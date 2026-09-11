# SU-AI-Plugin — V1.9B1 PreparedCadDataset
# Source Contract Mapping + Implementation-Ready Blueprint v1.2

Date: 2026-09-11
Planning / Technical Design Owner: AIPM / ChatGPT
Final Product Owner: Owner
Technical Reviewer: Codex xHigh
Target branch: `dev/v1.9`

Status:
- V1.9A = CLOSED_FROZEN
- V1.9B0 = CLOSED / OWNER PASS
- AttributeDictionary route = ACCEPTED_FOR_B1_B2
- verified real-host persistence envelope = <= 8 MiB on SketchUp 2020
- Codex review v1.0 = FIX REQUIRED
- Codex recheck v1.1 = FIX REQUIRED
- this v1.2 resolves B1-ID-03 / B1-ID-02-R1 / B1-COHERENCE-01-R1 / B1-STATE-01-R1
- B1.2–B1.4 = HOLD until Codex xHigh recheck PASS
- B1.5 = NOT_AUTHORIZED
- V1.9B2 = NOT_STARTED
- V2 / MCP / LLM / Agent = NOT_STARTED

## 0. Owner Summary

PreparedCadDataset v1 is the durable deterministic V1 -> V2 handoff contract.

This v1.2 closes the remaining identity/coherence/readiness gaps by adding:

1. B1-owned semantic IDs for nodes, edges, chains, loops and regions.
2. A type-tagged canonical BYTE encoding for identity instead of pseudo-canonical JSON.
3. A B1-local source semantic projection built directly from SourceSnapshot records, with no order-sensitive float aggregate.
4. A precisely defined AnalysisResult <-> SourceSnapshot coherence projection.
5. Full duplicate-action row/status/count validation.
6. A required explicit `topology_snapshot` Builder input so semantic node coordinates can be derived from all current endpoint members rather than from legacy ID-selected representatives.

No frozen V1.5–V1.9A production module is modified by B1.2–B1.4.

## 1. Stage boundary

B1.2:
- PreparedCadDataset immutable candidate/final value object
- canonical identity byte encoder
- deterministic persisted JSON serializer

B1.3:
- pure Builder
- input-coherence preflight
- semantic-ID remap
- source/execution/context normalization

B1.4:
- pure Validator/finalizer
- readiness
- issue-ref validation
- final <=8 MiB envelope

B1.5 remains separate and later provides ONE exact coherent live bundle:
- current SourceSnapshot
- current workflow snapshot
- current topology snapshot
- exact fresh CanonicalGeometryGraph built from that topology/current workspace
- V1.8 structure result produced from that exact graph
- matching AnalysisResult

## 2. Builder explicit inputs

```ruby
PreparedCadDatasetBuilder.build(
  source_snapshot: source_snapshot,
  workflow_snapshot: workflow_snapshot,
  topology_snapshot: topology_snapshot,
  canonical_graph: canonical_graph,
  structure_result: structure_result,
  analysis_result: analysis_result
)
```

All are explicit values.

Forbidden:
- Runner global access
- Runner private ivar access
- SketchUp calls
- host mutation
- source mutation

`topology_snapshot` is REQUIRED because the collapsed CanonicalGeometryGraph node stores only one representative coordinate selected by legacy endpoint-key ordering; B1 semantic node coordinates must not depend on legacy derived/endpoint IDs.

## 3. Identity canonical BYTE encoding

`content_digest`, `source_content_digest`, `execution_context_digest`,
`build_evidence_digest`, semantic IDs and coherence digests use ONE B1
canonical byte encoder.

The identity format is NOT JSON and does not reuse JSON escaping.

Allowed logical value types:
- nil
- true / false
- Integer
- finite Float
- valid UTF-8 String
- Array
- Hash with String keys only

Symbols are not accepted by the encoder. Builder normalization must convert explicitly allowed Symbol-keyed production inputs before encoding.

