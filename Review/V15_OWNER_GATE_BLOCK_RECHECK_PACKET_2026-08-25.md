# V1.5 Phase 1 — Owner-Gate BLOCK RECHECK PACKET (2026-08-25)

Date: 2026-08-25
Branch: v1.5-high-confidence-auto-repair
Base: V1.4 closeout a7cedb4
HEAD: <this commit> (will be the new recheck fix commit)
Review: CodeX V1.5 Phase 1 Owner-Gate Readiness Review

## Verdict addressed

CodeX V1.5 Phase 1 Owner-Gate Readiness Review (2026-08-25):
  REVIEW MODE: V1.5 PHASE 1 STAGE / OWNER-GATE READINESS
  VERDICT:     BLOCKED
  BLOCKS:
    BLOCK-001 (production load wiring missing)
    BLOCK-002 (auto-repair not in production call chain)
    BLOCK-003 (provenance condition makes real product path unreachable)
    BLOCK-004 (Owner checklist not executable)
    BLOCK-005 (batch atomicity must be fixed)

## Per-BLOCK recheck evidence

### BLOCK-001 — production load wiring

**Fix:** `extension/su_ai_plugin/main.rb` `boot!` now requires
the new modules at the production boot step:

    require_relative 'core/duplicate_repair_proposer'
    require_relative 'core/duplicate_repair_executor'

**Evidence:**
- `tests/test_v15_production_call_chain.rb` V15PC-001 loads
  `extension/su_ai_plugin/main.rb` directly and asserts
  `SUAnalysis::Core::DuplicateRepairProposer` and
  `SUAnalysis::Core::DuplicateRepairExecutor` are defined.
- V15PC-002 extracts `dist/SU-AI-Plugin.rbz` into a temp dir,
  loads the extracted entry-point, and asserts the same modules
  are defined (production-evidence; not dev-tree).

### BLOCK-002 — auto-repair production call chain

**Fix:** `extension/su_ai_plugin/dialog_runner.rb`
`on_prepare_workspace` and `on_rebuild_workspace` now invoke
`WorkingModeRunner.run_duplicate_repair_batch(registry:)` after
Prepare/Rebuild. The chain is:

    Prepare (V1.4)
      -> IssueRegistry from controller.result.registry
      -> DuplicateRepairProposer.propose(source, registry, workspace)
      -> plan.validate
      -> DuplicateRepairExecutor.apply_batch(workspace, plan)
      -> WorkingModeRunner snapshot.duplicate_repair = real results

**Evidence:**
- `tests/test_v15_production_call_chain.rb`:
  - V15PC-003: WorkingModeRunner.run_duplicate_repair_batch runs
    the full chain end-to-end through the production
    SketchupDerivedWorkspaceAdapter + FakeModel; final
    `actions_applied == 1` (real execution result, not manual).
  - V15PC-004: no eligible actions -> ready + applied=0
    (idempotent no-op).
  - V15PC-009: Rebuild replay -> same post-state (deterministic).
  - V15PC-010: Discard -> source unchanged.

### BLOCK-003 — provenance semantics

