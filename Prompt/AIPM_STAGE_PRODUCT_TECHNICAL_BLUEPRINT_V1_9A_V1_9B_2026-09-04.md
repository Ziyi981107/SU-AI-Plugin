# SU-AI-Plugin — V1.9A + V1.9B Product & Technical Blueprint

**Date:** 2026-09-04  
**Planning / Technical Design Owner:** AIPM / ChatGPT  
**Final Product Owner:** Owner  
**Implementation Agent:** Pi  
**Final Repo-aware Reviewer:** Codex xHigh (mandatory at V1.x final gate)  
**Baseline branch:** `dev/v1.8`  
**Baseline HEAD:** `bbe423cce3f4136ddd4d0673fbce02527e36de15`  
**Baseline status:** V1.8 CLOSED — Owner accepted for demo milestone  
**V1.9 status:** PLANNING FROZEN BY THIS BLUEPRINT; implementation not yet started

---

# 0. Owner Summary

V1.9 should be split into two controlled sub-stages:

- **V1.9A — Product UX + Deterministic Diagnostics Orchestration**
- **V1.9B — PreparedCadDataset + Validation + Acceptance + V2 Handoff**

This split is necessary.

V1.9A is not “beautify the CSS.”  
It changes the product interaction model from a development/debug panel into an action-first SketchUp production tool.

V1.9B is not “export some JSON.”  
It closes the entire V1.x product contract by defining what downstream V2 can trust, how readiness is validated, how warnings are acknowledged, and how the accepted Prepared CAD result is versioned and persisted.

The sequence is:

```text
V1.8 frozen baseline
    ↓
V1.9A0 static UX prototype
    ↓ Owner UX Gate
V1.9A1 production UI shell + presentation model
    ↓
V1.9A2 deterministic full-diagnostics orchestration
    ↓ Owner real-SU gate
V1.9B0 PreparedCadDataset persistence probe
    ↓ route frozen
V1.9B1 dataset schema + builder + validator
    ↓
V1.9B2 accept/persist/load + final UI
    ↓
AIPM review
    ↓
Codex xHigh FINAL V1.x review
    ↓
Owner real-host E2E + representative company CAD
    ↓
V1.x CLOSED
```

No MCP, LLM, Agent, site semantics, road recognition, building recognition, or V2 modeling is allowed in V1.9.

---

# 1. Evidence / Current-State Basis

## 1.1 Facts

1. V1.x Master Plan defines V1.9 as **Prepared CAD Workflow + V2 Handoff**.
2. The current V1.8 UI still exposes a stage-by-stage development workflow:
   - prepare workspace;
   - manually inspect planarity;
   - manually inspect gaps;
   - manually inspect structure.
3. Current primary UI architecture places working actions after issue groups and keeps significant information in multiple `<details>` sections.
4. Current V1.6 UX contract intentionally shows one “next action” at a time and hides unavailable actions.
5. Current `UIBridge` exposes raw/current `derivedWorkspace` plus older issue/layer/face payloads.
6. `WorkingModeRunner` is already the in-process owner of the current derived workspace and V1.6–V1.8 diagnostic state.
7. V1.8 final real SketchUp 2020 Owner gate passed rectangle-region and nested-loop/hole reconstruction.
8. Formal SU2017 runtime support still requires real-host evidence before release claim.

## 1.2 Owner Requirements Added for V1.9

The Owner has explicitly required:

- operation page must become the most prominent surface;
- starting processing should automatically detect all supported issue classes;
- Z problems, gaps/endpoints, structure status, etc. should not require a click-by-click reveal chain;
- the user should see the product’s processing capabilities at once;
- the top should stop showing normal inventory such as edge / vertex / face counts;
- default summary should show only meaningful problems;
- the page should be redesigned as a polished, professional SketchUp plugin;
- visual style should have restrained “AI” character rather than a debug-panel appearance.

These requirements are treated as product requirements, not cosmetic requests.

---

# 2. V1.9 Product Outcome

At the end of V1.9, a normal architectural designer should be able to:

1. select imported CAD geometry;
2. open the plugin;
3. click **one** primary “开始处理” action;
4. receive a complete diagnostic picture without manually stepping through internal pipeline stages;
5. understand:
   - what is already clean;
   - what was safely auto-processed;
   - what can be repaired explicitly;
   - what needs human review;
   - what is currently blocked or stale;
6. apply a safe Z correction or safe gap repair with one explicit action;
7. see downstream diagnostics refresh automatically;
8. inspect current unresolved problems without reading technical data;
9. optionally inspect layer / technical information;
10. validate the prepared result;
11. accept a versioned PreparedCadDataset when it is READY or explicitly acknowledge warnings when READY_WITH_WARNINGS;
12. finish with a result V2 can consume without guessing V1 internals.

The product should feel like:

> a focused CAD preparation workstation inside SketchUp

not:

> a sequence of version-development panels.

---

# 3. Product Principles

