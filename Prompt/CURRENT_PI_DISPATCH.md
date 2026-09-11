# CURRENT PI DISPATCH — V1.9B1 B1.2–B1.4 PURE DATASET CONTRACT IMPLEMENTATION

Project: SU-AI-Plugin
Stage: V1.9B1 — PreparedCadDataset
Date: 2026-09-11
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Target branch: `dev/v1.9`

STATUS: ACTIVE

Frozen stage state:
- V1.9A = CLOSED_FROZEN
- V1.9B0 = CLOSED / OWNER PASS
- AttributeDictionary route = ACCEPTED_FOR_B1_B2
- verified persistence envelope = <= 8 MiB on real SketchUp 2020
- V1.9B1 PRE-BUILD DESIGN REVIEW = PASS
- SAFE TO DISPATCH B1.2-B1.4 = YES
- B1.5 = NOT AUTHORIZED
- V1.9B2 = NOT STARTED
- V2 / MCP / LLM / Agent = NOT STARTED

Production baseline before B1 production source implementation:
`839097a49b1bca3002beaa2f442a52f8db47e36e`

Authoritative design:
`Prompt/AIPM_V1_9B1_SOURCE_CONTRACT_MAPPING_BLUEPRINT_V1_0_2026-09-11.md`

Codex pre-build PASS:
`Prompt/CODEX_V1_9B1_PREBUILD_DESIGN_REVIEW_RESULT_2026-09-11.md`

---

## 0. PURPOSE

Implement ONLY the pure B1 contract foundation:

- B1.2 — `PreparedCadDataset` value object + deterministic canonical serializer
- B1.3 — pure `PreparedCadDatasetBuilder`
- B1.4 — pure `PreparedCadDatasetValidator`

STOP after implementation, host-free tests, commit/push, and Pi report.

DO NOT:
- integrate with live `WorkingModeRunner`;
- implement B1.5;
- persist a dataset;
- add Accept/load/store behavior;
- change Presenter/UI;
- rebuild RBZ;
- begin V1.9B2;
- begin V2/MCP/LLM/Agent.

---

## 1. FIRST ACTION

Before editing:

1. Read `PI_START_HERE.md`.
2. Read this file.
3. Read the authoritative B1 Blueprint.
4. Read the Codex PASS record.
5. Verify `dev/v1.9` and record actual starting HEAD.
6. Confirm no unexplained local production edits.

If unexplained edits exist in frozen production files: STOP.

---

## 2. ALLOWED PRODUCTION FILES

Preferred new files only:

```text
extension/su_ai_plugin/core/prepared_cad_dataset.rb
extension/su_ai_plugin/core/prepared_cad_dataset_builder.rb
extension/su_ai_plugin/core/prepared_cad_dataset_validator.rb
```

Focused new tests under `tests/` are allowed.

A small private canonical serializer may live inside `prepared_cad_dataset.rb`.
Do not create extra framework layers unless strictly necessary.

---

## 3. FROZEN EXISTING PRODUCTION SOURCE

Do NOT modify existing V1.5–V1.9A production modules, including:

- SourceSnapshot / SourceFingerprint / ExecutionConfigSnapshot / LayerRecord
- WorkingModeRunner
- Planar proposer/executor
- Gap proposer/executor
- CanonicalTopologyBuilder / CanonicalGeometryGraph
- CanonicalStructureReconstructor
- CadPrepWorkflowOrchestrator
- Presenter / dialog_runner / ui_bridge / HTML frontend
- tolerance authority
- Probe/V1_9B0
- dist/RBZ

If B1.2–B1.4 appears to require any frozen existing module change: STOP and report the exact dependency to AIPM.

---

## 4. B1.2 — PREPARED DATASET VALUE OBJECT

Implement a pure Ruby value object:

```ruby
SUAnalysis::Core::PreparedCadDataset
```

Required logical fields:

```text
schema_version
content_digest
dataset_id
content
build_evidence
validation
```

Frozen semantics:

- published contract is deeply immutable;
- defensive copies on construction;
- JSON-safe primitives only;
- String Hash keys only in final published data;
- no SketchUp objects / host handles / Ruby object IDs;
- no wall-clock/random identity;
- `content_digest` is SHA-256 of deterministic canonical JSON of `content` ONLY;
- `dataset_id = "pcd-" + first 20 hex chars of content_digest`;
- `build_evidence` and `validation` do NOT affect semantic identity.

Never use `SourceSnapshot.snapshot_id`, `workspace_id`, current CanonicalGeometryGraph digest, or V1.8 structure digest as PreparedCadDataset semantic identity.

### Canonical serializer

Use one deterministic serializer shared by B1 components:

- recursively sort Hash keys;
- reject unsupported values rather than arbitrary `.to_s` coercion;
- allow only String / Integer / finite Numeric / true / false / nil / Array / String-keyed Hash;
- no Symbol values in final dataset;
- no NaN / Infinity;
- use `JSON.generate` + SHA-256;
- preserve traversal order for chain/loop node_ids and edge_ids;
- Builder must normalize set-like arrays deterministically before serialization.

