# SU-AI-Plugin — PROJECT MASTER PLAN V1.x

> Project: `D:\Projects\SU-AI-Plugin`
>
> Status: **ACTIVE — V1.x PRODUCT + TECHNICAL MASTER PLAN**
>
> Planning / Technical Design Owner: **ChatGPT / AIPM**
>
> Final Product Owner: **Owner**
>
> Implementation Agent: **Pi**
>
> Technical Reviewer: **Codex (conditional high-risk repo-aware reviewer)**
>
> Scope boundary: **V1.x = CAD preparation only. No MCP / No AI / No site modeling / No residential modeling.**

---

## 0. Purpose

This document is the project-local canonical map for the SU-AI-Plugin V1.x line.

It freezes the expensive-to-change product and technical decisions that must remain coherent across V1.4–V1.9, while leaving each meaningful stage to be specified in a separate AIPM Stage Technical Blueprint before coding.

This file defines:

- the V1.x product outcome;
- V1.x non-goals;
- the architectural direction;
- source / derived ownership;
- durable data contracts;
- repair authority;
- V1.4–V1.9 stage boundaries and dependencies;
- the V1 → V2 handoff contract;
- high-cost invariants;
- review and release strategy.

This file does **not** store:

- current HEAD;
- current active BLOCKs;
- current test counts;
- today's active Prompt;
- temporary repair instructions;
- implementation-level helper choices.

Those belong in `CURRENT_STATE`, active AIPM Guidance / Blueprint, Pi Review packets, and Git.

---

# 1. Product Outcome

V1.x is not a generic SketchUp cleaner.

It is the CAD preparation layer for an architectural-scheme workflow:

```text
CAD plan
→ V1.x CAD analyze / clean / normalize / reconstruct
→ trusted Prepared CAD data
→ V2 site modeling
→ V3 residential modeling
→ later optional AI / MCP / rendering / design-assist capabilities
```

The V1.x user outcome is:

> A designer can select CAD geometry already imported into SketchUp, understand what is wrong with it, produce a cleaned and reconstructed DERIVED representation, review material ambiguity, and finish with a stable Prepared CAD Dataset that downstream V2 can trust — without destroying or silently altering the original imported CAD.

V1.x is usable when:

1. Source CAD remains intact.
2. Geometry problems can be analyzed and explained.
3. Layer semantics and visibility uncertainty are explicit.
4. High-confidence deterministic repairs can be applied only to derived geometry.
5. Ambiguous repairs remain reviewable instead of guessed.
6. Planar normalization does not silently destroy intentional geometry.
7. Topology can be reconstructed into stable nodes, chains, loops, and regions.
8. Remaining unresolved defects remain visible.
9. The user can accept or discard the prepared result.
10. A versioned `PreparedCadDataset` exists for V2.
11. V1.x does not perform site/building/road semantic modeling.

---

# 2. Explicit V1.x Non-Goals

Not part of V1.x:

- DWG/DXF importer implementation;
- direct CAD-file parsing engine;
- MCP;
- LLM/AI decision making;
- cloud inference/service;
- Agent architecture inside the product;
- road recognition;
- building recognition;
- green-space recognition;
- curb/sidewalk semantic generation;
- site height rules;
- terrain generation;
- extrusion / site 3D modeling;
- residential building generation;
- parametric housing;
- AI rendering;
- AI color-plan generation;
- automatic architectural design decisions;
- multi-user cloud synchronization;
- destructive overwrite of source CAD.

If implementation work reaches for these, stop the affected scope and route back to AIPM / Owner.

---

# 3. Frozen Product Principles

## 3.1 Company-first + Generic Core

V1.x should work well on the company's real CAD workflow first.

But:

- core geometry logic must not hard-code one project;
- layer names must not be scattered through algorithms;
- project/company differences belong in profiles / rules / config;
- generic geometry behavior must remain reusable.

Preferred configuration layering:

```text
Core defaults
→ selected Profile
→ temporary session overrides
```

---

## 3.2 Analyze → Plan → Repair → Review → Validate

V1.x must not become a black-box one-click cleaner.

The intended product authority flow is:

```text
Analyze
→ issues + semantic context
→ Repair Plan
→ high-confidence deterministic repair on DERIVED geometry
→ ambiguous items remain reviewable
→ validate topology/result
→ user accepts or discards prepared output
```

