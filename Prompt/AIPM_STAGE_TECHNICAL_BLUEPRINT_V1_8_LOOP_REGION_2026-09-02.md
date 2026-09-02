# AIPM STAGE TECHNICAL BLUEPRINT — V1.8

PROJECT: SU-AI-Plugin
STAGE: V1.8 — Polyline / Closed Loop / Region Reconstruction
DATE: 2026-09-02
STATUS: FROZEN FOR IMPLEMENTATION
DESIGN OWNER / TECHNICAL AUTHORITY: AIPM
FINAL PRODUCT OWNER: Owner
IMPLEMENTATION AGENT: Pi
DEFAULT REVIEW: AIPM SOURCE REVIEW
CODEX REVIEW: RISK-TRIGGERED ONLY
SCOPE: CAD preparation only
BASELINE HEAD: ac0f26727574e4ea3830fec9fe4764a56e743358

---

# 0. OWNER SUMMARY

V1.8 turns V1.7's trustworthy canonical nodes + edges + adjacency into structures
that downstream site-modeling logic can actually consume:

canonical graph
→ open chains
→ closed loops
→ nested loops / holes
→ regions

The primary Owner demo is intentionally simple:

1. Select a clean rectangle.
2. 准备处理.
3. 检查结构.
4. Plugin reports:
   - 开放链：0
   - 闭合轮廓：1
   - 区域：1
   - 洞：0
   - 异常：0

Secondary demo:

outer rectangle + inner rectangle
→ 闭合轮廓：2
→ 区域：1
→ 洞：1

A V1.7 repaired almost-closed triangle must also reconstruct as one closed loop
and one region after the repair bridge has been applied.

V1.8 MUST stay deterministic and conservative.

V1.8 is NOT:
- SketchUp Face generation as a required feature;
- site semantic recognition;
- road/building/boundary classification;
- V2 modeling;
- MCP;
- AI;
- a generic computational-geometry kernel;
- an excuse to redesign V1.7 canonical identity.

---

# 1. PRODUCT AUTHORITY / STAGE BOUNDARY

Master Plan V1.8 durable scope:

- chains/polylines;
- closed-loop detection;
- self-intersection/open-chain/repeated-vertex detection;
- nested loops/holes;
- region reconstruction;
- loop-level unresolved issues;
- optional disposable derived face preview for validation only.

Hard rule:

> V1.8 does not assign site semantics.

V1.7 already froze the upstream boundary:

CanonicalGeometryGraph owns:
- canonical nodes;
- canonical edges;
- adjacency;
- unresolved topology issues;
- deterministic digest/provenance.

V1.8 consumes that graph.

V1.8 MUST NOT expand CanonicalGeometryGraph's V1.7 schema with loops/regions.
Create a separate downstream immutable reconstruction result.

Reason:
- preserves V1.7 closure;
- avoids reopening identity/digest contracts;
- keeps Codex risk gate unnecessary by default;
- makes V1.8 disposable/recomputable from the graph;
- reduces implementation time before the presentation milestone.

---

# 2. ARCHITECTURE DECISION

Introduce a pure, SketchUp-independent V1.8 reconstruction layer.

Recommended production file:

`extension/su_ai_plugin/core/canonical_structure_reconstructor.rb`

It may contain small immutable value objects in the same file to minimize
integration surface:

- ChainRecord
- LoopRecord
- RegionRecord
- StructureReconstructionResult
- CanonicalStructureReconstructor

Pi MAY split these into multiple core files only if that materially improves
clarity. Do not create architecture ceremony for its own sake.

Input:
`CanonicalGeometryGraph` or its equivalent JSON-safe Hash.

Output:
`StructureReconstructionResult`

No host handles.
No SketchUp::Entity.
No mutation.
No native operation.
No random IDs.
No observer.

The V1.8 result is DERIVED STATE and may always be recomputed from the current
canonical graph.

---

# 3. DATA CONTRACTS

## 3.1 StructureReconstructionResult

Conceptual contract:

- schema_version = `csr.v1`
- canonical_graph_digest
- source_snapshot_id
- workspace_id
- chains
- loops
- regions
- unresolved_issues
- metrics
- digest

Required states for UI/integration:

- NOT_COMPUTED
- READY
- READY_WITH_WARNINGS
- FAILED

`READY` means:
- reconstruction completed deterministically;
- no unresolved V1.8 issue blocks interpretation of the produced structures.

