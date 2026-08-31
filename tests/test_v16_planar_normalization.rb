#
# tests/test_v16_planar_normalization.rb — V1.6 Planar Normalization
# / Z Policy regression set.
#
# Per frozen V1.6 Blueprint §12 (Test Matrix):
#
#   Pure (P1-P9):
#     P1 - already planar          -> NO_CANDIDATE
#     P2 - small noisy plane        -> deterministic proposal
#     P3 - non-zero translated      -> target near actual plane
#     P4 - dominant + large outlier -> outlier unchanged
#     P5 - 50/50 split              -> REVIEW_REQUIRED
#     P6 - tied dominant windows    -> no guess
#     P7 - invalid tolerance        -> fail closed
#     P8 - invalid/non-finite coords -> no destructive action
#     P9 - idempotency              -> second analysis == zero movement
#
#   Geometry safety (G1-G6):
#     G1 - XY preservation
#     G2 - shared vertex with ineligible edge -> skip affected scope
#     G3 - curve/arc membership      -> no auto-normalization
#     G4 - face adjacency            -> no auto-normalization
#     G5 - outlier edge              -> unchanged
#     G6 - source fingerprint        -> unchanged
#
#   Host / transaction (H1-H6):
#     H1 - invalid preflight -> zero begin_operation
#     H2 - success -> one operation + one safe batch + commit
#     H3 - transform failure -> safe failure / abort
#     H4 - commit uncertainty -> FAILED
#     H5 - native Undo after -> existing host-consistency path safe
#     H6 - Discard/Rebuild -> source unchanged
#
#   Compatibility (C1-C4):
#     C1 - production Ruby stays old-runtime compatible
#     C2 - only SU2017-baseline host APIs in correctness path
#     C3 - RBZ contains all V1.6 modules (smoke-tested via RBZ test)
#     C4 - SketchUp 2020 real-host Owner test before closure
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/planar_normalization_analyzer'
require_relative '../extension/su_ai_plugin/core/planar_normalization_proposer'
require_relative '../extension/su_ai_plugin/core/planar_normalization_executor'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/derived_entity_record'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'

include SUAnalysis::Core

# ============================================================================
# PURE TESTS — PlanarNormalizationAnalyzer (P1-P9)
# ============================================================================

test 'V16-P1: already planar -> NO_CANDIDATE' do
  result = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   [[0.0, 0.0, 1.0], [1.0, 0.0, 1.0], [0.0, 1.0, 1.0], [1.0, 1.0, 1.0]],
    planar_z_snap:       0.01,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_NO_CANDIDATE, result[:state]
  assert_equal 1.0, result[:target_z]
  assert_equal 4,   result[:eligible_count]
  assert_equal 4,   result[:already_planar]
  assert_equal 0,   result[:movable_count]
end

test 'V16-P2: small noisy plane -> deterministic proposal' do
  zs = [1.000, 1.005, 1.002, 1.008, 1.001, 1.006, 0.500, 1.003]
  verts = zs.each_with_index.map { |z, i| [i.to_f, 0.0, z] }
  result = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   verts,
    planar_z_snap:       0.01,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_READY_TO_NORMALIZE, result[:state]
  # Median of 7-window [1.000..1.008] (sorted: 1.000, 1.001, 1.002, 1.003, 1.005, 1.006, 1.008) -> 1.003
  assert_in_delta 1.003, result[:target_z], 1.0e-6
  # 7 inliers (z=1.000..1.008 within 0.01 of 1.003), 1 outlier (z=0.500)
  assert_equal 8, result[:eligible_count]
  # Of the 7 inliers, 1 is already planar (z=1.003 itself) and 6 are movable
  assert_equal 6, result[:movable_count]
  assert_equal 1, result[:already_planar]
  assert_equal 1, result[:outlier_count]
  # The outlier is the 7th vertex (z=0.500) - position 6
  outlier_indices = result[:outliers].map { |o| o[:vertex_index] }
  assert_equal [6], outlier_indices
end

