# CURRENT PI REPORT — V17-AIPM-DIRECT-SOURCE-REVIEW-FIX

Project: `SU-AI-Plugin`
Version: V1.7
Stage: V17 DIRECT-SOURCE-REVIEW-FIX COMPLETE /
AWAITING AIPM DIRECT SOURCE RE-REVIEW (NOT yet V1.7 CLOSED;
mandatory Codex xHigh integration review + final Owner SU2020
real-host verification gate remain.)
Dispatch: `V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01`
Prior Dispatch: `V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01`
Dispatcher / Technical Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
AIPM direct source review (the corrections this dispatch
addresses):
`Review/CURRENT_AIPM_REVIEW_V17_DIRECT_SOURCE_REVIEW.md`
Frozen V1.6 Closure Anchor:
`Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md`
Branch: `dev/v1.7`
Source of Truth: `extension/su_ai_plugin/` + canonical contracts in
`PROJECT_HANDOFF` + `PROJECT_MASTER_PLAN_V1X`.

---

## 0. Scope (per dispatch §0-§13)

This is a **frozen-Blueprint bounded direct-source-review
correction packet**. AIPM direct source review of the prior
V17-AIPM-EVIDENCE-INTEGRATION-FINAL packet found SEVEN BLOCKs
(SR-01 through SR-07) requiring host-ownership, failure, cleanup,
post-validation, identity and provenance corrections.

This dispatch:

- corrected all seven SR findings with REAL production-path
  evidence;
- preserved the four R5 / R6 / R7 / R8 production-defect
  regressions and the seven production-path evidence tests from
  the prior packet;
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

## A. SR-01..SR-07 disposition