### 3.1 Encoding grammar

```text
nil      -> N;
false    -> B0;
true     -> B1;
Integer  -> I<decimal-byte-length>:<canonical-decimal>;
Float    -> F<16 lowercase hex IEEE-754 binary64 big-endian>;
String   -> S<utf8-byte-length>:<raw UTF-8 bytes>;
Array    -> A<count>:[<encoded values in semantic order>]
Hash     -> H<count>:{<encoded String key><encoded value>...}
```

Hash entries are sorted by raw UTF-8 bytes of the String key.

Integer:
- base 10
- no `+`
- no leading zeros except `0`

Float:
- finite only
- `-0.0` normalized to `+0.0`
- encode with Ruby-2.2-compatible `[value].pack('G').unpack('H*').first`
- no NaN / Infinity

String:
- must already be valid UTF-8
- invalid/unconvertible byte sequence => fail closed
- NO Unicode normalization
- control chars need no identity escape because strings are raw UTF-8 with a byte length prefix

This makes a real Hash such as `{"$f64":"..."}` distinct from a Float because the outer type tags differ.

### 3.2 Published/persisted JSON

The public dataset remains normal JSON-safe data.

A separate deterministic persisted serializer:
- recursively emits Hash keys in sorted UTF-8 byte order
- uses `JSON.generate` on the normalized ordered structure
- is used for exact persisted-payload bytesize
- does NOT define semantic identity

## 4. B1-local source semantic projection

Legacy `SourceFingerprint#digest` is BUILD EVIDENCE only.

Do NOT use legacy `edge_length_sum`, bounding-box aggregation order, or legacy nested Hash ordering for semantic identity.

B1 computes `pcd-source-projection.v1` directly from SourceSnapshot records.

### 4.1 Stable source ref

Semantic source ref exists ONLY when:
- `SourceReference.pid_path_complete == true`
- `persistent_id_path` is a non-empty Integer array

Form:

```json
{"kind":"source_pid_path","persistent_id_path":[1,2,3]}
```

No entity_id, object_id, instance label path, transient occurrence ID, or analysis-local record ID.

### 4.2 Source edge descriptor

```json
{
  "kind":"edge",
  "endpoints":[[0,0,0],[1,0,0]],
  "layer_name":"Layer0",
  "stable_source_ref":null
}
```

Rules:
- endpoints exactly 3 finite Numbers
- choose canonical edge orientation by comparing identity bytes of `[p1,p2]` and `[p2,p1]`
- no EdgeRecord.id
- no EdgeRecord.length
- no metadata
- no entity_id
- sort edge descriptors by identity bytes, preserving duplicates

This makes source identity independent from traversal order and order-dependent float summation.

### 4.3 Source face descriptor

Fields:
- kind = face
- layer_name
- outer_loop_vertex_count
- inner_loop_count
- stable_source_ref

Sort by identity bytes, preserving multiplicity.

### 4.4 Layer descriptor

Exact fields:
- layer_name
- role
- role_rule
- visible
- visibility_unknown
- edge_count
- face_count
- faces_with_holes_count

Convert role Symbol to String in Builder.
Sort by layer_name, then identity bytes.

### 4.5 Source content object

```text
schema_version = pcd-source-projection.v1
source_snapshot_schema_version
edges
faces
layers
```

`source_content_digest = SHA256(identity_bytes(source_content_object))`

Selection scope is NOT part of semantic identity in PCD v1.
Its current-session form is retained only in build evidence.

## 5. Exact execution normalization

Content execution fields:
- profile_id
- profile_version
- rule_set_id
- rule_set_version
- rule_set_digest
- tolerance_schema_version
- tolerance_values
- session_overrides
- source_snapshot_schema_version
- execution_context_digest

Exclude `captured_at`.

### 5.1 tolerance_values fixed schema

Builder accepts Symbol or String input keys, but maps ONLY:
- duplicate
- short_edge
- gap_search
- coordinate_epsilon
- big_z
- large_coordinate
- planar_z_snap

