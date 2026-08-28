# SU-AI-Plugin — PROJECT HANDOFF V3.4

> Project: `D:\Projects\SU-AI-Plugin`
>
> Status: **ACTIVE — DURABLE PROJECT CONTRACT**
>
> Final Product Owner: **Owner**
>
> Product + Technical Lead / Primary Source Reviewer / Dispatcher / Final Technical Adjudicator: **ChatGPT / AIPM**
>
> Implementation Agent: **Pi**
>
> Technical Reviewer: **Codex — conditional high-risk repo-aware reviewer**
>
> Canonical V1.x Master Plan: `PROJECT_MASTER_PLAN_V1X.md`

---

## 0. Purpose

This file stores only durable project truths.

It should remain useful across sessions, agents, and development stages without being rewritten for every commit or review.

This file does NOT store:

- current HEAD;
- current branch details;
- current BLOCK IDs;
- current test counts;
- current RBZ hash;
- today's active Prompt;
- temporary recovery instructions;
- one-off implementation decisions.

Those belong in:

- `CURRENT_STATE.md`;
- `Prompt/CURRENT_PI_DISPATCH.md`;
- `Review/CURRENT_PI_REPORT.md`;
- `Review/CURRENT_AIPM_REVIEW.md`;
- durable Stage Technical Blueprint / Guidance / Gate evidence when justified;
- Git.

---

# 1. Product Goal

SU-AI-Plugin is an architectural workflow plugin whose current V1.x line prepares imported CAD geometry inside SketchUp for trustworthy downstream modeling.

Long-term direction:

```text
Imported CAD
→ V1.x CAD preparation
→ trusted Prepared CAD Dataset
→ V2 site modeling
→ V3 residential modeling
→ later optional AI / MCP / rendering / design-assist capabilities
```

V1.x exists to:

- analyze imported CAD;
- explain geometry problems;
- preserve semantic/context information;
- create a safe derived working representation;
- perform conservative deterministic repair;
- normalize appropriate 2D geometry;
- reconstruct trustworthy canonical topology;
- reconstruct chains / loops / regions;
- expose unresolved ambiguity;
- produce a versioned Prepared CAD Dataset for V2.

---

# 2. V1.x Scope

## In Scope

- CAD analysis / preflight;
- issue detection;
- layer semantic interpretation;
- source snapshotting;
- derived working geometry;
- repair planning;
- high-confidence deterministic repair;
- conservative planar normalization;
- canonical geometry/topology;
- chains / loops / regions;
- provenance;
- validation;
- Prepared CAD Dataset;
- user acceptance/discard of prepared result;
- SketchUp packaging / host validation for V1.x.

## Explicitly Out of Scope

- MCP;
- AI/LLM decision making inside V1.x;
- direct DWG/DXF parser implementation;
- site modeling;
- road/building/green semantic recognition;
- terrain;
- site extrusion;
- residential modeling;
- automatic architectural design;
- AI rendering;
- cloud inference;
- destructive overwrite of source CAD.

Any work that crosses this boundary must return to AIPM / Owner before implementation continues.

---

# 3. Product Contract

V1.x must truthfully provide these guarantees:

1. Original source CAD is preserved.
2. Repairs happen on derived/working geometry.
3. Material automated changes are explainable.
4. Ambiguous geometry is not silently guessed into a destructive result.
5. User can distinguish source from prepared result.
6. User can inspect important unresolved issues before acceptance.
7. Prepared output can be discarded/rebuilt.
8. Downstream V2 receives a versioned, provenance-aware Prepared CAD Dataset.
9. V1.x does not claim site/building/road semantics.

Critical product failure:

> A normal V1.x workflow silently damages, mutates, or misrepresents original source CAD.

---

# 4. Experience Contract

The V1.x experience should provide confidence and control without turning into a full CAD authoring application.

Primary information:

- analysis status;
- issue counts;
- repair recommendations/results;
- unresolved issues;
- Prepared CAD readiness.

Secondary information:

- layer semantic diagnostics;
- counts/context;
- technical details.

Material repair explanation should answer:

- what changed?
- why?
- what rule/evidence justified it?
- what source geometry was involved?

Unknown / uncertain state is valid data.

High-confidence deterministic repairs should be batched rather than forcing hundreds of trivial approvals.

Ambiguous actions should remain reviewable at a useful level.

Owner controls visible UX and final experience freeze.

---

# 5. Project-Level Technical Architecture

