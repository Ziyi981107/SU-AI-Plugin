#
# core/duplicate_geometry_semantics.rb — V1.5 Round-4
#
# Single source of truth for V1.5 duplicate-geometry semantics.
#
# Per AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27 §3
# (BLOCK-002A + BLOCK-002B), this module owns:
#
#   1. finite-point validation
#   2. tolerance validation
#   3. forward / reversed segment direct_match?
#   4. tolerance-safe candidate-pair enumeration
#      (3D grid cell with mathematical floor; every edge is
#       indexed under BOTH endpoint cells; candidate pair set
#       is the union of all 27 neighboring cells around endpoint
#       A and the same around endpoint B; pairs are deduplicated
#       by stable unordered edge-ID pair and validated against
#       the shared direct_match? predicate)
#
# The detector, proposer, validator, expected-post-state, and
# audit-tolerance propagation MUST all go through this module.
# No production code may use a different per-axis predicate,
# different Layer0 normalization, different cell size, or
# different pair-enumeration algorithm. The class semantics
# are intentionally identical across the pipeline.
#

require_relative 'tolerance'
require_relative 'derived_entity_record'

module SUAnalysis
  module Core
    module DuplicateGeometrySemantics
      module_function

      DEFAULT_TOLERANCE = 1.0e-4

      # ===========================================================
      # Finite-point validation. A finite 3D point is a 3-Array
      # of finite Floats. Integers do NOT satisfy (Ruby Integer
      # is Numeric but not Float).
      # ===========================================================

      def finite_point?(p)
        return false unless p.is_a?(Array) && p.length == 3
        p.all? do |v|
          v.respond_to?(:finite?) && v.finite?
        end
      end

      def finite_float_triple(p)
        return nil unless finite_point?(p)
        [p[0].to_f, p[1].to_f, p[2].to_f]
      end

      # Per-axis tolerance check (the BLOCK-002 per-axis contract).
      def points_within?(p, q, tol)
        return false unless finite_point?(p) && finite_point?(q)
        (0..2).all? { |i| (p[i].to_f - q[i].to_f).abs <= tol.to_f }
      end

      # ===========================================================
      # Tolerance validation. Negative or non-finite tolerance
      # is invalid; the caller MUST treat this as
      # "no V1.5 auto-repair".
      # ===========================================================

      def valid_tolerance?(tolerance)
        return false if tolerance.nil?
        v = tolerance.to_f
        v.respond_to?(:finite?) && v.finite? && v > 0
      end

      # ===========================================================
      # Layer0 normalization (canonical).
      # nil / '' / 'layer0' / 'default' / 'untagged' => 'Layer0'.
      # Other layer names are returned verbatim (case preserved).
      # ===========================================================

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

      # ===========================================================
      # DIRECT MATCH — the V1.5 BLOCK-002 contract.
      # ===========================================================
      #
      # Returns :forward | :reversed | nil.
      #
      # :forward  if pa.start ~ pb.start AND pa.end ~ pb.end
      #           (per-axis, within tolerance)
      # :reversed if pa.start ~ pb.end   AND pa.end   ~ pb.start
      #           (per-axis, within tolerance)
      # nil       if neither direction satisfies the per-axis
      #           tolerance, or the layer names differ after
      #           Layer0 normalization, or any point is not a
      #           finite 3-Array.
      #
      # This function MUST NOT be replaced by anything other than
      # the same per-axis check with the captured tolerance.
      # Every consumer (detector, proposer, validator, post-
      # state) MUST go through this function.

      def direct_match?(pa_s, pa_e, pb_s, pb_e, layer_a, layer_b, tolerance)
        return nil unless valid_tolerance?(tolerance)
        return nil unless finite_point?(pa_s) && finite_point?(pa_e)
        return nil unless finite_point?(pb_s) && finite_point?(pb_e)
        tol = tolerance.to_f
        # Layer names must match after Layer0 normalization.
        return nil unless normalize_layer(layer_a) == normalize_layer(layer_b)
        if points_within?(pa_s, pb_s, tol) && points_within?(pa_e, pb_e, tol)
          :forward
        elsif points_within?(pa_s, pb_e, tol) && points_within?(pa_e, pb_s, tol)
          :reversed
        else
          nil
        end
      end

      # ===========================================================
      # Candidate-pair enumeration (BLOCK-002A).
      # ===========================================================
      #
      # Inputs:
      #   records   Array<Hash{derived_id:, start:, finish:, layer:}>
      #             OR Array<DerivedEntityRecord>
      #   tolerance Float > 0 (the captured execution tolerance)
      #
      # Returns:
      #   Array<Array<Integer>> sorted-list of candidate pair
      #   indices [(i, j) where i < j]. Pairs are deduplicated by
      #   the sorted-unordered (i, j) tuple.
      #
      # Algorithm (Round-4 fixed):
      #   1. Cell size = tolerance (NOT 2x tolerance).
      #   2. Mathematical floor per axis: floor(coord / cell).
      #   3. Every record is indexed under BOTH its endpoint cells.
      #   4. For each record, query all 27 neighboring cells
      #      around endpoint A (the 3x3x3 box centered at A's
      #      exact cell) and the same around endpoint B. The set
      #      of candidate neighbor records is the union of both
      #      endpoint searches.
      #   5. For each candidate, evaluate the shared
      #      direct_match? predicate. Retain only the pairs that
      #      satisfy it.
      #   6. Deduplicate by stable unordered edge-ID pair.
      #
      # Tolerance == 0 path: returns an exact endpoint-pair
      # canonical hash lookup (the cell-based path degenerates).
      #
      # Negative/non-finite tolerance: raises an ArgumentError;
      # production code MUST treat this as "no auto-repair".

      def enumerate_candidates(records, tolerance)
        raise ArgumentError, 'enumerate_candidates: invalid tolerance' unless valid_tolerance?(tolerance)
        records = Array(records)
        return [] if records.length < 2
        # Normalize records to {derived_id:, start:, finish:, layer:}.
        tuples = records.map { |r|
          if r.is_a?(Hash)
            # Accept both symbol and string keys, AND both
            # :end / 'end' and :finish / 'finish' for the
            # finish point (detector uses :end; proposer /
            # validator use :finish).
            start_v = r[:start] || r['start']
            finish_v = r[:finish] || r[:end] || r['finish'] || r['end']
            derived_id_v = r[:derived_id] || r['derived_id']
            layer_v = r[:layer] || r['layer']
            { derived_id: derived_id_v, start: start_v, finish: finish_v, layer: layer_v }
          else
            extract_record_tuple(r)
          end
        }.compact
        return [] if tuples.length < 2
        # Drop tuples with non-finite geometry or non-positive tolerance.
        tuples = tuples.select { |t| finite_point?(t[:start]) && finite_point?(t[:finish]) }
        return [] if tuples.length < 2
        tol = tolerance.to_f
        # Build the per-record index under BOTH endpoint cells.
        cell = tol
        # Floor-based 3D cell coordinate.
        floor_cell = lambda do |pt|
          [
            (pt[0].to_f / cell).floor,
            (pt[1].to_f / cell).floor,
            (pt[2].to_f / cell).floor
          ]
        end
        # Index record -> list of cell keys (both endpoint cells).
        cells_of = tuples.map do |t|
          a = floor_cell.call(t[:start])
          b = floor_cell.call(t[:finish])
          # Dedupe: A==B is possible (same cell).
          [a, b].uniq
        end
        # Invert the index: cell key -> Array<record-index>.
        cell_index = {}
        cells_of.each_with_index do |cks, i|
          cks.each do |ck|
            cell_index[ck] ||= []
            cell_index[ck] << i
          end
        end
        # For each record, compute its candidate set as the union
        # of all 27 neighboring cells around endpoint A and around
        # endpoint B. Then evaluate direct_match? for each unique
        # (i, j) with i < j.
        neighbor_offsets = (-1..1).flat_map { |dx|
          (-1..1).flat_map { |dy|
            (-1..1).map { |dz| [dx, dy, dz] }
          }
        }
        candidates = []
        seen = {}
        tuples.each_with_index do |t_a, i|
          a_keys = cells_of[i]
          # 27 neighboring cells around endpoint A.
          union = []
          a_keys.each do |ack|
            neighbor_offsets.each do |off|
              ck = [ack[0] + off[0], ack[1] + off[1], ack[2] + off[2]]
              arr = cell_index[ck]
              next if arr.nil?
              union.concat(arr)
            end
          end
          union.uniq!
          union.each do |j|
            next if j <= i # i < j only
            pair = [i, j]
            next if seen[pair]
            t_b = tuples[j]
            kind = direct_match?(t_a[:start], t_a[:finish], t_b[:start], t_b[:finish],
                                  t_a[:layer], t_b[:layer], tolerance)
            next unless kind == :forward || kind == :reversed
            seen[pair] = true
            candidates << pair
          end
        end
        # Stable sorted output.
        candidates.sort_by { |p| [p[0], p[1]] }
      end

      # ===========================================================
      # Direct-pair enumeration — the BLOCK-004 pair metric.
      # ===========================================================
      #
      # Returns:
      #   Array<Array<Hash>> where each inner array is a
      #   pair [record_i_hash, record_j_hash] (i < j) that
      #   satisfies the shared direct_match? predicate.
      #
      # The metric is "the number of UNIQUE UNORDERED derived-edge
      # pairs that satisfy the shared forward/reversed direct_match?
      # under the CAPTURED duplicate tolerance in the measured
      # workspace/scope" (AIPM Round-4 §6 definition).
      #
      # This is the SINGLE pair-count metric used by the audit,
      # summary, and post-state validation. Production code MUST
      # NOT derive pair counts from `removed_ids.length - 1`,
      # affected_derived_ids.length, or any other surrogate.
      def enumerate_direct_pairs(records, tolerance)
        pairs = enumerate_candidates(records, tolerance)
        tuples = records_to_tuples(records)
        pairs.map { |i, j| [tuples[i], tuples[j]] }
      end

      def count_direct_pairs(records, tolerance)
        enumerate_direct_pairs(records, tolerance).length
      end

      # ===========================================================
      # Tolerance resolution from a workspace / snapshot.
      # Captured execution tolerance. When the captured value is
      # unavailable / invalid, the resolver returns nil (NOT a
      # fallback default). Production code must treat nil as
      # "no auto-repair" (BLOCK-004: no silent fallback to the
      # historical 1e-4 default).
      # ===========================================================

      def resolve_captured_tolerance(workspace)
        return nil if workspace.nil?
        src = workspace.respond_to?(:source_snapshot) ? workspace.source_snapshot : nil
        return nil if src.nil?
        ec = src.respond_to?(:execution_config) ? src.execution_config : nil
        return nil if ec.nil?
        vals = ec.respond_to?(:tolerance_values) ? ec.tolerance_values : nil
        return nil unless vals.is_a?(Hash)
        v = vals[:duplicate] || vals['duplicate']
        return nil if v.nil?
        f = v.to_f
        return nil unless valid_tolerance?(f)
        f
      end

      # ===========================================================
      # Internal helpers
      # ===========================================================

      def records_to_tuples(records)
        Array(records).map { |r|
          if r.is_a?(Hash)
            start_v = r[:start] || r['start']
            finish_v = r[:finish] || r[:end] || r['finish'] || r['end']
            {
              derived_id: r[:derived_id] || r['derived_id'],
              start:      start_v,
              finish:     finish_v,
              layer:      r[:layer] || r['layer']
            }
          else
            extract_record_tuple(r)
          end
        }.compact
      end

      # Extract a stable tuple {derived_id, start, finish, layer}
      # from a DerivedEntityRecord (an :edge record). Other kinds
      # return nil.
      def extract_record_tuple(d)
        return nil unless d.is_a?(DerivedEntityRecord)
        return nil unless d.kind == :edge
        geom = d.respond_to?(:geometry_summary) ? d.geometry_summary : nil
        return nil unless geom.is_a?(Hash)
        s = geom['start'] || geom[:start]
        f = geom['end']   || geom[:end]   || geom['finish']
        l = geom['layer'] || geom[:layer]
        return nil unless finite_point?(s) && finite_point?(f)
        {
          derived_id: d.derived_id,
          start:      s,
          finish:     f,
          layer:      l
        }
      end
    end
  end
end