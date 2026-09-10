# AIPM — V1.9A RFR CODEX NARROW RECHECK CORRECTION

Project: `SU-AI-Plugin`  
Stage: V1.9A Final Owner Gate  
Date: 2026-09-10  
Current docs-only HEAD: `15e00ee26aa50e257806cc6ff25284ed6f285e46`  
Reviewed production implementation: `a42fd629654b55187d3d3e7c1b6eec19c44f8d8d`  
Trigger: Codex xHigh final narrow recheck  
Status: **FIX REQUIRED — TWO NARROW BLOCKS ONLY**  
Owner SU2020: **RECHECK BLOCKED**  
V1.9B: **NOT STARTED**

## Owner Summary

The real-SU2020 stale-planar refresh root cause is correctly fixed in direction: live endpoint Vertex coordinates are now the current-coordinate authority and the refresh contract is preserved.

Codex found two narrow residuals that AIPM confirms from current source:

1. The documented no-live cached fallback is unreachable in the proposer's first safety pass when endpoint handles exist but the adapter lacks `vertex_position`.
2. The proposer-level RFR failure matrix omits behavioral wrong-length live-coordinate coverage.

No architecture redesign is required. Do not reopen executor, shared-vertex fan-out, WorkingModeRunner, orchestrator, V1.7, V1.8, UI, or V1.9B.

---

## BLOCK CXR-01 — no-live cached fallback must be reachable in the first pass

File:

`extension/su_ai_plugin/core/planar_normalization_proposer.rb`

### Current defect

The first pass currently calls `_live_position_for` for both endpoints with:

```ruby
cached_pos: nil
fail_closed: true
```

If endpoint handles exist but `adapter.respond_to?(:vertex_position)` is false, `_live_position_for` returns nil because `fail_closed` is true. The edge is then marked unsafe before the second pass can use its valid cached `geometry_summary` coordinates.

That contradicts the frozen contract:

- **live authority exists + unreadable live read** -> fail closed, never use cache;
- **live-coordinate capability genuinely does not exist** -> valid immutable cached `geometry_summary` may be used for the host-free / backward-compatible analysis path.

### Required correction

Keep the same two-pass proposer architecture.

In the first pass:

1. Resolve the existing cached endpoint coordinates from `rec.geometry_summary`.
2. Distinguish **live capability absent** from **live capability present but unreadable**.
3. If the adapter exposes `vertex_position` and endpoint handles exist:
   - live read is authoritative;
   - nil / raise / wrong length / non-Numeric / NaN / Infinity -> mark unsafe / fail closed;
   - never substitute cached coordinates.
4. If the adapter genuinely lacks `vertex_position`:
   - sanitize and use valid cached endpoint coordinates for the first-pass eligibility gate;
   - malformed cached coordinates remain unsafe.
5. Do not mutate `geometry_summary`.
6. Do not weaken the real SketchUp path.

### Preferred minimal implementation shape

Do not redesign `_live_position_for` unnecessarily.

A small repo-fitting option is:

```ruby
has_live_reader = adapter.respond_to?(:vertex_position)

start_pos = _live_position_for(
  adapter: adapter,
  handle: endpoints[0],
  cached_pos: s_cached,
  endpoint_key: "#{did}.start",
  fail_closed: has_live_reader
)

end_pos = _live_position_for(
  adapter: adapter,
  handle: endpoints[1],
  cached_pos: e_cached,
  endpoint_key: "#{did}.end",
  fail_closed: has_live_reader
)
```

Equivalent implementations are allowed if they preserve the exact semantic split above.

Do not broaden this fix to missing edge/group handles unless a new focused regression proves that is necessary. The Codex block concerns the case where endpoint handles exist and only `vertex_position` capability is absent.

### Required behavioral tests

Add proposer-level tests:

**CXR-01A — no live reader + valid cached drift**
- endpoint handles exist;
- adapter still supports edge safety/endpoints but does NOT expose `vertex_position`;
- cached `geometry_summary` contains the original 0.2 mm drift;
- proposer must preserve backward-compatible cached analysis;
- expected result: `READY_TO_NORMALIZE`;
- proposal exists;
- max movement reflects the cached 0.2 mm drift.