**Fix:** `extension/su_ai_plugin/core/duplicate_repair_proposer.rb`
header now documents the EXACT provenance semantics:

  - `persistent_id_path` carried on the EdgeRecord's
    SourceReference is the CONTAINER path (NOT including the leaf
    Edge entity's own PID).
  - Two EdgeRecords from the SAME parent container (same
    `persistent_id_path`) = "same source occurrence".
  - Real-SU2020 constructible should-repair scenario: a
    ComponentDefinition containing two SU Edges with the same
    world endpoints (a CAD import artifact). The two edges
    share the instance's container path; the proposer detects
    them as duplicates.
  - Real-SU2020 constructible must-not-repair scenarios:
    (a) Two ComponentInstances of the same definition (different
        instance.persistent_id -> different paths): preserved.
    (b) Selection-overlap of the same edge entity (different
        container paths on each visit): preserved (different
        analysis visits, not a CAD import duplicate).

The proposer does NOT loosen to "all same world coordinates":
the master plan §17.2 (shared-component-definition instances
are physically separate geometry) is honored.

**Evidence:**
- `tests/test_v15_production_call_chain.rb`:
  - V15PC-005: real-SketchUp constructible should-repair.
  - V15PC-006: shared-definition two instances NOT merged.
  - V15PC-007: same-world-coords-different-provenance preserved.

### BLOCK-004 — Owner checklist

**Fix:** `Review/OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-25.txt`
rewritten to use ONLY real SketchUp 2020 operations:

  - Step V15-0: paste-load the entry-point from the installed
    Plugins folder (Ruby Console), verify both modules defined.
  - Step V15-1: GUI clicks Prepare + reads the Working Mode
    "Duplicate repairs" row in the dialog.
  - Step V15-2: Two shared-definition instances -> expect
    applied=0, skipped>=2.
  - Step V15-3: Discard + Rebuild -> source fingerprint
    byte-identical.
  - Step V15-4: Mid-action failure (Ruby Console inject) ->
    entire batch rolls back, applied=0, failed=1.
  - Step V15-5: Discard -> zero derived groups, source
    unchanged.
  - Step V15-6: Drop report at
    Prompt/OWNER_REPORT_V1_5_DUPLICATE_REPAIR_2026-08-25.txt.

**Evidence:**
- The checklist is now executable: every step either clicks a
  GUI button, reads a UI row, or pastes a single Ruby
  Console command. No FakeGroup / pure-Ruby test concepts.
- Every GUI step has an EXPECTED output.
- The Ruby Console commands are full single-line (no Owner
  Ruby authoring required).

### BLOCK-005 — batch atomicity

**Fix:** `extension/su_ai_plugin/core/duplicate_repair_executor.rb`
new method `apply_batch(workspace:, plan:)`:

  1. Pre-flight every action (compute per-action to_remove /
     present_ids / invalid_ids).
  2. Open ONE SU operation via `adapter.begin_operation`.
  3. Iterate actions in deterministic order; for each action,
     dispose its valid handles. On first dispose failure,
     break out of the loop.
  4. If ALL disposes succeed: `end_operation(commit: true)` ->
     build post-state workspace; every action :applied.
  5. If ANY dispose failed: `end_operation(commit: false)` ->
     the SU native operation rollback removes every entity
     write inside the batch (including prior successful
     disposes); workspace transitions to :failed; every action
     :failed.

Source fingerprint is unchanged across successful or failed
batch (the rollback restores the pre-batch workspace state).

The FakeAdapter (`FakeDerivedWorkspaceAdapter`) and FakeModel
already model SU's sequential-operation semantics (per V1.4
V14-STAGE-BLOCK-002): only ONE operation may be open at a time;
calling commit/abort with no matching start raises. The batch
test uses these fakes directly, so it cannot nest operations
to hide the contract.

**Evidence:**
- `tests/test_v15_production_call_chain.rb` V15PC-008: batch
  atomicity. PartiallyFailingAdapter raises on dispose call
  #2. The first action's dispose succeeds; the second
  action's dispose raises; the batch aborts; the workspace
  is :failed; ALL 4 entities preserved; FakeModel
  `operation_log` shows `:start, :abort` (NOT `:commit`).
- `tests/test_v15_production_call_chain.rb` V15PC-010: discard
  after batch leaves source unchanged (source_fingerprint
  digest matches pre-batch).

## Test evidence (post-recheck, pre-RBZ rebuild)

| Suite                       | Before    | After     |
|-----------------------------|-----------|-----------|
| Full Ruby (all)             | 677/677   | 695/695   |
| V1.5 Phase 1 Ruby tests     | 21/21     | 31/31     |
| Node DOM (all)              | 154/154   | 154/154   |
| V1.5 Phase 1 Node DOM tests | 6/6       | 6/6       |
| RBZ smoke                   | 8/8       | 8/8       |
| git diff --check            | clean     | clean     |
| working tree                | clean     | clean     |

## Recheck STOP

CodeX: please review BLOCK-001..005 ONLY. Do not widen scope,
do not enter V1.5 Phase 2, do not request additional features
beyond the locked vertical slice.

## Hard limits inherited

- NOT pushed / published / installed / released.
- NOT modified V1.0-V1.4 closed scope (only minimal additions to
  `working_mode_runner.rb` to expose the V1.5 metric + chain).
- NOT entered V1.5 Phase 2 / V1.6+ / V1.7+ / V1.8 / V1.9.
- NOT handled short edge / approximate / face / gap / weld /
  flatten / AI / MCP / V2.
- NOT asked Owner to install the previous RBZ (215152a).