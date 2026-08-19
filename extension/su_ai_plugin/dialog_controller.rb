#
# extension/dialog_controller.rb — per-dialog state holder.
#
# Per CodeX Round 018 BLOCK-004:
#   - The View is `model.active_view` (capability-checked), NOT
#     `dialog.get_view` (which does not exist on UI::HtmlDialog).
#   - The model is REQUIRED for the Locate action to resolve.
#

require_relative 'core/analysis_result'

module SUAnalysis
  module Extension
    class DialogController
      attr_reader :result, :bound_dialog, :model

      def initialize(result, model: nil)
        raise ArgumentError, 'result is required' if result.nil?
        @result = result
        @model = model
        @bound_dialog = nil
      end

      # Attach the dialog and remember the live model reference.
      def bind(dialog, model = nil)
        @bound_dialog = dialog
        @model = model unless model.nil?
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
        IssueLocator.locate_and_select(issue, model: @model, view: view)
      end

      private

      # Per CodeX Round 018 BLOCK-004: UI::HtmlDialog has no
      # #get_view. The View lives on the Model.
      def view
        return nil unless @model
        return nil unless @model.respond_to?(:active_view)
        @model.active_view
      rescue StandardError
        nil
      end
    end
  end
end
