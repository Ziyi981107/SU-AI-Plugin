# CURRENT PI REPORT — V17-AIPM-DIRECT-SOURCE-REREVIEW-FIX

Project: `SU-AI-Plugin`
Version: V1.7
Stage: V17 DIRECT-SOURCE-REREVIEW-FIX COMPLETE /
AWAITING AIPM FINAL DIRECT SOURCE RE-REVIEW (NOT yet V1.7
CLOSED; mandatory Codex xHigh integration review + final
Owner SU2020 real-host verification gate remain.)
Dispatch: `V17-AIPM-DIRECT-SOURCE-REREVIEW-FIX-2026-09-01`
Prior Dispatch: `V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01`
Dispatcher / Technical Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
AIPM direct source RE-review (the corrections this dispatch
addresses):
`Review/CURRENT_AIPM_REVIEW.md`
Frozen V1.6 Closure Anchor:
`Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md`
Branch: `dev/v1.7`
Source of Truth: `extension/su_ai_plugin/` + canonical contracts in
`PROJECT_HANDOFF` + `PROJECT_MASTER_PLAN_V1X`.

---

## 0. Scope (per dispatch §0)

This is a **frozen-Blueprint bounded direct-source-REREVIEW
correction packet**. AIPM direct source RE-review of the
prior V17-AIPM-DIRECT-SOURCE-REVIEW-FIX packet found FIVE
BLOCKs (RR-01..RR-05) requiring host-operation close,
host-endpoint fail-closed, restored host-mutation suite, exact
canonical pre/post validation, and order-independent node
collapse corrections.

This dispatch:

- corrected all five RR findings with REAL production-path
  evidence;
- preserved every prior RR-01..RR-07 + SR-01..SR-07 + R5..R8
  regression;
- restored the accidentally-collapsed
  `tests/test_v17_host_mutation.rb` H1..H7 suite (RR-03);
- did NOT redesign V1.7;
- did NOT invent new repair types;
- did NOT silently widen Source of Truth or tolerance
  semantics;
- did NOT invoke Codex;
- did NOT start V1.8;
- did NOT claim V1.7 closure;
- did NOT run Owner verification;
- did NOT touch the V1.6 backend, the V1.5 BLOCK-005 path,
  or the V1.4 derived-workspace architecture.

---

## A. RR-01..RR-05 disposition

