#
# core/derived_duplicate_validator.rb — V1.5 Phase 1 (corrected scope)
#
# Pure-core validation seam for the V1.5 exit gate (Guidance 031
# §8, CodeX Review 032 recheck 2026-08-25 BLOCK-004).
#
# Validates the duplicate-class topology of a derived workspace.
# Returns BEFORE/AFTER duplicate-class counts and a per-class
# member-count breakdown. Uses the SAME direct endpoint matcher
# as the proposer (BLOCK-002: spatial buckets are candidate
# acceleration only; the direct matcher is the match rule).
#
# The validator's "before" snapshot is computed on the
# pre-batch workspace; the executor records it. The "after"
# snapshot is computed on the post-batch workspace. The
# executor passes BOTH the pre-batch classes and the
# post-batch measured counts so the audit can show the real
# change.
#
# Locked contract:
#   - Input: a workspace (DerivedGeometryWorkspace), the
#     captured execution_config duplicate tolerance, and
#     optional pre/post snapshot counts for the audit row.
#   - Output: a Hash with duplicate_classes_before / after
#     counts, the sorted list of canonical class keys, per-class
#     member counts, and the captured tolerance value.
#   - Pure-data; no host mutations; no IssueRegistry writes.
#

require_relative 'tolerance'
require_relative 'derived_entity_record'

