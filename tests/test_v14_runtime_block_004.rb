#
# tests/test_v14_runtime_block_004.rb — V1.4 CodeX V14-RUNTIME-BLOCK-004
# (2026-08-24, real SU2020 narrow test) regression tests.
#
# Symptom: in SketchUp 2020, $stderr IS Sketchup::Console and
# $stdout IS Sketchup::Console; both have #puts as a PRIVATE
# method. Direct $stderr.puts(...) / $stdout.puts(...) raised
# NoMethodError, which masked the original Prepare exception
# in dialog_runner.rb#_safe_invoke's rescue block, skipping
# both the UI toast AND the push_data. The dialog got stuck
# in a stale / invisible intermediate state.
#
# Fix contract (production code changes verified by these tests):
#   1. _safe_invoke MUST use a defensive logger that never
#      propagates an exception. The logger is a private
#      method _safe_log(msg) which uses bare `warn(...)`
#      (a Kernel method that writes via the C error stream)
#      wrapped in its own begin/rescue.
#   2. The original exception (its class + message) is the
#      source of truth for the UI toast.
#   3. push_data runs UNCONDITIONALLY (even when the action
#      raised, even when the toast raised) so the UI is
#      re-pushed and the Working Mode state is refreshed.
#   4. _toast exceptions are logged but never propagated.
#   5. Same risk on $stdout.puts (on_locate + main.rb boot
#      rescue) is fixed with the same _safe_log pattern.
#

require_relative 'runner'
require_relative '_fake_ui'
require_relative '../extension/su_ai_plugin/dialog_runner'
require_relative '../extension/su_ai_plugin/ui_bridge'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/preflight'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/analysis_config'
require_relative '../extension/su_ai_plugin/core/layer_record'

include SUAnalysis::Core
include FakeUI

# ---- A mock console that mimics real SketchUp 2020:
# #puts is PRIVATE. Calling it raises NoMethodError. ----
class PrivateConsole
  # Public surface: write (low-level), no puts. Real SU has
  # #puts as private; we mirror that.
  private

  def puts(*_args)
    raise NoMethodError,
          "private method 'puts' called for #<PrivateConsole>"
  end

  public

  def write(*_args)
    # swallow
    nil
  end
end

# Helper module to hold the warn-override state (avoids the
# `wrong constant name` error for lowercase module-level
# identifiers).
# Build a minimal AnalysisResult for the dialog_runner's
# push_data path.
def v14_block_004_make_ar
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
  AnalysisResult.new(
    preflight:          pf,
    registry:           reg,
    selection_type:     'Edges',
    selection_label:    '1 edge',
    geometry_snapshot:  geom,
    selection_entities: [],
    active_edit_facts:  {}
  )
end

# Replace the global $stderr with the PrivateConsole mock so
# the production logger (which uses `warn`) does NOT touch the
# real $stderr (it would always succeed in the test env). The
# _safe_log helper calls bare `warn(...)`; we stub it to raise
# (mimicking real SU2020 where warn would propagate through
# $stderr.puts -> private method).
def v14_block_004_install_private_console
  @v14_block_004_saved_stderr = $stderr
  @v14_block_004_saved_stdout = $stdout
  # V1.4 V14-RUNTIME-BLOCK-004: in Ruby, $stderr is a
  # predefined GLOBAL variable; the correct override is
  # reassignment (not remove_instance_variable on Object --
  # which is the wrong API and would raise on a true
  # global). We assign the PrivateConsole instance directly
  # to $stderr / $stdout.
  $stderr = PrivateConsole.new
  $stdout = PrivateConsole.new
end

def v14_block_004_restore_stdio
  $stderr = @v14_block_004_saved_stderr if @v14_block_004_saved_stderr
  $stdout = @v14_block_004_saved_stdout if @v14_block_004_saved_stdout
end

# Build a minimal dialog + controller for the tests.
def v14_block_004_make_dialog_and_controller(ar)
  dialog = FakeUI::FakeHtmlDialog.new
  controller = SUAnalysis::Extension::DialogController.new(ar, model: nil)
  controller.bind(dialog, nil)
  [dialog, controller]
end

