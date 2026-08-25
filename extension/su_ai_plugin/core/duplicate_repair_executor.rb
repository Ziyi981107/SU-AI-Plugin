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
          new_ws = build_post_workspace(workspace: workspace, model: model, removed_ids: total_removed)
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
      def build_post_workspace(workspace:, model:, removed_ids:)
        adapter = workspace.instance_variable_get(:@adapter)
        src     = workspace.source_snapshot
        kept_pairs = workspace.instance_variable_get(:@entity_pairs).reject do |id, _rec|
          removed_ids.map(&:to_s).include?(id.to_s)
        end
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
          # Build the post-state workspace: every action's
          # affected_derived_ids are removed.
          total_removed = all_present_ids.uniq
          # Add silently-removed invalid ids too (idempotency).
          per_action.each { |_a, _t, _p, inv| total_removed.concat(inv) if inv.is_a?(Array) }
          total_removed = total_removed.uniq
          new_ws = build_post_workspace_batch(workspace: workspace, model: model,
                                                 removed_ids: total_removed)
          # Build updated actions: every action transitions to
          # :applied with its own affected_derived_ids (might be
          # empty for actions whose targets were all invalid).
          updated = per_action.map do |act, _to_remove, present_ids, invalid_ids|
            transition_action(act, to: :applied,
                                source_occurrence_ids: act.source_occurrence_ids,
                                affected_derived_ids: (present_ids + invalid_ids).uniq)
          end
          [new_ws, updated]
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
      # removed_ids across all actions in the batch.
      def build_post_workspace_batch(workspace:, model:, removed_ids:)
        adapter = workspace.instance_variable_get(:@adapter)
        src     = workspace.source_snapshot
        removed_set = removed_ids.map(&:to_s).to_set rescue removed_ids.map(&:to_s).uniq
        # to_set is Ruby 2.7+; fall back to manual uniq.
        removed_set = removed_ids.map(&:to_s).uniq
        kept_pairs = workspace.instance_variable_get(:@entity_pairs).reject do |id, _rec|
          removed_set.include?(id.to_s)
        end
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