# AIPM TECHNICAL GUIDANCE — V1.5 ROUND-4 BLOCK FIX

Project: SU-AI-Plugin  
Date: 2026-08-27  
Authority: ChatGPT / AIPM  
Status: ACTIVE TECHNICAL GUIDANCE  
Stage: V1.5 — High-confidence Auto Repair  
Review source: `CODEX_V1_5_ROUND3_NARROW_BLOCK_RECHECK_2026-08-27.txt`

## 0. AIPM adjudication

AIPM accepts all five Codex V1.5 Round-3 BLOCK findings as material.

This is not a new Stage and not a new Codex gate.

The Round-3 automated evidence remains valid for the paths it covered, but it
did not prove the safety properties required for:
- live-handle identity;
- complete tolerance candidate enumeration;
- non-transitive duplicate topology;
- complete precomputed post-state;
- truthful audit/tolerance propagation;
- one authoritative Owner verification path.

V1.6 remains NOT STARTED.

The purpose of this guidance is to freeze the minimum technical design needed
to close the existing V1.5 BLOCK set. Pi implements this design; Pi does not
redesign it.

---

# 1. Frozen V1.5 repair semantics

V1.5 auto-repair remains conservative.

A duplicate repair may be auto-applied only when the affected derived geometry
forms one deterministic, high-confidence, conflict-free duplicate component
under the captured execution tolerance.

Ambiguous/non-transitive topology must fail closed as a skipped repair, not be
partially repaired.

Source CAD remains immutable.

Workspace lifecycle `ready` means "the derived workspace is internally valid
and usable", NOT "every duplicate in the selected CAD was repaired".

Therefore:
- unresolved/skipped ambiguous duplicate components MAY coexist with a valid
  `ready` workspace if the audit truthfully reports them;
- an APPLIED action whose promised post-state is not satisfied MUST NOT coexist
  with `ready`.

This distinction is frozen for the Round-4 fix.

---

# 2. BLOCK-001 — Final action eligibility / live-handle proof

Before an executable duplicate action is created, every member of the final
repairable component must pass one complete eligibility proof against the
CURRENT workspace.

The proof must establish:
1. every member has one distinct `derived_id`;
2. every member resolves to one unambiguous current source-edge identity for
   V1.5 action membership;
3. every member has a current host handle;
4. every handle is live/valid;
5. every handle is distinct;
6. survivor handle and removal handles are disjoint;
7. member identity/provenance belongs to the current SourceSnapshot;
8. layer/tolerance/finite-coordinate guards pass;
9. no repeated/aliased member exists.

If any member is missing, stale, invalid, ambiguous, repeated, aliased, or not
current, the entire component is not executable. Emit a truthful `skipped`
audit row with a stable reason code.

Immediately before opening the SketchUp operation, the executor must re-check
that the handles referenced by the eligibility proof are still the same
current live handles.

If the proof no longer holds:
- do not open the host operation;
- do not publish an applied action;
- return skipped/failed evidence as appropriate;
- workspace may remain valid only if no partial host mutation occurred.

Do not add a dangerous production backdoor just to make this testable.

---

# 3. BLOCK-002A — Complete tolerance candidate enumeration

The Round-3 "exact key + <=6 single-axis shifted keys" scheme is not
authoritative anymore.

Introduce one shared pure duplicate-geometry semantics responsibility used by:
- DuplicateDetector;
- duplicate proposer eligibility/revalidation;
- duplicate validator.

Recommended responsibility name: `DuplicateGeometrySemantics`.

This responsibility owns:
- finite-point validation;
- tolerance validation;
- forward/reversed segment `direct_match?`;
- tolerance-safe candidate-pair enumeration.

For tolerance > 0:

1. Use a 3D grid cell size equal to the captured duplicate tolerance.
2. Cell coordinate uses mathematical floor per axis:
   `floor(coord / tolerance)`.
3. Index EVERY edge under BOTH endpoint cells.
4. For each edge, query all 27 neighboring cells around endpoint A and all 27
   neighboring cells around endpoint B.
5. Union/deduplicate candidate edge IDs.
6. Apply the shared `direct_match?` as the final authority.
7. Deduplicate pairs by stable unordered edge-ID pair.

This bounds lookup work to at most 54 neighboring-cell accesses per edge before
candidate deduplication, rather than a 3^6 edge-key expansion.

For tolerance == 0:
- use an exact endpoint-pair hash path.

Negative/non-finite tolerance:
- invalid configuration;
- fail closed for auto-repair.

Production detector/proposer/validator must receive captured execution
tolerance explicitly.

No production path may silently fall back to the historical `0.0001` default.

---

