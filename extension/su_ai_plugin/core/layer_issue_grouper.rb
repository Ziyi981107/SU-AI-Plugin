
#
# core/layer_issue_grouper.rb — V1.1 bucket issues by their source layer.
#
# Per V1.1 plan §4.5:
#   - Input: Array<UIIssue> + Array<LayerRecord>.
#   - Output: Array<LayerIssueBucket> Hash.
#   - Default-open policy: same as IssueGrouper (open iff bucket
#     contains a :high issue, else first non-empty bucket).
#   - Issues without source[:layer_name] are attributed to the
#     V1.0 fallback "Layer0" (matches the V1.0 layer normalization
#     in extension/preflight_runner.rb).
#   - Buckets only include layers that appear in the supplied
#     LayerRecord list — no auto-creation of phantom layers.
#

module SUAnalysis
  module Core
    module LayerIssueGrouper
      module_function

      DEFAULT_LAYER_NAME = 'Layer0'.freeze

      # Build buckets. Returns Array<Hash> with the locked field set.
      def group(issues, layer_records)
        # Build a set of known layer names (no phantom layers).
        known_names = layer_records.map { |r| r.name.to_s }.uniq
        # Always include the V1.0 fallback "Layer0" so issues with
        # nil layer_name still have a bucket.
        known_names << DEFAULT_LAYER_NAME if issues && !issues.empty?
        known_names.uniq!

        # Bucket issues by source[:layer_name] (or DEFAULT_LAYER_NAME).
        by_name = Hash.new { |h, k| h[k] = [] }
        if issues
          issues.each do |iss|
            next unless iss.is_a?(Hash)
            src = iss[:source]
            layer_name = if src.is_a?(Hash) && src[:layer_name] && !src[:layer_name].to_s.empty?
                           src[:layer_name].to_s
                         else
                           DEFAULT_LAYER_NAME
                         end
            # Only bucket if the layer is known.
            next unless known_names.include?(layer_name)
            by_name[layer_name] << iss
          end
        end

        # Default-open policy: open iff the bucket has a :high issue.
        # The first non-empty bucket is also opened when no :high exists
        # anywhere (mirrors IssueGrouper policy).
        any_high = issues && issues.any? { |iss| iss.is_a?(Hash) && iss[:severity] == 'high' }
        result = []
        first_emitted = false
        known_names.each do |name|
          bucket = by_name[name]
          next if bucket.empty?
          default_open = if any_high
                           bucket.any? { |iss| iss[:severity] == 'high' }
                         else
                           !first_emitted
                         end
          first_emitted = true if default_open
          result << {
            name:         name,
            count:        bucket.length,
            default_open: default_open,
            issues:       bucket.sort_by { |iss| iss[:issue_id].to_s }
          }
        end
        result
      end
    end
  end
end