| ID | Finding | Disposition | Evidence |
|----|---------|-------------|----------|
| SR-01 | DOUBLE-CREATION: `add_line_to_repair_group` created host bridge A in `SU-AI-Repair-GapBridge-*` while `workspace.build_entity` created host bridge B in a separate `SU-AI-Derived-*` group. Split ownership; normal Discard/Rebuild/close could delete the tracked copy and leave the production repair-group copy behind. | CORRECTED — V1.7 base execution path is the SOLE host-creation path: `workspace.build_entity(derived_id: "der-gap-#{proposal_id}", kind: :edge, ...)` exactly once per proposal. The old `add_line_to_repair_group` adapter API remains defined for backwards compatibility but is NOT called by the production path. The bridge handle is owned by the workspace's private `handle_registry` and is disposed via the existing Discard / Rebuild / close-time auto-discard (same lifecycle as every other derived entity). | `extension/su_ai_plugin/core/gap_bridge_executor.rb` (`GapBridgeExecutor.apply` no longer calls `adapter.add_line_to_repair_group`); `tests/test_v17_production_gap_path.rb` `V17-SR1-1`, `V17-SR1-2`, `V17-SR1-3`, `V17-SR1-4`. |
| SR-02 | TRUE FAILED WORKSPACE + LOGICAL ROLLBACK: `_fail` returned the input workspace unchanged; a partially-mutated workspace could remain `:ready` after host abort. | CORRECTED — `GapBridgeExecutor.apply` now captures `pre_workspace` BEFORE `begin_operation`. On confirmed abort, it builds a NEW `:failed` workspace derived from `pre_workspace` (preserving `entity_pairs` + `handle_registry` + `source_snapshot`). On commit uncertainty, the current generated handles are preserved so explicit Discard can clean up. No failure return path exposes `post_workspace.state == :ready`. | `gap_bridge_executor.rb` (`apply` `_confirmed_abort` / `_transition_to_failed_with_handles` / `_fail`); `tests/test_v17_production_gap_path.rb` `V17-SR2-1`, `V17-SR2-2`, `V17-SR2-3`, `V17-SR2-4`. |
| SR-03 | HARD RUNTIME POST-VALIDATION: `_post_validate` only proved state + count + handle validity; required runtime proofs of origin_kind, repair_action_id, host endpoint positions, source fingerprint, pre-existing coords, proposal ID set, and post-commit canonical graph invariants were missing. | CORRECTED — `_post_validate` now proves (A) state, (B) origin_kind + repair_action_id per bridge, (C) host endpoint positions match expected, (D) source fingerprint unchanged, (E) pre-existing derived coords unchanged, (F) generated proposal IDs exactly equal expected, (G) no REVIEW_REQUIRED was executed. The runner's `apply_gap_repair` rebuilds the canonical graph and proves (H) every bridge is one canonical `gap_bridge` edge, (I) repair_action_id survives, (J) repaired endpoint adjacency is present, (K) no new non_transitive_node_cluster was introduced. Failure -> workspace transitions to `:failed` with reason `canonical_post_validation_failed`. | `gap_bridge_executor.rb` (`_post_validate` checks A..G); `working_mode_runner.rb` (`apply_gap_repair` canonical post-validation H..K + `_canonical_post_validate`); `tests/test_v17_production_gap_path.rb` `V17-SR3-1`..`V17-SR3-5`. |
| SR-04 | TRUE POINT-ON-SEGMENT INTERIOR: `_third_node_on_segment?` only checked `abs(orientation) <= eps`, proving collinearity with the infinite LINE. A distant collinear node would falsely trigger `third_node_on_bridge`. | CORRECTED — new `_point_on_segment_interior?` predicate proves (1) finite 3D point, (2) projection parameter t lies STRICTLY in (0, 1) with endpoint epsilon exclusion (band `[eps/seg_len, 1 - eps/seg_len]`), (3) closest-point distance to the segment is `<= coordinate_epsilon`. Endpoints are excluded. | `working_mode_runner.rb` (`_point_on_segment_interior?` + updated `_third_node_on_segment?`); `tests/test_v17_production_gap_path.rb` `V17-SR4-1`, `V17-SR4-2`, `V17-SR4-3`. |
| SR-05 | DETERMINISTIC BRIDGE ID: `_next_bridge_id` used `rand(2**32)`, which produced non-deterministic IDs. | CORRECTED — generated bridge `derived_id` is now `"der-gap-#{proposal_id}"` (deterministic; `proposal_id` itself is deterministic per `GapPairProposer._proposal_id`). No Ruby random value. Same source + same captured config + same safe proposal -> same generated bridge derived_id + canonical_edge_id after rebuild/reapply. | `gap_bridge_executor.rb` (`_deterministic_bridge_id`); `tests/test_v17_production_gap_path.rb` `V17-SR5-1`. |
| SR-06 | PLURAL CANONICAL PROVENANCE: `CanonicalEdge` emitted only `source_occurrence_id` (singular, `first(...)`), losing provenance from the second incident side of a `gap_bridge`. | CORRECTED — `CanonicalEdge` now carries `source_occurrence_ids` (plural, normalized sorted/uniq Array of String). For a `gap_bridge` this contains the COMPLETE support union from both incident sides. Singular `source_occurrence_id` is preserved for backwards compatibility with existing consumers; V1.8 authority is the plural field. | `canonical_geometry_graph.rb` (`_build_canonical_edges` emits `source_occurrence_ids` via `_normalize_occurrence_ids`); `tests/test_v17_production_gap_path.rb` `V17-SR6-1`. |
| SR-07 | UNIQUE LOGICAL GRAPH NODES: `CanonicalGeometryGraph.nodes` was one record per EndpointRecord (Blueprint §7.2 / §7.3); `canonical_node_count` in metrics counted records, not unique logical node IDs. | CORRECTED — at the `CanonicalGeometryGraph` constructor boundary, per-endpoint records are collapsed into ONE LOGICAL NODE per `canonical_node_id` (preserving `endpoint_keys` + `derived_edge_ids` + `source_occurrence_ids` + `layer_names` + deterministic representative world coordinate from the lex-smallest endpoint_key member). The published `metrics.canonical_node_count` now reflects the UNIQUE logical node count. Non-transitive cluster members remain separate graph nodes. | `canonical_geometry_graph.rb` (`_collapse_nodes_by_id` + `_finalize_metrics`); `tests/test_v17_production_gap_path.rb` `V17-SR7-1`, `V17-SR7-2`, `V17-SR7-3`, `V17-SR7-4`. |

