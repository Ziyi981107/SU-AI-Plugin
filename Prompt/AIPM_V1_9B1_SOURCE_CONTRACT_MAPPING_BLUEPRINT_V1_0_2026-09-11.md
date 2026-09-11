# SU-AI-Plugin — V1.9B1 PreparedCadDataset
# Source Contract Mapping + Implementation-Ready Blueprint v1.0

Date: 2026-09-11
Planning / Technical Design Owner: AIPM / ChatGPT
Final Product Owner: Owner
Implementation Agent: Pi
Technical Reviewer: Codex xHigh (pre-build narrow review recommended; final V1.x review mandatory)
Repository baseline: dev/v1.9 @ 839097a49b1bca3002beaa2f442a52f8db47e36e

Status:
- V1.9A = CLOSED_FROZEN
- V1.9B0 = CLOSED / OWNER PASS
- AttributeDictionary persistence route = ACCEPTED_FOR_B1_B2
- verified persistence envelope = <= 8 MiB on real SketchUp 2020
- V1.9B1 = PLANNING_FROZEN_BY_THIS_BLUEPRINT / NOT YET IMPLEMENTED
- V1.9B2 = NOT STARTED
- V2 / MCP / LLM / Agent = NOT STARTED

---

## 0. Owner Summary

V1.9B1 is the durable contract boundary between the deterministic V1 CAD-preparation pipeline and future V2 site modeling.

B1 has exactly three product responsibilities:

1. `PreparedCadDataset` — immutable, JSON-safe, versioned handoff data.
2. `PreparedCadDatasetBuilder` — deterministic projection from current authoritative V1 outputs into that handoff contract.
3. `PreparedCadDatasetValidator` — deterministic readiness decision:
   `NOT_READY | READY_WITH_WARNINGS | READY`.

B1 does not persist or accept the dataset. B2 owns user Accept, warning acknowledgement, AttributeDictionary persistence, reload, replacement, stale handling, and final UI.

The dataset MUST NOT be a raw dump of V1 internal objects. It normalizes V1 outputs so V2 only depends on one stable contract.

---

# 1. Source-Contract Mapping — Current Production Facts

## 1.1 SourceSnapshot

Current source:
`extension/su_ai_plugin/core/source_snapshot.rb`

Exact relevant fields:

- `snapshot_id`
- `schema_version` (`1`)
- `captured_at`
- `selection_scope`
- `selection_scope_digest`
- `edges`
- `faces`
- `layers`
- `vertex_records`
- `unit` (current factory: `inches`)
- `coordinate_origin` (current factory: `raw`)
- `transform_context`
- `fingerprint`
- `execution_config`

Important identity fact:

`SourceSnapshot.default_snapshot_id` uses time + SecureRandom/fallback time. Therefore `snapshot_id` is session/snapshot audit identity, NOT semantic content identity.

Decision:
- preserve `source_snapshot_id` as build evidence;
- do NOT include it in PreparedCadDataset content identity/digest.

Authoritative semantic source identity for B1:
- `source_fingerprint_digest`
- `selection_scope_digest`
- source schema
- normalized selection scope.

## 1.2 SourceFingerprint

Current source:
`extension/su_ai_plugin/core/source_fingerprint.rb`

Deterministic SHA-256 fingerprint covers source facts such as:
- edge count / edge-length sum;
- bounding box;
- face / face-vertex counts;
- group/component counts;
- layer facts;
- material digest;
- selection-scope digest.

Decision:
`SourceFingerprint#digest` is the primary existing V1 source-content fingerprint used in the B1 content contract.

## 1.3 ExecutionConfigSnapshot

Current source:
`extension/su_ai_plugin/core/execution_config_snapshot.rb`

Exact machine fields:

- `profile_id`
- `profile_version`
- `rule_set_id`
- `rule_set_version`
- `rule_set_digest`
- `tolerance_schema_version`
- `tolerance_values`
- `session_overrides`
- `source_snapshot_schema_version`
- `captured_at`