All material automated behavior must be explainable.

---

## 3.3 Legacy-first

Target compatibility baseline remains SketchUp 2017+.

Principles:

- core must not depend on modern-only APIs;
- capability detection is preferred to scattered version checks;
- newer-host optimizations belong behind compatibility/capability adapters;
- Ruby syntax must remain compatible with the supported runtime baseline;
- real-host evidence matters more than unit-test-only claims.

Formal SU2017 support must not be claimed without real SU2017 evidence.

---

## 3.4 Simple First, Measurable First

Do not build an academic CAD kernel.

Prefer the simplest correct structures for real architectural CAD scale.

Avoid:

- speculative million-edge architecture;
- broad abstraction layers without current need;
- large refactors without product/risk payoff;
- obvious full pairwise scans where hashes/buckets/adjacency solve the real problem.

Measure before optimizing.

---

# 4. Central Architecture Invariant

## SOURCE CAD IS IMMUTABLE

Repair happens on derived geometry.

The project must maintain two worlds:

### A. Source World
- original imported SketchUp entities;
- immutable from the plugin's perspective;
- used for provenance, comparison, and rebuild.

### B. Derived / Working World
- geometry/records derived from source;
- safe to normalize, repair, reconstruct, and discard;
- may become the accepted Prepared CAD output.

Source must never be silently:

- erased;
- moved;
- flattened;
- welded;
- merged;
- re-layered;
- re-scaled;
- re-coordinated;
- permanently recolored for diagnostics.

Undo is an additional host-level safety layer, not the only recovery architecture.

Any normal workflow that destructively repairs source CAD is a release BLOCK.

---

# 5. Durable Logical Data Contracts

These are conceptual responsibilities, not mandatory class names.

## 5.1 SourceSnapshot

Immutable analysis representation of selected source geometry.

Must preserve enough information for:

- source selection identity;
- raw coordinates;
- world/local transform context;
- unit/coordinate context;
- geometry records;
- layer/tag metadata;
- persistent/source references where available;
- nested occurrence identity where necessary;
- provenance and rebuild.

---

## 5.2 LayerSemanticMap

Separates:

- semantic role;
- visibility state.

Rules:

- `unknown` is valid;
- role and visibility are separate dimensions;
- semantics must not mutate source layers/tags;
- interpretation should remain explainable.

---

## 5.3 DerivedGeometryWorkspace

Disposable working representation.

Must:

- preserve source;
- maintain provenance;
- support repair/normalization;
- be discardable/rebuildable;
- never silently become the authoritative original CAD.

---

## 5.4 CanonicalGeometryGraph

Explicit normalized topology representation.

Conceptually includes:

- canonical nodes/vertices;
- canonical edges;
- adjacency;
- chains/polylines;
- loops;
- regions later;
- provenance.

SketchUp host topology is not automatically the canonical topology.

---

## 5.5 RepairAction / RepairPlan

Every material repair must be representable as an explicit action.

Conceptually preserve:

- action identity;
- action type;
- rule;
- confidence;
- reason/explanation;
- source records;
- affected derived records;
- before/after summary;
- topology impact;
- status;
- validation result.

Confidence is rule/evidence driven, not fake AI confidence.

---

## 5.6 ProvenanceRecord

Prepared geometry must remain traceable to:

- original source occurrence/record;
- normalization history;
- repair actions;
- profile / rule / tolerance version where material.

---

## 5.7 PreparedCadDataset

Final V1.x output contract consumed by V2.

Must be versioned.

Conceptual contents:

- schema/dataset version;
- source snapshot identity;
- profile + rule/tolerance version;
- coordinate/unit metadata;
- LayerSemanticMap;
- canonical geometry;
- chains/polylines;
- closed loops;
- regions where available;
- unresolved warnings/issues;
- provenance / repair history;
- validation summary;
- readiness state.

Readiness:

```text
NOT_READY
READY_WITH_WARNINGS
READY
```

Exact storage/serialization is Stage-level engineering design, but the semantics above are durable.

---

# 6. Repair Authority Model

## High Confidence

May auto-apply only to DERIVED geometry when deterministic evidence is strong and regression coverage exists.

Examples:

- exact duplicate edge;
- reversed exact duplicate edge;
- clearly degenerate artifacts when safely proven;
- mathematically equivalent cleanup with no semantic ambiguity.

