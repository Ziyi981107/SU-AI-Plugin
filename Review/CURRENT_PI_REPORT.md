# CURRENT PI REPORT — V18-OWNER-SU2020-BOOT-BLOCK

Project: `SU-AI-Plugin`
Version: V1.8
Stage: V1.8 base — Polyline / Closed Loop / Region Reconstruction
Dispatch: V1.8 OWNER SU2020 BOOT BLOCK — narrow fix only
Authority: AIPM (AIPM traced Owner Gate report to
`_validate_adjacency_against_edges`)
Baseline HEAD: `436b71a19da6ec09c88a5983d59063c44ae673c1`
(dev/v1.8 V18-FINAL-FOUR-RESIDUALS complete state)
Target branch: `dev/v1.8` (per dispatch)
Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

---

## 0. Scope

ONE narrow fix packet triggered by the V1.8 real-SketchUp-2020
Owner Gate boot block. Fix the
`SyntaxError: canonical_structure_reconstructor.rb:680:
void value expression` reported by the embedded SU2020
Ruby parser. Inspect the production file for any analogous
control-flow keywords (`next`, `break`, `return`) embedded
inside assignment RHS expressions. Add a source-level
regression guarding this specific old-Ruby-parser-incompatible
pattern.

No V1.8 algorithm changes. No V1.7 contract changes. No
SegmentConflict semantic changes. No tolerance semantics
changes. No workspace ownership changes. No UI product scope
changes. No V1.9 work. No Codex self-invocation.

---

## 1. Status

- **V1.7: CLOSED** (per
  `Prompt/AIPM_V1_7_OWNER_ACCEPTED_CLOSURE_2026-09-02.md`).
- **V1.8: ACTIVE** (per AIPM trace of the Owner Gate report).
- **Frozen V1.8 Blueprint**: ACTIVE (unchanged).
- **V1.8 SR18-01..08 + FR18-01..04**: PASS (per the
  prior dispatch).
- **V1.8 Owner SU2020 Gate (this packet)**: BOOT BLOCK →
  narrow fix applied; Pi Complete; awaiting Owner re-run of
  the real-SU2020 boot path.
- **V1.8 Codex gate**: NOT REQUIRED
  (`CODEX_RISK_TRIGGER = NO`).
- **V1.9 / PreparedCadDataset**: NOT STARTED.
- **V2 / MCP**: OUT OF SCOPE.

Frozen V1.8 Blueprint preserved unchanged on the assigned
`dev/v1.8`. Pi did NOT rewrite any frozen design authority.

---

## 2. Boot-block root cause and narrow fix

The previous FR18-04 `_validate_adjacency_against_edges`
implementation used `next` as the value of an `else` branch of
an `if` expression assigned to `supplied`:

```ruby
supplied =
  if supplied_value.nil?
    []
  elsif supplied_value.is_a?(Array)
    supplied_value.map(&:to_s).reject(&:empty?).sort.uniq
  else
    mismatches << "#{REASON_ADJACENCY_MISMATCH}:non_array_value:#{nid}"
    next   # <-- the value of this branch is `next`, not a value
  end
```

Modern Ruby (2.3+) evaluates `next` as `nil`, so local dev
Ruby 2.7.8 accepts the construct. The SketchUp 2020 embedded
Ruby parser rejects `next` as an expression value with
`SyntaxError: void value expression`. The extension therefore
fails to even load on real SU2020.

### Narrow structural fix

`extension/su_ai_plugin/core/canonical_structure_reconstructor.rb`
— the same loop body, with control flow restructured so
`next` is a standalone block control statement:

```ruby
node_set.each do |nid|
  supplied_value = if adj_h.key?(nid)
                     adj_h[nid]
                   elsif adj_h.key?(nid.to_sym)
                     adj_h[nid.to_sym]
                   end
  # Scalar / Hash / arbitrary non-Array supplied value:
  # fail closed (no silent coercion). Handled FIRST as a
  # standalone control-flow branch so `next` is never
  # used as an expression value.
  if supplied_value && !supplied_value.is_a?(Array)
    mismatches << "#{REASON_ADJACENCY_MISMATCH}:non_array_value:#{nid}"
    next
  end
  # Normalize to a sorted/uniq String Array. nil
  # (key absent) -> empty list; Array -> filtered +
  # sorted/uniq. No control-flow keywords are used as
  # expression values here.
  supplied = if supplied_value.nil?
               []
             else
               supplied_value.map(&:to_s).reject(&:empty?).sort.uniq
             end
  expected_nbrs = Array(expected[nid]).map(&:to_s).sort.uniq
  ...
end
```

Behaviour is byte-equivalent: every `non_array_value:<kid>`
mismatch that the previous implementation would have appended
is still appended (and the offending canonical node is still
skipped via the standalone `next`).

No V1.8 algorithm change. No V1.7 contract change.

### Other occurrences of the same anti-pattern

A line-by-line inspection of the production source file
found exactly ONE occurrence of `next` / `break` / `return`
used as an expression value inside an assignment RHS — the
single offender fixed above. All other `next` / `break` /
`return` statements in the file are proper standalone block
control statements at the start of a line inside a block
body, which are legal in all Ruby versions.

### Source-level regression (new)

`tests/test_v18_structure_reconstruction.rb` — added the
`V18-BOOT` test set (3 tests) with a custom
`v18_boot_violations(src)` heuristic that scans the V1.8
production file for the old-Ruby-parser-incompatible pattern
of `next` / `break` / `return` used as an expression value
inside an assignment RHS. The heuristic tracks:

- `pending_assign` — set when the previous non-empty line
  ended with `=` (continuation of a multi-line assignment).
- `open_rhs` — stack of in-progress `if` / `case` / `do` RHS
  blocks whose value is being assigned.

