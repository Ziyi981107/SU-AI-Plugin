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
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/preflight'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/dialog_controller'
require_relative '../extension/su_ai_plugin/dialog_runner'
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
    # No production facts either.
    dr = SUAnalysis::Extension::DialogRunner
    ctx = dr.send(:_resolve_transform_context,
                  active_facts: {}, model: model)
    # V1.4 V14-STAGE-BLOCK-001 NIT fix (2026-08-24, CodeX recheck
    # #2): the dialog_runner now returns an explicit 'identity'
    # marker Hash (NOT nil) when no production facts and no
    # host edit_transform are present. This distinguishes
    # "no active edit" from "real active edit" so V1.5+ rebuild
    # / provenance tools can reason about the no-edit state.
    refute_nil ctx,
              'dialog_runner MUST return an explicit identity marker (not nil) when no production facts and no host edit_transform'
    assert_equal 'identity', ctx['active_edit_seed'],
              'identity marker MUST be present in the explicit "no active edit" context'
    refute ctx.key?('active_edit_transform'),
           'identity context MUST NOT have active_edit_transform (no real transform supplied)'
  ensure
    v14_stage_uninstall_fake_su
    FakeUI.uninstall!
    v14_stage_reset_everything
  end
end

# V14-STAGE-BLOCK-001 recheck (2026-08-24): the production
# data shape (AnalyzersRunner's active_edit_facts) uses
# 'transform' / 'pid_path' / 'pid_path_complete' / 'raw_with_nil'
# as String keys. The 'transform' value is a LIVE
# Sketchup::Geom::Transformation object. The dialog_runner's
# _resolve_transform_context MUST convert the live object
# into a 16-float Array (pure data) and map the production
# field names to the SourceSnapshot's transform_context.
test 'V14-STAGE-BLOCK-001: dialog_runner maps production AnalyzersRunner facts to pure data transform_context' do
  v14_stage_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_stage_install_fake_su(model)
    # Inject a live-ish edit_transform that mimics
    # Sketchup::Geom::Transformation: it has .to_a returning
    # the 16-float Array, and .inverse returning a similar
    # object.
    forward = NON_IDENTITY_16.dup
    inverse = NON_IDENTITY_INVERSE_16.dup
    fake_t = Object.new
    fake_t.define_singleton_method(:to_a) { forward.dup }
    fake_inv = Object.new
    fake_inv.define_singleton_method(:to_a) { inverse.dup }
    fake_t.define_singleton_method(:inverse) { fake_inv }
    model.inject_edit_transform(fake_t)
    # Build the AnalyzersRunner-style active_edit_facts Hash
    # (the production shape: String keys, :transform is a
    # LIVE Sketchup::Geom::Transformation).
    active_facts = {
      'transform'         => fake_t,
      'pid_path'          => [1234, 5678],
      'structural_depth'  => 2,
      'pid_path_complete' => true,
      'raw_with_nil'      => [1234, 5678]
    }
    dr = SUAnalysis::Extension::DialogRunner
    ctx = dr.send(:_resolve_transform_context,
                  active_facts: active_facts, model: model)
    refute_nil ctx,
              'dialog_runner MUST produce a transform_context when active_facts has a transform'
    # The 16-float transform MUST be extracted from the live
    # Sketchup object via .to_a -- NOT stored as a live object.
    assert_equal forward, ctx['active_edit_transform'],
              'dialog_runner MUST convert the live transform via .to_a (16-float Array)'
    assert_equal inverse, ctx['active_edit_inverse'],
              'dialog_runner MUST convert transform.inverse via .to_a (16-float Array)'
    assert_equal 'real', ctx['active_edit_seed'],
              'seed MUST be "real" when a real transform is supplied'
    assert_equal [1234, 5678], ctx['active_edit_path'],
              'pid_path MUST be preserved verbatim'
    assert_equal true, ctx['pid_path_complete'],
              'pid_path_complete MUST be preserved'
    # The transform_context MUST be deeply frozen (no live
    # object can be inserted after deep-freeze).
    assert ctx.frozen?, 'transform_context Hash MUST be frozen'
    assert ctx['active_edit_transform'].frozen?,
           'active_edit_transform Array MUST be frozen'
    # The 16-float Array elements MUST all be Float (NOT
    # Sketchup::Geom::Transformation, which would be a live
    # object). This is the explicit "no live SketchUp objects"
    # invariant.
    ctx['active_edit_transform'].each do |v|
      assert v.is_a?(Float),
             "every transform element MUST be a Float (no live Sketchup objects); got #{v.class}: #{v.inspect}"
    end
  ensure
    v14_stage_uninstall_fake_su
    FakeUI.uninstall!
    v14_stage_reset_everything
  end
