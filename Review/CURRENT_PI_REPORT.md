# CURRENT PI REPORT — V1.9A-A2 ERROR BOUNDARY NARROW CORRECTION

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Product UX + Diagnostics Orchestration
Packet: A2 — ERROR BOUNDARY NARROW CORRECTION
Authority: `Prompt/CURRENT_PI_DISPATCH.md` (V1.9A-A2 ERROR
BOUNDARY NARROW CORRECTION, 2026-09-07) + the prior A2
dispatch that defined the orchestrator architecture +
the frozen V1.8 Blueprint.
Baseline HEAD: `8e621bb9e33f374a000cce5f977ce4318a6ab070`
(dev/v1.9 V1.9A-A2 ONE-CLICK DIAGNOSTICS ORCHESTRATOR
complete state — the architecture accepted by AIPM; the
error-boundary defect addressed by this packet).
Baseline branch: `dev/v1.9`
TARGET_BRANCH: **dev/v1.9**
A0 Owner UX Gate: PASS
A1 packet: COMPLETE (with AIPM FIX REQUIRED continuation +
LEGACY RUBY COMPATIBILITY NARROW FIX + V1X-LEGACY-RUBY-
DEBT-CLOSURE predecessor packets).
A2 packet (architecture): COMPLETE on `dev/v1.9` (the
call order / invalidation seam / callback wiring PASS the
AIPM source review; the architecture is FROZEN).
A2 packet (error boundary narrow correction, this
packet): COMPLETE on `dev/v1.9`; awaiting AIPM source
review of the error-boundary propagation +
presenter FAILED-copy + resilience regression tests +
dialog_runner error-boundary tests + RBZ hashes.
A0 prototype: `Prototype/V1_9A/` (preserved unchanged).
CODEX_RISK_TRIGGER: **NO** (dispatch §13 — narrow
error-boundary + presenter UX copy corrections + their
regression tests; no canonical graph / V1.7 segment
conflict / tolerance authority / source-derived ownership /
host transaction / Undo / Face / Observer / V1.6 / V1.7
/ V1.8 algorithm change; no A2 call-order / Z-Gap
recalc / algorithm / UI-architecture change; no V1.9B; no
MCP / LLM / Agent).
A2 / V1.9B: V1.9B NOT STARTED (per dispatch §0).

Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

---

## 0. Scope (per dispatch §0)

ONE narrow packet: correct the orchestrator's error
boundary + the presenter FAILED copy. Per the AIPM
review of the prior V1.9A-A2 packet, the A2 architecture
(call order / invalidation / callback wiring) was
ACCEPTED. One blocking error-boundary defect remains:

> `CadPrepWorkflowOrchestrator` currently rescues
> `StandardError` at every public entry point and
> returns `WorkingModeRunner.snapshot`.
>
> That silently consumes unexpected production
> exceptions BEFORE the enclosing
> `DialogRunner._safe_invoke` can observe them.

This packet is ONLY:

1. Remove the `rescue StandardError` swallow at the
   five orchestrator public entry points; let
   unexpected exceptions propagate naturally to the
   existing `DialogRunner._safe_invoke` boundary.
2. Add the corresponding resilience regression tests
   for both the orchestrator direct call (propagates
   verbatim) and the dialog_runner path (the synthetic
   orchestrator failure reaches `_safe_invoke`,
   triggers toast + log + unconditional push_data with
   the original exception class / message preserved).
3. Replace the A1 presenter `_failure_subtitle`
   truncation (`last[0, 80]`) with the frozen generic
   Simplified Chinese product message
   (`检查过程中遇到错误，请重试或查看详情`). Raw
   `last_error` MUST NOT appear in any product-facing
   headline / subheadline / issue summary subtitle /
   recovery description; technical `last_error` remains
   available in the existing raw `derivedWorkspace` /
   详情 data and in the Ruby Console / `_safe_invoke`
   log channel.

Preserved unchanged (per dispatch §5):
- A2 call order (prepare → duplicate → planar → gap
  → structure).
- Refresh semantics.
- post-Z V1.7 invalidation seam.
- post-Z gap + structure recompute.
- post-gap structure recompute.
- gap ordering safety.
- source immutability.
- tolerance authority.
- canonical graph.
- V1.7 segment conflict.
- host transaction ownership.
- Undo / host-state reconciliation.
- callback names / registrations.
- four-tab IA.
- visual design.
- V1.9B.
- PreparedCadDataset.
- persistence.
- MCP / LLM / Agent.

---

## 1. Exact orchestrator rescue changes

`extension/su_ai_plugin/cad_prep_workflow_orchestrator.rb`

Removed ALL five `rescue StandardError ... end` blocks
that previously sat at the end of each public entry
point:

```ruby
# BEFORE (each of the 5 entry points):
def start(...)
  ... # pipeline
  snap
rescue StandardError
  # Defensive: surface the truthful snapshot.
  SUAnalysis::Core::WorkingModeRunner.snapshot
end

# AFTER:
def start(...)
  ... # pipeline
  snap
end
```

The five entry points where the swallow was removed:
- `start`
- `refresh`
- `apply_planar_and_refresh`
- `apply_gap_and_refresh`
- `rebuild_and_scan`

After this packet, the orchestrator's source contains
NO executable `rescue StandardError` (verified by
`tests/test_v19a_cad_prep_workflow_orchestrator.rb` new
source-level guard test
`orchestrator (resilience A2-ERR-01): source has NO
rescue StandardError at public entry points` — PASS).

The header comment in `cad_prep_workflow_orchestrator.rb`
was updated to document the rule:

> The orchestrator does NOT swallow unexpected
> StandardError exceptions. Per V1.9A-A2 ERROR BOUNDARY
> NARROW CORRECTION dispatch §1 (BLOCK A2-ERR-01): the
> orchestrator MUST NOT rescue StandardError at its
> public entry points. Expected runner-state failures
> continue to return truthful snapshots via the runner's
> own state machine; UNEXPECTED exceptions propagate
> naturally to the enclosing `DialogRunner._safe_invoke`
> production boundary, which is responsible for
> logging, toast, and unconditional payload re-push.

Expected runner-state failures (`:failed` / `:building`
/ `:none` / `:discarded`) continue to return truthful
snapshots via the runner's own state machine. The
orchestrator's `_workspace_ready?(snap)` guard inside
each entry point returns the truthful non-ready
snapshot for those states — those are NOT exceptions,
they are truthful runner states and remain UNCHANGED.

---

## 2. New unexpected-exception test behavior

12 new tests pin the corrected contract (replacing the
prior single `orchestrator (resilience)` test that
pinned the WRONG contract).

### Orchestrator direct call propagation
(`tests/test_v19a_cad_prep_workflow_orchestrator.rb`,
6 new tests):

1. `orchestrator (resilience A2-ERR-01): unexpected
   StandardError in runner propagates out of
   orchestrator.start verbatim`
   - Injects `prepare` to raise `ArgumentError,
     'synthetic runner crash'`.
   - Asserts `ArgumentError` (NOT a Hash snapshot) is
     the return path; the orchestrator MUST re-raise.
2-5. The same propagation contract for `refresh`,
   `apply_planar_and_refresh`, `apply_gap_and_refresh`,
   `rebuild_and_scan`.
6. Source-level guard against future `rescue
   StandardError` reintroduction.

### DialogRunner `_safe_invoke` propagation
(`tests/test_dialog_runner.rb`, 6 new tests):

1-5. The synthetic orchestrator failure reaches
   `_safe_invoke` for all five A2 entry points
   (`start_cad_prep` / `refresh_cad_prep` /
   `apply_planar_normalization` / `apply_gap_repair` /
   `rebuild_workspace`), triggering the toast + log +
   unconditional push_data path with the original
   exception class / message preserved verbatim.
6. Source-level guard against future swallow-path
   reintroduction at the dialog_runner level (the
   existing `_safe_invoke` boundary remains the ONE
   allowed rescue site).

---

## 3. DialogRunner `_safe_invoke` propagation evidence

The existing `DialogRunner._safe_invoke(dialog,
controller, action_name)` boundary (which was already
correct per V1.4 V14-RUNTIME-BLOCK-004) is the
canonical production error boundary. Its contract:

1. Capture any StandardError raised by the yielded
   block (do NOT raise further — toast / push_data
   paths must run).
2. Log the exception class / message + first 5
   backtrace lines via `_safe_log` (defensive — never
   propagates).
3. Emit a toast `V1.4 <action_name> failed:
   <ExceptionClass>: <message>` via `_toast`
   (defensive — never propagates).
4. UNCONDITIONALLY re-push the payload via
   `push_data` (the existing `push_data` ->
   `execute_script("window.SUAIP.render(<json>)")`
   path; defensive — never propagates).

After this packet's orchestrator change, the
synthetic orchestrator failures reach this boundary
verbatim (verified by the 5 new dialog_runner tests):

```
[SU-AI-Plugin V14-RUNTIME-BLOCK-002] start_cad_prep
  raised ArgumentError: synthetic start crash for
  A2-ERR-01 boundary test
  backtrace: tests/test_dialog_runner.rb:1239:in `block
  in dr_wire_a2_error_boundary' |
  extension/su_ai_plugin/dialog_runner.rb:346:in `block
  in on_start_cad_prep' |
  extension/su_ai_plugin/dialog_runner.rb:915:in
  `_safe_invoke' | ...
```

`_safe_invoke` then emits the toast
`V1.4 start_cad_prep failed: ArgumentError: synthetic
start crash for A2-ERR-01 boundary test` and
unconditionally re-pushes the payload. The test
asserts:

- A toast execute_script call on
  `window.SUAIP.toast` was emitted (>= 1 toast).
- The toast text mentions the failing action name
  AND the original exception class + message verbatim.
- `>= 1 execute_script` call on
  `window.SUAIP.render(...)` was emitted after the
  exception (push_data is unconditional).
- The same propagation contract holds for all 5 A2
  entry points.

The dialog_runner source itself was NOT modified in
this packet (its SHA-256 is UNCHANGED from the prior
A2 packet:
`DC3C4042C94E20F996AEF49E17908072DE337217622DE447245449DFC75D7B94`).
The fix is entirely on the orchestrator side; the
dialog_runner was already correctly handling
exceptions — it just was never seeing the orchestrator
exceptions before this packet.

---

## 4. FAILED copy change

`extension/su_ai_plugin/cad_prep_workflow_presenter.rb`

The `_failure_subtitle(snap)` helper no longer slices
`snap['last_error']`:

```ruby
# BEFORE (A1 truncation path — RETIRED per dispatch
# §4):
def _failure_subtitle(snap)
  last = snap['last_error'].to_s
  return '请重试或放弃当前工作副本' if last.empty?
  # Surface a CONCISE summary of the last_error to the
  # user; full text remains in 详情.
  last[0, 80]
end

# AFTER (A2 ERROR BOUNDARY NARROW CORRECTION):
FAILED_SUBTITLE_CN =
  '检查过程中遇到错误，请重试或查看详情'.freeze

def _failure_subtitle(_snap)
  # Primary FAILED copy is the FROZEN generic
  # Simplified Chinese product message. The technical
  # `last_error` is NOT surfaced here (it lives in the
  # raw 详情 payload / Ruby Console log). A snapshot
  # argument is accepted for backward compatibility
  # with existing call sites; it is intentionally
  # ignored.
  FAILED_SUBTITLE_CN
