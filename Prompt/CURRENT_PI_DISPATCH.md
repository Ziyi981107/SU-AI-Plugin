# CURRENT PI DISPATCH

DISPATCH_ID: V18-BASE-STRUCTURE-RECONSTRUCTION-2026-09-02
STATUS: ACTIVE
PROJECT: SU-AI-Plugin
STAGE: V1.8 — Polyline / Closed Loop / Region Reconstruction
TARGET_BRANCH: dev/v1.8
BASELINE_HEAD: ac0f26727574e4ea3830fec9fe4764a56e743358

Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

FROZEN BLUEPRINT:
Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_8_LOOP_REGION_2026-09-02.md

REPORT TARGET:
Review/CURRENT_PI_REPORT.md

# 0. MISSION

Implement V1.8 base completely according to the frozen Blueprint:

CanonicalGeometryGraph
→ deterministic open chains
→ deterministic closed loops
→ nested loops / holes
→ geometric regions
→ conservative unresolved issues
→ compact Chinese UI `轮廓与区域 / 检查结构`.

This is a TIME-BOXED stage before the Owner presentation milestone.

Primary objective:
finish a trustworthy deterministic V1.8 base without destabilizing V1.7.

# 1. FIRST ACTIONS

1. Confirm working tree / branch / remote state.
2. Preserve current accepted V1.7 head.
3. Create/switch to:
   `dev/v1.8`
   from:
   `ac0f26727574e4ea3830fec9fe4764a56e743358`
   unless that branch already exists at the correct ancestry.
4. Read:
   - AGENTS.md
   - PI_START_HERE.md
   - PROJECT_MASTER_PLAN_V1X.md
   - frozen V1.8 Blueprint
   - current V1.7 canonical graph + WorkingModeRunner implementation.
5. Do NOT inherit the old V1.7 CURRENT_PI_DISPATCH semantics after this file is
   installed; this file is the current task authority.

No force push.
No rebase/history rewrite.
No main merge/push.
No tag/release.

# 2. HARD ARCHITECTURE BOUNDARY

DO:
- add separate pure V1.8 reconstruction result;
- consume current CanonicalGeometryGraph;
- preserve plural provenance;
- integrate one read-only compute action in WorkingModeRunner;
- add compact UI;
- add comprehensive deterministic tests.

DO NOT:
- change CanonicalGeometryGraph schema to add loops/regions;
- change V1.7 canonical node/edge identity;
- change V1.7 gap repair semantics;
- change source ownership;
- mutate Source CAD;
- create SketchUp Faces;
- add observers;
- add new repair types;
- add site semantics;
- start V1.9 / PreparedCadDataset;
- invoke Codex yourself.

If any implementation need appears to require those changes:
STOP that subitem and report the blocker to AIPM.

# 3. REQUIRED CORE IMPLEMENTATION

Preferred main file:
`extension/su_ai_plugin/core/canonical_structure_reconstructor.rb`

Implement pure deterministic contracts:
- ChainRecord
- LoopRecord
- RegionRecord
- StructureReconstructionResult
- CanonicalStructureReconstructor

Exact details are frozen in the Blueprint.

Minimum behavior:

A. Simple open component
exactly two degree-1 endpoints, all other degree-2
→ one ChainRecord.

B. Simple cycle
all degree-2, E == V, >=3 nodes
→ deterministic LoopRecord.

C. Branch degree >2
→ `branching_component`
→ no guessed decomposition.

D. Geometry invalid:
- self intersection;
- repeated vertex;
- non-planar loop;
- degenerate loop;
- touching/intersecting loop boundaries;
→ unresolved / no false region.

E. Valid nested loops
→ deterministic containment tree;
→ even depth outer region;
→ odd depth hole;
→ depth 2 island becomes new region.

# 4. DETERMINISM / IDENTITY

No random IDs.

Open chain:
start at lexicographically smaller terminal.

Loop:
start at lexicographically smallest canonical node;
choose lexicographically smaller of the two complete valid orientations.

IDs:
SHA-256 over schema + normalized canonical node/edge identity.

Result digest:
stable across input node/edge/Hash iteration order.

Add explicit forward/reverse/shuffle regression proving exact payload + digest
identity.

# 5. PROVENANCE

Plural:
`source_occurrence_ids`
is authority.

Union from all participating canonical edges.
sorted + uniq.

Test a loop containing `origin_kind = gap_bridge`.

Do not convert gap_bridge support provenance into a claim that geometry existed
in source CAD.

# 6. PERFORMANCE

Component traversal:
O(V+E).

Self-intersection:
non-adjacent segments only + bbox prune.

