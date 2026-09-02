# CURRENT PI DISPATCH

DISPATCH_ID: V17-CODEX-BLOCK-FINAL-RESIDUAL-FIX-2026-09-02
STATUS: ACTIVE
PROJECT: SU-AI-Plugin
STAGE: V1.7 — Endpoint / Gap Repair + Canonical Topology
TARGET_BRANCH: dev/v1.7

Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

AIPM NARROW REVIEW:
Review/CURRENT_AIPM_REVIEW.md

CURRENT REMOTE HEAD:
40277b0ca8be04ce7f0eff36dcbf4e8b6c490251

SUBSTANTIVE INT FIX HEAD:
9a8158535d846b5e8e06f96f091adfc6d6095c0f

# 0. MISSION

Correct exactly TWO residuals inside the already-accepted Codex findings:

- INT-001 final output-order / digest determinism;
- INT-002 shared-endpoint collinear-overlap safety.

INT-003, INT-004 and INT-005 code fixes are AIPM narrow PASS.
Do not modify them except unavoidable mechanical test compatibility.

This is the FINAL Pi correction before Codex narrow recheck.

Do NOT:
- invoke Codex;
- run Owner gate;
- start V1.8;
- redesign canonical identity;
- add repair types;
- add Observer architecture;
- mutate Source CAD.

# 1. INT-001 — COMPLETE ORDER-INDEPENDENCE

Fix CanonicalTopologyBuilder:

A. Sort connected components using a stable key derived from ALL sorted
endpoint_keys in each component, not `comp.first`.

B. Publish stable builder ordering:
- canonical_nodes sorted by canonical_node_id then endpoint_key;
- non_transitive_clusters sorted by cluster_id;
- canonical_node_clusters in stable sorted-key insertion order if Hash order is
  serialized/exposed.

C. CanonicalGeometryGraph `_compute_digest` must sort non-transitive cluster
serialization lines before hashing.

Do not change:
- safe-clique collapse;
- non-transitive members remain separate;
- coordinate_epsilon semantics.

Regression MUST use interleaved membership keys so the old `comp.first` approach
would be capable of changing component order.

Forward/reverse/shuffle must produce exact-equal arrays/maps + graph digest, not
only equal sorted sets.

# 2. INT-002 — SHARED ENDPOINT DOES NOT OVERRIDE INTERIOR OVERLAP

Fix the shared SegmentConflict predicate.

Required decision order:

- validate;
- bbox reject;
- COLLINEAR classification / overlap first;
- if genuine collinear interior overlap -> conflict even if endpoint(s) shared;
- if collinear endpoint-only touch -> safe;
- if collinear disjoint -> safe;
- only then allow non-collinear shared-endpoint-only meeting as safe;
- proper crossing / T-junction logic remains.

Correct the existing wrong test:
`V17-INT-002-F` currently treats `[5,0]->[8,0]` vs `[5,0]->[10,0]` as SAFE.
That is interior overlap and MUST become CONFLICT.

Add separate SAFE tests for:
- non-collinear shared endpoint;
- collinear endpoint-only touch.

Add CONFLICT tests for:
- shared endpoint + same-ray interior overlap;
- identical segment;
- shared endpoint + partial overlap.

Drive at least one shared-overlap case through the actual runner crossing
checker / product proposal path.

Preserve:
- disjoint collinear SAFE;
- normal almost-closed triangle READY;
- one shared pure predicate used by runner + proposer.

# 3. REGRESSION

Run fresh:
- corrected INT-001 exact-order/digest tests;
- corrected INT-002 shared-overlap tests;
- all INT-001..INT-005 tests;
- all V1.7;
- full Ruby;
- H1-H7;
- V1.5 BLOCK-005;
- V1.6 close auto-discard;
- LEGACY-COMPAT;
- Node DOM;
- RBZ smoke;
- git diff --check.

Rebuild RBZ after production changes.

Report fresh exact counts.

# 4. REPORT

Overwrite:
`Review/CURRENT_PI_REPORT.md`

Dispatch:
`V17-CODEX-BLOCK-FINAL-RESIDUAL-FIX-2026-09-02`

Include:
- INT-001 residual disposition;
- exact interleaved-key ordering evidence;
- exact graph digest evidence;
- INT-002 residual disposition;
- corrected old V17-INT-002-F expectation;
- shared overlap / endpoint-only touch evidence;
- production runner/proposer evidence;
- full regression counts;
- RBZ identity;
- final implementation commit;
- remote dev/v1.7 HEAD;
- `SU2017_RUNTIME_EVIDENCE_PENDING` unchanged unless genuine evidence exists.

Gate:
`AIPM_REVIEW: PENDING FINAL TWO-DELTA CHECK`
`CODEX_NARROW_RECHECK: REQUIRED — DO NOT SELF-INVOKE`
`OWNER_GATE: NOT YET RUN`
`V1.8: NOT STARTED`

# 5. PUSH / STOP

After green:
one normal fast-forward push:
`git push origin dev/v1.7`

No force.
No rebase.
No main merge/push.
No tag/release.

STOP.

Next:
AIPM checks INT-001 + INT-002 only.
Then Codex narrow recheck.

END
