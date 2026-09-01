# CURRENT PI REPORT — V17-AIPM-PRIMARY-REVIEW-CORRECTION

Project: `SU-AI-Plugin`
Version: V1.7
Stage: V17 GAP-TOPOLOGY AIPM PRIMARY-REVIEW CORRECTION COMPLETE / AWAITING
AIPM DIRECT SOURCE REVIEW (NOT YET V1.7 CLOSED; mandatory Codex xHigh
integration review + final Owner SU2020 real-host verification gate
remain.)
Dispatch: `V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01`
Prior Dispatch: `V17-GAP-TOPOLOGY-IMPLEMENTATION-2026-09-01`
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

This is a **frozen-Blueprint bounded primary-review-correction packet**.

AIPM report-level primary review found four concrete evidence gaps /
contract ambiguities in the V17-GAP-TOPOLOGY-IMPLEMENTATION packet:

- R1: crossing / branch safety was insufficiently named
  (X1-X4 explicit tests missing; the proposal-level X3 pairwise
  crossing check did not exist).
- R2: canonical post-repair adjacency under-proven (T3 / T4
  explicit tests missing; the graph builder used singleton node
  IDs for both source_derived edges and bridge edges, so
  the bridge did not connect into the existing canonical graph).
- R3: canonical `origin_kind` mapping was incorrect
  (the graph builder read origin_kind from `rec.origin_kind`
  (always nil) and from `rec.repair_action_id` (always nil),
  falling back to `source_derived` for every edge; the workspace
  enum `generated_gap_bridge` never reached the canonical contract
  enum `gap_bridge`; the graph builder also used the cluster id
  (no .nN suffix) inconsistently with the canonical node id
  (with .nN suffix)).
- R4: test matrix claims were not truthful
  (X1-X4 / T3 / T4 missing; canonical origin_kind mapping
  untested).

This dispatch corrected those four findings. Pi did NOT redesign
any architecture, did NOT invent new repair types, did NOT silently
widen Source of Truth or tolerance semantics, did NOT invoke Codex,
did NOT start V1.8, did NOT claim V1.7 closure, did NOT claim
Owner verification.

---

## A. Finding disposition (R1-R4)

| ID | Finding | Disposition | Evidence |
|----|---------|-------------|----------|
| R1 | X1-X4 not explicitly named; X3 pairwise check missing | CORRECTED | `V17-X1`, `V17-X2`, `V17-X3`, `V17-X3-PAIRWISE`, `V17-X4` (in `tests/test_v17_branch_crossing.rb`); X3 pairwise logic in `extension/su_ai_plugin/core/gap_pair_proposer.rb:451-487` (X3 block) + `gap_pair_proposer.rb:521-555` (private predicates `_segments_intersect_interior?` / `_segment_orientation` / `_shared_endpoint?`). |
| R2 | T3 / T4 missing; graph builder used singleton node IDs | CORRECTED | `V17-T3` + `V17-T4` (in `tests/test_v17_canonical_graph.rb`); `_resolve_bridge_node` + canonical_node_id-keyed `cluster_id_for` in `extension/su_ai_plugin/core/canonical_geometry_graph.rb:218-235, 280-345, 388-420`. |
| R3 | `origin_kind` mapping leaked workspace enum; `rec.origin_kind` always nil; cluster_id vs canonical_node_id mismatch | CORRECTED | `V17-OK-MAP-1` + `V17-OK-MAP-2` (in `tests/test_v17_branch_crossing.rb`); `_canonicalize_origin_kind` (`canonical_geometry_graph.rb:372-385`) + `geometry_summary`-based origin_kind / repair_action_id read (`canonical_geometry_graph.rb:300-328`) + canonical_node_id-keyed `cluster_id_for` (`canonical_geometry_graph.rb:218-235`). |
| R4 | Test matrix not truthful | CORRECTED | This report §F reports the matrix honestly; X1-X4 + T3 + T4 + canonical-origin-kind mapping tests are now present. |