`READY_WITH_WARNINGS` means:
- valid structures exist and are usable;
- one or more components/loops were conservatively left unresolved.

`FAILED` means:
- input graph contract is structurally invalid or reconstruction itself failed;
- do not publish false regions.

The result must be:
- JSON-safe through `to_h`;
- deterministic for identical canonical graph content;
- deeply immutable/frozen at the public boundary;
- digestable independent of input iteration order.

## 3.2 ChainRecord

Required fields:

- chain_id
- node_ids (ordered)
- edge_ids (ordered)
- start_node_id
- end_node_id
- closed = false
- length
- source_occurrence_ids (plural sorted/uniq authority)
- layer_names (sorted/uniq; informational only)
- unresolved_flags

A valid base V1.8 open chain has:
- exactly two degree-1 terminal nodes;
- every internal node degree == 2;
- every component edge consumed exactly once.

Branching components are NOT decomposed heuristically into many chains in base
V1.8.

## 3.3 LoopRecord

Required fields:

- loop_id
- node_ids (ordered canonical traversal)
- edge_ids (ordered canonical traversal)
- world_coordinates (ordered vertices, do not duplicate first vertex at end unless
  one consistent contract is explicitly chosen and tested)
- closed = true
- perimeter
- signed_area_xy
- area_xy
- winding = CW | CCW | DEGENERATE
- source_occurrence_ids
- layer_names
- unresolved_flags
- valid_for_region = true | false

Winding is geometric information only.
It MUST NOT imply building/road/site semantics.

A valid loop:
- every component node degree == 2;
- traversal returns to start;
- consumes each expected edge exactly once;
- no repeated non-terminal vertex;
- no self-intersection;
- XY area is finite and materially non-zero;
- loop is sufficiently planar for the V1.8 2D contract.

## 3.4 RegionRecord

Required fields:

- region_id
- outer_loop_id
- hole_loop_ids (sorted deterministically)
- area_xy
- perimeter_outer
- source_occurrence_ids (union)
- layer_names (union)
- unresolved_flags

One RegionRecord represents:
one valid outer loop + its immediate valid hole loops.

Nested depth rule:
- depth 0 loop -> outer region;
- depth 1 loop -> hole of depth 0;
- depth 2 loop -> new island/outer region;
- depth 3 -> hole of depth 2;
- etc.

This is geometric containment only, not site semantics.

---

# 4. DETERMINISTIC IDENTITY

No UUID/random/object_id/entityID identity.

All V1.8 IDs derive only from stable V1.7 canonical IDs + schema.

## 4.1 Open chain orientation

For a valid open-chain component:
- start from the lexicographically smaller of the two degree-1 node IDs;
- at each degree-2 node take the only not-just-used edge;
- record ordered node_ids + edge_ids;
- derive `chain_id` from schema + normalized ordered IDs using SHA-256.

## 4.2 Closed loop orientation

For a simple degree-2 loop:
- choose lexicographically smallest canonical node ID as start;
- exactly two candidate first neighbors exist;
- build the two valid traversal orientations;
- compare normalized token sequence and choose lexicographically smaller;
- derive `loop_id` from schema + normalized node/edge sequence using SHA-256.

Do not use discovery ordinal.

## 4.3 Region identity

`region_id` derives from:
- schema;
- outer_loop_id;
- sorted immediate hole_loop_ids.

## 4.4 Result digest

Digest MUST be based on canonical serialized content:
- graph digest;
- sorted chains;
- sorted loops;
- sorted regions;
- sorted unresolved issues;
- deterministic metrics.

Timestamps, array insertion accidents, and Ruby Hash discovery order must not
change digest.

---

# 5. GRAPH VALIDATION BEFORE RECONSTRUCTION

Before traversal validate:

- graph present;
- nodes/edges/adjacency collections have supported shapes;
- every canonical edge has non-empty canonical_edge_id;
- every edge references two known canonical node IDs;
- no edge references a missing node;
- adjacency does not claim neighbors inconsistent with edge inventory;
- every world endpoint is finite;
- no unsupported self-loop edge (`node_a_id == node_b_id`) is silently accepted;
- duplicate canonical_edge_id is invalid;
- canonical node IDs are unique;
- graph digest may be recorded as authority but do not silently rewrite graph.

If core input integrity fails:
`FAILED`
with stable unresolved/error reason(s).