Loop containment:
loop bbox prune before point-in-polygon tests.

Add practical performance smoke.
Do not build a sophisticated sweep-line algorithm unless measured evidence proves
it necessary.

# 7. RUNNER INTEGRATION

Add V1.8 derived state, e.g.:
`@structure_reconstruction_result`

Clear it whenever current geometry/canonical truth may change:
- prepare/rebuild/discard;
- duplicate repair mutation;
- planar normalization apply;
- gap repair apply;
- failed/stale transition.

Add:
`compute_structure_reconstruction`

Order:
1. current ready workspace guard;
2. `validate_host_state_consistency!` FIRST;
3. captured current tolerance;
4. fresh `rebuild_canonical_geometry_graph`;
5. pure V1.8 reconstruct;
6. cache JSON-safe result;
7. snapshot.

Must work WITHOUT first running `检查间隙`.

No begin_operation.
No SketchUp host mutation.

Snapshot:
`structure_reconstruction`

minimum:
- computed
- state
- canonical_graph_digest
- digest
- metrics
- unresolved_issues

# 8. UI

Add block:
`轮廓与区域`

Button:
`检查结构`

States:
- 未检查
- 结构可用
- 存在需检查项
- 检查失败

Metrics:
- 开放链
- 闭合轮廓
- 区域
- 洞
- 异常

Keep technical details collapsed.

No Face generation button.

# 9. TESTS — MINIMUM REQUIRED

Core:
- open polyline;
- rectangle;
- repaired triangle / gap_bridge provenance;
- outer + inner rectangle;
- three-level nesting;
- bow-tie;
- repeated vertex;
- branching T/Y;
- non-planar loop;
- touching/intersecting loops;
- shuffle determinism exact payload/digest;
- plural provenance;
- invalid graph;
- upstream issue propagation;
- performance smoke.

Integration:
- prepare → structure check without gap check;
- gap apply → structure check detects closed loop;
- discard/rebuild clears stale result;
- host-state invalidation fails closed;
- compute structure opens zero host operations.

UI/package:
- DOM;
- loader;
- RBZ smoke;
- git diff --check.

Compatibility:
production code must remain Ruby 2.2 / SU2017 baseline compatible.
No `Hash#compact`, safe-navigation, pattern matching, or newer-only APIs.

# 10. FULL REGRESSION

Before report run fresh:
- V1.8 focused suites;
- V1.7 suite;
- V1.6 close-autodiscard;
- V1.5 BLOCK-005 / host-state relevant regression;
- full Ruby;
- Node DOM;
- RBZ smoke;
- git diff --check.

Rebuild RBZ after production changes.

Report exact counts and artifact identity.

# 11. REVIEW ESCALATION

Default after Pi:
AIPM SOURCE REVIEW.

Do NOT invoke Codex.

Mark CODEX_RISK_TRIGGER = YES and STOP for AIPM if you materially changed:
- CanonicalGeometryGraph schema/identity/digest;
- provenance authority;
- workspace ownership;
- native host mutation;
- Face creation;
- Undo/Observer architecture;
- tolerance authority.

Otherwise:
CODEX_RISK_TRIGGER = NO.

# 12. REPORT

Overwrite:
`Review/CURRENT_PI_REPORT.md`

Include:

- dispatch ID;
- branch/base/final HEAD;
- changed production files;
- changed test files;
- exact reconstruction data contracts;
- deterministic ID method;
- chain/loop traversal method;
- self-intersection method;
- containment/hole method;
- provenance handling;
- runner invalidation lifecycle;
- UI changes;
- focused V1.8 exact pass counts;
- full regression exact counts;
- RBZ path / size / entries / SHA-256;
- git diff --check;
- known limitations;
- CODEX_RISK_TRIGGER YES/NO;
- any deviations from Blueprint.

Gate line:
`AIPM_REVIEW: REQUIRED`
`CODEX: NOT REQUIRED UNLESS RISK TRIGGER`
`OWNER_SU2020: AFTER AIPM PASS`

# 13. COMMIT / PUSH

Pi may create clean local checkpoint commits.

After all required tests are green and report is current:
one normal fast-forward push is authorized to:
`origin/dev/v1.8`

No force.
No main push.
No release/tag.

Then STOP and hand control to AIPM.

# 14. TIMEBOX STOP CONDITIONS

Do not burn the presentation deadline on scope expansion.

If blocked by:
- canonical graph redesign;
- host Face semantics;
- new tolerance design;
- broad V1.7 changes;
- region logic requiring a materially larger geometry engine;

preserve completed green work, report exactly what is blocked, and STOP.

AIPM will decide whether to narrow the stage or defer the blocked subpart.

END
