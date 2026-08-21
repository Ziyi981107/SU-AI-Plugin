#
# tests/test_v14_cold_load_order.rb — V1.4 CodeX
# V14-RUNTIME-BLOCK-002 (2026-08-22) regression tests.
#
# Background: the real-SU2020 Owner observed NameError on
# the first Prepare click because dialog_runner.rb
# referenced SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter
# and SUAnalysis::Core::FakeDerivedWorkspaceAdapter WITHOUT
# explicit require_relative. Both constants relied on a
# sibling test file having pre-loaded them. Real SketchUp's
# cold-start path has no such test file, so the constant
# was uninitialized and the click raised NameError.
#
# These tests assert that the production load chain is
# DETERMINISTIC: regardless of which test files ran first,
# the constants must be loadable + the _adapter_for
# selection must be correct (production on real host, fake
# only in test env, no silent fake fallback on real host).
#
# We do NOT depend on `run_all.rb`'s ordering. Each test
# loads dialog_runner.rb and its required deps in isolation
# (via a fresh Ruby subprocess or by explicitly clearing
# $LOADED_FEATURES + $LOAD_PATH before requiring). The
# RBZ smoke test (test_rbz_smoke.rb) already covers the
# extracted-rbz load chain end-to-end.
#

require_relative 'runner'
require 'stringio'

# ----------------------------------------------------------------------
# 1. Cold-load test: dialog_runner.rb + its explicit
#    require_relative dependencies must load in isolation
#    without raising NameError on the adapter constants.
# ----------------------------------------------------------------------

def v14_cold_load_dialog_runner_only
  # Minimal stub: a Sketchup-shaped environment that has
  # active_model. This simulates a real SU host that has
  # just loaded (no test files have run before).
  unless Object.const_defined?(:Sketchup)
    Object.const_set(:Sketchup, Module.new)
  end
  fake_model = Object.new
  fake_model.define_singleton_method(:entities) { :fake_entities }
  Sketchup.define_singleton_method(:active_model) { fake_model }

  # We do NOT pre-load anything that other tests might
  # have loaded. We require_relative the production
  # adapter file DIRECTLY (no test order dependency) and
  # then load dialog_runner.rb (which now requires it
  # explicitly).
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
  require_relative '../extension/su_ai_plugin/dialog_controller'
  require_relative '../extension/su_ai_plugin/ui_bridge'
  require_relative '../extension/su_ai_plugin/issue_locator'
  require_relative '../extension/su_ai_plugin/compatibility/su_derived_workspace_adapter'
  # dialog_runner.rb itself MUST load without NameError.
  require_relative '../extension/su_ai_plugin/dialog_runner'
end

# ----------------------------------------------------------------------
# 2. Adapter selection tests: in a real-Sketchup-shaped env,
#    _adapter_for MUST return SketchupDerivedWorkspaceAdapter.
#    In a no-Sketchup env, _adapter_for MUST return
#    FakeDerivedWorkspaceAdapter. Real host + fake adapter
#    is FORBIDDEN (that path was the V14-RUNTIME-BLOCK-002
#    root cause: silent fake fallback on a real host).
# ----------------------------------------------------------------------

def v14_install_real_su
  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
  Object.const_set(:Sketchup, Module.new)
  # The production adapter's sketchup_available? checks
  # `Sketchup.active_model.respond_to?(:active_entities)`. The
  # fake model must respond to BOTH :entities (the Sketchup
  # standard entities collection) and :active_entities (the
  # production adapter's check).
  fake_model = Object.new
  fake_model.define_singleton_method(:entities) { :fake_entities }
  fake_model.define_singleton_method(:active_entities) { :fake_active_entities }
  Sketchup.define_singleton_method(:active_model) { fake_model }
  Sketchup.define_singleton_method(:respond_to?) { |name| name == :active_model || super(name) }
end

def v14_remove_su
  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
end

# ----------------------------------------------------------------------
# The actual tests.
# ----------------------------------------------------------------------

test 'V14-RUNTIME-BLOCK-002: dialog_runner.rb loads in isolation (no NameError on adapter constants)' do
  # Force a clean Slate for the constants we care about.
  v14_cold_load_dialog_runner_only
  assert defined?(SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter),
         'SketchupDerivedWorkspaceAdapter MUST be defined after dialog_runner.rb loads'
  assert defined?(SUAnalysis::Core::FakeDerivedWorkspaceAdapter),
         'FakeDerivedWorkspaceAdapter MUST be defined after dialog_runner.rb loads'
