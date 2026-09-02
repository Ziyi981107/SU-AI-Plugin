# CURRENT PI REPORT — V17-AIPM-FINAL-PRE-CODEX-FIX

Project: `SU-AI-Plugin`
Version: V1.7
Stage: V17 FINAL-PRE-CODEX-FIX COMPLETE / AWAITING AIPM FINAL
DIRECT SOURCE RE-REVIEW (NOT yet V1.7 CLOSED; mandatory Codex
xHigh integration review + final Owner SU2020 real-host
verification gate remain.)
Dispatch: `V17-AIPM-FINAL-PRE-CODEX-FIX-2026-09-02`
Prior Dispatch: `V17-AIPM-DIRECT-SOURCE-REREVIEW-FIX-2026-09-01`
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

This is the FINAL bounded AIPM correction packet before the
mandatory Codex xHigh integration review. The AIPM direct
source RE-review of the prior
V17-AIPM-DIRECT-SOURCE-REREVIEW-FIX packet found exactly TWO
remaining source-contract defects (F-01 and F-02):

- F-01: RR-04's pre-batch canonical baseline rebuilt tolerance
  values with a partial string-key parser while
  `Tolerance#to_h` publishes SYMBOL keys. Non-default profiles
  could therefore silently fall back to legacy defaults and
  diverge from the proposal/apply path. RR-04's
  "exact pre-batch canonical baseline" could be rebuilt with a
  DIFFERENT `coordinate_epsilon` / `gap_search` from the
  proposal/apply path.

- F-02: `GapBridgeExecutor._post_validate` correctly looked up
  the READY proposal for `coordinate_epsilon`, but the expected
  endpoints used for host comparison came from
  `geometry_summary` (the derived record created from the same
  mutation path). A wrong record/mutation input could
  self-consistently agree with the host while disagreeing with
  the authoritative proposal. The check did not independently
  verify record endpoints/length vs the proposal AND host
  endpoints vs the proposal.

This dispatch:

- corrected both F-01 and F-02 with REAL production-path
  evidence;
- preserved every prior RR-01..RR-05 + SR-01..SR-07 + R5..R8
  regression;
- preserved the restored `tests/test_v17_host_mutation.rb`
  H1..H7 suite;
- did NOT redesign V1.7;
- did NOT invent new repair types;
- did NOT silently widen Source of Truth or tolerance
  semantics;
- did NOT invoke Codex;
- did NOT run Owner real-host verification;
- did NOT start V1.8;
- did NOT push `main`.

---

## 1. F-01 disposition — CAPTURED TOLERANCE AUTHORITY

**Source defect (AIPM F-01):**
`WorkingModeRunner#v17_tolerance` rebuilt a Tolerance from the
captured `execution_config.tolerance_values` Hash using
STRING keys only (`vals['duplicate']`,
`vals['short_edge']`, `vals['gap_search']`,
`vals['coordinate_epsilon']`). But `Tolerance#to_h` publishes
SYMBOL keys (`:duplicate`, `:short_edge`, `:gap_search`,
`:coordinate_epsilon`); `ExecutionConfigSnapshot.from_live_config`
preserves that Hash shape. Therefore a normal captured
SourceSnapshot with symbol-keyed tolerance values silently
fell back to the legacy defaults inside `v17_tolerance`,
while the compute / apply path still used the captured
values. The RR-04 "exact pre-batch canonical baseline" was
therefore rebuilt with a DIFFERENT `coordinate_epsilon` /
`gap_search` from the proposal/apply path when a non-default
profile or override was used.

**Fix (per dispatch §1):**
`v17_tolerance` now delegates directly to the
already-correct `_tolerance_from_snapshot(@current_source)`,
the same helper the V1.6 Planar Normalization / V1.7 compute /
apply paths already use. That helper accepts BOTH symbol and
string keys defensively (`vals[:k] || vals['k]`) and
preserves the complete tolerance field set (including
`big_z` / `large_coordinate` / `planar_z_snap`). The RR-04
baseline capture AND the proposal/apply path therefore use
IDENTICAL captured `gap_search` and `coordinate_epsilon`
values, with NO silent fallback to defaults.

**Custom-tolerance evidence (per dispatch §1):**
- New `V17-F01-A` test (`tests/test_v17_production_gap_path.rb`):
  builds a SourceSnapshot whose captured execution_config
  carries `Tolerance.new(gap_search: 0.25,
  coordinate_epsilon: 5.0e-6)` with the production SYMBOL-key
  shape. Asserts:
  - `V17P_RUNNER.v17_tolerance.gap_search == 0.25` (not 0.1)
  - `V17P_RUNNER.v17_tolerance.coordinate_epsilon == 5e-6` (not 1e-6)
  - `compute_gap_repair` yields exactly ONE READY_TO_REPAIR
    proposal whose `coordinate_epsilon == 5e-6` (not 1e-6)
    and whose `expected_bridge_length == 0.05` (the actual
    C-D gap, captured from the workspace).