Critical finding:
the current class has no public `digest` implementation, while several legacy callers defensively check `respond_to?(:digest)`. Therefore the existing `execution_config_digest` may be empty and must NOT be assumed to be a durable identity.

Decision:
- DO NOT modify `ExecutionConfigSnapshot` merely to add a digest, because doing so would alter frozen V1.7/V1.8 digest behavior.
- B1 computes its own `execution_context_digest` over the normalized machine fields above, EXCLUDING `captured_at`.
- This B1 digest is local to the PreparedCadDataset contract and does not rewrite old V1 contracts.

## 1.4 Layer contract

Current source:
- `core/layer_record.rb`
- `core/layer_role.rb`

Machine fields available:
- `name`
- `id`
- `edge_count`
- `face_count`
- `faces_with_holes_count`
- `role`
- `role_rule`
- `visible`
- `visibility_unknown`

Current roles:
- `construction`
- `dimension`
- `annotation`
- `guide`
- `unknown`

Decision:
- `unknown` remains valid.
- visibility remains independent from role.
- B1 persists machine semantics, NOT localized UI labels.
- V1 uses layer names throughout canonical geometry; therefore B1 v1 uses normalized `layer_name` as the interoperability key.
- `LayerRecord.id` may be preserved as optional audit metadata but is not required for V2 referential integrity.
- source inventory counts may be omitted from the main handoff contract or retained only as non-authoritative summary data.

No road/building/green-space semantic roles are introduced.

## 1.5 WorkingModeRunner current state

Current source:
`core/working_mode_runner.rb`

JSON-safe snapshot contains:

- `state`
- `source_snapshot_id`
- `source_fingerprint_digest`
- `execution_config_digest`
- `workspace_id`
- `last_error`
- `entity_count`
- optional `duplicate_repair`
- `planar_normalization`
- `topology_repair`
- `structure_reconstruction`

Decision:
- `workspace_id` is session/working-state identity only.
- it MUST NOT participate in PreparedCadDataset semantic content identity.
- runner stage states are validation inputs, not V2 geometry.

## 1.6 CanonicalGeometryGraph

Current source:
`core/canonical_geometry_graph.rb`

Top-level published shape:
- `schema_version` (`cgg.v1`)
- `source_snapshot_id`
- `execution_config_digest`
- `workspace_id`
- `nodes`
- `edges`
- `adjacency`
- `unresolved_topology_issues`
- `metrics`
- `non_transitive_clusters`
- `open_endpoints`
- `built_at`
- `digest`
- `tolerance_digest`

Published logical node shape:
- `canonical_node_id`
- `endpoint_keys`
- `derived_edge_ids`
- `source_occurrence_ids`
- `layer_names`
- `world_coordinate`
- `resolved_clique`
- `coordinate_epsilon`
- `membership_count`

Published edge shape:
- `canonical_edge_id`
- `node_a_id`
- `node_b_id`
- `origin_kind`
- `derived_edge_id`
- legacy singular `source_occurrence_id`
- authoritative plural `source_occurrence_ids`
- `repair_action_id`
- `world_endpoints`
- `layer_name`
- `unresolved_flags`

Critical findings:

A. `workspace_id` is included in the current graph digest, while the runner creates random workspace IDs. Therefore `CanonicalGeometryGraph#digest` is useful as current-run evidence but is NOT suitable as the PreparedCadDataset semantic content identity across equivalent workspace rebuilds.

B. canonical nodes are built from the current topology endpoint coordinates and are the safest coordinate authority.

C. graph edge `world_endpoints` are built from `DerivedEntityRecord.geometry_summary`, which is build-time data and can become stale after a live derived-vertex Z repair. Therefore B1 MUST NOT carry `world_endpoints` forward as a second authoritative coordinate source.

Frozen B1 rule:

> **Node coordinates are the only authoritative geometry coordinates in PreparedCadDataset v1.**

Edges reference node IDs.

`CanonicalGeometryGraph#digest` is retained only as upstream build evidence, not as the B1 dataset identity.

## 1.7 V1.8 CanonicalStructureReconstructor

Current source:
`core/canonical_structure_reconstructor.rb`

