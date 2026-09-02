#
# tests/test_v18_working_mode_integration.rb — V1.8 base structure
# reconstruction working-mode integration tests.
#
# Dispatch: V18-BASE-STRUCTURE-RECONSTRUCTION-2026-09-02.
# Frozen Blueprint:
# Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_8_LOOP_REGION_2026-09-02.md.
#
# This file drives the REAL production entry point:
#   SUAnalysis::Core::WorkingModeRunner.compute_structure_reconstruction
# so test and production cannot silently diverge. Per Blueprint
# §19 integration test matrix is V18-I01..I05.
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
require_relative '../extension/su_ai_plugin/core/canonical_geometry_graph'
require_relative '../extension/su_ai_plugin/core/segment_conflict'
require_relative '../extension/su_ai_plugin/core/gap_pair_proposer'
require_relative '../extension/su_ai_plugin/core/gap_bridge_executor'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_snapshot'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'
require_relative '../extension/su_ai_plugin/core/canonical_structure_reconstructor'

include SUAnalysis::Core

# ---------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------

V18INT_RUNNER = SUAnalysis::Core::WorkingModeRunner

def v18int_tol(gap_search = 0.1, coord_eps = 1.0e-6)
  Tolerance.new(duplicate: 1.0e-4, short_edge: 0.5,
                gap_search: gap_search, coordinate_epsilon: coord_eps)
end

def v18int_source(edges, tolerance = v18int_tol)
  layer = LayerRecord.new(name: 'L0')
  recs = edges.map.with_index do |(s, e), i|
    EdgeRecord.new(
      id: i,
      source: SourceReference.new(
        entity_id: 1 + i, persistent_id: 100 + i, kind: 'edge',
        persistent_id_path: [100 + i], instance_path: [],
        structural_depth: 0, pid_path_complete: true, layer_name: 'L0'
      ),
      start_point: s, end_point: e, layer: 'L0'
    )
  end
  profile = Struct.new(:profile_name, :tolerance).new('v18int', tolerance)
  ec = ExecutionConfigSnapshot.from_live_config(
    profile, rule_set_digest: 'v18int-rules',
    source_snapshot_schema_version: 'v1'
  )
  SourceSnapshot.new(
    edges: recs, faces: [], layers: [layer], execution_config: ec,
    selection_scope: [], unit: 'inches', coordinate_origin: 'raw',
    transform_context: {}
  )
end

def v18int_prepare(edges, tolerance = v18int_tol)
  V18INT_RUNNER.reset_for_tests
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  snap = V18INT_RUNNER.prepare(
    source: v18int_source(edges, tolerance), adapter: adapter, model: nil
  )
  unless snap['state'] == 'ready'
    raise "v18int_prepare expected 'ready'; got #{snap['state']} (#{snap['last_error'].inspect})"
  end
  adapter
end

# ================================================================= = #
# V18-I01 — prepare -> compute_structure_reconstruction without
# running gap repair. Must work.
# ================================================================= = #

test 'V18-I01: prepare -> compute_structure_reconstruction without gap repair' do
  v18int_prepare([
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ])
  snap = V18INT_RUNNER.compute_structure_reconstruction
  sr = snap['structure_reconstruction']
  refute_nil sr, "V18-I01: structure_reconstruction must be in the snapshot"
  assert_equal 'READY', sr['state'],
               "V18-I01: state should be READY for a clean rectangle; got #{sr['state']}"
  assert sr['computed'] == true,
         "V18-I01: computed should be true; got #{sr['computed']}"
  refute_nil sr['digest'],
             "V18-I01: result digest must be present"
  assert sr['metrics']['closed_loop_count'] == 1,
         "V18-I01: 1 closed loop; got #{sr['metrics']}"
  assert sr['metrics']['region_count'] == 1,
         "V18-I01: 1 region; got #{sr['metrics']}"
  assert sr['metrics']['open_chain_count'] == 0,
         "V18-I01: 0 open chains; got #{sr['metrics']}"
end

# ================================================================= = #
# V18-I02 — V1.7 gap apply -> compute structure detects closed loop.
# ================================================================= = #

