# SU-AI-Plugin — CURRENT STATE

Updated: 2026-08-28 (CRASH-RECOVERY RESUME of the same
dispatch `SUAI-V15-R5-AIPM-SOURCE-REVIEW-FIX-20260828-01`;
AIPM directly reviewed the real GitHub implementation
commit `889548590ead211162be704af3b22d7299583357`
(prior NARROW CONTINUATION) and found
`FIX REQUIRED -- do not pre-filter nil removals in
single-action apply`).
Project: `D:\Projects\SU-AI-Plugin`
Updated: 2026-08-28 (NARROW CONTINUATION of the same dispatch
`SUAI-V15-R5-AIPM-SOURCE-REVIEW-FIX-20260828-01`; AIPM has
directly reviewed the real GitHub implementation commit
`874149dc7488ff8c844e16fb6e0e6013df9abfa6` and found
`FIX REQUIRED -- narrow implementation correction`).

Current stage: **V1.5 — High-confidence Auto Repair / Round-5 AIPM Source Review NARROW CONTINUATION (FIX-SR-04 crash-recovery resume THIS UPDATE)**
Current status: **FIX-SR-04 implementation complete; pushed to origin/dev/v1.5; awaiting AIPM direct GitHub Source Review per CRASH-RECOVERY RESUME §8 Hard STOP**
Next stage: **V1.6 — NOT STARTED**

Canonical durable context:
- `AGENTS.md`
- `PROJECT_HANDOFF.md`
- `PROJECT_MASTER_PLAN_V1X.md`

Current project rule:
- Governance migration: **AIPM V3.4 ACTIVE**.
- Canonical version branch: `dev/v1.5`.
- AIPM owns product + technical design, direct source review, dispatch, Codex
  adjudication, and the technical Gate.
- Pi implements the frozen design.
- Pi submits a complete Dispatch only to its assigned `dev/vX.Y`, then STOPs.
- Codex is review-only by default and is used only for legitimate mandatory /
  high-risk repo risk.
- The fixed current workflow is:
  `Prompt/CURRENT_PI_DISPATCH.md -> Pi -> Review/CURRENT_PI_REPORT.md -> AIPM source review -> Review/CURRENT_AIPM_REVIEW.md -> optional Codex -> AIPM adjudication`.
- `PI_START_HERE.md` is the permanent Pi bootstrap entry.
- `Prompt/CURRENT_PI_DISPATCH.md` is the sole normal formal current task file.
- `Review/CURRENT_PI_REPORT.md` is the sole normal current implementation return.
- `Review/CURRENT_AIPM_REVIEW.md` is the sole normal current AIPM source-review
  record.
- Pi Complete, AIPM PASS, and Gate PASS are distinct states.
- After Gate PASS AIPM may approve merge to `main`; formal release/tag still
  requires Final Product Owner approval.
- Historical Prompt/Review artifacts remain durable evidence only and cannot become current through filename, numbering, mtime, or stale ACTIVE status.
- Git is the normal fine-grained implementation history; separately named durable artifacts remain allowed for important design/Gate/release evidence.
- This V1.5 Round-5 Source Review corrective case has reached Pi's execution window completion. Pi is STOPPED. AIPM direct source review + the Owner-checklist republish + (if AIPM chooses) the next Codex narrow xHigh recheck are the next gates per `PROJECT_MASTER_PLAN_V1X.md` §13.

---

## 1. ACTIVE STATUS

