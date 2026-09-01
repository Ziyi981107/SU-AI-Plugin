# AIPM STAGE TECHNICAL BLUEPRINT — V1.7

PROJECT: SU-AI-Plugin
STAGE: V1.7 — Endpoint / Gap Repair + Canonical Topology
DATE: 2026-09-01
STATUS: FROZEN FOR IMPLEMENTATION
DESIGN OWNER: AIPM
FINAL PRODUCT OWNER: Owner
IMPLEMENTATION AGENT: Pi
MANDATORY INTEGRATION REVIEW: CODEX xHigh
SCOPE: CAD preparation only

# 0. OWNER SUMMARY

V1.7 is the first stage where the plugin should visibly repair broken 2D CAD
connectivity.

Primary Owner demo:

draw/import an almost-closed triangle
→ 准备处理
→ 检查间隙
→ plugin says `发现 1 个可安全修复的间隙`
→ 修复间隙
→ a derived repair bridge visibly closes the gap
→ canonical topology reports the previously open chain as connected
→ Source CAD remains untouched.

If one endpoint has multiple plausible destinations, V1.7 must NOT guess.

This stage must remain lean.

V1.7 is NOT:
- a generic CAD healing kernel;
- face/region reconstruction;
- semantic recognition;
- endpoint-to-edge auto-healing;
- arbitrary line extension;
- V1.8 loop/region reconstruction;
- AI / MCP / Agent work.

# 1. SOURCE / PRODUCT AUTHORITY

The durable Master Plan requires V1.7 to provide:

- canonical nodes;
- tolerance-aware endpoint clustering;
- adjacency rebuild;
- conservative gap proposal/repair;
- branch/crossing safety;
- deterministic semantics/tie-breaks;
- canonical edge provenance;
- repair/discard/recovery;
- real-scale performance.

Hard rule:

> Endpoint proximity is only a candidate signal, not proof of intended
> connection.

Project risk rules additionally require:

- source CAD immutable;
- host topology is not automatically canonical topology;
- ambiguous gaps remain reviewable/unchanged;
- tolerance, identity, transforms and provenance are explicit;
- V1.7 receives a mandatory Codex xHigh integration review.

# 2. EXTERNAL TECHNICAL EVIDENCE

## 2.1 Mature functional analogue — ThomThom Edge Tools²

Edge Tools² explicitly targets DWG import cleanup where edges do not quite line
up.

Its gap workflow:

- finds open-end vertices;
- searches candidate projected vertices / edges / open vertices;
- applies a user-defined tolerance;
- creates repair line geometry;
- wraps mutation in a SketchUp native operation;
- rescans current geometry after repair.

The mature implementation demonstrates a useful host principle:

> close a geometric gap by adding explicit repair geometry rather than
> reconstructing an extension's own private Undo history.

V1.7 adopts the conservative part of this principle, but intentionally supports
a smaller repair subset than Edge Tools².

## 2.2 Official SketchUp host behavior

SketchUp `Entities#add_line` / `add_edges` are long-standing APIs and behave
similarly to native SketchUp drawing tools, including geometry merge/split
behavior.

`Sketchup::Edge`, `Vertex`, `Edge#split`, `Edge#faces`, and `Edge#curve` are
available in the old host baseline.

However the SU-AI-Plugin derived architecture commonly represents repaired/
derived source occurrences in separate root-level derived groups.

Therefore:

> V1.7 correctness MUST NOT depend on SketchUp physically welding different
> derived groups into one host topology.

The canonical graph is the product topology.
SketchUp geometry is host/render evidence.

# 3. KEY ARCHITECTURAL DECISION

V1.7 separates THREE concepts that must never be conflated:

## A. Host Vertex

A SketchUp implementation object inside some derived group/context.

Not canonical identity.

## B. Gap Candidate Neighborhood

Tolerance-based search around an open endpoint.

Purpose:
candidate discovery only.

Membership within `gap_search` does NOT merge identity.