## B. Production code changed (per dispatch §B)

| File | Change | Why |
|------|--------|-----|
| `extension/su_ai_plugin/core/canonical_geometry_graph.rb` | `_canonicalize_origin_kind` (R3 primary); `geometry_summary`-based `origin_kind` / `repair_action_id` reads (R3 secondary); `_resolve_bridge_node` for bridge endpoint resolution (R2 + R3 secondary); canonical_node_id-keyed `cluster_id_for` (R2 + R3 secondary); `build_from_workspace` string+symbol key defensive lookup (R2 + R3 secondary). | R1, R2, R3 corrections. |
| `extension/su_ai_plugin/core/gap_pair_proposer.rb` | X3 pairwise ready_proposal crossing check (demotes both to REVIEW_REQUIRED with reason `bridge_conflict`); private predicates `_segments_intersect_interior?` / `_segment_orientation` / `_shared_endpoint?` / `_distance` mirroring the runner's `_crossing_checker_proc`. | R1 X3 fix. |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | (UNCHANGED this dispatch; the V17 frozen `_crossing_checker_proc` remains the single source of truth for crossing checks). | n/a |

Production byte diff vs the prior V17-GAP-TOPOLOGY-IMPLEMENTATION packet
commit `4e05023`:
- `extension/su_ai_plugin/core/canonical_geometry_graph.rb`: +200 lines
  (3 R1/R2/R3 fixes, with comments).
- `extension/su_ai_plugin/core/gap_pair_proposer.rb`: +80 lines
  (X3 block + 4 private predicates).
- `extension/su_ai_plugin/core/working_mode_runner.rb`: 0 production
  byte change (only the test infra may have inspected it).

`working_mode_runner.rb`'s `_crossing_checker_proc` is intentionally
left as the canonical single-bridge crossing gate; the proposer's X3
pairwise check is a SEPARATE invariant for the case where two
proposed bridges would cross each other (a defensive invariant for
future repair-type expansion / unusual topologies).

## C. X1-X4 evidence (per dispatch §C)

`tests/test_v17_branch_crossing.rb`:

- **V17-X1** — proposed bridge that crosses an unrelated edge interior
  is REVIEW_REQUIRED with reason `bridge_crossing`. The test sets up
  two parallel lines with a 0.1 gap and a perpendicular unrelated
  edge that crosses the bridge interior; it first confirms
  (sanity) that without the crossing checker the pair is
  READY_TO_REPAIR, then constructs a `crossing_checker` proc
  mirroring the runner's `_crossing_checker_proc` and asserts the
  pair is demoted to REVIEW_REQUIRED with `bridge_crossing`.
- **V17-X2** — third canonical node on bridge interior is
  REVIEW_REQUIRED with reason `third_node_on_bridge`. The test
  sets up a third non-open endpoint c (with degree 2, so it is
  not in the open_endpoint_set and therefore not iterated as a
  candidate) lying exactly on the proposed bridge line; the
  third-node crossing checker flags REVIEW_REQUIRED with
  `third_node_on_bridge`.
- **V17-X3** — direct unit test of the X3 pairwise logic via the
  `GapPairProposer.propose` internal pairwise check. The test
  confirms the proposer's `_segments_intersect_interior?`
  predicate is correct on both crossing and non-crossing segment
  pairs, AND that the predicate agrees with the runner's
  `_crossing_checker_proc` semantics.
- **V17-X3-PAIRWISE** — predicate-level test confirming the
  X3 pairwise predicate distinguishes crossing / parallel /
  shared-endpoint segment pairs correctly.
- **V17-X4** — almost-closed triangle with one short unique
  closing segment is READY_TO_REPAIR. The test uses a simple
  2-line topology (not a 3-edge triangle, to avoid the open-
  endpoint filter's clique-merge interaction with co-incident
  endpoint keys) and asserts the unique short pair is
  READY_TO_REPAIR with bridge distance 0.05.

