# SU-AI-Plugin — V1.9B1 PreparedCadDataset Blueprint v1.1

Date: 2026-09-11  
Authority: AIPM / ChatGPT  
Final Product Owner: Owner  
Reviewer: Codex xHigh  
Status: **PRE-BUILD RECHECK REQUIRED**

This v1.1 supersedes conflicting sections of v1.0 and resolves the six real Codex blocks recorded in `CODEX_V1_9B1_PREBUILD_DESIGN_REVIEW_REAL_RESULT_2026-09-11.md`. All non-conflicting v1.0 decisions remain in force.

Frozen stage state:

```text
V1.9A = CLOSED_FROZEN
V1.9B0 = CLOSED_OWNER_PASS
B1.2 = HOLD
B1.3 = HOLD
B1.4 = HOLD
B1.5 = NOT_AUTHORIZED
V1.9B2 = NOT_STARTED
V2 / MCP / LLM / Agent = NOT_STARTED
```

## 1. Semantic identity boundary

PreparedCadDataset semantic identity MUST be independent from:

- `SourceSnapshot.snapshot_id`;
- `WorkingModeRunner.workspace_id`;
- legacy `CanonicalGeometryGraph#digest`;
- legacy V1.8 result digest;
- legacy duplicate/gap action/proposal IDs;
- raw execution-only derived IDs when they are used only for audit;
- captured timestamps.

Identity remains:

```text
normalized semantic content
→ identity_canonical_json(content)
→ SHA-256 content_digest
→ dataset_id = "pcd-" + first 20 hex chars
```

Current-run evidence is separate:

```text
build_evidence
→ build_evidence_digest
```

Validation binds BOTH `content_digest` and `build_evidence_digest`, but neither validation nor build evidence changes `dataset_id`.

---

## 2. B1-ID-01 — legacy repair IDs are not semantic content

Current duplicate action IDs can contain `SourceSnapshot.snapshot_id`; therefore raw `action_id` is forbidden from canonical content. The same rule applies defensively to raw gap proposal/action IDs and execution-local `repair_action_id`.

`content.repair_history` stores stable semantic facts only. Raw legacy IDs, survivor/removed derived IDs and proposal IDs may be retained under `build_evidence.repair_audit` for audit.

If a semantic repair record needs an ID, B1 creates:

```text
semantic_repair_id =
"rep-" + first 20 hex chars(
  SHA256(identity_canonical_json(record_without_id))
)
```

A duplicate semantic record may include only stable fields such as rule ID, status, confidence basis, stable source refs, canonical endpoint summary, layer, removed count, tolerance status/value and before/after duplicate counts. Planar/Gap records follow the same principle: semantic status/tolerance/count/provenance facts are allowed; raw legacy action/proposal/session IDs are not.

Canonical geometry edges MUST NOT publish raw legacy `repair_action_id`. If a stable B1 semantic repair mapping exists they may reference `semantic_repair_id`; otherwise omit the link from semantic content and retain the raw ID only as build evidence.

Required regression: same CAD + same repair result + different snapshot/workspace/legacy action IDs => identical semantic canonical bytes, `content_digest`, and `dataset_id`.

---

## 3. B1-ID-02 — B1-local source identity + exact canonical encoding

### 3.1 B1-local source facts

Legacy `SourceFingerprint#digest` is BUILD EVIDENCE only. B1 computes `source_content_digest` from a recursively normalized source-facts object.

Normalized source facts contain:

```text
edge_count
edge_length_sum
bounding_box
face_count
face_vertex_count_sum
group_count
component_instance_count
component_definition_count
layer_count
layer_facts[]
material_digest
selection_scope_digest
```

`layer_facts` is an ARRAY sorted by `layer_name`, each entry:

```text
layer_name
visible
edge_count
face_count
```

This removes dependence on nested Hash insertion order.

`content.source` includes `source_schema_version`, `source_content_digest`, normalized source facts and normalized selection scope. Legacy source fingerprint digest moves to `build_evidence`.

### 3.2 Execution field set

The B1 execution identity contains EXACTLY:

```text
profile_id
profile_version
rule_set_id
rule_set_version
rule_set_digest
tolerance_schema_version
tolerance_values
session_overrides
source_snapshot_schema_version
```

`captured_at` is excluded.

`execution_context_digest` is computed over exactly the fields above. Do NOT modify legacy `ExecutionConfigSnapshot`.

### 3.3 Active-edit context whitelist

Do not copy arbitrary transform-context keys. Semantic content permits only:

```text
context_kind = root | active_edit
active_edit_transform = exactly 16 finite numbers
active_edit_inverse = exactly 16 finite numbers
active_edit_path = Array<Integer>
pid_path_complete = Boolean
```

Legacy root identity marker normalizes to identity transform/inverse + empty path. Unknown transform-context fields and `active_edit_seed` are excluded from semantic identity.

### 3.4 Identity canonical bytes

Serializer rules are frozen:

- published Hash keys are already Strings; serializer does not arbitrarily coerce keys;
- Hash keys sort by UTF-8 byte sequence;
- Strings must convert losslessly to valid UTF-8; invalid/unconvertible input fails closed;
- exact Unicode codepoint sequence is semantic; no implicit NFC/NFD normalization;
- Integer encoding is canonical base-10;
- Float must be finite; `-0.0` normalizes to `+0.0`;
- digest canonicalization MUST NOT depend on runtime Float#to_s.

For identity serialization only, every Float is projected as:

```json
{"$f64":"<16 lowercase big-endian IEEE-754 hex digits>"}
```

The published dataset still carries ordinary JSON Number fields. The tagged form exists only inside `identity_canonical_json` used for identity/digest.

Canonical JSON string escaping is fixed: escape JSON quote/backslash and control codepoints; emit remaining Unicode as UTF-8 bytes.

Provide a hard-coded Golden canonical-bytes + digest fixture. When a Ruby 2.2 runtime is available, run the SAME Golden under Ruby 2.2 and the current test runtime; do not claim cross-runtime PASS without actual execution.

---

## 4. Coordinate authority

Node-only authority remains frozen and is strengthened:

- canonical PCD node `xyz` is the ONLY authoritative geometry coordinate;
- edge references `node_a_id` / `node_b_id`;
- PCD edge MUST NOT contain `world_endpoints`;
- PCD loop MUST NOT contain `world_coordinates`;
- optional V1.8 length/area/perimeter/winding metrics are omitted from PCD v1 by default; if added later they must be recomputed from PCD node coordinates, never copied from a stale edge-endpoint path.

No active-edit transform is re-applied to already world-space canonical node coordinates.

---

## 5. B1-STATE-01 — fail-closed readiness matrix

General rule: **only explicitly allow-listed state combinations may become READY or READY_WITH_WARNINGS**. Missing, unknown, malformed, unsupported or contradictory states are always NOT_READY.

### Workspace

Only exact `ready` is acceptable. `none`, `building`, `discarded`, `failed`, missing or unknown => NOT_READY.

### Duplicate

Duplicate summary is required. `tolerance_status` MUST equal `captured`.

- `missing_captured_tolerance` => NOT_READY
- `invalid_captured_tolerance` => NOT_READY
- missing/unknown tolerance status => NOT_READY
- `actions_failed > 0` => NOT_READY
- `actions_skipped > 0` with no blocker => READY_WITH_WARNINGS
- counts must be non-negative Integers; malformed counts => NOT_READY

### Planar exact states

```text
NO_CANDIDATE        -> clean
READY_TO_NORMALIZE  -> NOT_READY
REVIEW_REQUIRED     -> READY_WITH_WARNINGS
APPLIED             -> clean
invalid_tolerance   -> NOT_READY
invalid_input       -> NOT_READY
FAILED              -> NOT_READY
NOT_COMPUTED        -> NOT_READY
unknown/missing     -> NOT_READY
```

If `computed` exists, contradictory combinations fail closed. `computed=false` may only coexist with NOT_COMPUTED; `computed=true` with NOT_COMPUTED is contradictory.

### Gap/topology

