# CURRENT PI REPORT — V18-AIPM-SOURCE-REVIEW-CORRECTION

Project: `SU-AI-Plugin`
Version: V1.8
Stage: V1.8 base — Polyline / Closed Loop / Region Reconstruction
Dispatch: `V18-AIPM-SOURCE-REVIEW-CORRECTION-2026-09-02`
Authority: `Review/CURRENT_AIPM_REVIEW.md` (AIPM direct source review)
Baseline HEAD: `4ca73ccb5684434fd102c0e6a059d60c186b627f` (dev/v1.8 V18-BASE-STRUCTURE-RECONSTRUCTION complete state)
Target branch: `dev/v1.8` (per dispatch §0)
Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

---

## 0. Scope (per dispatch §0)

ONE bounded correction packet for V1.8 base. Fix ONLY
`SR18-01..SR18-08` from AIPM direct source review. No V1.7
schema/identity/digest changes. No SegmentConflict semantic
changes. No source/provenance authority changes. No workspace
ownership changes. No host mutation / Face / Observer. No
site semantics. No V1.9. No Codex self-invocation.

---

## 1. Status

- **V1.7: CLOSED** (per
  `Prompt/AIPM_V1_7_OWNER_ACCEPTED_CLOSURE_2026-09-02.md`).
- **V1.8: ACTIVE**.
- **V1.8 AIPM source review**: BLOCK → all SR18-01..SR18-08
  fixed; Pi Complete; awaiting AIPM narrow recheck.
- **V1.8 Codex gate**: NOT REQUIRED
  (`CODEX_RISK_TRIGGER = NO`).
- **V1.8 Owner SU2020 gate (Scenarios A–D)**: pending AFTER
  AIPM narrow recheck PASS.
- **V1.9 / PreparedCadDataset**: NOT STARTED.
- **V2 / MCP**: OUT OF SCOPE.

Frozen V1.8 Blueprint preserved unchanged on the assigned
`dev/v1.8`. Pi did NOT rewrite any frozen design authority.

---

## 2. Corrections by this dispatch (each regression-locked)

