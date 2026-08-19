#
# tests/test_issue_id_assigner.rb
#
# Pure-Ruby tests for deterministic issue_id generation.
# Verifies CodeX BLOCK-001 v2 contract: same inputs -> same id,
# canonical key sort, counter is last tie-breaker, no object_id/entity_id.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/issue_id_assigner'

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

# --- BLOCK-002 adversarial: no-PID/no-location branch ---

test 'issue_id_assigner: no-PID + no-location -> no-source key (no entity_id/object_id)' do
  id = IssueIdAssigner.assign(
    issue_type: 'short_edge',
    source_tokens: [
      { persistent_id_path: [], entity_id: 999_999,
        nested: false, pid_path_complete: false, edge_ids: [] }
    ],
    counter_within_type: 1
  )
  # Must NOT contain entity_id 999999 or any object_id derivative.
  refute_match(/999999/, id)
  refute_match(/object_id/, id)
  # Uses the deterministic no-source key.
  assert_match(/no-source/, id)
end

test 'issue_id_assigner: no-PID + sorted edge_ids -> deterministic edges key' do
  id1 = IssueIdAssigner.assign(
    issue_type: 'short_edge',
    source_tokens: [
      { persistent_id_path: [], entity_id: 111,
        nested: false, pid_path_complete: false, edge_ids: [3, 1, 2] }
    ],
    counter_within_type: 1
  )
  id2 = IssueIdAssigner.assign(
    issue_type: 'short_edge',
    source_tokens: [
      { persistent_id_path: [], entity_id: 222,
        nested: false, pid_path_complete: false, edge_ids: [2, 3, 1] }
    ],
    counter_within_type: 1
  )
  # Same edge_ids in different order -> same id (sorted internally).
  assert_equal id1, id2
  assert_match(/edges:1,2,3/, id1)
end

test 'issue_id_assigner: location fallback is deterministic across perturbations' do
  id1 = IssueIdAssigner.assign(
    issue_type: 'short_edge',
    source_tokens: [
      { persistent_id_path: [], entity_id: 1,
        nested: false, pid_path_complete: false, edge_ids: [] }
    ],
    location: [10.0, 0.0, 0.0],
    counter_within_type: 1
  )
  id2 = IssueIdAssigner.assign(
    issue_type: 'short_edge',
    source_tokens: [
      { persistent_id_path: [], entity_id: 99,
        nested: false, pid_path_complete: false, edge_ids: [] }
    ],
    location: [10.0, 0.0, 0.0],
    counter_within_type: 1
  )
  # Location is identical; entity_id is ignored.
  assert_equal id1, id2
  assert_match(/geo:/, id1)
end