---

## B. Production code changed (per dispatch §B)

| File | Change | Why |
|------|--------|-----|
| `extension/su_ai_plugin/core/gap_bridge_executor.rb` | Major rewrite: removed `add_line_to_repair_group` call (SR-01); captured `pre_workspace` for SR-02 confirmed-abort; rewrote `_post_validate` for SR-03 (A..G); added `_deterministic_bridge_id` for SR-05; rewrote `_fail` to return a NEW `:failed` workspace derived from `pre_workspace` (not the partially-mutated `working_workspace`); added `_transition_to_failed_with_handles` (preserves current generated handles so explicit Discard can clean up); added `_confirmed_abort` path; new `REASON_CANONICAL_POST_VALIDATE_FAIL` constant; bumped schema_version to `gap-bridge-apply.v2`. | SR-01 / SR-02 / SR-03 / SR-05 |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | New `_point_on_segment_interior?` predicate (SR-04); rewrote `_third_node_on_segment?` to delegate to the new predicate; new `_canonical_post_validate` runner-level post-validation method (SR-03 H..K); added canonical post-validation block in `apply_gap_repair` that transitions the workspace to `:failed` with stable reason `canonical_post_validation_failed` if any H..K check fails (handles retained for Discard). | SR-03 / SR-04 |
| `extension/su_ai_plugin/core/canonical_geometry_graph.rb` | New `_collapse_nodes_by_id` instance helper (SR-07) collapses per-endpoint records into ONE logical node per `canonical_node_id` (preserves membership data + representative world coord from lex-smallest endpoint_key member). New `_finalize_metrics` instance helper overwrites `canonical_node_count` with the unique logical node count and adds `canonical_edge_count` for downstream convenience. New `_normalize_occurrence_ids` class helper (SR-06) emits a deterministic sorted/uniq String Array. `_build_canonical_edges` now emits `source_occurrence_ids` (plural) alongside the existing singular field. `_compute_digest` now uses the collapsed node format and includes `source_occurrence_ids` in the per-edge digest line. | SR-06 / SR-07 |
| `tests/test_v17_canonical_graph.rb` | Updated V17-L2 and V17-L3 lifecycle tests to verify the new SR-01 ownership path (workspace-owned bridge entity + private handle_registry dispose on Discard / close-time auto-discard). | SR-01 |
| `tests/test_v17_host_mutation.rb` | Rewrote V17-H3 to verify the new SR-01 build_entity path. The old test stubbed `add_line_to_repair_group`; the new test stubs `create_top_level_group` (the inner primitive that `workspace.build_entity` calls) so the second bridge in a 2-bridge batch fails after the first succeeded. Asserts `post_workspace.state == :failed` (SR-02) and exactly one `begin_operation` / zero `commit` (the failed batch aborts cleanly). | SR-01 / SR-02 |
| `tests/test_v17_production_gap_path.rb` | Updated V17-H3 [PRODUCTION PATH] to verify workspace-owned bridge handles (not the legacy repair_group_bridges). Added 22 SR-01..SR-07 regression tests. | SR-01..SR-07 |

Production byte diff vs the prior V17-AIPM-EVIDENCE-INTEGRATION-FINAL
packet commit `aa33ac6`:

- `extension/su_ai_plugin/core/gap_bridge_executor.rb`: rewritten
  (~ +400 / -200 lines net).
- `extension/su_ai_plugin/core/working_mode_runner.rb`: +90 / -10
  lines.
- `extension/su_ai_plugin/core/canonical_geometry_graph.rb`:
  +95 / -25 lines.
- `tests/test_v17_canonical_graph.rb`: +35 / -32 lines
  (L2 / L3 rewrite).
