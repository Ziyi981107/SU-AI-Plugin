# PI START HERE

Project: `D:\Projects\SU-AI-Plugin`  
Status: **ACTIVE CURRENT POINTER**  
Owner of this pointer: **ChatGPT / AIPM**  
Last updated: 2026-08-27

---

## 0. Purpose

This file is the ONLY current-task pointer for Pi in this repository.

Pi MUST NOT discover the active task by scanning `Prompt/`, sorting by
modification time, choosing the newest filename, or trusting an old
`STATUS: ACTIVE` header.

Historical Prompt/Review files remain evidence only unless this file or the
current AIPM PI_TASK explicitly references them.

If this file conflicts with an old Prompt/Review artifact about which task is
current, THIS FILE determines the current task pointer.

This file does not replace the technical/product contracts themselves. It only
defines the exact current context stack Pi must read before implementation.

---

# 1. Mandatory bootstrap order

Before reading source code, editing files, running implementation work, or
choosing a task, Pi MUST read these files in this exact order:

1. `AGENTS.md`
2. `PROJECT_HANDOFF.md`
3. `PROJECT_MASTER_PLAN_V1X.md`
4. `CURRENT_STATE.md`
5. `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`
6. `Prompt/PI_TASK_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`

Only after reading all six may Pi begin the current implementation task.

---

# 2. Current technical design authority

`Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`

This is the frozen AIPM technical design for the current V1.5 Round-4 fix.

Pi may implement it.

Pi may NOT replace it with a different architecture.

If implementation evidence proves the design cannot be implemented safely
against the actual repository seam, Pi must STOP the affected work and report
the exact gap to AIPM.

---

# 3. Current implementation authority

`Prompt/PI_TASK_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`

This is the ONLY active Pi implementation task.

Current Stage:
`V1.5 — Round-4 existing BLOCK fix`

Current implementation goal:
Close the implementation/evidence gaps for the existing
`V15-STAGE-BLOCK-001..005` according to the current AIPM Technical Guidance.

V1.6 is NOT started.

---

# 4. Forbidden task-discovery behavior

Pi MUST NOT choose the current task using any of the following:

- newest modification time;
- newest filename;
- newest file in `Prompt/`;
- any historical `STATUS: ACTIVE` found by scanning;
- previous chat/session memory;
- old Codex Guidance;
- old Codex Review;
- old Owner checklist;
- old `NEXT ACTION`;
- old `STOP` / `WAIT` / `GREENLIT` text;
- archived Reviewer Contract;
- archived Prompt/Review workflow files.

Pi MUST NOT treat `Prompt/` as a queue.

`Prompt/` is an archive + authority store.  
`PI_START_HERE.md` is the current pointer.

---

# 5. Current execution boundary

Pi may:

- implement the current AIPM Guidance;
- modify production/test files required by the current PI_TASK;
- run targeted and full tests;
- debug current implementation failures;
- rebuild/package the RBZ;
- create/update the required Pi Review packet;
- update `CURRENT_STATE.md` truthfully;
- create stable Git checkpoints.

Pi may NOT:

- change product scope;
- redesign V1.5 repair semantics;
- change Source of Truth;
- change core state/data ownership;
- change the V1.x roadmap;
- start V1.6;
- invent a different non-transitive duplicate policy;
- create the final AIPM Owner verification checklist;
- request Codex review directly;
- treat old Prompt files as current authority.

---

# 6. Required stop condition

When the current PI_TASK is complete:

1. write/update the required Round-4 Review packet;
2. update `CURRENT_STATE.md`;
3. record truthful Git/test/package evidence;
4. STOP;
5. return control to AIPM.

Do NOT:
- ask Owner to install the RBZ;
- ask Owner to run Ruby Console verification;
- ask Codex to recheck;
- begin V1.6;
- select another Prompt automatically.

AIPM will review the Pi packet and dispatch the next action.

---

# 7. Missing-file / conflict rule

If any file referenced in the mandatory bootstrap stack is missing:

STOP.

Report:
- missing path;
- current branch;
- current HEAD;
- `git status --short`.

Do not guess a replacement.

If two current-looking files conflict:

STOP the affected work and report the conflict to AIPM.

Do not resolve authority by file time, filename numbering, or Codex status.

---

# 8. One-line Pi rule

**Read `PI_START_HERE.md` first, follow only the exact AIPM Guidance + PI_TASK it
points to, implement inside the frozen design, then STOP and return control to
AIPM.**
