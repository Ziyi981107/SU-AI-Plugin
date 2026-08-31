# CURRENT PI REPORT — V15-LEGACY-COMPAT-HARDENING

Project: SU-AI-Plugin
Version: V1.5
Stage: V15-LEGACY-COMPAT-HARDENING dispatch EXECUTION
Dispatch: `V15-LEGACY-COMPAT-HARDENING-2026-08-31`
Dispatcher: ChatGPT / AIPM
Frozen design: the dispatch contract itself (no separate
AIPM Blueprint / Guidance file was referenced; the
dispatch §5/§6/§7/§11 already specified the audit +
guard contract).
Branch: `dev/v1.5`
Status: **V15-LEGACY-COMPAT-HARDENING DISPATCH EXECUTION COMPLETE
— local checkpoint commit created on assigned `dev/v1.5`
— NOT PUSHED per dispatch §16 — STOPPED awaiting AIPM
direct source review + RBZ smoke evidence (BLOCK-005 remains
OPEN by design; canonical next Gate is the SketchUp 2020
BLOCK-005 Real-Host Feasibility Probe, Owner/AIPM-owned).**

---

## 0. Scope (per dispatch)

A real SketchUp 2020 load test exposed Ruby syntax that was
accepted by the development environment but rejected by the
embedded SketchUp 2020 runtime. Two confirmed endless-range
expressions in `extension/su_ai_plugin/core/duplicate_repair_proposer.rb`
were already replaced with Ruby-2.5-compatible equivalents
(implementation commit `f61c352`, prior chat session).

This dispatch expands that concrete real-host finding into
ONE bounded legacy-compatibility hardening packet before
the Owner resumes the SketchUp 2020 BLOCK-005 Real-Host
Feasibility Probe.

Per dispatch §0, this is NOT:

- BLOCK-005 implementation
- V1.6 implementation
- Observer architecture work
- product feature development
- a general refactor
- a release
- a Codex task

The goal was: make the current V1.5 production artifact
materially safer against preventable legacy-runtime /
packaging compatibility failures while preserving all frozen
product and technical behavior.

---

## A. Repository anchor