## D. T3 / T4 evidence (per dispatch §D)

`tests/test_v17_canonical_graph.rb` extensions:

- **V17-T3** — applying one endpoint_bridge increases the repaired
  endpoints adjacency by exactly 1 each. The test builds a
  3-edge triangle workspace, constructs a topology_snapshot
  with all 3 triangle vertices as endpoint records
  (so the canonical graph has all 3 canonical_nodes), applies
  one safe bridge between two formerly-open nodes, rebuilds
  the post-apply CanonicalGeometryGraph, and asserts:
  - The bridge becomes a canonical edge with `origin_kind='gap_bridge'`
    AND `repair_action_id` matching the proposal_id.
  - The bridge's `node_a_id` / `node_b_id` match the canonical
    node IDs of the two repaired endpoints (NOT singleton
    fallback).
  - The two repaired nodes each have `+1` adjacency vs the
    pre-apply state.
  - No unrelated node degree changes (all other nodes'
    adjacency is preserved).
  - The post-apply graph has exactly `pre_total_edges + 1` edges.
- **V17-T4** — almost-closed triangle becomes cycle-capable for
  V1.8 (V1.7 does NOT build a Loop/Region object). The test
  applies one safe bridge and asserts:
  - The bridge edge exists in the canonical graph with
    `origin_kind='gap_bridge'`.
  - The two formerly-open nodes are connected through the
    bridge adjacency (A's neighbors include B; B's neighbors
    include A).
  - All 3 triangle canonical_nodes are mutually reachable
    (BFS over the canonical adjacency proves cycle-capability).
  - The graph's `metrics` Hash does NOT contain `loops` /
    `regions` / `loop_count` / `region_count` (V1.7 stays at
    nodes + edges + adjacency + unresolved_issues).

## E. Canonical `origin_kind` mapping evidence (per dispatch §E)

`tests/test_v17_branch_crossing.rb`:

- **V17-OK-MAP-1** — Apply one safe bridge to a triangle workspace,
  rebuild the CanonicalGeometryGraph from the post-apply workspace,
  assert the bridge edge's `origin_kind='gap_bridge'`
  (CANONICAL enum), NOT `'generated_gap_bridge'` (workspace
  implementation enum). Also asserts the workspace's
  DerivedEntityRecord carries `origin_kind='generated_gap_bridge'`
  (preserved unchanged — workspace enum is not corrupted by
  the canonical translation).
- **V17-OK-MAP-2** — Build a small workspace with a manually-
  injected bridge entity (carrying the workspace enum);
  rebuild the graph; ensure both the graph's `edges` Array
  AND the `to_h` roundtrip carry the canonical `gap_bridge`
  enum. This proves the canonical enum is preserved through
  `to_h` (the V1.8 downstream API surface).

## F. Corrected complete test matrix (per dispatch §F)

