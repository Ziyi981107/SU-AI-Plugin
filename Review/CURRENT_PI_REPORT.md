# CURRENT PI REPORT — V16-UI-CN-SIMPLIFICATION-FIX

Project: `SU-AI-Plugin`
Version: V1.6
Stage: V16 UI CN SIMPLIFICATION FIX COMPLETE / AWAITING AIPM SOURCE REVIEW
Dispatch: `V16-UI-CN-SIMPLIFICATION-FIX-2026-09-01`
Dispatcher / Technical Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Prior Dispatch (unchanged by this fix): `V16-UI-CN-SIMPLIFICATION-2026-09-01`
Prior Prior Dispatch (unchanged): `V16-UI-INTEGRATION-CORRECTION-2026-09-01`
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
Frozen V1.5 Closure Anchor:
`Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`
Branch: `dev/v1.6`

Status: **V16-UI-CN-SIMPLIFICATION-FIX dispatch EXECUTION
COMPLETE on assigned `dev/v1.6` — 1 stable local commit —
RBZ rebuilt — 843 Ruby tests pass + 307 Node DOM assertions
pass — STOPPED awaiting AIPM direct source review (NOT YET
V1.6 CLOSED; Owner SU2020 real-host verification gate is
NOT YET RUN).**

---

## 0. Scope (per dispatch §0)

This is a **bounded frontend regression fix** within the
already-active V16-UI-CN-SIMPLIFICATION dispatch. No V1.6
normalization algorithms, host mutation semantics,
Source-of-Truth, Undo/reconciliation, transaction,
provenance, or observer architecture was changed.

Specifically this dispatch:

- Fixed the Owner real-host regression: in workspace state
  `discarded` (and `failed`, by the "same class of mistake"
  review), the primary CTA is now `准备处理` so the user can
  create a fresh SourceSnapshot + Derived Workspace from a
  NEW selection.
- Kept `重新生成` as a secondary action under `更多操作` for
  replaying the previously captured workspace.
- Added 13 new DOM regression assertions covering the
  `discarded` + `failed` state primary CTA dispatch.
- Did NOT change V1.6 backend semantics (no Prepare /
  Discard / Rebuild contract change, no Source-of-Truth
  change, no Undo / transaction / provenance / observer
  change).

The frozen V1.6 Blueprint + the V1.6 backend (Planar
Normalization analyzer / proposer / executor / tolerance /
adapter / WorkingModeRunner / DialogRunner) are unchanged.

---

## A. Owner real-host finding (per dispatch §0)

> After the previous workspace is discarded, Working Mode
> shows “处理工作区 — 工作副本已放弃” but the UI exposes only
> “更多操作 -> 重新生成” and does NOT expose “准备处理”. This
> is incorrect.
>
> After Discard, the user may select a NEW CAD/source
> selection and must be able to create a fresh SourceSnapshot
> + Derived Workspace from the CURRENT selection.
>
> Rebuild is not a substitute for Prepare because it may
> rebuild from the previously captured workspace/source
> state.

Root cause: the prior `renderPrimaryAction()` function had
no branch for `discarded` or `failed` — those states fell
through to the default "no primary CTA" path, leaving only
`更多操作 -> 重新生成` exposed.

---

## B. Action-state matrix (per dispatch §5)

| Workspace state | Primary CTA (top-level)      | Secondary in `更多操作`  |
|-----------------|------------------------------|---------------------------|
| `none`          | `准备处理`                    | (none)                    |
| `discarded`     | `准备处理` (Owner fix)         | `重新生成`                |
| `failed`        | `准备处理` (Owner fix)         | `重新生成`                |
| `ready` + `NOT_COMPUTED` | `检查平面偏差`         | `放弃工作副本` + `重新生成` |
| `ready` + `READY_TO_NORMALIZE` | `应用平面校正`    | `放弃工作副本` + `重新生成` |
| `ready` + (`REVIEW_REQUIRED` / `NO_CANDIDATE` / `APPLIED` / `FAILED` / `INVALID_*`) | (none) | `放弃工作副本` + `重新生成` |
| `building`      | (none; in-progress)          | (none)                    |

Constraints preserved from prior packet:

- The destructive `应用平面校正` button is rendered ONLY when
  `workspaceState === 'ready'` AND `pnState === 'READY_TO_NORMALIZE'`.
- Unavailable actions are HIDDEN, NOT rendered as disabled
  buttons (zero disabled buttons in any state).
- All five host callbacks (`prepare_workspace` /
  `discard_workspace` / `rebuild_workspace` /
  `compute_planar_normalization` /
  `apply_planar_normalization`) are still routed to the
  correct `window.sketchup.<callback>` from the Simplified
  Chinese button text.

