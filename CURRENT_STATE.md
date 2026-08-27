# SU-AI-Plugin — CURRENT STATE

Updated: 2026-08-27
Project: `D:\Projects\SU-AI-Plugin`

Current stage: **V1.5 — High-confidence Auto Repair / Round-4 BLOCK fix**
Current status: **IMPLEMENTATION PACKET COMPLETE — AWAITING AIPM REVIEW (no Codex recheck request from Pi; awaiting Codex narrow recheck per AIPM dispatch)**
Next stage: **V1.6 — NOT STARTED**

Canonical durable context:
- `AGENTS.md`
- `PROJECT_HANDOFF.md`
- `PROJECT_MASTER_PLAN_V1X.md`

Current project rule:
- AIPM owns product + technical design, primary review, and dispatch.
- Pi executes the frozen design.
- Codex is used only for legitimate mandatory / high-risk repo-aware review.
- This V1.5 Round-4 case has reached the end of Pi's execution window.
  Pi is STOPPED. AIPM review + the next Codex narrow recheck are
  the next gates per PROJECT_MASTER_PLAN_V1X.md §13.

---

## 1. ACTIVE STATUS

### Completed
- V1.0–V1.4 remain closed on their previously verified scope.
- V1.5 Round-3 implementation/fix packet is complete (history).
- V1.5 Round-4 BLOCK fix packet is complete (THIS UPDATE).
- Round-4 code, test updates, documentation, and supporting
  helper modules are committed (local stable checkpoint).
- Automated evidence, RBZ rebuild, and Node DOM suite all PASS
  end-to-end for the Round-4 candidate.

### In progress
- Nothing is currently being implemented by Pi.

### Waiting
- AIPM review of the Round-4 Pi packet
  (`Review/V1_5_ROUND4_BLOCK_FIX_RECHECK_PACKET_2026-08-27.md`).
- AIPM publication of the authoritative Owner verification file
  (`Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`,
  per AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27 §7).
- Codex narrow xHigh recheck of the V1.5 BLOCK set
  (V15-STAGE-BLOCK-001..005), dispatched only AFTER AIPM review
  and Owner-checklist publication.

### Not started
- V1.6 Planar Normalization / Z Policy.

V1.6 must not begin until:
1. V1.5's active BLOCK set is formally closed;
2. required Owner verification for V1.5 is completed as applicable;
3. AIPM creates and freezes a V1.6 Stage Technical Blueprint;
4. AIPM dispatches a new PI_TASK.

---

## 2. CURRENT GIT / BUILD STATE

Current branch:
`v1.5-stage-round3-fix`

Governance migration base HEAD (pre-Round-4 carrier of this
`CURRENT_STATE.md`):
`43854c879a1c1fcb57bcd2bea7743c02e73d0c05`

Round-2 base:
`7283a830c0eb8979ad5c78ced30d8cffc790bc75`

Round-3 implementation commit:
`5ac83ea`

Round-3 documentation / report evidence:
- `fae3518` - recheck packet post-commit evidence;
- `6f5df97` - state update recording the Round-3 fix packet;
- `43854c8` - unattended final report awaiting the narrow
  Codex recheck.

Round-4 implementation HEAD:
`16dafce2ba91688b33511d5e7b8a351ace4fc88d`

(Commit message: `fix(v1.5-stage4-block-recheck): CodeX BLOCK-001..005
narrow-scope fixes (round 4)` — local stable checkpoint,
NOT pushed.)

Working tree (this Round-4 fix):
- Modified: 7 tracked files (`AGENTS.md` + 6 V1.5 core files
  + 1 test file).
- New untracked-then-committed: 2 helper modules
  (`duplicate_geometry_semantics.rb`,
  `duplicate_repair_expected_post_state.rb`).

Round-4 RBZ:

`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

Evidence recorded in this file:
- Size: 599,997 bytes
- Entries: 59
- SHA-256:
  `3D255BD5F6304440AD0C5030C8B52EEFA722CC0A27795B7F18F261DDAB0DE1BA`

Build command:
`.\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe scripts/build_rbz.rb`

This RBZ is **not approved for Owner installation** until the
AIPM Owner verification file is published AND the next Codex
narrow recheck passes.

---

## 3. CURRENT TEST EVIDENCE

Round-4 evidence (THIS UPDATE):

- Targeted Round-4 V15-BLOCK regressions (BLOCK-001..005):
  **20/20 PASS**
- Full V15: **65/65 PASS**
- Full Ruby suite: **729/729 PASS**
- Node DOM: **163/163 PASS** (164 PASS lines including the
  final summary `PASS`)
- `git diff --check HEAD`: clean
- `git diff --check` (working tree): clean
- RBZ smoke: 8/8 PASS

These are implementation/test evidence only.

They do not by themselves close the Codex BLOCK set, prove
real-host behavior, or substitute for Owner verification.

---

## 4. ACTIVE BLOCK / REVIEW STATUS

Active V1.5 BLOCK set:

- `V15-STAGE-BLOCK-001`
- `V15-STAGE-BLOCK-002`
- `V15-STAGE-BLOCK-003`
- `V15-STAGE-BLOCK-004`
- `V15-STAGE-BLOCK-005`

Status:

> **Addressed by the Round-4 Pi fix packet; awaiting AIPM review
> and Codex narrow recheck. NOT yet formally closed.**

Do not write "BLOCKs closed" until both gates pass.

Relevant Round-4 Pi packet:

`Review/V1_5_ROUND4_BLOCK_FIX_RECHECK_PACKET_2026-08-27.md`

Relevant frozen design references:

- `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`
- `Prompt/PI_TASK_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`

These are the authority artefacts for the Round-4 fix. They
do NOT override the existing project governance in
`AGENTS.md`, `PROJECT_HANDOFF.md`, and
`PROJECT_MASTER_PLAN_V1X.md`.

Historical Round-3 artefacts (still kept for audit):
- `Review/V1_5_ROUND3_FIX_RECHECK_PACKET_2026-08-26.md`
- `Prompt/CODEX_REVIEW_033_V1_5_DERIVED_EDGE_BLOCK_RECHECK_2026-08-25.txt`
- `Prompt/CODEX_V15_ROUND3_FIX_GUIDANCE_2026-08-26.txt`

---

## 5. ROUND-4 IMPLEMENTATION SUMMARY

The current file records these material Round-4 changes.

### Duplicate geometry semantics — single source of truth

New module:

`extension/su_ai_plugin/core/duplicate_geometry_semantics.rb`

It is the shared responsibility for:
- finite-point validation;
- tolerance validation;
- forward / reversed segment `direct_match?`;
- 3D grid cell candidate-pair enumeration (floor, BOTH endpoint
  cells, 27-neighbor search, stable unordered pair dedup,
  `direct_match?` as the final authority);
- unique-unordered direct-pair enumeration
  (`enumerate_direct_pairs`, `count_direct_pairs`) — the
  AIPM §6 metric.

Detector, proposer, validator, expected-post-state, and
working_mode_runner all flow through this module. No production
fallback to historical `1e-4`.

### Non-transitive topology decision

`extension/su_ai_plugin/core/derived_duplicate_topology.rb`

The destructive-action unit is no longer a maximal clique.
Bron-Kerbosch is retained only as a diagnostic helper. The
production decision is the connected-component / complete-
graph check:
- COMPLETE GRAPH → one action with deterministic survivor
  (lex-smallest `derived_id`).
- NON-COMPLETE → fail closed as ONE inspectable `:skipped`
  audit row with reason
  `non_transitive_duplicate_component`.

### Final repairable-component eligibility proof (BLOCK-001)

`extension/su_ai_plugin/core/duplicate_repair_proposer.rb#verify_final_repairable_component`

Every candidate repairable component passes the complete proof
BEFORE any executable action is emitted:
distinct `derived_id`, full leaf identity, distinct live
handles, survivor/removed handle disjointness, layer / tolerance
/ finite-coordinate guards, no repeated/aliased member.

`extension/su_ai_plugin/core/duplicate_repair_executor.rb#preflight_batch`
+ `apply_atomic` re-check the live-handle proof IMMEDIATELY
before opening the host operation.

### Complete expected post-state (BLOCK-003)

New module:

`extension/su_ai_plugin/core/duplicate_repair_expected_post_state.rb`

Pure-data expected post-state builder + invariant validator
(A..H per AIPM §5).