Existing V1.7 unresolved topology issues MUST be propagated to the V1.8 result
as upstream warnings. V1.8 may still reconstruct unaffected valid components
when safe; it must not pretend upstream uncertainty disappeared.

---

# 6. CONNECTED COMPONENT CLASSIFICATION

Build deterministic connected components from canonical edge/node relationships.

For each component compute:
- node count;
- edge count;
- node degree map;
- min/max degree;
- terminal nodes degree == 1;
- branch nodes degree > 2.

Base V1.8 classification:

## A. Simple open chain
Conditions:
- exactly 2 degree-1 nodes;
- every other node degree == 2;
- edge_count == node_count - 1.

Action:
emit one ChainRecord.

## B. Simple closed loop
Conditions:
- every node degree == 2;
- edge_count == node_count;
- at least 3 distinct nodes.

Action:
deterministic cycle traversal, then geometry validation.
If valid -> LoopRecord valid_for_region=true.
If invalid -> LoopRecord may be retained as evidence but valid_for_region=false,
plus unresolved issue.

## C. Branching component
Any degree > 2.

Action:
DO NOT guess decomposition.
Emit stable unresolved issue:
`branching_component`

No auto chain/loop/region from that component in V1.8 base.

## D. Other malformed component
Examples:
- >2 degree-1 endpoints;
- disconnected inventory inconsistency;
- repeated edge traversal;
- impossible degree/edge relation.

Action:
`invalid_component`
No guessed region.

This conservative scope is intentional for the deadline and product trust.

---

# 7. OPEN CHAIN RECONSTRUCTION

Traversal:

1. choose lexicographically smaller terminal node;
2. follow the unique unused incident edge;
3. at each internal degree-2 node choose the unused continuation;
4. stop at opposite degree-1 terminal;
5. prove:
   - all component edges consumed exactly once;
   - no repeated internal node;
   - final node is expected second terminal.

Failure:
`chain_traversal_failed`
or
`repeated_vertex`

Length:
sum canonical edge geometric lengths derived from current world endpoints.

Never infer length from source historical coordinates when current canonical edge
world_endpoints are available.

---

# 8. CLOSED LOOP RECONSTRUCTION

Cycle traversal MUST prove:

- starts at deterministic min node;
- returns to start;
- consumes every component edge exactly once;
- consumes no edge twice;
- all node IDs except closure are unique;
- at least 3 unique vertices.

Failure reasons:
- `loop_traversal_failed`
- `repeated_vertex`
- `degenerate_loop`

Do not let SketchUp Face topology define loop truth.
The canonical graph defines topology.

---

# 9. PLANAR / GEOMETRY VALIDATION

V1.8 is a 2D CAD preparation stage.

Do NOT silently project arbitrary 3D geometry.

For a loop:
- collect current canonical/world vertex coordinates;
- validate finite x/y/z;
- determine Z range;
- compare with captured `coordinate_epsilon` (or graph-provided equivalent
  authority if available).

If Z range exceeds permitted verification epsilon:
- unresolved `non_planar_loop`;
- valid_for_region=false.

No automatic Z repair here.
That belongs upstream to V1.6.

XY signed area:
shoelace formula.

If abs(area) <= a defensible numerical threshold based on coordinate_epsilon /
finite coordinate scale:
- `degenerate_loop`;
- no region.

Pi must not invent a large product tolerance.
Use coordinate_epsilon for verification semantics and document exact formula in
tests.

---

# 10. SELF-INTERSECTION / REPEATED VERTEX

## 10.1 Repeated vertex

A simple loop must not revisit a canonical node before final closure.

A chain must not revisit an internal canonical node.

Flag:
`repeated_vertex`

## 10.2 Self intersection

For each valid topological loop, test non-adjacent segments.

Adjacent segments sharing their legitimate common endpoint are allowed.

Non-adjacent conflict:
- proper interior crossing;
- T-junction-like point-on-segment interior;
- collinear interior overlap.

Prefer reusing the existing pure V1.7 `SegmentConflict` where semantically
correct instead of duplicating another intersection implementation.

However:
- do not reinterpret normal adjacent loop corners as conflict;
- do not mutate V1.7 SegmentConflict behavior solely for V1.8 convenience.

Flag:
`self_intersection`

Self-intersecting loop:
`valid_for_region=false`.

Use bbox pruning so this is not naïvely expensive on large loops.

---

# 11. NESTED LOOPS / HOLES / REGIONS

Only loops with:
- valid_for_region=true;
- no self-intersection;
- no non-planarity;
- non-zero area;
participate.