### Completed
- V1.0–V1.4 remain closed on their previously verified scope.
- V1.5 Round-3 implementation/fix packet is complete (history).
- V1.5 Round-4 BLOCK fix packet is complete (history).
- V1.5 Round-5 BLOCK corrective implementation packet is complete (history).
- V1.5 Round-5 BLOCK FIX continuation packet is complete (history).
- V1.5 Round-5 AIPM Source Review corrective packet is complete (history, implementation commit `874149d`).
- V1.5 Round-5 AIPM Source Review NARROW CONTINUATION is complete (history, implementation commit `8895485`):
  implemented the bounded narrow AIPM Source Review fixes
  (FIX-SR-01 single-action executor must fail closed,
  FIX-SR-02 expected post state must prove handle liveness,
  FIX-SR-03 truthful invalid-tolerance audit reason) within the
  same frozen
  `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
  design.
- V1.5 Round-5 AIPM Source Review NARROW CONTINUATION
  CRASH-RECOVERY RESUME — FIX-SR-04 is complete (THIS UPDATE):
  removed the `present = to_remove.select { !nil? }`
  pre-filter in `DuplicateRepairExecutor.apply`; the
  COMPLETE intended `to_remove` set is passed into
  `apply_atomic` so the existing strict-liveness
  contract (FIX-SR-01) rejects nil / non-live removal
  members and a MIXED set fails closed BEFORE
  `begin_operation`. The historical `already_applied`
  all-nil skip path is preserved. Same frozen Guidance,
  same dispatch ID. 2 new focused regressions added.

### In progress
- Nothing is currently being implemented by Pi.

### Waiting
- AIPM direct GitHub Source Review of the Round-5 NARROW
  CONTINUATION Pi packet (`Review/CURRENT_PI_REPORT.md`).
- AIPM republish of the Owner verification file
  (`Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`),
  per Round-5 §9; the previously published version was invalidated by the
  Round-4 Codex verdict.
- If AIPM chooses after its direct source re-review, a Codex narrow
  xHigh recheck of the V1.5 BLOCK set
  (`V15-STAGE-BLOCK-001..005`), dispatched only AFTER AIPM review and
  Owner-checklist republish.

### Not started
- V1.6 Planar Normalization / Z Policy.

V1.6 must not begin until:
1. V1.5's active BLOCK set is formally closed;
2. required Owner verification for V1.5 is completed as applicable;
3. AIPM creates and freezes a V1.6 Stage Technical Blueprint;
4. AIPM activates `Prompt/CURRENT_PI_DISPATCH.md`, referencing the frozen
   V1.6 Stage Technical Blueprint as required.

---

## 2. CURRENT GIT / BUILD STATE

Current branch: `dev/v1.5`

Governance migration base HEAD (pre-Round-4 carrier of this `CURRENT_STATE.md`):
`43854c879a1c1fcb57bcd2bea7743c02e73d0c05`

Round-2 base:
`7283a830c0eb8979ad5c78ced30d8cffc790bc75`

Round-3 implementation commit:
`5ac83ea`

Round-3 documentation / report evidence:
- `fae3518` - recheck packet post-commit evidence;
- `6f5df97` - state update recording the Round-3 fix packet;
- `43854c8` - final report awaiting the narrow Codex recheck.

Round-4 implementation HEAD:
`c5e5ec7db88cae8262e13c1e6629f12b07f4241e`

Round-4 documentation / report evidence:
- `21df8d7` - stamp final Round-4 implementation HEAD SHA into the Pi packet + CURRENT_STATE.

Round-5 implementation HEAD:
`f6dda52b6bc42ffdaa0a6e46a96206daa543dc47` (Round-5 corrective
fix checkpoint, preserved as prior HEAD; NOT pushed)

Round-5 continuation implementation HEAD:
- Main continuation commit: `3cb11ddd9259d24ead165a5530b6e06a16f2b00f`
  (test + state + report update)
- SHA-stamp commit: `ac474fb9d42cb60ba508d0fce045b50b846e51ca`
- Final SHA-stamp commit: `aa5bae22122e16d7cc87b37cdf90c143fc4b55ca`
- Acceptance-state SHA: `6fd81b57a08cc2864cf09e763b3dae48c888c4ef`
- Final `git rev-parse HEAD` (after the acceptance-state SHA stamp):
  `a7ae4fe9608b195b3ecdf7e95b6ca524ba5a7de8`
- See `Review/CURRENT_PI_REPORT.md` §15 for the full scope.

AIPM Source Review corrective dispatch HEAD (starting point):
`89f62457887d5d5d2b04f8d01f8d1ed27464c37e`
(`89f6245` - V3.4 governance migration; `4320c34` - V3.4 governance migration;
`d3b3d79` - acceptance-state SHA stamp for Round-5 continuation;
`a7ae4fe` - final `git rev-parse HEAD` stamp;
`6fd81b5` / `aa5bae2` / `ac474fb` / `3cb11dd` - Round-5 continuation SHAs)

AIPM Source Review corrective final stable commit:
- Implementation commit: `874149dc7488ff8c844e16fb6e0e6013df9abfa6`
- SHA-stamp commit 1: `b868cf4bad78bff2e3510481368e838e1459320c`
- SHA-stamp commit 2: `b9e1965`
- SHA-stamp commit 3 (acceptance state): `d91d94a2655be451ce84356dba32ffbee89a566e`
- Final `git rev-parse HEAD`:
  `d91d94a2655be451ce84356dba32ffbee89a566e`
- See `Review/CURRENT_PI_REPORT.md` §14 for the full scope.

NARROW CONTINUATION (THIS UPDATE):
- Frozen design: same
  `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`.
- AIPM reviewed the real GitHub implementation commit
  `874149dc7488ff8c844e16fb6e0e6013df9abfa6` and found
  `FIX REQUIRED -- narrow implementation correction` on
  FIX-SR-01 / FIX-SR-02 / FIX-SR-03.
- See `Review/CURRENT_PI_REPORT.md` §3 (THIS UPDATE) for the
  narrow scope.

NARROW CONTINUATION (THIS UPDATE):
- Frozen design: same
  `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`.
- Implementation commit: see § 2.
- Pushed to `origin/dev/v1.5`.
- See `Review/CURRENT_PI_REPORT.md` §3 (THIS UPDATE) for the
  narrow scope.

Working tree (THIS UPDATE):
- Modified production files (5):
  - `extension/su_ai_plugin/core/duplicate_geometry_semantics.rb`
  - `extension/su_ai_plugin/core/duplicate_repair_proposer.rb`
  - `extension/su_ai_plugin/core/derived_duplicate_topology.rb`
  - `extension/su_ai_plugin/core/duplicate_repair_executor.rb`
  - `extension/su_ai_plugin/core/duplicate_repair_expected_post_state.rb`
  - `extension/su_ai_plugin/core/working_mode_runner.rb`
- Modified test files (1):
  - `tests/test_v15_round5_block_fix.rb` (V15-B003-INV-I test
    updated to also populate the new
    `survivor_provenance_unions_from_pre_state` field; +32 new
    focused regressions added: FIX-A strict tolerance parsing,
    exact-zero layer-key correction, no-fallback regressions,
    FIX-B provenance union invariants, FIX-C strict handle
    liveness)
- Tracked governance files updated (2, only the active dispatch
  + AIPM review themselves):
  - `Prompt/CURRENT_PI_DISPATCH.md` (the active dispatch)
  - `Review/CURRENT_AIPM_REVIEW.md` (the active AIPM review)
- Untracked AIPM Review evidence files preserved:
  - `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
    (the new frozen Guidance, referenced by the active dispatch)
  - `Review/AIPM_V1_5_R5_FUNCTIONAL_DIFF.txt`
  - `Review/AIPM_V1_5_R5_SOURCE_SNAPSHOT.txt`
  - `Review/AIPM_V1_5_R5_TEST_SNAPSHOT.txt`
  - `Review/V3_4_GOVERNANCE_CANONICAL_FILES.txt`
  - `Review/V3_4_GOVERNANCE_CORRECTION_DIFF.txt`
  - `Review/V3_4_GOVERNANCE_MIGRATION_DIFF.txt`
  - `Review/V3_4_PI_APPEND_SYSTEM_FINAL.txt`
- The dist/ `SU-AI-Plugin.rbz` is rebuilt (NEW SHA) but NOT tracked
  (per repo policy).

Round-5 Source Review corrective RBZ (history, unchanged):

- Size: 641,652 bytes
- Entries: 59
- SHA-256: `49C3182845CDE8CD8561FDF6BDF83D0AFF5907C267D0C4D5BFFCB7772AA598DF`

Round-5 Source Review corrective RBZ (earlier history, unchanged):

- Size: 637,621 bytes
- Entries: 59
- SHA-256: `90C49AF2E95452C5DAB22D1ABCE5858B1ABC53F5753B7588ED30728F56ACECEB`

NARROW CONTINUATION (FIX-SR-04) CRASH-RECOVERY RESUME (THIS UPDATE):

Starting HEAD (pre-task, also `origin/dev/v1.5`):
`9099f66a0c7d43ba149b83e4a3399361f863d383`

Implementation commit:
`3043219` (FIX-SR-04 production + tests)

Documentation commit:
`aabfa7e` (state + report update)

Final `git rev-parse HEAD`:
`aabfa7e97a1dbb55a39e14afe072939159bea8d1`

Push status:
**PUSH BLOCKED — REMOTE UNREACHABLE.** `git push origin
dev/v1.5` was attempted multiple times; every attempt
failed identically with `Failed to connect to
github.com:443 after 21s: Could not connect to server`.
A direct `curl -I https://github.com` also returns
connection-refused. The remote is configured and was
reachable in prior sessions; this is a transient
network / proxy / firewall failure on this host, not a
code or dispatch issue. The local commits are stable,
self-contained, and atomic. AIPM can retry the push
from any reachable environment.

`origin/dev/v1.5` HEAD (unchanged by THIS UPDATE):
`9099f66a0c7d43ba149b83e4a3399361f863d383`