| ID | Finding | Disposition | Evidence |
|----|---------|-------------|----------|
| RR-01 | POST-VALIDATION FAILURE DOES NOT ABORT THE HOST OPERATION: `_confirmed_abort` did NOT actually call `adapter.end_operation(commit: false)`. A real SketchUp operation could remain open. | CORRECTED — `GapBridgeExecutor.apply` now tracks `operation_started` (set only after `begin_operation` returns without raising). Every exit path reaches exactly one of confirmed commit, confirmed abort, or close-uncertainty state. The new `_confirmed_abort` makes the SINGLE `adapter.end_operation(model, commit: false)` call and returns `:abort_completed` or `:abort_uncertain`. Confirmed abort -> new `:failed` workspace from `pre_workspace`, zero generated logical bridge record survives. Abort raises -> `:failed` uncertainty, current generated handles retained for explicit Discard. No nested cleanup operation. | `extension/su_ai_plugin/core/gap_bridge_executor.rb` (`apply` `operation_started` track + new `_confirmed_abort` returning `:abort_completed` / `:abort_uncertain`); `tests/test_v17_host_mutation.rb` `V17-H3` (begin=1, abort=1, commit=0, workspace :failed, source unchanged) + `V17-H4` (commit_uncertainty + abort closes the operation truthfully). |
| RR-02 | HOST ENDPOINT POST-VALIDATION IS NOT FAIL-CLOSED AND USES THE WRONG EPSILON: missing `edge_endpoints` / `vertex_position` capabilities, nil handles, raised/nil position reads were silently skipped. Hardcoded `1.0e-5` epsilon used instead of the proposal's `coordinate_epsilon`. | CORRECTED — `_post_validate` now fails closed on every missing capability / nil handle / nil-or-raised position read. Uses the proposal's own `coordinate_epsilon` (no hardcoded fallback). Undirected segment matching (host may report A,B OR B,A). Stable reason codes: `host_endpoint_handles_unavailable:<pid>`, `host_endpoint_handles_malformed:<pid>`, `host_endpoint_position_unavailable:<pid>`, `host_endpoint_position_unreadable:<pid>`, `host_endpoint_epsilon_missing:<pid>`, `host_endpoint_segment_mismatch:<pid>`. | `gap_bridge_executor.rb` (`_post_validate` block (C)); `tests/test_v17_production_gap_path.rb` `V17-RR02-A` (missing capability), `V17-RR02-B` (nil handles), `V17-RR02-C` (raising vertex_position), `V17-RR02-D` (nil vertex_position), `V17-RR02-E` (5e-6 perturbation exceeds proposal 1e-6 epsilon), `V17-RR02-F` (reversed host order passes). |
| RR-03 | `tests/test_v17_host_mutation.rb` WAS ACCIDENTALLY COLLAPSED: the file was physically collapsed into one line beginning with `#`; the prior H1..H7 tests were not being executed even though the global suite was green. | CORRECTED — file restored from pre-dispatch `2cdebb234f004c6980eb737c364274b4a568e8f7` with newlines preserved (CRLF -> LF cleanup). H1, H2, H4, H5, H6, H7 remain active. H3 updated to inject failure into the `create_top_level_group` primitive that `workspace.build_entity` calls (the actual production path), asserting begin=1, abort=1, commit=0 + workspace :failed + source unchanged. | `tests/test_v17_host_mutation.rb` (restored + H3 failure injection moved to `create_top_level_group`); V17-H1..H7 re-discovered + active in the full suite; fresh test counts confirm +7 tests are now actually running. |
| RR-04 | CANONICAL POST-VALIDATION H/K USE APPROXIMATIONS: (H) `total post gap_bridge count == current batch applied count` falsely failed when a pre-existing gap bridge was present. (K) had no pre-batch non_transitive baseline; only checked for clusters referencing an applied endpoint key. | CORRECTED — `WorkingModeRunner.apply_gap_repair` now captures the EXACT pre-batch canonical baseline BEFORE the executor apply: (1) existing `gap_bridge` repair_action_id set, (2) non_transitive cluster signatures (sorted endpoint_keys). `_canonical_post_validate` then compares exactly: every current-batch proposal_id -> exactly one canonical `gap_bridge` edge with that repair_action_id; pre-existing gap_bridges are allowed; `post_sigs - pre_sigs` MUST be EMPTY. | `working_mode_runner.rb` (new `_current_gap_bridge_action_ids`, `_current_non_transitive_signatures`, `_non_transitive_signature`, `v17_tolerance` helpers; updated `_canonical_post_validate` with `pre_batch_gap_bridge_action_ids` + `pre_batch_non_transitive_sigs` kwargs; `apply_gap_repair` now captures baseline before `GapBridgeExecutor.apply`); `tests/test_v17_production_gap_path.rb` `V17-RR04-A` (prior bridge + new bridge -> PASS), `V17-RR04-B` (unchanged pre-existing cluster -> PASS), `V17-RR04-C` (genuinely new cluster -> FAIL), `V17-RR04-D` (baseline capture hooks). |
| RR-05 | SR-07 REPRESENTATIVE NODE COORDINATE PAIRS SORTED KEYS WITH UNSORTED COORDINATES: `_collapse_nodes_by_id` stored `endpoint_keys` and `world_coordinates` separately, then zipped unsorted coords against sorted keys. Shuffled input order could bind the wrong coordinate to the lex-smallest key. | CORRECTED — `_collapse_nodes_by_id` now stores LINKED MEMBER RECORDS (one Hash per input member, NOT separate parallel arrays). Members are sorted by `endpoint_key`; every aggregate field is derived from these same linked records. Representative `world_coordinate` = the ACTUAL `world_coordinate` of the lex-smallest `endpoint_key` member (no averaging, no zip-mixing). Forward / reversed / shuffled input orders all yield the same logical node payload + representative coord + graph digest. | `canonical_geometry_graph.rb` (`_collapse_nodes_by_id` rewritten to use linked member records); `tests/test_v17_production_gap_path.rb` `V17-RR05` (forward / reversed / shuffled members -> identical payload + rep coord + digest). |