Each required exactly once after normalization.
Each value must be finite Numeric and > 0.

Missing, unknown extra tolerance key, duplicate-after-normalization or malformed value => Builder BLOCKED / dataset=nil.

Published tolerance Hash uses exactly the String keys above.

### 5.2 session_overrides

Allowed input keys: String or Symbol.

Convert keys to String recursively.
A String/Symbol collision after conversion => fail closed.

Allowed values:
- nil
- Boolean
- Integer
- finite Float
- valid UTF-8 String
- Array of allowed values
- Hash of allowed values

Any host/arbitrary object, invalid string, NaN/Infinity or unsupported key/value => fail closed.

`execution_context_digest` is over normalized execution content excluding itself.

## 6. Active-edit context whitelist

Semantic coordinate context:
- coordinate_space = sketchup_model_world
- unit
- axes = ["x","y","z"]
- source_coordinate_origin
- active_edit_context

Exact active-edit fields:
- context_kind = root | active_edit
- active_edit_transform = 16 finite Numbers
- active_edit_inverse = 16 finite Numbers
- active_edit_path = Array<Integer>
- pid_path_complete = Boolean

Root fallback:
- identity forward
- identity inverse
- []
- true

Active-edit:
- both matrices exactly 16 finite Numbers
- path Integer-only
- pid_path_complete Boolean
- unknown keys ignored semantically and may stay only in build evidence

`active_edit_seed` is not semantic identity.

## 7. Source occurrence -> stable provenance resolver

For every current SourceSnapshot EdgeRecord/FaceRecord with complete non-empty PID path:
- derive the expected current stable occurrence spelling:
  `occ-` + PID path joined with `>`
- map it to the semantic `source_pid_path` ref

A graph/topology occurrence ID produces semantic provenance ONLY when it matches this current SourceSnapshot lookup.

`transient-occ-*`, unknown strings and incomplete refs produce no semantic provenance and remain build evidence only.

Do not infer a stable PID path by parsing an unverified occurrence string alone.

## 8. B1-ID-03 — Semantic geometry ID/remap contract

Legacy IDs are addressing/evidence only.

Never copied as semantic IDs:
- derived_edge_id
- endpoint_key
- canonical_node_id
- canonical_edge_id
- chain_id
- loop_id
- region_id
- repair_action_id
- proposal/action ID
- transient occurrence ID

### 8.1 Semantic node coordinate authority

For each collapsed graph node:

1. Read legacy `endpoint_keys`.
2. Resolve EVERY endpoint key against required `topology_snapshot["endpoints"]`.
3. Every endpoint must expose finite 3-number `world_coordinate`.
4. Verify endpoint-member set agrees with graph membership.
5. For resolved clique, verify every pair of member coordinates is within declared coordinate_epsilon.
6. Semantic node XYZ = lexicographically smallest member coordinate by B1 identity-byte ordering, NOT endpoint_key ordering.

Missing/unreadable/inconsistent member => Builder BLOCKED.

### 8.2 Node local seed

- xyz
- sorted unique semantic stable source refs
- sorted unique layer_names
- resolved_clique Boolean
- membership_count

No endpoint_keys or derived_edge_ids.

### 8.3 Topology-refined node label

1. `label0 = SHA256(identity_bytes(node_local_seed))`
2. Provisional edge label uses:
   - unordered endpoint label0 pair
   - normalized origin_kind
   - layer_name
   - sorted stable source refs
   - stable unresolved flag base codes
   - semantic repair descriptor if any
3. Iteratively refine each node from:
   - node_local_seed
   - sorted multiset of `[provisional_edge_label, neighbor_previous_label]`
4. Iterate until labels stop changing OR node_count rounds.
5. If distinct legacy nodes still share one final label => `semantic_node_ambiguity`, BLOCKED. Never tie-break with legacy IDs/order/transient provenance.