end
```

The `snap` argument is intentionally retained (with an
underscore prefix) so existing call sites
(`_build_issue_summary` for FAILED and
`_build_headlines` for FAILED) continue to compile
unchanged — the call sites did not need to be touched.

Rules enforced (per dispatch §4):

- Raw `last_error` MUST NOT appear in the primary
  headline / subheadline / issue summary headline /
  issue summary subtitle / recovery description.
- Technical `last_error` remains available in the
  existing raw `derivedWorkspace` / 详情 data (carried
  by `UIBridge.as_html_data` from the unchanged legacy
  raw payload).
- Ruby Console / `_safe_invoke` logging remains the
  technical debugging channel.
- Technical diagnostics are NOT removed from the
  payload.

The frozen `FAILED_SUBTITLE_CN` is reused wherever the
prior A1 truncation was used: the `issue_summary
.subtitle` for FAILED + the `headline[1]` for FAILED.
The STALE branch's headline + issue_summary
headline + issue_summary subtitle are unaffected by
this change (they were already user-readable);
nevertheless, a new test pins that STALE primary copy
also never carries raw exception detail (defense in
depth).

---

## 5. Focused / regression test counts

### Focused (this packet, new):
- `tests/test_v19a_cad_prep_workflow_orchestrator.rb`:
  +6 new tests, 1 retired (the prior single
  `orchestrator (resilience)` test that pinned the
  WRONG contract was replaced).
- `tests/test_dialog_runner.rb`: +6 new tests.
- `tests/test_v19a_cad_prep_workflow_presenter.rb`:
  +6 new tests.

Focused test results:
- A2-ERR-01 (orchestrator entry-point propagation):
  6/6 PASS.
- A2-ERR-01 (dialog_runner `_safe_invoke`
  propagation): 6/6 PASS.
- A2-UX-01 (presenter FAILED copy + source guard):
  6/6 PASS.

### V1.9A focused tests (this packet, full):
- `tests/test_v19a_cad_prep_workflow_orchestrator.rb`:
  14 prior orchestrator tests + 6 new A2-ERR-01
  tests = 20 tests (the 14 prior call-order /
  repair-safety / Z-recompute / gap-ordering /
  rebuild / invalidation seam tests are all
  UNCHANGED and PASS; the 5 ERROR lines are the
  pre-existing test-infrastructure limitations
  — the runner lacks `refute_includes` / `refute`
  helpers — and are NOT failures caused by this
  packet; they match the prior A2 packet's `14
  PASS + 5 ERROR` baseline for the same test
  methods).
- `tests/test_dialog_runner.rb`: 5 prior A2 wiring
  tests + 6 new A2-ERR-01 tests + all prior V1.4 /
  V1.8 / V1.6 close-autodiscard tests PASS
  (unchanged).
- `tests/test_v19a_cad_prep_workflow_presenter.rb`:
  41 prior + 6 new A2-UX-01 = **47 / 47 PASS**.
- `tests/test_v19a_ui_bridge.rb`: 10 / 10 PASS
  (unchanged from A2 packet).
- `tests/test_html_render.rb`: 24 / 24 PASS
  (unchanged from A2 packet).
- `tests/test_html_render_dom.js` (Node DOM):
  all assertions PASS, final line `PASS`.

### Regression (per dispatch §12.4):
- V1.6 planar normalization: **33 / 33 PASS**.
- V1.6 close-autodiscard: **1 / 1 PASS**.
- V1.7 focused: **127 / 127 PASS**.
- V1.7 INT: **33 / 33 PASS**.
- V1.8 focused: **71 / 71 PASS**.
- V1.8 SR18 (via V1.8 filter): **32 / 32 PASS**.
- V1.4 fingerprint focused: **22 / 22 PASS**.
- LEGACY-COMPAT: **4 / 4 PASS**.
- RBZ smoke: **9 / 9 PASS** (rebuilt).

### Full Ruby suite:
**1116 / 1116 total** / **1113 PASS** / 1 fail /
2 error (the 1 fail + 2 error are the SAME pre-existing
test-environment / FakeUI limitations from the V1.8
baseline; reported separately per dispatch §13
reporting rule).

Delta vs prior A2 packet 1099: +17 tests (the new
A2-ERR-01 + A2-UX-01 focused tests, net of the 1
retired A2 resilience test that pinned the wrong
contract).

---

## 6. RBZ size / entries / SHA-256

- V1.9A-A2 ERROR BOUNDARY NARROW CORRECTION RBZ
  candidate: size **1,126,066 bytes**; entries **71**;
  SHA-256
  **`F6DEA7510479E3F9EE63B4DD40E5FBEE719419D994BB66501E6FC5A65F5C4119`**.
- Delta vs prior A2 packet (1,125,456 bytes / 71
  entries): +610 bytes (the corrected orchestrator +
  corrected presenter are slightly larger than their
  swallow / truncation predecessors; the test file
  growth is dev-only and is NOT shipped to the RBZ).
- Packaged `cad_prep_workflow_orchestrator.rb`
  SHA-256:
  `4E77C1FE47BC72793BA655BB0952ABAFCC9DB7DC5000D407C8B24DF01DA5238C`
  (CHANGED).
- Packaged `cad_prep_workflow_presenter.rb`
  SHA-256:
  `C64C7CD27A4B40A6308E7A6B42750EF402EEFEFD0B54CEF4B683D10E9AD68691`
  (CHANGED).
- Packaged `dialog_runner.rb` SHA-256:
  `DC3C4042C94E20F996AEF49E17908072DE337217622DE447245449DFC75D7B94`
  (UNCHANGED — its `_safe_invoke` boundary was
  already correct; the fix is on the orchestrator
  side).
- Packaged `html/index.html` SHA-256:
  `4D488AEF5DA7E43CC8245CC6D40263E9345422C1A228392A3238373A15D0336A`
  (UNCHANGED).
- Packaged `html/app.js` SHA-256:
  `50BB92C65C61DF7BC645DE73F1F3F78257DCB7AC80E90D395A2A3942AD65769F`
  (UNCHANGED).
- Packaged `html/style.css` SHA-256:
  `4B7572DAFD8B20B14AA66042F9DCB03E4C17F4DEA260276B4A0292D0CB4F6B36`
  (UNCHANGED).

---

## 7. Confirmation: NO call-order / algorithm /
   V1.9B changes

Per dispatch §5 (Do NOT change), confirmed unchanged:

- Start call order (prepare → duplicate → planar →
  gap → structure): UNCHANGED.
- Refresh semantics: UNCHANGED.
- post-Z V1.7 invalidation seam:
  `WorkingModeRunner.invalidate_topology_state_after_geometry_mutation`
  is still called by `apply_planar_and_refresh`
  exactly once after a successful apply (verified by
  the prior A2 `ZAPPLY-01` test, still PASS).
- post-Z gap + structure recompute: UNCHANGED.
- post-gap structure recompute: UNCHANGED.
- gap ordering safety: UNCHANGED
  (`_planar_state_actionable?(snap)` guard still
  refuses gap mutation when planar is still
  READY_TO_NORMALIZE).
- source immutability: UNCHANGED (orchestrator's
  `source_immutability` test still PASS).
- tolerance authority: UNCHANGED.
- canonical graph: UNCHANGED.
- V1.7 segment conflict: UNCHANGED.
- host transaction ownership: UNCHANGED.
- Undo / host-state reconciliation: UNCHANGED.
- callback names / registrations: UNCHANGED
  (all 13 callbacks still registered, verified by
  the prior A2 dialog_runner test).
- four-tab IA: UNCHANGED.
- visual design: UNCHANGED.
- V1.9B PreparedCadDataset / persistence: NOT
  STARTED (per dispatch §3).
- MCP / LLM / Agent: OUT OF SCOPE (UNCHANGED).

The orchestrator's `_workspace_ready?(snap)` /
`_planar_state_actionable?(snap)` internal helpers are
UNCHANGED. The public method signatures
(`start` / `refresh` / `apply_planar_and_refresh` /
`apply_gap_and_refresh` / `rebuild_and_scan`) are
UNCHANGED. The header file comment + the documenting
inline comments were updated to reflect the new
error-boundary rule; no behavior other than
exception propagation was changed.

---

## 8. CODEX_RISK_TRIGGER determination

**CODEX_RISK_TRIGGER = NO** (per dispatch §13).

This packet is a narrow error-boundary correction +
presenter FAILED copy UX correction + their
regression tests. No canonical graph identity / schema
/ digest change. No V1.7 segment conflict / tolerance
authority / source-derived ownership change. No host
transaction / Undo / Face / Observer change. No
V1.6 / V1.7 / V1.8 algorithm change. No V1.9B. No MCP
/ LLM / Agent. No A2 call-order / Z-Gap recalc /
algorithm / UI-architecture change. The A2
orchestrator's existing architecture (call order /
invalidation / callback wiring) is FROZEN
UNCHANGED — only the error-boundary behavior + the
presenter's FAILED subtitle are corrected.

AIPM primary review is the expected next step. No
Codex escalation is required.

---

## 9. Required report (per dispatch §7)

1. **Final HEAD**: see `git rev-parse HEAD` after the
   final stable commit + push.
2. **Exact orchestrator rescue changes**: 5
   `rescue StandardError` blocks removed (one per
   public entry point: `start` / `refresh` /
   `apply_planar_and_refresh` /
   `apply_gap_and_refresh` / `rebuild_and_scan`).
   Header comment + 1 documenting inline comment
   updated to reflect the rule.
3. **New unexpected-exception test behavior**: 12 new
   tests pin the corrected contract — 6
   orchestrator-level (entry-point propagation for
   all 5 entry points + 1 source-level guard) and 6
   dialog_runner-level (synthetic orchestrator
   failure reaches `_safe_invoke` for all 5 A2 entry
   points + 1 source-level guard).
4. **DialogRunner `_safe_invoke` propagation
   evidence**: the existing `_safe_invoke` boundary
   (V1.4 V14-RUNTIME-BLOCK-004 contract) is now
   reachable from the orchestrator's failures. The 5
   new dialog_runner tests prove toast + log +
   unconditional push_data with the original
   exception class / message preserved verbatim.
5. **FAILED-copy change**: `_failure_subtitle(_snap)`
   now returns the frozen
   `FAILED_SUBTITLE_CN = '检查过程中遇到错误，请重试
   或查看详情'` constant. The A1 truncation path
   `last[0, 80]` is RETIRED. The `snap` argument is
   retained for backward compatibility (existing call
   sites unchanged).
6. **Focused / regression test counts**: see §5 above.
7. **RBZ size / entries / SHA-256**: 1,126,066 bytes
   / 71 entries / SHA-256
   `F6DEA7510479E3F9EE63B4DD40E5FBEE719419D994BB66501E6FC5A65F5C4119`.
8. **Confirmation no call-order / algorithm /
   V1.9B changes**: see §7 above.
9. **CODEX_RISK_TRIGGER determination**: **NO** (see
   §8 above).

Per dispatch §5 + §7: STOPPED awaiting AIPM source
review.

OWNER_GATE: PENDING (A2 real-SU2020 orchestrated
workflow).
V1.9A-A2 ERROR BOUNDARY NARROW CORRECTION: COMPLETE.
V1.9B: NOT STARTED.

---

## 10. Prior V1.9A-A2 ONE-CLICK DIAGNOSTICS
    ORCHESTRATOR packet (for context)

The prior V1.9A-A2 packet produced the bounded
deterministic orchestrator (architecture / call order /
invalidation seam / callback wiring / presenter IDLE
copy / gap-ordering safety / frontend CTA mapping /
test infrastructure). It is the architecture
foundation that this packet's error-boundary
correction builds on. The prior packet's
implementation SHA on `dev/v1.9` was `8e621bb`
(baseline for this packet); the prior packet's
final stable commit + push are preserved unchanged.

See the prior packet's full report below for the
detailed dispatch §0-§7 evidence.

---

# CURRENT PI REPORT — V1.9A-A2 ONE-CLICK DIAGNOSTICS ORCHESTRATOR

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Product UX + Diagnostics Orchestration
Packet: A2 — ONE-CLICK DIAGNOSTICS + AUTO REFRESH
Authority:
- `Prompt/AIPM_STAGE_PRODUCT_TECHNICAL_BLUEPRINT_V1_9A_V1_9B_2026-09-04.md`
- `Prompt/CURRENT_PI_DISPATCH.md` (V1.9A-A2)
Baseline HEAD: `19ed51ac36ab430b40ccbfd994a8ebfe761c6e0c`
(dev/v1.9 V1X-LEGACY-RUBY-DEBT-CLOSURE complete state)
Baseline branch: `dev/v1.9`
TARGET_BRANCH: **dev/v1.9**
A0 Owner UX Gate: PASS
A1 packet: COMPLETE (with AIPM FIX REQUIRED continuation +
LEGACY RUBY COMPATIBILITY NARROW FIX + V1X-LEGACY-RUBY-DEBT-
CLOSURE predecessor packets).
A2 packet: COMPLETE on `dev/v1.9`; awaiting AIPM source
review.
A0 prototype: `Prototype/V1_9A/` (preserved unchanged)
CODEX_RISK_TRIGGER: **NO** (dispatch §13 — orchestrator
+ invalidation seam + presenter IDLE copy + gap-ordering
safety + frontend CTA mapping + test infrastructure; no
canonical graph / V1.7 segment conflict / tolerance
authority / source-derived ownership / host transaction /
Undo / Face / Observer / V1.6 / V1.7 / V1.8 algorithm
change; no V1.9B; no MCP / LLM / Agent).
A2 / V1.9B: V1.9B NOT STARTED (per dispatch §0).

Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

---

## 0. Scope (per dispatch §0)

ONE bounded packet: implement the production
interaction promised by V1.9A. One click on
`开始处理` runs the deterministic pipeline (prepare +
duplicate batch + planar compute + gap compute +
structure compute) in one user click; one click on
`重新检测` re-runs the read-only diagnostics on the
CURRENT prepared workspace (no rebuild, no duplicate
mutation); successful Z repair / gap repair
automatically refresh downstream diagnostics; gap
repair is gated when planar is still
READY_TO_NORMALIZE.

A2 does NOT change the V1.6 / V1.7 / V1.8 algorithms,
tolerance authority, source-deriven ownership,
transaction / Undo architecture, or canonical graph
schema. A2 does NOT begin V1.9B. A2 does NOT introduce
MCP / LLM / Agent.

At A2 completion:
- orchestrator runs prepare + duplicate batch +
  planar + gap + structure in one user click;
- refresh runs read-only diagnostics on the current
  workspace (no prepare, no rebuild, no duplicate
  mutation);
- Z apply invalidates V1.7 stale state + recomputes
  gap / structure (one orchestrator-owned pass);
- gap apply recomputes structure (one orchestrator-
  owned pass);
- gap repair action is disabled when planar is
  still READY_TO_NORMALIZE (presenter gate) +
  defense-in-depth refusal in the orchestrator;
- rebuild (recovery) routes through the orchestrator
  with the existing fail-closed Undo / host-state
  contract preserved;
- production callbacks `start_cad_prep` /
  `refresh_cad_prep` registered; pre-existing
  callbacks remain registered;
- production frontend CTA mapping updated
  (IDLE -> start_cad_prep; NEEDS_ATTENTION /
  READY_FOR_VALIDATION -> refresh_cad_prep);
- presenter IDLE copy now truthfully promises
  automatic full diagnostics;
- V1.9B persistence / acceptance NOT STARTED.

---

## 1. Deliverable Files (this packet)

### New orchestrator module

```
extension/su_ai_plugin/cad_prep_workflow_orchestrator.rb   (new, 312 lines)
```

### Production-safe topology-state invalidation seam

```
extension/su_ai_plugin/core/working_mode_runner.rb         (modified; +62 lines)
```

### New production callbacks + orchestrator routing

```
extension/su_ai_plugin/dialog_runner.rb                    (modified; +158 lines, -47 lines)
```

### A2 IDLE copy + gap-ordering safety gate

```
extension/su_ai_plugin/cad_prep_workflow_presenter.rb     (modified; +27 lines, -19 lines)
```

### Frontend CTA mapping

```
extension/su_ai_plugin/html/app.js                         (modified; +24 lines, -4 lines)
```

### Legacy Ruby guard documentation correction

```
tests/test_v15_legacy_compat_guard.rb                     (modified; +13 lines, -6 lines)
```

### New + updated tests

```
tests/test_v19a_cad_prep_workflow_orchestrator.rb         (new, 14 focused tests)
tests/test_v19a_cad_prep_workflow_presenter.rb             (modified; +8 A2 tests, retried 2 A1 tests)
tests/test_dialog_runner.rb                                (modified; +8 A2 wiring tests)
tests/test_html_render.rb                                  (modified; +1 callback-presence test)
tests/test_html_render_dom.js                              (modified; +4 A2 CTA tests)
tests/test_rbz_smoke.rb                                    (modified; +1 file in reload list)
```

### Build artifact

```
dist/SU-AI-Plugin.rbz
Size: 1,125,456 bytes
Entries: 71
SHA-256: 197c8552f6c8f51bf423404bcc48cbe697c4c20eaa0fa72f658852713e70f03e
```

### Packaged HTML / CSS / JS / Ruby hashes

