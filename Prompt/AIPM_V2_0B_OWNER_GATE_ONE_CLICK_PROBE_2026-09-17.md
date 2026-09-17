# AIPM V2-0B OWNER GATE ONE-CLICK PROBE

Date: 2026-09-17
Project: SU-AI-Plugin
Stage: V2-0B Host Geometry Probe
Status: ACTIVE IMPLEMENTATION CONTRACT
Authority: Owner + ChatGPT / AIPM
Target branch: `dev/v2`

## 0. Purpose

V2-0B automated tests and AIPM direct source review are PASS. The remaining Stage gate is real SketchUp 2020 Owner verification:

1. successful real-host geometry write;
2. one native Undo removes the entire V2 probe Group;
3. injected post-construction failure triggers confirmed abort;
4. zero visible V2 residue remains after rollback.

The existing `Probe/v2_stage0b_owner_probe.rb` requires the Owner to manually supply a `SemanticFootprint` and `AnalysisResult`. That is too implementation-heavy for the Owner gate.

This task adds a **Probe-only one-click diagnostic wrapper** so the Owner can run the real-host gate from the SU2020 Ruby Console without constructing internal V1/V2 data objects.

This is NOT a production architecture change. It MUST NOT modify any production file.

## 1. Frozen boundary

Production Stage-0B source is frozen and already source-reviewed PASS:

- `extension/su_ai_plugin/v2/host_operation_guard.rb`
- `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`
- `extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb`

V1 and V2-0A production are frozen.

The new Owner gate wrapper MUST use the SAME production:

- `HostOperationGuard`;
- `Stage0BMassProbe`;
- `V2SketchupMassAdapter`;
- real `Sketchup.active_model` host boundary.

It may inject **Probe-only synthetic freshness seams** because the truthful production-default V1 -> Builder -> Validator -> Projector -> Stage0B integration is already separately proven by `V2-S0B-R2-INT04`.

The purpose of this Owner gate is therefore specifically to isolate and verify **real SketchUp host mutation / native Undo / abort rollback behavior**, not to retest the V1 pure-data chain.

## 2. Required Owner-facing API

Enhance only:

`Probe/v2_stage0b_owner_probe.rb`

Expose two simple class/module-level callable entry points, with names equivalent to:

```ruby
SUAnalysis::Probe::V2Stage0BOwnerProbe.run_success_one_click
SUAnalysis::Probe::V2Stage0BOwnerProbe.run_injected_failure_one_click
```

Exact names above are preferred unless an existing Probe convention requires a very small adjustment.

The Owner should only need:

```ruby
load 'D:/Projects/SU-AI-Plugin/Probe/v2_stage0b_owner_probe.rb'
SUAnalysis::Probe::V2Stage0BOwnerProbe.run_success_one_click
```

and later:

```ruby
SUAnalysis::Probe::V2Stage0BOwnerProbe.run_injected_failure_one_click
```

No manual `footprint`, `analysis_result`, PCD, Runner, Builder, Validator, or Projector object construction by the Owner.

## 3. Probe-only synthetic authority

The one-click wrapper MUST NOT mutate or reset `WorkingModeRunner` and MUST NOT disturb an existing CAD Prep session.

Do NOT call:

- `WorkingModeRunner.reset_for_tests`;
- `WorkingModeRunner.prepare`;
- `WorkingModeRunner.discard`;
- any V1 repair/apply method.

Instead create a self-contained Probe-only synthetic freshness package that satisfies Stage0B's existing injected-seam contract.

Use a deterministic rectangular footprint, for example a 240 x 180 inch rectangle at z=0, with probe height default 120 inches.

The synthetic footprint MUST include valid Stage0B fields:

- `footprint_id_full`: deterministic 64-lowercase-hex String;
- `source_content_digest`: deterministic 64-lowercase-hex String;
- `semantic_role`: `'body'`;
- `source_layer_name`: `'V2_OWNER_PROBE'`;
- `projected_world_coordinates`: closed-region-compatible rectangle coordinates at z=0;
- `coordinate_epsilon`: explicit positive finite value, e.g. `1.0e-6`.

Create a Probe-only final-dataset stand-in with at minimum:

- `final? == true`;
- `content_digest` exactly equal to the footprint's `source_content_digest`.

Probe-only injected seams must produce the shapes Stage0B already expects:

- capture => `CAPTURED` + bundle Hash;
- build => `BUILT` + final dataset;
- validate => `READY` + same final dataset;
- projector => `PROJECTED` + the exact deterministic footprint.

This is allowed ONLY in the Probe file / Probe test surface. No production test switch or synthetic seam may be added to production modules.

## 4. Real-host success one-click behavior

`run_success_one_click` MUST:

1. instantiate a fresh `HostOperationGuard`;
2. instantiate the real `V2SketchupMassAdapter` with its normal real-host model provider (`Sketchup.active_model`);
3. instantiate `Stage0BMassProbe` with the Probe-only synthetic freshness seams;
4. run one deterministic rectangular mass at the default probe height;
5. print a compact Owner-readable result.

On success, console output must clearly say:

- `SUCCESS`;
- generated Group name;
- expected next action: press native SketchUp Undo ONCE;
- expected observation: the entire `SU-AI-V2-Probe-*` Group disappears.

Return the normal Stage0B result Hash so debugging remains possible.

If model is not at root edit context, return/print the existing Stage0B context failure. Do not auto-close edit context.

## 5. Real-host injected-failure one-click behavior

`run_injected_failure_one_click` MUST use the existing Probe-only mutate-then-raise concept:

1. same real `V2SketchupMassAdapter`;
2. same production `Stage0BMassProbe`;
3. delegate to real adapter FIRST so Group + Face + extrusion + ownership attributes are actually created inside the open operation;
4. then raise a Probe-only exception before commit;
5. production Stage0B exception boundary performs exactly one abort attempt.

Expected result when real SketchUp confirms abort:

`FAILED_ROLLED_BACK`

Console output must tell the Owner to confirm:

- no `SU-AI-V2-Probe-*` Group remains visible;
- zero visible generated mass residue remains.

The failure probe MUST NOT require the Owner to press Undo.

## 6. Owner-state isolation

One-click host diagnostics MUST NOT:

- reset or replace current WorkingModeRunner state;
- mutate source CAD;
- mutate V1 Derived Workspace;
- create toolbar/menu/HtmlDialog UI;
- persist synthetic dataset/footprint into model metadata beyond the existing generated probe Group attributes;
- modify user selection;
- change camera;
- save the model;
- automatically invoke Undo;
- automatically erase a successfully committed probe Group before Owner can verify Undo.

The success probe intentionally leaves the committed Group in the model until the Owner presses native Undo once.

The injected-failure probe must leave zero visible residue when abort is confirmed.

## 7. Allowed files

Allowed implementation:

- `Probe/v2_stage0b_owner_probe.rb`

Allowed tests:

- preferably a NEW focused host-free test file `tests/test_v2_stage0b_owner_probe.rb`, OR minimal additions to `tests/test_v2_stage0b_host_mass_probe.rb` if that better matches repository test-runner conventions.

Completion docs:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

No production file may change.

If implementation requires any production change, STOP with:

`V2_0B_OWNER_GATE_PROBE_PRODUCTION_CHANGE_REQUIRED`

## 8. Required automated proof

Host-free tests MUST prove at minimum:

### OG-01 one-click success

Using fake model + real production Stage0B / guard / adapter:

- returns `SUCCESS`;
- creates exactly one root probe Group;
- Group ownership attributes are correct;
- one operation start + one commit + zero abort.

### OG-02 success wrapper is self-contained

- no caller-supplied footprint;
- no caller-supplied analysis_result;
- no WorkingModeRunner state preparation/reset required.

### OG-03 one-click injected failure

- real adapter is delegated first;
- mutation occurs before injected exception;
- result is `FAILED_ROLLED_BACK` when fake abort returns true;
- zero surviving root probe Group after rollback;
- exactly one abort attempt.

### OG-04 no V1/Runner mutation dependency

Test/source guard proves the one-click wrapper does NOT call:

- `WorkingModeRunner.reset_for_tests`;
- `WorkingModeRunner.prepare`;
- `WorkingModeRunner.discard`.

### OG-05 production frozen

Diff check confirms no production file changed.

## 9. Regression requirements

Run:

- `ruby -c` on modified/new Probe/test files;
- Owner-probe focused tests;
- V2-0B focused suite (current baseline 50/50);
- V2-0A focused suite (current baseline 43/43);
- relevant V1.7 / V1.8 / B1.2 / B1.5 regressions;
- full runner: no new fail/error beyond established baseline 5 fail / 4 error;
- `git diff --check` clean;
- Ruby 2.2-era source compatibility guard remains green.

No real SU2020 Owner probe is run by Pi.

## 10. Ruby / compatibility

Maintain SketchUp 2017+ / Ruby 2.2-era syntax.

Do not introduce newer helpers such as safe navigation, `String#match?`, `Array#sum`, `Hash#compact`, `filter_map`, `transform_keys`, pattern matching, `then`, etc.

## 11. Commit / stop

After tests pass:

1. update `CURRENT_STATE.md`;
2. update `Review/CURRENT_PI_REPORT.md`;
3. commit + push only `dev/v2`;
4. STOP;
5. do not run real SU2020 Owner gate;
6. do not start Residential Stage 1;
7. do not invoke Codex.

Suggested commit message:

`test(v2-0b): add one-click real-host Owner gate probe`

Pi completion means only:

`OWNER-GATE PROBE READY — PENDING AIPM SOURCE REVIEW + OWNER REAL SU2020 TEST`

END