---

## B. Production code changed (per dispatch §B)

| File | Change | Why |
|------|--------|-----|
| `extension/su_ai_plugin/core/gap_bridge_executor.rb` | RR-01: new `operation_started` flag tracked only after `begin_operation` returns without raising. `_confirmed_abort` now makes the SINGLE `adapter.end_operation(model, commit: false)` call and returns `:abort_completed` / `:abort_uncertain`. New `REASON_ABORT_UNCERTAIN` constant + `_abort_uncertain_audit` builder. Rescue branch distinguishes commit uncertainty from abort uncertainty. Post-validate failure path now branches on `_confirmed_abort` outcome: abort_completed -> confirmed-abort return new :failed workspace; abort_uncertain -> preserve current handles + record `abort_uncertainty`. RR-02: `_post_validate` block (C) rewritten to fail closed on missing capability / nil handle / nil-or-raised position read. Uses proposal's own `coordinate_epsilon`. Undirected segment matching. Stable reason codes emitted. | RR-01 + RR-02 |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | RR-04: new `_current_gap_bridge_action_ids`, `_current_non_transitive_signatures`, `_non_transitive_signature`, `v17_tolerance` helpers. `_canonical_post_validate` now accepts `pre_batch_gap_bridge_action_ids` + `pre_batch_non_transitive_sigs` kwargs and checks current-batch bridges (not total) + `post_sigs - pre_sigs` must be empty. `apply_gap_repair` captures baseline BEFORE `GapBridgeExecutor.apply` and passes it through. | RR-04 |
| `extension/su_ai_plugin/core/canonical_geometry_graph.rb` | RR-05: `_collapse_nodes_by_id` rewritten to store linked member records (NOT separate parallel arrays). Members sorted by `endpoint_key`; every aggregate field derived from these same linked records. Representative `world_coordinate` = the actual coordinate of the lex-smallest endpoint_key member (no averaging, no zip-mixing). Forward / reversed / shuffled input orders all yield identical payload + rep coord + digest. | RR-05 |
| `tests/test_v17_host_mutation.rb` | RR-03: restored from pre-dispatch `2cdebb2` with newlines (CRLF -> LF cleanup for git diff --check). H1, H2, H4, H5, H6, H7 remain active. H3 updated to inject failure into `create_top_level_group` (the actual production primitive behind `workspace.build_entity`); asserts begin=1, abort=1, commit=0 + workspace :failed + source unchanged. H4 stub delegates to `original_end` for abort so the abort genuinely records in the FakeAdapter operation_log. | RR-01 + RR-03 |
| `tests/test_v17_production_gap_path.rb` | RR-02: SR2-2 and SR3-1 ready_entry extended to include `coordinate_epsilon` + `expected_bridge_endpoints` (required by the new RR-02 fail-closed contract). SR3-5 expectation broadened to accept either `repair_action_id_not_in_canonical` or `canonical_bridge_count_mismatch` (the RR-04 current-batch check). NEW: V17-RR02-A..F (RR-02 six-test suite). NEW: V17-RR04-A..D (RR-04 four-test suite). NEW: V17-RR05 (forward/reversed/shuffled order independence). | RR-02 + RR-04 + RR-05 |

All changes are LOCAL to the V1.7 frozen contract:

- tolerance semantics unchanged (`coordinate_epsilon` / `gap_search`
  unchanged; the executor's check now USES the proposal's
  `coordinate_epsilon` instead of a hardcoded fallback);
