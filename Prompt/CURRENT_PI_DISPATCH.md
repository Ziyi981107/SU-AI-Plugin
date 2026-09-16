# CURRENT PI DISPATCH — V2-0A SOURCE REVIEW R2 TEST-PROOF MICRO-CORRECTION

Date: 2026-09-16
Project: SU-AI-Plugin
TARGET_BRANCH: dev/v2
STATUS: ACTIVE

## Baseline / authority

R1 production implementation:

`e722638c9863ec2f1a8d562a34a3ec92491d2354`

R1 report/docs submission:

`24c3e68aba386f96e01c042a8f9aae00a87beeb4`

AIPM R1 source-review verdict: **NOT PASS — ONE TEST-EVIDENCE RESIDUAL ONLY**.

Execute only:

`Prompt/AIPM_V2_0A_SOURCE_REVIEW_R2_TEST_PROOF_CORRECTION_2026-09-16.md`

The frozen V2-0A Blueprint and R1 correction remain authoritative for all unchanged behavior.

## Before work

Fetch and fast-forward to current remote before editing:

```bash
git fetch origin
git switch dev/v2
git pull --ff-only origin dev/v2
```

Then verify:

- branch is `dev/v2`;
- local `dev/v2 == origin/dev/v2`;
- R1 implementation `e722638c9863ec2f1a8d562a34a3ec92491d2354` is an ancestor of HEAD;
- this dispatch is ACTIVE;
- R2 correction file exists.

If not, STOP and report to AIPM.

## Current stage

V1 = CLOSED / frozen.
V2-0A R1 production corrections = PRESERVE.
V2-0A R2 test-proof residual = ACTIVE.
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
9. `Prompt/AIPM_V2_0A_SOURCE_REVIEW_R2_TEST_PROOF_CORRECTION_2026-09-16.md`

## Execute ONLY R2-01

The current `V2-S0A-R1-07` isolated child-process proof is vacuous because it only requires the adapter and checks method/constant presence. It never calls `LayerLocalGraphAdapter.project`, so the `Set.new` adjacency path is not exercised.

Fix the test so a fresh child Ruby process:

- does NOT explicitly `require 'set'`;
- constructs a minimal usable FINAL PCD with actual V1 schemas;
- includes at least one mapped edge;
- calls real `LayerLocalGraphAdapter.project(dataset:, layer_name: 'L0')`;
- reaches adjacency rebuild / `Set.new`;
- asserts `PROJECTED`, non-empty graph, and expected adjacency;
- would fail if production `require 'set'` were removed.

## Allowed files

Substantive implementation change:

- `tests/test_v2_stage0a_semantic_footprint.rb` ONLY.

Completion docs:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

Production files: NONE.

If production modification appears necessary, STOP with:

`V2_0A_R2_PRODUCTION_SCOPE_EXPANSION_REQUIRED`

## Required validation

Run:

1. syntax check for the test file;
2. complete V2-0A focused suite, preserving all prior 43 tests;
3. explicit non-vacuous child-process projection proof;
4. V1.7 `V17-` regression;
5. V1.8 `V18-` regression;
6. V1.9B1 `B1.2-` regression;
7. V1.9B1 `B15-` regression;
8. full runner vs established `5 fail / 4 error` baseline;
9. `git diff --check`;
10. confirm no production file changed.

No RBZ rebuild required. No new fail/error acceptable.

## Frozen / forbidden

Do NOT modify production code.
Do NOT reopen the five R1 production corrections.
Do NOT modify V1.
Do NOT start V2-0B / Residential Stage 1.
Do NOT add host/UI/modeling/MCP/LLM/Agent work.
Do NOT invoke Codex.

## Completion

1. update `CURRENT_STATE.md`;
2. update `Review/CURRENT_PI_REPORT.md` with R2 evidence;
3. commit and push only `dev/v2`;
4. report implementation SHA + final remote HEAD;
5. STOP.

Next gate: AIPM narrow final source review.

END