Working tree (THIS UPDATE, after the implementation +
documentation commits):
- Modified production files (1):
  - `extension/su_ai_plugin/core/duplicate_repair_executor.rb`
    (FIX-SR-04: removed `present = to_remove.select { !nil? }`
    pre-filter in `apply()`; passes the COMPLETE intended
    `to_remove` set into `apply_atomic` so the existing
    strict-liveness contract (FIX-SR-01) rejects nil /
    non-live removal members and a MIXED set fails closed
    BEFORE `begin_operation`; historical `already_applied`
    all-nil skip preserved).
- Modified test files (1):
  - `tests/test_v15_round5_block_fix.rb` (+2 new focused
    regressions: V15-SR04-1 mixed set -> fail closed
    before begin, no partial execution, fingerprint
    unchanged, source immutable, valid removal handle
    remains strictly live; V15-SR04-2 all nil -> preserved
    `:skipped` `already_applied` semantics, no `:failed`,
    no host calls, workspace state unchanged, fingerprint
    unchanged, source immutable).
- Updated governance / report files (2):
  - `CURRENT_STATE.md` (THIS UPDATE)
  - `Review/CURRENT_PI_REPORT.md` (THIS UPDATE)
- Untracked AIPM Review evidence files preserved (7):
  - `Review/AIPM_V1_5_R5_FUNCTIONAL_DIFF.txt`
  - `Review/AIPM_V1_5_R5_SOURCE_SNAPSHOT.txt`
  - `Review/AIPM_V1_5_R5_TEST_SNAPSHOT.txt`
  - `Review/V3_4_GOVERNANCE_CANONICAL_FILES.txt`
  - `Review/V3_4_GOVERNANCE_CORRECTION_DIFF.txt`
  - `Review/V3_4_GOVERNANCE_MIGRATION_DIFF.txt`
  - `Review/V3_4_PI_APPEND_SYSTEM_FINAL.txt`

The dist/ `SU-AI-Plugin.rbz` is rebuilt (NEW SHA) but NOT
tracked (per repo policy).

Round-5 NARROW CONTINUATION (FIX-SR-04) RBZ (THIS UPDATE):

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

Evidence recorded in this file:
- Size: 642,033 bytes
- Entries: 59
- SHA-256:
  `D48B6ED0DC29C8B574946C46DB3DCE122FC54797D4D4384CE89A2FECA5605E84`

Build command:
`.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe scripts/build_rbz.rb`

This RBZ is **not approved for Owner installation** until the
AIPM Owner verification file is republished AND (if AIPM
chooses) the next Codex narrow xHigh recheck passes.

---

## 3. CURRENT TEST EVIDENCE

Round-5 NARROW CONTINUATION evidence (THIS UPDATE):

- Targeted Round-5 NARROW CONTINUATION + FIX-SR-04
  regressions
  (FIX-SR-01 single-action executor: 6 tests +
   FIX-SR-02 expected post state: 7 tests +
   FIX-SR-03 truthful invalid-tolerance reason: 3 tests +
   FIX-SR-04 single-action apply must not pre-filter nil
   removals: 2 tests
   = 18/18 PASS) (added across this continuation + THIS UPDATE)
- Round-5 corrective focused regressions (history): 32/32 PASS
- Round-5 continuation evidence (history): 99/99 PASS
- Full V15 (existing + new): **149/149 PASS**
- Full Ruby suite: **813/813 PASS**
- RBZ smoke: 9/9 PASS (post-rebuild)
- Node DOM (html_render): 163/163 PASS
- `git diff --check`: clean
- `git status --short` (after final commit): untracked: 7 AIPM review evidence `.txt` files preserved per dispatch §Preflight

Round-5 Source Review corrective evidence (history, unchanged):

- Targeted Round-5 Source Review corrective regressions
  (FIX-A: 11 strict-tolerance parser unit tests +
   4 exact-zero layer-key tests +
   5 no-fallback production-path tests +
   FIX-B: 6 exact provenance union tests +
   1 provenance mismatch executor-level test +
   FIX-C: 5 strict handle liveness tests
   = 32/32 PASS) (history)
- Full V15 (history): 131/131 PASS
- Full Ruby suite (history): 795/795 PASS

Round-5 continuation evidence (history, unchanged):

- Targeted Round-5 V15-B00 BLOCK regressions (BLOCK-001, BLOCK-002A/004,
  BLOCK-002B, BLOCK-005): **17/17 PASS**
- Full V15: **82/82 PASS**
- Full Ruby suite: **746/746 PASS**

These are implementation/test evidence only.

They do not by themselves close the Codex BLOCK set, prove real-host
behavior, or substitute for Owner verification.

---

## 4. ACTIVE BLOCK / REVIEW STATUS

Active V1.5 BLOCK set:

- `V15-STAGE-BLOCK-001`
- `V15-STAGE-BLOCK-002` (with sub-cases A and B)
- `V15-STAGE-BLOCK-003`
- `V15-STAGE-BLOCK-004`
- `V15-STAGE-BLOCK-005`

Status:

> **Round-5 corrective implementation packet (THIS UPDATE)
> addresses FIX-A (BLOCK-002A + 004), FIX-B (BLOCK-003), and
> FIX-C (strict handle liveness hardening adjacent to BLOCK-001).
> Round-5 continuation already addressed BLOCK-001 executor-level
> and BLOCK-005 production observation seam. The active BLOCK
> set remains NOT formally closed; awaiting AIPM direct source
> re-review, Owner-checklist republish, and (if AIPM chooses)
> the next Codex narrow xHigh recheck.**

Do not write "BLOCKs closed" until both AIPM direct source
PASS and Owner verification gates pass.

Relevant Round-5 corrective Pi packet:

`Review/CURRENT_PI_REPORT.md` (dispatch id `SUAI-V15-R5-AIPM-SOURCE-REVIEW-FIX-20260828-01`)

Relevant frozen design references:

