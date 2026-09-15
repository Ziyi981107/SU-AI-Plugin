# CURRENT PI DISPATCH — V1.9B1 B1.5 DIRECT SOURCE REVIEW R1

Date: 2026-09-15
Project: SU-AI-Plugin
Target: dev/v1.9
STATUS: ACTIVE

## Baseline

Expected current remote HEAD before this correction:
`659500aba5dc632b14c280bc45d87163423f3c8c`

Implementation under review:
`11f654bce616c6c38978d4eeb11dd5f3a7642eba`

If local cannot fast-forward cleanly to origin/dev/v1.9:
STOP and return to AIPM.

## State

V1.9A = CLOSED_FROZEN
V1.9B0 = CLOSED_OWNER_PASS
B1.2 = CLOSED
B1.3 = CLOSED
B1.4 = CLOSED
B1.5 = CORRECTION_REQUIRED_R1
Codex post-review = HOLD
V1.9B2 = NOT_STARTED
V2 = NOT_STARTED

## Authority

Read:

1. PI_START_HERE.md
2. Prompt/CURRENT_PI_DISPATCH.md
3. Blueprint v1.2
4. Blueprint v1.3 addendum
5. Prompt/AIPM_V1_9B1_B1_5_LIVE_COHERENT_INPUT_BUNDLE_IMPLEMENTATION_2026-09-15.md
6. `Prompt/AIPM_V1_9B1_B1_5_DIRECT_SOURCE_REVIEW_R1_CORRECTION_2026-09-15.md`

The R1 correction packet is authoritative over the previous B1.5 packet
where they conflict.

## Execute ONLY R1

Main correction principle:

**B1.5 captures truth. It must never fabricate readiness.**

Required:
- preserve real duplicate / planar / gap workflow semantics
- no NOT_COMPUTED -> NO_CANDIDATE promotion
- no fake duplicate summary
- fresh structure_result may truthfully be published as computed=true because B1.5 actually computes it
- workflow structure must contain the exact fresh structure_result, not a stale placeholder with only state/digest overwritten
- missing/malformed topology endpoints fail closed
- fix vacuous uniqueness test
- update clean READY fixture to execute the real deterministic workflow first
- add uncomputed workflow => CAPTURED but Validator NOT_READY regression
- add pre-populated cache non-overwrite regression

## Allowed

Production:
`extension/su_ai_plugin/core/working_mode_runner.rb`

Test:
`tests/test_v19b1_live_bundle_capture.rb`

Docs after implementation:
`CURRENT_STATE.md`
`Review/CURRENT_PI_REPORT.md`

No other production file.

## Frozen

Do not modify:
- PreparedCadDataset / Builder / Validator
- SourceReference / SourceSnapshot / ExecutionConfig
- CanonicalTopologyBuilder / CanonicalGeometryGraph / CanonicalStructureReconstructor
- Planar/Gap/V1.8 algorithms
- Presenter/Orchestrator/DialogRunner
- UI / HTML / CSS / toolbar / loader
- persistence / Accept / Load
- V1.9B2
- V2 / MCP / LLM / Agent

If another production file is needed:
STOP `B15_R1_SCOPE_EXPANSION_REQUIRED`.

## Runtime

Use only:
`.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`

Do not search the filesystem for Ruby.

## Review flow

Pi MUST NOT invoke Codex.

After R1:
AIPM direct source review first.
Only after AIPM PASS will AIPM send one narrow Codex xHigh B1.5 post-implementation recheck.

## Finish

Run syntax, focused B1.5, B1 156/156, relevant V1.7/V1.8/Runner,
full suite, diff-check, scope check.

Commit/push implementation once.
Update state/report once.
Commit/push docs once.
Print literal final HEAD.
No SHA-chasing commit.
STOP.

END
