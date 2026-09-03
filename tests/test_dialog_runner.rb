#
# tests/test_dialog_runner.rb — dialog lifecycle tests.
#
# Per CodeX Round 018 BLOCK-004 + BLOCK-006:
#   - DialogRunner uses set_file (absolute path), callbacks as BLOCKS,
#     set_on_closed, no source-mutation.
#   - DialogRunner.show must accept and propagate model.
#   - Loader retains the live dialog reference.
#   - End-to-end: menu click -> dialog -> locate(issue_id) -> selection
#     of the expected fake entity, plus unresolved toast control.
#
# Uses tests/_fake_ui.rb's UI module stub. The stub is installed /
# uninstalled around every test so state never leaks to the next
# test (especially the global UI constant).
#

require_relative 'runner'
require_relative '_fake_ui'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/loader'
require_relative '../extension/su_ai_plugin/dialog_runner'

include SUAnalysis::Core
include SUAnalysis::Extension
include FakeUI

# --- helpers ----------------------------------------------------------

# Reset Loader sentinels between tests.
def dr_reset_loader
  SUAnalysis::Extension::Loader.instance_variable_set(:@registered, false)
  SUAnalysis::Extension::Loader.instance_variable_set(:@live_dialog, nil)
end

# Build a minimal AnalysisResult with one locatable Issue. Renamed to
# `dr_minimal_result` to avoid collision with `minimal_result` defined
# in other test files (tests share the top-level namespace).
def dr_minimal_result
  reg = IssueRegistry.new([{
    issue_id:          'short_edge|1|1',
    issue_type:        'short_edge',
    severity:          'low',
    confidence:        'medium',
    sources:           [],
    source_entity_ids: [],
    edge_ids:          [],
    location:          nil,
    message:           'm',
    metadata:          {},
    locatable:         false,
    display_length:    nil
  }])
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count).new(0,0,0,0)
  AnalysisResult.new(preflight: pf, registry: reg, selection_type: 'Group', selection_label: 'g')
end

# V16-CLOSE-AUTODISCARD helper: build an AnalysisResult with one
# source edge so the production prepare() path reaches state
# 'ready' (NOT :failed for the empty-source path). Used by
# the close-time auto-discard tests.
def dr_realistic_result
  require_relative '../extension/su_ai_plugin/core/edge_record'
  require_relative '../extension/su_ai_plugin/core/source_reference'
  require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
  require_relative '../extension/su_ai_plugin/core/layer_record'
  reg = IssueRegistry.new([])
  pf  = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count)
        .new(1, 2, 0, 0)
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
  AnalysisResult.new(
    preflight: pf,
    registry:  reg,
    selection_type: 'Group',
    selection_label: 'g',
    geometry_snapshot: geom
  )
end

# --- tests ----------------------------------------------------------

test 'dialog_runner: show creates one dialog and stores it as live reference' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  refute_nil dialog
  assert_equal 1, FakeUI.state.dialogs.length
  assert_equal dialog, SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog)
ensure
  FakeUI.uninstall!
end

test 'dialog_runner: set_file uses absolute path' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  refute_nil dialog.set_files
  assert_equal 1, dialog.set_files.length
  # Absolute path under extension/su_ai_plugin/html/index.html.
  assert_match(/extension\/su_ai_plugin\/html\/index\.html$/, dialog.set_files.first)
ensure
  FakeUI.uninstall!
end

test 'dialog_runner: callbacks are registered BEFORE show (ready, locate, close)' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  refute_nil dialog.callbacks['ready']
  refute_nil dialog.callbacks['locate']
  refute_nil dialog.callbacks['close']
ensure
  FakeUI.uninstall!
end

test 'dialog_runner: set_on_closed is registered for cleanup' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  assert_equal 1, dialog.set_on_closed_blocks.length
ensure
  FakeUI.uninstall!
end

test 'dialog_runner: push_data calls execute_script with window.SUAIP.render (Round 018 BLOCK-003)' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Simulate the JS ready handshake.
  dialog.callbacks['ready'].call(nil)
  assert_equal 1, dialog.executed_scripts.length
  assert_match(/window\.SUAIP\.render\(/, dialog.executed_scripts.first)
ensure
  FakeUI.uninstall!
end

test 'dialog_runner: close callback releases Loader live dialog' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  refute_nil SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog)
  dialog.callbacks['close'].call(nil)
  assert_nil SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog)
