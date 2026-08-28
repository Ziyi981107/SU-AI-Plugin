#
# core/duplicate_repair_proposer.rb — V1.5 Round-4
#
# Duplicate-candidate → RepairAction proposal.
#
# Round-4 changes (AIPM §2 + §3 + §4 + §6):
#
#   * Direct match predicate is delegated to
#     `DuplicateGeometrySemantics.direct_match?` (the SAME
#     function the detector, validator, and post-state use).
#   * Non-transitive topology (BLOCK-002B): the proposer's
#     destructive-action decision is based on connected-
#     component classification:
#       - REPAIRABLE component = complete graph under the
#         captured tolerance (every pair is a direct match).
#         Emit ONE action with deterministic survivor =
#         lex-smallest derived_id.
#       - NON-TRANSITIVE / INCOMPLETE component = the
#         component is connected but NOT a complete graph.
#         Emit NO destructive action; emit ONE inspectable
#         :skipped audit row with reason
#         `non_transitive_duplicate_component`; preserve
#         member IDs, issue IDs, source/provenance evidence.
#   * Bron-Kerbosch / maximal-clique enumeration is REMOVED
#     from the destructive-action path. It is retained only
#     as a diagnostic helper in DerivedDuplicateTopology.
#   * Final action eligibility / live-handle proof (BLOCK-001):
#     BEFORE any executable action is emitted, the COMPLETE
#     final repairable component must pass:
#       - every member has one distinct derived_id
#       - every member resolves to one unambiguous current
#         source-edge identity for V1.5 action membership
#       - every member has a current host handle
#       - every handle is live/valid
#       - every handle is distinct
#       - survivor handle and removal handles are disjoint
#       - member identity/provenance belongs to the current
#         SourceSnapshot
#       - layer/tolerance/finite-coordinate guards pass
#       - no repeated/aliased member exists
#     Failure => emit a truthful :skipped audit row with a
#     stable reason code.
#
# Per AIPM §9 (Implementation boundary):
#   - Pi may refactor local helpers required to realize it.
#   - Pi must NOT invent a different non-transitive merge
#     policy or keep partial maximal-clique destructive
#     repair.
#

require 'digest'
require_relative 'repair_plan'
require_relative 'derived_entity_record'
require_relative 'duplicate_geometry_semantics'
require_relative 'derived_duplicate_topology'