- New `V17-F01-B` test: pre-batch baseline capture uses the
  SAME captured tolerance — `v17_tolerance` returns 0.25 / 5e-6
  even when called from `_current_gap_bridge_action_ids` /
  `_current_non_transitive_signatures` (the RR-04 baseline
  capture hooks). Apply succeeds and the canonical graph is
  structurally consistent (4 edges: 3 source + 1 bridge).

---

## 2. F-02 disposition — INDEPENDENT PROPOSAL-vs-RECORD-vs-HOST POST-VALIDATE

**Source defect (AIPM F-02):**
`GapBridgeExecutor._post_validate` correctly looked up the
READY proposal for `coordinate_epsilon`, but the expected
endpoints used for the host comparison were
`gs['start']` / `gs['end']` from the new DerivedEntityRecord
itself — a self-consistent comparison that a wrong
mutation input could pass while disagreeing with the
authoritative proposal. The method also did not
independently verify:

- record `geometry_summary` start/end == proposal
  `expected_bridge_endpoints`
- record `geometry_summary` length == proposal
  `expected_bridge_length`

**Fix (per dispatch §2):**
For each applied bridge, the post-validation block now:

1. Resolves the matching READY proposal by `proposal_id`;
   fails closed with `proposal_not_found:<pid>` if missing
   or not `READY_TO_REPAIR` / not `executable`.
2. Reads `expected_bridge_endpoints`,
   `expected_bridge_length` (with fallback derivation from
   the endpoints when missing in test seams), and
   `coordinate_epsilon` directly from the proposal. Fails
   closed on missing / non-finite / non-positive epsilon.
3. Independently verifies the DerivedEntityRecord's
   `geometry_summary['start']` / `['end']` against the
   PROPOSAL's `expected_bridge_endpoints` (undirected
   segment match within proposal `coordinate_epsilon`); emits
   `record_endpoint_mismatch:<pid>` on disagreement.
4. Independently verifies the DerivedEntityRecord's
   `geometry_summary['length']` against the proposal's
   `expected_bridge_length` (within proposal
   `coordinate_epsilon`); emits
   `record_length_mismatch:<pid>` on disagreement.
5. Verifies the actual host edge endpoints against the
   PROPOSAL's `expected_bridge_endpoints` (NOT against
   `geometry_summary`), within proposal `coordinate_epsilon`.
   Comparison remains undirected (host may report
   `(A,B)` or `(B,A)`). Emits
   `host_endpoint_segment_mismatch:<pid>` on disagreement.
6. Uses the proposal's `coordinate_epsilon`; no hardcoded
   fallback. Host capability / handle / position failures
   still fail closed with the existing stable reasons
   (`host_endpoint_handles_unavailable:<pid>` /
   `host_endpoint_handles_malformed:<pid>` /
   `host_endpoint_position_unavailable:<pid>` /
   `host_endpoint_position_unreadable:<pid>` /
   `host_endpoint_epsilon_missing:<pid>`).

**New stable reason constants:**
- `REASON_PROPOSAL_NOT_FOUND` = `proposal_not_found`
- `REASON_RECORD_ENDPOINT_MISMATCH` = `record_endpoint_mismatch`
- `REASON_RECORD_LENGTH_MISMATCH` = `record_length_mismatch`

**Independent proposal / record / host evidence (per dispatch §2):**
- New `V17-F02-A` test: ready proposal `(A, B)` with record
  AND host both reporting `(A, B)` PASSES (forward order).
- New `V17-F02-B` test: CONTRADICTION. Ready proposal expects
  `(A, B)`; the record says `(A, C)` (where `C` is 0.01
  away from `B`); the host says `(A, C)` too. The OLD
  self-consistent host-vs-record check would have PASSED.
  The NEW independent proposal-vs-record-vs-host check
  MUST FAIL, and MUST surface ALL THREE reasons
  simultaneously:
  - `record_endpoint_mismatch` (record start/end disagree
    with proposal)
  - `record_length_mismatch` (record length 0.01 != proposal
    0.05)
  - `host_endpoint_segment_mismatch` (host endpoint positions
    disagree with the PROPOSAL, not with the record).
- New `V17-F02-C` test: empty `ready` list (no matching READY
  proposal for the applied bridge) MUST fail with
  `proposal_not_found:<pid>`.

The reversed-host-order pass and captured-epsilon behavior
from the prior `V17-RR02-F` and `V17-RR02-E` tests are
preserved (re-run + green).

---

## 3. Changed production files

