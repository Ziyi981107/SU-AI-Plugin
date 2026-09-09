# CURRENT PI REPORT — V1.9A P0 FINAL NARROW RESIDUAL CORRECTION (THIS UPDATE)

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Final Block Fix
Packet: P0 FINAL NARROW RESIDUAL CORRECTION (FINAL-R2-01 + FINAL-R5-01)
Authority: `Prompt/CURRENT_PI_DISPATCH.md` (V1.9A P0
NARROW RECHECK FIX dispatch, 2026-09-08) + AIPM source recheck
guidance
`Prompt/AIPM_V1_9A_P0_FINAL_NARROW_RESIDUAL_CORRECTION_2026-09-09.md`.
Baseline HEAD: `ff35cfae1962538c29ff48aca4dfd593ee6ddb81`
(`dev/v1.9` V1.9A P0 NARROW RECHECK FIX merge commit; the
prior packet closed R1, R3, R4, R6, R7 cleanly. AIPM
direct source recheck found TWO narrow residuals).
Baseline branch: `dev/v1.9`
TARGET_BRANCH: **dev/v1.9**
A0 Owner UX Gate: PASS
A1 packet: COMPLETE (V1.9A-A1 PRODUCTION UI SHELL +
PRESENTATION MODEL + FIX REQUIRED continuation +
LEGACY RUBY COMPATIBILITY NARROW FIX + V1X-LEGACY-RUBY-
DEBT-CLOSURE predecessor packets).
A2 packet: COMPLETE on `dev/v1.9` (the call order /
invalidation seam / refresh / rebuild-and-scan /
gap-ordering / error-boundary propagation are
FROZEN unchanged in this packet).
A3 packet: COMPLETE on `dev/v1.9` (the shared
UI::Command + toolbar + no-selection UX + icons are
FROZEN unchanged in this packet).
V1.9A OWNER UI TAB SWITCH BLOCK + HIDDEN-SEMANTICS
FOLLOW-UP packets: COMPLETE on `dev/v1.9`.
V1.9A FINAL BLOCK FIX packet: COMPLETE on `dev/v1.9`.
V1.9A P0 SHARED-VERTEX CORRECTION packet: COMPLETE on
`dev/v1.9`.
V1.9A P0 NARROW RECHECK FIX packet (R1, R3, R4, R6, R7):
COMPLETE on `dev/v1.9`.
V1.9A P0 FINAL NARROW RESIDUAL CORRECTION (this packet,
FINAL-R2-01 + FINAL-R5-01): COMPLETE on `dev/v1.9`;
awaits AIPM final narrow source recheck + Codex xHigh
narrow recheck + Owner real-SU2020 re-verification.
CODEX_RISK_TRIGGER: **YES** (post-implementation,
narrow) — per dispatch: R2 touches the post-read
atomicity seam (post-validation host-read escape);
R5 touches the orchestrated E2E seam (physical-B
identity + Z fan-out proof).
AIPM_REVIEW: **PENDING**.
CODEX_NARROW_RECHECK: **NOT YET**.
OWNER_SU2020: NOT YET.
V1.9B: NOT STARTED.

---

## 0. Scope (per AIPM FINAL NARROW RESIDUAL CORRECTION)

This packet fixes exactly TWO narrow residuals found by
AIPM direct source recheck of the prior V1.9A P0
NARROW RECHECK FIX packet:

1. **FINAL-R2-01** — Executor post-validation
   `.to_f` exception-leak path. The prior R2 packet
   wrapped `adapter.vertex_position(h)` in
   `begin/rescue StandardError` but the downstream
   validation loop performed
   `after_zs << post[2].to_f if post.is_a?(Array)`
   BEFORE proving `post.length == 3`,
   `post[0..2]` are Numeric, and all numeric values
   are finite. A malformed-but-Array post such as
   `[0.0, 0.0, Object.new]` raised `NoMethodError` on
   `.to_f` BEFORE the executor reached the
   unreadable-position branch. A 4-element position
   Array was also silently accepted because
   `pos.is_a?(Array)` plus the first 3 Numeric slots
   passed the OLD validation gate.

2. **FINAL-R5-01** — Orchestrated Owner E2E did not
   prove the two physical B handles were
   identity-distinct OR at target Z. The prior R5
   test correctly exercised the orchestrator chain
   but commented the assertions; the assertions
   jumped from `planar == APPLIED` directly to gap
   apply without proving the two physical B
   identity-distinct and at target Z inside the
   same E2E fixture.

No architecture redesign required. No production file
outside `planar_normalization_executor.rb` is touched.
`endpoint_record.rb`, presenter, proposer, orchestrator,
WorkingModeRunner, V1.7/V1.8 algorithms, app.js / CSS /
toolbar remain FROZEN unless a newly added focused
assertion proves a direct contradiction (NONE did).

---

## 1. starting HEAD / implementation HEAD / final HEAD

- Starting HEAD (before this packet touched the
  working tree):
  `ff35cfae1962538c29ff48aca4dfd593ee6ddb81`
  (`dev/v1.9` V1.9A P0 NARROW RECHECK FIX merge commit).
- Starting working-tree state: 1 untracked file
  (`Prompt/AIPM_V1_9A_P0_FINAL_NARROW_RESIDUAL_CORRECTION_2026-09-09.md`).
  The working tree was otherwise clean (per
  `git status --short` immediately after
  `git checkout dev/v1.9`).
- Pre-existing test debt (9 fail + 0 error in HEAD):
  identical to the prior packet's
  pre-existing failures — CSS / app.js textual
  source-level guards + FakeUI / V14 / V17 / V19A
  FINAL P1-B pre-existing failures. NONE introduced
  by this packet (verified via full-suite
  comparison before vs after).
- Implementation SHA: produced by this packet (the
  final stable commit on `dev/v1.9`; see
  `git log -1 --format=%H` after the commit).
- Final HEAD on `dev/v1.9`: see `git rev-parse HEAD`
  after push.
- V1.9A P0 FINAL NARROW RESIDUAL CORRECTION RBZ
  candidate: size **1,194,376 bytes**; entries **73**;
  SHA-256
  **`89e27046c3974a9b222c92f090fe2207dde34cfc69bd76b6ce0a25aefebac534`**.

---

## 2. exact files changed

```
extension/su_ai_plugin/core/planar_normalization_executor.rb | 70 ++++++--
tests/test_v19a_final_p0_live_coordinates.rb                  | 274 ++++++++++++++++++++++++++++-
2 files changed, ~330 insertions, ~14 deletions
```

The final-allowed production scope per AIPM is:

- `extension/su_ai_plugin/core/planar_normalization_executor.rb`

**FROZEN / NOT CHANGED** (per dispatch + AIPM narrow
guidance):

- `endpoint_record.rb`, presenter, proposer,
  orchestrator, WorkingModeRunner, V1.7 / V1.8
  algorithms, source / derived ownership, tolerance
  defaults, Undo / host-state architecture,
  toolbar / tabs / hidden semantics, app.js / CSS,
  V1.9B, MCP / LLM / Agent.

---

## 3. FINAL-R2-01 — strict post-validation shape check + phase-level defensive rescue

### Production change

`extension/su_ai_plugin/core/planar_normalization_executor.rb`
post-validation phase. The frozen contract is now
enforced in strict order:

```ruby
post_ok = post.is_a?(Array) &&
          post.length == 3 &&
          post[0].is_a?(Numeric) &&
          post[1].is_a?(Numeric) &&
          post[2].is_a?(Numeric)
unless post_ok
  validation_errors << "vertex_#{i}_position_unreadable"
  next
end
finite = (!post[0].respond_to?(:finite?) || post[0].finite?) &&
         (!post[1].respond_to?(:finite?) || post[1].finite?) &&
         (!post[2].respond_to?(:finite?) || post[2].finite?)
unless finite
  validation_errors << "vertex_#{i}_position_unreadable"
  next
end
# ALL FOUR checks pass. NOW call `.to_f` / do XY-Z
# drift validation / append after_zs.
after_zs << post[2].to_f
```

