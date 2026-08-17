# BLOCK RECHECK REQUEST 4 — S2-BLOCK-005 (checklist H correction)

Created:    2026-08-17
Stage:      2 BLOCK rework pass 4 (final)
Source:     Prompt/CODEX_REVIEW_008_2026-08-17_BLOCK_RECHECK_PASS3.txt
Fix commit: 9ff2e49 fix(stage-2): resolve Codex BLOCK rework pass 4
Tests:      72/72 PASS (was 71/71; +1 pass-4 regression)


PURPOSE
=======

Per Codex Review 008 §NEXT REVIEW:
  "Recheck S2-BLOCK-005 checklist H correction and its one matching
   test only. Do not reopen code/API areas closed above without new
   evidence."

All other BLOCKS (S2-BLOCK-001, S2-BLOCK-002, S2-BLOCK-003, S2-BLOCK-004,
S2-BLOCK-006 HtmlDialog, S2-BLOCK-006 version subpart) are CLOSED per
Codex §CLOSED IN THIS RECHECK.

This file is the focused recheck packet for S2-BLOCK-005 only.


S2-BLOCK-005 (checklist H correction)
====================================

Location:    Review/OWNER_VERIFICATION_STAGE_2.txt step H,
             tests/test_preflight_runner.rb (new r4 test)
Fix:
  - Checklist selection_array changed from
      [inv_group, e1_invalid, e2_valid]
    to
      [inv_group, e1_invalid]
  - Rationale: e2 is already a child of inv_group; including it in
    the selection_array causes duplicate traversal — inv_group walks
    its children (discovers e2), then the explicit e2 in selection
    is walked again, producing 2 EdgeRecords instead of 1.
  - Production traversal NOT changed (parent-plus-descendant overlap
    dedup is outside this BLOCK unless product contract requires it).
  - NIT fix: sketchup_version simplified `v.is_a?(Integer) ? v.to_s : v.to_s`
    to `v.to_s` (no behavior change).

Recheck evidence:
  [x] Checklist H snippet is paste-runnable on SU2017+ with the
      corrected selection_array.
  [x] New automated test 'S2-BLOCK-005 (r4): checklist H shape
      [inv_group, e1_invalid] -> exactly 1 EdgeRecord':
        - Builds 2 edges in inv_group
        - Erases e1 (held reference retained in selection)
        - selection = [inv_group, e1] (no explicit e2)
        - Asserts edge_count == 1
        - Asserts the surviving edge is e2 (end at x=20)
  [x] Full suite remains at 72/72 PASS.


NEXT STEPS (per Codex §NEXT REVIEW)
===================================

1. Codex BLOCK RECHECK 4 for S2-BLOCK-005 checklist H only.
2. After PASS:
   - Owner runs Review/OWNER_VERIFICATION_STAGE_2.txt 9-step A..I in
     SU2017+ (per Q002=A; SU2017 also closes R004 caveat).
   - Owner drops report to Prompt/OWNER_REPORT_STAGE_2_<date>.txt.
3. Stage 6 UI (per R003+R005).
4. Stage 7 final report (PI_TASK_001 §22).
5. Final Gate (R004 posture B): real SU2017 load of complete
   production entry path is the closing evidence for Q004.

Agent awaits Codex BLOCK RECHECK 4 result for S2-BLOCK-005 (checklist H).

============================================================
END
============================================================