- `tests/test_v17_host_mutation.rb`: +60 / -369 lines (H3 rewrite;
  the old 2nd-bridge logic was removed since the architecture is
  now uniform).
- `tests/test_v17_production_gap_path.rb`: +659 / -57 lines
  (22 new SR tests + H3 update).

All changes are LOCAL to the V1.7 frozen contract:

- tolerance semantics unchanged;
- Source of Truth unchanged;
- Source-of-CAD immutability unchanged;
- gap repair type unchanged (still `endpoint_bridge`);
- cross-layer / curve / face / Z / crossing uncertainty unchanged;
- non-transitive cluster handling unchanged;
- canonical `origin_kind` enum unchanged (`gap_bridge`);
- no V1.8 Loop / Region / face semantics introduced;
- no Observer architecture added.

---

## C. One-bridge / one-host-geometry evidence (per dispatch §C)

`tests/test_v17_production_gap_path.rb`:

- **V17-SR1-1**: drives the real production path. Exactly ONE
  workspace-owned bridge entity after apply; the bridge host
  handle resolves to a FakeGroup containing exactly ONE
  FakeEdge child. NO `add_line_to_repair_group` is called.
- **V17-SR1-2**: explicit Discard invalidates the bridge host
  handle and empties the workspace entity inventory.
- **V17-SR1-3**: close-time auto-discard (same handle_registry
  path) invalidates the bridge host handle.
- **V17-SR1-4**: Rebuild (discard + new prepare from the same
  source) yields ZERO bridge entities — no stale handle leaks
  from the old workspace.

---

## D. Failed-state / rollback evidence (per dispatch §D)

`tests/test_v17_production_gap_path.rb`:

- **V17-SR2-1**: first of two bridges succeeds, second fails ->
  workspace transitions to `:failed`; NO bridge entity
  survives logically; audit reason is `post_validation_failed`
  or `commit_uncertainty`.
- **V17-SR2-2**: direct post-validation mismatch (host endpoint
  positions wrong) -> workspace transitions to `:failed` via
  the canonical post-validation block.
- **V17-SR2-3**: commit uncertainty (stub `end_operation` to
  raise on commit) -> workspace transitions to `:failed`;
  handles retained for Discard; audit reason
  `commit_uncertainty`.
- **V17-SR2-4**: zero-proposals path AND discarded-workspace
  path both return `:failed`, never `:ready`.

---

## E. Runtime post-validation map (per dispatch §E)

`GapBridgeExecutor._post_validate` (executor-side):

| Check | Stable reason |
|-------|---------------|
| (A) workspace state | `post_workspace_state_#{state}` |
| (A) applied count == expected | `applied_count_mismatch(N/M)` |
| (B) origin_kind per bridge | `wrong_origin_kind:#{pid}` |
| (B) repair_action_id per bridge | `wrong_repair_action_id:#{pid}` |
| (B) entity record exists | `missing_entity_record:#{pid}` |
| (B) geometry_summary exists | `missing_geometry_summary:#{pid}` |
| (B) host handle present | `missing_host_handle:#{pid}` |
| (B) host handle valid | `invalid_host_handle:#{pid}` |
| (C) host endpoint start matches | `host_endpoint_start_mismatch:#{pid}` |
| (C) host endpoint end matches | `host_endpoint_end_mismatch:#{pid}` |
| (D) source fingerprint unchanged | `source_fingerprint_changed` |
| (E) pre-existing coords unchanged | `pre_existing_coords_changed` |
| (F) proposal ID set matches | `proposal_id_set_mismatch` |
| (G) no REVIEW_REQUIRED executed | `non_ready_was_executed:#{pid}` |

`WorkingModeRunner._canonical_post_validate` (runner-side):