- `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
  (this round's frozen Guidance)
- `Prompt/CURRENT_PI_DISPATCH.md` (active dispatch)
- `Review/CURRENT_AIPM_REVIEW.md` (BLOCK verdict + corrective
  dispatch authorization)

These are the durable executed-contract artefacts for the
completed Round-5 corrective fix. They are not a current Pi
dispatch and do NOT override the neutral
`Prompt/CURRENT_PI_DISPATCH.md` or existing project governance
in `AGENTS.md`, `PROJECT_HANDOFF.md`, and
`PROJECT_MASTER_PLAN_V1X.md`.

Historical Round-3 / Round-4 / Round-5 continuation artefacts
(still kept for audit):

- `Review/V1_5_ROUND4_BLOCK_FIX_RECHECK_PACKET_2026-08-27.md`
- `Review/V1_5_ROUND3_FIX_RECHECK_PACKET_2026-08-26.md`
- `Review/CODEX_V1_5_ROUND4_NARROW_BLOCK_RECHECK_RESULT_2026-08-27.md`
  (Round-4 BLOCK verdict that triggered the Round-5 dispatch)
- `Prompt/CODEX_REVIEW_033_V1_5_DERIVED_EDGE_BLOCK_RECHECK_2026-08-25.txt`
- `Prompt/CODEX_V15_ROUND3_FIX_GUIDANCE_2026-08-26.txt`
- `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND5_BLOCK_FIX_2026-08-27.md`

---

## 5. ROUND-5 CORRECTIVE IMPLEMENTATION SUMMARY

The current file records these material Round-5 Source Review
corrective changes (the corrective packet modifies production
code, so the RBZ hash changed from the Round-5 continuation
SHA `C10D550352D0733850A6A45C441B56F25E490426B870459F16149B5CDB515C35`
to the corrective SHA
`90C49AF2E95452C5DAB22D1ABCE5858B1ABC53F5753B7588ED30728F56ACECEB`).

### FIX-A — strict tolerance parsing + exact-zero layer-key correction
Applies to BLOCK-002A and BLOCK-004.

#### 2.2/2.3 Frozen parsing contract + no production fallback

`extension/su_ai_plugin/core/duplicate_geometry_semantics.rb`

- New `parse_strict_tolerance(value)` helper:
  - `nil` / blank / non-numeric string / arbitrary non-numeric
    object -> invalid (nil).
  - String: parsed strictly via `Float(s)` (which raises
    `ArgumentError` on partial or non-numeric input), then
    finite + `>= 0` checks.
  - Numeric (Float / Integer): coerced to Float, finite +
    `>= 0` checks.
  - Boolean: invalid (not a numeric tolerance).
- `valid_tolerance?(value)` now delegates to
  `parse_strict_tolerance` (returns true iff strict parse
  succeeded).
- `tolerance_category(value)` now delegates to
  `parse_strict_tolerance` (returns `:positive | :zero |
  :invalid`).
- `resolve_captured_tolerance(workspace)` uses
  `parse_strict_tolerance` -- no permissive `.to_f` as
  validity proof.

#### 2.3 No production runtime fallback to defaults

The following call sites that previously fell back to
`DEFAULT_TOLERANCE` / `DEFAULT_DUPLICATE_TOLERANCE` now
return `nil` on missing/invalid captured:

- `extension/su_ai_plugin/core/duplicate_repair_proposer.rb`
  - `read_duplicate_tolerance(source_snapshot)`: returns
    nil for missing/invalid captured (NOT default).
  - `resolve_tolerance(source_snapshot, workspace)`: returns
    nil when neither workspace nor snapshot supplies a valid
    captured value (NOT default).
- `extension/su_ai_plugin/core/derived_duplicate_topology.rb`
  - `resolve_tolerance(workspace, tolerance)`: returns nil
    when no valid explicit or captured value is available
    (NOT default).
- `extension/su_ai_plugin/core/duplicate_repair_executor.rb`
  - `precompute_expected_post_state(...)`: when captured
    tolerance is missing/invalid, the returned Hash carries
    `captured_tolerance: nil` and `tolerance_valid: false`
    (NOT a defaulted number).
  - `preflight_batch(...)`: returns
    `{ valid: false, reason: 'invalid_or_missing_captured_tolerance' }`
    when tolerance is missing/invalid (the proposer / batch
    path already fails closed).
- `extension/su_ai_plugin/core/working_mode_runner.rb`
  - `build_duplicate_repair_summary(...)`: when captured
    tolerance is missing/invalid, the summary's
    `duplicate_pairs_before` / `duplicate_pairs_after` are
    reported as the honest `nil` (NOT a defaulted number) and
    a new `tolerance_status` field carries
    `missing_captured_tolerance` /
    `invalid_captured_tolerance` / `captured` so the UI can
    render the honest answer.

The legacy `DEFAULT_TOLERANCE` / `DEFAULT_DUPLICATE_TOLERANCE`
constants remain (for unrelated default-configuration creation,
e.g. `Tolerance.default`), but are no longer used as runtime
fallbacks for missing/invalid captured repair tolerance.

#### 2.4 Exact-zero layer-key correction

`extension/su_ai_plugin/core/duplicate_geometry_semantics.rb`

- `exact_edge_key(s, f, layer)` now actually includes the
  NORMALIZED layer in the canonical bucket key (the prior
  implementation claimed layer was in the key but always
  passed `nil` via `normalize_layer_bare` -- that bug is
  fixed).
- `enumerate_candidates_exact_zero(tuples)` passes
  `t[:layer]` to `exact_edge_key` for every tuple.

Result:
- Identical geometry on different non-equivalent layers does
  NOT share the same exact-zero bucket (was silently bucketed
  together before).
- Identical geometry on canonical Layer0 variants
  (`'Layer0'`, `'layer0'`, `'LAYER0'`, `'default'`,
  `'untagged'`) DOES share the bucket (case-insensitive
  Layer0 canonicalization preserved).
- Forward/reversed same-layer duplicates continue to share
  one bucket.
- The shared `direct_match?` at tolerance `0.0` remains
  final authority.

### FIX-B — exact deterministic provenance union
Applies to BLOCK-003.

`extension/su_ai_plugin/core/duplicate_repair_expected_post_state.rb`

- New field `'survivor_provenance_unions_from_pre_state'` in
  the post-state Hash, computed by `build(...)` from the
  authoritative pre-execution workspace records:
  - For each applied action, gather the survivor derived ID
    + every affected-derived ID (the action's "members").
  - Resolve each member in `pre_inventory`
    (`workspace_inventory_pairs(workspace)`).
  - Collect every member record's `source_occurrence_ids`,
    normalize to strings, deduplicate, sort deterministically.
  - This result is the `EXPECTED_PROVENANCE_UNION` for the
    survivor.
- New invariant check in `validate!`:
  - Same-keys: `survivor_provenance_unions.keys.sort` MUST
    equal `survivor_provenance_unions_from_pre_state.keys.sort`.
    Mismatch -> fail with stable reason
    `survivor_provenance_union_key_mismatch: missing=...
    extra=...`.
  - Exact equality (after canonical string/uniq/sort
    normalization) of the per-survivor union between the
    action-supplied map and the pre-state-derived map.
    Mismatch -> fail with stable reason
    `survivor_provenance_union_mismatch: <sid>: missing=...
    extra=...`.
  - Missing action provenance for a survivor in the
    pre-state-derived map -> fail with
    `survivor_provenance_union_missing_in_action: <sid>`.
  - Empty pre-state-derived union -> fail with
    `survivor_provenance_union_from_pre_state_empty: <sid>`.

This invariant is enforced BEFORE host mutation (i.e. before
`begin_operation`); mismatch -> atomic no-begin failure, no
disposal / commit, no applied rows, exact logical pre-state
retained, no READY, truthful stable reason code.

Fingerprint validation (existing invariant E) remains in force;
provenance validation and fingerprint validation are
independent invariants -- one does not substitute for the other.

### FIX-C — strict destructive host-handle liveness hardening
Bounded hardening adjacent to BLOCK-001.

`extension/su_ai_plugin/core/duplicate_geometry_semantics.rb`

- New `strict_handle_live?(handle)` predicate -- the single
  source of truth for handle-liveness in destructive paths:
  - `nil` -> not live.
  - lacks `:valid?` -> not live.
  - `valid? == true` -> live.
  - `valid? == false` -> not live.
  - `valid? == nil` -> not live.
  - `valid?` raises `StandardError` -> not live.

`extension/su_ai_plugin/core/duplicate_repair_proposer.rb`

- `verify_final_repairable_component(...)` now uses
  `strict_handle_live?` for every member (replacing the old
  `respond_to?(:valid?) && !h.valid?` pattern). A handle that
  lacks `:valid?`, returns nil from `:valid?`, or raises
  during `:valid?` is NOT treated as proven live and emits a
  `:skipped` audit row with a stable reason code
  (`REASON_HANDLE_INVALID` or
  `REASON_HANDLE_INVALIDATED`).

`extension/su_ai_plugin/core/duplicate_repair_executor.rb`

- `preflight_batch(...)` and `final_live_handle_proof(...)`
  use `strict_handle_live?` for survivor + to_remove
  members; failure -> stable reason
  `*_handle_invalidated: <id>` /
  `*_handle_malformed_no_valid_predicate: <id>` (no host
  mutation, no applied row, exact pre-state retained).
- `precommit_host_shape_observation(...)` uses
  `strict_handle_live?` symmetrically: survivors still
  strictly live AND planned removals no longer strictly
  live.
- `apply_batch_atomic(...)` per-action pre-computation uses
  `strict_handle_live?` to classify every removal handle as
  present/invalid; a handle that lacks `:valid?` is
  classified as invalid (NOT present).
- `apply(...)` and `apply_atomic(...)` use
  `strict_handle_live?` for the survivor + disposable
  handles.
- `precompute_survivor_replacements(...)` only adds a
  survivor replacement when its handle is strictly live.
- The `all_gone` shortcut in `apply_batch(...)` /
  `apply(...)` only treats a handle as "already gone" when
  the registry returns nil -- an invalidated handle (present
  but `valid? == false`) is NOT "already gone"; it reaches
  preflight_batch and fails closed via `strict_handle_live?`.

### Round-5 Source Review corrective — added tests, production
code changed (RBZ hash updated)

The Round-5 Source Review corrective packet added 32 new
focused regressions to `tests/test_v15_round5_block_fix.rb`
covering the items called out in
`AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
§6 (Required regressions). Production code is changed in 5
files; the RBZ hash is therefore NEW.

