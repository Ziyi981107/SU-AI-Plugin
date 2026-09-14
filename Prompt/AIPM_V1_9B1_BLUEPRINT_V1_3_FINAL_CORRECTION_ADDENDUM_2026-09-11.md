# SU-AI-Plugin — V1.9B1 Blueprint v1.3 Final Correction Addendum

Date: 2026-09-11
Base: `AIPM_V1_9B1_SOURCE_CONTRACT_MAPPING_BLUEPRINT_V1_2_2026-09-11.md`
Authority: AIPM / ChatGPT
Status: B1.2–B1.4 HOLD; B1.5 NOT AUTHORIZED FOR IMPLEMENTATION

This addendum is authoritative over v1.2 where they conflict. It resolves:
- B1-COHERENCE-01-R2
- B1-LIVE-BUNDLE-01
- B1-DIGEST-01

All v1.2 sections not changed here remain in force.

## 1. COHERENCE-R2

### 1.1 Topology schema and exact membership

Require:
- `topology_snapshot["schema_version"] == "cano-node.v1"`.
- `topology_snapshot["endpoints"]` exists.
- every endpoint has a non-empty unique `endpoint_key`.
- every endpoint has exactly 3 finite numeric `world_coordinate` values.

Let:
- `T` = set of topology endpoint keys.
- `G` = union of every `canonical_graph.nodes[*].endpoint_keys`.

Require exact equality `T == G`. No extra or missing topology endpoint.

Also require `topology_snapshot["canonical_nodes"]`:
- has unique endpoint keys;
- has the same endpoint-key set T;
- grouped by legacy `canonical_node_id`, exactly matches the graph node set;
- each graph node's sorted/uniq `endpoint_keys` exactly equals its topology group;
- each graph node `membership_count` equals the exact member count;
- resolved_clique state agrees.

Any mismatch => Builder `BLOCKED`, dataset=nil.

### 1.2 Coordinate epsilon binding

Normalize execution tolerance using the fixed v1.2 tolerance schema.

Define:
`expected_coordinate_epsilon = normalized_execution["tolerance_values"]["coordinate_epsilon"]`.

Require exact finite positive Float identity equality among:
- topology `coordinate_epsilon`;
- expected captured execution coordinate_epsilon;
- every topology canonical-node coordinate_epsilon;
- every graph-node coordinate_epsilon when present.

No fallback epsilon in B1 Builder.

### 1.3 Legacy graph tolerance binding

Current `CanonicalGeometryGraph` publishes `tolerance_digest`.

Recompute the current-production legacy value from the raw captured
`SourceSnapshot.execution_config.tolerance_values`:

```ruby
legacy_sorted = Hash[raw_tolerance_values.sort]
expected = "tol-" + Digest::SHA256.hexdigest(Marshal.dump(legacy_sorted))[0, 16]
```

This is build coherence evidence only, never semantic identity.

Require:
`canonical_graph.tolerance_digest == expected`.

If current raw tolerance values cannot be sorted/marshalled, fail closed.

### 1.4 Legacy execution-config binding

Define exactly as current production does:

```ruby
expected_legacy_execution_digest =
  execution_config.respond_to?(:digest) ? execution_config.digest.to_s : ""
```

Require graph `execution_config_digest` equals this expected value.

Current `ExecutionConfigSnapshot` has no public digest, so the normal current value is `""`.
This is only a production-coherence check, not PCD semantic identity.

### 1.5 Workflow / graph / structure binding

Require:
- workflow state == `ready`;
- workflow source_snapshot_id == SourceSnapshot.snapshot_id;
- workflow workspace_id == graph.workspace_id;
- workflow topology canonical-graph digest, when published, == graph.digest;
- structure source_snapshot_id == SourceSnapshot.snapshot_id;
- structure workspace_id == graph.workspace_id;
- structure canonical_graph_digest == graph.digest;
- workflow structure digest / graph digest, when published, matches supplied structure.

Do not invent workflow config fields that production does not publish.
Execution/tolerance binding is SourceSnapshot execution config -> expected legacy graph evidence -> supplied graph.

### 1.6 Incomplete PID current-session occurrence coherence

