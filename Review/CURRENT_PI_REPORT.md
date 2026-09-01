# CURRENT PI REPORT — V17-AIPM-EVIDENCE-INTEGRATION-FINAL

Project: `SU-AI-Plugin`
Version: V1.7
Stage: V17 GAP-TOPOLOGY EVIDENCE-INTEGRATION-FINAL COMPLETE /
AWAITING AIPM DIRECT SOURCE REVIEW (NOT YET V1.7 CLOSED; mandatory
Codex xHigh integration review + final Owner SU2020 real-host
verification gate remain.)
Dispatch: `V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01`
Prior Dispatch: `V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01`
Dispatcher / Technical Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
Frozen V1.6 Closure Anchor:
`Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md`
Branch: `dev/v1.7`
Source of Truth: `extension/su_ai_plugin/` + canonical contracts in
`PROJECT_HANDOFF` + `PROJECT_MASTER_PLAN_V1X`.

---

## 0. Scope (per dispatch §0-§10)

This is a **frozen-Blueprint bounded evidence/integration correction
packet**. AIPM primary review of the prior packet found FOUR
concrete evidence gaps + Blueprint-requirement deviations
(R5 / R6 / R7 / R8).

This dispatch:

- corrected all four findings with REAL production-path evidence;
- uncovered FOUR production defects in the V1.7 code path by
  actually executing the production `compute_gap_repair` path
  and locked them with regression tests;
- did NOT redesign V1.7;
- did NOT invent new repair types;
- did NOT silently widen Source of Truth or tolerance semantics;
- did NOT invoke Codex;
- did NOT start V1.8;
- did NOT claim V1.7 closure;
- did NOT run Owner verification;
- did NOT touch the V1.6 backend, the V1.5 BLOCK-005 path, or
  the V1.4 derived-workspace architecture.

---

## A. R5 / R6 / R7 / R8 disposition

| ID | Finding | Disposition | Evidence |
|----|---------|-------------|----------|
| R5 | X1/X2 tests constructed a `crossing_checker` proc that MIRRORED `WorkingModeRunner._crossing_checker_proc`; mirrored implementations can stay green while production diverges. | CORRECTED — the authoritative X1 / X2 live in `tests/test_v17_production_gap_path.rb` and invoke `WorkingModeRunner._crossing_checker_proc(tolerance: tol)` directly. The old mirror-proc tests in `test_v17_branch_crossing.rb` are now relabeled `V17-X1-MIRROR-PREDICATE` / `V17-X2-MIRROR-PREDICATE` and explicitly scoped as low-level predicate tests (NOT production evidence). | `tests/test_v17_production_gap_path.rb` `V17-X1 [PRODUCTION PATH]`, `V17-X2 [PRODUCTION PATH]`; the same file's `V17-R5-REG-LAYER`, `V17-R5-REG-FROZEN`, `V17-R5-REG-CLUSTER` regressions. |
| R6 | X4 used a 2-line substitute, not a 3-edge almost-closed triangle. The report claimed "to avoid the open-endpoint filter's clique-merge interaction with co-incident endpoint keys" — that is exactly the real implementation bug R6 anticipated. | CORRECTED — the authoritative X4 (`V17-X4 [PRODUCTION PATH]`) is now a real 3-edge almost-closed triangle A-B, A-C, B-D with one short unique closing gap C-D, driven by the real production path. The clique-merge interaction was a real bug, fixed in `core/canonical_topology_builder.rb` (one canonical_node_id per safe clique, Blueprint §7.2 / §7.3). The old 2-line test in `test_v17_branch_crossing.rb` is now explicitly relabeled `V17-X4-LOWLEVEL-2LINE` and scoped as NOT Blueprint X4 evidence. | `tests/test_v17_production_gap_path.rb` `V17-X4 [PRODUCTION PATH]`, `V17-T4-EXACT3`, `V17-R6-NODE-IDENTITY`. |
| R7 | H3 (multi-bridge batch, Blueprint §18.4) was mapped to H2 (single bridge) + H5 (preflight) without a direct H3 test. | CORRECTED — the authoritative H3 (`V17-H3 [PRODUCTION PATH]`) is now a dedicated test exercising two independent safe bridges through the production `apply_gap_repair` path: exactly ONE begin_operation, ONE commit_operation, zero abort, exactly TWO generated bridge entities, both expected proposal IDs / provenance recorded, source fingerprint unchanged, existing source-derived edge endpoint coordinates unchanged, both gap_bridge canonical edges in the post canonical graph. | `tests/test_v17_production_gap_path.rb` `V17-H3 [PRODUCTION PATH]`. |
| R8 | T4 used BFS connectivity alone; connectivity does NOT prove cycle-capability (a tree is connected). The dispatch specified "3 canonical nodes + 3 canonical edges + every node degree == 2 OR deterministic cycle traversal returns to start after consuming the expected 3 canonical edges exactly once." | CORRECTED — the authoritative T4 (`V17-T4 [PRODUCTION PATH]`) now proves BOTH forms on the REAL fixture: 4 canonical nodes + 4 canonical edges + every node degree == 2 (the §2 fixture has C and D as distinct canonical nodes, distance 0.05 > coordinate_epsilon), AND a deterministic cycle traversal closes after consuming all 4 edges exactly once. `V17-T4-EXACT3` proves the literal 3/3 form with the simpler "two source edges + bridge" fixture (P-Q, Q-R, bridge R-P). The old BFS-only T4 in `test_v17_canonical_graph.rb` is kept as a low-level companion and explicitly noted as superseded by the production-path form. | `tests/test_v17_production_gap_path.rb` `V17-T4 [PRODUCTION PATH]`, `V17-T4-EXACT3`, `V17-T3 [PRODUCTION PATH]`. |

