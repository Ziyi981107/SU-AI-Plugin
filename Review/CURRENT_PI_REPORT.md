# CURRENT PI REPORT — V18-FINAL-FOUR-RESIDUALS

Project: `SU-AI-Plugin`
Version: V1.8
Stage: V1.8 base — Polyline / Closed Loop / Region Reconstruction
Dispatch: `V18-FINAL-FOUR-RESIDUALS-2026-09-03`
Authority: `Review/CURRENT_AIPM_REVIEW.md` (AIPM narrow recheck of
the V18-AIPM-SOURCE-REVIEW-CORRECTION packet)
Baseline HEAD: `ab3e0c8a573052598ebba6fa0b483341408a660f` (dev/v1.8
V18-AIPM-SOURCE-REVIEW-CORRECTION complete state)
Target branch: `dev/v1.8` (per dispatch §0)
Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

---

## 0. Scope (per dispatch §0)

ONE bounded residual-fix packet for V1.8 base. Fix EXACTLY
`FR18-01..FR18-04` from the AIPM narrow recheck (the four
final residuals of `SR18-02`, `SR18-04`, `SR18-07`, `SR18-08`).
No broad V1.8 refactor. No V1.7 schema/identity/digest
changes. No SegmentConflict semantic changes. No
source/provenance authority changes. No tolerance authority
upstream. No workspace ownership changes. No host mutation /
Face / Observer. No UI product scope. No V1.9. No Codex
self-invocation.

If a fix appears to require any frozen-boundary change:
STOP and report.

---

## 1. Status

- **V1.7: CLOSED** (per
  `Prompt/AIPM_V1_7_OWNER_ACCEPTED_CLOSURE_2026-09-02.md`).
- **V1.8: ACTIVE**.
- **Frozen V1.8 Blueprint**: ACTIVE (unchanged).
- **V1.8 AIPM narrow recheck (this dispatch)**: BLOCK →
  all FR18-01..FR18-04 fixed; Pi Complete; awaiting AIPM
  narrow recheck.
- **V1.8 Codex gate**: NOT REQUIRED
  (`CODEX_RISK_TRIGGER = NO`).
- **V1.8 Owner SU2020 gate (Scenarios A–D)**: pending
  AFTER AIPM narrow recheck PASS.
- **V1.9 / PreparedCadDataset**: NOT STARTED.
- **V2 / MCP**: OUT OF SCOPE.

Frozen V1.8 Blueprint preserved unchanged on the assigned
`dev/v1.8`. Pi did NOT rewrite any frozen design authority.

---

## 2. Corrections by this dispatch (each regression-locked)

### FR18-01 — exact `coordinate_epsilon` authority (SR18-02 residual)

- `core/canonical_structure_reconstructor.rb` — rewrote
  `_resolve_coordinate_eps(graph, kw)` with the strict
  authority contract:
  1. ANY explicit finite positive `coordinate_epsilon:`
     keyword wins VERBATIM, including exactly `1.0e-6`.
     The previous `kw != 1.0e-6` short-circuit (which
     silently rejected the explicit default) is removed.
  2. With no explicit kw, per-node `coordinate_epsilon`
     is usable ONLY when ALL canonical nodes carry a
     finite / positive / CONSISTENT value. The previous
     silent median / min / max / first selection is
     REMOVED.
  3. Inconsistent per-node eps with no explicit kw → the
     function returns a stable failure reason
     `invalid_graph:coordinate_epsilon_mismatch`. The
     `reconstruct(...)` entry point routes this to
     `_empty_result` with `STATE_FAILED` and the stable
     reason.
  4. Defensive `1.0e-6` fallback ONLY when neither kw
     nor per-node eps is available (preserves the
     legacy contract for that case).
- `reconstruct(...)` now calls
  `coord_eps, eps_failure = _resolve_coordinate_eps(...)`
  and bails to `_empty_result` when `coord_eps.nil?`.
- Tests: `V18-FR01` (4 cases):
  - `V18-FR01-A`: explicit `1e-6` wins verbatim over
    conflicting per-node eps.
  - `V18-FR01-B`: conflicting per-node eps without kw
    → `STATE_FAILED` with
    `invalid_graph:coordinate_epsilon_mismatch`.
  - `V18-FR01-C`: consistent per-node eps without kw →
    uses that exact value.
  - `V18-FR01-D`: no per-node eps + no kw → defensive
    `1e-6` fallback.

### FR18-02 — true indexed O(V+E) membership (SR18-04 residual)

