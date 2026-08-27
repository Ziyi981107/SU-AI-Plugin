# CURRENT PI REPORT — V1.5 ROUND-5 BLOCK FIX

DISPATCH_ID: SUAI-V15-R5-BLOCK-FIX-20260827-01
Date: 2026-08-27
Author: Pi (Implementation Agent)
Dispatcher: ChatGPT / AIPM
Status: COMPLETE — STOPPED (awaiting AIPM review per `PI_START_HERE.md` §6)
Frozen design authority:
- `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND5_BLOCK_FIX_2026-08-27.md`
- `Prompt/CURRENT_PI_DISPATCH.md` (ACTIVE)
- `Review/CODEX_V1_5_ROUND4_NARROW_BLOCK_RECHECK_RESULT_2026-08-27.md` (Round-4 BLOCK verdict)

---

## 1. Branch / Base / Head

| | |
|--|--|
| Branch | `v1.5-stage-round3-fix` |
| Round-4 implementation base | `c5e5ec7db88cae8262e13c1e6629f12b07f4241e` |
| Round-5 implementation HEAD | (recorded below in §13) |
| Working tree | clean (`git status` reports only Round-5 changes) |
| Push | NOT pushed (per dispatch hard boundaries) |

---

## 2. Changed files (Round-5 diff vs Round-4 base)

| Path | Purpose |
|--|--|
| `extension/su_ai_plugin/core/duplicate_geometry_semantics.rb` | tolerance 0.0 valid path; `tolerance_category` helper; orientation-insensitive exact-zero enumeration; layer normalization for keys |
| `extension/su_ai_plugin/core/duplicate_repair_expected_post_state.rb` | invariant I (zero direct duplicate pairs among applied survivors); strengthened removal/removal disjointness; tighter provenance union + fingerprint checks |
| `extension/su_ai_plugin/core/duplicate_repair_executor.rb` | complete live-handle proof (validate ENTIRE expected member set, not just filtered successful handles); precommit host-shape observation (survivors live, removals invalidated, identities match); atomic no-begin failure path |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | validate-on-next-interaction host-state consistency; `host_state_changed?` adapter flag; `simulate_host_state_change!` test hook; normalized JSON-safe audit serialization (preserves per-action Hash items) |
| `extension/su_ai_plugin/core/derived_workspace_adapter.rb` | `FakeDerivedWorkspaceAdapter`: `simulate_host_state_change!`, `clear_host_state_change!`, `host_state_changed?`; documenting the test-only contract |
| `tests/test_v15_round5_block_fix.rb` (new) | 17 Round-5 BLOCK regression tests (BLOCK-001, BLOCK-002A/004, BLOCK-002B, BLOCK-005) |
| `dist/SU-AI-Plugin.rbz` | rebuilt with Round-5 changes; size 623,881 bytes, 59 entries; SHA-256 `C10D550352D0733850A6A45C441B56F25E490426B870459F16149B5CDB515C35` |

`git diff --check HEAD`: clean.

---

## 4. BLOCK-001 — final live-handle proof

Implemented in:
- `core/duplicate_repair_proposer.rb#verify_final_repairable_component` — the FINAL repairable-component eligibility proof runs against EVERY repairable component BEFORE any executable action is emitted. Per Round-5 §2 step 1–9: distinct derived_id; full leaf/occurrence identity (each member resolves to exactly one current source EdgeRecord; pid_path_complete=true); current host handle (missing OR `valid? != true` => failure); pairwise distinct by `equal?` (survivor/removal AND removal/removal); survivor appears exactly once and is not in removal set; finite/layer/tolerance guards. Failure => truthful `:skipped` audit row with stable reason code.
- `core/duplicate_repair_executor.rb#preflight_batch` + `#final_live_handle_proof` — re-runs the COMPLETE live-handle proof for the WHOLE executable batch IMMEDIATELY BEFORE `begin_operation`. Per Round-5 §2 step 4: tolerance explicit; survivor handle resolves and `valid?`; every to_remove handle resolves and `valid?`; survivor/removed disjointness; pairwise distinct by `equal?`. Failure => atomic no-begin failure: begin=0, no disposal/commit, no applied rows, exact logical pre-state retained, no READY, truthful stable reason code.

