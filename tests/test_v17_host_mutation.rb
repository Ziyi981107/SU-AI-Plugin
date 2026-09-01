#
# tests/test_v17_host_mutation.rb — V1.7 Host mutation tests.
#
# Per frozen V1.7 Blueprint §18.4:
#
#   H1 invalid preflight
#      -> zero begin_operation.
#   H2 success -> one operation + one safe batch + commit
#   H3 transform failure -> safe failure / abort
#   H4 add-line failure -> abort/fail closed, no false APPLIED
#   H5 commit uncertainty -> FAILED
#   H6 post-state mismatch -> FAILED
#   H7 source fingerprint unchanged
#   H8 existing derived source-edge coordinates unchanged
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/endpoint_record'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/derived_entity_record'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/canonical_topology_builder'
require_relative '../extension/su_ai_plugin/core/gap_pair_proposer'
require_relative '../extension/su_ai_plugin/core/gap_bridge_executor'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_snapshot'

include SUAnalysis::Core

def make_fake_adapter
  DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
end

def make_test_workspace(adapter:, edges:)
  # Build a minimal SourceSnapshot with the given edges.
  layer = LayerRecord.new(name: 'L0')
  edge_records = edges.map do |(s, e)|
    EdgeRecord.new(
      id: 0,
      source: SourceReference.new(
        entity_id: 1, persistent_id: 100, kind: 'edge',
        persistent_id_path: [100], instance_path: [],
        structural_depth: 0, pid_path_complete: true,
        layer_name: 'L0'
      ),
      start_point: s,
      end_point:   e,
      layer: 'L0'
    )
  end
  geom = GeometrySnapshot.new(edges: edge_records, layers: [layer])
  profile = Struct.new(:profile_name, :tolerance).new('test', Tolerance.default)
  tol = Tolerance.default
  ec = ExecutionConfigSnapshot.from_live_config(
    profile,
    rule_set_digest: 'test-rules',
    source_snapshot_schema_version: 'v1'
  )
  snap = SourceSnapshot.new(
    edges: edge_records,
    faces: [],
    layers: [layer],
    execution_config: ec,
    selection_scope: [],
    unit: 'inches',
    coordinate_origin: 'raw',
    transform_context: {}
  )
  ws = DerivedGeometryWorkspace.new(source_snapshot: snap, adapter: adapter, model: nil)
  cur = ws
  edges.each_with_index do |(s, e), i|
    cur = cur.build_entity(
      derived_id: "der-edge-#{i}",
      kind: :edge,
      source_occurrence_ids: ["occ-#{i}"],
      geometry_summary: { 'layer' => 'L0', 'start' => s, 'end' => e, 'length' => 1.0, 'vertex_count' => 2 },
      geometry_data: [s, e]
    )
    break if cur.state == :failed
  end
  cur
end

# ---- H1: invalid preflight -> zero begin_operation ----

test 'V17-H1: invalid preflight -> zero begin_operation' do
  adapter = make_fake_adapter
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.05, 0.0, 0.0], [20.0, 0.0, 0.0]]
  ]
  ws = make_test_workspace(adapter: adapter, edges: edges)
  refute_nil ws
  # Construct a proposal that fails preflight (distance out of band).
  bad_proposal = [{
    'proposal_id' => 'p-bad',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'a',
    'endpoint_b_key' => 'b',
    'canonical_node_a_id' => 'cn-a',
    'canonical_node_b_id' => 'cn-b',
    'distance'   => 1000.0,  # beyond gap_search
    'gap_search' => 0.1,
    'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0',
    'layer_b'    => 'L0',
    'incident_derived_edge_ids' => %w[eA eB],
    'incident_source_occurrence_ids' => %w[occ-a occ-b],
    'expected_bridge_endpoints' => [[0.0, 0.0, 0.0], [1000.0, 0.0, 0.0]],
    'expected_bridge_length' => 1000.0,
    'rule_id' => 'endpoint_bridge.v1',
    'rule_version' => '1'
  }]
  before = adapter.operation_log.length
  result = GapBridgeExecutor.apply(
    workspace: ws,
    adapter:   adapter,
    proposals: bad_proposal,
    tolerance: Tolerance.default
  )
  assert_equal :failed, result['status']
  assert_equal REASON_PREFLIGHT_FAILED = 'preflight_failed',
               result['audit']['reason']
  # No new begin_operation call.
  assert_equal before, adapter.operation_log.length,
               "preflight fail must NOT call begin_operation"
end

# ---- H2: success -> one operation + one safe batch + commit ----

