# GATE B MILESTONE REVIEW — Stage 6 Host-side Integration

| Field | Value |
|---|---|
| Created | 2026-08-18 |
| Project | D:\Projects\SU-AI-Plugin |
| Stage | 6 Gate B (host-side integration) |
| Source commits | `f68f4bd` (Gate A) → `8ddacda` (Round 015 fix) → `7110229` (Round 016 fix) → `e755d8e` (Gate B) |
| Base | `aeced98` (last CodeX-verified Stage 2 EOD) |
| Head | `e755d8e` |
| Status | **Gate B milestone complete; awaiting CodeX formal review** |
| Tests | **207 / 207 pass, 0 fail, 0 error** (+134 from base) |
| Diff size | 40 files changed, +4483 / -80 lines |
| Output file | `Review/GATE_B_MILESTONE_REVIEW_2026-08-18.md` |

---

## 1. VERDICT STATUS — CodeX approvals up to date

| CodeX round | Verdict | Scope |
|---|---|---|
| 004..009 (Stage 2) | PASS | Stage 2 BLOCK rework complete; all 6 BLOCKS CLOSED |
| 010 | BLOCKED | Pre-build plan review of Gate A core |
| 011 | BLOCKED | Plan recheck (BLOCK-001, -003 narrow) |
| 012 | BLOCKED | Plan recheck (BLOCK-001 v2, VERIFY-001) |
| 013 | BLOCKED | Plan recheck (BLOCK-001 v3, VERIFY-001 v2) |
| 014 | BLOCKED | Active-edit depth / completeness = moved to Gate B hardening |
| 015 | BLOCKED | Gate A implementation (BLOCK-001, BLOCK-002) |
| 016 | BLOCKED | Gate A recheck (BLOCK-002 v2 — same-PID different-location) |
| **017** | **PASS** | Gate A FINAL — Gate B authorized |

**CodeX Round 017 OWNER-LOCKED DIRECTIVE** (verbatim):
> *Effective immediately, formal Codex review is milestone-based, not edit-based.*
> *The next planned formal review is only after Gate B is complete as one coherent,
>  independently testable host-side integration milestone:*
> *all Gate B files implemented, required fake-host tests and lint/full suite passing,*
> *and the complete evidence packet ready.*

This packet is that milestone.

---

## 2. GIT BASE / HEAD

```
aeced98 docs(eod): end-of-day hand-off for next-session resume (Cicada 2026-08-17)
f68f4bd feat(stage6): Gate A Core contract — 8 new pure-Ruby core files + 8 test files + 1 lint
8ddacda fix(stage6): Gate A BLOCK-001..002 rework per CodeX Round 015
7110229 fix(stage6): Gate A BLOCK-002 v2 — location+edge_ids discriminators in stable sort key
e755d8e feat(stage6): Gate B host-side integration — full milestone
```

- `aeced98..e755d8e` = 4 commits, 40 files, +4483 / -80
- `git diff --check aeced98..HEAD` = PASS
- All Ruby files: `ruby -c` syntax check PASS
- No Ruby 2.3+ syntax in code (comments excluded): `&.`, `case-in`, `frozen_string_literal`, `_1`/`_2`, `$ERROR_INFO`

---

## 3. COMPLETE CHANGE SCOPE

### 3.1 Modified files (continuing evolution from Stage 2)

| File | Lines | Change |
|---|---|---|
| `compatibility/su_capability.rb` | 143 | +143/-8: added `active_edit_context_facts` (5-fact helper), `find_entity_by_id` (safe wrapper), `build_source_reference` extended with `structural_depth` / `pid_path_complete` kwargs |
| `extension/preflight_runner.rb` | 507 | +71/-22: walk now tracks `parent_struct_depth` and `parent_path_complete`; edges yield with populated structural identity; uses `active_edit_context_facts` for the seed |
| `core/source_reference.rb` | 96 | +51/-17: added `structural_depth` and `pid_path_complete` fields (default fail-closed: `pid_path_complete: false`); `entity_id` now optional |
| `core/synthetic_factory.rb` | 53 | +9/-1: explicit `structural_depth: 0, pid_path_complete: false` on synthetic edges |
| `.gitignore` | 41 | +3/-1: `data/_check_tmp/` and `/tmp/` are now gitignored |

### 3.2 New core files (Gate A v5 — re-confirmed by Gate B lint)