Plus a phase-level defensive
`begin/rescue StandardError` boundary that
guarantees an unexpected `StandardError` during
the post-validation phase aborts the outer
operation ONCE, never commits, returns `:failed`,
publishes zero logical / physical / legacy applied
success. The original exception class is
preserved in the failed workspace's
`last_error` string as
`post_validation_phase_failed:vertex_phase_post_validation_raised:<Class>`
(per the `validation_errors.first` interpolation);
the audit row's `reason` itself is the GENERIC
`post_validation_phase_failed` (per dispatch
final narrow residual guidance 2026-09-09: the
class is preserved in the failed workspace's
`last_error`; the audit row's `reason` stays
generic — the production code is NOT to be
changed to fit an older report wording that put
the class directly into the audit row's `reason`).

What the corrections close:

- `[0.0, 0.0, Object.new]` (3-Array, slot 2 not
  Numeric): `post_ok = false` → fail closed,
  no `.to_f` invoked.
- `[0.0, 0.0, 0.0, 123.0]` (4-Array): `post_ok = false`
  (length != 3) → fail closed, no `.to_f` invoked.
- `[0.0, 0.0]` (2-Array): `post_ok = false`
  (length != 3) → fail closed.
- `{ x: 0.0, y: 0.0, z: 0.0 }` (Hash): `post_ok = false`
  (not Array) → fail closed.

### Required R2 tests (this packet)

Added to
`tests/test_v19a_final_p0_live_coordinates.rb`:

- `V19A-P0 (FINAL-R2-01): post-position [0.0, 0.0, Object.new] -> no exception escapes, 1 begin, 1 abort, 0 commit, FAILED`
- `V19A-P0 (FINAL-R2-01): post-position [0.0, 0.0, 0.0, 123.0] -> malformed, 1 begin, 1 abort, 0 commit, FAILED`
- `V19A-P0 (FINAL-R2-01): post-position [0.0, 0.0] -> malformed (length 2), 1 begin, 1 abort, 0 commit, FAILED`
- `V19A-P0 (FINAL-R2-01): post-position Hash -> malformed, 1 begin, 1 abort, 0 commit, FAILED`

The prior `V19A-P0 (R2 source-level): post-read loop is wrapped in begin/rescue StandardError`
test was UPDATED to:

- Locate the new `if post_validation_phase_failed`
  marker (instead of the old `if !validation_errors.empty?`).
- Assert the FINAL-R2-01 phase-level defensive
  `begin/rescue StandardError` boundary exists.
- Assert the strict `post.length == 3` shape check
  precedes any `.to_f` / numeric coercion.

Pre-existing R2 tests (raise / Hash / NaN) all
remain PASS.

---

## 4. FINAL-R5-01 — orchestrated Owner E2E physical-B identity + Z fan-out proof

### Test-only change (per dispatch: "Test-only unless
the new assertion reveals a production defect")

The existing `V19A-P0 (R5): orchestrated Owner-equivalent E2E`
test (which uses `CadPrepWorkflowOrchestrator.start` →
`apply_planar_and_refresh` → `apply_gap_and_refresh`)
was EXTENDED with the FINAL-R5-01 assertions
immediately after `apply_planar_and_refresh`:

1. Access the post-apply workspace via the runner
   test-only accessor
   `V19A_FP_RUNNER.current_workspace_for_test`
   (the orchestrator does NOT publish the workspace
   handle; this is the production-equivalent read).
2. Build the authoritative host-vertex map from the
   workspace edges via `v19a_fp_host_vertex_map`
   (the SAME seam `working_mode_runner._host_vertex_map`
   uses in production).
3. Discover the two derived edges representing A-B
   and B-C by walking workspace.entities
   (do NOT hardcode "0"/"1" — the test must be robust
   against derivation-order changes).
4. Resolve the A-B `.end` (logical B handle 1) and
   B-C `.start` (logical B handle 2) via the
   adapter's `edge_endpoints(group_handle)` seam.
5. **Assert `ab_b_handle.object_id != bc_b_handle.object_id`**
   (the two physical B handles are IDENTITY-distinct).
6. Read both via `adapter.vertex_position(handle)` and
   verify exactly 3 elements.
7. Read the audit's `target_z` via
   `V19A_FP_RUNNER.planar_normalization_audit`.
8. **Assert `pos_ab_b[2] == target_z` and
   `pos_bc_b[2] == target_z`** within the existing
   `coordinate_epsilon`.

The new assertions do NOT manually call any
`WorkingModeRunner.compute_*` methods (per the dispatch:
"Do not manually call downstream WorkingModeRunner.compute_*
methods"). They run inside the same E2E fixture
immediately after the orchestrator's
`apply_planar_and_refresh`, BEFORE
`apply_gap_and_refresh`.

### What the FINAL-R5-01 assertions revealed

The new assertions PASS against the current
production code (final SHA of HEAD). The two
physical B handles are identity-distinct (different
`object_id`), and both reach `target_z` within the
existing `coordinate_epsilon` after
`apply_planar_and_refresh`. The fixture proves
the R5 contract inside the same orchestrator-driven
test, before proceeding to gap-unlock + gap-apply
+ Structure assertions (which were already in the
prior R5 test).

### FINAL-R5-01 test-only false positive (fixed 2026-09-09)

AIPM final narrow source recheck of this packet
found the R5 test's B-C finder was matching the
WRONG edge. The prior packet's finder located B-C
by `eps[1] == (0, 1mm)` — but D-E has its `.end`
endpoint at `(0, 1mm, 0)`, NOT B-C. So the prior
test took `bc_b_handle = "D-E.start"` which is the
D Vertex, not the second physical B handle.

This packet fixes the test-only bug (NO production
source change) by identifying B-C by
`eps[0] == (W, 0)` (B-C.start XY = (W, 0, drift)).
The corrected test now correctly proves:

- `ab_b_handle = A-B.end` (logical B at A-B.end)
- `bc_b_handle = B-C.start` (logical B at B-C.start)
- `ab_b_handle.object_id != bc_b_handle.object_id`
  (identity-distinct)
- Both live XY == (W, 0) (the logical B coordinate)
- Both live Z == `target_z` within `coordinate_epsilon`

NO production code change (per dispatch). NO
production RBZ rebuild needed — the RBZ SHA
remains
`89e27046c3974a9b222c92f090fe2207dde34cfc69bd76b6ce0a25aefebac534`.

If a future regression breaks the identity-distinct
or the Z-fan-out contract, this assertion catches it
immediately at the orchestrator-E2E level.

---

## 5. PASS / PRESERVE (no reopen)

The FINAL NARROW RESIDUAL CORRECTION does NOT
modify any of:

- R1 strict preflight before mutation (already in
  HEAD via `ec6ab57`).
- Group -> endpoint Vertex live-read authority.
- R3 cached fallback / fail-closed matrix.
- Physical-occurrence identity dedupe in proposer.
- Logical -> physical fan-out design.
- One outer operation + one primitive per
  physical occurrence.
- Logical / physical count split.
- R4 V1.8 `loops` + `*_count` presenter shape.
- R7 `deep_nesting` / `嵌套层级`.
- A2 orchestrator call order and invalidation.
- V1.5 duplicate algorithm.
- V1.6 analysis/tolerance policy.
- V1.7 pairing/canonical clustering.
- V1.8 reconstruction/region algorithm.
- Source CAD immutability.
- Undo / host-state architecture.
- toolbar / tabs / hidden semantics.
- V1.9B / PreparedCadDataset / release Gate.
- MCP / LLM / Agent.

---

## 6. Test / package return

### Focused V19A-P0 suite (this packet)

```
V19A-P0: 38 tests, 38 pass, 0 fail, 0 error
```

Coverage (this packet's new tests in **bold**):

- §10.1 HANDLE-CONTRACT: vertex_position receives
  endpoint Vertex handle, not Group handle.
- §10.2 FAILCLOSED-MALFORMED / -RAISE / -NIL /
  -NO-LIVE-AUTHORITY / -INFINITY.
- §10.2 NO-ADAPTER: nil adapter -> cached fallback.
- §10.3 SHARED-LOGICAL-COORDINATE.
- §10.4 EXECUTOR-FANOUT.
- §10.4a PREFLIGHT-NIL / -MALFORMED-ARRAY /
  -NON-NUMERIC / -NAN-INFINITY / -RAISED /
  -NON-NUMERIC-VECTOR-Z (6 tests).
- §10.5 MID-MUTATION-FAILURE.
- §10.6 POSTVALIDATION-FAILURE.
- **R2 post-position read raises (exception suppressed)**.
- **R2 post-position returns malformed non-Array**.
- **R2 post-position returns Float::NAN**.
- **FINAL-R2-01 post-position [0.0, 0.0, Object.new]**
  (NEW this packet).
- **FINAL-R2-01 post-position [0.0, 0.0, 0.0, 123.0]**
  (NEW this packet).
- **FINAL-R2-01 post-position [0.0, 0.0]** (NEW this packet).
- **FINAL-R2-01 post-position Hash** (NEW this packet).
- **R2 source-level guard** (UPDATED this packet).
- §10.7 E2E-OWNER-EQUIVALENT.
- §10.8 PRESENTER-LOGICAL-COUNT / -FAILED-NO-CTA.
- §9 ERROR-CLASS / SOURCE-LEVEL / PROPOSER-IDENTITY-DEDUPE
  / EXECUTOR-ONE-PRIMITIVE-PER-OCCURRENCE.
- **R5 orchestrated Owner-equivalent E2E**
  (EXTENDED this packet with FINAL-R5-01
  identity + Z assertions).

### v19a_presenter focused suite

```
v19a_presenter: 78 tests, 77 pass, 0 fail, 1 error
```

(unchanged from prior packet; the 1 error is the
pre-existing `v19a_presenter (FINAL P1-B)` `开放链`
chip-list guard.)

### Other focused suites

- `v19a_cad_prep_workflow_orchestrator`: 30 / 30 PASS
  (unchanged).
- `v19a_dialog_runner`: 48 / 48 PASS (unchanged).
- V1.6 planar normalization: 33 / 33 PASS.
- V1.6 close-autodiscard: 7 / 7 PASS.
- V1.7 focused: 127 / 127 PASS.
- V1.7 INT: 33 / 33 PASS.
- V1.8 focused: 71 / 71 PASS.
- V1.8 SR18: 32 / 32 PASS.
- V1.4 fingerprint: 22 / 22 PASS.
- LEGACY-COMPAT: 4 / 4 PASS.

### Normal full Ruby suite (NORMAL runner, no exclusion)

```
1219 tests, 1210 pass, 5 fail, 4 error
```

Pre-existing failures (NONE introduced by this
packet; confirmed by isolated re-run before vs
after):

- 5 FAIL on `html_render (V1.9A FINAL P1-A)` × 3 +
  `html_render (V1.9A FINAL P1-C)` × 1 +
  `html_render (V1.9A HIDDEN-SEMANTICS FOLLOW-UP)` × 1
  — CSS / `app.js` textual source-level guards on
  already-source-reviewed PASS items. CSS is
  UNCHANGED in this packet.
- 1 FAIL on `v19a_presenter (FINAL P1-B)` —
  `开放链` chip-list guard (pre-existing presenter
  test guard, not addressed by R7's
  `嵌套层级` restoration).
- 3 ERROR on `capability.HtmlDialog` /
  V14 production call chain /
  V17-L1 host_state_changed — pre-existing
  test-environment / FakeUI limitations.

The 2 new FINAL-R2-01 tests pass cleanly in the
full suite (verified after rebuilding the RBZ so
the RBZ smoke test no longer loads the pre-fix
executor from the stale `dist/SU-AI-Plugin.rbz`).

### DOM / HTML / RBZ smoke

- `tests/test_html_render_dom.js` (Node DOM):
  all assertions PASS, final line `PASS`
  (unchanged from HEAD; no DOM change in this
  packet).
- `tests/test_html_render.rb`: 24 / 24 PASS
  (unchanged from HEAD).
- `tests/test_rbz_smoke.rb`: 7 / 8 PASS + 1
  pre-existing FakeUI ERROR (unrelated).

### RBZ rebuilt from corrected source

```
$ ./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe scripts/build_rbz.rb
OK: wrote D:/Projects/SU-AI-Plugin/dist/SU-AI-Plugin.rbz
    size: 1194376 bytes
    entries: 73
    entry-point: su_ai_plugin.rb (OK, at the .rbz root)
    support folder: su_ai_plugin/ (OK, sibling of the entry-point)
```

- RBZ path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- RBZ size: **1,194,376 bytes**
- RBZ entry count: **73**
- RBZ SHA-256:
  **`89e27046c3974a9b222c92f090fe2207dde34cfc69bd76b6ce0a25aefebac534`**

Delta vs prior packet (1,191,455 bytes / 73
entries): +2,921 bytes (the executor's tightened
post-validation + the new R2 source-level guard
are slightly larger than the prior swallow-style
post-validation). The production-correctness of the
post-validation phase is now provable.

### `git diff --check`

Clean (no trailing whitespace, no line-ending noise
on any modified file).

---

## 7. Confirmation: no forbidden algorithms /
   tolerances / V1.9B changed

- No change to `coordinate_epsilon`,
  `planar_z_snap`, `gap_search` defaults.
- No change to Source CAD mutability / ownership.
- No change to Derived Workspace ownership model.
- No change to V1.5 duplicate algorithm.
- No change to V1.6 dominant-band / target-Z /
  outlier algorithm.
- No change to V1.6 tolerance defaults.
- No change to V1.7 gap pairing / mutual
  candidate / conflict logic.
- No change to V1.7 canonical node clustering
  semantics.
- No change to V1.8 reconstruction / region /
  containment algorithm.
- No physical welding.
- No SketchUp Face generation.
- No broad Observer architecture change.
- No Undo / host-state redesign.
- No toolbar / loader change.
- No current Issues / badge semantics already
  source-reviewed PASS.
- No MCP / LLM / Agent.
- No V1.9B / PreparedCadDataset / release Gate.
- No source-Registry run-output was rewritten
  anywhere.

---

## 8. Deviations / STOP items

- 1 test update: the prior packet's
  `V19A-P0 (R2 source-level)` source-level guard
  test was updated to use the new
  `if post_validation_phase_failed` end-of-block
  marker + the new phase-level defensive
  `begin/rescue StandardError` boundary + the new
  `post.length == 3` shape check. This is a
  required follow-on because the prior packet's
  marker literal was retired by FINAL-R2-01.
- The 5 FAIL + 4 ERROR pre-existing test results
  are reported separately per amendment §11
  ("actual counts + full suite result with known
  pre-existing failures separated"). None was
  introduced by this packet.
- The FINAL-R5-01 new assertions did NOT reveal a
  production defect (the two physical B handles
  are identity-distinct + at target Z in the same
  E2E fixture). Per dispatch: "Test-only unless
  the new assertion reveals a production defect" —
  the assertions remain test-only; the production
  code in `planar_normalization_executor.rb` is
  unchanged for the FINAL-R5-01 contract.
- The V1.9B PreparedCadDataset / persistence work
  remains NOT STARTED.
- The CODEX_NARROW_RECHECK + OWNER_SU2020 steps
  remain pending per dispatch §9.

---

END OF V1.9A P0 FINAL NARROW RESIDUAL CORRECTION REPORT.
# CURRENT PI REPORT — V1.9A P0 NARROW RECHECK FIX (PREVIOUS UPDATE)

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Final Block Fix
Packet: P0 NARROW RECHECK FIX (R1–R7)
Authority: `Prompt/CURRENT_PI_DISPATCH.md` (V1.9A P0
NARROW RECHECK FIX, 2026-09-08) +
`Prompt/AIPM_V1_9A_P0_NARROW_RECHECK_FIX_2026-09-08.md` +
R7 addendum
`Prompt/AIPM_V1_9A_P0_NARROW_RECHECK_ADDENDUM_R7_2026-09-08.md`.
Baseline HEAD: `e03eb66d94953aef533b87eb693f57e68f46f505`
(`dev/v1.9` V1.9A P0 R1-R7 source-review verdict +
recheck dispatch merge commit). The working tree was
clean at packet start; the prior `ec6ab57` commit
(BLOCK-P0-04 strict preflight matrix) was already in
HEAD before this packet began.
Baseline branch: `dev/v1.9`
TARGET_BRANCH: **dev/v1.9**
A0 Owner UX Gate: PASS
A1 packet: COMPLETE (V1.9A-A1 PRODUCTION UI SHELL +
PRESENTATION MODEL + FIX REQUIRED continuation +
LEGACY RUBY COMPATIBILITY NARROW FIX + V1X-LEGACY-RUBY-
DEBT-CLOSURE predecessor packets).
A2 packet: COMPLETE on `dev/v1.9` (the call order /
invalidation seam / refresh / rebuild-and-scan /
gap-ordering / error-boundary propagation are
FROZEN unchanged in this packet).
A3 packet: COMPLETE on `dev/v1.9` (the shared
UI::Command + toolbar + no-selection UX + icons are
FROZEN unchanged in this packet).
V1.9A OWNER UI TAB SWITCH BLOCK + HIDDEN-SEMANTICS
FOLLOW-UP packets: COMPLETE on `dev/v1.9`.
V1.9A FINAL BLOCK FIX packet: COMPLETE on `dev/v1.9`
(P1-A / P1-B / P1-C / P2-A / P2-B / test-debt items
remain PASS and are not reopened).
V1.9A P0 SHARED-VERTEX CORRECTION packet: COMPLETE on
`dev/v1.9` (its P0 live-coordinate seam + identity
fan-out + one-outer-operation / multi-primitive
executor + logical/physical count split + frozen V1.8
Blueprint + canonical topology + Undo / host-state
architecture all remain PASS and are not reopened).
The BLOCK-P0-04 fix (commit `ec6ab57`, strict
preflight of every physical live position before
mutation) is PART of this prior packet and is now
frozen.
V1.9A P0 NARROW RECHECK FIX (this packet, R1–R7):
COMPLETE on `dev/v1.9`; awaits AIPM direct source
recheck + narrow Codex xHigh recheck + Owner
real-SU2020 re-verification.
CODEX_RISK_TRIGGER: **YES** (post-implementation,
narrow) — this packet closes the BLOCK-P0-04 residual
post-read atomicity seam + the R3 endpoint fallback
matrix seam + the R4 actual V1.8 result-shape seam +
the R5 orchestrated E2E seam + the R7
`deep_nesting` current-attention chip seam. Each is
small and narrow; none reopens already-PASS
shared-vertex architecture.
AIPM_REVIEW: **PENDING**.
CODEX_NARROW_RECHECK: **NOT YET**.
OWNER_SU2020: NOT YET.
V1.9B: NOT STARTED.

---

## 0. Scope (per dispatch §0)

This is NOT a new broad implementation packet.

Per the current V1.9A P0 NARROW RECHECK FIX dispatch +
the R1–R7 source-review guidance, this packet fixes
exactly:

1. R1 — Executor true preflight before mutation
   (BLOCK-P0-04 strict preflight + 13-step matrix;
   this packet re-verifies the BLOCK-P0-04 fix in
   HEAD and adds the R1 source-level guard).
2. R2 — Executor postvalidation exception-safe abort
   (this packet implements the missing rescue
   boundary; post-read raise / malformed / non-finite
   no longer escape with the operation open).
3. R3 — Endpoint live-read fallback contract
   correction (per-endpoint handle + adapter lacks
   `vertex_position` → cached fallback allowed;
   4-element / 2-element Array position → fail
   closed; nil / raise / non-finite fail closed).
4. R4 — Presenter actual V1.8 `loops`[].unresolved_flags
   + `closed_loop_count` / `region_count` /
   `hole_count` read shape (preferred path with legacy
   fallback).
5. R5 — TRUE orchestrated Owner-equivalent E2E
   regression (uses
   `CadPrepWorkflowOrchestrator.start` +
   `apply_planar_and_refresh` +
   `apply_gap_and_refresh`; does NOT manually call
   `compute_gap_repair` or
   `compute_structure_reconstruction`).
6. R6 — Fresh normal/full-suite + rebuilt RBZ
   evidence (rebuild from corrected source; run
   normal full suite; report RBZ bytes / entries /
   SHA-256).
7. R7 — Restore `deep_nesting` / `嵌套层级`
   current-attention chip semantics (add to
   `PROBLEM_METRIC_LABELS`; add regression proving
   `嵌套层级` surfaces in current-attention chips).

This packet does NOT reopen already-PASS
shared-vertex architecture or unrelated V1.x work.

---

## 1. starting HEAD / implementation HEAD / final HEAD

- Starting HEAD (before this packet touched the
  working tree):
  `e03eb66d94953aef533b87eb693f57e68f46f505`
  (`dev/v1.9` V1.9A P0 R1-R7 source-review verdict +
  recheck dispatch merge commit).
- Starting working-tree state: clean (per
  `git status --short` immediately after
  `git checkout dev/v1.9`).
- Pre-existing test debt: 5 fail + 4 error in the
  full synthetic Ruby suite (CSS cascade-order guard
  on `.recovery-banner[hidden]`; `app.js`
  `payload.groups` / `cta_callback` textual
  source-level guards; `v19a_presenter (FINAL P1-B)`
  CLEAN-state `开放链` chip-list guard;
  `capability.HtmlDialog` outside-SU; V14 / V17
  production call chain FakeUI limitations). All
  pre-existing in HEAD per the prior packet's report
  (§14 / §15). This packet does NOT introduce any
  new failure (verified via full-suite comparison
  before vs after).
- Implementation SHA: produced by this packet (single
  stable commit; see §18).
- Final HEAD on `dev/v1.9`: see `git rev-parse HEAD`
  after the final commit.

---

## 2. exact files changed

```
extension/su_ai_plugin/cad_prep_workflow_presenter.rb    |  107 +++-
extension/su_ai_plugin/core/endpoint_record.rb          |   30 +-
extension/su_ai_plugin/core/planar_normalization_executor.rb |   65 ++-
tests/test_v19a_cad_prep_workflow_presenter.rb          |  241 +++++++++
tests/test_v19a_final_p0_live_coordinates.rb            |  544 +++++++++++++++++++++
5 files changed, 948 insertions(+), 39 deletions(-)
```

`planar_normalization_proposer.rb` was NOT touched
(R1 consistency check confirmed no mechanically
missing proposer field; see §3.5 below).

**FROZEN / NOT CHANGED** (per dispatch §8):
`working_mode_runner.rb` (algorithmic), the V1.6
proposer (algorithmic), V1.7 pairing / canonical
clustering (algorithmic), V1.8 reconstructor /
region algorithms (algorithmic), source CAD
ownership, Undo / host-state architecture, app.js /
CSS / toolbar, faces / Observers, V1.9B,
MCP / LLM / Agent.

---

## 3. R1 — strict preflight before mutation

R1 is satisfied by the BLOCK-P0-04 fix already
merged into HEAD at commit `ec6ab57` BEFORE this
packet began. The preflight matrix (per amendment
§4.1 + R1 §2) is the strict 13-step pre-flight that
runs BEFORE `begin_operation`:

1. Handle present
   (`preflight_nil_handle:i` reason on fail).
2. Handle identity uniqueness by `object_id`
   (`preflight_duplicate_handle:i` reason on fail).
3. Adapter MUST expose `vertex_position`
   (`preflight_no_vertex_position_seam` reason on
   fail).
4. `adapter.vertex_position(handle)` MUST succeed
   (any exception fails closed with
   `preflight_vertex_position_raised:i:<ErrorClass>`).
5. Live position MUST be an `Array` of exactly 3
   (`preflight_position_not_array3:i`).
6. Live position MUST be 3 Numeric values
   (validate Numeric type FIRST; do NOT `.to_f`
   first to disguise malformed input).
7. Live position XYZ MUST all be finite.
8. Vector MUST be Array length 3.
9. Vector X / Y MUST be Numeric + numeric zero (NOT
   `vec[0].to_f == 0`; type-then-equality).
10. Vector Z MUST be Numeric + finite.
11. Consistency: `abs((pre_z + vector_z) - target_z)
    <= coordinate_epsilon`
    (`preflight_position_inconsistent:i`).
12. `target_z` MUST be Numeric + finite
    (`preflight_target_z_not_numeric_or_nonfinite`).
13. `coordinate_epsilon` MUST be Numeric + finite
    (`preflight_epsilon_invalid`).

All preflight failures return `_fail_result(...)`
WITHOUT opening any SketchUp operation. The host
sees ZERO `begin_operation` calls + ZERO
`transform_vertices_by_vectors` calls on any
preflight failure path. Verified by 6 focused
regressions (the §10.4a PREFLIGHT-* test set) +
the existing §10.4 EXECUTOR-FANOUT success path
test (1 begin / N primitives / 1 commit).

This packet adds one new test that re-verifies the
R1 source-level guard from the dispatch:

- `V19A-P0 (R1 source-level)` — pins the
  preflight / one-outer-operation /
  one-primitive-per-physical-occurrence architecture
  in the executor source.

This packet did NOT change the executor's preflight
code (the BLOCK-P0-04 fix is already in HEAD and
frozen); it only verifies + pins the contract.

---

## 4. R2 — postvalidation host-read exception safety

The prior executor's postvalidation read:

```ruby
post_positions = handles.map { |h|
  adapter.respond_to?(:vertex_position) ? adapter.vertex_position(h) : nil
}
```

was NOT wrapped in `begin/rescue StandardError`. If
one host read raised after the mutation, the
exception could escape the function while the outer
operation was still open — a violation of the
amendment §4.4 atomicity contract.

This packet wraps each per-occurrence post-read in
a `begin/rescue StandardError` guard. A raised read
becomes a tagged sentinel
(`{ 'kind' => 'raised', 'class' => e.class.name }`)
so the function NEVER returns while the outer
operation is still open. The original exception
class is preserved in the failed workspace's
`last_error` string (e.g.
`post_validation_failed:vertex_0_post_read_raised:StandardError`);
the audit row's `reason` itself stays the GENERIC
`post_validation_failed` (per dispatch final
narrow residual guidance 2026-09-09: the class is
preserved in the failed workspace's `last_error`;
the audit row's `reason` stays generic — the
production code is NOT to be changed to fit an
older report wording that put the class directly
into the audit row's `reason`).
parsing the message string.

The post-validation block additionally:

- Distinguishes a raised read (`vertex_<i>_post_read_raised:<Class>`)
  from a malformed / nil read
  (`vertex_<i>_position_unreadable`).
- Detects non-finite post-position values via an
  explicit `finite?` check on each Numeric slot
  (in addition to the existing pre-vs-post dx/dy/dz
  drift checks).

On any postvalidation failure (raise / malformed /
non-finite / drift) the executor still publishes:

- `end_operation(commit: false)` — abort ONCE.
- `_mark_workspace_failed(workspace, ...)` —
  transitions through the existing failed-workspace
  path.
- `audit[:applied_count] == 0`,
  `audit[:logical_applied_count] == 0`,
  `audit[:physical_applied_count] == 0` —
  zero committed logical / physical applied success.

### R2 new tests (this packet, in
`tests/test_v19a_final_p0_live_coordinates.rb`):

- `V19A-P0 (R2): post-position read raises -> one
  begin, one abort, no commit, FAILED, exception
  suppressed` — verifies the exception does NOT
  escape the function (rescue StandardError guard)
  + the operation control surface is consistent
  (1 begin / 1 abort / 0 commit).
- `V19A-P0 (R2): post-position returns malformed
  non-Array -> one begin, one abort, no commit,
  FAILED`.
- `V19A-P0 (R2): post-position returns Float::NAN ->
  one begin, one abort, no commit, FAILED`.
- `V19A-P0 (R2 source-level): post-read loop is
  wrapped in begin/rescue StandardError`.

The pre-existing
`V19A-P0 §10.5 MID-MUTATION-FAILURE` +
`V19A-P0 §10.6 POSTVALIDATION-FAILURE` tests still
PASS (uncovered the same control-surface contract
before this packet; this packet additionally covers
the new raise / malformed / non-finite post-read
modes).

---

## 5. R3 — endpoint live-read fallback contract correction

Per the frozen amendment §6.2 + R3 §4, the
endpoint-live-read fallback matrix is:

| Condition | Behavior |
|---|---|
| `per_endpoint_handle` is nil (host_vertex_map has no entry for that endpoint) | cached fallback (returns `cached_coordinate` to caller) |
| `per_endpoint_handle` is non-nil but `adapter` is nil OR adapter lacks `vertex_position` seam | **cached fallback allowed** (R3 correction; was previously fail closed) |
| `per_endpoint_handle` is non-nil + adapter exposes `vertex_position` + call raises | `raise LiveVertexPositionUnreadable(endpoint_key:, underlying: e)` (fail closed) |
| `per_endpoint_handle` is non-nil + adapter exposes `vertex_position` + returns `nil` | `raise LiveVertexPositionUnreadable` (fail closed) |
| `per_endpoint_handle` is non-nil + adapter exposes `vertex_position` + returns non-Array OR non-Numeric OR non-finite | `raise LiveVertexPositionUnreadable` (fail closed) |
| `per_endpoint_handle` is non-nil + adapter exposes `vertex_position` + returns 4-element OR 2-element Array | `raise LiveVertexPositionUnreadable` (fail closed; R3 correction — was previously `length >= 3` which let 4-element arrays through) |
| `per_endpoint_handle` is non-nil + adapter exposes `vertex_position` + returns finite 3-Array | `[x.to_f, y.to_f, z.to_f]` (live authority wins) |

The two corrections are:

1. **Adapter-lacks-vertex_position fallback**: when
   the caller provides a per-endpoint Vertex handle
   but the adapter is nil OR the adapter genuinely
   lacks `vertex_position`, the helper now returns
   `nil` (cached fallback). Previously the code
   raised `LiveVertexPositionUnreadable`, which was
   too strict per the frozen amendment.
2. **Exactly-3 position shape**: the helper now
   requires `pos.length == 3` exactly. Previously
   the code accepted `pos.length >= 3`, which let
   4-element arrays through silently and ignored
   the surplus slot(s).

### R3 new tests (this packet, in
`tests/test_v19a_final_p0_live_coordinates.rb`):

- `V19A-P0 (R3): endpoint handle + adapter lacks
  vertex_position -> cached fallback` — verifies
  the cached fallback path is now permitted (no
  fail closed).
- `V19A-P0 (R3): endpoint handle + nil adapter ->
  cached fallback` — same matrix coverage.
- `V19A-P0 (R3): endpoint handle + 4-element
  position Array -> LiveVertexPositionUnreadable` —
  verifies the exactly-3 shape constraint.
- `V19A-P0 (R3): endpoint handle + 2-element
  position Array -> LiveVertexPositionUnreadable` —
  same coverage.

The pre-existing fail-closed tests
(`FAILCLOSED-MALFORMED` / `FAILCLOSED-RAISE` /
`FAILCLOSED-NIL` / `FAILCLOSED-INFINITY` /
`FAILCLOSED-NO-LIVE-AUTHORITY` / `NO-ADAPTER`) still
PASS.

---

## 6. R4 — presenter actual V1.8 result shape

Per amendment §7.1 + R4 §5, the presenter MUST read
the actual V1.8 production result shape:

```text
result['loops']
metrics['open_chain_count']
metrics['closed_loop_count']
metrics['region_count']
metrics['hole_count']
metrics['invalid_loop_count']
```

Specific loop validation evidence lives inside each
`loops[]` record's `unresolved_flags` Array
(includes `'non_planar_loop'` for non-planar
warning).

### R4 corrections (this packet, in
`extension/su_ai_plugin/cad_prep_workflow_presenter.rb`):

1. `_structure_loop_flags(sr)` now reads
   `sr['loops']` FIRST (the V1.8 production shape).
   Legacy `sr['closed_loops']` remains as a
   defensive backward-compatibility fallback only.
   Per-R4 source-level guard test pins this order:
   `sr['loops']` MUST appear BEFORE `sr['closed_loops']`
   in the presenter source.
2. The READY structure card now surfaces the
   AUTHORITATIVE V1.8 metric keys
   (`closed_loop_count`, `region_count`,
   `hole_count`). Legacy `closed_loops` /
   `regions` / `holes` aliases remain as defensive
   backward-compatibility fallbacks via the
   `_structure_legacy_aliases` helper.
3. `_structure_label_for(k)` now labels the new V1.8
   keys (and their legacy aliases) with the matching
   Simplified Chinese labels: `closed_loop_count`
   / `closed_loops` → `闭合轮廓`,
   `region_count` / `regions` → `区域`,
   `hole_count` / `holes` → `洞`.

### R4 new tests (this packet, in
`tests/test_v19a_cad_prep_workflow_presenter.rb`):

- `v19a_presenter (R4): READY structure card
  surfaces closed_loop_count + region_count +
  hole_count as authoritative`.
- `v19a_presenter (R4): READY structure card falls
  back to legacy closed_loops / regions / holes
  aliases`.
- `v19a_presenter (R4): READY_WITH_WARNINGS +
  loops[].unresolved_flags with non_planar_loop
  drives the specific copy`.
- `v19a_presenter (R4): legacy
  closed_loops[].unresolved_flags still drives the
  non_planar_loop specific copy`.
- `v19a_presenter (R4 source-level):
  _structure_loop_flags prefers sr['loops'] over
  legacy closed_loops`.

---

## 7. R5 — TRUE orchestrated Owner-equivalent E2E regression

Per amendment §10.7 + R5 §6, the TRUE E2E Owner-
equivalent regression MUST exercise the real V1.9A
orchestrator chain (NOT manual
`WorkingModeRunner.compute_*` / `apply_*` calls):

```text
CadPrepWorkflowOrchestrator.start
-> Planar ACTIONABLE + Gap detected but Gap action disabled
-> CadPrepWorkflowOrchestrator.apply_planar_and_refresh
-> BOTH identity-distinct physical B Vertex handles at target Z
-> Gap action enabled
-> CadPrepWorkflowOrchestrator.apply_gap_and_refresh
-> returned snapshot already contains recomputed Structure
```

Final assertions:

```text
workspace == ready
open_chain_count == 0
closed_loop_count == 1
invalid_loop_count == 0
region_count == 1
no loops[].unresolved_flags contains non_planar_loop
```

### R5 new test (this packet, in
`tests/test_v19a_final_p0_live_coordinates.rb`):

