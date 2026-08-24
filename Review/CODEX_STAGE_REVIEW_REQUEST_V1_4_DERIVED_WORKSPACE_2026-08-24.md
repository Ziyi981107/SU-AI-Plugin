# CodeX V1.4 Stage Review Request — Derived Workspace + Repair Foundation
Date: 2026-08-24
For: CodeX Technical Reviewer (per master plan §20 REVIEW A — mandatory after V1.4)

======================================================================
REVIEW MODE
======================================================================

REVIEW MODE: STAGE
SCOPE: V1.4 (Derived Workspace + Repair Foundation) end-to-end on
       branch `v1.4-derived-workspace`, base / head below.
DEPTH: full V1.4 production + test diff against the V1.3 close baseline.

The V1.4 directive 030 ("PASS TO IMPLEMENT V1.4, 0 BLOCKs") authorized
the V1.4 foundation work. This packet asks CodeX to engage the
mandatory V1.4 Stage Review per the master plan §20 / REVIEW A.

======================================================================
BRANCH / BASE / HEAD
======================================================================

  branch:        v1.4-derived-workspace
  base (V1.3 close): 550eb74
  current HEAD: 707273a
                  fix(v1.4): V14-RUNTIME-BLOCK-003 — correct
                  SketchUp add_group contract + RBZ smoke
                  test isolation

Commits in scope (V1.4 implementation + post-V14 BLOCK rework):

  ... see `git log --oneline 550eb74..HEAD` for the full list ...
  ddefe2f  Stage 1 -- SourceSnapshot / fingerprint / execution-config
  de233be  Stage 2 -- RepairPlan / RepairAction / lifecycle
  d2a8328  Stage 3 -- DerivedGeometryWorkspace + adapter + fingerprint
  431af5d  Stage 4 -- Working Mode runner + UI plumbing + tests
  cc246b2  CodeX BLOCK-R3 recheck -- 3 BLOCKs closed
  ae8e7d7  CodeX BLOCK recheck rework -- 7 BLOCK fixes
  dd5d1d6  CodeX BLOCK rework -- real Prepare/Discard/Rebuild call chain
  bfc1368  V14-RUNTIME-BLOCK-001 -- host action dispatch on window.sketchup
  5d43be4  CodeX BLOCK-R4-1 -- Face-only selection -> :failed
  3a6afcc  Phase-3 self-audit -- atomic partial-cleanup + recovery
  78d0803  Phase 2 self-audit -- production-chain ordinary defects
  e883e18  Phase 4 -- Owner checklist update + report template
  bcfd348  V14-RUNTIME-BLOCK-002 -- deterministic production adapter loading
  707273a  V14-RUNTIME-BLOCK-003 -- SketchUp add_group contract + RBZ smoke

======================================================================
V1.4 PRODUCTION CODE SCOPE (in this branch HEAD)
======================================================================

Core data layer (V1.4 stages 1-2, plus V1.0-V1.3 contracts preserved):

  extension/su_ai_plugin/core/tolerance.rb
  extension/su_ai_plugin/core/analysis_config.rb
  extension/su_ai_plugin/core/source_reference.rb
  extension/su_ai_plugin/core/source_fingerprint.rb
  extension/su_ai_plugin/core/execution_config_snapshot.rb
  extension/su_ai_plugin/core/source_snapshot.rb
  extension/su_ai_plugin/core/derived_entity_record.rb
  extension/su_ai_plugin/core/derived_workspace_fingerprint.rb
  extension/su_ai_plugin/core/repair_plan.rb
  extension/su_ai_plugin/core/face_record.rb
  extension/su_ai_plugin/core/face_inventory_grouper.rb
  extension/su_ai_plugin/core/analysis_result.rb
  extension/su_ai_plugin/core/derived_workspace_adapter.rb

V1.4 stages 3-4 (derived workspace + adapter + Working Mode runner):

  extension/su_ai_plugin/core/derived_geometry_workspace.rb
  extension/su_ai_plugin/core/working_mode_runner.rb
  extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb

V1.4 dialog integration (Working Mode callbacks in dialog_runner):

  extension/su_ai_plugin/dialog_runner.rb
  extension/su_ai_plugin/analyzers_runner.rb
  extension/su_ai_plugin/ui_bridge.rb

Frozen baselines preserved (NOT in scope of this review):
  - V1.0 tag `v1.0-candidate-2026-08-19` at `56ea611`
  - V1.1 branch `v1.1-layer-semantic-mapping` at `823feab`
  - V1.2 branch `v1.2-issues-by-layer` at `0460c6b`
  - V1.3 branch `v1.3-face-inventory` at `550eb74`

