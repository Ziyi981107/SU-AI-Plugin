# CODEX REVIEW REQUEST — V1.9A P0 CURRENT-GEOMETRY / SHARED-PHYSICAL-VERTEX BOUNDARY

Project: SU-AI-Plugin
Branch: `dev/v1.9`
Date: 2026-09-08
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Reviewer: Codex (review-only)
Implementation Agent: Pi (HOLD — do not implement until AIPM re-dispatches)
Current HEAD at AIPM review: `23a6dc51288e22e536760b045479632bc2561d4c`
V1.9B: NOT STARTED / NOT AUTHORIZED

## 0. Review objective

Review one high-risk deterministic geometry boundary only:

`V1.6 Planar Normalization host mutation -> CURRENT DerivedGeometryWorkspace -> V1.7 topology snapshot / canonical graph`

Do NOT redesign the product, do NOT begin V1.9B, and do NOT propose AI/MCP/Agent work.

AIPM has already found that Pi's first P0 fix is incorrect. We need Codex to independently verify the root cause and review the proposed technical correction before Pi changes V1.6 host-mutation behavior.

## 1. Real SU2020 Owner evidence

Owner fixture:
- near-rectangle;
- safe endpoint gap = 1 mm;
- one shared corner has safe Z drift = 0.2 mm.

Observed before the attempted P0 fix:

```text
WORKSPACE: ready
STRUCTURE: READY_WITH_WARNINGS
open_chain_count: 0
closed_loop_count: 1
region_count: 0
invalid_loop_count: 1
flags: ["non_planar_loop"]
```

The reconstructed loop still contained:

```text
z = 0.007874015748031498 in
```

exactly 0.2 mm, the original pre-Z drift.

This initially exposed that V1.7 was consuming cached build-time `geometry_summary` instead of CURRENT derived host coordinates.

## 2. AIPM source-review BLOCK on Pi's attempted P0 fix

Inspect current:

`extension/su_ai_plugin/core/endpoint_record.rb`

Pi changed `DerivedTopologySnapshotBuilder.build` so it calls `_live_coordinate_for` using:

```ruby
host_handle = workspace.handle_for(edid)
```

for BOTH `#{edid}.start` and `#{edid}.end`.

But the existing workspace contract stores a derived GROUP handle per `derived_id`. The real endpoint Vertex handles are already resolved separately by the runner / adapter:

- `adapter.edge_endpoints(group_handle)` -> `[start_vertex, end_vertex]`;
- `_host_vertex_map(workspace)` -> `endpoint_key => host_vertex_handle`;
- `DerivedTopologySnapshotBuilder.build(... vertex_keys_by_edge: host_vertex_map)`;
- EndpointRecord already assigns `host_vertex_handle` from that endpoint-key map.

Production adapter contract:

```ruby
def vertex_position(vertex_handle)
  # Sketchup::Vertex only; returns [x,y,z] or nil
end
```

Therefore `vertex_position(group_handle)` returns nil on real SketchUp. Pi's helper then treats nil as "no live authority" and falls back to stale cached geometry, preserving the original bug.

### Required review question A

Confirm whether the correct V1.7 read seam is:

```text
endpoint_key
-> host_vertex_map[endpoint_key]
-> adapter.vertex_position(actual Vertex handle)
-> CURRENT world_coordinate
```

while `workspace.handle_for(edid)` remains the edge/group-level handle for edge safety / provenance only.

### Required review question B

The frozen AIPM rule was:

> If a live endpoint handle exists and the adapter exposes `vertex_position`, but the live read is malformed / non-finite / unreadable, fail closed; do not silently substitute cached pre-mutation geometry.

Current Pi code treats `vertex_position(...) == nil` as cached fallback even when a live handle exists.

Confirm that `nil` in this condition must be treated as `live_vertex_position_unreadable`, while cached fallback is allowed only when there is genuinely NO live endpoint authority (no adapter, no endpoint handle, or adapter lacks the live-read capability in a host-free test context).

## 3. Deeper AIPM finding: V1.6 logical vertex dedupe vs physical derived vertices

This is the main high-risk review target.

Inspect current:

- `extension/su_ai_plugin/core/planar_normalization_proposer.rb`
- `extension/su_ai_plugin/core/planar_normalization_executor.rb`
- `extension/su_ai_plugin/core/derived_workspace_adapter.rb`
- `extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb`

### Current representation

Derived workspace creates independently-owned derived geometry. In the fake adapter, each derived source edge has its own pair of `FakeVertex` handles; the fake explicitly does NOT dedupe vertices across edges. Production SketchUp derived edge groups likewise do not share mutable vertex ownership across independently-created groups.

### Current proposer behavior

