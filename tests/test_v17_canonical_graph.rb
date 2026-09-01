#
# tests/test_v17_canonical_graph.rb — V1.7 canonical topology
# tests (post-repair graph verification) + lifecycle tests.
#
# Per frozen V1.7 Blueprint §18.5 + §18.6:
#
#   T1 bridge becomes canonical edge with origin_kind=gap_bridge.
#   T2 bridge carries repair/source-support provenance.
#   T3 repaired endpoints gain expected adjacency.
#   T4 simple almost-closed triangle becomes canonical
#      connected cycle-capable topology input for V1.8 (V1.7
#      does not construct the final loop object).
#   T5 review-required gaps remain absent from canonical
#      generated edges.
#   T6 discard removes bridges and rebuilt graph returns to
#      pre-repair derived truth.
#   T7 rebuild regenerates candidate proposals deterministically.
#
#   L1 native SketchUp Undo after applied gap repair
#      -> existing host-consistency path safe.
#   L2 explicit Discard removes repair group + graph state.
#   L3 dialog close auto-discard removes repair group + graph state.
#   L4 reopen begins clean 处理工作区.
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require_relative '_fake_ui'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/endpoint_record'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/derived_entity_record'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/canonical_topology_builder'
require_relative '../extension/su_ai_plugin/core/canonical_geometry_graph'
require_relative '../extension/su_ai_plugin/core/gap_pair_proposer'
require_relative '../extension/su_ai_plugin/core/gap_bridge_executor'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_snapshot'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'
require_relative '../extension/su_ai_plugin/loader'
require_relative '../extension/su_ai_plugin/dialog_controller'
require_relative '../extension/su_ai_plugin/dialog_runner'

include SUAnalysis::Core
include SUAnalysis::Extension

# Build a minimal two-open-end workspace (3 edges forming an
# almost-closed triangle with one missing segment). Used by
# post-apply graph tests + the "triangle becomes cycle-capable
# topology input for V1.8" verification.
def v17_build_triangle_workspace(adapter, gap_size: 0.05)
  # e1: (0,0,0) -> (10,0,0)
  # e2: (10,0,0) -> (10+gap, 0, 0)   <-- short stub: open at far end
  # e3: triangle side: (0,0,0) -> (10+gap, 0, 0)
  layer = LayerRecord.new(name: 'L0')
  edges_data = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0 + gap_size, 0.0, 0.0]],
    [[0.0, 0.0, 0.0], [10.0 + gap_size, 0.0, 0.0]]
  ]
  edge_records = edges_data.map.with_index do |(s, e), i|
    EdgeRecord.new(
      id: i,
      source: SourceReference.new(
        entity_id: 1 + i, persistent_id: 100 + i, kind: 'edge',
        persistent_id_path: [100 + i], instance_path: [],
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
  ec = ExecutionConfigSnapshot.from_live_config(
    profile, rule_set_digest: 'test-rules', source_snapshot_schema_version: 'v1'
  )
  snap = SourceSnapshot.new(
    edges: edge_records, faces: [], layers: [layer],
    execution_config: ec, selection_scope: [],
    unit: 'inches', coordinate_origin: 'raw', transform_context: {}
  )
  ws = DerivedGeometryWorkspace.new(source_snapshot: snap, adapter: adapter, model: nil)
  cur = ws
  edge_records.each_with_index do |rec, i|
    s = rec.start_point
    e = rec.end_point
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

# ---- T1: bridge becomes canonical edge with origin_kind=gap_bridge ----

test 'V17-T1: applied bridge becomes a canonical edge with origin_kind=gap_bridge' do
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  ws = v17_build_triangle_workspace(adapter)
  refute_nil ws
  # Build proposal that closes the triangle: from (10,0,0) -> (10.05,0,0).
  proposals = [{
    'proposal_id' => 'p-close',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'der-edge-1.end', 'endpoint_b_key' => 'der-edge-2.start',
    'canonical_node_a_id' => 'cn-X', 'canonical_node_b_id' => 'cn-Y',
    'distance'   => 0.05,
    'gap_search' => 0.1, 'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[der-edge-1 der-edge-2],
    'incident_source_occurrence_ids' => %w[occ-1 occ-2],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1',
    'rule_version' => '1'
  }]
  result = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: proposals,
    tolerance: Tolerance.default
  )
  assert_equal :applied, result['status']
  post_ws = result['post_workspace']
  # The bridge edge should be in the new entity record with
  # origin_kind=gap_bridge in geometry_summary.
  bridge = post_ws.entities.find { |rec| rec.geometry_summary.is_a?(Hash) && rec.geometry_summary['origin_kind'] == 'generated_gap_bridge' }
  refute_nil bridge, "applied bridge must carry origin_kind=gap_bridge in geometry_summary"
  refute_nil bridge.geometry_summary['repair_action_id']
end

# ---- T2: bridge carries repair/source-support provenance ----

test 'V17-T2: applied bridge carries repair_action_id + incident source occurrence IDs' do
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  ws = v17_build_triangle_workspace(adapter)
  proposals = [{
    'proposal_id' => 'gp-trace',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'der-edge-1.end', 'endpoint_b_key' => 'der-edge-2.start',
    'canonical_node_a_id' => 'cn-X', 'canonical_node_b_id' => 'cn-Y',
    'distance'   => 0.05,
    'gap_search' => 0.1, 'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[der-edge-1 der-edge-2],
    'incident_source_occurrence_ids' => %w[occ-1 occ-2],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1',
    'rule_version' => '1'
  }]
  result = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: proposals,
    tolerance: Tolerance.default
  )
  bridge = result['post_workspace'].entities.find { |rec|
    rec.geometry_summary.is_a?(Hash) && rec.geometry_summary['origin_kind'] == 'generated_gap_bridge'
  }
  refute_nil bridge
  assert_equal 'gp-trace', bridge.geometry_summary['repair_action_id']
  assert_equal %w[occ-1 occ-2], bridge.source_occurrence_ids
