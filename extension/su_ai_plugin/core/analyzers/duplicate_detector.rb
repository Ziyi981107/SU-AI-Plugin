module SUAnalysis
  module Core
    module Analyzers
      #
      # DuplicateDetector — V1.5 Round-4
      #
      # Two edges are duplicate candidates when both endpoints
      # coincide within the CAPTURED `tolerance.duplicate`
      # per-axis. Direction is ignored (A→B ≡ B→A).
      #
      # Round-4 changes (AIPM §3 BLOCK-002A):
      #
      #   * Candidate enumeration now uses the SHARED
      #     `DuplicateGeometrySemantics.enumerate_candidates`
      #     (3D grid cell size = tolerance; mathematical floor;
      #     index EVERY edge under BOTH endpoint cells; 27-
      #     neighbor-cell query around each endpoint; union +
      #     dedup candidate IDs; shared direct_match? as final
      #     authority; stable unordered pair dedup). The previous
      #     "exact key + <=6 single-axis shifted keys" scheme
      #     is REMOVED — it was not authoritative.
      #
      #   * Spatial bucketing is GONE. The direct matcher IS the
      #     match rule. Bucket acceleration is no longer used
      #     here because the new candidate-enumeration produces
      #     a tight candidate set without the per-bucket fan-out
      #     bugs that motivated the legacy code.
      #
      #   * detector, proposer, validator, and post-state ALL
      #     share the SAME direct predicate via
      #     `DuplicateGeometrySemantics`.
      #
      # The detector NEVER modifies edges; it only emits issue
      # hashes (PI_TASK_001 §4 NEVER MODIFY SOURCE CAD).
      #
      class DuplicateDetector
        TYPE = 'duplicate_edge_candidate'

        def detect(snapshot)
          tol = snapshot.config.tolerance.duplicate
          return [] unless DuplicateGeometrySemantics.valid_tolerance?(tol)
          # Build the per-edge record tuples. We feed them to
          # the shared candidate-pair enumerator which performs
          # the complete tolerance-correct enumeration.
          records = snapshot.edges.map do |edge|
            next nil unless edge.respond_to?(:start_point) && edge.respond_to?(:end_point)
            {
              id:    edge.respond_to?(:id) ? edge.id : nil,
              start: edge.start_point,
              end:   edge.end_point,
              layer: edge.respond_to?(:layer) ? edge.layer : nil
            }
          end.compact
          # Enumerate candidate (i, j) index pairs under the
          # CAPTURED tolerance.
          candidate_pairs = DuplicateGeometrySemantics.enumerate_candidates(records, tol)
          issues = []
          seen = {}
          candidate_pairs.each do |i, j|
            a = snapshot.edges.find { |e| e.respond_to?(:id) && e.id == records[i][:id] }
            b = snapshot.edges.find { |e| e.respond_to?(:id) && e.id == records[j][:id] }
            next if a.nil? || b.nil?
            next if a.equal?(b)
            pair_key = [a.id, b.id].sort_by { |x| x.to_s }
            next if seen[pair_key]
            seen[pair_key] = true
            issues << build_issue(a, b, tol)
          end
          issues
        end

        private

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