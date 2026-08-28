# CURRENT PI REPORT — V1.5 ROUND-5 AIPM SOURCE REVIEW CORRECTIVE

Project: SU-AI-Plugin
Version: V1.5
Stage: Round-5 AIPM Source Review corrective continuation
Dispatch: `SUAI-V15-R5-AIPM-SOURCE-REVIEW-FIX-20260828-01`
Dispatcher: ChatGPT / AIPM
Frozen Guidance: `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
AIPM Source Review: `Review/CURRENT_AIPM_REVIEW.md`
Branch: `dev/v1.5`
Status: **IMPLEMENTATION COMPLETE — STOPPED awaiting AIPM direct source re-review**

---

## 1. Scope (per dispatch)

Implemented ONLY the bounded AIPM Source Review fixes frozen
in `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`:

- **FIX-A** — strict tolerance parsing (no permissive `.to_f`)
  + elimination of missing/invalid runtime fallback +
  exact-zero layer-key correction.
- **FIX-B** — exact deterministic survivor provenance union.
- **FIX-C** — strict destructive host-handle liveness hardening.

Explicitly NOT implemented (per dispatch §Hard STOP and §Scope):

- BLOCK-005 discard / Undo recovery redesign;
- Observer architecture;
- Owner verification;
- V1.6;
- product / UX changes;
- topology policy changes;
- source-CAD mutation;
- Codex review.

---

## 2. Preflight

| Item | Value |
|---|---|
| `git branch --show-current` | `dev/v1.5` (matches dispatch expected) |
| `git rev-parse HEAD` (before) | `89f62457887d5d5d2b04f8d01f8d1ed27464c37e` |
| `git status --short` (before) | `M Prompt/CURRENT_PI_DISPATCH.md`, `M Review/CURRENT_AIPM_REVIEW.md`, plus untracked AIPM review evidence `.txt` files |
| Untracked files preserved | yes — `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`, `Review/AIPM_V1_5_R5_*.txt`, `Review/V3_4_*.txt` |
| Unexpected tracked production/test/governance modifications | none |
| `git remote -v` | empty (no remote) |
| Push status | `PUSH NOT POSSIBLE — NO REMOTE` |

The starting point `89f6245` is the V3.4 governance migration HEAD
documented in `CURRENT_AIPM_REVIEW.md` §Evidence basis.

---

## 3. Changed production files

| File | Change | Reason |
|---|---|---|
| `extension/su_ai_plugin/core/duplicate_geometry_semantics.rb` | Added `parse_strict_tolerance`; rewrote `valid_tolerance?` / `tolerance_category` to delegate to it; added `strict_handle_live?`; rewrote `exact_edge_key` to include the normalized layer; rewrote `enumerate_candidates_exact_zero` to pass `t[:layer]` to `exact_edge_key`; rewrote `resolve_captured_tolerance` to use `parse_strict_tolerance`. | FIX-A §2.2/2.3/2.4 + FIX-C. |
| `extension/su_ai_plugin/core/duplicate_repair_proposer.rb` | Rewrote `read_duplicate_tolerance` / `resolve_tolerance` to return nil on missing/invalid (no runtime fallback); rewrote the survivor / removal / member handle-proof sections in `verify_final_repairable_component` to use `strict_handle_live?`; added `REASON_HANDLE_INVALID` for handles that lack `:valid?`. | FIX-A §2.3 + FIX-C. |
| `extension/su_ai_plugin/core/derived_duplicate_topology.rb` | Rewrote `resolve_tolerance` to return nil when no valid explicit or captured value is available (no runtime fallback). | FIX-A §2.3. |
| `extension/su_ai_plugin/core/duplicate_repair_executor.rb` | Rewrote `precompute_expected_post_state` so `captured_tolerance` stays nil on missing/invalid (with `tolerance_valid: false`); rewrote `preflight_batch`, `final_live_handle_proof`, `precommit_host_shape_observation` to use `strict_handle_live?`; rewrote the per-action pre-computation in `apply_batch_atomic` to classify via `strict_handle_live?`; rewrote `apply` / `apply_atomic` / `precompute_survivor_replacements` accordingly; preserved the "all_gone" shortcut semantics as "handle.nil?" only. | FIX-A §2.3 + FIX-C. |
| `extension/su_ai_plugin/core/duplicate_repair_expected_post_state.rb` | Added `'survivor_provenance_unions_from_pre_state'` field computed from authoritative pre-state records; added invariant checks in `validate!` for exact union match + key-set equality (with stable reason codes `survivor_provenance_union_mismatch`, `survivor_provenance_union_key_mismatch`, `survivor_provenance_union_missing_in_action`, `survivor_provenance_union_from_pre_state_empty`). | FIX-B §3.2/3.3. |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | Rewrote the `before_pairs` / `after_pairs` computation in `build_duplicate_repair_summary` to remove the silent `read_duplicate_tolerance` fallback; added a new `tolerance_status` field (`missing_captured_tolerance` / `invalid_captured_tolerance` / `captured`) so the UI can render the honest answer when no pair metric is available. | FIX-A §2.3 (audit path). |

No other production files were modified.

---

## 4. Changed test files

| File | Change | Reason |
|---|---|---|
| `tests/test_v15_round5_block_fix.rb` | Updated `V15-B003-INV-I` test to also populate the new `survivor_provenance_unions_from_pre_state` field (the phantom survivor's pre-state record must agree with its claimed union so the test still reaches invariant I). Added **32 new focused regressions** in 6 groups: FIX-A strict tolerance parsing (11), FIX-A exact-zero layer-key correction (4), FIX-A no-fallback production-path regressions (5), FIX-B exact provenance union invariants + executor-level mismatch (7), FIX-C strict handle liveness (5). | dispatch §6 Required regressions. |

---

## 5. AIPM finding -> implementation -> regression mapping

| AIPM finding (per `CURRENT_AIPM_REVIEW.md`) | Implementation site | Regressions |
|---|---|---|
| BLOCK-002A / BLOCK-004 tolerance fail-closed: permissive `.to_f` / runtime default fallback / exact-zero key/layer inconsistency. | `duplicate_geometry_semantics.rb#parse_strict_tolerance`, `#valid_tolerance?`, `#tolerance_category`, `#resolve_captured_tolerance`, `#exact_edge_key`, `#enumerate_candidates_exact_zero`; `duplicate_repair_proposer.rb#read_duplicate_tolerance`, `#resolve_tolerance`; `derived_duplicate_topology.rb#resolve_tolerance`; `duplicate_repair_executor.rb#precompute_expected_post_state`, `#preflight_batch`; `working_mode_runner.rb#build_duplicate_repair_summary`. | `V15-FIXA-STR-1..11`, `V15-FIXA-KEY-1..4`, `V15-FIXA-NOFALLBACK-1..5`. |
| BLOCK-003 exact provenance union: validator proves only non-empty provenance; does not prove exact deterministic union from authoritative pre-state members. | `duplicate_repair_expected_post_state.rb#build` (new `'survivor_provenance_unions_from_pre_state'` field computed from `workspace_inventory_pairs`), `#validate!` (new exact-union + key-set invariant checks with stable reason codes). | `V15-FIXB-PR-1..6`, `V15-FIXB-PR-EXEC`. |
| Bounded hardening adjacent to BLOCK-001: handle that lacks `:valid?` / returns nil from `:valid?` / raises during `:valid?` must NOT be treated as live. | `duplicate_geometry_semantics.rb#strict_handle_live?`; `duplicate_repair_proposer.rb#verify_final_repairable_component`; `duplicate_repair_executor.rb#preflight_batch`, `#final_live_handle_proof`, `#precommit_host_shape_observation`, `#apply_batch_atomic` per-action pre-computation, `#apply`, `#apply_atomic`, `#precompute_survivor_replacements`. | `V15-FIXC-HDL-1..5`. |
| BLOCK-005 discard / Undo / host-change reconciliation | explicitly NOT implemented (AIPM design gap, deferred to separate AIPM research per dispatch §5). | n/a — BLOCK-005 remains OPEN. |

