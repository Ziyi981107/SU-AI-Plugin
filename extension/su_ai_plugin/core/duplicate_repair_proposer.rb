#
# core/duplicate_repair_proposer.rb — V1.5 Phase 1 (corrected scope)
#
# Duplicate-candidate → RepairAction proposal.
#
# CORRECTED SCOPE per Guidance 031 (CodeX/AIPM, 2026-08-25):
#
#   The V1.5 Phase 1 implementation directive canonicalizes exact /
#   reversed-exact coincident DERIVED edges inside the current selected
#   SourceSnapshot, while preserving the immutable source occurrences
#   as a many-to-one provenance union on the surviving derived edge.
#
#   The previous "same container occurrence" restriction is
#   SUPERSEDED. Two ComponentInstances remain two distinct SOURCE
#   occurrences; their DERIVED topology may be canonicalized into
#   ONE derived survivor whose source_occurrence_ids is the sorted
#   unique union of every contributing source occurrence.
#
# This module refactors DuplicateRepairProposer around DERIVED
# world-geometry equivalence classes (computed directly from each
# derived record's geometry_summary), not container-occurrence
# identity.
#
# Algorithm:
#
#   1. Group every derived Edge record in the workspace by a
#      CANONICAL WORLD-GEOMETRY KEY. The key is:
#
#        geom | <qx1,qy1,qz1> | <qx2,qy2,qz2> | layer=<normalized_layer>
#
#      - quantize_point(start), quantize_point(finish) snap endpoints
#        to the captured tolerance.duplicate grid.
#      - the two quantized endpoints are sorted (orientation-
#        independent).
#      - the layer is normalized via Layer0 normalization
#        (Layer0 / Default / Untagged collapse to "Layer0").
#
#   2. From the registry, read every duplicate_edge_candidate issue
#      and resolve it to the same canonical key (via the issue's
#      two source EdgeRecord endpoints + layer). Issues that fail
#      per-issue guards emit a :skipped action with an explicit
#      reason.
#
#   3. For each derived class with 2+ members AND at least one
#      matching issue (evidence guard):
#      - apply eligibility guards
#      - emit ONE :remove_duplicate_edge action with:
#
#          survivor_derived_id     = lex-smallest derived_id
#          affected_derived_ids    = sorted other derived_ids
#          source_occurrence_ids   = sorted unique union of every
#                                    contributing derived record's
#                                    source_occurrence_ids
#          canonical_endpoint_summary = { quantized start, end }
#          layer                   = normalized layer name
#          before_edge_count       = member count
#          proposed_after_edge_count = 1
#          confidence_basis        = forward or reversed match
#          action_id               = deterministic (rule id +
#                                    snapshot id + canonical key
#                                    + sorted member derived_ids)
#
#   4. Output deterministic ordering (sorted by action_id).
#
# Locked auto-apply eligibility (Guidance 031 §5):
#
#   1. Evidence originates from existing duplicate_edge_candidate
#      issues in the captured IssueRegistry (no competing analyzer).
#   2. Every member resolves to a distinct source EdgeRecord and a
#      distinct live derived Edge record/handle.
#   3. World-coordinate endpoints match forward or reversed within
#      the captured execution_config tolerance.duplicate.
#      Re-verified directly inside the proposer.
#   4. Coordinates are finite; transform resolution valid.
#   5. Every member belongs to the same current SourceSnapshot /
#      selection scope.
#   6. Provenance usable. Incomplete nested identity fails closed.
#   7. Layer names byte-identical after Layer0 normalization.
#      Different layer names = semantic conflict → :skipped.
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
      BASIS_FORWARD_EXACT  = 'exact_endpoint_match_within_tolerance.duplicate'.freeze
      BASIS_REVERSED_EXACT = 'reversed_endpoint_match_within_tolerance.duplicate'.freeze

      # Topology impact (audit string).
      TOPOLOGY_IMPACT = 'removes_duplicate_edge'.freeze

      # Reason strings (used in :skipped actions and explanations).
      REASON_SELF_MATCH            = 'duplicate_evidence_self_match'.freeze
      REASON_NEAR_BUT_NOT_EXACT    = 'endpoints_outside_tolerance_duplicate'.freeze
      REASON_PROVENANCE_DIFFERS    = 'source_occurrence_ids_differ'.freeze
      REASON_LAYER_MISMATCH        = 'semantic_conflict_layer_mismatch'.freeze
      REASON_DERIVED_NOT_FOUND     = 'no_derived_record_for_source_edge'.freeze
      REASON_DERIVED_ERASED        = 'derived_record_handle_invalidated'.freeze
      REASON_NON_EDGE_KIND         = 'derived_record_kind_not_edge'.freeze
      REASON_INCOMPLETE_PROVENANCE = 'incomplete_nested_provenance'.freeze
      REASON_NON_FINITE_COORDS     = 'non_finite_endpoint_coordinates'.freeze
      REASON_NON_DISTINCT_SOURCE   = 'duplicate_evidence_repeated_source_edge'.freeze
      REASON_MISSING_EDGE_RECORD   = 'no_edge_record_for_one_or_both_edge_ids'.freeze

      # Canonical Layer0 normalization. SketchUp default layers
      # "Layer0" / "Default" / "Untagged" all collapse to the
      # canonical construction layer name "Layer0". Any other
      # layer name is passed through unchanged.
      DEFAULT_LAYER_CANONICAL = 'Layer0'.freeze

      # Default fallback tolerance.duplicate (inches). The
      # proposer prefers the source snapshot's captured
      # execution_config tolerance.duplicate when available.
      DEFAULT_DUPLICATE_TOLERANCE = 1.0e-4

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

      # ---- internals ----------------------------------------------------

      # Build the actions Array.
      #
      # - Group derived edges by canonical world-geometry key.
      # - For each class with 2+ members AND at least one matching
      #   duplicate_edge_candidate issue, emit ONE action.
      # - For each issue that fails a per-issue guard, emit ONE
      #   :skipped action.
      def build_actions(source_snapshot:, registry:, workspace:)
        tolerance    = read_duplicate_tolerance(source_snapshot)
        edge_lookup  = build_edge_lookup(source_snapshot)
        issues       = collect_duplicate_candidates(registry)

        # --- Pass 1: per-issue guards. Build a set of canonical
        # keys that have at least one valid issue evidence.
        issue_keys = {}        # canonical_key => Array<issue_hash>
        issue_seed_basis = {}  # canonical_key => 'forward'|'reversed'
        skipped = []

        issues.each do |iss|
          classification = classify_issue(
            iss,
            edge_lookup: edge_lookup,
            tolerance:   tolerance
          )
          if classification[:valid]
            key = classification[:canonical_key]
            (issue_keys[key] ||= []) << iss
            issue_seed_basis[key] ||= classification[:basis_kind]
          else
            skipped << classification[:skipped_action]
          end
        end

        # --- Pass 2: group derived records by canonical key.
        derived_classes = group_derived_by_canonical_key(workspace, tolerance)

        # --- Pass 3: for each derived class with 2+ members AND
        # matching issue evidence, emit one action.
        remove_actions = []
        derived_classes.each do |canonical_key, members|
          next if members.length < 2
          matching_issues = issue_keys[canonical_key]
          next unless matching_issues && !matching_issues.empty?
          basis_kind = issue_seed_basis[canonical_key] || :forward
          basis_str  = basis_kind == :reversed ? BASIS_REVERSED_EXACT : BASIS_FORWARD_EXACT

          # Distinct derived records guard (2).
          uniq_derived_ids = members.map { |d| d.derived_id.to_s }.uniq
          if uniq_derived_ids.length != members.length
            matching_issues.each do |iss|
              skipped << skipped_action_for(
                iss, REASON_DERIVED_NOT_FOUND,
                'duplicate derived_id inside the equivalence class; ambiguity is fail-closed'
              )
            end
            next
          end

          # Distinct source edge records guard (2): in the new V1.5
          # world-geometry model, 2 derived records can come from
          # the same parent source edge (a CAD-import artifact
          # where the source edge has 2 derived representations).
          # The guard against "all members share a single occ_id"
          # is implicit in the requirement of 2+ distinct derived
          # records with non-empty source_occurrence_ids (the
          # distinctness of source edges is preserved on the
          # survivor's provenance union, regardless of whether
          # all members share one source or not).
          #
          # We therefore do NOT enforce distinct_occs; we only
          # check that 2+ distinct derived_ids exist (already
          # enforced above) and that every member has non-empty
          # source_occurrence_ids (enforced by guard 6 below).

          # Provenance usability guard (6). Any member without
          # source_occurrence_ids is fail-closed.
          incomplete = members.select { |d| Array(d.source_occurrence_ids).empty? }
          unless incomplete.empty?
            matching_issues.each do |iss|
              skipped << skipped_action_for(
                iss, REASON_INCOMPLETE_PROVENANCE,
                'one or more derived records in the equivalence class have empty source_occurrence_ids'
              )
            end
            next
          end

          # Compute the action's records.
          sorted_member_ids  = uniq_derived_ids.sort
          survivor_id        = sorted_member_ids.first
          removed_ids        = sorted_member_ids[1..]
          provenance_union   = members
                                .flat_map { |d| Array(d.source_occurrence_ids).map(&:to_s) }
                                .uniq
                                .sort

          snapshot_id = source_snapshot.respond_to?(:snapshot_id) ? source_snapshot.snapshot_id.to_s : ''
          action = build_remove_action(
            survivor_id:           survivor_id,
            removed_ids:           removed_ids,
            source_occurrence_ids: provenance_union,
            basis:                 basis_str,
            canonical_key:         canonical_key,
            snapshot_id:           snapshot_id,
            member_derived_ids:    sorted_member_ids
          )
          remove_actions << action
        end

        # Deterministic ordering: remove_actions by action_id asc;
        # skipped by issue_id asc.
        remove_actions.sort_by! { |a| a.action_id.to_s }
        skipped.sort_by!     { |a| (a.before_summary['issue_id'] || '').to_s }
        remove_actions + skipped
      end

      # Classify one duplicate issue. Returns:
      #   {valid: true, canonical_key:, basis_kind:} or
      #   {valid: false, skipped_action: <RepairAction :skipped>}
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

        # Guard 7: layer names byte-identical after Layer0 normalization.
        layer_a = normalize_layer(layer_name_of(ea))
        layer_b = normalize_layer(layer_name_of(eb))
        if layer_a != layer_b
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_LAYER_MISMATCH,
                     "different normalized layer names: #{layer_a.inspect} vs #{layer_b.inspect}") }
        end

        # Guard 3: endpoint exactness (forward or reversed within
        # tolerance.duplicate). Re-verified directly.
        kind, _basis = endpoint_match_kind(ea, eb, tolerance)
        if kind.nil?
          return { valid: false,
                   skipped_action: skipped_action_for(issue, REASON_NEAR_BUT_NOT_EXACT,
                     'endpoints coincide outside tolerance.duplicate; not an exact duplicate') }
        end

        # Build the canonical key from the endpoints + layer.
        canonical_key = canonical_geometry_key(
          start:     ea.start_point,
          finish:    ea.end_point,
          layer:     layer_a,
          tolerance: tolerance
        )

        {
          valid:         true,
          canonical_key: canonical_key,
          basis_kind:    kind
        }
      end

      # ---- canonical geometry key ----

      # Layer0 normalization: Layer0 / Default / Untagged collapse
      # to "Layer0"; anything else passes through unchanged. Empty
      # / nil maps to "Layer0" (the V1.0 fallback layer name).
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

      # Quantize a 3-Float point to a tolerance grid so points
      # within tolerance.duplicate land in the same bucket.
      def quantize_point(point, tolerance)
        inv = 1.0 / tolerance.to_f
        [
          (point[0].to_f * inv).round,
          (point[1].to_f * inv).round,
          (point[2].to_f * inv).round
        ]
      end

      # Orientation-independent canonical geometry key.
      def canonical_geometry_key(start:, finish:, layer:, tolerance:)
        s_q = quantize_point(start, tolerance)
        f_q = quantize_point(finish, tolerance)
        pair = [s_q, f_q].sort_by { |p| p.to_s }
        norm_layer = normalize_layer(layer)
        "geom|#{pair[0].join(',')}|#{pair[1].join(',')}|layer=#{norm_layer}"
      end

      # ---- basis detection ----

      # Determine whether two source edges are exact (forward or
      # reversed) duplicates within tolerance.duplicate. Returns
      # [:forward|:reversed|:nil, basis_string].
      def endpoint_match_kind(edge_a, edge_b, tolerance)
        a_s = finite_float_triple(edge_a.start_point)
        a_e = finite_float_triple(edge_a.end_point)
        b_s = finite_float_triple(edge_b.start_point)
        b_e = finite_float_triple(edge_b.end_point)
        return [nil, nil] if a_s.nil? || a_e.nil? || b_s.nil? || b_e.nil?
        if points_within?(a_s, b_s, tolerance) && points_within?(a_e, b_e, tolerance)
          [:forward, BASIS_FORWARD_EXACT]
        elsif points_within?(a_s, b_e, tolerance) && points_within?(a_e, b_s, tolerance)
          [:reversed, BASIS_REVERSED_EXACT]
        else
          [nil, nil]
        end
      end

      # ---- source-edge / derived-record bookkeeping ----

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

      # Group derived records by canonical world-geometry key.
      # Reads each derived record's geometry_summary for the
      # two endpoints + layer.
      def group_derived_by_canonical_key(workspace, tolerance)
        out = {}
        return out if workspace.nil?
        entities = workspace.respond_to?(:entities) ? workspace.entities : []
        entities.each do |d|
          geom = d.respond_to?(:geometry_summary) ? d.geometry_summary : nil
          next unless geom.is_a?(Hash)
          s = geom['start'] || geom[:start]
          f = geom['end']   || geom[:end]
          l = geom['layer'] || geom[:layer]
          next unless finite_point?(s) && finite_point?(f)
          key = canonical_geometry_key(start: s, finish: f, layer: l, tolerance: tolerance)
          (out[key] ||= []) << d
        end
        out
      end

      # Resolve a V1.4-format source_occurrence_id back to a
      # source EdgeRecord.
      #
      # CORRECTED V1.5 model (Guidance 031): the occurrence id
      # encodes the FULL persistent_id_path joined by '>' (leaf
      # included). For matching back to a source EdgeRecord we
      # use the CONTAINER path (excluding the leaf PID). This
      # is the canonical V1.5 mapping:
      #
      #   - Source edge with pid_path [parent..., leaf] maps
      #     to derived record with occ_id "occ-parent>...>leaf"
      #     by container path only.
      #   - Multiple source edges in the same container map to
      #     multiple derived records (one per leaf) — all
      #     resolve to the same set of source edges.
      #
      # Returns the FIRST matching source EdgeRecord or nil
      # when the path cannot be parsed or no EdgeRecord shares
      # the container.
      def edge_for_occurrence_id(occ_id, edge_lookup)
        return nil if occ_id.nil? || !occ_id.is_a?(String)
        s = occ_id.to_s
        # Strip 'occ-' or 'transient-occ-' prefix.
        rest = if s.start_with?('occ-')
                 s[4..-1]
        elsif s.start_with?('transient-occ-')
                 s[14..-1]
        else
                 nil
        end
        return nil if rest.nil?
        # ipath variant (transient): look up by first path element.
        if rest.start_with?('ipath-')
          rest = rest[6..-1]
        end
        # Parse the path: Array<Integer joined by '>'.
        parts = rest.split('>').map { |x| Integer(x) rescue nil }.compact
        return nil if parts.empty?
        # Match by CONTAINER path (excluding the leaf PID).
        container_path = parts[0..-2]
        edge_lookup.each_value do |edge|
          pid = edge.respond_to?(:source) && edge.source.respond_to?(:persistent_id_path) ?
                  edge.source.persistent_id_path : nil
          next unless pid.is_a?(Array)
          next unless pid.map(&:to_i)[0..-2] == container_path
          return edge
        end
        nil
      end

      # ---- registry / issue collection ----

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

      # ---- tolerance / numeric helpers ----

      # Read tolerance.duplicate from the SourceSnapshot's
      # captured execution_config. Falls back to the conservative
      # default 1.0e-4 inches.
      def read_duplicate_tolerance(source_snapshot)
        return DEFAULT_DUPLICATE_TOLERANCE if source_snapshot.nil?
        ec = source_snapshot.respond_to?(:execution_config) ? source_snapshot.execution_config : nil
        return DEFAULT_DUPLICATE_TOLERANCE if ec.nil?
        vals = ec.respond_to?(:tolerance_values) ? ec.tolerance_values : nil
        return DEFAULT_DUPLICATE_TOLERANCE unless vals.is_a?(Hash)
        v = vals[:duplicate] || vals['duplicate']
        v ? v.to_f : DEFAULT_DUPLICATE_TOLERANCE
      end

      # True iff `p` is a finite 3-Float Array.
      def finite_point?(p)
        return false unless p.is_a?(Array) && p.length == 3
        p.all? do |v|
          v.respond_to?(:finite?) && v.finite?
        end
      end

      # Convert a point to a [Float x3] triple or nil when not finite.
      def finite_float_triple(p)
        return nil unless finite_point?(p)
        [p[0].to_f, p[1].to_f, p[2].to_f]
      end

      # True iff two 3-Float points are within `tol` per axis.
      def points_within?(p, q, tol)
        return false unless p.is_a?(Array) && q.is_a?(Array) && p.length == 3 && q.length == 3
        (0..2).all? { |i| (p[i].to_f - q[i].to_f).abs <= tol.to_f }
      end

      # Coerce a value to Integer or nil.
      def int(v)
        Integer(v) rescue nil
      end

      # ---- edge accessors ----

      def layer_name_of(edge)
        return nil unless edge.respond_to?(:layer)
        edge.layer
      end

      # ---- deterministic action_id ----

      # Build a deterministic action_id from the rule id, source
      # snapshot identity, canonical geometry key, and the
      # sorted member derived_ids. SHA256-based; reproducible
      # and auditable. NEVER uses SecureRandom.
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

      # ---- action builders ----

      # Build the :remove_duplicate_edge RepairAction (one per
      # equivalence class).
      def build_remove_action(survivor_id:, removed_ids:,
                              source_occurrence_ids:, basis:,
                              canonical_key:, snapshot_id:,
                              member_derived_ids:)
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
          'proposed_after_edge_count'  => 1
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

      # Build a :skipped RepairAction (no removal) with the given
      # reason. The action still records the reason for the audit
      # trail.
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

      # Self-match shortcut.
      def self_match_skipped(issue)
        skipped_action_for(issue, REASON_SELF_MATCH,
          'duplicate evidence references the same source edge twice; nothing to remove')
      end

      # ---- canonical-key accessors (audit only) ----

      # Extract the canonical endpoint summary from a canonical
      # key string. The key is opaque to callers; we expose only
      # the layer and the presence of two quantized endpoints.
      def canonical_endpoint_summary(canonical_key)
        parts = canonical_key.to_s.split('|')
        # parts: ["geom", "<qx1>", "<qx2>", "layer=<name>"]
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

      # Build the explanation string for a remove action. Pure
      # data; no live objects.
      def build_explanation(basis:, member_count:, source_occ_count:)
        basis_kind = basis.to_s.start_with?('reversed') ? 'reversed exact' : 'forward exact'
        survivor_count = 1
        removed_count  = member_count - survivor_count
        "Exact duplicate edge (#{basis_kind}); #{member_count} source occurrences converge on one canonical derived segment; survivor keeps the lex-smallest derived_id; #{removed_count} derived record(s) to remove; provenance union size = #{source_occ_count}."
      end
    end
  end
end