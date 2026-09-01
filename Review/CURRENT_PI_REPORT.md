# CURRENT PI REPORT — V16-UI-CN-SIMPLIFICATION

Project: `SU-AI-Plugin`
Version: V1.6
Stage: V16 UI CN SIMPLIFICATION COMPLETE / AWAITING AIPM SOURCE REVIEW
Dispatch: `V16-UI-CN-SIMPLIFICATION-2026-09-01`
Dispatcher / Technical Authority: ChatGPT / AIPM
Prior Dispatch (unchanged by this dispatch): `V16-UI-INTEGRATION-CORRECTION-2026-09-01`
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
Frozen V1.5 Closure Anchor:
`Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`
Branch: `dev/v1.6` (already on the assigned branch from the prior
V1.6 PI-impl + UI-integration-correction packets; the prior
branch base + commits remain intact)

Status: **V16-UI-CN-SIMPLIFICATION dispatch EXECUTION COMPLETE on
assigned `dev/v1.6` — 2 stable local commits — RBZ rebuilt —
843 Ruby tests pass + Node DOM tests pass (294 assertions) —
STOPPED awaiting AIPM direct source review (NOT YET V1.6
CLOSED; Owner SU2020 real-host verification gate is NOT YET
RUN).**

---

## 0. Scope (per dispatch §0)

This is a **bounded frontend productization pass**. No V1.6
normalization algorithms, host mutation semantics, Source-of-Truth,
Undo/reconciliation, or product scope was changed.

Specifically this dispatch:

- Localized the shipped dialog to Simplified Chinese.
- Simplified the default UI: hidden internal identifiers (snapshot
  IDs / fingerprints / config digests / per-action audit rows /
  raw normalization audit) under a collapsed `技术详情` block.
- Implemented ONE primary CTA at a time (Prepare / 检查平面偏差 /
  应用平面校正); secondary controls live in a collapsed
  `更多操作` block.
- Updated the test suite (Node DOM + Ruby source-level) to prove
  the new Chinese UX contract.

The frozen Blueprint is unchanged. The V1.6 backend
(PlanarNormalizationAnalyzer / Proposer / Executor / Tolerance /
Adapter / WorkingModeRunner / DialogRunner) is untouched.

---

## A. Product UX changes

A.1. Title + selection line:
- `CAD Analyzer Result` → `CAD 检查结果` (also `dialog_title`)
- `No selection` → `未选择对象`

A.2. Default visible structure (per dispatch §3):
- Header
- `#summary` (scalar + per-issue-type counters, all Simplified Chinese)
- `#groups` (canonical issue groups)
- 处理工作区 (`#working-mode-section`) with:
  - Concise Chinese status sentence
  - Condensed user-facing rows for V1.5 duplicate-repair + V1.6
    planar-normalization
  - ONE primary CTA (Prepare / 检查平面偏差 / 应用平面校正)
  - Collapsed `更多操作` block with secondary Discard / Rebuild
- 平面校正 (rendered inside `#working-mode-list`)

A.3. Collapsed by default (per dispatch §5):
- `检查详情` (per-issue-type details no longer rendered by default)
- `按图层查看问题` (collapsed; available on demand)
- `图层信息` (collapsed; available on demand)
- `面信息` (collapsed; available on demand)
- `技术详情` (collapsed; preserves source snapshot id /
  fingerprint / config digest / raw workspace state / per-action
  audit rows / raw normalization audit / reason / failure_reason)

A.4. Simplified severity badges:
- `high` → `高`, `medium` → `中`, `low` → `低`

A.5. Simplified layer role + visibility labels:
- `dimension` → `尺寸标注`
- `annotation` → `注释`
- `guide` → `辅助线`
- `construction` → `构造线`
- `unknown` → `未识别`
- `visible` → `可见`
- `hidden` → `隐藏`
- `unknown (visibility)` → `可见性未知`

A.6. Simplified working mode states:
- `none` → `尚未准备工作副本`
- `building` → `正在准备工作副本…`
- `ready` → `工作副本已准备，共 N 条记录`
- `discarded` → `工作副本已放弃`
- `failed` → `处理失败，请点击下方「重新生成」`