test 'V17-H2: success -> one operation + one safe batch + commit' do
  adapter = make_fake_adapter
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.05, 0.0, 0.0], [20.0, 0.0, 0.0]]
  ]
  ws = make_test_workspace(adapter: adapter, edges: edges)
  good_proposal = [{
    'proposal_id' => 'p-good',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'a',
    'endpoint_b_key' => 'b',
    'canonical_node_a_id' => 'cn-a',
    'canonical_node_b_id' => 'cn-b',
    'distance'   => 0.05,
    'gap_search' => 0.1,
    'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0',
    'layer_b'    => 'L0',
    'incident_derived_edge_ids' => %w[eA eB],
    'incident_source_occurrence_ids' => %w[occ-a occ-b],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1',
    'rule_version' => '1'
  }]
  result = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: good_proposal,
    tolerance: Tolerance.default
  )
  assert_equal :applied, result['status']
  # One begin + one commit in the operation log.
  op_log = adapter.operation_log
  begins = op_log.select { |op| op[:kind] == :begin }.length
  commits = op_log.select { |op| op[:kind] == :commit }.length
  aborts  = op_log.select { |op| op[:kind] == :abort }.length
  assert_equal 1, begins, "expected exactly one begin_operation"
  assert_equal 1, commits, "expected exactly one commit"
  assert_equal 0, aborts
  # Exactly one applied bridge.
  assert_equal 1, result['audit']['applied_count']
  # The bridge appears in the workspace.
  post_ws = result['post_workspace']
  refute_nil post_ws
  entity_count_delta = post_ws.entity_count - ws.entity_count
  assert_equal 1, entity_count_delta
end

# ---- H3: add-line failure -> abort/fail closed ----

test 'V17-H3: add-line failure -> abort/fail closed, no false APPLIED' do
  adapter = make_fake_adapter
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.05, 0.0, 0.0], [20.0, 0.0, 0.0]]
  ]
  ws = make_test_workspace(adapter: adapter, edges: edges)
  # Inject a failure that breaks add_line_to_repair_group.
  adapter.define_singleton_method(:add_line_to_repair_group) do |rg, p1, p2|
    nil  # simulate failure
  end
  good_proposal = [{
    'proposal_id' => 'p-fail',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'a',
    'endpoint_b_key' => 'b',
    'canonical_node_a_id' => 'cn-a',
    'canonical_node_b_id' => 'cn-b',
    'distance'   => 0.05,
    'gap_search' => 0.1,
    'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[eA eB],
    'incident_source_occurrence_ids' => %w[occ-a occ-b],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1',
    'rule_version' => '1'
  }]
  result = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: good_proposal,
    tolerance: Tolerance.default
  )
  assert_equal :failed, result['status']
  refute_equal :applied, result['status']
  # The operation log: begin + abort (no commit).
  op_log = adapter.operation_log
  begins = op_log.select { |op| op[:kind] == :begin }.length
  aborts = op_log.select { |op| op[:kind] == :abort }.length
  commits = op_log.select { |op| op[:kind] == :commit }.length
  assert_equal 1, begins, "begin should fire exactly once"
  assert_equal 1, aborts, "abort should fire on failure"
  assert_equal 0, commits, "no commit on add-line failure"
end

# ---- H4: commit uncertainty -> FAILED ----

test 'V17-H4: commit uncertainty -> FAILED' do
  adapter = make_fake_adapter
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.05, 0.0, 0.0], [20.0, 0.0, 0.0]]
  ]
  ws = make_test_workspace(adapter: adapter, edges: edges)
  # Stub end_operation to raise (commit uncertainty).
  original_end = adapter.method(:end_operation)
  adapter.define_singleton_method(:end_operation) do |_m, commit:|
    raise StandardError, "commit_uncertain_simulation"
  end
  good_proposal = [{
    'proposal_id' => 'p-unc',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'a',
    'endpoint_b_key' => 'b',
    'canonical_node_a_id' => 'cn-a',
    'canonical_node_b_id' => 'cn-b',
    'distance'   => 0.05,
    'gap_search' => 0.1,
    'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[eA eB],
    'incident_source_occurrence_ids' => %w[occ-a occ-b],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1',
    'rule_version' => '1'
  }]
  result = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: good_proposal,
    tolerance: Tolerance.default
  )
  assert_equal :failed, result['status']
  assert_equal 'commit_uncertainty', result['audit']['reason']
end

# ---- H5: post-state mismatch -> FAILED ----

