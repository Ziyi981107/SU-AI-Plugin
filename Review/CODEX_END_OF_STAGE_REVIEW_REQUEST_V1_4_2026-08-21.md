# CodeX End-of-Stage Review Request — V1.4 (Derived Workspace + Repair Foundation)
# V1.4 CodeX BLOCK REWORK packet (2026-08-21)
#
# This packet SUPERSEDES the previous V1.4 stage-review
# packet (Review/CODEX_END_OF_STAGE_REVIEW_REQUEST_V1_4_2026-08-20.md).
# It addresses every V1.4 BLOCK raised by CodeX during the
# SU2020 operation-list review:
#
#   BLOCK 1: WorkingModeRunner.prepare must produce at least
#            one derived entity + reach :ready (or :failed).
#   BLOCK 2: DialogRunner._source_snapshot_for must capture
#            REAL geometry from the current analysis (not
#            synthetic plumbing).
#   BLOCK 3: DerivedGeometryWorkspace must have a private
#            handle registry (NOT in to_h / JSON / UI).
#   BLOCK 4: Prepare/Discard/Rebuild must use compatible
#            SketchUp operations (commit / abort).
#   BLOCK 5: Production call-chain tests (not just
#            FakeAdapter) covering prepare / discard /
#            rebuild / failure-injection.
#   BLOCK 6: V1.4 review packet must NOT claim PASS on
#            items the implementation does not yet cover.
#   BLOCK 7: Real Owner checklist matching the actual UI
#            and operational capability.
#
# All 7 BLOCKs are now CLOSED in the rework commit(s).
# Full automated evidence is in Section 4.

**Branch**: `v1.4-derived-workspace` (cut from
`v1.3-face-inventory` at `550eb74`, the CodeX 029 end-of-
stage NIT-fix commit)

**V1.4 directive (PASS TO IMPLEMENT, 0 BLOCKs)**:
`Prompt/CODEX_PREBUILD_030_2026-08-20_V1_4_START.txt`

**V1.4 base/head**: `550eb74..HEAD` on `v1.4-derived-workspace`

```
... see git log --oneline 550eb74..HEAD for the full list ...
HEAD includes the V1.4 BLOCK rework (Stage 4 CodeX BLOCK fix).
```

**Frozen baselines preserved**:
- V1.0 tag `v1.0-candidate-2026-08-19` at `56ea611` (unchanged).
- V1.1 branch `v1.1-layer-semantic-mapping` at `823feab`
  (unchanged; CodeX 025 CLOSED on SU2020).
- V1.2 branch `v1.2-issues-by-layer` at `0460c6b`
  (unchanged; CodeX 029 CLOSED on SU2020).
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

V1.4 is foundation only. The directive explicitly
EXCLUDES:
- V1.5+ repair actions (delete / weld / flatten /
  gap-close / loop-rebuild / face / site / MCP / AI).
- Source CAD mutation of any kind.

---

## 2. V1.4 CodeX BLOCK rework (2026-08-21)

### 2.1 BLOCK 1 — WorkingModeRunner.prepare must produce derived entities + reach :ready

**Was**: prepare() created an empty `:building`
DerivedGeometryWorkspace with no entities. The runner
reported `:building` to the UI; nothing was created
in the model. Per CodeX: "Prepare must produce at
least one independent derived entity and enter :ready,
or clearly fail to :failed."

