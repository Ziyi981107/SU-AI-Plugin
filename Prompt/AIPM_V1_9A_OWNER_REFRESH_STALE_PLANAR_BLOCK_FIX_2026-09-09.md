# AIPM — V1.9A OWNER REFRESH STALE-PLANAR BLOCK FIX

Project: `SU-AI-Plugin`  
Stage: V1.9A Final Owner Gate  
Date: 2026-09-09  
Trigger: Real SketchUp 2020 Owner Test  
Status: **FIX REQUIRED — ONE NARROW PRODUCTION BLOCK**  
V1.9B: **NOT STARTED**

## Owner evidence

Real SU2020 Owner flow:

1. Start CAD Prep on the standard fixture with 0.2 mm Z drift + 1 mm endpoint gap.
2. Initial Planar state is actionable.
3. Apply Z succeeds:
   - Planar audit `status = applied`
   - `logical_applied_count = 1`
   - `physical_applied_count = 2`
   - Planar state `APPLIED`
4. User clicks `重新检测` (`refresh_cad_prep`).
5. Without rebuild / user Undo / source mutation, Planar immediately becomes `READY_TO_NORMALIZE` again.
6. The refreshed proposal reports `max_movement = 0.007874015748...` inch, exactly the original 0.2 mm drift.

This violates the frozen refresh contract: Refresh must re-scan the current derived workspace and must not resurrect a repair already applied to that workspace.

## Root cause

`CadPrepWorkflowOrchestrator.refresh` correctly calls the current-workspace read-only diagnostics and does not rebuild.

`WorkingModeRunner.compute_planar_normalization` correctly calls `PlanarNormalizationProposer.propose` against the current workspace.

The stale seam is inside:

`extension/su_ai_plugin/core/planar_normalization_proposer.rb`

The proposer resolves live endpoint Vertex handles, but its analysis/clustering `positions` are still sourced from immutable build-time:

```ruby
rec.geometry_summary['start']
rec.geometry_summary['end']
```

`DerivedEntityRecord.geometry_summary` is intentionally frozen rebuild/provenance data and must NOT be mutated after host repairs. Therefore it cannot remain the authority for current-workspace Planar diagnosis.

## Frozen authority correction

For a prepared live derived workspace:

`derived edge -> adapter.edge_endpoints(group_handle) -> actual endpoint Vertex -> adapter.vertex_position(Vertex)`

must be the current-coordinate authority for V1.6 Planar diagnosis.

`geometry_summary` remains immutable and is NOT rewritten after repair.

### Live-read matrix

When an endpoint Vertex handle exists and the adapter exposes `vertex_position`:

- successful exact 3-element Numeric finite XYZ -> authoritative current coordinate;
- nil -> fail closed;
- raise -> fail closed;
- wrong length -> fail closed;
- non-Numeric -> fail closed;
- NaN / Infinity -> fail closed.

Do NOT silently fall back to cached `geometry_summary` when live authority exists but is unreadable.

Cached `geometry_summary` fallback is allowed only when there is genuinely no live-position capability in the execution environment and doing so preserves existing host-free/backward-compatible behavior.

Use the existing unsafe/review path where possible; do not invent a second state machine.

## Required production change

Primary allowed production file:

`extension/su_ai_plugin/core/planar_normalization_proposer.rb`

The proposer must use one coherent current-position source for ALL coordinate-dependent Planar logic, including:

1. safe-edge current endpoint positions;
2. `edge_data[:positions]`;
3. logical position key / coordinate-epsilon clustering;
4. all-edge/shared-vertex clustering;
5. candidate positions sent to `PlanarNormalizationAnalyzer`;
6. movement-vector / target calculations that depend on current XYZ.

Do NOT mix live positions for one phase with cached positions for another phase.

Do NOT mutate `DerivedEntityRecord.geometry_summary`.

## Required regressions

### RFR-01 — direct stale-cache/current-live regression

Create a derived edge fixture where:

- cached `geometry_summary` still contains the original 0.2 mm Z drift;
- live endpoint Vertices have already been moved to target Z.

Calling `PlanarNormalizationProposer.propose` must NOT return `READY_TO_NORMALIZE` from the stale cached coordinate.

Expected current diagnosis: no actionable Z repair (`NO_CANDIDATE` or the existing semantically-equivalent clean state).

### RFR-02 — real orchestrated apply -> refresh regression

Use the standard Owner fixture:

A=(0,0,0)  
B=(W,0,0.2mm)  
C=(W,H,0)  
D=(0,H,0)  
E=(0,1mm,0)

Run only the production orchestrator:

`start -> apply_planar_and_refresh -> refresh`

Assert:

- after apply, both identity-distinct physical B Vertices are at target Z;
- `workspace_id` is unchanged across refresh;
- refresh does not call prepare/rebuild;
- refresh does not perform host mutation;
- refreshed Planar state is NOT `READY_TO_NORMALIZE`;
- the original 0.2 mm movement does not reappear;
- Gap remains correctly diagnosable / actionable on the current workspace.

### RFR-03 — continue through Gap after refresh

Continue:

`... -> refresh -> apply_gap_and_refresh`

Final Structure must remain:

- `open_chain_count = 0`
- `closed_loop_count = 1`
- `invalid_loop_count = 0`
- `region_count = 1`
- no `non_planar_loop`

### RFR-04 — live-read failure matrix

With live endpoint authority present, prove nil / raise / malformed / non-Numeric / NaN / Infinity never become a fabricated actionable proposal from cached geometry.

Fail closed through the existing safe/unsafe review path.

### RFR-05 — initial detection preserved

The original unmodified Owner fixture must still initially detect the 0.2 mm Z issue and preserve:

- one logical move;
- two physical B occurrences;
- existing logical/physical count semantics.

## Frozen / forbidden

Do NOT change unless a new focused regression proves a direct contradiction:

- `planar_normalization_executor.rb`
- shared-vertex fan-out architecture
- transaction / Undo semantics
- `working_mode_runner.rb`
- `cad_prep_workflow_orchestrator.rb`
- V1.7 pairing / canonical clustering
- V1.8 reconstruction / regions
- tolerances
- Source CAD ownership
- Presenter / app.js / CSS / toolbar
- V1.9B / MCP / LLM / Agent

If Pi believes any frozen file must change, STOP and report the exact reason before implementation.

## Validation / packaging

After implementation:

- run new RFR focused tests;
- run existing V19A-P0 focused suite;
- run presenter/orchestrator focused suite;
- run V1.6 / V1.7 / V1.8 regressions;
- run normal `tests/run_all.rb`;
- `git diff --check`;
- rebuild RBZ because production source changed;
- report new RBZ SHA-256 / size / entry count.

Do not present the previous RBZ SHA as Owner-candidate after this production change.

## Return state

After Pi commit/push:

- `AIPM_REVIEW = PENDING`
- `CODEX_NARROW_RECHECK = NOT YET`
- `OWNER_SU2020 = BLOCKED_BY_REFRESH_FIX`
- `V1.9B = NOT STARTED`

STOP and return to AIPM for source review.

END