| File | Lines | Purpose |
|---|---|---|
| `core/structural_facts.rb` | 94 | pure-Ruby helper: `compute(ancestry, leaf_pid, active_path_count)` and `from_canonical_path(pid_path, active_path_count)` |
| `core/issue_registry.rb` | 193 | tolerant validation, required-key Hash contract, per-type canonical severity, summary, groups, open? |
| `core/issue_id_assigner.rb` | 91 | deterministic issue_id from `canonical_source_keys` + counter; no entity_id, no object_id (CodeX Round 015 BLOCK-002) |
| `core/issue_normalizer.rb` | 165 | `kind` → `issue_type`, Symbol → String, UTF-8 preservation, control-char strip, preflight warning → issue |
| `core/issue_enricher.rb` | 216 | edge_ids → SourceToken array, whole-token dedup, locatable derivation (6 profiles), counter stability via `stable_sort_key` (CodeX Round 016 BLOCK-002 v2) |
| `core/issue_grouper.rb` | 62 | canonical order, CodeX Q1 default-open (any :high → open; else first non-empty) |
| `core/issue_locator_policy.rb` | 95 | 6 profiles: complete-root / complete-nested / incomplete-root / incomplete-nested-partial-leaf / incomplete-nested-partial-ancestry / fully-missing |
| `core/analysis_result.rb` | 60 | immutable wrapper, no setters, frozen top-level + nested immutable by design |

### 3.3 New extension files (Gate B scope)

| File | Lines | Purpose |
|---|---|---|
| `extension/issue_locator.rb` | 187 | host-side glue: 6 Profile → Model entity resolution; LocateResult { status, targets, diagnostics }; `locate_and_select` applies selection + zoom (read-only on model) |
| `extension/display_unit_formatter.rb` | 64 | format_length via `Sketchup.format_length` (in SU) or deterministic fallback; format_all extracts length/distance from metadata |
| `extension/analyzers_runner.rb` | 146 | one-pass pipeline: snapshot → preflight → 4 analyzers → normalize → enrich → registry → AnalysisResult |
| `extension/loader.rb` | 81 | idempotent UI.menu / UI::Command registration; `register!` callable multiple times safely |
| `extension/dialog_controller.rb` | 55 | per-dialog state holder; bind/release pattern |
| `extension/dialog_runner.rb` | 76 | HtmlDialog lifecycle: set_file absolute path, callbacks as BLOCKS, ready handshake, set_on_closed release |
| `extension/ui_bridge.rb` | 91 | Symbol → JSON String boundary at the JS payload; nested Hashes have String keys; values coerced via `to_s` |
| `extension/html/index.html` | 20 | single-page layout: header + summary + groups + toast |
| `extension/html/style.css` | 107 | severity palette (R005): low neutral, medium orange, high red |
| `extension/html/app.js` | 102 | render(payload) via textContent / setAttribute; click → `window.sketchup.locate(issue_id)`; DOMContentLoaded → `window.sketchup.ready()` |

### 3.4 New test files

| File | Lines | Coverage |
|---|---|---|
| `tests/test_structural_facts.rb` | 155 | complete / incomplete / nested / active-edit contexts; invariant `pid_path.length == expected_pid_count` for no-active-edit |
| `tests/test_issue_id_assigner.rb` | 189 | deterministic id, canonical sort, counter tie-breaker, no-entity_id / no-object_id branches |
| `tests/test_issue_registry.rb` | 214 | validation, tolerant drop, summary, groups, open? |
| `tests/test_issue_normalizer.rb` | 129 | kind → issue_type, per-type severity, control-char strip |
| `tests/test_issue_enricher.rb` | 339 | aligned tokens, whole-token dedup, 6 locatable profiles, missing edge_id, counter stability permutations |
| `tests/test_issue_grouper.rb` | 116 | canonical order, CodeX Q1 default-open |
| `tests/test_analysis_result.rb` | 129 | immutability, no setters, frozen top-level |
| `tests/test_issue_locator_policy.rb` | 195 | 6 profile → target descriptor mapping |
| `tests/test_active_edit_context_facts.rb` | 106 | **Gate B proof #1+#2**: structural_depth = real entity count; pid_path_complete computed BEFORE nil filtering |
| `tests/test_issue_locator.rb` | 180 | 6 Profile resolution + diagnostics + non-locatable + multi-source dedup |
| `tests/test_display_unit_formatter.rb` | 66 | fallback formatting + format_all extraction |
| `tests/test_ui_bridge.rb` | 134 | Symbol → String key conversion, JSON serialization, deep nested |

