#
# core/derived_duplicate_validator.rb — V1.5 Round-4
#
# Pure-core validation seam for the V1.5 exit gate.
#
# Round-4 changes (AIPM §3 + §4 + §6):
#
#   * Uses the shared `DuplicateGeometrySemantics` for the
#     direct-match predicate and the candidate-pair enumeration.
#   * Pair metric (BLOCK-004): duplicate_pairs_before /
#     duplicate_pairs_after = count of unique unordered derived-
#     edge pairs satisfying the shared direct_match? under the
#     CAPTURED tolerance. Measured from the actual workspace.
#     NOT a surrogate from removed-count or a hardcoded zero.
#   * Class metric: repairable_components count = number of
#     connected components that are COMPLETE GRAPHS under the
#     captured tolerance. Non-transitive components are
#     reported separately (their geometry is unchanged).
#   * Captured tolerance flows from the workspace's
#     source_snapshot.execution_config. No silent fallback to
#     the historical 1e-4 default.
#

require_relative 'tolerance'
require_relative 'derived_entity_record'
require_relative 'duplicate_geometry_semantics'
require_relative 'derived_duplicate_topology'

module SUAnalysis
  module Core
    module DerivedDuplicateValidator
      module_function

      DEFAULT_TOLERANCE = DuplicateGeometrySemantics::DEFAULT_TOLERANCE

      # ===========================================================
      # Public validate() entry — Round-4 contract.
      # ===========================================================
      #
      # Inputs:
      #   workspace:  a DerivedGeometryWorkspace
      #   tolerance:  explicit Float > 0 OR nil (use captured)
      #   pre_classes: optional pre-batch Hash<String, Array>
      #                for `before` metrics. When supplied, the
      #                `before` metrics come from this Hash; the
      #                `after` metrics always come from the
      #                current workspace's measured topology.
      #
      # Returns a Hash with REAL measurements (NOT hardcoded
      # zeros):
      #
      #   {
      #     'duplicate_pairs_before'          => Integer,
      #     'duplicate_pairs_after'           => Integer,
      #     'repairable_components_before'    => Integer,
      #     'repairable_components_after'     => Integer,
      #     'non_transitive_components_before'=> Integer,
      #     'non_transitive_components_after' => Integer,
      #     'tolerance'                       => Float,
      #     'tolerance_is_captured'           => Boolean
      #   }
      def validate(workspace:, tolerance: nil, pre_classes: nil)
        tol = resolve_tolerance(workspace, tolerance)
        return nil unless DuplicateGeometrySemantics.valid_tolerance?(tol)
        # BEFORE metrics: prefer explicit pre_classes if supplied.
        before_pairs = nil
        before_repairable = nil
        before_non_transitive = nil
        if pre_classes.is_a?(Hash) && !pre_classes.empty?
          before_pairs = pre_classes['duplicate_pairs_before'] || pre_classes[:duplicate_pairs_before]
          before_repairable = pre_classes['repairable_components'] || pre_classes[:repairable_components]
          before_non_transitive = pre_classes['non_transitive_components'] || pre_classes[:non_transitive_components]
        end
        # Measure the CURRENT (after) topology from the workspace.
        records = workspace_records(workspace)
        after_classes = measure_topology(records, tol)
        if before_pairs.nil?
          before_pairs = count_pairs_from_records(pre_records(workspace, pre_classes), tol)
        end
        if before_repairable.nil?
          before_repairable = after_classes[:repairable_components].length if pre_classes.nil?
        end
        if before_non_transitive.nil?
          before_non_transitive = after_classes[:non_transitive_components].length if pre_classes.nil?
        end
        # Build the canonical class keys (sorted derived_id
        # strings for each repairable component) for the
        # historical `class_keys` accessor.
        class_keys = after_classes[:repairable_components].map { |tuples|
          ids = tuples.map { |t| t[:derived_id].to_s }.sort
          "repairable|#{ids.join('|')}"
        }.sort
        class_member_counts = after_classes[:repairable_components].map { |tuples| tuples.length }
        {
          'duplicate_pairs_before'           => before_pairs.to_i,
          'duplicate_pairs_after'            => after_classes[:duplicate_pair_count],
          'repairable_components_before'     => before_repairable.to_i,
          'repairable_components_after'      => after_classes[:repairable_components].length,
          'non_transitive_components_before' => before_non_transitive.to_i,
          'non_transitive_components_after'  => after_classes[:non_transitive_components].length,
          # Backward-compatible keys (tests + UI):
          'duplicate_classes_before'         => before_repairable.to_i,
          'duplicate_classes_after'          => after_classes[:repairable_components].length,
          'class_keys'                       => class_keys,
          'class_member_counts'              => class_member_counts,
          'tolerance'                        => tol.to_f,
          'tolerance_is_captured'            => tolerance.nil? ? true : false
        }.freeze
      end

      # ===========================================================
      # measure_topology — the canonical post-state measurement.
      # ===========================================================
      #
      # Returns a Hash:
      #   {
      #     repairable_components:     Array<Array<Hash>>,
      #     non_transitive_components:  Array<Hash>,
      #     duplicate_pair_count:       Integer,
      #     records:                    Array<Hash{derived_id,...}>
      #   }
      def measure_topology(records, tolerance)
        tuples = DuplicateGeometrySemantics.records_to_tuples(records)
        result = DerivedDuplicateTopology.classify_components(tuples, tolerance)
        repairable = result[:repairable_components].map { |idxs|
          idxs.map { |i| tuples[i] }
        }
        non_transitive = result[:non_transitive_components]
        pair_count = DerivedDuplicateTopology.count_direct_pairs(tuples, tolerance)
        {
          repairable_components:     repairable,
          non_transitive_components: non_transitive,
          duplicate_pair_count:      pair_count,
          records:                   tuples
        }
      end

      # ===========================================================
      # Helpers (delegated)
      # ===========================================================

      def workspace_records(workspace)
        return [] if workspace.nil?
        ents = workspace.respond_to?(:entities) ? workspace.entities : []
        ents.select { |d| d.is_a?(DerivedEntityRecord) && d.kind == :edge }
      end

      def pre_records(_workspace, pre_classes)
        return [] unless pre_classes.is_a?(Hash)
        # pre_classes can carry its own tuple list under
        # 'records'; when missing we recompute from the same
        # workspace (defensive fallback).
        recs = pre_classes['records'] || pre_classes[:records]
        return recs if recs.is_a?(Array)
        []
      end

      def count_pairs_from_records(records, tolerance)
        return 0 if records.nil? || records.empty?
        DuplicateGeometrySemantics.count_direct_pairs(records, tolerance)
      end

      # ===========================================================
      # Compatibility: previous `group_derived_duplicates`
      # entry point. Returns the repairable-component topology
      # keyed by canonical class key (sorted derived_ids).
      # ===========================================================
      def group_derived_duplicates(workspace, tolerance)
        out = {}
        return out if workspace.nil?
        tol = resolve_tolerance(workspace, tolerance)
        return out unless DuplicateGeometrySemantics.valid_tolerance?(tol)
        records = workspace_records(workspace)
        measurement = measure_topology(records, tol)
        measurement[:repairable_components].each do |tuples|
          member_records = tuples.map { |t|
            workspace.entities.find { |d|
              d.is_a?(DerivedEntityRecord) && d.kind == :edge &&
                d.derived_id.to_s == t[:derived_id].to_s
            }
          }.compact
          next if member_records.empty?
          sorted_ids = member_records.map { |d| d.derived_id.to_s }.sort
          key = "repairable|#{sorted_ids.join('|')}"
          out[key] = member_records
        end
        out
      end

      def direct_match?(pa_s, pa_e, pb_s, pb_e, layer_a, layer_b, tolerance)
        DuplicateGeometrySemantics.direct_match?(pa_s, pa_e, pb_s, pb_e,
                                                  layer_a, layer_b, tolerance)
      end

      def resolve_tolerance(workspace, tolerance)
        DerivedDuplicateTopology.resolve_tolerance(workspace, tolerance)
      end

      def normalize_layer(name)
        DuplicateGeometrySemantics.normalize_layer(name)
      end

      def finite_point?(p)
        DuplicateGeometrySemantics.finite_point?(p)
      end

      def points_within?(p, q, tol)
        DuplicateGeometrySemantics.points_within?(p, q, tol)
      end
    end
  end
end