**CXR-01B — live reader exists but unreadable**
- preserve the complete existing fail-closed matrix;
- nil / raise / malformed / non-Numeric / NaN / Infinity must remain `REVIEW_REQUIRED` / no proposal / no cached resurrection.

Optional but useful:
- no live reader + malformed cached coordinate -> safe failure, no crash.

---

## BLOCK CXR-02 — proposer-level wrong-length live-coordinate behavior is missing

File:

`tests/test_v19a_final_p0_live_coordinates.rb`

### Current defect

RFR-04 currently behaviorally tests:

- nil;
- exception;
- non-Array Hash;
- non-Numeric;
- NaN;
- Infinity.

It does not behaviorally test wrong-length Arrays at the changed proposer seam. Existing wrong-length tests elsewhere are not sufficient because they exercise another component.

### Required tests

Add proposer-level regressions for BOTH:

```ruby
[0.0, 0.0]            # length 2
[0.0, 0.0, 0.0, 1.0] # length 4
```

With live endpoint authority present and stale cached drift available, each test must prove:

- state is `REVIEW_REQUIRED`;
- reason is the existing safe failure reason (expected `no_safe_eligible_vertices` unless current repo semantics dictate an equivalent stable reason);
- proposal is nil;
- cached 0.2 mm drift is NOT resurrected into `READY_TO_NORMALIZE`;
- no exception escapes.

Do not use source-string guards as the only evidence.

---

## PASS / PRESERVE

Do not reopen these already-passing boundaries:

- live Vertex is current-coordinate authority on real host path;
- Group -> edge_endpoints(Group) -> actual Vertex -> vertex_position(Vertex);
- repaired live geometry survives refresh;
- shared logical vertex retains all identity-distinct physical occurrences;
- one logical move fans out to all physical occurrences;
- executor preflight / one outer operation / post-validation atomicity;
- logical vs physical count semantics;
- refresh scans the same current workspace and does not rebuild;
- Gap remains diagnosable after Planar refresh;
- final Structure target remains `0 / 1 / 0 / 1`;
- V1.7 pairing / canonical clustering;
- V1.8 reconstruction / regions;
- tolerances;
- Source CAD immutability;
- UI / Presenter / toolbar;
- V1.9B.

---

## Allowed scope

Production:

- `extension/su_ai_plugin/core/planar_normalization_proposer.rb`

Tests:

- `tests/test_v19a_final_p0_live_coordinates.rb`
- only tightly-related focused test helpers if strictly necessary.

Docs:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

Forbidden without STOP + AIPM approval:

- `planar_normalization_executor.rb`
- `working_mode_runner.rb`
- `cad_prep_workflow_orchestrator.rb`
- V1.7 / V1.8 algorithm files
- Presenter / app.js / CSS / toolbar
- tolerance defaults
- V1.9B / MCP / LLM / Agent

---

## Validation / packaging

After the two blocks are fixed:

- run the new CXR focused tests;
- run the full RFR focused suite;
- run existing V19A-P0 focused suite;
- run V1.6 planar regressions;
- run orchestrator focused suite;
- run V1.7 / V1.8 focused regressions;
- run normal `tests/run_all.rb`;
- run Node DOM;
- run `git diff --check`;
- rebuild RBZ because production proposer source changes;
- report new RBZ size / entries / SHA-256.

Existing pre-existing unrelated failures may remain, but Pi must clearly separate them from this packet.

---

## Return state

After implementation + tests + RBZ rebuild + commit/push:

- `AIPM_REVIEW = PENDING`
- `CODEX_NARROW_RECHECK = REQUIRED`
- `OWNER_SU2020 = RECHECK_BLOCKED`
- `V1.9B = NOT STARTED`

STOP and return to AIPM.

AIPM will source-review only CXR-01/CXR-02, then send the same narrow seam back to Codex xHigh. Only after both pass will Owner reinstall the new RBZ and resume the real SU2020 test.

END
