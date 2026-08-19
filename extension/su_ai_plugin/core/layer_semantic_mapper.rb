
#
# core/layer_semantic_mapper.rb — V1.1 aggregate layer -> LayerSummary.
#
# Per V1.1 plan §4.4:
#   - Input: Array<LayerRecord> + Array<UIIssue> (for issue_count attribution).
#   - Output: Array<LayerSummary> Hash with the locked field set.
#   - Sort: role bucket order (LayerRole::ALL), then within each bucket
#     visible == true first (R009), then issue_count DESC, then name ASC.
#   - Layers with visibility_unknown: true sort alongside visible rows
#     (operational visible: true) but the badge text distinguishes them.
#
# LayerRole::visibility_label is the SOURCE OF TRUTH for the dialog
# badge text — the JS layer does NOT recompute it.
#

require_relative 'layer_record'
require_relative 'layer_role'
require_relative 'layer_role_config'

module SUAnalysis
  module Core
    module LayerSemanticMapper
      module_function

      # Build LayerSummary Array from per-layer records + per-issue
      # list. `issue_count` is derived by matching the issue's source
      # layer_name to the LayerRecord name.
      def build(layer_records, issues)
        # Deduplicate by name; sum edge_count; collect unique
        # visibility / visibility_unknown per layer (first-seen-wins,
        # per §12 default).
        by_name = {}
        layer_records.each do |rec|
          name = rec.name
          by_name[name] ||= {
            name:               name,
            edge_count:         0,
            role:               rec.role,
            role_rule:          rec.role_rule,
            visible:            rec.visible,
            visibility_unknown: rec.visibility_unknown
          }
          by_name[name][:edge_count] += rec.edge_count
        end

        # Issue count per layer (issue[:source][:layer_name] -> count).
        # Issues without a layer_name are attributed to "Layer0" (V1.0
        # fallback). The issue might also have a nil source; we treat
        # that as Layer0 too.
        issue_count_by_name = Hash.new(0)
        if issues
          issues.each do |iss|
            layer_name = if iss.is_a?(Hash) && iss[:source].is_a?(Hash)
                           src = iss[:source]
                           if src[:layer_name] && !src[:layer_name].to_s.empty?
                             src[:layer_name].to_s
                           else
                             'Layer0'
                           end
                         else
                           'Layer0'
                         end
            issue_count_by_name[layer_name] += 1
          end
        end

        # Build summaries.
        summaries = by_name.values.map do |agg|
          {
            name:               agg[:name],
            role:               agg[:role],
            role_rule:          agg[:role_rule],
            role_label:         LayerRole::HUMAN[agg[:role]],
            visible:            agg[:visible],
            visibility_unknown: agg[:visibility_unknown],
            visibility_label:   LayerRole.visibility_label(agg[:visible], agg[:visibility_unknown]),
            edge_count:         agg[:edge_count],
            issue_count:        issue_count_by_name[agg[:name]]
          }
        end

        # Sort: role bucket order, then within bucket (visible first,
        # then issue_count DESC, then name ASC).
        role_rank = Hash.new(LayerRole::ALL.size)
        LayerRole::ALL.each_with_index { |r, i| role_rank[r] = i }
        summaries.sort_by do |s|
          [
            role_rank[s[:role]],
            s[:visible] ? 0 : 1,                     # visible rows first
            -s[:issue_count],                        # issue_count DESC
            s[:name].to_s                            # name ASC tiebreak
          ]
        end
      end
    end
  end
end
