#
# extension/su_ai_plugin/cad_prep_workflow_orchestrator.rb —
# V1.9A-A2 ONE-CLICK DIAGNOSTICS ORCHESTRATOR.
#
# Per dispatch (Prompt/CURRENT_PI_DISPATCH.md, V1.9A-A2) and
# Blueprint §5.2:
#
#   A bounded orchestrator that coordinates the EXISTING
#   WorkingModeRunner production methods into a single
#   deterministic pipeline.
#
# The orchestrator:
#   - coordinates prepare + duplicate batch + planar compute +
#     gap compute + structure compute (the Start pipeline);
#   - owns the post-apply downstream recompute rules (after
#     Z repair, after gap repair);
#   - owns the Refresh rule (validate current workspace,
#     re-run read-only diagnostics, do NOT rebuild);
#   - owns the Rebuild-and-scan rule (existing rebuild +
#     duplicate batch + full diagnostics);
#   - honors the gap-ordering safety rule (refuse gap
#     mutation while planar state is still
#     READY_TO_NORMALIZE, even if a buggy UI somehow
#     dispatches the apply callback).
#
# The orchestrator does NOT:
#   - own any V1.4 / V1.5 / V1.6 / V1.7 / V1.8 algorithm
#     (all geometry / topology / structure logic stays in
#     the existing production modules);
#   - move, mutate, or discard source CAD (it only
#     delegates to the runner, which already enforces the
#     source-immutability contract);
#   - own tolerance, canonical graph identity, or
#     transaction / Undo architecture (all owned by the
#     runner + executor pair);
#   - introduce threads / timers / background workers /
#     progress animations (per dispatch §10, no fake
#     progress architecture);
#   - raise a different exception class than the
#     production code; on StandardError, the orchestrator
#     logs and re-publishes the truthful snapshot so the
#     UI shows a FAILED recovery state instead of a
#     silent broken state.
#
# Authority:
#   Prompt/AIPM_STAGE_PRODUCT_TECHNICAL_BLUEPRINT_V1_9A_V1_9B_2026-09-04.md
#   + dispatch Prompt/CURRENT_PI_DISPATCH.md (V1.9A-A2).
#
# Frozen V1.4 / V1.5 / V1.6 / V1.7 / V1.8 contracts UNCHANGED.
# No algorithm change. No source CAD mutation. No Face /
# Observer architecture. No V1.9B. No MCP / LLM / Agent.
#

require_relative 'core/working_mode_runner'

