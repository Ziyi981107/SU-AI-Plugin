#
# core/issue_id_assigner.rb — pure-Ruby deterministic issue_id generator.
#
# Per CodeX Review 011..014 (2026-08-18), Stage 6 BLOCK-001 v2 fix:
#   - issue_id is built from canonical source tokens, NOT from
#     object_id or entity_id.
#   - The canonical sort key is the lexicographic order of the
#     serialized pid_path (dot-string) for each source, with a
#     deterministic analysis-data fallback when the pid_path is empty.
#   - The counter is the LAST tie-breaker, applied only after the
#     canonical keys are sorted.
#
# Per CodeX Review 015 (2026-08-18) BLOCK-002:
#   - issue_id NEVER uses entity_id or object_id (Ruby object_id).
#   - The fallback signature when both pid_path and location are
#     missing uses only deterministic analysis data:
#     sorted edge_ids, or a constant no-source key.
#   - IssueEnricher.enrich_all sorts by canonical keys BEFORE
#     assigning counter — so reversed input order produces the same
#     issue_id for the same logical Issue.
#
# issue_id format: "{issue_type}|{key1}+{key2}+...|{counter}"
# Example:         "duplicate_edge_candidate|10.20.555+12.21.777|1"
#
# The same inputs produce the same issue_id across runs.
#

module SUAnalysis
  module Core
    module IssueIdAssigner
      module_function

      # Deterministic no-source key. Used ONLY when both pid_path
      # is empty AND location is nil. This is the LAST-RESORT fallback
      # and is shared by all sources that hit it. CodeX BLOCK-002
      # forbids using entity_id or object_id here.
      NO_SOURCE_KEY = 'no-source'.freeze

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
        "#{issue_type}|#{keys.join('+')}|#{counter_within_type.to_i}".freeze
      end

      # Build the canonical (sorted) source-key list from tokens.
      # Exposed for tests and IssueEnricher.sort_by_canonical_key.
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
      #
      # CodeX BLOCK-002 forbids object_id or entity_id. The fallback
      # uses ONLY deterministic analysis data:
      #   1. quantized coordinates (when location is provided)
      #   2. sorted edge_ids (when edge_ids are present)
      #   3. constant NO_SOURCE_KEY (last-resort, shared by all)
      def geometry_signature(token, location: nil, coord_epsilon: 1.0e-6)
        if location.is_a?(Array) && location.size == 3
          q = location.map { |c| (Float(c) / coord_epsilon).floor.to_i }
          return "geo:#{q.join(',')}"
        end
        edge_ids = token[:edge_ids]
        if edge_ids.is_a?(Array) && !edge_ids.empty?
          sorted = edge_ids.map { |x| Integer(x).to_s }.sort
          return "edges:#{sorted.join(',')}"
        end
        NO_SOURCE_KEY
      end
    end
  end
end