## P1 — Action First

The first screen is the processing dashboard.

Normal users must not need to scroll through layer inventories, face inventories, raw fingerprints, or implementation audits to reach the actual actions.

## P2 — Auto Diagnose, Explicit Repair

Diagnostics may run automatically.

Material geometry mutation remains explicit unless it is already classified as high-confidence deterministic auto-repair under the frozen V1.x authority model.

Examples:

- duplicate cleanup: may remain high-confidence auto-applied on derived geometry;
- safe planar normalization: explicit action;
- safe gap repair: explicit action;
- ambiguous geometry: never auto-guessed.

## P3 — Capability Visibility, Not Progressive Reveal

The dashboard always shows the main processing capabilities.

A capability card may be:

- clean;
- checking;
- actionable;
- review-required;
- applied;
- blocked;
- stale;
- failed.

The card itself does not disappear simply because no action is currently available.

## P4 — Current Prepared State Beats Raw Source Inventory

The default UI must describe the **current derived/prepared state**.

Original source findings remain available for audit, but must not cause repaired issues to continue looking “unfixed” in the primary dashboard.

## P5 — Error-only Summary

The top summary hides zero-value categories.

Normal inventory such as:

- edge count;
- vertex count;
- face count;
- faces-with-holes count;

is not shown on the default dashboard.

These may remain in Technical Details.

## P6 — Conservative Truth

If a downstream diagnostic is provisional, blocked, stale, or failed, say so.

Do not render a green “clean” state merely because an internal stage has not yet computed.

## P7 — No AI Theatre

The UI may have an AI-inspired visual identity.

V1.9 itself remains a deterministic CAD pipeline.

No LLM/API/MCP/Agent is introduced merely to justify the visual identity.

## P8 — Offline / Local Runtime

No CDN, web font, external icon service, remote JS, or runtime web dependency.

All assets ship inside the RBZ.

## P9 — Legacy-aware Frontend

Do not depend on visual features known to be fragile in older SketchUp HtmlDialog engines.

Prefer:

- flex layout;
- explicit margins;
- gradients;
- shadows;
- border radius;
- bundled SVG/static assets.

Avoid making correctness depend on:

- CSS Grid;
- `backdrop-filter`;
- flex `gap`;
- external fonts;
- modern-only browser APIs.

Graceful degradation is required.

---

# 4. V1.9A — Product UX + Diagnostics Orchestration

# 4.1 User Journey

## State 0 — Before Processing

The dialog opens with a selected CAD scope.

Primary surface:

```text
SU AI · CAD Prep
当前选择：XXXX

CAD 尚未处理
开始后将创建安全工作副本并完成全部检查

[ 开始处理 ]
```

Below it, the capability cards are already visible in an uncomputed state.

## State 1 — Processing

One click runs the deterministic preparation / diagnostic pipeline.

The UI shows:

```text
正在检查 CAD…
工作副本
重复线
Z 轴
间隙与断点
轮廓与区域
```

No user click is required between diagnostic stages.

## State 2 — Results

Example:

```text
发现 2 类需要处理的问题
12 个 Z 轴偏差 · 3 个可安全修复间隙

[ 重新检测 ]

重复线清理      ✓ 已处理 4 条
Z 轴 / 平面     ⚠ 12 个可安全校正点    [ 修复 Z 轴 ]
间隙与断点      ⚠ 3 处可安全修复       [ 修复间隙 ]
轮廓与区域      ! 当前 2 个开放链
其他问题        ! 1 项需要人工查看       [ 查看问题 ]
```

## State 3 — Repair

User explicitly applies a safe repair.

After repair:

- affected downstream computations are invalidated;
- they are automatically recomputed;
- UI receives one refreshed coherent snapshot;
- user does not manually click “检查间隙” / “检查结构” again.

## State 4 — Ready for V1.9B Validation

When no actionable safe repairs remain, the dashboard transitions toward final validation.

---

# 4.2 Information Architecture

Use four primary tabs / surfaces:

## A. 处理 — Default

The action dashboard.

Contains:

- header / current selection;
- overall CAD status;
- error-only summary;
- persistent capability cards;
- top-level Start / Recheck action;
- recovery banner when stale/failed;
- V1.9B final validation card later.

This is the normal-user home.

## B. 问题

Shows **current unresolved problems** first.

Supports:

- type grouping;
- severity / actionability;
- click-to-locate when locatable;
- concise reason;
- “why not auto repaired” where relevant.

The old source Registry may be available as an “原始检查记录” sub-section but is not the default current-problem count.

## C. 图层

Preserves LayerSemanticMap / layer-role / visibility information.

This is secondary context, not the main workflow.

## D. 详情

Technical / audit surface.

May contain:

- source snapshot id;
- source fingerprint;
- config digest;
- raw workspace state;
- duplicate repair audit;
- normalization audit;
- gap audit;
- canonical graph digest;
- structure digest;
- dataset version/digest in V1.9B;
- raw source inventory counts;
- original source issue groups;
- debug information.

