# V1.5 Round-4 BLOCK Fix — Pi Review Packet

Date: 2026-08-27
Author: Pi (Implementation)
Dispatcher: ChatGPT / AIPM
Status: COMPLETE — AWAITING AIPM REVIEW (no Codex recheck request from Pi)
Frozen design authority:
  - `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`
  - `Prompt/PI_TASK_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`

---

## 1. Branch / Base / Head

| | |
|--|--|
| Branch | `v1.5-stage-round3-fix` |
| Governance-migration base HEAD | `43854c879a1c1fcb57bcd2bea7743c02e73d0c05` |
| Round-2 base | `7283a830c0eb8979ad5c78ced30d8cffc790bc75` |
| Round-3 implementation commit | `5ac83ea` |
| Round-3 documentation | `fae3518` (recheck packet), `6f5df97` (state), `43854c8` (final report) |
| Current Round-4 implementation HEAD | `c5e5ec7db88cae8262e13c1e6629f12b07f4241e` (local stable checkpoint, NOT pushed) |

Working tree (this Round-4 fix):
- Modified: 7 tracked files (`AGENTS.md` + 6 V1.5 core files), 1 test file
- New (untracked before commit): 2 helper modules + 2 Prompt artefacts + `PI_START_HERE.md`
- `AGENTS.md` change: governance migration to V3.1 project contract (carried over from the pre-fix state)

---

## 2. Changed files (Round-4 diff vs governance-migration base)

### 2.1 Modified files

| Path | Lines (diff) |
|--|--|
| `AGENTS.md` | governance migration |
| `extension/su_ai_plugin/core/analyzers/duplicate_detector.rb` | Round-4 BLOCK-002A — shared `DuplicateGeometrySemantics.enumerate_candidates` |
| `extension/su_ai_plugin/core/derived_duplicate_topology.rb` | Round-4 compatibility shim → `DuplicateGeometrySemantics` + Round-4 BLOCK-002B topology decision |
| `extension/su_ai_plugin/core/derived_duplicate_validator.rb` | Round-4 BLOCK-002A/BLOCK-004 — shared semantics + pure top-state measurement |
| `extension/su_ai_plugin/core/duplicate_repair_executor.rb` | Round-4 BLOCK-001 / BLOCK-003 / BLOCK-004 — preflight, expected post-state, capture-tolerance propagation |
| `extension/su_ai_plugin/core/duplicate_repair_proposer.rb` | Round-4 BLOCK-001 / BLOCK-002B / BLOCK-004 — final repairable-component eligibility proof + non-transitive skip + basis-kind derivation |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | Round-4 BLOCK-004 summary carries accurate `duplicate_pairs_after` via the shared `DuplicateGeometrySemantics` |
| `tests/test_v15_duplicate_repair.rb` | Round-4 contract updates to V15-13 and V15-B003-5 |

### 2.2 New files (this Round-4 fix)

| Path | Purpose |
|--|--|
| `extension/su_ai_plugin/core/duplicate_geometry_semantics.rb` | Round-4 BLOCK-002A shared `DuplicateGeometrySemantics` (single source of truth for finite/tolerance/layer normalization, `direct_match?`, candidate enumeration, pair enumeration) |
| `extension/su_ai_plugin/core/duplicate_repair_expected_post_state.rb` | Round-4 BLOCK-003 pure-data expected post-state builder + invariant validator |
| `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md` | AIPM frozen design (read-only) |
| `Prompt/PI_TASK_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md` | AIPM dispatched task (read-only) |
| `PI_START_HERE.md` | Pi current-task pointer (per V3.1 governance) |
| `Review/V1_5_ROUND4_BLOCK_FIX_RECHECK_PACKET_2026-08-27.md` | This packet |

### 2.3 `git diff --check`

- `git diff --check HEAD`: clean (no whitespace errors).
- `git diff --check` (working tree vs index): clean.

---