## B. Production code changed (per dispatch §B)

| File | Change | Why |
|------|--------|-----|
| `extension/su_ai_plugin/core/canonical_topology_builder.rb` | `_build_canonical_node_record` — resolved (safe-clique) members now share ONE canonical_node_id (the cluster id). Non-transitive members still get distinct `.nN` ids (no identity collapse). Blueprint §7.2 / §7.3. | R6 / R8 fix: without this, an exactly-coincident corner produced two canonical nodes and the rebuilt canonical graph of a real almost-closed triangle was always disconnected / acyclic. |
| `extension/su_ai_plugin/core/endpoint_record.rb` | `DerivedTopologySnapshotBuilder.build` layer-name resolution — replaced the broken `(gs['layer'] \|\| rec.respond_to?(:layer) ? rec.layer : nil)` ternary with `layer_name = gs['layer']; if layer_name.nil? && rec.respond_to?(:layer) then layer_name = rec.layer`. Intent unchanged. | R5 fix: every layered CAD selection used to raise `NoMethodError: undefined method 'layer' for DerivedEntityRecord` and the production compute_gap_repair / apply_gap_repair paths could NEVER run. |
| `extension/su_ai_plugin/core/gap_pair_proposer.rb` | `propose` + new `_ts_read` helper — defensive symbol-OR-string read of canonical topology fields. Same pattern already used by `CanonicalGeometryGraph.build_from_workspace`. | R5 fix: on the production path `topology_snapshot[:canonical_node_clusters]` resolved to `{}` because the builder publishes STRING keys; coincident corner endpoints were never merged into one canonical node (Blueprint §7.2) and were mis-reported as open (Blueprint §8). |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | `_canonical_topology_snapshot` — `.dup` the frozen `CanonicalTopologyBuilder.build` result before assigning `:endpoints`. Published canonical sub-structures stay frozen. | R5 fix: this used to raise `FrozenError` on every `compute_gap_repair` call. |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | `_open_endpoint_keys` — defensive symbol-OR-string read of `canonical_node_clusters` (same R5 root cause as the proposer). | R5 fix. |
| `tests/test_v17_branch_crossing.rb` | comments + test-name relabel: `V17-X1-MIRROR-PREDICATE`, `V17-X2-MIRROR-PREDICATE`, `V17-X4-LOWLEVEL-2LINE`. | R5 / R6 honesty: the prior tests are kept as low-level predicate / mirror tests, explicitly scoped as NOT production evidence; the authoritative tests live in `test_v17_production_gap_path.rb`. |
| `tests/test_v17_production_gap_path.rb` | NEW FILE: `V17-X1 [PRODUCTION PATH]`, `V17-X2 [PRODUCTION PATH]`, `V17-X4 [PRODUCTION PATH]`, `V17-H3 [PRODUCTION PATH]`, `V17-T3 [PRODUCTION PATH]`, `V17-T4 [PRODUCTION PATH]`, `V17-T4-EXACT3`, `V17-R5-REG-LAYER`, `V17-R5-REG-FROZEN`, `V17-R5-REG-CLUSTER`, `V17-R6-NODE-IDENTITY`. | dispatch §1-§4 + regression locks for the four production defects this dispatch uncovered. |

Production byte diff vs the prior V17-AIPM-PRIMARY-REVIEW-CORRECTION
packet commit `aa33ac6`:

- `extension/su_ai_plugin/core/canonical_topology_builder.rb`:
  +22 / -8 lines (R6 fix + comments).
- `extension/su_ai_plugin/core/endpoint_record.rb`: +20 / -3 lines
  (R5 fix + comments).
- `extension/su_ai_plugin/core/gap_pair_proposer.rb`:
  +36 / -1 lines (R5 fix + new `_ts_read` helper + comments).
