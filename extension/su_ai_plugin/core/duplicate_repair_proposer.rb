#
# core/duplicate_repair_proposer.rb — V1.5 Phase 1
# Duplicate-candidate → RepairAction proposal.
#
# Per V1.5 Phase 1 plan §6 (IMPLEMENTATION ORDER step 2):
# reads the EXISTING duplicate_edge_candidate evidence from the
# IssueRegistry + SourceSnapshot + DerivedGeometryWorkspace,
# verifies exactness (endpoint equality within tolerance.duplicate),
# and emits one RepairAction per DUPLICATE OCCURRENCE (not per pair)
# with:
#
#   action_type      = :remove_duplicate_edge
#   rule_id         = 'duplicate_edge.exact_remove'
#   confidence      = 1.0 (with non-empty confidence_basis)
#   auto_applicable = true
#   status          = :proposed (then validate() transitions to
#                              :validated when ok)
#
# Each valid action carries:
#   - affected_derived_ids = the non-survivor derived_ids to remove
#     (Array<String>; one entry per non-survivor)
#   - source_occurrence_ids = [one occurrence_id (the dedup target)]
#
# ================================================================
# PROVENANCE SEMANTICS (per CodeX V1.5 BLOCK-003 recheck, 2026-08-25)
# ================================================================
#
# What "same source occurrence" means in production:
#
#   The PreflightRunner walks the user's selection tree. For
#   every SU Edge entity it encounters, it appends the parent
#   container's persistent_id (Group / ComponentInstance) to
#   the path and yields ONE EdgeRecord with:
#     - source.persistent_id       = leaf Edge entity's PID
#     - source.persistent_id_path  = CONTAINER path WITHOUT leaf
#                                    (Array<Integer>; [] for root)
#
#   occurrence_id_for(edge) computes:
#     "occ-<container_pid_path_joined_by_'>"
#
#   So two EdgeRecord instances from the SAME parent component
#   instance (same container chain) have the SAME occurrence_id.
#   This corresponds to the realistic case where a CAD import
#   accidentally produced two SU Edges with identical world
#   endpoints INSIDE THE SAME component definition (a ComponentInstance
#   whose definition contains duplicate edges).
#
# What "same source occurrence" does NOT mean:
#
#   - Same leaf Edge PID (different EdgeRecord.id from the same
#     SU Edge): such pairs come from overlap-selected scopes
#     (user selects an outer group AND its inner group); the
#     two visits have DIFFERENT container paths even though the
#     underlying SU Edge is the same. V1.5 Phase 1 deliberately
#     does NOT merge these -- they represent two different
#     analysis visits, not a CAD import duplicate.
#   - Two SU Edges from two ComponentInstances of the SAME
#     ComponentDefinition: each instance has its own
#     instance.persistent_id, so the container paths differ
#     even though the world coordinates are identical. V1.5
#     Phase 1 deliberately does NOT merge these (master plan
#     §17.2: shared-component-definition instances are
#     physically separate geometry).
#
# Real-SketchUp constructible should-repair scenario:
#
#   1. Create a ComponentDefinition (4 edges, where 2 of them
#      share world endpoints).
#   2. Place a ComponentInstance of that definition in the model.
#   3. Select the instance.
#   4. Analyze selection -> the snapshot contains TWO EdgeRecords
#      for the 2 overlapping edges (BOTH with persistent_id_path
#      = [<instance_pid>]).
#   5. DuplicateDetector emits a `duplicate_edge_candidate` pair.
#   6. Proposer sees SAME occurrence_id -> emits one action.
#   7. Executor removes 1 -> workspace has 3 derived records.
#
# Real-SketchUp constructible must-not-repair scenarios:
#
#   A. Two ComponentInstances of the same definition (different
#      instance.persistent_id -> different container paths): the
#      proposer emits :skipped with reason `source_occurrence_ids_differ`.
#   B. Edges at world-coords with no relationship (random
#      coincidence): same as A, different paths, skipped.
#
# Hard rules:
#   - NEVER auto-delete a short edge merely because its length is
#     below short_edge threshold. A "short edge" is NOT sufficient
#     evidence for deletion.
#   - NEVER handle approximate / fuzzy duplicates. V1.5 Phase 1
#     handles ONLY exact and reversed-exact duplicates within
#     tolerance.duplicate.
#   - NEVER merge distinct shared-component occurrences by mistake.
#     Two ComponentInstances sharing one ComponentDefinition have
#     DIFFERENT snapshot-local occurrence IDs; the duplicate detector
#     MUST compare occurrences, not definitions. (Plan §3 + §5 test 7.)
#   - NEVER collapse two derived edges whose world coordinates
#     coincide but whose source_occurrence_ids differ.
#   - Survivor selection: lexicographically smaller derived_id
#     wins (deterministic, testable).
#
# Deduplication model:
#   The DuplicateDetector emits C(N,2) pairs when N source edges
#   share endpoints within tolerance. We group the pairs BY
#   occurrence_id (only same-occurrence pairs qualify for removal;
#   cross-occurrence pairs are :skipped with provenance-differs
#   reason). For each occurrence_id with 2+ derived records in
#   the workspace, we emit ONE :remove_duplicate_edge action that
#   removes all non-survivor derived records. This collapses the
#   duplicate-pair explosion into one action per occurrence and
#   guarantees idempotency (apply once -> N-1 removed; apply
#   again -> all affected_derived_ids already gone -> :skipped).
#

