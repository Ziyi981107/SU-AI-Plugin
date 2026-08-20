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
      def as_html_data(analysis_result)
        return {} if analysis_result.nil?
        result = {
          'selectionType'  => analysis_result.selection_type.to_s,
          'selectionLabel' => analysis_result.selection_label.to_s,
          'summary'        => stringify_hash(analysis_result.summary),
          'displayData'    => stringify_hash(analysis_result.display_data),
          'diagnostics'    => stringify_array(analysis_result.diagnostics),
          'groups'         => stringify_groups(analysis_result.registry),
          'layerGroups'    => stringify_array(analysis_result.layer_groups)
        }
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