Before containment classification:
- build loop XY bounding boxes;
- use bbox containment/intersection pruning.

Loop pairs that geometrically cross, overlap, or touch ambiguously:
- MUST NOT be interpreted as outer/hole;
- flag stable issue such as:
  - `loop_boundary_intersection`
  - `loop_boundary_touch`
- affected loops excluded from region relationship until unambiguous.

Containment rule:
- For candidate inner A and candidate container B:
  - bbox(A) must fit inside bbox(B) within epsilon;
  - no boundary intersection/touch;
  - vertices of A must classify consistently strictly inside B.
- Use deterministic point-in-polygon/ray-casting with explicit boundary
  detection and coordinate_epsilon handling.
- A boundary hit is NOT "inside"; it is ambiguous/touching.

Build containment parent:
the smallest-area valid containing loop.

Depth parity:
- even depth -> region outer;
- odd depth -> hole.

Each even-depth loop creates one RegionRecord.
Its immediate odd-depth children become hole_loop_ids.
Even-depth grandchildren become separate regions.

Area:
outer area minus immediate hole areas.

If result area <= numerical epsilon:
- region invalid/unresolved;
- no false READY region.

---

# 12. PROVENANCE

V1.8 MUST preserve V1.7 plural provenance.

Authority:
`source_occurrence_ids`

For ChainRecord/LoopRecord:
union all canonical edges' plural source_occurrence_ids,
sorted + unique.

For RegionRecord:
union outer + holes.

Do not treat a `gap_bridge` as if it existed in source CAD.

Its support provenance is inherited evidence from V1.7.
Keep `origin_kind` available in loop evidence if useful, but do not duplicate
the entire canonical edge contract inside every record.

At minimum tests MUST prove:
a repaired V1.7 loop containing one `gap_bridge` retains all supporting plural
source occurrence IDs through the V1.8 output.

---

# 13. LAYER INFORMATION

V1.8 does NOT assign semantic roles.

For each chain/loop/region:
- collect canonical edge layer_name values;
- normalize non-empty strings;
- sorted/uniq.

Mixed-layer structures are allowed as facts unless an upstream unresolved issue
says otherwise.

Do not infer:
- building;
- road;
- red line;
- plot boundary;
- landscape;
- curb.

Those are downstream semantics.

---

# 14. PERFORMANCE

Primary graph traversal should be O(V + E).

Avoid:
- all-edge pair scans for component finding;
- repeated whole-graph scans inside every traversal step.

Self-intersection can be worse than linear, but:
- exclude adjacent pairs;
- bbox prune segment pairs;
- stop early on first blocking conflict when only validity is needed.

Region containment:
- bbox prune loop pairs before polygon tests.

Minimum practical regression:
- long open chain;
- many independent rectangular loops;
- representative 1k+ edge graph;
- no obvious explosive behavior.

Do not spend tonight inventing a complex sweep-line algorithm unless actual
performance evidence proves the bounded implementation inadequate.

---

# 15. WORKING MODE RUNNER INTEGRATION

Add derived V1.8 runner state, e.g.:

`@structure_reconstruction_result`

Optional lazy-load flag:
`@structure_v18_loaded`

## 15.1 Reset / invalidation

Clear V1.8 result on:
- prepare;
- rebuild;
- discard;
- duplicate-repair mutation;
- planar-normalization apply;
- gap-repair apply;
- any transition to failed/stale current workspace.

Do not show old loops against changed geometry.

## 15.2 Compute entry point

Add:

`compute_structure_reconstruction`

Required order:

1. require V1.8 pure dependencies;
2. ensure current workspace/source/adapter exist;
3. require current workspace state == ready;
4. run existing `validate_host_state_consistency!` FIRST;
5. if stale:
   - fail closed;
   - clear V1.8 result;
   - surface stable `host_state_changed`;
   - no reconstruction from stale geometry;
6. get captured current tolerance using existing authority;
7. rebuild a FRESH CanonicalGeometryGraph from current workspace via the existing
   `rebuild_canonical_geometry_graph`;
8. run CanonicalStructureReconstructor on that graph;
9. cache JSON-safe immutable result;
10. return normal snapshot.

Important:

V1.8 MUST work even if the user never ran `检查间隙`.
Do not require `@topology_repair_canonical_graph` to already exist.

The canonical graph is rebuilt read-only from current workspace as needed.

