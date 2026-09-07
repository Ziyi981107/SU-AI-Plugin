# AIPM V1.9A FINAL BLOCK FIX — CURRENT-GEOMETRY + CURRENT-ISSUE SEMANTICS

Project: SU-AI-Plugin
Stage: V1.9A — Product UX + Diagnostics Orchestration
Date: 2026-09-07
Authority: ChatGPT / AIPM
Owner: Final Product Owner
Implementation Agent: Pi
Target Branch: `dev/v1.9`
Starting Baseline: `d4c4bc06e590dc4c4825fdbe20f07c2b1bc4db80`
Status: DURABLE GUIDANCE — executable only when referenced by `Prompt/CURRENT_PI_DISPATCH.md`
V1.9B: NOT AUTHORIZED

References:
- `Prompt/AIPM_STAGE_PRODUCT_TECHNICAL_BLUEPRINT_V1_9A_V1_9B_2026-09-04.md`
- `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
- `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
- `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_8_LOOP_REGION_2026-09-02.md`

---

## 0. OWNER GATE CONTEXT

Real SketchUp 2020 Owner testing has already verified:

- A3 native `SU AI` toolbar works;
- no-selection prompt works;
- V1.9A production UI loads;
- four tabs work after the scoped `[hidden]` fixes;
- false STALE recovery banner is gone;
- red issue badge is hidden when count is zero;
- A2 one-click start performs Prepare + Duplicate + Planar + Gap + Structure;
- a combined Z + Gap case correctly shows both issues;
- while Planar is actionable, Gap repair is disabled;
- after applying Z, Gap is automatically recomputed and unlocked;
- after applying Gap, Structure is automatically recomputed;
- the repaired topology becomes `open_chain_count=0`, `closed_loop_count=1`.

V1.9A is NOT closed because the same real SU2020 test exposed one P0 current-geometry consistency bug plus several narrow product/presentation bugs.

Do not reopen already-passed hidden-semantics or host-state work.

---

# 1. P0 BLOCK — V1.6 -> V1.7 READS STALE PRE-Z COORDINATES

## 1.1 Real SU2020 evidence

Owner test fixture intentionally contained:

- one safe Z drift of exactly `0.2 mm`;
- one safe endpoint gap of `1.0 mm`.

Observed after `Start -> Apply Z -> Apply Gap`:

```text
WORKSPACE: ready
STRUCTURE: READY_WITH_WARNINGS
open_chain_count: 0
closed_loop_count: 1
region_count: 0
invalid_loop_count: 1
flags: ["non_planar_loop"]
```

The reconstructed loop still contained:

```text
z = 0.007874015748031498 in
```

which is exactly `0.2 mm`, i.e. the original pre-normalization Z drift.

This proves:

- V1.6 host mutation happened;
- A2 invalidated/recomputed downstream stages;
- V1.7 canonical topology closed correctly after the bridge;
- but V1.7 topology snapshot consumed stale cached geometry coordinates;
- V1.8 correctly rejected the resulting stale loop as `non_planar_loop`.

V1.8 is not the root cause.

## 1.2 Source diagnosis

Current `PlanarNormalizationExecutor` mutates live derived host vertices and post-validates them through `adapter.vertex_position`, but returns the same logical workspace object/records.

Current `DerivedTopologySnapshotBuilder` obtains host vertex handles but builds `DerivedEdgeRecord.world_endpoints` and `EndpointRecord.world_coordinate` from `DerivedEntityRecord.geometry_summary['start'/'end']`.

Those summaries describe the workspace build-time geometry and are stale after V1.6 vertex mutation.

This violates the frozen V1.7 contract:

> V1.7 analysis runs on the CURRENT DerivedGeometryWorkspace after V1.5/V1.6 operations.

## 1.3 Frozen fix direction

The current live derived host geometry is authoritative for V1.7 coordinates whenever the host execution layer can resolve it.

Implement the narrow fix in the topology snapshot seam, preferably `DerivedTopologySnapshotBuilder` / equivalent local helper.

