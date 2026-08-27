#
# core/duplicate_repair_executor.rb — V1.5 Round-4
#
# Derived-only executor for the :remove_duplicate_edge action.
#
# Round-4 changes (AIPM §5 BLOCK-003 + §6 BLOCK-004):
#
#   * BEFORE opening a host operation, the executor builds the
#     COMPLETE expected post-state via
#     `DuplicateRepairExpectedPostState.build` and validates
#     every invariant (inventory, removed/survivors,
#     provenance unions, geometry/fingerprint, handle shape,
#     applied-class absence). A failure => begin_calls=0,
#     workspace unchanged, every action :failed.
#
#   * IMMEDIATELY before opening a host operation the executor
#     re-checks the live-handle proof on every member of every
#     runnable action (current distinct live handles,
#     survivor/removed disjointness). A failure => begin_calls=0.
#
#   * On commit uncertainty / failure, the workspace
#     transitions to :failed; no claim of "rolled back"; no
#     false READY publication. Recovery evidence is preserved.
#
#   * Captured tolerance flows through apply_batch into the
#     expected post-state. No silent fallback to defaults.
#
#   * Pair metric uses `DuplicateGeometrySemantics.
#     enumerate_direct_pairs` for direct-pair evidence
#     (BLOCK-004 minimum: unique unordered direct-match
#     pairs).
#
# Source entities are NEVER touched. Derived mutations are
# atomic with respect to the host operation boundary.
#

require_relative 'repair_plan'
require_relative 'derived_geometry_workspace'
require_relative 'derived_duplicate_validator'
require_relative 'duplicate_repair_expected_post_state'
require_relative 'duplicate_geometry_semantics'