Canonical architecture:

```text
SketchUp Source Adapter
→ Immutable SourceSnapshot
→ Preflight + Analyzer + LayerSemanticMap
→ DerivedGeometryWorkspace
→ RepairPlan
→ Conservative Deterministic Repair
→ Normalized CanonicalGeometryGraph
→ Chains / Loops / Regions
→ Validation + Unresolved Issues
→ PreparedCadDataset
→ future V2
```

The canonical roadmap and version boundaries are defined by:

```text
PROJECT_MASTER_PLAN_V1X.md
```

Before any meaningful Stage begins Coding, AIPM must produce a Stage Technical Blueprint.

The Master Plan is the map.
The Stage Blueprint is the construction drawing.

---

# 6. Source of Truth / State Ownership

## Source CAD

Authoritative original geometry.

From the plugin's perspective it is immutable.

V1.x must not silently:

- erase;
- move;
- flatten;
- weld;
- merge;
- re-layer;
- re-scale;
- re-coordinate;
- permanently restyle source geometry.

## SourceSnapshot

Immutable analysis representation of selected source geometry.

Used for:

- analysis;
- identity/provenance;
- comparison;
- rebuild.

## DerivedGeometryWorkspace

Disposable working representation.

May be:

- normalized;
- repaired;
- reconstructed;
- discarded;
- rebuilt.

It is not the authoritative original CAD.

## CanonicalGeometryGraph

Explicit internal topology used for downstream reconstruction.

SketchUp host topology is not automatically canonical topology.

## PreparedCadDataset

Accepted/versioned V1.x handoff to V2.

It must preserve enough information for:

- geometry;
- semantic context;
- unresolved warnings;
- provenance;
- readiness;
- version compatibility.

---

# 7. Durable Data Contracts

Conceptual responsibilities that future Stage Blueprints must remain compatible with:

- `SourceSnapshot`
- `LayerSemanticMap`
- `DerivedGeometryWorkspace`
- `RepairAction`
- `RepairPlan`
- `ProvenanceRecord`
- `CanonicalGeometryGraph`
- `PreparedCadDataset`

Exact class/file/helper names may differ.

Core semantics and ownership may not be changed by Pi without an AIPM Blueprint update.

---

# 8. Repair Authority

## High Confidence
May auto-apply only to derived geometry when deterministic evidence is strong and regression coverage exists.

## Medium Confidence
Preview/review by default.

## Low Confidence
Do not auto-repair.

Hard rule:

> Short edge alone is not sufficient evidence for destructive deletion.

Uncertainty must not be hidden by a convenient destructive default.

---

# 9. Failure Preservation / Recovery

A failed or interrupted prepare/repair operation must not corrupt source CAD.

Preferred recovery hierarchy:

1. source remains untouched;
2. derived workspace can be discarded;
3. derived workspace can be rebuilt from source + config;
4. host Undo may provide an additional recovery layer;
5. logs / RepairPlan explain failure.

If derived state becomes partially invalid:

- it must not be presented as READY;
- Stage Blueprint must define whether rollback, compensation, or discard/rebuild is required.

Undo is not the sole recovery architecture.

---

# 10. Geometry / Compatibility Invariants

High-cost seams include:

- world vs local coordinate correctness;
- nested group/component transforms;
- occurrence identity vs shared component definitions;
- units;
- tolerance semantics;
- quantization/bucket boundary behavior;
- source identity fallback;
- entity invalidation;
- selection scope;
- canonical topology;
- provenance.

Target compatibility remains legacy-first with SketchUp 2017+ as the intended baseline.

Do not claim verified SU2017 support without real SU2017 evidence.

---

# 11. Role Ownership

## Final Product Owner

Owns:

- product outcome;
- product scope;
- visible UX;
- user-facing automation authority;
- meaningful time/cost/risk tradeoffs;
- experience freeze;
- final release decision.

Owner does not need to design technical internals.

---

## AIPM

Owns:

- product planning;
- V1.x Master Plan;
- project architecture;
- Stage Technical Blueprints;
- Source of Truth;
- state/data ownership;
- core schemas/data contracts;
- core module responsibilities;
- algorithm semantics;
- transaction/recovery;
- provenance/identity;
- compatibility/performance strategy;
- test matrix;
- primary Review;
- next-step Dispatch;
- whether Codex is required.
- direct real-source review;
- Codex finding adjudication;
- technical Gate decisions;
- approval to merge `main` after Gate PASS.

