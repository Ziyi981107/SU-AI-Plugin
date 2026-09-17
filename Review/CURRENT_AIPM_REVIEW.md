# CURRENT AIPM REVIEW — V2-0B DIRECT SOURCE REVIEW R2 REQUIRED

Project: SU-AI-Plugin
Stage: V2-0B Host Geometry Probe
Date: 2026-09-17
Reviewer: ChatGPT / AIPM
Final Product Owner: Owner
Reviewed R1 correction: `a43c34c151148c969bf2443cfe466864802ec63d`

VERDICT: **NOT PASS — THREE NARROW R2 RESIDUALS**
V2-0A: **CLOSED / PASS — DO NOT REOPEN**
V2-0B REAL SU2020 OWNER TEST: **HOLD**
RESIDENTIAL STAGE 1: **NOT STARTED**
CODEX: **NOT REQUIRED**

## Owner Summary

R1 correctly closes the major first-review defects: real B1.5 Builder wiring, post-start exception abort boundary, real Vertex#position Z reading, confirmed-vs-unconfirmed rollback lock semantics, current-footprint construction, host-only success Group handle, and mutate-then-abort injected-failure behavior.

Three residuals remain before real SU2020 testing. They are narrow and do not require architecture redesign.

## R2-01 — root Group parent authority is wrong

Current adapter checks real root ownership using `group.parent.nil?`.

SketchUp official Entity parent contract returns the containing Model / ComponentDefinition (narratively Model / ComponentDefinition / Group depending on containment). A top-level Group under `model.entities` therefore must be validated against the current Model, not nil.

Current code can reject a correct real-SU2020 root Group as `group_not_root`.

Required: validate root Group with current-model parent authority; fake host must mirror that real shape.

## R2-02 — ownership identity/digest check is non-empty-only

Current post-validation checks schema and kind exactly, but only verifies stored `footprint_id_full` and `source_content_digest` are non-empty.

Frozen Blueprint requires exact match to the current re-resolved SemanticFootprint.

Required: wrong-but-non-empty footprint ID or digest must fail before commit and rollback through the existing operation path.

## R2-03 — R1 INT02 is not truthful end-to-end default handoff

R1 production default Builder wiring is now correct.

However `V2-S0B-INT02` explicitly builds an empty-authority B1.5-shaped bundle and proves only that the real Builder returns canonical BLOCKED rather than raising due to bad keyword names. That is useful contract evidence, but it is not the required successful default:

`WorkingModeRunner.capture_prepared_cad_input_bundle -> PreparedCadDatasetBuilder -> PreparedCadDatasetValidator -> SemanticFootprintProjector -> Stage0B`

integration proof.

Required: reuse the already-proven truthful V2-0A runner fixture pattern and run Stage0B with default capture/build/validate/projector seams; only the SketchUp host boundary may be fake.

## R1 surfaces accepted / frozen

Do not reopen without new evidence:

- R1-01 production `_default_build_seam` keyword wiring itself;
- R1-02 unexpected post-start adapter exception -> exactly one abort attempt;
- R1-03 real `Sketchup::Vertex#position` Z reading;
- no hidden coordinate_epsilon fallback;
- R1-04 confirmed rollback keeps session READY; unconfirmed rollback locks;
- R1-05 geometry consumes current re-resolved footprint;
- success result exposes host-only Group handle;
- R1-06 Owner injected failure creates real geometry then raises before commit;
- V1 and V2-0A production boundaries remain frozen.

## Current automated evidence

Pi reports R1:

- V2-0B focused: 42/42 PASS;
- V2-0A: 43/43 PASS;
- V1.7: 127/127 PASS;
- V1.8: 74/74 PASS;
- B1.2: 83/83 PASS;
- B1.5: 17/17 PASS;
- full runner: 1509 tests / 1500 pass / 5 fail / 4 error;
- no new fail/error versus established debt.

These regressions are accepted but do not close R2-01..03.

## Required correction authority

Pi must follow:

`Prompt/AIPM_V2_0B_SOURCE_REVIEW_R2_CORRECTION_2026-09-17.md`

No real SU2020 Owner test until R2 passes direct AIPM source review.

END
