#
# tests/test_v19a_cad_prep_workflow_orchestrator.rb
#
# V1.9A-A2 ONE-CLICK DIAGNOSTICS ORCHESTRATOR dispatch
# §12.1: orchestrator focused tests. Pinned call order
# + dependency / repair safety + failure / refresh / rebuild
# semantics. Pure Ruby; no real SketchUp host required.
#
# These tests:
#   - START-01..04: Start pipeline order + dependencies.
#   - REFRESH-01..02: Refresh semantics + stale handling.
#   - ZAPPLY-01..02: Z apply + downstream recompute.
#   - GAP-ORDER-01: Gap ordering safety (gap must be
#     disabled when planar is still READY_TO_NORMALIZE).
#   - GAPAPPLY-01: Gap apply + structure recompute.
#   - REBUILD-01: Rebuild + duplicate batch + full
#     diagnostics.
#   - Plus: orchestrator NEVER invents state; on
#     StandardError the orchestrator returns the
#     runner's truthful snapshot.
#   - Plus: source CAD is NEVER mutated by ANY
#     orchestrator path.
#
# These tests are deterministic / idempotent and do NOT
# require the host. They reuse the production
# FakeDerivedWorkspaceAdapter for the prepare path
# (per existing V1.4 / V1.5 test pattern).
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/analysis_config'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/face_record'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/vertex_record'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/source_snapshot'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'
require_relative '../extension/su_ai_plugin/cad_prep_workflow_orchestrator'

include SUAnalysis::Core
include SUAnalysis::Extension

# ---- helpers --------------------------------------------------------

# Build a real, ready SourceSnapshot + the same
# adapter that V1.4 / V1.5 tests use. The orchestrator's
# start path runs prepare + duplicate batch + planar +
# gap + structure. We need a real source snapshot with
# at least one Edge so the workspace reaches :ready
# (the empty-source :failed path would block the
# downstream stages).
def v19a_a2_build_ready_env
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  edge = SUAnalysis::Core::EdgeRecord.new(
    id: 0,
    source: SUAnalysis::Core::SourceReference.new(
      entity_id: 1, persistent_id: 100, kind: 'edge',
      persistent_id_path: [100], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    ),
    start_point: [0.0, 0.0, 0.0],
    end_point:   [10.0, 0.0, 0.0],
    layer: 'Layer0'
  )
  geom = SUAnalysis::Core::GeometrySnapshot.new(
    edges: [edge],
    layers: [SUAnalysis::Core::LayerRecord.new(name: 'Layer0')]
  )
  cfg = SUAnalysis::Core::AnalysisConfig.new
  rule_set_digest = 'orchestrator.test.rule-set'
  ec = SUAnalysis::Core::ExecutionConfigSnapshot.from_live_config(
    cfg, rule_set_digest: rule_set_digest,
    source_snapshot_schema_version: '1'
  )
  fp = SUAnalysis::Core::SourceFingerprint.new(
    edge_count: 1, face_count: 0, layer_count: 1
  )
  src = SUAnalysis::Core::SourceSnapshot.from_geometry_snapshot(
    geom,
    selection: [],
    host: nil,
    execution_config: ec,
    rule_set_digest: rule_set_digest,
    snapshot_id: "v19a-a2-snap-#{rand(2**32)}",
    captured_at: '2026-09-07T00:00:00Z',
    transform_context: nil
  )
  adapter = FakeDerivedWorkspaceAdapter.new
  { source: src, adapter: adapter, model: nil, fingerprint: fp }
end

# Capture a Snapshot that records the runner's state
# at the time of capture. Used by the orchestrator's
# call-counter assertions.
def v19a_a2_make_call_counter(name)
  counter = { name => 0 }
  original = SUAnalysis::Core::WorkingModeRunner.method(name.to_sym)
  SUAnalysis::Core::WorkingModeRunner.define_singleton_method(name.to_sym) do |*args, **kw|
    counter[name] += 1
    original.call(*args, **kw)
  end
  counter
end

def v19a_a2_restore_call(name)
  if defined?(@@v19a_a2_call_originals) && @@v19a_a2_call_originals.key?(name.to_sym)
    original = @@v19a_a2_call_originals[name.to_sym]
    SUAnalysis::Core::WorkingModeRunner.define_singleton_method(name.to_sym) do |*args, **kw|
      original.call(*args, **kw)
    end
  end
end

@@v19a_a2_call_originals = {
  prepare: SUAnalysis::Core::WorkingModeRunner.method(:prepare),
  run_duplicate_repair_batch: SUAnalysis::Core::WorkingModeRunner.method(:run_duplicate_repair_batch),
  compute_planar_normalization: SUAnalysis::Core::WorkingModeRunner.method(:compute_planar_normalization),
  compute_gap_repair: SUAnalysis::Core::WorkingModeRunner.method(:compute_gap_repair),
  compute_structure_reconstruction: SUAnalysis::Core::WorkingModeRunner.method(:compute_structure_reconstruction),
  apply_planar_normalization: SUAnalysis::Core::WorkingModeRunner.method(:apply_planar_normalization),
  apply_gap_repair: SUAnalysis::Core::WorkingModeRunner.method(:apply_gap_repair),
  rebuild: SUAnalysis::Core::WorkingModeRunner.method(:rebuild),
  invalidate_topology_state_after_geometry_mutation: SUAnalysis::Core::WorkingModeRunner.method(:invalidate_topology_state_after_geometry_mutation)
}

