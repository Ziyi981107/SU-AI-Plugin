# CURRENT AIPM REVIEW — V2-0B DIRECT SOURCE REVIEW R1

Project: SU-AI-Plugin
Stage: V2-0B Host Geometry Probe
Date: 2026-09-16
Reviewer: ChatGPT / AIPM
Final Product Owner: Owner
Reviewed implementation: `8c59b1908ade02897938c1e4b479b9b7d444333f`

VERDICT: **NOT PASS — NARROW CORRECTION REQUIRED**
V2-0A: **CLOSED / PASS — DO NOT REOPEN**
V2-0B REAL SU2020 OWNER TEST: **HOLD**
RESIDENTIAL STAGE 1: **NOT STARTED**
CODEX: **NOT INVOKED — CORRECT SOURCE DEFECTS FIRST**

## Owner Summary

The implementation direction is correct, but the current source cannot yet be trusted on the real SU2020 gate.

The key issue is not test count. Several focused tests use fakes that do not match the actual V1 public bundle or real SketchUp Vertex shape, so 28/28 does not prove the real path.

AIPM found six narrow correction areas. No V2 architecture redesign is required.

## BLOCK R1-01 — production default V1 handoff is miswired

`Stage0BMassProbe#_default_build_seam` calls the real `PreparedCadDatasetBuilder.build` with the wrong keyword contract and projection-style bundle keys.

The real B1.5 public bundle contains `source_snapshot`, `workflow_snapshot`, `topology_snapshot`, `canonical_graph`, `structure_result`, `analysis_result`.

The real Builder accepts those same authority inputs.

The current focused `V2-S0B-INT01` does not catch this because it injects lambda capture/build/validate seams that return a synthetic prebuilt dataset.

Consequence: the default production/Owner path can fail before geometry creation despite the green integration test.

## BLOCK R1-02 — exceptions after start can escape without abort

`Stage0BMassProbe#run` calls `adapter.build_mass` without an outer rescue.

Any unexpected adapter/SketchUp exception after confirmed operation start can escape without the mandatory single abort attempt.

The current Owner injected-failure decorator actually raises before construction and therefore does not prove rollback of mutated geometry; with the current orchestrator the raise can escape while the operation is open.

## BLOCK R1-03 — post-validation is not real-SketchUp-complete

The adapter's `_z_of` does not support the real `Sketchup::Vertex#position` shape. Real SketchUp vertices expose their Point3d through `position`.

The current post-validation also omits required proof of:

- root ownership;
- Face + Edge presence;
- explicit base z≈0 vertex;
- explicit top z≈probe_height vertex;
- footprint_id_full attribute round-trip;
- source_content_digest attribute round-trip.

It also introduces a hidden fallback epsilon (`1e-6`) instead of requiring the footprint's frozen `coordinate_epsilon` authority.

## BLOCK R1-04 — confirmed rollback incorrectly locks the session

In `HostOperationGuard#commit`, commit failure followed by `abort_operation == true` returns `COMMIT_FAILED_ROLLED_BACK` but also calls `lock!`.

The frozen contract says confirmed rollback is known-safe and MUST NOT enter HOST_STATE_UNCERTAIN. Only unconfirmed rollback may lock later writes.

The current OP09 test encodes the implementation bug rather than the Blueprint: it expects the guard to be uncertain after confirmed rollback.

## BLOCK R1-05 — current footprint/host-handle result seam is incomplete

Freshness re-resolution finds a current matched footprint but discards it; construction still uses the caller's original footprint.

The success result also omits the generated Group handle even though the Owner probe reads `result['group']`.

V2-0B must build from the re-resolved current footprint and expose the generated group as a host-only result field.

## BLOCK R1-06 — Owner injected-failure proof is not yet a rollback proof

The probe comments promise failure after mutation has begun, but `_inject_failure_build_mass` raises immediately before real adapter construction.

The corrected probe must create real V2 geometry inside the open operation and then raise before commit, allowing the production exception boundary to abort and prove zero residue.

## Source facts accepted

The following direction remains correct and should not be redesigned:

- one normal non-transparent operation;
- model-root independent group;
- empty `add_group` then geometry inside group;
- +Z orientation before positive pushpull;
- ownership dictionary inside the same operation;
- full content_digest stale authority;
- exact footprint_id_full re-resolution;
- root-context checks before capture and immediately before start;
- V2 session uncertainty lock when rollback cannot be confirmed;
- V1 and V2-0A frozen boundaries.

## Automated evidence status

Pi reported:

- V2-0B focused 28/28 PASS;
- V2-0A 43/43 PASS;
- V1.7 127/127 PASS;
- V1.8 74/74 PASS;
- B1.2 83/83 PASS;
- B1.5 17/17 PASS;
- full runner 1495 / 1486 pass / 5 fail / 4 error with no new fail/error.

These are useful regression evidence, but they do not close the source-review BLOCKs above.

## Required correction authority

Pi must follow:

`Prompt/AIPM_V2_0B_SOURCE_REVIEW_R1_CORRECTION_2026-09-16.md`

No Owner real-SU test before the correction passes direct source review.

END
