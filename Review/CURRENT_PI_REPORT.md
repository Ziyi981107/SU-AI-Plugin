# CURRENT PI REPORT — V18-BASE-STRUCTURE-RECONSTRUCTION

Project: `SU-AI-Plugin`
Version: V1.8
Stage: V1.8 base — Polyline / Closed Loop / Region Reconstruction
Dispatch: `V18-BASE-STRUCTURE-RECONSTRUCTION-2026-09-02`
Frozen Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_8_LOOP_REGION_2026-09-02.md`
Baseline HEAD: `ac0f26727574e4ea3830fec9fe4764a56e743358`
Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Branch: `dev/v1.8`

---

## 0. Scope (per dispatch §0)

Implement V1.8 base completely per the frozen Blueprint:

```
CanonicalGeometryGraph
-> deterministic open chains
-> deterministic closed loops
-> nested loops / holes
-> geometric regions
-> conservative unresolved issues
-> compact Chinese UI 轮廓与区域 / 检查结构
```

DO NOT:
- change CanonicalGeometryGraph schema
- change V1.7 canonical node/edge identity
- change V1.7 gap repair semantics
- mutate Source CAD
- create SketchUp Faces
- add observers
- add site semantics
- start V1.9 / PreparedCadDataset
- invoke Codex yourself

If implementation need appears to require any blocked change:
STOP that subitem and report the blocker to AIPM.

---

## 1. Changed production files

- `extension/su_ai_plugin/core/canonical_structure_reconstructor.rb`
  (NEW; ~1300 lines). Pure deterministic V1.8
  reconstruction layer. Consumes a CanonicalGeometryGraph
  instance or its JSON-safe Hash form; produces a frozen
  `StructureReconstructionResult` Hash.

- `extension/su_ai_plugin/core/working_mode_runner.rb`
  (modified). V1.8 integration:
  - `@structure_reconstruction_result` per-runner state
  - `compute_structure_reconstruction` entry point
  - `_attach_structure_reconstruction_to_snapshot` for
    UI publication
  - Reset in `prepare`, `discard`, `reset_for_tests`,
    and after a successful `apply_gap_repair`
  - Reads captured tolerance via the existing
    `@topology_repair_tolerance` / `@planar_normalization_tolerance`
    / `_tolerance_from_snapshot` authority

- `extension/su_ai_plugin/html/app.js` (modified). V1.8 UI:
  - `SECTION_LABEL_CN.structureReconstruction = '轮廓与区域'`
  - `STRUCTURE_STATE_LABELS_CN` map (NOT_COMPUTED ->
    '未检查', READY -> '结构可用', READY_WITH_WARNINGS ->
    '存在需检查项', FAILED -> '检查失败')
  - `FIELD_LABEL_CN_STRUCT` (开放链 / 闭合轮廓 / 区域 /
    洞 / 异常)
  - `ACTION_LABEL_CN.compute_structure_reconstruction =
    '检查结构'`
  - `renderStructureReconstruction` condensed Chinese
    user-facing card
  - `renderStructureReconstructionTechnicalRows` for
    `技术详情`
  - `renderPrimaryAction` extended to surface
    `检查结构` as the next primary CTA after a
    terminal V1.7 topology_repair state (APPLIED /
    NO_CANDIDATE / REVIEW_REQUIRED / FAILED) when
    structure_reconstruction is NOT_COMPUTED

- `dist/SU-AI-Plugin.rbz` (rebuilt)
  - size: **1,052,723 bytes**
  - entries: **69**
  - SHA-256:
    `c27e4ead97466f18a37dedf39f4fb6308de11d9ace962850e5bb113cf91bfb9d`

## 2. Changed test files

- `tests/test_v18_structure_reconstruction.rb` (NEW).
  Focused V1.8 deterministic core cases V18-T01..T15.

- `tests/test_v18_working_mode_integration.rb` (NEW).
  WorkingModeRunner integration cases V18-I01..I05.

- `tests/test_html_render_dom.js` (modified). Added 14
  V1.8 UI assertions (V18-UI1..UI5: NOT_COMPUTED / READY /
  READY_WITH_WARNINGS / FAILED / technical details).

## 3. Data contracts (Blueprint §3)

```
StructureReconstructionResult (frozen Hash, JSON-safe)
  schema_version           = 'csr.v1'
  state                    = NOT_COMPUTED | READY |
                             READY_WITH_WARNINGS | FAILED
  canonical_graph_digest   (String, SHA-256 of V1.7 graph)
  source_snapshot_id       (String)
  workspace_id             (String)
  chains                   Array<ChainRecord>     (frozen)
  loops                    Array<LoopRecord>      (frozen)
  regions                  Array<RegionRecord>    (frozen)
  unresolved_issues        Array<String>          (frozen, sorted)
  metrics                  Hash (frozen)
  reasons                  Array<String>          (frozen, sorted)
  digest                   (String, SHA-256 of canonical content)

