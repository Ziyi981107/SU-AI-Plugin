# frozen_string_literal: true

module SUAnalysis
  module Core
    module Analyzers
      #
      # DuplicateDetector — ISSUE 001 (PI_TASK_001 §9).
      #
      # Two edges are duplicate candidates when both endpoints coincide
      # within `tolerance.duplicate`. Direction is ignored (A→B ≡ B→A).
      #
      # Complexity: O(E) amortized by hash-bucketing on a quantized,
      # direction-normalized (start, end) key. Edges whose endpoints
      # fall in different quantization cells never compare (they cannot
      # be duplicates given the tolerance); edges in the same cell
      # compare pairwise inside the bucket.
      #
      # The detector **never modifies** edges, only reports issue hashes
      # (PI_TASK_001 §4 NEVER MODIFY SOURCE CAD).
      #
      class DuplicateDetector
        TYPE = 'duplicate_edge_candidate'

        def detect(snapshot)
          tol    = snapshot.config.tolerance.duplicate
          bucket = Hash.new { |h, k| h[k] = [] }

          snapshot.edges.each do |edge|
            bucket[canonical_key(edge, tol)] << edge
          end

          issues = []
          bucket.each_value do |group|
            # all pairwise within the bucket
            (0...group.size).each do |i|
              ((i + 1)...group.size).each do |j|
                issues << build_issue(group[i], group[j], tol)
              end
            end
          end
          issues
        end

        private

        # Quantize both endpoints, then return a sorted (a, b) key so
        # direction is normalized.
        def canonical_key(edge, tol)
          a = edge.start_point.map { |c| (c / tol).floor }
          b = edge.end_point.map   { |c| (c / tol).floor }
          [a, b].sort_by(&:to_s)  # Array#sort_by ensures deterministic ordering without lex coords confusion
        end

        def build_issue(a, b, tol)
          {
            kind:              TYPE,
            severity:          'medium',
            confidence:        'high',
            source_entity_ids: [a.source.entity_id, b.source.entity_id],
            edge_ids:          [a.id, b.id],
            location:          midpoint(a.start_point, a.end_point),
            message:           'Duplicate edge candidate: two edges share both endpoints within duplicate_tolerance.',
            metadata:          {
              duplicate_tolerance: tol,
              length_a:            a.length,
              length_b:            b.length
            }
          }
        end

        def midpoint(p, q)
          [
            (p[0] + q[0]) / 2.0,
            (p[1] + q[1]) / 2.0,
            (p[2] + q[2]) / 2.0
          ]
        end
      end
    end
  end
end
