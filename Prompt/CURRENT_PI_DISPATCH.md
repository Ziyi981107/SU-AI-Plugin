# CURRENT PI DISPATCH — HOLD / CODEX REVIEW PENDING

Project: SU-AI-Plugin
Stage: V1.9A — Final Block Fix Source Review
Date: 2026-09-08
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
TARGET_BRANCH: `dev/v1.9`
AIPM_REVIEW: FIX REQUIRED
PI_IMPLEMENTATION: HOLD
CODEX_REVIEW: REQUIRED — NARROW P0 BOUNDARY
V1.9B: NOT AUTHORIZED / NOT STARTED

Current reviewed HEAD before AIPM review-doc commits:

`23a6dc51288e22e536760b045479632bc2561d4c`

Codex review packet:

`Prompt/CODEX_V1_9A_P0_CURRENT_GEOMETRY_SHARED_VERTEX_REVIEW_2026-09-08.md`

Prior implementation guidance remains historical authority for intended outcomes:

`Prompt/AIPM_V1_9A_FINAL_BLOCK_FIX_2026-09-07.md`

---

## 0. STATUS

STOP implementation.

Pi MUST NOT continue changing production code until AIPM receives the narrow Codex review and issues a new ACTIVE implementation dispatch.

Reason: AIPM direct source review found that the submitted P0 live-coordinate fix does not follow the actual GROUP -> endpoint VERTEX host-handle contract, and source inspection exposed a second-order V1.6 shared-logical-vertex / multiple-physical-vertex mutation risk.

This is a high-risk deterministic geometry / host-ownership boundary. Per project governance it requires narrow Codex review before further Pi implementation.

---

## 1. AIPM SOURCE REVIEW — CONFIRMED BLOCKS

### BLOCK P0-A — wrong handle passed to `vertex_position`

Current `DerivedTopologySnapshotBuilder.build` uses:

```ruby
host_handle = workspace.handle_for(edid)
```

for both start/end live-coordinate reads.

That handle is the derived GROUP / edge-level wrapper. `adapter.vertex_position` expects an endpoint Vertex handle.

The actual endpoint handles are already resolved through:

```text
adapter.edge_endpoints(group_handle)
-> endpoint_key => host_vertex_handle map
-> build(... vertex_keys_by_edge: host_vertex_map)
```

The correction must use the endpoint-key Vertex handle for each endpoint. Keep the group handle only for group/edge-level adapter operations such as curve/face safety and host provenance.

### BLOCK P0-B — nil live read incorrectly falls back

If a live endpoint handle exists and adapter exposes `vertex_position`, then `nil` is unreadable live authority and must fail closed with stable reason `live_vertex_position_unreadable`.

Cached geometry fallback is allowed only when there is genuinely no live endpoint authority.

### BLOCK P0-C — submitted P0 tests do not model the real handle contract

Current new P0 tests were not executed because the local Ruby runtime failed. AIPM source review found concrete fixture errors:

- `adapter.created_handles` contains FakeGroup handles, not the FakeEdge the test searches for;
- some tests call `adapter.handle_for`, but `handle_for` is a workspace method;
- one test explicitly expects `vertex_position == nil` to fall back despite a live handle, contradicting the frozen fail-closed contract;
- the so-called Owner fixture is only a topology-snapshot assertion, not the required full Z + Gap -> Structure -> Region integration regression.

Do not repair these tests until AIPM re-dispatches after Codex review.

---

## 2. HIGH-RISK SECOND-ORDER FINDING — CODEX REVIEW REQUIRED

AIPM source inspection shows:

- derived edges are independently owned and may have separate physical endpoint Vertex handles for the same logical CAD coordinate;
- `PlanarNormalizationProposer` dedupes logical positions by coordinate, which is appropriate for analysis;
- but the candidate record currently retains only ONE physical `vertex_handle` for the first occurrence of a logical coordinate;
- later occurrences append `derived_id` but not their physical endpoint handles;
- executor mutates only `proposal[:unique_vertex_handles]`;
- production adapter documents that a single `Entities#transform_by_vectors` call expects vertices sharing one `Sketchup::Entities` collection.

Therefore correcting V1.7 to read true live coordinates may expose that V1.6 only normalized one physical copy of a shared logical vertex.

Pi is NOT authorized to redesign V1.6 under the current packet.

Codex must review the proposed correction in:

`Prompt/CODEX_V1_9A_P0_CURRENT_GEOMETRY_SHARED_VERTEX_REVIEW_2026-09-08.md`

---

## 3. NARROW NON-P0 MISSES TO PRESERVE FOR THE NEXT DISPATCH

Do not implement yet; these will be included after Codex review.

### P2-B — structure warning reads wrong V1.8 snapshot paths

Real V1.8 metrics use keys including:

- `open_chain_count`
- `closed_loop_count`
- `region_count`
- `hole_count`
- `invalid_loop_count`

and per-loop flags live inside `closed_loops[].unresolved_flags`.

Current presenter looks for `open_chains` and top-level/metrics-level `unresolved_flags`, so specific warning copy can miss real evidence.

Next correction must read the actual frozen V1.8 shape, using compatibility aliases only as fallback. Do not change V1.8.

### P1-C — FAILED issue-summary CTA

Current FAILED issue_summary emits:

```text
cta = 重新检测
cta_callback = refresh_cad_prep
```

The final-fix contract requires FAILED/STALE to rely on explicit recovery actions rather than a normal issue-summary CTA.

Next correction: FAILED issue_summary should have no normal CTA; existing recovery banner remains authoritative.

---

## 4. SOURCE-REVIEW PASS ITEMS — FREEZE

Do NOT reopen without concrete evidence:

- Current Issues primary list no longer appends raw `payload.groups`.
- Red issue badge no longer counts historical source-registry rows.
- Original/source inspection evidence remains under Details / 原始检查记录.
- Healthy ready-state `重新检测` routes to `refresh_cad_prep`, not rebuild.
- Planar presenter uses authoritative `movable_count` / `applied_count` with legacy fallback.
- READY_TO_NORMALIZE no longer says `未发现需要 Z 校正的点`.
- Hidden CSS production rules remain unchanged; CSS source guard now strips comments.

---

## 5. PI ACTION NOW

NONE.

Pi must STOP and wait.

Do not:
- edit production source;
- edit tests to accommodate the current incorrect implementation;
- change V1.6 / V1.7 / V1.8 algorithms;
- widen tolerance;
- change source/derived ownership;
- modify Undo / host-state behavior;
- begin V1.9B;
- invoke Codex.

AIPM will issue the next ACTIVE dispatch after the Codex review is returned.

END
