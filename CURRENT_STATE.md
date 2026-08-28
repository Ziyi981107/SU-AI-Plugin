# SU-AI-Plugin — CURRENT STATE

Updated: 2026-08-28
Project: `D:\Projects\SU-AI-Plugin`

Current stage: **V1.5 — High-confidence Auto Repair / Round-5 AIPM Source Review corrective continuation (THIS UPDATE)**
Current status: **FIX-A / FIX-B / FIX-C implementation complete; awaiting AIPM source review and Owner-checklist republish per dispatch §Hard STOP**
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
- V1.5 Round-5 AIPM Source Review corrective packet is complete (THIS UPDATE):
  implemented the bounded AIPM Source Review fixes frozen in
  `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
  (FIX-A strict tolerance parsing + exact-zero layer-key correction,
  FIX-B exact deterministic provenance union,
  FIX-C strict destructive handle-liveness hardening).

### In progress
- Nothing is currently being implemented by Pi.

### Waiting
- AIPM review of the Round-5 Source Review Pi packet
  (`Review/CURRENT_PI_REPORT.md`).
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
- SHA-stamp commit 2 (final acceptance): `b9e1965`
- Final `git rev-parse HEAD`:
  `b9e1965`
- See `Review/CURRENT_PI_REPORT.md` §14 for the full scope.

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

Round-5 Source Review corrective RBZ:

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

Evidence recorded in this file:
- Size: 637,621 bytes
- Entries: 59
- SHA-256:
  `90C49AF2E95452C5DAB22D1ABCE5858B1ABC53F5753B7588ED30728F56ACECEB`

Build command:
`.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe scripts/build_rbz.rb`

This RBZ is **not approved for Owner installation** until the
AIPM Owner verification file is republished AND the next Codex
narrow xHigh recheck passes.

---

## 3. CURRENT TEST EVIDENCE

Round-5 Source Review corrective evidence (THIS UPDATE):

- Targeted Round-5 Source Review corrective regressions
  (FIX-A: 11 strict-tolerance parser unit tests +
   4 exact-zero layer-key tests +
   5 no-fallback production-path tests +
   FIX-B: 6 exact provenance union tests +
   1 provenance mismatch executor-level test +
   FIX-C: 5 strict handle liveness tests
   = 32/32 PASS) (added in this update)
- Existing Round-5 continuation evidence (unchanged): **99/99 PASS**
- Full V15 (existing + new): **131/131 PASS**
- Full Ruby suite: **795/795 PASS**
- RBZ smoke: 9/9 PASS
- Node DOM (html_render): 58/58 PASS
- `git diff --check`: clean
- `git status --short` (after final commit): empty

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
1. AIPM reviews the Round-5 corrective Pi packet
   (`Review/CURRENT_PI_REPORT.md`).
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
implementation (THIS UPDATE) -> awaiting AIPM direct source
re-review -> AIPM Owner-checklist republish -> optional Codex
narrow recheck -> closure / next fix.

Pi is **STOPPED** awaiting AIPM review.

---

# One-Line Current State

**V1.5 Round-5 Source Review corrective packet is complete:
FIX-A (strict tolerance parsing + exact-zero layer-key
correction), FIX-B (exact deterministic provenance union),
and FIX-C (strict destructive handle-liveness hardening)
implemented across 5 production files; 32 new focused
regressions added to `tests/test_v15_round5_block_fix.rb`;
full V15 131/131 PASS, full Ruby 795/795 PASS, RBZ smoke
9/9 PASS, Node DOM 58/58 PASS, `git diff --check` clean,
RBZ rebuilt with new SHA-256
`90C49AF2E95452C5DAB22D1ABCE5858B1ABC53F5753B7588ED30728F56ACECEB`;
BLOCK-005 remains OPEN by design; Pi is stopped; V1.6 must
wait for AIPM/Owner closure and a new AIPM V1.6 Technical
Blueprint.**