Normal users should not need this tab for ordinary processing.

---

# 4.3 Dashboard Capability Cards

Cards are rendered in a fixed order.

## Card 1 — 重复线清理

Possible user states:

- 未检查
- 正在处理
- 无重复线
- 已自动处理 N 条
- 跳过 N 条
- 处理失败

No manual “repair duplicates” button is added if current V1.5 authority remains high-confidence auto-apply.

## Card 2 — Z 轴 / 平面校正

Possible states:

- 未检查
- 无需校正
- 可安全校正
- 需要人工确认
- 已校正
- 失败
- 已过期 / 等待重检

Action when safe:

`修复 Z 轴`

Do not display Apply when state is not safe.

## Card 3 — 间隙与断点

Possible states:

- 未检查
- 无需修复
- 发现安全修复项
- 需要人工确认
- 已修复
- 失败
- 已过期 / 等待重检

Action when safe:

`修复间隙`

Useful metrics:

- open endpoints;
- safe repair proposals;
- review-required count;
- remaining open endpoints.

Only non-zero/relevant values should be shown.

## Card 4 — 轮廓与区域

Possible states:

- 未检查
- 结构可用
- 存在需检查项
- 检查失败
- 等待上游状态
- 已过期

Useful metrics:

- open chains;
- closed loops;
- regions;
- holes;
- exceptions.

Do not show all metrics if zero-value rows add no decision value.

## Card 5 — 其他需检查项

Only visually material when current non-actionable issues exist, for example:

- short edge warnings;
- abnormal coordinate warning;
- deep nesting;
- unresolved geometry ambiguity.

Action:

`查看问题`

This card prevents secondary issue classes from disappearing merely because they do not have a dedicated repair feature.

---

# 4.4 Overall Status

Presentation-level overall state:

```text
IDLE
SCANNING
NEEDS_ATTENTION
READY_FOR_VALIDATION
STALE
FAILED
```

Do not expose this enum verbatim to the user.

Example labels:

- 尚未处理
- 正在检查
- 发现需要处理的问题
- 已完成检查
- 工作副本已失效
- 处理失败

The overall status is presentation state, not a replacement for frozen V1.6/V1.7/V1.8 internal state enums.

---

# 4.5 Error-only Summary Contract

Primary summary is generated from **current workflow state**, not raw inventory.

Rules:

1. Hide all categories whose count is 0.
2. Hide normal edge/vertex/face counts.
3. Prefer current unresolved/actionable counts.
4. Repaired duplicate/Z/gap items must no longer remain in the primary current-problem total merely because source Registry still contains the original finding.
5. Original source findings remain auditable under `详情 → 原始检查记录`.
6. If there are no current problems:

```text
CAD 状态良好
未发现需要处理的问题
```

7. If there are issues:

```text
发现 3 类 · 17 项问题
12 Z 轴偏差
3 开放端点
2 间隙
```

Exact wording is presentation-level and may be polished during prototype gate.

---

# 4.6 Visual Direction

Target visual character:

> Professional CAD utility + restrained AI product language.

Not:

> neon cyberpunk dashboard / chatbot / marketing landing page.

## Light-first palette

Recommended direction:

- cool near-white background;
- white / slightly tinted surfaces;
- subtle blue-violet primary accent;
- blue → violet micro-gradient for primary CTA or thin accent strip;
- emerald success;
- amber warning;
- red failure;
- graphite text;
- low-contrast cool-gray borders.

## Geometry

- 10–12px card radius;
- generous vertical spacing;
- restrained shadow;
- clear visual hierarchy;
- no dense spreadsheet look.

## Typography

Use system / locally available fonts only:

- `system-ui`
- `PingFang SC`
- `Microsoft YaHei`
- fallback sans-serif.

No web font.

## Icons

Bundled static SVG / inline static SVG is allowed.

Do not load remote icon libraries.

## Motion

Allowed:

- subtle spinner;
- progress pulse;
- 120–180ms hover / state transitions.

Avoid:

- decorative continuous animation;
- expensive blur effects;
- animation that obscures state.

---

# 4.7 Static Prototype Gate — REQUIRED BEFORE PRODUCTION UI CODE

Pi must first build a static prototype only.

Recommended path:

```text
Prototype/V1_9A/
  index.html
  style.css
  prototype.js
```

No production Ruby callback integration in this packet.

Prototype must include mock-switchable states:

1. Idle / not processed.
2. Clean CAD.
3. Z + gap actionable.
4. Review-required / unresolved.
5. Failed / stale recovery.
6. Ready for validation.

Prototype should be viewable at approximately current SketchUp dialog size and a moderately larger size.

## Owner UX Gate

Owner must approve:

- overall visual direction;
- card hierarchy;
- tab hierarchy;
- default density;
- terminology;
- primary CTA placement;
- issue summary behavior;
- repair button placement.

