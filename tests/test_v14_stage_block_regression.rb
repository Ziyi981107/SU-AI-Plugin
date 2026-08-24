#
# tests/test_v14_stage_block_regression.rb — V1.4 targeted
# regression tests added after CodeX V1.4 Stage Review (2026-08-24).
#
# Two BLOCKs were raised at the V1.4 Stage Review:
#
#   V14-STAGE-BLOCK-001: real active-edit transform is computed
#                        in dialog_runner but discarded by
#                        SourceSnapshot.from_geometry_snapshot
#                        (which unconditionally writes identity).
#   V14-STAGE-BLOCK-002: operation/recovery model does not match
#                        real SketchUp. The production code wraps
#                        per-entity operations inside the runner's
#                        outer operation (real SU does not nest;
#                        start_operation implicitly ends the prior
#                        one). FakeModel used a counter (masking the
#                        real SU behavior). Also: _discard_if_present
#                        returning :failed was overwritten by the
#                        next prepare() (losing handle_registry).
#
# These tests pin the new contracts (production-call-chain + FakeModel
# sequential operations + transform-context flow + failed-workspace
# preservation) so future regressions to either BLOCK are caught
# automatically.
#

require_relative 'runner'
require_relative '_fake_ui'
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
require_relative '../extension/su_ai_plugin/core/derived_entity_record'
require_relative '../extension/su_ai_plugin/core/derived_workspace_fingerprint'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'
require_relative '../extension/su_ai_plugin/compatibility/su_derived_workspace_adapter'

include SUAnalysis::Core
include FakeUI

# Identity matrix (the canonical 16-float identity transform).
IDENTITY_16 = [1.0, 0.0, 0.0, 0.0,
               0.0, 1.0, 0.0, 0.0,
               0.0, 0.0, 1.0, 0.0,
               0.0, 0.0, 0.0, 1.0].freeze

# A non-identity 16-float transform: translate by (10, 20, 30).
NON_IDENTITY_16 = [1.0, 0.0, 0.0, 10.0,
                    0.0, 1.0, 0.0, 20.0,
                    0.0, 0.0, 1.0, 30.0,
                    0.0, 0.0, 0.0, 1.0].freeze

# A non-identity 16-float inverse: same translation, inverted.
NON_IDENTITY_INVERSE_16 = [1.0, 0.0, 0.0, -10.0,
                            0.0, 1.0, 0.0, -20.0,
                            0.0, 0.0, 1.0, -30.0,
                            0.0, 0.0, 0.0, 1.0].freeze

# ---- V14-STAGE-BLOCK-001 regressions ----

def v14_stage_install_fake_su(model)
  unless Object.const_defined?(:Sketchup)
    Object.const_set(:Sketchup, Module.new)
  end
  Sketchup.define_singleton_method(:active_model) { model }
  unless model.respond_to?(:active_entities)
    model.define_singleton_method(:active_entities) { :fake_active_entities }
  end
end

def v14_stage_uninstall_fake_su
  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
end

def v14_stage_reset_everything
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

def v14_stage_make_source
  edges = [EdgeRecord.new(
    id: 0,
    source: SourceReference.new(
      entity_id: 1000, persistent_id: 1000, kind: 'edge',
      persistent_id_path: [1000], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    ),
    start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0],
    layer: 'Layer0'
  )]
  layers = [LayerRecord.new(name: 'Layer0')]
  geom = GeometrySnapshot.new(edges: edges, layers: layers)
  ec = ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'stage-block-001'),
    rule_set_digest: 'stage-block-001.rule-set',
    source_snapshot_schema_version: '1'
  )
  SourceSnapshot.from_geometry_snapshot(
    geom, selection: [], execution_config: ec,
    rule_set_digest: 'stage-block-001.rule-set',
    snapshot_id: 'stage-block-001-snap',
    captured_at: '2026-08-24T00:00:00Z'
  )
end