- Source of Truth unchanged;
- Source-of-CAD immutability unchanged;
- gap repair type unchanged (still `endpoint_bridge`);
- cross-layer / curve / face / Z / crossing uncertainty
  unchanged;
- non-transitive cluster handling unchanged;
- canonical `origin_kind` enum unchanged (`gap_bridge`);
- no V1.8 Loop / Region / face semantics introduced;
- no Observer architecture added;
- V1.6 close auto-discard preserved (no regression);
- V1.5 BLOCK-005 validate-on-next-interaction preserved (no
  regression);
- V1.4 derived-workspace architecture preserved (no
  regression).

---

## C. RR-01 operation-trace evidence (per dispatch §1)

`tests/test_v17_host_mutation.rb`:

- **V17-H1** (preflight fail) -> zero `begin_operation`. No
  operation ever opens.
- **V17-H2** (success) -> 1 begin + 1 commit. No abort.
- **V17-H3** (group-creation failure on first bridge) ->
  begin=1, abort=1, commit=0; workspace `:failed`; source
  unchanged. (RR-01 contract.)
- **V17-H4** (commit uncertainty) -> 1 begin + 1 abort + 0
  commits; workspace `:failed`; reason `commit_uncertainty`.
- **V17-H5** (post-state mismatch) -> `:failed`; reason
  `preflight_failed` (preflight rejects duplicate endpoints).
- **V17-H6** (source fingerprint unchanged) -> `:applied`;
  workspace `:ready`; source fingerprint unchanged.
- **V17-H7** (source-edge coords unchanged) -> pre-world
  snapshot identical to post-world snapshot for every
  pre-existing source-derived edge.

---

## D. RR-02 host-endpoint fail-closed evidence (per dispatch §2)

`tests/test_v17_production_gap_path.rb`:

- **V17-RR02-A** (missing `edge_endpoints` capability via
  singleton `respond_to?` override) -> post-validate FAILS
  with `host_endpoint_handles_unavailable:<pid>`.
- **V17-RR02-B** (`edge_endpoints` returns `[nil, nil]`) ->
  post-validate FAILS with `host_endpoint_handles_malformed:<pid>`.
- **V17-RR02-C** (`vertex_position` raises) -> post-validate
  FAILS with `host_endpoint_position_unreadable:<pid>`.
- **V17-RR02-D** (`vertex_position` returns `nil`) ->
  post-validate FAILS with `host_endpoint_position_unreadable:<pid>`.
- **V17-RR02-E** (5e-6 host perturbation, proposal epsilon
  1e-6) -> post-validate FAILS with
  `host_endpoint_segment_mismatch:<pid>`. The 5e-6 delta is
  INSIDE the legacy 1e-5 hardcoded tolerance but OUTSIDE the
  proposal's 1e-6 epsilon. RR-02 contract verified.
- **V17-RR02-F** (reversed host order (end, start)) ->
  post-validate PASSES (undirected segment match accepted).

---

## E. RR-03 host-mutation-suite restoration (per dispatch §3)

- Pre-dispatch commit `2cdebb2`'s
  `tests/test_v17_host_mutation.rb` was 428 lines.
- Post-SR-correction commit `b2b08bd` accidentally collapsed
  the file to one line (15,680 bytes but 0 newlines). Ruby
  treated it as one giant comment and H1..H7 were not
  running.
- Restored from `2cdebb2` -> 428 lines + newlines preserved.
- H3 re-purposed to inject failure into
  `create_top_level_group` (the actual production primitive
  that `workspace.build_entity` calls) so the test exercises
  the current production path.
- Fresh total: **939 tests PASS** (was 921 pre-RR-03; +7 from
  the previously-disabled H1..H7 + +6 RR-02 + +4 RR-04 +
  +1 RR-05 + +1 RR-04-D baseline-capture = +18 new tests
  after the dispatch landed).

---

## F. RR-04 canonical pre/post evidence (per dispatch §4)

`tests/test_v17_production_gap_path.rb`:

