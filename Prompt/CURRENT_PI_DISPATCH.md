# CURRENT PI DISPATCH

DISPATCH_ID: V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01
STATUS: ACTIVE
PROJECT: SU-AI-Plugin
STAGE: V1.7 — Endpoint / Gap Repair + Canonical Topology
TARGET_BRANCH: dev/v1.7

Dispatcher / Product + Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

FROZEN BLUEPRINT:
Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md

PRIOR IMPLEMENTATION REPORT:
Review/CURRENT_PI_REPORT.md
Dispatch:
V17-GAP-TOPOLOGY-IMPLEMENTATION-2026-09-01

---

# 0. PURPOSE

AIPM report-level primary review found concrete evidence gaps / contract
ambiguities in the V1.7 implementation packet.

This is NOT a redesign.

Do NOT start V1.8.
Do NOT invoke Codex yet.
Do NOT run Owner real-host verification yet.

Correct the bounded findings below, regenerate trustworthy evidence, and produce
an AIPM-readable source-review patch bundle so AIPM can complete the required
primary source review before the mandatory Codex xHigh gate.

---

# 1. FINDING V17-R1 — CROSSING / BRANCH SAFETY IS NOT ACTUALLY PROVEN

The frozen Blueprint requires explicit:

X1 — proposed bridge intersects unrelated edge interior
     → REVIEW_REQUIRED.

X2 — third canonical node lies on bridge
     → REVIEW_REQUIRED.

X3 — two proposed bridges cross
     → conflicting proposals not executable.

X4 — almost-closed triangle
     → READY_TO_REPAIR.

The prior Pi report claims:

`§10.3 crossing / branch / pair conflict`
→ `WorkingModeRunner._crossing_checker_proc`
→ `(covered by G1)`

This is insufficient.

G1 is only a simple valid pair and cannot prove crossing / third-node /
simultaneous-bridge conflict safety.

## Required correction

1. Inspect the ACTUAL `_crossing_checker_proc` implementation.
2. Verify that it checks ALL frozen conditions:
   - unrelated canonical-edge interior intersection;
   - unrelated canonical node on proposed bridge interior;
   - implicit T-junction / split requirement;
   - crossing between simultaneously proposed bridges.
3. Add explicit regression tests named/mapped to X1, X2, X3, X4.
4. Each unsafe case must prove:
   - no executable READY proposal for the unsafe bridge;
   - stable review reason where applicable:
     `bridge_crossing`,
     `third_node_on_bridge`,
     `bridge_conflict`;
   - zero destructive bridge creation.
5. X4 must use an almost-closed triangle-style topology and prove ONE safe
   endpoint_bridge proposal exists.

Do NOT treat "nearest" or "mutual unique" as a substitute for crossing safety.

---

# 2. FINDING V17-R2 — CANONICAL POST-REPAIR ADJACENCY IS UNDER-PROVEN

The frozen Blueprint requires:

T3 — repaired endpoints gain exactly the expected adjacency.

T4 — an almost-closed triangle becomes canonical connected / cycle-capable
     topology input for V1.8 after the bridge.

The prior report lists canonical graph tests:

T1, T2, T5-T7

and does not provide explicit T3 / T4 evidence.

## Required correction

Add explicit tests:

### T3

Before repair:
- endpoint node A degree = 1;
- endpoint node B degree = 1.

After applying one endpoint_bridge + rebuilding CanonicalGeometryGraph:
- canonical gap bridge exists;
- node A degree increases exactly as expected;
- node B degree increases exactly as expected;
- no unrelated node degree changes.

### T4

Construct an almost-closed triangle / equivalent 3-edge chain with one short
unique missing closing segment.

Before:
- topology has two open endpoint nodes.

After endpoint_bridge:
- canonical graph contains the generated canonical edge;
- the two formerly open nodes are connected through the expected adjacency;
- topology is cycle-capable for V1.8;
- V1.7 MUST NOT create a V1.8 Loop/Region object.

This is topology evidence only, not a face-generation requirement.

---

# 3. FINDING V17-R3 — CANONICAL `origin_kind` CONTRACT MUST BE MADE EXACT

The Blueprint deliberately distinguishes:

Derived/workspace record origin kind:
`generated_gap_bridge`

from CanonicalEdge origin kind:
`gap_bridge`

Blueprint §15.1 explicitly requires:

CanonicalEdge:
`origin_kind = gap_bridge`

The prior report maps §15.1 to:

`GapBridgeExecutor.apply sets origin_kind='generated_gap_bridge'`

This is ambiguous and may leak the workspace implementation enum into the
canonical downstream contract.

## Required correction

Verify the actual canonical graph output.

Required final contract:

- raw/generated DerivedEntityRecord MAY remain:
  `origin_kind = generated_gap_bridge`

- CanonicalGeometryGraph CanonicalEdge MUST expose:
  `origin_kind = gap_bridge`

Add an explicit test proving this mapping.

Do NOT change the frozen source/derived provenance meaning.