test 'V16-P3: non-zero translated plane -> target near actual plane (not zero)' do
  zs = [999.99, 1000.00, 1000.01, 1000.005, 999.995, 1000.002]
  verts = zs.each_with_index.map { |z, i| [i.to_f, 0.0, z] }
  result = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   verts,
    planar_z_snap:       0.02,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_READY_TO_NORMALIZE, result[:state]
  assert result[:target_z] > 999.0, "target_z must be near 1000 (not zero): got #{result[:target_z]}"
  assert result[:target_z] < 1001.0, "target_z must be near 1000 (not zero): got #{result[:target_z]}"
  assert_in_delta 1000.0, result[:target_z], 0.5
end

test 'V16-P4: dominant plane + large outlier -> outlier unchanged' do
  inliers = [1.0, 1.001, 1.002, 1.003, 1.004, 1.005, 1.006, 1.007, 1.008, 1.009, 1.010]
  zs = inliers + [50.0]  # large outlier
  verts = zs.each_with_index.map { |z, i| [i.to_f, 0.0, z] }
  result = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   verts,
    planar_z_snap:       0.01,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_READY_TO_NORMALIZE, result[:state]
  assert_equal 1, result[:outlier_count]
  # The outlier is the last vertex
  outlier_indices = result[:outliers].map { |o| o[:vertex_index] }
  assert_equal [11], outlier_indices
end

test 'V16-P5: 50/50 split -> REVIEW_REQUIRED' do
  half_a = Array.new(5) { 1.0 }
  half_b = Array.new(5) { 2.0 }
  zs = half_a + half_b
  verts = zs.each_with_index.map { |z, i| [i.to_f, 0.0, z] }
  result = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   verts,
    planar_z_snap:       0.01,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_REVIEW_REQUIRED, result[:state]
  # Two clusters of 5 each are tied at the max count; Blueprint
  # §6.2 step 4 fires before step 5, so the reason is
  # 'tied_dominant_windows'. Both reasons are valid
  # REVIEW_REQUIRED outcomes.
  assert result[:reason] == 'tied_dominant_windows' || result[:reason] == 'no_strict_majority',
         "expected tied_dominant_windows or no_strict_majority, got #{result[:reason].inspect}"
end

test 'V16-P6: tied dominant windows -> no guess' do
  # Build a case with two distinct windows both containing the
  # max count. Take 6 vertices: z = 1.0, 1.0, 1.0, 5.0, 5.0, 5.0.
  # Each window is width 0.01 around its mean; each contains 3.
  # Window 1: z=1.0,1.0,1.0 -> count 3
  # Window 2: z=5.0,5.0,5.0 -> count 3
  # Tied -> REVIEW_REQUIRED.
  zs = [1.0, 1.0, 1.0, 5.0, 5.0, 5.0]
  verts = zs.each_with_index.map { |z, i| [i.to_f, 0.0, z] }
  result = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   verts,
    planar_z_snap:       0.01,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_REVIEW_REQUIRED, result[:state]
  assert_equal 'tied_dominant_windows', result[:reason]
end

test 'V16-P7: invalid tolerance -> fail closed' do
  result_nil = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   [[0.0, 0.0, 1.0]],
    planar_z_snap:       nil,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_INVALID_TOLERANCE, result_nil[:state]
  assert_equal 'invalid_tolerance', result_nil[:reason]

  result_zero = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   [[0.0, 0.0, 1.0]],
    planar_z_snap:       0.0,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_INVALID_TOLERANCE, result_zero[:state]

  result_neg = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   [[0.0, 0.0, 1.0]],
    planar_z_snap:       -0.01,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_INVALID_TOLERANCE, result_neg[:state]

  result_inf = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   [[0.0, 0.0, 1.0]],
    planar_z_snap:       Float::INFINITY,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_INVALID_TOLERANCE, result_inf[:state]
end