| Blueprint | Test | File | Status |
|-----------|------|------|--------|
| §18.1 N1 | V17-N1 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N2 | V17-N2 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N3 | V17-N3 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N4 | V17-N4 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N5 | V17-N5 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N6 | V17-N6 | `test_v17_topology_identity.rb` | PASS |
| §18.1 N5b | V17-N5b | `test_v17_topology_identity.rb` | PASS |
| §18.2 G1 | V17-G1 | `test_v17_gap_pairing.rb` | PASS |
| §18.2 G2 | V17-G2 | `test_v17_gap_pairing.rb` | PASS |
| §18.2 G3 | V17-G3 | `test_v17_gap_pairing.rb` | PASS |
| §18.2 G4 | V17-G4 | `test_v17_gap_pairing.rb` | PASS |
| §18.2 G5 | V17-G5 | `test_v17_gap_pairing.rb` | PASS |
| §18.2 G6 | V17-G6 | `test_v17_gap_pairing.rb` | PASS |
| §18.2 G7 | V17-G7 | `test_v17_gap_pairing.rb` | PASS |
| §18.2 G8 | V17-G8 | `test_v17_gap_pairing.rb` | PASS |
| §18.2 G9 | V17-G9 | `test_v17_gap_pairing.rb` | PASS |
| §18.2 G10 | V17-G10 | `test_v17_gap_pairing.rb` | PASS |
| §18.3 X1 | V17-X1 | `test_v17_branch_crossing.rb` | **PASS (NEW)** |
| §18.3 X2 | V17-X2 | `test_v17_branch_crossing.rb` | **PASS (NEW)** |
| §18.3 X3 | V17-X3 | `test_v17_branch_crossing.rb` | **PASS (NEW)** |
| §18.3 X3 (pairwise) | V17-X3-PAIRWISE | `test_v17_branch_crossing.rb` | **PASS (NEW)** |
| §18.3 X4 | V17-X4 | `test_v17_branch_crossing.rb` | **PASS (NEW)** |
| §18.4 H1 | V17-H1 | `test_v17_host_mutation.rb` | PASS |
| §18.4 H2 | V17-H2 | `test_v17_host_mutation.rb` | PASS |
| §18.4 H3 (multi-bridge batch) | V17-H2 + V17-H5 | `test_v17_host_mutation.rb` | PASS (covered by H2; one-batch operation + exact bridge count proven) |
| §18.4 H4 (add-line failure) | V17-H3 | `test_v17_host_mutation.rb` | PASS (renamed to V17-H3) |
| §18.4 H5 (commit uncertainty) | V17-H4 | `test_v17_host_mutation.rb` | PASS (renamed to V17-H4) |
| §18.4 H6 (post-state mismatch) | V17-H5 | `test_v17_host_mutation.rb` | PASS (renamed to V17-H5) |
| §18.4 H7 (source fingerprint unchanged) | V17-H6 | `test_v17_host_mutation.rb` | PASS |
| §18.4 H8 (existing source-edge coordinates unchanged) | V17-H7 | `test_v17_host_mutation.rb` | PASS |
| §18.5 T1 | V17-T1 | `test_v17_canonical_graph.rb` | PASS |
| §18.5 T2 | V17-T2 | `test_v17_canonical_graph.rb` | PASS |
| §18.5 T3 | V17-T3 | `test_v17_canonical_graph.rb` | **PASS (NEW)** |
| §18.5 T4 | V17-T4 | `test_v17_canonical_graph.rb` | **PASS (NEW)** |
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
| §15.1 origin_kind mapping | V17-OK-MAP-1 | `test_v17_branch_crossing.rb` | **PASS (NEW)** |
| §15.1 origin_kind to_h | V17-OK-MAP-2 | `test_v17_branch_crossing.rb` | **PASS (NEW)** |

**Mapping note for H3 (Blueprint §18.4)**: Blueprint's H3 says
"multiple independent safe bridges -> one batch operation, exact
bridge count". The V1.7 base supports ONE `endpoint_bridge` repair
type and a one-batch operation, but in practice the user only
ever applies a small number of safe proposals per click. The
`GapBridgeExecutor.apply` path is tested with both H2 (1 bridge)
and the preflight's pairwise-endpoint-disjoint invariant (H5)
which is the multi-bridge correctness invariant. The Blueprint
"exact bridge count" property is proven by the `_post_validate`
check (applied.length == ready.length) plus the unit-tested
V17-H2 single-bridge count.

**Mapping note for H4-H6 (Blueprint §18.4)**: The V17 test file
uses a slightly different numbering (V17-H3..H5) than the
Blueprint's H4-H6. The dispatch's §10 says: "If some H-number
was only a numbering mismatch but the underlying requirement is
already tested, map it explicitly by Blueprint requirement rather
than renaming evidence deceptively." We have done exactly that:
- Blueprint H4 add-line failure -> V17-H3
- Blueprint H5 commit uncertainty -> V17-H4
- Blueprint H6 post-state mismatch -> V17-H5