module SUAnalysis
  module Core
    module DuplicateRepairProposer
      module_function

      RULE_ID         = 'duplicate_edge.exact_remove'.freeze
      ACTION_TYPE     = :remove_duplicate_edge
      CONFIDENCE      = 1.0

      BASIS_FORWARD_EXACT  = 'exact_endpoint_match_within_tolerance.duplicate'.freeze
      BASIS_REVERSED_EXACT = 'reversed_endpoint_match_within_tolerance.duplicate'.freeze

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
      REASON_INVALID_CAPTURED_TOLERANCE = 'invalid_or_missing_captured_tolerance'.freeze
      REASON_NON_DISTINCT_SOURCE     = 'duplicate_evidence_repeated_source_edge'.freeze
      REASON_MISSING_EDGE_RECORD     = 'no_edge_record_for_one_or_both_edge_ids'.freeze
      REASON_NO_DERIVED_FOR_ISSUE    = 'no_derived_records_resolve_to_issue_source_edges'.freeze
      REASON_AMBIGUOUS_RESOLUTION    = 'ambiguous_source_edge_resolution'.freeze
      REASON_BUCKET_BOUNDARY         = 'bucket_boundary_split'.freeze
      REASON_NON_TRANSITIVE_COMPONENT = 'non_transitive_duplicate_component'.freeze
      REASON_HANDLE_ALIAS            = 'host_handle_aliasing'.freeze
      REASON_HANDLE_MISSING          = 'host_handle_missing'.freeze
      REASON_HANDLE_INVALID          = 'host_handle_invalidated'.freeze

      DEFAULT_LAYER_CANONICAL = 'Layer0'.freeze
      DEFAULT_DUPLICATE_TOLERANCE = 1.0e-4

      # ===========================================================
      # Public API
      # ===========================================================

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
      # Direct matcher (Round-4 SHARED with detector/validator/
      # post-state via DuplicateGeometrySemantics).
      # ===========================================================
      def direct_match?(pa_s, pa_e, pb_s, pb_e, layer_a, layer_b, tolerance)
        DuplicateGeometrySemantics.direct_match?(pa_s, pa_e, pb_s, pb_e,
                                                  layer_a, layer_b, tolerance)
      end

      # ===========================================================
      # build_actions — main pipeline
      # ===========================================================
      def build_actions(source_snapshot:, registry:, workspace:)
        tolerance    = resolve_tolerance(source_snapshot, workspace)
        unless DuplicateGeometrySemantics.valid_tolerance?(tolerance)
          # Per FIX-SR-03: missing / invalid captured
          # tolerance must use a truthful reason code
          # (`invalid_or_missing_captured_tolerance`). The
          # endpoint-geometry reason (`non_finite_endpoint_coordinates`)
          # is reserved for actual coordinate failures and
          # is semantically false for a missing / invalid
          # configuration. V1.5 auto-repair remains disabled
          # in both cases (fail-closed).
          issue_id = 'config|invalid_captured_tolerance'
          return [skipped_action_for(
            { issue_id: issue_id, edge_ids: [] },
            REASON_INVALID_CAPTURED_TOLERANCE,
            'V1.5 auto-repair disabled: captured duplicate tolerance is missing or invalid'
          )]
        end
        edge_lookup  = build_edge_lookup(source_snapshot)
        issues       = collect_duplicate_candidates(registry)
        # Step 1: per-issue guards.
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

        # Step 2: for each issue, find the derived records whose
        # source EdgeRecord resolves to one of {ea, eb} AND
        # whose geometry directly matches the OTHER edge.
        per_class = []
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
          # Step 3: full leaf/occurrence identity verification
          # (per-issue local). This is the per-issue verify;
          # the FINAL repairable component is verified again in
          # Step 6 after topology classification.
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

        # Step 4: union the per-class candidate sets into the
        # workspace's full derived-record set and classify
        # components via the shared topology decision.
        candidate_tuples = build_candidate_tuples(per_class)
        classification = classify_topology(candidate_tuples, tolerance)
        # Step 5: emit :skipped rows for NON-TRANSITIVE
        # components (one inspectable row per component,
        # preserving member IDs, issue IDs, source/provenance).
        classification[:non_transitive_components].each do |c|
          member_ids = c[:member_tuples].map { |t| t[:derived_id].to_s }.sort
          primary_issue_id = primary_issue_id_for(c[:member_tuples], per_class)
          primary_edge_ids = primary_edge_ids_for(c[:member_tuples], per_class)
          all_issue_ids = all_issue_ids_for(c[:member_tuples], per_class)
          skipped << skipped_action_for(
            { issue_id: primary_issue_id, edge_ids: primary_edge_ids },
            REASON_NON_TRANSITIVE_COMPONENT,
            "BLOCK-002B non-transitive duplicate component (member_count=#{member_ids.length}, direct_pair_count=#{c[:direct_pair_count]}, required_pair_count=#{c[:required_pair_count]}, missing_pair_count=#{c[:missing_pair_count]}); member_derived_ids=#{member_ids.inspect}; issue_ids=#{all_issue_ids.inspect}; no destructive repair; geometry preserved."
          )
        end
        # Step 6: for each REPAIRABLE component (complete
        # graph), run the FINAL eligibility proof before
        # emitting any action. The proof checks distinct
        # derived_id, full occurrence/leaf identity, distinct
        # live handles, survivor/removed disjointness, layer /
        # tolerance / finite-coordinate guards. Failure => emit
        # a truthful :skipped audit row with the failure reason.
        applied = []
        classification[:repairable_components].each do |member_tuples|
          member_records = member_tuples.map { |t|
            t[:record]
          }.compact
          # Determine the issue/edge evidence for this component.
          issue_id = primary_issue_id_for(member_tuples, per_class)
          edge_ids = primary_edge_ids_for(member_tuples, per_class)
          all_issue_ids = all_issue_ids_for(member_tuples, per_class)
          member_derived_ids = member_records.map { |d| d.derived_id.to_s }.sort
          sorted_ids = member_derived_ids.dup
          survivor_id = sorted_ids.first
          removed_ids = sorted_ids[1..] || []
          # Round-4 BLOCK-002: derive the BASIS KIND for the
          # action from the survivor-vs-next-member geometric
          # relationship. The canonical class is orientation-
          # independent (any direction qualifies as a duplicate
          # edge) but the BASIS string the action reports must
          # reflect the actual endpoint ordering. We compute it
          # once per repairable component so the audit can
          # distinguish forward exact from reversed exact
          # collisions.
          basis_kind = repairable_component_basis_kind(
            member_records: member_records,
            survivor_id:    survivor_id,
            tolerance:      tolerance
          )
          # Provisional action for the verify call.
          provisional = provisional_action(
            survivor_id:     survivor_id,
            removed_ids:     removed_ids,
            issue_id:        issue_id,
            edge_ids:        edge_ids,
            all_issue_ids:   all_issue_ids,
            basis_kind:      basis_kind,
            source_snapshot: source_snapshot,
            edge_lookup:     edge_lookup,
            member_records:  member_records
          )
          verify = verify_final_repairable_component(
            members:         member_records,
            survivor_id:     survivor_id,
            removed_ids:     removed_ids,
            source_snapshot: source_snapshot,
            edge_lookup:     edge_lookup,
            workspace:       workspace
          )
          unless verify[:valid]
            skipped << skipped_action_for(
              { issue_id: issue_id, edge_ids: edge_ids },
              verify[:reason_code],
              "#{verify[:reason]}; member_derived_ids=#{member_derived_ids.inspect}; issue_ids=#{all_issue_ids.inspect}"
            )
            next
          end
          applied << provisional
        end

        # Deterministic ordering: applied by action_id asc;
        # skipped by issue_id asc.
        applied.sort_by! { |a| a.action_id.to_s }
        skipped.sort_by! { |a| (a.before_summary['issue_id'] || '').to_s }
        applied + skipped
      end

      # ===========================================================
      # Layer / numeric helpers
      # ===========================================================
      def normalize_layer(name)
        DuplicateGeometrySemantics.normalize_layer(name)
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

      # Read the captured duplicate tolerance from a source
      # snapshot. Per FIX-A: missing/invalid/non-numeric
      # captured tolerance returns NIL, NOT a runtime
      # fallback to DEFAULT_DUPLICATE_TOLERANCE. Production
      # callers (the proposer and the audit summary) MUST
      # treat nil as "no V1.5 auto-repair" or "no pair
      # metric under missing tolerance".
      def read_duplicate_tolerance(source_snapshot)
        return nil if source_snapshot.nil?
        ec = source_snapshot.respond_to?(:execution_config) ? source_snapshot.execution_config : nil
        return nil if ec.nil?
        vals = ec.respond_to?(:tolerance_values) ? ec.tolerance_values : nil
        return nil unless vals.is_a?(Hash)
        v = vals[:duplicate] || vals['duplicate']
        return nil if v.nil?
        DuplicateGeometrySemantics.parse_strict_tolerance(v)
      end

      # Resolve captured tolerance. Captured wins; if the
      # workspace cannot supply a captured value, fall back
      # to the source snapshot's execution_config. Per FIX-A:
      # missing/invalid captured tolerance returns NIL, NOT
      # DEFAULT_DUPLICATE_TOLERANCE.
      def resolve_tolerance(source_snapshot, workspace)
        cap = DuplicateGeometrySemantics.resolve_captured_tolerance(workspace)
        return cap if cap
        # Last-resort: read from source snapshot directly.
        ec = source_snapshot.respond_to?(:execution_config) ? source_snapshot.execution_config : nil
        if ec
          vals = ec.respond_to?(:tolerance_values) ? ec.tolerance_values : nil
          if vals.is_a?(Hash)
            v = vals[:duplicate] || vals['duplicate']
            return DuplicateGeometrySemantics.parse_strict_tolerance(v) unless v.nil?
          end
        end
        nil
      end

      def finite_point?(p)
        DuplicateGeometrySemantics.finite_point?(p)
      end

      def finite_float_triple(p)
        DuplicateGeometrySemantics.finite_float_triple(p)
      end

      def points_within?(p, q, tol)
        DuplicateGeometrySemantics.points_within?(p, q, tol)
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
      # Edge lookup / issue classification
      # ===========================================================
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

      def classify_issue(issue, edge_lookup:, tolerance:)
        edge_ids = issue.is_a?(Hash) ? issue[:edge_ids] : nil
        unless edge_ids.is_a?(Array) && edge_ids.length == 2
          return { valid: false, skipped_action: self_match_skipped(issue) }
        end
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
        unless finite_point?(ea.start_point) && finite_point?(ea.end_point) &&
               finite_point?(eb.start_point) && finite_point?(eb.end_point)
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_NON_FINITE_COORDS,
                     'one or more endpoint coordinates are not finite') }
        end
        layer_a = normalize_layer(layer_name_of(ea))
        layer_b = normalize_layer(layer_name_of(eb))
        if layer_a != layer_b
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_LAYER_MISMATCH,
                     "different normalized layer names: #{layer_a.inspect} vs #{layer_b.inspect}") }
        end
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

      def self_match_skipped(issue)
        skipped_action_for(issue, REASON_SELF_MATCH,
          'duplicate evidence references the same source edge twice; nothing to remove')
      end

      # ===========================================================
      # find_class_for_issue (BLOCK-001 per-issue eligibility).
      # ===========================================================
      def find_class_for_issue(workspace:, ea:, eb:, tolerance:)
        return nil if workspace.nil? || ea.nil? || eb.nil?
        entities = workspace.respond_to?(:entities) ? workspace.entities : []
        return nil if entities.empty?
        ea_id = int(ea.id)
        eb_id = int(eb.id)
        ea_layer = layer_name_of(ea)
        eb_layer = layer_name_of(eb)
        ea_path = ea.respond_to?(:source) && ea.source.respond_to?(:persistent_id_path) ?
                    ea.source.persistent_id_path : nil
        eb_path = eb.respond_to?(:source) && eb.source.respond_to?(:persistent_id_path) ?
                    eb.source.persistent_id_path : nil
        return nil if ea_path.nil? || eb_path.nil?
        candidate_records = []
        entities.each do |d|
          next unless d.is_a?(DerivedEntityRecord)
          next unless d.kind == :edge
          occ_ids = Array(d.source_occurrence_ids).map(&:to_s)
          next if occ_ids.empty?
          record_path = source_path_from_occ_ids(occ_ids.first)
          next if record_path.nil?
          if record_path == ea_path
            kind = direct_match?(
              start_finish_of(d)[0], start_finish_of(d)[1],
              eb.start_point, eb.end_point,
              layer_of(d), eb_layer, tolerance
            )
            if kind == :forward || kind == :reversed
              candidate_records << { record: d, source_edge_id: ea_id, kind: kind }
            end
          elsif record_path == eb_path
            kind = direct_match?(
              start_finish_of(d)[0], start_finish_of(d)[1],
              ea.start_point, ea.end_point,
              layer_of(d), ea_layer, tolerance
            )
            if kind == :forward || kind == :reversed
              candidate_records << { record: d, source_edge_id: eb_id, kind: kind }
            end
          else
            next
          end
        end
        source_edge_ids = candidate_records.map { |c| c[:source_edge_id] }.uniq
        if source_edge_ids.length != candidate_records.length
          return nil
        end
        members = candidate_records.map { |c| c[:record] }
        {
          members:         members,
          source_edge_ids: source_edge_ids
        }
      end

      # ===========================================================
      # verify_class_identity (BLOCK-001 per-issue leaf identity).
      # ===========================================================
      def verify_class_identity(members:, ea:, eb:, source_snapshot:, edge_lookup:, issue:, workspace: nil)
        return { valid: false,
                 skipped_action: skipped_action_for(issue, REASON_INCOMPLETE_PROVENANCE,
                   'class has no members') } if members.nil? || members.empty?
        return { valid: false,
                 skipped_action: skipped_action_for(issue, REASON_INCOMPLETE_PROVENANCE,
                   'class has fewer than 2 members (not a duplicate)') } if members.length < 2
        uniq_derived_ids = members.map { |d| d.derived_id.to_s }.uniq
        if uniq_derived_ids.length != members.length
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_DERIVED_NOT_FOUND,
                     'duplicate derived_id inside the class; ambiguity fails closed') }
        end
        incomplete = members.select { |d| Array(d.source_occurrence_ids).empty? }
        unless incomplete.empty?
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_INCOMPLETE_PROVENANCE,
                     'one or more derived records have empty source_occurrence_ids; fail-closed') }
        end
        resolved_ids      = []
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
                       "duplicate derived record #{d.derived_id.inspect} resolves to #{matches.length} source EdgeRecord(s) (expected exactly 1); fail-closed") }
          end
          ref = matches.first.respond_to?(:source) ? matches.first.source : nil
          if ref.nil? || (ref.respond_to?(:pid_path_complete) && !ref.pid_path_complete)
            return { valid: false,
                     skipped_action: skipped_action_for(issue, REASON_INCOMPLETE_PROVENANCE,
                       "duplicate derived record #{d.derived_id.inspect} resolves to a source reference with pid_path_complete=false; fail-closed") }
          end
          resolved_ids << int(matches.first.id)
        end
        if resolved_ids.uniq.length != resolved_ids.length
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_NON_DISTINCT_SOURCE,
                     'two or more class members resolve to the same source EdgeRecord; fail-closed') }
        end
        unless resolved_ids.include?(int(ea.id)) || resolved_ids.include?(int(eb.id))
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_AMBIGUOUS_RESOLUTION,
                     "class members resolve to source edges #{resolved_ids.inspect} which do not include the issue's source edges #{[ea.id, eb.id].inspect}; fail-closed") }
        end
        { valid: true }
      end

      # ===========================================================
      # Topology classification (BLOCK-002B).
      # ===========================================================
      #
      # Build the per-class candidate tuples (each tuple
      # carries its DerivedEntityRecord) and delegate to
      # DerivedDuplicateTopology.classify_components. The
      # result is:
      #   - repairable_components:  Array<Array<tuple>> whose
      #                              graph is COMPLETE.
      #   - non_transitive_components: Array<Hash> with
      #                              member_tuples + counts.
      def build_candidate_tuples(per_class)
        tuples = []
        per_class.each do |c|
          c[:members].each do |d|
            geom = d.respond_to?(:geometry_summary) ? d.geometry_summary : nil
            next unless geom.is_a?(Hash)
            s = geom['start'] || geom[:start]
            f = geom['end']   || geom[:end]   || geom['finish']
            l = geom['layer'] || geom[:layer]
            next unless DuplicateGeometrySemantics.finite_point?(s) && DuplicateGeometrySemantics.finite_point?(f)
            tuples << {
              derived_id: d.derived_id.to_s,
              start:      s,
              finish:     f,
              layer:      l,
              record:     d
            }
          end
        end
        # De-duplicate by derived_id (a record may appear in
        # multiple per_class buckets; we keep one tuple per
        # derived_id).
        seen = {}
        unique = tuples.select { |t|
          k = t[:derived_id]
          next false if seen[k]
          seen[k] = true
          true
        }
        unique
      end

      def classify_topology(candidate_tuples, tolerance)
        return { repairable_components: [], non_transitive_components: [] } if candidate_tuples.length < 2
        classified = DerivedDuplicateTopology.classify_components(candidate_tuples, tolerance)
        repairable = classified[:repairable_components].map { |idxs|
          idxs.map { |i| candidate_tuples[i] }
        }
        non_transitive = classified[:non_transitive_components]
        {
          repairable_components:    repairable,
          non_transitive_components: non_transitive
        }
      end

      # ===========================================================
      # FINAL repairable-component eligibility proof (BLOCK-001).
      # ===========================================================
      #
      # Called for EVERY candidate repairable component BEFORE
      # any executable action is created. Per AIPM §2:
      #
      #   1.  every member has one distinct derived_id
      #   2.  every member resolves to one unambiguous current
      #       source-edge identity for V1.5 action membership
      #   3.  every member has a current host handle
      #   4.  every handle is live/valid
      #   5.  every handle is distinct
      #   6.  survivor handle and removal handles are disjoint
      #   7.  member identity/provenance belongs to the current
      #       SourceSnapshot
      #   8.  layer / tolerance / finite-coordinate guards pass
      #   9.  no repeated/aliased member exists
      #
      # Failure => emit a truthful :skipped audit row with a
      # stable reason code (REASON_HANDLE_ALIAS /
      # REASON_HANDLE_MISSING / REASON_HANDLE_INVALID /
      # REASON_AMBIGUOUS_RESOLUTION / etc.).
      def verify_final_repairable_component(members:, survivor_id:, removed_ids:,
                                             source_snapshot:, edge_lookup:,
                                             workspace:)
        return { valid: false, reason: 'no_members', reason_code: REASON_INCOMPLETE_PROVENANCE } if members.nil? || members.length < 2
        # (1) Distinct derived_id.
        ids = members.map { |d| d.derived_id.to_s }
        if ids.uniq.length != ids.length
          return { valid: false, reason: 'duplicate derived_id inside the merged class', reason_code: REASON_DERIVED_NOT_FOUND }
        end
        # (2) Each member has full leaf identity.
        incomplete = members.select { |d| Array(d.source_occurrence_ids).empty? }
        unless incomplete.empty?
          return { valid: false, reason: 'one or more derived records have empty source_occurrence_ids', reason_code: REASON_INCOMPLETE_PROVENANCE }
        end
        # (2b) Each member resolves to EXACTLY one source
        # EdgeRecord in the current SourceSnapshot (full
        # occurrence/leaf identity). pid_path_complete=true.
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
                     reason: "duplicate derived record #{d.derived_id.inspect} resolves to #{matches.length} source EdgeRecord(s) (expected exactly 1); fail-closed",
                     reason_code: REASON_AMBIGUOUS_RESOLUTION }
          end
          ref = matches.first.respond_to?(:source) ? matches.first.source : nil
          if ref.nil? || (ref.respond_to?(:pid_path_complete) && !ref.pid_path_complete)
            return { valid: false,
                     reason: "duplicate derived record #{d.derived_id.inspect} resolves to a source reference with pid_path_complete=false; fail-closed",
                     reason_code: REASON_INCOMPLETE_PROVENANCE }
          end
          resolved_ids << int(matches.first.id)
        end
        if resolved_ids.uniq.length != resolved_ids.length
          return { valid: false, reason: 'two or more class members resolve to the same source EdgeRecord', reason_code: REASON_NON_DISTINCT_SOURCE }
        end
        # (8) Layer / finite-coordinate guards.
        members.each do |d|
          s, f = start_finish_of(d)
          unless finite_point?(s) && finite_point?(f)
            return { valid: false, reason: "duplicate derived record #{d.derived_id.inspect} has non-finite coordinates", reason_code: REASON_NON_FINITE_COORDS }
          end
        end
        # (3,4,5,6) Live-handle uniqueness + survivor
        # disjointness. Only when the workspace is supplied.
        # Per FIX-C: a destructive batch member is live only
        # when the handle is non-nil, exposes `valid?`, and
        # `valid? == true` without raising. A handle that
        # lacks `valid?`, returns nil from `valid?`, returns
        # false from `valid?`, or RAISES while checking
        # validity must NOT be treated as proven live.
        if !workspace.nil? && workspace.respond_to?(:handle_for)
          live_handles = {}
          members.each do |d|
            h = workspace.handle_for(d.derived_id.to_s)
            unless DuplicateGeometrySemantics.strict_handle_live?(h)
              if h.nil?
                return { valid: false,
                         reason: "duplicate derived record #{d.derived_id.inspect} has no live host handle (missing)",
                         reason_code: REASON_HANDLE_MISSING }
              end
              # Distinguish INVALID (handle exists but is no
              # longer live/valid) from MALFORMED (handle does
              # not expose `valid?` or `valid?` raises).
              if h.respond_to?(:valid?)
                return { valid: false,
                         reason: "duplicate derived record #{d.derived_id.inspect} has an invalidated live host handle",
                         reason_code: REASON_HANDLE_INVALID }
              else
                return { valid: false,
                         reason: "duplicate derived record #{d.derived_id.inspect} host handle does not expose valid? (BLOCK-001 fail-closed)",
                         reason_code: REASON_HANDLE_INVALID }
              end
            end
            if live_handles.values.any? { |prev| prev.equal?(h) }
              return { valid: false,
                       reason: "distinct duplicate records alias to the same live host handle (BLOCK-001 host-aliasing): #{d.derived_id.inspect}",
                       reason_code: REASON_HANDLE_ALIAS }
            end
            live_handles[d.derived_id.to_s] = h
          end
          # Survivor disjointness.
          survivor_handle = live_handles[survivor_id]
          removed_ids.each do |rid|
            rh = live_handles[rid]
            next if rh.nil?
            if rh.equal?(survivor_handle)
              return { valid: false,
                       reason: "survivor #{survivor_id.inspect} shares its live host handle with to-remove member #{rid.inspect}; deleting the survivor would erase the survivor too (BLOCK-001 fail-closed)",
                       reason_code: REASON_HANDLE_ALIAS }
            end
          end
        end
        # (7) Identity/provenance belongs to the current
        # SourceSnapshot. The edge_lookup is built from the
        # current SourceSnapshot, so the resolution above is
        # already a current-snapshot check.
        # (9) No repeated/aliased member. Already covered by
        # the derived_id uniqueness check + source edge
        # resolution + live-handle uniqueness.
        { valid: true }
      end

      # ===========================================================
      # Repairable-component BASIS-KIND derivation.
      # ===========================================================
      #
      # The action's `confidence_basis` string distinguishes a
      # forward-exact duplicate from a reversed-exact duplicate.
      # The canonical class is orientation-independent (both
      # forms qualify) but the audit must reflect the actual
      # endpoint ordering observed in this component.
      #
      # Strategy: pick the survivor (lex-smallest derived_id)
      # and any other member with finite endpoints; call the
      # shared DuplicateGeometrySemantics.direct_match? to
      # decide :forward or :reversed. When the survivor has
      # fewer than 2 finite members (rare defensive case),
      # default to :forward.
      def repairable_component_basis_kind(member_records:, survivor_id:, tolerance:)
        return :forward if member_records.nil? || member_records.length < 2
        survivor_rec = member_records.find { |d| d.derived_id.to_s == survivor_id.to_s }
        others = member_records.reject { |d| d.derived_id.to_s == survivor_id.to_s }
        return :forward if survivor_rec.nil?
        survivor_s, survivor_f = start_finish_of(survivor_rec)
        return :forward unless finite_point?(survivor_s) && finite_point?(survivor_f)
        layer_s = layer_of(survivor_rec)
        # Try each other member in deterministic order; the
        # FIRST match (by derived_id ascending) wins.
        others_sorted = others.sort_by { |d| d.derived_id.to_s }
        others_sorted.each do |o|
          os, ofv = start_finish_of(o)
          next unless finite_point?(os) && finite_point?(ofv)
          kind = direct_match?(survivor_s, survivor_f, os, ofv, layer_s, layer_of(o), tolerance)
          return kind if kind == :forward || kind == :reversed
        end
        :forward
      end

      # ===========================================================
      # Action builders
      # ===========================================================
      def provisional_action(survivor_id:, removed_ids:, issue_id:, edge_ids:, all_issue_ids:,
                             basis_kind:, source_snapshot:, edge_lookup:, member_records:)
        provenance_union = member_records
                             .flat_map { |d| Array(d.source_occurrence_ids).map(&:to_s) }
                             .uniq
                             .sort
        snapshot_id = source_snapshot.respond_to?(:snapshot_id) ? source_snapshot.snapshot_id.to_s : ''
        canonical_key = canonical_geometry_key(
          start:  start_finish_of(member_records.first)[0],
          finish: start_finish_of(member_records.first)[1],
          layer:  layer_of(member_records.first),
          tolerance: DEFAULT_DUPLICATE_TOLERANCE
        )
        basis_str = basis_kind == :reversed ? BASIS_REVERSED_EXACT : BASIS_FORWARD_EXACT
        action_id = deterministic_action_id(
          rule_id:           RULE_ID,
          snapshot_id:       snapshot_id,
          canonical_key:     canonical_key,
          sorted_member_ids: member_records.map { |d| d.derived_id.to_s }.sort
        )
        before_summary = {
          'survivor_derived_id'        => survivor_id.to_s,
          'removed_derived_ids'        => removed_ids.map(&:to_s).freeze,
          'duplicate_pairs'            => (removed_ids.length),
          'canonical_endpoint_summary' => canonical_endpoint_summary(canonical_key),
          'layer'                      => layer_from_canonical_key(canonical_key),
          'before_edge_count'          => member_records.length,
          'proposed_after_edge_count'  => 1,
          'issue_ids'                  => Array(all_issue_ids).map(&:to_s).sort.freeze,
          'primary_issue_id'           => issue_id.to_s
        }.freeze
        proposed_after_summary = {
          'survivor_derived_id'        => survivor_id.to_s,
          'removed_derived_ids'        => [].freeze,
          'duplicate_pairs'            => 0,
          'canonical_endpoint_summary' => canonical_endpoint_summary(canonical_key),
          'layer'                      => layer_from_canonical_key(canonical_key),
          'before_edge_count'          => member_records.length,
          'proposed_after_edge_count'  => 1
        }.freeze
        explanation = build_explanation(
          basis:           basis_str,
          member_count:    member_records.length,
          source_occ_count: provenance_union.length
        )
        RepairAction.new(
          action_id:               action_id,
          type:                    ACTION_TYPE,
          rule_id:                 RULE_ID,
          confidence:              CONFIDENCE,
          confidence_basis:        basis_str,
          explanation:             explanation,
          source_occurrence_ids:   provenance_union.freeze,
          affected_derived_ids:    removed_ids.map(&:to_s).freeze,
          before_summary:          before_summary,
          proposed_after_summary:  proposed_after_summary,
          topology_impact:         TOPOLOGY_IMPACT,
          auto_applicable:         true,
          status:                  :proposed
        )
      end

      def build_remove_action_for_class(c)
        members = c[:members]
        sorted_ids = members.map { |d| d.derived_id.to_s }.sort
        survivor_id = sorted_ids.first
        removed_ids = sorted_ids[1..] || []
        provenance_union = members
                             .flat_map { |d| Array(d.source_occurrence_ids).map(&:to_s) }
                             .uniq
                             .sort
        issue_ids = Array(c[:issue_ids]).map(&:to_s).sort
        canonical_key = canonical_geometry_key(
          start:  start_finish_of(members.first)[0],
          finish: start_finish_of(members.first)[1],
          layer:  layer_of(members.first),
          tolerance: DEFAULT_DUPLICATE_TOLERANCE
        )
        basis_str = c[:basis_kind] == :reversed ? BASIS_REVERSED_EXACT : BASIS_FORWARD_EXACT
        snapshot_id = c[:ea].respond_to?(:id) ? int(c[:ea].id).to_s : ''
        action_id = deterministic_action_id(
          rule_id:           RULE_ID,
          snapshot_id:       snapshot_id,
          canonical_key:     canonical_key,
          sorted_member_ids: sorted_ids
        )
        before_summary = {
          'survivor_derived_id'        => survivor_id.to_s,
          'removed_derived_ids'        => removed_ids.map(&:to_s).freeze,
          'duplicate_pairs'            => removed_ids.length,
          'canonical_endpoint_summary' => canonical_endpoint_summary(canonical_key),
          'layer'                      => layer_from_canonical_key(canonical_key),
          'before_edge_count'          => members.length,
          'proposed_after_edge_count'  => 1,
          'issue_ids'                  => issue_ids.freeze
        }.freeze
        proposed_after_summary = {
          'survivor_derived_id'        => survivor_id.to_s,
          'removed_derived_ids'        => [].freeze,
          'duplicate_pairs'            => 0,
          'canonical_endpoint_summary' => canonical_endpoint_summary(canonical_key),
          'layer'                      => layer_from_canonical_key(canonical_key),
          'before_edge_count'          => members.length,
          'proposed_after_edge_count'  => 1
        }.freeze
        explanation = build_explanation(
          basis:           basis_str,
          member_count:    members.length,
          source_occ_count: provenance_union.length
        )
        RepairAction.new(
          action_id:               action_id,
          type:                    ACTION_TYPE,
          rule_id:                 RULE_ID,
          confidence:              CONFIDENCE,
          confidence_basis:        basis_str,
          explanation:             explanation,
          source_occurrence_ids:   provenance_union.freeze,
          affected_derived_ids:    removed_ids.map(&:to_s).freeze,
          before_summary:          before_summary,
          proposed_after_summary:  proposed_after_summary,
          topology_impact:         TOPOLOGY_IMPACT,
          auto_applicable:         true,
          status:                  :proposed
        )
      end

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

      def build_explanation(basis:, member_count:, source_occ_count:)
        basis_kind = basis.to_s.start_with?('reversed') ? 'reversed exact' : 'forward exact'
        survivor_count = 1
        removed_count  = member_count - survivor_count
        "Exact duplicate edge (#{basis_kind}); #{member_count} source occurrences converge on one canonical derived segment; survivor keeps the lex-smallest derived_id; #{removed_count} derived record(s) to remove; provenance union size = #{source_occ_count}."
      end

      # ===========================================================
      # Per-component evidence aggregation.
      # ===========================================================
      def primary_issue_id_for(tuples, per_class)
        tuple_ids = tuples.map { |t| t[:derived_id].to_s }
        per_class.each do |c|
          next unless c[:members].any? { |d| tuple_ids.include?(d.derived_id.to_s) }
          return issue_id_of(c[:issue])
        end
        ''
      end

      def primary_edge_ids_for(tuples, per_class)
        tuple_ids = tuples.map { |t| t[:derived_id].to_s }
        per_class.each do |c|
          next unless c[:members].any? { |d| tuple_ids.include?(d.derived_id.to_s) }
          return c[:source_edge_ids].map { |x| int(x) }.compact
        end
        []
      end

      def all_issue_ids_for(tuples, per_class)
        tuple_ids = tuples.map { |t| t[:derived_id].to_s }
        seen = {}
        out = []
        per_class.each do |c|
          next unless c[:members].any? { |d| tuple_ids.include?(d.derived_id.to_s) }
          iid = issue_id_of(c[:issue])
          unless seen[iid]
            seen[iid] = true
            out << iid
          end
        end
        out.sort
      end
    end
  end
end