Required behavior:

1. Preserve `DerivedEntityRecord` identity/provenance/layer/origin semantics.
2. Preserve the existing `endpoint_key` / `derived_edge_id` contract.
3. Resolve each endpoint's existing host vertex handle through the already-supplied host map.
4. When `adapter.vertex_position(handle)` is available and returns a finite `[x,y,z]`, use that LIVE position as:
   - `DerivedEdgeRecord.world_endpoints`;
   - matching `EndpointRecord.world_coordinate`.
5. Cached `geometry_summary['start'/'end']` is allowed only as a host-free / no-live-handle fallback for pure tests or contexts that genuinely have no live coordinate authority.
6. If a live host handle exists and the adapter exposes `vertex_position`, but the position read is malformed/non-finite/unreadable, DO NOT silently substitute the cached pre-mutation coordinate. Fail closed through the narrowest existing error path with a stable diagnostic reason containing `live_vertex_position_unreadable` (endpoint key may be appended).
7. Do not mutate SketchUp from the snapshot builder.
8. Do not rewrite `geometry_summary` merely to hide the stale-cache issue.
9. Do not change `coordinate_epsilon`, `planar_z_snap`, `gap_search`, canonical-node clustering, gap pairing, structure reconstruction, or region validation.
10. Do not change Source CAD.

Expected post-fix truth for the Owner fixture:

```text
open_chain_count = 0
closed_loop_count = 1
invalid_loop_count = 0
region_count = 1
loop unresolved_flags = []
```

The canonical graph remains the product topology. This task does NOT require physical cross-group SketchUp welding and does NOT generate SketchUp Faces.

---

# 2. P1 BLOCK — CURRENT ISSUES TAB IS SHOWING HISTORICAL SOURCE REGISTRY

## 2.1 Bug

The UI says:

`当前未解决问题 / 仅显示当前已处理结果中尚未修复的问题`

but `app.js` currently appends every issue from legacy `payload.groups` to the current issue list.

`payload.groups` is derived from the original `AnalysisResult.registry` and is intentionally retained for backward compatibility / source evidence. It is NOT a current post-repair issue registry.

Result observed in real SU2020:

- Gap was applied;
- canonical topology became a Closed Loop;
- but the Issues tab still displayed the original two `open_endpoint` rows and original `gap_candidate` row;
- the red tab badge also continued to count those historical rows.

## 2.2 Frozen product semantics

Separate these concepts:

### A. Current attention / unresolved state
Derived from current `cadPrepWorkflow` + current V1.6/V1.7/V1.8 snapshots.
This owns:
- current Issues tab primary list;
- red Issues badge count;
- current top issue summary.

### B. Original source findings
Derived from legacy `AnalysisResult.registry` / `payload.groups`.
This is evidence/history only after the workspace pipeline begins.
It belongs under `详情 -> 原始检查记录` (or an equivalent existing Details subsection).

Required implementation:

1. Keep `payload.groups` backward-compatible. Do NOT delete the raw bridge field.
2. Stop appending raw `payload.groups` directly into the primary current Issues list.
3. Render source-registry records only in the existing `原始检查记录` / Details surface.
4. If a current card has `REVIEW_REQUIRED` or `FAILED`, it may create a truthful current issue row from the card.
5. Do not fabricate locatable current issue IDs when the current snapshot does not provide one.
6. Original source records may retain their historical locate behavior inside the Details/source-record surface where safe.
7. When no current attention items remain, current Issues list shows `当前没有未解决问题` and the red badge is hidden even if original source records still exist.

## 2.3 Top issue-summary counting

Current `_collect_chips` behavior is too broad because it can aggregate arbitrary card metrics, including non-problem metrics such as `closed_loops`, `regions`, `holes`, applied counts, etc.

Fix semantics:

- top problem counts must count only metrics that semantically represent CURRENT attention;
- CLEAN/APPLIED success metrics MUST NOT inflate issue counts;
- `closed_loops`, `regions`, `holes`, repaired/applied counts are not issues;
- ACTIONABLE / REVIEW_REQUIRED / FAILED states may contribute problem counts using explicitly defined problem metrics;
- if an exact truthful count is unavailable, show the attention state without inventing a numeric count.

Prefer a small explicit helper such as `collect_issue_chips` / equivalent rather than inferring issue semantics from every metric indiscriminately.

---

# 3. P1 BLOCK — `重新检测` MUST REFRESH CURRENT WORKSPACE, NOT REBUILD

Frozen A2 contract:

> `重新检测` checks the CURRENT workspace only. It must not silently rebuild the workspace.

Current frontend issue-summary CTA is hard-wired to `rebuild_workspace`.

Required fix:

1. Normal `重新检测` action on a ready workspace MUST dispatch `refresh_cad_prep`.
2. `refresh_cad_prep` must preserve the current workspace and run diagnostics on it.
3. Do not change Orchestrator refresh semantics unless a source review proves the existing implementation violates the frozen contract.
4. `rebuild_workspace` remains available only for explicit recovery actions such as `重新生成工作副本` in STALE/FAILED recovery UI.
5. Prefer an explicit presenter field such as `issue_summary.cta_callback` (additive schema) so the frontend does not infer callback semantics from Chinese button text.
6. For FAILED/STALE states, do not disguise rebuild as `重新检测`; use the existing explicit recovery actions.

Acceptance:

- clicking `重新检测` on a healthy ready workspace does not change `workspace_id`;
- no source/derived rebuild occurs;
- diagnostics refresh.

---

# 4. P2 — PLANAR CARD COUNT / COPY MAPPING

## 4.1 READY_TO_NORMALIZE

Current V1.6 proposal uses:

`movable_count`

The current presenter looks for legacy/non-existent `movable` / `proposed_movable`, so the UI can show:

- state: `可安全校正`;
- enabled `修复 Z 轴` button;
- summary: `未发现需要 Z 校正的点`.

Fix:

1. Read `proposal['movable_count']` as authoritative.
2. Legacy aliases may remain as defensive fallback if useful.
3. If state is `READY_TO_NORMALIZE` but exact count is unavailable, use generic truthful copy such as `发现可安全校正的 Z 偏差`; never say `未发现`.
4. Keep `outlier_count` semantics unchanged.

## 4.2 APPLIED audit count

Current executor audit publishes `applied_count`.
The presenter currently looks for `moved` / `moved_applied`.

Use `applied_count` as authoritative for the applied Z count, with legacy fallback only if needed.

No V1.6 algorithm change.

---

# 5. P2 UX POLISH — STRUCTURE WARNING COPY MUST BE SPECIFIC WHEN EVIDENCE EXISTS

Do not change V1.8 classification.
Only improve product-facing copy.

Preferred mapping when `READY_WITH_WARNINGS`:

- `open_chain_count > 0` -> summary communicates `存在未闭合轮廓`;
- `invalid_loop_count > 0` and loop flags include `non_planar_loop` -> summary communicates `存在非平面闭合轮廓，暂不能形成区域`;
- other known invalid-loop/unresolved reasons -> concise corresponding generic `存在无效轮廓或需确认结构`;
- only when no more specific evidence is available may fallback to `结构已重建，但存在需要人工查看的项`.

Do not expose raw Ruby exception strings in the primary UI.
Do not invent repair actions for V1.8.

---

# 6. TEST DEBT — HIDDEN CSS REGRESSION GUARD FALSE PASS

The production `[hidden]` fix has already passed real SU2020 Owner verification.
Do NOT reopen the production hidden-semantics fix unless a real regression is found.

A source-level test currently uses naive selector-order searching and can match selector text inside a CSS comment, making the guard pass for the wrong reason.

Fix the TEST only / primarily:

- ensure selector assertions match actual CSS rules, not comments;
- stripping CSS comments before selector-order assertions is acceptable;
- or use an equivalent parser/anchored rule matcher compatible with the current test environment;
- add a regression proving a comment alone cannot satisfy the selector check.

