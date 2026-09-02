#
# core/segment_conflict.rb — V1.7 conservative segment-conflict
# predicate.
#
# Per V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-002:
#
# Create / reuse ONE small shared PURE V1.7 segment-conflict
# predicate used by BOTH:
#   A. WorkingModeRunner's existing-edge crossing safety
#      (WorkingModeRunner._crossing_checker_proc);
#   B. GapPairProser's simultaneous-proposal X3 conflict safety
#      (GapPairProposer.propose pairwise crossing check).
#
# It must conservatively detect in a finite 3D / coplanar-
# compatible context:
#   1. proper interior crossing;
#   2. full collinear containment;
#   3. partial collinear interior overlap;
#   4. bridge endpoint strictly inside an unrelated edge;
#   5. unrelated endpoint strictly inside the bridge;
#   6. simultaneous proposed-bridge overlap / conflict.
#
# It must NOT reject MERELY DISJOINT COLLINEAR SEGMENTS
# (Blueprint §10.3: shared endpoints that are legitimately the
# two target canonical endpoints are not conflicts).
#
# Stable reason families:
#   existing-edge conflict -> 'bridge_crossing' (mapped)
#   proposal/proposal conflict -> 'bridge_conflict' (mapped)
#   actual third canonical node on bridge interior ->
#       'third_node_on_bridge' (caller maps via point_in_segment_interior?)
#
# This module is intentionally pure (no host mutation, no
# random, no Ruby >= 2.4-only API). Used by both production
# paths and tests so they cannot silently diverge.
#

