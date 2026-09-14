# CURRENT PI DISPATCH — V1.9B1 B1.2–B1.4 PURE DATASET CONTRACT IMPLEMENTATION

Project: SU-AI-Plugin
Stage: V1.9B1 — PreparedCadDataset
Date: 2026-09-14
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Target branch: `dev/v1.9`

STATUS: ACTIVE

## Gate state

Real Codex xHigh final pre-build recheck:

```text
VERDICT: PASS
SAFE TO DISPATCH B1.2-B1.4: YES
```

Closed review blocks:
- B1-ID-03
- B1-ID-02-R1
- B1-COHERENCE-01-R2
- B1-STATE-01-R1
- B1-LIVE-BUNDLE-01
- B1-DIGEST-01

Frozen product state:

```text
V1.9A   = CLOSED_FROZEN
V1.9B0  = CLOSED_OWNER_PASS
B1.2    = AUTHORIZED
B1.3    = AUTHORIZED
B1.4    = AUTHORIZED
B1.5    = NOT_AUTHORIZED_FOR_IMPLEMENTATION
V1.9B2  = NOT_STARTED
V2      = NOT_STARTED
```

Current production baseline before B1 production code:
`839097a49b1bca3002beaa2f442a52f8db47e36e`

Remote `dev/v1.9` may contain documentation-only commits after that baseline.
Pi MUST record the actual starting HEAD after synchronization.

## Authoritative design order

Read in this order:

1. `PI_START_HERE.md`
2. `Prompt/CURRENT_PI_DISPATCH.md`
3. `Prompt/AIPM_V1_9B1_SOURCE_CONTRACT_MAPPING_BLUEPRINT_V1_2_2026-09-11.md`
4. `Prompt/AIPM_V1_9B1_BLUEPRINT_V1_3_FINAL_CORRECTION_ADDENDUM_2026-09-11.md`
5. `Prompt/CODEX_V1_9B1_V1_3_FINAL_RECHECK_PASS_2026-09-14.md`

v1.3 is authoritative over v1.2 wherever they conflict.

---

## 0. OWNER INTENT

Implement ONLY:

- B1.2 — `PreparedCadDataset` immutable value object, identity-byte encoder, deterministic persisted JSON serializer
- B1.3 — pure `PreparedCadDatasetBuilder`
- B1.4 — pure `PreparedCadDatasetValidator` / finalizer

STOP after:
- production source implementation
- host-free regression suite
- report
- commit + push

Do NOT:
- implement B1.5
- modify WorkingModeRunner
- add persistence
- add Accept/Load UI
- package RBZ
- begin V1.9B2
- begin V2/MCP/LLM/Agent

---

# 1. FIRST ACTION

Before editing:

1. Verify branch `dev/v1.9`.
2. Synchronize with `origin/dev/v1.9`.
3. Record exact starting HEAD.
4. Confirm tracked working tree is clean.
5. Read all authoritative documents above in full.
6. Confirm no unexplained changes exist in frozen production files.

If anything is ambiguous or a frozen file appears required: STOP and return to AIPM.

---

# 2. ALLOWED PRODUCTION FILES

Preferred new files only:

```text
extension/su_ai_plugin/core/prepared_cad_dataset.rb
extension/su_ai_plugin/core/prepared_cad_dataset_builder.rb
extension/su_ai_plugin/core/prepared_cad_dataset_validator.rb
```

Focused B1 tests under `tests/` are allowed.

A small private serializer/helper may live in one of the three B1-owned modules.
Do not create unnecessary architecture.

---

# 3. FROZEN EXISTING PRODUCTION FILES

B1.2–B1.4 MUST NOT modify existing V1.5–V1.9A modules, including:

```text
source_snapshot.rb
source_fingerprint.rb
execution_config_snapshot.rb
working_mode_runner.rb
planar_normalization_*
gap_*
canonical_topology_builder.rb
canonical_geometry_graph.rb
canonical_structure_reconstructor.rb
cad_prep_workflow_orchestrator.rb
cad_prep_workflow_presenter.rb
dialog_runner.rb
ui_bridge.rb
html/*
Probe/*
dist/*
```

No tolerance change.
No Source CAD mutation.
No derived-host mutation.
No Observer architecture.
No Face generation.

The v1.3 authorization for ONE additive `WorkingModeRunner.capture_prepared_cad_input_bundle` method applies to FUTURE B1.5 only and is NOT authorized in this dispatch.

---

# 4. B1.2 — PREPARED DATASET

Implement:

```ruby
SUAnalysis::Core::PreparedCadDataset
```

Top-level shape:

```text
schema_version
dataset_id
content_digest
content
build_evidence_digest
build_evidence
validation
```

Candidate: `validation = nil`