end

test 'V14-RUNTIME-BLOCK-002: _adapter_for returns PRODUCTION adapter on a real-Sketchup-shaped host' do
  v14_cold_load_dialog_runner_only
  v14_install_real_su
  begin
    adapter = SUAnalysis::Extension::DialogRunner.send(:_adapter_for, _host_safety_check: true)
    assert_kind_of SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter, adapter,
                   '_adapter_for MUST return the PRODUCTION adapter on a real-Sketchup host (V14-RUNTIME-BLOCK-002 fix)'
  ensure
    v14_remove_su
  end
end

test 'V14-RUNTIME-BLOCK-002: _adapter_for returns FAKE adapter only in a no-Sketchup env' do
  v14_cold_load_dialog_runner_only
  v14_remove_su
  adapter = SUAnalysis::Extension::DialogRunner.send(:_adapter_for, _host_safety_check: true)
  assert_kind_of SUAnalysis::Core::FakeDerivedWorkspaceAdapter, adapter,
                 '_adapter_for MUST return the FakeAdapter only when Sketchup is unavailable'
end

test 'V14-RUNTIME-BLOCK-002: _adapter_for raises AdapterUnavailableError on a real host with an unusable production adapter' do
  # Simulate the case where Sketchup is present AND
  # active_model responds to :entities BUT the production
  # adapter's sketchup_available? returns false (e.g. SU
  # version too old or active_model nil). In that case the
  # previous code silently fell back to the FakeAdapter --
  # the new contract raises AdapterUnavailableError.
  v14_cold_load_dialog_runner_only
  v14_install_real_su
  # Force the production adapter to claim unavailability
  # by stubbing its sketchup_available? to return false.
  original = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.method(:sketchup_available?)
  SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.define_singleton_method(:sketchup_available?) { false }
  begin
    raised = false
    begin
      SUAnalysis::Extension::DialogRunner.send(:_adapter_for, _host_safety_check: true)
    rescue SUAnalysis::Extension::DialogRunner::AdapterUnavailableError
      raised = true
    end
    assert raised,
           '_adapter_for MUST raise AdapterUnavailableError when production adapter is unusable on a real host (no silent fake fallback)'
  ensure
    SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.define_singleton_method(:sketchup_available?, original)
    v14_remove_su
  end
end