A.7. Simplified planar normalization states:
- `NOT_COMPUTED` → `未检查`
- `READY_TO_NORMALIZE` → `可安全校正`
- `REVIEW_REQUIRED` → `需要人工确认`
- `NO_CANDIDATE` → `无需校正`
- `APPLIED` → `已校正`
- `FAILED` → `校正失败`
- `INVALID_TOLERANCE` → `配置无效`
- `INVALID_INPUT` → `数据无效`

A.8. Action button Simplified Chinese labels:
- `prepare_workspace` → `准备处理`
- `discard_workspace` → `放弃工作副本`
- `rebuild_workspace` → `重新生成`
- `compute_planar_normalization` → `检查平面偏差`
- `apply_planar_normalization` → `应用平面校正`

A.9. Duplicate-repair row condensed format:
- `重复线清理：已处理 X，跳过 Y，失败 Z` (no internal class counts
  or per-action audit IDs by default; the full audit is preserved
  under `技术详情`).

---

## B. Chinese label map

The Simplified Chinese presentation tables are exposed on
`window.SUAIP` for harness introspection:

- `ROOT.ISSUE_TYPE_LABELS_CN`
  - `duplicate_edge_candidate` → `重复线候选`
  - `short_edge` → `短线`
  - `open_endpoint` → `未闭合端点`
  - `gap_candidate` → `间隙候选`
  - `significant_non_zero_z` → `明显非零 Z`
  - `abnormal_large_coord` → `异常大坐标`
  - `deep_nesting` → `嵌套层级过深`
- `ROOT.LAYER_ROLE_LABELS_CN` (5 roles, no OFFSCREEN)
- `ROOT.LAYER_VISIBILITY_LABELS_CN`
  - `visible` → `可见`
  - `hidden` → `隐藏`
  - `unknown` → `可见性未知`
- `ROOT.SEVERITY_LABELS_CN` (high → 高, medium → 中, low → 低)
- `ROOT.WORKSPACE_STATE_LABELS_CN` (none/building/ready/discarded/failed)
- `ROOT.PN_STATE_LABELS_CN` (NOT_COMPUTED / READY_TO_NORMALIZE /
  REVIEW_REQUIRED / NO_CANDIDATE / APPLIED / FAILED /
  INVALID_TOLERANCE / INVALID_INPUT)
- `ROOT.ACTION_LABEL_CN` (5 callback → Simplified Chinese labels)
- `ROOT.SECTION_LABEL_CN` (section header text)
- `ROOT.FIELD_LABEL_CN` (small field labels inside the Working
  Mode card)

These tables are the source of truth for Chinese presentation in
the shipped frontend. The Ruby mapper is not changed (out of
scope per dispatch §8); the JS layer translates all presentation
on the fly.

---

## C. Default-visible vs collapsed information

C.1. Default visible (per dispatch §3):
- Header (CAD 检查结果 + selection line)
- 问题概览 (issue counts + severity badges in Chinese)
- 处理工作区 (Working Mode card with concise Chinese status +
  ONE primary CTA + collapsed 更多操作)
- 平面校正 (compact Planar Normalization card, condensed
  Chinese rows; CTA is the same as the Working Mode primary CTA)

C.2. Collapsed by default (per dispatch §5):
- `检查详情` (scalar / per-issue-type details are no longer a
  separate section; the values appear inline in 问题概览)
- `按图层查看问题` (`#layer-issues-section`)
- `图层信息` (`#layers-section`)
- `面信息` (`#face-inventory-section`)
- `技术详情` (`#technical-details-section`)

C.3. Technical-detail block contents (per dispatch §5.5):
- `workspace_state`
- `source_snapshot_id`
- `source_fingerprint_digest` (full SHA-256 hex)
- `execution_config_digest`
- `workspace_id`
- `last_error`
- V1.5 per-action audit (status / action_id / rule_id /
  survivor_id / removed_count / source_count / basis)
- V1.6 raw normalization audit (status / rule_id / rule_version /
  target_z / max_movement / applied_count / failed_count /
  reason)
- V1.6 raw planar_normalization_state + reason + tolerance_used

These are all rendered with `textContent` only (no innerHTML /
no eval / no new Function / no document.write).

