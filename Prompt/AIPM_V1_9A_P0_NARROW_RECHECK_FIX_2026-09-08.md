# AIPM V1.9A P0 NARROW RECHECK FIX — 2026-09-08

Project: SU-AI-Plugin
Stage: V1.9A — Final Block Fix
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Target branch: `dev/v1.9`
Status: AUTHORITATIVE NARROW CORRECTION
V1.9B: NOT AUTHORIZED / NOT STARTED

This document is a narrow continuation of:

- `Prompt/AIPM_V1_9A_P0_SHARED_VERTEX_IMPLEMENTATION_AMENDMENT_2026-09-08.md`
- `Prompt/CODEX_V1_9A_P0_CURRENT_GEOMETRY_SHARED_VERTEX_REVIEW_2026-09-08.md`

It does NOT reopen V1.5 / V1.6 analysis math / V1.7 pairing or canonical clustering / V1.8 reconstruction algorithms.

---

# 1. AIPM SOURCE-REVIEW VERDICT

The shared-vertex implementation direction is substantially correct:

- Group -> endpoint Vertex live-read authority is corrected;
- logical-coordinate dedupe now retains identity-distinct physical Vertex occurrences;
- executor now uses one outer operation with one single-Vertex primitive per physical occurrence;
- logical vs physical count domains are separated.

However the packet is NOT ready for Owner SU2020 yet. The following residual blocks must be fixed first.

---

# 2. BLOCK R1 — EXECUTOR PREFLIGHT IS NOT ACTUALLY FAIL-CLOSED BEFORE MUTATION

File:
`extension/su_ai_plugin/core/planar_normalization_executor.rb`

Current code collects:

```ruby
pre_positions = handles.map do |h|
  adapter.respond_to?(:vertex_position) ? adapter.vertex_position(h) : nil
end
```

but does not validate those positions before opening the SketchUp operation.

This violates the frozen amendment §4.1, which requires BEFORE mutation:

- every physical handle position readable;
- exact 3-number coordinate;
- finite XYZ;
- finite numeric target Z;
- Z-only vector;
- current position + vector consistent with the shared logical target within existing `coordinate_epsilon`.

Required correction:

1. Validate `proposal[:target_z]` is Numeric and finite BEFORE converting/publishing it. Do not allow nil/string to become `0.0` through `to_f`.
2. Require `adapter.respond_to?(:vertex_position)` for executor host mutation.
3. Read EVERY physical handle before `begin_operation`.
4. Each pre-position must be exactly 3 Numeric finite values.
5. Each vector must be exactly 3 Numeric finite values, with X/Y exactly zero.
6. For each physical occurrence verify:

```text
abs((pre_z + vector_z) - target_z) <= coordinate_epsilon
```

This is the minimum owner-safe consistency proof that the occurrence still belongs to the logical move/target being applied.
7. Any failure must return the existing failed result BEFORE opening the outer operation.

Do not widen tolerance and do not silently drop the bad physical copy.

---

# 3. BLOCK R2 — POSTVALIDATION READ EXCEPTION CAN ESCAPE WHILE OPERATION IS OPEN

File:
`extension/su_ai_plugin/core/planar_normalization_executor.rb`

Current postvalidation does:

```ruby
post_positions = handles.map { |h|
  adapter.respond_to?(:vertex_position) ? adapter.vertex_position(h) : nil
}
```

outside a rescue boundary.

If one host read raises after mutation, the exception can leave `apply` before `end_operation(commit: false)` runs. That violates the atomicity contract.

Required correction:

- post-read nil / malformed / non-numeric / non-finite / raised exception must all become postvalidation failure;
- the ONE outer operation must be aborted exactly once;
- no commit;
- workspace/result FAILED;
- no published logical/physical applied success;
- unexpected host read must NOT escape with an operation still open.

Add focused regression tests for:

- unreadable pre-position => zero `begin_operation` calls;
- pre-position read raises => zero `begin_operation` calls;
- post-position read raises => one begin + one abort + zero commit;
- post-position returns malformed/non-finite => one begin + one abort + zero commit.

---

# 4. BLOCK R3 — V1.7 CACHED-FALLBACK CONTRACT IS TOO STRICT IN ONE CASE

File:
`extension/su_ai_plugin/core/endpoint_record.rb`

Frozen amendment §6.2 permits cached fallback when there is genuinely no usable live-read authority, including:

- no adapter;
- no endpoint handle;
- adapter genuinely lacks `vertex_position` capability.

Current implementation raises `LiveVertexPositionUnreadable` when a per-endpoint handle exists but adapter lacks `vertex_position`.

Required correction:

- endpoint handle exists + adapter exposes `vertex_position` + read nil/raises/malformed/non-finite => fail closed;
- adapter nil OR adapter lacks `vertex_position` => cached fallback allowed;
- endpoint handle absent => cached fallback allowed.

Also tighten live position shape to EXACTLY 3 Numeric finite values; an Array longer/shorter than 3 is malformed.

Required tests:

- endpoint handle + adapter lacking `vertex_position` => cached fallback;
- endpoint handle + 4-element position Array => fail closed;
- retain nil/raise/non-finite fail-closed coverage.

---

# 5. BLOCK R4 — PRESENTER STILL READS THE WRONG ACTUAL V1.8 RESULT SHAPE

File:
`extension/su_ai_plugin/cad_prep_workflow_presenter.rb`

