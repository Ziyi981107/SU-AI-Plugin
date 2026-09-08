# CURRENT PI DISPATCH — V1.9A P0 NARROW RECHECK FIX

Project: SU-AI-Plugin
Stage: V1.9A — Final Block Fix
Date: 2026-09-08
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
TARGET_BRANCH: `dev/v1.9`
STATUS: ACTIVE
AIPM_REVIEW: FIX REQUIRED — NARROW RESIDUALS ONLY
CODEX_REVIEW: PRE-IMPLEMENTATION REVIEW COMPLETE; NARROW POST-FIX RECHECK PENDING
OWNER_SU2020: NOT YET
V1.9B: NOT AUTHORIZED / NOT STARTED

Primary authority for this continuation:

`Prompt/AIPM_V1_9A_P0_NARROW_RECHECK_FIX_2026-09-08.md`

Additional R7 authority:

`Prompt/AIPM_V1_9A_P0_NARROW_RECHECK_ADDENDUM_R7_2026-09-08.md`

Current AIPM review evidence:

`Review/CURRENT_AIPM_REVIEW.md`

Prior authority remains frozen except where the narrow guidance clarifies residuals:

- `Prompt/AIPM_V1_9A_P0_SHARED_VERTEX_IMPLEMENTATION_AMENDMENT_2026-09-08.md`
- `Prompt/CODEX_V1_9A_P0_CURRENT_GEOMETRY_SHARED_VERTEX_REVIEW_2026-09-08.md`

---

## 0. SCOPE

This is NOT a new broad implementation packet.

Fix exactly AIPM-P0-R1 through R7:

1. Executor true preflight before mutation.
2. Executor postvalidation exception-safe abort.
3. Endpoint live-read fallback contract correction.
4. Presenter actual V1.8 `loops` / `*_count` read shape.
5. TRUE orchestrated Owner-equivalent E2E regression.
6. Fresh normal/full-suite + rebuilt RBZ evidence.
7. Restore `deep_nesting` / `嵌套层级` current-attention chip semantics accidentally lost during mojibake recovery.

Do not reopen already-PASS shared-vertex architecture or unrelated V1.x work.

---

## 1. ALLOWED PRODUCTION FILES

- `extension/su_ai_plugin/core/endpoint_record.rb`
- `extension/su_ai_plugin/core/planar_normalization_executor.rb`
- `extension/su_ai_plugin/cad_prep_workflow_presenter.rb`

`planar_normalization_proposer.rb` is FROZEN for this recheck. If an R1 consistency test proves a mechanically missing proposer field is required, STOP and report the exact missing field before editing proposer.

Focused tests may be changed as required by R1–R7.

---

## 2. REQUIRED EXECUTOR OUTCOME — R1/R2

Before `begin_operation`:

- target Z must be Numeric + finite before conversion;
- every physical handle present + identity unique;
- adapter live-read capability available;
- every pre-position exactly 3 Numeric finite values;
- every vector exactly 3 Numeric finite values, X/Y exactly zero;
- `abs((pre_z + vector_z) - target_z) <= coordinate_epsilon` for every occurrence.

Any preflight failure => no operation opened, FAILED result, zero published success.

After mutation but before commit:

- every post-position read must be guarded;
- nil/malformed/non-numeric/non-finite/raise => abort exactly once, no commit, FAILED, zero published success;
- XY unchanged + Z at target within existing epsilon for every occurrence.

Required tests include unreadable/raised pre-read => zero begins, and raised/malformed/non-finite post-read => one begin + one abort + zero commit.

---

## 3. REQUIRED ENDPOINT OUTCOME — R3

Preferred path:

`endpoint_key -> host_vertex_map -> actual endpoint Vertex -> vertex_position(Vertex)`.

Cached fallback allowed when:

- endpoint handle absent;
- adapter absent;
- adapter genuinely lacks `vertex_position`.

Fail closed when endpoint handle exists AND adapter exposes `vertex_position`, but the read raises / returns nil / malformed / non-numeric / non-finite.

Live position shape must be EXACTLY 3 values.

---

## 4. REQUIRED PRESENTER OUTCOME — R4/R7

Use actual V1.8 result shape as primary authority:

- `sr['loops'][].unresolved_flags`
- `metrics['open_chain_count']`
- `metrics['closed_loop_count']`
- `metrics['region_count']`
- `metrics['hole_count']`
- `metrics['invalid_loop_count']`

Legacy aliases may remain defensive fallback only.

