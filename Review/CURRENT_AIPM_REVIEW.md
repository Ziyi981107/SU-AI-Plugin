# CURRENT AIPM REVIEW — V2-0B REAL SU2020 OWNER GATE FAIL

Project: SU-AI-Plugin
Stage: V2-0B Host Geometry Probe
Date: 2026-09-21
Reviewer: ChatGPT / AIPM
Final Product Owner: Owner

VERDICT: **NOT PASS — REAL HOST NAMESPACE BLOCK**
V2-0A: **CLOSED / PASS — DO NOT REOPEN**
V2-0B AUTOMATED/SOURCE EVIDENCE: **PREVIOUSLY PASS**
V2-0B REAL SU2020 OWNER TEST: **FAILED / CORRECTION REQUIRED**
RESIDENTIAL STAGE 1: **NOT STARTED**
CODEX: **NOT REQUIRED**

## Owner evidence

The Owner loaded the one-click Probe in real SketchUp 2020 and invoked:

`SUAnalysis::Probe::V2Stage0BOwnerProbe.run_success_one_click`

Real host returned:

`NameError: uninitialized constant SUAnalysis::V2::Stage0BMassProbe::V2SketchupMassAdapter`

The failure occurs in production `stage0b_mass_probe.rb` before intended geometry construction.

## Root cause

`Stage0BMassProbe` is defined under `SUAnalysis::V2`, while the adapter class is defined under:

`SUAnalysis::Compatibility::V2SketchupMassAdapter`

Production Stage0B directly uses unqualified `V2SketchupMassAdapter::...` references.

The focused test environment masked the bug because
`tests/test_v2_stage0b_host_mass_probe.rb` performs top-level:

`include SUAnalysis::Compatibility`

which pollutes constant lookup in tests but is absent from normal real SketchUp runtime.

## Duplicate-constant warnings

The Owner also saw `already initialized constant` warnings for V1 classes.

These came from having an installed AppData SU-AI-Plugin copy already loaded while also loading repository source with the developer Probe.

They are not the primary BLOCK and must not be “fixed” by namespace aliases or reload hacks.

For the next Owner retest, use a clean SU2020 session with the installed extension disabled/restarted before loading repo Probe source.

## Required correction

See:

`Prompt/AIPM_V2_0B_OWNER_GATE_R1_NAMESPACE_CORRECTION_2026-09-21.md`

Required production direction:

all Stage0B adapter constant references must be fully qualified to:

`SUAnalysis::Compatibility::V2SketchupMassAdapter`

A runtime namespace-isolation regression must prove the production path no longer relies on test pollution.

## Gate

STOP V2-0B closure.
Do not start Residential Stage 1.

After Pi correction:
1. AIPM direct source review;
2. clean-session real SU2020 success probe;
3. one native Undo => full Group disappears;
4. injected-failure probe => FAILED_ROLLED_BACK + zero residue.

Only then may V2-0B become CLOSED / PASS.

END
