# AIPM STAGE TECHNICAL BLUEPRINT — V2-0A SEMANTIC FOOTPRINT

Date: 2026-09-16
Project: SU-AI-Plugin
Target branch: `dev/v2`
Status: FROZEN FOR IMPLEMENTATION
Final Product Owner: Owner
Technical authority: ChatGPT / AIPM

## 0. Stage purpose

V2-0A is a pure-data feasibility/proof stage.

It proves that a validated V1 `PreparedCadDataset` can be projected by an exact mapped CAD layer into deterministic, conservative, buildable V2 semantic footprints without touching SketchUp host state.

This stage does **not** generate SketchUp geometry and does **not** implement the AI Site UI.

Frozen pipeline:

`PreparedCadDataset`
→ exact layer filter
→ `LayerLocalGraphAdapter`
→ existing `CanonicalStructureReconstructor`
→ `SemanticFootprintProjector`
→ immutable V2 semantic-footprint records

The PB-06 shared-reconstructor hotfix is already part of the `dev/v2` baseline.

## 1. Frozen V1 boundary

V1 is CLOSED.

V2 may consume only published `PreparedCadDataset` data. It must not:

- reach into `WorkingModeRunner` private state;
- rescan raw SketchUp entities as V2 semantic authority;
- mutate Source CAD;
- mutate V1 Derived Workspace;
- change `pcd.v1`;
- reopen V1.9B2 persistence;
- redefine V1 semantic IDs.

`PreparedCadDataset.content['semantic_graph']` is the geometry authority for this stage.

## 2. Host-free contract

All V2-0A production modules must be pure Ruby and host-free.

Forbidden in V2-0A production code:

- `Sketchup` API calls;
- `UI` / `HtmlDialog`;
- model/entity handles;
- `start_operation`, `commit_operation`, `abort_operation`;
- toolbar/menu wiring;
- MCP/LLM/Agent calls.

No V2-0A code may create, erase, transform, select, highlight, or otherwise mutate SketchUp entities.

## 3. Proposed module ownership

Create under `extension/su_ai_plugin/v2/`:

### 3.1 `layer_local_graph_adapter.rb`

Owns only the projection of one exact mapped CAD layer from the published PCD semantic graph into the pure graph shape required by `CanonicalStructureReconstructor`.

Public conceptual API:

`LayerLocalGraphAdapter.project(dataset:, layer_name:)`

Responsibilities:

1. Require a real finalized/validated `PreparedCadDataset` suitable for V2 consumption.
2. Require non-empty mapped `layer_name` String.
3. Read only `dataset.content['semantic_graph']`.
4. Filter EDGES by exact `edge['layer_name'] == layer_name`.
5. Unknown / empty / implicit layer matching is forbidden.
6. Retain only nodes referenced by the filtered edges.
7. Rebuild adjacency from the FILTERED EDGE RECORDS themselves.
8. Preserve edge multiplicity. Do not deduplicate parallel edges into one logical edge.
9. Adapt PCD semantic IDs into the field names expected by `CanonicalStructureReconstructor` without inventing new geometry.
10. Preserve source edge provenance needed downstream.
11. Return a deterministic pure-data result; never mutate dataset input.

Important: published/global PCD adjacency must not be used as the layer-local authority after filtering. Layer-local adjacency is rebuilt from filtered edges.

### 3.2 `semantic_footprint.rb`

Owns the immutable V2 Stage-0A footprint value record and validation of its field shape.

Conceptual fields:

- `schema_version` = `v2.semantic-footprint.v1`
- `footprint_id`
- `semantic_role`
- `source_layer_name`
- `source_dataset_id`
- `source_content_digest`
- `coordinate_epsilon`
- `source_node_ids`
- `source_edge_ids`
- `projected_world_coordinates`
- `area_xy`
- `perimeter`

The record is dataset-relative. A `v2fp-*` identity is NOT a durable building/object identity across changed PreparedCadDatasets.

The record must be JSON-safe / deterministic / deeply immutable following existing project style.

### 3.3 `semantic_footprint_projector.rb`