- **V17-RR04-A** (prior `prior-gap-001` bridge present +
  new `current-gap-002` bridge) -> canonical post-validate
  PASSES (pre-existing bridge allowed; new bridge maps 1:1
  to the batch's applied proposal_id).
- **V17-RR04-B** (unchanged pre-existing non_transitive
  cluster signature `kA|kB|kC`) -> canonical post-validate
  PASSES (post signatures - pre signatures is EMPTY).
- **V17-RR04-C** (genuinely new cluster `kX|kY|kZ` not in
  pre-batch baseline) -> canonical post-validate FAILS with
  `new_non_transitive_cluster_introduced:1`.
- **V17-RR04-D** (baseline capture hooks return `[]` when no
  workspace is set) -> hooks are deterministic and
  shape-stable.

---

## G. RR-05 order-independence evidence (per dispatch §5)

`tests/test_v17_production_gap_path.rb`:

- **V17-RR05** (3 members supplied forward `kA,kB,kC` ->
  reversed `kC,kB,kA` -> shuffled `kB,kA,kC`) -> all three
  reconstructions yield:
  - exactly ONE logical node;
  - `endpoint_keys` == `['kA','kB','kC']`;
  - `derived_edge_ids` == `['eA','eB','eC']`;
  - `source_occurrence_ids` == `['occ-a','occ-b','occ-c']`;
  - `layer_names` == `['L0','L1']`;
  - `membership_count` == 3;
  - representative `world_coordinate` == `[1.0, 2.0, 3.0]`
    (the ACTUAL coordinate of the `kA` member, not the
    average and not the zip-mismatched coord);
  - `graph.digest` identical across all three orderings.

---

## H. Complete V1.7 test matrix (per dispatch §7)

| Blueprint / RR | Test | File | Status |
|----------------|------|------|--------|
| §18.1 N1..N6 | V17-N1..N6 | test_v17_topology_identity.rb | PASS |
| §18.1 N5b | V17-N5b | test_v17_topology_identity.rb | PASS |
| §18.2 G1..G10 | V17-G1..G10 | test_v17_gap_pairing.rb | PASS |
| §18.3 X1..X4 | V17-X1..X4 | test_v17_branch_crossing.rb | PASS |
| §18.3 X1..X4 (PRODUCTION PATH) | V17-X1..X4 [PRODUCTION PATH] | test_v17_production_gap_path.rb | PASS |
| §18.4 H1..H2 | V17-H1, V17-H2 | test_v17_host_mutation.rb | PASS |
| §18.4 H3 (build_entity failure) | V17-H3 (RR-03 restored) | test_v17_host_mutation.rb | PASS |
| §18.4 H3 (multi-bridge batch, PRODUCTION PATH) | V17-H3 [PRODUCTION PATH] | test_v17_production_gap_path.rb | PASS |
| §18.4 H4 (commit uncertainty) | V17-H4 (RR-01 fixed abort) | test_v17_host_mutation.rb | PASS |
| §18.4 H5..H7 | V17-H5, V17-H6, V17-H7 | test_v17_host_mutation.rb | PASS |
| §18.5 T1..T7 | V17-T1..T7 | test_v17_canonical_graph.rb | PASS |
| §18.5 T3..T4 (PRODUCTION PATH) | V17-T3, V17-T4, V17-T4-EXACT3 [PRODUCTION PATH] | test_v17_production_gap_path.rb | PASS |
| §18.6 L1..L4 | V17-L1..L4 | test_v17_canonical_graph.rb | PASS |
| §18.7 P1..P3 | V17-P1..P3 | test_v17_performance.rb | PASS |
| §15.1 origin_kind translation | V17-OK-MAP-1, -2 | test_v17_branch_crossing.rb | PASS |
| RR-01 (operation truthful close) | V17-H3, V17-H4 | test_v17_host_mutation.rb | PASS |
| RR-02 (host endpoint fail-closed) | V17-RR02-A..F | test_v17_production_gap_path.rb | PASS |
| RR-03 (suite restoration) | V17-H1..H7 + V17-H3 [PRODUCTION PATH] | test_v17_host_mutation.rb, test_v17_production_gap_path.rb | PASS |
| RR-04 (exact pre/post canonical) | V17-RR04-A..D | test_v17_production_gap_path.rb | PASS |
| RR-05 (order-independence) | V17-RR05 | test_v17_production_gap_path.rb | PASS |
| R5 (prior packet) | V17-R5-REG-LAYER, FROZEN, CLUSTER | test_v17_production_gap_path.rb | PASS |
| R6 (prior packet) | V17-R6-NODE-IDENTITY | test_v17_production_gap_path.rb | PASS |
| SR-01 (prior packet) | V17-SR1-1..4 | test_v17_production_gap_path.rb | PASS |
| SR-02 (prior packet) | V17-SR2-1..4 | test_v17_production_gap_path.rb | PASS |
| SR-03 (prior packet) | V17-SR3-1..5 | test_v17_production_gap_path.rb | PASS |
| SR-04 (prior packet) | V17-SR4-1..3 | test_v17_production_gap_path.rb | PASS |
| SR-05 (prior packet) | V17-SR5-1 | test_v17_production_gap_path.rb | PASS |
| SR-06 (prior packet) | V17-SR6-1 | test_v17_production_gap_path.rb | PASS |
| SR-07 (prior packet) | V17-SR7-1..4 | test_v17_production_gap_path.rb | PASS |

---

## I. Prior-stage regressions + RBZ (per dispatch §7)

- **V16 close-autodiscard** (V16-CLOSE-AUTODISCARD): 7/7 PASS
  (no regression).
- **V15 host-state / BLOCK-005** (V15): 149/149 PASS (no
  regression).
- **LEGACY-COMPAT**: 4/4 PASS (no regression).
- **RBZ smoke** (`tests/test_rbz_smoke.rb`): 9/9 PASS
  (post-rebuild).
- **Node DOM** (`tests/test_html_render_dom.js`): PASS
  (V17-UI1..UI4 topology-repair Simplified Chinese cards).
- **`git diff --check`**: clean.

---

## J. RBZ identity (per dispatch §7)

Rebuilt via `scripts/build_rbz.rb` after the RR-01..RR-05
production fixes landed:

- **Path**: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- **Size**: 949,575 bytes
- **Entries**: 67
- **SHA-256**:
  `3D97401433DBEE666E97681C18BF33E16E4AB267ADC334DCFBABB72F93BCCD08`
- **`su_ai_plugin.rb`** at RBZ root (entry-point convention
  OK).
- **`su_ai_plugin/`** support folder (sibling of entry-point).
- All V1.7 production files shipped (verified by
  `test_rbz_smoke.rb`).
- Frontend asset trio (`html/{index.html, app.js, style.css}`)
  shipped and byte-identical to in-tree source (no JS-side
  change in this dispatch).
- `tests/`, `scripts/`, `Review/`, `Prompt/`, `.vendor/`,
  `.git/` dev-only paths excluded (rbz_smoke verified).

---

## K. Fresh test counts (per dispatch §8)

| Subset | Pre-RR-03 / pre-this-dispatch | Post-this-dispatch |
|--------|-------------------------------|---------------------|
| V1.7 Ruby tests (X*, N*, G*, T*, L*, P*, H*, SR*, V17-OK-MAP*) | 71 | 71 (existing) + 18 new (H1..H7 unblocked + RR-02 x6 + RR-04 x4 + RR-05 x1) = 89 |
| V15 host-state (BLOCK-005) | 149 | 149 (unchanged) |
| V16 close-autodiscard | 7 | 7 (unchanged) |
| LEGACY-COMPAT | 4 | 4 (unchanged) |
| dialog_runner | 29 | 29 (unchanged) |
| All other V1.0-V1.6 | 626 | 626 (unchanged) |
| RBZ smoke | 9 | 9 (unchanged) |
| TOTAL | 921 | **939** (all PASS, 0 fail, 0 error) |

This dispatch reports **fresh exact counts**, not the
mechanically-reused 921.

---

## L. Git facts (per dispatch §9)

- **Starting HEAD (pre-this-dispatch)**: `2f45a20`
  (the prior V17-AIPM-DIRECT-SOURCE-REVIEW-FIX doc-stamp
  commit).
- **Closed V1.6 base SHA**: `d7e9c59` (V1.6
  CLOSE-AUTODISCARD).
- **V17 substantive implementation HEAD**: `e98326e`
  (preserved from prior packet; this dispatch is a
  correction packet on top).
- **Prior SR-correction SHA**: `b2b08bdd` (the
  V17-AIPM-DIRECT-SOURCE-REVIEW-FIX production commit).
- **Final HEAD on `dev/v1.7`**: see `git rev-parse HEAD` after
  the RR-01..RR-05 correction commits land; the doc-stamp
  commit is the last commit on the assigned branch.
- **Working tree (this dispatch, pre-commit)**: 3 modified
  production files + 2 modified test files. Dispatch + Review
  protocol files modified by AIPM remain unstaged (Pi does
  not own those files).
- **`git diff --check`**: clean.
- **Local commits created (this dispatch)**: one production
  commit (RR-01..RR-05 corrections + tests) + one doc-stamp
  commit (CURRENT_STATE update + CURRENT_PI_REPORT overwrite).

---

## M. Remaining defects / assumptions / unknowns (per dispatch §8)

### Confirmed defects (this dispatch)

None. All five RR findings are corrected; the 18 new RR
regression tests are green; the full Ruby suite + RBZ smoke +
V16 close-autodiscard + V15 host-state + LEGACY-COMPAT + Node
DOM are all green; `git diff --check` is clean.

### Assumptions (require AIPM direct source review or Owner
SU2020 confirmation)

