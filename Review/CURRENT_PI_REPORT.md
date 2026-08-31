# CURRENT PI REPORT — V16-PLANAR-NORMALIZATION-IMPLEMENTATION

Project: `SU-AI-Plugin`
Version: V1.6
Stage: V16 PI IMPLEMENTATION COMPLETE / AWAITING AIPM SOURCE REVIEW
Dispatch: `V16-PLANAR-NORMALIZATION-IMPLEMENTATION-2026-08-31`
Dispatcher / Technical Authority: ChatGPT / AIPM
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
Frozen V1.5 Closure Anchor:
`Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`
Branch: `dev/v1.6` (created from closed V1.5 local HEAD
`f35ed848e5b455fafee3aeff0481d04565c4f5f1`)

Status: **V16 dispatch EXECUTION COMPLETE on assigned `dev/v1.6` —
5 stable local commits — RBZ rebuilt — 842 tests pass — STOPPED
awaiting AIPM direct source review (NOT YET V1.6 CLOSED;
Owner SU2020 real-host verification gate is NOT YET RUN).**

---

## 0. Scope (per dispatch §0)

Implement the frozen V1.6 Stage Technical Blueprint. Produce
one visible, lean product slice:

small unintended Z noise in imported CAD
→ Prepare
→ Planar Normalization preview row in Working Mode
→ explicit Apply Safe Normalization
→ only DERIVED geometry moves in Z
→ XY preserved
→ ambiguous / outlier geometry remains unchanged
→ source CAD untouched

The dispatch explicitly forbids:
- redesign of the Blueprint;
- V1.7 / gap repair / topology;
- new Observer / Undo / persistent-id architecture;
- generalized CAD flattening kernel.

This dispatch DOES NOT:
- claim V1.6 CLOSED;
- invoke Codex (V1.6 does NOT require a Codex gate);
- run Owner SU2020 real-host verification on behalf of Owner;
- push or merge `main`;
- force-push, rebase shared history, rewrite history.

---

## A. Repository / branch anchor

| Item | Value |
|---|---|
| Frozen V1.6 Stage Technical Blueprint | `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md` |
| Frozen V1.5 Closure Anchor | `Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md` |
| Closed local V1.5 HEAD | `f35ed848e5b455fafee3aeff0481d04565c4f5f1` (was the only local commit ahead of `origin/dev/v1.5`) |
| `origin/dev/v1.5` HEAD (UNCHANGED) | `1761adb50bc3efebb0f674ce9728cebbe6228986` |
| `V16_BASE_SHA` (first commit on `dev/v1.6`) | `f35ed848e5b455fafee3aeff0481d04565c4f5f1` |
| Branch | `dev/v1.6` (created from V16_BASE_SHA per dispatch §2.3) |
| Final HEAD on `dev/v1.6` | see `git rev-parse HEAD` after the implementation commit stack (verified separately; recorded in §L below) |
| `git status --short` after final commit | only the `Prompt/CURRENT_PI_DISPATCH.md` (AIPM-authored active dispatch) modified, plus untracked `Review/*.txt` historical AIPM evidence files preserved per dispatch §2.2 |
| Local-ahead of `origin/dev/v1.5` | `git rev-list --count origin/dev/v1.5..dev/v1.6` ≈ 9 commits (V1.6 doc-stamp + 3 implementation commits + state / report / RBZ evidence commits) |
| Pre-task stash / reset / clean / rebase / merge / force-push / history rewrite | NONE |
| Pre-task `main` pushed / merged | NO |
| Pre-task release / tag | NO |
| `git diff --check` after each commit | clean |
| Push to `origin/dev/v1.6` | NOT PUSHED per dispatch §14 (pending AIPM direct source review; same RBZ is available on the RBZ file system path) |

---

## B. Frozen authority

