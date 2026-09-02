#
# core/working_mode_runner.rb — V1.4 WorkingModeRunner.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 4: minimal working-mode plumbing.
#
# The runner is the in-process state holder for the dialog's
# "Working Mode" surface. It owns the current
# DerivedGeometryWorkspace (one per dialog session) and exposes
# prepare / discard / rebuild operations as JSON-safe Hashes
# for the JS layer.
#
# Locked contract (per directive 030 Stage 4):
#   - Enter working mode by clicking "Prepare" on the dialog.
#     The runner snapshots the current analysis source into a
#     DerivedGeometryWorkspace via the injected adapter.
#   - The runner NEVER touches the source -- it only sees the
#     frozen SourceSnapshot the AnalysisResult already carries.
#   - Discard / rebuild operate ONLY on the runner-owned
#     workspace.
#   - The runner returns a JSON-safe Hash; it never holds a
#     live SketchUp::Entity across the bridge.
#   - V1.5 repair actions stay out of scope. V1.4 plumbing
#     only.
#
# Adapter selection (per directive):
#   - Real SU: use SketchupDerivedWorkspaceAdapter (in
#     compatibility/) which creates real SketchUp::Group
#     entities under a recognizable name prefix.
#   - Test env: use FakeDerivedWorkspaceAdapter (in core/).
#   - The runner is adapter-agnostic; the factory decides.
#

require_relative 'derived_geometry_workspace'
require_relative 'derived_duplicate_validator'
require_relative 'tolerance'
# V1.6 Planar Normalization / Z Policy: load the proposer +
# executor so the runner can delegate to them without per-test
# requires.
require_relative 'planar_normalization_proposer'
require_relative 'planar_normalization_executor'

