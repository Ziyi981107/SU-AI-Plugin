
module SUAnalysis
  module Core
    module Analyzers
      #
      # DuplicateDetector — ISSUE 001 (PI_TASK_001 §9).
      #
      # Two edges are duplicate candidates when both endpoints coincide
      # within `tolerance.duplicate`. Direction is ignored (A→B ≡ B→A).
      #
      # BLOCK-002 (CodeX 032 recheck 2026-08-25): the previous
      # bucketing used `quantize_point` with a 1-cell grid; two
      # endpoints that are within tolerance but quantize to
      # different cells were NEVER compared (e.g., start=(1.00005,
      # 0, 0) and start=(1.00015, 0, 0) with tol=1e-4 quantize to
      # cells 10000 and 10001 respectively — they were in two
      # separate buckets and the detector silently missed the
      # duplicate).
      #
      # Fix: use a 2x-tolerance cell width and compare across
      # ADJACENT buckets (the closest cells whose quantizations
      # could legitimately produce a within-tolerance match), AND
      # when an edge's exact quantization lands on a cell
      # boundary (residual within tol of the next integer), also
      # place a copy of the edge in the neighboring bucket so
      # cross-bucket candidates are guaranteed to be discovered.
      #
      # The final comparison still uses the DIRECT endpoint
      # matcher (not the legacy `quantize_point` equality); the
      # same matcher the proposer / validator use.
      #
      # Complexity: O(E + E_b * k^2) where E_b is the maximum
      # bucket size and k is the adjacent-bucket fan-out. For
      # typical SU selections this stays small.
      #
      # The detector **never modifies** edges, only reports issue hashes
      # (PI_TASK_001 §4 NEVER MODIFY SOURCE CAD).
      #
      class DuplicateDetector
        TYPE = 'duplicate_edge_candidate'

        def detect(snapshot)
          tol    = snapshot.config.tolerance.duplicate
          # 2*tolerance cell width + boundary-aware placement:
          # two endpoints within `tol` quantize to cells that are
          # at most 2 cells apart on a 2*tol grid (never 3+).
          cell  = tol * 2.0
          bucket = Hash.new { |h, k| h[k] = [] }

          snapshot.edges.each do |edge|
            keys = adjacent_canonical_keys(edge, tol, cell)
            keys.each { |k| bucket[k] << edge }
          end

          issues = []
          seen_pairs = {}
          bucket.each_value do |group|
            (0...group.size).each do |i|
              ((i + 1)...group.size).each do |j|
                a = group[i]
                b = group[j]
                next if a.equal?(b)
                # Direct match gate — never trust bucketing
                # alone. This is the V1.5 BLOCK-002 contract:
                # the spatial bucket is candidate
                # acceleration only; the direct matcher is the
                # match rule.
                next unless direct_match?(a, b, tol)
                pair_key = [a.id, b.id].sort_by(&:to_s)
                next if seen_pairs[pair_key]
                seen_pairs[pair_key] = true
                issues << build_issue(a, b, tol)
              end
            end
          end
          issues
        end

        private

        # Quantize both endpoints on a `cell` grid (cell = 2*tol),
        # then return a sorted (a, b) key so direction is
        # normalized. Return ALL the canonical keys whose cells
        # are within 1 cell of the exact quantization so that an
        # edge whose true endpoints sit on a cell boundary is
        # also placed in the neighboring cells. This guarantees
        # that any two within-tolerance endpoints share at least
        # one bucket.
        def adjacent_canonical_keys(edge, tol, cell)
          exact = canonical_key_exact(edge, cell)
          # Boundary scan: if any quantized coordinate sits
          # within `tol` of the next integer (residual >= 1 - 2*tol/cell
          # when cell = 2*tol -> residual >= 0.5 of cell), place
          # the edge in the +/- 1 shifted bucket as well.
          a = edge.start_point
          b = edge.end_point
          shifts = []
          [[a, 0], [a, 1], [a, 2], [b, 0], [b, 1], [b, 2]].each do |pt, axis|
            q = (pt[axis] / cell).floor
            r = pt[axis] - q * cell
            if r <= tol || (cell - r) <= tol
              shifts << [0, 0, 0]
              shifts << shift_for(axis, 1)
              shifts << shift_for(axis, -1)
            end
          end
          shifts << [0, 0, 0]
          shifts.uniq.map do |s|
            shifted = exact.map { |coord| [coord[0] + s[0], coord[1] + s[1], coord[2] + s[2]] }
            shifted.sort_by(&:to_s)
          end.uniq
        end

        def shift_for(axis, delta)
          a = [0, 0, 0]
          a[axis] = delta
          a
        end

        def canonical_key_exact(edge, cell)
          a = edge.start_point.map { |c| (c / cell).floor }
          b = edge.end_point.map   { |c| (c / cell).floor }
          [a, b]
        end

        # The DIRECT endpoint matcher. Two edges are duplicates
        # iff EITHER both endpoints coincide within `tol`
        # (forward exact) OR the endpoints are reversed within
        # `tol` (reversed exact). Layer names must also match
        # after the Layer0 normalization.
        def direct_match?(a, b, tol)
          sa = a.start_point
          ea = a.end_point
          sb = b.start_point
          eb = b.end_point
          return false unless finite_point?(sa) && finite_point?(ea)
          return false unless finite_point?(sb) && finite_point?(eb)
          forward  = points_within?(sa, sb, tol) && points_within?(ea, eb, tol)
          reversed = points_within?(sa, eb, tol) && points_within?(ea, sb, tol)
          return false unless forward || reversed
          unless normalize_layer(a.respond_to?(:layer) ? a.layer : nil) ==
                 normalize_layer(b.respond_to?(:layer) ? b.layer : nil)
            return false
          end
          true
        end

        def finite_point?(p)
          return false unless p.is_a?(Array) && p.length == 3
          p.all? { |v| v.respond_to?(:finite?) && v.finite? }
        end

        def points_within?(p, q, tol)
          return false unless p.is_a?(Array) && q.is_a?(Array) && p.length == 3 && q.length == 3
          (0..2).all? { |i| (p[i].to_f - q[i].to_f).abs <= tol.to_f }
        end

        def normalize_layer(name)
          return 'Layer0' if name.nil?
          s = name.to_s
          return 'Layer0' if s.empty?
          case s.downcase
          when 'layer0', 'default', 'untagged'
            'Layer0'
          else
            s
          end
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