READY card must truthfully surface closed-loop / region counts using the `*_count` keys; optional hole count may surface when nonzero.

Restore `嵌套层级` to `PROBLEM_METRIC_LABELS`. Add a regression proving a current `deep_nesting` issue appears in the `other` card metric and current-attention chip/headline total, while CLEAN/APPLIED success metrics remain excluded.

Do NOT modify V1.8 or app.js.

---

## 5. REQUIRED TRUE E2E REGRESSION — R5

Use the same 0.2mm-Z + 1mm-gap Owner fixture.

Exercise ONLY the real V1.9A orchestrator chain for the automatic behavior:

```text
CadPrepWorkflowOrchestrator.start
-> Planar ACTIONABLE
-> Gap detected + presenter Gap action disabled
-> CadPrepWorkflowOrchestrator.apply_planar_and_refresh
-> BOTH identity-distinct physical B Vertex handles at target Z
-> presenter Gap action enabled
-> CadPrepWorkflowOrchestrator.apply_gap_and_refresh
-> returned snapshot already contains recomputed Structure
```

Do NOT manually call `compute_gap_repair` or `compute_structure_reconstruction` to simulate the automatic chain.

Final assertions:

- workspace ready
- open_chain_count 0
- closed_loop_count 1
- invalid_loop_count 0
- region_count 1
- no `loops[].unresolved_flags` contains `non_planar_loop`
- the two physical B handles are proven identity-distinct in THIS fixture.

---

## 6. REQUIRED TEST / PACKAGE EVIDENCE — R6

Use the working vendored Ruby interpreter already found by Pi.

After source/tests are corrected:

- run P0 focused tests;
- run relevant V1.6/V1.7/V1.8 regressions;
- run presenter + orchestrator regressions;
- rebuild `dist/SU-AI-Plugin.rbz` FROM THE CORRECTED SOURCE;
- run RBZ smoke against that rebuilt artifact;
- run the NORMAL/FULL Ruby suite; do not substitute the custom RBZ-excluding synthetic runner as final evidence;
- run Node DOM as applicable;
- run `git diff --check`.

Report exact Ruby executable path, `ruby -v`, commands/counts, known pre-existing failures separately, RBZ bytes/entries/SHA-256.

If the normal/full suite cannot run, STOP `TEST_EXECUTION_BLOCKED`.

Do NOT ask Owner to install the currently stale/corrupted RBZ.

---

## 7. PASS / PRESERVE — DO NOT REOPEN

- Group -> actual endpoint Vertex current-coordinate authority direction;
- physical-occurrence identity dedupe in proposer;
- logical vertex -> all eligible physical Vertex fan-out;
- one outer operation + one single-Vertex primitive per occurrence;
- logical/physical count split;
- V1.5 duplicate algorithm;
- V1.6 analysis math / tolerance authority;
- V1.7 pairing / canonical clustering;
- V1.8 reconstruction algorithm;
- current Issues / badge / healthy refresh behavior;
- toolbar / UI tab / hidden-semantics fixes;
- Source CAD immutability;
- Undo / host-state architecture;
- V1.9B.

---

## 8. FORBIDDEN

Do NOT change:

- `working_mode_runner.rb`
- orchestrator architecture/call order
- `planar_normalization_proposer.rb` unless STOP/approval condition in §1 is met
- V1.5 duplicate algorithm
- V1.6 analysis math/tolerances
- V1.7 pairing/canonical clustering
- V1.8 reconstruction/region algorithms
- Source CAD ownership
- Undo/host-state architecture
- app.js / CSS / toolbar
- Faces / Observers
- V1.9B / PreparedCadDataset
- MCP / LLM / Agent

---

## 9. RETURN

Update:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

Then commit/push only `origin/dev/v1.9` and STOP.

Return fields:

- exact files changed;
- R1 preflight behavior + tests;
- R2 post-read abort behavior + tests;
- R3 fallback matrix + tests;
- R4 actual V1.8 presenter key paths + tests;
- R5 orchestrated E2E evidence including two physical B handles;
- R6 normal full-suite + rebuilt RBZ evidence;
- R7 deep_nesting / 嵌套层级 regression evidence;
- confirmation V1.9B NOT STARTED.

Set:

- `AIPM_REVIEW = PENDING`
- `CODEX_NARROW_RECHECK = NOT YET`
- `OWNER_SU2020 = NOT YET`
- `V1.9B = NOT STARTED`

STOP.

END