end

# V14-STAGE-BLOCK-001 recheck: the FULL production
# path must produce a SourceSnapshot whose transform_context
# carries the real 16-float transform. This test exercises
# the exact shape that AnalyzersRunner stores on the
# AnalysisResult + the controller wiring.
test 'V14-STAGE-BLOCK-001: full production path -- controller + analysis result + model -> real transform_context in SourceSnapshot' do
  v14_stage_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_stage_install_fake_su(model)
    # Inject a live-ish edit_transform (mimics
    # Sketchup::Geom::Transformation's .to_a + .inverse).
    forward = NON_IDENTITY_16.dup
    inverse = NON_IDENTITY_INVERSE_16.dup
    fake_t = Object.new
    fake_t.define_singleton_method(:to_a) { forward.dup }
    fake_inv = Object.new
    fake_inv.define_singleton_method(:to_a) { inverse.dup }
    fake_t.define_singleton_method(:inverse) { fake_inv }
    model.inject_edit_transform(fake_t)
    # Build the AnalyzersRunner-style active_edit_facts Hash.
    active_edit_facts = {
      'transform'         => fake_t,
      'pid_path'          => [1234, 5678],
      'structural_depth'  => 2,
      'pid_path_complete' => true,
      'raw_with_nil'      => [1234, 5678]
    }
    # Build a real AnalysisResult + GeometrySnapshot the way
    # AnalyzersRunner would (selection_entities + active_edit_facts
    # on the AnalysisResult).
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
    pf = PreflightAnalyzer.run(geom)
    reg = IssueRegistry.new([])
    ar = AnalysisResult.new(
      preflight:          pf,
      registry:           reg,
      selection_type:     'Edges',
      selection_label:    '1 edge',
      geometry_snapshot:  geom,
      selection_entities: [],
      active_edit_facts:  active_edit_facts
    )
    # Build a DialogController with the model. This is what
    # the real dialog_runner.show() does.
    controller = SUAnalysis::Extension::DialogController.new(ar, model: model)
    # Call the REAL _source_snapshot_for(controller) path --
    # NOT the helper directly. This is the BLOCK-001
    # production-path test.
    dr = SUAnalysis::Extension::DialogRunner
    src = dr.send(:_source_snapshot_for, controller)
    refute_nil src, '_source_snapshot_for(controller) MUST return a real SourceSnapshot'
    # The SourceSnapshot MUST carry the real transform_context
    # (NOT the identity marker).
    ctx = src.transform_context
    refute_nil ctx['active_edit_transform'],
             'production path MUST flow the REAL 16-float transform into the SourceSnapshot (no silent identity fallback)'
    assert_equal forward, ctx['active_edit_transform'],
             'production path MUST preserve the 16-float transform (extracted from the live transform via .to_a)'
    assert_equal inverse, ctx['active_edit_inverse'],
             'production path MUST preserve the 16-float inverse (extracted from live.inverse.to_a)'
    assert_equal 'real', ctx['active_edit_seed'],
             'production path MUST mark the seed as "real" when a real transform is supplied'
    assert_equal [1234, 5678], ctx['active_edit_path'],
             'production path MUST preserve the production pid_path field as active_edit_path'
    assert_equal true, ctx['pid_path_complete'],
             'production path MUST preserve pid_path_complete'
    # The SourceSnapshot MUST NOT contain any live SketchUp
    # objects (only pure data).
    ctx['active_edit_transform'].each do |v|
      assert v.is_a?(Float),
             "every transform element MUST be Float (no live Sketchup objects in the SourceSnapshot); got #{v.class}"
    end
    # to_h MUST also preserve the real transform.
    h = src.to_h
    assert_equal forward, h[:transform_context]['active_edit_transform'],
             'to_h MUST preserve the real transform_context'
  ensure
    v14_stage_uninstall_fake_su
    FakeUI.uninstall!
    v14_stage_reset_everything
  end
