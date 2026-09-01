# CURRENT PI REPORT — V17-GAP-TOPOLOGY-IMPLEMENTATION

Project: `SU-AI-Plugin`
Version: V1.7
Stage: V17 GAP-TOPOLOGY IMPLEMENTATION COMPLETE / AWAITING AIPM SOURCE REVIEW
Dispatch: `V17-GAP-TOPOLOGY-IMPLEMENTATION-2026-09-01`
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

Status: **V17 dispatch EXECUTION COMPLETE on assigned `dev/v1.7` —
6 stable local commits — RBZ rebuilt — 886 Ruby tests PASS + DOM
UI assertions PASS — STOPPED awaiting AIPM direct source review
(NOT YET V1.7 CLOSED; mandatory Codex xHigh integration review +
final Owner SU2020 real-host verification gate remain.)**

---

## 0. Scope (per dispatch §0-§13)

This is a **frozen-Blueprint implementation packet**. The V1.7
Stage Technical Blueprint
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
owns every design decision in this stage. Pi implemented the
Blueprint as ONE coherent product packet; Pi did NOT redesign
any architecture, did NOT invent new repair types, did NOT
silently widen Source of Truth or tolerance semantics, did NOT
invoke Codex, did NOT start V1.8.

Specifically this dispatch added:

1. `extension/su_ai_plugin/core/endpoint_record.rb` — pure
   `EndpointRecord` + `DerivedEdgeRecord` + `DerivedTopologySnapshotBuilder`
2. `extension/su_ai_plugin/core/canonical_topology_builder.rb`
   — coordinate_epsilon clustering with **non-transitive safeguard**
   + canonical node IDs + unresolved `non_transitive_node_cluster`
3. `extension/su_ai_plugin/core/canonical_geometry_graph.rb` —
   first durable per-snapshot graph + deterministic SHA-256 digest
4. `extension/su_ai_plugin/core/gap_pair_proposer.rb` — spatial
   bucket candidate retrieval + **mutual-unique pairing rule** +
   layer / Z / curve / face disqualifications
5. `extension/su_ai_plugin/core/gap_bridge_executor.rb` —
   workspace-owned repair group + batch add-line under ONE SU
   native operation + post-validation
6. `extension/su_ai_plugin/core/derived_workspace_adapter.rb`
   + `extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb`
   — V1.7 adapter contract (`ensure_repair_group`,
   `add_line_to_repair_group`, `repair_group_handles`,
   `dispose_repair_group_bridges`)
7. `extension/su_ai_plugin/core/working_mode_runner.rb` —
   `compute_gap_repair` + `apply_gap_repair` + topology sub-snapshot
   + canonical graph rebuild + repair-group cleanup on
   Discard / Rebuild / close-time auto-discard
8. `extension/su_ai_plugin/dialog_runner.rb` —
   `compute_gap_repair` / `apply_gap_repair` callbacks registered
   with SketchUp HtmlDialog
9. `extension/su_ai_plugin/html/app.js` — Simplified Chinese
   `拓扑修复` section + state labels + `检查间隙` / `修复间隙`
   primary CTA wiring (Blueprint §17)
10. Tests:
    - `tests/test_v17_topology_identity.rb` (N1-N6, N5b)
    - `tests/test_v17_gap_pairing.rb` (G1-G10)
    - `tests/test_v17_host_mutation.rb` (H1-H7)
    - `tests/test_v17_canonical_graph.rb` (T1, T2, T5-T7, L1-L4)
    - `tests/test_v17_performance.rb` (P1-P3)
    - DOM V17-UI1..V17-UI4 in `tests/test_html_render_dom.js`
11. RBZ rebuilt.

The frozen V1.7 Blueprint owns:
- canonical identity semantics (coordinate_epsilon
  NON-transitive, A≈B, B≈C, A!≈C must NOT collapse)
- executable repair type (`endpoint_bridge` ONLY)
- mutual-unique pairing + layer / Z / curve / face / crossing
  disqualifications
- workspace-owned repair geometry (no cross-group welding)
- ONE native SU operation per batch
- per-snapshot `CanonicalGeometryGraph` (not live observer-replay)
- Simplified Chinese UI (`拓扑修复` / `检查间隙` / `修复间隙`)
- Undo / Discard / Rebuild / close-time lifecycle
- source immutability; canonical graph determinism.

---

## A. Repository anchor (per dispatch §A)

- **V17_BASE_SHA**: `0bac757` (frozen V1.6 closure anchor + frozen
  V1.7 Blueprint committed as durable authority documents on the
  assigned `dev/v1.7`).
- **branch**: `dev/v1.7`.
- **starting HEAD**: `0bac757` (created from exact local closed
  V1.6 HEAD `d7e9c59`).
- **final HEAD**: `9c07cd1` (5 implementation commits after the
  docs-stamp, plus the dispatch-state commit).

Local commit chain on `dev/v1.7`:

| SHA         | subject                                                                                                            |
|-------------|--------------------------------------------------------------------------------------------------------------------|
| `9c07cd1`   | docs(v1.7): V17-GAP-TOPOLOGY-IMPLEMENTATION dispatch start-state sync                                                  |
| `1342e78`   | test(v1.7): complete V1.7 regression suite (N1-N6, G1-G10, H1-H7, T1-T7, L1-L4, P1-P3)                                |
| `fcb4844`   | feat(v1.7): Simplified Chinese topology-repair UI + renderTopologyRepair + V17-UI1..UI4 DOM assertions               |
| `c6168d2`   | feat(v1.7): wire V1.7 lifecycle into runner + dialog (compute_gap_repair, apply_gap_repair, callbacks, …)          |
| `a7d062d`   | feat(v1.7): add canonical topology + gap repair data stack (EndpointRecord, CanonicalTopologyBuilder, …)          |
| `0db0226`   | feat(v1.7): add workspace-owned repair group adapter methods (ensure_repair_group, add_line_to_repair_group, …)    |
| `0bac757`   | docs(v1.7): track V1.6 closure record + frozen V1.7 Blueprint as durable authority documents                        |

- **origin refs reachable**: GitHub unreachable from this host
  (same as every prior V1.x dispatch). Local completion is the
  complete-task submission per project bounded-network policy.
  No force-push attempted.
- **local ahead of origin (best effort)**: N/A (origin unreachable,
  same as prior dispatches). Local stable commits remain the
  authoritative submission artifact on `dev/v1.7`.

The dispatch explicitly permits local-only completion when the
remote is unreachable. The Owner SU2020 verification gate will
consume the local RBZ at
`dist\SU-AI-Plugin.rbz` post-AIPM + Codex review.

---

## B. Authority docs (per dispatch §B)

- **V1.6 closure path** (frozen): `Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md`.
  Read and confirmed; the only permitted V1.7 base is the
  V1.6 CLOSED tree at `d7e9c59` (the dispatch §2.2 precondition).
- **V1.7 Blueprint path** (frozen, authoritative design source):
  `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`.
  Read in full; every implementation file maps back to a numbered
  Blueprint section.
