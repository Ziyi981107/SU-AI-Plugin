# AIPM STAGE TECHNICAL BLUEPRINT — V1.6

PROJECT: SU-AI-Plugin
STAGE: V1.6 — Planar Normalization / Z Policy
DATE: 2026-08-31
STATUS: FROZEN FOR IMPLEMENTATION
DESIGN OWNER: AIPM
FINAL PRODUCT OWNER: Owner
IMPLEMENTATION AGENT: Pi
SCOPE: CAD preparation only

---

# 0. OWNER SUMMARY

V1.6 should be a lean, visible product slice.

User-visible outcome:

A designer prepares imported CAD, sees which geometry has small unintended Z
drift, reviews one conservative normalization proposal, applies it to the
DERIVED working copy, and ends with cleaner planar geometry while the original
CAD remains untouched.

This stage must NOT become a generic 3D flattening engine.

The primary success demo is:

imported CAD with small Z noise
→ Prepare
→ see Planar Normalization summary
→ Apply Safe Normalization
→ XY unchanged
→ safe derived vertices share one intended Z plane
→ outliers / ambiguous geometry remain unchanged and visible
→ source CAD unchanged

The implementation should optimize for reaching this working vertical slice
quickly. Do not reproduce the V1.5 pattern of repeated speculative architecture
expansion.

---

# 1. PRODUCT CONTRACT

## 1.1 Goal

Prepare predominantly 2D architectural CAD for later topology reconstruction
without silently flattening intentional 3D/elevated geometry.

Frozen principle:

> Non-zero Z is evidence, not permission to flatten.

## 1.2 In Scope

- raw-vs-normalized coordinate distinction;
- Z-distribution diagnostics on current derived CAD geometry;
- one deterministic candidate reference plane in model/world Z;
- conservative batch proposal for safe Z-only normalization;
- user review before applying normalization;
- normalization on DERIVED geometry only;
- XY preservation;
- original raw source coordinates/provenance preserved;
- mixed-Z / outlier reporting;
- idempotency;
- discard / rebuild / host-Undo compatibility through existing V1.4/V1.5 seams;
- SketchUp 2017+ compatible host API route;
- real SketchUp 2020 Owner verification before V1.6 closure.

## 1.3 Out of Scope

- source CAD mutation;
- generic arbitrary-plane flattening;
- terrain;
- site elevation modeling;
- building heights;
- semantic recognition of roads/buildings/green;
- gap repair;
- endpoint merge/snap;
- canonical topology;
- chains / loops / regions;
- curve reconstruction;
- face healing;
- MCP / AI / Agent;
- new Observer architecture;
- new Undo architecture.

## 1.4 Automation Authority

Planar normalization is MEDIUM-confidence by project policy.

Therefore:

- Prepare/analyze MAY automatically compute a normalization proposal.
- It MUST NOT silently apply Z movement merely because non-zero Z exists.
- User performs one explicit batch approval:
  `Apply Safe Normalization`.
- Ambiguous/outlier geometry remains unchanged.
- No per-edge confirmation is required for the safe batch.

## 1.5 Critical Failures

Any of the following is a V1.6 BLOCK:

- source CAD moved/flattened;
- X or Y coordinate changes through Z-only normalization;
- ambiguous/outlier geometry is silently flattened;
- a shared host vertex is moved while incident ineligible geometry is changed as
  a side effect;
- curve/face-host behavior changes geometry outside the approved action set;
- workspace claims READY after partial/uncertain host mutation;
- raw/provenance data is overwritten by normalized coordinates;
- normal V1.6 path requires a SketchUp API newer than the intended SU2017 baseline
  without a safe compatibility route.

---

# 2. EXISTING ARCHITECTURE TO REUSE

Do NOT create a second normalization architecture beside the current V1.x
pipeline.

Reuse:

SketchUp Source Adapter
→ immutable SourceSnapshot
→ DerivedGeometryWorkspace
→ RepairAction / RepairPlan semantics
→ existing WorkingModeRunner lifecycle
→ existing transaction / fail-closed / discard / rebuild behavior
→ existing UI bridge / Working Mode summary
→ provenance and captured ExecutionConfigSnapshot

Important existing facts:

- derived groups are created at MODEL ROOT;
- derived edge endpoints preserve SOURCE WORLD coordinates;
- source geometry remains immutable;
- current host-state consistency validation runs before later destructive use;
- current tolerance/config snapshot is the deterministic execution input.

Therefore V1.6 normalization operates on DERIVED world/model coordinates.

No active-edit local-coordinate mutation path should be invented.

---

# 3. EXTERNAL TECHNICAL EVIDENCE / HOST ROUTE

The approved SketchUp mutation primitive for per-vertex Z-only movement is:

`Sketchup::Entities#transform_by_vectors`

Reason:

- official SketchUp Ruby API documents it since SketchUp 6.0;
- it applies individual translation vectors to multiple sub-entities in one call;
- it supports the legacy-first SU2017+ product baseline;
- mature SketchUp flattening tools use this class of approach for imported DWG
  cleanup.

Do NOT use a newer-host-only API when this baseline primitive is sufficient.

Important caution from mature flattening implementations / SketchUp behavior:

moving vertices participating in Curves or topology with additional incident
geometry can have side effects.

Therefore V1.6 Phase 1 is deliberately conservative around:
- Curve / Arc membership;
- Face adjacency;
- shared vertices connected to ineligible geometry.

Do NOT explode curves as an automatic V1.6 workaround.
Do NOT delete/recreate source or derived topology merely to make flattening easy.

---

# 4. CONFIG / TOLERANCE CONTRACT

## 4.1 New Stage-specific Tolerance

Introduce ONE explicit captured tolerance:

`planar_z_snap`

Recommended initial default:
`0.01 inch`

Rationale:
- matches the current order of magnitude already used by `big_z`;
- remains explicit rather than reusing a warning threshold as repair authority;
- is configurable through the existing Tolerance / ExecutionConfigSnapshot path.

`big_z` remains a PRE-FLIGHT warning threshold.

It MUST NOT become normalization permission.

`coordinate_epsilon` remains the near-zero equality/verification epsilon.

## 4.2 Schema Discipline

Adding `planar_z_snap` changes the captured tolerance field set.

Pi must:
- update Tolerance;
- update `to_h`;
- update ExecutionConfigSnapshot capture/equality/rebuild evidence;
- let the existing deterministic tolerance schema/version mechanism reflect the
  field-set change;
- add regression coverage.

Do not scatter `0.01` through normalization code.

Invalid / nil / non-finite / <= 0 normalization tolerance:
- no normalization plan is executable;
- report a stable fail-closed reason;
- do not silently fall back to another tolerance.

---

# 5. NORMALIZATION DATA CONTRACT

V1.6 should remain compatible with the existing RepairPlan model.

Preferred action representation:

`action_type = :normalize_z`

Each material action/proposal must preserve conceptually:

- action_id;
- action_type;
- rule_id;
- target_z;
- tolerance used;
- affected derived IDs;
- affected source occurrence IDs;
- affected host vertex count;
- before Z summary;
- proposed after Z summary;
- max absolute Z movement;
- reason / confidence basis;
- status;
- validation result;
- provenance / normalization-history record.

Do NOT overwrite raw source coordinates.

Normalized geometry summaries may be added to derived records / normalization
history, but the SourceSnapshot remains immutable.

---

# 6. PLANAR BASELINE ALGORITHM

Use the simplest deterministic algorithm that is safe.

Input:
- unique eligible DERIVED edge vertices in world/model coordinates;
- captured `planar_z_snap`;
- captured `coordinate_epsilon`.

## 6.1 Eligible diagnostic population

For baseline detection, include unique vertices belonging to ordinary derived
Edges.

Exclude from AUTO-APPLY eligibility:
- non-finite points;
- invalid/missing host handles;
- Curve / Arc members;
- vertices with Face adjacency;
- any vertex whose incident derived geometry cannot be completely accounted for
  by the candidate set.

Excluded geometry may still contribute to diagnostics only if doing so is
unambiguous; otherwise exclude and report why.

## 6.2 Find one dominant planar band

From eligible unique vertex Z values:

1. sort Z ascending;
2. use a deterministic sliding window;
3. a valid window must satisfy:
   `max_z - min_z <= planar_z_snap`;
4. find the window containing the greatest number of eligible unique vertices;
5. if two materially different windows tie for maximum count:
   baseline is AMBIGUOUS → no executable normalization batch;
6. require the winning window to contain a strict majority (>50%) of eligible
   vertices;
7. otherwise:
   no executable normalization batch;
8. `target_z` = deterministic median of the winning window.

Why:
- avoids assuming world Z=0;
- handles a CAD group positioned at non-zero elevation;
- ignores large Z outliers;
- refuses a 50/50 two-plane case rather than guessing.

## 6.3 Inliers / outliers

Inlier:
`abs(vertex.z - target_z) <= planar_z_snap`

Movable:
inlier AND
`abs(vertex.z - target_z) > coordinate_epsilon`

Already planar:
inlier AND
`abs(vertex.z - target_z) <= coordinate_epsilon`

Outlier:
outside the planar band.

Outliers remain unchanged and visible in audit/UI.

## 6.4 Shared-vertex safety

A host vertex may be moved only if ALL incident derived edges that would be
affected by moving that vertex are themselves eligible for the same target_z.

If moving one vertex would change:
- an outlier edge;
- an excluded curve;
- face-owned geometry;
- untracked/unmapped derived geometry;
- another ineligible entity;