Final: same semantic/evidence fields, non-nil validation.

## 4.1 Semantic digest domain

The ONLY semantic hash object is:

```text
{
  "identity_schema_version" => "pcd-semantic-identity.v1",
  "dataset_schema_version"  => "pcd.v1",
  "content"                 => normalized_semantic_content
}
```

```text
content_digest = SHA256(identity_bytes(object))
dataset_id = "pcd-" + first20(content_digest)
```

EXCLUDED:
- dataset_id
- content_digest itself
- build evidence
- build_evidence_digest
- validation
- serialized byte count
- session/timestamp evidence outside semantic content

## 4.2 Build evidence digest

Hash exactly:

```text
{
  "identity_schema_version" => "pcd-build-evidence-identity.v1",
  "content_digest"          => content_digest,
  "build_evidence"          => build_evidence
}
```

Exclude build_evidence_digest itself and validation.

Equivalent semantic content from another session: same content_digest/dataset_id; build_evidence_digest may differ.

## 4.3 Identity byte encoder

Use the v1.2 type-disjoint grammar:

```text
nil      N;
false    B0;
true     B1;
Integer  I<len>:<decimal>;
Float    F<16 lower-case IEEE754 big-endian hex>;
String   S<byte_len>:<raw valid UTF-8 bytes>;
Array    A<count>:[...];
Hash     H<count>:{...};
```

Hash keys:
- String only
- sort by raw UTF-8 bytes

Float:
- finite only
- normalize -0.0 to +0.0
- Ruby 2.2-compatible `pack('G')`

No arbitrary `.to_s` fallback.

Identity encoder and persisted JSON serializer are separate contracts.

## 4.4 Deterministic persisted JSON

Public dataset remains ordinary JSON-safe data.

Persisted serializer:
- deterministic recursively sorted String-keyed Hashes
- valid UTF-8
- ordinary JSON numbers
- exact serializer later reused by B2

## 4.5 Deep immutability

Defensive deep copy + deep freeze.
No host objects.
No Symbol keys/values in final published dataset.

`with_validation` returns a NEW object and MUST verify BOTH:
- validated_content_digest
- validated_build_evidence_digest

Candidate/final semantic identity must remain identical.

## 4.6 Truncated-ID collision hardening

For `pcn`, `pce`, `pch`, `pcl`, `pcr`, `pcrp`, `dataset_id`, retain full digest internally during build.

Same truncated prefix + different full digest/semantic record => `semantic_id_truncation_collision` => BLOCKED.

Never append counters or use legacy IDs as tie-break.

---

# 5. B1.3 — PURE BUILDER

Implement:

```ruby
SUAnalysis::Core::PreparedCadDatasetBuilder
```

Public API:

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

Builder:
- explicit-input only
- no Runner access
- no SketchUp API
- no host mutation
- no input mutation

Return:

Success:
```text
status = BUILT
dataset = unvalidated PreparedCadDataset
```

Coherence/design failure:
```text
status = BLOCKED
dataset = nil
blockers = [...]
```

Do not use `NOT_READY` for Builder failure.

---

# 6. BUILDER COHERENCE PREFLIGHT

Before semantic projection require all v1.2/v1.3 coherence checks.

At minimum:
- workflow state == ready
- topology schema == `cano-node.v1`
- topology endpoint keys unique
- exact topology endpoint set == union of graph-node endpoint_keys
- exact topology canonical-node membership == graph node memberships
- membership counts agree
- source snapshot IDs agree across workflow/graph/structure
- workspace IDs agree across workflow/graph/structure
- structure canonical_graph_digest == supplied graph.digest
- graph schema == cgg.v1
- structure schema == csr.v1
- execution source schema version agrees
- topology epsilon == normalized captured execution coordinate_epsilon
- graph-node epsilons agree
- graph tolerance_digest == recomputed current-production legacy tolerance digest
- graph execution_config_digest == current expected production value
- workflow graph/structure digest evidence, when present, agrees
- AnalysisResult <-> SourceSnapshot coherence projection agrees
- source-secondary registry edge IDs resolve exactly

Unknown/missing/contradictory evidence => BLOCKED.

## 6.1 Incomplete PID coherence

Complete non-empty PID path: stable semantic source ref allowed.

Incomplete PID: current-session coherence only.

For nested occurrence:
- entity_id required
- structural_depth required
- partial PID path required as captured
- instance_path required and non-empty
- layer/kind evidence exact

Ambiguous nested incomplete occurrence => BLOCKED.

Transient evidence MUST NOT enter semantic content.

---

# 7. SEMANTIC SOURCE / EXECUTION NORMALIZATION

Do not use legacy SourceFingerprint digest as semantic identity.

