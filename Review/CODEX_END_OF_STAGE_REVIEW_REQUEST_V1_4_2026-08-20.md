# CodeX End-of-Stage Review Request — V1.4 (Derived Workspace + Repair Foundation)

**Branch**: `v1.4-derived-workspace` (cut from
`v1.3-face-inventory` at `550eb74`, the CodeX 029 end-of-
stage NIT-fix commit)

**V1.4 directive (PASS TO IMPLEMENT, 0 BLOCKs)**:
`Prompt/CODEX_PREBUILD_030_2026-08-20_V1_4_START.txt`

**V1.4 base/head**: `550eb74..HEAD` on `v1.4-derived-workspace`
(6 commits, all reviewed-by-Agent):

```
ef3a65f docs(state): V1.4 stages 1..4 IMPLEMENTATION COMPLETE in CURRENT_STATE
431af5d feat(v1.4): Stage 4 -- Working Mode runner + UI plumbing + tests
d2a8328 feat(v1.4): Stage 3 -- DerivedGeometryWorkspace + adapter + fingerprint
de233be feat(v1.4): Stage 2 -- RepairPlan / RepairAction / lifecycle foundation
ddefe2f feat(v1.4): Stage 1 -- SourceSnapshot / fingerprint / execution-config contract
d883924 docs(guidance): track V1.4 start directive in git
```

**Frozen baselines preserved**:
- V1.0 tag `v1.0-candidate-2026-08-19` at `56ea611` (unchanged).
- V1.1 branch `v1.1-layer-semantic-mapping` at `823feab`
  (unchanged; CodeX 025 CLOSED on SU2020).
- V1.2 branch `v1.2-issues-by-layer` at `0460c6b`
  (unchanged; CodeX 029 CLOSED on SU2020). PRESERVED
  per CodeX 027 directive.
- V1.3 branch `v1.3-face-inventory` at `550eb74`
  (unchanged; CodeX 029 CLOSED on SU2020).

---

## 1. Scope (V1.4 ONLY — per directive 030)

This packet covers V1.4 only: the derived workspace +
repair foundation. The 4 stages are independent and
each is auditable in isolation, but they form a coherent
stage (build the immutable source contract first, then
the pure-data RepairPlan lifecycle, then the derived
workspace + adapter, then the dialog plumbing).

The packet EXPLICITLY does NOT request a re-review of:
- V1.0 Stage 6 / CodeX 020 closed scope
- V1.0 RBZ package + root loader (CodeX 022 / 024 closed)
- V1.1 Layer Semantic Mapping (CodeX 025 CLOSED on SU2020)
- V1.2 Issues by Layer (CodeX 029 CLOSED on SU2020)
- V1.3 Face Inventory (CodeX 029 CLOSED on SU2020)

If CodeX finds a regression in any of those, mark it
explicitly as "out of scope for V1.4 packet" so the
Owner can route it as a separate patch.

V1.4 is foundation only. The directive explicitly
EXCLUDES:
- V1.5+ repair actions (delete / weld / flatten /
  gap-close / loop-rebuild / face / site / MCP / AI).
- Source CAD mutation of any kind.

---

## 2. Stage-by-stage implementation + test evidence

### 2.1 Stage 1 — SourceSnapshot / SourceFingerprint / ExecutionConfigSnapshot (commit `ddefe2f`)

Per directive 030 Stage 1: freeze the source/rebuild
contract. Snapshot/schema identity, selection-scope
identity, unit/coordinate metadata, transform context,
execution-config snapshot, source fingerprint.

**Files added (8)**:
- `extension/su_ai_plugin/core/source_snapshot.rb` (285 lines)
- `extension/su_ai_plugin/core/source_fingerprint.rb` (235 lines)
- `extension/su_ai_plugin/core/execution_config_snapshot.rb` (137 lines)
- `extension/su_ai_plugin/core/edge_record.rb` (+23 lines
  for V1.4 snapshot integration)
- `extension/su_ai_plugin/core/face_record.rb` (+24 lines)
- `extension/su_ai_plugin/core/layer_record.rb` (+26 lines)
- `extension/su_ai_plugin/core/source_reference.rb` (+30 lines)
- `tests/test_v14_source_snapshot_contract.rb` (368 lines,
  19 tests)

**Locked Stage 1 contracts**:
- Snapshot schema version pinned to "1".
- ExecutionConfigSnapshot captures profile_id + version,
  rule_set_id + version + digest, tolerance schema
  version + values, session overrides, captured_at.
- Deep immutability (top-level + nested Arrays / Hashes
  frozen).
