# AIPM TECHNICAL GUIDANCE — V1.5 ROUND-5 SOURCE REVIEW CORRECTIVE FIX

Project: SU-AI-Plugin
Date: 2026-08-28
Authority: ChatGPT / AIPM
Status: FROZEN TECHNICAL GUIDANCE
Stage: V1.5 — High-confidence Auto Repair
Cycle: Round-5 AIPM Source Review corrective continuation
Scope: AIPM Source Review findings for BLOCK-002A / BLOCK-003 / BLOCK-004 + bounded hardening
Target branch: `dev/v1.5`
V1.6: NOT STARTED

## 0. Decision

AIPM directly reviewed the V1.5 Round-5 real functional diff, changed production source, directly affected upstream/downstream code, and relevant tests.

Overall V1.5 Source Review verdict remains **BLOCK**.

This corrective packet fixes the bounded implementation defects that are already fully understood:

1. tolerance parsing / fallback must be genuinely fail-closed;
2. provenance validation must prove the exact deterministic union, not merely non-empty provenance;
3. small adjacent hardening: exact-zero layer key consistency and strict host-handle validity.

**BLOCK-005 discard -> SketchUp Undo / host reconciliation is NOT assigned to Pi in this packet.**
That item remains an AIPM design gap and will be redesigned after targeted official-API + mature open-source SketchUp plugin research.

Pi must not invent a new Observer / Undo architecture.

This is not Round-6 and does not change V1.5 product semantics.

---

## 1. Frozen contracts that remain unchanged

- Source CAD is immutable.
- Repair happens only on derived geometry.
- Only deterministic complete direct-match duplicate components are auto-repairable.
- Non-transitive/incomplete components are skipped whole.
- Captured duplicate tolerance is authoritative.
- Missing/invalid tolerance means **no V1.5 auto-repair**.
- Captured `0.0` means exact-zero matching; it must never become `0.0001`.
- Expected post-state validation must complete before host mutation.
- READY must never hide a failed invariant or host/logical divergence.
- Pi does not redesign product scope, topology policy, transaction semantics, or V1.6.

Previously accepted Round-5 behavior for BLOCK-001 and BLOCK-002B stays closed unless this corrective diff directly invalidates it.

---

## 2. FIX-A — strict tolerance parsing and zero fallback elimination
Applies to BLOCK-002A and BLOCK-004.

### 2.1 Problem

The current source still contains permissive `.to_f` coercion and default tolerance fallbacks.

Examples identified by AIPM Source Review include:
- `DuplicateRepairProposer#read_duplicate_tolerance`;
- `DuplicateRepairProposer#resolve_tolerance`;
- `DerivedDuplicateTopology#resolve_tolerance`;
- compatibility/helper paths such as `DuplicateRepairExecutor#precompute_expected_post_state` if they remain reachable;
- any other current V1.5 production path that silently substitutes `DEFAULT_TOLERANCE` / `DEFAULT_DUPLICATE_TOLERANCE` when the captured value is missing or invalid.

Ruby permissive `.to_f` must not allow arbitrary non-numeric values such as `"abc"` to become valid exact-zero tolerance.

### 2.2 Frozen parsing contract

Introduce or reuse one strict tolerance normalization contract.

Equivalent implementation is allowed, but behavior must be:

- `nil` -> invalid;
- blank string -> invalid;
- non-numeric string such as `"abc"` / `"1foo"` -> invalid;
- arbitrary non-numeric object -> invalid;
- negative -> invalid;
- NaN / +Inf / -Inf -> invalid;
- finite numeric `0` / `0.0` -> valid exact-zero;
- finite positive numeric -> valid positive tolerance;
- a strictly parseable numeric string may be accepted only if parsing consumes the full numeric value (e.g. Ruby `Float(value)` with failure handling or an equivalent strict parser).

Do **not** use permissive `value.to_f` as validity proof.

All consumers must receive either:
- a validated finite non-negative Float, or
- `nil` / explicit invalid result.

### 2.3 No production fallback

For the V1.5 duplicate-repair pipeline:

- no missing/invalid captured duplicate tolerance may silently become `0.0001`;
- proposer must emit a truthful skipped/no-auto-repair outcome when tolerance is unavailable or invalid;
- topology / validator / expected-state / executor / audit paths must fail closed or return no auto-repair according to their existing contract;
- legacy constants may remain only if needed for unrelated default configuration creation, but they must not be a runtime fallback for missing/invalid captured repair tolerance.

Search the directly affected production code for all live uses of:
- `DEFAULT_TOLERANCE`
- `DEFAULT_DUPLICATE_TOLERANCE`
- `.to_f`
around duplicate tolerance resolution.

Do not perform unrelated refactoring.

### 2.4 Exact-zero layer-key correction