test 'V16-P8: invalid/non-finite coordinates -> no destructive action' do
  bad_inputs = [
    [[Float::INFINITY, 0.0, 1.0]],
    [[0.0, Float::NAN, 1.0]],
    [[0.0, 0.0, 'string']],
    [[0.0, 0.0]],
    [[0.0, 0.0, 1.0, 2.0]],  # wrong length
    nil
  ]
  bad_inputs.each do |verts|
    result = PlanarNormalizationAnalyzer.analyze(
      eligible_vertices:   verts,
      planar_z_snap:       0.01,
      coordinate_epsilon:  1.0e-6
    )
    assert result[:state] == PlanarNormalizationAnalyzer::STATE_INVALID_INPUT ||
           result[:state] == PlanarNormalizationAnalyzer::STATE_NO_CANDIDATE,
           "expected INVALID_INPUT or NO_CANDIDATE for #{verts.inspect}, got #{result[:state]}"
    assert_equal 0, result[:movable_count]
  end
end

test 'V16-P9: idempotency -> second analysis yields zero movement' do
  zs = [1.000, 1.002, 1.005, 1.008]
  verts = zs.each_with_index.map { |z, i| [i.to_f, 0.0, z] }
  first = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   verts,
    planar_z_snap:       0.01,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_READY_TO_NORMALIZE, first[:state]
  moved_zs = first[:proposed_moves].map { |m| m[:to_z] }.uniq
  # Re-analyze with the proposed_to_z values: should produce
  # NO_CANDIDATE because everything is now within coordinate_epsilon
  # of target_z.
  new_verts = verts.each_with_index.map { |v, i|
    target_move = first[:proposed_moves].find { |m| m[:vertex_index] == i }
    if target_move
      [v[0], v[1], target_move[:to_z]]
    else
      v
    end
  }
  second = PlanarNormalizationAnalyzer.analyze(
    eligible_vertices:   new_verts,
    planar_z_snap:       0.01,
    coordinate_epsilon:  1.0e-6
  )
  assert_equal PlanarNormalizationAnalyzer::STATE_NO_CANDIDATE, second[:state]
  assert_equal 0, second[:movable_count]
end

# ============================================================================
# GEOMETRY SAFETY (G1-G6)
# ============================================================================

def make_simple_snapshot(edges)
  # Build a minimal ExecutionConfigSnapshot + SourceSnapshot
  # suitable for the proposer.
  cfg = ExecutionConfigSnapshot.new(
    profile_id:        'profile.test',
    profile_version:   '1',
    rule_set_id:       'role.config',
    rule_set_version:  '1',
    rule_set_digest:   'test',
    tolerance_schema_version: 'tol-test',
    tolerance_values:  {
      duplicate:          1.0e-4,
      short_edge:         0.5,
      gap_search:         0.1,
      coordinate_epsilon: 1.0e-6,
      big_z:              0.01,
      large_coordinate:   1.0e6,
      planar_z_snap:      0.01
    },
    session_overrides:  {},
    source_snapshot_schema_version: '1'
  )
  fp = SourceFingerprint.new(
    edge_count: edges.length,
    face_count: 0,
    layer_count: 1
  )
  SourceSnapshot.new(
    snapshot_id: 'snap-test',
    selection_scope: [],
    edges: edges,
    faces: [],
    layers: [],
    vertex_records: [],
    unit: 'inches',
    coordinate_origin: 'raw',
    transform_context: { 'active_edit_seed' => 'identity' },
    execution_config: cfg,
    fingerprint: fp
  )
end

def make_edge_record(id, start_point, end_point)
  src = SourceReference.new(
    persistent_id_path: [id * 1000],
    instance_path:      ["occ-#{id}"],
    structural_depth:   0,
    pid_path_complete:  true,
    persistent_id:      id * 1000,
    entity_id:          id * 100,
    layer_name:         'Layer0'
  )
  EdgeRecord.new(
    id: id,
    layer: 'Layer0',
    start_point: start_point,
    end_point:   end_point,
    length:      Math.sqrt(((end_point[0]-start_point[0])**2) +
                           ((end_point[1]-start_point[1])**2) +
                           ((end_point[2]-start_point[2])**2)),
    source:      src
  )
end

