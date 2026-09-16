# AIPM V2-0B SOURCE REVIEW R1 CORRECTION

Date: 2026-09-16
Project: SU-AI-Plugin
Target branch: `dev/v2`
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Status: FROZEN CORRECTION CONTRACT

## 0. Verdict and intent

Reviewed implementation commit:

`8c59b1908ade02897938c1e4b479b9b7d444333f`

AIPM direct source review verdict:

`NOT PASS — CORRECTION REQUIRED BEFORE REAL SU2020 OWNER TEST`

V2-0A remains CLOSED / PASS.
V2-0B architecture remains frozen.
No Residential Stage 1 work is authorized.

This correction is narrow. It closes real production/host-probe defects found in the Stage-0B implementation. Do not redesign the Stage.

## 1. R1-01 — wire the REAL V1 public bundle into the REAL Builder/Validator

Current production `Stage0BMassProbe#_default_build_seam` does NOT match the frozen B1.5 bundle/Builder contract.

The real B1.5 capture bundle publishes:

- `source_snapshot`
- `workflow_snapshot`
- `topology_snapshot`
- `canonical_graph`
- `structure_result`
- `analysis_result`

The real `PreparedCadDatasetBuilder.build` accepts exactly those authorities (plus optional test-only truncation context).

The current Stage-0B default build seam incorrectly attempts to call the Builder with projection keys such as `source_projection`, `execution`, `semantic_graph`, `semantic_structure`, `current_issues`, `coherence_evidence`.

CORRECTION:

- `_default_build_seam(bundle)` MUST call the real Builder with the actual B1.5 public bundle keys.
- Validator workflow authority MUST default from `bundle['workflow_snapshot']`, not `bundle['workflow']`.
- No synthetic projection-shape adaptation may become the production default seam.
- Any capture/build/validate exception before `start_operation` must fail closed with zero host mutation rather than escaping the public Stage-0B result contract.

Required evidence:

- a test that uses the REAL `WorkingModeRunner.capture_prepared_cad_input_bundle`;
- the REAL default `_default_build_seam`;
- the REAL default `_default_validate_seam`;
- real `SemanticFootprintProjector`;
- fake host only for the SketchUp write surface;
- no injected fake Builder/Validator in this integration test.

The previous `V2-S0B-INT01` is NOT sufficient because it replaces capture/build/validate with lambdas returning a prebuilt synthetic dataset.

## 2. R1-02 — no construction exception may escape after operation start

Current `Stage0BMassProbe#run` calls `@adapter.build_mass(...)` without an outer rescue.

Any unexpected adapter/SketchUp exception after a confirmed start can therefore escape before Stage0B attempts abort.

This violates the frozen rule:

> after operation start, every construction/post-validation failure must attempt abort exactly once.

CORRECTION:

- Wrap the construction call at the orchestration boundary.
- Any `StandardError` raised by `adapter.build_mass` after confirmed start must be converted into a construction failure and go through exactly one `guard.abort(model)` attempt.
- abort true -> `FAILED_ROLLED_BACK`.
- abort false/raise -> `HOST_STATE_UNCERTAIN` + session lock.
- Never rescue exceptions before start in a way that causes an abort attempt for an operation that was never confirmed open.

Required tests:

- adapter raises immediately after start -> exactly one abort attempt;
- confirmed abort -> FAILED_ROLLED_BACK;
- abort false/raise -> HOST_STATE_UNCERTAIN;
- no open operation remains in the fake after confirmed abort.

## 3. R1-03 — real SketchUp post-validation must validate real SketchUp entity shapes

Current mass-adapter post-validation is not real-SketchUp-correct.

### 3.1 Vertex coordinate access

Real `Sketchup::Face#vertices` / `Sketchup::Edge#vertices` return `Sketchup::Vertex` objects. A SketchUp Vertex exposes its coordinates through `vertex.position` (`Geom::Point3d`), not `vertex.z`.

Current `_z_of` does not read `vertex.position`, so real SU vertices can collapse to fallback `0.0` during validation and make a valid extrusion fail post-validation.

CORRECTION:

`_z_of` / vertex extraction must support:

- real `Sketchup::Vertex#position`;
- test coordinate arrays;
- any already-supported Point3d-like test shape.

### 3.2 Complete Blueprint §9 checks

Post-validation MUST actually verify all frozen requirements:

- group valid / not deleted;
- group is a ROOT entity under the current model (for real SketchUp, `Entity#parent` may be used; top-level parent is the Model);
- generated group contains at least one Face AND at least one Edge;
- at least one generated vertex is within `coordinate_epsilon` of z=0;
- at least one generated vertex is within `coordinate_epsilon` of z=probe_height;
- no generated vertex below `-coordinate_epsilon`;
- max-z within epsilon of probe_height;
- all FOUR ownership values round-trip exactly:
  - schema_version
  - kind
  - footprint_id_full
  - source_content_digest

The current implementation only checks the first two ownership fields and does not prove root ownership / face+edge presence / base and top vertex existence.

### 3.3 No hidden epsilon

The adapter currently falls back to `1.0e-6` when footprint epsilon is absent.

This is forbidden.

`footprint['coordinate_epsilon']` MUST be Numeric, finite, > 0 before mutation; it is the only post-validation geometry tolerance.

Missing/invalid epsilon must fail before `start_operation`.

Required tests:

- real-Vertex-shaped fake exposing `position` but not `z` succeeds;
- missing/invalid epsilon blocks before start;
- group not root -> post-validation failure -> rollback;
- no Face -> rollback;
- no Edge -> rollback;
- no z≈0 vertex -> rollback;
- no z≈height vertex -> rollback;
- footprint/digest ownership mismatch -> rollback.

