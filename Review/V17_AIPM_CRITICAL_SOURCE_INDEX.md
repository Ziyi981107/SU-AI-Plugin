# V17-AIPM-DIRECT-SOURCE-REVIEW-FIX Critical Source Index

## SR-01..SR-07 Production File Map

| SR | Concern | File | Lines | Symbol |
|----|---------|------|-------|--------|
| SR-01 | Bridge ownership (workspace.build_entity only; no separate repair-group edge) | `extension/su_ai_plugin/core/gap_bridge_executor.rb` | full file | `GapBridgeExecutor.apply` (no `adapter.add_line_to_repair_group` call) |
| SR-01 | Bridge derived_id deterministic form | `extension/su_ai_plugin/core/gap_bridge_executor.rb` | `_deterministic_bridge_id` | `"der-gap-#{proposal_id}"` |
| SR-02 | True `:failed` workspace + logical rollback | `extension/su_ai_plugin/core/gap_bridge_executor.rb` | `apply` (pre_workspace capture), `_confirmed_abort`, `_transition_to_failed_with_handles`, `_fail` | pre/post workspace separation; current handles preserved for Discard on commit uncertainty |
| SR-03 | Executor-side hard post-validation (A..G) | `extension/su_ai_plugin/core/gap_bridge_executor.rb` | `_post_validate` | proves state, count, origin_kind, repair_action_id, host endpoints, source fingerprint, pre-existing coords, proposal ID set, no REVIEW_REQUIRED executed |
| SR-03 | Runner-side canonical post-validation (H..K) | `extension/su_ai_plugin/core/working_mode_runner.rb` | `_canonical_post_validate` + `apply_gap_repair` block | proves canonical bridge count, repair_action_id, repaired adjacency, no new non_transitive_node_cluster; workspace transitions to `:failed` with `canonical_post_validation_failed` on failure |
| SR-04 | True point-on-segment-interior predicate | `extension/su_ai_plugin/core/working_mode_runner.rb` | `_point_on_segment_interior?` + updated `_third_node_on_segment?` | projection t in (0,1) with endpoint exclusion + closest-point distance <= coordinate_epsilon |
| SR-05 | Deterministic generated bridge derived_id | `extension/su_ai_plugin/core/gap_bridge_executor.rb` | `_deterministic_bridge_id` | `"der-gap-#{proposal_id}"`; no `rand` |
| SR-06 | Plural `source_occurrence_ids` provenance | `extension/su_ai_plugin/core/canonical_geometry_graph.rb` | `_build_canonical_edges` + new `_normalize_occurrence_ids` | sorted/uniq String Array; singular `source_occurrence_id` preserved for backwards compatibility |
| SR-07 | Collapse per-endpoint records to ONE logical node per canonical_node_id | `extension/su_ai_plugin/core/canonical_geometry_graph.rb` | `_collapse_nodes_by_id` + updated constructor | preserves membership + representative world coord (lex-smallest endpoint_key member); `metrics.canonical_node_count` reflects UNIQUE logical node count |

## Production defects uncovered by production-path tests (prior packet)

- R5-REG-LAYER: layered CAD NoMethodError on `rec.layer` (fixed in `core/endpoint_record.rb`).
- R5-REG-FROZEN: `_canonical_topology_snapshot` mutated frozen Hash (fixed in `core/working_mode_runner.rb` via `.dup`).
- R5-REG-CLUSTER: SYMBOL vs STRING key mismatch in `canonical_node_clusters` (fixed via `_ts_read` helper in `gap_pair_proposer.rb` + `working_mode_runner.rb`).
- R6-NODE-IDENTITY: clique members got distinct `<cluster>.nN` ids (fixed in `core/canonical_topology_builder.rb`; safe cliques now share one canonical_node_id).

## Test File Map

| File | Status | Coverage |
|------|--------|----------|
| `tests/test_v17_canonical_graph.rb` | Modified | L2/L3 rewritten for SR-01 ownership |
| `tests/test_v17_host_mutation.rb` | Modified | H3 rewritten for SR-01/SR-02 (workspace.build_entity path) |
| `tests/test_v17_production_gap_path.rb` | Modified + 22 new SR tests | All V17 production-path evidence + SR-01..SR-07 regression tests |
| `tests/test_v17_branch_crossing.rb` | Unchanged | Low-level predicate tests (X1/X2 mirror + X3 + X4 2-line) |
| `tests/test_v17_topology_identity.rb` | Unchanged | N1..N6 + N5b |
| `tests/test_v17_gap_pairing.rb` | Unchanged | G1..G10 |
| `tests/test_v17_performance.rb` | Unchanged | P1..P3 |

## Reviewer Checklist

- [x] SR-01: `GapBridgeExecutor.apply` calls `workspace.build_entity` ONLY (no `adapter.add_line_to_repair_group`); bridge host handle is the workspace's private handle_registry entry; lifecycle = workspace discard / rebuild / close-time auto-discard.
- [x] SR-02: `pre_workspace` captured before `begin_operation`; on confirmed abort returns `:failed` workspace derived from `pre_workspace`; on commit uncertainty retains current handles for Discard; no failure path returns `:ready`.
- [x] SR-03: `_post_validate` (executor) + `_canonical_post_validate` (runner) implement A..G + H..K; workspace transitions to `:failed` with `canonical_post_validation_failed` on canonical post-validation failure.
- [x] SR-04: `_point_on_segment_interior?` uses projection t + endpoint exclusion + closest-point distance <= coordinate_epsilon.
- [x] SR-05: `_deterministic_bridge_id("der-gap-#{proposal_id}")`; no `rand`.
- [x] SR-06: `CanonicalEdge.source_occurrence_ids` is normalized sorted/uniq String Array; singular preserved.
- [x] SR-07: `CanonicalGeometryGraph._collapse_nodes_by_id` collapses records by `canonical_node_id`; `metrics.canonical_node_count` = unique logical count.
- [x] 22 SR regression tests in `tests/test_v17_production_gap_path.rb`.
- [x] Full Ruby suite: 921/921 PASS.
- [x] RBZ smoke: 9/9 PASS.
- [x] `git diff --check`: clean.
- [x] No Codex invocation; no Owner verification; no V1.8 work.
- [x] Frozen V1.7 Blueprint preserved unchanged.