Result top-level:
- `schema_version` (`csr.v1`)
- `state`
- `canonical_graph_digest`
- `source_snapshot_id`
- `workspace_id`
- `chains`
- `loops`
- `regions`
- `unresolved_issues`
- `metrics`
- `reasons`
- `digest`

Chain fields:
- `chain_id`
- `node_ids`
- `edge_ids`
- `start_node_id`
- `end_node_id`
- `closed`
- `length`
- `source_occurrence_ids`
- `layer_names`
- `unresolved_flags`
- `coordinate_epsilon`

Loop fields:
- `loop_id`
- `node_ids`
- `edge_ids`
- `world_coordinates`
- `closed`
- `perimeter`
- `signed_area_xy`
- `area_xy`
- `winding`
- `source_occurrence_ids`
- `layer_names`
- `unresolved_flags`
- `valid_for_region`
- `coordinate_epsilon`

Region fields:
- `region_id`
- `outer_loop_id`
- `hole_loop_ids`
- `area_xy`
- `perimeter_outer`
- `source_occurrence_ids`
- `layer_names`
- `unresolved_flags`

Critical identity fact:
V1.8 result digest incorporates the current canonical graph digest. Since the graph digest includes session `workspace_id`, V1.8 `digest` is also treated as current-run evidence rather than PreparedCadDataset semantic identity.

B1 projection rule:
- preserve structural IDs and references;
- drop `loop.world_coordinates` from the downstream contract because node coordinates are authoritative;
- keep existing numerical structure metrics only as explicitly non-authoritative derived metrics if included;
- V2 must be able to recompute geometry metrics from node coordinates + structure references.

For v1, the preferred minimal contract keeps:
- chain topology/provenance/flags;
- loop topology/provenance/flags/validity;
- region topology/provenance/flags;
and may include current V1.8 area/perimeter/winding under `derived_metrics`.

## 1.8 Initial IssueRegistry vs current unresolved state

Current `AnalysisResult.registry` is built at Analyze time. It contains historical/source findings and may retain issues that have since been repaired.

Canonical initial issue types include:
- `duplicate_edge_candidate`
- `short_edge`
- `open_endpoint`
- `gap_candidate`
- `significant_non_zero_z`
- `abnormal_large_coord`
- `deep_nesting`

V1.9A deliberately prevents repaired duplicate/Z/gap findings from continuing to count as current problems.

Decision:
B1 MUST NOT copy `AnalysisResult.registry` wholesale into `unresolved_issues`.

Current-issue synthesis uses:
- current Runner stage states/reasons;
- current V1.8 unresolved codes;
- only secondary source-registry classes that are not superseded by repair stages:
  - `short_edge`
  - `abnormal_large_coord`
  - `deep_nesting`

The following initial registry types are superseded by current deterministic stage state and are NOT copied as current unresolved records:
- `duplicate_edge_candidate`
- `significant_non_zero_z`
- `open_endpoint`
- `gap_candidate`

---

# 2. PreparedCadDataset v1 — Exact Contract Direction

Recommended top-level object:

```json
{
  "schema_version": "pcd.v1",
  "dataset_id": "pcd-...",
  "content_digest": "...",
  "content": {},
  "build_evidence": {},
  "validation": {}
}
```

## 2.1 Why split `content`, `build_evidence`, and `validation`

`content` is the stable semantic V2 handoff.

`build_evidence` records which V1 session/snapshot produced it and may contain non-semantic current-run IDs/digests.

`validation` records deterministic validation of a specific `content_digest`.

Only canonical `content` defines `content_digest` and `dataset_id`.

This prevents random `snapshot_id` / `workspace_id` / legacy upstream digest behavior from contaminating PreparedCadDataset semantic identity.

---

# 3. Canonical `content`

## 3.1 `source`

```json
{
  "source_schema_version": "1",
  "source_fingerprint_digest": "...",
  "selection_scope_digest": "...",
  "selection_scope": []
}
```

Normalized selection-scope entries:
- `kind`
- `persistent_id_path`
- `instance_path`
- `layer_name`