Node ID:
`pcn-` + first 20 hex chars(final label)

### 8.4 Semantic edge ID

After node IDs exist, normalize:
- node_a_id / node_b_id sorted lexicographically
- origin_kind
- layer_name
- sorted stable source refs
- stable unresolved flag base codes
- semantic_repair_id optional

Edge ID:
`pce-` + first20(SHA256(identity_bytes(record_without_id)))

Collision among distinct legacy edges => `semantic_edge_ambiguity`, BLOCKED.

### 8.5 Adjacency

Ignore legacy adjacency for publication after coherence checks.
Rebuild PCD adjacency only from semantic edges.

### 8.6 Chain remap

Remap legacy node/edge sequences.
Build forward and aligned reverse traversals.
Choose lexicographically smaller alternating semantic node/edge token sequence.
Publish chosen orientation.

ID:
`pch-` + first20(SHA256(identity_bytes(node_ids + edge_ids)))

Collision => BLOCKED.

### 8.7 Loop remap

Remap open cyclic node/edge sequence.
Generate all `2*N` valid representations:
- N forward rotations
- N reverse-orientation rotations
- preserve edge-to-consecutive-node alignment

Choose lexicographically smallest alternating semantic token sequence.

ID:
`pcl-` + first20(SHA256(identity_bytes(node_ids + edge_ids)))

Collision => BLOCKED.

Do not publish loop world_coordinates.

### 8.8 Region remap

Map outer_loop_id and hole_loop_ids to semantic loop IDs.
Sort/uniq holes.

Region semantic record:
- outer_loop_id
- hole_loop_ids
- stable source refs
- layer_names
- stable unresolved flag base codes

ID:
`pcr-` + first20(SHA256(identity_bytes(record_without_id)))

Collision => BLOCKED.

### 8.9 ID-bearing diagnostics

Never copy raw structure/topology strings containing legacy IDs into content.

Known reason families:
- emit stable base reason code
- remap resolvable IDs to typed semantic refs
- keep raw legacy diagnostic only in build evidence

Unknown ID-bearing diagnostics stay evidence only and cause warning/blocker according to fail-closed policy.

## 9. Semantic repair IDs

No legacy action/proposal/derived ID enters content.

If required:
`pcrp-` + first20(SHA256(identity_bytes(stable repair record without ID)))

Stable source refs only.
Transient occurrence IDs omitted.

Legacy repair audit stays build evidence only.

## 10. B1-COHERENCE-01-R1 — Exact Analysis <-> Source projection

Compute the SAME `pcd-coherence.v1` projection independently from:
A. SourceSnapshot edges/faces/layers
B. AnalysisResult.geometry_snapshot edges/faces/layers

Hash both with B1 identity bytes; require equality.

This is build coherence evidence only.

### 10.1 Coherence SourceReference descriptor

Fields:
- kind
- structural_depth
- pid_path_complete
- layer_name

Identity branch:
- complete non-empty PID path => `stable_pid` + persistent_id_path
- else entity_id exists => `transient_entity` + entity_id
- else => `unresolved`

`instance_path` may appear as String array in coherence evidence only.

### 10.2 Coherence edge descriptor

- kind=edge
- canonical unordered endpoints
- layer_name
- coherence_source_ref

No EdgeRecord.id, metadata or length aggregate.
Sort descriptors by identity bytes, preserving duplicates.

### 10.3 Coherence face descriptor

- kind=face
- layer_name
- outer_loop_vertex_count
- inner_loop_count
- coherence_source_ref

Sort by identity bytes.

### 10.4 Coherence layer descriptor

Exact fields:
- name
- role
- role_rule
- visible
- visibility_unknown
- edge_count
- face_count
- faces_with_holes_count

### 10.5 Registry edge ID resolution

For current source-secondary registry issues:

1. Build `analysis_edge_by_id` from AnalysisResult.geometry_snapshot.edges.
2. Every EdgeRecord.id must be non-nil and unique.
3. Every issue edge_id must resolve exactly once.
4. Compute resolved analysis edge coherence descriptor.
5. Require descriptor exists in SourceSnapshot edge coherence multiset.
6. Missing => `analysis_registry_mismatch`.

Analysis-local edge IDs are in-memory lookup keys only and never persisted semantically.

Issue semantic ref:
- complete stable PID => source_pid_path
- otherwise refs=[]

Transient entity_id is coherence evidence only.

## 11. Cross-input coherence checks

Builder success requires:

1. workflow state exactly ready
2. source snapshot ID == workflow source snapshot ID
3. graph source snapshot ID == source snapshot ID
4. graph workspace ID == workflow workspace ID
5. structure source snapshot ID == source snapshot ID
6. structure workspace ID == workflow workspace ID
7. structure canonical_graph_digest == supplied graph.digest
8. graph schema == cgg.v1
9. structure schema == csr.v1
10. workflow structure digest/graph digest, when present, matches supplied structure
11. source schema == execution source_snapshot_schema_version
12. topology endpoint membership resolves every graph node endpoint key
13. topology coordinate_epsilon coherent with graph node epsilon
14. Analysis<->Source coherence digests equal
15. source-secondary registry edge lookups resolve

Any mismatch:
- BuildOutcome.status = BLOCKED
- dataset = nil

Builder failure uses `BLOCKED`; final dataset readiness remains `NOT_READY | READY_WITH_WARNINGS | READY`.

## 12. B1-STATE-01-R1 — Duplicate stage full validation

Production candidate requires duplicate summary.

Required:
- tolerance_status == captured
- actions_applied/skipped/failed non-negative Integers
- last_action_status in `none | applied | skipped | failed`

If `actions` exists:
- must be Array
- every row Hash
- every row has status
- row status allowlist exactly `applied | skipped | failed`
- unknown/missing/raw-only row => NOT_READY
- recompute counts from rows
- recomputed counts must equal summary counts
- sum counts == actions.length

last_action_status:
- empty actions => must be none
- non-empty + applied/skipped/failed => corresponding recomputed count > 0
- non-empty + none => allowed ONLY when every row is skipped
- otherwise NOT_READY

For current contract, missing `actions` => NOT_READY.

Then:
- failed > 0 => NOT_READY
- skipped > 0 with no blocker => READY_WITH_WARNINGS
- otherwise clean

Any count/status contradiction => NOT_READY.

All earlier workspace/Planar/Gap/Structure allowlists from v1.1 remain frozen.

## 13. Issue reference contract

Semantic refs ONLY:
- pcd_node
- pcd_edge
- source_pid_path

PCD refs use B1 semantic IDs.

Forbidden:
- source_entity_ids
- entity_id
- object_id
- raw analysis edge ID
- raw legacy canonical/derived ID
- transient occurrence ID

All non-empty refs must resolve.
No stable ref => refs=[].

Historical duplicate/Z/open-endpoint/gap registry families remain superseded by current workflow state.

Secondary source warnings:
- short_edge
- abnormal_large_coord
- deep_nesting

## 14. Candidate / validation / 8 MiB finalization

Builder success:
- BuildOutcome.status = BUILT
- candidate.validation = nil

Builder coherence failure:
- BuildOutcome.status = BLOCKED
- dataset = nil

Validator final readiness:
- NOT_READY
- READY_WITH_WARNINGS
- READY

Validation binds BOTH:
- validated_content_digest
- validated_build_evidence_digest

Finalization:
1. candidate
2. non-size validation
3. tentative final with fixed-shape persistence PASS check
4. deterministic persisted UTF-8 JSON bytes
5. measure bytesize
6. <= 8388608 => PASS
7. > 8388608 => rebuild validation with `persistence_envelope_unverified`, finalize NOT_READY
8. measured bytes are out-of-band and never persisted inside the measured payload