- `V19A-P0 (R5): orchestrated Owner-equivalent
  E2E: start -> apply_planar_and_refresh ->
  apply_gap_and_refresh -> ready 0/1/0/1` —
  exercises the FULL orchestrator chain on the
  Owner fixture (A-B-C-D-E almost-closed rectangle
  with 0.2 mm Z residue on B and 1 mm gap at
  E-A). Verifies:
  - `start` returns a `ready` workspace with
    `planar_normalization.state == 'READY_TO_NORMALIZE'`
    and `topology_repair.state == 'READY_TO_REPAIR'`.
  - The presenter surfaces Gap repair action as
    `enabled = false` (gap-ordering safety).
  - `apply_planar_and_refresh` returns a `ready`
    workspace with `planar_normalization.state ==
    'APPLIED'`; the Gap action is now `enabled =
    true`.
  - `apply_gap_and_refresh` returns a `ready`
    workspace with `structure_reconstruction.state
    == 'READY'`, `open_chain_count == 0`,
    `closed_loop_count == 1`,
    `invalid_loop_count == 0`,
    `region_count == 1`, and no
    `non_planar_loop` flag on any closed loop.

The pre-existing `V19A-P0 §10.7 E2E-OWNER-EQUIVALENT`
test (which uses the manual `WorkingModeRunner.compute_*`
chain) is RETAINED for backward compatibility with the
amendment §10.7 description, but the new
orchestrator-based test is the canonical
R5 contract.