then the affected connected candidate scope is NOT auto-executable.

Stable reason:
`shared_vertex_scope_ambiguous`

This prevents one approved edge from silently dragging another entity in Z.

---

# 7. PREVIEW / PLAN BEHAVIOR

Prepare should compute and expose a Planar Normalization summary without moving
geometry.

Minimum user-visible summary:

- target plane Z;
- eligible vertices;
- vertices already planar;
- vertices proposed to move;
- affected derived edges;
- outlier vertices / edges;
- skipped ambiguous geometry;
- maximum proposed Z movement.

Minimum states:

`NO_CANDIDATE`
- already planar or no eligible geometry.

`READY_TO_NORMALIZE`
- one deterministic safe batch exists.

`REVIEW_REQUIRED`
- non-zero/mixed Z exists but no safe dominant plane or shared-vertex/curve/face
  ambiguity prevents batch execution.

`APPLIED`
- batch applied and validated.

`FAILED`
- host operation / post-validation uncertain or failed.

The existing `significant_non_zero_z` issue remains diagnostic evidence.
Do not reinterpret it as automatic repair permission.

---

# 8. EXECUTION CONTRACT

On explicit user action:

`Apply Safe Normalization`

## 8.1 Preflight before host operation

Before `start_operation`:

- current workspace is READY;
- host-state consistency validation passes;
- action plan was built from the same current workspace/config;
- every target derived handle exists and is valid;
- every target host vertex is unique and valid;
- shared-vertex incident scope is fully safe;
- target_z finite;
- movement vectors finite;
- every vector is exactly:
  `[0, 0, target_z - current_z]`;
- expected post-state is calculated before mutation.

If any proof fails:
- do not open host operation;
- mark action skipped/failed truthfully;
- no geometry change.

## 8.2 Host mutation

Use one SketchUp native operation for the entire approved normalization batch.

Preferred host primitive:
`Entities#transform_by_vectors(unique_vertices, vectors)`

The transformed vertices must belong to the same owning `Sketchup::Entities`
collection required by the API.

If safe ownership cannot be proven:
fail closed.

Do not:
- move source entities;
- transform whole source groups;
- recreate source geometry;
- explode curves;
- create a new Observer system.

## 8.3 Commit / failure

Reuse existing transaction philosophy:

- successful mutation + validation → commit;
- pre-commit mutation failure → abort where current adapter contract supports it;
- commit uncertainty → workspace FAILED, do not fabricate rollback success;
- later interaction uses existing host-state consistency validation.

---

# 9. POST-VALIDATION

After host mutation and before publishing READY/APPLIED truth, prove:

For every moved vertex:

- `abs(after.x - before.x) <= coordinate_epsilon`
- `abs(after.y - before.y) <= coordinate_epsilon`
- `abs(after.z - target_z) <= coordinate_epsilon`

Additionally:

- source fingerprint unchanged;
- affected derived records still map to the expected current host entities;
- moved vertex count matches the expected unique vertex set;
- outlier/skipped geometry unchanged;
- workspace inventory remains coherent;
- normalization audit is recorded.

If validation fails:
- workspace must not claim READY;
- failure reason must be inspectable;
- source remains unaffected;
- user can discard/rebuild.

---

# 10. PROVENANCE / NORMALIZATION HISTORY

V1.6 must preserve enough history for later PreparedCadDataset provenance.

For each applied normalization batch record conceptually:

- normalization rule/version;
- captured `planar_z_snap`;
- target_z;
- affected source occurrence IDs;
- affected derived IDs;
- before Z summary;
- after Z summary;
- max movement;
- applied/skipped/failed counts.

Raw source coordinates remain in SourceSnapshot.

Do NOT replace raw coordinates with normalized ones.

---

# 11. UX — LEAN STAGE

Must Have:

- existing Prepare workflow computes normalization preview;
- a compact `Planar normalization` row/section appears in Working Mode;
- target Z and candidate/moved/skipped/outlier counts are visible;
- one explicit `Apply Safe Normalization` control when state is
  READY_TO_NORMALIZE;
- clear `Review required` / `No safe normalization` text when ambiguous;
- after apply, truthful before/after summary;
- existing Discard / Rebuild remains available.

Can Defer:

- dedicated overlay colors;
- per-edge checkboxes;
- interactive plane gizmo;
- arbitrary custom target Z editor;
- multiple simultaneous plane selection;
- animation;
- advanced profile UI.

Do not build a mini CAD editor.

---

# 12. TEST MATRIX

## 12.1 Pure / deterministic

P1 — already planar:
all z equal within coordinate_epsilon
→ NO_CANDIDATE.

P2 — small noisy plane:
z values within planar_z_snap
→ one deterministic target_z
→ movable set correct.

P3 — non-zero translated plane:
all geometry around world Z = 1000
→ target around 1000, NOT zero.

