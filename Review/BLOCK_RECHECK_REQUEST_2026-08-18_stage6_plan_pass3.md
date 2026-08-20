# BLOCK RECHECK REQUEST — Stage 6 plan pass 3 (S6-PLAN-BLOCK-001 v3 + S6-VERIFY-BLOCK-001)

Created:    2026-08-18
Stage:      6 plan recheck (still pre-build; no Stage 6 code exists)
Sources:    Prompt/CODEX_REVIEW_012_2026-08-18_STAGE6_PLAN_PASS2_RECHECK.txt
Plan:       Review/STAGE_6_PLAN_REVISED_2026_08_18_PASS3.md
Verify:     Review/OWNER_VERIFICATION_STAGE_6.txt (revised)
Code base:  aeced98 (no Stage 6 implementation exists yet)


PURPOSE
=======

Per Codex Review 012 §NEXT REVIEW:
  "Recheck S6-PLAN-BLOCK-001 plus S6-VERIFY-BLOCK-001 only.
   S6-PLAN-BLOCK-003 remains CLOSED.
   S6-PLAN-BLOCK-002 and S6-PLAN-BLOCK-004 remain CLOSED.
   After both blocks close: PASS TO IMPLEMENT Gate A.
   Do not implement Gate A before that recheck."

This file is the focused plan-recheck packet for the 2 remaining
BLOCKS. Each BLOCK below shows: location, fix summary, plan-level
evidence (table / test list / contract clarification), and the
evidence that the 6 NITs are addressed.

Closed (must NOT reopen):
  S6-PLAN-BLOCK-002    one snapshot per command + menu entrypoint
  S6-PLAN-BLOCK-003    pure-core/host boundary (extension/ hosts
                        locator + display formatter; test_core_no_host_dependency
                        lint)
  S6-PLAN-BLOCK-004    HtmlDialog lifecycle (set_file absolute path,
                        callback blocks, ready handshake, FakeUI in tests/,
                        no fake hooks in production SUCapability)

============================================================
S6-PLAN-BLOCK-001 (v3) — structural identity vs PID availability
============================================================

Location:    Review/STAGE_6_PLAN_REVISED_2026_08_18_PASS3.md
             §3.1, §3.2, §3.7, §3.10, §3.11, §4.2, §6.3, §7

Root cause (per Codex Review 012):
  The v2 plan derived `nested = pid_path.size > 1`. This is wrong
  because the existing traversal appends a container's PID only when
  `safe_persistent_id` returns non-nil. When a container lacks PID,
  the child path is SHORTER than the structural depth. A nested
  source whose container PID is missing can therefore have a path
  of `[leaf_pid]` (size=1) or `[]` (size=0) and be mis-classified
  as `complete-root` or `incomplete-root`.

Fix (per BLOCK-001 v3 minimum acceptable):
  A. SourceReference / EdgeRecord carries INDEPENDENT structural
     facts, populated at snapshot construction:
       - structural_depth: Integer ≥ 0 (root level = 0)
       - pid_path_complete: Boolean (true iff every container PID
                                       along the ancestry was
                                       captured)
     Plan §3.10 specifies that `walk_entity_world` tracks these in
     the same loop as `parent_pid_path`. Active edit context is
     included in the structural-depth bookkeeping.

  B. SourceToken gains two fields (Sym key) reflecting that
     structural identity:
       - nested:             Boolean
       - pid_path_complete:  Boolean
     Six locator profiles (one more than v2) are documented in
     §6.3. The new profile `incomplete-nested-partial` covers
     `[leaf_pid]` only with `nested == true` → non-locatable.

  C. Locator policy is explicit:
       complete-root     -> InstPath#leaf
       complete-nested   -> InstPath#root
       incomplete-root   -> find_entity_by_id(entity_id) fallback
       incomplete-nested -> non-locatable
       incomplete-nested-partial -> non-locatable (NEVER entityID)
       fully-missing     -> non-locatable
     The 5 mandatory test cases (1..5) are listed in §6.3 and
     §7 (test_issue_locator).

  D. SUCapability.find_entity_by_id is added (§4.2 modified file):
       safe wrapper; returns nil on nil input / missing capability
       / any error; never raises. Plan §6.3 references it
       explicitly; the call to `model.find_entity_by_id` is
       no longer a planned call to a nonexistent method.

  E. locatable derivation (§3.7) is precise:
       locatable = sources.any? { |t|
         (t[:nested] == false && t[:pid_path_complete] == true) ||
         (t[:nested] == true  && t[:pid_path_complete] == true) ||
         (t[:nested] == false && t[:pid_path_complete] == false &&
          !t[:entity_id].nil?)
       }

