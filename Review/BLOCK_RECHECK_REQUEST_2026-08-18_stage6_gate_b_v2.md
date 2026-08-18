# BLOCK RECHECK REQUEST v2 — Stage 6 Gate B (BLOCK-002-R2 + BLOCK-006-R2)

### Metadata

| Field | Value |
|---|---|
| Created | 2026-08-18 |
| Stage | 6 Gate B — BLOCK recheck v2 for S6-GATE-B-BLOCK-002-R2 and -006-R2 |
| Source | Prompt/CODEX_REVIEW_019_2026-08-18_STAGE6_GATE_B_BLOCK_RECHECK.txt |
| Fix commit | (this rework; one consolidated pass for the 2 open BLOCKs) |
| Tests | 247/247 PASS (was 244; +3 new tests; 0 regressions) |
| Base | 3117a1f (Round 018 BLOCK-001..006 rework) |

### Scope

Per CodeX Round 019 directive: "One consolidated recheck for
BLOCK-002-R2 and BLOCK-006-R2 only. Do not reopen BLOCK-001, -003,
-004 or -005."

This packet closes only the two remaining BLOCKs. The four already-
closed BLOCKs are NOT reopened; their test coverage is unchanged.

### Test results

Full suite (verbatim):

```
$ .vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb
--- 247 tests: 247 pass, 0 fail, 0 error ---
```

New tests in this rework:

| Test | File | Closes |
|------|------|--------|
| faithful boot — load entrypoint twice, one menu item, handler reaches dialog | tests/test_loader.rb | BLOCK-002-R2 |
| menu command handler is wired AND clicking it reaches the dialog (rewrite) | tests/test_loader.rb | BLOCK-002-R2 |
| boot entrypoint source order: file_loaded is AFTER Boot.boot! | tests/test_loader.rb | BLOCK-002-R2 |
| render outputs per-issue-type counters in locked order (Node.js DOM test) | tests/test_html_render.rb | BLOCK-006-R2 |
| app.js exports ISSUE_TYPE_LABELS for the locked render order | tests/test_html_render.rb | BLOCK-006-R2 |

The Node.js test runs as part of the Ruby run_all (17 inline
assertions; `tests/test_html_render_dom.js`).

### Closure of S6-GATE-B-BLOCK-002-R2

#### Root cause

The Round 018 fix put `file_loaded(...)` BEFORE the boot path. A
transient failure in any `require_relative` would have left the
"loaded" state set, blocking retry in the same session. The Owner
checklist J still manually `load`-ed 22 files including
`extension/loader.rb` (which would bypass the entrypoint and reset
the module-level `@registered` sentinel on each `load`). The
FakeMenu masked the real-host duplicate with a nonstandard
create-or-return.

#### Code fixes

`extension/su_ai_plugin.rb`:

- The boot path is now `SUAnalysis::Boot.boot!` — a single method
  that `require_relative`'s all Gate B deps in safe order and
  calls `Loader.register!` exactly once.
- `file_loaded($__su_ai_plugin_entry_name)` is moved INSIDE the
  success branch, AFTER `Boot.boot!` returns. A transient boot
  failure leaves the loaded state unset, so the next `load` of
  the same file retries from scratch (safe-retry contract).
- If `file_loaded?` is not defined (test env), the boot still
  attempts; failures are logged to STDERR.