P4 — one large outlier:
dominant small-noise plane + distant vertex
→ inliers proposed, outlier unchanged.

P5 — 50/50 two-plane split:
→ ambiguous, no executable batch.

P6 — tied dominant windows:
→ ambiguous, no guess.

P7 — invalid/non-finite tolerance:
→ fail closed, no executable batch.

P8 — invalid/non-finite coordinates:
→ skipped/review, no destructive action.

P9 — idempotency:
apply once, recompute
→ zero further movement within epsilon.

## 12.2 Geometry safety

G1 — XY preservation:
exactly no material XY movement.

G2 — shared vertex with ineligible edge:
→ skip affected scope.

G3 — curve/arc membership:
→ no auto-normalization.

G4 — face adjacency:
→ no auto-normalization.

G5 — outlier edge:
→ unchanged.

G6 — source fingerprint:
unchanged before/after.

## 12.3 Host / transaction

H1 — all preflight invalid:
zero host operation begins.

H2 — successful batch:
one begin, one transform batch, one commit.

H3 — transform failure:
abort / fail per current adapter contract; no READY lie.

H4 — commit uncertainty:
FAILED; no fake rollback claim.

H5 — native Undo after applied normalization:
existing validate-on-next-interaction / invalidation path remains safe.

H6 — Discard/Rebuild:
source unchanged; rebuilt derived geometry returns to source-derived state and
normalization can be proposed again.

## 12.4 Compatibility/package

C1 — production Ruby stays old-runtime compatible.
C2 — only SU2017-baseline host APIs in correctness path, or explicit capability
     fallback.
C3 — RBZ contains and loads all V1.6 production modules through the real entry
     path.
C4 — SketchUp 2020 real-host Owner test before closure.

---

# 13. OWNER REAL-HOST ACCEPTANCE — V1.6

Use a tiny manually-created or imported CAD-like edge sample.

Required Owner scenarios:

A. Small Z noise:
- Prepare;
- see normalization proposal;
- Apply Safe Normalization;
- visually / diagnostically verify the derived result is planar;
- source unchanged.

B. Non-zero translated plane:
- source/derived geometry around a non-zero world elevation;
- normalization stays near that plane, not world zero.

C. Outlier:
- one clearly different-Z edge/vertex;
- safe majority normalizes;
- outlier remains unchanged / reported.

D. Ambiguous split:
- two comparable Z planes;
- plugin refuses to guess.

E. Discard / rebuild:
- source still intact;
- normalized derived workspace can be discarded/rebuilt.

Real SketchUp 2020 PASS is required for V1.6 closure.

Do not claim real SU2017 verification unless separately run.

---

# 14. PERFORMANCE

Target algorithmic shape:

- baseline detection: O(V log V);
- candidate classification: O(V + E) after sorting;
- one host transform batch for executable vertices.

Do not optimize beyond measured need.

No spatial tree, graph database, generalized geometry kernel, or background
worker is authorized for V1.6.

---

# 15. REVIEW POLICY

Default:
Pi implementation + tests
→ AIPM direct source review.

Codex is NOT a routine mid-stage reviewer.

Escalate only if implementation reveals a material repo-aware issue involving:
- unexpected world/local transform conflict;
- source/derived ownership change;
- transaction/recovery change;
- provenance architecture change;
- host API compatibility blocker;
- destructive normalization behavior outside this frozen contract.

Do not create repeated Codex micro-gates.

---

# 16. IMPLEMENTATION ORDER

Pi should implement in this order:

1. config/tolerance field + captured snapshot tests;
2. pure PlanarNormalizationAnalyzer / proposal logic;
3. pure audit/result structures;
4. workspace integration WITHOUT host mutation;
5. UI summary + Apply Safe Normalization action;
6. production adapter host vertex resolution + transform_by_vectors batch;
7. expected post-state / preflight;
8. transaction + post-validation;
9. regression / RBZ / package;
10. Owner-test candidate.

Prefer one coherent implementation packet rather than many micro-dispatches.

---

# 17. DEFINITION OF DONE

V1.6 implementation is ready for AIPM Gate when:

- V1.5 remains unchanged/closed;
- source CAD is immutable;
- a safe dominant Z plane is deterministically proposed when evidence supports it;
- ambiguous/mixed-Z cases are not guessed;
- explicit user approval exists before material Z movement;
- only derived geometry moves;
- XY is preserved;
- outliers remain unchanged;
- shared-vertex/curve/face side-effect risks fail closed;
- normalization history/provenance is inspectable;
- repeated normalization is idempotent;
- existing discard/rebuild/Undo safety remains intact;
- targeted + full regression + RBZ smoke pass;
- current RBZ is ready for SU2020 Owner verification.

V1.6 does NOT need to solve V1.7 gap repair.

END
