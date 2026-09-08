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

However, direct source review found narrow residual contract gaps that still block the Owner SU2020 re-test. These do not require redesign.

Primary correction guidance:

`Prompt/AIPM_V1_9A_P0_NARROW_RECHECK_FIX_2026-09-08.md`

R7 addendum:

`Prompt/AIPM_V1_9A_P0_NARROW_RECHECK_ADDENDUM_R7_2026-09-08.md`

---

## BLOCK AIPM-P0-R1 — executor preflight does not validate live positions before mutation

Current executor reads `pre_positions`, but opens the operation without first proving every physical position is readable, exactly 3-number, finite, and consistent with the target.

Required: validate every physical occurrence BEFORE `begin_operation`, including target/vector numeric-finite shape and:

`abs((pre_z + vector_z) - target_z) <= coordinate_epsilon`.

Any failure must occur before opening the outer operation.

---

## BLOCK AIPM-P0-R2 — postvalidation host-read exception can escape while operation is open

Current postvalidation reads `adapter.vertex_position(handle)` outside an exception-safe abort boundary.

Required: nil/malformed/non-numeric/non-finite/raised post-read must all abort the single outer operation exactly once, publish FAILED, no commit, and zero committed success.

---

## BLOCK AIPM-P0-R3 — endpoint fallback is stricter than the frozen guidance

Frozen amendment §6.2 allows cached fallback when there is genuinely no usable live-read capability.

Required matrix:

- no adapter => cached fallback;
- no endpoint handle => cached fallback;
- adapter lacks `vertex_position` => cached fallback;
- endpoint handle + live-read capability + nil/raise/malformed/non-finite => fail closed `live_vertex_position_unreadable`.

Also require exactly 3 position values; a 4-element Array is malformed.

---

## BLOCK AIPM-P0-R4 — presenter still reads non-production V1.8 keys

Direct review of `CanonicalStructureReconstructor` confirms production publishes:

- `result['loops']`
- `metrics['open_chain_count']`
- `metrics['closed_loop_count']`
- `metrics['region_count']`
- `metrics['hole_count']`
- `metrics['invalid_loop_count']`

Current presenter still uses `sr['closed_loops']` as its preferred loop-flag path and READY metric keys `closed_loops` / `regions`.

Required:
- preferred loop flags = `loops[].unresolved_flags`;
- READY metrics = `closed_loop_count`, `region_count`, optional `hole_count`;
- legacy aliases may remain fallback only.

Do not modify V1.8.

---

## BLOCK AIPM-P0-R5 — current E2E test is not the frozen orchestrated Owner-equivalent flow

The current test manually invokes WorkingModeRunner compute/apply methods and therefore does not prove the actual A2 automatic chain.

Required in one fixture:

- `CadPrepWorkflowOrchestrator.start`;
- Planar ACTIONABLE + Gap detected + Gap presenter action disabled;
- `apply_planar_and_refresh` automatically recomputes/unlocks Gap;
- BOTH identity-distinct physical B Vertices reach target Z;
- `apply_gap_and_refresh` automatically recomputes Structure;
- returned final snapshot directly reports open=0, closed=1, invalid=0, region=1, with no `non_planar_loop`.

No manual downstream compute call may substitute for the orchestrator behavior.

---

## BLOCK AIPM-P0-R6 — completion evidence incomplete: no fresh RBZ and no true full suite

Pi restored a working vendored Ruby, but the packet used a custom RBZ-excluding runner and did not rebuild the RBZ. The current dist artifact is explicitly stale/corrupted and must NOT be used for Owner testing.

Required after R1–R5/R7:

- rebuild RBZ from reviewed source;
- run normal/full Ruby suite;
- run RBZ smoke against rebuilt artifact;
- run focused P0 + V1.6/V1.7/V1.8 + presenter/orchestrator/DOM regressions;
- report Ruby path/version, exact counts, RBZ bytes/entries/SHA-256;
- clean diff.

---

## BLOCK AIPM-P0-R7 — `deep_nesting` current-attention chip was accidentally suppressed

Baseline `PROBLEM_METRIC_LABELS` included `嵌套层级`. The current implementation removed it during the mojibake/CRLF recovery, while `_other_issue_label('deep_nesting')` still emits `嵌套层级`.

Because `_is_problem_metric?` only accepts whitelisted labels, a current `deep_nesting` issue can make the `other` card REVIEW_REQUIRED while disappearing from the current-attention chip/headline count.

Required: restore `嵌套层级` to `PROBLEM_METRIC_LABELS` and add a narrow presenter regression. Do not redesign issue taxonomy or app.js.

---

## PASS / PRESERVE

Do not reopen these parts unless a new direct regression proves it:

- Group -> endpoint Vertex live-read authority direction;
- physical occurrence identity dedupe in proposer;
- logical -> physical fan-out;
- one single-Vertex primitive per occurrence within one outer operation;
- logical/physical count split;
- V1.5 duplicate algorithm;
- V1.6 analysis math / tolerance authority;
- V1.7 pairing / canonical clustering;
- V1.8 reconstruction algorithm;
- current Issues / badge / healthy refresh behavior;
- toolbar / UI tab / hidden-semantics fixes;
- Source CAD immutability;
- Undo / host-state architecture;
- V1.9B.

---

## NEXT

Pi executes only the current ACTIVE narrow correction dispatch.

After Pi returns:

1. AIPM direct source recheck;
2. narrow Codex xHigh recheck on the shared-vertex / transaction boundary;
3. fresh rebuilt RBZ confirmation;
4. Owner SU2020 same Z + Gap fixture;
5. only then V1.9A closure decision.

END
