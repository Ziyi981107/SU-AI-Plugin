# SU-AI-Plugin — CURRENT STATE

## V1.7 AIPM-PRIMARY-REVIEW-CORRECTION (THIS UPDATE)

Updated: 2026-09-01 (V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01
dispatch EXECUTION on assigned `dev/v1.7` per dispatch
`Prompt/CURRENT_PI_DISPATCH.md` and the frozen V1.7 Stage
Technical Blueprint
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`.)

Status (this dispatch):

- **V1.6: CLOSED** (per
  `Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md`).
- **V1.6 Owner SU2020 PASS** (Final Product Owner
  confirmation recorded by AIPM).
- **V1.7: ACTIVE** (per dispatch §0).
- **Frozen V1.7 Blueprint**: ACTIVE (unchanged).
- **V1.7 AIPM primary review**: pending direct source review
  of this packet.
- **V1.7 mandatory Codex review**: pending xHigh AFTER AIPM
  primary review. Pi does NOT invoke Codex.
- **V1.8 NOT STARTED**.
- **V2 / MCP OUT OF SCOPE**.

This dispatch corrected the four bounded primary-review findings
(R1 X1-X4 explicit tests + X3 pairwise check; R2 T3/T4 + bridge
endpoint canonical_node_id resolution; R3 workspace enum ->
canonical enum translation + geometry_summary-based reads; R4
test matrix reported honestly).

V1.7 CORRECTED PACKET — 2026-09-01.

- Starting HEAD: `792e99f6d6a140b4a250f316dc1e9d7beb8f6e4b` (the
  V17-GAP-TOPOLOGY implementation complete-state doc-stamp).
- Final HEAD on `dev/v1.7`: `7920dd0b5ff4845e728a8467cb6dd4852a98cf7d`
  (4 stable local commits: 1 production + 1 doc-stamp + 1
  patch refresh + 1 SHA update).
- V1.7 RBZ candidate: size **903,234 bytes**; entries **67**;
  SHA-256 **`1d34cdd0b6ec924f5f8c23a7fc94615a2b1743aa36d380c184f70de45e2cecc1`**.
- Full Ruby suite: **895 / 895 PASS** / 0 fail / 0 error
  (V1.0–V1.6 regressions + 52 V1.7 Ruby tests, +9 from
  V17-AIPM-PRIMARY-REVIEW-CORRECTION dispatch).
- Node DOM assertions: **PASS** (CN1..CN18 + V17-UI1..UI4 +
  V16-FIX, no JS-side change in this dispatch).
- V16-CLOSE-AUTODISCARD: 7/7 PASS (no regression).
- V15 host-state / BLOCK-005: 149/149 PASS (no regression).
- LEGACY-COMPAT: 4/4 PASS (no regression).
- RBZ smoke: 9/9 PASS (post-rebuild).
- `git diff --check`: clean.
- per dispatch §10: STOPPED awaiting AIPM direct source review;
  Codex xHigh integration review NOT invoked; V1.8 NOT
  STARTED; final Owner SU2020 real-host verification gate
  NOT YET RUN.

Frozen V1.7 Blueprint preserved unchanged on the assigned
`dev/v1.7`. Pi did NOT rewrite any frozen design authority.

New review artifacts produced by this dispatch:

- `Review/V17_AIPM_SOURCE_REVIEW.patch` (214,055 bytes;
  SHA-256 `9b417b88dfae4562575f83e788c2252fbbcf5611e41d0b6ece4846f9764434c0`).
- `Review/V17_AIPM_CRITICAL_SOURCE_INDEX.md`.

Next expected AIPM action: AIPM direct source review of this
corrected V1.7 packet against the frozen Blueprint + the prior
V1.4–V1.6 review evidence, then (on AIPM PASS) the mandatory
Codex xHigh integration review, then the final Owner SU2020
real-host verification gate Scenarios A–G.

CODEX_GATE: STILL PENDING — DO NOT INVOKE.
OWNER GATE: NOT YET RUN.

## V1.7 GAP-TOPOLOGY IMPLEMENTATION (HISTORICAL)

Updated: 2026-09-01 (V17-GAP-TOPOLOGY-IMPLEMENTATION-2026-09-01
dispatch EXECUTION on assigned `dev/v1.7` per dispatch
`Prompt/CURRENT_PI_DISPATCH.md` and the frozen V1.7 Stage
Technical Blueprint
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`.)

Status (this dispatch underway):

- **V1.6: CLOSED** (per
  `Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md` and the prior
  CURRENT_PI_REPORT closure record).
- **V1.6 Owner SU2020 PASS** (Final Product Owner
  confirmation recorded by AIPM).
- **V1.7: ACTIVE** (per dispatch §0).
- **Frozen V1.7 Blueprint**: ACTIVE
  (`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`).
- **V1.7 mandatory Codex review**: pending xHigh AFTER AIPM
  primary review. Pi does NOT invoke Codex.
- **V1.8 NOT STARTED**.
- **V2 / MCP OUT OF SCOPE**.

Starting V1.7 baseline:

- Branch: `dev/v1.7` (created from exact local closed V1.6
  HEAD `d7e9c59`).
- V1.7 docs commit: `0bac757` (track V1.6 closure record +
  V1.7 Blueprint as durable authority documents).
- V1.6 RBZ baseline: size 768,150 bytes; entries 62; SHA-256
  `7154C6C96759E847CA99A99E9B8B62F88BF230E0741CDFED884586425960BAE7`.

Full V1.7 implementation summary will be appended to this
dispatch block when the dispatch completes.

V1.7 IMPLEMENTATION COMPLETE — 2026-09-01.

- Starting HEAD: `0bac757`.
- Final HEAD on `dev/v1.7`: `4e05023` (8 stable local commits:
  docs anchor → 5 implementation → tests → dispatch + report).
- V1.7 RBZ candidate: size 890,087 bytes; entries 67; SHA-256
  `b0064262f4cc9b52d02db75a86aeda9d75b03f7bba14eed55d2ce0a6c999f3f5`.
- Full Ruby suite: **886 / 886 PASS** / 0 fail / 0 error
  (V1.0–V1.6 regressions + 36 new V1.7 Ruby tests).
- Node DOM assertions: **PASS** (existing V1.6 CN1..CN18 +
  V17-UI1..V17-UI4 topology-repair Chinese card assertions).
- per dispatch §13: STOPPED awaiting AIPM direct source review;
  Codex xHigh integration review NOT invoked; V1.8 NOT
  STARTED; final Owner SU2020 real-host verification gate
  NOT YET RUN.

Frozen V1.7 Blueprint preserved unchanged on the assigned
`dev/v1.7`. Pi did NOT rewrite any frozen design authority.

Next expected AIPM action: AIPM direct source review of this
implementation packet against the frozen Blueprint + the prior
V1.4–V1.6 review evidence, then (on AIPM PASS) the mandatory
Codex xHigh integration review, then the final Owner SU2020
real-host verification gate Scenarios A-G.
Codex review is NOT a routine reviewer for V1.7 and was NOT
self-invoked by Pi.

(For complete V1.6 closure facts and the prior dispatch
blocks, see the historical sections below this dispatch.)

---

## V1.6 CLOSE-AUTODISCARD DISPATCH (HISTORICAL)

Updated: 2026-09-01 (V16-CLOSE-AUTODISCARD-2026-09-01
dispatch EXECUTION COMPLETE on assigned `dev/v1.6`. The
prior V16-UI-CN-SIMPLIFICATION + V16-UI-CN-SIMPLIFICATION-FIX
packets are intact; this dispatch performed ONE bounded
Owner UX fix BEFORE closure: when the user explicitly
closes the SU-AI-Plugin dialog, the EXISTING discard-workspace
path is automatically run if (and only if) a current
transient Derived Workspace exists, so the next plugin-open
session begins cleanly with the normal primary action
`准备处理` (per the V16-UI-CN-SIMPLIFICATION-FIX action-state
matrix). The frozen V1.6 Stage Technical Blueprint + the
V1.6 backend are untouched.)

Closure date for the prior V1.5 closure: 2026-08-31
(unchanged).

Status:

- **V1.5: CLOSED**
- **BLOCK-005: CLOSED**
- **Owner SketchUp 2020 V1.5 verification: PASS** (Final
  Product Owner confirmation recorded by AIPM)
- **BLOCK-005 technical direction (unchanged, frozen):**
  `validate-on-next-interaction → detect host mismatch → fail
  closed / invalidate → host-authoritative discard +
  prepare/rebuild`. No global ModelObserver / EntitiesObserver
  architecture added in V1.5. `persistent_id` is not the
  correctness Source of Truth. Old Ruby Entity handles must
  never be trusted after host-state divergence.
- **V1.6: UI CN SIMPLIFICATION + UI CN SIMPLIFICATION FIX +
  CLOSE-AUTODISCARD COMPLETE / AWAITING AIPM SOURCE REVIEW**
  (per dispatch `V16-CLOSE-AUTODISCARD-2026-09-01`, on
  assigned `dev/v1.6`). The prior V16-UI-CN-SIMPLIFICATION +
  V16-UI-CN-SIMPLIFICATION-FIX packets are intact; this
  dispatch added the bounded close-time auto-discard per
  `Review/CURRENT_PI_REPORT.md`.
- **V1.6: OWNER REAL-HOST VERIFICATION A-E: PASSED** (per
  Owner / Owner-AIPM step before the close-autodiscard
  finding; recorded by AIPM in the prior closure path).
- **V1.6: NOT CLOSED** (closure is Owner / AIPM-side per
  dispatch §15 + §9; V1.6 frozen Blueprint §13 requires
  real-SU2020 Owner verification of the close-autodiscard
  fix before closure).
- **V1.7: NOT STARTED**
- **V2 / MCP: OUT OF SCOPE**

Accepted V1.5 RBZ (verified, unchanged by this CLOSURE-ONLY sync):

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz` (overwritten by the V1.6 RBZ)
- Size: **642,037 bytes**
- Entries: **59**
- SHA-256: **`61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292`**

V1.6 UI-INTEGRATION-CORRECTION RBZ (prior dispatch, superseded by later dispatches' RBZ):

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **744,607 bytes** (+11,103 vs V1.6 PI-impl RBZ, the delta is the
  rendered Planar Normalization block + audit rendering + the
  action button wiring + the H5 regression test).
- Entries: **62** (unchanged from V1.6 PI-impl).
- SHA-256: **`c9c1f4f0503957a1fe5073957df2d67996be6ec74cff0d95d5c046ab6bfa585d`**

V1.6 UI-CN-SIMPLIFICATION RBZ (prior dispatch, superseded by this dispatch's RBZ):

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **762,012 bytes** (+17,405 vs V1.6 UI-INTEGRATION-
  CORRECTION RBZ, the delta is the Simplified Chinese label
  maps in app.js + the condensed Working Mode card + the
  collapsed `更多操作` block + the new collapsed `技术详情`
  block in index.html + the Simplified Chinese `dialog_title`
  in dialog_runner.rb + the CN1-CN18 DOM test coverage + the
  Ruby source-level CN guards).
- Entries: **62** (unchanged).
- SHA-256: **`BBDF9BC1277878AD1B8B83A5FA1C9B37A6F26EC75D979F8BE6CFC8BCBAB0F7D9`**

V1.6 UI-CN-SIMPLIFICATION-FIX RBZ (prior dispatch, superseded by this dispatch's RBZ):

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **764,857 bytes** (+2,845 vs V1.6 UI-CN-SIMPLIFICATION
  RBZ, the delta is the `discarded` + `failed` state primary
  CTA fix in app.js + the V16-FIX DOM regression tests).
- Entries: **62** (unchanged).
- SHA-256: **`A8326FE595FD4F3E99F63AD43BA7B540422650264FE449F8A2E94F662CA3074F`**

V1.6 CLOSE-AUTODISCARD RBZ candidate (this dispatch):

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **768,150 bytes** (+3,293 vs V1.6 UI-CN-SIMPLIFICATION-
  FIX RBZ, the delta is the close-time auto-discard path in
  dialog_runner.rb + 7 new V16-CLOSE-AUTODISCARD Ruby
  regression tests).
- Entries: **62** (unchanged).
- SHA-256: **`7154C6C96759E847CA99A99E9B8B62F88BF230E0741CDFED884586425960BAE7`**

Packaged `html/app.js` SHA-256:
**`7CF8A33BF5AE4FE74FDB0E0DA85BAFAB8A2CF4D02B5B72A6B86F6D43A55C30A0`**
(unchanged from prior V16-UI-CN-SIMPLIFICATION-FIX — the
close-time auto-discard is a Ruby-side change in
`dialog_runner.rb`, not a JS change)
Packaged `html/index.html` SHA-256:
**`6405DD9EB10A4C4CFCC73CD15AA8B54BC4DAF1D5F631780D7DB6308EAAD6489D`**
(unchanged from prior V16-UI-CN-SIMPLIFICATION)
Packaged `html/style.css` SHA-256:
**`3FAAB5E5C6C9757DDE90D2F984B02F2F357727553232BC7FC70814C7709BB95B`**
(unchanged from prior V16-UI-CN-SIMPLIFICATION)

All three packaged dialog assets are byte-identical to the
in-tree source (per the existing smoke-test contract).

Next expected AIPM action: AIPM direct source review of the
V1.6 close-autodiscard packet against the frozen Blueprint
+ the prior V1.6 review evidence, then (on AIPM PASS) the
final Owner SU2020 real-host verification gate. Codex review
is NOT a routine reviewer for V1.6 and was NOT invoked.

Closure date for the prior V1.5 closure: 2026-08-31
(unchanged).

Status:

- **V1.5: CLOSED**
- **BLOCK-005: CLOSED**
- **Owner SketchUp 2020 V1.5 verification: PASS** (Final
  Product Owner confirmation recorded by AIPM)
- **BLOCK-005 technical direction (unchanged, frozen):**
  `validate-on-next-interaction → detect host mismatch → fail
  closed / invalidate → host-authoritative discard +
  prepare/rebuild`. No global ModelObserver / EntitiesObserver
  architecture added in V1.5. `persistent_id` is not the
  correctness Source of Truth. Old Ruby Entity handles must
  never be trusted after host-state divergence.
- **V1.6: UI CN SIMPLIFICATION + UI CN SIMPLIFICATION FIX
  COMPLETE / AWAITING AIPM SOURCE REVIEW** (per dispatch
  `V16-UI-CN-SIMPLIFICATION-FIX-2026-09-01`, on assigned
  `dev/v1.6`). The prior V16-UI-CN-SIMPLIFICATION packet is
  intact; this dispatch fixed the Owner real-host
  regression (discarded state primary CTA = `准备处理`,
  Rebuild as secondary) per
  `Review/CURRENT_PI_REPORT.md`.
- **V1.6: OWNER REAL-HOST VERIFICATION NOT YET RUN** (SketchUp
  2020 Owner / Owner-AIPM step remains after AIPM source
  review).
- **V1.6: NOT CLOSED** (closure is Owner / AIPM-side per
  dispatch §15 + §9; V1.6 frozen Blueprint §13 requires
  real-SU2020 Owner verification before closure).
- **V1.7: NOT STARTED**
- **V2 / MCP: OUT OF SCOPE**

Accepted V1.5 RBZ (verified, unchanged by this CLOSURE-ONLY sync):

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz` (overwritten by the V1.6 RBZ)
- Size: **642,037 bytes**
- Entries: **59**
- SHA-256: **`61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292`**

