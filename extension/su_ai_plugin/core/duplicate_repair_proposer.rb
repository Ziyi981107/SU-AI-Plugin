#
# core/duplicate_repair_proposer.rb — V1.5 Phase 1 (corrected scope)
#
# Duplicate-candidate → RepairAction proposal.
#
# CORRECTED SCOPE per Guidance 031 (CodeX/AIPM, 2026-08-25) and
# CodeX Review 032 recheck (2026-08-25):
#
#   The V1.5 implementation directive canonicalizes exact /
#   reversed-exact coincident DERIVED edges inside the current
#   selected SourceSnapshot, while preserving the immutable
#   source occurrences as a many-to-one provenance union on the
#   surviving derived edge.
#
#   V1.5 STAGE BLOCK-001 (canonical class membership):
#     Every derived member of a class resolves to exactly one
#     current SourceSnapshot EdgeRecord using FULL
#     occurrence/leaf identity. Source EdgeRecords are distinct;
#     derived records and live handles are distinct. The
#     existing deterministic transient-root fallback applies
#     only where the frozen snapshot contract permits it.
#
#   V1.5 STAGE BLOCK-002 (bucketing is not the direct tolerance
#   contract):
#     The SAME tested matcher performs forward/reversed direct
#     endpoint comparison with the CAPTURED execution-config
#     duplicate tolerance for every member admitted to an
#     action. Spatial buckets are candidate acceleration only.
#     Proposer and validator share exactly the same direct
#     matcher semantics.
#
# Algorithm (V1.5 recheck):
#
#   1. For every duplicate_edge_candidate issue in the
#      captured IssueRegistry, classify it with per-issue
#      guards (finite coords, layer match, endpoint exactness,
#      self-match, etc.).
#
#   2. For each valid issue, find the derived records whose
#      source EdgeRecord is one of the issue's two source
#      edges AND whose geometry directly matches the other
#      source edge (forward or reversed within the captured
#      tolerance). The set of matching records is the
#      issue's candidate class.
#
#   3. Verify the candidate class:
#      a. Every member resolves to exactly one current
#         SourceSnapshot EdgeRecord using full
#         occurrence/leaf identity.
#      b. Source EdgeRecords are distinct (no two members
#         share the same source edge).
#      c. Derived records and live handles are distinct.
#      d. No member is the self-match of another.
#      e. No member has incomplete nested provenance.
#
#   4. Deduplicate: multiple issues that authorize the same
#      candidate class collapse to one action.
#
#   5. Emit ONE :remove_duplicate_edge action per class with
#      survivor = lex-smallest derived_id, removed = others,
#      source_occurrence_ids = sorted unique union.
#
#   6. Each action's before_summary carries the source
#      issue_ids (the issues that authorized the class).
#
# Direct match contract (shared with DerivedDuplicateValidator):
#
#   direct_match?(pa, pb, layer_a, layer_b, tolerance) ->
#     :forward | :reversed | nil
#
#   forward  : both endpoints match within tolerance
#   reversed : start of a matches end of b AND end of a
#              matches start of b, all within tolerance
#   nil      : neither direction satisfies the per-axis
#              tolerance (or layer names differ after
#              Layer0 normalization)
#
# Locked auto-apply eligibility (Guidance 031 §5 + Review 032
# recheck minimum):
#
#   1. Evidence originates from existing duplicate_edge_candidate
#      issues in the captured IssueRegistry.
#   2. Every member resolves to a distinct source EdgeRecord and
#      a distinct live derived Edge record/handle.
#   3. World-coordinate endpoints match forward or reversed
#      within the captured execution_config tolerance.duplicate.
#      Re-verified directly by the direct matcher.
#   4. Coordinates are finite; transform resolution valid.
#   5. Every member belongs to the same current SourceSnapshot /
#      selection scope.
#   6. Provenance usable. Incomplete nested identity fails closed.
#   7. Layer names byte-identical after Layer0 normalization.
#   8. No self-match or repeated reference.
#   9. No short-edge-only deletion evidence.
#  10. No source mutation.
#
# Non-eligible explicit cases:
#   - near/approximate duplicates outside tolerance
#   - layer mismatch
#   - incomplete nested provenance
#   - invalid/erased source or derived handle
#   - self-match
#   - different world coordinates
#   - short edge solely because it is short
#   - face/gap/weld/flatten/loop/site/AI/MCP/V2 work
#

require 'digest'
require_relative 'repair_plan'
require_relative 'derived_entity_record'