======================================================================
NEW / CHANGED DOCUMENTS IN THIS PACKET (2026-08-22 .. 2026-08-24)
======================================================================

  Prompt/OWNER_REPORT_V1_4_DERIVED_WORKSPACE_2026-08-24.txt
                          Owner Gate 2 evidence (V14-1..V14-10 PASS).
  Review/OWNER_VERIFICATION_V1_4_DERIVED_WORKSPACE_2026-08-21.txt
                          Updated V14-8 label-targeted one-shot snippet
                          + V14-10 shared-definition wording note
                          + new-selection-must-re-Analyze note.
  Prompt/OWNER_REPORT_V1_4_DERIVED_WORKSPACE_2026-08-21_TEMPLATE.txt
                          Same updates mirrored in the blank template.
  tests/test_v14_targeted_regression.rb (NEW)
                          6 targeted regression tests:
                          V14-TARGETED-1..6 cover the label-targeted
                          one-shot patch contract, the 4-edge x 2-instance
                          shared-definition production path, and the
                          fresh-AnalysisResult-per-selection contract.
  CURRENT_STATE.md
                          Updated with BLOCK-003 section + Stage 4 correction.

======================================================================
OWNER V14-1..V14-10 REAL SU2020 EVIDENCE
======================================================================

All 10 steps PASS on real SketchUp 2020 with the post-V14-RUNTIME-BLOCK-003
rebuilt rbz (commit 707273a). Full evidence:

  V14-1  PASS  -- Working Mode initial state == 'none'.
  V14-2  PASS  -- Prepare creates 4 derived groups; source unchanged;
                   derived groups at model root with SU-AI-Derived-* prefix.
  V14-3  PASS  -- Source entityID / persistent_id / 4 edges / 1 face unchanged.
  V14-4  PASS  -- Discard erases all 4 derived groups (precise cleanup).
  V14-5  PASS  -- Source unchanged after Discard.
  V14-6  PASS  -- Rebuild discards old groups, creates 4 new groups;
                   source unchanged; fingerprint invariant.
  V14-7  PASS  -- Source unchanged after Rebuild.
  V14-8  PASS  -- Label-targeted one-shot begin_operation injection
                   (Discard label does NOT match TARGET_LABEL, so the
                   patch is preserved for the Prepare click; Prepare
                   begin_operation fires the injection; patch is
                   self-restored; no patch leakage into V14-9 / V14-10).
  V14-9  PASS  -- Undo after Prepare removes the latest derived group;
                   source unchanged.
  V14-10 PASS  -- Nested groups + shared ComponentDefinition x 2 instances:
                   8 independent derived edge occurrences
                   (2 instances x 4 edges per definition);
                   SOURCE_DEFINITION_EDGES=4 unchanged;
                   INSTANCE_OCCURRENCES=2;
                   UNIQUE_PID_PATHS=8;
                   WORLD_COORDINATES_MATCH=true (after re-Analyze).

Full evidence per step: Prompt/OWNER_REPORT_V1_4_DERIVED_WORKSPACE_2026-08-24.txt

======================================================================
AUTOMATED REGRESSION EVIDENCE (rbz build HEAD = 707273a)
======================================================================

Ruby test suite (tests/run_all.rb):

  .vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb
  --- 628 tests: 628 pass, 0 fail, 0 error ---

(Was 622 before this packet; +6 from tests/test_v14_targeted_regression.rb.)

Targeted regressions (V1.4 Gate 2 hardening):

  DANGER (15 tests)                        -- 15 pass
  V14 production call chain (7 tests)      -- 7 pass
  V14-RUNTIME-BLOCK-002 (6 tests)          -- 6 pass
  V14-TARGETED (6 tests; new)              -- 6 pass

Node.js DOM render contract:

  node tests/test_html_render_dom.js
  PASS  (148 / 148 DOM assertions)

RBZ smoke (extracted package installs + boots via FakeUI):

  tests/run_all.rb "RBZ" filter
  -- 8 RBZ smoke tests pass (package layout, entry-point, asset trio,
     support folder layout, dev-only-path exclusion, dev/packaged
     file-set equality, syntax check, extracted entry-point boots
     through FakeUI with menu + handler + SketchupExtension.new
     String target).

`git diff --check`:
  clean.

