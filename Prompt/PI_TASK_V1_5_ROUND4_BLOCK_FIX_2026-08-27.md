# PI TASK — V1.5 ROUND-4 EXISTING BLOCK FIX

Project: SU-AI-Plugin
Date: 2026-08-27
Dispatcher: ChatGPT / AIPM
Status: ACTIVE IMPLEMENTATION TASK

Read first, in order:

1. `AGENTS.md`
2. `PROJECT_HANDOFF.md`
3. `PROJECT_MASTER_PLAN_V1X.md`
4. `CURRENT_STATE.md`
5. `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`
6. the current Codex V1.5 Round-3 narrow recheck artifact

Your job is IMPLEMENTATION ONLY.

Implement the frozen Round-4 AIPM design for the existing:
- V15-STAGE-BLOCK-001
- V15-STAGE-BLOCK-002
- V15-STAGE-BLOCK-003
- V15-STAGE-BLOCK-004
- V15-STAGE-BLOCK-005 evidence prerequisites

Hard requirements:

- no source CAD mutation;
- no partial maximal-clique destructive repair;
- candidate enumeration must have no tolerance false negatives;
- captured tolerance explicit across production paths;
- final executable components require distinct current live handles;
- full expected post-state validates before host `begin_operation`;
- failed prevalidation => begin_calls=0;
- failed dispose/precommit => abort, no commit, exact logical pre-state retained;
- commit uncertainty => failed/non-ready;
- skipped actions remain visible in final audit;
- duplicate pair metric uses unique unordered direct-match pairs;
- ambiguous non-transitive components are skipped whole;
- do not create the final AIPM Owner verification file;
- do not invoke Codex;
- do not start V1.6.

Required output:

`Review/V1_5_ROUND4_BLOCK_FIX_RECHECK_PACKET_2026-08-27.md`

The packet must include:
- branch/base/head;
- changed files;
- implementation map for BLOCK-001..004;
- evidence prerequisites for BLOCK-005;
- focused regression results;
- full V1.5 results;
- full Ruby results;
- Node DOM results;
- git diff --check;
- final RBZ path/size/entries/SHA-256;
- exact production observation paths AIPM needs to write the Owner checklist;
- unresolved issues.

After packet + CURRENT_STATE update are complete:

STOP.

Return control to AIPM.
Do not ask Owner to install anything.
Do not request Codex recheck.