Sort deterministically.

Do NOT include transient Ruby `entity_id` / `object_id`.

## 3.2 `execution`

```json
{
  "profile_id": "...",
  "profile_version": "...",
  "rule_set_id": "...",
  "rule_set_version": "...",
  "rule_set_digest": "...",
  "tolerance_schema_version": "...",
  "tolerance_values": {},
  "session_overrides": {},
  "execution_context_digest": "..."
}
```

`execution_context_digest` = SHA-256 of canonical JSON of the above machine data, excluding itself and excluding captured timestamps.

## 3.3 `coordinate_context`

```json
{
  "coordinate_space": "sketchup_model_world",
  "unit": "inches",
  "axes": ["x", "y", "z"],
  "source_coordinate_origin": "raw",
  "active_edit_context": {}
}
```

Rules:
- canonical node XYZ values are current model/world coordinates;
- V2 MUST NOT apply the captured active-edit transform again to node XYZ;
- active-edit transform/inverse/path are provenance/context only;
- no B1 unit conversion to mm.

## 3.4 `layer_semantics`

Each record:

```json
{
  "layer_name": "...",
  "role": "unknown",
  "role_rule": "...",
  "visible": true,
  "visibility_unknown": false
}
```

Sort by `layer_name`.

Localized labels are excluded.

## 3.5 `canonical_geometry`

```json
{
  "schema_version": "pcd-geometry.v1",
  "source_graph_schema_version": "cgg.v1",
  "coordinate_epsilon": 0.000001,
  "nodes": [],
  "edges": [],
  "adjacency": {}
}
```

### Node

```json
{
  "node_id": "...",
  "xyz": [0.0, 0.0, 0.0],
  "source_occurrence_ids": [],
  "layer_names": [],
  "resolved_clique": true,
  "membership_count": 1
}
```

May preserve `endpoint_keys` / `derived_edge_ids` under a clearly named provenance/debug sub-field, but V2 must not depend on them.

### Edge

```json
{
  "edge_id": "...",
  "node_a_id": "...",
  "node_b_id": "...",
  "origin_kind": "source_derived",
  "layer_name": null,
  "source_occurrence_ids": [],
  "repair_action_id": null,
  "unresolved_flags": []
}
```

Explicitly forbidden in PreparedCadDataset v1:
- `world_endpoints`
- live Vertex/Edge/Group handles
- Ruby object IDs
- legacy singular source occurrence identity as authority

Adjacency may be copied from the validated graph and canonicalized by key/value sort. Validator must verify adjacency references only known node IDs.

## 3.6 `structures`

```json
{
  "schema_version": "pcd-structures.v1",
  "source_structure_schema_version": "csr.v1",
  "chains": [],
  "loops": [],
  "regions": []
}
```

### Chain

Authoritative:
- `chain_id`
- `node_ids`
- `edge_ids`
- `start_node_id`
- `end_node_id`
- `closed`
- `source_occurrence_ids`
- `layer_names`
- `unresolved_flags`

Optional non-authoritative:
```json
"derived_metrics": {
  "length": 0.0
}
```

### Loop

Authoritative:
- `loop_id`
- `node_ids`
- `edge_ids`
- `closed`
- `source_occurrence_ids`
- `layer_names`
- `unresolved_flags`
- `valid_for_region`

Forbidden:
- `world_coordinates`

Optional non-authoritative:
```json
"derived_metrics": {
  "perimeter": 0.0,
  "signed_area_xy": 0.0,
  "area_xy": 0.0,
  "winding": "CCW"
}
```

### Region

Authoritative:
- `region_id`
- `outer_loop_id`
- `hole_loop_ids`
- `source_occurrence_ids`
- `layer_names`
- `unresolved_flags`

Optional non-authoritative:
```json
"derived_metrics": {
  "area_xy": 0.0,
  "perimeter_outer": 0.0
}
```

## 3.7 `repair_history`

Compact durable machine audit.

### Duplicate

