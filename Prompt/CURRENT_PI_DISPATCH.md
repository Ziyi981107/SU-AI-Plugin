# CURRENT PI DISPATCH

DISPATCH_ID: V16-CLOSE-AUTODISCARD-2026-09-01
STATUS: ACTIVE
PROJECT: SU-AI-Plugin
STAGE: V1.6 — Planar Normalization / Z Policy (close UX fix)
TARGET_BRANCH: dev/v1.6

Dispatcher / Product + Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

FROZEN V1.6 BLUEPRINT:
Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md

PRIOR ACCEPTED DISPATCHES (history):
- V16-UI-CN-SIMPLIFICATION-FIX-2026-09-01 (主 UX 修正; COMPLETE)
- V16-UI-CN-SIMPLIFICATION-2026-09-01 (主 UX pass; COMPLETE)
- V16-UI-INTEGRATION-CORRECTION-2026-09-01 (PRIOR ACCEPTED FUNCTIONAL UI INTEGRATION)

---

# 0. SCOPE — BOUNDED CLOSE-CLEANUP UX FIX (V16-CLOSE-AUTODISCARD)

Owner real-host verification A-E of the V16-UI-CN-SIMPLIFICATION
+ V16-UI-CN-SIMPLIFICATION-FIX RBZ has PASSED.

NEW Owner UX finding (per dispatch §1):

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

2. Reuse the current discard semantics. Do NOT create a second
   cleanup implementation.

3. Closing the dialog should therefore make the next
   plugin-open session begin cleanly, with the normal primary
   action: `准备处理`.

4. The close cleanup must be fail-safe:
   - must not block SketchUp shutdown/model close;
   - must not raise an unhandled exception from the HtmlDialog
     close callback;
   - if there is no current workspace, closing is a no-op.

5. Do NOT change:
   - Source-of-Truth
   - Prepare / Discard / Rebuild semantics
   - normalization algorithms
   - Undo/reconciliation architecture
   - Observer architecture
   - V1.7 scope

6. Add focused regression evidence for:
   - ready workspace -> dialog close -> discarded/clean state;
   - no workspace -> dialog close -> safe no-op;
   - source fingerprint/source geometry unchanged;
   - reopening the dialog exposes a clean `准备处理` path.

7. Run focused tests + full Ruby + DOM if affected + RBZ smoke
   + git diff --check.

8. Rebuild RBZ.

9. Report new RBZ SHA-256.

Do NOT invoke Codex. Do NOT start V1.7. Do NOT push if
GitHub remains unreachable. STOP after the bounded fix.

This is a small continuation inside the already-ACTIVE
V1.6 dispatch window. The change is purely in the dialog
close path (no architecture, no Source-of-Truth, no
Undo, no observers, no V1.7).

After this fix the next Gate remains: Owner / AIPM SketchUp
2020 V1.6 real-host verification. Do NOT run Owner
verification on behalf of Owner.

---

# 0. SCOPE — BOUNDED UX REGRESSION FIX (V16-UI-CN-SIMPLIFICATION-FIX, history)

Owner real-host testing of the V16-UI-CN-SIMPLIFICATION RBZ
found ONE concrete workflow blocker:

After the previous workspace is discarded, Working Mode shows
“处理工作区 — 工作副本已放弃” but the UI exposes only
“更多操作 -> 重新生成” and does NOT expose “准备处理”.
This is incorrect: after Discard, the user may select a NEW
CAD/source selection and must be able to create a fresh
SourceSnapshot + Derived Workspace from the CURRENT selection.
Rebuild is not a substitute for Prepare because it may rebuild
from the previously captured workspace/source state.

This dispatch performs ONE bounded frontend correction to fix
this regression. Do NOT change backend semantics / V1.6
normalization algorithms / Source-of-Truth / Undo /
transaction / provenance / observer architecture.

After this fix the next Gate remains: Owner / AIPM SketchUp
2020 V1.6 real-host verification. Do NOT run Owner
verification on behalf of Owner. Do NOT start V1.7. Do NOT
invoke Codex.

