# AIPM V2-0B SOURCE REVIEW R2 CORRECTION

Date: 2026-09-17
Project: SU-AI-Plugin
Target branch: `dev/v2`
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Status: FROZEN CORRECTION CONTRACT

## 0. Verdict and intent

Reviewed R1 correction commit:

`a43c34c151148c969bf2443cfe466864802ec63d`

AIPM direct source review verdict:

`NOT PASS — THREE NARROW RESIDUALS REMAIN BEFORE REAL SU2020 OWNER TEST`

V2-0A remains CLOSED / PASS.
V2-0B architecture remains frozen.
No Product redesign.
No Residential Stage 1.
No Codex required for this correction.

This R2 packet closes only the three residuals below. Do not reopen already-correct R1-02, R1-04, R1-05, R1-06 behavior except where a test must be adjusted to keep the same contract.

---

## R2-01 — Real SketchUp root Group authority

### Defect

R1 implemented `_is_root_group?` using the assumption:

`group.parent.nil?`

That is not the real SketchUp Entity parent contract.

SketchUp official Ruby API documents `Sketchup::Entity#parent` as returning the containing `Sketchup::Model` or `Sketchup::ComponentDefinition` (and the narrative says Model / ComponentDefinition / Group depending on containment).

For a top-level Group created under `model.entities`, the root authority is the current Model, not `nil`.

Consequence:

A correct real-SU2020 root Group can be rejected as `group_not_root` before commit.

### Required correction

The real post-validation root test must prove:

- entity is a Group;
- entity belongs to the current target model;
- its parent authority represents the current Model/root rather than a nested ComponentDefinition / Group.

Preferred minimal contract:

- pass the current `model` explicitly into post-validation;
- require `group.parent == model` (or equivalent identity-safe comparison supported by the real host wrapper);
- optionally also require `group.model == model` where useful;
- do NOT use `parent.nil?` as the real-host criterion.

Fake host must model the real parent shape:

- root fake Group parent = fake Model;
- nested fake Group parent = non-Model container / definition-like object.

### Required tests

Add focused tests proving:

1. root Group whose `parent == model` passes;
2. nested Group whose parent is not the current model fails `group_not_root`;
3. a fake `parent=nil` must NOT be the reason a real-host root check passes.

Do not change the geometry ownership architecture.

---

## R2-02 — Ownership attributes must match the CURRENT target exactly

### Defect

R1 post-validation correctly verifies schema/kind exactly, but only checks `footprint_id_full` and `source_content_digest` are non-empty.

Frozen Blueprint §9 requires ownership values to be readable and exactly match the target current SemanticFootprint / digest.

A non-empty but wrong attribute must fail before commit.

### Required correction

Post-validation must receive or otherwise retain the expected current footprint identity and digest and compare exactly:

- `schema_version == 'v2.host-object.v1'`
- `kind == 'stage0b_mass_probe'`
- stored `footprint_id_full == current_footprint['footprint_id_full']`
- stored `source_content_digest == current_footprint['source_content_digest']`

No prefix/truncated comparison.
No dataset_id substitution.
No non-empty-only acceptance.

### Required tests

Add focused tests proving:

1. wrong-but-non-empty `footprint_id_full` fails post-validation;
2. wrong-but-non-empty `source_content_digest` fails post-validation;
3. exact values pass.

The failure must flow through the existing one-abort rollback path; do not create a new transaction mechanism.

---

## R2-03 — Truthful production default handoff proof

### Defect

R1 production wiring is now correct:

`capture_prepared_cad_input_bundle`
→ real B1.5 bundle keys
→ `PreparedCadDatasetBuilder.build`
→ `PreparedCadDatasetValidator.validate_and_finalize`
→ `SemanticFootprintProjector.project`

However the current R1 test named `V2-S0B-INT02: real default V1 handoff path succeeds end-to-end` does NOT actually execute that path end-to-end.

It creates an empty-authority bundle, calls the default Builder seam, and correctly proves only that the keyword contract yields canonical `BLOCKED` rather than an ArgumentError.

That is useful source-contract evidence, but it is not the required successful production-default integration proof.

### Required correction

Add one truthful integration test which uses the real public V1 workflow and the Stage0B production defaults for all pure-data seams.

