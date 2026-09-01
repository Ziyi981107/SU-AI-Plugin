# V17 AIPM Critical Source Index

> Critical source index for the V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01
> dispatch. Maps every Blueprint § requirement to the exact production
> symbol + line range. The patch in
> `Review/V17_AIPM_SOURCE_REVIEW.patch` remains the source evidence; this
> index is a fast lookup for AIPM direct source review.

Project: SU-AI-Plugin
Dispatch: V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01
Frozen Blueprint: `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
Closed V1.6 base SHA: `d7e9c59` (V1.6 CLOSE-AUTODISCARD)
Branch: `dev/v1.7`
Starting HEAD: `0bac757` (V1.6 closure anchor + V1.7 Blueprint as durable
authority documents)
Final HEAD: see CURRENT_PI_REPORT §K
Patch: `Review/V17_AIPM_SOURCE_REVIEW.patch`
Patch SHA-256: `87d84724b572b9ef9d2c96fd61d63cdd72bfa74af44e2155a16e3a6497654d59`

---

## R1 — Crossing / Branch Safety

| Requirement | Symbol / file | Line range | Test |
|-------------|---------------|------------|------|
| X1 bridge crosses unrelated edge interior -> REVIEW_REQUIRED | `WorkingModeRunner._crossing_checker_proc` (`_segments_intersect_interior?` predicate) | `working_mode_runner.rb:1112-1175` | `V17-X1` (`tests/test_v17_branch_crossing.rb`) |
| X2 third canonical node on bridge -> REVIEW_REQUIRED | `WorkingModeRunner._crossing_checker_proc` (`_third_node_on_segment?` predicate) | `working_mode_runner.rb:1175-1190` | `V17-X2` (`tests/test_v17_branch_crossing.rb`) |
| X3 two proposed bridges cross -> REVIEW_REQUIRED with `bridge_conflict` | `GapPairProposer.propose` (X3 pairwise check block) + `_segments_intersect_interior?` predicate | `gap_pair_proposer.rb:451-487` (X3 block) + `gap_pair_proposer.rb:521-555` (predicate) | `V17-X3` + `V17-X3-PAIRWISE` (`tests/test_v17_branch_crossing.rb`) |
| X4 almost-closed triangle -> READY_TO_REPAIR | `GapPairProposer.propose` end-to-end (mutual-unique + layer + Z + crossing-gate) | `gap_pair_proposer.rb:340-410` | `V17-X4` (`tests/test_v17_branch_crossing.rb`) |

## R2 — Canonical post-repair adjacency

| Requirement | Symbol / file | Line range | Test |
|-------------|---------------|------------|------|
| T3 repaired endpoints gain expected adjacency | `CanonicalGeometryGraph._build_canonical_edges` (canonical_node_id resolution) + `_resolve_bridge_node` | `canonical_geometry_graph.rb:280-345` | `V17-T3` (`tests/test_v17_canonical_graph.rb`) |
| T4 almost-closed triangle becomes cycle-capable for V1.8 (no V1.8 Loop/Region object) | `CanonicalGeometryGraph._build_canonical_edges` + `CanonicalGeometryGraph._build_adjacency` (no loop/region metrics) | `canonical_geometry_graph.rb:280-345` + `canonical_geometry_graph.rb:430-440` | `V17-T4` (`tests/test_v17_canonical_graph.rb`) |

## R3 — Canonical origin_kind mapping (workspace -> canonical enum)

| Requirement | Symbol / file | Line range | Test |
|-------------|---------------|------------|------|
| Translate workspace enum `generated_gap_bridge` -> canonical enum `gap_bridge` | `CanonicalGeometryGraph._canonicalize_origin_kind` (R3 primary) | `canonical_geometry_graph.rb:372-385` | `V17-OK-MAP-1` + `V17-OK-MAP-2` (`tests/test_v17_branch_crossing.rb`) |
| Read `origin_kind` from `geometry_summary` (not `rec.origin_kind`) | `CanonicalGeometryGraph._build_canonical_edges` (R3 secondary; line 300-310) | `canonical_geometry_graph.rb:300-310` | `V17-OK-MAP-1` + `V17-OK-MAP-2` |
| Read `repair_action_id` from `geometry_summary` (not `rec.repair_action_id`) | `CanonicalGeometryGraph._build_canonical_edges` (R3 secondary; line 320-328) | `canonical_geometry_graph.rb:320-328` | `V17-OK-MAP-1` + `V17-OK-MAP-2` |
| Resolve bridge-endpoint canonical nodes by world coordinate (so bridge connects into existing canonical graph) | `CanonicalGeometryGraph._resolve_bridge_node` | `canonical_geometry_graph.rb:388-420` | `V17-T3` + `V17-T4` + `V17-OK-MAP-1` + `V17-OK-MAP-2` |
| Map `clusters` -> `cluster_id_for` keyed by canonical_node_id (NOT cluster_id) | `CanonicalGeometryGraph._build_canonical_edges` (R3 cluster_id_for remap) | `canonical_geometry_graph.rb:218-235` | `V17-T3` + `V17-T4` |
| Defensive string+symbol key lookup in `build_from_workspace` (for legacy callers) | `CanonicalGeometryGraph.build_from_workspace` | `canonical_geometry_graph.rb:131-160` | `V17-T3` + `V17-T4` |

## R4 — Test matrix / report claims

| Blueprint | Symbol / file | Test (in `tests/`) |
|-----------|---------------|---------------------|
| §18.1 N1-N6 canonical node / identity | `CanonicalTopologyBuilder` + existing V17-N* tests | `test_v17_topology_identity.rb` |
| §18.1 N5b canonical graph digest | `CanonicalGeometryGraph._compute_digest` | `test_v17_topology_identity.rb` |
| §18.2 G1-G10 gap candidate / pairing | `GapPairProposer.propose` | `test_v17_gap_pairing.rb` |
| §18.3 X1-X4 branch / crossing (NEW) | `_crossing_checker_proc` + X3 pairwise check | `test_v17_branch_crossing.rb` |
| §18.4 H1-H7 host mutation | `GapBridgeExecutor.apply` + preflight + post_validate | `test_v17_host_mutation.rb` |
| §18.4 H6 source fingerprint unchanged | `SourceFingerprint.from_snapshot` round-trip | `test_v17_host_mutation.rb` (H6) |
| §18.4 H7 existing source-edge coordinates unchanged | `entity.geometry_summary` byte-equal before/after | `test_v17_host_mutation.rb` (H7) |
| §18.5 T1-T2 bridge edge + provenance | `GapBridgeExecutor.apply` -> `origin_kind='gap_bridge'` | `test_v17_canonical_graph.rb` |
| §18.5 T3 repaired endpoints adjacency (NEW) | `CanonicalGeometryGraph` adjacency rebuild | `test_v17_canonical_graph.rb` |
| §18.5 T4 cycle-capable for V1.8 (NEW) | `CanonicalGeometryGraph` adjacency + BFS | `test_v17_canonical_graph.rb` |
| §18.5 T5 review-required gaps no canonical edge | `GapBridgeExecutor.apply` rejects review-required proposals | `test_v17_canonical_graph.rb` |
| §18.5 T6 discard removes bridges | `_discard_if_present` + `dispose_repair_group_bridges` | `test_v17_canonical_graph.rb` |
| §18.5 T7 rebuild deterministic | `GapPairProposer._proposal_id` SHA-256 | `test_v17_canonical_graph.rb` |
| §18.6 L1-L4 lifecycle | `WorkingModeRunner.validate_host_state_consistency!` + close-auto-discard | `test_v17_canonical_graph.rb` + `test_dialog_runner.rb` |
| §18.7 P1-P3 performance | `GapPairProposer` bucket-based O(V+K) | `test_v17_performance.rb` |

---

## Files modified (this dispatch)

### Production files (3)

| File | Change | Why |
|------|--------|-----|
| `extension/su_ai_plugin/core/canonical_geometry_graph.rb` | R1, R2, R3 fixes: `_canonicalize_origin_kind`, `_resolve_bridge_node`, `build_from_workspace` dual-key lookup, cluster_id_for remap to canonical_node_id | R3 (canonical origin_kind mapping) + R2 (canonical adjacency) + T3/T4 correctness |
| `extension/su_ai_plugin/core/gap_pair_proposer.rb` | R1 X3 fix: pairwise ready_proposal crossing check + `_segments_intersect_interior?` / `_segment_orientation` / `_shared_endpoint?` private helpers | X3 (two proposed bridges cross -> bridge_conflict) |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | (UNCHANGED this dispatch — V17 frozen code remains the single source of truth for `_crossing_checker_proc`) | n/a |

### Test files (2)

| File | Change |
|------|--------|
| `tests/test_v17_branch_crossing.rb` | NEW: 6 tests for X1, X2, X3, X3-PAIRWISE, X4, OK-MAP-1, OK-MAP-2 |
| `tests/test_v17_canonical_graph.rb` | EXTENDED: added T3 + T4 tests (post-repair adjacency + cycle-capable) |

### Governance files (1)

| File | Change |
|------|--------|
| `Prompt/CURRENT_PI_DISPATCH.md` | Updated to the V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 dispatch (overwritten by AIPM) |

### New review artifacts (1)

| File | Content |
|------|---------|
| `Review/V17_AIPM_SOURCE_REVIEW.patch` | `git diff d7e9c59..HEAD -- extension/su_ai_plugin tests scripts/build_rbz.rb` (this file) |
| `Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md` | this file |

---

## Dispatch §7 — Full regression evidence

- V17-X1, V17-X2, V17-X3, V17-X3-PAIRWISE, V17-X4, V17-OK-MAP-1, V17-OK-MAP-2
- V17-T1, V17-T2, V17-T3, V17-T4, V17-T5, V17-T6, V17-T7
- V17-L1, V17-L2, V17-L3, V17-L4
- V17-N1..N6, V17-N5b
- V17-G1..G10
- V17-H1..H7
- V17-P1, V17-P2, V17-P3
- Full Ruby suite: 895 / 895 PASS (was 886; +9 new)
- Node DOM (test_html_render_dom.js): 316+ assertions PASS
- V16-CLOSE-AUTODISCARD: 7/7 PASS (regression)
- V15 host-state / BLOCK-005: 149/149 PASS (regression)
- LEGACY-COMPAT: 4/4 PASS (regression)
- RBZ smoke: 9/9 PASS (post-rebuild)

---

## Verified by inspection

AIPM may directly inspect:

1. `Review/V17_AIPM_SOURCE_REVIEW.patch` (the actual source diff from V1.6
   closed base `d7e9c59` to the final corrected V1.7 HEAD).
2. The full repository at the final corrected V1.7 HEAD (use
   `git rev-parse HEAD`).
3. The `dist\SU-AI-Plugin.rbz` artifact rebuilt from the corrected
   source (see CURRENT_PI_REPORT §M for the SHA-256).
4. The DOM assertions file `tests/test_html_render_dom.js` (no JS-side
   changes in this dispatch; existing V17-UI1..UI4 assertions still pass).

---

END OF INDEX
