# CURRENT PI DISPATCH

DISPATCH_ID: V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01
STATUS: ACTIVE
PROJECT: SU-AI-Plugin
STAGE: V1.7 — Endpoint / Gap Repair + Canonical Topology
TARGET_BRANCH: dev/v1.7

Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

AIPM REVIEW:
Review/CURRENT_AIPM_REVIEW.md

FROZEN BLUEPRINT:
Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md

REVIEWED HEAD:
2cdebb234f004c6980eb737c364274b4a568e8f7

SUBSTANTIVE IMPLEMENTATION HEAD:
e98326ee17cabdeec0b617f22576d1bdc5ce699a

---

# 0. MISSION

Execute the bounded V1.7 direct-source-review correction SR-01 through SR-07.

This is NOT a redesign.

Do NOT:
- invoke Codex;
- run Owner real-host verification;
- start V1.8;
- change V1.7 repair authority beyond the AIPM findings;
- add endpoint-to-edge / extension / intersection repair;
- add Observer architecture;
- mutate Source CAD.

The goal is to make the already-frozen endpoint_bridge architecture truthful
under real host ownership, failure, cleanup, post-validation, identity and
provenance contracts.

---

# 1. READ FIRST

Read:

1. AGENTS.md
2. PI_START_HERE.md
3. PROJECT_HANDOFF.md
4. PROJECT_MASTER_PLAN_V1X.md
5. CURRENT_STATE.md
6. Prompt/CURRENT_PI_DISPATCH.md
7. Review/CURRENT_AIPM_REVIEW.md
8. Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md
9. Review/CURRENT_PI_REPORT.md
10. actual source/tests on dev/v1.7

The AIPM review owns the bounded correction decisions.

---

# 2. SR-01 — ONE LOGICAL BRIDGE = ONE HOST BRIDGE

Remove the double-creation production route.

CURRENT defect:
- add_line_to_repair_group creates host bridge A;
- workspace.build_entity creates host bridge B in a second group.

Required V1.7 base route:

ONE proposal
→ deterministic derived_id
→ `DerivedGeometryWorkspace#build_entity`
→ one workspace-owned top-level derived group
→ one bridge edge
→ private handle_registry owns that derived group.

Use this existing V1.4 ownership route as the Blueprint-approved "safer
equivalent owned repair-geometry container".

Do not also create a shared repair-group edge.

Do not create a parallel ownership registry.

If old ensure_repair_group / add_line_to_repair_group adapter APIs remain, they
must be unused by the production base V1.7 path and clearly non-authoritative.

Lifecycle:
normal workspace Discard/Rebuild/close removes the generated bridge by the same
private registry as other derived geometry.

---

# 3. SR-02 — TRUE FAILED WORKSPACE + LOGICAL ROLLBACK

Capture pre_workspace before host operation.

Apply into working_workspace.

If a mutation/postvalidate failure occurs and host abort is CONFIRMED:
- return a new `:failed` workspace based on exact pre_workspace inventory +
  handle registry;
- no generated bridge record survives logically;
- stable last_error;
- source unchanged.

If commit/abort result is uncertain:
- state MUST be :failed;
- do NOT claim rollback;
- preserve enough current generated handles for explicit Discard recovery;
- no APPLIED truth.

No failure return may expose `post_workspace.state == :ready`.

---

# 4. SR-03 — HARD RUNTIME POST-VALIDATION

Implement the minimum runtime proof from CURRENT_AIPM_REVIEW §4.

Executor-side before APPLIED:
- exact generated count;
- deterministic proposal IDs;
- generated record origin/action;
- record endpoint/length;
- actual host endpoint positions via existing adapter read seams;
- source fingerprint unchanged;
- pre-existing derived source geometry unchanged;
- no non-ready proposal executed.

Runner-side canonical proof after commit and graph rebuild:
- every applied bridge -> canonical `gap_bridge`;
- repair_action_id preserved;
- expected adjacency present;
- no new non_transitive_node_cluster.

Canonical failure after commit:
workspace -> :failed;
retain handles for Discard;
no fake rollback.