```text
NO_CANDIDATE     -> clean
READY_TO_REPAIR  -> NOT_READY
REVIEW_REQUIRED  -> READY_WITH_WARNINGS
APPLIED          -> clean
FAILED           -> NOT_READY
NOT_COMPUTED     -> NOT_READY
unknown/missing  -> NOT_READY
```

Apply the same computed/state contradiction rule.

### Structure

```text
READY                -> clean
READY_WITH_WARNINGS  -> READY_WITH_WARNINGS
FAILED               -> NOT_READY
NOT_COMPUTED         -> NOT_READY
unknown/missing      -> NOT_READY
```

READY / READY_WITH_WARNINGS / FAILED require `computed=true`; contradiction => NOT_READY.

Required tests are table-driven over every real production enum plus unknown, missing, wrong-type and contradictory values.

---

## 6. B1-COHERENCE-01 — all explicit inputs must be one coherent build

Builder API uses Ruby-2.2-compatible explicit keywords:

```ruby
PreparedCadDatasetBuilder.build(
  source_snapshot: source_snapshot,
  workflow_snapshot: workflow_snapshot,
  canonical_graph: canonical_graph,
  structure_result: structure_result,
  analysis_result: analysis_result
)
```

Builder returns an internal frozen BuildOutcome.

Success:

```text
status = BUILT
dataset = PreparedCadDataset candidate
blockers = []
```

Failure:

```text
status = NOT_READY
dataset = nil
blockers = [...]
```

No partial dataset is published after coherence failure.

Before projection all of these must pass:

1. workflow state == `ready`;
2. source snapshot ID == workflow source snapshot ID;
3. graph source snapshot ID == source snapshot ID;
4. graph workspace ID == workflow workspace ID;
5. structure source snapshot ID == source snapshot ID;
6. structure workspace ID == workflow workspace ID;
7. structure `canonical_graph_digest` == supplied graph digest;
8. graph schema == expected `cgg.v1`;
9. structure schema == expected `csr.v1`;
10. workflow structure digest/graph-digest evidence, when present, matches supplied structure result;
11. source snapshot schema matches execution config `source_snapshot_schema_version`;
12. `analysis_result.geometry_snapshot` must match SourceSnapshot edges/faces/layers under a B1-local normalized analysis/source digest;
13. source-secondary issue references from AnalysisResult must resolve against current SourceSnapshot records; impossible/mismatched analysis refs => NOT_READY.

The IDs/digests above are coherence evidence only; they do not enter semantic dataset identity.

Validator later re-checks candidate build evidence against workflow evidence and binds validation to both content and evidence digests.

B1.5 must later provide the EXACT fresh graph that is also consumed by V1.8; current cached topology graph accessor is not assumed sufficient.

---

## 7. B1-ISSUE-01 — exact issue-reference contract

Replace abstract `entity_refs` with `refs` containing ONLY these shapes:

PCD node:

```json
{"kind":"pcd_node","id":"..."}
```

PCD edge:

```json
{"kind":"pcd_edge","id":"..."}
```

Stable source path:

```json
{"kind":"source_pid_path","persistent_id_path":[1,2,3]}
```

Rules:

- PCD node/edge refs must resolve inside the dataset;
- source PID path must be non-empty integer-only and come from current SourceReference with `pid_path_complete=true`;
- raw `source_entity_ids`, `entity_id`, Ruby `object_id` are forbidden;
- analysis-local `edge_ids` are forbidden as published refs;
- analysis-local edge ID may only be used internally to locate a current SourceSnapshot EdgeRecord and derive a stable allowed PID-path ref;
- raw transient occurrence token is not an issue ref;
- when no stable ref exists, preserve issue code/count and publish `refs=[]`; do not invent identity.

Every non-empty issue ref must be resolvable.

Historical `duplicate_edge_candidate`, `significant_non_zero_z`, `open_endpoint`, `gap_candidate` remain superseded by current workflow state and MUST NOT resurrect. Only source-secondary `short_edge`, `abnormal_large_coord`, `deep_nesting` may remain as source-registry warnings.

---

## 8. Build evidence + validation binding

`build_evidence` may contain session/current-run facts:

```text
source_snapshot_id
workspace_id
legacy_source_fingerprint_digest
upstream_graph_digest
upstream_structure_digest
source_snapshot_captured_at
source_graph_schema_version
source_structure_schema_version
legacy repair audit / IDs
```

Compute:

```text
build_evidence_digest = SHA256(identity_canonical_json(build_evidence))
```

Validation MUST carry:

```text
validated_content_digest
validated_build_evidence_digest
```

`PreparedCadDataset#with_validation` returns a NEW immutable dataset and rejects validation unless both digests match. A validation from another build/session cannot be reused solely because semantic content matches.

---

## 9. B1-ENVELOPE-01 — unique candidate → validation → final sequence

### Candidate

Builder success produces an immutable unvalidated candidate:

```text
schema_version
dataset_id
content_digest
content
build_evidence
build_evidence_digest
validation = nil
```

### Finalization algorithm

1. run all non-size validation checks;
2. construct tentative validation with persistence check `PASS` and constant `threshold_bytes=8388608`;
3. attach validation to candidate => tentative final dataset;
4. serialize the EXACT final persisted UTF-8 JSON and measure `bytesize`;
5. if bytesize <= 8 MiB: keep PASS validation;
6. if bytesize > 8 MiB: rebuild validation with persistence check FAIL + blocker `persistence_envelope_unverified`, attach to candidate => final NOT_READY dataset;
7. serialize failure form once more only for diagnostic reporting.

The measured byte count MUST NOT be persisted inside the payload being measured. It is returned out-of-band in Validator's runtime outcome.

Because adding a failure blocker can only increase payload size, a tentative payload already >8 MiB cannot become supported after adding the FAIL record.

Preferred pure API:

```ruby
outcome = PreparedCadDatasetValidator.validate_and_finalize(
  dataset: candidate,
  workflow_snapshot: workflow_snapshot
)
```

Runtime outcome may include:

```text
status
final_dataset
serialized_bytes
readiness
```

`serialized_bytes` is diagnostic output only, not persisted data.

Required boundary tests include exact 8 MiB, 8 MiB + 1 byte, validation reuse after changed build evidence, and absence of digest/size circularity.

---

## 10. Structural validation minimum

Validator must fail closed on:

- unsupported dataset schema;
- source-content digest mismatch;
- execution-context digest mismatch;
- build-evidence digest mismatch;
- content digest mismatch;
- dataset ID mismatch;
- non-UTF8/unsupported types/Symbol leakage;
- duplicate node/edge/chain/loop/region IDs;
- malformed/nonfinite node XYZ;
- invalid edge/adjacency/structure refs;
- edge `world_endpoints` present;
- loop `world_coordinates` present;
- invalid/non-resolvable issue refs;
- host/session entity IDs leaking into semantic content;
- any readiness-state blocker;
- final persisted UTF-8 payload > current verified 8 MiB envelope.

---

## 11. Ruby 2.2 boundary

Do not use Ruby 3 keyword shorthand such as:

```ruby
source_snapshot:
```

Use:

```ruby
source_snapshot: source_snapshot
```

Continue avoiding Array#sum, Hash#compact, transform_keys, filter_map, Numeric#positive?, safe-navigation, yield_self/then and pattern matching.

---

## 12. Recheck evidence required

Codex v1.1 recheck should verify at minimum:

- random snapshot/workspace/action IDs change only build evidence, not semantic bytes/dataset ID;
- nested layer-fact/Hash order does not change source/content digest;
- exact execution field set is closed;
- transform context is whitelisted;
- Float/UTF-8 canonical identity is runtime-format independent;
- every production state + unknown/missing/contradiction fails/permits exactly as specified;
- source/workflow/graph/structure/analysis mismatch => BuildOutcome NOT_READY + dataset=nil;
- validation binds both digests;
- final 8 MiB size check measures the exact persisted payload without self-reference;
- host/session issue IDs cannot enter content;
- B1.2–B1.4 still require only NEW pure modules and no frozen V1.5–V1.9A changes.

Until Codex returns:

```text
SAFE TO DISPATCH B1.2-B1.4: YES
```

Pi remains HOLD.

END