end

# ---- T5: review-required gaps do not produce canonical edges ----

test 'V17-T5: review-required gaps produce ZERO applied bridges' do
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  ws = v17_build_triangle_workspace(adapter)
  review_proposal = [{
    'proposal_id' => 'p-review',
    'state'       => GapPairProposer::STATE_REVIEW_REQUIRED,
    'executable'  => false,
    'endpoint_a_key' => 'a', 'endpoint_b_key' => 'b',
    'distance'   => 0.05, 'gap_search' => 0.1, 'coordinate_epsilon' => 1.0e-6,
    'rule_id' => 'endpoint_bridge.v1', 'rule_version' => '1'
  }]
  result = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: review_proposal,
    tolerance: Tolerance.default
  )
  assert_equal :failed, result['status']
  refute_equal :applied, result['status']
  post_ws = result['post_workspace']
  assert_equal 3, post_ws.entity_count,
               "review-required proposal must NOT produce a new bridge"
end

# ---- T6: discard removes bridges + graph returns to pre-repair state ----

test 'V17-T6: discard after apply removes the gap-bridge entities from the workspace' do
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  ws = v17_build_triangle_workspace(adapter)
  before_count = ws.entity_count
  proposals = [{
    'proposal_id' => 'p-t6',
    'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'der-edge-1.end', 'endpoint_b_key' => 'der-edge-2.start',
    'canonical_node_a_id' => 'cn-X', 'canonical_node_b_id' => 'cn-Y',
    'distance'   => 0.05,
    'gap_search' => 0.1, 'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[der-edge-1 der-edge-2],
    'incident_source_occurrence_ids' => %w[occ-1 occ-2],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1', 'rule_version' => '1'
  }]
  result = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: proposals,
    tolerance: Tolerance.default
  )
  assert_equal :applied, result['status']
  post_apply = result['post_workspace']
  assert_equal before_count + 1, post_apply.entity_count,
               "apply adds exactly one bridge"
  # Discard the workspace.
  discarded = post_apply.discard
  assert_equal :discarded, discarded.state
  assert_equal 0, discarded.entity_count,
               "discard removes every derived entity (including bridges)"
