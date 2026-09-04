# CURRENT PI DISPATCH — V1.9A-A1 PRODUCTION UI SHELL + PRESENTATION MODEL

Project: SU-AI-Plugin
Stage: V1.9A — Product UX + Diagnostics Orchestration
Packet: A1 — PRODUCTION UI SHELL + PRESENTATION MODEL
Date: 2026-09-04
Authority: Prompt/AIPM_STAGE_PRODUCT_TECHNICAL_BLUEPRINT_V1_9A_V1_9B_2026-09-04.md
A0 Owner UX Gate: PASS
Approved Prototype: Prototype/V1_9A/
Baseline: dev/v1.8 @ bbe423cce3f4136ddd4d0673fbce02527e36de15
TARGET_BRANCH: dev/v1.9
Implementation Agent: Pi
CODEX_RISK_TRIGGER: NO unless frozen risk boundaries are crossed
A2 / V1.9B: NOT AUTHORIZED

---

## 0. Goal

Integrate the Owner-approved A0 visual / information architecture into the real production HtmlDialog and add a clean product-facing presentation model.

A1 must NOT yet implement the one-click full diagnostics orchestrator.

Stage split:

A0 = static UX prototype — PASS
A1 = production frontend + presentation model
A2 = deterministic full-diagnostics orchestration

At A1 completion:
- production HtmlDialog uses the approved four-tab structure;
- processing dashboard visually follows the prototype;
- existing V1.4–V1.8 backend actions still work;
- production payload exposes additive `cadPrepWorkflow`;
- frontend renders product state from that presentation object;
- no geometry algorithm redesign.

STOP after A1.

---

## 1. Git / Branch

Create or switch to `dev/v1.9` from exactly:

`dev/v1.8 @ bbe423cce3f4136ddd4d0673fbce02527e36de15`

Normal local commits and normal fast-forward push to `origin/dev/v1.9` are authorized.

Do not modify main.
Do not rewrite dev/v1.8 history.
No force-push / shared-history rebase.

---

## 2. Visual / IA Source of Truth

Use Owner-approved:

Prototype/V1_9A/
- index.html
- style.css
- prototype.js

Approved production IA:

处理 | 问题 | 图层 | 详情

Default tab = 处理.

Preserve:
- action-first dashboard;
- error-only primary summary;
- persistent capability cards;
- prominent primary action;
- layer / technical content subordinate;
- light professional CAD-tool appearance;
- restrained blue-violet AI accent.

Do not redesign the IA again.

---

## 3. Expected Production Files

Expected:
- extension/su_ai_plugin/html/index.html
- extension/su_ai_plugin/html/style.css
- extension/su_ai_plugin/html/app.js
- extension/su_ai_plugin/ui_bridge.rb

Preferred additive presenter:
- extension/su_ai_plugin/cad_prep_workflow_presenter.rb
or repository-consistent equivalent.

Small dialog_runner.rb wiring changes are allowed only if mechanically required.

Do not modify geometry algorithm files unless AIPM explicitly re-authorizes.

---

## 4. Hard Scope Boundary

A1 MAY:
- port approved HTML/CSS/JS design;
- add pure/product-facing presenter;
- add additive `cadPrepWorkflow` payload;
- keep existing raw V1.0–V1.8 payload for details/backward compatibility;
- map current existing backend state into new cards;
- preserve existing callbacks.

A1 MUST NOT:
- implement CadPrepWorkflowOrchestrator;
- add automatic full diagnostics after Prepare;
- add start_cad_prep orchestration;
- add automatic downstream recompute after Z repair;
- add automatic structure recompute after gap repair;
- change V1.6/V1.7/V1.8 algorithms;
- change tolerance/source ownership;
- add Face or Observer architecture;
- add PreparedCadDataset/persistence;
- begin V1.9B;
- add MCP / LLM / Agent.

If any of these appears necessary: STOP and report.

---

## 5. Presentation Model

Preferred architecture:

AnalysisResult + WorkingModeRunner.snapshot
→ CadPrepWorkflowPresenter
→ cadPrepWorkflow
→ UIBridge
→ app.js

The frontend must not infer the entire product state itself from raw nested internal hashes.

Presenter should be pure/testable where practical.

Conceptual `cadPrepWorkflow` responsibilities:
- schema_version
- overall_state
- headline
- subheadline
- issue_summary
- cards
- recovery

Overall presentation states:
- IDLE
- SCANNING
- NEEDS_ATTENTION
- READY_FOR_VALIDATION
- STALE
- FAILED

Do not expose raw enum strings to users.

---

## 6. Capability Cards

Fixed order:

1. duplicate_cleanup
2. planar_normalization
3. gap_repair
4. structure_reconstruction
5. other_issues

Each card should expose the simplest stable equivalent of:
- id
- state
- title
- summary
- metrics
- primary_action
- detail_target
- reason

Possible presentation states:
- UNCOMPUTED
- CHECKING
- CLEAN
- ACTIONABLE
- REVIEW_REQUIRED
- APPLIED
- BLOCKED
- STALE
- FAILED

Critical truth rule:
`NOT_COMPUTED` must never be rendered as `CLEAN`.

---

## 7. A1 Uses Existing Stepwise Backend Truthfully

A2 orchestration is not implemented yet.

Therefore A1 must NOT fake one-click full diagnosis.

Examples:

### Workspace not prepared
Overall: IDLE
CTA: 开始处理
May call existing `prepare_workspace`.
All capability cards remain visible as 未检查.

### Workspace ready / planar NOT_COMPUTED
Show Z card as 未检查.
Existing action may show `检查平面偏差`.

### Planar actionable
Show `修复 Z 轴` wired to existing `apply_planar_normalization`.

### Gap states
Truthfully map existing V1.7 state.

### Structure states
Truthfully map existing V1.8 state.

The improvement in A1 is that the entire capability stack stays visible together. The backend remains stepwise until A2.

---

## 8. Error-only Primary Summary

Default processing dashboard must not show normal inventory:
- 线段
- 顶点
- 面
- 含洞面

Show only non-zero meaningful current problems.

Rules:
- prefer current prepared-state information where available;
- do not blindly count historical source findings as current unresolved issues;
- if a current count cannot be stated truthfully, omit it rather than guess;
- original source findings remain available under 详情 / 原始检查记录;
- raw inventory remains under 详情 only.

---

## 9. Tabs

### 处理
Default.
Contains:
- header/brand;
- selection;
- overall status;
- primary CTA;
- error-only summary;
- all 5 capability cards;
- recovery banner;
- placeholder position for future V1.9B 最终验证 (no behavior yet).

### 问题
Current unresolved/relevant issues first.
Preserve:
- severity;
- concise Chinese message;
- click-to-locate for locatable issues;
- non-locatable issue rows inert.

### 图层
Port existing layer semantic / visibility data into new visual system.
Do not alter layer logic.

### 详情
Technical/audit:
- source snapshot/fingerprint;
- config digest;
- raw workspace state;
- duplicate/planar/gap audit;
- canonical/structure digest where available;
- raw edge/vertex/face inventory;
- original source issue records if useful.

---

## 10. Visual Fidelity

Port approved A0 visual language:
- cool near-white background;
- white/lightly tinted cards;
- blue-violet accent;
- restrained gradient;
- green success / amber warning / red failure;
- graphite text;
- soft borders and restrained shadows;
- 10–12px card radius;
- clear spacing hierarchy;
- system fonts only;
- bundled/inline static SVG;
- subtle hover/state transitions.

No remote runtime resources.

Legacy-aware:
Do not make correctness depend on CSS Grid, flex gap, backdrop-filter, web fonts, remote icons, or modern-only browser APIs.

---

## 11. Safety / Frontend Contract

Preserve:
- no eval;
- no new Function;
- no document.write;
- no unsafe interpolation of user strings;
- user text through textContent / safe attributes;
- known window.sketchup callbacks only;
- no remote script/style/font/CDN;
- existing locate safety contract.

---

## 12. Existing Callback Compatibility

Preserve existing callback functionality:

- ready
- locate
- close
- prepare_workspace
- discard_workspace
- rebuild_workspace
- compute_planar_normalization
- apply_planar_normalization
- compute_gap_repair
- apply_gap_repair
- compute_structure_reconstruction

No hidden JS chain of multiple callbacks.
A2 owns orchestration.

---

## 13. Tests Required

Presenter focused tests:
- idle mapping;
- workspace ready + planar uncomputed;
- planar actionable;
- gap actionable;
- structure READY;
- structure READY_WITH_WARNINGS;
- stale/failed;
- NOT_COMPUTED never → CLEAN;
- zero issue categories omitted;
- raw inventory absent from primary summary.

UIBridge:
- cadPrepWorkflow exists;
- JSON-safe;
- old payload remains where required;
- no live SU/Ruby object crosses bridge.

DOM:
- 4 tabs exist;
- 处理 default active;
- 5 capability cards in fixed order;
- all capability cards visible;
- inventory absent on 处理;
- technical/raw inventory reachable in 详情;
- locate behavior preserved;
- non-locatable issues inert;
- buttons dispatch correct existing callbacks;
- no unsafe JS/remote asset regression.

Regression:
- full Ruby suite;
- V1.7;
- V1.8;
- V1.6 close-autodiscard;
- LEGACY-COMPAT;
- Node DOM;
- RBZ smoke;
- git diff --check.

If known pre-existing failures remain, report separately and prove they pre-existed. Do not label them PASS.

---

## 14. RBZ

A1 modifies production UI, so rebuild RBZ.

Report:
- path
- byte size
- entry count
- SHA-256
- packaged HTML/CSS/JS hashes if current reporting pattern uses them

A1 RBZ is an internal review candidate only, not final V1.9/V1.x release.

---

## 15. Gate / STOP

When complete:

AIPM_REVIEW = PENDING
CODEX = NOT REQUIRED by default
OWNER_SU2020 = NOT YET
A2 = NOT STARTED
V1.9B = NOT STARTED

STOP.

AIPM will source-review:
1. prototype fidelity;
2. IA;
3. presenter truthfulness;
4. callback preservation;
5. frontend safety;
6. readiness for A2 orchestration.

---

## 16. Required Report

Return:
1. branch/final HEAD;
2. files changed;
3. presenter architecture;
4. actual cadPrepWorkflow schema;
5. raw-state → presentation-state mapping table;
6. DOM/Ruby/RBZ evidence;
7. RBZ identity;
8. known limitations;
9. confirmation no A2/V1.9B work;
10. CODEX_RISK_TRIGGER determination.

STOP.

END