Only then does Pi integrate the production frontend.

---

# 5. V1.9A Technical Architecture

# 5.1 Do Not Reimplement V1.6–V1.8 Algorithms

V1.9A is an orchestration and presentation layer.

It must call the existing production methods.

Do not copy or rewrite:

- planar normalization proposer/executor;
- gap repair proposer/executor;
- canonical graph semantics;
- structure reconstruction algorithm.

Any algorithm rewrite is outside this stage and triggers AIPM review before implementation continues.

---

# 5.2 Add a Deterministic Diagnostics Orchestrator

Preferred responsibility:

```text
CadPrepWorkflowOrchestrator
```

The exact class/module name may fit repository conventions, but responsibility is frozen:

- coordinate the existing preparation / diagnostic methods;
- publish one coherent post-run state;
- know dependency invalidation;
- never infer architectural semantics;
- never make an AI decision.

Preferred start-processing sequence:

```text
validate input/source
→ prepare Derived Workspace
→ run existing high-confidence duplicate repair batch
→ compute planar normalization diagnostic
→ compute gap/topology diagnostic
→ compute structure reconstruction diagnostic when available
→ publish workflow snapshot
```

If a downstream stage cannot run, publish a truthful BLOCKED/UNAVAILABLE presentation state.

Do not hide it.

---

# 5.3 Mutation / Refresh Dependency Rules

## After `修复 Z 轴`

Use the existing planar executor.

Then automatically:

```text
invalidate affected topology/structure state
→ recompute gap/topology
→ recompute structure
→ publish one coherent refreshed UI payload
```

The user must not manually click:

- 检查间隙
- 检查结构

after the repair.

## After `修复间隙`

Use the existing gap executor.

Then:

```text
invalidate structure state
→ recompute structure
→ publish one coherent refreshed UI payload
```

## After Rebuild

```text
rebuild workspace
→ duplicate high-confidence batch
→ full diagnostics
→ publish
```

## Recheck

Top-level `重新检测` means:

- validate current host/workspace consistency;
- recompute diagnostics on the **current prepared workspace**;
- do not silently rebuild and erase prior accepted repairs.

`重新生成工作副本` remains a distinct recovery / advanced action.

---

# 5.4 Failure Semantics

Foundational failures:

- source unavailable;
- workspace build failed;
- host state changed;
- workspace handle reconciliation failed.

These may block the pipeline.

Stage-local failures should be represented locally and block only dependent stages where possible.

Never transform:

`NOT_COMPUTED`

into:

`clean`.

Unknown/uncomputed must remain distinguishable.

---

# 5.5 Presentation Model — New Additive UI Contract

Do not force `app.js` to infer the entire product state from raw V1.4–V1.8 hashes.

Add an additive top-level UI payload, conceptually:

```json
{
  "cadPrepWorkflow": {
    "schema_version": "1",
    "overall_state": "NEEDS_ATTENTION",
    "headline": "发现 2 类需要处理的问题",
    "issue_summary": [],
    "cards": [],
    "recovery": null
  }
}
```

Existing raw fields remain available for backward compatibility / technical details.

Recommended card shape:

```json
{
  "id": "planar_normalization",
  "state": "ACTIONABLE",
  "title": "Z 轴 / 平面校正",
  "summary": "发现 12 个可安全校正点",
  "metrics": [
    {"key":"movable","label":"可校正","value":12}
  ],
  "primary_action": {
    "callback": "apply_planar_normalization",
    "label": "修复 Z 轴",
    "enabled": true
  },
  "detail_filter": "planar"
}
```

The exact JSON shape may be adjusted mechanically during implementation, but these semantics are frozen:

- stable card id;
- stable presentation state;
- title;
- summary;
- metrics;
- optional action;
- optional detail target / reason.

---

# 5.6 Presenter Responsibility

Preferred separation:

```text
Core runner/orchestrator
    ↓ raw deterministic state
CadPrepWorkflowPresenter
    ↓ product-facing state
UIBridge
    ↓ JSON-safe conversion
app.js
```

The presenter is pure/testable where practical.

Do not put Chinese business-state inference in geometry algorithms.

---

# 5.7 Frontend Rewrite Boundary

Production frontend may substantially rewrite:

- `html/index.html`
- `html/style.css`
- `html/app.js`

while preserving:

- no `eval`;
- no `new Function`;
- no `document.write`;
- no unsafe interpolation of user strings;
- user-supplied text rendered via `textContent` / safe attributes;
- existing locate behavior for locatable issues;
- no remote runtime dependency.

Old layer/face/technical render functions may be reused or simplified behind the new tabs.

The product UI is allowed to remove old default-visible inventory presentation, but the underlying data contract must not be deleted merely for visual simplification.

---

# 5.8 Dialog Callback Boundary

New orchestration callbacks may include:

```text
start_cad_prep
refresh_cad_prep
```

Existing repair callbacks should preferably remain stable:

```text
apply_planar_normalization
apply_gap_repair
discard_workspace
rebuild_workspace
```

After apply, Ruby-side handler/orchestrator owns downstream refresh.

Do NOT implement a JavaScript chain that simulates multiple button clicks.

Backend orchestration is authoritative.

---

# 6. V1.9A Acceptance Criteria

## Product / UX

A1. From a valid selected CAD scope, one click on `开始处理` produces a complete diagnostic dashboard.

A2. No manual `检查平面偏差 → 检查间隙 → 检查结构` click chain is required on the normal path.

A3. All main capability cards remain visible.

A4. Zero-value issue categories do not clutter the top summary.

A5. Edge / vertex / face inventory is absent from the primary dashboard.

A6. Current repaired state is not confused with original source findings.

A7. Normal path does not require opening `图层` or `详情`.

A8. Safe repairs remain explicit unless already frozen as high-confidence auto-repair.

A9. Applying Z repair automatically refreshes affected downstream diagnostics.

A10. Applying gap repair automatically refreshes structure diagnostics.

A11. Stale/Undo host state produces an obvious recovery state rather than silent failure.

A12. UI works without network access.

## Technical

A13. Source CAD remains immutable.

A14. Existing V1.5–V1.8 algorithms are reused, not duplicated.

A15. No JS-driven hidden orchestration.

A16. Presentation model is additive and JSON-safe.

A17. Existing raw technical data remains available under technical detail.

A18. New workflow/orchestrator behavior has deterministic tests.

A19. DOM regression proves:
- card presence;
- action visibility;
- zero summary hiding;
- safe text rendering;
- tab switching;
- stale/failed display.

A20. Real SketchUp 2020 Owner test passes.

A21. No SU2017 support claim is upgraded without real SU2017 evidence.

---

# 7. V1.9B — PreparedCadDataset + Validation + Acceptance

# 7.1 Product Goal

Turn the prepared working result into a versioned, validated V1 output contract that future V2 can consume.

V1.9B answers:

> “Can V2 trust this prepared CAD dataset, and exactly what does ‘trust’ mean?”

It must NOT answer:

- which loop is a road;
- which region is a residential building;
- what should be extruded;
- what design decision should be made.

---

# 7.2 Final Dashboard Card

Add final card:

`最终验证`

Possible states:

- 尚未验证
- 不可交付
- 可交付但存在警告
- 已就绪
- 已接受
- 验证失败
- 数据已失效

Actions:

```text
[ 验证准备数据 ]
[ 接受准备结果 ]
```

For READY_WITH_WARNINGS:

```text
仍有 N 项未解决问题
这些问题将作为警告保留在 PreparedCadDataset 中

[ 查看警告 ]
[ 接受并保留警告 ]
```

Warning acceptance must be explicit.

---

# 7.3 PreparedCadDataset — Frozen Conceptual Schema

The dataset is pure-data, JSON-safe, deeply immutable after build, and versioned.

Conceptual schema:

```text
PreparedCadDataset
├─ schema_version
├─ dataset_id
├─ content_digest
├─ producer
├─ source
│  ├─ source_snapshot_id
│  ├─ source_fingerprint_digest
│  └─ selection/source identity summary
├─ execution
│  ├─ profile
│  ├─ rule_set_digest
│  ├─ config_digest
│  └─ tolerance metadata
├─ coordinate_context
│  ├─ unit policy
│  ├─ coordinate origin policy
│  └─ transform/edit context required by V2
├─ layer_semantics
├─ canonical_geometry
│  ├─ graph schema/version
│  ├─ graph digest
│  ├─ nodes
│  ├─ edges
│  └─ adjacency
├─ structures
│  ├─ structure schema/version
│  ├─ structure digest
│  ├─ chains
│  ├─ loops
│  └─ regions
├─ repair_history
│  ├─ duplicate cleanup
│  ├─ planar normalization
│  └─ gap repair
├─ unresolved_issues
├─ provenance_summary
└─ validation
   ├─ readiness
   ├─ checks
   ├─ blockers
   └─ warnings
```

The implementation may flatten/nest fields differently if needed, but the semantic responsibility is frozen.

---

# 7.4 Content Digest / Dataset Identity

Dataset content identity must be deterministic.

Rules:

1. No current wall-clock timestamp inside the content digest.
2. Deterministic ordering is required.
3. Rebuilding the same accepted logical data should produce the same content digest.
4. `dataset_id` should be derived from or tied to the content digest.
5. Acceptance metadata such as `accepted_at` belongs outside the deterministic content payload or is excluded from the content digest.

Reuse existing canonical digest helpers if the repository already has a suitable reviewed implementation.

Do not create a second incompatible digest convention without need.

---

# 7.5 Acceptance Envelope

Separate deterministic dataset content from user acceptance metadata.

Conceptually:

```text
PreparedCadAcceptance
├─ dataset
├─ accepted_at
├─ plugin_version
├─ acknowledged_warning_ids
└─ persistence_metadata
```

