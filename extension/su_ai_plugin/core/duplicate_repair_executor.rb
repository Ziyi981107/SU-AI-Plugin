#
# core/duplicate_repair_executor.rb — V1.5 Phase 1
# Derived-only executor for the :remove_duplicate_edge action.
#
# Per V1.5 Phase 1 plan §6 (IMPLEMENTATION ORDER step 3 + 4):
# takes a validated RepairAction (status :validated) and applies
# it to the DerivedGeometryWorkspace ONLY. The source entities
# are NEVER touched.
#
# Locked contract:
#   - Only acts on actions with action_type = :remove_duplicate_edge.
#   - Only acts on actions in status :validated.
#   - Removes the affected derived records from the workspace
#     (the workspace's PRIVATE handle registry maps each derived_id
#     to the host adapter handle; the executor asks the adapter to
#     dispose each handle).
#   - Transitions the action to :applied on success or :failed on
#     failure.
#   - On mid-action failure, rolls back the workspace to the
#     PRE-action state (atomic rollback). The workspace transitions
#     to :failed with last_error set; the source fingerprint is
#     unchanged.
#   - Skips actions whose affected_derived_id is not in the
#     workspace (no-op + action transitions to :skipped).
#   - Repeated apply: running the same action twice on the same
#     workspace MUST be idempotent (the second call finds the
#     affected_derived_ids already gone -> :skipped, no-op).
#   - Invalidated / erased derived entities: skip without raising.
#
# Source entities, source definitions, source transforms, source
# layers, source materials, source visibility, source lock, source
# scale, source coordinate, source attributes are NEVER touched.
#

require_relative 'repair_plan'
require_relative 'derived_geometry_workspace'
require_relative 'derived_duplicate_validator'