The `discarded` + `failed` change is intentionally symmetric
because both states share the same product reason: the user
may have moved on to a NEW selection and must be able to
create a fresh SourceSnapshot.

---

## C. Files changed by this dispatch

Production files modified by this dispatch (1):
- `extension/su_ai_plugin/html/app.js`:
  - `renderPrimaryAction()` now emits `准备处理` (data-
    action="prepare_workspace") for `none`, `discarded`, and
    `failed` workspace states.
  - The `ready` branch is unchanged.
  - The `building` branch is unchanged (no buttons).
  - `renderMoreActions()` is unchanged in code; the
    `discarded` + `failed` branches already showed `重新生成`
    as a secondary control. Now `准备处理` is the primary
    CTA on top + `重新生成` is the secondary under `更多操作`.

Production files NOT modified by this dispatch (the
regression was purely in the simplified action-state
matrix; the Frozen Blueprint + V1.6 backend + non-Working-
Mode UI surfaces are unchanged):
- `planar_normalization_analyzer.rb`,
  `planar_normalization_proposer.rb`,
  `planar_normalization_executor.rb`, `tolerance.rb`,
  `analysis_config.rb`, `derived_workspace_adapter.rb`,
  `su_derived_workspace_adapter.rb`, `working_mode_runner.rb`,
  `dialog_runner.rb`, `main.rb`
- `extension/su_ai_plugin/html/index.html`
- `extension/su_ai_plugin/html/style.css`

Test files modified by this dispatch (1):
- `tests/test_html_render_dom.js`:
  - 13 new V16-FIX assertions covering the `discarded` and
    `failed` state primary CTA dispatch.

Governance files updated (2):
- `Prompt/CURRENT_PI_DISPATCH.md` — dispatch ID updated to
  `V16-UI-CN-SIMPLIFICATION-FIX-2026-09-01` and the new
  scope is recorded.
- `CURRENT_STATE.md` — V16-UI-CN-SIMPLIFICATION-FIX dispatch
  EXECUTION COMPLETE block is added (additive alongside the
  prior V16-UI-CN-SIMPLIFICATION + V16-UI-INTEGRATION-
  CORRECTION blocks).

---

## D. DOM test evidence

Node DOM test suite (`tests/test_html_render_dom.js`):

- 307 assertions PASS, 0 FAIL (294 existing + 13 new V16-FIX)
- The 13 new V16-FIX assertions:
  - **V16-FIX: discarded state primary CTA is Simplified
    Chinese "准备处理" (Owner real-host fix)**
    Confirms: state="discarded" -> top-level action button
    text === '准备处理', data-action ===
    'prepare_workspace', NO disabled attribute.
  - **V16-FIX: discarded state 更多操作 block contains
    "重新生成" as secondary action**
    Confirms: secondary `重新生成` (data-action ===
    'rebuild_workspace') is present and enabled inside the
    collapsed 更多操作 block.
  - **V16-FIX: discarded state does NOT render
    "放弃工作副本" (already discarded)**
    Confirms: no Discard button is rendered anywhere in
    state="discarded" (the workspace is already discarded).
  - **V16-FIX: discarded state renders ZERO disabled
    buttons (unavailable actions are HIDDEN, not disabled)**
    Confirms: the one-primary-action rule + no-disabled-
    button rule is preserved.
  - **V16-FIX: clicking "准备处理" in discarded state calls
    prepare_workspace EXACTLY ONCE**
  - **V16-FIX: clicking "准备处理" in discarded state does
    NOT call rebuild_workspace**
  - **V16-FIX: clicking "准备处理" in discarded state does
    NOT call discard_workspace**
  - **V16-FIX: clicking "重新生成" (secondary) in discarded
    state calls rebuild_workspace EXACTLY ONCE**
  - **V16-FIX: clicking "重新生成" (secondary) in discarded
    state does NOT call prepare_workspace**
  - **V16-FIX: failed state primary CTA is Simplified
    Chinese "准备处理" (Owner real-host fix)** (same class
    of mistake, by symmetry)
  - **V16-FIX: failed state 更多操作 block contains
    "重新生成" as secondary action**
  - **V16-FIX: clicking "准备处理" in failed state calls
    prepare_workspace EXACTLY ONCE**
  - **V16-FIX: clicking "准备处理" in failed state does NOT
    call rebuild_workspace**

All 240+ prior V12 / V13 / V14 / V14-RUNTIME-BLOCK-001 / V15 /
V15 BLOCK-004 / UI1-UI8 / CN1-CN18 assertions still pass
unchanged (no regression in the existing V1.6 UI-CN-
SIMPLIFICATION contract).

---

## E. Ruby regression evidence

Full Ruby suite (powered by `.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`):

