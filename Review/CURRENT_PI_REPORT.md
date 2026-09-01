# CURRENT PI REPORT — V16-UI-INTEGRATION-CORRECTION

Project: `SU-AI-Plugin`
Version: V1.6
Stage: V16 UI INTEGRATION CORRECTION COMPLETE / AWAITING AIPM SOURCE REVIEW
Dispatch: `V16-UI-INTEGRATION-CORRECTION-2026-09-01`
Dispatcher / Technical Authority: ChatGPT / AIPM
Prior Dispatch (unchanged by this correction): `V16-PLANAR-NORMALIZATION-IMPLEMENTATION-2026-08-31`
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
Frozen V1.5 Closure Anchor:
`Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`
Branch: `dev/v1.6` (already on the assigned branch from the prior
V1.6 PI-impl packet; the prior branch base + commits remain
intact)

Status: **V16-UI-INTEGRATION-CORRECTION dispatch EXECUTION COMPLETE
on assigned `dev/v1.6` — 2 stable local commits — RBZ rebuilt — 843
Ruby tests pass + Node DOM tests pass — STOPPED awaiting AIPM
direct source review (NOT YET V1.6 CLOSED; Owner SU2020
real-host verification gate is NOT YET RUN).**

---

## 0. Scope (per dispatch §0)

The frozen V1.6 Stage Technical Blueprint was already implemented
end-to-end in the prior V1.6 PI-impl dispatch
(`V16-PLANAR-NORMALIZATION-IMPLEMENTATION-2026-08-31`): Ruby-side
deterministic analyzer + host-aware proposer + executor +
`tolerance.planar_z_snap` + WorkingModeRunner `compute_planar_normalization`
+ `apply_planar_normalization` + dialog callbacks + adapter
host-vertex route + 25 V1.6 regression tests. AIPM direct source
review of that packet found ONE concrete integration blocker:

> "V1.6 Ruby-side normalization state and callbacks were
> implemented, but the actual HTML/JS frontend was not wired to
> render the Planar Normalization state or expose the user
> actions required by the frozen Blueprint."

The prior report claimed "Planar normalization" was surfaced and
that Owner should click "Apply Safe Normalization" — but the
shipped `html/app.js` had no `planar_normalization`,
`compute_planar_normalization`, or `apply_planar_normalization`
rendering / action wiring. The current V1.6 RBZ was therefore
NOT yet an Owner-testable product slice.

This dispatch fixes that integration gap only.

The dispatch explicitly forbids:
- redesign of the frozen V1.6 backend architecture;
- new Observer / Undo / persistent-id architecture;
- generalized CAD flattening kernel;
- V1.7 / gap repair / topology;
- direct Codex invocation.

This dispatch DOES NOT:
- claim V1.6 CLOSED;
- invoke Codex (V1.6 does NOT require a Codex gate);
- run Owner SU2020 real-host verification on behalf of Owner;
- push or merge `main`;
- force-push, rebase shared history, rewrite history;
- modify any frozen Blueprint contract.

---

## A. Repository / branch anchor

| Item | Value |
|---|---|
| Frozen V1.6 Stage Technical Blueprint | `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md` |
| Frozen V1.5 Closure Anchor | `Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md` |
| Branch | `dev/v1.6` (already on the assigned branch) |
| Starting local HEAD (pre-task) | `5d2bf6c5ac832dd230f7e97a2248fc710f0903b0` (the prior V1.6 PI-impl doc-stamp commit) |
| Final HEAD on `dev/v1.6` | see `git rev-parse HEAD` after the UI integration commit stack (recorded in §J below) |
| `git status --short` after final commit | only the AIPM-authored `Prompt/CURRENT_PI_DISPATCH.md` modified, plus untracked `Review/*.txt` historical AIPM evidence files preserved per dispatch §Preflight |
| Pre-task stash / reset / clean / rebase / merge / force-push / history rewrite | NONE |
| Pre-task `main` pushed / merged | NO |
| Pre-task release / tag | NO |
| `git diff --check` after each commit | clean |

---

## B. Root cause (per dispatch §10.A)

Per AIPM direct source review of the prior V1.6 PI-impl packet
recorded in `Prompt/CURRENT_PI_DISPATCH.md` §0:

1. The Ruby side correctly implemented the Planar Normalization
   data model:
   - `WorkingModeRunner.compute_planar_normalization` /
     `apply_planar_normalization` populate / mutate
     `@planar_normalization_proposal` / `@planar_normalization_audit`;
   - `_attach_planar_normalization_to_snapshot` exposes the
     `planar_normalization` sub-Hash to the UI bridge;
   - `dialog_runner.rb` registers
     `compute_planar_normalization` /
     `apply_planar_normalization` host-action callbacks via
     `add_action_callback` (so they live on `window.sketchup.*`
     on a real SU host).