- The new `_confirmed_abort` makes the SINGLE
  `adapter.end_operation(model, commit: false)` call. If
  real SketchUp's `Model#abort_operation` raises when the
  model has no open operation, the executor's rescue branch
  records `:abort_uncertain` and the workspace transitions
  to `:failed` with reason `abort_uncertainty`. The current
  handles are preserved so explicit Discard can clean any
  host entity that may still exist.
- The runner-side baseline capture helpers
  (`_current_gap_bridge_action_ids`,
  `_current_non_transitive_signatures`) rebuild the canonical
  graph TWICE per `apply_gap_repair` call (once before
  executor apply for baseline, once after for post-validate).
  For typical V1.7 real-scale CAD the rebuild is O(V + E)
  expected and remains well within the V1.7 Blueprint §11
  performance budget; Owner Scenario A confirms end-to-end
  latency.
- The plural `source_occurrence_ids` field is the V1.8
  authority; the singular `source_occurrence_id` is preserved
  for backwards compatibility. V1.8 must consume the plural
  field.
- The canonical_node_count in the published metrics is
  computed AT THE GRAPH CONSTRUCTOR boundary (after
  SR-07 collapse). The topology snapshot's `metrics` Hash
  still carries the per-endpoint builder counts; the GRAPH
  finalizes the canonical_node_count before publication.