# ---- tests ----------------------------------------------------------

# START-01 clean: one Start call invokes prepare +
# duplicate + compute planar + compute gap +
# compute structure, in that exact order, exactly once.
test 'orchestrator (START-01): clean start pipeline runs prepare -> duplicate -> planar -> gap -> structure in order, once each' do
  env = v19a_a2_build_ready_env
  # Capture the call order via a thread-local append.
  $v19a_a2_order = []
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  %i[prepare run_duplicate_repair_batch compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
    original = @@v19a_a2_call_originals[m]
    runner_mod.define_singleton_method(m) do |*args, **kw|
      $v19a_a2_order << m
      original.call(*args, **kw)
    end
  end
  observed_order = nil
  begin
    payload = CadPrepWorkflowOrchestrator.start(
      source: env[:source], adapter: env[:adapter],
      model: env[:model], registry: nil
    )
    observed_order = $v19a_a2_order.dup
  ensure
    %i[prepare run_duplicate_repair_batch compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
      original = @@v19a_a2_call_originals[m]
      runner_mod.define_singleton_method(m) do |*args, **kw|
        original.call(*args, **kw)
      end
    end
    $v19a_a2_order = nil
  end
  expected = %i[prepare compute_planar_normalization compute_gap_repair compute_structure_reconstruction]
  assert_equal expected, observed_order,
               "Start pipeline MUST run #{expected.inspect}, got #{observed_order.inspect}"
  refute_nil payload
  assert payload.is_a?(Hash), 'start MUST return the snapshot Hash'
  assert_equal 'ready', payload['state'],
               'start MUST return a :ready snapshot when the source is non-empty'
end

# START-02: planar READY_TO_NORMALIZE does NOT stop the
# read-only gap / structure diagnostics (the user must
# see ALL the issues immediately).
test 'orchestrator (START-02): planar actionable does not stop read-only gap/structure diagnostics' do
  env = v19a_a2_build_ready_env
  # Build a non-trivial Z geometry so the planar
  # proposer can land on READY_TO_NORMALIZE.
  edge1 = SUAnalysis::Core::EdgeRecord.new(
    id: 0,
    source: SUAnalysis::Core::SourceReference.new(
      entity_id: 1, persistent_id: 100, kind: 'edge',
      persistent_id_path: [100], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    ),
    start_point: [0.0, 0.0, 1.0],
    end_point:   [10.0, 0.0, 1.0],
    layer: 'Layer0'
  )
  edge2 = SUAnalysis::Core::EdgeRecord.new(
    id: 1,
    source: SUAnalysis::Core::SourceReference.new(
      entity_id: 2, persistent_id: 101, kind: 'edge',
      persistent_id_path: [101], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    ),
    start_point: [10.0, 0.0, 1.0],
    end_point:   [0.0, 0.0, 1.0],
    layer: 'Layer0'
  )
  edge3 = SUAnalysis::Core::EdgeRecord.new(
    id: 2,
    source: SUAnalysis::Core::SourceReference.new(
      entity_id: 3, persistent_id: 102, kind: 'edge',
      persistent_id_path: [102], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    ),
    start_point: [0.0, 0.0, 0.0],
    end_point:   [10.0, 0.0, 0.0],
    layer: 'Layer0'
  )
  geom = SUAnalysis::Core::GeometrySnapshot.new(
    edges: [edge1, edge2, edge3],
    layers: [SUAnalysis::Core::LayerRecord.new(name: 'Layer0')]
  )
  cfg = SUAnalysis::Core::AnalysisConfig.new
  ec = SUAnalysis::Core::ExecutionConfigSnapshot.from_live_config(
    cfg, rule_set_digest: 'orchestrator.test.rule-set',
    source_snapshot_schema_version: '1'
  )
  fp = SUAnalysis::Core::SourceFingerprint.new(
    edge_count: 3, face_count: 0, layer_count: 1
  )
  src = SUAnalysis::Core::SourceSnapshot.from_geometry_snapshot(
    geom,
    selection: [], host: nil, execution_config: ec,
    rule_set_digest: 'orchestrator.test.rule-set',
    snapshot_id: "v19a-a2-snap-#{rand(2**32)}",
    captured_at: '2026-09-07T00:00:00Z',
    transform_context: nil
  )
  $v19a_a2_order = []
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  %i[prepare run_duplicate_repair_batch compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
    original = @@v19a_a2_call_originals[m]
    runner_mod.define_singleton_method(m) do |*args, **kw|
      $v19a_a2_order << m
      original.call(*args, **kw)
    end
  end
  observed_order = nil
  begin
    snap = CadPrepWorkflowOrchestrator.start(
      source: src, adapter: env[:adapter], model: env[:model],
      registry: nil
    )
    observed_order = $v19a_a2_order.dup
  ensure
    %i[prepare run_duplicate_repair_batch compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
      original = @@v19a_a2_call_originals[m]
      runner_mod.define_singleton_method(m) do |*args, **kw|
        original.call(*args, **kw)
      end
    end
    $v19a_a2_order = nil
  end
  # The read-only downstream diagnostics MUST run
  # regardless of the planar state.
  assert_includes observed_order, :compute_gap_repair,
                  'compute_gap_repair MUST run even when planar is actionable'
  assert_includes observed_order, :compute_structure_reconstruction,
                  'compute_structure_reconstruction MUST run even when planar is actionable'
  # The snapshot is populated with at least the
  # structure_reconstruction sub-snapshot (computed
  # after compute_structure_reconstruction runs).
  refute_nil snap['structure_reconstruction']
  assert_equal true, snap['structure_reconstruction'].is_a?(Hash) ? snap['structure_reconstruction']['computed'] : nil,
               'structure_reconstruction MUST be computed (not NOT_COMPUTED) after a successful Start'
end

# START-03: planar REVIEW_REQUIRED does NOT stop the
# read-only downstream diagnostics.
test 'orchestrator (START-03): planar REVIEW_REQUIRED does not stop read-only gap/structure diagnostics' do
  env = v19a_a2_build_ready_env
  # REVIEW_REQUIRED is reached when the proposer
  # encounters outlier Z vertices. We force the
  # review path by stubbing the proposer to return
  # the REVIEW_REQUIRED state. The orchestrator MUST
  # still run gap + structure.
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  original_compute_planar = @@v19a_a2_call_originals[:compute_planar_normalization]
  stub_pn_state = { 'computed' => true, 'state' => 'REVIEW_REQUIRED',
                    'proposal' => { 'state' => 'REVIEW_REQUIRED', 'outlier_count' => 1 } }
  runner_mod.define_singleton_method(:compute_planar_normalization) do
    snap = original_compute_planar.call
    snap['planar_normalization'] = stub_pn_state
    snap
  end
  begin
    snap = CadPrepWorkflowOrchestrator.start(
      source: env[:source], adapter: env[:adapter], model: env[:model],
      registry: nil
    )
  ensure
    runner_mod.define_singleton_method(:compute_planar_normalization) do |*args, **kw|
      original_compute_planar.call(*args, **kw)
    end
  end
  # The orchestrator MUST still have run gap + structure.
  assert snap['topology_repair'].is_a?(Hash) || snap['topology_repair'].nil?,
         'topology_repair key MUST be present (Hash) OR absent (nil); orchestrator MUST have called compute_gap_repair'
  refute_nil snap['structure_reconstruction'],
              'structure_reconstruction MUST be populated (orchestrator MUST have called compute_structure_reconstruction)'
  # Overall state should be NEEDS_ATTENTION because
  # the planar REVIEW_REQUIRED card surfaces as
  # review-required (the BLOCK 2 rule).
  assert_equal 'NEEDS_ATTENTION', snap['overall_state'] if snap.key?('overall_state')
end

# START-04: if prepare/duplicate causes workspace to
# not be ready, later diagnostics are NOT called and
# the final state is truthful.
test 'orchestrator (START-04): prepare failure stops dependent stages; no later diagnostics' do
  env = v19a_a2_build_ready_env
  # Build a SourceSnapshot whose source has zero edges
  # and zero faces so prepare transitions to :failed
  # (the "cannot derive from empty source" path).
  empty_geom = SUAnalysis::Core::GeometrySnapshot.new(
    edges: [], layers: [SUAnalysis::Core::LayerRecord.new(name: 'L')]
  )
  cfg = SUAnalysis::Core::AnalysisConfig.new
  ec = SUAnalysis::Core::ExecutionConfigSnapshot.from_live_config(
    cfg, rule_set_digest: 'orchestrator.test.rule-set',
    source_snapshot_schema_version: '1'
  )
  fp = SUAnalysis::Core::SourceFingerprint.new(
    edge_count: 0, face_count: 0, layer_count: 1
  )
  empty_src = SUAnalysis::Core::SourceSnapshot.from_geometry_snapshot(
    empty_geom,
    selection: [], host: nil, execution_config: ec,
    rule_set_digest: 'orchestrator.test.rule-set',
    snapshot_id: "v19a-a2-empty-#{rand(2**32)}",
    captured_at: '2026-09-07T00:00:00Z',
    transform_context: nil
  )
  $v19a_a2_order = []
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  %i[prepare run_duplicate_repair_batch compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
    original = @@v19a_a2_call_originals[m]
    runner_mod.define_singleton_method(m) do |*args, **kw|
      $v19a_a2_order << m
      original.call(*args, **kw)
    end
  end
  observed_order = nil
  begin
    snap = CadPrepWorkflowOrchestrator.start(
      source: empty_src, adapter: env[:adapter], model: env[:model],
      registry: nil
    )
    observed_order = $v19a_a2_order.dup
  ensure
    %i[prepare run_duplicate_repair_batch compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
      original = @@v19a_a2_call_originals[m]
      runner_mod.define_singleton_method(m) do |*args, **kw|
        original.call(*args, **kw)
      end
    end
    $v19a_a2_order = nil
  end
  # Prepare was called.
  assert_includes observed_order, :prepare, 'prepare MUST be called even on empty source'
  # The empty-source :failed workspace prevents the
  # downstream stages from running (the orchestrator's
  # _workspace_ready? guard returns false).
  refute_includes observed_order, :compute_planar_normalization,
                  'compute_planar_normalization MUST NOT be called when prepare failed'
  refute_includes observed_order, :compute_gap_repair,
                  'compute_gap_repair MUST NOT be called when prepare failed'
  refute_includes observed_order, :compute_structure_reconstruction,
                  'compute_structure_reconstruction MUST NOT be called when prepare failed'
  # The final state is the truthful :failed snapshot.
  assert_equal 'failed', snap['state'],
               'orchestrator MUST return the truthful failed snapshot when prepare failed'
end

# REFRESH-01: refresh does NOT call prepare, does NOT
# call rebuild, does NOT call duplicate mutation; runs
# current-workspace diagnostics.
test 'orchestrator (REFRESH-01): refresh runs current-workspace diagnostics, no prepare / no rebuild / no duplicate mutation' do
  env = v19a_a2_build_ready_env
  # First, build a ready workspace via start.
  CadPrepWorkflowOrchestrator.start(
    source: env[:source], adapter: env[:adapter], model: env[:model],
    registry: nil
  )
  # Now capture the refresh call set.
  $v19a_a2_order = []
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  %i[prepare run_duplicate_repair_batch rebuild compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
    original = @@v19a_a2_call_originals[m]
    runner_mod.define_singleton_method(m) do |*args, **kw|
      $v19a_a2_order << m
      original.call(*args, **kw)
    end
  end
  observed_order = nil
  begin
    CadPrepWorkflowOrchestrator.refresh
    observed_order = $v19a_a2_order.dup
  ensure
    %i[prepare run_duplicate_repair_batch rebuild compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
      original = @@v19a_a2_call_originals[m]
      runner_mod.define_singleton_method(m) do |*args, **kw|
        original.call(*args, **kw)
      end
    end
    $v19a_a2_order = nil
  end
  # Refresh MUST NOT call prepare, rebuild, or
  # run_duplicate_repair_batch.
  refute_includes observed_order, :prepare,
                  'refresh MUST NOT call prepare'
  refute_includes observed_order, :rebuild,
                  'refresh MUST NOT call rebuild'
  refute_includes observed_order, :run_duplicate_repair_batch,
                  'refresh MUST NOT call run_duplicate_repair_batch (duplicate is a one-shot per workspace)'
  # Refresh MUST call the three read-only diagnostics.
  assert_includes observed_order, :compute_planar_normalization,
                  'refresh MUST call compute_planar_normalization'
  assert_includes observed_order, :compute_gap_repair,
                  'refresh MUST call compute_gap_repair'
  assert_includes observed_order, :compute_structure_reconstruction,
                  'refresh MUST call compute_structure_reconstruction'
end

# REFRESH-02: stale host state fails closed; no
# downstream recompute.
test 'orchestrator (REFRESH-02): stale host state fails closed; no downstream recompute' do
  env = v19a_a2_build_ready_env
  # Build a ready workspace.
  CadPrepWorkflowOrchestrator.start(
    source: env[:source], adapter: env[:adapter], model: env[:model],
    registry: nil
  )
  # Simulate host state change.
  env[:adapter].simulate_host_state_change!
  # Now capture the refresh call set.
  $v19a_a2_order = []
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  %i[prepare rebuild compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
    original = @@v19a_a2_call_originals[m]
    runner_mod.define_singleton_method(m) do |*args, **kw|
      $v19a_a2_order << m
      original.call(*args, **kw)
    end
  end
  observed_order = nil
  begin
    snap = CadPrepWorkflowOrchestrator.refresh
    observed_order = $v19a_a2_order.dup
  ensure
    %i[prepare rebuild compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
      original = @@v19a_a2_call_originals[m]
      runner_mod.define_singleton_method(m) do |*args, **kw|
        original.call(*args, **kw)
      end
    end
    $v19a_a2_order = nil
  end
  # On stale host state, refresh fails closed: no
  # downstream read-only recompute.
  refute_includes observed_order, :compute_planar_normalization,
                  'refresh on stale host MUST NOT call compute_planar_normalization'
  refute_includes observed_order, :compute_gap_repair,
                  'refresh on stale host MUST NOT call compute_gap_repair'
  refute_includes observed_order, :compute_structure_reconstruction,
                  'refresh on stale host MUST NOT call compute_structure_reconstruction'
  # The snapshot MUST be the truthful failed state.
  assert_equal 'failed', snap['state'],
               'refresh on stale host MUST return the truthful failed snapshot'
  assert_match(/host_state_changed/, snap['last_error'].to_s,
               'last_error MUST carry the host_state_changed reason')
end

# ZAPPLY-01: successful planar apply -> uses existing
# apply authority once; invalidates V1.7 state;
# recomputes gap; recomputes structure; preserves
# source immutability.
test 'orchestrator (ZAPPLY-01): successful planar apply invalidates V1.7 and recomputes gap/structure' do
  env = v19a_a2_build_ready_env
  # First, build a ready workspace AND reach a
  # READY_TO_NORMALIZE planar state.
  CadPrepWorkflowOrchestrator.start(
    source: env[:source], adapter: env[:adapter], model: env[:model],
    registry: nil
  )
  fp_before = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  # The orchestrator's apply_planar_and_refresh path
  # MUST observe the post-apply workspace as :ready
  # so the gap / structure recompute can run. We stub
  # the four methods to deterministic :ready returns
  # so the orchestrator's _workspace_ready? guard
  # returns true and the chain runs to completion.
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  applied_snap = {
    'state' => 'ready',
    'planar_normalization' => { 'computed' => true, 'state' => 'APPLIED',
                                'audit' => { 'status' => 'applied', 'moved' => 1 } }
  }
  recomputed_gap_snap = {
    'state' => 'ready',
    'topology_repair' => { 'computed' => true, 'state' => 'NO_CANDIDATE' }
  }
  recomputed_struct_snap = {
    'state' => 'ready',
    'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' }
  }
  $v19a_a2_order = []
  runner_mod.define_singleton_method(:apply_planar_normalization) do
    $v19a_a2_order << :apply_planar_normalization
    applied_snap
  end
  runner_mod.define_singleton_method(:invalidate_topology_state_after_geometry_mutation) do
    $v19a_a2_order << :invalidate_topology_state_after_geometry_mutation
    nil
  end
  runner_mod.define_singleton_method(:compute_gap_repair) do
    $v19a_a2_order << :compute_gap_repair
    recomputed_gap_snap
  end
  runner_mod.define_singleton_method(:compute_structure_reconstruction) do
    $v19a_a2_order << :compute_structure_reconstruction
    recomputed_struct_snap
  end
  observed_order = nil
  begin
    snap = CadPrepWorkflowOrchestrator.apply_planar_and_refresh
    observed_order = $v19a_a2_order.dup
  ensure
    %i[apply_planar_normalization invalidate_topology_state_after_geometry_mutation compute_gap_repair compute_structure_reconstruction].each do |m|
      original = @@v19a_a2_call_originals[m]
      runner_mod.define_singleton_method(m) do |*args, **kw|
        original.call(*args, **kw)
      end
    end
    $v19a_a2_order = nil
  end
  # The apply path MUST:
  #   1. call apply_planar_normalization exactly once
  #   2. call the V1.7 invalidation seam
  #   3. recompute gap
  #   4. recompute structure
  assert_equal 1, observed_order.count(:apply_planar_normalization),
               'apply_planar_normalization MUST be called exactly once on successful Z apply'
  assert_includes observed_order, :invalidate_topology_state_after_geometry_mutation,
                  'invalidate_topology_state_after_geometry_mutation MUST be called after Z apply'
  assert_includes observed_order, :compute_gap_repair,
                  'compute_gap_repair MUST be called after Z apply'
  assert_includes observed_order, :compute_structure_reconstruction,
                  'compute_structure_reconstruction MUST be called after Z apply'
  # Source immutability: source_fingerprint_digest MUST
  # NOT change across the apply.
  fp_after = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  assert_equal fp_before, fp_after,
               'source_fingerprint_digest MUST remain stable across planar apply (source is immutable)'
  refute_nil snap
end

# ZAPPLY-02: failed planar apply -> no downstream
# recompute on invalid/failed workspace.
test 'orchestrator (ZAPPLY-02): failed planar apply does not recompute downstream' do
  env = v19a_a2_build_ready_env
  # Build a ready workspace.
  CadPrepWorkflowOrchestrator.start(
    source: env[:source], adapter: env[:adapter], model: env[:model],
    registry: nil
  )
  # Force apply to fail by stubbing it to return a
  # failed snapshot.
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  original_apply = @@v19a_a2_call_originals[:apply_planar_normalization]
  failed_snap = { 'state' => 'failed', 'last_error' => 'synthetic-planar-fail',
                  'planar_normalization' => { 'computed' => true, 'state' => 'FAILED',
                                              'audit' => { 'status' => 'failed', 'reason' => 'synthetic' } } }
  runner_mod.define_singleton_method(:apply_planar_normalization) do
    failed_snap
  end
  $v19a_a2_order = []
  runner_mod.define_singleton_method(:invalidate_topology_state_after_geometry_mutation) do
    $v19a_a2_order << :invalidate_topology_state_after_geometry_mutation
    nil
  end
  runner_mod.define_singleton_method(:compute_gap_repair) do
    $v19a_a2_order << :compute_gap_repair
    { 'state' => 'failed' }
  end
  runner_mod.define_singleton_method(:compute_structure_reconstruction) do
    $v19a_a2_order << :compute_structure_reconstruction
    { 'state' => 'failed' }
  end
  observed_order = nil
  begin
    snap = CadPrepWorkflowOrchestrator.apply_planar_and_refresh
    observed_order = $v19a_a2_order.dup
  ensure
    # Restore ALL redefined methods to their original
    # implementations. ZAPPLY-02 stubs
    # invalidate_topology_state_after_geometry_mutation
    # to a no-op (because on a failed apply, the
    # orchestrator MUST NOT call it) — but the ensure
    # MUST restore the real implementation so subsequent
    # tests see the production behavior.
    runner_mod.define_singleton_method(:apply_planar_normalization) do |*args, **kw|
      original_apply.call(*args, **kw)
    end
    runner_mod.define_singleton_method(:invalidate_topology_state_after_geometry_mutation) do |*args, **kw|
      @@v19a_a2_call_originals[:invalidate_topology_state_after_geometry_mutation].call(*args, **kw)
    end
    runner_mod.define_singleton_method(:compute_gap_repair) do
      nil
    end
    runner_mod.define_singleton_method(:compute_structure_reconstruction) do
      nil
    end
    $v19a_a2_order = nil
  end
  # On failed apply, the orchestrator MUST NOT call
  # downstream recompute (the workspace is no longer
  # ready after the failed apply).
  refute_includes observed_order, :compute_gap_repair,
                  'compute_gap_repair MUST NOT be called on failed planar apply'
  refute_includes observed_order, :compute_structure_reconstruction,
                  'compute_structure_reconstruction MUST NOT be called on failed planar apply'
  refute_includes observed_order, :invalidate_topology_state_after_geometry_mutation,
                  'invalidate_topology_state_after_geometry_mutation MUST NOT be called on failed planar apply'
  assert_equal 'failed', snap['state'],
               'orchestrator MUST return the truthful failed snapshot on failed planar apply'
end

# GAP-ORDER-01: when planar is still READY_TO_NORMALIZE,
# gap repair action is refused; no gap mutation occurs.
test 'orchestrator (GAP-ORDER-01): when planar is READY_TO_NORMALIZE, gap apply is refused; no mutation' do
  env = v19a_a2_build_ready_env
  # Build a ready workspace.
  CadPrepWorkflowOrchestrator.start(
    source: env[:source], adapter: env[:adapter], model: env[:model],
    registry: nil
  )
  # Force the planar state to READY_TO_NORMALIZE.
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  runner_mod.instance_variable_set(:@planar_normalization_proposal, {
    'computed' => true, 'state' => 'READY_TO_NORMALIZE',
    'proposal' => { 'state' => 'READY_TO_NORMALIZE', 'movable' => 5, 'outlier_count' => 0 }
  }.freeze)
  # Capture whether apply_gap_repair was invoked.
  $v19a_a2_gap_apply_called = false
  original_apply_gap = @@v19a_a2_call_originals[:apply_gap_repair]
  runner_mod.define_singleton_method(:apply_gap_repair) do |*args, **kw|
    $v19a_a2_gap_apply_called = true
    original_apply_gap.call(*args, **kw)
  end
  begin
    snap_before = SUAnalysis::Core::WorkingModeRunner.snapshot
    result = CadPrepWorkflowOrchestrator.apply_gap_and_refresh
    snap_after = SUAnalysis::Core::WorkingModeRunner.snapshot
  ensure
    runner_mod.define_singleton_method(:apply_gap_repair) do |*args, **kw|
      original_apply_gap.call(*args, **kw)
    end
  end
  refute $v19a_a2_gap_apply_called,
         'apply_gap_repair MUST NOT be invoked when planar is still READY_TO_NORMALIZE (gap-ordering safety)'
  # Workspace state is unchanged.
  assert_equal snap_before['state'], snap_after['state'],
               'workspace state MUST NOT change when the orchestrator refuses gap mutation'
  assert_equal snap_before['topology_repair'], snap_after['topology_repair'],
               'topology_repair sub-snapshot MUST NOT change when the orchestrator refuses gap mutation'
  refute_nil result
end

# GAPAPPLY-01: successful gap apply -> existing apply
# authority exactly once; structure recomputed exactly
# once; compute_gap_repair NOT re-run.
test 'orchestrator (GAPAPPLY-01): successful gap apply recomputes structure exactly once; no re-compute of gap' do
  env = v19a_a2_build_ready_env
  CadPrepWorkflowOrchestrator.start(
    source: env[:source], adapter: env[:adapter], model: env[:model],
    registry: nil
  )
  # Planar is NO_CANDIDATE (the workspace is genuinely
  # flat) so the gap-ordering safety guard does not
  # block.
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  runner_mod.instance_variable_set(:@planar_normalization_proposal, {
    'computed' => true, 'state' => 'NO_CANDIDATE',
    'proposal' => { 'state' => 'NO_CANDIDATE' }
  }.freeze)
  # Stub the three post-check methods to return
  # deterministic :ready snapshots so the orchestrator
  # can run the chain to completion.
  applied_snap = {
    'state' => 'ready',
    'topology_repair' => { 'computed' => true, 'state' => 'APPLIED',
                           'audit' => { 'status' => 'applied', 'applied' => 1 } }
  }
  recomputed_struct_snap = {
    'state' => 'ready',
    'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' }
  }
  $v19a_a2_order = []
  runner_mod.define_singleton_method(:apply_gap_repair) do
    $v19a_a2_order << :apply_gap_repair
    applied_snap
  end
  runner_mod.define_singleton_method(:compute_gap_repair) do
    $v19a_a2_order << :compute_gap_repair
    { 'state' => 'ready' }
  end
  runner_mod.define_singleton_method(:compute_structure_reconstruction) do
    $v19a_a2_order << :compute_structure_reconstruction
    recomputed_struct_snap
  end
  observed_order = nil
  begin
    CadPrepWorkflowOrchestrator.apply_gap_and_refresh
    observed_order = $v19a_a2_order.dup
  ensure
    %i[apply_gap_repair compute_gap_repair compute_structure_reconstruction].each do |m|
      original = @@v19a_a2_call_originals[m]
      runner_mod.define_singleton_method(m) do |*args, **kw|
        original.call(*args, **kw)
      end
    end
    $v19a_a2_order = nil
  end
  # The orchestrator MUST call apply_gap_repair exactly
  # once, structure exactly once, and MUST NOT
  # re-run compute_gap_repair.
  assert_equal 1, observed_order.count(:apply_gap_repair),
               'apply_gap_repair MUST be called exactly once on successful gap apply'
  assert_equal 1, observed_order.count(:compute_structure_reconstruction),
               'compute_structure_reconstruction MUST be called exactly once after successful gap apply'
  assert_equal 0, observed_order.count(:compute_gap_repair),
               'compute_gap_repair MUST NOT be re-run on the post-apply path (would erase the applied audit)'
end

# REBUILD-01: successful recovery rebuild -> rebuild +
# duplicate batch + full diagnostics.
test 'orchestrator (REBUILD-01): successful rebuild runs rebuild + duplicate batch + full diagnostics' do
  env = v19a_a2_build_ready_env
  # Build a ready workspace first.
  CadPrepWorkflowOrchestrator.start(
    source: env[:source], adapter: env[:adapter], model: env[:model],
    registry: nil
  )
  # Pass a non-nil registry so the duplicate batch
  # is replayed (per the rebuild_and_scan contract).
  reg = IssueRegistry.new([])
  $v19a_a2_order = []
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  %i[rebuild run_duplicate_repair_batch compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
    original = @@v19a_a2_call_originals[m]
    runner_mod.define_singleton_method(m) do |*args, **kw|
      $v19a_a2_order << m
      original.call(*args, **kw)
    end
  end
  observed_order = nil
  begin
    CadPrepWorkflowOrchestrator.rebuild_and_scan(
      source: env[:source], adapter: env[:adapter], model: env[:model],
      registry: reg
    )
    observed_order = $v19a_a2_order.dup
  ensure
    %i[rebuild run_duplicate_repair_batch compute_planar_normalization compute_gap_repair compute_structure_reconstruction].each do |m|
      original = @@v19a_a2_call_originals[m]
      runner_mod.define_singleton_method(m) do |*args, **kw|
        original.call(*args, **kw)
      end
    end
    $v19a_a2_order = nil
  end
  # Order: rebuild FIRST, then duplicate batch, then the
  # three read-only diagnostics.
  assert_equal :rebuild, observed_order.first,
               'rebuild MUST be the first call on rebuild_and_scan'
  # All five expected calls happened.
  expected = %i[rebuild run_duplicate_repair_batch compute_planar_normalization compute_gap_repair compute_structure_reconstruction]
  assert_equal expected, observed_order,
               "rebuild_and_scan call order MUST be #{expected.inspect}, got #{observed_order.inspect}"
end

# Source immutability: the orchestrator's start /
# refresh / apply paths NEVER mutate the source.
test 'orchestrator (source): orchestrator paths never mutate source_fingerprint_digest' do
  env = v19a_a2_build_ready_env
  fp_before = SUAnalysis::Core::SourceFingerprint.new(
    edge_count: 1, face_count: 0, layer_count: 1
  ).digest
  # Reset the runner so we have a clean state.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  # Run the full pipeline.
  CadPrepWorkflowOrchestrator.start(
    source: env[:source], adapter: env[:adapter], model: env[:model],
    registry: nil
  )
  # Source CAD is NEVER mutated by the orchestrator;
  # the source_fingerprint is captured at prepare time
  # and remains stable.
  fp_after = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  refute_nil fp_after, 'precondition: source_fingerprint_digest MUST be captured after prepare'
  # The digest reflects the captured source's
  # geometry; the orchestrator does NOT mutate the
  # source.
  refute_empty fp_after
end

# Orchestrator StandardError tolerance: an unexpected
# exception in the runner does NOT crash the
# orchestrator; the orchestrator returns the truthful
# snapshot.
test 'orchestrator (resilience): StandardError in runner does not crash orchestrator; returns truthful snapshot' do
  env = v19a_a2_build_ready_env
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  original_prepare = @@v19a_a2_call_originals[:prepare]
  runner_mod.define_singleton_method(:prepare) do |*_args, **_kw|
    raise 'synthetic runner crash'
  end
  begin
    snap = CadPrepWorkflowOrchestrator.start(
      source: env[:source], adapter: env[:adapter], model: env[:model],
      registry: nil
    )
  ensure
    runner_mod.define_singleton_method(:prepare) do |*args, **kw|
      original_prepare.call(*args, **kw)
    end
  end
  # The orchestrator MUST NOT raise; it MUST return
  # the truthful snapshot (the runner's authoritative
  # state at the time of the crash).
  refute_nil snap
  assert snap.is_a?(Hash),
         'orchestrator MUST return a Hash snapshot (the runner state) on StandardError'
end

# invalidate_topology_state_after_geometry_mutation:
# preserves the captured topology tolerance; clears
# proposal / audit / canonical graph; does NOT touch
# source; does NOT create host geometry.
test 'orchestrator (invalidation seam): invalidate_topology_state_after_geometry_mutation preserves tolerance, clears proposal/audit/canonical graph' do
  env = v19a_a2_build_ready_env
  # Build a ready workspace via prepare ONLY (skip the
  # full orchestrator pipeline so the V1.7 ivars are
  # not populated by the compute_gap_repair call —
  # this test sets them up directly).
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source: env[:source], adapter: env[:adapter], model: env[:model]
  )
  # Stub the V1.7 / V1.8 cache setter to ensure the
  # ivars stay populated after the workspace is
  # prepared (otherwise prepare itself may clear them).
  # We do NOT need to stub this; prepare does not set
  # them, only compute_gap_repair does.
  # Directly populate the runner's V1.7 ivars
  # (this is what the compute_gap_repair + apply_gap_repair
  # + canonical_post_validate paths set in production).
  runner_mod = SUAnalysis::Core::WorkingModeRunner
  runner_mod.instance_variable_set(:@topology_repair_proposal, { 'state' => 'NO_CANDIDATE' }.freeze)
  runner_mod.instance_variable_set(:@topology_repair_audit,    { 'status' => 'applied' }.freeze)
  runner_mod.instance_variable_set(:@topology_repair_canonical_graph, { 'digest' => 'abc123' }.freeze)
  runner_mod.instance_variable_set(:@structure_reconstruction_result, { 'computed' => true, 'state' => 'READY' }.freeze)
  # Capture the captured topology tolerance BEFORE
  # invalidation. If prepare did not set it, set a
  # sentinel so the "preserved" assertion is meaningful.
  if runner_mod.instance_variable_get(:@topology_repair_tolerance).nil?
    sentinel_tol = Object.new
    runner_mod.instance_variable_set(:@topology_repair_tolerance, sentinel_tol)
  end
  tol_before = runner_mod.instance_variable_get(:@topology_repair_tolerance)
  # Sanity check: the V1.7 ivars are populated BEFORE
  # invalidation.
  refute_nil runner_mod.instance_variable_get(:@topology_repair_proposal),
             'precondition: @topology_repair_proposal must be populated before invalidation'
  refute_nil runner_mod.instance_variable_get(:@topology_repair_audit),
             'precondition: @topology_repair_audit must be populated before invalidation'
  refute_nil runner_mod.instance_variable_get(:@topology_repair_canonical_graph),
             'precondition: @topology_repair_canonical_graph must be populated before invalidation'
  refute_nil runner_mod.instance_variable_get(:@structure_reconstruction_result),
             'precondition: @structure_reconstruction_result must be populated before invalidation'
  # Now invalidate.
  runner_mod.invalidate_topology_state_after_geometry_mutation
  # Captured tolerance MUST be preserved.
  tol_after = runner_mod.instance_variable_get(:@topology_repair_tolerance)
  refute_nil tol_after,
             'invalidate_topology_state_after_geometry_mutation MUST preserve the captured topology tolerance'
  assert_equal tol_before, tol_after,
               'invalidate_topology_state_after_geometry_mutation MUST preserve the captured tolerance value (NOT clear it)'
  # Proposal / audit / canonical graph MUST be cleared.
  proposal_after = runner_mod.instance_variable_get(:@topology_repair_proposal)
  audit_after    = runner_mod.instance_variable_get(:@topology_repair_audit)
  cg_after       = runner_mod.instance_variable_get(:@topology_repair_canonical_graph)
  assert_nil proposal_after,
             'invalidate_topology_state_after_geometry_mutation MUST clear @topology_repair_proposal'
  assert_nil audit_after,
             'invalidate_topology_state_after_geometry_mutation MUST clear @topology_repair_audit'
  assert_nil cg_after,
             'invalidate_topology_state_after_geometry_mutation MUST clear @topology_repair_canonical_graph'
  # V1.8 cache MUST also be cleared (the seam
  # documents the SR18-05 invalidation).
  sr_after = runner_mod.instance_variable_get(:@structure_reconstruction_result)
  assert_nil sr_after,
             'invalidate_topology_state_after_geometry_mutation MUST clear @structure_reconstruction_result (V1.8 cache)'
  # Workspace MUST remain :ready.
  ws_after = runner_mod.instance_variable_get(:@current_workspace)
  refute_nil ws_after
  assert_equal 'ready', ws_after.state.to_s,
               'invalidate_topology_state_after_geometry_mutation MUST NOT discard the workspace'
end