## C. Canonical Node

A deterministic logical topology node generated from current DERIVED geometry.

Canonical nodes use the much tighter `coordinate_epsilon` equivalence contract,
not `gap_search`.

This distinction is mandatory.

Do NOT implement:

`within gap_search -> same canonical node`

That would turn proximity into identity and violate the Master Plan hard rule.

# 4. V1.7 EXECUTABLE REPAIR TYPE

V1.7 base supports ONE destructive topology repair type:

`endpoint_bridge`

Meaning:

two distinct open endpoints
→ conservative evidence proves one unambiguous pair
→ add one explicit DERIVED repair connector between their current world
   coordinates
→ rebuild canonical topology.

V1.7 does NOT move existing endpoint vertices.

V1.7 does NOT:
- snap two existing host vertices to a midpoint;
- extend an endpoint to an edge;
- project an endpoint to an arbitrary line;
- split a target edge for T-junction healing;
- extend two lines to their theoretical intersection;
- explode curves to make repair easier.

Why:

Adding a derived repair connector:
- minimizes distortion;
- preserves all existing derived edge coordinates;
- preserves raw/source provenance;
- is visually inspectable;
- is easy to undo/discard;
- matches mature SketchUp gap-repair practice;
- avoids requiring cross-group physical vertex welding;
- gives V1.8 an explicit canonical edge with repair provenance.

Future V1.7.x may widen repair types only after V1.7 base closure and new
evidence.

# 5. TOLERANCE CONTRACT

Reuse existing tolerance concepts.

Existing:

`gap_search`
- candidate discovery radius;
- may over-return candidate neighborhoods.

`coordinate_epsilon`
- canonical coordinate equivalence / verification epsilon;
- NOT a repair search tolerance.

Do NOT reuse:
- duplicate tolerance;
- short-edge threshold;
- planar_z_snap;
as gap-repair authority.

V1.7 base does NOT add another gap tolerance unless implementation evidence
proves a separate execution threshold is materially required.

Reason:

The repair is already gated by conservative structural evidence + explicit user
approval.

If Pi discovers that `gap_search` cannot safely serve as the maximum repair
radius without a second value:

STOP the tolerance-design subitem and request AIPM decision.
Do not invent a new default silently.

All tolerance values remain captured in ExecutionConfigSnapshot.

# 6. INPUT TOPOLOGY SNAPSHOT

V1.7 analysis runs on the CURRENT DerivedGeometryWorkspace after any V1.5/V1.6
operations.

Create a pure logical snapshot of current derived edges in world/model
coordinates.

Each `EndpointRecord` conceptually contains:

- endpoint_key;
- derived_edge_id;
- endpoint_role (start/end or stable equivalent);
- world_coordinate;
- owner/context identity;
- layer/source-layer identity where available;
- source occurrence identity/provenance;
- incident derived edge IDs;
- host handle reference only in the host execution layer;
- curve membership evidence;
- face adjacency evidence.

Each `DerivedEdgeRecord` conceptually contains:

- derived_edge_id;
- endpoint A key;
- endpoint B key;
- world coordinates;
- source provenance;
- layer/context evidence;
- origin_kind:
  - source_derived
  - duplicate_repair_survivor/current derived
  - generated_gap_bridge
- repair_action_id if generated.

Pure candidate/topology code must not directly mutate SketchUp.

# 7. CANONICAL NODE CONTRACT

## 7.1 Coordinate equivalence

Two endpoint records may share one CanonicalNode only when their actual current
world coordinates directly match within `coordinate_epsilon`.

Do not use transitive union blindly.

Example:

A≈B
B≈C
A !≈ C

must NOT silently become one canonical node.

## 7.2 Non-transitive safeguard

Build direct pairwise coordinate-match relationships using spatial bucketing.

For each connected candidate component:

- if every pair directly matches within `coordinate_epsilon`:
  create one canonical node;