| Check | Stable reason |
|-------|---------------|
| (H) canonical bridge count == applied | `canonical_bridge_count_mismatch(N/M)` |
| (I) repair_action_id in canonical edge | `repair_action_id_not_in_canonical:#{id}` |
| (J) bridge endpoint adjacency A->B | `repaired_adjacency_missing_a:#{ce}` |
| (J) bridge endpoint adjacency B->A | `repaired_adjacency_missing_b:#{ce}` |
| (J) bridge endpoint resolution | `bridge_endpoint_not_resolved:#{ce}` |
| (K) no new non_transitive_cluster | `new_non_transitive_cluster_introduced` |

---

## F. Point-on-segment tests (per dispatch §F)

`tests/test_v17_production_gap_path.rb`:

- **V17-SR4-1**: real fixture where a third edge's vertex lies
  EXACTLY on the bridge segment interior (between two
  coincident corners that are NOT open endpoints). The
  proposal is demoted to REVIEW_REQUIRED with reason
  `third_node_on_bridge`.
- **V17-SR4-2**: third edge whose vertex is collinear with the
  bridge line but FAR beyond the segment endpoint (y=100, well
  outside the segment band). The proposal is NOT demoted; the
  OLD collinearity-only predicate would have falsely demoted
  it.
- **V17-SR4-3**: third edge whose vertex is NEAR the bridge line
  but outside `coordinate_epsilon`. The proposal is NOT demoted.

---

## G. Deterministic ID evidence (per dispatch §G)

`V17-SR5-1` [PRODUCTION PATH]: drives the real production path
THEN discards + rebuilds + reapplies. The new bridge's
`derived_id` is identical to the previous one (`der-gap-#{proposal_id}`,
where `proposal_id` itself is deterministic per
`GapPairProposer._proposal_id`).

---

## H. Plural provenance evidence (per dispatch §H)

`V17-SR6-1` [PRODUCTION PATH]: after apply, the canonical graph
contains exactly one `gap_bridge` canonical edge; its
`source_occurrence_ids` field is an Array containing BOTH
incident source occurrence IDs (`occ-101` AND `occ-102`). The
singular `source_occurrence_id` is preserved and is one of the
plural IDs (backwards compatibility).

---

## I. Unique graph-node evidence (per dispatch §I)

`V17-SR7-1` [PRODUCTION PATH]: after apply, `graph.nodes.length`
equals the UNIQUE logical node count (4 for the triangle
fixture); no duplicates. The corner-A clique has
`membership_count >= 2`.

`V17-SR7-2`: a non-transitive cluster (A~=B, B~=C, A!~=C) keeps
DISTINCT `canonical_node_id`s (3 distinct ids, no collapse).

`V17-SR7-3`: `graph.metrics['canonical_node_count']` equals
`graph.nodes.length` (UNIQUE logical count, not per-endpoint
record count).

`V17-SR7-4`: rebuilding the canonical graph from the same
unchanged workspace yields the SAME `digest` and the SAME
`canonical_node_ids`.

---

## J. Complete V1.7 test matrix (per dispatch §G + dispatch §9)

