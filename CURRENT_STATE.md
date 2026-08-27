# SU-AI-Plugin — CURRENT STATE

Updated: 2026-08-27
Project: `D:\Projects\SU-AI-Plugin`

Current stage: **V1.5 — High-confidence Auto Repair / Round-5 BLOCK fix**
Current status: **IMPLEMENTATION COMPLETE — STOPPED (awaiting AIPM review per PI_START_HERE.md §6)**
Next stage: **V1.6 — NOT STARTED**

Canonical durable context:
- `AGENTS.md`
- `PROJECT_HANDOFF.md`
- `PROJECT_MASTER_PLAN_V1X.md`

Current project rule:
- AIPM owns product + technical design, primary review, and dispatch.
- Pi implements the frozen design.
- Codex is used only for legitimate mandatory / high-risk repo risk.
- The fixed current workflow is:
  `Prompt/CURRENT_PI_DISPATCH.md -> Pi -> Review/CURRENT_PI_REPORT.md -> AIPM`.
- `PI_START_HERE.md` is the permanent Pi bootstrap entry.
- `Prompt/CURRENT_PI_DISPATCH.md` is the sole normal formal current task file.
- `Review/CURRENT_PI_REPORT.md` is the sole normal current implementation return.
- Historical Prompt/Review artifacts remain durable evidence only and cannot become current through filename, numbering, mtime, or stale ACTIVE status.
- Git is the normal fine-grained implementation history; separately named durable artifacts remain allowed for important design/Gate/release evidence.
- This V1.5 Round-5 case has reached the end of Pi's execution window. Pi is STOPPED. AIPM review + the next Codex narrow xHigh recheck are the next gates per `PROJECT_MASTER_PLAN_V1X.md` §13.

---

## 1. ACTIVE STATUS

### Completed
- V1.0–V1.4 remain closed on their previously verified scope.
- V1.5 Round-3 implementation/fix packet is complete (history).
- V1.5 Round-4 BLOCK fix packet is complete (history).
- V1.5 Round-5 BLOCK corrective implementation packet is complete (THIS UPDATE).
- Round-5 code, test additions, documentation, and supporting RBZ rebuild are committed (local stable checkpoint, NOT pushed).
- Automated evidence, RBZ rebuild, and full Ruby suite all PASS end-to-end for the Round-5 candidate.

### In progress
- Nothing is currently being implemented by Pi.

### Waiting
- AIPM review of the Round-5 Pi packet (`Review/CURRENT_PI_REPORT.md`).
- AIPM republish of the Owner verification file
  (`Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`,
  per Round-5 §9; the previously published version was invalidated by the Round-4
  Codex verdict).
- Codex narrow xHigh recheck of the V1.5 BLOCK set
  (V15-STAGE-BLOCK-001..005), dispatched only AFTER AIPM review and
  Owner-checklist republish.

### Not started
- V1.6 Planar Normalization / Z Policy.

V1.6 must not begin until:
1. V1.5's active BLOCK set is formally closed;
2. required Owner verification for V1.5 is completed as applicable;
4. AIPM creates and freezes a V1.6 Stage Technical Blueprint;
5. AIPM activates `Prompt/CURRENT_PI_DISPATCH.md`, referencing the frozen
   V1.6 Stage Technical Blueprint as required.

---

## 2. CURRENT GIT / BUILD STATE

Current branch: `v1.5-stage-round3-fix`

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
(see §15 of `Review/CURRENT_PI_REPORT.md` for the recorded SHA;
final stable commit recorded in the local git log; NOT pushed)

Working tree (Round-5 fix):
- Modified: 5 tracked files (Round-5 implementation in `core/`).
- New untracked-then-tracked: 1 test file
  (`tests/test_v15_round5_block_fix.rb`).
- The dist/ `SU-AI-Plugin.rbz` is rebuilt but NOT tracked (per repo policy).

Round-5 RBZ:

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

Evidence recorded in this file:
- Size: 623,881 bytes
- Entries: 59
- SHA-256:
  `C10D550352D0733850A6A45C441B56F25E490426B870459F16149B5CDB515C35`

Build command:
`.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe scripts/build_rbz.rb`

This RBZ is **not approved for Owner installation** until the
AIPM Owner verification file is republished AND the next Codex
narrow xHigh recheck passes.

---

## 3. CURRENT TEST EVIDENCE

Round-5 evidence (THIS UPDATE):

- Targeted Round-5 V15-B00 BLOCK regressions (BLOCK-001, BLOCK-002A/004,
  BLOCK-002B, BLOCK-005): **17/17 PASS**
