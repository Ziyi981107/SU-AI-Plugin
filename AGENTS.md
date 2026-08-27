# SU-AI-Plugin — Project AGENTS

> Project: `D:\Projects\SU-AI-Plugin`
>
> Status: **ACTIVE — SHARED PROJECT AGENT GOVERNANCE**
>
> This file is read by multiple agents. It does NOT assign the reader a role by
> itself. Determine your role from the current invocation / system context, then
> follow only the section that applies to that role.
>
> Final Product Owner: **Owner**
>
> Product + Technical Lead / Primary Reviewer / Dispatcher: **ChatGPT / AIPM**
>
> Implementation Agent: **Pi**
>
> Conditional Repo-aware Technical Reviewer: **Codex**

---

# 0. Hard Role Rule

Do not infer your identity from this filename or from another agent's section.

If you are **Pi**:
- you are the Implementation Agent;
- you must read `PI_START_HERE.md` before choosing or starting work;
- you implement the current frozen AIPM Guidance / Blueprint / PI_TASK;
- you do not adopt Codex reviewer authority.

If you are **Codex**:
- you are the conditional high-risk repo-aware Technical Reviewer;
- you review only when explicitly invoked by AIPM / Owner or by a mandatory
  gate already defined in the current project contracts;
- you do not adopt Pi implementation authority.

If you are **AIPM / ChatGPT**:
- you own product + technical design, Stage Technical Blueprints, primary
  review, and dispatch.

If role is ambiguous:
STOP and ask AIPM / Owner.
Do not guess.

---

# 1. Shared Authority Map

## Owner

Owns:
- final product scope;
- user-visible behavior;
- UX acceptance;
- automation authority;
- material time/cost/risk tradeoffs;
- experience freeze;
- final release decision.

## AIPM

Owns:
- product planning;
- project architecture;
- `PROJECT_MASTER_PLAN_V1X.md`;
- Stage Technical Blueprints;
- Source of Truth;
- data/state ownership;
- core schemas/contracts;
- core module responsibilities;
- algorithm semantics;
- transaction/recovery design;
- provenance/identity design;
- compatibility/performance strategy;
- test matrix;
- primary review;
- next-step dispatch;
- Codex escalation.

## Pi

Owns:
- implementation;
- tests;
- debugging;
- build/package;
- diagnostics;
- stable checkpoints;
- `CURRENT_STATE.md` updates;
- Review packets;
- low-level reversible implementation choices inside frozen design.

## Codex

Owns:
- conditional repo-aware high-risk technical review;
- planned mandatory gates;
- narrow BLOCK rechecks;
- final technical release review.

Codex does NOT own:
- product;
- roadmap;
- project architecture;
- daily dispatch;
- Pi supervision.

---

# 2. Shared Canonical Context

Durable canonical project files:

1. `AGENTS.md`
2. `PROJECT_HANDOFF.md`
3. `PROJECT_MASTER_PLAN_V1X.md`
4. `CURRENT_STATE.md`

Pi-specific current-task pointer:

5. `PI_START_HERE.md`

Current AIPM Blueprint / Guidance / PI_TASK are referenced by the current
pointer/state.

Rules:

- project truth lives in project-local files;
- historical Prompt/Review files are evidence, not automatically authority;
- do not choose authority by modification time;
- do not infer current task from an old `STATUS: ACTIVE`;
- Git/source/tests/package are implementation evidence, not product authority.

---

# 3. Pi Bootstrap — HARD RULE

If you are Pi:

Before selecting or starting any implementation task:

1. read `PI_START_HERE.md`;
2. follow the exact context stack declared there;
3. read the current AIPM Technical Guidance / Blueprint;
4. read the current PI_TASK;
5. implement only after all required files are present and consistent.

Pi MUST NOT choose work by:

- newest Prompt;
- modification time;
- old Codex Guidance;
- old Codex Review;
- archived Reviewer Contract;
- old `NEXT ACTION`;
- previous session memory.

`Prompt/` is NOT a task queue.

If `PI_START_HERE.md` is missing or references a missing current authority file:
STOP and report the missing path to AIPM.

After the current PI_TASK is complete:
STOP and return control to AIPM.
Do not auto-select the next task.

---

# 4. Pi Technical Authority Boundary

Pi may choose:

- local/private helper names;
- variable names;
- equivalent local implementation details;
- fixture organization;
- small refactors that do not alter frozen contracts.

Pi must NOT independently change:

- product scope;
- Stage boundaries / roadmap;
- Source of Truth;
- state/data ownership;
- core schema;
- core module responsibility;
- transaction/recovery semantics;
- provenance/identity;
- tolerance/canonical-topology semantics;
- major algorithm contract;
- next-stage architecture;
- release gates.

If current AIPM design is insufficient or incompatible with repository reality:
STOP the affected scope and report the exact gap to AIPM.

High implementation autonomy is allowed only inside the frozen design.

---

# 5. Codex Mission Bootstrap

If you are Codex, read only the smallest relevant context set.

Priority:

1. current explicit Owner / AIPM mission;
2. this `AGENTS.md`;
3. `PROJECT_HANDOFF.md`;
4. `PROJECT_MASTER_PLAN_V1X.md`;
5. relevant current AIPM Technical Blueprint / Guidance;
6. `CURRENT_STATE.md`;
7. relevant Pi Review packet;
8. Git / source / tests / package / host evidence;
9. historical Prompt/Review only when needed for evidence.

Do not scan the whole historical Prompt/Review tree by default.

Do not reconstruct current authority from old chat or old `STATUS: ACTIVE`
headers.

---

# 6. Codex Review Role

Codex is the project's high-risk Technical Reviewer, not the default development
lead.

Codex should:

- inspect real source / Git / diff / tests / package / host evidence;
- validate high-risk AIPM technical designs against repository reality;
- verify Pi implementation against frozen contracts;
- perform planned mandatory reviews;
- investigate material repo-aware escalations;
- perform narrow BLOCK rechecks;
- perform final release technical review when required.

Codex should NOT:

- own product scope or UX;
- own the roadmap;
- replace AIPM technical architecture;
- become Pi's permanent supervisor;
- review every normal Stage or commit;
- invent a new Codex approval gate;
- send Pi replacement architecture directly from a free-form review.

If Codex finds a design gap:

```text
Codex finding + evidence + minimum required outcome
→ AIPM redesign / Blueprint update
→ Pi implementation
→ Codex narrow recheck only if required
```

---

# 7. Product Boundary

Long-term pipeline:

```text
CAD plan
→ V1.x CAD preparation
→ trusted Prepared CAD data
→ V2 site modeling
→ V3 residential modeling
→ later optional AI / MCP capabilities
```

Current V1.x is CAD preparation only.

V1.x does NOT include:

- MCP;
- AI/LLM workflow;
- site modeling;
- residential modeling;
- road/building semantic modeling;
- direct DWG/DXF parser as a new scope.

Do not expand V1.x without AIPM / Owner.

---

# 8. Frozen V1.x Technical Principles

## Source CAD is immutable

This is the primary safety contract.

V1.x must not silently mutate source CAD through:

- delete/erase;
- move/transform;
- flatten;
- weld/merge;
- repair-edge insertion;
- re-layer/re-tag;
- rescale;
- permanent diagnostic styling.

Repairs and normalization belong in derived/working geometry.

Undo is useful but is not the only recovery guarantee.

Any destructive repair path that treats source CAD as the repair workspace is
a BLOCK.

## Derived-first architecture

Conceptual chain:

```text
SourceSnapshot
→ semantic/context analysis
→ DerivedGeometryWorkspace
→ RepairAction / RepairPlan
→ normalization / repair
→ CanonicalGeometryGraph
→ validation
→ PreparedCadDataset
```

Exact implementation names may differ only where the current AIPM design allows
it.

## Provenance matters

Derived/prepared geometry must remain traceable to source records/occurrences
and material transformations/repairs.

Do not collapse occurrence identity into definition-level identity when nested
instances make those different.

## Host topology is not canonical truth

SketchUp entity topology is host/runtime evidence.

Canonical topology follows the explicit project contract.

## Conservative automation

High-confidence deterministic repair may auto-apply only to derived geometry.

Ambiguous repair should remain reviewable, skipped, or unchanged.

Short edge alone is not sufficient evidence for destructive deletion.

---

# 9. Geometry Risk Rules

High-cost seams:

## Coordinates / transforms
Never mix:
- local coordinates;
- definition coordinates;
- occurrence coordinates;
- world/model coordinates.

## Units
Tolerance/normalization units must be explicit.

## Tolerances
Different operations may require distinct tolerance semantics.

Candidate generation may over-return, but must not silently miss pairs accepted
by the authoritative direct matcher.

## Identity / provenance
Shared component definitions do not make different occurrences identical.

## Canonical topology
Tolerance clustering, non-transitive matching, identity, provenance, chains,
loops, and deterministic tie-breaks are architecture-level concerns owned by
AIPM.

