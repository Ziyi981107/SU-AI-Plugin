# CURRENT PI REPORT — V16-CLOSE-AUTODISCARD

Project: `SU-AI-Plugin`
Version: V1.6
Stage: V16 CLOSE-AUTODISCARD COMPLETE / AWAITING AIPM SOURCE REVIEW
Dispatch: `V16-CLOSE-AUTODISCARD-2026-09-01`
Dispatcher / Technical Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Prior Dispatch (unchanged by this dispatch):
`V16-UI-CN-SIMPLIFICATION-FIX-2026-09-01`
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
Frozen V1.5 Closure Anchor:
`Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`
Branch: `dev/v1.6`

Status: **V16-CLOSE-AUTODISCARD dispatch EXECUTION COMPLETE on
assigned `dev/v1.6` — 1 stable local commit — RBZ rebuilt —
850 Ruby tests pass + 307 Node DOM assertions pass — STOPPED
awaiting AIPM direct source review (NOT YET V1.6 CLOSED;
final Owner SU2020 real-host verification gate of the
close-autodiscard fix is NOT YET RUN).**

---

## 0. Scope (per dispatch §0-§5)

This is a **bounded Owner UX fix BEFORE closure**. The frozen
V1.6 Stage Technical Blueprint + the V1.6 backend
(Planar Normalization analyzer / proposer / executor /
tolerance / adapter / WorkingModeRunner / DialogRunner
core path) + the Simplified Chinese UI surface are all
UNCHANGED.

Specifically this dispatch:

- Adds the close-time auto-discard path to
  `dialog_runner.rb` `on_close()` so the EXISTING discard-
  workspace contract is automatically run when the user
  explicitly closes the HtmlDialog.
- Reuses `WorkingModeRunner.discard` VERBATIM. NO second
  cleanup implementation is introduced.
- The auto-discard is FAIL-SAFE: a transient close-time
  error is swallowed at the boundary via
  `rescue StandardError` + `_safe_log`, so a close-time error
  can NEVER block SketchUp shutdown / model close / the
  HtmlDialog close callback.
- Preserves Source CAD completely (the discard contract
  only clears the derived workspace + V1.5 duplicate_repair
  summary + V1.6 planar_normalization proposal/audit).
- Clears the V1.6 planar-normalization transient
  proposal/audit state as the existing discard contract
  already requires (no new path).
- Does NOT change: Source-of-Truth, Prepare / Discard /
  Rebuild semantics, normalization algorithms, Undo /
  reconciliation, transaction, provenance, observer
  architecture, V1.7 scope.

---

## A. Owner real-host finding (per dispatch §1)

> Closing the SU-AI-Plugin dialog currently leaves the
> transient Derived Workspace alive. When the plugin is
> opened again, the user must manually Discard the previous
> workspace before preparing a new selection. This creates
> unnecessary workflow friction.

Required behavior (per dispatch §1-§5):

1. When the user explicitly closes the SU-AI-Plugin dialog:
   - if a current transient Derived Workspace exists,
     automatically run the EXISTING discard-workspace path;
   - remove Derived geometry/state;
   - preserve Source CAD completely;
   - clear V1.6 planar-normalization transient proposal/audit
     state as the existing discard contract already requires.

2. Reuse the current discard semantics. Do NOT create a
   second cleanup implementation.

3. Closing the dialog should therefore make the next
   plugin-open session begin cleanly, with the normal
   primary action: `准备处理`.

4. The close cleanup must be fail-safe:
   - must not block SketchUp shutdown/model close;
   - must not raise an unhandled exception from the
     HtmlDialog close callback;
   - if there is no current workspace, closing is a no-op.

5. Do NOT change: Source-of-Truth, Prepare / Discard /
   Rebuild semantics, normalization algorithms, Undo /
   reconciliation architecture, Observer architecture,
   V1.7 scope.

---

## B. Close-time behavior matrix (per dispatch §1-§4)

| State at close   | on_close action                                                                 |
|------------------|----------------------------------------------------------------------------------|
| `none`           | no-op (no current workspace)                                                     |
| `discarded`      | no-op (already discarded)                                                        |
| `building`       | `WorkingModeRunner.discard` (cleanup transient)                                  |
| `ready`          | `WorkingModeRunner.discard` (the primary case — clear derived + V1.5 dup + V1.6 PN) |
| `failed`         | `WorkingModeRunner.discard` (cleanup partial state)                             |