test 'V14-STAGE-BLOCK-001: SourceSnapshot.from_geometry_snapshot passes the supplied transform_context (NO silent identity fallback)' do
  # When the caller supplies a non-identity transform_context,
  # the SourceSnapshot MUST carry the REAL transform (16
  # floats + active_edit_seed='real'), NOT the identity marker.
  edges = [EdgeRecord.new(
    id: 0,
    source: SourceReference.new(
      entity_id: 1000, persistent_id: 1000, kind: 'edge',
      persistent_id_path: [1000], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    ),
    start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0],
    layer: 'Layer0'
  )]
  layers = [LayerRecord.new(name: 'Layer0')]
  geom = GeometrySnapshot.new(edges: edges, layers: layers)
  ec = ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'tx-pass-through'),
    rule_set_digest: 'tx-pass-through.rule-set',
    source_snapshot_schema_version: '1'
  )
  real_ctx = {
    'active_edit_transform' => NON_IDENTITY_16,
    'active_edit_inverse'    => NON_IDENTITY_INVERSE_16,
    'active_edit_seed'       => 'real',
    'active_edit_path'       => [1234, 5678],
    'pid_path_complete'      => true
  }
  snap = SourceSnapshot.from_geometry_snapshot(
    geom, selection: [], execution_config: ec,
    rule_set_digest: 'tx-pass-through.rule-set',
    snapshot_id: 'tx-pass-through-snap',
    captured_at: '2026-08-24T00:00:00Z',
    transform_context: real_ctx
  )
  # SourceSnapshot.transform_context MUST carry the REAL
  # transform -- NOT silently fall back to identity.
  assert_equal NON_IDENTITY_16, snap.transform_context['active_edit_transform'],
               'SourceSnapshot must preserve the REAL 16-float active_edit_transform (no silent identity fallback)'
  assert_equal NON_IDENTITY_INVERSE_16, snap.transform_context['active_edit_inverse'],
               'SourceSnapshot must preserve the REAL 16-float active_edit_inverse'
  assert_equal 'real', snap.transform_context['active_edit_seed'],
               'active_edit_seed MUST be the real marker when a real transform is supplied'
  assert_equal [1234, 5678], snap.transform_context['active_edit_path'],
               'active_edit_path MUST be preserved verbatim'
  assert_equal true, snap.transform_context['pid_path_complete'],
               'pid_path_complete MUST be preserved'
  refute_equal 'identity', snap.transform_context['active_edit_seed'],
               'active_edit_seed MUST NOT be the synthetic identity marker when a real transform is supplied'
  # to_h MUST carry the same transform_context.
  h = snap.to_h
  assert_equal NON_IDENTITY_16, h[:transform_context]['active_edit_transform'],
               'to_h MUST preserve the real transform_context'
  # transform_context MUST be deeply frozen.
  assert snap.transform_context.frozen?, 'transform_context Hash MUST be frozen'
  assert snap.transform_context['active_edit_transform'].frozen?,
         'active_edit_transform Array MUST be frozen'
end

test 'V14-STAGE-BLOCK-001: nil transform_context preserves the legacy identity marker (V1.0-V1.3 plumbing)' do
  edges = [EdgeRecord.new(
    id: 0,
    source: SourceReference.new(
      entity_id: 1000, persistent_id: 1000, kind: 'edge',
      persistent_id_path: [1000], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    ),
    start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0],
    layer: 'Layer0'
  )]
  layers = [LayerRecord.new(name: 'Layer0')]
  geom = GeometrySnapshot.new(edges: edges, layers: layers)
  ec = ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'tx-nil'),
    rule_set_digest: 'tx-nil.rule-set',
    source_snapshot_schema_version: '1'
  )
  snap = SourceSnapshot.from_geometry_snapshot(
    geom, selection: [], execution_config: ec,
    rule_set_digest: 'tx-nil.rule-set',
    snapshot_id: 'tx-nil-snap',
    captured_at: '2026-08-24T00:00:00Z',
    transform_context: nil
  )
  # Legacy plumbing path: no real edit_transform supplied.
  # The factory MUST write the identity marker (for backward
  # compatibility with the V1.0-V1.3 plumbing path).
  assert_equal 'identity', snap.transform_context['active_edit_seed'],
               'when transform_context is nil, the identity marker MUST be written (V1.0-V1.3 backward compat)'