- Full V15: **82/82 PASS**
- Full Ruby suite: **746/746 PASS**
- RBZ smoke: 8/8 PASS
- `git diff --check`: clean

These are implementation/test evidence only.

They do not by themselves close the Codex BLOCK set, prove real-host
behavior, or substitute for Owner verification.

---

## 4. ACTIVE BLOCK / REVIEW STATUS

Active V1.5 BLOCK set:

- `V15-STAGE-BLOCK-001`
- `V15-STAGE-BLOCK-002` (with sub-cases A and B)
- `V15-STAGE-BLOCK-003`
- `V15-STAGE-BLOCK-004`
- `V15-STAGE-BLOCK-005`

Status:

> **Addressed by the Round-5 Pi fix packet; awaiting AIPM review
> and Codex narrow recheck. NOT yet formally closed.**

Do not write "BLOCKs closed" until both gates pass.

Relevant Round-5 Pi packet:

`Review/CURRENT_PI_REPORT.md` (dispatch id `SUAI-V15-R5-BLOCK-FIX-20260827-01`)

Relevant frozen design references:

- `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND5_BLOCK_FIX_2026-08-27.md`
- `Prompt/CURRENT_PI_DISPATCH.md` (ACTIVE)

These are the durable executed-contract artefacts for the completed Round-5
fix. They are not a current Pi dispatch and do NOT override the current
`Prompt/CURRENT_PI_DISPATCH.md` or existing project governance in
`AGENTS.md`, `PROJECT_HANDOFF.md`, and `PROJECT_MASTER_PLAN_V1X.md`.

Historical Round-3 / Round-4 artefacts (still kept for audit):

- `Review/V1_5_ROUND4_BLOCK_FIX_RECHECK_PACKET_2026-08-27.md`
- `Review/V1_5_ROUND3_FIX_RECHECK_PACKET_2026-08-26.md`
- `Review/CODEX_V1_5_ROUND4_NARROW_BLOCK_RECHECK_RESULT_2026-08-27.md`
  (Round-4 BLOCK verdict that triggered the Round-5 dispatch)
- `Prompt/CODEX_REVIEW_033_V1_5_DERIVED_EDGE_BLOCK_RECHECK_2026-08-25.txt`
- `Prompt/CODEX_V15_ROUND3_FIX_GUIDANCE_2026-08-26.txt`

---

## 5. ROUND-5 IMPLEMENTATION SUMMARY

The current file records these material Round-5 changes.

### BLOCK-002A / BLOCK-004 — tolerance semantics (incl. exact-zero path)

`extension/su_ai_plugin/core/duplicate_geometry_semantics.rb`

- `valid_tolerance?(tolerance)` accepts `>= 0.0` (including exact 0.0).
  - `> 0` => tolerance-grid path (Round-4 contract preserved).
  - `== 0` => exact-match path (no grid math, no division).
  - missing / negative / NaN / Inf / non-numeric => invalid.
- `tolerance_category(tolerance)` returns `:positive | :zero | :invalid`.
- `enumerate_candidates(records, tolerance)` branches on category:
  - `:zero` => `enumerate_candidates_exact_zero(tuples)` — orientation-insensitive exact
    endpoint-pair hashing (lex-ordered two endpoint triples + normalized layer in the key;
    hash key -> records; enumerate every unique unordered pair within each bucket exactly
    once; shared `direct_match?` at tolerance 0.0 is final authority; stable pair
    ordering/dedup).
  - `:positive` => `enumerate_candidates_grid(tuples, tol)` (Round-4 contract preserved).
  - `:invalid` => `ArgumentError`.
- Captured 0.0 MUST NEVER become 0.0001 — no production fallback.

### BLOCK-001 — complete final live-handle proof

- `core/duplicate_repair_proposer.rb#verify_final_repairable_component` — runs the
  FINAL repairable-component eligibility proof against EVERY repairable component
  BEFORE any executable action is emitted. Per Round-5 §2 step 1–9: distinct
  derived_id; full leaf/occurrence identity; current host handle (missing OR
  `valid? != true` => failure); pairwise distinct by `equal?` (survivor/removal AND
  removal/removal); survivor appears exactly once and is not in removal set;
  finite/layer/tolerance guards. Failure => truthful `:skipped` audit row with
  stable reason code.
- `core/duplicate_repair_executor.rb#preflight_batch` + `#final_live_handle_proof` —
  re-runs the COMPLETE live-handle proof for the WHOLE executable batch
  IMMEDIATELY BEFORE `begin_operation`, AFTER expected-state validation. Per
  Round-5 §2 step 4: tolerance explicit; survivor handle resolves and `valid?`;
  every to_remove handle resolves and `valid?`; survivor/removed disjointness;
  pairwise distinct by `equal?`. Failure => atomic no-begin failure: begin=0, no
  disposal/commit, no applied rows, exact logical pre-state retained, no READY,
  truthful stable reason code.