Persist:
- summary counts;
- `tolerance_status`;
- per-action:
  - action_id
  - status
  - rule_id
  - confidence_basis
  - source_occurrence_ids
  - affected_derived_ids
  - survivor_derived_id
  - issue_ids

Do not blindly persist arbitrary legacy `before_summary` blobs.

### Planar

Persist from audit where present:
- rule_id / rule_version
- status / reason
- target_z
- captured_tolerance
- affected_derived_ids
- affected_source_occurrence_ids
- outlier_derived_ids
- before_z_summary / after_z_summary
- max_movement
- logical_applied_count
- physical_applied_count
- failed_count

### Gap

Persist from audit where present:
- status / reason
- applied_count / failed_count
- applied proposal IDs
- rule_id / rule_version / schema_version
- tolerance_used
- commit_completed

Do not persist wall-clock-like fields into canonical identity unless they are deterministic constants. `applied_at` is omitted from B1 content.

## 3.8 `unresolved_issues`

Machine-readable only.

Record shape:

```json
{
  "code": "...",
  "class": "blocker|warning",
  "source": "planar|gap|structure|source_registry|duplicate",
  "count": 1,
  "reason_codes": [],
  "entity_refs": []
}
```

No Chinese UI copy in the contract.

Current issue synthesis rules are in §6.

## 3.9 `provenance_summary`

At minimum:

```json
{
  "source_occurrence_count": 0,
  "stable_occurrence_count": 0,
  "transient_occurrence_count": 0,
  "has_transient_occurrences": false
}
```

Transient source occurrence IDs are valid snapshot provenance and do not automatically block readiness.

---

# 4. `build_evidence`

Non-semantic current-build evidence:

```json
{
  "source_snapshot_id": "...",
  "workspace_id": "...",
  "upstream_graph_digest": "...",
  "upstream_structure_digest": "...",
  "source_snapshot_captured_at": "...",
  "source_graph_schema_version": "cgg.v1",
  "source_structure_schema_version": "csr.v1"
}
```

Rules:
- excluded from `content_digest`;
- useful for audit/debug/current-session consistency;
- V2 must not use `workspace_id` as semantic identity.

---

# 5. Content Identity

Canonicalization rules:

1. all Hash keys serialized in deterministic sorted order by the B1 canonical serializer;
2. arrays whose semantic order is not meaningful are sorted by stable IDs/names;
3. arrays whose order IS meaningful stay ordered:
   - chain node/edge traversal order;
   - loop node/edge traversal order;
4. no timestamps/random IDs/session IDs in canonical `content`;
5. only finite Numeric coordinates;
6. no host objects;
7. SHA-256 over canonical JSON bytes of `content`.

Then:

```text
content_digest = SHA256(canonical_content_json)
dataset_id     = "pcd-" + first_20_hex(content_digest)
```

Same canonical content -> same canonical bytes -> same content digest -> same dataset ID.

Existing `CanonicalGeometryGraph#digest` and V1.8 `digest` are NOT reused as PreparedCadDataset identity because they contain current-run/session evidence.

---

# 6. Current-Issue Synthesis + Readiness

## 6.1 Duplicate stage

- duplicate stage missing/not run where normal V1.9A orchestration requires it -> blocker
- `actions_failed > 0` -> blocker
- `actions_skipped > 0` -> warning
- clean/applied with no failures -> no current blocker

## 6.2 Planar stage

- `NOT_COMPUTED` -> blocker
- `INVALID_TOLERANCE` / `FAILED` -> blocker
- `READY_TO_NORMALIZE` -> blocker (`planar_repair_pending`)
- `REVIEW_REQUIRED` -> warning
- `NO_CANDIDATE` / `APPLIED` -> no current planar issue

## 6.3 Gap/topology stage

- `NOT_COMPUTED` -> blocker
- `FAILED` -> blocker
- `READY_TO_REPAIR` -> blocker (`gap_repair_pending`)
- `REVIEW_REQUIRED` -> warning
- `NO_CANDIDATE` / `APPLIED` -> no current gap issue

## 6.4 Structure stage