---

# 0. OWNER DECISION

Before Owner SU2020 real-host verification, perform ONE bounded frontend
productization pass.

Owner requirements:

1. The user-facing interface must be Simplified Chinese.
2. The default UI must be much simpler.
3. Technical/debug information that normal users do not need must NOT dominate
   the screen.
4. Secondary / diagnostic information may remain available through collapsed
   detail sections.
5. Do not change V1.6 normalization algorithms, host mutation semantics,
   Source-of-Truth, Undo/reconciliation, or product scope.

This is a PRODUCT UX correction, not an architecture rewrite.

After this dispatch the next Gate remains:

Owner / AIPM SketchUp 2020 V1.6 real-host verification.

Do NOT run Owner verification on behalf of Owner.
Do NOT start V1.7.
Do NOT invoke Codex unless a genuinely new architectural blocker appears.

---

# 1. UX PRINCIPLE

The plugin is for architectural CAD preparation, not for debugging the internal
pipeline.

Default screen should answer only four user questions:

1. 当前选中的 CAD 有没有问题？
2. 工作副本现在是什么状态？
3. 系统建议我做什么？
4. 我现在可以点哪个按钮？

Everything else is secondary.

Use:

PRIMARY ACTION
→ current recommended next action

SECONDARY ACTIONS
→ safe operational controls

TECHNICAL DETAILS
→ collapsed by default

Do not make normal users read:
- snapshot IDs
- fingerprint hashes
- config digests
- rule IDs
- action IDs
- survivor IDs
- source occurrence counts
- internal state enum names
- raw audit rows
unless they deliberately expand technical details.

---

# 2. LANGUAGE — SIMPLIFIED CHINESE

All normal user-facing text in the shipped dialog must be Simplified Chinese.

Do NOT translate internal data identifiers in storage / API contracts.
Translate only presentation.

## 2.1 Main title

`CAD Analyzer Result`
→ `CAD 检查结果`

`No selection`
→ `未选择对象`

## 2.2 Core summary labels

Use concise Chinese:

- Edges → 线段
- Vertices → 顶点
- Faces → 面
- Faces With Holes → 含洞面
- Non Zero Z Vertices → 非零 Z 顶点
- Warnings → 警告

Avoid exposing zero-value technical counters in the default primary summary if
they add no user value.

## 2.3 Issue type labels

At minimum:

- duplicate_edge_candidate → 重复线候选
- short_edge → 短线
- open_endpoint → 未闭合端点
- gap_candidate → 间隙候选
- significant_non_zero_z → 明显非零 Z
- abnormal_large_coord → 异常大坐标
- deep_nesting → 嵌套层级过深

Severity:
- high → 高
- medium → 中
- low → 低

Standard known issue descriptions should be presented in Chinese where the
frontend can map them deterministically.

Do not invent Chinese meaning for unknown backend messages.
Unknown/unmapped messages may appear under technical details rather than
polluting the primary UX.

## 2.4 Layer / visibility labels

- Layers → 图层
- Issues by Layer → 按图层查看问题
- Face Inventory → 面信息
- Dimension → 尺寸标注
- Annotation → 注释
- Guide → 辅助线
- Construction → 构造线
- Unknown → 未识别
- Visible → 可见
- Off-screen / Hidden → 隐藏
- Visibility unknown → 可见性未知

## 2.5 Working Mode

`Working Mode`
→ `处理工作区`

Workspace states:

- none → 未准备
- building → 正在准备
- ready → 已准备
- discarded → 已放弃
- failed → 处理失败

Buttons:

- Prepare → 准备处理
- Discard → 放弃工作副本
- Rebuild → 重新生成
- Analyze Planarity → 检查平面偏差
- Apply Safe Normalization → 应用平面校正

## 2.6 Planar normalization

`Planar Normalization`
→ `平面校正`

State labels:

- NOT_COMPUTED → 未检查
- READY_TO_NORMALIZE → 可安全校正
- REVIEW_REQUIRED → 需要人工确认
- NO_CANDIDATE → 无需校正
- APPLIED → 已校正
- FAILED → 校正失败
- INVALID_TOLERANCE → 配置无效
- INVALID_INPUT → 数据无效

