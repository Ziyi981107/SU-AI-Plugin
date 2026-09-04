#
# extension/ui_bridge.rb — bridge between the Registry's Symbol-keyed
# Hashes and the JSON-safe Hashes the JS layer consumes.
#
# Per CodeX Round 011..014:
#   - All Issue Hashes inside core/ use Symbol keys (pure Ruby).
#   - The boundary that emits JS payload (JSON.stringify) MUST
#     convert Symbol keys to String keys.
#   - No callable / Symbol / Date / Time objects may cross the
#     boundary; only String, Number, Boolean, Array, Object (Hash).
#

require 'json'
require_relative 'core/issue_registry'
require_relative 'core/working_mode_runner'
require_relative 'cad_prep_workflow_presenter'

module SUAnalysis
  module Extension
    module UIBridge
      module_function

      # Build the JS-safe payload from an AnalysisResult.
      # Returns Hash with String keys (top level + nested).
      #
      # V1.1 (per plan §4.9): adds ONE new top-level key `layerGroups`
      # so the JS layer can render the dialog's "Layers" section
      # without having to traverse `summary['layer_groups']`. The
      # `summary['layer_groups']` path remains as the canonical Ruby
      # access point (also String-keyed on the JSON boundary); the
      # top-level `layerGroups` is the convenience-shaped key the JS
      # render function reads. Both carry the SAME data (no
      # duplication of work; the underlying Array is referenced from
      # the frozen AnalysisResult).
      #
      # V1.2 (per directive 026): adds ONE new top-level key
      # `layerIssueGroups` for the dialog's 'Issues by Layer'
      # section. Mirrors `summary['layer_issue_groups']` (canonical
      # Ruby access) so both sides cannot drift. Backward-
      # compatible default: V1.0 / V1.1 callers that don't supply
      # layer_issue_groups get `layerIssueGroups == []` AND
      # `summary['layer_issue_groups'] == []`.
      #
      # V1.3 (per directive 027): adds ONE new top-level key
      # `faceInventoryGroups` for the dialog's 'Face Inventory'
      # section. Mirrors `summary['face_inventory_groups']`
      # (canonical Ruby access). Also exposes 'faces' and
      # 'faces_with_holes' scalar counters at the summary level
      # (already added by AnalysisResult.summary in commit
      # b896e04's data layer). Backward-compatible default:
      # V1.0 / V1.1 / V1.2 callers that don't supply
      # face_inventory_groups get `faceInventoryGroups == []`
      # AND `summary['face_inventory_groups'] == []` AND
      # `summary['faces'] == 0` AND `summary['faces_with_holes'] == 0`.
      #
      # V1.4 (per directive 030, Stage 4): adds ONE new top-level
      # key `derivedWorkspace` for the dialog's 'Working Mode'
      # section. Default value is the runner's idle snapshot
      # (state='none', no source_snapshot_id, etc.).
      #
      # V1.9A-A1: adds ONE new top-level key `cadPrepWorkflow`
      # for the new production UX presentation model. Pure
      # / testable / JSON-safe / additive — legacy callers
      # (V1.0–V1.8) that read summary / groups / diagnostics /
      # layerGroups / layerIssueGroups / faceInventoryGroups /
      # derivedWorkspace continue to receive them unchanged.
      # The new payload is the SOLE new top-level key.
      def as_html_data(analysis_result)
        return {} if analysis_result.nil?
        result = {
          'selectionType'      => analysis_result.selection_type.to_s,
          'selectionLabel'     => analysis_result.selection_label.to_s,
          'summary'            => stringify_hash(analysis_result.summary),
          'displayData'        => stringify_hash(analysis_result.display_data),
          'diagnostics'        => stringify_array(analysis_result.diagnostics),
          'groups'             => stringify_groups(analysis_result.registry),
          'layerGroups'        => stringify_array(analysis_result.layer_groups),
          'layerIssueGroups'   => stringify_array(analysis_result.layer_issue_groups),
          'faceInventoryGroups' => stringify_array(analysis_result.face_inventory_groups),
          # V1.4: working-mode snapshot from WorkingModeRunner.
          # Default ('none' state) when no workspace is active.
          'derivedWorkspace'   => SUAnalysis::Core::WorkingModeRunner.snapshot
        }
        # V1.9A-A1: additive top-level presentation model.
        # The presenter is pure / testable; it consumes the
        # analysis_result + the live WorkingModeRunner.snapshot
        # and emits a JSON-safe presentation Hash. No live
        # SketchUp objects cross the bridge (the presenter
        # only reads primitive / Hash / Array values).
        begin
          wf_payload = SUAnalysis::Extension::CadPrepWorkflowPresenter.present(
            analysis_result:   analysis_result,
            workspace_snapshot: SUAnalysis::Core::WorkingModeRunner.snapshot
          )
          result['cadPrepWorkflow'] = wf_payload
        rescue StandardError => e
          # Defensive: a presenter failure MUST NOT break the
          # legacy payload. Surface the failure as a STALE
          # presentation so the UI can render a coherent
          # fallback instead of crashing mid-dialog.
          #
          # Per AIPM source review (non-blocking cleanup):
          # the main product UI MUST stay generic and user-
          # readable. The technical exception detail
          # (class + message) stays in the SketchUp Ruby
          # Console via the existing _safe_log path on the
          # rebound rescue, NOT in the primary product
          # copy.
          begin
            warn("[SU-AI-Plugin] V1.9A-A1 presenter fault: " +
                 "#{e.class}: #{e.message}")
          rescue StandardError
            # Logging is best-effort; never propagate.
            nil
          end
          result['cadPrepWorkflow'] = {
            'schema_version' => SUAnalysis::Extension::CadPrepWorkflowPresenter::SCHEMA_VERSION,
            'overall_state'  => 'STALE',
            'headline'       => '工作副本已失效',
            'subheadline'    => '请重新生成工作副本或放弃当前副本',
            'selection'      => { 'type' => analysis_result.selection_type.to_s,
                                  'label' => analysis_result.selection_label.to_s },
            'issue_summary'  => { 'kind' => 'issues', 'headline' => '处理失败',
                                  'subtitle' => '请重新生成工作副本',
                                  'chips' => [{ 'value' => 1, 'label' => '失败' }],
                                  'cta' => '重新检测' },
            'cards'          => [],
            'recovery'       => {
              'title'          => '处理失败',
              'desc'           => 'CAD 准备界面暂不可用。请重新生成工作副本，或放弃当前副本以保持源 CAD 完整。技术细节可在 SketchUp Ruby 控制台查看。',
              'primary_label'  => '重新生成工作副本',
              'primary_callback' => 'rebuild_workspace',
              'secondary_label'  => '放弃工作副本',
              'secondary_callback' => 'discard_workspace'
            }
          }.freeze
        end
        result
      end

      # Serialize as_json using only String keys. Returns a JSON string.
      def to_json(analysis_result)
        JSON.generate(as_html_data(analysis_result))
      end

      # ---- internals ------------------------------------------------------

      def stringify_hash(h)
        return {} if h.nil?
        out = {}
        h.each do |k, v|
          out[k.to_s] = stringify_value(v)
        end
        out
      end

      def stringify_array(a)
        return [] if a.nil?
        out = []
        a.each do |item|
          out << stringify_value(item)
        end
        out
      end

      def stringify_groups(registry)
        return [] if registry.nil?
        registry.groups.map do |g|
          {
            'type'         => g[:type].to_s,
            'count'        => g[:count].to_i,
            'defaultOpen'  => g[:default_open] ? true : false,
            'issues'       => stringify_array(g[:issues])
          }
        end
      end

      # Recursively coerce any object to a JSON-safe value.
      # Hashes get String keys; arrays are mapped; everything else is
      # passed through if it's a String/Numeric/Boolean/nil, otherwise
      # coerced via to_s.
      def stringify_value(v)
        case v
        when Hash
          stringify_hash(v)
        when Array
          stringify_array(v)
        when String, Numeric, TrueClass, FalseClass, NilClass
          v
        else
          v.to_s
        end
      end
    end
  end
end