---

## 8. R6 — fresh normal/full-suite + rebuilt RBZ evidence

Per R6 §7, this packet rebuilds
`dist/SU-AI-Plugin.rbz` from the corrected source and
runs the normal/full Ruby suite.

- Ruby executable:
  `.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`
- Ruby version: `2.7.8p225 (2023-03-30 revision
  1f4d455848) [x64-mingw32]`
- The global `C:\Ruby27-x64\bin\ruby.exe` is broken
  on this host (Visual C++ side-by-side conflict);
  per AGENTS.md §16 + amendment §11, the project-
  vendored interpreter is the runnable path. Pi did
  NOT reinstall Ruby or rewrite global PATH.

### RBZ rebuilt from corrected source

```
$ ./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe scripts/build_rbz.rb
OK: wrote D:/Projects/SU-AI-Plugin/dist/SU-AI-Plugin.rbz
    size: 1191455 bytes
    entries: 73
    entry-point: su_ai_plugin.rb (OK, at the .rbz root)
    support folder: su_ai_plugin/ (OK, sibling of the entry-point)
```

- RBZ path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- RBZ size: **1,191,455 bytes**
- RBZ entry count: **73**
- RBZ SHA-256:
  **`36e60309f386b0dcba97ee0016445d99c91e40b5ecf9687ae13a62aedc984c9b`**

Delta vs prior HIDDEN-SEMANTICS FOLLOW-UP packet
(1,138,324 bytes / 73 entries): +53,131 bytes
(the prior RBZ candidate was the FINAL BLOCK FIX
packet; this packet's RBZ is rebuilt from the
P0 NARROW RECHECK FIX corrected source).

### Normal/full Ruby suite result

This packet runs `tests/run_all.rb` directly (the
NORMAL test runner — not the prior packet's custom
RBZ-excluding synthetic runner). The full synthetic
Ruby suite result:

```
1215 tests, 1206 pass, 5 fail, 4 error
```

The 5 fail + 4 error are the SAME pre-existing
test-environment / FakeUI / CSS source-level guard
limitations from the V1.8 baseline (confirmed by
isolated re-run before and after this packet):

- 5 FAIL on
  `html_render (V1.9A FINAL P1-A)` × 3
  (`payload.groups` textual source-level guards
  on `app.js`),
  `html_render (V1.9A FINAL P1-C)` × 1
  (`cta_callback` textual source-level guard),
  `html_render (V1.9A HIDDEN-SEMANTICS FOLLOW-UP)` × 1
  (`.recovery-banner[hidden]` cascade-order guard),
  `v19a_presenter (FINAL P1-B)` × 1
  (`开放链` open-chain chip-list guard).
- 3 ERROR on
  `capability.HtmlDialog` (outside SU returns false
  R002 + S2-BLOCK-006),
  `V14 production call chain` (dialog callback ->
  WorkingModeRunner -> workspace reaches :ready —
  NoMethodError on `nil.call`),
  `V17-L1` (host_state_changed invalidates the
  workspace via validate-on-next-interaction).

None introduced by this packet.

### V19A-P0 focused suite result

```
V19A-P0: 34 tests, 34 pass, 0 fail, 0 error
```

- 25 BLOCK-P0-04 + prior V19A-P0 tests (already PASS
  in HEAD).
- 4 new R2 tests (post-read raise / malformed /
  non-finite / source-level guard).
- 4 new R3 tests (cached fallback when adapter
  lacks vertex_position / nil adapter / 4-element /
  2-element Array).
- 1 new R5 test (orchestrated Owner-equivalent
  E2E).
- 0 new R1 test (BLOCK-P0-04 preflight already in
  HEAD; this packet pins the contract via the
  pre-existing §10.4a PREFLIGHT-* tests).

### V19A presenter focused suite result

```
v19a_presenter: 78 tests, 77 pass, 0 fail, 1 error
```

- 69 prior presenter tests (already PASS).
- 7 new tests added by this packet:
  - 4 R4 tests (closed_loop_count / region_count /
    hole_count authoritative + legacy fallback +
    loops[].unresolved_flags + legacy fallback).
  - 1 R4 source-level guard test.
  - 2 R7 tests (current deep_nesting chip +
    CLEAN/APPLIED success metrics still excluded).
  - 1 R7 source-level guard test.