Short edge alone is not sufficient evidence for deletion.

## Medium Confidence

Preview/review by default.

Examples:

- small gap closure with supporting evidence;
- endpoint merge within tolerance;
- selective planar normalization;
- chain merge where intent is ambiguous.

## Low Confidence

Do not auto-repair.

Examples:

- ambiguous gaps;
- uncertain non-zero Z;
- conflicting loops;
- unknown semantic role affecting treatment;
- repairs that erase multiple plausible interpretations.

Uncertainty must not be hidden by destructive defaults.

---

# 7. Stage Map

Stage is the design unit, not commit.

Every meaningful Stage requires an AIPM Technical Blueprint before coding.

---

## V1.4 — Derived Workspace + Repair Foundation

### Product Goal
Create the safe mutation boundary needed for all later repair work.

### Durable Scope
- DerivedGeometryWorkspace;
- source vs derived ownership;
- provenance foundation;
- RepairPlan lifecycle;
- apply/discard/rebuild;
- source-integrity verification;
- minimum reproducibility metadata.

### Critical Failure
Source CAD mutation through normal V1.4 workflow.

### Review
Mandatory Codex review.

### Status
Closed unless current Git changes invalidate the reviewed contract.

---

## V1.5 — High-confidence Auto Repair

### Product Goal
Perform deterministic useful cleanup without becoming destructive or opaque.

### Durable Scope
- high-confidence auto-repair only;
- exact/reversed duplicate cleanup on derived geometry;
- safe degenerate handling where proven;
- idempotency;
- provenance;
- truthful before/after metrics;
- applied/skipped/failed audit.

### Hard Rule
Short edge alone is not auto-delete evidence.

### Review
No permanent version-number gate by default.

Codex review is risk-triggered when source/provenance/transaction/tolerance/state correctness becomes material.

Current V1.5 status belongs in `CURRENT_STATE`, not here.

---

## V1.6 — Planar Normalization / Z Policy

### Product Goal
Prepare 2D architectural CAD for reliable topology without silently flattening intentional geometry.

### Durable Scope
- raw vs normalized coordinates;
- Z diagnostics;
- derived-only normalization;
- conservative rule/profile selection;
- uncertain geometry retained/reviewable;
- raw coordinates/provenance preserved;
- XY preservation for Z-only normalization;
- unit/transform correctness.

### Hard Rules
- never flatten source;
- never flatten all geometry by default;
- unresolved intent → no destructive action.

### Review
No Codex review by default.

Risk-triggered only if material repo-aware issues involve:
- transforms;
- units;
- canonical coordinate semantics;
- source/derived divergence;
- destructive normalization;
- recovery/provenance.

Before coding V1.6, AIPM must create a full V1.6 Stage Technical Blueprint.

---

## V1.7 — Endpoint / Gap Repair + Canonical Topology

### Product Goal
Convert cleaned geometry into a trustworthy connected canonical topology.

### Durable Scope
- canonical nodes;
- tolerance-aware endpoint clustering;
- adjacency rebuild;
- conservative gap proposal/repair;
- branch/crossing safety;
- deterministic semantics/tie-breaks;
- canonical edge provenance;
- repair/discard/recovery;
- real-scale performance.

### Hard Rule
Endpoint proximity is only a candidate signal, not proof of intended connection.

### Review
**MANDATORY Codex xHigh integration review.**

Reason:
- tolerance;
- identity;
- transforms;
- topology;
- provenance;
- downstream correctness.

---

## V1.8 — Polyline / Closed Loop / Region Reconstruction

### Product Goal
Produce stable structures that downstream site modeling can consume.

### Durable Scope
- chains/polylines;
- closed-loop detection;
- self-intersection/open-chain/repeated-vertex detection;
- nested loops/holes;
- region reconstruction;
- loop-level unresolved issues;
- optional disposable derived face preview for validation only.

### Hard Rule
V1.8 does not assign site semantics.

### Review
No Codex review by default.

Risk-triggered only if canonical graph, provenance, or state ownership architecture changes materially.

---

## V1.9 — Prepared CAD Workflow + V2 Handoff

### Product Goal
Finish V1.x as one coherent CAD-preparation product.

### Final User Flow