### 3.5 New scripts (operational tooling; not in scope of CodeX Gate B recheck)

| File | Lines | Purpose |
|---|---|---|
| `scripts/prompt_monitor.ps1` | 143 | 5-minute polling daemon for `Prompt/` |
| `scripts/prompt_monitor_one_shot.ps1` | 96 | single-run variant |
| `scripts/check_monitor.ps1` | 8 | status helper |
| `scripts/restart_monitor.ps1` | 54 | restart-and-verify |
| `scripts/stop_monitor.ps1` | n/a | kill helper |

Per CodeX Round 017 §DEBT, monitor scripts may be in a separate commit. Not part of Gate B evidence.

### 3.6 Existing test infrastructure (unchanged)

| File | Lines | Status |
|---|---|---|
| `tests/_fake_su.rb` | 418 | extended: FakePoint3d, FakeTransformation, FakeVertex, FakeLayer, FakeComponentDefinition, FakeGroup, FakeComponentInstance, FakeSelection, FakeEntity (test_active_edit_context_facts adds FakeEntity) |
| `tests/runner.rb` | 192 | unchanged |
| `tests/run_all.rb` | 21 | unchanged |

---

## 4. TEST RESULTS

### 4.1 Full suite

```
$ .vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb
... 207 tests: 207 pass, 0 fail, 0 error ...
```

### 4.2 Test count progression

| Base | Cumulative | Delta | Source |
|---|---|---|---|
| 72 | 72 | — | Stage 2 final |
| 72 | 161 | +89 | Gate A core (`f68f4bd`) |
| 72 | 171 | +10 | Gate A rework (`8ddacda`) |
| 72 | 173 | +2 | Gate A v2 fix (`7110229`) |
| 72 | **207** | +34 | **Gate B host-side (`e755d8e`)** |

### 4.3 Gate B proofs (CodeX Round 014 §四)

| # | CodeX requirement | Proof | Test file / line |
|---|---|---|---|
| 1 | structural_depth from REAL `model.active_path` entity count, NOT filtered PID length | `edit_facts_fake_model([100, nil])` returns `structural_depth: 2` while `pid_path.length == 1` | `test_active_edit_context_facts.rb` "structural_depth != filtered PID length" |
| 2 | active-path completeness computed BEFORE nil PIDs are discarded | `raw_with_nil: [100, nil, 300]` preserves nil slots; `pid_path_complete` is false | `test_active_edit_context_facts.rb` "raw_with_nil preserves slot structure" |
| 3 | missing any active-path container PID → fail closed | `edit_facts_fake_model([nil, nil])` returns `complete: false`; `[:inst_path_unresolved]` diagnostic on resolver failure | `test_active_edit_context_facts.rb` + `test_issue_locator.rb` "unresolved inst_path produces a diagnostic" |
| 4 | incomplete nested source NEVER uses entityID fallback | `nested: true, complete: false` → `[:skip]` | `test_issue_locator.rb` "incomplete-nested -> :skip" + "incomplete-nested-partial-leaf -> :skip" |
| 5 | two tests required: complete active path + active path with one missing PID | "complete active path of 2 → depth 2, complete=true" + "2-container active path with one nil PID → depth 2, complete=false" | `test_active_edit_context_facts.rb` |

### 4.4 Lint (CodeX Round 012 NIT)

```
$ ruby tests/run_all.rb "no_host"
PASS  core_no_host_dependency: no file references Sketchup::
PASS  core_no_host_dependency: no file requires compatibility/ or extension/
PASS  core_no_host_dependency: no file references UI::, Geom::, or Sketchup.
PASS  core_no_host_dependency: lint covers expected files
--- 5 tests: 5 pass, 0 fail, 0 error ---
```

The lint scans every `core/*.rb` for `Sketchup`, `UI::`, `Geom::`, `compatibility/`, `extension/` references. **Zero hits** in Gate A and Gate B code.

### 4.5 Ruby 2.2.4 syntax compatibility

