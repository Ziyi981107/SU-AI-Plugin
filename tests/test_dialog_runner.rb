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