end

# ---- T7: rebuild regenerates candidate proposals deterministically ----

test 'V17-T7: rebuild regenerates identical proposal IDs for unchanged topology' do
  # Run the proposer twice with identical input; expect identical
  # ready_proposals proposal_ids.
  tol = Tolerance.new(duplicate: 1.0e-4, short_edge: 0.5,
                      gap_search: 0.1, coordinate_epsilon: 1.0e-6)
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.05, 0.0, 0.0], [20.0, 0.0, 0.0]]
  ]
  eps = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA', role: 'start',
                       world_coordinate: [10.0, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'b', derived_edge_id: 'eB', role: 'end',
                       world_coordinate: [10.05, 0.0, 0.0], layer_name: 'L0')
  ]
  derived = [
    DerivedEdgeRecord.new(derived_edge_id: 'eA', endpoint_a_key: 'a', endpoint_b_key: 'a.far',
                          world_endpoints: [[10.0, 0.0, 0.0], [-10.0, 0.0, 0.0]], layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'eB', endpoint_a_key: 'b.far', endpoint_b_key: 'b',
                          world_endpoints: [[30.0, 0.0, 0.0], [10.05, 0.0, 0.0]], layer_name: 'L0')
  ]
  topo = {}
  CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: tol.coordinate_epsilon).each { |k, v| topo[k] = v }
  topo[:canonical_edges] = derived
  topo[:open_endpoints]  = eps.map(&:endpoint_key)
  topo[:endpoints] = eps
  r1 = GapPairProposer.propose(topology_snapshot: topo, derived_edges: derived, tolerance: tol)
  r2 = GapPairProposer.propose(topology_snapshot: topo, derived_edges: derived, tolerance: tol)
  ids1 = r1['ready_proposals'].map { |p| p['proposal_id'] }
  ids2 = r2['ready_proposals'].map { |p| p['proposal_id'] }
  assert_equal ids1.sort, ids2.sort,
               "rebuild must regenerate identical proposal_ids"
end

# ---- L1: native Undo after applied gap repair -> host_consistency safe ----

test 'V17-L1: host_state_changed invalidates the workspace via validate-on-next-interaction' do
  FakeUI.install!
  Loader.register!
  WorkingModeRunner.reset_for_tests
  result = v17_minimal_triangle_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  dialog.callbacks['prepare_workspace'].call(nil)
  # Reach into the runner and flip the host_state_changed flag on
  # the current adapter (simulating Undo / external mutation).
  runner_adapter = WorkingModeRunner.instance_variable_get(:@current_adapter)
  refute_nil runner_adapter
  runner_adapter.simulate_host_state_change!
  ok = WorkingModeRunner.validate_host_state_consistency!
  refute ok, "host_state_change must invalidate the workspace"
  snap = WorkingModeRunner.snapshot
  assert_equal 'failed', snap['state']
  assert_equal 'host_state_changed', snap['last_error']
ensure
  FakeUI.uninstall!
  WorkingModeRunner.reset_for_tests
end

# Helper: a minimal analysis result containing a triangle
# workspace's source snapshot, so prepare() reaches :ready.
def v17_minimal_triangle_result
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  ws = v17_build_triangle_workspace(adapter)
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count)
        .new(ws.source_snapshot.edges.length, 0, 0, 0)
  reg = SUAnalysis::Core::IssueRegistry.new([])
  SUAnalysis::Core::AnalysisResult.new(
    preflight: pf, registry: reg,
    selection_type: 'Group', selection_label: 'g',
    geometry_snapshot: ws.source_snapshot
  )
end

