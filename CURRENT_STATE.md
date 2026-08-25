# CURRENT STATE

## V1.4 Stage Review — OFFICIALLY CLOSED (2026-08-24, CodeX VERDICT: PASS, 0 BLOCKs)

Real SU2020 narrow test V14-9 re-run on the post-BLOCK-005 RBZ PASSED:
- Prepare normally produced 4 derived entities
- Ctrl+Z once -> derived entities = 0, SOURCE_OK=true
- Undo + Rebuild -> 4 derived entities back
- Mid-build failure injection correctly entered :failed
- Mid-build failure left NO partial derived entities and the source
  was unchanged
- One-shot failure patch auto-recovered
- Rebuild/Retry successfully recovered
- Final Discard -> derived entities = 0, source unchanged

CodeX V1.4 Stage Review VERDICT (2026-08-24):
  REVIEW MODE: V1.4 BLOCK RECHECK / STAGE CLOSE
  VERDICT: PASS
  BLOCKS: NONE

As a result:
  - V14-RUNTIME-BLOCK-004 closed
  - V14-RUNTIME-BLOCK-005 closed
  - V1.4 Stage Review formally PASSED
  - V1.5 Phase 1 Gate 1 / Gate 2 / Gate 3 all satisfied
  - V1.5 Phase 1 EXPLICITLY GREENLIT by CodeX + Owner

Final V1.4 state:
  Branch:    v1.4-derived-workspace (closeout)
  HEAD:      92be2cb  (fix SketchUp::Materials compatibility)
  Prev HEAD: 875333d  (V14-RUNTIME-BLOCK-004 safe host logging)
  Working tree: clean

Final V1.4 RBZ:
  Path:    D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz
  Size:    443,553 bytes
  Entries: 53
  SHA256:  4708569BEF45AF7C66945A78DA700CB61B73368BE09EC12D0F8CB0010E669705

Auto-test baseline at V1.4 close:
  Ruby:    656/656 PASS
  Node DOM: 148/148 PASS
  RBZ smoke: 8/8 PASS

## V1.5 Phase 1 — PENDING START (CodeX + Owner greenlit)

CodeX + Owner have explicitly greenlit V1.5 Phase 1 in the
2026-08-25 Owner dispatch:
- V1.5 plan: Review/V1_5_HIGH_CONFIDENCE_AUTO_REPAIR_IMPLEMENTATION_PLAN_2026-08-24.md
- V1.5 Pi Task: Prompt/PI_TASK_V1_5_HIGH_CONFIDENCE_AUTO_REPAIR_PHASE1_2026-08-24.txt

Vertical slice (the ONLY allowed slice):
  "In the DerivedGeometryWorkspace, auto-apply ONLY exact-duplicate
   and reversed-exact-duplicate edge occurrences, with full
   provenance, audit, and rollback. Do nothing else."

Per V1.5 plan §6 IMPLEMENTATION ORDER.

NEXT ACTION (this session):
  - Create V1.4 closeout commit on v1.4-derived-workspace.
  - Branch from HEAD into v1.5-high-confidence-auto-repair.
  - Implement V1.5 Phase 1 per the plan.
  - Stop at Owner Gate boundary.

## V14-RUNTIME-BLOCK-005 (2026-08-24) — material collection compatibility fixed

The first clean V14-9 retry surfaced the original host error after BLOCK-004
logging repair: `Sketchup::Materials` lacks `empty?`. `SourceFingerprint`
now normalizes enumerable material collections before Array operations.

Evidence: SourceFingerprint 7/7; full Ruby 656/656; Node DOM 148/148; RBZ
smoke 8/8. New RBZ is 443,553 bytes, 53 entries, SHA256
`4708569bef45af7c66945a78da700cb61b73368be09ec12d0f8cb0010e669705`.
Review packet: `Review/V14_RUNTIME_BLOCK_005_FIX_PACKET_2026-08-24.md`.

## V14-RUNTIME-BLOCK-004 (2026-08-24) — implementation + automated verification complete

Pi's real-SketchUp-2020 repro exposed a second failure in the error path;
`$stderr.puts` / `$stdout.puts` called private `Sketchup::Console#puts`,
masking the original Prepare exception. The narrow fix is committed at
`5f23917`: defensive `_safe_log` via bare `warn`,
original-error toast preservation, unconditional `push_data`, and the same
safe logging rule in `main.rb` and `on_locate`.

Evidence:

- V14-RUNTIME-BLOCK-004: 9/9 pass
- Full Ruby: 655/655 pass, 0 fail, 0 error
- Node DOM: 148/148 pass
- RBZ smoke: 8/8 pass
- RBZ rebuilt: `dist/SU-AI-Plugin.rbz`, 442,832 bytes, 53 entries
- SHA256: `c8288a2c2b499291fc9a03a75b90f96f4184a057df41a833a5d410f625418db0`
- Review packet: `Review/V14_RUNTIME_BLOCK_004_FIX_PACKET_2026-08-24.md`

Next gate: CodeX narrow recheck, then install this RBZ and rerun only the
real SU2020 V14-9 narrow flow. V1.5 remains gated; do not publish/release.

Last updated: 2026-08-25 (V1.4 Stage Review OFFICIALLY CLOSED —
CodeX VERDICT: PASS, 0 BLOCKs; V1.5 Phase 1 GREENLIT).
Branch `v1.4-derived-workspace` (V1.4 closeout commit pending this session).
  - Production candidate HEAD (rbz built from): 92be2cb
  - Working tree: clean

Full suite **656/656 Ruby + 148/148 Node.js DOM assertions
+ 8/8 RBZ smoke tests** PASS, 0 fail, 0 error.
dist/SU-AI-Plugin.rbz rebuilt (439,067 bytes, 53 entries,
SHA256 `af3e8621ab37582ae711be337fd18ac846e4b564e2d84b4dbadb315e3550cf97`,
committed with NIT fix + final production path fixes).

NOTE: this 439,067-byte RBZ was superseded by the BLOCK-004 +
BLOCK-005 narrow fixes; the final V1.4 RBZ is the
443,553-byte build at HEAD 92be2cb. The earlier build is
preserved here only for historical reference.

Owner Gate 2 V1.4 SU2020: V14-1..V14-10 all PASS on the post-BLOCK-003
rbz. Evidence at
`Prompt/OWNER_REPORT_V1_4_DERIVED_WORKSPACE_2026-08-24.txt`.

CodeX V1.4 Stage Review (2026-08-24) verdict:
VERDICT: BLOCKED (BLOCKS: V14-STAGE-BLOCK-001, V14-STAGE-BLOCK-002).
Both BLOCKs closed in this commit (narrow recheck scope; full
Stage Review NOT requested). Stage Review packet base/head
recorded separately.

Stage Review packet dispatched at
`Review/CODEX_STAGE_REVIEW_REQUEST_V1_4_DERIVED_WORKSPACE_2026-08-24.md`.

V1.5 Phase 1 plan + Pi Task prepared but NOT started (gated on
CodeX V1.4 Stage Review PASS):
  - `Review/V1_5_HIGH_CONFIDENCE_AUTO_REPAIR_IMPLEMENTATION_PLAN_2026-08-24.md`
  - `Prompt/PI_TASK_V1_5_HIGH_CONFIDENCE_AUTO_REPAIR_PHASE1_2026-08-24.txt`

## V14-STAGE-BLOCK-001 + V14-STAGE-BLOCK-002
                          -- recheck fix COMPLETE 2026-08-24

CodeX V1.4 Stage Review BLOCK RECHECK verdict (2026-08-24):
VERDICT: BLOCKED
  BLOCKS:
    V14-STAGE-BLOCK-001 still not closed: the production path
      reads AnalyzersRunner-style fields ('transform',
      'pid_path', 'pid_path_complete', 'raw_with_nil') but
      the previous fix expected the WRONG keys
      ('active_edit_transform', 'active_edit_path', etc).
      The dialog_runner's _host_for(ar) returned nil, so
      the production code could not read the controller's
      model. The new tests called the normalize helper
      directly and missed the real production flow.
    V14-STAGE-BLOCK-002 still not closed: when _build_derived_entities
      returns a :failed workspace (no exception), prepare
      still committed the operation (NOT aborted), so
      surviving entities were kept. The :failed-state
      refusal guard made the UI's Rebuild path dead
      (Discard disabled, Rebuild calls prepare which is
      refused). _discard_if_present's rescue branch
      cleared @current_workspace = nil, losing the
      handle_registry.
  NITS:
    - Operation changed from per-edge to whole-Prepare, so
      V14-9's real Undo behavior changes. Need to retest
      on real SU2020: Prepare success, mid-build failure
      no leftover / leftover cleanable, Discard/Retry
      recovery, Ctrl+Z reverts whole Prepare, source
      unchanged. Cannot reuse old V14-9 evidence.

Fix -- V14-STAGE-BLOCK-001 (production path recheck):

  extension/su_ai_plugin/dialog_runner.rb:
    - _source_snapshot_for(controller) now reads
      controller.model and passes it through to
      _source_snapshot_from_real_geometry(ar, geom, model:).
    - _source_snapshot_from_real_geometry(ar, geom, model: model)
      uses the controller's model for both the SourceFingerprint
      (host: model) and the transform context.
    - _resolve_transform_context(active_facts:, model:)
      handles BOTH the AnalyzersRunner production shape
      (String keys 'transform' / 'pid_path' /
      'pid_path_complete' / 'raw_with_nil' /
      'structural_depth') AND the pre-coerced shape
      (already-converted 16-float Arrays). The 'transform'
      value is a LIVE Sketchup::Geom::Transformation
      object on real SU -- we convert it to a 16-float
      Array via .to_a (via _coerce_to_16floats which now
      handles objects that respond to .to_a). The inverse
      is extracted via t.inverse.to_a. We keep t_raw (the
      original Object) separately so the inverse extraction
      works on the live object (not the already-converted
      Array). When active_facts has no 'transform' but the
      model has edit_transform, we fall back to reading
      model.edit_transform (with the same .to_a path) and
      its inverse.
    - SourceSnapshot MUST contain ONLY pure data -- no
      live SketchUp objects. The deep-freeze + Float-only
      assertions in the new production-path tests pin
      this invariant.
    - Removed the now-unused _host_edit_transform_16floats
      helper (its logic was inlined into
      _resolve_transform_context with the live-object
      reference preserved).

Fix -- V14-STAGE-BLOCK-002 (recovery + abort recheck):

  core/working_mode_runner.rb:
    - prepare: when prior workspace is :failed, try to
      discard it FIRST (this is the UI's Rebuild recovery
      path). If discard succeeds (transitions to
      :discarded), proceed with the new build. If discard
      ALSO fails (transitions to :failed again), refuse
      + preserve the prior failed workspace (no overwrite,
      handle_registry intact, last_error explains). The
      user's escape hatch is the prior workspace's explicit
      Discard / Rebuild call from the UI.
    - prepare: when _build_derived_entities returns a
      :failed workspace (mid-build failure), ABORT the
      SU operation (not commit). The previous bug committed
      on :failed, leaving surviving entities on the model.
      The abort rolls back every entity created under the
      operation (atomic cleanup). The :failed workspace
      still carries the partial handle_registry for the
      user's precise cleanup.
    - _discard_if_present: NEVER clear @current_workspace
      on exception. The prior code set it to nil, losing
      the handle_registry. The fix preserves the workspace
      AS-IS (workspace.discard's internal rescue handles
      the disposal failures; this outer rescue is paranoid).

  tests/_fake_ui.rb:
    - FakeEntities.invalidate_all! now clears @groups (in
      addition to erasing each group). The previous
      implementation only marked groups as invalid (via
      erase!) but did NOT clear @groups, so the `groups`
      reader still returned the rolled-back groups. The
      abort's "roll back every entity" contract is now
      properly enforced in the FakeModel.

New production-path tests (this commit):

  tests/test_v14_stage_block_regression.rb (4 new tests):
    BLOCK-001:
      9. dialog_runner maps production AnalyzersRunner
         facts to pure data transform_context -- the
         'transform' live object is converted to a 16-float
         Array via .to_a; pid_path / pid_path_complete /
         raw_with_nil are preserved; the result is deeply
         frozen.
      10. full production path -- controller + analysis
          result + model -> real transform_context in
          SourceSnapshot. The REAL production path
          (controller.model -> _source_snapshot_for ->
          _source_snapshot_from_real_geometry ->
          from_geometry_snapshot) is exercised end-to-end.
      11. production path falls back to model.edit_transform
          when facts has no transform -- the model's
          edit_transform is read, and BOTH the forward and
          inverse 16-float arrays are extracted.
    BLOCK-002:
      12. production Prepare mid-build failure ABORTS the
          SU operation (no partial entities) -- verifies
          the operation_log shows :start then :abort (NOT
          :commit), model.entities.groups is empty after
          abort, and the :failed workspace carries the
          partial inventory for precise cleanup.
      13. _discard_if_present NEVER clears workspace on
          exception -- the prior failed workspace's
          handle_registry is preserved even when the
          discard path raises.

