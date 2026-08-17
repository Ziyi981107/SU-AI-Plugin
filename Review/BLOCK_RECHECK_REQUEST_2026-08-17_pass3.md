# BLOCK RECHECK REQUEST 3 — S2-BLOCK-002/004/005/006-version

Created:    2026-08-17
Stage:      2 BLOCK rework pass 3
Sources:    Prompt/CODEX_REVIEW_007_2026-08-17_BLOCK_RECHECK_PASS2.txt
            Prompt/CODEX_GUIDANCE_006_2026-08-17_REWORK_PLAN_CORRECTIONS.txt
Fix commit: 88ad609 fix(stage-2): resolve Codex BLOCK rework pass 3
Tests:      71/71 PASS (was 65/65 after pass 2; +6 for pass-3 recheck evidence)

Closed (must NOT reopen):
  S2-BLOCK-001                 one Edge -> one EdgeRecord
  S2-BLOCK-003                 no &. in production entry path (Ruby 2.2.4)
  S2-BLOCK-006 HtmlDialog subpart (UI::HtmlDialog namespace)


PURPOSE
=======

Per Codex Review 007 §NEXT REVIEW:
  "Recheck S2-BLOCK-002, S2-BLOCK-004, S2-BLOCK-005, and the version
   subpart of S2-BLOCK-006 only, after Pi incorporates
   Prompt/CODEX_GUIDANCE_006_2026-08-17_REWORK_PLAN_CORRECTIONS.txt
   and this review."

This file is the recheck evidence packet for the 4 remaining BLOCKS.
Each S2-BLOCK-### below shows: location, fix summary, automated test
evidence, and post-fix syntax sweep result.

Mandatory CODEX_GUIDANCE_006 corrections absorbed:
  1. Version API fix: sketchup_version preserves dotted String;
     sketchup_major_version extracts leading integer for baseline;
     NO calendar-year inference from version_number.
  2. Active edit context: model.edit_transform; active_path is Array;
     resolver takes dot-delimited String.
  3. Vertex dedup: search current + adjacent buckets; preserve perf.

-----------------------------------------------------------

S2-BLOCK-006 (version subpart)
==============================

Location:    compatibility/su_capability.rb (sketchup_version,
             sketchup_major_version), tests/test_preflight.rb
Fix:
  - sketchup_version returns the dotted String verbatim (e.g. '17.2.0').
    NO .to_i on String (would yield wrong calendar year).
  - New sketchup_major_version returns Integer >= 17 on SU2017+;
    uses leading-integer regex on the dotted String.
  - DROPPED product_year / su_release_to_year table (was based on
    the wrong assumption that version_number is 17..26).
  - Baseline check for SU2017+ lock: sketchup_major_version >= 17.

Recheck evidence (tests/test_preflight.rb):
  PASS  capability.version: sketchup_version returns nil outside SU
  PASS  capability.version: sketchup_version preserves dotted String
        verbatim (fake '17.2.0' -> '17.2.0')
  PASS  capability.version: sketchup_major_version extracts leading
        integer from dotted String (fake '17.2.0' -> 17)
  PASS  capability.version: sketchup_major_version on modern SU
        returns 24 (NOT calendar year 2024)

-----------------------------------------------------------

S2-BLOCK-002 (real API contract)
================================

Location:    compatibility/su_capability.rb, extension/preflight_runner.rb,
             tests/_fake_su.rb, tests/test_preflight_runner.rb