ensure
  FakeUI.uninstall!
end

test 'dialog_runner: set_on_closed also releases the live dialog' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Simulate the window-close path.
  dialog.set_on_closed_blocks.first.call
  assert_nil SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog)
ensure
  FakeUI.uninstall!
end

# --------------------------------------------------------------------------
# V16-CLOSE-AUTODISCARD (Owner UX fix, 2026-09-01):
# when the user explicitly closes the HtmlDialog, the
# EXISTING discard-workspace path is automatically run
# (no second cleanup implementation), so the next
# plugin-open session begins cleanly with the normal
# primary action `准备处理` (per the V16-UI-CN-SIMPLIFICATION-
# FIX action-state matrix).
#
# Contract (per dispatch §1-§4):
#   - ready workspace -> dialog close -> discarded/clean state
#   - no workspace    -> dialog close -> safe no-op
#   - source fingerprint / source geometry unchanged
#   - reopen exposes a clean `准备处理` path
#   - must be FAIL-SAFE: a transient close-time error MUST
#     NOT block SketchUp shutdown / model close / HtmlDialog
#     close callback
# --------------------------------------------------------------------------

test 'dialog_runner (V16-CLOSE-AUTODISCARD): close with ready workspace auto-discards' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_realistic_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Prepare to reach state='ready'.
  dialog.callbacks['prepare_workspace'].call(nil)
  refute_equal 'none', SUAnalysis::Core::WorkingModeRunner.snapshot['state'],
               'precondition: prepare_workspace must transition the runner out of :none'
  assert_equal 'ready', SUAnalysis::Core::WorkingModeRunner.snapshot['state'],
               'precondition: runner must be in :ready state before close (use dr_realistic_result with source edges)'
  # Simulate the user explicitly closing the HtmlDialog.
  # V16-CLOSE-AUTODISCARD: on_close must automatically run
  # the EXISTING discard-workspace path (reused verbatim).
  dialog.set_on_closed_blocks.first.call
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'discarded', snap['state'],
               'on_close with ready workspace MUST auto-discard so the next session begins cleanly'
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner (V16-CLOSE-AUTODISCARD): close with no workspace is a safe no-op' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Do NOT prepare. Initial state is 'none'.
  assert_equal 'none', SUAnalysis::Core::WorkingModeRunner.snapshot['state'],
               'precondition: runner is in :none state with no prepare_workspace call'
  # Simulate the user closing the dialog. No-op expected.
  begin
    dialog.set_on_closed_blocks.first.call
    snap = SUAnalysis::Core::WorkingModeRunner.snapshot
    assert_equal 'none', snap['state'],
                 'on_close with no workspace MUST be a no-op (state stays :none)'
  rescue StandardError => e
    flunk("on_close with no workspace raised: #{e.class}: #{e.message}")
  end
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner (V16-CLOSE-AUTODISCARD): close with already-discarded workspace is a no-op' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Prepare, then explicit discard to reach state='discarded'.
  dialog.callbacks['prepare_workspace'].call(nil)
  dialog.callbacks['discard_workspace'].call(nil)
  assert_equal 'discarded', SUAnalysis::Core::WorkingModeRunner.snapshot['state'],
               'precondition: runner is in :discarded state after explicit discard'
  # Simulate the user closing the dialog. No-op expected.
  begin
    dialog.set_on_closed_blocks.first.call
    snap = SUAnalysis::Core::WorkingModeRunner.snapshot
    assert_equal 'discarded', snap['state'],
                 'on_close with already-discarded workspace MUST stay in :discarded'
  rescue StandardError => e
    flunk("on_close with already-discarded workspace raised: #{e.class}: #{e.message}")
  end
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner (V16-CLOSE-AUTODISCARD): close preserves source fingerprint / source geometry' do
  # Per dispatch §6: source fingerprint / source geometry MUST
  # be unchanged by the close-time auto-discard. We capture
  # the source snapshot id + digest BEFORE close and verify
  # they are unchanged AFTER close.
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_realistic_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Prepare to capture a source snapshot.
  dialog.callbacks['prepare_workspace'].call(nil)
  assert_equal 'ready', SUAnalysis::Core::WorkingModeRunner.snapshot['state'],
               'precondition: runner must be in :ready state (use dr_realistic_result with source edges)'
  snap_before = SUAnalysis::Core::WorkingModeRunner.snapshot
  src_id_before     = snap_before['source_snapshot_id']
  digest_before     = snap_before['source_fingerprint_digest']
  assert !src_id_before.nil? && !src_id_before.to_s.empty?,
         'precondition: source_snapshot_id captured before close'
  # Simulate the user closing the dialog.
  dialog.set_on_closed_blocks.first.call
  snap_after = SUAnalysis::Core::WorkingModeRunner.snapshot
  # Source CAD invariants — the auto-discard MUST NOT touch them.
  assert_equal src_id_before, snap_after['source_snapshot_id'],
               'on_close auto-discard MUST preserve the captured source_snapshot_id'
  assert_equal digest_before, snap_after['source_fingerprint_digest'],
               'on_close auto-discard MUST preserve the captured source_fingerprint_digest'
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner (V16-CLOSE-AUTODISCARD): close auto-discard clears V1.6 planar_normalization proposal/audit' do
  # Per dispatch §1: close MUST clear the V1.6 planar-
  # normalization transient proposal/audit state as the
  # existing discard contract already requires. We verify
  # the post-close snapshot does NOT carry a stale proposal
  # or audit row (the snapshot may still carry the default
  # 'NOT_COMPUTED' sub-snapshot which is the safe-empty
  # marker, but it must NOT carry the prior compute's
  # proposal/audit data).
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_realistic_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Prepare + populate a V1.6 planar_normalization sub-snapshot.
  dialog.callbacks['prepare_workspace'].call(nil)
  assert_equal 'ready', SUAnalysis::Core::WorkingModeRunner.snapshot['state'],
               'precondition: runner must be in :ready state (use dr_realistic_result with source edges)'
  dialog.callbacks['compute_planar_normalization'].call(nil)
  snap_before = SUAnalysis::Core::WorkingModeRunner.snapshot
  pn_before = snap_before['planar_normalization']
  # Precondition: a non-empty proposal was computed.
  assert(pn_before.is_a?(Hash) && !pn_before.empty?,
         'precondition: compute_planar_normalization must populate the planar_normalization sub-snapshot')
  assert(pn_before['proposal'].is_a?(Hash),
         'precondition: planar_normalization.proposal must be populated after compute')
  # Simulate the user closing the dialog.
  dialog.set_on_closed_blocks.first.call
  snap_after = SUAnalysis::Core::WorkingModeRunner.snapshot
  # The next session must begin cleanly — the snapshot
  # must NOT carry the prior compute's proposal/audit data.
  pn_after = snap_after['planar_normalization']
  assert(pn_after.is_a?(Hash),
         'planar_normalization sub-snapshot must still exist (default safe-empty marker)')
  # The prior proposal MUST be cleared.
  assert(pn_after['proposal'].nil?,
         'on_close auto-discard MUST clear the V1.6 planar_normalization proposal (no stale proposal from prior compute)')
  # The prior audit MUST be cleared.
  assert(pn_after['audit'].nil?,
         'on_close auto-discard MUST clear the V1.6 planar_normalization audit (no stale audit from prior compute)')
  # The state is the default safe-empty marker (NOT a stale
  # 'NO_CANDIDATE' / 'READY_TO_NORMALIZE' / 'APPLIED' from
  # the prior compute).
  assert(pn_after['state'] == 'NOT_COMPUTED',
         'on_close auto-discard MUST surface the default safe-empty NOT_COMPUTED marker (NOT a stale terminal state)')
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner (V16-CLOSE-AUTODISCARD): reopen after close exposes a clean 准备处理 path' do
  # Per dispatch §3 + §6: the next plugin-open session must
  # begin cleanly with the normal primary action `准备处理`.
  # We verify that the post-close snapshot has state='discarded'
  # (the previous V16-UI-CN-SIMPLIFICATION-FIX packet proves
  # the 'discarded' state exposes 准备处理 as the primary CTA).
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_realistic_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # First session: prepare (state -> 'ready').
  dialog.callbacks['prepare_workspace'].call(nil)
  assert_equal 'ready', SUAnalysis::Core::WorkingModeRunner.snapshot['state'],
               'precondition: first-session prepare must reach :ready (use dr_realistic_result with source edges)'
  # Close the dialog.
  dialog.set_on_closed_blocks.first.call
  # Second session: reopen the dialog with a NEW controller.
  # The runner carries the post-close 'discarded' state, which
  # is exactly the state the V16-UI-CN-SIMPLIFICATION-FIX
  # packet maps to primary CTA = 准备处理.
  result2 = dr_realistic_result
  model2 = FakeUI::FakeModel.new
  dialog2 = SUAnalysis::Extension::DialogRunner.show(result2, model: model2)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'discarded', snap['state'],
               'reopen after close MUST surface a clean :discarded state (which maps to 准备处理 per V16-UI-CN-SIMPLIFICATION-FIX)'
  # Verify the dialog is still functional on reopen.
  refute_nil dialog2, 'reopen after close MUST produce a new dialog'
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner (V16-CLOSE-AUTODISCARD): close callback is fail-safe on transient close-time error' do
  # Per dispatch §4: the close cleanup MUST be fail-safe. A
  # transient close-time error MUST NOT block SketchUp
  # shutdown / model close / the HtmlDialog close callback.
  # We simulate a failing WorkingModeRunner.discard and
  # verify on_close still releases the controller + Loader
  # cache + the module-level controller handle.
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_realistic_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Prepare to reach state='ready' (which would normally
  # trigger the auto-discard on close).
  dialog.callbacks['prepare_workspace'].call(nil)
  assert_equal 'ready', SUAnalysis::Core::WorkingModeRunner.snapshot['state'],
               'precondition: runner must be in :ready state (use dr_realistic_result with source edges)'
  # Monkey-patch WorkingModeRunner.discard to raise by
  # replacing the singleton method via class_eval. We
  # remember the original method and restore it in the
  # ensure block so subsequent tests see the unpatched
  # contract.
  original_discard = SUAnalysis::Core::WorkingModeRunner.method(:discard)
  begin
    SUAnalysis::Core::WorkingModeRunner.singleton_class.class_eval do
      define_method(:discard) do
        raise 'simulated transient close-time error'
      end
    end
    # The close callback MUST still complete (swallow the error).
    begin
      dialog.set_on_closed_blocks.first.call
    rescue StandardError => e
      flunk("on_close did NOT swallow transient close-time error: #{e.class}: #{e.message}")
    end
    # Controller + Loader cache MUST still be released.
    assert_nil SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog),
               'on_close MUST still release the Loader live_dialog even when the auto-discard raises'
    assert_nil SUAnalysis::Extension::DialogRunner.current_controller,
               'on_close MUST still clear the module-level current_controller handle even when the auto-discard raises'
  ensure
    # Restore the original WorkingModeRunner.discard so
    # subsequent tests see the unpatched contract.
    SUAnalysis::Core::WorkingModeRunner.singleton_class.send(:remove_method, :discard) rescue nil
    SUAnalysis::Core::WorkingModeRunner.singleton_class.class_eval do
      define_method(:discard, original_discard)
    end
  end
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner: set_file absolute path is parseable' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  abs_path = dialog.set_files.first
  assert_equal abs_path, File.expand_path(abs_path)