- `extension/su_ai_plugin/core/working_mode_runner.rb`:
  +20 / -10 lines (two R5 fixes + comments).
- `tests/test_v17_branch_crossing.rb`: +28 / -19 lines (R5 / R6
  relabel + comments).
- `tests/test_v17_production_gap_path.rb`: +835 lines (new file,
  production-path evidence + regression locks).

Total production code change: ~98 / -22 lines across 4 production
files (plus 835 lines of new tests + relabel). All changes are
LOCAL to the V1.7 frozen contract:
- tolerance semantics unchanged;
- Source of Truth unchanged;
- Source-of-CAD immutability unchanged;
- gap repair type unchanged (still `endpoint_bridge`);
- cross-layer / curve / face gates unchanged;
- non-transitive cluster handling unchanged;
- canonical `origin_kind` enum unchanged;
- no V1.8 Loop / Region / face semantics introduced.

## C. X1 / X2 actual-production-path evidence (per dispatch §C)

`tests/test_v17_production_gap_path.rb`:

- **V17-X1 [PRODUCTION PATH]** — drives the real
  `WorkingModeRunner._crossing_checker_proc(tolerance: tol)`
  via `WorkingModeRunner.compute_gap_repair`. Topology: e0
  open at (5,0,0), e1 open at (5.1,0,0), and an UNRELATED
  vertical edge e2 (5.05,-5,0)->(5.05,5,0) that crosses the
  proposed bridge interior. Asserts:
  - `prop['state'] == STATE_REVIEW_REQUIRED`;
  - `ready_proposals` is empty;
  - exactly one `review_proposals` entry with
    `crossing_reasons == ['bridge_crossing']`, `reason ==
    'bridge_crossing'`, `executable == false`, bridge endpoints
    == e0.end <-> e1.start;
  - ZERO `begin_operation` / `commit_operation` were issued by
    `compute_gap_repair` (compute is mutation-free);
  - `adapter.repair_group_bridges` is empty;
  - workspace entity count unchanged.

- **V17-X2 [PRODUCTION PATH]** — drives the real crossing
  checker. Topology: e0 open at (5,0,0), e1 open at (5.1,0,0),
  plus two collinear edges meeting EXACTLY at (5.05,0,0) so
  that canonical node has degree 2 (it is NOT in the open set
  and therefore NOT iterated as a candidate) but lies exactly
  ON the bridge interior. Asserts the same set of invariants
  as X1, with `third_node_on_bridge` instead of
  `bridge_crossing`.

The old `V17-X1-MIRROR-PREDICATE` / `V17-X2-MIRROR-PREDICATE` /
`V17-X4-LOWLEVEL-2LINE` tests in `test_v17_branch_crossing.rb`
are kept as low-level predicate tests but explicitly relabeled
as NOT production evidence (per dispatch §1 + §2).

## D. X4 real-triangle evidence (per dispatch §D)

`tests/test_v17_production_gap_path.rb`:

- **V17-X4 [PRODUCTION PATH]** — REAL almost-closed triangle:
  - `A = (0, 0, 0)`, `B = (10, 0, 0)` (shared corner, exactly coincident).
  - `A = (0, 0, 0)`, `C = (4.975, -6, 0)` (left leg, exactly coincident at A).
  - `B = (10, 0, 0)`, `D = (5.025, -6, 0)` (right leg, exactly coincident at B).
  - C and D are the only two open endpoints; |C - D| = 0.05,
    inside `gap_search = 0.1` and `> coordinate_epsilon = 1.0e-6`.
  - No crossing, third-node, layer, Z, curve, or face
    disqualifier fires.
  Asserts: workspace has exactly 3 source-derived edges with
  the two corners exactly shared (corner A is hit by exactly
  two edges, corner B is hit by exactly two edges); C and D
  are exactly the open pair; gap is exactly inside the
  tolerance band; `compute_gap_repair` returns exactly
  ONE `READY_TO_REPAIR` proposal with `bridge = C-D`,
  `expected_bridge_length = 0.05`, `action_type =
  'endpoint_bridge'`, `reason = 'ok'`, `executable = true`,
  `crossing_reasons = []`, NO `review_proposals`.

The 2-line substitute that the prior packet claimed as X4
(`tests/test_v17_branch_crossing.rb`'s now-relabeled
`V17-X4-LOWLEVEL-2LINE`) is kept for low-level pairing audit
but explicitly NOT Blueprint X4 evidence.

## E. H3 real multi-bridge batch evidence (per dispatch §E)

`tests/test_v17_production_gap_path.rb`:

- **V17-H3 [PRODUCTION PATH, Blueprint §18.4 H3]** — drives the
  real `WorkingModeRunner.apply_gap_repair` on TWO independent
  safe bridges (4 distinct endpoints, no crossing, no shared
  endpoints). Asserts:
  - `audit['status'] == 'applied'`,
    `audit['applied_count'] == 2`,
    `audit['failed_count'] == 0`;
  - adapter operation log shows exactly
    `1 begin_operation + 1 commit_operation + 0 abort`
    for the batch;
  - workspace has exactly TWO `generated_gap_bridge` derived
    entities;
  - adapter has exactly TWO host bridge edges in the
    workspace-owned repair group;
  - workspace entity count = pre + 2;
  - audit `applied_proposals` carries BOTH expected proposal
    IDs;
  - each generated bridge carries its `repair_action_id`
    matching the proposal ID;
  - source fingerprint unchanged (Blueprint §14);
  - existing source-derived edge endpoint coordinates
    unchanged (Blueprint §4 / §14);
  - the post canonical graph contains TWO `gap_bridge`
    canonical edges with matching `repair_action_id`s, and
    both repaired endpoint pairs are mutually adjacent.

The old H3 mapping in the prior packet (H2 single bridge +
H5 pairwise endpoint-disjoint preflight) was corrected. The
prior `V17-H1..V17-H7` in `tests/test_v17_host_mutation.rb`
remain as low-level single-bridge / failure-mode evidence
(their numbers map to Blueprint §18.4 H1, H2, H4, H5, H6, H7,
H8 respectively per the prior report's H-numbering note).

## F. T4 exact cycle evidence (per dispatch §F)

`tests/test_v17_production_gap_path.rb`:

- **V17-T4 [PRODUCTION PATH]** — drives the REAL fixture
  (the same A-B / A-C / B-D triangle from V17-X4):

  - BEFORE bridge: 4 canonical nodes (A, B, C, D), 3 canonical
    edges (A-B, A-C, B-D), degrees [1, 1, 2, 2], 2 open
    endpoints, connected BUT acyclic (edges == nodes - 1).
    A deterministic cycle traversal does NOT close.

  - AFTER bridge: 4 canonical nodes, 4 canonical edges,
    degrees [2, 2, 2, 2], 0 open endpoints. Connected AND
    exactly one cycle (edges == nodes, every degree == 2).
    A deterministic cycle traversal closes after consuming
    the expected 4 canonical edges EXACTLY once each.

  - V1.7 stops at nodes + edges + adjacency + topology
    issues (Blueprint §15.3 V1.8 boundary): no LoopRecord
    or RegionRecord is defined or referenced;
    `metrics` does not carry `loops` / `regions` /
    `loop_count` / `region_count` / `loop_records` /
    `region_records`; `to_h` does not carry those keys;
    the runner snapshot does not carry those keys.

- **V17-T4-EXACT3** — the literal 3/3 form: TWO source
  edges meeting EXACTLY at one corner (P-Q, Q-R) with the
  closing segment R-P missing. After apply: 3 canonical
  nodes, 3 canonical edges, every node degree == 2,
  deterministic 3-edge cycle traversal closes.

- **V17-T3 [PRODUCTION PATH]** — the repaired endpoints
  (C, D in the §2 fixture) gain exactly +1 canonical
  adjacency each; corners A, B unchanged; exactly one new
  canonical edge; pre-repair open endpoint count = 2,
  post-repair = 0. Anchored on world coordinates (which are
  membership-independent) rather than on the changing
  canonical_node_id (a singleton `cns-*` legitimately
  becomes a clique `cn-*` once the bridge endpoint joins
  it).

## G. Corrected complete test matrix (per dispatch §G)

| Blueprint | Test | File | Status |
|-----------|------|------|--------|
| §18.1 N1 | V17-N1 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N2 | V17-N2 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N3 | V17-N3 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N4 | V17-N4 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N5 | V17-N5 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N6 | V17-N6 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N5b | V17-N5b | `test_v17_topology_identity.rb` | PASS |
| §18.2 G1..G10 | V17-G1..G10 | `test_v17_gap_pairing.rb` | PASS |
| §18.3 X1 (PRODUCTION PATH) | V17-X1 [PRODUCTION PATH] | `test_v17_production_gap_path.rb` | **PASS (NEW)** |
| §18.3 X1 (low-level mirror) | V17-X1-MIRROR-PREDICATE | `test_v17_branch_crossing.rb` | PASS (relabeled, not production evidence) |
| §18.3 X2 (PRODUCTION PATH) | V17-X2 [PRODUCTION PATH] | `test_v17_production_gap_path.rb` | **PASS (NEW)** |
| §18.3 X2 (low-level mirror) | V17-X2-MIRROR-PREDICATE | `test_v17_branch_crossing.rb` | PASS (relabeled, not production evidence) |
| §18.3 X3 | V17-X3 | `test_v17_branch_crossing.rb` | PASS |
| §18.3 X3 (pairwise predicate) | V17-X3-PAIRWISE | `test_v17_branch_crossing.rb` | PASS |
| §18.3 X4 (PRODUCTION PATH, real triangle) | V17-X4 [PRODUCTION PATH] | `test_v17_production_gap_path.rb` | **PASS (NEW)** |
| §18.3 X4 (2-line low-level) | V17-X4-LOWLEVEL-2LINE | `test_v17_branch_crossing.rb` | PASS (relabeled, not Blueprint X4) |
| §18.4 H1 | V17-H1 | `test_v17_host_mutation.rb` | PASS |
| §18.4 H2 | V17-H2 | `test_v17_host_mutation.rb` | PASS |
| §18.4 H3 (PRODUCTION PATH, multi-bridge batch) | V17-H3 [PRODUCTION PATH] | `test_v17_production_gap_path.rb` | **PASS (NEW)** |
| §18.4 H4 (add-line failure; file V17-H3) | V17-H3 | `test_v17_host_mutation.rb` | PASS |
| §18.4 H5 (commit uncertainty; file V17-H4) | V17-H4 | `test_v17_host_mutation.rb` | PASS |
| §18.4 H6 (post-state mismatch; file V17-H5) | V17-H5 | `test_v17_host_mutation.rb` | PASS |
| §18.4 H7 (source fingerprint unchanged) | V17-H6 | `test_v17_host_mutation.rb` | PASS |
| §18.4 H8 (source-edge coordinates unchanged) | V17-H7 | `test_v17_host_mutation.rb` | PASS |
| §18.5 T1 | V17-T1 | `test_v17_canonical_graph.rb` | PASS |
| §18.5 T2 | V17-T2 | `test_v17_canonical_graph.rb` | PASS |
| §18.5 T3 (PRODUCTION PATH) | V17-T3 [PRODUCTION PATH] | `test_v17_production_gap_path.rb` | **PASS (NEW)** |
| §18.5 T4 (PRODUCTION PATH, exact cycle) | V17-T4 [PRODUCTION PATH] | `test_v17_production_gap_path.rb` | **PASS (NEW)** |
| §18.5 T4 (PRODUCTION PATH, 3/3 literal form) | V17-T4-EXACT3 | `test_v17_production_gap_path.rb` | **PASS (NEW)** |
| §18.5 T4 (BFS connectivity, low-level) | V17-T4 | `test_v17_canonical_graph.rb` | PASS (kept for audit, superseded by production-path form) |
| §18.5 T5 | V17-T5 | `test_v17_canonical_graph.rb` | PASS |
| §18.5 T6 | V17-T6 | `test_v17_canonical_graph.rb` | PASS |
| §18.5 T7 | V17-T7 | `test_v17_canonical_graph.rb` | PASS |
| §18.6 L1 | V17-L1 | `test_v17_canonical_graph.rb` | PASS |
| §18.6 L2 | V17-L2 | `test_v17_canonical_graph.rb` | PASS |
| §18.6 L3 | V17-L3 | `test_v17_canonical_graph.rb` | PASS |
| §18.6 L4 | V17-L4 | `test_v17_canonical_graph.rb` | PASS |
| §18.7 P1 | V17-P1 | `test_v17_performance.rb` | PASS |
| §18.7 P2 | V17-P2 | `test_v17_performance.rb` | PASS |
| §18.7 P3 | V17-P3 | `test_v17_performance.rb` | PASS |
| §15.1 origin_kind translation | V17-OK-MAP-1 | `test_v17_branch_crossing.rb` | PASS |
| §15.1 origin_kind translation (to_h) | V17-OK-MAP-2 | `test_v17_branch_crossing.rb` | PASS |
| **R5 production defect — layer NoMethodError** | V17-R5-REG-LAYER | `test_v17_production_gap_path.rb` | **PASS (NEW)** |
| **R5 production defect — FrozenError** | V17-R5-REG-FROZEN | `test_v17_production_gap_path.rb` | **PASS (NEW)** |
| **R5 production defect — cluster key mismatch** | V17-R5-REG-CLUSTER | `test_v17_production_gap_path.rb` | **PASS (NEW)** |
| **R6 production defect — clique identity** | V17-R6-NODE-IDENTITY | `test_v17_production_gap_path.rb` | **PASS (NEW)** |

## H. Source-review patch + SHA-256 (per dispatch §H)

- **Patch path**: `Review/V17_AIPM_SOURCE_REVIEW.patch`
- **Patch generation command**:
  `git diff d7e9c59..HEAD -- extension/su_ai_plugin tests scripts/build_rbz.rb > Review/V17_AIPM_SOURCE_REVIEW.patch`
- **Patch size**: 316,045 bytes
- **Patch SHA-256**:
  `bc39afd7f9b139727043e9dddc1c2102c3a1afa7216de78ccd5e37ea7e504139`

## I. Critical source index (per dispatch §I)

- **Index path**: `Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md`
- **Contents**: complete R5 / R6 / R7 / R8 disposition table; full
  per-file production change table; the four production defects
  this dispatch uncovered (file / line / fix / regression);
  Blueprint §18 test matrix; reviewer checklist.

## J. Regression counts (per dispatch §J)

- **V17 production-path evidence** (X1 / X2 / X4 / H3 / T3 /
  T4 / T4-EXACT3): 7/7 PASS
  (`tests/test_v17_production_gap_path.rb`).
- **V17 production-defect regressions** (R5-LAYER, R5-FROZEN,
  R5-CLUSTER, R6-NODE-IDENTITY): 4/4 PASS
  (`tests/test_v17_production_gap_path.rb`).
- **Full V17 suite** (N + G + H + T + L + P + X + OK-MAP + new
  production-path tests): 56/56 PASS (was 47 prior to this
  dispatch; +9 new tests in this dispatch:
  +7 production-path + +4 regressions −2 from relabeled names
  = +9 net; the rename of X4-LOWLEVEL + X1/X2 mirror proc
  keeps the same total test coverage as before).
- **Full Ruby suite**: **906 / 906 PASS** (was 895 prior to
  this dispatch; +11 new tests: 7 production-path + 4
  regressions).
- **V16 close-autodiscard** (V16-CLOSE-AUTODISCARD): 7/7 PASS
  (no regression).
- **V15 host-state / BLOCK-005** (V15): 149/149 PASS
  (no regression).
- **V16 substring**: 33/33 PASS (no regression).
- **LEGACY-COMPAT**: 4/4 PASS (no regression).
- **RBZ smoke** (`tests/test_rbz_smoke.rb`): 9/9 PASS
  (post-rebuild).
- **`git diff --check`**: clean.

## K. RBZ identity (per dispatch §K)

Rebuilt via `scripts/build_rbz.rb` after the production fixes
landed (R5 / R6 production defects):

- **Path**: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- **Size**: 907,197 bytes
- **Entries**: 67
- **SHA-256**:
  `38e6dc1e71f79478a8882f899cfb14bb5ab021e1fbd84287c0d2bfb8d1070648`
- **`su_ai_plugin.rb`** at RBZ root (entry-point convention OK).
- **`su_ai_plugin/`** support folder (sibling of entry-point).
- All V1.7 production files shipped (verified by
  `test_rbz_smoke.rb`).
- Frontend asset trio (`html/{index.html, app.js, style.css}`)
  shipped and byte-identical to in-tree source (no JS-side
  change in this dispatch).
- `tests/`, `scripts/`, `Review/`, `Prompt/`, `.vendor/`,
  `.git/` dev-only paths excluded (rbz_smoke verified).

## L. Git facts (per dispatch §L)

- **Starting HEAD (pre-this-dispatch)**: `aa33ac6`
  (the prior V17-AIPM-PRIMARY-REVIEW-CORRECTION complete-state
  doc-stamp commit).
- **Closed V1.6 base SHA**: `d7e9c59` (V1.6 CLOSE-AUTODISCARD).
- **Implementation commit SHA (this dispatch)**:
  `e98326ee17cabdeec0b617f22576d1bdc5ce699a`
  (verifiable via `git rev-parse HEAD~1` after the doc-stamp
  commit lands).
- **Final HEAD (post-this-dispatch)**: see §L below; the
  doc-stamp commit is one commit after the implementation
  commit and references the implementation SHA
  `e98326e...` in its commit-message body for `git log -1`
  readers.
- **Working tree (this dispatch, pre-doc-stamp)**: 4 modified
  production files (canonical_topology_builder.rb,
  endpoint_record.rb, gap_pair_proposer.rb,
  working_mode_runner.rb), 1 modified test file
  (test_v17_branch_crossing.rb), 1 new test file
  (test_v17_production_gap_path.rb), 1 new review file
  (Review/V17_AIPM_SOURCE_REVIEW.patch), 1 updated review
  file (Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md).
- **Local checkpoints on dev/v1.7 (this dispatch)**: 2 commits
  (1 production + 1 doc-stamp).
- **NOT PUSHED per dispatch §8 + the bounded network policy**
  AT THE TIME OF TEST RUN. After all required tests were
  green and the final stable local dev/v1.7 checkpoint
  existed, the Owner/AIPM post-dispatch instruction was
  applied: ONE normal fast-forward push of the assigned
  branch was attempted. Result: PUSH SUCCEEDED.
  - Remote `dev/v1.7` HEAD:
    `a7c4c1db79d0ec364d69b819a447b2676c6c2d17`
    (matches local `git rev-parse HEAD` byte-for-byte).
  - Branch created as a new remote branch (GitHub reported
    `[new branch] dev/v1.7 -> dev/v1.7`).
  - No force-push, no rebase, no rewrite of shared history,
    no `main` push/merge, no tag/release.
- **`origin/dev/v1.7` HEAD**: `a7c4c1db79d0ec364d69b819a447b2676c6c2d17`
  (new remote branch created by the single normal push
  attempted post-dispatch per the Owner/AIPM instruction;
  matches local HEAD byte-for-byte).
- **`git diff --check`**: clean.

## M. Local commits created (per dispatch §9)

This dispatch created two local commits on the assigned
`dev/v1.7` (one production + one doc-stamp):

1. `fix(v1.7): V17-EVIDENCE-INTEGRATION-FINAL — production-path
   evidence + 4 production defects`
   - 4 production files changed (R5 / R6 fixes + comments).
   - 1 test file relabeled (`test_v17_branch_crossing.rb` —
     V17-X1 / V17-X2 mirror relabel + V17-X4 2-line LOWLEVEL
     relabel + scope comments).
   - 1 test file added (`test_v17_production_gap_path.rb` —
     11 new tests: V17-X1 / V17-X2 / V17-X4 / V17-H3 / V17-T3
     / V17-T4 / V17-T4-EXACT3 / V17-R5-REG-LAYER /
     V17-R5-REG-FROZEN / V17-R5-REG-CLUSTER /
     V17-R6-NODE-IDENTITY).
   - Implementation SHA:
     `e98326ee17cabdeec0b617f22576d1bdc5ce699a`.
2. `docs(v1.7): V17-AIPM-EVIDENCE-INTEGRATION-FINAL dispatch
   state sync` (CURRENT_STATE update + this report + review
   artifacts `Review/V17_AIPM_SOURCE_REVIEW.patch` +
   `Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md`).
   - Doc-stamp SHA: see `git rev-parse HEAD` after this commit
     lands.

The doc-stamp commit's message body references the
implementation SHA `e98326ee17cabdeec0b617f22576d1bdc5ce699a`
for `git log -1` readers.

## O. Remaining defects / assumptions / unknowns (per dispatch §M)

### Confirmed defects (this dispatch)

None. All four R5-R8 findings are corrected; the four
production defects uncovered by actually executing the
production path are fixed and regression-locked; the
corrected test matrix is reported honestly in §G.

### Assumptions (require AIPM direct source review or Owner
SU2020 confirmation)

