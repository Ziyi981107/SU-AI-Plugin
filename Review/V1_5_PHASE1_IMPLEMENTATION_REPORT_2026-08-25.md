# V1.5 Phase 1 — Implementation Report (Agent dispatch)

Date: 2026-08-25
Branch: v1.5-high-confidence-auto-repair
Base commit: 92be2cb (V1.4 closeout)
Implementation commits:
  - dbd8cd4: feat(v1.5-phase-1): high-confidence duplicate-edge auto-repair vertical slice
  - a9a88c5: feat(v1.5-phase-1): minimal Working Mode UI summary for duplicate repairs
Vertical slice status: IMPLEMENTATION COMPLETE — Owner Gate pending

## Summary

Implemented the V1.5 Phase 1 vertical slice per
`Review/V1_5_HIGH_CONFIDENCE_AUTO_REPAIR_IMPLEMENTATION_PLAN_2026-08-24.md`
§6 IMPLEMENTATION ORDER. The slice is locked to:
"In the DerivedGeometryWorkspace, auto-apply ONLY exact-duplicate
and reversed-exact-duplicate edge occurrences, with full
provenance, audit, and rollback."

## Files added / modified

Added (pure-Ruby implementation):
- `extension/su_ai_plugin/core/duplicate_repair_proposer.rb` (~280 lines)
  - Reads existing `duplicate_edge_candidate` IssueRegistry evidence
    + SourceSnapshot + DerivedGeometryWorkspace.
  - Emits ONE `:remove_duplicate_edge` RepairAction per source
    occurrence_id that has 2+ derived records (per-occurrence
    deduplication, not per-pair explosion).
  - Validates: exact / reversed-exact endpoint match within
    `tolerance.duplicate`; SAME source occurrence required
    (cross-occurrence duplicates preserved per plan §5 test 7);
    self-match → :skipped; near-but-not-exact → :skipped.
  - Action shape: `action_type = :remove_duplicate_edge`,
    `confidence = 1.0`, `confidence_basis = "exact_endpoint_match_..."`
    or `"reversed_endpoint_match_..."`, `auto_applicable = true`,
    `affected_derived_ids = [non-survivor derived_ids]`.

- `extension/su_ai_plugin/core/duplicate_repair_executor.rb` (~250 lines)
  - Takes a `:validated` RepairAction; applies it to the
    DerivedGeometryWorkspace ONLY (source entities NEVER touched).
  - Survivor = lex-smaller derived_id (deterministic, testable).
  - Atomic dispose via `adapter.begin_operation` /
    `adapter.dispose` / `adapter.end_operation(commit: true|false)`.
  - Mid-action failure → `end_operation(commit: false)` →
    workspace transitions to `:failed` with `last_error`,
    ALL handles preserved (no partial removal).
  - Idempotent: second apply with already-removed
    `affected_derived_ids` → `:skipped`.
  - Invalid / erased handles (valid? == false) → silently
    filtered out, no raise.

- `tests/test_v15_duplicate_repair.rb` (21 new tests)
  - §5 SHOULD REPAIR (3 tests): forward exact, reversed exact,
    three identical.
  - §5 MUST NOT REPAIR (5 tests): short edge preserved, near-
    but-not-exact preserved, provenance-differs preserved,
    self-match skipped, nested-transform preserved.
  - §5 APPLY SAFETY (5 tests): idempotency, rollback,
    discard+rebuild, erased handle, source_fingerprint.
  - Determinism (2 tests): survivor selection is
    deterministic across rebuilds.
  - WorkingModeRunner integration (2 tests): summary
    recording + discard clearing.
  - RepairAction invariants (2 tests): only allowed action
    type; confidence=1.0 requires non-empty basis.
  - Sanity (1 test).