- 843 tests PASS / 0 fail / 0 error (no Ruby-side change was
  required for this UI fix; the Ruby regression suite covers
  the existing V1.6 backend contract, which is unchanged).
- html_render substring: 55/55 PASS (no source-level change
  was required; the CN guards remain green).
- V16 substring: 26/26 PASS (P1-P9, G1-G6, H1-H6, T1-T3, I1-I3)
  — V1.6 backend behavior is unchanged.
- V15 substring: 149/149 PASS (BLOCK-005 closed, duplicate-
  repair semantics unchanged).
- RBZ smoke substring: 9/9 PASS (package is a valid PKZip;
  entry-point at root; dialog asset trio shipped; support
  folder; dev-only paths excluded; required files shipped;
  install smoke parse + boot).

`git diff --check`: clean (no whitespace / line-ending
issues).

---

## F. RBZ identity

Rebuilt via the existing `scripts/build_rbz.rb`:

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **764,857 bytes** (+2,845 vs prior V16-UI-CN-
  SIMPLIFICATION RBZ at 762,012 bytes; the delta is the
  `discarded` + `failed` state primary CTA fix in `app.js`
  + the V16-FIX DOM regression tests).
- Entries: **62** (unchanged)
- SHA-256:
  **`A8326FE595FD4F3E99F63AD43BA7B540422650264FE449F8A2E94F662CA3074F`**
- Packaged `html/app.js` SHA-256:
  **`7CF8A33BF5AE4FE74FDB0E0DA85BAFAB8A2CF4D02B5B72A6B86F6D43A55C30A0`**
  (changed from prior V16-UI-CN-SIMPLIFICATION
  `40133806BA6626B331DAB874C1B8CF6A3645810A0223BB88E0E728D00A96AE11`).
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

Compared to the prior V16-UI-CN-SIMPLIFICATION RBZ (SHA-256
`BBDF9BC1277878AD1B8B83A5FA1C9B37A6F26EC75D979F8BE6CFC8BCBAB0F7D9`,
762,012 bytes, 62 entries), this RBZ adds the
`renderPrimaryAction` correction for `discarded` + `failed`
states + the V16-FIX DOM regression assertions. The
destructive `apply_planar_normalization` callback name is
preserved verbatim in the locked `data-action` attributes.

---

## G. Owner Chinese test instructions (re-affirmed)

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
   `准备处理`（不是 `重新生成`）。**
6. **用一个新的 CAD 选中项替换当前选择。**
7. **点击 `准备处理` — 必须能从当前选择创建新的 SourceSnapshot
   + Derived Workspace。**

These instructions use ONLY Simplified Chinese labels that
exist in the final RBZ (per dispatch §13 + this regression-
fix dispatch).

---

## H. Remaining real-host unknowns

The following require real SketchUp 2020 Owner verification
(per dispatch §15 STOP condition + the regression-fix
dispatch §8 ordering):
- Visual hierarchy in a real SU HtmlDialog WebKit (no
  rounding / overflow) for the new primary CTA in
  `discarded` + `failed` states.
- Chinese font rendering on different OS / host language
  configurations.
- Real cursor / hover / focus behavior on the `<details>`
  `更多操作` block when the primary CTA above it is
  `准备处理` (instead of `检查平面偏差` or `应用平面校正`).
- Owner experience freeze.
- Real Builder / Pro / SketchUp Make round-trip of every
  primary CTA, including the new `准备处理` primary CTA in
  `discarded` + `failed` states.

Pi is NOT assigned the owner probe and remains STOPPED.

---

## I. Git / network facts

I.1. Local commits:
- 1 stable local commit on the assigned `dev/v1.6`:
  - `fix(v1.6): show 准备处理 as primary CTA in discarded / failed
    workspace states (Owner real-host regression fix)`
- Branch is `dev/v1.6` (assigned by the dispatch).
- Push: **NOT PUSHED** per dispatch §8 (bounded retry
  against `origin/dev/v1.6` may be attempted from a
  reachable environment; the same RBZ is available on the
  RBZ file system path for the Owner SU2020 verification
  gate regardless).

I.2. Working tree (post-task; pre-push):
- Modified production files (1):
  - `extension/su_ai_plugin/html/app.js`
- Modified test files (1):
  - `tests/test_html_render_dom.js`
- Modified governance files (1):
  - `Prompt/CURRENT_PI_DISPATCH.md` (dispatch ID updated to
    `V16-UI-CN-SIMPLIFICATION-FIX-2026-09-01`; scope recorded).