Ruby 2.2 aware: no Array#sum, Hash#compact, Numeric#positive?, safe-navigation `&.`, filter_map, transform_keys, yield_self/then, or other modern-only APIs/syntax.

### Validation attachment

Preferred pure API:

```ruby
validated_dataset = candidate.with_validation(validation_hash)
```

Return a NEW immutable dataset; never mutate candidate. If `validated_content_digest` is supplied and does not match, fail closed.

---

## 5. B1.3 — PURE BUILDER

Implement:

```ruby
SUAnalysis::Core::PreparedCadDatasetBuilder
```

Preferred API:

```ruby
PreparedCadDatasetBuilder.build(
  source_snapshot:,
  workflow_snapshot:,
  canonical_graph:,
  structure_result:,
  analysis_result:
)
```

Explicit inputs only.

Forbidden:
- global Runner reads;
- Runner private ivars / `instance_variable_get`;
- SketchUp API;
- live host reads;
- input mutation.

Build canonical `content` sections exactly per Blueprint:

```text
source
execution
coordinate_context
layer_semantics
canonical_geometry
structures
repair_history
unresolved_issues
provenance_summary
```

and separate `build_evidence`.

Critical frozen mappings:

### Source / execution
- source content identity uses source fingerprint + selection scope identity, not `snapshot_id`;
- exclude captured timestamps from content identity;
- compute B1-local `execution_context_digest` over normalized ExecutionConfig machine fields excluding `captured_at`;
- DO NOT add/modify legacy `ExecutionConfigSnapshot#digest`.

### Coordinates
- canonical node XYZ is the ONLY coordinate authority in PreparedCadDataset v1;
- node output uses `node_id` + `xyz` + provenance/flags;
- edge output references `node_a_id` / `node_b_id`;
- dataset edge MUST NOT publish `world_endpoints`;
- dataset loop MUST NOT publish `world_coordinates`;
- active edit transform is provenance/context only; do not re-transform node XYZ;
- no B1 unit conversion.

### Layer semantics
Persist machine fields only:
`layer_name`, `role`, `role_rule`, `visible`, `visibility_unknown`.
No localized labels and no V2 road/building/land-use semantics.

### Structures
Project chain/loop/region IDs and references from current V1.8 result. Existing length/area/perimeter/winding may be retained only under clearly non-authoritative `derived_metrics`.

### Repair history
Persist only the compact durable fields specified by Blueprint. Do not deep-copy arbitrary legacy audit blobs. Omit `applied_at` from canonical content identity.

### Current unresolved issues
Do NOT copy AnalysisResult.registry wholesale.

These historical source issue families are superseded by current deterministic stage state and MUST NOT resurrect:

```text
duplicate_edge_candidate
significant_non_zero_z
open_endpoint
gap_candidate
```

These source-registry secondary classes may remain warnings:

```text
short_edge
abnormal_large_coord
deep_nesting
```

Issue records are machine-readable only: code, class, source, count, reason_codes, entity_refs.

### Build evidence
Keep session/current-run evidence separate and excluded from content digest:
`source_snapshot_id`, `workspace_id`, upstream graph digest, upstream structure digest, source captured_at, graph/structure schema versions.

---

## 6. B1.4 — PURE VALIDATOR

Implement:

```ruby
SUAnalysis::Core::PreparedCadDatasetValidator
```

Preferred API:

```ruby
validation = PreparedCadDatasetValidator.validate(
  dataset: candidate,
  workflow_snapshot: workflow_snapshot
)
```

Return a deeply frozen JSON-safe String-keyed Hash with:

```text
validator_version = pcd-validator.v1
validated_content_digest
readiness
checks
blockers
warnings
summary
```

Readiness:

```text
blocker exists -> NOT_READY
no blocker + warning exists -> READY_WITH_WARNINGS
no blocker + no warning -> READY
```

Minimum validation:

- supported dataset schema;
- source fingerprint / execution identity present;
- supported coordinate contract;
- unique node IDs;
- every node xyz exactly 3 Numeric finite values;
- unique edge IDs + valid node refs;
- no edge world_endpoints;
- adjacency only known nodes and consistent/symmetric with edge graph;
- unique chain/loop/region IDs;
- all structure refs resolve;
- no loop world_coordinates;
- provenance strings valid;
- only JSON-safe primitives in final tree;
- content digest recomputes exactly;
- dataset_id matches digest;
- canonical serializer repeatable;
- workflow readiness gates;
- 8 MiB verified persistence envelope.

Structural/schema contradiction is always a blocker even if upstream says READY.

### Persistence-size gate

For B1.4, measure the serialized candidate payload WITHOUT attached validation to avoid circularity. Record measured bytes in validation evidence.

If candidate bytes > 8 MiB:

`persistence_envelope_unverified` blocker.

This means only that the Owner-verified AttributeDictionary envelope currently covers <=8 MiB; do not claim >8 MiB necessarily fails SketchUp.

---

## 7. WORKFLOW READINESS POLICY