V1.8 must be able to consume canonical `gap_bridge` without learning the
workspace implementation enum.

---

# 4. FINDING V17-R4 — TEST MATRIX / REPORT CLAIMS MUST BE TRUTHFUL

The dispatch required at minimum:

- N1-N6
- G1-G10
- X1-X4
- H1-H8
- T1-T7
- L1-L4
- P1-P3

The prior report labels:
- H1-H7;
- T1, T2, T5-T7;
- no X1-X4.

Do not claim "all Blueprint §§ covered" until the explicit missing evidence is
present.

After correction, report the matrix honestly.

If some H-number was only a numbering mismatch but the underlying requirement
is already tested, map it explicitly by Blueprint requirement rather than
renaming evidence deceptively.

In particular prove both:

- source fingerprint unchanged;
- existing source-derived endpoint coordinates unchanged.

---

# 5. AIPM SOURCE-REVIEW BUNDLE — REQUIRED

AIPM cannot currently inspect local `dev/v1.7` through the remote repository
because the branch is not available remotely from the current environment.

Generate a durable review artifact from the actual local branch.

Create:

`Review/V17_AIPM_SOURCE_REVIEW.patch`

using the exact closed V1.6 base:

`d7e9c59`

to the final corrected V1.7 HEAD.

The patch must include all V1.7 production/test changes.

Equivalent command conceptually:

git diff d7e9c59..HEAD --   extension/su_ai_plugin   tests   scripts/build_rbz.rb   > Review/V17_AIPM_SOURCE_REVIEW.patch

Additionally create:

`Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md`

containing:

- corrected final HEAD;
- full list of changed V1.7 source/test files;
- symbol index for:
  - DerivedTopologySnapshotBuilder
  - CanonicalTopologyBuilder
  - CanonicalGeometryGraph
  - GapPairProposer
  - GapBridgeExecutor
  - WorkingModeRunner compute/apply gap methods
  - `_crossing_checker_proc`
  - SU derived workspace repair-group methods
  - topology UI renderer / CTA logic;
- line ranges or grep anchors;
- exact tests covering N/G/X/H/T/L/P matrix.

Do NOT paraphrase code into this file.
The patch remains the source evidence.

---

# 6. NO PRODUCT REDESIGN

Do NOT change:

- `endpoint_bridge` as the only executable V1.7 repair type;
- `gap_search` authority;
- `coordinate_epsilon` canonical identity semantics;
- source immutability;
- workspace-owned repair geometry;
- mutual-unique pairing;
- Curve/Face/layer/Z conservative rules;
- Undo architecture;
- Observer architecture;
- Simplified Chinese UX;
- V1.8 boundary.

If an actual source bug makes one of the above impossible:
STOP and report the exact blocker.

---

# 7. REQUIRED REGRESSION

Run:

1. explicit X1-X4 tests;
2. explicit T3-T4 tests;
3. canonical origin-kind mapping test;
4. full focused V1.7 suite;
5. full Ruby suite;
6. Node DOM suite;
7. V1.6 close-autodiscard regression;
8. V1.5 host-state/BLOCK-005 regression;
9. legacy compatibility;
10. RBZ smoke/load;
11. git diff --check.

Rebuild RBZ if production code changes.

If only tests/report change and production code is proven correct, do not rebuild
just to create a new hash unnecessarily unless current packaging policy requires
a final stable candidate after the report checkpoint.

---

# 8. REPORT

Overwrite:

Review/CURRENT_PI_REPORT.md

DISPATCH_ID:
V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01

Report:

A. exact finding disposition R1-R4
B. exact production code changed, if any
C. X1-X4 evidence
D. T3-T4 evidence
E. canonical `origin_kind` mapping evidence
F. corrected complete test matrix
G. source-review patch path + SHA-256
H. critical source index path
I. full regression counts
J. RBZ identity if rebuilt
K. Git facts
L. remaining confirmed defects / assumptions / unknowns
M. `CODEX_GATE: STILL PENDING — DO NOT INVOKE`
N. `OWNER GATE: NOT YET RUN`

Do not claim AIPM PASS.
Do not claim Codex PASS.
Do not claim Owner PASS.

---

# 9. GIT

Create one meaningful correction checkpoint, or two only if production and tests
are cleanly separable.

Suggested:

`fix(v1.7): complete topology safety contracts`

and/or

`test(v1.7): prove crossing and post-repair adjacency`

Do not:
- force-push;
- rebase shared history;
- merge main;
- tag/release;
- start V1.8.

Remote network failure remains non-blocking.

---

# 10. STOP

After:

- R1-R4 corrected;
- source-review patch generated;
- current report updated;
- full regressions green;
- stable local corrected HEAD exists;

STOP.

Return control to AIPM.

Next Gate:

AIPM direct source review of `V17_AIPM_SOURCE_REVIEW.patch`.

Only after AIPM primary PASS:
mandatory Codex xHigh integration review.

END