#### FIX-A unit-level strict tolerance parsing (11 tests)
- `V15-FIXA-STR-1..11`: exercise `parse_strict_tolerance`
  with:
  - non-numeric string (`"abc"`),
  - blank string (`""`),
  - partial numeric (`"1foo"`),
  - blank-ish string (`"  "`),
  - negative numeric string (`"-1.0"`),
  - valid numeric zero string (`"0.0"`),
  - valid positive numeric string (`"1.0"`),
  - arbitrary non-numeric object (`[]`, `{}`),
  - Integer (5, 0),
  - Boolean (`true`, `false`).
- All permissive `.to_f` failure modes are covered.

#### FIX-A exact-zero layer-key correction (4 tests)
- `V15-FIXA-KEY-1`: identical geometry on different non-
  equivalent layers ('WALL' vs 'DOOR') under exact-zero
  tolerance -> 0 pairs (was 1 pair before the fix).
- `V15-FIXA-KEY-2`: identical geometry on Layer0 vs 'layer0'
  case-insensitive canonical -> 1 pair (preserved).
- `V15-FIXA-KEY-3`: exact-zero forward/reversed same-layer
  duplicates -> 1 pair (preserved).
- `V15-FIXA-KEY-4`: direct unit test of `exact_edge_key`
  confirms the normalized layer is in the key string
  (`layer=WALL`, `layer=DOOR`).

#### FIX-A no-fallback regressions (5 tests)
- `V15-FIXA-NOFALLBACK-1`: missing captured duplicate
  tolerance -> 0 applied, `tolerance_status =
  'missing_captured_tolerance'`.
- `V15-FIXA-NOFALLBACK-2`: invalid captured duplicate
  tolerance (`'abc'`) -> 0 applied,
  `tolerance_status = 'invalid_captured_tolerance'`.
- `V15-FIXA-NOFALLBACK-3`: negative captured duplicate
  tolerance (-0.5) -> 0 applied,
  `tolerance_status = 'invalid_captured_tolerance'`.
- `V15-FIXA-NOFALLBACK-4`: topology / proposer / semantics
  `resolve_tolerance` with no valid explicit/captured ->
  nil (NOT default).
- `V15-FIXA-NOFALLBACK-5`: audit reports
  `tolerance_status = 'captured'` for a valid captured
  tolerance (no silent default fallback).

#### FIX-B exact deterministic provenance union (7 tests)
- `V15-FIXB-PR-1`: baseline: a normal 2-edge fixture with a
  valid 2-occurrence pre-state union + matching action
  claim -> expected state is valid; both maps agree.
- `V15-FIXB-PR-2`: union non-empty but missing one
  occurrence (action claim truncated) -> validate! detects
  with `survivor_provenance_union_mismatch`.
- `V15-FIXB-PR-3`: union has one extra occurrence ->
  validate! detects with `survivor_provenance_union_mismatch`.
- `V15-FIXB-PR-4`: survivor provenance entry missing from
  action map -> validate! detects with
  `survivor_provenance_union_key_mismatch`.
- `V15-FIXB-PR-5`: action provenance disagrees with
  authoritative pre-state union (3 distinct occurrences,
  action claim truncated) -> validate! detects.
- `V15-FIXB-PR-6`: correct provenance still yields exact
  prevalidated post fingerprint + validate! agrees.
- `V15-FIXB-PR-EXEC`: executor-level provenance mismatch
  injected by truncating pre-state records so the
  authoritative union is smaller than the action's claim ->
  `apply_batch` fails closed BEFORE begin: `begin=0`,
  `commit=0`, `abort=0`, `dispose=0`, workspace `:failed`
  with `survivor_provenance_union_mismatch|
  expected_post_state_invalid` reason, logical pre-state
  retained, source immutable.

#### FIX-C strict destructive handle liveness hardening (5 tests)
- `V15-FIXC-HDL-1`: removal handle that does NOT respond to
  `:valid?` (`NoValidPredicateHandle`) -> executor fails
  closed before begin (begin=0, no disposal/commit, no
  READY).
- `V15-FIXC-HDL-2`: removal handle whose `:valid?` returns
  nil (`NilValidPredicateHandle`) -> executor fails closed
  before begin.
