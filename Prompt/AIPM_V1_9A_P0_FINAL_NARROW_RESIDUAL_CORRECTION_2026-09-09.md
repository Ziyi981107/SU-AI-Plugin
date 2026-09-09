# AIPM — V1.9A P0 FINAL NARROW RESIDUAL CORRECTION

Project: `SU-AI-Plugin`
Stage: V1.9A — Final Block Fix
Date: 2026-09-09
Reviewed HEAD: `ff35cfae1962538c29ff48aca4dfd593ee6ddb81` (`dev/v1.9`)
Reviewer: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi

**VERDICT: FIX REQUIRED — TWO NARROW RESIDUALS ONLY**
**CODEX_NARROW_RECHECK: DEFER UNTIL THESE TWO RESIDUALS ARE FIXED**
**OWNER_SU2020: NOT YET**
**V1.9B: NOT STARTED**

## Owner Summary

The R1–R7 packet is substantially correct. Direct source recheck confirms R1, R3, R4 and R7 are implemented in the intended direction, and the rebuilt RBZ/full-suite evidence is available.

Two narrow gaps remain before Codex recheck / Owner SU2020:

1. R2 post-validation still has an exception-leak path while the SketchUp operation is open.
2. R5 orchestrated E2E test does not actually prove the two identity-distinct physical B Vertices both reached target Z.

No architecture redesign is required.

## BLOCK FINAL-R2-01 — post-validation validation loop can still raise before abort

File:

`extension/su_ai_plugin/core/planar_normalization_executor.rb`

Current code correctly wraps the host call `adapter.vertex_position(h)` in `begin/rescue StandardError`.

However, after the host read is captured, the validation loop currently performs:

```ruby
after_zs << post[2].to_f if post.is_a?(Array)
```

before proving:

- `post.length == 3`;
- `post[0..2]` are Numeric;
- every numeric is finite.

Therefore malformed-but-Array post data can still raise while the outer operation is open. Example:

```ruby
[0.0, 0.0, Object.new]
```

`Object.new.to_f` raises `NoMethodError` before the executor reaches the existing unreadable-position branch.

The current validation condition also accepts an Array longer than 3 values because it checks `post.is_a?(Array)` plus the first 3 Numeric slots, but does not require `post.length == 3`.

### Required correction

Before any `.to_f`, subtraction, `.abs`, audit append, or other numeric use:

1. entry must not be raised/missing;
2. `post` must be an Array of **exactly 3**;
3. all 3 values must be Numeric;
4. all 3 values must be finite.

Only after all four checks pass may the code append `after_zs` or perform XY/Z validation.

Add a final defensive exception boundary around the post-validation phase so an unexpected `StandardError` during post-validation also:

- aborts the single outer operation exactly once;
- never commits;
- returns `:failed`;
- publishes zero logical / physical / legacy applied success.

Do not change preflight, fan-out, operation ownership, tolerances, or proposer logic.

### Required tests

Add focused tests proving:

- post-read `[0.0, 0.0, Object.new]` -> no exception escapes, 1 begin, 1 abort, 0 commit, FAILED, zero success;
- post-read `[0.0, 0.0, 0.0, 123.0]` -> malformed, 1 begin, 1 abort, 0 commit, FAILED;
- existing raised / Hash / NaN tests remain PASS.

## BLOCK FINAL-R5-01 — orchestrated Owner E2E does not prove physical-B fan-out

File:

`tests/test_v19a_final_p0_live_coordinates.rb`

The new R5 test correctly exercises:

```text
CadPrepWorkflowOrchestrator.start
-> apply_planar_and_refresh
-> apply_gap_and_refresh
```

and correctly asserts final structure:

```text
open_chain_count = 0
closed_loop_count = 1
invalid_loop_count = 0
region_count = 1
no non_planar_loop
```

However, the frozen R5 contract also required the test to prove inside this same orchestrated fixture:

- the two physical B handles are identity-distinct;
- after `apply_planar_and_refresh`, both physical B handles are at target Z.

The current test comments claim this, but the assertions jump from `planar == APPLIED` directly to gap apply and do not inspect the two B Vertex handles.

### Required correction

Test-only unless the new assertion reveals a production defect.

Immediately after `apply_planar_and_refresh`:

1. resolve the two physical endpoint Vertex handles representing logical B from the two independent derived edge Groups (`A-B.end` and `B-C.start`, or equivalent authoritative host-vertex map);
2. assert they are not the same object identity;
3. read both through the adapter's live `vertex_position`;
4. assert both Z values equal the planar target Z within the existing `coordinate_epsilon`;
5. only then continue to the existing gap-unlock + gap-apply + Structure assertions.

Do not manually call downstream `WorkingModeRunner.compute_*` methods.

## PASS / PRESERVE

Do not reopen unless the new focused tests expose a direct defect:

- R1 strict preflight before mutation;
- Group -> endpoint Vertex live-read authority;
- R3 cached fallback / fail-closed matrix;
- physical-occurrence identity dedupe in proposer;
- logical -> physical fan-out design;
- one outer operation + one primitive per physical occurrence;
- logical / physical count split;
- R4 V1.8 `loops` + `*_count` presenter shape;
- R7 `deep_nesting` / `嵌套层级`;
- A2 orchestrator call order and invalidation;
- V1.5 duplicate algorithm;
- V1.6 analysis/tolerance policy;
- V1.7 pairing/canonical clustering;
- V1.8 reconstruction/region algorithm;
- Source CAD immutability;
- Undo / host-state architecture;
- toolbar / tabs / hidden semantics;
- V1.9B.

## Test / package return requirements

After the two residuals are fixed:

- focused V19A-P0 tests;
- presenter + orchestrator focused tests;
- V1.6 / V1.7 / V1.8 regressions;
- normal `tests/run_all.rb`;
- rebuilt RBZ from final corrected source;
- RBZ smoke;
- Node DOM;
- `git diff --check`.

Report exact counts and separate known pre-existing failures. Do not claim a count such as `78/78 PASS + 1 error`; report totals arithmetically consistently.

The current RBZ candidate (`1,191,455 bytes`, 73 entries, SHA-256 `36e60309f386b0dcba97ee0016445d99c91e40b5ecf9687ae13a62aedc984c9b`) is **not Owner-approved** because production source will change again for FINAL-R2-01.

## Allowed production scope

Only:

- `extension/su_ai_plugin/core/planar_normalization_executor.rb`

Test files needed for FINAL-R2-01 / FINAL-R5-01 may be changed.

`endpoint_record.rb`, presenter, proposer, orchestrator, WorkingModeRunner, V1.7/V1.8 algorithms, app.js/CSS/toolbar are frozen unless a newly added focused assertion proves a direct contradiction. If that happens: STOP and report rather than expanding scope.

## Next

Pi implements only FINAL-R2-01 + FINAL-R5-01, rebuilds evidence, commits/pushes `dev/v1.9`, and STOPs.

Then:

1. AIPM final narrow source recheck;
2. Codex xHigh narrow recheck;
3. Owner SU2020 same Z + Gap fixture;
4. V1.9A closure decision;
5. only after explicit Owner/AIPM discussion may V1.9B begin.

Set:

- `AIPM_REVIEW = PENDING`
- `CODEX_NARROW_RECHECK = NOT YET`
- `OWNER_SU2020 = NOT YET`
- `V1.9B = NOT STARTED`

END