B1 source semantic projection:
- per-edge endpoint geometry
- per-face structural facts
- per-layer machine facts
- stable complete source PID refs only
- deterministic orientation/order
- preserve multiplicity
- no order-sensitive edge_length_sum
- no transient entity IDs

Execution normalizes exact fixed tolerance key set:
- duplicate
- short_edge
- gap_search
- coordinate_epsilon
- big_z
- large_coordinate
- planar_z_snap

Symbol/String forms normalize to String keys.
Missing/unknown/collision/malformed => BLOCKED.

Normalize session_overrides recursively per v1.2.
Unsupported arbitrary object => BLOCKED.

---

# 8. SEMANTIC GEOMETRY ID REMAP

Legacy IDs are input addressing/evidence only.

Do NOT publish as semantic identity:
- derived IDs
- endpoint keys
- canonical node/edge IDs
- legacy chain/loop/region IDs
- repair/proposal/action IDs
- transient occurrence IDs

Node:
- resolve every graph node member through topology endpoints
- use all current member coordinates
- require clique agreement within epsilon
- semantic XYZ independent from endpoint-key order
- topology-refined semantic label per v1.2
- unresolved semantic symmetry => BLOCKED

Edge:
- semantic node IDs
- semantic facts only
- collision => BLOCKED

Adjacency: rebuild from semantic edges.

Chain: canonical forward/reverse traversal.

Loop: canonicalize all rotations + reverse orientations.

Region: remap through semantic loop IDs.

Do not publish:
- edge.world_endpoints
- loop.world_coordinates

Do not copy raw legacy ID-bearing diagnostics into semantic content.

---

# 9. CURRENT ISSUE / READINESS INPUT NORMALIZATION

Do NOT copy AnalysisResult IssueRegistry wholesale.

Historical repaired families do not resurrect:
- duplicate_edge_candidate
- significant_non_zero_z
- open_endpoint
- gap_candidate

Secondary source warnings allowed:
- short_edge
- abnormal_large_coord
- deep_nesting

Issue refs only:
- pcd_node
- pcd_edge
- complete source_pid_path

No source_entity_ids, raw entity_id/object_id, raw analysis edge ID, raw legacy IDs or transient occurrence IDs in content.

No stable ref => refs=[].

---

# 10. B1.4 — VALIDATOR / FINALIZER

Implement:

```ruby
SUAnalysis::Core::PreparedCadDatasetValidator
```

Preferred:

```ruby
outcome = PreparedCadDatasetValidator.validate_and_finalize(
  dataset: candidate,
  workflow_snapshot: workflow_snapshot
)
```

Final readiness only:

```text
NOT_READY
READY_WITH_WARNINGS
READY
```

Rule:
- any blocker => NOT_READY
- no blocker + warning => READY_WITH_WARNINGS
- no blocker/warning => READY

Unknown/missing/malformed state must fail closed.

---

# 11. WORKFLOW STATE MATRIX

Workspace: ONLY `ready` is acceptable.

Duplicate:
- tolerance_status MUST be `captured`
- `actions` array required
- every row status exactly applied/skipped/failed
- recompute counts from action rows
- counts must match summary
- last_action_status consistency required
- unknown/missing/raw-only rows => NOT_READY
- failed > 0 => NOT_READY
- skipped > 0, no blocker => warning

Planar:
- NO_CANDIDATE clean
- READY_TO_NORMALIZE blocker
- REVIEW_REQUIRED warning
- APPLIED clean
- invalid_tolerance blocker
- invalid_input blocker
- FAILED blocker
- NOT_COMPUTED blocker
- unknown/missing/contradiction blocker

Gap:
- NO_CANDIDATE clean
- READY_TO_REPAIR blocker
- REVIEW_REQUIRED warning
- APPLIED clean
- FAILED blocker
- NOT_COMPUTED blocker
- unknown/missing/contradiction blocker

Structure:
- READY clean
- READY_WITH_WARNINGS warning
- FAILED blocker
- NOT_COMPUTED blocker
- unknown/missing/contradiction blocker

---

# 12. VALIDATOR STRUCTURAL CHECKS

At minimum:
- dataset/source/execution schema checks
- source_content_digest recompute
- execution_context_digest recompute
- content_digest recompute
- dataset_id exact derivation
- build_evidence_digest recompute
- only JSON-safe published values
- valid UTF-8
- no Symbol keys/values
- no live host objects
- unique semantic IDs
- node xyz exactly 3 finite values
- edge refs resolve
- adjacency valid/symmetric/consistent
- chain refs resolve
- loop refs resolve
- region refs resolve
- issue refs typed + resolve
- forbidden duplicate coordinate fields absent
- no transient/host IDs in semantic content
- current workflow readiness matrix
- validation dual-digest binding

---

# 13. <= 8 MiB FINAL PAYLOAD GATE