No host operation.
No source mutation.
No derived host geometry mutation.

## 15.3 Snapshot

Add:

`structure_reconstruction`

Shape:

- computed
- state
- canonical_graph_digest
- digest
- metrics
- unresolved_issues
- optionally compact chains/loops/regions summaries

Do not dump megabytes of full coordinates into the default UI payload if not
needed. Keep detailed result internally/queryable while snapshot exposes enough
for UI and verification.

Metrics minimum:

- component_count
- open_chain_count
- closed_loop_count
- region_count
- hole_count
- invalid_component_count
- invalid_loop_count
- unresolved_issue_count

---

# 16. UI — SIMPLIFIED CHINESE

Add one compact block:

`轮廓与区域`

Primary button:

`检查结构`

States:

- `未检查`
- `结构可用`
- `存在需检查项`
- `检查失败`

Default visible metrics:

- `开放链：N`
- `闭合轮廓：N`
- `区域：N`
- `洞：N`
- `异常：N`

No "生成建筑", "生成道路", "场地边界" semantic wording.

No mandatory Face button in V1.8 base.

Optional advanced details may show:
- reconstruction digest;
- unresolved reason codes;
- component/loop IDs.

Keep them collapsed.

---

# 17. FACE PREVIEW DECISION

Master Plan calls face preview OPTIONAL.

For this implementation window:

`FACE_PREVIEW = DEFERRED_FROM_V1.8_BASE`

Reason:
- SketchUp Face creation introduces real host mutation;
- faces may split/merge edges;
- operation/Undo/discard/host-state reconciliation would need a new contract;
- not required for downstream logical region reconstruction;
- presentation value does not justify the regression risk today.

Pi MUST NOT add host Face generation unless AIPM issues a separate explicit
dispatch after base V1.8 is green.

---

# 18. ERROR / ISSUE CODES

Stable minimum V1.8 issue vocabulary:

Input / graph:
- `invalid_graph`
- `missing_node_reference`
- `duplicate_canonical_edge_id`
- `self_loop_edge`
- `upstream_topology_issue`

Component:
- `branching_component`
- `invalid_component`
- `chain_traversal_failed`
- `loop_traversal_failed`

Geometry:
- `repeated_vertex`
- `self_intersection`
- `non_planar_loop`
- `degenerate_loop`
- `loop_boundary_intersection`
- `loop_boundary_touch`

Region:
- `ambiguous_containment`
- `invalid_region`

Host state:
- reuse `host_state_changed`

Do not create dozens of overlapping reason codes.
If implementation discovers a materially missing category, add one clearly and
document it in report/tests.

---

# 19. TEST MATRIX — REQUIRED

Create focused V1.8 test file(s), e.g.:

`tests/test_v18_structure_reconstruction.rb`
`tests/test_v18_working_mode_integration.rb`

Required deterministic core cases:

V18-T01
single open polyline
→ 1 open chain, 0 loops, 0 regions.

V18-T02
simple rectangle
→ 0 open chains, 1 valid loop, 1 region, 0 holes.

V18-T03
simple triangle containing a canonical `gap_bridge`
→ 1 loop, 1 region;
plural provenance union survives.

V18-T04
outer rectangle + inner rectangle
→ 2 valid loops, 1 region, 1 hole.

V18-T05
three nested rectangles
→ 3 loops;
depth 0 outer region with one hole;
depth 2 island creates second region.

V18-T06
bow-tie/self-crossing closed topology
→ self_intersection;
0 valid regions from affected loop.

V18-T07
repeated canonical vertex / malformed cycle
→ repeated_vertex or invalid component;
no false region.

V18-T08
T/Y branching component
→ branching_component;
do not guess chain decomposition.

V18-T09
non-planar loop
→ non_planar_loop;
not region-valid.

V18-T10
touching / intersecting loop boundaries
→ unresolved;
no false hole relation.

V18-T11
forward/reverse/shuffled node + edge input ordering
→ exact-equal canonical V1.8 payload (excluding any explicitly non-semantic
timestamp, preferably none) + identical result digest.

V18-T12
source_occurrence_ids plural union deterministic sorted/uniq.

V18-T13
invalid graph missing node ref
→ FAILED / stable reason, no crash.

V18-T14
upstream unresolved topology issue propagation.

V18-T15
long chain / many loops performance smoke.

Integration:

V18-I01
prepare → compute_structure_reconstruction without running gap repair
→ works.

