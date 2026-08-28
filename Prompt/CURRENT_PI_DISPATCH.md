# CURRENT PI DISPATCH

STATUS: NO ACTIVE DISPATCH
DISPATCH_ID: NONE
Project: SU-AI-Plugin
Dispatcher: ChatGPT / AIPM
Current version line: V1.5
V1.6: NOT STARTED

## Current instruction

There is no executable Pi task.

Pi must STOP and return control to AIPM. Do not infer work from historical
Prompt/Review files, filename order, modification time, stale ACTIVE text, Git
history, or prior chat/session memory.

The completed V1.5 Round-5 dispatch and its evidence remain preserved in Git
history and `Review/CURRENT_PI_REPORT.md`. Pi completion is implementation
evidence, not AIPM source-review approval.

## Permanent ACTIVE-dispatch template

Before future Pi work begins, AIPM must replace this neutral content with one
internally consistent ACTIVE dispatch containing at least:

- `STATUS: ACTIVE`;
- unique `DISPATCH_ID`;
- project/version/stage;
- `TARGET_BRANCH: dev/vX.Y`;
- frozen Blueprint/Guidance references;
- scope and out-of-scope boundaries;
- required tests/build/package evidence;
- state/report requirements;
- STOP/escalation conditions;
- complete-task Git submission rule.

For a future ACTIVE dispatch, Pi:

1. reads `AGENTS.md`, `PROJECT_HANDOFF.md`,
   `PROJECT_MASTER_PLAN_V1X.md`, `CURRENT_STATE.md`, this file, and only
   explicitly referenced durable Blueprint/Guidance;
2. executes the entire frozen dispatch on its assigned `dev/vX.Y`;
3. completes required tests/build/package evidence;
4. updates `CURRENT_STATE.md` and `Review/CURRENT_PI_REPORT.md`;
5. creates the final stable commit;
6. pushes only the assigned `dev/vX.Y` as the formal complete-task
   submission;
7. STOPs and returns control to AIPM source review.

Pi may create local checkpoint commits, but must not formally submit an
incomplete dispatch.

Pi must never push/merge `main`, force-push, rewrite shared history, create a
release/tag, run/request Codex, start an undispatched Stage, or invent
architecture beyond the frozen AIPM contract.