## 3. Implementation map — BLOCK-001..004

### 3.1 BLOCK-001 — Final action eligibility / live-handle proof

Where:
- `core/duplicate_repair_proposer.rb#verify_final_repairable_component` —
  the FINAL repairable-component eligibility proof runs against
  EVERY repairable component BEFORE any executable action is
  emitted. Failure ⇒ a truthful `:skipped` audit row with a
  stable reason code (`REASON_HANDLE_ALIAS`,
  `REASON_HANDLE_MISSING`, `REASON_HANDLE_INVALID`,
  `REASON_AMBIGUOUS_RESOLUTION`, `REASON_NON_DISTINCT_SOURCE`,
  `REASON_NON_FINITE_COORDS`, `REASON_INCOMPLETE_PROVENANCE`).
- `core/duplicate_repair_executor.rb#preflight_batch` +
  `apply_atomic` — re-check the live-handle proof on each
  action IMMEDIATELY before opening the host operation.

What is checked:
1. every member has one distinct `derived_id`;
2. every member resolves to one unambiguous current source-edge
   identity for V1.5 action membership (full leaf identity,
   `pid_path_complete=true`);
3. every member has a current host handle in the workspace;
4. every handle is live/valid (`valid? == true`);
5. every handle is distinct (`equal?` comparison);
6. survivor handle and removal handles are disjoint;
7. member identity/provenance belongs to the current
   `SourceSnapshot` (the `edge_lookup` is built from the
   snapshot, so this is a current-snapshot check);
8. layer / tolerance / finite-coordinate guards pass
   (the shared `DuplicateGeometrySemantics.valid_tolerance?`
   validates the captured tolerance is `Float > 0`);
9. no repeated/aliased member exists
   (`derived_id` uniqueness + source-edge resolution +
   live-handle uniqueness).

### 3.2 BLOCK-002A — Complete tolerance candidate enumeration

Where: `core/duplicate_geometry_semantics.rb` (new)
- `DuplicateGeometrySemantics.enumerate_candidates(records, tolerance)`
  for `tolerance > 0`:
  - cell size = captured tolerance;
  - mathematical floor per axis: `floor(coord / cell)`;
  - every record indexed under BOTH endpoint cells (with `A==B`
    dedup);
  - cell index inverted `cell_key -> Array<record_index>`;
  - for each record, query all 27 neighboring cells around
    endpoint A and around endpoint B;
  - candidate set = union + dedup of index hits;
  - final authority = the shared `direct_match?`;
  - pair dedup by stable unordered `(i, j)` index tuple.
- Tolerance == 0 path: exact pair lookup via the same algorithm
  (cell size == 0 still works mathematically; the production
  pipeline never reaches it when captured tolerance is set).
- Negative / non-finite tolerance: `valid_tolerance?` returns
  `false`; `enumerate_candidates` raises `ArgumentError`. The
  proposer / executor treat the captured tolerance as an explicit
  value — there is NO silent fallback to historical `1e-4`.

Consumption: `core/derived_duplicate_topology.rb`,
`core/analyzers/duplicate_detector.rb`,
`core/derived_duplicate_validator.rb`,
`core/duplicate_repair_proposer.rb`,
`core/duplicate_repair_expected_post_state.rb`,
`core/working_mode_runner.rb` all flow through
`DuplicateGeometrySemantics`.

### 3.3 BLOCK-002B — Non-transitive topology

Where: `core/derived_duplicate_topology.rb#classify_components`
- Build the direct-match adjacency graph for the candidate
  scope under the captured tolerance.
