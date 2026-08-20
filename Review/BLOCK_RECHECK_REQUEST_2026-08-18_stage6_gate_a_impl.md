# BLOCK RECHECK REQUEST — Gate A Stage 6 Core contract implementation

Created:    2026-08-18
Stage:      6 Gate A — pure-Ruby core contract
Source:     Review/STAGE_6_PLAN_REVISED_2026_08_18_PASS4.md (CodeX Round 014 PASS-after-override)
Fix commit: f68f4bd feat(stage6): Gate A Core contract — 8 new pure-Ruby core files + 8 test files + 1 lint
Tests:      161/161 PASS (was 72; +89 new from this commit; 0 regressions)

PURPOSE
=======

Per Cicada 2026-08-18 long-term-autonomy protocol section 四:
  "Gate A 正常评审触发点：
   - Gate A 完整实现完成；
   - 全部相关测试通过；
   - 保持 Ruby 2.2.4 兼容；
   - 有稳定 Git commit；
   - 生成一个完整 Gate A implementation review packet 到 Review\。
   不要再发送纯计划 Pass 5 给 Codex。"

This packet replaces any further plan-pass loop. Codex reviews the
implementation directly against the plan's locked contracts.

CONTEXT
=======

Current base/head: f68f4bd (aeced98 + 1 commit)
Previous Stage 2 verdict: PASS (all 6 BLOCKs closed)
Previous Stage 6 plan verdict (CodeX Round 014): active-edit-context
  depth / completeness is moved to Gate B hardening (NOT a Gate A blocker).

Files in scope (this commit, Gate A only):
  core/source_reference.rb         (modified: +structural_depth, +pid_path_complete)
  core/synthetic_factory.rb        (modified: explicit kwargs)
  core/structural_facts.rb         (NEW)
  core/issue_registry.rb           (NEW)
  core/issue_id_assigner.rb        (NEW)
  core/issue_normalizer.rb         (NEW)
  core/issue_enricher.rb           (NEW)
  core/issue_grouper.rb            (NEW)
  core/analysis_result.rb          (NEW)
  core/issue_locator_policy.rb     (NEW)
  tests/test_structural_facts.rb   (NEW)
  tests/test_issue_id_assigner.rb  (NEW)
  tests/test_issue_registry.rb     (NEW)
  tests/test_issue_normalizer.rb   (NEW)
  tests/test_issue_enricher.rb     (NEW)
  tests/test_issue_grouper.rb      (NEW)
  tests/test_analysis_result.rb    (NEW)
  tests/test_issue_locator_policy.rb (NEW)
  tests/test_core_no_host_dependency.rb (NEW)
  scripts/prompt_monitor*.ps1      (NEW: 5-min Prompt/ monitor)
  .gitignore                       (modified: data/_check_tmp)

WHAT IS DONE
============

1. SourceReference now carries structural identity:
   - entity_id: optional (was required), Integer or nil
   - persistent_id_path: Array<Integer> with nil-preserved entries
   - structural_depth: Integer (default 0; production MUST pass explicit)
   - pid_path_complete: Boolean (default false; production MUST pass explicit;
                              fail-closed semantics)
   - All existing tests pass without modification (backward-compatible defaults).

2. 8 new pure-Ruby core files:
   - core/structural_facts.rb — pid_path_complete invariants; structural_depth
     = active_path_count + ancestry_count + 1
   - core/issue_registry.rb — tolerant validation; required-key Hash contract;
     per-type CanonSeverity; diagnostic-tolerant drop; summary; groups
   - core/issue_id_assigner.rb — issue_id = "type|canonical_keys|counter"
     where canonical_keys is the lex-sorted Array<Integer.to_s.join('.')> of
     each source's pid_path (with geometry fallback when empty)
   - core/issue_normalizer.rb — kind -> issue_type; Symbol -> String;
     UTF-8 preserved; control chars stripped (NUL..US, DEL)
   - core/issue_enricher.rb — edge_ids -> SourceToken array; whole-token dedup;
     locatable derivation per CodeX BLOCK-001 v4
   - core/issue_grouper.rb — canonical order; within-group ASC by issue_id;
     CodeX Q1 default-open (any :high opens; else first non-empty)
   - core/analysis_result.rb — immutable wrapper; no setters; frozen top-level;
     nested fields immutable by design
   - core/issue_locator_policy.rb — 6 profiles -> target descriptor;
     nested sources NEVER use entityID fallback

