#
# tests/test_structural_facts.rb
#
# Pure-Ruby tests for structural identity arithmetic.
# Covers all branches of SUAnalysis::Core::StructuralFacts.compute.
#
# Stage 6 CodeX BLOCK-001 v3 fix (Round 015):
#   structural_depth = active_path_count + ancestry_count
#   (the leaf is NOT counted; expected_pid_count = structural_depth + 1)
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/structural_facts'

include SUAnalysis::Core

# --- structural_depth excludes the leaf ---

test 'structural_facts: root leaf, no active edit, pid_path=[]' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [],
    leaf_pid: nil,
    active_path_count: 0
  )
  assert_equal 0, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

test 'structural_facts: root leaf with leaf_pid only' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [],
    leaf_pid: 100,
    active_path_count: 0
  )
  assert_equal 0, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [100], facts[:pid_path]
end

test 'structural_facts: nested leaf with 2 ancestors + leaf' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [10, 20],
    leaf_pid: 555,
    active_path_count: 0
  )
  assert_equal 2, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [10, 20, 555], facts[:pid_path]
end

test 'structural_facts: nested with one missing PID -> incomplete' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [10, nil],
    leaf_pid: 555,
    active_path_count: 0
  )
  # ancestry_count=2 (containers); structural_depth = 0 + 2 = 2.
  assert_equal 2, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  # The canonical pid_path drops the nil and preserves the leaf.
  assert_equal [10, 555], facts[:pid_path]
end

test 'structural_facts: nested with leaf PID missing -> incomplete' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [10, 20],
    leaf_pid: nil,
    active_path_count: 0
  )
  assert_equal 2, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  # The canonical pid_path does NOT include the missing leaf.
  assert_equal [10, 20], facts[:pid_path]
end

test 'structural_facts: active edit context adds to depth' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [10, 20],
    leaf_pid: 555,
    active_path_count: 2
  )
  # 2 active + 2 ancestors = 4 (leaf NOT counted).
  assert_equal 4, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [10, 20, 555], facts[:pid_path]
end

test 'structural_facts: active edit with all PIDs nil -> incomplete' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [nil, nil],
    leaf_pid: nil,
    active_path_count: 2
  )
  # 2 active + 2 ancestors = 4.
  assert_equal 4, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

# --- constant invariants ---

test 'structural_facts: invariant pid_path_length == expected_pid_count when no active edit' do
  # expected_pid_count = structural_depth + 1
  [0, 1, 2, 3].each do |n|
    ancestry = (0...n).map { |i| (i + 1) * 10 }
    leaf = (n + 1) * 10
    facts = StructuralFacts.compute(
      ancestry_pids_with_nil: ancestry,
      leaf_pid: leaf,
      active_path_count: 0
    )
    assert_equal n + 1,
                facts[:pid_path].length,
                "n=#{n} pid_path.length should match expected_pid_count"
    assert_equal n, facts[:structural_depth]
  end
end

# --- from_canonical_path: pid_path INCLUDES the leaf as last entry ---

test 'structural_facts.from_canonical_path: complete nested' do
  # ancestry = pid_path[0..-2] = [10, 20]; structural_depth = 2.
  facts = StructuralFacts.from_canonical_path(pid_path: [10, 20, 555], active_path_count: 0)
  assert_equal 2, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [10, 20, 555], facts[:pid_path]
end

test 'structural_facts.from_canonical_path: empty path is incomplete' do
  facts = StructuralFacts.from_canonical_path(pid_path: [], active_path_count: 0)
  assert_equal 0, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

test 'structural_facts.from_canonical_path: nil path is incomplete' do
  facts = StructuralFacts.from_canonical_path(pid_path: nil, active_path_count: 0)
  assert_equal 0, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

test 'structural_facts.from_canonical_path: root leaf with 1 pid' do
  facts = StructuralFacts.from_canonical_path(pid_path: [100], active_path_count: 0)
  assert_equal 0, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [100], facts[:pid_path]
end

test 'structural_facts.from_canonical_path: with active edit context' do
  facts = StructuralFacts.from_canonical_path(pid_path: [10, 20, 555], active_path_count: 2)
  # 2 active + 2 ancestors = 4.
  assert_equal 4, facts[:structural_depth]
end