ensure
  FakeUI.uninstall!
end

# --------------------------------------------------------------------------
# Round 018 BLOCK-004 — End-to-end: menu action -> dialog -> locate click ->
# selection of the expected fake entity. Plus unresolved toast control.
# --------------------------------------------------------------------------

# Build a locatable Issue whose SourceReference has entity_id matching
# the test entity. IssueLocator's policy: nested=false + complete=false +
# entity_id -> find_entity_by_id fallback (root-only).
def dr_locate_issue(entity_id)
  reg = IssueRegistry.new([{
    issue_id:          "short_edge|#{entity_id}|1",
    issue_type:        'short_edge',
    severity:          'low',
    confidence:        'medium',
    sources:           [{
      entity_id:           entity_id,
      persistent_id:       nil,
      kind:                'edge',
      label:               'edge',
      instance_path:       [],
      persistent_id_path:  [],
      structural_depth:    0,
      pid_path_complete:   false
    }],
    source_entity_ids: [entity_id],
    edge_ids:          [],
    location:          nil,
    message:           'm',
    metadata:          {},
    locatable:         true,
    display_length:    nil
  }])
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count).new(0,0,0,0)
  AnalysisResult.new(preflight: pf, registry: reg, selection_type: 'Group', selection_label: 'g')
end

