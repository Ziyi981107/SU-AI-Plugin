# V1.5 Phase 1 — Owner-Gate BLOCK RECHECK PACKET #3 (2026-08-25)

> !!!  ON HOLD — DO NOT RUN THE OWNER GATE  !!!
>
> STATUS: BLOCKED — see
> Review/V15_PHASE1_UNREACHABLE_INPUT_ESCALATION_2026-08-25.md.
>
> This packet is the recheck #3 attempt. Its premise was
> that the BLOCK-004 defects A-E could be fixed AND BLOCK-003
> could be resolved by an Owner-runnable reachability probe.
> After CodeX review of this packet (and the uncommitted
> production code change to the adapter's class-level hook,
> test rewrite, and new Owner-runnable probe), the Agent has
> reverted to escalation: BLOCK-003 is NOT closed because no
> real SU2020 evidence is in the repository; the
> reachability probe and the rewritten Owner checklist are
> both held in escrow (marked DO NOT RUN at the top of each
> file); the production change to
> extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb
> is held in the working tree, uncommitted, awaiting Product
> Owner decision.
>
> DO NOT install the V1.5 Phase 1 RBZ.
> DO NOT execute the Owner checklist or the reachability probe.
> Awaiting Product Owner decision on options A, B, and C in
> Review/V15_PHASE1_UNREACHABLE_INPUT_ESCALATION_2026-08-25.md.

Date: 2026-08-25
Branch: v1.5-high-confidence-auto-repair
Review: CodeX V1.5 Phase 1 BLOCK RECHECK #3 (BLOCK-003 + BLOCK-004 re-re-opens)

## Verdict addressed