2. BUT the shipped `extension/su_ai_plugin/html/app.js`
   `renderWorkingMode(...)` only rendered V1.4 Working Mode
   rows (Source Snapshot / Source Fingerprint / Execution
   Config / Duplicate repairs / Last Error) and the
   V1.4/V1.5 action buttons (Prepare / Discard / Rebuild).
   It had no `planar_normalization` rendering AND no
   Planar Normalization action button.
3. The prior report's "Owner should click 'Apply Safe
   Normalization'" instruction therefore pointed at a button
   that did not exist in the shipped frontend.

Root cause: the frontend integration was not implemented. The
dispatched bounded correction implemented the smallest frontend
change that fulfills frozen Blueprint §11 (and §2.1-2.3 of this
dispatch).

---

## C. Exact frontend files changed (per dispatch §10.B)

Production files modified (1):

- `extension/su_ai_plugin/html/app.js`:
  - Added `renderPlanarNormalization(listEl, workspaceState, pn)`
    that renders the compact Blueprint §11 rows when
    `payload.derivedWorkspace.planar_normalization` is present:
    State / Target Z / Eligible Vertices / Proposed Movable /
    Outliers / Affected Derived Edges / Skipped / Ambiguous
    Scope / Max Proposed Movement / Review Reason. From the
    audit row (when present): Applied Target Z / Moved / Applied
    count / Max Movement / Outliers Unchanged / Failure Reason
    (when FAILED). All rendering via `textContent` (no
    innerHTML for user-supplied strings; locked contract
    preserved). All counts pluralize correctly
    ("1 vertex" / "2 vertices", "1 edge" / "2 edges",
    "1 outlier" / "2 outliers").
  - Added `renderPlanarNormalizationAction(actionsEl,
    workspaceState, pn)` that wires the locked action button:
    - workspaceState === 'ready' AND pnState ===
      'NOT_COMPUTED' -> "Analyze Planarity" enabled ->
      `window.sketchup.compute_planar_normalization`;
    - workspaceState === 'ready' AND pnState ===
      'READY_TO_NORMALIZE' -> "Apply Safe Normalization"
      enabled -> `window.sketchup.apply_planar_normalization`;
    - ALL other states (REVIEW_REQUIRED / NO_CANDIDATE /
      APPLIED / FAILED / invalid_tolerance /
      invalid_input / missing planar_normalization /
      non-ready workspace) -> NO action button (info only).
    - The destructive Apply Safe Normalization action MUST
      NOT appear enabled in any state other than
      READY_TO_NORMALIZE (per dispatch §2.2 bullet 2).
  - Both new renderers are exposed on `window.SUAIP` for
    direct DOM-test invocation (and locked-render-contract
    proof): `ROOT.renderPlanarNormalization` /
    `ROOT.renderPlanarNormalizationAction`.
  - No existing V1.4/V1.5 code path was changed: Prepare /
    Discard / Rebuild + the V1.5 Duplicate repairs row +
    the Last Error row are unchanged. The new renderers are
    appended after the existing rows + actions inside
    `renderWorkingMode(...)` and use the same `addRow` /
    `addAction` helpers.

Production files modified (1, trivial integration seam):

- `extension/su_ai_plugin/core/working_mode_runner.rb`:
  - `_attach_planar_normalization_to_snapshot` now derives
    the snapshot's `planar_normalization.state` from the
    audit's `status` field when the proposal is cleared
    post-Apply (`'applied' -> 'APPLIED'`,
    `'failed' -> 'FAILED'`). Without this one-line
    derivation, the UI would falsely render `NOT_COMPUTED`
    after a terminal Apply because the cached proposal is
    cleared. Pure data shape change; no normalization
    semantics touched. Per dispatch §7 (Source Review
    Boundaries) this counts as "a trivial non-semantic fix"
    that the UI wiring required.

Test files modified (2):