# 4. BLOCK-002B — Non-transitive topology

Do NOT use maximal cliques as destructive action units in V1.5.

Bron-Kerbosch / maximal-clique enumeration must not drive action emission.

Build the direct-match graph for the duplicate candidate scope.

For every connected component with N >= 2:

## Repairable component

The component is auto-repairable ONLY if it is a COMPLETE GRAPH:

`direct_pair_count == N * (N - 1) / 2`

and every member also passes the final live-handle/provenance eligibility proof.

Then:
- emit exactly ONE repair action;
- deterministic survivor = lexicographically smallest `derived_id`;
- removal set = all other members;
- provenance union = deterministic sorted union;
- no member may participate in another emitted action.

## Non-transitive / incomplete component

If the connected component is not complete:
- emit NO destructive action for any sub-clique;
- do not greedily pick one maximal clique;
- emit one inspectable `skipped` component audit row;
- use a stable reason such as `non_transitive_duplicate_component`;
- preserve member IDs, issue IDs, source/provenance evidence;
- leave geometry unchanged.

A~B, B~C, A!~C is therefore skipped as one ambiguous component.

---

# 5. BLOCK-003 — Complete expected post-state before host mutation

Before `begin_operation`, build one immutable/pure-data expected post-state for
the entire executable batch.

Recommended responsibility: `DuplicateRepairExpectedPostState`.

The semantic contract is mandatory even if Pi chooses a repo-fitting file/class
name.

At minimum it contains:
- captured duplicate tolerance;
- complete pre-inventory identity;
- complete expected post-inventory;
- removed derived IDs;
- survivor derived IDs;
- survivor provenance unions;
- expected source/provenance mapping;
- expected geometry records;
- expected derived-workspace fingerprint;
- expected survivor/removal handle identity shape;
- expected direct duplicate-pair metrics;
- applied component/action membership;
- unresolved skipped component IDs;
- validation result.

Before opening a SketchUp operation, prove:

1. inventory transition is exact;
2. removed IDs disappear exactly once;
3. survivors remain exactly once;
4. provenance unions are exact;
5. expected geometry/fingerprint is internally consistent;
6. handle identity shape is valid and disjoint;
7. every APPLIED complete duplicate component collapses to one survivor;
8. no duplicate pair belonging to an APPLIED component remains in the expected
   post-state.

Skipped ambiguous components may remain unresolved and must be visible in audit
metrics.

If expected-state validation fails:
- `begin_operation` must not be called;
- no host mutation;
- no applied action;
- no false READY publication.

Host sequence after pure validation:

1. re-check live-handle proof;
2. begin ONE host operation;
3. dispose planned removal handles;
4. before commit, verify observable host handle shape matches expected
   survivor/removal state;
5. on dispose/precommit mismatch: abort exactly once, commit=0, retain exact
   logical pre-state;
6. on successful commit: publish exactly the precomputed expected logical state.

If commit raises or completion is uncertain:
- state = failed / non-ready;
- do not publish the expected state as confirmed;
- preserve recovery evidence;
- require the existing safe recovery/discard/rebuild path.

---

# 6. BLOCK-004 — Audit truth and tolerance propagation

## Captured tolerance

The same captured duplicate tolerance must flow through:

`execution config`
→ detector
→ proposer
→ expected-post-state validation
→ validator
→ audit metrics
→ UI summary

No production fallback to default tolerance.

If captured tolerance is unavailable/invalid:
- no V1.5 auto-repair;
- explicit failed/skipped evidence.

## Final audit rows

The final result must preserve ALL planned evidence rows:
- applied;
- skipped;
- failed.

Executor output must not filter away pre-execution skipped actions.

At minimum each relevant row preserves:
- action/component ID;
- status;
- stable reason code;
- issue IDs;
- affected derived IDs;
- survivor ID when applicable;
- source edge/provenance evidence;
- captured tolerance;
- before/after evidence applicable to that row.

## Duplicate pair metric — AIPM definition

`duplicate_pairs_before` / `duplicate_pairs_after` means:

the number of UNIQUE UNORDERED derived-edge pairs that satisfy the shared
forward/reversed `direct_match?` under the CAPTURED duplicate tolerance in the
measured workspace/scope.

It is measured from direct-pair evidence.

It is NOT:
- `affected_derived_ids.length - 1`;
- sum of action sizes;
- an inferred clique metric.

Three completely identical derived edges therefore have 3 duplicate pairs.

## READY semantics

Workspace `ready` may coexist with truthful SKIPPED ambiguous components.

Workspace `ready` must NOT coexist with:
- an applied action whose expected post-state failed;
- host/logical divergence;
- invalid/stale action handle proof;
- a remaining direct duplicate pair belonging to an APPLIED repairable
  component;