- `extension/su_ai_plugin/core/working_mode_runner.rb`:
  `v17_tolerance` is now a 2-line delegation to
  `_tolerance_from_snapshot(@current_source)` (with
  `Tolerance.default` fallback when no source is captured).
  No other behavior change.

- `extension/su_ai_plugin/core/gap_bridge_executor.rb`:
  - Added `REASON_PROPOSAL_NOT_FOUND`,
    `REASON_RECORD_ENDPOINT_MISMATCH`,
    `REASON_RECORD_LENGTH_MISMATCH` constants.
  - `_post_validate` now resolves the READY proposal by
    `proposal_id` and uses the PROPOSAL's
    `expected_bridge_endpoints` / `expected_bridge_length` /
    `coordinate_epsilon` as the authoritative reference for
    BOTH the record AND host comparisons. Independent
    `record_endpoint_mismatch` /
    `record_length_mismatch` / `host_endpoint_segment_mismatch`
    reasons are emitted on disagreement. Host comparison
    against the proposal (not against the record) restores
    the post-validation contract.

---

## 4. Changed test files

- `tests/test_v17_production_gap_path.rb`: +5 new tests:
  - `V17-F01-A` (custom symbol-keyed tolerance honored)
  - `V17-F01-B` (RR-04 baseline capture uses the captured
    tolerance)
  - `V17-F02-A` (record + host both match READY proposal
    PASSES)
  - `V17-F02-B` (contradictory record + host vs proposal
    FAILS with all three independent reasons)
  - `V17-F02-C` (missing READY proposal entry fails with
    `proposal_not_found:<pid>`)

No other test files were modified.

---

## 5. Full regression counts

- Full Ruby suite: **944 / 944 PASS** / 0 fail / 0 error
  (V1.0–V1.6 regressions + 89 prior V1.7 Ruby tests, +5 from
  this dispatch: V17-F01-A / V17-F01-B / V17-F02-A /
  V17-F02-B / V17-F02-C).
- V17 substring (`test_v17_*`): all green.
- V16 substring: **33 / 33 PASS**.
- V15 substring (`V15-B005-*`, BLOCK-005 host-state
  validation): **149 / 149 PASS** (no regression).
- LEGACY-COMPAT: **4 / 4 PASS**.
- RBZ smoke: **9 / 9 PASS**.
- Node DOM (`tests/test_html_render_dom.js`): all assertions
  PASS; final line `PASS`.
- `git diff --check`: clean.

---

## 6. RBZ

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **956,742 bytes**
- Entries: **67**
- SHA-256: **`98e9cb2ed659ec1b0d80efac2691c3380dc3c39875f316dae58cb47191d13710`**

---

## 7. Final commit + push

Final HEAD on `dev/v1.7`: see `git rev-parse HEAD` after the
push (one production commit + one doc-stamp, this dispatch).

Push policy:

- one normal fast-forward of the assigned branch (`dev/v1.7`);
- no force-push, no rebase, no rewrite of shared history;
- no `main` push/merge;
- no tag/release.

---

## 8. Remaining real unknowns (NOT a claim of completion)

- V1.7 mandatory Codex xHigh integration review still
  PENDING — Pi does NOT self-invoke.
- Final Owner SU2020 real-host verification gate (Scenarios
  A–G from §19 of the frozen V1.7 Blueprint) NOT YET RUN.
- V1.8 NOT STARTED.
- V2 / MCP / AI / site modeling OUT OF SCOPE.

---

## 9. Gate states

- `CODEX_GATE: STILL PENDING` — AIPM direct source re-review
  of this corrected packet is required before the mandatory
  Codex xHigh integration review.
- `OWNER_GATE: NOT YET RUN` — final SU2020 owner real-host
  verification gate (Blueprint §19 Scenarios A–G) is
  downstream of AIPM source re-review + Codex xHigh.
- `V1.8: NOT STARTED`.
- `V2 / MCP: OUT OF SCOPE`.

---

## 10. STOP

Per dispatch §8 + §9 + §12: STOPPED awaiting AIPM direct
source re-review of this corrected packet; Codex xHigh
integration review NOT invoked; V1.8 NOT STARTED; final
Owner SU2020 real-host verification gate NOT YET RUN.

Next expected action: AIPM direct source re-review of this
corrected packet. If F-01 and F-02 corrections pass, AIPM
SOURCE REVIEW = PASS, then mandatory Codex xHigh
integration review. Per dispatch §5: "After F-01 and F-02
are corrected and pushed: Pi STOP → AIPM verifies only
these two deltas → if both PASS, AIPM PRIMARY SOURCE
REVIEW = PASS → mandatory Codex xHigh integration review.
Do not open another AIPM correction round for speculative
polish."