#
# core/planar_normalization_analyzer.rb — V1.6 Planar Normalization / Z Policy.
#
# Per frozen V1.6 Blueprint §6 (Planar Baseline Algorithm):
#
#   Pure-Ruby, host-free, deterministic analyzer that examines the
#   eligible unique DERIVED edge vertices in world/model coordinates
#   and proposes (or refuses to propose) one dominant Z-band window
#   with a deterministic target_z.
#
# Locked semantics:
#
#   - Input:
#       eligible_vertices: Array of 3-Float Arrays (world/model
#                         coordinates), each Array length == 3,
#                         all values finite. Order-stable.
#       planar_z_snap:     Float > 0 (the captured V1.6 tolerance).
#       coordinate_epsilon: Float > 0 (the near-zero epsilon).
#
#   - Output (a frozen PlanarNormalizationResult Hash):
#       state           : Symbol
#       target_z        : Float | nil
#       eligible_count  : Integer
#       already_planar  : Integer
#       movable_count   : Integer
#       outlier_count   : Integer
#       proposed_moves  : Array of Hashes
#                         {vertex_index:, vertex:,
#                          from_z:, to_z:, movement:}
#       outliers        : Array of Hashes {vertex_index:, vertex:}
#       max_movement    : Float
#       reason          : String (stable, inspectable; nil iff state
#                         is NO_CANDIDATE/READY_TO_NORMALIZE/APPLIED
#                         without reason)
#       tolerance_used  : Float
#
#   - States:
#       NO_CANDIDATE        - already planar / no eligible / no inputs
#       READY_TO_NORMALIZE  - one deterministic safe batch exists
#       REVIEW_REQUIRED     - ambiguous (50/50 split / tied windows /
#                             shared-vertex scope ambiguity / curve /
#                             face scope refusal)
#       invalid_tolerance   - tolerance invalid; no executable batch
#       invalid_input       - input contained non-finite or malformed
#                             coordinates; no destructive action
#
#   - Algorithm (deterministic sliding window):
#       1. Sort eligible Z ascending.
#       2. Slide a window; valid window iff (max_z - min_z) <=
#          planar_z_snap.
#       3. Find the window containing the greatest number of
#          eligible unique vertices.
#       4. If two materially different windows tie for maximum
#          count -> REVIEW_REQUIRED ("tied_dominant_windows").
#       5. Require the winning window to contain a strict majority
#          (> 50%) of eligible vertices; otherwise REVIEW_REQUIRED
#          ("no_strict_majority").
#       6. target_z = deterministic median of the winning window.
#       7. Inlier  : abs(v.z - target_z) <= planar_z_snap.
#          Movable : inlier AND abs(v.z - target_z) > coordinate_epsilon.
#          Already : inlier AND abs(v.z - target_z) <= coordinate_epsilon.
#          Outlier : outside the planar band; not auto-normalized.
#
# This module is INTENTIONALLY host-free. It does NOT mutate the
# workspace, host handles, or any derived state. The runner
# adapts the analyzer's result into a RepairAction / workspace
# mutation; this file only computes the proposal.
#
# The analyzer is deterministic: identical input + identical
# captured tolerance -> identical result Hash (including the
# order of `proposed_moves` and `outliers` which mirror the
# input's order so callers can map back to source/derived
# indices).
#