Reuse the already-proven V2-0A truthful fixture pattern from:

`tests/test_v2_stage0a_semantic_footprint.rb`

In particular, reuse/port the same deterministic helper approach that:

- resets `WorkingModeRunner` test state;
- builds a clean rectangle SourceSnapshot / AnalysisResult;
- runs the required deterministic V1 workflow stages so B1.5 capture is genuinely READY;
- calls the real `WorkingModeRunner.capture_prepared_cad_input_bundle`;
- calls the real `PreparedCadDatasetBuilder`;
- calls the real `PreparedCadDatasetValidator`;
- obtains a READY final PreparedCadDataset;
- projects the real current SemanticFootprint.

Then run `Stage0BMassProbe` with:

- real/default capture seam;
- real/default build seam;
- real/default validate seam;
- real/default SemanticFootprintProjector;
- ONLY the SketchUp host boundary replaced by the existing fake model/real V2 mass adapter test surface.

Expected:

`SUCCESS`

and one created fake root Group.

The test must NOT inject fake capture/build/validate/projector lambdas for this case.

The previous empty-authority keyword-contract test may remain, but rename/comment it truthfully as a keyword-contract rejection proof rather than end-to-end success.

### Required negative assertion

The truthful integration test must fail if `_default_build_seam` is reverted to the old projection-shaped keyword contract.

Do not satisfy this only with source-text grep; the runtime test itself must exercise the default seam.

---

## 4. Keep the already-correct R1 fixes frozen

Do NOT redesign or reopen these unless the above corrections require a tiny signature adjustment:

- R1-02: any unexpected adapter/SketchUp exception after confirmed start -> exactly one abort attempt;
- R1-03 Vertex `position` Z reading and coordinate_epsilon no-fallback rule;
- R1-04 confirmed rollback stays READY; unconfirmed rollback locks;
- R1-05 geometry consumes re-resolved current footprint; success returns host-only Group handle;
- R1-06 injected-failure probe creates real geometry then raises before commit.

No production `failure_stage` switch.

---

## 5. Allowed scope

Production files allowed only if needed by these residuals:

- `extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb`
- `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

`host_operation_guard.rb` should remain unchanged unless a compile/test-only signature consequence is unavoidable; if behavior change appears necessary, STOP and report.

Test/probe:

- `tests/test_v2_stage0b_host_mass_probe.rb`
- `Probe/v2_stage0b_owner_probe.rb` only if required to keep the same public probe contract.

Completion docs:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

Forbidden:

- any V1 production modification;
- any V2-0A production modification;
- Loader / UI / Tool / HtmlDialog;
- Residential Stage 1;
- MCP / LLM / Agent;
- roads / raised community / landscape;
- main / force push / release / tag.

If another production file is required, STOP with:

`V2_0B_R2_SCOPE_EXPANSION_REQUIRED`

---

## 6. Validation required

At minimum:

1. Ruby syntax checks for modified/new Ruby files;
2. V2-0B focused suite — all pass;
3. new R2 root-parent tests — all pass;
4. new exact ownership tests — all pass;
5. truthful production-default V1 handoff -> Stage0B fake-host SUCCESS test — pass;
6. V2-0A focused regression — unchanged green;
7. V1.7 relevant regression;
8. V1.8 structure regression;
9. V1.9 B1 / B1.5 regressions;
10. full runner versus established `5 fail / 4 error` debt — no new fail/error;
11. `git diff --check` clean;
12. Ruby 2.2-era compatibility guard remains green;
13. RBZ rebuild/smoke if repository packaging contract requires the corrected production file.

---

## 7. Final Gate after R2

Pi must NOT run the real SU2020 Owner probe itself.

After implementation:

1. update `CURRENT_STATE.md`;
2. update `Review/CURRENT_PI_REPORT.md`;
3. commit + push only `dev/v2`;
4. STOP.

Then AIPM performs direct source review.

Only if AIPM signs source PASS does Owner perform:

- real SU2020 success probe;
- one native Undo removes the whole probe Group;
- real SU2020 injected failure probe;
- confirmed abort leaves zero visible V2 residue.

Only then V2-0B may be CLOSED.

END