`PlanarNormalizationProposer` correctly dedupes ANALYSIS positions by geometric coordinate (`seen_keys` / `candidate_positions`). But `candidate_records` stores only ONE `vertex_handle` for the first edge in that logical coordinate cluster.

When another safe edge shares the same logical coordinate, the code currently appends only its `derived_id`; it does NOT append that edge's physical endpoint Vertex handle.

Then for each analyzer proposed move the proposer builds:

```text
unique_vertex_handles << one vertex handle
vectors << one Z vector
```

### Current executor behavior

`PlanarNormalizationExecutor` calls:

```ruby
adapter.transform_vertices_by_vectors(handles, vectors)
```

once for the proposal handle array.

The production adapter explicitly documents that SketchUp `Entities#transform_by_vectors` requires supplied vertices to share one `Sketchup::Entities` collection. Physical vertex copies living in separate derived groups therefore cannot simply be combined into one cross-group host batch.

### Why this matters for the Owner fixture

The 0.2 mm corner is a logical CAD vertex shared by two source edges. After derivation, those two edge records can have two independently-owned host Vertex handles at the same world coordinate.

If V1.6 moves only one physical handle:
- one derived edge endpoint becomes Z=0;
- the other remains Z=0.2 mm;
- a corrected V1.7 live-coordinate snapshot would then expose two different current positions at what used to be one logical vertex;
- canonical topology may split / remain non-planar / become open rather than producing the expected valid Region.

This is currently a SOURCE-BASED technical risk; the attempted P0 patch did not reach a truthful integration test because its new Ruby tests were not executed and several fixtures do not follow the real adapter handle contract.

## 4. Proposed AIPM technical direction for Codex review

Do NOT treat this as pre-approved implementation. Review it critically.

### 4.1 Preserve logical analysis dedupe

Keep one analyzer candidate per coordinate cluster. We do NOT want to count the same logical CAD vertex multiple times merely because the derived representation has multiple physical copies.

Conceptually change candidate record from:

```ruby
{
  vertex_handle: one_handle,
  derived_ids: [...]
}
```

to something equivalent to:

```ruby
{
  vertex_handles: [all eligible physical endpoint handles in this logical coordinate cluster],
  derived_ids: [...],
  source_occurrence_ids: [...]
}
```

When a second SAFE edge contributes the same logical coordinate, append its endpoint handle (dedup by object identity) and provenance. Existing `shared_with_unsafe` logic must continue to skip the entire logical cluster if any contributing edge makes the cluster unsafe.

### 4.2 Expand one logical Z move to all eligible physical handles

For each analyzer proposed move at logical coordinate K:

```text
logical move: K -> target_z
```

expand to the same `[0,0,dz]` for every physical host Vertex handle belonging to K.

`movable_count` should remain the logical candidate/move count.
The executor audit `applied_count` may remain the number of physical host vertices actually mutated, but Codex should flag any compatibility concern with existing audit semantics.

### 4.3 Preserve one outer SketchUp operation, but do not cross owner collections

Because vertices from different derived groups may belong to different `Sketchup::Entities` collections, do NOT send a mixed cross-group array to one `Entities#transform_by_vectors` call.

A simple candidate strategy is:

```text
begin one existing outer SketchUp operation
for each physical vertex handle:
    adapter.transform_vertices_by_vectors([handle], [vector])
post-validate ALL handles
commit once
```

If any inner host mutation fails, abort the ONE outer operation so prior partial mutations roll back atomically.

Alternative grouping by owner `Sketchup::Entities` is acceptable only if it can be implemented without weakening ownership abstraction or adding brittle host introspection. Prefer the smallest robust path.

### 4.4 Preserve all existing safety / product contracts

Must preserve:
- Source CAD immutable;
- derived-only mutation;
- same deterministic target Z / tolerance rules;
- same unsafe Curve / Face / shared-with-unsafe exclusions;
- one user-triggered transaction with rollback on failure;
- host mismatch fail closed;
- no Observer architecture;
- no Face generation;
- no V1.7 gap-pairing / canonical-node / segment-conflict semantic change;
- no V1.8 algorithm change;
- Ruby 2.2-era compatibility.

## 5. Test defects found by AIPM in Pi's current P0 test file

Inspect:

`tests/test_v19a_final_p0_live_coordinates.rb`

Current tests were NOT executed because Pi's system Ruby runtime was broken.

AIPM source review found the tests do not faithfully model the real handle contract:

1. The primary fixture searches `adapter.created_handles` for an object behaving like `FakeEdge`, but `created_handles` stores `FakeGroup`; actual edges are under `added_edges` / group children.
2. Some tests call `adapter.handle_for(...)`, but `handle_for` belongs to the workspace (`ws.handle_for`), not `FakeDerivedWorkspaceAdapter`.
3. The test explicitly asserts `vertex_position == nil` should fall back to cached geometry even when a live handle exists, contradicting the frozen fail-closed requirement.
4. The so-called Owner-fixture test only asserts snapshot coordinates; it does NOT run the required full `Z + Gap -> Closed Loop + Region` production-like integration path.

### Required review question C

Confirm these test defects and specify the minimum faithful regression test shape.

AIPM expects at least:

- resolve derived group with `ws.handle_for(edid)`;
- resolve actual endpoint vertices with `adapter.edge_endpoints(group)` / the production host map;
- mutate/read those actual endpoint handles;
- verify live coordinate wins over cached summary;
- live endpoint handle + nil/malformed/non-finite read -> fail closed;
- no live endpoint handle -> cached fallback is allowed;
- true integration test through WorkingModeRunner / CadPrepWorkflowOrchestrator as far as the fake host supports:
  `start -> planar actionable + gap detected/locked -> apply planar -> gap recomputed/unlocked -> apply gap -> structure recomputed -> open_chain=0 / closed_loop=1 / invalid_loop=0 / region=1`.

If the shared-physical-vertex issue causes this integration test to fail, Codex should identify the precise failed invariant and judge whether the AIPM fan-out proposal above is the correct minimal V1.6 correction.

## 6. Two additional narrow source-review misses (not the main Codex target)

These do NOT need architectural redesign, but please sanity-check them if convenient.

### 6.1 Structure warning copy reads wrong V1.8 paths

Real V1.8 snapshot evidence uses metrics such as:

```text
open_chain_count
closed_loop_count
region_count
hole_count
invalid_loop_count
```

and invalid loop flags live inside each `closed_loops[]` record's `unresolved_flags`.

Current new presenter helper instead looks for `metrics['open_chains']` and top-level / metric-level `unresolved_flags`, so:
- open-chain-specific warning copy can miss real open chains;
- `non_planar_loop` specificity can miss the real nested loop flag.

Expected narrow correction: read the actual frozen V1.8 snapshot shape, with compatibility aliases only as fallback. Do not change V1.8.

### 6.2 FAILED issue-summary CTA

Final-fix guidance said FAILED/STALE should rely on explicit recovery actions rather than a normal `重新检测` issue-summary affordance. Current presenter emits:

```text
FAILED -> cta='重新检测', cta_callback='refresh_cad_prep'
```

STALE correctly has no issue-summary CTA and uses recovery.

Expected narrow correction: FAILED issue_summary should also have no normal CTA; the existing recovery banner owns `重新生成工作副本` / `放弃工作副本`. Do not change the generic FAILED copy or DialogRunner error boundary.

## 7. What already looks correct — do NOT reopen without evidence

AIPM source review found these Final Block Fix directions generally correct:

- primary current Issues list no longer appends raw `payload.groups`;
- red issue badge no longer counts historical source-registry rows;
- raw/original source evidence remains under Details / original inspection record surface;
- normal healthy `重新检测` uses `refresh_cad_prep` rather than rebuild;
- planar presenter now reads authoritative `movable_count` / `applied_count` with legacy fallback;
- contradictory READY_TO_NORMALIZE copy is removed;
- production hidden CSS remains untouched and the new test helper strips CSS comments before source-order checks.

Do not redesign these unless you find a concrete regression.

## 8. Required Codex output

Return a concise technical review with:

1. **Verdict**: PASS / FIX REQUIRED on AIPM's root-cause analysis.
2. **Handle contract**: confirm GROUP vs EDGE vs VERTEX ownership and the correct live-read path.
3. **Nil semantics**: confirm fail-closed vs fallback conditions.
4. **Shared logical coordinate**: determine whether current V1.6 mutates only one physical endpoint copy and whether this is a real correctness bug.
5. **Host transaction strategy**: review one-handle-per-call inside one outer operation vs owner-grouped batching; recommend the simplest safe route for SU2017/SU2020.
6. **Proposer data shape**: recommend the minimum change needed to carry all physical handles while preserving logical analyzer dedupe and provenance.
7. **Audit semantics**: flag any issue with logical `movable_count` vs physical `applied_count`.
8. **Regression tests**: identify exact tests needed, including a true end-to-end Z+Gap->Region regression.
9. **Risk boundaries**: list files Pi may need to touch and files/algorithms that must remain frozen.
10. **Any official SketchUp API / mature-extension pattern** relevant specifically to `Entities#transform_by_vectors`, operation atomicity, and vertex ownership. If external verification is unavailable, say so rather than guessing.

Do not implement code. Do not modify the repository. Return review only.

END