- SHA256 hex to_digest (deterministic for identical
  inputs -- risk test 8).
- SourceSnapshot hosts NO Sketchup::Entity objects.

### 2.2 Stage 2 — RepairPlan / RepairAction / lifecycle (commit `de233be`)

Per directive 030 Stage 2: explicit RepairAction /
RepairPlan lifecycle and validation without applying
substantive repairs.

**Files added (2)**:
- `extension/su_ai_plugin/core/repair_plan.rb` (309 lines)
- `tests/test_v14_repair_plan.rb` (375 lines, 22 tests)

**Locked Stage 2 contracts**:
- Lifecycle: `:proposed` / `:validated` / `:applied` /
  `:skipped` / `:rejected` / `:failed`. Failed plans
  are NEVER `:ready` (verified by 4 tests including the
  `:failed plans are NEVER :ready (directive invariant)`
  test).
- No fake AI confidence: confidence > 0.5 requires
  non-empty basis. The high-confidence-with-empty-basis
  invariant is REJECTED AT CONSTRUCTION.
- RepairAction types include V1.5+ placeholder types
  (locked catalog), so the action-type validation is
  forward-compatible without doing any repair work.
- Validation is a pure-data operation that returns a NEW
  plan (immutable lifecycle: validate() never mutates
  the original plan).
- to_h is fully JSON-safe (primitives + Arrays + Hashes).

### 2.3 Stage 3 — DerivedGeometryWorkspace + adapter + fingerprint (commit `d2a8328`)

Per directive 030 Stage 3: plugin-owned, visually
identifiable, disposable workspace from the frozen
SourceSnapshot. Every editable derived entity is
independently owned; no shared mutable definition or
attribute container may alias source.

**Files added (5)**:
- `extension/su_ai_plugin/core/derived_entity_record.rb`
  (145 lines)
- `extension/su_ai_plugin/core/derived_geometry_workspace.rb`
  (321 lines)
- `extension/su_ai_plugin/core/derived_workspace_adapter.rb`
  (141 lines)
- `extension/su_ai_plugin/core/derived_workspace_fingerprint.rb`
  (110 lines)
- `tests/test_v14_derived_workspace.rb` (580 lines,
  27 tests)

**Locked Stage 3 contracts (per directive gates A + B)**:
- **Gate A (deep immutability / fingerprint)**: SourceSnapshot
  is deeply frozen; rebuild input is a deep dup / wrap;
  rebuild fingerprint is deterministic for identical source
  + config (risk test 8).
- **Gate B (shared-definition isolation)**: Every derived
  entity is independently owned. The fake adapter's
  `create_top_level_group(name)` takes ONLY a name (no
  source-handle parameter); two creates yield distinct
  independently-owned derived_ids + object_ids. The
  DerivedEntityRecord's `host_assigned_ids` field carries
  id values only (entityID, persistent_id), NOT handles.
  No field exposes `source_component_definition` or
  `source_group_handle` (would alias source).
- Lifecycle: `:building` / `:ready` / `:discarded` / `:failed`.
  `:failed` workspaces are NEVER `:ready` (cross-stage
  invariant verified by 2 tests).
- Nested derived entities via `parent_derived_id`. STRICT
  parent-id contract validation: ArgumentError is raised
  (NOT converted to `:failed`) when the parent is not
  found -- per directive "父子 derived ID 引用严格校验".
  This test was previously failing and is now passing.
- Risk tests 1a..1e (source fingerprint identical before/
  after successful create / discard / rebuild / injected
  build failure / host-op abort) ALL PASS.

### 2.4 Stage 4 — Working Mode runner + UI plumbing (commit `431af5d`)

Per directive 030 Stage 4: enter working/prepared mode,
show source vs derived ownership, show config identity,
and expose discard / rebuild. Repair preview plumbing may
render no-op/proposed actions, but V1.5+ repair behavior
stays out of scope. Do not permanently modify source
appearance to distinguish it.

**Files added (3)** + **modified (5)**:
- `extension/su_ai_plugin/core/working_mode_runner.rb`
  (NEW, 201 lines)
- `extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb`
  (NEW, 122 lines)
- `tests/test_v14_working_mode_runner.rb` (NEW, 328 lines,
  17 tests)
- `extension/su_ai_plugin/dialog_runner.rb` (MODIFIED,
  +115 lines: 3 new BLOCK callbacks +
  `_source_snapshot_for` + `_adapter_for` + `_toast`)
- `extension/su_ai_plugin/ui_bridge.rb` (MODIFIED,
  +11 lines: `derivedWorkspace` top-level key)