- `NOT_COMPUTED` -> blocker
- `FAILED` -> blocker
- `READY_WITH_WARNINGS` -> warning(s) using existing `unresolved_issues` reason codes
- `READY` -> no structure blocker

Any schema/reference contradiction found by B1 validator remains a blocker even if upstream state says READY.

## 6.5 Source-registry secondary issues

Only current non-superseded source issue classes become B1 warnings:
- `short_edge`
- `abnormal_large_coord`
- `deep_nesting`

Historical:
- duplicate candidate
- non-zero-Z
- open endpoint
- gap candidate

are NOT copied as current issues; current stage state is authoritative for those problem families.

## 6.6 Persistence-envelope check

Canonical serialized PreparedCadDataset payload:
- `<= 8 MiB` -> current persistence capability verified by B0 Owner test;
- `> 8 MiB` -> blocker `persistence_envelope_unverified`.

This is an evidence boundary, not a claim that SketchUp necessarily fails above 8 MiB.

## 6.7 Readiness

```text
if blockers.any?:
    NOT_READY
elsif warnings.any?:
    READY_WITH_WARNINGS
else:
    READY
```

`READY` means V1's geometry/provenance contract is trustworthy.
It does NOT mean V2 architectural semantics are known.

---

# 7. PreparedCadDatasetValidator

Return:

```json
{
  "validator_version": "pcd-validator.v1",
  "validated_content_digest": "...",
  "readiness": "READY",
  "checks": [],
  "blockers": [],
  "warnings": [],
  "summary": {}
}
```

Minimum structural checks:

- schema version supported;
- source fingerprint present;
- execution context complete enough;
- unit/coordinate-space supported;
- node IDs unique;
- every node XYZ exactly 3 Numeric finite values;
- edge IDs unique;
- edge node refs exist;
- no prohibited `world_endpoints`;
- adjacency only references known nodes and is symmetric/consistent enough for handoff;
- chain IDs unique; all node/edge refs exist;
- loop IDs unique; all node/edge refs exist;
- no prohibited loop `world_coordinates`;
- region IDs unique; outer/hole loop refs exist;
- provenance IDs are strings and non-empty where required;
- no live SketchUp objects anywhere in serializable tree;
- current-stage readiness gates;
- canonical serializer repeatability;
- content digest recomputation matches;
- payload <= verified persistence envelope.

Validator does NOT infer site semantics.

---

# 8. Builder

Preferred pure API:

```ruby
PreparedCadDatasetBuilder.build(
  source_snapshot:,
  workflow_snapshot:,
  canonical_graph:,
  structure_result:,
  analysis_result:
)
```

Builder does not reach into global runner private ivars and does not call SketchUp.

Sequence:

```text
validate input object shapes
→ normalize source identity
→ normalize execution context
→ normalize coordinate context
→ normalize layers
→ project graph nodes
→ project graph edges WITHOUT world_endpoints
→ canonicalize adjacency
→ project chains/loops/regions WITHOUT loop.world_coordinates
→ project compact repair history
→ synthesize current issues
→ provenance summary
→ deterministic canonical content JSON
→ content_digest
→ dataset_id
→ build_evidence
→ return immutable candidate
```

Any unreadable authoritative input -> fail closed; never publish partial candidate as READY.

---

# 9. Production Integration Boundary

Do NOT make the pure Builder read Runner private state.

B1 implementation is split:

## B1.2 — Dataset value object + canonical serializer
Pure only.

## B1.3 — Pure builder
Explicit inputs only.

## B1.4 — Pure validator
Explicit candidate + workflow state only.

## B1.5 — Current-state integration
Only after B1.2–B1.4 source review passes.

B1.5 may add one small production read-only integration seam to obtain a coherent current input bundle from the existing pipeline.

Preferred semantics:

```text
validate host consistency
→ require current workspace ready
→ obtain current SourceSnapshot
→ obtain/rebuild fresh CanonicalGeometryGraph read-only
→ require current V1.8 structure result corresponding to that graph
→ collect current runner snapshot/audits
→ pass explicit values to Builder
```

No host mutation.

Do not use `instance_variable_get` from the Builder.