V1.6 UI-INTEGRATION-CORRECTION RBZ (prior dispatch, superseded by later dispatches' RBZ):

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **744,607 bytes** (+11,103 vs V1.6 PI-impl RBZ, the delta is the
  rendered Planar Normalization block + audit rendering + the
  action button wiring + the H5 regression test).
- Entries: **62** (unchanged from V1.6 PI-impl).
- SHA-256: **`c9c1f4f0503957a1fe5073957df2d67996be6ec74cff0d95d5c046ab6bfa585d`**

V1.6 UI-CN-SIMPLIFICATION RBZ (prior dispatch, superseded by this dispatch's RBZ):

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **762,012 bytes** (+17,405 vs V1.6 UI-INTEGRATION-
  CORRECTION RBZ, the delta is the Simplified Chinese label
  maps in app.js + the condensed Working Mode card + the
  collapsed `更多操作` block + the new collapsed `技术详情`
  block in index.html + the Simplified Chinese `dialog_title`
  in dialog_runner.rb + the CN1-CN18 DOM test coverage + the
  Ruby source-level CN guards).
- Entries: **62** (unchanged).
- SHA-256: **`BBDF9BC1277878AD1B8B83A5FA1C9B37A6F26EC75D979F8BE6CFC8BCBAB0F7D9`**

V1.6 UI-CN-SIMPLIFICATION-FIX RBZ candidate (this dispatch):

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **764,857 bytes** (+2,845 vs V1.6 UI-CN-SIMPLIFICATION
  RBZ, the delta is the `discarded` + `failed` state primary
  CTA fix in app.js + the V16-FIX DOM regression tests).
- Entries: **62** (unchanged).
- SHA-256: **`A8326FE595FD4F3E99F63AD43BA7B540422650264FE449F8A2E94F662CA3074F`**

Packaged `html/app.js` SHA-256:
**`7CF8A33BF5AE4FE74FDB0E0DA85BAFAB8A2CF4D02B5B72A6B86F6D43A55C30A0`**
Packaged `html/index.html` SHA-256:
**`6405DD9EB10A4C4CFCC73CD15AA8B54BC4DAF1D5F631780D7DB6308EAAD6489D`**
(index.html unchanged from prior V16-UI-CN-SIMPLIFICATION
dispatch)
Packaged `html/style.css` SHA-256:
**`3FAAB5E5C6C9757DDE90D2F984B02F2F357727553232BC7FC70814C7709BB95B`**
(style.css unchanged from prior V16-UI-CN-SIMPLIFICATION
dispatch)

All three packaged dialog assets are byte-identical to the
in-tree source (per the existing smoke-test contract).

Next expected AIPM action: AIPM direct source review of the V1.6
UI CN simplification fix packet against the frozen Blueprint +
the prior V1.6 review evidence, then (on AIPM PASS) the Owner
SU2020 real-host verification gate. Codex review is NOT a
routine reviewer for V1.6 and was NOT invoked.

## V1.6 UI-INTEGRATION-CORRECTION DISPATCH (THIS UPDATE)

Updated: 2026-09-01 (V16-UI-INTEGRATION-CORRECTION-2026-09-01
dispatch EXECUTION COMPLETE on assigned `dev/v1.6`. AIPM direct
source review of the prior V1.6 PI-implementation packet found
ONE concrete integration blocker:

  - the prior V1.6 Ruby-side normalization state + dialog
    callbacks were implemented correctly, but the actual
    HTML/JS frontend was NOT wired to render the Planar
    Normalization state or to expose the user actions
    required by Blueprint section 11;
  - the prior report claimed an existing "Planar
    normalization" row was surfaced and that Owner should
    click "Apply Safe Normalization", but inspection of the
    unchanged V1.5 frontend source confirmed the rendered
    Working Mode had no Planar Normalization rows
    and no Planar Normalization action buttons.

This dispatch corrected that bounded integration gap only.

Concretely this dispatch added:

  - `extension/su_ai_plugin/html/app.js`:
    a new `renderPlanarNormalization(listEl, workspaceState,
    pn)` helper that renders the compact Blueprint section 11
    rows (State, Target Z, Eligible Vertices, Proposed Movable,
    Outliers, Affected Derived Edges, Skipped / Ambiguous
    Scope, Max Proposed Movement, Review Reason) AND a new
    `renderPlanarNormalizationAction(actionsEl, workspaceState,
    pn)` helper that wires the locked "Analyze Planarity" /
    "Apply Safe Normalization" button. Action wiring contract:
    workspaceState === 'ready' AND pnState ===
    'NOT_COMPUTED' -> "Analyze Planarity" enabled ->
    `window.sketchup.compute_planar_normalization`;
    workspaceState === 'ready' AND pnState ===
    'READY_TO_NORMALIZE' -> "Apply Safe Normalization"
    enabled -> `window.sketchup.apply_planar_normalization`;
    ALL other states (REVIEW_REQUIRED / NO_CANDIDATE /
    APPLIED / FAILED / invalid_tolerance / invalid_input /
    missing planar_normalization / non-ready workspace) ->
    NO action button (info only). The destructive Apply
    Safe Normalization action MUST NOT appear enabled in any
    state other than READY_TO_NORMALIZE (per dispatch section
    2.2 bullet 2). textContent only (locked contract preserved).
  - The post-apply audit (state, target_z, moved/applied
    count, max_movement, outliers_unchanged, failure_reason)
    is rendered from `pn.audit` when present (no client-side
    source of truth; the Ruby snapshot remains authoritative).
  - `tests/test_html_render_dom.js`: 49 new assertions
    covering UI1-UI8 (NOT_COMPUTED preview, READY_TO_NORMALIZE
    apply, REVIEW_REQUIRED / NO_CANDIDATE / APPLIED / FAILED
    fail-closed, missing / malformed payload degrade,
    V1.4/V1.5 controls unchanged). The DOM test loads the
    SHIPPED app.js (no parallel helper).
  - `tests/test_v16_planar_normalization.rb`: 1 new test
    (V16-H5: native Undo after applied normalization -> the
    existing V1.5 BLOCK-005 validate-on-next-interaction path
    remains safe; no new Observer architecture added). H5
    was the one missing test from the prior V1.6 PI-impl
    report's H1-H6 claim; it is now covered.
  - `extension/su_ai_plugin/core/working_mode_runner.rb`:
    trivial non-semantic integration seam fix in
    `_attach_planar_normalization_to_snapshot` -- when only
    an audit row is present (post-Apply), the snapshot's
    `state` field is derived from the audit's `status`
    (`'applied' -> 'APPLIED'`, `'failed' -> 'FAILED'`) so
    the UI does not falsely render `NOT_COMPUTED` after a
    terminal Apply. Pure data shape change; no normalization
    semantics touched.

Production files NOT modified by this dispatch:
planar_normalization_analyzer.rb,
planar_normalization_proposer.rb,
planar_normalization_executor.rb, tolerance.rb,
analysis_config.rb, derived_workspace_adapter.rb,
su_derived_workspace_adapter.rb, dialog_runner.rb, main.rb.

RBZ identity (post-rebuild):

- Size: 744,607 bytes
- Entries: 62 (unchanged)
- SHA-256: `c9c1f4f0503957a1fe5073957df2d67996be6ec74cff0d95d5c046ab6bfa585d`
- Packaged `html/app.js` SHA-256:
  `b0056640d283a40e0db71f54f1b5405554ebc4d08ed5e96772cd6bd2f5c820d0`
  (byte-identical to in-tree source)

Test evidence (this dispatch):

- Full Ruby suite: 843 / 843 PASS / 0 fail / 0 error
  (was 842 before this dispatch; +1 = the V16-H5 test).
- V16 substring: 26 / 26 PASS (P1-P9, G1-G6, H1-H6,
  T1-T3, I1-I3) -- H5 is now covered.
- LEGACY-COMPAT substring: 4 / 4 PASS (unchanged).
- RBZ smoke: 9 / 9 PASS.
- Node DOM (test_html_render_dom.js): PASS
  (49 new UI1-UI8 assertions added on top of the existing
  V14 / V15 / V1.6 assertions).
- `git diff --check`: clean.

H5 evidence disposition (per dispatch section 6): H5 is now
covered by V16-H5 using the existing approved
`simulate_host_state_change!` / `validate_host_state_consistency!`
seam (same pattern as V15-B005-3). No new Observer / Undo
architecture was added. Per dispatch section 6, the H5 test
exercises: apply normalization -> simulate host-state
invalidation -> validate-on-next-interaction -> workspace
transitions to :failed with stable reason `host_state_changed`
-> no stale READY_TO_NORMALIZE state in the snapshot ->
source CAD immutable -> the existing V1.5 BLOCK-005 path
remains the canonical recovery seam.

CODEX_TRIGGER: NO (per dispatch section 8). No material
repo-aware issue uncovered; the V1.6 backend architecture is
unchanged; the prior frozen PlanarNormalizationAnalyzer /
Proposer / Executor / Tolerance / Adapter / WorkingModeRunner /
DialogRunner work is intact and re-verified by 26 V16 tests.
The UI fix is the smallest frontend integration seam needed
to make the already-registered callbacks reachable from the
shipped frontend, plus a one-line trivial snapshot-state
derivation fix in the runner so the UI does not falsely render
NOT_COMPUTED after a terminal Apply.

V1.6 OWNER REAL-HOST VERIFICATION NOT YET RUN. V1.6 NOT CLOSED.

## V1.6 UI-CN-SIMPLIFICATION DISPATCH (THIS UPDATE)

Updated: 2026-09-01 (V16-UI-CN-SIMPLIFICATION-2026-09-01
dispatch EXECUTION COMPLETE on assigned `dev/v1.6`. The
prior V1.6 UI-INTEGRATION-CORRECTION packet is intact; this
dispatch performed the bounded frontend productization pass
per dispatch §0: Simplified Chinese localization of all
normal user-facing text + materially simpler default UI +
ONE primary CTA hierarchy + collapsed `技术详情` block
preserving the full data contract. The frozen V1.6 Stage
Technical Blueprint + the V1.6 backend (Planar
Normalization analyzer / proposer / executor / tolerance /
adapter / working mode runner / dialog runner) are
UNTOUCHED.)

This dispatch changed:

  - `extension/su_ai_plugin/html/app.js`:
    - Added Simplified Chinese label maps
      (`ISSUE_TYPE_LABELS_CN`, `LAYER_ROLE_LABELS_CN`,
      `LAYER_VISIBILITY_LABELS_CN`, `SEVERITY_LABELS_CN`,
      `WORKSPACE_STATE_LABELS_CN`, `PN_STATE_LABELS_CN`,
      `FIELD_LABEL_CN`, `ACTION_LABEL_CN`,
      `SECTION_LABEL_CN`).
    - Added `issueTypeLabelCN()` / `layerRoleLabelCN()` /
      `workspaceStateSentenceCN()` helpers.
    - Added `renderPrimaryAction()` (ONE primary CTA per
      current workspace + planar normalization state;
      unavailable actions are HIDDEN, not rendered as
      disabled).
    - Added `renderMoreActions()` (collapsed `更多操作`
      block carrying the secondary Discard / Rebuild
      controls).
    - Added `renderTechnicalDetails()` (collapsed `技术详情`
      block preserving source_snapshot_id /
      source_fingerprint_digest / execution_config_digest /
      raw workspace state / per-action audit (status,
      action_id, rule_id, survivor_id, removed_count,
      source_count, basis) / raw normalization audit
      (status, rule_id, rule_version, target_z,
      max_movement, applied_count, failed_count, reason)).
    - Added `renderDuplicateRepairUserRow()` (condensed
      Simplified Chinese "重复线清理：已处理 X，跳过 Y，
      失败 Z" row in the default Working Mode list).
    - Rewrote `renderPlanarNormalization()` to render the
      condensed Chinese card (`平面校正` / `目标 Z` /
      `待移动顶点` / `异常点` / `已移动` / `最大校正量` /
      `保留异常项` / `失败原因`).
    - Rewrote `renderWorkingMode()` for the new layout:
      concise Chinese status sentence + condensed
      user-facing rows + ONE primary CTA + collapsed
      `更多操作`.
  - `extension/su_ai_plugin/html/index.html`:
    - `<title>` `CAD Analyzer Result` → `CAD 检查结果`.
    - `<h1>` `CAD Analyzer Result` → `CAD 检查结果`.
    - Default `#selection-info` text `No selection` →
      `未选择对象`.
    - `<html lang="en">` → `<html lang="zh-CN">`.
    - Restructured section order: Working Mode is now BEFORE
      Layers / Issues by Layer / Face Inventory (the
      secondary sections are below the primary Working Mode
      + Technical Details blocks).
    - Added the collapsed `<details id="technical-details-
      section">` block with `<summary id="technical-details-
      summary">技术详情</summary>`.
    - Translated the static `<summary>` headers to
      Simplified Chinese (`处理工作区`, `按图层查看问题`,
      `图层信息`, `面信息`).
  - `extension/su_ai_plugin/html/style.css`:
    - Added Simplified-Chinese-friendly font stack
      (PingFang SC, Microsoft YaHei).
    - Added styles for the condensed Working Mode card,
      primary CTA prominence (border weight + font-weight;
      NO new color selectors), the collapsed `更多操作`
      block, and the `技术详情` block (monospace, neutral
      palette).
  - `extension/su_ai_plugin/dialog_runner.rb`:
    - `dialog_title: 'CAD Analyzer Result'` →
      `'CAD 检查结果'`.

Production files NOT modified by this dispatch:
- `planar_normalization_analyzer.rb`,
  `planar_normalization_proposer.rb`,
  `planar_normalization_executor.rb`, `tolerance.rb`,
  `analysis_config.rb`, `derived_workspace_adapter.rb`,
  `su_derived_workspace_adapter.rb`, `working_mode_runner.rb`,
  `main.rb`. The V1.6 frozen Blueprint + the V1.6 backend
  are unchanged.

Test files updated:
  - `tests/test_html_render_dom.js`:
    - Updated all English label assertions to Simplified
      Chinese.
    - Updated working-mode button structure expectations
      (ONE primary CTA + collapsed `更多操作`; NO disabled
      buttons).
    - Updated V15 BLOCK-004 audit-row placement (now under
      `技术详情`, NOT in the default Working Mode list).
    - Updated UI1-UI8 Simplified Chinese V1.6 Planar
      Normalization card + locked primary CTA behavior.
    - Added the CN1-CN18 block per dispatch §10 (54
      explicit assertions).
    - Total: 240+ existing assertions + 54 new = 294/294
      PASS / 0 FAIL.
  - `tests/test_html_render.rb`:
    - Updated `ISSUE_TYPE_LABELS` / `LAYER_ROLE_LABELS` /
      `LAYER_VISIBILITY_LABELS` source-level assertions to
      their `_CN` counterparts.
    - Updated the working-mode-section position expectation
      (Working Mode is now BEFORE the secondary collapsed
      sections).
    - Updated the `CAD Analyzer Result` title assertion to
      `CAD 检查结果`.
    - 55/55 html_render PASS (full source-level CN guard).

Test evidence (this dispatch):

- Full Ruby suite: **843 / 843 PASS** (was 843 before this
  dispatch; no regressions; the CN guard assertions are
  additive).
- V16 substring: **26 / 26 PASS** (P1-P9, G1-G6, H1-H6,
  T1-T3, I1-I3) — the V1.6 backend behavior is unchanged.
- V15 substring: **149 / 149 PASS** (BLOCK-005 closed,
  duplicate-repair semantics unchanged).
- RBZ smoke substring: **9 / 9 PASS**.
- Node DOM (`tests/test_html_render_dom.js`): **294/294
  PASS** (54 new CN1-CN18 + 240 existing assertions).
- `git diff --check`: clean.

CODEX_TRIGGER: **NO** (per dispatch §8). No material repo-
aware issue was uncovered; the V1.6 backend architecture is
unchanged; the prior frozen PlanarNormalizationAnalyzer /
Proposer / Executor / Tolerance / WorkingModeRunner /
DialogRunner work is intact and re-verified by 26 V16 tests.
The UI change is the smallest frontend productization seam
needed to satisfy the dispatch §0 Owner requirements:
Simplified Chinese localization + materially simpler default
UI + ONE primary CTA hierarchy + collapsed `技术详情` block.
The destructive Apply Safe Normalization action wiring is
unchanged (the visible button label is Simplified Chinese;
the internal `data-action="apply_planar_normalization"`
callback name is preserved verbatim).

V1.6 OWNER REAL-HOST VERIFICATION NOT YET RUN. V1.6 NOT CLOSED.

## V1.6 UI-CN-SIMPLIFICATION-FIX DISPATCH (THIS UPDATE)

Updated: 2026-09-01 (V16-UI-CN-SIMPLIFICATION-FIX-2026-09-01
dispatch EXECUTION COMPLETE on assigned `dev/v1.6`. The
prior V16-UI-CN-SIMPLIFICATION packet is intact; this
dispatch performed ONE bounded frontend UX regression fix
per Owner real-host finding.)

Owner real-host finding (per dispatch §0):

> After the previous workspace is discarded, Working Mode
> shows “处理工作区 — 工作副本已放弃” but the UI exposes only
> “更多操作 -> 重新生成” and does NOT expose “准备处理”. This
> is incorrect. After Discard, the user may select a NEW
> CAD/source selection and must be able to create a fresh
> SourceSnapshot + Derived Workspace from the CURRENT
> selection. Rebuild is not a substitute for Prepare because
> it may rebuild from the previously captured workspace/
> source state.

Concretely this dispatch changed:

  - `extension/su_ai_plugin/html/app.js`:
    - `renderPrimaryAction()` now emits `准备处理` as the
      primary CTA for BOTH `none` AND `discarded` AND `failed`
      workspace states. The `discarded` + `failed` branches
      were missing in the prior packet (only Rebuild was
      available under `更多操作`).
    - The `ready` branch is unchanged: `检查平面偏差` for
      `NOT_COMPUTED`, `应用平面校正` for `READY_TO_NORMALIZE`,
      no destructive button for REVIEW_REQUIRED / NO_CANDIDATE
      / APPLIED / FAILED / INVALID_*.
    - The `building` branch is unchanged: no buttons
      (in-progress).
    - `renderMoreActions()` is unchanged in code; the
      `discarded` + `failed` branches already showed `重新生成`
      as a secondary control. Now `准备处理` is the primary
      CTA on top + `重新生成` is the secondary under `更多操作`.

Action-state matrix (per dispatch §5):

| Workspace state | Primary CTA                | Secondary in `更多操作` |
|-----------------|----------------------------|--------------------------|
| `none`          | `准备处理`                 | (none)                   |
| `discarded`     | `准备处理` (Owner fix)      | `重新生成`               |
| `failed`        | `准备处理` (Owner fix)      | `重新生成`               |
| `ready` + `NOT_COMPUTED` | `检查平面偏差`     | `放弃工作副本` + `重新生成` |
| `ready` + `READY_TO_NORMALIZE` | `应用平面校正` | `放弃工作副本` + `重新生成` |
| `ready` + (REVIEW_REQUIRED / NO_CANDIDATE / APPLIED / FAILED / INVALID_*) | (none) | `放弃工作副本` + `重新生成` |
| `building`      | (none; in-progress)        | (none)                   |

The destructive `应用平面校正` button is rendered ONLY when
`workspaceState === 'ready'` AND `pnState === 'READY_TO_NORMALIZE'`
(per the prior packet's locked contract).

Production files NOT modified by this dispatch:
- All V1.6 backend files (planar_normalization_*.rb,
  tolerance.rb, analysis_config.rb,
  derived_workspace_adapter.rb,
  su_derived_workspace_adapter.rb, working_mode_runner.rb,
  dialog_runner.rb, main.rb). The V1.6 frozen Blueprint +
  the V1.6 backend are unchanged.
- `extension/su_ai_plugin/html/index.html`
- `extension/su_ai_plugin/html/style.css`

Test files modified by this dispatch:
  - `tests/test_html_render_dom.js`:
    - Added V16-FIX assertions for the `discarded` state:
      - Primary CTA is Simplified Chinese `准备处理` (data-
        action="prepare_workspace", enabled, NO disabled attr).
      - `更多操作` block contains `重新生成` as secondary.
      - `放弃工作副本` is NOT rendered (already discarded).
      - ZERO disabled buttons anywhere in the `discarded`
        state (unavailable actions are HIDDEN, not disabled).
      - Clicking `准备处理` calls prepare_workspace EXACTLY
        ONCE; does NOT call rebuild_workspace; does NOT call
        discard_workspace.
      - Clicking `重新生成` (secondary) calls
        rebuild_workspace EXACTLY ONCE; does NOT call
        prepare_workspace.
    - Added V16-FIX assertions for the `failed` state (same
      class of mistake, by symmetry):
      - Primary CTA is Simplified Chinese `准备处理`.
      - `更多操作` block contains `重新生成` as secondary.
      - Clicking `准备处理` calls prepare_workspace EXACTLY
        ONCE; does NOT call rebuild_workspace.

Test evidence (this dispatch):

- Full Ruby suite: **843 / 843 PASS** / 0 fail / 0 error
  (no Ruby-side change was required for this UI fix; the
  Ruby regression suite covers the existing V1.6 backend
  contract, which is unchanged).
- V16 substring: **26 / 26 PASS** (P1-P9, G1-G6, H1-H6,
  T1-T3, I1-I3) — V1.6 backend behavior is unchanged.
- V15 substring: **149 / 149 PASS** (BLOCK-005 closed).
- Node DOM (`tests/test_html_render_dom.js`):
 **307 / 307 PASS** (294 existing + 13 new V16-FIX).
- RBZ smoke substring: **9 / 9 PASS**.
- `git diff --check`: clean.

CODEX_TRIGGER: **NO** (per dispatch §8). No new architecture
was added; no V1.6 normalization algorithm was changed; no
Source-of-Truth / Undo / transaction / provenance / observer
was touched. The destructive `apply_planar_normalization`
callback name is preserved verbatim — only the action-state
matrix in the simplified renderer was corrected (no backend
semantics, no Source-of-Truth, no Undo/reconciliation, no
transaction, no provenance).

V1.6 OWNER REAL-HOST VERIFICATION NOT YET RUN.
V1.6 NOT CLOSED.

## V1.6 CLOSE-AUTODISCARD DISPATCH (THIS UPDATE)

Updated: 2026-09-01 (V16-CLOSE-AUTODISCARD-2026-09-01
dispatch EXECUTION COMPLETE on assigned `dev/v1.6`. The
prior V16-UI-CN-SIMPLIFICATION + V16-UI-CN-SIMPLIFICATION-FIX
packets are intact; this dispatch performed ONE bounded
Owner UX fix BEFORE closure.)

Owner real-host finding (per dispatch §1):

> Closing the SU-AI-Plugin dialog currently leaves the
> transient Derived Workspace alive. When the plugin is
> opened again, the user must manually Discard the previous
> workspace before preparing a new selection. This creates
> unnecessary workflow friction.

Concretely this dispatch changed:

  - `extension/su_ai_plugin/dialog_runner.rb`:
    - `on_close()` now runs the EXISTING
      `WorkingModeRunner.discard` path BEFORE releasing the
      controller / Loader cache / module-level controller
      handle, IF and only IF the current workspace state is
      in `{building, ready, failed}`. For `none` and
      `discarded` the close is a no-op.
    - The close-time cleanup is wrapped in a
      `begin / rescue StandardError` block that uses the
      existing `_safe_log` to log the error and SWALLOWS the
      exception, so a transient close-time error can NEVER
      block SketchUp shutdown / model close / the
      HtmlDialog close callback (per dispatch §4 fail-safe
      requirement).
    - The existing discard contract is reused verbatim. NO
      second cleanup implementation is introduced.
    - The destructive `apply_planar_normalization` callback
      name is preserved verbatim. Source-of-Truth / Undo /
      transaction / provenance / observer architecture are
      all UNCHANGED.

Close-time behavior matrix (per dispatch §1-§4):

| State at close   | on_close action                                                                 |
|------------------|----------------------------------------------------------------------------------|
| `none`           | no-op (no current workspace)                                                     |
| `discarded`      | no-op (already discarded)                                                        |
| `building`       | `WorkingModeRunner.discard` (cleanup transient)                                  |
| `ready`          | `WorkingModeRunner.discard` (the primary case — clear derived + V1.5 dup + V1.6 PN) |
| `failed`         | `WorkingModeRunner.discard` (cleanup partial state)                             |

All five cases must NOT raise. Source CAD is NEVER touched
by the close path; only the derived workspace + the V1.5
duplicate_repair summary + the V1.6 planar_normalization
proposal/audit (carried by `WorkingModeRunner`) are cleared,
which is the existing discard contract.

Production files NOT modified by this dispatch (frozen
Blueprint + V1.6 backend + the Simplified Chinese UI surface
are all untouched):
- All V1.6 backend files (planar_normalization_*.rb,
  tolerance.rb, analysis_config.rb,
  derived_workspace_adapter.rb,
  su_derived_workspace_adapter.rb, working_mode_runner.rb,
  main.rb).
- `extension/su_ai_plugin/html/app.js` (the Simplified
  Chinese UI surface; the close-time auto-discard is a
  Ruby-side change in `dialog_runner.rb`).
- `extension/su_ai_plugin/html/index.html`
- `extension/su_ai_plugin/html/style.css`

Test files modified by this dispatch (1):
  - `tests/test_dialog_runner.rb`: added a new
    `dr_realistic_result` helper (AnalysisResult with one
    source edge so the production prepare() path reaches
    state='ready' instead of 'failed' for the empty-source
    path) and 7 new V16-CLOSE-AUTODISCARD assertions:
    - V16-CLOSE-AUTODISCARD: close with ready workspace
      auto-discards (the primary case).
    - V16-CLOSE-AUTODISCARD: close with no workspace is a
      safe no-op.
    - V16-CLOSE-AUTODISCARD: close with already-discarded
      workspace is a no-op.
    - V16-CLOSE-AUTODISCARD: close preserves source
      fingerprint / source geometry (Source CAD invariant).
    - V16-CLOSE-AUTODISCARD: close auto-discard clears V1.6
      planar_normalization proposal / audit (existing
      discard contract requirement).
    - V16-CLOSE-AUTODISCARD: reopen after close exposes a
      clean `准备处理` path (state='discarded' after close).
    - V16-CLOSE-AUTODISCARD: close callback is fail-safe on
      transient close-time error (monkey-patch discard to
      raise; on_close MUST still release Loader cache +
      current_controller handle).

Test evidence (this dispatch):

- Full Ruby suite: **850 / 850 PASS** / 0 fail / 0 error
  (was 843 before this dispatch; +7 = the new
  V16-CLOSE-AUTODISCARD assertions).
- V16 substring: **26 / 26 PASS** (V1.6 backend behavior
  unchanged).
- V15 substring: **149 / 149 PASS** (BLOCK-005 closed,
  duplicate-repair semantics unchanged).
- dialog_runner substring: **29 / 29 PASS** (was 22 before
  this dispatch; +7 = the new V16-CLOSE-AUTODISCARD
  assertions).
- Node DOM (`tests/test_html_render_dom.js`): **307/307
  PASS** (the JS surface is unchanged; 240 existing + 54
  new CN1-CN18 + 13 V16-FIX = 307 all green).
- RBZ smoke substring: **9 / 9 PASS**.
- `git diff --check`: clean.

CODEX_TRIGGER: **NO** (per dispatch §9). No new architecture;
no Source-of-Truth / Undo / transaction / provenance /
observer change. The fix reuses the EXISTING discard contract
verbatim. The destructive `apply_planar_normalization`
callback name is preserved verbatim. The closed-dialog
auto-discard is fail-safe by construction (rescue StandardError
at the boundary + `_safe_log` for diagnostic logging).

V1.6 OWNER REAL-HOST VERIFICATION OF THE CLOSE-AUTODISCARD
NOT YET RUN.
V1.6 NOT CLOSED.

## V1.6 PI-IMPLEMENTATION DISPATCH

Updated: 2026-08-31 (V16-PLANAR-NORMALIZATION-IMPLEMENTATION-2026-08-31
dispatch EXECUTION COMPLETE on assigned `dev/v1.6`. The frozen V1.6
Stage Technical Blueprint
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`
is fully implemented: deterministic PlanarNormalizationAnalyzer +
host-aware PlanarNormalizationProposer + PlanarNormalizationExecutor +
Tolerance.planar_z_snap + WorkingModeRunner compute/apply +
dialog callbacks + Adapter edge_curve / edge_faces_count /
edge_endpoints / transform_vertices_by_vectors / vertex_position
+ 25 V1.6 regression tests. V1.6 OWNER REAL-HOST VERIFICATION
NOT YET RUN. V1.6 NOT CLOSED.)

Implementation map (Blueprint requirement → production symbol →
test evidence):

| Blueprint | Symbol / file | Test |
|-----------|---------------|------|
| §4.1 `planar_z_snap` tolerance | `Tolerance#planar_z_snap` | T1, T2 |
| §4.2 schema/version/equality | `Tolerance.to_h`, `ExecutionConfigSnapshot` | T3 |
| §6.1 eligible vertices | `PlanarNormalizationProposer#propose` | G1, G5 |
| §6.1 unsafe scope | `adapter.edge_curve`, `adapter.edge_faces_count` | G3, G4 |
| §6.2 sliding window | `PlanarNormalizationAnalyzer.analyze` | P2, P3, P4 |
| §6.2 strict majority | `PlanarNormalizationAnalyzer.analyze` | P5 |
| §6.2 tied windows | `PlanarNormalizationAnalyzer.analyze` | P6 |
| §6.3 inliers / outliers | `PlanarNormalizationAnalyzer.analyze` | P4, G5 |
| §6.4 shared-vertex safety | `PlanarNormalizationProposer#propose` | G2 |
| §7 preview states | `planar_normalization` snapshot field | I1, I2 |
| §8.1 preflight | `PlanarNormalizationExecutor.apply` | H1 |
| §8.2 host mutation | `adapter.transform_vertices_by_vectors` | H2 |
| §8.3 commit / failure | `PlanarNormalizationExecutor.apply` | H3, H4 |
| §9 post-validation | `PlanarNormalizationExecutor.apply` | H2 |
| §10 provenance | `_attach_planar_normalization_to_snapshot` | I2 |
| §11 lean UX | dialog_runner.rb callbacks | (UI harness) |
| §17 implementation order | (this dispatch) | n/a |

Source immutability: G1+G6 + the source fingerprint contract
prove source CAD is unchanged before/after Apply. The proposer
+ executor operate exclusively on derived workspace geometry.

Working tree (THIS UPDATE):
- Modified production files: 7 (tolerance.rb, analysis_config.rb,
  derived_workspace_adapter.rb, planar_normalization_analyzer.rb,
  planar_normalization_proposer.rb, planar_normalization_executor.rb,
  su_derived_workspace_adapter.rb, working_mode_runner.rb,
  dialog_runner.rb, main.rb).
- Added production files: 3
  (planar_normalization_analyzer.rb,
  planar_normalization_proposer.rb,
  planar_normalization_executor.rb).
- Added test file: 1 (test_v16_planar_normalization.rb — 25 tests).
- Tracked AIPM authority: 2 (V1.5 closure record + V1.6
  Stage Technical Blueprint).
- RBZ rebuilt: yes (size 733504, entries 62, SHA-256
  `c1e4b641b1ac8f509c7bfede52770bbd6d8a2f771f3003f4f5e572341dc72b68`).
- Local checkpoints on `dev/v1.6`: 5
  (V1.6 doc-stamp + 3 implementation + final RBZ state — see
  `git log --oneline -10` for the exact SHAs).
- Push: NOT PUSHED per dispatch §14 (bounded retry against
  `origin/dev/v1.6` may be attempted from a reachable
  environment; same RBZ is available on the RBZ file system
  path for the Owner SU2020 verification gate regardless).
- `git diff --check`: clean.

V1.5 regression coverage preserved: V1.0–V1.5 full suite
(817 pre-existing tests + 25 V1.6 tests = 842 total) all PASS.
Full Ruby suite: 842 pass / 0 fail / 0 error. RBZ smoke:
9/9 PASS. Node DOM (test_html_render_dom.js): PASS.

Owner / AIPM SU2020 real-host verification is NOT YET RUN
per dispatch §15 STOP condition.

---

---

## Historical V1.5 closure process (clearly historical)

The `Updated:` blocks below record the historical V1.5 closure process (V15-LEGACY-COMPAT packets, Round-5 corrective packets, BLOCK-005 documentation sync, etc.). They remain for durable audit evidence only. They are NOT active V1.5 work — V1.5 is CLOSED above.

---

Updated: 2026-08-31 (V15-LEGACY-COMPAT-FINAL-EVIDENCE-FIX
dispatch EXECUTION COMPLETE per dispatch
`V15-LEGACY-COMPAT-FINAL-EVIDENCE-FIX-2026-08-31`. AIPM
authoritatively reviewed the real prior corrective
packet output and identified three remaining factual
defects in CURRENT_STATE / CURRENT_PI_REPORT. This
dispatch executed the bounded final-evidence corrective
work:

FINDING 1 (accepted): the prior corrective packet's
report and state used placeholder SHA markers
(`<SHA_STAMP>`, "recorded elsewhere", etc.) for the
exact final commit SHA. That is not acceptable
evidence. This packet records the exact full SHA
directly via the standard "implementation + doc-
stamp" pattern; the implementation commit is recorded
explicitly as `ad6ca70e2213034d54a3cb14a9bad210b19767fb`
(verifiable via `git rev-parse HEAD~1` after both
commits of this packet land), and the final HEAD after
the doc-stamp commit is the `git rev-parse HEAD` result
at task completion (the reader verifies directly via
`git rev-parse HEAD`; the SHA is also recorded in the
doc-stamp commit's commit-message body for `git log -1`
readers; embedding the SHA inside the report file
itself is intentionally avoided because a file inside
a commit cannot contain its own commit's hash without
a fixed-point construction that git does not natively
support). Both are documented
verbatim.

FINDING 2 (accepted): the prior corrective packet
classified `Model#find_entity_by_id`,
`Model#active_path` (getter), `Entity#persistent_id`,
`Model#instance_path_from_pid_path`, and
`UI::HtmlDialog` as "post-SU2017 but capability-gated"
APIs, but official SU API version history shows these
are baseline-or-earlier for an SU2017+ project target:
`Model#find_entity_by_id` SU2015; `Model#active_path`
(getter) SU7.0; `Entity#persistent_id` SU2017;
`Model#instance_path_from_pid_path` SU2017;
`UI::HtmlDialog` SU2017. The production code does NOT
use the `Model#active_path=` setter (a later API; if
it were used, it would be classified separately and
isn't here). This packet reclassifies these into
category A (baseline-or-earlier for an SU2017+ target),
keeps the defensive capability gates as forward-compat
belt-and-braces, and reports category B as empty
after the corrected inventory.

FINDING 3 (accepted): the prior corrective packet said
beginless range `(..a)` was introduced in Ruby 2.6.
Official Ruby release history says endless range
`(a..)` was introduced in Ruby 2.6 and beginless range
`(..a)` was introduced in Ruby 2.7. This packet
corrects the beginless-range version metadata in the
test file rule (`ruby_min_unsupported` and
`ruby_min_required` both `2.7.0`), the per-rule
comment, and any related state/report references. The
guard itself is preserved: beginless range remains
incompatible with the Ruby 2.2 baseline.

Production byte-diff vs prior corrective commit
`36eb6da97c1040d9772656467208b0105cd16fa3`: ZERO
production byte change. The production file
(`core/source_snapshot.rb`) is unchanged in this
packet. Test file changes are limited to one rule's
`ruby_min_*` field and its comment. Governance
documentation is updated to remove placeholders,
correct API classification, and record the corrected
beginless-range version.

Stable local commits are created on the assigned
`dev/v1.5`. NOT pushed per dispatch directive. Final
HEAD after this packet is the doc-stamp commit; its
exact SHA is recorded in the `Review/CURRENT_PI_REPORT.md`
report and is verifiable via `git rev-parse HEAD`.

No real SU2017 / SU2020 compatibility PASS is claimed.

Updated: 2026-08-31 (V15-LEGACY-COMPAT-CORRECTION dispatch
EXECUTION COMPLETE per dispatch
`V15-LEGACY-COMPAT-CORRECTION-2026-08-31`. AIPM authoritatively
reviewed the real prior hardening packet output and identified
four findings (A through D). This dispatch executed the
bounded corrective work:

FINDING A (accepted): the prior claim that integer literal
underscore `1_000_000` requires Ruby 2.5+ was FACTUALLY
INCORRECT. Ruby 2.2 official syntax documentation explicitly
supports underscores in numeric literals (e.g. `1_234`).
Therefore the prior `1_000_000` -> `1000000` replacement
was unnecessary for the stated compatibility reason, the
production code is restored to the readable `1_000_000`
form, and the false version-history claim is removed. No
production behavior change.

FINDING B (accepted): the prior "vendored-Ruby-2.7.8 parse
= strict superset of older Ruby rejections" claim was
incorrect; Ruby 2.7.8 ACCEPTS syntax that Ruby 2.6/2.5/2.4
REJECT. Both the vendored parse and the Ripper.sexp AST
parse are now documented honestly as "current-source
syntax/load smoke" and NOT as proof of Ruby 2.5/2.2
parseability.

FINDING C (accepted): the prior "Modern-only APIs found:
0" classification was overstated. The audit now categorizes
host API usage truthfully into baseline-SU2017 APIs +
post-SU2017-but-capability-gated APIs + uncertain/version-
evidence-conflict items + unsafe-unguarded post-baseline
APIs (the last being empty). The post-SU2017-but-gated
APIs are not collapsed with baseline-APIs into a single
"zero modern-only" number.

FINDING D (accepted): the prior report reintroduced stale
historical-gate prerequisites stating the RBZ could not be
used until the Owner verification file is republished AND
(if AIPM chooses) the next Codex narrow xHigh recheck passes.
These are not prerequisites for the BLOCK-005 SU2020 probe
per the current authoritative project state. The obsolete
prerequisite wording is removed from CURRENT_STATE and
CURRENT_PI_REPORT.

Concrete changes:
- `extension/su_ai_plugin/core/source_snapshot.rb` is restored
  to its pre-hardening state (the readability-improving
  `1_000_000` is back). The 4-line comment block that
  incorrectly stated integer-literal underscores required
  Ruby 2.5+ is removed. Syntax/behavior unchanged.
- `tests/test_v15_legacy_compat_guard.rb` is corrected:
  integer_literal_underscore rule removed from
  KNOWN_MODERN_SYNTAX (per FINDING A — Ruby 2.2 supports
  this officially); per-file guard pinning the false
  integer-underscore change on `core/source_snapshot.rb`
  removed; the four actually-real guard classes kept
  (endless_range, beginless_range, numbered_block_params,
  safe_navigation); test names re-framed to say what
  they actually check ("current-source syntax/load
  smoke", "current-source AST smoke"); per-tree endless-
  range guard retained (CONFIRMED-FIX-COMPAT-RANGE)
  per the dispatch directive "Do not weaken the
  confirmed endless-range guard." 4/4 LEGACY-COMPAT
  tests pass; full V15 149/149; full Ruby 817/817.
  (The integer-underscore-RB-of-zero-findings test
  count drop from 818 to 817 is exactly explained by
  the 5->4 LEGACY-COMPAT count: the 5th test was the
  per-file guard for the false-positive class and was
  correctly removed.)
- RBZ rebuilt from current source via the existing
  `scripts/build_rbz.rb`; packaged `core/source_snapshot.rb`
  is byte-identical to in-tree source; size 642,038
  bytes (was 642,296; delta is the removed 4-line
  comment block); entries 59 (unchanged); SHA-256
  `0E7dEB9CD933FE97CDA37F45E93B07AC65C242AB8DAE48B6BFFEE0D1E27B3E9F`.
  (Owner SU2020 BLOCK-005 Real-Host Feasibility Probe
  remains the canonical next Gate after AIPM acceptance
  of this corrective packet.)
- BLOCK-005: OPEN (not closed by this correction).
- BLOCK-005 technical direction: FROZEN (unchanged).
- Codex: NOT REQUIRED for the current compatibility/
  probe path (this dispatch is NOT a Codex task).
- V1.6: NOT STARTED.
- Canonical next Gate after AIPM acceptance of this
  correction: **SketchUp 2020 BLOCK-005 Real-Host
  Feasibility Probe** (Owner/AIPM-owned).
- Local checkpoint commit created on the assigned
  `dev/v1.5`; NOT pushed per dispatch §9.
- No real SU2017/SU2020 compatibility PASS is claimed;
  this dispatch ONLY documents the corrected audit
  results and explicitly notes its own evidence
  boundary (only Ruby 2.7.8 is vendored; no Ruby
  2.5.5 / Ruby 2.2.4 real-host verifier is available
  in this project).

Updated: 2026-08-31 (V15-LEGACY-COMPAT-HARDENING dispatch
EXECUTION COMPLETE per dispatch
`V15-LEGACY-COMPAT-HARDENING-2026-08-31`. The dispatched
audit was performed on the COMPLETE production Ruby load
tree used by the installed RBZ (root loader `extension/
su_ai_plugin.rb` + `extension/su_ai_plugin/` support
folder + `scripts/build_rbz.rb`). The audit found ONE
production-reachable Ruby 2.5+-only parse-time hazard
(`1_000_000` integer literal underscore syntax in
`core/source_snapshot.rb`, inside the `rescue LoadError`
SecureRandom fallback at line 447) which would have
rejected SU2017 (Ruby 2.2.4) and SU2018 (Ruby 2.4.4) at
parse time even though the rescue branch is dead at runtime
on any host that ships stdlib `securerandom`. The fix is
semantically identical (`1_000_000` -> `1000000`) and
preserves all frozen product/technical behavior per
dispatch §9. No production-touchable change was made
to: duplicate detection, tolerance semantics,
complete-graph-or-skip, repair eligibility, source/derived
ownership, destructive handle requirements, source-CAD
immutability, repair transaction semantics, audit/
provenance semantics, UI workflow, user-visible repair
authority, or BLOCK-005 recovery policy. New regression
guard `tests/test_v15_legacy_compat_guard.rb` added:
5/5 PASS (vendored-Ruby parse on every production file
via `RubyVM::InstructionSequence.compile`; Ripper.sexp
AST parse on every production file; targeted-regex scan
for integer literal underscores / endless ranges /
beginless ranges / numbered block parameters / safe
navigation that the vendored Ruby silently accepts but
the SU minimum baseline rejects; plus two FIX-specific
guards pinning the integer-underscore and endless-range
findings the dispatch set out to harden). The guard
catches intentional reintroduction (verified during
this dispatch by temporarily reverting the fix and
re-running the regression: 3/5 PASS, 2 FAIL with
explicit file:line + id); restoring the fix returns
5/5 PASS. RBZ rebuilt from current source via the
existing `scripts/build_rbz.rb`. RBZ contents
verified: packaged `core/source_snapshot.rb` is identical
to in-tree source (RBZ contains the post-fix code;
no stale pre-fix copy). RBZ install/load smoke: 9/9 PASS.
Full Ruby suite: **818/818 PASS** (was 813 prior to
adding +5 LEGACY-COMPAT tests; no other regressions).
V15 substring: 149/149 PASS. `git diff --check` clean.
Local checkpoint commit created on the assigned
`dev/v1.5`. NOT pushed per dispatch §16. BLOCK-005
remains OPEN; BLOCK-005 technical direction remains
FROZEN; Owner SU2020 real-host probe remains the next
Gate. V1.6 remains NOT STARTED.)

Updated: 2026-08-31 (BLOCK-005 documentation-only sync
per AIPM directive. This is NOT a new implementation round
and does NOT assign BLOCK-005 work to Pi. BLOCK-005
dedicated AIPM technical research is now COMPLETE;
technical direction is FROZEN on
`validate-on-next-interaction -> detect host mismatch ->
fail closed / invalidate -> host-authoritative
prepare/rebuild` with the SketchUp Model as geometry
Source of Truth. No global ModelObserver / EntitiesObserver
architecture is added in V1.5. Entity-level observer event
replay is rejected as a correctness mechanism. `persistent_id`
is not the correctness Source of Truth. Old Ruby Entity
handles must never be trusted after host-state divergence.
ModelObserver invalidation is only an approved fallback if
the SU2020 real-host probe proves the existing validation
seam insufficient. The canonical next gate is the **SketchUp
2020 BLOCK-005 Real-Host Feasibility Probe**, owned by
Owner/AIPM. Pi is not assigned the probe and remains
STOPPED. No production code was modified by this update;
no RBZ was rebuilt; no tests were rerun; no push was
attempted.)
Updated: 2026-08-28 (CRASH-RECOVERY RESUME of the same
dispatch `SUAI-V15-R5-AIPM-SOURCE-REVIEW-FIX-20260828-01`;
AIPM directly reviewed the real GitHub implementation
commit `889548590ead211162be704af3b22d7299583357`
(prior NARROW CONTINUATION) and found
`FIX REQUIRED -- do not pre-filter nil removals in
single-action apply`).
Project: `D:\Projects\SU-AI-Plugin`
Updated: 2026-08-28 (NARROW CONTINUATION of the same dispatch
`SUAI-V15-R5-AIPM-SOURCE-REVIEW-FIX-20260828-01`; AIPM has
directly reviewed the real GitHub implementation commit
`874149dc7488ff8c844e16fb6e0e6013df9abfa6` and found
`FIX REQUIRED -- narrow implementation correction`).

Current stage: **V1.5 — CLOSED (THIS UPDATE)**. This CLOSURE-ONLY sync dispatch (`V15-CLOSURE-SYNC-2026-08-31`) records the Final Product Owner / AIPM V1.5 closure decision. No production / runtime / test / RBZ / V1.6 implementation changes were made by this dispatch. See the `V1.5 CLOSURE (THIS UPDATE)` block at the top of this file for the authoritative closure facts and accepted V1.5 RBZ identity.
Current status: **V1.5 CLOSED. BLOCK-005 CLOSED. V1.6 NOT STARTED.** Accepted V1.5 RBZ identity verified at `dist\SU-AI-Plugin.rbz` (size 642,037 bytes; entries 59; SHA-256 `61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292`). Owner SketchUp 2020 V1.5 verification: PASS (per `Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`). BLOCK-005 technical direction remains frozen: `validate-on-next-interaction → detect host mismatch → fail closed / invalidate → host-authoritative discard + prepare/rebuild` (no global Observer architecture). One local closure checkpoint commit created on the assigned `dev/v1.5`; pushed to `origin/dev/v1.5` if the current V3.4 submission policy permits (and if remote is not blocked / diverged). Pi STOPPED awaiting AIPM V1.6 dispatch.
Next stage: **V1.6 — NOT STARTED (awaits new ACTIVE `CURRENT_PI_DISPATCH` referencing the frozen V1.6 Stage Technical Blueprint `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`)**

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
- BLOCK-005 dedicated technical research is COMPLETE on the AIPM side; technical direction is FROZEN on `validate-on-next-interaction -> detect host mismatch -> fail closed / invalidate -> host-authoritative prepare/rebuild`; the canonical next gate for BLOCK-005 is the SketchUp 2020 BLOCK-005 Real-Host Feasibility Probe (Owner/AIPM-owned; Pi is not assigned).

---

## 1. ACTIVE STATUS

### Completed
- V1.0–V1.4 remain closed on their previously verified scope.
- V1.5 Round-3 implementation/fix packet is complete (history).
- V1.5 Round-4 BLOCK fix packet is complete (history).
- V1.5 Round-5 BLOCK corrective implementation packet is complete (history).
- V1.5 Round-5 BLOCK FIX continuation packet is complete (history).
- V1.5 Round-5 AIPM Source Review corrective packet is complete (history, implementation commit `874149d`).
- V1.5 Round-5 AIPM Source Review NARROW CONTINUATION is complete (history, implementation commit `8895485`):
  implemented the bounded narrow AIPM Source Review fixes
  (FIX-SR-01 single-action executor must fail closed,
  FIX-SR-02 expected post state must prove handle liveness,
  FIX-SR-03 truthful invalid-tolerance audit reason) within the
  same frozen
  `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
  design.
- V1.5 Round-5 AIPM Source Review NARROW CONTINUATION
  CRASH-RECOVERY RESUME — FIX-SR-04 is complete (history,
  implementation commit `3043219`, documentation commits
  `aabfa7e` + `1761adb`):
  removed the `present = to_remove.select { !nil? }`
  pre-filter in `DuplicateRepairExecutor.apply`; the
  COMPLETE intended `to_remove` set is passed into
  `apply_atomic` so the existing strict-liveness
  contract (FIX-SR-01) rejects nil / non-live removal
  members and a MIXED set fails closed BEFORE
  `begin_operation`. The historical `already_applied`
  all-nil skip path is preserved. Same frozen Guidance,
  same dispatch ID. 2 new focused regressions added.
  Pushed to `origin/dev/v1.5` (final remote HEAD =
  `1761adb50bc3efebb0f674ce9728cebbe6228986`).
- V1.5 BLOCK-005 documentation-only sync is complete (history):
  per AIPM directive, the canonical project state has been
  synchronized to record that BLOCK-005 dedicated AIPM
  technical research is COMPLETE, the technical direction is
  FROZEN on the existing `validate-on-next-interaction`
  architecture, the SketchUp Model remains the geometry
  Source of Truth, no global ModelObserver / EntitiesObserver
  architecture is added in V1.5, entity-level observer event
  replay is rejected as a correctness mechanism,
  `persistent_id` is not the correctness Source of Truth, and
  old Ruby Entity handles must never be trusted after
  host-state divergence. The canonical next gate is the
  SketchUp 2020 BLOCK-005 Real-Host Feasibility Probe
  (Owner/AIPM-owned). No production code, no tests, no RBZ,
  no push were touched by this update.
- V1.5 V15-LEGACY-COMPAT-HARDENING dispatch EXECUTION COMPLETE (history):
  per AIPM dispatch `V15-LEGACY-COMPAT-HARDENING-2026-08-31`,
  the COMPLETE production Ruby load tree was audited for
  Ruby 2.2+ parse-time compatibility and Ruby core/stdlib
  API compatibility. The audit found ONE supposed
  parse-time hazard (integer literal underscore). NOTE: this
  result was authoritatively RETRACTED in the corrective
  packet below (FINDING A: integer literal underscore is
  Ruby 2.2+ officially supported; the prior hardening
  packet's `1_000_000` -> `1000000` swap was unnecessary
  for the stated reason). The confirmed endless-range
  finding is the only CONFIRMED defect from this audit;
  the corresponding fixes in `core/duplicate_repair_proposer.rb`
  remain in place (implementation commit `f61c352`, prior
  chat session). RBZ rebuilt via the existing
  `scripts/build_rbz.rb`; full Ruby suite **818/818 PASS**.
  NOT pushed. BLOCK-005 untouched architecturally.
- V1.5 V15-LEGACY-COMPAT-CORRECTION dispatch EXECUTION COMPLETE (THIS UPDATE):
  per AIPM dispatch `V15-LEGACY-COMPAT-CORRECTION-2026-08-31`,
  the prior hardening packet's output was authoritatively
  reviewed and four findings (A-D) were accepted and
  corrected:

  - **FINDING A** (accepted): the prior claim that
    integer literal underscore `1_000_000` requires
    Ruby 2.5+ was FACTUALLY WRONG (Ruby 2.2 supports
    `1_234` per official docs). The `1_000_000` ->
    `1000000` swap in `extension/su_ai_plugin/core/source_snapshot.rb:447`
    is reverted; the form is restored to `1_000_000`,
    the false comment is removed. No behavior change.
  - **FINDING B** (accepted): the prior
    "vendored-Ruby-2.7.8 = strict superset of older
    parser rejections" claim was logically inverted
    (newer parser ACCEPTS more). Both vendored-parse
    and Ripper.sexp AST parse are now documented as
    current-source syntax/load smoke, NOT as proof of
    old-Ruby parseability.
  - **FINDING C** (accepted): the prior
    "Modern-only APIs found: 0" classification was
    overstated. The API inventory is now categorised
    truthfully into SU2017-baseline + post-SU2017-
    but-capability-gated + uncertain + unsafe-unguarded
    (the last being empty). The audit's classification
    is explicitly NOT collapsed into "0 modern-only".
  - **FINDING D** (accepted): the prior report
    reintroduced stale prerequisite gates stating the
    RBZ was unusable until Owner verification republish
    AND Codex narrow recheck. Those prerequisites are
    NOT current. The current authoritative next Gate
    is **SketchUp 2020 BLOCK-005 Real-Host Feasibility
    Probe** (Owner/AIPM-owned), not gated on Owner
    republish or Codex recheck.

  Concrete changes:
  - `extension/su_ai_plugin/core/source_snapshot.rb`
    restored to pre-hardening state (the readable
    `1_000_000` is back; the 4-line false-claim comment
    is removed).
  - `tests/test_v15_legacy_compat_guard.rb` corrected:
    `integer_literal_underscore` rule removed from
    `KNOWN_MODERN_SYNTAX`; per-file guard pinning the
    false integer-underscore change on
    `core/source_snapshot.rb` removed; the four
    actually-real guard classes kept
    (`endless_range`, `beginless_range`,
    `numbered_block_params`, `safe_navigation`); the
    CONFIRMED endless-range per-tree guard retained
    (per the corrective dispatch directive "Do not
    weaken the confirmed endless-range guard"); test
    names re-framed to say what they actually check.
    5 tests -> 4 tests.
  - RBZ rebuilt from current source via the existing
    `scripts/build_rbz.rb`; packaged
    `core/source_snapshot.rb` is byte-identical to
    in-tree source; size 642,037 bytes (was 642,296;
    delta is the removed false-claim comment block);
    entries 59 (unchanged); SHA-256
    `61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292`
    (same as the prior f61c352 SHA — the artifact is
    byte-identical to the pre-hardening state because
    the corrective packet reverted the production
    change back to its starting point).
  - Full Ruby suite: **817/817 PASS** (was 818 prior
    to removing the +1 false-positive LEGACY-COMPAT
    integer-underscore per-file guard test; no other
    regressions across the existing 817 tests).
  - V15 substring: 149/149 PASS. LEGACY-COMPAT
    substring: 4/4 PASS. RBZ install/load smoke: 9/9
    PASS. `git diff --check`: clean.
  - Local checkpoint commit created on the assigned
    `dev/v1.5`. NOT pushed per dispatch §9.

  BLOCK-005: OPEN (NOT closed by this correction).
  BLOCK-005 technical direction: FROZEN. Codex: NOT
  REQUIRED for the current compatibility/probe path.
  V1.6: NOT STARTED. Canonical next Gate after AIPM
  acceptance of this correction: **SketchUp 2020
  BLOCK-005 Real-Host Feasibility Probe**
  (Owner/AIPM-owned). No real SU2017/SU2020
  compatibility PASS is claimed; evidence bounded by
  the only vendored Ruby available (2.7.8).

### In progress
- Nothing is currently being implemented by Pi. The CLOSURE-ONLY sync
  dispatch (`V15-CLOSURE-SYNC-2026-08-31`) is complete; Pi is STOPPED
  awaiting AIPM V1.6 dispatch.

### Waiting
- **AIPM V1.6 dispatch.** The canonical next AIPM action is to
  activate a new `CURRENT_PI_DISPATCH` that references the frozen
  V1.6 Stage Technical Blueprint
  (`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_6_PLANAR_NORMALIZATION_2026-08-31.md`).
  V1.6 is the next product stage after V1.5 closure.

### Not started
- V1.6 Planar Normalization / Z Policy (Stage Technical Blueprint
  is frozen in `Prompt/`; implementation awaits a separate ACTIVE
  `CURRENT_PI_DISPATCH` referencing it).
- V1.7 Endpoint / Gap Repair + Canonical Topology.
- V1.8 Polyline / Closed Loop / Region Reconstruction.
- V1.9 Prepared CAD Workflow + V2 Handoff.
- V2 / MCP — out of scope per `PROJECT_MASTER_PLAN_V1X.md`.

The pre-V1.6 prerequisites that were listed in earlier revisions of
this file (BLOCK-005 dedicated technical research pending; SU2020
BLOCK-005 Real-Host Feasibility Probe pending; V1.5 BLOCK set not
formally closed; Owner verification republish required) are now
RETIRED — V1.5 is CLOSED, BLOCK-005 is CLOSED, the BLOCK-005
technical research was completed on the AIPM side and its direction
frozen, and the Owner SU2020 verification was reported PASS per the
Final Product Owner confirmation recorded by AIPM in
`Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`.

---

## 2. CURRENT GIT / BUILD STATE

Current branch: `dev/v1.5`

V15-LEGACY-COMPAT-CORRECTION local checkpoint (THIS UPDATE):

- Starting local HEAD (pre-task):
  `1db28d3181fa0f90151da2d9ab53ffafaca832a3`
  (the V15-LEGACY-COMPAT-HARDENING commit from the
  prior chat session; 1 commit ahead of
  `origin/dev/v1.5`)
- Corrected production state (THIS UPDATE):
  `extension/su_ai_plugin/core/source_snapshot.rb`
  restored to pre-hardening byte state
  (`1_000_000` form, no false-version comment).
  This is a behavior-free byte-equivalent inversion of
  the prior hardening packet's production patch.
- Corrected test file (THIS UPDATE):
  `tests/test_v15_legacy_compat_guard.rb` rule list
  and per-file guard updated; 5 -> 4 tests.
- Updated governance / report files:
  - `CURRENT_STATE.md` (THIS UPDATE)
  - `Review/CURRENT_PI_REPORT.md` (THIS UPDATE)
- Implementation commit (THIS UPDATE):
  awaiting final SHA stamp at end of this task
  (1 corrective commit covering the
  `source_snapshot.rb` byte-restoration +
  `tests/test_v15_legacy_compat_guard.rb` rule-list
  fix + governance updates).
- `origin/dev/v1.5` HEAD (unchanged by THIS UPDATE):
  `1761adb50bc3efebb0f674ce9728cebbe6228986`
- Local-ahead count after THIS UPDATE: 4 commits
  (the prior `f61c352` endless-range fix + `ae256d9`
  BLOCK-005 doc sync + `1db28d3` legacy hardening +
  THIS UPDATE).
- NOT PUSHED per dispatch §9.
- The dispatch §9 explicitly forbids pushing this
  corrective packet; the complete-task submission will
  be pushed after AIPM direct source review of this
  corrective evidence, per the formal `dev/vX.Y`
  submit contract in `PROJECT_HANDOFF.md` §14.

Working tree (THIS UPDATE, post-task; pre-commit):
- Modified production files (1):
  - `extension/su_ai_plugin/core/source_snapshot.rb`
    (byte-identical to the pre-hardening state at
    `1db28d3^`; the false-claim `1_000_000` ->
    `1000000` swap and accompanying 4-line comment
    are reverted).
- Modified test files (1):
  - `tests/test_v15_legacy_compat_guard.rb`
    (KNOWN_MODERN_SYNTAX `integer_literal_underscore`
    rule removed per FINDING A; the per-file guard
    pinning the false integer-underscore change on
    `core/source_snapshot.rb` removed; test names
    re-framed to say what they actually check;
    `KNOWN_MODERN_SYNTAX` now lists 4 classes; the
    CONFIRMED-FIX-COMPAT-RANGE per-tree endless-range
    guard retained per the corrective dispatch
    directive; total: 5 -> 4 tests).
- Updated governance / report files (this commit):
  - `CURRENT_STATE.md` (THIS UPDATE)
  - `Review/CURRENT_PI_REPORT.md` (THIS UPDATE)
- Untracked AIPM Review evidence files preserved (7):
  - `Review/AIPM_V1_5_R5_FUNCTIONAL_DIFF.txt`
  - `Review/AIPM_V1_5_R5_SOURCE_SNAPSHOT.txt`
  - `Review/AIPM_V1_5_R5_TEST_SNAPSHOT.txt`
  - `Review/V3_4_GOVERNANCE_CANONICAL_FILES.txt`
  - `Review/V3_4_GOVERNANCE_CORRECTION_DIFF.txt`
  - `Review/V3_4_GOVERNANCE_MIGRATION_DIFF.txt`
  - `Review/V3_4_PI_APPEND_SYSTEM_FINAL.txt`
- The `Prompt/CURRENT_PI_DISPATCH.md` is modified (by
  AIPM) to the active V15-LEGACY-COMPAT-CORRECTION
  dispatch; this is the active dispatch and remains
  in place exactly as AIPM wrote it.

V15-LEGACY-COMPAT-CORRECTION RBZ candidate (THIS UPDATE):

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

Evidence recorded in this file:
- Size: 642,037 bytes
  (back to the pre-hardening size; delta vs the prior
  hardening RBZ SHA-256
  `36CD3FCCADF212CA6CDC3257C01406EA97267BA04AE6D0EF4F020C02BA426C2A`
  is the removed false-claim comment block at
  line 447 of `core/source_snapshot.rb`).
- Entries: 59 (unchanged)
- SHA-256:
  `61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292`
  (byte-identical to the pre-hardening RBZ at
  `f61c352` because the corrective packet reverted
  the production change back to its starting point).

Build command:

`.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe scripts/build_rbz.rb`

Verifications performed:
- packaged `core/source_snapshot.rb` is byte-identical
  to the pre-hardening in-tree source (the RBZ
  contains the corrected source; no stale
  intermediate copy);
- root registration loader `su_ai_plugin.rb` is at
  the RBZ root as expected (not inside the support
  folder);
- support folder `su_ai_plugin/` exists alongside the
  registration loader and contains `main.rb`;
- dialog asset trio (`html/index.html`, `html/app.js`,
  `html/style.css`) is shipped;
- dev-only paths (`tests/`, `scripts/`, `Review/`,
  `Prompt/`, `.vendor/`, `.git/`) are excluded;
- the existing RBZ smoke test
  (`tests/test_rbz_smoke.rb`) ran all 9 RBZ tests
  successfully on the new artifact.

This RBZ candidate is acceptable for the canonical
next Gate (SketchUp 2020 BLOCK-005 Real-Host
Feasibility Probe, Owner/AIPM-owned) once AIPM
accepts this corrective packet. It is NOT gated on
prior Owner verification republishes or prior Codex
narrow recheck gates (the obsolete prerequisite
wording from the prior hardening packet's §H/§I
has been removed per FINDING D).

The corrective dispatch explicitly forbids claiming
SU2017 real-host PASS (dispatch §3 / §15 forbidden).
Only Owner real-host evidence may establish SU2017
support.

V15-LEGACY-COMPAT-HARDENING local checkpoint (history):

- Implementation commit: `1db28d3` (1 implementation
  commit covering the now-retracted
  `1_000_000` -> `1000000` fix + the original 5-test
  regression guard; the implementation commit history
  remains in git log for evidence)
- Source state at that HEAD is no longer authoritative
  for production source-content; the corrective packet
  reverts the production change to its starting point.
- RBZ at that HEAD: SHA-256
  `36CD3FCCADF212CA6CDC3257C01406EA97267BA04AE6D0EF4F020C02BA426C2A`;
  size 642,296 bytes; entries 59.

Round-5 NARROW CONTINUATION (FIX-SR-04) RBZ (history, unchanged):

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
- SHA-stamp commit 2: `b9e1965`
- SHA-stamp commit 3 (acceptance state): `d91d94a2655be451ce84356dba32ffbee89a566e`
- Final `git rev-parse HEAD`:
  `d91d94a2655be451ce84356dba32ffbee89a566e`
- See `Review/CURRENT_PI_REPORT.md` §14 for the full scope.

NARROW CONTINUATION (THIS UPDATE):
- Frozen design: same
  `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`.
- AIPM reviewed the real GitHub implementation commit
  `874149dc7488ff8c844e16fb6e0e6013df9abfa6` and found
  `FIX REQUIRED -- narrow implementation correction` on
  FIX-SR-01 / FIX-SR-02 / FIX-SR-03.
- See `Review/CURRENT_PI_REPORT.md` §3 (THIS UPDATE) for the
  narrow scope.

NARROW CONTINUATION (THIS UPDATE):
- Frozen design: same
  `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`.
- Implementation commit: see § 2.
- Pushed to `origin/dev/v1.5`.
- See `Review/CURRENT_PI_REPORT.md` §3 (THIS UPDATE) for the
  narrow scope.

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

Round-5 Source Review corrective RBZ (history, unchanged):

- Size: 641,652 bytes
- Entries: 59
- SHA-256: `49C3182845CDE8CD8561FDF6BDF83D0AFF5907C267D0C4D5BFFCB7772AA598DF`

Round-5 Source Review corrective RBZ (earlier history, unchanged):

- Size: 637,621 bytes
- Entries: 59
- SHA-256: `90C49AF2E95452C5DAB22D1ABCE5858B1ABC53F5753B7588ED30728F56ACECEB`

NARROW CONTINUATION (FIX-SR-04) CRASH-RECOVERY RESUME (THIS UPDATE):

Starting HEAD (pre-task, also `origin/dev/v1.5`):
`9099f66a0c7d43ba149b83e4a3399361f863d383`

Implementation commit:
`3043219` (FIX-SR-04 production + tests)

Documentation commit:
`aabfa7e` (state + report update)

Final `git rev-parse HEAD`:
`aabfa7e97a1dbb55a39e14afe072939159bea8d1`

Push status:
**PUSH BLOCKED — REMOTE UNREACHABLE.** `git push origin
dev/v1.5` was attempted multiple times; every attempt
failed identically with `Failed to connect to
github.com:443 after 21s: Could not connect to server`.
A direct `curl -I https://github.com` also returns
connection-refused. The remote is configured and was
reachable in prior sessions; this is a transient
network / proxy / firewall failure on this host, not a
code or dispatch issue. The local commits are stable,
self-contained, and atomic. AIPM can retry the push
from any reachable environment.

`origin/dev/v1.5` HEAD (unchanged by THIS UPDATE):
`9099f66a0c7d43ba149b83e4a3399361f863d383`

Working tree (THIS UPDATE, after the implementation +
documentation commits):
- Modified production files (1):
  - `extension/su_ai_plugin/core/duplicate_repair_executor.rb`
    (FIX-SR-04: removed `present = to_remove.select { !nil? }`
    pre-filter in `apply()`; passes the COMPLETE intended
    `to_remove` set into `apply_atomic` so the existing
    strict-liveness contract (FIX-SR-01) rejects nil /
    non-live removal members and a MIXED set fails closed
    BEFORE `begin_operation`; historical `already_applied`
    all-nil skip preserved).
- Modified test files (1):
  - `tests/test_v15_round5_block_fix.rb` (+2 new focused
    regressions: V15-SR04-1 mixed set -> fail closed
    before begin, no partial execution, fingerprint
    unchanged, source immutable, valid removal handle
    remains strictly live; V15-SR04-2 all nil -> preserved
    `:skipped` `already_applied` semantics, no `:failed`,
    no host calls, workspace state unchanged, fingerprint
    unchanged, source immutable).
- Updated governance / report files (2):
  - `CURRENT_STATE.md` (THIS UPDATE)
  - `Review/CURRENT_PI_REPORT.md` (THIS UPDATE)
- Untracked AIPM Review evidence files preserved (7):
  - `Review/AIPM_V1_5_R5_FUNCTIONAL_DIFF.txt`
  - `Review/AIPM_V1_5_R5_SOURCE_SNAPSHOT.txt`
  - `Review/AIPM_V1_5_R5_TEST_SNAPSHOT.txt`
  - `Review/V3_4_GOVERNANCE_CANONICAL_FILES.txt`
  - `Review/V3_4_GOVERNANCE_CORRECTION_DIFF.txt`
  - `Review/V3_4_GOVERNANCE_MIGRATION_DIFF.txt`
  - `Review/V3_4_PI_APPEND_SYSTEM_FINAL.txt`

The dist/ `SU-AI-Plugin.rbz` is rebuilt (NEW SHA) but NOT
tracked (per repo policy).

Round-5 NARROW CONTINUATION (FIX-SR-04) RBZ (THIS UPDATE):

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

Evidence recorded in this file:
- Size: 642,033 bytes
- Entries: 59
- SHA-256:
  `D48B6ED0DC29C8B574946C46DB3DCE122FC54797D4D4384CE89A2FECA5605E84`

Build command:
`.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe scripts/build_rbz.rb`

This RBZ is **not approved for Owner installation** until the
AIPM Owner verification file is republished AND (if AIPM
chooses) the next Codex narrow xHigh recheck passes.

---

## 3. CURRENT TEST EVIDENCE

V15-LEGACY-COMPAT-CORRECTION evidence (THIS UPDATE):

- LEGACY-COMPAT targeted regressions (corrected; 4/4 PASS):
  - `LEGACY-COMPAT: vendored Ruby parses every production
    .rb file (current-source syntax/load smoke)`
    (1/1 PASS — `RubyVM::InstructionSequence.compile`
    on every production .rb; only proves Ruby ≤ 2.7.8
    parseability per the dispatch FINDING B correction)
  - `LEGACY-COMPAT: Ripper.sexp parses every production
    .rb file (current-source AST smoke)`
    (1/1 PASS — same caveat)
  - `LEGACY-COMPAT: no known modern-syntax constructs in
    production source` (1/1 PASS — 4 confirmed-version
    construct classes scanned: `endless_range`,
    `beginless_range`, `numbered_block_params`,
    `safe_navigation`; the integer_literal_underscore
    class is REMOVED per FINDING A)
  - `LEGACY-COMPAT: no endless-range [n..] in production
    source (CONFIRMED-FIX-COMPAT-RANGE)`
    (1/1 PASS — the CONFIRMED prior fix; per-tree guard
    retained per the corrective dispatch directive
    "Do not weaken the confirmed endless-range guard.")
  - Total LEGACY-COMPAT: **4/4 PASS**
    (was 5/5 before this corrective dispatch; the
    per-file integer-underscore guard at
    `core/source_snapshot.rb` was correctly removed
    because the underlying claim was retracted.)
- Full V15: **149/149 PASS** (unchanged from prior)
- Full Ruby suite: **817/817 PASS**
  (was 818 prior to removing the +1 false-positive
  LEGACY-COMPAT integer-underscore per-file guard
  test; no other regressions across the existing 817)
- RBZ smoke (post-rebuild): **9/9 PASS**
  (includes `RBZ: install smoke — extract to temp dir,
  verify entry-point + assets + all .rb files parse`
  which runs `RubyVM::InstructionSequence.compile` on
  every packaged .rb; and `RBZ: install smoke —
  extracted entry-point boots through FakeUI` which
  exercises the production `boot!` require_relative
  chain + Loader.register!)
- `git diff --check`: clean

The endless-range guard's effectiveness was verified
during the prior dispatch (3/5 PASS + 2 FAIL with
explicit file:line + id during temp revert of the
endless-range fix; restoring the fix returns 5/5).
The integer-underscore class is no longer guarded,
and ordinary numeric underscores (e.g. `1_234`,
`1_000_000`) are accepted by all LEGACY-COMPAT tests
as required by the corrected Ruby 2.2-support claim.

Implementation / test evidence only. They do not by themselves
close the AIPM BLOCK on BLOCK-005, prove real-host
behavior, or substitute for Owner verification. They
do not claim SU2017 real-host PASS (dispatch §3
explicitly forbids this without real SU2017 evidence).

Round-5 NARROW CONTINUATION evidence (history):

- Targeted Round-5 NARROW CONTINUATION + FIX-SR-04
  regressions
  (FIX-SR-01 single-action executor: 6 tests +
   FIX-SR-02 expected post state: 7 tests +
   FIX-SR-03 truthful invalid-tolerance reason: 3 tests +
   FIX-SR-04 single-action apply must not pre-filter nil
   removals: 2 tests
   = 18/18 PASS) (added across this continuation + THIS UPDATE)
- Round-5 corrective focused regressions (history): 32/32 PASS
- Round-5 continuation evidence (history): 99/99 PASS
- Full V15 (existing + new): **149/149 PASS**
- Full Ruby suite: **813/813 PASS**
- RBZ smoke: 9/9 PASS (post-rebuild)
- Node DOM (html_render): 163/163 PASS
- `git diff --check`: clean
- `git status --short` (after final commit): untracked: 7 AIPM review evidence `.txt` files preserved per dispatch §Preflight

Round-5 Source Review corrective evidence (history, unchanged):

- Targeted Round-5 Source Review corrective regressions
  (FIX-A: 11 strict-tolerance parser unit tests +
   4 exact-zero layer-key tests +
   5 no-fallback production-path tests +
   FIX-B: 6 exact provenance union tests +
   1 provenance mismatch executor-level test +
   FIX-C: 5 strict handle liveness tests
   = 32/32 PASS) (history)
- Full V15 (history): 131/131 PASS
- Full Ruby suite (history): 795/795 PASS

Round-5 continuation evidence (history, unchanged):

- Targeted Round-5 V15-B00 BLOCK regressions (BLOCK-001, BLOCK-002A/004,
  BLOCK-002B, BLOCK-005): **17/17 PASS**
- Full V15: **82/82 PASS**
- Full Ruby suite: **746/746 PASS**

These are implementation/test evidence only.

They do not by themselves close the Codex BLOCK set, prove real-host
behavior, or substitute for Owner verification.

---

## 4. BLOCK / REVIEW STATUS (CLOSED — historical)

> **V1.5 closure status (THIS UPDATE):** V1.5 is CLOSED. BLOCK-005 is
> CLOSED. Owner SketchUp 2020 V1.5 verification: PASS. The active
> V1.5 BLOCK set below is RETIRED — all V15-STAGE-BLOCK-001..005 are
> formally closed as part of the V1.5 closure decision recorded in
> `Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`. This section is preserved
> for durable audit evidence of the V1.5 closure process; it is
> NOT an active review state.

Historical V1.5 BLOCK set (all CLOSED — historical record only):

- `V15-STAGE-BLOCK-001`
- `V15-STAGE-BLOCK-002` (with sub-cases A and B)
- `V15-STAGE-BLOCK-003`
- `V15-STAGE-BLOCK-004`
- `V15-STAGE-BLOCK-005`

Historical closure process (clearly historical):

> **Round-5 corrective implementation packet addresses FIX-A
> (BLOCK-002A + 004), FIX-B (BLOCK-003), and FIX-C (strict handle
> liveness hardening adjacent to BLOCK-001). Round-5 continuation
> already addressed BLOCK-001 executor-level and BLOCK-005
> production observation seam.** (history)

### BLOCK-005 dedicated technical research (AIPM-side, THIS UPDATE)

> BLOCK-005 dedicated technical research is **COMPLETE** on
> the AIPM side. Technical direction is **FROZEN**. The
> canonical next gate is the **SketchUp 2020 BLOCK-005
> Real-Host Feasibility Probe** (Owner/AIPM-owned; Pi is NOT
> assigned the probe).

V1.5 remains on the existing architecture:

```text
validate-on-next-interaction
-> detect host mismatch
-> fail closed / invalidate
-> host-authoritative prepare/rebuild
```

SketchUp Model remains the geometry Source of Truth.

Explicit V1.5 boundaries (frozen, THIS UPDATE):

- No global ModelObserver / EntitiesObserver architecture is added in V1.5.
- Entity-level observer event replay is rejected as a correctness mechanism.
- `persistent_id` is not the correctness Source of Truth.
- Old Ruby Entity handles must never be trusted after host-state divergence.
- ModelObserver invalidation is only an approved fallback if the
  SketchUp 2020 real-host probe proves the existing validation seam
  insufficient. EntitiesObserver-based incremental reconciliation and
  plugin-side Undo replay remain out of scope even if escalation
  becomes necessary.

BLOCK-005 closure condition (the probe must produce real-host
evidence proving all of the following, THIS UPDATE):

- native Undo/Redo cannot leave stale plugin state falsely READY;
- stale destructive handles cannot reach destructive execution;
- host mismatch fails closed before destructive operation;
- normal product recovery rebuilds fresh inventory / handles / UI
  from the current SketchUp host;
- source CAD remains immutable.

BLOCK-005 status — final closure (THIS UPDATE):

- **CLOSED** (per `Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`).
- Technical direction: FROZEN (`validate-on-next-interaction →
  detect host mismatch → fail closed / invalidate →
  host-authoritative discard + prepare/rebuild`).
- SketchUp Model remains the geometry Source of Truth.
- No global ModelObserver / EntitiesObserver architecture was
  added in V1.5.
- `persistent_id` was never the correctness Source of Truth.
- Old Ruby Entity handles are never trusted after host-state
  divergence.
- Owner SketchUp 2020 V1.5 verification: PASS (Final Product
  Owner confirmation).
- V1.6: NOT STARTED (awaits a separate ACTIVE `CURRENT_PI_DISPATCH`
  referencing the frozen V1.6 Stage Technical Blueprint).

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
reconciliation) remains **OPEN by design** and is NOT part of
the corrective dispatch cycle. Per AIPM Source Review verdict:

> BLOCK-005 is classified as an AIPM technical-design gap,
> not a Pi implementation-choice gap. BLOCK-005 is
> intentionally NOT assigned in the current Pi corrective
> packet. AIPM will separately research SketchUp official
> API, mature open-source SketchUp extensions, Undo/Redo /
> ModelObserver / EntitiesObserver, entity lifecycle /
> persistent identity, license constraints.

**THIS UPDATE (BLOCK-005 documentation-only sync):**

- BLOCK-005 dedicated AIPM technical research is **COMPLETE**.
- Technical direction is **FROZEN** on the existing
  `validate-on-next-interaction -> detect host mismatch ->
  fail closed / invalidate -> host-authoritative
  prepare/rebuild` architecture.
- SketchUp Model remains the geometry Source of Truth.
- No global ModelObserver / EntitiesObserver architecture is
  added in V1.5.
- Entity-level observer event replay is rejected as a
  correctness mechanism.
- `persistent_id` is not the correctness Source of Truth.
- Old Ruby Entity handles must never be trusted after
  host-state divergence.
- ModelObserver invalidation is only an approved fallback if
  the SketchUp 2020 real-host probe proves the existing
  validation seam insufficient.

Pi must NOT invent a new Observer / Undo architecture while
the SketchUp 2020 BLOCK-005 Real-Host Feasibility Probe is
being run by Owner/AIPM.

### Round-5 NARROW CONTINUATION (THIS UPDATE) — narrow
implementation corrections to the same dispatch

After AIPM directly reviewed the real GitHub implementation
commit `874149dc7488ff8c844e16fb6e0e6013df9abfa6` the verdict
was `FIX REQUIRED -- narrow implementation correction`. This
narrow continuation implements three bounded fixes within the
same frozen Guidance; the design is unchanged.

#### FIX-SR-01 — single-action executor must fail closed
`extension/su_ai_plugin/core/duplicate_repair_executor.rb`

`apply_atomic` (the single-action entry path) was classifying
removal handles into `valid_pairs` / `invalid_ids` but did
NOT fail closed when `invalid_ids` was non-empty: it would
open a host operation, dispose only the valid handles, then
logically `total_removed = (removed_ids + invalid_ids).uniq`,
producing host/logical divergence.

Now: BEFORE `begin_operation`, if any removal member is not
strictly live (`DuplicateGeometrySemantics.strict_handle_live?`
returns false — nil, missing `valid?`, returns nil/false, or
raises), the function:
- `begin=0`, `dispose=0`, `commit=0`, `abort=0`;
- emits a `:failed` action with stable reason
  `removal_handle_not_strictly_live: [...]` (per-id detail);
- transitions the workspace to `:failed` with the same
  reason;
- preserves the exact logical pre-state;
- source CAD immutable.

Reuses the existing `strict_handle_live?` contract; no new
predicate. The normal valid-handle success path remains
green (covered by V15-SR01-6).

#### FIX-SR-02 — expected post state must prove handle liveness
`extension/su_ai_plugin\core\duplicate_repair_expected_post_state.rb`

The previous F / H aliasing invariants in `validate!` checked
`equal?` aliasing with `next if sh.nil?` / `next if rh.nil?`,
so a nil or non-live handle was silently SKIPPED. This did
not fully satisfy the frozen Guidance.

Now: a NEW invariant J is inserted BEFORE the existing F / H
aliasing checks. For every survivor + removal handle in the
expected post-state, the validator calls
`DuplicateGeometrySemantics.strict_handle_live?` (the same
single source of truth used in the executor). Any
- nil survivor handle -> invalid, reason
  `survivor_handle_missing: <id>`.
- nil removal handle -> invalid, reason
  `removal_handle_missing: <id>`.
- handle lacking `:valid?` -> invalid, reason
  `<survivor|removal>_handle_no_valid_predicate: <id>`.
- handle whose `valid?` returns nil / false -> invalid,
  reason `<survivor|removal>_handle_not_strictly_live: <id>
  valid?=...`.
- handle whose `valid?` raises -> invalid, reason
  `<survivor|removal>_handle_valid?_raised: <id> <exc>`.

This invariant is in addition to (not a replacement for) the
existing F / H aliasing invariants and the existing preflight /
final-proof executor checks. The preflight and final-proof
remain in place; the expected-state J is an additional
gate. Fingerprint (invariant E) and pair-metric (invariant I)
remain in force; provenance union (FIX-B) remains in force.

#### FIX-SR-03 — truthful invalid-tolerance audit reason
`extension/su_ai_plugin/core/duplicate_repair_proposer.rb`

When the proposer's `build_actions` detected a missing /
invalid captured duplicate tolerance, the emitted skipped
audit row used `REASON_NON_FINITE_COORDS` (`non_finite_endpoint_coordinates`),
which is semantically false for a configuration failure.

Now: a new stable reason `REASON_INVALID_CAPTURED_TOLERANCE =
'invalid_or_missing_captured_tolerance'.freeze` is added,
and the missing / invalid captured-tolerance branch uses
this truthful reason. The endpoint-geometry reason
(`non_finite_endpoint_coordinates`) is reserved for actual
coordinate failures. The fail-closed behavior is preserved
(zero applied actions; one skipped audit row with stable
reason). No UI redesign.

### Round-5 NARROW CONTINUATION — added tests
`tests/test_v15_round5_block_fix.rb` got 16 new focused
regressions (V15-SR01-1..6 + V15-SR02-1..7 + V15-SR03-1..3):

- **SR01 (6 tests)**: exercise the single-action `apply()`
  path directly. 4 invalid-handle shapes (missing
  `:valid?`, `valid?` returns nil, `valid?` returns false,
  `valid?` raises) -> all fail closed with `begin=0`,
  no disposal/commit, no READY, exact pre-state, source
  immutable. 1 multi-removal partial-execution test ->
  the valid removal handle is NOT partially disposed.
  1 baseline all-valid success test (existing behavior
  remains green).
- **SR02 (7 tests)**: pure-data state mutations prove the
  expected-state validator catches nil survivor handle,
  nil removal handle, removal missing `:valid?`, removal
  `valid?` returns nil; the existing survivor/removal
  aliasing and removal/removal aliasing invariants still
  fire (regression); the all-valid baseline still validates.
- **SR03 (3 tests)**: missing / invalid (`'abc'`) captured
  tolerance produce a skipped audit row with
  `skipped:invalid_or_missing_captured_tolerance`; the
  non-finite endpoint geometry reason remains
  `skipped:non_finite_endpoint_coordinates` and is NOT
  cross-polluted.

### Round-5 NARROW CONTINUATION — CRASH-RECOVERY RESUME — FIX-SR-04 (THIS UPDATE)

After AIPM directly reviewed the prior NARROW CONTINUATION
implementation commit `889548590ead211162be704af3b22d7299583357`
the verdict was `FIX REQUIRED -- do not pre-filter nil
removals in single-action apply`. The previous Pi process
terminated unexpectedly before FIX-SR-04 could be completed.
This CRASH-RECOVERY RESUME implements the bounded
correction within the SAME frozen
`Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX_2026-08-28.md`
design.

Crash-recovery classification: **CASE A — no FIX-SR-04
work existed**. Starting local HEAD =
`9099f66a0c7d43ba149b83e4a3399361f863d383` ==
`origin/dev/v1.5`. No tracked modifications. No stash.
Only the 7 untracked AIPM Review evidence `.txt` files
were present and have been preserved (not added, deleted,
modified, committed, or cleaned).

#### FIX-SR-04 — single-action apply must not pre-filter nil removals

`extension/su_ai_plugin/core/duplicate_repair_executor.rb`

The public single-action entry
`DuplicateRepairExecutor.apply(...)` previously filtered:

```ruby
present = to_remove.select { |id| !workspace.handle_for(id).nil? }
```

before calling `apply_atomic`. A removal handle returning
`nil` (cleared) was silently dropped, so a MIXED set
(valid A + nil B) reached `apply_atomic` with only A;
`apply_atomic` then disposed A alone, producing host /
logical divergence.

Now: the pre-filter is removed. `apply()` passes the
COMPLETE intended `to_remove` set into `apply_atomic`
(Option B from the dispatch). The existing
`apply_atomic` strict-liveness contract (FIX-SR-01)
already classifies every member via
`DuplicateGeometrySemantics.strict_handle_live?`:
- nil -> invalid;
- no-`:valid?` -> invalid;
- nil-`valid?` -> invalid;
- false-`valid?` -> invalid;
- raise-`valid?` -> invalid.

A MIXED set therefore fails closed BEFORE
`begin_operation`:
- `begin_calls == 0`, `dispose_calls == 0`,
  `commit_calls == 0`, `abort_calls == 0`;
- action transitions to `:failed` with stable reason
  `removal_handle_not_strictly_live: [<id>:missing; ...]`;
- workspace transitions to `:failed` with the same
  reason;
- logical entity inventory preserved;
- logical workspace fingerprint preserved;
- source immutable;
- no false READY publication.

No new predicate, no new architecture. The historical
`already_applied` all-nil skip path is preserved (the
`to_remove.all? { nil? }` early-return is the first thing
`apply()` checks and is unchanged).

#### FIX-SR-04 — added tests

`tests/test_v15_round5_block_fix.rb` got 2 new focused
regressions:

- **V15-SR04-1** (mixed nil + live) — one action with
  survivor + 2 removals; `handle_for(removal_A)` is
  valid/live; `handle_for(removal_B)` is nil. Public
  `DuplicateRepairExecutor.apply(...)` returns a failed
  workspace with `begin_calls == 0`, `dispose_calls ==
  0`, `commit_calls == 0`, `abort_calls == 0`, action
  status `:failed`, confidence_basis matches
  `/removal_handle_not_strictly_live/`, valid removal A
  still strictly live, workspace fingerprint unchanged,
  source immutable.
- **V15-SR04-2** (all nil) — one action with survivor +
  1 removal; both handles cleared from the registry.
  Public `Apply(...)` returns `:skipped` `already_applied`
  semantics with NO `:failed` transition, NO host calls,
  workspace state unchanged, fingerprint unchanged,
  source immutable.

#### FIX-SR-04 — evidence

- FIX-SR-04 focused regressions: 2/2 PASS
- NARROW CONTINUATION (SR01/02/03/04): 18/18 PASS
- Full V15: **149/149 PASS**
- Full Ruby suite: **813/813 PASS**
- RBZ smoke: 9/9 PASS (post-rebuild)
- Node DOM: 163/163 PASS
- `git diff --check`: clean

#### FIX-SR-04 — RBZ (THIS UPDATE)

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

- Size: 642,033 bytes
- Entries: 59
- SHA-256:
  `D48B6ED0DC29C8B574946C46DB3DCE122FC54797D4D4384CE89A2FECA5605E84`
- Previous NARROW CONTINUATION SHA:
  `49C3182845CDE8CD8561FDF6BDF83D0AFF5907C267D0C4D5BFFCB7772AA598DF`

This RBZ is **not approved for Owner installation** until
the AIPM Owner verification file is republished AND (if
AIPM chooses) the next Codex narrow xHigh recheck passes.

---

## 5A. V15-LEGACY-COMPAT-CORRECTION DISPOSITION (THIS UPDATE)

The V15-LEGACY-COMPAT-HARDENING-2026-08-31 dispatch produced
output that was authoritative-reviewed by AIPM. The review
identified four findings (A-D), all accepted in this
corrective dispatch
`V15-LEGACY-COMPAT-CORRECTION-2026-08-31`:

### FINDING A — Integer literal underscore claim RETRACTED

The prior report claimed integer literal underscore syntax
is Ruby 2.5+ and therefore incompatible with SketchUp 2017
(Ruby 2.2.4). That claim is factually INCORRECT. Ruby 2.2
official syntax documentation explicitly supports
underscores in numeric literals (e.g. `1_234`). The
`1_000_000` integer literal underscore syntax in
`extension/su_ai_plugin/core/source_snapshot.rb:447` was
NOT a real Ruby-2.5-only parse hazard, the
`1_000_000` -> `1000000` replacement was unnecessary for
the stated compatibility reason, and the `1000000`
form plus the false version-history comment is now
removed.

Result: `extension/su_ai_plugin/core/source_snapshot.rb`
is restored to its pre-hardening state (the readable
`1_000_000` form). No behavior change. No frozen-contract
change.

### FINDING B — Vendored-parser evidence wording CORRECTED

The prior report described the Ruby 2.7.8 vendored parse
as "catching a strict superset of what older SketchUp Ruby
runtimes would reject" and "a strict superset of what
SU2017/SU2018 would catch". A newer parser can ACCEPT
syntax that an older parser REJECTS (the opposite of the
prior claim). Both vendored-parse and Ripper.sexp AST
parse are now documented honestly as current-source
syntax/load smoke (catches Ruby ≤ 2.7.8 parse
incompatibilities, which a SU2017/SU2020 host would also
catch) and NOT as proof of old-Ruby parseability.

Result: `tests/test_v15_legacy_compat_guard.rb` test
names re-framed ("current-source syntax/load smoke",
"current-source AST smoke") with the evidence-bound
caveat documented inline. No behavior change.

### FINDING C — SketchUp API classification CORRECTED

The prior report stated "Modern-only APIs found: 0"
while listing capability-gated host calls such as
`Model#find_entity_by_id` and `entity.persistent_id`.
The list conflated baseline-SU2017 APIs with
post-SU2017-but-capability-gated APIs and then reported
zero modern-only APIs. That is overstated.

Result: the API inventory is now categorised truthfully
into:

A. **Baseline-or-earlier APIs for an SU2017+ target** (the
      original class label is preserved; the items below are
      baseline-or-earlier for the project's SU2017+ target,
      plus the SU2017-release APIs listed at the end of this
      category are ALSO baseline-or-earlier for the same
      SU2017+ target):
   `Sketchup.version`, `Sketchup.active_model`,
   `Sketchup.format_length`, `Sketchup.register_extension`,
   `SketchupExtension.new`, `file_loaded?` /
   `file_loaded`, `Sketchup::Entity#entityID`,
   `#typename`, `#valid?`, `#layer`, `#vertices`,
   `#start`, `#end`, `#definition`,
   `Sketchup::Edge` / `Face` accessors, `Layer#name` /
   `#visible?`, `Sketchup::Group` /
   `Sketchup::ComponentInstance`, `Sketchup::Model#entities`
   / `#selection` / `#definitions`,
   `UI::Command.new`, `UI.menu`, `Sketchup::Menu#add_submenu`
   / `#items`, `Geom::Transformation`, `Geom::Point3d`,
   `model.entities.add_group` (gated with `respond_to?`),
   `model.selection.add` / `.clear`, `model.edit_transform`,
   `entity.layer`, etc.
   Plus the SU2017-release APIs (since the project's
   baseline target IS Sketchup 2017+, these are
   baseline-or-earlier for that target, NOT
   post-baseline):
     - `Sketchup::Model#find_entity_by_id` -- Sketchup
       2015+ (baseline-or-earlier for an SU2017+ target)
     - `Sketchup::Model#active_path` (getter) --
       Sketchup 7.0 (production uses only the getter;
       the setter `Model#active_path=` is NOT called
       anywhere in production and would be classified
       separately if used; it isn't)
     - `Sketchup::Entity#persistent_id` -- Sketchup
       2017+ on the relevant entity classes; baseline
       for an SU2017+ target
     - `Sketchup::Model#instance_path_from_pid_path`
       -- Sketchup 2017+; baseline for an SU2017+ target
     - `UI::HtmlDialog` -- Sketchup 2017+; baseline for
       an SU2017+ target
   All five are correctly capability-gated in
   `extension/su_ai_plugin/compatibility/su_capability.rb`
   and at every host call site. The gating is a
   defensive belt-and-braces pattern (forward-compat for
   future host variations), NOT a post-baseline
   compatibility workaround.



B. **Post-SU2017 but capability-gated APIs** (introduced
   AFTER the Sketchup 2017 release, with both an
   `respond_to?` / `defined?` gate and a closed fallback):
   none recorded at this time. After the corrected
   inventory (which moved the SU2017-release APIs to
   category A), no host call site in production uses
   an API introduced after the Sketchup 2017 release
   without a closed fallback. The defensive gates in
   `su_capability.rb` remain as forward-compat
   belt-and-braces, but they are not POST-baseline
   gating for any current production call.
C. **Uncertain / version-evidence-conflict items**: none
   recorded at this time. Any future API whose
   introduction version is genuinely uncertain should
   be classified here with the conflict noted, NOT
   collapsed into A or B by wishful classification.
D. **Unsafe unguarded post-baseline APIs**: zero
   (the existing `SUCapability` shim is the project's
   documented capability detector and is correctly used
   at every host call site).

No production host-call site was changed (FINDING C
explicitly says: "Do NOT modify production host
behavior unless a concrete unsafe unguarded call is
proven").

### FINDING 2 — SU2017-release APIs RECLASSIFIED TO BASELINE (THIS UPDATE)

The V15-LEGACY-COMPAT-FINAL-EVIDENCE-FIX dispatch
(`V15-LEGACY-COMPAT-FINAL-EVIDENCE-FIX-2026-08-31`)
authoritative review found that the items listed above
under category B (`Model#find_entity_by_id`,
`Model#active_path` (getter), `Entity#persistent_id`,
`Model#instance_path_from_pid_path`, `UI::HtmlDialog`)
are, per official SU API version history, baseline-or-
earlier for an SU2017+ project target (NOT post-
baseline):

- `Sketchup::Model#find_entity_by_id` — SU2015
- `Sketchup::Model#active_path` (getter) — SU7.0
- `Sketchup::Entity#persistent_id` — SU2017+
- `Sketchup::Model#instance_path_from_pid_path` —
  SU2017+
- `UI::HtmlDialog` — SU2017+

Production code does NOT call the `Model#active_path=`
setter (which IS a later API; would be classified
separately if it were used; it isn't).

These five APIs have therefore been moved INTO
category A above (baseline-or-earlier for an SU2017+
target). Category B is now EMPTY for production
host-call sites: no production call uses an API
introduced after the Sketchup 2017 release. The
defensive capability gates in
`extension/su_ai_plugin/compatibility/su_capability.rb`
and at every host call site remain as forward-compat
belt-and-braces pattern (correctly used for SU2017-
baseline APIs whose actual introduction may vary
slightly across SU2017 patch generations and whose
fallback must be safe in any future host variation),
NOT because of any post-baseline necessity.

### FINDING 3 — BEGINLESS RANGE VERSION CORRECTED (THIS UPDATE)

The prior regex guard comment said beginless range
`[..b]` was introduced in Ruby 2.6. Per official Ruby
release history:

- endless range `(a..)` / `ary[a..]` — Ruby 2.6.0
- beginless range `(..a)` / `ary[..b]` — Ruby 2.7.0

This packet corrects the beginless_range entry in
`KNOWN_MODERN_SYNTAX` in
`tests/test_v15_legacy_compat_guard.rb`:

- `ruby_min_unsupported`: `2.6.0` -> `2.7.0`
- `ruby_min_required`: `2.6.0` -> `2.7.0`
- comment: `Ruby >= 2.6.0` -> `Ruby >= 2.7.0`
- multi-line note explaining the endless-vs-beginless
  distinction added to the rule entry

The guard itself is preserved: beginless range remains
incompatible with the Ruby 2.2 baseline (introduced in
2.7 vs baseline 2.2 -> incompatible). Only the
introduction version is corrected. The endless-range
(Ruby 2.6+) rule is unchanged; the numbered_block_params
(Ruby 2.7+) rule is unchanged; the safe_navigation
(Ruby 2.3+) rule is unchanged.

### FINDING D — Obsolete prerequisite gates REMOVED

The prior report's `Review/CURRENT_PI_REPORT.md` §H and §I
plus `CURRENT_STATE.md` §5A reintroduced stale
historical-gate statements claiming the RBZ could not be
used until the AIPM Owner verification file is
republished AND (if AIPM chooses) the next Codex narrow
xHigh recheck passes. Those are stale historical-gate
statements unless a CURRENT authoritative governance file
newer than the latest AIPM BLOCK-005 research freeze
explicitly re-establishes them. Per the current
authoritative project state in §12 below, no such
re-establishment exists.

Result: the obsolete prerequisite wording is removed
from CURRENT_STATE §5A and from the new
`CURRENT_PI_REPORT.md`. The RBZ candidate produced by
this corrective packet is acceptable for the canonical
next Gate (SketchUp 2020 BLOCK-005 Real-Host Feasibility
Probe, Owner/AIPM-owned) once AIPM accepts this
corrective packet. It is NOT gated on prior Owner
verification republishes or prior Codex narrow recheck
gates.

### Audit coverage (unchanged by the correction)

The COMPLETE production Ruby load tree was audited under
the prior hardening dispatch and the audit inventory
remains accurate for this correction:

- Root registration loader `extension/su_ai_plugin.rb` (1)
- Support folder `extension/su_ai_plugin/**/*.rb` (57)
- Production script `scripts/build_rbz.rb` (1)
- Total production Ruby files audited: **59**
  (matches the rebuilt RBZ entry count)

### CONFIRMED finding (kept)

The CONFIRMED endless-range finding at the start of this
correspondence series is preserved: `sorted_ids[1..]`
(Ruby 2.6+ endless range) is NOT a SU2020-supported
construct (SU2020 embeds Ruby 2.5.5). The two sites in
`core/duplicate_repair_proposer.rb` were replaced with
`sorted_ids[1..-1]` in the prior implementation commit
`f61c352`. The `tests/test_v15_legacy_compat_guard.rb`
per-tree guard `LEGACY-COMPAT: no endless-range [n..] in
production source (CONFIRMED-FIX-COMPAT-RANGE)` is
RETAINED per the corrective dispatch directive "Do not
weaken the confirmed endless-range guard."

### Regression guard (corrected)

`tests/test_v15_legacy_compat_guard.rb` (corrected; 4 tests):

1. `LEGACY-COMPAT: vendored Ruby parses every production
    .rb file (current-source syntax/load smoke)` — uses
   `RubyVM::InstructionSequence.compile(text, file)` on
   every production `.rb` (same mechanism `tests/test_rbz_smoke.rb`
   uses for the extracted RBZ). Catches Ruby <= 2.7.8
   parse incompatibilities (a subset of the SU2017/SU2020
   support boundary, NOT a strict superset).
2. `LEGACY-COMPAT: Ripper.sexp parses every production
    .rb file (current-source AST smoke)` — same caveat
   via Ripper.sexp.
3. `LEGACY-COMPAT: no known modern-syntax constructs in
    production source` — targeted regex scan for the
   4 construct classes with confirmed version evidence:
     - endless_range (Ruby 2.6+)
     - beginless_range (Ruby 2.7+)  (NOT Ruby 2.6+
       which is the version that introduced endless
       range; beginless range entered in Ruby 2.7
       per official Ruby release history. The guard
       rule is preserved — beginless range remains
       incompatible with the Ruby 2.2 baseline — only
       the stated introduction version is corrected.)
     - numbered_block_params (Ruby 2.7+)
     - safe_navigation (Ruby 2.3+)
   The integer_literal_underscore class is REMOVED per
   FINDING A (Ruby 2.2 supports this officially and the
   prior claim was factually wrong). Test name now says
   only what it actually checks: "no known modern-syntax
   constructs".
4. `LEGACY-COMPAT: no endless-range [n..] in production
    source (CONFIRMED-FIX-COMPAT-RANGE)` — pins the
   CONFIRMED prior fix on every production file.

The per-file guard for the (false) integer-underscore
change on `core/source_snapshot.rb` is REMOVED (5 -> 4
tests). The guard's effectiveness at catching the
endless-range class was verified during the prior
dispatch (3/5 -> 5/5 with the temp revert). The integer-
underscore class is no longer a guard class.

### Production behavior freeze (§9 confirmation, retried)

Per the corrective dispatch §10 hard boundaries:

- BLOCK-005 production architecture modified: **NO**.
- Observers added (ModelObserver / EntitiesObserver /
  EntityObserver): **NO**.
- Undo reconciliation redesigned: **NO**.
- Persistent-id correctness architecture added: **NO**.
- Source-of-truth or state/data ownership changed: **NO**.

BLOCK-005 remains on the frozen
`validate-on-next-interaction -> detect host mismatch ->
fail closed / invalidate -> host-authoritative
prepare/rebuild` architecture, with the SketchUp Model
as the geometry Source of Truth.

### Scale / safety limit (§13 confirmation)

- Production files requiring semantic modifications: **0**
  net in this corrective dispatch
  (the `1000000` form is restored to `1_000_000`;
  the production diff is the exact inverse of the prior
  hardening patch).
- Test files modified: **1**
  (`tests/test_v15_legacy_compat_guard.rb` — rule
  removal + wording correction).
- No broad compatibility architecture change.
- No new host-call / API redesign.
- No required minimum-version product decision.
- No transaction/recovery implications.

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

### Canonical next gate (THIS UPDATE)

**SketchUp 2020 BLOCK-005 Real-Host Feasibility Probe** —
Owner/AIPM-owned.

Pi is NOT assigned this probe.

### Probe goal

Verify on a real SketchUp 2020 host that the existing V1.5
`validate-on-next-interaction -> detect host mismatch -> fail
closed / invalidate -> host-authoritative prepare/rebuild`
seam is sufficient to satisfy the BLOCK-005 closure
condition:

- native Undo/Redo cannot leave stale plugin state falsely
  READY;
- stale destructive handles cannot reach destructive
  execution;
- host mismatch fails closed before destructive operation;
- normal product recovery rebuilds fresh inventory / handles /
  UI from the current SketchUp host;
- source CAD remains immutable.

### Parallel gates for the remaining BLOCK set
1. AIPM directly reviews the Round-5 NARROW CONTINUATION +
   FIX-SR-04 crash-recovery resume Pi packet on GitHub
   (`Review/CURRENT_PI_REPORT.md`) for the BLOCK-001..004
   closure path.
2. AIPM republishes the canonical Owner verification file
   `Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`
   (BLOCK-005 deliverable, Pi is not the author).

### If the SU2020 real-host probe proves the existing seam sufficient
1. AIPM records the probe result in
   `Review/CURRENT_AIPM_REVIEW.md`.
2. BLOCK-005 is formally closed.
3. The V1.5 BLOCK set may be formally closed only after AIPM
   direct source PASS for the remaining implementation gates
   and Owner real-SketchUp verification is complete.
4. AIPM designs and freezes a V1.6 Stage Technical Blueprint
   before any V1.6 implementation begins.

### If the SU2020 real-host probe proves the seam insufficient
1. The only approved first escalation is a deferred /
   debounced ModelObserver transaction event that marks plugin
   state dirty / stale, followed by host-authoritative re-read
   + rebuild. EntitiesObserver-based incremental reconciliation
   and plugin-side Undo replay remain out of scope even in
   this escalation.
2. AIPM updates the BLOCK-005 technical design as required.
3. A new AIPM dispatch assigns the bounded fix to Pi.
4. Codex (if AIPM chooses) performs a narrow recheck.

### If Codex is later required for a BLOCK recheck
1. Codex reports only remaining / new causally related material
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
implementation (commit `874149d`, history) -> GitHub origin
push -> AIPM direct GitHub Source Review on `874149d` (FIX
REQUIRED, narrow correction) -> Pi Round-5 NARROW CONTINUATION
implementation (FIX-SR-01/02/03, commit `8895485`, history)
-> pushed to origin/dev/v1.5 -> AIPM direct GitHub Source
Review on `8895485` (FIX REQUIRED, do not pre-filter nil
removals in single-action apply) -> Pi CRASH-RECOVERY
RESUME FIX-SR-04 implementation (THIS UPDATE) -> pushed
to origin/dev/v1.5 -> awaiting AIPM direct GitHub Source
Review -> AIPM Owner-checklist republish -> optional Codex
narrow recheck -> closure / next fix.

Pi is **STOPPED** awaiting AIPM direct GitHub Source Review
on the FIX-SR-04 crash-recovery resume.

**BLOCK-005 documentation-only sync (THIS UPDATE, 2026-08-31):**
BLOCK-005 dedicated AIPM technical research is COMPLETE;
technical direction is FROZEN on the existing
`validate-on-next-interaction` architecture. The canonical
next gate for BLOCK-005 is the SketchUp 2020 BLOCK-005
Real-Host Feasibility Probe (Owner/AIPM-owned; Pi is not
assigned). Pi did NOT modify production code, did NOT run
the probe, did NOT rebuild the RBZ, did NOT rerun tests,
and did NOT push. The prior "FIX-SR-04 awaiting AIPM source
review" gate remains in effect for BLOCK-001..004 closure.
Pi is STOPPED awaiting both the AIPM direct GitHub Source
Review and the SU2020 BLOCK-005 Real-Host Feasibility Probe
(the latter is Owner/AIPM-owned and requires no Pi action).

---

# One-Line Current State

**V1.5 CLOSURE (THIS UPDATE, 2026-08-31):** V1.5 is **CLOSED**.
BLOCK-005 is **CLOSED**. Owner SketchUp 2020 V1.5 verification:
**PASS** (Final Product Owner confirmation per
`Prompt/AIPM_V1_5_CLOSURE_2026-08-31.md`). BLOCK-005 technical
direction remains frozen on `validate-on-next-interaction →
detect host mismatch → fail closed / invalidate →
host-authoritative discard + prepare/rebuild` (no global
Observer architecture; SketchUp Model remains the geometry
Source of Truth; `persistent_id` is not the correctness Source
of Truth; old Ruby Entity handles are never trusted after
host-state divergence). Accepted V1.5 RBZ verified at
`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz` (size
**642,037 bytes**; entries **59**; SHA-256
**`61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292`**).
This CLOSURE-ONLY sync dispatch (`V15-CLOSURE-SYNC-2026-08-31`)
made ZERO production / runtime / test / RBZ / V1.6
implementation changes. V1.6: **NOT STARTED** (Stage Technical
Blueprint is frozen in `Prompt/`; implementation awaits a
separate ACTIVE `CURRENT_PI_DISPATCH` referencing it). V1.7 /
V2 / MCP: NOT STARTED / OUT OF SCOPE. Codex: NOT REQUIRED for
this closure step. One local closure checkpoint commit created
on the assigned `dev/v1.5`; pushed to `origin/dev/v1.5` if the
V3.4 submission policy permits and the remote is reachable /
not diverged. Pi STOPPED awaiting AIPM V1.6 dispatch. No real
SU2017 / SU2020 compatibility PASS is claimed; evidence bounded
by the only vendored Ruby available (2.7.8).

---

**Historical V1.5 closure-process one-line summaries (clearly
historical, retained for audit only — V1.5 is CLOSED above):**

**V1.5 V15-LEGACY-COMPAT-FINAL-EVIDENCE-FIX dispatch EXECUTION
COMPLETE (2026-08-31): bounded final-evidence
correction per AIPM dispatch
`V15-LEGACY-COMPAT-FINAL-EVIDENCE-FIX-2026-08-31`. FINDING 1
(placeholder SHA markers removed; exact implementation
commit SHA `36eb6da97c1040d9772656467208b0105cd16fa3`
recorded explicitly; final HEAD = `git rev-parse HEAD`
after the two-commit "implementation + doc-stamp" pattern).
FINDING 2 (SU2017-release APIs `Model#find_entity_by_id`
[SU2015], `Model#active_path` getter [SU7.0],
`Entity#persistent_id` [SU2017+],
`Model#instance_path_from_pid_path` [SU2017+], `UI::HtmlDialog`
[SU2017+] reclassified from category B "post-SU2017 but
capability-gated" into category A "baseline-or-earlier for an
SU2017+ target"; `Model#active_path=` setter NOT used in
production; category B now EMPTY for current production host
calls). FINDING 3 (beginless range `(..a)` was actually
introduced in Ruby 2.7, not Ruby 2.6; corrected
`ruby_min_unsupported` and `ruby_min_required` both to `2.7.0`
in the test file rule, plus the rule comment; guard itself
preserved). Test evidence: LEGACY-COMPAT 4/4 PASS (was 4/4
prior; only the beginless-range rule's `ruby_min_*` field and
comment changed; behavior unchanged); V15 149/149 PASS; full
Ruby suite 817/817 PASS (unchanged from prior); RBZ install/
load smoke 9/9 PASS (unchanged). `git diff --check` clean.
ZERO production byte change (production source
`core/source_snapshot.rb` is byte-identical to the prior
corrective commit `36eb6da`; the RBZ SHA
`61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292`
is preserved because production source is unchanged and the
build process is deterministic). Local commits created on
the assigned `dev/v1.5` (implementation + doc-stamp); NOT
pushed per dispatch directive. BLOCK-005: OPEN (NOT closed
by this packet). BLOCK-005 technical direction: FROZEN.
Codex: NOT REQUIRED for the current compatibility/probe
path. V1.6: NOT STARTED. Canonical next Gate after AIPM
acceptance of this packet: **SketchUp 2020 BLOCK-005
Real-Host Feasibility Probe** (Owner/AIPM-owned). No real
SU2017 / SU2020 compatibility PASS is claimed. Evidence
bounded by the only vendored Ruby available (2.7.8).

**V1.5 V15-LEGACY-COMPAT-CORRECTION dispatch EXECUTION COMPLETE
(THIS UPDATE, 2026-08-31): AIPM authoritatively reviewed the
prior V15-LEGACY-COMPAT-HARDENING packet output and
identified four findings (A-D), all accepted in this
corrective packet. FINDING A (integer literal underscore
`1_000_000` -> Ruby 2.5+ was wrong; Ruby 2.2 supports this
officially; the readability-improving `1_000_000` is
restored at `extension/su_ai_plugin/core/source_snapshot.rb:447`,
the false comment block is removed). FINDING B (vendored-
Ruby-2.7.8 parse = "strict superset of older rejections" was
inverted; new wording is "current-source syntax/load smoke"
not proof of old-Ruby parseability). FINDING C
("Modern-only APIs found: 0" overstated; API inventory
now correctly broken into SU2017-baseline +
post-SU2017-but-capability-gated + uncertain + unsafe-
unguarded (the last being empty), with no collapsing).
FINDING D (obsolete prerequisite gates "Owner verification
republish + Codex narrow recheck" removed; the current
canonical next Gate is the SketchUp 2020 BLOCK-005
Real-Host Feasibility Probe (Owner/AIPM-owned), not
gated on prior Owner republish or Codex recheck).
Production diff (THIS UPDATE) is the byte-inverse of the
prior hardening packet (production source restored to
`1db28d3^` state; no behavior change). Test guard
`tests/test_v15_legacy_compat_guard.rb` corrected:
`integer_literal_underscore` rule removed from
`KNOWN_MODERN_SYNTAX`; per-file guard pinning the false
change on `core/source_snapshot.rb` removed; 5 -> 4
tests; the CONFIRMED endless-range per-tree guard
retained per the corrective dispatch directive. RBZ
rebuilt via the existing `scripts/build_rbz.rb`;
packaged `core/source_snapshot.rb` byte-identical to
in-tree source; size **642,037 bytes** (was 642,037 in
the prior f61c352 RBZ before my prior hardening
introduced the false patch; SHA-256 returns to
`61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292`,
identical to the pre-hardening artifact because the
production change reverts to its starting point);
entries 59 (unchanged). Full Ruby suite **817/817
PASS** (was 818 prior to +1 false-positive LEGACY-COMPAT
test removal; no other regressions across the existing
817). V15: 149/149 PASS. RBZ install/load smoke: 9/9
PASS. `git diff --check`: clean. Local checkpoint
commit exists on the assigned `dev/v1.5`; NOT pushed per
dispatch §9. BLOCK-005: OPEN (NOT closed by this
correction). BLOCK-005 technical direction: FROZEN.
Codex: NOT REQUIRED for the current
compatibility/probe path. V1.6: NOT STARTED. Pi STOPPED
awaiting AIPM direct source review of this corrective
packet.**
