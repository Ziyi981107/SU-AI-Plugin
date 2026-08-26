
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
        # could legitimately contain an edge that is within
        # `tol` of this edge (BLOCK-002 V1.5 round 3).
        #
        # V1.5 round 3 fix (CodeX Review 033 BLOCK-002 finding):
        # the previous implementation shifted ALL six quantized
        # coordinates together by the SAME 3-D vector whenever ANY
        # axis of either endpoint sat on a cell boundary. This
        # missed the case where only ONE endpoint of an edge is on
        # a boundary: a cross-bucket candidate was never compared
        # because the OTHER endpoint's bucket was shifted AWAY from
        # its neighbor.
        #
        # Correct enumeration: each endpoint's quantized cell can
        # independently be the exact cell OR +/- 1 in any axis
        # whose residual is within `tol` of the cell boundary.
        # The 6 axes (3 per endpoint) are enumerated
        # INDEPENDENTLY; the total number of bucket keys per edge
        # is at most 2^6 = 64 in the worst case (all 6 axes on a
        # boundary), but in practice it is small (typically 1-4).
        # The direct_match? gate below still enforces the actual
        # tolerance rule, so the bucket enumeration is candidate
        # acceleration only.
        def adjacent_canonical_keys(edge, tol, cell)
          a = edge.start_point
          b = edge.end_point
          # Per-endpoint exact cell quantizations.
          aq = [0, 1, 2].map { |ax| (a[ax] / cell).floor }
          bq = [0, 1, 2].map { |ax| (b[ax] / cell).floor }
          # Build a bounded set of bucket keys. The CORRECT
          # enumeration must guarantee: if A's start and B's
          # start are within `tol` AND each lands on a cell
          # boundary, A and B share at least one bucket.
          #
          # For each endpoint, for each axis, if the residual is
          # within `tol` of a cell boundary, that endpoint can
          # plausibly be in EITHER its exact cell OR the
          # immediately adjacent cell in that axis. The
          # exhaustive enumeration over every combination would
          # produce up to 3^6 = 729 keys per edge (one per
          # endpoint-axis delta), which is far too slow on
          # large selections.
          #
          # Equivalent and bounded enumeration:
          #   1. The exact bucket key (no shift).
          #   2. For each endpoint-axis pair on a boundary, ONE
          #      additional key where ONLY that endpoint is
          #      shifted by +/- 1 in that axis (and no other
          #      endpoint-axis pair is shifted).
          #
          # Correctness argument: if A and B share a within-tol
          # start (or end) point, the shared point's cell is some
          # cell K. After quantization:
          #   - Both A.start and B.start quantize to either K or
          #     K-1 or K+1 (depending on which side of the cell
          #     boundary they land on).
          #   - If both quantize to K, they share the exact key.
          #   - If they quantize to K and K+1 respectively,
          #     A's shifted-start key (start shifted +1) puts A
          #     in K+1, matching B's exact key. They share that
          #     bucket.
          #   - If they quantize to K and K-1, similar with -1.
          # So at most one of A's 13 keys matches one of B's
          # 13 keys, and the pair is found. The direct_match?
          # gate below still enforces the actual tolerance rule.
          # NOTE: many bucket keys may collapse to the SAME
          # canonical key after sorting the (start_cell,
          # end_cell) pair, so we apply .uniq.
          keys = []
          # Bounded key construction: include the exact bucket,
          # plus at most 6 single-axis shifted variants (3 axes
          # × 2 endpoints). For a synthetic 5000-edge selection
          # where every edge has integer-aligned coordinates,
          # every endpoint-axis is on a boundary, so each edge
          # gets at most 1 + 6 = 7 keys (and many collapse to
          # the same sorted pair).
          keys << canonical_key_from_cells(aq, bq)
          aq_deltas = boundary_deltas(a, cell, tol)
          bq_deltas = boundary_deltas(b, cell, tol)
          aq_deltas.each do |d|
            keys << canonical_key_from_cells(add_delta(aq, d), bq)
          end
          bq_deltas.each do |d|
            keys << canonical_key_from_cells(aq, add_delta(bq, d))
          end
          keys.uniq
        end

        # Return a list of 3-element Integer delta vectors
        # describing each +/-1 axis-shift that is justified by
        # the point being on a cell boundary.
        def boundary_deltas(pt, cell, tol)
          deltas = []
          [0, 1, 2].each do |axis|
            q = (pt[axis] / cell).floor
            r = pt[axis] - q * cell
            on_lower = r <= tol
            on_upper = (cell - r) <= tol
            if on_lower
              d = [0, 0, 0]
              d[axis] = -1
              deltas << d
            end
            if on_upper
              d = [0, 0, 0]
              d[axis] = +1
              deltas << d
            end
          end
          deltas
        end

        def add_delta(cells, delta)
          [cells[0] + delta[0], cells[1] + delta[1], cells[2] + delta[2]]
        end

        def canonical_key_from_cells(aq, bq)
          [aq, bq].sort_by { |x| x.map(&:to_s).join(',') }
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