`apply_batch_atomic` builds the expected post-state, validates
it via `validate!`, and on success publishes the precomputed
logical post-state after a successful host commit. On any
failure path:
- begin_calls = 0 (the host operation never opens), OR
- commit raises / dispose fails → begin=1, commit=0,
  workspace `:failed`, audit row preserved.

### Audit truth and tolerance propagation (BLOCK-004)

Captured tolerance flows through execution_config →
detector → proposer → expected-post-state → validator →
audit metrics → UI summary. No silent fallback.

The runner's `duplicate_repair` summary carries:
- `duplicate_pairs_before`, `duplicate_pairs_after`
  measured via `DuplicateGeometrySemantics.count_direct_pairs`;
- `actions_applied`, `actions_skipped`, `actions_failed`;
- per-action audit rows including `action_id`, `status`,
  `removed_count`, `survivor_derived_id`,
  `source_occurrence_count`, `source_occurrence_ids`,
  `issue_ids`, `before_summary`.

Pre-execution `:skipped` actions are preserved end-to-end.

READY semantics: workspace `:ready` MAY coexist with truthful
`:skipped` ambiguous components. Workspace `:ready` MUST NOT
coexist with any of: applied action whose expected post-state
failed; host/logical divergence; invalid/stale handle proof;
remaining direct duplicate pair belonging to an APPLIED
repairable component; failed batch invariant.

### Owner verification path (BLOCK-005)

Pi does NOT write the authoritative Owner verification file.
Pi only provides the evidence prerequisites (see
`Review/V1_5_ROUND4_BLOCK_FIX_RECHECK_PACKET_2026-08-27.md`
§11). AIPM publishes the canonical checklist.

---

## 6. CODEX RECHECK BOUNDARY

The next Codex engagement (when dispatched by AIPM) is a
**BLOCK RECHECK**, not a new full Stage review.

Reasoning effort:
**xHigh**

Review only:
- the active V1.5 BLOCK set;
- the Round-4 fix diff;
- direct dependencies;
- directly affected regressions;
- adjacent seams materially changed by the Round-4 fix.

Keep unchanged V1.0–V1.4 scope closed.

Do not use this recheck to:
- design V1.6;
- reopen old passed scope;
- create a new post-PASS Codex greenlight;
- redesign the project roadmap;
- send a replacement architecture directly to Pi.

If a material design gap remains:
`Codex finding → AIPM technical design/Guidance → Pi fix → narrow Codex recheck`.

---

## 7. NEXT ACTION

### Immediate
1. AIPM reviews the Round-4 Pi packet
   (`Review/V1_5_ROUND4_BLOCK_FIX_RECHECK_PACKET_2026-08-27.md`).
2. AIPM publishes the canonical Owner verification file
   `Prompt/AIPM_OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-27.txt`
   (BLOCK-005 deliverable, Pi is not the author).
3. AIPM dispatches the next Codex narrow xHigh recheck.

### If Codex PASS
1. close the V1.5 active BLOCK set;
2. AIPM determines whether the current Owner real-SketchUp
   verification path is technically ready;
3. Owner runs the approved real-host verification;
4. AIPM reviews the result and formally closes V1.5 when
   acceptance evidence is sufficient;
5. AIPM designs and freezes `V1.6` Stage Technical Blueprint;
6. only then dispatch Pi into V1.6.

### If Codex remains BLOCKED
1. Codex reports only remaining/new causally related material
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
**BLOCKED pending AIPM Owner-checklist publication + Codex PASS.**

No current evidence in this file supports:
- Owner PASS for the Round-4 artifact;
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
  the frozen `AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27.md`
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
`Pi → AIPM`

Current exception:
V1.5 is inside an active Codex BLOCK recheck cycle that has
advanced through Round-3 (Codex BLOCK verdict) → AIPM Round-4
Guidance + PI_TASK dispatch → Pi Round-4 implementation
(this update) → awaiting AIPM review → AIPM Owner-checklist
publication → Codex narrow recheck → closure / next fix.

Pi is **STOPPED** awaiting AIPM review.

---

# One-Line Current State

**V1.5 Round-4 implementation is complete, fully test-green in
the recorded automated evidence, and documented in a Round-4
Pi packet; its five active BLOCKs are addressed but still
awaiting AIPM review + Owner-checklist publication + Codex
narrow recheck; Pi is stopped; V1.6 must wait for AIPM/Owner
closure and a new AIPM V1.6 Technical Blueprint.**