B2 MUST use the same persisted JSON serializer.

## 15. Build evidence

May contain:
- source_snapshot_id
- workspace_id
- legacy source fingerprint digest
- legacy graph digest
- legacy structure digest
- captured_at
- normalized selection_scope
- topology legacy endpoint/node/edge mappings
- legacy derived/canonical/repair/action/proposal IDs
- transient occurrence IDs
- raw ID-bearing diagnostics
- coherence digest/current-session transient entity evidence

`build_evidence_digest = SHA256(identity_bytes(build_evidence))`

It may change across equivalent sessions without changing content_digest/dataset_id.

## 16. Required regressions for v1.2

### ID-03
- reorder source edges -> same semantic graph/content
- perturb derived_edge_id/endpoint_key/canonical IDs -> same semantic graph/content
- perturb gap/repair IDs -> same content
- perturb transient occurrence IDs -> same content
- chain orientation flip -> same semantic chain
- loop rotation/reversal -> same semantic loop
- region legacy-ID perturb -> same semantic region
- semantic node ambiguity -> BLOCKED
- semantic edge ambiguity -> BLOCKED
- all remapped refs resolve

### live-member node coordinate
- same members, different endpoint-key ordering -> same semantic xyz
- missing member endpoint -> BLOCKED
- clique member outside epsilon -> BLOCKED

### ID-02-R1
- edge order permutation -> same source_content_digest
- no edge_length_sum in semantic source identity
- Hash insertion order -> same identity bytes
- Float vs tag-shaped Hash -> different identity bytes
- -0.0 and +0.0 same identity
- control chars stable
- invalid UTF-8 fails
- Symbol/String tolerance forms normalize identically
- unknown/missing tolerance key BLOCKED
- Symbol/String session key collision BLOCKED
- unsupported override type BLOCKED
- hard-coded canonical-byte + SHA Golden fixture
- Ruby 2.2 Golden only claimed if actually executed

### COHERENCE-R1
- same source/analysis reordered -> pass
- geometry mismatch -> BLOCKED
- layer mismatch -> BLOCKED
- source-ref mismatch -> BLOCKED
- transient entity coherence mismatch -> BLOCKED
- registry unknown edge ID -> BLOCKED
- registry descriptor absent from source multiset -> BLOCKED
- raw analysis edge IDs absent from content

### DUPLICATE STATE-R1
- unknown action status -> NOT_READY
- missing status -> NOT_READY
- count mismatch -> NOT_READY
- impossible last status -> NOT_READY
- skip-only + last none -> valid warning
- failed row with actions_failed=0 -> NOT_READY
- raw-only malformed action -> NOT_READY

All previous v1.1 regressions remain required.

## 17. Ruby 2.2

Allowed float identity primitive:

```ruby
[value].pack('G').unpack('H*').first
```

Do not use:
- keyword value shorthand
- Array#sum
- Hash#compact
- transform_keys
- filter_map
- Numeric#positive?
- safe navigation
- pattern matching
- then / yield_self

## 18. Frozen modules

B1.2–B1.4 must not modify SourceSnapshot, SourceFingerprint,
ExecutionConfigSnapshot, WorkingModeRunner, Planar, Gap,
CanonicalTopologyBuilder, CanonicalGeometryGraph,
CanonicalStructureReconstructor, Presenter/UI, persistence, RBZ,
V1.9A/B0, or V2/MCP/LLM/Agent.

If impossible without changing a frozen module: STOP.

## 19. Codex gate

Until real Codex xHigh v1.2 recheck returns:

```text
VERDICT: PASS
SAFE TO DISPATCH B1.2-B1.4: YES
```

state remains:

```text
B1.2 = HOLD
B1.3 = HOLD
B1.4 = HOLD
B1.5 = NOT_AUTHORIZED
V1.9B2 = NOT_STARTED
V2 = NOT_STARTED
```

END