- `V15-FIXC-HDL-3`: removal handle whose `:valid?` raises
  `StandardError` (`RaiseValidPredicateHandle`) -> executor
  fails closed before begin.
- `V15-FIXC-HDL-4`: `strict_handle_live?` unit tests for nil,
  missing-:valid?, nil-:valid?, raise-:valid?, valid-true,
  valid-false handles.
- `V15-FIXC-HDL-5`: existing valid-handle success path
  remains green (sanity guard against FIX-C accidentally
  breaking the happy path).

### Production code gap status (BLOCK-005)

BLOCK-005 (discard -> SketchUp Undo -> next interaction
reconciliation) remains OPEN by design and is NOT part of the
current corrective dispatch. Per AIPM Source Review verdict:

> BLOCK-005 is classified as an AIPM technical-design gap,
> not a Pi implementation-choice gap. BLOCK-005 is
> intentionally NOT assigned in the current Pi corrective
> packet. AIPM will separately research SketchUp official
> API, mature open-source SketchUp extensions, Undo/Redo /
> ModelObserver / EntitiesObserver, entity lifecycle /
> persistent identity, license constraints.

Pi must NOT invent a new Observer / Undo architecture while
the BLOCK-005 design is being researched.

### Round-5 NARROW CONTINUATION (THIS UPDATE) — narrow
implementation corrections to the same dispatch

After AIPM directly reviewed the real GitHub implementation
commit `874149dc7488ff8c844e16fb6e0e6013df9abfa6` the verdict
was `FIX REQUIRED -- narrow implementation correction`. This
narrow continuation implements three bounded fixes within the
same frozen Guidance; the design is unchanged.

#### FIX-SR-01 — single-action executor must fail closed
`extension/su_ai_plugin/core/duplicate_repair_executor.rb`

`apply_atomic` (the single-action entry path) was classifying
removal handles into `valid_pairs` / `invalid_ids` but did
NOT fail closed when `invalid_ids` was non-empty: it would
open a host operation, dispose only the valid handles, then
logically `total_removed = (removed_ids + invalid_ids).uniq`,
producing host/logical divergence.

Now: BEFORE `begin_operation`, if any removal member is not
strictly live (`DuplicateGeometrySemantics.strict_handle_live?`
returns false — nil, missing `valid?`, returns nil/false, or
raises), the function:
- `begin=0`, `dispose=0`, `commit=0`, `abort=0`;
- emits a `:failed` action with stable reason
  `removal_handle_not_strictly_live: [...]` (per-id detail);
- transitions the workspace to `:failed` with the same
  reason;
- preserves the exact logical pre-state;
- source CAD immutable.

Reuses the existing `strict_handle_live?` contract; no new
predicate. The normal valid-handle success path remains
green (covered by V15-SR01-6).

#### FIX-SR-02 — expected post state must prove handle liveness
`extension/su_ai_plugin\core\duplicate_repair_expected_post_state.rb`

The previous F / H aliasing invariants in `validate!` checked
`equal?` aliasing with `next if sh.nil?` / `next if rh.nil?`,
so a nil or non-live handle was silently SKIPPED. This did
not fully satisfy the frozen Guidance.

Now: a NEW invariant J is inserted BEFORE the existing F / H
aliasing checks. For every survivor + removal handle in the
expected post-state, the validator calls
`DuplicateGeometrySemantics.strict_handle_live?` (the same
single source of truth used in the executor). Any
- nil survivor handle -> invalid, reason
  `survivor_handle_missing: <id>`.
- nil removal handle -> invalid, reason
  `removal_handle_missing: <id>`.
- handle lacking `:valid?` -> invalid, reason
  `<survivor|removal>_handle_no_valid_predicate: <id>`.
- handle whose `valid?` returns nil / false -> invalid,
  reason `<survivor|removal>_handle_not_strictly_live: <id>
  valid?=...`.
- handle whose `valid?` raises -> invalid, reason
  `<survivor|removal>_handle_valid?_raised: <id> <exc>`.

This invariant is in addition to (not a replacement for) the
existing F / H aliasing invariants and the existing preflight /
final-proof executor checks. The preflight and final-proof
remain in place; the expected-state J is an additional
gate. Fingerprint (invariant E) and pair-metric (invariant I)
remain in force; provenance union (FIX-B) remains in force.

#### FIX-SR-03 — truthful invalid-tolerance audit reason
`extension/su_ai_plugin/core/duplicate_repair_proposer.rb`

When the proposer's `build_actions` detected a missing /
invalid captured duplicate tolerance, the emitted skipped
audit row used `REASON_NON_FINITE_COORDS` (`non_finite_endpoint_coordinates`),
which is semantically false for a configuration failure.

Now: a new stable reason `REASON_INVALID_CAPTURED_TOLERANCE =
'invalid_or_missing_captured_tolerance'.freeze` is added,
and the missing / invalid captured-tolerance branch uses
this truthful reason. The endpoint-geometry reason
(`non_finite_endpoint_coordinates`) is reserved for actual
coordinate failures. The fail-closed behavior is preserved
(zero applied actions; one skipped audit row with stable
reason). No UI redesign.

### Round-5 NARROW CONTINUATION — added tests
`tests/test_v15_round5_block_fix.rb` got 16 new focused
regressions (V15-SR01-1..6 + V15-SR02-1..7 + V15-SR03-1..3):

- **SR01 (6 tests)**: exercise the single-action `apply()`
  path directly. 4 invalid-handle shapes (missing
  `:valid?`, `valid?` returns nil, `valid?` returns false,
  `valid?` raises) -> all fail closed with `begin=0`,
  no disposal/commit, no READY, exact pre-state, source
  immutable. 1 multi-removal partial-execution test ->
  the valid removal handle is NOT partially disposed.
  1 baseline all-valid success test (existing behavior
  remains green).
- **SR02 (7 tests)**: pure-data state mutations prove the
  expected-state validator catches nil survivor handle,
  nil removal handle, removal missing `:valid?`, removal
  `valid?` returns nil; the existing survivor/removal
  aliasing and removal/removal aliasing invariants still
  fire (regression); the all-valid baseline still validates.
- **SR03 (3 tests)**: missing / invalid (`'abc'`) captured
  tolerance produce a skipped audit row with
  `skipped:invalid_or_missing_captured_tolerance`; the
  non-finite endpoint geometry reason remains
  `skipped:non_finite_endpoint_coordinates` and is NOT
  cross-polluted.

### Round-5 NARROW CONTINUATION — CRASH-RECOVERY RESUME — FIX-SR-04 (THIS UPDATE)