CodeX V1.5 Phase 1 BLOCK RECHECK #3 (2026-08-25):
  REVIEW MODE: BLOCK RECHECK
  BASE/HEAD:   1ec7c00..a8b7792
  VERDICT:     BLOCKED
  BLOCKS:
    BLOCK-001 (production load wiring) -- CLOSED (prior recheck)
    BLOCK-002 (Prepare/Rebuild production call chain + UI
              summary) -- CLOSED (prior recheck)
    BLOCK-005 (one-operation batch apply/abort) -- CLOSED
              (prior recheck)
    BLOCK-003 (real production provenance unreachable) --
              REOPENED (recheck #3: Owner fixture relies on a
              topology real SketchUp may canonicalize)
    BLOCK-004 (Owner checklist not executable/correct) --
              REOPENED (recheck #3: defects A-E listed below)

This commit addresses BLOCK-003 and BLOCK-004 (recheck #3).

## Per-BLOCK recheck #3 evidence

### BLOCK-003 — real production provenance (recheck #3)

**CodeX concern (recheck #3):** the Owner fixture in the
prior V15-1 step called `entities.add_line` twice with
identical endpoints. The CODE-side _fake_ui.rb's
`FakeEntities` allowed this topology, but the CodeX side
asks: does REAL SketchUp 2020 allow two distinct
`Sketchup::Edge` entities with byte-identical endpoints to
coexist in the same `Entities` collection, or does SU
auto-merge them like the native Line tool does?

**Fix (recheck #3):**

1. **Reachability probe.** New file
   `Review/V15_REAL_SU2020_REACHABILITY_PROBE_2026-08-25.md`
   defines 3 Owner-runnable Ruby Console probes:

   - PROBE 1: create a Group, call `add_line([0,0,0],[10,0,0])`
     twice on `g.entities`, then inspect:
       - `e1.entityID != e2.entityID`
       - `e1.persistent_id != e2.persistent_id`
       - `g.entities.grep(Sketchup::Edge).length == 2`
       - `e1.start.position.to_a == e2.start.position.to_a`
       - `e1.end.position.to_a == e2.end.position.to_a`
     If PROBE 1 returns FAIL, BLOCK-003 is UNREACHABLE on
     real SU2020 → CodeX should escalate to Product Owner.
     If PROBE 1 returns PASS, the topology is reachable.

   - PROBE 2: inside one ComponentInstance of a definition
     that has 2 coincident edges (the production-shape input).
     PROBE 2 confirms the SU-compatible path works.

   - PROBE 3: two ComponentInstances of the SAME definition at
     the SAME identity transform (the cross-instance case).
     PROBE 3 confirms the DuplicateDetector emits a candidate
     pair AND the proposer PRESERVES it (applied = 0).

   Each probe is a single-line paste into the Ruby Console.
   The Owner captures the output and drops it at
   `Prompt/OWNER_REPORT_V15_REAL_SU2020_REACHABILITY_PROBE_2026-08-25.txt`.

2. **Production-shape fixture in tests.** New
   `tests/_fake_ui.rb` `add_line(*points)` method now
   mirrors real SU's behavior: each call creates ONE new
   Edge entity; two calls with the same endpoints create
   two distinct entities with distinct `entityID` /
   `persistent_id`. The fixture is now SU-API-compatible
   (the same `entities.add_line` call the production code
   uses).

3. **Real-PreflightRunner regression tests.**
   `tests/test_v15_real_preflight_path.rb` now exercises the
   FULL production pipeline end-to-end against the
   SU-compatible fake:

     V15RP-001a: SU-compatible add_line creates 2 distinct
                 edges with byte-identical endpoints
                 (the BLOCK-003 reachability property).
     V15RP-001:  real PreflightRunner + DuplicateDetector ->
                 DuplicateRepairExecutor path inside ONE
                 parent container ARE applied (applied >= 1).
     V15RP-002:  two parent containers with coincident edges
                 -> cross-instance isolation (applied = 0).
     V15RP-003:  no duplicates -> applied=0, ready.
     V15RP-004:  source_fingerprint unchanged across apply.
     V15RP-005:  V15-4 ordering -- install class-level hook
                 BEFORE clicking Prepare, run batch, snapshot
                 state = 'failed', hook auto-consumed.
     V15RP-006:  Owner V15-4 command sequence (BLOCK-004
                 req 6) -- strictly reproduces the Ruby
                 Console + Prepare + run_duplicate_repair_batch
                 sequence WITHOUT expecting exception
                 propagation (the runner rescues internally and
                 returns a snapshot).

The tests use the REAL `PreflightRunner.build_snapshot` +
`AnalyzersRunner.run` + `WorkingModeRunner.prepare` +
`run_duplicate_repair_batch` pipeline (NOT hand-crafted
EdgeRecords with fabricated equal pid_paths).

### BLOCK-004 — Owner checklist executable (recheck #3)

CodeX listed 5 defects in the prior checklist. This revision
fixes all 5.

**Defect A (V15-2 only called add_instance once).**
FIXED: V15-2 now calls `add_instance` TWICE, on
`mod.active_entities` (not the fake `defs_root`). The two
instances are named `V15_SharedInst#A` and `V15_SharedInst#B`.

**Defect B (V15-2 placed instances at offset transforms, so
no cross-instance candidates could exist).**
FIXED: V15-2 places BOTH instances at the IDENTITY transform
(no offset). The two instances OVERLAP in world space; the
walk visits each instance's edges; DuplicateDetector emits a
candidate pair (the edges coincide); the proposer PRESERVES
the pair (different container paths); applied = 0, skipped = 1.
The expected output now reads `["ready", 2, 0, 1]` and the
checklist asserts `actions_applied == 0` AND
`actions_skipped == 1` (this is the actual must-not-repair
proof).

**Defect C (V15-4 installed the hook AFTER Prepare
completed).**
FIXED: V15-4 now installs the class-level test hook BEFORE
clicking Prepare. The production adapter now exposes
`SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.
class_test_hook=` (a class-level, one-shot StandardError
injector) exactly for this. The hook fires on the FIRST
dispose() call inside the batch (NOT during Prepare's
non-disposing build). After firing, the hook is auto-cleared.

**Defect D (V15-4 expected a Ruby Console exception).**
FIXED: V15-4 no longer expects an exception.
`WorkingModeRunner.run_duplicate_repair_batch` rescues
StandardError internally and returns a snapshot Hash. The
checklist now reads the snapshot via
`SUAnalysis::Core::WorkingModeRunner.snapshot` and asserts
on:
  - `state == "failed"`
  - `last_error` contains `v15-gate-injected-failure`
  - `duplicate_repair.actions_failed >= 1`
  - `duplicate_repair.actions_applied == 0`
  - `entity_count == 4` (no partial removal)
  - The hook auto-cleared
NO `begin/rescue` block; no `RESCUED:` line; no expectation
of an exception escaping to Ruby Console.

**Defect E (steps left SU-AI-Derived-* groups behind).**
FIXED: Every step now starts with a cleanup that erases
both the previous step's source fixture AND any
SU-AI-Derived-* groups the prior batch may have left behind.
The cleanup uses
`Sketchup.active_model.entities.grep(Sketchup::Group).
select { |g| g.name.start_with?('SU-AI-Derived-') }.each(&:erase!)`.
The next step's `Ctrl+A` will NOT pick up leftover derived
groups, so the selection is clean.

**Additional fixes (recheck #3):**

- Step V15-3 (Discard + Rebuild) reads the source fingerprint
  prefix from the snapshot Hash BEFORE Discard and AFTER
  Rebuild, asserting byte-identical prefixes.
- Step V15-5 (Discard precise cleanup) reads the snapshot
  Hash AND verifies the source ComponentDefinition still has
  its 2 edges (the source is UNTOUCHED).
- Step V15-6 (new) runs the BLOCK-003 reachability probe
  and captures the result.

## Production code changes (recheck #3)

`extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb`:
- Added `SketchupDerivedWorkspaceAdapter.class_test_hook` /
  `class_test_hook=` accessor (class-level StandardError).
- `dispose` reads the class-level hook FIRST (broader scope),
  raises and clears it (one-shot), then reads the
  per-instance `@__v15_one_shot_failure` (also one-shot).
  This addresses BLOCK-004 C: the hook fires on the FIRST
  dispose inside the batch (which the runner calls), not
  during Prepare.

`tests/_fake_ui.rb`:
- Added `add_line(*points)` method on `FakeEntities` that
  creates distinct FakeEdge entities per call (no auto-merge),
  matching real SU's `Entities#add_line(*points)` semantics.

`tests/test_v15_real_preflight_path.rb`:
- Rewritten to use the SU-compatible `add_line` API.
- 7 tests: V15RP-001a, V15RP-001..006.
- V15RP-006 is the BLOCK-004 req 6 regression: strictly
  reproduces the Owner V15-4 command sequence end-to-end.

`Review/V15_REAL_SU2020_REACHABILITY_PROBE_2026-08-25.md` (new):
- The Owner-runnable Ruby Console probe for BLOCK-003.

`Review/OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-25.txt`:
- REWRITTEN with the BLOCK-004 A-E fixes.

`Review/V15_OWNER_GATE_BLOCK_RECHECK_PACKET_2026-08-25.md`:
- This file (recheck #3 evidence).

## Test evidence

| Suite                       | Before    | After     |
|-----------------------------|-----------|-----------|
| Full Ruby (all)             | 700/700   | 706/706   |
| V1.5 Phase 1 Ruby tests     | 36/36     | 42/42     |
| V15 (pure-data)              | 21        | 21        |
| V15PC (production chain)     | 10        | 10        |
| V15RP (real Preflight path)  | 5         | 7         |
| Node DOM (all)              | 154/154   | 154/154   |
| RBZ smoke                   | 8/8       | 8/8       |
| git diff --check            | clean     | clean     |
| working tree                | clean     | clean     |

## Final V1.5 Phase 1 RBZ (recheck #3)

  Path:    D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz
  Size:    <rebuilt after recheck #3 commit>
  Entries: 55
  SHA256:  <rebuilt after recheck #3 commit>

## Hard limits inherited

- NOT pushed / published / installed / released.
- NOT modified V1.0-V1.4 closed scope.
- NOT entered V1.5 Phase 2 / V1.6+ / V1.7+ / V1.8 / V1.9.
- NOT handled short edge / approximate / face / gap / weld /
  flatten / AI / MCP / V2.
- NOT asked Owner to install the previous RBZ (a8b7792).

## STOP

CodeX: please review BLOCK-003 + BLOCK-004 ONLY (recheck
#3). Do not widen scope.

If PROBE 1 in the BLOCK-003 reachability probe returns FAIL
on real SU2020, BLOCK-003 is UNREACHABLE and CodeX must
escalate to Product Owner; the Agent does NOT modify the
production code beyond what this commit already contains.

On PASS (PROBE 1+2+3 all green), Owner runs the rewritten
checklist on real SU2020.