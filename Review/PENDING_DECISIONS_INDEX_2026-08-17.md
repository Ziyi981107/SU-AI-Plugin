============================================================
PENDING DECISIONS INDEX — 2026-08-17
Project: D:\Projects\SU-AI-Plugin
For:    Codex + Owner
============================================================

PURPOSE
=======

Per WORKFLOW_PROTOCOL:
  "所有需要外部决策的问题都写成txt文件存进 Review/"

This file is the single index of everything Stage 2 DESIGN leaves
hanging for Codex / Owner input. Each R### entry has its own detail
file next to this one. Items already ANSWERED (Q001-Q004) are NOT
re-listed — see git log `37db08f` for those answers.

ITEMS WAITING
=============

(none — R001-R005 all RESOLVED 2026-08-17 via CODEX_REVIEW_004;
 the BLOCK rework is the open work, tracked in CURRENT_STATE.md,
 not in this index)

----- historical, kept for traceability -----

R001  Preflight threshold defaults (big_z, large_coordinate) — RESOLVED 2026-08-17
       File: R001_preflight_threshold_defaults.md (Status: ANSWERED)
       Source: CODEX_REVIEW_004 §R001-R005 DECISIONS
       Decision: KEEP big_z=0.01/large_coord=1e6/warning=3 BUT root=level1,
                 warning at deepest_nesting >= 3, big_z ONLY for significant-Z
                 warning (NOT for non-zero counts). See R### ANSWER block.

R002  Stage 5 capability probe scope — RESOLVED 2026-08-17
       File: R002_stage5_capability_probe_scope.md (Status: ANSWERED)
       Source: CODEX_REVIEW_004 §R001-R005 DECISIONS
       Decision: Option C + amendment — DO NOT create su_version_probe.rb
                 or YAML matrix. su_capability.rb IS the single entry point.
                 Add HtmlDialog check + outside-SU stub tests during
                 Stage 2 rework. Stage 5 as standalone CANCELLED.

R003  Stage 6 UI design — RESOLVED 2026-08-17
       File: R003_stage6_ui_design.md (Status: ANSWERED)
       Source: CODEX_REVIEW_004 §R001-R005 DECISIONS
       Decision: Q3.1=B (selection+camera ONLY, no overlay), Q3.2=A
                 (HtmlDialog), Q3.3=A (single page + grouped sections),
                 Q3.4=R005 language, Q3.5=A (Locate only), Q3.6=confirmed.
                 HARD PROHIBITION on any overlay / mutation in V1.

R004  Q004 caveat closure criteria — RESOLVED 2026-08-17
       File: R004_q004_caveat_closure.md (Status: ANSWERED)
       Source: CODEX_REVIEW_004 §R001-R005 DECISIONS
       Decision: B conditional; C REJECTED. Caveat closes only after
                 COMPLETE production entry path loads on real SU2017.
                 If SU2017 unavailable -> posture A becomes REQUIRED.
                 Caveat cannot be documented-only.

R005  Issue Registry presentation — RESOLVED 2026-08-17
       File: R005_issue_registry_presentation.md (Status: ANSWERED)
       Source: CODEX_REVIEW_004 §R001-R005 DECISIONS
       Decision: option 2 grouped, deterministic issue_id order,
                 severity=low/medium/high ONLY (NOT :info/:warning),
                 confidence separate, UI palette low=neutral/medium=orange/
                 high=red. Suggested mapping for 7 issue types included.

ALREADY-WAITING (NOT IN THIS BATCH)
====================================

- Owner Stage 2 SU-side verification (9-step checklist)
  File: OWNER_VERIFICATION_STAGE_2.txt
  Status: NOT VERIFIED IN REAL SKETCHUP (per Q002=A)
  Expected input: Prompt/OWNER_REPORT_STAGE_2_<date>.txt from Owner
  This is *execution* feedback, not a *decision* — separate from R###.

AGENT CARRYING (NO R FILE NEEDED)
=================================

- "Continue to Stage 5 immediately without waiting for Owner Stage 2
   verification"
  Rationale: Stage 5 (capability probe) does not depend on Stage 2
             SU-side behavior. It only depends on Q003 = SU2017+ lock
             (already ANSWERED) and the existing compatibility/
             module (already committed in 6eb33e8).
  If Owner wants Stage 5 paused until Stage 2 verification lands,
  flag here and Agent will halt Stage 5.

WHAT TO DO WITH THIS INDEX
===========================

- Owner: skim R### list, read R-files that affect you (especially
  R003 UI design + R004 caveat closure), drop answers in
  Prompt/. Agent picks up on the next session start.
- Codex: review R### for hard-constraint conflicts with PI_TASK_001.
  Anything conflicting with §3 / §6 / §10 / §11 / §17 / §18 should be
  flagged in Review/.

============================================================
END
============================================================