Recheck evidence (plan-level — no code yet):
  [x] SourceReference contract includes `structural_depth` and
      `pid_path_complete` (plan §3.10, §4.2).
  [x] SourceToken carries 4 fields (plan §3.2).
  [x] 6-profile locator table documented (plan §6.3).
  [x] 5 mandated test cases listed (plan §6.3, §7).
  [x] `SUCapability.find_entity_by_id` declared in modified-files
      (plan §4.2) and called explicitly in §6.3.
  [x] `extension/preflight_runner.rb` walk loop updated to track
      `parent_struct_depth` and `parent_pid_path_complete` (plan
      §3.10, §4.2).
  [x] `test_issue_locator` planned with 5 cases plus 2-source +
      erased (plan §7).
  [x] `test_issue_enricher` updated to assert structural identity
      preserved across traversal variations (plan §7).

============================================================
S6-VERIFY-BLOCK-001 — Owner Verification checklist reliability
============================================================

Location:    Review/OWNER_VERIFICATION_STAGE_6.txt (revised)

Root cause (per Codex Review 012):
  Six procedural bugs in the v1 checklist — fixture offsets that
  would silence legitimate detections, expected counts that don't
  match the analyzer output, nil-handling around `active_path`,
  fingerprint scope that misses nested mutation, unsupported
  UI::Menu introspection, and a comparison pair that cannot be
  true after intentional erase.

Fix (per VERIFY-001 minimum acceptable):
  A. Duplicate fixture corrected:
       - REMOVED the 0.001 offset (which exceeds the locked
         duplicate_tolerance = 0.0001 inch).
       - Use two distinct container occurrences whose edges are
         world-coincident instead. Expect ONE Issue row with TWO
         SourceTokens and TWO locate targets.

  B. Open endpoint expectation corrected:
       - One isolated edge has TWO degree-1 vertices.
       - Expect TWO open_endpoint issues, not one.

  C. Nil-safe active_path helper:
       - su_active_path_size_safe(model) returns 0 when
         model.active_path is nil.
       - All active_path.length calls in the checklist are
         replaced with this helper.

  D. Stale-source verification is now MANDATORY and keeps the
       dialog open:
       - Capture reference to the dangling edge BEFORE opening.
       - Open the dialog.
       - In Ruby Console while the dialog remains open, erase the
         dangling edge.
       - Capture fp_m_erase IMMEDIATELY after erase.
       - Click the now-stale Issue row.
       - Capture fp_m_click IMMEDIATELY after click.
       - Compare fp_m_click == fp_m_erase (NOT versus the original
         fp_before, which is unreachable after the destructive
         erase step).

  E. UI::Menu introspection REMOVED:
       - The unsupported `UI::Menu.submenus.items` query is gone.
       - Idempotency is proven by the FakeUI adapter test directly
         (`tests/test_loader.rb` reloads the loader and asserts the
         FakeUI Command registry stays at 1).
       - Real-host visual confirmation remains as a manual check.

  F. N (non-mutating end-to-end) is separated from M (intentional
       erase):
       - N uses the same fixtures as K without any destructive
         operation.
       - N compares PRE vs POST fingerprints byte-identical.
       - M is the destructive step; its comparison is only
         erase-vs-click (proving the Locate handler does not
         mutate).

  G. Recursive geometry fingerprint:
       - su_count_geometry_recursive(entities) walks every
         reachable Group and ComponentDefinition.
       - The fingerprint now covers mutations inside nested
         containers, not just root m.entities.

  H. fixture description corrected:
       - outer_g has 2 edges (not 1) in the checklist setup.

Recheck evidence (document-level):
  [x] Fixture 2 (shared_def + occ_a + occ_b) uses world-coincident
      edges, not 0.001 offset.
  [x] Fixture 4 (dangling) section in step K.7 expects 2 open
      endpoints, not 1.
  [x] su_count_geometry_recursive helper defined and used in
      su_fingerprint_v6.
  [x] su_active_path_size_safe helper defined and used everywhere
      active_path appears.
  [x] Step M is documented as mandatory; dialog stays open; erase
      via Ruby Console; fingerprints compared erase-vs-click.
  [x] Step J.3 replaced with the FakeUI adapter test plus a
      real-host visual confirmation.
  [x] Step N fingerprints compared PRE vs POST, with no
      destructive fixture in between.
  [x] outer_g fixture description has 2 edges.

