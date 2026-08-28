# CURRENT PI DISPATCH

STATUS: ACTIVE
DISPATCH_ID: SUAI-V15-R5-AIPM-SOURCE-REVIEW-FIX-20260828-01
Project: SU-AI-Plugin
Dispatcher: ChatGPT / AIPM
Version: V1.5
Stage: V1.5 — Round-5 AIPM Source Review corrective continuation
TARGET_BRANCH: dev/v1.5
V1.6: NOT STARTED

## Read first

1. `AGENTS.md`
2. `PROJECT_HANDOFF.md`
3. `PROJECT_MASTER_PLAN_V1X.md`
4. `CURRENT_STATE.md`
5. `Prompt/CURRENT_PI_DISPATCH.md`
6. `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
7. `Review/CURRENT_AIPM_REVIEW.md`
8. the existing Round-5 frozen Guidance only where referenced by the new Guidance

Historical Prompt/Review files are evidence only and cannot override this dispatch.

## Mission

Implement ONLY the bounded AIPM Source Review fixes frozen in:

`Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`

Assigned scope:

- FIX-A: strict tolerance parsing + eliminate missing/invalid runtime fallback + exact-zero layer-key correction;
- FIX-B: exact deterministic survivor provenance union;
- FIX-C: strict destructive handle-liveness hardening;
- focused/full regression and package evidence.

Explicitly NOT assigned:

- BLOCK-005 discard/Undo recovery redesign;
- Observer architecture;
- Owner verification;
- V1.6;
- product/UX changes;
- topology policy changes;
- source-CAD mutation;
- Codex review.

## Preflight

Before editing:

- `git branch --show-current`
- `git rev-parse HEAD`
- `git status --short`
- inspect current diff / untracked files

Expected branch:
`dev/v1.5`

The repository may contain untracked AIPM Review evidence `.txt` files generated for review.
Preserve them. Do not add, delete, or commit them.

If unexpected tracked production/test/governance modifications exist:
STOP and report exact paths.

Do not reset/rebase/clean away another agent's evidence.

## Implementation authority

Pi may:

- modify the production/test seams required by FIX-A/B/C;
- add focused regressions;
- make small local refactors strictly needed to centralize the frozen semantics;
- run tests/build/package;
- update `CURRENT_STATE.md`;
- overwrite `Review/CURRENT_PI_REPORT.md`;
- create local stable checkpoints.

Pi must NOT invent architecture outside the Guidance.

If the Guidance is insufficient against repository reality:
STOP the affected scope and report the exact gap to AIPM.

## Evidence

Run at minimum:

- focused corrective regressions;
- existing Round-5 regressions;
- full V1.5;
- full Ruby;
- Node DOM;
- RBZ smoke/package;
- rebuild RBZ;
- `git diff --check`.

`Review/CURRENT_PI_REPORT.md` must include:

- this exact DISPATCH_ID;
- branch / starting HEAD / final HEAD;
- changed production/test files;
- AIPM finding -> implementation -> regression mapping;
- exact tolerance/fallback search result;
- exact provenance invariant evidence;
- handle-liveness evidence;
- focused/full/package test results;
- RBZ path/size/entries/hash;
- known open BLOCK-005 statement;
- unresolved issues;
- final stable commit;
- push status;
- final `git status --short`;
- STOP.

## Git submission

Pi may create local checkpoint commits.

At completion:
- create one final stable submission commit;
- push only `dev/v1.5` if a remote is already configured and normal V3.4 dev-branch submission is possible;
- do NOT configure a new remote;
- do NOT push/merge `main`;
- do NOT force-push or rewrite history.

If there is still no remote:
record `PUSH NOT POSSIBLE — NO REMOTE`, keep the stable local commit, and STOP.

## Hard STOP

After all assigned FIX-A/B/C work and evidence are complete:

STOP.

Do not:
- continue into BLOCK-005;
- run/request Codex;
- ask Owner for verification;
- start V1.6;
- select another task.

Return control to AIPM for real source review.
