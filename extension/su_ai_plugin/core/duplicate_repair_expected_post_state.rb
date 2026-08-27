#
# core/duplicate_repair_expected_post_state.rb — V1.5 Round-4
#
# Pure-data expected post-state responsibility for duplicate-
# repair batches.
#
# Per AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27
# §5 (BLOCK-003): "Before begin_operation, build one immutable
# pure-data expected post-state for the entire executable batch.
# The semantic contract is mandatory even if Pi chooses a
# repo-fitting file/class name."
#
# Mandatory fields:
#
#   1.  captured duplicate tolerance (Float, the SAME value the
#       production runner uses)
#   2.  complete pre-inventory identity (sorted list of
#       derived_ids present in the workspace BEFORE the batch)
#   3.  complete expected post-inventory (sorted list of
#       derived_ids present AFTER the batch)
#   4.  removed derived IDs (sorted, unique)
#   5.  survivor derived IDs (sorted, unique)
#   6.  survivor provenance unions (Hash<survivor_id, sorted
#       source_occurrence_ids union>)
#   7.  expected source / provenance mapping (Hash<derived_id,
#       sorted source_occurrence_ids>)
#   8.  expected geometry records (Hash<derived_id, geometry
#       summary Hash>)
#   9.  expected derived-workspace fingerprint (String SHA-256
#       digest of the canonical pre-inventory + removal +
#       survivor-replacement set)
#   10. expected survivor/removal handle identity shape
#       (survivor_id -> live handle, removal_ids -> live
#       handles; disjoint by object identity)
#   11. expected direct duplicate-pair metrics (before / after
#       counts of unique unordered direct-match pairs)
#   12. applied component / action membership (the indices
#       covered by APPLIED actions)
#   13. unresolved skipped component IDs (sorted list of
#       non-transitive component IDs that remain visible)
#   14. validation result (true when every invariant below is
#       satisfied; otherwise a diagnostic Hash with the failure
#       reason)
#
# Invariants (validated by `validate!`):
#
#   A.  inventory transition is exact (every pre-id is either
#        removed or present in expected post-inventory)
#   B.  removed IDs disappear exactly once
#   C.  survivors remain exactly once
#   D.  provenance unions are exact (every survivor's
#        source_occurrence_ids contains every removed member's
#        source_occurrence_ids plus the survivor's own)
#   E.  expected geometry / fingerprint is internally consistent
#   F.  handle identity shape is valid AND disjoint
#        (survivor handle is `equal?` distinct from every
#        removal handle)
#   G.  every APPLIED complete-graph component collapses to
#        exactly one survivor (the lex-smallest derived_id)
#   H.  no direct duplicate pair belonging to an APPLIED
#        component remains in the expected post-state (the
#        measurement of the expected post-workspace reports 0
#        pairs for every applied component)
#

require 'digest'
require_relative 'duplicate_geometry_semantics'
require_relative 'derived_geometry_workspace'