- otherwise:
  mark `non_transitive_node_cluster`;
  do not collapse the component into one identity;
  keep deterministic separate node records / unresolved topology evidence.

## 7.3 Canonical node ID

Canonical node IDs must be deterministic for an unchanged derived snapshot.

Preferred inputs:

- schema/version;
- sorted stable endpoint membership keys;
- deterministic representative coordinate.

Do not use:
- Ruby object_id;
- array iteration order;
- random UUID;
- current SketchUp Entity object identity alone.

Persistent ID may be recorded as host evidence where available but is NOT the
canonical-node correctness source.

# 8. OPEN ENDPOINT CONTRACT

Canonical node degree is computed from canonical current derived edges.

An `open endpoint` candidate node for V1.7 executable gap repair must:

- have canonical degree exactly 1 before repair;
- belong to one ordinary eligible derived edge;
- have valid current provenance;
- have finite world coordinates;
- not be part of an unresolved non-transitive canonical-node cluster.

Do not infer open/closed state from host-group vertex degree alone.

Because separate derived groups may make every host vertex appear locally
degree 1, canonical adjacency is the authoritative V1.7 degree.

# 9. GAP CANDIDATE DISCOVERY

Use a spatial bucket/grid/hash.

Target complexity:
O(V + K) expected for endpoint candidate discovery, where K is nearby candidate
pairs.

No whole-drawing O(V²) scan.

For each open canonical endpoint A:

find endpoint B candidates satisfying all basic filters:

1. B != A.
2. Different incident derived edge.
3. Finite coordinates.
4. Direct 3D distance:
   `coordinate_epsilon < distance(A,B) <= gap_search`.
5. Z compatibility:
   `abs(A.z - B.z) <= coordinate_epsilon`
   for executable endpoint_bridge.
6. Both endpoint contexts are eligible for the derived repair workflow.
7. Neither endpoint belongs to Curve/Arc-owned geometry for auto repair.
8. Neither endpoint has Face adjacency that makes bridge intent uncertain.
9. Candidate is not already represented by an existing canonical edge.

Candidates failing the strict executable filters may be retained as
`REVIEW_REQUIRED` evidence, but must not be executable.

# 10. HIGH-CONFIDENCE PAIRING RULE

Proximity is not enough.

An endpoint_bridge is `READY_TO_REPAIR` only if:

## 10.1 Mutual unique candidate

A has exactly ONE executable endpoint candidate within `gap_search`: B.

B has exactly ONE executable endpoint candidate within `gap_search`: A.

This is deliberately stricter than nearest-neighbor ranking.

If A has B and C:
- no auto repair for A;
- report ambiguous neighborhood.

If B has A and D:
- no auto repair.

No global optimization/matching algorithm is required in V1.7 base.

## 10.2 Layer evidence

If both endpoints have known source-layer identities and they differ:

default:
`REVIEW_REQUIRED`.

V1.7 base does not auto-connect clearly cross-layer geometry.

If layer identity is missing/unknown:
do not fabricate certainty;
retain the structural evidence and classify conservatively.

AIPM allows implementation to treat both-unknown as executable ONLY if the
existing source pipeline cannot supply stable layer identity and all other
high-confidence rules pass. This choice must be explicit in the Pi report.

## 10.3 Crossing / branch safety

The proposed bridge segment must not:

- intersect an unrelated canonical edge in its interior;
- pass through an unrelated canonical node;
- create an implicit T-junction;
- require splitting an existing edge;
- cross another simultaneously proposed bridge.

Intersection at its own two target endpoints is allowed.

If any conflict exists:
`REVIEW_REQUIRED`, stable reason such as:
- `bridge_crossing`
- `third_node_on_bridge`
- `bridge_conflict`

## 10.4 No same-edge self repair

Never connect the two endpoints of the same existing edge as a gap repair.

## 10.5 Determinism

All endpoint/candidate iteration and reporting uses stable sorted keys.

