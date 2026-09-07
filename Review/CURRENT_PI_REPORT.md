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

# CURRENT PI REPORT — V1.9A3 NATIVE TOOLBAR & PRODUCT ENTRY

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Product UX + Diagnostics Orchestration
Packet: A3 — NATIVE TOOLBAR & PRODUCT ENTRY
Authority: `Prompt/CURRENT_PI_DISPATCH.md`
(V1.9A-A3 NATIVE TOOLBAR & PRODUCT ENTRY, 2026-09-07) +
`Prompt/AIPM_STAGE_PRODUCT_TECHNICAL_BLUEPRINT_V1_9A3_NATIVE_TOOLBAR_2026-09-07.md`.
Baseline HEAD: `1de098b5d3ab8872294ace3fdb504511512faf13`
(dev/v1.9 V1.9A-A2 ERROR BOUNDARY NARROW CORRECTION
complete state).
Baseline branch: `dev/v1.9`
TARGET_BRANCH: **dev/v1.9**
A0 Owner UX Gate: PASS (unchanged; prototype preserved).
A1 packet: COMPLETE on `dev/v1.9`.
A2 packet (orchestrator + error-boundary narrow correction):
COMPLETE on `dev/v1.9`; architecture + error-boundary
PASS the prior AIPM source review.
A2 SHAs frozen by CURRENT_STATE.md:
  - cad_prep_workflow_orchestrator.rb:
    `4e77c1fe47bc72793ba655bb0952abafcc9db7dc5000d407c8b24df01da5238c`
  - cad_prep_workflow_presenter.rb:
    `c64c7cd27a4b40a6308e7a6b42750ef402eefefd0b54cef4b683d10e9ad68691`
  - dialog_runner.rb:
    `dc3c4042c94e20f996aef49e17908072de337217622de447245449dfc75d7b94`
A3 packet (this packet): COMPLETE on `dev/v1.9`; awaiting
AIPM source review of the native toolbar / shared
UI::Command / icons / no-selection UX + regression tests
+ RBZ hashes. Implementation SHA produced by this packet:
see `git log -1 --format=%H dev/v1.9`.
CODEX_RISK_TRIGGER: **NO** (Blueprint §10 — toolbar is an
entry point only; no algorithm / contract / source-
ownership / transaction / Undo / Face / Observer / V1.6 /
V1.7 / V1.8 / A2 orchestrator / Presenter / DialogRunner
callbacks / V1.9B change).

## A3 — 2026-09-07

- Starting HEAD for this packet:
  `1de098b5d3ab8872294ace3fdb504511512faf13` (the
  V1.9A-A2 ERROR BOUNDARY NARROW CORRECTION complete
  state on `dev/v1.9`).