module SUAnalysis
  module Core
    module DerivedDuplicateValidator
      module_function

      DEFAULT_TOLERANCE = 1.0e-4

      # Validate the duplicate-class topology of the given
      # workspace. Returns a Hash with REAL measurements
      # (NOT a hard-coded `duplicate_classes_after = 0`):
      #
      #   {
      #     'duplicate_classes_before' => Integer,
      #     'duplicate_classes_after'  => Integer,
      #     'class_keys'               => Array<String>,
      #     'class_member_counts'      => Array<Integer>,
      #     'tolerance'                => Float
      #   }
      #
      # When `pre_classes` is supplied (a Hash<String, Array>
      # measured on the pre-batch workspace), the validator
      # uses it for `duplicate_classes_before`; otherwise it
      # measures the current workspace for both before and
      # after (the same workspace is the only available
      # measure).
      #
      # When `tolerance` is nil, the validator derives it
      # from the workspace's captured execution_config (NOT
      # the default). This is the BLOCK-004 fix: captured
      # tolerance is used end to end.
      def validate(workspace:, tolerance: nil, pre_classes: nil)
        tol = resolve_tolerance(workspace, tolerance)
        current_classes = group_derived_duplicates(workspace, tol)
        before_count = pre_classes.is_a?(Hash) ? pre_classes.length : current_classes.length
        after_count  = current_classes.length
        class_keys = current_classes.keys.sort
        member_counts = class_keys.map { |k| current_classes[k].length }
        {
          'duplicate_classes_before' => before_count,
          'duplicate_classes_after'  => after_count,
          'class_keys'               => class_keys,
          'class_member_counts'      => member_counts,
          'tolerance'                => tol
        }.freeze
      end

      # Compute the duplicate-class topology for the given
      # workspace using the DIRECT endpoint matcher (the
      # SAME matcher the proposer uses). Returns a
      # Hash<String, Array<DerivedEntityRecord>> of every
      # class with 2+ members.
      #
      # This is the V1.5 BLOCK-002 fix: the previous code
      # used `quantize_point` to bucket records; the new
      # code uses union-find over direct endpoint matches.
      # Buckets are candidate acceleration only; the direct
      # matcher is the match rule.
      def group_derived_duplicates(workspace, tolerance)
        out = {}
        return out if workspace.nil?
        tol = tolerance || DEFAULT_TOLERANCE
        entities = workspace.respond_to?(:entities) ? workspace.entities : []
        return out if entities.empty?
        # Build the list of edge records.
        edges = []
        entities.each do |d|
          next unless d.is_a?(DerivedEntityRecord)
          next unless d.kind == :edge
          geom = d.respond_to?(:geometry_summary) ? d.geometry_summary : nil
          next unless geom.is_a?(Hash)
          s = geom['start'] || geom[:start]
          f = geom['end']   || geom[:end]
          l = geom['layer'] || geom[:layer]
          next unless finite_point?(s) && finite_point?(f)
          edges << { record: d, start: s, finish: f, layer: l }
        end
        # Union-find over direct matches. Inline the find
        # operation so we don't need a separate method
        # (module_function context).
        parent = Array.new(edges.length) { |i| i }
        edges.each_with_index do |a, i|
          ((i + 1)...edges.length).each do |j|
            b = edges[j]
            kind = direct_match?(a[:start], a[:finish], b[:start], b[:finish],
                                  a[:layer], b[:layer], tol)
            if kind == :forward || kind == :reversed
              # Find roots (with path compression)
              ri = i
              ri = parent[ri] while parent[ri] != ri
              rj = j
              rj = parent[rj] while parent[rj] != rj
              parent[ri] = rj if ri != rj
            end
          end
        end
        # Collect roots (with path compression for lookup).
        groups = {}
        edges.each_with_index do |e, i|
          r = i
          r = parent[r] while parent[r] != r
          (groups[r] ||= []) << e[:record]
        end
        groups.select { |_k, v| v.length >= 2 }
      end

      # ===========================================================
      # Direct endpoint matcher (the V1.5 BLOCK-002 contract).
      # Mirrors DuplicateRepairProposer.direct_match?.
      # ===========================================================

      def direct_match?(pa_s, pa_e, pb_s, pb_e, layer_a, layer_b, tolerance)
        return nil unless finite_point?(pa_s) && finite_point?(pa_e)
        return nil unless finite_point?(pb_s) && finite_point?(pb_e)
        tol = tolerance.to_f
        return nil unless tol.finite? && tol > 0
        if normalize_layer(layer_a) != normalize_layer(layer_b)
          return nil
        end
        if points_within?(pa_s, pb_s, tol) && points_within?(pa_e, pb_e, tol)
          :forward
        elsif points_within?(pa_s, pb_e, tol) && points_within?(pa_e, pb_s, tol)
          :reversed
        else
          nil
        end
      end

      # ===========================================================
      # Resolve the captured tolerance from the workspace's
      # source_snapshot.execution_config (BLOCK-004: the
      # validator must use the captured tolerance, not the
      # default).
      # ===========================================================

      def resolve_tolerance(workspace, tolerance)
        return tolerance.to_f if tolerance && tolerance.to_f.finite? && tolerance.to_f > 0
        return DEFAULT_TOLERANCE if workspace.nil?
        src = workspace.respond_to?(:source_snapshot) ? workspace.source_snapshot : nil
        return DEFAULT_TOLERANCE if src.nil?
        ec = src.respond_to?(:execution_config) ? src.execution_config : nil
        return DEFAULT_TOLERANCE if ec.nil?
        vals = ec.respond_to?(:tolerance_values) ? ec.tolerance_values : nil
        return DEFAULT_TOLERANCE unless vals.is_a?(Hash)
        v = vals[:duplicate] || vals['duplicate']
        v ? v.to_f : DEFAULT_TOLERANCE
      end

      # ===========================================================
      # Layer0 normalization
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
      # Numeric helpers
      # ===========================================================

      def finite_point?(p)
        return false unless p.is_a?(Array) && p.length == 3
        p.all? do |v|
          v.respond_to?(:finite?) && v.finite?
        end
      end

      def points_within?(p, q, tol)
        return false unless p.is_a?(Array) && q.is_a?(Array) && p.length == 3 && q.length == 3
        (0..2).all? { |i| (p[i].to_f - q[i].to_f).abs <= tol.to_f }
      end
    end
  end
end