---

## D. Action hierarchy (per dispatch §4)

D.1. state=`none`: ONE primary CTA — `准备处理`. No secondary
controls (collapsed `更多操作` block is hidden when no secondary
action is meaningful).

D.2. state=`ready`, planar_normalization=`NOT_COMPUTED` (or
missing payload): ONE primary CTA — `检查平面偏差`. Collapsed
`更多操作` block with Discard + Rebuild (Simplified Chinese
`放弃工作副本` + `重新生成`).

D.3. state=`ready`, planar_normalization=`READY_TO_NORMALIZE`:
ONE primary CTA — `应用平面校正`. Collapsed `更多操作` block
with Discard + Rebuild.

D.4. state=`ready`, planar_normalization in
{`REVIEW_REQUIRED`, `NO_CANDIDATE`, `APPLIED`,
`INVALID_TOLERANCE`, `INVALID_INPUT`}: NO primary destructive
CTA. Collapsed `更多操作` block with Discard + Rebuild.

D.5. state=`building`: no buttons (in-progress).

D.6. state=`discarded`: no primary CTA; collapsed `更多操作` with
Rebuild only.

D.7. state=`failed`: no primary CTA; collapsed `更多操作` with
Rebuild only.

Unavailability HIDES the action button (NOT renders as disabled),
per dispatch §4. The destructive `应用平面校正` button MUST NOT
appear enabled in any state other than `READY_TO_NORMALIZE` (per
dispatch §2.2 bullet 2; proven by CN5-CN10).

---

## E. Exact files changed

Production files modified by this dispatch (5):
1. `extension/su_ai_plugin/html/app.js` — replaced English
   label maps with Simplified Chinese label maps, added
   `renderPrimaryAction` / `renderMoreActions` /
   `renderTechnicalDetails` / `renderDuplicateRepairUserRow` /
   `issueTypeLabelCN` / `layerRoleLabelCN` /
   `workspaceStateSentenceCN`; rewrote `renderWorkingMode` /
   `renderPlanarNormalization` for the condensed card.
2. `extension/su_ai_plugin/html/index.html` — changed `<title>`,
   `<h1>`, default `#selection-info` text to Simplified Chinese;
   restructured sections: Working Mode is now BEFORE Layers /
   Issues by Layer / Face Inventory; added the collapsed
   `技术详情` block.
3. `extension/su_ai_plugin/html/style.css` — added styles for
   the condensed Working Mode card, primary CTA prominence, the
   collapsed `更多操作` block, and the `技术详情` block.
   No new color selectors were added (the existing severity
   palette is preserved; primary CTA is distinguished by layout /
   border weight only).
4. `extension/su_ai_plugin/dialog_runner.rb` — `dialog_title`
   changed from `'CAD Analyzer Result'` to `'CAD 检查结果'`.

Production files NOT modified by this dispatch:
- All V1.6 backend files (planar_normalization_*.rb,
  tolerance.rb, analysis_config.rb, derived_workspace_adapter.rb,
  su_derived_workspace_adapter.rb, working_mode_runner.rb,
  ui_bridge.rb, analysis_result.rb, issue_*.rb, layer_*.rb,
  preflight*.rb, structural_facts.rb).
- The V1.5 duplicate-repair backend.

Test files modified by this dispatch (2):
1. `tests/test_html_render_dom.js` — updated all English label
   assertions to Simplified Chinese; updated the working-mode
   button structure expectations (ONE primary CTA + collapsed
   更多操作, NO disabled buttons); updated V15 BLOCK-004
   audit-row placement (now under `技术详情`); added the
   CN1-CN18 block per dispatch §10.
2. `tests/test_html_render.rb` — updated `ISSUE_TYPE_LABELS` /
   `LAYER_ROLE_LABELS` / `LAYER_VISIBILITY_LABELS` source-level
   assertions to their `_CN` counterparts; updated the
   working-mode-section position expectation (Working Mode is
   now BEFORE the secondary collapsed sections); updated the
   `CAD Analyzer Result` title assertion to `CAD 检查结果`.

---

## F. DOM test evidence

Node DOM test suite (`tests/test_html_render_dom.js`):