module SUAnalysis
  module Extension
    module CadPrepWorkflowOrchestrator
      module_function

      # Start the full deterministic pipeline:
      #   prepare + duplicate batch + planar compute +
      #   gap compute + structure compute.
      # One user click on `开始处理`. Returns the final
      # snapshot Hash.
      #
      # Inputs (per dispatch §3.1):
      #   source:  frozen SourceSnapshot (immutable).
      #   adapter: production or fake adapter.
      #   model:   the SketchUp model the controller was
      #            bound to (may be nil in tests).
      #   registry: AnalysisResult.registry (the existing
      #            IssueRegistry that already carries
      #            duplicate_edge_candidate evidence).
      #            When nil, the duplicate batch is
      #            skipped (defensive).
      def start(source:, adapter:, model: nil, registry: nil)
        # Step 1: prepare derived workspace. If the
        # workspace is no longer ready (prepare failed or
        # the host invalidated it), we stop the pipeline
        # and return the truthful snapshot.
        snap = SUAnalysis::Core::WorkingModeRunner.prepare(
          source:  source,
          adapter: adapter,
          model:   model
        )
        return snap unless _workspace_ready?(snap)

        # Step 2: V1.5 high-confidence duplicate repair
        # batch (existing production method). Defensive
        # skip when the registry is nil.
        if registry
          snap = SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(
            registry: registry
          )
          return snap unless _workspace_ready?(snap)
        end

        # Steps 3-5: read-only diagnostics on the
        # current prepared workspace. Per dispatch §3.1
        # each step reads the snapshot the previous step
        # returned; if the workspace is no longer ready
        # (host invalidation, a prior step failure, ...)
        # the pipeline stops. We do NOT silence the
        # actionable / review_required state.
        snap = SUAnalysis::Core::WorkingModeRunner.compute_planar_normalization
        return snap unless _workspace_ready?(snap)
        snap = SUAnalysis::Core::WorkingModeRunner.compute_gap_repair
        return snap unless _workspace_ready?(snap)
        snap = SUAnalysis::Core::WorkingModeRunner.compute_structure_reconstruction
        snap
      rescue StandardError
        # Defensive: surface the truthful snapshot. The
        # runner is the single source of truth; the
        # orchestrator never invents state.
        SUAnalysis::Core::WorkingModeRunner.snapshot
      end

      # Refresh: re-run the read-only diagnostics on the
      # CURRENT prepared workspace. Per dispatch §3.2:
      #   - validate host/workspace consistency via the
      #     EXISTING validate_host_state_consistency!
      #     authority (no new validator, no rewrite);
      #   - if stale/failed, fail closed (return the
      #     runner's truthful snapshot);
      #   - do NOT call prepare;
      #   - do NOT call rebuild;
      #   - do NOT call the duplicate-repair mutation
      #     (duplicate cleanup is a one-shot per workspace);
      #   - recompute planar / gap / structure on the
      #     current workspace.
      def refresh
        unless SUAnalysis::Core::WorkingModeRunner.validate_host_state_consistency!
          return SUAnalysis::Core::WorkingModeRunner.snapshot
        end
        snap = SUAnalysis::Core::WorkingModeRunner.compute_planar_normalization
        return snap unless _workspace_ready?(snap)
        snap = SUAnalysis::Core::WorkingModeRunner.compute_gap_repair
        return snap unless _workspace_ready?(snap)
        SUAnalysis::Core::WorkingModeRunner.compute_structure_reconstruction
      rescue StandardError
        SUAnalysis::Core::WorkingModeRunner.snapshot
      end

      # Apply Z and refresh: orchestrate the existing
      # apply_planar_normalization + the dispatch §4.1
      # post-Z invalidation + downstream recompute.
      # On success, the user sees the current gap +
      # structure diagnostics rebuilt against the
      # post-Z workspace (NO manual click on 检查间隙 /
      # 检查结构).
      #
      # Defense-in-depth: the orchestrator refuses
      # mutation when the current workspace state is not
      # :ready (the runner's :ready guard already does
      # this, but the orchestrator's guard is the
      # canonical "no public re-entrance" seam).
      def apply_planar_and_refresh
        snap = SUAnalysis::Core::WorkingModeRunner.snapshot
        return snap unless _workspace_ready?(snap)
        # Step 1: validate host state. The runner's
        # apply path validates again internally; this
        # outer check is the orchestrator's canonical
        # "fail closed before any mutation" seam.
        unless SUAnalysis::Core::WorkingModeRunner.validate_host_state_consistency!
          return SUAnalysis::Core::WorkingModeRunner.snapshot
        end
        snap = SUAnalysis::Core::WorkingModeRunner.apply_planar_normalization
        return snap unless _workspace_ready?(snap)
        # Step 2: dispatch §4.1 invalidation seam.
        # Clear stale V1.7 proposal / audit / canonical
        # graph state (the runner preserves the captured
        # tolerance; the seam is the only state cleared).
        SUAnalysis::Core::WorkingModeRunner.invalidate_topology_state_after_geometry_mutation
        # Step 3: recompute gap on the post-Z workspace
        # (so the user sees the up-to-date gap state
        # without manually clicking 检查间隙).
        snap = SUAnalysis::Core::WorkingModeRunner.compute_gap_repair
        return snap unless _workspace_ready?(snap)
        # Step 4: recompute structure on the post-gap
        # workspace. SR18-05 already invalidates the V1.8
        # cache on planar apply; this is the explicit
        # refresh path the user-facing contract expects.
        SUAnalysis::Core::WorkingModeRunner.compute_structure_reconstruction
      rescue StandardError
        SUAnalysis::Core::WorkingModeRunner.snapshot
      end

      # Apply gap and refresh. Per dispatch §4.2:
      #   - validate current workspace;
      #   - apply existing apply_gap_repair authority
      #     (this is the runner's existing V1.7 path —
      #     it already rebuilds the canonical graph and
      #     clears the V1.8 cache on success);
      #   - on success, recompute structure exactly once
      #     (the user must NOT see a stale structure
      #     card after gap repair);
      #   - do NOT re-run compute_gap_repair just for
      #     cosmetic cleanliness (the apply path already
      #     published the post-gap audit; re-running
      #     would erase that audit for no real benefit).
      #
      # Gap-ordering safety (per dispatch §5.1): the
      # orchestrator refuses gap mutation when the
      # current planar state is still
      # READY_TO_NORMALIZE (the user must complete Z
      # correction first). This is the
      # defense-in-depth guard. The presenter ALSO
      # disables the gap repair action in this state;
      # both layers must agree.
      def apply_gap_and_refresh
        snap = SUAnalysis::Core::WorkingModeRunner.snapshot
        return snap unless _workspace_ready?(snap)
        # Gap-ordering safety: refuse mutation when
        # planar is still actionable. The presenter
        # already disables the gap action in this
        # state; this is the orchestrator's canonical
        # backstop.
        if _planar_state_actionable?(snap)
          # Truthful return: the workspace state is
          # unchanged; the next UI render will surface
          # the planar card + the still-gated gap card.
          # The user must complete Z repair first.
          return snap
        end
        unless SUAnalysis::Core::WorkingModeRunner.validate_host_state_consistency!
          return SUAnalysis::Core::WorkingModeRunner.snapshot
        end
        snap = SUAnalysis::Core::WorkingModeRunner.apply_gap_repair
        return snap unless _workspace_ready?(snap)
        # Per dispatch §4.2: do NOT re-run
        # compute_gap_repair here (it would erase the
        # applied audit). Recompute structure exactly
        # once so the structure card reflects the
        # post-gap canonical graph.
        SUAnalysis::Core::WorkingModeRunner.compute_structure_reconstruction
      rescue StandardError
        SUAnalysis::Core::WorkingModeRunner.snapshot
      end

      # Rebuild and scan: existing rebuild authority +
      # duplicate batch + full read-only diagnostics.
      # Distinct from Refresh: rebuild discards the
      # prior workspace and rebuilds the derived copy
      # from the captured source.
      #
      # Per dispatch §7 the user may invoke this from
      # the recovery flow. The orchestrator honors the
      # existing fail-closed Undo / host-state
      # reconciliation contract: if the runner's
      # validate_host_state_consistency! refuses the
      # rebuild (host state has drifted), the rebuild
      # path returns the truthful snapshot unchanged.
      def rebuild_and_scan(source:, adapter:, model: nil, registry: nil)
        # Step 1: existing rebuild authority. The
        # runner already calls validate_host_state_
        # consistency! at the top of rebuild and
        # refuses on stale host state. We do NOT
        # bypass that contract.
        snap = SUAnalysis::Core::WorkingModeRunner.rebuild
        # Rebuild returned the truthful snapshot.
        # If the runner is in a non-ready state (e.g.
        # rebuild was refused, or the captured
        # source is missing), we surface that
        # snapshot and stop. We do NOT try to
        # prepare from scratch on the orchestrator
        # side (the rebuild path is the canonical
        # "reuse captured source" entry; a missing
        # captured source means the user must do
        # something else).
        return snap unless _workspace_ready?(snap)
        # Step 2: replay the duplicate batch on the
        # rebuilt workspace (the runner's existing
        # rebuild path already prepared; this is the
        # post-rebuild V1.5 batch replay).
        if registry
          snap = SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(
            registry: registry
          )
          return snap unless _workspace_ready?(snap)
        end
        # Step 3: full diagnostics.
        snap = SUAnalysis::Core::WorkingModeRunner.compute_planar_normalization
        return snap unless _workspace_ready?(snap)
        snap = SUAnalysis::Core::WorkingModeRunner.compute_gap_repair
        return snap unless _workspace_ready?(snap)
        SUAnalysis::Core::WorkingModeRunner.compute_structure_reconstruction
      rescue StandardError
        SUAnalysis::Core::WorkingModeRunner.snapshot
      end

      # ---- internals ------------------------------------------------

      # Defensive: read the workspace state from the
      # runner's current snapshot. The orchestrator
      # trusts the runner's state authority; it does
      # NOT cache workspace state locally.
      def _workspace_ready?(snap)
        return false if snap.nil?
        st = snap.is_a?(Hash) ? snap['state'] : nil
        st.to_s == 'ready'
      end

      # Gap-ordering safety: return true when the
      # current planar state is READY_TO_NORMALIZE
      # (the user must complete Z repair first). The
      # orchestrator refuses gap mutation in this
      # state. Other planar states (NO_CANDIDATE,
      # APPLIED, REVIEW_REQUIRED, FAILED, BLOCKED,
      # NOT_COMPUTED) do NOT block gap repair —
      # REVIEW_REQUIRED is a non-actionable warning
      # that V1.7's own conservative rules already
      # handle.
      def _planar_state_actionable?(snap)
        return false if snap.nil? || !snap.is_a?(Hash)
        pn = snap['planar_normalization']
        return false unless pn.is_a?(Hash)
        pn['state'].to_s == 'READY_TO_NORMALIZE'
      end
    end
  end
end