- For each connected component with `N >= 2`:
  - **Repairable component**: ONLY if `direct_pair_count ==
    N * (N - 1) / 2` (COMPLETE GRAPH).
    - Emit exactly ONE action with deterministic survivor =
      lex-smallest `derived_id`; removal set = the other
      members; provenance union = deterministic sorted union.
  - **Non-transitive / incomplete component**:
    - Emit NO destructive action for any sub-clique
      (Bron-Kerbosch / maximal-clique enumeration is REMOVED
      from the destructive-action path; the helper is retained
      only for diagnostic use).
    - Emit ONE inspectable `:skipped` audit row with reason
      `non_transitive_duplicate_component`; preserve member
      IDs, issue IDs, source/provenance evidence.
    - Geometry unchanged.

The proposer's pipeline (`core/duplicate_repair_proposer.rb`)
emits the `:skipped` non-transitive rows BEFORE the final
eligibility proof runs on repairable components.

### 3.4 BLOCK-003 — Complete expected post-state before host mutation

Where: `core/duplicate_repair_expected_post_state.rb` (new)
- Pure-data expected post-state builder. Mandatory fields:
  - `tolerance` (captured, explicit)
  - `pre_inventory_ids` (sorted)
  - `post_inventory_ids` (sorted)
  - `removed_derived_ids` (sorted, unique)
  - `survivor_derived_ids` (sorted, unique)
  - `survivor_provenance_unions` (Hash<survivor_id, sorted
    source_occurrence_ids union>)
  - `post_geometry` (Hash<derived_id, geometry summary Hash>)
  - `post_fingerprint` (SHA-256 of canonical post-state)
  - `survivor_handles`, `removal_handles` (disjoint by
    `equal?`)
  - `duplicate_pairs_before`, `duplicate_pairs_after`
    (measured via `DuplicateGeometrySemantics.count_direct_pairs`)
  - `applied_action_ids`, `applied_component_membership`
  - `unresolved_skipped_component_ids`
- `DuplicateRepairExpectedPostState.validate!` checks the
  invariants A..H listed in `AIPM_TECHNICAL_GUIDANCE §5`.

Where: `core/duplicate_repair_executor.rb#apply_batch_atomic`
- BUILDS the expected post-state via
  `DuplicateRepairExpectedPostState.build` BEFORE opening the
  host operation.
- If `expected_post['valid'] == false` => rollback path,
  every action `:failed`, `begin_calls = 0`.
- The published workspace is the precomputed pure-data one
  (after the host commit); the executor does NOT re-derive
  the post-state after commit. A successful commit means the
  expected post-state was already proven consistent in pure
  data BEFORE the host operation opened.

### 3.5 BLOCK-004 — Audit truth and tolerance propagation

- **Captured tolerance** flows through:
  `execution_config.tolerance_values[:duplicate]` ->
  `DuplicateGeometrySemantics.resolve_captured_tolerance` ->
  detector / proposer / expected-post-state / validator /
  audit metrics / UI summary. NO silent fallback to historical
  defaults.
- **Final audit rows** preserve applied / skipped / failed
  status with:
  - `action/component_id`
  - stable reason code (`REASON_*`, including the new
    `REASON_NON_TRANSITIVE_COMPONENT`)
  - `issue_ids`
  - affected derived IDs
  - survivor ID (where applicable)
  - source / provenance evidence
  - captured tolerance
  - before / after evidence
- **Executor output** does NOT filter away pre-execution
  skipped actions. `apply_batch` returns
  `updated_actions + pre_skipped`. The runner's summary
  builder (`build_duplicate_repair_summary`) re-emits every
  pre-execution `:skipped` row that the executor may not
  echo back, using the per-action `audit_row_for` helper.
- **Pair metric** is the AIPM §6 definition:
  `duplicate_pairs_before / duplicate_pairs_after` =
  count of `UNIQUE UNORDERED` derived-edge pairs that satisfy
  the shared forward/reversed `direct_match?` under the
  CAPTURED duplicate tolerance, measured via
  `DuplicateGeometrySemantics.count_direct_pairs`. NOT a
  surrogate from `removed_ids.length - 1`,
  `affected_derived_ids.length`, or any clique metric.
