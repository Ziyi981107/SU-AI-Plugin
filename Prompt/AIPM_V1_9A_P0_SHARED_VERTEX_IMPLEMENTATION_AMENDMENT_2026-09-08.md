# AIPM V1.9A P0 SHARED-VERTEX IMPLEMENTATION AMENDMENT

Project: SU-AI-Plugin
Stage: V1.9A — Final Block Fix
Date: 2026-09-08
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Reviewer input: Codex xHigh review — FIX REQUIRED
Target branch: `dev/v1.9`
Starting baseline for this amendment: `5b6cfbd9be8afb0245cb3800919a36f2c41c3dae`
Status: AUTHORITATIVE NARROW AMENDMENT
V1.9B: NOT AUTHORIZED / NOT STARTED

This document narrowly amends the frozen V1.6/V1.7 implementation contract where the previous wording “one transform batch” was ambiguous. It does NOT reopen the V1.6 analysis algorithm, V1.7 canonical topology algorithm, or V1.8 reconstruction algorithm.

Related documents:

- `Prompt/AIPM_V1_9A_FINAL_BLOCK_FIX_2026-09-07.md`
- `Prompt/CODEX_V1_9A_P0_CURRENT_GEOMETRY_SHARED_VERTEX_REVIEW_2026-09-08.md`
- `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
- `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
- `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_8_LOOP_REGION_2026-09-02.md`

If this amendment conflicts with older V1.6 wording about “one transform batch”, THIS amendment wins for the shared-physical-vertex host-mutation boundary.

---

# 1. FINAL ROOT-CAUSE DECISION

Codex independently confirmed all three AIPM BLOCKS.

## BLOCK P0-01 — wrong V1.7 live handle

`workspace.handle_for(derived_id)` is a derived GROUP / entity wrapper, not an endpoint Vertex.

Correct current-coordinate authority is:

```text
endpoint_key
-> host_vertex_map[endpoint_key]
-> actual endpoint Vertex
-> adapter.vertex_position(Vertex)
-> current world coordinate
```

The Group remains authoritative for derived ownership / discard / edge lookup / provenance, not endpoint position.

## BLOCK P0-02 — one logical CAD vertex can have multiple physical derived Vertex handles

The derived representation intentionally gives independently-owned geometry to derived edge groups. Two source edges sharing one logical coordinate may therefore expose two distinct physical endpoint Vertex handles at the same world position.

V1.6 must continue to analyze this as ONE logical CAD vertex, but a safe logical normalization must mutate ALL eligible physical copies belonging to that logical vertex.

## BLOCK P0-03 — prior P0 tests are not credible evidence

The submitted P0 tests do not model the real Group -> Edge -> Vertex contract and were not executed. They must be replaced / corrected, not patched to bless the incorrect implementation.

---

# 2. FROZEN TERMINOLOGY AND OWNERSHIP

Use these concepts consistently.

## 2.1 Logical vertex

A deterministic analysis-space coordinate cluster representing one CAD point under `coordinate_epsilon`.

- Analyzer dedupe unit.
- `movable_count` unit.
- User-facing “N 个可校正点” unit.

## 2.2 Physical vertex occurrence

One actual derived host endpoint Vertex belonging to one independently-owned derived edge/group.

A single logical vertex may own 1..N physical occurrences.

Each physical occurrence must preserve at least:

- `vertex_handle`;
- `derived_id`;
- `endpoint_key` (`<derived_id>.start|end`);
- `source_occurrence_ids`;
- enough existing provenance to trace the occurrence without changing Source CAD ownership.

Do NOT require physical welding or shared host identity.

## 2.3 One logical transaction vs one host primitive call

The frozen requirement is now:

> One user-triggered Planar Apply = ONE outer SketchUp operation / one atomic logical transaction.

It is NOT required to be one `Entities#transform_by_vectors` primitive call.

Inside that single outer operation, Pi may perform multiple owner-safe primitive calls so long as:

- every call operates only on eligible derived physical Vertex handles;
- no call mixes Vertex handles from incompatible owner `Entities` collections;
- all physical occurrences are preflighted before mutation;
- all physical occurrences are postvalidated before commit;
- any mutation or postvalidation failure aborts the ONE outer operation;
- Source CAD is untouched.

For this fix the preferred minimal implementation is:

```text
begin one outer SketchUp operation
for each physical Vertex occurrence:
    adapter.transform_vertices_by_vectors([vertex], [vector])
postvalidate every physical Vertex occurrence
commit once
```

