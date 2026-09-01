# V1.7 AIPM Critical Source Index — Evidence-Integration-Final

Project: `SU-AI-Plugin`
Version: V1.7 (Endpoint / Gap Repair + Canonical Topology)
Dispatch: `V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01`
Prior dispatch: `V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01`
Implementation Agent: Pi
Reviewer: AIPM (direct source review)
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
Branch: `dev/v1.7`

This index lists the EXACT lines a reviewer needs to inspect to
verify each Blueprint §18 test / R5-R8 finding. Production-defect
regressions are listed at the bottom.

---

## 0. Headline disposition (R5-R8)

| ID | Finding | Disposition |
|----|---------|-------------|
| R5 | X1/X2 tests mirrored production code | CORRECTED — `tests/test_v17_production_gap_path.rb` drives the real `WorkingModeRunner._crossing_checker_proc`; the old mirror tests in `test_v17_branch_crossing.rb` are explicitly relabeled as `V17-X1-MIRROR-PREDICATE` / `V17-X2-MIRROR-PREDICATE`. |
| R6 | X4 used a 2-line substitute | CORRECTED — `V17-X4 [PRODUCTION PATH]` in `test_v17_production_gap_path.rb` uses a real 3-edge almost-closed triangle A-B, A-C, B-D with one short unique closing gap C-D; `V17-X4-LOWLEVEL-2LINE` in `test_v17_branch_crossing.rb` is now explicitly scoped as NOT Blueprint X4 evidence. |
| R7 | H3 mapped to H2 + H5 | CORRECTED — `V17-H3 [PRODUCTION PATH]` is a dedicated test exercising two independent safe bridges through the production `apply_gap_repair` path. |
| R8 | T4 proved connectivity only | CORRECTED — `V17-T4 [PRODUCTION PATH]` proves exact cycle invariants on the real fixture (degree-2 graph + deterministic cycle traversal); `V17-T4-EXACT3` proves the literal 3/3 form. |

## 1. Production defects uncovered by running the production path

This dispatch uncovered FOUR production defects by EXECUTING the
production `WorkingModeRunner.compute_gap_repair` path. None were
catchable by the prior test suite because the prior test seam was
the proposer + crossing_checker procs in isolation. They are
regression-locked in this packet:

| Production defect | File:line | Fix | Regression |
|-------------------|-----------|-----|------------|
| `NoMethodError: undefined method 'layer' for DerivedEntityRecord` raised for EVERY layered CAD selection during gap compute | `extension/su_ai_plugin/core/endpoint_record.rb` `DerivedTopologySnapshotBuilder.build` (layer-name resolution block) | Replaced the broken `(gs['layer'] || rec.respond_to?(:layer) ? rec.layer : nil)` ternary with `layer_name = gs['layer']; if layer_name.nil? && rec.respond_to?(:layer) then layer_name = rec.layer`. Intent unchanged. | `V17-R5-REG-LAYER` |
| `FrozenError: can't modify frozen Hash` raised inside `_canonical_topology_snapshot` for EVERY compute_gap_repair call | `extension/su_ai_plugin/core/working_mode_runner.rb` `_canonical_topology_snapshot` | `.dup` the frozen `CanonicalTopologyBuilder.build` result before assigning `:endpoints`. Published canonical sub-structures stay frozen. | `V17-R5-REG-FROZEN` |
| `topology_snapshot[:canonical_node_clusters]` resolved to `{}` on the production path because `CanonicalTopologyBuilder.build` publishes STRING keys; coincident corner endpoints were never merged into one canonical node (Blueprint §7.2) and were mis-reported as open endpoints (Blueprint §8). | `extension/su_ai_plugin/core/working_mode_runner.rb` `_open_endpoint_keys`; `extension/su_ai_plugin/core/gap_pair_proposer.rb` `propose` | Defensive symbol-OR-string read via `_ts_read`. Same pattern already used by `CanonicalGeometryGraph.build_from_workspace`. | `V17-R5-REG-CLUSTER` |
| Resolved coordinate_epsilon clique produced multiple `<cluster>.nN` canonical_node_ids, fragmenting the rebuilt canonical graph of a real almost-closed triangle into disjoint degree-1 fragments. | `extension/su_ai_plugin/core/canonical_topology_builder.rb` `_build_canonical_node_record` | Resolved clique members now share the cluster id as canonical_node_id (ONE canonical node per safe clique, Blueprint §7.2 / §7.3). Non-transitive cluster members still get distinct `.nN` ids. | `V17-R6-NODE-IDENTITY` |

## 2. Test matrix (dispatch §6)