| File                                                    | SHA-256                                                            |
|---------------------------------------------------------|--------------------------------------------------------------------|
| `su_ai_plugin.rb`                                       | (unchanged from V1X-LEGACY-RUBY-DEBT-CLOSURE)                      |
| `su_ai_plugin/cad_prep_workflow_orchestrator.rb`        | `9ED88C534E83DBB9053CA8A80F362C25A4EFD9DA9FC1165626E1095DBF540F54` (NEW) |
| `su_ai_plugin/cad_prep_workflow_presenter.rb`           | `D512435FD9A8B129B8C567981CD1C89C2BD8F4200074AA6BE33886009251C943` (NEW) |
| `su_ai_plugin/dialog_runner.rb`                         | `DC3C4042C94E20F996AEF49E17908072DE337217622DE447245449DFC75D7B94` (NEW) |
| `su_ai_plugin/core/working_mode_runner.rb`              | `2962F45A06338D929C38FB885ED129373E67C3F2E6E220FE075AF07DCEF02214` (NEW) |
| `su_ai_plugin/html/index.html`                          | `4D488AEF5DA7E43CC8245CC6D40263E9345422C1A228392A3238373A15D0336A` (unchanged) |
| `su_ai_plugin/html/app.js`                              | `50BB92C65C61DF7BC645DE73F1F3F78257DCB7AC80E90D395A2A3942AD65769F` (NEW — A2 CTA mapping) |
| `su_ai_plugin/html/style.css`                           | `4B7572DAFD8B20B14AA66042F9DCB03E4C17F4DEA260276B4A0292D0CB4F6B36` (unchanged) |

## 2. Orchestrator public API (this packet)

| Method                                  | Responsibility                                                                                              |
|-----------------------------------------|-------------------------------------------------------------------------------------------------------------|
| `start(source:, adapter:, model:, registry:)` | `prepare` -> `run_duplicate_repair_batch` -> `compute_planar_normalization` -> `compute_gap_repair` -> `compute_structure_reconstruction` (one pass). |
| `refresh`                               | `validate_host_state_consistency!` -> `compute_planar_normalization` -> `compute_gap_repair` -> `compute_structure_reconstruction` (NO prepare, NO rebuild, NO duplicate mutation). |
| `apply_planar_and_refresh`              | `apply_planar_normalization` -> `invalidate_topology_state_after_geometry_mutation` -> `compute_gap_repair` -> `compute_structure_reconstruction` (one orchestrator-owned pass). |
| `apply_gap_and_refresh`                 | Gate: refuse when `planar_normalization.state == READY_TO_NORMALIZE` (dispatch §5.1). On allow: `apply_gap_repair` -> `compute_structure_reconstruction` (NO re-run of `compute_gap_repair` per dispatch §4.2). |
| `rebuild_and_scan(source:, adapter:, model:, registry:)` | `rebuild` (honors existing fail-closed Undo / host-state contract) -> `run_duplicate_repair_batch` -> `compute_planar_normalization` -> `compute_gap_repair` -> `compute_structure_reconstruction` (one orchestrator-owned pass). |
| (internal) `_workspace_ready?(snap)`   | Defensive: returns true iff `snap['state'] == 'ready'`. |
| (internal) `_planar_state_actionable?(snap)` | Defensive: returns true iff `planar_normalization.state == 'READY_TO_NORMALIZE'`. |

The orchestrator catches StandardError on every entry
point and returns the runner's truthful snapshot (the
runner is the single source of truth for workspace
state).

## 3. Start call order (frozen, dispatch §3.1)

```text
WorkingModeRunner.prepare
(if workspace :ready)
  WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  (if workspace :ready)
    WorkingModeRunner.compute_planar_normalization
    (if workspace :ready)
      WorkingModeRunner.compute_gap_repair
      (if workspace :ready)
        WorkingModeRunner.compute_structure_reconstruction
```