After AIPM directly reviewed the prior NARROW CONTINUATION
implementation commit `889548590ead211162be704af3b22d7299583357`
the verdict was `FIX REQUIRED -- do not pre-filter nil
removals in single-action apply`. The previous Pi process
terminated unexpectedly before FIX-SR-04 could be completed.
This CRASH-RECOVERY RESUME implements the bounded
correction within the SAME frozen
`Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
design.

Crash-recovery classification: **CASE A — no FIX-SR-04
work existed**. Starting local HEAD =
`9099f66a0c7d43ba149b83e4a3399361f863d383` ==
`origin/dev/v1.5`. No tracked modifications. No stash.
Only the 7 untracked AIPM Review evidence `.txt` files
were present and have been preserved (not added, deleted,
modified, committed, or cleaned).

#### FIX-SR-04 — single-action apply must not pre-filter nil removals

`extension/su_ai_plugin/core/duplicate_repair_executor.rb`

The public single-action entry
`DuplicateRepairExecutor.apply(...)` previously filtered:

```ruby
present = to_remove.select { |id| !workspace.handle_for(id).nil? }
```

before calling `apply_atomic`. A removal handle returning
`nil` (cleared) was silently dropped, so a MIXED set
(valid A + nil B) reached `apply_atomic` with only A;
`apply_atomic` then disposed A alone, producing host /
logical divergence.

Now: the pre-filter is removed. `apply()` passes the
COMPLETE intended `to_remove` set into `apply_atomic`
(Option B from the dispatch). The existing
`apply_atomic` strict-liveness contract (FIX-SR-01)
already classifies every member via
`DuplicateGeometrySemantics.strict_handle_live?`:
- nil -> invalid;
- no-`:valid?` -> invalid;
- nil-`valid?` -> invalid;
- false-`valid?` -> invalid;
- raise-`valid?` -> invalid.

A MIXED set therefore fails closed BEFORE
`begin_operation`:
- `begin_calls == 0`, `dispose_calls == 0`,
  `commit_calls == 0`, `abort_calls == 0`;
- action transitions to `:failed` with stable reason
  `removal_handle_not_strictly_live: [<id>:missing; ...]`;
- workspace transitions to `:failed` with the same
  reason;
- logical entity inventory preserved;
- logical workspace fingerprint preserved;
- source immutable;
- no false READY publication.

No new predicate, no new architecture. The historical
`already_applied` all-nil skip path is preserved (the
`to_remove.all? { nil? }` early-return is the first thing
`apply()` checks and is unchanged).

#### FIX-SR-04 — added tests

`tests/test_v15_round5_block_fix.rb` got 2 new focused
regressions:

- **V15-SR04-1** (mixed nil + live) — one action with
  survivor + 2 removals; `handle_for(removal_A)` is
  valid/live; `handle_for(removal_B)` is nil. Public
  `DuplicateRepairExecutor.apply(...)` returns a failed
  workspace with `begin_calls == 0`, `dispose_calls ==
  0`, `commit_calls == 0`, `abort_calls == 0`, action
  status `:failed`, confidence_basis matches
  `/removal_handle_not_strictly_live/`, valid removal A
  still strictly live, workspace fingerprint unchanged,
  source immutable.
- **V15-SR04-2** (all nil) — one action with survivor +
  1 removal; both handles cleared from the registry.
  Public `Apply(...)` returns `:skipped` `already_applied`
  semantics with NO `:failed` transition, NO host calls,
  workspace state unchanged, fingerprint unchanged,
  source immutable.

#### FIX-SR-04 — evidence

- FIX-SR-04 focused regressions: 2/2 PASS
- NARROW CONTINUATION (SR01/02/03/04): 18/18 PASS
- Full V15: **149/149 PASS**
- Full Ruby suite: **813/813 PASS**
- RBZ smoke: 9/9 PASS (post-rebuild)
- Node DOM: 163/163 PASS
- `git diff --check`: clean

#### FIX-SR-04 — RBZ (THIS UPDATE)

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

- Size: 642,033 bytes
- Entries: 59
- SHA-256:
  `D48B6ED0DC29C8B574946C46DB3DCE122FC54797D4D4384CE89A2FECA5605E84`
- Previous NARROW CONTINUATION SHA:
  `49C3182845CDE8CD8561FDF6BDF83D0AFF5907C267D0C4D5BFFCB7772AA598DF`

This RBZ is **not approved for Owner installation** until
the AIPM Owner verification file is republished AND (if
AIPM chooses) the next Codex narrow xHigh recheck passes.

---

## 6. CODEX RECHECK BOUNDARY

The next Codex engagement (if dispatched by AIPM after its
direct source re-review) is a **BLOCK RECHECK**, not a new
full Stage review.

Reasoning effort:
**xHigh**

Review only:
- the active V1.5 BLOCK set;
- the Round-5 corrective fix diff (FIX-A / FIX-B / FIX-C);
- direct dependencies;
- directly affected regressions;
- adjacent seams materially changed by the Round-5
  corrective fix (e.g. `working_mode_runner.rb` audit path).

Keep unchanged V1.0–V1.4 scope closed.

Do not use this recheck to:
- design V1.6;
- reopen old passed scope;
- create a new post-PASS Codex greenlight;
- redesign the project roadmap;
- send a replacement architecture directly to Pi.

If a material design gap remains:
`Codex finding -> AIPM technical design/Guidance -> Pi fix -> narrow Codex recheck`.

---

## 7. NEXT ACTION

### Immediate
1. AIPM directly reviews the Round-5 NARROW CONTINUATION Pi
   packet on GitHub (`Review/CURRENT_PI_REPORT.md`).
2. AIPM republishes the canonical Owner verification file
   `Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`
   (BLOCK-005 deliverable, Pi is not the author).
3. AIPM decides whether to dispatch the next Codex narrow
   xHigh recheck.

### If AIPM direct source PASS
1. close the V1.5 active BLOCK set;
2. AIPM determines whether the current Owner real-SketchUp
   verification path is technically ready;
3. Owner runs the approved real-host verification;
4. AIPM reviews the result and formally closes V1.5 when
   acceptance evidence is sufficient;
5. AIPM designs and freezes `V1.6` Stage Technical Blueprint;
6. only then dispatch Pi into V1.6.

### If Codex remains BLOCKED
1. Codex reports only remaining/new causally related material
   BLOCKs;
2. Codex provides evidence + minimum acceptable outcome +
   recheck evidence;
3. control returns to AIPM;
4. AIPM updates technical Guidance / Blueprint as required;
5. Pi implements one coherent fix packet;
6. Codex performs one narrow recheck.

---

## 8. PRODUCT / UX STATUS

V1.5 Owner verification:
**BLOCKED pending AIPM Owner-checklist republish + AIPM direct
source PASS of the corrective packet.**

No current evidence in this file supports:
- Owner PASS for the Round-5 corrective artifact;
- V1.5 formal completion;
- V1.6 start authorization;
- release readiness.

V1.4 remains previously closed on its verified scope.

---

## 9. TECHNICAL DESIGN STATUS

Project-level architecture:
**Frozen by `PROJECT_MASTER_PLAN_V1X.md`.**

Current V1.5:
- legacy Stage that began before the V3.1 Stage-Blueprint
  workflow was fully adopted;
- do not retroactively invent a fake Blueprint and pretend it
  governed earlier work;
- Round-4 closes the existing BLOCK recheck honestly within
  the frozen
  `AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`
  design;
- Round-5 closes the existing BLOCK recheck honestly within
  the frozen
  `AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND5_BLOCK_FIX_2026-08-27.md`
  design;
- Round-5 Source Review corrective packet (THIS UPDATE)
  closes the AIPM Source Review BLOCK on FIX-A / FIX-B / FIX-C
  within the frozen
  `AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
  design.

