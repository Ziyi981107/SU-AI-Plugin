# CURRENT PI DISPATCH — V2-0B SOURCE REVIEW R2 CORRECTION

Date: 2026-09-17
Project: SU-AI-Plugin
TARGET_BRANCH: dev/v2
STATUS: ACTIVE

## Authority

V2-0A = CLOSED / PASS.

V2-0B original implementation:

`8c59b1908ade02897938c1e4b479b9b7d444333f`

V2-0B R1 correction under review:

`a43c34c151148c969bf2443cfe466864802ec63d`

AIPM direct source review:

`Review/CURRENT_AIPM_REVIEW.md`

Current correction authority:

`Prompt/AIPM_V2_0B_SOURCE_REVIEW_R2_CORRECTION_2026-09-17.md`

Frozen Stage Blueprint remains authoritative:

`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md`

## Before work

```bash
git fetch origin
git switch dev/v2
git pull --ff-only origin dev/v2
```

Verify:

- branch is `dev/v2`;
- local == latest `origin/dev/v2` before editing;
- R1 commit `a43c34c151148c969bf2443cfe466864802ec63d` is an ancestor of HEAD;
- `Prompt/AIPM_V2_0B_SOURCE_REVIEW_R2_CORRECTION_2026-09-17.md` exists locally after pull;
- `Review/CURRENT_AIPM_REVIEW.md` says V2-0B R2 correction required;
- this dispatch is ACTIVE.

If any check fails, STOP.

## Execute ONLY R2

Read:

1. `PI_START_HERE.md`
2. `AGENTS.md`
3. `PROJECT_HANDOFF.md`
4. `PROJECT_MASTER_PLAN_V1X.md`
5. `CURRENT_STATE.md`
6. `Review/CURRENT_AIPM_REVIEW.md`
7. `Prompt/CURRENT_PI_DISPATCH.md`
8. `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md`
9. `Prompt/AIPM_V2_0B_SOURCE_REVIEW_R1_CORRECTION_2026-09-16.md`
10. `Prompt/AIPM_V2_0B_SOURCE_REVIEW_R2_CORRECTION_2026-09-17.md`

Implement exactly:

- R2-01 real SketchUp root-Group parent authority;
- R2-02 exact ownership identity/digest post-validation;
- R2-03 truthful production-default V1 handoff -> Stage0B integration proof.

## Allowed production scope

Only if required:

- `extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb`
- `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

Do not change `host_operation_guard.rb` behavior without STOP/report.

Allowed tests/probe:

- `tests/test_v2_stage0b_host_mass_probe.rb`
- `Probe/v2_stage0b_owner_probe.rb` only if necessary to preserve probe compatibility.

Completion docs:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

Do NOT modify V1 production, V2-0A production, Loader/UI/Tool/HtmlDialog, Residential Stage 1, MCP/LLM/Agent.

If scope expansion is required, STOP with:

`V2_0B_R2_SCOPE_EXPANSION_REQUIRED`

## Acceptance

Must prove:

- real top-level SketchUp Group is accepted by `parent == model` / equivalent correct host authority; nested group rejected;
- wrong-but-non-empty `footprint_id_full` rejected;
- wrong-but-non-empty `source_content_digest` rejected;
- exact ownership values accepted;
- one runtime integration test genuinely runs the real/default `WorkingModeRunner.capture_prepared_cad_input_bundle -> PreparedCadDatasetBuilder -> PreparedCadDatasetValidator -> SemanticFootprintProjector -> Stage0B` pure-data path, with only host boundary faked;
- no fake capture/build/validate/projector lambdas in that truthful integration case;
- all existing R1 transaction/freshness/rollback contracts remain green;
- no new full-runner fail/error beyond established 5 fail / 4 error debt.

## Stop rule

After implementation/tests:

1. update `CURRENT_STATE.md`;
2. update `Review/CURRENT_PI_REPORT.md`;
3. commit + push only `dev/v2`;
4. STOP;
5. do NOT run real SU2020 Owner probe;
6. do NOT start Residential Stage 1;
7. do NOT invoke Codex.

Control returns to AIPM source review.

END