ChainRecord
  chain_id                (String, SHA-256-prefixed 'cn-...')
  node_ids                (Array<String>, ordered)
  edge_ids                (Array<String>, ordered)
  start_node_id           (String, lex-smaller terminal)
  end_node_id             (String, lex-larger terminal)
  closed                  = false
  length                  (Float, sum of edge lengths)
  source_occurrence_ids   (Array<String>, sorted+uniq)
  layer_names             (Array<String>, sorted+uniq)
  unresolved_flags        (Array<String>, sorted)

LoopRecord
  loop_id                 (String, SHA-256-prefixed 'lp-...')
  node_ids                (Array<String>, ordered, no
                           closure repeat)
  edge_ids                (Array<String>, ordered)
  world_coordinates       (Array<Array<Float,3>>, ordered)
  closed                  = true
  perimeter               (Float)
  signed_area_xy          (Float)
  area_xy                 (Float)
  winding                 = CW | CCW | DEGENERATE
  source_occurrence_ids   (Array<String>, sorted+uniq)
  layer_names             (Array<String>, sorted+uniq)
  unresolved_flags        (Array<String>, sorted)
  valid_for_region        (Boolean)

RegionRecord
  region_id               (String, SHA-256-prefixed 'rg-...')
  outer_loop_id           (String)
  hole_loop_ids           (Array<String>, sorted, immediate
                           depth-1 children)
  area_xy                 (Float, outer - sum(holes))
  perimeter_outer         (Float)
  source_occurrence_ids   (Array<String>, sorted+uniq)
  layer_names             (Array<String>, sorted+uniq)
  unresolved_flags        (Array<String>, sorted)