Do not reorder working production CSS merely to satisfy a brittle test.

---

# 7. ALLOWED PRODUCTION FILES

Expected / allowed production scope:

- `extension/su_ai_plugin/core/endpoint_record.rb`
  - specifically `DerivedTopologySnapshotBuilder` current-coordinate read seam;
- `extension/su_ai_plugin/cad_prep_workflow_presenter.rb`;
- `extension/su_ai_plugin/html/app.js`;
- `extension/su_ai_plugin/ui_bridge.rb` only if additive presentation/current-issue shaping is mechanically required;
- `extension/su_ai_plugin/cad_prep_workflow_orchestrator.rb` only if a narrow source-level wiring correction is strictly required to preserve the already-frozen refresh contract; otherwise DO NOT TOUCH;
- focused tests.

Before editing any production file outside this list, STOP and report why it is required.

---

# 8. FORBIDDEN CHANGES

Do NOT change:

- Source CAD ownership or mutability;
- Derived Workspace architecture;
- host-state validation / reconciliation semantics;
- broad Observer architecture;
- V1.5 duplicate algorithm;
- V1.6 normalization math / tolerance;
- V1.7 gap pairing / conflict / canonical-node algorithm;
- V1.8 reconstruction / containment / region algorithm;
- `coordinate_epsilon`, `planar_z_snap`, `gap_search` defaults;
- physical cross-group welding as a correctness requirement;
- SketchUp Face generation;
- Undo transaction architecture;
- Toolbar / loader unless a regression is directly proven;
- MCP / LLM / Agent;
- V1.9B / PreparedCadDataset / final release gate.

Do not "fix" P0 by widening `coordinate_epsilon` or accepting the stale `0.2 mm` Z value.

---

# 9. REQUIRED AUTOMATED TESTS

## 9.1 P0 current-coordinate unit/regression

Create a deterministic test where:

- a derived record's cached `geometry_summary` contains old Z;
- host vertex handle resolves to a different CURRENT Z through `adapter.vertex_position`;
- `DerivedTopologySnapshotBuilder` must publish the live Z in BOTH edge and endpoint records;
- cached old Z must not leak into canonical coordinates.

Add failure coverage:

- live handle exists + adapter exposes `vertex_position` + unreadable/non-finite current position -> fail closed; no stale-cache substitution.

## 9.2 Combined Z + Gap -> Region integration regression

Automated fixture equivalent to Owner test:

1. one safe planar drift;
2. one safe endpoint gap;
3. initial A2 diagnostics: Planar ACTIONABLE + Gap ACTIONABLE but Gap repair disabled;
4. apply Z;
5. downstream Gap recomputed and repair enabled;
6. apply Gap;
7. Structure recomputed;
8. assert:
   - `open_chain_count == 0`;
   - `closed_loop_count == 1`;
   - `invalid_loop_count == 0`;
   - `region_count == 1`;
   - loop does not carry `non_planar_loop`.

This must exercise the production-like WorkingModeRunner / orchestrator path as far as the existing fake-host test harness reasonably permits.

## 9.3 Current Issues / badge

Test:

- initial source registry contains `open_endpoint` and `gap_candidate`;
- after current workspace state no longer reports those issues, they remain available as original-source evidence;
- they do NOT appear in primary current Issues rows;
- they do NOT inflate the red badge;
- source records are still reachable in Details / original source record surface.

## 9.4 Issue chip semantics

Test that:

- CLEAN structure metrics (`closed_loops`, `regions`, `holes`) do not count as issues;
- APPLIED repair metrics do not count as issues;
- ACTIONABLE / REVIEW_REQUIRED current problem metrics do count;
- unavailable exact count yields truthful non-numeric attention copy rather than fake zero.

## 9.5 Refresh callback

Test:

- `重新检测` -> `refresh_cad_prep`;
- no normal ready-state `重新检测` button -> `rebuild_workspace`;
- explicit STALE/FAILED recovery may still dispatch `rebuild_workspace` with label `重新生成工作副本`;
- refresh preserves workspace identity in orchestrator/runner integration coverage.

## 9.6 Planar presenter

Test:

- `READY_TO_NORMALIZE + movable_count=1` -> card metric `1 可校正` + non-contradictory summary;
- missing count under READY_TO_NORMALIZE -> generic actionable summary, never `未发现需要 Z 校正的点`;
- APPLIED + `audit.applied_count=1` -> `1 已移动/已校正` equivalent.

## 9.7 Structure copy

Test specific warning mapping for:

- open chain;
- non-planar invalid loop;
- generic warning fallback.

## 9.8 Existing regression suites

Run and report separately:

- V1.6 focused;
- V1.7 focused;
- V1.8 focused;
- V1.9A Orchestrator;
- V1.9A Presenter;
- UI bridge;
- HTML source-level render guards;
- DOM click-through tests;
- Legacy compatibility;
- RBZ smoke;
- full Ruby suite;
- `git diff --check`.

Known pre-existing baseline failures must remain explicitly separated from new failures. Do not report an aggregate PASS if failures/errors remain.

---

# 10. REAL SU2020 OWNER RE-VERIFICATION TARGET

Pi cannot declare Owner PASS. Pi must build the RBZ and return control.

AIPM/Owner will rerun the same real SU2020 scenario:

```text
Start
-> Planar + Gap both detected
-> Gap repair disabled while Planar ACTIONABLE
-> Apply Z
-> Gap automatically recomputed/unlocked
-> Apply Gap
-> Structure automatically recomputed
```

Expected final Owner evidence:

```text
workspace = ready
open_chain_count = 0
closed_loop_count = 1
invalid_loop_count = 0
region_count = 1
```

UI expected:

- Structure becomes clean / usable;
- no stale `open_endpoint` / `gap_candidate` in current Issues;
- no red badge when current issue count is zero;
- original source findings remain only under Details / original source evidence;
- Z actionable copy/count is internally consistent;
- `重新检测` refreshes the same workspace rather than rebuilding it;
- no false STALE banner;
- four tabs remain functional.

Only after this Owner re-test can AIPM consider `V1.9A CLOSED`.

---

# 11. CODEX RISK TRIGGER

`CODEX_RISK_TRIGGER = YES (POST-IMPLEMENTATION, NARROW)`

Reason:

P0 touches the V1.6 -> V1.7 current-geometry authority seam feeding canonical topology. This is a high-risk data/state boundary even though the implementation should be small.

Order:

1. Pi implements + tests + commits + pushes;
2. AIPM performs direct source/diff review first;
3. if P0 changed only the frozen live-coordinate read seam as specified, request a narrow Codex review of that boundary before final V1.9A closure OR fold it into the immediately-following final V1.x review if AIPM judges the diff trivially local and Owner real-SU evidence is clean;
4. Codex remains review-only.

Pi MUST NOT invoke Codex itself.

---

# 12. REQUIRED PI RETURN

Return in `Review/CURRENT_PI_REPORT.md`:

1. starting HEAD / implementation HEAD / final HEAD;
2. exact files changed;
3. P0 root-cause confirmation;
4. exact live-coordinate authority implementation;
5. fail-closed behavior for unreadable live positions;
6. current-vs-original issue rendering semantics;
7. refresh callback proof;
8. planar presenter mapping proof;
9. structure warning copy mapping;
10. hidden-test guard correction;
11. focused test counts;
12. full-suite counts with pre-existing failures separated;
13. RBZ path / bytes / entries / SHA-256;
14. confirmation that V1.5–V1.8 algorithms/tolerances and V1.9B remained untouched;
15. `CODEX_RISK_TRIGGER` acknowledgment;
16. any deviation / STOP item.

Pi must update `CURRENT_STATE.md`, create the final stable commit, push `origin/dev/v1.9`, then STOP and return control to AIPM.

END