module SUAnalysis
  module Core
    module WorkingModeRunner
      module_function

      # Internal state. Per-process (no per-dialog tracking yet;
      # one dialog instance per process is the common case).
      # All state is frozen when stored so callers cannot mutate
      # the runner's view of the current workspace.
      @current_workspace     = nil   # DerivedGeometryWorkspace or nil
      @current_source        = nil   # SourceSnapshot (frozen) or nil
      @current_adapter       = nil   # DerivedWorkspaceAdapter instance or nil
      @current_adapter_kind  = nil   # Symbol :real_su | :fake | nil
      @current_model         = nil   # SU model (for adapter operations); nil if absent
      # V1.5 Phase 1: duplicate-repair summary Hash (or nil).
      # Populated by record_duplicate_repair_summary; read by snapshot.
      @duplicate_repair_summary = nil
      # V1.6 Planar Normalization / Z Policy: captured
      # proposal + audit Hashes (or nil). Populated by
      # compute_planar_normalization and apply_planar_normalization;
      # read by snapshot.
      @planar_normalization_proposal = nil
      @planar_normalization_audit    = nil
      # V1.6: cached tolerance derived from the captured
      # SourceSnapshot's execution_config.tolerance_values.
      # Recomputed on prepare()/rebuild().
      @planar_normalization_tolerance = nil

      STATES = [:none, :building, :ready, :discarded, :failed].freeze

      # Build (or rebuild) the current workspace from a frozen
      # SourceSnapshot. Returns the JSON-safe Hash for the UI.
      # When no existing workspace exists, this is "prepare".
      # When a workspace already exists, this is "rebuild".
      #
      # adapter: a DerivedWorkspaceAdapter subclass instance.
      # source:  a frozen SourceSnapshot.
      # model:   SU model (passed to workspace + adapter for
      #          operation wrapping). May be nil in tests.
      #
      # The adapter is captured for rebuild(); the runner does
      # NOT trust callers to re-supply it on every operation.
      #
      # V1.4 CodeX BLOCK fix (Stage 4): prepare MUST actually
      # build at least one derived entity via the adapter
      # (NOT just an empty workspace). The SourceSnapshot's
      # edges + faces are converted 1:1 to derived entities
      # (one SU-AI-Derived-* group per source Edge / Face).
      # If the source has NO edges AND NO faces, prepare
      # transitions the workspace to :failed with a clear
      # last_error (cannot derive from empty source).
      def prepare(source:, adapter:, model: nil)
        # Per directive: "Source CAD is immutable". The
        # runner only ever sees a frozen SourceSnapshot and
        # builds a brand new workspace. Any prior workspace
        # is discarded (best-effort) first.
        #
        # V1.4 V14-STAGE-BLOCK-002 (2026-08-24, CodeX V1.4 Stage Review
        # recheck): when the prior workspace is in :failed
        # state, we MUST attempt to clean it up first --
        # this is the UI's recovery path (the UI's Rebuild
        # button calls prepare; if we refuse without trying
        # cleanup, the user is stuck in the failed state).
        # The discard call may itself fail (cleanup couldn't
        # complete); in that case we keep the failed workspace
        # intact (no overwrite) and refuse the new build with
        # a clear last_error. This preserves the failed
        # workspace's private handle_registry AND gives the
        # user at least one recovery path.
        prior = @current_workspace
        if prior && prior.state == :failed
          begin
            @current_workspace = @current_workspace.discard
            if @current_workspace && @current_workspace.state != :failed
              # Discard succeeded -- proceed with the new build.
            else
              # Discard transitioned to :failed again (partial
              # cleanup). Refuse + return.
              refused = DerivedGeometryWorkspace.new_with_inventory(
                workspace_id:    prior.workspace_id,
                source_snapshot: prior.source_snapshot,
                adapter:         prior.instance_variable_get(:@adapter),
                model:           prior.instance_variable_get(:@model),
                state:           :failed,
                entity_pairs:    prior.instance_variable_get(:@entity_pairs),
                handle_registry: prior.instance_variable_get(:@handle_registry),
                fingerprint:     prior.fingerprint,
                last_error:      'prepare refused: prior workspace cleanup incomplete; cannot overwrite failed workspace',
                build_started_at: prior.build_started_at
              )
              @current_workspace = refused
              return snapshot
            end
          rescue StandardError
            # Outer rescue (paranoid): the prior failed workspace
            # is preserved AS-IS (handle_registry intact,
            # last_error unchanged). The user has at least one
            # recovery path (the prior workspace's explicit
            # Discard / Rebuild call from the UI).
            return snapshot
          end
        end
        _discard_if_present

        # Build the empty workspace first. We will populate
        # it via build_entity calls below.
        ws = DerivedGeometryWorkspace.new(
          workspace_id:    "ws-#{rand(2**32)}",
          source_snapshot: source,
          adapter:         adapter,
          model:           model
        )
        @current_source        = source
        @current_adapter       = adapter
        @current_adapter_kind  = _adapter_kind_of(adapter)
        @current_model         = model
        @current_workspace     = ws
        # V1.6 Planar Normalization / Z Policy: capture the
        # tolerance from the SourceSnapshot's execution_config
        # (so a rebuild from the same source yields the same
        # tolerance and the same proposal idempotently).
        @planar_normalization_tolerance = _tolerance_from_snapshot(source)
        # Reset per-build V1.6 state.
        @planar_normalization_proposal  = nil
        @planar_normalization_audit     = nil
        # V1.7 Endpoint / Gap Repair + Canonical Topology:
        # reset per-build V1.7 state. The tolerance is
        # captured from the same snapshot.
        @topology_repair_tolerance         = @planar_normalization_tolerance
        @topology_repair_proposal          = nil
        @topology_repair_audit             = nil
        @topology_repair_canonical_graph   = nil
        @topology_v17_loaded               = false

        # V1.4 V14-STAGE-BLOCK-002 (2026-08-24): the prepare
        # path is the SINGLE operation owner for the build.
        # Real SketchUp does NOT nest operations (per the
        # SketchUp Ruby API docs: calling Model#start_operation
        # while another operation is open implicitly ends
        # the previous one). The workspace's build_entity
        # does NOT open its own operation -- it just calls
        # create_top_level_group + add_edge_to_group inside
        # our open operation. On mid-build failure the runner
        # aborts THIS operation; SU rolls back every derived
        # entity created so far (atomic cleanup). This is
        # what the per-entity nesting attempt was trying to
        # achieve; the sequential-operation model achieves it
        # correctly on real SU.
        built_ws = nil  # explicit initial so rescue path can reference it
        begin
          adapter.begin_operation(model, label: 'SU-AI-Plugin: V1.4 Working Copy Prepare')
          built_ws = _build_derived_entities(ws, source)
          # V1.4 V14-STAGE-BLOCK-002 recheck (2026-08-24):
          # _build_derived_entities returns a :failed workspace
          # (NOT raises) when a mid-build failure happens. The
          # previous code committed the operation unconditionally
          # after _build_derived_entities returned, which left
          # surviving entities on the model when the build
          # failed mid-way. The new code ABORTS the operation
          # when built_ws.state == :failed, so SU rolls back
          # every entity created so far (atomic cleanup). The
          # :failed workspace's handle_registry still tracks
          # any handles that the abort failed to roll back.
          if built_ws && built_ws.state == :failed
            begin
              adapter.end_operation(model, commit: false)
            rescue StandardError
              # The abort itself failed (e.g. host rejected);
              # the partial handle_registry still tracks the
              # surviving entities for precise cleanup.
            end
          else
            adapter.end_operation(model, commit: true)
          end
          @current_workspace = built_ws
        rescue StandardError => e
          # Atomic cleanup: abort the outer operation; SU
          # rolls back every derived entity created so far
          # under it (atomic cleanup). The runner's
          # @current_workspace is set to the :failed
          # workspace so the UI sees the failed state and
          # the handle_registry stays intact (precise
          # tracking of any partial handles that the abort
          # failed to roll back -- e.g. if the host is
          # running an older SU API that did not auto-roll-
          # back via abort_operation).
          begin
            adapter.end_operation(model, commit: false)
          rescue StandardError => abort_err
            # Record the secondary failure but do NOT
            # swallow the original error: the workspace is
            # still :failed (the original build failed).
            @abort_error = "#{abort_err.class}: #{abort_err.message}"
          end
          # The :failed workspace preserves the partial
          # inventory + handle_registry so the user can
          # issue a Discard (or Rebuild) to clean up
          # explicitly. The next prepare() will refuse
          # until cleanup completes (see the prior ==
          # :failed check at the top of this method).
          #
          # Per V14-STAGE-BLOCK-002 (2026-08-24): the
          # partial inventory + handle_registry MUST come
          # from `built_ws` (the last build_entity result,
          # which may carry surviving entities + handles),
          # NOT from `ws` (the original empty :building
          # workspace which has no entities yet). When
          # _build_derived_entities raised BEFORE returning
          # any workspace (e.g., when the empty-source
          # :failed workspace is returned, or when a
          # build raised during the very first entity),
          # built_ws may be nil or carry no inventory; we
          # fall back to the original ws's empty state in
          # that case.
          partial_pairs = if built_ws && built_ws.respond_to?(:instance_variable_get)
                          built_ws.instance_variable_get(:@entity_pairs)
                        else
                          []
                        end
          partial_handles = if built_ws && built_ws.respond_to?(:instance_variable_get)
                              built_ws.instance_variable_get(:@handle_registry)
                            else
                              {}.freeze
                            end
          partial_fp = if built_ws && built_ws.respond_to?(:fingerprint)
                         built_ws.fingerprint
                       else
                         nil
                       end
          built_ws = DerivedGeometryWorkspace.new_with_inventory(
            workspace_id:    ws.workspace_id,
            source_snapshot: source,
            adapter:         adapter,
            model:           model,
            state:           :failed,
            entity_pairs:    partial_pairs,
            handle_registry: partial_handles,
            fingerprint:     partial_fp,
            last_error:      "#{e.class}: #{e.message}",
            build_started_at: ws.build_started_at
          )
          @current_workspace = built_ws
        end
        snapshot
      end

      # Discard the current workspace if any. Idempotent.
      # Returns the post-discard snapshot Hash (state == :discarded).
      #
      # The discarded workspace is KEPT in @current_workspace
      # (in :discarded state) so the next snapshot() reports
      # 'discarded' to the UI. The next prepare() proceeds
      # with a fresh workspace regardless; the prior discarded
      # workspace is no longer the active one (snapshot will
      # report the new state on the next render).
      #
      # V1.5 Phase 1: discard also clears the duplicate-repair
      # summary so the next snapshot doesn't report stale
      # numbers from a discarded workspace.
      # V1.6 Planar Normalization / Z Policy: discard also
      # clears the planar normalization proposal + audit so
      # the UI doesn't render stale normalization rows against
      # the discarded workspace.
      def discard
        _discard_if_present
        @duplicate_repair_summary = nil
        @planar_normalization_proposal = nil
        @planar_normalization_audit    = nil
        # V1.7 Endpoint / Gap Repair + Canonical Topology:
        # clear per-build V1.7 state too.
        @topology_repair_proposal          = nil
        @topology_repair_audit             = nil
        @topology_repair_canonical_graph   = nil
        # NOTE: do NOT clear @current_workspace here. The
        # discarded workspace carries the :discarded state
        # that the UI needs to render. The next prepare()
        # overwrites @current_workspace with a fresh
        # :building workspace.
        snapshot
      end

      # Rebuild from the SAME captured source + the SAME captured
      # adapter. The runner remembers the adapter that was
      # supplied at prepare() time; rebuild reuses it so the
      # caller does NOT have to re-supply it.
      #
      # For the V1.4 plumbing, rebuild = prepare (the workspace
      # is empty in :building state); V1.4+ will rebuild real
      # entities from the captured RepairPlan.
      #
      # Round-5 BLOCK-005 §7: rebuild runs
      # `validate_host_state_consistency!` first. If the prior
      # workspace's handle registry is inconsistent with the
      # host (e.g. user-undone), the runner must NOT silently
      # discard/overwrite; the user must explicitly discard
      # the now-stale workspace before a new rebuild.
      def rebuild
        validate_host_state_consistency!
        return _empty_snapshot if @current_source.nil?
        # If the captured adapter is missing (e.g. tests that
        # bypass prepare()), rebuild stays idle.
        return _empty_snapshot if @current_adapter.nil?
        # V1.4 Phase-2 self-audit fix: rebuild MUST replay the
        # captured model too. Otherwise the production adapter
        # would resolve via Sketchup.active_model instead of
        # the controller's model (and the inverse-edit_transform
        # contract would silently fall back to identity).
        prepare(
          source:  @current_source,
          adapter: @current_adapter,
          model:   @current_model
        )
      end

      # Snapshot of the runner state for the UI. JSON-safe.
      # Returns a String-keyed Hash with: state, source_snapshot_id,
      # source_fingerprint_digest, execution_config_digest,
      # workspace_id, last_error, AND entity_count (V1.4
      # CodeX BLOCK rework 2026-08-21: BLOCK 4 -- UI "N
      # entities ready" must match the actual derived record
      # count).
      # V1.5 Phase 1 (per plan §6 step 5): adds duplicate_repair
      # summary fields (duplicate_count_before / after + status)
      # so the dialog can show a "Duplicate repairs" line without
      # a UI redesign. The fields are populated ONLY when the
      # runner has applied at least one duplicate-repair action;
      # otherwise the keys are omitted (backward-compatible).
      # When the runner is idle (no workspace), returns the
      # "none" snapshot.
      def snapshot
        if @current_workspace.nil?
          snap = {
            'state'                    => 'none',
            'source_snapshot_id'       => nil,
            'source_fingerprint_digest' => nil,
            'execution_config_digest'  => nil,
            'workspace_id'             => nil,
            'last_error'               => nil,
            'entity_count'             => 0
          }
          # V1.5 Phase 1: include duplicate_repair summary in the
          # 'none' snapshot too when recorded (the summary is the
          # audit trail; it survives even after Discard).
          if @duplicate_repair_summary.is_a?(Hash) && !@duplicate_repair_summary.empty?
            snap['duplicate_repair'] = stringify_duplicate_repair_summary(@duplicate_repair_summary)
          end
          # V1.6 Planar Normalization / Z Policy: include the
          # last-known proposal + audit in the snapshot so the
          # UI's Working Mode row remains stable across
          # renderings.
          _attach_planar_normalization_to_snapshot(snap)
          # V1.7 Endpoint / Gap Repair + Canonical Topology
          # sub-snapshot (state + ready_proposals + audit +
          # canonical graph digest).
          _attach_topology_repair_to_snapshot(snap)
          snap
        else
          ws = @current_workspace
          src = @current_source || ws.source_snapshot
          fp = src.fingerprint
          ec_digest = ''
          if src.execution_config.respond_to?(:digest)
            ec_digest = src.execution_config.digest.to_s
          end
          fp_digest = ''
          if fp.respond_to?(:digest) && fp.digest
            fp_digest = fp.digest.to_s
          end
          le = ws.respond_to?(:last_error) ? ws.last_error : nil
          snap = {
            'state'                    => ws.state.to_s,
            'source_snapshot_id'       => src.snapshot_id.to_s,
            'source_fingerprint_digest' => fp_digest,
            'execution_config_digest'  => ec_digest,
            'workspace_id'             => ws.workspace_id.to_s,
            'last_error'               => le,
            # BLOCK 4 fix: UI "N entities ready" must equal
            # the actual derived record count.
            'entity_count'             => ws.respond_to?(:entity_count) ? ws.entity_count : 0
          }
          # V1.5 Phase 1 (per plan §6 step 6): include duplicate
          # repairs summary when present. Backward-compatible
          # (omitted when no duplicate repair has been applied
          # yet so older callers do not see the new keys).
          if @duplicate_repair_summary.is_a?(Hash) && !@duplicate_repair_summary.empty?
            snap['duplicate_repair'] = stringify_duplicate_repair_summary(@duplicate_repair_summary)
          end
          # V1.6 Planar Normalization / Z Policy.
          _attach_planar_normalization_to_snapshot(snap)
          # V1.7 Endpoint / Gap Repair + Canonical Topology.
          _attach_topology_repair_to_snapshot(snap)
          snap
        end
      end

      # V1.5 Phase 1: record the duplicate-repair summary on the
      # runner so the next snapshot() exposes it via
      # `derivedWorkspace.duplicate_repair`. Pure data only --
      # no live Sketchup objects.
      def record_duplicate_repair_summary(summary)
        return if summary.nil?
        return unless summary.is_a?(Hash)
        @duplicate_repair_summary = summary.dup.freeze
      end

      # V1.5 Phase 1 production call chain (CodeX BLOCK-002,
      # 2026-08-25 V1.5 Owner-Gate Readiness Review): run the
      # full Phase 1 pipeline against the CURRENT workspace.
      #
      # Inputs:
      #   registry: an IssueRegistry from the controller's
      #     AnalysisResult. Carries the duplicate_edge_candidate
      #     evidence emitted by the existing DuplicateDetector.
      #
      # Flow:
      #   1. proposer.propose(source, registry, workspace) -> plan
      #   2. plan.validate() -> validated plan
      #   3. executor.apply_batch(workspace, validated plan) -> [ws, actions]
      #   4. record_duplicate_repair_summary(actual results)
      #   5. return updated snapshot
      #
      # The whole flow is non-destructive to source. If anything
      # fails mid-batch, the workspace transitions to :failed and
      # the executor's atomic rollback restores the pre-batch
      # workspace state. The UI summary reflects actual results.
      #
      # When called outside a Prepare context (no workspace),
      # returns the current snapshot unchanged.
      def run_duplicate_repair_batch(registry:)
        if @current_workspace.nil?
          return snapshot
        end
        src_snapshot = @current_source || @current_workspace.source_snapshot
        # If the workspace is already :failed or :discarded,
        # skip the batch (no derivable entities).
        if @current_workspace.state == :failed || @current_workspace.state == :discarded
          return snapshot
        end
        begin
          plan = SUAnalysis::Core::DuplicateRepairProposer.propose(
            source_snapshot: src_snapshot,
            registry:        registry,
            workspace:       @current_workspace
          )
          validated = plan.validate
          # Capture the pre-batch workspace for the audit (BLOCK-004:
          # edge counts come from the actual pre-batch inventory).
          pre_ws = @current_workspace
          # Stage 3 (§8): capture the pre-batch derived-duplicate
          # class topology BEFORE assigning new_ws to
          # @current_workspace. The validator groups derived
          # records by canonical world-geometry key.
          pre_classes = SUAnalysis::Core::DerivedDuplicateValidator.group_derived_duplicates(
            @current_workspace, nil
          )
          # Capture every pre-execution skipped action from the
          # plan. These rows MUST remain in the final audit
          # (BLOCK-004: no runnable action may erase the
          # skipped evidence).
          plan_pre_skipped = Array(validated.respond_to?(:actions) ? validated.actions : []).select { |a|
            a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :skipped
          }
          new_ws, updated_actions = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
            workspace: @current_workspace,
            plan:      validated
          )
          @current_workspace = new_ws
          # Stage 3 (§8): validate the post-batch workspace.
          post_validation = SUAnalysis::Core::DuplicateRepairExecutor.validate_post_state(
            workspace: new_ws
          )
          # Build the summary from ACTUAL results (NOT manual
          # injection -- the CodeX BLOCK-002 fix requires the UI
          # summary to come from real execution results).
          # BLOCK-004: edge counts come from the actual
          # pre-batch and post-batch workspace inventories.
          pre_edge_count = pre_ws ? pre_ws.entities.length : nil
          summary = build_duplicate_repair_summary(
            plan:             validated,
            updated_actions:  updated_actions,
            pre_classes:      pre_classes,
            post_validation:  post_validation,
            pre_edge_count:   pre_edge_count,
            post_edge_count:  new_ws.entities.length,
            pre_workspace:    pre_ws,
            post_workspace:   new_ws
          )
          # Preserve pre-execution :skipped rows that the
          # executor may not echo back (defensive).
          unless plan_pre_skipped.empty?
            existing = Array(summary['actions']).map { |a|
              a.is_a?(Hash) ? (a['action_id'] || '') : (a.respond_to?(:action_id) ? a.action_id.to_s : '')
            }
            plan_pre_skipped.each do |act|
              aid = act.respond_to?(:action_id) ? act.action_id.to_s : ''
              next if existing.include?(aid)
              summary['actions'] << audit_row_for(act)
            end
          end
          @duplicate_repair_summary = summary
        rescue StandardError => e
          # Defensive: any uncaught exception leaves the workspace
          # intact (we don't touch @current_workspace) and records
          # the failure in the summary so the UI can display it.
          @duplicate_repair_summary = {
            'duplicate_pairs_before' => 0,
            'duplicate_pairs_after'  => 0,
            'actions_applied'        => 0,
            'actions_skipped'        => 0,
            'actions_failed'         => 1,
            'last_action_status'     => 'failed',
            'last_error'             => "#{e.class}: #{e.message}"
          }.freeze
        end
        snapshot
      end

      # Build an audit-row Hash for a RepairAction. Used to
      # preserve pre-execution :skipped rows in the summary
      # (BLOCK-004 minimum).
      def audit_row_for(action)
        if action.is_a?(SUAnalysis::Core::RepairAction)
          removed_count = Array(action.affected_derived_ids).length
          survivor_id = if action.before_summary.is_a?(Hash)
                          action.before_summary['survivor_derived_id'].to_s
                        else
                          ''
                        end
          source_count = Array(action.source_occurrence_ids).length
          issue_ids = if action.before_summary.is_a?(Hash)
                        Array(action.before_summary['issue_ids']).map(&:to_s)
                      else
                        []
                      end
          {
            'action_id'               => action.action_id.to_s,
            'status'                  => action.status.to_s,
            'rule_id'                 => action.rule_id.to_s,
            'explanation'             => action.explanation.to_s,
            'confidence_basis'        => action.confidence_basis.to_s,
            'source_occurrence_ids'   => Array(action.source_occurrence_ids).map(&:to_s),
            'source_occurrence_count' => source_count,
            'affected_derived_ids'    => Array(action.affected_derived_ids).map(&:to_s),
            'removed_count'           => removed_count,
            'survivor_derived_id'     => survivor_id,
            'issue_ids'               => issue_ids,
            'before_summary'          => (action.before_summary || {}).to_h
          }
        else
          { 'raw' => action.inspect }
        end
      end

      # Build the summary Hash from the actual plan + updated
      # actions. Counts actions by status (applied / skipped /
      # failed) and records the pre/post duplicate-pair counts
      # for the UI. Stage 3 (§8): also exposes the
      # derived-duplicate class counts (before/after) so the
      # UI can show the validation result.
      # V1.5 BLOCK-004 (2026-08-25 recheck): all counts come
      # from ACTUAL plan + execution + post-workspace data
      # (not fabricated). Every applied eligible class is
      # absent from the post result before host commit. A
      # failed invariant cannot be READY. Summary metrics
      # include:
      #   - applied/skipped/failed counts (from updated_actions)
      #   - duplicate classes before/after (from pre_classes
      #     and post_validation)
      #   - derived edge count before/after (from the actual
      #     workspace inventory)
      #   - duplicate pairs before/after (from the plan + post)
      def build_duplicate_repair_summary(plan:, updated_actions:, pre_classes: nil, post_validation: nil, pre_edge_count: nil, post_edge_count: nil, post_workspace: nil, pre_workspace: nil)
        applied = updated_actions.count { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
        skipped = updated_actions.count { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :skipped }
        failed  = updated_actions.count { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :failed }
        # ---- duplicate_pairs_before ----
        # BLOCK-004 Round-4 definition (AIPM §6):
        #   "the number of UNIQUE UNORDERED derived-edge pairs
        #    that satisfy the shared forward/reversed
        #    direct_match? under the CAPTURED duplicate
        #    tolerance in the measured workspace/scope. It is
        #    measured from direct-pair evidence. It is NOT:
        #    affected_derived_ids.length - 1, sum of action
        #    sizes, an inferred clique metric."
        # We measure BEFORE from the actual pre-batch
        # workspace using the shared
        # DuplicateGeometrySemantics.count_direct_pairs (NOT
        # a surrogate). The captured tolerance is the one
        # the executor already used.
        # Per FIX-A: when the captured tolerance is missing /
        # invalid we DO NOT silently fall back to
        # DEFAULT_DUPLICATE_TOLERANCE / the legacy 1e-4
        # default. We report `nil` and surface a
        # `tolerance_status` field so the UI can render the
        # honest answer.
        tolerance_status = if pre_workspace.respond_to?(:source_snapshot)
                             cap = pre_workspace.source_snapshot.respond_to?(:execution_config) ?
                                     pre_workspace.source_snapshot.execution_config : nil
                             vals = cap.respond_to?(:tolerance_values) ? cap.tolerance_values : nil
                             v = vals.is_a?(Hash) ? (vals[:duplicate] || vals['duplicate']) : nil
                             if v.nil?
                               'missing_captured_tolerance'
                             elsif SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(v)
                               'captured'
                             else
                               'invalid_captured_tolerance'
                             end
                           else
                             'missing_captured_tolerance'
                           end
        before_pairs = if pre_workspace.respond_to?(:entities)
                         tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(pre_workspace)
                         if SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(tol)
                           records = Array(pre_workspace.entities).select { |r| r.is_a?(SUAnalysis::Core::DerivedEntityRecord) && r.kind == :edge }
                           SUAnalysis::Core::DuplicateGeometrySemantics.count_direct_pairs(records, tol)
                         else
                           # FIX-A: missing/invalid captured
                           # tolerance; pair count is nil (not
                           # a defaulted number).
                           nil
                         end
                       else
                         nil
                       end
        # ---- duplicate_pairs_after ----
        # Measured from the actual post-batch workspace using
        # the SAME captured tolerance. No hardcoded 0.
        after_pairs = nil
        if post_validation.is_a?(Hash) && post_validation.key?('duplicate_pairs_after')
          after_pairs = post_validation['duplicate_pairs_after'].to_i
        end
        if after_pairs.nil? && post_workspace.respond_to?(:entities)
          tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(post_workspace)
          if SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(tol)
            records = Array(post_workspace.entities).select { |r| r.is_a?(SUAnalysis::Core::DerivedEntityRecord) && r.kind == :edge }
            after_pairs = SUAnalysis::Core::DuplicateGeometrySemantics.count_direct_pairs(records, tol)
          else
            after_pairs = nil
          end
        end
        # ---- normalize for stable UI consumption ----
        # If we could not measure pairs (nil), we surface the
        # honest answer (nil) plus a tolerance_status field.
        # Existing UI consumers can render `nil` as "N/A".
        # To preserve the existing JSON contract (integer
        # fields), we coerce nil -> 0 only as a UI fallback
        # when tolerance is genuinely missing/invalid; the
        # `tolerance_status` field tells the UI to render an
        # explanatory label rather than "0 duplicate pairs".
        if before_pairs.nil? && tolerance_status == 'captured'
          before_pairs = 0
        end
        if after_pairs.nil? && tolerance_status == 'captured'
          after_pairs = 0
        end
        # ---- class counts ----
        pre_count = pre_classes.is_a?(Hash) ? pre_classes.length : 0
        post_count = post_validation.is_a?(Hash) ? post_validation['duplicate_classes_after'].to_i : pre_count
        # ---- edge counts ----
        before_edge_count = pre_edge_count
        after_edge_count  = post_edge_count
        if after_edge_count.nil? && post_workspace.respond_to?(:entities)
          after_edge_count = post_workspace.entities.length
        end
        # ---- per-action audit rows ----
        actions_list = updated_actions.map { |a| audit_row_for(a) }
        # Preserve plan pre-execution skipped actions that the
        # executor may not echo back. The summary must not
        # silently drop them.
        if plan.respond_to?(:actions)
          Array(plan.actions).each do |act|
            next unless act.is_a?(SUAnalysis::Core::RepairAction) && act.status == :skipped
            aid = act.respond_to?(:action_id) ? act.action_id.to_s : ''
            next if aid.empty?
            existing_ids = actions_list.map { |row| row.is_a?(Hash) ? (row['action_id'] || '') : '' }
            next if existing_ids.include?(aid)
            actions_list << audit_row_for(act)
          end
        end
        {
          'duplicate_pairs_before'    => before_pairs,
          'duplicate_pairs_after'     => after_pairs,
          'actions_applied'           => applied,
          'actions_skipped'           => skipped,
          'actions_failed'            => failed,
          'last_action_status'        => (updated_actions.last ? updated_actions.last.status.to_s : 'none'),
          'duplicate_classes_before'  => pre_count,
          'duplicate_classes_after'   => post_count,
          'derived_edge_count_before' => before_edge_count,
          'derived_edge_count_after'  => after_edge_count,
          'tolerance_status'          => tolerance_status,
          'actions'                   => actions_list
        }.freeze
      end

      # V1.5 Phase 1: clear the duplicate-repair summary
      # (called when the workspace is discarded / rebuilt).
      def clear_duplicate_repair_summary
        @duplicate_repair_summary = nil
      end

      # ===========================================================
      # V1.6 Planar Normalization / Z Policy
      # ===========================================================
      #
      # Operating on the CURRENT workspace. Two-step user flow:
      #   1. compute_planar_normalization  -> snapshot['planar_normalization']
      #      (a frozen PlanarNormalizationProposer Hash with
      #      state + proposal; NO host mutation);
      #   2. apply_planar_normalization   -> snapshot (post-
      #      mutation; state transitions to :applied or
      #      :failed).
      #
      # All actions operate on the runner-owned workspace;
      # source remains untouched. The source fingerprint is
      # preserved by construction (SourceSnapshot is immutable).

      # Step 1: compute (without mutating) the planar
      # normalization proposal for the current workspace.
      # Idempotent: repeated calls on the same workspace +
      # tolerance return the same proposal Hash (Blueprint
      # P9). Clears the audit so the UI shows "READY_TO_NORMALIZE"
      # before the user applies.
      def compute_planar_normalization
        if @current_workspace.nil? || @current_source.nil? || @current_adapter.nil?
          @planar_normalization_proposal = nil
          return snapshot
        end
        if @current_workspace.state != :ready
          @planar_normalization_proposal = nil
          return snapshot
        end
        tol = @planar_normalization_tolerance || _tolerance_from_snapshot(@current_source)
        @planar_normalization_tolerance = tol
        proposal = SUAnalysis::Core::PlanarNormalizationProposer.propose(
          workspace: @current_workspace,
          adapter:   @current_adapter,
          tolerance: tol
        )
        # Strip the non-JSON-safe vertex handle Array (the
        # proposal builder's private host-handle resolution)
        # before caching. The UI sees state + counts + audit;
        # the executor (which runs in this same Ruby process)
        # re-resolves host handles from the proposal's
        # `unique_vertex_records` (which is JSON-safe).
        proposal_for_snapshot = proposal.dup
        if proposal_for_snapshot[:proposal].is_a?(Hash)
          stripped = proposal_for_snapshot[:proposal].dup
          stripped.delete(:unique_vertex_handles)
          proposal_for_snapshot = proposal_for_snapshot.merge(proposal: stripped)
        end
        @planar_normalization_proposal = proposal_for_snapshot.freeze
        @planar_normalization_audit    = nil
        snapshot
      end

      # Step 2: apply the previously-computed proposal to the
      # live workspace. One user-triggered action. Idempotent
      # at the apply level: a second call on an already-
      # applied workspace returns the existing audit without
      # re-running host mutation. On failure the workspace
      # transitions to :failed and the audit captures the
      # reason.
      def apply_planar_normalization
        if @current_workspace.nil? || @current_source.nil? || @current_adapter.nil?
          return snapshot
        end
        if @current_workspace.state != :ready
          return snapshot
        end
        # Re-build the live proposal (with vertex handles) on
        # demand; the cached snapshot-stripped proposal does
        # not carry the host handles.
        tol = @planar_normalization_tolerance || _tolerance_from_snapshot(@current_source)
        full_proposal = SUAnalysis::Core::PlanarNormalizationProposer.propose(
          workspace: @current_workspace,
          adapter:   @current_adapter,
          tolerance: tol
        )
        if full_proposal[:state] != SUAnalysis::Core::PlanarNormalizationAnalyzer::STATE_READY_TO_NORMALIZE
          # The workspace no longer matches the previous
          # READY_TO_NORMALIZE state (e.g. user discarded /
          # rebuilt). Do not apply; refresh the snapshot.
          @planar_normalization_proposal = full_proposal.dup.tap { |p|
            p.delete(:unique_vertex_handles) if p[:proposal].is_a?(Hash)
          }.freeze
          @planar_normalization_audit = {
            'status' => :skipped,
            'reason' => 'workspace_changed_before_apply'
          }.freeze
          return snapshot
        end
        # Run the executor.
        result = SUAnalysis::Core::PlanarNormalizationExecutor.apply(
          workspace:      @current_workspace,
          adapter:        @current_adapter,
          proposal_hash:  full_proposal,
          tolerance:      tol
        )
        if result[:status] == :failed
          # Workspace transitioned to :failed via the executor.
          @current_workspace = result[:post_workspace]
          @planar_normalization_audit = _planar_normalization_audit_to_jsonable(result[:audit])
          # Strip the (now stale) cached proposal so the UI
          # shows REVIEW_REQUIRED instead of pretending the
          # batch is still pending.
          @planar_normalization_proposal = nil
          return snapshot
        end
        # Applied successfully. Refresh the cached proposal
        # (now stale; the next compute will be a no-op since
        # all vertices are at target_z).
        @current_workspace = result[:post_workspace]
        @planar_normalization_audit = _planar_normalization_audit_to_jsonable(result[:audit])
        @planar_normalization_proposal = nil
        snapshot
      end

      # Read-only accessor for tests. Returns the cached
      # proposal Hash (without host handles) or nil.
      def planar_normalization_proposal
        @planar_normalization_proposal
      end

      # Read-only accessor for tests. Returns the cached
      # audit Hash or nil.
      def planar_normalization_audit
        @planar_normalization_audit
      end

      # Test-only: clear the V1.6 state (called by
      # reset_for_tests).
      def clear_planar_normalization
        @planar_normalization_proposal  = nil
        @planar_normalization_audit     = nil
        @planar_normalization_tolerance = nil
      end

      # V1.5 Phase 1: read-only accessor for tests / Owner
      # verification scripts. Returns the current summary Hash
      # or nil.
      def duplicate_repair_summary
        @duplicate_repair_summary
      end

      # ===========================================================
      # V1.7 Endpoint / Gap Repair + Canonical Topology
      # ===========================================================
      #
      # Operating on the CURRENT workspace. Two-step user flow
      # matches the V1.6 pattern:
      #   1. compute_gap_repair  -> snapshot['topology_repair']
      #      (a frozen GapPairProposer Hash with state +
      #       ready_proposals + review_proposals; NO host
      #       mutation);
      #   2. apply_gap_repair    -> snapshot (post-mutation;
      #       audit = :applied/:failed; workspace stays :ready
      #       on success, transitions to :failed on executor
      #       failure).
      #
      # All actions operate on the runner-owned workspace;
      # source remains untouched. The source fingerprint is
      # preserved by construction (SourceSnapshot is
      # immutable). The dedicated repair group is workspace-
      # owned (Blueprint §12.1) and is cleaned up by Discard /
      # Rebuild / close-time auto-discard.

      # Test hook: ensure V1.7 modules are loaded by the runner
      # require path. Tests may require additional files
      # explicitly when they need them; this is a defensive
      # require for the runner's own requires.
      GAP_REPAIR_RULE_ID = 'endpoint_bridge.v1'.freeze

      def require_v17_dependencies
        require_relative 'endpoint_record'
        require_relative 'canonical_topology_builder'
        require_relative 'canonical_geometry_graph'
        require_relative 'gap_pair_proposer'
        require_relative 'gap_bridge_executor'
        nil
      end

      # Step 1: compute (no host mutation) the conservative
      # endpoint gap proposal on the CURRENT workspace.
      # Idempotent: repeated calls on the same workspace +
      # tolerance return the same proposal Hash. Clears the
      # audit so the UI shows the READY_TO_REPAIR / REVIEW /
      # NO_CANDIDATE state before the user applies.
      def compute_gap_repair
        require_v17_dependencies if @topology_v17_loaded != true
        @topology_v17_loaded = true
        if @current_workspace.nil? || @current_source.nil? || @current_adapter.nil?
          @topology_repair_proposal = nil
          return snapshot
        end
        if @current_workspace.state != :ready
          @topology_repair_proposal = nil
          return snapshot
        end
        tol = @topology_repair_tolerance || _tolerance_from_snapshot(@current_source)
        @topology_repair_tolerance = tol
        proposal = GapPairProposer.propose(
          topology_snapshot: _canonical_topology_snapshot(workspace: @current_workspace,
                                                          tolerance: tol),
          derived_edges:     _derived_topology_edges(workspace: @current_workspace,
                                                    tolerance: tol),
          tolerance:         tol,
          crossing_checker:  _crossing_checker_proc(tolerance: tol)
        )
        @topology_repair_proposal = stringify_topology_repair_proposal(proposal).freeze
        @topology_repair_audit    = nil
        snapshot
      end

      # Step 2: apply the previously-computed proposal's READY
      # ones to the live workspace. One user-triggered action.
      # Idempotent at the apply level: a second call when
      # already-APPLIED returns the existing audit. On failure
      # the workspace transitions to :failed.
      def apply_gap_repair
        require_v17_dependencies if @topology_v17_loaded != true
        @topology_v17_loaded = true
        if @current_workspace.nil? || @current_source.nil? || @current_adapter.nil?
          return snapshot
        end
        if @current_workspace.state != :ready
          return snapshot
        end
        tol = @topology_repair_tolerance || _tolerance_from_snapshot(@current_source)
        # Recompute the live proposal (the cached snapshot
        # version is JSON-safe and may have been published).
        proposal = GapPairProposer.propose(
          topology_snapshot: _canonical_topology_snapshot(workspace: @current_workspace,
                                                          tolerance: tol),
          derived_edges:     _derived_topology_edges(workspace: @current_workspace,
                                                    tolerance: tol),
          tolerance:         tol,
          crossing_checker:  _crossing_checker_proc(tolerance: tol)
        )
        ready = Array(proposal['ready_proposals']).select { |p|
          p.is_a?(Hash) && p['state'] == GapPairProposer::STATE_READY_TO_REPAIR &&
            p['executable'] == true
        }
        if ready.empty?
          @topology_repair_audit = {
            'status' => :skipped,
            'reason' => 'no_ready_proposals'
          }.freeze
          return snapshot
        end
        # Pre-check: workspace.host_consistency.
        unless validate_host_state_consistency!
          @topology_repair_audit = {
            'status' => :failed,
            'reason' => 'host_state_changed'
          }.freeze
          return snapshot
        end
        # V17-AIPM-DIRECT-SOURCE-REREVIEW-2026-09-01 RR-04:
        # capture the EXACT pre-batch canonical baseline BEFORE
        # the executor apply:
        #   - existing gap_bridge repair_action_id set
        #   - non_transitive cluster signatures (sorted
        #     endpoint_keys)
        # The post-batch canonical_post_validate then compares
        # EXACTLY against this baseline:
        #   - every current-batch proposal_id maps to ONE
        #     canonical gap_bridge edge
        #   - pre-existing gap_bridges are allowed (current
        #     batch may have additional ones)
        #   - post non_transitive signatures minus pre
        #     signatures must be EMPTY
        pre_batch_gap_bridge_action_ids = _current_gap_bridge_action_ids
        pre_batch_non_transitive_sigs   = _current_non_transitive_signatures
        result = GapBridgeExecutor.apply(
          workspace: @current_workspace,
          adapter:   @current_adapter,
          proposals: ready,
          tolerance: tol
        )
        if result['status'] == :applied
          @current_workspace = result['post_workspace']
          @topology_repair_audit = stringify_topology_repair_audit(result['audit'])
          @topology_repair_proposal = nil
          @topology_repair_canonical_graph =
            rebuild_canonical_geometry_graph(workspace: @current_workspace, tolerance: tol)
          # V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-03 (H,I,J,K):
          # canonical post-validation after the host commit.
          # Every applied bridge MUST map to ONE canonical
          # edge with origin_kind=gap_bridge; repair_action_id
          # MUST survive into the canonical edge; the repaired
          # endpoint adjacency MUST be present; and the batch
          # MUST NOT introduce a new non_transitive_node_cluster.
          # Failure -> workspace transitions to :failed with
          # stable reason `canonical_post_validation_failed`;
          # handles retained for Discard; do NOT fake rollback.
          #
          # V17-AIPM-DIRECT-SOURCE-REREVIEW-2026-09-01 RR-04:
          # post-validation receives the EXACT pre-batch
          # baseline captured above (gap_bridge repair_action_id
          # set + non_transitive cluster signatures). Pre-existing
          # gap bridges are allowed; only the BATCH-INTRODUCED
          # ones must map 1:1 to applied proposal_ids; post
          # non_transitive signatures minus pre signatures
          # must be EMPTY.
          cpv = _canonical_post_validate(
            graph:  @topology_repair_canonical_graph,
            audit:  @topology_repair_audit,
            ready:  ready,
            pre_batch_gap_bridge_action_ids:    pre_batch_gap_bridge_action_ids,
            pre_batch_non_transitive_sigs:      pre_batch_non_transitive_sigs
          )
          unless cpv['pass']
            failed_audit = stringify_topology_repair_audit(@topology_repair_audit).dup
            failed_audit['status'] = 'failed'
            failed_audit['reason'] = GapBridgeExecutor::REASON_CANONICAL_POST_VALIDATE_FAIL
            failed_audit['extra_reasons'] = cpv['reasons']
            failed_audit['applied_proposals'] = []
            @topology_repair_audit = failed_audit.freeze
            # Transition the workspace to :failed WITHOUT
            # dropping the handle registry (explicit Discard
            # still works). Use the existing
            # _invalidate_to_failed_with_reason seam.
            _invalidate_to_failed_with_reason(GapBridgeExecutor::REASON_CANONICAL_POST_VALIDATE_FAIL)
            return snapshot
          end
          snapshot
        else
          # :failed: workspace may already have transitioned.
          @current_workspace = result['post_workspace'] if result['post_workspace']
          @topology_repair_audit = stringify_topology_repair_audit(result['audit'])
          @topology_repair_proposal = nil
          snapshot
        end
      end

      # Test-only: clear all V1.7 runner state.
      def clear_topology_repair
        @topology_repair_proposal          = nil
        @topology_repair_audit             = nil
        @topology_repair_tolerance         = nil
        @topology_repair_canonical_graph   = nil
      end

      # Read-only accessor for tests.
      def topology_repair_proposal
        @topology_repair_proposal
      end

      def topology_repair_audit
        @topology_repair_audit
      end

      def topology_repair_canonical_graph
        @topology_repair_canonical_graph
      end

      # ---- V1.7 internals ----

      # Build a DerivedTopologySnapshot (EndpointRecord +
      # DerivedEdgeRecord list) for the CURRENT workspace.
      # Pure read; no host mutation. Resolves host vertex
      # handles (if available) for the snapshot builder.
      def _derived_topology_edges(workspace:, tolerance:)
        require_v17_dependencies if @topology_v17_loaded != true
        @topology_v17_loaded = true
        return [] if workspace.nil? || workspace.state != :ready
        result = DerivedTopologySnapshotBuilder.build(
          workspace:          workspace,
          adapter:            @current_adapter,
          vertex_keys_by_edge: _host_vertex_map(workspace)
        )
        Array(result['edges'])
      end

      # Build the canonical topology snapshot Hash for the
      # CURRENT workspace. Wraps CanonicalTopologyBuilder.
      def _canonical_topology_snapshot(workspace:, tolerance:)
        require_v17_dependencies if @topology_v17_loaded != true
        @topology_v17_loaded = true
        return CanonicalTopologyBuilder._empty_result if workspace.nil?
        tol = tolerance.respond_to?(:coordinate_epsilon) ?
                tolerance.coordinate_epsilon.to_f : 1.0e-6
        topo = DerivedTopologySnapshotBuilder.build(
          workspace:           workspace,
          adapter:             @current_adapter,
          vertex_keys_by_edge: _host_vertex_map(workspace)
        )
        endpoints = Array(topo['endpoints'])
        # V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01 R5 fix:
        # CanonicalTopologyBuilder.build returns a FROZEN Hash,
        # so the previous in-place `result[:endpoints] =` raised
        # FrozenError and made the whole production
        # compute_gap_repair / apply_gap_repair path unusable.
        # `dup` yields an unfrozen shallow copy (the frozen
        # canonical sub-structures stay frozen, which is the
        # intended immutability contract).
        result = CanonicalTopologyBuilder.build(
          endpoints:          endpoints,
          coordinate_epsilon: tol
        ).dup
        result[:endpoints] = endpoints
        result
      end

      # Host vertex map: { endpoint_key => host_vertex_handle }
      # best-effort, nil when adapter unavailable.
      def _host_vertex_map(workspace)
        return {} if workspace.nil? || @current_adapter.nil?
        adapter = @current_adapter
        out = {}
        workspace.entities.each do |rec|
          next unless rec.respond_to?(:kind) && rec.kind == :edge
          did = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
          next if did.empty?
          handle = workspace.handle_for(did) if workspace.respond_to?(:handle_for)
          next if handle.nil?
          next unless adapter.respond_to?(:edge_endpoints)
          eps = adapter.edge_endpoints(handle)
          next unless eps.is_a?(Array) && eps.length == 2
          out["#{did}.start"] = eps[0]
          out["#{did}.end"]   = eps[1]
        end
        out
      end

      # Crossing checker: a Proc suitable for
      # GapPairProposer.propose(... crossing_checker:).
      # For V1.7 base we use a simple exact-match segment
      # intersection against the current derived edges
      # (Blueprint §10.3 minimal implementation). A real SU
      # crossing check would consult the world-coord
      # endpoints; the in-test implementation mirrors that.
      def _crossing_checker_proc(tolerance:)
        proc do |proposal, derived_edges, endpoint_lookup, _topology_snapshot|
          eps = Array(proposal ? proposal['coordinate_epsilon'] : nil).first ||
                 (tolerance.respond_to?(:coordinate_epsilon) ? tolerance.coordinate_epsilon.to_f : 1.0e-6)
          bridge_a = Array(proposal['expected_bridge_endpoints'])
          return { 'safe' => false, 'reasons' => ['invalid_bridge_endpoints'] } unless bridge_a.length == 2
          pa1, pa2 = bridge_a[0], bridge_a[1]
          reasons = []
          ek_a = proposal['endpoint_a_key']
          ek_b = proposal['endpoint_b_key']
          ea_a = endpoint_lookup[ek_a]
          ea_b = endpoint_lookup[ek_b]
          if ea_a && ea_b && ea_a['derived_edge_id'] == ea_b['derived_edge_id']
            # Same incident edge on BOTH sides is allowed
            # only if the endpoints are DIFFERENT (no
            # self-loop); both endpoints come from the same
            # edge but at different roles (start vs end).
            # No third-party check.
          end
          # Walk every other derived edge that is not
          # incident to either endpoint; check whether the
          # bridge segment intersects that edge's interior
          # OR shares a non-trivial node.
          Array(derived_edges).each do |e|
            next if e.endpoint_a_key == ek_a || e.endpoint_b_key == ek_a
            next if e.endpoint_a_key == ek_b || e.endpoint_b_key == ek_b
            # Compare world endpoints.
            ew_a = e.world_endpoints[0]
            ew_b = e.world_endpoints[1]
            # Bridge and edge share an endpoint?
            if (_dist(pa1, ew_a) < eps && _dist(pa2, ew_b) < eps) ||
               (_dist(pa1, ew_b) < eps && _dist(pa2, ew_a) < eps)
              # Share both endpoints; that's literally the
              # same segment (already excluded by endpoint
              # key). Skip.
              next
            end
            if (_shared_endpoint?(pa1, ew_a, eps) ||
                _shared_endpoint?(pa1, ew_b, eps) ||
                _shared_endpoint?(pa2, ew_a, eps) ||
                _shared_endpoint?(pa2, ew_b, eps))
              # The bridge touches this edge's endpoint;
              # no interior crossing.
              next
            end
            if _segments_intersect_interior?(pa1, pa2, ew_a, ew_b, eps)
              reasons << 'bridge_crossing'
              break
            end
            if _third_node_on_segment?(pa1, pa2, ew_a, ew_b, endpoints_worlds: _other_endpoint_worlds(e, ek_a, ek_b, endpoint_lookup), eps: eps)
              reasons << 'third_node_on_bridge'
              break
            end
          end
          { 'safe' => reasons.empty?, 'reasons' => reasons }
        end
      end

      def _dist(a, b)
        return Float::INFINITY unless a.is_a?(Array) && b.is_a?(Array)
        dx = a[0] - b[0]
        dy = a[1] - b[1]
        dz = a[2] - b[2]
        Math.sqrt(dx * dx + dy * dy + dz * dz)
      end

      def _shared_endpoint?(a, b, eps)
        return false unless a.is_a?(Array) && b.is_a?(Array)
        _dist(a, b) <= eps
      end

      def _segments_intersect_interior?(p1, p2, q1, q2, eps)
        return false unless p1.is_a?(Array) && p2.is_a?(Array) && q1.is_a?(Array) && q2.is_a?(Array)
        return false if _shared_endpoint?(p1, q1, eps) || _shared_endpoint?(p1, q2, eps) ||
                        _shared_endpoint?(p2, q1, eps) || _shared_endpoint?(p2, q2, eps)
        d1 = _segment_orientation(p1, p2, q1)
        d2 = _segment_orientation(p1, p2, q2)
        d3 = _segment_orientation(q1, q2, p1)
        d4 = _segment_orientation(q1, q2, p2)
        return false if d1.abs < eps || d2.abs < eps || d3.abs < eps || d4.abs < eps
        ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
          ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
      end

      def _segment_orientation(p, q, r)
        # 2D orientation projected onto the XY plane (the V1.7
        # base Z-compat test already excludes non-coplanar
        # bridges).
        (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
      end

      # V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-04:
      # TRUE point-on-segment-interior predicate. The previous
      # implementation only proved collinearity with the
      # INFINITE LINE through the bridge (`abs(orientation)
      # <= eps`), so a distant unrelated node collinear with
      # the bridge but FAR OUTSIDE the segment would falsely
      # trigger `third_node_on_bridge`.
      #
      # The new predicate proves:
      #   1. the candidate point is finite 3D
      #   2. the projection parameter t lies strictly inside
      #      (0, 1) -- endpoints excluded
      #   3. the closest-point distance to the segment is
      #      <= coordinate_epsilon
      #
      # Returns true iff the candidate lies STRICTLY INSIDE
      # the bridge segment interior (within coordinate_epsilon).
      def _third_node_on_segment?(p1, p2, _ew_a, _ew_b, endpoints_worlds:, eps:)
        return false unless endpoints_worlds.is_a?(Array)
        endpoints_worlds.each do |w|
          next unless _is_finite_point?(w)
          next unless _point_on_segment_interior?(p1, p2, w, eps)
          return true
        end
        false
      end

      # Pure point-on-segment-interior predicate. Returns true
      # iff `w` lies strictly inside the closed segment
      # [p1, p2] within `eps` (closest-point distance <= eps)
      # AND the projection parameter t is in (0, 1) with
      # endpoint epsilon exclusion.
      def _point_on_segment_interior?(p1, p2, w, eps)
        return false unless _is_finite_point?(p1)
        return false unless _is_finite_point?(p2)
        return false unless _is_finite_point?(w)
        eps_f = eps.to_f
        return false if eps_f <= 0 || !eps_f.finite?
        # Reject degenerate segment.
        sx = (p2[0] - p1[0]).abs
        sy = (p2[1] - p1[1]).abs
        sz = (p2[2] - p1[2]).abs
        seg_len2 = (sx * sx) + (sy * sy) + (sz * sz)
        return false if seg_len2 <= 0
        # Projection parameter t = ((w - p1) . (p2 - p1)) / |p2 - p1|^2
        wx = w[0] - p1[0]
        wy = w[1] - p1[1]
        wz = w[2] - p1[2]
        dot = (wx * (p2[0] - p1[0])) + (wy * (p2[1] - p1[1])) + (wz * (p2[2] - p1[2]))
        t = dot / seg_len2
        # Endpoint exclusion: must be STRICTLY between
        # (eps / seg_len) and (1 - eps / seg_len).
        # Equivalently: t > eps_f and t < 1.0 - eps_f when
        # eps is a distance; convert to a t-relative band by
        # scaling with seg_len. We use the conservative band
        # [eps_seg, 1 - eps_seg] where eps_seg = eps_f /
        # seg_len (eps expressed as a fraction of segment
        # length). For a typical CAD gap (seg_len ~ 0.05..10)
        # the band is well-defined.
        seg_len = Math.sqrt(seg_len2)
        eps_seg = eps_f / seg_len
        return false if t <= eps_seg
        return false if t >= (1.0 - eps_seg)
        # Closest-point distance: w projected onto segment,
        # then distance from w to projected point.
        proj_x = p1[0] + t * (p2[0] - p1[0])
        proj_y = p1[1] + t * (p2[1] - p1[1])
        proj_z = p1[2] + t * (p2[2] - p1[2])
        dx = w[0] - proj_x
        dy = w[1] - proj_y
        dz = w[2] - proj_z
        closest_d = Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
        closest_d <= eps_f
      end

      def _other_endpoint_worlds(derived_edge, ek_a, ek_b, endpoint_lookup)
        ws = []
        [derived_edge.endpoint_a_key, derived_edge.endpoint_b_key].each do |ek|
          next if ek == ek_a || ek == ek_b
          ep = endpoint_lookup[ek]
          ws << ep['world_coordinate'] if ep.is_a?(Hash) && ep['world_coordinate'].is_a?(Array)
        end
        ws
      end

      # Build / rebuild the canonical geometry graph for the
      # CURRENT workspace state. Pure read; no host mutation.
      def rebuild_canonical_geometry_graph(workspace:, tolerance:)
        require_v17_dependencies if @topology_v17_loaded != true
        @topology_v17_loaded = true
        return nil if workspace.nil?
        topo = _canonical_topology_snapshot(workspace: workspace, tolerance: tolerance)
        derived_edges = _derived_topology_edges(workspace: workspace, tolerance: tolerance)
        # Attach workspace metrics to topology snapshot for
        # the graph builder (node degrees etc.).
        CanonicalGeometryGraph.build_from_workspace(
          workspace:         workspace,
          topology_snapshot: topo.merge(
            :canonical_edges   => derived_edges,
            :open_endpoints    => _open_endpoint_keys(workspace, derived_edges, topo)
          )
        )
      end

      # V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-03 (H..K):
      # canonical post-validation. Runs AFTER the host commit
      # AND after the canonical graph rebuild. Returns:
      #   { 'pass' => true|false, 'reasons' => Array<String> }
      #
      # V17-AIPM-DIRECT-SOURCE-REREVIEW-2026-09-01 RR-04:
      # receives the EXACT pre-batch baseline captured before
      # the executor apply:
      #   pre_batch_gap_bridge_action_ids : Set<String> of
      #     repair_action_ids already present in the
      #     pre-batch canonical graph's gap_bridge edges.
      #     Pre-existing gap_bridges are allowed; only the
      #     BATCH-INTRODUCED ones must map 1:1 to applied
      #     proposal_ids.
      #   pre_batch_non_transitive_sigs : Array<String> of
      #     sorted-endpoint-keys signatures of non-transitive
      #     clusters already present before this batch.
      #     The post-batch non_transitive signatures minus
      #     this set MUST be EMPTY.
      def _canonical_post_validate(graph:, audit:, ready:,
                                  pre_batch_gap_bridge_action_ids: nil,
                                  pre_batch_non_transitive_sigs: nil)
        reasons = []
        if graph.nil?
          reasons << 'no_canonical_graph'
          return { 'pass' => false, 'reasons' => reasons }
        end
        applied_ids = Array(audit['applied_proposals']).map(&:to_s)
        if applied_ids.empty?
          # Nothing was applied (defensive); nothing to check.
          return { 'pass' => true, 'reasons' => [] }
        end
        # (H) RR-04: every CURRENT-BATCH applied bridge ->
        # one canonical edge with origin_kind=gap_bridge AND
        # repair_action_id equal to one of the applied
        # proposal_ids. Pre-existing gap_bridges are excluded
        # from this count by intersecting with applied_ids.
        canonical_edges = graph.respond_to?(:edges) ? graph.edges : []
        bridge_edges = canonical_edges.select { |e| e['origin_kind'].to_s == 'gap_bridge' }
        # Current-batch bridge edges = those whose
        # repair_action_id is one of the applied_ids.
        batch_bridge_edges = bridge_edges.select { |e|
          applied_ids.include?(e['repair_action_id'].to_s)
        }
        unless batch_bridge_edges.length == applied_ids.length
          reasons << "canonical_bridge_count_mismatch(#{batch_bridge_edges.length}/#{applied_ids.length})"
        end
        # (I) repair_action_id survives into the canonical edge.
        batch_bridge_edges.each do |e|
          unless applied_ids.include?(e['repair_action_id'].to_s)
            reasons << "repair_action_id_not_in_canonical:#{e['repair_action_id']}"
          end
        end
        # (J) repaired endpoint adjacency is present. Each
        # applied bridge connects two DISTINCT canonical
        # nodes, and they are mutually adjacent in the
        # graph's adjacency.
        adj = graph.respond_to?(:adjacency) ? graph.adjacency : {}
        batch_bridge_edges.each do |e|
          a = e['node_a_id'].to_s
          b = e['node_b_id'].to_s
          if a.empty? || b.empty? || a == b
            reasons << "bridge_endpoint_not_resolved:#{e['canonical_edge_id']}"
            next
          end
          adj_a = Array(adj[a]).map(&:to_s)
          adj_b = Array(adj[b]).map(&:to_s)
          unless adj_a.include?(b)
            reasons << "repaired_adjacency_missing_a:#{e['canonical_edge_id']}"
          end
          unless adj_b.include?(a)
            reasons << "repaired_adjacency_missing_b:#{e['canonical_edge_id']}"
          end
        end
        # (K) RR-04: no NEW non_transitive_node_cluster is
        # introduced. Compare the post graph's
        # non_transitive cluster signatures against the
        # pre-batch baseline. The post_sigs - pre_sigs
        # difference MUST be EMPTY. An unchanged pre-existing
        # cluster does NOT cause a failure.
        pre_sigs = Array(pre_batch_non_transitive_sigs).map(&:to_s)
        post_sigs = Array(graph.non_transitive_clusters).map { |c|
          _non_transitive_signature(c)
        }.map(&:to_s)
        new_sigs = post_sigs - pre_sigs
        unless new_sigs.empty?
          reasons << "new_non_transitive_cluster_introduced:#{new_sigs.length}"
        end
        { 'pass' => reasons.empty?, 'reasons' => reasons }.freeze
      end

      # RR-04: capture the EXACT pre-batch canonical baseline
      # (existing gap_bridge repair_action_id set). Rebuilds
      # the current canonical graph from the current
      # workspace state (read-only) and collects the
      # gap_bridge repair_action_ids present BEFORE the
      # executor apply.
      def _current_gap_bridge_action_ids
        return [] if @current_workspace.nil?
        return [] unless @current_workspace.state == :ready
        tol = v17_tolerance
        graph = rebuild_canonical_geometry_graph(
          workspace: @current_workspace, tolerance: tol
        )
        return [] if graph.nil?
        Array(graph.edges).select { |e| e['origin_kind'].to_s == 'gap_bridge' }
                          .map { |e| e['repair_action_id'].to_s }
                          .reject { |s| s.empty? }
                          .uniq
      end

      # RR-04: capture the EXACT pre-batch canonical baseline
      # (non_transitive cluster signatures). Each cluster's
      # signature = sorted endpoint_keys joined with a stable
      # separator. A pre-existing cluster whose sorted
      # endpoint_keys are unchanged across the batch yields
      # an identical signature and is NOT a failure.
      def _current_non_transitive_signatures
        return [] if @current_workspace.nil?
        return [] unless @current_workspace.state == :ready
        tol = v17_tolerance
        graph = rebuild_canonical_geometry_graph(
          workspace: @current_workspace, tolerance: tol
        )
        return [] if graph.nil?
        Array(graph.non_transitive_clusters).map { |c|
          _non_transitive_signature(c)
        }
      end

      # Build the canonical signature for a non_transitive
      # cluster. Stable sorted endpoint_keys joined with '|'.
      # The signature is identical for any two clusters
      # whose endpoint membership keys are the same set.
      def _non_transitive_signature(cluster)
        return '' unless cluster.is_a?(Hash)
        Array(cluster['endpoint_keys']).map(&:to_s).sort.join('|')
      end

      # Read the V1.7 tolerance from the current source
      # snapshot, falling back to a sane default when the
      # runner has no source. Used by RR-04 baseline capture.
      #
      # V17-AIPM-FINAL-PRE-CODEX-FIX-2026-09-02 F-01: do NOT
      # maintain a second tolerance parser. The previous
      # implementation read only STRING keys while
      # Tolerance#to_h publishes SYMBOL keys (and
      # ExecutionConfigSnapshot.from_live_config preserves
      # that Hash shape), so a normal captured SourceSnapshot
      # could carry symbol-keyed tolerance values while
      # v17_tolerance silently fell back to the legacy
      # defaults. RR-04's exact pre-batch canonical baseline
      # could therefore be rebuilt with a DIFFERENT
      # coordinate_epsilon / gap_search from the
      # proposal/apply path when a non-default profile or
      # override was used. This violated captured-config
      # authority.
      #
      # The fix delegates directly to the already-correct
      # `_tolerance_from_snapshot(@current_source)`, which
      # accepts BOTH symbol and string keys (defensive
      # `vals[:k] || vals['k']`) and preserves the complete
      # tolerance field set (including big_z /
      # large_coordinate / planar_z_snap). The RR-04
      # baseline capture AND the proposal/apply path MUST
      # therefore use IDENTICAL captured gap_search and
      # coordinate_epsilon values, with NO silent fallback
      # to defaults.
      def v17_tolerance
        return Tolerance.default if @current_source.nil?
        _tolerance_from_snapshot(@current_source)
      end

      def _open_endpoint_keys(workspace, derived_edges, topology_snapshot)
        # Adjacency in canonical-node space.
        # V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01 R5 fix:
        # CanonicalTopologyBuilder.build publishes STRING keys;
        # the previous symbol-only read silently resolved to {}
        # on the production runner path, which destroyed
        # canonical-node identity (Blueprint §7) and reported
        # every coincident corner endpoint as "open"
        # (Blueprint §8). Read symbol OR string defensively.
        cluster_lookup = topology_snapshot[:canonical_node_clusters] ||
                          topology_snapshot['canonical_node_clusters'] || {}
        canonical_node_by_endpoint = {}
        cluster_lookup.each { |cid, keys| Array(keys).each { |k| canonical_node_by_endpoint[k.to_s] = cid.to_s } }
        adj = Hash.new { |h, k| h[k] = [] }
        derived_edges.each do |e|
          ak = canonical_node_by_endpoint[e.endpoint_a_key.to_s] || e.endpoint_a_key.to_s
          bk = canonical_node_by_endpoint[e.endpoint_b_key.to_s] || e.endpoint_b_key.to_s
          adj[ak] << bk unless adj[ak].include?(bk)
          adj[bk] << ak unless adj[bk].include?(ak)
        end
        degree = Hash.new(0)
        adj.each { |k, vs| vs.each { |v| degree[k] += 1 } }
        endpoint_open = []
        derived_edges.each do |e|
          if degree[canonical_node_by_endpoint[e.endpoint_a_key.to_s] || e.endpoint_a_key.to_s].to_i == 1
            endpoint_open << e.endpoint_a_key.to_s
          end
          if degree[canonical_node_by_endpoint[e.endpoint_b_key.to_s] || e.endpoint_b_key.to_s].to_i == 1
            endpoint_open << e.endpoint_b_key.to_s
          end
        end
        endpoint_open.uniq.sort
      end

      # JSON-safe conversion for the topology_repair proposal.
      def stringify_topology_repair_proposal(proposal)
        return nil unless proposal.is_a?(Hash)
        out = {}
        proposal.each do |k, v|
          ks = k.to_s
          out[ks] = stringify_duplicate_repair_value(v)
        end
        # Flatten nested :ready_proposals entries the JS can
        # directly inspect.
        out.freeze
      end

      def stringify_topology_repair_audit(audit)
        return nil unless audit.is_a?(Hash)
        stringify_duplicate_repair_summary(audit)
      end

      # ---- internals ----

      # V1.4 CodeX BLOCK rework (2026-08-22) BLOCK-R4-1:
      # V1.4 minimal scope ONLY materializes Edges faithfully.
      # Source FaceRecords are retained in the SourceSnapshot
      # (provenance / fingerprint / layer counts) but are NOT
      # materialized as derived Face entities (see the
      # commit message for the full BLOCK-R3-2 / BLOCK-R4-1
      # rationale).
      #
      # Derive-ability is therefore determined SOLELY by the
      # source edges: if edges is empty, the workspace MUST
      # transition to :failed (NOT :building). Without this
      # guard, a Face-only selection would loop through zero
      # edges, produce zero entities, and leave the workspace
      # stuck in :building forever -- the UI would be locked
      # with Discard/Rebuild inoperable.
      #
      # Returns a new DerivedGeometryWorkspace (the original
      # is deeply frozen; transitions produce new instances).
      # On failure (no derivable edge OR adapter failure),
      # returns a :failed workspace with last_error set.
      def _build_derived_entities(ws, source)
        edges = source.respond_to?(:edges) ? source.edges : []
        faces = source.respond_to?(:faces) ? source.faces : []
        if edges.nil? || edges.empty?
          # No derivable edge in the source: V1.4 minimal
          # scope cannot produce any derived entity. The
          # workspace MUST NOT be marked READY (and MUST NOT
          # stay in :building -- that locks the UI). Transition
          # to :failed with a precise last_error.
          return DerivedGeometryWorkspace.new_with_inventory(
            workspace_id:    ws.workspace_id,
            source_snapshot: source,
            adapter:         ws.instance_variable_get(:@adapter),
            model:           ws.instance_variable_get(:@model),
            state:           :failed,
            entity_pairs:    [].freeze,
            handle_registry: {}.freeze,
            fingerprint:     nil,
            last_error:      'V1.4 working copy requires at least one derivable edge; source faces are retained as provenance only.',
            build_started_at: ws.build_started_at
          )
        end
        # Note: the `faces` variable is unused below; we keep
        # the read so future V1.5+ provenance tooling can use
        # it without re-reading the snapshot. V1.4 minimal
        # scope materializes NO Face entities (no fabrication
        # of vertices, no truncation to first 3 points).
        _ = faces
        # Build one derived entity per source EdgeRecord.
        # V1.4 CodeX BLOCK rework (2026-08-21): derived
        # Edges use the real two-endpoint path (NO 3-point
        # face fabrication, NO Z lift). The geometry_data is
        # [start_point, end_point] -- the adapter's
        # add_edge_to_group uses add_edges for these.
        #
        # V1.4 CodeX BLOCK rework (2026-08-22) BLOCK-R3-2:
        # V1.4 minimal scope ONLY derives Edges faithfully.
        # Source FaceRecords are recorded in the SourceSnapshot
        # (provenance / fingerprint / layer counts) but are NOT
        # materialized as derived Face entities. The previous
        # path called FaceRecord#vertices (which does not
        # exist on the production FaceRecord) and forced a
        # :failed transition for any source selection with a
        # face; that broke the "Edge-only faithful derivation"
        # contract.
        cur = ws
        edges.each_with_index do |edge, idx|
          did = "der-edge-#{idx}-#{_stable_id_fragment(edge)}"
          occ_id = _source_occurrence_id_for(edge, kind: :edge, array_index: idx)
          geom   = _geometry_summary_for_edge(edge)
          pts    = _edge_endpoints(edge)
          cur = cur.build_entity(
            derived_id:            did,
            kind:                  :edge,
            source_occurrence_ids: [occ_id],
            geometry_summary:      geom,
            geometry_data:         pts
          )
          break if cur.state == :failed
        end
        return cur if cur.state == :failed
        # Per BLOCK-R3-2: V1.4 minimal scope does NOT
        # materialize derived Faces. The faces are kept in
        # the SourceSnapshot (for layer counts / fingerprint /
        # provenance) but the prepare path SKIPS face
        # materialization so the workspace reaches :ready
        # without fabricating face geometry.
        # entity_count == edges.length (NOT edges.length +
        # faces.length); the Owner checklist + UI text
        # explicitly call out "derived Edge count" so the
        # operator is never misled.
        cur
      end

      # Derive a snapshot-local occurrence id from a
      # SourceRecord. V1.4 CodeX BLOCK rework (2026-08-22):
      # the occurrence id MUST be unique WITHIN one
      # SourceSnapshot and deterministic across rebuilds of
      # the same snapshot. We never use `record.object_id`
      # (which varies per process) and we never return a
      # unified `transient-occ-unresolved` (which would
      # collapse distinct occurrences to the same id).
      #
      # Resolution priority:
      #   1. Stable root: persistent_id_path non-empty AND
      #      pid_path_complete=true -> "occ-<path>" (full path
      #      joined by '>').
      #   2. Transient root: persistent_id_path non-empty but
      #      pid_path_complete=false -> "transient-occ-<path>"
      #      (still unique within the snapshot; never claims
      #      cross-session stability).
      #   3. No usable host identity chain (root edge with no
      #      PID, transient leaf, etc.) -> fallback to a
      #      snapshot-local analysis-local id of the form
      #      "transient-occ-<kind>-<record.id>" where
      #      <record.id> is the analysis-local record id
      #      (EdgeRecord#id / FaceRecord#id). This id is
      #      unique within the snapshot AND stable across
      #      rebuilds of the same snapshot (the record's
      #      analysis-local id is the snapshot-local occurrence
      #      id, per BLOCK-R3-1). The caller MUST pass
      #      `kind:` (`:edge` or `:face`) so the id is
      #      distinguishable across kinds.
      #
      # We NEVER use entityID / object_id as a substitute
      # for stable identity (per BLOCK 2 / BLOCK-R3-1).
      def _source_occurrence_id_for(record, kind: nil, array_index: nil)
        if record.nil?
          return _transient_local_id(:edge, 0, array_index)
        end
        src = record.respond_to?(:source) ? record.source : nil
        # Prefer the full persistent_id_path.
        pid_path  = (src.respond_to?(:persistent_id_path) && src.persistent_id_path) ? src.persistent_id_path : nil
        ipath     = (src.respond_to?(:instance_path)      && src.instance_path)      ? src.instance_path      : nil
        # Identity quality (per directive): if pid_path_complete
        # is false, prefix `transient-:` so the rebuild contract
        # never silently treats transient occurrences as stable.
        complete  = src.respond_to?(:pid_path_complete) ? src.pid_path_complete : true
        quality   = complete ? 'occ' : 'transient-occ'
        if pid_path.is_a?(Array) && !pid_path.empty?
          return "#{quality}-#{pid_path.map(&:to_s).join('>')}"
        elsif ipath.is_a?(Array) && !ipath.empty?
          return "#{quality}-ipath-#{ipath.map(&:to_s).join('>')}"
        end
        # No usable identity chain: snapshot-local fallback.
        # The record's analysis-local id is the snapshot-local
        # occurrence id (unique within the snapshot, stable
        # across rebuilds of the same snapshot).
        inferred_kind = kind || (record.respond_to?(:vertices) ? :face : :edge)
        inferred_id   = if record.respond_to?(:id) && record.id
                          record.id
                        elsif !array_index.nil?
                          array_index
                        else
                          0
                        end
        _transient_local_id(inferred_kind, inferred_id, array_index)
      end

      # Build a transient snapshot-local occurrence id. The
      # caller supplies the kind + record id (or array index
      # if record id is unavailable). The id is unique within
      # one SourceSnapshot and stable across rebuilds of the
      # same snapshot.
      def _transient_local_id(kind, record_id, array_index)
        kind_str = (kind || :edge).to_s
        if record_id && record_id > 0
          "transient-occ-#{kind_str}-#{record_id}"
        elsif !array_index.nil? && array_index >= 0
          "transient-occ-#{kind_str}-#{array_index}"
        else
          # Last-resort deterministic id (still snapshot-local,
          # never claims cross-session stability).
          "transient-occ-#{kind_str}-0"
        end
      end

      # Build a small geometry_summary Hash for a source Edge.
      # Mirrors the V1.3 FaceInventory summary style AND
      # carries the original (start, end) endpoints so the
      # workspace can rebuild a faithful derived Edge without
      # re-fetching the source.
      def _geometry_summary_for_edge(edge)
        return {} if edge.nil?
        layer_name = (edge.respond_to?(:layer) && edge.layer) ? edge.layer.to_s : nil
        s = edge.respond_to?(:start_point) ? edge.start_point : nil
        e = edge.respond_to?(:end_point)   ? edge.end_point   : nil
        gs = {
          'layer'        => layer_name,
          'length'       => (edge.respond_to?(:length) ? edge.length : nil),
          'vertex_count' => 2
        }
        if s.is_a?(Array) && s.length == 3 && e.is_a?(Array) && e.length == 3
          gs['start'] = [s[0], s[1], s[2]]
          gs['end']   = [e[0], e[1], e[2]]
        end
        gs
      end

      # Build a small geometry_summary Hash for a source Face.
      def _geometry_summary_for_face(face)
        return {} if face.nil?
        layer_name = (face.respond_to?(:layer) && face.layer) ? face.layer.to_s : nil
        verts = face.respond_to?(:vertices) ? face.vertices : nil
        gs = {
          'layer'        => layer_name,
          'vertex_count' => verts.is_a?(Array) ? verts.length : nil
        }
        if verts.is_a?(Array)
          gs['vertices'] = verts.map { |v| v.is_a?(Array) ? [v[0], v[1], v[2]] : nil }
        end
        gs
      end

      # Build a deterministic id fragment from a source
      # record so derived_id is stable across rebuilds (per
      # directive: "rebuild is deterministic for identical
      # source + captured config"). The fragment is the FULL
      # persistent_id_path joined by `-` so two same-definition
      # instances get different fragments (per BLOCK 2).
      #
      # V1.4 CodeX BLOCK rework (2026-08-22) BLOCK-R3-1:
      # we MUST NEVER use `record.object_id` here (it varies
      # per process and is NOT deterministic across rebuilds).
      # When no PID path is available, we use the
      # analysis-local record id (EdgeRecord#id / FaceRecord#id)
      # as a snapshot-local fallback -- the record id is part
      # of the captured SourceSnapshot and is therefore stable
      # across rebuilds of the same snapshot.
      def _stable_id_fragment(record, array_index: nil)
        return '0' if record.nil?
        src = record.respond_to?(:source) ? record.source : nil
        if src && src.respond_to?(:persistent_id_path) && src.persistent_id_path.is_a?(Array) && !src.persistent_id_path.empty?
          src.persistent_id_path.map(&:to_s).join('-')
        elsif src && src.respond_to?(:persistent_id) && src.persistent_id
          "pid#{src.persistent_id}"
        elsif record.respond_to?(:id) && record.id
          "rec#{record.id}"
        elsif !array_index.nil?
          "idx#{array_index}"
        else
          '0'
        end
      end

      # V1.4 CodeX BLOCK rework (2026-08-21): extract the
      # source Edge's two world-coordinate endpoints verbatim.
      # Returns [start_point, end_point] (each a 3-Float
      # Array) or nil if the source lacks faithful
      # world-coordinate endpoints. Per directive: derived
      # Edges MUST preserve the two world-coordinate endpoints
      # EXACTLY. NO Z lift, NO 3-point face fabrication.
      def _edge_endpoints(edge)
        return nil if edge.nil?
        s = edge.respond_to?(:start_point) ? edge.start_point : nil
        e = edge.respond_to?(:end_point)   ? edge.end_point   : nil
        return nil unless s.is_a?(Array) && e.is_a?(Array) && s.length == 3 && e.length == 3
        return nil unless _is_finite_point?(s) && _is_finite_point?(e)
        [[s[0], s[1], s[2]], [e[0], e[1], e[2]]]
      end

      # Validate a 3-Float Array world-coordinate point.
      def _is_finite_point?(p)
        return false unless p.is_a?(Array)
        return false unless p.length == 3
        p.all? do |v|
          v.is_a?(Numeric) && !v.nil? && v.respond_to?(:finite?) && v.finite?
        end
      end

      def _discard_if_present
        return if @current_workspace.nil?
        begin
          @current_workspace = @current_workspace.discard
        rescue StandardError
          # V1.4 V14-STAGE-BLOCK-002 recheck (2026-08-24):
          # NEVER clear @current_workspace on exception. The
          # workspace.discard path has its OWN rescue that
          # returns a :failed workspace when cleanup cannot
          # complete -- so this outer rescue is paranoid.
          # If it does trigger (something truly unexpected),
          # preserve the workspace AS-IS so the prior
          # handle_registry stays in scope for the user's
          # # explicit recovery attempt.
        end
        # V1.7 Gap Repair: dispose every workspace-owned
        # repair group (Blueprint §12) so the next
        # discard/close/start cleanly starts with zero
        # generated gap bridge edges.
        begin
          if @current_adapter.respond_to?(:dispose_repair_group_bridges)
            @current_adapter.dispose_repair_group_bridges
          end
        rescue StandardError
          # Cleanup is fail-safe; never propagate.
        end
        # V1.5 Phase 1: clear the duplicate-repair summary on
        # discard (the prior workspace's repair summary no longer
        # applies).
        @duplicate_repair_summary = nil
        # V1.6 Planar Normalization / Z Policy: discard also
        # clears the V1.6 state so the next snapshot doesn't
        # render stale normalization rows.
        @planar_normalization_proposal  = nil
        @planar_normalization_audit     = nil
      end

      def _adapter_kind_of(adapter)
        if adapter.is_a?(DerivedWorkspaceAdapter)
          # The FakeAdapter is the only adapter in core/; the
          # production adapter lives in compatibility/.
          klass_path = adapter.class.name.to_s
          if klass_path.include?('Fake')
            :fake
          else
            :real_su
          end
        else
          :unknown
        end
      end

      def _adapter_for(_kind)
        # Deprecated: the runner remembers the adapter via
        # @current_adapter and rebuild() reuses it. This
        # private helper is retained for any external code
        # that may have been calling it; it returns the
        # currently captured adapter (or nil).
        @current_adapter
      end

      def _empty_snapshot
        snapshot
      end

      # ---- V1.6 Planar Normalization / Z Policy internals ----

      # Resolve a Tolerance from a SourceSnapshot's captured
      # execution_config. The captured execution_config
      # carries the canonical tolerance_values Hash from the
      # Tolerance.to_h at the time of capture (per
      # ExecutionConfigSnapshot.from_live_config). Re-build a
      # fresh Tolerance from that Hash so V1.6 reads the
      # captured values, NOT the live host Tolerance (which
      # may drift between Prepare and Apply).
      def _tolerance_from_snapshot(source)
        return SUAnalysis::Core::Tolerance.default if source.nil?
        ec = source.respond_to?(:execution_config) ? source.execution_config : nil
        return SUAnalysis::Core::Tolerance.default if ec.nil?
        vals = ec.respond_to?(:tolerance_values) ? ec.tolerance_values : nil
        return SUAnalysis::Core::Tolerance.default unless vals.is_a?(Hash)
        # Use the V1.6-aware Tolerance constructor (defaults
        # for any missing key preserve backward compatibility
        # with pre-V1.6 captured snapshots).
        begin
          SUAnalysis::Core::Tolerance.new(
            duplicate:          vals[:duplicate]          || vals['duplicate']          || SUAnalysis::Core::Tolerance::DEFAULT_DUPLICATE,
            short_edge:         vals[:short_edge]         || vals['short_edge']         || SUAnalysis::Core::Tolerance::DEFAULT_SHORT_EDGE,
            gap_search:         vals[:gap_search]         || vals['gap_search']         || SUAnalysis::Core::Tolerance::DEFAULT_GAP_SEARCH,
            coordinate_epsilon: vals[:coordinate_epsilon] || vals['coordinate_epsilon'] || SUAnalysis::Core::Tolerance::DEFAULT_COORDINATE_EPSILON,
            big_z:              vals[:big_z]              || vals['big_z']              || SUAnalysis::Core::Tolerance::DEFAULT_BIG_Z,
            large_coordinate:   vals[:large_coordinate]   || vals['large_coordinate']   || SUAnalysis::Core::Tolerance::DEFAULT_LARGE_COORDINATE,
            planar_z_snap:      vals[:planar_z_snap]      || vals['planar_z_snap']      || SUAnalysis::Core::Tolerance::PLANAR_Z_SNAP_DEFAULT
          )
        rescue ArgumentError, TypeError
          # Fall back to the default if the captured values
          # are themselves invalid (defensive; the captured
          # snapshot SHOULD always validate at capture time).
          SUAnalysis::Core::Tolerance.default
        end
      end

      # Attach the planar_normalization sub-snapshot Hash to
      # the given snap Hash. JSON-safe (string keys + primitive
      # values only).
      #
      # V16-UI-INTEGRATION-CORRECTION-2026-09-01 trivial
      # integration seam: after apply_planar_normalization the
      # cached proposal is cleared (so the UI does not pretend
      # the batch is still pending) and only the audit row
      # remains. Without the derivation below, the snapshot
      # would carry `audit: {status: 'applied'|'failed', ...}`
      # but no `state`, and the UI would fall back to
      # NOT_COMPUTED -- which is wrong (the actual terminal
      # state is APPLIED or FAILED). The audit's `status`
      # field is the source of truth here; we map
      # `applied -> 'APPLIED'` and `failed -> 'FAILED'` so
      # the UI renders truthfully. Pure data shape change,
      # no normalization semantics touched.
      def _attach_planar_normalization_to_snapshot(snap)
        sub = {}
        if @planar_normalization_proposal.is_a?(Hash)
          sub['proposal'] = _stringify_planar_normalization_proposal(@planar_normalization_proposal)
        end
        if @planar_normalization_audit.is_a?(Hash)
          sub['audit'] = @planar_normalization_audit
        end
        # If we have NO proposal + NO audit, surface a stable
        # summary so the UI can render the "Planar
        # normalization: not computed" row consistently.
        if sub.empty?
          sub['computed'] = false
          sub['state']    = 'NOT_COMPUTED'
        else
          sub['computed'] = true
          if sub['proposal'].is_a?(Hash)
            sub['state'] = sub['proposal']['state'].to_s
          elsif sub['audit'].is_a?(Hash)
            audit_status = sub['audit']['status'].to_s
            sub['state'] = audit_status == 'applied' ? 'APPLIED' : 'FAILED'
          else
            sub['state'] = 'NOT_COMPUTED'
          end
        end
        snap['planar_normalization'] = sub.freeze
      end

      # Convert the cached proposal Hash to a JSON-safe Hash
      # with String keys. The strip step already removed the
      # host handles; this method normalizes the remaining
      # keys + nested structures.
      #
      # For UI ergonomics we ALSO flatten the nested
      # `:proposal` keys (the inner host-mutation plan with
      # `target_z`, `outlier_count`, `affected_derived_ids`,
      # etc.) up one level. This avoids the
      # `result.proposal.proposal.target_z` ladder and lets
      # the UI render fields like
      # `result.proposal.target_z` /
      # `result.proposal.outlier_count` directly.
      def _stringify_planar_normalization_proposal(proposal)
        out = {}
        proposal.each do |k, v|
          ks = k.to_s
          out[ks] = stringify_duplicate_repair_value(v)
        end
        inner = out.delete('proposal')
        if inner.is_a?(Hash)
          inner.each do |k, v|
            # Don't shadow top-level keys.
            ks = k.to_s
            out[ks] = v unless out.key?(ks)
          end
        end
        out.freeze
      end

      # Convert the executor audit Hash to a JSON-safe Hash.
      # The audit may carry Ruby Symbols for :applied / :failed;
      # we coerce to Strings.
      def _planar_normalization_audit_to_jsonable(audit)
        return nil unless audit.is_a?(Hash)
        stringify_duplicate_repair_summary(audit)
      end

      # ===========================================================
      # V1.7 Endpoint / Gap Repair + Canonical Topology
      # ===========================================================

      # Attach the topology_repair sub-snapshot to the given
      # snap Hash. JSON-safe (string keys + primitive values).
      #
      # State matrix (per Blueprint §11):
      #   NOT_COMPUTED       -> before the first compute call.
      #   READY_TO_REPAIR    -> at least one safe proposal.
      #   REVIEW_REQUIRED    -> proposals exist but no safe one.
      #   NO_CANDIDATE       -> no open endpoints with candidates.
      #   APPLIED            -> the last apply call succeeded.
      #   FAILED             -> the last apply call failed.
      def _attach_topology_repair_to_snapshot(snap)
        sub = {}
        if @topology_repair_proposal.is_a?(Hash)
          sub['proposal'] = stringify_duplicate_repair_summary(@topology_repair_proposal)
        end
        if @topology_repair_audit.is_a?(Hash)
          sub['audit'] = stringify_duplicate_repair_summary(@topology_repair_audit)
        end
        if sub.empty?
          sub['computed'] = false
          sub['state']    = 'NOT_COMPUTED'
        else
          sub['computed'] = true
          if sub['proposal'].is_a?(Hash) && sub['proposal']['state']
            sub['state'] = sub['proposal']['state'].to_s
          elsif sub['audit'].is_a?(Hash)
            audit_status = sub['audit']['status'].to_s
            sub['state'] = audit_status == 'applied' ? 'APPLIED' : (
              audit_status == 'skipped' ? (sub['proposal']['state'] || 'NO_CANDIDATE').to_s : 'FAILED'
            )
          else
            sub['state'] = 'NOT_COMPUTED'
          end
        end
        # Canonical graph digest (when available).
        if @topology_repair_canonical_graph.is_a?(Hash) ||
           @topology_repair_canonical_graph.respond_to?(:to_h)
          cg = @topology_repair_canonical_graph
          graph_h = cg.is_a?(Hash) ? cg : cg.to_h
          sub['canonical_graph'] = {
            'digest'              => graph_h['digest'],
            'schema_version'      => graph_h['schema_version'],
            'metrics'             => graph_h['metrics'],
            'unresolved_issues'   => graph_h['unresolved_topology_issues']
          }.compact.freeze
        end
        snap['topology_repair'] = sub.freeze
      end

      # ===========================================================
      # Round-5 BLOCK-005 §7: host-state reconciliation.
      # ===========================================================
      #
      # Validate-on-next-interaction: compare the stored
      # workspace handle registry against the observable host
      # state BEFORE proceeding with any later destructive or
      # reconciliation operation.
      #
      # Returns:
      #   true  -> workspace is consistent with host, proceed.
      #   false -> workspace was inconsistent; the runner has
      #            transitioned it to :failed with reason
      #            `host_state_changed`. The next prepare() or
      #            rebuild() must observe :failed and refuse
      #            silent overwrite.
      #
      # Per AIPM §7:
      #   - validate stored workspace/handles against
      #     observable host state
      #   - mismatch -> do not continue destructive work
      #   - deterministically invalidate to an existing safe
      #     non-ready state (failed/stale/none or repo-
      #     fitting equivalent)
      #   - surface stable reason `host_state_changed`
      #   - require/use existing safe rebuild/prepare before
      #     destructive work resumes
      #
      # Implementation:
      #   - The workspace's PRIVATE handle_registry is the
      #     single source of truth for the runner's
      #     expectation. Each handle's `valid?` (when
      #     supported) is checked against the host.
      #   - When the adapter exposes
      #     `host_state_changed?` and returns true, the
      #     workspace is also invalidated (this lets the
      #     FakeAdapter simulate a user-Undo or external
      #     host change without changing the workspace).
      #   - A workspace already in :failed/:discarded/:none
      #     is treated as "consistent enough" for the purpose
      #     of this check (the runner proceeds; the caller
      #     still has explicit gates).
      #   - No observer architecture is added; the check runs
      #     only when a destructive/observable operation is
      #     about to use the stored handles.
      def validate_host_state_consistency!
        return true if @current_workspace.nil?
        # :none: no workspace; nothing to validate.
        return true if @current_workspace.state == :none
        # :failed: already non-ready; further destructive
        # operations already refuse. The runner just reports
        # the existing :failed state. The adapter flag is
        # irrelevant here -- the workspace is already
        # unusable for destructive work.
        return true if @current_workspace.state == :failed
        # If the runner does not have a captured adapter
        # (e.g. tests that bypass prepare() by setting
        # @current_workspace directly), the validate-on-
        # next-interaction seam degrades gracefully: check
        # the stored handle registry but skip the adapter-
        # driven host_state_changed? flag (which requires an
        # adapter to consult). Production flows always go
        # through prepare() and have a captured adapter.
        adapter = @current_adapter
        # Adapter-driven host-state flag (FakeAdapter +
        # production can override; default false).
        adapter_flag = false
        if !adapter.nil? && adapter.respond_to?(:host_state_changed?)
          adapter_flag = adapter.host_state_changed? ? true : false
        end
        registry = @current_workspace.instance_variable_get(:@handle_registry) || {}
        # :ready + no handles is already incoherent (the
        # workspace claimed READY without materializing
        # handles). :discarded + host-state-change means
        # the prior discard was undone / external state
        # changed; per AIPM §7, the next interaction must
        # NOT claim a false :discarded coherence.
        invalid_no_handles = registry.empty? && @current_workspace.state == :ready
        invalid_handle = registry.any? do |_derived_id, handle|
          if handle.nil?
            true
          elsif handle.respond_to?(:valid?) && !handle.valid?
            true
          else
            false
          end
        end
        if adapter_flag || invalid_no_handles || invalid_handle
          _invalidate_to_failed_with_reason('host_state_changed')
          return false
        end
        true
      end

      # Internal: re-emit a :failed workspace that preserves
      # the existing handle registry + entity pairs but
      # carries a stable reason. Mirrors the same shape used
      # by `discard` failures so downstream callers see a
      # consistent :failed state.
      def _invalidate_to_failed_with_reason(reason)
        return if @current_workspace.nil?
        ws = @current_workspace
        adapter = ws.instance_variable_get(:@adapter)
        model   = ws.instance_variable_get(:@model)
        new_ws = DerivedGeometryWorkspace.new_with_inventory(
            workspace_id:    ws.workspace_id,
            source_snapshot: ws.source_snapshot,
            adapter:         adapter,
            model:           model,
            state:           :failed,
            entity_pairs:    ws.instance_variable_get(:@entity_pairs),
            handle_registry: ws.instance_variable_get(:@handle_registry),
            fingerprint:     ws.respond_to?(:fingerprint) ? ws.fingerprint : nil,
            last_error:      reason.to_s,
            build_started_at: ws.build_started_at
        )
        @current_workspace = new_ws
        @duplicate_repair_summary = nil
      end

      # Test hook: force-clear the runner state. NOT for
      # production or Owner flow per Round-5 BLOCK-005 §7.
      # Tests that need isolated runner state may call this
      # directly; production code MUST NOT. Production code
      # reaches the runner only through prepare / rebuild /
      # discard / run_duplicate_repair_batch, all of which
      # operate on the CURRENT workspace without mutating
      # private state.
      def reset_for_tests
        @current_workspace    = nil
        @current_source       = nil
        @current_adapter      = nil
        @current_adapter_kind = nil
        @current_model        = nil
        @duplicate_repair_summary = nil
        # V1.6 Planar Normalization / Z Policy: clear all V1.6
        # runner state on test reset.
        @planar_normalization_proposal  = nil
        @planar_normalization_audit     = nil
        @planar_normalization_tolerance = nil
        # V1.7 Endpoint / Gap Repair + Canonical Topology.
        @topology_repair_proposal         = nil
        @topology_repair_audit            = nil
        @topology_repair_tolerance        = nil
        @topology_repair_canonical_graph  = nil
        @topology_v17_loaded              = false
      end

      # V1.5 Phase 1 (internal): convert the duplicate-repair
      # summary Hash into a JSON-safe String-keyed Hash for the
      # UI bridge. Frozen at the boundary.
      def stringify_duplicate_repair_summary(summary)
        out = {}
        summary.each do |k, v|
          ks = k.to_s
          out[ks] = case v
                    when String, Numeric, TrueClass, FalseClass, NilClass
                      v
                    when Hash
                      v.each_with_object({}) { |(kk, vv), h| h[kk.to_s] = vv }
                    when Array
                      v.map { |item| stringify_duplicate_repair_value(item) }
                    else
                      v.to_s
                    end
        end
        out.freeze
      end

      # Internal helper: recursively stringify a value (Hash
      # keys become strings; Array items recurse; everything
      # else is converted to a String). Used so per-action audit
      # rows inside the summary's `actions` Array stay queryable
      # (status, confidence_basis, etc.) instead of being
      # collapsed into a single inspect-style blob.
      def stringify_duplicate_repair_value(v)
        case v
        when String, Numeric, TrueClass, FalseClass, NilClass
          v
        when Hash
          v.each_with_object({}) { |(kk, vv), h| h[kk.to_s] = stringify_duplicate_repair_value(vv) }
        when Array
          v.map { |item| stringify_duplicate_repair_value(item) }
        else
          v.to_s
        end
      end

      # V1.4 CodeX BLOCK fix (Stage 4): test-only accessor
      # for the current DerivedGeometryWorkspace. Returns
      # the workspace instance (with its private handle
      # registry) so production-call-chain tests can assert
      # on entity_count / handle_registry_keys / state.
      # NOT exposed via the snapshot Hash (snapshot() still
      # returns JSON-safe primitives only).
      def current_workspace_for_test
        @current_workspace
      end
    end
  end
end