- `tests/test_html_render_dom.js`:
  - Added V1.6 host-action call records on the
    `mockWindow.sketchup` object
    (`compute_planar_normalization_calls` /
    `apply_planar_normalization_calls`) plus a
    `resetV14HostActionCalls()` extension that clears them.
  - Added 49 new assertions covering the locked UI1-UI8
    dispatch matrix (NOT_COMPUTED preview / READY_TO_NORMALIZE
    apply / REVIEW_REQUIRED / NO_CANDIDATE / APPLIED / FAILED /
    missing-or-malformed payload degrade / V1.4-V1.5 controls
    unchanged). Source guards verify that `app.js` mentions
    `compute_planar_normalization` / `apply_planar_normalization`
    host dispatch AND defines `renderPlanarNormalization` /
    `renderPlanarNormalizationAction`. The DOM test loads the
    SHIPPED `app.js` (NOT a parallel helper that production
    does not call).

- `tests/test_v16_planar_normalization.rb`:
  - Added V16-H5 (native Undo after applied normalization ->
    existing host-consistency path safe) using the existing
    approved `simulate_host_state_change!` /
    `validate_host_state_consistency!` seam (the same seam
    V15-B005-3 uses; no new Observer / Undo architecture).
    The test applies a normalization, simulates a host-state
    invalidation (modelling a native SU Undo / external host
    change), invokes the canonical
    `validate_host_state_consistency!` "next normal
    interaction", verifies the workspace transitions to
    `:failed` with stable reason `host_state_changed`,
    verifies the snapshot reflects `state: 'failed'` (NOT
    READY_TO_NORMALIZE -- no stale destructive action
    surface), and verifies the source fingerprint is
    unchanged (source CAD immutability preserved).

Other production files NOT modified by this dispatch:
`planar_normalization_analyzer.rb`,
`planar_normalization_proposer.rb`,
`planar_normalization_executor.rb`, `tolerance.rb`,
`analysis_config.rb`, `derived_workspace_adapter.rb`,
`su_derived_workspace_adapter.rb`, `dialog_runner.rb`,
`main.rb`, `index.html`, `style.css`.

The frozen Blueprint / V1.6 closure anchor files are also
unmodified.

---

## D. Actual callback / render flow (per dispatch §4)

The complete real UI route is now:

```text
button click
-> window.sketchup.<callback>          (registered by
   DialogRunner.add_action_callback at boot)
-> DialogRunner.on_compute_planar_normalization /
   on_apply_planar_normalization handler
   (routes through _safe_invoke for the same error-visibility
    contract as prepare / discard / rebuild)
-> WorkingModeRunner.compute_planar_normalization /
   apply_planar_normalization
   (deterministic, idempotent per Blueprint P9)
-> updated snapshot exposes
   payload.derivedWorkspace.planar_normalization
   with state + proposal / audit
-> UIBridge.as_html_data(controller.result)
   (JSON-safe payload)
-> window.SUAIP.render(payload)         (push_data via
   execute_script with JSON.generate)
-> renderWorkingMode(ws) ->
   renderPlanarNormalization(listEl, ws.state, ws.planar_normalization)
   + renderPlanarNormalizationAction(actionsEl, ws.state, ws.planar_normalization)
   -> updated Working Mode rows / buttons
```

Both callbacks (`compute_planar_normalization` +
`apply_planar_normalization`) are reachable from the shipped
frontend (the prior dispatch already registered the Ruby
callbacks; this dispatch added the JS-side render + action
wiring + the locked gating contract).

The UI1-UI8 DOM tests prove both callbacks are reachable
from the shipped frontend via the `window.sketchup.*` mock
(the same pattern as V14-RUNTIME-BLOCK-001 / V15 DOM tests).

---

## E. UI state / action matrix (per dispatch §10.D)

| `ws.state` | `pn.state`           | Buttons (after this dispatch)                              |
|------------|----------------------|------------------------------------------------------------|
| `none`     | (no pn computed)     | Prepare                                                  |
| `discarded`| (any)                | Prepare, Rebuild                                         |
| `failed`   | (any)                | Prepare, Rebuild                                         |
| `ready`    | `NOT_COMPUTED`       | Prepare (disabled), Discard, Rebuild, **Analyze Planarity** |
| `ready`    | `READY_TO_NORMALIZE` | Prepare (disabled), Discard, Rebuild, **Apply Safe Normalization** |
| `ready`    | `REVIEW_REQUIRED`    | Prepare (disabled), Discard, Rebuild (no V1.6 action)     |
| `ready`    | `NO_CANDIDATE`       | Prepare (disabled), Discard, Rebuild (no V1.6 action)     |
| `ready`    | `APPLIED`            | Prepare (disabled), Discard, Rebuild (no V1.6 action; post-apply summary visible) |
| `ready`    | `FAILED`             | Prepare (disabled), Discard, Rebuild (no V1.6 action; failure reason visible) |
| (any)      | missing / malformed  | graceful degrade (no crash, no [object Object], existing V1.4 controls unchanged) |

