# AIPM TECHNICAL GUIDANCE — SU-AI-Plugin V3.4 Governance Migration

Date: 2026-08-28
Author: ChatGPT / AIPM
Project: `D:\Projects\SU-AI-Plugin`
Type: Governance / workflow migration
Product/runtime scope: NONE
Authority: Final Product Owner + AIPM Playbook V3.4

---

## 0. Decision

Migrate the SU-AI-Plugin repository from the existing V3.2-era project governance to the V3.4 operating model.

This is a **governance-only** migration.

It must not change:
- product behavior;
- SketchUp runtime behavior;
- V1.5 duplicate-repair implementation;
- tests for product behavior;
- RBZ contents for product functionality;
- V1.6 product/technical scope;
- previously closed V1.0–V1.4 technical conclusions.

The migration changes how work is:
- dispatched;
- handed back;
- pushed to GitHub;
- source-reviewed by AIPM;
- escalated to Codex;
- merged to `main`;
- approved for formal release.

---

## 1. One-time Codex execution authorization

Permanent V3.4 rule:
- Codex is normally a review-only high-risk expert reviewer.

For **this migration only**, the Final Product Owner explicitly authorizes Codex to:
- inspect the real local repository;
- modify governance / workflow / agent instruction files;
- create the new V3.4 current-review file;
- create or switch to the local canonical version development branch if safe;
- create one local governance commit after validation.

This one-time authorization does **not** change the permanent Codex default.

Codex is still forbidden in this task to:
- modify production source;
- modify product tests;
- modify runtime behavior;
- modify package implementation;
- modify CAD / geometry logic;
- start V1.6;
- perform Owner verification;
- release/tag;
- merge `main`;
- force-push or rewrite history;
- push unless separately authorized after this migration.

---

## 2. Target steady-state role model

### Final Product Owner
Owns:
- product scope;
- visible UX;
- automation authority;
- meaningful risk/time/cost tradeoffs;
- real-host acceptance;
- formal release/tag.

Does not need to approve ordinary technical commits or ordinary `main` merges after Gate PASS.

### AIPM / ChatGPT
Role:
`Product + Technical Lead + Primary Source Reviewer + Dispatcher + Final Technical Adjudicator`

Owns:
- product definition;
- architecture;
- Source of Truth;
- state/data ownership;
- schemas;
- algorithm semantics;
- transaction/recovery;
- Stage Blueprint / Guidance;
- acceptance/release gates;
- Pi dispatch;
- real source review after Pi submits code;
- Codex escalation;
- Codex finding adjudication;
- technical Gate;
- approval to merge `main` after Gate PASS.

Hard evidence rule:
> AIPM may not claim Source Review PASS unless AIPM has directly inspected the real code/diff.

### Pi
Role:
`Implementation Agent`

Owns:
- implement;
- test;
- debug;
- build/package;
- local checkpoints;
- final stable commit;
- update `CURRENT_STATE.md`;
- update `Review/CURRENT_PI_REPORT.md`;
- after the complete dispatch is finished, push the stable submission to the assigned `dev/vX.Y`;
- STOP.

Pi must not independently redesign:
- Source of Truth;
- state/data ownership;
- core schema;
- architecture;
- module responsibility;
- algorithm semantics;
- transaction/recovery;
- identity/provenance;
- Stage boundaries;
- product UX;
- release gates.

### Codex
Permanent role:
`Conditional High-Risk Repo-aware Reviewer`

Default:
- review-only;
- no code changes;
- no commit;
- no push;
- no merge.

Mandatory/high-risk triggers include:
- state/data ownership;
- transaction/recovery/Undo;
- cross-module core architecture;
- SketchUp/host compatibility;
- destructive actions;
- package/install/runtime/release-critical behavior;
- Stage/Version final high-risk technical Gate.

Codex verdict is advisory evidence.
AIPM owns final technical adjudication.

---

## 3. Target communication files

Permanent current files:

```text
Prompt/CURRENT_PI_DISPATCH.md
Review/CURRENT_PI_REPORT.md
Review/CURRENT_AIPM_REVIEW.md
```

### `Prompt/CURRENT_PI_DISPATCH.md`
Sole current AIPM → Pi formal task authority.