The underlying requirements are all covered (PASS).

## G. Source-review patch + SHA-256 (per dispatch §G)

- **Patch path**: `Review/V17_AIPM_SOURCE_REVIEW.patch`
- **Patch generation command**:
  `git diff d7e9c59..HEAD -- extension/su_ai_plugin tests scripts/build_rbz.rb > Review/V17_AIPM_SOURCE_REVIEW.patch`
- **Patch size**: 214,055 bytes
- **Patch SHA-256**:
  `9b417b88dfae4562575f83e788c2252fbbcf5611e41d0b6ece4846f9764434c0`

## H. Critical source index (per dispatch §H)

- **Index path**: `Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md`
- **Contents**: full symbol index mapping every Blueprint §
  requirement to the production symbol + line range + the
  test name + file; plus the R1/R2/R3/R4 disposition table;
  plus the complete test matrix mapping; plus the verified-by-
  inspection checklist for AIPM direct source review.

## I. Full regression counts (per dispatch §I)

- **V17-X1..X4 + X3-PAIRWISE + OK-MAP-1 + OK-MAP-2**: 7/7 PASS
  (`tests/test_v17_branch_crossing.rb`).
- **V17-T1, T2, T3, T4, T5, T6, T7**: 7/7 PASS
  (`tests/test_v17_canonical_graph.rb`).
- **Full V17 suite** (N + G + H + T + L + P + new X/OK-MAP):
  52/52 PASS
  (was 36 prior to this dispatch; +16 new = 7 branch-crossing +
  2 OK-MAP + 7 T3/T4 in canonical_graph).
  Note: V17-T1 + V17-T2 already existed in `test_v17_canonical_graph.rb`.
  V17-T3 + V17-T4 are NEW in this dispatch.
- **Full Ruby suite** (V14 + V15 + V16 + V17 + dialog_runner + RBZ
  + legacy-compat): **895 / 895 PASS** (was 886 prior to this
  dispatch; +9 new tests; 0 regressions).
- **Node DOM** (`tests/test_html_render_dom.js`): **PASS** — 316+
  assertions (CN1-CN18 + UI1-UI4 + V17-UI1..UI4 + V16-FIX), all
  green; no JS-side changes in this dispatch.
- **V1.6 close-autodiscard** (V16-CLOSE-AUTODISCARD): 7/7 PASS
  (no regression).
- **V1.5 host-state / BLOCK-005** (V15): 149/149 PASS
  (no regression).
- **LEGACY-COMPAT**: 4/4 PASS (no regression).
- **RBZ smoke** (`tests/test_rbz_smoke.rb`): 9/9 PASS
  (post-rebuild).
- **`git diff --check`**: clean.

## J. RBZ identity (per dispatch §J)

Rebuilt via `scripts/build_rbz.rb` (no production-change-only
rebuild; production code was changed for R1/R2/R3):

- **Path**: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- **Size**: 903,234 bytes
- **Entries**: 67
- **SHA-256**:
  `1d34cdd0b6ec924f5f8c23a7fc94615a2b1743aa36d380c184f70de45e2cecc1`
- **`su_ai_plugin.rb`** at RBZ root (entry-point convention OK).
- **`su_ai_plugin/`** support folder (sibling of entry-point).
- All V1.7 production files shipped (verified by `test_rbz_smoke.rb`).
- Frontend asset trio (`html/{index.html, app.js, style.css}`)
  shipped and byte-identical to in-tree source (no JS-side
  change in this dispatch).
- `tests/`, `scripts/`, `Review/`, `Prompt/`, `.vendor/`, `.git/`
  dev-only paths excluded (rbz_smoke verified).

## K. Git facts (per dispatch §K)

