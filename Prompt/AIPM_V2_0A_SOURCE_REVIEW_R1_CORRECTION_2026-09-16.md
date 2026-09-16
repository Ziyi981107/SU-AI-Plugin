# AIPM V2-0A SOURCE REVIEW R1 CORRECTION

Date: 2026-09-16
Project: SU-AI-Plugin
Target branch: `dev/v2`
Status: FROZEN CORRECTION
Final Product Owner: Owner
Technical authority: ChatGPT / AIPM

## 0. Review verdict

AIPM direct source review of implementation commit
`d947a7899a1b04ddb545b159603cf2b09b392070` is **NOT PASS**.

The V2-0A architecture remains valid. This packet is a narrow implementation correction only.

No V1 production file may be modified.
No V2-0B work may start.

## 1. V2-0A-SR-01 — real PreparedCadDataset schema mismatch

The implementation currently validates synthetic schema names:

- content: `pcd-content.v1`
- semantic graph: `semantic-graph.v1`

The real V1.9 `PreparedCadDatasetBuilder` publishes:

- content schema: `pcd.v1`
- semantic graph schema: `pcd-semantic-graph.v1`

Correction:

- `LayerLocalGraphAdapter` MUST consume the actual published V1 contract.
- Expected content schema MUST be `pcd.v1`.
- Expected semantic graph schema MUST be `pcd-semantic-graph.v1`.
- Use named constants rather than duplicated hard-coded literals in the checks.
- Do NOT modify the V1 Builder or `pcd.v1`.

Required regression:

A real public V1 handoff fixture MUST be captured/built/validated using the existing public path and then passed directly to V2-0A without patching its content/schema.

At minimum the real-integration test must prove:

`WorkingModeRunner.capture_prepared_cad_input_bundle`
→ `PreparedCadDatasetBuilder.build`
→ `PreparedCadDatasetValidator.validate_and_finalize`
→ READY or READY_WITH_WARNINGS
→ `SemanticFootprintProjector.project`
→ one expected footprint.

If a smaller existing public helper/fixture already exercises the exact same public Builder+Validator path, it may be reused. Do not synthesize the PCD schema manually for this integration proof.

## 2. V2-0A-SR-02 — fake-final test fixture / readiness gate

Current focused tests manually call `PreparedCadDataset#with_validation` with a synthetic validation Hash. This proves only `final?`, not that the dataset is V1 READY for V2.

The real `PreparedCadDataset#final?` contract is only `validation != nil`; a Validator NOT_READY result can therefore still carry a final dataset.

Correction:

V2-0A input usability MUST require all of:

1. real `PreparedCadDataset` instance;
2. `final? == true`;
3. validation is a Hash;
4. validation blockers is an Array and is empty;
5. validation `persistence_check.status == 'PASS'`.

Warnings are allowed.

Add a stable V2 blocker such as:

`v2_llga:pcd_not_ready`

for finalized-but-not-usable datasets.

Do not redesign V1 validation. Do not add a new V1 status field.

Test requirements:

- real READY / READY_WITH_WARNINGS finalized PCD → allowed;
- finalized PCD with non-empty blockers → BLOCKED;
- finalized PCD with persistence FAIL/missing → BLOCKED;
- candidate (`validation == nil`) → BLOCKED as before.

Synthetic geometry fixtures may remain for the geometry matrix, but they MUST use the actual `pcd.v1` / `pcd-semantic-graph.v1` schemas and a helper that creates a contract-valid usable final PCD. The required real handoff integration test above is the authoritative proof.

## 3. V2-0A-SR-03 — explicit Set dependency

`LayerLocalGraphAdapter` calls `Set.new` but does not require Ruby stdlib `set`.

Correction:

Add:

`require 'set'`

in the production file that owns the dependency.

Do not rely on test-runner or unrelated-file load order.

Required regression:

Add an isolated-load test/process or equivalent source/runtime proof that V2 adapter/projector can be required and project a simple valid fixture without any earlier test requiring `set`.

