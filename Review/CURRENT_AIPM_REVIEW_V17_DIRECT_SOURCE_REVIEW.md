# CURRENT AIPM REVIEW

REVIEW_ID: V17-AIPM-DIRECT-SOURCE-REVIEW-2026-09-01
PROJECT: SU-AI-Plugin
STAGE: V1.7 — Endpoint / Gap Repair + Canonical Topology
REVIEWER: AIPM
FINAL PRODUCT OWNER: Owner
BRANCH: dev/v1.7
REVIEWED_REMOTE_HEAD: 2cdebb234f004c6980eb737c364274b4a568e8f7
SUBSTANTIVE_IMPLEMENTATION_HEAD: e98326ee17cabdeec0b617f22576d1bdc5ce699a
CLOSED_V1_6_BASE: d7e9c59
VERDICT: FIX REQUIRED — BOUNDED SOURCE-REVIEW CORRECTION
CODEX_GATE: NOT YET AUTHORIZED
OWNER_GATE: NOT YET AUTHORIZED
V1.8: NOT ACTIVE

FROZEN BLUEPRINT:
Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md

---

# 0. OWNER SUMMARY

The latest V1.7 packet materially improved the implementation and fixed four
real production-path defects. The major V1.7 architecture remains valid:

- Source CAD immutable;
- endpoint_bridge remains the only V1.7 executable repair type;
- conservative pairing / ambiguity rules remain valid;
- CanonicalGeometryGraph remains the downstream truth;
- existing V1.5 host-state reconciliation remains the recovery architecture.

However direct inspection of the pushed production source found several
runtime-contract violations that the current green test suite does not catch.

The largest issue is not "algorithm quality".

It is host / logical state ownership:

the current executor creates a line in a dedicated repair group, then calls
DerivedGeometryWorkspace#build_entity, which creates a SECOND top-level derived
group + edge for the same logical bridge. The workspace handle registry tracks
the second copy, while the first repair-group copy is outside the production
workspace cleanup path.

This must be corrected before Codex and before Owner SU2020 testing.

---

# 1. PASS / PRESERVE

The following direction is accepted and must NOT be redesigned by the corrective
packet:

1. `gap_search` is candidate discovery, not canonical identity.
2. `coordinate_epsilon` owns canonical equivalence.
3. Non-transitive coordinate clusters are not collapsed.
4. Safe clique members share one canonical node identity.
5. Mutual-unique pairing is required.
6. Cross-layer / curve / face / Z / crossing uncertainty is conservative.
7. Canonical generated repair enum is `gap_bridge`.
8. Source CAD remains immutable.
9. V1.7 does not implement LoopRecord / RegionRecord.
10. Existing validate-on-next-interaction Undo/reconciliation architecture
    remains the recovery seam.
11. Simplified Chinese product UX remains.
12. V1.8 remains blocked until V1.7 closes.

---

# 2. BLOCK SR-01 — DUPLICATE HOST BRIDGE + SPLIT OWNERSHIP

## Evidence

`GapBridgeExecutor.apply` currently:

1. calls `adapter.add_line_to_repair_group(...)`;
2. receives a host bridge edge;
3. then calls `workspace.build_entity(... kind: :edge, geometry_data: [p1,p2])`.

But `DerivedGeometryWorkspace#build_entity` creates a NEW top-level group and
calls `adapter.add_edge_to_group` inside that group.

Therefore one logical endpoint_bridge currently produces two host geometries:

A. one edge inside `SU-AI-Repair-GapBridge-*`;
B. one edge inside a separate `SU-AI-Derived-*` group created by build_entity.

The workspace private handle registry only learns the handle created by
`build_entity`, not the earlier repair-group edge.

The fake adapter has a special `dispose_repair_group_bridges` method, but the
production `SketchupDerivedWorkspaceAdapter` does not expose the same cleanup
method. WorkingModeRunner only calls that method conditionally via
`respond_to?`.

Result:
- duplicate physical bridge geometry;
- split ownership;
- normal Discard / Rebuild / close may delete the tracked copy but leave the
  production repair-group copy behind;
- host consistency validation is not tracking the actual repair-group bridge.

## Required correction

Use the frozen Blueprint's allowed fallback:

> If the existing workspace architecture already provides a safer equivalent
> owned repair-geometry container, reuse it instead of creating a second
> container.

For V1.7 base:

- use the EXISTING `DerivedGeometryWorkspace#build_entity` path as the SOLE host
  creation path for a generated endpoint_bridge;
- one proposal creates exactly ONE workspace-owned derived group containing
  exactly ONE bridge edge;
- do NOT also create a separate shared repair-group edge;
- the workspace handle registry therefore owns the generated bridge through the
  same lifecycle contract as all other derived entities.