| Check | Result |
|---|---|
| `ruby -c core/*.rb` + `ruby -c extension/*.rb` | All 19 files: `Syntax OK` |
| `&.` (safe-navigation) | 0 in code (comments excluded) |
| `case-in` pattern matching | 0 |
| `frozen_string_literal` magic comment | 0 |
| `_1` / `_2` numbered parameters | 0 |
| `$ERROR_INFO` | 0 |
| `def foo() = expr` endless defs | 0 |
| `case var; in pattern; end` | 0 |

### 4.6 Test file rename for unique top-level helpers

CodeX Round 014 NIT about helper collisions: each test file now uses unique helper names (`reg_issue`, `ar_issue`, `group_issue`, `loc_issue`, `edit_facts_fake_model`, `issue_locator_fake_model`) to avoid cross-file top-level method collisions during `load`.

---

## 5. GIT DIFF SUMMARY

```
$ git diff --stat aeced98..HEAD
.gitignore                              |   3 +-
compatibility/su_capability.rb          | 143 ++++++++++----
core/analysis_result.rb                 |  60 ++++++
core/issue_enricher.rb                  | 216 ++++++++++++++++++++
core/issue_grouper.rb                   |  62 ++++++
core/issue_id_assigner.rb               |  91 +++++++++
core/issue_locator_policy.rb            |  95 +++++++++
core/issue_normalizer.rb                | 165 ++++++++++++++++
core/issue_registry.rb                  | 193 ++++++++++++++++++
core/source_reference.rb                |  51 +++--
core/structural_facts.rb                |  94 +++++++++
core/synthetic_factory.rb               |   9 +-
extension/analyzers_runner.rb           | 146 ++++++++++++++
extension/dialog_controller.rb          |  55 ++++++
extension/dialog_runner.rb              |  76 +++++++
extension/display_unit_formatter.rb     |  64 ++++++
extension/html/app.js                   | 102 ++++++++++
extension/html/index.html               |  20 ++
extension/html/style.css                | 107 ++++++++++
extension/issue_locator.rb              | 187 ++++++++++++++++++
extension/loader.rb                     |  81 ++++++++
extension/preflight_runner.rb           |  71 +++++--
extension/ui_bridge.rb                  |  91 +++++++++
scripts/check_monitor.ps1               |   8 +
scripts/prompt_monitor.ps1              | 143 ++++++++++++++
scripts/prompt_monitor_one_shot.ps1     |  96 +++++++++
scripts/restart_monitor.ps1             |  54 +++++
tests/test_active_edit_context_facts.rb | 106 ++++++++++
tests/test_analysis_result.rb           | 129 ++++++++++++
tests/test_core_no_host_dependency.rb   | 128 ++++++++++++
tests/test_display_unit_formatter.rb    |  66 +++++++
tests/test_issue_enricher.rb            | 339 ++++++++++++++++++++++++++++++++
tests/test_issue_grouper.rb             | 116 +++++++++++
tests/test_issue_id_assigner.rb         | 189 ++++++++++++++++++
tests/test_issue_locator.rb             | 180 +++++++++++++++++
tests/test_issue_locator_policy.rb      | 195 ++++++++++++++++++
tests/test_issue_normalizer.rb          | 129 ++++++++++++
tests/test_issue_registry.rb            | 214 ++++++++++++++++++++
tests/test_structural_facts.rb          | 155 +++++++++++++++
tests/test_ui_bridge.rb                 | 134 +++++++++++++
40 files changed, 4483 insertions(+), 80 deletions(-)
```

---

## 6. REAL SKETCHUP VERIFICATION NEEDS

Per `Q002=A` and `R004`, the Agent cannot run SketchUp. The Owner runs the
following before Gate B is accepted on a real host. The existing
`Review/OWNER_VERIFICATION_STAGE_6.txt` (5 steps J..N) is the canonical
checklist.

### 6.1 Recommended Gate B verification steps (Owner-driven)