module SUAnalysis
  module Core
    module DuplicateRepairExecutor
      module_function

      DEFAULT_DUPLICATE_TOLERANCE = DuplicateGeometrySemantics::DEFAULT_TOLERANCE

      # ------------------------------------------------------------
      # Public: apply a single :remove_duplicate_edge action.
      # Returns [updated_workspace, updated_action].
      # ------------------------------------------------------------
      def apply(workspace:, action:)
        return [workspace, action] if workspace.nil?
        return [workspace, action] if action.nil?
        unless action.type == :remove_duplicate_edge
          return [workspace, action]
        end
        unless [:validated, :proposed].include?(action.status)
          return [workspace, action]
        end
        to_remove = Array(action.affected_derived_ids).map(&:to_s).uniq
        if to_remove.all? { |id| workspace.handle_for(id).nil? }
          return [workspace, skip_action(action, reason: 'already_applied')]
        end
        present = to_remove.select { |id| !workspace.handle_for(id).nil? }
        if present.empty?
          return [workspace, skip_action(action, reason: 'affected_derived_ids_not_in_workspace')]
        end
        apply_atomic(workspace: workspace, action: action, to_remove: present)
      end

      # ------------------------------------------------------------
      # Public: apply_batch (used by WorkingModeRunner and tests).
      # ------------------------------------------------------------
      def apply_batch(workspace:, plan:)
        return [workspace, []] if workspace.nil?
        return [workspace, []] if plan.nil?
        actions = Array(plan.actions)
        runnable = actions.select do |a|
          a.is_a?(RepairAction) &&
            a.type == :remove_duplicate_edge &&
            [:validated, :proposed].include?(a.status)
        end
        # The runner's audit must include pre-execution
        # :skipped rows from the plan even when no runnable
        # actions remain. Capture them here.
        all_skipped = actions.select { |a|
          a.is_a?(RepairAction) && a.status == :skipped
        }
        if runnable.empty?
          return [workspace, all_skipped]
        end
        all_gone = runnable.all? do |a|
          Array(a.affected_derived_ids).all? { |id| workspace.handle_for(id).nil? }
        end
        if all_gone
          updated = runnable.map { |a| skip_action(a, reason: 'already_applied') }
          return [workspace, updated + all_skipped]
        end
        apply_batch_atomic(workspace: workspace, runnable: runnable, pre_skipped: all_skipped)
      end

      # ------------------------------------------------------------
      # Batch atomic implementation.
      # ------------------------------------------------------------
      def apply_batch_atomic(workspace:, runnable:, pre_skipped: [])
        adapter = workspace.instance_variable_get(:@adapter)
        model   = workspace.instance_variable_get(:@model)
        # Capture the captured tolerance EXPLICITLY (no
        # silent fallback). The expected post-state uses this
        # same value.
        captured_tol = DuplicateGeometrySemantics.resolve_captured_tolerance(workspace)
        unless DuplicateGeometrySemantics.valid_tolerance?(captured_tol)
          updated = runnable.map { |a| fail_action(a, reason: 'invalid_or_missing_captured_tolerance', affected_derived_ids: Array(a.affected_derived_ids)) }
          new_ws = rollback_to_failed(pre_ws: workspace, model: model, reason: 'invalid_or_missing_captured_tolerance')
          return [new_ws, updated + pre_skipped]
        end
        # Pre-compute (action, to_remove, present, invalid).
        per_action = runnable.map do |act|
          to_remove = Array(act.affected_derived_ids).map(&:to_s).uniq
          invalid_ids = to_remove.select { |id|
            h = workspace.handle_for(id)
            h.respond_to?(:valid?) ? !h.valid? : false
          }
          present_ids = to_remove.reject do |id|
            h = workspace.handle_for(id)
            h.nil? || (h.respond_to?(:valid?) && !h.valid?)
          end
          [act, to_remove, present_ids, invalid_ids]
        end
        # Pre-flight (BLOCK-001 live-handle proof re-check +
        # BLOCK-003 invariant checks). Run BEFORE opening the
        # host operation. Per Round-5 §2, this validates the
        # COMPLETE expected member set, not just filtered
        # successful handles.
        preflight = preflight_batch(workspace: workspace, per_action: per_action, captured_tolerance: captured_tol)
        unless preflight[:valid]
          updated = runnable.map { |a| fail_action(a, reason: "preflight_failed: #{preflight[:reason]}", affected_derived_ids: Array(a.affected_derived_ids)) }
          new_ws = rollback_to_failed(pre_ws: workspace, model: model, reason: "preflight_failed: #{preflight[:reason]}")
          return [new_ws, updated + pre_skipped]
        end
        # Build the COMPLETE expected post-state (BLOCK-003)
        # using the SAME captured tolerance.
        expected_post = DuplicateRepairExpectedPostState.build(
          workspace:        workspace,
          applied_actions:  runnable,
          captured_tolerance: captured_tol,
          candidate_pair_count_before: preflight[:candidate_pair_count_before]
        )
        unless expected_post['valid']
          # Logic error in preflight OR mismatched state. Fail
          # closed WITHOUT opening the host operation.
          updated = runnable.map { |a| fail_action(a, reason: "expected_post_state_invalid: #{expected_post['reason']}", affected_derived_ids: Array(a.affected_derived_ids)) }
          new_ws = rollback_to_failed(pre_ws: workspace, model: model, reason: "expected_post_state_invalid: #{expected_post['reason']}")
          return [new_ws, updated + pre_skipped]
        end
        # Round-5 BLOCK-001 §2 step 4: re-run the COMPLETE
        # live-handle proof immediately before opening the
        # host operation. Per AIPM §2 step 4: "After
        # expected-state validation, rerun this proof for the
        # WHOLE executable batch."
        final_proof = final_live_handle_proof(workspace: workspace, per_action: per_action)
        unless final_proof[:valid]
          # Atomic no-begin failure (BLOCK-001 step 5..8):
          # begin=0, no disposal/commit, no applied rows,
          # exact logical pre-state retained, no READY.
          updated = runnable.map { |a| fail_action(a, reason: "final_live_handle_proof_failed: #{final_proof[:reason]}", affected_derived_ids: Array(a.affected_derived_ids)) }
          new_ws = rollback_to_failed(pre_ws: workspace, model: model, reason: "final_live_handle_proof_failed: #{final_proof[:reason]}")
          return [new_ws, updated + pre_skipped]
        end
        # Precompute the post-workspace from the pure-data
        # expected state. The published workspace is THIS
        # workspace after a successful commit.
        precomputed_post_workspace = build_post_workspace_batch(
          workspace:        workspace,
          model:            model,
          removed_ids:      expected_post['removed_derived_ids'],
          survivor_updates: expected_post['survivor_provenance_unions']
        )
        # Open the host operation.
        begin
          adapter.begin_operation(model, label: 'SU-AI-Plugin: V1.5 Duplicate Repair Batch')
        rescue StandardError => e
          updated = runnable.map { |a| fail_action(a, reason: "begin_operation_failed: #{e.class}: #{e.message}", affected_derived_ids: Array(a.affected_derived_ids)) }
          new_ws = rollback_to_failed(pre_ws: workspace, model: model, reason: "begin_operation_failed: #{e.class}: #{e.message}")
          return [new_ws, updated + pre_skipped]
        end
        # Dispose every present handle.
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
              break
            end
          end
          break unless action_errors.empty?
        end
        if action_errors.empty?
          # BLOCK-003 PRECOMMIT host-shape observation.
          # Re-verify against the live host state immediately
          # before commit. Per AIPM §5 step 6:
          #   - survivors still live/valid
          #   - planned removals observably no longer live/valid
          #   - identities still match the proven batch
          #   - no survivor accidentally disposed
          # Mismatch => abort exactly once, commit=0, no
          # post-state publish, exact logical pre-state,
          # failed/non-ready.
          precommit = precommit_host_shape_observation(
            workspace: workspace,
            per_action: per_action,
            adapter: adapter,
            model: model
          )
          unless precommit[:valid]
            begin
              adapter.end_operation(model, commit: false)
            rescue StandardError
            end
            updated = runnable.map { |a| fail_action(a, reason: "precommit_host_shape_mismatch: #{precommit[:reason]}", affected_derived_ids: Array(a.affected_derived_ids)) }
            new_ws = rollback_to_failed(pre_ws: workspace, model: model, reason: "precommit_host_shape_mismatch: #{precommit[:reason]}")
            return [new_ws, updated + pre_skipped]
          end
          # Commit the operation. BLOCK-003: success path
          # publishes the already-precomputed logical
          # post-workspace. A successful commit means the
          # expected post-state was already proven consistent
          # in pure data before the host operation opened.
          begin
            adapter.end_operation(model, commit: true)
          rescue StandardError => e
            # Commit failed -> :failed workspace. No
            # follow-up end_operation(commit: false): the
            # host either auto-rolled-back its own operation
            # (real SU) or never opened one (fake adapter).
            # Per AIPM §5 step 9: commit uncertainty =>
            # failed/non-ready; preserve evidence; do NOT
            # fabricate successful rollback.
            new_ws = rollback_to_failed(pre_ws: workspace, model: model, reason: "commit_operation_failed: #{e.class}: #{e.message}")
            updated = runnable.map { |a| fail_action(a, reason: "commit_operation_failed: #{e.class}: #{e.message}", affected_derived_ids: all_present_ids & Array(a.affected_derived_ids)) }
            return [new_ws, updated + pre_skipped]
          end
          # Publish the precomputed post-workspace.
          published_ws = publish_precomputed_workspace(
            precomputed_post_workspace: precomputed_post_workspace,
            workspace:                  workspace,
            model:                      model,
            total_removed:              expected_post['removed_derived_ids']
          )
          updated = per_action.map do |act, _to_remove, present_ids, invalid_ids|
            transition_action(act, to: :applied,
                                source_occurrence_ids: act.source_occurrence_ids,
                                affected_derived_ids: (present_ids + invalid_ids).uniq)
          end
          [published_ws, updated + pre_skipped]
        else
          # Some disposes failed. Abort the operation; the
          # host rolls back every entity write inside it.
          begin
            adapter.end_operation(model, commit: false)
          rescue StandardError
          end
          new_ws = rollback_to_failed(pre_ws: workspace, model: model, reason: "batch_dispense_failed: #{action_errors.join('; ')}")
          updated = per_action.map do |act, _t, present_ids, invalid_ids|
            fail_action(act, reason: "batch_dispense_failed: #{action_errors.join('; ')}", affected_derived_ids: (present_ids - invalid_ids).uniq)
          end
          [new_ws, updated + pre_skipped]
        end
      end

      # ------------------------------------------------------------
      # Pre-flight (BLOCK-001 + BLOCK-003): per-action live-
      # handle proof + handle validity + tolerance + capture
      # the pre-batch candidate_pair_count.
      #
      # Round-5 §2: validates the COMPLETE expected member
      # set from each action, not just filtered successful
      # handles. Every action's expected member IDs =
      # survivor + all removals. Each one resolves to exactly
      # one current host handle; any missing member is
      # failure; any `valid? != true` is failure; all handles
      # pairwise distinct by `equal?` (survivor/removal AND
      # removal/removal); survivor appears exactly once and
      # is not in removal set.
      # ------------------------------------------------------------
      def preflight_batch(workspace:, per_action:, captured_tolerance: nil)
        # Captured tolerance explicit. Per Round-5 §3 the
        # category check is more permissive (>= 0.0 valid).
        tol = captured_tolerance || DuplicateGeometrySemantics.resolve_captured_tolerance(workspace)
        unless DuplicateGeometrySemantics.valid_tolerance?(tol)
          return { valid: false, reason: 'invalid_or_missing_captured_tolerance' }
        end
        # Live-handle proof: every action's survivor and
        # to_remove handles must be present, valid, distinct,
        # and survivor/removed disjoint. Per Round-5 §2 step 1,
        # the COMPLETE expected member set is validated -- not
        # just the filtered present set.
        per_action.each do |act, to_remove, _present_ids, _invalid_ids|
          survivor_id = act.before_summary.is_a?(Hash) ?
                          act.before_summary['survivor_derived_id'].to_s : nil
          survivor_handle = nil
          # (1) survivor resolves to exactly one current host
          # handle; missing OR invalid => failure.
          if survivor_id && !survivor_id.empty?
            survivor_handle = workspace.handle_for(survivor_id)
            if survivor_handle.nil?
              return { valid: false, reason: "survivor_handle_missing: #{survivor_id.inspect}" }
            end
            if survivor_handle.respond_to?(:valid?) && !survivor_handle.valid?
              return { valid: false, reason: "survivor_handle_invalidated: #{survivor_id.inspect}" }
            end
          end
          # (2) Every to_remove member resolves to exactly
          # one current host handle. Per Round-5 §2 step 2,
          # ANY missing member is failure -- not filtered out.
          to_remove.each do |id|
            h = workspace.handle_for(id)
            if h.nil?
              return { valid: false, reason: "non_survivor_handle_missing: #{id.inspect}" }
            end
            if h.respond_to?(:valid?) && !h.valid?
              return { valid: false, reason: "non_survivor_handle_invalidated: #{id.inspect}" }
            end
          end
          # (3) Survivor appears exactly once and is not in
          # removal set.
          if survivor_id && !survivor_id.empty? && to_remove.include?(survivor_id)
            return { valid: false, reason: "survivor_present_in_removal_set: #{survivor_id.inspect}" }
          end
          # (4) All handles pairwise distinct by object
          # identity (`equal?`). Check survivor/removal AND
          # removal/removal alias.
          all_handles = {}
          if survivor_id && !survivor_id.empty?
            all_handles[survivor_id] = survivor_handle
          end
          to_remove.each do |id|
            h = workspace.handle_for(id)
            all_handles[id] = h
          end
          # Pairwise equal? check.
          ids = all_handles.keys
          ids.combination(2).each do |a, b|
            ha = all_handles[a]
            hb = all_handles[b]
            next if ha.nil? || hb.nil?
            if ha.equal?(hb)
              return { valid: false, reason: "host_handle_aliasing: #{a.inspect} <-> #{b.inspect}" }
            end
          end
        end
        # Measure the pre-batch candidate_pair_count (for the
        # expected post-state's `before` metric). The expected
        # post-state recomputes `after` from the post-state
        # itself; we only need the `before` count here.
        records = workspace.respond_to?(:entities) ? workspace.entities : []
        records = records.select { |r| r.is_a?(SUAnalysis::Core::DerivedEntityRecord) && r.kind == :edge }
        candidate_pair_count_before = DuplicateGeometrySemantics.count_direct_pairs(records, tol)
        {
          valid:                          true,
          captured_tolerance:             tol,
          candidate_pair_count_before:    candidate_pair_count_before
        }
      end

      # ------------------------------------------------------------
      # FINAL live-handle proof (Round-5 BLOCK-001 §2 step 4).
      # Re-runs the complete live-handle proof for the WHOLE
      # executable batch IMMEDIATELY BEFORE begin_operation,
      # AFTER expected-state validation. Per AIPM §2:
      #   - complete expected member set (survivor + removals)
      #   - every member resolves to exactly one host handle
      #   - any missing OR `valid? != true` is failure
      #   - all handles pairwise distinct by `equal?` (incl.
      #     removal/removal)
      #   - survivor appears exactly once and not in removal
      # Failure => atomic no-begin failure: begin=0, no
      # disposal, no commit, no applied rows, exact logical
      # pre-state retained, no READY, truthful stable reason
      # code.
      # ------------------------------------------------------------
      def final_live_handle_proof(workspace:, per_action:)
        per_action.each do |act, to_remove, _present_ids, _invalid_ids|
          survivor_id = act.before_summary.is_a?(Hash) ?
                          act.before_summary['survivor_derived_id'].to_s : nil
          survivor_handle = nil
          if survivor_id && !survivor_id.empty?
            survivor_handle = workspace.handle_for(survivor_id)
            if survivor_handle.nil?
              return { valid: false, reason: "survivor_handle_missing: #{survivor_id.inspect}" }
            end
            if survivor_handle.respond_to?(:valid?) && !survivor_handle.valid?
              return { valid: false, reason: "survivor_handle_invalidated: #{survivor_id.inspect}" }
            end
          end
          # Each to_remove member resolves to exactly one
          # current host handle.
          to_remove.each do |id|
            h = workspace.handle_for(id)
            if h.nil?
              return { valid: false, reason: "non_survivor_handle_missing: #{id.inspect}" }
            end
            if h.respond_to?(:valid?) && !h.valid?
              return { valid: false, reason: "non_survivor_handle_invalidated: #{id.inspect}" }
            end
          end
          # Survivor appears exactly once and is not in the
          # removal set.
          if survivor_id && !survivor_id.empty? && to_remove.include?(survivor_id)
            return { valid: false, reason: "survivor_present_in_removal_set: #{survivor_id.inspect}" }
          end
          # All handles pairwise distinct by `equal?` (incl.
          # removal/removal alias).
          all_handles = {}
          all_handles[survivor_id] = survivor_handle if survivor_id && !survivor_id.empty?
          to_remove.each { |id| all_handles[id] = workspace.handle_for(id) }
          ids = all_handles.keys
          ids.combination(2).each do |a, b|
            ha = all_handles[a]
            hb = all_handles[b]
            next if ha.nil? || hb.nil?
            if ha.equal?(hb)
              return { valid: false, reason: "host_handle_aliasing: #{a.inspect} <-> #{b.inspect}" }
            end
          end
        end
        { valid: true }
      end

      # ------------------------------------------------------------
      # PRECOMMIT host-shape observation (Round-5 BLOCK-003 §5
      # step 6). After disposal but before commit, re-verify
      # the live host state:
      #   - survivors still live/valid
      #   - planned removals observably no longer live/valid
      #   - identities still match the proven batch
      #   - no survivor accidentally disposed
      # Mismatch => abort exactly once, commit=0, no
      # post-state publish, exact logical pre-state,
      # failed/non-ready.
      # ------------------------------------------------------------
      def precommit_host_shape_observation(workspace:, per_action:, adapter:, model:)
        per_action.each do |act, to_remove, _present_ids, _invalid_ids|
          survivor_id = act.before_summary.is_a?(Hash) ?
                          act.before_summary['survivor_derived_id'].to_s : nil
          # (1) Survivors still live/valid.
          if survivor_id && !survivor_id.empty?
            sh = workspace.handle_for(survivor_id)
            if sh.nil? || (sh.respond_to?(:valid?) && !sh.valid?)
              return { valid: false, reason: "precommit_survivor_handle_not_live: #{survivor_id.inspect}" }
            end
          end
          # (2) Planned removals observably no longer live/valid.
          to_remove.each do |id|
            h = workspace.handle_for(id)
            if h.nil?
              # handle was cleared by dispose -- expected.
              next
            end
            if h.respond_to?(:valid?) && !h.valid?
              # handle invalidated by dispose -- expected.
              next
            end
            # Handle still appears live/valid after dispose --
            # this is a host-shape mismatch.
            return { valid: false, reason: "precommit_removal_handle_still_live: #{id.inspect}" }
          end
          # (3) Identities still match the proven batch.
          # This is the same check as the live-handle proof
          # (handles must still be distinct by equal?).
          all_handles = {}
          all_handles[survivor_id] = workspace.handle_for(survivor_id) if survivor_id && !survivor_id.empty?
          to_remove.each { |id| all_handles[id] = workspace.handle_for(id) }
          ids = all_handles.keys
          ids.combination(2).each do |a, b|
            ha = all_handles[a]
            hb = all_handles[b]
            next if ha.nil? || hb.nil?
            if ha.equal?(hb)
              return { valid: false, reason: "precommit_handle_aliasing: #{a.inspect} <-> #{b.inspect}" }
            end
          end
        end
        { valid: true }
      end

      # ------------------------------------------------------------
      # Post-batch workspace builder.
      # ------------------------------------------------------------
      def build_post_workspace_batch(workspace:, model:, removed_ids:, survivor_updates: nil)
        adapter = workspace.instance_variable_get(:@adapter)
        src     = workspace.source_snapshot
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

      def publish_precomputed_workspace(precomputed_post_workspace:, workspace:, model:, total_removed:)
        precomputed_post_workspace
      end

      # ------------------------------------------------------------
      # Single-action atomic apply.
      # ------------------------------------------------------------
      def apply_atomic(workspace:, action:, to_remove:)
        adapter = workspace.instance_variable_get(:@adapter)
        model   = workspace.instance_variable_get(:@model)
        # Capture the captured tolerance for the single-
        # action preflight.
        captured_tol = DuplicateGeometrySemantics.resolve_captured_tolerance(workspace)
        unless DuplicateGeometrySemantics.valid_tolerance?(captured_tol)
          return [
            workspace,
            fail_action(action, reason: 'invalid_or_missing_captured_tolerance')
          ]
        end
        # Live-handle proof re-check on this single action.
        survivor_id = action.before_summary.is_a?(Hash) ? action.before_summary['survivor_derived_id'].to_s : nil
        if survivor_id && !survivor_id.empty?
          sh = workspace.handle_for(survivor_id)
          if sh.nil? || (sh.respond_to?(:valid?) && !sh.valid?)
            return [
              workspace,
              fail_action(action, reason: "survivor_handle_invalid: #{survivor_id.inspect}")
            ]
          end
        end
        disposable_handles = to_remove.map { |id| [id, workspace.handle_for(id)] }
        valid_pairs = disposable_handles.select do |_id, handle|
          handle.respond_to?(:valid?) ? handle.valid? : true
        end
        invalid_ids = disposable_handles.reject { |id, h| valid_pairs.any? { |vid, _vh| vid == id } }.map(&:first)
        begin
          adapter.begin_operation(model, label: 'SU-AI-Plugin: V1.5 Duplicate Repair Apply')
        rescue StandardError => e
          return [
            workspace,
            fail_action(action, reason: "begin_operation_failed: #{e.class}: #{e.message}")
          ]
        end
        dispose_errors = []
        valid_pairs.each do |id, handle|
          begin
            adapter.dispose(handle)
          rescue StandardError => e
            dispose_errors << "#{id.inspect}: #{e.class}: #{e.message}"
          end
        end
        if dispose_errors.empty?
          begin
            adapter.end_operation(model, commit: true)
          rescue StandardError => e
            begin
              adapter.end_operation(model, commit: false)
            rescue StandardError
            end
            new_ws = rollback_to_failed(pre_ws: workspace, model: model, reason: "commit_operation_failed: #{e.class}: #{e.message}")
            return [new_ws, fail_action(action, reason: "commit_operation_failed: #{e.class}: #{e.message}")]
          end
          removed_ids = valid_pairs.map(&:first)
          kept_ids = Array(workspace.entities.map(&:derived_id)).map(&:to_s) - removed_ids
          total_removed = (removed_ids + invalid_ids).uniq
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
          begin
            adapter.end_operation(model, commit: false)
          rescue StandardError
          end
          new_ws = rollback_to_failed(pre_ws: workspace, model: model, reason: "dispose_failed: #{dispose_errors.join('; ')}")
          updated_action = fail_action(action, reason: "dispose_failed: #{dispose_errors.join('; ')}", affected_derived_ids: (valid_pairs.map(&:first) - invalid_ids))
          [new_ws, updated_action]
        end
      end

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

      # ------------------------------------------------------------
      # Compatibility helpers.
      # ------------------------------------------------------------
      def precompute_survivor_replacements(workspace:, per_action:)
        updates = {}
        per_action.each do |act, _to_remove, _present_ids, _invalid_ids|
          survivor_id = act.before_summary.is_a?(Hash) ?
                          act.before_summary['survivor_derived_id'].to_s :
                          nil
          next if survivor_id.nil? || survivor_id.empty?
          next if workspace.handle_for(survivor_id).nil?
          updates[survivor_id] = Array(act.source_occurrence_ids).map(&:to_s)
        end
        updates
      end

      def precompute_expected_post_state(workspace:, per_action:, survivor_updates:)
        removed_set = per_action.flat_map { |_a, to_remove, _p, inv|
          Array(to_remove) + Array(inv)
        }.map(&:to_s).uniq
        surviving_ids = workspace.instance_variable_get(:@entity_pairs).map { |id, _rec|
          id.to_s
        }.reject { |id| removed_set.include?(id) }.sort
        tol = DuplicateGeometrySemantics.resolve_captured_tolerance(workspace)
        unless DuplicateGeometrySemantics.valid_tolerance?(tol)
          tol = DEFAULT_DUPLICATE_TOLERANCE
        end
        records = workspace.respond_to?(:entities) ? workspace.entities : []
        records = records.select { |r| r.is_a?(SUAnalysis::Core::DerivedEntityRecord) && r.kind == :edge }
        pre_classes = nil
        if defined?(SUAnalysis::Core::DerivedDuplicateValidator)
          pre_classes = SUAnalysis::Core::DerivedDuplicateValidator.group_derived_duplicates(
            workspace,
            tol
          )
        end
        {
          surviving_derived_ids:    surviving_ids,
          survivor_replacement_keys: (survivor_updates || {}).keys.sort,
          pre_classes_count:        pre_classes.is_a?(Hash) ? pre_classes.length : 0,
          pre_classes_keys:         pre_classes.is_a?(Hash) ? pre_classes.keys.sort : [],
          captured_tolerance:       tol
        }.freeze
      end

      def validate_post_state(workspace:, tolerance: nil)
        return nil if workspace.nil?
        tol = tolerance || DuplicateGeometrySemantics.resolve_captured_tolerance(workspace)
        return nil unless DuplicateGeometrySemantics.valid_tolerance?(tol)
        SUAnalysis::Core::DerivedDuplicateValidator.validate(
          workspace:  workspace,
          tolerance:  tol
        )
      end

      def post_state_matches_expected?(new_workspace, expected)
        return false if new_workspace.nil? || expected.nil?
        actual_ids = new_workspace.entities.map { |rec| rec.derived_id.to_s }.sort
        return false unless actual_ids == expected[:surviving_derived_ids]
        survivor_keys = (expected[:survivor_replacement_keys] || []).sort
        return false if survivor_keys.empty?
        true
      end

      # ------------------------------------------------------------
      # Action lifecycle transitions.
      # ------------------------------------------------------------
      def transition_action(action, to:, source_occurrence_ids:, affected_derived_ids:)
        return action unless action.is_a?(RepairAction)
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

      def skip_action(action, reason:)
        transition_action(
          action,
          to: :skipped,
          source_occurrence_ids: action.source_occurrence_ids,
          affected_derived_ids:   action.affected_derived_ids
        )
      end

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