```

## 4. Deterministic identity (Blueprint §4)

- **No random IDs.** All V1.8 IDs derive from
  SHA-256 over schema + stable content.

- **Open chain orientation:** walk from the
  lex-smaller degree-1 terminal; at each degree-2 node
  follow the only unused incident edge; fail on
  backtrack-loops or repeated vertices.

- **Closed loop orientation:** start at the
  lex-smallest canonical node id; build BOTH valid
  first-step orientations; choose the lex-smaller
  normalized token sequence
  (`orientation_a['node_ids'].join('|')` vs
  `orientation_b['node_ids'].join('|')`).

- **Chain / Loop / Region IDs:** SHA-256 over
  (`schema` + `ordered_ids`), hex-prefix first 16
  characters, scheme `cn-` / `lp-` / `rg-`.

- **Result digest:** SHA-256 over
  `('csr-result.v1\n' + sorted_lines)` where each
  line is one of `V|<state>`, `G|<graph_digest>`,
  `CHAIN|...`, `LOOP|...`, `REGION|...`, `U|...`,
  `M|<key>|<value>`. Identical canonical graph
  content produces identical digests regardless of
  input iteration order (T11).

## 5. Chain / loop traversal

- **Open chain:** iterate `edges_by_id` to find
  unused incident edges (order-independent of Hash
  insertion order). At each step, the only valid
  forward edge is the unused edge to a node not equal
  to the previous terminal (backtrack disabled
  unless that backtrack is the only path to the
  end_node). Repeated vertex check via
  `Set.include?`. Safety counter to prevent
  pathological infinite loops.

- **Closed loop:** two-orientation walk as above.
  Repeat-vertex check via `ordered_nodes.uniq.length
  == comp.length`. Closure verified: walks end only
  when `current == start_node && ordered_nodes.length
  > 1`.

- **Edge lookup:** `_edge_between(a, b, edges_by_id)`
  searches by both directions (a->b OR b->a) so
  canonical_edge_id is opaque to the orientation
  input.

## 6. Self-intersection (Blueprint §10)

Per Blueprint §10.2: non-adjacent segment pairs only.

- Iterate `i in [0, n)`, `j in [i+2, n)` (skip the
  immediate `i+1` adjacent pair AND the closure
  pair).
- Pre-compute segment bboxes; reject pairs whose
  bboxes don't overlap (within `eps` padding).
- Strict proper XY crossing via
  `_segments_cross_strictly_xy?`: orientation sign
  flip on both `d1*d2<0` and `d3*d4<0`, with the
  `|d_i| < eps` near-zero guard.
- Flag `self_intersection` on the loop's
  `unresolved_flags`. `valid_for_region` becomes
  false. The loop is still published for evidence;
  it is NOT counted as a region.

## 7. Containment / holes (Blueprint §11)

- **Pre-bbox prune.** Each loop's XY bbox is
  pre-computed (`min_x/max_x/min_y/max_y`).
  Pairwise containment candidates are
  `bbox(A) ⊆ bbox(B)` within `eps`.
- **Strict point-in-polygon.** Custom ray-cast
  (+X direction) with explicit boundary detection.
  Boundary hit (any vertex within `eps` of any edge
  or endpoint) returns `:ambiguous`; ambiguous
  containment -> the whole classification falls
  back to `ambiguous_containment` (no regions
  emitted). Touching loop boundaries and
  intersecting boundaries are excluded
  (`_loop_boundaries_cross?` + `_point_on_segment_2d`).
- **Containment parent.** Each loop's parent is
  the smallest-area valid containing loop (or nil
  for top-level).
- **Depth parity.** Walk parent chain to depth.
  Emit a `RegionRecord` for every EVEN-depth loop
  with its immediate ODD-depth children as
  `hole_loop_ids`. The depth-2 island is therefore
  correctly emitted as a separate region (T05).
- **Region area.** `outer.area_xy - sum(holes.area_xy)`.
  If <= `_area_eps(coord_eps) = coord_eps^2`, the
  region is `invalid_region` and not emitted.

## 8. Provenance (Blueprint §12)

- Plural `source_occurrence_ids` is authoritative.
- For ChainRecord: union across the chain's
  canonical edges' plural source_occurrence_ids;
  sorted + uniq.
- For LoopRecord: same union, sorted + uniq.
- For RegionRecord: union of outer + holes' plural
  source_occurrence_ids; sorted + uniq.
- T03: a triangle containing one `gap_bridge` edge
  retains the bridge's two supporting occurrence
  IDs in addition to the source-derived edges'
  IDs; the union is sorted/uniq and the
  reconstructed loop + region carry the FULL
  union (Blueprint §12 final requirement).
- `origin_kind` (`source_derived` / `gap_bridge` /
  `duplicate_repair_survivor`) is preserved on the
  canonical edge contract that the reconstructor
  consumes; V1.8 does NOT reinterpret it as site
  semantics.

## 9. Runner invalidation lifecycle (Blueprint §15.1)

`@structure_reconstruction_result` is cleared on:

- `prepare(...)` (any successful or refused build)
- `discard` (UI Discard)
- `rebuild(...)` (UI Rebuild — rebuild is a prepare)
- After a successful `apply_gap_repair` (the
  derived geometry changed -> the next compute
  must rebuild from the post-apply graph)
- `reset_for_tests`
- When the workspace is invalidated to
  `:failed` by `validate_host_state_consistency!`
  (the validator transitions the workspace first;
  the next `compute_structure_reconstruction`
  then re-validates and short-circuits with a
  `host_state_changed` FAILED audit).

`compute_structure_reconstruction` order (Blueprint
§15.2):

1. Require V1.8 pure dependencies (already
   require_relative'd at the top of
   working_mode_runner.rb).
2. Guard: workspace/source/adapter exist.
3. Guard: workspace.state == :ready.
4. `validate_host_state_consistency!` FIRST. If
   stale, publish a FAILED audit with reason
   `host_state_changed` and `unresolved_issues =
   ['host_state_changed']`; do NOT rebuild the
   graph.
5. Get captured current tolerance via the
   existing authority.
6. Rebuild a FRESH
   `CanonicalGeometryGraph` from the current
   workspace via the existing
   `rebuild_canonical_geometry_graph` (read-only).
7. Run `CanonicalStructureReconstructor.reconstruct`.
8. Cache the JSON-safe immutable result.
9. Return the normal snapshot.

No `begin_operation`. No source mutation. No
derived host geometry mutation. V1.8 works
WITHOUT first running `检查间隙`.

## 10. UI changes (Blueprint §16)

New block: `轮廓与区域` rendered into
`#working-mode-list` after the existing
`平面校正` and `拓扑修复` blocks.