end

test 'V14-STAGE-BLOCK-001: SourceSnapshot rejects a malformed transform_context (not 16 floats)' do
  bad = SourceSnapshot.normalize_transform_context(
    'active_edit_transform' => [1.0, 0.0, 0.0]  # only 3 elements
  )
  assert_equal nil, bad, 'normalize_transform_context MUST return nil when shape is invalid (defensive)'
end

test 'V14-STAGE-BLOCK-001: dialog_runner._resolve_transform_context reads model.edit_transform via .to_a' do
  # End-to-end: the dialog_runner reads the host model's
  # edit_transform, extracts the 16 floats, and flows them
  # into the SourceSnapshot. This is the production path
  # that fixes V14-STAGE-BLOCK-001.
  v14_stage_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_stage_install_fake_su(model)
    # Inject an edit_transform that exposes .to_a returning
    # the NON_IDENTITY_16 array. This mimics the real
    # Sketchup::Geom::Transformation#to_a contract.
    fake_t = Object.new
    fake_t.define_singleton_method(:to_a) { NON_IDENTITY_16.dup }
    model.inject_edit_transform(fake_t)
    # Build the dialog_runner and invoke _resolve_transform_context.
    dr = SUAnalysis::Extension::DialogRunner
    # We don't have a full AnalysisResult here; we just need
    # to call the private method directly with a minimal
    # active_edit_facts Hash (nil to trigger the host fallback).
    # _resolve_transform_context is private; bypass with send.
    ctx = dr.send(:_resolve_transform_context,
                  active_facts: {}, model: model)
    refute_nil ctx,
              'dialog_runner MUST produce a transform_context when model has an edit_transform'
    assert_equal NON_IDENTITY_16, ctx['active_edit_transform'],
              'dialog_runner MUST preserve the REAL 16-float edit_transform'
    assert_equal 'real', ctx['active_edit_seed'],
              'dialog_runner MUST mark the seed as real when a real transform is supplied'
    assert ctx.frozen?,
           'dialog_runner MUST deeply freeze the transform_context before passing it to the snapshot'
    assert ctx['active_edit_transform'].frozen?,
           'dialog_runner MUST deeply freeze the transform Array'
  ensure
    v14_stage_uninstall_fake_su
    FakeUI.uninstall!
    v14_stage_reset_everything
  end
end

test 'V14-STAGE-BLOCK-001: dialog_runner._resolve_transform_context falls back to identity when host has no edit_transform' do
  v14_stage_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_stage_install_fake_su(model)
    # No inject_edit_transform -- model.edit_transform returns nil.
    dr = SUAnalysis::Extension::DialogRunner
    ctx = dr.send(:_resolve_transform_context,
                  active_facts: {}, model: model)
    assert_nil ctx,
              'dialog_runner MUST return nil (let the factory write the identity marker) when model has no edit_transform'
  ensure
    v14_stage_uninstall_fake_su
    FakeUI.uninstall!
    v14_stage_reset_everything
  end
end

# ---- V14-STAGE-BLOCK-002 regressions ----

