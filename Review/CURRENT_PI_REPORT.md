# CURRENT PI REPORT — V17-CODEX-BLOCK-FINAL-RESIDUAL-FIX

Project: `SU-AI-Plugin`
Version: V1.7
Stage: V1.7 FINAL INT-001 / INT-002 residual fix COMPLETE /
AWAITING AIPM NARROW TWO-DELTA SOURCE REVIEW (NOT yet
V1.7 CLOSED; mandatory Codex xHigh NARROW recheck of
these two findings only + final Owner SU2020 real-host
verification gate Scenarios A–G remain.)
Dispatch: `V17-CODEX-BLOCK-FINAL-RESIDUAL-FIX-2026-09-02`
Prior Dispatch: `V17-CODEX-XHIGH-BLOCK-FIX-2026-09-02`
Dispatcher / Technical Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
Codex xHigh BLOCK adjudication (the prior correction
this dispatch tightens):
`Review/CURRENT_AIPM_REVIEW.md` (REVIEW_ID
`V17-CODEX-BLOCK-NARROW-DELTA-REVIEW-2026-09-02`)
Frozen V1.6 Closure Anchor:
`Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md`
Branch: `dev/v1.7`
Source of Truth: `extension/su_ai_plugin/` + canonical contracts in
`PROJECT_HANDOFF` + `PROJECT_MASTER_PLAN_V1X`.

---

## 0. Scope (per dispatch §0)

Correct EXACTLY TWO residuals inside the already-accepted
Codex findings:
- **INT-001** — final output-order / digest determinism.
- **INT-002** — shared-endpoint collinear-overlap safety.

INT-003, INT-004 and INT-005 code fixes are AIPM narrow
PASS. Do not modify them except unavoidable mechanical
test compatibility.

This is the FINAL Pi correction before Codex narrow
recheck.

DO NOT:
- invoke Codex yourself;
- run Owner SU2020 gate;
- start V1.8;
- redesign canonical identity;
- add repair types;
- add Observer architecture;
- mutate Source CAD.

The frozen V1.7 Stage Technical Blueprint and the frozen
V1.6 closure anchor are PRESERVED UNCHANGED.

---

## A. INT-001 residual disposition

`### A.1 — DETERMINISTIC NON-TRANSITIVE IDENTITY (residual fix)`

The prior `V17-CODEX-XHIGH-BLOCK-FIX-2026-09-02` packet
already dropped the discovery-ordinal `comp_idx` from the
non-transitive `cluster_id` and derived the per-member
`canonical_node_id` position from `sorted_indices`. That
correction is preserved unchanged.

The Codex narrow delta review identified three residual
order/digest determinism concerns inside this fix:

- **A.1.a — component iteration key.** The prior fix
  used `comp.first` (DFS-discovery first member), which
  is NOT necessarily the lex-smallest endpoint_key in
  the component. Two interleaved components could swap
  output order across rebuilds.

  **Residual fix applied:** component iteration key now
  derives from ALL sorted endpoint_keys of the
  component:
  ```ruby
  components_sorted = components.each_with_index.sort_by do |comp, _idx|
    if comp.empty?
      ''
    else
      comp.map { |i| epss[i].endpoint_key.to_s }.sort.join('|')
    end
  end
  ```
  This is independent of DFS discovery order AND of input
  enumeration order. Forward / reversed / shuffled
  enumerations of the same membership yield identical
  sorted component keys and therefore identical component
  iteration order.

- **A.1.b — published payload ordering.** Even with the
  A.1.a fix, a single component class could still emit
  per-member canonical_node records in an order that
  depends on which endpoint the iteration chose to
  publish first, and Hash insertion order for
  `canonical_node_clusters` is host / insertion dependent.

  **Residual fix applied:** the published payload is
  defensively re-sorted by stable keys BEFORE freezing:
  - `canonical_nodes` sorted by
    `(canonical_node_id, endpoint_key)`.
  - `non_transitive_clusters` sorted by `cluster_id`.
  - `canonical_node_clusters` rebuilt in
    `cluster_id`-sorted insertion order so external
    consumers that serialize the Hash get a stable
    representation.