### BLOCK-002B — genuine non-transitive regression

The production chain (Round-5 `V15-B002B-1`) exercises the 0/.75T/1.5T geometry
through the production detector, proposer, topology classifier, expected
post-state, validator, audit, runner, and UI summary. NO manual fabrication.

- tolerance = T > 0 (test uses T = 1.0);
- three edges offset by 0, 0.75T, 1.5T along the same axis (cumulative);
- therefore A~B, B~C, A!~C;
- expected outcome: exactly 2 direct pairs; one connected non-transitive
  component; 0 executable/destructive actions; exactly 1 skipped whole-component
  row; member IDs exactly once; logical and host geometry unchanged; workspace
  remains `:ready`.

### BLOCK-003 — expected post-state + transaction (incl. invariant I + precommit)

`core/duplicate_repair_expected_post_state.rb#validate!` enforces A–I:
- A. exact inventory transition;
- B. each removed ID disappears exactly once;
- C. each survivor remains exactly once;
- D. exact deterministic provenance union (non-empty is insufficient);
- E. canonical fingerprint consistency;
- F. handle identity shape valid AND survivor/removal AND removal/removal disjoint;
- G. every applied complete-graph component collapses to exactly one survivor;
- H. all expected handles exist/live and pairwise disjoint;
- I. zero direct duplicate pairs belonging to every APPLIED component remain in
  expected post geometry — measured via
  `DuplicateGeometrySemantics.enumerate_candidates(survivor_records, tol)` on the
  survivors of applied actions.

Host sequence (`core/duplicate_repair_executor.rb#apply_batch_atomic`):
1. build expected post-state;
2. validate A-I;
3. run final live-handle proof (BLOCK-001 step 4);
4. begin exactly once;
6. PRECOMMIT host-shape observation (BLOCK-003 step 6):
   - survivors still live/valid;
   - planned removals observably no longer live/valid;
   - identities still match the proven batch;
   - no survivor accidentally disposed;
   - mismatch => abort exactly once, commit=0, no post-state publish, exact logical
     pre-state, failed/non-ready;
7. match => commit exactly once;
8. after confirmed commit publish exactly the PREVALIDATED logical post-state/fingerprint;
9. commit raise / uncertainty => workspace `:failed`, no fabricated rollback, evidence preserved.

### BLOCK-004 — audit / READY

- captured tolerance flows through detector -> proposer -> expected post-state ->
  validator -> audit metrics -> UI summary (no silent fallback);
- pre-execution `:skipped` actions are preserved end-to-end;
- pair metric is the authoritative report (measured via
  `DuplicateGeometrySemantics.count_direct_pairs(records, tol)`), NOT a surrogate;
- READY semantics: workspace `:ready` MAY coexist with truthful `:skipped`
  ambiguous components; MUST NOT coexist with: applied action whose expected
  post-state failed; host/logical divergence; invalid/stale handle proof; remaining
  direct duplicate pair belonging to an APPLIED repairable component; failed
  batch invariant.

### BLOCK-005 — production Owner path + host-change reconciliation

- `WorkingModeRunner.reset_for_tests` is TEST-ONLY and never used by any
  production Owner flow. Owner verification uses normal
  prepare / run_duplicate_repair_batch / discard / rebuild / prepare.
- `validate_host_state_consistency!` runs at the start of `prepare`, `discard`,
  `rebuild`, and `run_duplicate_repair_batch`. It inspects:
  - the stored handle registry against the observable host (every handle must be
    live/valid; missing or `valid? != true` => inconsistent);
  - the captured `adapter.host_state_changed?` flag (defaults false; the
    `FakeDerivedWorkspaceAdapter` exposes `simulate_host_state_change!` /
    `clear_host_state_change!` for deterministic tests);
  - the workspace's `:ready` state with an empty handle registry (incoherent).
- mismatch => workspace transitions to `:failed` with stable reason
  `host_state_changed`, duplicate-repair summary cleared, destructive work NOT
  attempted.
- discard -> user Undo -> next plugin interaction: `validate_host_state_consistency!`
  detects mismatch (adapter flag set) and refuses to continue destructive work.
- rebuild after `:failed`: explicit `discard` then `prepare` rebuilds coherent
  inventory/handles/UI; the prior `:failed` workspace's private handle_registry is
  preserved until the explicit discard.