AIPM rechecked the frozen production source:
`CanonicalStructureReconstructor` publishes:

```text
result['loops']
metrics['open_chain_count']
metrics['closed_loop_count']
metrics['region_count']
metrics['hole_count']
metrics['invalid_loop_count']
```

The current presenter still looks for:

- `sr['closed_loops']` for nested `unresolved_flags`;
- READY metrics `%w[closed_loops regions]`.

Those are not the actual V1.8 production keys.

Required correction:

1. `_structure_loop_flags` preferred production path must read:

```text
sr['loops'][].unresolved_flags
```

Legacy `closed_loops` may remain only as a fallback.

2. READY structure card metrics must use actual V1.8 keys:

```text
closed_loop_count
region_count
hole_count
```

3. `_structure_label_for` must label those preferred keys correctly.

4. Keep `open_chain_count` and `invalid_loop_count` as warning metrics.

Required regression:

- READY with `closed_loop_count=1, region_count=1` renders both truthful metrics;
- READY_WITH_WARNINGS with `loops[].unresolved_flags=['non_planar_loop']` + invalid_loop_count > 0 renders `存在非平面闭合轮廓，暂不能形成区域`;
- legacy aliases may be tested separately but must not be the production-primary path.

Do NOT modify V1.8.

---

# 6. BLOCK R5 — THE “TRUE E2E” TEST DOES NOT YET PROVE THE FROZEN OWNER FLOW

File:
`tests/test_v19a_final_p0_live_coordinates.rb`

The current E2E test manually invokes WorkingModeRunner compute/apply methods. It does not prove:

- orchestrator `start` behavior;
- Gap is detected but disabled while Planar is actionable;
- applying Planar automatically recomputes/unlocks Gap;
- BOTH physical B copies are actually at target Z in the same end-to-end fixture;
- applying Gap automatically recomputes Structure without a manual structure compute call.

Required replacement/extension:

Exercise the real V1.9A orchestrator path:

```text
CadPrepWorkflowOrchestrator.start
-> inspect snapshot + presenter: Planar ACTIONABLE, Gap detected, Gap button disabled
-> CadPrepWorkflowOrchestrator.apply_planar_and_refresh
-> assert BOTH identity-distinct physical B Vertex handles have target Z
-> inspect returned snapshot + presenter: Gap still actionable and button enabled
-> CadPrepWorkflowOrchestrator.apply_gap_and_refresh
-> use returned snapshot directly; do NOT manually call structure compute
```

Final assertions:

```text
workspace ready
open_chain_count = 0
closed_loop_count = 1
invalid_loop_count = 0
region_count = 1
no loops[].unresolved_flags includes non_planar_loop
```

The test must prove two physical B handles by identity in THIS SAME E2E fixture.

---

# 7. BLOCK R6 — COMPLETION EVIDENCE IS INCOMPLETE: FULL SUITE + RBZ

The amendment §11/§12 requires actual runnable evidence before Owner recheck.

Current report used a custom synthetic runner excluding RBZ-dependent tests and did not rebuild the RBZ. This is not sufficient for Owner Gate.

Required after R1–R5 pass:

1. Use the working vendored Ruby interpreter already found by Pi.
2. Rebuild `dist/SU-AI-Plugin.rbz` from the corrected source.
3. Run the normal/full Ruby suite, not only `.diag/run_no_rbz.rb`.
4. Run RBZ smoke against the rebuilt artifact.
5. Run Node DOM / focused P0 / V1.6 / V1.7 / V1.8 / presenter regressions.
6. Report exact executable, `ruby -v`, commands, counts, and any pre-existing failures separately.
7. Report rebuilt RBZ bytes / entries / SHA-256.
8. `git diff --check` must be clean for the correction packet.

Do not ask Owner to install the currently known-corrupted/stale RBZ.

---

# 8. ALLOWLIST FOR THIS NARROW RECHECK

Production files allowed:

- `extension/su_ai_plugin/core/endpoint_record.rb`
- `extension/su_ai_plugin/core/planar_normalization_executor.rb`
- `extension/su_ai_plugin/cad_prep_workflow_presenter.rb`

Tests allowed:

- `tests/test_v19a_final_p0_live_coordinates.rb`
- `tests/test_v19a_cad_prep_workflow_presenter.rb`
- existing focused test infrastructure only where strictly necessary for the orchestrator E2E / RBZ smoke.

Do NOT reopen `planar_normalization_proposer.rb` unless an R1 consistency test proves a proposer data field is mechanically missing. If that occurs, STOP and report the exact missing field before changing it.

Do NOT modify:

- `working_mode_runner.rb`
- V1.7 pairing/canonical clustering
- V1.8 reconstructor/region algorithms
- tolerances
- Source CAD ownership
- Undo/host-state architecture
- app.js/CSS/toolbar
- V1.9B
- MCP/LLM/Agent

---

# 9. CODEX / OWNER ORDER

After Pi completes R1–R6:

1. return to AIPM for direct source recheck;
2. if AIPM PASS, run ONE narrow Codex recheck against the previously identified P0 seam + these residuals;
3. if Codex PASS, rebuild/confirm the exact Owner RBZ if not already identical to reviewed source;
4. Owner reruns the same SU2020 Z + Gap fixture;
5. only then may AIPM close V1.9A.

V1.9B remains NOT STARTED.

END