- `core/canonical_structure_reconstructor.rb`:
  - **Removed** the process-global `comp_set(arr)` helper
    and its instance-variable cache
    (`@_comp_set_cache`, keyed by `arr.object_id`). Object
    IDs can be reused after GC and the cache could grow
    across reconstructions.
  - **Removed** every `comp.include?(other)` Array scan
    from the production traversal hot path.
  - `_classify_component` now builds ONE local
    `comp_set = Set.new(comp)` and threads it through
    every per-step `include?` check (degree, parallel-
    pair prune, chain walk, loop walk).
  - `_build_chain`, `_build_loop`, and `_walk_cycle` now
    take `comp_set` as an explicit parameter (no more
    `comp.include?` in any per-step check).
  - `_parallel_pairs_in_comp` and
    `_edges_in_component_via_index` now accept the local
    Set directly (no defensive `Set.new` re-allocation
    per call).
  - The rebuilt adjacency uses Set/hash accumulation
    (`adj_set[k].add(b)`) instead of
    `adjacency[k] << b unless adjacency[k].include?(b)`
    insertion scans; the published adjacency is the
    sorted-Array projection of the Set, so the payload is
    deterministic and downstream traversal uses Set-based
    O(1) lookups instead of repeated `Array#include?`.
- No identity / order behavior change. V18-T11's
  forward / reverse / shuffled input equivalence and
  V18-SR04's 100-rectangle / 200-chain smokes continue
  to pass.
- Tests: `V18-FR02` (5 cases):
  - `V18-FR02-A`: source guard — production traversal
    has NO `comp.include?` in the hot path.
  - `V18-FR02-B`: source guard — production source has
    NO `@_comp_set_cache` / object_id membership cache.
  - `V18-FR02-C`: source guard — production adjacency
    rebuild accumulates via Set (no
    `adjacency[key].include?` insert scan).
  - `V18-FR02-D`: 500-node chain walk finishes
    comfortably bounded.
  - `V18-FR02-E`: 300-node cycle walk finishes
    comfortably bounded.

### FR18-03 — true deep freeze (SR18-07 residual)

- `core/canonical_structure_reconstructor.rb` — rewrote
  `deep_freeze(obj)` so it now:
  - Recursively freezes Hash KEYS as well as values
    (the previous implementation only froze values).
  - Recursively freezes Array members.
  - **Freezes String scalar values explicitly** (Ruby
    Strings are mutable by default; without this branch
    a caller could still mutate `result['digest']`,
    `result['loops'][0]['loop_id']`, or
    `result['loops'][0]['source_occurrence_ids'][0]`
    in place after the digest was published).
  - JSON primitive numerics / `true` / `false` / `nil`
    are immutable by definition and pass through
    unchanged (the case branch returns them).
- `deep_freeze` is invoked on BOTH the normal result
  publication and the `_empty_result` (failed) result,
  so the published payload remains frozen even after a
  failed reconstruction.
- Tests: `V18-FR03` (3 cases):
  - `V18-FR03-A`: `result['digest']`, `loop['loop_id']`,
    `loop['source_occurrence_ids'][i]`, `region['region_id']`,
    and every reason string are frozen.
  - `V18-FR03-B`: in-place `<<` mutations on
    `result['digest']`, `loop['loop_id']`, and
    `loop['source_occurrence_ids'][0]` all raise
    `FrozenError` (or `RuntimeError`), AND the digest /
    loop_id / source_occurrence_id values remain
    unchanged.
  - `V18-FR03-C`: every top-level result key AND every
    loop key are frozen Strings (deep-freeze of Hash
    keys).

### FR18-04 — complete adjacency validation (SR18-08 residual)

- `core/canonical_structure_reconstructor.rb` — rewrote
  `_validate_adjacency_against_edges(adj_h, node_set,
  edge_h)` so it now:
  - Normalizes expected adjacency for EVERY canonical
    node id (missing expected-key for an isolated node =
    empty list).
  - Normalizes supplied adjacency for EVERY canonical
    node id (missing supplied-key = empty list).
  - Compares expected vs supplied for every known node
    (NOT only for supplied keys). An omitted edge-backed
    adjacency key now reports `missing_neighbor`.
  - Rejects non-Array adjacency values explicitly with
    `non_array_value:<kid>` (no silent scalar coercion).
  - Unknown key / unknown neighbor / extra non-edge
    neighbor / missing edge-backed neighbor remain
    failures.
  - Isolated known node with explicit empty adjacency
    remains valid (no `missing_neighbor` reported for an
    isolated canonical node).
- New stable reason tokens:
  - `invalid_graph:adjacency_mismatch:non_array_value:<kid>`
- Tests: `V18-FR04` (4 cases):
  - `V18-FR04-A`: omitted entire edge-backed adjacency
    key → `STATE_FAILED` with `missing_neighbor:cn-2->...`.
  - `V18-FR04-B`: scalar / non-Array adjacency value →
    `STATE_FAILED` with `non_array_value:cn-2`.
  - `V18-FR04-C`: isolated known node with explicit
    empty adjacency remains valid (clean negative case).
  - `V18-FR04-D`: omitted isolated node key remains valid
    (missing supplied-key for an isolated node is
    normalized to an empty list).

---

## 3. Do-not-change guard (per dispatch)