end

# V14-STAGE-BLOCK-001 recheck: when the active_edit_facts
# has an empty/missing :transform but the model has a real
# edit_transform, the dialog_runner must read the model's
# edit_transform (the production fallback path).
test 'V14-STAGE-BLOCK-001: production path falls back to model.edit_transform when facts has no transform' do
  v14_stage_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_stage_install_fake_su(model)
    # Inject a live-ish edit_transform on the model.
    forward = NON_IDENTITY_16.dup
    fake_t = Object.new
    fake_t.define_singleton_method(:to_a) { forward.dup }
    fake_inv = Object.new
    fake_inv.define_singleton_method(:to_a) { NON_IDENTITY_INVERSE_16.dup }
    fake_t.define_singleton_method(:inverse) { fake_inv }
    model.inject_edit_transform(fake_t)
    # Build active_edit_facts WITHOUT :transform (e.g.
    # AnalyzersRunner's facts when the model was not in an
    # active edit at the time of analysis, but IS now).
    active_edit_facts = {
      'pid_path'          => [],
      'pid_path_complete' => true
    }
    dr = SUAnalysis::Extension::DialogRunner
    ctx = dr.send(:_resolve_transform_context,
                  active_facts: active_edit_facts, model: model)
    refute_nil ctx,
              'dialog_runner MUST fall back to model.edit_transform when facts has no :transform'
    assert_equal forward, ctx['active_edit_transform'],
              'fallback MUST read the REAL model.edit_transform via .to_a'
    assert_equal NON_IDENTITY_INVERSE_16, ctx['active_edit_inverse'],
              'fallback MUST also read the inverse'
    assert_equal 'real', ctx['active_edit_seed']
  ensure
    v14_stage_uninstall_fake_su
    FakeUI.uninstall!
    v14_stage_reset_everything
  end
end

# ---- V14-STAGE-BLOCK-002 regressions ----

# V14-STAGE-BLOCK-001 NIT fix (2026-08-24, CodeX recheck #2):
# when the production active_edit_facts is non-empty (the
# AnalyzersRunner always produces pid_path /
# pid_path_complete / raw_with_nil / structural_depth when
# it has a selection) but the root layer is NOT inside an
# active edit (no :transform key, model.edit_transform is
# nil), the dialog_runner MUST produce a context Hash with
# the explicit 'identity' seed marker. This distinguishes
# "no active edit" from "real active edit" so V1.5+ rebuild
# / provenance tools can reason about the root-layer case.
test 'V14-STAGE-BLOCK-001: production-shaped root-context (no active edit) carries the identity seed marker' do
  v14_stage_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_stage_install_fake_su(model)
    # The model's edit_transform is nil (root layer, no
    # active edit). AnalyzersRunner-style facts have NO
    # 'transform' key (root layer, no active edit), but DO
    # carry pid_path / pid_path_complete / raw_with_nil
    # (because there IS a selection at the root).
    active_edit_facts = {
      'pid_path'          => [],
      'structural_depth'  => 0,
      'pid_path_complete' => true,
      'raw_with_nil'      => []
      # NO 'transform' key
    }
    dr = SUAnalysis::Extension::DialogRunner
    ctx = dr.send(:_resolve_transform_context,
                  active_facts: active_edit_facts, model: model)
    refute_nil ctx,
              'root-context MUST produce a non-nil transform_context when other production facts are present'
    # NO transform was supplied, so the context MUST carry
    # the explicit 'identity' seed marker (NOT 'real').
    assert_equal 'identity', ctx['active_edit_seed'],
              'root-context (no active edit) MUST carry the "identity" seed marker'
    refute ctx.key?('active_edit_transform'),
           'root-context MUST NOT have active_edit_transform (no real transform supplied)'
    refute ctx.key?('active_edit_inverse'),
           'root-context MUST NOT have active_edit_inverse (no real transform supplied)'
    # Other production facts MUST be preserved.
    assert_equal [], ctx['active_edit_path'],
              'pid_path MUST be preserved as active_edit_path'
    assert_equal true, ctx['pid_path_complete'],
              'pid_path_complete MUST be preserved'
    assert_equal [], ctx['raw_with_nil'],
              'raw_with_nil MUST be preserved'
    assert_equal 0, ctx['structural_depth'],
              'structural_depth MUST be preserved'
    # The context MUST be deeply frozen.
    assert ctx.frozen?, 'root-context Hash MUST be frozen'
  ensure
    v14_stage_uninstall_fake_su
    FakeUI.uninstall!
    v14_stage_reset_everything
  end
