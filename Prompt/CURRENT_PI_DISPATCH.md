# CURRENT PI DISPATCH

DISPATCH_ID: V17-AIPM-FINAL-PRE-CODEX-FIX-2026-09-02
STATUS: ACTIVE
PROJECT: SU-AI-Plugin
STAGE: V1.7 — Endpoint / Gap Repair + Canonical Topology
TARGET_BRANCH: dev/v1.7

Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

AIPM REVIEW:
Review/CURRENT_AIPM_REVIEW.md

REVIEWED HEAD:
43a3ac080d02d4aa809df7429d0589760a2594b3

# 0. MISSION

Fix exactly TWO final source-contract findings:

F-01 captured tolerance authority in RR-04 pre-batch baseline;
F-02 independent proposal-vs-record-vs-host post-validation.

This is the final bounded AIPM correction before mandatory Codex xHigh.

Do NOT:
- redesign V1.7;
- invoke Codex;
- run Owner real-host verification;
- start V1.8;
- add repair types;
- add Observer architecture.

# 1. F-01 — USE THE SAME CAPTURED TOLERANCE AUTHORITY

Current `v17_tolerance` parses only string keys while `Tolerance#to_h` normally captures symbol keys.

Preferred fix:

`v17_tolerance`
→ delegate to `_tolerance_from_snapshot(@current_source)`

Do not create another partial tolerance parser.

Add a non-default captured-tolerance regression proving compute/apply baseline uses identical:

- gap_search
- coordinate_epsilon

and does not silently use defaults.

# 2. F-02 — VALIDATE AGAINST THE READY PROPOSAL, NOT THE RECORD ITSELF

In `GapBridgeExecutor._post_validate`:

For each applied bridge:

- find READY proposal by proposal_id;
- fail if missing;
- expected endpoints = proposal['expected_bridge_endpoints'];
- expected length = proposal['expected_bridge_length'];
- epsilon = proposal['coordinate_epsilon'];

Prove independently:

A. DerivedEntityRecord geometry_summary start/end == proposal endpoints;
B. DerivedEntityRecord geometry_summary length == proposal expected length;
C. actual host endpoint positions == proposal endpoints;
D. origin_kind == generated_gap_bridge;
E. repair_action_id == proposal_id.

Host segment comparison remains undirected.

Add contradiction regression:

proposal = A-B
record = A-C
host = A-C

MUST FAIL.

Preserve reversed host-order PASS and captured epsilon behavior.

# 3. REGRESSION

Run:

- new F-01 custom captured tolerance test;
- new F-02 contradictory record/host vs proposal test;
- all RR tests;
- restored H1..H7;
- all V1.7;
- full Ruby;
- V15 BLOCK-005;
- V16 close-autodiscard;
- LEGACY-COMPAT;
- Node DOM;
- RBZ smoke;
- git diff --check.

Report fresh exact counts.

Rebuild RBZ.

# 4. REPORT

Overwrite `Review/CURRENT_PI_REPORT.md`.

Include:

- F-01 disposition;
- F-02 disposition;
- changed production/test files;
- custom-tolerance evidence;
- independent proposal/record/host evidence;
- full regression counts;
- RBZ path/size/entries/SHA-256;
- final commit SHA;
- remaining real unknowns only;
- `CODEX_GATE: STILL PENDING`;
- `OWNER_GATE: NOT YET RUN`;
- `V1.8: NOT STARTED`.

Do not claim AIPM PASS.

# 5. PUSH / STOP

After green:

one normal fast-forward:

`git push origin dev/v1.7`

No force.
No rebase.
No main merge/push.
No tag/release.

Report remote HEAD and STOP.

Next:
AIPM checks only F-01 and F-02.

If both PASS:
AIPM SOURCE REVIEW PASS → mandatory Codex xHigh.

END
