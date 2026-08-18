# BLOCK RECHECK REQUEST — Stage 6 REAL-HOST (Selection normalization + preflight report)

### Metadata

| Field | Value |
|---|---|
| Created | 2026-08-18 |
| Stage | 6 — REAL-HOST BLOCK (Owner-reported on SketchUp 2020) |
| Source | Cicada Owner message (2026-08-18 17:29); per AGENT.md §1b Owner signals problem resolved by writing this packet. |
| Repro | `AnalyzersRunner.run(Sketchup.active_model.selection, model: Sketchup.active_model).summary` returns `{"edges"=>0, ...}` while the control call `PreflightRunner.build_snapshot([$test_group], model: ...).edge_count` returns 4. |
| Fix commits | (this rework; one consolidated pass) |
| Tests | 252/252 PASS (was 247; +5 new tests; 0 regressions) |
| Base | 6c69ee7 (CodeX Round 020 NIT corrections) |

### Root cause

Two related gaps in the Stage 6 analysis path:

1. **Selection not normalized at the boundary** (per CodeX directive).
   The real `Sketchup::Selection` (and any one-shot Selection-like
   enumerable) is not always safe to iterate more than once. The
   preflight walk and the snapshot walk each called
   `selection.each`; on a one-shot source, the second iteration
   yields 0 items. The control case passed an Array (always safe to
   iterate repeatedly), which masked the bug.

2. **Preflight was a Hash, not a PreflightReport** (existing gap
   surfaced by the REAL-HOST repro).
   `extension/analyzers_runner.rb` was passing the `collect_preflight_facts`
   Hash straight through to `AnalysisResult.new(preflight: ...)`.
   `AnalysisResult#summary` uses `safe_attr(@preflight, :edge_count, 0)`;
   a Hash does not respond to `:edge_count`, so the summary always
   returned 0 for `edges` even when the snapshot had 4 edges. The
   OWNER's repro (`.summary` returning `edges: 0`) was the visible
   symptom; the underlying snapshot DID have 4 edges, but the
   summary path could not read them.

### Code fixes

`extension/preflight_runner.rb`:

- New public module function `normalize_selection(input)`:
  - Returns `[]` for nil.
  - Returns `input.dup` for Array.
  - Falls through to `to_ary` (Ruby coercion protocol) and rescues
    on failure.
  - Falls through to manual `each` iteration (rescue on iteration
    failure) and accumulates the result into a fresh Array.
  - Last resort: `[]`.
- `build_snapshot(selection, model: nil)` now calls
  `selection = normalize_selection(selection)` at the very top, so
  every downstream stage (preflight collection, walk, edge-record
  construction) iterates the SAME stable Array.

`extension/analyzers_runner.rb`:

- `run(selection, model: nil)` now normalizes the selection once at
  the boundary and uses the normalized form for:
  - `PreflightRunner.build_snapshot` (which re-normalizes; idempotent
    for Array).
  - `selection_label_for(normalized)`.
  - `classification_label(normalized)`.
- The preflight is now a real `SUAnalysis::Core::PreflightReport`:
  - `preflight = SUAnalysis::Core::PreflightAnalyzer.run(snapshot)`
    replaces the previous `preflight = snapshot.preflight` (which was
    the Hash from `collect_preflight_facts`).
  - This makes `AnalysisResult#summary` able to read `edge_count`,
    `vertex_count`, `non_zero_z_vertex_count`, and `warning_count`
    correctly.

### New tests (BLOCK RECHECK evidence)

`tests/test_preflight_runner.rb`:

A `OneShotEnumerable` mock that mirrors a real SU Selection with
one-shot iteration: it responds to `:each`, `:count`, `:first`,
`:to_a`, `:length`, `:empty?` but clears its items after the FIRST
`.each` call. Subsequent `.each` calls yield nothing. This is the
shape that reproduces the OWNER's repro at the fake-host level.

1. **"OneShotEnumerable with 4-edge Group -> build_snapshot returns 4
   edges"** (NEW) — proves the fix: passing the one-shot source to
   `build_snapshot` returns 4 edges, NOT 0.
2. **"OneShotEnumerable without normalization -> 0 edges (proves the
   fix is required)"** (NEW) — manually invokes
   `collect_preflight_facts` + `walk_selection_world` on the
   one-shot source WITHOUT the normalize-first step. Result: 0
   edges. This documents the broken behavior so future readers know
   WHY the fix exists.
3. **"normalize_selection converts Selection-like to stable Array"**
   (NEW) — verifies the helper produces a stable Array (multiple
   iterations do not affect the original).
4. **"AnalyzersRunner.run with OneShotEnumerable -> 4 edges, not 0"**
   (NEW) — the full pipeline reproduces the OWNER's repro in the
   fake-host environment and returns 4 edges.
5. **"Array input still works (regression on the fix)"** (NEW) —
   the fix MUST NOT break the existing Array path. Control: pass
   the group as a plain Array; verify the same 4-edge result.

### Test results

```
$ .vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb
--- 252 tests: 252 pass, 0 fail, 0 error ---
```

`git diff --check` clean. Ruby 2.2.4 syntax sweep clean on all
production .rb files.

### Recheck evidence required from Owner (real SU 2020)

Per the OWNER's required recheck:

1. In SU2020, select the 4-edge Group through `model.selection`.
2. Menu Analyze selection must show `Edges: 4`, `Vertices: 4`,
   `Warnings: 0`.
3. Then rerun Owner K..N.

If the menu now shows the locked counts, the Gate B Stage 6 path
is fully exercisable on the real host. The Owner should then
proceed to rerun J..N per `Review/OWNER_VERIFICATION_STAGE_6.txt`.

### Long-term-autonomy boundary compliance

- Does NOT change R001-R005 product decisions.
- Does NOT expand product scope (no overlay, no repair, no mutation).
- Does NOT push / publish / release.
- Does NOT skip Owner verification.
- Does NOT fake SU2017 as SU2020 evidence.
- Does NOT change the locked menu / dialog / locate behavior.

### Lessons (for project handoff, NOT for CodeX review)

#### Always normalize Enumerable at the API boundary

Any method that takes "a selection" (or any "an Enumerable of
entities") MUST snapshot to a stable Array at the top. Real-world
Enumerables can have iteration quirks (one-shot, lazy, or
side-effecting). The `Array` `dup` at the boundary is cheap and
removes an entire class of real-host bugs.

#### `safe_attr` on a Hash always returns the default

`AnalysisResult#summary` uses `safe_attr(pf, :edge_count, 0)` which
calls `pf.respond_to?(:edge_count)`. A Hash returns `false` for any
method-name symbol, so `safe_attr` on a Hash returns the default for
EVERY field. The downstream code path was designed for a
PreflightReport (or any object that responds to those methods) — the
Hash was an upstream architecture gap that survived because the
fake-host test happened to pass a Struct, not because the
production path was correct.

#### The fake-host suite is only as strong as its mocks

The existing `FakeSU::Selection` exposes a regular Array
(`respond_to?(:each)`, `count`, `first`, `to_a`, `[]`) and does NOT
have one-shot iteration. A test using `FakeSU::Selection` cannot
surface the real-host bug. The new `OneShotEnumerable` mock
explicitly exhibits the one-shot-iteration behavior to prove the
fix and to catch any regression that re-introduces the
multi-iteration assumption.