Use the frozen Blueprint policy:

Duplicate:
- required stage missing -> blocker
- actions_failed > 0 -> blocker
- actions_skipped > 0 -> warning

Planar:
- NOT_COMPUTED / INVALID_TOLERANCE / FAILED / READY_TO_NORMALIZE -> blocker
- REVIEW_REQUIRED -> warning
- NO_CANDIDATE / APPLIED -> clean

Gap/topology:
- NOT_COMPUTED / FAILED / READY_TO_REPAIR -> blocker
- REVIEW_REQUIRED -> warning
- NO_CANDIDATE / APPLIED -> clean

Structure:
- NOT_COMPUTED / FAILED -> blocker
- READY_WITH_WARNINGS -> warning(s) using existing reason codes
- READY -> clean

Workspace state not `ready` -> blocker for production-ready dataset candidate.

Do not invent unknown semantics.

---

## 8. CODEX FOLLOW-UP PRECONDITION — HOLD FOR B1.5

Codex PASS included one explicit later requirement:

B1.5 must resolve build-time-vs-live-time coordinate freshness before publishing a production dataset candidate.

DO NOT solve that in this packet by touching Runner/graph production code.

For B1.2–B1.4:
- Builder trusts the explicit canonical_graph argument it is given as its input object;
- tests prove node-only authority inside that input;
- B1.5 remains a separate held packet.

---

## 9. REQUIRED HOST-FREE REGRESSION MINIMUM

Tests must cover at least:

1. deep immutability / JSON-safe only;
2. same semantic content -> byte-identical canonical JSON + same digest/id;
3. differing snapshot_id/workspace_id/upstream digests do not alter content identity;
4. captured_at differences do not alter execution/content identity;
5. node-only coordinate authority; edge world_endpoints absent; loop world_coordinates absent;
6. duplicate IDs / invalid refs / malformed or nonfinite xyz -> NOT_READY;
7. invalid adjacency -> NOT_READY;
8. clean rectangle -> READY;
9. repaired Owner-style Z+Gap fixture -> READY;
10. pending safe Z -> NOT_READY;
11. pending safe Gap -> NOT_READY;
12. non-ready workspace -> NOT_READY;
13. Planar/Gap/Structure NOT_COMPUTED -> NOT_READY;
14. review-only ambiguity -> READY_WITH_WARNINGS;
15. short_edge / abnormal_large_coord / deep_nesting -> READY_WITH_WARNINGS;
16. repaired historical Z/gap/open-endpoint registry evidence does not resurrect;
17. duplicate repair failure -> NOT_READY;
18. duplicate skipped action -> READY_WITH_WARNINGS if no blocker;
19. execution_context_digest stable across captured_at;
20. digest recomputation + dataset-id derivation;
21. >8 MiB -> persistence_envelope_unverified;
22. Builder/Validator perform zero host mutation and do not mutate inputs;
23. no V2 semantic labels fabricated.

Fixtures must reflect actual current V1 shapes rather than convenient incompatible mock schemas.

---

## 10. TEST EXECUTION

Tests must ACTUALLY run.

Report:
- exact Ruby executable path;
- `ruby -v`;
- exact commands;
- exact pass/fail counts.

Minimum:
- `ruby -c` on each new production Ruby file;
- focused B1.2/B1.3/B1.4 tests.

Full V1.x rerun is not required because frozen shared production modules must not change.

Do NOT claim real SketchUp 2017 PASS; only legacy-aware / Ruby-2.2-aware implementation unless real host evidence exists.

---

## 11. VERSION CONTROL

Commit + push to `dev/v1.9`.

Commit may contain only:
- the three allowed new production modules;
- focused B1 tests;
- normal Pi state/report documentation required by governance.

No RBZ.

Before push record `git status`, `git diff --stat`, and changed filenames. Confirm no frozen existing production source changed.

---

## 12. STOP CONDITIONS

STOP if:
- WorkingModeRunner modification is needed;
- Builder needs Runner private state;
- graph/structure algorithm change is needed;
- a second coordinate authority seems necessary;
- identity seems to require snapshot_id/workspace_id;
- current issue policy is ambiguous;
- tests cannot actually run;
- Ruby 2.2 compatibility requires frozen module changes;
- persistence/UI/Accept integration seems necessary;
- V2 semantics are needed.

Return the ambiguity to AIPM instead of expanding scope.

---

## 13. RETURN REPORT

Return:

- starting HEAD + final commit SHA;
- exact changed files;
- confirmation Blueprint + Codex PASS read;
- B1.2/B1.3/B1.4 implementation summaries;
- exact identity/digest behavior;
- evidence that snapshot_id/workspace_id/upstream digests are excluded from semantic identity;
- evidence of node-only coordinate authority;
- issue synthesis behavior;
- 8 MiB gate behavior;
- exact Ruby path/version/commands/test counts;
- Ruby 2.2 compatibility audit;
- changed-file evidence showing no frozen production source changed;
- limitations / unresolved questions.

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

Then STOP.

END