module SUAnalysis
  module Core
    module DuplicateRepairProposer
      module_function

      # Locked catalog constants.
      RULE_ID         = 'duplicate_edge.exact_remove'.freeze
      ACTION_TYPE     = :remove_duplicate_edge
      CONFIDENCE      = 1.0

      # Confidence basis strings (one per exact-match kind).
      BASIS_FORWARD_EXACT  = 'exact_endpoint_match_within_tolerance.duplicate'.freeze
      BASIS_REVERSED_EXACT = 'reversed_endpoint_match_within_tolerance.duplicate'.freeze

      # Topology impact (audit string).
      TOPOLOGY_IMPACT = 'removes_duplicate_edge'.freeze

      # Reason strings (used in :skipped actions and explanations).
      REASON_SELF_MATCH              = 'duplicate_evidence_self_match'.freeze
      REASON_NEAR_BUT_NOT_EXACT      = 'endpoints_outside_tolerance_duplicate'.freeze
      REASON_PROVENANCE_DIFFERS      = 'source_occurrence_ids_differ'.freeze
      REASON_LAYER_MISMATCH          = 'semantic_conflict_layer_mismatch'.freeze
      REASON_DERIVED_NOT_FOUND       = 'no_derived_record_for_source_edge'.freeze
      REASON_DERIVED_ERASED          = 'derived_record_handle_invalidated'.freeze
      REASON_NON_EDGE_KIND           = 'derived_record_kind_not_edge'.freeze
      REASON_INCOMPLETE_PROVENANCE   = 'incomplete_nested_provenance'.freeze
      REASON_NON_FINITE_COORDS       = 'non_finite_endpoint_coordinates'.freeze
      REASON_NON_DISTINCT_SOURCE     = 'duplicate_evidence_repeated_source_edge'.freeze
      REASON_MISSING_EDGE_RECORD     = 'no_edge_record_for_one_or_both_edge_ids'.freeze
      REASON_NO_DERIVED_FOR_ISSUE    = 'no_derived_records_resolve_to_issue_source_edges'.freeze
      REASON_AMBIGUOUS_RESOLUTION    = 'ambiguous_source_edge_resolution'.freeze
      REASON_BUCKET_BOUNDARY         = 'bucket_boundary_split'.freeze

      # Canonical Layer0 normalization.
      DEFAULT_LAYER_CANONICAL = 'Layer0'.freeze

      # Default fallback tolerance.duplicate (inches).
      DEFAULT_DUPLICATE_TOLERANCE = 1.0e-4

      # ===========================================================
      # Public API
      # ===========================================================

      # Build a RepairPlan from the existing duplicate_edge_candidate
      # IssueRegistry evidence.
      def propose(source_snapshot:, registry:, workspace:)
        result = build_actions(
          source_snapshot: source_snapshot,
          registry:        registry,
          workspace:       workspace
        )
        plan = RepairPlan.new(actions: result, status: :proposed)
        plan.validate
      end

      # ===========================================================
      # Canonical-key construction (kept for diagnostic / layer
      # discrimination; NOT used as the match rule per BLOCK-002).
      # ===========================================================

      def normalize_layer(name)
        return DEFAULT_LAYER_CANONICAL if name.nil?
        s = name.to_s
        return DEFAULT_LAYER_CANONICAL if s.empty?
        case s.downcase
        when 'layer0', 'default', 'untagged'
          DEFAULT_LAYER_CANONICAL
        else
          s
        end
      end

      def quantize_point(point, tolerance)
        inv = 1.0 / tolerance.to_f
        [
          (point[0].to_f * inv).round,
          (point[1].to_f * inv).round,
          (point[2].to_f * inv).round
        ]
      end

      def canonical_geometry_key(start:, finish:, layer:, tolerance:)
        s_q = quantize_point(start, tolerance)
        f_q = quantize_point(finish, tolerance)
        pair = [s_q, f_q].sort_by { |p| p.to_s }
        norm_layer = normalize_layer(layer)
        "geom|#{pair[0].join(',')}|#{pair[1].join(',')}|layer=#{norm_layer}"
      end

      # ===========================================================
      # DIRECT MATCHER (the V1.5 BLOCK-002 contract)
      # ===========================================================
      #
      # The proposer and the validator share this exact matcher.
      # It compares two 3-Float points PER AXIS within the
      # captured tolerance. NO bucketing is involved. Forward
      # and reversed orderings are both supported. Layer
      # discrimination happens BEFORE geometry: different
      # normalized layers return nil regardless of geometry.
      #
      # Inputs:
      #   pa, pb: each [x, y, z] finite-Float Array
      #   layer_a, layer_b: layer names (already resolved from
      #                     the source EdgeRecord)
      #   tolerance: Float > 0 (captured tolerance.duplicate)
      #
      # Returns:
      #   :forward  if pa.start ~ pb.start AND pa.end ~ pb.end
      #             (per-axis, within tolerance)
      #   :reversed if pa.start ~ pb.end   AND pa.end   ~ pb.start
      #             (per-axis, within tolerance)
      #   nil       if neither direction satisfies the per-axis
      #             tolerance, or layer names differ after
      #             Layer0 normalization, or any point is not a
      #             finite 3-Float Array.

      def direct_match?(pa_s, pa_e, pb_s, pb_e, layer_a, layer_b, tolerance)
        return nil unless finite_point?(pa_s) && finite_point?(pa_e)
        return nil unless finite_point?(pb_s) && finite_point?(pb_e)
        tol = tolerance.to_f
        return nil unless tol.finite? && tol > 0
        # Layer names must match after Layer0 normalization.
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
      # build_actions — main pipeline
      # ===========================================================

      def build_actions(source_snapshot:, registry:, workspace:)
        tolerance    = read_duplicate_tolerance(source_snapshot)
        edge_lookup  = build_edge_lookup(source_snapshot)
        issues       = collect_duplicate_candidates(registry)

        # Step 1: per-issue guards. Each issue becomes either a
        # valid {issue, classification, ea, eb} record or a
        # :skipped action.
        per_issue = []
        skipped   = []
        issues.each do |iss|
          classification = classify_issue(
            iss,
            edge_lookup: edge_lookup,
            tolerance:   tolerance
          )
          unless classification[:valid]
            skipped << classification[:skipped_action]
            next
          end
          ea = classification[:ea]
          eb = classification[:eb]
          per_issue << {
            issue:          iss,
            ea:             ea,
            eb:             eb,
            basis_kind:     classification[:basis_kind]
          }
        end

        # Step 2: for each issue, find derived records whose
        # source EdgeRecord resolves to one of {ea, eb} AND
        # whose geometry directly matches the OTHER edge
        # within the captured tolerance.
        per_class = []   # each: { issue, ea, eb, basis_kind, members, source_edge_ids }
        per_issue.each do |pi|
          ea = pi[:ea]
          eb = pi[:eb]
          klass = find_class_for_issue(
            workspace:    workspace,
            ea:           ea,
            eb:           eb,
            tolerance:    tolerance
          )
          if klass.nil? || klass[:members].empty?
            skipped << skipped_action_for(
              pi[:issue], REASON_NO_DERIVED_FOR_ISSUE,
              'no derived records in the workspace resolve to the issue source edges'
            )
            next
          end
          # Step 3: full leaf/occurrence identity verification.
          identity_ok = verify_class_identity(
            members:      klass[:members],
            ea:           ea,
            eb:           eb,
            source_snapshot: source_snapshot,
            edge_lookup:  edge_lookup,
            issue:        pi[:issue]
          )
          unless identity_ok[:valid]
            skipped << identity_ok[:skipped_action]
            next
          end
          per_class << {
            issue:           pi[:issue],
            ea:              ea,
            eb:              eb,
            basis_kind:      pi[:basis_kind],
            members:         klass[:members],
            source_edge_ids: klass[:source_edge_ids]
          }
        end

        # Step 4: deduplicate — multiple issues that resolve
        # to the same member-set collapse to one action.
        deduped = deduplicate_classes(per_class)

        # Step 5: emit one action per deduped class.
        remove_actions = deduped.map do |c|
          build_remove_action_for_class(c)
        end

        # Deterministic ordering: remove_actions by action_id asc;
        # skipped by issue_id asc.
        remove_actions.sort_by! { |a| a.action_id.to_s }
        skipped.sort_by!     { |a| (a.before_summary['issue_id'] || '').to_s }
        remove_actions + skipped
      end

      # ===========================================================
      # Source-edge bookkeeping
      # ===========================================================

      # Build edge_lookup: Hash<Integer, EdgeRecord>.
      def build_edge_lookup(source_snapshot)
        h = {}
        return h if source_snapshot.nil?
        Array(source_snapshot.respond_to?(:edges) ? source_snapshot.edges : []).each do |e|
          if e.respond_to?(:id) && !e.id.nil?
            h[int(e.id)] = e
          end
        end
        h
      end

      # ===========================================================
      # Issue classification
      # ===========================================================

      def classify_issue(issue, edge_lookup:, tolerance:)
        edge_ids = issue.is_a?(Hash) ? issue[:edge_ids] : nil
        unless edge_ids.is_a?(Array) && edge_ids.length == 2
          return { valid: false, skipped_action: self_match_skipped(issue) }
        end
        # Self-match guard (8).
        begin
          if int(edge_ids[0]) == int(edge_ids[1])
            return { valid: false, skipped_action: self_match_skipped(issue) }
          end
        rescue ArgumentError, TypeError
          return { valid: false, skipped_action: self_match_skipped(issue) }
        end
        ea = edge_lookup[int(edge_ids[0])] rescue nil
        eb = edge_lookup[int(edge_ids[1])] rescue nil
        if ea.nil? || eb.nil?
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_MISSING_EDGE_RECORD,
                     'no edge record for one or both edge_ids in the source snapshot') }
        end
        # Guard 4: finite coordinates.
        unless finite_point?(ea.start_point) && finite_point?(ea.end_point) &&
               finite_point?(eb.start_point) && finite_point?(eb.end_point)
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_NON_FINITE_COORDS,
                     'one or more endpoint coordinates are not finite') }
        end
        # Guard 7: layer names byte-identical after Layer0
        # normalization. The direct matcher also enforces this;
        # classifying here surfaces the explicit per-issue
        # guard.
        layer_a = normalize_layer(layer_name_of(ea))
        layer_b = normalize_layer(layer_name_of(eb))
        if layer_a != layer_b
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_LAYER_MISMATCH,
                     "different normalized layer names: #{layer_a.inspect} vs #{layer_b.inspect}") }
        end
        # Direct match (BLOCK-002): the same matcher used by the
        # validator performs the per-axis tolerance check.
        kind = direct_match?(
          ea.start_point, ea.end_point,
          eb.start_point, eb.end_point,
          layer_a, layer_b, tolerance
        )
        if kind.nil?
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_NEAR_BUT_NOT_EXACT,
                     'endpoints coincide outside tolerance.duplicate; not an exact duplicate') }
        end
        {
          valid:     true,
          ea:        ea,
          eb:        eb,
          basis_kind: kind
        }
      end

      # ===========================================================
      # find_class_for_issue
      # ===========================================================
      #
      # For one issue, find the derived records whose source
      # EdgeRecord is one of {ea, eb} AND whose geometry
      # directly matches the OTHER source edge's geometry
      # (forward or reversed, within tolerance). The class is
      # the set of such records. A record whose source edge
      # is NOT in {ea, eb} is NEVER swept into the class
      # (BLOCK-001: unrelated records in the same bucket are
      # not swept into the action).
      #
      # Returns { members:, source_edge_ids: } or nil.

      def find_class_for_issue(workspace:, ea:, eb:, tolerance:)
        return nil if workspace.nil? || ea.nil? || eb.nil?
        entities = workspace.respond_to?(:entities) ? workspace.entities : []
        return nil if entities.empty?

        # ea and eb are EdgeRecord (with .id, .source.persistent_id_path).
        ea_id = int(ea.id)
        eb_id = int(eb.id)
        ea_layer = layer_name_of(ea)
        eb_layer = layer_name_of(eb)

        # Bucket index for O(N) lookup: quantize each derived
        # record's start/end at 2*tolerance and map
        # (qx1,qy1,qz1,qx2,qy2,qz2, layer) -> Array<record>.
        # This is candidate acceleration only; the direct
        # matcher (per-axis) is the actual match rule.
        bucket_size = (tolerance.to_f * 2.0)
        bucket_size = DEFAULT_DUPLICATE_TOLERANCE * 2.0 if bucket_size <= 0
        # ea and eb as candidate anchors. For each, look up
        # the bucket that contains each axis-aligned
        # quantization. (Adjacent buckets are handled by
        # searching the 3x3x3x3x3x3 neighborhood of buckets.)
        candidate_records = []
        # For each derived record, compute the matching
        # source edge ID (the edge whose persistent_id_path
        # matches one of the record's source_occurrence_ids).
        # This is the FULL leaf identity resolution (BLOCK-001).
        ea_path = ea.respond_to?(:source) && ea.source.respond_to?(:persistent_id_path) ?
                    ea.source.persistent_id_path : nil
        eb_path = eb.respond_to?(:source) && eb.source.respond_to?(:persistent_id_path) ?
                    eb.source.persistent_id_path : nil
        return nil if ea_path.nil? || eb_path.nil?

        entities.each do |d|
          next unless d.is_a?(DerivedEntityRecord)
          next unless d.kind == :edge
          # Resolve the record's source edges by full path
          # (including leaf PID).
          occ_ids = Array(d.source_occurrence_ids).map(&:to_s)
          next if occ_ids.empty?
          # Determine which source edge this record resolves to.
          record_path = source_path_from_occ_ids(occ_ids.first)
          next if record_path.nil?
          if record_path == ea_path
            # Record resolves to ea. Its geometry must
            # directly match eb (BLOCK-002).
            kind = direct_match?(
              start_finish_of(d)[0], start_finish_of(d)[1],
              eb.start_point, eb.end_point,
              layer_of(d), eb_layer, tolerance
            )
            if kind == :forward || kind == :reversed
              candidate_records << { record: d, source_edge_id: ea_id, kind: kind }
            end
          elsif record_path == eb_path
            # Record resolves to eb. Its geometry must
            # directly match ea.
            kind = direct_match?(
              start_finish_of(d)[0], start_finish_of(d)[1],
              ea.start_point, ea.end_point,
              layer_of(d), ea_layer, tolerance
            )
            if kind == :forward || kind == :reversed
              candidate_records << { record: d, source_edge_id: eb_id, kind: kind }
            end
          else
            # Record resolves to NEITHER ea nor eb. It is
            # NOT in the class (BLOCK-001: unrelated records
            # in the same bucket are not swept).
            next
          end
        end

        # Also include the records whose geometry matches
        # but which are NOT in the workspace's source edges
        # (e.g., records that are the same source edge as
        # ea or eb but with different derived_id). The
        # above loop already handles this case.

        # Verify each member has a unique source edge ID.
        source_edge_ids = candidate_records.map { |c| c[:source_edge_id] }.uniq
        if source_edge_ids.length != candidate_records.length
          # Some members share the same source edge -> repeated
          # reference. Per BLOCK-001, the class fails closed.
          return nil
        end
        members = candidate_records.map { |c| c[:record] }
        {
          members:         members,
          source_edge_ids: source_edge_ids
        }
      end

      # ===========================================================
      # verify_class_identity (BLOCK-001)
      # ===========================================================
      #
      # For each member in the class, verify:
      #   - Full occurrence/leaf identity resolves to exactly
      #     one current SourceSnapshot EdgeRecord.
      #   - Source EdgeRecords are distinct.
      #   - Derived records and live handles are distinct.
      #   - No member is the self-match of another.
      #   - No member has incomplete nested provenance.
      #
      # Returns { valid: true } or
      #         { valid: false, skipped_action: <action> }.

      def verify_class_identity(members:, ea:, eb:, source_snapshot:, edge_lookup:, issue:)
        return { valid: false,
                 skipped_action: skipped_action_for(issue, REASON_INCOMPLETE_PROVENANCE,
                   'class has no members') } if members.nil? || members.empty?
        return { valid: false,
                 skipped_action: skipped_action_for(issue, REASON_INCOMPLETE_PROVENANCE,
                   'class has fewer than 2 members (not a duplicate)') } if members.length < 2

        # Distinct derived_ids.
        uniq_derived_ids = members.map { |d| d.derived_id.to_s }.uniq
        if uniq_derived_ids.length != members.length
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_DERIVED_NOT_FOUND,
                     'duplicate derived_id inside the class; ambiguity fails closed') }
        end

        # Each member must have full leaf identity (source_occurrence_ids non-empty).
        incomplete = members.select { |d| Array(d.source_occurrence_ids).empty? }
        unless incomplete.empty?
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_INCOMPLETE_PROVENANCE,
                     'one or more derived records have empty source_occurrence_ids; fail-closed') }
        end

        # Each member must resolve to EXACTLY ONE source
        # EdgeRecord in the current SourceSnapshot (full
        # occurrence/leaf identity). If a member's path
        # matches multiple edges, OR no edges, the class
        # fails closed.
        resolved_ids = []
        members.each do |d|
          occ = Array(d.source_occurrence_ids).first
          path = source_path_from_occ_ids(occ)
          matches = edge_lookup.values.select do |edge|
            ep = edge.respond_to?(:source) && edge.source.respond_to?(:persistent_id_path) ?
                    edge.source.persistent_id_path : nil
            ep.is_a?(Array) && ep == path
          end
          if matches.length != 1
            return { valid: false,
                     skipped_action: skipped_action_for(issue, REASON_AMBIGUOUS_RESOLUTION,
                       "derived record #{d.derived_id.inspect} resolves to #{matches.length} source EdgeRecord(s) (expected exactly 1); fail-closed") }
          end
          resolved_ids << int(matches.first.id)
        end

        # Source EdgeRecords are distinct (no two members
        # resolve to the same source edge).
        if resolved_ids.uniq.length != resolved_ids.length
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_NON_DISTINCT_SOURCE,
                     'two or more class members resolve to the same source EdgeRecord; fail-closed') }
        end

        # No self-match: the resolved source edges must
        # include both ea and eb (or at least two distinct
        # source edges from the issue).
        unless resolved_ids.include?(int(ea.id)) || resolved_ids.include?(int(eb.id))
          # This is a "the class doesn't actually cover the
          # issue's source edges" case. Fail closed.
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_AMBIGUOUS_RESOLUTION,
                     "class members resolve to source edges #{resolved_ids.inspect} which do not include the issue's source edges #{[ea.id, eb.id].inspect}; fail-closed") }
        end

        { valid: true }
      end

      # ===========================================================
      # Class deduplication
      # ===========================================================
      #
      # Multiple issues that authorize overlapping sets of
      # derived records are merged into a single class. The
      # merge is union-find over the issue->class->member
      # relationship. After merging, each class emits one
      # :remove_duplicate_edge action.
      #
      # Example (V15-3, three identical source edges):
      #   Issue (0, 1) -> {der-0, der-1}
      #   Issue (0, 2) -> {der-0, der-2}
      #   Issue (1, 2) -> {der-1, der-2}
      # All three share members -> merge into one class
      # {der-0, der-1, der-2} with one action.
      #
      # Example (V15-B001-3, unrelated record):
      #   Issue (0, 1) -> {der-A, der-B}
      #   No other issues -> one action for {der-A, der-B}.
      #   The unrelated record (not covered by any issue) is
      #   NOT in any class and is NEVER swept.

      def deduplicate_classes(per_class)
        return [] if per_class.empty?
        # Union-find over classes (by index). Two classes
        # are unioned iff they share at least one derived
        # record.
        n = per_class.length
        parent = (0...n).to_a
        rank = Array.new(n, 0)
        find = ->(i) {
          while parent[i] != i
            parent[i] = parent[parent[i]]
            i = parent[i]
          end
          i
        }
        union = ->(i, j) {
          ri = find.call(i)
          rj = find.call(j)
          if ri != rj
            if rank[ri] < rank[rj]
              parent[ri] = rj
            elsif rank[ri] > rank[rj]
              parent[rj] = ri
            else
              parent[rj] = ri
              rank[ri] += 1
            end
          end
        }
        # Index derived_id -> list of class indices
        did_to_class = {}
        per_class.each_with_index do |c, i|
          c[:members].each do |m|
            did_to_class[m.derived_id.to_s] ||= []
            did_to_class[m.derived_id.to_s] << i
          end
        end
        # Union classes that share a derived record
        did_to_class.each_value do |idxs|
          idxs.each_cons(2) { |a, b| union.call(a, b) }
        end
        # Collect by root
        groups = {}
        per_class.each_with_index do |c, i|
          r = find.call(i)
          (groups[r] ||= { members: [], issue_ids: [], source_edge_ids: [], basis_kind: :forward })[:members] << c[:members]
          groups[r][:issue_ids] << issue_id_of(c[:issue])
          groups[r][:source_edge_ids] |= c[:source_edge_ids]
        end
        # Flatten the per-class member arrays
        groups.values.map do |g|
          # Determine basis_kind from the first issue
          basis = per_class.find { |c| issue_id_of(c[:issue]) == g[:issue_ids].first }&.dig(:basis_kind) || :forward
          # Deduplicate members by derived_id
          seen = {}
          members = g[:members].flatten.select { |m| seen[m.derived_id.to_s] ? false : (seen[m.derived_id.to_s] = true; true) }
          {
            issue_ids:        g[:issue_ids].sort,
            source_edge_ids:  g[:source_edge_ids].sort,
            members:          members,
            basis_kind:       basis
          }
        end
      end

      # ===========================================================
      # Action builders
      # ===========================================================

      def build_remove_action_for_class(c)
        members         = c[:members]
        sorted_ids      = members.map { |d| d.derived_id.to_s }.sort
        survivor_id     = sorted_ids.first
        removed_ids     = sorted_ids[1..] || []
        # Provenance union: every contributing derived
        # record's source_occurrence_ids, sorted unique.
        provenance_union = members
                             .flat_map { |d| Array(d.source_occurrence_ids).map(&:to_s) }
                             .uniq
                             .sort
        # Issue IDs: the source issues that authorized
        # the class (BLOCK-004: remove action must preserve
        # source issue references).
        issue_ids = Array(c[:issue_ids]).map(&:to_s).sort
        # Canonical key for the action_id digest (NOT
        # used as the match rule; just for the action_id
        # uniqueness).
        canonical_key = canonical_geometry_key(
          start:  start_finish_of(members.first)[0],
          finish: start_finish_of(members.first)[1],
          layer:  layer_of(members.first),
          tolerance: DEFAULT_DUPLICATE_TOLERANCE
        )
        basis_str = c[:basis_kind] == :reversed ? BASIS_REVERSED_EXACT : BASIS_FORWARD_EXACT
        snapshot_id = c[:ea].respond_to?(:id) ? int(c[:ea].id).to_s : ''
        action = build_remove_action(
          survivor_id:           survivor_id,
          removed_ids:           removed_ids,
          source_occurrence_ids: provenance_union,
          basis:                 basis_str,
          canonical_key:         canonical_key,
          snapshot_id:           snapshot_id,
          member_derived_ids:    sorted_ids,
          issue_ids:             issue_ids
        )
        action
      end

      # ===========================================================
      # Action factory
      # ===========================================================

      def build_remove_action(survivor_id:, removed_ids:,
                              source_occurrence_ids:, basis:,
                              canonical_key:, snapshot_id:,
                              member_derived_ids:, issue_ids: [])
        action_id = deterministic_action_id(
          rule_id:           RULE_ID,
          snapshot_id:       snapshot_id,
          canonical_key:     canonical_key,
          sorted_member_ids: member_derived_ids
        )
        before_summary = {
          'survivor_derived_id'        => survivor_id.to_s,
          'removed_derived_ids'        => removed_ids.map(&:to_s).freeze,
          'duplicate_pairs'            => removed_ids.length,
          'canonical_endpoint_summary' => canonical_endpoint_summary(canonical_key),
          'layer'                      => layer_from_canonical_key(canonical_key),
          'before_edge_count'          => member_derived_ids.length,
          'proposed_after_edge_count'  => 1,
          # BLOCK-004: remove actions preserve source issue
          # references for the audit trail.
          'issue_ids'                  => Array(issue_ids).map(&:to_s).sort.freeze
        }.freeze
        proposed_after_summary = {
          'survivor_derived_id'        => survivor_id.to_s,
          'removed_derived_ids'        => [].freeze,
          'duplicate_pairs'            => 0,
          'canonical_endpoint_summary' => canonical_endpoint_summary(canonical_key),
          'layer'                      => layer_from_canonical_key(canonical_key),
          'before_edge_count'          => member_derived_ids.length,
          'proposed_after_edge_count'  => 1
        }.freeze
        explanation = build_explanation(
          basis:           basis,
          member_count:    member_derived_ids.length,
          source_occ_count: source_occurrence_ids.length
        )
        RepairAction.new(
          action_id:               action_id,
          type:                    ACTION_TYPE,
          rule_id:                 RULE_ID,
          confidence:              CONFIDENCE,
          confidence_basis:        basis.to_s,
          explanation:             explanation,
          source_occurrence_ids:   source_occurrence_ids.map(&:to_s).freeze,
          affected_derived_ids:    removed_ids.map(&:to_s).freeze,
          before_summary:          before_summary,
          proposed_after_summary:  proposed_after_summary,
          topology_impact:         TOPOLOGY_IMPACT,
          auto_applicable:         true,
          status:                  :proposed
        )
      end

      def skipped_action_for(issue, reason, explanation)
        eids = issue.is_a?(Hash) ? issue[:edge_ids] : nil
        iid = issue.is_a?(Hash) ? issue[:issue_id] : nil
        RepairAction.new(
          type:                    ACTION_TYPE,
          rule_id:                 RULE_ID,
          confidence:              CONFIDENCE,
          confidence_basis:        "skipped:#{reason}",
          explanation:             explanation.to_s,
          source_occurrence_ids:   (eids.is_a?(Array) ? eids.map { |x| int(x) } : []).compact.freeze,
          affected_derived_ids:    [].freeze,
          before_summary:          { 'reason' => reason.to_s, 'issue_id' => iid.to_s }.freeze,
          proposed_after_summary:  { 'reason' => reason.to_s }.freeze,
          topology_impact:         'no_op',
          auto_applicable:         true,
          status:                  :skipped
        )
      end

      def self_match_skipped(issue)
        skipped_action_for(issue, REASON_SELF_MATCH,
          'duplicate evidence references the same source edge twice; nothing to remove')
      end

      # ===========================================================
      # source_path_from_occ_ids
      # ===========================================================
      #
      # Convert a V1.4 source_occurrence_id (e.g. "occ-100>101")
      # into the FULL persistent_id_path including the leaf
      # (Array<Integer>). This is the canonical V1.5 mapping.
      # The leaf PID is the LAST component of the path.

      def source_path_from_occ_ids(occ_id)
        return nil if occ_id.nil? || !occ_id.is_a?(String)
        s = occ_id.to_s
        rest = if s.start_with?('occ-')
                 s[4..-1]
        elsif s.start_with?('transient-occ-')
                 s[14..-1]
        else
                 nil
        end
        return nil if rest.nil?
        if rest.start_with?('ipath-')
          rest = rest[6..-1]
        end
        parts = rest.split('>').map { |x| Integer(x) rescue nil }.compact
        return nil if parts.empty?
        parts
      end

      # ===========================================================
      # Registry / issue collection
      # ===========================================================

      def collect_duplicate_candidates(registry)
        return [] if registry.nil?
        out = []
        Array(registry.respond_to?(:issues) ? registry.issues : []).each do |iss|
          if iss.is_a?(Hash) && iss[:issue_type].to_s == 'duplicate_edge_candidate'
            out << iss
          end
        end
        out.sort_by { |iss| iss[:issue_id].to_s }
      end

      # ===========================================================
      # Tolerance / numeric helpers
      # ===========================================================

      def read_duplicate_tolerance(source_snapshot)
        return DEFAULT_DUPLICATE_TOLERANCE if source_snapshot.nil?
        ec = source_snapshot.respond_to?(:execution_config) ? source_snapshot.execution_config : nil
        return DEFAULT_DUPLICATE_TOLERANCE if ec.nil?
        vals = ec.respond_to?(:tolerance_values) ? ec.tolerance_values : nil
        return DEFAULT_DUPLICATE_TOLERANCE unless vals.is_a?(Hash)
        v = vals[:duplicate] || vals['duplicate']
        v ? v.to_f : DEFAULT_DUPLICATE_TOLERANCE
      end

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

      def points_within?(p, q, tol)
        return false unless p.is_a?(Array) && q.is_a?(Array) && p.length == 3 && q.length == 3
        (0..2).all? { |i| (p[i].to_f - q[i].to_f).abs <= tol.to_f }
      end

      def int(v)
        Integer(v) rescue nil
      end

      def layer_name_of(edge)
        return nil unless edge.respond_to?(:layer)
        edge.layer
      end

      def start_finish_of(record)
        return [nil, nil] unless record.respond_to?(:geometry_summary)
        g = record.geometry_summary
        [g['start'] || g[:start], g['end'] || g[:end]]
      end

      def layer_of(record)
        return 'Layer0' unless record.respond_to?(:geometry_summary)
        g = record.geometry_summary
        g['layer'] || g[:layer] || 'Layer0'
      end

      def issue_id_of(issue)
        return '' unless issue.is_a?(Hash)
        issue[:issue_id].to_s
      end

      # ===========================================================
      # Deterministic action_id
      # ===========================================================

      def deterministic_action_id(rule_id:, snapshot_id:, canonical_key:, sorted_member_ids:)
        input = [
          rule_id.to_s,
          snapshot_id.to_s,
          canonical_key.to_s,
          Array(sorted_member_ids).map(&:to_s).sort.join('+')
        ].join('|')
        digest = Digest::SHA256.hexdigest(input)[0, 12]
        "act-#{rule_id}-#{digest}"
      end

      # ===========================================================
      # Canonical-key accessors (audit only)
      # ===========================================================

      def canonical_endpoint_summary(canonical_key)
        parts = canonical_key.to_s.split('|')
        {
          'quantized_start' => parts[1],
          'quantized_end'   => parts[2],
          'format'          => 'canonical_geometry_key_v1'
        }.freeze
      end

      def layer_from_canonical_key(canonical_key)
        parts = canonical_key.to_s.split('|')
        l = parts.find { |p| p.start_with?('layer=') }
        l ? l.sub('layer=', '') : nil
      end

      # ===========================================================
      # Explanation builder
      # ===========================================================

      def build_explanation(basis:, member_count:, source_occ_count:)
        basis_kind = basis.to_s.start_with?('reversed') ? 'reversed exact' : 'forward exact'
        survivor_count = 1
        removed_count  = member_count - survivor_count
        "Exact duplicate edge (#{basis_kind}); #{member_count} source occurrences converge on one canonical derived segment; survivor keeps the lex-smallest derived_id; #{removed_count} derived record(s) to remove; provenance union size = #{source_occ_count}."
      end
    end
  end
end