### SR18-01 — Ruby 2.2 source guard
- `core/canonical_structure_reconstructor.rb` — replaced
  `regions.sum { |r| Array(r['hole_loop_ids']).length }`
  with explicit `hole_count = 0; regions.each { |r|
  hole_count += Array(r['hole_loop_ids']).length }` (Ruby
  2.2.4 / SketchUp 2017 ships 2.2.4, no Enumerable#sum).
- `core/canonical_structure_reconstructor.rb` — replaced
  `hole_ids.sum { |hid| ... }` with explicit `hole_area =
  0.0; hole_ids.each do |hid| ... end` in `_build_regions`.
- Tests: `V18-SR01` (source-level static guard asserts NO
  production `.sum`) and runtime guard
  (`Array#sum undef` then verify hole_count/region_area
  remain correct).

### SR18-02 — coordinate_epsilon authority
- `core/canonical_structure_reconstructor.rb` — added
  `_safe_eps(coord_eps)` and `_resolve_coordinate_eps(graph, kw)`
  to thread ONE resolved epsilon through the entire
  reconstruction with authority order:
  1. explicit `coordinate_epsilon:` keyword arg
  2. per-node `coordinate_epsilon` (consistent across nodes
     → use; disagreeing → median)
  3. hard-coded `1e-6` fallback (defensive only).
- `reconstruct(...)` now accepts a `coordinate_epsilon:`
  keyword argument. `_validate_loop_geometry`,
  `_validate_loop_self_intersection`,
  `_classify_loop_containment`, `_build_regions`, and the
  per-loop `_loop_coord_eps` lookup all consume the
  resolved `coord_eps`. The resolved value is published on
  each loop's `coordinate_epsilon` field.
- `core/working_mode_runner.rb` — `compute_structure_reconstruction`
  extracts `tol.coordinate_epsilon` (if finite + positive) and
  passes it as the new keyword. No silent 1e-6 fallback when
  a valid non-default captured tolerance is present.
- Tests: `V18-SR02` (1e-3 + 1e-5 + 1e-6 fallback cases; per-loop
  flag assertions consistent with V18-T09's `loop['unresolved_flags']`
  contract).

### SR18-03 — loop conflict detection (non-adjacent segments)
- `core/canonical_structure_reconstructor.rb` —
  `_validate_loop_self_intersection` now routes every
  non-adjacent pair check through the shared V1.7
  `SegmentConflict.conflict?` pure predicate. The four
  conflict kinds are surfaced with stable per-loop reasons:
  - proper interior crossing → `self_intersection`
  - endpoint on unrelated segment interior (T-junction-like)
    → `loop_endpoint_on_segment`
  - collinear interior overlap → `loop_collinear_overlap`
  - non-adjacent geometric touch → `loop_geometric_touch`
  - (V1.7 SegmentConflict semantics preserved; no
    SegmentConflict source change).
- Adjacent pairs (including the closure-adjacent segment)
  are SKIPPED. Closure adjacency is NOT a conflict.
- Tests: `V18-SR03` (bow-tie, T-junction, collinear overlap,
  normal rectangle negative test).

### SR18-04 — O(V+E) traversal via edge indexes
- `core/canonical_structure_reconstructor.rb` — added
  `_build_edge_indexes(edges_by_id)` that produces once:
  - `incident` (Hash[node_id] → sorted edge IDs)
  - `pair_to_edges` (Hash[sorted "a|b"] → sorted edge IDs)
  - `edge_endpoints` (Hash[edge_id] → [sorted_a, sorted_b])
  - `has_parallel` / `parallel_pairs` (parallel edge
    detection)
- `_classify_component` now:
  - Detects parallel edges FIRST and returns `:parallel_edges`
    with stable reason `parallel_edges_unsupported:<a>|<b>`
    per affected pair. No guessing.
  - Uses the incident index for degree computation.
  - Calls `_edges_in_component_via_index` (O(V+E_comp)
    instead of O(V²) combination scan).
- `_walk_cycle` and `_build_chain` use the index:
  - `_edge_between(a, b, edges_by_id, edge_indexes)` is
    O(1) via the pair index (falls back to a defensive
    scan only if the index is missing the pair).
  - chain walk incident lookups are O(deg(current)) per
    step.
- `comp.combination(2)` and `edges_by_id.each do ...` per
  traversal step are ELIMINATED from the production path.
- Tests: `V18-SR04` (no `comp.combination(2)` source guard,
  parallel-edges conservative invalid, 100-rectangle
  performance smoke, 200-node chain walk performance smoke).

### SR18-05 — cache invalidation
- `core/working_mode_runner.rb` — added a single
  `_invalidate_v18_cache` seam that clears
  `@structure_reconstruction_result`. Called from:
  - `_invalidate_to_failed_with_reason`
  - `apply_gap_repair` `:applied` AND `:failed` branches
    (the previous implementation cleared cache only in
    the `:failed` branch — the `:applied` branch is now
    also wired so a successful apply invalidates the
    pre-apply cached structure)
  - `apply_planar_normalization` `:failed` AND success
    branches
  - `run_duplicate_repair_batch` success AND `rescue`
    branches
- The `reset_for_tests`, `prepare`, `rebuild`, and
  `discard` paths already cleared the cache (no
  regression).
- Tests: `V18-SR05` (seam direct call, gap-apply failure,
  discard/rebuild cycle, `_invalidate_to_failed_with_reason`
  invalidation, planar-apply cache clear, duplicate-repair
  cache clear).

### SR18-06 — truthful state
- `core/canonical_structure_reconstructor.rb` — the result
  state computation now matches the dispatch's contract:
  - invalid graph → `STATE_FAILED` (rejected in
    `_validate_graph`; `_empty_result` already returned
    `STATE_FAILED`)
  - any unresolved / upstream warning →
    `STATE_READY_WITH_WARNINGS`
  - warning-free + content → `STATE_READY`
  - branch-only (no chains/loops but a
    `branching_component` reason or
    `parallel_edges_unsupported:*` was reported) →
    `STATE_READY_WITH_WARNINGS` (NOT `STATE_READY`)
  - invalid adjacency → `STATE_FAILED`
- Tests: `V18-SR06` (branch-only, upstream-warning-only,
  clean rectangle, invalid graph, invalid adjacency).

### SR18-07 — deep immutability
- `core/canonical_structure_reconstructor.rb` — added
  `deep_freeze(obj)` that recursively freezes nested
  Hashes and Arrays in place. Applied to BOTH the normal
  result publication and the `_empty_result` (failed)
  result. Caller cannot mutate `result['chains'][0]['node_ids']`
  or `result['loops'][0]['world_coordinates'][0][0]`
  in place; any such mutation raises `FrozenError` and
  the digest remains stable.
- Tests: `V18-SR07` (outer + nested freeze, mutation
  attempts raise, empty / failed result also deep-frozen,
  digest stable across failed mutations).

### SR18-08 — adjacency validation
- `core/canonical_structure_reconstructor.rb` — added
  `REASON_ADJACENCY_MISMATCH = 'invalid_graph:adjacency_mismatch'`
  and `_validate_adjacency_against_edges(adj_h, node_set,
  edge_h)`. Runs after the basic graph validation. The
  helper computes the expected adjacency from the edge
  inventory and reports:
  - `unknown_key:<kid>` — adjacency key not in the node set
  - `unknown_neighbor:<kid>-><n>` — neighbor not in the node set
  - `extra_neighbor:<kid>-><n>` — adjacency lists a neighbor
    not backed by an edge
  - `missing_neighbor:<kid>-><n>` — edge-backed neighbor is
    not listed in adjacency
- Any mismatch yields `STATE_FAILED` and the stable
  `invalid_graph:adjacency_mismatch:...` reason family.
- V1.7 CanonicalGeometryGraph schema is NOT modified.
- Tests: `V18-SR08` (unknown key, unknown neighbor, missing
  edge-backed neighbor, extra non-edge neighbor, consistent
  adjacency negative test).

---

## 3. Do-not-change guard (per dispatch)

- ✅ No V1.7 schema / identity / digest changes.
- ✅ No SegmentConflict semantic changes (used as-is).
- ✅ No source / provenance authority changes.
- ✅ No workspace ownership changes.
- ✅ No host mutation / Face / Observer.
- ✅ No site semantics.
- ✅ No V1.9 work.
- ✅ No Codex self-invocation.
- ✅ Frozen V1.8 Blueprint preserved unchanged.

`CODEX_RISK_TRIGGER = NO` (dispatch §3 invariant).

---

## 4. Test evidence

### 4a. Full Ruby suite

- **1029 / 1029 PASS** / 0 fail / 0 error.
- Composition (1029 tests):
  - V1.0–V1.6 regressions
  - 127 V1.7 tests
  - 9 V1.5 BLOCK-005
  - 7 V1.6 close-autodiscard
  - 4 LEGACY-COMPAT
  - 9 RBZ smoke
  - 15 V1.8 focused core (V18-T01..T15)
  - 5 V1.8 runner integration (V18-I01..I05)
  - 32 new V1.8 SR18 focused tests (V18-SR01..SR08):
    - V18-SR01: 2 tests (Ruby 2.2 source guard)
    - V18-SR02: 3 tests (coordinate_epsilon authority)
    - V18-SR03: 4 tests (loop conflict detection)
    - V18-SR04: 4 tests (O(V+E) traversal + parallel edges)
    - V18-SR05: 6 tests (cache invalidation)
    - V18-SR06: 5 tests (truthful state)
    - V18-SR07: 3 tests (deep immutability)
    - V18-SR08: 5 tests (adjacency validation)
- Delta vs V1.8 base: +32 tests (the new SR18 focused set).
- Delta vs V1.7 closure 997: +32 tests (the new SR18 focused set).

### 4b. Focused V1.8 / SR18 timings

- V1.8 focused test set (52 tests including all SR18
  corrections): **< 1 second** end-to-end.
- Largest individual V1.8 performance smoke
  (V18-SR04 200-node chain walk): sub-second.
- The 13-minute hang the previous session observed is
  NOT reproduced. The largest pre-fix test was the
  performance smoke at 100 rectangles + 1 long chain
  (V18-T15, 10s budget). The new V18-SR04 tests
  (100 rectangles + 200-node chain) complete in
  well under 5s each on the indexed traversal.

### 4c. `git diff --check`

Clean (0 warnings). The `core/canonical_structure_reconstructor.rb`
file was normalized from CRLF to LF to make the Windows
`git diff --check` whitespace check consistent and clean
without changing the file semantics. All other modified
files were already LF.

---

## 5. V1.8 RBZ

- **Path**: `dist/SU-AI-Plugin.rbz` (overwritten by this dispatch)
- **Size**: **1,071,551 bytes**
- **Entries**: **69**
- **SHA-256**: `7FBE090F6C491617CA5626FCAA60A5FB30555B66A8E8051D6C85C08F64670523`
- **Packaged `html/app.js` SHA-256**:
  `56878DD018A0DB6A1684CABE91EE84EB1426B295C7B1CF60F6A08F5D98353F2D`
- **Packaged `html/index.html` SHA-256**:
  `6405DD9EB10A4C4CFCC73CD15AA8B54BC4DAF1D5F631780D7DB6308EAAD6489D`
- **Packaged `html/style.css` SHA-256**:
  `3FAAB5E5C6C9757DDE90D2F984B02F2F357727553232BC7FC70814C7709BB95B`
- All packaged dialog assets are byte-identical to the
  in-tree source (per the existing smoke-test contract).

---

## 6. Commit + push plan

- Single production commit on `dev/v1.8` with all SR18
  corrections + new tests + updated RBZ.
- One normal fast-forward push to `origin/dev/v1.8`.
- No force-push, no rebase, no rewrite of shared history,
  no `main` push/merge, no tag/release.

---

## 7. Gate

- **AIPM_REVIEW: PENDING NARROW RECHECK** (this packet is
  the bounded correction round; AIPM must recheck
  SR18-01..SR18-08 specifically).
- **CODEX_RISK_TRIGGER: NO** (frozen boundary untouched).
- **OWNER_SU2020: NOT YET** (pending AIPM narrow recheck
  PASS).
- **V1.9: NOT STARTED**.

After green: one normal fast-forward push of the
assigned `dev/v1.8` as the complete-task submission. STOP
and return control to AIPM for narrow recheck.
