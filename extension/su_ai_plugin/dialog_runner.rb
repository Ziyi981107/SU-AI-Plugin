#
# extension/dialog_runner.rb — HtmlDialog lifecycle.
#
# Per CodeX Round 018:
#   - set_file with absolute path (NOT set_html with embedded asset).
#   - add_action_callback with BLOCKS (NOT method(:name)).
#   - ready handshake: JS calls window.SUAIP.ready() after
#     DOMContentLoaded; Ruby then pushes data via execute_script.
#   - set_on_closed releases the controller (GC the dialog).
#   - show(result, model) propagates the model to the controller so
#     the Locate action can resolve against the real model.
#   - The dialog reference is held in Loader.@live_dialog so the
#     window is not GC'd; Loaderr.release_dialog! is called via
#     set_on_closed.
#

require 'json'
require_relative 'dialog_controller'
require_relative 'ui_bridge'
require_relative 'issue_locator'

module SUAnalysis
  module Extension
    module DialogRunner
      module_function

      # Show the HtmlDialog for one AnalysisResult.
      # Returns the dialog instance (or nil in tests).
      def show(result, model: nil)
        return nil unless result
        return nil unless defined?(UI::HtmlDialog)
        return nil unless UI::HtmlDialog.respond_to?(:new)
        controller = DialogController.new(result, model: model)
        dialog = UI::HtmlDialog.new(
          dialog_title:    'CAD Analyzer Result',
          preferences_key: 'SU-AI-Plugin.cad_analyzer.v1',
          width:           720,
          height:          600,
          left:            100,
          top:             100,
          resizable:       true
        )
        # Absolute path for relative CSS/JS resolution.
        index_path = File.expand_path('html/index.html', __dir__)
        dialog.set_file(index_path)
        # Callbacks as BLOCKS (real SketchUp API). Keep references
        # alive via closures over controller/dialog so callbacks fire
        # on the correct controller instance.
        dialog.add_action_callback('ready')   { |_ctx| push_data(dialog, controller) }
        dialog.add_action_callback('locate')  { |_ctx, issue_id| on_locate(dialog, controller, issue_id) }
        dialog.add_action_callback('close')   { |_ctx| on_close(dialog, controller) }
        # set_on_closed releases the Loader-side cache so the window
        # can be GC'd after the user closes it.
        dialog.set_on_closed do
          on_close(dialog, controller)
        end
        controller.bind(dialog, model)
        # Hold the live dialog reference for the dialog lifetime.
        # Per CodeX Round 018 BLOCK-006 + official SketchUp guidance.
        Loader.keep_dialog!(dialog)
        dialog.show
        dialog
      end

      # ---- internals ------------------------------------------------------

      # Push the serialized AnalysisResult to the JS layer.
      # Uses JSON.generate + execute_script with a wrapped, fixed
      # function name. Never interpolates user text into executable JS.
      def push_data(dialog, controller)
        payload = UIBridge.as_html_data(controller.result)
        json = JSON.generate(payload)
        dialog.execute_script("window.SUAIP.render(#{json})")
      end

      def on_locate(dialog, controller, issue_id)
        return unless issue_id.is_a?(String)
        result = controller.locate(issue_id)
        return unless result
        if result[:status] == :unresolved
          msg = JSON.generate("source no longer available for: #{issue_id}")
          dialog.execute_script("window.SUAIP.toast(#{msg})")
          $stdout.puts("[SU-AI-Plugin] locate_issue: #{result[:diagnostics].last || 'unresolved'}")
        end
      end

      # Idempotent close handler. Releases the controller and the
      # Loader-side live-dialog cache.
      def on_close(_dialog, controller)
        controller.release!
        Loader.release_dialog!
      end
    end
  end
end