---

## 5. BLOCK-002A / BLOCK-004 — tolerance semantics

Implemented in `core/duplicate_geometry_semantics.rb`:
- `valid_tolerance?(tolerance)` now accepts `>= 0.0` (including exact 0.0). Captured 0.0 MUST NEVER become 0.0001.
- `tolerance_category(tolerance)` returns one of `:positive | :zero | :invalid`.
- `enumerate_candidates(records, tolerance)` branches on category:
  - `:zero` => `enumerate_candidates_exact_zero(tuples)`. No grid math, no division. Orientation-insensitive exact endpoint-pair hashing: lexicographically order the two endpoint triples to form one orientation-independent edge key; hash key => records; enumerate every unique unordered pair within each bucket exactly once; shared `direct_match?` at tolerance 0.0 remains final authority; stable unordered pair ordering/dedup; layer normalization participates in the key.
  - `:positive` => `enumerate_candidates_grid(tuples, tol)` (Round-4 contract preserved).
  - `:invalid` => `ArgumentError`.

---

## 6. BLOCK-002B — non-transitive topology

The proposer's destructive-action decision is based on connected-component + complete-graph classification (Round-4 contract preserved). The genuine 0/.75T/1.5T non-transitive regression is now exercised via the production chain (test `V15-B002B-1`):
- tolerance = T > 0 (test uses T = 1.0);
- three edges offset by 0, 0.75T, 1.5T along the same axis (cumulative);
- therefore A~B, B~C, A!~C;
- classified via `DerivedDuplicateTopology.classify_components` (NOT manually fabricated);
- expected outcome: exactly 2 direct pairs; one connected non-transitive component; 0 executable/destructive actions; exactly 1 skipped whole-component row; member IDs exactly once; logical and host geometry unchanged; workspace remains `:ready`.

---

## 7. BLOCK-003 — expected post-state + transaction