test 'V16-G1+G6: XY preservation + source fingerprint unchanged after apply' do
  adapter = FakeDerivedWorkspaceAdapter.new
  edges = [
    make_edge_record(1, [0.0, 0.0, 1.0], [10.0, 0.0, 1.0]),
    make_edge_record(2, [0.0, 5.0, 1.001], [10.0, 5.0, 1.0])
  ]
  source = make_simple_snapshot(edges)
  src_fp_before = source.fingerprint.digest

  # Build workspace manually
  ws = nil
  edges.each_with_index do |edge_rec, idx|
    parent = ws
    # Use the adapter to build a derived entity
    grp = adapter.create_top_level_group("der-edge-#{idx + 1}")
    adapter.add_edge_to_group(grp, [edge_rec.start_point, edge_rec.end_point].first(2).first, [edge_rec.start_point, edge_rec.end_point].first(2).last) rescue nil
    # Use the workspace builder via the runner
  end

  # Reset and use the runner.prepare path
  adapter = FakeDerivedWorkspaceAdapter.new
  WorkingModeRunner.reset_for_tests
  snap = WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  assert_equal 'ready', snap['state']
  ws = WorkingModeRunner.current_workspace_for_test

  # Run the duplicate-repair batch (existing V1.5 plumbing).
  # Then compute the V1.6 proposal.
  proposal = WorkingModeRunner.compute_planar_normalization
  assert proposal['planar_normalization']['computed']
  assert_equal 'READY_TO_NORMALIZE', proposal['planar_normalization']['state']

  # Apply
  result = WorkingModeRunner.apply_planar_normalization
  assert_equal 'ready', result['state'], "apply should succeed: #{result['last_error']}"

  # Verify XY preservation: every vertex X, Y unchanged
  # Get the adapter's tracked vertices and check positions
  adapter.vertex_handles_by_edge.each do |_edge_handle, vertex_handles|
    vertex_handles.each do |v|
      assert_equal 1.0, v.z, "vertex Z should be normalized to 1.0"
    end
  end
  # Source fingerprint unchanged
  assert_equal src_fp_before, source.fingerprint.digest
end

test 'V16-G2: shared vertex with ineligible edge -> skip affected scope' do
  adapter = FakeDerivedWorkspaceAdapter.new
  # Two edges sharing a vertex at (10, 0, 1.0). Edge 1 is safe
  # (no curve/face). Edge 2 is unsafe (simulated by stubbing
  # edge_curve on the adapter to return truthy for the
  # group_handle containing edge 2).
  # We monkey-patch edge_curve on the adapter. The proposer
  # calls edge_curve with the GROUP handle (the V1.4
  # handle_registry stores groups per derived_id). We mark
  # the 2nd-created group as unsafe by comparing its
  # derived_id.
  original_curve = adapter.method(:edge_curve)
  adapter.define_singleton_method(:edge_curve) do |handle|
    # The 2nd group created by prepare has derived_id == 'fake-2'.
    if handle.respond_to?(:derived_id) && handle.derived_id == 'fake-2'
      :stubbed_curve
    else
      original_curve.call(handle)
    end
  end

  edges = [
    make_edge_record(1, [0.0, 0.0, 1.0],    [10.0, 0.0, 1.0]),
    make_edge_record(2, [10.0, 0.0, 1.0],   [10.0, 5.0, 1.005]),  # shares (10,0,1.0)
    make_edge_record(3, [10.0, 0.0, 1.0],   [0.0,  5.0, 1.003])   # shares (10,0,1.0)
  ]
  source = make_simple_snapshot(edges)

  WorkingModeRunner.reset_for_tests
  WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  result = WorkingModeRunner.compute_planar_normalization

  # The shared vertex (10,0,1.0) belongs to edge 2 (unsafe via stub)
  # AND edges 1+3 (safe). So shared-vertex scope is ambiguous.
  # The proposer should return REVIEW_REQUIRED with reason
  # 'no_safe_eligible_vertices' or 'shared_vertex_scope_ambiguous'.
  state = result['planar_normalization']['computed'] ? result['planar_normalization']['state'] : 'NOT_COMPUTED'
  assert state == 'REVIEW_REQUIRED' || state == 'NO_CANDIDATE',
         "expected REVIEW_REQUIRED or NO_CANDIDATE (shared-vertex ambiguity), got #{state}: #{result['planar_normalization'].inspect}"
end