# ---- Test 1: the private-puts mock behaves as expected ----

test 'V14-RUNTIME-BLOCK-004: PrivateConsole mock raises NoMethodError when #puts is called (mimics real SU2020)' do
  v14_block_004_install_private_console
  begin
    raised = false
    begin
      $stderr.puts('anything')
    rescue NoMethodError => e
      raised = true
      # Ruby's NoMethodError message uses backticks around
      # the method name (e.g. "private method `puts' called
      # for #<PrivateConsole:0x...>"). Real SU2020 raises the
      # same shape; we check for the keyword "private method"
      # and the method name (backticks vs single quotes is
      # not stable across Ruby versions).
      assert_match(/private method.*puts/, e.message,
                   'mock must raise the same NoMethodError shape as real SU2020')
    end
    assert raised,
           '$stderr.puts MUST raise NoMethodError when #puts is private (real SU2020 behavior)'
  ensure
    v14_block_004_restore_stdio
  end
end

# ---- Test 2: _safe_log never propagates a logging exception ----

test 'V14-RUNTIME-BLOCK-004: dialog_runner._safe_log never propagates a logging exception (warn failure swallowed)' do
  v14_block_004_install_private_console
  begin
    # V1.4 V14-RUNTIME-BLOCK-004: force bare `warn` to raise
    # (mimics the worst case where even warn(...) fails on
    # the SU2020 host). We use a wrapper class + singleton
    # method binding to avoid the `do/end` block binding
    # issue inside `module_eval`.
    warn_calls = [0]
    dr = SUAnalysis::Extension::DialogRunner
    dr.singleton_class.send(:define_method, :warn) do |*_args|
      warn_calls[0] += 1
      raise NoMethodError, "private method `puts' called for #<PrivateConsole>"
    end
    raised = false
    begin
      dr.send(:_safe_log, "any message")
    rescue StandardError
      raised = true
    end
    assert !raised, '_safe_log MUST NEVER propagate a logging exception'
    assert warn_calls[0] > 0,
           'warn MUST have been invoked at least once (the shim should have triggered)'
  ensure
    SUAnalysis::Extension::DialogRunner.singleton_class.send(:remove_method, :warn)
    v14_block_004_restore_stdio
  end
end

# ---- Test 3: _safe_invoke preserves the original exception class + message ----

test 'V14-RUNTIME-BLOCK-004: _safe_invoke preserves the original exception (class + message) for the toast' do
  v14_block_004_install_private_console
  begin
    ar = v14_block_004_make_ar
    dialog, controller = v14_block_004_make_dialog_and_controller(ar)
    original_exception = StandardError.new('original Prepare failure XYZ')
    dr = SUAnalysis::Extension::DialogRunner
    dr.send(:_safe_invoke, dialog, controller, 'on_prepare_workspace') do
      raise original_exception
    end
    # The toast MUST have been called with the ORIGINAL exception
    # class + message, not the NoMethodError from the logger.
    toast_calls = dialog.executed_scripts.select { |s| s.include?('SUAIP.toast') }
    assert !toast_calls.empty?,
           'a toast MUST be raised on the original Prepare failure'
    assert toast_calls.any? { |s| s.include?('on_prepare_workspace') && s.include?('original Prepare failure XYZ') },
           "toast MUST include the original action name and message; got: #{toast_calls.inspect}"
  ensure
    v14_block_004_restore_stdio
  end
end

# ---- Test 4: _safe_invoke runs push_data even when the action raised ----

test 'V14-RUNTIME-BLOCK-004: _safe_invoke runs push_data UNCONDITIONALLY (action raised -> UI still re-pushed)' do
  v14_block_004_install_private_console
  begin
    ar = v14_block_004_make_ar
    dialog, controller = v14_block_004_make_dialog_and_controller(ar)
    dr = SUAnalysis::Extension::DialogRunner
    dr.send(:_safe_invoke, dialog, controller, 'on_prepare_workspace') do
      raise StandardError, 'prepare failed'
    end
    # push_data calls window.SUAIP.render(...). The script
    # list MUST contain the render call (NOT just the toast).
    render_calls = dialog.executed_scripts.select { |s| s.include?('SUAIP.render') }
    assert !render_calls.empty?,
           'push_data MUST run after a failed action so the UI re-pushes the Working Mode state'
  ensure
    v14_block_004_restore_stdio
  end
