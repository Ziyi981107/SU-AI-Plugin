# CURRENT PI DISPATCH — V2-0A SEMANTIC FOOTPRINT

Date: 2026-09-16
Project: SU-AI-Plugin
TARGET_BRANCH: dev/v2
STATUS: ACTIVE

## Baseline

V2 branch was created from the PB-06-reviewed commit:

`80bdbd62e63c8e8df1ffe3816df2d0cdd84e405f`

AIPM then added the frozen V2-0A technical blueprint on `dev/v2`.

Expected remote HEAD before Pi implementation:

`7c62a7a9e4eb9959fab07f2b7de01b29dcf006dd`

Pi must fetch and fast-forward/switch to `origin/dev/v2` before work.
If local cannot reach this exact baseline cleanly, STOP and report to AIPM.

Do not work on `dev/v1.9` or `fix/v2-pb06-reconstructor`.

## Current stage

V1 = CLOSED / frozen input authority.
PB-01..PB-06 = CLOSED by AIPM + Codex pre-build review.
V2 branch = OPEN.
V2-0A = ACTIVE IMPLEMENTATION DISPATCH.
V2-0B = NOT STARTED.
V2 Residential Stage 1 = NOT STARTED.

Historical statements elsewhere saying `V2 = NOT_STARTED` are stale project snapshots; this ACTIVE dispatch is the current task authority. Do not reinterpret old history as a competing task.

## Mandatory authority order

Read:

1. `PI_START_HERE.md`
2. `AGENTS.md`
3. `PROJECT_HANDOFF.md`
4. `PROJECT_MASTER_PLAN_V1X.md`
5. `CURRENT_STATE.md`
6. `Prompt/CURRENT_PI_DISPATCH.md`
7. `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0A_SEMANTIC_FOOTPRINT_2026-09-16.md`

For V2-0A, the V2-0A Blueprint is authoritative over historical V1/V2-not-started planning text where they conflict.

## Mission

Implement ONLY the pure-data Stage V2-0A pipeline:

PreparedCadDataset
→ exact mapped-layer filter
→ LayerLocalGraphAdapter
→ existing CanonicalStructureReconstructor
→ SemanticFootprintProjector
→ immutable SemanticFootprint records

Prove deterministic, conservative layer-local semantic-footprint extraction.

No SketchUp host write is allowed.

## Expected production files

Create:

- `extension/su_ai_plugin/v2/layer_local_graph_adapter.rb`
- `extension/su_ai_plugin/v2/semantic_footprint.rb`
- `extension/su_ai_plugin/v2/semantic_footprint_projector.rb`

A minimal V2 loader/helper may be added only if required for pure module loading/tests; report it explicitly.

Do NOT modify any existing V1 production file.

If any existing V1 production file appears necessary to change:
STOP with `V2_0A_SHARED_KERNEL_CHANGE_REQUIRED` or an equally explicit scope-expansion report.

## Test file

Create focused host-free coverage:

- `tests/test_v2_stage0a_semantic_footprint.rb`

Implement the complete PASS / REJECT matrix frozen in the V2-0A Blueprint, including:

PASS:
- rectangle
- concave polygon
- multiple disconnected footprints
- cross-layer shared node
- cross-layer coincident segment
- fully coincident geometry on distinct layers
- z below epsilon
- z exactly epsilon
- deterministic reorder identity

REJECT / fail closed:
- same-layer parallel edges
- branching
- bow-tie
- endpoint-on-segment
- collinear overlap
- degenerate/zero area
- hole-bearing/nested loops
- z above epsilon
- empty layer
- unknown layer
- invalid/non-positive epsilon
- malformed node/edge reference

No input mutation.

## Frozen technical rules

- Consume only published `PreparedCadDataset` data.
- Exact mapped `layer_name` matching only.
- Filter EDGES first.
- Rebuild layer-local adjacency from filtered EDGE inventory.
- Preserve edge multiplicity.
- Reuse existing `CanonicalStructureReconstructor`; do not copy polygon algorithms.
- `coordinate_epsilon` from PCD execution tolerance is the only Stage-0A geometry tolerance authority.
- Source vertex acceptance is inclusive: `abs(z) <= epsilon`.
- Accepted coordinates are copied/projected locally to exact `z=0.0`.
- Publish footprints from valid reconstructed REGIONS, never directly from raw loops.
- Hole-bearing regions are not Stage-0A footprints.
- `v2fp-*` is dataset-relative footprint identity, not future generated-object identity.
- PCD is immutable and unchanged.
- Ruby 2.2 / SketchUp 2017 compatibility remains mandatory.

## Strictly forbidden

Do NOT implement or modify:

- SketchUp Group/Face/extrusion
- host operation guard
- Tool / pickray / highlighting
- HtmlDialog / toolbar / loader wiring into product UI
- Layer Mapping UI/storage
- ResidentialObject
- balcony association
- floor/height modeling
- materials
- Site/raised community
- roads/landscape/context buildings
- MCP/LLM/Agent
- pcd.v1
- V1.9B2 persistence
- shared `CanonicalStructureReconstructor` behavior

Pi must not invoke Codex.

## Required regression run

At minimum:

1. `tests/test_v2_stage0a_semantic_footprint.rb`
2. `tests/test_v18_structure_reconstruction.rb`
3. `tests/test_v19b1_prepared_cad_dataset.rb`
4. `tests/test_v19b1_live_bundle_capture.rb`
5. relevant V1.7 reconstruction/topology regressions
6. project full test runner

Separate verified pre-existing unrelated failures from any new regression.
Do not weaken/delete/skip existing tests.

## Completion / submission

Complete the whole V2-0A task before formal submission.

Then:

1. update `CURRENT_STATE.md` with a concise V2-0A implementation record;
2. replace/update `Review/CURRENT_PI_REPORT.md` with implementation evidence;
3. commit the complete implementation + tests + required task-state/report artifacts using stable commits per repository workflow;
4. push only `dev/v2`;
5. print/report final remote HEAD;
6. STOP and return control to AIPM.

Do not start V2-0B.
Do not self-approve Stage 0A.
Do not request Codex review.

AIPM source review is the next gate.

END