```text
Select imported CAD
→ Analyze / Preflight
→ Review issues + layer semantics
→ Create Derived Working Copy
→ Preview repair plan
→ Apply high-confidence repairs
→ Review/skip ambiguity
→ Normalize safe 2D geometry
→ Rebuild canonical topology
→ Reconstruct chains/loops/regions
→ Inspect remaining issues
→ Validate
→ Accept PreparedCadDataset
→ future V2
```

### V2 Handoff Contract

V1 may state:

- canonical edges/chains/loops/regions are stable;
- layer roles/provenance;
- unresolved issues;
- dataset readiness.

V1 must not state:

- this loop is definitely a road;
- this is a residential building;
- extrude this curb;
- generate the site model.

Those belong to V2.

### Release Evidence

By V1.9, require:

- source integrity;
- critical repair regressions;
- canonical topology / loop regressions;
- representative company Golden CAD/SKP fixtures where available;
- real SketchUp target-environment E2E;
- package/runtime evidence;
- Owner experience freeze;
- versioned PreparedCadDataset;
- documented unresolved limitations.

### Review
**MANDATORY Codex xHigh final V1.x review.**

---

## V1.9.x — Stabilization

Allowed:

- bug fixes;
- compatibility fixes;
- measured performance fixes;
- packaging fixes;
- Golden-case regressions;
- small Owner-approved UX clarity fixes.

Not allowed:

- new CAD capability disguised as hardening;
- V2 site semantics;
- MCP;
- AI;
- broad aesthetic refactor without material benefit.

---

# 8. UX Contract Across V1.x

The UI does not need to become a full CAD authoring application.

It must create confidence and control.

Primary information:

- analysis status;
- critical issue counts;
- repair recommendations/results;
- unresolved issues;
- Prepared CAD readiness.

Secondary information:

- layer semantic diagnostics;
- counts/context;
- technical details.

Source trust:

- source CAD is preserved;
- repair applies to prepared/working geometry;
- prepared result can be discarded.

Material repair explanation should answer:

- what changed?
- why?
- how certain is the rule?
- what source geometry was involved?

Unknown is valid data.

Batch high-confidence actions.
Do not make users approve hundreds of deterministic exact-duplicate removals one by one.

Ambiguous actions should be grouped and reviewable at a useful level.

---

# 9. Failure / Recovery Contract

A failed or interrupted prepare/repair operation must not corrupt source CAD.

Recovery hierarchy:

1. source remains untouched;
2. derived workspace can be discarded;
3. derived workspace can be rebuilt from source + config;
4. host Undo may provide an additional layer;
5. logs/RepairPlan explain failure location.

If derived state becomes partially mutated and invalid:

- do not present it as READY;
- rollback transactionally where the Stage contract requires it;
- otherwise invalidate and require discard/rebuild.

Stage Blueprints must define transaction / commit / abort / rollback / compensation / retry / uncertain-commit semantics whenever mutation/state persistence becomes material.

---

# 10. Geometry / Identity Hard Rules

Codex and AIPM should treat these as high-cost seams:

## World vs Local Coordinates
Nested group/component transforms must remain correct.

## Shared Component Definitions
Different occurrences sharing one definition are not automatically the same world-space geometry.

## Unit Handling
SketchUp internal length behavior must not be confused with arbitrary unitless/mm floats.

## Tolerance Boundaries
Quantization/buckets must not create silent misses or false merges at cell boundaries.

## Source Identity
Persistent IDs may not exist in every supported host capability.
Fallback must not invent stronger identity guarantees than it actually has.

## Entity Invalidation
Erased/invalid host entities must not crash the whole workflow.

## Selection Scope
Do not silently expand selected scope to the entire model without a product contract.

---

# 11. Performance Principles

Target:
interactive enough for real company CAD, not theoretical extreme CAD.

Measure where relevant:

- source edge count;
- snapshot time;
- analysis time;
- derived workspace build;
- repair-plan time;
- repair time;
- topology rebuild;
- loop reconstruction;
- approximate memory/IO where practical.

Prefer:

- hashes;
- quantized coordinates;
- adjacency maps;
- spatial buckets/grid;
- bounding-box pruning.

Avoid obvious unbounded pairwise work where a simple indexed structure solves the real case.

---

# 12. Test Strategy

Testing is risk-driven.

## Source Integrity Set — Critical
For every mutation-capable Stage:
- capture source state/fingerprint;
- run workflow;
- prove source geometry/layers/transforms remain unchanged.