When multiple ambiguous candidates exist:
sort for presentation by:
1. distance;
2. stable endpoint key.

Sorting is for deterministic evidence only.
It must NOT convert ambiguity into execution authority.

# 11. GAP PROPOSAL DATA CONTRACT

A `GapRepairProposal` conceptually contains:

- proposal_id;
- action_type = `endpoint_bridge`;
- endpoint_a_key;
- endpoint_b_key;
- canonical_node_a_id;
- canonical_node_b_id;
- distance;
- gap_search tolerance used;
- coordinate_epsilon used;
- layer evidence;
- crossing-check result;
- incident derived edge IDs;
- incident source occurrence IDs;
- expected bridge world endpoints;
- expected bridge length;
- confidence/state;
- reason;
- executable boolean.

Deterministic `proposal_id` should derive from stable pair keys + captured
config/schema, not random UUID.

States:

- READY_TO_REPAIR
- REVIEW_REQUIRED
- NO_CANDIDATE
- APPLIED
- FAILED

# 12. HOST MUTATION MODEL

## 12.1 Workspace-owned repair geometry

Do NOT attempt to weld vertices across separate derived source groups.

Create gap bridge geometry in workspace-owned DERIVED repair geometry.

Preferred:

one dedicated V1.7 repair group owned by the current DerivedGeometryWorkspace,
at model root with identity/world-coordinate semantics compatible with the
existing workspace.

All generated bridge edges belong to this transient derived repair group.

The repair group/handles must be included in:

- workspace handle registry;
- discard cleanup;
- rebuild cleanup;
- close-time auto-discard;
- host-state consistency validation.

## 12.2 Add-line primitive

For each approved endpoint_bridge:

create one line from exact endpoint A world coordinate to exact endpoint B world
coordinate using the old-host-compatible SketchUp edge creation path.

Do not move existing source-derived endpoints.

Because the connector lives in a dedicated repair group:

- it cannot accidentally weld/split source-derived groups;
- it does not create a face with source-derived edges merely by completing a
  visual loop across different groups;
- it remains clearly generated derived geometry;
- provenance is explicit.

If current workspace architecture already provides a safer equivalent owned
repair-geometry container, reuse it instead of inventing a second container.

## 12.3 One native operation

Applying one batch of safe proposals:

preflight all
→ start ONE SketchUp native operation
→ create all approved bridge edges
→ hard post-validate
→ commit

Any uncertain preflight:
no begin_operation.

If mutation fails before commit:
use existing abort/fail-closed semantics.

If commit result is uncertain:
workspace FAILED;
do not claim rollback success without evidence.

# 13. PREFLIGHT BEFORE DESTRUCTIVE APPLY

Before host operation prove:

- workspace state READY;
- existing host consistency validation passes;
- proposal/config belong to current workspace snapshot;
- all referenced current derived handles valid;
- source fingerprint unchanged;
- proposals are pairwise endpoint-disjoint;
- no proposal is REVIEW_REQUIRED;
- no bridge crossing/third-node conflict;
- bridge coordinates finite;
- bridge length within:
  `(coordinate_epsilon, gap_search]`;
- repair group ownership/context is valid;
- expected post-state is computed.

If any proof fails:
do not start host operation.

# 14. POST-VALIDATION

Before publishing APPLIED:

For every bridge:

- created handle exists and is valid;
- created edge endpoints match expected world positions within
  `coordinate_epsilon`;
- bridge length matches expected distance within verification epsilon;
- bridge belongs to the workspace-owned repair geometry;
- bridge provenance/action ID is recorded.

Global proof:

- source fingerprint unchanged;
- existing source-derived edge endpoint coordinates unchanged;
- applied bridge count exactly equals expected executable proposal count;
- no skipped/review-required proposal was created;
- canonical graph rebuild succeeds;
- each applied bridge appears as one canonical edge;
- the two repaired endpoint nodes each gain exactly one expected adjacency;
- open endpoint count decreases by 2 per independent applied bridge, unless
  coordinate-epsilon canonical merging already made that endpoint non-open;
