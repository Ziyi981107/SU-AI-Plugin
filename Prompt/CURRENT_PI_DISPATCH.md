# CURRENT PI DISPATCH — V2-0A SOURCE REVIEW R1 CORRECTION

Date: 2026-09-16
Project: SU-AI-Plugin
TARGET_BRANCH: dev/v2
STATUS: ACTIVE

## Baseline / authority

V2-0A implementation commit under correction:

`d947a7899a1b04ddb545b159603cf2b09b392070`

AIPM direct source review verdict: **NOT PASS**.

The architecture remains frozen. Execute only the narrow correction in:

`Prompt/AIPM_V2_0A_SOURCE_REVIEW_R1_CORRECTION_2026-09-16.md`

Pi must fetch and fast-forward to current `origin/dev/v2` before work.

Do NOT use a self-referential exact-HEAD gate. Verify:

- branch is `dev/v2`;
- local `dev/v2 == origin/dev/v2` before editing;
- implementation commit `d947a7899a1b04ddb545b159603cf2b09b392070` is an ancestor of HEAD;
- frozen V2-0A Blueprint exists;
- R1 correction file exists;
- this dispatch is ACTIVE.

If these checks fail, STOP and report to AIPM.

## Current stage

V1 = CLOSED / frozen input authority.
PB-01..PB-06 = CLOSED.
V2-0A original implementation = SOURCE REVIEW NOT PASS.
V2-0A R1 correction = ACTIVE.
V2-0B = NOT STARTED.
V2 Residential Stage 1 = NOT STARTED.

## Mandatory read order

1. `PI_START_HERE.md`
2. `AGENTS.md`
3. `PROJECT_HANDOFF.md`
4. `PROJECT_MASTER_PLAN_V1X.md`
5. `CURRENT_STATE.md`
6. `Prompt/CURRENT_PI_DISPATCH.md`
7. `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0A_SEMANTIC_FOOTPRINT_2026-09-16.md`
8. `Prompt/AIPM_V2_0A_SOURCE_REVIEW_R1_CORRECTION_2026-09-16.md`

The R1 correction is authoritative over the original V2-0A implementation where they conflict. The original Blueprint remains authoritative for all unchanged architecture and acceptance rules.

## Execute ONLY these corrections

### R1-01 — real PCD schema + real handoff proof

Correct V2-0A to consume the actual published V1 schema:

- content schema = `pcd.v1`
- semantic graph schema = `pcd-semantic-graph.v1`

Do not modify V1.

Add a real public integration proof:

`WorkingModeRunner.capture_prepared_cad_input_bundle`
→ `PreparedCadDatasetBuilder.build`
→ `PreparedCadDatasetValidator.validate_and_finalize`
→ READY / READY_WITH_WARNINGS
→ `SemanticFootprintProjector.project`
→ expected footprint.

No schema patching or hand-built fake PCD for this authoritative integration test.

### R1-02 — usable validation/readiness

Do not treat `final?` alone as V2-ready.

V2 input must require:

- final PreparedCadDataset;
- validation Hash;
- validation blockers Array empty;
- persistence_check.status == `PASS`.

Warnings remain allowed.

Finalized NOT_READY / persistence-failed dataset must BLOCK.

### R1-03 — Set dependency

`LayerLocalGraphAdapter` uses `Set`; explicitly `require 'set'` in its production owner file.

Prove load-order independence.

### R1-04 — Ruby 2.2-era compatibility

Remove new V2 use of `String#match?` and any other newly introduced post-Ruby-2.2 helper from the three V2-0A production files.

Do NOT modify pre-existing V1 compatibility debt in this correction.

### R1-05 — EMPTY vs UNKNOWN

Unknown mapped layer → BLOCKED.

Known mapped layer with zero matching edges → projector `EMPTY`, not `unknown_mapped_layer`.

No exception and no invented geometry.

## Allowed production files

Only:

- `extension/su_ai_plugin/v2/layer_local_graph_adapter.rb`
- `extension/su_ai_plugin/v2/semantic_footprint.rb`
- `extension/su_ai_plugin/v2/semantic_footprint_projector.rb`

No existing V1 production file may change.

If a V1 production file appears necessary:
STOP and report `V2_0A_R1_SCOPE_EXPANSION_REQUIRED`.

## Allowed tests

Primary:

- `tests/test_v2_stage0a_semantic_footprint.rb`

One minimal additional V2-0A test helper/process file is allowed only if needed for isolated-load proof.

Do not weaken or delete the original 35 tests.

## Required validation

Run at minimum:

1. original + R1 V2-0A focused tests;
2. real V1 public handoff → V2 integration test;
3. isolated-load Set dependency proof;
4. V1.7 relevant reconstruction/topology;
5. V1.8 structure reconstruction;
6. V1.9 B1 PreparedCadDataset;
7. V1.9 B1.5 live bundle;
8. project full runner, comparing against the pre-R1 5 fail / 4 error baseline;
9. syntax checks;
10. `git diff --check`;
11. source compatibility guard for the three new V2 production files.

No new fail/error is acceptable.

## Frozen / forbidden

Do NOT:

- redesign SemanticFootprint identity;
- modify V1 / `pcd.v1`;
- modify shared `CanonicalStructureReconstructor`;
- implement SketchUp Group/Face/extrusion;
- implement V2HostOperationGuard;
- implement Tool/pickray/highlight;
- implement HtmlDialog/toolbar/menu;
- implement ResidentialObject / balcony association / floor modeling;
- implement Site / raised community / roads / landscape;
- implement MCP/LLM/Agent;
- start V2-0B;
- invoke Codex.

## Completion

After the full R1 correction is complete:

1. update `CURRENT_STATE.md` with V2-0A R1 status;
2. prepend/replace `Review/CURRENT_PI_REPORT.md` with exact R1 evidence;
3. commit and push only `dev/v2`;
4. report implementation SHA + final remote HEAD;
5. STOP.

AIPM direct source review is the next gate.

END