Must include, when ACTIVE:
- `DISPATCH_ID`;
- project/version/stage;
- assigned `TARGET_BRANCH: dev/vX.Y`;
- frozen Blueprint/Guidance references;
- scope/out-of-scope;
- required tests/evidence;
- STOP rules;
- Git submission rule.

Task discovery must never use:
- mtime;
- newest filename;
- filename numbering;
- historical `STATUS: ACTIVE`;
- historical Prompt;
- historical Review;
- previous chat/session memory.

When no task exists:
`STATUS: NO ACTIVE DISPATCH`

### `Review/CURRENT_PI_REPORT.md`
Sole current Pi → AIPM implementation return channel.

Pi report is evidence, not task authority.

Expected completion fields:
- matching `DISPATCH_ID`;
- branch/base/HEAD;
- changed files;
- implementation summary;
- tests;
- build/package evidence if required;
- unresolved issues;
- stable commit;
- pushed remote branch/commit;
- final STOP.

### `Review/CURRENT_AIPM_REVIEW.md`
New permanent AIPM source-review record.

At minimum:
- status;
- reviewed branch;
- reviewed commit;
- review scope;
- evidence basis;
- PASS / FIX REQUIRED / BLOCK / NOT YET REVIEWED;
- findings summary;
- Codex trigger;
- Codex adjudication when applicable;
- next permitted action;
- Owner action required or not.

Use `CURRENT + major-node archive`:
- ordinary reviews overwrite CURRENT;
- durable versioned review artifacts only for material BLOCK, Codex Gate, Stage PASS, Version Gate, Release, major risk acceptance.

---

## 4. Target Git / branch model

Permanent version branch model:

```text
main
├── dev/v1.5
├── dev/v1.6
└── ...
```

Rules:
- one development branch per product version;
- no new branch for every Round;
- `main` = technical stable line;
- formal release/tag = product release line.

### Pi submission
Pi may make multiple local commits.

Pi performs the formal push only when:
1. the entire current Dispatch is complete;
2. required tests/build/package are complete;
3. `CURRENT_STATE.md` is updated;
4. `CURRENT_PI_REPORT.md` is updated;
5. final stable commit exists;
6. Pi is ready to STOP and submit for AIPM review.

Pi pushes only to the assigned `dev/vX.Y`.

Pi must never:
- push/merge `main`;
- force-push;
- rewrite published/shared remote history;
- create release/tag;
- treat an incomplete dispatch as a formal review submission.

### Current repository migration
The current V1.5 legacy working branch may have a historical name.

Migration rule:
- inspect real Git state first;
- if safe, create/switch local `dev/v1.5` at the current stable V1.5 HEAD;
- preserve the old branch as historical; do not delete it;
- do not rewrite history;
- do not push in this migration unless separately authorized.

If an existing local or remote `dev/v1.5` points somewhere materially different:
STOP and report the conflict instead of guessing.

---

## 5. PASS / Gate semantics

Freeze three distinct states:

### Pi Complete
Pi finished, self-tested, created stable commit, and submitted to `dev/vX.Y`.

This is not approval.

### AIPM PASS
AIPM directly inspected:
- real diff;
- directly affected upstream/downstream code;
- relevant tests;

and judged the implementation consistent with the frozen design.

### Gate PASS
For ordinary low-risk work:
- AIPM PASS may form the technical Gate.

For mandatory/high-risk work:
- AIPM PASS;
- Codex repo-aware review;
- AIPM adjudication of Codex findings;

must all complete before Gate PASS.

Do not conflate these states.

---

## 6. `main` and release authority

`main`:
- technical stable line;
- after Gate PASS, AIPM may approve merge into `main`.

Formal release/tag:
- requires Final Product Owner approval;
- `main` stable does not equal formally released.

---

## 7. Files Codex must inspect

At minimum inspect actual current contents of:

```text
AGENTS.md
PI_START_HERE.md
PROJECT_HANDOFF.md
PROJECT_MASTER_PLAN_V1X.md
CURRENT_STATE.md
Prompt/CURRENT_PI_DISPATCH.md
Review/CURRENT_PI_REPORT.md
.pi/APPEND_SYSTEM.md            (if present)
```