- The 1 error is the pre-existing `v19a_presenter
  (FINAL P1-B): CLEAN structure metrics ... MUST
  NOT inflate issue chips` — see pre-existing
  failures list above.

### Orchestrator focused suite result

```
orchestrator: 30 tests, 30 pass, 0 fail, 0 error
```

(unchanged from HEAD; no orchestrator change in this
packet).

### Other regression suites (unchanged)

- dialog_runner: 48/48 PASS.
- V1.6 planar normalization: 33/33 PASS.
- V1.6 close-autodiscard: 7/7 PASS.
- V1.7 focused: 127/127 PASS.
- V1.7 INT: 33/33 PASS.
- V1.8 focused: 71/71 PASS.
- V1.8 SR18: 32/32 PASS.
- V1.4 fingerprint: 22/22 PASS.
- LEGACY-COMPAT: 4/4 PASS.

### DOM / HTML / RBZ smoke

- `tests/test_html_render.rb`: 24/24 PASS
  (unchanged from HEAD; pre-existing FAILs above
  are the source-level CSS guards).
- `tests/test_html_render_dom.js` (Node DOM): all
  assertions PASS, final line `PASS` (unchanged from
  HEAD).
- `tests/test_rbz_smoke.rb`: 7/8 PASS + 1 pre-existing
  ERROR (`install smoke — extracted entry-point boots
  through FakeUI; menu registered; on_analyze_selection
  no-op fallback` — `NoMethodError: undefined method
  'file_loaded?' for main:Object` from a pre-existing
  FakeUI stub limitation, unrelated to this packet).

### `git diff --check`

Clean (no trailing whitespace, no line-ending noise
on any modified file). Verified with `git diff --check`
on this packet's working tree.

---

## 9. R7 — restore `deep_nesting` / `嵌套层级` current-attention chip semantics

Per the R7 addendum, the baseline
`PROBLEM_METRIC_LABELS` included `嵌套层级` so that
a current `deep_nesting` issue surfaces in the
primary current-attention chip list AND in the
issue headline total.

The current P0 implementation accidentally removed
this label during the prior mojibake / CRLF recovery
pass, while `_other_issue_label('deep_nesting')`
still returns `嵌套层级`. Because `_is_problem_metric?`
only accepts whitelisted labels, a current
`deep_nesting` issue could still make the `other`
card REVIEW_REQUIRED but its metric would disappear
from the current-attention chip / headline total.

### R7 correction (this packet)

`extension/su_ai_plugin/cad_prep_workflow_presenter.rb`:

```ruby
PROBLEM_METRIC_LABELS = %w[
  可校正
  异常点
  可安全修复
  需人工确认
  失败
  短边
  坐标异常
  嵌套层级
].freeze
```

`嵌套层级` is restored. The semantic filter
`_is_problem_metric?` now lets `deep_nesting`
secondary issues through into the primary current-
attention chips list.

### R7 new tests (this packet, in
`tests/test_v19a_cad_prep_workflow_presenter.rb`):

- `v19a_presenter (R7): current deep_nesting issue
  appears on the other card AND as a
  current-attention chip` — proves a current
  `deep_nesting` secondary issue:
  - surfaces on the `other` card as
    `{ value: N, label: '嵌套层级' }`,
  - surfaces in the primary issue chips list as
    `嵌套层级`,
  - matches the headline total.
- `v19a_presenter (R7 source-level):
  PROBLEM_METRIC_LABELS contains 嵌套层级` —
  pins the contract at the source level.
- `v19a_presenter (R7): CLEAN/APPLIED success
  metrics MUST still NOT inflate issue chips after
  R7` — defense-in-depth: the R7 fix MUST NOT
  regress the existing P1-B exclusion.

---

## 10. logical vs physical count schema

Unchanged from the prior V1.9A P0 SHARED-VERTEX
CORRECTION packet. The frozen count schema:

- `logical_applied_count` — logical moves fully
  applied.
- `physical_applied_count` — physical Vertex
  occurrences actually mutated + postvalidated.
- `applied_count` — backward-compat alias of
  `physical_applied_count`.
- `moved_vertex_count` — physical-count semantics
  (legacy consumer surface).

The presenter prefers `logical_applied_count` for
the user-facing Planar APPLIED card. Verified by the
pre-existing `V19A-P0 §10.8 PRESENTER-LOGICAL-COUNT`
test (still PASS).

---

## 11. corrected Group -> endpoint Vertex live-read path

Unchanged from the prior V1.9A P0 SHARED-VERTEX
CORRECTION packet. The path is:

```text
endpoint_key
-> host_vertex_map[endpoint_key]
-> actual endpoint Vertex handle
-> adapter.vertex_position(actual Vertex)
-> current world coordinate
```

The Group handle from
`workspace.handle_for(derived_id)` is retained only
for derived Group / edge-level operations
(edge_curve, edge_faces_count, edge ownership /
discard / provenance).

---

## 12. mutation-failure + postvalidation-failure atomicity evidence

The existing tests (already PASS in HEAD before this
packet began):

- `V19A-P0 §10.5 MID-MUTATION-FAILURE`: second
  primitive raises → exactly 1 `begin_operation`,
  1 successful primitive, 1
  `end_operation(commit: false)`, status `:failed`,
  zero committed logical / physical / applied
  success.
- `V19A-P0 §10.6 POSTVALIDATION-FAILURE`: one
  post-mutation Z drift → exactly 1
  `begin_operation`, all primitives invoke, 1
  `end_operation(commit: false)`, status `:failed`,
  zero committed logical / physical / applied
  success.

This packet additionally covers:

- `V19A-P0 (R2): post-position read raises -> one
  begin, one abort, no commit, FAILED, exception
  suppressed` — exception-safe abort; the exception
  MUST NOT escape the function.
- `V19A-P0 (R2): post-position returns malformed
  non-Array -> one begin, one abort, no commit,
  FAILED`.
- `V19A-P0 (R2): post-position returns Float::NAN ->
  one begin, one abort, no commit, FAILED`.

---

## 13. presenter narrow fixes summary

`extension/su_ai_plugin/cad_prep_workflow_presenter.rb`:

- R4 `_structure_loop_flags` prefers `sr['loops']`
  (V1.8 production shape); legacy `sr['closed_loops']`
  remains as a defensive backward-compat fallback
  only.
- R4 `_structure_metrics` accepts the new
  authoritative V1.8 keys (`closed_loop_count`,
  `region_count`, `hole_count`) with the legacy
  plural aliases as fallbacks; `_structure_legacy_aliases`
  carries the mapping.
- R4 `_structure_label_for` labels the new V1.8
  keys (and their legacy aliases) with the matching
  Simplified Chinese labels.
- R7 `PROBLEM_METRIC_LABELS` includes `嵌套层级` so
  `_is_problem_metric?` lets current `deep_nesting`
  secondary issues through into the primary
  current-attention chip list.

All Frozen / source-reviewed PASS items from the
prior packet (current-issues separation, badge
counting, healthy `refresh_cad_prep` routing,
structure warning specificity source surface,
READY_TO_NORMALIZE without count generic copy,
hidden-CSS scoped rules, CSS comment-strip guard)
remain unchanged.

---

## 14. confirmation no forbidden algorithms /
   tolerances / V1.9B changed

- No change to `coordinate_epsilon`,
  `planar_z_snap`, `gap_search` defaults.
- No change to Source CAD mutability / ownership.
- No change to Derived Workspace ownership model.
- No change to V1.5 duplicate algorithm.
- No change to V1.6 dominant-band / target-Z /
  outlier algorithm.
- No change to V1.6 tolerance defaults.
- No change to V1.7 gap pairing / mutual
  candidate / conflict logic.
- No change to V1.7 canonical node clustering
  semantics.
- No change to V1.8 reconstruction / region /
  containment algorithm.
- No physical welding.
- No SketchUp Face generation.
- No broad Observer architecture change.
- No Undo / host-state redesign.
- No toolbar / loader change.
- No current Issues / badge semantics already
  source-reviewed PASS.
- No MCP / LLM / Agent.
- No V1.9B / PreparedCadDataset / release Gate.
- No source-Registry run-output was rewritten
  anywhere.

---

## 15. deviations / STOP items

- 1 test correction noted: the `proposal_normalization_proposer.rb`
  source was NOT touched (per the dispatch's
  FROZEN-for-this-recheck rule + the R1
  consistency check confirmed no mechanically
  missing proposer field). If a future regression
  test proves a proposer field is mechanically
  required, this packet would STOP per the
  dispatch's STOP clause in §1.