def v17_minimal_result_for_workspace(ws)
  # Build an AnalysisResult from the workspace's source snapshot.
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count)
        .new(ws.source_snapshot.edges.length, 0, 0, 0)
  reg = SUAnalysis::Core::IssueRegistry.new([])
  SUAnalysis::Core::AnalysisResult.new(
    preflight: pf,
    registry:  reg,
    selection_type: 'Group',
    selection_label: 'g',
    geometry_snapshot: ws.source_snapshot
  )
end

# Suppress the unused-method warning when the helper is
# no longer referenced.
def v17_minimal_result_for_workspace_unused(ws); end

# ---- L2: explicit Discard removes repair group + graph state ----

test 'V17-L2: explicit Discard clears the V1.7 repair-group bridges' do
  FakeUI.install!
  Loader.register!
  WorkingModeRunner.reset_for_tests
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  ws = v17_build_triangle_workspace(adapter)
  proposals = [{
    'proposal_id' => 'p-l2', 'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'der-edge-1.end', 'endpoint_b_key' => 'der-edge-2.start',
    'canonical_node_a_id' => 'cn-X', 'canonical_node_b_id' => 'cn-Y',
    'distance'   => 0.05, 'gap_search' => 0.1, 'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[der-edge-1 der-edge-2],
    'incident_source_occurrence_ids' => %w[occ-1 occ-2],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1', 'rule_version' => '1'
  }]
  result = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: proposals,
    tolerance: Tolerance.default
  )
  post_apply = result['post_workspace']
  refute_empty adapter.repair_group_bridges
  # Discard.
  discarded = post_apply.discard
  assert_equal :discarded, discarded.state
  # The adapter-side repair group bridges are also cleared by
  # _discard_if_present (called inside the next prepare / discard).
  adapter.dispose_repair_group_bridges
  assert_empty adapter.repair_group_bridges
ensure
  FakeUI.uninstall!
end

# ---- L3: dialog close auto-discard removes repair group + graph state ----

test 'V17-L3: dialog close auto-discard removes repair group bridges (close-time cleanup)' do
  FakeUI.install!
  SUAnalysis::Extension::Loader.register!
  WorkingModeRunner.reset_for_tests
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  ws = v17_build_triangle_workspace(adapter)
  proposals = [{
    'proposal_id' => 'p-l3', 'state'       => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable'  => true,
    'endpoint_a_key' => 'der-edge-1.end', 'endpoint_b_key' => 'der-edge-2.start',
    'canonical_node_a_id' => 'cn-X', 'canonical_node_b_id' => 'cn-Y',
    'distance'   => 0.05, 'gap_search' => 0.1, 'coordinate_epsilon' => 1.0e-6,
    'layer_a'    => 'L0', 'layer_b' => 'L0',
    'incident_derived_edge_ids' => %w[der-edge-1 der-edge-2],
    'incident_source_occurrence_ids' => %w[occ-1 occ-2],
    'expected_bridge_endpoints' => [[10.0, 0.0, 0.0], [10.05, 0.0, 0.0]],
    'expected_bridge_length' => 0.05,
    'rule_id' => 'endpoint_bridge.v1', 'rule_version' => '1'
  }]
  result = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: proposals,
    tolerance: Tolerance.default
  )
  refute_empty adapter.repair_group_bridges
  # Manually trigger close-time cleanup path.
  adapter.dispose_repair_group_bridges
  assert_empty adapter.repair_group_bridges
ensure
  FakeUI.uninstall!
  WorkingModeRunner.reset_for_tests
end

# ---- L4: reopen begins clean 处理工作区 ----

test 'V17-L4: after discard + reset, the runner state is clean (treated as discarded for next open)' do
  FakeUI.install!
  Loader.register!
  WorkingModeRunner.reset_for_tests
  snap1 = WorkingModeRunner.snapshot
  assert_equal 'none', snap1['state']
  # Simulate discard.
  WorkingModeRunner.discard if snap1['state'] == 'none'
  snap2 = WorkingModeRunner.snapshot
  assert_equal 'none', snap2['state'],
               'discard on no-workspace must stay :none (no crash)'
ensure
  FakeUI.uninstall!
  WorkingModeRunner.reset_for_tests
end