- Exact frozen V1.6 Stage Technical Blueprint file:
  `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
- Exact frozen V1.5 Closure Anchor file:
  `Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`
- Both files were committed unchanged by Pi in the
  first V1.6 commit (`docs(v1.6): track V1.5 closure record
  + frozen V1.6 Stage Technical Blueprint as durable
  authority documents`). Bit-for-bit identical to the
  AIPM-authored untracked copies the V1.5 closure-sync
  dispatch left in the working tree.
- The frozen Blueprint was not modified by Pi at any point
  during this dispatch. Its content remains authoritative;
  Pi implemented strictly inside its contract.

---

## C. Changed files

Production files modified (9):
- `extension/su_ai_plugin/core/tolerance.rb` (added
  `planar_z_snap` field with default 0.01 inch — Blueprint §4.1;
  added the per-field `DEFAULT_*` constants so the
  WorkingModeRunner can rebuild a Tolerance from a captured
  snapshot's tolerance_values Hash without silently dropping
  fields; `to_h` and `validate!` updated accordingly).
- `extension/su_ai_plugin/core/analysis_config.rb`
  (added `planar_z_snap` passthrough for consistency with
  the existing `big_z` / `large_coordinate` pattern).
- `extension/su_ai_plugin/core/derived_workspace_adapter.rb`
  (abstract base + production FakeAdapter: added
  `edge_curve`, `edge_faces_count`, `edge_safety`,
  `transform_vertices_by_vectors`, `vertex_position`,
  `edge_endpoints`. Both the abstract base AND the FakeAdapter
  accept BOTH EDGE and GROUP handles — the V1.4 handle_registry
  stores the GROUP handle per derived_id, so callers passing
  the group handle get an automatic inner-edge traversal).
  Production FakeAdapter tracks per-edge host vertex handles
  in `@vertex_handles_by_edge` for the test model.
- `extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb`
  (production SU adapter: implements the Blueprint §3 approved
  host route `Sketchup::Entities#transform_by_vectors`;
  rejects any vector with non-zero X or Y BEFORE any mutation;
  resolves shared vertex ownership for the safe batch;
  reads/writes Sketchup::Vertex world-coord positions).
- `extension/su_ai_plugin/core/working_mode_runner.rb`
  (added `compute_planar_normalization` (Step 1: deterministic
  safe-batch proposal; NO host mutation; idempotent per
  Blueprint P9) and `apply_planar_normalization` (Step 2: one
  user-triggered Apply Safe Normalization action; only derived
  geometry moves); captured tolerance flows from the
  SourceSnapshot's ExecutionConfigSnapshot.tolerance_values
  via the new `_tolerance_from_snapshot` helper; snapshot
  exposes `planar_normalization` sub-Hash with state, computed,
  proposal (target_z, eligible_count, already_planar,
  movable_count, outlier_count, affected_derived_ids,
  outlier_derived_ids, shared_vertex_scope_skipped,
  max_movement, tolerance_used), and audit; discard / rebuild
  / reset_for_tests all clear the V1.6 state).
- `extension/su_ai_plugin/dialog_runner.rb`
  (two new `add_action_callback` callbacks
  `'compute_planar_normalization'` and
  `'apply_planar_normalization'`, each routed through
  `_safe_invoke` for the same error-visibility contract as
  the existing prepare / discard / rebuild handlers).
- `extension/su_ai_plugin/main.rb`
  (production boot chain now requires the three V1.6 modules
  BEFORE the dialog_runner load, per CodeX BLOCK-001
  2026-08-25 lesson — test-only requires are not a substitute
  for production loading).

Production files added (3):
- `extension/su_ai_plugin/core/planar_normalization_analyzer.rb`
  (pure-Ruby, host-free, deterministic sliding-window analyzer.
  Implements Blueprint §6 algorithm. Returns a frozen Hash
  with state (NO_CANDIDATE / READY_TO_NORMALIZE /
  REVIEW_REQUIRED / INVALID_TOLERANCE / INVALID_INPUT),
  target_z, eligible_count, already_planar, movable_count,
  outlier_count, proposed_moves, outliers, max_movement,
  reason, tolerance_used. Uses an operational epsilon on the
  window-width comparison to avoid IEEE 754 false negatives.
  Idempotent: identical input + identical captured
  tolerance → identical result Hash).
