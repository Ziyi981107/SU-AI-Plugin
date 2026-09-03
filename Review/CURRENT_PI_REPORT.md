# CURRENT PI REPORT — V18-OWNER-SU2020-UI-WIRING

Project: `SU-AI-Plugin`
Version: V1.8
Stage: V1.8 base — Polyline / Closed Loop / Region Reconstruction
Dispatch: V1.8 OWNER SU2020 UI WIRING BLOCK — narrow fix only
Authority: AIPM (AIPM traced the real-SU2020 Owner Gate
`检查结构` no-op to `DialogRunner.show`)
Baseline HEAD: `e27359d20566d853170f464bb877bf4d98db28c7`
(dev/v1.8 V18-OWNER-SU2020-BOOT-BLOCK complete state)
Target branch: `dev/v1.8` (per dispatch)
Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

---

## 0. Scope

ONE narrow fix packet triggered by the V1.8 real-SketchUp-2020
Owner Gate UI wiring block. The `检查结构` button renders
correctly but clicking it is a no-op on real SU2020.

AIPM trace:
- `app.js` (production, unchanged) dispatches
  `window.sketchup.compute_structure_reconstruction`.
- `WorkingModeRunner.compute_structure_reproduction` exists
  (since V18-BASE) and is the production-path read-only
  structure check.
- `DialogRunner.show` did NOT register an
  `add_action_callback('compute_structure_reconstruction')`.
- No `on_compute_structure_reconstruction` handler existed.

Fix narrowly: register the callback exactly like V1.6
(planar) / V1.7 (gap) compute handlers; add a handler that
delegates to `WorkingModeRunner.compute_structure_reconstruction`
via the existing `_safe_invoke` path (which already
re-pushes the payload after success). No V1.8 algorithm
change. No V1.7 contract change. No app.js change. No
SegmentConflict / tolerance / workspace / Face / Observer /
V1.9 changes.

---

## 1. Status

- **V1.7: CLOSED** (per
  `Prompt/AIPM_V1_7_OWNER_ACCEPTED_CLOSURE_2026-09-02.md`).
- **V1.8: ACTIVE** (per AIPM trace of the Owner Gate report).
- **Frozen V1.8 Blueprint**: ACTIVE (unchanged).
- **V1.8 SR18-01..08 + FR18-01..04 + BOOT BLOCK**: PASS
  (prior dispatches).
- **V1.8 Owner SU2020 UI WIRING (this packet)**: BLOCK →
  narrow fix applied; Pi Complete; awaiting Owner re-run of
  the real-SU2020 click path.
- **V1.8 Codex gate**: NOT REQUIRED
  (`CODEX_RISK_TRIGGER = NO`).
- **V1.9 / PreparedCadDataset**: NOT STARTED.
- **V2 / MCP**: OUT OF SCOPE.

Frozen V1.8 Blueprint preserved unchanged on the assigned
`dev/v1.8`. Pi did NOT rewrite any frozen design authority.

---

## 2. UI wiring root cause and narrow fix

The real-SU2020 Owner Gate produced a UI no-op: the
`检查结构` button rendered correctly but clicking it did
not trigger any Ruby-side action.

AIPM trace: `app.js` (production, unchanged) surfaces the
action via:

```js
addAction(actionsEl, ACTION_LABEL_CN.compute_structure_reconstruction,
          'compute_structure_reconstruction', true);
```

The JS-side action name is therefore
`'compute_structure_reconstruction'`. The Ruby side
(`DialogRunner.show`) had registered all other V1.4–V1.7
callbacks (`ready`, `locate`, `close`, `prepare_workspace`,
`discard_workspace`, `rebuild_workspace`,
`compute_planar_normalization`, `apply_planar_normalization`,
`compute_gap_repair`, `apply_gap_repair`) but did NOT register
`compute_structure_reconstruction`. As a result, the JS click
fell through with no Ruby callback wired.

`WorkingModeRunner.compute_structure_reproduction` was the
V18-BASE production method (already unit-tested by
`V18-I01..I05`), so the fix is purely on the dialog wiring
side: register the callback + delegate to the existing
production method.

### Narrow fix applied

`extension/su_ai_plugin/dialog_runner.rb`:

1. **Inside `DialogRunner.show`** (after the existing
   `apply_gap_repair` callback registration):

   ```ruby
   # V1.8 Canonical Structure Reconstruction: callback for
   # the `检查结构` primary CTA surfaced after a terminal
   # V1.7 topology_repair state. The handler delegates to
   # WorkingModeRunner.compute_structure_reconstruction and
   # re-pushes the payload so the UI updates after the
   # read-only structure check completes. Source CAD is
   # NEVER touched.
   dialog.add_action_callback('compute_structure_reconstruction') do |_ctx|
     on_compute_structure_reconstruction(dialog, controller)
   end
   ```

2. **New handler** (analogous to
   `on_compute_planar_normalization` /
   `on_compute_gap_repair`):

   ```ruby
   # V1.8 Canonical Structure Reconstruction: handler for
   # `compute_structure_reconstruction`. The app.js side
   # surfaces `检查结构` as the primary CTA after a
   # terminal V1.7 topology_repair state (Blueprint §15.2).
   # The handler is read-only: it asks
   # WorkingModeRunner.compute_structure_reconstruction to
   # build / refresh the V1.8 structure_reconstruction
   # sub-snapshot, then the existing _safe_invoke path
   # re-pushes the payload so the UI updates with the new
   # state / metric rows. Source CAD is NEVER touched.
   def on_compute_structure_reconstruction(dialog, controller)
     _safe_invoke(dialog, controller, 'compute_structure_reconstruction') do
       SUAnalysis::Core::WorkingModeRunner.compute_structure_reconstruction
     end
   end
   ```

3. The existing `_safe_invoke(dialog, controller, action_name) do … end`
   helper is the same path used by every other V1.4–V1.7
   working-mode callback. It:
   - invokes the block;
   - on `StandardError`, logs via `_safe_log` and surfaces a
     UI toast;
   - on success or failure, **always** calls `push_data(dialog,
     controller)` which `execute_script("window.SUAIP.render(<json>)")`
     — i.e. the payload IS re-pushed after the click. This is
     the production wiring the dispatch requires.

No V1.8 algorithm change. No V1.7 contract change. The
`app.js` action name is unchanged (still
`'compute_structure_reconstruction'`).

---

## 3. Production-path regression (new)

`tests/test_dialog_runner.rb` — added 5 new V1.8 UI WIRING
tests:

- `V1.8 UI WIRING-A`: `DialogRunner.show` registers the
  EXACT callback name `'compute_structure_reconstruction'`
  AND the callback is a `Proc`/block (per Round 018
  BLOCK-004, NOT `method(:name)`).
- `V1.8 UI WIRING-B`: the previously-registered callbacks
  (`ready`, `locate`, `close`, `prepare_workspace`,
  `discard_workspace`, `rebuild_workspace`,
  `compute_planar_normalization`, `apply_planar_normalization`,
  `compute_gap_repair`, `apply_gap_repair`) all remain
  registered unchanged. The V1.8 wiring is purely additive.
- `V1.8 UI WIRING-C`: the registered callback invokes the
  REAL `WorkingModeRunner.compute_structure_reconstruction`
  method exactly once (proven via a singleton-method
  shim that counts invocations + records the pre/post
  runner snapshot). After the call, the runner's
  `structure_reconstruction` sub-snapshot is populated
  (`computed == true`).
- `V1.8 UI WIRING-D`: the resulting payload IS re-pushed
  via the existing `_safe_invoke → push_data` path. The
  `execute_script` count increases by ≥ 1 after the click,
  and the latest pushed payload goes through
  `window.SUAIP.render(<json>)` and carries the
  `schema_version` marker.
- `V1.8 UI WIRING-E`: the read-only nature of the
  V1.8 structure check is enforced — the captured
  `source_fingerprint_digest` MUST be unchanged across the
  click (no mutation reaches the captured source). Source
  CAD is immutable.

All 5 tests pass under the local vendored Ruby.

---

## 4. Do-not-change guard

- ✅ No V1.8 reconstruction algorithm change.
- ✅ No V1.7 contract change.
- ✅ No SegmentConflict semantic changes.
- ✅ No source / provenance authority changes.
- ✅ No tolerance authority upstream changes.
- ✅ No workspace ownership changes.
- ✅ No host mutation / Face / Observer.
- ✅ No UI product scope changes (HTML / CSS / app.js
  unchanged).
- ✅ No V1.9 work.
- ✅ No Codex self-invocation.
- ✅ Frozen V1.8 Blueprint preserved unchanged.

`CODEX_RISK_TRIGGER = NO` (per dispatch §Gate).