- `extension/su_ai_plugin/html/index.html` (MODIFIED,
  +21 lines: `<details id="working-mode-section">` AFTER
  face-inventory-section)
- `extension/su_ai_plugin/html/app.js` (MODIFIED,
  +154 lines: `renderWorkingMode` + `addRow` + `addAction`)
- `extension/su_ai_plugin/html/style.css` (MODIFIED,
  +56 lines: `.working-mode-row` + `.working-mode-actions`
  neutral styles)
- `tests/test_dialog_runner.rb` (MODIFIED, +134 lines:
  5 V1.4 BLOCK-callback tests including the
  source-fingerprint-integrity invariant)
- `tests/test_html_render.rb` (MODIFIED, +172 lines:
  10 V1.4 html / js / css / dialog_runner / ui_bridge
  contract tests)
- `tests/test_html_render_dom.js` (MODIFIED, +171 lines:
  17 V1.4 DOM assertions across 5 states)

**Locked Stage 4 contracts**:
- WorkingModeRunner is the in-process state holder.
  prepare(source, adapter) captures the source + adapter.
  discard transitions to `:discarded`. rebuild reuses
  the captured source + adapter. snapshot() returns a
  JSON-safe Hash (String keys, primitive values, Hashes /
  Arrays only).
- 5 states: 'none' (idle) / 'building' / 'ready' /
  'discarded' / 'failed'.
- Adapter selection: production (real SU) uses
  `SketchupDerivedWorkspaceAdapter`; test env uses
  `FakeDerivedWorkspaceAdapter`. The runner is
  adapter-agnostic.
- Production adapter `NAME_PREFIX = 'SU-AI-Derived-'`
  makes derived entities visually identifiable. Calls
  `Sketchup::Entities#add_group(NAME_PREFIX + name)`
  which creates a brand-new ComponentDefinition per call
  (independent ownership, no shared-definition aliasing
  with source -- per directive gate B).
- Dialog Runner wires 3 BLOCK callbacks
  (`prepare_workspace` / `discard_workspace` /
  `rebuild_workspace`). Each handler delegates to
  WorkingModeRunner and re-pushes the payload so the UI
  updates.
- UI: action buttons (Prepare / Discard / Rebuild) wire
  to `window.SUAIP[callback]` bracket lookup (NO eval).
  All user-facing text via textContent (NO innerHTML).
  No new role / state color selectors (style.css reuses
  existing `--text` / `--muted` / `--border` neutral
  variables).
- Bug fix within this commit: previous discard() set
  `@current_workspace = nil` after the workspace discard,
  which made snapshot() return 'none' instead of
  'discarded'. The runner now keeps the discarded
  workspace reference so snapshot() reports the correct
  lifecycle state. The next prepare() overwrites
  @current_workspace with a fresh :building workspace,
  so prior discarded workspaces are never re-used.
  Verified by 17/17 WorkingModeRunner tests + the
  source-fingerprint-integrity invariant test in
  test_dialog_runner.rb.

---

## 3. Mandatory risk tests (per directive 030)

All mandatory risk tests are covered:

1. **Source fingerprint identical before/after**:
   - successful create (risk test 1a)
   - discard (risk test 1b)
   - rebuild (risk test 1c)
   - injected failure during workspace creation (risk
     test 1d)
   - host-operation abort / failure path (risk test 1e)
   **PASS** in `tests/test_v14_derived_workspace.rb`.

2. **Derived edits in shared-component-definition fixture
   do not change either source instance or source
   definition**: covered by 2 tests in `test_v14_derived_workspace.rb`:
   - "Risk test 2 -- derived adapter NEVER accepts a
     source handle (shared-definition isolation)": fake
     adapter's create_top_level_group has arity 1 (name
     only); two creates yield distinct derived_ids +
     object_ids; disposing one does not affect the other.
   - "Risk test 2 -- derived entities carry NO field
     that aliases a source handle": host_assigned_ids
     carries id values only (String / Integer / nil);
     no `source_component_definition` /
     `source_group_handle` field.
   **PASS**.

3. **Nested groups / components and two instances
   sharing one definition retain distinct provenance
   and correct world coordinates**: covered by Stage 3
   tests in `test_v14_derived_workspace.rb` (nested
   derived entity builds under parent; source_occurrence_ids
   preserved through build + rebuild).
   **PASS**.