module SUAnalysis
  module Core
    module PlanarNormalizationAnalyzer
      module_function

      # State enum (V1.6 Blueprint §7 Preview states).
      STATE_NO_CANDIDATE        = :NO_CANDIDATE
      STATE_READY_TO_NORMALIZE  = :READY_TO_NORMALIZE
      STATE_REVIEW_REQUIRED     = :REVIEW_REQUIRED
      STATE_INVALID_TOLERANCE   = :invalid_tolerance
      STATE_INVALID_INPUT       = :invalid_input

      # Validate the captured tolerance.
      # Per V1.6 Blueprint §4.2: invalid / nil / non-finite /
      # <= 0 normalization tolerance => fail closed (no
      # executable batch). Reused by host-side preflight
      # before opening any operation.
      def valid_tolerance?(value)
        return false if value.nil?
        return false unless value.is_a?(Numeric)
        return false unless value.respond_to?(:finite?) ? value.finite? : true
        return false if value <= 0
        true
      end

      # Validate the coordinate epsilon.
      def valid_coordinate_epsilon?(value)
        return false if value.nil?
        return false unless value.is_a?(Numeric)
        return false unless value.respond_to?(:finite?) ? value.finite? : true
        return false if value <= 0
        true
      end

      # Run the analyzer on a host-free vertex list.
      #
      # `eligible_vertices` is an Array of 3-Float Arrays. The
      # analyzer tolerates the array being empty / nil; the result
      # state is NO_CANDIDATE in that case.
      #
      # Returns a frozen PlanarNormalizationResult Hash.
      def analyze(eligible_vertices:, planar_z_snap:, coordinate_epsilon:)
        if !valid_tolerance?(planar_z_snap)
          return _fail_result(
            state: STATE_INVALID_TOLERANCE,
            reason: 'invalid_tolerance',
            tolerance_used: nil,
            eligible_count: _safe_len(eligible_vertices),
            proposed_moves: [],
            outliers: []
          )
        end
        if !valid_coordinate_epsilon?(coordinate_epsilon)
          return _fail_result(
            state: STATE_INVALID_TOLERANCE,
            reason: 'invalid_coordinate_epsilon',
            tolerance_used: planar_z_snap.to_f,
            eligible_count: _safe_len(eligible_vertices),
            proposed_moves: [],
            outliers: []
          )
        end
        verts = _normalize_input(eligible_vertices)
        if verts.nil?
          # non-finite / malformed input detected.
          return _fail_result(
            state: STATE_INVALID_INPUT,
            reason: 'invalid_input_coordinates',
            tolerance_used: planar_z_snap.to_f,
            eligible_count: _safe_len(eligible_vertices),
            proposed_moves: [],
            outliers: []
          )
        end
        if verts.empty?
          return _make_result(
            state: STATE_NO_CANDIDATE,
            target_z: nil,
            eligible_count: 0,
            already_planar: 0,
            movable_count: 0,
            outlier_count: 0,
            proposed_moves: [],
            outliers: [],
            max_movement: 0.0,
            reason: 'no_eligible_vertices',
            tolerance_used: planar_z_snap.to_f
          )
        end
        # ---- P1 already planar ----
        # All z equal within coordinate_epsilon -> NO_CANDIDATE.
        zs = verts.map { |v| v[2] }
        if _all_within_eps?(zs, coordinate_epsilon.to_f)
          return _make_result(
            state: STATE_NO_CANDIDATE,
            target_z: zs.first,
            eligible_count: verts.length,
            already_planar: verts.length,
            movable_count: 0,
            outlier_count: 0,
            proposed_moves: [],
            outliers: [],
            max_movement: 0.0,
            reason: 'already_planar',
            tolerance_used: planar_z_snap.to_f
          )
        end
        # ---- Sliding window on sorted Z ----
        # Sort Z ascending but keep original indices so we can
        # report `vertex_index` (input-stable order) for the UI.
        indexed = zs.each_with_index.map { |z, i| [z, i] }.sort_by { |z, _| z }
        sorted_zs = indexed.map { |z, _| z }
        sorted_idx = indexed.map { |_, i| i }
        n = sorted_zs.length
        snap = planar_z_snap.to_f
        # Operational epsilon for the window-width comparison.
        # Plain subtraction `(max - min) > snap` is sensitive to
        # IEEE 754 rounding: e.g. `1.010 - 1.0` evaluates to
        # `0.010000000000000009`, which would (incorrectly) be
        # considered > 0.01. We compare `max > min + snap +
        # op_eps` instead, where `op_eps` is a relative epsilon
        # scaled to snap.
        op_eps = (snap * 1.0e-9).abs + 1.0e-12
        # Compute window counts in O(n) via two-pointer.
        best_count = 0
        best_lo = 0
        best_hi = -1
        ties = 0  # number of distinct windows tied with the best count
        lo = 0
        (0...n).each do |hi|
          # Advance lo while the window is too wide.
          while lo < hi && sorted_zs[hi] > sorted_zs[lo] + snap + op_eps
            lo += 1
          end
          count = hi - lo + 1
          if count > best_count
            best_count = count
            best_lo = lo
            best_hi = hi
            ties = 1
          elsif count == best_count
            # Materially different window? Two windows that share
            # the same lo or hi (i.e. consecutive in the sorted
            # array) are NOT materially different -- we treat the
            # growing slide as the same window. Only a separate
            # window (with both lo and hi distinct) is a true
            # "materially different" window.
            if lo != best_lo || hi != best_hi
              ties += 1
            end
          end
        end
        # ---- P6 tied dominant windows -> REVIEW_REQUIRED ----
        if ties > 1
          return _make_result(
            state: STATE_REVIEW_REQUIRED,
            target_z: nil,
            eligible_count: verts.length,
            already_planar: 0,
            movable_count: 0,
            outlier_count: 0,
            proposed_moves: [],
            outliers: [],
            max_movement: 0.0,
            reason: 'tied_dominant_windows',
            tolerance_used: snap
          )
        end
        # ---- P5 no strict majority -> REVIEW_REQUIRED ----
        # best_count is strictly > n/2 -> strict majority.
        unless best_count.to_f > (n.to_f / 2.0)
          return _make_result(
            state: STATE_REVIEW_REQUIRED,
            target_z: nil,
            eligible_count: verts.length,
            already_planar: 0,
            movable_count: 0,
            outlier_count: 0,
            proposed_moves: [],
            outliers: [],
            max_movement: 0.0,
            reason: 'no_strict_majority',
            tolerance_used: snap
          )
        end
        # ---- Winning window target = deterministic median ----
        # sorted_idx[best_lo..best_hi] is the winning window's
        # original-index list. We take the median of that
        # window's Z values (deterministic: middle of an odd
        # count; mean of the two middle values for an even
        # count). Median is robust to outliers WITHIN the band
        # by definition (the window's spread is <= planar_z_snap).
        win_zs = sorted_zs[best_lo..best_hi]
        target_z = _median(win_zs)
        # ---- Classify ----
        proposed_moves = []
        outliers      = []
        already       = 0
        movable       = 0
        max_movement  = 0.0
        verts.each_with_index do |v, idx|
          z = v[2]
          diff = (z - target_z).abs
          if diff <= snap
            # inlier
            if diff <= coordinate_epsilon.to_f
              already += 1
            else
              movable += 1
              movement = target_z - z
              m_abs = movement.abs
              max_movement = m_abs if m_abs > max_movement
              proposed_moves << {
                vertex_index: idx,
                vertex: [v[0], v[1], v[2]],
                from_z: z.to_f,
                to_z:   target_z.to_f,
                movement: movement.to_f
              }.freeze
            end
          else
            outliers << {
              vertex_index: idx,
              vertex: [v[0], v[1], v[2]]
            }.freeze
          end
        end
        # ---- P9 idempotency: nothing to move -> NO_CANDIDATE ----
        if proposed_moves.empty?
          return _make_result(
            state: STATE_NO_CANDIDATE,
            target_z: target_z,
            eligible_count: verts.length,
            already_planar: already,
            movable_count: 0,
            outlier_count: outliers.length,
            proposed_moves: [],
            outliers: outliers,
            max_movement: 0.0,
            reason: 'all_within_epsilon',
            tolerance_used: snap
          )
        end
        _make_result(
          state: STATE_READY_TO_NORMALIZE,
          target_z: target_z,
          eligible_count: verts.length,
          already_planar: already,
          movable_count: movable,
          outlier_count: outliers.length,
          proposed_moves: proposed_moves,
          outliers: outliers,
          max_movement: max_movement.to_f,
          reason: nil,
          tolerance_used: snap
        )
      end

      # ---- internals ----

      def _normalize_input(eligible_vertices)
        return [] if eligible_vertices.nil?
        return nil unless eligible_vertices.is_a?(Array)
        out = []
        eligible_vertices.each do |v|
          unless _is_finite_point?(v)
            return nil
          end
          out << [v[0].to_f, v[1].to_f, v[2].to_f]
        end
        out
      end

      def _is_finite_point?(p)
        return false unless p.is_a?(Array)
        return false unless p.length == 3
        p.all? do |coord|
          coord.is_a?(Numeric) &&
            (coord.respond_to?(:finite?) ? coord.finite? : true)
        end
      end

      def _all_within_eps?(zs, eps)
        return true if zs.length <= 1
        lo = zs.min
        hi = zs.max
        op_eps = (eps * 1.0e-9).abs + 1.0e-12
        # Use `hi <= lo + eps + op_eps` to avoid IEEE 754
        # rounding false-negatives (see sliding-window note
        # in the analyze method).
        hi <= lo + eps + op_eps
      end

      # Deterministic median. For odd count -> middle value
      # (stable: even-index sort tie-break by input order
      # since the caller pre-sorts). For even count -> mean
      # of the two middle values.
      def _median(sorted_array)
        n = sorted_array.length
        if n.odd?
          sorted_array[n / 2]
        else
          (sorted_array[(n / 2) - 1] + sorted_array[n / 2]) / 2.0
        end
      end

      def _safe_len(coll)
        return 0 if coll.nil?
        coll.respond_to?(:length) ? coll.length : 0
      end

      def _make_result(state:, target_z:, eligible_count:, already_planar:,
                       movable_count:, outlier_count:,
                       proposed_moves:, outliers:, max_movement:,
                       reason:, tolerance_used:)
        {
          state:           state,
          target_z:        target_z,
          eligible_count:  eligible_count,
          already_planar:  already_planar,
          movable_count:   movable_count,
          outlier_count:   outlier_count,
          proposed_moves:  proposed_moves.freeze,
          outliers:        outliers.freeze,
          max_movement:    max_movement.to_f,
          reason:          reason,
          tolerance_used:  tolerance_used.is_a?(Numeric) ? tolerance_used.to_f : nil
        }.freeze
      end

      def _fail_result(state:, reason:, tolerance_used:,
                       eligible_count:, proposed_moves:, outliers:)
        {
          state:           state,
          target_z:        nil,
          eligible_count:  eligible_count,
          already_planar:  0,
          movable_count:   0,
          outlier_count:   outliers.length,
          proposed_moves:  proposed_moves.freeze,
          outliers:        outliers.freeze,
          max_movement:    0.0,
          reason:          reason,
          tolerance_used:  tolerance_used.is_a?(Numeric) ? tolerance_used.to_f : nil
        }.freeze
      end
    end
  end
end
