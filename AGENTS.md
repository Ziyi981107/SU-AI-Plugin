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
> Product + Technical Lead / Primary Source Reviewer / Dispatcher / Final Technical Adjudicator: **ChatGPT / AIPM**
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
- you implement only an authorized ACTIVE
  `Prompt/CURRENT_PI_DISPATCH.md` and its referenced frozen AIPM contracts;
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
- Owner verification;
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
- acceptance criteria;
- release gates;
- primary review;
- next-step dispatch;
- Codex escalation.
- direct real-source review;
- final adjudication of Codex findings;
- technical Gate decisions;
- approval to merge `main` after Gate PASS.

## Pi

Owns:
- implementation;
- tests;
- debugging;
- build/package;
- diagnostics;
- stable checkpoints;
- final stable submission commit;
- `CURRENT_STATE.md` updates;
- `Review/CURRENT_PI_REPORT.md` updates;
- complete-dispatch submission to the assigned `dev/vX.Y` branch;
- durable Review artifacts when AIPM determines long-term evidence is justified;
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

Codex is review-only by default:
- no source/test/governance modification;
- no commit;
- no push;
- no merge.

Codex findings are technical evidence. AIPM records the final
Accepted / Downgraded / Rejected adjudication.

---

# 2. Shared Canonical Context

Durable canonical project files:

1. `AGENTS.md`
2. `PROJECT_HANDOFF.md`
3. `PROJECT_MASTER_PLAN_V1X.md`
4. `CURRENT_STATE.md`

Permanent Pi bootstrap entry:

5. `PI_START_HERE.md`

Normal current communication files:

6. `Prompt/CURRENT_PI_DISPATCH.md` - sole normal formal AIPM -> Pi dispatch.
7. `Review/CURRENT_PI_REPORT.md` - sole normal Pi -> AIPM implementation
   return.
8. `Review/CURRENT_AIPM_REVIEW.md` - sole normal current AIPM source-review
   record.

Durable AIPM Blueprint / Guidance artifacts are read only when explicitly
referenced by the current dispatch or otherwise required by canonical project
context.

Rules:

- project truth lives in project-local files;
- historical Prompt/Review files are evidence, not automatically authority;
- no file becomes current by modification time, filename numbering, or stale
  `STATUS: ACTIVE`;
- `CURRENT_PI_REPORT.md` is implementation evidence, not task authority;
- Git/source/tests/package are implementation evidence, not product authority.

---

# 3. Pi Bootstrap — HARD RULE

If you are Pi, before selecting or starting implementation work:

1. read `PI_START_HERE.md`;
2. follow its permanent context stack;
3. read `Prompt/CURRENT_PI_DISPATCH.md`;
4. read every durable Blueprint / Guidance explicitly referenced by that file;
5. execute only when the dispatch is ACTIVE, internally consistent, and the
   project's normal user authorization / Proceed flow is satisfied.

Pi MUST NOT choose work by:

- modification time;
- latest/newest filename or highest number;
- historical `STATUS: ACTIVE`;
- historical Prompt or Review files;
- old Codex Guidance;
- old Codex Review;
- archived Reviewer Contract;
- old `NEXT ACTION`;
- previous session memory.

`Prompt/` is NOT a task queue. `Review/` is NOT task authority.

If `PI_START_HERE.md` or `CURRENT_PI_DISPATCH.md` is missing, malformed, or
contradictory, or if the dispatch says `STATUS: NO ACTIVE DISPATCH`, Pi must
STOP and report the problem to AIPM. Do not guess.

After the current dispatch is complete, Pi must update `CURRENT_STATE.md` and
`Review/CURRENT_PI_REPORT.md`, create the final stable commit, push only the
assigned `dev/vX.Y` branch as the complete-task submission, then STOP and
return control to AIPM. Do not auto-select the next task.

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
- product UX;
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

Permanent mandatory/high-risk triggers include:
- state/data ownership;
- transaction/recovery/Undo;
- cross-module core architecture;
- SketchUp/host compatibility;
- destructive action;
- package/install/runtime/release-critical behavior;
- Stage/Version final high-risk technical Gate.

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

# 13. Prompt / Review Communication

Normal daily direction:

- `Prompt/` = AIPM -> Pi.
- `Review/` = Pi -> AIPM.

Normal current files:

- `Prompt/CURRENT_PI_DISPATCH.md` is the sole normal formal current
  implementation dispatch.
- `Review/CURRENT_PI_REPORT.md` is the sole normal current implementation
  return.