Modified:
- `extension/su_ai_plugin/core/working_mode_runner.rb`
  - Added `record_duplicate_repair_summary` / `clear_duplicate_repair_summary`
    / `duplicate_repair_summary` accessors.
  - Added `stringify_duplicate_repair_summary` private helper.
  - `snapshot` now exposes `duplicate_repair` key in BOTH the
    'none' state (audit trail after Discard) and the active
    workspace state.
  - `discard` clears the summary (post-discard audit resets).
  - `_discard_if_present` clears the summary.

- `extension/su_ai_plugin/html/app.js`
  - `renderWorkingMode` renders a single labelled
    "Duplicate repairs: applied N, skipped M" row when
    `ws.duplicate_repair` is present.
  - textContent only (no innerHTML, no eval).
  - Row carries `data-state="<current state>"` for CSS hook.

- `tests/test_html_render_dom.js`
  - 6 new V15 assertions: ready-state row presence + content
    + data-state + textContent contract; none-state row
    presence; no-row absence; source guard for innerHTML /
    textContent.

## Test evidence

| Suite                       | Before    | After     |
|-----------------------------|-----------|-----------|
| Full Ruby (all)             | 656/656   | 677/677   |
| V1.5 Phase 1 Ruby tests     | (none)    | 21/21     |
| Node DOM (all)              | 148/148   | 154/154   |
| V1.5 Phase 1 Node DOM tests | (none)    | 6/6       |
| RBZ smoke                   | 8/8       | 8/8       |
| git diff --check            | clean     | clean     |

## Final RBZ

Path:    D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz
Size:    479,023 bytes
Entries: 55
SHA256:  (see git diff / build output; new build from HEAD)

## Hard rules (per plan §3 + Pi Task)

- [x] Only `:remove_duplicate_edge` action type emitted.
- [x] `confidence = 1.0` with non-empty `confidence_basis`
      (the constructor rejects `confidence > 0.5` with empty basis).
- [x] `auto_applicable = true` (the rule is strictly deterministic).
- [x] Source entities NEVER touched (executor uses
      `adapter.dispose` on the workspace's PRIVATE handle registry
      only; the handle registry is per-derivative, not per-source).
- [x] source_fingerprint unchanged across successful OR failed apply.
- [x] Repeated apply idempotent (second call :skipped).
- [x] Mid-action failure → atomic rollback (no partial removal).
- [x] Erased / invalid derived entity silently skipped (no raise).
- [x] Discard + rebuild after apply works.
- [x] Same source_occurrence_id required (cross-occurrence
      duplicates preserved per plan §5 test 7).
- [x] Survivor = lex-smaller derived_id (deterministic).
- [x] DO NOT handle short edges, approximate duplicates,
      face duplicates, gap, weld, flatten, AI, MCP, V2.

## Hard limits inherited

- [x] NOT pushed, NOT published, NOT installed, NOT released.
- [x] NOT modified V1.0-V1.4 closed scope (only minimal
      `working_mode_runner.rb` addition to expose the V1.5 metric;
      no behavioral change to existing V1.4 lifecycle).
- [x] NOT entered V1.5 Phase 2 / V1.6 / V1.7 / V1.8 / V1.9.
- [x] NOT asked Owner to re-run V1.4 tests.

## Stop condition

Per the 2026-08-25 Owner dispatch:

> 11. 保持工作树 clean。
> 11. 停在 Owner Gate，等待真实 SketchUp 2020 验证。

This report is dispatched at the Owner Gate. The next
move belongs to Owner: run
`Review/OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-25.txt`
on real SketchUp 2020 and drop a report at
`Prompt/OWNER_REPORT_V1_5_DUPLICATE_REPAIR_2026-08-25.txt`.

## Diff highlights

```
 extension/su_ai_plugin/core/duplicate_repair_proposer.rb   | new (~280 lines)
 extension/su_ai_plugin/core/duplicate_repair_executor.rb   | new (~250 lines)
 extension/su_ai_plugin/core/working_mode_runner.rb          | +44 lines
 extension/su_ai_plugin/html/app.js                         | +36 lines
 tests/test_v15_duplicate_repair.rb                         | new (~620 lines)
 tests/test_html_render_dom.js                              | +76 lines
```