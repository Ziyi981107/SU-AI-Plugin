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
require_relative 'derived_duplicate_topology'

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
      # SAME matcher the proposer uses) and the SAME maximal-
      # clique partition the proposer uses (BLOCK-002 V1.5
      # round 3: proposer and validator must share both direct
      # predicate and class semantics).
      #
      # Returns a Hash<String, Array<DerivedEntityRecord>> keyed
      # by canonical "clique|" + sorted-derived-ids digest so
      # the audit can identify each distinct class. Only proper
      # cliques (>= 2 members) are reported.
      def group_derived_duplicates(workspace, tolerance)
        out = {}
        return out if workspace.nil?
        tol = tolerance || DEFAULT_TOLERANCE
        entities = workspace.respond_to?(:entities) ? workspace.entities : []
        return out if entities.empty?
        # Build the list of edge record tuples.
        records = entities.map { |d| DerivedDuplicateTopology.extract_record_tuple(d) }.compact
        return out if records.empty?
        # Use the SHARED topology helper (the SAME Bron-Kerbosch
        # clique partition the proposer uses). This is the V1.5
        # round-3 BLOCK-002 fix: validator and proposer MUST share
        # class semantics.
        cliques = DerivedDuplicateTopology.clique_classes(records, tol)
        cliques.each do |clique|
          member_records = clique.map { |t| t[:record] }
          sorted_ids = member_records.map { |d| d.derived_id.to_s }.sort
          # Canonical class key: derived from the SORTED
          # derived_ids (deterministic across rebuilds of the
          # same workspace).
          key = "clique|#{sorted_ids.join('|')}"
          out[key] = member_records
        end
        out
      end

      # ===========================================================
      # Direct endpoint matcher (the V1.5 BLOCK-002 contract).
      # Delegates to the SHARED topology helper so the proposer
      # and validator use the SAME predicate (BLOCK-002 round-3
      # class semantics).
      # ===========================================================

      def direct_match?(pa_s, pa_e, pb_s, pb_e, layer_a, layer_b, tolerance)
        DerivedDuplicateTopology.direct_match?(pa_s, pa_e, pb_s, pb_e,
                                                layer_a, layer_b, tolerance)
      end

      # ===========================================================
      # Resolve the captured tolerance from the workspace's
      # source_snapshot.execution_config (BLOCK-004: the
      # validator must use the captured tolerance, not the
      # default). Delegates to the shared helper.
      # ===========================================================

      def resolve_tolerance(workspace, tolerance)
        DerivedDuplicateTopology.resolve_tolerance(workspace, tolerance)
      end

      # ===========================================================
      # Layer0 normalization (delegated to shared helper).
      # ===========================================================

      def normalize_layer(name)
        DerivedDuplicateTopology.normalize_layer(name)
      end

      # ===========================================================
      # Numeric helpers (delegated to shared helper).
      # ===========================================================

      def finite_point?(p)
        DerivedDuplicateTopology.finite_point?(p)
      end

      def points_within?(p, q, tol)
        DerivedDuplicateTopology.points_within?(p, q, tol)
      end
    end
  end
end
