# CURRENT PI DISPATCH — V2-0B OWNER GATE ONE-CLICK PROBE

Date: 2026-09-17
Project: SU-AI-Plugin
TARGET_BRANCH: dev/v2
STATUS: ACTIVE

## Authority

V2-0A = CLOSED / PASS.

V2-0B R2 implementation reviewed:

`5a3c8cd02cad1948a46901b80f5463f6d994bfff`

AIPM direct source review verdict:

`PASS — SOURCE GATE CLOSED`

Current task authority:

`Prompt/AIPM_V2_0B_OWNER_GATE_ONE_CLICK_PROBE_2026-09-17.md`

Frozen Stage Blueprint remains:

`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md`

## Before work

```bash
cd "D:/Projects/SU-AI-Plugin"
git fetch origin
git switch dev/v2
git pull --ff-only origin dev/v2
```

Verify:

- branch is `dev/v2`;
- local == latest `origin/dev/v2`;
- R2 implementation `5a3c8cd02cad1948a46901b80f5463f6d994bfff` is an ancestor of HEAD;
- `Prompt/AIPM_V2_0B_OWNER_GATE_ONE_CLICK_PROBE_2026-09-17.md` exists locally;
- this dispatch is ACTIVE.

If any check fails, STOP.

## Execute ONLY Owner-Gate Probe Usability Task

Read the normal bootstrap stack from `PI_START_HERE.md`, then implement exactly:

`Prompt/AIPM_V2_0B_OWNER_GATE_ONE_CLICK_PROBE_2026-09-17.md`

Goal:

Add Probe-only one-click Owner entry points so the Owner can run the remaining real-SU2020 host gate without manually constructing `SemanticFootprint`, `AnalysisResult`, PCD, Runner, Builder, Validator, or Projector objects.

Preferred Owner calls after loading the Probe file:

```ruby
SUAnalysis::Probe::V2Stage0BOwnerProbe.run_success_one_click
SUAnalysis::Probe::V2Stage0BOwnerProbe.run_injected_failure_one_click
```

## Frozen production

NO production file may change.

In particular, do NOT modify:

- `extension/su_ai_plugin/v2/host_operation_guard.rb`
- `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`
- `extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb`
- any V1 production file
- any V2-0A production file

If a production change appears necessary, STOP with:

`V2_0B_OWNER_GATE_PROBE_PRODUCTION_CHANGE_REQUIRED`

## Allowed files

Implementation:

- `Probe/v2_stage0b_owner_probe.rb`

Tests:

- new `tests/test_v2_stage0b_owner_probe.rb`, preferred; or minimal focused additions to the existing Stage-0B test if repository conventions require it.

Completion docs:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

## Core acceptance

Must prove:

1. one-click success wrapper uses the SAME production Stage0B + HostOperationGuard + real V2SketchupMassAdapter host path;
2. Owner supplies no footprint / analysis_result;
3. Probe-only synthetic freshness seams do NOT touch/reset WorkingModeRunner;
4. success path creates exactly one root V2 probe Group and returns `SUCCESS`;
5. console tells Owner to press native Undo exactly once and verify complete Group disappearance;
6. one-click injected-failure delegates to the real adapter first, then raises before commit;
7. confirmed abort yields `FAILED_ROLLED_BACK` and zero surviving probe Group;
8. no production file changed;
9. no new full-runner fail/error beyond established 5 fail / 4 error baseline.

## Forbidden

Do NOT:

- run real SU2020 Owner test yourself;
- reset/prepare/discard WorkingModeRunner from the one-click wrapper;
- modify source CAD or V1 Derived Workspace;
- start Residential Stage 1;
- add Loader/UI/Tool/HtmlDialog changes;
- add MCP/LLM/Agent;
- invoke Codex;
- push/merge main;
- force-push;
- tag/release.

## Completion

After implementation and required tests:

1. update `CURRENT_STATE.md`;
2. update `Review/CURRENT_PI_REPORT.md`;
3. commit + push only `dev/v2`;
4. STOP and return control to AIPM.

Completion state is:

`OWNER-GATE PROBE READY — PENDING AIPM SOURCE REVIEW + OWNER REAL SU2020 TEST`

END