---

# 5. SR-04 — TRUE POINT-ON-SEGMENT INTERIOR

Replace collinearity-only `_third_node_on_segment?`.

Use a pure point-on-segment-interior predicate:
- finite 3D points;
- projection `t`;
- endpoint exclusion;
- closest-point distance <= coordinate_epsilon.

Test actual production path.

Far collinear points outside the bridge segment must NOT trigger
third_node_on_bridge.

---

# 6. SR-05 — DETERMINISTIC BRIDGE ID

Remove rand from generated bridge derived IDs.

Preferred:

`der-gap-#{proposal_id}`

Equivalent deterministic collision-safe form allowed.

Canonical edge identity must therefore be stable for equivalent rebuild/reapply.

---

# 7. SR-06 — PLURAL CANONICAL PROVENANCE

CanonicalEdge must preserve:

`source_occurrence_ids`

as full normalized/sorted/uniq provenance.

For gap_bridge:
must contain the complete support union from both incident sides.

Preserve `repair_action_id`.

If a legacy singular field remains, plural is authoritative for V1.8.

---

# 8. SR-07 — UNIQUE LOGICAL GRAPH NODES

Keep topology-builder endpoint membership records if useful.

But CanonicalGeometryGraph.nodes must be one logical node per
canonical_node_id.

Aggregate deterministic membership evidence:
- endpoint_keys;
- derived_edge_ids;
- source_occurrence_ids;
- layer evidence.

Representative world coordinate:
use one deterministic ACTUAL member point selected by stable endpoint_key order.

Do not average/fabricate.

Non-transitive members remain separate.

Correct canonical_node_count to unique logical nodes.

---

# 9. TESTS

Implement the SR1-SR7 regression set from CURRENT_AIPM_REVIEW §9.

Important required failure tests:
- first bridge created, second bridge fails;
- clean host abort;
- no generated logical residue;
- post_workspace FAILED;
- commit uncertainty FAILED;
- actual Discard removes all generated host bridge geometry.

Important host-creation test:
- one safe proposal produces exactly ONE host bridge edge total.

Important topology:
- real almost-closed triangle remains READY and becomes an actual cycle after
  repair.

Run all V1.7 + prior stage regressions.

---

# 10. PACKAGE

If production code changes, rebuild RBZ.

Report:
- path;
- size;
- entry count;
- SHA-256;
- source/package match;
- RBZ smoke.

---

# 11. SOURCE REVIEW RETURN

Overwrite:

Review/CURRENT_PI_REPORT.md

DISPATCH_ID:
V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01

Include:

A. SR-01..SR-07 disposition
B. exact changed production files
C. one-bridge/one-host-geometry evidence
D. failed-state/rollback evidence
E. runtime post-validation map
F. point-on-segment tests
G. deterministic ID evidence
H. plural provenance evidence
I. unique graph-node evidence
J. complete V1.7 matrix
K. prior-stage regressions
L. RBZ identity
M. exact final implementation commit
N. remaining defect/assumption/unknown
O. `CODEX_GATE: STILL PENDING`
P. `OWNER_GATE: NOT YET RUN`
Q. `V1.8: NOT STARTED`

Do not claim AIPM PASS.

---

# 12. GIT + PUSH

Create one or a small number of meaningful correction commits.

After all required tests are green and the local checkpoint is stable:

attempt ONE normal:

`git push origin dev/v1.7`

Rules:
- fast-forward only;
- no force;
- no rebase;
- no main merge/push;
- no tag/release.

If push succeeds:
report remote HEAD.

If unreachable:
report once and STOP normally.

---

# 13. STOP

After:
- SR-01..SR-07 corrected;
- full regressions green;
- RBZ rebuilt;
- CURRENT_PI_REPORT updated;
- stable commit exists;
- one bounded push attempt complete;

STOP and return control to AIPM.

Next Gate:
AIPM direct source RE-REVIEW.

Only after AIPM PASS:
mandatory Codex xHigh integration review.

END