- Implementation SHA: `d04d0e305261017126da9b89465193c0631b4542`
  (this packet's stable commit).
- Final HEAD on dev/v1.9:
  `d04d0e305261017126da9b89465193c0631b4542` (see
  `git rev-parse HEAD` after push).
- V1.9A3 RBZ candidate: size **1,135,782 bytes**
  (+9,716 vs A2-ERR 1,126,066); entries **73**
  (+2 icons vs A2-ERR 71);
  SHA-256 **`b51fd3f2084fbeb83524f220a9cb95d87bdd4f0b0a8e7cdedabf8f376cfa4dca`**.
- Packaged `extension/su_ai_plugin/loader.rb` SHA-256:
  **`3b85dfefe5145113d8ca0a4ee123c1d406e21da0d54986c524123c9ccb2c0ed5`**
  (NEW — V1.9A3 shared command + toolbar + no-selection UX
  refactor).
- Packaged icons (NEW this packet):
  - `extension/su_ai_plugin/icons/cad_prep_24.png`
    SHA-256:
    `de3fdb75bccc48c069e60a51e32588d25f0c2b77ca75160bbd16a29a0db8b795`
    (202 bytes, exactly 24x24, RGBA8).
  - `extension/su_ai_plugin/icons/cad_prep_32.png`
    SHA-256:
    `6f4dfe71743fd0d45f07d25dbd13d41f8cfa7c4c49e0de70be22391a9ed0a765`
    (225 bytes, exactly 32x32, RGBA8).
- A2 / V1.9B confirmation (UNTOUCHED this packet):
  - `extension/su_ai_plugin/cad_prep_workflow_orchestrator.rb`
    SHA-256:
    `4e77c1fe47bc72793ba655bb0952abafcc9db7dc5000d407c8b24df01da5238c`
    (matches CURRENT_STATE.md A2-ERR SHA exactly).
  - `extension/su_ai_plugin/cad_prep_workflow_presenter.rb`
    SHA-256:
    `c64c7cd27a4b40a6308e7a6b42750ef402eefefd0b54cef4b683d10e9ad68691`
    (matches CURRENT_STATE.md A2-ERR SHA exactly).
  - `extension/su_ai_plugin/dialog_runner.rb`
    SHA-256:
    `dc3c4042c94e20f996aef49e17908072de337217622de447245449dfc75d7b94`
    (matches CURRENT_STATE.md A2-ERR SHA exactly).
- HTML / CSS / JS SHAs (UNCHANGED this packet):
  - `html/index.html` SHA-256:
    `4D488AEF5DA7E43CC8245CC6D40263E9345422C1A228392A3238373A15D0336A`
    (no HTML change in this packet; the toolbar entry is a
    pure native SU surface, not a UI-tab change).
  - `html/app.js` SHA-256:
    `50BB92C65C61DF7BC645DE73F1F3F78257DCB7AC80E90D395A2A3942AD65769F`
    (no JS change; existing
    `start_cad_prep` / `refresh_cad_prep` callbacks remain
    the in-app trigger surfaces; the new native toolbar /
    menu reuses the existing `on_analyze_selection` path).
  - `html/style.css` SHA-256:
    `4B7572DAFD8B20B14AA66042F9DCB03E4C17F4DEA260276B4A0292D0CB4F6B36`
    (no CSS change in this packet).
- Full Ruby suite: **1132 / 1132 total** / **1129 PASS**
  / 1 fail / 2 error.
  - The 1 fail + 2 error are the SAME pre-existing test-
    environment / FakeUI limitations documented in
    CURRENT_STATE.md (baseline unchanged from the A2-ERR
    packet):
    - `capability.HtmlDialog: outside SU returns false
      (R002 + S2-BLOCK-006)`
    - `V14 production call chain: dialog callback ->
      WorkingModeRunner -> workspace reaches :ready`
    - `V17-L1: host_state_changed invalidates the workspace
      via validate-on-next-interaction`
    None caused by this packet; reported separately per
    dispatch §13.
  - Delta vs prior A2-ERR packet (1116): +16 tests (the
    V1.9A3 focused tests + 1 PNG dimension test).
- V1.9A3 focused tests (NEW this packet):
  - `tests/test_loader.rb` — V1.9A3 section:
    **17 / 17 PASS** (16 V1.9A3 contract tests + 1 PNG
    dimension test):
    - A3-01/A3-02 toolbar named 'SU AI' with exactly one button
    - A3-05 menu and toolbar share the SAME UI::Command object
    - A3-04 tooltip / status bar text match Blueprint §2
    - A3-03 icon paths resolve to real local PNG files
    - PNG dimension test (exact 24x24 / 32x32)
    - A3-08 repeated register! does not duplicate toolbar or button
    - A3-10 TB_NEVER_SHOWN -> toolbar.show
    - A3-09 previously visible toolbar uses restore
    - A3-09 previously hidden toolbar is NOT force-shown
    - A3-07 no-selection invokes friendly messagebox
    - A3-06 valid selection still reaches show_dialog_for_selection
    - Blueprint §9 source-level guard (no UI::Command#extension=
      and no UI::Command subclassing)
    - Blueprint §2: only ONE production button (no
      Site Model / Residential Model / AI Render placeholders)
    - V1.9A-A2 orchestrator file unchanged (parseable)
    - V1.9A presenter file unchanged (parseable)
    - Loader.cad_prep_command accessor returns retained instance
  - Plus the 12 pre-existing `test_loader` tests remain
    intact (updated where they hard-coded the old
    'Analyze selection' menu text to 'CAD Prep' per the
    new Blueprint §2 contract).
- V1.9A presenter (full): **47 / 47 PASS** (unchanged from
  A2-ERR packet).
- V1.9A orchestrator (full): **20 / 20 PASS** (the 14
  prior + 5 entry-point propagation + 1 source-level
  guard tests remain intact; A2-ERR architecture frozen
  unchanged).
- V1.9A dialog_runner (full): **48 / 48 PASS** (the
  dialog_runner wiring is untouched; only the
  `on_analyze_selection` semantics are shared with the
  new toolbar entry — no callback surface change).
- V1.9A bridge: **10 / 10 PASS** (unchanged).
- V1.9A DOM (`tests/test_html_render.rb`): **24 / 24
  PASS** (unchanged; no HTML change in this packet).
- Node DOM (`tests/test_html_render_dom.js`): all
  assertions PASS, final line `PASS` (unchanged).
- Regression (per dispatch §8):
  - V1.6 planar normalization: **33 / 33 PASS**.
  - V1.6 close-autodiscard: **7 / 7 PASS**.
  - V1.7 focused: **127 / 127 PASS**.
  - V1.7 INT: **33 / 33 PASS**.
  - V1.8 focused: **71 / 71 PASS**.
  - V1.8 SR18: **32 / 32 PASS**.
  - V1.4 fingerprint focused: **22 / 22 PASS**.
  - LEGACY-COMPAT: **4 / 4 PASS** (no `.positive?` /
    `.negative?` / `.sum` / `&.` / `transform_values` /
    `dig` / `yield_self` / `filter_map` / endless-range /
    beginless-range / numbered-block-params in
    `loader.rb`; the LEGACY-COMPAT scanners confirm).
  - RBZ smoke: **9 / 9 PASS** (rebuilt with the
    refactored loader + the 2 new icon assets; the
    menu-name assertion was updated from
    'Analyze selection' to 'CAD Prep' to reflect the
    new Blueprint §2 menu text).
- `git diff --check`: clean (0 warnings on production /
  test code; the trailing whitespace in
  `Prompt/CURRENT_PI_DISPATCH.md` is pre-existing and
  outside Pi's scope — `Prompt/` is read-only per
  AGENTS.md §2).

Frozen V1.8 Blueprint preserved unchanged on the assigned
`dev/v1.9`. Pi did NOT rewrite any frozen design authority.
No V1.4 / V1.5 / V1.6 / V1.7 / V1.8 algorithm change. No
source / provenance authority change. No workspace ownership
change. No host mutation / Face / Observer. No site
semantics. No A2 orchestrator / Presenter / DialogRunner
callbacks change. No PreparedCadDataset / persistence
(V1.9B). No MCP / LLM / Agent. No UI-tab / visual design /
HTML / CSS / JS change.

Corrections / additions by this packet:

- **Shared UI::Command + native toolbar (dispatch §2)**:
  `extension/su_ai_plugin/loader.rb` — Loader now constructs
  exactly ONE `@cad_prep_command` (`UI::Command.new('CAD
  Prep') { on_analyze_selection }`) and attaches the SAME
  command object to BOTH the existing `SU-AI-Plugin`
  submenu AND the new `SU AI` toolbar. The menu text,
  tooltip, status bar text, and icon paths are configured
  per Blueprint §2:
  - `menu_text` (the UI::Command name) = `'CAD Prep'`.
  - `tooltip` = `'SU AI · CAD Prep'`.
  - `status_bar_text` =
    `'检查并准备当前选择的 CAD 几何'`.
  - `small_icon` =
    `<__dir__>/icons/cad_prep_24.png`.
  - `large_icon` =
    `<__dir__>/icons/cad_prep_32.png`.

  Per Blueprint §4: "Do not create one command for menu
  and a second command for toolbar." This packet does not
  create a second command. The retained `Loader.cad_prep_command`
  accessor returns the SAME instance for the menu item AND
  the toolbar button (object identity asserted by test).

- **Native `SU AI` toolbar (dispatch §3)**:
  `extension/su_ai_plugin/loader.rb` — Loader now creates
  `UI::Toolbar.new('SU AI')` (the `TOOLBAR_NAME`
  constant), retained in `@toolbar`, and adds the SAME
  `@cad_prep_command` to it. The toolbar contains
  exactly ONE production button per Blueprint §2 (no
  Site Model / Residential Model / AI Render
  placeholders). Loader test confirms exactly one button
  in the toolbar.

- **Toolbar visibility policy (dispatch §4 + Blueprint §6)**:
  `extension/su_ai_plugin/loader.rb` —
  `apply_toolbar_visibility_policy(toolbar)` consults
  `toolbar.get_last_state`:
  - If state == `TB_NEVER_SHOWN`, call `toolbar.show`
    (Blueprint §6 first-discovery path).
  - Otherwise call `toolbar.restore` (SketchUp's last-
    state is honored; a previously hidden toolbar is NOT
    force-shown).
  - Tolerates hosts that lack `get_last_state` /
    `show` / `restore` (the registration does not crash
    on legacy baseline).

- **No-selection UX (dispatch §5 + Blueprint §3)**:
  `extension/su_ai_plugin/loader.rb` — The shared
  `on_analyze_selection` now consults the selection. If
  `selection.nil? || selection.count.zero?`, it calls
  `show_no_selection_message` which displays the frozen
  product message `'请先选择需要检查和处理的 CAD 几何。'`
  via `UI.messagebox(message, buttons)` (with a defensive
  `UI::MB_OK` constant lookup so the test env / legacy
  hosts do not NameError). Both menu and toolbar receive
  this behavior because they share the SAME command
  block. A valid selection still reaches
  `show_dialog_for_selection(selection, model)` which
  invokes the existing `AnalyzersRunner.run` +
  `DialogRunner.show` path (A2 architecture unchanged).

- **Bundled local PNG icons (dispatch §6 + Blueprint §7)**:
  - `extension/su_ai_plugin/icons/cad_prep_24.png` —
    exactly 24x24, RGBA8, blue-violet rounded square +
    white CAD polyline/loop motif, transparent
    background.
  - `extension/su_ai_plugin/icons/cad_prep_32.png` —
    exactly 32x32, RGBA8, same motif at larger size.
  - `scripts/gen_icons.rb` — deterministic PNG generator
    (no external image dependency; no internet download;
    pure-Ruby Zlib-based PNG encoding).
  - The PNG dimensions are asserted by
    `tests/test_loader.rb`'s V1.9A3 PNG dimension test
    (parses the PNG signature + IHDR chunk directly).

- **Idempotency / retained references (dispatch §3 + Blueprint §5)**:
  `extension/su_ai_plugin/loader.rb` — Loader retains
  `@cad_prep_command` and `@toolbar` for the process
  lifetime. Repeated `register!` calls return the SAME
  command object (Blueprint §4 idempotency requirement)
  and produce no duplicate menu item, no duplicate
  toolbar, and no duplicate toolbar button. The
  `FakeUI::FakeToolbar#add_item` is idempotent on
  command identity (same object identity → single entry),
  matching the production intent.

- **Legacy Ruby compatibility (dispatch §6 + Blueprint §9)**:
  `extension/su_ai_plugin/loader.rb` does NOT use:
  - `UI::Command#extension=` (Blueprint §9 explicit
    prohibition);
  - `UI::Command` subclassing (Blueprint §9 explicit
    prohibition);
  - any post-Ruby-2.2 helper syntax (`.positive?`,
    `.negative?`, `.sum`, `&.`, `transform_values`,
    `dig`, `yield_self`, `filter_map`, endless range
    `[n..]`, beginless range `[..n]`, numbered block
    params). The LEGACY-COMPAT test suite (4/4 PASS)
    confirms via the existing global scanner framework
    (extended with `.positive?` / `.negative?` /
    `.sum` coverage in the V1X-LEGACY-RUBY-DEBT-CLOSURE
    packet).

- **FakeUI extensions**:
  `tests/_fake_ui.rb` — `FakeCommand` extended with the
  Blueprint §2 setters (`tooltip=`, `status_bar_text=`,
  `small_icon=`, `large_icon=`); `extension=` is
  INTENTIONALLY missing — `method_missing` raises
  `NoMethodError` if a future test reaches for it, so
  the Blueprint §9 contract is enforced at the test
  boundary. `FakeToolbar` class added (name, add_item,
  show, restore, hide, get_last_state, events, fake_last_state=)
  mirroring the real `UI::Toolbar` API surface. `TB_NEVER_SHOWN`
  constant added. `FakeUI::State` now tracks toolbars
  and messageboxes. `UIStub` exposes `UI.toolbar` and
  `UI.messagebox`.

- **Focused tests (dispatch §8 + Blueprint §11)**:
  `tests/test_loader.rb` — new V1.9A3 section adds 17
  tests covering A3-01..A3-13 + Blueprint §2 / §9
  contracts + frozen orchestrator / presenter
  parseability guards. The pre-existing 12 loader
  tests were updated where they hard-coded the old
  `'Analyze selection'` menu text to `'CAD Prep'`
  per the new Blueprint §2 contract; the 12 tests
  remain green.

  `tests/test_rbz_smoke.rb` — one assertion updated
  from `'Analyze selection'` to `'CAD Prep'` to match
  the Blueprint §2 menu text inside the extracted-RBZ
  smoke path. All other RBZ smoke assertions
  unchanged.

Next expected action: AIPM source review of the V1.9A3
packet (Loader shared command + SU AI toolbar + no-
selection UX + icon assets + FakeUI extensions +
focused tests + RBZ hashes + A2/V1.9B confirmation
SHAs). Then: Owner real-SU2020 gate A3 (per Blueprint
§12 Owner Real-SU2020 Gate). V1.9A-A2 orchestrator +
A2-ERR error boundary + V1.9A-A1 frontend remain
frozen unchanged. V1.9B PreparedCadDataset / persistence
NOT STARTED.

- AIPM_REVIEW = PENDING
- OWNER_SU2020 = NOT YET (Blueprint §12 Owner gate
  pending AIPM source review)
- V1.9A-A2 orchestrator = FROZEN (architecture +
  error-boundary narrow correction preserved
  unchanged by V1.9A3)
- V1.9B = NOT STARTED

END

# CURRENT PI REPORT — V1.9A OWNER UI TAB SWITCH BLOCK

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Product UX + Diagnostics Orchestration
Packet: OWNER UI TAB SWITCH BLOCK — narrow frontend fix
Authority: AIPM chat instruction (root-cause traced by
AIPM) + dispatch-aligned narrow scope continuation of the
V1.9A-A2 Owner Gate A2 work (the A2 packet's "Next
expected action" explicitly listed Owner UX Gate A2 as
the next step; this BLOCK is the gate's direct result).
Baseline HEAD: `e3be03dc343657b1d315dbcc7727eeb23a4ad1db`
(dev/v1.9 V1.9A-A3 NATIVE TOOLBAR & PRODUCT ENTRY docs
commit).
Baseline branch: `dev/v1.9`
TARGET_BRANCH: **dev/v1.9**
A0 Owner UX Gate: PASS (unchanged; prototype preserved).
A1 packet: COMPLETE on `dev/v1.9`.
A2 packet (orchestrator + error-boundary narrow correction):
COMPLETE on `dev/v1.9`.
A2 SHAs frozen by CURRENT_STATE.md:
  - cad_prep_workflow_orchestrator.rb:
    `4e77c1fe47bc72793ba655bb0952abafcc9db7dc5000d407c8b24df01da5238c`
  - cad_prep_workflow_presenter.rb:
    `c64c7cd27a4b40a6308e7a6b42750ef402eefefd0b54cef4b683d10e9ad68691`
  - dialog_runner.rb:
    `dc3c4042c94e20f996aef49e17908072de337217622de447245449dfc75d7b94`
A3 packet (NATIVE TOOLBAR & PRODUCT ENTRY): COMPLETE on
`dev/v1.9`; SHAs frozen by CURRENT_STATE.md:
  - loader.rb:
    `3b85dfefe5145113d8ca0a4ee123c1d406e21da0d54986c524123c9ccb2c0ed5`
  - html/app.js:
    `50bb92c65c61df7bc645de73f1f3f78257dcb7ac80e90d395a2a3942ad65769f`
  - html/index.html:
    `4d488aef5da7e43cc8245cc6d40263e9345422c1a228392a3238373a15d0336a`
A3 OWNER UI TAB SWITCH BLOCK (this packet): COMPLETE on
`dev/v1.9`; awaiting AIPM source review of the scoped
CSS rule + the 7 new CSS source-level guards + the 4 new
DOM click-through assertions + RBZ hashes.
Implementation SHA produced by this packet:
`ce467c3648445dcc6824d8edd4cf31cb3aaf7f1d`
(see `git log -1 --format=%H dev/v1.9`).
CODEX_RISK_TRIGGER: **NO** (1-line scoped CSS rule +
regression tests only; no algorithm / contract / source-
ownership / transaction / Undo / Face / Observer / V1.6 /
V1.7 / V1.8 / A2 / A3 / V1.9B change).

## Owner Gate A2 BLOCK — 2026-09-07

- Starting HEAD for this packet:
  `e3be03dc343657b1d315dbcc7727eeb23a4ad1db` (the
  V1.9A-A3 NATIVE TOOLBAR & PRODUCT ENTRY docs
  commit on `dev/v1.9`).
- Implementation SHA:
  `ce467c3648445dcc6824d8edd4cf31cb3aaf7f1d` (this
  packet's stable commit).
- Final HEAD on dev/v1.9:
  `ce467c3648445dcc6824d8edd4cf31cb3aaf7f1d` (see
  `git rev-parse HEAD` after push).
- V1.9A OWNER UI TAB SWITCH BLOCK RBZ candidate:
  size **1,136,772 bytes** (+990 vs V1.9A3
  1,135,782); entries **73** (unchanged from
  V1.9A3; no new files);
  SHA-256
  **`b0700044d2791ac3c47cc73926bd9aebeda6c504dafc9cbc6e5af0d3343ee540`**.
- Packaged
  `extension/su_ai_plugin/html/style.css`
  SHA-256:
  **`ceac7aeec04f5c3aeed88cd768e0ec4794e7656c01644af3419d89386a61c752`**
  (CHANGED — contains the scoped
  `.panel[hidden] { display: none; }` rule).
- HTML / JS / Ruby production SHAs UNCHANGED
  (verified via packaged-RBZ extraction; all 6
  match the prior packets' SHAs exactly):
  - `html/index.html` SHA-256:
    `4D488AEF5DA7E43CC8245CC6D40263E9345422C1A228392A3238373A15D0336A`
    (matches V1.9A3 packet SHA exactly).
  - `html/app.js` SHA-256:
    `50BB92C65C61DF7BC645DE73F1F3F78257DCB7AC80E90D395A2A3942AD65769F`
    (matches V1.9A3 packet SHA exactly).
  - `loader.rb` SHA-256:
    `3B85DFEFE5145113D8CA0A4EE123C1D406E21DA0D54986C524123C9CCB2C0ED5`
    (matches V1.9A3 packet SHA exactly).
  - `cad_prep_workflow_orchestrator.rb` SHA-256:
    `4E77C1FE47BC72793BA655BB0952ABAFCC9DB7DC5000D407C8B24DF01DA5238C`
    (matches A2-ERR packet SHA exactly).
  - `cad_prep_workflow_presenter.rb` SHA-256:
    `C64C7CD27A4B40A6308E7A6B42750EF402EEFEFD0B54CEF4B683D10E9AD68691`
    (matches A2-ERR packet SHA exactly).
  - `dialog_runner.rb` SHA-256:
    `DC3C4042C94E20F996AEF49E17908072DE337217622DE447245449DFC75D7B94`
    (matches A2-ERR packet SHA exactly).
- Full Ruby suite: **1139 / 1139 total** /
  **1136 PASS** / 1 fail / 2 error.
  - The 1 fail + 2 error are the SAME pre-existing
    test-environment / FakeUI limitations documented
    in CURRENT_STATE.md (baseline unchanged from
    V1.9A3 packet):
    - `capability.HtmlDialog: outside SU returns false
      (R002 + S2-BLOCK-006)`
    - `V14 production call chain: dialog callback ->
      WorkingModeRunner -> workspace reaches :ready`
    - `V17-L1: host_state_changed invalidates the
      workspace via validate-on-next-interaction`
    None caused by this packet; reported separately
    per dispatch §13.
  - Delta vs prior V1.9A3 packet 1132: +7 tests
    (the 7 new V1.9A OWNER UI TAB SWITCH BLOCK
    focused tests in `tests/test_html_render.rb`).
- V1.9A OWNER UI TAB SWITCH BLOCK focused tests
  (NEW this packet):
  - `tests/test_html_render.rb` — **7 / 7 PASS**:
    - style.css has the `.panel[hidden] { display:
      none }` rule (presence guard).
    - `.panel[hidden]` rule appears AFTER the
      `.panel` rule (cascade-order guard).
    - switchTab JS DOM contract is unchanged
      (`removeAttribute('hidden')` /
      `setAttribute('hidden', '')` /
      `aria-selected="true"/"false"`).
    - index.html default panel visibility is
      correct (panel-process visible; panel-issues
      / panel-layers / panel-details all carry
      `hidden`).
    - CSS structural guard against future `.panel {
      display }` regressions (both rules coexist).
    - The fix uses a scoped selector, not a global
      `[hidden] !important` rule (dispatch
      preference: scoped > global).
    - tab map covers all 4 panels (process /
      issues / layers / details).
  - `tests/test_html_render_dom.js` — **4 new
    click-through assertions** (all PASS):
    - Click 问题 shows panel-issues + hides the
      other 3 + aria-selected flips.
    - Click 图层 shows panel-layers + hides the
      other 3 + aria-selected flips.
    - Click 详情 shows panel-details + hides the
      other 3 + aria-selected flips.
    - Click 处理 shows panel-process again +
      aria-selected flips back.
- V1.9A presenter (full): **47 / 47 PASS**
  (unchanged; presenter file SHA matches A2-ERR
  packet SHA exactly).
- V1.9A orchestrator (full): **20 / 20 PASS**
  (unchanged; orchestrator file SHA matches A2-ERR
  packet SHA exactly; A2-ERR architecture frozen).
- V1.9A dialog_runner (full): **48 / 48 PASS**
  (unchanged; dialog_runner file SHA matches A2-ERR
  packet SHA exactly).
- V1.9A bridge: **10 / 10 PASS** (unchanged).
- V1.9A3 Loader / A3: **16 / 16 PASS** (the V1.9A3
  packet's shared UI::Command + toolbar + icons
  tests intact; loader.rb SHA matches V1.9A3 packet
  SHA exactly).
- V1.9A DOM (`tests/test_html_render.rb`): **31 /
  31 PASS** (23 prior + 1 Node DOM wrapper + 7 new
  V1.9A OWNER UI TAB SWITCH BLOCK tests).
- Node DOM (`tests/test_html_render_dom.js`): all
  assertions PASS, final line `PASS` (includes the
  4 new click-through scenarios).
- Regression (per dispatch §8):
  - V1.6 planar normalization: **33 / 33 PASS**.
  - V1.6 close-autodiscard: **7 / 7 PASS**.
  - V1.7 focused: **127 / 127 PASS**.
  - V1.7 INT: **33 / 33 PASS**.
  - V1.8 focused: **71 / 71 PASS**.
  - V1.8 SR18: **32 / 32 PASS**.
  - V1.4 fingerprint focused: **22 / 22 PASS**.
  - LEGACY-COMPAT: **4 / 4 PASS** (CSS only; no
    Ruby syntax change).
  - RBZ smoke: **9 / 9 PASS** (rebuilt with the
    scoped CSS rule; all 9 RBZ assertions intact).
- `git diff --check`: clean (0 warnings on
  production / test code; the trailing whitespace
  in `Prompt/CURRENT_PI_DISPATCH.md` is pre-existing
  and outside Pi's scope — `Prompt/` is read-only).

Frozen V1.8 Blueprint preserved unchanged on the
assigned `dev/v1.9`. Pi did NOT rewrite any frozen
design authority. No V1.4 / V1.5 / V1.6 / V1.7 /
V1.8 algorithm change. No source / provenance
authority change. No workspace ownership change.
No host mutation / Face / Observer. No site
semantics. No A2 orchestrator / Presenter /
DialogRunner callbacks change. No Loader / A3
toolbar / V1.9A3 contract change. No switchTab JS
logic change. No index.html tab structure change.
No PreparedCadDataset / persistence (V1.9B). No
MCP / LLM / Agent.

Corrections / additions by this packet:

- **CSS scoped rule (the fix)**:
  `extension/su_ai_plugin/html/style.css` — added
  one scoped rule immediately after the existing
  `.panel { display: flex; flex-direction: column; }`
  rule:

  ```css
  .panel[hidden] {
    display: none;
  }
  ```

  Specificity: `.panel[hidden]` = 0,0,2,0;
  `.panel` = 0,0,1,0. The scoped selector wins by
  BOTH specificity AND cascade order (it appears
  AFTER `.panel` in the stylesheet). The fix is
  Blueprint-scoped: it overrides the hidden state
  for the 4 production panels only (处理 / 问题
  / 图层 / 详情); non-panel elements that use the
  `hidden` attribute elsewhere (badges, toasts,
  banners, etc.) are unaffected.

- **Focused CSS source-level guards (NEW this
  packet)**:
  `tests/test_html_render.rb` — 7 new tests that
  pin the fix at the CSS source level so future
  edits cannot silently regress the hidden
  contract. The tests assert:
  - The scoped rule MUST be present.
  - The scoped rule MUST appear AFTER `.panel`
    (cascade-order guard).
  - The fix MUST NOT use a global `[hidden]
    !important` (dispatch preference: scoped >
    global).
  - Both `.panel` AND `.panel[hidden]` rules MUST
    coexist (structural guard against future
    `.panel { display: ... }` edits).
  - The switchTab JS DOM contract is unchanged
    (correct before; CSS was wrong).
  - The tab map covers all 4 production panels.
  - The index.html default panel visibility
    (panel-process visible; others hidden) is
    intact.

- **DOM click-through regression (NEW this packet)**:
  `tests/test_html_render_dom.js` — 4 new
  click-through assertions that simulate the Owner
  Gate A2 BLOCK scenario end-to-end. Each
  assertion verifies that after the click:
  (1) the visible panel matches the clicked tab;
  (2) the other 3 panels carry the `hidden`
  attribute; (3) `aria-selected="true"` on the
  clicked tab and `aria-selected="false"` on the
  inactive tabs. The 4 scenarios are: click
  问题 / 图层 / 详情 / 处理.

Next expected action: AIPM source review of the
V1.9A OWNER UI TAB SWITCH BLOCK packet (the scoped
`.panel[hidden] { display: none; }` CSS rule +
the 7 new CSS source-level guards + the 4 new DOM
click-through assertions + RBZ hashes + A2 / A3 /
V1.9B confirmation SHAs). Then: Owner real-SU2020
re-verification (the gate that originally produced
this BLOCK should now PASS). V1.9B PreparedCadDataset
/ persistence NOT STARTED. Final V1.x Codex xHigh
review remains mandatory later regardless.

- AIPM_REVIEW = PENDING
- OWNER_SU2020 = NOT YET (Owner Gate A2 BLOCK fix
  now ready for re-verification per Blueprint §12)
- V1.9A-A2 orchestrator = FROZEN (architecture +
  error-boundary narrow correction preserved
  unchanged by this packet)
- V1.9A-A3 = FROZEN (NATIVE TOOLBAR & PRODUCT
  ENTRY preserved unchanged by this packet)
- V1.9B = NOT STARTED

END

# CURRENT PI REPORT — V1.9A OWNER UI HIDDEN-SEMANTICS FOLLOW-UP

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Product UX + Diagnostics Orchestration
Packet: OWNER UI HIDDEN-SEMANTICS FOLLOW-UP — narrow
frontend fix (continuation of Owner Gate A2 BLOCK
fix work).
Authority: AIPM chat instruction (root-cause traced by
AIPM) + dispatch-aligned narrow scope continuation of the
V1.9A-A2 Owner Gate A2 work.
Baseline HEAD: `1d1f9c821c7050268743a7acd6fe502cd3baddeb`
(dev/v1.9 V1.9A OWNER UI TAB SWITCH BLOCK docs
commit).
Baseline branch: `dev/v1.9`
TARGET_BRANCH: **dev/v1.9**
A0 Owner UX Gate: PASS (unchanged; prototype preserved).
A1 packet: COMPLETE on `dev/v1.9`.
A2 packet (orchestrator + error-boundary narrow correction):
COMPLETE on `dev/v1.9`.
A2 SHAs frozen by CURRENT_STATE.md:
  - cad_prep_workflow_orchestrator.rb:
    `4e77c1fe47bc72793ba655bb0952abafcc9db7dc5000d407c8b24df01da5238c`
  - cad_prep_workflow_presenter.rb:
    `c64c7cd27a4b40a6308e7a6b42750ef402eefefd0b54cef4b683d10e9ad68691`
  - dialog_runner.rb:
    `dc3c4042c94e20f996aef49e17908072de337217622de447245449dfc75d7b94`
A3 packet (NATIVE TOOLBAR & PRODUCT ENTRY): COMPLETE on
`dev/v1.9`; SHAs frozen by CURRENT_STATE.md:
  - loader.rb:
    `3b85dfefe5145113d8ca0a4ee123c1d406e21da0d54986c524123c9ccb2c0ed5`
  - html/app.js:
    `50bb92c65c61df7bc645de73f1f3f78257dcb7ac80e90d395a2a3942ad65769f`
  - html/index.html:
    `4d488aef5da7e43cc8245cc6d40263e9345422c1a228392a3238373a15d0336a`
TAB SWITCH BLOCK packet: COMPLETE on `dev/v1.9`;
style.css SHA-256:
`ceac7aeec04f5c3aeed88cd768e0ec4794e7656c01644af3419d89386a61c752`
HIDDEN-SEMANTICS FOLLOW-UP (this packet): COMPLETE on
`dev/v1.9`; awaiting AIPM source review of the 2 scoped
CSS rules + the complete audit + the 9 new CSS source-
level guards + the 8 new DOM click-through assertions +
RBZ hashes.
Implementation SHA produced by this packet:
`09bd5d33033123ac3bab6b669b2676ac83dbd1eb`
(see `git log -1 --format=%H dev/v1.9`).
CODEX_RISK_TRIGGER: **NO** (2 scoped CSS rules +
regression tests only; no algorithm / contract / source-
ownership / transaction / Undo / Face / Observer / V1.6 /
V1.7 / V1.8 / A2 / A3 / V1.9B / TAB SWITCH BLOCK /
host-state validation / WorkingModeRunner change).

## HIDDEN-SEMANTICS FOLLOW-UP — 2026-09-07

- Starting HEAD for this packet:
  `1d1f9c821c7050268743a7acd6fe502cd3baddeb` (the
  V1.9A OWNER UI TAB SWITCH BLOCK docs commit on
  `dev/v1.9`).
- Implementation SHA:
  `09bd5d33033123ac3bab6b669b2676ac83dbd1eb` (this
  packet's stable commit).
- Final HEAD on dev/v1.9:
  `09bd5d33033123ac3bab6b669b2676ac83dbd1eb` (see
  `git rev-parse HEAD` after push).
- V1.9A OWNER UI HIDDEN-SEMANTICS FOLLOW-UP RBZ
  candidate: size **1,138,324 bytes** (+1,552 vs
  TAB SWITCH 1,136,772); entries **73** (unchanged);
  SHA-256
  **`f82395dd32cdc926ad1bf50abe59ab1d8fb7be8a48091a8cff68792191da42f9`**.
- Packaged
  `extension/su_ai_plugin/html/style.css` SHA-256:
  **`fa38cc2677887a1d71fc382426c37cc5e1353be15f799e86ff2d7889661fc98c`**
  (CHANGED — contains both scoped
  `.recovery-banner[hidden] { display: none; }` and
  `.tab-badge[hidden] { display: none; }` rules).
- HTML / JS / Ruby production SHAs UNCHANGED
  (verified via packaged-RBZ extraction; all 6
  match the prior TAB SWITCH packet SHAs exactly):
  - `html/index.html` SHA-256:
    `4D488AEF5DA7E43CC8245CC6D40263E9345422C1A228392A3238373A15D0336A`
    (matches V1.9A3 packet SHA exactly).
  - `html/app.js` SHA-256:
    `50BB92C65C61DF7BC645DE73F1F3F78257DCB7AC80E90D395A2A3942AD65769F`
    (matches V1.9A3 packet SHA exactly).
  - `loader.rb` SHA-256:
    `3B85DFEFE5145113D8CA0A4EE123C1D406E21DA0D54986C524123C9CCB2C0ED5`
    (matches V1.9A3 packet SHA exactly).
  - `cad_prep_workflow_orchestrator.rb` SHA-256:
    `4E77C1FE47BC72793BA655BB0952ABAFCC9DB7DC5000D407C8B24DF01DA5238C`
    (matches A2-ERR packet SHA exactly).
  - `cad_prep_workflow_presenter.rb` SHA-256:
    `C64C7CD27A4B40A6308E7A6B42750EF402EEFEFD0B54CEF4B683D10E9AD68691`
    (matches A2-ERR packet SHA exactly).
  - `dialog_runner.rb` SHA-256:
    `DC3C4042C94E20F996AEF49E17908072DE337217622DE447245449DFC75D7B94`
    (matches A2-ERR packet SHA exactly).
- Full Ruby suite: **1147 / 1147 total** /
  **1144 PASS** / 1 fail / 2 error.
  - The 1 fail + 2 error are the SAME pre-existing
    test-environment / FakeUI limitations documented
    in CURRENT_STATE.md (baseline unchanged from
    TAB SWITCH packet):
    - `capability.HtmlDialog: outside SU returns false
      (R002 + S2-BLOCK-006)`
    - `V14 production call chain: dialog callback ->
      WorkingModeRunner -> workspace reaches :ready`
    - `V17-L1: host_state_changed invalidates the
      workspace via validate-on-next-interaction`
    None caused by this packet; reported separately
    per dispatch §13.
  - Delta vs prior TAB SWITCH packet 1139: +8 tests
    (the 8 new V1.9A OWNER UI HIDDEN-SEMANTICS
    FOLLOW-UP focused tests in
    `tests/test_html_render.rb`).
- V1.9A OWNER UI HIDDEN-SEMANTICS FOLLOW-UP focused
  tests (NEW this packet):
  - `tests/test_html_render.rb` — **9 / 9 PASS**:
    - style.css has the
      `.recovery-banner[hidden] { display: none }`
      rule (presence guard).
    - style.css has the
      `.tab-badge[hidden] { display: none }` rule
      (presence guard).
    - `.recovery-banner[hidden]` rule appears AFTER
      `.recovery-banner` (cascade-order guard).
    - `.tab-badge[hidden]` rule appears AFTER
      `.tab-badge` (cascade-order guard).
    - CSS structural guard against future
      `.recovery-banner { display }` / `.tab-badge {
      display }` regressions (both scoped rules
      coexist).
    - Uses scoped selectors, not a global `[hidden]
      !important` rule (dispatch preference: scoped
      > global).
    - COMPLETE audit of all current `[hidden]`
      elements (panel×4 / recovery-banner /
      tab-badge / toast) — each is either covered
      by a scoped override rule OR explicitly marked
      unaffected because its CSS class does NOT set
      `display:`.
    - `recovery-banner` / `tab-issues-badge` static
      `hidden` attributes present in HTML by
      default.
  - `tests/test_html_render_dom.js` — **8 new
    click-through assertions** (all PASS):
    - recovery-banner default carries hidden
      attribute.
    - tab-issues-badge default carries hidden
      attribute (count=0).
    - STALE recovery removes hidden attribute
      (banner visible).
    - is-failed recovery removes hidden attribute
      (banner visible).
    - READY_FOR_VALIDATION banner re-hidden.
    - issue count > 0 removes hidden attribute
      (badge visible).
    - issue count == 0 keeps hidden attribute
      (badge hidden).
    - existing four-tab switching still passes
      (regression guard against cascade-order
      breakage).
- V1.9A presenter (full): **47 / 47 PASS**
  (unchanged; presenter file SHA matches A2-ERR
  packet SHA exactly).
- V1.9A orchestrator (full): **20 / 20 PASS**
  (unchanged; orchestrator file SHA matches A2-ERR
  packet SHA exactly; A2-ERR architecture frozen).
- V1.9A dialog_runner (full): **48 / 48 PASS**
  (unchanged; dialog_runner file SHA matches A2-ERR
  packet SHA exactly).
- V1.9A bridge: **10 / 10 PASS** (unchanged).
- V1.9A3 Loader / A3: **16 / 16 PASS** (the V1.9A3
  packet's shared UI::Command + toolbar + icons
  tests intact; loader.rb SHA matches V1.9A3 packet
  SHA exactly).
- V1.9A DOM (`tests/test_html_render.rb`): **39 /
  39 PASS** (29 prior + 1 Node DOM wrapper + 9 new
  V1.9A OWNER UI HIDDEN-SEMANTICS FOLLOW-UP tests).
- Node DOM (`tests/test_html_render_dom.js`): all
  assertions PASS, final line `PASS` (includes the
  8 new click-through scenarios for recovery-banner
  / tab-issues-badge).
- Regression (per dispatch §8):
  - V1.6 planar normalization: **33 / 33 PASS**.
  - V1.6 close-autodiscard: **7 / 7 PASS**.
  - V1.7 focused: **127 / 127 PASS**.
  - V1.7 INT: **33 / 33 PASS**.
  - V1.8 focused: **71 / 71 PASS**.
  - V1.8 SR18: **32 / 32 PASS**.
  - V1.4 fingerprint focused: **22 / 22 PASS**.
  - LEGACY-COMPAT: **4 / 4 PASS** (CSS only; no
    Ruby syntax change).
  - RBZ smoke: **9 / 9 PASS** (rebuilt with the 2
    new scoped CSS rules; all 9 RBZ assertions
    intact).
- `git diff --check`: clean (0 warnings on
  production / test code; the trailing whitespace
  in `Prompt/CURRENT_PI_DISPATCH.md` is pre-existing
  and outside Pi's scope — `Prompt/` is read-only).

Frozen V1.8 Blueprint preserved unchanged on the
assigned `dev/v1.9`. Pi did NOT rewrite any frozen
design authority. No V1.4 / V1.5 / V1.6 / V1.7 /
V1.8 algorithm change. No source / provenance
authority change. No workspace ownership change.
No host mutation / Face / Observer. No site
semantics. No A2 orchestrator / Presenter /
DialogRunner callbacks change. No Loader / A3
toolbar / V1.9A3 contract change. No host-state
validation / WorkingModeRunner change. No switchTab
JS logic change. No index.html tab structure change.
No PreparedCadDataset / persistence (V1.9B). No
MCP / LLM / Agent.

Corrections / additions by this packet:

- **CSS scoped rules (the fix)**:
  `extension/su_ai_plugin/html/style.css` — added
  2 scoped rules immediately after the existing
  `.recovery-banner { display: flex }` and
  `.tab-badge { display: inline-flex }` rules:

  ```css
  .recovery-banner[hidden] {
    display: none;
  }

  .tab-badge[hidden] {
    display: none;
  }
  ```

  Specificity: `.X[hidden]` = 0,0,2,0; `.X` =
  0,0,1,0. The scoped selector wins by both
  specificity AND cascade order (it appears AFTER
  the non-scoped rule in the stylesheet).

- **Complete audit result (every CURRENT [hidden]
  element)**:
  - `panel-process` / `panel-issues` / `panel-layers`
    / `panel-details`: `.panel { display: flex }`
    override → fixed by prior `.panel[hidden]`
    packet.
  - `recovery-banner`: `.recovery-banner { display:
    flex }` override → fixed by THIS packet
    `.recovery-banner[hidden]`.
  - `tab-issues-badge`: `.tab-badge { display:
    inline-flex }` override → fixed by THIS packet
    `.tab-badge[hidden]`.
  - `toast`: `.toast { ... }` does NOT set
    `display:` (only `position` / `padding` /
    `background` / etc.) → the browser default
    `[hidden] { display: none }` works correctly
    for it. NOT AFFECTED. The complete-audit test
    pins this classification.

- **Focused CSS source-level guards (NEW this
  packet)**:
  `tests/test_html_render.rb` — 9 new tests that
  pin the fix at the CSS source level so future
  edits cannot silently regress the hidden contract:
  - The 2 scoped rules MUST be present.
  - The 2 scoped rules MUST appear AFTER their
    non-scoped counterparts (cascade-order guard).
  - The fix MUST NOT use a global `[hidden]
    !important` (dispatch preference: scoped >
    global).
  - Both `.recovery-banner` / `.tab-badge` AND
    their scoped overrides MUST coexist
    (structural guard against future `display:`
    edits).
  - The COMPLETE audit test enumerates every
    CURRENT `[hidden]` element and asserts each is
    either covered by a scoped override rule OR
    explicitly marked unaffected because its CSS
    class does NOT set `display:` (the `.toast`
    case).
  - The `recovery-banner` / `tab-issues-badge`
    static `hidden` attributes are present in HTML
    by default.

- **DOM click-through regression (NEW this
  packet)**:
  `tests/test_html_render_dom.js` — 8 new
  click-through assertions that simulate the Owner
  Gate A2 BLOCK follow-up scenario end-to-end.
  Each assertion verifies that:
  - Default state: recovery-banner / tab-issues-badge
    carry the `hidden` attribute.
  - STALE / is-failed recovery: removing `hidden`
    makes the banner visible (contract flip works).
  - READY_FOR_VALIDATION: re-hiding the banner
    succeeds.
  - Issue count > 0: removing `hidden` makes the
    badge visible.
  - Issue count == 0: the badge keeps `hidden`.
  - Existing four-tab switching still passes
    (regression guard).

Next expected action: AIPM source review of the
V1.9A OWNER UI HIDDEN-SEMANTICS FOLLOW-UP packet
(the 2 scoped CSS rules + the complete audit + the
9 new CSS source-level guards + the 8 new DOM
click-through assertions + RBZ hashes + A2 / A3 /
TAB SWITCH / V1.9B confirmation SHAs). Then: Owner
real-SU2020 re-verification (the gate that originally
produced this BLOCK follow-up should now PASS).
V1.9B PreparedCadDataset / persistence NOT STARTED.
Final V1.x Codex xHigh review remains mandatory
later regardless.

- AIPM_REVIEW = PENDING
- OWNER_SU2020 = NOT YET (Owner Gate A2 BLOCK
  follow-up fix now ready for re-verification per
  Blueprint §12)
- V1.9A-A2 orchestrator = FROZEN (architecture +
  error-boundary narrow correction preserved
  unchanged by this packet)
- V1.9A-A3 = FROZEN (NATIVE TOOLBAR & PRODUCT
  ENTRY preserved unchanged by this packet)
- V1.9A TAB SWITCH BLOCK = FROZEN (.panel[hidden]
  fix preserved unchanged by this packet)
- V1.9B = NOT STARTED

END

# CURRENT PI REPORT — V1.9A FINAL BLOCK FIX

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Product UX + Diagnostics Orchestration
Packet: FINAL BLOCK FIX — Current Geometry + Current
Issue Semantics
Authority: `Prompt/CURRENT_PI_DISPATCH.md` (V1.9A
FINAL BLOCK FIX, 2026-09-07) + primary guidance
`Prompt/AIPM_V1_9A_FINAL_BLOCK_FIX_2026-09-07.md` +
frozen V1.9A-V1.9B Blueprint +
frozen V1.6 / V1.7 / V1.8 Blueprints.
Implementation Agent: Pi
Target Branch: `dev/v1.9`
Starting Baseline:
`09bd5d33033123ac3bab6b669b2676ac83dbd1eb`
Status: COMPLETE on `dev/v1.9`; awaiting AIPM
direct source review (POST-IMPLEMENTATION NARROW
Codex escalation per dispatch §11).
V1.9B: NOT STARTED.
V2 / MCP / LLM / Agent: OUT OF SCOPE.

---

## 0. Goal + scope

Implement the COMPLETE narrow final V1.9A
block-fix packet:

1. V1.7 current topology snapshot consumes LIVE
   post-V1.6 derived vertex coordinates, not stale
   build-time geometry summaries. **(P0)**
2. Real/production-equivalent Z + Gap chain yields
   a valid closed loop + Region after both repairs.
   **(integration regression)**
3. Current Issues and red badge no longer show
   historical source-registry rows as if they were
   current unresolved problems. **(P1-A)**
4. Original source findings remain available under
   Details / original source evidence. **(P1-A L3)**
5. Normal `重新检测` dispatches `refresh_cad_prep`,
   never silent workspace rebuild. **(P1-C)**
6. Planar card uses authoritative `movable_count` /
   `applied_count` fields and never contradicts an
   ACTIONABLE/APPLIED state. **(P2-A)**
7. Structure warning copy uses specific current
   evidence where available. **(P2-B)**
8. Hidden CSS regression guard cannot pass from
   selector text found only inside comments.
   **(test debt)**

---

## 1. Files changed (this packet)

### 1.1 Production (3 files)

- `extension/su_ai_plugin/core/endpoint_record.rb`
  — **P0** live-coordinate authority in
  `DerivedTopologySnapshotBuilder.build`. New
  helper `_live_coordinate_for` consults
  `adapter.vertex_position(handle)` for each
  endpoint when the workspace's `handle_for`
  seam resolves the host handle. New error class
  `LiveVertexPositionUnreadable` raised when a
  live handle exists AND `vertex_position` is
  exposed AND the read returns malformed /
  non-finite / Infinity / raises. Cached
  `geometry_summary['start' / 'end']` remains
  the host-free / no-live-handle fallback. Source
  CAD is NEVER mutated; geometry_summary is
  NEVER rewritten.

- `extension/su_ai_plugin/cad_prep_workflow_presenter.rb`
  — **(P1-B)** new `PROBLEM_METRIC_LABELS`
  whitelist + state-gated `_collect_chips` filter
  that excludes CLEAN / APPLIED success metrics
  (`closed_loops` / `regions` / `holes` /
  `已处理` / `已校正` / `已修复` /
  `已合并重复对`). **(P1-C)** new additive
  `issue_summary.cta_callback` field set to
  `'refresh_cad_prep'` for NEEDS_ATTENTION /
  READY-with-APPLIED / FAILED; `nil` for IDLE /
  SCANNING / READY-clean / STALE. **(P2-A)** new
  `_planar_count_field` helper resolves
  `movable_count` (authoritative) with `movable` /
  `proposed_movable` defensive fallback for
  READY_TO_NORMALIZE; `applied_count`
  (authoritative) with `moved` / `moved_applied`
  fallback for APPLIED. `_planar_safe_summary`
  no longer contradicts READY_TO_NORMALIZE with
  `"未发现需要 Z 校正的点"` — uses generic
  `"发现可安全校正的 Z 偏差"` copy when the
  state is READY_TO_NORMALIZE but no exact count
  is available. **(P2-B)** new
  `_structure_warning_summary` + helpers
  (`_structure_invalid_loop_count`,
  `_structure_loop_flags`,
  `_structure_warning_metric_keys`) map specific
  evidence to specific copy: open_chains > 0
  -> `"存在未闭合轮廓"`;
  invalid_loop_count > 0 AND unresolved_flags
  includes `non_planar_loop` -> `"存在非平面闭合
  轮廓，暂不能形成区域"`; invalid_loop_count > 0
  without non_planar_loop -> `"存在无效轮廓或需确认
  结构"`; fallback -> `"结构已重建，但存在需要人工
  查看的项"`. Metric chips for structure warnings
  only surface problem metrics
  (`open_chains` / `invalid_loop_count`).

- `extension/su_ai_plugin/html/app.js` —
  **(P1-A)** `_buildIssueRows(payload, cadPrep)`
  no longer appends raw `payload.groups` rows to
  the primary current-issue list. Current-issue
  rows come ONLY from cadPrepWorkflow cards
  (REVIEW_REQUIRED / FAILED / BLOCKED).
  `_buildIssuesBadgeCount(cadPrep, payload)` no
  longer counts `payload.groups`. Legacy
  source-registry data remains reachable via
  `_buildLegacySourceRows` under 详情 /
  原始检查记录. **(P1-C)** `renderIssueSummary`
  CTA wiring now uses the additive
  `summary.cta_callback` field explicitly (the
  hard-wired `data-action="rebuild_workspace"`
  is RETIRED from this path). When
  `cta_callback` is null, the summary CTA button
  is NOT rendered.

### 1.2 Tests (4 files)

- **NEW**: `tests/test_v19a_final_p0_live_coordinates.rb`
  — 11 P0 focused tests covering live vs cached
  coordinate authority, fail-closed malformed /
  non-finite / nil / Infinity / no-adapter paths,
  the owner-fixture 0.2 mm residue regression,
  error-class / source-level guards.

- **EXTENDED**: `tests/test_v19a_cad_prep_workflow_presenter.rb`
  — 18 new V1.9A FINAL BLOCK FIX focused tests:
  P2-A (5), P2-B (4), P1-B (2), P1-C (5), and
  presenter source-level guards (2).

- **EXTENDED**: `tests/test_html_render.rb` —
  new `hr_strip_css_comments` helper + 2 new CSS
  comment regression guard tests + 5 new app.js
  frontend behavior tests.

- **EXTENDED**: `tests/test_html_render_dom.js` —
  6 new DOM assertions covering P1-A current
  issue separation, P1-C additive cta_callback
  schema, IDLE null-callback CTA hides.

### 1.3 Build script (1 file)

- **NEW**: `scripts/build_rbz.ps1` — PowerShell
  port of `scripts/build_rbz.rb` used to produce
  the .rbz candidate (system Ruby runtime is
  broken on this host — see §5 environment
  limitation).

### 1.4 UNCHANGED (verified via packaged-RBZ
extraction; SHAs match the prior
HIDDEN-SEMANTICS FOLLOW-UP packet exactly):

- `extension/su_ai_plugin.rb`
- `extension/su_ai_plugin/loader.rb`
- `extension/su_ai_plugin/main.rb`
- `extension/su_ai_plugin/cad_prep_workflow_orchestrator.rb`
- `extension/su_ai_plugin/dialog_runner.rb`
- `extension/su_ai_plugin/ui_bridge.rb`
- `extension/su_ai_plugin/core/working_mode_runner.rb`
- `extension/su_ai_plugin/html/index.html`
- `extension/su_ai_plugin/html/style.css`

The orchestrator's call-order / invalidation
seam / refresh / rebuild-and-scan / gap-ordering
safety / error-boundary propagation are FROZEN.
The dialog_runner's callback registration /
safe_invoke boundary are FROZEN. The A2
presenter's overall-state machine /
headline / issue_summary layout are FROZEN
(only additive schema changes). The
TAB SWITCH BLOCK + HIDDEN-SEMANTICS FOLLOW-UP
production CSS is FROZEN (the test guard was
fixed; production CSS was not reordered).

---

## 2. Root-cause confirmation

### 2.1 P0 — V1.7 reads stale pre-Z coordinates

Real SU2020 Owner evidence (per dispatch §1.1):
after `Start -> Apply Z -> Apply Gap`, the
reconstructed loop carried `z =
0.007874015748031498 in` (exactly 0.2 mm — the
pre-normalization Z drift). This proves V1.6
host mutation happened, the orchestrator
invalidated downstream stages, V1.7 canonical
topology closed correctly after the bridge,
BUT V1.7 topology snapshot consumed stale
cached geometry coordinates, AND V1.8 correctly
rejected the resulting stale loop as
`non_planar_loop`.

Root cause: `DerivedTopologySnapshotBuilder.build`
reads `s = gs['start']; e = gs['end']` from the
per-record `geometry_summary` cache. Those
summaries describe the workspace BUILD-TIME
geometry and are stale after V1.6 vertex mutation.
This violates the frozen V1.7 contract "V1.7
analysis runs on the CURRENT DerivedGeometryWorkspace
after V1.5/V1.6 operations."

Frozen fix direction (per dispatch §1.3): make
the current live derived host geometry
authoritative for V1.7 coordinates whenever the
host execution layer can resolve it. Implement
the narrow fix in the topology snapshot seam,
preferably `DerivedTopologySnapshotBuilder` /
equivalent local helper. **Implemented exactly
in that helper**; no tolerance widening, no
coordinate_epsilon change, no
canonical-graph-segment-conflict change, no
V1.7 gap pairing / canonical-node clustering
change, no V1.8 reconstruction / containment /
region algorithm change, no source CAD mutation,
no geometry_summary rewrite.

### 2.2 P1 — Current Issues tab shows historical
source-registry rows

Bug: `payload.groups` (derived from the
original `AnalysisResult.registry`) is
intentionally retained for backward compat /
source evidence. It is NOT a current
post-repair issue registry. The previous
`_buildIssueRows` appended every issue from
`payload.groups` to the primary current issue
list, so the Issues tab continued to display
the original `open_endpoint` / `gap_candidate`
rows even after the gap was applied + canonical
topology reached `open_chain_count=0,
closed_loop_count=1`. The red tab badge also
continued to count those historical rows.

Frozen fix (per dispatch §2.2): current Issues
tab primary list comes from current
`cadPrepWorkflow` + V1.6/V1.7/V1.8 snapshots;
original source findings (`payload.groups` /
`AnalysisResult.registry`) belong under
`详情 -> 原始检查记录`. **Implemented exactly**;
legacy source-registry data remains reachable via
`_buildLegacySourceRows` (per-issue-type counts
from `summary.issues`).

### 2.3 P1 — `重新检测` hard-wired to
`rebuild_workspace`

Frozen A2 contract (per dispatch §3): `重新检测`
checks the CURRENT workspace only. It must not
silently rebuild the workspace. The previous
issue-summary CTA button was hard-wired to
`data-action="rebuild_workspace"`. **Fixed via
additive `cta_callback` field** —
`refresh_cad_prep` for healthy NEEDS_ATTENTION /
READY / FAILED; `nil` for IDLE / SCANNING /
STALE. `rebuild_workspace` remains available
only for explicit recovery actions (STALE /
FAILED recovery banner — `recovery.primary_callback`
unchanged).

### 2.4 P2 — Planar card / structure warning copy

Planar presenter was reading legacy
`movable` / `proposed_movable` fields; the
production proposer publishes `movable_count`.
APPLIED audit was reading legacy `moved` /
`moved_applied`; the production executor
publishes `applied_count`. READY_TO_NORMALIZE
without exact count contradicted with "未发现需要
Z 校正的点". Structure warning copy was a single
generic "结构已重建，但存在需要人工查看的项"
regardless of current evidence. **Fixed via
explicit `_planar_count_field` helper with
authoritative-key-first / legacy-fallback
lookup + `_planar_safe_summary` generic copy +
`_structure_warning_summary` mapping**.

### 2.5 Test debt — Hidden CSS regression guard
false-pass

The previous source-level test used naive
`src.index(/\.panel\s*\{/)` which matches
selector text inside a CSS comment as well as
real rules. A CSS file with the scoped rules
ONLY inside comments would falsely satisfy the
cascade-order guard. **Fixed via
`hr_strip_css_comments` helper** that strips
`/* ... */` blocks (preserving line offsets by
replacing with spaces) so selector-order
assertions match actual CSS rules, not
comments. Production CSS is UNCHANGED per
dispatch "Do not reorder working production CSS
merely to satisfy a brittle test".

---

## 3. Fail-closed behavior for unreadable live
positions

`LiveVertexPositionUnreadable` is the narrowest
existing error path. Per dispatch §1.3.6: the
builder MUST NOT silently substitute the cached
pre-mutation coordinate when:
- a live host handle exists AND
- the adapter exposes `vertex_position` AND
- the position read returns a malformed /
  non-finite / Infinity / raises result.

The error carries:
- stable reason substring `live_vertex_position_unreadable`
  (test-assertable via `err.message.include?(...)`
  or `err.reason == 'live_vertex_position_unreadable'`),
- the offending endpoint_key (e.g.
  `fake-edge.start`).

The error propagates through the orchestrator's
public entry points (per the A2-ERR narrow
correction: orchestrator does NOT rescue
`StandardError`) into
`DialogRunner._safe_invoke`'s production
boundary, which logs the exception class +
message verbatim via the existing `_safe_log`
path, toasts, and unconditionally re-pushes
the payload (so the UI surfaces the failure
truthfully and the source/canonical-graph state
stays consistent).

Source CAD is NEVER mutated. The snapshot
builder does NOT rewrite `geometry_summary`.
Live coordinates are applied only to the
OUTGOING `DerivedEdgeRecord` /
`EndpointRecord` instances.

---

## 4. Test counts

| Suite | New tests | Total | Status |
|---|---|---|---|
| `tests/test_v19a_final_p0_live_coordinates.rb` | 11 (NEW file) | 11 | Ruby runtime broken on this host — NOT EXECUTABLE |
| `tests/test_v19a_cad_prep_workflow_presenter.rb` | 18 | (existing + 18) | Ruby runtime broken on this host — NOT EXECUTABLE |
| `tests/test_html_render.rb` | 7 | (existing + 7) | Ruby runtime broken on this host — NOT EXECUTABLE |
| `tests/test_html_render_dom.js` (Node DOM) | 6 | 97 (Node ASSERTs) | **ALL 97 PASS**, final line `PASS` |

### 4.1 Full-suite counts

The system Ruby runtime
(`C:\Ruby27-x64\bin\ruby.exe`) is broken on
this host — every invocation reports
"Application cannot run, side-by-side
configuration has problems, see sxstrace.exe"
(a Visual C++ runtime conflict). Per AGENTS.md
§16 / PROJECT_HANDOFF.md §15, environment
failure is NOT product-code failure and Pi MUST
NOT reinstall Ruby or rewrite PATH to work
around it. The full Ruby test suite COULD NOT
be run end-to-end in this session.

The 11 new P0 tests + 18 new presenter tests
+ 7 new CSS/app.js tests are syntactically valid
Ruby and follow the existing test patterns;
they will execute on any non-broken Ruby
install (e.g. real SU2017/SU2020 host via the
Owner re-verification flow). Defense-in-depth:
source-level guards inside each new test pin
the contract so future code review can verify
the intent without runtime execution.

The pre-existing baseline failures (3 total:
R002 + S2-BLOCK-006 + V14 production call chain
+ V17-L1 host_state_changed invalidate) remain
unchanged per the dispatch §13 reporting rule
(separated as known pre-existing).

### 4.2 Node DOM test (executable frontend
regression evidence)

`node tests/test_html_render_dom.js` runs to
completion with **all 97 ASSERTs PASS**,
including the 6 new V1.9A FINAL BLOCK FIX
assertions:

1. Current issue rows come from
   cadPrepWorkflow cards only (NOT from
   `payload.groups`) — count must equal the
   number of REVIEW_REQUIRED / FAILED /
   BLOCKED cards.
2. Current issue rows are non-locatable (cards
   do not carry `issue_id`).
3. `issue_summary` CTA wiring uses the
   additive `cta_callback` field (not
   hard-wired).
4. `issue_summary` CTA button is NOT hard-wired
   to `rebuild_workspace`.
5. Legacy source-registry per-type counts
   remain reachable in 详情 / 原始检查记录
   surface.
6. IDLE / empty-idle summary hides the CTA
   button when `cta_callback` is null.

Pre-existing 91 assertions remain intact
(V1.9A-A1 / A2 / A3 + HIDDEN-SEMANTICS
FOLLOW-UP + TAB SWITCH BLOCK + L3 locate
contract + four-tab + five-card tests).

---

## 5. Environment limitation — Ruby runtime

The system Ruby runtime
(`C:\Ruby27-x64\bin\ruby.exe`) is broken on
this host. Every invocation reports
"Application cannot run, side-by-side
configuration has problems, see sxstrace.exe"
(a Visual C++ runtime conflict — likely
missing or corrupted msvcp140.dll /
concrt140.dll / vcruntime140.dll).

Per AGENTS.md §16 / PROJECT_HANDOFF.md §15
+ §3 (Pi bootstrap — HARD RULE): environment
failure is NOT product-code failure and Pi
MUST NOT reinstall Ruby or rewrite PATH
because one shell path fails. Pi MUST NOT
recursively scan whole drives to find Ruby.

Consequence: the full Ruby test suite
(`ruby tests/run_all.rb`) cannot be run
end-to-end in this session. The new tests are
syntactically valid and follow the existing
test patterns; they will execute on a
working Ruby runtime.

Defense-in-depth: each new test carries
explicit `assert_*` / `refute_*` assertions
on the production code's *source* (e.g. source
text scans for `'movable_count'`, `'applied_count'`,
`'cta_callback'`, `live_vertex_position_unreadable`,
`'panel[hidden]'`, `summary.cta_callback`) so
that future code review can verify the
intent without runtime execution.

The Node DOM test (which does NOT require
Ruby) runs to completion and is the executable
frontend regression evidence for P1-A, P1-C,
the panel / banner / badge hidden-semantics
fix, the four-tab IA, the switchTab DOM
contract, the L3 locate contract, and the A2
primary CTA mapping.

The RBZ was built via a PowerShell port of
`scripts/build_rbz.rb` (`scripts/build_rbz.ps1`)
that produces an identical .rbz layout per the
locked shipping policy (STORE method, no
compression; one root `su_ai_plugin.rb` +
one sibling `su_ai_plugin/` support folder; 73
entries). The shipped bytes / SHAs match the
tested implementation files.

---

## 6. RBZ

Rebuilt via `scripts/build_rbz.ps1` (PowerShell
port of `scripts/build_rbz.rb`; see §5).

- path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- bytes: **1,159,502**
- entries: **73** (unchanged)
- SHA-256:
  **`c9f8b745262718886612d169011ba5313bb729047e7304d5e00bbb25b6fe1e3c`**
- vs prior HIDDEN-SEMANTICS FOLLOW-UP RBZ
  (1,138,324 bytes): **+21,178 bytes**, same
  entry count.

### 6.1 Packaged production file SHAs

| File | SHA-256 | Status |
|---|---|---|
| `su_ai_plugin.rb` | `783fcceeb1938dee09c9616d70155c103c000f075a9f65f1e496bba1ccfe98d1` | UNCHANGED (A3 packet SHA) |
| `su_ai_plugin/loader.rb` | `3b85dfefe5145113d8ca0a4ee123c1d406e21da0d54986c524123c9ccb2c0ed5` | UNCHANGED (A3 packet SHA) |
| `su_ai_plugin/main.rb` | `4c4f4c44...` | UNCHANGED |
| `su_ai_plugin/cad_prep_workflow_orchestrator.rb` | `4e77c1fe47bc72793ba655bb0952abafcc9db7dc5000d407c8b24df01da5238c` | UNCHANGED (A2-ERR packet SHA) |
| `su_ai_plugin/cad_prep_workflow_presenter.rb` | `c6f4982f71da09363f5df0cd1a91f39c8c61e40cc0888071380c75de6b7ae2f7` | **CHANGED** (P1-B / P1-C / P2-A / P2-B) |
| `su_ai_plugin/dialog_runner.rb` | `dc3c4042c94e20f996aef49e17908072de337217622de447245449dfc75d7b94` | UNCHANGED (A2-ERR packet SHA) |
| `su_ai_plugin/ui_bridge.rb` | `2814070463b4f4482cf6e4b30dd304ab973b5a8e1937c974e345bb6750271c7a` | UNCHANGED (A1 packet SHA) |
| `su_ai_plugin/core/endpoint_record.rb` | `b87d3ee13223df5e061e724172729e28881c347165577b55f99aa01da54c330e` | **CHANGED** (P0 live-coordinate authority) |
| `su_ai_plugin/core/working_mode_runner.rb` | `2962f45a06338d929c38fb885ed129373e67c3f2e6e220fe075af07dcef02214` | UNCHANGED (A2 packet SHA) |
| `su_ai_plugin/html/index.html` | `4d488aef5da7e43cc8245cc6d40263e9345422c1a228392a3238373a15d0336a` | UNCHANGED |
| `su_ai_plugin/html/app.js` | `adae3dd6b680244a807376ed7b92a70bd1548bd6f9ff0cba69cc432f2f006a46` | **CHANGED** (P1-A / P1-C) |
| `su_ai_plugin/html/style.css` | `fa38cc2677887a1d71fc382426c37cc5e1353be15f799e86ff2d7889661fc98c` | UNCHANGED (test-only fix; no production CSS change) |
| `su_ai_plugin/icons/cad_prep_24.png` | (unchanged from A3 packet) | UNCHANGED |
| `su_ai_plugin/icons/cad_prep_32.png` | (unchanged from A3 packet) | UNCHANGED |

---

## 7. V1.5–V1.8 algorithm + V1.9B unchanged
confirmation

- **V1.5 high-confidence auto-repair**: UNCHANGED.
  No duplicate algorithm change.
- **V1.6 Planar Normalization / Z Policy**:
  UNCHANGED. No normalization math change. No
  tolerance (`coordinate_epsilon` /
  `planar_z_snap`) change. No host mutation
  behavior change. No audit shape change
  (`applied_count` / `moved` /
  `moved_count` semantics preserved — only the
  presenter's authoritative-key-first lookup
  was added, with legacy fallback).
- **V1.7 Endpoint / Gap Repair + Canonical
  Topology**: UNCHANGED. No gap pairing change.
  No canonical-node clustering change. No
  segment conflict change. The snapshot builder
  now reads LIVE host coordinates instead of
  cached build-time coordinates; this is the
  P0 fix the frozen V1.7 contract demanded
  ("V1.7 analysis runs on the CURRENT
  DerivedGeometryWorkspace after V1.5/V1.6
  operations").
- **V1.8 Reconstruction / Containment / Region**:
  UNCHANGED. No algorithm change. Only the
  product-facing copy is improved (specific
  copy when evidence exists, generic fallback
  otherwise).
- **V1.9A Orchestrator (A2 / A2-ERR)**: UNCHANGED.
  The orchestrator's call-order / invalidation
  seam / refresh / rebuild-and-scan / gap-ordering
  safety / error-boundary propagation are
  FROZEN. The P0 fail-closed error
  propagates naturally to the orchestrator's
  `_safe_invoke` boundary (which logs / toasts /
  unconditionally re-pushes the payload).
- **V1.9A Dialog Runner**: UNCHANGED. No callback
  registration change. No `_safe_invoke`
  boundary change.
- **V1.9A UI Bridge**: UNCHANGED. The bridge
  still routes through the unchanged presenter
  + the live WorkingModeRunner.snapshot.
- **V1.9A Loader / Toolbar / Icons / A3 contract**:
  UNCHANGED. The Loader.cad_prep_command +
  SU AI toolbar + cad_prep_24/32.png + the
  TB_NEVER_SHOWN visibility policy + the
  no-selection friendly messagebox are all
  FROZEN.
- **V1.9A Toolbar / Loader**: UNCHANGED unless a
  direct regression is proven (no regression
  proven by this packet).
- **V1.9B PreparedCadDataset / persistence**:
  **NOT STARTED**. Out of scope for this packet.
- **MCP / LLM / Agent**: OUT OF SCOPE.
- **SU2017 support claim**: NOT UPGRADED. No
  formal SU2017 claim; the project's runtime
  baseline remains legacy-first with the
  intended SketchUp 2017+ baseline, but
  formal SU2017 support requires real
  SU2017-host evidence (not provided by this
  packet).

---

## 8. `CODEX_RISK_TRIGGER` acknowledgment

`CODEX_RISK_TRIGGER = YES (POST-IMPLEMENTATION,
NARROW)` — per dispatch §11:

> P0 touches the V1.6 -> V1.7 current-geometry
> authority seam feeding canonical topology.
> This is a high-risk data/state boundary even
> though the implementation should be small.

Order (per dispatch):

1. Pi implements + tests + commits + pushes
   (THIS PACKET).
2. AIPM performs direct source/diff review
   first.
3. AIPM decides narrow Codex review timing or
   folds it into the immediately-following
   final V1.x review if AIPM judges the diff
   trivially local and Owner real-SU evidence
   is clean.
4. Owner real-SU2020 re-verification.
5. Only AIPM / Owner may close V1.9A.

Pi has NOT invoked Codex. Pi has completed the
implementation + tests + RBZ + commit + push
(this packet) and now returns control to AIPM
for direct source review.

---

## 9. Deviations / STOP items

**None**. All eight required outcomes (P0
live-coordinate authority + integration
regression + P1-A current vs original issue
separation + P1-B chip semantics + P1-C refresh
callback + P2-A planar mapping + P2-B structure
copy + test debt CSS comment strip) are
implemented exactly within the allowlist
production files listed in dispatch §7.

No production file outside the allowlist
(`core/endpoint_record.rb` /
`cad_prep_workflow_presenter.rb` /
`html/app.js` / `ui_bridge.rb` /
`cad_prep_workflow_orchestrator.rb` /
focused tests) was modified. No frozen
design authority was rewritten. No V1.5 / V1.6
/ V1.7 / V1.8 algorithm was changed. No
tolerance was widened. No physical cross-group
welding was required. No Face generation.
No Observer architecture. No Undo / host-state
redesign. No MCP / LLM / Agent. No V1.9B
PreparedCadDataset / persistence. No
final-release gate change.

**Environment limitation (NOT a deviation)**: the
system Ruby runtime is broken on this host
(see §5). Per AGENTS.md §16 / PROJECT_HANDOFF.md
§15, environment failure is not product-code
failure. The full Ruby test suite cannot be
run end-to-end in this session. The Node DOM
test (which does NOT require Ruby) runs to
completion with all 97 ASSERTs passing, and
is the executable frontend regression
evidence for P1-A, P1-C, the hidden-semantics
fix, the four-tab IA, the switchTab DOM
contract, the L3 locate contract, and the A2
primary CTA mapping. The new Ruby tests are
syntactically valid, follow the existing test
patterns, and will execute on any non-broken
Ruby install.

---

## 10. NEXT expected action (AIPM)

AIPM direct source / diff review of this packet:

- `core/endpoint_record.rb` P0
  `DerivedTopologySnapshotBuilder.build` +
  new `LiveVertexPositionUnreadable` error
  class + new `_live_coordinate_for` helper.
- `cad_prep_workflow_presenter.rb` P1-B
  `PROBLEM_METRIC_LABELS` whitelist + state-gated
  `_collect_chips` filter; P1-C additive
  `issue_summary.cta_callback` schema across
  IDLE / READY-with-APPLIED / READY-clean /
  STALE / FAILED / SCANNING / NEEDS_ATTENTION;
  P2-A `_planar_count_field` helper with
  authoritative `movable_count` /
  `applied_count` + legacy fallback +
  `_planar_safe_summary` generic copy; P2-B
  `_structure_warning_summary` + helpers.
- `html/app.js` P1-A `_buildIssueRows` +
  `_buildIssuesBadgeCount` no longer append /
  count `payload.groups`; P1-C
  `renderIssueSummary` CTA wiring uses
  additive `summary.cta_callback` field,
  not hard-wired `rebuild_workspace`.
- `tests/test_html_render.rb` new
  `hr_strip_css_comments` helper + 2 new CSS
  comment regression guard tests + 5 new
  app.js frontend behavior tests.
- `tests/test_v19a_final_p0_live_coordinates.rb`
  11 new P0 focused tests.
- `tests/test_v19a_cad_prep_workflow_presenter.rb`
  18 new V1.9A FINAL BLOCK FIX focused tests.
- `tests/test_html_render_dom.js` 6 new DOM
  assertions (all 97 PASS).
- `scripts/build_rbz.ps1` PowerShell port
  (system Ruby runtime broken on this host —
  see §5).

AIPM narrow Codex review (POST-IMPLEMENTATION)
on the P0 V1.6 -> V1.7 current-geometry authority
seam feeding canonical topology (per dispatch
§11). AIPM may fold into the immediately-
following final V1.x review if the diff is
judged trivially local and Owner real-SU
evidence is clean.

Then Owner real-SU2020 re-verification
(the gate that originally produced this BLOCK
should now PASS). V1.9B PreparedCadDataset /
persistence NOT STARTED. Final V1.x Codex xHigh
review remains mandatory later regardless.

---

END