The `WorkingModeRunner.discard` path itself:

1. Calls `_discard_if_present` (which delegates to
   `workspace.discard`). The discard path has its own
   rescue that preserves the prior handle_registry on
   exception.
2. Clears `@duplicate_repair_summary` (V1.5 audit).
3. Clears `@planar_normalization_proposal` +
   `@planar_normalization_audit` (V1.6 transient).
4. The next `prepare()` overwrites `@current_workspace` with
   a fresh `:building` workspace.

Source CAD is NEVER touched by the close path or the
discard path. The next plugin-open session begins with
state='discarded' (or 'none' if the prior state was 'none'),
which per the V16-UI-CN-SIMPLIFICATION-FIX action-state
matrix exposes `准备处理` as the primary CTA.

---

## C. Files changed by this dispatch

Production files modified by this dispatch (1):
- `extension/su_ai_plugin/dialog_runner.rb`:
  - `on_close()` now runs the EXISTING
    `WorkingModeRunner.discard` path BEFORE releasing the
    controller / Loader cache / module-level controller
    handle, IF and only IF the current workspace state is
    in `{building, ready, failed}`. For `none` and
    `discarded` the close is a no-op.
  - The close-time cleanup is wrapped in a
    `begin / rescue StandardError` block that uses the
    existing `_safe_log` to log the error and SWALLOWS the
    exception, so a transient close-time error can NEVER
    block SketchUp shutdown / model close / the HtmlDialog
    close callback (per dispatch §4 fail-safe requirement).
  - The existing discard contract is reused verbatim. NO
    second cleanup implementation is introduced.

Production files NOT modified by this dispatch (the
regression was purely in the dialog close path; the Frozen
Blueprint + V1.6 backend + Simplified Chinese UI surface
+ V1.5 V15PC-002 proposer / executor are unchanged):
- All V1.6 backend files (planar_normalization_*.rb,
  tolerance.rb, analysis_config.rb,
  derived_workspace_adapter.rb,
  su_derived_workspace_adapter.rb, working_mode_runner.rb,
  main.rb).
- `extension/su_ai_plugin/html/app.js`
- `extension/su_ai_plugin/html/index.html`
- `extension/su_ai_plugin/html/style.css`

Test files modified by this dispatch (1):
- `tests/test_dialog_runner.rb`:
  - Added a new `dr_realistic_result` helper that builds an
    `AnalysisResult` with one source edge (so the production
    prepare() path reaches state='ready' instead of 'failed'
    for the empty-source path).
  - Added 7 new V16-CLOSE-AUTODISCARD assertions:
    1. **V16-CLOSE-AUTODISCARD: close with ready workspace
       auto-discards** — the primary case.
    2. **V16-CLOSE-AUTODISCARD: close with no workspace is
       a safe no-op** — close with `state='none'` MUST NOT
       raise.
    3. **V16-CLOSE-AUTODISCARD: close with already-discarded
       workspace is a no-op** — close with `state='discarded'`
       MUST stay in 'discarded'.
    4. **V16-CLOSE-AUTODISCARD: close preserves source
       fingerprint / source geometry** — Source CAD
       invariant: source_snapshot_id + source_fingerprint_digest
       are unchanged by the close-time auto-discard.
    5. **V16-CLOSE-AUTODISCARD: close auto-discard clears
       V1.6 planar_normalization proposal/audit** — the
       existing discard contract requirement: after close,
       the prior compute's proposal/audit MUST be cleared
       (the default safe-empty `NOT_COMPUTED` marker IS
       acceptable, but the stale proposal/audit data is
       NOT).
    6. **V16-CLOSE-AUTODISCARD: reopen after close exposes
       a clean `准备处理` path** — after close+reopen the
       runner state is 'discarded' (which maps to
       `准备处理` per V16-UI-CN-SIMPLIFICATION-FIX).
    7. **V16-CLOSE-AUTODISCARD: close callback is fail-safe
       on transient close-time error** — monkey-patch
       `WorkingModeRunner.discard` to raise; `on_close` MUST
       still complete (swallow the error) AND MUST still
       release the Loader live_dialog cache + the
       module-level current_controller handle.

Governance files updated (3):
- `Prompt/CURRENT_PI_DISPATCH.md` — dispatch ID updated to
  `V16-CLOSE-AUTODISCARD-2026-09-01`; the new scope is
  recorded.