Updated existing tests to the new contracts:

  tests/test_v14_dangerous_failure_modes.rb:
    - PHASE-3-MATRIX "failed state refuses new Prepare
      until Discard completes" replaced with TWO tests:
      1. "failed state auto-cleans-up" -- the runner tries
         to discard the prior failed workspace first; when
         the discard succeeds (transient-failure adapter),
         the new build proceeds to :ready. This is the
         UI's Rebuild button path -- the user MUST NOT be
         stuck in the failed state.
      2. "failed state REFUSES new Prepare when cleanup
         fails" -- an always-failing adapter makes both
         the Prepare AND the auto-cleanup fail; the runner
         refuses the new build and preserves the prior
         failed workspace (no overwrite, handle_registry
         intact).

  tests/test_v14_stage_block_regression.rb:
    - "V14-STAGE-BLOCK-002: prepare refuses to overwrite a
      :failed workspace" replaced with TWO tests:
      1. "prepare auto-cleans-up the prior failed workspace
         (recovery path)" -- the runner discards the prior
         failed workspace and proceeds to :ready.
      2. "prepare REFUSES to overwrite when cleanup itself
         fails (handle_registry preservation)" -- the
         runner preserves the prior failed workspace when
         the auto-cleanup ALSO fails.

Verification:
  - Targeted: tests/run_all.rb "V14-STAGE-BLOCK-001" ->
    8 tests, 8 pass, 0 fail, 0 error.
    tests/run_all.rb "V14-STAGE-BLOCK-002" -> 9 tests,
    9 pass, 0 fail, 0 error.
  - Full Ruby: 644 tests, 644 pass, 0 fail, 0 error.
  - Node DOM: 148/148 PASS.
  - git diff --check: clean.

RBZ rebuild:
  Path:      D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz
  Size:      438,607 bytes (was 432,162)
  SHA256:    a698d837bd02f08ecef80ad597305e5b332b749f736da32f6c5f34499ca6a15a
  Entries:   53
  Modified:  2026-08-24 15:20
  Verified:  Extracted su_ai_plugin/dialog_runner.rb
             from the archive: _resolve_transform_context
             present; production pid_path / pid_path_complete
             mapping present; controller.model passed;
             _coerce_to_16floats handles live objects.
             Extracted su_ai_plugin/core/working_mode_runner.rb:
             prepare ABORTS on :failed (commit: false path);
             _discard_if_present NEVER clears workspace on
             exception.

What remains:
  - CodeX V14-STAGE-BLOCK-001 + V14-STAGE-BLOCK-002 narrow
    recheck #2 verdict (the production-path fixes).
  - After CodeX PASS, a SU2020 narrow re-test of:
      * Prepare success (no leftover)
      * Mid-build failure no leftover (or leftover is
        precisely cleanable)
      * Discard / Retry recovery path
      * Ctrl+Z reverts the whole Prepare (per the V14-9
        contract change: operation is now whole-Prepare
        not per-edge)
      * Source unchanged
    Per CodeX: "不能沿用旧 V14-9 证据直接放行".
  - Owner Gate 2 V1.4 SU2020 evidence (commit f9bc321)
    remains valid for the production-code HEAD 707273a
    for the prior-passing subset (V14-1..V14-8, V14-10); the
    new V14-9 narrow re-test is required because the
    operation semantics changed.

NEXT ACTION:
  - DO NOT push, publish, install, or release.
  - DO NOT enter V1.5 / V1.6 / V1.7 / V1.8 / V1.9.
  - Wait for CodeX V14-STAGE-BLOCK-001 + V14-STAGE-BLOCK-002
    recheck #2 verdict.

## V14-STAGE-BLOCK-001 + V14-STAGE-BLOCK-002
                            -- fix COMPLETE 2026-08-24

CodeX V1.4 Stage Review verdict (2026-08-24):
VERDICT: BLOCKED
  BLOCKS:
    V14-STAGE-BLOCK-001: real active-edit transform is
                          computed in dialog_runner but
                          discarded by
                          SourceSnapshot.from_geometry_snapshot
                          (which unconditionally wrote identity).
                          Violates Gate A (SourceSnapshot must
                          preserve world/local transform context
                          for rebuild / V1.5+ repairs /
                          provenance).
    V14-STAGE-BLOCK-002: operation/recovery model does not
                          match real SketchUp. The production
                          code wrapped per-entity operations
                          inside the runner's outer operation
                          (real SU does NOT nest; start_operation
                          implicitly ends the prior). FakeModel
                          used a counter (masking the real SU
                          behavior). Also: _discard_if_present
                          returning :failed was overwritten by
                          the next prepare() (losing handle
                          registry).
  NITS:
    - Stage Review packet says HEAD = 707273a but
      evidence-packet HEAD = f9bc321. Record RBZ /
      production-candidate HEAD separately from
      review-packet HEAD.
    - CURRENT_STATE.md had stale "do not submit Stage
      Review" todo. Clean up.

Fix -- V14-STAGE-BLOCK-001 (production add_group /
                                transform_context):
  - `core/source_snapshot.rb`:
    - `SourceSnapshot.from_geometry_snapshot` now accepts a
      `transform_context:` keyword (the dialog_runner MUST
      pass the real transform context). When nil, the factory
      writes the legacy identity marker Hash (V1.0-V1.3 plumbing
      compatibility).
    - New class method `SourceSnapshot.normalize_transform_context`
      validates the shape (16 finite Floats for
      active_edit_transform / active_edit_inverse; Boolean /
      nil pid_path_complete; Array of Integer / String /
      nil slots for active_edit_path; non-'identity' String
      active_edit_seed when a real transform is supplied).
      Returns a deeply-frozen Hash ready to embed in a
      SourceSnapshot. Malformed shapes return nil
      (defensive -- a raise would surface a BLOCK in the
      dialog callback path).
  - `extension/su_ai_plugin/dialog_runner.rb`:
    - New private method `_resolve_transform_context`
      reads the host model's `edit_transform.to_a` (16
      finite Floats) and the model's active path facts,
      and produces the frozen transform_context Hash the
      factory expects. When the host has no active edit
      (or the AnalysisResult did not carry
      active_edit_facts), returns nil (factory writes the
      identity marker).
    - `_source_snapshot_from_real_geometry` now passes
      `transform_context:` to `from_geometry_snapshot`
      (NOT silently identity).

Fix -- V14-STAGE-BLOCK-002 (sequential operations +
                                failed-workspace preservation):
  - `core/derived_geometry_workspace.rb`:
    - `build_entity` no longer opens its own SU operation
      (the runner's outer operation in prepare() is the
      single operation owner). The rescue clause no
      longer calls `end_operation(commit: false)` -- the
      runner owns that decision. It still disposes any
      partial host handle from the SAME call (precise
      per-entity rollback).
    - `discard` keeps its own operation wrapper (the
      single owner for cleanup). Unchanged from prior.
  - `core/working_mode_runner.rb`:
    - `prepare` reads the partial inventory + handle_registry
      from the LAST build_entity result (the :failed
      workspace returned by build_entity when a mid-build
      failure happens), NOT from the original empty
      `:building` workspace. This preserves the precise
      handle_registry tracking for cleanup.
    - NEW: at the top of `prepare`, when the prior
      `@current_workspace.state == :failed`, refuse the
      new Prepare -- keep the failed workspace intact (no
      overwrite), set last_error explaining the refusal, and
      return a snapshot with state=:failed. The user MUST
      explicitly trigger a Discard (or Rebuild) that
      completes the cleanup before a fresh Prepare is
      allowed. Prevents losing the failed workspace's
      private handle_registry and leaking partial derived
      entities on hosts where abort failed to roll back.
  - `tests/_fake_ui.rb`:
    - FakeModel now uses SEQUENTIAL operation semantics
      (single-open boolean), NOT the prior nestable counter
      stack. Calling `start_operation` while an operation
      is open auto-closes the prior one (logged as
      `:implicit_close`); calling `commit_operation` /
      `abort_operation` when no operation is open raises.
      This mirrors real SketchUp's behavior, per the
      SketchUp Ruby API docs.

NITS addressed:
  - Stage Review packet base/head now recorded
    separately (`RBZ / production candidate HEAD =
    707273a`, `Review packet HEAD = f9bc321`).
  - CURRENT_STATE.md no longer carries the stale "do not
    submit Stage Review" todo.

Verification:
  - Targeted: `tests/run_all.rb "V14-STAGE-BLOCK"` -> 9
    new tests, 9 pass, 0 fail, 0 error.
    - V14-STAGE-BLOCK-001 (5 tests): transform_context
      passes through SourceSnapshot (no silent identity
      fallback); nil preserves legacy identity marker;
      malformed transform_context rejected; dialog_runner
      reads model.edit_transform via .to_a; falls back
      to identity when host has no edit_transform.
    - V14-STAGE-BLOCK-002 (4 tests): FakeModel sequential
      operations; production Prepare wraps build in EXACTLY
      ONE SU operation (no per-entity nesting); prepare
      refuses to overwrite a :failed workspace (handle
      registry preservation); build failure mid-build
      preserves partial handle registry in :failed
      workspace; second Discard after transient dispose
      failure succeeds.
  - Existing tests updated:
    - `test_v14_production_call_chain.rb`: assertion
      changed from `operation_log.length >= 2` to
      `== 2` (sequential-operation contract: exactly one
      start + one commit, NOT 2*N entries); `open_operations`
      predicate replaced with `operation_open?` predicate.
    - `test_v14_targeted_regression.rb`: V14-TARGETED-4
      updated to reflect the sequential-operation semantics
      (subsequent Discard's start_operation logs :implicit_close
      + :start = 2 more entries on top of the existing 1
      = 3 total).
    - `test_v14_dangerous_failure_modes.rb`: PHASE-3-MATRIX
      "failed state is recoverable" replaced with "failed
      state refuses new Prepare until Discard completes"
      (V14-STAGE-BLOCK-002 new contract).
  - Full Ruby: 637 tests, 637 pass, 0 fail, 0 error.
  - Node DOM: 148/148 PASS.
  - RBZ smoke (8): all pass.
  - `git diff --check`: clean.

What remains:
  - CodeX V14-STAGE-BLOCK-001 + V14-STAGE-BLOCK-002 narrow
    recheck (NOT the full V1.4 Stage Review; the Stage
    Review packet was already dispatched in the prior
    commit).
  - Once CodeX PASSES the narrow recheck, the V1.4
    Stage Review verdict is COMPLETE. No further review
    dispatch is required -- the BLOCK recheck IS the
    Stage Review.
  - Owner Gate 2 V1.4 SU2020 already PASSED (prior
    commit); no re-run needed.
  - V1.5 Phase 1 still gated on the V1.4 Stage Review
    PASS + a fresh Pi Task dispatch.
V1.0 candidate still FROZEN at tag `v1.0-candidate-2026-08-19`
(commit `56ea611`). V1.2 + V1.3 stages remain CLOSED on
SketchUp 2020 per CodeX 029.

## V14-RUNTIME-BLOCK-003 (real SU2020 Owner repro 2026-08-22)
                        -- fix COMPLETE 2026-08-24

- **Symptom**: Owner real-SU2020 repro at the V14 Gate 2
  click on Prepare. Production adapter's
  `SketchupDerivedWorkspaceAdapter#create_top_level_group`
  called `entities.add_group(NAME_PREFIX + name.to_s)`.
  Real SketchUp 2020 `Sketchup::Entities#add_group` takes
  NO arguments (it accepts an optional pre-population
  `Sketchup::Entity`, NOT a String group name). The call
  raised on the host:
  ```
  TypeError: wrong argument type (expected Sketchup::Entity)
  ```
  and the dialog entered the `failed` state. CI-side, the
  full test suite produced 9 FAILs (DANGER 1, 2, 5a,
  BLOCK-R3-2 closure, plus 5 V14 production call chain
  tests) when run in alphabetical file order, while the
  same tests PASS in isolated runs -- classic test-state
  pollution.

- **Root cause (production adapter)**:
  `extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb`
  used the wrong SketchUp host contract:
  `g = entities.add_group(NAME_PREFIX + name.to_s)`. The
  correct contract is:
  ```
  g = entities.add_group         # zero args -> fresh Group
  g.name = NAME_PREFIX + name.to_s  # separate property write
  g
  ```

- **Root cause (test pollution)**: `tests/test_rbz_smoke.rb`
  extracts the existing `dist/SU-AI-Plugin.rbz` into a TEMP
  directory and `load`s the entry-point + main.rb through
  the boot! require_relative chain. The chain reopens the
  production classes (including the production adapter) with
  the EXTRACTED source from the .rbz. The .rbz was built
  BEFORE BLOCK-003, so the extracted adapter had the BUG
  (`add_group(NAME_PREFIX + name)`). After the smoke test,
  `SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter#create_top_level_group`
  remained bound to the BUGGY extracted source, so
  subsequent tests (DANGER 1/2/5a, BLOCK-R3-2, the V14
  production call chain) ran the BUGGY production path and
  hit the FakeEntities TypeError guard we had tightened
  in BLOCK-003 to surface exactly this regression.

- **Fix -- production adapter**:
  `extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb`
  - `create_top_level_group`: `entities.add_group` (no
    args) then `g.name = NAME_PREFIX + name.to_s`.
  - Updated the doc comment to spell out the real SketchUp
    host contract (no string group-name argument; the
    recognizable name is assigned via the property writer).

- **Fix -- host-API contract tests**:
  `tests/_fake_ui.rb` FakeUI::FakeModel::FakeEntities
  - `add_group(*args)`: takes `*args` and raises `TypeError`
    if `args` is non-empty, mirroring the real
    `Sketchup::Entities#add_group` signature. The previous
    version accepted `add_group(name)` as a positional
    argument, which masked the BLOCK-003 bug.
  `tests/_fake_ui.rb` FakeUI::FakeModel::FakeGroup
  - `name` / `name=` re-implemented explicitly to support
    the production adapter's `g.name = ...` assignment.
  `tests/test_v14_dangerous_failure_modes.rb`
  - `v14_install_fake_su` ensures the test fake model
    responds to BOTH `:entities` (the production
    destination) AND `:active_entities` (the
    `sketchup_available?` capability check).