---

## 6. CODEX RECHECK BOUNDARY

The next Codex engagement (when dispatched by AIPM) is a
**BLOCK RECHECK**, not a new full Stage review.

Reasoning effort:
**xHigh**

Review only:
- the active V1.5 BLOCK set;
- the Round-5 fix diff;
- direct dependencies;
- directly affected regressions;
- adjacent seams materially changed by the Round-5 fix.

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

### Immediate
1. AIPM reviews the Round-5 Pi packet
   (`Review/CURRENT_PI_REPORT.md`).
2. AIPM republishes the canonical Owner verification file
   `Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`
   (BLOCK-005 deliverable, Pi is not the author).
3. AIPM dispatches the next Codex narrow xHigh recheck.

### If Codex PASS
1. close the V1.5 active BLOCK set;
2. AIPM determines whether the current Owner real-SketchUp verification path is
   technically ready;
3. Owner runs the approved real-host verification;
4. AIPM reviews the result and formally closes V1.5 when acceptance evidence is
   sufficient;
5. AIPM designs and freezes `V1.6` Stage Technical Blueprint;
6. only then dispatch Pi into V1.6.

### If Codex remains BLOCKED
1. Codex reports only remaining/new causally related material BLOCKs;
2. Codex provides evidence + minimum acceptable outcome + recheck evidence;
3. control returns to AIPM;
4. AIPM updates technical Guidance / Blueprint as required;
5. Pi implements one coherent fix packet;
6. Codex performs one narrow recheck.

---

## 8. PRODUCT / UX STATUS

V1.5 Owner verification:
**BLOCKED pending AIPM Owner-checklist republication + Codex PASS.**

No current evidence in this file supports:
- Owner PASS for the Round-5 artifact;
- V1.5 formal completion;
- V1.6 start authorization;
- release readiness.

V1.4 remains previously closed on its verified scope.

---

## 9. TECHNICAL DESIGN STATUS

Project-level architecture:
**Frozen by `PROJECT_MASTER_PLAN_V1X.md`.**

Current V1.5:
- legacy Stage that began before the V3.1 Stage-Blueprint workflow was fully adopted;
- do not retroactively invent a fake Blueprint and pretend it governed earlier work;
- Round-4 closes the existing BLOCK recheck honestly within the frozen
  `AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md` design;
- Round-5 closes the existing BLOCK recheck honestly within the frozen
  `AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND5_BLOCK_FIX_2026-08-27.md` design.

V1.6:
- requires a new AIPM Stage Technical Blueprint before any implementation begins.

Pi may not fill V1.6 architecture gaps independently.

---

## 10. TOOLCHAIN / ENVIRONMENT

Preferred Ruby test environment:

`.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe`

Known host issue:
- `C:\Ruby27-x64\bin\ruby.exe` is recorded as broken on this host due to Windows
  runtime/SxS problems.

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
- reinstall Ruby or rewrite global PATH merely because one shell path fails.

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
- V1.5 Round-3 (frozen evidence, superseded by Round-4 for the active BLOCK set)
- V1.5 Round-4 (frozen evidence, superseded by Round-5 for the active BLOCK set)

Historical Review/Prompt artifacts remain evidence only.

Do not use old "next action", "greenlight", "active directive",
or old test baseline text from archived sections as current truth.

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
`Prompt/CURRENT_PI_DISPATCH.md -> Pi -> Review/CURRENT_PI_REPORT.md -> AIPM`

There is currently no active Pi implementation dispatch.

Current exception:
V1.5 is inside an active Codex BLOCK recheck cycle that has
advanced through Round-3 (Codex BLOCK verdict) -> AIPM Round-4
Guidance + PI_TASK dispatch -> Pi Round-4 implementation
(history) -> AIPM review -> AIPM Owner-checklist publication ->
Codex Round-4 narrow recheck -> Round-4 BLOCK verdict ->
AIPM Round-5 Guidance + CURRENT_PI_DISPATCH dispatch ->
Pi Round-5 implementation (this update) -> awaiting AIPM review
-> AIPM Owner-checklist republication -> Codex narrow recheck ->
closure / next fix.

Pi is **STOPPED** awaiting AIPM review.

---

# One-Line Current State

**V1.5 Round-5 implementation is complete, fully test-green in
the recorded automated evidence, and documented in
`Review/CURRENT_PI_REPORT.md`; its five active BLOCKs are addressed
but still awaiting AIPM review + Owner-checklist republication +
Codex narrow recheck; Pi is stopped; V1.6 must wait for AIPM/Owner
closure and a new AIPM V1.6 Technical Blueprint.**