This deliberately avoids cross-group batching and brittle owner introspection.

---

# 3. V1.6 PROPOSER — LOGICAL DEDUPE + PHYSICAL FAN-OUT

Target file:

`extension/su_ai_plugin/core/planar_normalization_proposer.rb`

## 3.1 Preserve analysis behavior

DO NOT change:

- dominant Z band logic;
- target Z calculation;
- `planar_z_snap`;
- `coordinate_epsilon`;
- outlier classification;
- Curve / Face safety exclusion;
- shared-with-unsafe exclusion;
- logical position clustering semantics.

`candidate_positions` remains one entry per logical coordinate cluster.

## 3.2 Replace singular physical ownership

Current candidate state effectively keeps only:

```text
vertex_handle: first physical handle
```

That is insufficient.

Each logical candidate must retain ALL eligible physical occurrences that contributed to that logical coordinate.

Recommended minimum conceptual shape:

```ruby
{
  logical_coordinate: [x, y, z],
  physical_occurrences: [
    {
      vertex_handle: <actual endpoint Vertex>,
      derived_id: <derived id>,
      endpoint_key: '<derived id>.start|end',
      source_occurrence_ids: [...]
    },
    ...
  ],
  derived_ids: [...],
  source_occurrence_ids: [...]
}
```

Exact internal naming may differ, but the semantics are frozen.

## 3.3 Identity dedupe is mandatory

Physical handles must be deduped by OBJECT IDENTITY, not value equality.

Do NOT rely on `Array#include?` / `==` for host-handle uniqueness because fake Struct handles with identical XYZ may compare equal while representing different physical Vertices.

Use an explicit Ruby-2.2-compatible identity rule, e.g. `object_id` or `equal?` based dedupe.

## 3.4 Duplicate logical-coordinate branch

When a second SAFE edge endpoint joins an existing logical coordinate cluster:

- append its physical occurrence if its Vertex handle is identity-unique;
- union its `derived_id`;
- union all `source_occurrence_ids`;
- retain endpoint provenance.

If any contributor makes the logical cluster unsafe under existing shared-with-unsafe rules, the entire logical cluster remains excluded exactly as before.

## 3.5 Proposal expansion

For each analyzer `proposed_move`:

- resolve its ONE logical candidate;
- keep ONE logical move / ONE logical count;
- fan out the same target Z / corresponding Z-only move to every eligible physical occurrence.

The proposal must expose enough data for the executor to preflight and mutate every physical occurrence without reconstructing provenance heuristically.

Backward-compatible legacy fields may remain if existing consumers need them, but they must not silently collapse multiple physical handles into one.

---

# 4. V1.6 EXECUTOR — ONE OUTER OPERATION, MULTIPLE OWNER-SAFE CALLS

Target file:

`extension/su_ai_plugin/core/planar_normalization_executor.rb`

## 4.1 Preflight ALL physical occurrences before mutation

Before opening or mutating the operation, validate every physical occurrence in the proposal:

- handle is present;
- handle set is identity-unique;
- `adapter.vertex_position(handle)` is readable;
- current position is finite `[x,y,z]`;
- target Z is finite;
- vector is exactly Z-only;
- every physical occurrence for a logical move is consistent with that logical move's current coordinate / target within existing `coordinate_epsilon`.

If a physical occurrence cannot be safely proven, fail closed BEFORE mutation using a stable reason. Do not drop only the bad copy and continue.

Do not add new tolerance constants.

## 4.2 Mutation

Open the existing single outer operation ONCE.

For each physical occurrence, call the existing adapter primitive with one handle / one vector:

```ruby
adapter.transform_vertices_by_vectors([handle], [vector])
```

Do not pass a cross-group mixed Vertex array to one primitive call.

Do not open nested SketchUp operations.

## 4.3 Failure / rollback

If any primitive call raises:

- abort the ONE outer operation once;
- transition through the existing failed-workspace path;
- report zero committed physical applications;
- do not fake rollback in Ruby after host abort;
- keep Source CAD immutable.

## 4.4 Postvalidation

After all primitive calls but BEFORE commit, read EVERY physical Vertex again.

For every physical occurrence assert under existing `coordinate_epsilon`:

- X unchanged;
- Y unchanged;
- Z == target Z;
- live read finite/readable.

If any one fails:

- abort the ONE outer operation;
- fail closed;
- no partial logical success may be published.

Commit exactly once only when ALL physical occurrences validate.

---

# 5. COUNT SCHEMA — FROZEN

Codex correctly identified two count domains. Freeze them now.