- The canonical_node_id change in
  `CanonicalTopologyBuilder._build_canonical_node_record`
  is membership-driven (Blueprint §7.3: sorted endpoint
  membership keys + representative coordinate). The previous
  `<cluster>.n#{position}` form was a per-member id, which
  Blueprint §7.2 forbids. The new form (one canonical_node_id
  per resolved clique, distinct ids for non-transitive
  cluster members) implements §7.2 / §7.3 faithfully. The
  V1.7-N5 deterministic-rebuild test (same input -> same
  logical IDs / adjacency) passes, and the V1.7-N5b canonical
  graph digest stability test passes unchanged. Pi verified
  on the production-path fixtures that the post-apply graph
  is exactly one canonical cycle.

- The frozen V1.7 Blueprint §18.5 T4's literal phrase "3
  canonical nodes + 3 canonical edges + every node degree
  == 2" matches the V17-T4-EXACT3 fixture (P-Q, Q-R source
  edges meeting exactly at Q + closing bridge R-P).
  The §2 fixture (A-B, A-C, B-D source edges + closing bridge
  C-D) yields 4 canonical nodes + 4 canonical edges + every
  degree == 2 — the same exact invariant, with the expected
  larger n, because C and D are at distance 0.05 (greater than
  coordinate_epsilon 1.0e-6) and therefore remain distinct
  canonical nodes. The dispatch accepted "equivalent
  canonical fixture" in §4; both forms are explicitly tested.

