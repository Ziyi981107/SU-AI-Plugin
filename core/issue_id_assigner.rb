#
# core/issue_id_assigner.rb — pure-Ruby deterministic issue_id generator.
#
# Per CodeX Review 011..014 (2026-08-18), Stage 6 BLOCK-001 v2 fix:
#   - issue_id is built from canonical source tokens, NOT from
#     object_id or entity_id.
#   - The canonical sort key is the lexicographic order of the
#     serialized pid_path (dot-string) for each source, with a
#     geometry-signature fallback when the pid_path is empty.
#   - The counter is the LAST tie-breaker, applied only after the
#     canonical keys are sorted.
#
# issue_id format: "{issue_type}|{key1}+{key2}+...|{counter}"
# Example: "duplicate_edge_candidate|10.20.555+12.21.777|1"
#
# The same inputs produce the same issue_id across runs.
#

module SUAnalysis
  module Core
    module IssueIdAssigner
      module_function

      # Assign a deterministic issue_id given:
      #   issue_type:            String
      #   source_tokens:         Array<SourceToken>
      #   location:              Array<Float,3> | nil
      #   coord_epsilon:         Float (default 1.0e-6)
      #   counter_within_type:   Integer (1-based)
      # Returns: String (frozen)
      def assign(issue_type:, source_tokens:, location: nil,
                 coord_epsilon: 1.0e-6, counter_within_type: 1)
        keys = canonical_source_keys(
          source_tokens: source_tokens,
          location: location,
          coord_epsilon: coord_epsilon
        )
        "[#{issue_type}]|#{keys.join('+')}|#{counter_within_type.to_i}"
      end

      # Build the canonical (sorted) source-key list from tokens.
      # Exposed for tests and IssueRegistry.find duplication logic.
      def canonical_source_keys(source_tokens:, location: nil, coord_epsilon: 1.0e-6)
        keys = Array(source_tokens).map do |t|
          pid = t[:persistent_id_path]
          if pid && !pid.empty?
            Array(pid).map { |x| Integer(x).to_s }.join('.')
          else
            geometry_signature(t, location: location, coord_epsilon: coord_epsilon)
          end
        end
        keys.compact.sort
      end

      # Geometry fallback signature for a token whose pid_path is empty.
      # Uses quantized coordinates when location is provided, else
      # falls back to "edge_id:#{edge_id}" or "entity_id:#{entity_id}".
      def geometry_signature(token, location: nil, coord_epsilon: 1.0e-6)
        if location.is_a?(Array) && location.size == 3
          q = location.map { |c| (Float(c) / coord_epsilon).floor.to_i }
          "geo:#{q.join(',')}"
        elsif token[:edge_ids] && !token[:edge_ids].empty?
          "edge_id:#{Array(token[:edge_ids]).first}"
        elsif token[:entity_id]
          "entity_id:#{token[:entity_id]}"
        else
          "anon:#{token.object_id}"
        end
      end
    end
  end
end