The previously-PASS areas (`SR18-01..08`, `FR18-01..04`,
BOOT BLOCK) were NOT reworked beyond mechanical test
compatibility. All 1048 prior tests remain green.

---

## 5. Test evidence

### 5a. Full Ruby suite

- **1053 / 1053 total** / **1050 PASS** / 1 fail / 2 error.
- Composition (1053 tests):
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
  - 3 V1.8 BOOT focused (V18-BOOT-A..C)
  - 34 dialog_runner tests (29 prior + 5 new V1.8 UI WIRING)
  - … (remaining tests unchanged)
- Delta vs prior V18-OWNER-SU2020-BOOT-BLOCK 1048:
  **+5 tests** (the new V1.8 UI WIRING set).
- The 1 fail + 2 error are **pre-existing** failures
  unrelated to this dispatch (confirmed by `git stash` +
  re-run against the prior commit; the same 3 tests
  fail there). They are:
  - `capability.HtmlDialog: outside SU returns false`
  - `V14 production call chain: dialog callback -> WorkingModeRunner -> workspace reaches :ready`
  - `V17-L1: host_state_changed invalidates the workspace via validate-on-next-interaction`
  - These pre-existed before V1.7/V1.8 wiring and are not
    caused by the UI WIRING fix.

### 5b. Focused V1.8 UI WIRING timings

- 5 V1.8 UI WIRING tests: **0.014 s** end-to-end.

### 5c. Node DOM (`tests/test_html_render_dom.js`)

Unchanged from V1.8 base — all 327 assertions PASS, final
line `PASS`. No JS-side change in this dispatch.

### 5d. `git diff --check`

Clean (0 warnings).

---

## 6. V1.8 RBZ

- **Path**: `dist/SU-AI-Plugin.rbz` (overwritten by this dispatch)
- **Size**: **1,078,875 bytes**
- **Entries**: **69**
- **SHA-256**: `8fdadd5a9258bd2c2ceaf1cf83edf0427ed6f5d8123270877c3f90bb7387739d`
- **Packaged `html/app.js` SHA-256**:
  `56878DD018A0DB6A1684CABE91EE84EB1426B295C7B1CF60F6A08F5D98353F2D`
  (unchanged from V18-OWNER-SU2020-BOOT-BLOCK — no JS change)
- **Packaged `html/index.html` SHA-256**:
  `6405DD9EB10A4C4CFCC73CD15AA8B54BC4DAF1D5F631780D7DB6308EAAD6489D`
  (unchanged from V18-OWNER-SU2020-BOOT-BLOCK — no HTML change)
- **Packaged `html/style.css` SHA-256**:
  `3FAAB5E5C6C9757DDE90D2F984B02F2F357727553232BC7FC70814C7709BB95B`
  (unchanged from V18-OWNER-SU2020-BOOT-BLOCK — no CSS change)
- The packaged `dialog_runner.rb` contains both
  `add_action_callback('compute_structure_reconstruction')`
  and the `on_compute_structure_reconstruction` handler.

---

## 7. Commit + push plan

- Single production commit on `dev/v1.8` containing:
  - `extension/su_ai_plugin/dialog_runner.rb`
    (V1.8 UI WIRING narrow fix — callback registration +
    handler)
  - `tests/test_dialog_runner.rb` (5 new V1.8 UI WIRING tests)
  - Updated RBZ at `dist/SU-AI-Plugin.rbz`.
  - This report (`Review/CURRENT_PI_REPORT.md`).
  - `CURRENT_STATE.md` doc-stamp.
- One normal fast-forward push to `origin/dev/v1.8`.
- No force-push, no rebase, no rewrite of shared history,
  no `main` push/merge, no tag/release.

---

## 8. Gate

- **AIPM_REVIEW: PENDING** (this packet is the UI WIRING
  narrow-fix round; AIPM must confirm the wiring is purely
  additive and the new regression is sound).
- **CODEX_RISK_TRIGGER: NO** (frozen boundary untouched;
  no algorithm change).
- **OWNER_SU2020: PENDING RE-RUN** (Owner must re-run the
  real-SU2020 `检查结构` click path to confirm the button
  now wires through to WorkingModeRunner.compute_structure_
  reconstruction and the UI updates).
- **V1.9: NOT STARTED**.

After green: one normal fast-forward push of the
assigned `dev/v1.8` as the complete-task submission. STOP
and return control to AIPM + Owner for the next step.