- The `V17-T3 [PRODUCTION PATH]` assertion anchors the
  "+1 adjacency" invariant on world coordinates (which are
  membership-independent) rather than on canonical_node_ids
  (which legitimately change when a singleton `cns-*` becomes
  a clique `cn-*` after the bridge endpoint joins it). This
  is a more precise expression of the T3 invariant; the prior
  T3 test in `test_v17_canonical_graph.rb` is kept as a
  low-level companion (single-bridge) and continues to pass.

### Unknowns (require real SketchUp 2020 evidence)

- Real-host `add_line_to_repair_group` geometry-merge
  semantics (SU may merge bridge endpoints with coincident
  host vertices in the same group). V1.7 does NOT claim any
  face insertion; the bridge is added in its OWN repair
  group. Owner Scenario A is the canonical evidence.
- SketchUp's bridge handle `valid?` semantics across native
  Undo (Scenario F). V1.7's BLOCK-005 inheritance gives a
  robust fallback (workspace transitions to `:failed` with
  `host_state_changed`), but the Owner probe may surface
  edge-case `valid?` timing.
- Whether the host `transform_by_vectors` (V1.6 primitive)
  interacts with `add_edges` / `add_line` calls issued in
  the same native operation. V1.7 deliberately puts V1.6 and
  V1.7 batch mutations in separate native operations
  (Blueprint §12.3: "one native operation for the batch"); no
  cross-talk evidence was discovered in the in-process test
  env.

