# V1.5 Phase 1 — Owner-Gate BLOCK RECHECK PACKET #2 (2026-08-25)

Date: 2026-08-25
Branch: v1.5-high-confidence-auto-repair
Review: CodeX V1.5 Phase 1 BLOCK RECHECK #2 (BLOCK-003 + BLOCK-004 re-opens)

## Verdict addressed

CodeX V1.5 Phase 1 BLOCK RECHECK #2 (2026-08-25):
  REVIEW MODE: BLOCK RECHECK
  BASE/HEAD:   215152a..1ec7c00
  VERDICT:     BLOCKED
  BLOCKS:
    BLOCK-001 (production load wiring) -- CLOSED
    BLOCK-002 (Prepare/Rebuild production call chain + UI summary) -- CLOSED
    BLOCK-005 (one-operation batch apply/abort implementation) -- CLOSED
    BLOCK-003 (real production provenance unreachable) -- OPEN
    BLOCK-004 (Owner checklist not executable/correct) -- OPEN

This commit addresses BLOCK-003 and BLOCK-004.

## Per-BLOCK recheck #2 evidence

### BLOCK-003 — real production provenance

**Root cause (per CodeX):** The PreflightRunner's
`walk_entity_world` appends every entity's PID to the
pid_path INCLUDING the leaf edge PID. The V1.0-V1.4
canonical `persistent_id_path` therefore includes the leaf
edge PID as its last element. The previous proposer's
`occurrence_id_for` used the full path, so two distinct
duplicate edges in the SAME parent component had DIFFERENT
V1.4 occurrence IDs (different leaf PIDs) and were never
detected as duplicates.

**Fix (per CodeX):** The proposer now derives a SEPARATE
V1.5 container-occurrence identity by EXCLUDING the leaf
PID (the last element of the canonical `persistent_id_path`).
The canonical `persistent_id_path` is NOT mutated
(V1.0-V1.4 contracts preserved). For each workspace's
derived records, `build_occurrence_to_deriveds` reverses the
V1.4 source_occurrence_ids back into the pid_path Array
(via `parse_v14_occurrence_to_container_path`) and
computes the V1.5 container-occurrence for matching.

**Top-level (root-level) edges:** The leaf is the ONLY
element of the path. The container_path after exclusion is
empty. Per CodeX fail-closed guidance, V1.5 Phase 1
EXCLUDES root-level edges from auto-repair
(`occurrence_id_for` returns nil). The repair is only
meaningful within a non-root container (a Group or a
ComponentInstance) where two duplicate edges indicate a
CAD-import artifact inside one parent.

**Real-PreflightRunner regression tests added:**
`tests/test_v15_real_preflight_path.rb` exercises the FULL
production pipeline end-to-end:

  V15RP-001: real PreflightRunner path -- duplicate edges
             inside ONE ComponentInstance ARE repaired.
             (proves the V1.5 container-occurrence catches
             the CAD-import-duplicate case.)

  V15RP-002: real PreflightRunner path -- two ComponentInstances
             of the SAME definition are NOT cross-merged.
             (proves the shared-component isolation is
             preserved; each instance's duplicate pair is
             repaired independently.)

  V15RP-003: real PreflightRunner path -- no duplicates ->
             applied=0, ready. (proves the no-op path.)

  V15RP-004: real PreflightRunner path -- root-level edges
             have pid_path length 1 (leaf only) and are
             correctly identified as fail-closed.

  V15RP-005: real PreflightRunner path -- source_fingerprint
             unchanged across apply.

The test uses the REAL PreflightRunner.build_snapshot +
AnalyzersRunner.run + WorkingModeRunner.prepare +
run_duplicate_repair_batch pipeline (not hand-crafted
EdgeRecords with fabricated equal pid_paths).

**Test fixtures updated:**
The helper `v15_edge` / `v15pc_edge` now accepts
`parent_pid_path: [100, 200]` (the container path) and
builds the full canonical pid_path
`[parent_pid_path..., leaf_pid]`. This matches what
real-SketchUp's PreflightRunner produces. The old
fixtures that bypassed the leaf are now correct.

### BLOCK-004 — Owner checklist executable

**Root cause (per CodeX):** The previous checklist relied
on (a) `$su_ai_plugin_dialog_controller` (which is never
defined in production), (b) `@next_dispose_should_raise`
(which is not a production adapter hook), (c) fixture
construction that required Owner to manually create
coincident SU edges.

**Fixes:**

1. **`SUAnalysis::Extension::DialogRunner.current_controller`
   module-level accessor.** The dialog's controller is
   published when `show` is called and cleared in `on_close`.
   Owner uses this from the Ruby Console instead of
   undefined globals.

2. **Production `dispose` one-shot failure hook.**
   `SketchupDerivedWorkspaceAdapter#dispose` now reads
   `@__v15_one_shot_failure`. When set to a
   `StandardError` instance, the FIRST `dispose` call
   raises and clears the hook (one-shot by design).
   Subsequent calls work normally without intervention.

3. **Auto-creating test fixtures.** All V15-N steps use
   Ruby Console commands that build their own Component
   Definitions + Instances + edges. The Owner NEVER
   manually constructs coincident SU edges.

4. **V15-2 contradiction fixed.** V15-2 uses a definition
   with NO internal duplicates (4 distinct edges) and
   places TWO ComponentInstances of it. The cross-instance
   case has no candidate duplicates (different
   world coords), so applied=0 and skipped=0.

5. **Replaced placeholder `<YOUR_USERNAME>`** with an
   inline Ruby expression: `File.expand_path('~')` returns
   the Owner-specific path.

6. **Per-step PASS outputs and cleanup commands.** Each
   step lists the expected output and includes a
   paste-cleanup command that removes the fixture from the
   model.

## Test evidence

| Suite                       | Before    | After     |
|-----------------------------|-----------|-----------|
| Full Ruby (all)             | 695/695   | 700/700   |
| V1.5 Phase 1 Ruby tests     | 31/31     | 36/36     |
| V15 (pure-data)              | 21        | 21        |
| V15PC (production chain)     | 10        | 10        |
| V15RP (real Preflight path)  | (none)    | 5         |
| Node DOM (all)              | 154/154   | 154/154   |
| RBZ smoke                   | 8/8       | 8/8       |
| git diff --check            | clean     | clean     |
| working tree                | clean     | clean     |

## Final V1.5 Phase 1 RBZ

  Path:    D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz
  Size:    504,298 bytes
  Entries: 55
  SHA256:  8C1162031C76B3E984906D821FBDB523D7241EC20D8400CF3C931061FBABD2D4

## Hard limits inherited

- NOT pushed / published / installed / released.
- NOT modified V1.0-V1.4 closed scope.
- NOT entered V1.5 Phase 2 / V1.6+ / V1.7+ / V1.8 / V1.9.
- NOT handled short edge / approximate / face / gap / weld /
  flatten / AI / MCP / V2.
- NOT asked Owner to install the previous RBZ (1ec7c00).

## STOP

CodeX: please review BLOCK-003 + BLOCK-004 ONLY. Do not widen
scope. On PASS, Owner runs the rewritten checklist on real SU2020.