======================================================================
RBZ BUILD RESULT
======================================================================

  Build command:
    .vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe scripts/build_rbz.rb

  Path:
    D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz

  Size:
    416,996 bytes

  SHA256:
    0fc5ee407c52a4c70ca469c6e9549f032dcd21cb4549bfade56aed49b1b7d255

  Entry count:
    53 entries

  Modified:
    2026-08-24 10:12

  Commit:
    707273a (fix(v1.4): V14-RUNTIME-BLOCK-003 — correct SketchUp
    add_group contract + RBZ smoke test isolation)

  Distinct-from-prior:
    Prior rbz was 416,781 bytes (SHA256
    464cd637a395cb3de563779ec6ca243702807c38c9d8f8b61d54c891e50b24b6,
    dated 2026-08-21). The current rbz differs in size and SHA256
    and carries the V14-RUNTIME-BLOCK-003 production add_group fix
    (verified by extracting
    su_ai_plugin/compatibility/su_derived_workspace_adapter.rb
    from the archive and confirming it uses `entities.add_group`
    (no args) + `g.name = ...`, NOT
    `entities.add_group(NAME_PREFIX + name.to_s)`).

======================================================================
WHAT THIS REVIEW IS REQUESTED TO COVER
======================================================================

Per master plan §20 REVIEW A (mandatory after V1.4) and directive
030 NEXT REVIEW scope:

  1. source vs derived ownership
  2. SourceSnapshot and provenance contract
  3. deep immutability / fingerprint evidence
  4. shared-definition isolation (gate B)
  5. failure / discard / rebuild behavior
  6. SU2017+ compatibility implications
  7. relevant regressions and the real SU2020 workflow evidence

In addition, this packet asks CodeX to confirm the BLOCK-003 fix
specifically:

  - Sketchup::Entities#add_group contract: zero args + `g.name = ...`
  - FakeEntities.add_group(*args) raises TypeError on non-zero args
  - FakeUI::FakeModel responds to both :entities and :active_entities
  - test_rbz_smoke.rb restores in-tree production files after the
    smoke test (preventing stale extracted code from polluting
    subsequent tests via class re-opening)

======================================================================
WHAT THIS REVIEW IS EXPLICITLY NOT REQUESTED TO COVER
======================================================================

  - Re-opening V1.0 / V1.1 / V1.2 / V1.3 closed scope.
  - Re-opening CodeX 020 / 022 / 023 / 024 / 025 / 028 / 029 closed scope.
  - Re-opening CodeX 030 (the pre-build directive) — already PASS.
  - V1.5 implementation. V1.5 Phase 1 plan exists at
    Review/V1_5_HIGH_CONFIDENCE_AUTO_REPAIR_IMPLEMENTATION_PLAN_2026-08-24.md
    but production executor code MUST NOT start before this V1.4
    review PASSES.
  - V1.6 / V1.7 / V1.8 / V1.9 scope.

======================================================================
KNOWN NITs / DEBT (parked; non-blocking)
======================================================================

  - DANGER 9a (adapter.add_face_to_group rejects Integer vertex):
    this test stubs the FAKE adapter (which has the strict Float
    check). The production adapter's per-vertex validation lives
    at the FakeAdapter boundary because the production adapter's
    add_face_to_group is reached only via the FakeAdapter path in
    the test env. The intent (reject non-Float vertices) is
    enforced at the boundary closest to the host call. Track as
    DEBT for the production-side Float-coercion guard (V1.5+).

  - V14-TARGETED-5 uses the PRODUCTION adapter + FakeUI model to
    verify 8 independent derived edge occurrences for the
    shared-definition case. The corresponding pure-Ruby coverage
    is in DANGER 3 (2-edge case). V14-TARGETED-5 extends to 4-edge
    x 2-instance via the production call chain. Track as
    DEBT only if the production call chain ever changes its
    edge-derivation loop.

======================================================================
CURRENT GIT STATE
======================================================================

  On branch v1.4-derived-workspace
  nothing to commit, working tree clean

  HEAD = 707273a
       fix(v1.4): V14-RUNTIME-BLOCK-003 — correct SketchUp
       add_group contract + RBZ smoke test isolation

======================================================================
REQUEST
======================================================================

CodeX: please review the V1.4 production diff
(base `550eb74`..HEAD `707273a`) against the locked V1.4 directive
030 contracts (gate A + gate B + the 10 mandatory risk tests) and
report PASS WITH NITS or BLOCK.

If BLOCKs come back, Pi will fix them in a narrow follow-up commit
and ask for recheck.

If PASS WITH NITS:
  - Pi will fix NITs that are small + low-risk + clearly stable
    in a narrow follow-up commit.
  - Pi will record DEBT-class NITs for V1.5 Phase 1 / V1.6+ work.

If PASS:
  - Pi will dispatch the V1.5 Phase 1 Pi Task from
    Prompt/PI_TASK_V1_5_HIGH_CONFIDENCE_AUTO_REPAIR_PHASE1_2026-08-24.txt
    once CodeX explicitly greenlights V1.5 scope in a follow-up
    guidance file. No production V1.5 code will start before that.

Until then: stop at the V1.4 close boundary. Do not push, publish,
install, or release.