Exact sequence:

1. Builder returns candidate with validation=nil.
2. Run all non-size validation.
3. Build tentative final validation with fixed-shape persistence PASS.
4. Attach validation.
5. Serialize EXACT complete final top-level dataset with deterministic persisted JSON serializer.
6. Measure UTF-8 `.bytesize`.
7. `<= 8_388_608` => persistence check stays PASS.
8. `> 8_388_608` => rebuild validation with blocker `persistence_envelope_unverified`, finalize NOT_READY.
9. Measured byte count stays OUT-OF-BAND and is not persisted in the payload being measured.

No self-reference.

---

# 14. REQUIRED HOST-FREE TEST EVIDENCE

Implement all v1.2 + v1.3 required regressions.

Minimum categories:

### Identity/canonical bytes
- exact Golden identity bytes + SHA
- -0.0 normalization
- UTF-8/control chars
- invalid UTF-8 fail closed
- Hash order independence
- Float vs Hash type distinction
- content change changes semantic digest
- evidence/validation changes do not
- candidate/final same semantic identity
- stale validation rejected after evidence change

### Source/execution
- source-edge reorder stable
- no edge_length_sum semantic dependence
- Symbol/String tolerance normalization
- unknown/missing tolerance key BLOCKED
- session override collision/unsupported type BLOCKED

### Coherence
- topology schema mismatch
- duplicate/extra/missing endpoints
- topology/graph membership mismatch
- epsilon mismatch
- graph tolerance digest mismatch
- graph execution digest mismatch
- source/workspace/structure digest mismatch
- Analysis/Source mismatch
- registry edge mismatch
- nested incomplete-PID occurrence ambiguity

### Semantic ID/remap
- perturb legacy IDs/traversal/proposal IDs/transient occurrence IDs => same semantic content
- node representative independent from endpoint-key order
- chain reversal canonical
- loop rotation/reversal canonical
- region remap stable
- semantic ambiguity BLOCKED
- forced truncated-prefix collisions BLOCKED

### Readiness
- every explicit state
- unknown/missing/malformed/computed-state contradiction
- duplicate action/count/last-status contradictions

### Safety
- Builder/Validator mutate no inputs
- zero SketchUp dependency
- no V2 road/building/green-space semantic fabrication

---

# 15. TEST EXECUTION

Tests must ACTUALLY run.

Report:
- exact Ruby executable path
- `ruby -v`
- syntax commands
- focused B1 suite counts
- any broader regression command/counts

Do NOT claim Ruby 2.2 runtime PASS unless actually executed on Ruby 2.2.
Design is Ruby-2.2-aware; current available validation runtime may be Ruby 2.7.8.

Known pre-existing full-suite failures in unchanged V1.9A UI/capability/test-order surfaces must be identified as pre-existing, not hidden or misreported as full PASS.

---

# 16. VERSION CONTROL

Commit and push to `dev/v1.9`.

Before push record:
- `git status`
- `git diff --stat`
- exact changed filenames from starting HEAD

Allowed production delta should be B1-owned new modules only.

No RBZ.

---

# 17. STOP CONDITIONS

STOP if:
- WorkingModeRunner appears required now
- any frozen existing production module appears required
- a second topology snapshot is needed
- a legacy ID seems necessary as semantic tie-break
- an unknown state cannot be classified
- coherence cannot be proven with explicit inputs
- tests cannot actually run
- persistence/UI integration becomes necessary
- B1.5/B2/V2 scope begins to leak in

Do not invent around a STOP condition.

---

# 18. PI RETURN REPORT

Return:

A. actual starting HEAD
B. final commit SHA
C. exact changed files
D. confirmation v1.2 + v1.3 + Codex PASS read
E. B1.2 implementation summary
F. identity-byte serializer + persisted JSON serializer summary
G. exact semantic hash domain/dataset_id semantics
H. build-evidence digest / validation binding
I. B1.3 Builder/coherence summary
J. semantic ID/remap summary
K. B1.4 readiness/finalization summary
L. 8 MiB exact final-payload gate behavior
M. exact Ruby path/version
N. exact tests and counts
O. Ruby 2.2 compatibility audit
P. diff/status evidence
Q. confirmation no frozen existing production module changed
R. known limitations

Return state:

```text
V1_9A = CLOSED_FROZEN
V1_9B0 = CLOSED_OWNER_PASS
V1_9B1_B1_2 = COMPLETE | BLOCKED
V1_9B1_B1_3 = COMPLETE | BLOCKED
V1_9B1_B1_4 = COMPLETE | BLOCKED
V1_9B1_B1_5 = NOT_AUTHORIZED
V1_9B2 = NOT_STARTED
V2 = NOT_STARTED
```

Then STOP. Do not begin B1.5.

END