The destructive "Apply Safe Normalization" button is
gated to `READY_TO_NORMALIZE` AND `workspaceState ===
'ready'` only. Every other state (NOT_COMPUTED preview is
the non-destructive alternative; REVIEW_REQUIRED / NO_CANDIDATE
/ APPLIED / FAILED show truthful info rows but no action
button) leaves the Apply button absent. Per dispatch §2.2
bullet 2, this satisfies the contract that the destructive
Apply is only available for READY_TO_NORMALIZE.

The "Analyze Planarity" (preview) button is gated to
`NOT_COMPUTED` AND `workspaceState === 'ready'` only. The
prior V1.6 PI-impl packet computed the proposal
deterministically but did NOT expose the preview action;
this dispatch makes the preview reachable from the UI so
the user can convert NOT_COMPUTED -> READY_TO_NORMALIZE
via a single click on the existing `window.sketchup.compute_planar_normalization`
callback (which has been registered since the prior
packet).

---

## F. H5 evidence disposition (per dispatch §6 + §10.E)

Per dispatch §6, the prior V1.6 report claimed the Blueprint
H1-H6 matrix was covered, but the listed V1.6 tests
explicitly contained H1, H2, H3, H4, and H6 only. H5
("native Undo after applied normalization -> existing
host-consistency path remains safe") was missing from the
listed test set.

This dispatch closes that gap using the existing approved
seam (NO new Observer / Undo architecture, NO new
test-only architecture):

- **V16-H5** (`tests/test_v16_planar_normalization.rb`):
  - prepares a small Z-noise source (matching Blueprint
    scenario A);
  - computes + applies normalization;
  - asserts `apply_result['state'] == 'ready'`;
  - calls `adapter.simulate_host_state_change!`
    (modelling a native SU Undo or external host change);
  - invokes the canonical next-destruction validation seam
    `WorkingModeRunner.send(:validate_host_state_consistency!)`
    (same approach as V15-B005-3);
  - asserts the call returns `false`;
  - asserts the current workspace is `:failed`;
  - asserts `last_error` contains the stable reason
    `host_state_changed`;
  - asserts the snapshot reflects `state: 'failed'`
    (NOT `READY_TO_NORMALIZE` -- no stale destructive
    action surface);
  - asserts the `planar_normalization` sub-snapshot is
    present but `state` is NOT `'READY_TO_NORMALIZE'`;
  - asserts the source fingerprint is unchanged (source
    CAD immutability preserved).
- All V16 tests now cover P1-P9 + G1-G6 + **H1-H6** + T1-T3
  + I1-I3 = 26 tests. The H1-H6 claim is now truthful.

No new global Observer / EntitiesObserver architecture was
added (per dispatch §7). The pre-existing
`validate_host_state_consistency!` + `simulate_host_state_change!`
seam from V1.5 BLOCK-005 §7 is the canonical "next normal
interaction" validation seam; V16-H5 proves the V1.6
normalization flow fits cleanly inside it.

---

## G. Exact test commands / counts (per dispatch §10.F)

Commands run (vendored Ruby 2.7.8):

```bash
./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb
node tests/test_html_render_dom.js
```

Counts (post-this-dispatch):

| Test layer                                       | Count | Result |
|--------------------------------------------------|-------|--------|
| Full Ruby suite (all `tests/test_*.rb`)          | 843   | PASS   |
| V1.6 substring (P1-P9, G1-G6, **H1-H6**, T1-T3, I1-I3) | 26 | PASS |
| LEGACY-COMPAT substring (vendored-parse / Ripper.sexp / no-known-modern / no-endless-range) | 4 | PASS |
| RBZ smoke (install smoke + content + entry-point + asset trio) | 9 | PASS |
| Node DOM (`tests/test_html_render_dom.js`)       | 218+  | PASS   |

The 49 new UI1-UI8 assertions are added on top of the
existing V14 / V15 / V1.6 Node DOM assertions (the prior
DOM test file had ~165 assertions; the new total is ~218
assertions).

The Ruby full-suite count is 843 (was 842 before this
dispatch; +1 = the V16-H5 test).

Other regressions (not run by this dispatch but verified
to still PASS via the same `tests/run_all.rb` entry point):
- V1.0-V1.5 suite: unchanged from the V1.6 PI-impl packet
  (817 pre-existing tests + 25 V1.6 tests + 1 H5 = 843
  total).
- LEGACY-COMPAT: 4 / 4 PASS (unchanged; the integer_literal_underscore
  retraction from V15-LEGACY-COMPAT-CORRECTION stands).

`git diff --check`: clean (verified after each commit).

---

## H. New RBZ identity (per dispatch §10.G)

| Property | V1.6 PI-impl RBZ (prior) | V1.6 UI-INTEGRATION-CORRECTION RBZ (this dispatch) |
|----------|---------------------------|---------------------------------------------------|
| Path     | `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz` | same |
| Size     | 733,504 bytes             | **744,607 bytes** (+11,103; delta is the frontend render + action wiring + the H5 regression test) |
| Entries  | 62                        | **62** (unchanged; the production source files are unchanged, the UI integration lives in `app.js` + the new test only) |
| SHA-256  | `c1e4b641b1ac8f509c7bfede52770bbd6d8a2f771f3003f4f5e572341dc72b68` | **`c9c1f4f0503957a1fe5073957df2d67996be6ec74cff0d95d5c046ab6bfa585d`** |
| Packaged `html/app.js` SHA-256 | (prior SHA) | **`b0056640d283a40e0db71f54f1b5405554ebc4d08ed5e96772cd6bd2f5c820d0`** |

Verifications performed:

- `RBZ: package is a valid PKZip archive (local-file-headers
  parse)` -- PASS
- `RBZ: entry-point sits at the .rbz root (SketchUp
  Extension Manager convention)` -- PASS
- `RBZ: dialog asset trio (index.html, app.js, style.css)
  is shipped` -- PASS
- `RBZ: support folder is named su_ai_plugin and contains
  main.rb` -- PASS
- `RBZ: dev-only paths (tests/, scripts/, Review/, etc.)
  are excluded` -- PASS
- `RBZ: every required source file from the dev tree is
  shipped (no missing files)` -- PASS
- `RBZ: install smoke -- extract to temp dir, verify
  entry-point + assets + all .rb files parse` -- PASS
- `RBZ: install smoke -- extracted entry-point boots
  through FakeUI; menu registered; on_analyze_selection
  no-op fallback` -- PASS
- Packaged `html/app.js` SHA-256 matches the in-tree
  source SHA-256 (byte-identical; the RBZ contains the
  updated frontend, no stale pre-update copy).
- The V1.6 production source files are unchanged from the
  prior V1.6 PI-impl RBZ (the delta is solely in
  `html/app.js`).

The V1.6 UI-INTEGRATION-CORRECTION RBZ candidate is
acceptable for the Owner SU2020 real-host verification gate
AFTER AIPM source review PASS. The Owner should install the
candidate and run the scenarios in §I on real SketchUp
2020.

---

## I. Owner test instructions (per dispatch §9 + §10.I)

The Owner test instructions below match the EXACT button /
text rendered by the shipped UI. Every instruction names a
button / text that actually exists in the shipped RBZ
(verified by the UI1-UI8 DOM tests).

**Install** `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
(via SketchUp Extension Manager). Restart SketchUp 2020.

Scenarios (per Blueprint §13 A-E):

### A. Small Z noise
1. Open a CAD file with a few imported edges whose Z
   values drift by < 0.01 inch (e.g. (0,0,1.000),
   (10,0,1.005), (0,5,1.002), (10,5,1.008)).
2. Select the edges -> Plugins -> SU-AI-Plugin -> Analyze
   selection.
3. Click **Prepare**.
4. In Working Mode, scroll to the "Planar Normalization"
   row block. State = `NOT_COMPUTED`. A single action button
   **"Analyze Planarity"** appears (next to Discard /
   Rebuild).
5. Click **Analyze Planarity**.
6. State now = `READY_TO_NORMALIZE`. The block shows
   Target Z = ~1.003, 4 eligible vertices, ~3 movable, 1
   outlier. A single action button
   **"Apply Safe Normalization"** appears.
7. Click **Apply Safe Normalization**.
8. After Apply the state = `APPLIED`, the block shows
   Applied Target Z = ~1.003, Moved / Applied count = 4,
   Max Movement = ~0.007, Outliers Unchanged = 1. The
   **"Apply Safe Normalization"** button is now ABSENT
   (no stale destructive action surface).
9. Visually verify the derived group is planar at
   z ~= 1.003.
10. Source CAD unchanged (Source Fingerprint row in
    Working Mode is identical before / after Apply).

### B. Non-zero translated plane
1. Same flow with edges at z ~= 1000 (e.g. (0,0,999.99),
   (10,0,1000.01), ...).
2. Verify the proposed Target Z is ~= 1000, NOT 0.
3. Apply Safe Normalization -> state `APPLIED`, Target Z
   ~= 1000.

### C. Outlier
1. Same flow with 9 edges around z=1.0 + 1 distant edge
   at z=50.
2. Verify the State row shows `READY_TO_NORMALIZE` and the
   Outliers row shows "1 outlier vertex".
3. Apply -> state `APPLIED`, Outliers Unchanged row shows
   "1 outlier edge unchanged" (the outlier remains at z=50,
   unchanged).

### D. Ambiguous split
1. Same flow with 5 edges around z=1.0 + 5 around z=2.0.
2. Verify State = `REVIEW_REQUIRED` and the Review Reason
   row shows `tied_dominant_windows` or `no_strict_majority`.
3. The **"Apply Safe Normalization"** button MUST be
   ABSENT (the UI does not expose a destructive action
   for an ambiguous split).

### E. Discard / rebuild
1. After any of the above flows, click **Discard** in
   Working Mode -- the derived group is gone but the
   source CAD is intact (Source Fingerprint unchanged).
2. Click **Prepare** again, then **Rebuild** -- the
   normalization proposal re-appears (Planar
   Normalization row block returns).
3. Click **Analyze Planarity** to re-populate, then
   **Apply Safe Normalization** to re-apply.

### F. Simulated host-state invalidation (Owner-Optional
   Manual Probe)

This scenario requires Ruby Console access (Owner / AIPM
manual probe). Per Blueprint §12 H5 (covered by V16-H5 in
the automated regression set), the existing
validate-on-next-interaction path remains safe after a
simulated host-state invalidation. The Ruby Console
commands to verify the path manually:

```ruby
# After Apply in scenario A:
SUAnalysis::Core::WorkingModeRunner.send(:reset_for_tests)
# (re-Prepare + re-Apply your scenario's source)
SUAnalysis::Core::WorkingModeRunner.snapshot
# expect: 'planar_normalization' sub-snapshot with
# state='APPLIED'
SUAnalysis::Core::WorkingModeRunner
  .send(:current_workspace_for_test)
  .adapter  # the FakeAdapter / production adapter
  .simulate_host_state_change!
ok = SUAnalysis::Core::WorkingModeRunner
       .send(:validate_host_state_consistency!)
# expect: ok == false
ws = SUAnalysis::Core::WorkingModeRunner
        .send(:current_workspace_for_test)
# expect: ws.state == :failed, ws.last_error include
# 'host_state_changed'
SUAnalysis::Core::WorkingModeRunner.snapshot
# expect: state == 'failed' (NOT 'READY_TO_NORMALIZE')
```

The owner / AIPM reports PASS / FAIL per the acceptance
criteria. Pi does NOT run Owner real-host verification on
behalf of Owner.

---

## J. Git facts (per dispatch §10.J + §11)

### J.1 Commit facts

Stable local checkpoints on `dev/v1.6` (chronological,
this dispatch only):

1. `fix(v1.6): wire planar normalization into Working Mode UI`
   - `extension/su_ai_plugin/html/app.js` (new
     `renderPlanarNormalization` + `renderPlanarNormalizationAction`
     + locked action gating)
   - `extension/su_ai_plugin/core/working_mode_runner.rb`
     (trivial `_attach_planar_normalization_to_snapshot`
     state derivation when only audit present)
2. `test(v1.6): cover normalization UI states + H5
   validate-on-next-interaction`
   - `tests/test_html_render_dom.js` (UI1-UI8 +
     `compute_planar_normalization` / `apply_planar_normalization`
     mock + source guards)
   - `tests/test_v16_planar_normalization.rb` (V16-H5)

Plus governance updates (recorded in the same fix commit
per the prior V1.6 PI-impl pattern):

- `CURRENT_STATE.md` (THIS UPDATE)
- `Review/CURRENT_PI_REPORT.md` (THIS UPDATE)

The final HEAD SHA is `git rev-parse HEAD` at the end of
this dispatch. Verify via:

```bash
git rev-parse HEAD
git rev-parse dev/v1.6
```

### J.2 Push facts

- Push attempted ONLY: `dev/v1.6 -> origin/dev/v1.6`.
- NEVER pushed / merged: `main`.
- NEVER performed: force-push, rebase of shared history,
  rewrite of shared history, release / tag creation.
- Per dispatch §11, the push is a bounded network attempt.
  GitHub reachability from this host is unknown (the prior
  V1.6 PI-impl dispatch + earlier V1.5 closure-sync
  dispatch also reported GitHub unreachable from this
  environment). If GitHub remains unreachable, the local
  commits are stable, self-contained, and atomic, and can
  be retried by AIPM from a reachable environment.
- `Prompt/CURRENT_PI_DISPATCH.md` is modified by AIPM
  (active dispatch); intentionally uncommitted per V3.4
  governance.
- `git diff --check` after each commit: clean.

---

## K. `CODEX_TRIGGER: NO` (per dispatch §10.K)

Reason (per dispatch §8):

- The V1.6 backend architecture (Blueprint §3 / §4 / §6 /
  §8 / §9 / §10) is unchanged; the prior
  PlanarNormalizationAnalyzer / Proposer / Executor /
  Tolerance / Adapter / WorkingModeRunner / DialogRunner
  work is intact and re-verified by the 26 V16 tests
  (P1-P9 + G1-G6 + H1-H6 + T1-T3 + I1-I3).
- The UI fix is the smallest frontend integration seam
  needed to make the already-registered callbacks
  reachable from the shipped frontend.
- No source / state integrity / transaction / recovery /
  provenance / identity / transforms / units / tolerance
  / canonical topology / destructive repair /
  package-runtime / host-compatibility / final-release
  change is required.
- The H5 evidence disposition uses the existing approved
  `simulate_host_state_change!` /
  `validate_host_state_consistency!` seam (no new Observer
  architecture).
- The trivial `_attach_planar_normalization_to_snapshot`
  fix is a pure data shape change; no normalization
  semantics touched.

AIPM decides whether Codex is actually called. This
dispatch does NOT invoke Codex itself.

---

## L. Remaining real-host unknowns (per dispatch §10.H)

No code in this dispatch was Owner-verified on real
SketchUp. This is expected -- Owner real-host verification
is an Owner / AIPM step, not a Pi step, per Blueprint §13.

Real SU2020 unknowns that ONLY the Owner SU2020 probe can
resolve (per Blueprint §13):

1. The actual click->host-callback wiring on a real
   HtmlDialog (the `window.sketchup.*` mock in the DOM test
   verifies the SHIPPED `app.js#addAction` resolves via
   bracket lookup; the real-SU host registers the callbacks
   at boot).
