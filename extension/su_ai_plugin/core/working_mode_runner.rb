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
      def discard
        _discard_if_present
        @duplicate_repair_summary = nil
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
      def rebuild
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
            post_edge_count:  new_ws.entities.length
          )
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
      def build_duplicate_repair_summary(plan:, updated_actions:, pre_classes: nil, post_validation: nil, pre_edge_count: nil, post_edge_count: nil, post_workspace: nil)
        applied = updated_actions.count { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
        skipped = updated_actions.count { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :skipped }
        failed  = updated_actions.count { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :failed }
        # Real duplicate_pairs counts:
        #   before: number of duplicate pairs the plan recognized
        #   after: number of pairs remaining after apply (0 on success)
        before_pairs = plan.actions.select { |a|
          a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :validated
        }.sum { |a| Array(a.affected_derived_ids).length }
        after_pairs  = applied > 0 ? 0 : before_pairs
        # Real class counts from measured data:
        pre_count  = pre_classes.is_a?(Hash) ? pre_classes.length : 0
        post_count = post_validation.is_a?(Hash) ? post_validation['duplicate_classes_after'].to_i : (applied > 0 ? 0 : pre_count)
        # Real edge counts from actual workspace inventory:
        before_edge_count = pre_edge_count
        after_edge_count  = post_edge_count
        if after_edge_count.nil? && post_workspace.respond_to?(:entities)
          after_edge_count = post_workspace.entities.length
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
          # Per-action audit rows (BLOCK-004: every action
          # audit retains source issue IDs/keys; the
          # inspectable structure exposes per-action status,
          # rule or explanation, removed count, survivor ID,
          # and source-occurrence count).
          'actions' => updated_actions.map { |a|
            if a.is_a?(SUAnalysis::Core::RepairAction)
              {
                'action_id'          => a.action_id.to_s,
                'status'             => a.status.to_s,
                'rule_id'            => a.rule_id.to_s,
                'explanation'        => a.explanation.to_s,
                'confidence_basis'   => a.confidence_basis.to_s,
                'source_occurrence_ids' => Array(a.source_occurrence_ids).map(&:to_s),
                'affected_derived_ids'  => Array(a.affected_derived_ids).map(&:to_s),
                'before_summary'     => (a.before_summary || {}).to_h
              }
            else
              { 'raw' => a.inspect }
            end
          }
        }.freeze
      end

      # V1.5 Phase 1: clear the duplicate-repair summary
      # (called when the workspace is discarded / rebuilt).
      def clear_duplicate_repair_summary
        @duplicate_repair_summary = nil
      end

      # V1.5 Phase 1: read-only accessor for tests / Owner
      # verification scripts. Returns the current summary Hash
      # or nil.
      def duplicate_repair_summary
        @duplicate_repair_summary
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
        # V1.5 Phase 1: clear the duplicate-repair summary on
        # discard (the prior workspace's repair summary no longer
        # applies).
        @duplicate_repair_summary = nil
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

      # Test hook: force-clear the runner state. Not used in
      # production; here for testing in isolation.
      def reset_for_tests
        @current_workspace    = nil
        @current_source       = nil
        @current_adapter      = nil
        @current_adapter_kind = nil
        @current_model        = nil
        @duplicate_repair_summary = nil
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
                      v.map { |item| item.is_a?(String) ? item : item.to_s }
                    else
                      v.to_s
                    end
        end
        out.freeze
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