- no new unresolved non-transitive canonical-node error is introduced.

If validation fails:
workspace must not claim READY/APPLIED truth.

# 15. CANONICAL GEOMETRY GRAPH

V1.7 introduces the first durable `CanonicalGeometryGraph`.

This is a logical immutable snapshot derived from CURRENT derived geometry.

It must not be a live mirror that relies on SketchUp observer replay.

Conceptually:

CanonicalGeometryGraph
- schema_version
- source_snapshot_id
- execution_config_digest
- nodes
- edges
- adjacency
- unresolved_topology_issues
- metrics
- provenance_digest / reproducibility metadata as appropriate

## 15.1 CanonicalEdge

Each canonical edge has:

- canonical_edge_id;
- node_a_id;
- node_b_id;
- origin_kind;
- current derived ID / generated repair ID;
- source occurrence provenance;
- repair_action_id if generated;
- current world endpoint coordinates;
- layer provenance;
- unresolved flags.

For a gap bridge:

`origin_kind = gap_bridge`

Its source provenance is SUPPORT evidence from the two incident source-derived
edges, not a claim that the bridge existed in source CAD.

## 15.2 Adjacency

Adjacency is rebuilt deterministically from canonical edges after:

- Prepare/Rebuild;
- V1.5 duplicate repair;
- V1.6 normalization apply;
- V1.7 gap repair apply.

Do NOT incrementally patch adjacency from assumed host events as the only truth.

Recompute from current workspace state.

## 15.3 V1.8 boundary

V1.7 stops at nodes + edges + adjacency + topology issues.

Do NOT construct:

- polylines/chains as final products;
- closed loops;
- holes;
- regions;
- faces;
- site semantics.

Those are V1.8.

# 16. PROVENANCE

Gap repair is generated geometry and must be traceable.

For each applied bridge record:

- proposal/action ID;
- endpoint canonical node IDs;
- incident derived edge IDs;
- supporting source occurrence IDs;
- original endpoint world coordinates;
- bridge length;
- tolerances used;
- layer evidence;
- crossing-check result;
- apply status;
- generated derived edge ID/handle identity;
- canonical edge ID.

Do not overwrite raw SourceSnapshot geometry.

Do not claim the generated bridge is source CAD.

# 17. UI — SIMPLIFIED CHINESE

Keep the V1.6 UX philosophy.

Normal user should see a compact new block:

`拓扑修复`

Possible states:

- `未检查`
- `发现可修复间隙`
- `需要人工确认`
- `无需修复`
- `已修复`
- `修复失败`

Primary flow:

workspace ready
→ `检查间隙`

If safe proposals exist:
→ `发现可修复间隙`
→ `修复间隙`

ambiguous:
→ `需要人工确认`
→ no destructive CTA for ambiguous items.

Default visible information:

- `开放端点：N`
- `可安全修复：N`
- `需人工确认：N`
- optionally `最大间隙：...`

After apply:

- `已修复间隙：N`
- `剩余开放端点：N`
- `需人工确认：N`

Technical details collapsed:

- proposal IDs;
- endpoint keys;
- canonical node IDs;
- raw distances;
- raw tolerance values;
- crossing reason codes;
- layer IDs;
- provenance IDs;
- canonical graph raw metrics.

No per-gap checkbox UI in V1.7 base.

Batch button applies only READY_TO_REPAIR proposals.
Review-required proposals remain unchanged.

# 18. TEST MATRIX

## 18.1 Canonical node / identity

N1 exact same world coordinate across separate derived groups
→ one canonical node.

N2 within coordinate_epsilon complete clique
→ one canonical node.

N3 outside coordinate_epsilon
→ separate nodes.

N4 non-transitive A≈B, B≈C, A!≈C
→ must NOT collapse all three;
→ unresolved `non_transitive_node_cluster`.