- **A.1.c — graph digest lines.** The
  `CanonicalGeometryGraph._compute_digest` method
  previously serialized the `non_transitive_clusters`
  in iteration order, with `Array(...).join('|')` for
  endpoint_keys (NOT sorted). Different rebuilds would
  produce different digest lines.

  **Residual fix applied:** `_compute_digest` now
  sorts `non_transitive_clusters` by `cluster_id` and
  sorts the endpoint_keys within each serialization
  line before joining.

**Do-not-change invariants preserved:**
- safe-clique collapse (Blueprint §7.2) unchanged.
- non-transitive members remain separate (Blueprint
  §7.2) unchanged.
- coordinate_epsilon semantics unchanged.

---

## B. INT-002 residual disposition

`### B.1 — SHARED-ENDPOINT DOES NOT OVERRIDE INTERIOR OVERLAP (residual fix)`

The prior `V17-CODEX-XHIGH-BLOCK-FIX-2026-09-02` packet
created the shared pure `core/segment_conflict.rb`
predicate and made the runner's
`_crossing_checker_proc` and the proposer's X3 pairwise
check delegate to it. The first version of that predicate
returned `{ conflict: false, reason: 'shared_endpoint' }`
**before** checking whether the two collinear segments
actually overlap through their interiors. That wrongly
classified `[5,0]->[8,0]` vs `[5,0]->[10,0]` as SAFE —
they share endpoint `(5,0,0)` AND overlap on the collinear
interval `[5, 8]`.

**Residual fix applied:** the shared
`SegmentConflict.conflict?` predicate's decision order is
now strictly:

1. validate inputs + bounding-box reject.
2. **COLLINEAR classification + collinear overlap FIRST**:
   - genuine collinear interior overlap (full or partial)
     → CONFLICT (reason: `'collinear_overlap'`) **even if
     endpoint(s) are shared**;
   - collinear endpoint-only touch (one segment terminates
     at an endpoint of the other with zero interior
     overlap) → SAFE (reason: `'shared_endpoint'`);
   - disjoint collinear → SAFE.
3. Non-collinear geometry with a single shared endpoint
   only → SAFE (reason: `'shared_endpoint'`).
4. Proper strict interior crossing → CONFLICT
   (reason: `'proper_interior_crossing'`).
5. Bridge endpoint strictly inside unrelated edge
   interior → CONFLICT
   (reason: `'bridge_endpoint_on_unrelated'`).
6. Unrelated endpoint strictly inside bridge interior →
   CONFLICT (reason: `'unrelated_endpoint_on_bridge'`).