- `Review/CURRENT_AIPM_REVIEW.md` is the sole normal current AIPM
  source-review record.

Pi treats `Prompt/` as read-only and does not write it as the normal task
return channel. Pi does not use `Review/` to discover work. AIPM does not
treat `Prompt/` as implementation evidence.

`AGENTS.md`, `PROJECT_HANDOFF.md`, `PROJECT_MASTER_PLAN_V1X.md`,
`CURRENT_STATE.md`, and `PI_START_HERE.md` are project governance/context,
not directional task messages.

Do not create separately versioned Prompt/Review artifacts for every small
iteration. Use the CURRENT files for normal daily work. Create durable
separately named artifacts only when long-term reference is justified, such as
a Stage Technical Blueprint, major architecture/data/schema contract,
important migration decision, mandatory Codex Gate review, Owner verification,
Stage closure, release report, or material risk acceptance.

Git history is the normal fine-grained implementation history.

AIPM decides the appropriate dispatch medium:

- Changes to project truth or technical authority belong in the formal current
  dispatch or a durable Blueprint / Guidance referenced by it. This includes
  architecture, Source of Truth, data/state ownership, schema, algorithm
  semantics, transaction/recovery, cross-module contracts, Stage scope,
  acceptance/release gates, and long-lived technical decisions.
- Small local continuation inside an already frozen ACTIVE dispatch may be a
  short direct chat instruction, such as rerunning tests, retrying a command,
  fixing a local bug, adding an already-implied regression, collecting
  evidence, rebuilding a package, updating the report, or narrow debugging.

A short chat instruction must never create a new task or silently alter frozen
architecture or product contract.

---

# 14. Git Checkpoint / Push Policy

Local commits are meaningful stable checkpoints, not a per-edit ritual.

Pi may create a local commit for:

- a complete validated small implementation task;
- a stable sub-stage checkpoint;
- a clean rollback point before a clearly high-risk refactor or mutation;
- Stage/Gate completion;
- another explicitly requested checkpoint.

Do not commit after every trivial edit. Do not present a known broken state as
a stable checkpoint. If an explicitly necessary diagnostic/broken checkpoint
is created, label it truthfully.

Local commit and formal version-branch submission are different steps.

Pi may create multiple local commits. Pi formally pushes only when all are
true:

- the entire current Dispatch is complete;
- required tests/build/package evidence is complete;
- `CURRENT_STATE.md` is updated;
- `Review/CURRENT_PI_REPORT.md` is updated;
- a final stable commit exists;
- Pi is ready to STOP and submit for AIPM source review.

Pi pushes only the `TARGET_BRANCH: dev/vX.Y` assigned by the current dispatch.
This complete-task push does not require a separate per-push Owner/AIPM
permission.

Pi must never:

- push or merge `main`;
- force-push;
- rewrite shared remote history;
- rebase published/shared history;
- destructively reset away another agent's work;
- squash/rewrite checkpoints merely to make history look cleaner.

Pi must not create a formal review submission for an incomplete dispatch.

---

# 14A. Source Review / Gate / Release Semantics

AIPM may not claim Source Review PASS unless AIPM directly inspected the real
code/diff, affected upstream/downstream seams, and relevant tests. A Pi report
is evidence; it is not AIPM approval.

Keep these states distinct:

- **Pi Complete**: implementation finished, self-tested, stable commit created,
  and submitted to the assigned `dev/vX.Y`.
- **AIPM PASS**: AIPM directly reviewed the real source/diff and relevant
  evidence against the frozen design.
- **Gate PASS**: ordinary low-risk AIPM Gate, or for mandatory/high-risk scope,
  AIPM PASS plus Codex repo-aware review plus AIPM adjudication.

After Gate PASS, AIPM may approve merge to `main`.

`main` is the technical stable line. Formal release/tag/external delivery is a
separate Final Product Owner decision. Stable `main` does not mean formally
released.

---

# 15. Evidence Discipline

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

# 16. SketchUp / Toolchain Discipline

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

# 17. Codex Reasoning Effort

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

# 18. Stable vs Dynamic Information

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
- `Prompt/CURRENT_PI_DISPATCH.md`;
- referenced durable AIPM Guidance / Blueprint;
- `Review/CURRENT_PI_REPORT.md` or justified durable Review artifact;
- Git.

---

# One-Line Rule

**AIPM designs and dispatches; Pi implements only the current frozen task;
Codex reviews only legitimate high-risk repo seams; source CAD remains
immutable; current authority comes from canonical project files, never from
historical Prompt discovery.**
