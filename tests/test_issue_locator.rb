#
# tests/test_issue_locator.rb — adapter test for the host-side locator.
# Verifies the 6 Profile resolutions produce correct entities and
# surface correct diagnostics when resolution fails.
#

require_relative 'runner'
require_relative '_fake_su'
require_relative '../core/issue_registry'
require_relative '../core/issue_locator_policy'
require_relative '../extension/issue_locator'

include SUAnalysis::Core
include SUAnalysis::Extension
include FakeSU

# --- helpers ---------------------------------------------------------

def issue_with(sources, locatable: true)
  {
    issue_id:          'test|1',
    issue_type:        'short_edge',
    severity:          'low',
    confidence:        'medium',
    sources:           sources,
    source_entity_ids: sources.map { |s| s[:entity_id] }.compact,
    edge_ids:          [],
    location:          nil,
    message:           'm',
    metadata:          {},
    locatable:         locatable,
    display_length:    nil
  }
end

# Test FakeModel that responds to instance_path_from_pid_path and
# find_entity_by_id. Per CodeX Round 014 BLOCK-001 v3 / v4:
#   - structural_depth is real entity count
#   - pid_path_complete is computed BEFORE nil filtering
class FakeInstancePath
  def initialize(leaf:, root: nil)
    @leaf = leaf
    @root = root
  end
  def leaf; @leaf; end
  def root; @root || @leaf; end
end

def issue_locator_fake_model(resolve_table = {}, entities_by_id = {})
  # resolve_table: Hash<Array<Integer> => FakeInstancePath>
  # entities_by_id: Hash<Integer => Object>
  m = Object.new
  m.define_singleton_method(:instance_path_from_pid_path) do |serialized|
    # Recreate the array from the serialized string.
    arr = serialized.split('.').map { |x| Integer(x) }
    resolve_table[arr]
  end
  m.define_singleton_method(:find_entity_by_id) do |eid|
    entities_by_id[eid]
  end
  m
end

# --- 6 profiles ------------------------------------------------------

test 'issue_locator: complete-root -> :inst_path_leaf -> leaf entity' do
  fake_leaf = Object.new
  ip = FakeInstancePath.new(leaf: fake_leaf)
  model = issue_locator_fake_model({[100] => ip})
  issue = issue_with([{ persistent_id_path: [100], entity_id: 1,
                         nested: false, pid_path_complete: true }])
  result = IssueLocator.locate(issue, model: model)
  assert_equal :resolved, result[:status]
  assert_equal 1, result[:targets].length
  assert_equal fake_leaf, result[:targets].first
  assert_equal [], result[:diagnostics]
end

test 'issue_locator: complete-nested -> :inst_path_root -> root occurrence' do
  fake_root = Object.new
  ip = FakeInstancePath.new(leaf: Object.new, root: fake_root)
  model = issue_locator_fake_model({[100, 200, 555] => ip})
  issue = issue_with([{ persistent_id_path: [100, 200, 555], entity_id: 1,
                         nested: true, pid_path_complete: true }])
  result = IssueLocator.locate(issue, model: model)
  assert_equal :resolved, result[:status]
  assert_equal fake_root, result[:targets].first
end

test 'issue_locator: incomplete-root + entity_id -> find_entity_by_id' do
  fake_entity = Object.new
  model = issue_locator_fake_model({}, 999 => fake_entity)
  issue = issue_with([{ persistent_id_path: [], entity_id: 999,
                         nested: false, pid_path_complete: false }])
  result = IssueLocator.locate(issue, model: model)
  assert_equal :resolved, result[:status]
  assert_equal fake_entity, result[:targets].first
end

test 'issue_locator: incomplete-nested -> :skip (CodeX Round 014 #4)' do
  issue = issue_with([{ persistent_id_path: [], entity_id: 999,
                         nested: true, pid_path_complete: false }])
  model = issue_locator_fake_model({}, 999 => Object.new)
  result = IssueLocator.locate(issue, model: model)
  assert_equal :unresolved, result[:status]
  assert_equal [], result[:targets]
  assert result[:diagnostics].any? { |d| d[:reason] =~ /incomplete-nested/ }
end

test 'issue_locator: incomplete-nested-partial-leaf -> :skip (no entityID fallback)' do
  issue = issue_with([{ persistent_id_path: [555], entity_id: 999,
                         nested: true, pid_path_complete: false }])
  model = issue_locator_fake_model({}, 999 => Object.new)
  result = IssueLocator.locate(issue, model: model)
  assert_equal :unresolved, result[:status]
  assert result[:diagnostics].any? { |d| d[:reason] =~ /incomplete-nested-partial-leaf/ }
end

test 'issue_locator: fully-missing -> :skip' do
  issue = issue_with([{ persistent_id_path: [], entity_id: nil,
                         nested: false, pid_path_complete: false }])
  model = issue_locator_fake_model
  result = IssueLocator.locate(issue, model: model)
  assert_equal :unresolved, result[:status]
  assert result[:diagnostics].any? { |d| d[:reason] =~ /fully-missing/ }
end

# --- diagnostics -----------------------------------------------------

test 'issue_locator: unresolved inst_path produces a diagnostic' do
  model = issue_locator_fake_model({})  # empty resolve table
  issue = issue_with([{ persistent_id_path: [100], entity_id: 1,
                         nested: false, pid_path_complete: true }])
  result = IssueLocator.locate(issue, model: model)
  assert_equal :unresolved, result[:status]
  assert result[:diagnostics].any? { |d| d[:stage] == 'issue_locator.inst_path_unresolved' }
end

test 'issue_locator: missing entity_id fallback produces a diagnostic' do
  model = issue_locator_fake_model({}, {})  # empty entities_by_id
  issue = issue_with([{ persistent_id_path: [], entity_id: 42,
                         nested: false, pid_path_complete: false }])
  result = IssueLocator.locate(issue, model: model)
  assert_equal :unresolved, result[:status]
  assert result[:diagnostics].any? { |d| d[:stage] == 'issue_locator.entity_id_unresolved' }
end

# --- locator policy for non-locatable Issues ---

test 'issue_locator: non-locatable issue returns no targets' do
  issue = issue_with([{ persistent_id_path: [100], entity_id: 1,
                         nested: false, pid_path_complete: true }],
                    locatable: false)
  model = issue_locator_fake_model({[100] => FakeInstancePath.new(leaf: Object.new)})
  result = IssueLocator.locate(issue, model: model)
  assert_equal :unresolved, result[:status]
  assert_equal [], result[:targets]
end

# --- multi-source: duplicate / gap with two tokens ---

test 'issue_locator: 2 tokens -> 2 targets, deduped' do
  leaf1 = Object.new
  leaf2 = Object.new
  model = issue_locator_fake_model({
    [10, 20, 555] => FakeInstancePath.new(leaf: leaf1),
    [10, 20, 777] => FakeInstancePath.new(leaf: leaf2)
  })
  issue = issue_with([
    { persistent_id_path: [10, 20, 555], entity_id: 1,
      nested: true, pid_path_complete: true },
    { persistent_id_path: [10, 20, 777], entity_id: 2,
      nested: true, pid_path_complete: true }
  ])
  result = IssueLocator.locate(issue, model: model)
  assert_equal :resolved, result[:status]
  assert_equal 2, result[:targets].length
  assert result[:targets].include?(leaf1)
  assert result[:targets].include?(leaf2)
end
