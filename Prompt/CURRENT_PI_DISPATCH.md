# CURRENT PI DISPATCH — V1.9A FINAL BLOCK FIX

Project: SU-AI-Plugin
Stage: V1.9A — Product UX + Diagnostics Orchestration
Packet: FINAL BLOCK FIX — Current Geometry + Current Issue Semantics
Date: 2026-09-07
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
TARGET_BRANCH: `dev/v1.9`
STARTING_BASELINE: `d4c4bc06e590dc4c4825fdbe20f07c2b1bc4db80`
STATUS: ACTIVE
V1.9B: NOT AUTHORIZED / NOT STARTED

Primary technical guidance:

`Prompt/AIPM_V1_9A_FINAL_BLOCK_FIX_2026-09-07.md`

Also authoritative for unchanged stage boundaries:

`Prompt/AIPM_STAGE_PRODUCT_TECHNICAL_BLUEPRINT_V1_9A_V1_9B_2026-09-04.md`

Relevant frozen upstream contracts:

- `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
- `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
- `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_8_LOOP_REGION_2026-09-02.md`

---

## 0. Owner Gate status

Already PASS in real SketchUp 2020:

- A3 native Toolbar;
- no-selection prompt;
- production V1.9A UI;
- four tabs;
- hidden-semantics fixes for panel / recovery banner / issue badge;
- one-click A2 diagnostics;
- combined Z + Gap detection;
- Gap repair disabled while Z is ACTIONABLE;
- Apply Z automatically recomputes/unlocks Gap;
- Apply Gap automatically recomputes Structure;
- repaired canonical topology reaches `open_chain_count=0`, `closed_loop_count=1`.

V1.9A remains BLOCKED only by the issues in the referenced Final Block Fix guidance.

Do NOT rerun or redesign already-passed host-state / hidden-semantics work.

---

## 1. Goal

Implement the COMPLETE narrow final V1.9A block-fix packet in:

`Prompt/AIPM_V1_9A_FINAL_BLOCK_FIX_2026-09-07.md`

The required outcomes are:

1. V1.7 current topology snapshot consumes LIVE post-V1.6 derived vertex coordinates, not stale build-time geometry summaries.
2. Real/production-equivalent Z + Gap chain yields a valid closed loop + Region after both repairs.
3. Current Issues and red badge no longer show historical source-registry rows as if they were current unresolved problems.
4. Original source findings remain available under Details / original source evidence.
5. Normal `重新检测` dispatches `refresh_cad_prep`, never silent workspace rebuild.
6. Planar card uses authoritative `movable_count` / `applied_count` fields and never contradicts an ACTIONABLE/APPLIED state.
7. Structure warning copy uses specific current evidence where available.
8. Hidden CSS regression guard cannot pass from selector text found only inside comments.

Complete the whole packet before formal submission.

---

## 2. Hard implementation boundary

Follow the detailed allowed/forbidden file and architecture boundaries in the referenced guidance.

Key prohibitions:

- no Source CAD mutation;
- no tolerance widening;
- no change to V1.6 normalization math;
- no change to V1.7 gap-pairing / canonical-node semantics;
- no change to V1.8 reconstruction/containment algorithm;
- no physical cross-group welding requirement;
- no Face generation;
- no Observer architecture;
- no Undo/host-state redesign;
- no Toolbar/loader changes unless a direct regression is proven;
- no MCP / LLM / Agent;
- no V1.9B / PreparedCadDataset.

For P0 specifically, do NOT hide the stale-coordinate bug by widening `coordinate_epsilon` or accepting the old 0.2 mm Z value.

If implementation requires changing production files outside the allowlist in the guidance, STOP and report before proceeding.

---

## 3. Test obligation

Implement every focused regression defined in the Final Block Fix guidance, including:

- live-coordinate-over-cached-coordinate topology snapshot;
- unreadable live coordinate fail-closed behavior;
- combined Z + Gap -> Closed Loop + Region integration;
- current-vs-original issue separation;
- issue badge semantics;
- issue-chip semantics;
- `重新检测` -> `refresh_cad_prep` + workspace identity preservation;
- Planar `movable_count` / `applied_count` presenter mapping;
- structure warning copy specificity;
- hidden CSS comment false-pass regression.

Then run the existing focused and full regression suites listed in the guidance.

Known pre-existing failures must be reported separately. Do not call the aggregate suite PASS if failures/errors remain.

---

## 4. RBZ

This task changes production behavior/UI, so rebuild:

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

Report:

- path;
- bytes;
- entry count;
- SHA-256;
- relevant packaged production file hashes when practical.

This remains a V1.9A Owner re-verification candidate, not a final V1.x release.

---

## 5. CODEX

`CODEX_RISK_TRIGGER = YES (POST-IMPLEMENTATION, NARROW)` because P0 touches the V1.6 -> V1.7 current-geometry authority seam feeding canonical topology.

Pi MUST NOT invoke Codex.

Order is:

1. Pi implementation/tests/build/commit/push;
2. AIPM direct source/diff review;
3. AIPM decides narrow Codex review timing;
4. Owner SU2020 re-verification;
5. only AIPM/Owner may close V1.9A.

---

## 6. Required return

Update:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

Return exactly the evidence required by section 12 of:

`Prompt/AIPM_V1_9A_FINAL_BLOCK_FIX_2026-09-07.md`

Then:

- create final stable commit;
- push only `origin/dev/v1.9`;
- `AIPM_REVIEW = PENDING`;
- `OWNER_SU2020 = NOT YET`;
- `V1.9B = NOT STARTED`;
- STOP and return control to AIPM.

END
