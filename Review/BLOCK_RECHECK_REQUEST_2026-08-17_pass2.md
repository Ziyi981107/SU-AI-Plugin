# BLOCK RECHECK REQUEST 2 — S2-BLOCK-002/004/005/006

Created:    2026-08-17
Stage:      2 BLOCK rework 2nd pass
Source:     Prompt/CODEX_REVIEW_005_2026-08-17_BLOCK_RECHECK.txt
Fix commit: d7ac371 fix(stage-2): resolve Codex BLOCK rework 2nd pass
Tests:      65/65 PASS (was 50/50 after pass 1; +15 for pass-2 recheck evidence)

Already CLOSED (must NOT be reopened):
  S2-BLOCK-001  (one Edge -> one EdgeRecord)
  S2-BLOCK-003  (no &. in production entry path)


PURPOSE
=======

Per Codex Review 005 §NEXT REVIEW:
  "Recheck only: S2-BLOCK-002, S2-BLOCK-004, S2-BLOCK-005, S2-BLOCK-006.
   S2-BLOCK-001 and S2-BLOCK-003 are closed and must not be reopened."

This file is the recheck evidence packet for the 4 remaining BLOCKS.
Each S2-BLOCK-### below shows: location, fix summary, automated test
evidence, and post-fix syntax sweep result.

Owner real-SU verification stays PAUSED until this recheck passes
(per Codex Review 005 §NEXT REVIEW).

-----------------------------------------------------------

S2-BLOCK-006 — Capability/version probes use wrong real-SU API
=============================================================

Location:    compatibility/su_capability.rb (html_dialog?, sketchup_version,
             product_year added), tests/test_preflight.rb
Fix:
  - HtmlDialog is UI::HtmlDialog, not Sketchup::HtmlDialog. html_dialog?
    now probes defined?(UI::HtmlDialog).
  - Sketchup.version returns a dotted String in modern SU; calling
    .to_i yields the leading numeric component (24), NOT the calendar
    year. Added product_year that maps Sketchup.version_number -> year
    via explicit table (17..26 -> 2017..2026). sketchup_version kept
    for raw display.

Recheck evidence (tests/test_preflight.rb):
  PASS  capability.HtmlDialog: outside SU returns false (R002 + S2-BLOCK-006)
  PASS  capability.HtmlDialog: positive — fake UI::HtmlDialog defined returns true (S2-BLOCK-006)
  PASS  capability.version: product_year returns nil outside SU; sketchup_version returns nil too (S2-BLOCK-006)
  PASS  capability.version: product_year maps Sketchup.version_number -> calendar year (S2-BLOCK-006)

S2-BLOCK-004 — Preflight metrics + performance
==============================================

Location:    core/preflight.rb
Fix:
  - non_zero_z_edge_count now uses OR semantics: an Edge with even ONE
    off-plane endpoint is a non-zero-Z Edge (was AND).
  - collect_distinct_vertices(edges, coord_eps:) takes eps explicitly;
    Preflight passes config.tolerance.coordinate_epsilon (was hardcoded
    1e-6; ignored Company Profile overrides).
  - Vertex dedup uses O(V) spatial hash (bucket_key + per-bucket linear
    scan). Previous result.any? full scan was O(V^2) and gave ~4.4s for
    5000 disconnected Edges.
  - Perf target met: 5000 edges Preflight now < 2s.

Recheck evidence (tests/test_preflight.rb):
  PASS  preflight.S2-BLOCK-004: edge with one endpoint on Z=0 and one off-plane
        -> non_zero_z_edge_count=1
  PASS  preflight.S2-BLOCK-004: custom config.tolerance.coordinate_epsilon controls
        vertex merge (tight=4 distinct, loose=3 distinct)
  PASS  preflight.S2-BLOCK-004: perf — 5000 disconnected Edges Preflight under 2 seconds

S2-BLOCK-002 — Machine-resolvable source identity + edit-context + non-commutative coverage
========================================================================================

Location:    core/source_reference.rb, extension/preflight_runner.rb,
             compatibility/su_capability.rb