- **READY semantics**: workspace `:ready` MAY coexist with
  truthful `:skipped` ambiguous components. Workspace `:ready`
  MUST NOT coexist with an applied action whose expected
  post-state failed, host/logical divergence, invalid
  handle proof, a remaining direct duplicate pair belonging
  to an APPLIED repairable component, or a failed batch
  invariant.

### 3.6 BLOCK-005 — One authoritative Owner verification path

Per AIPM §7, Pi does NOT write the authoritative Owner
verification file. Pi provides the evidence prerequisites
below in §10; AIPM publishes the canonical checklist
(`Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`)
after this packet is reviewed.

---

## 4. BLOCK-001..005 evidence prerequisites

### 4.1 BLOCK-001 — live-handle proof

Verified by `V15-B001-1..B001-5`, `V15-13` (whole-component
skip under Round-4 contract).

### 4.2 BLOCK-002A — complete tolerance candidate enumeration

Verified by `V15-B002-1..B002-4` (rounding-boundary,
just-outside, non-transitive, reversed-edge cases). The
detector flow exercises the same algorithm in
`V15-B002-1` (the V1.1 layer test now detects duplicates
again — see §11 unresolved limitations for the regression
history).

### 4.3 BLOCK-002B — non-transitive topology

Verified by `V15-B002-3`, `V15-B002-5`. The complete-graph
condition (`direct_pair_count == N*(N-1)/2`) is exercised
by `V15-3` (3 identical edges → 1 action, 1 survivor).

### 4.4 BLOCK-003 — expected post-state

Verified by `V15-B003-1..B003-5`:
- `B003-1`: preflight failure → `begin_calls = 0`
- `B003-2`: success → exactly one `begin`, one `commit`,
  zero `abort`
- `B003-3`: commit failure → workspace `:failed`, no
  fabricated rollback
- `B003-4`: dispose/precommit mismatch → abort,
  `commit_calls <= 1`, no second `end_operation(commit: false)`
- `B003-5`: injected validator mismatch →
  `begin_calls = 0`, every action `:failed`, workspace
  NOT `:ready`

### 4.5 BLOCK-004 — audit truth and tolerance propagation

Verified by `V15-B004-1..B004-5`, plus the Round-3 CodeX 032
recheck tests. The captured tolerance (e.g. `1.0e-3`,
`delta = 5.0e-4`) is exercised by `V15-B004-2`.

### 4.6 BLOCK-005 — Owner verification path (evidence prerequisites)

Pi provides:
- final branch: `v1.5-stage-round3-fix`
- final implementation HEAD: see §13 commit SHA
- final RBZ path/size/entries/SHA-256: see §11
- exact production observation paths: see §12
- supported Ruby Console commands: see §12
- FakeSU / production-call-chain evidence:
  `tests/test_v15_production_call_chain.rb`,
  `tests/test_v15_real_preflight_path.rb`
- G1/G3/Undo/recovery behavior evidence:
  `tests/test_v15_duplicate_repair.rb`
  (`V15-10`, `V15-11`, `V15-12`, `V15-14`,
   `V15-O`, `V15-P`)
- exact UI fields exposed to Owner: see §12
- known host limitations: see §14

---

## 5. Focused regression results

Targeted Round-4 BLOCK regressions (V15-B00x series):

| Test | Status |
|--|--|
| `V15-B001-1` | PASS |
| `V15-B001-2` | PASS |
| `V15-B001-3` | PASS |
| `V15-B001-4` | PASS |
| `V15-B001-5` | PASS |
| `V15-B002-1` | PASS |
| `V15-B002-2` | PASS |
| `V15-B002-3` | PASS |
| `V15-B002-4` | PASS |
| `V15-B002-5` | PASS |
| `V15-B003-1` | PASS |
| `V15-B003-2` | PASS |
| `V15-B003-3` | PASS |
| `V15-B003-4` | PASS |
| `V15-B003-5` | PASS |
| `V15-B004-1` | PASS |
| `V15-B004-2` | PASS |
| `V15-B004-3` | PASS |
| `V15-B004-4` | PASS |
| `V15-B004-5` | PASS |