3. 8 new test files + 1 lint:
   - 89 new tests (was 72; now 161)
   - test_core_no_host_dependency.rb: scans every core/*.rb for forbidden
     tokens (Sketchup, UI, Geom, compatibility/, extension/) — hard FAIL on hit

4. Prompt monitor (5-min polling daemon):
   - scripts/prompt_monitor.ps1 — detached background watcher
   - scripts/prompt_monitor_one_shot.ps1 — single-run variant
   - scripts/check_monitor.ps1 — status helper
   - scripts/restart_monitor.ps1 — restart-and-verify
   - Live state: confirmed running (PID at startup; state file at
     data/_check_tmp/prompt_monitor_state.json)
   - Already processed 13 historical Codex/Owner files at startup

NITs from CodeX Round 014 — addressed
==================================

NIT 1: backward-compat defaults that fail closed
  - pid_path_complete: defaults to false (NOT true)
  - structural_depth: defaults to 0
  - Production callers (extension/preflight_runner.rb) MUST pass both
    explicitly. Gate B scope will enforce this.

NIT 2: source_reference.py -> .rb
  - Fixed: all test files are .rb; the test_extension_reference
    mentioned in the plan was always .rb in our environment.

NIT 3: Owner Verification N.7 sampler
  - Out of Gate A scope; deferred to Gate B (no SU runtime in core/).

NIT 4: test source listing
  - See test_core_no_host_dependency.rb section "covers expected files".

RISK TABLE CORRECTNESS (CodeX Round 014 NIT)
===========================================

The 6 locator profiles from §6.3 of the Stage 6 plan are mapped
verbatim in core/issue_locator_policy.rb. Risk table numbering in the
plan is correct; no architecture change was made.

REGRESSION CHECK
================

Existing test files exercised unchanged:
  - tests/test_geometry_core.rb (SourceReference, EdgeRecord, etc.)
  - tests/test_preflight.rb (PreflightAnalyzer)
  - tests/test_preflight_runner.rb (PreflightRunner)
  - tests/test_synthetic_01_through_10.rb (TC-01..10)
  - tests/test_analyzers, tests/test_dispatch, etc.

Full suite result (commit f68f4bd):
  PASS  161 (was 72; +89 new)
  FAIL  0
  ERROR 0

RUBY 2.2.4 COMPATIBILITY
=======================

Verified: no &., no pattern matching, no frozen_string_literal, no numbered
parameters, no $ERROR_INFO, no endless defs. All code targets Ruby 2.2.4
baseline per Codex Q003 answer and Stage 2 conventions.

RUN COMMAND
===========

  D:\Projects\SU-AI-Plugin\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe \
    tests/run_all.rb

(Note: the vendor Ruby is 2.7.8 for the Windows agent sandbox; the
code itself is also Ruby 2.2.4 compatible as listed above.)

NEXT REVIEW (CodeX Gate A)
=========================

CodeX reviews:
  - 1. structural identity (pid_path_complete + structural_depth) in
       SourceReference / StructuralFacts
  - 2. UIIssue Hash contract (12 keys, Symbol keys, canonical severity)
  - 3. SourceToken 4-field shape (pid_path, entity_id, nested, complete)
  - 4. Locatable derivation per CodeX BLOCK-001 v4
  - 5. Deterministic issue_id construction
  - 6. Core/host boundary (no Sketchup/UI/Geom/compatibility/extension)
  - 7. NIT absorption (defaults, .rb extension, immutability contract)
  - 8. 161/161 test pass + 0 regression on existing tests

After Gate A PASS, Gate B is authorized (per Cicada 2026-08-18 section
四). Gate B must additionally prove:
  1. structural_depth from real model.active_path entity count, NOT
     filtered PID array length
  2. active-path completeness computed BEFORE nil-PID filtering
  3. missing any active-path container PID -> fail closed
  4. incomplete nested source NEVER uses entityID fallback
  5. two tests required: complete active path + active path with one
     missing PID

LONG-TERM-AUTONOMY BOUNDARY
===========================

Per Cicada 2026-08-18 sections 五 and 六, this Gate A implementation:
  - Stays within the locked R003-R005 Stage 6 scope
  - Does NOT add overlay, repair, or source-model mutation
  - Does NOT push / publish / release
  - Does NOT bypass Owner real-SU verification
  - Does NOT change R001-R005 product decisions

Owner Verification Stage 6 (new file in Review/) J..N steps still apply
once Gate A + Gate B both pass.

AGENT AWAITS CODEX ROUND 014 GATE A VERDICT
==========================================