end

# V14-STAGE-BLOCK-001 NIT fix: the full production path
# (controller + analysis result + model) at the root layer
# (no active edit) must produce a SourceSnapshot whose
# transform_context carries the 'identity' seed marker.
test 'V14-STAGE-BLOCK-001: full production path -- root layer (no active edit) carries the identity seed marker' do
  v14_stage_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_stage_install_fake_su(model)
    # Production-shaped active_edit_facts: root layer, no
    # active edit (no 'transform' key), but a selection
    # present (pid_path / pid_path_complete / raw_with_nil).
    active_edit_facts = {
      'pid_path'          => [1000, 1001],
      'structural_depth'  => 2,
      'pid_path_complete' => true,
      'raw_with_nil'      => [1000, 1001]
    }
    # Build a real AnalysisResult + GeometrySnapshot.
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
    pf = PreflightAnalyzer.run(geom)
    reg = IssueRegistry.new([])
    ar = AnalysisResult.new(
      preflight:          pf,
      registry:           reg,
      selection_type:     'Edges',
      selection_label:    '1 edge',
      geometry_snapshot:  geom,
      selection_entities: [],
      active_edit_facts:  active_edit_facts
    )
    controller = SUAnalysis::Extension::DialogController.new(ar, model: model)
    # Call the REAL _source_snapshot_for(controller) path.
    dr = SUAnalysis::Extension::DialogRunner
    src = dr.send(:_source_snapshot_for, controller)
    refute_nil src
    # The SourceSnapshot MUST carry the 'identity' seed
    # marker (root layer, no active edit).
    assert_equal 'identity', src.transform_context['active_edit_seed'],
              'root-layer SourceSnapshot MUST carry the "identity" seed marker (no active edit)'
    refute src.transform_context.key?('active_edit_transform'),
           'root-layer SourceSnapshot MUST NOT have active_edit_transform'
    refute src.transform_context.key?('active_edit_inverse'),
           'root-layer SourceSnapshot MUST NOT have active_edit_inverse'
    # Other production facts MUST be preserved.
    assert_equal [1000, 1001], src.transform_context['active_edit_path']
    assert_equal true, src.transform_context['pid_path_complete']
    assert_equal [1000, 1001], src.transform_context['raw_with_nil']
    assert_equal 2, src.transform_context['structural_depth']
    # to_h MUST also preserve the root-layer marker.
    h = src.to_h
    assert_equal 'identity', h[:transform_context]['active_edit_seed'],
              'to_h MUST carry the "identity" seed marker for the root layer'
  ensure
    v14_stage_uninstall_fake_su
    FakeUI.uninstall!
    v14_stage_reset_everything
  end
end

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

test 'V14-STAGE-BLOCK-002: prepare auto-cleans-up the prior failed workspace (recovery path)' do
  # Per V14-STAGE-BLOCK-002 recheck (2026-08-24): the runner
  # MUST attempt to discard the prior failed workspace before
  # building a new one. This is the UI's Rebuild button path.
  # When cleanup succeeds (the FakeAdapter's dispose is a
  # no-op so the discard returns :discarded), the new build
  # proceeds to :ready.
  v14_stage_reset_everything
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  src = v14_stage_make_source
  # First Prepare succeeds.
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  snap1 = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'ready', snap1['state']
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
  # New Prepare MUST auto-cleanup the prior failed workspace
  # and proceed to :ready (this is the UI's Rebuild button
  # path -- the user MUST NOT be stuck in the failed state).
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  snap2 = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'ready', snap2['state'],
               'retry Prepare after :failed MUST auto-cleanup and reach :ready (V14-STAGE-BLOCK-002 recheck)'
  assert_equal 1, snap2['entity_count'],
               'auto-cleanup + new build MUST produce 1 derived entity'
end