Total Round-4 BLOCK regressions: **20/20 PASS**.

Plus the existing V15-1..V15-14, V15-DET-*, V15-WMR-*,
V15-RA-*, V15-SANITY, V15-F/L/M, V15-E/I/O/P/Q/Q-UI/P
regressions: all **PASS** (see §6 for the full count).

---

## 6. Full V1.5 suite

```
targeted filter: V15
PASS=65  FAIL=0  ERROR=0  TOTAL=65
```

Every V1.5 test in the suite passes. The V15-2 (reversed
exact duplicate) regression that surfaced during the crash
recovery was the basis_kind propagation issue in
`core/duplicate_repair_proposer.rb#provisional_action`:
the basis_kind was hardcoded `:forward`. The Round-4 fix
introduces `repairable_component_basis_kind`, which derives
the actual basis kind from the geometric relationship between
the survivor and the next-lexical member.

The V15-13 regression — Round-4 BLOCK-001 supersedes the
old "invalid handle is filtered silently" contract. The test
is now an authoritative assertion that an invalidated member
handle fails the ENTIRE component as `:skipped` (NOT a
partial apply). The new contract is documented in
`V15-13` and matches AIPM §2 verbatim.

---

## 7. Full Ruby suite

```
targeted filter: (none — full suite)
PASS=729  FAIL=0  ERROR=0  TOTAL=729
```

729/729 PASS. No regressions. No errors. No tests skipped.

---

## 8. Node DOM suite

```
node tests/test_html_render_dom.js
ASSERT-final-line PASS=164  FAIL=0  ERROR=0
```

The single trailer `PASS` line counts as a final summary.
Per-assertion passing count: **163** (the trailer increments
to 164 because of the `PASS` summary line itself). All
Dialog / DOM tests pass.

---

## 9. git diff --check

```
$ git diff --check HEAD
(empty — clean)

$ git diff --check
(empty — clean)
```

No whitespace errors in either the tracked vs HEAD diff or
the working tree diff. No CR/LF bleed, no trailing
whitespace, no merge-marker leakage.

---

## 10. Final RBZ facts

```
Path:      D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz
Size:      599,997 bytes
Entries:   59
SHA-256:   3D255BD5F6304440AD0C5030C8B52EEFA722CC0A27795B7F18F261DDAB0DE1BA
Build cmd: .vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe scripts/build_rbz.rb
```

The new Round-4 helper modules
(`duplicate_geometry_semantics.rb`,
`duplicate_repair_expected_post_state.rb`) are now shipped
inside the RBZ. The previous Round-3 RBZ (`596,443 bytes`,
57 entries) had these files missing; the rebuild is required
and is now complete.

RBZ smoke tests (in `tests/test_rbz_smoke.rb`):

| Smoke check | Status |
|--|--|
| Package is a valid PKZip archive | PASS |
| Entry-point at `.rbz` root | PASS |
| Dialog asset trio (`index.html`, `app.js`, `style.css`) shipped | PASS |
| Support folder named `su_ai_plugin/` containing `main.rb` | PASS |
| Dev-only paths (`tests/`, `scripts/`, `Review/`, etc.) excluded | PASS |
| Every required source file from the dev tree is shipped | PASS |
| Install smoke: extract, all `.rb` files parse | PASS |
| Install smoke: extracted entry-point boots through FakeUI; menu registered; `on_analyze_selection` no-op fallback | PASS |

The RBZ is **not approved for Owner installation** until AIPM
publishes the authoritative Owner verification file (BLOCK-005)
and the next Codex narrow recheck passes.

---

## 11. Exact production observation paths AIPM needs for the Owner checklist

These are the live code seams the Owner will exercise
directly in SketchUp. Each one is already covered by an
automated regression in `tests/`.

