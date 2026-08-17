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

R001  Preflight threshold defaults (big_z, large_coordinate)
       File: R001_preflight_threshold_defaults.md
       Default chosen:  big_z = 0.01 in, large_coordinate = 1e6 in,
                        deepest_nesting_warning = 3
       Owner may override via Company Profile later, but locking the
       V1.0 default up front avoids surprise in Stage 2 verification.

R002  Stage 5 capability probe scope
       File: R002_stage5_capability_probe_scope.md
       Default chosen: thin wrapper around compatibility/su_capability.rb
                       + stub test (NOT unit-testable in SU env, only
                       behavioral check)
       Question: keep thin, or expand to richer capability matrix
                 (HTML dialog version, model.save_copy, etc.)?

R003  Stage 6 UI design
       File: R003_stage6_ui_design.md
       High-impact: selection visualizer approach, dialog container,
                   layout, color language.
       Multiple sub-decisions; Owner pick A/B/C per sub-question.

R004  Q004 caveat closure criteria
       File: R004_q004_caveat_closure.md
       When does "Ruby 2.2.4 baseline evidence" count as satisfied?
       Three candidates proposed; Owner picks the gate posture.

R005  Issue Registry presentation
       File: R005_issue_registry_presentation.md
       Per PI_TASK_001 §11, issues have severity/confidence/source.
       How to render in UI? Flat list / grouped / sortable / filter?

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