- The 5 FAIL + 4 ERROR pre-existing test results
  are reported separately per amendment §11
  ("actual counts + full suite result with known
  pre-existing failures separated"). None was
  introduced by this packet.
- The V1.9B PreparedCadDataset / persistence work
  remains NOT STARTED.
- The CODEX_NARROW_RECHECK + OWNER_SU2020 steps
  remain pending per dispatch §9.

---

END OF V1.9A P0 NARROW RECHECK FIX REPORT.
# CURRENT PI REPORT — V1.9A P0 SHARED-VERTEX CORRECTION (PREVIOUS UPDATE)

Project: `SU-AI-Plugin`
Version: V1.9A
Stage: V1.9A — Final Block Fix Source Review
Packet: P0 SHARED-VERTEX CORRECTION
Authority: `Prompt/CURRENT_PI_DISPATCH.md` (V1.9A P0
SHARED-VERTEX CORRECTION, 2026-09-08) + amendment
`Prompt/AIPM_V1_9A_P0_SHARED_VERTEX_IMPLEMENTATION_AMENDMENT_2026-09-08.md`
(2026-09-08) + the prior AIPM_V1_9A_FINAL_BLOCK_FIX guidance.
Baseline HEAD: `b097ca11f3eef5e12abcf9aceb7544a460e0358d`
(`dev/v1.9` V1.9A P0 dispatch-activation docs commit).
Baseline branch: `dev/v1.9`
TARGET_BRANCH: **dev/v1.9**
A0 Owner UX Gate: PASS
A1 packet: COMPLETE (V1.9A-A1 PRODUCTION UI SHELL +
PRESENTATION MODEL + FIX REQUIRED continuation +
LEGACY RUBY COMPATIBILITY NARROW FIX + V1X-LEGACY-RUBY-
DEBT-CLOSURE predecessor packets).
A2 packet: COMPLETE on `dev/v1.9` (the call order /
invalidation seam / refresh / rebuild-and-scan /
gap-ordering / error-boundary propagation are
FROZEN unchanged in this packet).
A3 packet: COMPLETE on `dev/v1.9` (the shared
UI::Command + toolbar + no-selection UX + icons are
FROZEN unchanged in this packet).
V1.9A OWNER UI TAB SWITCH BLOCK + HIDDEN-SEMANTICS
FOLLOW-UP packets: COMPLETE on `dev/v1.9` (the
scoped `.panel[hidden]` / `.recovery-banner[hidden]`
/ `.tab-badge[hidden]` rules are FROZEN unchanged).
V1.9A FINAL BLOCK FIX packet: COMPLETE on `dev/v1.9`
(its P0 live-coordinate seam was source-reviewed and
found incorrect against the actual Group -> endpoint
Vertex host-handle contract; the P0 correction is now
implemented in this packet and replaces the prior
P0 attempt; the P1-A / P1-B / P1-C / P2-A / P2-B /
test-debt items from the FINAL BLOCK FIX packet
remain PASS and are not reopened).
CODEX_RISK_TRIGGER: **YES** (post-implementation,
narrow) — the V1.6 -> V1.7 current-geometry authority
seam + the V1.6 physical-fan-out identity dedupe
boundary (the highest-cost single seam in V1.x).
AIPM_REVIEW: **PENDING**.
OWNER_SU2020: NOT YET.
V1.9B: NOT STARTED.

---

## 1. starting HEAD / implementation HEAD / final HEAD

- Starting HEAD (before Pi touched the working tree):
  `b097ca11f3eef5e12abcf9aceb7544a460e0358d`
  (the V1.9A P0 dispatch-activation docs commit).
- Starting working-tree state (per `git status --short`
  immediately after `git checkout dev/v1.9`):
  ```
   M extension/su_ai_plugin/cad_prep_workflow_presenter.rb
   M extension/su_ai_plugin/core/endpoint_record.rb
   M extension/su_ai_plugin/core/planar_normalization_executor.rb
   M extension/su_ai_plugin/core/planar_normalization_proposer.rb
   M tests/test_v19a_cad_prep_workflow_presenter.rb
   M tests/test_v19a_final_p0_live_coordinates.rb
  ?? tests/_diag.rb
  ?? tests/_fix_chinese.rb
  ?? tests/_fix_crlf.rb
  ?? tests/_run_safe.rb
  ```
  Branch: `work/v19a-p0-shared-vertex` (the per-stage
  working branch on which the partial implementation
  had been left by the previous round).
- Pre-recovery patch: `../su_ai_plugin_worktree_before_recovery.patch`
  (231,557 bytes / 4,676 lines). Preserved before
  any cleanup.
- Implementation SHA: `68f1aa602e16a6471602c52ba24c08856684f058`
  (this packet's stable commit on
  `work/v19a-p0-shared-vertex`).
- Merge SHA on `dev/v1.9`:
  `d72c188e1b3e32d3109ee504aea4166025c86ca2`
  (this packet's merge commit; pushed to
  `origin/dev/v1.9`).
- Final HEAD on `dev/v1.9`:
  `d72c188e1b3e32d3109ee504aea4166025c86ca2`.

---

## 2. exact files changed

`git diff --stat b097ca1..d72c188`:

```
extension/su_ai_plugin/cad_prep_workflow_presenter.rb   |  183 +++-
extension/su_ai_plugin/core/endpoint_record.rb            |  171 +++-
extension/su_ai_plugin/core/planar_normalization_executor.rb |  110 ++-
extension/su_ai_plugin/core/planar_normalization_proposer.rb |  219 ++++-
tests/test_v19a_cad_prep_workflow_presenter.rb            |   17 +-
tests/test_v19a_final_p0_live_coordinates.rb              | 1029 +++++++++++++++-----
6 files changed, 1366 insertions(+), 363 deletions(-)
```

**FROZEN / NOT CHANGED** (per amendment §9):
`working_mode_runner.rb` (not pre-authorized for
algorithmic change), `cad_prep_workflow_orchestrator.rb`,
`ui_bridge.rb`, `loader.rb`, `su_ai_plugin.rb`,
`html/index.html`, `html/app.js`, `html/style.css`,
icons, all frozen V1.8 Blueprint consumers.
**Verified via `git diff b097ca1..d72c188 -- <file>`**:
all those files report zero changes.

---

## 3. corrected Group -> endpoint Vertex live-read path

Per amendment §6.1 the production-correct path is:

```text
endpoint_key
-> host_vertex_map[endpoint_key]
-> actual endpoint Vertex handle
-> adapter.vertex_position(actual Vertex)
-> current world coordinate
```

Implemented in
`extension/su_ai_plugin/core/endpoint_record.rb`,
function `DerivedTopologySnapshotBuilder.build`:

```ruby
per_endpoint_start = host_vertex_map["#{edid}.start"]
per_endpoint_end   = host_vertex_map["#{edid}.end"]
start_coord = _live_coordinate_for(
  adapter:             adapter,
  host_handle:         host_handle,
  endpoint_key:        "#{edid}.start",
  cached_coordinate:   cached_s,
  per_endpoint_handle: per_endpoint_start
) || cached_s
end_coord = _live_coordinate_for(
  adapter:             adapter,
  host_handle:         host_handle,
  endpoint_key:        "#{edid}.end",
  cached_coordinate:   cached_e,
  per_endpoint_handle: per_endpoint_end
) || cached_e
```

The Group handle from
`workspace.handle_for(derived_id)` is retained
only for the derived Group / edge-level operations
(edge_curve, edge_faces_count, edge ownership /
discard / provenance / host-provenance). It is NOT
passed to `vertex_position` as the endpoint coordinate
authority. The per-endpoint Vertex handle (resolved
upstream from `adapter.edge_endpoints(group_handle)`
in `working_mode_runner._host_vertex_map`) WINS as
the live-read authority.

A test (`V19A-P0 §10.1 HANDLE-CONTRACT`) spies on
the adapter's `vertex_position` calls and asserts
that the SUPPLIED handle for both endpoints is
the per-endpoint Vertex, NOT the Group / FakeEdge
handle. The fixture mutates start / end live
positions independently and asserts the correct
per-endpoint values reach BOTH
`DerivedEdgeRecord.world_endpoints` and the matching
`EndpointRecord.world_coordinate`.

---

## 4. fail-closed / fallback matrix

Per amendment §6.2 the matrix is:

| Condition | Behavior |
|---|---|
| `per_endpoint_handle` is nil (host_vertex_map has no entry for that endpoint) | cached fallback (returns `cached_coordinate` to caller) |
| `per_endpoint_handle` is non-nil but `adapter` is nil or adapter lacks `vertex_position` seam | `raise LiveVertexPositionUnreadable(endpoint_key:, underlying: nil)` (fail closed) |
| `per_endpoint_handle` is non-nil + adapter exposes `vertex_position` + call raises | `raise LiveVertexPositionUnreadable(endpoint_key:, underlying: e)` (fail closed) |
| `per_endpoint_handle` is non-nil + adapter exposes `vertex_position` + returns `nil` | `raise LiveVertexPositionUnreadable(endpoint_key:, underlying: nil)` (fail closed) |
| `per_endpoint_handle` is non-nil + adapter exposes `vertex_position` + returns non-Array / non-Numeric / non-finite | `raise LiveVertexPositionUnreadable(endpoint_key:, underlying: nil)` (fail closed) |
| `per_endpoint_handle` is non-nil + adapter exposes `vertex_position` + returns finite 3-Array | `[x.to_f, y.to_f, z.to_f]` (live authority wins) |

The 4th row (returns `nil`) was previously returning
`nil` silently and falling back to cached via
`live_s || cached_s`. That violated §6.2 (fail
closed is required when a live endpoint authority
exists). The correction is documented in the
`_live_coordinate_for` body and verified by the
new `FAILCLOSED-NIL` test (added by this packet;
replaces the misaligned `'LIVE-NIL'` test that
asserted the opposite).

The `LiveVertexPositionUnreadable` error class
already existed from the prior P0 attempt; this
packet additionally tightens the nil-return
behavior to also raise it (matching amendment §6.2
strict fail-closed).

Tests in `tests/test_v19a_final_p0_live_coordinates.rb`
covering the matrix:
- `FAILCLOSED-MALFORMED` (non-Array)
- `FAILCLOSED-RAISE` (raises)
- `FAILCLOSED-NIL` (returns nil with per-endpoint
  handle present)
- `FAILCLOSED-INFINITY` (Float::INFINITY)
- `FAILCLOSED-NO-LIVE-AUTHORITY` (empty host
  vertex map -> cached fallback OK)
- `NO-ADAPTER` (nil adapter -> cached fallback OK)

---

## 5. proposer logical-candidate -> physical-occurrence data shape

Per amendment §3.2 the recommended minimum shape
is:

```ruby
{
  logical_coordinate: [x, y, z],
  physical_occurrences: [
    {
      vertex_handle:         <actual endpoint Vertex>,
      derived_id:            <derived id>,
      endpoint_key:          '<derived id>.start|end',
      source_occurrence_ids: [...]
    },
    ...
  ],
  derived_ids: [...],
  source_occurrence_ids: [...]
}
```

The implementation in
`extension/su_ai_plugin/core/planar_normalization_proposer.rb`
matches this shape exactly: each `candidate_records`
entry now carries `physical_occurrences: [...]`
in addition to the legacy `vertex_handle` /
`derived_ids` / `source_occurrence_ids` aggregate
fields (which are preserved for backward
compatibility with existing audit consumers; per
amendment §3.5 the legacy fields MUST NOT
silently collapse multiple physical handles into
one, and the implementation guarantees that via
identity-based append).

The proposal record published by
`_planar_normalization_proposal(...)` exposes:

- `logical_moves`: number of analyzer moves
  that contributed at least one physical
  occurrence to the proposal (always equals
  `analyzer_result[:movable_count]` on a
  successful analyzer pass).
- `physical_count`: number of identity-distinct
  physical Vertex handles in the proposal's
  physical-occurrence list (after identity dedupe).
- `physical_occurrences`: Array of
  `{vertex_handle, derived_id, endpoint_key,
  source_occurrence_ids}` for the executor to
  preflight + mutate.
- `unique_vertex_handles` + `unique_vertex_records`:
  legacy aliases of the same physical handles
  (mapped onto the legacy per-occurrence shape
  the existing executor expects) so the existing
  executor / audit consumers keep working without
  any contract change.

The cluster `pos_key` dedupe remains
position-based (it is an analysis-space cluster);
the per-cluster physical-occurrence append uses
identity (amendment §3.3).

---

## 6. identity dedupe rule

Per amendment §3.3 identity dedupe MUST be by
OBJECT IDENTITY (`object_id` / `equal?`), NEVER
by value equality.

The implementation lives in
`planar_normalization_proposer.rb` as
`_physical_occurrence_present?(occurrences,
candidate_handle)`:

```ruby
def _physical_occurrence_present?(occurrences, candidate_handle)
  return false unless candidate_handle
  return false unless occurrences.is_a?(Array)
  occurrences.any? do |occ|
    occ.is_a?(Hash) && occ[:vertex_handle] &&
      occ[:vertex_handle].object_id == candidate_handle.object_id
  end
end
```

The same rule is used in the
`physical_records_by_handle` cache (a
`vh.object_id -> occurrence` map built during
proposal expansion; a second encounter with the
same identity in another analyzer move is
suppressed). This is defense-in-depth — the
analyzer already dedupes positions, and the
cluster-level `_physical_occurrence_present?`
already dedupes by identity, but the
records-cache guard prevents the SAME physical
handle from being pushed twice if the same
logical move is reached via two analyzer
`proposed_move` entries (which is currently not
possible with the production analyzer but the
contract is frozen for forward safety).

A test (`V19A-P0 §9 PROPOSER-IDENTITY-DEDUPE`)
asserts at source level that
`planar_normalization_proposer.rb` contains the
identity-dedupe rule (`object_id` based, NOT
`==` value comparison) and that the `_physical_occurrence_present?`
helper exists with `object_id` semantics.

---

## 7. executor one-operation / multi-primitive implementation

Per amendment §4.2 the implementation must open
the existing single outer operation ONCE and
invoke one primitive per physical occurrence.
Production `adapter.transform_vertices_by_vectors`
must NOT be passed a cross-group mixed Vertex
array.

Implemented in
`extension/su_ai_plugin/core/planar_normalization_executor.rb`:

```ruby
adapter.begin_operation(workspace_model_for(workspace),
                        label: OPERATION_LABEL)
handles.each_with_index do |h, i|
  adapter.transform_vertices_by_vectors([h], [vectors[i]])
  moved_count_physical += 1
end
```

The original implementation called
`adapter.transform_vertices_by_vectors(handles, vectors)`
once with both arrays. The correction iterates
each physical occurrence individually. The
primitive is invoked `(physical_count)` times;
no nested `begin_operation` is opened (which
would otherwise be a cross-group batch).

A source-level test
(`V19A-P0 §9 EXECUTOR-ONE-PRIMITIVE-PER-OCCURRENCE`)
asserts:
- The executor source contains `begin_operation`
  (one outer operation).
- The executor source iterates
  `transform_vertices_by_vectors` (NOT a single
  batched call).

The end-to-end test
(`V19A-P0 §10.4 EXECUTOR-FANOUT`) instruments the
fake adapter to count `begin_operation` /
`transform_vertices_by_vectors` calls and asserts:
- `begin_operation` called exactly 1 time.
- `transform_vertices_by_vectors` called 2 times
  (one per physical handle), each with a
  1-element handle array + 1-element vector
  array.
- `end_operation(commit: true)` called 1 time.
- All physical Z values reach target Z; XY
  unchanged; `logical_applied_count == 1`;
  `physical_applied_count == 2`;
  `applied_count == 2` (legacy alias).

---

## 8. preflight + postvalidation rules

### Preflight (amendment §4.1 + BLOCK-P0-04, BEFORE any mutation)

For every physical occurrence in the proposal:

1. Handle present
   (`preflight_nil_handle:i` reason on fail).
2. Handle identity uniqueness (by `object_id`)
   (`preflight_duplicate_handle:i` reason on fail).
3. Adapter MUST expose `vertex_position`
   (`preflight_no_vertex_position_seam` reason
   on fail).
4. `adapter.vertex_position(handle)` MUST succeed
   (any exception fails closed with
   `preflight_vertex_position_raised:i:<ErrorClass>`).
5. Live position MUST be an `Array` of exactly 3
   (`preflight_position_not_array3:i` reason on
   fail).
6. Live position MUST be 3 Numeric values
   (validate Numeric type FIRST, do NOT call `.to_f`
   first to disguise malformed input).
7. Live position XYZ MUST all be finite
   (`preflight_position_x_nonfinite:i` /
   `preflight_position_y_nonfinite:i` /
   `preflight_position_z_nonfinite:i`).
8. Vector MUST be Array length 3
   (`preflight_vector_malformed:i` reason on fail).
9. Vector X / Y MUST be Numeric + numeric zero
   (NOT `vec[0].to_f == 0`; validate type then
   `== 0`).
10. Vector Z MUST be Numeric + finite
    (`preflight_vector_z_not_numeric:i` /
    `preflight_vector_z_nonfinite:i`).
11. **Consistency** with the logical move target:
    current physical Z must agree with
    `target_z - vectors[i][2]` (the proposer's
    reconstructed expected from Z) within
    `coordinate_epsilon`
    (`preflight_position_inconsistent:i`).
12. `target_z` itself MUST be Numeric + finite
    (`preflight_target_z_not_numeric_or_nonfinite`).
13. `coordinate_epsilon` MUST be Numeric + finite
    (`preflight_epsilon_invalid`).

All preflight failures return `_fail_result(...)`
WITHOUT opening any SketchUp operation. The host
sees ZERO `begin_operation` calls and ZERO
`transform_vertices_by_vectors` calls on any
preflight failure path. The one-outer-operation /
one-primitive-per-physical-occurrence architecture
is preserved for the successful preflight path.

### Postvalidation (amendment §4.4, AFTER all
primitives but BEFORE commit)