---

## 6. Exact tolerance / fallback search result

Per dispatch §2.3 the search target was every live use of:

- `DEFAULT_TOLERANCE`
- `DEFAULT_DUPLICATE_TOLERANCE`
- `.to_f`
around duplicate tolerance resolution in production code.

| File | Line | Symbol | Before | After |
|---|---|---|---|---|
| `duplicate_geometry_semantics.rb` | 36 | `DEFAULT_TOLERANCE = 1.0e-4` | constant present | constant retained for unrelated default-config creation; NOT a runtime fallback (used only by `tolerance.rb` `Tolerance.default`). |
| `duplicate_geometry_semantics.rb` | old `valid_tolerance?` | `.to_f` on String + `.respond_to?(:finite?) && ...` | permissive: `"abc".to_f == 0.0` -> valid exact-zero. | replaced with `parse_strict_tolerance` (strict `Float(s)` for Strings; `f.finite? && f >= 0` for Numerics). |
| `duplicate_geometry_semantics.rb` | old `tolerance_category` | `.to_f` | same permissive coercion. | replaced with `parse_strict_tolerance`. |
| `duplicate_geometry_semantics.rb` | old `resolve_captured_tolerance` | `v.to_f` | permissive. | `parse_strict_tolerance(v)`. |
| `duplicate_repair_proposer.rb` | `read_duplicate_tolerance` | `DEFAULT_DUPLICATE_TOLERANCE` returns on missing | runtime fallback. | returns nil on missing/invalid; caller MUST treat nil as "no V1.5 auto-repair". |
| `duplicate_repair_proposer.rb` | `resolve_tolerance` | `DEFAULT_DUPLICATE_TOLERANCE` last-resort | runtime fallback. | returns nil when neither workspace nor snapshot supplies a valid captured value. |
| `duplicate_repair_proposer.rb` | `verify_final_repairable_component` (provenance union) | `DEFAULT_DUPLICATE_TOLERANCE` in `canonical_geometry_key` call | uses default for non-action key normalization. | not a runtime fallback; the default is only used as a quantization grid for a non-action key. Preserved per Guidance §2.3 ("legacy constants may remain only if needed for unrelated default configuration creation"). |
| `derived_duplicate_topology.rb` | `resolve_tolerance` | `DEFAULT_TOLERANCE` last-resort | runtime fallback. | returns nil when no valid explicit or captured value. |
| `duplicate_repair_executor.rb` | `precompute_expected_post_state` | `DEFAULT_DUPLICATE_TOLERANCE` fallback | runtime fallback. | captured_tolerance stays nil; `tolerance_valid: false`; caller fails closed. |
| `duplicate_repair_executor.rb` | `preflight_batch` | (no direct default, but used `tol` from `resolve_captured_tolerance`) | n/a | uses `strict_handle_live?` for every member; returns `valid: false, reason: 'invalid_or_missing_captured_tolerance'` on missing/invalid. |
| `working_mode_runner.rb` | `build_duplicate_repair_summary` (both before_pairs and after_pairs) | fallback to `read_duplicate_tolerance(pre_workspace.source_snapshot)` on invalid captured | silent audit fallback. | no fallback; pair metric reported as `nil` (with explicit `tolerance_status` field) when captured is missing/invalid. |