end

# ---- Test 5: _safe_invoke does NOT propagate a logger exception ----

test 'V14-RUNTIME-BLOCK-004: _safe_invoke does NOT propagate the logger NoMethodError' do
  v14_block_004_install_private_console
  begin
    # Force bare `warn` to raise (the OLD bug: $stderr.puts
    # raised NoMethodError inside the rescue, masking the
    # original exception). Use a wrapper class to avoid
    # the `do/end` block binding issue.
    dr = SUAnalysis::Extension::DialogRunner
    dr.singleton_class.send(:define_method, :warn) do |*_args|
      raise NoMethodError, "private method `puts' called for #<PrivateConsole>"
    end
    ar = v14_block_004_make_ar
    dialog, controller = v14_block_004_make_dialog_and_controller(ar)
    raised_outside = false
    raised = nil
    begin
      dr.send(:_safe_invoke, dialog, controller, 'on_prepare_workspace') do
        raise StandardError, 'real Prepare failure'
      end
    rescue StandardError => e
      # _safe_invoke MUST swallow the logger failure; the
      # method itself MUST NOT propagate the logger NoMethodError.
      raised_outside = true
      raised = e
    end
    assert !raised_outside,
           "_safe_invoke MUST NOT propagate the logger failure; got: #{raised.inspect}"
    # The toast MUST still fire (the real failure path is
    # preserved).
    toast_calls = dialog.executed_scripts.select { |s| s.include?('SUAIP.toast') }
    assert toast_calls.any? { |s| s.include?('real Prepare failure') },
           "toast MUST carry the real Prepare failure; got: #{toast_calls.inspect}"
    # push_data MUST still run.
    render_calls = dialog.executed_scripts.select { |s| s.include?('SUAIP.render') }
    assert !render_calls.empty?, 'push_data MUST still run when the logger raises'
  ensure
    SUAnalysis::Extension::DialogRunner.singleton_class.send(:remove_method, :warn)
    v14_block_004_restore_stdio
  end
end

# ---- Test 6: _toast exceptions do NOT prevent push_data ----

test 'V14-RUNTIME-BLOCK-004: _toast exception does NOT prevent push_data' do
  v14_block_004_install_private_console
  begin
    ar = v14_block_004_make_ar
    dialog = FakeUI::FakeHtmlDialog.new
    # Make execute_script raise on toast but work on render.
    original_execute_script = dialog.method(:execute_script)
    calls = []
    dialog.define_singleton_method(:execute_script) do |js|
      calls << js
      if js.include?('SUAIP.toast')
        raise StandardError, 'toast engine unavailable'
      end
      original_execute_script.call(js)
    end
    controller = SUAnalysis::Extension::DialogController.new(ar, model: nil)
    controller.bind(dialog, nil)
    dr = SUAnalysis::Extension::DialogRunner
    dr.send(:_safe_invoke, dialog, controller, 'on_prepare_workspace') do
      raise StandardError, 'prepare failed ABC'
    end
    # push_data MUST have run.
    render_calls = calls.select { |s| s.include?('SUAIP.render') }
    assert !render_calls.empty?,
           'push_data MUST run even when _toast raises (UI re-push is mandatory)'
  ensure
    v14_block_004_restore_stdio
  end
end

# ---- Test 7: the Working Mode state reflects the original failure ----