1. **SU2020 + clean install** of the plugin in `%localappdata%\SketchUp\SketchUp 2020\SketchUp\Plugins\`.
2. **Run Owner Verification Stage 6** (J..N):
   - J. Plugin load smoke (no errors on SketchUp startup).
   - K. Plugin menu item "Analyze selection" appears once.
   - L. Click menu → HtmlDialog opens with summary + grouped sections.
   - M. Verify dynamic-edit invariants (CodeX Round 014 §1):
     - `model.active_path` length drives `structural_depth` directly.
     - For an active Group containing 2 entities, `structural_depth`
       increases by exactly 2.
     - For an active Group with one missing PID, source is
       non-locatable (no entityID fallback).
3. **Real-host locate test** (CodeX Round 014 §4):
   - Source a root-level Edge with missing PID → entityID fallback
     finds it via `model.find_entity_by_id`.
   - Source a nested Entity with missing PID → locator fails closed
     (no entityID fallback).
   - Source a shared ComponentDefinition with two occurrences →
     `InstancePath#root` returns the correct ComponentInstance.
4. **No-source-mutation test** (CodeX Round 005 §R003):
   - Run analyze, click multiple issues, verify `model.entities.length`
     unchanged via Ruby Console.
   - `Model Info → Statistics` shows no new entities / materials /
     layers.
5. **SU2017 minimum-host re-verification** (Gate B proof #1 re-checked
   on SU2017): required for SHIP but not for Gate B approval.

### 6.2 Owner Verification still pending

Per the project contract (Q002=A), the Owner runs the `OWNER_VERIFICATION_STAGE_6.txt` checklist. The AGENT DOES NOT ANNOUNCE THIS AS PASS.

---

## 7. KNOWN RISKS

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | Active-edit path may have ALL PIDs nil (every container lacks persistent_id) | Low | `pid_path_complete: false` propagates; issue is non-locatable; no entityID fallback for nested. Tested in `test_active_edit_context_facts.rb`. |
| 2 | FakeObject fingerprinted subclass detection in tests | Low | `FakeEntity` class defined in `test_active_edit_context_facts.rb` mirrors real SketchUp API shape (only `persistent_id` method). |
| 3 | `extension/issue_locator.rb` direct invocation when `model` is nil | Low | `find_entity_by_id` returns nil; `resolve_pid_path` returns nil; both surface as `:unresolved` with diagnostic. |
| 4 | `UI::HtmlDialog` may not be available on very old SketchUp versions | Low | DialogRunner returns nil; Owner sees a message box via Loader.show_dialog_for_selection with graceful fallback to UI.messagebox. |
| 5 | `Sketchup.format_length` may not be available on pre-SU2017 | Low | DisplayUnitFormatter fallback to deterministic "X.XXXX inch" format. |
| 6 | HtmlDialog `set_file` absolute path may fail if plugin is installed in a path with non-ASCII | Low | `File.expand_path('html/index.html', __dir__)` returns the same encoding; verified during Owner verification. |
| 7 | A malformed Issue from a future analyzer could break IssueRegistry | Low | `validate_issue!` raises `InvalidIssue`; constructor catches and pushes to diagnostics; builder continues. |
| 8 | `core/source_reference.rb` `entity_id` was required; now optional | Low | Synthetic factory updated; production callers in Gate B (analyzers_runner) set explicit `entity_id` from the source Edge. |
| 9 | R001/R002/etc. product decisions inadvertently changed | Low | All locked decisions are read-only in core/. No commit in `aeced98..e755d8e` changes `core/tolerance.rb`, `core/analysis_config.rb`, or the locked contract SemVer. |
| 10 | Stage 2 BLOCK-001..006 tests regressed | Low | `tests/test_preflight*.rb` and `tests/test_synthetic_*.rb` still present and pass; `git diff --stat` shows no change to those files. |

---

## 8. ROLLBACK POINTS

If a future CodeX review finds an issue that cannot be fixed in this commit, the rollback points are:

1. **Per-file rollback** via `git revert <commit>` then re-apply
   `aeced98..e755d8e` minus the failing file.
2. **Per-stage rollback** to the last verified base:
   - `git reset --hard 7110229` → keeps Gate A recheck v2 fix, drops Gate B
   - `git reset --hard 8ddacda` → keeps Gate A rework, drops Gate B + Round 016 fix
   - `git reset --hard f68f4bd` → keeps Gate A core, drops all Gate A rework + Gate B
   - `git reset --hard aeced98` → full rollback to Stage 2 final
3. **Per-file revert** within this commit:
   - `git checkout e755d8e -- extension/issue_locator.rb` — keep active-edit facts in `su_capability.rb` but restore old issue_locator if CodeX finds a bug there.

The full directory structure is preserved: `git stash` is not needed
because all changes are committed. The `data/_check_tmp/` directory is
gitignored; it's safe to delete at any time.