- a failed batch invariant.

---

# 7. BLOCK-005 — One authoritative Owner verification path

Do not reuse either old similarly named Owner checklist as final executable
authority.

Do not ask Owner to run the current RBZ.

The final Owner verification file will be AIPM-owned and created only AFTER Pi
returns complete Round-4 implementation/build evidence.

Frozen future canonical path:

`Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`

Pi MUST NOT write this file.

Pi must provide AIPM with:
- final branch;
- final implementation HEAD;
- final RBZ path/size/entry count/SHA-256;
- exact production observation paths;
- supported Ruby Console commands if genuinely required;
- FakeSU/production-call-chain evidence for those observation paths;
- G1/G3/Undo/recovery behavior evidence;
- exact UI fields exposed to Owner;
- known host limitations.

AIPM will publish the authoritative checklist before the next Codex recheck.

Old Owner verification files remain historical evidence.

---

# 8. Required Round-4 regression matrix

BLOCK-001:
- 3-member A/C handle alias -> no executable action;
- 3 members, distinct live handles, complete provenance -> one action;
- missing non-survivor handle -> no executable action;
- invalid non-survivor handle -> no executable action;
- survivor/removal alias -> no executable action.

BLOCK-002 candidate enumeration:
- simultaneous multi-axis boundary crossings;
- multiple endpoint coordinates crossing boundaries;
- positive coordinates;
- negative coordinates;
- forward orientation;
- reversed orientation;
- just-outside tolerance -> absent;
- captured tolerance other than 0.0001.

BLOCK-002 non-transitive graph:
- A~B, B~C, A!~C under multiple derived-ID orderings;
- no sub-clique destructive action;
- one explicit skipped ambiguous component;
- no member in multiple actions;
- geometry unchanged.

Complete 3-member clique:
- exactly one action;
- deterministic survivor;
- complete provenance union;
- duplicate pair count before = 3;
- duplicate pair count after for applied component = 0.

BLOCK-003:
- forced provenance expected-state mismatch -> begin_calls = 0;
- forced fingerprint mismatch -> begin_calls = 0;
- forced handle-shape mismatch -> begin_calls = 0;
- forced topology mismatch -> begin_calls = 0;
- Nth dispose failure -> begin=1, abort=1, commit=0, exact pre-state retained;
- success -> begin=1, commit=1, abort=0, published state equals prevalidated state;
- commit failure -> failed/non-ready + recovery evidence.

Use pure validation seams instead of adding dangerous production hooks.

BLOCK-004:
- production runner tolerance 0.001 / delta 0.0005;
- semantic-conflict skipped row survives end-to-end;
- 3 identical edges -> pair count 3;
- non-transitive component -> skipped/unresolved evidence, no partial apply;
- applied-component validation failure -> failed/non-ready;
- issue IDs/provenance retained in audit rows.

---

# 9. Implementation boundary

Pi may:
- implement the design above;
- add/refactor local helpers required to realize it;
- add tests/diagnostics;
- remove Round-3 clique-emission logic from the active path;
- update CURRENT_STATE and Review evidence.

Pi may NOT:
- invent a different non-transitive merge policy;
- keep partial maximal-clique destructive repair;
- change READY semantics beyond this guidance;
- change V1.x scope;
- start V1.6;
- modify product UX beyond minimum truthful audit fields;
- create the final AIPM Owner checklist;
- request Codex review directly.

If this guidance is technically impossible against the current repository seam,
Pi stops the affected work and reports the exact gap to AIPM.

---

# 10. Evidence / stop condition

After implementation Pi must run:
- new focused BLOCK regressions;
- full V1.5 suite;
- full Ruby suite;
- Node DOM suite;
- RBZ smoke/package checks;
- `git diff --check`.

Rebuild the RBZ.

Write one coherent Round-4 Review packet with:
- base/head;
- changed files;
- design-to-code map;
- focused test evidence;
- full regression evidence;
- RBZ facts/hash;
- unresolved limitations;
- facts needed for the final AIPM Owner checklist.

Then STOP and return control to AIPM.

Do NOT:
- ask Owner to install;
- ask Owner to run Ruby Console;
- ask Codex for recheck;
- begin V1.6.

The next Codex recheck will be dispatched only after AIPM reviews the Pi packet
and publishes the authoritative Owner checklist.

---

# One-line Round-4 rule

Use one complete tolerance semantics, auto-repair only complete direct-match
components with valid distinct live handles, prove the full logical post-state
before touching SketchUp, preserve every audit row truthfully, and skip
non-transitive ambiguity instead of partially repairing it.