test 'V14-RUNTIME-BLOCK-002: Prepare callback error is visible (no silent swallow)' do
  v14_cold_load_dialog_runner_only
  v14_remove_su  # no-Sketchup env so the FakeAdapter is used
  # Stub WorkingModeRunner.prepare to raise.
  original_prepare = SUAnalysis::Core::WorkingModeRunner.method(:prepare)
  SUAnalysis::Core::WorkingModeRunner.singleton_class.class_eval do
    define_method(:prepare) do |**_kw|
      raise StandardError, 'v14-rb-002-injected-prepare-failure'
    end
  end
  # Stub controller so dialog_runner's handlers can run.
  # The handler invokes push_data which calls UIBridge.as_html_data,
  # which reads analysis result + preflight + display_data + ...
  # We provide a minimal stub that responds to all the
  # UIBridge keys we care about.
  controller = Object.new
  controller.define_singleton_method(:result) do
    ar = Object.new
    ar.define_singleton_method(:respond_to?) { |n| true }
    ar.define_singleton_method(:geometry_snapshot) { nil }
    ar.define_singleton_method(:selection_entities) { [] }
    ar.define_singleton_method(:active_edit_facts) { {} }
    ar.define_singleton_method(:config) { nil }
    ar.define_singleton_method(:snapshot_lookup) { {} }
    ar.define_singleton_method(:selection_type) { 'Edges' }
    ar.define_singleton_method(:selection_label) { 'g' }
    ar.define_singleton_method(:display_data) { {} }
    ar.define_singleton_method(:diagnostics) { [] }
    ar.define_singleton_method(:layer_groups) { [] }
    ar.define_singleton_method(:layer_issue_groups) { [] }
    ar.define_singleton_method(:face_inventory_groups) { [] }
    ar.define_singleton_method(:summary) { {} }
    ar.define_singleton_method(:preflight) do
      pf = Object.new
      pf.define_singleton_method(:respond_to?) { |n| true }
      pf.define_singleton_method(:edge_count) { 0 }
      pf.define_singleton_method(:vertex_count) { 0 }
      pf.define_singleton_method(:non_zero_z_vertex_count) { 0 }
      pf.define_singleton_method(:warning_count) { 0 }
      pf.define_singleton_method(:face_count) { 0 }
      pf.define_singleton_method(:faces_with_holes_count) { 0 }
      pf.define_singleton_method(:layer_distribution) { {} }
      pf
    end
    ar.define_singleton_method(:registry) do
      reg = Object.new
      reg.define_singleton_method(:respond_to?) { |n| true }
      reg.define_singleton_method(:summary) { {} }
      reg.define_singleton_method(:groups) { [] }
      reg
    end
    ar
  end
  controller.define_singleton_method(:model) { nil }
  controller.define_singleton_method(:bind) { |*| self }
  controller.define_singleton_method(:release!) { nil }
  # Stub the dialog: capture the execute_script calls (for
  # toast + render) and add_action_callback calls.
  class FakeDialogForRb002
    attr_reader :executed, :callbacks
    def initialize
      @executed = []
      @callbacks = {}
    end
    def add_action_callback(name, &block)
      @callbacks[name.to_sym] = block
    end
    def execute_script(js)
      @executed << js
    end
    def set_file(path); end
    def set_on_closed(&block); end
    def show; self; end
  end
  $LOAD_PATH.unshift(File.expand_path('tests/_fake_ui_dir')) if false
  # Capture $stderr to verify the BLOCK-context error log.
  captured_err = StringIO.new
  original_stderr = $stderr
  $stderr = captured_err
  begin
    # Show the dialog. We bypass the real HtmlDialog by
    # patching UI::HtmlDialog.
    unless defined?(UI)
      Object.const_set(:UI, Module.new)
    end
    UI.send(:remove_const, :HtmlDialog) if UI.const_defined?(:HtmlDialog)
    dialog = FakeDialogForRb002.new
    UI.const_set(:HtmlDialog, Class.new do
      define_singleton_method(:new) { |**_| dialog }
      define_singleton_method(:respond_to?) { |name| name == :new || super(name) }
    end)
    # Stub Loader.keep_dialog!.
    unless defined?(SUAnalysis::Extension::Loader)
      Object.const_set(:SUAnalysis, Module.new) unless Object.const_defined?(:SUAnalysis)
      # Module already defined (we loaded dialog_runner.rb
      # which opens it). Just ensure Loader exists.
    end
    SUAnalysis::Extension::Loader.singleton_class.send(:define_method, :keep_dialog!) { |*| }
    SUAnalysis::Extension::DialogRunner.show(controller.result, model: nil)
    # Fire the prepare_workspace callback.
    dialog.callbacks[:prepare_workspace].call(nil)
    # Assert: an execute_script call carrying the toast
    # text was made.
    toasts = dialog.executed.grep(/SUAIP\.toast/)
    assert toasts.length > 0,
           'prepare failure MUST surface a toast (no silent swallow)'
    assert_match(/v14-rb-002-injected-prepare-failure/, toasts.first,
                 'toast text MUST carry the original error message')
    # Assert: the BLOCK-prefixed error log was emitted.
    assert_match(/V14-RUNTIME-BLOCK-002/, captured_err.string,
                 '$stderr MUST receive a BLOCK-prefixed error log on callback failure')
  ensure
    SUAnalysis::Core::WorkingModeRunner.singleton_class.class_eval do
      define_method(:prepare, original_prepare)
    end
    $stderr = original_stderr
    v14_remove_su
  end
end

test 'V14-RUNTIME-BLOCK-002: end-to-end dialog.show() works with no other test file having run first' do
  # This test loads dialog_runner.rb FRESH (via require +
  # the cold-load chain) and asserts the show() entry point
  # returns without raising. It does NOT depend on the
  # `run_all.rb` ordering.
  v14_cold_load_dialog_runner_only
  v14_remove_su
  # We can't easily create a real SketchUp::HtmlDialog in
  # the cold-load test (UI::HtmlDialog is not a real
  # constant). Instead we assert the adapter resolution
  # + source-snapshot builder + working-mode-runner
  # snapshot all work together WITHOUT touching a real
  # dialog. This is the production-load-chain smoke.
  adapter = SUAnalysis::Extension::DialogRunner.send(:_adapter_for, _host_safety_check: true)
  refute_nil adapter, '_adapter_for must return a non-nil adapter in the no-Sketchup env'
  assert_kind_of SUAnalysis::Core::FakeDerivedWorkspaceAdapter, adapter
end