The old V1.7 repair-group adapter methods may remain temporarily for compatibility
if removing them would create unnecessary churn, but they must not be used by
the production V1.7 base execution path.

Required regression:
ONE proposal -> ONE new host bridge edge total, not two.

---

# 3. BLOCK SR-02 — FAILED / ABORTED APPLY CAN RETURN FALSE-READY LOGICAL STATE

## Evidence

`GapBridgeExecutor._fail` returns the incoming workspace object unchanged.

It does not create a workspace whose `state == :failed`.

During apply, the local workspace variable is replaced after each successful
`build_entity`.

If a later mutation or post-validation fails:

- the SketchUp operation can be aborted;
- `_fail` can still return the logically-mutated workspace;
- WorkingModeRunner assigns that returned workspace;
- the workspace may remain `:ready` and may still contain generated bridge
  records even though the host operation was aborted.

This violates the fail-closed V1.4/V1.7 contract.

## Required correction

Capture:

`pre_workspace`

before begin_operation.

Maintain a separate:

`working_workspace`

during the operation.

For a confirmed successful abort:
- return a NEW `:failed` workspace derived from the exact PRE-BATCH logical
  inventory + handle registry;
- no generated bridge record may survive logically;
- source fingerprint unchanged;
- `last_error` carries a stable V1.7 reason.

For commit uncertainty / abort uncertainty:
- never claim rollback success;
- return `:failed`;
- preserve sufficient current handles so explicit Discard can clean any host
  entity that may still exist;
- do not publish APPLIED.

Required regressions:
- second bridge fails after first succeeds -> host abort + no generated logical
  bridge records + post_workspace.state == :failed;
- post-validation failure -> state == :failed;
- commit uncertainty -> state == :failed;
- no failure path returns READY.

---

# 4. BLOCK SR-03 — PRODUCTION POST-VALIDATION IS TOO WEAK

Current `_post_validate` only proves:

- workspace state;
- applied count;
- host handle exists / valid.

The frozen Blueprint requires a hard post-state proof before APPLIED truth is
published.

## Required minimum runtime validation

Before successful APPLIED publication, prove at runtime:

A. exact generated record count;
B. every generated record:
   - `origin_kind == generated_gap_bridge`;
   - `repair_action_id == proposal_id`;
   - expected start/end coordinates within coordinate_epsilon;
   - expected length within coordinate_epsilon;
C. actual host-derived bridge endpoint positions match expected values, using
   the existing adapter edge/vertex read seams;
D. source fingerprint unchanged;
E. all pre-existing source-derived record coordinates unchanged;
F. generated proposal IDs exactly equal expected READY proposal IDs;
G. no REVIEW_REQUIRED proposal was executed.

Then WorkingModeRunner must rebuild CanonicalGeometryGraph and, BEFORE exposing
successful V1.7 APPLIED truth, prove:

H. each generated record maps to one canonical edge with
   `origin_kind == gap_bridge`;
I. repair_action_id survives into the canonical edge;
J. repaired endpoint adjacency is present;
K. no new `non_transitive_node_cluster` is introduced by the repair.

If canonical post-validation fails after host commit:
- do not fake rollback;
- transition workspace to `:failed`;
- keep handles available for explicit Discard;
- stable reason `canonical_post_validation_failed` or equivalent.

---

# 5. BLOCK SR-04 — THIRD-NODE TEST USES INFINITE LINE, NOT BRIDGE SEGMENT

## Evidence

Production `_third_node_on_segment?` currently tests only:

`abs(orientation(p1,p2,w)) <= eps`

This proves collinearity with the infinite line through the bridge.

It does NOT prove `w` lies between p1 and p2.

A distant unrelated node that is collinear but far outside the proposed bridge
can therefore falsely produce:

`third_node_on_bridge`.

## Required correction

Replace with a true point-on-segment-interior predicate.

Recommended pure predicate:

- finite 3D points;
- compute projection parameter `t`;
- require `0 < t < 1` with endpoint epsilon exclusion;
- compute closest-point distance;
- require closest distance <= coordinate_epsilon;
- endpoints themselves are not third nodes.

Add production-path regressions:

- actual point inside bridge -> `third_node_on_bridge`;
- far collinear point beyond endpoint -> NOT third_node_on_bridge;
- near-collinear but outside epsilon -> NOT third_node_on_bridge.

Do not duplicate the production predicate in the test.

---

# 6. BLOCK SR-05 — GENERATED BRIDGE ID IS RANDOM

Current bridge ID uses `rand(2**32)`.

But V1.7 freezes deterministic identity / provenance and V1.8 will build stable
loop/region IDs from canonical edges.

## Required correction

Generated bridge derived ID must be deterministic from the already-deterministic
proposal ID.

Preferred:

`der-gap-#{proposal_id}`

or an equivalently deterministic collision-safe representation.

No Ruby random value.