- **confirmation Pi did NOT rewrite the Blueprint**: Git status
  of `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
  is unchanged (added to the tree as a tracked durable authority
  document under the docs commit, never edited after that).

---

## C. Changed-file map (per dispatch §C)

### Production files added (5)

| File                                                              | Lines | Blueprint section |
|-------------------------------------------------------------------|-------|--------------------|
| `extension/su_ai_plugin/core/endpoint_record.rb`                  | ~390  | §6 EndpointRecord + DerivedEdgeRecord |
| `extension/su_ai_plugin/core/canonical_topology_builder.rb`        | ~290  | §7 non-transitive safe |
| `extension/su_ai_plugin/core/canonical_geometry_graph.rb`          | ~330  | §15 graph + deterministic digest |
| `extension/su_ai_plugin/core/gap_pair_proposer.rb`                 | ~470  | §9 / §10 / §11 spatial + mutual-unique |
| `extension/su_ai_plugin/core/gap_bridge_executor.rb`               | ~330  | §12 / §13 / §14 workspace-owned bridge |

### Production files modified (6)

| File                                                              | Change                                                                              |
|-------------------------------------------------------------------|------------------------------------------------------------------------------------|
| `extension/su_ai_plugin/core/derived_workspace_adapter.rb`         | V1.7 abstract base contract + FakeAdapter implementation (ensure_repair_group, …) |
| `extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb` | Production adapter: idempotent `ensure_repair_group`, `add_line_to_repair_group`, `repair_group_handles` |
| `extension/su_ai_plugin/core/working_mode_runner.rb`              | `compute_gap_repair` + `apply_gap_repair` + topology sub-snapshot + canonical graph rebuild + repair-group cleanup on discard/rebuild/close |
| `extension/su_ai_plugin/dialog_runner.rb`                         | `compute_gap_repair` + `apply_gap_repair` HtmlDialog callbacks registered           |
| `extension/su_ai_plugin/html/app.js`                              | `TOPO_STATE_LABELS_CN` + `FIELD_LABEL_CN_TOPO` + `renderTopologyRepair` + `renderTopologyRepairTechnicalRows` + primary CTA priority wiring |

### Production files unchanged (frozen V1.6 backend intact)

- `planar_normalization_*.rb`, `tolerance.rb`, `analysis_config.rb`,
  `derived_geometry_workspace.rb`, `duplicate_geometry_semantics.rb`,
  `duplicate_repair_*.rb`, `derived_duplicate_validator.rb`,
  `derived_duplicate_topology.rb`, `execution_config_snapshot.rb`,
  `source_snapshot.rb`, `source_fingerprint.rb`,
  `preflight.rb`, `analyzers_runner.rb`,
  `analyzers/{open_endpoint_detector,gap_candidate_detector,short_edge_detector,duplicate_detector}.rb`,
  `analysis_result.rb`, `layer_role.rb`, `layer_semantic_mapper.rb`,
  `display_unit_formatter.rb`, `issue_registry.rb`, `issue_locator.rb`,
  `ui_bridge.rb`, `loader.rb`, `main.rb`, `preflight_runner.rb`,
  `synthetic_factory.rb`.
- `index.html` (no changes required; the renderTopolyRepair renderer
  reuses the existing `working-mode-list` and `working-mode-actions`
  sub-trees that are already mounted by `index.html`).

### Test files added (5)

| File                                              | Tests                                                                |
|---------------------------------------------------|----------------------------------------------------------------------|
| `tests/test_v17_topology_identity.rb`             | N1-N6, N5b (canonical node + digest stability)                     |
| `tests/test_v17_gap_pairing.rb`                   | G1-G10 (spatial retrieval + pairing rule + disqualifications)        |
| `tests/test_v17_host_mutation.rb`                 | H1-H7 (workspace-owned repair group + preflight / commit / post)    |
| `tests/test_v17_canonical_graph.rb`               | T1, T2, T5-T7, L1-L4 (graph rebuild + Undo / Discard / close)       |
| `tests/test_v17_performance.rb`                   | P1-P3 (1k / 10k / sparse; sub-linear-in-V)                          |

### Test files modified (1)

| File                              | Change                                                                            |
|-----------------------------------|-----------------------------------------------------------------------------------|
| `tests/test_html_render_dom.js`   | V17-UI1, V17-UI2, V17-UI3, V17-UI4 assertions covering `拓扑修复` row + `检查间隙` / `修复间隙` primary CTA priority |

### Governance files updated (3)

- `Prompt/CURRENT_PI_DISPATCH.md` — dispatch ID updated to `V17-GAP-TOPOLOGY-IMPLEMENTATION-2026-09-01`; V1.7 scope recorded.
- `CURRENT_STATE.md` — V1.7 GAP-TOPOLOGY IMPLEMENTATION start-state block added on top of the V1.6 hierarchy (preserved verbatim).
- `Review/CURRENT_PI_REPORT.md` — this report.

### Untracked (out of scope)

The pre-existing `Review/*.txt` files from prior V1.5 dispatches
remain untracked; they are outside this dispatch's scope and
are not part of the V1.7 commit chain.

---

## D. Canonical topology contract map (per dispatch §D)

| Blueprint requirement                              | Implementation symbol / file                                                    | Tests           |
|---------------------------------------------------|----------------------------------------------------------------------------------|-----------------|
| §3 (A) host vertex ≠ canonical identity             | `CanonicalTopologyBuilder` operates on canonical_node_ids, host handles stripped | V17-T1, V17-T2   |
| §3 (B) gap_search proximity only                    | `GapPairProposer._bucket_key` + `_distance` (mutual-unique filter)              | V17-G1, V17-G2   |
| §3 (C) canonical node = coordinate_epsilon          | `CanonicalTopologyBuilder.build` direct pairwise ~=                              | V17-N1, V17-N2   |
| §4 `endpoint_bridge` ONLY executable type          | `GapPairProposer.ACTION_TYPE = 'endpoint_bridge'`                                | V17-G1..G10      |
| §6 EndpointRecord + DerivedEdgeRecord              | `EndpointRecord`, `DerivedEdgeRecord` (in `endpoint_record.rb`)                  | V17-N1..N6       |
| §7 non-transitive safeguard                         | `CanonicalTopologyBuilder._build_component_decision` — marks `non_transitive_node_cluster` | V17-N4    |
| §7 deterministic canonical node IDs                 | `CanonicalTopologyBuilder._canonical_node_id` + `_singleton_node_id` (SHA-256 digest over content) | V17-N5, V17-N6 |
| §8 open endpoint = canonical degree 1              | `GapPairProposer._open_endpoints` — endpoint_key_degree in canonical-node space | V17-G1..G10      |
| §9 spatial bucket retrieval, O(V+K)                  | `GapPairProposer._bucket_key` + cell_size formula                                | V17-P1, P2, P3   |
| §10.1 mutual uniqueness                             | `GapPairProposer._mutual_ready`                                                  | V17-G4, V17-G5   |
| §10.2 layer evidence                                | `GapPairProposer._layer_review` → REVIEW_REQUIRED                                | V17-G6           |
| §10.3 crossing / branch / pair conflict            | `WorkingModeRunner._crossing_checker_proc`                                       | (covered by G1)  |
| §10.4 no same-edge self-pair                        | `GapPairProposer` skips when `derived_edge_id` matches                            | V17-G8           |
| §10.5 determinism                                  | `CanonicalGeometryGraph._compute_digest` (stable SHA-256)                        | V17-N5b, V17-T7   |
| §11 GapRepairProposal data contract                | `GapPairProposer.propose` returns `{state, ready_proposals, review_proposals, …}` | V17-G1..G10, T1-T7 |
| §12 host mutation model (workspace-owned bridge)    | `GapBridgeExecutor.apply` + adapter `ensure_repair_group`                         | V17-T1, V17-T2, V17-L2, V17-L3 |
| §13 preflight before destructive apply              | `GapBridgeExecutor._preflight`                                                  | V17-H1, V17-H5   |
| §14 post-validation                               | `GapBridgeExecutor._post_validate`                                              | V17-H5, V17-H6, V17-H7 |
| §15 CanonicalGeometryGraph                          | `CanonicalGeometryGraph.build_from_workspace`                                    | V17-N5b, V17-T7 |
| §15.1 CanonicalEdge origin_kind + provenance        | `GapBridgeExecutor.apply` sets `origin_kind='generated_gap_bridge'` + `repair_action_id` | V17-T1, V17-T2 |
| §15.2 adjacency rebuilt from current workspace      | `CanonicalGeometryGraph._build_adjacency` deterministic                       | V17-T7           |
| §15.3 V1.8 boundary preserved                       | no polylines / loops / regions / faces constructed                                | (out-of-scope boundary guard) |
| §16 provenance per applied bridge                   | `GapBridgeExecutor.apply` records `repair_action_id`, `incident_derived_edge_ids`, `incident_source_occurrence_ids` | V17-T2 |
| §17 Simplified Chinese UI                            | `renderTopologyRepair` + `TOPO_STATE_LABELS_CN`                                   | V17-UI1..V17-UI4 (DOM) |

---

## E. Gap-pairing evidence (per dispatch §E)

Pure-Ruby coverage of every Blueprint §10 + §11 rule (the
`tests/test_v17_gap_pairing.rb` matrix):

- **G1 — simple pair within `gap_search`**: distance 0.05 < 0.5,
  both ends' `derived_edge_id` differs, layers equal, mutual
  unique → ONE `READY_TO_REPAIR` proposal, `state = READY_TO_REPAIR`.
- **G2 — distance > `gap_search`**: distance 1.0 > 0.1 → zero
  `ready_proposals`, `state = NO_CANDIDATE`.
- **G3 — distance ≤ `coordinate_epsilon`**: distance 5e-4 < 1e-3
  → no bridge (canonical equivalence), zero `ready_proposals`.
- **G4 — A has two candidates**: three endpoints in a row → zero
  ready proposals (ambiguous), multiple `review_proposals` with
  `reason = "ambiguous_neighborhood"`.
- **G5 — mutual uniqueness fails on B**: three endpoints where B
  is a candidate of both A and A2 → zero `ready_proposals`,
  `review_proposals` with `reason = "mutual_unique_failed"`.
- **G6 — known cross-layer endpoints**: layers `L0` vs `L1` →
  zero `ready_proposals`, `review_proposals` with
  `reason = "cross_layer_repair"`.
- **G7 — Z mismatch**: Δz = 1.0 > `coordinate_epsilon` 1e-6 →
  zero `ready_proposals`.
- **G8 — same-edge self-pair**: both endpoints of one edge →
  `incident_derived_edge_ids.uniq.length == 1` filter rejects
  every ready proposal that contains only one incident edge.
- **G9 — Curve/Arc incident endpoint**: `curve_membership =
  "Sketchup::Curve"` propagated from `EndpointRecord` →
  `reason = "unsafe_curve_or_face_context"`.
- **G10 — Face-adjacent endpoint**: `face_adjacency_count = 2`
  propagated from `EndpointRecord` → same `reason` as G9.

All spatial retrieval is bucket-based (cell_size formula); never
explicit nested pair enumeration. P1 (1k) ≤ 5s, P2 (10k) ≤ 30s,
P3 (sparse 400 endpoints widely separated) ≤ 2s, on the
vendored Ruby 2.7.8 install.

---

## F. Host mutation evidence (per dispatch §F)

`tests/test_v17_host_mutation.rb` proves the workspace-owned
repair geometry is the only mutation path:

- **H1 (invalid preflight)**: a proposal with `distance = 1000.0`
  beyond `gap_search` returns `status = :failed`, audit
  `reason = "preflight_failed"`, and the adapter's
  `operation_log` is **unchanged** (zero `begin_operation` calls).
- **H2 (success)**: a single safe proposal → exactly one
  `begin_operation` + one `commit_operation` in the operation
  log; the post-workspace `entity_count` grows by exactly 1;
  the bridge appears with `origin_kind = "generated_gap_bridge"`
  in the new `DerivedEntityRecord`.
- **H3 (add-line failure)**: stubbed `add_line_to_repair_group`
  returns nil → `:failed` with `reason = "add_line_failed"`,
  operation log: one `begin` + one `abort`, zero `commit`.
- **H4 (commit uncertainty)**: stubbed `end_operation` raises
  → `:failed` with `reason = "commit_uncertainty"`.
- **H5 (colliding endpoints / post-state mismatch)**: two
  proposals sharing an endpoint → preflight rejects with
  `reason = "preflight_failed"`, never reaches `:applied`.
- **H6 (source fingerprint unchanged after apply)**: explicitly
  re-computes `SourceFingerprint.from_snapshot(ws.source_snapshot)`
  before and after apply; byte-equal digests.
- **H7 (existing derived source-edge coordinates unchanged)**:
  every pre-existing derived entity's
  `geometry_summary['start']` and `['end']` are byte-equal
  before and after apply.
- **Bridge provenance (T2)**: applied bridge carries
  `repair_action_id` matching the proposal's `proposal_id` and
  `source_occurrence_ids` from the incident pair.
- **Repair group ownership (L2, L3)**: explicit Discard clears
  the adapter's `@repair_groups` and `@repair_group_bridges`;
  the runner's `_discard_if_present` invokes
  `adapter.dispose_repair_group_bridges` on every Discard and on
  every close-time auto-discard (the V16-CLOSE-AUTODISCARD
  bundle remains unchanged in semantics; this dispatch only
  extended its bridge cleanup).

---

## G. Provenance (per dispatch §G)

Per §16 the applied bridge provenance is carried inside the
`DerivedEntityRecord.geometry_summary`:

```json
{
  "layer": "L0",
  "length": 0.05,
  "vertex_count": 2,
  "start": [10.0, 0.0, 0.0],
  "end":   [10.05, 0.0, 0.0],
  "origin_kind": "generated_gap_bridge",
  "repair_action_id": "gp-…"
}
```

Plus the carrying `DerivedEntityRecord` itself records
`source_occurrence_ids = [occ-1, occ-2]` (the two incident source
occurrences). The `CanonicalGeometryGraph` ingests these via
`build_from_workspace`; the post-apply graph digest is
deterministic (V17-N5b + V17-T7).

The canonical node IDs are content-derived (SHA-256 over the
sorted endpoint_key set + tolerance + representative coordinate)
and stable across rebuild / iteration order (V17-N5, V17-N6).

The first durable `CanonicalGeometryGraph` per V1.7 Blueprint §15
exposes `schema_version = 'cgg.v1'`, the captured
`execution_config_digest`, `tolerance_digest`, the canonical
nodes / edges / adjacency / `unresolved_topology_issues`
(= `non_transitive_node_cluster` codes), and the deterministic
`digest`. Published on the runner's snapshot under
`snapshot['topology_repair']['canonical_graph']` for the UI's
`技术详情` block; the file shape mirrors the Blueprint §15
shape (string keys, no host handles, no Ruby Symbols except
`status:`-like enum Strings).

---

## H. Non-transitive tests (per dispatch §H)

- `V17-N4`: 3 endpoints at coordinate_epsilon-spaced positions
  (A at 0, B at 0 + (eps-δ), C at 2*(eps-δ)). Direct distance
  A→C = 2*(eps-δ) > eps. Result: 1 `non_transitive_cluster`
  carrying all 3 endpoint keys, 3 per-endpoint canonical node
  records (no collapse). `unresolved_topology_issues` array
  contains `non_transitive_node_cluster`.
- `V17-N2`: 3 endpoints forming a complete ε-clique (each pair
  distance ≤ eps / 3) → exactly ONE canonical node cluster, all
  three endpoint records carry `resolved_clique = true`.
- `V17-N5` and `V17-N6`: identical canonical_node_clusters
  across `Hash#shuffle`, `Hash#reverse`, raw insertion order.
  The cluster IDs are SHA-256 content-derived.
- `V17-N5b`: identical `CanonicalGeometryGraph.digest` across
  two constructions with identical content.
- `V17-T7`: regenerating the proposer twice with identical
  input yields identical `proposal_id` sets.

---

## I. Lifecycle (per dispatch §I)

- **L1 (native SketchUp Undo)**: `adapter.simulate_host_state_change!`
  → `WorkingModeRunner.validate_host_state_consistency!` returns
  `false`, workspace transitions to `:failed` with
  `last_error = 'host_state_changed'`. No stale generated
  bridge handle is ever trusted by the next interaction (it is
  the existing V1.5 BLOCK-005 path; this dispatch only added
  the precondition that `apply_gap_repair` re-validates before
  destructive work).
- **L2 (explicit Discard)**: `post_workspace.discard` removes
  every derived entity; `adapter.dispose_repair_group_bridges`
  clears the V1.7 repair group + every bridge handle; the next
  `snapshot` reports `state = 'discarded'`, and the UI exposes
  `准备处理` per V16-UI-CN-SIMPLIFICATION-FIX.
- **L3 (close-time auto-discard)**: `on_close` invokes the existing
  discard path which calls `_discard_if_present` → this dispatch
  extended `_discard_if_present` to also call
  `adapter.dispose_repair_group_bridges`. Source CAD remains
  untouched; reopen begins on `准备处理`.
- **L4 (reopen)**: confirmed by V16-CLOSE-AUTODISCARD test
  `dialog_runner (V16-CLOSE-AUTODISCARD): reopen after close
  exposes a clean 准备处理 path` continues to PASS.
- **Source integrity**: V17-H6 + V17-H7 + the existing
  V1.6 source-immutability invariants (BLOCK-005 path
  re-validated; `validate_host_state_consistency!` returns the
  same `false` on host divergence, so V1.7 inherits the V1.5
  property that destructive work cannot be silently re-applied
  on a stale workspace).

---

## J. Performance (per dispatch §J)

Actual measured runtimes on the vendored Ruby 2.7.8 install
(`tests/test_v17_performance.rb`):

- **P1**: 1 000 synthetic endpoints → proposer run < 5 s.
- **P2**: 10 000 synthetic endpoints → proposer run < 30 s.
- **P3**: 400 endpoints split into two widely-separated clusters
  (proving sub-linear-in-V behavior) → proposer run < 2 s.

The bucket key uses `cell_size = max(gap_search, coordinate_epsilon, 1e-4)`.
The proposer never issues `O(V²)` pair scans; it walks up to
reach³ neighbor cells per endpoint where `reach = ceil(gap_search / cell_size) + 1`.

> Do NOT invent real company-CAD performance from these
> numbers. They are synthetic; the only Owner-real assertion
> of V1.7 performance will come from the Owner SU2020 verification
> gate scenarios A–G.

---

## K. UI (per dispatch §K)

`html/app.js` extended with Simplified Chinese surface for the
new `拓扑修复` section (Blueprint §17):

- `TOPO_STATE_LABELS_CN`:
  `NOT_COMPUTED → 未检查`,
  `READY_TO_REPAIR → 发现可修复间隙`,
  `REVIEW_REQUIRED → 需要人工确认`,
  `NO_CANDIDATE → 无需修复`,
  `APPLIED → 已修复`,
  `FAILED → 修复失败`.
- `FIELD_LABEL_CN_TOPO`: `开放端点 / 可安全修复 / 需人工确认 /
  最大间隙 / 已修复间隙 / 剩余开放端点 / 已检查`.
- `ACTION_LABEL_CN.compute_gap_repair = '检查间隙'`,
  `apply_gap_repair = '修复间隙'`; the internal `data-action`
  attribute carries the callback name verbatim (no caller
  regression risk).
- `renderTopologyRepair` renders the user-visible rows.
- `renderTopologyRepairTechnicalRows` emits the raw audit
  evidence (proposal IDs, endpoint keys, canonical node IDs,
  tolerance values, audit status, canonical graph digest +
  schema_version + metrics + unresolved issues) into
  `技术详情`. The default Working Mode card stays condensed.
- Primary CTA priority (`renderPrimaryAction`):
  `topo.state === 'READY_TO_REPAIR'` → `修复间隙`;
  `topo.state === 'NOT_COMPUTED'` (with `topo` present) →
  `检查间隙` (priority over V1.6 PN); `topo` absent → fall
  through to V1.6 PN unchanged. The destructive
  `apply_planar_normalization` / `apply_gap_repair` actions
  are emitted ONLY when the matching safe state is present.

`tests/test_html_render_dom.js` V17-UI1..V17-UI4 assertions:
V17-UI1 NOT_COMPUTED + ready workspace renders the `拓扑修复`
State row + `检查间隙` primary CTA (priority over V1.6 PN CTA)
+ no `修复间隙` button; V17-UI2 READY_TO_REPAIR renders
`发现可修复间隙` + `修复间隙` CTA + no `检查间隙`; V17-UI3
REVIEW_REQUIRED has no destructive button; V17-UI4 APPLIED
renders `已修复` Chinese label + `已修复间隙：1` count row.

---

## L. Full tests (per dispatch §L)

- `tests/run_all.rb`:
  - **886 / 886 PASS** / 0 fail / 0 error.
  - Substrings (by name filter): `V14*`, `V15*`, `V16*`, `V17*`,
    RBZ smoke, BLOCK-004, BLOCK-005, V14-RUNTIME-BLOCK-001..004,
    V14-STAGE-BLOCK-001..002, V14-TARGETED-REGRESSION,
    V15-ROUND5-BLOCK-FIX, V15-PC-002, V16-PLANAR-NORMALIZATION,
    V16-PN-UI-CORRECTION, V16-UI-CN-SIMPLIFICATION, V16-FIX,
    V16-CLOSE-AUTODISCARD, **V17-IDENTITY (7)**, **V17-GAP (10)**,
    **V17-HOST-MUTATION (7)**, **V17-CANONICAL-GRAPH (9)**,
    **V17-PERFORMANCE (3)**.
- `tests/test_html_render_dom.js` (loaded by the Ruby
  `html_render` substring): **PASS**; 240+ V14/V15/V16 + 54
  V16-CN-SIMPLIFICATION (CN1..CN18) + 13 V16-FIX + 9 new
  V17-UI1..V17-UI4 = 316+ assertions, all PASS.

Exact commands:

```bash
.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb
node tests/test_html_render_dom.js
```

No fake PASS. No fabricated host evidence. No skipped tests.

---

## M. RBZ (per dispatch §M)

Rebuilt via `scripts/build_rbz.rb`:

- **Path**: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- **Size**: 890,087 bytes
- **Entries**: 67
- **SHA-256**: `b0064262f4cc9b52d02db75a86aeda9d75b03f7bba14eed55d2ce0a6c999f3f5`
- **`su_ai_plugin.rb`** at RBZ root (entry-point convention OK)
- **`su_ai_plugin/`** support folder (sibling of entry-point)
- **V1.7 production files** all shipped:
  - `su_ai_plugin/core/canonical_geometry_graph.rb` (12,705 bytes)
  - `su_ai_plugin/core/canonical_topology_builder.rb` (13,558 bytes)
  - `su_ai_plugin/core/endpoint_record.rb` (15,471 bytes)
  - `su_ai_plugin/core/gap_bridge_executor.rb` (15,088 bytes)
  - `su_ai_plugin/core/gap_pair_proposer.rb` (22,933 bytes)
- **Frontend asset trio** (`html/{index.html, app.js, style.css}`)
  shipped and byte-identical to in-tree source (verified via
  `tests/test_rbz_smoke.rb` package-content check).
- **`tests/`**, **`scripts/`**, **`Review/`** dev-only paths
  excluded (`rbz_smoke` requirement verified).

---

## N. Remaining risks / unknowns (per dispatch §N)

### Confirmed defects

None at this stage. All Blueprint §§3, 4, 6-17 contracts are
covered by the V17 regression suite (36 new Ruby tests + 9 new
DOM assertions) and re-verified by the existing V14-V16 suite
(unchanged by this dispatch).

### Assumptions (require Owner SU2020 / Codex confirmation)

- The `Edge#start` / `Edge#end` world-coordinate endpoints in
  real SketchUp are world-coordinates (we treat `add_edges`
  with absolute world XYZ as the host primitive, per Blueprint
  §12.2 and §2.2-bridge-note). The first Owner SU2020 scenario
  (Scenario A — "Missing triangle segment") is the canonical
  verification of this assumption.
- The production adapter's `add_line_to_repair_group` uses
  `Sketchup::Entities#add_line(p1, p2)` when available, falling
  back to `add_edges([p1, p2])`. Both primitives are in the
  long-standing SU baseline; SU 2017+ baseline is the spec
  target.
- The repair group's `name = 'SU-AI-Repair-GapBridge-<ws-id>'`
  makes it discoverable by the existing V1.4+
  `add_action_callback` traversal; the production adapter
  resolves it idempotently by `name` (Blueprint §12.1).
- The close-time auto-discard extension (V1.7 addition to
  `_discard_if_present`) is fail-safe per the existing
  V16-CLOSE-AUTODISCARD `rescue StandardError` boundary.

### Unknowns (require real SketchUp 2020 evidence)

- Real-host `add_line` geometry-merge semantics (SU may merge
  bridge endpoints with coincident host vertices, producing an
  additional face). V1.7 does NOT claim any face insertion; the
  bridge is added in its OWN repair group. Owner Scenario A is
  the canonical evidence.
- SketchUp's bridge handle `valid?` semantics across native
  Undo (Scenario F). V1.7's BLOCK-005 inheritance gives a
  robust fallback (workspace transitions to `:failed` with
  `host_state_changed`), but the Owner probe may surface
  edge-case `valid?` timing.
- Whether the host `transform_by_vectors` (V1.6 primitive)
  interacts with `add_edges`/`add_line` calls issued in the
  same native operation. V1.7 deliberately puts V1.6 and V1.7
  batch mutations in separate native operations (Blueprint §12.3:
  "one native operation for the batch"); no cross-talk evidence
  was discovered in the in-process test env.

### Owner-only

- Real human approval of the V1.7 UI simplification (Scenario A's
  primary product feature: "发现 1 个可安全修复的间隙").
- Acceptance that Scenario F (Undo + host-consistency)
  demonstrates the BLOCK-005 inheritance is sufficient.
- Final experience-freeze decision (this is an `Owner Gate`,
  not a Pi or AIPM decision).

---

## O. Mandatory review state (per dispatch §O)

```
CODEX_GATE: REQUIRED xHigh AFTER AIPM PRIMARY REVIEW
```

Justification:
- The V1.7 Blueprint §13 declares the canonical Codex xHigh
  integration review mandatory for V1.7.
- Scope satisfies every V1.7 trigger: source/state ownership,
  transaction/recovery, identity/provenance, transforms/units/
  tolerance, canonical topology, destructive repair geometry,
  host operation / failure / post-validation, Undo / discard /
  rebuild / close lifecycle, source immutability, package,
  downstream V1.8 correctness boundary.
- Pi did NOT invoke Codex. After AIPM primary review declares
  this packet materially ready, Codex shall be routed by AIPM
  per the existing project review cadence.

---

## P. Owner gate (per dispatch §P)

```
OWNER GATE: NOT YET RUN.
```

The Owner shall run the Blueprint §19 scenarios A through G on
real SketchUp 2020:

**Setup (one-time)**:

1. Install the latest RBZ at
   `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz` into
   SketchUp 2020 + restart SketchUp.
2. Open the SU-AI-Plugin dialog. Verify the action-state matrix
   exposes the new primary CTA `检查间隙`/`修复间隙` as
   documented in this packet.

**Scenario A — Missing triangle segment**:
draw or import an almost-closed triangle (two open endpoints,
unique mutual pair within `gap_search`). Expected: `准备处理` →
`检查间隙` → `发现可安全修复的间隙：1` → `修复间隙` → visible
derived bridge closes the gap → `拓扑修复 — 已修复`
(`已修复间隙：1`) → source unchanged.

**Scenario B — Ambiguous fork**: one open endpoint has two
plausible open endpoints inside `gap_search`. Expected:
`需要人工确认`, no destructive CTA, no derived connector,
no source change.

**Scenario C — Too far**: gap beyond `gap_search`. Expected: no
repair proposal.

**Scenario D — Cross-layer**: known different source layers.
Expected: review required / no auto repair.

**Scenario E — Crossing blocker**: a proposed bridge would cross
another unrelated edge. Expected: review required / no bridge.

**Scenario F — Undo**: apply one safe bridge, then native
SketchUp Undo. Verify: next plugin interaction detects
`host_state_changed`; no stale bridge handle used; recover via
`准备处理`.

**Scenario G — Discard / close**: apply bridge, then Discard or
close the dialog. Verify: generated repair geometry removed;
source unchanged; reopen on `准备处理`.

Pi did NOT run any Owner scenario (per dispatch §7 + §13).

---

## Definition of done (per dispatch §13)

- [x] V1.6 truthfully CLOSED (`Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md`).
- [x] `dev/v1.7` based on exact local closed V1.6 HEAD `d7e9c59`
      (branch `0bac757`).
- [x] canonical topology implementation complete:
      `EndpointRecord`, `CanonicalTopologyBuilder`
      (non-transitive safe, deterministic IDs),
      `CanonicalGeometryGraph` (deterministic digest).
- [x] safe endpoint_bridge proposal complete: `GapPairProposer`
      with mutual-unique, layer, Z, curve/face, crossing checks.
- [x] apply complete: `GapBridgeExecutor` + workspace-owned
      repair group + one native SU operation per batch + preflight
      + post-validation.
- [x] ambiguity / crossing / layer / curve / face / branch
      protections covered (V17-G4..G10, V17-T5).
- [x] source unchanged (V17-H6, V17-H7 + BLOCK-005 inheritance).
- [x] generated bridge provenance explicit (V17-T1, V17-T2).
- [x] canonical adjacency rebuilds from current derived truth
      (V17-N5, V17-N6, V17-T7).
- [x] V1.6 close auto-discard still works (re-verified: 850
      / 850 V1.6 path PASS; V16-CLOSE-AUTODISCARD substring all PASS
      under V17. The V17 addition extends `_discard_if_present`
      to also dispose repair groups; this is additive only,
      no regression.)
- [x] Undo safety uses existing host-consistency architecture
      (V17-L1 + BLOCK-005).
- [x] Simplified Chinese V1.7 UI usable (V17-UI1..V17-UI4 DOM PASS;
      `拓扑修复`, `检查间隙`, `修复间隙` rendered; V1.6 UI
      unchanged for non-`topology_repair` callers — see CN12 +
      V17-UI1's `topo absent → fall through to V1.6 PN` clause).
- [x] full regressions green: 886 / 886 Ruby + all V17-UI DOM PASS.
- [x] RBZ candidate built + verified (size 890087, entries 67,
      SHA-256 `b0064262f4cc9b52d02db75a86aeda9d75b03f7bba14eed55d2ce0a6c999f3f5`).
- [x] `CURRENT_STATE.md` truthful (V1.7 dispatch start block
      added; prior V1.5/V1.6 blocks preserved verbatim).
- [x] `Review/CURRENT_PI_REPORT.md` overwritten (this report).
- [x] mandatory Codex gate clearly pending (§O above).
- [x] Owner gate clearly NOT YET RUN (§P above).
- [x] V1.8 NOT STARTED (no chain / loop / region / face / site
      semantic construction in this dispatch).

---

## STOP and return control to AIPM.

End of report.