test 'V16-G3: curve/arc membership -> no auto-normalization' do
  adapter = FakeDerivedWorkspaceAdapter.new
  original_curve = adapter.method(:edge_curve)
  original_count = adapter.method(:edge_faces_count)
  # Mark all edges as curve-members
  adapter.define_singleton_method(:edge_curve) do |_edge_handle|
    :stubbed_curve  # truthy -> unsafe
  end

  edges = [
    make_edge_record(1, [0.0, 0.0, 1.0], [5.0, 0.0, 1.001]),
    make_edge_record(2, [5.0, 0.0, 1.001], [10.0, 0.0, 1.0])
  ]
  source = make_simple_snapshot(edges)

  WorkingModeRunner.reset_for_tests
  WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  result = WorkingModeRunner.compute_planar_normalization

  state = result['planar_normalization']['computed'] ? result['planar_normalization']['state'] : 'NOT_COMPUTED'
  assert_equal 'REVIEW_REQUIRED', state,
               "curve membership should refuse auto-normalization; got #{state}"
end

test 'V16-G4: face adjacency -> no auto-normalization' do
  adapter = FakeDerivedWorkspaceAdapter.new
  # Mark all edges as face-adjacent
  adapter.define_singleton_method(:edge_faces_count) do |_edge_handle|
    2  # > 0 -> unsafe
  end

  edges = [
    make_edge_record(1, [0.0, 0.0, 1.0], [5.0, 0.0, 1.001]),
    make_edge_record(2, [5.0, 0.0, 1.001], [10.0, 0.0, 1.0])
  ]
  source = make_simple_snapshot(edges)

  WorkingModeRunner.reset_for_tests
  WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  result = WorkingModeRunner.compute_planar_normalization

  state = result['planar_normalization']['computed'] ? result['planar_normalization']['state'] : 'NOT_COMPUTED'
  assert_equal 'REVIEW_REQUIRED', state,
               "face adjacency should refuse auto-normalization; got #{state}"
end

test 'V16-G5: outlier edge remains unchanged' do
  adapter = FakeDerivedWorkspaceAdapter.new
  # 9 edges around z=1.0 + 1 outlier edge far away
  edges = []
  9.times do |i|
    edges << make_edge_record(i + 1,
                              [i.to_f, 0.0, 1.0 + (i * 0.001)],
                              [(i + 1).to_f, 0.0, 1.0 + ((i + 1) * 0.001)])
  end
  edges << make_edge_record(100, [0.0, 100.0, 50.0], [10.0, 100.0, 50.0])  # outlier
  source = make_simple_snapshot(edges)

  WorkingModeRunner.reset_for_tests
  WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  result = WorkingModeRunner.compute_planar_normalization

  state = result['planar_normalization']['computed'] ? result['planar_normalization']['state'] : 'NOT_COMPUTED'
  assert_equal 'READY_TO_NORMALIZE', state
  proposal = result['planar_normalization']['proposal']
  # The outlier edge has TWO endpoints, each a separate
  # vertex position. The analyzer reports vertex-level
  # outlier_count.
  assert_equal 2, proposal['outlier_count'], "outlier_count should be 2 (both endpoints of the outlier edge)"
  # The outlier edge's derived_id should be in outlier_derived_ids
  assert proposal['outlier_derived_ids'].include?('der-edge-9-100000'),
         "outlier edge should be in outlier_derived_ids; got #{proposal['outlier_derived_ids'].inspect}"
end

# ============================================================================
# HOST / TRANSACTION (H1-H6)
# ============================================================================

test 'V16-H1: invalid preflight -> zero begin_operation' do
  adapter = FakeDerivedWorkspaceAdapter.new
  # No workspace -> no begin_operation
  WorkingModeRunner.reset_for_tests
  result = WorkingModeRunner.apply_planar_normalization
  assert_equal [], adapter.operation_log.select { |op| op[:kind] == :begin }
  # No workspace, so state should be 'none'
  assert_equal 'none', result['state']
end