Complete non-empty persistent_id_path remains the only stable semantic provenance.

When `pid_path_complete == false`, current-session coherence may use transient evidence only if exact enough:

Required:
- kind;
- structural_depth Integer >= 0;
- persistent_id_path Integer array, possibly partial/empty;
- instance_path Array<String>;
- layer_name;
- entity_id Integer;
- persistent_id if present.

For nested occurrences (`structural_depth > 0`):
- instance_path MUST be non-empty;
- each element must be a non-empty valid UTF-8 String.

For root-level incomplete occurrence:
- empty instance_path is allowed;
- entity_id is still required.

The incomplete-path coherence tuple is:
`kind + structural_depth + persistent_id_path + instance_path + entity_id + persistent_id-if-present + layer_name`.

If nested occurrence lacks usable instance_path => `ambiguous_incomplete_occurrence` => BLOCKED.

These transient fields are build-coherence evidence only and never enter semantic PCD content.

## 2. LIVE-BUNDLE-01 — sanctioned B1.5 seam

The current Runner does not expose the exact tuple. AIPM explicitly authorizes ONE narrow additive production change in B1.5 only:

File:
`extension/su_ai_plugin/core/working_mode_runner.rb`

Preferred public API:

```ruby
WorkingModeRunner.capture_prepared_cad_input_bundle(
  analysis_result: analysis_result
)
```

No external private-ivar access. No test-only accessor.

### 2.1 Synchronous capture sequence

Within one call:

1. Require current source/workspace/adapter and workspace state `ready`.
2. Run existing `validate_host_state_consistency!`; mismatch => BLOCKED/no bundle.
3. Capture local source/workspace/adapter/tolerance references.
4. Check the explicit analysis_result belongs to the current source before expensive recomputation.
5. Build ONE current topology snapshot using the existing V1.7 current-host endpoint path.
6. Build ONE fresh `CanonicalGeometryGraph` FROM THAT EXACT topology snapshot:
   `CanonicalGeometryGraph.build_from_workspace(workspace: workspace, topology_snapshot: topology_snapshot)`.
7. Build ONE fresh V1.8 structure result FROM THAT EXACT graph.
8. Create a pure `workflow_snapshot_for_bundle` from the current runner snapshot, replacing only the bundle copy's topology/structure summaries with the exact fresh graph/structure pair. Do not update runner caches solely for bundle construction.
9. Re-run host-state validation immediately before return; mismatch => BLOCKED/no bundle.
10. Return a frozen `pcd-input-bundle.v1` containing:
   - source_snapshot
   - workflow_snapshot
   - topology_snapshot
   - canonical_graph
   - structure_result
   - analysis_result

### 2.2 Mutation boundary

Successful capture:
- zero begin_operation / commit / abort;
- zero new host entities;
- zero source mutation;
- zero derived geometry mutation;
- unchanged workspace fingerprint;
- no assignment to cached topology/structure solely for capture.

Existing fail-closed Runner state invalidation on detected host mismatch is allowed.

SketchUp Ruby's synchronous host-thread execution plus the second host-state validation is the atomicity model. No Observer architecture.

### 2.3 B1.5 evidence

Later B1.5 tests must prove:
- public method only;
- no `current_workspace_for_test`;
- no external `instance_variable_get`;
- same source/workspace IDs across tuple;
- exact topology membership;
- topology epsilon == captured execution epsilon;
- graph tolerance digest == expected captured legacy tolerance digest;
- structure canonical_graph_digest == exact graph.digest;
- analysis/source coherence passes;
- zero host/source geometry mutation;
- host mismatch => BLOCKED/no bundle.

B1.2–B1.4 do NOT implement this method.

## 3. DIGEST-01 — exact identity domain

### 3.1 Candidate top-level object

```json
{
  "schema_version": "pcd.v1",
  "dataset_id": "...",
  "content_digest": "...",
  "content": {},
  "build_evidence_digest": "...",
  "build_evidence": {},
  "validation": null
}
```

### 3.2 Exact semantic hash domain

The ONLY object hashed for `content_digest` is:

```json
{
  "identity_schema_version": "pcd-semantic-identity.v1",
  "dataset_schema_version": "pcd.v1",
  "content": {}
}
```

