# frozen_string_literal: true

require_relative '../quantize_key'

module SUAnalysis
  module Core
    module Analyzers
      #
      # GapCandidateDetector — ISSUE 003b (PI_TASK_001 §9).
      #
      # Pairs of open endpoints whose euclidean distance is in
      # (epsilon, gap_search_tolerance]. Each pair appears once.
      #
      # Algorithm:
      #   1. Collect open vertices from VertexIndex.
      #   2. Bucket them spatially (cell_size ≈ max(gap_search, 1.0)).
      #   3. For each open vertex, scan neighbor cells within reach and
      #      collect pairs (sorted (low_id, high_id) to dedupe).
      #   4. Final gate is the explicit distance check; bucketing only
      #      avoids the O(V^2) all-pairs scan PI_TASK_001 §15 forbids.
      #
      class GapCandidateDetector
        TYPE = 'gap_candidate'

        def detect(snapshot)
          tol       = snapshot.config.tolerance.gap_search
          open_vs   = snapshot.vertex_records.select { |v| v.degree == 1 }
          cell_size = [tol, 1.0].max

          bucket = Hash.new { |h, k| h[k] = [] }
          open_vs.each do |v|
            key = QuantizeKey.bucket_for(v.coordinate, cell_size)
            bucket[key] << v
          end

          seen_pairs = {}
          issues = []

          open_vs.each do |v|
            reach = ((tol / cell_size).ceil + 1).to_i
            cx, cy, cz = QuantizeKey.bucket_for(v.coordinate, cell_size)

            (-reach..reach).each do |dx|
              (-reach..reach).each do |dy|
                (-reach..reach).each do |dz|
                  key = [cx + dx, cy + dy, cz + dz]
                  Array(bucket[key]).each do |other|
                    next if other.id == v.id
                    pair_key = [v.id, other.id].sort
                    next if seen_pairs[pair_key]
                    d = distance(v.coordinate, other.coordinate)
                    next if d > tol
                    next if d < 1.0e-9
                    seen_pairs[pair_key] = true
                    issues << build_issue(v, other, d, tol)
                  end
                end
              end
            end
          end

          issues
        end

        private

        def build_issue(v1, v2, d, tol)
          edge_id_1 = v1.edge_ids.first
          edge_id_2 = v2.edge_ids.first
          mid = [
            (v1.coordinate[0] + v2.coordinate[0]) / 2.0,
            (v1.coordinate[1] + v2.coordinate[1]) / 2.0,
            (v1.coordinate[2] + v2.coordinate[2]) / 2.0
          ]
          {
            kind:              TYPE,
            severity:          'low',
            confidence:        'medium',
            source_entity_ids: [],
            edge_ids:          [edge_id_1, edge_id_2],
            location:          mid,
            message:           "Gap candidate: two open endpoints within gap_search_tolerance (#{format('%.6f', d)} inch).",
            metadata:          {
              distance:         d,
              gap_tolerance:    tol,
              vertex_id_1:      v1.id,
              vertex_id_2:      v2.id
            }
          }
        end

        def distance(a, b)
          dx = a[0] - b[0]
          dy = a[1] - b[1]
          dz = a[2] - b[2]
          Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
        end
      end
    end
  end
end