Owns V2 semantic-footprint derivation.

Conceptual API:

`SemanticFootprintProjector.project(dataset:, semantic_role:, layer_name:)`

Responsibilities:

1. Validate dataset usability/schema without host access.
2. Resolve the single geometry tolerance authority from:
   `dataset.content['execution']['tolerance_values']['coordinate_epsilon']`.
3. Require `coordinate_epsilon` to be Numeric, finite, and strictly > 0.
4. Call `LayerLocalGraphAdapter` for exact mapped layer.
5. Call existing `CanonicalStructureReconstructor.reconstruct` with the same explicit `coordinate_epsilon`.
6. Project only valid reconstructed REGIONS, never raw loops.
7. Apply the Stage-0A acceptance contract below.
8. Publish accepted immutable footprints plus deterministic rejection evidence for non-buildable results.
9. Never mutate PCD or reconstructor output.

## 4. Stage-0A footprint acceptance contract

A footprint is publishable only when ALL conditions hold:

- reconstructed region has exactly one outer loop;
- `hole_loop_ids` is empty;
- region has no unresolved flags;
- referenced outer loop exists;
- outer loop `valid_for_region == true`;
- outer loop has at least 3 distinct nodes;
- source coordinates are finite;
- every source vertex satisfies inclusive ground-plane check:
  `abs(z) <= coordinate_epsilon`.

For an accepted footprint, V2 creates a LOCAL projected coordinate copy:

`[x, y, z] -> [x, y, 0.0]`

PCD data and reconstructor data remain unchanged.

Stage 0A/1 construction plane authority is therefore exactly `z = 0.0`.

Reject/fail closed for:

- holes / nested inner loops;
- self-intersection;
- endpoint-on-segment ambiguity;
- collinear overlap ambiguity;
- zero/degenerate area;
- same-layer parallel edges;
- branching components;
- malformed/missing references;
- non-finite coordinates;
- any vertex with `abs(z) > coordinate_epsilon`;
- missing/invalid coordinate epsilon;
- empty/unknown mapped layer.

Do not invent geometry to repair these cases in V2-0A.

## 5. SemanticFootprint identity

Prefix: `v2fp-`.

Identity is deterministic only within the source PCD semantic content.

Compute identity from a versioned, unambiguous domain containing at minimum:

- footprint identity schema/version;
- `semantic_role`;
- exact `source_layer_name`;
- canonical outer-loop source semantic node/edge sequence as returned from the deterministic layer-local reconstruction.

Use SHA-256 and a project-consistent truncated display ID while retaining the source PCD full `content_digest` separately.

Do not use SketchUp entity IDs.
Do not use transient legacy IDs.
Do not equate footprint identity with future `v2obj-*` generated-object identity.

If implementation needs a collision guard consistent with existing project semantic-ID practice, implement it locally for V2-0A without modifying `pcd.v1`.

## 6. Output/status contract

The projector must expose explicit status rather than silently returning partial truth.

Minimum conceptual outcomes:

- `PROJECTED`: one or more valid footprints published, no relevant rejection.
- `PROJECTED_WITH_REJECTIONS`: valid footprints published and one or more layer-local components/regions were conservatively rejected.
- `EMPTY`: mapped layer exists in the PCD layer inventory / graph context but yields no buildable footprint.
- `BLOCKED`: invalid dataset, invalid epsilon, missing/empty mapped layer, or other contract failure prevents trustworthy projection.

Exact constant names may follow repository style, but semantics above are frozen.

Return stable blocker/rejection reasons suitable for tests and later UI surfacing.

Do not convert a reconstructor warning into a valid footprint unless the acceptance contract explicitly permits it.

## 7. Required Stage-0A regression matrix

Create a focused host-free test file, preferably:

`tests/test_v2_stage0a_semantic_footprint.rb`

### PASS cases