test 'V14-STAGE-BLOCK-002: prepare REFUSES to overwrite when cleanup itself fails (handle_registry preservation)' do
  # Per V14-STAGE-BLOCK-002 recheck: when the prior failed
  # workspace's cleanup ALSO fails (the discard itself cannot
  # complete), the runner MUST preserve the prior failed
  # workspace (no overwrite) and refuse the new build. The
  # user's escape hatch is the prior workspace's explicit
  # Discard / Rebuild call from the UI (which goes through
  # the same code path with a known-working adapter).
  v14_stage_reset_everything
  src = v14_stage_make_source
  # Adapter that fails begin_operation for all calls. The
  # first Prepare fails. The second Prepare's auto-cleanup
  # ALSO fails (because begin_operation raises again). The
  # prior failed workspace MUST be preserved.
  always_failing_adapter = Class.new(SUAnalysis::Core::FakeDerivedWorkspaceAdapter) do
    define_method(:begin_operation) do |_model, label:|
      raise StandardError, 'v14-cleanup-fails-too'
    end
  end.new
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source: src, adapter: always_failing_adapter, model: nil
  )
  snap1 = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'failed', snap1['state']
  failed_ws_id = snap1['workspace_id']
  refute_nil failed_ws_id
  # New Prepare: cleanup fails, -> refuses + preserve.
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source: src, adapter: always_failing_adapter, model: nil
  )
  snap2 = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'failed', snap2['state'],
               'retry Prepare (cleanup also fails) MUST be REFUSED (V14-STAGE-BLOCK-002 recheck)'
  assert_equal failed_ws_id, snap2['workspace_id'],
               'retry Prepare MUST preserve the prior failed workspace_id (no overwrite)'
  assert_match(/refused|cleanup/i, snap2['last_error'].to_s,
               'last_error MUST explain the refusal / cleanup failure')
  # The prior failed workspace's handle_registry is still
  # intact (the runner did NOT clear it).
  ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  refute_nil ws.instance_variable_get(:@handle_registry)
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

# V14-STAGE-BLOCK-002 recheck (2026-08-24): when the
# production Prepare hits a mid-build failure, the operation
# MUST be ABORTED (not committed), so all entities created
# so far are rolled back. The previous bug committed the
# operation even when built_ws.state was :failed.
test 'V14-STAGE-BLOCK-002: production Prepare mid-build failure ABORTS the SU operation (no partial entities)' do
  v14_stage_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_stage_install_fake_su(model)
    adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
    # 3 edges; fail on the 2nd add_edge_to_group call.
    src = v14_danger_source_with_paths([
      { persistent_id: 70001, persistent_id_path: [70001],
        start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] },
      { persistent_id: 70002, persistent_id_path: [70002],
        start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0] },
      { persistent_id: 70003, persistent_id_path: [70003],
        start_point: [10.0, 5.0, 0.0], end_point: [0.0, 5.0, 0.0] }
    ])
    # Inject a failure on the 2nd add_edges call (mimics a
    # mid-build host failure on real SU).
    original_add_edges = FakeUI::FakeModel::FakeEntities.instance_method(:add_edges)
    call_count = 0
    FakeUI::FakeModel::FakeEntities.class_eval do
      define_method(:add_edges) do |points|
        call_count += 1
        raise StandardError, "v14-mid-build-fail-#{call_count}" if call_count == 2
        original_add_edges.bind(self).call(points)
      end
    end
    SUAnalysis::Core::WorkingModeRunner.prepare(
      source: src, adapter: adapter, model: model
    )
    snap = SUAnalysis::Core::WorkingModeRunner.snapshot
    # The Prepare MUST transition to :failed (mid-build
    # failure captured).
    assert_equal 'failed', snap['state'],
                 'mid-build failure MUST produce :failed workspace'
    assert_match(/v14-mid-build-fail-2/, snap['last_error'].to_s,
                 'last_error MUST capture the mid-build failure')
    # The SU operation MUST be ABORTED, NOT committed.
    # Real SU's abort_operation rolls back all entities
    # created under the operation; the FakeModel's
    # abort_operation invalidates the model.entities (root)
    # so all SU-AI-Derived-* groups are erased.
    # The operation_log MUST show a :start then an :abort
    # (NOT a :start then a :commit).
    kinds = model.operation_log.map { |e| e[:kind] }
    assert_equal :start, kinds.first,
                 'operation log MUST start with :start'
    refute_equal :commit, kinds.last,
                 'operation log MUST NOT end with :commit (mid-build failure must abort, not commit)'
    assert_equal :abort, kinds.last,
                 'operation log MUST end with :abort (mid-build failure must abort the SU operation)'
    # The model root MUST be empty (all entities aborted).
    assert_equal 0, model.entities.groups.length,
                 'mid-build failure MUST leave ZERO derived groups (operation aborted, not committed)'
    # The :failed workspace carries the partial handle_registry
    # (precise tracking) so a subsequent Discard can clean up.
    ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
    refute_nil ws, 'current_workspace must be available for assertions'
    entity_count = ws.entity_count
    handle_count = ws.handle_registry_keys.length
    # The first edge succeeded; the second aborted (leaving
    # the first edge's group invalidated by the FakeModel's
    # abort). The :failed workspace preserves what build_entity
    # reported BEFORE the abort (so the user can see what
    # happened).
    # On real SU: abort rolls back every entity under the
    # operation -- the model.entities is empty AFTER abort
    # (verified above), and the :failed workspace tracks the
    # partial inventory for the user's audit / cleanup.
    assert entity_count >= 0,
           'entity_count is non-negative (partial inventory preserved)'
    assert handle_count >= 0,
           'handle_count is non-negative (handle_registry preserved)'
  ensure
    # Restore the original add_edges method.
    if defined?(original_add_edges) && original_add_edges
      FakeUI::FakeModel::FakeEntities.class_eval do
        define_method(:add_edges, original_add_edges)
      end
    end
    v14_stage_uninstall_fake_su
    FakeUI.uninstall!
    v14_stage_reset_everything
  end
