# CURRENT AIPM REVIEW

REVIEW_ID: V17-CODEX-BLOCK-NARROW-DELTA-REVIEW-2026-09-02
PROJECT: SU-AI-Plugin
STAGE: V1.7 — Endpoint / Gap Repair + Canonical Topology
REVIEWER: AIPM
FINAL PRODUCT OWNER: Owner

REVIEWED REMOTE HEAD:
40277b0ca8be04ce7f0eff36dcbf4e8b6c490251

SUBSTANTIVE INT-001..005 FIX COMMIT:
9a8158535d846b5e8e06f96f091adfc6d6095c0f

VERDICT:
FIX REQUIRED — TWO NARROW RESIDUALS INSIDE INT-001 / INT-002

INT-003: AIPM NARROW PASS
INT-004: AIPM NARROW PASS
INT-005: AIPM CODE PASS / SU2017_RUNTIME_EVIDENCE_PENDING
CODEX_RECHECK: HOLD UNTIL INT-001 / INT-002 RESIDUALS CLOSE
OWNER_GATE: HOLD
V1.8: NOT ACTIVE

# 0. OWNER SUMMARY

Pi's one-packet correction materially closes most of the five Codex xHigh BLOCK findings.

AIPM narrow source review accepts:
- INT-003 plural provenance;
- INT-004 validate-on-next-V1.7-interaction;
- INT-005 removal of Hash#compact from the V1.7 production path, with the
  explicitly truthful SU2017 runtime evidence still pending.

Two residuals remain INSIDE the original Codex findings:

1. INT-001: logical IDs are now stable, but component/raw-output ordering and
   non-transitive cluster digest serialization are not fully order-independent.
2. INT-002: SegmentConflict returns SAFE immediately for ANY shared endpoint,
   even when the two collinear segments share an endpoint AND overlap through
   their interiors.

No other V1.7 scope is reopened.

# 1. INT-001 — PARTIAL PASS / RESIDUAL ORDER-DETERMINISM BLOCK

## What is fixed

Accepted:
- discovery ordinal `comp_idx` was removed from non-transitive cluster_id;
- cluster_id now derives from sorted membership digest;
- per-member `.n#{position}` derives from sorted member order.

## Residual source issue

`CanonicalTopologyBuilder.build` says it sorts components by the smallest
endpoint_key, but currently does:

`epss[comp.first].endpoint_key`

`comp.first` is the first member encountered by DFS/input discovery, NOT
necessarily the lexicographically-smallest endpoint_key of the component.

Therefore two interleaved components can swap output order when the input
enumeration changes.

Additionally `CanonicalGeometryGraph#_compute_digest` serializes
`non_transitive_clusters` into `cl_lines` without sorting the cluster lines.
Even with stable cluster IDs, changed raw cluster ordering can change the graph
digest.

The current INT-001 tests do not fully prove this:
- INT-001-A compares sorted cluster ID sets;
- INT-001-B compares sorted member ID sets;
- INT-001-C does not actually rebuild non-transitive components from shuffled
  endpoint enumeration; it mainly reverses an open_endpoints list.

This leaves the original Codex requirement
"identity AND output ordering / graph digest independent of input enumeration"
only partially closed.

## Required correction

A. CanonicalTopologyBuilder component iteration:
- derive a stable component membership key from ALL sorted endpoint_keys;
- sort components by that stable membership key;
- do not use DFS/input first member as the sort authority.

Example conceptual key:
`comp.map { |i| epss[i].endpoint_key.to_s }.sort.join('|')`

B. Before publishing builder output:
- canonical_nodes: stable sort by canonical_node_id + endpoint_key;
- non_transitive_clusters: stable sort by cluster_id;
- if canonical_node_clusters iteration order is externally serialized, publish
  it in stable sorted-key insertion order.

C. CanonicalGeometryGraph digest:
- defensively sort non-transitive cluster serialization lines by stable
  cluster_id/signature before hashing.

Do not change canonical membership semantics.

## Required regression

Use at least TWO non-transitive components whose endpoint-key ranges INTERLEAVE,
so arbitrary first-member order can actually flip component order.

Example membership domains:
- component A: `a`, `z`, `zz`
- component B: `m`, `n`, `o`

Forward / reversed / deliberately shuffled input must produce EXACTLY identical:
- non_transitive_clusters array order/content;
- canonical_nodes array order/content;
- canonical_node_clusters key order/content if serialized;
- membership -> cluster_id mapping;
- membership -> canonical_node_id mapping;
- CanonicalGeometryGraph digest.

Do not compare only sorted sets.

# 2. INT-002 — PARTIAL PASS / SHARED-ENDPOINT OVERLAP BLOCK

## What is fixed