1. simple rectangle -> one footprint;
2. concave simple polygon -> one footprint;
3. multiple disconnected valid loops on same mapped layer -> multiple footprints;
4. residential-body and balcony geometry share a node but are on different layers -> body-layer projection remains valid;
5. body and balcony have coincident segment on different layers -> body-layer projection remains valid;
6. fully coincident edges on distinct layers -> exact layer projection isolates each layer;
7. all source z values below epsilon -> accepted/projected to z=0;
8. source z exactly equal to epsilon -> accepted/projected to z=0;
9. deterministic input reorder -> byte/value-equivalent footprint output and same footprint IDs.

### REJECT / FAIL-CLOSED cases

10. same-layer parallel edges;
11. branching topology;
12. bow-tie/self-intersection;
13. endpoint-on-segment ambiguous geometry;
14. collinear overlap;
15. zero-area/degenerate loop;
16. outer + inner nested loop / hole -> no Stage-0A footprint for that hole-bearing region;
17. any source z above epsilon;
18. empty mapped layer name;
19. unknown mapped layer;
20. missing/invalid/non-positive coordinate_epsilon;
21. malformed edge/node reference.

Tests must prove no input object is mutated.

## 8. Reconstructor reuse contract

`CanonicalStructureReconstructor` remains the authority for:

- self-loop rejection;
- parallel-edge detection;
- branching;
- edge/node cardinality;
- deterministic cycle traversal;
- repeated vertices;
- self-intersection;
- endpoint-on-segment;
- collinear overlap;
- degeneracy;
- containment;
- region/hole reconstruction.

Do NOT copy those algorithms into V2.

If V2-0A cannot adapt to the reconstructor without changing reconstructor behavior, STOP and report `V2_0A_SHARED_KERNEL_CHANGE_REQUIRED` to AIPM. Do not independently modify the shared kernel.

## 9. Compatibility

Maintain SketchUp 2017+ / Ruby 2.2-era syntax.

No newer Ruby helpers disallowed by the existing project compatibility contract.

Host-free tests run under the project Ruby runner, but production code must remain compatible with the embedded baseline.

## 10. Allowed implementation scope

Expected new production files:

- `extension/su_ai_plugin/v2/layer_local_graph_adapter.rb`
- `extension/su_ai_plugin/v2/semantic_footprint.rb`
- `extension/su_ai_plugin/v2/semantic_footprint_projector.rb`

Expected new focused test file:

- `tests/test_v2_stage0a_semantic_footprint.rb`

Pi may add a minimal `extension/su_ai_plugin/v2/` loader/helper file only if technically required for pure module loading/tests; report it explicitly.

Do not modify V1 production files in this stage.

If any existing V1 production file must change, STOP and report scope expansion to AIPM.

## 11. Required regression evidence

At minimum run:

- new V2 Stage-0A focused tests;
- `tests/test_v18_structure_reconstruction.rb`;
- `tests/test_v19b1_prepared_cad_dataset.rb`;
- `tests/test_v19b1_live_bundle_capture.rb`;
- relevant V1.7 regressions used by the reconstructor path;
- project full test runner, with pre-existing unrelated failures clearly separated from new regressions.

No existing test may be weakened, skipped, or deleted to obtain green results.

## 12. Stage gate

V2-0A is PASS only when:

1. exact layer-local filtering is deterministic;
2. filtered-edge multiplicity is preserved;
3. adjacency is rebuilt from filtered edges;
4. existing reconstructor is reused rather than duplicated;
5. acceptance/rejection matrix is green;
6. no SketchUp host dependency exists in V2-0A production modules;
7. no V1 production file changed;
8. all required regressions pass or only verified pre-existing unrelated failures remain;
9. AIPM source review passes after Pi submission.

Codex is not invoked by Pi.

After Pi completion: AIPM source review first. AIPM decides whether any Codex recheck is needed before V2-0B.

## 13. Out of scope

Explicitly NOT in V2-0A:

- SketchUp Group/Face/extrusion;
- V2HostOperationGuard;
- selection/pickray/highlight;
- HtmlDialog / toolbar / menu;
- Layer Mapping UI/template storage;
- ResidentialObject;
- balcony association;
- floor count/height;
- material palette;
- Site Base / raised community;
- roads / landscape / context buildings;
- MCP / LLM / Agent;
- persistence redesign.

END