- Untracked AIPM Review evidence files preserved (7):
  - `Review/AIPM_V1_5_R5_FUNCTIONAL_DIFF.txt`
  - `Review/AIPM_V1_5_R5_SOURCE_SNAPSHOT.txt`
  - `Review/AIPM_V1_5_R5_TEST_SNAPSHOT.txt`
  - `Review/V3_4_GOVERNANCE_CANONICAL_FILES.txt`
  - `Review/V3_4_GOVERNANCE_CORRECTION_DIFF.txt`
  - `Review/V3_4_GOVERNANCE_MIGRATION_DIFF.txt`
  - `Review/V3_4_PI_APPEND_SYSTEM_FINAL.txt`

I.3. Network / push status:
- Same as the prior V1.6 packets: push attempts are subject
  to the project's bounded network retry rule. GitHub being
  unreachable must not block local completion. Pi remains
  STOPPED awaiting AIPM source review + Owner verification
  gate.

---

## J. CODEX_TRIGGER

`CODEX_TRIGGER: NO`

Reasoning (per dispatch §8):
- No new architecture was added.
- No new code path beyond the existing `renderPrimaryAction`
  / `renderMoreActions` surface in the simplified renderer.
- The destructive Apply Safe Normalization action wiring is
  unchanged: the visible button label is Simplified Chinese,
  the internal `data-action="apply_planar_normalization"`
  callback name is preserved verbatim. The destructive-button
  fail-closed contract (READY_TO_NORMALIZE only) is preserved.
- Source / derived ownership, transaction / Undo, provenance,
  tolerance semantics, canonical topology semantics — all
  unchanged.
- The V1.5 duplicate-repair contract — unchanged.
- V1.6 normalization algorithm semantics — unchanged.
- The fix is the smallest possible UI matrix correction
  needed to satisfy the Owner real-host finding: in
  `discarded` + `failed` workspace states, the primary CTA is
  `准备处理` so the user can create a fresh SourceSnapshot
  from a NEW selection. `重新生成` remains available as a
  secondary action under `更多操作` for replaying the
  previously captured workspace.

No material repo-aware risk that warrants a Codex review.

---

## K. Definition of done (per dispatch §6 + §7)

This dispatch is complete:

- [x] workspace state `discarded` shows `准备处理` as the
      PRIMARY CTA (V16-FIX: discarded state primary CTA is
      Simplified Chinese "准备处理");
- [x] clicking `准备处理` dispatches exactly
      `window.sketchup.prepare_workspace` (V16-FIX: clicking
      "准备处理" in discarded state calls prepare_workspace
      EXACTLY ONCE; does NOT call rebuild_workspace; does
      NOT call discard_workspace);
- [x] `重新生成` remains a secondary action under `更多操作`
      in `discarded` state (V16-FIX: discarded state 更多操作
      block contains "重新生成" as secondary action);
- [x] no regression to the one-primary-action rule (V16-FIX:
      discarded state renders ZERO disabled buttons);
- [x] the action-state matrix is reviewed for the same class
      of mistake (per dispatch §5): `none` -> 准备处理;
      `discarded` -> 准备处理 (primary) + 重新生成 (secondary);
      `ready + NOT_COMPUTED` -> 检查平面偏差;
      `ready + READY_TO_NORMALIZE` -> 应用平面校正;
      destructive Apply unavailable in all other states. The
      `failed` state was identified as the same class of
      mistake and is fixed by the same change (primary CTA
      = 准备处理; secondary 重新生成);
- [x] backend Prepare / Discard / Rebuild semantics NOT
      changed (no Ruby production code changed);
- [x] V1.6 normalization algorithms NOT changed (no V1.6
      backend files touched);
- [x] Source-of-Truth, Undo/reconciliation, transaction,
      provenance, observer architecture NOT changed;
- [x] 13 new DOM regression assertions (V16-FIX) added
      covering the `discarded` + `failed` state primary CTA
      dispatch;
- [x] existing 294 DOM assertions still PASS unchanged
      (CN1-CN18 + UI1-UI8 + L4 + V12 + V13 + V14 + V15 +
      V15 BLOCK-004 all green);
- [x] full Ruby suite: 843/843 PASS (no Ruby-side change
      required);
- [x] focused V1.6 tests: 26/26 PASS (V1.6 backend behavior
      unchanged);
- [x] Node DOM tests: 307/307 PASS;
- [x] RBZ smoke: 9/9 PASS;
- [x] `git diff --check`: clean;
- [x] new RBZ built: path / size / SHA-256 / packaged
      `app.js` SHA-256 / packaged `index.html` SHA-256 /
      packaged `style.css` SHA-256 all reported in section F;
- [x] did NOT push (GitHub remains unreachable; bounded
      retry allowed from a reachable environment);
- [x] did NOT start V1.7;
- [x] did NOT invoke Codex.

Pi STOPPED. Return control to AIPM for direct source review
+ Owner SU2020 real-host verification gate.