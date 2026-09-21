# AIPM — V2-0B OWNER GATE R1 NAMESPACE CORRECTION

Date: 2026-09-21
Project: SU-AI-Plugin
Branch: dev/v2
Authority: ChatGPT / AIPM
Scope: NARROW CORRECTION ONLY

## 0. Trigger

Real SU2020 Owner Gate failed before geometry mutation.

Observed console error:

```text
NameError: uninitialized constant
SUAnalysis::V2::Stage0BMassProbe::V2SketchupMassAdapter
```

The same real-host run also printed duplicate-constant warnings because an installed AppData copy of SU-AI-Plugin was already loaded and the developer Probe then loaded repository source. Those warnings are test-environment duplication, not the primary BLOCK.

## 1. Root cause — BLOCK

Production file:

`extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

is lexically under:

`SUAnalysis::V2::Stage0BMassProbe`

but directly references the unqualified constant:

`V2SketchupMassAdapter`

The real class is defined only at:

`SUAnalysis::Compatibility::V2SketchupMassAdapter`

Current unqualified production references include at least:

- operation label;
- construction-failed status;
- success status;
- post-validation-failed status.

The focused host-free test environment masked this because
`tests/test_v2_stage0b_host_mass_probe.rb` executes top-level:

`include SUAnalysis::Compatibility`

which can make the sibling Compatibility constant visible through test process constant lookup even though a normal SketchUp runtime does not provide that pollution.

This is a real production namespace bug proven by Owner SU2020 evidence. Real-host evidence overrides automated green tests.

## 2. Required production correction

Modify ONLY as needed:

`extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

Every production reference to the adapter class constant must use explicit stable authority:

`SUAnalysis::Compatibility::V2SketchupMassAdapter`

For example:

- `SUAnalysis::Compatibility::V2SketchupMassAdapter::OPERATION_LABEL`
- `SUAnalysis::Compatibility::V2SketchupMassAdapter::STATUS_CONSTRUCTION_FAILED`
- `SUAnalysis::Compatibility::V2SketchupMassAdapter::STATUS_SUCCESS`
- `SUAnalysis::Compatibility::V2SketchupMassAdapter::STATUS_POST_VALIDATION_FAILED`

Do NOT create an alias under `SUAnalysis::V2` merely to make the old unqualified references work.
Do NOT move the adapter class.
Do NOT change namespace ownership.

## 3. Required anti-regression proof

The correction is not complete if existing tests still pass only because of namespace pollution.

Add a focused runtime regression that proves Stage0B works in a clean namespace where:

- `SUAnalysis::Compatibility::V2SketchupMassAdapter` exists;
- `SUAnalysis::V2::V2SketchupMassAdapter` is NOT defined;
- no top-level `include SUAnalysis::Compatibility` is required for the exercised path;
- Stage0B actually executes far enough to resolve all adapter constants used by the success/failure path.

Preferred proof:

A fresh Ruby subprocess or isolated focused test which loads the production files without top-level `include SUAnalysis::Compatibility`, injects the minimum fake model/seams needed, invokes the Stage0B path, and reaches the expected deterministic result without NameError.

A source-text grep alone is NOT sufficient.

You MAY additionally reduce the masking in
`tests/test_v2_stage0b_host_mass_probe.rb` by replacing direct unqualified test uses with fully-qualified Compatibility references, but do not expand into unrelated test cleanup.

## 4. Frozen behavior

Do NOT redesign or modify:

- `HostOperationGuard` semantics;
- freshness gate;
- rollback semantics;
- ownership schema;
- V2SketchupMassAdapter behavior unless a test-only qualification is unavoidable;
- V1 production;
- V2-0A production;
- SemanticFootprint contract;
- Owner one-click synthetic freshness design;
- Residential Stage 1;
- UI / Tool / HtmlDialog;
- MCP / LLM / Agent.

The real-host failure occurred BEFORE the intended geometry write, so this packet is namespace correction only.

## 5. Owner Probe / environment note

Do not attempt to fix duplicate-constant warnings by changing production namespaces or adding reload hacks.

Those warnings came from loading repository source while an installed AppData SU-AI-Plugin copy was already active.

After this correction passes source review, Owner will repeat the real-SU2020 gate in a clean session with the installed extension disabled/restarted, then load the repo Probe directly.

## 6. Allowed files

Production:
- `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

Tests:
- `tests/test_v2_stage0b_host_mass_probe.rb`
- `tests/test_v2_stage0b_owner_probe.rb`
- optionally one NEW narrow V2-0B namespace-isolation test file if that is cleaner.

Completion docs:
- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

Do not modify the Owner Probe implementation unless a test harness change is truly required. The one-click API itself is not the defect.

## 7. Required validation

Minimum:

1. `ruby -c` on all modified/new Ruby files — Syntax OK.
2. Namespace-isolation runtime regression — PASS.
3. V2-0B focused suite — all PASS.
4. Owner-Gate focused suite — all PASS.
5. V2-0A focused — unchanged PASS.
6. V1.7 / V1.8 / V1.9 B1.2 / B1.5 relevant regressions — unchanged PASS.
7. Ruby 2.2-era compatibility guard — PASS.
8. `git diff --check` — clean.
9. Full runner — no new fail/error beyond established 5 fail / 4 error baseline.
10. RBZ smoke if normal repository completion rules require it.

Also add a negative proof if practical:

temporarily reintroducing an unqualified `V2SketchupMassAdapter` reference must make the new namespace-isolation runtime test fail with a NameError or equivalent.

## 8. Completion state

After implementation/tests:

- update `CURRENT_STATE.md`;
- update `Review/CURRENT_PI_REPORT.md`;
- commit + push only `dev/v2`;
- STOP.

Do NOT run the real SU2020 Owner Gate.
Do NOT start Residential Stage 1.
Do NOT invoke Codex.
Do NOT push/merge main or force-push.

Final state:

`V2-0B OWNER GATE R1 IMPLEMENTED — PENDING AIPM SOURCE REVIEW + OWNER REAL SU2020 RETEST`

END