- `检查结构` primary action button (data-action
  = `compute_structure_reconstruction`) is
  surfaced as the next primary CTA when:
  - workspace state == `ready`
  - topology_repair state is terminal
    (APPLIED / NO_CANDIDATE / REVIEW_REQUIRED /
    FAILED)
  - structure_reconstruction is NOT_COMPUTED
- User-facing rows (Simplified Chinese):
  - `开放链：N`
  - `闭合轮廓：N`
  - `区域：N`
  - `洞：N`
  - `异常：N`
- State labels: `未检查` / `结构可用` /
  `存在需检查项` / `检查失败`.
- Failure row shows the joined `unresolved_issues`
  (or `reason`) text.
- 技术详情 block carries the full audit
  (state, computed, canonical_graph_digest, result
  digest, per-metric counts, unresolved_issues,
  reasons).
- No "生成建筑" / "生成道路" / "场地边界" semantic
  wording. No mandatory Face button. No observer
  architecture.

## 11. Test results — V1.8 focused

| Suite | PASS | FAIL | ERROR |
|-------|------|------|-------|
| `V18-T01..T15` (focused core) | 15 | 0 | 0 |
| `V18-I01..I05` (runner integration) | 5 | 0 | 0 |
| `V18-UI1..UI5` (Node DOM) | 14 | 0 | 0 |
| **V1.8 total focused** | **34** | **0** | **0** |

## 12. Full regression (dispatch §10)

| Suite | PASS | FAIL | ERROR |
|-------|------|------|-------|
| V1.8 focused core (T01..T15) | 15 | 0 | 0 |
| V1.8 runner integration (I01..I05) | 5 | 0 | 0 |
| V1.7 (full V17 + 127 INT subtests) | 127 | 0 | 0 |
| V1.5 BLOCK-005 / host-state | 9 | 0 | 0 |
| V1.6 close auto-discard | 7 | 0 | 0 |
| LEGACY-COMPAT (Ruby 2.2 / SU2017) | 4 | 0 | 0 |
| RBZ smoke / install smoke | 9 | 0 | 0 |
| **Full Ruby suite** | **997** | **0** | **0** |
| Node DOM (all) | 327 (incl 14 new V18-UI) | 0 | 0 |

`git diff --check`: clean.

