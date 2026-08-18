#
# tests/test_issue_id_assigner.rb
#
# Pure-Ruby tests for deterministic issue_id generation.
# Verifies CodeX BLOCK-001 v2 contract: same inputs -> same id,
# canonical key sort, counter is last tie-breaker, no object_id/entity_id.
#

require_relative 'runner'
require_relative '../core/issue_id_assigner'

include SUAnalysis::Core

CANONICAL_DUPLICATE = {
  issue_type: 'duplicate_edge_candidate',
  source_tokens: [
    { persistent_id_path: [10, 20, 555], entity_id: 1,
      nested: true, pid_path_complete: true },
    { persistent_id_path: [10, 20, 777], entity_id: 2,
      nested: true, pid_path_complete: true }
  ]
}

# --- deterministic ---

test 'issue_id_assigner: same inputs produce same id' do
  id1 = IssueIdAssigner.assign(**CANONICAL_DUPLICATE, counter_within_type: 1)
  id2 = IssueIdAssigner.assign(**CANONICAL_DUPLICATE, counter_within_type: 1)
  assert_equal id1, id2
end

test 'issue_id_assigner: id is a String' do
  id = IssueIdAssigner.assign(**CANONICAL_DUPLICATE, counter_within_type: 1)
  assert_kind_of String, id
end

test 'issue_id_assigner: id contains the issue_type' do
  id = IssueIdAssigner.assign(**CANONICAL_DUPLICATE, counter_within_type: 1)
  assert_match /duplicate_edge_candidate/, id
end

# --- canonical sort ---

test 'issue_id_assigner: source keys are sorted lexicographically' do
  reversed = {
    issue_type: 'duplicate_edge_candidate',
    source_tokens: [
      { persistent_id_path: [10, 20, 777], entity_id: 2,
        nested: true, pid_path_complete: true },
      { persistent_id_path: [10, 20, 555], entity_id: 1,
        nested: true, pid_path_complete: true }
    ]
  }
  id_original = IssueIdAssigner.assign(**CANONICAL_DUPLICATE, counter_within_type: 1)
  id_reversed = IssueIdAssigner.assign(**reversed,           counter_within_type: 1)
  assert_equal id_original, id_reversed
end

test 'issue_id_assigner: dot-joined pid_path forms keys' do
  keys = IssueIdAssigner.canonical_source_keys(
    source_tokens: CANONICAL_DUPLICATE[:source_tokens]
  )
  assert_equal ['10.20.555', '10.20.777'], keys
end

# --- counter is last tie-breaker ---

test 'issue_id_assigner: counter distinguishes equal canonical keys' do
  single = {
    issue_type: 'short_edge',
    source_tokens: [
      { persistent_id_path: [42], entity_id: 1,
        nested: false, pid_path_complete: true }
    ]
  }
  id1 = IssueIdAssigner.assign(**single, counter_within_type: 1)
  id2 = IssueIdAssigner.assign(**single, counter_within_type: 2)
  refute_equal id1, id2
  assert_match /\|1$/, id1
  assert_match /\|2$/, id2
end

# --- empty pid_path falls back to geometry ---

test 'issue_id_assigner: empty pid_path uses geometry fallback' do
  id = IssueIdAssigner.assign(
    issue_type: 'short_edge',
    source_tokens: [
      { persistent_id_path: [], entity_id: 7,
        nested: false, pid_path_complete: false }
    ],
    location: [10.0, 0.0, 0.0],
    counter_within_type: 1
  )
  assert_match /geo:/, id
  # Same inputs -> same id
  id2 = IssueIdAssigner.assign(
    issue_type: 'short_edge',
    source_tokens: [
      { persistent_id_path: [], entity_id: 7,
        nested: false, pid_path_complete: false }
    ],
    location: [10.0, 0.0, 0.0],
    counter_within_type: 1
  )
  assert_equal id, id2
end

# --- never uses object_id or entity_id ---

test 'issue_id_assigner: id does not contain raw object_id or entity_id' do
  id = IssueIdAssigner.assign(
    issue_type: 'short_edge',
    source_tokens: [
      { persistent_id_path: [42], entity_id: 1_000_000,
        nested: false, pid_path_complete: true }
    ],
    counter_within_type: 1
  )
  assert_nil id.match(/object_id/)
  # entity_id 1000000 appears only as part of the canonical PID path,
  # never as a raw entity_id key.
  assert_match(/42/, id)
  refute_match(/1000000/, id)
end