The exact-zero path is preserved: `tolerance_category(0.0) == :zero`; `enumerate_candidates_exact_zero` is invoked. Captured `0.0` is NEVER substituted by `0.0001` anywhere in the production chain.

---

## 7. Exact provenance invariant evidence

`duplicate_repair_expected_post_state.rb#build` now carries TWO
independent survivor-provenance-union maps:

```text
survivor_provenance_unions                  : <sid> -> <sorted uniq claimed source_occurrence_ids>
survivor_provenance_unions_from_pre_state   : <sid> -> <sorted uniq pre-state record source_occurrence_ids>
```

`validate!` requires:

1. Same keys (sorted): `survivor_provenance_unions.keys.sort ==
   survivor_provenance_unions_from_pre_state.keys.sort`. Mismatch ->
   `survivor_provenance_union_key_mismatch`.
2. For every key, exact equality of the canonical-normalized union:
   `Array(occs).map(&:to_s).uniq.sort`. Mismatch ->
   `survivor_provenance_union_mismatch: <sid>: missing=[...]
   extra=[...]`.
3. Defensive: missing entry in either map ->
   `survivor_provenance_union_missing_in_action: <sid>` or
   `survivor_provenance_union_from_pre_state_empty: <sid>`.

Fingerprint validation (existing invariant E) remains in force;
the two invariants are independent.

The mismatch detection runs INSIDE `validate!`, which is
called from `build(...)` AFTER the per-action membership and
removed/survivor inventory invariants but BEFORE the function
returns the post-state Hash. The executor's `apply_batch_atomic`
only consults `expected_post['valid']` to decide whether to
commit host mutation; a mismatch therefore blocks
`begin_operation`.

`V15-FIXB-PR-EXEC` exercises this end-to-end: a 3-record
fixture has the action's claim (3 occurrences) and the
pre-state records truncated to 2 occurrences; `apply_batch`
reports `begin=0`, `commit=0`, `abort=0`, `dispose=0`,
workspace `:failed` with `survivor_provenance_union_mismatch|
expected_post_state_invalid`, logical pre-state retained,
source immutable.

---

## 8. Handle-liveness evidence

`DuplicateGeometrySemantics.strict_handle_live?(handle)` is the
single source of truth for handle liveness in destructive paths:

| Handle shape | `respond_to?(:valid?)` | `valid?` returns | `strict_handle_live?` |
|---|---|---|---|
| `nil` | n/a | n/a | `false` |
| Object missing `:valid?` (`NoValidPredicateHandle`) | `false` | n/a | `false` |
| Object with `valid?` returning `nil` (`NilValidPredicateHandle`) | `true` | `nil` | `false` |
| Object with `valid?` raising `StandardError` (`RaiseValidPredicateHandle`) | `true` | raises | `false` (caught) |
| Object with `valid?` returning `false` | `true` | `false` | `false` |
| Object with `valid?` returning `true` | `true` | `true` | `true` |

This predicate is wired into:

- `DuplicateRepairProposer#verify_final_repairable_component`
  (per-repairable-component final eligibility proof) ->
  `:skipped` audit row with `REASON_HANDLE_INVALID` /
  `REASON_HANDLE_INVALIDATED`.
- `DuplicateRepairExecutor#preflight_batch` (live-handle proof
  re-check on every action before `begin_operation`) ->
  `{ valid: false, reason: '*_handle_invalidated' /
  '*_handle_malformed_no_valid_predicate' }`.
- `DuplicateRepairExecutor#final_live_handle_proof` (same proof
  re-run IMMEDIATELY before `begin_operation`, AFTER expected-
  state validation) -> atomic no-begin failure.
- `DuplicateRepairExecutor#precommit_host_shape_observation`
  (symmetric: survivors still strictly live, planned removals
  no longer strictly live) -> `precommit_*_not_live` /
  `precommit_removal_handle_still_live` /
  `precommit_handle_aliasing` reasons.
- `DuplicateRepairExecutor#apply_batch_atomic` per-action
  pre-computation: every removal handle is classified via
  `strict_handle_live?` into present/invalid (a handle that
  lacks `:valid?` is classified as invalid, NOT present).
- `DuplicateRepairExecutor#apply` / `#apply_atomic` /
  `#precompute_survivor_replacements` use the same predicate.
- The `all_gone` shortcut in `apply_batch` /
  `apply` retains the historical "handle.nil? == gone" semantics
  (an invalidated handle is NOT gone and reaches preflight_batch).

`V15-FIXC-HDL-1..3` exercise the three handle shapes above
end-to-end through `apply_batch` and assert: `begin=0`,
`commit=0`, `abort=0`, `dispose=0`, workspace `:failed`,
stable reason code with `handle_invalidated|malformed_no_valid_predicate|final_live_handle_proof_failed|preflight_failed`,
exact logical pre-state retained.

`V15-FIXC-HDL-5` is the sanity guard: a normal workspace with
all-valid handles still produces 1 applied action and a
`:ready` workspace.

---

## 9. Focused test results

Run command:

```bash
.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe tests/run_all.rb 'FIX'
```

Result:

```text
--- 32 tests: 32 pass, 0 fail, 0 error ---
```

Per test group:

- FIX-A strict tolerance parser units (11/11 PASS):
  `V15-FIXA-STR-1..11`.
- FIX-A exact-zero layer-key correction (4/4 PASS):
  `V15-FIXA-KEY-1..4`.
- FIX-A no-fallback production-path regressions (5/5 PASS):
  `V15-FIXA-NOFALLBACK-1..5`.
- FIX-B exact provenance union invariants (7/7 PASS):
  `V15-FIXB-PR-1..6`, `V15-FIXB-PR-EXEC`.
- FIX-C strict handle liveness (5/5 PASS):
  `V15-FIXC-HDL-1..5`.

---

## 10. Full test results

Run commands:

```bash
.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe tests/run_all.rb 'V15'
.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe tests/run_all.rb
```

Results:

| Suite | Result |
|---|---|
| Round-5 corrective focused regressions | 32/32 PASS (added in this update) |
| Existing Round-5 continuation evidence | 99/99 PASS (unchanged) |
| Full V15 (existing + new) | **131/131 PASS** |
| Full Ruby suite | **795/795 PASS** |
| RBZ smoke | 9/9 PASS (post-rebuild) |
| Node DOM (`html_render`) | 58/58 PASS |
| `git diff --check` | clean |

Implementation / test evidence only.

Do not by themselves close the AIPM BLOCK on BLOCK-005, prove
real-host behavior, or substitute for Owner verification.

---

## 11. RBZ evidence

Path:

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

| Property | Value |
|---|---|
| Size | 637,621 bytes |
| Entries | 59 |
| SHA-256 | `90C49AF2E95452C5DAB22D1ABCE5858B1ABC53F5753B7588ED30728F56ACECEB` |
| Previous Round-5 continuation SHA | `C10D550352D0733850A6A45C441B56F25E490426B870459F16149B5CDB515C35` |