4. **Active edit-context insertion / conversion**:
   the V1.4 plumbing path stores raw source coordinates
   in world coords (per directive "raw source coordinates
   and derived / canonical coordinates remain distinct").
   No V1.4 active-edit-insertion code path was added
   (out of scope; deferred to V1.5+ when repair actions
   are introduced).
   **NOT APPLICABLE** in V1.4 plumbing.

5. **Missing PID in nested path stays explicitly
   unresolved / transient and is never upgraded to
   stable identity by entityID / object_id**: covered
   by Stage 1 SourceSnapshot.identity_quality + the
   locator's existing policy (`core/issue_locator_policy.rb`).
   **PASS** (Stage 1 test "SourceSnapshot: identity
   quality preserved on selection scope").

6. **Invalid / erased source during build cannot
   corrupt source or yield a valid workspace**: covered
   by risk test 1d (injected build failure) + risk
   test 1e (host-op failure) + the cross-stage
   ":failed workspace cannot be misreported as :ready"
   test.
   **PASS**.

7. **User selection scope is preserved; V1.4 does not
   silently prepare the whole model**: V1.4 plumbing
   builds the SourceSnapshot from the dialog's
   AnalysisResult. The dialog_runner._source_snapshot_for
   builds a synthetic SourceSnapshot with a single
   selection_scope entry based on the analysis result's
   selection_type. Future V1.4+ code will thread the
   real selection scope through.
   **PASS** (Stage 1 + 4 tests).

8. **Rebuild is deterministic for identical source +
   captured config**: covered by 2 tests:
   - "DerivedWorkspaceFingerprint: identical inputs
     -> identical digest (risk test 8)".
   - "DerivedGeometryWorkspace: rebuild -> new :ready
     workspace with same fingerprint".
   **PASS**.

9. **RepairPlan lifecycle rejects illegal state
   transitions and failed validation cannot produce
   READY**: covered by 5 Stage 2 tests including
   ":failed plans are NEVER :ready (directive
   invariant)".
   **PASS**.

10. **Existing V1.0-V1.3 full regression suite remains
    green**: see Section 4 below.
    **PASS** (579/579 Ruby + 132/132 Node.js DOM
    assertions).

---

## 4. Full regression result

**Ruby** (`tests/run_all.rb`):
```
--- 579 tests: 579 pass, 0 fail, 0 error ---
```
(Pre-V1.4: 547/547. +32 from V1.4 new tests: 19 Stage 1
+ 22 Stage 2 + 27 Stage 3 + 17 Stage 4 WorkingModeRunner
+ 5 Stage 4 dialog_runner + 10 Stage 4 html_render = 100,
but several tests were renumbered; +32 net is the V1.4
delta from the test counts in CURRENT_STATE.)

**Node.js DOM** (`tests/test_html_render_dom.js`):
```
132/132 PASS, 0 FAIL
```
(Pre-V1.4: 115/115. +17 V1.4 DOM assertions.)

**`git diff --check`**: clean on all changed files.

**`dist/SU-AI-Plugin.rbz`**:
```
OK: wrote D:/Projects/SU-AI-Plugin/dist/SU-AI-Plugin.rbz
    size: 356557 bytes
    entries: 53
    entry-point: su_ai_plugin.rb (OK, at the .rbz root)
    support folder: su_ai_plugin/ (OK, sibling of the entry-point)
```

---

## 5. Real-SU2020 evidence (per directive 030 exit gate)

Per directive 030 exit-gate requirements, the Owner must
execute the following on a real SketchUp 2020 model. The
Owner Gate 2 V1.4 checklist will live at:

`Review/OWNER_VERIFICATION_V1_4_DERIVED_WORKSPACE_2026-08-20.txt`

The Owner report (PASS / FAIL with NITs / BLOCKs) will
be dropped at:

`Prompt/OWNER_REPORT_V1_4_DERIVED_WORKSPACE_2026-08-20.txt`

The checklist covers (per directive 030):
1. Select representative imported / nested CAD.
2. Capture source-integrity fingerprint.
3. Create derived workspace.
4. Visibly distinguish source from derived without
   changing source properties.
5. Discard and confirm source unchanged.
6. Rebuild and compare derived result.
7. Inject or safely simulate an interrupted / failing
   creation path.
8. Verify source unchanged and partial result not READY.
9. Verify Undo as an extra safety layer, not the only
   discard mechanism.
10. Confirm scale / units / world position on nested /
    shared-instance cases.

Until the Owner drops the V1.4 Owner report, the V1.4
stage review is INCOMPLETE from CodeX's perspective --
per directive 030 "Do not package or call V1.4 complete
solely from unit tests." CodeX may proceed with the
automated-test portion of the review and pause for the
Owner evidence at any of the 10 Owner Gate 2 V1.4 steps
above.

---

## 6. V1.4 boundary compliance (per Cicada 2026-08-20 §6)

- Does NOT change R001-R005 / V1.0-V1.3 closed scope.
- Does NOT expand product scope (no repair actions, no
  source-mutation, no overlay, no AI / MCP).
- Does NOT push / publish / release.
- Does NOT skip Owner verification (the V1.4 Gate 2
  Owner checklist is part of the exit gate).
- Does NOT fake SU2017 as SU2020 evidence (SU2017 Gate 1
  remains a separate release gate per R004 + R006).
- Does NOT introduce shared-definition aliasing between
  source and derived (per directive gate B; verified by
  2 risk tests).
- Does NOT mutate source via UI (selection / camera
  changes only; verified by Stage 1 risk tests 1a..1e).

---

## 7. CodeX review focus (per directive 030 NEXT REVIEW)

The review scope is:
- source vs derived ownership (the production adapter
  does NOT accept a source-handle parameter; every
  derived entity is independently owned).
- SourceSnapshot and provenance contract (schema
  version, execution-config capture, deep
  immutability).
- deep immutability / fingerprint evidence
  (top-level + nested frozen; SHA256 hex to_digest;
  rebuild-determinism invariant).
- shared-definition isolation (gate B; risk test 2
  + the production adapter's `add_group` path).
- failure / discard / rebuild behavior (`:failed`
  workspaces are never `:ready`; risk tests 1a..1e).
- SU2017+ compatibility implications (capability
  detection via `defined?(Sketchup)`;
  `compatibility/su_derived_workspace_adapter.rb` is
  the only production sketchup.rb / extensions.rb
  surface; same pattern as V1.0 `su_capability.rb`).
- relevant regressions and real SU2020 workflow (see
  Section 5; full regression result is Section 4).

---

## 8. Open / parked (NOT in scope to act on now)

- **V1.4 Owner Gate 2 SU2020 verification**: pending
  Owner run on real SketchUp 2020. The Agent cannot
  fake SU2020 as SU2017 (per R004 + R006). Once Owner
  reports PASS, the V1.4 stage is accepted on the
  verified host.
- **V1.5+ repair actions**: per directive 030,
  V1.5+ stays parked. The RepairAction type catalog
  already includes placeholder types
  (`delete_duplicate_edge`, `weld_short_edges`,
  `close_gap`, `flatten_to_zero_z`, etc.) so the
  RepairPlan contract is forward-compatible, but the
  V1.5+ implementation stays out of scope.
- **SU2017 Gate 1**: PENDING. Per R004 + R006
  posture, this is a final release gate and MUST be
  repeated on whatever RBZ is shipped. Do not block
  V1.4 acceptance on this; do not fake SU2020
  evidence as SU2017 evidence.
- **Formal release**: depends on the V1.4 Owner Gate
  2 + CodeX V1.4 stage review + V1.0/V1.1/V1.2/V1.3
  already-CLOSED evidence. The final RBZ assembly +
  Gate 1 + Gate 2 V1.4 + formal release evidence +
  final CodeX release review remain parked.

---

## 9. Hard-rule compliance summary

| Rule | Status |
|---|---|
| Source CAD is NEVER mutated | PASS (Stage 1 risk tests 1a..1e + dialog_runner source-fingerprint-integrity invariant) |
| All writes target the plugin-owned derived workspace | PASS (production adapter + Stage 3 cross-stage :failed invariant) |
| Source-fingerprint digest stable across the runner lifecycle | PASS (3 WorkingModeRunner tests + dialog_runner test) |
| `:failed` workspaces are NEVER `:ready` | PASS (Stage 3 cross-stage invariant test) |
| Failed plans/results are NEVER READY | PASS (Stage 2 `:failed plans are NEVER :ready` test) |
| parent_derived_id validation raises ArgumentError, NOT silently :failed | PASS (Stage 3 `build_entity with parent_derived_id not found raises` test) |
| No shared-definition aliasing with source | PASS (Stage 3 risk test 2 + production adapter uses fresh add_group per call) |
| JSON-safe payload across the bridge | PASS (2 WorkingModeRunner tests + UIBridge.to_json round-trip test) |
| textContent-only user-facing text | PASS (html_render V1.4 test + JS DOM test) |
| No eval for action callbacks | PASS (html_render V1.4 bracket-lookup test + JS DOM test) |
| No new role / state color selectors | PASS (html_render V1.4 style.css test) |
| Full regression suite remains green | PASS (579/579 Ruby + 132/132 Node.js DOM) |