This allows deterministic dataset identity while still recording the real acceptance event.

---

# 7.6 Readiness Contract

Canonical readiness:

```text
NOT_READY
READY_WITH_WARNINGS
READY
```

## NOT_READY

Examples of blocking conditions:

- no current ready workspace;
- host state stale / invalid;
- source integrity cannot be validated;
- workspace processing failed;
- canonical graph unavailable/invalid;
- structure reconstruction FAILED;
- known safe actionable repair remains pending and is required for dataset consistency;
- required provenance/digest contract invalid;
- dataset fails serialization/schema/digest checks.

## READY_WITH_WARNINGS

Allowed only when:

- no blocking condition remains;
- current geometry contract is internally consistent;
- unresolved items are explicitly non-blocking/reviewable;
- warning records are preserved in dataset;
- user explicitly acknowledges them when accepting.

## READY

- all required validation checks pass;
- no blocking issues;
- no material unresolved warning requiring acknowledgment.

---

# 7.7 Important Product Decision — Actionable Safe Repairs vs Warnings

A deterministic repair that the product classifies as safe and required for current preparation should not silently become a warning merely because the user did not click it.

Examples:

- `READY_TO_NORMALIZE`
- `READY_TO_REPAIR`

normally keep dataset as `NOT_READY` until the action is completed or the final policy explicitly defines a safe skip.

Ambiguous / review-required geometry may be preserved under `READY_WITH_WARNINGS`.

This prevents the product from calling known unfinished deterministic work “ready.”

---

# 7.8 Dataset Builder

Preferred pure component:

```text
PreparedCadDatasetBuilder
```

Inputs should be existing pure/frozen data where possible:

- AnalysisResult / SourceSnapshot data;
- LayerSemanticMap data;
- WorkingModeRunner current audited state;
- V1.7 canonical graph;
- V1.8 structure result.

Builder must not retain live SketchUp entities.

It outputs a deeply immutable PreparedCadDataset.

---

# 7.9 Dataset Validator

Separate component:

```text
PreparedCadDatasetValidator
```

Responsibilities:

- verify required schema fields;
- verify source/workspace consistency inputs;
- verify graph/structure digest relationship;
- verify readiness preconditions;
- verify unresolved issue classification;
- verify provenance presence;
- verify JSON-safe serialization;
- verify deterministic digest;
- return structured blockers/warnings/check results.

Do not bury readiness logic inside frontend JS.

---

# 7.10 Source Integrity at Accept Time

Acceptance must not rely only on the historical source snapshot.

Before final dataset acceptance, the system must re-check that the source scope V1 is referring to has not silently diverged in a way that invalidates the dataset.

The exact implementation must reuse existing source identity/fingerprint/provenance mechanisms where possible.

If reliable live-source revalidation cannot be proven, acceptance must fail closed rather than claiming READY.

This is a high-risk boundary and will be explicitly inspected in final Codex review.

---

# 8. Prepared Dataset Persistence — Feasibility Gate Before Freeze

# 8.1 Why a Probe Is Required

SketchUp officially supports `Model#set_attribute` / AttributeDictionary and String values in long-standing Ruby APIs.

However, the current API documentation does not define a product-grade large-JSON payload size/performance guarantee.

Therefore we should not blindly freeze “store entire dataset as one model attribute string” before testing representative data.

---

# 8.2 V1.9B0 Persistence Probe

Test a minimal `PreparedDatasetStore` candidate using real SketchUp.

Leading candidate:

```text
Model AttributeDictionary
dictionary: SU-AI-Plugin.PreparedCadDataset
```

Probe:

1. save representative JSON payload;
2. read it back;
3. save SKP;
4. close/reopen model;
5. read and parse;
6. verify byte-identical / digest-identical content;
7. test Undo/Redo behavior when write is wrapped in an operation;
8. measure practical write/read/save latency on representative company CAD-scale payload;
9. verify replacement of one accepted dataset with another;
10. verify corrupt/missing payload fails closed.

If model-attribute persistence is reliable at representative scale, use it.

If not, AIPM chooses a fallback before Pi implements persistence.

Potential fallback classes may include a sidecar JSON store, but no fallback is pre-authorized until the probe fails and AIPM reviews the tradeoff.

---

# 8.3 One Active Accepted Dataset per Model — V1.9 Scope

V1.9 supports one active accepted PreparedCadDataset per SketchUp model.

Replacing it requires a new successful Accept.

Historical multi-dataset/version browsing is out of scope.

This is sufficient for the V1 → V2 handoff and avoids building a dataset-management product.

---

# 9. Acceptance Lifecycle

Recommended lifecycle:

```text
working result
→ validate
→ READY / READY_WITH_WARNINGS
→ explicit accept
→ build acceptance envelope
→ persist atomically if storage route is approved
→ mark session accepted
→ UI confirms accepted dataset id/digest
```