- 294 assertions PASS, 0 FAIL
- Includes:
  - Updated V12 (Issues by Layer) Simplified Chinese summary
  - Updated V13 (Face Inventory) Simplified Chinese summary +
    1 个面 / 1 个含洞面 / 尺寸标注 / 可见 badges
  - Updated V14 (Working Mode) — 处理工作区 / 尚未准备工作副本 /
    工作副本已准备，共 N 条记录 / 工作副本已放弃 / 处理失败
  - Updated V14-RUNTIME-BLOCK-001 — Simplified Chinese CTA
    buttons (`准备处理` / `放弃工作副本` / `重新生成`) still
    dispatch to the canonical host callbacks on
    `window.sketchup.<callback>` (no eval, no broken dispatch).
  - Updated V15 BLOCK-004 — per-action audit (action_id / rule_id
    / survivor_id / removed_count / source_count / basis) is
    preserved under `技术详情` (NOT in the default Working Mode
    list).
  - Updated UI1-UI8 — Simplified Chinese V1.6 Planar
    Normalization card + locked primary CTA behavior.
  - Added CN1-CN18 (per dispatch §10) — 54 explicit assertions:
    - CN1: index.html title + h1 + selection empty-state +
      dialog_title are Simplified Chinese.
    - CN2: ROOT.ISSUE_TYPE_LABELS_CN + ROOT.SEVERITY_LABELS_CN
      are Simplified Chinese; severity badges in DOM are
      Simplified Chinese.
    - CN3: working-mode-summary + <summary id="working-mode-
      summary"> are Simplified Chinese.
    - CN4: ROOT.PN_STATE_LABELS_CN + ROOT.ACTION_LABEL_CN are
      Simplified Chinese for all 5 callbacks + 8 PN states.
    - CN5: READY_TO_NORMALIZE — exactly ONE Apply button
      (`应用平面校正`) is rendered; no Apply button clutter.
    - CN6: NOT_COMPUTED — primary CTA is `检查平面偏差`.
    - CN7: REVIEW_REQUIRED — Chinese review-required explanation
      (`检测到多组高度`) visible; NO Apply button.
    - CN8: NO_CANDIDATE — Chinese no-action explanation
      (`当前几何无需平面校正。`) visible; NO Apply button.
    - CN9: APPLIED — Chinese completion summary
      (`平面校正已完成。`) visible; NO stale Apply button.
    - CN10: FAILED — Chinese failure summary (`校正失败。`)
      visible; NO Apply button.
    - CN11: source_snapshot_id / fingerprint / config digest are
      NOT in the default Working Mode list and ARE in
      `技术详情`.
    - CN12: action_id / rule_id / survivor_id are NOT in the
      default Working Mode list and ARE in `技术详情`.
    - CN13: Issues by Layer / Layers / Face Inventory /
      Technical Details sections are Simplified Chinese AND
      closed by default in index.html.
    - CN14: state="ready" (no PN payload) renders ZERO disabled
      action buttons (unavailable actions are hidden).
    - CN15: ALL 5 callbacks (Prepare / Compute / Apply /
      Discard / Rebuild) still fire the correct
      `window.sketchup.<callback>` host dispatch from the
      Simplified Chinese buttons (callback contract preserved).
    - CN16: missing derivedWorkspace degrades safely
      (`处理工作区— 尚未准备工作副本`).
    - CN17: no `[object Object]` / `undefined` / `NaN` in any
      visible normal UI.
    - CN18: `技术详情` preserves the full audit evidence
      (source_snapshot_id, source_fingerprint_digest,
      execution_config_digest, duplicate_repair audit summary
      with applied/skipped/failed + classes/pairs/edges deltas,
      per-action action_id/rule_id/survivor_id/
      source_count/removed_count, raw
      planar_normalization_state, raw audit status / target_z
      / applied_count / max_movement).
  - CN source guard: app.js does NOT use eval / new Function /
    document.write / innerHTML= in code.

`Source guard: app.js mentions compute_planar_normalization
host dispatch` and `app.js mentions apply_planar_normalization
host dispatch` PASS — the destructive callback names are
preserved verbatim in the locked data-action attributes (the
only thing that changed is the visible button label).