Any normal workflow source mutation = BLOCK.

## Capability / Synthetic Set
Cover representative should-work, must-not-act, boundary, failure, recovery, and regression cases.

## Regression Set
Material real bugs and Reviewer BLOCKs should become targeted regression cases where practical.

## Company Golden Dataset
By V1.9:
- 3–5 representative real CAD/SKP samples if available;
- local/private;
- not silently committed to public Git;
- normal + messy cases;
- expected major issues/outcomes recorded.

## Real Host
At meaningful product/release gates:
- installed RBZ;
- real SketchUp;
- real selection;
- analyze;
- create prepared copy;
- repair;
- review;
- validate;
- accept/discard;
- recovery/Undo where relevant;
- units/scale.

Unit tests never replace required real-host evidence.

---

# 13. Review Strategy

AIPM is the default first-line reviewer.

Normal path:

```text
Pi Review packet
→ AIPM review
→ Continue / Fix / Update Blueprint / Owner Gate / Codex escalation
```

Codex is conditional.

### Mandatory Codex gates
- V1.4 — closed unless invalidated by new evidence.
- V1.7 — mandatory xHigh integration review.
- V1.9 — mandatory xHigh final V1.x review.

### Risk-triggered Codex review
Use only when reliable judgment requires real repo/Git/diff/host evidence for material risk such as:
- source mutation;
- state ownership;
- transaction/recovery;
- provenance/identity;
- transform/unit/tolerance;
- canonical topology;
- package/runtime;
- release-critical compatibility.

Passed unchanged scope stays closed.

BLOCK rechecks are narrow.

Codex does not create the next development gate by itself.

---

# 14. Role Boundaries

## Owner
Owns:
- product outcome;
- user-visible behavior;
- UX acceptance;
- automation authority;
- material time/cost/risk tradeoffs;
- final release.

## AIPM
Owns:
- product planning;
- this Master Plan;
- project architecture;
- Stage Technical Blueprints;
- Source of Truth/state ownership;
- core data contracts;
- algorithms/semantics;
- transaction/recovery design;
- compatibility/performance strategy;
- test matrix;
- primary review;
- dispatch;
- Codex escalation decision.

## Pi
Owns:
- implementation;
- tests;
- debugging;
- build/package;
- diagnostics;
- stable checkpoints;
- low-level reversible choices inside frozen Blueprint.

Pi may choose:
- private helper names;
- local variable names;
- equivalent local implementation details;
- fixture organization;
- small internal refactors that do not alter contract.

Pi must not independently change:
- Stage boundaries/roadmap;
- Source of Truth;
- state ownership;
- core schemas;
- core module responsibilities;
- transaction/recovery;
- provenance/identity;
- tolerance/canonical-topology semantics;
- major algorithm contract;
- next-stage architecture.

If Blueprint is insufficient, Pi stops the affected scope and reports the gap to AIPM.

## Codex
Owns:
- conditional repo-aware high-risk technical review;
- mandatory gates;
- narrow BLOCK recheck;
- final technical release review.

Codex does not own product or technical architecture.

---

# 15. Version / Git Discipline

- preserve historical passed evidence;
- each meaningful Stage should have stable checkpoints;
- `CURRENT_STATE` records current progress and active pitfalls;
- `PROJECT_HANDOFF` stores durable project contract;
- this file defines the V1.x roadmap;
- Stage Blueprints define current construction details;
- old Gate evidence does not prove a changed artifact;
- do not silently rewrite history.

---

# 16. V1.x Completion Definition

V1.x is complete when we can truthfully say:

> We have a conservative, explainable, non-destructive CAD preparation system for imported SketchUp CAD. It can analyze problems, interpret layer roles, create a safe working copy, perform high-confidence deterministic cleanup, normalize appropriate 2D geometry, reconstruct trustworthy topology and loops, surface unresolved ambiguity, and hand a versioned Prepared CAD Dataset to the next modeling layer without modifying the original CAD.

V1.x is not complete merely because:

- a cleaner button works;
- a face appears;
- issue counts go down;
- one demo CAD looks good;
- automated tests pass without required real-host evidence.

---

# One-Line Architecture

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

**NO MCP. NO AI. NO SITE MODELING. NO SOURCE DESTRUCTION.**
