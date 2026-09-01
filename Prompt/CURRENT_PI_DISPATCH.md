# CURRENT PI DISPATCH

DISPATCH_ID: V17-GAP-TOPOLOGY-IMPLEMENTATION-2026-09-01
STATUS: ACTIVE
PROJECT: SU-AI-Plugin
TARGET_STAGE: V1.7 — Endpoint / Gap Repair + Canonical Topology
TARGET_BRANCH: dev/v1.7

Dispatcher / Product + Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

V1.6 CLOSURE:
Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md

FROZEN V1.7 BLUEPRINT:
Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md

# 0. MISSION

The Owner has completed V1.6 real SketchUp 2020 verification.

V1.6 is CLOSED.

This dispatch activates V1.7.

Implement the frozen V1.7 Blueprint as ONE coherent product packet:

canonical topology
→ conservative endpoint gap proposal
→ Simplified Chinese preview
→ explicit derived-only `修复间隙`
→ canonical graph rebuild
→ provenance / lifecycle / regression / RBZ.

Do NOT start V1.8.

V1.7 is a mandatory Codex xHigh integration-review stage, but Pi must NOT invoke
Codex. Pi stops after its implementation packet for AIPM primary review.

# 1. READ FIRST

Read in canonical order:

1. AGENTS.md
2. PI_START_HERE.md
3. PROJECT_HANDOFF.md
4. PROJECT_MASTER_PLAN_V1X.md
5. CURRENT_STATE.md
6. Prompt/CURRENT_PI_DISPATCH.md
7. Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md
8. Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md
9. Review/CURRENT_PI_REPORT.md
10. actual local Git/source/tests

Historical Prompt/Review artifacts are evidence only.

The frozen V1.7 Blueprint owns design decisions for this stage.

Pi does not independently redesign:
- canonical identity;
- repair types;
- tolerance authority;
- source/derived ownership;
- transaction/recovery;
- provenance;
- V1.8 boundary.

# 2. PRE-FLIGHT + V1.6 CLOSURE SYNC

## 2.1 Git truth

Record:

- current branch;
- current HEAD;
- local `dev/v1.6` HEAD;
- origin refs if reachable;
- local-ahead counts;
- tracked/untracked state.

Known environment fact:
GitHub has repeatedly been unreachable from this host.
Remote reachability is NOT required for local V1.7 implementation.

Do not repeatedly retry network.

## 2.2 Verify actual V1.6 base

The only permitted V1.7 base is the actual local V1.6 HEAD containing:

- Simplified Chinese UI;
- discarded/failed fresh `准备处理`;
- close-time auto-discard;
- current final V1.6 RBZ source.

Verify CURRENT_STATE can be truthfully updated to:

- V1.6 CLOSED
- Owner SU2020 PASS
- V1.7 STARTED

If the local source does not contain the final close-autodiscard implementation:
STOP.

## 2.3 Track AIPM authority docs unchanged

Ensure these are tracked durable files on the V1.7 line:

- Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md
- Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md

Pi may add/commit them unchanged.

Do NOT rewrite AIPM product/technical content.

## 2.4 Branch

If `dev/v1.7` does not exist:
create it from the exact local closed V1.6 HEAD.

If it exists unexpectedly:
inspect it.

Do not reset/rewrite a conflicting branch.

No round-specific branch.

# 3. CURRENT_STATE START UPDATE

Before substantial V1.7 code, update current dynamic status:

- V1.6 CLOSED
- V1.6 Owner SU2020 PASS
- V1.7 ACTIVE
- frozen Blueprint path
- mandatory future Codex xHigh integration review
- V1.8 NOT STARTED

Do not claim V1.7 PASS/CLOSED.

# 4. IMPLEMENT FROZEN V1.7

Follow the Blueprint exactly.

Critical contracts:

## 4.1 Canonical identity

- host topology != canonical topology;
- gap_search proximity != canonical identity;
- canonical nodes use coordinate_epsilon;
- no transitive tolerance collapse;
- deterministic IDs/order.

## 4.2 Executable repair type

ONLY:

`endpoint_bridge`

Do not implement endpoint movement / midpoint snap / endpoint-to-edge / projected
intersection / line extension / curve explosion.

## 4.3 Pair authority

Executable only when the pair is conservatively unambiguous:

- open canonical degree 1;
- direct distance within allowed range;
- Z compatible;
- mutual unique candidate;
- no same-edge self-pair;
- layer-safe;
- no crossing;
- no third node on bridge;
- no proposed-bridge conflict;
- no unsafe Curve/Face context.

Anything else:
review/skip, no destructive apply.

## 4.4 Repair host ownership

Generated bridge geometry is transient DERIVED workspace-owned repair geometry.

Do not move existing source-derived endpoints.

Do not mutate source.

Include repair group/handles in:
- handle registry;
- Discard;
- Rebuild;
- close auto-discard;
- host consistency validation.

## 4.5 Canonical graph

Build/rebuild:

CanonicalGeometryGraph
- deterministic nodes;
- canonical edges;
- adjacency;
- unresolved topology issues;
- provenance.

Recompute from current derived truth after material changes.

No live observer-replay graph.

# 5. UI

Keep Simplified Chinese.

Add compact user-level `拓扑修复` section.

Normal flow:

ready workspace
→ primary `检查间隙`

safe proposals
→ `发现可修复间隙`
→ primary `修复间隙`

ambiguous:
→ `需要人工确认`
→ no destructive CTA for ambiguous items.

Default visible:
- 开放端点
- 可安全修复
- 需人工确认
- 最大间隙 where useful.

Technical IDs/tolerances/provenance:
collapsed `技术详情`.