Fix:
  - SourceReference now carries persistent_id_path (Array<Integer>) as
    the canonical machine-resolvable identity (containers from model
    root down to leaf Edge PID). instance_path is a display label only.
    Default empty array is now frozen (per NIT: mutability consistency).
  - walk_selection_world builds PID path during recursion via
    safe_persistent_id on each container; yields (entity, world_points,
    pid_path, label_path) tuple to snapshot builder.
  - active_edit_context(model) helper: returns active edit context
    transform + PID path; seeds walk's world_t and pid_path so selected
    Edges inside an active edit context are reported in model-space
    world coords (NOT local-to-context).
  - resolve_pid_path(model, pid_path) wraps
    Model#instance_path_from_pid_path with safe-rescue.

Recheck evidence (tests/test_preflight_runner.rb):
  PASS  S2-BLOCK-002 (r2): persistent_id_path is Array<Integer>
        with one PID per container + leaf PID
  PASS  S2-BLOCK-002 (r2): two ComponentInstances sharing one
        definition INSIDE ONE outer Group -> 2 occurrences
  PASS  S2-BLOCK-002 (r2): rotation + non-uniform scale + translation
        nested -> exact world coords (30deg z + scale(2,3,1) + trans
        (10,20,30) at 3 levels verified manually)
  PASS  S2-BLOCK-002 (r2): active edit-context seeds walk transform
        (selected Edge inside active Group -> world coords)
  PASS  S2-BLOCK-002 (r2): no active edit-context -> identity seed
  PASS  S2-BLOCK-002 (r2): snapshot PID paths resolve back through
        model.instance_path_from_pid_path

S2-BLOCK-005 — Owner checklist + invalid handling
==================================================

Location:    Review/OWNER_VERIFICATION_STAGE_2.txt,
             extension/preflight_runner.rb, tests/_fake_su.rb
Fix:
  - Owner checklist rewritten: Entities#add_line replaces
    v.position = ... (no setter exists on real SU Vertex).
  - Added executable recursive fingerprint helper script (paste
    into Ruby Console; captures persistent_id, transformation, layer,
    edges/groups/components recursively). Owner runs it before AND
    after Preflight; fp_before == fp_after.
  - vertex_point_world raises InvalidGeometryError instead of silently
    returning [0,0,0] (no fabricated origin geometry).
  - walk_entity_world has per-child rescue; one bad child does not
    abort siblings.
  - safe_each wraps iteration in begin/rescue; returns items
    successfully enumerated before any failure.
  - entity_valid? checks valid?/erased?/deleted?; walk skips invalid
    entities cleanly.
  - FakeSU::Edge#erase! flips state; subsequent start/end/vertices
    raise InvalidEntityError (realistic behavior).
  - Per-child rescue in walk; sibling traversal continues.

Recheck evidence (tests/test_preflight_runner.rb):
  PASS  S2-BLOCK-005 (r2): erased Edge -> ZERO EdgeRecords from that Edge
        (count == 1, not >= 1)
  PASS  S2-BLOCK-005 (r2): invalid vertex (start nil) -> Edge skipped,
        no origin EdgeRecord
  PASS  S2-BLOCK-005 (r2): invalid container with one bad child ->
        siblings still walked


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

Note: $ERROR_MESSAGE is a 1.x-era alias for $!.message syntax that is
available in Ruby 2.2.4. We use it instead of `$ERROR_INFO&.message`
(which would be post-2.2).


TOTAL TEST COUNT
================

Before pass 2:  50 tests, 50 pass.
After pass 2:   65 tests, 65 pass.
Delta:          +15 tests (4 BLOCK-006 + 3 BLOCK-004 r2 + 6 BLOCK-002
                r2 + 3 BLOCK-005 r2 + 2 runner helpers' tests
                auto-exercised).


NEXT STEPS (per Codex §NEXT REVIEW)
===================================

1. Codex BLOCK RECHECK 2 for S2-BLOCK-002 / 004 / 005 / 006 only.
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

Agent awaits Codex BLOCK RECHECK 2 result for S2-BLOCK-002/004/005/006.

============================================================
END
============================================================