- `CURRENT_STATE.md` — the V16-CLOSE-AUTODISCARD dispatch
  EXECUTION COMPLETE block is added (additive alongside the
  prior V16-UI-CN-SIMPLIFICATION + V16-UI-CN-SIMPLIFICATION-FIX
  + V16-UI-INTEGRATION-CORRECTION blocks).
- This `Review/CURRENT_PI_REPORT.md` is overwritten with the
  V16-CLOSE-AUTODISCARD implementation report (sections A
  through K per dispatch §0-§9).

---

## D. Test evidence

Ruby test suite (powered by `.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`):

- **850 tests PASS / 0 fail / 0 error** (was 843 before
  this dispatch; +7 = the new V16-CLOSE-AUTODISCARD
  assertions).
- dialog_runner substring: **29 / 29 PASS** (was 22 before
  this dispatch; +7 = the new V16-CLOSE-AUTODISCARD
  assertions). All prior V1.0-V1.6 + V1.6 V16 + V1.5
  V15PC + V1.4 + BLOCK-004 + V14-RUNTIME-BLOCK-002 +
  V14-STAGE-BLOCK-001 + V14-RUNTIME-BLOCK-004 assertions
  remain green.
- V16 substring: **26 / 26 PASS** (P1-P9, G1-G6, H1-H6,
  T1-T3, I1-I3) — V1.6 backend behavior is unchanged.
- V15 substring: **149 / 149 PASS** (BLOCK-005 closed,
  duplicate-repair semantics unchanged).
- RBZ smoke substring: **9 / 9 PASS** (package is a valid
  PKZip; entry-point at root; dialog asset trio shipped;
  support folder; dev-only paths excluded; required files
  shipped; install smoke parse + boot).

Node DOM test suite (`tests/test_html_render_dom.js`):

- **307 / 307 PASS** (no change; the JS surface is
  unchanged by this dispatch. 240 existing + 54 new
  CN1-CN18 + 13 V16-FIX = 307 all green).

`git diff --check`: clean (no whitespace / line-ending
issues).

---

## E. RBZ identity

Rebuilt via the existing `scripts/build_rbz.rb`:

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **768,150 bytes** (+3,293 vs prior V16-UI-CN-
  SIMPLIFICATION-FIX RBZ at 764,857 bytes; the delta is
  the close-time auto-discard path in `dialog_runner.rb`
  + 7 new V16-CLOSE-AUTODISCARD Ruby regression tests).
- Entries: **62** (unchanged)
- SHA-256:
  **`7154C6C96759E847CA99A99E9B8B62F88BF230E0741CDFED884586425960BAE7`**
- Packaged `html/app.js` SHA-256:
  **`7CF8A33BF5AE4FE74FDB0E0DA85BAFAB8A2CF4D02B5B72A6B86F6D43A55C30A0`**
  (unchanged from prior V16-UI-CN-SIMPLIFICATION-FIX; the
  close-time auto-discard is a Ruby-side change in
  `dialog_runner.rb`, not a JS change).
- Packaged `html/index.html` SHA-256:
  **`6405DD9EB10A4C4CFCC73CD15AA8B54BC4DAF1D5F631780D7DB6308EAAD6489D`**
  (unchanged from prior V16-UI-CN-SIMPLIFICATION).
- Packaged `html/style.css` SHA-256:
  **`3FAAB5E5C6C9757DDE90D2F984B02F2F357727553232BC7FC70814C7709BB95B`**
  (unchanged from prior V16-UI-CN-SIMPLIFICATION).

The RBZ smoke test (`tests/test_rbz_smoke.rb`) ships the
dialog asset trio (index.html, app.js, style.css) — the
packaged asset SHA-256 hashes match the in-tree hashes
(byte-identical, per the existing smoke-test contract).

Compared to the prior V16-UI-CN-SIMPLIFICATION-FIX RBZ
(SHA-256
`A8326FE595FD4F3E99F63AD43BA7B540422650264FE449F8A2E94F662CA3074F`,
764,857 bytes, 62 entries), this RBZ adds:

- The close-time auto-discard path in
  `extension/su_ai_plugin/dialog_runner.rb` `on_close()`.