---

## 9. OWNER-LOCKED DIRECTIVE ABSORPTION (CodeX Round 017)

Per CodeX Round 017:
> *Pi Agent owns routine technical decisions.*
> *Batch related work and self-review locally.*
> *NIT/DEBT must not create a review loop.*
> *The next planned formal review is only after Gate B is complete
>  as one coherent, independently testable host-side integration milestone.*

This Gate B milestone is the planned formal review boundary. All
routine engineering decisions were resolved locally within Gate B:

- 6 shared test helper renames (`reg_issue`, `ar_issue`, `group_issue`,
  `loc_issue`, `edit_facts_fake_model`, `issue_locator_fake_model`)
  for unique top-level methods.
- Fail-closed default of `pid_path_complete: false` in `SourceReference`
  preserves backward compatibility.
- `Snapshot.edges` lookup in `IssueEnricher` matches the existing
  Stage 2 contract.
- `analyzers_runner.rb` runs exactly one snapshot per command (CodeX
  Round 010 BLOCK-002 v2).
- `dialog_runner.rb` uses BLOCK callbacks (not `method(:name)`), matches
  real SketchUp API.
- `extension/html/app.js` uses `textContent` / `setAttribute` only
  (no `innerHTML` for user-supplied strings).
- `Sketchup.format_length` is called in exactly one place.

No further CodeX review is filed in this commit. Owner Verification
Stage 6 is the next formal action.

---

## 10. LONG-TERM-AUTONOMY BOUNDARY COMPLIANCE

Per Cicada 2026-08-18 section 六:

- ✅ Does NOT change R001-R005 product decisions
- ✅ Does NOT expand product scope
- ✅ Does NOT add overlay / repair / source-model mutation
- ✅ Does NOT push / publish / release (local commit only)
- ✅ Does NOT skip Owner verification
- ✅ Does NOT fake SU2017 as SU2020 evidence
- ✅ Does NOT make irreversible decisions on Owner behalf

Per section 四:
- ✅ Gate A complete (CodeX Round 017 PASS)
- ✅ All Gate B tests pass (207/207)
- ✅ Ruby 2.2.4 compatibility verified
- ✅ Stable Git commit at `e755d8e`
- ✅ Complete Gate B evidence packet at `Review/GATE_B_MILESTONE_REVIEW_2026-08-18.md`

Per section 六 Owner Verification stop:
- ✅ After Gate B milestone + CodeX approval, STOP at Owner Verification Stage 6
- ✅ NOT advance to Stage 7 or IMPLEMENTATION REPORT
- ✅ NOT announce PASS FOR RELEASE

---

## 11. SUMMARY FOR CODEX

Stage 6 Gate B host-side integration is complete as one coherent
independently testable milestone. All Gate B CodeX-required invariants
(Round 014 §1-5) are proven by tests. The previous formal review
(CodeX Round 017) closed Gate A and authorized Gate B. This packet
is the deliverable that satisfies CodeX Round 017's directive.

CodeX reviews:
1. **compatibility/su_capability.rb** — `active_edit_context_facts`
   returns 5 facts; `find_entity_by_id` fails closed.
2. **extension/preflight_runner.rb** — walk tracks structural_depth +
   pid_path_complete through ancestry → leaf.
3. **extension/issue_locator.rb** — 6 Profile resolutions + diagnostics.
4. **extension/analyzers_runner.rb** — one snapshot per command.
5. **extension/loader.rb / dialog_runner.rb / dialog_controller.rb /
   ui_bridge.rb** — UI contract; Symbol → JSON String boundary.
6. **extension/html/** — render + click handler; no `innerHTML` for
   user strings; **BLOCK-006** selectors `UI::HtmlDialog` only.
7. **tests/test_active_edit_context_facts.rb** — Gate B proof #1, #2.
8. **tests/test_issue_locator.rb** — Gate B proof #4, #3.
9. **tests/test_ui_bridge.rb / test_display_unit_formatter.rb** —
   JS boundary + unit formatting.

After Gate B PASS:
- → Owner Verification Stage 6 (5 steps J..N), then wait.
- → SU2017 minimum-host verification (separate release Gate per R004).
- → No Stage 7 / IMPLEMENTATION REPORT until Owner releases.

AGENT AWAITS CODEX GATE B MILESTONE REVIEW VERDICT.