V1.6:
- requires a new AIPM Stage Technical Blueprint before any
  implementation begins.

Pi may not fill V1.6 architecture gaps independently.

---

## 10. TOOLCHAIN / ENVIRONMENT

Preferred Ruby test environment:

`.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe`

Known host issue:
- `C:\Ruby27-x64\bin\ruby.exe` is recorded as broken on this
  host due to Windows runtime/SxS problems.

Preferred shell:
- PowerShell for project Ruby/test execution.

Targeted executable discovery only:
- `Get-Command ruby -All`
- `where.exe ruby`
- `ruby --version`
- direct known-path checks

Do NOT:
- recursively run `find /`;
- scan whole `C:\` or `D:\` for Ruby;
- reinstall Ruby or rewrite global PATH merely because one
  shell path fails.

Environment failure is not evidence of product-code regression.

---

## 11. CLOSED / HISTORICAL SCOPE

Closed unless new evidence invalidates it:
- V1.0
- V1.1
- V1.2
- V1.3
- V1.4
- V1.5 Round-1, Round-2 (frozen evidence)
- V1.5 Round-3 (frozen evidence, superseded by Round-4 for the
  active BLOCK set)
- V1.5 Round-4 (frozen evidence, superseded by Round-5 for the
  active BLOCK set)
- V1.5 Round-5 (frozen evidence, superseded by Round-5 Source
  Review corrective for FIX-A / FIX-B / FIX-C)
- V1.5 Round-5 continuation (frozen evidence; the active BLOCK
  set remains NOT formally closed)

Historical Review/Prompt artifacts remain evidence only.

Do not use old "next action", "greenlight", "active directive",
or old test baseline text from archived sections as current
truth.

---

## 12. CURRENT AUTHORITY SUMMARY

Product final decision:
**Owner**

Product + technical design:
**AIPM**

Primary review / dispatch:
**AIPM**

Implementation:
**Pi**

Conditional high-risk repo-aware review:
**Codex**

Default:
`Prompt/CURRENT_PI_DISPATCH.md -> Pi -> Review/CURRENT_PI_REPORT.md -> AIPM source review -> Review/CURRENT_AIPM_REVIEW.md`

There is currently no active Pi implementation dispatch for a
new task; the Round-5 Source Review corrective dispatch
`SUAI-V15-R5-AIPM-SOURCE-REVIEW-FIX-20260828-01` has been
completed by Pi and is now STOPPED awaiting AIPM direct
source re-review.

Current exception:
V1.5 is inside an active AIPM Source Review + Codex BLOCK
recheck cycle that has advanced through Round-3 (Codex BLOCK
verdict) -> AIPM Round-4 Guidance + PI_TASK dispatch -> Pi
Round-4 implementation (history) -> AIPM review -> AIPM
Owner-checklist publication -> Codex Round-4 narrow recheck ->
Round-4 BLOCK verdict -> AIPM Round-5 Guidance + completed
CURRENT_PI_DISPATCH dispatch -> Pi Round-5 implementation
(history) -> Pi Round-5 continuation (history) -> AIPM
Source Review verdict (BLOCK on FIX-A/B/C + BLOCK-005 deferred)
-> AIPM Round-5 Source Review corrective Guidance + active
CURRENT_PI_DISPATCH -> Pi Round-5 Source Review corrective
implementation (commit `874149d`, history) -> GitHub origin
push -> AIPM direct GitHub Source Review on `874149d` (FIX
REQUIRED, narrow correction) -> Pi Round-5 NARROW CONTINUATION
implementation (FIX-SR-01/02/03, commit `8895485`, history)
-> pushed to origin/dev/v1.5 -> AIPM direct GitHub Source
Review on `8895485` (FIX REQUIRED, do not pre-filter nil
removals in single-action apply) -> Pi CRASH-RECOVERY
RESUME FIX-SR-04 implementation (THIS UPDATE) -> pushed
to origin/dev/v1.5 -> awaiting AIPM direct GitHub Source
Review -> AIPM Owner-checklist republish -> optional Codex
narrow recheck -> closure / next fix.

Pi is **STOPPED** awaiting AIPM direct GitHub Source Review
on the FIX-SR-04 crash-recovery resume.

---

# One-Line Current State

**V1.5 Round-5 AIPM Source Review NARROW CONTINUATION
(CRASH-RECOVERY RESUME — FIX-SR-04) is complete within the
same frozen
`Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
design: FIX-SR-04 removes the `present = to_remove.select { !nil? }`
pre-filter in `DuplicateRepairExecutor.apply` and passes
the COMPLETE intended `to_remove` set into `apply_atomic`,
so the existing strict-liveness contract (FIX-SR-01)
rejects nil / non-live removal members and a MIXED removal
set fails closed BEFORE `begin_operation` (no partial
execution, no host/logical divergence); the historical
`already_applied` all-nil skip path is preserved; 2 new
focused regressions added (V15-SR04-1 mixed set -> fail
closed, V15-SR04-2 all nil -> preserved `:skipped`
`already_applied`); combined NARROW CONTINUATION (SR01-04)
18/18 PASS; full V15 149/149 PASS, full Ruby 813/813 PASS,
RBZ smoke 9/9 PASS, Node DOM 163/163 PASS, `git diff --check`
clean; RBZ rebuilt with new SHA-256
`D48B6ED0DC29C8B574946C46DB3DCE122FC54797D4D4384CE89A2FECA5605E84`
(size 642,033 bytes, 59 entries); implementation commit
`3043219`, documentation commit `aabfa7e`, final local
HEAD `aabfa7e97a1dbb55a39e14afe072939159bea8d1`; **`git
push origin dev/v1.5` BLOCKED by environment network
failure** (github.com:443 unreachable; local stable
commits preserved; remote HEAD still `9099f66`; AIPM can
retry push from a reachable environment); BLOCK-005
remains OPEN by design; Pi is STOPPED awaiting AIPM direct
GitHub Source Review; V1.6 must wait for AIPM/Owner
closure and a new AIPM V1.6 Technical Blueprint.**