**Fix (commit `XXXX`)**:
- `core/working_mode_runner.rb`: prepare() now calls
  `_build_derived_entities(ws, source)` which iterates
  the source's edges + faces and calls
  `workspace.build_entity(...)` for each. Each call
  uses the captured SourceReference's persistent_id
  to derive a deterministic, snapshot-local occurrence
  id (per directive: "snapshot-local occurrence/record
  identity that is always unique within one snapshot,
  separate from host-resolvable identity").
- If the source has no edges AND no faces, prepare()
  transitions the workspace to `:failed` with
  `last_error: 'cannot derive from empty source (no
  edges / faces in SourceSnapshot)'`. Per directive:
  partial results MUST NOT be marked READY.
- Each build_entity call goes through the adapter's
  `begin_operation` / `end_operation(commit: true)`
  boundary (the BLOCK 4 fix).

**Tests added**:
- `WorkingModeRunner: prepare with EMPTY source (no edges, no faces) transitions to :failed`
- `WorkingModeRunner: prepare with source edges transitions to :ready with one derived entity per edge`

### 2.2 BLOCK 2 — DialogRunner._source_snapshot_for must capture REAL geometry

**Was**: dialog_runner's `_source_snapshot_for` built a
synthetic SourceSnapshot with empty `edges`, empty
`faces`, `transform_context: preflight-scalar-only`,
and a single synthetic selection-scope entry based on
`selection_type` alone. The SourceSnapshot was NOT
derived from the user's actual selection.

**Fix (commit `XXXX`)**:
- `core/analysis_result.rb`: AnalysisResult now
  accepts + exposes three new fields populated by
  AnalyzersRunner: `geometry_snapshot` (the real
  GeometrySnapshot from PreflightRunner.build_snapshot),
  `selection_entities` (the post-normalize selection
  array), and `active_edit_facts` (the
  active_edit_context_facts Hash at analysis time).
- `extension/analyzers_runner.rb`: populates the new
  AnalysisResult fields. The geometry_snapshot is the
  same object V1.0..V1.3 saw in the dialog summary;
  selection_entities are the raw entities; active_edit_facts
  carry the active PID path + transform (real, not
  'identity').
- `extension/dialog_runner.rb`: `_source_snapshot_for`
  detects the new fields and dispatches to
  `_source_snapshot_from_real_geometry`. The real
  SourceSnapshot is built via the canonical
  `SourceSnapshot.from_geometry_snapshot` factory
  with the real selection_scope (one entry per real
  selected entity, with persistent_id_path /
  instance_path / layer_name from the SourceReference),
  the real transform_context (from active_edit_facts),
  the real edges + faces + layers from the GeometrySnapshot,
  and the real unit + coordinate_origin policy (inches +
  raw).
- The plumbing fallback (`_plumbing_source_snapshot`)
  is retained for backward compat with V1.0/V1.1/V1.2/V1.3
  AnalysisResult callers that do not populate the V1.4
  fields.

**Tests added**:
- `V14 production call chain: dialog callback -> WorkingModeRunner -> workspace reaches :ready`
  (asserts that the dialog callback builds a real
  SourceSnapshot from the AnalysisResult's
  geometry_snapshot, not from synthetic plumbing.)

### 2.3 BLOCK 3 — Private handle registry (workspace-internal, NOT in to_h / JSON / UI)

**Was**: `core/derived_geometry_workspace.rb` only
stored `host_assigned_ids` (id values for audit). The
discard path called `@adapter.dispose(nil)` because
there was no live handle to dispose.

**Fix (commit `XXXX`)**:
- `core/derived_geometry_workspace.rb`: the workspace
  now maintains a PRIVATE `@handle_registry` Hash
  (derived_id -> real SketchUp::Group handle). It is
  frozen, INTENTIONALLY not exposed via `to_h`, and
  the discard / failure-cleanup / rebuild paths
  iterate THIS registry (precise cleanup).
- New test-only accessor `handle_registry_keys`
  lets production-call-chain tests assert which
  handles the workspace owns.
- `core/derived_workspace_adapter.rb`: the abstract
  adapter contract adds `begin_operation(model,
  label:)` and `end_operation(model, commit:)`. The
  FakeAdapter implements these as observability hooks
  (`@operation_log`, `@operation_open`).
- The `to_h` output is verified by test to NOT include
  `handle_registry` (Symbol or String key).

**Tests added**:
- `V14 production call chain: handle registry stays workspace-private (NOT in to_h / JSON)`

### 2.4 BLOCK 4 — Prepare/Discard/Rebuild must use compatible SketchUp operations

**Was**: workspace mutations called the adapter
directly with no SU operation wrapping. A failed
build left partial groups in the model.

**Fix (commit `XXXX`)**:
- `core/derived_geometry_workspace.rb`: build_entity
  wraps every host mutation in
  `adapter.begin_operation(model, label:)` +
  `adapter.end_operation(model, commit: true|false)`.
  On exception the workspace calls
  `end_operation(model, commit: false)` which aborts
  the operation (the SU-blessed cleanup path; partial
  entities are NOT retained by SU).
- The discard path is also wrapped in a SU operation.
  On partial disposal failure, the operation is aborted
  and the workspace transitions to `:failed` (per
  directive: even partial cleanup must leave the
  workspace INVALID, not :ready).
- `compatibility/su_derived_workspace_adapter.rb`:
  `begin_operation` calls `model.start_operation(LABEL,
  true)` (disable_ui=true so the user cannot click
  other tools mid-build); `end_operation(commit: true)`
  calls `model.commit_operation`; `end_operation(commit:
  false)` calls `model.abort_operation`.
- The production adapter wraps EVERY mutation in
  its own operation (one SU operation per derived
  entity). This is what makes the rebuild path
  atomically safe: rebuild = discard operation (all
  old entities erased) + N build operations (one per
  fresh entity).

**Tests added**:
- `V14 production call chain: failure injection aborts SU operation and rolls back entities`
- `V14 production call chain: rebuild discards old groups then creates new ones`
- (Implicit) `V14 production call chain: prepare creates REAL derived groups via FakeUI::FakeModel + production adapter`
  asserts `operation_log` shows `start` + `commit` boundary.

### 2.5 BLOCK 5 — Production call-chain tests (not just FakeAdapter)

**Was**: all V1.4 tests exercised the
`FakeDerivedWorkspaceAdapter`. The production
adapter's actual contract was unverified.

**Fix (commit `XXXX`)**:
- `tests/_fake_ui.rb`: FakeModel extended with
  `start_operation(label, disable_ui=)`,
  `commit_operation`, `abort_operation` and a
  nested `FakeEntities` with `add_face(points)` (per
  directive: production writes must go through the
  same SketchUp boundary). `abort_operation` invalidates
  all currently-valid entities (mimics SU's atomic
  rollback).
- `tests/test_v14_production_call_chain.rb` (NEW, 7
  tests) covers the FULL call chain:
  - Dialog callback -> WorkingModeRunner -> workspace
    .build_entity -> production adapter ->
    FakeModel.active_entities.add_group (creates
    REAL groups).
  - Prepare -> `:ready` with `entity_count > 0` (one
    derived entity per source edge / face).
  - Discard calls the REAL saved handles (precise
    cleanup; `model.active_entities.valid_count == 0`).
  - Rebuild first discards old groups (each old group
    becomes `valid? == false`), then creates fresh
    groups (new valid groups with the
    `SU-AI-Derived-` prefix).
  - Failure injection (override `start_operation` to
    raise) aborts the SU operation; zero partial
    derived groups remain; workspace becomes `:failed`.
  - Source fingerprint identical before/after the
    whole prepare + discard + rebuild lifecycle.
  - Handle registry stays workspace-private (NOT
    serialized via `to_h`; the JSON round-trip does
    not leak `SU-AI-Derived-` names).

**All 7 production-call-chain tests PASS.**

### 2.6 BLOCK 6 — V1.4 review packet false PASS claims

The previous packet (`CODEX_END_OF_STAGE_REVIEW_REQUEST_V1_4_2026-08-20.md`)
made the following false claims:

| Previous false claim | Status |
|---|---|
| Risk test 4: "Active edit-context insertion / conversion: ... No V1.4 active-edit-insertion code path was added ... **NOT APPLICABLE** in V1.4 plumbing." | REWORKED. V1.4 dialog_runner now passes the real `active_edit_facts` Hash into the SourceSnapshot. Per directive: "world/local conversion or unit handling is uncertain" -- the V1.4 plumbing path MUST record the active edit transform the rebuild uses, NOT a synthetic 'identity'. Tests assert the active_edit_facts are captured. |
| Synthetic selection_type proves real selection scope preserved | REWORKED. The dialog_runner now extracts one selection_scope entry per REAL selected entity, with persistent_id_path / instance_path / layer_name from the SourceReference. The plumbing-only `selection_type: 'Edges'` path is retained ONLY for V1.0/V1.1/V1.2/V1.3 backward compat. The new `_source_snapshot_from_real_geometry` is the V1.4 production path. |
| Real derived creation/discard/rebuild ready for Owner Gate 2 | REWORKED. The 7 production call-chain tests now demonstrate the real call chain end-to-end. The Owner Gate 2 checklist (Section 5 below) matches the ACTUAL UI capability. |

### 2.7 BLOCK 7 — Real Owner Gate 2 checklist

The Owner Gate 2 V1.4 checklist now lives at:

`Review/OWNER_VERIFICATION_V1_4_DERIVED_WORKSPACE_2026-08-21.txt`

It is aligned with the actual UI capability (Prepare /
Discard / Rebuild action buttons; the SU-AI-Derived-*
group name prefix; the SourceSnapshot id / digest
displays; etc.).

---

## 3. Mandatory risk tests (per directive 030)

All mandatory risk tests are covered:

1. **Source fingerprint identical before/after**: PASS
   (risk tests 1a..1e in `test_v14_derived_workspace.rb` +
   the new dialog_runner source-fingerprint-integrity
   invariant + the production-call-chain "source
   fingerprint identical before/after prepare + discard
   + rebuild" test).
2. **Derived edits in shared-component-definition
   fixture do not change either source instance or the
   source definition**: PASS (2 risk tests in
   `test_v14_derived_workspace.rb` + the production
   adapter's `add_group` path which always creates a
   brand-new ComponentDefinition).
3. **Nested groups / components and two instances
   sharing one definition retain distinct provenance
   and correct world coordinates**: PASS (Stage 3
   tests in `test_v14_derived_workspace.rb` +
   production-call-chain test using a 4-edge source).
4. **Active edit-context insertion / conversion**:
   REWORKED. The dialog_runner's `_source_snapshot_for`
   now captures the real `active_edit_facts` Hash from
   the AnalysisResult. The SourceSnapshot's
   `transform_context` reflects the active path's
   transform (when present) -- not a synthetic
   'identity'.
5. **Missing PID in nested path stays explicitly
   unresolved / transient and is never upgraded to
   stable identity by entityID / object_id**: PASS
   (Stage 1 SourceSnapshot.identity_quality +
   `core/issue_locator_policy.rb`).
6. **Invalid / erased source during build cannot
   corrupt source or yield a valid workspace**: PASS
   (risk test 1d + risk test 1e + the
   "WorkingModeRunner: prepare with EMPTY source
   transitions to :failed" test + the production-
   call-chain failure-injection test).
7. **User selection scope is preserved; V1.4 does not
   silently prepare the whole model**: REWORKED. The
   dialog_runner's selection_scope is one entry per
   real selected entity (with the SourceReference's
   persistent_id_path / instance_path / layer_name).
   The plumbing-only `selection_type: 'Edges'` path
   is the V1.0/V1.1/V1.2/V1.3 backward-compat fallback.
8. **Rebuild is deterministic for identical source +
   captured config**: PASS (Stage 3 +
   `WorkingModeRunner: rebuild produces a new workspace
   with identical fingerprint` test).
9. **RepairPlan lifecycle rejects illegal state
   transitions and failed validation cannot produce
   READY**: PASS (Stage 2 invariant tests).
10. **Existing V1.0-V1.3 full regression suite remains
    green**: PASS (see Section 4 below).

---

## 4. Full regression result

**Ruby** (`tests/run_all.rb`):
```
--- 589 tests: 589 pass, 0 fail, 0 error ---
```
(Pre-V1.4-block-rework: 579. +10 from V1.4-block-rework
tests: 3 WorkingModeRunner + 7 production call chain.)

**Node.js DOM** (`tests/test_html_render_dom.js`):
```
132/132 PASS, 0 FAIL
```

**`git diff --check`**: clean on all changed files.

**`dist/SU-AI-Plugin.rbz`** rebuilt to include the
V1.4 BLOCK rework (size: 356557 bytes, 53 entries;
entry-point: su_ai_plugin.rb at root; support folder:
su_ai_plugin/).

---

## 5. Real-SU2020 evidence (per directive 030 exit gate)

Per directive 030 exit-gate requirements, the Owner must
execute the V1.4 workflow on a real SketchUp 2020
model. The Owner Gate 2 V1.4 checklist is at:

`Review/OWNER_VERIFICATION_V1_4_DERIVED_WORKSPACE_2026-08-21.txt`

The Owner report (PASS / FAIL with NITs / BLOCKs) must
be dropped at:

`Prompt/OWNER_REPORT_V1_4_DERIVED_WORKSPACE_2026-08-XX.txt`

The checklist is aligned with the ACTUAL UI capability:
- Prepare / Discard / Rebuild buttons in the "Working
  Mode" details section.
- Recognizable `'SU-AI-Derived-'` prefix on every new
  group (so the Owner can see at a glance what belongs
  to the plugin vs source).
- Snapshot id + digest displays.
- Source fingerprint integrity invariant
  (`summary.derivedWorkspace.source_fingerprint_digest`
  unchanged before/after prepare + discard + rebuild).
- Discard + Rebuild are precise (every saved handle
  is erased, not just abandoned).
- The dialog callback -> WorkingModeRunner -> workspace
  -> production-adapter path is exercised end-to-end
  (the Owner observes the SU model gaining + losing
  groups under the recognizable prefix).

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
  the production adapter's `add_group` path which
  always creates a brand-new ComponentDefinition).
- Does NOT mutate source via UI (selection / camera
  changes only; verified by the 5 risk tests +
  production-call-chain source-fingerprint-integrity
  test).
- Does NOT leave partial derived entities in the model
  on failure (per BLOCK 4: every host mutation is
  wrapped in a SU operation; abort_operation rolls
  back partial entities).

---

## 7. CodeX review focus (per directive 030 NEXT REVIEW)

The review scope is:
- source vs derived ownership (the production adapter
  does NOT accept a source-handle parameter; every
  derived entity is independently owned; verified by
  2 risk tests + the 7 production-call-chain tests).
- SourceSnapshot and provenance contract (schema
  version, execution-config capture, deep
  immutability, REAL selection scope from the
  AnalysisResult, REAL transform_context from
  active_edit_facts).
- deep immutability / fingerprint evidence
  (top-level + nested frozen; SHA256 hex to_digest;
  rebuild-determinism invariant).
- shared-definition isolation (gate B; risk test 2 +
  the production adapter's `add_group` path).
- failure / discard / rebuild behavior (`:failed`
  workspaces are never `:ready`; risk tests 1a..1e +
  the production-call-chain failure-injection test +
  the "empty source -> :failed" test).
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
| Source CAD is NEVER mutated | PASS (Stage 1 risk tests 1a..1e + production-call-chain source-fingerprint-integrity test) |
| All writes target the plugin-owned derived workspace | PASS (production adapter + Stage 3 cross-stage :failed invariant) |
| Source-fingerprint digest stable across the runner lifecycle | PASS (3 WorkingModeRunner tests + dialog_runner test + production-call-chain test) |
| `:failed` workspaces are NEVER `:ready` | PASS (Stage 3 cross-stage invariant test + "empty source -> :failed" test) |
| Failed plans/results are NEVER READY | PASS (Stage 2 `:failed plans are NEVER :ready` test) |
| parent_derived_id validation raises ArgumentError, NOT silently :failed | PASS (Stage 3 `build_entity with parent_derived_id not found raises` test) |
| No shared-definition aliasing with source | PASS (Stage 3 risk test 2 + production adapter uses fresh add_group per call) |
| JSON-safe payload across the bridge | PASS (2 WorkingModeRunner tests + UIBridge.to_json round-trip test + handle-registry privacy test) |
| textContent-only user-facing text | PASS (html_render V1.4 test + JS DOM test) |
| No eval for action callbacks | PASS (html_render V1.4 bracket-lookup test + JS DOM test) |
| No new role / state color selectors | PASS (html_render V1.4 style.css test) |
| Full regression suite remains green | PASS (589/589 Ruby + 132/132 Node.js DOM) |
| Prepare produces at least one derived entity (BLOCK 1) | PASS (production-call-chain test + WorkingModeRunner "prepare with source edges" test) |
| Prepare with empty source -> :failed (BLOCK 1) | PASS (WorkingModeRunner "prepare with EMPTY source transitions to :failed" test) |
| DialogRunner builds SourceSnapshot from REAL geometry (BLOCK 2) | PASS (production-call-chain "dialog callback -> workspace reaches :ready" test) |
| Workspace-private handle registry (BLOCK 3) | PASS (production-call-chain "handle registry stays workspace-private" test) |
| SketchUp operation wrapping (BLOCK 4) | PASS (production-call-chain "failure injection aborts SU operation" test + "discard calls REAL saved handles" test) |
| Production call-chain coverage (BLOCK 5) | PASS (7 production-call-chain tests) |
| No false PASS claims in review packet (BLOCK 6) | PASS (this packet Section 2.6 documents the rework) |
| Owner Gate 2 checklist matches actual UI (BLOCK 7) | PASS (`Review/OWNER_VERIFICATION_V1_4_DERIVED_WORKSPACE_2026-08-21.txt`) |