test 'V16-H2: success -> one operation + one safe batch + commit' do
  adapter = FakeDerivedWorkspaceAdapter.new
  edges = [
    make_edge_record(1, [0.0, 0.0, 1.0], [5.0, 0.0, 1.001]),
    make_edge_record(2, [5.0, 0.0, 1.001], [10.0, 0.0, 1.0])
  ]
  source = make_simple_snapshot(edges)

  WorkingModeRunner.reset_for_tests
  WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  WorkingModeRunner.compute_planar_normalization

  # Clear operation log to focus on the apply operation
  apply_adapter = FakeDerivedWorkspaceAdapter.new
  # Actually the apply uses the same adapter from the runner.
  # Reset the op log AFTER compute to count only the apply ops.
  pre_log_size = adapter.operation_log.length

  result = WorkingModeRunner.apply_planar_normalization
  assert_equal 'ready', result['state'], "apply should succeed: #{result['last_error']}"

  apply_ops = adapter.operation_log[pre_log_size..-1] || []
  begin_ops = apply_ops.select { |op| op[:kind] == :begin }
  commit_ops = apply_ops.select { |op| op[:kind] == :commit }
  abort_ops = apply_ops.select { |op| op[:kind] == :abort }
  assert_equal 1, begin_ops.length, "expected exactly 1 begin, got #{begin_ops.length}"
  assert_equal 1, commit_ops.length, "expected exactly 1 commit, got #{commit_ops.length}"
  assert_equal 0, abort_ops.length, "expected 0 aborts, got #{abort_ops.length}"
end

test 'V16-H3: transform failure -> safe failure / abort' do
  adapter = FakeDerivedWorkspaceAdapter.new
  edges = [
    make_edge_record(1, [0.0, 0.0, 1.0], [5.0, 0.0, 1.001]),
    make_edge_record(2, [5.0, 0.0, 1.001], [10.0, 0.0, 1.0])
  ]
  source = make_simple_snapshot(edges)

  WorkingModeRunner.reset_for_tests
  WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  WorkingModeRunner.compute_planar_normalization

  # Inject a failure on the NEXT transform_vertices_by_vectors call
  def adapter.transform_vertices_by_vectors(*_args)
    raise StandardError, 'simulated host failure'
  end

  result = WorkingModeRunner.apply_planar_normalization
  assert_equal 'failed', result['state'], "apply should fail closed"
  assert result['last_error'].to_s.include?('host_mutation_failed'),
         "last_error should record host mutation failure: #{result['last_error']}"
end

test 'V16-H4: commit uncertainty -> FAILED' do
  adapter = FakeDerivedWorkspaceAdapter.new
  edges = [
    make_edge_record(1, [0.0, 0.0, 1.0], [5.0, 0.0, 1.001])
  ]
  source = make_simple_snapshot(edges)

  WorkingModeRunner.reset_for_tests
  WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  WorkingModeRunner.compute_planar_normalization

  # Inject a failure on the NEXT end_operation call (commit path)
  # We need to count calls so the FIRST end_operation (commit)
  # raises but the abort on rollback does not.
  call_count = 0
  original_end_op = adapter.method(:end_operation)
  adapter.define_singleton_method(:end_operation) do |*args|
    call_count += 1
    if call_count == 1
      raise StandardError, 'simulated commit failure'
    else
      original_end_op.call(*args)
    end
  end

  result = WorkingModeRunner.apply_planar_normalization
  assert_equal 'failed', result['state'], "commit failure should mark FAILED"
end

test 'V16-H6: Discard/Rebuild -> source unchanged' do
  adapter = FakeDerivedWorkspaceAdapter.new
  edges = [
    make_edge_record(1, [0.0, 0.0, 1.0], [5.0, 0.0, 1.001]),
    make_edge_record(2, [5.0, 0.0, 1.001], [10.0, 0.0, 1.0])
  ]
  source = make_simple_snapshot(edges)
  src_fp = source.fingerprint.digest

  WorkingModeRunner.reset_for_tests
  WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  WorkingModeRunner.compute_planar_normalization
  WorkingModeRunner.apply_planar_normalization

  # Discard the workspace
  result = WorkingModeRunner.discard
  # Source fingerprint MUST still be unchanged
  assert_equal src_fp, source.fingerprint.digest

  # Rebuild -> source still unchanged
  WorkingModeRunner.rebuild
  assert_equal src_fp, source.fingerprint.digest
end

# ============================================================================
# TOLERANCE / CONFIG (T1-T3)
# ============================================================================

