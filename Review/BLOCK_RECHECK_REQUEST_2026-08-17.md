# BLOCK RECHECK REQUEST — S2-BLOCK-001..005

Created:  2026-08-17
Stage:    2 BLOCK rework
Source:   Prompt/CODEX_REVIEW_004_2026-08-17_STAGE2_AND_R001_R005.txt
Commit:   eb3cd41 fix(stage-2): resolve Codex BLOCK rework S2-BLOCK-001..005
Tests:    50/50 PASS (was 33/33 before; +17 new tests for recheck evidence)


PURPOSE
=======

Per Codex Review 004 §REQUIRED EXECUTION ORDER step 5:
  "Request Codex BLOCK RECHECK for S2-BLOCK-001..005 only."

This file is the recheck evidence packet for Codex. Each S2-BLOCK-###
below shows: location, fix summary, automated test evidence, and
post-fix syntax sweep result.


S2-BLOCK-001  — One source Edge -> one EdgeRecord
=================================================

Location:    extension/preflight_runner.rb (full rewrite)
Old code:    entity.vertices.each_with_index do |v, i| ... end (created
             two directed half-records per Edge)
New code:    Reads edge.start.position + edge.end.position once, yields
             ONE tuple to the snapshot builder.
Recheck evidence (tests/test_preflight_runner.rb):
  PASS  S2-BLOCK-001: single Edge in selection -> exactly one EdgeRecord
  PASS  S2-BLOCK-001: rectangle in Group -> 4 EdgeRecords (not 8)
  PASS  end-to-end: nested translated component rectangle -> 4 EdgeRecords

S2-BLOCK-002  — Component traversal + accumulated transforms + instance identity
================================================================================

Location:    extension/preflight_runner.rb (full rewrite),
             core/source_reference.rb (added instance_path field)
Fix:
  - Group children walked via group.entities.
  - ComponentInstance children walked via instance.definition.entities
    (NOT instance.entities).
  - Geom::Transformation accumulated through recursion; applied to
    endpoints so EdgeRecord coords are in world space.
  - SourceReference gains instance_path field (Array<String>) describing
    container chain from model root to entity.
  - ComponentInstance label carries object_id hex suffix so two
    instances sharing one definition stay distinct (e.g.
    "ComponentInstance:Window#0xabc123").
Recheck evidence (tests/test_preflight_runner.rb):
  PASS  S2-BLOCK-002: ComponentInstance child lives in definition.entities
  PASS  S2-BLOCK-002: ComponentInstance translation applied to Edge endpoints (world coords)
  PASS  S2-BLOCK-002: two ComponentInstances sharing one definition -> 2 occurrences, distinct world coords
  PASS  S2-BLOCK-002: instance_path distinguishes two ComponentInstance occurrences
  PASS  S2-BLOCK-002: nested Group -> Component -> Group accumulates transforms (1110,1111 world coords)

S2-BLOCK-003  — No &. in production entry path (Ruby 2.2.4)
===========================================================

Location:    extension/preflight_runner.rb (replaced &. with explicit
             nil guards throughout)
Automated syntax sweep result (run across core/, compatibility/,
extension/ — 17 .rb files, all PASS):
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
frozen_string_literal magic comments, and numbered params (_1, _2).
Recheck evidence (tests/test_preflight_runner.rb):
  PASS  S2-BLOCK-003: extension/preflight_runner.rb source contains no
        post-Ruby-2.2 syntax (strips comment lines first)

S2-BLOCK-004  — Preflight metrics match task contract
======================================================

Location:    core/preflight.rb (full rewrite of analyzer + report)
Field changes (with rationale):
  - non_zero_z_count
      -> split into non_zero_z_vertex_count + non_zero_z_edge_count
      -> both use coordinate_epsilon (NOT big_z)
  - new: significant_z_extrema_count (distinct vertices with |Z| > big_z)
  - large_coordinate_count -> large_coordinate_extrema_count (renamed,
      was counting bbox axis extrema not entities / vertices)
  - canonical severity :low / :medium / :high ONLY (R005);
      dropped :info / :warning emissions
  - abnormal_large_coord severity -> :high (R005)
  - deep_nesting severity -> :low (R005)
  - root container = level 1; warning at deepest_nesting >= threshold
      (was > threshold; now >=)
  - mixed selection: selection_type returns 'mixed' if roots have >1 kind