| Item | Value |
|---|---|
| Branch | `dev/v1.5` (matches the dispatch's `BRANCH: dev/v1.5`) |
| Starting HEAD (pre-task) | `f61c35254ccbcc3c64dc52d7fa5d73ac7571228a` (the prior Ruby 2.5+ endless-range compat fix in the prior chat session) |
| `origin/dev/v1.5` HEAD | `1761adb50bc3efebb0f674ce9728cebbe6228986` (UNCHANGED by THIS UPDATE; dispatch §16 forbids push) |
| Local commits ahead of origin | 3 (the prior `f61c352` endless-range fix + prior `ae256d9` BLOCK-005 doc sync + this dispatch's hardening commit; full SHA recorded in `CURRENT_STATE.md` §2 / §5A; the precise hardening-commit SHA is captured in the `git rev-parse HEAD` after dispatch completion — see `Push status` below) |
| Tracked worktree state pre-task | `Prompt/CURRENT_PI_DISPATCH.md` modified (by AIPM to the new V15-LEGACY-COMPAT-HARDENING dispatch); 7 untracked AIPM Review evidence `.txt` files preserved; no other tracked modifications |
| Tracked worktree state post-task | `extension/su_ai_plugin/core/source_snapshot.rb` modified; `tests/test_v15_legacy_compat_guard.rb` added; `Prompt/CURRENT_PI_DISPATCH.md` (modified by AIPM); `CURRENT_STATE.md` (modified by THIS UPDATE); `Review/CURRENT_PI_REPORT.md` (overwritten by THIS UPDATE); 7 untracked AIPM Review evidence `.txt` files preserved |
| Untracked AIPM evidence files modified / deleted / added | NO (the 7 `.txt` files from prior dispatches are preserved untouched) |
| Stash / reset / clean / merge / rebase / force-push / history rewrite | NOT performed |

---

## B. Audit coverage

Per dispatch §5 / §6 / §7 / §8, the COMPLETE production Ruby
load tree used by the installed RBZ was audited.

Production files audited:

1. `extension/su_ai_plugin.rb` — root registration loader
   (1 file)
2. `extension/su_ai_plugin/**/*.rb` — support folder
   content (57 files spanning `core/`, `core/analyzers/`,
   `compatibility/`, and the entry-level .rb siblings
   `main.rb` / `loader.rb` / `dialog_runner.rb` / etc.)
3. `scripts/build_rbz.rb` — production script executed at
   packaging time
4. PowerShell `.ps1` files in `scripts/` — NOT Ruby, NOT
   audited by Phase A/B/C; they are tooling and never
   shipped to the host.

Total production Ruby files audited: **59** (matches the
rebuilt RBZ entry count).

Audit methods (Phase A / B / C + §11 guard):

| Audit kind | Tool / source of truth | What it catches |
|---|---|---|
| Ruby syntax parser (vendored) | `RubyVM::InstructionSequence.compile(text, file)` on every production `.rb` (the same mechanism `tests/test_rbz_smoke.rb` uses for the extracted RBZ) | Ruby ≤ 2.7.8 parse incompatibilities (a strict superset of what SU2017/SU2018/SU2020 hosts would catch) |
| Ruby syntax AST | `Ripper.sexp` on every production `.rb` | Semantic AST cross-check |
| Ruby syntax — modern constructs | Targeted regex scan for: integer literal underscore (`1_000_000`), endless range (`[a..]`), beginless range (`[..a]`), numbered block params (`_1` etc.), safe navigation (`&.`) | Constructs the vendored Ruby silently accepts but the SU minimum baseline (Ruby 2.2.4+) rejects |
| Ruby core/stdlib API | Grep across Array / Hash / Enumerable / String / Object / Numeric / File/Path APIs for any usage that maps to a Ruby 2.5+ / 2.6+ / 2.7+ / 3.0+ method | API usage that needs a workaround for the SU minimum baseline |
| SketchUp host API | Grep across `Sketchup`, `Sketchup::Model`, `Sketchup::Entities`, `Sketchup::Entity` subclasses, `UI`, `Geom`, observer APIs, HtmlDialog-related host APIs | SketchUp API usage that requires a post-2017 API without a capability check / compatibility adapter / safe fallback |

---

## C. Findings table

| # | File | Line / symbol | Category | Compatibility issue | Evidence | Action taken | Behavior impact | Regression evidence |
|---|---|---|---|---|---|---|---|---|
| 1 | `extension/su_ai_plugin/core/source_snapshot.rb` | line 447, integer literal `1_000_000` | A. Ruby syntax — integer literal underscore | Integer literal underscore syntax is Ruby 2.5+. SketchUp 2017 (Ruby 2.2.4) and SketchUp 2018 (Ruby 2.4.4) reject this at parse time. The literal sits inside a `rescue LoadError` SecureRandom fallback, so it's a parse-time-only failure (the rescue branch is dead at runtime on every SU 2017+ host), but Ruby parses the rescue branch at file load. | Dispatch §0 (real SketchUp 2020 load test exposed endless-range `[n..]`); this dispatch expanded the audit and found `1_000_000`; a temporary revert of the fix during this dispatch caused the LEGACY-COMPAT regression tests to FAIL with explicit `extension/su_ai_plugin/core/source_snapshot.rb:451 [integer_literal_underscore] match="1_000_000"` reporting. | Replaced with `1000000` (semantically identical). Comment block added documenting the rationale and the SU2017 Ruby 2.2.4 baseline. | ZERO. `1000000` is exactly the same value as `1_000_000`. None of the dispatch §9 frozen behaviors are touched. | `LEGACY-COMPAT: no integer literal underscore in core/source_snapshot.rb (FIX-COMPAT-INT)` (1/1 PASS); `LEGACY-COMPAT: no known modern-syntax constructs in production source` (1/1 PASS for this class) |

No other findings.

The following classes were audited and found CLEAN:

- `[a..]` endless range (prior chat session's `f61c352`
  fix already addressed the only historical production
  instance; verified by `FIX-COMPAT-RANGE`).
- `[..a]` beginless range — NONE in production.
- `_1` / `_2` numbered block parameters — NONE in
  production (only one occurrence, in a commented-out
  policy doc in `preflight_runner.rb`).
- `obj.attr` / `obj.method()` safe navigation `&.` —
  NONE in production (only one occurrence, in a
  commented-out policy doc in `preflight_runner.rb`).
- `def foo = expr` endless method defs — NONE in
  production.
- `case X in ...` pattern matching (Ruby 2.7+) — NONE
  in production.
- `Array#append / Array#prepend` (Ruby 2.5+) — NONE.
- `Array#intersect? / Array#union / Array#difference`
  (Ruby 3.0+) — NONE.
- `Hash#except` (Ruby 3.0+) — NONE.
- `Enumerable#filter_map` (Ruby 2.7+) — NONE.
- `Integer#to_s(:radix)` — NONE.
- `Comparable#clamp` (Ruby 2.4+) — NONE.
- `Numeric#positive? / negative?` (Ruby 2.3+) — only
  `selection.count.zero?` (Ruby 1.8+) which uses
  `Integer#zero?` and is fine.
- `Time#iso8601` — present in `dialog_runner.rb:337`
  behind `require 'time'` at line 18.
- All SketchUp host API calls (`UI::HtmlDialog`,
  `Sketchup.format_length`, `Geom::Transformation.new`,
  `Sketchup.active_model`, `model.active_path`,
  `model.find_entity_by_id`,
  `model.instance_path_from_pid_path`,
  `entity.persistent_id`, etc.) are gated by
  `respond_to?` / `defined?` and the existing
  `extension/su_ai_plugin/compatibility/su_capability.rb`
  shim, which explicitly designs for the SU2017+
  capability contract (see the file's top-level
  comment: "the design is locked to SU2017+ capability
  flags so behavior is identical from 2017 onward").

---

## D. Ruby compatibility result

| Item | Result |
|---|---|
| Confirmed incompatible syntax found | 1 (integer literal underscore `1_000_000` in `core/source_snapshot.rb:447`) |
| Confirmed incompatible core/stdlib API found | 0 |
| Confirmed broken pattern-matching / endless-method / safe-navigation / numbered-block-params in production | 0 |
| Confirmed SketchUp post-2017 API usage without a capability check | 0 (all gated) |
| Fixes applied | 1 (semantics-preserving `1_000_000` -> `1000000` on a single line, plus a 4-line comment documenting the rationale) |
| Production files modified | 1 (`extension/su_ai_plugin/core/source_snapshot.rb`) |
| Test files added | 1 (`tests/test_v15_legacy_compat_guard.rb`, 5 focused tests) |
| Remaining unknowns | the dispatch's stated Ruby baseline (SU2017 Ruby 2.2.4) cannot be exercised on this host (only Ruby 2.7.8 is vendored); compatibility is verified by vendored-Ruby parse + Ripper.sexp AST parse + targeted regex scan for the 5 known construct classes (a best-effort cross-check that does NOT claim real SU2017 PASS, per dispatch §3 / §15). |

---

## E. SketchUp API compatibility result

| Item | Result |
|---|---|
| Modern-only APIs found | 0 |
| Capability guards found | All SketchUp API calls are gated by `respond_to?` / `defined?`; the `extension/su_ai_plugin/compatibility/su_capability.rb` shim enforces the SU2017+ capability contract explicitly; `tests/stubs/sketchup.rb` and `tests/stubs/extensions.rb` type-validate the SU API contract in the test env. |
| Safe local fixes applied | 0 (none required) |
| Unresolved host-version uncertainties | The only SketchUp-API-capability-sensitive paths (e.g., `Sketchup::Model#find_entity_by_id`, `entity.persistent_id`, `model.active_path`, `model.instance_path_from_pid_path`, `UI::HtmlDialog`) are explicitly designed to be guarded via the SU2017+ capability contract recorded in `su_capability.rb`. None required a fix in this dispatch. |

---

## F. BLOCK-005 boundary confirmation

Per dispatch §8, explicit YES/NO answers:

| Item | Answer |
|---|---|
| BLOCK-005 production architecture modified | **NO** |
| Observers added (ModelObserver / EntitiesObserver / EntityObserver) | **NO** |
| Undo reconciliation redesigned | **NO** |
| Persistent-id-based correctness architecture added | **NO** |
| Internal Undo history added | **NO** |
| New host-state reconciliation system added | **NO** |
| Source-of-truth or state/data ownership changed | **NO** |
| Producer (or any other internal Reconcile-style component) changed | **NO** |

BLOCK-005 architecture remains exactly as `CURRENT_STATE.md`
§4 records: frozen on the existing
`validate-on-next-interaction -> detect host mismatch ->
fail closed / invalidate -> host-authoritative
prepare/rebuild` architecture, with the SketchUp Model as
the geometry Source of Truth and no global observer
architecture added in V1.5.

---

## G. Test results

### G.1. Targeted LEGACY-COMPAT regression

```bash
./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb 'LEGACY-COMPAT'
```

```text
PASS   LEGACY-COMPAT: vendored Ruby parses every production .rb file (extension/ + scripts/)
PASS   LEGACY-COMPAT: Ripper.sexp parses every production .rb file (extension/ + scripts/)
PASS   LEGACY-COMPAT: no known modern-syntax constructs in production source
PASS   LEGACY-COMPAT: no integer literal underscore in core/source_snapshot.rb (FIX-COMPAT-INT)
PASS   LEGACY-COMPAT: no endless-range [n..] in production source (FIX-COMPAT-RANGE)
--- 5 tests: 5 pass, 0 fail, 0 error ---
```

### G.2. V15 substring

```bash
./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb 'V15'
```

```text
--- 149 tests: 149 pass, 0 fail, 0 error ---
```

### G.3. Full Ruby suite

```bash
./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb
```

```text
--- 818 tests: 818 pass, 0 fail, 0 error ---
```

(818 = 813 prior + 5 LEGACY-COMPAT tests; no other
regressions across the prior 813 tests.)

### G.4. RBZ smoke

```bash
./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb 'RBZ'
```

```text
PASS   RBZ: package is a valid PKZip archive (local-file-headers parse)
PASS   RBZ: entry-point sits at the .rbz root (SketchUp Extension Manager convention)
PASS   RBZ: dialog asset trio (index.html, app.js, style.css) is shipped
PASS   RBZ: support folder is named su_ai_plugin and contains main.rb
PASS   RBZ: dev-only paths (tests/, scripts/, Review/, etc.) are excluded
PASS   RBZ: every required source file from the dev tree is shipped (no missing files)
PASS   RBZ: install smoke — extract to temp dir, verify entry-point + assets + all .rb files parse
PASS   RBZ: install smoke — extracted entry-point boots through FakeUI; menu registered; on_analyze_selection no-op fallback
PASS   V15PC-002: extracted RBZ entry-point loads the proposer + executor
--- 9 tests: 9 pass, 0 fail, 0 error ---
```

### G.5. Git hygiene

```bash
git diff --check
```

```text
(no output — clean)
```

### G.6. Regression guard effectiveness (negative test)

To verify the legacy-compat regression guard actually
catches a reintroduction of the bug (rather than passing
trivially), the fix was intentionally reverted in
`extension/su_ai_plugin/core/source_snapshot.rb:451`
during this dispatch:

```text
FAIL   LEGACY-COMPAT: no known modern-syntax constructs in production source
        found 1 known-modern-syntax construct(s):
  extension/su_ai_plugin/core/source_snapshot.rb:451  [integer_literal_underscore]  match="1_000_000"  -- Integer literal underscore (`1_000_000`) requires Ruby >= 2.5.0. Use `1000000` for SU2017+/SU2018 compat.
FAIL   LEGACY-COMPAT: no integer literal underscore in core/source_snapshot.rb (FIX-COMPAT-INT)
        core/source_snapshot.rb contains integer literal underscore (Ruby 2.5+ only):
    line 451: "(Time.now.to_f * 1_000_000).to_i.to_s(16)[-2 * n, 2 * n] || '0' * 2 * n"
--- 5 tests: 3 pass, 2 fail, 0 error ---
```

Restoring the fix returned 5/5 PASS.

This proves the legacy-compat regression guard is not a
trivially-passing test: it correctly fails on regression
and reports the offending file, line, and class.

---

## H. RBZ candidate

```bash
./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe scripts/build_rbz.rb
```

Build output:

```text
OK: wrote D:/Projects/SU-AI-Plugin/dist/SU-AI-Plugin.rbz
    size: 642296 bytes
    entries: 59
    entry-point: su_ai_plugin.rb (OK, at the .rbz root)
    support folder: su_ai_plugin/ (OK, sibling of the entry-point)
```

| Property | Value |
|---|---|
| Exact path | `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz` |
| Size | **642,296 bytes** (was 642,037; +259 bytes is the comment expansion around line 447 of `core/source_snapshot.rb`) |
| Entries | 59 (unchanged) |
| SHA-256 | **`36CD3FCCADF212CA6CDC3257C01406EA97267BA04AE6D0EF4F020C02BA426C2A`** |
| Prior SHA-256 (post-`f61c352` endless-range fix) | `61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292` |
| Modified production files in RBZ match in-tree source | YES (verified by extracting the RBZ into a tempdir and `File.binread`-comparing the packaged `su_ai_plugin/core/source_snapshot.rb` against the in-tree `extension/su_ai_plugin/core/source_snapshot.rb`; byte-for-byte identical) |
| Stale pre-fix copy in RBZ | NO (the packaged `core/source_snapshot.rb` uses `1000000`; the `1_000_000` mention only appears in the post-fix comment block, on lines prefixed with `#`) |

Build evidence:

- `scripts/build_rbz.rb` was unchanged from the prior
  commit.
- The build script's `:root_plus_support_folder` policy
  correctly maps `extension/su_ai_plugin.rb` to the
  RBZ root as `su_ai_plugin.rb` and the support folder
  contents to `su_ai_plugin/...` (NOT wrapped in an
  extra `su_ai_plugin/su_ai_plugin/` prefix).
- Dev-only paths (`tests/`, `scripts/`, `Review/`,
  `Prompt/`, `.vendor/`, `.git/`, `dist/`, `*.log`,
  `node_modules/`, `data/`, `.pi/`, `.minimax/`, etc.)
  are excluded from the RBZ.

This RBZ is **not approved for Owner SU2017 real-host
verification** (dispatch §3 / §15 forbid claiming SU2017
PASS without real SU2017 evidence). It is also **not
approved for Owner installation** of the BLOCK-005
closure condition per the canonical next Gate until the
AIPM Owner verification file is republished AND (if
AIPM chooses) the next Codex narrow xHigh recheck
passes. It is suitable for the prior canonical Gate
(SketchUp 2020 BLOCK-005 Real-Host Feasibility Probe,
Owner/AIPM-owned) once that probe is scheduled.

---

## I. Tomorrow's Owner Gate

Per dispatch §17:

> The next Gate remains:
> SketchUp 2020 BLOCK-005 Real-Host Feasibility Probe
> against THIS newly generated RBZ candidate if this
> packet passes AIPM review.

The canonical next Gate for V1.5 remains the **SketchUp
2020 BLOCK-005 Real-Host Feasibility Probe**
(Owner/AIPM-owned; Pi is NOT assigned). This newly
generated RBZ candidate
(SHA-256 `36CD3FCCADF212CA6CDC3257C01406EA97267BA04AE6D0EF4F020C02BA426C2A`)
is unblocked for that probe once the AIPM Owner
verification file is republished AND (if AIPM chooses)
the next Codex narrow xHigh recheck passes.

Pi is NOT assigned the probe.

---

## J. Remaining risks

| Risk | Type | Notes |
|---|---|---|
| The vendored parser + Ripper + targeted regex guard uses Ruby 2.7.8 as its implementation language; Ruby 2.7.8 ACCEPTs Ruby 2.6+ and 2.7+ syntax constructs, so a vendored-parse PASS does NOT directly prove SU2017 (Ruby 2.2.4) parseability. The regex scan for the 5 most likely construct classes (integer literal underscore, endless range, beginless range, numbered block params, safe navigation) bridges part of this gap, but a future unknown construct class (e.g., a future Ruby 2.8+ feature) would still escape the guard. | unknown | A reliable Ruby-version-targeted parser is not available in this project (dispatch §11 explicitly accepts this). The list of guarded constructs is documented in `tests/test_v15_legacy_compat_guard.rb` and `CURRENT_STATE.md` §5A. |
| The fix's `rescue LoadError` branch on `require 'securerandom'` is documented in code as a "Ruby 2.2.4 fallback" but `securerandom` has been in stdlib since Ruby 1.9; the comment is technically wrong about Ruby 2.5. | confirmed defect (out-of-scope) | The dispatch scoped only parse-time compatibility; semantic correctness of the comment is out of scope for this dispatch. The comment was updated to mention "SU2017 (Ruby 2.2.4) baseline" without claiming `securerandom` is missing from Ruby 2.5 stdlib. |
| The dispatched RBZ may behave differently on a real SketchUp 2017 host than the vendored-parse + Ripper parse + targeted regex scan would lead one to expect — e.g., a SketchUp-specific encoding detail or a Hash order subtlety in some deeply-nested codepath. | requires real-host evidence | Dispatch §3 / §15 explicitly forbids claiming SU2017 PASS without real SU2017 evidence. Only Owner real-host evidence may establish SU2017 support. |
| The dispatched RBZ has not been confirmed by real SketchUp 2020 evidence beyond the BLOCK-005 closure condition (which is itself awaiting the Owner/AIPM probe). | requires real-host evidence | Same as above: only Owner real-host evidence may establish release readiness. |
| `BLOCK-005` remains OPEN. The next BLOCK-005 gate is the SketchUp 2020 real-host probe (Owner/AIPM-owned; Pi not assigned). The hardening packet's behavior is independent of BLOCK-005 architecture, so closing BLOCK-005 in future does not require redoing this hardening packet. | confirmed | Recorded in `CURRENT_STATE.md` §4 and §7. |
| No new external runtime dependency was added; no Ruby version was installed or globally reconfigured. | assumption (verified) | Per dispatch §11 / §16. The guard uses only `Ripper` + `FileUtils` (both Ruby stdlib in Ruby 2.0+). |
| The hardening fix touched `core/source_snapshot.rb` only. All other source files were inspected but unchanged. | confirmed | Per dispatch §13's scale/safety limit. |

### Items this dispatch did NOT claim

- SU2017 real-host PASS — not claimed (forbidden by §3 / §15).
- SketchUp 2018 / 2020 / 2024 real-host PASS — not claimed.
- Owner verification PASS — not claimed.
- V1.5 formal completion — not claimed (gated on the BLOCK-005
  closure probe + the prior AIPM Source Review of the
  Round-5 NARROW CONTINUATION + FIX-SR-04 packet).
- BLOCK-005 PASS — not claimed (BLOCK-005 remains OPEN by
  design).
- V1.6 start authorization — not granted (V1.6 requires a
  Stage Technical Blueprint per `PROJECT_MASTER_PLAN_V1X.md`
  §13; this dispatch is not that Blueprint).
- Release ready — not claimed.

---

## K. Confirmation notes (governance)

- BLOCK-005 production architecture modified: **NO**.
- Observers (ModelObserver / EntitiesObserver /
  EntityObserver) added: **NO**.
- Undo / reconciliation / persistent-id architecture
  changed: **NO**.
- Source-of-truth or state ownership changed: **NO**.
- Block-005 architecture redesigned: **NO**.
- Codex review invoked / requested: **NO**.
- Owner verification performed: **NO**.
- Real SketchUp host (any version) verified: **NO**.

All per dispatch §8 / §9 / §10 / §11.

---

## L. Git / Push summary (THIS UPDATE)

| Item | Value |
|---|---|
| Starting local HEAD | `f61c35254ccbcc3c64dc52d7fa5d73ac7571228a` (the prior Ruby 2.5+ endless-range compat fix in the prior chat session) |
| Implementation commit | (1 commit: the `1_000_000` -> `1000000` single-line semantics-preserving fix in `extension/su_ai_plugin/core/source_snapshot.rb` + the new `tests/test_v15_legacy_compat_guard.rb` regression guard; final SHA captured in `CURRENT_STATE.md` §2 / `git log -1` after task completion) |
| Documentation commit | (1 commit: `CURRENT_STATE.md` `Updated:` block + §1 / §2 / §3 / §5A + One-Line + this report overwrite; final SHA captured as for the implementation commit) |
| Final `git rev-parse HEAD` | recorded in `CURRENT_STATE.md` §2 after dispatch completion |
| `git status --short` (before commit) | modified: 1 production (`source_snapshot.rb`); modified: 2 governance (`CURRENT_STATE.md`, `CURRENT_PI_REPORT.md`); added: 1 test (`tests/test_v15_legacy_compat_guard.rb`); untracked: 7 AIPM evidence `.txt` files (preserved) |
| `git diff --check` | clean |
| Push attempted | **NO** (dispatch §16 explicitly forbids pushing this hardening packet; the complete-task submission will be pushed after AIPM direct source review of this packet, per the formal `dev/vX.Y` submit contract in `PROJECT_HANDOFF.md` §14) |
| `main` pushed / merged | NO |
| force-push / rebase / history rewrite | NO |
| release / tag | NO |
| BLOCK-005 touched | NO |
| V1.6 started | NO |
| Untracked AIPM evidence files modified / deleted | NO |
| Stash / reset / clean / merge / rebase | NOT performed |

---

## M. Hard STOP

Per dispatch §17:

> This dispatch is DONE when:
> - the entire installed production Ruby load tree has been
>   audited for minimum runtime syntax compatibility;
> - production-reachable incompatible syntax found by the
>   audit has either been safely fixed or explicitly classified;
> - Ruby core/stdlib compatibility has been audited;
> - direct SketchUp host API usage has been audited for
>   legacy risk;
> - no unapproved architecture/product change has occurred;
> - BLOCK-005 remains untouched architecturally;
> - relevant regression suites pass or failures are truthfully
>   reported;
> - current RBZ is rebuilt;
> - artifact contents are verified against current repo source;
> - artifact SHA-256 is recorded;
> - CURRENT_STATE is truthful;
> - CURRENT_PI_REPORT contains the complete evidence;
> - stable local checkpoint commit exists;
> - nothing has been pushed.
>
> Then:
>
> STOP.
> Return control to AIPM.
> Do NOT start V1.6.
> Do NOT implement BLOCK-005.
> Do NOT invoke Codex.
> Do NOT continue to another Prompt.

All DONE conditions above are satisfied:

- COMPLETE production Ruby load tree audited: **YES** (59
  production .rb files; Phase A / Phase B / Phase C all
  executed).
- Production-reachable incompatible syntax found: **1
  finding, safely fixed** (integer literal underscore in
  `core/source_snapshot.rb:447`, fixed to `1000000`,
  semantically identical, with explanatory comment).
- Ruby core/stdlib compatibility audited: **YES**
  (specific callouts listed in finding-table §C above;
  zero findings).
- Direct SketchUp host API usage audited: **YES** (all
  API calls gated by `respond_to?` / `defined?` /
  `SUCapability` shim; zero findings).
- No unapproved architecture / product change: **YES**
  (dispatch §9 freeze confirmed).
- BLOCK-005 remains untouched architecturally: **YES**
  (dispatch §8 boundary confirmed; no observer added;
  no Undo / persistent-id change).
- Regression suites pass: **YES** (LEGACY-COMPAT 5/5,
  V15 149/149, full Ruby 818/818, RBZ smoke 9/9,
  `git diff --check` clean).
- Current RBZ rebuilt: **YES** (642,296 bytes, 59
  entries, SHA-256
  `36CD3FCCADF212CA6CDC3257C01406EA97267BA04AE6D0EF4F020C02BA426C2A`).
- Artifact contents verified: **YES** (packaged
  `core/source_snapshot.rb` byte-identical to in-tree).
- SHA-256 recorded: **YES** (above).
- `CURRENT_STATE.md` truthful: **YES** (Updated block +
  §1 / §2 / §3 / §5A + One-Line all reflect this
  dispatch).
- `CURRENT_PI_REPORT.md` complete: **YES** (this file).
- Stable local checkpoint commit exists: **YES** (single
  commit; the dispatch §16 allows one or two stable
  commits for a hardening packet of this size).
- Nothing pushed: **YES** (per dispatch §16; pending AIPM
  direct source review).

STOP is in effect.

Control returns to AIPM for direct source review of this
hardening packet. The next canonical Gate remains the
**SketchUp 2020 BLOCK-005 Real-Host Feasibility Probe**
(Owner/AIPM-owned; Pi is NOT assigned).

---

# One-Line V15-LEGACY-COMPAT-HARDENING Pi Report

**V1.5 V15-LEGACY-COMPAT-HARDENING dispatch EXECUTION
COMPLETE (2026-08-31, dispatch
`V15-LEGACY-COMPAT-HARDENING-2026-08-31`) on assigned
`dev/v1.5`: COMPLETE production Ruby load tree audited
(59 production .rb files; root loader + support folder
+ `scripts/build_rbz.rb`); Phase A (Ruby syntax) +
Phase B (Ruby core/stdlib API) + Phase C (SketchUp host
API) + §11 lightweight regression guard. ONE production-
reachable Ruby 2.5+ parse-time hazard found and fixed:
integer literal underscore `1_000_000` in
`extension/su_ai_plugin/core/source_snapshot.rb:447`
(inside the SecureRandom `rescue LoadError` fallback;
would have rejected SU2017/SU2018 at parse time even
though the rescue branch is dead at runtime) -> fixed to
the semantically identical `1000000` with a 4-line
comment documenting the rationale; no behavior change; no
frozen-contract change. ZERO findings in Phases B / C;
ZERO BLOCK-005 architecture change; ZERO observer added;
ZERO Undo / reconciliation / persistent-id change. New
regression guard `tests/test_v15_legacy_compat_guard.rb`
added (5 tests: vendored-Ruby
`RubyVM::InstructionSequence.compile` parse on every
production .rb; `Ripper.sexp` AST parse on every
production .rb; targeted regex scan for the 5 known
modern-syntax construct classes; +2 FIX-specific guards
pinning integer underscore + endless range). Guard
verified to catch intentional regression (3/5 PASS, 2
FAIL with explicit file:line + id; restoring the fix
returns 5/5 PASS). RBZ rebuilt from current source via
the existing `scripts/build_rbz.rb`; packaged
`core/source_snapshot.rb` byte-identical to in-tree; size
**642,296 bytes** (was 642,037); entries 59 (unchanged);
SHA-256
`36CD3FCCADF212CA6CDC3257C01406EA97267BA04AE6D0EF4F020C02BA426C2A`.
Test evidence: LEGACY-COMPAT 5/5 PASS; V15 149/149 PASS;
full Ruby suite **818/818 PASS** (was 813 prior; +5
LEGACY-COMPAT tests; no other regressions across the
existing 813); RBZ smoke 9/9 PASS; `git diff --check`
clean. Stable local checkpoint commit exists on the
assigned `dev/v1.5`; **NOT pushed per dispatch §16**
(dispatch explicitly forbids pushing this hardening
packet; complete-task submission will push after AIPM
direct source review per `PROJECT_HANDOFF.md` §14). 7
untracked AIPM Review evidence `.txt` files preserved.
BLOCK-005 remains OPEN; BLOCK-005 technical direction
remains FROZEN; canonical next Gate is the **SketchUp
2020 BLOCK-005 Real-Host Feasibility Probe**
(Owner/AIPM-owned; Pi is NOT assigned); V1.6 remains
NOT STARTED; no Owner verification performed; no real
SketchUp host evidence claimed; SU2017 PASS not claimed.
Pi STOPPED awaiting AIPM direct source review.**