## 4. R1-04 — HostOperationGuard rollback/lock semantics must match the frozen contract

Current `HostOperationGuard#commit` calls `lock!` even when commit fails but the subsequent abort returns literal true.

That contradicts the frozen contract:

- commit false/raise + abort true -> `COMMIT_FAILED_ROLLED_BACK`;
- confirmed rollback means host state is known and the session MUST remain READY;
- ONLY abort false/raise (or otherwise unconfirmed rollback) may enter `HOST_STATE_UNCERTAIN`.

CORRECTION:

- confirmed abort after commit failure MUST NOT lock the session;
- abort false/raise MUST lock;
- explicit `abort` true after construction failure MUST leave the session READY;
- operation-method availability/exception paths must never return `HOST_STATE_UNCERTAIN` while leaving the guard unlocked/open;
- use literal Boolean identity semantics (`equal?(true)` or equivalent exact Boolean check) for start/commit/abort results.

Correct the existing OP09 expectation: it must assert `COMMIT_FAILED_ROLLED_BACK` AND `guard.uncertain? == false`.

Add/adjust tests proving a second write is allowed after confirmed rollback and blocked only after uncertain rollback.

## 5. R1-05 — build from the CURRENT re-resolved footprint and return the host handle on success

The freshness gate re-resolves the exact current footprint, but current production discards that matched record and builds from the caller's original footprint.

CORRECTION:

- `_freshness_check` must return the matched CURRENT SemanticFootprint (or an equivalent internal result carrying it).
- geometry construction must consume that re-resolved current footprint.
- successful public result must include the generated Group handle as the explicitly host-only `group` field because the Owner probe consumes it.
- no host handle may be serialized/persisted into PCD or model metadata.

Required test:

- success result contains the same group handle created by the adapter.

## 6. R1-06 — Owner injected-failure probe must actually mutate then rollback

Current `PushpullRaisingAdapterDecorator` comments say it raises after mutation begins, but the implementation raises before calling the real adapter at all.

Worse, because R1-02 is currently missing, that exception can escape with an open operation.

CORRECTION:

The Owner injected-failure path must:

1. use the SAME production `Stage0BMassProbe`;
2. use the SAME real `V2SketchupMassAdapter` for actual geometry mutation;
3. cause a failure AFTER V2 geometry has been created inside the open operation but BEFORE commit;
4. let the production Stage0B exception boundary invoke abort;
5. expect `FAILED_ROLLED_BACK` on confirmed abort;
6. leave zero V2 probe group visible after confirmed rollback.

A simple acceptable Probe-only strategy is:

- decorator calls the real adapter's `build_mass(...)` completely;
- require the delegated result is success / geometry exists;
- then raise a Probe-only exception before Stage0B can commit.

That proves rollback removes already-created valid geometry without adding a production `failure_stage` switch.

Do not monkey-patch global SketchUp classes.

## 7. Required focused regression changes

The corrected focused suite must prove all of the following in addition to the prior matrix:

1. REAL default V1 capture -> REAL Builder -> REAL Validator -> real projector -> fake host Stage0B SUCCESS;
2. unexpected adapter exception after start -> abort exactly once;
3. confirmed commit-failure rollback does NOT lock session;
4. unconfirmed rollback DOES lock session;
5. real-Vertex-shaped `position` coordinates are understood;
6. complete post-validation matrix from §3;
7. success result contains host-only group handle;
8. Owner injected-failure decorator actually delegates to the real adapter first, then raises;
9. fake abort for the injected-failure proof restores the fake root-entity snapshot so zero-residue rollback is mechanically asserted.

Do not weaken existing 28 tests merely to make the new implementation green.

## 8. Allowed files

Production corrections are limited to the existing Stage-0B files:

- `extension/su_ai_plugin/v2/host_operation_guard.rb`
- `extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb`
- `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

Test/probe corrections:

- `tests/test_v2_stage0b_host_mass_probe.rb`
- `Probe/v2_stage0b_owner_probe.rb`

State/report after completion:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

Do NOT modify:

- any V1 production file;
- any V2-0A production file;
- pcd.v1;
- CanonicalStructureReconstructor;
- Loader/UI/Tool/HtmlDialog;
- Residential Stage 1;
- MCP/LLM/Agent.

If another production file appears necessary, STOP with:

`V2_0B_R1_SCOPE_EXPANSION_REQUIRED`

## 9. Required validation

At minimum:

- syntax checks on all three corrected production files + test + Owner probe;
- complete corrected V2-0B focused suite;
- V2-0A 43/43;
- V1.7 relevant regression;
- V1.8 structure regression;
- V1.9 B1 PreparedCadDataset regression;
- V1.9 B1.5 live bundle regression;
- full runner compared to established 5 fail / 4 error debt;
- Ruby-2.2-era source compatibility guard;
- `git diff --check`;
- RBZ rebuild + smoke if the corrected production sources are packaged.

No new fail/error.

## 10. Gate

Pi must NOT perform the real Owner SU2020 probe.

After R1 implementation:

1. Pi updates state/report, commits and pushes `dev/v2`, then STOPs.
2. AIPM performs direct source/diff review.
3. If source review passes, AIPM may request a narrow Codex host-contract recheck if still warranted.
4. Only then does Owner run the real SU2020 success + injected-failure probes.

V2-0B remains OPEN until Owner confirms:

- success mass exists;
- one native Undo removes the entire success mass;
- injected failure returns confirmed rollback;
- injected-failure visible residue = zero.

END