Default review flow:

```text
Prompt/CURRENT_PI_DISPATCH.md
→ Pi complete implementation + tests + stable commit
→ assigned dev/vX.Y
→ Review/CURRENT_PI_REPORT.md
→ AIPM direct source review
→ Review/CURRENT_AIPM_REVIEW.md
→ optional Codex review when triggered
→ AIPM adjudication and next action
```

---

## Pi

Owns:

- implementation;
- tests;
- debugging;
- build/package;
- diagnostics;
- stable Git checkpoints;
- final stable submission commit;
- CURRENT_STATE updates;
- `Review/CURRENT_PI_REPORT.md`;
- complete-dispatch submission to the assigned `dev/vX.Y`;
- durable Review artifacts when long-term evidence is justified;
- low-level reversible implementation choices inside a frozen Blueprint.

Pi may choose:

- local/private helper names;
- variables;
- equivalent local implementation details;
- fixture organization;
- small refactors that do not alter contract.

Pi must not independently change:

- product scope;
- Stage boundaries/roadmap;
- Source of Truth;
- state ownership;
- core schema;
- core module responsibility;
- transaction/recovery;
- provenance/identity;
- tolerance/canonical topology semantics;
- major algorithm contract;
- next-stage architecture.

If the Blueprint is insufficient, Pi stops the affected scope and reports the gap to AIPM.

---

## Codex

Codex is the conditional high-risk repo-aware Technical Reviewer.

Use Codex for:

- planned mandatory gates;
- material repo-aware architecture validation;
- source/state integrity;
- provenance/identity;
- transaction/recovery;
- transforms/units/tolerance;
- canonical topology;
- package/runtime;
- target-host compatibility;
- narrow BLOCK rechecks;
- final technical release review.

Codex does not own:

- product;
- roadmap;
- technical architecture;
- primary review;
- daily dispatch;
- Pi supervision.

A Codex BLOCK that requires design change routes back through AIPM.
Codex is review-only by default: no code changes, commit, push, or merge.
Codex findings are evidence; AIPM records the final
Accepted / Downgraded / Rejected adjudication.

---

# 12. Current Communication and Durable Artifacts

Permanent workflow:

- `PI_START_HERE.md` is Pi's stable bootstrap entry.
- `Prompt/CURRENT_PI_DISPATCH.md` is the sole normal formal current
  AIPM -> Pi implementation dispatch.
- `Review/CURRENT_PI_REPORT.md` is the sole normal current Pi -> AIPM
  implementation return.
- `Review/CURRENT_AIPM_REVIEW.md` is the sole normal current AIPM source-review
  record.

Pi treats `Prompt/` as read-only and does not write it as the normal return
channel. Pi does not use `Review/` to discover tasks. AIPM does not treat
`Prompt/` as implementation evidence.

Historical Prompt/Review files remain evidence only. They cannot become current
authority through filename, numbering, modification time, or stale
`STATUS: ACTIVE`.

Do not create versioned Prompt/Review files for every small iteration. The
CURRENT files serve normal daily work, while Git provides fine-grained
implementation history.

Separately named durable artifacts remain appropriate for Stage Technical
Blueprints, major architecture/data/schema contracts, important migrations,
mandatory Codex Gate reviews, Owner verification, Stage closure, release
reports, material risk acceptance, and other evidence likely to matter later.

AIPM decides whether an instruction needs the formal dispatch or a referenced
durable Blueprint / Guidance. A short direct chat instruction is allowed only
for a small continuation inside an already frozen ACTIVE dispatch and must
never silently alter architecture, product contract, Stage scope, or release
authority.

---

# 13. Mandatory Review Strategy

V1.x planned Codex gates:

- V1.4 — Derived Workspace / mutation ownership — CLOSED unless new evidence invalidates it.
- V1.7 — Endpoint / Gap Repair + Canonical Topology — MANDATORY xHigh integration review.
- V1.9 — Prepared CAD Workflow + V2 Handoff — MANDATORY xHigh final V1.x review.

V1.6 / V1.8 do not require Codex by default.

Between planned gates, Codex review is risk-triggered only.

High/xHigh reasoning level does not itself create a review gate.

---

# 14. Test / Evidence Contract

Testing is risk-driven.

Durable expectations:

- source integrity checks for mutation-capable stages;
- representative should-work cases;
- must-not-act cases;
- tolerance/transform/unit boundary cases;
- failure/recovery tests;
- regressions for material real bugs;
- package/runtime evidence;
- real SketchUp evidence at meaningful product/release gates;
- representative private company CAD/SKP Golden fixtures by V1.9 where available.

Automated PASS does not replace required real-host evidence.

Package contents do not by themselves prove runtime load/execution.

---

# 15. Git / Toolchain Discipline

Git checkpoints are recovery/evidence mechanisms, not governance gates.

Pi may create a local commit at a meaningful stable checkpoint, including a
complete validated small task, a stable sub-stage, a rollback point before a
clearly high-risk refactor/mutation, Stage/Gate completion, or another
explicitly requested checkpoint.

Do not commit after every trivial edit or present a known broken state as
stable. An explicitly necessary diagnostic/broken checkpoint must be labelled
truthfully.

Pi may create multiple local commits. Pi formally pushes only after the entire
current Dispatch, required evidence, `CURRENT_STATE.md`,
`Review/CURRENT_PI_REPORT.md`, and the final stable commit are complete, and Pi
is ready to STOP. The formal submission goes only to the assigned
`dev/vX.Y`; it does not require separate per-push Owner/AIPM permission.

Pi must never push/merge `main`, force-push, rewrite shared remote history,
rebase published/shared history, create a release/tag, destructively reset away
another agent's work, or squash/rewrite checkpoints merely to make history
look cleaner.

Keep:

- meaningful stable commits;
- clear base/head for reviews;
- tracked/untracked distinction;
- truthful test/build/package evidence.

Environment/toolchain failure is not automatically product-code failure.

On Windows:

- prefer known/project-vendored Ruby where available;
- prefer targeted executable discovery;
- avoid recursive full-drive Ruby searches;
- do not reinstall/rewrite global PATH merely because one shell path fails;
- record durable environment pitfalls in `CURRENT_STATE` / stable project context.

---

# 16. Source Review, Gate, Main, and Release Rule

AIPM may not claim Source Review PASS from a Pi report alone. AIPM must
directly inspect the real diff, affected upstream/downstream source, and
relevant tests.

Keep three states distinct:

- **Pi Complete** - finished, self-tested, stable commit, submitted to
  `dev/vX.Y`.
- **AIPM PASS** - AIPM directly reviewed real source/diff and relevant
  evidence.
- **Gate PASS** - ordinary low-risk AIPM Gate, or for mandatory/high-risk
  scope, AIPM PASS + Codex repo-aware review + AIPM adjudication.

After Gate PASS, AIPM may approve merge into `main`.

`main` is the technical stable line. Formal release/tag/external delivery
remains a separate Final Product Owner decision. Stable `main` is not itself a
formal release.

Formal release requires, as applicable:

```text
AIPM technical/product gate
→ Owner complete user-flow verification
→ Owner experience freeze
→ Release Candidate
→ critical regression/package evidence
→ target-environment E2E
→ mandatory Final Codex Review
→ no unresolved release BLOCK
→ Owner release decision
```

Packaging before experience freeze is technical smoke evidence only.

A changed release artifact requires evidence for that changed artifact.

---

# 17. Stable vs Dynamic Information

This file changes only when durable project truth changes.

Examples:

- product boundary;
- architecture;
- Source of Truth;
- ownership;
- high-cost invariant;
- review strategy;
- release strategy.

Dynamic project status belongs in `CURRENT_STATE.md`. Normal current task and
implementation-return content belongs in `CURRENT_PI_DISPATCH.md` and
`CURRENT_PI_REPORT.md`.

The project must not again depend on a Master Plan or active contract that lives only in an external Downloads directory.

Canonical long-term project contracts must live inside:

```text
D:\Projects\SU-AI-Plugin
```

---

# 18. Durable Lessons

1. High-autonomy implementation does not mean high-autonomy architecture design.
2. Expensive technical decisions must be frozen before Coding.
3. Stage is the technical design unit, not commit.
4. AIPM is the default Review/Dispatch layer.
5. Codex is high-leverage review capacity, not a permanent project governor.
6. Source CAD immutability and derived/discardable repair are stronger guarantees than Undo alone.
7. Project truth must live in stable project-local files, not external Downloads paths or old chat history.

---

# One-Line Project Contract

**Preserve source CAD, build trustworthy derived/canonical Prepared CAD data, let AIPM design and review, let Pi execute, use Codex only for legitimate high-risk repo-aware gates, and keep durable project truth inside the repository.**