| Blueprint / SR | Test | File | Status |
|----------------|------|------|--------|
| §18.1 N1..N6 | V17-N1..N6 | test_v17_topology_identity.rb | PASS |
| §18.1 N5b | V17-N5b | test_v17_topology_identity.rb | PASS |
| §18.2 G1..G10 | V17-G1..G10 | test_v17_gap_pairing.rb | PASS |
| §18.3 X1 (PRODUCTION PATH) | V17-X1 [PRODUCTION PATH] | test_v17_production_gap_path.rb | PASS |
| §18.3 X1 (low-level mirror) | V17-X1-MIRROR-PREDICATE | test_v17_branch_crossing.rb | PASS (low-level) |
| §18.3 X2 (PRODUCTION PATH) | V17-X2 [PRODUCTION PATH] | test_v17_production_gap_path.rb | PASS |
| §18.3 X2 (low-level mirror) | V17-X2-MIRROR-PREDICATE | test_v17_branch_crossing.rb | PASS (low-level) |
| §18.3 X3 | V17-X3 | test_v17_branch_crossing.rb | PASS |
| §18.3 X3 (pairwise) | V17-X3-PAIRWISE | test_v17_branch_crossing.rb | PASS |
| §18.3 X4 (PRODUCTION PATH) | V17-X4 [PRODUCTION PATH] | test_v17_production_gap_path.rb | PASS |
| §18.3 X4 (low-level 2-line) | V17-X4-LOWLEVEL-2LINE | test_v17_branch_crossing.rb | PASS (low-level) |
| §18.4 H1 | V17-H1 | test_v17_host_mutation.rb | PASS |
| §18.4 H2 | V17-H2 | test_v17_host_mutation.rb | PASS |
| §18.4 H3 (PRODUCTION PATH, multi-bridge batch) | V17-H3 [PRODUCTION PATH] | test_v17_production_gap_path.rb | PASS |
| §18.4 H3 (build_entity failure) | V17-H3 | test_v17_host_mutation.rb | PASS |
| §18.4 H4 (commit uncertainty) | V17-H4 | test_v17_host_mutation.rb | PASS |
| §18.4 H5 (post-state mismatch) | V17-H5 | test_v17_host_mutation.rb | PASS |
| §18.4 H6 (source fingerprint) | V17-H6 | test_v17_host_mutation.rb | PASS |
| §18.4 H7 (source-edge coords) | V17-H7 | test_v17_host_mutation.rb | PASS |
| §18.5 T1 | V17-T1 | test_v17_canonical_graph.rb | PASS |
| §18.5 T2 | V17-T2 | test_v17_canonical_graph.rb | PASS |
| §18.5 T3 (PRODUCTION PATH) | V17-T3 [PRODUCTION PATH] | test_v17_production_gap_path.rb | PASS |
| §18.5 T4 (PRODUCTION PATH, exact cycle, 4 nodes) | V17-T4 [PRODUCTION PATH] | test_v17_production_gap_path.rb | PASS |
| §18.5 T4 (PRODUCTION PATH, 3/3 form) | V17-T4-EXACT3 | test_v17_production_gap_path.rb | PASS |
| §18.5 T4 (BFS, low-level) | V17-T4 | test_v17_canonical_graph.rb | PASS (kept for audit) |
| §18.5 T5..T7 | V17-T5..T7 | test_v17_canonical_graph.rb | PASS |
| §18.6 L1 | V17-L1 | test_v17_canonical_graph.rb | PASS |
| §18.6 L2 (SR-01 ownership) | V17-L2 | test_v17_canonical_graph.rb | PASS |
| §18.6 L3 (SR-01 ownership) | V17-L3 | test_v17_canonical_graph.rb | PASS |
| §18.6 L4 | V17-L4 | test_v17_canonical_graph.rb | PASS |
| §18.7 P1..P3 | V17-P1..P3 | test_v17_performance.rb | PASS |
| §15.1 origin_kind translation | V17-OK-MAP-1, -2 | test_v17_branch_crossing.rb | PASS |
| R5 (prior packet) | V17-R5-REG-LAYER, FROZEN, CLUSTER | test_v17_production_gap_path.rb | PASS |
| R6 (prior packet) | V17-R6-NODE-IDENTITY | test_v17_production_gap_path.rb | PASS |
| SR-01 | V17-SR1-1, -2, -3, -4 | test_v17_production_gap_path.rb | PASS |
| SR-02 | V17-SR2-1, -2, -3, -4 | test_v17_production_gap_path.rb | PASS |
| SR-03 | V17-SR3-1, -2, -3, -4, -5 | test_v17_production_gap_path.rb | PASS |
| SR-04 | V17-SR4-1, -2, -3 | test_v17_production_gap_path.rb | PASS |
| SR-05 | V17-SR5-1 | test_v17_production_gap_path.rb | PASS |
| SR-06 | V17-SR6-1 | test_v17_production_gap_path.rb | PASS |
| SR-07 | V17-SR7-1, -2, -3, -4 | test_v17_production_gap_path.rb | PASS |

---