- 7 new V16-CLOSE-AUTODISCARD Ruby regression tests in
  `tests/test_dialog_runner.rb` (including the
  fail-safe + source-invariant + reopen-clean-path + V1.6
  PN-clear + realistic-result helper).

The destructive `apply_planar_normalization` callback name
is preserved verbatim in the locked `data-action`
attributes. The Simplified Chinese UI surface is
unchanged.

---

## F. Owner Chinese test instructions (re-affirmed)

The first Owner scenario (after this dispatch lands on
`dev/v1.6` and is merged into `main` per AIPM):

1. 安装最新 RBZ，重启 SketchUp 2020。
2. 选择存在轻微 Z 偏差的线。
3. 打开插件。
4. 点击 `准备处理`。
5. 点击 `检查平面偏差`。
6. 确认显示 `可安全校正`。
7. 点击 `应用平面校正`。
8. 确认工作副本被校正、原始 CAD 不变。

Additional Owner scenario for the discarded-state fix
verification:

1. 安装最新 RBZ，重启 SketchUp 2020。
2. 选择 CAD 打开插件。
3. 点击 `准备处理`。
4. 点击 `放弃工作副本`（在 `更多操作` 块中）。
5. **确认现在显示 `处理工作区 — 工作副本已放弃` 且主操作是
   `准备处理`。**
6. **用一个新的 CAD 选中项替换当前选择。**
7. **点击 `准备处理` — 必须能从当前选择创建新的
   SourceSnapshot + Derived Workspace。**

Additional Owner scenario for the close-autodiscard fix
verification:

1. 安装最新 RBZ，重启 SketchUp 2020。
2. 选择 CAD 打开插件。
3. 点击 `准备处理`。
4. 点击 `检查平面偏差`（或任何其他主操作）。
5. **点击窗口右上角的关闭按钮关闭插件。**
6. **重新打开插件。**
7. **确认现在显示 `准备处理` 作为主操作 — 不需要先手动
   Discard。**

These instructions use ONLY Simplified Chinese labels that
exist in the final RBZ (per dispatch §13 + the prior
V16-UI-CN-SIMPLIFICATION + V16-UI-CN-SIMPLIFICATION-FIX +
V16-UI-INTEGRATION-CORRECTION packets).

---

## G. Remaining real-host unknowns

The following require real SketchUp 2020 Owner verification
of the close-autodiscard fix (per dispatch §9):

- Closing the dialog after `准备处理` → `应用平面校正`
  cleanly transitions to a state that reopens to
  `准备处理`.
- Closing the dialog after a `failed` workspace (e.g. host
  failure during prepare) cleanly transitions to a state
  that reopens to `准备处理`.
- Closing the dialog with the dialog already in `discarded`
  state is truly a no-op.
- Closing the dialog during `building` (in-progress) is
  handled by the fail-safe path.
- A transient close-time error (e.g. dispose failure) does
  NOT block SketchUp shutdown / model close.

Pi is NOT assigned the owner probe and remains STOPPED.

---

## H. Git / network facts

H.1. Local commits:
- 1 stable local commit on the assigned `dev/v1.6`:
  - `fix(v1.6): auto-discard transient workspace on HtmlDialog close
    (Owner UX fix before closure)`
- Branch is `dev/v1.6` (assigned by the dispatch).
- Push: **NOT PUSHED** per dispatch §9 (bounded retry
  against `origin/dev/v1.6` may be attempted from a
  reachable environment; the same RBZ is available on the
  RBZ file system path for the final Owner SU2020
  verification gate regardless).

H.2. Working tree (post-task; pre-push):
- Modified production files (1):
  - `extension/su_ai_plugin/dialog_runner.rb`
- Modified test files (1):
  - `tests/test_dialog_runner.rb`
- Modified governance files (2):
  - `Prompt/CURRENT_PI_DISPATCH.md` (dispatch ID updated to
    `V16-CLOSE-AUTODISCARD-2026-09-01`; scope recorded).
  - `CURRENT_STATE.md` (V16-CLOSE-AUTODISCARD dispatch
    EXECUTION COMPLETE block is added).