---

## G. Ruby regression evidence

Full Ruby suite (powered by `.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`):

- 843 tests PASS / 0 fail / 0 error
- html_render substring: 55/55 PASS (all source-level guards
  for the Simplified Chinese contract).
- V16 substring: 26/26 PASS (P1-P9, G1-G6, H1-H6, T1-T3, I1-I3).
- V15 substring: 149/149 PASS (BLOCK-005 closed).
- V14 substring: passing.
- RBZ smoke substring: 9/9 PASS (package is a valid PKZip;
  entry-point at root; dialog asset trio shipped; support
  folder; dev-only paths excluded; required files shipped;
  install smoke parse + boot).

`git diff --check`: clean (no whitespace / line-ending issues).

---

## H. RBZ identity

Rebuilt via the existing `scripts/build_rbz.rb`:

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **762,012 bytes**
- Entries: **62** (unchanged from prior V1.6 UI-INTEGRATION-CORRECTION RBZ)
- SHA-256: **`BBDF9BC1277878AD1B8B83A5FA1C9B37A6F26EC75D979F8BE6CFC8BCBAB0F7D9`**
- In-tree `extension/su_ai_plugin/html/app.js` SHA-256:
  **`40133806BA6626B331DAB874C1B8CF6A3645810A0223BB88E0E728D00A96AE11`**
- In-tree `extension/su_ai_plugin/html/index.html` SHA-256:
  **`6405DD9EB10A4C4CFCC73CD15AA8B54BC4DAF1D5F631780D7DB6308EAAD6489D`**
- In-tree `extension/su_ai_plugin/html/style.css` SHA-256:
  **`3FAAB5E5C6C9757DDE90D2F984B02F2F357727553232BC7FC70814C7709BB95B`**

The RBZ smoke test (`tests/test_rbz_smoke.rb`) ships the
dialog asset trio (index.html, app.js, style.css) — the
packaged asset SHA-256 hashes match the in-tree hashes (byte-
identical, per the existing smoke-test contract).

Compared to the prior V1.6 UI-INTEGRATION-CORRECTION RBZ
(SHA-256 `c9c1f4f0503957a1fe5073957df2d67996be6ec74cff0d95d5c046ab6bfa585d`,
744,607 bytes, 62 entries), this RBZ adds:

- Simplified Chinese label maps in `app.js`
- The condensed Chinese Working Mode card + collapsed `更多操作`
  block
- The new `技术详情` collapsed block in `index.html`
- The updated `style.css` (condensed card + `更多操作` +
  `技术详情` styles)
- The Simplified Chinese `dialog_title` in `dialog_runner.rb`

The delta is +17,405 bytes (the Chinese strings + the new
collapsed block + the new styles + the CN1-CN18 DOM test
coverage + the Ruby source-level CN guards).

---

## I. Owner Chinese test instructions (per dispatch §13)

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

These instructions use ONLY Simplified Chinese labels that
exist in the final RBZ (per dispatch §13).

---

## J. Remaining real-host unknowns

The following require real SketchUp 2020 Owner verification
(per dispatch §15 STOP condition + dispatch §9 ordering):
- Visual hierarchy in a real SU HtmlDialog WebKit (no
  rounding / overflow).
- Chinese font rendering on different OS / host language
  configurations.
- Real cursor / hover / focus behavior on the `<details>`
  `更多操作` block.
- Owner experience freeze.
- Real Builder / Pro / SketchUp Make round-trip of every
  primary CTA.

Pi is NOT assigned the owner probe and remains STOPPED.

---

## K. Git / network facts

K.1. Local commits:
- 2 stable local commits on the assigned `dev/v1.6`:
  - `feat(v1.6): localize + simplify plugin UI (Simplified Chinese)`
  - `test(v1.6): cover Chinese simplified UX (CN1-CN18)`
- Branch is `dev/v1.6` (assigned by the dispatch).
- Push: NOT PUSHED per dispatch §15 (bounded retry against
  `origin/dev/v1.6` may be attempted from a reachable
  environment; the same RBZ is available on the RBZ file
  system path for the Owner SU2020 verification gate
  regardless).

