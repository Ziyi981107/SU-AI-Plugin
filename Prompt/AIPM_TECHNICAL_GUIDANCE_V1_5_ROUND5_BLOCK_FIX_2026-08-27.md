# AIPM TECHNICAL GUIDANCE — V1.5 ROUND-5 EXISTING BLOCK FIX

Project: SU-AI-Plugin
Date: 2026-08-27
Authority: ChatGPT / AIPM
Status: FROZEN TECHNICAL GUIDANCE
Stage: V1.5 — High-confidence Auto Repair
Cycle: Round-5 corrective implementation
Scope: Existing `V15-STAGE-BLOCK-001..005` only
V1.6: NOT STARTED

## 0. AIPM adjudication
AIPM accepts the Round-4 Codex BLOCK verdict.

This is not a new product Stage and does not change V1.5 product semantics. Round-4 architecture remains authoritative except for the clarifications below. Pi implements; Pi does not redesign.

## 1. Frozen repair semantics
- Source CAD immutable.
- Auto-repair only deterministic complete direct-match components.
- Non-transitive/incomplete connected components skipped whole.
- No destructive maximal-clique sub-action.
- One atomic executable batch.
- READY may coexist with truthful skipped ambiguity.
- READY may not coexist with host/logical divergence, invalid live-handle proof, failed expected-state invariant, or a remaining duplicate pair belonging to an applied component.

## 2. BLOCK-001 — complete final live-handle proof

The executor must validate the COMPLETE expected member set from each action. Do not define safety truth by filtering only successfully resolved handles.

For each action:
- expected member IDs = survivor + all removals;
- every member resolves to exactly one current host handle;
- any missing member is failure;
- any `valid? != true` is failure;
- all handles pairwise distinct by object identity (`equal?` semantics);
- check survivor/removal AND removal/removal alias;
- survivor appears exactly once and is not in removal set;
- current source identity/provenance/snapshot membership remains valid;
- finite/layer/tolerance guards remain valid.

Immediately before `begin_operation`, after expected-state validation, rerun this proof for the WHOLE executable batch. If any action fails:
- begin=0;
- no disposal/commit;
- no applied rows;
- exact logical pre-state retained;
- no READY;
- truthful stable reason code.

No partial execution of remaining actions.

## 3. BLOCK-002A / BLOCK-004 — tolerance semantics

Captured tolerance states:
1. finite `> 0`: tolerance-grid path;
2. finite `== 0`: VALID exact-match mode;
3. missing / negative / NaN / ±Inf / non-numeric: invalid -> fail closed.

Captured `0.0` must never become `0.0001`. Remove all production fallback.

### Exact-zero path
Do not enter grid math.

Use orientation-insensitive exact endpoint-pair hashing:
1. finite endpoints only;
2. normalize numeric zero if required for stable hashing;
3. build exact endpoint coordinate triples;
4. lexicographically order the two endpoints to form one orientation-independent edge key;
5. hash key -> records;
6. enumerate every unique unordered pair within each bucket exactly once;
7. shared `direct_match?` at tolerance 0 remains final authority;
8. stable pair ordering/dedup.

Forward/reversed exact duplicates must share one key. Division by zero must be impossible.

### Positive tolerance
Keep Round-4 rules: captured tolerance cell size, mathematical floor, BOTH endpoint cells, 27-neighbor lookup around BOTH endpoints, shared direct_match? final authority, stable unordered pair dedup.

The same captured value must flow detector -> proposer -> expected state -> validator -> audit -> runner/UI.

## 4. BLOCK-002B — genuine non-transitive regression

Production policy remains complete-graph-or-skip.

Required geometric case:
- tolerance = T > 0;
- equal-length/equal-orientation edges offset by 0, 0.75T, 1.5T;
- therefore A~B, B~C, A!~C.

Generate evidence through production detector/shared semantics; do NOT manually fabricate an impossible B-C issue.

Under multiple derived-ID orderings prove:
- exactly 2 direct pairs;
- one connected non-transitive component;
- 0 executable/destructive actions;
- exactly 1 skipped whole-component row;
- all member IDs exactly once, stable order;
- issue IDs/provenance retained;
- no disposal;
- logical and host geometry unchanged;
- summary preserves the skip.

Complete 3-member clique remains one action, lexicographically smallest survivor, full provenance union, pair count 3 -> 0 for applied component.

## 5. BLOCK-003 — expected post-state + transaction

Before begin, build one pure expected batch state containing:
- captured tolerance;
- exact pre/post inventory IDs;
- removed/survivor IDs;
- applied action/component membership;
- exact survivor provenance unions derived from pre-state;
- expected geometry;
- canonical expected workspace fingerprint;
- expected survivor/removal handle identity shape;
- direct-pair evidence/metrics;
- unresolved skipped component IDs.

Hard pre-host invariants:
A. exact inventory transition;
B. each removed ID disappears exactly once;
C. each survivor remains exactly once;
D. exact deterministic provenance union (non-empty is insufficient);
E. canonical geometry+provenance+inventory serialization produces expected fingerprint;
F. the exact logical state that will be published has that same fingerprint;
G. all expected handles exist/live and all survivor/removal/removal sets are pairwise disjoint;
H. every applied component collapses to one survivor;
I. zero direct duplicate pairs belonging to every applied component remain in expected post geometry.

Any failure A-I => begin=0, no mutation, no applied action, pre-state unchanged, not READY.

Tests must trigger REAL invariant mismatches through pure-data seams. Monkeypatching `validate!` to simply return false is not proof.