Production source is changed in this dispatch (5 files), so the
RBZ hash is NEW. Build command:

```bash
.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe scripts/build_rbz.rb
```

Build output:

```text
OK: wrote D:/Projects/SU-AI-Plugin/dist/SU-AI-Plugin.rbz
    size: 637621 bytes
    entries: 59
    entry-point: su_ai_plugin.rb (OK, at the .rbz root)
    support folder: su_ai_plugin/ (OK, sibling of the entry-point)
```

This RBZ is **not approved for Owner installation** until the
AIPM Owner verification file is republished AND (if AIPM
chooses) the next Codex narrow xHigh recheck passes.

---

## 12. Known open BLOCK-005 statement

BLOCK-005 (discard -> SketchUp Undo -> next plugin interaction
host-state reconciliation) is **deliberately OPEN** at the end
of this dispatch.

Per AIPM Source Review verdict and the dispatch §5:

- AIPM classified BLOCK-005 as an AIPM technical-design gap,
  not a Pi implementation-choice gap.
- The current production-path observation seam (handle.valid?
  on the next normal interaction) is acceptable for V1.5 but
  is NOT sufficient to formally prove the discard -> Undo ->
  reconcile scenario end-to-end.
- AIPM will perform targeted research (SketchUp official API,
  2–4 mature open-source SketchUp extensions, Undo/Redo /
  ModelObserver / EntitiesObserver patterns, entity lifecycle /
  persistent identity, license constraints) before freezing the
  recovery fix.
- Pi must NOT invent a new Observer / Undo / persistent-scanning
  architecture in this dispatch or any successor dispatch.
- BLOCK-005 remains OPEN in the active V1.5 BLOCK set.

---

## 13. Unresolved issues

- BLOCK-005 still OPEN (deliberate, per dispatch §5; AIPM design
  gap, not Pi implementation gap).
- The V1.5 active BLOCK set remains NOT formally closed
  pending AIPM direct source re-review of this corrective
  packet + Owner-checklist republish + (if AIPM chooses)
  the next Codex narrow xHigh recheck.
- V1.6 is NOT STARTED; requires a new AIPM Stage Technical
  Blueprint before any implementation begins.
- Owner verification is BLOCKED pending AIPM Owner-checklist
  republication.
- Real-host (SketchUp 2017/2020/2024) verification remains
  required before V1.5 can be formally closed; not yet
  attempted.
- No remote configured; final stable commit is local-only.

---

## 14. Final stable commit

| Item | Value |
|---|---|
| Implementation commit | `874149dc7488ff8c844e16fb6e0e6013df9abfa6` |
| SHA-stamp commit 1 | `b868cf4bad78bff2e3510481368e838e1459320c` |
| SHA-stamp commit 2 (final acceptance) | `b9e1965` |
| Final stable commit (HEAD) | `b9e1965` (local-only on `dev/v1.5`) |
| Push status | `PUSH NOT POSSIBLE — NO REMOTE` |
| `git status --short` (after stable commit + SHA stamp) | untracked: 7 AIPM review evidence `.txt` files preserved per dispatch §Preflight |
| `git diff --check` | clean |

---

## 15. Hard STOP

Per dispatch §Hard STOP:

> After all assigned FIX-A/B/C work and evidence are complete:
> STOP. Do not: continue into BLOCK-005; run/request Codex;
> ask Owner for verification; start V1.6; select another task.
> Return control to AIPM for real source review.

STOP is in effect. Control returns to AIPM for direct source
re-review of the Round-5 Source Review corrective packet.

---

# One-Line Round-5 Source Review Corrective Pi Report

**V1.5 Round-5 AIPM Source Review corrective packet is complete
within the frozen
`Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`:
FIX-A strict tolerance parsing + exact-zero layer-key
correction, FIX-B exact deterministic provenance union, FIX-C
strict destructive handle liveness hardening, all implemented
with no silent `0.0001` fallback and no broad architecture
refactor; 32 new focused regressions added (FIX-A 20, FIX-B 7,
FIX-C 5); full V15 131/131 PASS, full Ruby 795/795 PASS, RBZ
smoke 9/9 PASS, Node DOM 58/58 PASS, `git diff --check` clean;
RBZ rebuilt with SHA-256
`90C49AF2E95452C5DAB22D1ABCE5858B1ABC53F5753B7588ED30728F56ACECEB`;
BLOCK-005 remains OPEN by design; Pi STOPPED; final stable
commit local-only (`PUSH NOT POSSIBLE — NO REMOTE`).**