- Untracked AIPM Review evidence files preserved (7):
  - `Review/AIPM_V1_5_R5_FUNCTIONAL_DIFF.txt`
  - `Review/AIPM_V1_5_R5_SOURCE_SNAPSHOT.txt`
  - `Review/AIPM_V1_5_R5_TEST_SNAPSHOT.txt`
  - `Review/V3_4_GOVERNANCE_CANONICAL_FILES.txt`
  - `Review/V3_4_GOVERNANCE_CORRECTION_DIFF.txt`
  - `Review/V3_4_GOVERNANCE_MIGRATION_DIFF.txt`
  - `Review/V3_4_PI_APPEND_SYSTEM_FINAL.txt`

H.3. Network / push status:
- Same as the prior V1.6 packets: push attempts are subject
  to the project's bounded network retry rule. GitHub being
  unreachable must not block local completion. Pi remains
  STOPPED awaiting AIPM source review + final Owner
  verification gate.

---

## I. CODEX_TRIGGER

`CODEX_TRIGGER: NO`

Reasoning (per dispatch §9):
- No new architecture was added.
- No new code path beyond the existing `WorkingModeRunner.
  discard` / `on_close` surface in `dialog_runner.rb`.
- The destructive Apply Safe Normalization action wiring
  is unchanged: the visible button label is Simplified
  Chinese, the internal
  `data-action="apply_planar_normalization"` callback
  name is preserved verbatim. The destructive-button
  fail-closed contract (READY_TO_NORMALIZE only) is
  preserved.
- Source / derived ownership, transaction / Undo,
  provenance, tolerance semantics, canonical topology
  semantics — all unchanged.
- The V1.5 duplicate-repair contract — unchanged.
- V1.6 normalization algorithm semantics — unchanged.
- The fix is the smallest possible dialog-close-path
  addition: a single guarded `WorkingModeRunner.discard`
  call in the `on_close()` callback, wrapped in
  `begin / rescue StandardError` + `_safe_log` for
  fail-safe behavior.

No material repo-aware risk that warrants a Codex review.

---

## J. Definition of done (per dispatch §6-§9)

This dispatch is complete:

- [x] ready workspace -> dialog close -> discarded/clean
      state (V16-CLOSE-AUTODISCARD: close with ready
      workspace auto-discards);
- [x] no workspace -> dialog close -> safe no-op
      (V16-CLOSE-AUTODISCARD: close with no workspace is a
      safe no-op);
- [x] already-discarded workspace -> dialog close ->
      no-op (V16-CLOSE-AUTODISCARD: close with already-
      discarded workspace is a no-op);
- [x] source fingerprint / source geometry unchanged
      (V16-CLOSE-AUTODISCARD: close preserves source
      fingerprint / source geometry);
- [x] V1.6 planar_normalization proposal/audit cleared by
      the close-time auto-discard (V16-CLOSE-AUTODISCARD:
      close auto-discard clears V1.6 planar_normalization
      proposal/audit);
- [x] reopening the dialog exposes a clean `准备处理` path
      (V16-CLOSE-AUTODISCARD: reopen after close exposes
      a clean `准备处理` path);
- [x] close cleanup is fail-safe (V16-CLOSE-AUTODISCARD:
      close callback is fail-safe on transient close-time
      error);
- [x] did NOT change Source-of-Truth (no Ruby source
      mutation; the discard contract clears only the
      derived workspace + V1.5 dup summary + V1.6 PN);
- [x] did NOT change Prepare / Discard / Rebuild
      semantics (the close-time path delegates to
      `WorkingModeRunner.discard` verbatim);
- [x] did NOT change normalization algorithms (no V1.6
      backend files touched);
- [x] did NOT change Undo / reconciliation architecture
      (no V14 / V15 Undo path touched);
- [x] did NOT change observer architecture (no
      ModelObserver / EntitiesObserver introduced);
- [x] did NOT start V1.7;
- [x] 7 new focused regression assertions added;
- [x] 307 DOM assertions still PASS unchanged (the JS
      surface is unchanged);
- [x] full Ruby suite: 850/850 PASS;
- [x] RBZ smoke: 9/9 PASS;
- [x] `git diff --check`: clean;
- [x] new RBZ built: path / size / SHA-256 / packaged
      `app.js` SHA-256 / packaged `index.html` SHA-256 /
      packaged `style.css` SHA-256 all reported in section E;
- [x] did NOT invoke Codex;
- [x] did NOT push (GitHub remains unreachable; bounded
      retry allowed from a reachable environment).

Pi STOPPED. Return control to AIPM for direct source review
+ final Owner SU2020 real-host verification gate.