### 11.1 G1: prepare + observe workspace state

Command (Ruby Console):

```ruby
# Replace the @current_workspace state in the runner via the
# native dialog path. The UI is the user-facing path; the
# Ruby Console is the explicit Owner path for V1.5.
require 'su_ai_plugin/main'
SUAnalysis::Core::WorkingModeRunner.reset_for_tests
ar = SUAnalysis::Extension::AnalyzersRunner.run(
  Sketchup.active_model.selection, model: Sketchup.active_model
)
SUAnalysis::Core::WorkingModeRunner.prepare(
  source:  ar.respond_to?(:source_snapshot) ? ar.source_snapshot : nil,
  adapter: SUAnalysis::Extension::SUDerivedWorkspaceAdapter.new,
  model:   Sketchup.active_model
)
SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(
  registry: ar.respond_to?(:registry) ? ar.registry : nil
)
puts SUAnalysis::Core::WorkingModeRunner.snapshot
```

Coverage: `tests/test_v15_production_call_chain.rb`
(`V15PC-003`, `V15PC-005`, `V15PC-006`, `V15PC-007`).

### 11.2 G2: dialog-driven apply

Coverage: `tests/test_v14_runtime_block_004.rb`,
`tests/test_dialog_runner.rb` (existing V1.4 layer).
The dialog path invokes `WorkingModeRunner.prepare` and
`run_duplicate_repair_batch` via BLOCK callbacks.

### 11.3 G3: discard + undo

Command (Ruby Console):

```ruby
SUAnalysis::Core::WorkingModeRunner.discard
puts SUAnalysis::Core::WorkingModeRunner.snapshot
# expected: state == "discarded"
Sketchup.undo
```

Coverage: `tests/test_v15_duplicate_repair.rb`
(`V15-12` rebuild after apply), `tests/test_v15_production_call_chain.rb`
(`V15PC-010` Discard after batch). The undo path
relies on SketchUp's `Model.start_operation / commit /
abort` boundaries the executor uses (verified by
`tests/test_v14_runtime_block_004.rb`).

### 11.4 Recovery evidence (per AIPM §6, READY semantics)

`V15-B003-1..B003-5` cover the complete pre-host
validation chain. They are pure-Ruby tests of the
executor + post-state module, not full SketchUp
integration. The production call-chain test
`V15PC-008` (N-th dispose failure rolls back all
prior actions) is the existing real-host-faithful
recovery seam.

### 11.5 Exact UI fields exposed to Owner

The dialog's "Working Mode" section renders (via
`app.js#renderWorkingMode`):

- Source snapshot ID + fingerprint digest
- Execution-config digest
- Workspace ID
- State (one of `none`, `building`, `ready`,
  `discarded`, `failed`)
- Entity count
- Last error (when `:failed`)
- Duplicate-repair summary (when populated):
  - `duplicate_pairs_before`
  - `duplicate_pairs_after`
  - `actions_applied`, `actions_skipped`, `actions_failed`
  - `last_action_status`
  - `duplicate_classes_before`, `duplicate_classes_after`
  - `derived_edge_count_before`, `derived_edge_count_after`
  - `actions` (per-action audit rows with
    `action_id`, `status`, `removed_count`,
    `survivor_derived_id`, `source_occurrence_count`,
    `source_occurrence_ids`, `issue_ids`,
    `before_summary`)
- V1.5 BLOCK-004: per-action audit rows carry
  `data-action-id`, `data-action-status`,
  `data-survivor-id` plus the cell values above
  (asserted by the Node DOM test).

Coverage: `tests/test_html_render_dom.js` (all V15
ASSERT rows).

---

## 12. Known host limitations

1. **Ruby 2.7.8 baseline.** The project targets SU2017+
   via Ruby 2.2+ compat (no `&.` safe navigation, no
   `case ... in` pattern matching). See the locked
   `DANGER 7a/b` regression tests.