The current exact-zero bucket key comments claim normalized layer participates in the key, but the implementation does not actually carry the tuple layer into the key.

Correct this bounded inconsistency.

Required behavior:
- exact-zero canonical key includes normalized layer;
- forward/reversed geometry on the same normalized layer shares the same key;
- identical geometry on different non-equivalent layers does not share the same exact-zero bucket;
- `direct_match?` remains final authority.

No change to the positive-tolerance grid semantics.

---

## 3. FIX-B — exact deterministic provenance union
Applies to BLOCK-003.

### 3.1 Problem

The current expected post-state validator proves that survivor provenance is non-empty, but does not prove that it is exactly the complete union of all pre-state members in each applied duplicate component.

This violates the frozen V1.5 provenance contract.

### 3.2 Authoritative provenance source

For each applied action, derive the expected provenance from authoritative pre-execution workspace records, not merely from an action-supplied aggregate.

For each applied duplicate component:

1. obtain the deterministic survivor derived ID;
2. obtain every planned removal derived ID;
3. resolve the corresponding pre-state `DerivedEntityRecord`s;
4. collect every member record's `source_occurrence_ids`;
5. normalize to strings;
6. deduplicate;
7. sort deterministically.

This result is the `EXPECTED_PROVENANCE_UNION` for the survivor.

### 3.3 Required invariant

Before host mutation, validation must prove all applicable representations agree exactly:

- expected provenance union derived from pre-state membership;
- `survivor_provenance_unions[survivor_id]`;
- survivor post-geometry / post-record provenance;
- action-level provenance if that field is treated as authoritative audit evidence.

Set equality is required after the canonical string/uniq/sort normalization.

The following are all invalid:
- empty union;
- non-empty but missing one source occurrence;
- non-empty but containing an extra source occurrence;
- wrong survivor key;
- missing survivor provenance entry;
- action provenance disagreeing with the pre-state-derived union when action provenance is used downstream.

A provenance mismatch must invalidate the expected post-state **before `begin_operation`**.

No host mutation.
No applied row.
No READY.

Use a stable reason family, e.g.:
- `survivor_provenance_union_mismatch`
- or another concise stable code consistent with existing style.

### 3.4 Do not weaken fingerprint validation

Fingerprint validation remains in force.

Provenance union validation and fingerprint validation are separate invariants; one must not substitute for the other.

---

## 4. FIX-C — strict destructive host-handle liveness hardening
Bounded hardening adjacent to BLOCK-001.

The frozen contract says a destructive batch member is live only when:

- handle is non-nil;
- handle exposes `valid?`;
- `handle.valid? == true`.

A handle that:
- lacks `valid?`;
- returns nil;
- returns false;
- raises while checking validity

must not be treated as proven live for destructive execution.

Prefer one small shared/helper predicate where it reduces inconsistency, but do not perform broad architecture refactoring.

Apply this only to the proposer/executor/expected-state destructive proof seams needed by the current V1.5 contract.

Previously passing alias/missing/invalid safety behavior must stay green.

---

## 5. BLOCK-005 — explicitly deferred from this Pi packet

Do **not** implement a new discard/Undo/reconciliation architecture in this dispatch.

AIPM Source Review established that the current validate-on-next-interaction approach does not prove the real case:

`Discard -> handle registry cleared -> SketchUp Undo restores derived geometry -> plugin must detect/reconcile restored host state`.

The current design assumption is therefore not frozen enough for implementation.

AIPM will separately research:
- SketchUp official API;
- mature open-source SketchUp extension implementations;
- Undo/Redo / ModelObserver / EntitiesObserver patterns;
- entity lifecycle / persistent identity;
- operation boundaries and state invalidation.

Until a new AIPM Guidance freezes BLOCK-005:

- preserve existing behavior unless a change is strictly required by FIX-A/B/C;
- do not add a broad Observer;
- do not invent persistent scanning or recovery state;
- do not claim BLOCK-005 closed;
- do not republish Owner verification;
- do not run Owner verification.

---

## 6. Required regressions

Add targeted regressions proving the actual defects, not only helper behavior.

### Tolerance / BLOCK-002A + 004

At minimum:

1. `"abc"` -> invalid, no auto-repair.
2. `""` -> invalid, no auto-repair.
3. `"1foo"` -> invalid, no auto-repair.
4. negative -> invalid.
5. NaN/Inf -> invalid.
6. `0.0` -> exact-zero path.
7. positive finite -> positive path.
8. missing captured tolerance in a production-relevant proposer path -> no auto-repair; no default.
9. invalid captured tolerance in a production-relevant proposer path -> no auto-repair; no default.
10. topology resolution with no valid explicit/captured tolerance -> no hidden default.
11. search/regression proving current production V1.5 flow has no silent `0.0001` fallback.
12. exact-zero identical geometry on different non-equivalent layers -> not bucketed/matched as same-layer duplicate.
13. exact-zero forward/reversed same-layer duplicates stay green.