N5 deterministic graph rebuild
→ same unchanged input produces same logical IDs/adjacency.

N6 random Ruby/host iteration order
→ canonical output unchanged.

## 18.2 Gap candidate / pairing

G1 one simple endpoint pair within gap_search
→ READY_TO_REPAIR.

G2 distance > gap_search
→ no executable proposal.

G3 distance <= coordinate_epsilon
→ canonical equivalence/no bridge needed.

G4 A has two candidate endpoints
→ REVIEW_REQUIRED, no execution.

G5 mutual uniqueness fails on B
→ REVIEW_REQUIRED.

G6 known cross-layer endpoints
→ REVIEW_REQUIRED.

G7 significant Z mismatch
→ REVIEW_REQUIRED/no execution.

G8 same edge endpoints
→ no repair.

G9 Curve/Arc incident endpoint
→ no auto repair.

G10 Face-adjacent incident geometry
→ no auto repair.

## 18.3 Branch / crossing

X1 proposed bridge intersects unrelated edge interior
→ REVIEW_REQUIRED.

X2 third canonical node lies on bridge
→ REVIEW_REQUIRED.

X3 two proposed bridges cross
→ conflicting proposals not executable.

X4 triangle missing one short closing segment
→ READY_TO_REPAIR.

## 18.4 Host mutation

H1 invalid preflight
→ zero begin_operation.

H2 one safe bridge
→ one operation, one generated derived edge, commit.

H3 multiple independent safe bridges
→ one batch operation, exact bridge count.

H4 add-line failure
→ abort/fail closed, no false APPLIED.

H5 commit uncertainty
→ FAILED, no fake rollback claim.

H6 post-state mismatch
→ FAILED.

H7 source fingerprint unchanged.

H8 existing derived source-edge coordinates unchanged.

## 18.5 Canonical topology after repair

T1 bridge becomes canonical edge with `origin_kind=gap_bridge`.

T2 bridge carries repair/source-support provenance.

T3 repaired endpoints gain expected adjacency.

T4 simple almost-closed triangle becomes canonical connected cycle-capable
topology input for V1.8 (V1.7 does not construct the final loop object).

T5 review-required gaps remain absent from canonical generated edges.

T6 discard removes bridges and rebuilt graph returns to pre-repair derived truth.

T7 rebuild regenerates candidate proposals deterministically.

## 18.6 Undo / lifecycle

L1 native SketchUp Undo after applied gap repair
→ next interaction uses existing host-state consistency validation
→ no stale generated bridge handles used
→ safe failed/stale state.

L2 explicit Discard removes repair group + graph state.

L3 dialog close auto-discard removes repair group + graph state.

L4 reopen begins clean `准备处理`.

## 18.7 Performance

P1 synthetic 1k edges.
P2 synthetic 10k edges if existing harness permits reasonable runtime.
P3 candidate discovery proves it does not use global O(V²) pair enumeration.

Do not add a complex spatial index beyond a simple grid/hash unless measured
evidence requires it.

# 19. OWNER REAL-HOST ACCEPTANCE

Real SketchUp 2020 is required.

Owner test helpers may create source geometry from Ruby Console, but the actual
plugin workflow must use production Chinese UI.

## Scenario A — Missing triangle segment

Almost-closed triangle with two open endpoints forming one small unique pair.

Expected:

- 准备处理
- 检查间隙
- `可安全修复：1`
- 修复间隙
- visible derived connector appears
- source unchanged
- remaining open endpoints reflect repaired topology.

## Scenario B — Ambiguous fork

One open endpoint has two plausible open endpoints inside gap_search.

Expected:

- 需要人工确认
- no destructive repair for that ambiguous proposal
- no derived connector.

## Scenario C — Too far

Gap beyond tolerance.

Expected:
no repair proposal.

## Scenario D — Cross-layer

Known different source layers.

Expected:
review required / no auto repair.

## Scenario E — Crossing blocker