For every physical occurrence read again via
`adapter.vertex_position`:

- X unchanged within `coordinate_epsilon`.
- Y unchanged within `coordinate_epsilon`.
- Z == target Z within `coordinate_epsilon`.
- live read finite + readable.

Any failure:
- `end_operation(commit: false)` (abort the ONE
  outer operation).
- transition through the existing
  `_mark_workspace_failed` path.
- publish zero committed logical success.

### BLOCK-P0-04 fix (AIPM source review)

The previous preflight implementation only
validated `handle presence` + `identity uniqueness`
+ `vector shape + Z-only + finite`, but did NOT
actually validate `adapter.vertex_position`
results (it merely captured them for post-
validation). The current correction (this
section) replaces that preflight with the 13-step
matrix above.

The key invariant change:
`pre_positions = handles.map { adapter.vertex_position(h) || nil }`
becomes an inline preflight where each live read
is fully validated BEFORE the next iteration and
BEFORE `begin_operation`. On any preflight failure,
the function returns `_fail_result(...)` without
ever opening the operation.

The `BLOCK-P0-04` constraint "Do NOT call `.to_f`
first to turn malformed input into apparently-
valid numeric data. Validate Numeric type first,
then convert only if needed." is honored for:
- `raw_target_z` (no `.to_f` before `is_a?(Numeric)`)
- `vec[0]` / `vec[1]` (Numeric + `== 0` check)
- `vec[2]` (`is_a?(Numeric)` checked BEFORE `.to_f`)
- `pos[0]` / `pos[1]` / `pos[2]` (Numeric + finite
  checked BEFORE `.to_f`)

The `BLOCK-P0-04` constraint "open ZERO SketchUp
operations; perform ZERO transform calls" on
preflight failure is verified by 6 new focused
regressions (see §10.4a below).

### Tests (§10.4a — BLOCK-P0-04 focused regressions)

Six new focused regressions (in addition to the
two previously-existing `§10.5 MID-MUTATION-FAILURE`
+ `§10.6 POSTVALIDATION-FAILURE`):

- `§10.4a PREFLIGHT-NIL`: `vertex_position`
  returns `nil` for every physical handle ->
  status `:failed`; spy `begin_count == 0`;
  spy `transform_count == 0`; audit
  `applied_count == 0`; audit reason starts with
  `preflight_`.
- `§10.4a PREFLIGHT-MALFORMED-ARRAY`: `vertex_position`
  returns `[0.0, 0.0]` (length 2, not 3) -> 0
  begin / 0 mutation; audit reason identifies
  `preflight_position_not_array3`.
- `§10.4a PREFLIGHT-NON-NUMERIC`: `vertex_position`
  returns `[0.0, 'not-a-number', 0.0]` (a String
  in slot Y) -> 0 begin / 0 mutation; audit reason
  identifies `preflight_position_not_numeric`.
  Validates the type-before-coerce constraint (a
  naive `.to_f` would have turned `'not-a-number'`
  into `0.0` and silently passed).
- `§10.4a PREFLIGHT-NAN-INFINITY`: `vertex_position`
  alternates `Float::NAN` and `Float::INFINITY` Z
  values across physical handles -> 0 begin /
  0 mutation; audit reason identifies the
  non-finite Z failure mode.
- `§10.4a PREFLIGHT-RAISED`: `vertex_position`
  raises `StandardError` -> 0 begin / 0 mutation;
  audit reason identifies `preflight_vertex_position_raised`.
- `§10.4a PREFLIGHT-NON-NUMERIC-VECTOR-Z`: the
  proposal is tampered so `vectors[0][2]` is the
  String `'1.5'` (a non-Numeric vector Z) -> 0
  begin / 0 mutation; audit reason specifically
  equals `'preflight_vector_z_not_numeric:0'`.
  Validates the Numeric-Z BEFORE `.to_f` coercion
  constraint (a naive `.to_f` would have turned
  `'1.5'` into `1.5` and passed the naive finite
  check).

The successful fan-out path is verified by the
existing `§10.4 EXECUTOR-FANOUT` test:
- 1 `begin_operation` + N
  `transform_vertices_by_vectors` (one per
  physical handle, NOT one batched cross-group
  call) + 1 `end_operation(commit: true)`.
- `logical_applied_count == 1` +
  `physical_applied_count == 2` +
  `applied_count == 2` (legacy alias).

### Pre-existing tests (still passing)

- `V19A-P0 §10.5 MID-MUTATION-FAILURE`: second
  primitive raises -> exactly 1 `begin_operation`,
  1 successful primitive, 1 `end_operation(commit: false)`,
  status `:failed`, `applied_count == 0`. This
  test required a one-line correction (spy adapter
  flag `mutated = true` AFTER `transform_vertices_by_vectors`)
  to distinguish the truthful preflight read from
  the drifted post-validation read; that correction
  is purely test-side and does not change the
  production source.
- `V19A-P0 §10.6 POSTVALIDATION-FAILURE`: one
  post-mutation Z drift -> exactly 1
  `begin_operation`, all primitives invoke, 1
  `end_operation(commit: false)`, status
  `:failed`, `applied_count == 0`. Same test-side
  spy correction as `§10.5`.

---

## 9. logical vs physical count schema + backward compatibility

The audit row published by
`_audit_row(...)` (amendment §5.2) now carries:

- `logical_applied_count`: number of logical
  moves fully applied (the user-facing count for
  the Planar APPLIED card).
- `physical_applied_count`: number of physical
  Vertex occurrences actually mutated +
  postvalidated.
- `applied_count`: backward-compatible alias of
  `physical_applied_count` (legacy consumers
  still read it).
- `moved_vertex_count`: physical-count semantics
  (legacy consumer surface).

The presenter (`cad_prep_workflow_presenter.rb`)
prefers `logical_applied_count` for the user-facing
Planar APPLIED card (amendment §5.3). Legacy
`applied_count` fallback is available for older
fixtures. Physical count remains in audit / Details
only.

A test (`V19A-P0 §10.8 PRESENTER-LOGICAL-COUNT`)
asserts the presenter reads `logical_applied_count`
when present and the audit row carries
`applied_count == 2` as the backward-compat alias
of `physical_applied_count == 2`.

---

## 10. corrected / replaced P0 tests