Also inspect:
- other root-level instruction/governance files;
- `.pi/` instruction files;
- current/non-historical Prompt/Review workflow documents;
- `.github/` or hooks/config only if they hard-code branch names or workflow authority.

Search the repository for live/current governance conflicts including concepts such as:
- `Pi must NOT push`;
- `Push requires explicit Owner/AIPM authorization`;
- `DO NOT PUSH` in current active Pi instructions;
- old current branch naming as permanent policy;
- Codex-first/default Codex review;
- Pi task discovery via newest/latest/mtime/ACTIVE history;
- Review files used as task authority;
- AIPM review based only on Pi report while labelled as source review;
- lack of `CURRENT_AIPM_REVIEW`;
- Owner required for ordinary technical `main` merge;
- any rule that conflicts with V3.4.

Do not treat historical artifacts as current governance merely because they contain old wording.

---

## 8. Per-file migration contract

### `AGENTS.md`
Must become the strongest project-local operational governance.

Preserve all valid SU-AI-Plugin:
- architecture;
- runtime;
- compatibility;
- testing;
- geometry;
- source immutability;
- safety;
- product contracts.

Update only workflow/role/Git/Review rules needed for V3.4.

Must include:
- role model;
- fixed current files;
- Pi submission to `dev/vX.Y`;
- Pi `main`/force-push/release prohibitions;
- AIPM source-review requirement;
- three PASS states;
- Codex review-only default;
- Codex high-risk triggers;
- AIPM final adjudication;
- `main` vs release authority.

### `PI_START_HERE.md`
Keep permanent and compact.

Read order should remain roughly:
1. `AGENTS.md`
2. `PROJECT_HANDOFF.md`
3. `PROJECT_MASTER_PLAN_V1X.md`
4. `CURRENT_STATE.md`
5. `Prompt/CURRENT_PI_DISPATCH.md`
6. explicitly referenced Blueprint/Guidance
7. execute only current dispatch

Add/confirm:
- current task discovery only from CURRENT_PI_DISPATCH;
- assigned target branch must match dispatch;
- completion submission is stable commit + push assigned `dev/vX.Y` + report + STOP;
- never push/merge main;
- no Codex;
- no next Stage without AIPM dispatch.

### `PROJECT_HANDOFF.md`
Keep durable; do not turn into dynamic tracker.

Update only obsolete governance paragraphs.

Must explain:
- AIPM → CURRENT_PI_DISPATCH → Pi → CURRENT_PI_REPORT → AIPM;
- Pi submits complete work to `dev/vX.Y`;
- AIPM performs real source review;
- CURRENT_AIPM_REVIEW records current AIPM verdict;
- Codex is conditional second-layer reviewer;
- Gate PASS / main / release distinction.

### `PROJECT_MASTER_PLAN_V1X.md`
Do not modify product/technical roadmap merely for governance wording.

Only edit if it contains live operational rules directly conflicting with V3.4.

If unchanged, report why.

### `CURRENT_STATE.md`
Preserve truthful product progress.

Add a concise governance note:
- project now uses V3.4 workflow;
- current canonical version branch is `dev/v1.5` after safe branch migration;
- AIPM source review is now required after Pi submission;
- Codex remains conditional;
- `main` vs release distinction.

Do not invent:
- V1.5 PASS;
- Codex PASS;
- Owner verification;
- V1.6 start.

### `Prompt/CURRENT_PI_DISPATCH.md`
Inspect actual current status.

If the latest Pi report proves the prior dispatch is COMPLETE/STOPPED and no new Pi task exists:
- convert it to a neutral `STATUS: NO ACTIVE DISPATCH` current template;
- preserve prior task history in Git/history, not in CURRENT task authority.

The inactive template must encode new V3.4 Git submission semantics for the next ACTIVE dispatch.

If the prior Pi task is not proven closed:
- do not neutralize it;
- report the inconsistency.

### `Review/CURRENT_PI_REPORT.md`
Do not rewrite Pi's completed implementation evidence simply to change governance wording.

Leave the latest truthful Pi report intact unless a purely clerical path/reference correction is essential and clearly non-semantic.