| Blueprint | Test | File | Status |
|-----------|------|------|--------|
| §18.3 X1 (production path) | V17-X1 [PRODUCTION PATH] | `tests/test_v17_production_gap_path.rb` | PASS |
| §18.3 X1 (low-level mirror predicate, NOT production evidence) | V17-X1-MIRROR-PREDICATE | `tests/test_v17_branch_crossing.rb` | PASS (relabeled) |
| §18.3 X2 (production path) | V17-X2 [PRODUCTION PATH] | `tests/test_v17_production_gap_path.rb` | PASS |
| §18.3 X2 (low-level mirror predicate, NOT production evidence) | V17-X2-MIRROR-PREDICATE | `tests/test_v17_branch_crossing.rb` | PASS (relabeled) |
| §18.3 X3 (pairwise bridge conflict) | V17-X3 | `tests/test_v17_branch_crossing.rb` | PASS |
| §18.3 X3 (pairwise predicate-level) | V17-X3-PAIRWISE | `tests/test_v17_branch_crossing.rb` | PASS |
| §18.3 X4 (real almost-closed triangle, PRODUCTION PATH) | V17-X4 [PRODUCTION PATH] | `tests/test_v17_production_gap_path.rb` | PASS |
| §18.3 X4 (low-level 2-line substitute, NOT Blueprint X4) | V17-X4-LOWLEVEL-2LINE | `tests/test_v17_branch_crossing.rb` | PASS (relabeled) |
| §18.4 H1 | V17-H1 | `tests/test_v17_host_mutation.rb` | PASS |
| §18.4 H2 | V17-H2 | `tests/test_v17_host_mutation.rb` | PASS |
| §18.4 H3 (multi-bridge batch, PRODUCTION PATH) | V17-H3 [PRODUCTION PATH] | `tests/test_v17_production_gap_path.rb` | PASS |
| §18.4 H4 (renamed to V17-H3 in the file; add-line failure) | V17-H3 | `tests/test_v17_host_mutation.rb` | PASS |
| §18.4 H5 (renamed to V17-H4; commit uncertainty) | V17-H4 | `tests/test_v17_host_mutation.rb` | PASS |
| §18.4 H6 (renamed to V17-H5; post-state mismatch) | V17-H5 | `tests/test_v17_host_mutation.rb` | PASS |
| §18.4 H7 (source fingerprint unchanged) | V17-H6 | `tests/test_v17_host_mutation.rb` | PASS |
| §18.4 H8 (existing source-edge coordinates unchanged) | V17-H7 | `tests/test_v17_host_mutation.rb` | PASS |
| §18.5 T1 | V17-T1 | `tests/test_v17_canonical_graph.rb` | PASS |
| §18.5 T2 | V17-T2 | `tests/test_v17_canonical_graph.rb` | PASS |
| §18.5 T3 (PRODUCTION PATH, world-coord-anchored) | V17-T3 [PRODUCTION PATH] | `tests/test_v17_production_gap_path.rb` | PASS |
| §18.5 T4 (PRODUCTION PATH, real fixture + exact cycle invariant) | V17-T4 [PRODUCTION PATH] | `tests/test_v17_production_gap_path.rb` | PASS |
| §18.5 T4 (PRODUCTION PATH, literal 3 nodes + 3 edges form) | V17-T4-EXACT3 | `tests/test_v17_production_gap_path.rb` | PASS |
| §18.5 T4 (BFS-only connectivity, kept as low-level companion) | V17-T4 | `tests/test_v17_canonical_graph.rb` | PASS (kept for audit; superseded by V17-T4 [PRODUCTION PATH]) |
| §18.5 T5 | V17-T5 | `tests/test_v17_canonical_graph.rb` | PASS |
| §18.5 T6 | V17-T6 | `tests/test_v17_canonical_graph.rb` | PASS |
| §18.5 T7 | V17-T7 | `tests/test_v17_canonical_graph.rb` | PASS |
| §18.6 L1 | V17-L1 | `tests/test_v17_canonical_graph.rb` | PASS |
| §18.6 L2 | V17-L2 | `tests/test_v17_canonical_graph.rb` | PASS |
| §18.6 L3 | V17-L3 | `tests/test_v17_canonical_graph.rb` | PASS |
| §18.6 L4 | V17-L4 | `tests/test_v17_canonical_graph.rb` | PASS |
| §18.7 P1 | V17-P1 | `tests/test_v17_performance.rb` | PASS |
| §18.7 P2 | V17-P2 | `tests/test_v17_performance.rb` | PASS |
| §18.7 P3 | V17-P3 | `tests/test_v17_performance.rb` | PASS |
| §18.1 N1 | V17-N1 | `tests/test_v17_topology_identity.rb` | PASS |
| §18.1 N2 | V17-N2 | `tests/test_v17_topology_identity.rb` | PASS |
| §18.1 N3 | V17-N3 | `tests/test_v17_topology_identity.rb` | PASS |
| §18.1 N4 | V17-N4 | `tests/test_v17_topology_identity.rb` | PASS |
| §18.1 N5 | V17-N5 | `tests/test_v17_topology_identity.rb` | PASS |
| §18.1 N6 | V17-N6 | `tests/test_v17_topology_identity.rb` | PASS |
| §18.1 N5b | V17-N5b | `tests/test_v17_topology_identity.rb` | PASS |
| §18.2 G1..G10 | V17-G1..G10 | `tests/test_v17_gap_pairing.rb` | PASS |
| §15.1 origin_kind translation | V17-OK-MAP-1, V17-OK-MAP-2 | `tests/test_v17_branch_crossing.rb` | PASS |