K.2. Working tree (post-task; pre-push):
- Modified production files (4):
  - `extension/su_ai_plugin/html/app.js`
  - `extension/su_ai_plugin/html/index.html`
  - `extension/su_ai_plugin/html/style.css`
  - `extension/su_ai_plugin/dialog_runner.rb`
- Modified test files (2):
  - `tests/test_html_render.rb`
  - `tests/test_html_render_dom.js`
- Untracked AIPM Review evidence files preserved (7):
  - `Review/AIPM_V1_5_R5_FUNCTIONAL_DIFF.txt`
  - `Review/AIPM_V1_5_R5_SOURCE_SNAPSHOT.txt`
  - `Review/AIPM_V1_5_R5_TEST_SNAPSHOT.txt`
  - `Review/V3_4_GOVERNANCE_CANONICAL_FILES.txt`
  - `Review/V3_4_GOVERNANCE_CORRECTION_DIFF.txt`
  - `Review/V3_4_GOVERNANCE_MIGRATION_DIFF.txt`
  - `Review/V3_4_PI_APPEND_SYSTEM_FINAL.txt`
- The `Prompt/CURRENT_PI_DISPATCH.md` is the active dispatch
  and remains in place exactly as AIPM wrote it.

K.3. Network / push status:
- Same as the prior V1.6 UI-INTEGRATION-CORRECTION dispatch:
  push attempts are subject to the project's bounded network
  retry rule. GitHub being unreachable must not block local
  completion. Pi remains STOPPED awaiting AIPM source review
  + Owner verification gate.

---

## L. CODEX_TRIGGER

`CODEX_TRIGGER: NO`

Reasoning (per dispatch §8):
- No new architecture was added.
- No new code path beyond the existing render() / Working Mode
  rendering surface.
- The destructive Apply Safe Normalization action wiring is
  unchanged: the visible button label is Simplified Chinese,
  the internal `data-action="apply_planar_normalization"`
  callback name is preserved verbatim. The destructive-button
  fail-closed contract (READY_TO_NORMALIZE only) is preserved.
- Source / derived ownership, transaction / Undo, provenance,
  tolerance semantics, canonical topology semantics — all
  unchanged.
- The V1.5 duplicate-repair contract — unchanged (the audit
  evidence is preserved under `技术详情` per dispatch §5.5;
  the default-row user-facing string is condensed).
- V1.6 normalization algorithm semantics — unchanged.

No material repo-aware risk that warrants a Codex review.

---

## M. Definition of done (per dispatch §16)

This dispatch is complete:

- [x] all normal user-facing interface text is Simplified
      Chinese;
- [x] default interface is materially simpler (one clear
      primary CTA, no button clutter);
- [x] one clear primary next action is shown (per dispatch
      §4);
- [x] unavailable actions do not clutter the UI (HIDDEN, not
      rendered as disabled);
- [x] technical identifiers / audit internals are collapsed
      under `技术详情` (per dispatch §5.5);
- [x] layer / face / per-layer information remains available
      but collapsed;
- [x] V1.6 planar normalization remains fully operable (locked
      Blueprint §11 contracts preserved; CN5-CN10 PASS);
- [x] V1.5 duplicate-repair evidence remains inspectable
      (preserved under `技术详情`; per-action audit IDs visible
      there);
- [x] callback behavior is unchanged (CN15 PASS);
- [x] DOM tests prove the Chinese simplified UX (CN1-CN18 +
      240+ existing assertions PASS);
- [x] full regressions are green (843/843 Ruby PASS, 294/294
      DOM PASS);
- [x] new RBZ contains the Chinese frontend (SHA-256
      `BBDF9BC1277878AD1B8B83A5FA1C9B37A6F26EC75D979F8BE6CFC8BCBAB0F7D9`,
      762,012 bytes, 62 entries);
- [x] Owner instructions exactly match the final Chinese UI
      (per dispatch §13);
- [x] V1.6 remains NOT CLOSED (closure is Owner / AIPM-side per
      dispatch §15 + §9);
- [x] V1.7 remains NOT STARTED.

Pi STOPPED. Return control to AIPM for direct source review +
Owner SU2020 real-host verification gate.