### Host sequence
1. build expected state;
2. validate A-I;
3. second complete live-handle recheck;
4. begin exactly once;
5. dispose removals;
6. PRECOMMIT observation:
   - survivors still live/valid;
   - planned removals observably no longer live/valid under production handle semantics;
   - identities still match the proven batch;
   - no survivor accidentally disposed;
7. mismatch => abort exactly once, commit=0, no post-state publish, exact logical pre-state, failed/non-ready;
8. match => commit exactly once;
9. after confirmed commit publish exactly the PREVALIDATED logical post-state/fingerprint.

Commit raise/uncertainty => failed/non-ready; preserve evidence; do not fabricate successful rollback.

## 6. BLOCK-004 — audit / READY
- invalid/missing tolerance => explicit failed/skipped evidence, never default;
- pre-execution skipped rows survive end-to-end;
- pair metric = real unique unordered direct-match pairs under captured tolerance;
- no READY if BLOCK-001/003 final invariants fail;
- stable reasons distinguish missing handle, invalid handle, alias, invalid tolerance, non-transitive component, expected-state mismatch, precommit host-shape mismatch, commit uncertainty.

## 7. BLOCK-005 — production Owner path + Undo reconciliation

The currently published Owner checklist is invalid and must not be executed. Pi must not edit it.

No live Owner flow may use `WorkingModeRunner.reset_for_tests` or another test/private-state mutation hook.

Primary Owner path = normal product UI/dialog. Optional Ruby Console observation must be read-only or explicitly supported production APIs.

### Host-change / Undo reconciliation
SketchUp Undo can alter host geometry after plugin operations. The plugin must never continue with a stale logical workspace/handle registry.

Before any later V1.5 action/refresh that relies on stored workspace:
- validate stored workspace/handles against observable host state;
- if mismatch, do not continue destructive work;
- deterministically invalidate to an existing safe non-ready state (`failed`/`stale`/`none` or repo-fitting equivalent);
- surface stable reason such as `host_state_changed`;
- require/use existing safe rebuild/prepare before destructive work resumes.

After discard -> user Undo -> next supported plugin interaction:
- no false discarded/ready coherence if host geometry was restored;
- stale handles are not used;
- rebuild/prepare establishes new current inventory + handle registry;
- UI/snapshot reflects reconciled/rebuilt truth.

Do NOT add a large observer architecture unless existing seams make validate-on-next-interaction impossible. Validate-on-next-interaction -> invalidate -> rebuild is sufficient for V1.5.

Pi must return production-safe paths/evidence to AIPM. AIPM republishes the Owner checklist only after Pi packet review and later Codex PASS.

## 8. Required Round-5 tests

BLOCK-001:
- missing removal handle -> begin=0;
- invalid removal -> begin=0;
- survivor/removal alias -> begin=0;
- removal/removal alias -> begin=0;
- all-valid distinct -> success;
- host/logical pre-state retained for every preflight failure.

BLOCK-002A/004:
- exact-zero forward and reversed;
- exact-zero 3-member clique pair count = 3;
- exact-zero through detector/proposer/topology/expected-state/validator/runner;
- missing/negative/non-finite -> no auto-repair;
- captured 0.0 never becomes 0.0001;
- positive-boundary regressions remain green.

BLOCK-002B:
- genuine 0/.75T/1.5T production chain;
- multiple ID orders;
- 2 pairs, 0 actions, 1 skipped row, IDs exactly once, host/logical unchanged.

BLOCK-003:
- real provenance mismatch -> begin=0;
- real fingerprint mismatch -> begin=0;
- real handle-shape mismatch incl removal/removal alias -> begin=0;
- real topology/residual-pair mismatch -> begin=0;
- Nth dispose failure -> begin=1 abort=1 commit=0 exact logical pre-state;
- precommit host mismatch -> begin=1 abort=1 commit=0;
- success -> begin=1 commit=1 abort=0 published state/fingerprint = prevalidated state;
- commit uncertainty -> failed/non-ready + recovery evidence.

BLOCK-005:
- normal production prepare/apply without reset_for_tests;
- normal discard;
- discard -> simulated host Undo/change -> next plugin interaction detects mismatch and blocks stale handles;
- invalidate/reconcile truth;
- rebuild restores coherent inventory/handles/UI;
- source CAD immutable.

Also run full V1.5, full Ruby, Node DOM, RBZ smoke, rebuild RBZ, `git diff --check`.

## 9. Implementation order
1. tolerance/exact-zero semantics;
2. executor live-handle proof;
3. expected-state hard invariants;
4. precommit host observation;
5. genuine non-transitive integration regression;
6. host-change/Undo reconciliation;
7. audit/READY integration;
8. focused tests;
9. full regressions;
10. rebuild/package;
11. update CURRENT_STATE;
12. overwrite CURRENT_PI_REPORT with matching DISPATCH_ID;
13. final local stable checkpoint;
14. STOP.

## 10. Boundaries
Pi may implement/refactor local V1.5 seams, add tests/diagnostics, update state/report, build/package, local commit.

Pi must NOT:
- edit AIPM Owner checklist;
- run Codex;
- push;
- start/design V1.6;
- reopen unrelated V1.0–V1.4;
- change topology policy, source immutability, or READY semantics;
- invent broad observer architecture.

If precommit observation or reconciliation is impossible through existing seams, STOP and report exact repo gap to AIPM.

## 11. Definition of Done
Ready for AIPM review only when every Codex finding has code/test mapping, forbidden fallback is gone, focused tests prove real invariants, full suites/package are green, RBZ is rebuilt/identified, final local stable commit exists, no push, report/state truthful, and Pi STOPs.

Codex BLOCKs remain OPEN until later narrow xHigh recheck PASS. Owner Verification remains BLOCKED.