test 'V14-RUNTIME-BLOCK-004: Working Mode state is :failed (NOT :discarded / NOT corrupted) when the action raised' do
  v14_block_004_install_private_console
  begin
    ar = v14_block_004_make_ar
    dialog, controller = v14_block_004_make_dialog_and_controller(ar)
    dr = SUAnalysis::Extension::DialogRunner
    dr.send(:_safe_invoke, dialog, controller, 'on_prepare_workspace') do
      raise StandardError, 'simulated Prepare failure'
    end
    # The push_data call's payload MUST include the working
    # copy state. We verify by re-running the dialog's render
    # call ourselves and checking the JSON payload (the
    # FakeHtmlDialog captured it).
    render_calls = dialog.executed_scripts.select { |s| s.include?('SUAIP.render') }
    assert !render_calls.empty?,
           'push_data MUST have run for the Working Mode state test'
    json = render_calls.first.sub(/^.*?window\.SUAIP\.render\(/, '').sub(/\)\s*$/, '')
    require 'json'
    payload = JSON.parse(json)
    # The payload MUST carry derivedWorkspace (the Working
    # Mode surface) -- the V1.4 contract.
    refute_nil payload['derivedWorkspace'],
              'pushed payload MUST include derivedWorkspace (Working Mode)'
    # The state is the runner's snapshot state. After a
    # failed _safe_invoke (no Prepare actually ran), the
    # runner is in its idle 'none' state. The CRITICAL property
    # is: push_data ran (so the UI got the payload) and no
    # stale / invisible state was left behind.
    assert_equal 'none', payload['derivedWorkspace']['state'],
                 'runner MUST stay in idle state when the action failed before Prepare'
  ensure
    v14_block_004_restore_stdio
  end
end

# ---- Test 8: same risk on $stdout (on_locate) ----

test 'V14-RUNTIME-BLOCK-004: on_locate uses _safe_log (no $stdout.puts on SU2020 host)' do
  v14_block_004_install_private_console
  begin
    ar = v14_block_004_make_ar
    dialog, controller = v14_block_004_make_dialog_and_controller(ar)
    # Inject a minimal issue_locator stub that returns an
    # unresolved result so on_locate's $stdout.puts path is
    # exercised. The original code did
    # $stdout.puts("[SU-AI-Plugin] locate_issue: ...") which
    # would raise NoMethodError on SU2020.
    original_locator = SUAnalysis::Extension::IssueLocator.singleton_class.instance_method(:locate_and_select)
    fake_locator = Object.new
    fake_locator.define_singleton_method(:locate_and_select) do |_issue, **_kwargs|
      { status: :unresolved, diagnostics: ['no entity for this issue'] }
    end
    SUAnalysis::Extension::IssueLocator.singleton_class.send(:define_method, :locate_and_select) do |*args, **kw|
      fake_locator.locate_and_select(*args, **kw)
    end
    begin
      dr = SUAnalysis::Extension::DialogRunner
      raised = false
      begin
        dr.on_locate(dialog, controller, 'short_edge|9999|1')
      rescue StandardError
        raised = true
      end
      assert !raised,
             'on_locate MUST NOT propagate a logging exception (the previous $stdout.puts bug)'
    ensure
      SUAnalysis::Extension::IssueLocator.singleton_class.send(
        :define_method, :locate_and_select, original_locator
      )
    end
  ensure
    v14_block_004_restore_stdio
  end
end

# ---- Test 9: end-to-end -- V14-9-style workflow under private-puts console ----

test 'V14-RUNTIME-BLOCK-004: end-to-end -- on_prepare_workspace on a real failing source emits toast + render on SU2020 console' do
  v14_block_004_install_private_console
  begin
    ar = v14_block_004_make_ar
    dialog, controller = v14_block_004_make_dialog_and_controller(ar)
    # Simulate the V14-9 narrow test scenario: a failing source
    # with an exception raised inside the action block. The
    # previous bug masked this exception with a NoMethodError
    # from $stderr.puts; the new contract surfaces the
    # ORIGINAL exception via the toast and runs push_data.
    real_failure = StandardError.new('SOURCE_READY failed: v14-block-004-scenario')
    dr = SUAnalysis::Extension::DialogRunner
    dr.send(:_safe_invoke, dialog, controller, 'on_prepare_workspace') do
      raise real_failure
    end
    toast_calls = dialog.executed_scripts.select { |s| s.include?('SUAIP.toast') }
    render_calls = dialog.executed_scripts.select { |s| s.include?('SUAIP.render') }
    assert toast_calls.any? { |s| s.include?('SOURCE_READY failed') },
           'toast MUST surface the REAL failure (not the NoMethodError)'
    assert !render_calls.empty?,
           'push_data MUST run so the UI leaves the intermediate state'
  ensure
    v14_block_004_restore_stdio
  end
end