- The runner's `_canonical_post_validate` runs AFTER the host
  commit AND after the canonical graph rebuild. If canonical
  post-validation fails after commit, the workspace
  transitions to `:failed` with stable reason
  `canonical_post_validation_failed`; handles are retained
  for Discard; NO fake rollback is claimed. The
  RUNNER-level audit is updated to `status=failed` +
  `reason=canonical_post_validation_failed`.

### Unknowns (require real SketchUp 2020 evidence)

- Whether real SketchUp's `Model#abort_operation` fully rolls
  back all entities created in the operation when the
  executor's `_confirmed_abort` path fires (Blueprint §12.3).
  V1.7's BLOCK-005 inheritance provides the
  validate-on-next-interaction fallback (workspace
  transitions to `:failed` with `host_state_changed`), but
  real-host evidence is required.
- Whether the bridge-endpoint host_vertex_handle resolution
  via `edge_endpoints` returns the same world coordinates on
  real SU as the source-edge endpoints within
  `coordinate_epsilon`. The new RR-02 fail-closed
  post-validation rejects any drift > `coordinate_epsilon`;
  the Owner Scenario A end-to-end is the canonical evidence.

### Owner-only

- Real human approval of the V1.7 UI (Scenario A's primary
  product feature: "发现 1 个可安全修复的间隙").