### Provenance / BLOCK-003

Build a valid multi-member action with at least three distinct source-occurrence IDs so partial-union defects cannot pass accidentally.

At minimum:

1. exact full union -> valid.
2. union is non-empty but missing one occurrence -> invalid before begin.
3. union has one extra occurrence -> invalid before begin.
4. survivor provenance entry missing -> invalid.
5. action provenance disagrees with authoritative pre-state union, if action provenance participates in publish/audit -> invalid.
6. correct provenance still yields the exact prevalidated post fingerprint.

For executor-level mismatch tests, assert:
- begin=0;
- dispose=0;
- commit=0;
- no applied actions;
- failed/non-ready state;
- logical pre-state unchanged;
- source fingerprint unchanged.

### Handle hardening

At minimum:
- destructive member handle missing `valid?` -> fail before begin;
- `valid? == nil` -> fail before begin;
- existing valid-handle success path remains green.

---

## 7. Regression / package evidence

After focused tests pass, run:

- focused new corrective tests;
- all existing Round-5 tests;
- full V1.5 suite;
- full Ruby suite;
- Node DOM suite;
- RBZ smoke/package tests;
- rebuild RBZ because production source changes;
- `git diff --check`.

Record exact counts and failures truthfully.

Do not alter a test merely to preserve a green count if the frozen contract says the implementation is wrong.

---

## 8. Files / scope

Likely touched production seams include, only as necessary:

- `extension/su_ai_plugin/core/duplicate_geometry_semantics.rb`
- `extension/su_ai_plugin/core/duplicate_repair_proposer.rb`
- `extension/su_ai_plugin/core/derived_duplicate_topology.rb`
- `extension/su_ai_plugin/core/duplicate_repair_expected_post_state.rb`
- `extension/su_ai_plugin/core/duplicate_repair_executor.rb`
- directly affected tests

`working_mode_runner.rb` may be touched only if required to preserve fail-closed tolerance/audit behavior from FIX-A/B/C.

Do not redesign BLOCK-005 in `working_mode_runner.rb`.

Do not touch:
- V1.6;
- source-CAD mutation policy;
- non-transitive complete-graph-or-skip semantics;
- user-visible product scope;
- Owner verification checklist;
- governance files except the normal `CURRENT_STATE.md` / `CURRENT_PI_REPORT.md` completion updates required by the active dispatch.

---

## 9. Implementation order

1. audit every duplicate-tolerance resolver/fallback in the current V1.5 production chain;
2. freeze one strict tolerance normalization helper/contract;
3. remove runtime missing/invalid default fallbacks;
4. correct exact-zero layer key;
5. implement authoritative pre-state-derived provenance union;
6. enforce exact union validation;
7. harden destructive live-handle predicate;
8. add focused regressions;
9. run focused tests;
10. run full regression suites;
11. rebuild/package;
12. update `CURRENT_STATE.md`;
13. overwrite `Review/CURRENT_PI_REPORT.md` with the active DISPATCH_ID;
14. create final stable commit;
15. push assigned `dev/v1.5` only if an existing remote is already configured and normal V3.4 submission is possible;
16. STOP.

Do not configure a new Git remote in this task.
If no remote is configured, report `PUSH NOT POSSIBLE — NO REMOTE` and STOP with a stable local commit.

---

## 10. STOP / escalation

STOP the affected scope and report to AIPM if:

- satisfying FIX-A/B/C requires changing product behavior;
- provenance cannot be computed from authoritative pre-state membership without changing core ownership;
- a tolerance change would alter the frozen complete-graph-or-skip policy;
- fixing the bounded issues requires redesigning transaction/recovery;
- BLOCK-005 becomes entangled and requires an Undo/Observer architecture decision;
- unexpected tracked production changes exist before implementation;
- the current branch is not `dev/v1.5`.

Do not run/request Codex.
Do not start V1.6.
Do not perform Owner verification.

---

## 11. Definition of Done for this dispatch

This dispatch is complete when:

- every assigned AIPM finding (FIX-A/B/C) has implementation + regression mapping;
- no missing/invalid/non-numeric duplicate tolerance can silently become the V1.5 repair default;
- exact-zero layer key is consistent;
- provenance exact-union mismatch is proven to fail before host begin;
- strict destructive handle liveness is enforced;
- focused and full suites are green or any genuine regression is truthfully reported;
- RBZ is rebuilt/identified;
- `CURRENT_STATE.md` and `CURRENT_PI_REPORT.md` are truthful;
- stable final commit exists;
- normal dev-branch push is performed only if an existing remote makes it possible;
- Pi STOPs.

BLOCK-005 remains OPEN after this dispatch by design.
V1.5 remains NOT CLOSED.