A proposed bridge would cross another unrelated edge.

Expected:
review required / no bridge.

## Scenario F — Undo

Apply one safe bridge
→ native SketchUp Undo
→ next plugin interaction
→ safe host-state invalidation/recovery; no stale bridge use.

## Scenario G — Discard / close

Apply bridge
→ Discard or close dialog
→ generated repair geometry removed
→ source unchanged
→ reopen clean.

# 20. MANDATORY CODEX xHigh INTEGRATION REVIEW

After Pi implementation and AIPM primary source review, but BEFORE V1.7 Owner
closure:

Codex xHigh MUST review the integrated V1.7 implementation.

Review scope:

- tolerance semantics;
- non-transitive canonical node clustering;
- candidate pairing ambiguity;
- world/local transforms;
- source occurrence identity;
- generated bridge provenance;
- canonical graph determinism;
- branch/crossing safety;
- host operation / failure / post-validation;
- Undo/discard/rebuild/close lifecycle;
- source immutability;
- package/runtime;
- downstream V1.8 correctness boundary.

Codex must NOT:
- redesign product scope;
- start V1.8;
- create extra review gates after a PASS without new evidence;
- require speculative topology features outside this Blueprint.

# 21. IMPLEMENTATION ORDER

Pi should implement one coherent V1.7 packet:

1. pure endpoint/canonical topology data records;
2. coordinate-epsilon canonical-node builder + non-transitive safety;
3. spatial gap candidate retrieval;
4. mutual-unique conservative proposer;
5. crossing/third-node/pair-conflict checks;
6. canonical graph + deterministic IDs/provenance;
7. WorkingModeRunner proposal lifecycle;
8. Chinese `拓扑修复` UI + `检查间隙` / `修复间隙`;
9. workspace-owned repair geometry adapter;
10. batch add-line execution;
11. post-validation + graph rebuild;
12. Undo/discard/rebuild/close integration;
13. performance/regression/package evidence;
14. Owner-test RBZ;
15. STOP for AIPM review.

Do not split into many micro-dispatches unless an actual BLOCK requires a design
decision.

# 22. STOP / ESCALATION CONDITIONS

Pi continues through ordinary implementation/debug/test work.

STOP affected work and request AIPM if:

- gap repair requires source mutation;
- current derived workspace cannot own generated repair geometry safely;
- a new transaction/Undo architecture appears necessary;
- cross-group transforms invalidate the world-coordinate contract;
- canonical node identity cannot preserve source occurrence provenance;
- `gap_search` demonstrably needs a separate execution tolerance;
- a safe bridge cannot be represented without mutating existing source-derived
  endpoints;
- host face/split side effects cannot be isolated by workspace-owned repair
  geometry;
- performance requires a materially new spatial architecture;
- implementation would require V1.8 loop/region semantics.

Do not stop for routine multi-file work or test iteration.

# 23. DEFINITION OF PI COMPLETE

Pi implementation is ready for AIPM source review when:

- V1.6 remains closed;
- V1.7 canonical graph exists;
- canonical node identity is deterministic and non-transitive-safe;
- candidate discovery is tolerance-aware and scalable;
- proximity alone never creates an executable repair;
- one unique mutual endpoint pair can produce endpoint_bridge proposal;
- ambiguous/cross-layer/crossing cases fail conservatively;
- repair geometry is derived/workspace-owned;
- existing derived/source coordinates are not moved;
- Source CAD is unchanged;
- generated bridge provenance is explicit;
- canonical adjacency rebuilds from current derived truth;
- V1.6 close auto-discard still works;
- Undo safety uses existing host consistency architecture;
- Simplified Chinese V1.7 UI is usable;
- full regressions pass;
- RBZ candidate is built/verified;
- Owner scenarios are documented but NOT claimed PASS;
- V1.7 is NOT marked CLOSED;
- Codex review is NOT self-invoked by Pi;
- Pi reports the exact packet and STOPs.

END