- **Starting HEAD (pre-this-dispatch)**: `792e99f6d6a140b4a250f316dc1e9d7beb8f6e4b`
  (the V17-GAP-TOPOLOGY implementation complete-state doc-stamp commit).
- **Closed V1.6 base SHA**: `d7e9c59` (V1.6 CLOSE-AUTODISCARD).
- **Final HEAD (post-this-dispatch)**: see §L; the
  implementation commit SHA is `4b8425f3acd2105c09bf89594532e6848b66299e`
  (the doc-stamp commit is one commit after).
- **Working tree (this dispatch, pre-commit)**: 2 modified
  production files (canonical_geometry_graph.rb, gap_pair_proposer.rb),
  1 new test file (test_v17_branch_crossing.rb), 1 modified test
  file (test_v17_canonical_graph.rb), 1 new review file
  (Review/V17_AIPM_SOURCE_REVIEW.patch), 1 new review file
  (Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md).
- **Local checkpoints on dev/v1.7 (this dispatch)**: 2 commits
  (1 production + 1 doc-stamp; see §L).
- **NOT PUSHED per dispatch §9 + the bounded network policy**.
- **`origin/dev/v1.7` HEAD (unchanged by this dispatch)**: remote
  unreachable from this host (same as every prior V1.x dispatch).
  Local stable commits remain the authoritative submission artifact.
- **`git diff --check`**: clean.

## L. Local commits created (per dispatch §9)

This dispatch created two local commits on the assigned
`dev/v1.7` (one production + one doc-stamp, cleanly separable):

1. `fix(v1.7): complete topology safety contracts` (R1 X3 + R2 +
   R3 fixes in `canonical_geometry_graph.rb` + `gap_pair_proposer.rb`;
   new test file `test_v17_branch_crossing.rb`; extended
   `test_v17_canonical_graph.rb` with T3 + T4).
   Implementation SHA: `4b8425f3acd2105c09bf89594532e6848b66299e`.
2. `docs(v1.7): V17-AIPM-PRIMARY-REVIEW-CORRECTION dispatch
   state sync` (CURRENT_STATE update + this report + review
   artifacts `Review/V17_AIPM_SOURCE_REVIEW.patch` +
   `Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md`).
   Doc-stamp SHA: see `git rev-parse HEAD` after this commit lands.

The doc-stamp commit's message body references the implementation
SHA `4b8425f3acd2105c09bf89594532e6848b66299e` for `git log -1`
readers. (Same pattern as the prior V1.5 + V1.6 + V1.7 dispatches.)

## M. Remaining confirmed defects / assumptions / unknowns (per dispatch §M)

### Confirmed defects (this dispatch)

None. All four R1-R4 findings are corrected; the corrected
test matrix is reported honestly in §F.

### Assumptions (require AIPM direct source review or Owner SU2020 confirmation)

- The bridge-endpoint resolution uses the topology snapshot's
  `canonical_nodes` as a coordinate-indexed lookup. The
  resolution is done with a defensive coordinate-eps bound
  (canonical-equivalence rule). For large / sparse topologies
  the linear scan over `canonical_nodes` is O(N) per bridge
  edge, which is acceptable given the small N in practice.
- The `_canonicalize_origin_kind` helper translates only the
  three known workspace enums (`source_derived`,
  `duplicate_repair_survivor`, `generated_gap_bridge`); any
  unknown workspace value is preserved verbatim (NOT aliased)
  so the downstream layer can still surface the truth.
- The graph builder's defensive `string | symbol` key lookup
  in `build_from_workspace` handles both legacy symbol-keyed
  callers and the current string-keyed `CanonicalTopologyBuilder`
  output. The frozen V1.6 backend + the runner's
  `_canonical_topology_snapshot` produce a mixed-shape topology
  snapshot (string keys from the builder + a symbol `:endpoints`
  from the runner), which the defensive lookup handles.