Field labels:

- Target Z → 目标 Z
- Eligible Vertices → 可处理顶点
- Proposed Movable → 待移动顶点
- Affected Derived Edges → 受影响线段
- Outliers → 异常点
- Skipped / Ambiguous Scope → 已跳过
- Max Proposed Movement → 最大校正量
- Review Reason → 原因
- Moved / Applied → 已移动
- Outliers Unchanged → 保留异常项
- Failure Reason → 失败原因

Internal reason strings may be mapped to concise Chinese presentation where
stable, but the raw reason must remain available in technical details.

---

# 3. DEFAULT INFORMATION ARCHITECTURE

The default UI should be visibly simpler than V1.5.

Use the existing page structure where possible; do not introduce a frontend
framework.

## 3.1 Primary visible area

Default expanded / visible content:

### A. Header

`CAD 检查结果`

One short selection line.

### B. 问题概览

Show only useful user-level facts.

Recommended:
- `发现 X 个问题`
- concise grouped issue list
- severity badge
- Chinese issue label/message

Do NOT make the primary summary look like a developer dashboard full of zero
counters.

If all counts are still retained for diagnostics, put them in collapsed
`检查详情`.

### C. 处理工作区

Show one short status sentence, for example:

- `尚未准备工作副本`
- `工作副本已准备，共 32 条线`
- `工作副本已放弃`
- `处理失败，需要重新生成`

Then show contextual action(s).

### D. 平面校正

Only show this card/block when a working copy exists.

Examples:

NOT_COMPUTED:
`尚未检查平面偏差。`

READY_TO_NORMALIZE:
`检测到可安全校正的轻微 Z 偏差。`
`目标 Z：...`
`待校正：... 个顶点`
`异常项：...`
PRIMARY CTA:
`应用平面校正`

REVIEW_REQUIRED:
`检测到多组高度，无法安全自动判断。`
No destructive action.

NO_CANDIDATE:
`当前几何无需平面校正。`

APPLIED:
`平面校正已完成。`
Show only moved count + max movement + outlier count by default.

FAILED:
`平面校正失败。`
Show a concise Chinese reason and recovery action.

---

# 4. ONE PRIMARY ACTION AT A TIME

Reduce visual button clutter.

The primary workflow should expose ONE clear next action whenever possible.

## 4.1 No workspace

Primary:
`准备处理`

## 4.2 Workspace ready + normalization NOT_COMPUTED

Primary:
`检查平面偏差`

Secondary:
- `放弃工作副本`
- `重新生成`

## 4.3 READY_TO_NORMALIZE

Primary:
`应用平面校正`

Secondary:
- `放弃工作副本`
- `重新生成`

## 4.4 REVIEW_REQUIRED / NO_CANDIDATE / APPLIED

No destructive normalization CTA.

Secondary workspace controls remain accessible.

## 4.5 Secondary action presentation

Do NOT show disabled irrelevant buttons such as a disabled `Prepare` next to
every ready-state action.

Preferred:

Primary button visible normally.

Secondary operational controls placed in a small collapsed:

`更多操作`

containing:
- 放弃工作副本
- 重新生成

If implementing a collapsed More Actions container creates disproportionate
complexity, use clearly secondary buttons below the primary CTA, but HIDE
unavailable actions rather than rendering many disabled buttons.

Preserve all existing callbacks.

---

# 5. COLLAPSED SECONDARY INFORMATION

These sections should remain available but collapsed by default:

## 5.1 `检查详情`

May contain:
- full scalar counters
- per-issue-type zero/non-zero counts
- original technical issue message if useful

## 5.2 `按图层查看问题`

Existing Issues by Layer.
Collapsed by default.

## 5.3 `图层信息`

Existing Layers.
Collapsed by default.

## 5.4 `面信息`

Existing Face Inventory.
Collapsed by default.

## 5.5 `技术详情`

Create/reuse a single collapsed technical detail area inside or below Working
Mode for information such as:

- Source Snapshot ID
- Source Fingerprint
- Execution Config digest
- raw workspace state
- duplicate repair technical audit
- per-action action_id
- rule_id
- survivor_id
- source occurrence count
- raw normalization reason string
- raw normalization audit fields

Normal user should not see these fields without intentionally opening
`技术详情`.

Do NOT delete the data contract.
Only change presentation hierarchy.

---

# 6. DUPLICATE REPAIR PRESENTATION

V1.5 audit evidence must remain inspectable, but simplify the visible row.

Default user-facing row:

`重复线清理：已处理 X，跳过 Y，失败 Z`

Optional:
`线段：A → B`

Do NOT show in the default view:
- duplicate class counts
- duplicate pair counts
- survivor derived ID
- action ID
- rule ID
- source occurrence count

Put those inside `技术详情`.

No V1.5 behavior change is authorized.

---

# 7. ISSUE ROW SIMPLIFICATION

Default issue card should contain:

- Chinese issue label
- Chinese severity badge
- one concise Chinese explanation

Keep issue ID hidden from the primary row.

Issue ID may be:
- tooltip;
- data attribute;
- technical details.

Locatable behavior remains unchanged.

Do NOT change source-locate semantics.

---

# 8. TECHNICAL IMPLEMENTATION BOUNDARY

Primary expected files:

- `extension/su_ai_plugin/html/app.js`
- `extension/su_ai_plugin/html/index.html`
- `extension/su_ai_plugin/html/style.css`
- `tests/test_html_render_dom.js`

Small Ruby UI-mapper changes are allowed ONLY if required to expose a stable
presentation field that cannot safely be derived in JS.

Do NOT modify:

- PlanarNormalizationAnalyzer semantics
- PlanarNormalizationProposer semantics
- PlanarNormalizationExecutor semantics
- Tolerance semantics
- transform_by_vectors route
- source/derived ownership
- transaction/Undo architecture
- provenance semantics
- V1.5 duplicate-repair semantics

If UI productization reveals a real backend contract flaw, STOP and report it
instead of silently redesigning.

---

# 9. FRONTEND SAFETY / COMPATIBILITY

Preserve current safety rules:

- no `eval`
- no `new Function`
- no user-supplied `innerHTML`
- no `document.write`
- text through `textContent`
- callback actions through `window.sketchup.<callback>`

Keep syntax compatible with the existing shipped HtmlDialog / SketchUp 2020
environment.

All HTML remains UTF-8.

Chinese text must display correctly in the RBZ / real SU2020 HtmlDialog.

---

# 10. REQUIRED DOM / UX TESTS

Tests must load the ACTUAL shipped frontend.

At minimum:

CN1 — Main title / selection empty-state are Chinese.

CN2 — Issue type / severity labels are Chinese.

CN3 — Working Mode visible labels/buttons are Chinese.

CN4 — Planar Normalization states/buttons are Chinese.

CN5 — READY_TO_NORMALIZE:
only the correct destructive primary CTA exists:
`应用平面校正`.

CN6 — NOT_COMPUTED:
primary action is:
`检查平面偏差`.

CN7 — REVIEW_REQUIRED:
Chinese review-required explanation visible;
no Apply action.

CN8 — NO_CANDIDATE:
Chinese no-action explanation visible;
no Apply action.

CN9 — APPLIED:
Chinese completion summary;
no stale Apply action.

CN10 — FAILED:
Chinese failure summary;
no Apply action.

CN11 — source snapshot / fingerprint / config digest are NOT visible in the
default primary Working Mode area and are available under `技术详情`.

CN12 — duplicate action IDs / rule IDs / survivor IDs are hidden by default and
available under technical details.

CN13 — Issues by Layer / Layers / Face Inventory are Chinese and collapsed by
default.

CN14 — unavailable actions are hidden rather than producing button clutter.

CN15 — existing callback dispatch still works:
- 准备处理 -> prepare_workspace
- 放弃工作副本 -> discard_workspace
- 重新生成 -> rebuild_workspace
- 检查平面偏差 -> compute_planar_normalization
- 应用平面校正 -> apply_planar_normalization