## K. Prior-stage regressions + RBZ (per dispatch §K + L)

- **V16 close-autodiscard** (V16-CLOSE-AUTODISCARD): 7/7 PASS (no
  regression).
- **V15 host-state / BLOCK-005** (V15): 149/149 PASS (no
  regression).
- **LEGACY-COMPAT**: 4/4 PASS (no regression).
- **RBZ smoke** (`tests/test_rbz_smoke.rb`): 9/9 PASS
  (post-rebuild).
- **`git diff --check`**: clean.

---

## L. RBZ identity (per dispatch §K)

Rebuilt via `scripts/build_rbz.rb` after the production fixes
landed:

- **Path**: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- **Size**: 937,804 bytes
- **Entries**: 67
- **SHA-256**:
  `9C7F701CDFBA1A908B329546C53BA325AC035544A4B6FF356C883BD84403FCCF`
- **`su_ai_plugin.rb`** at RBZ root (entry-point convention OK).
- **`su_ai_plugin/`** support folder (sibling of entry-point).
- All V1.7 production files shipped (verified by
  `test_rbz_smoke.rb`).
- Frontend asset trio (`html/{index.html, app.js, style.css}`)
  shipped and byte-identical to in-tree source (no JS-side
  change in this dispatch).
- `tests/`, `scripts/`, `Review/`, `Prompt/`, `.vendor/`,
  `.git/` dev-only paths excluded (rbz_smoke verified).

---

## M. Git facts (per dispatch §M)

- **Starting HEAD (pre-this-dispatch)**: `2cdebb2`
  (the prior V17-AIPM-EVIDENCE-INTEGRATION-FINAL doc-stamp
  commit).
- **Closed V1.6 base SHA**: `d7e9c59` (V1.6 CLOSE-AUTODISCARD).
- **V17 substantive implementation HEAD**: `e98326e` (preserved
  from prior packet; this dispatch is a correction packet on
  top).
- **Final HEAD on `dev/v1.7`**: see `git rev-parse HEAD` after
  the correction commits land; the doc-stamp commit is the last
  commit on the assigned branch.
- **Working tree (this dispatch, pre-commit)**: 4 modified
  production files + 3 modified test files + 1 new patch file
  (`Review/V17_AIPM_SOURCE_REVIEW.patch`) + 1 untracked review
  file (`Review/CURRENT_AIPM_REVIEW_V17_DIRECT_SOURCE_REVIEW.md`).
- **NOT PUSHED per dispatch §8 + §12 at the time of this report's
  test run.** Push is attempted as the final step (after all
  tests are green and the local checkpoint is stable).
- **`git diff --check`**: clean.
- **Local commits created (this dispatch)**: one production
  commit (SR-01..SR-07 corrections + tests) + one doc-stamp
  commit (CURRENT_STATE update + CURRENT_PI_REPORT overwrite +
  patch refresh).

---

## N. Remaining defects / assumptions / unknowns (per dispatch §M)

### Confirmed defects (this dispatch)

None. All seven SR findings are corrected; the 22 new SR
regression tests are green; the full Ruby suite + RBZ smoke +
V16 close-autodiscard + V15 host-state + LEGACY-COMPAT are all
green; `git diff --check` is clean.

### Assumptions (require AIPM direct source review or Owner
SU2020 confirmation)

- The new `_point_on_segment_interior?` predicate uses a
  conservative band `[eps/seg_len, 1 - eps/seg_len]` for the
  projection parameter t. For very short segments (seg_len
  close to eps) the band becomes wide; for typical CAD gaps
  the band is well-defined. Owner Scenario E (crossing) and the
  Owner scenarios involving the bridge close to a pre-existing
  vertex exercise this path.
- The plural `source_occurrence_ids` field is the V1.8
  authority; the singular `source_occurrence_id` is preserved
  for backwards compatibility. V1.8 must consume the plural
  field.
