# CURRENT PI DISPATCH — V1.9A P0 SHARED-VERTEX CORRECTION

Project: SU-AI-Plugin
Stage: V1.9A — Final Block Fix
Date: 2026-09-08
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
TARGET_BRANCH: `dev/v1.9`
STARTING_BASELINE: `9f65064a2cebb5820768853efdae586385aeefa7`
STATUS: ACTIVE
AIPM_REVIEW: FIX REQUIRED -> NEW IMPLEMENTATION AUTHORIZED
CODEX_REVIEW: COMPLETE — FIX REQUIRED
OWNER_SU2020: NOT YET
V1.9B: NOT AUTHORIZED / NOT STARTED

Primary authoritative implementation amendment:

`Prompt/AIPM_V1_9A_P0_SHARED_VERTEX_IMPLEMENTATION_AMENDMENT_2026-09-08.md`

Codex review evidence:

`Prompt/CODEX_V1_9A_P0_CURRENT_GEOMETRY_SHARED_VERTEX_REVIEW_2026-09-08.md`

Prior final-block guidance remains authoritative for outcomes that are not overridden by the new amendment:

`Prompt/AIPM_V1_9A_FINAL_BLOCK_FIX_2026-09-07.md`

Older V1.6/V1.7/V1.8 blueprints remain frozen except for the explicit “one transform batch” -> “one outer operation with multiple owner-safe primitive calls” amendment in the new guidance.

---

## 0. WHY THIS DISPATCH EXISTS

AIPM direct source review + independent Codex xHigh review confirmed three P0 BLOCKS in the previous Pi implementation:

1. V1.7 live-coordinate code passed a derived Group to `vertex_position` instead of the actual endpoint Vertex.
2. V1.6 logical-coordinate dedupe retained only one physical derived Vertex for a shared logical CAD vertex, so Planar Apply could normalize only one physical copy.
3. The submitted P0 regression tests did not model the real Group -> Edge -> Vertex contract, did not execute, and did not prove the required Z + Gap -> Region integration.

Pi is now authorized to implement the coherent correction exactly within the new amendment.

---

## 1. REQUIRED OUTCOMES

Implement ALL of the following before return:

### A. Correct V1.7 live-coordinate authority

```text
endpoint_key
-> host_vertex_map[endpoint_key]
-> actual endpoint Vertex
-> adapter.vertex_position(Vertex)
```

- Group remains ownership / edge-level handle.
- live endpoint exists + nil/malformed/non-finite/raise => fail closed `live_vertex_position_unreadable`.
- cached geometry fallback only when there is genuinely no endpoint live authority.

### B. Correct V1.6 shared logical vertex fan-out

- preserve one logical analyzer candidate per coordinate cluster;
- collect all identity-distinct eligible physical endpoint Vertex occurrences in that logical candidate;
- union derived IDs / endpoint keys / source occurrence provenance;
- one logical proposed move fans out to every physical occurrence;
- object identity dedupe, not value equality.

### C. Atomic owner-safe mutation

- ONE outer SketchUp operation for one Apply action;
- one owner-safe `transform_vertices_by_vectors([vertex], [vector])` primitive per physical occurrence;
- preflight ALL occurrences before mutation;
- postvalidate ALL occurrences before commit;
- any mutation/postvalidation failure -> abort outer operation, no published partial logical success.

### D. Freeze count schema

- `movable_count` = logical actionable count;
- `logical_applied_count` = logical successful count;
- `physical_applied_count` = physical Vertex successful count;
- `applied_count` = physical legacy alias;
- `moved_vertex_count` may remain physical legacy semantics;
- Planar product UI prefers `logical_applied_count`.

### E. Complete the two narrow presenter misses

- read actual V1.8 `open_chain_count` / `invalid_loop_count` and nested `closed_loops[].unresolved_flags` for specific warning copy;
- FAILED issue summary has no normal `重新检测` CTA; recovery banner remains authoritative.

Do NOT reopen already-PASS Current Issues / badge / healthy refresh / hidden-semantics work.

---

## 2. ALLOWED / FORBIDDEN SCOPE

Follow sections 8 and 9 of:

`Prompt/AIPM_V1_9A_P0_SHARED_VERTEX_IMPLEMENTATION_AMENDMENT_2026-09-08.md`

Expected production allowlist:

- `core/endpoint_record.rb`
- `core/planar_normalization_proposer.rb`
- `core/planar_normalization_executor.rb`
- `core/derived_workspace_adapter.rb` only for fake/test seams
- production SU adapter only if strictly necessary
- `cad_prep_workflow_presenter.rb`
- focused tests

`working_mode_runner.rb` is not pre-authorized for algorithmic changes. If a narrow wiring edit is truly required, STOP and report before editing it.

Do not change V1.7 pairing/canonical clustering, V1.8 reconstruction, tolerances, Source CAD ownership, Undo/host-state architecture, Face generation, Observers, Toolbar, MCP/LLM/Agent, or V1.9B.

---

## 3. TEST OBLIGATION — ACTUAL EXECUTION REQUIRED

Correct/replace the misleading prior P0 tests. Implement every regression in section 10 of the amendment, especially:

- real Group -> endpoint Vertex live-read spy;
- nil/raise/malformed/non-finite fail closed;
- true host-free fallback;
- two physical Vertices under one logical candidate;
- identity dedupe;
- fan-out success with one begin/one commit;
- mid-mutation failure -> one abort/no commit;
- postvalidation failure -> one abort/no commit;
- TRUE Owner-equivalent end-to-end:
  `Start -> Planar+Gap -> Gap locked -> Apply Planar -> both physical shared-corner copies corrected -> Gap auto-unlocked -> Apply Gap -> Structure auto-recomputed -> open=0 / closed=1 / invalid=0 / region=1`;
- presenter logical-count / V1.8 read-shape / FAILED CTA regressions;
- preserve current Issues / badge / refresh behavior.

The previous local Ruby runtime failure cannot be used as PASS evidence.

Pi may repair its LOCAL interpreter/PATH outside the repo. Before return, actual Ruby tests must run. If no supported Ruby environment can be restored, STOP with `TEST_EXECUTION_BLOCKED`; do NOT package an Owner candidate as ready.

Report exact Ruby executable path + `ruby -v`.

---

## 4. RBZ

Only after required automated evidence is actually executed and acceptable, rebuild:

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

Report path, bytes, entry count, SHA-256.

This is an Owner re-test candidate only; Pi cannot declare V1.9A PASS/CLOSED.

---

## 5. REVIEW ORDER AFTER PI RETURNS

1. Pi implements / tests / commits / pushes.
2. AIPM direct source + diff recheck against the THREE Codex BLOCKS only.
3. If source recheck passes, no broad Codex rerun; only a narrow Codex recheck if AIPM sees ambiguity in the mutation/transaction seam.
4. Owner runs the same real SU2020 Z + Gap fixture.
5. Only then may AIPM/Owner close V1.9A.

V1.9B remains NOT STARTED.

---

## 6. REQUIRED RETURN

Follow section 13 of the amendment exactly.

Update:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

Then create the final stable commit, push only `origin/dev/v1.9`, set:

- `AIPM_REVIEW = PENDING`
- `OWNER_SU2020 = NOT YET`
- `V1.9B = NOT STARTED`

and STOP.

END