When `open_rhs` is non-empty and a standalone `next` / `break`
/ `return` lands at the start of a line, it is flagged as a
violation. Standalone block control statements inside a
non-RHS block body are NOT flagged (they are legal in all
Ruby versions).

The heuristic was verified against the exact BAD pattern
(split + same-line opener variants) and three GOOD patterns
(standalone `next` in plain `if`, all-values if-assignment,
all-values case-assignment). All BAD variants caught, no
GOOD variants false-flagged.

Tests:
- `V18-BOOT-A`: production source has NO `next` / `break` /
  `return` used as assignment RHS value.
- `V18-BOOT-B`: V1.8 production file parses cleanly under
  the local vendored Ruby (sanity check; the actual
  host-side compatibility is the SU2020 real-host verifier's
  job).
- `V18-BOOT-C`: `_validate_adjacency_against_edges` still
  produces correct results after the restructure — the
  `non_array_value:<kid>` mismatch family continues to fire
  on a scalar supplied value.

---

## 3. Do-not-change guard

- ✅ No V1.7 schema / identity / digest changes.
- ✅ No SegmentConflict semantic changes.
- ✅ No source / provenance authority changes.
- ✅ No tolerance authority upstream changes.
- ✅ No workspace ownership changes.
- ✅ No host mutation / Face / Observer.
- ✅ No UI product scope changes.
- ✅ No V1.9 work.
- ✅ No Codex self-invocation.
- ✅ Frozen V1.8 Blueprint preserved unchanged.

`CODEX_RISK_TRIGGER = NO` (per dispatch §Gate).

The already-PASS `SR18-01..08` and `FR18-01..04` areas were
NOT reworked beyond mechanical test compatibility. The
`V18-SR08` non-array-value tests (`V18-FR04-B`,
`V18-SR08: scalar adjacency value`, etc.) continue to PASS
against the restructured helper.

---

## 4. Test evidence

### 4a. Full Ruby suite

- **1048 / 1048 PASS** / 0 fail / 0 error.
- Composition (1048 tests):
  - V1.0–V1.6 regressions
  - 127 V1.7 tests
  - 9 V1.5 BLOCK-005
  - 7 V1.6 close-autodiscard
  - 4 LEGACY-COMPAT
  - 9 RBZ smoke
  - 15 V1.8 focused core (V18-T01..T15)
  - 5 V1.8 runner integration (V18-I01..I05)
  - 32 V1.8 SR18 focused (V18-SR01..SR08)
  - 16 V1.8 FR18 focused (V18-FR01..FR04)
  - 3 new V1.8 BOOT focused (V18-BOOT-A..C)
- Delta vs prior V18-FINAL-FOUR-RESIDUALS 1045:
  **+3 tests** (the new V18-BOOT set).
- All previously-PASS tests remain PASS unchanged.

### 4b. Focused V18-BOOT timings

- 3 V18-BOOT tests: **0.024 s** end-to-end.

### 4c. Node DOM (`tests/test_html_render_dom.js`)

Unchanged from V1.8 base — all 327 assertions PASS, final
line `PASS`. No JS-side change in this dispatch.

### 4d. `git diff --check`

Clean (0 warnings).

---

## 5. V1.8 RBZ

- **Path**: `dist/SU-AI-Plugin.rbz` (overwritten by this dispatch)
- **Size**: **1,077,480 bytes**
- **Entries**: **69**
- **SHA-256**: `b58b412523c8a2ad3560eeef714321910d4fb695b3956dbb726df54ff3239497`
- **Packaged `html/app.js` SHA-256**:
  `56878DD018A0DB6A1684CABE91EE84EB1426B295C7B1CF60F6A08F5D98353F2D`
  (unchanged from V18-FINAL-FOUR-RESIDUALS — no JS change)
- **Packaged `html/index.html` SHA-256**:
  `6405DD9EB10A4C4CFCC73CD15AA8B54BC4DAF1D5F631780D7DB6308EAAD6489D`
  (unchanged from V18-FINAL-FOUR-RESIDUALS — no HTML change)
- **Packaged `html/style.css` SHA-256**:
  `3FAAB5E5C6C9757DDE90D2F984B02F2F357727553232BC7FC70814C7709BB95B`
  (unchanged from V18-FINAL-FOUR-RESIDUALS — no CSS change)
- The packaged `canonical_structure_reconstructor.rb`
  contains the BOOT BLOCK fix (no `next` used as an
  expression value inside an assignment RHS).

---

## 6. Commit + push plan

- Single production commit on `dev/v1.8` containing:
  - `core/canonical_structure_reconstructor.rb`
    (BOOT BLOCK narrow fix)
  - `tests/test_v18_structure_reconstruction.rb`
    (3 new V18-BOOT tests)
  - Updated RBZ at `dist/SU-AI-Plugin.rbz`.
  - This report (`Review/CURRENT_PI_REPORT.md`).
  - `CURRENT_STATE.md` doc-stamp.
- One normal fast-forward push to `origin/dev/v1.8`.
- No force-push, no rebase, no rewrite of shared history,
  no `main` push/merge, no tag/release.

---

## 7. Gate

- **AIPM_REVIEW: PENDING** (this packet is the BOOT BLOCK
  narrow-fix round; AIPM must confirm the narrow fix is
  algorithm-neutral and the new source guard is sound).
- **CODEX_RISK_TRIGGER: NO** (frozen boundary untouched;
  no algorithm change).
- **OWNER_SU2020: PENDING RE-RUN** (Owner must re-run the
  real-SU2020 boot path to confirm the `SyntaxError` is gone
  and the extension loads).
- **V1.9: NOT STARTED**.

After green: one normal fast-forward push of the
assigned `dev/v1.8` as the complete-task submission. STOP
and return control to AIPM + Owner for the next step.