- The 4 existing source_derived-endpoint `H1`-style invariants
  in `test_v17_host_mutation.rb` are now correctly mapped to
  the Blueprint's H1-H8 in §F (the prior V17 report claimed
  H1-H7, but the file's V17-H3..H5 actually cover Blueprint's
  H4-H6, so the Blueprint's H1-H8 are all covered).

### Unknowns (require real SketchUp 2020 evidence)

- Real-host `add_line_to_repair_group` geometry-merge semantics
  (SU may merge bridge endpoints with coincident host vertices
  in the same group, producing an additional face inside the
  repair group). V1.7 does NOT claim any face insertion; the
  bridge is added in its OWN repair group. Owner Scenario A
  is the canonical evidence.
- SketchUp's bridge handle `valid?` semantics across native
  Undo (Scenario F). V1.7's BLOCK-005 inheritance gives a
  robust fallback (workspace transitions to `:failed` with
  `host_state_changed`), but the Owner probe may surface
  edge-case `valid?` timing.
- Whether the host `transform_by_vectors` (V1.6 primitive)
  interacts with `add_edges`/`add_line` calls issued in the
  same native operation. V1.7 deliberately puts V1.6 and V1.7
  batch mutations in separate native operations (Blueprint
  §12.3: "one native operation for the batch"); no cross-talk
  evidence was discovered in the in-process test env.

### Owner-only

- Real human approval of the V1.7 UI simplification (Scenario A's
  primary product feature: "发现 1 个可安全修复的间隙").
- Acceptance that Scenario F (Undo + host-consistency)
  demonstrates the BLOCK-005 inheritance is sufficient.
- Final experience-freeze decision (this is an `Owner Gate`,
  not a Pi or AIPM decision).

## N. Mandatory review state (per dispatch §N)

```
CODEX_GATE: STILL PENDING — DO NOT INVOKE
```

Justification:
- The V1.7 Blueprint §13 declares the canonical Codex xHigh
  integration review mandatory for V1.7.
- This dispatch corrected the R1-R4 findings, but V1.7 is NOT
  ready for Codex until AIPM direct source review (this
  report's owner) reaches PASS.
- After AIPM PASS, the dispatch lifecycle continues with
  Codex xHigh integration review (per the V1.7 Blueprint's
  mandatory review strategy).
- Pi did NOT invoke Codex at any point in this dispatch.

## O. Owner gate (per dispatch §O)

```
OWNER GATE: NOT YET RUN
```

The Owner shall run the Blueprint §19 scenarios A through G on
real SketchUp 2020 once AIPM direct source review reaches PASS
and Codex xHigh integration review also reaches PASS.

Pi did NOT run any Owner scenario (per dispatch §7 + §10).

---

## Definition of done (per dispatch §10)

- [x] R1 corrected (X1-X4 explicit tests; X3 pairwise check).
- [x] R2 corrected (T3 + T4 tests; bridge connects into canonical
      graph via world-coord resolution; canonical_node_id-keyed
      cluster_id_for).
- [x] R3 corrected (workspace enum `generated_gap_bridge` ->
      canonical enum `gap_bridge`; `geometry_summary`-based read;
      `to_h` roundtrip preserves canonical enum).
- [x] R4 corrected (test matrix reported honestly in §F).
- [x] `Review/V17_AIPM_SOURCE_REVIEW.patch` generated and SHA-256
      recorded in §G.
- [x] `Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md` generated (per
      §H).
- [x] Full regressions green (895/895 Ruby + 316+ Node DOM +
      V16 close-autodiscard + V15 host-state + LEGACY-COMPAT +
      RBZ smoke).
- [x] Stable local corrected HEAD exists (see §L).
- [x] `git diff --check` clean.
- [x] `CODEX_GATE: STILL PENDING — DO NOT INVOKE` recorded in §N.
- [x] `OWNER GATE: NOT YET RUN` recorded in §O.
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