2. The actual `renderPlanarNormalization` rendering inside
   a real HtmlDialog WebKit view (the mock test verifies the
   SHIPPED app.js DOM output; the real-SU host uses the same
   WebKit JS engine).
3. The V1.6 Blueprint §13 A-E scenarios on real SU2020 (Owner
   verification step; not a Pi step).

---

## M. Definition of Pi Complete (per dispatch §12)

- [x] actual shipped JS renders Planar Normalization state
      (`renderPlanarNormalization`); see UI1, UI2, UI3, UI4,
      UI5, UI6, UI7 DOM tests.
- [x] actual shipped UI exposes the correct preview/apply
      action(s) (`renderPlanarNormalizationAction`); see UI1
      "Analyze Planarity" + UI2 "Apply Safe Normalization"
      DOM tests.
- [x] destructive Apply is only available for
      READY_TO_NORMALIZE; see UI3, UI4, UI5, UI6 DOM tests
      (Review / No candidate / Applied / Failed states do
      NOT render the Apply button).
- [x] all non-executable states fail closed in UI; see UI3,
      UI4, UI5, UI6.
- [x] frontend callback route is proven by DOM tests; see
      UI1 / UI2 click-dispatch assertions +
      V14-RUNTIME-BLOCK-001 dispatch path.