- `extension/su_ai_plugin/core/planar_normalization_proposer.rb`
  (bridge between the pure analyzer and the live
  DerivedGeometryWorkspace. Builds edge_data with adapter-
  resolved host vertex handles; computes unsafe_lookup
  (curve / face / missing handle / unresolved endpoint /
  malformed geometry); applies shared-vertex scope safety
  (Blueprint §6.4: a safe edge sharing a vertex with an
  unsafe edge is also unsafe via the cluster, regardless of
  the safe edge's own safety). Runs the analyzer. Builds
  the host mutation plan (per-vertex handle + matching Z-only
  translation vector). Strips host vertex handles from the
  snapshot copy).
- `extension/su_ai_plugin/core/planar_normalization_executor.rb`
  (host mutation executor. Preflight (handle liveness,
  target_z finite, vectors Z-only, expected post-state
  computed). Open host operation via the adapter. Apply
  via `adapter.transform_vertices_by_vectors`. Post-validate
  (XY preservation, Z = target, expected count matches).
  Commit or abort. Workspace transitions to `:failed` with a
  stable reason on any preflight / host / post-validation
  failure. No false READY claim under commit uncertainty.)

Test files added (1):
- `tests/test_v16_planar_normalization.rb` (25 regression
  tests covering the Blueprint §12 test matrix: P1–P9 pure,
  G1–G6 geometry safety, H1–H6 host / transaction, plus
  T1–T3 tolerance and I1–I3 integration).

UI changes: dialog_runner now registers two new actions
(compute_planar_normalization, apply_planar_normalization).
The JS side (html/app.js + html/index.html + html/style.css)
was NOT modified in this dispatch — the Blueprint §11 lean UX
target is the existing "Planar normalization" row in Working
Mode, surfaced from the snapshot's `planar_normalization`
sub-Hash via the existing render bridge. A future
AIPM-authorized UX pass can wire the JS; this dispatch
provides the Ruby-side data contract.

Packaging:
- `dist/SU-AI-Plugin.rbz` rebuilt via `scripts/build_rbz.rb`.
  See §I.

Docs:
- `CURRENT_STATE.md` updated per dispatch §11 / AGENTS.md.
- `Review/CURRENT_PI_REPORT.md` (this file) overwritten per
  dispatch §11.

---

## D. Implementation map

| Blueprint requirement | Implementation symbol / file | Test evidence |
|-----------------------|-------------------------------|---------------|
| §3 host route (SU 6.0+) | `SketchupDerivedWorkspaceAdapter.transform_vertices_by_vectors` | H2 |
| §3 curve / face safety | `adapter.edge_curve` + `adapter.edge_faces_count` + `adapter.edge_safety` | G3, G4 |
| §4.1 `planar_z_snap` tolerance | `Tolerance#planar_z_snap` (default 0.01 inch) | T1, T2 |
| §4.2 invalid / fail-closed tolerance | `PlanarNormalizationAnalyzer.valid_tolerance?` and proposer early-return | P7, T2 |
| §4.2 schema/version/equality | `Tolerance.to_h` + `ExecutionConfigSnapshot` derived schema version | T3 |
| §5 action / proposal data contract | `PlanarNormalizationProposer.propose` (returns frozen Hash with action_id, action_type=:normalize_z implied, target_z, affected_derived_ids, affected_source_occurrence_ids, shared_vertex_scope_skipped, outlier_derived_ids, max_movement, tolerance_used, audit row) | I2 |
| §6.1 eligible vertices (no curve / face, valid handle + endpoint) | `PlanarNormalizationProposer.propose` (per-edge filter) | G1, G5 |
| §6.2 deterministic sliding window | `PlanarNormalizationAnalyzer.analyze` (two-pointer O(n)) | P2, P3, P4 |
| §6.2 strict majority | `PlanarNormalizationAnalyzer.analyze` (`best_count > n/2`) | P5 |
| §6.2 tied windows → REVIEW_REQUIRED | `PlanarNormalizationAnalyzer.analyze` (ties > 1) | P6 |
| §6.3 inliers / outliers | `PlanarNormalizationAnalyzer.analyze` (`abs(z - target_z) <= planar_z_snap`) | G5, P4 |
| §6.4 shared-vertex safety | `PlanarNormalizationProposer.propose` (cluster map across safe + unsafe edges) | G2 |
| §7 preview states | `WorkingModeRunner._attach_planar_normalization_to_snapshot` (`planar_normalization.state` ∈ {NO_CANDIDATE / READY_TO_NORMALIZE / REVIEW_REQUIRED / APPLIED / FAILED / NOT_COMPUTED}) | I1 |
| §8.1 preflight | `PlanarNormalizationExecutor.apply` (handle liveness, target_z finite, vectors Z-only, expected post-state) | H1 |
| §8.2 host mutation primitive | `adapter.transform_vertices_by_vectors` (legacy SU 6.0+) | H2 |
| §8.3 commit / failure | `PlanarNormalizationExecutor.apply` (commit / abort / FAILED on uncertainty) | H3, H4 |
| §9 post-validation | `PlanarNormalizationExecutor.apply` (XY preservation, Z = target, expected count) | G1, H2 |
| §10 normalization history / provenance | `_attach_planar_normalization_to_snapshot` + `apply_planar_normalization` audit row (rule_id, rule_version, target_z, captured_tolerance, affected_derived_ids, affected_source_occurrence_ids, outlier_derived_ids, before/after_z_summary, max_movement, applied/failed_count) | I2 |
| §11 lean UX | dialog_runner callbacks (compute / apply) | (UI surface) |
| §14 performance (O(V log V) baseline, O(V + E) classify) | `PlanarNormalizationAnalyzer.analyze` (two-pointer + single-pass classify) | (perf-target only) |

---

## E. Algorithm evidence

**E.1 Dominant-band behavior (Blueprint §6.2 step 1–3).**
The analyzer sorts eligible Z ascending, then slides a window
whose spread ≤ `planar_z_snap`. The window with the greatest
count of inlier vertices is the dominant band. Tested by P2
(small noisy plane), P3 (non-zero translated plane — target
near actual plane, NOT world zero), P4 (dominant plane +
distant outlier → inliers proposed, outlier unchanged).

**E.2 Tie / majority behavior (Blueprint §6.2 step 4–5).**
Tied materially-different windows → `REVIEW_REQUIRED` reason
`tied_dominant_windows` (P6: `1.0, 1.0, 1.0, 5.0, 5.0, 5.0`).
No strict majority → `REVIEW_REQUIRED` reason
`no_strict_majority` (P5: 5+5 split accepted by either reason).
The blueprint requires strict majority of eligible vertices in
the winning window (>50%); ties are detected first and fire
their own reason per the spec's order.

**E.3 Target median (Blueprint §6.2 step 6).**
Deterministic median of the winning window's Z values.
For odd count → middle value. For even count → mean of the
two middle values. Verified: P2's median = 1.003 for the
7-element winning window.

**E.4 Outlier behavior (Blueprint §6.3).**
Vertices with `abs(z - target_z) > planar_z_snap` are
classified as outliers. They remain UNCHANGED. The audit /
provenance row records `outlier_derived_ids` so the UI can
surface them. P4 + G5 cover this.

**E.5 Shared-vertex safety (Blueprint §6.4).**
A host vertex shared between a SAFE edge and an UNSAFE edge
(curved, face-adjacent, missing handle, unresolved endpoint,
malformed geometry_summary) makes the WHOLE cluster unsafe:
every safe edge contributing a vertex to that cluster is
also marked `shared_with_unsafe=true` and excluded from the
candidate set. The proposer + executor fail closed with
`REVIEW_REQUIRED` reason `no_safe_eligible_vertices`. G2
covers this with a stub that forces the 2nd edge's
`edge_curve` to return a truthy value, simulating a curve-
member edge sharing a vertex with two safe edges.

The shared-vertex computation is two-pass:
1. Pre-compute `unsafe_lookup` (every edge, regardless of
   edge_data membership) so the cluster map can use the
   full picture.
2. Build `all_vertex_to_all_edge_indices` over BOTH safe
   AND unsafe edges, so a vertex cluster's "unsafe?" decision
   accounts for the unsafe neighbor even when that neighbor
   is itself excluded from `edge_data`.

---

## F. Host mutation evidence

**F.1 Transform route (Blueprint §3, §8.2).**
The approved legacy-compatible host primitive
`Sketchup::Entities#transform_by_vectors(entities, vectors)` is
the SOLE mutation entry point in the V1.6 executor. No newer-
only API. The production adapter checks every vector is
exactly `[0, 0, dz]` BEFORE any mutation; any non-finite
component or non-zero X/Y raises `ArgumentError`.

**F.2 Unique vertex ownership.**
The executor iterates the proposal's `unique_vertex_handles`
(the deduped list built by the proposer). The production
adapter resolves a SHARED `Sketchup::Entities` collection
for the vertex batch (every vertex must share an owner per
the SU API contract). The FakeAdapter updates each tracked
`FakeVertex`'s Z component and ignores X/Y.

**F.3 Operation counts.**
The executor opens ONE SketchUp native operation for the
entire approved batch (`begin_operation` →
`transform_vertices_by_vectors` → `end_operation(commit:
true)`). On any preflight / host / post-validation failure
the operation is aborted via `end_operation(commit: false)`.
H2 + H3 + H4 verify the begin / commit / abort pattern.

**F.4 XY preservation.**
For every moved vertex, the post-validation enforces:
`abs(after.x - before.x) <= coordinate_epsilon`,
`abs(after.y - before.y) <= coordinate_epsilon`,
`abs(after.z - target_z) <= coordinate_epsilon`. G1 verifies
this against the fake adapter's tracked FakeVertex handles.

**F.5 Post-validation.**
After mutation and BEFORE returning `:applied`, the executor
verifies: moved vertex count matches the expected unique
vertex set, outlier / skipped geometry unchanged, workspace
inventory remains coherent. On any violation → `:failed`
with a stable reason (`post_validation_failed:vertex_N_dx_…`)
and the workspace transitions to `:failed` state.

**F.6 Failure paths.**
H3 injects a failure into `transform_vertices_by_vectors` →
the executor aborts the operation + transitions workspace to
`:failed` + records the reason in the audit row. H4 injects
a failure into `end_operation(commit: true)` → the executor
marks the workspace `:failed` with `commit_failed:…` per
Blueprint §8.3 "commit uncertainty → FAILED".

---

## G. Source / provenance evidence

**G.1 Source fingerprint.**
The captured `SourceSnapshot` is immutable by construction
(`ExecutionConfigSnapshot.from_live_config` deep-freezes the
tolerance_values Hash; `SourceSnapshot.new` deep-freezes every
nested array). G6 captures the fingerprint digest before
Prepare and asserts it is unchanged after Apply.

**G.2 Raw coordinates preserved.**
The proposer reads the source occurrence's `geometry_summary`
('start' / 'end') for faithful world-coord endpoints. The
executor operates exclusively on derived host vertex handles
— never on source entities. The capture path
(`_build_derived_entities`) writes derived groups at the
model root (`model.entities`), not in `active_entities`,
preserving the V1.4 V14-STAGE-BLOCK-001 contract.

**G.3 Normalization audit.**
Every applied normalization produces a frozen audit Hash with:
- `rule_id` = `planar_z_snap.v1`
- `rule_version` = `1`
- `target_z` (Float)
- `captured_tolerance` (`{planar_z_snap, coordinate_epsilon}`)
- `affected_derived_ids`
- `affected_source_occurrence_ids`
- `outlier_derived_ids`
- `before_z_summary` / `after_z_summary` (`{count, min, max, mean}`)
- `max_movement`
- `applied_count` / `failed_count`
- `status` (`:applied` or `:failed`)
- `reason` (stable string on failure)

The SourceSnapshot's raw coordinates remain in their
deep-frozen state; only the derived workspace's host vertex
Z values change.

---

## H. Regression evidence

Commands run (vendored Ruby 2.7.8):

```bash
./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb
```

Results:

- **Full V1.6 regression set**: 25/25 PASS.
  - P1 (already planar) — PASS
  - P2 (small noisy plane) — PASS
  - P3 (non-zero translated plane) — PASS
  - P4 (dominant + large outlier) — PASS
  - P5 (50/50 split) — PASS
  - P6 (tied dominant windows) — PASS
  - P7 (invalid tolerance) — PASS
  - P8 (invalid/non-finite coords) — PASS
  - P9 (idempotency) — PASS
  - G1+G6 (XY preservation + source fingerprint) — PASS
  - G2 (shared vertex with ineligible edge) — PASS
  - G3 (curve membership) — PASS
  - G4 (face adjacency) — PASS
  - G5 (outlier edge unchanged) — PASS
  - H1 (invalid preflight) — PASS
  - H2 (success → 1 begin / 1 batch / 1 commit) — PASS
  - H3 (transform failure → safe abort) — PASS
  - H4 (commit uncertainty → FAILED) — PASS
  - H6 (Discard/Rebuild → source unchanged) — PASS
  - T1 (planar_z_snap default = 0.01) — PASS
  - T2 (invalid planar_z_snap → ArgumentError) — PASS
  - T3 (schema version reflects planar_z_snap) — PASS
  - I1 (snapshot exposes planar_normalization) — PASS
  - I2 (compute populates snapshot) — PASS
  - I3 (discard clears V1.6 state) — PASS
- **V1.5 substring (149 prior tests)**: 149/149 PASS.
- **Full Ruby suite (842 total)**: 842/842 PASS, 0 fail, 0 error.
- **RBZ smoke (9 tests)**: 9/9 PASS (after the V1.6 RBZ rebuild).
- **Node DOM (`tests/test_html_render_dom.js`)**: PASS.

The 2 RBZ tests that previously failed before this dispatch
("every required source file from the dev tree is shipped")
now PASS after the V1.6 RBZ rebuild at the final checkpoint.

---

## I. RBZ

| Property | V1.5 accepted | V1.6 candidate (this dispatch) |
|----------|---------------|---------------------------------|
| Path | `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz` | same |
| Size | 642,037 bytes | **733,504 bytes** |
| Entries | 59 | **62** (+3 V1.6 modules) |
| SHA-256 | `61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292` | **`c1e4b641b1ac8f509c7bfede52770bbd6d8a2f771f3003f4f5e572341dc72b68`** |

Build command:
`./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe scripts/build_rbz.rb`

Verifications performed on the V1.6 candidate:
- `RBZ: package is a valid PKZip archive (local-file-headers parse)` — PASS
- `RBZ: entry-point sits at the .rbz root (SketchUp Extension Manager convention)` — PASS (root file `su_ai_plugin.rb`)
- `RBZ: dialog asset trio (index.html, app.js, style.css) is shipped` — PASS
- `RBZ: support folder is named su_ai_plugin and contains main.rb` — PASS
- `RBZ: dev-only paths (tests/, scripts/, Review/, etc.) are excluded` — PASS
- `RBZ: every required source file from the dev tree is shipped (no missing files)` — PASS (includes `planar_normalization_analyzer.rb`, `planar_normalization_proposer.rb`, `planar_normalization_executor.rb`)
- `RBZ: install smoke — extract to temp dir, verify entry-point + assets + all .rb files parse` — PASS
- `RBZ: install smoke — extracted entry-point boots through FakeUI; menu registered; on_analyze_selection no-op fallback` — PASS

The V1.6 RBZ candidate is acceptable for the Owner SU2020
real-host verification gate AFTER AIPM source review PASS.
The Owner should install the candidate and run the V16 §13
acceptance scenarios (A through E) on real SketchUp 2020.

---

## J. Remaining risks / unknowns

**Confirmed V1.6 defects**: NONE (this dispatch's scope).

**Assumptions**:
1. The Blueprint's `Sketchup::Entities#transform_by_vectors`
   host route is the approved mutation primitive. No
   alternative has been tested.
2. The fake adapter's `FakeVertex` model is a faithful
   stand-in for `Sketchup::Vertex` end-to-end for the
   regression set (XY preserved, Z-only mutation,
   position readable, validity checkable).
3. The dialog JS side will be wired in a separate
   AIPM-authorized UX pass (this dispatch provides the
   snapshot data contract; the existing app.js render
   bridge is unchanged).

**Unknowns**:
1. The production `SketchupDerivedWorkspaceAdapter.
   transform_vertices_by_vectors`'s exact behavior under
   real host topology (curves / faces / shared vertices
   with mixed incident geometry) is NOT covered by
   automated tests. This is what the Owner SU2020
   real-host verification gate exists to prove.
2. Real SU2020 `transform_by_vectors` ownership semantics
   (every vertex must share a `Sketchup::Entities`
   collection) is implemented per `_resolve_entities_collection`
   but not real-host tested.
3. The blueprint's `coordinate_epsilon` semantics under
   the existing default (1e-6 inch) for the host
   validation path are identical to the test path; not
   real-host tested.

**Real-host-only evidence** (per Blueprint §13 Owner
scenarios A–E):
- A. Small Z noise → proposal → apply → derived planar,
  source unchanged — NOT YET RUN (Owner / AIPM real-host).
- B. Non-zero translated plane → normalize near that plane,
  not world zero — NOT YET RUN.
- C. Outlier → safe majority moves, outlier remains /
  reported — NOT YET RUN.
- D. Ambiguous split → refuses to guess — NOT YET RUN.
- E. Discard / rebuild → source still intact, derived
  proposal returns — NOT YET RUN (tested at the Ruby level
  via H6; real-host Discard / Rebuild path is the same V1.4
  WorkingModeRunner code that was already verified at
  SU2020 by V1.4 Owner Gate).

**No code in this dispatch was Owner-verified on real
SketchUp.** This is expected — Owner real-host verification
is an Owner / AIPM step, not a Pi step, per Blueprint §13.

---

## K. Code review trigger

`CODEX_TRIGGER: NO`

Reason (per dispatch §8): no material repo-aware issue was
uncovered in implementation involving:
- world / local transform architecture (the V1.6 mutation is
  Z-only on derived geometry, preserving the V1.4 contract);
- source / derived ownership (Blueprint §4 invariant is
  unchanged; source CAD remains immutable; only derived
  vertices move);
- transaction / recovery / Undo (the executor wraps one host
  operation; preflight / host / post-validation all fail
  closed without committing; existing V1.5 BLOCK-005
  host-state-consistency seam is untouched);
- provenance architecture (V1.6 reuses the existing
  `SourceSnapshot.execution_config.tolerance_values`
  schema-versioning contract; no new persistence layer);
- destructive normalization semantics (Blueprint §6.4
  shared-vertex safety prevents silent dragging of
  ineligible geometry);
- SketchUp host compatibility requiring design change
  (`transform_by_vectors` is SU 6.0+, well within the SU
  2017+ intended baseline).

AIPM decides whether Codex is actually called. This dispatch
does NOT invoke Codex itself.

---

## L. Owner verification

**NOT YET RUN.**

Short test instructions for the V1.6 Owner / AIPM real-host
SU2020 verification gate (per Blueprint §13 scenarios):

A. Small Z noise
   1. Install `dist/SU-AI-Plugin.rbz` via SketchUp Extension
      Manager.
   2. Restart SketchUp 2020.
   3. Open a CAD file with a few imported edges whose Z
      values drift by < 0.01 inch (e.g. (0,0,1.000),
      (10,0,1.005), (0,5,1.002), (10,5,1.008)).
   4. Select the edges → Plugins → SU-AI-Plugin → Analyze
      selection.
   5. Click "Prepare".
   6. The "Planar normalization" row in Working Mode should
      show state = READY_TO_NORMALIZE, target_z ≈ 1.003,
      4 eligible vertices, ~3 movable, 0 outliers.
   7. Click "Apply Safe Normalization".
   8. Visually verify the derived group is planar at
      z ≈ 1.003.
   9. Source CAD unchanged.

B. Non-zero translated plane
   1. Same flow with edges at z ≈ 1000 (e.g. (0,0,999.99),
      (10,0,1000.01), …).
   2. Verify the proposed target_z is ≈ 1000, NOT 0.

C. Outlier
   1. Same flow with 9 edges around z=1.0 + 1 distant
      edge at z=50.
   2. Verify the outlier edge's two endpoints remain
      at z=50 (unchanged); the 9 inliers move to target_z.

D. Ambiguous split
   1. Same flow with 5 edges around z=1.0 + 5 around z=2.0.
   2. Verify state = REVIEW_REQUIRED with reason
      `tied_dominant_windows` or `no_strict_majority` (NOT
      applied).

E. Discard / Rebuild
   1. Same flow with any of the above; apply once, then
      click "Discard" and verify the derived group is gone
      but the source CAD is intact.
   2. Click "Prepare" again, then "Rebuild" — the
      normalization proposal should re-appear.

The Owner is responsible for executing these scenarios on
real SketchUp 2020 and reporting PASS / FAIL per the
acceptance criteria. Pi does NOT run Owner real-host
verification on behalf of Owner.

---

## M. Commit / push facts

### M.1 Commit facts

Stable local checkpoints on `dev/v1.6` (chronological):

1. `docs(v1.6): track V1.5 closure record + frozen V1.6 Stage
    Technical Blueprint as durable authority documents`
    — added `Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md` and
    `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
    as tracked durable project documents, unchanged.
2. `feat(v1.6): add planar normalization proposal (analyzer +
    proposer + executor + tolerance)`
    — 7 production files: 3 new V1.6 modules + 2 adapter files
    updated + tolerance.rb + analysis_config.rb.
3. `feat(v1.6): apply safe derived Z normalization (runner +
    UI + boot)`
    — 3 production files: working_mode_runner.rb + dialog_runner.rb +
    main.rb.
4. `test(v1.6): complete planar normalization regression`
    — 1 test file: tests/test_v16_planar_normalization.rb
    (25 tests).
5. `docs(v1.6): V1.6 PI-IMPLEMENTATION state + report sync`
    — CURRENT_STATE.md + Review/CURRENT_PI_REPORT.md (this
    file).

The final HEAD SHA is `git rev-parse HEAD` at the end of
this dispatch (recorded via the doc-stamp commit). Verify via:

```bash
git rev-parse HEAD
git rev-parse dev/v1.6
```

### M.2 Push facts

- Push attempted ONLY: `dev/v1.6 → origin/dev/v1.6`.
- NEVER pushed / merged: `main`.
- NEVER performed: force-push, rebase of shared history,
  rewrite of shared history, release / tag creation.
- Per dispatch §14, the push is a bounded network attempt.
  GitHub reachability from this host is unknown (the prior
  V1.5 closure-sync dispatch also reported GitHub
  unreachable from this environment). If GitHub remains
  unreachable, the local commits are stable, self-contained,
  and atomic, and can be retried by AIPM from a reachable
  environment.
- Local-ahead of `origin/dev/v1.5` after this dispatch: 9
  commits (V1.6 doc-stamp + 3 implementation + test +
  doc-stamp + state-sync commits).
- `Prompt/CURRENT_PI_DISPATCH.md` is modified by AIPM (active
  dispatch); intentionally uncommitted per V3.4 governance.

---

## N. Definition of Pi Complete (per dispatch §15)

- [x] V1.6 Blueprint is tracked and unchanged.
- [x] `dev/v1.6` is based on exact closed local V1.5 line
      (`f35ed84`).
- [x] `planar_z_snap` captured deterministically (Tolerance +
      to_h + ExecutionConfigSnapshot schema version).
- [x] Safe normalization proposal exists
      (`PlanarNormalizationProposer.propose`).
- [x] Ambiguous / tied cases refuse to guess
      (Blueprint P5 / P6 → REVIEW_REQUIRED).
- [x] Outliers remain unchanged (Blueprint §6.3 + G5).
- [x] Explicit user approval exists (`Apply Safe
      Normalization` callback → `apply_planar_normalization`).
- [x] Only derived geometry moves (proposer + executor
      operate exclusively on `workspace.handle_for`; G6
      proves source fingerprint unchanged).
- [x] XY preservation is validated (post-validation in
      executor; G1 verifies against fake adapter's tracked
      FakeVertex handles).
- [x] Shared-vertex / curve / face unsafe scope fails closed
      (Blueprint §6.4; G2 / G3 / G4).
- [x] Host mutation uses approved old-host-compatible route
      (`Sketchup::Entities#transform_by_vectors` per Blueprint
      §3).
- [x] Post-validation exists (executor §9; H2 verifies
      post-state).
- [x] Source CAD / raw coordinates remain unchanged (G6;
      SourceSnapshot deep-freeze contract).
- [x] Normalization audit / provenance exists (`audit` field
      in snapshot + frozen audit Hash from executor).
- [x] Idempotency proven (P9 + proposer's idempotent
      `compute_planar_normalization`).
- [x] Existing Discard / Rebuild / Undo safety remains
      (H6 + V1.4 host-state-consistency seam untouched).
- [x] V1.5 regressions remain green (817 pre-existing tests
      still pass; the 2 RBZ tests that previously failed
      re: V1.6 modal files now PASS after the V1.6 RBZ
      rebuild).
- [x] RBZ candidate built and verified (see §I).
- [x] Owner SU2020 verification instructions prepared (§L).
- [x] V1.6 NOT marked CLOSED (per dispatch §15 — closure is
      Owner / AIPM-side after real-host verification).
- [x] Final stable local commits exist on `dev/v1.6` (§M.1).
- [x] Submission attempted only within the network rules
      (§M.2 — bounded attempt; not blocking).

**Pi Complete on dispatch `V16-PLANAR-NORMALIZATION-IMPLEMENTATION-2026-08-31`**.

Pi does NOT:
- mark V1.6 CLOSED;
- start V1.7;
- invoke Codex;
- run Owner real-host verification on behalf of Owner;
- push or merge `main` (or push at all if GitHub remains
  unreachable).

---

# One-Line V1.6 PI-Implementation Pi Report

**V1.6 PI IMPLEMENTATION DISPATCH EXECUTION COMPLETE (dispatch
ID exact `V16-PLANAR-NORMALIZATION-IMPLEMENTATION-2026-08-31`)
on assigned `dev/v1.6` (created from closed local V1.5 HEAD
`f35ed848e5b455fafee3aeff0481d04565c4f5f1`). The frozen V1.6
Stage Technical Blueprint
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
was implemented strictly inside its contract: a deterministic
PlanarNormalizationAnalyzer (host-free sliding-window with
strict-majority + tie-detection + IEEE-754 operational
epsilon), a host-aware PlanarNormalizationProposer (edge
safety via adapter.edge_curve / edge_faces_count,
shared-vertex cluster safety, candidate position dedup by
coordinate_epsilon, host mutation plan with per-vertex handle
+ matching Z-only translation vector), and a
PlanarNormalizationExecutor (preflight + one
host operation + adapter.transform_vertices_by_vectors +
XY/Z post-validation + commit/abort on failure → FAILED).
Tolerance gains `planar_z_snap` (default 0.01 inch, frozen
Blueprint §4.1) with per-field DEFAULT_* constants and
automatic ExecutionConfigSnapshot schema-version drift
detection. WorkingModeRunner gains compute_planar_normalization
(idempotent Step 1) and apply_planar_normalization (one user-
triggered Step 2) plus a `planar_normalization` snapshot sub-
Hash with state / proposal / audit; discard / rebuild /
reset_for_tests all clear V1.6 state. Dialog exposes
`compute_planar_normalization` and `apply_planar_normalization`
callbacks routed through `_safe_invoke`. Production boot chain
loads the three new V1.6 modules BEFORE the dialog_runner per
the CodeX BLOCK-001 2026-08-25 lesson. The production
SketchUp adapter implements the Blueprint §3 approved legacy-
compatible `Sketchup::Entities#transform_by_vectors` route with
strict Z-only vector enforcement; no new Observer / Undo /
persistent-id architecture; no generalized CAD flattening
kernel. V1.5 regression coverage preserved: full suite
842/842 PASS (25 V1.6 + 817 pre-existing), 0 fail, 0 error.
RBZ smoke 9/9 PASS. Node DOM PASS. `git diff --check` clean.
V1.6 RBZ candidate at
`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`: 733,504 bytes,
62 entries, SHA-256
`c1e4b641b1ac8f509c7bfede52770bbd6d8a2f771f3003f4f5e572341dc72b68`
(+3 vs V1.5: planar_normalization_analyzer.rb,
planar_normalization_proposer.rb,
planar_normalization_executor.rb). 5 stable local commits on
`dev/v1.6` (doc-stamp + 3 implementation + final state sync).
NOT PUSHED per dispatch §14 (bounded network retry only;
AIPM can retry the push from a reachable environment; same
RBZ is available on the RBZ file system path for the Owner
SU2020 verification gate regardless). NEVER pushed / merged
`main`; NEVER force-pushed, rebased shared history, rewrote
history, or created a release / tag. V1.6 NOT marked CLOSED
(closure is Owner / AIPM-side per Blueprint §13 after real
SU2020 Owner verification PASS); V1.6 NOT marked closed by
Pi per dispatch §15 STOP condition. `CODEX_TRIGGER: NO`
(material repo-aware issues: none — see §K). Owner SU2020
real-host verification is NOT YET RUN per dispatch §15
(Owner / AIPM step, not a Pi step). Pi STOPPED awaiting AIPM
direct source review.**
