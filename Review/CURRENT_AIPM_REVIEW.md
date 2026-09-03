# AIPM DIRECT SOURCE REVIEW — V1.8 BASE

Project: SU-AI-Plugin
Stage: V1.8
Reviewed HEAD: 4ca73ccb5684434fd102c0e6a059d60c186b627f
Implementation: cc766fb266f34c33fc2713877583556646d906e0
Verdict: BLOCK — one bounded Pi correction round required
Codex risk trigger: NO, if fixes stay inside V1.8.

## Owner Summary
Overall architecture is correct and tests are green, but direct source review found contract gaps not covered by the current suite. Do not run Owner SU2020 gate yet.

## SR18-01 — Ruby 2.2 incompatibility
Production uses Enumerable/Array#sum (`regions.sum`, `hole_ids.sum`), unavailable in Ruby 2.2.4.
Fix with Ruby-2.2-compatible accumulation and add a V1.8 compatibility/source guard. Do not search/install Ruby 2.2 tonight.

## SR18-02 — coordinate_epsilon authority lost
V1.8 loop/containment geometry silently falls back to hard-coded 1e-6 because `_build_loop` never publishes the epsilon that `_loop_coord_eps` expects; containment and hole validation also hard-code 1e-6.
Fix by passing captured `tol.coordinate_epsilon` from WorkingModeRunner into the reconstructor and threading one resolved epsilon through planarity, degenerate area, self-intersection, boundary checks, containment, holes, and region validity. Add non-default-epsilon regressions. Do not change V1.7 tolerance authority/schema.

## SR18-03 — self-intersection incomplete
Current implementation detects only strict proper XY crossings. Blueprint also requires non-adjacent endpoint-on-segment/T-junction-like conflicts and collinear interior overlap.
Reuse existing V1.7 SegmentConflict where appropriate, or equivalent V1.8-local semantics. Skip legitimate adjacent pairs including closure adjacency. Add regressions for proper crossing, endpoint-on-segment, collinear overlap, and normal rectangle.

## SR18-04 — traversal is not O(V+E)
Current `_edges_in_component` uses node-pair combinations and `_edge_between` scans all edges; chain traversal scans all edges each step. This can degrade toward O(V^2*E)/O(E^2+).
Build deterministic incident-edge and normalized node-pair indexes once. Use them for component edges, chain/cycle traversal, and edge lookup. Parallel edges must fail conservatively, not silently collapse. Strengthen performance regression.

## SR18-05 — cache invalidation incomplete
The report/comment claims invalidation after duplicate repair, planar apply, gap apply, failed transitions. Direct source review only finds prepare/discard, successful gap apply, compute guards, reset.
Clear V1.8 cached result on duplicate-repair mutation, planar-normalization apply, gap applied/failed/uncertain mutation path, and `_invalidate_to_failed_with_reason`. Add integration tests.

## SR18-06 — warning-only empty result can publish READY
Current state logic returns READY when chains and loops are empty before honoring warnings. A branch-only component can therefore display “结构可用” while carrying `branching_component`.
Fix: invalid graph => FAILED; any warning => READY_WITH_WARNINGS; warning-free => READY. Add state assertions.

## SR18-07 — result not deeply immutable
Normal result freezes only the outer Hash. Nested arrays/hashes remain mutable, so a caller can mutate published content after digest computation.
Deep-freeze the published result recursively and add mutation-attempt regression.

## SR18-08 — adjacency contract not validated
`_validate_graph` only checks adjacency is a Hash; it does not prove supplied adjacency matches edge inventory as required by the Blueprint.
Reject unknown adjacency nodes/neighbors, missing edge-backed neighbors, and extra non-edge neighbors with stable invalid_graph subtype. Do not modify CanonicalGeometryGraph.

## Non-blocking
- UI prioritizing `检查间隙` before `检查结构` is acceptable tonight; no redesign needed.
- Correction report should publish the actual packaged app.js SHA rather than the current contradictory baseline wording.

## Gate
AIPM_REVIEW: BLOCK
Next: one Pi correction packet.
Codex: NOT REQUIRED unless Pi touches V1.7 schema/identity/digest, tolerance authority, SegmentConflict semantics, workspace ownership, host mutation/Face/Observer.
Owner SU2020: NOT YET
V1.9: NOT STARTED