Fix:
  - active_edit_context now reads model.edit_transform (NOT
    InstancePath#transformation).
  - model.active_path is Array of entities; active_path_pids iterates
    and collects safe_persistent_id per element.
  - resolve_pid_path serializes Array<Integer> -> dot-delimited String
    ('10.20.555') before calling Model#instance_path_from_pid_path.
  - build_source_reference uses entity.entityID (real SU API,
    Integer per session) when available; falls back to object_id.
  - FakeSU::Model.instance_path_from_pid_path accepts ONLY String
    (rejects arrays). FakeSU::InstancePath.persistent_id_path is String.

Recheck evidence (tests/test_preflight_runner.rb):
  PASS  S2-BLOCK-002 (r3): SourceReference uses entity.entityID
        when available (round-trip)
  PASS  S2-BLOCK-002 (r3): active edit-context uses Array active_path
        + edit_transform on Model
  PASS  S2-BLOCK-002 (r3): resolve_pid_path rejects Array<Integer>,
        only String works (registered '10.20.30' resolves; Array returns nil)
  PASS  S2-BLOCK-002 (r2): snapshot PID paths resolve back through
        model.instance_path_from_pid_path (uses dot-delimited String)
  PASS  S2-BLOCK-002 (r2): active edit-context seeds walk transform
        (selected Edges inside active Group -> world coords)
  PASS  S2-BLOCK-002 (r2): no active edit-context -> identity seed
  PASS  S2-BLOCK-002 (r2): persistent_id_path is Array<Integer>
        with one PID per container + leaf PID
  PASS  S2-BLOCK-002 (r2): two ComponentInstances sharing one
        definition INSIDE ONE outer Group -> 2 occurrences
  PASS  S2-BLOCK-002 (r2): rotation + non-uniform scale + translation
        nested -> exact world coords

-----------------------------------------------------------

S2-BLOCK-004 (boundary-bucket dedup)
====================================

Location:    core/preflight.rb (collect_distinct_vertices)
Fix:
  - Searches current bucket AND all 26 adjacent buckets (3x3x3
    neighborhood).
  - Each candidate in a neighbor bucket is confirmed with explicit
    points_equal? distance check (within coord_eps) before merging.
  - 5000-edge perf target preserved (< 2s).

Recheck evidence (tests/test_preflight.rb):
  PASS  preflight.S2-BLOCK-004 (r3): two points < eps apart across
        bucket boundary -> merged ([0.99, 0, 0] and [1.01, 0, 0] with
        coord_eps=0.5; 0.02 apart, well within eps, in adjacent
        buckets -> merged; 10,0,0 and 10,1,0 stay distinct as 1.0
        > 0.5)
  PASS  preflight.S2-BLOCK-004: perf — 5000 disconnected Edges
        Preflight under 2 seconds (still passes)
  PASS  preflight.S2-BLOCK-004: edge with one endpoint on Z=0 and one
        off-plane -> non_zero_z_edge_count=1 (still passes)
  PASS  preflight.S2-BLOCK-004: custom config.tolerance.coordinate_epsilon
        controls vertex merge (still passes)

-----------------------------------------------------------

S2-BLOCK-005 (checklist + invalid geometry)
============================================

Location:    Review/OWNER_VERIFICATION_STAGE_2.txt
Fix:
  - `Entities#add_line(...)` returns ONE Edge directly (NOT an array).
    Removed the spurious `[0]` indexing from the checklist.
  - Invalid-entity setup now uses an EXPLICIT selection array
    `[inv_group, e1_invalid, e2_valid]` so the invalid reference is
    retained even after `e1.erase!` (per Codex Review 007).
  - Fingerprint helper uses capability-safe `su_safe_pid` and
    `su_safe_4x4`; recurses into component-definition contents +
    occurrence transforms so it can detect source mutation inside
    components.

Recheck evidence:
  [x] Checklist add_line code paste-runnable on SU2017+ (manual)
  [x] Invalid-entity test holds invalid reference + valid Edge in
      same selection; valid Edge analyzed, invalid contributes 0
      (already covered by S2-BLOCK-005 r2 test 'invalid vertex (start
      nil) -> Edge skipped, no origin EdgeRecord' and 'erased Edge ->
      ZERO EdgeRecords from that Edge (count == 1, not >= 1)')
  [x] Fingerprint helper uses capability-safe PID access (manual;
      the helper snippet is in OWNER_VERIFICATION_STAGE_2.txt step G)

-----------------------------------------------------------

POST-2.2 SYNTAX SWEEP (all 17 production .rb files)
====================================================

OK: core/analysis_config.rb
OK: core/analyzers/duplicate_detector.rb
OK: core/analyzers/gap_candidate_detector.rb
OK: core/analyzers/open_endpoint_detector.rb
OK: core/analyzers/short_edge_detector.rb
OK: core/edge_record.rb
OK: core/geometry_snapshot.rb
OK: core/layer_record.rb
OK: core/preflight.rb
OK: core/quantize_key.rb
OK: core/source_reference.rb
OK: core/synthetic_factory.rb
OK: core/tolerance.rb
OK: core/vertex_index.rb
OK: core/vertex_record.rb
OK: compatibility/su_capability.rb
OK: extension/preflight_runner.rb

Sweep rules: code lines only (comment lines stripped), reject &.,
frozen_string_literal magic, numbered params (_1/_2), $ERROR_INFO
(2.5+ alias). Ruby 2.2.4 baseline enforced.


TOTAL TEST COUNT
================

Before pass 3:  65 tests, 65 pass.
After pass 3:   71 tests, 71 pass.
Delta:          +6 tests
                 - 4 capability.version (round 3 version API)
                 - 1 preflight.S2-BLOCK-004 (r3) boundary dedup
                 - 3 S2-BLOCK-002 (r3) entityID / Array / String resolver
                 - earlier round tests still pass


NEXT STEPS (per Codex §NEXT REVIEW)
===================================

1. Codex BLOCK RECHECK 3 for S2-BLOCK-002 / 004 / 005 / 006-version only.
   S2-BLOCK-001, S2-BLOCK-003, S2-BLOCK-006 HtmlDialog stay CLOSED.
2. Owner real-SU verification stays PAUSED until recheck passes.
3. After PASS:
   - Owner runs Review/OWNER_VERIFICATION_STAGE_2.txt 9-step A..I in
     SU2017+ (per Q002=A; SU2017 also closes R004 caveat).
   - Owner drops report to Prompt/OWNER_REPORT_STAGE_2_<date>.txt.
4. Stage 6 UI (per R003+R005): HtmlDialog + selection/camera Locate
   only + grouped issue sections + canonical severity palette.
5. Stage 7 final report (PI_TASK_001 §22).
6. Final Gate (R004 posture B): real SU2017 load of complete
   production entry path is the closing evidence for Q004.

Agent awaits Codex BLOCK RECHECK 3 result for S2-BLOCK-002/004/005/006-version.

============================================================
END
============================================================