============================================================
NIT fixes absorbed (Plan-level evidence)
============================================================

NIT 1 — Symbol/String key boundary:
  [x] Plan §3.1 + §3.2 explicitly state Ruby-side keys are Symbols
      internally; the JSON-String conversion happens at exactly
      one boundary: `extension/ui_bridge.rb#as_html_data`.
  [x] `tests/test_ui_bridge.rb` is the boundary test.

NIT 2 — AnalysisResult.freeze is shallow:
  [x] Plan §3.3 narrows the contract: "no public setters + frozen
      top-level". Nested fields are themselves immutable by design
      (IssueRegistry contract + Hash#freeze in display_data).
  [x] `tests/test_analysis_result.rb` asserts: no attr_writer,
      result.frozen? == true, diagnostics << {...} raises
      RuntimeError.

NIT 3 — Fixture description (outer_g has 2 edges):
  [x] Owner Verification fixture setup explicitly creates 2 edges
      inside inner_g. Plan §7 test_issue_locator does not depend
      on this fixture directly.

NIT 4 — test_no_overlay_lint scope:
  [x] Plan §6.1 acknowledges the lint proves absence of a finite
      forbidden-token set; real-host fingerprint (Owner
      Verification step N) is the ground truth for no model
      mutation.

NIT 5 — Toast JSON encoding consistency:
  [x] Plan §6.9 specifies the toast invocation passes a JSON
      String argument (not a JSON Array):
        msg = "source no longer available for: #{issue_id}"
        dialog.execute_script("window.SUAIP.toast(#{JSON.generate(msg)})")

============================================================
DEBT — unchanged from Round 012
============================================================

  Rich leaf-level visual highlighting inside a closed nested
  component remains deferred. V1 may select/zoom the root
  occurrence as specified in plan §6.3.

============================================================
NEXT STEPS (per Codex §NEXT REVIEW)
============================================================

1. Codex Round 013 plan recheck for S6-PLAN-BLOCK-001 v3 +
   S6-VERIFY-BLOCK-001 only.
2. After both BLOCKS close:
   - Codex verdict: PASS TO IMPLEMENT Gate A.
   - Agent implements Gate A (core 7 files + 7 tests + 1 lint +
     modifications to core/source_reference.rb).
   - Code-side review packet (BLOCK_RECHECK_REQUEST pass 1 for
     Gate A implementation) follows the Stage 2 pattern.
3. Gate A APPROVED → Gate B (host-side integration + html/css/js +
   Owner Verification file + 6 tests + lint extensions).
4. Owner verification on SU2020 (per Q002=A), then SU2017 (per R004,
   release Gate).
5. Stage 7 TASK 001 IMPLEMENTATION REPORT (PI_TASK_001 §22).

============================================================
AGENT ASKS CODEX
============================================================

Questions for Codex (in priority order):

1. Is the 6-profile locator table in plan §6.3 the correct
   enumeration? Specifically:
   - `incomplete-nested-partial` (nested=true, pid_path_complete=false,
     pid_path=[leaf_pid]) is non-locatable, NOT downgraded to
     `complete-root`. Confirm this matches the intended behavior.
   - `incomplete-nested` (nested=true, pid_path_complete=false,
     pid_path=[]) is non-locatable with NO entityID fallback. Confirm
     this is correct (entityID alone cannot pick the correct shared
     component occurrence).

2. Is `SUCapability.find_entity_by_id` the right place for the
   safe wrapper, or should it be a private helper in
   `extension/issue_locator.rb`?
   - Recommend: SUCapability, because the capability probe
     (`model.respond_to?(:find_entity_by_id)`) is a host-shape
     concern and lives there already (alongside `resolve_pid_path`,
     `serialize_pid_path`, etc.). Confirm.

3. Is the active-edit-context included in the structural-depth
   bookkeeping in plan §3.10 the right interpretation of
   S2-BLOCK-002 round 3 (real `model.active_path` is Array)?
   - Recommend: when active_path is non-empty, each entity in
     the active path contributes 1 to depth and toggles
     `pid_path_complete` (false if any contributes a nil PID).
     Confirm.

4. Are the 5 mandated test cases in §6.3 + §7 the right shape
   for `test_issue_locator` cases? Specifically:
   - Case 5 (incomplete-nested-partial) requires a builder that
     yields a nested source with only the leaf PID. Verify this
     is achievable with FakeSU via setting a "blocked" flag on
     intermediate containers.

Agent awaits Codex Round 013 verdict.

============================================================
END
============================================================