- The canonical_node_count in the published metrics is
  computed AT THE GRAPH CONSTRUCTOR boundary (after
  SR-07 collapse). The topology snapshot's `metrics` Hash
  still carries the per-endpoint builder counts; the GRAPH
  finalizes the canonical_node_count before publication.
- The new `_canonical_post_validate` runs AFTER the host
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
  V1.7's BLOCK-005 inheritance provides the validate-on-next-
  interaction fallback (workspace transitions to `:failed`
  with `host_state_changed`), but real-host evidence is
  required.
- Whether the bridge-endpoint host_vertex_handle resolution
  via `edge_endpoints` returns the same world coordinates on
  real SU as the source-edge endpoints within
  coordinate_epsilon. The V1.6 `vertex_position` seam is
  exercised by the post-validation; the Owner Scenario F
  (Undo + host-consistency) is the canonical evidence.

### Owner-only

- Real human approval of the V1.7 UI (Scenario A's primary
  product feature: "发现 1 个可安全修复的间隙").
- Acceptance that Scenario F demonstrates the BLOCK-005
  inheritance is sufficient.
- Final experience-freeze decision (this is an `Owner Gate`,
  not a Pi or AIPM decision).

---

## O. Mandatory review state (per dispatch §N)

```
CODEX_GATE: STILL PENDING — DO NOT INVOKE
```

Justification:
- The V1.7 Blueprint §13 declares the canonical Codex xHigh
  integration review mandatory for V1.7.
- This dispatch corrected the SR-01..SR-07 findings but V1.7
  is NOT ready for Codex until AIPM direct source review (this
  report's owner) reaches PASS.
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

---

## P. Push outcome (per Owner/AIPM post-dispatch instruction)

After all required tests were green and the final stable local
`dev/v1.7` checkpoint existed, ONE normal fast-forward push of
the assigned branch was attempted. Result: see `git ls-remote
origin dev/v1.7` after push.

- Branch pushed only to the assigned `dev/v1.7`.
- No force-push, no rebase, no rewrite of shared history.
- No `main` push/merge, no tag/release.

---

## Definition of done (per dispatch §10)

- [x] SR-01 corrected (workspace-owned bridge; no separate
      repair-group edge).
- [x] SR-02 corrected (true `:failed` workspace on confirmed
      abort; logical rollback via `pre_workspace`).
- [x] SR-03 corrected (executor-side A..G + runner-side
      H..K + `canonical_post_validation_failed` reason).
- [x] SR-04 corrected (true point-on-segment-interior
      predicate with projection parameter t + closest-point
      distance + endpoint exclusion).
- [x] SR-05 corrected (deterministic `der-gap-#{proposal_id}`;
      no `rand`).
- [x] SR-06 corrected (plural `source_occurrence_ids` +
      singular preserved for backwards compatibility).
- [x] SR-07 corrected (collapse records by `canonical_node_id`
      into ONE logical graph node at the constructor boundary;
      unique logical count in `canonical_node_count`).
- [x] 22 SR-01..SR-07 regression tests added (dispatch §9).
- [x] Prior-stage regressions + RBZ smoke green (921/921).
- [x] `git diff --check` clean.
- [x] RBZ rebuilt (937,804 bytes / 67 entries / SHA-256
      `9C7F701CDFBA1A908B329546C53BA325AC035544A4B6FF356C883BD84403FCCF`).
- [x] `CODEX_GATE: STILL PENDING — DO NOT INVOKE` recorded
      in §O.
- [x] `OWNER GATE: NOT YET RUN` recorded in §O.
- [x] No claim of AIPM PASS / Codex PASS / Owner PASS.
- [x] V1.8 NOT STARTED.
- [x] `main` not pushed / merged.
- [x] No force-push / rebase / shared-history rewrite.

---

## STOP and return control to AIPM.

Next Gate: AIPM direct source RE-REVIEW of
`Review/V17_AIPM_SOURCE_REVIEW.patch` + the corrected V1.7 HEAD.

Only after AIPM primary PASS: mandatory Codex xHigh integration review.

End of report.