Recheck evidence (tests/test_preflight.rb):
  PASS  preflight.TC-11: empty snapshot -> 0 edges, bbox=nil, no warnings
  PASS  preflight.TC-12: pure 2D rectangle -> no significant-Z warning, bbox covers all edges
  PASS  preflight.TC-13a: Z above coordinate_epsilon but below big_z
        -> counts populated, no significant warning (key BLOCK-004 evidence)
  PASS  preflight.TC-13b: Z above big_z threshold -> significant-Z
        warning, severity :medium
  PASS  preflight.TC-14: abnormal large coord -> abnormal_large_coord
        warning, severity :high
  PASS  preflight.TC-15: L-shape + multiple layers -> counts + layer
        distribution accurate
  PASS  preflight.EXTRA: SU-side facts from snapshot.preflight are passed through to report
  PASS  preflight.EXTRA: deep_nesting warning fires at >= threshold (root=1), severity :low
  PASS  preflight.EXTRA: deep_nesting does NOT fire below threshold (root=1)
  PASS  preflight.EXTRA: shared endpoint of two edges counted ONCE in vertex count

S2-BLOCK-005  — Owner verification checklist usable + source integrity check
==============================================================================

Location:    Review/OWNER_VERIFICATION_STAGE_2.txt (full rewrite)
Fix:
  - Setup steps rewritten to use Entities#add_line inside a disposable
    test Group (NOT production / source CAD).
  - Source integrity: deterministic fingerprint (entity counts,
    persistent_ids, endpoint coords, container transforms, layer
    assignments) BEFORE vs AFTER analysis. Diff must be empty
    (modulo selection state).
  - Cleanup: explicit test-group erase by Owner (NOT Analyzer behavior).
  - Reproducible invalid/erased entity test: 1 valid + 1 erased edge
    -> report still has the valid one.
  - 9 steps A..I cover plugin load, capability detection, single-group
    Preflight, non-zero Z warning, large coord warning, nested groups,
    source fingerprint, invalid entity, translated component.
Recheck evidence (tests/test_preflight_runner.rb):
  PASS  S2-BLOCK-005-replacement: one valid + one erased Edge ->
        analysis continues with the valid one
  PASS  end-to-end: nested translated component rectangle -> PreflightReport
        with correct counts


R002 amendment  — HtmlDialog capability probe
=============================================

Location:    compatibility/su_capability.rb (added html_dialog?)
Fix:
  - SUAnalysis::Compatibility::SUCapability.html_dialog? returns true
    on SU 2017+, false outside SU.
  - Standalone Stage 5 (compatibility/su_version_probe.rb) CANCELLED
    per Codex R002 = C with amendment.
Recheck evidence (tests/test_preflight.rb):
  PASS  capability.HtmlDialog: outside SU returns false (R002 evidence)


TOTAL TEST COUNT
================

Before rework: 33 tests, 33 pass, 0 fail, 0 error.
After rework:  50 tests, 50 pass, 0 fail, 0 error.
Delta:         +17 tests (5 BLOCK recheck evidence + 5 Preflight
               metric update + 3 deep_nesting + 4 BLOCK-005 + R002 +
               SourceReference instance_path)


WHAT IS NOT IN THIS REWORK
==========================

- Stage 6 UI (separate stage, after BLOCK recheck PASS + Owner SU verify)
- Stage 7 final report
- Any Repair feature (per PI_TASK_001 §17 / §91)


FILES CHANGED (commit eb3cd41)
================================

Modified:
  Review/OWNER_VERIFICATION_STAGE_2.txt     BLOCK-005 fix
  compatibility/su_capability.rb            R002 amendment (html_dialog?)
  core/preflight.rb                         BLOCK-004 fix
  core/source_reference.rb                  BLOCK-002 (instance_path)
  extension/preflight_runner.rb             BLOCK-001/002/003 fix
  tests/runner.rb                           +4 helpers (refute_match,
                                             assert_match, refute_equal)
  tests/test_preflight.rb                   BLOCK-004 + R002 +
                                             S2-BLOCK-002 (instance_path)

Added:
  tests/_fake_su.rb                         adapter-level stub fixtures
  tests/test_preflight_runner.rb            adapter-level tests (12 cases)


NEXT STEPS (per Codex §REQUIRED EXECUTION ORDER)
=================================================

1. Owner in real SU: run Review/OWNER_VERIFICATION_STAGE_2.txt
   checklist A..I (per Q002=A) and drop report to
   Prompt/OWNER_REPORT_STAGE_2_<date>.txt.
2. Owner with SU2017: complete R004 posture B — load complete
   production entry path; this satisfies the Q004 caveat closure.
3. Stage 6 (UI) per R003/R005: HtmlDialog + selection/camera Locate
   only (no overlay, no mutation).
4. Stage 7 (final report per PI_TASK_001 §22).

Agent awaiting Codex BLOCK RECHECK result for S2-BLOCK-001..005 only.

============================================================
END
============================================================