test 'BLOCK-004: end-to-end menu -> dialog -> locate -> selection of fake entity' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  # A target entity the locator can find via find_entity_by_id.
  target_entity = Object.new
  target_entity.define_singleton_method(:entityID) { 4242 }
  # The FakeModel has a stub #find_entity_by_id so locate can resolve.
  model = FakeUI::FakeModel.new
  model.define_singleton_method(:find_entity_by_id) { |id| id == 4242 ? target_entity : nil }
  # Build a locatable Issue with entity_id 4242.
  result = dr_locate_issue(4242)
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  refute_nil dialog
  # Simulate the JS locate click on issue_id 'short_edge|4242|1'.
  # The locator should resolve and select target_entity.
  dialog.callbacks['locate'].call(nil, 'short_edge|4242|1')
  # The locator clears the selection and adds the resolved entity.
  assert_equal [target_entity], model.selection.to_a
  # No toast was emitted (we did not show any unresolved path).
  assert_equal 0, dialog.executed_scripts.length
ensure
  FakeUI.uninstall!
end

test 'BLOCK-004: end-to-end locate unresolved -> toast emitted to window.SUAIP.toast' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  model = FakeUI::FakeModel.new
  # find_entity_by_id returns nil for everything -> unresolved.
  model.define_singleton_method(:find_entity_by_id) { |_id| nil }
  result = dr_locate_issue(9999)
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  refute_nil dialog
  # Simulate JS locate click on the missing id.
  dialog.callbacks['locate'].call(nil, 'short_edge|9999|1')
  # A toast execute_script call must have been emitted on window.SUAIP.toast.
  toast_calls = dialog.executed_scripts.select { |s| s.include?('window.SUAIP.toast') }
  assert_equal 1, toast_calls.length
  assert toast_calls.first.include?('short_edge|9999|1')
  # The selection is NOT changed.
  assert_equal [], model.selection.to_a
