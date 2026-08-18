#
# tests/test_structural_facts.rb
#
# Pure-Ruby tests for structural identity arithmetic.
# Covers all branches of SUAnalysis::Core::StructuralFacts.compute.
#

require_relative 'runner'
require_relative '../core/structural_facts'

include SUAnalysis::Core

# --- structural_depth: counts ancestors + leaf + active edit context ---

test 'structural_facts: root leaf, no active edit, pid_path=[]' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [],
    leaf_pid: nil,
    active_path_count: 0
  )
  assert_equal 1, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

test 'structural_facts: root leaf with leaf_pid only' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [],
    leaf_pid: 100,
    active_path_count: 0
  )
  assert_equal 1, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [100], facts[:pid_path]
end

test 'structural_facts: nested leaf with 2 ancestors + leaf' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [10, 20],
    leaf_pid: 555,
    active_path_count: 0
  )
  assert_equal 3, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [10, 20, 555], facts[:pid_path]
end

test 'structural_facts: nested with one missing PID -> incomplete' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [10, nil],
    leaf_pid: 555,
    active_path_count: 0
  )
  # ancestry_count=2 (containers); structural_depth = 0 + 2 + 1 = 3.
  assert_equal 3, facts[:structural_depth]
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
  assert_equal 3, facts[:structural_depth]
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
  assert_equal 5, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [10, 20, 555], facts[:pid_path]
end

test 'structural_facts: active edit with all PIDs nil -> incomplete' do
  facts = StructuralFacts.compute(
    ancestry_pids_with_nil: [nil, nil],
    leaf_pid: nil,
    active_path_count: 2
  )
  # ancestry_count=2; structural_depth = 2 + 1 + 2 = 5.
  assert_equal 5, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

# --- from_canonical_path: editing-side helper ---

test 'structural_facts.from_canonical_path: complete nested' do
  # in this form, pid_path INCLUDES the leaf as the last element.
  # ancestry = pid_path[0..-2] = [10, 20]; structural_depth = 2 + 1 = 3.
  facts = StructuralFacts.from_canonical_path(pid_path: [10, 20, 555], active_path_count: 0)
  assert_equal 3, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [10, 20, 555], facts[:pid_path]
end

test 'structural_facts.from_canonical_path: empty path is incomplete' do
  facts = StructuralFacts.from_canonical_path(pid_path: [], active_path_count: 0)
  assert_equal 1, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

test 'structural_facts.from_canonical_path: nil path is incomplete' do
  facts = StructuralFacts.from_canonical_path(pid_path: nil, active_path_count: 0)
  assert_equal 1, facts[:structural_depth]
  assert_equal false, facts[:pid_path_complete]
  assert_equal [], facts[:pid_path]
end

test 'structural_facts.from_canonical_path: root leaf with 1 pid' do
  facts = StructuralFacts.from_canonical_path(pid_path: [100], active_path_count: 0)
  assert_equal 1, facts[:structural_depth]
  assert_equal true, facts[:pid_path_complete]
  assert_equal [100], facts[:pid_path]
end