CN16 — missing/malformed payload degrades safely.

CN17 — no `[object Object]`, `undefined`, `NaN` in visible normal UI.

CN18 — technical details still retain the audit evidence needed by AIPM/Pi.

---

# 11. VISUAL CHECK

Pi must perform a static DOM/screenshot-capable review if the existing tooling
allows it, checking:

- Chinese text does not overflow obvious buttons/cards;
- primary action hierarchy is visually clear;
- technical detail sections are collapsed;
- default screen is materially less dense than before.

Do not claim real SketchUp rendering from Node tests.

Owner will perform the real SU2020 visual check.

---

# 12. REGRESSION / RBZ

Run:

1. updated Node DOM suite
2. focused V1.6 Ruby tests
3. V1.5 regression
4. full Ruby suite
5. legacy compatibility suite
6. RBZ smoke/load tests
7. git diff --check

Rebuild RBZ.

Verify packaged:
- app.js
- index.html
- style.css
match in-tree current files byte-for-byte.

Report:
- RBZ path
- size
- entry count
- SHA-256
- app.js SHA-256
- index.html SHA-256
- style.css SHA-256

---

# 13. OWNER ACCEPTANCE AFTER THIS DISPATCH

Do NOT run Owner verification.

Prepare the final real-host Owner test using the Chinese UI.

The first Owner scenario should read approximately:

1. 安装最新 RBZ，重启 SketchUp 2020。
2. 选择存在轻微 Z 偏差的线。
3. 打开插件。
4. 点击 `准备处理`。
5. 点击 `检查平面偏差`。
6. 确认显示 `可安全校正`。
7. 点击 `应用平面校正`。
8. 确认工作副本被校正、原始 CAD 不变。

Owner test instructions must use ONLY Chinese labels that actually exist in the
final RBZ.

---

# 14. CURRENT STATE / REPORT

Update CURRENT_STATE.md:

- V1.6 functional implementation remains complete;
- V1.6 Chinese simplified UX pass complete;
- Owner SU2020 verification NOT YET RUN;
- V1.6 NOT CLOSED;
- V1.7 NOT STARTED.

Overwrite:

Review/CURRENT_PI_REPORT.md

DISPATCH_ID:
V16-UI-CN-SIMPLIFICATION-2026-09-01

Report:

A. product UX changes
B. Chinese label map
C. default-visible vs collapsed information
D. action hierarchy
E. exact files changed
F. DOM test evidence
G. Ruby regression evidence
H. RBZ identity
I. Owner Chinese test instructions
J. remaining real-host unknowns
K. Git/network facts
L. CODEX_TRIGGER

Expected:
`CODEX_TRIGGER: NO`

unless a genuine architecture blocker appears.

---

# 15. GIT / NETWORK

Create one or two meaningful local commits.

Suggested:

`feat(v1.6): localize and simplify plugin UI`

`test(v1.6): cover Chinese simplified UX`

Do NOT:
- push/merge main
- force-push
- rebase shared history
- rewrite history
- tag/release

Use existing bounded network policy at completion.
GitHub being unreachable must not block local completion.

---

# 16. DEFINITION OF DONE

This dispatch is complete when:

- all normal user-facing interface text is Simplified Chinese;
- default interface is materially simpler;
- one clear primary next action is shown;
- unavailable actions do not clutter the UI;
- technical identifiers/audit internals are collapsed under `技术详情`;
- layer / face / per-layer information remains available but collapsed;
- V1.6 planar normalization remains fully operable;
- V1.5 duplicate-repair evidence remains inspectable;
- callback behavior is unchanged;
- DOM tests prove the Chinese simplified UX;
- full regressions are green;
- new RBZ contains the Chinese frontend;
- Owner instructions exactly match the final Chinese UI;
- V1.6 remains NOT CLOSED;
- V1.7 remains NOT STARTED.

Then STOP.

Return control to AIPM for Owner SU2020 real-host verification.