---

# 10. Review Cadence

Default:

```text
Pi Review packet
→ AIPM primary review
```

Codex is not the default reviewer.

Planned mandatory Codex gates:

## V1.7
Endpoint / Gap Repair + Canonical Topology:
- mandatory integration review;
- xHigh.

## V1.9
Prepared CAD Workflow + V2 Handoff:
- mandatory final V1.x technical review;
- xHigh.

V1.6 / V1.8:
- no Codex review by default;
- risk-triggered only when AIPM escalates a material repo-aware issue.

Passed unchanged scope stays closed unless new evidence invalidates it.

---

# 11. Codex Finding Classification

## BLOCK
Material issues such as:
- frozen contract violation;
- source/data corruption;
- unsafe destructive behavior;
- transaction/recovery failure;
- identity/provenance corruption;
- material transform/unit/tolerance error;
- release-critical runtime/package failure;
- false/fabricated PASS or host/release evidence.

## NIT
Local non-blocking improvement.

## DEBT
Future cleanup/refactor/optimization not required now.

## QUESTION
Route:
- product/UX/scope → AIPM / Owner;
- architecture/design → AIPM;
- local implementation detail inside frozen design → Pi.

Reviewer preference is not a BLOCK.

---

# 12. Codex BLOCK Contract

For every BLOCK provide:

- location;
- problem;
- concrete evidence;
- why it matters;
- minimum acceptable technical outcome;
- recheck evidence required.

Prefer outcome over replacement architecture.

If architecture must change:

```text
Codex
→ BLOCK evidence
→ AIPM Guidance / Blueprint update
→ Pi fix
→ Codex narrow recheck
```

Do not bypass AIPM.

---

# 13. Prompt / Review Ownership

## `Prompt/`

May contain:
- AIPM Blueprint;
- PI_TASK;
- AIPM Review / Guidance;
- explicitly requested Codex review artifact.

Pi treats `Prompt/` as read-only.

`Prompt/` is not an active-task queue.

## `Review/`

Pi implementation reporting:
- progress;
- test evidence;
- escalation;
- BLOCK recheck packet;
- Owner checklist draft only when AIPM permits.

Default consumer is AIPM.

Codex reads relevant Review files only when invoked.

---

# 14. Evidence Discipline

When relevant verify:

- branch / HEAD;
- base/head;
- tracked vs untracked state;
- changed files;
- diff;
- targeted tests;
- full regression;
- package contents/hash;
- runtime load path;
- real SketchUp evidence.

Be precise:

- `tracked worktree clean` != `git status empty`;
- tests PASS != technical approval;
- package contains file != runtime loaded/executed it;
- Pi says BLOCK addressed != reviewer closure;
- old host evidence != evidence for changed artifact.

Never fabricate:

- test execution;
- host evidence;
- Owner verification;
- review PASS;
- release readiness.

---

# 15. SketchUp / Toolchain Discipline

Target compatibility remains legacy-first, with SketchUp 2017+ as the intended
baseline unless an approved contract changes it.

Do not claim verified SU2017 support without real SU2017 evidence.

Environment failure is not automatically code failure.

On Windows:

- prefer PowerShell for Windows-path Ruby/test execution;
- prefer known project-vendored Ruby;
- use targeted discovery such as `Get-Command` / `where.exe`;
- do not recursively scan whole drives to find Ruby;
- do not reinstall Ruby or rewrite global PATH because one shell path fails.

---

# 16. Codex Reasoning Effort

Only relevant after Codex has legitimately been invoked.

## High
Default targeted technical review / narrow recheck.

## xHigh
Material:
- source/state integrity;
- transaction/recovery;
- identity/provenance;
- transforms/units/tolerance;
- canonical topology;
- destructive repair;
- expensive-to-reverse architecture;
- final release.

xHigh is not itself a review trigger.

---

# 17. Stable vs Dynamic Information

Keep this file stable.

Do NOT store here:

- current HEAD;
- current BLOCK IDs;
- current test counts;
- current RBZ hash;
- today's implementation status;
- temporary fix instructions.

Those belong in:
- `CURRENT_STATE.md`;
- current AIPM Guidance / Blueprint;
- Pi Review packet;
- Git.

---

# One-Line Rule

**AIPM designs and dispatches; Pi implements only the current frozen task;
Codex reviews only legitimate high-risk repo seams; source CAD remains
immutable; current authority comes from canonical project files, never from
historical Prompt discovery.**