V18-I02
V1.7 gap apply → compute structure
→ reads current rebuilt graph and detects newly closed loop.

V18-I03
discard/rebuild clears stale V1.8 result.

V18-I04
native host invalidation seam
→ compute structure validates first and fails closed with `host_state_changed`.

V18-I05
no begin_operation / no host mutation from structure compute.

UI / package:
- DOM labels/state/counts/button;
- loader cold-load;
- RBZ smoke;
- no missing require;
- git diff --check.

Compatibility:
- preserve SketchUp 2017 / Ruby 2.2-compatible production syntax/APIs;
- no `Hash#compact`;
- no safe-navigation `&.`;
- no unsupported newer Enumerable/Hash convenience methods in production path;
- no pattern matching/new syntax.

---

# 20. REGRESSION GATE

Before AIPM review Pi must run fresh:

1. V1.8 focused core tests.
2. V1.8 runner integration tests.
3. V1.7 full suite.
4. V1.6 close-autodiscard regression.
5. V1.5 BLOCK-005 / relevant host-state regression.
6. full Ruby suite.
7. Node DOM test.
8. RBZ smoke.
9. git diff --check.

Rebuild RBZ after all production changes.

Report exact counts, not "all green" only.

---

# 21. AIPM / CODEX REVIEW RULE

Default:
AIPM source review only.

Codex is NOT mandatory if implementation stays inside this blueprint.

Escalate to Codex BEFORE Owner gate if Pi materially changes any of:

- CanonicalGeometryGraph V1.7 schema;
- canonical node/edge identity;
- V1.7 graph digest semantics;
- source/provenance authority;
- DerivedGeometryWorkspace ownership;
- native SketchUp mutation;
- host Face creation;
- Undo/Observer/reconciliation architecture;
- tolerance authority.

If none of those change:
no Codex gate.

---

# 22. OWNER GATE — TOMORROW MORNING

Keep Owner verification deliberately short.

Use real SketchUp 2020 + normal plugin UI.
Ruby Console may create fixtures, but no test hooks/reset_for_tests.

A. Rectangle
Expected:
- 开放链 0
- 闭合轮廓 1
- 区域 1
- 洞 0
- 异常 0

B. Open polyline
Expected:
- 开放链 1
- 闭合轮廓 0
- 区域 0

C. Outer + inner rectangle
Expected:
- 闭合轮廓 2
- 区域 1
- 洞 1

D. Repaired V1.7 triangle
Flow:
- Prepare
- 检查间隙
- 修复间隙
- 检查结构

Expected:
- repaired loop recognized as 1 closed loop / 1 region;
- Source remains untouched by the existing V1.7 contract.

If these representative cases behave correctly and AIPM source review + full
regression are green, Owner may close V1.8 for the presentation milestone.

Do not expand tomorrow's morning gate into a multi-hour geometry certification.

---

# 23. DELIVERY PLAN / TIMEBOX

TODAY:
- implement pure reconstructor + records;
- integrate WorkingModeRunner;
- integrate compact UI;
- focused tests;
- full regression;
- build RBZ;
- Pi report;
- AIPM source review if time remains.

TOMORROW MORNING:
- finish at most one AIPM correction round if required;
- fresh full regression;
- RBZ;
- short Owner A-D real-host verification;
- freeze demo build.

TOMORROW AFTERNOON:
- PPT / demo preparation.

STOP CONDITIONS TONIGHT:
If V1.8 starts requiring:
- canonical graph redesign;
- host face mutation;
- new tolerance product design;
- broad V1.7 rewrite;
- Observer architecture;
- multi-stage region solver redesign;

STOP that subproblem and preserve the finished subset.
Do not endanger the stable V1.7 demo build.

---

# 24. DEFINITION OF DONE

V1.8 is done when:

- separate deterministic V1.8 reconstruction result exists;
- no CanonicalGeometryGraph schema redesign;
- simple chains reconstruct correctly;
- simple loops reconstruct correctly;
- nested loops create deterministic outer/hole regions;
- invalid/branch/self-intersecting/non-planar structures fail conservatively;
- plural provenance survives;
- runner computes from current graph without host mutation;
- stale host state fails closed;
- UI reports clear Chinese structure counts;
- V1.7 regressions remain green;
- RBZ builds;
- AIPM source review passes;
- Owner representative real-host gate is accepted.

Face preview is NOT required.

PreparedCadDataset is NOT V1.8.
That remains V1.9.

END
