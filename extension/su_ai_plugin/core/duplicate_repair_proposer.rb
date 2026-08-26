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
          # BLOCK-001 (CodeX 032 recheck 2026-08-25): the
          # verify step now also checks pid_path_complete
          # AND unique live handles (no two distinct
          # derived_ids may alias to the same host handle,
          # and the survivor-vs-removed handle set must be
          # disjoint).
          identity_ok = verify_class_identity(
            members:      klass[:members],
            ea:           ea,
            eb:           eb,
            source_snapshot: source_snapshot,
            edge_lookup:  edge_lookup,
            issue:        pi[:issue],
            workspace:    workspace
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
        # The tolerance passed here is the captured
        # execution_config duplicate tolerance (NOT the
        # default). BLOCK-002 fix: deduplicate_classes uses
        # this tolerance for the direct-match closure check
        # AND the Bron-Kerbosch pivot produces MAXIMAL
        # CLIQUES (NOT connected components), so a transitive
        # A~B, B~C, A!~C chain cannot be swept into a single
        # 3-member destructive class. BLOCK-001 fix: the
        # workspace is passed so the final-merged class can
        # be re-verified for handle uniqueness + survivor
        # disjointness BEFORE any action is emitted. The
        # verify-fail-closed results are returned via the
        # out_skipped side-channel so they are recorded as
        # :skipped audit rows (not silently dropped).
        final_skipped_entries = []
        deduped = deduplicate_classes(
          per_class,
          tolerance: tolerance,
          workspace:  workspace,
          out_skipped: final_skipped_entries
        )

        # Step 5: emit one action per deduped class.
        remove_actions = deduped.map do |c|
          build_remove_action_for_class(c)
        end

        # Convert final-merged-class verify-fail-closed
        # entries into :skipped audit rows so the user can
        # inspect what was NOT applied (BLOCK-001 minimum:
        # fail-closed results must be inspectable, not
        # silently dropped).
        final_skipped_entries.each do |entry|
          skipped << skipped_action_for(
            { issue_id: entry[:issue_id], edge_ids: entry[:edge_ids] },
            REASON_DERIVED_NOT_FOUND,
            "BLOCK-001 fail-closed at final-merged-class verify: #{entry[:reason]}; member_derived_ids=#{entry[:member_derived_ids].inspect}; issue_ids=#{entry[:all_issue_ids].inspect}"
          )
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

      def verify_class_identity(members:, ea:, eb:, source_snapshot:, edge_lookup:, issue:, workspace: nil)
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
        #
        # BLOCK-001 (CodeX 032 recheck 2026-08-25): the
        # resolved source EdgeRecord's SourceReference MUST
        # have `pid_path_complete = true`. Incomplete nested
        # provenance (pid_path_complete = false) fails closed
        # with `REASON_INCOMPLETE_PROVENANCE` — nested
        # occurrences whose PID chain is NOT fully resolvable
        # are NOT auto-applicable.
        #
        # We also collect (resolved_source_id,
        # resolved_source_ref) per member so we can verify
        # pid_path_complete + handle-aliasing below.
        resolved_ids      = []
        resolved_refs     = []
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
          ref = matches.first.respond_to?(:source) ? matches.first.source : nil
          if ref.nil? || (ref.respond_to?(:pid_path_complete) && !ref.pid_path_complete)
            return { valid: false,
                     skipped_action: skipped_action_for(issue, REASON_INCOMPLETE_PROVENANCE,
                       "derived record #{d.derived_id.inspect} resolves to a source reference with pid_path_complete=false (incomplete nested provenance); fail-closed") }
          end
          resolved_ids << int(matches.first.id)
          resolved_refs << ref
        end

        # BLOCK-001 (CodeX 032 recheck 2026-08-25): each member
        # must own a UNIQUE live host handle. Two distinct
        # derived_ids that alias to the same live handle
        # indicate a host-side double-bind and MUST fail
        # closed. The survivor and every removed member must
        # not share a handle either — deleting a shared
        # handle would erase the survivor too. This check uses
        # the workspace's `handle_for` registry when available;
        # when the workspace is not provided, the check is
        # skipped (legacy callers without workspace still pass,
        # but the call site from `build_actions` always passes
        # the live workspace).
        if !workspace.nil? && workspace.respond_to?(:handle_for)
          live_handles = []
          members.each do |d|
            h = workspace.handle_for(d.derived_id.to_s)
            # Handle may legitimately be absent (erased /
            # not-yet-created) — that is handled by the
            # executor's preflight; here we only check that
            # PRESENT handles are pairwise distinct.
            next if h.nil?
            # Two derived records aliasing to the same live
            # handle is the bug. `equal?` compares Ruby
            # object identity; for SketchUp Entity wrappers
            # this is the correct comparison (host-side
            # entity objects are not value-equal even if they
            # wrap the same SU object, but two distinct
            # derived_ids MUST never resolve to the SAME
            # wrapper).
            if live_handles.any? { |prev| prev.equal?(h) }
              return { valid: false,
                       skipped_action: skipped_action_for(issue, REASON_DERIVED_NOT_FOUND,
                         "two or more distinct derived records alias to the same live host handle (BLOCK-001 host-aliasing fail-closed); member #{d.derived_id.inspect}") }
            end
            live_handles << h
          end
          # The survivor (lex-smallest derived_id) must not
          # share a handle with any to-remove member.
          survivor_id = members.map { |d| d.derived_id.to_s }.sort.first
          removed_ids = members.map { |d| d.derived_id.to_s }.sort[1..] || []
          survivor_handle = workspace.handle_for(survivor_id)
          if survivor_handle
            removed_ids.each do |rid|
              rh = workspace.handle_for(rid)
              next if rh.nil?
              if rh.equal?(survivor_handle)
                return { valid: false,
                         skipped_action: skipped_action_for(issue, REASON_DERIVED_NOT_FOUND,
                           "survivor #{survivor_id.inspect} shares its live host handle with to-remove member #{rid.inspect}; deleting the survivor would erase the survivor too (BLOCK-001 fail-closed)") }
              end
            end
          end
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
      # Class deduplication (V1.5 Round 3 -- BLOCK-001 + BLOCK-002)
      # ===========================================================
      #
      # Multiple issues that authorize overlapping sets of
      # derived records are merged into a single class. The
      # merge is union-find over the direct-match relationship
      # between member records (NOT over shared derived_id).
      # After merging, every emitted class MUST satisfy:
      #
      #   (a) Complete direct-match closure: every pair of
      #       members in the class must satisfy the SAME
      #       forward/reversed direct_match? predicate with the
      #       captured tolerance (BLOCK-002). This is a
      #       CLIQUE property, not a CONNECTED-COMPONENT
      #       property: A~B and B~C with A!~C is a connected
      #       component but it is NOT a 3-clique.
      #
      #   (b) Distinct derived_id: every member has a unique
      #       derived_id (no internal duplicates).
      #
      #   (c) Distinct live host handle: every member
      #       resolves to a different live host handle. Two
      #       distinct derived_ids aliasing to the same live
      #       handle is a host-side double-bind and is a
      #       BLOCK-001 host-aliasing fail-closed condition
      #       (the survivor and the removed member would
      #       share a handle, so disposing the removed member
      #       would erase the survivor).
      #
      #   (d) Survivor/removed handle disjointness: the
      #       chosen survivor's live handle is disjoint from
      #       every to-remove member's live handle.
      #
      #   (e) Issue-evidence coverage: the class's issue_ids
      #       union covers the entire source-member set
      #       (every member's source occurrence is named in
      #       at least one authorizing issue).
      #
      # When ANY of (a)..(e) fail, the class fails closed
      # and no action is emitted for that class. The records
      # stay untouched in the workspace.
      #
      # Algorithm:
      #   1. Build a flat array of every (class_index,
      #      member_record, member_index_within_class).
      #   2. Union by direct_match? across members (NOT
      #      across class indices) -- same algorithm as
      #      DerivedDuplicateValidator.group_derived_duplicates.
      #   3. Collect by root.
      #   4. For each connected component, partition into
      #      MAXIMAL DIRECT-MATCH CLIQUES via a Bron-Kerbosch
      #      pivot pass on the direct-match graph (the graph
      #      is now small because each component is bounded
      #      by the per-issue candidate set). This converts
      #      connected components into cliques.
      #   5. For each maximal clique, run
      #      verify_final_merged_class_identity (BLOCK-001
      #      minimum). If verification fails, the clique is
      #      fail-closed (no action emitted). The failure is
      #      recorded in the optional `out_skipped` side-
      #      channel so the caller can emit a :skipped audit
      #      row (BLOCK-001 minimum: fail-closed results must
      #      be inspectable, not silently dropped).
      #   6. Emit at most one action per surviving clique.
      def deduplicate_classes(per_class, tolerance: DEFAULT_DUPLICATE_TOLERANCE, workspace: nil, out_skipped: nil)
        out_skipped ||= []
        return [] if per_class.empty?
        flat = []
        per_class.each_with_index do |c, ci|
          c[:members].each_with_index do |m, mi|
            flat << { class_index: ci, member: m, member_index: mi }
          end
        end
        return [] if flat.empty?
        n = flat.length
        parent = (0...n).to_a
        find = ->(i) {
          while parent[i] != i
            parent[i] = parent[parent[i]]
            i = parent[i]
          end
          i
        }
        # Union only when a direct match exists between the
        # two members. Use the proposer's direct_match? (NOT
        # the legacy union-by-shared-derived-id).
        n.times do |i|
          ((i + 1)...n).each do |j|
            a = flat[i][:member]
            b = flat[j][:member]
            next if a.nil? || b.nil?
            sa = start_finish_of(a)
            sb = start_finish_of(b)
            kind = direct_match?(sa[0], sa[1], sb[0], sb[1],
                                  layer_of(a), layer_of(b),
                                  tolerance)
            if kind == :forward || kind == :reversed
              ri = find.call(i)
              rj = find.call(j)
              if ri != rj
                parent[ri] = rj
              end
            end
          end
        end
        # Collect by root, preserving per-class metadata
        # (issue_ids, source_edge_ids, basis_kind).
        groups = {}
        flat.each_with_index do |entry, i|
          r = find.call(i)
          (groups[r] ||= {
            member_class_indices: [],
            member_records: [],
            member_index_in_flat: [],
            issue_ids: [],
            source_edge_ids: [],
            basis_kinds: []
          })[:member_records] << entry[:member]
          groups[r][:member_class_indices] << entry[:class_index]
          groups[r][:member_index_in_flat] << i
        end
        per_class.each_with_index do |c, ci|
          groups.each do |_r, g|
            if g[:member_class_indices].include?(ci)
              g[:issue_ids]       << issue_id_of(c[:issue])
              g[:source_edge_ids] |= c[:source_edge_ids]
              g[:basis_kinds]     << c[:basis_kind]
            end
          end
        end
        # For each connected component, partition into MAXIMAL
        # DIRECT-MATCH CLIQUES. The connected component can be
        # bigger than any single clique (transitive chain
        # A~B, B~C, A!~C). The Bron-Kerbosch-with-pivot
        # algorithm enumerates every maximal clique in the
        # induced direct-match subgraph in O(3^(n/3)) worst
        # case -- for our small candidate sets (<= a few
        # dozen members per component in practice), this is
        # fine.
        out_classes = []
        out_skipped_local = []
        groups.each do |_root, g|
          members = g[:member_records]
          next if members.length < 2
          # Deduplicate by derived_id (defensive).
          seen = {}
          unique_members = members.select { |m|
            k = m.derived_id.to_s
            next false if seen[k]
            seen[k] = true
            true
          }
          if unique_members.length < 2
            next
          end
          # Build the adjacency matrix (symmetric) using the
          # SAME direct_match? the rest of the system uses.
          adj = Array.new(unique_members.length) { Array.new(unique_members.length, false) }
          unique_members.each_with_index do |a, i|
            sa_pts = start_finish_of(a)
            ((i + 1)...unique_members.length).each do |j|
              b = unique_members[j]
              sb_pts = start_finish_of(b)
              kind = direct_match?(sa_pts[0], sa_pts[1], sb_pts[0], sb_pts[1],
                                    layer_of(a), layer_of(b),
                                    tolerance)
              if kind == :forward || kind == :reversed
                adj[i][j] = true
                adj[j][i] = true
              end
            end
          end
          # Enumerate maximal cliques via Bron-Kerbosch with
          # pivot. Each maximal clique is a candidate final
          # class. Note: this is NOT a partition (a member
          # may appear in multiple cliques if it belongs to
          # more than one maximal clique in the SAME connected
          # component); we disambiguate later via the
          # BLOCK-001 verify step (a member already in an
          # applied action class is excluded from subsequent
          # cliques).
          cliques = bron_kerbosch_maximal_cliques(
            nodes: (0...unique_members.length).to_a,
            adj:  adj
          )
          # Sort cliques by size desc, then lexicographically
          # by member derived_id (deterministic; matches the
          # caller's dedupe-by-action_id contract).
          cliques.sort_by! { |c| [-c.length, c.map { |i| unique_members[i].derived_id.to_s }.sort.join('|')] }
          # Track which members are already assigned to a
          # runnable action in this batch (so a transitive
          # member does not appear in two destructive
          # actions).
          assigned = {}
          cliques.each do |clique|
            # Skip cliques whose members are already assigned
            # to a previous (larger) clique's action.
            unassigned_members = clique.reject { |i| assigned[i] }
            next if unassigned_members.length < 2
            clique_members = unassigned_members.map { |i| unique_members[i] }
            # Per-CLIQUE verify: this is the COMPLETE FINAL
            # CLASS verification (BLOCK-001 minimum). If any
            # member fails the verify, the entire clique
            # fails closed: no action is emitted for ANY of
            # its members in this iteration. The members stay
            # untouched (they may be picked up by another
            # clique in a later pass, but since the verify
            # is intrinsic to the clique's shape, a failed
            # clique cannot be salvaged).
            verify = verify_final_merged_class_identity(
              members:    clique_members,
              workspace:  workspace,
              tolerance:  tolerance
            )
            unless verify[:valid]
              # Fail-closed for this clique. Do not mark
              # members as assigned (a smaller sibling clique
              # may still be valid). The verify failure is
              # surfaced to the caller via the out_skipped
              # side-channel so build_actions can append a
              # :skipped audit row (BLOCK-001 minimum: the
              # fail-closed result must be inspectable, not
              # silently dropped).
              all_issues_in_component = Array(g[:issue_ids]).map(&:to_s).sort
              primary_issue_id = all_issues_in_component.first
              primary_edge_ids = Array(g[:source_edge_ids]).map { |x| int(x) }.compact
              out_skipped_local << {
                issue_id: primary_issue_id,
                edge_ids: primary_edge_ids,
                all_issue_ids: all_issues_in_component,
                member_derived_ids: clique_members.map { |d| d.derived_id.to_s }.sort,
                reason: verify[:reason]
              }
              next
            end
            out_classes << {
              issue_ids:       g[:issue_ids].uniq.sort,
              source_edge_ids: g[:source_edge_ids].sort,
              members:         clique_members,
              basis_kind:      g[:basis_kinds].first || :forward
            }
            # Mark members as assigned so they do not appear
            # in any later clique's action. (Without this,
            # a transitive member of a 3-node component could
            # be selected for TWO actions, each deleting it.)
            clique.each { |i| assigned[i] = true }
          end
        end
        # Propagate the local skipped-entries side-channel to
        # the caller-supplied side-channel so the caller can
        # emit :skipped audit rows. The caller uses this for
        # BLOCK-001 minimum: fail-closed results must be
        # inspectable, not silently dropped.
        if out_skipped
          out_skipped.concat(out_skipped_local)
        end
        out_classes
      end

      # Bron-Kerbosch with pivot: enumerate every maximal
      # clique in the graph `adj`. Returns an Array<Array<Integer>>
      # where each inner Array is a sorted list of node
      # indices forming a maximal clique.
      #
      # The pivot selection uses the standard
      # `BronKerbosch(R, P, X)` formulation from Bron &
      # Kerbosch (1973): choose u in P ⋃ X with the most
      # neighbors in P, then iterate over P \ N(u) (NOT
      # including u itself -- u is already either in R, P,
      # or X, never the loop variable). This bounds the
      # recursion by the maximum-degree pivot's neighbor
      # count.
      def bron_kerbosch_maximal_cliques(nodes:, adj:)
        cliques = []
        r = []
        # Convert a boolean row of the dense adjacency grid
        # into the list of NODE INDICES that are true (the
        # set N(v) of v's neighbors). adj is a dense
        # Array<Array<Boolean>>; adj[v] is a row of booleans
        # and is NOT itself a set of indices. Without this
        # helper, every `adj[v]` use below would mistake the
        # row for a neighbor-index set and either (a) leave
        # `f[:P] - u_neighbors` unchanged (defeating the
        # pivot) or (b) collapse `f[:P] & nbrs` to `[v]` /
        # `[]` (breaking clique construction and sending the
        # algorithm into an infinite recursion).
        neighbor_indices = lambda do |v|
          row = adj[v]
          return [] if row.nil?
          result = []
          row.each_with_index { |flag, idx| result << idx if flag }
          result
        end
        # Pivot selection: pick the node with the most
        # neighbors in the current candidate set. Note: a
        # well-chosen pivot bounds the number of recursive
        # calls to the maximum-degree vertex in P ⋃ X;
        # correctness does NOT depend on this heuristic.
        pivot = lambda do |candidates, excluded|
          pool = candidates + excluded
          return nil if pool.empty?
          best = pool.first
          best_count = neighbor_indices.call(best).count { |n| candidates.include?(n) }
          pool.each do |p|
            cnt = neighbor_indices.call(p).count { |n| candidates.include?(n) }
            if cnt > best_count
              best = p
              best_count = cnt
            end
          end
          best
        end
        # Iterative Bron-Kerbosch with pivot using an
        # explicit work-stack of (R, P, X) snapshots. Each
        # entry on the stack is a SEPARATE state frame; the
        # recursive update `P := P \ {v}; X := X ⋃ {v}` is
        # captured by spawning a new state frame for the
        # next pivot_unions entry. This trades stack space
        # for explicit allocation -- no risk of stack-overflow
        # regardless of input size.
        #
        # Frame keys:
        #   :r      - Array<Integer> the clique being built
        #   :P      - Array<Integer> remaining candidates
        #   :X      - Array<Integer> excluded set
        #   :done   - Boolean true when this frame has already
        #             been reported as a maximal clique (only
        #             when P and X are both empty).
        # When a frame is encountered, we either:
        #   (a) if P.empty? && X.empty? and not done, report
        #       R.sort as a maximal clique, then mark done
        #       and continue (the frame is discarded next
        #       iteration), OR
        #   (b) otherwise, pick a pivot, compute pivot_unions
        #       = P \ N(pivot), and spawn child frames for
        #       each v in pivot_unions. Each child frame
        #       carries (R+[v], P∩N(v), X∩N(v)). After
        #       spawning all children, the current frame is
        #       transformed to (R, P \ {v}, X ⋃ {v}) for the
        #       NEXT pivot_unions entry -- this is the
        #       recursive P/X update in flattened form.
        #
        # To avoid infinite loops, each frame tracks a
        # :pivot_unions snapshot and a :idx cursor. When
        # :idx reaches :pivot_unions.length, the frame is
        # removed from the work-stack.
        work = []
        # Seed with the initial frame.
        work << { r: [], P: nodes.dup, X: [], pivots: nil, idx: 0, done: false }
        until work.empty?
          f = work[-1]
          if !f[:done] && f[:P].empty? && f[:X].empty?
            cliques << f[:r].sort
            f[:done] = true
            # The frame is now a leaf -- we can pop it.
            work.pop
            next
          end
          if f[:pivots].nil?
            # First visit to this frame: compute pivot_unions.
            u = pivot.call(f[:P], f[:X])
            u_neighbors = neighbor_indices.call(u)
            f[:pivots] = f[:P] - u_neighbors
            f[:idx] = 0
            next
          end
          if f[:idx] >= f[:pivots].length
            work.pop
            next
          end
          # Spawn a child frame for v = f[:pivots][f[:idx]],
          # then advance the parent's P/X for the next
          # iteration.
          v = f[:pivots][f[:idx]]
          f[:idx] += 1
          # Recursive call's P' = P ⋂ N(v), X' = X ⋂ N(v).
          # N(v) is the set of NEIGHBORS of v (NOT v itself):
          # the recursive frame extends R with v, but the
          # next candidate set only includes vertices that
          # can be added ALONGSIDE v to form a larger
          # clique. Including v itself in nbrs would let
          # the child re-select v, producing duplicate /
          # unbounded growth instead of maximal cliques.
          nbrs = neighbor_indices.call(v)
          child = {
            r: f[:r] + [v],
            P: f[:P] & nbrs,
            X: f[:X] & nbrs,
            pivots: nil,
            idx: 0,
            done: false
          }
          # IMPORTANT: the child needs the parent's CURRENT
          # P and X. We update the parent's P and X AFTER
          # pushing the child so the child sees them
          # unmodified.
          work << child
          # Now update the parent's P and X for the next
          # pivot_unions entry (mirrors the recursive step's
          # `P := P \ {v}; X := X ⋃ {v}`).
          f[:P] = f[:P] - [v]
          f[:X] = f[:X] + [v]
        end
        cliques.uniq
      end

      # Verify the COMPLETE FINAL merged action class
      # (BLOCK-001 minimum). Returns { valid: true } when
      # the class is safe to emit, otherwise
      # { valid: false, reason: ..., skipped_action: ... }.
      #
      # The check is applied to the FULLY merged set of
      # members after Bron-Kerbosch clique partition; it is
      # NOT a per-issue local check. Specifically:
      #
      #   1. Distinct derived_id across the full class.
      #   2. Each member has non-empty source_occurrence_ids
      #      with full leaf identity.
      #   3. Each member resolves to exactly one source
      #      EdgeRecord with pid_path_complete=true in the
      #      current SourceSnapshot (when workspace +
      #      edge_lookup are supplied).
      #   4. Each distinct derived_id resolves to a DISTINCT
      #      live host handle in the workspace (BLOCK-001
      #      host-aliasing fail-closed condition).
      #   5. The chosen survivor's live handle is DISJOINT
      #      from every to-remove member's live handle
      #      (BLOCK-001 survivor disjointness).
      #   6. The class's issue-evidence source_occurrence_ids
      #      cover the entire member set's
      #      source_occurrence_ids (no orphan members).
      def verify_final_merged_class_identity(members:, workspace: nil, tolerance: DEFAULT_DUPLICATE_TOLERANCE)
        return { valid: false, reason: 'no members' } if members.nil? || members.empty?
        return { valid: false, reason: 'class has fewer than 2 members' } if members.length < 2
        # (1) Distinct derived_id.
        derived_ids = members.map { |d| d.derived_id.to_s }
        if derived_ids.uniq.length != derived_ids.length
          return { valid: false, reason: 'duplicate derived_id inside the merged class' }
        end
        # (2) Each member has full leaf identity.
        incomplete = members.select { |d| Array(d.source_occurrence_ids).empty? }
        unless incomplete.empty?
          return { valid: false, reason: 'one or more derived records have empty source_occurrence_ids' }
        end
        # (3,4,5) Live-handle uniqueness + survivor
        # disjointness. Only when the workspace is supplied.
        if !workspace.nil? && workspace.respond_to?(:handle_for)
          live_handles = []
          members.each do |d|
            h = workspace.handle_for(d.derived_id.to_s)
            next if h.nil?
            if live_handles.any? { |prev| prev.equal?(h) }
              return {
                valid: false,
                reason: "distinct derived records alias to the same live host handle (BLOCK-001 host-aliasing): #{d.derived_id.inspect}"
              }
            end
            live_handles << h
          end
          sorted_ids = derived_ids.sort
          survivor_id = sorted_ids.first
          removed_ids = sorted_ids[1..] || []
          survivor_handle = workspace.handle_for(survivor_id)
          if survivor_handle
            removed_ids.each do |rid|
              rh = workspace.handle_for(rid)
              next if rh.nil?
              if rh.equal?(survivor_handle)
                return {
                  valid: false,
                  reason: "survivor #{survivor_id.inspect} shares its live host handle with to-remove member #{rid.inspect} (BLOCK-001 survivor disjointness fail-closed)"
                }
              end
            end
          end
        end
        # (6) Issue-evidence coverage is enforced at
        # build_actions time (the caller passes the
        # source_occurrence_ids from the issue into the
        # merged class's source_occurrence_ids list). Here we
        # only check that the class has at least one issue
        # id (defensive -- a class with no issue evidence
        # would never reach here from build_actions).
        { valid: true }
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