Important:

- failed persistence must not claim accepted;
- accepted dataset must remain readable after dialog closes;
- transient derived working geometry may be cleaned after acceptance without deleting the persisted dataset;
- current V1.6 “close auto-discard” behavior must be revised carefully so accepted data is not lost;
- no broad Observer architecture is introduced.

If the user later changes source/host geometry, V2 must validate dataset/source compatibility at consumption time rather than trusting a stale acceptance forever.

---

# 10. V1.9B UI Behavior

## NOT_READY

```text
最终验证
不可交付

仍有 2 项需要完成：
• Z 轴存在 12 个可安全校正点
• 3 处间隙可安全修复

[ 返回处理 ]
```

## READY_WITH_WARNINGS

```text
最终验证
可交付，但存在 2 项警告

这些问题不会被自动修改，将保留给下游和人工检查。

[ 查看警告 ]
[ 接受并保留警告 ]
```

## READY

```text
最终验证
CAD 已准备完成

结构、来源和修复记录已通过验证。

[ 接受准备结果 ]
```

## ACCEPTED

```text
准备完成 ✓

Dataset
PCD-XXXXXXXX

V1 数据已冻结，可供后续 V2 使用。
```

Do not show raw SHA values prominently unless user opens details.

---

# 11. V1.9B Acceptance Criteria

B1. PreparedCadDataset has an explicit schema version.

B2. Dataset content is JSON-safe and contains no live SketchUp object.

B3. Dataset is deeply immutable after build.

B4. Same logical content produces the same content digest.

B5. Source identity/fingerprint is included.

B6. Layer semantic data is included.

B7. Canonical graph and V1.8 structures are included or deterministically referenced by embedded content.

B8. Repair/audit history is preserved.

B9. Unresolved warnings are preserved.

B10. Readiness is one of NOT_READY / READY_WITH_WARNINGS / READY.

B11. Pending required safe repairs cannot accidentally produce READY.

B12. READY_WITH_WARNINGS requires explicit user acknowledgment before Accept.

B13. Accept validates source/host consistency immediately before persisting.

B14. Persistence failure does not produce accepted state.

B15. Saved accepted dataset survives close/reopen under the selected persistence route.

B16. Dataset digest is verified after reload.

B17. Corrupt or unsupported stored schema fails closed.

B18. No V2 semantic label is invented.

B19. V2 can load the dataset without knowing V1.6/V1.7/V1.8 UI internals.

B20. Source CAD remains unmodified.

---

# 12. Test Strategy

# 12.1 V1.9A Capability / Regression Set

Maintain:

### UX DOM Set
- idle;
- clean;
- actionable Z;
- actionable gap;
- Z + gap together;
- review-required;
- failed stage;
- stale host;
- post-Z automatic refresh;
- post-gap automatic refresh;
- zero issue summary;
- current vs original source issue distinction.

### Workflow Deterministic Set
- exact orchestration order;
- no duplicate call;
- stage dependency invalidation;
- error propagation;
- host-state validation;
- source immutable;
- repair audit preserved.

### Existing Regression
All V1.0–V1.8 suites remain required unless AIPM explicitly documents a deliberate UI-contract replacement.

---

# 12.2 V1.9B Dataset Set

### Capability
- clean rectangle → READY dataset;
- outer + inner loop → READY dataset with region/hole structure;
- representative safe repaired gap → valid final dataset;
- representative planar correction → valid final dataset.

### Warning
- ambiguous/review-required case → READY_WITH_WARNINGS if no blocker;
- explicit warning acknowledgment captured.

### Negative
- pending safe repair → NOT_READY;
- structure failure → NOT_READY;
- stale workspace → NOT_READY;
- source integrity mismatch → NOT_READY;
- corrupt graph digest → NOT_READY;
- missing provenance → NOT_READY;
- persistence failure → not accepted;
- corrupted stored JSON → load fails closed;
- unsupported schema → load fails closed.

### Determinism
- same logical input → same dataset content digest;
- serialization round-trip preserves digest.

---

# 12.3 Real-host Gates

## SketchUp 2020

Mandatory.

V1.9A Owner:
- one-click full diagnostics;
- Z repair auto-refresh;
- gap repair auto-refresh;
- clean case;
- stale/recovery;
- final polished UI usability.

V1.9B Owner:
- validate;
- accept;
- persist;
- close/reopen;
- load/verify accepted dataset;
- warning acceptance path.

## SketchUp 2017

Required before formal “SU2017+ supported” release claim.

If unavailable/unverified:

- do not fabricate PASS;
- describe implementation as legacy-aware but runtime-verified only on tested hosts.

---

# 12.4 Company Golden Fixtures

Before V1.x final closure, test representative company CAD/SKP where available.

Prefer at least:

1. ordinary imported residential CAD with common noise;
2. known Z/gap/duplicate-heavy fixture;
3. nested closed-region / hole case or comparable site geometry.

Record real observed outcome.

