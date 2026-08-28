# PI START HERE

Project: `D:\Projects\SU-AI-Plugin`
Status: **PERMANENT BOOTSTRAP ENTRY**
Owner: **ChatGPT / AIPM**

---

## 0. Purpose

This file is Pi's permanent bootstrap entry. It is stable and must not be
rewritten for each task.

The sole normal formal current implementation dispatch is:

`Prompt/CURRENT_PI_DISPATCH.md`

The sole normal current implementation return channel is:

`Review/CURRENT_PI_REPORT.md`

`Review/CURRENT_PI_REPORT.md` is implementation evidence, not task authority.

The sole normal current AIPM source-review record is:

`Review/CURRENT_AIPM_REVIEW.md`

---

## 1. Mandatory bootstrap order

Before choosing or starting implementation work, Pi must read:

1. `AGENTS.md`
2. `PROJECT_HANDOFF.md`
3. `PROJECT_MASTER_PLAN_V1X.md`
4. `CURRENT_STATE.md`
5. `Prompt/CURRENT_PI_DISPATCH.md`
6. Any durable AIPM Technical Blueprint / Guidance files explicitly referenced
   by `CURRENT_PI_DISPATCH.md`

Pi may execute only the current dispatch, and only after the project's normal
user authorization / Proceed flow.

The target branch is authoritative only when declared by the ACTIVE dispatch
as `TARGET_BRANCH: dev/vX.Y`. Pi must not invent or substitute a Round-specific
branch.

A short direct chat instruction may continue a small local step only inside an
already ACTIVE dispatch and frozen contract. It cannot create a task, replace
the current dispatch, or alter architecture/product authority.

---

## 2. No-dispatch and conflict rule

If `Prompt/CURRENT_PI_DISPATCH.md` is:

- missing;
- unreadable or malformed;
- internally contradictory;
- contradictory with a referenced durable contract; or
- `STATUS: NO ACTIVE DISPATCH`;

Pi must STOP and report that there is no executable current dispatch.

Do not guess, resume, invent, or select another task.

If a referenced Blueprint / Guidance file is missing or contradictory, Pi must
STOP the affected work and report the exact path or conflict to AIPM.

---

## 3. Forbidden task discovery

Pi must never select current work by:

- modification time;
- the latest or newest filename;
- filename numbering or highest version number;
- scanning for historical `STATUS: ACTIVE`;
- historical Prompt files;
- historical Review files;
- old Codex Guidance or Review;
- archived Reviewer Contracts or workflow files;
- old `NEXT ACTION`, `STOP`, `WAIT`, or `GREENLIT` text;
- previous chat/session memory.

`Prompt/` is not a task queue.

`Review/` must not be read to discover the next task.

Historical Prompt/Review artifacts cannot become current authority through
their filename, numbering, modification time, or stale status.

---

## 4. Implementation authority boundary

Pi implements, tests, debugs, builds, packages, and reports inside the frozen
AIPM contract.

Pi must not independently change:

- product scope or UX;
- Stage boundaries or roadmap;
- Source of Truth or state/data ownership;
- core schemas or module responsibilities;
- architecture or major algorithm semantics;
- transaction/recovery or provenance/identity contracts;
- tolerance/canonical-topology semantics;
- acceptance or release gates.

If required design authority is missing or contradictory, Pi must STOP the
affected work and report the design gap to AIPM.

---

## 5. Completion rule

For an ACTIVE dispatch, Pi completes the entire frozen task and required
tests/build/package evidence, updates `CURRENT_STATE.md` and
`Review/CURRENT_PI_REPORT.md`, creates the final stable commit, pushes only the
assigned `dev/vX.Y` as the formal complete-task submission, then STOPs and
returns control to AIPM.

Pi may create local checkpoint commits before completion, but must not submit
an incomplete dispatch for formal review.

Pi must never push or merge `main`, force-push, rewrite shared history, create
a release/tag, select another task, start another Stage, request/run Codex
directly, or infer a next action from historical files.

---

## 6. One-line Pi rule

**Read the permanent bootstrap stack, execute only an authorized ACTIVE
`CURRENT_PI_DISPATCH` on its assigned `dev/vX.Y` inside the frozen AIPM
contract, complete and submit it through `CURRENT_PI_REPORT`, then STOP and
return control to AIPM.**