test 'V18-I02: V1.7 gap apply -> compute structure detects newly closed loop' do
  v18int_prepare([
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[0.0, 0.0, 0.0], [4.975, -6.0, 0.0]],
    [[10.0, 0.0, 0.0], [5.025, -6.0, 0.0]]
  ], v18int_tol(0.1))
  V18INT_RUNNER.compute_gap_repair
  apply_snap = V18INT_RUNNER.apply_gap_repair
  audit_status = apply_snap.dig('topology_repair', 'audit', 'status').to_s
  assert_equal 'applied', audit_status,
               "V18-I02: gap apply must succeed; got #{audit_status}"
  # After the apply, the structure reconstruction has been
  # invalidated. The next compute must rebuild from the
  # post-apply canonical graph.
  snap = V18INT_RUNNER.compute_structure_reconstruction
  sr = snap['structure_reconstruction']
  refute_nil sr
  assert sr['metrics']['closed_loop_count'] == 1,
         "V18-I02: post-apply must detect 1 closed loop; got #{sr['metrics']}"
  assert sr['metrics']['region_count'] == 1,
         "V18-I02: post-apply must detect 1 region; got #{sr['metrics']}"
end

# ================================================================= = #
# V18-I03 — discard / rebuild clears stale V1.8 result.
# ================================================================= = #

test 'V18-I03: discard / rebuild clears stale V1.8 result' do
  v18int_prepare([
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ])
  snap1 = V18INT_RUNNER.compute_structure_reconstruction
  refute_equal 'NOT_COMPUTED', snap1['structure_reconstruction']['state']
  V18INT_RUNNER.discard
  discarded = V18INT_RUNNER.snapshot
  assert_equal 'discarded', discarded['state'],
               "V18-I03: discard must transition to discarded; got #{discarded['state']}"
  assert_equal 'NOT_COMPUTED', discarded['structure_reconstruction']['state'],
               "V18-I03: discard must clear V1.8 result to NOT_COMPUTED"
  V18INT_RUNNER.rebuild
  rebuilt = V18INT_RUNNER.snapshot
  assert_equal 'ready', rebuilt['state'],
               "V18-I03: rebuild must restore ready; got #{rebuilt['state']}"
  assert_equal 'NOT_COMPUTED', rebuilt['structure_reconstruction']['state'],
               "V18-I03: rebuild must clear V1.8 result to NOT_COMPUTED"
end

# ================================================================= = #
# V18-I04 — native host invalidation seam: compute structure
# validates first and fails closed with `host_state_changed`.
# ================================================================= = #

test 'V18-I04: native host invalidation -> compute structure fails closed with host_state_changed' do
  v18int_prepare([
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ])
  V18INT_RUNNER.compute_structure_reconstruction
  adapter = V18INT_RUNNER.instance_variable_get(:@current_adapter)
  adapter.simulate_host_state_change!
  snap = V18INT_RUNNER.compute_structure_reconstruction
  sr = snap['structure_reconstruction']
  assert_equal 'FAILED', sr['state'],
               "V18-I04: state must be FAILED on host_state_change; got #{sr['state']}"
  assert_includes Array(sr['unresolved_issues']),
                  'host_state_changed',
                  "V18-I04: must emit host_state_changed"
  # And the workspace itself is now :failed.
  assert_equal 'failed', snap['state'],
               "V18-I04: workspace must be :failed on host_state_change; got #{snap['state']}"
end

# ================================================================= = #
# V18-I05 — compute structure opens zero host operations.
# ================================================================= = #

test 'V18-I05: compute_structure_reconstruction opens zero host operations' do
  v18int_prepare([
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ])
  adapter = V18INT_RUNNER.instance_variable_get(:@current_adapter)
  ops_before = adapter.operation_log.length
  V18INT_RUNNER.compute_structure_reconstruction
  V18INT_RUNNER.compute_structure_reconstruction
  V18INT_RUNNER.compute_structure_reconstruction
  ops_after = adapter.operation_log.length
  assert_equal 0, ops_after - ops_before,
               "V18-I05: compute_structure_reconstruction must NOT open host operations; " \
               "got #{ops_after - ops_before} new operations"
end