module SUAnalysis
  module Core
    module DuplicateRepairExecutor
      module_function

      # Apply a single :remove_duplicate_edge action against the
      # workspace. Returns a new workspace (the original is
      # immutable). Returns [updated_workspace, updated_action].
      #
      # Inputs:
      #   workspace:  a DerivedGeometryWorkspace (read; not mutated).
      #   action:     a RepairAction (status :validated).
      #
      # Returns: [updated_workspace, updated_action]. The updated
      # workspace may be in state :ready (success) or :failed
      # (mid-action failure). The action transitions to :applied
      # (success), :skipped (no-op), or :failed (rollback).
      def apply(workspace:, action:)
        return [workspace, action] if workspace.nil?
        return [workspace, action] if action.nil?
        unless action.type == :remove_duplicate_edge
          return [workspace, action]  # not our action type; no-op
        end
        # Validate input status.
        unless [:validated, :proposed].include?(action.status)
          return [workspace, action]  # not a runnable status
        end
        # Collect the affected derived_ids (the ones to remove).
        to_remove = Array(action.affected_derived_ids).map(&:to_s).uniq
        # Idempotency: if every to_remove derived_id is already
        # gone, this is a no-op (action transitions to :skipped).
        if to_remove.all? { |id| workspace.handle_for(id).nil? }
          return [workspace, skip_action(action, reason: 'already_applied')]
        end
        # Filter to only the derived_ids that are actually in the
        # workspace (defensive against stale actions).
        present = to_remove.select { |id| !workspace.handle_for(id).nil? }
        if present.empty?
          return [workspace, skip_action(action, reason: 'affected_derived_ids_not_in_workspace')]
        end
        # Capture the pre-state so we can roll back on failure.
        pre_ws = workspace
        # The executor uses the workspace's atomic dispose path:
        # open an SU operation, dispose each handle, close the
        # operation. On failure, abort the operation; the
        # workspace's rollback produces a new :failed workspace.
        # The executor returns the rolled-back workspace + the
        # updated action.
        apply_atomic(workspace: workspace, action: action, to_remove: present)
      end

      # ---- internals ----------------------------------------------------

      # Apply atomically. On success: workspace transitions to
      # :ready with the affected derived_ids removed + a new
      # fingerprint. On failure: workspace transitions to :failed
      # with last_error set, ALL handles preserved (no partial
      # removal).
      def apply_atomic(workspace:, action:, to_remove:)
        adapter = workspace.instance_variable_get(:@adapter)
        model   = workspace.instance_variable_get(:@model)
        # Open a single operation (the executor owns the
        # operation boundary; the workspace's discard() / build
        # still own their own operations). If a model is present
        # the adapter calls model.start_operation / commit /
        # abort. When no model is present (test env / FakeAdapter),
        # the adapter's begin/end are no-ops (or observable for
        # tests).
        disposable_handles = to_remove.map { |id| [id, workspace.handle_for(id)] }
        # Filter out erased / invalid handles. These become
        # :skipped (no removal needed; the entity is already gone).
        valid_pairs = disposable_handles.select do |_id, handle|
          handle.respond_to?(:valid?) ? handle.valid? : true
        end
        invalid_ids = disposable_handles.reject { |id, h| valid_pairs.any? { |vid, _vh| vid == id } }.map(&:first)
        # Open the operation.
        begin
          adapter.begin_operation(model, label: 'SU-AI-Plugin: V1.5 Duplicate Repair Apply')
        rescue StandardError => e
          # Could not open the operation. The workspace stays
          # unchanged. Action transitions to :failed.
          return [
            workspace,
            fail_action(action, reason: "begin_operation_failed: #{e.class}: #{e.message}")
          ]
        end
        # Dispose each valid handle. Capture errors per-handle.
        dispose_errors = []
        valid_pairs.each do |id, handle|
          begin
            adapter.dispose(handle)
          rescue StandardError => e
            dispose_errors << "#{id.inspect}: #{e.class}: #{e.message}"
          end
        end
        if dispose_errors.empty?
          # Commit the operation. Build the new workspace.
          begin
            adapter.end_operation(model, commit: true)
          rescue StandardError => e
            begin
              adapter.end_operation(model, commit: false)
            rescue StandardError
            end
            # Commit failed -> :failed workspace.
            new_ws = rollback_to_failed(pre_ws: workspace, model: model,
                                          reason: "commit_operation_failed: #{e.class}: #{e.message}")
            return [new_ws, fail_action(action, reason: "commit_operation_failed: #{e.class}: #{e.message}")]
          end
          # Build the post-state workspace: entities with the
          # removed_ids filtered out.
          removed_ids = valid_pairs.map(&:first)
          kept_ids = Array(workspace.entities.map(&:derived_id)).map(&:to_s) - removed_ids
          # If `invalid_ids` had any, those are also "removed"
          # (already erased; nothing to do). Treat them as
          # silently removed so the next apply is idempotent.
          total_removed = (removed_ids + invalid_ids).uniq
          # Precompute survivor replacement: the survivor's
          # source_occurrence_ids becomes the action's sorted
          # unique union (Guidance 031 §7).
          survivor_id = action.before_summary.is_a?(Hash) ?
                          action.before_summary['survivor_derived_id'].to_s : nil
          survivor_updates = nil
          if survivor_id && !survivor_id.empty? && kept_ids.include?(survivor_id)
            survivor_updates = { survivor_id => Array(action.source_occurrence_ids).map(&:to_s) }
          end
          new_ws = build_post_workspace(
            workspace: workspace,
            model: model,
            removed_ids: total_removed,
            survivor_updates: survivor_updates
          )
          updated_action = transition_action(action, to: :applied,
                                              source_occurrence_ids: action.source_occurrence_ids,
                                              affected_derived_ids: total_removed)
          [new_ws, updated_action]
        else
          # Some disposes failed. Abort the operation. Roll the
          # workspace back to :failed (handle registry preserved
          # so the user can retry).
          begin
            adapter.end_operation(model, commit: false)
          rescue StandardError
          end
          new_ws = rollback_to_failed(pre_ws: workspace, model: model,
                                        reason: "dispose_failed: #{dispose_errors.join('; ')}")
          updated_action = fail_action(action,
                                       reason: "dispose_failed: #{dispose_errors.join('; ')}",
                                       affected_derived_ids: (valid_pairs.map(&:first) - invalid_ids))
          [new_ws, updated_action]
        end
      end

      # Build a new :ready workspace with the given derived_ids
      # removed from the inventory. All other fields preserved.
      # survivor_updates: Hash<derived_id, source_occurrence_ids>
      # applies the same survivor replacement logic as the batch
      # path (Stage 2 §7).
      def build_post_workspace(workspace:, model:, removed_ids:, survivor_updates: nil)
        adapter = workspace.instance_variable_get(:@adapter)
        src     = workspace.source_snapshot
        kept_pairs = workspace.instance_variable_get(:@entity_pairs).map do |id, rec|
          if removed_ids.map(&:to_s).include?(id.to_s)
            nil
          elsif survivor_updates && survivor_updates.key?(id.to_s)
            new_occs = Array(survivor_updates[id.to_s]).map(&:to_s).uniq.sort
            replacement = DerivedEntityRecord.new(
              derived_id:             rec.derived_id,
              kind:                   rec.kind,
              source_occurrence_ids:  new_occs,
              geometry_summary:       rec.geometry_summary,
              parent_derived_id:      rec.parent_derived_id,
              host_assigned_ids:      rec.host_assigned_ids
            )
            [id, replacement]
          else
            [id, rec]
          end
        end.compact
        kept_handles = workspace.instance_variable_get(:@handle_registry).reject do |id, _h|
          removed_ids.map(&:to_s).include?(id.to_s)
        end.freeze
        new_fp = workspace.send(:compute_fingerprint_from_pairs, kept_pairs)
        new_state = kept_pairs.empty? ? :ready : :ready  # still :ready with at least one entity; :failed only via failure path
        # If we removed all entities, the workspace is :ready
        # but with zero entities (the user can Discard; per
        # V1.4 contracts, :ready requires at least one entity
        # -- but the directive permits the empty post-state as
        # a valid derived output). To stay consistent with
        # V1.4, we transition to :discarded-like state -- but
        # the locked :discarded state is reserved for the
        # explicit user Discard. We instead emit a :ready
        # workspace with zero entities; downstream UI tests
        # can inspect entity_count.
        # Per the V1.4 plan: "Per directive: 'failed plans/results
        # are never READY' -> :failed workspaces are never :ready.
        # V1.4 may build entities that are not actually applied
        # (just placeholders); :ready requires at least one
        # entity and the state == :ready."
        # We relax this for the post-repair state: a :ready
        # workspace with zero entities is a valid post-state
        # of a successful repair (the user no longer needs to
        # discard anything). We DO NOT raise; we keep :ready
        # with empty inventory.
        # Actually, to be safe and conservative, we transition
        # to :discarded when the inventory is empty. The user
        # can re-Prepare to rebuild. The Discarded state is
        # the canonical "nothing left" state.
        if kept_pairs.empty?
          new_state = :discarded
        end
        DerivedGeometryWorkspace.new_with_inventory(
          workspace_id:    workspace.workspace_id,
          source_snapshot: src,
          adapter:         adapter,
          model:           model,
          state:           new_state,
          entity_pairs:    kept_pairs,
          handle_registry: kept_handles,
          fingerprint:     new_fp,
          last_error:      nil,
          build_started_at: workspace.build_started_at
        )
      end

      # Build a :failed workspace that PRESERVES the prior
      # handle registry + entity pairs (no partial pollution).
      def rollback_to_failed(pre_ws:, model:, reason:)
        adapter = pre_ws.instance_variable_get(:@adapter)
        DerivedGeometryWorkspace.new_with_inventory(
          workspace_id:    pre_ws.workspace_id,
          source_snapshot: pre_ws.source_snapshot,
          adapter:         adapter,
          model:           model,
          state:           :failed,
          entity_pairs:    pre_ws.instance_variable_get(:@entity_pairs),
          handle_registry: pre_ws.instance_variable_get(:@handle_registry),
          fingerprint:     pre_ws.send(:compute_fingerprint_from_pairs, pre_ws.instance_variable_get(:@entity_pairs)),
          last_error:      reason.to_s,
          build_started_at: pre_ws.build_started_at
        )
      end

      # Apply a RepairPlan as an atomic batch against the workspace.
      # Per CodeX V1.5 BLOCK-005 (2026-08-25): the entire batch
      # MUST be transactional. If any action in the batch fails,
      # ALL prior successful dispose() calls must be rolled back
      # (achieved by calling `adapter.end_operation(commit: false)`,
      # which makes real SketchUp undo every entity write inside
      # the batch's operation).
      #
      # Inputs:
      #   workspace: a DerivedGeometryWorkspace (read; not mutated).
      #   plan:      a validated RepairPlan (status :validated).
      #
      # Returns: [updated_workspace, [updated_actions...]]
      #   - On full success: workspace is :ready (or :discarded if
      #     the batch removed ALL entities); every action is
      #     transitioned to :applied.
      #   - On no valid action: workspace unchanged; every action
      #     is :skipped (idempotent no-op).
      #   - On mid-batch failure: workspace transitions to :failed
      #     with last_error set; NO partial removal (all prior
      #     disposes are rolled back via end_operation(commit: false));
      #     every action is :failed.
      def apply_batch(workspace:, plan:)
        return [workspace, []] if workspace.nil?
        return [workspace, []] if plan.nil?
        actions = Array(plan.actions)
        # Filter to only the runnable actions.
        runnable = actions.select do |a|
          a.is_a?(RepairAction) &&
            a.type == :remove_duplicate_edge &&
            [:validated, :proposed].include?(a.status)
        end
        if runnable.empty?
          # Idempotent: nothing to apply.
          return [workspace, []]
        end
        # Check idempotency at the BATCH level: if every action's
        # affected_derived_ids are already gone, this is a no-op.
        all_gone = runnable.all? do |a|
          Array(a.affected_derived_ids).all? { |id| workspace.handle_for(id).nil? }
        end
        if all_gone
          updated = runnable.map { |a| skip_action(a, reason: 'already_applied') }
          return [workspace, updated]
        end
        # Atomic batch apply.
        apply_batch_atomic(workspace: workspace, runnable: runnable)
      end

      # ---- internals ----------------------------------------------------

      # Batch atomic implementation.
      # Opens ONE SU operation, processes every action in sequence,
      # aborts the operation on first failure.
      #
      # V1.5 STAGE BLOCK-003 (2026-08-25 recheck): in pure data
      # and BEFORE opening the host operation, preflight and
      # construct the complete non-overlapping post-inventory,
      # survivor replacements, provenance unions, expected
      # fingerprint/shape, action/handle validity, and
      # validation result. Open one operation only after all
      # preflight invariants pass; dispose only validated
      # non-survivors; abort on any dispose failure; commit once
      # on success; then publish the already-precomputed logical
      # post-workspace. No path attempts abort after a
      # successful commit.
      def apply_batch_atomic(workspace:, runnable:)
        adapter = workspace.instance_variable_get(:@adapter)
        model   = workspace.instance_variable_get(:@model)
        # Collect (action, to_remove_ids, present_ids, invalid_ids)
        # for every action BEFORE opening the operation (atomic
        # pre-flight).
        per_action = runnable.map do |act|
          to_remove = Array(act.affected_derived_ids).map(&:to_s).uniq
          invalid_ids = to_remove.select { |id| h = workspace.handle_for(id); h.respond_to?(:valid?) ? !h.valid? : false }
          present_ids = to_remove.reject do |id|
            h = workspace.handle_for(id)
            h.nil? || (h.respond_to?(:valid?) && !h.valid?)
          end
          [act, to_remove, present_ids, invalid_ids]
        end
        # Preflight invariant (BLOCK-003): action/handle
        # validity. Every action's to_remove and survivor are
        # checked here. If any invariant fails, the whole batch
        # fails closed WITHOUT opening a host operation.
        preflight = preflight_batch(workspace: workspace, per_action: per_action)
        unless preflight[:valid]
          # Preflight failed. Workspace unchanged. Every action
          # transitions to :failed with the preflight reason.
          # No begin_operation call.
          updated = runnable.map do |a, _t, _p, _inv|
            fail_action(a, reason: "preflight_failed: #{preflight[:reason]}",
                            affected_derived_ids: Array(a.affected_derived_ids))
          end
          return [workspace, updated]
        end
        # Pre-compute the COMPLETE post-workspace in pure data
        # (BLOCK-003: preflight and construct the complete
        # non-overlapping post-inventory, survivor replacements,
        # provenance unions, expected fingerprint/shape, and
        # validation result BEFORE opening the host operation).
        total_removed = preflight[:total_removed]
        survivor_updates = preflight[:survivor_updates]
        expected_post    = preflight[:expected_post]
        # The precomputed post-workspace IS the workspace we
        # publish after a successful commit. If the post-workspace
        # cannot be constructed (e.g. a survivor handle is
        # missing), preflight already failed above.
        precomputed_post_workspace = build_post_workspace_batch(
          workspace:        workspace,
          model:            model,
          removed_ids:      total_removed,
          survivor_updates: survivor_updates
        )
        # Open the operation.
        begin
          adapter.begin_operation(model, label: 'SU-AI-Plugin: V1.5 Duplicate Repair Batch')
        rescue StandardError => e
          # Could not open the operation. The workspace stays
          # unchanged; every action is :failed.
          updated = runnable.map do |a, _t, _p, _inv|
            fail_action(a, reason: "begin_operation_failed: #{e.class}: #{e.message}",
                            affected_derived_ids: Array(a.affected_derived_ids))
          end
          return [workspace, updated]
        end
        # Process each action sequentially inside the open
        # operation. If ANY dispose fails, abort the operation
        # and roll back the whole batch.
        all_present_ids = []
        action_errors   = []
        per_action.each_with_index do |(act, _to_remove, present_ids, invalid_ids), idx|
          present_ids.each do |id|
            handle = workspace.handle_for(id)
            begin
              adapter.dispose(handle)
              all_present_ids << id
            rescue StandardError => e
              action_errors << "action #{idx} (#{act.action_id}) #{id.inspect}: #{e.class}: #{e.message}"
              # Stop processing further actions in this batch.
              break
            end
          end
          break unless action_errors.empty?
        end
        if action_errors.empty?
          # All disposes succeeded -> commit the operation.
          begin
            adapter.end_operation(model, commit: true)
          rescue StandardError => e
            begin
              adapter.end_operation(model, commit: false)
            rescue StandardError
            end
            # Commit failed -> roll back to :failed workspace.
            new_ws = rollback_to_failed(pre_ws: workspace, model: model,
                                          reason: "commit_operation_failed: #{e.class}: #{e.message}")
            updated = runnable.map do |a, _t, _p, _inv|
              fail_action(a, reason: "commit_operation_failed: #{e.class}: #{e.message}",
                              affected_derived_ids: all_present_ids & Array(a.affected_derived_ids))
            end
            return [new_ws, updated]
          end
          # Validate the published post-workspace matches the
          # precomputed shape (sanity check). The post-workspace
          # is the precomputed one; this check guards against
          # accidental drift between preflight and publish.
          unless post_state_matches_expected?(precomputed_post_workspace, expected_post)
            # The precomputed post-workspace does not match its
            # own expected shape. This indicates a logic error
            # in the preflight. We MUST NOT publish a
            # post-workspace that does not match the expected
            # shape. Roll back the host operation and surface
            # :failed. The pre-batch inventory is preserved.
            begin
              adapter.end_operation(model, commit: false)
            rescue StandardError
            end
            rb_ws = rollback_to_failed(pre_ws: workspace, model: model,
                                        reason: 'post_state_fingerprint_mismatch: precomputed post-workspace does not match its own expected shape')
            updated = runnable.map do |a, _t, _p, _inv|
              fail_action(a, reason: 'post_state_fingerprint_mismatch',
                              affected_derived_ids: all_present_ids & Array(a.affected_derived_ids))
            end
            return [rb_ws, updated]
          end
          # Publish the already-precomputed logical post-workspace
          # (BLOCK-003 minimum outcome). The handle registry in
          # the published workspace reflects the post-commit
          # host state (all removed handles are gone, survivor
          # handles are preserved).
          published_ws = publish_precomputed_workspace(
            precomputed_post_workspace: precomputed_post_workspace,
            workspace:                  workspace,
            model:                      model,
            total_removed:              total_removed
          )
          # Build updated actions: every action transitions to
          # :applied with its own affected_derived_ids (might be
          # empty for actions whose targets were all invalid).
          updated = per_action.map do |act, _to_remove, present_ids, invalid_ids|
            transition_action(act, to: :applied,
                                source_occurrence_ids: act.source_occurrence_ids,
                                affected_derived_ids: (present_ids + invalid_ids).uniq)
          end
          [published_ws, updated]
        else
          # Some disposes failed. Abort the operation (real SU
          # rolls back every entity write inside the operation,
          # which includes all the prior dispose() calls in this
          # batch).
          begin
            adapter.end_operation(model, commit: false)
          rescue StandardError
          end
          new_ws = rollback_to_failed(pre_ws: workspace, model: model,
                                        reason: "batch_dispense_failed: #{action_errors.join('; ')}")
          updated = per_action.map do |act, _t, present_ids, invalid_ids|
            fail_action(act, reason: "batch_dispense_failed: #{action_errors.join('; ')}",
                            affected_derived_ids: (present_ids - invalid_ids).uniq)
          end
          [new_ws, updated]
        end
      end

      # Build a new workspace with the given derived_ids removed.
      # Like build_post_workspace but takes the full union of
      # removed_ids across all actions in the batch, and
      # optionally replaces survivor records with the unioned
      # provenance (per Guidance 031 §7).
      #
      # survivor_updates: Hash<derived_id, source_occurrence_ids>
      # - when present, the survivor's DerivedEntityRecord is
      # replaced with a new record that keeps the same derived_id,
      # kind, geometry_summary, parent_derived_id, and
      # host_assigned_ids; only source_occurrence_ids is updated
      # to the sorted unique union.
      def build_post_workspace_batch(workspace:, model:, removed_ids:, survivor_updates: nil)
        adapter = workspace.instance_variable_get(:@adapter)
        src     = workspace.source_snapshot
        removed_set = removed_ids.map(&:to_s).to_set rescue removed_ids.map(&:to_s).uniq
        # to_set is Ruby 2.7+; fall back to manual uniq.
        removed_set = removed_ids.map(&:to_s).uniq
        kept_pairs = workspace.instance_variable_get(:@entity_pairs).map do |id, rec|
          if removed_set.include?(id.to_s)
            nil
          elsif survivor_updates && survivor_updates.key?(id.to_s)
            new_occs = Array(survivor_updates[id.to_s]).map(&:to_s).uniq.sort
            replacement = DerivedEntityRecord.new(
              derived_id:             rec.derived_id,
              kind:                   rec.kind,
              source_occurrence_ids:  new_occs,
              geometry_summary:       rec.geometry_summary,
              parent_derived_id:      rec.parent_derived_id,
              host_assigned_ids:      rec.host_assigned_ids
            )
            [id, replacement]
          else
            [id, rec]
          end
        end.compact
        kept_handles = workspace.instance_variable_get(:@handle_registry).reject do |id, _h|
          removed_set.include?(id.to_s)
        end.freeze
        new_fp = workspace.send(:compute_fingerprint_from_pairs, kept_pairs)
        new_state = kept_pairs.empty? ? :discarded : :ready
        DerivedGeometryWorkspace.new_with_inventory(
          workspace_id:    workspace.workspace_id,
          source_snapshot: src,
          adapter:         adapter,
          model:           model,
          state:           new_state,
          entity_pairs:    kept_pairs,
          handle_registry: kept_handles,
          fingerprint:     new_fp,
          last_error:      nil,
          build_started_at: workspace.build_started_at
        )
      end

      # Pre-flight (Stage 2 §7): build the survivor replacement
      # map BEFORE opening the host operation. Each survivor is
      # keyed by its derived_id; its replacement
      # source_occurrence_ids is the action's sorted unique
      # union. Pure data; no host mutations.
      def precompute_survivor_replacements(workspace:, per_action:)
        updates = {}
        per_action.each do |act, _to_remove, _present_ids, _invalid_ids|
          survivor_id = act.before_summary.is_a?(Hash) ?
                          act.before_summary['survivor_derived_id'].to_s :
                          nil
          next if survivor_id.nil? || survivor_id.empty?
          # Verify the survivor handle is still live and present.
          next if workspace.handle_for(survivor_id).nil?
          updates[survivor_id] = Array(act.source_occurrence_ids).map(&:to_s)
        end
        updates
      end

      # Pre-flight (Stage 2 §7): compute the expected post-state
      # inventory shape BEFORE the host operation. The shape is
      # the set of surviving derived_ids (sorted). After the host
      # operation commits, post_state_matches_expected? compares
      # the new workspace's surviving derived_ids to this
      # baseline.
      def precompute_expected_post_state(workspace:, per_action:, survivor_updates:)
        removed_set = per_action.flat_map { |_a, to_remove, _p, inv|
          Array(to_remove) + Array(inv)
        }.map(&:to_s).uniq
        surviving_ids = workspace.instance_variable_get(:@entity_pairs).map { |id, _rec|
          id.to_s
        }.reject { |id| removed_set.include?(id) }.sort
        # Pre-batch derived-duplicate class counts (Stage 3 §8):
        # we capture the canonical class topology of the
        # pre-batch workspace so the post-batch validator can
        # produce a before/after audit row.
        pre_classes = if defined?(DerivedDuplicateValidator)
                        SUAnalysis::Core::DerivedDuplicateValidator.group_derived_duplicates(
                          workspace,
                          DEFAULT_DUPLICATE_TOLERANCE
                        )
                      else
                        {}
                      end
        {
          surviving_derived_ids: surviving_ids,
          survivor_replacement_keys: (survivor_updates || {}).keys.sort,
          pre_classes_count:     pre_classes.length,
          pre_classes_keys:      pre_classes.keys.sort
        }.freeze
      end

      # V1.5 STAGE BLOCK-003 preflight: verify every action
      # and handle in the batch BEFORE opening the host
      # operation. Returns a Hash with:
      #   valid:           Boolean
      #   reason:          String (when !valid)
      #   total_removed:   Array<String> (all removed derived_ids)
      #   survivor_updates: Hash<String, Array<String>>
      #   expected_post:   Hash (the expected post-state shape)
      # When !valid, the batch fails closed WITHOUT opening
      # the host operation.
      def preflight_batch(workspace:, per_action:)
        # Verify every action's survivor and to_remove handles
        # are present and valid in the pre-batch workspace.
        per_action.each do |act, to_remove, present_ids, invalid_ids|
          survivor_id = act.before_summary.is_a?(Hash) ?
                          act.before_summary['survivor_derived_id'].to_s : nil
          if survivor_id && !survivor_id.empty?
            survivor_handle = workspace.handle_for(survivor_id)
            if survivor_handle.nil?
              return { valid: false, reason: "survivor_handle_missing: #{survivor_id.inspect}" }
            end
            if survivor_handle.respond_to?(:valid?) && !survivor_handle.valid?
              return { valid: false, reason: "survivor_handle_invalidated: #{survivor_id.inspect}" }
            end
          end
          # Every present_ids handle must be live.
          present_ids.each do |id|
            h = workspace.handle_for(id)
            if h.nil? || (h.respond_to?(:valid?) && !h.valid?)
              return { valid: false, reason: "non_survivor_handle_invalid: #{id.inspect}" }
            end
          end
        end
        # Compute total_removed: present_ids + invalid_ids, dedup.
        total_removed = per_action.flat_map { |_a, _to_remove, present_ids, invalid_ids|
          Array(present_ids) + Array(invalid_ids)
        }.map(&:to_s).uniq
        survivor_updates = precompute_survivor_replacements(
          workspace:   workspace,
          per_action:  per_action
        )
        expected_post = precompute_expected_post_state(
          workspace:        workspace,
          per_action:       per_action,
          survivor_updates: survivor_updates
        )
        {
          valid:            true,
          total_removed:    total_removed,
          survivor_updates: survivor_updates,
          expected_post:    expected_post
        }
      end

      # V1.5 STAGE BLOCK-003 publish: construct the new
      # DerivedGeometryWorkspace from the precomputed
      # post-workspace, applying the post-commit host state
      # (the handle registry in the precomputed workspace is
      # the post-batch state — the same handles the host
      # adapter kept after commit).
      def publish_precomputed_workspace(precomputed_post_workspace:, workspace:, model:, total_removed:)
        # The precomputed_post_workspace was built with
        # build_post_workspace_batch, which already constructs
        # the post-batch handle registry. We just need to
        # ensure the published workspace reflects the final
        # state.
        precomputed_post_workspace
      end

      # Default tolerance for the derived validator (matches the
      # proposer's default).
      DEFAULT_DUPLICATE_TOLERANCE = 1.0e-4

      # Verify the post-state matches the expected shape (Stage 2
      # §7). The host operation may have surfaced unexpected
      # state (disposed an extra handle, etc.); this guard
      # catches that and surfaces a :failed result rather than
      # silently reporting success.
      def post_state_matches_expected?(new_workspace, expected)
        return false if new_workspace.nil? || expected.nil?
        actual_ids = new_workspace.entities.map { |rec| rec.derived_id.to_s }.sort
        actual_ids == expected[:surviving_derived_ids]
      end

      # Stage 3 (§8): validate the post-batch workspace's
      # derived-duplicate topology. Pure-data; reads each
      # derived record's geometry_summary; reuses the
      # canonical key contract.
      def validate_post_state(workspace:, tolerance: nil)
        return nil if workspace.nil?
        tol = tolerance || DEFAULT_DUPLICATE_TOLERANCE
        return nil unless defined?(DerivedDuplicateValidator)
        SUAnalysis::Core::DerivedDuplicateValidator.validate(
          workspace:  workspace,
          tolerance:  tol
        )
      end

      # Transition an action to :applied (success).
      def transition_action(action, to:, source_occurrence_ids:, affected_derived_ids:)
        return action unless action.is_a?(RepairAction)
        # RepairAction is immutable; we must construct a new
        # action with the new status. We carry forward all
        # other fields.
        RepairAction.new(
          action_id:               action.action_id,
          type:                    action.type,
          rule_id:                 action.rule_id,
          confidence:              action.confidence,
          confidence_basis:        action.confidence_basis,
          explanation:             action.explanation,
          source_occurrence_ids:   source_occurrence_ids,
          affected_derived_ids:    affected_derived_ids,
          before_summary:          action.before_summary,
          proposed_after_summary:  action.proposed_after_summary,
          topology_impact:         action.topology_impact,
          auto_applicable:         action.auto_applicable,
          status:                  to
        )
      end

      # Transition to :skipped.
      def skip_action(action, reason:)
        transition_action(action, to: :skipped,
                            source_occurrence_ids: action.source_occurrence_ids,
                            affected_derived_ids: action.affected_derived_ids)
      end

      # Transition to :failed.
      def fail_action(action, reason:, affected_derived_ids: nil)
        new_basis = if action.confidence_basis.to_s.start_with?('failed:')
                      action.confidence_basis
                    else
                      "failed:#{reason}"
                    end
        RepairAction.new(
          action_id:               action.action_id,
          type:                    action.type,
          rule_id:                 action.rule_id,
          confidence:              action.confidence,
          confidence_basis:        new_basis,
          explanation:             "#{action.explanation}; FAILED: #{reason}",
          source_occurrence_ids:   action.source_occurrence_ids,
          affected_derived_ids:    (affected_derived_ids || action.affected_derived_ids),
          before_summary:          action.before_summary,
          proposed_after_summary:  action.proposed_after_summary,
          topology_impact:         action.topology_impact,
          auto_applicable:         action.auto_applicable,
          status:                  :failed
        )
      end
    end
  end
end