Preserve one-primary-action philosophy.

Do not regress V1.6 UI.

# 6. TEST REQUIREMENTS

Implement the Blueprint matrix at minimum:

- N1-N6 canonical identity;
- G1-G10 pairing;
- X1-X4 crossing/branch safety;
- H1-H8 host mutation;
- T1-T7 graph/provenance;
- L1-L4 lifecycle;
- P1-P3 performance evidence.

Also preserve:

- full V1.0-V1.6 regressions;
- V1.6 close auto-discard;
- V1.5 BLOCK-005;
- legacy compatibility;
- Node DOM;
- RBZ smoke.

No test may make source mutation acceptable.

No fake Owner real-host PASS.

# 7. PACKAGE / OWNER CANDIDATE

Build RBZ.

Verify:

- root entry point;
- all V1.7 modules included;
- Chinese frontend included;
- no dev-only paths;
- production source/package hash match;
- parse/load smoke;
- legacy compatibility.

Report:

- path;
- size;
- entry count;
- SHA-256;
- relevant frontend hashes;
- source/package match.

Prepare Owner SU2020 instructions for Blueprint scenarios A-G.

Do NOT run Owner verification.

# 8. AIPM REVIEW PACKET

Overwrite:

Review/CURRENT_PI_REPORT.md

DISPATCH_ID:
V17-GAP-TOPOLOGY-IMPLEMENTATION-2026-09-01

Include:

## A. Repository anchor
- V17_BASE_SHA
- branch
- starting/final HEAD
- origin refs/reachability
- local ahead

## B. Authority docs
- closure path
- Blueprint path
- confirmation Pi did not rewrite Blueprint

## C. Changed-file map

## D. Canonical topology contract map
Blueprint requirement
→ symbol/file
→ test.

## E. Gap-pairing evidence
- spatial candidate retrieval;
- mutual uniqueness;
- layer;
- Z;
- curve/face;
- crossing;
- third-node;
- pair conflicts.

## F. Host mutation
- workspace repair container;
- add-line route;
- operation counts;
- failure/commit uncertainty;
- post-validation.

## G. Provenance
- canonical node IDs;
- edge provenance;
- generated gap bridge provenance;
- source occurrence trace.

## H. Non-transitive tests
Explicitly report A≈B/B≈C/A!≈C evidence.

## I. Lifecycle
- Undo;
- Discard;
- Rebuild;
- close auto-discard;
- source integrity.

## J. Performance
Actual synthetic sizes/timings available from tests.
Do not invent real company-CAD performance.

## K. UI
Chinese states/buttons and DOM evidence.

## L. Full tests
Exact commands + counts.

## M. RBZ
Path/size/entries/hash.

## N. Remaining risks/unknowns
Separate confirmed defect / assumption / unknown / Owner-only.

## O. Mandatory review state
State:

`CODEX_GATE: REQUIRED xHigh AFTER AIPM PRIMARY REVIEW`

Pi must NOT call Codex.

## P. Owner gate
`NOT YET RUN`

Provide exact Chinese real-host steps.

# 9. AIPM/CODEX GATE BOUNDARY

Pi must NOT mark V1.7 CLOSED.

After Pi completion:

Pi STOP
→ AIPM direct source review
→ if implementation packet is materially ready:
   Codex mandatory xHigh integration review
→ fix BLOCKs if any
→ Owner SU2020 real-host scenarios
→ AIPM V1.7 closure.

Do not create additional arbitrary Codex gates.

# 10. STOP EARLY ONLY FOR MATERIAL DESIGN GAPS

STOP affected scope if:

- source mutation becomes required;
- cross-group repair cannot be represented as workspace-owned bridge geometry;
- canonical graph requires transitive gap-tolerance identity;
- current transforms invalidate world-coordinate assumptions;
- source occurrence provenance cannot survive canonicalization;
- separate execution tolerance is materially required;
- host topology side effects cannot be isolated;
- new Undo/Observer architecture is required;
- V1.8 loop semantics become necessary.

Otherwise continue autonomously through implementation/debug/tests.

# 11. GIT

Pi may create meaningful local commits.

Suggested:

1. `feat(v1.7): add deterministic canonical topology`
2. `feat(v1.7): propose conservative endpoint gap repairs`
3. `feat(v1.7): apply derived gap bridge repairs`
4. `feat(v1.7): expose Chinese topology repair workflow`
5. `test(v1.7): complete topology and lifecycle regression`

Do not create trivial micro-commits.

Never:
- force-push;
- reset shared work;
- rebase published history;
- merge main;
- tag/release.

# 12. NETWORK

At final completion only:

one bounded remote check.

If unreachable:
report and STOP normally with stable local commits.

If reachable:
normal fast-forward push may be attempted only for assigned version branches
under current governance.

Never force.

# 13. DEFINITION OF PI COMPLETE

Pi Complete requires:

- V1.6 truthfully CLOSED;
- dev/v1.7 based on exact final local V1.6;
- canonical topology implementation complete;
- safe endpoint_bridge proposal/apply complete;
- ambiguity/crossing protections complete;
- source unchanged;
- generated bridge provenance complete;
- lifecycle integrations complete;
- Chinese UI complete;
- performance evidence complete;
- full regressions green;
- RBZ candidate built;
- CURRENT_STATE truthful;
- CURRENT_PI_REPORT complete;
- mandatory Codex gate clearly pending;
- Owner gate clearly NOT YET RUN;
- V1.8 NOT STARTED.

Then STOP and return control to AIPM.

Do NOT invoke Codex.
Do NOT start V1.8.