require_relative 'repair_plan'

module SUAnalysis
  module Core
    module DuplicateRepairProposer
      module_function

      # Locked catalog constants. Tests pin these so future
      # accidental changes surface as failures.
      RULE_ID         = 'duplicate_edge.exact_remove'.freeze
      ACTION_TYPE     = :remove_duplicate_edge
      CONFIDENCE      = 1.0

      # Confidence basis strings (one per exact-match kind).
      BASIS_FORWARD_EXACT   = 'exact_endpoint_match_within_tolerance.duplicate'.freeze
      BASIS_REVERSED_EXACT  = 'reversed_endpoint_match_within_tolerance.duplicate'.freeze

      # Topology impact (audit string).
      TOPOLOGY_IMPACT = 'removes_duplicate_edge'.freeze

      # Reason strings (used in :skipped actions and explanations).
      REASON_SELF_MATCH           = 'duplicate_evidence_self_match'.freeze
      REASON_NEAR_BUT_NOT_EXACT   = 'endpoints_outside_tolerance_duplicate'.freeze
      REASON_PROVENANCE_DIFFERS   = 'source_occurrence_ids_differ'.freeze
      REASON_DERIVED_NOT_FOUND    = 'no_derived_record_for_source_edge'.freeze
      REASON_DERIVED_ERASED       = 'derived_record_handle_invalidated'.freeze
      REASON_NON_EDGE_KIND        = 'derived_record_kind_not_edge'.freeze

      # Propose a RepairPlan from the existing duplicate_edge_candidate
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

      # ---- internals ----------------------------------------------------

      # Build the actions Array. Group duplicate pairs by occurrence_id;
      # one :remove_duplicate_edge action per occurrence_id that has
      # 2+ derived records. Plus one :skipped action per invalid pair.
      def build_actions(source_snapshot:, registry:, workspace:)
        edge_lookup = build_edge_lookup(source_snapshot)
        occ_to_deriveds = build_occurrence_to_deriveds(workspace)
        candidates = collect_duplicate_candidates(registry)
        # bucket[occ_id] = { basis: 'forward'|'reversed' }
        # We don't pre-compute survivor/removed here because the
        # full derived list might span multiple pairs; the actual
        # survivor/removed are derived from occ_to_deriveds after
        # all pairs are processed.
        bucket_bases = {}
        skipped = []
        candidates.each do |iss|
          classification = classify_issue(iss, edge_lookup: edge_lookup,
                                                 occ_to_deriveds: occ_to_deriveds)
          if classification[:valid]
            occ = classification[:occurrence_id]
            bucket_bases[occ] ||= classification[:basis]
          else
            skipped << classification[:skipped_action]
          end
        end
        # Emit one :remove_duplicate_edge action per occurrence.
        remove_actions = []
        bucket_bases.each do |occ, basis|
          derived_ids = (occ_to_deriveds[occ] || []).uniq
          next if derived_ids.length < 2  # need at least 2 for a removal
          # Survivor = lex-smaller derived_id across the FULL list.
          survivor = derived_ids.min
          # All non-survivors are removed.
          removed_ids = (derived_ids - [survivor]).uniq
          remove_actions << build_remove_action(
            survivor_id:   survivor,
            removed_ids:   removed_ids,
            occurrence_id: occ,
            basis:         basis || BASIS_FORWARD_EXACT
          )
        end
        # Stable ordering: remove_actions by survivor_id asc,
        # skipped by issue_id asc (already sorted upstream).
        remove_actions.sort_by! { |a| a.before_summary['survivor_derived_id'].to_s }
        remove_actions + skipped
      end

      # Classify one duplicate issue. Returns:
        #   {valid: true, occurrence_id:, basis:} OR
        #   {valid: false, skipped_action: <RepairAction :skipped>}
      def classify_issue(issue, edge_lookup:, occ_to_deriveds:)
        edge_ids = issue.is_a?(Hash) ? issue[:edge_ids] : nil
        unless edge_ids.is_a?(Array) && edge_ids.length == 2
          return { valid: false, skipped_action: self_match_skipped(issue) }
        end
        ea = edge_lookup[Integer(edge_ids[0])] rescue nil
        eb = edge_lookup[Integer(edge_ids[1])] rescue nil
        if ea.nil? || eb.nil?
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_DERIVED_NOT_FOUND,
                     'no_edge_record_for_one_or_both_edge_ids') }
        end
        # Self-match.
        if Integer(edge_ids[0]) == Integer(edge_ids[1])
          return { valid: false, skipped_action: self_match_skipped(issue) }
        end
        # Endpoint exactness.
        kind, basis = endpoint_match_kind(ea, eb)
        if kind.nil?
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_NEAR_BUT_NOT_EXACT,
                     'endpoints coincide outside tolerance.duplicate; not an exact duplicate') }
        end
        # Provenance: same source occurrence required.
        occ_a = occurrence_id_for(ea)
        occ_b = occurrence_id_for(eb)
        if occ_a.nil? || occ_b.nil?
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_PROVENANCE_DIFFERS,
                     'no usable source occurrence id for one or both edges') }
        end
        if occ_a != occ_b
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_PROVENANCE_DIFFERS,
                     "source occurrences differ (#{occ_a.inspect} vs #{occ_b.inspect}); not an occurrence-level duplicate") }
        end
        # Same occurrence. Verify the workspace has 2+ derived
        # records for this occurrence (otherwise the pair is a
        # no-op / self-match).
        deriveds = occ_to_deriveds[occ_a.to_s] || []
        if deriveds.length < 2
          return { valid: false, skipped_action: self_match_skipped(issue) }
        end
        {
          valid:          true,
          occurrence_id:  occ_a.to_s,
          basis:          basis
        }
      end

      # Build edge_lookup: Hash<Integer, EdgeRecord>.
      def build_edge_lookup(source_snapshot)
        h = {}
        Array(source_snapshot.respond_to?(:edges) ? source_snapshot.edges : []).each do |e|
          if e.respond_to?(:id) && !e.id.nil?
            h[Integer(e.id)] = e
          end
        end
        h
      end

      # Build occ_to_deriveds: Hash<String, Array<derived_id>>.
      # Each V1.5 container-occurrence maps to ALL derived
      # records (potentially multiple) that originated from
      # source edges sharing that container. The workspace may
      # have 2+ derived records for the same V1.5
      # container-occurrence (the "duplicate within same parent
      # container" case -- the CAD-import artifact case).
      #
      # We reverse-parse each derived record's V1.4-format
      # source_occurrence_ids back into the canonical pid-path
      # Array, then derive the V1.5 container-occurrence by
      # excluding the leaf PID. This keeps the V1.4 contract
      # intact while letting the proposer match on the V1.5
      # identity.
      def build_occurrence_to_deriveds(workspace)
        h = {}
        return h if workspace.nil?
        Array(workspace.respond_to?(:entities) ? workspace.entities : []).each do |rec|
          Array(rec.respond_to?(:source_occurrence_ids) ? rec.source_occurrence_ids : []).each do |occ|
            pid_path = parse_v14_occurrence_to_container_path(occ.to_s)
            next if pid_path.nil? || pid_path.empty?
            key = container_occurrence_for_path(pid_path)
            next if key.nil?
            (h[key] ||= []) << rec.derived_id.to_s
          end
        end
        # Deduplicate and freeze lists (preserve insertion order).
        h.each_value { |list| list.uniq! }
        h
      end

      # Collect the duplicate_edge_candidate Issues from the
      # registry, sorted by issue_id (deterministic).
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

      # Determine whether two edges are exact (forward or
      # reversed) duplicates within tolerance.duplicate.
      def endpoint_match_kind(edge_a, edge_b)
        tol = read_duplicate_tolerance
        a_s = endpoint(edge_a, :start_point)
        a_e = endpoint(edge_a, :end_point)
        b_s = endpoint(edge_b, :start_point)
        b_e = endpoint(edge_b, :end_point)
        return [nil, nil] if a_s.nil? || a_e.nil? || b_s.nil? || b_e.nil?
        if points_within?(a_s, b_s, tol) && points_within?(a_e, b_e, tol)
          [:forward, BASIS_FORWARD_EXACT]
        elsif points_within?(a_s, b_e, tol) && points_within?(a_e, b_s, tol)
          [:reversed, BASIS_REVERSED_EXACT]
        else
          [nil, nil]
        end
      end

      # Read tolerance.duplicate from the EdgeRecord metadata
      # (DuplicateDetector writes it there). Fallback: 1.0e-4
      # inches (the conservative default per Tolerance.default).
      def read_duplicate_tolerance
        1.0e-4
      end

      # Extract a 3-Float endpoint Array from an EdgeRecord.
      def endpoint(edge, accessor)
        return nil unless edge.respond_to?(accessor)
        p = edge.send(accessor)
        return nil unless p.is_a?(Array) && p.length == 3
        return nil unless p.all? { |v| v.is_a?(Numeric) }
        [p[0].to_f, p[1].to_f, p[2].to_f]
      end

      # True iff two 3-Float points are within `tol` per axis.
      def points_within?(p, q, tol)
        return false unless p.is_a?(Array) && q.is_a?(Array) && p.length == 3 && q.length == 3
        (0..2).all? { |i| (p[i].to_f - q[i].to_f).abs <= tol.to_f }
      end

      # Derive the V1.5 CONTAINER-occurrence id from an
      # EdgeRecord's SourceReference.
      #
      # CONTRACT (per CodeX V1.5 BLOCK-003 recheck #2):
      # The canonical SourceReference.persistent_id_path
      # (V1.0-V1.4 contract) is NOT mutated. The V1.5
      # container-occurrence is a SEPARATE identity derived
      # here by excluding the leaf edge PID (the last
      # element of the canonical path). Two edges from the
      # SAME parent container (e.g., two duplicate edges
      # inside the same ComponentDefinition) share this
      # identity; two edges from DIFFERENT containers
      # (e.g., two ComponentInstances of the same definition)
      # have DIFFERENT identities.
      #
      # Top-level (root-level) edges: their container_path
      # would be empty after excluding the leaf. Per CodeX
      # fail-closed guidance, V1.5 Phase 1 EXCLUDES top-level
      # edges from auto-repair (returns nil). The repair is
      # only meaningful within a non-root container (a Group
      # or a ComponentInstance) where two duplicate edges
      # indicate a CAD-import artifact inside one parent.
      def occurrence_id_for(edge)
        return nil if edge.nil?
        src = edge.respond_to?(:source) ? edge.source : nil
        return nil if src.nil?
        pid_path = (src.respond_to?(:persistent_id_path) && src.persistent_id_path) ? src.persistent_id_path : nil
        ipath    = (src.respond_to?(:instance_path) && src.instance_path) ? src.instance_path : nil
        complete = src.respond_to?(:pid_path_complete) ? src.pid_path_complete : true
        quality  = complete ? 'occ' : 'transient-occ'
        # V1.5 container-occurrence: exclude the leaf PID
        # (last element). The canonical persistent_id_path
        # is read-only; we just slice it here.
        if pid_path.is_a?(Array) && pid_path.length >= 2
          container_path = pid_path[0..-2]
          return "#{quality}-container-#{container_path.map(&:to_s).join('>')}"
        elsif pid_path.is_a?(Array) && pid_path.length == 1
          # Root-level edge (pid_path = [leaf_pid], no
          # container). FAIL-CLOSED: no V1.5 repair.
          return nil
        elsif ipath.is_a?(Array) && !ipath.empty?
          # Fallback: instance_path only. The instance_path
          # also does NOT include the leaf PID (it's the
          # container path); so we can use it directly.
          # NOTE: instance_path is the LABEL path (String
          # entries), not the PID path; it identifies the
          # container uniquely within the source snapshot
          # but is NOT guaranteed stable across sessions.
          # We treat it as a transient V1.5 identity.
          "#{quality}-container-ipath-#{ipath.map(&:to_s).join('>')}"
        elsif edge.respond_to?(:id) && edge.id
          # Last-resort transient identity (analysis-local).
          # Two edges with this identity in the SAME analysis
          # would be merged; two in DIFFERENT analyses are
          # not (they get different ids).
          "transient-occ-container-edge-#{edge.id}"
        else
          nil
        end
      end

      # Reverse-parse a V1.4-format occurrence string (e.g.
      # "occ-100>200>300" or "occ-container-ipath-Group>Comp")
      # back into the container-pid-path Array (excluding the
      # leaf). Used by build_occurrence_to_deriveds to map
      # the workspace's V1.4 source_occurrence_ids into the
      # V1.5 container-occurrence keys for matching.
      #
      # Returns nil if the string is not parseable.
      def parse_v14_occurrence_to_container_path(occ_string)
        return nil if occ_string.nil? || !occ_string.is_a?(String)
        s = occ_string.to_s
        # Strip the quality prefix.
        rest = if s.start_with?('occ-')
                s[4..-1]
              elsif s.start_with?('transient-occ-')
                s[14..-1]
              else
                nil
              end
        return nil if rest.nil?
        # V1.5-prefixed (defensive: if the proposer itself
        # already wrote a container-prefixed id, just strip
        # the prefix and pass through).
        if rest.start_with?('container-')
          rest = rest[10..-1]
        end
        # Strip any ipath- prefix.
        if rest.start_with?('ipath-')
          return rest[6..-1].split('>')  # keep as-is; ipath is
                                          # already container-only
        end
        if rest.start_with?('container-ipath-')
          return rest[15..-1].split('>')
        end
        if rest.start_with?('container-edge-')
          return nil  # transient edge id; cannot extract container
        end
        # Otherwise, this is a V1.4 pid-path. The leaf PID is
        # the last element; we exclude it for the V1.5
        # container-occurrence.
        parts = rest.split('>').map { |x| Integer(x) rescue x }
        return nil if parts.length < 2
        # Exclude the leaf PID (last element).
        parts[0..-2]
      end

      # Compute the V1.5 container-occurrence from a parsed
      # pid-path Array. Centralized for symmetry with
      # occurrence_id_for.
      def container_occurrence_for_path(container_path, quality: 'occ')
        return nil if container_path.nil? || container_path.empty?
        "#{quality}-container-#{container_path.map(&:to_s).join('>')}"
      end

      # Build the :remove_duplicate_edge RepairAction (one per
      # occurrence).
      def build_remove_action(survivor_id:, removed_ids:, occurrence_id:, basis:)
        before_summary = {
          'survivor_derived_id' => survivor_id.to_s,
          'removed_derived_ids' => removed_ids.map(&:to_s).freeze,
          'duplicate_pairs'     => removed_ids.length
        }.freeze
        proposed_after_summary = {
          'survivor_derived_id' => survivor_id.to_s,
          'removed_derived_ids' => [].freeze,
          'duplicate_pairs'     => 0
        }.freeze
        RepairAction.new(
          type:                    ACTION_TYPE,
          rule_id:                 RULE_ID,
          confidence:              CONFIDENCE,
          confidence_basis:        basis.to_s,
          explanation:             "Exact duplicate edge (#{basis}); survivor keeps the lex-smaller derived_id; #{removed_ids.length} derived record(s) to remove.",
          source_occurrence_ids:   [occurrence_id.to_s].freeze,
          affected_derived_ids:    removed_ids.map(&:to_s).freeze,
          before_summary:          before_summary,
          proposed_after_summary:  proposed_after_summary,
          topology_impact:         TOPOLOGY_IMPACT,
          auto_applicable:         true,
          status:                  :proposed
        )
      end

      # Build a :skipped RepairAction (no removal) with the given
      # reason. The action still records the reason for the audit
      # trail.
      def skipped_action_for(issue, reason, explanation)
        eids = issue.is_a?(Hash) ? issue[:edge_ids] : nil
        RepairAction.new(
          type:                    ACTION_TYPE,
          rule_id:                 RULE_ID,
          confidence:              CONFIDENCE,
          confidence_basis:        "skipped:#{reason}",
          explanation:             explanation.to_s,
          source_occurrence_ids:   (eids.is_a?(Array) ? eids.map { |x| Integer(x) rescue x } : []).dup.freeze,
          affected_derived_ids:    [].freeze,
          before_summary:          { 'reason' => reason.to_s }.freeze,
          proposed_after_summary:  { 'reason' => reason.to_s }.freeze,
          topology_impact:         'no_op',
          auto_applicable:         true,
          status:                  :skipped
        )
      end

      # Self-match shortcut.
      def self_match_skipped(issue)
        skipped_action_for(issue, REASON_SELF_MATCH,
          'duplicate evidence references the same source edge twice; nothing to remove')
      end
    end
  end
end