Accepted:
- one shared pure SegmentConflict module now exists;
- runner and proposer use the shared predicate;
- full containment, partial non-shared overlap, T-junction and ordinary crossing
  are represented;
- disjoint collinear geometry is allowed.

## Residual source issue

`SegmentConflict.conflict?` currently returns SAFE immediately when ANY endpoint
is shared:

`return { conflict: false, reason: 'shared_endpoint' }`

This happens BEFORE the collinear-overlap check.

That means these invalid cases are incorrectly SAFE:

1. same start endpoint + both segments run along the same ray and overlap;
2. identical segments (both endpoints shared);
3. one segment is a longer continuation of the other from a shared endpoint.

The dispatch did NOT say "all shared endpoints are safe".
It said shared endpoints that merely meet at the legitimate target vertex are
not AUTOMATICALLY conflicts.

Interior overlap remains a conflict even when the overlap includes a shared
endpoint.

The current regression `V17-INT-002-F` is itself incorrect:
- bridge `[5,0] -> [8,0]`
- unrelated `[5,0] -> [10,0]`
- these share an endpoint AND overlap on `[5,8]`
- the test currently expects SAFE.

That expectation must be corrected.

## Required correction

Reorder / refine SegmentConflict:

1. validate inputs;
2. bbox quick reject;
3. if collinear:
   - evaluate finite INTERIOR overlap FIRST;
   - genuine interior overlap -> `collinear_overlap` conflict, even when an
     endpoint is shared;
   - pure endpoint-only touch -> SAFE shared endpoint;
   - disjoint -> SAFE;
4. for non-collinear geometry:
   - shared endpoint-only meeting -> SAFE;
5. then proper crossing / T-junction checks.

Required semantics:

SAFE:
- non-collinear segments meeting only at one shared endpoint;
- collinear segments touching only at one endpoint with zero interior overlap;
- disjoint collinear segments.

CONFLICT:
- identical segments;
- same-endpoint same-ray containment;
- same-endpoint partial interior overlap;
- all previously-detected proper crossing / T-junction cases.

## Required regression

Pure shared predicate:
- shared endpoint + non-collinear divergence -> SAFE;
- shared endpoint + collinear endpoint-only touch -> SAFE;
- shared endpoint + collinear interior overlap -> CONFLICT;
- identical segments -> CONFLICT;
- existing disjoint-collinear SAFE remains.

Production path:
- existing unrelated edge sharing one bridge endpoint but overlapping bridge
  interior -> no READY proposal;
- ordinary legitimate triangle corner/shared endpoint does not false-block;
- simultaneous proposed bridges with shared endpoint but interior collinear
  overlap are conflict if such a fixture is possible; otherwise directly test
  the actual shared production predicate and report why mutual-unique proposal
  generation makes that exact high-level fixture unreachable.

Do not restore duplicated crossing algorithms.

# 3. INT-003 — AIPM NARROW PASS

Verified source direction:
- EndpointRecord + DerivedEdgeRecord carry plural source_occurrence_ids;
- snapshot builder reads the full plural list;
- proposer endpoint lookup carries plural provenance;
- incident_source_occurrence_ids is the sorted/uniq union across both sides;
- generated record/canonical edge retain plural support.

The retained singular accessor is compatibility-only and derived from plural.

No further INT-003 correction requested.

# 4. INT-004 — AIPM NARROW PASS

Verified:
- compute_gap_repair calls validate_host_state_consistency! before topology /
  proposal read;
- apply_gap_repair validates before proposal recomputation and before the
  ready.empty? return;
- defense-in-depth validation remains before executor apply;
- mismatch clears stale main V1.7 proposal/canonical state on the normal
  validate-on-next-interaction path;
- no Observer architecture added.

No further INT-004 correction requested.

# 5. INT-005 — AIPM CODE PASS / RUNTIME EVIDENCE PENDING

Verified production change:
- V1.7 snapshot path no longer uses Hash#compact;
- uses Ruby-2.2-compatible `delete_if { |_k, v| v.nil? }`.

Accepted automated evidence:
- Hash#compact removal test;
- successful V1.7 snapshot path with compact undefined.

Known unknown remains truthful:
`SU2017_RUNTIME_EVIDENCE_PENDING`.

Do NOT fabricate SU2017 runtime PASS.

The mandatory Codex narrow recheck will adjudicate whether:
- code/static/API-removal evidence is sufficient for this stage; OR
- a separate SU2017-compatible probe is required before V1.x release/closure.

# 6. NEXT GATE

Pi corrects ONLY INT-001 and INT-002 residuals.

Then:
AIPM checks ONLY those two deltas.

If PASS:
→ Codex xHigh NARROW RECHECK of INT-001..INT-005
→ if Codex PASS: Owner SU2020 A-G
→ V1.7 closure.

No new speculative AIPM review scope after this packet.

END