- **Fix -- test isolation in RBZ smoke**:
  `tests/test_rbz_smoke.rb` adds a defensive restore step
  that `load`s the in-tree production source files (with
  absolute paths) AFTER the smoke test, so the production
  classes' method bindings are restored to the in-tree
  source regardless of which .rbz build was extracted.
  Without this, any .rbz that lags behind a production-side
  fix would pollute subsequent tests via class re-opening.
  The list of files to restore is the complete boot!
  require_relative chain + dialog_runner's transitive
  requires (loader.rb, dialog_runner.rb, analyzers_runner,
  ui_bridge, dialog_controller, issue_locator, all the
  core/* pure-Ruby files, the compatibility/* files, and
  the V1.4 stage 3/4 files: derived_workspace_adapter,
  derived_geometry_workspace, working_mode_runner,
  source_snapshot, su_derived_workspace_adapter).

- **Verification**:
  - Targeted: `tests/run_all.rb "DANGER"` -> 15/15 PASS;
    `tests/run_all.rb "V14 production call chain"` -> 7/7
    PASS; `tests/run_all.rb "V14-RUNTIME-BLOCK-002"` ->
    6/6 PASS.
  - Full Ruby: 622/622 PASS, 0 fail, 0 error, exit 0.
  - Node DOM: 148/148 PASS.
  - `git diff --check`: clean.
  - RBZ rebuilt: `dist/SU-AI-Plugin.rbz` 416996 bytes,
    53 entries,
    SHA256 `0fc5ee407c52a4c70ca469c6e9549f032dcd21cb4549bfade56aed49b1b7d255`
    (distinct from the prior 416781-byte build).
  - The BLOCK-003 fix IS present in the .rbz
    (`su_ai_plugin/compatibility/su_derived_workspace_adapter.rb`
    inside the archive has `entities.add_group` then
    `g.name = ...`, not `entities.add_group(NAME_PREFIX + ...)`).

- **What remains**:
  - **CodeX narrow-scope recheck** of the BLOCK-003 fix.
    DO NOT submit the full V1.4 Stage Review yet -- the
    BLOCK-003 fix is a focused, narrow patch (production
    add_group contract + FakeUI host-API contract tests +
    RBZ smoke test isolation). CodeX should re-check only
    these changes.
  - **Owner Gate 2 V1.4 SU2020** on the rebuilt rbz: Owner
    must RESTART SU2020 ENTIRELY and reinstall the rbz
    before running the 10-step V14 Gate 2 checklist
    (`Review/OWNER_VERIFICATION_V1_4_DERIVED_WORKSPACE_2026-08-21.txt`).
    Agent will NOT pre-fill PASS.
  - **V1.4 Stage Review** packet: remains STALE; do not
    submit. After CodeX BLOCK-003 recheck PASS + Owner
    Gate 2 PASS, Agent will assemble the consolidated
    V1.4 stage review packet per directive 030.

- **Lessons**:
  - Test stubs that accept "anything goes" argument shapes
    (`def add_group(name)` instead of `def add_group(*args)`
    with strict validation) MASK production bugs. The
    fake host MUST mirror the real host signature so the
    test suite catches regressions, not paper over them.
  - Smoke tests that `load` extracted package files in the
    SAME Ruby process as the main test suite can pollute
    global classes via class re-opening semantics. Either
    run the smoke test in a subprocess (preferred for
    future redesign) or restore the in-tree files at the
    END of the smoke test. We chose the latter as the
    minimum-invasive fix.
  - Build artifacts MUST be regenerated whenever a
    production-side fix touches a file that ships in the
    .rbz; otherwise the smoke test's extracted copy lags
    behind the in-tree source.

## V1.4 stage 4 (IMPLEMENTATION COMPLETE on
            `v1.4-derived-workspace` branch, head = `431af5d`)

- **Implementation status**: ALL 4 V1.4 stages implemented
  on `v1.4-derived-workspace` (cut from V1.3 close at
  `550eb74`).
  - Commit `ddefe2f`: Stage 1 -- SourceSnapshot /
    fingerprint / execution-config contract.
  - Commit `de233be`: Stage 2 -- RepairPlan / RepairAction /
    lifecycle foundation.
  - Commit `d2a8328`: Stage 3 -- DerivedGeometryWorkspace +
    adapter + fingerprint.
  - Commit `431af5d`: Stage 4 -- Working Mode runner + UI
    plumbing + tests (this commit).
- **V1.4 directive**: `Prompt/CODEX_PREBUILD_030_2026-08-20_V1_4_START.txt`
  (PASS TO IMPLEMENT V1.4, 0 BLOCKs).
- **Locked V1.4 contracts preserved**:
  - Directive gates A (deep immutability / versioned /
    fingerprintable SourceSnapshot) and B (independent
    derived editable geometry, no shared-definition
    aliasing with source) -- both verified by Stage 3 + 4
    tests.
  - Source CAD immutability -- verified by the 5 SourceFingerprint
    identity risk tests (1a..1e) + the
    dialog_runner source-integrity invariant test
    (fingerprint identical before/after prepare / discard /
    rebuild).
  - JSON-safe payload (String keys, primitive values,
    Hashes/Arrays only) -- verified by 2 WorkingModeRunner
    tests + the UIBridge.to_json round-trip test.
  - RepairPlan lifecycle invariant (failed plans/results
    never READY) -- Stage 2 tests.
  - textContent-only render contract -- Stage 4
    html_render test.
  - Bracket-lookup for action callbacks (no eval) -- Stage 4
    html_render test.
  - No new role / state color selectors -- Stage 4
    style.css test (allows only var(--*) neutral palette).
- **Working Mode UI section** (per directive 030 Stage 4):
  - `<details id="working-mode-section">` AFTER V1.3
    face-inventory-section. Default-closed.
  - 5 states: 'none' (idle) / 'building' (in-progress) /
    'ready' (workspace active) / 'discarded' (user
    discarded) / 'failed' (build/cleanup raised). State is
    rendered as a data-state attribute on each row.
  - Action buttons (Prepare / Discard / Rebuild) wire to
    window.SUAIP callbacks exposed by DialogRunner as
    BLOCKs. Enable/disable per state. Prepare button is
    ALWAYS shown in 'none' / 'discarded' / 'failed';
    Discard only in 'ready'; Rebuild in 'ready' /
    'discarded' / 'failed'.
  - All user-facing text via textContent (no innerHTML).
    Bracket lookup for callbacks (no eval). textContent +
    setAttribute only.
- **Production adapter**:
  - `compatibility/su_derived_workspace_adapter.rb`:
    `SketchupDerivedWorkspaceAdapter` is the production
    SketchUp adapter. `NAME_PREFIX = 'SU-AI-Derived-'`
    makes derived entities visually identifiable. Calls
    `Sketchup::Entities#add_group` with NO arguments
    (a brand-new ComponentDefinition per call -- per
    directive gate B, independent derived ownership, no
    shared-definition aliasing with source) and assigns
    the recognizable name via `g.name = NAME_PREFIX +
    name.to_s`. Capability detection via defined?(Sketchup).

    > **CORRECTION (V14-RUNTIME-BLOCK-003, 2026-08-22,
    > fix 2026-08-24)**: the previous description in
    > this section referred to
    > `Sketchup::Entities#add_group(NAME_PREFIX + name)`
    > as the correct production contract. That is the
    > BUG. Real SketchUp 2020 `add_group` takes NO
    > arguments (or an optional pre-population
    > `Sketchup::Entity`); passing a String group name
    > raises TypeError on the host. The BLOCK-003 fix
    > changed the production adapter to
    > `g = entities.add_group` (no args) followed by
    > `g.name = NAME_PREFIX + name.to_s`. See the
    > V14-RUNTIME-BLOCK-003 section at the top of this
    > file for the full root-cause analysis.
- **Runner bug fix within this commit**:
  - The previous version of `core/working_mode_runner.rb`
    discard() set `@current_workspace = nil` after the
    workspace discard, which made `snapshot()` return 'none'
    instead of 'discarded'. The runner now keeps the
    discarded workspace reference so `snapshot()` reports
    the correct lifecycle state. The next `prepare()`
    overwrites `@current_workspace` with a fresh :building
    workspace, so prior discarded workspaces are never
    re-used. Verified by 17/17 WorkingModeRunner tests +
    the source-fingerprint-integrity invariant test in
    test_dialog_runner.rb.
- **Test evidence at this commit**:
  - Ruby: 579/579 PASS, 0 fail, 0 error
    (was 547/547 before V1.4 Stage 4; +32 from new tests).
  - Node.js DOM: 132/132 assertions PASS, 0 fail
    (was 115/115 before V1.4 Stage 4; +17 V14 assertions).
  - `git diff --check` clean on all changed files.
  - `dist/SU-AI-Plugin.rbz` rebuilt to include the new
    working_mode_runner.rb + su_derived_workspace_adapter.rb
    + dialog_runner.rb / ui_bridge.rb / html/ changes.

## V1.4 stage 3 (IMPLEMENTATION COMPLETE on
            `v1.4-derived-workspace` branch, head = `d2a8328`)

- **CodeX verdict (pre-build)**: PASS TO IMPLEMENT V1.4
  per directive 030 (no CodeX stage-review yet, awaiting
  V1.4 exit gate).
- **Implementation status**: Stage 3 COMPLETE.
  - DerivedGeometryWorkspace + adapter + fingerprint
    (lifecycle: :building / :ready / :discarded / :failed;
    nested derived entities via parent_derived_id; deep
    immutability; rebuild preserves fingerprint).
  - The parent_derived_id validation raises ArgumentError
    (NOT silently converted to :failed) when the parent
    is not found in the workspace -- per directive
    "父子 derived ID 引用严格校验". This test was
    previously failing and is now passing (commit d2a8328).
- **Test evidence at this commit**:
  - Ruby: 547/547 PASS (the 27 new Stage 3 tests
    + all previous).
  - `git diff --check` clean.

## V1.4 stage 2 (IMPLEMENTATION COMPLETE on
            `v1.4-derived-workspace` branch, head = `de233be`)

- RepairPlan / RepairAction / ValidationResult pure-data
  layer (lifecycle: :proposed / :validated / :applied /
  :skipped / :rejected / :failed; failed plans NEVER
  :ready; no fake AI confidence).
- 22 new tests covering deep immutability, lifecycle
  transitions, JSON-safe round-trip, and the
  cross-stage :failed invariant.

## V1.4 stage 1 (IMPLEMENTATION COMPLETE on
            `v1.4-derived-workspace` branch, head = `ddefe2f`)

- SourceSnapshot / SourceFingerprint / ExecutionConfigSnapshot
  pure-data layer. Schema version, execution-config capture
  (profile + rule-set + tolerance values + session
  overrides), deep immutability (top-level + nested Arrays /
  Hashes frozen), stable to_digest (SHA256 hex).
- 25 new tests covering deep immutability, schema version
  pin, identity quality preserved on selection scope, and
  source fingerprint stability (risk test 8).

## V1.2 + V1.3 stages (CLOSED on SU2020 per CodeX 029, 2026-08-20)
(Historical context -- superseded by the V1.2 + V1.3 closed
sections at the top of the V1.0 narrative.)

## V1.2 stage (CLOSED on SU2020 per CodeX 029, 2026-08-20)

- **CodeX verdict (end-of-stage)**: PASS WITH NITS,
  0 BLOCKs per CodeX 029 (combined V1.2 + V1.3 packet).
  V1.2 stage may be marked CLOSED on the verified
  SU2020 host.
- **Owner evidence**:
  `Prompt/OWNER_REPORT_V1_2_ISSUES_BY_LAYER_2026-08-20.txt`
  (Owner Gate 2 V1.2 PASS on real SU2020; V12-1..V12-7).
- **CodeX packet**:
  `Review/CODEX_END_OF_STAGE_REVIEW_REQUEST_V1_2_AND_V1_3_2026-08-20.md`
  (combined V1.2 + V1.3 end-of-stage review request).
- **CodeX review file**:
  `Prompt/CODEX_REVIEW_029_2026-08-20_V1_2_V1_3_END_OF_STAGE.txt`
  (PASS WITH NITS, 0 BLOCKs).
- **Implementation status**: COMPLETE on
  `v1.2-issues-by-layer` branch.
  - Commit `035e306`: data layer (AnalysisResult
    `layer_issue_groups`, AnalyzersRunner wiring,
    LayerIssueGrouper Hash-shape input compat).
  - Commit `ea81aaa`: UIBridge `layerIssueGroups`
    top-level key.
  - Commit `03c2dd9`: HTML/JS/CSS render
    (`<details id="layer-issues-section">`,
    `renderLayerIssues()` + `renderLayerIssueBucket()`,
    `.layer-issue-bucket` neutral styles).
- **PRESERVATION** (per CodeX guidance 027):
  - Tag `v1.2-issues-by-layer-candidate` at `0460c6b`
    protects the V1.2 Owner-test candidate EXACTLY.
  - The V1.2 branch is FROZEN at `0460c6b` even after
    V1.3 close, so the two stages are cleanly separable.
- **Locked contracts preserved**: R007..R012 + V1.2
  directive 026 items 1-12.
- **Test evidence at close**: Ruby 395/395 (at V1.2
  close, pre-V1.3). Node.js DOM 86 assertions.
  `git diff --check` clean.
- **V12-NIT-001 fix**: lives in the V1.3 branch commit
  `e66a9ad` (the fix touches the shared `renderLayerIssues`
  function; the V1.2 branch itself is FROZEN at
  `0460c6b`; the V1.3 branch imports the fix through
  the V1.2 -> V1.3 cut).

## V1.3 stage (CLOSED on SU2020 per CodeX 029, 2026-08-20)

- **CodeX verdict (end-of-stage)**: PASS WITH NITS,
  0 BLOCKs per CodeX 029 (combined V1.2 + V1.3 packet).
  V1.3 stage may be marked CLOSED on the verified
  SU2020 host.
- **Owner evidence**:
  `Prompt/OWNER_REPORT_V1_3_FACE_INVENTORY_SU2020_2026-08-20.txt`
  (Owner Gate 2 V1.3 PASS WITH NIT on real SU2020;
  V13-1..V13-6; V13-BLOCK-001 CLOSED via the production-
  seam fix; V13-NIT-001 spacing fixed in this commit).
- **V13-BLOCK-001 recheck CLOSED**: see
  `Review/CODEX_V13_BLOCK_001_RECHECK_2026-08-20.md`.
  Production-seam silent-collapse fix: AnalyzersRunner
  now passes `snapshot.layers` (Array<LayerRecord>)
  to FaceInventoryGrouper instead of `layer_groups`
  (Array<Hash> LayerSummary).
- **CodeX review file**:
  `Prompt/CODEX_REVIEW_028_2026-08-20_V1_3_FACE_INVENTORY_REAL_HOST_BLOCK.txt`
  (the original V13-BLOCK-001 BLOCK) +
  `Prompt/CODEX_REVIEW_029_2026-08-20_V1_2_V1_3_END_OF_STAGE.txt`
  (the consolidated end-of-stage verdict).
- **V1.3 directive**: `Prompt/CODEX_GUIDANCE_027_2026-08-20_DEFER_OWNER_SU_AND_CONTINUE_V1_3.txt`
  (Face Inventory; aggregate-by-layer UI rows;
  preserve V1.0/V1.1/V1.2 contracts; SU2017 Gate 1
  deferred; Owner SU2020 testing deferred for V1.2).
- **Implementation status**: COMPLETE on
  `v1.3-face-inventory` branch (cut from V1.2 candidate
  head `0460c6b`).
  - Commit `b896e04`: core data layer (FaceRecord +
    GeometrySnapshot.faces extension + LayerRecord
    face_count + faces_with_holes_count + PreflightRunner
    walk extension + SUCapability face probes +
    FaceInventoryGrouper).
  - Commit `b415364`: core data + adapter tests.
  - Commit `a72d23e`: pipeline + payload
    (AnalysisResult.face_inventory_groups + PreflightReport
    face counters + UIBridge faceInventoryGroups top-level
    key + AnalyzersRunner FaceInventoryGrouper wiring).
  - Commit `5d20560`: UI render (`<details id=
    "face-inventory-section">` AFTER Layers,
    `renderFaceInventory` + `renderFaceInventoryRow`,
    `.face-inventory-row` neutral styles, Faces /
    Faces With Holes scalars in #summary).
  - Commit `bf2b2fc`: V13-BLOCK-001 production-seam fix.
  - Commit `e66a9ad`: V13-NIT-001 spacing fix (margin-
    only fallback; no flex gap to avoid double-spacing).
- **Locked contracts preserved**:
  - R007..R012 (V1.1 layer semantics unchanged; role
    badges + visibility badges for face rows reused
    from V1.1 LayerRecord shape).
  - V1.2 directive 026 items 1-12 (layerIssueGroups
    byte-for-byte intact; regression guard test in
    test_ui_bridge.rb).
  - V1.3 directive 027 items 1-12 (Face Inventory
    section position, default-closed, summary format,
    aggregate-by-layer rows, singular/plural wording,
    textContent-only, non-actionable rows, read-only
    analysis, no new role colors).
- **Test evidence at close**:
  - Ruby: 470/470 PASS (395 V1.2 + 75 new V1.3 = 8 + 10 +
    11 + 8 + 4 + 7 + 6 + 4 + 9 + 6 + 1 source guard + 1
    V12-NIT-001, 0 fail / 0 error).
  - Node.js DOM: 114 assertions (67 V1.1 + 19 V1.2 +
    19 V1.3 + 3 V13-NIT-001 + 6 V13-BLOCK-001 + the
    rest, all PASS).
  - `git diff --check` clean for `extension/` and `tests/`.
  - `dist/SU-AI-Plugin.rbz` rebuilt locally
    (255170 bytes, 43 entries; gitignored).
  - Performance guard: 5,000 + 50,000 face aggregations
    stay linear; FaceInventoryGrouper on 10 layers
    sub-second.

## V1.1 stage (CLOSED on SU2020 per CodeX 025, 2026-08-20; historical context)

- **CodeX verdict**: PASS WITH NITS. 0 BLOCKs. V1.1 stage
  may be marked CLOSED on the verified SU2020 host.
- **Owner evidence**: `Prompt/OWNER_REPORT_V1_1_LAYERS_2026-08-20.txt`
  (Owner Gate 2 V1.1 PASS WITH NIT on real SU2020).
- **CodeX packet**: `Review/CODEX_END_OF_STAGE_REVIEW_REQUEST_V1_1_LAYERS_2026-08-20.md`.
- **CodeX review file**: `Prompt/CODEX_REVIEW_025_2026-08-20_V1_1_LAYER_SEMANTIC_MAPPING_STAGE.txt`.
- **NITs closed**:
  - V1.1 NIT 1 (visual spacing + plural): commit `33b601a`.
  - V1.1 NIT 2a/2b/2c (fixtures): commit `0a1f2af`.
  - CodeX DOC-025-001 (OWNER_VERIFICATION loader path +
    L7 fixture count + L2 duplicate + CRLF normalization):
    in the CodeX-025 follow-up commit.
  - CodeX DOC-025-002 (qualify the packet's
    `git diff --check` statement to scope to `extension/`
    and `tests/`): in the same follow-up commit.
  - CodeX EVIDENCE-025-003 (visual re-verification of
    separator/plural NIT fix on post-fix SU2020): no
    action required per CodeX.
- **Debt** (per CodeX 025, kept parked):
  - LayerIssueGrouper was unconnected to the V1.1 UI;
    V1.2 closes that hook (see the V1.2 section above).
  - No git remote configured; backup / push separately.
    Not a V1.1 / V1.2 blocker.

## Next action (post-V1.4 stage 4, awaiting mandatory V1.4 CodeX stage review)

1. **Owner** (whenever Owner is ready; this is a
   non-CodeX-triggered step):
   - **V1.4 real-SU2020 verification**: per directive 030
     exit gate, run the V1.4 workflow on a real
     SketchUp 2020 model. The Owner Gate 2 V1.4 checklist
     covers: select representative imported/nested CAD;
     capture source-integrity fingerprint; create derived
     workspace; visibly distinguish source from derived
     without changing source properties; discard and
     confirm source unchanged; rebuild and compare derived
     result; inject or safely simulate an
     interrupted/failing creation path; verify source
     unchanged and partial result not READY; verify Undo
     as an extra safety layer, not the only discard
     mechanism; confirm scale/units/world position on
     nested/shared-instance cases.
   - Drop the V1.4 Owner report at
     `Prompt/OWNER_REPORT_V1_4_DERIVED_WORKSPACE_2026-08-XX.txt`.

2. **Agent** (immediately after the Owner V1.4 evidence
   is dropped):
   - Assemble the V1.4 stage-review packet per directive
     030: base = `550eb74` (V1.4 directive commit on
     `v1.3-face-inventory`), head = `431af5d` (current
     V1.4 head), changed files, focused source-integrity /
     provenance / failure evidence, full regression
     result, real-SU2020 Owner evidence. Drop at
     `Review/CODEX_V1_4_STAGE_REVIEW_REQUEST_2026-08-XX.md`.

3. **CodeX**: next engagement is the **MANDATORY V1.4
   STAGE REVIEW** per directive 030. The review scope is:
   source vs derived ownership; SourceSnapshot and
   provenance contract; deep immutability / fingerprint
   evidence; shared-definition isolation; failure /
   discard / rebuild behavior; SU2017+ compatibility
   implications; relevant regressions and real SU2020
   workflow. Do not submit tiny edit packets.

4. **Post-V1.4 (when CodeX V1.4 stage review PASS is
   received)**: assemble the final V1.0 + V1.4 RBZ
   (`dist/SU-AI-Plugin.rbz`); re-run Gate 1 (SU2017) +
   Gate 2 V1.4 on the combined artifact; drop the formal
   release evidence at
   `Prompt/OWNER_REPORT_FORMAL_RELEASE_2026-08-XX.txt`;
   dispatch the FINAL CodeX release review packet.

5. **Out of scope** (V1.5+ stays parked):
   - No V1.5+ repair actions (delete / weld / flatten /
     gap-close / loop-rebuild / face / site / MCP / AI).
   - No re-opening of V1.0 / V1.1 / V1.2 / V1.3 closed
     scope without new concrete evidence.
   - No re-opening of CodeX 029 / 030 closed scope.

## Active baseline (V1.0, head of `main` = 56ea611)

- V1.0 candidate is **frozen** for release decisions. Do not mix
  V1.1 / next-stage work into this baseline without re-running
  Gate 2 + Gate 1 on the resulting RBZ.
- Stage 6 owner verification: PASS (K..N real-SU2020, including
  closed group / duplicate component / deep nesting / dangling
  edge).
- Gate 2 install: PASS (dist/SU-AI-Plugin.rbz installed on
  SU2020, Owner verbal confirm recorded in
  Review/OWNER_VERIFICATION_RBZ_INSTALL_2026-08-19.txt).
- RBZ package + root loader structure: PASS (CodeX Review 024
  recheck closed BLOCK-022-001 and BLOCK-023-001/002).
- Real-host fixes closed this week: REAL-HOST BLOCK (to_a +
  variable-shadow), K2 duplicate-component crash
  (IssueNormalizer private/module_function), L3 non-locatable
  warning (renderIssue click-handler gate). All 286 tests PASS,
  all evidence in the lower sections of this file.

## V1.1 stage (historical implementation record; superseded by the CLOSED-ON-SU2020 section above)

The new V1.1 section at the top of this file is authoritative
after CodeX 025 (2026-08-20). The narrative below is preserved
for historical context only; it captures the implementation
details and locked decisions at the time of `823feab`.

## V1.1 stage (IMPLEMENTATION COMPLETE on
            `v1.1-layer-semantic-mapping` branch, head = `823feab`)

- **Implementation status**: **ALL 5 commits landed**; full
  suite 372/372 PASS, 0 fail, 0 error. V1.0 baseline (286
  tests) UNCHANGED; 86 V1.1 additions (Layer role + config +
  record + source ref, mapper, grouper, su_capability visibility,
  AnalyzersRunner integration, UIBridge layerGroups, full UI
  render for Layers section).
- **Decision (Cicada 2026-08-19)**: V1.1 first stage is
  **Layer Semantic Mapping** — read-only classification of each
  layer into a role (:construction / :dimension / :annotation /
  :guide / :unknown), surfaced in a new "Layers" section of
  the dialog. Visibility is a SEPARATE field, NOT a role
  (R007 / ChatGPT §11.3).
- **Plan**: `Review/V1_1_LAYER_SEMANTIC_MAPPING_PLAN_2026-08-19.md`
  (FINAL, 864 lines).
- **Progress report**: `Review/V1_1_LAYER_SEMANTIC_MAPPING_PROGRESS_2026-08-19.md`
  (updated 2026-08-20 with all 5 commits + RBZ rebuild + L1..L9
  checklist handoff).
- **Owner checklist (Gate 2 V1.1)**:
  `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt`. Steps
  L1..L9 cover V1.0 baseline + 8 V1.1-specific checks + a
  byte-identical PRE/POST fingerprint.
- **Reviewer routing** (per Cicada 2026-08-19 routing rule):
  1. **ChatGPT** answered §11 — 10 plan-level policy / UX /
     fail-closed / sort-order questions. **ALL ANSWERED.**
  2. **Agent self** decided §12 — 2 contained code-architecture
     questions with documented defaults (SourceReference
     extension; first-seen-wins dedup).
  3. **Agent** implemented per the answers + defaults (5/5
     commits landed).
  4. **CodeX** end-of-stage review of the full V1.1
     implementation diff (§13), awaiting Owner Gate 2 V1.1
     evidence.
- **Locked V1.1 decisions** (all incorporated into the implementation):
  - **R007** (ChatGPT §11.3): role and visibility are SEPARATE
    fields. The `OFFSCREEN` role Symbol is REMOVED. 5 name-based
    roles only.
  - **R008** (ChatGPT §11.7): no role color hints in V1.1.
    Roles use text + neutral badge. V1.0 issue severity palette
    is NOT reused for roles.
  - **R009** (ChatGPT §11.2): layer display order = role
    order, hidden layers LAST within each role bucket (with
    `opacity: 0.6` muted style).
  - **R010** (ChatGPT §11.8): rule ordering is top-down-by-
    priority. NOT auto-promoted by specificity. Specificity
    may be a future tie-break / lint hint, not the main rule.
    Test pin: a layer matching two rules gets the FIRST rule's
    role.
  - **R011** (ChatGPT §11.9): `layer_visibility` returns
    `:visible | :hidden | :unknown` Symbol. The caller maps
    `:unknown` to `LayerRecord(visible: true, visibility_unknown:
    true)` — operational fallback is visible, but the data
    model preserves the uncertainty. UI surfaces a third
    badge "Visibility: unknown". We do NOT fake `false`
    ("confirmed hidden") when the answer is "I don't know".
  - **R012** (ChatGPT §11.10): layer role order is INDEPENDENT
    from `IssueRegistry::DEFAULT_GROUP_ORDER`. Locked as
    `[dimension, annotation, guide, construction, unknown]`.
    Issue type and semantic role are two different information
    systems.
  - Layers section BELOW per-issue-type groups (ChatGPT §11.1).
  - Layers `<details>` default-closed, summary shows
    `"Layers — N total (M with issues)"` (ChatGPT §11.5).
  - `:unknown` role retained, surfaced as "Unknown / ?"
    (ChatGPT §11.6).
  - Per-layer `edge_count` + `issue_count` both shown,
    `issue_count` visually emphasized when > 0 (ChatGPT §11.4).
- **Branch state**: `v1.1-layer-semantic-mapping` cut from
  `v1.0-candidate-2026-08-19` at commit `56ea611`. **5 code
  commits landed** as of this report (head = `823feab`):
  ```
  823feab feat(v1.1): UI render for Layers section + locked L4 DOM/CSS/JS contract (commit 5)
  ef9ae04 feat(v1.1): AnalyzersRunner.layer_groups + UIBridge.layerGroups (commit 4)
  4e626d3 feat(v1.1): SUCapability.layer_visibility + preflight layer population (R007/R010/R011)
  a2b05df feat(v1.1): LayerSemanticMapper + LayerIssueGrouper (pure Ruby)
  460037c feat(v1.1): pure Ruby layer data layer + V1.1 extension to existing records
  ```
  `dist/SU-AI-Plugin.rbz` rebuilt locally at end of commit 5
  (214,776 bytes, 41 entries; gitignored). `git diff --check`
  clean on all 5 commits.
- **Hard scope** (inherited from V1.0 + R006 = Gate 1 deferred):
  - Read-only analysis, no model mutation, no new SU API beyond
    `Layer#visible?`.
  - V1.0 tests (286) MUST still pass unchanged. **VERIFIED: all
    286 V1.0 tests pass on the V1.1 branch head.**
  - Gate 1 (SU2017) remains PENDING per R006; not a V1.1 blocker.
  - Gate 2 V1.1: Owner re-runs the V1.0 checklist PLUS V1.1
    Layers-specific checks on real SU2020 before V1.1 is
    considered ready. **Checklist drafted at
    `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt`; awaiting
    Owner run.**
- **Next action** (post-implementation):
  1. **Owner Gate 2 V1.1** — run
     `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt` steps
     L1..L9 on real SU2020. Owner drops report to
     `Prompt/OWNER_REPORT_V1_1_LAYERS_2026-08-XX.txt`. Once Owner
     reports PASS, V1.1 stage is accepted on the verified host.
  2. **CodeX end-of-stage review** — Agent dispatches ONE
     consolidated packet per plan §13 (this branch's full diff
     `56ea611`..`823feab` + 372/372 test results + Gate 2 V1.1
     Owner report + §12 defaults + §8 known risks). CodeX engages
     ONLY at this boundary; reopening V1.0 Stage 6 / CodeX 020
     / RBZ / CodeX 024 is explicitly out of scope.
  3. **Formal release** — Owner combines V1.0 + V1.1 in the
     final .rbz artifact, reruns Gate 1 (SU2017) + Gate 2 V1.1
     on the combined artifact, and ships. Per R006, Gate 1 is
     deferred to formal release.

## Migration tail (commits 8814455, b0c16c8)

- `8814455 chore(structure): finalize V1.0-candidate package-structure
  migration` — removes the 24 legacy root-level `core/*` and
  `compatibility/*` files that were duplicated at
  `extension/su_ai_plugin/{core,compatibility}/` since 7b722b9
  (RBZ standard contract commit).
- `b0c16c8 chore(scripts): add stop_monitor.ps1 helper` — adds
  the missing workflow companion to the already-tracked
  `prompt_monitor.ps1` / `restart_monitor.ps1` /
  `check_monitor.ps1` / `prompt_monitor_one_shot.ps1`.
- These are pure cleanup, no product-scope, no compatibility,
  no release-promise changes. No Codex review was triggered;
  ordinary implementation decision per the handoff protocol.

## Open / pending (NOT in scope to act on now)

- **Owner formal-release prep** (current next action):
  Cicada combines V1.0 + V1.1 in the final `.rbz`
  (one entry-point `su_ai_plugin.rb` at the package root;
  one support folder `su_ai_plugin/` with `main.rb`,
  `core/`, `compatibility/`, `html/`), then re-runs
  Gate 1 (SU2017) + Gate 2 V1.1 (Owner verification
  checklist) on the combined artifact.
- **CodeX formal-release review** (next code action after
  Owner formal-release evidence lands). Next CodeX
  engagement is the formal-release review packet (final
  RBZ + SU2017 Gate 1 + SU2020 Gate 2 + no-mutation
  evidence). CodeX is reserved for: complete coherent
  stage (V1.1 was that; formal release is the next),
  high-risk blocker, BLOCK recheck, final release review.
  Reopening V1.0 / V1.1 scope is explicitly out of scope.
- **Gate 1 (SU2017 minimum-host verification)**: PENDING.
  Cicada (2026-08-19) has chosen to defer this until
  formal release. Per R004 + R006 posture, this is a
  final release gate and MUST be repeated on whatever
  RBZ is shipped. Do not block V1.1 acceptance on this;
  do not fake SU2020 evidence as SU2017 evidence.
- **V1.1 LayerIssueGrouper integration into the UI**:
  the commit-2 pure-Ruby grouper
  (`core/layer_issue_grouper.rb`) exists but is not yet
  consumed by any UI surface. It is a forward-compatibility
  hook for a future V1.1.1 stage that wants an
  "Issues by Layer" <details> block. Per plan §4.5 the
  API is locked; the UI integration is intentionally
  deferred. **NOT a V1.1 blocker; do NOT reopen V1.1 for
  this work.**
- **CodeX review cadence**: Pi's handoff is explicit —
  do NOT submit tiny edit packets, partial packets, or
  progress pings. Codex is reserved for: complete coherent
  stage, high-risk blocker, BLOCK recheck, final release
  review. Routine coding decisions stay with the agent.

## 决策落地 (PI_TASK_001)

| ID | Decision | 状态 |
|---|---|---|
| Q001 git workflow | **B** — 本地 git init, 不 push, 阶段 commit | ✅ 已在用 |
| Q002 real SU verification | **A** — Owner 在真 SU 跑, Agent 写代码 + 清单 | ✅ 按此推进 |
| Q003 target SU version | **A** — **SU2017+ 硬基线, Ruby 2.2.4** | ✅ 已修正 |
| Q004 Ruby in Agent env | **C** — 隔离运行时, 真实跑 tests | ✅ DONE |

## 重要事实纠正 (per Codex 2026-08-14)

- ❌ 旧假设 (Stage 0 那轮写的): "Ruby 2.4+", "Q003=B (SU2018+ 基线)"
- ✅ 正确: **SU2017+**, **Ruby 2.2.4** 是硬最低基线
- ✅ `Sketchup::Entity#persistent_id` 在 **SU2017 起就有**, 不是 SU2018+ 才有
- ✅ capability detection (`respond_to?`) 优先于版本号判断

## CODEX REVIEW 009 (2026-08-17) — VERDICT: PASS (BLOCK recheck 4)

CODEX_REVIEW_009 (BLOCK recheck 4, commit 9ff2e49 + recheck packet):
  VERDICT: PASS
  ALL BLOCKS CLOSED:
    S2-BLOCK-001                CLOSED
    S2-BLOCK-002                CLOSED  (real API contract accepted)
    S2-BLOCK-003                CLOSED
    S2-BLOCK-004                CLOSED  (adjacent-bucket dedup accepted)
    S2-BLOCK-005                CLOSED  (checklist H correction accepted)
    S2-BLOCK-006 HtmlDialog     CLOSED
    S2-BLOCK-006 version         CLOSED  (dotted diagnostic + major)

  Stage 2 implementation BLOCK-checks PASSED. This is NOT a release
  verdict and NOT a substitute for real-host evidence.

  Owner should now execute Review/OWNER_VERIFICATION_STAGE_2.txt
  steps A-I in real SketchUp. SU2017 required to close R004 caveat.
  Owner drops report to Prompt/OWNER_REPORT_STAGE_2_<date>.txt.

## CODEX REVIEW 008 (2026-08-17) — BLOCK recheck 3 result

CODEX_REVIEW_008 (BLOCK recheck 3, commit 88ad609 + recheck packet):
  S2-BLOCK-002  CLOSED  (real API contract accepted)
  S2-BLOCK-004  CLOSED  (adjacent-bucket dedup accepted)
  S2-BLOCK-006 version subpart  CLOSED  (dotted diagnostic + major)
  S2-BLOCK-005  REMAINS OPEN  (only checklist H selection shape has
                              overlap; traversal itself OK)
  S2-BLOCK-001 + S2-BLOCK-003 + S2-BLOCK-006 HtmlDialog  still CLOSED

NEXT: 修 S2-BLOCK-005 checklist H (selection_array 去掉 e2_valid),
加 1 个自动化测试用修正后的形状。

## CODEX REVIEW 007 (2026-08-17) + GUIDANCE 006 — BLOCK recheck 2 result

CODEX_REVIEW_007 (BLOCK recheck 2, commit d7ac371 + Review recheck packet):
  S2-BLOCK-001  CLOSED  (still)
  S2-BLOCK-003  CLOSED  (still)
  S2-BLOCK-006 HtmlDialog subpart  CLOSED  (namespace fix accepted)
  S2-BLOCK-002  REMAINS OPEN  (real API contract issues)
  S2-BLOCK-004  REMAINS OPEN  (boundary-bucket dedup)
  S2-BLOCK-005  REMAINS OPEN  (checklist + invalid geometry)
  S2-BLOCK-006 version subpart  REMAINS OPEN  (version_number not calendar year)

CODEX_GUIDANCE_006 (plan corrections, MANDATORY):
  1. Version API: sketchup_version to_s for diagnostics; baseline
     `Sketchup.version.to_i >= 17`. NO calendar-year inference from
     version_number.
  2. Active edit context: use model.edit_transform; model.active_path
     is Array (NOT InstancePath); resolver takes dot-delimited String.
  3. Vertex dedup: search current + adjacent buckets; preserve
     5000-Edge perf target.

NEXT: pass-3 rework incorporating CODEX_GUIDANCE_006 corrections.
Closed scopes stay closed (S2-BLOCK-001, S2-BLOCK-003, S2-BLOCK-006
HtmlDialog).

## CODEX REVIEW 005 (2026-08-17) — VERDICT: PARTIAL PASS, 4 BLOCKS remain

Codex did focused recheck (Commit eb3cd41) for S2-BLOCK-001..005.
Result:
  S2-BLOCK-001  CLOSED  (one Edge -> one EdgeRecord confirmed)
  S2-BLOCK-003  CLOSED  (no &. in production entry path)
  S2-BLOCK-002  REMAINS OPEN  (3 sub-issues)
  S2-BLOCK-004  REMAINS OPEN  (3 sub-issues + perf)
  S2-BLOCK-005  REMAINS OPEN  (5 sub-issues)
  S2-BLOCK-006  NEW BLOCK   (capability probe uses wrong namespace)

Plus NITs:
  - SourceReference instance_path mutability inconsistency
  - Recheck packet told Owner to verify before recheck PASS (should pause)

NEXT: focused rework on S2-BLOCK-002 / 004 / 005 / 006 only.
S2-BLOCK-001 / -003 stay closed.

## CODEX REVIEW 004 (2026-08-17) — VERDICT: BLOCKED on Stage 2 SU adapter

Codex reviewed Stage 2 commit 6eb33e8. Pure-Ruby 33/33 tests PASS evidence
remains valid for the paths it exercises. The SketchUp traversal / snapshot
adapter is BLOCKED with 5 BLOCKS — see Review/CODEX_REVIEW_004_BLOCK_REWORK_PLAN.md
(queued for next session).

5 BLOCKS:
  S2-BLOCK-001  Every SketchUp Edge becomes 2 EdgeRecords (doubling).
  S2-BLOCK-002  Component traversal, accumulated transforms, instance-aware
                identity missing in extension/preflight_runner.rb.
  S2-BLOCK-003  &. safe-navigation operator used (post Ruby 2.3, violates
                Ruby 2.2.4 baseline).
  S2-BLOCK-004  Preflight metrics do not match task contract (non-zero-Z
                counts, nesting level semantics, severity canonicalization).
  S2-BLOCK-005  Owner verification checklist has invalid API setup paths
                and weak source-integrity check.

CURRENT_STATE label correction (Codex NIT):
  Stage 2 is NOT 'DESIGN PASS'. It is: 'pure-Ruby Preflight tests pass;
  SU adapter blocked / rework required'. Fixed below in section labels.

R001-R005 are all ANSWERED (Codex decisions documented in each R### file
per WORKFLOW_PROTOCOL). All 5 R### files updated to Status: ANSWERED.

## 已完成 (Stage 0 + Stage 1)

### Stage 0 — 仓库骨架
- `git init -b main` (本地, 不 push)
- `.gitignore` (SU/CAD/编辑器/OS/Ruby)
- `README.md` + `CURRENT_STATE.md`
- 自建 `tests/runner.rb` + `tests/run_all.rb` (零 gem 依赖)

### Stage 1 — 纯 Ruby Geometry Core (代码已就位 + 实跑通过)
- 数据模型: `Tolerance / SourceReference / EdgeRecord / VertexRecord /
  LayerRecord / AnalysisConfig / GeometrySnapshot`
- 空间索引: `QuantizeKey / VertexIndex`
- 4 个 Analyzer: `DuplicateDetector / ShortEdgeDetector /
  OpenEndpointDetector / GapCandidateDetector`
- `SyntheticFactory` 测试 fixture 构造器 (已从 class 改为 module)
- `Tests.run!` 测试 dispatcher (Stage 1 PASS commit `5e32ab1` 补齐)
- Synthetic Tests TC-01..TC-10 + 数据模型 + 容差边界 + issue 字段
  完整性测试, 总共 26 个 `test` cases
- 代码风格: Ruby 2.2.4-safe (无 pattern matching / numbered params /
  endless method / kwargs 糖 / frozen_string_literal magic)
- ✅ 隔离 Ruby 2.7.8 实跑: 26/26 PASS

### Stage 2 — Preflight (pure-Ruby 部分 PASS, SU 端 BLOCKED / rework 待执行)
**纯 Ruby 部分 (Agent 已实跑通过):**
- `core/tolerance.rb` 新增 2 字段: `big_z` (默认 0.01 in),
  `large_coordinate` (默认 1e6 in)
- `core/analysis_config.rb` 增加 passthrough `big_z` / `large_coordinate`
- `core/preflight.rb` NEW: `PreflightReport` 数据类 +
  `PreflightAnalyzer` 纯 Ruby 聚合器 (无 Sketchup:: 调用)
- `tests/test_preflight.rb` NEW: TC-11..TC-15 + 2 EXTRA = 7 cases
- 7/7 PASS

**SU 端部分 (Agent 设计完毕, Owner 在真 SU 验证):**
- `compatibility/su_capability.rb` NEW: capability 检测 shim
  (`sketchup_version`, `supports_persistent_id?`, `safe_persistent_id`,
   `edge?` / `group?` / `component_instance?` / `container?`,
   `layer_name`, `build_source_reference`)
- `extension/preflight_runner.rb` NEW: SU 端入口,
  从 `Sketchup::Selection` 递归 Group/Component 收集 Edges → 建
  GeometrySnapshot → 跑 PreflightAnalyzer → PreflightReport。
  §18 错误处理: 异常 Entity `warn` 后跳过, 不让分析崩
- `Review/OWNER_VERIFICATION_STAGE_2.txt` NEW: 9 步 (A..I) Owner 手动
  验证清单 (plugin load / capability / 各 preflight 字段 / 不改源 CAD /
  错误处理 / perf)

## Stage 1 自测状态 (Q004=C) — 2026-08-17 PASS

- ✅ 隔离 Ruby 运行时已落地: `.vendor/ruby/rubyinstaller-2.7.8-1-x64/`
  - 来源: GitHub mirror `ghfast.top` (直接 GitHub 在本环境下 10s 超时,
    `github.akams.cn` / `gh-proxy.com` 亦可用作 fallback)
  - 体积: 7z 包 12.17 MB, 解压后 90 MB, 含 `bin/ruby_builtin_dlls/`
    (缺这部分则 `ruby.exe` 会报 SxS 错误, 上一轮 `C:\Ruby27-x64\`
    安装不完整的原因就是这个 DLL 集合未提取)
  - 调用: 全程绝对路径 `.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`,
    不入 PATH, 不入 Git (`.vendor/` 已被 `.gitignore` 排除)
- ✅ 实跑 `tests/run_all.rb`: **33 tests: 33 pass, 0 fail, 0 error**
  - 完整 log: `.vendor/STAGE_1_TEST_RUN_2026-08-17.log`
  - Ruby 版本证据: `.vendor/RUBY_VERSION_2026-08-17.txt`
  - 覆盖: 16 data-model + 7 preflight + 10 synthetic TC-01..TC-10
- ✅ Stage 1 stable checkpoint commit `5e32ab1`
- ⚠️ **Q004 旁注 (caveat, 不阻碍进入下一阶段)**:
  - 实际跑测试的是 Ruby 2.7.8p225, 交付代码最低基线是 Ruby 2.2.4 (SU2017 内置)
  - 静态检查 Stage 1 + Stage 2 代码已经按 2.2.4-safe 写
  - 真实 2.2.4 baseline 证据 **仍需** 在最终 Gate 前补 (Owner 真 SU 验证
    跑 SU2017 即满足此 caveat, 不必单独找 2.2.4 二进制)

## 调试期顺手修的 bug

### Stage 1 (commit 5e32ab1)
- `core/synthetic_factory.rb`: `class SyntheticFactory` → `module SyntheticFactory`
  (原版 `class` + `module_function` 是语法错误, 上一轮没跑过测试所以没暴露)
- `tests/runner.rb`: 补上 `Tests.run!(filter=nil)` 方法
  (上一轮写了 TestCase/TestResult 但漏了 dispatcher, 调用 `Tests.run!` 会
  NoMethodError)

### Stage 2 (本轮, 跟 Stage 2 一起 commit)
- `tests/runner.rb` 加 3 个 helper: `assert_nil` / `refute_nil` / `assert_operator`
- `core/tolerance.rb` 加 `big_z` / `large_coordinate` 字段 + 默认值
  (向后兼容: 新字段有默认值, 不改现有 Profile 序列化路径)
- `core/analysis_config.rb` 加 passthrough, 让 PreflightAnalyzer 写
  `config.big_z` 而不是 `config.tolerance.big_z`
  (后续重命名 Tolerance 字段时不需跳 Preflight)

## Next Step (Phase G — Stage 2 BLOCK-checks COMPLETE, awaiting Owner real-SU verification)

1. ✅ **已结束** — Q001-R005 全部 ANSWERED, BLOCKED 现状反映到 CURRENT_STATE
2. ✅ **已结束** — Codex Review 004 BLOCK rework pass 1
   (commit `eb3cd41`): S2-BLOCK-001 + S2-BLOCK-003 CLOSED; 50/50 PASS
3. ✅ **已结束** — Codex Review 005 BLOCK recheck + pass 2 rework
   (commits `fd0a0ab`, `d7ac371`): S2-BLOCK-001/003 stay CLOSED;
   S2-BLOCK-006 HtmlDialog CLOSED; 65/65 PASS
4. ✅ **已结束** — Codex Review 007 BLOCK recheck 2 + GUIDANCE 006
   plan corrections received (最新 Prompt/)
5. ⏳ **下一步 (本轮)** — pass 4 final 修 S2-BLOCK-005 checklist H
   selection_array 修正 + 1 自动化测试 (生产 traversal 不动)
   CODEX_GUIDANCE_006 三条修正:
   - Version API: sketchup_version 保留 String 诊断;
     baseline = `Sketchup.version.to_i >= 17`; 不从 version_number 推日历年
   - Active edit context: model.edit_transform + active_path 是 Array;
     resolver 接收 dot-delimited String
   - Vertex dedup: 扫当前 + 邻接 buckets; 保留 5000-edge perf
   见 `Review/CODEX_REVIEW_007_BLOCK_REWORK_PLAN.md`
6. **BLOCK recheck 3 PASS 后** — Owner 跑真 SU 验证 (Q002=A) +
   走 R004 posture B (SU2017 必须)
7. **Stage 6** — UI (per R003 + R005)
8. **Stage 7** — TASK 001 IMPLEMENTATION REPORT (PI_TASK_001 §22)
9. **最终 Gate 前** — Ruby 2.2.4 / SU2017 真机证据 (R004 posture B)


## Stage 2 设计边界 (NOT IN SCOPE, 明确不做, per PI_TASK_001 §17)

本阶段禁止实现：

- 自动删除重复线、Gap 自动连接、Flatten、Weld、Polyline reconstruction、
  Closed Loop reconstruction、Face generation、道路识别、建筑识别、
  Layer semantic mapping、AI、MCP、场地生成、住宅生成、自动 CAD import、
  完整 settings UI、云服务。

如果发现这些需求: 记录 TODO, 不要顺手做。

## 已知问题 / Lessons

### Lesson — review assumption vs hard constraint
- Stage 0 那轮把 Q003 默认假设成 "SU2018+ / Ruby 2.4+", 用 "更现代" 为由
  默认升级产品基线, 这是错的。
- Owner 决策 #004 已经锁定 SU2017+ 硬基线, Agent 不应擅自决定。
- 后续: **凡是涉及产品 / 兼容基线 / 用户级行为 的决策, 一律上 Review**,
  不在 "技术细节" 的掩护下随手定。

### Lesson — install system Ruby is wrong direction
- 之前想装系统 RubyInstaller 是错路。
- 正确做法: 隔离运行时 (`.vendor/` 或 temp), 不污染 PATH, 跑完可删。
- 这条 lesson 跨项目价值高, 已经写到 Q004 IMPACT 段供 Codex / AIPM 审。

### Lesson — isolated 7z bundle needs ruby_builtin_dlls/
- 直接用 RubyInstaller-3.x .exe 在 Windows 7z 提取会缺 `x64-msvcrt-rubyNNN.dll`
- 选 .7z bundle + standalone 7zr.exe 是稳的; 前提是 bundle 含 `ruby_builtin_dlls/`
- RubyInstaller 2.7.8 .7z bundle 自带; 这是为什么本次 C:\Ruby27-x64\ 装出来
  ruby.exe 跑不了 (上一轮用了 rubyinst.exe self-extracting installer, 那个不走
  7z 提取路径, 也没走 Inno Setup, 落得不完整)
- 跨项目可复用: Windows 下跑 Ruby 的最小可用姿势 = `.7z` bundle +
  standalone 7-Zip, 不要 `.exe`

### Code — 无已知 block
- Stage 1 + Stage 2 纯 Ruby 部分: 33/33 PASS
- Stage 2 SU 端: 设计完毕, 等 Owner 验证

## CODEX REVIEW 018 (2026-08-18) �� GATE B RECHECK: ALL 6 BLOCKs CLOSED

**Verdict**: All 6 S6-GATE-B-BLOCK-001..006 closed in one consolidated
rework. Full test suite: 244/244 PASS, 0 fail, 0 error.

### Code-side changes
- `extension/analyzers_runner.rb`: removed the second `diagnostics = []`
  that wiped per-analyzer failure entries (BLOCK-005). Same `diagnostics`
  array now flows from the analyzer rescue -> IssueRegistry -> AnalysisResult.
- `extension/su_ai_plugin.rb` (new): real SketchUp boot entrypoint
  with `file_loaded?` / `file_loaded` guard + safe `require_relative`
  chain + `Loader.register!` exactly once (BLOCK-002).
- `extension/loader.rb`: register! uses a module-level `@registered`
  sentinel (NOT menu introspection) for idempotency; holds the live
  dialog reference in `@live_dialog`; on_analyze_selection propagates
  `model` into `DialogRunner.show` (BLOCK-002, BLOCK-004, BLOCK-006).
- `extension/dialog_runner.rb`: model flows through to DialogController;
  on_locate emits `window.SUAIP.toast(...)` on unresolved (BLOCK-003,
  BLOCK-004).
- `extension/dialog_controller.rb`: `view` resolves to
  `model.active_view` (capability-checked), NOT nonexistent
  `dialog.get_view` (BLOCK-004).
- `core/analysis_result.rb#summary`: exposes the locked Edges /
  Vertices / non-zero-Z vertices / warnings / issues[per-type]
  sub-fields required by the Stage 6 plan (BLOCK-006).
- `compatibility/su_capability.rb#active_edit_context_facts`:
  empty/root active path is the neutral complete state
  (`pid_path_complete: true`); non-empty with any nil slot is fail
  closed. Structural depth = entity count, NOT filtered PID length
  (BLOCK-001, Gate B proof #1+#2).

### Test-side changes
- `tests/_fake_ui.rb` (new): real Module for the UI constant with
  `UI::Command` + `UI::HtmlDialog` constants and per-instance `menu` /
  `HtmlDialog.new` delegation. `FakeUI::State` records menus + dialogs
  per test, with `install!` / `reset!` / `uninstall!` lifecycle so the
  no-UI world is restored after every test.
- `tests/test_loader.rb` (new): 6 FakeUI-based tests proving register!
  is idempotent, keeps the dialog reference, wires to the boot
  entrypoint, and the menu command handler is on_analyze_selection
  (BLOCK-002).
- `tests/test_dialog_runner.rb` (new): 8 lifecycle tests + 3 BLOCK-004
  end-to-end tests proving the menu -> dialog -> locate -> selection
  flow + unresolved toast control + ready handshake (BLOCK-003, 004, 006).
- `tests/test_html_render.rb` (new): 11 HTML/JS contract tests proving
  namespace consistency, no forbidden patterns, no overlay,
  textContent-only render, BLOCK callbacks not method(:) (BLOCK-003, 006).
- `tests/test_analyzers_runner.rb` (new): 3 failing-analyzer injection
  tests proving the per-analyzer recovery contract (BLOCK-005).
- `tests/test_preflight_runner.rb`: 3 BLOCK-001 build_snapshot
  integration tests (root Edge valid PID -> complete, nested
  valid-PID chain -> complete, active path with nil PID -> incomplete)
  per CodeX Round 018 BLOCK-001 minimum acceptable fix (BLOCK-001).
- `tests/test_preflight.rb`: capability probe (positive) ensure-block
  rewritten to be robust against UI already being a non-Module
  (defensive cleanup; the FakeUI was a plain class instance before
  this rework and leaked state).
- `tests/test_ui_bridge.rb`: `summary` keys assertion corrected (per-
  type counts live under `summary['issues']`, not at top level).
- `tests/test_html_render.rb`: file paths corrected from `../../`
  (resolves to D:/Projects/...) to `../` (resolves to the real
  project root); comment-stripping for the `eval` / `new Function`
  regex check; regex updated for `var ROOT = window.SUAIP` style.

### What remains
- CodeX Round 019: BLOCK RECHECK for the 6 closed BLOCKs. We expect
  PASS; if BLOCKs come back, fix in another consolidated pass.
- Owner Verification Stage 6 (real SketchUp 2020) �� `Review/OWNER_VERIFICATION_STAGE_6.txt`
  steps J..N. Owner is the only one who can run this (Q002=A).
- SU2017 minimum-host verification remains a release Gate (per R004);
  not a Stage 6 blocker.
- Packaging / .rbz for SketchUp Extension Manager �� not yet started;
  will follow Owner Verification Stage 6 PASS.

### Hard-rule compliance (per Cicada 2026-08-18 section ��)
- ? Does NOT change R001-R005 product decisions
- ? Does NOT expand product scope (no overlay, no repair, no mutation)
- ? Does NOT push / publish / release
- ? Does NOT skip Owner verification
- ? Does NOT fake SU2017 as SU2020 evidence

## CODEX REVIEW 019 (2026-08-18) �� GATE B RECHECK v2: BLOCK-002-R2 + BLOCK-006-R2 CLOSED

**Verdict**: BLOCK-001, -003, -004, -005, -006 stay CLOSED.
BLOCK-002-R2 (boot path is not executable as documented) and
BLOCK-006-R2 (per-issue-type summary counts not rendered) both
closed in this pass. Full test suite: 247/247 PASS, 0 fail, 0 error.

### Code-side changes (Round 019 rework)
- `extension/su_ai_plugin.rb`:
  - `file_loaded(...)` moved INTO the success branch �� only marked
    on full boot success. A transient boot failure leaves the loaded
    state unset, so the next load retries from scratch (per BLOCK-002-R2
    safe-retry contract).
  - Boot path is now a single method `SUAnalysis::Boot.boot!` that
    `require_relative`'s the deps in safe order and calls
    `Loader.register!` exactly once.
- `extension/html/app.js`:
  - `render(payload)` now emits per-issue-type counters in the locked
    canonical order (7 types: duplicate_edge_candidate, short_edge,
    open_endpoint, gap_candidate, significant_non_zero_z,
    abnormal_large_coord, deep_nesting) with human-readable labels
    ("Short Edges: 1", "Duplicate Candidates: 0", ...). The scalar
    header rows (Edges, Vertices, non-zero-Z, Warnings) come first,
    then the per-issue-type rows �� both linear, no nested-object
    stringification ("[object Object]") anywhere. Exposed
    `ROOT.ISSUE_TYPE_LABELS` for harness introspection.
- `tests/_fake_ui.rb`:
  - `FakeMenu#add_submenu` no longer does nonstandard create-or-return
    semantics. It always creates a NEW submenu �� mirroring the real
    `Sketchup::Menu` API, which does not guarantee find-or-create.
    Production idempotency relies on `file_loaded?` + module-level
    `@registered` sentinel, NOT on this method (per BLOCK-002-R2).

### Test-side changes (Round 019 rework)
- `tests/test_loader.rb` (rewrite):
  - Top-level `file_loaded?` / `file_loaded` / `file_unloaded` stubs
    so the test's `instance_eval` runner sees them via the entrypoint.
  - 1 NEW test "faithful boot �� load entrypoint twice, one menu item,
    handler reaches dialog" that:
    - Actually `load`s `extension/su_ai_plugin.rb` twice.
    - Asserts exactly ONE menu item across both loads.
    - Invokes the created command handler through to the dialog
      boundary (FakeUI.state.dialogs.length == 1).
    - After `file_unloaded` + sentinel reset, asserts the
      honest FakeMenu surfaces a SECOND submenu (proving the
      production code relies on `file_loaded?`, not on FakeMenu
      find-or-create).
  - 1 NEW assertion in "boot entrypoint exists and uses file_loaded?
    guard" that the `file_loaded` call comes AFTER `Boot.boot!` in
    the source.
  - 1 NEW "menu command handler is wired AND clicking it reaches
    the dialog" that actually invokes the handler (not just checks
    the name).
- `tests/test_html_render.rb` (additions):
  - 1 NEW test that spawns Node.js to actually `vm.runInContext`
    `extension/html/app.js` with a mock DOM, call `render(payload)`,
    and inspect the rendered children for the locked labels
    (Short Edges: 1, Duplicate Candidates: 0, etc.) and absence of
    "[object Object]".
  - 1 NEW source-text assertion that the locked `ISSUE_TYPE_LABELS`
    array exists in the canonical order.
- `tests/test_html_render_dom.js` (NEW): the Node.js executable
  render test (17 inline assertions, prints "PASS" on full success).
- `Review/OWNER_VERIFICATION_STAGE_6.txt` (rewritten step J):
  - Removed the 22-line manual file list.
  - Step J.1 now says: `load
    "D:/Projects/SU-AI-Plugin/extension/su_ai_plugin.rb"` (the
    supported entrypoint).
  - Step J.3 IDEMPOTENCY now points to the faithful boot test
    (not UI::Menu introspection) and the real-host path is
    `file_unloaded 'SU-AI-Plugin/extension/su_ai_plugin'` +
    re-load the entrypoint (NOT direct `load loader.rb`).

### NIT fixes (Round 019 NIT)
- This packet uses atx-style `### H2` headings (no `=======`
  underline) so `git diff --check` does not flag a conflict-marker
  pattern in the markdown source. The previous packet had a
  `git diff --check: PASS` claim but the independent command
  actually reported a conflict-marker pattern on the underline
  lines; the claim has been dropped. The packet's diff itself is
  clean.
- The "menu -> dialog" test was renamed to "menu command handler
  is wired AND clicking it reaches the dialog" and now ACTUALLY
  invokes the handler (not just calls `DialogRunner.show`
  directly). Future packet wording matches what executes.

### What remains
- CodeX Round 020: BLOCK RECHECK for the 2 closed BLOCKs. Expected
  PASS.
- Owner Verification Stage 6 (real SketchUp 2020) �� `Review/OWNER_VERIFICATION_STAGE_6.txt`
  steps J..N. Owner is the only one who can run this (Q002=A).
- SU2017 minimum-host verification remains a release Gate (per R004).
- Packaging / .rbz for SketchUp Extension Manager �� not yet started;
  will follow Owner Verification Stage 6 PASS.

### Hard-rule compliance (per Cicada 2026-08-18 section ��)
- ? Does NOT change R001-R005 product decisions
- ? Does NOT expand product scope (no overlay, no repair, no mutation)
- ? Does NOT push / publish / release
- ? Does NOT skip Owner verification
- ? Does NOT fake SU2017 as SU2020 evidence

## CODEX REVIEW 020 (2026-08-18) �� GATE B FINAL: PASS WITH NITS

**Verdict**: PASS WITH NITS. All 6 Gate B BLOCKs + the 2 Round-019
reopens (BLOCK-002-R2, BLOCK-006-R2) are CLOSED. The two NITs are
narrow checklist/evidence-hygiene corrections; no new review is
required.

### NIT corrections applied (CodeX Round 020)
- NIT 1 �� `file_unloaded` is not a documented SketchUp top-level
  API. The real API is `file_loaded?` / `file_loaded` only. Removed
  the Owner instructions that called `file_unloaded`. Step J.3
  now states that idempotency is covered by the automated
  faithful-boot test (no manual Ruby-Console visual confirmation
  is required).
- NIT 2 �� `tests/_fake_instance_path.rb` and
  `tests/test_no_overlay_lint.rb` were referenced in the checklist
  inventory but do not exist in HEAD. Removed the inventory entries
  and the step N.6 "load test_no_overlay_lint" instruction. N.6
  now relies on the existing recursive fingerprint + direct
  real-host property observation.

### Hard-rule compliance (per Cicada 2026-08-18 section ��)
- ? Does NOT change R001-R005 product decisions
- ? Does NOT expand product scope
- ? Does NOT push / publish / release
- ? Does NOT skip Owner verification
- ? Does NOT fake SU2017 as SU2020 evidence

### Next action
**Dispatch Owner Verification Stage 6** �� `Review/OWNER_VERIFICATION_STAGE_6.txt`
J..N on real SketchUp 2020. Owner is the only one who can run
this (Q002=A). Once Owner reports PASS, the next gate is the
SU2017 minimum-host verification (release Gate, per R004; not a
Stage 6 blocker). After that, packaging / .rbz for the SketchUp
Extension Manager.

## REAL-HOST BLOCK (Owner repro 2026-08-18) �� CLOSED

**Verdict**: BLOCK reported by Owner via direct message (not via
CodeX in Prompt/). Root cause: two related gaps.

### Code-side changes
- `extension/preflight_runner.rb`:
  - New public `normalize_selection(input)` that snapshots any
    Selection-like enumerable to a stable Array (to_ary -> each ->
    rescue chain).
  - `build_snapshot` calls `normalize_selection` at the very top,
    so preflight collection + walk iterate the same stable Array.
- `extension/analyzers_runner.rb`:
  - `run(selection, model: nil)` normalizes the selection once at
    the boundary; uses the normalized form for build_snapshot +
    selection_label_for + classification_label.
  - `preflight` is now a real `SUAnalysis::Core::PreflightReport`
    via `PreflightAnalyzer.run(snapshot)` (replaced the previous
    Hash from `collect_preflight_facts`). This makes
    `AnalysisResult#summary` able to read real `edge_count`,
    `vertex_count`, etc.

### Test-side changes
- `tests/test_preflight_runner.rb`: NEW `OneShotEnumerable` mock
  that mirrors a real SU Selection with one-shot iteration
  (responds to `:each` / `:count` / `:first` / `:to_a` / `:length`
  / `:empty?` but clears its items after the FIRST `.each` call).
  5 new tests:
  1. `build_snapshot` with OneShotEnumerable returns 4 edges.
  2. Without normalize, OneShotEnumerable returns 0 edges (proves
     the fix is required).
  3. `normalize_selection` converts Selection-like to a stable
     Array.
  4. `AnalyzersRunner.run` with OneShotEnumerable returns 4 edges.
  5. Array input still works (regression on the fix).

### Lessons
- **Always normalize Enumerable at the API boundary.** Real-world
  Enumerables can have iteration quirks (one-shot, lazy,
  side-effecting). A cheap `Array.dup` at the boundary removes an
  entire class of real-host bugs.
- **`safe_attr` on a Hash always returns the default.** A Hash
  returns `false` for any method-name symbol, so `safe_attr(pf,
  :edge_count, 0)` on a Hash returns 0. The downstream code path
  was designed for a PreflightReport; the Hash was an upstream
  architecture gap that survived because fake-host tests
  happened to pass a Struct, not because the production path was
  correct.
- **The fake-host suite is only as strong as its mocks.**
  `FakeSU::Selection` does NOT have one-shot iteration, so it
  cannot surface this real-host bug. The new `OneShotEnumerable`
  mock explicitly exhibits the one-shot behavior to prove the
  fix and to catch any regression.

### Next action
Owner re-runs the required recheck on real SU 2020:
- Menu Analyze selection on the 4-edge Group must show
  `Edges: 4, Vertices: 4, Warnings: 0`.
- Then rerun Owner K..N per `Review/OWNER_VERIFICATION_STAGE_6.txt`.

## REAL-HOST BLOCK (Owner repro 2026-08-18, RECHECK) — CLOSED

**Verdict**: BLOCK REOPEN from Owner on the same SketchUp 2020 repro.
The previous fix's `to_ary`-first strategy was NOT valid for the real
host: `Sketchup::Selection#to_ary` returns an empty Array on SU2020
even when entities are selected. A second latent bug also surfaced:
`AnalyzersRunner.run` reused the variable name `normalized` for both
the selection array and the issues array, so `classification_label`
saw the (empty) issues array and returned `'empty'`. Both fixed.

### Code-side changes (commit `efe2242`)
- `extension/preflight_runner.rb`:
  - `normalize_selection` no longer trusts `to_ary`. New priority:
    1. `to_a` (documented Sketchup::Selection public API; one-pass
       capture returning a stable Array).
    2. Manual `each` iteration (fallback when `to_a` is missing
       or returns non-Array).
    3. Empty array.
  - On SU2020, `Sketchup::Selection#to_ary` returns [] even when
    entities are selected (Ruby's strict array-coercion idiom),
    so any path treating `to_ary` as authoritative silently empties
    the normalized selection. The fix prefers `to_a` (the documented
    API).
  - `build_snapshot` calls `normalize_selection` at the very top.
- `extension/analyzers_runner.rb`:
  - The selection-boundary variable is renamed to
    `normalized_selection`. The issue-normalization array is renamed
    to `normalized_issues`. The two MUST NOT share a name: with the
    previous single-name `normalized`, the variable was shadowed
    inside the run() body (after `normalized = []` for issues),
    causing `selection_label_for(normalized)` and
    `classification_label(normalized)` at the end of run() to be
    called on the issues array (often empty for a closed rectangle).
  - For the OWNER's repro (4-edge Group): `classification_label`
    now sees the `[group]` array, not `[]`, so
    `result.selection_type == 'selection'` (NOT `'empty'`), and
    `result.selection_label == 'Group: test_group'`.

### Test-side changes
- `tests/test_preflight_runner.rb`: NEW `BrokenToArySelection` mock
  that explicitly mimics the SU2020 bug — `respond_to?(:to_ary)` is
  true, `to_ary` returns `[]`, but `to_a` / `count` / `each` /
  `first` / `length` / `empty?` all correctly report the entities.
  8 new regression tests:
  1. `normalize_selection` with BrokenToArySelection returns
     `[group]` (not `[]`).
  2. `build_snapshot` with BrokenToArySelection returns 4 edges.
  3. `AnalyzersRunner.run` with BrokenToArySelection returns
     `summary['edges'] == 4`, `vertices == 4`, `warnings == 0`.
  4. `selection_type != 'empty'` for BrokenToArySelection.
  5. White-box: `normalize_selection` does NOT call `to_ary`.
  6. Closed-rectangle `selection_type != 'empty'` (variable-shadow
     guard).
  7. `selection_label == 'Group: test_group'` (uses the Group's
     typename + name, not the generic default).
  8. (Existing) OneShotEnumerable tests still pass (5 tests).

### Required Owner recheck (on real SU 2020)
Per the OWNER's required recheck criteria:
1. `selection.add(test_group)` => 1.
2. `AnalyzersRunner.run(model.selection).summary['edges']` => 4.
3. `result.selection_type` must NOT be `"empty"`.
4. Menu dialog must show Edges: 4, Vertices: 4, Warnings: 0.
All four are now covered by automated fake-host tests. The OWNER
should rerun J..N on real SU 2020 to close the loop.

### Lessons
- **Do NOT trust `to_ary` as an authoritative conversion path on
  SketchUp Selection.** SU2020's `Selection#to_ary` returns `[]`
  even when the selection contains entities. The documented public
  API is `to_a`; the `to_ary` is a Ruby-implicit-coercion marker
  that SketchUp honors with the empty-Array idiom.
- **Avoid variable shadow in long methods.** `AnalyzersRunner.run`
  is ~50 lines; reusing the name `normalized` for two semantically
  different arrays (selection vs issues) caused a silent bug
  (`selection_type == 'empty'`) that only surfaced on real host
  with a no-issue selection (closed rectangle). The fix uses
  distinct names: `normalized_selection` and `normalized_issues`.
- **The fake-host suite is only as strong as its mocks.**
  `FakeSU::Selection` does NOT mimic the SU2020 `to_ary` bug, so
  the previous round's tests could not surface it. The new
  `BrokenToArySelection` mock explicitly exhibits the broken
  `to_ary` to prove the fix and to catch any regression.

### Hard-rule compliance (per Cicada 2026-08-18 section 6)
- Does NOT change R001-R005 product decisions.
- Does NOT expand product scope (no overlay, no repair, no mutation).
- Does NOT push / publish / release.
- Does NOT skip Owner verification.
- Does NOT fake SU2017 as SU2020 evidence.

## REAL-HOST BLOCK (Owner K2 repro 2026-08-18) — CLOSED

**Verdict**: K2 Owner-reported BLOCK on fresh SU2020: two coincident
component instances crash Analyze selection with
`NoMethodError: undefined method 'normalize_location' for
SUAnalysis::Core::IssueNormalizer:Module`, called from
`normalize_analyzer_issue` (reached via `extension/analyzers_runner.rb:96`).

### Root cause

`core/issue_normalizer.rb` used `module_function` at the top, then
declared `private` before its helper methods
(`normalize_location`, `sanitize_message`, `normalize_metadata`,
`canonical_preflight_code`, `severity_for_preflight`). In Ruby, the
`private` keyword overrides the `module_function` flag for
subsequent methods — so those helpers became PRIVATE INSTANCE
METHODS only, NOT module singleton methods.

### Why tests masked it

The test files (`tests/test_issue_normalizer.rb`,
`tests/test_issue_enricher.rb`) do
`include SUAnalysis::Core::IssueNormalizer` at the top. The
include adds the module's private instance methods to Object's
ancestor chain, which makes `Module.normalize_location(...)`
succeed via the include chain. So tests passed.

Production code (`extension/analyzers_runner.rb`) does NOT include
IssueNormalizer. So on the production call path, the implicit-self
call to `normalize_location(...)` from inside
`normalize_analyzer_issue` raised `NoMethodError: undefined method
'normalize_location' for SUAnalysis::Core::IssueNormalizer:Module`.

The first issue with a non-nil 3D location dispatched to
`normalize_location(loc)` and crashed the entire Analyze selection
command. On the K2 repro (two coincident component instances), the
duplicate issue has a non-nil `location: [200.0, 0.0, 0.0]`, which
triggers the bug on the first call.

### Code-side changes (commit `1133dcd`)
- `core/issue_normalizer.rb`:
  - Removed the `private` keyword (it broke `module_function` for
    subsequent methods).
  - Defined ALL helpers after `module_function` so they ARE
    module singleton methods (callable from production's
    `SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)`
    form AND from inside-the-module implicit-self form).
  - Marked helpers as `private_class_method` at the bottom of the
    module. This preserves the original `private` intent (helpers
    are internal, not part of the public API) WITHOUT breaking
    module-method dispatch.
  - The public API methods (`normalize_analyzer_issue`,
    `normalize_preflight_warning`, `normalize_preflight_warnings`,
    `canonical_severity`, `severity_for_type`) remain PUBLIC
    module singleton methods.

### Test-side changes (10 NEW in `tests/test_issue_normalizer.rb`)
- Production-path tests (no `include` in scope), exercising the
  exact fully-qualified call form used by `analyzers_runner.rb`:
  1. `normalize_analyzer_issue` with non-nil 3D location (the K2
     crash point).
  2. Non-Float location components coerced via `Float()`.
  3. Non-nil metadata Hash round-trips.
  4. Control-character message sanitized.
  5. `normalize_preflight_warnings` with all 3 codes (production
     path for the OTHER public API).
  6. Unknown preflight code returns `[]`.
  7. Helpers are private module methods (visibility contract).
  8. Public API remains public module methods (no public methods
    accidentally marked private).
  9. K2 full repro: duplicate with non-nil location via
     production call form returns the correct issue Hash.
  10. K2 batch repro: 3 mixed raw issues (some with non-nil
      locations) all survive production-path normalization.

### Required Owner recheck (real SU 2020)
- Two coincident component instances.
- Analyze selection must show:
  - **Edges: 2** (each occurrence's Edge in world coords).
  - **Duplicate Candidates: 1** (one Issue row, two SourceTokens).
  - **Warnings: 0** (no preflight warnings).
- No Ruby exception.
- The full pipeline test in the fix commit exercises exactly this
  scenario end-to-end via FakeSU; both Edge count, Duplicate count,
  Warning count, and the "no exception" invariant are covered.

### Lessons
- **`private` after `module_function` overrides `module_function`.**
  In Ruby, `module_function` (no args) sets a flag that affects
  subsequent method definitions until another visibility modifier
  is seen. `private` is such a modifier: methods defined after it
  become PRIVATE INSTANCE METHODS only, not module singleton
  methods. Use `private_class_method` instead to mark a module
  singleton method as private without breaking the module
  singleton method table.
- **`include M` at the top level can mask module-method visibility
  bugs.** The include pulls M's private instance methods into
  Object's ancestor chain, which makes `Module.foo(...)` succeed
  via the include chain — even when `foo` is NOT a module singleton
  method. Tests that rely on `include` to call helper methods will
  not catch this kind of regression; production-path tests that
  use the fully-qualified call form (no include in scope) are
  required.
- **The fake- suite suite is only as strong as its tests.** The
  previous test file's `include SUAnalysis::Core::IssueNormalizer`
  made the bug invisible. The new tests use the production call
  form (no include), exercising the exact dispatch path used by
  `extension/analyzers_runner.rb`.

### Hard-rule compliance (per Cicada 2026-08-18 section 6)
- Does NOT change R001-R005 product decisions.
- Does NOT expand product scope.
- Does NOT push / publish / release.
- Does NOT skip Owner verification.
- Does NOT fake SU2017 as SU2020 evidence.

## L3 non-locatable warning (Owner repro 2026-08-18) — CLOSED

**Verdict**: L3 BLOCK REOPEN from Owner: clicking the Deep Nesting
warning in the dialog shows the toast "source no longer available
for: deep_nesting|1" even though the warning is intentionally
non-locatable (no source token to resolve). SEL=1 and ACTIVE_PATH=0
are unchanged, but the toast makes the row look like a stale
source. The warning must NOT invoke Locate at all.

### Root cause

`extension/html/app.js#renderIssue` unconditionally added a click
listener that called `window.sketchup.locate(id)` for every
issue row. For non-locatable rows (preflight warnings like
`deep_nesting` and `abnormal_large_coord`), the locator
policy (`core/issue_locator_policy.rb#targets_for`) returns `[]`,
the host-side glue returns `:unresolved`, and `dialog_runner.rb`'s
`on_locate` fires the misleading "source no longer available for:
..." toast.

### Code-side changes (commit `4940613`)
- `extension/html/app.js`:
  - `renderIssue` now gates the `addEventListener('click', ...)`
    on `issue.locatable === true`. For `locatable === false`,
    **NO** click listener is registered. There is no path to
    `window.sketchup.locate` and therefore no path to the toast.
  - For `locatable === false`, the row carries a `no-action` CSS
    class and `data-locatable="false"`. The locked render contract
    (textContent + setAttribute, no innerHTML for user strings,
    no eval / no new Function / no document.write) is preserved.
  - For `locatable === true`, behavior is unchanged: the row gets
    a click listener that calls `window.sketchup.locate(id)` and
    does NOT carry the `no-action` class.
- `extension/html/style.css`:
  - New `.issue.no-action` block: `cursor: default` and
    `:hover { background: transparent }` so the row visually
    signals "intentionally not clickable" without hiding the
    warning. The locked severity palette (R005) is unchanged.

### Test-side changes
- `tests/test_html_render_dom.js`:
  - MockElement.addEventListener now records listeners so the L3
    tests can assert WHICH rows have click handlers registered.
  - MockElement exposes `hasListener(name)` for assertion.
  - MockElement exposes className getter/setter that maintains a
    `classes` array (split on whitespace) so tests can assert
    class membership the same way they would with real DOM.
  - 12 NEW ASSERT lines cover:
    - **L3.1** locatable row has click listener registered.
    - **L3.1** locatable row data-locatable attr is "true".
    - **L3.1** locatable row does NOT carry no-action class.
    - **L3.2** non-locatable row has NO click listener.
    - **L3.2** non-locatable row data-locatable attr is "false".
    - **L3.2** non-locatable row carries no-action class.
    - **L3.1** clicking locatable row invokes window.sketchup.locate ONCE.
    - **L3.1** locate receives the issue_id.
    - **L3.2** clicking non-locatable row does NOT invoke locate.
    - **L3.2** clicking non-locatable row N times still does NOT invoke locate.
- `tests/test_html_render.rb`:
  - 3 NEW Ruby-level tests:
    - Source-level guard: `addEventListener('click', ...)` appears
      exactly ONCE in app.js and is gated by `if (locatable)`.
    - Style contract: `.issue.no-action` is defined in style.css
      with `cursor: default` AND a `:hover` override.
    - The Node.js DOM test runs and the L3 ASSERT lines all PASS.

### Owner recheck (real SU 2020)
- Click Deep Nesting warning.
- No selection change, no camera change, no toast, no Ruby error.
- Warning visibly appears non-actionable (default cursor, no hover).
- All four invariants above are now covered by automated tests.

### Lessons
- **JS click handlers should mirror the data-model policy.** The
  locator policy already returns `[]` for non-locatable issues
  (`core/issue_locator_policy.rb#targets_for`). The JS click
  handler should respect the same boundary: do not register a
  handler at all for non-locatable rows. Adding the handler and
  having it return `:unresolved` produces a misleading toast
  ("source no longer available") that confuses the user.
- **Mock DOMs need to track listeners for click-handler tests.**
  The previous MockElement.addEventListener was a no-op, which
  made it impossible to assert which rows had handlers registered.
  For L3 (and any future click-dispatch contract tests), the mock
  must record listeners so tests can probe `hasListener('click')`.
- **CSS class membership is not the same as className string
  equality.** `className` is a space-separated string; testing
  membership requires splitting on whitespace. Mock DOMs should
  expose a `classes` array (and tests should use it) the same way
  real DOM testing libraries do (e.g. `element.classList.contains`).

### Hard-rule compliance (per Cicada 2026-08-18 section 6)
- Does NOT change R001-R005 product decisions.
- Does NOT expand product scope.
- Does NOT push / publish / release.
- Does NOT skip Owner verification.
- Does NOT fake SU2017 as SU2020 evidence.
