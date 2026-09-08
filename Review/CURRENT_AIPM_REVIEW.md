# CURRENT AIPM REVIEW — V1.9A P0 SHARED-VERTEX CORRECTION

Project: SU-AI-Plugin
Stage: V1.9A — Final Block Fix
Date: 2026-09-08
Reviewer: ChatGPT / AIPM
Final Product Owner: Owner
Reviewed implementation: `dev/v1.9` P0 shared-vertex correction (`d72c188e1b3e32d3109ee504aea4166025c86ca2` production merge; later docs-only commits do not change reviewed production files)
Prior authority:
- `Prompt/AIPM_V1_9A_P0_SHARED_VERTEX_IMPLEMENTATION_AMENDMENT_2026-09-08.md`
- `Prompt/CODEX_V1_9A_P0_CURRENT_GEOMETRY_SHARED_VERTEX_REVIEW_2026-09-08.md`

VERDICT: **FIX REQUIRED — NARROW RESIDUALS ONLY**
CODEX_RISK_TRIGGER: **YES, but defer recheck until these residuals are fixed**
OWNER_SU2020: **NOT YET**
V1.9B: **NOT STARTED**

## Owner Summary

The main shared-vertex direction is now substantially correct:

- V1.7 no longer uses the derived Group as endpoint coordinate authority;
- logical vertex dedupe now retains identity-distinct physical endpoint Vertex occurrences;
- one logical move fans out to multiple physical Vertices;
- executor uses one outer operation + one single-Vertex primitive per physical occurrence;
- logical vs physical count domains are separated.

However, direct source review found residual contract gaps that still block the Owner SU2020 re-test. These are narrow and do not require redesign.

Authoritative correction guidance:

`Prompt/AIPM_V1_9A_P0_NARROW_RECHECK_FIX_2026-09-08.md`

---

## BLOCK AIPM-P0-R1 — executor preflight does not validate live positions before mutation

Current executor reads `pre_positions`, but opens the operation without first proving every physical position is readable, exactly 3-number, finite, and consistent with the target.

This violates amendment §4.1.

Required: validate every physical occurrence BEFORE `begin_operation`, including target/vector numeric-finite shape and `abs((pre_z + vector_z) - target_z) <= coordinate_epsilon`.

---

## BLOCK AIPM-P0-R2 — postvalidation host-read exception can escape while operation is open

Current postvalidation maps `adapter.vertex_position(handle)` outside a rescue boundary.

If one post-read raises after mutation, the exception may escape before `end_operation(commit: false)`, violating the atomicity contract.

Required: nil/malformed/non-finite/raised post-read must all abort the single outer operation once, publish FAILED, and publish zero committed success.

---

## BLOCK AIPM-P0-R3 — endpoint fallback is stricter than the frozen guidance

Frozen amendment §6.2 allows cached fallback when there is no usable live-read capability, including an adapter that genuinely lacks `vertex_position`.

Current helper raises when a per-endpoint handle exists but the adapter lacks that method.

Required: no adapter / no endpoint handle / no live-read capability => cached fallback. Endpoint handle + live-read capability + unreadable result => fail closed.

Also require exactly 3 values; do not accept a 4-element position Array as valid.

---

## BLOCK AIPM-P0-R4 — presenter still reads non-production V1.8 keys

AIPM rechecked `CanonicalStructureReconstructor` directly. Production V1.8 publishes:

- `result['loops']`
- `metrics['open_chain_count']`
- `metrics['closed_loop_count']`
- `metrics['region_count']`
- `metrics['hole_count']`
- `metrics['invalid_loop_count']`

Current presenter still uses `sr['closed_loops']` for loop flags and READY metric keys `closed_loops` / `regions`.

Required:
- preferred loop flag path = `loops[].unresolved_flags`;
- READY metrics = `closed_loop_count`, `region_count`, optional `hole_count`;
- legacy aliases may remain fallback only.

Do not modify V1.8.

---

## BLOCK AIPM-P0-R5 — current E2E test is not the frozen orchestrated Owner-equivalent flow

The current test manually calls WorkingModeRunner compute/apply steps.

It does not prove in one fixture:

- orchestrator start;
- Gap disabled while Planar actionable;
- Planar apply auto-recomputes/unlocks Gap;
- BOTH identity-distinct physical B Vertices reach target Z;
- Gap apply auto-recomputes Structure without manual structure compute.

Required: exercise `CadPrepWorkflowOrchestrator.start`, `apply_planar_and_refresh`, `apply_gap_and_refresh` and assert presenter lock/unlock states plus final 0/1/0/1 structure metrics.

---

## BLOCK AIPM-P0-R6 — completion evidence incomplete: no fresh RBZ and no true full suite

Pi restored a working vendored Ruby, which is good. But the packet used a custom synthetic runner excluding RBZ-dependent tests and did not rebuild the RBZ.

The current `dist/SU-AI-Plugin.rbz` is explicitly reported stale/corrupted and must NOT be used for Owner testing.

Required after R1–R5:

- rebuild RBZ from reviewed source;
- run normal full Ruby suite;
- run RBZ smoke against rebuilt artifact;
- run P0 + V1.6/V1.7/V1.8 + presenter/DOM regressions;
- report exact Ruby path/version, counts, RBZ bytes/entries/SHA-256;
- clean diff.

---

## PASS / PRESERVE

Do not reopen these parts unless a new direct regression proves it:

- Group -> endpoint Vertex live-read authority direction;
- physical occurrence identity dedupe in proposer;
- one single-Vertex primitive per occurrence;
- logical/physical count split;
- V1.5 duplicate algorithm;
- V1.6 analysis math / tolerance authority;
- V1.7 pairing / canonical clustering;
- V1.8 reconstruction algorithm;
- current Issues / badge / healthy refresh behavior;
- toolbar / UI tab fixes;
- Source CAD immutability;
- Undo / host-state architecture;
- V1.9B.

---

## NEXT

Pi executes only the new narrow correction dispatch.

After Pi returns:

1. AIPM direct source recheck;
2. narrow Codex xHigh recheck on the shared-vertex / transaction boundary;
3. fresh RBZ confirmation;
4. Owner SU2020 same Z + Gap fixture;
5. only then V1.9A closure decision.

END