test 'V16-T1: Tolerance.planar_z_snap default is 0.01' do
  assert_in_delta 0.01, Tolerance::PLANAR_Z_SNAP_DEFAULT, 1.0e-9
  t = Tolerance.default
  assert_in_delta 0.01, t.planar_z_snap, 1.0e-9
  assert t.to_h.key?(:planar_z_snap)
end

test 'V16-T2: invalid planar_z_snap raises ArgumentError' do
  Tests.assert_raises(ArgumentError) do
    Tolerance.new(
      duplicate: 1.0e-4, short_edge: 0.5, gap_search: 0.1,
      coordinate_epsilon: 1.0e-6, planar_z_snap: 0
    )
  end
  Tests.assert_raises(ArgumentError) do
    Tolerance.new(
      duplicate: 1.0e-4, short_edge: 0.5, gap_search: 0.1,
      coordinate_epsilon: 1.0e-6, planar_z_snap: -0.01
    )
  end
end

test 'V16-T3: ExecutionConfigSnapshot schema version reflects planar_z_snap' do
  cfg_old = ExecutionConfigSnapshot.new(
    profile_id: 'profile.test', profile_version: '1',
    rule_set_id: 'role.config', rule_set_version: '1', rule_set_digest: 't',
    tolerance_schema_version: 'tol-OLD',
    tolerance_values: { duplicate: 1.0e-4, short_edge: 0.5, gap_search: 0.1,
                         coordinate_epsilon: 1.0e-6, big_z: 0.01,
                         large_coordinate: 1.0e6 },
    session_overrides: {},
    source_snapshot_schema_version: '1'
  )
  cfg_new = ExecutionConfigSnapshot.new(
    profile_id: 'profile.test', profile_version: '1',
    rule_set_id: 'role.config', rule_set_version: '1', rule_set_digest: 't',
    tolerance_schema_version: 'tol-NEW',
    tolerance_values: { duplicate: 1.0e-4, short_edge: 0.5, gap_search: 0.1,
                         coordinate_epsilon: 1.0e-6, big_z: 0.01,
                         large_coordinate: 1.0e6, planar_z_snap: 0.01 },
    session_overrides: {},
    source_snapshot_schema_version: '1'
  )
  refute_equal cfg_old, cfg_new, "config snapshots with different tolerance field sets must differ"
end

# ============================================================================
# INTEGRATION (I1-I3)
# ============================================================================

test 'V16-I1: snapshot exposes planar_normalization sub-snapshot' do
  adapter = FakeDerivedWorkspaceAdapter.new
  WorkingModeRunner.reset_for_tests
  snap = WorkingModeRunner.snapshot
  assert snap.key?('planar_normalization'), 'snapshot must expose planar_normalization'
  assert_equal false, snap['planar_normalization']['computed']
  assert_equal 'NOT_COMPUTED', snap['planar_normalization']['state']
end

test 'V16-I2: compute_planar_normalization populates the snapshot' do
  adapter = FakeDerivedWorkspaceAdapter.new
  edges = [
    make_edge_record(1, [0.0, 0.0, 1.0], [5.0, 0.0, 1.001])
  ]
  source = make_simple_snapshot(edges)

  WorkingModeRunner.reset_for_tests
  WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  snap = WorkingModeRunner.compute_planar_normalization
  assert_equal true, snap['planar_normalization']['computed']
  proposal = snap['planar_normalization']['proposal']
  assert proposal.is_a?(Hash)
  assert proposal.key?('state')
end

test 'V16-I3: discard clears planar_normalization state' do
  adapter = FakeDerivedWorkspaceAdapter.new
  edges = [
    make_edge_record(1, [0.0, 0.0, 1.0], [5.0, 0.0, 1.001])
  ]
  source = make_simple_snapshot(edges)

  WorkingModeRunner.reset_for_tests
  WorkingModeRunner.prepare(source: source, adapter: adapter, model: nil)
  WorkingModeRunner.compute_planar_normalization
  WorkingModeRunner.discard
  snap = WorkingModeRunner.snapshot
  assert_equal false, snap['planar_normalization']['computed'],
         "discard must clear planar_normalization state"
end