test 'V14-STAGE-BLOCK-002: FakeModel has SEQUENTIAL operations (not nestable counter)' do
  # Per V14-STAGE-BLOCK-002: the FakeModel must mimic real
  # SketchUp's single-open operation invariant. Calling
  # start_operation when one is already open MUST implicitly
  # close the prior and open the new one. The prior
  # implementation used a nestable counter, which masked
  # the real SU behavior.
  m = FakeUI::FakeModel.new
  assert_equal false, m.operation_open?,
               'fresh FakeModel has no open operation'
  m.start_operation('op-A')
  assert_equal true, m.operation_open?
  m.start_operation('op-B')
  # op-A produced 1 :start entry. op-B implicitly closed op-A
  # (logging :implicit_close) and opened op-B (logging :start),
  # so 2 more entries = 3 total.
  assert_equal 3, m.operation_log.length,
               'start_operation when open MUST implicitly close the prior operation (real SU behavior)'
  assert_equal :implicit_close, m.operation_log[-2][:kind],
               'penultimate entry of start-while-open MUST be :implicit_close'
  assert_equal 'op-A', m.operation_log[-2][:prev_label],
               ':implicit_close entry MUST carry the prior label'
  assert_equal :start, m.operation_log.last[:kind],
               'last entry MUST be :start'
  assert_equal 'op-B', m.operation_log.last[:label]
  assert_equal true, m.operation_open?,
               'after second start_operation, exactly one operation MUST be open'
  # commit_operation closes the open one.
  m.commit_operation
  refute m.operation_open?
  # commit_operation with no open operation MUST raise.
  raised = false
  begin
    m.commit_operation
  rescue RuntimeError
    raised = true
  end
  assert raised, 'commit_operation with no open operation MUST raise'
  # abort_operation with no open operation MUST also raise.
  raised = false
  begin
    m.abort_operation
  rescue RuntimeError
    raised = true
  end
  assert raised, 'abort_operation with no open operation MUST raise'
end

test 'V14-STAGE-BLOCK-002: production Prepare wraps the WHOLE build in a single SU operation (no per-entity nesting)' do
  # Per V14-STAGE-BLOCK-002: the workspace's build_entity does
  # NOT open its own SU operation. The runner's outer
  # operation is the single owner. The FakeModel's
  # operation_log MUST therefore have exactly 2 entries
  # for a successful Prepare (1 start + 1 commit), NOT 2*N
  # entries (one per entity).
  v14_stage_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_stage_install_fake_su(model)
    adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
    src = v14_stage_make_source
    SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: model)
    snap = SUAnalysis::Core::WorkingModeRunner.snapshot
    assert_equal 'ready', snap['state']
    # Exactly 1 start + 1 commit; NO per-entity operations.
    assert_equal 2, model.operation_log.length,
                 'production Prepare MUST wrap the whole build in EXACTLY ONE SU operation (single owner; no per-entity nesting)'
    assert_equal :start,  model.operation_log.first[:kind]
    assert_equal :commit, model.operation_log.last[:kind]
    refute model.operation_open?,
           'after a successful Prepare, the FakeModel MUST have no open operation (sequential semantics)'
  ensure
    v14_stage_uninstall_fake_su
    FakeUI.uninstall!
    v14_stage_reset_everything
  end
end

test 'V14-STAGE-BLOCK-002: prepare refuses to overwrite a :failed workspace (handle_registry preservation)' do
  # Per V14-STAGE-BLOCK-002: when _discard_if_present leaves
  # the prior workspace in :failed state (because cleanup
  # could not complete), a new prepare MUST NOT overwrite
  # the failed workspace -- its private handle registry may
  # still hold partial handles that need precise cleanup.
  v14_stage_reset_everything
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  src = v14_stage_make_source
  # First Prepare succeeds.
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  snap1 = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'ready', snap1['state']
  ws1_id = snap1['workspace_id']
  refute_nil ws1_id
  # Force the workspace into :failed state by replacing the
  # current workspace with a :failed one. This simulates the
  # scenario where a Prepare hit a host failure (the runner
  # leaves the workspace in :failed with its handle_registry
  # intact).
  current_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  refute_nil current_ws
  failed_ws = SUAnalysis::Core::DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    current_ws.workspace_id,
    source_snapshot: current_ws.source_snapshot,
    adapter:         adapter,
    model:           nil,
    state:           :failed,
    entity_pairs:    current_ws.instance_variable_get(:@entity_pairs),
    handle_registry: current_ws.instance_variable_get(:@handle_registry),
    fingerprint:     current_ws.fingerprint,
    last_error:      'simulated failure -- handle_registry preserved',
    build_started_at: current_ws.build_started_at
  )
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, failed_ws)
  # New Prepare MUST be refused: state stays :failed, the
  # workspace_id is preserved, and the last_error explains.
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  snap2 = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'failed', snap2['state'],
               'retry Prepare MUST be REFUSED while prior workspace is :failed (V14-STAGE-BLOCK-002)'
  assert_equal ws1_id, snap2['workspace_id'],
               'retry Prepare MUST NOT overwrite the failed workspace_id'
  assert_match(/refused/i, snap2['last_error'].to_s,
               'last_error MUST explain the refusal')
  # The failed workspace's handle_registry is still intact.
  refute_nil SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test.instance_variable_get(:@handle_registry)
