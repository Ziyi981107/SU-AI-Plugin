#
# tests/test_active_edit_context_facts.rb
#
# CodeX Round 014 Gate B proof: structural_depth and pid_path_complete
# MUST be derived from the real active_path facts, not from the filtered
# PID array.
#
# These tests work outside SketchUp via a stand-in model object that
# reports a configurable active_path. No real SU required.
#

require_relative 'runner'
require_relative '../compatibility/su_capability'

include SUAnalysis::Compatibility

# --- helpers ---------------------------------------------------------

class FakeEntity
  # Test stub for active-path entities. `pid` is the integer PID
  # (or nil for missing-PID slots).
  def initialize(pid)
    @pid = pid
  end
  def persistent_id
    @pid
  end
end

def edit_facts_fake_model(active_pids)
  # active_path entities whose position-N entity has PID active_pids[N]
  # (nil for missing-PID slots).
  path = active_pids.map { |pid| FakeEntity.new(pid) }
  model = Object.new
  model.define_singleton_method(:active_path) { path }
  model.define_singleton_method(:edit_transform) { nil }
  model
end

# --- structural_depth from real entity count ---

test 'active_edit_context_facts: empty active path -> depth 0, complete=true' do
  # Per CodeX Round 018 BLOCK-001: empty active path is the NEUTRAL
  # complete state for snapshot traversal. The walk seed is identity;
  # missing-PID failures from real containers/leafs are evaluated
  # separately.
  facts = SUCapability.active_edit_context_facts(edit_facts_fake_model([]))
  assert_equal 0, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

test 'active_edit_context_facts: complete active path of 2 -> depth 2, complete=true' do
  facts = SUCapability.active_edit_context_facts(edit_facts_fake_model([100, 200]))
  assert_equal 2, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [100, 200], facts[:pid_path]
end

test 'active_edit_context_facts: 2-container active path with one nil PID -> depth 2, complete=false' do
  # CodeX Round 014 Gate B proof #2: missing any container PID -> fail closed.
  facts = SUCapability.active_edit_context_facts(edit_facts_fake_model([100, nil]))
  assert_equal 2, facts[:structural_depth],
             'structural_depth must be ENTITY COUNT, not filtered PID length'
  assert_equal false, facts[:pid_path_complete],
             'pid_path_complete must be false when any PID is nil'
  # The canonical pid_path drops the nil; PIDs are NOT zero-padded.
  assert_equal [100], facts[:pid_path]
end

test 'active_edit_context_facts: 2-container active path with all nil PIDs -> complete=false' do
  facts = SUCapability.active_edit_context_facts(edit_facts_fake_model([nil, nil]))
  assert_equal 2, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

# --- structural_depth is NOT filtered PID length ---

test 'active_edit_context_facts: structural_depth != filtered PID length' do
  # Two entities, only one PID. Filtered length = 1, but depth = 2.
  facts = SUCapability.active_edit_context_facts(edit_facts_fake_model([100, nil]))
  filtered_length = facts[:pid_path].length
  assert_equal 1, filtered_length
  refute_equal filtered_length, facts[:structural_depth]
end

# --- raw_with_nil preserves the slot structure for callers ---

test 'active_edit_context_facts: raw_with_nil preserves slot structure' do
  facts = SUCapability.active_edit_context_facts(edit_facts_fake_model([100, nil, 300]))
  assert_equal [100, nil, 300], facts[:raw_with_nil]
end

# --- nil model returns default empty facts ---

test 'active_edit_context_facts: nil model -> default empty facts' do
  # Per CodeX Round 018 BLOCK-001: nil model -> default empty facts
  # with pid_path_complete = true (neutral seed for snapshot traversal).
  facts = SUCapability.active_edit_context_facts(nil)
  assert_equal 0, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

# --- pid_path is frozen ---

test 'active_edit_context_facts: pid_path is frozen' do
  facts = SUCapability.active_edit_context_facts(edit_facts_fake_model([100, 200]))
  assert facts[:pid_path].frozen?
end