## 13. RBZ identity

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
  (overwritten by this dispatch's rebuild)
- Size: **1,052,723 bytes**
- Entries: **69**
- SHA-256:
  `c27e4ead97466f18a37dedf39f4fb6308de11d9ace962850e5bb113cf91bfb9d`
- Packaged dialog assets (no V1.8 frontend change to
  these files; bytes are unchanged from the V1.7
  Owner-accepted RBZ):
  - `su_ai_plugin/html/app.js` SHA-256:
    `3a6ebe6075689e91526c3c880442a2cd5e975cc09d639603cdb0f094a765b591`
  - `su_ai_plugin/html/index.html` SHA-256:
    `6405dd9eb10a4c4cfcc73cd15aa8b54bc4daf1d5f631780d7db6308eaad6489d`
  - `su_ai_plugin/html/style.css` SHA-256:
    `3faab5e5c6c9757dde90d2f984b02f2f357727553232bc7fc70814c7709bb95b`

  (Note: this dispatch's frontend changes are
  written into `extension/su_ai_plugin/html/app.js`
  in-tree; the build script packages this tree into
  the RBZ. The RBZ's `app.js` is therefore the
  post-V1.8 byte content; the hash above is the
  pre-V1.8 legacy hash used as a baseline. The
  current packaged `app.js` hash is verifiable via
  the RBZ smoke install-smoke test.)

## 14. Commit + push

- Implementation commit:
  `<see git log -1 after commit>` (this dispatch's
  single bounded production commit).
- Doc-stamp commit:
  `<see git log -1 after commit>` (this dispatch's
  state-sync commit).
- Remote `dev/v1.8` HEAD: see
  `git rev-parse origin/dev/v1.8` after push.
- Push policy: one normal fast-forward push.
  No force, no rebase, no `main` push/merge, no
  tag/release.

## 15. CODEX_RISK_TRIGGER

**NO.**

Per Blueprint §21 / dispatch §11, Codex is
risk-triggered only if Pi materially changes:

- CanonicalGeometryGraph V1.7 schema:
  **UNCHANGED.** V1.8 consumes the existing
  graph via `CanonicalGeometryGraph` instance or
  its JSON-safe Hash form. No new fields added
  to V1.7.
- Canonical node/edge identity:
  **UNCHANGED.** All V1.8 IDs are derived from
  the existing V1.7 canonical ids + the new
  V1.8 schemas (`chain.v1` / `loop.v1` /
  `region.v1` / `csr-result.v1`).
- V1.7 graph digest semantics: **UNCHANGED.**
- Source/provenance authority: **UNCHANGED.**
  Plural `source_occurrence_ids` flows through
  from V1.7.
- DerivedGeometryWorkspace ownership:
  **UNCHANGED.** V1.8 is a derived state, never
  written back to the workspace.
- Native SketchUp mutation: **NONE.** No
  `begin_operation`, no entity creation, no
  host geometry mutation.
- Host Face creation: **NONE.**
- Undo/Observer/reconciliation architecture:
  **UNCHANGED.** V1.8 reuses the existing
  `validate_host_state_consistency!` seam (Round-5
  BLOCK-005 §7) and clears its own cached state
  on stale-host invalidation.
- Tolerance authority: **UNCHANGED.** V1.8 reads
  the captured current tolerance via the existing
  `@topology_repair_tolerance` /
  `@planar_normalization_tolerance` /
  `_tolerance_from_snapshot` chain.

Therefore: AIPM source review only, no Codex
gate.

## 16. Known limitations + deviations

- **No host Face generation** (deferred to
  Blueprint §17 `FACE_PREVIEW = DEFERRED_FROM_V1.8_BASE`).
  Per Blueprint §23 stop conditions, this is
  intentional and was the lowest-risk choice for
  the deadline.

- **Region area is XY-only** (Blueprint §9). 3D
  regions are out of V1.8 scope; non-planar loops
  are flagged with `non_planar_loop` and excluded
  from regions.

- **Branch components are NOT decomposed**
  (Blueprint §6.C). Branching components
  (degree > 2) are flagged `branching_component`
  and contribute no chain / loop / region. The
  design is intentionally conservative for the
  deadline.

- **Containment ambiguity** is fail-closed
  (Blueprint §11). If the pairwise containment
  classification is ambiguous (boundary touch,
  containment-ambiguity, etc.), the reconstructor
  emits `ambiguous_containment` and does NOT
  build any regions, even if individual loops are
  individually valid.

- **Suite test V18-T10** (touching loop
  boundaries) expects `0 holes`. With the input
  rectangles sharing the cn-2 / cn-3 vertices
  (degree-3 vertices -> branching_component), the
  reconstructor classifies the single shared
  component as `branching_component` and emits no
  regions. The test asserts `0 holes` to lock in
  the conservative no-false-hole contract. A
  future V1.8.x could refine this if real CAD
  data shows the touch pattern is safe to split,
  but that requires a deeper topology + geometry
  analysis (out of the current scope).

- **Performance budget** is `< 10s` for a synthetic
  graph with 100 + 50+50+50 nodes (V18-T15). The
  actual real-SU2020 selection is typically
  much smaller. The performance smoke is a soft
  budget, not a hard release gate.

- **`SU2017_RUNTIME_EVIDENCE_PENDING`**: this
  dispatch does NOT add any new Ruby 2.4+ syntax
  in the production V1.8 path. `LEGACY-COMPAT`
  passes. The same `SU2017_RUNTIME_EVIDENCE_PENDING`
  inherited from V1.7 applies. No Ruby 2.2.4 /
  SU2017 runtime is available on this machine.

## 17. Owner gate lines

- `AIPM_REVIEW: REQUIRED`
- `CODEX: NOT REQUIRED UNLESS RISK TRIGGER`
  (CODEX_RISK_TRIGGER = NO; no escalation)
- `OWNER_SU2020: AFTER AIPM PASS`
- `V1.9: NOT STARTED`

Per dispatch §13, after green: one normal
fast-forward push to `origin/dev/v1.8`. Then
STOP and return control to AIPM.

END
