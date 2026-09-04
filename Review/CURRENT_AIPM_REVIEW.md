# AIPM V1.8 NARROW RECHECK — FINAL RESIDUALS

PROJECT: SU-AI-Plugin
STAGE: V1.8
DATE: 2026-09-03
REVIEWED_HEAD: ab3e0c8a573052598ebba6fa0b483341408a660f
PRIOR_PACKET: V18-AIPM-SOURCE-REVIEW-CORRECTION-2026-09-02
REVIEWER: AIPM

VERDICT: BLOCK — FOUR FINAL RESIDUALS ONLY
CODEX_RISK_TRIGGER: NO

## Owner Summary

The bounded correction packet substantially succeeded.

PASS:
- SR18-01 Ruby 2.2 `.sum` correction
- SR18-03 conservative non-adjacent segment conflict detection
- SR18-05 V1.8 cache invalidation
- SR18-06 truthful READY_WITH_WARNINGS state

PARTIAL / residual correction required:
- SR18-02 coordinate_epsilon exact authority
- SR18-04 O(V+E) traversal implementation
- SR18-07 true deep immutability
- SR18-08 complete adjacency contract validation

This is NOT another broad V1.8 review.
Fix exactly the four residuals below and stop.

---

## FR18-01 — SR18-02 RESIDUAL — exact coordinate_epsilon authority

Current `_resolve_coordinate_eps` has two contract violations:

1. A valid explicit `coordinate_epsilon: 1.0e-6` is NOT treated as authoritative because the code only immediately returns the keyword when `kw != 1.0e-6`.

2. When per-node epsilon values disagree, the code chooses a deterministic median.

Frozen correction authority required:
- ANY explicit finite positive keyword value wins verbatim, including exactly `1.0e-6`;
- when no explicit value exists, per-node epsilon may be used ONLY when all relevant node values are finite, positive, and consistent;
- inconsistent per-node epsilon is not an authority and must fail conservatively instead of selecting median/min/max/first;
- no silent product-tolerance invention.

Preferred behavior for inconsistent node epsilon:
return FAILED V1.8 result with a stable reason such as:
`invalid_graph:coordinate_epsilon_mismatch`

Do not change V1.7 Tolerance or CanonicalGeometryGraph schema.

Required regression:
A. explicit 1e-6 + conflicting node eps -> explicit 1e-6 wins.
B. no explicit eps + conflicting node eps -> FAILED stable mismatch reason.
C. no explicit eps + consistent node eps -> uses that exact value.

---

## FR18-02 — SR18-04 RESIDUAL — traversal still contains O(V) membership checks per step

The new edge index is directionally correct, but primary traversal still calls Array#include? repeatedly:

- degree computation checks `comp.include?(other)`;
- chain traversal checks `comp.include?(other)`;
- loop-neighbor traversal checks `comp.include?(n)` on every step.

Therefore a long simple chain/loop can still degrade toward O(V^2).

There is also a new process-global `comp_set` cache keyed by `arr.object_id`.
That cache:
- is unnecessary;
- grows across reconstructions;
- can be unsafe if object IDs are eventually reused after GC.

Required correction:
- create ONE local `Set.new(comp)` per component classification/traversal context;
- pass/reuse that Set through degree computation, edge collection, chain walk, loop walk;
- remove process-global object_id-based component-set cache;
- no Array#include? on `comp` inside repeated edge/traversal loops;
- keep deterministic ID/order behavior unchanged.

Also make primary rebuilt adjacency construction linear:
avoid repeated `array.include?` insertion scans where practical; use local Set/hash accumulation then publish sorted Arrays.

Required regression/source guard:
- no repeated production `comp.include?` in traversal methods;
- no `@_comp_set_cache` / object_id membership cache;
- large chain/loop smoke must remain comfortably bounded.

No geometry algorithm redesign.

---

## FR18-03 — SR18-07 RESIDUAL — Strings are still mutable

Current `deep_freeze` recursively freezes Hashes and Arrays but its scalar branch does nothing.

Ruby String is mutable.

Therefore public fields such as:
- loop_id
- chain_id
- region_id
- canonical_graph_digest
- source_snapshot_id
- workspace_id
- reason strings
- source_occurrence_id strings
can still be modified in-place after the result digest has been computed.

This violates the Blueprint's deeply immutable published-result contract.

Required correction:
- recursively freeze Hash keys AND values;
- recursively freeze Array members;
- freeze String scalar values;
- JSON primitive numerics/true/false/nil are already effectively immutable but may safely receive `.freeze`;
- do not mutate/rewrite the digest after publication.

Required regression:
attempt all of:
- `result['digest'] << 'x'`
- `result['loops'].first['loop_id'] << 'x'`
- `result['loops'].first['source_occurrence_ids'].first << 'x'`
Each must raise / be impossible and digest/payload remain unchanged.

---

## FR18-04 — SR18-08 RESIDUAL — omitted adjacency keys can pass validation

Current adjacency validation:
- detects unknown provided keys;
- compares given vs expected neighbors only while iterating keys actually present in `adj_h`.

If an edge-backed canonical node's adjacency key is omitted entirely, the method does not necessarily compare that missing key against expected neighbors.

Required correction:
- normalize expected adjacency for ALL canonical node IDs;
- normalize supplied adjacency for ALL canonical node IDs;
- every canonical node must be represented logically (missing key = empty list);
- compare expected vs supplied for every known node;
- an omitted edge-backed node key must report `missing_neighbor` / adjacency mismatch;
- unknown keys/neighbors and extra neighbors remain failures;
- adjacency values must be Arrays (do not silently coerce an arbitrary scalar into a valid adjacency list).

Required regressions:
A. remove an entire edge-backed adjacency key -> FAILED.
B. scalar/non-Array adjacency value -> FAILED.
C. isolated known node with an explicit or normalized empty adjacency remains valid if the graph otherwise supports isolated-node policy.

Do not modify V1.7 CanonicalGeometryGraph.

---

## Already PASS — DO NOT REWORK

SR18-01:
PASS. `.sum` production incompatibility removed.

SR18-03:
PASS. Existing V1.7 SegmentConflict is reused without semantic changes.

SR18-05:
PASS. Cache invalidation seam is present on the required mutation/failure paths.

SR18-06:
PASS. Warning-bearing result publishes READY_WITH_WARNINGS.

Do NOT reopen these areas except mechanical test compatibility.

---

## Final Regression

Run fresh:
- final residual focused tests;
- all V1.8 tests;
- V1.7 suite;
- V1.6 close-autodiscard;
- V1.5 BLOCK-005;
- LEGACY-COMPAT;
- full Ruby;
- Node DOM;
- RBZ smoke;
- git diff --check.

Rebuild RBZ.

Report exact counts + final RBZ identity.

---

## Gate

AIPM_REVIEW: BLOCK — FINAL FOUR RESIDUALS
CODEX: NOT REQUIRED
OWNER_SU2020: NOT YET
V1.9: NOT STARTED

After Pi:
AIPM checks ONLY FR18-01..04.
If PASS, proceed directly to Owner SU2020 A-D.

END