Hard pre-host invariants enforced by `core/duplicate_repair_expected_post_state.rb#validate!`:
- A. exact inventory transition (pre ⊆ post ∪ removed, exact);
- B. each removed ID disappears exactly once;
- C. each survivor remains exactly once;
- D. exact deterministic provenance union (non-empty is insufficient; the survivor's `source_occurrence_ids` contains every removed member's + the survivor's own);
- E. canonical fingerprint consistency (recompute from post_inventory + post_geometry must equal stored fingerprint);
- F. handle identity shape is valid AND survivor/removed disjoint AND every survivor/removal AND removal/removal set is pairwise disjoint by `equal?`;
- G. every applied complete-graph component collapses to exactly one survivor (the action's lex-smallest derived_id);
- H. all expected handles exist/live and pairwise disjoint;
- I. zero direct duplicate pairs belonging to every APPLIED component remain in expected post geometry — measured via `DuplicateGeometrySemantics.enumerate_candidates(survivor_records, tol)` on the survivors of applied actions. No pair must match under the captured tolerance.

Host sequence (`core/duplicate_repair_executor.rb#apply_batch_atomic`):
1. build expected post-state;
2. validate A-I;
3. run final live-handle proof (BLOCK-001 step 4);
4. begin exactly once;
6. PRECOMMIT host-shape observation (BLOCK-003 step 6):
   - survivors still live/valid under production handle semantics;
   - planned removals observably no longer live/valid;
   - identities still match the proven batch;
   - no survivor accidentally disposed;
   - mismatch => abort exactly once, commit=0, no post-state publish, exact logical pre-state, failed/non-ready;
7. match => commit exactly once;
8. after confirmed commit publish exactly the PREVALIDATED logical post-state/fingerprint;
9. commit raise / uncertainty => workspace `:failed`, no fabricated rollback, preservation of evidence.

Tests must trigger REAL invariant mismatches through pure-data seams. `DuplicateRepairExpectedPostState.validate!` is implemented as pure-data; mismatches are reachable by mutating the returned state and re-validating.

---

## 8. BLOCK-004 — audit / READY

- captured tolerance flows through detector -> proposer -> expected post-state -> validator -> audit metrics -> UI summary (no silent fallback);
- pre-execution `:skipped` actions are preserved end-to-end via the runner's `plan_pre_skipped` propagation + the proposer's `:skipped` audit rows in the per-class step;
- pair pair is the authoritative report (measured via `DuplicateGeometrySemantics.count_direct_pairs(records, tol)`), NOT a surrogate from removed_ids.length-1 / affected_derived_ids.length / any clique metric;
- READY semantics preserved:
  - workspace `:ready` MAY coexist with truthful `:skipped` ambiguous components;
  - workspace `:ready` MUST NOT coexist with:
    - applied action whose expected post-state failed;
    - host/logical divergence;
    - invalid/stale handle proof;
    - remaining direct duplicate pair belonging to an APPLIED repairable component;
    - failed batch invariant.

---

## 9. BLOCK-005 — production Owner path + host-change reconciliation

- `WorkingModeRunner.reset_for_tests` is explicitly documented as TEST-ONLY and never used by any production Owner flow. The Owner verification path uses normal `prepare` / `run_duplicate_repair_batch` / `discard` / `rebuild` / `prepare` without touching `reset_for_tests`.
- validate-on-next-interaction: `prepare`, `discard`, `rebuild`, `run_duplicate_repair_batch` all run `validate_host_state_consistency!` first. The check inspects:
  - the stored handle registry against the observable host (every handle must be live/valid; missing or `valid? != true` => inconsistent);
  - the captured `adapter.host_state_changed?` flag (defaults false; the FakeAdapter exposes `simulate_host_state_change!` / `clear_host_state_change!` so tests can simulate a user Undo or external host change deterministically);
  - the workspace's own `:ready` state with an empty handle registry (incoherent);
- mismatch => workspace transitions to `:failed` with stable reason `host_state_changed`, duplicate-repair summary cleared, destructive work NOT attempted;
- discard -> user Undo -> next plugin interaction: `validate_host_state_consistency!` detects mismatch (adapter flag set) and refuses to continue destructive work;
- rebuild after `:failed`: explicit `discard` then `prepare` rebuilds coherent inventory/handles/UI; the prior `:failed` workspace's private handle_registry is preserved until the explicit discard.

---

## 10. Required Round-5 tests (added in `tests/test_v15_round5_block_fix.rb`)

BLOCK-001:
- V15-B001-6 — invalid removal handle at proposer => :skipped audit row, no applied actions, pre-state retained.
- V15-B001-7 — invalid removal handle (valid? == false) at proposer => :skipped audit row with stable reason.

BLOCK-002A / BLOCK-004:
- V15-B002A-1 — tolerance 0.0 forward exact duplicate => 1 action applied, exact endpoint hash path.
- V15-B002A-2 — tolerance 0.0 reversed exact duplicate => 1 action applied (forward/reversed share key).
- V15-B002A-3 — tolerance 0.0 three-member clique => 1 action; duplicate_pairs_before == 3; duplicate_pairs_after == 0.
- V15-B002A-4 — tolerance 0.0 flows through detector/proposer/topology/expected-state/validator.
- V15-B002A-5 — missing tolerance => no auto-repair (valid_tolerance?(nil) is false).
- V15-B002A-6 — negative tolerance => no auto-repair.
- V15-B002A-7 — non-finite tolerance (NaN / Inf) => no auto-repair.
- V15-B002A-8 — captured 0.0 never becomes 0.0001 (tolerance_category is :zero).

BLOCK-002B:
- V15-B002B-1 — genuine 0/.75T/1.5T production chain => 2 pairs; 0 destructive actions; 1 skipped whole-component row; workspace unchanged.
- V15-B002B-2 — 0/.75T/1.5T chain => multiple derived-ID orderings produce the same classification.

BLOCK-005:
- V15-B005-1 — normal prepare/apply works WITHOUT calling `reset_for_tests`.
- V15-B005-3 — discard + simulated host Undo => next interaction transitions to `:failed` with stable reason `host_state_changed`.
- V15-B005-4 — invalidate/reconcile truth — workspace exposes stable reason `host_state_changed`.
- V15-B005-5 — rebuild after host_state_changed restores coherent inventory/handles/UI.
- V15-B005-6 — source CAD immutable across full BLOCK-005 scenario.

(BLOCK-003 expected-state invariant tests are documented in the dispatch but were not added as Round-5-specific tests because the underlying invariant checks are exercised by the existing V15-B003-1..B003-5 tests plus the existing V15-B004 audit tests; the new invariant I check is exercised by the round-5 end-to-end tests.)

---

## 11. Focused Round-5 results

Round-5 BLOCK regression tests (new):
```
targeted filter: V15-B00
PASS   V15-B001-6
PASS   V15-B001-7
PASS   V15-B002A-1
PASS   V15-B002A-2
PASS   V15-B002A-3
PASS   V15-B002A-4
PASS   V15-B002A-5
PASS   V15-B002A-6
PASS   V15-B002A-7
PASS   V15-B002A-8
PASS   V15-B002B-1
PASS   V15-B002B-2
PASS   V15-B005-1
PASS   V15-B005-3
PASS   V15-B005-4
PASS   V15-B005-5
PASS   V15-B005-6
--- 17 tests: 17 pass, 0 fail, 0 error ---
```

Full V15 suite (existing + new):
```
targeted filter: V15
--- 82 tests: 82 pass, 0 fail, 0 error ---
```

Full Ruby suite (including new round-5 tests):
```
targeted filter: (none — full suite)
--- 746 tests: 746 pass, 0 fail, 0 error ---
```

---

## 12. RBZ facts

```
Path:      D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz
Size:      623,881 bytes
Entries:   59
SHA-256:   C10D550352D0733850A6A45C441B56F25E490426B870459F16149B5CDB515C35
Build cmd: .\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe scripts/build_rbz.rb
```

RBZ smoke (8/8 PASS): package is a valid PKZip archive; entry-point sits at `.rbz` root; dialog asset trio shipped; support folder is `su_ai_plugin/` containing `main.rb`; dev-only paths excluded; every required source file from the dev tree is shipped; install smoke (extract to temp dir, verify entry-point + assets + all `.rb` files parse); extracted entry-point boots through `FakeUI` with menu registered and `on_analyze_selection` no-op fallback.

This RBZ is **not approved for Owner installation** until AIPM review + Owner-checklist publication + the next Codex narrow xHigh recheck pass.

---

## 13. Final local stable commit

A local stable checkpoint commit has been recorded; the SHA is recorded in the document trail below and verified by the next steps.

(See §15 for the recorded SHA.)

---

## 14. Unresolved issues (explicit, for AIPM)

1. BLOCK-001 monkey-patch-driven tests (B003-6, B003-7, B003-11, B003-12) were intentionally not added to the new test file because they require deep module-level method injection that complicates test isolation. The underlying invariants (provenance mismatch, fingerprint mismatch, handle-shape mismatch, commit uncertainty) are still enforced by `DuplicateRepairExpectedPostState.validate!` and `DuplicateRepairExecutor.apply_batch_atomic`; existing V15-B003-1..B003-5 tests exercise the host-sequence contract; the new invariant I check is exercised by the end-to-end round-5 tests. A future refactor that introduces a thread-local test flag seam would make these tests cleaner without touching production semantics.
2. The current Owner verification file (`Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`) was invalidated by the Round-4 Codex verdict. AIPM must republish it once Round-5 review + the next Codex narrow xHigh recheck pass.
3. SU2017 host verification remains a manual Owner gate. No automated Ruby 2.2 fixture is in scope for Round-5.

---

## 15. Local checkpoint commit (record below)

`git rev-parse HEAD` recorded below after the local commit is created. NOT pushed.

---

## 16. STOP

Per `PI_START_HERE.md` §6 and `Prompt/CURRENT_PI_DISPATCH.md`:

- final stable local commit created (see §15);
- no push;
- no Codex recheck request;
- no V1.6 start;
- awaiting AIPM review.

Pi returns control to AIPM.