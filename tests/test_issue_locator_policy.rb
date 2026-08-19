#
# tests/test_issue_locator_policy.rb
#
# Pure-Ruby tests for IssueLocatorPolicy. Verifies the 6-profile
# mapping to target descriptors (CodeX BLOCK-001 v3 + v4).
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/issue_locator_policy'

include SUAnalysis::Core

def loc_issue(sources, locatable: true)
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

# --- 6 profiles ---

test 'issue_locator_policy: complete-root -> :inst_path_leaf' do
  issue = loc_issue([{ persistent_id_path: [100], entity_id: 1,
                        nested: false, pid_path_complete: true }])
  targets = IssueLocatorPolicy.targets_for(issue)
  assert_equal 1, targets.length
  assert_equal :inst_path_leaf, targets[0][:kind]
  assert_equal [100], targets[0][:pid_path]
end

test 'issue_locator_policy: complete-nested -> :inst_path_root' do
  issue = loc_issue([{ persistent_id_path: [10, 20, 555], entity_id: 1,
                        nested: true, pid_path_complete: true }])
  targets = IssueLocatorPolicy.targets_for(issue)
  assert_equal 1, targets.length
  assert_equal :inst_path_root, targets[0][:kind]
  assert_equal [10, 20, 555], targets[0][:pid_path]
end

test 'issue_locator_policy: incomplete-root -> :entity_id' do
  issue = loc_issue([{ persistent_id_path: [], entity_id: 42,
                        nested: false, pid_path_complete: false }])
  targets = IssueLocatorPolicy.targets_for(issue)
  assert_equal 1, targets.length
  assert_equal :entity_id, targets[0][:kind]
  assert_equal 42, targets[0][:entity_id]
end

test 'issue_locator_policy: incomplete-nested-partial-leaf -> :skip' do
  issue = loc_issue([{ persistent_id_path: [555], entity_id: 1,
                        nested: true, pid_path_complete: false }])
  targets = IssueLocatorPolicy.targets_for(issue)
  assert_equal 1, targets.length
  assert_equal :skip, targets[0][:kind]
  assert_match(/incomplete-nested-partial-leaf/, targets[0][:reason])
end

test 'issue_locator_policy: incomplete-nested-partial-ancestry -> :skip' do
  issue = loc_issue([{ persistent_id_path: [], entity_id: 1,
                        nested: true, pid_path_complete: false }])
  targets = IssueLocatorPolicy.targets_for(issue)
  assert_equal 1, targets.length
  assert_equal :skip, targets[0][:kind]
  assert_match(/incomplete-nested-partial-ancestry/, targets[0][:reason])
end

test 'issue_locator_policy: fully-missing -> :skip' do
  issue = loc_issue([{ persistent_id_path: [], entity_id: nil,
                        nested: false, pid_path_complete: false }])
  targets = IssueLocatorPolicy.targets_for(issue)
  assert_equal 1, targets.length
  assert_equal :skip, targets[0][:kind]
  assert_match(/fully-missing/, targets[0][:reason])
end

# --- multi-source ---

test 'issue_locator_policy: duplicate issue has 2 targets, both nested' do
  issue = loc_issue([
    { persistent_id_path: [10, 20, 555], entity_id: 1,
      nested: true, pid_path_complete: true },
    { persistent_id_path: [10, 20, 777], entity_id: 2,
      nested: true, pid_path_complete: true }
  ])
  targets = IssueLocatorPolicy.targets_for(issue)
  assert_equal 2, targets.length
  assert_equal :inst_path_root, targets[0][:kind]
  assert_equal :inst_path_root, targets[1][:kind]
end

# --- non-locatable ---

test 'issue_locator_policy: non-locatable issue returns []' do
  issue = loc_issue([{ persistent_id_path: [100], entity_id: 1,
                        nested: false, pid_path_complete: true }],
                    locatable: false)
  targets = IssueLocatorPolicy.targets_for(issue)
  assert_equal [], targets
end

# --- select_count ---

test 'issue_locator_policy.select_count: counts non-skip targets' do
  issue = loc_issue([
    { persistent_id_path: [10, 20, 555], entity_id: 1,
      nested: true, pid_path_complete: true },
    { persistent_id_path: [], entity_id: 1,
      nested: true, pid_path_complete: false }
  ])
  assert_equal 1, IssueLocatorPolicy.select_count(issue)
end

# --- SAFETY: nested source with entityID MUST NOT use entityID fallback ---

test 'issue_locator_policy: incomplete-nested entity_id NEVER falls back' do
  issue = loc_issue([{ persistent_id_path: [], entity_id: 999,
                        nested: true, pid_path_complete: false }])
  targets = IssueLocatorPolicy.targets_for(issue)
  assert_equal :skip, targets[0][:kind]
  refute_equal :entity_id, targets[0][:kind]
end

# --- CodeX Round 014 integration: StructuralFacts -> SourceReference
#     -> IssueEnricher -> IssueLocatorPolicy ---

require_relative '../extension/su_ai_plugin/core/structural_facts'
require_relative '../extension/su_ai_plugin/core/issue_enricher'

def integrate_structural_to_locator(ancestry_pids_with_nil:, leaf_pid:,
                                    entity_id:, active_path_count: 0)
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: ancestry_pids_with_nil,
    leaf_pid: leaf_pid,
    active_path_count: active_path_count
  )
  path = facts[:pid_path]
  token = {
    persistent_id_path: path,
    entity_id:          entity_id,
    nested:             facts[:structural_depth] > 0,
    pid_path_complete:  facts[:pid_path_complete]
  }
  locatable = IssueEnricher.send(:compute_locatable, [token])
  issue = {
    issue_id:   'test',
    issue_type: 'short_edge',
    severity:   'low',
    confidence: 'medium',
    sources:    [token],
    source_entity_ids: [entity_id].compact,
    edge_ids:   [],
    location:   nil,
    message:    'm',
    metadata:   {},
    locatable:  locatable,
    display_length: nil
  }
  [IssueLocatorPolicy.targets_for(issue), locatable]
end

test 'integration: complete root -> :inst_path_leaf (CodeX Round 014)' do
  targets, locatable = integrate_structural_to_locator(
    ancestry_pids_with_nil: [],
    leaf_pid:              100,
    entity_id:             1,
    active_path_count:     0
  )
  assert_equal true, locatable
  assert_equal 1, targets.length
  assert_equal :inst_path_leaf, targets[0][:kind]
  assert_equal [100], targets[0][:pid_path]
end

test 'integration: incomplete root + entityID -> :entity_id (CodeX Round 014)' do
  targets, locatable = integrate_structural_to_locator(
    ancestry_pids_with_nil: [],
    leaf_pid:              nil,
    entity_id:             1,
    active_path_count:     0
  )
  assert_equal true, locatable
  assert_equal 1, targets.length
  assert_equal :entity_id, targets[0][:kind]
  assert_equal 1, targets[0][:entity_id]
end