`tests/_fake_ui.rb` (FakeMenu#add_submenu):

- Removed the nonstandard create-or-return behavior. `add_submenu`
  now ALWAYS creates a new submenu, mirroring the real
  `Sketchup::Menu` API. Production idempotency relies on
  `file_loaded?` + module-level `@registered` sentinel, NOT on
  this method.

`Review/OWNER_VERIFICATION_STAGE_6.txt` (step J):

- Removed the 22-line manual file list. Step J.1 is now a single
  command: `load 'D:/Projects/SU-AI-Plugin/extension/su_ai_plugin.rb'`.
- Step J.3 IDEMPOTENCY now points to the faithful boot test
  (not UI::Menu introspection in Ruby Console). The real-host
  retry path is `file_unloaded 'SU-AI-Plugin/extension/su_ai_plugin'`
  + re-load the entrypoint — NOT direct `load loader.rb` (which
  bypasses the entrypoint's `file_loaded?` guard).

#### New tests

`tests/test_loader.rb`:

1. "faithful boot — load entrypoint twice, one menu item, handler
   reaches dialog" (NEW):
   - Top-level `file_loaded?` / `file_loaded` / `file_unloaded`
     stubs (defined at file top so the `instance_eval`-based test
     runner sees them).
   - `load extension/su_ai_plugin.rb` twice — first load
     registers one menu item; second load short-circuits via
     `file_loaded?`.
   - Invokes the created command handler through to the dialog
     boundary (FakeUI.state.dialogs.length == 1 after click).
   - `file_unloaded` + sentinel reset + third `load` — the honest
     FakeMenu (no create-or-return) surfaces a SECOND submenu,
     proving the production code relies on `file_loaded?` + sentinel,
     NOT on FakeMenu.find_or_create.
2. "menu command handler is wired AND clicking it reaches the dialog"
   (rewritten):
   - Actually invokes `cmd.call_handler` (not just checks the
     command NAME). Stubs `Sketchup.active_model` so the handler
     drives through to `DialogRunner.show`. Asserts a dialog was
     created.
3. "boot entrypoint exists and uses file_loaded? guard" (assertion
   added):
   - Verifies `file_loaded(` source position is AFTER `Boot.boot!`
     in `extension/su_ai_plugin.rb`.

### Closure of S6-GATE-B-BLOCK-006-R2

#### Root cause

`app.js#render` treated every top-level `summary` value as a scalar.
After rendering `Edges / Vertices / non-zero-Z / Warnings`, it
emitted the nested `summary.issues` Hash as the literal string
"Issues: [object Object]". The locked per-issue-type counters
("Duplicate candidates: 0", "Short edges: 1", ...) required by
Stage 6 plan section 6.7 were never rendered.

#### Code fixes

`extension/html/app.js`:

- `render(payload)` now has TWO phases:
  1. Locked scalar header rows: `Edges / Vertices / Non Zero Z
     Vertices / Warnings` (4 rows, in order, with the
     humanized labels).
  2. Locked per-issue-type counters in canonical order: 7 rows,
     one per `IssueRegistry::CANONICAL_ISSUE_TYPES` entry, with
     humanized labels (`Duplicate Candidates / Short Edges /
     Open Endpoints / Gap Candidates / Significant Non-zero Z /
     Abnormal Large Coordinate / Deep Nesting`).
- The `ISSUE_TYPE_LABELS` array is locked at the top of the IIFE
  and exposed as `ROOT.ISSUE_TYPE_LABELS` for harness
  introspection.
- Missing issue types default to 0 (the locked
  "count-zero-required-categories" contract).
- The renderer NEVER stringifies a nested Hash. The
  `[object Object]` output is impossible by construction.
- The selection label is rendered ONCE in `#selection-info` (not
  duplicated in the summary block).

#### New tests

`tests/test_html_render_dom.js` (NEW): a Node.js executable
render test. Loads `extension/html/app.js` into a mock DOM via
`vm.runInContext`, calls `window.SUAIP.render(payload)`, walks
the rendered children, and asserts:

- 4 scalar header rows present (`Edges: 4`, `Vertices: 5`,
  `Non Zero Z Vertices: 0`, `Warnings: 1`).
- 7 per-issue-type counters present in the canonical order
  (`Duplicate Candidates: 0`, `Short Edges: 1`,
  `Open Endpoints: 0`, `Gap Candidates: 0`,
  `Significant Non-zero Z: 0`, `Abnormal Large Coordinate: 0`,
  `Deep Nesting: 0`).
- No `[object Object]` in any rendered text.
- Order invariant: scalar rows come before per-issue-type rows;
  per-issue-type rows in canonical order.
- 7 `data-issue-type` attributes present, in canonical order.
- `selection-info` carries the locked `"<label> (<type>)"` shape.

`tests/test_html_render.rb`:

1. "render outputs per-issue-type counters in locked order
   (BLOCK-006-R2)" (NEW): spawns Node.js via backticks, asserts
   the JS test prints `PASS`, exit 0, and the BLOCK-006-R2
   critical labels (Short Edges: 1, Duplicate Candidates: 0,
   no [object Object], canonical order, 7 data-issue-type attrs).
2. "app.js exports ISSUE_TYPE_LABELS for the locked render order
   (BLOCK-006-R2)" (NEW): source-text assertion that the
   `ISSUE_TYPE_LABELS` array exists in the canonical order.

### NIT fixes (per CodeX Round 019 NIT)

- This packet uses atx-style `### H2` headings (no `=======`
  underline) so `git diff --check` does not flag a conflict-marker
  pattern in the markdown source. The Round 018 packet's claim
  "git diff --check: PASS" was misleading — the independent
  command reported a conflict-marker pattern on the underline
  lines. The Round 018 packet's diff itself was clean; only the
  claim has been dropped.
- The "menu -> dialog" test was renamed to "menu command handler
  is wired AND clicking it reaches the dialog" and now ACTUALLY
  invokes the handler (not just calls `DialogRunner.show`
  directly). Future packet wording matches what executes.

### Known limitations (per CodeX Round 017 / Cicada 2026-08-18)

- M (stale source behavior) and N (non-mutating end-to-end) are
  Owner-side real-SU verification steps, NOT Adapter tests. They
  require a real SketchUp host. Owner runs them in
  `Review/OWNER_VERIFICATION_STAGE_6.txt` after this recheck PASSES.
- SU2017 minimum-host verification remains a release Gate (per R004).
  Not a Stage 6 blocker.
- The `console diagnostic` promised by CodeX Round 018 NIT (on_locate
  console line) is emitted by `DialogRunner#on_locate` via
  `$stdout.puts("[SU-AI-Plugin] locate_issue: ...")`. Visible in
  Ruby Console.

### Next review

CodeX Round 020 — Gate B BLOCK RECHECK for the 2 closed BLOCKs.
Expected PASS. If BLOCKs come back, fix in another consolidated
pass; do not re-open Gate A scope (already PASS per Round 017) or
the Round 018 closed scope (BLOCK-001, -003, -004, -005, -006).

After Round 020 PASS, Owner runs `Review/OWNER_VERIFICATION_STAGE_6.txt`
J..N on real SketchUp 2020.

### Long-term-autonomy boundary compliance

- Does NOT change R001-R005 product decisions.
- Does NOT expand product scope (no overlay, no repair, no mutation).
- Does NOT push / publish / release.
- Does NOT skip Owner verification.
- Does NOT fake SU2017 as SU2020 evidence.
- Aggregated review per CodeX Round 017 DEBT (one consolidated
  recheck, not per-sub-step).

### Lessons (for project handoff, NOT for CodeX review)

#### Test runner's `instance_eval` vs top-level `self`

Ruby's test runner uses `instance_eval` to execute each test
body. The `self` inside a test is a `Tests::TestCase` instance,
not the main object. `define_singleton_method` at the test level
adds methods to the test case, NOT to `main`/`Object`. The
fix: define top-level stubs at the top of the test FILE (outside
any test). They become private instance methods on `Object`,
callable from anywhere.

#### Markdown underlines trigger `git diff --check`

`git diff --check` flags any line that's exactly `=======`
(7+ equals) because that pattern looks like a git conflict
marker. Markdown setext-style H2 headings (`Title\n======`)
trip the warning. Use atx-style (`## Title`) in formal
packets, or setext-style `---` underlines (3+ dashes is not
flagged).

#### Honest test doubles must mirror real API shape

`FakeMenu#add_submenu` previously returned an existing same-name
submenu. The real `Sketchup::Menu` does not guarantee that
behavior — `add_submenu` always creates a new submenu (or throws
on some versions). The nonstandard create-or-return was hiding
a real duplicate in the production boot path. The fix: make the
fake mirror the real API and prove production idempotency via
`file_loaded?` + module-level sentinel, not via the fake's
accidental find-or-create.