The dispatcher pre-conditions (Z-compat upstream of
`GapPairProposer` and the runner's crossing checker) are
preserved. Disjoint collinear segments remain SAFE.
Almost-closed triangles remain `READY_TO_REPAIR`. One
shared pure predicate is used by the runner + the proposer.

**Stable reason codes emitted:**
- `'collinear_overlap'`
- `'proper_interior_crossing'`
- `'bridge_endpoint_on_unrelated'`
- `'unrelated_endpoint_on_bridge'`
- `'shared_endpoint'` (SAFE marker for caller clarity)
- `nil` (safe / no reason)

---

## C. Tests added by this dispatch (dispatch §3)

`### C.1 — V17-INT-001-E`

Combined regression. Forward / reversed / deliberately
shuffled input enumerations on the **interleaved
membership topology** (two non-transitive components with
endpoint-key ranges that interleave so the pre-residual
`comp.first` approach was capable of changing component
order) produce:

- exact-equal `CanonicalTopologyBuilder` arrays
  (`canonical_nodes`, `non_transitive_clusters`) — not
  only sorted-set equal;
- exact-equal `canonical_node_clusters` Hash payload;
- equal `CanonicalGeometryGraph` digest.

`### C.2 — V17-INT-002-M1 / M2 / M3`

Production-helper coverage for the dispatch's required
"shared-overlap case through the product proposal path":

- **V17-INT-002-M1**: bridge `(5,0,0)->(8,0,0)` vs
  unrelated `(5,0,0)->(10,0,0)` — shared endpoint
  `(5,0,0)` + collinear interior overlap `[5, 8]` driven
  through `GapPairProposer._segments_intersect_interior?`
  (the production X3 / bridge-conflict helper) →
  CONFLICT.
- **V17-INT-002-M2**: identical segments
  `(0,0,0)->(10,0,0)` vs `(0,0,0)->(10,0,0)` (both
  endpoints shared) → CONFLICT.
- **V17-INT-002-M3**: bridge `(5,0,0)->(12,0,0)` vs
  unrelated `(5,0,0)->(10,0,0)` (shared endpoint + partial
  overlap + bridge contains an unrelated endpoint strictly
  inside its interior) → CONFLICT.

The prior correction's existing
`V17-INT-002-F/F2/F3/G/H/I/J/K/L` regression coverage is
preserved and unmodified.

---

## D. Existing tests preserved (no regression introduced)

- `V17-INT-002-F` was **corrected** (not removed) to
  expect `CONFLICT` (`collinear_overlap`) on the
  `[5,0]->[8,0]` vs `[5,0]->[10,0]` shared-endpoint +
  collinear interior overlap case. Previously this test
  wrongly expected SAFE; the corrected expectation is the
  residual fix.
- `V17-INT-002-F2` and `V17-INT-002-F3` were **added**
  as separate SAFE cases:
  - `F2` — non-collinear shared endpoint → SAFE
    (`shared_endpoint`).
  - `F3` — collinear endpoint-only touch → SAFE
    (`shared_endpoint`).
- `V17-INT-002-G` `[PRODUCTION PATH]` collinear
  containment rejects a bridge inside an unrelated
  collinear edge: **PASS** (unchanged).
- `V17-INT-002-H` `[PRODUCTION PATH]` almost-closed
  triangle remains `READY_TO_REPAIR`: **PASS** (unchanged).
- `V17-INT-002-I` `[PRODUCTION PATH]`
  proposal-vs-proposal collinear overlap →
  `bridge_conflict`: **PASS** (unchanged; the helper
  returns true for both `'proper_interior_crossing'` and
  `'collinear_overlap'`).

INT-003 / INT-004 / INT-005 test coverage is unchanged:
- INT-003 plural provenance: `V17-INT-003-A`,
  `V17-INT-003-A-PROD`, `V17-INT-003-B`,
  `V17-INT-003-C`, `V17-INT-003-D`.
- INT-004 validate-on-next-V1.7-interaction:
  `V17-INT-004-A`, `V17-INT-004-B`, `V17-INT-004-C`.
- INT-005 Ruby 2.2 / SU2017 compatibility:
  `V17-INT-005-A`, `V17-INT-005-B`, `V17-INT-005-C`.

---

## E. Full regression counts

This dispatch:

| Suite | PASS | FAIL | ERROR |
|-------|------|------|-------|
| `V17-INT` (all 33 INT-block-fix regressions) | 33 | 0 | 0 |
| `V17` (V1.7 topology + executor + canonical graph) | 127 | 0 | 0 |
| `BLOCK-005` (V1.5 host-state seam) | 9 | 0 | 0 |
| `V16-CLOSE-AUTODISCARD` | 7 | 0 | 0 |
| `LEGACY-COMPAT` | 4 | 0 | 0 |
| `H*` host-mutation (V17-H1..H7 + RR-04 pre-batch + RR-02 host-endpoint proof) | 122 | 0 | 0 |
| `RBZ` smoke + install smoke + V15PC-002 | 9 | 0 | 0 |
| **Full Ruby suite** | **977** | **0** | **0** |

- New tests added by this dispatch: **4**
  (`V17-INT-001-E`, `V17-INT-002-M1`, `V17-INT-002-M2`,
  `V17-INT-002-M3`). Plus the corrected `V17-INT-002-F`
  + the new `V17-INT-002-F2` / `V17-INT-002-F3` /
  `V17-INT-002-J` / `V17-INT-002-K` / `V17-INT-002-L`
  that the AIPM narrow delta review directed be present
  in the prior correction but were already on disk for the
  prior dispatch's commit and are preserved unchanged in
  this dispatch.

- Node DOM (`tests/test_html_render_dom.js`): all
  assertions PASS, final line `PASS`.

- `git diff --check`: clean.

---

## F. RBZ identity

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
  (overwritten by this dispatch's rebuild)
- Size: **984,319 bytes**
- Entries: **68**
- SHA-256:
  **`9A320BD0c64bf5117a57813263d23043b8c2b0057c5c87121ff81585d13c38c7`**

Packaged dialog assets (this dispatch did NOT modify
HTML/JS/CSS — the in-tree sources are byte-identical to
the packaged copies):

- `su_ai_plugin/html/app.js` SHA-256:
  `3a6ebe6075689e91526c3c880442a2cd5e975cc09d639603cdb0f094a765b591`
- `su_ai_plugin/html/index.html` SHA-256:
  `6405dd9eb10a4c4cfcc73cd15aa8b54bc4daf1d5f631780d7db6308eaad6489d`
- `su_ai_plugin/html/style.css` SHA-256:
  `3faab5e5c6c9757dde90d2f984b02f2f357727553232bc7fc70814c7709bb95b`

---

## G. Final implementation commit + remote HEAD

- Starting HEAD (this dispatch): `40277b0` (the prior
  `V17-CODEX-XHIGH-BLOCK-FIX` doc-stamp; production
  substantive commit was `9a81585`).
- Implementation commit produced by this dispatch: see
  `git log -1` after commit (one production commit +
  one doc-stamp).
- Final HEAD on `dev/v1.7`: see `git rev-parse HEAD`
  after push.
- Remote `dev/v1.7` HEAD: see
  `git rev-parse origin/dev/v1.7` after push.

The three production files modified by this dispatch are
listed under §A (INT-001) and §B (INT-002) above. The
test additions are listed under §C.

`SU2017_RUNTIME_EVIDENCE_PENDING` is UNCHANGED — this
machine runs Ruby 2.7.8; no Ruby 2.2.4 / SketchUp 2017-
compatible runtime is available. The narrow Codex
recheck decides whether the static / API-removal evidence
recorded by `V17-INT-005-A` / `V17-INT-005-B` is
sufficient or whether a separate Owner / host
compatibility probe remains required before release.

---

## H. Dispatch gate lines

- `AIPM_REVIEW: PENDING FINAL TWO-DELTA CHECK`
- `CODEX_NARROW_RECHECK: REQUIRED — DO NOT SELF-INVOKE`
- `OWNER_GATE: NOT YET RUN`
- `V1.8: NOT STARTED`

Pi did NOT invoke Codex. Pi did NOT start V1.8. Pi did NOT
run the Owner gate. Pi did NOT redesign canonical identity.

---

## I. Push outcome (post-dispatch)

After all required tests were green and the final stable
local `dev/v1.7` checkpoint existed, one normal
fast-forward push of the assigned branch was performed:

- Remote `dev/v1.7` HEAD after push: see
  `git rev-parse origin/dev/v1.7` (matches local
  `git rev-parse HEAD` byte-for-byte).
- No force-push, no rebase, no rewrite of shared history,
  no `main` push/merge, no tag/release.

Pi STOPPED awaiting AIPM narrow source review of the
INT-001 + INT-002 delta only.

Next expected AIPM action: AIPM narrow source review of
the INT-001 + INT-002 delta only. On AIPM PASS: mandatory
Codex xHigh NARROW recheck of these two findings only. On
Codex PASS: final Owner SU2020 real-host verification
gate Scenarios A–G.