- Acceptance that Scenario F demonstrates the BLOCK-005
  inheritance is sufficient.
- Final experience-freeze decision (this is an `Owner Gate`,
  not a Pi or AIPM decision).

---

## N. Mandatory review state (per dispatch §8)

```
CODEX_GATE: STILL PENDING
OWNER_GATE: NOT YET RUN
V1.8: NOT STARTED
```

Justification:

- The V1.7 Blueprint §13 declares the canonical Codex xHigh
  integration review mandatory for V1.7.
- This dispatch corrected the RR-01..RR-05 findings but V1.7
  is NOT ready for Codex until AIPM FINAL direct source
  RE-review (this report's owner) reaches PASS.
- After AIPM PASS, the dispatch lifecycle continues with
  Codex xHigh integration review (per the V1.7 Blueprint's
  mandatory review strategy).
- Pi did NOT invoke Codex at any point in this dispatch.
- Pi does NOT claim AIPM PASS. AIPM records the final
  Accepted / Downgraded / Rejected adjudication of any findings.

The Owner shall run the Blueprint §19 scenarios A through G
on real SketchUp 2020 once AIPM direct source RE-review
reaches PASS and Codex xHigh integration review also reaches
  PASS.

---

## O. Definition of done (per dispatch §8 + §10)

- [x] RR-01 corrected (`_confirmed_abort` actually closes
      the host operation; `operation_started` tracked;
      `:abort_completed` / `:abort_uncertain` outcomes;
      `:failed` workspace on confirmed abort; handles
      retained for Discard on abort uncertainty).
- [x] RR-02 corrected (host endpoint post-validation fails
      closed; uses proposal's `coordinate_epsilon`;
      undirected segment match; stable reason codes).
- [x] RR-03 corrected (`tests/test_v17_host_mutation.rb`
      restored from pre-dispatch; H1..H7 active; H3 updated
      to current production `create_top_level_group` path;
      begin=1, abort=1, commit=0 asserted in H3).
- [x] RR-04 corrected (canonical pre/post validation uses
      exact pre-batch baseline; pre-existing gap_bridges
      allowed; `post_sigs - pre_sigs` must be EMPTY).
- [x] RR-05 corrected (linked member records in
      `_collapse_nodes_by_id`; representative coord = actual
      coord of lex-smallest endpoint_key member; forward /
      reversed / shuffled input orders yield identical
      payload + rep coord + graph digest).
- [x] 18 new RR-01..RR-05 regression tests added (dispatch
      §9).
- [x] Prior-stage regressions + RBZ smoke green (939/939).
- [x] `git diff --check` clean.
- [x] RBZ rebuilt (949,575 bytes / 67 entries / SHA-256
      `3D97401433DBEE666E97681C18BF33E16E4AB267ADC334DCFBABB72F93BCCD08`).
- [x] `CODEX_GATE: STILL PENDING` recorded in §N.
- [x] `OWNER_GATE: NOT YET RUN` recorded in §N.
- [x] `V1.8: NOT STARTED` recorded in §N.
- [x] No claim of AIPM PASS / Codex PASS / Owner PASS.
- [x] `main` not pushed / merged.
- [x] No force-push / rebase / shared-history rewrite.

---

## P. Push plan (per dispatch §9)

After green:

- ONE normal `git push origin dev/v1.7`.
- No force, no rebase, no `main` merge/push, no tag/release.
- Report remote HEAD and STOP.

---

## STOP and return control to AIPM.

Next Gate: AIPM FINAL direct source RE-review of the corrected
V1.7 packet.

Only after AIPM primary PASS: mandatory Codex xHigh integration
review.

End of report.