## 3. Production code touched by this dispatch

| File | Lines | Change |
|------|-------|--------|
| `extension/su_ai_plugin/core/canonical_topology_builder.rb` | `_build_canonical_node_record` | Resolved clique -> ONE shared canonical_node_id; non-transitive -> distinct .nN ids. Blueprint §7.2 / §7.3. |
| `extension/su_ai_plugin/core/endpoint_record.rb` | `DerivedTopologySnapshotBuilder.build` layer-name resolution | Replaced broken ternary with explicit fallback; layered CAD no longer raises NoMethodError. |
| `extension/su_ai_plugin/core/gap_pair_proposer.rb` | `propose` + new `_ts_read` helper | Defensive symbol-OR-string read of canonical topology fields; Blueprint §7 canonical clustering now actually runs on the production path. |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | `_canonical_topology_snapshot`, `_open_endpoint_keys` | `.dup` of frozen builder result; defensive symbol-OR-string read; production compute_gap_repair / apply_gap_repair now actually run. |
| `tests/test_v17_branch_crossing.rb` | comments + test names | R5 / R6 relabel: mirror-proc tests are now explicitly low-level; X4-LOWLEVEL is explicitly NOT Blueprint X4. |
| `tests/test_v17_production_gap_path.rb` | new file (dispatch §1-§4) | New production-path evidence + regression locks for the four production defects. |

No frozen-design authority was changed: the V1.7 Blueprint, the
V1.6 closure anchor, the V1.6 backend, the V1.5 BLOCK-005
host-state consistency path, and the V1.4 derived-workspace
architecture are all untouched.

## 4. Source-review patch

- Path: `Review/V17_AIPM_SOURCE_REVIEW.patch`
- Base: `d7e9c59` (V1.6 CLOSE-AUTODISCARD closure)
- Final substantive HEAD: `e98326ee17cabdeec0b617f22576d1bdc5ce699a`
  (this dispatch's implementation commit)
- Doc-stamp HEAD: see `git rev-parse HEAD` after the doc-stamp
  commit lands (recorded in `Review/CURRENT_PI_REPORT.md` §L)
- Size: 316045 bytes
- SHA-256: `bc39afd7f9b139727043e9dddc1c2102c3a1afa7216de78ccd5e37ea7e504139`

## 5. RBZ identity (post-rebuild)

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: 907197 bytes
- Entries: 67
- SHA-256: `38e6dc1e71f79478a8882f899cfb14bb5ab021e1fbd84287c0d2bfb8d1070648`

The RBZ rebuilds from current source via
`scripts/build_rbz.rb`. The 4 production-byte changes above flow
into the RBZ transparently.

## 6. Reviewer checklist (verified-by-inspection)

- [ ] Confirm the production path actually runs (it could not
  before this dispatch — verify the four R5 regressions all
  FAIL on the prior packet and PASS on this one).
- [ ] Confirm `WorkingModeRunner._crossing_checker_proc` is the
  ONLY crossing authority exercised by V17-X1 / X2 [PRODUCTION
  PATH] (no test seam constructs its own crossing proc).
- [ ] Confirm the X4 fixture is a real 3-edge almost-closed
  triangle A-B / A-C / B-D with one short unique closing gap
  C-D, NOT a 2-line substitute.
- [ ] Confirm H3 [PRODUCTION PATH] batches TWO bridges into ONE
  native SketchUp operation (1 begin, 1 commit, 0 abort, exactly
  2 generated bridges).
- [ ] Confirm T4 [PRODUCTION PATH] proves an ACTUAL cycle
  invariant (degree-2 graph + deterministic cycle traversal),
  not just BFS connectivity.
- [ ] Confirm the canonical_node_id change is local to
  `CanonicalTopologyBuilder._build_canonical_node_record` and
  does not affect V1.8 Loop/Region semantics (no LoopRecord /
  RegionRecord introduced).
- [ ] Confirm no Blueprint §was silently widened (tolerance
  semantics, Source of Truth, identity, transforms, transaction
  / recovery all unchanged).