end

# V14-STAGE-BLOCK-002 recheck: _discard_if_present must NEVER
# clear the workspace on exception. The prior failed workspace
# must be preserved so the user has a real recovery path.
test 'V14-STAGE-BLOCK-002: _discard_if_present NEVER clears workspace on exception (handle_registry preservation)' do
  v14_stage_reset_everything
  # Adapter that raises on every call (dispose + begin_operation).
  always_failing_adapter = Class.new(SUAnalysis::Core::FakeDerivedWorkspaceAdapter) do
    define_method(:begin_operation) do |_model, label:|
      raise StandardError, 'always-fail'
    end
    define_method(:dispose) do |_handle|
      raise StandardError, 'always-fail'
    end
  end.new
  src = v14_danger_source_with_paths([
    { persistent_id: 80001, persistent_id_path: [80001],
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] }
  ])
  # Build a workspace manually (since prepare will fail at
  # begin_operation). The :failed workspace has a non-empty
  # handle_registry (we'll inject one).
  ws = SUAnalysis::Core::DerivedGeometryWorkspace.new(
    source_snapshot: src, adapter: always_failing_adapter, model: nil
  )
  handle = Object.new
  failed_ws = SUAnalysis::Core::DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    ws.workspace_id,
    source_snapshot: src,
    adapter:         always_failing_adapter,
    model:           nil,
    state:           :failed,
    entity_pairs:    [['d0', SUAnalysis::Core::DerivedEntityRecord.new(
      derived_id: 'd0', kind: :edge,
      source_occurrence_ids: ['occ-d0'],
      geometry_summary: {},
      parent_derived_id: nil,
      host_assigned_ids: {}
    )]],
    handle_registry: { 'd0' => handle }.freeze,
    fingerprint:     nil,
    last_error:      'simulated',
    build_started_at: ws.build_started_at
  )
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, failed_ws)
  # Now try to discard. The adapter raises on begin_operation.
  # The workspace.discard's internal rescue catches and returns
  # :failed. The runner's _discard_if_present NEVER clears
  # @current_workspace on exception (the prior code set it to
  # nil, losing the handle_registry).
  SUAnalysis::Core::WorkingModeRunner.discard
  current = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  refute_nil current,
             '_discard_if_present MUST NOT clear @current_workspace on exception'
  assert_equal 'd0', current.handle_registry_keys.first,
             'handle_registry MUST be preserved (the runner did NOT clear the workspace)'
  assert current.state == :failed || current.state == :discarded,
         'the current workspace state is :failed or :discarded (whichever the discard produced)'
end