2. **FakeSU / production-adapter parity.** The
   `tests/test_v15_production_call_chain.rb` suite
   exercises the production `SUDerivedWorkspaceAdapter`
   path against `FakeUI::FakeModel`; this is the closest
   Owner-replacement for a real SU host without invoking
   the Extension Manager. The Round-4 BLOCK-001..004
   evidence is gathered against this seam.
3. **SU2017 evidence gap.** The project vendored Ruby is
   2.7.8; SU2017 ships with Ruby 2.2-2.4 on the legacy
   path. No automated fixture can dispatch Ruby 2.2
   implementations without rewriting the project's toolchain.
   Formal SU2017 verification remains the Owner's
   responsibility, gated by the published AIPM Owner
   checklist (BLOCK-005).
4. **Subset-filter test isolation.** The
   `V14-RUNTIME-BLOCK-004: Working Mode state is :failed`
   test fails when run via the `BLOCK-00` filter only
   (i.e., a specific subset of tests leave the
   `WorkingModeRunner.@current_workspace` module state
   set). The same test passes in isolation and within the
   full suite (`729/729 PASS`). This is a pre-existing
   module-state isolation issue unaffected by Round-4
   changes; it surfaced only because the previous run
   streamed a different subset. Documented here for
   transparency; should be addressed by introducing a
   per-test `WorkingModeRunner.reset_for_tests` setup
   (out of Round-4 scope).

---

## 13. Local checkpoint commit

A local stable checkpoint commit has been recorded at
SHA `c5e5ec7db88cae8262e13c1e6629f12b07f4241e` :

```
fix(v1.5-stage4-block-recheck): CodeX BLOCK-001..005
narrow-scope fixes (round 4)
```

Commit scope (16 files changed, 4157 insertions, 2508 deletions):
- 4 modified tracked files (governance + state):
  `AGENTS.md`, `CURRENT_STATE.md`, `tests/test_v15_duplicate_repair.rb`,
  plus `.gitignore` (added `.pi/`, `.codex/`, `dist/` exclusions).
- 6 modified V1.5 core files: detector, topology, validator,
  proposer, executor, working_mode_runner.
- 2 new helper modules: `duplicate_geometry_semantics.rb`,
  `duplicate_repair_expected_post_state.rb`.
- 5 new authority / record files (NOT silently executable):
  `PI_START_HERE.md`, two Prompt authority artefacts, the
  Round-4 Review packet, and the `.gitignore` update.

NOT pushed. NOT reviewed by Codex. NOT approved for
Owner installation. AIPM review + Codex recheck are
the next gates per `PROJECT_MASTER_PLAN_V1X.md §13`
and `PI_START_HERE.md`.

---

## 14. Unresolved issues (explicit, for AIPM)

1. The `V14-RUNTIME-BLOCK-004: Working Mode state is :failed`
   test pre-existing isolation issue (§12 item 4). Not a
   regression from Round-4.
2. The Round-4 contract change to `V15-13` (invalid
   member handle fails the whole component) is
   intentionally stricter than the V1.5 Round-3 behavior.
   Reviewer / Codex may want to confirm whether existing
   Owner checklists reference the old "filtered silently"
   contract; if so, AIPM should republish the Owner
   checklist to match.
3. SU2017 host verification remains a manual Owner gate.
   No automated Ruby 2.2 fixture is in scope for Round-4.

---

## 15. Required next actions (Pi → AIPM)

Pi is STOPPED.

Per `PI_START_HERE.md §6` and `Prompt/PI_TASK_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`:

1. AIPM reviews this packet.
2. AIPM publishes the canonical Owner verification file
   `Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`.
3. AIPM dispatches the next Codex narrow recheck.

Pi does NOT:
- ask Owner to install the RBZ,
- ask Owner to run Ruby Console,
- ask Codex for recheck,
- begin V1.6,
- select another task automatically.

End of Round-4 Pi packet.