If current public/test-only Runner accessors are insufficient, B1.5 may add a narrowly-scoped read-only production accessor/context method after AIPM review. Do not turn WorkingModeRunner into the dataset implementation.

B2 later owns refresh-before-validation / accept-time source revalidation / persistence.

---

# 10. Minimum Regression Set

### Value / serialization
1. JSON-safe only.
2. deeply immutable candidate.
3. no SketchUp objects / object IDs.
4. same `content` twice -> exact same canonical bytes + digest.
5. different build-evidence session IDs do not change content digest.
6. random SourceSnapshot `snapshot_id` does not change content digest when semantic source content is unchanged.
7. random workspace ID / legacy graph digest does not define dataset identity.

### Geometry
8. nodes are sole coordinate authority.
9. edge `world_endpoints` are absent.
10. loop `world_coordinates` are absent.
11. duplicate node ID -> NOT_READY.
12. malformed/NaN/Infinity node coord -> NOT_READY.
13. missing edge node ref -> NOT_READY.
14. missing chain/loop/region refs -> NOT_READY.
15. adjacency references invalid node -> NOT_READY.

### Workflow readiness
16. clean rectangle -> READY.
17. repaired Owner Z+Gap fixture -> READY.
18. pending safe Z -> NOT_READY.
19. pending safe Gap -> NOT_READY.
20. stale/failed workspace -> NOT_READY.
21. Planar/Gap/Structure NOT_COMPUTED -> NOT_READY.
22. review-only ambiguity -> READY_WITH_WARNINGS.
23. source short-edge / large-coordinate / deep-nesting issue -> READY_WITH_WARNINGS.
24. repaired historical Z/gap/open-endpoint registry issues do NOT resurrect as warnings/blockers.
25. duplicate repair failure -> NOT_READY.
26. duplicate skipped action -> READY_WITH_WARNINGS if no blocker.

### Digest/config
27. B1 execution_context_digest is stable across differing captured_at.
28. B1 does not modify legacy ExecutionConfigSnapshot or legacy graph digest behavior.
29. content digest recomputation matches.
30. payload > 8 MiB -> `persistence_envelope_unverified` blocker.

### Safety
31. Builder + Validator cause zero host mutation.
32. Source CAD unchanged.
33. V1.7/V1.8 objects are not mutated.
34. no V2 road/building/green-space labels fabricated.

---

# 11. Allowed / Forbidden During B1.2–B1.4

Preferred new production modules:

```text
extension/su_ai_plugin/core/prepared_cad_dataset.rb
extension/su_ai_plugin/core/prepared_cad_dataset_builder.rb
extension/su_ai_plugin/core/prepared_cad_dataset_validator.rb
```

Focused tests may be added.

Do NOT modify during the first B1 implementation packet:

- V1.5 duplicate algorithms;
- Planar proposer/executor;
- Gap proposer/executor;
- CanonicalTopologyBuilder;
- CanonicalGeometryGraph;
- CanonicalStructureReconstructor;
- tolerance values;
- SourceSnapshot;
- ExecutionConfigSnapshot;
- WorkingModeRunner;
- CadPrepWorkflowOrchestrator;
- Presenter/UI;
- persistence store;
- RBZ accept/load path;
- V1.9B2;
- V2/MCP/LLM/Agent.

If B1.2–B1.4 appears to require any frozen existing module change: STOP and return to AIPM.

---

# 12. B1 Pre-Build Review Gate

Because this stage freezes a long-lived V1→V2 data contract and contains identity/digest/state-ownership decisions, AIPM recommends one narrow Codex xHigh design review BEFORE Pi production coding.

Codex should review:
- random/session identity exclusion;
- graph/structure digest non-reuse;
- node-only coordinate authority;
- current-issue synthesis;
- content/build-evidence separation;
- Builder purity;
- readiness blockers/warnings;
- Ruby 2.2 compatibility of the proposed implementation approach.

Codex must not implement code.

After Codex PASS:
- AIPM issues B1.2–B1.4 Pi implementation dispatch.
- B1.5 integration is held for a separate packet after source review.

END