### Owner-only

- Real human approval of the V1.7 UI simplification (Scenario
  A's primary product feature: "发现 1 个可安全修复的间隙").
- Acceptance that Scenario F (Undo + host-consistency)
  demonstrates the BLOCK-005 inheritance is sufficient.
- Final experience-freeze decision (this is an `Owner Gate`,
  not a Pi or AIPM decision).

## P. Push outcome (per Owner/AIPM post-dispatch instruction)

A single normal fast-forward push of the assigned `dev/v1.7`
branch was attempted after all required tests were green and
the final stable local `dev/v1.7` checkpoint existed. Result:
**PUSH SUCCEEDED**.

- Remote `dev/v1.7` HEAD:
  `a7c4c1db79d0ec364d69b819a447b2676c6c2d17`
  (matches local `git rev-parse HEAD` byte-for-byte; verified
  via `git ls-remote origin dev/v1.7`).
- Branch created as a new remote branch (GitHub reported
  `[new branch] dev/v1.7 -> dev/v1.7`).
- No force-push, no rebase, no rewrite of shared history, no
  `main` push/merge, no tag/release.

## Q. Mandatory review state (per dispatch §N)

```
CODEX_GATE: STILL PENDING — DO NOT INVOKE
```

Justification:
- The V1.7 Blueprint §13 declares the canonical Codex xHigh
  integration review mandatory for V1.7.
- This dispatch corrected the R5-R8 findings AND fixed four
  production defects, but V1.7 is NOT ready for Codex until
  AIPM direct source review (this report's owner) reaches
  PASS.
- After AIPM PASS, the dispatch lifecycle continues with
  Codex xHigh integration review (per the V1.7 Blueprint's
  mandatory review strategy).
- Pi did NOT invoke Codex at any point in this dispatch.

```
OWNER_GATE: NOT YET RUN
```

The Owner shall run the Blueprint §19 scenarios A through G on
real SketchUp 2020 once AIPM direct source review reaches PASS
and Codex xHigh integration review also reaches PASS.

Pi did NOT run any Owner scenario (per dispatch §7 + §10).

---

## Definition of done (per dispatch §10)

- [x] R5 corrected (X1 / X2 drive the real
      `WorkingModeRunner._crossing_checker_proc`; old mirror
      tests relabeled as low-level predicate tests).
- [x] R6 corrected (X4 is a real 3-edge almost-closed
      triangle through the production path; the prior 2-line
      substitute was a real implementation bug — the clique-
      merge interaction — fixed in
      `canonical_topology_builder._build_canonical_node_record`).
- [x] R7 corrected (H3 [PRODUCTION PATH] proves 2-bridge
      batch in ONE native operation with exact count).
- [x] R8 corrected (T4 [PRODUCTION PATH] proves exact cycle
      invariant on the real fixture + T4-EXACT3 proves the
      literal 3/3 form; BFS-only connectivity explicitly NOT
      accepted).
- [x] Four production defects uncovered by running the
      production path are fixed and regression-locked
      (R5-REG-LAYER / R5-REG-FROZEN / R5-REG-CLUSTER /
      R6-NODE-IDENTITY).
- [x] `Review/V17_AIPM_SOURCE_REVIEW.patch` regenerated from
      `d7e9c59` to the final substantive HEAD; SHA-256
      recorded in §H.
- [x] `Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md` updated with
      the new disposition table, production-defect table, and
      reviewer checklist.
- [x] Full regressions green (906 / 906 Ruby + 9 RBZ smoke +
      V16 close-autodiscard + V15 host-state + LEGACY-COMPAT).
- [x] Stable local corrected HEAD exists (see §L).
- [x] `git diff --check` clean.
- [x] `CODEX_GATE: STILL PENDING — DO NOT INVOKE` recorded
      in §P.
- [x] `OWNER GATE: NOT YET RUN` recorded in §Q.
- [x] No claim of AIPM PASS / Codex PASS / Owner PASS.
- [x] V1.8 NOT STARTED.
- [x] `main` not pushed / merged.
- [x] No force-push / rebase / shared-history rewrite.

---

## STOP and return control to AIPM.

Next Gate: AIPM direct source review of
`Review/V17_AIPM_SOURCE_REVIEW.patch` + the corrected V1.7 HEAD.

Only after AIPM primary PASS: mandatory Codex xHigh integration review.

End of report.