## 4. V2-0A-SR-04 — Ruby 2.2 compatibility in new V2 code

`SemanticFootprint.build` currently uses `String#match?` for the full digest format check. V2-0A Blueprint §9 requires SketchUp 2017+ / Ruby 2.2-era compatibility.

Correction:

Replace NEW V2 usages of Ruby helpers unavailable in Ruby 2.2 with Ruby-2.2-compatible equivalents.

For the digest format check, use a Ruby-2.2-compatible regex path such as `Regexp#match` / `=~` plus the existing length/type gate as appropriate.

Audit all three new V2 production files for newly introduced post-Ruby-2.2 helpers.

Do NOT reopen or modify pre-existing V1 production compatibility debt in this packet.

Required regression/source guard:

- no `String#match?` in the three V2-0A production files;
- no safe navigation, `filter_map`, `transform_keys`, `Array#sum`, `Numeric#positive?`, pattern matching, or other post-baseline helper introduced by this packet.

## 5. V2-0A-SR-05 — EMPTY semantics for known layer with zero edges

The frozen Blueprint §6 says `EMPTY` means a mapped layer exists in the PCD layer inventory / graph context but yields no buildable footprint.

Current adapter reports `UNKNOWN_MAPPED_LAYER` when the layer is known through the node inventory but contributes zero edges.

Correction:

Do not label a known layer as unknown.

Preferred narrow behavior:

- unknown layer → adapter BLOCKED `v2_llga:unknown_mapped_layer`;
- known layer with zero matching edges → return a valid empty layer-local projection (or another explicit non-error adapter result) such that the projector returns `EMPTY`;
- no reconstructor exception may escape for this case.

Do not introduce geometry repair.

Required tests:

- unknown layer → BLOCKED;
- known layer, zero matching edges → projector `EMPTY`, no footprint, no rejection, no blocker.

## 6. Existing contracts that remain frozen

Do NOT change:

- exact edge-layer matching;
- filtered-edge multiplicity preservation;
- adjacency rebuild from filtered edges;
- V1.8 `CanonicalStructureReconstructor` authority;
- Stage-0A region acceptance rules;
- z <= epsilon inclusive ground-plane policy;
- local z=0 projection;
- SemanticFootprint dataset-relative identity concept;
- no-host / no-SketchUp contract;
- no V1 production-file modification;
- no V2-0B / Residential / UI / MCP work.

## 7. Allowed files

Production:

- `extension/su_ai_plugin/v2/layer_local_graph_adapter.rb`
- `extension/su_ai_plugin/v2/semantic_footprint.rb`
- `extension/su_ai_plugin/v2/semantic_footprint_projector.rb`

Test:

- `tests/test_v2_stage0a_semantic_footprint.rb`

A minimal additional V2-0A test helper file is allowed only if required to isolate process/load-order behavior. No V1 production file.

Docs on completion:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

## 8. Required validation

Run:

1. V2-0A focused suite including all original 35 tests plus new correction regressions;
2. real public V1→PCD→V2 integration proof;
3. V1.7 relevant regressions;
4. V1.8 structure reconstruction;
5. V1.9 B1 PreparedCadDataset regression;
6. V1.9 B1.5 live bundle regression;
7. project full runner and compare failures to pre-correction baseline;
8. syntax checks;
9. `git diff --check`.

No existing test may be weakened, deleted, skipped, or rewritten to hide the real PCD schema mismatch.

## 9. Completion gate

R1 is complete only when:

- real V1 public READY PCD passes directly into V2-0A;
- actual schemas are consumed without patching;
- NOT_READY finalized PCD is rejected;
- Set dependency is explicit;
- new V2 code satisfies Ruby 2.2-era helper contract;
- known-zero-edge layer returns EMPTY rather than UNKNOWN;
- original Stage-0A geometry matrix remains green;
- no V1 production file changed;
- AIPM direct source review passes.

Pi must STOP after R1 and return to AIPM. Do not invoke Codex and do not start V2-0B.

END