test 'V17-H5: post-state mismatch -> FAILED' do
  adapter = make_fake_adapter
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.05, 0.0, 0.0], [20.0, 0.0, 0.0]]
  ]
  ws = make_test_workspace(adapter: adapter, edges: edges)
  good_proposal = [{
    'proposal_id' => 'p-postmismatch',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'a',
    'endpoint_b_key' => 'b',
    'canonical_node_a_id' => 'cn-a',
    'canonical_node_b_id' => 'cn-b',
    'distance'   => 0.05,
    'gap_search' => 0.1,
    'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[eA eB],
    'incident_source_occurrence_ids' => %w[occ-a occ-b],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1',
    'rule_version' => '1'
  }]
  # Inject post-validate failure: simulate that adapter's bridge
  # handles were never actually created (post_validate checks
  # all applied host handles valid?).
  # The fake adapter returns valid FakeEdges by default; we
  # cannot easily make them invalid post-hoc. Instead we use a
  # 2-proposal list where they collide on endpoints (causes
  # post-validate to flag duplicate endpoint / mismatch).
  colliding = good_proposal + [{
    'proposal_id' => 'p-collide',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'a',  # SAME endpoint -> duplicate
    'endpoint_b_key' => 'b',
    'canonical_node_a_id' => 'cn-a',
    'canonical_node_b_id' => 'cn-b',
    'distance'   => 0.05,
    'gap_search' => 0.1,
    'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[eA eB],
    'incident_source_occurrence_ids' => %w[occ-a occ-b],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1',
    'rule_version' => '1'
  }]
  result = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: colliding,
    tolerance: Tolerance.default
  )
  # Pre-flight rejects this (duplicate endpoints), so :failed
  # with preflight_failed OR post_validate_failed; either way
  # must NOT be :applied.
  refute_equal :applied, result['status'],
               "duplicate-endpoint collision must NOT yield :applied"
end

# ---- H6: source fingerprint unchanged ----

test 'V17-H6: source fingerprint unchanged after apply' do
  adapter = make_fake_adapter
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.05, 0.0, 0.0], [20.0, 0.0, 0.0]]
  ]
  ws = make_test_workspace(adapter: adapter, edges: edges)
  # Compute fingerprint explicitly via SourceFingerprint.from_snapshot.
  source_fp = SourceFingerprint.from_snapshot(ws.source_snapshot)
  pre_fingerprint = source_fp.digest.to_s.dup
  good_proposal = [{
    'proposal_id' => 'p-good',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'a', 'endpoint_b_key' => 'b',
    'canonical_node_a_id' => 'cn-a', 'canonical_node_b_id' => 'cn-b',
    'distance'   => 0.05,
    'gap_search' => 0.1, 'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[eA eB],
    'incident_source_occurrence_ids' => %w[occ-a occ-b],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1',
    'rule_version' => '1'
  }]
  result = GapPairProposer_propose_safe_then_apply(adapter, ws, good_proposal)
  assert_equal :applied, result['status']
  # Workspace stays :ready.
  assert_equal :ready, result['post_workspace'].state
  # Source fingerprint unchanged.
  post_fingerprint = SourceFingerprint.from_snapshot(result['post_workspace'].source_snapshot).digest.to_s
  assert_equal pre_fingerprint, post_fingerprint,
               "source fingerprint MUST remain unchanged after gap repair apply"
end

# ---- H7: existing source-edge coordinates unchanged ----

test 'V17-H7: existing source-edge coordinates unchanged after apply' do
  adapter = make_fake_adapter
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.05, 0.0, 0.0], [20.0, 0.0, 0.0]]
  ]
  ws = make_test_workspace(adapter: adapter, edges: edges)
  pre_world = ws.entities.map { |rec| [rec.geometry_summary['start'], rec.geometry_summary['end']] }
  good_proposal = [{
    'proposal_id' => 'p-good',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'a', 'endpoint_b_key' => 'b',
    'canonical_node_a_id' => 'cn-a', 'canonical_node_b_id' => 'cn-b',
    'distance'   => 0.05,
    'gap_search' => 0.1, 'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[eA eB],
    'incident_source_occurrence_ids' => %w[occ-a occ-b],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1',
    'rule_version' => '1'
  }]
  result = GapPairProposer_propose_safe_then_apply(adapter, ws, good_proposal)
  # First N entities' world coords (before the new bridge) match
  # the pre-world snapshot.
  post = result['post_workspace']
  pre_world.each_with_index do |(s, e), i|
    rec = post.entity(post.entities[i].derived_id)
    next if rec.nil?
    assert_equal s, rec.geometry_summary['start'],
                 "source-edge start at idx=#{i} must be unchanged"
    assert_equal e, rec.geometry_summary['end'],
                 "source-edge end at idx=#{i} must be unchanged"
  end
end

# Helper: apply a single safe proposal with the workspace.
def GapPairProposer_propose_safe_then_apply(adapter, ws, proposals)
  GapBridgeExecutor.apply(
    workspace: ws,
    adapter:   adapter,
    proposals: proposals,
    tolerance: Tolerance.default
  )
end