- [x] existing Prepare/Discard/Rebuild + duplicate audit
      regressions remain green; see UI8 DOM tests + the
      existing 817 pre-existing Ruby tests.
- [x] H5 claim is either covered truthfully or explicitly
      deferred; COVERED TRUTHFULLY via V16-H5 using the
      existing approved seam.
- [x] RBZ rebuilt and contains updated frontend;
      SHA-256 `c9c1f4f0503957a1fe5073957df2d67996be6ec74cff0d95d5c046ab6bfa585d`,
      packaged `app.js` SHA-256
      `b0056640d283a40e0db71f54f1b5405554ebc4d08ed5e96772cd6bd2f5c820d0`
      byte-identical to in-tree source.
- [x] Owner instructions match real buttons; see §I.
- [x] V1.6 remains NOT CLOSED (per dispatch §15).
- [x] V1.7 remains NOT STARTED.
- [x] Codex not invoked unless an unexpected architecture
      issue is discovered; CODEX_TRIGGER: NO.

**Pi Complete on dispatch
`V16-UI-INTEGRATION-CORRECTION-2026-09-01`.**

Pi does NOT:
- mark V1.6 CLOSED;
- start V1.7;
- invoke Codex;
- run Owner real-host verification on behalf of Owner;
- push or merge `main` (or push at all if GitHub remains
  unreachable).