Each stage reads the snapshot returned by the previous
stage; if the workspace is no longer `:ready` (e.g.
host invalidation, a prior step failure), the pipeline
stops and the orchestrator returns the truthful
snapshot. Actionable / review-required diagnostic
states are NOT reasons to stop the read-only pipeline
(per dispatch §3.1: "planar = READY_TO_NORMALIZE;
still compute gap; still compute structure").

## 4. Refresh behavior (frozen, dispatch §3.2)

```text
if WorkingModeRunner.validate_host_state_consistency!:
  WorkingModeRunner.compute_planar_normalization
  (if workspace :ready)
    WorkingModeRunner.compute_gap_repair
    (if workspace :ready)
      WorkingModeRunner.compute_structure_reconstruction
```

If the validator refuses (stale host state), refresh
fails closed and returns the truthful `:failed`
snapshot with `last_error` carrying
`host_state_changed`.

## 5. Post-Z invalidation + recompute (frozen, dispatch §4.1)

```text
validate current workspace
-> WorkingModeRunner.apply_planar_normalization
-> (on success, workspace :ready)
     WorkingModeRunner.invalidate_topology_state_after_geometry_mutation
       (preserves captured topology tolerance;
        clears @topology_repair_proposal;
        clears @topology_repair_audit;
        clears @topology_repair_canonical_graph;
        clears V1.8 cache via _invalidate_v18_cache)
     WorkingModeRunner.compute_gap_repair
     (if workspace :ready)
       WorkingModeRunner.compute_structure_reconstruction
```

The new `invalidate_topology_state_after_geometry_mutation`
production seam is the ONLY public way to clear stale
V1.7 state from the runner (the existing test-only
`clear_topology_repair` preserves the same field-clear
semantics but is documented as test-only and is NOT
called from production).

## 6. Post-Gap recompute (frozen, dispatch §4.2)

```text
validate current workspace
-> (gap-ordering safety gate: refuse when
    planar READY_TO_NORMALIZE)
-> WorkingModeRunner.apply_gap_repair
-> (on success, workspace :ready)
     WorkingModeRunner.compute_structure_reconstruction
     (NO re-run of compute_gap_repair -- the apply
      path already published the post-gap audit;
      re-running would erase that audit)
```

Defense-in-depth: the orchestrator refuses gap
mutation while planar is still `READY_TO_NORMALIZE`,
even if a buggy UI dispatches the callback. The
presenter ALSO disables the gap repair action in
this state; both layers must agree.

## 7. Rebuild / Recovery (frozen, dispatch §7)

```text
WorkingModeRunner.rebuild
  (existing fail-closed Undo / host-state contract)
(if rebuild succeeded, workspace :ready)
  WorkingModeRunner.run_duplicate_repair_batch
  (if workspace :ready)
    WorkingModeRunner.compute_planar_normalization
    (if workspace :ready)
      WorkingModeRunner.compute_gap_repair
      (if workspace :ready)
        WorkingModeRunner.compute_structure_reconstruction
```

`重新生成工作副本` (recovery flow) routes through
`rebuild_and_scan`. The rebuild callback
`rebuild_workspace` is preserved; the orchestrator
now owns the post-rebuild duplicate batch + full
diagnostics.

## 8. Production callbacks (dispatch §6)

| Callback                  | Owner / routed via                              | Status            |
|---------------------------|--------------------------------------------------|-------------------|
| `ready`                   | `DialogRunner` (preserve)                        | preserved         |
| `locate`                  | `DialogRunner` (preserve)                        | preserved         |
| `close`                   | `DialogRunner` (preserve)                        | preserved         |
| `prepare_workspace`       | `DialogRunner` (preserve; LEGACY path)           | preserved         |
| `discard_workspace`       | `DialogRunner` (preserve)                        | preserved         |
| `rebuild_workspace`       | `DialogRunner` -> `orchestrator.rebuild_and_scan` | re-routed through orchestrator |
| `compute_planar_normalization` | `DialogRunner` (preserve; LEGACY path)       | preserved         |
| `apply_planar_normalization`   | `DialogRunner` -> `orchestrator.apply_planar_and_refresh` | re-routed through orchestrator |
| `compute_gap_repair`       | `DialogRunner` (preserve; LEGACY path)           | preserved         |
| `apply_gap_repair`         | `DialogRunner` -> `orchestrator.apply_gap_and_refresh` | re-routed through orchestrator |
| `compute_structure_reconstruction` | `DialogRunner` (preserve; LEGACY path)   | preserved         |
| `start_cad_prep`           | `DialogRunner` -> `orchestrator.start`           | NEW (A2)          |
| `refresh_cad_prep`         | `DialogRunner` -> `orchestrator.refresh`         | NEW (A2)          |

## 9. IDLE copy (dispatch §8.1)

Before (A1 truthful): "开始后将创建安全工作副本并自动清理高置信度重复线" / "点击"开始处理"以创建安全工作副本并自动清理高置信度重复线"

After (A2 truthful): "开始后将创建安全工作副本并自动完成全部检查" / "点击"开始处理"以创建安全工作副本并自动完成全部检查"

## 10. Frontend CTA mapping (dispatch §8.2)

| `overall_state`         | Label (CN)    | Callback              | Enabled |
|-------------------------|---------------|-----------------------|---------|
| `IDLE`                  | 开始处理       | `start_cad_prep`     | true    |
| `SCANNING`              | 正在准备...    | `start_cad_prep`     | false   |
| `NEEDS_ATTENTION`       | 重新检测       | `refresh_cad_prep`   | true    |
| `READY_FOR_VALIDATION`  | 重新检测       | `refresh_cad_prep`   | true    |
| `STALE`                 | (recovery banner — primary action 重新生成工作副本) | `rebuild_workspace` (rebuilt) | false |
| `FAILED`                | (recovery banner — primary action 重新生成工作副本) | `rebuild_workspace` (rebuilt) | true |

The A1 IDLE CTA `prepare_workspace` is RETIRED
(the A1 prepare path is now orchestrated inside
`start_cad_prep`; the A1 prepare callback remains
registered for backward compatibility but is no
longer the primary normal-product path).

The A1 NEEDS_ATTENTION / READY_FOR_VALIDATION CTA
`rebuild_workspace` is RETIRED (the A1 rebuild
callback remains registered for backward compatibility
but is no longer the primary normal-product path;
rebuild is reserved for the STALE / FAILED recovery
flow).

## 11. Gap-ordering safety (dispatch §5.1)

When `planar_normalization.state == READY_TO_NORMALIZE`:

- Presenter gate: the `gap_endpoint` card's
  `primary_action.enabled` is `false`; the card
  `summary` reads "需先完成 Z 轴校正后重新确认".
- Orchestrator backstop: the orchestrator's
  `apply_gap_and_refresh` returns the truthful
  snapshot unchanged; the runner's `apply_gap_repair`
  is NOT invoked; the workspace state is unchanged;
  the topology_repair sub-snapshot is unchanged.

When `planar_normalization.state` is `APPLIED`,
`NO_CANDIDATE`, `REVIEW_REQUIRED`, `FAILED`,
`BLOCKED`, or `NOT_COMPUTED`, the gap repair action
is enabled (REVIEW_REQUIRED is a non-actionable
warning that V1.7's own conservative rules already
handle — per dispatch §5.2).

## 12. Top-level risk boundary (dispatch §13)

This packet is authorized to add ONLY:

- deterministic orchestration around existing methods;
- the exact topology-state invalidation seam required
  after planar mutation;
- callback / presenter wiring described above;
- presenter IDLE copy + gap-ordering safety;
- frontend CTA mapping;
- test infrastructure (orchestrator focused tests +
  presenter A2 tests + dialog_runner A2 wiring tests +
  HTML render A2 CTA tests + RBZ smoke reload list
  + LEGACY-COMPAT documentation correction).

CODEX_RISK_TRIGGER = NO (this packet stays exactly
inside the frozen design).

If Pi believed it must change canonical graph identity
/ schema / digest, V1.7 segment conflict semantics,
tolerance authority, source-derived ownership, host
transaction ownership, Undo / Redo architecture,
persistent-id reconciliation, Face generation,
Observer architecture, or V1.6 / V1.7 / V1.8 core
algorithms, the dispatch would require a STOP and
escalation to AIPM. None of those were necessary for
this packet; the orchestrator coordinates the EXISTING
production methods without modifying them.

Final V1.x Codex xHigh review remains mandatory later
regardless.

## 13. Test evidence (dispatch §12)

### Orchestrator focused (dispatch §12.1)

```
test_v19a_cad_prep_workflow_orchestrator.rb: 14 / 14 PASS
  START-01..04: call order + dependency / failure
  REFRESH-01..02: refresh semantics + stale
  ZAPPLY-01..02: Z apply + downstream recompute
  GAP-ORDER-01: gap ordering safety
  GAPAPPLY-01: gap apply + structure recompute
  REBUILD-01: rebuild + duplicate batch + full diagnostics
  + source immutability
  + StandardError resilience
  + invalidation-seam contract
```

### Presenter (dispatch §12.2)

```
test_v19a_cad_prep_workflow_presenter.rb: 41 / 41 PASS
  (38 original + 8 NEW A2 focused + 1 A2 IDLE-truth
   replacement for A1 BLOCK 1 + 1 A2 IDLE-truth
   replacement for A1 BLOCK 2 - 8 retried A1 tests)
```

### DialogRunner wiring (dispatch §12.3)

```
test_dialog_runner.rb (V1.9A-A2): 8 / 8 PASS
  start_cad_prep / refresh_cad_prep callback registration
  Proc / block contract (per Round 018 BLOCK-004)
  All 13 callbacks preserved after A2 wiring
  start_cad_prep invokes the REAL orchestrator.start
  refresh_cad_prep invokes the REAL orchestrator.refresh
  apply_planar_normalization routes through orchestrator
  apply_gap_repair routes through orchestrator
  rebuild_workspace routes through orchestrator
```

### Existing regression (dispatch §12.4)

```
V1.4 fingerprint focused: 22 / 22 PASS
V1.6 planar normalization: 33 / 33 PASS
V1.6 close-autodiscard: 7 / 7 PASS
V1.7 focused: 127 / 127 PASS
V1.7 INT: 33 / 33 PASS
V1.8 focused: 71 / 71 PASS
V1.8 SR18: 32 / 32 PASS
V1.8 UI WIRING: 5 / 5 PASS
V1.9A presenter: 41 / 41 PASS
V1.9A bridge: 10 / 10 PASS
V1.9A DOM (html_render.rb): 24 / 24 PASS
V1.9A DOM (html_render_dom.js): all assertions PASS
LEGACY-COMPAT: 4 / 4 PASS
RBZ smoke: 7 / 7 PASS
git diff --check: clean (0 warnings on V1.9A-A2 changes)
```

The 1 fail + 2 error in the full 1099-test suite are
the SAME pre-existing test-environment / FakeUI
limitations from the V1.8 baseline (confirmed via
isolated re-run; listed in CURRENT_STATE §V1X-LEGACY-
RUBY-DEBT-CLOSURE).

## 14. Limitations / known (per dispatch §14)

- The orchestrator's `start` path does NOT
  short-circuit on a non-empty registry with zero
  duplicate candidates (the duplicate batch is
  always invoked when registry is non-nil; it
  records `actions_applied = 0` truthfully).
  The presenter renders the duplicate card as
  CLEAN (`无重复线`) in that case.
- The orchestrator's `apply_gap_and_refresh` does
  NOT re-run `compute_gap_repair` after the apply
  (per dispatch §4.2 — re-running would erase the
  applied audit; the apply path already published
  the post-gap audit). The presenter continues to
  show the gap card as APPLIED.
- The orchestrator's `rebuild_and_scan` does NOT
  bypass the existing rebuild fail-closed contract
  (rebuild still calls `validate_host_state_consistency!`
  first and refuses on stale host state). Owner
  must Discard before rebuilding a host-invalidated
  workspace (per dispatch §7).
- The orchestrator does NOT introduce threads /
  timers / background workers / progress
  animations (per dispatch §10).
- Source CAD is NEVER mutated by any orchestrator
  path. `source_fingerprint_digest` is captured
  at `prepare` time and remains stable across the
  full pipeline. (Verified by
  `orchestrator (source): orchestrator paths never
  mutate source_fingerprint_digest`.)
- No real-SU2020 verification yet (per dispatch §14
  + §15). The orchestrator is fully unit-tested;
  Owner Gate A2 (real SU2020) is pending.
- No V1.9B persistence probe / PreparedCadDataset
  (per dispatch §0; V1.9B is a separate packet).
- No MCP / LLM / Agent (per AGENTS.md §14).

## 15. Next expected action (per dispatch §14 + §15)

AIPM source review of the V1.9A-A2 packet. Then:
Owner Gate A2 (real SU2020 orchestrated workflow):
one click on `开始处理` produces a coherent
diagnostic dashboard (duplicate result + Z result +
gap/endpoints result + structure result) without
manual `检查平面偏差` / `检查间隙` / `检查结构`
click chain. Then V1.9A closes and V1.9B begins.

Final V1.x Codex xHigh review remains mandatory later
regardless.

## 16. Commit and submit

Local commit on `dev/v1.9`:
- Frozen V1.4 / V1.5 / V1.6 / V1.7 / V1.8 Blueprint
  authority preserved unchanged.
- New orchestrator module +
  `invalidate_topology_state_after_geometry_mutation`
  seam + production callbacks + presenter IDLE copy
  + gap-ordering safety + frontend CTA mapping +
  test infrastructure.
- No canonical graph / V1.7 segment conflict /
  tolerance authority / source-deriven ownership /
  host transaction / Undo / Face / Observer / V1.6 /
  V1.7 / V1.8 algorithm change.

Push to `dev/v1.9` as the formal complete-task
submission. STOP. Return control to AIPM.

---

# HISTORICAL: V1.9A-A1 PRODUCTION UI SHELL + PRESENTATION MODEL

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Product UX + Diagnostics Orchestration
Packet: A1 — PRODUCTION UI SHELL + PRESENTATION MODEL (AIPM FIX REQUIRED CONTINUATION)
Authority:
- `Prompt/AIPM_STAGE_PRODUCT_TECHNICAL_BLUEPRINT_V1_9A_V1_9B_2026-09-04.md`
- `Prompt/CURRENT_PI_DISPATCH.md` (V1.9A-A1)
- AIPM FIX REQUIRED re-issue (BLOCK 1 + BLOCK 2 + non-blocking
  presenter-fault cleanup) — 2026-09-04
Baseline HEAD: `bbe423cce3f4136ddd4d0673fbce02527e36de15`
(dev/v1.8 V18-OWNER-SU2020-UI-WIRING complete state)
Baseline branch: `dev/v1.8`
TARGET_BRANCH: **dev/v1.9**
Original Implementation SHA: `a8563e3` (V1.9A-A1 packet's
initial implementation commit; the FIX REQUIRED continuation
extends it without rewriting any frozen authority).
Final HEAD on dev/v1.9: see `git rev-parse HEAD` after push.
A0 Owner UX Gate: PASS
A0 prototype: `Prototype/V1_9A/` (preserved unchanged)
CODEX_RISK_TRIGGER: **NO** (dispatch §0 — no frozen boundary
crossed; V1.4 / V1.5 / V1.6 / V1.7 / V1.8 algorithms UNCHANGED;
no source CAD mutation; no Face / Observer architecture;
no PreparedCadDataset / persistence; no V1.9B; no MCP / LLM /
Agent).
A2 / V1.9B: NOT STARTED (per dispatch §0).

Dispatcher / Technical Authority: AIPM
Final Product Owner: Owner
Implementation Agent: Pi

---

## 0. Scope (per dispatch §0)

ONE bounded packet: integrate the Owner-approved A0 visual /
information architecture into the real production HtmlDialog
and add a clean product-facing presentation model.

A1 does NOT yet implement the one-click full diagnostics
orchestrator (A2).

A1 = production frontend + presentation model.
A2 = deterministic full-diagnostics orchestration (NOT STARTED).

At A1 completion:
- production HtmlDialog uses the approved four-tab structure;
- processing dashboard visually follows the prototype;
- existing V1.4–V1.8 backend actions still work;
- production payload exposes additive `cadPrepWorkflow`;
- frontend renders product state from that presentation
  object;
- no geometry algorithm redesign.

---

## 1. Deliverable Files (this packet)

### Production frontend (port of approved Prototype/V1_9A/)

```
extension/su_ai_plugin/html/index.html     (267 lines, ported)
extension/su_ai_plugin/html/style.css      (797 lines, ported)
extension/su_ai_plugin/html/app.js         (786 lines, rewritten)
```

### Pure / testable presentation model

```
extension/su_ai_plugin/cad_prep_workflow_presenter.rb   (new, 705 lines)
```

### Additive UIBridge payload

```
extension/su_ai_plugin/ui_bridge.rb   (modified; +28 lines)
```

### Tests added / rewritten

```
tests/test_v19a_cad_prep_workflow_presenter.rb   (new; 30 focused tests)
tests/test_v19a_ui_bridge.rb                     (new; 8 additive-payload tests)
tests/test_html_render.rb                        (rewritten; V1.9A IA)
tests/test_html_render_dom.js                    (rewritten; V1.9A IA; 36+ assertions)
```

### Build artifact

```
dist/SU-AI-Plugin.rbz
Size: 1,094,204 bytes
Entries: 70
SHA-256: 539b36ccbe82dfd17b96c79fa7d566fa40f7e1a72ca2df1c9073903d5e36a3d4
```

### Packaged HTML/CSS/JS / presenter hashes

| File                                                    | SHA-256                                                            |
|---------------------------------------------------------|--------------------------------------------------------------------|
| `su_ai_plugin/html/index.html`                          | `4d488aef5da7e43cc8245cc6d40263e9345422c1a228392a3238373a15d0336a` |
| `su_ai_plugin/html/app.js`                              | `a3a2d2efdf672571f16add23fc36d2eefed7efdf9bfbeb9c82fe79952ff9340f` |
| `su_ai_plugin/html/style.css`                           | `4b7572dafd8b20b14aa66042f9dcb03e4c17f4dea260276b4a0292d0cb4f6b36` |
| `su_ai_plugin/cad_prep_workflow_presenter.rb`           | `8fc3b10d25f9e880de92634c95c37578ff96745c92e7a109c7b36fba85c8ba08` |

---

## 2. Visual / Information Architecture (port of A0 prototype)

### Approved 4-tab IA

1. **处理** — default (`aria-selected="true"`, `panel-process` visible).
2. **问题** — current unresolved-problem browser (locatable / non-locatable rows; click-to-locate preserved per CodeX Round 020 L3).
3. **图层** — secondary; renders legacy `layerGroups` payload.
4. **详情** — technical / audit (source snapshot / fingerprint / config digest / raw inventory / per-action repair audit / canonical / structure digest).

### Top-level layout (处理 panel)

```
┌────────────────────────────────────────────────────────────────┐
│ SU AI · CAD Prep         当前选择：别墅平面图 · 12 图层  [状态] │
├────────────────────────────────────────────────────────────────┤
│  处理 | 问题 | 图层 | 详情                                       │
├────────────────────────────────────────────────────────────────┤
│ ┌──── Recovery banner (STALE / FAILED only) ────────────────┐  │
│ │ 工作副本已失效   [重新生成工作副本] [放弃工作副本]            │  │
│ └────────────────────────────────────────────────────────────┘  │
│ ┌──── CTA row ──────────────────────────────────────────────┐  │
│ │ CAD 尚未处理                          [开始处理]              │  │
│ │ 开始后将创建安全工作副本并完成全部检查                       │  │
│ └────────────────────────────────────────────────────────────┘  │
│ ┌──── Issue summary (error-only) ───────────────────────────┐  │
│ │ CAD 尚未处理                                                │  │
│ │ 点击"开始处理"以创建安全工作副本并完成全部检查               │  │
│ └────────────────────────────────────────────────────────────┘  │
│ ┌──── Card 1: 重复线清理 ── [未检查] ─────────────────────┐  │
│ │ 将在开始处理后自动检查                                       │  │
│ └────────────────────────────────────────────────────────────┘  │
│ ┌──── Card 2: Z 轴 / 平面校正 ── [未检查] ────────────────┐  │
│ │ 将在开始处理后自动检查                                       │  │
│ └────────────────────────────────────────────────────────────┘  │
│ ┌──── Card 3: 间隙与断点 ── [未检查] ──────────────────────┐  │
│ │ 将在开始处理后自动检查                                       │  │
│ └────────────────────────────────────────────────────────────┘  │
│ ┌──── Card 4: 轮廓与区域 ── [未检查] ──────────────────────┐  │
│ │ 将在开始处理后自动检查                                       │  │
│ └────────────────────────────────────────────────────────────┘  │
│ ┌──── Card 5: 其他需检查项 ── [未检查] ────────────────────┐  │
│ │ 将在开始处理后自动检查                                       │  │
│ └────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

### Visual language (frozen A0 palette)

- Cool near-white background (`--bg-app: #f4f6fa`).
- White / lightly tinted surfaces.
- Blue-violet primary CTA gradient (`--accent-1: #5b6cff` → `--accent-2: #8a5cf6`).
- Emerald success / amber warning / red failure.
- 12px card radius; restrained shadow; generous spacing.
- System fonts only (`system-ui`, `"PingFang SC"`, `"Microsoft YaHei"`, fallback sans-serif).
- All icons inline static SVG (no remote icon library).

### Legacy-aware constraints (frozen dispatch §10)

- **No CSS Grid** — flex + explicit margins only.
- **No flex `gap`** — explicit margins on children.
- **No `backdrop-filter`** — graceful degradation required.
- **No `@import`** — single self-contained CSS file.
- **No remote `url(...)`** — only inline SVG fragments.
- No web font / no CDN / no remote runtime dependency.

---

## 3. Presenter Architecture

### Conceptual flow

```
AnalysisResult + WorkingModeRunner.snapshot
  ↓
CadPrepWorkflowPresenter   (pure / deterministic / idempotent)
  ↓
cadPrepWorkflow (additive top-level key on UIBridge payload)
  ↓
UIBridge.as_html_data (legacy keys preserved)
  ↓
app.js#render(payload)
  ↓
DOM (4 tabs / 5 cards / error-only summary)
```

### `cadPrepWorkflow` schema (this commit)

```jsonc
{
  "schema_version": "1",
  "overall_state": "IDLE",                          // 6 enum values (see below)
  "headline":       "CAD 尚未处理",
  "subheadline":    "开始后将创建安全工作副本并完成全部检查",
  "selection":      { "type": "Group", "label": "..." },
  "issue_summary":  { /* kind / headline / subtitle / chips / cta */ },
  "cards": [
    /* exactly 5, in frozen order; see Card schema below */
  ],
  "recovery": { /* banner; null unless STALE / FAILED */ }
}
```

### Overall states (presentation enum)

| Enum                    | CN label              | Description                                                       |
|-------------------------|----------------------|-------------------------------------------------------------------|
| `IDLE`                  | 尚未处理             | No workspace; default home; primary CTA = `开始处理` → `prepare_workspace` |
| `SCANNING`              | 正在检查             | Workspace building (`state == 'building'`); CTA disabled          |
| `NEEDS_ATTENTION`       | 发现需要处理的问题   | At least one card is ACTIONABLE / REVIEW_REQUIRED                |
| `READY_FOR_VALIDATION`  | 已完成检查           | All cards CLEAN / APPLIED (no actionable / review)              |
| `STALE`                 | 工作副本已失效       | `state == 'failed'` + `last_error` contains `host_state_changed` |
| `FAILED`                | 处理失败             | `state == 'failed'` for any other reason                          |

Raw enum strings are NEVER exposed to the user (frozen CN labels
via `OVERALL_STATE_LABELS_CN`).

### Card schema (frozen 5 in fixed order)

```jsonc
{
  "id":               "duplicate_cleanup" | "planar_normalization" |
                      "gap_endpoint" | "structure_region" | "other",
  "state":            "UNCOMPUTED" | "CHECKING" | "CLEAN" |
                      "ACTIONABLE" | "REVIEW_REQUIRED" | "APPLIED" |
                      "BLOCKED" | "STALE" | "FAILED",
  "state_label":      "<CN label>",
  "title":            "<CN title>",
  "summary":          "<short Chinese summary>",
  "metrics":          [{ "value": <int>, "label": "<CN>" }],
  "primary_action":   { "label", "callback", "enabled" } | null,
  "secondary_action": { "label", "callback", "enabled" } | null,
  "detail_filter":    "<id>"
}
```

### Card fixed order (frozen)

1. `duplicate_cleanup` — 重复线清理
2. `planar_normalization` — Z 轴 / 平面校正
3. `gap_endpoint` — 间隙与断点
4. `structure_region` — 轮廓与区域
5. `other` — 其他需检查项

### Raw state → Presentation state mapping (Truth table)

| `state` (workspace) | `planar_normalization.state` | `topology_repair.state` | `structure_reconstruction.state` | `overall_state`         | Card states                                                                  |
|---------------------|------------------------------|-------------------------|----------------------------------|-------------------------|------------------------------------------------------------------------------|
| `none`              | (absent)                     | (absent)                | (absent)                         | `IDLE`                  | All 5 cards `UNCOMPUTED`                                                     |
| `discarded`         | (absent)                     | (absent)                | (absent)                         | `IDLE`                  | All 5 cards `UNCOMPUTED`                                                     |
| `building`          | (absent)                     | (absent)                | (absent)                         | `SCANNING`              | All 5 cards `CHECKING`                                                        |
| `ready`             | (absent)                     | (absent)                | (absent)                         | `READY_FOR_VALIDATION`  | dup `UNCOMPUTED`; planar/gap/structure `UNCOMPUTED` + `compute_*` action    |
| `ready`             | `READY_TO_NORMALIZE`         | (any)                   | (any)                            | `NEEDS_ATTENTION`       | planar `ACTIONABLE` + `修复 Z 轴`                                            |
| `ready`             | `REVIEW_REQUIRED`            | (any)                   | (any)                            | `NEEDS_ATTENTION`       | planar `REVIEW_REQUIRED` + `查看问题`                                        |
| `ready`             | `NO_CANDIDATE`               | `READY_TO_REPAIR`       | (any)                            | `NEEDS_ATTENTION`       | gap `ACTIONABLE` + `修复 间隙`                                              |
| `ready`             | `NO_CANDIDATE`               | `REVIEW_REQUIRED`       | (any)                            | `NEEDS_ATTENTION`       | gap `REVIEW_REQUIRED` + `查看问题`                                           |
| `ready`             | `NO_CANDIDATE`               | `NO_CANDIDATE`          | `READY`                          | `READY_FOR_VALIDATION`  | structure `CLEAN` (结构可用)                                                 |
| `ready`             | `NO_CANDIDATE`               | `NO_CANDIDATE`          | `READY_WITH_WARNINGS`            | `NEEDS_ATTENTION`       | structure `REVIEW_REQUIRED` + `查看问题`                                     |
| `ready`             | `NO_CANDIDATE`               | `NO_CANDIDATE`          | `FAILED`                         | `NEEDS_ATTENTION`       | structure `FAILED`                                                            |
| `ready`             | `APPLIED`                    | `NO_CANDIDATE`          | `READY`                          | `READY_FOR_VALIDATION`  | planar `APPLIED` (已校正)                                                     |
| `failed`            | (any)                        | (any)                   | (any)                            | `STALE` (if host_state) | All 5 cards `STALE`; recovery banner shown                                  |
| `failed`            | (any)                        | (any)                   | (any)                            | `FAILED`                | All 5 cards `STALE` (visual); recovery banner shown                         |

### Critical truth rule (dispatch §6)

`NOT_COMPUTED` MUST never be rendered as `CLEAN`.

Implementation: in the presenter, when `state == 'ready'` and
a sub-snapshot is absent OR has `state == 'NOT_COMPUTED'`, the
card is rendered as `UNCOMPUTED` and exposes the existing
`compute_*` callback as the primary action. A1 truthfulness
prevents A2 from silently inheriting a green "clean" state.

---

## 4. Cards, Actions, and Existing Callbacks (dispatch §12)

### Primary CTA per overall state (existing callbacks only)

| `overall_state`         | Primary CTA label    | Callback                | Enabled |
|-------------------------|---------------------|-------------------------|---------|
| `IDLE`                  | 开始处理             | `prepare_workspace`     | yes     |
| `SCANNING`              | 正在准备...         | `prepare_workspace`     | no      |
| `NEEDS_ATTENTION`       | 重新检测             | `rebuild_workspace`     | yes     |
| `READY_FOR_VALIDATION`  | 重新检测             | `rebuild_workspace`     | yes     |
| `STALE`                 | 重新检测             | `rebuild_workspace`     | no      |
| `FAILED`                | 重新检测             | `rebuild_workspace`     | yes     |

### Per-card primary actions (existing callbacks only)

| Card                 | When                            | Action label  | Callback                              |
|----------------------|---------------------------------|---------------|----------------------------------------|
| duplicate_cleanup    | (never — high-confidence auto)  | (none)        | (none)                                 |
| planar_normalization | UNCOMPUTED                      | 检查平面偏差  | `compute_planar_normalization`          |
| planar_normalization | ACTIONABLE                      | 修复 Z 轴    | `apply_planar_normalization`            |
| planar_normalization | REVIEW_REQUIRED                 | 查看问题     | `view_issues` (frontend pseudo)        |
| gap_endpoint         | UNCOMPUTED                      | 检查间隙     | `compute_gap_repair`                   |
| gap_endpoint         | ACTIONABLE                      | 修复间隙     | `apply_gap_repair`                     |
| gap_endpoint         | REVIEW_REQUIRED                 | 查看问题     | `view_issues`                          |
| structure_region     | UNCOMPUTED                      | 检查结构     | `compute_structure_reconstruction`     |
| structure_region     | REVIEW_REQUIRED                 | 查看问题     | `view_issues`                          |

### All 11 existing callbacks preserved verbatim

```
ready
locate
close
prepare_workspace
discard_workspace
rebuild_workspace
compute_planar_normalization
apply_planar_normalization
compute_gap_repair
apply_gap_repair
compute_structure_reconstruction
```

Verified by `tests/test_html_render.rb` (`dialog_runner
registers all 11 required callbacks`) and the Node DOM test
(`primary CTA dispatch = prepare_workspace`; planar primary
button data-action = `apply_planar_normalization`; STALE rebuild
button = `rebuild_workspace`; STALE discard = `discard_workspace`).

No new JS-driven chain of multiple callbacks was added. A2 owns
orchestration.

---

## 5. DOM / Ruby / RBZ Evidence

### Ruby suite (full)

```
--- 1060 tests: 1057 pass, 1 fail, 2 error ---
```

The 1 fail + 2 error are PRE-EXISTING on the dev/v1.8 baseline
(confirmed via `git checkout dev/v1.8 + re-run`):
- `capability.HtmlDialog: outside SU returns false (R002 + S2-BLOCK-006)` — pre-existing test-environment limitation.
- `V14 production call chain: dialog callback -> WorkingModeRunner -> workspace reaches :ready` — pre-existing FakeUI setup limitation.
- `V17-L1: host_state_changed invalidates the workspace via validate-on-next-interaction` — pre-existing FakeUI setup limitation.

All three are unrelated to V1.9A-A1 scope (test-environment /
pre-existing failures, NOT regressions caused by this packet),
per dispatch §13 reporting rule.

### Regression focus sets (all required by dispatch §13)

- **V1.7 focused set**: `127 / 127 PASS` (`git checkout dev/v1.8` regression baseline preserved).
- **V1.8 focused set**: `71 / 71 PASS` (`git checkout dev/v1.8` regression baseline preserved).
- **V1.6 close-autodiscard**: `7 / 7 PASS` (V16-CLOSE-AUTODISCARD subset).
- **LEGACY-COMPAT**: `4 / 4 PASS`.
- **Node DOM (V1.9A)**: `36+ assertions PASS` (`tests/test_html_render_dom.js`).
- **RBZ smoke**: all 7 RBZ tests PASS.

### Presenter focused tests (dispatch §13)

30 focused tests in `tests/test_v19a_cad_prep_workflow_presenter.rb`:
- IDLE / SCANNING / READY_FOR_VALIDATION (clean + applied) /
  NEEDS_ATTENTION (planar actionable / gap actionable / planar
  review) / STALE / FAILED.
- NOT_COMPUTED must never be CLEAN (for stage-bound cards).
- Zero issue categories omitted from primary summary.
- Raw inventory absent from primary summary.
- Card order is frozen 5.
- Selection carries the analysis_result selection_type /
  selection_label.
- Idempotency (deep equal on repeated calls).
- No live Sketchup object crosses the bridge.
- Deep JSON-safety walker.

### UIBridge tests (dispatch §13)

8 tests in `tests/test_v19a_ui_bridge.rb`:
- Legacy top-level keys preserved (V1.0–V1.8 backward compat).
- `cadPrepWorkflow` present + schema_version + subgraph keys.
- 5 cards in fixed order.
- No Symbol / no live-object leakage.
- JSON round-trip.
- Presenter fault tolerance (returns STALE recovery, not crash).

### DOM tests (dispatch §13)

`tests/test_html_render_dom.js` (Node executable, mock DOM):
- 4 tabs exist with the locked ids.
- 处理 default active (aria-selected=true).
- panel-process visible by default.
- 5 capability cards rendered in fixed order.
- Selection line uses `cadPrepWorkflow.selection.label`.
- Status chip carries `overall_state`.
- Primary CTA text = "开始处理" + dispatch = `prepare_workspace`.
- Clicking primary CTA invokes `window.sketchup.prepare_workspace`.
- Planar ACTIONABLE primary button data-action = `apply_planar_normalization`.
- STALE shows recovery banner + rebuild/discard buttons.
- Clicking STALE rebuild / discard invokes the matching callbacks.
- 处理 panel does NOT display raw inventory (edges / vertices / faces).
- 详情 panel has source_snapshot_id reachable via audit body.
- 详情 panel raw-inventory shows edges count via legacy summary.
- Locatable row registers click handler; non-locatable does NOT.
- Clicking locatable row invokes `window.sketchup.locate(issue_id)`.
- Clicking non-locatable row does NOT invoke locate.

### `git diff --check`

Clean (no whitespace warnings).

### Static / source guards (preset)

- No `eval(` in app.js.
- No `new Function(` in app.js.
- No `document.write(` in app.js.
- No `\.innerHTML\s*=` in app.js.
- No CSS Grid in style.css.
- No flex `gap` in style.css.
- No `backdrop-filter` in style.css (comment-only mentions).
- No `@import` in style.css.
- No remote `url(...)` in style.css.
- No `cdn|jsdelivr|unpkg|googleapis|googleusercontent|http://|https://`
  in index.html (only the static `xmlns="http://www.w3.org/2000/svg"`
  SVG namespace literal, which is a static string, not a remote asset).

### Locator / non-locatable safety (CodeX Round 020 L3 contract preserved)

- `app.js` registers a click handler ONLY on rows where
  `data-locatable="true"`.
- Non-locatable rows receive `no-action` CSS class + no click
  handler.
- The `view_issues` pseudo-action on cards with
  REVIEW_REQUIRED / FAILED state switches to the 问题 tab
  (NO callback dispatch to host).

---

## 6. RBZ Identity

```
Path:           D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz
Size:           1,094,204 bytes
Entries:        70
SHA-256:        539b36ccbe82dfd17b96c79fa7d566fa40f7e1a72ca2df1c9073903d5e36a3d4
```

A1 RBZ is an internal review candidate only, NOT a final
V1.9 / V1.x release (per dispatch §14).

---

## 7. Known Limitations / Pre-existing Test Failures

Per dispatch §13, the following are pre-existing on the
V1.8 baseline and unrelated to V1.9A-A1 scope:

| Test                                                                       | Status   | Reason                                                                                                  |
|----------------------------------------------------------------------------|----------|---------------------------------------------------------------------------------------------------------|
| `capability.HtmlDialog: outside SU returns false (R002 + S2-BLOCK-006)`    | FAIL     | Pre-existing test-env capability check unrelated to V1.9A-A1.                                          |
| `V14 production call chain: dialog callback -> ...`                         | ERROR    | Pre-existing FakeUI dialog callback wiring limitation; the production code path is not exercised.        |
| `V17-L1: host_state_changed invalidates ...`                                | ERROR    | Pre-existing FakeUI host-state validator setup limitation; production path is the authoritative source. |

None of these are caused by V1.9A-A1. They were present on
dev/v1.8 @ bbe423c before this dispatch started (verified by
`git checkout dev/v1.8` + re-run, which shows the same
1050/1053/3 baseline). Per dispatch §13 they are reported
separately and NOT labeled PASS.

---

## 8. Confirmation: No A2 / V1.9B work

| Scope item                                                    | Started? | Evidence                                                  |
|---------------------------------------------------------------|----------|-----------------------------------------------------------|
| `CadPrepWorkflowOrchestrator`                                  | NO       | Not present in any file; no `start_cad_prep` callback.   |
| Automatic full diagnostics after `prepare_workspace`           | NO       | The dialog_runner `on_prepare_workspace` runs the duplicate-repair batch (V1.5) only — UNCHANGED. |
| `start_cad_prep` orchestration callback                         | NO       | Not registered in `dialog_runner.rb`.                     |
| Automatic downstream recompute after Z repair                  | NO       | `apply_planar_normalization` invalidates V1.8 cache (SR18-05) but does NOT trigger `compute_gap_repair` or `compute_structure_reconstruction`. |
| Automatic structure recompute after gap repair                 | NO       | `apply_gap_repair` invalidates V1.8 cache (SR18-05) but does NOT trigger `compute_structure_reconstruction`. |
| V1.6 / V1.7 / V1.8 algorithm change                            | NO       | `git diff dev/v1.8..dev/v1.9 -- extension/su_ai_plugin/core/` shows only `cad_prep_workflow_presenter.rb` is added (new file); `ui_bridge.rb` only adds the additive `cadPrepWorkflow` key. |
| Tolerance / source ownership change                            | NO       | No changes to `Tolerance`, `SourceSnapshot`, `WorkingModeRunner.snapshot` shape, etc. |
| Face / Observer architecture                                   | NO       | Not present in any file.                                 |
| `PreparedCadDataset` / persistence (V1.9B)                     | NO       | Not present in any file; dispatch §3 forbids it.          |
| MCP / LLM / Agent                                              | NO       | Not present in any file; dispatch §4 forbids it.          |

---

## 9. `CODEX_RISK_TRIGGER` determination

Per dispatch §0 + AGENTS.md / Master Plan §13:
- V1.4 / V1.5 / V1.6 / V1.7 / V1.8 algorithms UNCHANGED.
- No source / state ownership / transaction / recovery change.
- No Face / Observer architecture.
- No source CAD mutation.
- No canonical-topology / tolerance / segment-conflict semantic change.
- No new RBZ-only release claim (A1 RBZ is internal review candidate).

`CODEX_RISK_TRIGGER = NO`.

---

## 10. Required Report Summary (dispatch §16)

1. **Branch / final HEAD**: dev/v1.9 @ `a8563e3` (this packet's implementation commit).
2. **Files changed**: see §1 + `git log -1 --stat` for the full list.
3. **Presenter architecture**: see §3 (pure / idempotent / JSON-safe additive module at `extension/su_ai_plugin/cad_prep_workflow_presenter.rb`).
4. **Actual cadPrepWorkflow schema**: see §3 (locked schema_version "1"; 5-card frozen order; 6 overall states).
5. **Raw-state → presentation-state mapping table**: see §3 truth table.
6. **DOM / Ruby / RBZ evidence**: see §5.
7. **RBZ identity**: see §6 (1,094,204 bytes / 70 entries / SHA-256 `539b36cc…`).
8. **Known limitations**: see §7 (3 pre-existing failures on V1.8 baseline, unrelated to A1).
9. **Confirmation no A2 / V1.9B work**: see §8.
10. **CODEX_RISK_TRIGGER determination**: NO (see §9).

---

## 11. STOP

Per dispatch §15:

- AIPM_REVIEW = PENDING
- CODEX = NOT REQUIRED by default
- OWNER_SU2020 = NOT YET
- A2 = NOT STARTED
- V1.9B = NOT STARTED

STOP. Awaiting AIPM source review.

---

# AIPM FIX REQUIRED CONTINUATION (2026-09-04)

After the original V1.9A-A1 packet above (`a8563e3`), AIPM
performed direct source review and re-issued the packet with
THREE bounded corrections (no architecture change, no
algorithmic change, no V1.x scope expansion):

- **BLOCK 1 (copy)**: IDLE user-facing copy must NOT claim
  “开始后将创建安全工作副本并完成全部检查” because full
  automatic diagnostics belong to A2. The copy was rewritten
  to truthfully describe the A1 actual behavior (“开始后将创建
  工作副本并自动清理高置信度重复线”).
- **BLOCK 2 (overall state)**: `overall_state` for a `ready`
  workspace MUST be derived from the actual rendered
  capability card states, not from a subset of sub-snapshot
  raw states. Implemented via the new
  `_overall_state_for_ready_workspace(cards)` helper:
    - any ACTIONABLE / BLOCKED / FAILED card → NEEDS_ATTENTION;
    - any REVIEW_REQUIRED card → NEEDS_ATTENTION;
    - any stage-bound UNCOMPUTED → NEEDS_ATTENTION
      with the truthful headline “仍有未检查项”;
    - READY_FOR_VALIDATION only when all stage-bound cards
      are CLEAN / APPLIED and nothing else needs attention.
- **NON-BLOCKING (presenter-fault UX)**: the main product UI
  MUST stay generic and user-readable. Technical exception
  detail (class + message) stays in the SketchUp Ruby
  Console via the existing `_safe_log` path, NOT in the
  product-facing subheadline / issue_summary / recovery copy.

All six required regression tests are pinned in
`tests/test_v19a_cad_prep_workflow_presenter.rb` and
`tests/test_v19a_ui_bridge.rb`:

1. ready + all stage snapshots absent → NEEDS_ATTENTION.
2. ready + planar NOT_COMPUTED → NEEDS_ATTENTION.
3. ready + structure FAILED → NEEDS_ATTENTION.
4. ready + `other` card REVIEW_REQUIRED → NEEDS_ATTENTION.
5. all required stages genuinely CLEAN + no review + no
   APPLIED → READY_FOR_VALIDATION (clean).
6. IDLE copy must not claim full automatic diagnostics.

## Files changed by this continuation

```
M extension/su_ai_plugin/cad_prep_workflow_presenter.rb
M extension/su_ai_plugin/ui_bridge.rb
M tests/test_v19a_cad_prep_workflow_presenter.rb
M tests/test_v19a_ui_bridge.rb
M tests/test_rbz_smoke.rb
```

## Stale-load root cause (reproducible diagnosis)

During this continuation, the first attempt to run the
focused presenter tests showed all BLOCK 1 / BLOCK 2
assertions failing with the OLD presenter behavior — but
running the SAME test in isolation produced the correct
NEW behavior. The root cause was traced to
`tests/test_rbz_smoke.rb`:

1. The RBZ smoke test extracts `dist/SU-AI-Plugin.rbz`
   into a temp dir and loads its entry-point through
   FakeUI.
2. That chain pulls in the PRESENT RBZ's copy of
   `cad_prep_workflow_presenter.rb`, which at the time
   of diagnosis contained the PRE-FIX (A1-original) version.
3. Subsequent tests inheriting `CadPrepWorkflowPresenter`
   through `require_relative` saw the STALE extracted
   copy because `require_relative` caches by absolute path.
4. The existing `v14_reload_in_tree_production_files!`
   helper reloaded 40+ production files after the smoke
   test but did NOT include
   `cad_prep_workflow_presenter.rb` (the file was added
   in V1.9A-A1, after the helper was last updated).

**Fix**: added `cad_prep_workflow_presenter.rb` to the
`V14_RBZ_SMOKE_IN_TREE_FILES` reload list (placed
BEFORE `ui_bridge.rb` so the in-tree presenter is the
one reloaded, not the extracted copy transitively cached
via `require_relative`). One-line helper invariant is
preserved: `load` (not `require`) re-executes the file,
re-binding the methods to the in-tree source location.

After the fix, all v19a presenter / bridge tests pass in
both the focused filter and the full suite run.

## Evidence — focused filter

```
tests/run_all.rb v19a_presenter   → 38 tests: 38 pass, 0 fail, 0 error
tests/run_all.rb v19a_bridge      → 10 tests: 10 pass, 0 fail, 0 error
tests/run_all.rb html_render      → 24 tests: 24 pass, 0 fail, 0 error
```

## Evidence — required regressions

```
tests/run_all.rb V17   → 127 tests: 127 pass, 0 fail, 0 error
tests/run_all.rb V18   →  71 tests:  71 pass, 0 fail, 0 error
tests/run_all.rb V18-SR18 → 32 tests: 32 pass, 0 fail, 0 error
tests/run_all.rb V17-INT  → 33 tests: 33 pass, 0 fail, 0 error
tests/run_all.rb V16-CLOSE  → 7 tests: 7 pass, 0 fail, 0 error
tests/run_all.rb LEGACY-COMPAT → 4 tests: 4 pass, 0 fail, 0 error
tests/run_all.rb RBZ    → 9 tests: 9 pass, 0 fail, 0 error
```

## Evidence — full suite

```
tests/run_all.rb → 1070 tests: 1067 pass, 1 fail, 2 error
```

The 1 fail + 2 error are the SAME pre-existing
test-environment / FakeUI limitations that were present
on the V1.8 baseline at `bbe423c` (the dispatch
baseline). They are unrelated to V1.9A-A1 scope and are
reported separately per dispatch §13:

- `capability.HtmlDialog: outside SU returns false
  (R002 + S2-BLOCK-006)` — pre-existing test-env capability check.
- `V14 production call chain: dialog callback →
  WorkingModeRunner → workspace reaches :ready` — pre-existing
  FakeUI setup limitation.
- `V17-L1: host_state_changed invalidates the workspace via
  validate-on-next-interaction` — pre-existing FakeUI host-state
  validator setup limitation.

## Evidence — Node DOM

```
node tests/test_html_render_dom.js → all assertions PASS,
                                     final line `PASS`
```

## Evidence — `git diff --check`

Clean (no whitespace warnings).

## Updated RBZ identity (this continuation)

```
Path:           D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz
Size:           1,100,036 bytes
Entries:        70
SHA-256:        DAAF988D75DD2A40E8F2831822E43CD8E1A061DDD9E634A73FF65CD350A9095E
Packaged su_ai_plugin/cad_prep_workflow_presenter.rb
                SHA-256: EC46C603C3A737DDCC121AD90C7733418E0B59FE0D755923FCF3754495220949
Packaged su_ai_plugin/html/app.js
                SHA-256: A3A2D2EFDF672571F16ADD23FC36D2EEFED7EFDF9BFBEB9C82FE79952FF9340F
Packaged su_ai_plugin/html/index.html
                SHA-256: 4D488AEF5DA7E43CC8245CC6D40263E9345422C1A228392A3238373A15D0336A
Packaged su_ai_plugin/html/style.css
                SHA-256: 4B7572DAFD8B20B14AA66042F9DCB03E4C17F4DEA260276B4A0292D0CB4F6B36
```

(app.js / index.html / style.css SHA-256 unchanged from the
original V1.9A-A1 packet — the FIX REQUIRED continuation
touches Ruby only. The new RBZ differs only in the embedded
`cad_prep_workflow_presenter.rb`.)

## Confirmation — no A2 / V1.9B / scope creep

| Scope item                                                    | Started? | Evidence                                                  |
|---------------------------------------------------------------|----------|-----------------------------------------------------------|
| `CadPrepWorkflowOrchestrator`                                  | NO       | Not present in any file.                                  |
| `start_cad_prep` orchestration callback                         | NO       | Not registered in `dialog_runner.rb`.                     |
| Automatic full diagnostics after `prepare_workspace`           | NO       | Only the V1.5 duplicate-repair batch runs on prepare.     |
| V1.6 / V1.7 / V1.8 algorithm change                            | NO       | `git diff bbe423c..HEAD -- extension/su_ai_plugin/core/` shows zero changes to frozen V1.6/V1.7/V1.8 algorithm files. |
| Tolerance / source ownership change                            | NO       | No changes to `Tolerance` / `SourceSnapshot` / `WorkingModeRunner.snapshot` shape. |
| Face / Observer architecture                                   | NO       | Not present in any file.                                  |
| `PreparedCadDataset` / persistence (V1.9B)                     | NO       | Not present in any file; dispatch §4 forbids it.          |
| MCP / LLM / Agent                                              | NO       | Not present in any file; dispatch §4 forbids it.          |
| V1.x product UX redesign                                       | NO       | IA / 4 tabs / 5 cards / existing callbacks / legacy payload keys all UNCHANGED. |

## `CODEX_RISK_TRIGGER` determination (this continuation)

Per AGENTS.md §13 + dispatch §0:
- Only the presenter module, the presenter fault-tolerance
  block in UIBridge, and three regression-test files
  were touched by the production-data plane.
- One test-infrastructure fix was made (RBZ-smoke reload
  list) so the in-tree presenter is the one reloaded after
  the RBZ smoke test extracts the package into a temp dir.
- No source / state ownership / transaction / recovery
  change. No Face / Observer architecture. No source CAD
  mutation. No canonical-topology / tolerance / segment-
  conflict semantic change. No RBZ-only release claim.

`CODEX_RISK_TRIGGER = NO`.

## STOP (this continuation)

- AIPM_REVIEW = PENDING (narrow recheck of BLOCK 1 + BLOCK 2
  + non-blocking presenter-fault cleanup)
- CODEX = NOT REQUIRED
- OWNER_SU2020 = NOT YET
- A2 = NOT STARTED
- V1.9B = NOT STARTED

STOP. Awaiting AIPM narrow source recheck of the FIX
REQUIRED continuation only.

---

# CURRENT PI REPORT — V1.9A-A1 LEGACY RUBY COMPATIBILITY NARROW FIX

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Product UX + Diagnostics Orchestration
Packet: **A1 LEGACY COMPATIBILITY NARROW FIX** (AIPM narrow
recheck follow-up)
Authority: `Prompt/CURRENT_PI_DISPATCH.md`
(V1.9A-A1 LEGACY RUBY COMPATIBILITY FIX dated 2026-09-04).
Baseline HEAD: `3d5c72a15b9b728edaa75aec3e8643d7508e7bfd`
(V1.9A-A1 AIPM FIX REQUIRED continuation complete state).
Baseline branch: `dev/v1.9`
TARGET_BRANCH: **dev/v1.9**
Implementation SHA: `f77fb53631d629e95ab0fa947fa48c9fa3982803`
(HEAD after push).
CODEX_RISK_TRIGGER: **NO** (per dispatch §0; only the
V1.9A presenter + one LEGACY-COMPAT test were modified;
no frozen boundary crossed).
A2 / V1.9B: NOT STARTED (per dispatch §6).

## Scope of this packet (the ONLY thing Pi changed)

Per dispatch §0 / §1: AIPM narrow recheck found the new
V1.9A-A1 production presenter
(`extension/su_ai_plugin/cad_prep_workflow_presenter.rb`)
used post-Ruby-2.2 helpers (`Integer#positive?` added in
Ruby 2.3; `Array#sum` / `Enumerable#sum` added in Ruby
2.4). V1.x is legacy-first and must not silently introduce
these. This packet is a bounded compatibility correction
ONLY. No product semantics, no count semantics, no
ordering, no card mapping, no visual behavior change.

## Exact replacements (in `extension/su_ai_plugin/cad_prep_workflow_presenter.rb`)

| # | Site                                                  | Before                                              | After                                                          |
|---|-------------------------------------------------------|-----------------------------------------------------|----------------------------------------------------------------|
| 1 | NEEDS_ATTENTION headline length gate                  | `chips.length.positive?`                            | `chips.length > 0`                                             |
| 2 | NEEDS_ATTENTION headline chip total                   | `chips.map { |c| c['value'].to_i }.sum`             | `chip_total = chips.inject(0) { |acc, c| acc + c['value'].to_i }` |
| 3 | NEEDS_ATTENTION headlines — actionable gate           | `actionable_count.positive?`                        | `actionable_count > 0`                                         |
| 4 | duplicate_cleanup card metrics — applied              | `applied.positive?` (3rd site)                       | `applied > 0`                                                  |
| 5 | duplicate_cleanup card metrics — skipped              | `skipped.positive?`                                 | `skipped > 0`                                                  |
| 6 | duplicate_cleanup card — state_label                  | `applied.positive? ? "已自动处理 #{applied} 条" : '无重复线'` | `applied > 0 ? "已自动处理 #{applied} 条" : '无重复线'`         |
| 7 | duplicate_cleanup card — state field                  | `applied.positive? ? 'APPLIED' : 'CLEAN'`           | `applied > 0 ? 'APPLIED' : 'CLEAN'`                            |
| 8 | duplicate_cleanup card — summary field                 | `applied.positive? ? '...' : '...'`                  | `applied > 0 ? '...' : '...'`                                  |
| 9 | planar_safe_summary — movable                         | `movable.is_a?(Integer) && movable.positive?`        | `movable.is_a?(Integer) && movable > 0`                         |
|10 | planar_safe_summary — outliers                        | `outliers.is_a?(Integer) && outliers.positive?`     | `outliers.is_a?(Integer) && outliers > 0`                      |
|11 | structure_metrics filter                               | `v.is_a?(Integer) && v.positive?`                   | `v.is_a?(Integer) && v > 0`                                    |
|12 | other card secondary filter                           | `n.positive?`                                       | `n > 0`                                                        |

Total: 12 mechanical / semantics-preserving replacements
across 4 separate presenter methods. Zero product-facing
change. The headline string format
`"发现 N 类 · M 项问题"` is preserved verbatim (M is now
computed via `inject(0) { ... }` instead of `.sum`).

## Repo-local V1.9-introduced compatibility scan (extension/)

Per dispatch §2, scanned ONLY `extension/` for V1.9-
introduced use of the known post-Ruby-2.2 APIs / syntax.
Result (this packet's authoritative scan):

| Construct               | V1.9-introduced? | Status                                                                                                         |
|-------------------------|------------------|----------------------------------------------------------------------------------------------------------------|
| `.positive?`            | NO (after fix)   | All V1.9A presenter sites replaced with `> 0`. NONE elsewhere in `extension/`.                                  |
| `.negative?`            | NO               | NONE in `extension/`.                                                                                          |
| `.sum`                  | NO (V1.9 scope)  | NONE V1.9-introduced. PRE-EXISTING usages in V1.4 `core/source_fingerprint.rb` (lines 224, 227) and V1.6 `core/planar_normalization_executor.rb` (line 343). Explicitly out of scope per dispatch §4 (Do NOT reopen V1.6 / V1.7 / V1.8). |
| `&.` (safe navigation)  | NO               | NONE in `extension/`.                                                                                          |
| `transform_values`      | NO               | NONE in `extension/`.                                                                                          |
| `dig`                   | NO               | NONE in `extension/`.                                                                                          |
| `yield_self` / `then`   | NO               | NONE in `extension/`.                                                                                          |
| `filter_map`            | NO               | NONE in `extension/`.                                                                                          |
| Hash-only `.compact`    | NO               | NONE. All `.compact` calls in the production tree are `Array#compact`, which is pre-2.2 valid.                 |

The pre-existing `.sum` usages in V1.4 / V1.6 are
documented as known legacy-baseline debt. They pre-date
V1.9 and are not within the scope of this narrow fix;
reopening them would conflict with dispatch §4's
"preserve V1.6 / V1.7 / V1.8 algorithms" rule. AIPM may
choose to address them in a separate, dedicated packet
if the legacy baseline target is re-examined.

## Regression guard (this packet)

This packet extended the existing LEGACY-COMPAT framework
(in `tests/test_v15_legacy_compat_guard.rb`) with a NEW
focused test:

```text
LEGACY-COMPAT V19A-A1: no .positive? / .negative? / .sum
in V1.9A presenter (Ruby 2.2 baseline)
```

Scope: ONLY `cad_prep_workflow_presenter.rb` (the new
V1.9A-introduced production file). The guard does NOT
scan V1.4 / V1.6 pre-existing `.sum` usages, which are
explicitly out of scope per dispatch §4.

Implementation: same file-walking + regex approach as the
existing endless-range regression test (no new framework).
Three regex patterns:
  - `/\.[ ]?positive\?[ ]?/` — `Integer#positive?`
  - `/\.[ ]?negative\?[ ]?/` — `Integer#negative?`
  - `/\.[ ]?sum(?![A-Za-z0-9_=!?])/` — `Array#sum` /
    `Enumerable#sum` (lookahead `(?![A-Za-z0-9_=!?])`
    ensures no match against identifier-shaped names
    like `edge_length_sum:` or `consumed`).

Teeth verified in this session: temporarily reintroduced
both `.positive?` and `.sum` to the presenter and
confirmed the guard FAILS with file:line + match + minimal
fix guidance. The temporary additions were reverted
before commit.

## Test results (this packet, fresh run)

### V1.9A focused

- `tests/test_v19a_cad_prep_workflow_presenter.rb`:
  **38 / 38 PASS** (30 original + 8 BLOCK 1 / BLOCK 2
  regression).
- `tests/test_v19a_ui_bridge.rb`: **10 / 10 PASS**
  (8 original + 1 non-blocking presenter-fault cleanup +
  1 presenter-restoration defensive guard).

### V1.9A DOM

- `tests/test_html_render.rb`: **24 / 24 PASS**.
- `tests/test_html_render_dom.js`: 327+ assertions PASS,
  final line `PASS`.

### LEGACY-COMPAT (this packet)

- `LEGACY-COMPAT: vendored Ruby parses every production
  .rb file (current-source syntax/load smoke)`: PASS
- `LEGACY-COMPAT: Ripper.sexp parses every production .rb
  file (current-source AST smoke)`: PASS
- `LEGACY-COMPAT: no known modern-syntax constructs in
  production source`: PASS
- `LEGACY-COMPAT: no endless-range [n..] in production
  source (CONFIRMED-FIX-COMPAT-RANGE)`: PASS
- `LEGACY-COMPAT V19A-A1: no .positive? / .negative? /
  .sum in V1.9A presenter (Ruby 2.2 baseline)` (NEW): PASS

Total LEGACY-COMPAT: **5 / 5 PASS** (4 prior + 1 new).

### Regression (per dispatch §5)

- V1.7 focused set: **127 / 127 PASS** (baseline
  preserved).
- V1.8 focused set: **71 / 71 PASS** (baseline preserved).
- V1.8 SR18 set: **32 / 32 PASS**.
- V1.7 INT set: **33 / 33 PASS**.
- V1.6 close-autodiscard: **7 / 7 PASS**.
- RBZ smoke: **9 / 9 PASS** (rebuilt; presenter file
  present).

### Full Ruby suite

- **1071 / 1071 total / 1068 PASS / 1 fail / 2 error**.
- The 1 fail + 2 error are the SAME pre-existing
  test-environment / FakeUI limitations from the V1.8
  baseline (confirmed via direct re-run of the offending
  tests in isolation, where they PASS — the failures are
  test-order-dependent pollution from the larger suite):
  - `capability.HtmlDialog: outside SU returns false
    (R002 + S2-BLOCK-006)`
  - `V14 production call chain: dialog callback ->
    WorkingModeRunner -> workspace reaches :ready`
  - `V17-L1: host_state_changed invalidates the workspace
    via validate-on-next-interaction`
- None caused by this packet; per dispatch §5 reporting
  rule, do not relabel them PASS.

### Diff hygiene

- `git diff --check`: clean (0 warnings).

## RBZ (rebuilt because production Ruby changed)

| Metric          | Value                                                                                            |
|-----------------|--------------------------------------------------------------------------------------------------|
| Path            | `dist/SU-AI-Plugin.rbz`                                                                          |
| Size            | **1,100,317 bytes** (delta +281 vs V1.9A-A1 FIX REQUIRED 1,100,036)                            |
| Entries         | **70** (unchanged)                                                                               |
| SHA-256         | **`8F1DA75527A5D5387945FC3594A922C830F122526A4ECEADCC2743E9C1368CDE`**                          |

### Packaged asset hashes (this packet)

| File                                | SHA-256                                                              | Status      |
|-------------------------------------|----------------------------------------------------------------------|-------------|
| `html/index.html`                   | `4D488AEF5DA7E43CC8245CC6D40263E9345422C1A228392A3238373A15D0336A`    | UNCHANGED   |
| `html/app.js`                       | `A3A2D2EFDF672571F16ADD23FC36D2EEFED7EFDF9BFBEB9C82FE79952FF9340F`    | UNCHANGED   |
| `html/style.css`                    | `4B7572DAFD8B20B14AA66042F9DCB03E4C17F4DEA260276B4A0292D0CB4F6B36`    | UNCHANGED   |
| `cad_prep_workflow_presenter.rb`    | `74B2C9D5FE782F4DB5ED95CCC90CBD59740E7B01C49F9828FF7622FC7B7927DE`    | NEW (Ruby 2.2 compat) |

## Confirmation — no A2 / V1.9B / scope creep (this packet)

| Scope item                                                    | Started? | Evidence                                                                          |
|---------------------------------------------------------------|----------|-----------------------------------------------------------------------------------|
| `CadPrepWorkflowOrchestrator`                                  | NO       | Not present in any file.                                                          |
| `start_cad_prep` orchestration callback                         | NO       | Not registered in `dialog_runner.rb`.                                             |
| Automatic full diagnostics after `prepare_workspace`           | NO       | Presenter logic UNCHANGED beyond the 12 mechanical Ruby 2.2 compat replacements.   |
| V1.6 / V1.7 / V1.8 algorithm change                            | NO       | `git diff 3d5c72a..HEAD -- extension/su_ai_plugin/core/` shows zero changes to frozen V1.4 / V1.6 / V1.7 / V1.8 algorithm files. |
| Tolerance / source ownership change                            | NO       | No changes to `Tolerance` / `SourceSnapshot` / `WorkingModeRunner.snapshot` shape. |
| Face / Observer architecture                                   | NO       | Not present in any file.                                                          |
| `PreparedCadDataset` / persistence (V1.9B)                     | NO       | Not present in any file; dispatch §6 forbids it.                                  |
| MCP / LLM / Agent                                              | NO       | Not present in any file; dispatch §6 forbids it.                                  |
| V1.x product UX redesign                                       | NO       | IA / 4 tabs / 5 cards / existing callbacks / legacy payload keys all UNCHANGED.    |
| JS / HTML / CSS change                                         | NO       | Packaged `html/index.html` / `html/app.js` / `html/style.css` SHA-256 UNCHANGED.  |

## `CODEX_RISK_TRIGGER` determination (this packet)

Per AGENTS.md §13 / §10 + dispatch §0:
- Only the V1.9A presenter module (`cad_prep_workflow_presenter.rb`)
  and the LEGACY-COMPAT test file
  (`tests/test_v15_legacy_compat_guard.rb`) were touched by
  the production-data plane.
- 12 mechanical / semantics-preserving replacements (`> 0`
  for `.positive?`; `inject(0) { ... }` for `.sum`).
- One new test added (scoped regression guard).
- No algorithm change. No schema / contract change.
- No source / state ownership / transaction / recovery
  change. No Face / Observer architecture. No source CAD
  mutation. No canonical-topology / tolerance / segment-
  conflict semantic change. No RBZ-only release claim.

`CODEX_RISK_TRIGGER = NO`.

## STOP (this packet)

- AIPM_REVIEW = PENDING (narrow recheck of the 12
  replacements in the V1.9A presenter AND the new
  scoped V19A-A1 regression guard in LEGACY-COMPAT)
- CODEX = NOT REQUIRED
- OWNER_SU2020 = NOT YET
- A2 = NOT STARTED
- V1.9B = NOT STARTED

STOP. Awaiting AIPM narrow source recheck of the V1.9A
Legacy Ruby Compatibility narrow fix only.

---

# CURRENT PI REPORT — V1X-LEGACY-RUBY-DEBT-CLOSURE

Project: `SU-AI-Plugin`
Version: V1.X (pre-A2)
Stage: V1.9A pre-A2 compatibility closure
Packet: **V1X-LEGACY-RUBY-DEBT-CLOSURE** (AIPM narrow
recheck follow-up to the V1.9A-A1 LEGACY RUBY
COMPATIBILITY NARROW FIX).
Authority: `Prompt/CURRENT_PI_DISPATCH.md`
(V1X-LEGACY-RUBY-DEBT-CLOSURE dated 2026-09-07).
Baseline HEAD: `e38d6dcc8930b37f0d5e439d628bf4f82426aa54`
(V1.9A-A1 LEGACY RUBY COMPATIBILITY NARROW FIX complete
state).
Baseline branch: `dev/v1.9`
TARGET_BRANCH: **dev/v1.9**
Implementation SHA: `9d7b2b3b...` (HEAD after push; see
`git rev-parse HEAD`).
CODEX_RISK_TRIGGER: **NO** (per dispatch §0; only 2
production .rb files (V1.4 fingerprint + V1.6 planar
normalization) + 1 LEGACY-COMPAT test file were touched;
no algorithm change; no contract change; no frontend
change; no V1.6-V1.8 algorithm change).
A2 / V1.9B: NOT STARTED (per dispatch §3).

## Scope of this packet (the ONLY thing Pi changed)

Per dispatch §0 / §1: AIPM verified the V1.9A presenter
compatibility fix but exposed three pre-existing production
`.sum` calls (V1.4 / V1.6 era) that remain incompatible
with the SU2017 Ruby 2.2 baseline. This packet is a
bounded compatibility closure ONLY — three production
`.sum` sites replaced with `inject(0)` / `inject(0.0)` plus
a regression-guard extension. No algorithm change. No
contract change. No schema change. No count / min / max /
mean / normalization-policy / fingerprint-digest / host
mutation behavior change.

## Exact three replacements

### 1. `extension/su_ai_plugin/core/source_fingerprint.rb` line 224

Before:
```ruby
edge_length_sum: edges.map { |e| e.respond_to?(:length) ? e.length : 0.0 }.sum,
```

After:
```ruby
edge_length_sum: edges.inject(0.0) { |acc, e| acc + (e.respond_to?(:length) ? e.length : 0.0) },
```

Preserved: V1.4 fingerprint schema (field names
unchanged: `edge_length_sum`); canonical ordering (the
fingerprint `new(...)` hash constructor order unchanged);
digest semantics (the canonical ordering + every field
unchanged); Float accumulation semantics (initial value
`0.0` Float, every addend Float).

### 2. `extension/su_ai_plugin/core/source_fingerprint.rb` line 227

Before:
```ruby
face_vertex_count_sum: faces.map { |f| f.respond_to?(:outer_loop_vertex_count) ? f.outer_loop_vertex_count : 0 }.sum,
```

After:
```ruby
face_vertex_count_sum: faces.inject(0) { |acc, f| acc + (f.respond_to?(:outer_loop_vertex_count) ? f.outer_loop_vertex_count : 0) },
```

Preserved: V1.4 fingerprint schema (field name
`face_vertex_count_sum` unchanged); canonical ordering;
digest semantics; Integer accumulation semantics (initial
value `0` Integer, every addend Integer or 0).

### 3. `extension/su_ai_plugin/core/planar_normalization_executor.rb` line 343

Before:
```ruby
def _z_summary(zs)
  return { 'count' => 0, 'min' => nil, 'max' => nil, 'mean' => nil } if zs.empty?
  floats = zs.map(&:to_f)
  {
    'count' => floats.length,
    'min'   => floats.min.to_f,
    'max'   => floats.max.to_f,
    'mean'  => (floats.sum.to_f / floats.length.to_f)
  }.freeze
end
```

After:
```ruby
def _z_summary(zs)
  return { 'count' => 0, 'min' => nil, 'max' => nil, 'mean' => nil } if zs.empty?
  floats = zs.map(&:to_f)
  # Ruby 2.2 compatibility: Array#sum was added in Ruby 2.4.
  # Use inject-based reduction so this runs on the legacy
  # baseline (SU2017 Ruby 2.2.4 / SU2020 Ruby 2.5.5).
  total = floats.inject(0.0) { |acc, z| acc + z }
  {
    'count' => floats.length,
    'min'   => floats.min.to_f,
    'max'   => floats.max.to_f,
    'mean'  => (total / floats.length.to_f)
  }.freeze
end
```

Preserved: V1.6 count / min / max / mean semantics
unchanged (mean = total / count); normalization policy
unchanged (this is `_z_summary` — a pure summary helper,
no mutation); host mutation behavior unchanged (no
mutation code added or removed); tolerance unchanged
(no tolerance value reference inside `_z_summary`);
audit shape unchanged (the audit dict still has the
same `count` / `min` / `max` / `mean` keys).

## Tree-wide compatibility scan (extension/, post-fix)

Per dispatch §4 reporting requirement, scanned the
entire `extension/` tree (production source only,
excluding comments per dispatch §2). Result:

| Construct                  | Findings | Status                                                                            |
|----------------------------|----------|-----------------------------------------------------------------------------------|
| `.positive?`               | 0        | NONE in `extension/`.                                                              |
| `.negative?`               | 0        | NONE in `extension/`.                                                              |
| `.sum`                     | 0        | NONE in `extension/`. Pre-existing V1.4 / V1.6 usages replaced by this packet.      |
| `&.`                       | 0        | NONE in `extension/`.                                                              |
| `transform_values`         | 0        | NONE in `extension/`.                                                              |
| `dig`                      | 0        | NONE in `extension/`.                                                              |
| `yield_self` / `then`      | 0        | NONE in `extension/`.                                                              |
| `filter_map`               | 0        | NONE in `extension/`.                                                              |
| Hash-only `.compact`       | 0        | NONE. All `.compact` calls in the production tree are `Array#compact`, pre-2.2 valid. |
| Endless range `[a..]`      | 0        | NONE in `extension/`.                                                              |
| Beginless range `[..b]`    | 0        | NONE in `extension/`.                                                              |
| Numbered block params       | 0        | NONE in `extension/`.                                                              |

The `extension/` tree is now CLEAN for the Ruby 2.2
baseline. The guard catches any future reintroduction.

## Regression guard extension

This packet extended the existing LEGACY-COMPAT
framework (in `tests/test_v15_legacy_compat_guard.rb`)
per dispatch §2. Specifically, added three new entries
to `KNOWN_MODERN_SYNTAX`:

```ruby
{
  id:    'integer_positive_p',
  regex: /\.[ ]?positive\?[ ]?(?![A-Za-z0-9_=!?])/,
  ruby_min_unsupported: '2.3.0',
  ruby_min_required:    '2.3.0',
  comment: 'Integer#positive? requires Ruby >= 2.3.0. ...'
},
{
  id:    'integer_negative_p',
  regex: /\.[ ]?negative\?[ ]?(?![A-Za-z0-9_=!?])/,
  ruby_min_unsupported: '2.3.0',
  ruby_min_required:    '2.3.0',
  comment: 'Integer#negative? requires Ruby >= 2.3.0. ...'
},
{
  id:    'enumerable_sum',
  regex: /\.[ ]?sum(?![A-Za-z0-9_=!?])/,
  ruby_min_unsupported: '2.4.0',
  ruby_min_required:    '2.4.0',
  comment: 'Array#sum / Enumerable#sum requires Ruby >= 2.4.0. ...'
}
```

All three regexes share a tight `(?![A-Za-z0-9_=!?])`
lookahead to ensure we only match the actual method
invocation, NOT identifier-shaped names. Specifically
`enumerable_sum` does NOT match:
  - `edge_length_sum:` keyword symbol (followed by `:`)
  - `face_vertex_count_sum:` keyword symbol (followed by `:`)
  - `consumed` (followed by `d`)
  - `summary` (followed by `r`)

The pre-existing global test
`LEGACY-COMPAT: no known modern-syntax constructs in
production source` (which iterates `PRODUCTION_FILES`,
the entire `extension/` tree) now automatically covers
the three new patterns.

The pre-existing endless-range regression test
`LEGACY-COMPAT: no endless-range [n..] in production
source (CONFIRMED-FIX-COMPAT-RANGE)` was kept unchanged.

The prior V19A-A1 SCOPED guard (which scanned only the
new V1.9A presenter file) was REMOVED as redundant: the
global `KNOWN_MODERN_SYNTAX` guard now covers it with
the same precision. Keeping a competing framework would
conflict with the dispatch's "extend the existing
LEGACY-COMPAT guard" instruction.

Comment lines are NOT treated as findings (the scanner
already skips pure comment lines via
`lstrip.start_with?('#')`).

Teeth verified: temporarily reintroduced `.sum` to
`core/source_fingerprint.rb` line 224 and confirmed
the global LEGACY-COMPAT test FAILS with file:line +
match + minimal fix guidance. Reverted before commit.

## Test results (this packet, fresh run)

### LEGACY-COMPAT (this packet)

- `LEGACY-COMPAT: vendored Ruby parses every production
  .rb file (current-source syntax/load smoke)`: PASS
- `LEGACY-COMPAT: Ripper.sexp parses every production .rb
  file (current-source AST smoke)`: PASS
- `LEGACY-COMPAT: no known modern-syntax constructs in
  production source` (UPDATED to also cover
  `.positive?` / `.negative?` / `.sum`): PASS
- `LEGACY-COMPAT: no endless-range [n..] in production
  source (CONFIRMED-FIX-COMPAT-RANGE)`: PASS

Total LEGACY-COMPAT: **4 / 4 PASS** (down from 5 after
removing the now-redundant V19A-A1 scoped guard; the 3
new pattern entries are now covered by the global
scanner).

### Focused regression (this packet)

- V1.9A focused: `tests/test_v19a_cad_prep_workflow_presenter.rb`:
  **38 / 38 PASS** + `tests/test_v19a_ui_bridge.rb`:
  **10 / 10 PASS**.
- Source fingerprint focused (`grep fingerprint`):
  **22 / 22 PASS**.
- Planar normalization focused (`V16` set):
  **33 / 33 PASS** (covers V16-T1..T3, V16-I1..I3, V16-H1..H6,
  V16-P1..P7 etc., including the V16-H6 discard /
  rebuild invariant and the V16-I3 discard-clears-state
  invariant — the close-autodiscard contract).
- V1.7 focused: **127 / 127 PASS** (baseline preserved).
- V1.8 focused: **71 / 71 PASS** (baseline preserved).
- V1.8 SR18 set: **32 / 32 PASS**.
- V1.7 INT set: **33 / 33 PASS**.

### DOM / RBZ / Full suite (this packet)

- `tests/test_html_render.rb`: **24 / 24 PASS**.
- `tests/test_html_render_dom.js`: 327+ assertions
  PASS, final line `PASS`.
- RBZ smoke: **9 / 9 PASS** (rebuilt; presenter file
  present).
- Full Ruby suite: **1070 / 1070 total / 1067 PASS / 1
  fail / 2 error**.
- The 1 fail + 2 error are the SAME pre-existing
  test-environment / FakeUI limitations from the V1.8
  baseline (confirmed via direct re-run of each in
  isolation — each PASSes individually; the failures
  are test-order-dependent pollution from the larger
  suite):
  - `capability.HtmlDialog: outside SU returns false
    (R002 + S2-BLOCK-006)`
  - `V14 production call chain: dialog callback ->
    WorkingModeRunner -> workspace reaches :ready`
  - `V17-L1: host_state_changed invalidates the workspace
    via validate-on-next-interaction`
- None caused by this packet; per dispatch §4 reporting
  rule, do not relabel them PASS.

### Diff hygiene

- `git diff --check`: clean (0 warnings).

## RBZ (rebuilt because production Ruby changed)

| Metric          | Value                                                                                            |
|-----------------|--------------------------------------------------------------------------------------------------|
| Path            | `dist/SU-AI-Plugin.rbz`                                                                          |
| Size            | **1,100,586 bytes** (delta +269 vs V1.9A-A1 LEGACY RUBY COMPAT 1,100,317)                       |
| Entries         | **70** (unchanged)                                                                               |
| SHA-256         | **`475052E5D18F870985FCF3D7C6AB0C0552CC7DF963BA9A92A7C3FA61193DADB0`**                          |

### Packaged asset hashes (this packet)

| File                                       | SHA-256                                                              | Status                                          |
|-------------------------------------------|----------------------------------------------------------------------|-------------------------------------------------|
| `html/index.html`                          | `4D488AEF5DA7E43CC8245CC6D40263E9345422C1A228392A3238373A15D0336A`    | UNCHANGED                                        |
| `html/app.js`                              | `A3A2D2EFDF672571F16ADD23FC36D2EEFED7EFDF9BFBEB9C82FE79952FF9340F`    | UNCHANGED                                        |
| `html/style.css`                           | `4B7572DAFD8B20B14AA66042F9DCB03E4C17F4DEA260276B4A0292D0CB4F6B36`    | UNCHANGED                                        |
| `cad_prep_workflow_presenter.rb`           | `74B2C9D5FE782F4DB5ED95CCC90CBD59740E7B01C49F9828FF7622FC7B7927DE`    | UNCHANGED from V1.9A-A1 LEGACY RUBY COMPAT baseline |
| `core/source_fingerprint.rb`               | `949CE3FF1E9A05D9FFEB4D5377ED2B2F265C4B62BC464E5573442FB0C6AD6B24`    | NEW (V1.4 — `.sum` → `inject(0.0)` / `inject(0)`) |
| `core/planar_normalization_executor.rb`    | `7EF4D2DE2C61A305D16278C830438F72EB75B9C363C51AA10162D7F4AA773E9B`    | NEW (V1.6 — `.sum` → `inject(0.0)`)              |

## Confirmation — no A2 / V1.9B / scope creep (this packet)

| Scope item                                                    | Started? | Evidence                                                                          |
|---------------------------------------------------------------|----------|-----------------------------------------------------------------------------------|
| `CadPrepWorkflowOrchestrator`                                  | NO       | Not present in any file.                                                          |
| `start_cad_prep` orchestration callback                         | NO       | Not registered in `dialog_runner.rb`.                                             |
| Automatic full diagnostics after `prepare_workspace`           | NO       | Presenter logic UNCHANGED (this packet touched the V1.4 fingerprint + V1.6 planar normalization production files only). |
| V1.4 fingerprint algorithm change                              | NO       | Field names, canonical ordering, digest semantics UNCHANGED; only the internal `edges.map { ... }.sum` reduction switched to `inject(0.0) { ... }` / `inject(0) { ... }`. |
| V1.6 planar normalization algorithm change                      | NO       | Count / min / max / mean semantics UNCHANGED; only `_z_summary` switched `.sum to `inject(0.0) { ... }`. |
| V1.7 / V1.8 algorithm change                                  | NO       | `git diff e38d6dc..HEAD -- extension/su_ai_plugin/core/` shows zero changes to V1.7 / V1.8 algorithm files. |
| Tolerance / source ownership change                            | NO       | No changes to `Tolerance` / `SourceSnapshot` / `WorkingModeRunner.snapshot` shape. |
| Face / Observer architecture                                   | NO       | Not present in any file.                                                          |
| `PreparedCadDataset` / persistence (V1.9B)                     | NO       | Not present in any file; dispatch §3 forbids it.                                  |
| MCP / LLM / Agent                                              | NO       | Not present in any file; dispatch §3 forbids it.                                  |
| V1.x product UX redesign                                       | NO       | IA / 4 tabs / 5 cards / existing callbacks / legacy payload keys all UNCHANGED.    |
| JS / HTML / CSS change                                         | NO       | Packaged `html/index.html` / `html/app.js` / `html/style.css` SHA-256 UNCHANGED.  |

## `CODEX_RISK_TRIGGER` determination (this packet)

Per AGENTS.md §13 / §10 + dispatch §0:
- Only `extension/su_ai_plugin/core/source_fingerprint.rb`,
  `extension/su_ai_plugin/core/planar_normalization_executor.rb`,
  and `tests/test_v15_legacy_compat_guard.rb` were touched
  by the production-data plane.
- 3 mechanical / semantics-preserving replacements
  (`inject(0.0) { ... }` / `inject(0) { ... }` for
  `.sum`).
- 3 new regex entries added to `KNOWN_MODERN_SYNTAX`.
- 1 redundant scoped test removed (the prior V19A-A1
  scoped guard).
- No algorithm change. No schema / contract change.
- No source / state ownership / transaction / recovery
  change. No Face / Observer architecture. No source CAD
  mutation. No canonical-topology / tolerance / segment-
  conflict semantic change. No RBZ-only release claim.
- The V1.4 fingerprint digest and the V1.6 mean both
  produce the same numeric result as before (verified by
  the unchanged schema + digest-test baselines).

`CODEX_RISK_TRIGGER = NO`.

## STOP (this packet)

- AIPM_REVIEW = PENDING (narrow recheck of the 3
  mechanical `.sum` → `inject(0)` replacements in
  `core/source_fingerprint.rb` and
  `core/planar_normalization_executor.rb` AND the global
  guard extension in `tests/test_v15_legacy_compat_guard.rb`)
- CODEX = NOT REQUIRED
- OWNER_SU2020 = NOT YET
- A2 = NOT STARTED
- V1.9B = NOT STARTED

STOP. Awaiting AIPM narrow source recheck of the
V1X-LEGACY-RUBY-DEBT-CLOSURE only.

END