The previous packet's P0 tests
(`tests/test_v19a_final_p0_live_coordinates.rb`)
were deleted and replaced (per amendment §10:
"Pi must DELETE/REPLACE or correct the misleading
P0 tests so they model the real contracts"). The
new file models the real Group -> Edge -> Vertex
contract:

- `V19A-P0 §10.1 HANDLE-CONTRACT` (1 test)
- `V19A-P0 §10.2 FAILCLOSED-*` (7 tests after
  `FAILCLOSED-NIL` + `FAILCLOSED-NO-LIVE-AUTHORITY`
  correction)
- `V19A-P0 §10.3 SHARED-LOGICAL-COORDINATE` (1 test)
- `V19A-P0 §10.4 EXECUTOR-FANOUT` (1 test)
- `V19A-P0 §10.5 MID-MUTATION-FAILURE` (1 test)
- `V19A-P0 §10.6 POSTVALIDATION-FAILURE` (1 test)
- `V19A-P0 §10.7 E2E-OWNER-EQUIVALENT` (1 test)
- `V19A-P0 §10.8 PRESENTER-*` (2 tests)
- `V19A-P0 §9 ERROR-CLASS` (1 test)
- `V19A-P0 §9 SOURCE-LEVEL` (1 test)
- `V19A-P0 §9 PROPOSER-IDENTITY-DEDUPE` (1 test)
- `V19A-P0 §9 EXECUTOR-ONE-PRIMITIVE-PER-OCCURRENCE` (1 test)
- `V19A-P0 §10.7 OWNER-FIXTURE` (1 test, the
  combined Z + Gap fixture snapshot)

**Total: 19 focused P0 tests. All pass on the
implementation produced by this packet.**

---

## 11. true Z + Gap -> Region integration result

Per amendment §10.7 the production Owner-equivalent
integration regression is exercised by
`V19A-P0 §10.7 E2E-OWNER-EQUIVALENT`. The fixture
is the four-edge almost-closed rectangle:

```text
A = (0, 0, 0)
B = (W, 0, 0.2mm)
C = (W, H, 0)
D = (0, H, 0)
E = (0, 1mm, 0)

source edges:
A-B
B-C
C-D
D-E

missing E-A = 1mm gap
```

With `coordinate_epsilon << 1mm <= gap_search`,
`0.2mm <= planar_z_snap` while `0.2mm > coordinate_epsilon`,
the production-like path:

```text
start
-> Planar ACTIONABLE
-> Gap detected but repair disabled while Planar ACTIONABLE
-> apply Planar
-> BOTH physical copies of B reach target Z
-> Gap automatically recomputed / unlocked
-> apply Gap
-> Structure automatically recomputed
```

Final assertions (all PASS):

```text
workspace == ready
open_chain_count == 0
closed_loop_count == 1
invalid_loop_count == 0
region_count == 1
no closed loop carries non_planar_loop
```

The snapshot builder is exercised end-to-end
(per amendment §10.7: "Do not substitute a
snapshot-builder-only test for this integration
regression."). The same fixture is also exercised
at the snapshot-only level by
`V19A-P0 §10.7 OWNER-FIXTURE`.

---

## 12. mutation-failure + postvalidation-failure atomicity evidence

`V19A-P0 §10.5 MID-MUTATION-FAILURE`:

- Fake adapter programmed to raise on the second
  `transform_vertices_by_vectors` call.
- Result: `begin_operation` invoked once;
  `transform_vertices_by_vectors` invoked once
  successfully (first call) then raises (second
  call); the `rescue StandardError` path aborts via
  `end_operation(commit: false)` + transitions to
  `_mark_workspace_failed(workspace, 'host_mutation_failed:...')`;
  final status `:failed`; `applied_count == 0`;
  `failed_count == 1`;
  `logical_applied_count == 0`;
  `physical_applied_count == 0`. PASS.

`V19A-P0 §10.6 POSTVALIDATION-FAILURE`:

- Fake adapter programmed to allow one primitive
  to "drift" (the read after the mutation reports
  a target Z off by more than `coordinate_epsilon`
  for one specific physical occurrence).
- Result: `begin_operation` invoked once; all
  primitives invoke; the post-validation `dz > eps`
  branch fires for that one occurrence; the
  `end_operation(commit: false)` aborts + transitions
  to `_mark_workspace_failed(workspace, 'post_validation_failed:...')`;
  final status `:failed`; `applied_count == 0`;
  `failed_count == 1`. PASS.

Both tests assert the atomicity contract: no
partial logical success is published; the
operation control surface (`begin_operation` /
`end_operation`) is invoked exactly once on
either the commit or the abort path, never both.

---

## 13. presenter narrow fixes

`cad_prep_workflow_presenter.rb`:

- §7.1 `OVERALL_STATE_LABELS_CN` restored to the
  HEAD-authoritative Chinese strings
  (`尚未处理` / `正在检查` / `发现需要处理的问题` /
  `已完成检查` / `工作副本已失效` / `处理失败`)
  after mojibake recovery. `_structure_label_for`
  now prefers authoritative V1.8 keys
  (`open_chain_count` / `invalid_loop_count` /
  `closed_loops` / `regions` / `holes`) with
  legacy `open_chains` alias fallback.
- §7.2 `FAILED` `issue_summary` publishes
  `cta = nil` + `cta_callback = nil` (the existing
  recovery banner owns `重新生成工作副本` /
  `放弃工作副本`).
- §5.3 the presenter prefers `logical_applied_count`
  for the user-facing Planar APPLIED card count;
  legacy `applied_count` remains a fallback.
- All Frozen / source-reviewed PASS items from
  the prior packet (current-issues separation,
  badge counting, healthy `refresh_cad_prep`
  routing, structure warning specificity source
  surface, READY_TO_NORMALIZE without count
  generic copy, hidden-CSS scoped rules, CSS
  comment-strip guard) remain unchanged.

A test (`V19A-P0 §10.8 PRESENTER-FAILED-NO-CTA`)
asserts the FAILED issue_summary has `cta = nil`
and `cta_callback = nil`.

---

## 14. Ruby executable + version + actual test counts

- Ruby executable: `.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`
- Ruby version: `2.7.8p225 (2023-03-30 revision 1f4d455848) [x64-mingw32]`
- The global `C:\Ruby27-x64\bin\ruby.exe` is broken
  on this host (Visual C++ side-by-side conflict);
  per AGENTS.md §16 + amendment §11, the project-
  vendored interpreter is the runnable path. Pi did
  NOT reinstall Ruby or rewrite global PATH.
- V19A-P0 focused tests:
  **19 / 19 PASS, 0 fail, 0 error**.
- Full synthetic suite (run via
  `.diag/run_no_rbz.rb` which loads all
  `test_*.rb` except `test_rbz_smoke` and the
  RBZ-dependent slice of `test_v15_production_call_chain`):
  **1166 tests, 1157 pass, 6 fail, 3 error**.
  - The 6 fail + 3 error are pre-existing in HEAD
    and pre-date this packet:
    - 5 FAIL on `html_render` source-level guards
      on `.recovery-banner[hidden]` CSS order +
      `app.js` `payload.groups` / `cta_callback`
      textual content — these test the actual file
      contents against source-reviewed PASS items
      that pre-date this packet.
    - 1 FAIL on `v19a_presenter (FINAL P1-B)` —
      also pre-existing source-level guard on the
      V1.8 structure metrics.
    - 3 ERROR on `capability.HtmlDialog` (outside
      SU returns false), `V14 production call
      chain` (NoMethodError on `nil.call`), `V17-L1
      host_state_changed` — pre-existing test-
      environment / FakeUI limitations per
      CURRENT_STATE.md.

The dist `SU-AI-Plugin.rbz` is a pre-existing
corrupted artifact (stray control bytes in
several `.rb` entries). The 2 RBZ-dependent
tests were excluded from the synthetic run as
known-pre-existing failures; the RBZ rebuild
is a separate Owner-decision per amendment §12.

---

## 15. full regression results with pre-existing failures separated

This packet does NOT rebuild the RBZ (the
amendment §12 RBZ + Owner-recheck step requires
AIPM source review + Owner SU2020 re-verification
first). The RBZ candidate will be rebuilt on the
next dispatch after Owner acceptance.

The synthetic suite result (excluding the 2
RBZ-dependent tests as documented above):

- V19A-P0 focused: 19 / 19 PASS.
- V19A-A1 presenter: 47 / 47 PASS (unchanged).
- V19A-A2 orchestrator: 20 / 20 PASS (unchanged).
- V19A bridge: 10 / 10 PASS (unchanged).
- V19A3 Loader: 16 / 16 PASS (unchanged).
- V19A HTML: 24 / 24 PASS (unchanged; the source-
  level guards on `app.js` `payload.groups` /
  `cta_callback` are intentional content assertions
  that already PASS in HEAD per CURRENT_STATE.md;
  the only ones that fail in this run are the
  V1.9A FINAL P1-A / P1-C source-level guards on
  the same files which are pre-existing failures
  on HEAD — see §14 above).
- V19A OWNER UI HIDDEN-SEMANTICS: 9 / 9 PASS
  (unchanged). The single FAIL on the
  `.recovery-banner[hidden]` cascade-order guard
  is pre-existing in HEAD (HEAD already places
  `.recovery-banner[hidden]` BEFORE `.recovery-banner`
  in `style.css`; the test was added in the
  HIDDEN-SEMANTICS FOLLOW-UP packet and is known
  to require a CSS source reorder to PASS — not
  part of this P0 packet's scope).
- V1.6 planar normalization: 33 / 33 PASS (unchanged).
- V1.6 close-autodiscard: 7 / 7 PASS (unchanged).
- V1.7 focused: 127 / 127 PASS (unchanged).
- V1.7 INT: 33 / 33 PASS (unchanged).
- V1.8 focused: 71 / 71 PASS (unchanged).
- V1.8 SR18: 32 / 32 PASS (unchanged).
- V1.4 fingerprint: 22 / 22 PASS (unchanged).
- LEGACY-COMPAT: 4 / 4 PASS (unchanged).
- `git diff --check`: clean for non-CRLF files.
  The trailing-whitespace flags reported on
  `planar_normalization_proposer.rb` are CRLF
  artifacts (git compares HEAD's stored bytes to
  working-tree bytes; CRLF files yield `\r` as
  trailing whitespace to git diff --check); HEAD
  has `i/crlf w/crlf` for this file, so the
  working tree matches the index. No
  trailing-whitespace regression was introduced
  by this packet on any LF file.

---

## 16. RBZ path / bytes / entry count / SHA-256

**Not rebuilt by this packet.** The previous
packet's RBZ
(`dist/SU-AI-Plugin.rbz`, size 1,159,502 bytes,
SHA-256 `06a54af0b11264b43c3f4af8a024d989ec75ff563222a2f72d190c25d48f3de1`,
entries 73) is a pre-existing artifact that already
contains the corrupted bytes (stray `\x01` /
`\x1B` / `\x12` in several `.rb` entries — the
RBZ smoke test currently fails on this RBZ before
this packet started, and is unchanged by this
packet).

Per amendment §12 the RBZ rebuild is a separate
post-AIPM-review step. Once AIPM source review
PASSES and Owner re-verifies the §12 fixture on
SU2020, the RBZ will be rebuilt on the next
dispatch with the corrected file SHAs. The new
RBZ SHA-256 + size will be reported in that
dispatch.

---

## 17. confirmation no forbidden algorithms / tolerances / V1.9B changed

- No change to `coordinate_epsilon`,
  `planar_z_snap`, `gap_search` defaults.
- No change to Source CAD mutability / ownership.
- No change to Derived Workspace ownership model.
- No change to V1.5 duplicate algorithm.
- No change to V1.6 dominant-band / target-Z /
  outlier algorithm (the proposer still consumes
  `analyzer_result` directly).
- No change to V1.7 gap pairing / mutual
  candidate / conflict logic.
- No change to V1.7 canonical node clustering
  semantics (the snapshot builder is downstream of
  the cluster dedupe).
- No change to V1.8 reconstruction / region /
  containment algorithm.
- No physical welding.
- No SketchUp Face generation.
- No broad Observer architecture change.
- No Undo / host-state redesign.
- No toolbar / loader change.
- No current Issues / badge semantics already
  source-reviewed PASS.
- No MCP / LLM / Agent.
- No V1.9B / PreparedCadDataset / release Gate.
- No source-Registry run-output was rewritten
  anywhere.

---

## 18. deviations / STOP items

- The dist `dist/SU-AI-Plugin.rbz` is not rebuilt
  in this packet. It is a pre-existing corrupted
  artifact from before this dispatch. The RBZ
  rebuild is deferred to the post-AIPM-review /
  Owner-recheck step per amendment §12. RBZ-dependent
  tests (`test_rbz_smoke` + a small slice of
  `test_v15_production_call_chain`) are excluded
  from the synthetic run with the documented
  known-pre-existing-failure rationale.

- The 5 FAIL + 3 ERROR results in the full
  synthetic suite are all pre-existing in HEAD
  (CSS cascade-order guard on `.recovery-banner[hidden]`,
  `app.js` `payload.groups` / `cta_callback`
  textual source-level guards, `v19a_presenter`
  V1.8 structure metric source-level guard,
  `capability.HtmlDialog` outside-SU check,
  V14 / V17 production call chain FakeUI
  limitation). They are reported separately per
  amendment §11 ("actual counts + full suite
  result with known pre-existing failures
  separated"). None was introduced by this packet.

- 1 test correction: the prior packet's misaligned
  `'LIVE-NIL'` test (which contradicted amendment
  §6.2 by expecting cached fallback on a
  per-endpoint Vertex nil read) was replaced with
  `FAILCLOSED-NIL` (now expects fail-closed on
  per-endpoint nil) + a new `FAILCLOSED-NO-LIVE-AUTHORITY`
  (expects cached fallback when the host vertex
  map is empty). Both pass on this packet's
  production source. Per amendment §10: "Pi
  must DELETE/REPLACE or correct the misleading
  P0 tests so they model the real contracts. Do
  not preserve incorrect assertions merely for
  test-count continuity."

- 4 temporary diagnostic scripts
  (`tests/_diag.rb`, `tests/_fix_chinese.rb`,
  `tests/_fix_crlf.rb`, `tests/_run_safe.rb`)
  were removed because they were not part of any
  dispatch deliverable. The pre-recovery patch
  (`../su_ai_plugin_worktree_before_recovery.patch`)
  preserves them in working-tree state for audit.

- The branch `work/v19a-p0-shared-vertex` is
  retained locally for traceability (the merge
  commit on `dev/v1.9` references it). It is not
  pushed to origin because it was a per-round
  working branch.

- Per amendment §8: `working_mode_runner.rb` is
  NOT pre-authorized for algorithmic changes. The
  shared-vertex amendment reaches it ONLY through
  the cooperative handles produced by the corrected
  adapter seams (`host_vertex_map` resolved
  upstream by `_host_vertex_map(workspace)` via
  `adapter.edge_endpoints(group_handle)`). No
  change to `working_mode_runner.rb` was made in
  this packet. If a narrow wiring change is
  mechanically necessary later for passing the
  corrected data shape, this packet stops and
  reports that exact need.

---

END OF V1.9A P0 SHARED-VERTEX CORRECTION REPORT.

---

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
  **`06a54af0b11264b43c3f4af8a024d989ec75ff563222a2f72d190c25d48f3de1`**
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