end

test 'V14-STAGE-BLOCK-002: build failure mid-build preserves partial handle registry in :failed workspace' do
  # Per V14-STAGE-BLOCK-002: when a mid-build failure leaves
  # some entities created (the abort failed to roll them
  # back), the :failed workspace MUST carry the partial
  # entity_pairs + handle_registry so a subsequent Discard
  # can precisely clean up.
  v14_stage_reset_everything
  # 3-edge source.
  src = v14_danger_source_with_paths([
    { persistent_id: 17001, persistent_id_path: [17001],
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] },
    { persistent_id: 17002, persistent_id_path: [17002],
      start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0] },
    { persistent_id: 17003, persistent_id_path: [17003],
      start_point: [10.0, 5.0, 0.0], end_point: [0.0, 5.0, 0.0] }
  ])
  # Adapter that fails on the 2nd add_edge_to_group call.
  fail_at = 2
  failing_adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  original_add_edge = failing_adapter.method(:add_edge_to_group)
  call_count = 0
  failing_adapter.define_singleton_method(:add_edge_to_group) do |group, s, e|
    call_count += 1
    raise StandardError, "v14-stage-block-002-fail-at-#{fail_at}" if call_count == fail_at
    original_add_edge.call(group, s, e)
  end
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: failing_adapter, model: nil)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal 'failed', snap['state'],
               'mid-build failure (position 2 of 3) MUST produce :failed workspace'
  # The partial inventory + handle_registry is preserved.
  entity_count = ws.entity_count
  handle_count = ws.handle_registry_keys.length
  assert_equal entity_count, handle_count,
               'partial entity_count MUST equal handle_registry_keys length (precise cleanup path)'
  # Dispose temporarily fails; retry succeeds.
  if entity_count > 0
    handle_key = ws.handle_registry_keys.first
    target_handle = ws.handle_for(handle_key)
    original_dispose = failing_adapter.method(:dispose)
    fail_dispose_count = 0
    failing_adapter.define_singleton_method(:dispose) do |handle|
      if handle.equal?(target_handle) && fail_dispose_count.zero?
        fail_dispose_count += 1
        raise StandardError, 'transient dispose failure'
      end
      original_dispose.call(handle)
    end
    # Discard the workspace via the runner (NOT directly
    # via ws.discard) so the runner's @current_workspace
    # is updated. The first dispose call raises; the
    # workspace MUST transition to :failed (per the
    # directive: even partial disposal must leave the
    # workspace INVALID, not :ready).
    SUAnalysis::Core::WorkingModeRunner.discard
    snap_after_partial = SUAnalysis::Core::WorkingModeRunner.snapshot
    refute_equal 'discarded', snap_after_partial['state'],
                 'partial disposal failure MUST transition to :failed (per directive)'
    # Retry: the adapter's dispose now works (fail_dispose_count
    # is incremented past 0); the second discard completes.
    SUAnalysis::Core::WorkingModeRunner.discard
    snap_after_retry = SUAnalysis::Core::WorkingModeRunner.snapshot
    assert_equal 'discarded', snap_after_retry['state'],
                 'second Discard (after the transient dispose failure) MUST succeed'
  end
end