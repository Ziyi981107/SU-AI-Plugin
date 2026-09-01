# CURRENT PI DISPATCH

DISPATCH_ID: V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01
STATUS: ACTIVE
PROJECT: SU-AI-Plugin
STAGE: V1.7 — Endpoint / Gap Repair + Canonical Topology
TARGET_BRANCH: dev/v1.7

Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

FROZEN BLUEPRINT:
Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md

PRIOR REPORT:
Review/CURRENT_PI_REPORT.md
Dispatch:
V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01

---

# 0. PURPOSE

AIPM reviewed the correction report before consuming the source patch.

The packet is materially improved, but three Blueprint requirements are still
not proven by the evidence described in the report.

This is a FINAL bounded evidence/integration correction.

Do NOT redesign V1.7.
Do NOT invoke Codex.
Do NOT run Owner verification.
Do NOT start V1.8.

---

# 1. FINDING V17-R5 — X1/X2 TESTS MUST EXECUTE PRODUCTION CROSSING LOGIC

The current report says V17-X1 / V17-X2 construct a
`crossing_checker` proc "mirroring" `WorkingModeRunner._crossing_checker_proc`.

A mirrored test implementation is not acceptable evidence for the production
gate: the test and production code may diverge while both appear green.

Required:

1. X1 and X2 must execute the ACTUAL production crossing/third-node logic.
2. Preferred evidence:
   - invoke the normal `WorkingModeRunner.compute_gap_repair` path with the
     real `_crossing_checker_proc`, OR
   - call the actual production method/proc through the smallest existing
     supported seam.
3. Do not duplicate/reimplement the crossing algorithm inside the test.
4. Prove:
   - X1 -> REVIEW_REQUIRED / `bridge_crossing`;
   - X2 -> REVIEW_REQUIRED / `third_node_on_bridge`;
   - no executable unsafe proposal;
   - no destructive host operation.

The old mirror-proc tests may remain as low-level predicate tests, but they
cannot be the only production evidence.

---

# 2. FINDING V17-R6 — X4 MUST BE A REAL ALMOST-CLOSED TRIANGLE

The current report explicitly says V17-X4 uses a simple 2-line topology rather
than the Blueprint-required almost-closed triangle.

That does NOT satisfy X4.

Required:

Construct an actual almost-closed triangular boundary, e.g.:

A -------- B
 \        /
  \      /
   C --- D

with:
- three existing canonical/source-derived edges forming an almost triangle;
- C and D are the two open endpoints;
- distance(C,D) within gap_search and > coordinate_epsilon;
- C and D are mutual-unique safe candidates;
- no crossing / third-node / layer / Z / curve / face disqualifier.

Prove:
- exactly one READY_TO_REPAIR endpoint_bridge;
- the bridge is C-D;
- the input is actually a 3-edge almost-closed triangle.

Important:

The report says the 2-line substitute was chosen to avoid a
"clique-merge interaction with co-incident endpoint keys".

If a correct 3-edge almost-triangle cannot pass because canonical identity or
open-endpoint filtering incorrectly collapses/loses the topology, this is a
REAL implementation bug, not a reason to weaken the test.

In that case:
- fix the implementation within the frozen V1.7 contract;
- do not change the Blueprint;
- report the root cause.

---

# 3. FINDING V17-R7 — H3 MULTI-BRIDGE BATCH MUST BE TESTED DIRECTLY

Blueprint H3 requires:

multiple independent safe bridges
→ ONE native SketchUp operation
→ exact generated bridge count.

The current report maps H3 to:
- H2 single bridge, plus
- H5 endpoint-disjoint/preflight behavior.

That is not direct H3 evidence.

Required explicit H3 test:

Input:
- two independent safe endpoint_bridge proposals;
- four distinct endpoints;
- no crossing/conflict;
- both executable.

Apply one batch.

Prove:
- exactly ONE begin_operation;
- exactly ONE commit_operation;
- zero abort;
- exactly TWO generated bridge entities;
- both expected proposal IDs/provenance recorded;
- source fingerprint unchanged;
- existing source-derived coordinates unchanged;
- post canonical graph contains both gap_bridge canonical edges.

Name/map this test explicitly to Blueprint H3.

---

# 4. FINDING V17-R8 — T4 MUST PROVE A CYCLE, NOT ONLY CONNECTIVITY

The current T4 report says BFS proves all three nodes are mutually reachable.

Connectivity alone does NOT prove cycle-capability; a tree is connected.

Required T4 evidence using the actual almost-closed triangle from X4 or an
equivalent canonical fixture:

Before bridge:
- connected/open triangle-chain component;
- exactly two open endpoint nodes;
- no cycle.

After bridge:
- bridge exists as canonical `gap_bridge`;
- component is connected;
- component has an actual cycle.

For the simple triangle fixture prove one of the following equivalent exact
invariants:

- 3 canonical nodes + 3 canonical edges + every node degree == 2; OR
- deterministic cycle traversal returns to start after consuming the expected
  3 canonical edges exactly once.

Also prove:
- no LoopRecord / RegionRecord is created in V1.7.

Do NOT count BFS connectivity alone as T4 PASS.

---

# 5. REGENERATE SOURCE-REVIEW BUNDLE

After R5-R8 are complete, regenerate:

`Review/V17_AIPM_SOURCE_REVIEW.patch`

from exact closed V1.6 base:

`d7e9c59`

to the final substantive corrected V1.7 implementation/test HEAD.

Update:

`Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md`

with:
- actual production X1/X2 test seam;
- real triangle X4;
- direct H3;
- exact T4 cycle invariant;
- corrected line anchors.

Record patch SHA-256.

---

# 6. REGRESSION

Run at minimum:

- X1 actual production-path test
- X2 actual production-path test
- X3 / X3-PAIRWISE
- X4 real almost-closed triangle
- direct H3 two-independent-bridges batch
- T3
- T4 exact cycle proof
- OK-MAP-1 / OK-MAP-2
- full V1.7
- full Ruby
- Node DOM
- V1.6 close auto-discard
- V1.5 BLOCK-005
- LEGACY-COMPAT
- RBZ smoke
- git diff --check

Rebuild RBZ if production code changes.

---

# 7. REPORT

Overwrite:

Review/CURRENT_PI_REPORT.md

DISPATCH_ID:
V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01

Report:

A. R5-R8 disposition
B. production code changed, if any
C. X1/X2 actual-production-path evidence
D. X4 real-triangle evidence
E. H3 real multi-bridge batch evidence
F. T4 exact cycle evidence
G. corrected complete matrix
H. source-review patch path / size / SHA-256
I. critical source index
J. regression counts
K. RBZ identity
L. exact substantive implementation HEAD + final doc-stamp HEAD
M. remaining defect / assumption / unknown
N. `CODEX_GATE: STILL PENDING — DO NOT INVOKE`
O. `OWNER GATE: NOT YET RUN`

Do NOT claim AIPM PASS.

---

# 8. GIT / STOP

Create one bounded checkpoint if needed.

Do NOT:
- force-push;
- rebase;
- merge main;
- tag/release;
- start V1.8;
- invoke Codex.

After R5-R8 + review bundle + green regressions:

STOP.

Return control to AIPM.

Next Gate:
AIPM direct source review of the regenerated patch.

END
