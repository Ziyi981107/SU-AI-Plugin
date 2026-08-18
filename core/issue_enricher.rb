#
# core/issue_enricher.rb — pure-Ruby enrichment from a normalized
# analyzer issue Hash + EdgeRecord index into a UIIssue Hash
# carrying SourceToken tokens, deterministic issue_id, and
# locatable derivation.
#
# Per CodeX Review 011..014 (2026-08-18), Stage 6 BLOCK-001 v3 fix:
#   - One SourceToken per resolved EdgeRecord (whole-token dedup).
#   - SourceToken carries 4 fields: persistent_id_path, entity_id,
#     nested, pid_path_complete.
#   - `nested` is structural_depth > 0; NOT pid_path.size > 1.
#   - `pid_path_complete` is the full-path invariant (covers leaf too).
#   - `locatable` derivation:
#       locatable iff at least one token is complete-root,
#       complete-nested, or incomplete-root (entity_id present).
#
# Per CodeX Review 015 (2026-08-18) BLOCK-002:
#   - enrich_all sorts by canonical_source_keys BEFORE assigning
#     counter, so reversed input order produces the same issue_id.
#   - Missing edge_id is recorded in metadata (no_source_marker).
#
# This module is pure Ruby. It does NOT call SketchUp or access
# compatibility/. It only maps Hash -> Hash.
#

module SUAnalysis
  module Core
    module IssueEnricher
      module_function

      # Enrich one normalized analyzer issue.
      # snapshot_lookup: Hash<Integer, EdgeRecord> built by
      #   analyzers_runner.rb (Gate B).
      # counter_within_type: Integer, sequential within the issue_type.
      # coord_epsilon: Float for geometry-signature fallback.
      # Returns a UIIssue Hash (Symbol keys, JSON-safe values).
      def enrich_one(normalized, snapshot_lookup:, counter_within_type: 1,
                    coord_epsilon: 1.0e-6)
        return nil unless normalized.is_a?(Hash)
        sources = build_source_tokens(normalized, snapshot_lookup)
        locatable = compute_locatable(sources)
        issue_id = IssueIdAssigner.assign(
          issue_type: normalized[:issue_type],
          source_tokens: sources,
          location: normalized[:location],
          coord_epsilon: coord_epsilon,
          counter_within_type: counter_within_type
        )
        {
          issue_id:           issue_id,
          issue_type:         normalized[:issue_type],
          severity:           normalized[:severity],
          confidence:         normalized[:confidence],
          sources:            sources,
          source_entity_ids:  sources.map { |t| t[:entity_id] }.compact,
          edge_ids:           normalized[:edge_ids].dup,
          location:           normalized[:location],
          message:            normalized[:message],
          metadata:           normalized[:metadata].dup,
          locatable:          locatable,
          display_length:     nil
        }
      end

      # Enrich a batch of normalized issues.
      # Per CodeX BLOCK-002: sort by canonical_source_keys BEFORE
      # assigning counter, so reversed input order produces the same
      # issue_id for the same logical Issue.
      def enrich_all(normalized_issues, snapshot_lookup:,
                    coord_epsilon: 1.0e-6)
        bullets = Array(normalized_issues).map do |iss|
          # Build a single bullet without a counter; counter is
          # assigned after sorting.
          build_bullet_without_id(iss, snapshot_lookup, coord_epsilon)
        end.compact
        by_type = {}
        bullets.each do |bullet|
          by_type[bullet[:issue_type]] ||= []
          by_type[bullet[:issue_type]] << bullet
        end
        result = []
        by_type.each do |_type, list|
          # Sort by canonical source keys for stable counter assignment.
          sorted = list.sort_by do |bullet|
            IssueIdAssigner.canonical_source_keys(
              source_tokens: bullet[:sources],
              location: bullet[:location],
              coord_epsilon: coord_epsilon
            )
          end
          sorted.each_with_index do |bullet, idx|
            bullet[:issue_id] = IssueIdAssigner.assign(
              issue_type: bullet[:issue_type],
              source_tokens: bullet[:sources],
              location: bullet[:location],
              coord_epsilon: coord_epsilon,
              counter_within_type: idx + 1
            )
            result << bullet
          end
        end
        result
      end

      # Build the aligned SourceToken array for one issue.
      # Returns Array<Hash> (Symbol keys). PIDs may be empty when
      # source lookup misses; the SourceToken preserves the
      # structural fields regardless.
      # Missing edge_ids are recorded in metadata with the
      # :no_source_marker field (CodeX NIT 4).
      def build_source_tokens(normalized, snapshot_lookup)
        tokens = []
        missing_edge_ids = []
        Array(normalized[:edge_ids]).each do |edge_id|
          rec = snapshot_lookup[Integer(edge_id)]
          if rec.nil?
            missing_edge_ids << Integer(edge_id)
            tokens << {
              persistent_id_path: [].freeze,
              entity_id:          nil,
              nested:             false,
              pid_path_complete:  false
            }
            next
          end
          src = rec.source
          path = src.persistent_id_path || []
          tokens << {
            persistent_id_path: path.dup.freeze,
            entity_id:          src.entity_id,
            nested:             src.structural_depth.to_i > 0,
            pid_path_complete:  src.pid_path_complete ? true : false
          }
        end
        # Stash missing edge_ids in `normalized[:metadata]` so the
        # caller can surface them. We mutate a copy, not the input.
        if !missing_edge_ids.empty? && normalized[:metadata].is_a?(Hash)
          normalized[:metadata] = normalized[:metadata].dup
          normalized[:metadata][:no_source_marker] = missing_edge_ids.map(&:to_s).sort.join(',')
        end
        dedup_whole_tokens(tokens)
      end

      # Determine locatable from tokens. Per BLOCK-001 v3:
      #   locatable iff at least one token is complete-root,
      #   complete-nested, or incomplete-root (entity_id present).
      def compute_locatable(sources)
        sources.any? do |t|
          next true if !t[:pid_path_complete] && t[:nested] == false && !t[:entity_id].nil?
          next true if t[:pid_path_complete] && t[:nested] == false
          next true if t[:pid_path_complete] && t[:nested]
        end
      end

      # Whole-token dedup (NOT field-by-field). Preserves order.
      def dedup_whole_tokens(tokens)
        seen = {}
        out = []
        tokens.each do |t|
          key = [t[:persistent_id_path], t[:entity_id], t[:nested], t[:pid_path_complete]]
          next if seen[key]
          seen[key] = true
          out << t
        end
        out
      end

      # Private helper: build a bullet without a counter. The
      # counter is assigned after sorting in enrich_all.
      def build_bullet_without_id(normalized, snapshot_lookup, coord_epsilon)
        return nil unless normalized.is_a?(Hash)
        sources = build_source_tokens(normalized, snapshot_lookup)
        locatable = compute_locatable(sources)
        {
          issue_id:           nil, # assigned by enrich_all
          issue_type:         normalized[:issue_type],
          severity:           normalized[:severity],
          confidence:         normalized[:confidence],
          sources:            sources,
          source_entity_ids:  sources.map { |t| t[:entity_id] }.compact,
          edge_ids:           normalized[:edge_ids].dup,
          location:           normalized[:location],
          message:            normalized[:message],
          metadata:           normalized[:metadata].dup,
          locatable:          locatable,
          display_length:     nil
        }
      end
    end
  end
end