Compute:
`content_digest = SHA256(identity_bytes(the_object_above))`.

Explicitly excluded:
- dataset_id;
- content_digest itself;
- build_evidence;
- build_evidence_digest;
- validation;
- validation diagnostics;
- payload byte count;
- session/timestamp evidence outside semantic content.

### 3.3 Dataset ID

`dataset_id = "pcd-" + first 20 lowercase hex chars(content_digest)`.

Retain full content_digest.

If one truncated dataset_id maps to a different full content digest in a build context:
`dataset_id_truncation_collision` => BLOCKED.

### 3.4 Build-evidence digest

Hash exactly:

```json
{
  "identity_schema_version": "pcd-build-evidence-identity.v1",
  "content_digest": "<already-final semantic digest>",
  "build_evidence": {}
}
```

`build_evidence_digest = SHA256(identity_bytes(...))`.

Exclude build_evidence_digest itself and validation.

Equivalent semantic content in another session:
- same content_digest and dataset_id;
- build_evidence/build_evidence_digest may differ.

### 3.5 Validation binding

Validation never defines semantic identity.

Every validation must contain:
- validated_content_digest;
- validated_build_evidence_digest;
- validator_version;
- readiness/checks/blockers/warnings.

`with_validation` rejects unless BOTH digests match the candidate.

### 3.6 Candidate -> final

Candidate already has final:
- content;
- content_digest;
- dataset_id;
- build_evidence;
- build_evidence_digest.

Finalization only attaches validation and MUST NOT change any of those five fields.

No candidate/final semantic digest circularity.

### 3.7 Persisted payload

The deterministic persisted JSON is the COMPLETE final top-level object:
schema_version + dataset_id + content_digest + content + build_evidence_digest + build_evidence + validation.

The <=8 MiB gate measures exact UTF-8 bytes of that final persisted JSON.

Measured bytes stay out-of-band.

Changing validation/build evidence may change persisted bytes but not semantic identity.
Changing semantic content changes content_digest/dataset_id except for a cryptographic hash collision.

### 3.8 Golden regression

Hard-code one semantic content fixture and assert exact:
- identity bytes;
- SHA-256 content_digest;
- dataset_id.

Also prove:
- validation A/B => same content identity;
- build evidence A/B => same semantic identity;
- differing build evidence => differing evidence digest;
- one semantic field changed => different semantic identity;
- candidate/final => same semantic identity.

## 4. Truncated semantic-ID collision hardening

For all semantic ID families:
`pcn`, `pce`, `pch`, `pcl`, `pcr`, `pcrp`, and dataset_id:

retain the full SHA-256 during build and map:
`truncated_id -> full_digest + semantic_record`.

If a truncated ID is reused by a different full digest/semantic record:
`semantic_id_truncation_collision` => BLOCKED.

Never append a counter or use a legacy ID tie-break.

## 5. Required new regressions

COHERENCE:
- wrong topology schema;
- duplicate/extra/missing topology endpoints;
- topology-group vs graph-member mismatch;
- membership_count mismatch;
- epsilon mismatch against execution;
- graph node epsilon mismatch;
- graph tolerance digest mismatch;
- graph execution-config digest mismatch;
- workflow graph digest mismatch;
- nested incomplete PID same entity_id but distinct instance_path handled distinctly;
- nested incomplete PID without instance_path => BLOCKED.

DIGEST:
- exact hash-domain Golden;
- evidence changes do not change semantic identity;
- validation changes do not change semantic identity;
- semantic changes do;
- stale validation rejected after evidence change;
- candidate/final semantic identity unchanged;
- final persisted payload includes evidence/validation while semantic hash excludes them.

TRUNCATION:
- use a fake digest seam to force same prefix/different full digest => BLOCKED.

## 6. Gate

Until real Codex xHigh returns:

```text
VERDICT: PASS
SAFE TO DISPATCH B1.2-B1.4: YES
```

remain:

```text
B1.2 = HOLD
B1.3 = HOLD
B1.4 = HOLD
B1.5 = NOT_AUTHORIZED FOR IMPLEMENTATION
V1.9B2 = NOT_STARTED
V2 = NOT_STARTED
```

END