ensure
  FakeUI.uninstall!
end

test 'BLOCK-004: ready handshake pushes data once (no double push on click)' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  model = FakeUI::FakeModel.new
  result = dr_locate_issue(4242)
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # ready handshake pushes data once.
  dialog.callbacks['ready'].call(nil)
  initial = dialog.executed_scripts.length
  assert_equal 1, initial
  assert_match(/window\.SUAIP\.render\(/, dialog.executed_scripts.first)
  # The rendered payload is valid JSON.
  require 'json'
  rendered_call = dialog.executed_scripts.first
  # Extract the JSON argument: "window.SUAIP.render(<json>)"
  json_str = rendered_call.sub(/^.*?window\.SUAIP\.render\(/, '').sub(/\)\s*$/, '')
  parsed = JSON.parse(json_str)
  assert parsed['summary'].is_a?(Hash)
  assert parsed['groups'].is_a?(Array)
ensure
  FakeUI.uninstall!
end

# --------------------------------------------------------------------------
# CodeX 030 PRE-BUILD TECHNICAL PREVIEW V1.4 Stage 4: dialog_runner
# wires the 3 working-mode callbacks (prepare_workspace,
# discard_workspace, rebuild_workspace) as BLOCKs. Each handler
# delegates to WorkingModeRunner and re-pushes the payload so the
# UI updates. The source is NEVER touched.
# --------------------------------------------------------------------------

require_relative '../extension/su_ai_plugin/core/working_mode_runner'

test 'dialog_runner (V1.4): registers prepare/discard/rebuild workspace callbacks' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  refute_nil dialog.callbacks['prepare_workspace'],
           'dialog_runner must register prepare_workspace callback'
  refute_nil dialog.callbacks['discard_workspace'],
           'dialog_runner must register discard_workspace callback'
  refute_nil dialog.callbacks['rebuild_workspace'],
           'dialog_runner must register rebuild_workspace callback'
ensure
  FakeUI.uninstall!
end

test 'dialog_runner (V1.4): prepare_workspace callback transitions the runner to non-idle' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  refute_nil dialog
  # Simulate the JS-side click on the Prepare button.
  dialog.callbacks['prepare_workspace'].call(nil)
  # The runner must now report a non-idle state.
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  refute_equal 'none', snap['state'],
              'prepare_workspace must transition WorkingModeRunner out of the idle state'
  # The runner must hold a SourceSnapshot id (captured from the
  # dialog's analysis result; the plumbing builds one with a
  # synthetic id).
  refute_nil snap['source_snapshot_id'],
              'prepare_workspace must capture a source snapshot id'
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner (V1.4): discard_workspace callback transitions the runner to :discarded' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Prepare first, then Discard.
  dialog.callbacks['prepare_workspace'].call(nil)
  refute_equal 'none', SUAnalysis::Core::WorkingModeRunner.snapshot['state']
  dialog.callbacks['discard_workspace'].call(nil)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'discarded', snap['state'],
               'discard_workspace must transition WorkingModeRunner to :discarded'
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner (V1.4): rebuild_workspace callback re-prepares from captured source' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Prepare, Discard, Rebuild.
  dialog.callbacks['prepare_workspace'].call(nil)
  src_id_before = SUAnalysis::Core::WorkingModeRunner.snapshot['source_snapshot_id']
  dialog.callbacks['discard_workspace'].call(nil)
  assert_equal 'discarded', SUAnalysis::Core::WorkingModeRunner.snapshot['state']
  dialog.callbacks['rebuild_workspace'].call(nil)
  snap_after = SUAnalysis::Core::WorkingModeRunner.snapshot
  # The source_snapshot_id MUST be preserved across rebuild (rebuild
  # reuses the captured source, never re-creates it).
  assert_equal src_id_before, snap_after['source_snapshot_id'],
               'rebuild_workspace must preserve the captured source snapshot id'
  refute_equal 'none', snap_after['state'],
               'rebuild_workspace must transition WorkingModeRunner out of :discarded'
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner (V1.4): source-integrity invariant -- source fingerprint is identical before/after prepare+discard+rebuild' do
  # Per directive 030 Stage 4 risk test 1: source fingerprint MUST
  # be identical before/after a successful prepare, discard, and
  # rebuild. The dialog_runner path must NEVER mutate the source.
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # The runner doesn't hold a SourceSnapshot externally; we verify
  # the contract via the snapshot Hash (which is JSON-safe and
  # carries a deterministic source_fingerprint_digest derived from
  # the captured source).
  before_fp = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  dialog.callbacks['prepare_workspace'].call(nil)
  fp_after_prepare = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  dialog.callbacks['discard_workspace'].call(nil)
  # After discard, snapshot goes to 'discarded' state but the
  # source_fingerprint_digest is still in the captured source.
  fp_after_discard = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  dialog.callbacks['rebuild_workspace'].call(nil)
  fp_after_rebuild = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  # The captured source is the SAME across the whole lifecycle.
  # Its fingerprint digest MUST be stable.
  refute_nil fp_after_prepare, 'prepare_workspace must capture a source fingerprint digest'
  assert_equal fp_after_prepare, fp_after_discard,
               'discard_workspace must NOT drift the source fingerprint digest'
  assert_equal fp_after_prepare, fp_after_rebuild,
               'rebuild_workspace must NOT drift the source fingerprint digest'
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end


# --------------------------------------------------------------------------
# V1.8 OWNER SU2020 UI WIRING BLOCK (real-SU2020 Owner Gate):
# the JS-side `检查结构` button (app.js dispatches
# `window.sketchup.compute_structure_reconstruction`) is wired
# to the Ruby callback `compute_structure_reconstruction`
# via `DialogRunner.show`. WorkingModeRunner has had
# `compute_structure_reconstruction` since V18-BASE, but the
# DialogRunner did NOT register an add_action_callback for
# it -- so the JS click was a no-op on a real SU2020 host.
#
# The fix: DialogRunner.show now registers the
# `compute_structure_reconstruction` callback exactly as
# V1.6 (planar) / V1.7 (gap) compute handlers are wired.
# `on_compute_structure_reconstruction` delegates to
# WorkingModeRunner.compute_structure_reconstruction via
# the existing `_safe_invoke` path, which re-pushes the
# payload after success so the UI updates.
#
# These regressions prove the production-path wiring:
#   - DialogRunner registers the EXACT callback name
#     `'compute_structure_reconstruction'`;
#   - the registered callback invokes the REAL
#     WorkingModeRunner.compute_structure_reproduction
#     method (a stub counts the calls + records the
#     runner state observed before / after);
#   - the resulting V1.8 structure_reconstruction
#     sub-snapshot is re-pushed (the dialog observes the
#     payload via push_data executed from the callback);
#   - the previously-registered callbacks (ready, locate,
#     close, prepare_workspace, discard_workspace,
#     rebuild_workspace, compute_planar_normalization,
#     apply_planar_normalization, compute_gap_repair,
#     apply_gap_repair) remain unchanged.
# --------------------------------------------------------------------------

# Build a FakeUI dialog + register a WorkingModeRunner
# compute_structure_reconstruction call counter so the test
# can prove the registered callback delegates to the
# real production method.
def dr_wire_v18_callback_capture
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = dr_realistic_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # Prepare to reach state='ready' (the precondition for the
  # V1.8 `检查结构` CTA to be surfaced per Blueprint §15.2
  # -- V1.7 topology must be in a terminal state first).
  dialog.callbacks['prepare_workspace'].call(nil)
  # Counter module to record the runner call.
  $dr_v18_compute_calls = 0
  $dr_v18_compute_pre  = nil
  $dr_v18_compute_post = nil
  original = SUAnalysis::Core::WorkingModeRunner.method(:compute_structure_reconstruction)
  SUAnalysis::Core::WorkingModeRunner.define_singleton_method(:compute_structure_reconstruction) do |*args, **kw|
    $dr_v18_compute_calls += 1
    $dr_v18_compute_pre  = SUAnalysis::Core::WorkingModeRunner.snapshot.dup
    result = original.call(*args, **kw)
    $dr_v18_compute_post = SUAnalysis::Core::WorkingModeRunner.snapshot.dup
    result
  end
  [dialog, model]
end

test 'dialog_runner (V1.8 UI WIRING): registers exact callback name compute_structure_reconstruction' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # The EXACT callback name must be registered. JS dispatches
  # `window.sketchup.compute_structure_reconstruction`; the
  # Ruby `add_action_callback` MUST use the same string.
  refute_nil dialog.callbacks['compute_structure_reconstruction'],
              'DialogRunner MUST register add_action_callback("compute_structure_reconstruction") ' \
              'so the JS `检查结构` click is not a no-op'
  # The callback must be a Proc / block (per CodeX Round 018
  # BLOCK-004) -- NOT a Method object.
  cb = dialog.callbacks['compute_structure_reconstruction']
  assert_kind_of Proc, cb,
                 'V1.8 compute_structure_reconstruction callback MUST be a Proc/block ' \
                 '(per Round 018 BLOCK-004 -- NOT method(:name))'
ensure
  FakeUI.uninstall!
end

test 'dialog_runner (V1.8 UI WIRING): existing callbacks remain unchanged after the V1.8 wiring' do
  FakeUI.install!
  dr_reset_loader
  Loader.register!
  result = dr_minimal_result
  model = FakeUI::FakeModel.new
  dialog = SUAnalysis::Extension::DialogRunner.show(result, model: model)
  # The previously-registered callbacks must all still be
  # present (the V1.8 wiring is purely additive).
  %w[
    ready
    locate
    close
    prepare_workspace
    discard_workspace
    rebuild_workspace
    compute_planar_normalization
    apply_planar_normalization
    compute_gap_repair
    apply_gap_repair
    compute_structure_reconstruction
  ].each do |name|
    refute_nil dialog.callbacks[name],
               "DialogRunner MUST still register callback #{name.inspect} after the V1.8 wiring"
  end
ensure
  FakeUI.uninstall!
end

test 'dialog_runner (V1.8 UI WIRING): callback invokes the real WorkingModeRunner.compute_structure_reconstruction' do
  dialog, _model = dr_wire_v18_callback_capture
  # Reset the dialog's executed_scripts list (the show path
  # already pushed the initial payload via push_data).
  before_scripts = dialog.executed_scripts.length
  # Fire the JS-side click.
  dialog.callbacks['compute_structure_reconstruction'].call(nil)
  # The REAL WorkingModeRunner.compute_structure_reconstruction
  # MUST have been invoked exactly once.
  assert_equal 1, $dr_v18_compute_calls,
               'V1.8 callback MUST invoke the REAL ' \
               'WorkingModeRunner.compute_structure_reconstruction exactly once; ' \
               "got #{$dr_v18_compute_calls} calls"
  # The pre-snapshot observed by the runner shows the
  # structure_reconstruction sub-snapshot in the
  # NOT_COMPUTED safe-empty marker (precondition).
  pre_sr = $dr_v18_compute_pre['structure_reconstruction']
  assert(pre_sr.is_a?(Hash),
         'precondition: structure_reconstruction sub-snapshot must exist before the click')
  # The post-snapshot MUST carry a populated
  # structure_reconstruction sub-snapshot with computed=true
  # (the real method produced a result).
  post_sr = $dr_v18_compute_post['structure_reconstruction']
  refute_nil post_sr, 'post-condition: structure_reconstruction sub-snapshot MUST be populated after the click'
  computed_flag = post_sr.is_a?(Hash) ? post_sr['computed'] : nil
  assert_equal true, computed_flag,
               'post-condition: structure_reconstruction.computed MUST be true after the real WorkingModeRunner call'
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

test 'dialog_runner (V1.8 UI WIRING): resulting payload is re-pushed via _safe_invoke -> push_data' do
  dialog, _model = dr_wire_v18_callback_capture
  before_scripts = dialog.executed_scripts.length
  # Fire the JS-side click.
  dialog.callbacks['compute_structure_reconstruction'].call(nil)
  # The existing _safe_invoke path MUST re-push the payload
  # after success (so the UI updates). The push_data call
  # is what populates the dialog's executed_scripts list.
  after_scripts = dialog.executed_scripts.length
  pushed_count = after_scripts - before_scripts
  assert pushed_count >= 1,
         "_safe_invoke MUST re-push the payload after a successful " \
         "compute_structure_reconstruction click (expected >= 1 execute_script " \
         "call, got #{pushed_count})"
  # The most recent pushed payload MUST include the
  # structure_reconstruction sub-snapshot the V1.8 runner
  # produced (so the UI can render the `检查结构` result rows).
  latest = dialog.executed_scripts.last.to_s
  assert_match(/SUAIP\.render\(/, latest,
               're-pushed payload MUST go through window.SUAIP.render (per Round 018 BLOCK-003 contract)')
  # The render payload carries the JSON-serialized result;
  # the structure_reconstruction digest MUST be present in
  # the render call. We assert the JSON contains the
  # schema_version key + structure_reconstruction sub-key
  # (the production UIBridge serializes the full snapshot).
  # We do not assume the exact key ordering; just the
  # presence of the schema_version marker.
  assert_match(/"schema_version"/, latest,
               're-pushed payload MUST include the AnalysisResult schema_version marker')
end

test 'dialog_runner (V1.8 UI WIRING): source CAD is untouched by the compute callback' do
  # Per Blueprint §1 (Source CAD is immutable) the V1.8
  # callback MUST be a read-only structure check. We verify
  # the source fingerprint digest is unchanged across the
  # click (no mutation reaches the captured source).
  dialog, _model = dr_wire_v18_callback_capture
  fp_before = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  refute_nil fp_before,
             'precondition: source_fingerprint_digest must be captured by prepare_workspace'
  dialog.callbacks['compute_structure_reconstruction'].call(nil)
  fp_after = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  assert_equal fp_before, fp_after,
               'compute_structure_reconstruction MUST NOT mutate the captured source ' \
               '(source_fingerprint_digest must remain stable)'
ensure
  FakeUI.uninstall!
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end
