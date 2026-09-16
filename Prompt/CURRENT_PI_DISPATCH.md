# CURRENT PI DISPATCH — V2-0B SOURCE REVIEW R1 CORRECTION

Date: 2026-09-16
Project: SU-AI-Plugin
TARGET_BRANCH: dev/v2
STATUS: ACTIVE

## Authority

V2-0A = CLOSED / PASS.

V2-0B implementation commit under correction:

`8c59b1908ade02897938c1e4b479b9b7d444333f`

AIPM direct source review:

`Review/CURRENT_AIPM_REVIEW.md`

Correction authority:

`Prompt/AIPM_V2_0B_SOURCE_REVIEW_R1_CORRECTION_2026-09-16.md`

Frozen Stage Technical Blueprint remains authoritative except where the correction packet explicitly tightens evidence/implementation to satisfy the same Blueprint:

`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md`

## Before work

```bash
git fetch origin
git switch dev/v2
git pull --ff-only origin dev/v2
```

Verify:

- current branch is `dev/v2`;
- local == latest `origin/dev/v2` before editing;
- implementation commit `8c59b1908ade02897938c1e4b479b9b7d444333f` is an ancestor of HEAD;
- `Review/CURRENT_AIPM_REVIEW.md` says V2-0B NOT PASS / R1 correction required;
- R1 correction file exists;
- this dispatch is ACTIVE.

If not, STOP.

## Execute ONLY the R1 correction

Read in order:

1. `PI_START_HERE.md`
2. `AGENTS.md`
3. `PROJECT_HANDOFF.md`
4. `PROJECT_MASTER_PLAN_V1X.md`
5. `CURRENT_STATE.md`
6. `Review/CURRENT_AIPM_REVIEW.md`
7. `Prompt/CURRENT_PI_DISPATCH.md`
8. `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md`
9. `Prompt/AIPM_V2_0B_SOURCE_REVIEW_R1_CORRECTION_2026-09-16.md`

Implement R1-01 through R1-06 exactly.

Allowed production files only:

- `extension/su_ai_plugin/v2/host_operation_guard.rb`
- `extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb`
- `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

Allowed test/probe files:

- `tests/test_v2_stage0b_host_mass_probe.rb`
- `Probe/v2_stage0b_owner_probe.rb`

Completion docs:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

Do not modify any V1 production file or V2-0A production file.

If another production file is required, STOP with:

`V2_0B_R1_SCOPE_EXPANSION_REQUIRED`

## Non-negotiable acceptance

The corrected packet must prove:

- real default B1.5 capture bundle -> real default Builder -> real default Validator -> real V2-0A projector works with fake host;
- no construction exception after start can escape without exactly one abort attempt;
- confirmed rollback leaves guard READY;
- unconfirmed rollback locks guard HOST_STATE_UNCERTAIN;
- real SketchUp Vertex-shaped `position` coordinates are post-validated correctly;
- complete Blueprint §9 post-validation exists;
- no hidden epsilon fallback;
- success result carries the host-only generated group handle;
- geometry is built from the fresh re-resolved current footprint;
- Owner injected-failure probe actually creates geometry first, then fails before commit so abort removes real geometry;
- focused fake abort mechanically restores/removes generated V2 group on confirmed rollback;
- no production `failure_stage` switch.

## Validation

Run all validation listed in the R1 correction packet.

No new fail/error is acceptable relative to the established full-runner 5 fail / 4 error debt.

## Stop rule

After correction implementation and required tests:

1. update `CURRENT_STATE.md`;
2. update `Review/CURRENT_PI_REPORT.md`;
3. commit + push only `dev/v2`;
4. STOP;
5. do NOT run Owner real SU2020 probe;
6. do NOT start Residential Stage 1;
7. do NOT invoke Codex yourself.

Control returns to AIPM direct source review.

END