module SUAnalysis
  module Core
    module SegmentConflict
      module_function

      # Check whether two segments conflict.
      #
      # Inputs:
      #   segment_a: [p1, p2]  -- the proposed bridge (3-Float Arrays)
      #   segment_b: [q1, q2]  -- the unrelated edge (or another
      #               proposed bridge); 3-Float Arrays.
      #   eps:       coordinate_epsilon tolerance (>0 finite).
      #
      # Returns a Hash:
      #   {
      #     'conflict' => true | false,
      #     'reason'   => stable string reason code or nil
      #   }
      #
      # Stable reason codes (the caller maps these to the
      # required stable V1.7 reason families per dispatch):
      #   'proper_interior_crossing'     -- proper strict crossing
      #   'collinear_overlap'            -- full / partial collinear overlap
      #   'bridge_endpoint_on_unrelated' -- T-junction: bridge endpoint
      #                                      strictly inside segment_b
      #   'unrelated_endpoint_on_bridge' -- T-junction: segment_b endpoint
      #                                      strictly inside bridge
      #
      # Shared endpoints are NOT a conflict (Blueprint §10.3):
      #   'shared_endpoint'              -- caller can ignore / treat as safe
      def conflict?(segment_a, segment_b, eps: 1.0e-6)
        p1, p2 = segment_a
        q1, q2 = segment_b
        return _safe unless _valid_inputs?(p1, p2, q1, q2, eps)

        # Shared endpoint (Blueprint §10.3): legitimately the
        # two target canonical endpoints -> not a conflict.
        if _shared_endpoint?(p1, q1, eps) || _shared_endpoint?(p1, q2, eps) ||
           _shared_endpoint?(p2, q1, eps) || _shared_endpoint?(p2, q2, eps)
          return { 'conflict' => false, 'reason' => 'shared_endpoint' }
        end

        # Bounding-box quick reject (XY plane -- Z compat is
        # checked upstream by GapPairProposer and the
        # WorkingModeRunner crossing checker).
        return _safe unless _bbox_overlap_xy?(p1, p2, q1, q2, eps)

        # ----- Collinear case -----
        # When ALL FOUR points are collinear, we must detect
        # containment / partial overlap (and accept disjoint
        # collinear as safe per dispatch).
        if _collinear?(p1, p2, q1, eps) && _collinear?(p1, p2, q2, eps)
          if _collinear_overlap?(p1, p2, q1, q2, eps)
            return { 'conflict' => true, 'reason' => 'collinear_overlap' }
          else
            return _safe
          end
        end

        # ----- Proper strict crossing -----
        if _segments_cross_strictly?(p1, p2, q1, q2, eps)
          return { 'conflict' => true, 'reason' => 'proper_interior_crossing' }
        end

        # ----- T-junction (point-on-segment interior) -----
        # Bridge endpoint strictly inside segment_b
        # (intent: implicit T-junction against an unrelated
        # edge). Caller maps this to existing-edge
        # conflict -> 'bridge_crossing'.
        if point_in_segment_interior?(p1, [q1, q2], eps: eps) ||
           point_in_segment_interior?(p2, [q1, q2], eps: eps)
          return { 'conflict' => true, 'reason' => 'bridge_endpoint_on_unrelated' }
        end
        # segment_b endpoint strictly inside the bridge
        # (intent: an unrelated endpoint is exactly on the
        # proposed bridge -- i.e. the bridge would silently
        # T-junction into that endpoint). Caller maps this
        # to existing-edge conflict -> 'bridge_crossing' OR
        # (for canonical nodes) -> 'third_node_on_bridge'.
        if point_in_segment_interior?(q1, [p1, p2], eps: eps) ||
           point_in_segment_interior?(q2, [p1, p2], eps: eps)
          return { 'conflict' => true, 'reason' => 'unrelated_endpoint_on_bridge' }
        end

        _safe
      end

      # Pure point-on-segment-interior predicate.
      # Returns true iff `point` lies STRICTLY INSIDE the closed
      # segment [p1, p2] (within `eps`) AND the projection
      # parameter t is in (0, 1) with endpoint epsilon exclusion.
      # Endpoints are NOT a conflict (Blueprint §10.3: shared
      # endpoints that are legitimately the two target canonical
      # endpoints are not conflicts).
      def point_in_segment_interior?(point, segment, eps: 1.0e-6)
        p1, p2 = segment
        return false unless _valid_inputs?(p1, p2, point, nil, eps)
        # Endpoint exclusion: NOT a "strictly inside" hit when
        # the point is shared with an endpoint.
        return false if _shared_endpoint?(point, p1, eps) ||
                        _shared_endpoint?(point, p2, eps)
        # Reject degenerate segment.
        sx = (p2[0] - p1[0]).abs
        sy = (p2[1] - p1[1]).abs
        sz = (p2[2] - p1[2]).abs
        seg_len2 = (sx * sx) + (sy * sy) + (sz * sz)
        return false if seg_len2 <= 0
        # Projection parameter t.
        wx = point[0] - p1[0]
        wy = point[1] - p1[1]
        wz = point[2] - p1[2]
        dot = (wx * (p2[0] - p1[0])) + (wy * (p2[1] - p1[1])) + (wz * (p2[2] - p1[2]))
        t = dot / seg_len2
        # Endpoint exclusion band.
        seg_len = Math.sqrt(seg_len2)
        return false if seg_len <= 0
        eps_seg = eps.to_f / seg_len
        return false if t <= eps_seg
        return false if t >= (1.0 - eps_seg)
        # Closest-point distance check.
        proj_x = p1[0] + t * (p2[0] - p1[0])
        proj_y = p1[1] + t * (p2[1] - p1[1])
        proj_z = p1[2] + t * (p2[2] - p1[2])
        dx = point[0] - proj_x
        dy = point[1] - proj_y
        dz = point[2] - proj_z
        closest_d = Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
        closest_d <= eps.to_f
      end

      # ---- internals ----

      def _safe
        { 'conflict' => false, 'reason' => nil }
      end

      def _valid_inputs?(p1, p2, q1, q2, eps)
        return false unless _finite?(p1) && _finite?(p2)
        return false unless q1.nil? || _finite?(q1)
        return false unless q2.nil? || _finite?(q2)
        return false unless eps.is_a?(Numeric) && eps.respond_to?(:finite?) &&
                            eps.finite? && eps > 0
        true
      end

      def _finite?(p)
        p.is_a?(Array) && p.length == 3 &&
          p.all? { |v| v.is_a?(Numeric) && v.respond_to?(:finite?) && v.finite? }
      end

      def _shared_endpoint?(a, b, eps)
        return false unless _finite?(a) && _finite?(b)
        dx = a[0] - b[0]
        dy = a[1] - b[1]
        dz = a[2] - b[2]
        Math.sqrt((dx * dx) + (dy * dy) + (dz * dz)) <= eps.to_f
      end

      def _bbox_overlap_xy?(p1, p2, q1, q2, eps)
        ax_min = [p1[0], p2[0]].min
        ax_max = [p1[0], p2[0]].max
        ay_min = [p1[1], p2[1]].min
        ay_max = [p1[1], p2[1]].max
        bx_min = [q1[0], q2[0]].min
        bx_max = [q1[0], q2[0]].max
        by_min = [q1[1], q2[1]].min
        by_max = [q1[1], q2[1]].max
        pad = eps.to_f
        return false if ax_max + pad < bx_min
        return false if bx_max + pad < ax_min
        return false if ay_max + pad < by_min
        return false if by_max + pad < ay_min
        true
      end

      # Segment orientation in 2D (XY plane; Z compatibility is
      # verified upstream by the proposer + executor).
      def _orientation(p, q, r)
        (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
      end

      # Strict proper crossing: d1*d2<0 AND d3*d4<0 AND each
      # di non-zero. Shared endpoints and collinear cases are
      # handled before this predicate.
      def _segments_cross_strictly?(p1, p2, q1, q2, eps)
        d1 = _orientation(p1, p2, q1)
        d2 = _orientation(p1, p2, q2)
        d3 = _orientation(q1, q2, p1)
        d4 = _orientation(q1, q2, p2)
        return false if d1.abs < eps.to_f || d2.abs < eps.to_f ||
                        d3.abs < eps.to_f || d4.abs < eps.to_f
        ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
          ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
      end

      # Collinear test: q lies on the infinite line through p1p2
      # (orientation near zero).
      def _collinear?(p1, p2, q, eps)
        return false unless _finite?(q)
        _orientation(p1, p2, q).abs <= eps.to_f
      end

      # Two collinear segments overlap iff their projections
      # onto the segment axis overlap (after endpoint exclusion).
      # Disjoint collinear segments are NOT a conflict (Blueprint
      # §10.3 + dispatch INT-002).
      def _collinear_overlap?(p1, p2, q1, q2, eps)
        seg_len2 = _seg_len2(p1, p2)
        return false if seg_len2 <= 0
        seg_len = Math.sqrt(seg_len2)
        eps_seg = eps.to_f / seg_len
        t_q1 = _project_t(p1, p2, q1)
        t_q2 = _project_t(p1, p2, q2)
        lo = [t_q1, t_q2].min
        hi = [t_q1, t_q2].max
        # Disjoint: hi strictly below 0 (with eps_seg band) OR lo
        # strictly above 1 (with eps_seg band).
        return false if hi <= eps_seg
        return false if lo >= (1.0 - eps_seg)
        # Touching at exactly one endpoint: shared endpoint
        # handled above by `_shared_endpoint?` -- here we still
        # treat touching as no-conflict because dispatch says
        # `do not reject merely disjoint collinear segments`.
        # Touching (lo == 0 AND hi in [0,1]) or (hi == 1 AND lo
        # in [0,1]) is technically disjoint from a "bridge
        # consumes another edge" standpoint; we still emit
        # conflict only when there is genuine interior overlap.
        # Compute the interior span of segment_b inside [0,1]:
        interior_lo = lo < eps_seg ? eps_seg : lo
        interior_hi = hi > (1.0 - eps_seg) ? (1.0 - eps_seg) : hi
        return false if interior_hi <= interior_lo
        true
      end

      def _project_t(p1, p2, q)
        wx = q[0] - p1[0]
        wy = q[1] - p1[1]
        wz = q[2] - p1[2]
        sx = p2[0] - p1[0]
        sy = p2[1] - p1[1]
        sz = p2[2] - p1[2]
        dot = (wx * sx) + (wy * sy) + (wz * sz)
        seg_len2 = (sx * sx) + (sy * sy) + (sz * sz)
        return 0.0 if seg_len2 <= 0
        dot / seg_len2
      end

      def _seg_len2(p1, p2)
        sx = p2[0] - p1[0]
        sy = p2[1] - p1[1]
        sz = p2[2] - p1[2]
        (sx * sx) + (sy * sy) + (sz * sz)
      end
    end
  end
end