### `Review/CURRENT_AIPM_REVIEW.md`
Create if absent.

Initial state after migration:
- `STATUS: PENDING AIPM SOURCE REVIEW`;
- current V1.5 branch/commit if safely known;
- `VERDICT: NOT YET REVIEWED`;
- evidence note that Pi completion/report is not AIPM source approval;
- next action: push/remote availability if needed, then AIPM reviews real diff.

### `.pi/APPEND_SYSTEM.md`
Keep minimal.

If it already only points Pi to `PI_START_HERE.md`, leave it alone.

Do not duplicate AGENTS / HANDOFF.

### Other current governance files
Modify only when:
- they are actually current operational authority;
- they conflict with V3.4.

Do not mass-edit historical evidence.

---

## 9. Historical artifact rule

Do not:
- delete historical Prompt/Review;
- mass rename them;
- rewrite old verdicts;
- “correct” old instructions to look modern.

Historical files may truthfully contain old governance.

Only current/canonical authority must be migrated.

---

## 10. Safety / validation matrix

Before edits:
- record branch;
- record HEAD;
- record `git status --short`;
- record remotes;
- record local/remote branches;
- record `git log -10 --oneline --decorate`.

STOP if:
- unexpected uncommitted production/source/test changes exist;
- current HEAD is not a stable completed V1.5 checkpoint;
- `dev/v1.5` exists and conflicts materially;
- current Pi task status is ambiguous;
- governance migration would require modifying production code.

After edits verify:

### Scope
No unintended changes under product/runtime code or tests.

### Governance consistency
Current canonical files agree on:
- roles;
- CURRENT dispatch/report/review files;
- dev branch model;
- push rule;
- source-review rule;
- Codex default;
- PASS levels;
- main/release authority.

### Stale-rule scan
No live/current canonical file should still say:
- Pi cannot push the completed assignment to the assigned dev branch;
- every push needs per-task Owner approval;
- Codex is default first-line reviewer;
- AIPM may claim source PASS from Pi report only;
- Review history can select the current task.

### Git hygiene
Run:
- `git diff --check`;
- inspect `git diff --stat`;
- inspect full governance diff;
- ensure historical artifacts were not mass-modified.

---

## 11. Commit / push contract for this migration

After validation, Codex may create exactly one local governance commit:

```text
chore(governance): migrate project to AIPM V3.4 workflow
```

The commit may include:
- governance rule files;
- current workflow files;
- `CURRENT_AIPM_REVIEW.md`;
- migration report;
- branch/governance state update.

Do not include production/runtime/test changes.

Do not push in this task unless the Owner later gives separate explicit authorization.

---

## 12. Required Codex migration report

Create durable report:

```text
Review/CODEX_V3_4_GOVERNANCE_MIGRATION_2026-08-28.md
```

Report:
- preflight branch/HEAD/status/remotes;
- branch migration decision;
- exact files changed;
- exact files inspected but intentionally unchanged;
- each stale rule found and how resolved;
- `CURRENT_PI_DISPATCH` decision;
- `CURRENT_PI_REPORT` preservation decision;
- `CURRENT_AIPM_REVIEW` creation;
- validation commands/results;
- final local commit SHA;
- final branch;
- final `git status --short`;
- anything still unresolved;
- explicit `PUSH: NOT PERFORMED`;
- explicit `PRODUCT/RUNTIME CODE: NOT MODIFIED`;
- STOP.

---

## 13. End state

The desired end state is:

```text
Owner
  ↓ product/risk/release

AIPM
  ↓ frozen design
Prompt/CURRENT_PI_DISPATCH.md
  ↓
Pi
  ↓ complete implementation + tests + stable commit
dev/vX.Y
  ↓
Review/CURRENT_PI_REPORT.md
  ↓
AIPM real source review
  ↓
Review/CURRENT_AIPM_REVIEW.md
  ├─ ordinary → AIPM Gate
  └─ high-risk → Codex review-only → AIPM adjudication
  ↓
Gate PASS
  ↓
AIPM may approve main merge
  ↓
Owner approves Formal Release
```

No product feature work is part of this migration.