Prove:
same source + same captured config + same safe proposal
-> same generated bridge derived_id / canonical_edge_id after rebuild/reapply.

---

# 7. BLOCK SR-06 — GAP BRIDGE PROVENANCE IS TRUNCATED

The generated workspace record correctly receives BOTH incident supporting
source occurrence IDs.

But CanonicalGeometryGraph currently emits only:

`source_occurrence_id = first(...)`

This loses provenance from the second side of the repaired gap.

## Required correction

CanonicalEdge must preserve deterministic plural provenance:

`source_occurrence_ids: [...]`

- normalize to strings;
- uniq;
- deterministic sort;
- for `gap_bridge`, include the complete supporting source occurrence union;
- preserve `repair_action_id`.

A singular compatibility field may remain only if an existing consumer requires
it, but V1.8 authority is the plural field.

Add regression:
two-source gap bridge -> canonical edge contains both source occurrence IDs.

---

# 8. BLOCK SR-07 — CANONICAL GRAPH `nodes` IS NOT YET ONE LOGICAL NODE PER ID

CanonicalTopologyBuilder now correctly gives all members of a resolved safe
clique the same `canonical_node_id`.

However its `canonical_nodes` collection is still one RECORD PER ENDPOINT.

CanonicalGeometryGraph currently forwards that collection directly as its
`nodes`, so a logical canonical node may appear multiple times with the same
canonical_node_id.

This is tolerable as an internal endpoint-membership representation, but NOT as
the durable CanonicalGeometryGraph node contract that V1.8 consumes.

The current `canonical_node_count` metric likewise counts records, not unique
logical node IDs.

## Required correction

Do NOT redesign CanonicalTopologyBuilder if its per-endpoint records are useful
for membership mapping.

At the CanonicalGeometryGraph boundary:

collapse records by `canonical_node_id` into ONE logical graph-node record.

A logical graph node should at minimum carry:

- `canonical_node_id`;
- deterministic representative `world_coordinate`;
- sorted `endpoint_keys`;
- sorted `derived_edge_ids`;
- sorted `source_occurrence_ids`;
- resolved/non-transitive evidence;
- layer evidence as available.

Representative coordinate:
use a deterministic ACTUAL member coordinate (for example the member with the
lexicographically-smallest endpoint_key). Do not invent an averaged coordinate
without AIPM approval.

Graph metrics:
`canonical_node_count` = number of unique logical graph nodes.

Prove:
two coincident endpoint records in one safe clique
-> exactly ONE graph node.

Non-transitive cluster members remain separate graph nodes.

This is required before V1.8 activation.

---

# 9. REQUIRED TESTS

Add / update explicit source-level tests for:

SR1-1 one proposal -> exactly one physical generated bridge;
SR1-2 Discard -> zero generated bridge host geometry;
SR1-3 close auto-discard -> zero generated bridge host geometry;
SR1-4 Rebuild -> no stale generated bridge geometry;

SR2-1 first of two bridges succeeds, second fails -> clean abort + FAILED +
      no logical bridge residue;
SR2-2 post-validation failure -> FAILED;
SR2-3 commit uncertainty -> FAILED + handles retained for recovery;
SR2-4 no failure path returns READY;

SR3-1 endpoint mismatch is caught;
SR3-2 provenance/action mismatch is caught;
SR3-3 source fingerprint mismatch is caught;
SR3-4 pre-existing derived-coordinate mismatch is caught;
SR3-5 canonical post-validation mismatch -> FAILED;

SR4-1 point truly inside segment -> third_node_on_bridge;
SR4-2 far collinear beyond endpoint -> safe from third-node reason;
SR4-3 near-line but outside epsilon -> safe from third-node reason;

SR5-1 deterministic generated bridge ID across equivalent rebuild/reapply;

SR6-1 generated gap canonical edge contains both source occurrence IDs;

SR7-1 resolved clique -> one CanonicalGeometryGraph node;
SR7-2 non-transitive members -> distinct graph nodes;
SR7-3 canonical_node_count counts unique logical nodes;
SR7-4 graph IDs / digest stable for unchanged same-workspace reconstruction.

Preserve and rerun:
- N1-N6;
- G1-G10;
- X1-X4;
- H1-H8;
- T1-T7;
- L1-L4;
- P1-P3;
- V1.6 close auto-discard;
- V1.5 BLOCK-005;
- LEGACY-COMPAT;
- Node DOM;
- RBZ smoke;
- git diff --check.

---

# 10. REVIEW STATUS

AIPM direct source review:
FIX REQUIRED.

This does NOT authorize Codex yet.

After the bounded correction:
Pi STOP
→ push final dev/v1.7 normally
→ AIPM direct source re-review
→ if PASS: mandatory Codex xHigh integration review
→ if Codex PASS: Owner SU2020 scenarios A-G
→ V1.7 closure.

END