- ✅ No V1.7 schema / identity / digest changes.
- ✅ No SegmentConflict semantic changes (used as-is).
- ✅ No source / provenance authority changes.
- ✅ No workspace ownership changes.
- ✅ No host mutation / Face / Observer.
- ✅ No site semantics.
- ✅ No UI product scope.
- ✅ No V1.9 work.
- ✅ No Codex self-invocation.
- ✅ Frozen V1.8 Blueprint preserved unchanged.

`CODEX_RISK_TRIGGER = NO` (dispatch §Gate invariant).

The already-PASS areas (`SR18-01`, `SR18-03`, `SR18-05`,
`SR18-06`) were NOT reworked beyond mechanical test
compatibility — per dispatch §Already-PASS.

---

## 4. Test evidence

### 4a. Full Ruby suite

- **1045 / 1045 PASS** / 0 fail / 0 error.
- Composition (1045 tests):
  - V1.0–V1.6 regressions
  - 127 V1.7 tests
  - 9 V1.5 BLOCK-005
  - 7 V1.6 close-autodiscard
  - 4 LEGACY-COMPAT
  - 9 RBZ smoke
  - 15 V1.8 focused core tests (V18-T01..T15)
  - 5 V1.8 runner integration tests (V18-I01..I05)
  - 32 V1.8 SR18 focused tests (V18-SR01..SR08, all
    preserved unchanged from the previous dispatch)
  - 16 new V1.8 FR18 focused tests (V18-FR01..FR04):
    - V18-FR01: 4 tests (epsilon authority residuals)
    - V18-FR02: 5 tests (true indexed O(V+E) membership)
    - V18-FR03: 3 tests (true deep freeze of Hash keys
      + Arrays + Strings)
    - V18-FR04: 4 tests (complete adjacency validation)
- Delta vs prior V18-AIPM-SOURCE-REVIEW-CORRECTION
  1029: **+16 tests** (the new FR18 focused set).
- All previously-PASS tests remain PASS unchanged.

### 4b. Focused FR18 timings

- 16 V18-FR tests: **0.054 s** end-to-end.
- Largest individual FR performance smoke
  (V18-FR02-D 500-node chain walk, V18-FR02-E 300-node
  cycle walk): sub-second. The new local-Set indexed
  traversal comfortably handles both scales inside the
  5 s budget.

### 4c. Node DOM (`tests/test_html_render_dom.js`)

Unchanged from V1.8 base — all 327 assertions PASS,
final line `PASS`. No JS-side change in this dispatch.

### 4d. `git diff --check`

Clean (0 warnings).

---

## 5. V1.8 RBZ

- **Path**: `dist/SU-AI-Plugin.rbz` (overwritten by this dispatch)
- **Size**: **1,076,511 bytes**
- **Entries**: **69**
- **SHA-256**: `e4348abd68618b337161415c20fe0b81352de800e1b91ee8fb1492954986ffdb`
- **Packaged `html/app.js` SHA-256**:
  `56878DD018A0DB6A1684CABE91EE84EB1426B295C7B1CF60F6A08F5D98353F2D`
- **Packaged `html/index.html` SHA-256**:
  `6405DD9EB10A4C4CFCC73CD15AA8B54BC4DAF1D5F631780D7DB6308EAAD6489D`
- **Packaged `html/style.css` SHA-256**:
  `3FAAB5E5C6C9757DDE90D2F984B02F2F357727553232BC7FC70814C7709BB95B`
- All packaged dialog assets are byte-identical to the
  in-tree source (per the existing smoke-test contract).
- The packaged `canonical_structure_reconstructor.rb`
  contains all FR18-01..FR18-04 corrections
  (`coordinate_epsilon_mismatch` constant, `non_array_value`
  reason, `when String` deep-freeze branch, `comp_set` local
  Set threading).

---

## 6. Commit + push plan

- Single production commit on `dev/v1.8` containing:
  - `core/canonical_structure_reconstructor.rb`
    (FR18-01..FR18-04 corrections)
  - `tests/test_v18_structure_reconstruction.rb`
    (16 new V18-FR01..FR04 tests)
  - Updated RBZ at `dist/SU-AI-Plugin.rbz`.
  - This report (`Review/CURRENT_PI_REPORT.md`).
  - `CURRENT_STATE.md` doc-stamp.
- One normal fast-forward push to `origin/dev/v1.8`.
- No force-push, no rebase, no rewrite of shared history,
  no `main` push/merge, no tag/release.

---

## 7. Gate

- **AIPM_REVIEW: PENDING FINAL FOUR RECHECK** (this packet
  is the narrow final-residual-fix round; AIPM must
  recheck FR18-01..FR18-04 specifically).
- **CODEX_RISK_TRIGGER: NO** (frozen boundary untouched).
- **OWNER_SU2020: NOT YET** (pending AIPM narrow recheck
  PASS).
- **V1.9: NOT STARTED**.

After green: one normal fast-forward push of the
assigned `dev/v1.8` as the complete-task submission. STOP
and return control to AIPM for final recheck.