## 5.1 Proposal / user-facing logical count

`movable_count`

= number of logical coordinate clusters with safe proposed moves.

This remains the Planar card's actionable count.

## 5.2 Apply audit

Add / publish:

- `logical_applied_count` = number of logical moves fully applied and postvalidated;
- `physical_applied_count` = number of physical Vertex occurrences actually mutated and postvalidated;
- `applied_count` = backward-compatible alias of `physical_applied_count` for existing audit consumers;
- existing `moved_vertex_count` may remain physical-count semantics for compatibility.

A logical move is applied only if ALL its physical occurrences pass. Because the outer operation is atomic, successful overall apply should publish all logical moves as applied; failed apply publishes no committed success.

## 5.3 Presenter

The user-facing Planar APPLIED card must display the LOGICAL corrected-point count:

1. prefer `logical_applied_count`;
2. legacy fallback may use `applied_count` only when `logical_applied_count` is absent.

Do not describe `physical_applied_count` as “N 个逻辑顶点”.

Physical counts belong in audit / Details, not the primary product card.

---

# 6. V1.7 CURRENT-COORDINATE AUTHORITY — CORRECT HANDLE CONTRACT

Target file:

`extension/su_ai_plugin/core/endpoint_record.rb`

The prior Pi implementation is NOT acceptable and must be corrected.

## 6.1 Correct live read

For each endpoint:

```text
start_key = <derived_id>.start
end_key   = <derived_id>.end

start_vertex = host_vertex_map[start_key]
end_vertex   = host_vertex_map[end_key]
```

If a non-nil endpoint Vertex exists and adapter exposes `vertex_position`, read CURRENT coordinates from that Vertex.

Use those coordinates for BOTH:

- `DerivedEdgeRecord.world_endpoints`;
- matching `EndpointRecord.world_coordinate`.

Keep `workspace.handle_for(derived_id)` only for the existing derived Group / edge-level operations such as `edge_curve`, `edge_faces_count`, host provenance / ownership.

Never pass that Group handle to `vertex_position` as the endpoint coordinate authority.

## 6.2 Fail-closed vs fallback

### Fail closed

If ALL are true:

- endpoint host Vertex handle exists;
- adapter exposes `vertex_position`;
- but the call raises OR returns nil OR malformed/non-numeric/non-finite data;

then raise / propagate the stable narrow failure:

`live_vertex_position_unreadable`

with endpoint key evidence.

Do NOT use cached `geometry_summary` in this situation.

### Cached fallback allowed

Cached build-time `geometry_summary` may be used only when there is genuinely no live endpoint authority, e.g.:

- host-free pure test with no adapter;
- endpoint host map has no handle for that endpoint;
- adapter genuinely lacks the live-read capability.

Do not rewrite `geometry_summary`.

---

# 7. NARROW PRESENTER MISSES FROM SOURCE REVIEW

Target file:

`extension/su_ai_plugin/cad_prep_workflow_presenter.rb`

Do not reopen already-PASS current-issues / badge / healthy refresh behavior.

## 7.1 Structure warning must read actual V1.8 shape

Authoritative V1.8 metrics include:

- `open_chain_count`;
- `closed_loop_count`;
- `region_count`;
- `hole_count`;
- `invalid_loop_count`.

Specific loop validation evidence lives on the loop records, especially:

```text
closed_loops[].unresolved_flags
```

Required presenter behavior:

- `open_chain_count > 0` -> `存在未闭合轮廓`;
- `invalid_loop_count > 0` AND any current closed loop has `non_planar_loop` -> `存在非平面闭合轮廓，暂不能形成区域`;
- other invalid-loop evidence -> generic invalid-structure warning;
- only no-specific-evidence warning -> generic manual-review fallback.

Compatibility aliases such as legacy `open_chains` may remain as fallback, but actual frozen V1.8 keys win.

Do NOT modify V1.8.

## 7.2 FAILED summary CTA

For `overall_state == FAILED`:

- issue_summary `cta = nil`;
- issue_summary `cta_callback = nil`.

The existing recovery surface owns explicit recovery (`重新生成工作副本` / `放弃工作副本`).

Do not change the generic FAILED user copy or raw-error boundary.

---

# 8. ALLOWED PRODUCTION FILES

This amendment authorizes narrow changes only in:

- `extension/su_ai_plugin/core/endpoint_record.rb`;
- `extension/su_ai_plugin/core/planar_normalization_proposer.rb`;
- `extension/su_ai_plugin/core/planar_normalization_executor.rb`;
- `extension/su_ai_plugin/core/derived_workspace_adapter.rb` ONLY for fake-adapter/test seams strictly required by these regressions;
- `extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb` ONLY if a minimal adapter-contract correction is proven necessary; prefer existing one-handle primitive behavior;
- `extension/su_ai_plugin/cad_prep_workflow_presenter.rb`;
- focused tests for these boundaries.

`working_mode_runner.rb` is NOT pre-authorized for algorithmic changes. If a narrow wiring change is mechanically necessary for passing the corrected data shape, STOP and report the exact need before editing it.

`cad_prep_workflow_orchestrator.rb`, `ui_bridge.rb`, `html/app.js`, CSS, toolbar/loader are FROZEN for this packet unless a regression from the corrected backend is directly proven.

---

# 9. FORBIDDEN CHANGES

Do NOT change:

- Source CAD mutability / ownership;
- Derived Workspace ownership model;
- V1.5 duplicate algorithm;
- V1.6 dominant-band / target-Z / outlier algorithm;
- V1.6 tolerance defaults;
- V1.7 gap pairing / mutual candidate / conflict logic;
- V1.7 canonical node clustering semantics;
- V1.8 reconstruction / region / containment algorithm;
- `coordinate_epsilon`, `planar_z_snap`, `gap_search` defaults;
- physical welding;
- SketchUp Face generation;
- broad Observer architecture;
- Undo / host-state redesign;
- Toolbar / loader;
- current Issues / badge semantics already source-reviewed PASS;
- MCP / LLM / Agent;
- V1.9B / PreparedCadDataset / Release Gate.

Do not hide any failure by widening tolerance or accepting a stale coordinate.

---

# 10. REQUIRED REGRESSION TESTS

Pi must DELETE/REPLACE or correct the misleading P0 tests so they model the real contracts. Do not preserve incorrect assertions merely for test-count continuity.

## 10.1 Handle-contract live-read test

Build a derived edge through the real fake-workspace path:

```text
workspace.handle_for(derived_id) -> FakeGroup
adapter.edge_endpoints(group) -> two distinct FakeVertex handles
```

Spy / assert that V1.7 `vertex_position` receives those endpoint Vertex handles, not Group / FakeEdge.

Mutate start/end live positions independently and assert the correct per-endpoint values reach:

- `DerivedEdgeRecord.world_endpoints`;
- each EndpointRecord.

## 10.2 Live-read fail closed

With a real endpoint Vertex handle present:

- `vertex_position -> nil` => fail closed;
- raises => fail closed;
- malformed => fail closed;
- non-finite => fail closed.

All use `live_vertex_position_unreadable`.

Separately prove cached fallback when NO endpoint live authority exists.

## 10.3 Shared logical coordinate proposer test

Two independently-derived safe edges share the same logical coordinate.

Assert:

- one logical candidate / one logical proposed move;
- `movable_count == 1` for that coordinate;
- candidate/proposal retains TWO identity-distinct physical Vertex handles;
- both derived IDs / endpoint keys / source occurrence provenance are retained.

Use identity assertions, not Struct value equality.

## 10.4 Executor fan-out success

One logical move with two physical handles in distinct derived groups.

Assert:

- exactly one outer `begin_operation`;
- owner-safe mutation primitive invoked for each physical Vertex, not one mixed cross-group batch;
- both physical Z values reach target;
- XY unchanged;
- exactly one commit;
- `logical_applied_count == 1`;
- `physical_applied_count == 2`;
- `applied_count == 2` legacy alias.

## 10.5 Mid-mutation failure atomicity

Add the narrowest fake-adapter test seam needed to fail on the second physical primitive call.

Assert:

- begin once;
- first primitive may execute in the fake;
- second raises;
- abort once;
- no commit;
- result/workspace FAILED;
- no committed logical success is reported.

The test must model host operation rollback semantics; it must not claim physical rollback from fake in-memory state unless the fake explicitly models abort restoration. The production contract being tested is operation control + no published partial success.

## 10.6 Postvalidation failure atomicity

Inject a narrow test condition where one physical Vertex does not validate after mutation.

Assert:

- abort once;
- no commit;
- FAILED;
- no published partial logical success.

## 10.7 TRUE end-to-end Owner-equivalent integration

Use FOUR source edges forming an almost-closed rectangle plus the eventual repair bridge:

```text
A -- B
|    |
E -- D/C shape as rectangle perimeter
```

More explicitly, mirror the real Owner fixture:

```text
A = (0, 0, 0)
B = (W, 0, 0.2mm)
C = (W, H, 0)
D = (0, H, 0)
E = (0, 1mm, 0)

source edges:
A-B
B-C
C-D
D-E

missing E-A = 1mm gap
```

Use tolerance values equivalent to production defaults or equally strict values where:

`coordinate_epsilon << 1mm <= gap_search`

and `0.2mm <= planar_z_snap` while `0.2mm > coordinate_epsilon`.

Exercise the production-like orchestrator / WorkingModeRunner path:

```text
start
-> Planar ACTIONABLE
-> Gap detected but repair disabled while Planar ACTIONABLE
-> apply Planar
-> BOTH physical copies of B reach target Z
-> Gap automatically recomputed / unlocked
-> apply Gap
-> Structure automatically recomputed
```

Final assertions:

```text
workspace == ready
open_chain_count == 0
closed_loop_count == 1
invalid_loop_count == 0
region_count == 1
no closed loop carries non_planar_loop
```

Do not substitute a snapshot-builder-only test for this integration regression.

## 10.8 Presenter regressions

Assert:

- APPLIED Planar card prefers `logical_applied_count` for user-facing count;
- physical count remains available only in audit/details semantics;
- `open_chain_count` drives open-loop warning copy;
- nested `closed_loops[].unresolved_flags` containing `non_planar_loop` drives specific non-planar warning;
- FAILED issue_summary has no normal CTA;
- existing current Issues / badge / healthy `refresh_cad_prep` behavior remains unchanged.

---

# 11. TEST EXECUTION REQUIREMENT

The previous Pi submission could not execute Ruby because its local Ruby side-by-side setup was broken. This time unexecuted new Ruby tests are NOT acceptable as completion evidence.

Pi may repair its LOCAL interpreter/PATH/toolchain outside the repository or use an already-supported project Ruby interpreter. Do not modify project architecture merely to make tests runnable.

Before final return Pi must report:

- exact Ruby executable path;
- `ruby -v`;
- focused test commands + actual counts;
- full suite result with known pre-existing failures separated;
- DOM / HTML / RBZ smoke as applicable;
- `git diff --check`.

If a runnable Ruby test environment cannot be restored, Pi must STOP with `TEST_EXECUTION_BLOCKED` and must NOT declare the implementation ready for Owner testing.

---

# 12. RBZ + REAL OWNER RECHECK

If automated evidence passes, rebuild:

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

Return path, bytes, entry count and SHA-256.

Pi cannot close V1.9A.

After AIPM source/diff recheck, Owner will rerun the SAME SU2020 fixture.

Owner PASS target:

```text
Planar + Gap detected
Gap locked before Planar
Apply Planar
Gap auto-unlocks
Apply Gap
Structure auto-recomputes
workspace = ready
open_chain_count = 0
closed_loop_count = 1
invalid_loop_count = 0
region_count = 1
```

UI target:

- no stale historical open_endpoint / gap_candidate in Current Issues;
- no red badge when current issues are zero;
- original source evidence remains under Details;
- Planar counts/copy are logical and consistent;
- Structure warning copy uses actual V1.8 evidence;
- FAILED recovery remains explicit;
- no false STALE banner;
- four tabs remain functional.

Only AIPM/Owner may then declare `V1.9A CLOSED`.

---

# 13. REQUIRED PI RETURN

Update:

- `CURRENT_STATE.md`;
- `Review/CURRENT_PI_REPORT.md`.

Report:

1. starting HEAD / implementation HEAD / final HEAD;
2. exact files changed;
3. corrected Group -> endpoint Vertex live-read path;
4. fail-closed / fallback matrix;
5. proposer logical-candidate -> physical-occurrence data shape;
6. identity dedupe rule;
7. executor one-operation / multi-primitive implementation;
8. preflight + postvalidation rules;
9. logical vs physical count schema and backward compatibility;
10. corrected/replaced P0 tests;
11. true Z+Gap->Region integration result;
12. mutation-failure + postvalidation-failure atomicity evidence;
13. presenter narrow fixes;
14. Ruby executable + version + actual test counts;
15. full regression results with pre-existing failures separated;
16. RBZ path / bytes / entry count / SHA-256;
17. confirmation no forbidden algorithms/tolerances/V1.9B changed;
18. deviations / STOP items.

Then commit, push only `origin/dev/v1.9`, set:

- `AIPM_REVIEW = PENDING`;
- `OWNER_SU2020 = NOT YET`;
- `V1.9B = NOT STARTED`;

and STOP.

END