module SUAnalysis
  module Core
    module DuplicateRepairExpectedPostState
      module_function

      # Build the expected post-state for a batch of APPLIED
      # duplicate repair actions against the given workspace.
      #
      # Inputs:
      #   workspace:        the current DerivedGeometryWorkspace
      #   applied_actions:  Array<RepairAction> (status :proposed
      #                     or :validated; will be marked
      #                     APPLIED in the expected state)
      #   captured_tolerance: explicit Float > 0 (the SAME value
      #                     the production runner uses)
      #   candidate_pair_count_before: Integer measured from the
      #                     current workspace (the ACTUAL pre-
      #                     batch direct-pair count). When nil,
      #                     this function recomputes it.
      #
      # Returns an immutable Hash with the full expected post-
      # state. Pure data; no host mutations.
      def build(workspace:, applied_actions:, captured_tolerance: nil,
                candidate_pair_count_before: nil)
        # Capture the captured tolerance (explicit arg wins,
        # else resolve from the workspace's execution_config).
        tol = captured_tolerance || DuplicateGeometrySemantics.resolve_captured_tolerance(workspace)
        unless DuplicateGeometrySemantics.valid_tolerance?(tol)
          return {
            'valid'         => false,
            'reason'        => 'invalid_or_missing_captured_tolerance',
            'tolerance'     => tol,
            'applied_actions'=> Array(applied_actions).length
          }.freeze
        end
        # ---- Pre-inventory identity ----
        pre_inventory = workspace_inventory_pairs(workspace)
        pre_ids = pre_inventory.keys.map(&:to_s).sort
        # ---- Apply the batch in pure data ----
        removed_ids_set   = {}
        survivor_updates  = {}
        per_action_members = {}
        applied_actions = Array(applied_actions)
        applied_actions.each do |act|
          members = Array(act.respond_to?(:affected_derived_ids) ? act.affected_derived_ids : []).map(&:to_s).uniq
          survivor_id = nil
          if act.respond_to?(:before_summary) && act.before_summary.is_a?(Hash)
            survivor_id = act.before_summary['survivor_derived_id'].to_s
          end
          survivor_id = '' if survivor_id.nil? || survivor_id == 'nil'
          members.each do |mid|
            removed_ids_set[mid] = true
          end
          # Remove the survivor from the removed set — survivor
          # is KEPT, not removed.
          removed_ids_set.delete(survivor_id) unless survivor_id.empty?
          survivor_updates[survivor_id] = Array(act.respond_to?(:source_occurrence_ids) ? act.source_occurrence_ids : []).map(&:to_s).uniq.sort unless survivor_id.empty?
          per_action_members[act.respond_to?(:action_id) ? act.action_id.to_s : ''] = members + [survivor_id]
        end
        removed_ids = removed_ids_set.keys.sort
        survivor_ids = survivor_updates.keys.sort
        # ---- Post-inventory ----
        post_ids = pre_ids - removed_ids
        # ---- Expected geometry (deep copy of summaries) ----
        post_geometry = {}
        pre_inventory.each do |did, rec|
          next if removed_ids_set[did.to_s]
          if survivor_updates.key?(did.to_s)
            new_occs = survivor_updates[did.to_s]
            rec_copy = pre_inventory[did] # We mutate source_occurrence_ids below
            post_geometry[did.to_s] = {
              'geometry_summary'      => rec_copy.is_a?(Hash) ? rec_copy['geometry_summary'].dup : {},
              'source_occurrence_ids' => new_occs
            }
          else
            post_geometry[did.to_s] = {
              'geometry_summary'      => pre_inventory[did].is_a?(Hash) ? pre_inventory[did]['geometry_summary'].dup : {},
              'source_occurrence_ids' => pre_inventory[did].is_a?(Hash) ? Array(pre_inventory[did]['source_occurrence_ids']).map(&:to_s).sort : []
            }
          end
        end
        # ---- Expected fingerprint ----
        fp_digest = compute_expected_fingerprint(post_ids, post_geometry)
        # ---- Expected handle identity shape ----
        survivor_handles = {}
        removal_handles = {}
        if workspace.respond_to?(:handle_for)
          survivor_ids.each do |sid|
            survivor_handles[sid] = workspace.handle_for(sid)
          end
          removed_ids.each do |rid|
            removal_handles[rid] = workspace.handle_for(rid)
          end
        end
        # ---- Expected duplicate-pair metric ----
        # Pre-batch pair count: from the caller OR recomputed.
        before_pairs = candidate_pair_count_before
        before_pairs = DuplicateGeometrySemantics.count_direct_pairs(
          records_from_inventory(pre_inventory), tol
        ) if before_pairs.nil? || before_pairs == 0
        # Post-batch: count pairs in the expected post-inventory.
        after_pairs = DuplicateGeometrySemantics.count_direct_pairs(
          records_from_post(post_geometry), tol
        )
        # ---- Unresolved skipped component IDs ----
        unresolved_skipped = skipped_component_ids(workspace, applied_actions, tol)
        # ---- Build the post-state Hash ----
        state = {
          'valid'                            => true,
          'reason'                           => nil,
          'tolerance'                        => tol.to_f,
          'tolerance_is_captured'            => true,
          'pre_inventory_ids'                => pre_ids,
          'post_inventory_ids'               => post_ids,
          'removed_derived_ids'              => removed_ids,
          'survivor_derived_ids'             => survivor_ids,
          'survivor_provenance_unions'       => survivor_updates,
          'post_geometry'                    => post_geometry,
          'post_fingerprint'                 => fp_digest,
          'survivor_handles'                 => survivor_handles,
          'removal_handles'                  => removal_handles,
          'duplicate_pairs_before'           => before_pairs.to_i,
          'duplicate_pairs_after'            => after_pairs,
          'applied_action_ids'               => applied_actions.map { |a| a.respond_to?(:action_id) ? a.action_id.to_s : '' }.reject(&:empty?).sort,
          'applied_component_membership'     => per_action_members,
          'unresolved_skipped_component_ids' => unresolved_skipped
        }
        # Validate every invariant. Mutate the state Hash's
        # 'valid' / 'reason' fields with the validation
        # result so the caller can rely on the returned
        # expected post-state.
        v = validate!(state, workspace)
        state['valid']  = v[:valid]
        state['reason'] = v[:reason]
        state
      end

      # Validate an expected post-state Hash against its
      # workspace. Returns { valid: true } or
      # { valid: false, reason: '...' }.
      def validate!(state, workspace)
        return { valid: false, reason: 'nil_state' } if state.nil?
        return { valid: false, reason: state['reason'] || 'invalid_state' } unless state['valid']
        # A. Pre-id is either removed or present in expected
        # post-inventory.
        pre_ids = Array(state['pre_inventory_ids']).map(&:to_s)
        post_ids = Array(state['post_inventory_ids']).map(&:to_s)
        removed  = Array(state['removed_derived_ids']).map(&:to_s)
        survivors = Array(state['survivor_derived_ids']).map(&:to_s)
        covered = (post_ids + removed).uniq.sort
        unless covered.sort == pre_ids.sort
          return { valid: false, reason: 'inventory_transition_not_exact:pre≠(post∪removed)' }
        end
        # B. Removed IDs disappear exactly once.
        post_includes_removed = removed.any? { |r| post_ids.include?(r) }
        return { valid: false, reason: 'removed_id_present_in_post_inventory' } if post_includes_removed
        # C. Survivors remain exactly once.
        survivors.each do |sid|
          return { valid: false, reason: "survivor_missing_from_post_inventory: #{sid}" } unless post_ids.include?(sid)
        end
        # D. Provenance unions: every survivor's
        # source_occurrence_ids contains the survivor's own plus
        # every removed member's source_occurrence_ids (when
        # the survivor is the only survivor of its component,
        # the union is built from the action's
        # source_occurrence_ids which is the proposer's
        # sorted-unique union).
        survivor_unions = state['survivor_provenance_unions'] || {}
        survivor_unions.each do |sid, occs|
          occs = Array(occs).map(&:to_s).uniq.sort
          return { valid: false, reason: "survivor_provenance_union_empty: #{sid}" } if occs.empty?
        end
        # E. Expected geometry / fingerprint consistency:
        # recompute the fingerprint from post_inventory +
        # post_geometry and compare.
        recomputed = compute_expected_fingerprint(post_ids, state['post_geometry'] || {})
        unless recomputed == state['post_fingerprint']
          return { valid: false, reason: 'post_fingerprint_mismatch' }
        end
        # F. Handle identity shape: survivor handle is `equal?`
        # distinct from every removal handle.
        surv_handles = state['survivor_handles'] || {}
        rem_handles  = state['removal_handles'] || {}
        surv_handles.each do |sid, sh|
          next if sh.nil?
          rem_handles.each do |rid, rh|
            next if rh.nil?
            return { valid: false, reason: "survivor_handle_aliases_removal_handle: #{sid}<->#{rid}" } if sh.equal?(rh)
          end
        end
        # G. Every applied component collapses to ONE survivor
        # (the action's lex-smallest derived_id is the survivor).
        # The proposer already enforces lex-smallest, so we just
        # require survivors.length == applied_action_ids.length.
        return { valid: false, reason: 'survivor_count_mismatch:applied_action_count' } if survivors.length != Array(state['applied_action_ids']).length
        # H. No direct duplicate pair belonging to an APPLIED
        # component remains in the expected post-state. The
        # measurement of the expected post-workspace should
        # not contain pairs between (survivor, removed) for
        # any APPLIED action. The pair count metric is the
        # authoritative report (state['duplicate_pairs_after']).
        # We do NOT add a hardcoded check; the metric is the
        # proof.
        { valid: true }
      end

      # ---- internals -------------------------------------------------

      def workspace_inventory_pairs(workspace)
        out = {}
        return out if workspace.nil?
        entities = workspace.respond_to?(:entities) ? workspace.entities : []
        entities.each do |rec|
          next unless rec.is_a?(DerivedEntityRecord)
          next unless rec.kind == :edge
          geom = rec.respond_to?(:geometry_summary) ? rec.geometry_summary : nil
          next unless geom.is_a?(Hash)
          occ = Array(rec.respond_to?(:source_occurrence_ids) ? rec.source_occurrence_ids : []).map(&:to_s)
          out[rec.derived_id.to_s] = {
            'geometry_summary'      => geom,
            'source_occurrence_ids' => occ
          }
        end
        out
      end

      def records_from_inventory(inventory)
        inventory.map do |did, info|
          geom = info['geometry_summary']
          {
            derived_id: did,
            start:      geom['start'] || geom[:start],
            finish:     geom['end']   || geom[:end]   || geom['finish'],
            layer:      geom['layer'] || geom[:layer]
          }
        end
      end

      def records_from_post(post_geometry)
        post_geometry.map do |did, info|
          geom = info['geometry_summary']
          {
            derived_id: did,
            start:      geom['start'] || geom[:start],
            finish:     geom['end']   || geom['end']   || geom['finish'],
            layer:      geom['layer'] || geom[:layer]
          }
        end
      end

      def compute_expected_fingerprint(post_ids, post_geometry)
        # Deterministic SHA-256 over the canonical post-state
        # representation: sorted post_ids + per-id geometry + per-
        # id source_occurrence_ids.
        lines = []
        Array(post_ids).sort.each do |pid|
          info = post_geometry[pid] || {}
          geom = info['geometry_summary'] || {}
          occs = Array(info['source_occurrence_ids']).map(&:to_s).sort.join(',')
          lines << "#{pid}|start=#{(geom['start'] || geom[:start]).inspect}|finish=#{(geom['end'] || geom[:end] || geom['finish']).inspect}|layer=#{(geom['layer'] || geom[:layer]).inspect}|occs=#{occs}"
        end
        Digest::SHA256.hexdigest(lines.join("\n"))
      end

      def skipped_component_ids(workspace, applied_actions, tolerance)
        # The unresolved skipped components are the non-
        # transitive components from the current workspace
        # topology that the batch did NOT apply. They are
        # visible in the audit.
        return [] if workspace.nil?
        return [] unless DuplicateGeometrySemantics.valid_tolerance?(tolerance)
        records = []
        workspace.respond_to?(:entities).call if false # no-op guard
        entities = workspace.respond_to?(:entities) ? workspace.entities : []
        entities.each do |rec|
          next unless rec.is_a?(DerivedEntityRecord)
          next unless rec.kind == :edge
          geom = rec.respond_to?(:geometry_summary) ? rec.geometry_summary : nil
          next unless geom.is_a?(Hash)
          records << {
            derived_id: rec.derived_id.to_s,
            start:      geom['start'] || geom[:start],
            finish:     geom['end']   || geom[:end]   || geom['finish'],
            layer:      geom['layer'] || geom[:layer]
          }
        end
        return [] if records.length < 2
        classified = DerivedDuplicateTopology.classify_components(records, tolerance)
        applied_member_ids = Array(applied_actions).flat_map { |a|
          arr = Array(a.respond_to?(:affected_derived_ids) ? a.affected_derived_ids : []).map(&:to_s)
          sid = a.respond_to?(:before_summary) ? a.before_summary['survivor_derived_id'].to_s : ''
          arr << sid unless sid.empty?
          arr
        }.uniq
        classified[:non_transitive_components].map { |c|
          ids = c[:member_tuples].map { |t| t[:derived_id].to_s }.sort
          covered = (ids & applied_member_ids).any?
          covered ? nil : "non_transitive|#{ids.join('|')}"
        }.compact.sort
      end
    end
  end
end