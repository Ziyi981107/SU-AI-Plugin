#
# extension/dialog_controller.rb — per-dialog state holder.
#
# Per CodeX Round 011..014:
#   - Per-dialog state: registry snapshot, model ref, registry version,
#     diagnostics. The controller owns the registry-projection;
#     the dialog owns only the rendered UI.
#   - Lifecycle: bind(dialog) attaches; release! clears references
#     so the dialog can be GC'd when set_on_closed fires.
#

require_relative '../core/analysis_result'

module SUAnalysis
  module Extension
    class DialogController
      attr_reader :result, :bound_dialog

      def initialize(result)
        raise ArgumentError, 'result is required' if result.nil?
        @result = result
        @bound_dialog = nil
      end

      # Attach the dialog; remember the live model reference.
      def bind(dialog, model = nil)
        @bound_dialog = dialog
        @model = model
      end

      # Clear references so the dialog can be GC'd.
      def release!
        @bound_dialog = nil
        @model = nil
      end

      # Apply the Locate action for one issue_id.
      # Returns the LocateResult struct from IssueLocator.locate.
      def locate(issue_id)
        return nil unless issue_id.is_a?(String)
        issue = @result.find_issue(issue_id)
        return nil if issue.nil?
        IssueLocator.locate_and_select(issue, model: @model,
                                                 view: @bound_dialog ? view : nil)
      end

      private

      def view
        return nil unless @bound_dialog
        @bound_dialog.respond_to?(:get_view) ? @bound_dialog.get_view : nil
      end
    end
  end
end