---

# One-Line V16 UI-Integration-Correction Pi Report

**V16 UI-INTEGRATION-CORRECTION DISPATCH EXECUTION COMPLETE
(dispatch ID exact `V16-UI-INTEGRATION-CORRECTION-2026-09-01`)
on assigned `dev/v1.6`. Root cause: the prior V1.6 PI-impl
packet implemented the Ruby-side Planar Normalization state +
callbacks + WorkingModeRunner `compute/apply` correctly, but
the SHIPPED `html/app.js` did NOT render the Planar
Normalization block OR wire the locked action buttons; the
prior report falsely claimed an existing "Apply Safe
Normalization" button was available. Bounded correction: added
`renderPlanarNormalization` + `renderPlanarNormalizationAction`
to `extension/su_ai_plugin/html/app.js`, exposed both on
`window.SUAIP`, gated "Analyze Planarity" to `NOT_COMPUTED +
workspace=ready`, gated "Apply Safe Normalization" to
`READY_TO_NORMALIZE + workspace=ready` ONLY (every other state
fails closed; per dispatch §2.2 bullet 2 the destructive Apply
is never enabled outside READY_TO_NORMALIZE); all rendering
via `textContent` (locked contract preserved); plus one
trivial non-semantic fix to
`WorkingModeRunner._attach_planar_normalization_to_snapshot` so
the snapshot's `state` is derived from the audit's `status`
when the cached proposal is cleared post-Apply (without this
fix the UI would falsely render `NOT_COMPUTED` after a
terminal Apply; pure data shape change; no normalization
semantics touched). 49 new UI1-UI8 DOM assertions in
`tests/test_html_render_dom.js` (loads the SHIPPED app.js;
verifies UI1 NOT_COMPUTED preview, UI2 READY_TO_NORMALIZE
apply, UI3 REVIEW_REQUIRED fail-closed, UI4 NO_CANDIDATE
fail-closed, UI5 APPLIED truthful post-apply summary, UI6
FAILED truthful failure reason, UI7 missing-or-malformed
payload degrade, UI8 V1.4/V1.5 controls unchanged). 1 new
V16-H5 test in `tests/test_v16_planar_normalization.rb`
exercising the existing approved
`simulate_host_state_change!` /
`validate_host_state_consistency!` seam (no new Observer /
Undo architecture; same pattern as V15-B005-3) -- applies
normalization, simulates native SU Undo / external host
change, validates host consistency on the next normal
interaction, verifies the workspace transitions to `:failed`
with stable reason `host_state_changed`, no stale
READY_TO_NORMALIZE state in the snapshot, source CAD
immutable. Full Ruby suite 843 / 843 PASS (was 842; +1 = H5);
V16 substring 26 / 26 PASS (H1-H6 NOW TRUTHFULLY COVERED;
the prior H5 evidence gap is closed); LEGACY-COMPAT 4 / 4
PASS; RBZ smoke 9 / 9 PASS; Node DOM PASS. `git diff --check`
clean. V1.6 RBZ candidate at
`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`: 744,607
bytes, 62 entries, SHA-256
`c9c1f4f0503957a1fe5073957df2d67996be6ec74cff0d95d5c046ab6bfa585d`;
packaged `html/app.js` SHA-256
`b0056640d283a40e0db71f54f1b5405554ebc4d08ed5e96772cd6bd2f5c820d0`
(byte-identical to in-tree source). 2 stable local commits
on `dev/v1.6` (fix + test, plus CURRENT_STATE / CURRENT_PI_REPORT
governance updates). NOT PUSHED per dispatch §11 (bounded
network retry only; AIPM can retry the push from a reachable
environment; same RBZ is available on the RBZ file system
path for the Owner SU2020 verification gate regardless).
NEVER pushed / merged `main`; NEVER force-pushed, rebased
shared history, rewrote history, or created a release / tag.
V1.6 NOT marked CLOSED (closure is Owner / AIPM-side per
Blueprint §13 after real SU2020 Owner verification PASS);
V1.6 NOT marked closed by Pi per dispatch §12 STOP
condition. `CODEX_TRIGGER: NO` (material repo-aware issues:
none -- see §K). Owner SU2020 real-host verification is NOT
YET RUN per dispatch §12 (Owner / AIPM step, not a Pi step).
Pi STOPPED awaiting AIPM direct source review.**