Do not treat demo fixtures as a substitute for company data.

---

# 13. Review / Release Gates

## Gate A0 — Static UX Prototype

Owner visual/interaction approval.

No backend integration before PASS.

## Gate A1 — Production Frontend

AIPM checks:

- new IA;
- presentation model;
- safe JS contract;
- no raw-state UI confusion;
- visual prototype fidelity.

## Gate A2 — Orchestrator

AIPM checks:

- exact call flow;
- invalidation/recompute;
- no algorithm duplication;
- host/source safety.

Codex is not mandatory unless frozen topology/ownership/transaction contracts materially change.

## Gate B0 — Persistence Probe

AIPM selects persistence route based on evidence.

## Gate B1 — Dataset Contract

AIPM checks schema/digest/readiness/provenance.

## Gate B2 — Acceptance + Store

AIPM checks atomicity/fail-closed/load/reopen.

## Final V1.x Gate

**Mandatory Codex xHigh final review** per Master Plan.

Focus:

- source immutability;
- host state / Undo;
- dataset identity/digest;
- source revalidation;
- persistence;
- tolerance/provenance;
- state ownership;
- Ruby/SU2017 compatibility risks;
- V2 handoff boundary.

Then Owner real-host acceptance.

---

# 14. Non-Goals

V1.9 explicitly does NOT add:

- MCP;
- LLM;
- AI reasoning;
- Agent;
- CAD direct importer;
- road classification;
- building classification;
- land-use semantics;
- site extrusion;
- residential generation;
- rendering;
- cloud sync;
- user accounts;
- multi-dataset history;
- plugin marketplace/commercial licensing.

Visual “AI feel” does not change this boundary.

---

# 15. File / Module Direction

Likely touched in V1.9A:

```text
extension/su_ai_plugin/html/index.html
extension/su_ai_plugin/html/style.css
extension/su_ai_plugin/html/app.js
extension/su_ai_plugin/ui_bridge.rb
extension/su_ai_plugin/dialog_runner.rb
extension/su_ai_plugin/core/working_mode_runner.rb   # only where required
```

Preferred additive modules:

```text
extension/su_ai_plugin/core/cad_prep_workflow_orchestrator.rb
extension/su_ai_plugin/cad_prep_workflow_presenter.rb
```

Exact locations may adapt to repository convention.

V1.9B likely adds:

```text
extension/su_ai_plugin/core/prepared_cad_dataset.rb
extension/su_ai_plugin/core/prepared_cad_dataset_builder.rb
extension/su_ai_plugin/core/prepared_cad_dataset_validator.rb
extension/su_ai_plugin/compatibility/prepared_dataset_store.rb
```

Do not create unnecessary framework layers. If two responsibilities fit cleanly in one small module, prefer simpler structure.

---

# 16. Decision / Unknown / Validation Ledger

## Decisions

- V1.9 is split A/B.
- V1.9A starts with static UX prototype gate.
- Dashboard is action-first.
- Diagnostics become one-click deterministic orchestration.
- Repairs remain conservative/explicit.
- Capability cards remain visible.
- Top summary is current-problem-only.
- raw inventory moves to details.
- V1.9B defines versioned PreparedCadDataset.
- readiness = NOT_READY / READY_WITH_WARNINGS / READY.
- warning acceptance is explicit.
- one active accepted dataset per model.
- final Codex xHigh is mandatory.

## Unknowns

- final approved visual treatment before prototype gate;
- exact PreparedCadDataset persistence mechanism;
- model AttributeDictionary performance/size behavior on representative payload;
- exact company Golden fixtures to use;
- availability of real SU2017 for release evidence.

## Required Validation

- Owner static UX approval;
- real SU2020 orchestrated workflow;
- persistence probe;
- deterministic dataset tests;
- save/reopen/load;
- company Golden CAD;
- final Codex xHigh;
- SU2017 real-host before formal support claim.

---

# 17. Implementation Sequence

Do not give Pi the whole V1.9 in one autonomous packet.

Use bounded packets:

```text
Packet A0
Static UX prototype only
STOP → Owner UX Gate

Packet A1
Production HTML/CSS/JS shell + presentation model
STOP → AIPM review

Packet A2
Diagnostics orchestrator + auto refresh
STOP → AIPM review + Owner SU2020

Packet B0
Persistence feasibility probe only
STOP → AIPM route decision

Packet B1
PreparedCadDataset + validator
STOP → AIPM source review

Packet B2
Accept/store/load + final dashboard integration
STOP → AIPM review

Final
Codex xHigh V1.x review
→ Owner E2E
→ V1.x CLOSED
```

This keeps Pi execution-focused and prevents unreviewed architectural drift.

---

# 18. Immediate Next Action

Create and dispatch **V1.9A Packet A0 — Static UX Prototype**.

No production Ruby code.

The Owner should first see and approve the new product experience before we connect it to the V1.4–V1.8 backend.

END
