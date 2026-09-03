# CURRENT PI DISPATCH

DISPATCH_ID: V18-AIPM-SOURCE-REVIEW-CORRECTION-2026-09-02
STATUS: ACTIVE
PROJECT: SU-AI-Plugin
STAGE: V1.8
TARGET_BRANCH: dev/v1.8
CURRENT_REMOTE_HEAD: 4ca73ccb5684434fd102c0e6a059d60c186b627f

Authority:
- Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_8_LOOP_REGION_2026-09-02.md
- Review/CURRENT_AIPM_REVIEW.md

Mission: fix ONLY SR18-01..SR18-08 from AIPM direct source review. One bounded correction round before AIPM recheck + Owner gate.

## 1. Ruby 2.2
Remove V1.8 production `.sum` usage (`regions.sum`, `hole_ids.sum`) and any other Ruby>2.2 production APIs introduced by V1.8. Add a focused compatibility/source guard. Do NOT search/install Ruby 2.2/SU2017.

## 2. coordinate_epsilon
`compute_structure_reconstruction` must pass current captured `tol.coordinate_epsilon` into the reconstructor.
Direct calls may derive epsilon from canonical node records only if finite/positive/consistent.
Thread ONE epsilon through planarity, degenerate-area, self-intersection, boundary-touch, containment, hole validation, region-area validity.
No silent 1e-6 when valid captured non-default epsilon exists.
Add non-default epsilon regressions.
Do NOT modify V1.7 tolerance/CanonicalGraph schema.

## 3. Loop conflict detection
For NON-ADJACENT loop segments detect:
- proper interior crossing
- endpoint on unrelated segment interior / T-junction-like touch
- collinear interior overlap
- non-adjacent geometric touch
Prefer existing V1.7 SegmentConflict without changing its semantics.
Skip legitimate adjacent pairs including closure adjacency.
Tests: bow-tie, endpoint-on-segment, collinear overlap, normal rectangle.

## 4. O(V+E) traversal
Build once:
- incident_edge_ids_by_node
- normalized endpoint-pair -> edge IDs
Use indexes for component edge collection, chain/cycle walk, edge lookup.
Do NOT use `comp.combination(2)` to discover component edges.
Do NOT scan all edges per traversal step.
Parallel/multiple edges between same node pair => conservative invalid/unsupported component, no guessing.
Strengthen performance regression.

## 5. Cache invalidation
Clear `@structure_reconstruction_result` on:
- prepare/rebuild/discard
- duplicate repair mutation
- planar normalization apply
- gap repair applied OR failed/uncertain mutation
- `_invalidate_to_failed_with_reason`
- any new workspace publication that changes derived geometry
Tests:
A compute -> duplicate mutation -> NOT_COMPUTED
B compute -> planar apply -> NOT_COMPUTED
C compute -> generic failed invalidation -> no stale structure payload

## 6. Truthful state
- invalid graph => FAILED
- any unresolved/upstream warning => READY_WITH_WARNINGS
- warning-free => READY
Branch-only must be READY_WITH_WARNINGS.
Add assertions for branch-only and upstream-warning-only.

## 7. Deep immutability
Deep-freeze published normal StructureReconstructionResult, including chains/loops/regions/metrics/reasons/unresolved and nested arrays/hashes.
Mutation attempts must fail and cannot change digest.
Add regression.

## 8. Adjacency validation
Validate supplied canonical adjacency exactly against edge inventory:
- unknown adjacency key => invalid
- unknown neighbor => invalid
- missing edge-backed neighbor => invalid
- extra neighbor not backed by edge => invalid
Stable reason: `invalid_graph:adjacency_mismatch` or equivalent.
Do NOT modify V1.7 CanonicalGeometryGraph.
Add malformed-adjacency regression.

## Do not change
No V1.7 schema/identity/digest changes.
No SegmentConflict semantic changes.
No source/provenance authority changes.
No workspace ownership changes.
No host mutation/Face/Observer.
No site semantics.
No V1.9.
No Codex self-invocation.

If any requested fix appears to require a frozen-boundary change: STOP and report CODEX_RISK_TRIGGER=YES.

## Regression
Fresh:
- all SR18 new tests
- all V1.8 core/integration
- V1.7 full
- V1.6 close-autodiscard
- V1.5 BLOCK-005
- LEGACY-COMPAT
- full Ruby
- Node DOM
- RBZ smoke
- git diff --check
Rebuild RBZ.

Report exact counts plus RBZ size/entries/SHA-256 and ACTUAL packaged app.js SHA-256.

Overwrite Review/CURRENT_PI_REPORT.md.
Gate:
AIPM_REVIEW: PENDING NARROW RECHECK
CODEX_RISK_TRIGGER: NO unless frozen boundary touched
OWNER_SU2020: NOT YET
V1.9: NOT STARTED

After green: one normal fast-forward push to origin/dev/v1.8. No force/rebase/main/tag. STOP.
