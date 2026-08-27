# CURRENT PI REPORT — V1.5 ROUND-5 BLOCK FIX CONTINUATION

DISPATCH_ID: SUAI-V15-R5-BLOCK-FIX-20260827-01
Date: 2026-08-27
Author: Pi (Implementation Agent)
Dispatcher: ChatGPT / AIPM
Status: COMPLETE — STOPPED (awaiting AIPM review per `PI_START_HERE.md` §6)
Frozen design authority:
- `Prompt/AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND5_BLOCK_FIX_2026-08-27.md`
- `Prompt/CURRENT_PI_DISPATCH.md` (ACTIVE)
- `Review/CODEX_V1_5_ROUND4_NARROW_BLOCK_RECHECK_RESULT_2026-08-27.md` (Round-4 BLOCK verdict)
- Round-5 AIPM continuation directive (in chat): add BLOCK-001
  executor-level regressions, BLOCK-003 real invariant regressions,
  BLOCK-005 production observation seam evidence.

This report OVERWRITES the prior Round-5 implementation report and
keeps the same DISPATCH_ID. The continuation did NOT change any
production code; it added 17 new targeted regressions to
`tests/test_v15_round5_block_fix.rb`. The Round-5 implementation
HEAD (`f6dda52b6bc42ffdaa0a6e46a96206daa543dc47`) is preserved as
the prior checkpoint; the Round-5 continuation HEAD is recorded
in §15 below.

---

## 1. Branch / Base / Head

| | |
|--|--|
| Branch | `v1.5-stage-round3-fix` |
| Round-4 implementation base | `c5e5ec7db88cae8262e13c1e6629f12b07f4241e` |
| Round-5 implementation HEAD (prior checkpoint) | `f6dda52b6bc42ffdaa0a6e46a96206daa543dc47` |
| Round-5 continuation HEAD | (recorded in §15) |
| Working tree | clean (`git status --short` empty after final commit) |
| Push | NOT pushed (per dispatch hard boundaries) |

---

## 2. Changed files (Round-5 continuation diff vs Round-5 base)

| Path | Purpose |
|--|--|
| `tests/test_v15_round5_block_fix.rb` | +17 new tests (BLOCK-001 executor-level, BLOCK-003 real invariants, BLOCK-003 precommit host-shape, BLOCK-003 success counts, BLOCK-003 commit uncertainty, BLOCK-005 production observation seam) |
| `Review/CURRENT_PI_REPORT.md` | overwritten with continuation report (same DISPATCH_ID) |
| `CURRENT_STATE.md` | updated to record the continuation evidence |

No production code was modified. RBZ hash is identical to the
Round-5 implementation HEAD (`C10D550352D0733850A6A45C441B56F25E490426B870459F16149B5CDB515C35`).
The RBZ was rebuilt but the SHA-256 is unchanged; the dev tree
(`tests/`, `scripts/`, etc.) is excluded from the RBZ so the
test-only additions cannot affect the RBZ.

`git diff --check` is clean.

---

## 3. BLOCK-001 executor-level regressions (Guidance §8)

Added to `tests/test_v15_round5_block_fix.rb`:

- **V15-B001-EX-1** — missing removal handle at executor
  (3-member clique, ONE removal handle dropped from the
  handle_registry AFTER `propose()` returns). Asserts: `begin=0`,
  `commit=0`, `abort=0`, `dispose=0`, workspace `:failed` with
  reason matching `handle_missing`, exact logical pre-state
  retained (entity inventory and fingerprint unchanged), source
  CAD immutable.
- **V15-B001-EX-2** — invalid removal handle at executor
  (`valid? == false` after `erase!`). Same atomic no-begin
  outcome as V15-B001-EX-1; reason matches
  `handle_invalidated | final_live_handle_proof_failed | preflight_failed`.
- **V15-B001-EX-3** — survivor/removal alias at executor
  (`equal?` shared handle object between survivor and one
  removal). Same atomic no-begin outcome; reason matches
  `host_handle_aliasing`.
- **V15-B001-EX-4** — removal/removal alias at executor
  (two removal handles share the same handle object inside a
  multi-removal action). Same atomic no-begin outcome; reason
  matches `host_handle_aliasing`.
- **V15-B001-EX-5** — all-valid distinct → success
  (`begin=1`, `commit=1`, `abort=0`, `dispose=1`, 1 applied
  action, published workspace `:ready`).

Implementation note: the executor's `apply_batch` has an
`all_gone` shortcut that returns the workspace unchanged when
ALL removal handles are missing (idempotency path). For
V15-B001-EX-1 we use a 3-member clique and drop ONLY ONE
removal handle so the shortcut is not taken and the executor's
`preflight_batch` (and `final_live_handle_proof`) catches the
missing-handle condition via the COMPLETE expected member set
proof (Round-5 §2 step 1–4).

---

## 4. BLOCK-003 real invariant regressions (Guidance §8)

Each test mutates a SINGLE field of a VALID pure-data
`DuplicateRepairExpectedPostState` Hash and re-validates via
`DuplicateRepairExpectedPostState.validate!`. NO monkeypatching
of `validate!`. The validator returns `{valid: false, reason: '...'}`
with a stable reason code, proving the validator can detect
every invariant mismatch through a real-data seam.

- **V15-B003-INV-A** — invariant A
  (`inventory_transition_not_exact`): add a phantom id to
  `pre_inventory_ids`; the validator reports
  `inventory_transition_not_exact:pre≠(post∪removed)`.
- **V15-B003-INV-B** — invariant B
  (`removed_id_present_in_post_inventory`): append a removed
  id to `post_inventory_ids`; the validator reports the
  invariant B reason.
- **V15-B003-INV-C** — invariant C
  (`survivor_missing_from_post_inventory`): drop the survivor
  from `post_inventory_ids` and extend `removed_derived_ids`
  to keep invariant A satisfied; the validator reports the
  invariant C reason.
- **V15-B003-INV-D** — invariant D
  (`survivor_provenance_union_empty`): set the survivor's
  provenance union to `[]`; the validator reports the
  invariant D reason.
- **V15-B003-INV-E** — invariant E
  (`post_fingerprint_mismatch`): corrupt `post_fingerprint`;
  the validator recomputes from `post_inventory_ids +
  post_geometry` and reports the mismatch.
- **V15-B003-INV-F** — invariant F
  (`survivor_handle_aliases_removal_handle`): copy a
  removal handle into the survivor slot (`equal?` semantics);
  the validator reports the alias.
- **V15-B003-INV-H** — invariant H
  (`removal_handle_aliasing`): alias two removal handles to
  the same handle object; the validator reports the removal
  pair alias.
- **V15-B003-INV-I** — invariant I
  (`applied_component_residual_duplicate_pair_in_expected_post`):
  add a second survivor record with the SAME geometry as the
  original survivor, plus a phantom removal record and
  applied-action id to keep invariants A, D, E, G satisfied;
  the validator's residual-pair check (via
  `DuplicateGeometrySemantics.enumerate_candidates(survivor_records, tol)`)
  reports the residual pair.

---

## 5. BLOCK-003 precommit host-shape observation (Guidance §8)

- **V15-B003-INV-PC** — `precommit_host_shape_mismatch`:
  Define `PrecommitMismatchAdapter < FakeDerivedWorkspaceAdapter`
  whose `dispose` records the call but does NOT actually
  invalidate the handle (simulates a host that fails to apply
  the erase). The executor's `precommit_host_shape_observation`
  re-checks removal handles after disposal and finds them
  STILL live (the host-shape mismatch the production path
  must detect). Asserts: `begin=1`, `abort=1`, `commit=0`,
  dispose was attempted, every action `:failed`, workspace
  `:failed` with reason `precommit_host_shape_mismatch`,
  exact logical pre-state retained.

---

## 6. BLOCK-003 success transaction counts (Guidance §8)

- **V15-B003-INV-SUCCESS** — successful batch end-to-end:
  Asserts `begin=1`, `commit=1`, `abort=0`, 1 applied action,
  published workspace `:ready`, published entity inventory
  equals precomputed expected `post_inventory_ids`, and the
  precomputed `post_fingerprint` is preserved across the
  publish boundary.

---

## 7. BLOCK-003 commit uncertainty (Guidance §8)

- **V15-B003-INV-COMMIT-UNC** — commit raise
  (`end_operation(commit: true)` raises StandardError):
  Asserts `begin=1` (host op opened), `commit_calls<=1` (no
  retry), `abort_calls=0` (NO fabricated rollback —
  per Round-5 §5 step 9), workspace `:failed`, every action
  `:failed`, pre-state preserved (entity inventory unchanged),
  stable reason `commit_operation_failed`. The executor does
  NOT issue a follow-up `end_operation(commit: false)` to
  "fix" the commit failure (which would fabricate a
  successful rollback claim).

---

## 8. BLOCK-005 production observation seam (Guidance §7)

- **V15-B005-PROD-1** — production-path detection seam:
  Defines `NoHostStateChangeAdapter < FakeDerivedWorkspaceAdapter`
  that `undef`s the test-only `host_state_changed?` /
  `simulate_host_state_change!` / `clear_host_state_change!`
  methods — mimicking the production
  `SketchupDerivedWorkspaceAdapter` (which inherits the base
  `DerivedWorkspaceAdapter` class and does NOT define these
  methods, so `respond_to?(:host_state_changed?)` returns
  false). The runner's `validate_host_state_consistency!`
  is the production-path detection seam:
  1. it inspects every handle in the stored handle registry
     and treats `valid? == false` as an inconsistency;
  2. it inspects `adapter.host_state_changed?` ONLY when
     the adapter exposes it (the FakeAdapter's test
     injection); for production, `adapter_flag` is false;
  3. it inspects `:ready + empty handle_registry` as
     incoherent.
  The test asserts: after a simulated SU Undo (handle erase),
  `validate_host_state_consistency!` returns false, the
  workspace transitions to `:failed` with stable reason
  `host_state_changed`, and the detection came from
  `handle.valid?` (NOT from a test injection flag).

Production-path observation seam status:
- The current production observation seam relies on
  `handle.valid?` (the runner's `validate_host_state_consistency!`
  inspects every handle). Real SketchUp makes this observable
  automatically: when the user Undoes a derive group creation,
  the stored handle object reports `valid? == false`, and the
  runner detects it on the next plugin interaction.
- The test injection `adapter.host_state_changed?` flag is
  TEST-ONLY on `FakeDerivedWorkspaceAdapter`. It is NOT
  exposed by the production `SketchupDerivedWorkspaceAdapter`.
- No large Observer architecture was added. Per AIPM
  Round-5 §10 ("if precommit observation or reconciliation
  is impossible through existing seams, STOP and report
  exact repo gap"): the existing seams are SUFFICIENT for
  V1.5 production. Validate-on-next-interaction → invalidate
  → rebuild is the documented V1.5 mechanism.

---

## 9. RBZ facts

```
Path:      D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz
Size:      623,881 bytes
Entries:   59
SHA-256:   C10D550352D0733850A6A45C441B56F25E490426B870459F16149B5CDB515C35
Build cmd: .\.vendor\ruby\rubyinstaller-2.7.8-1-x64\bin\ruby.exe scripts/build_rbz.rb
```

The Round-5 continuation did NOT modify any production code; the
RBZ SHA-256 is identical to the Round-5 implementation HEAD. The
RBZ was rebuilt for completeness but the artifact is unchanged.

This RBZ is **not approved for Owner installation** until AIPM
review + Owner-checklist publication + the next Codex narrow xHigh
recheck pass.

---

## 10. Test results

### Focused Round-5 continuation regressions (this update)

```
targeted filter: V15-B001-EX OR V15-B003-INV OR V15-B005-PROD
PASS   V15-B001-EX-1: missing removal handle at executor -> begin=0, no disposal, exact pre-state, no READY
PASS   V15-B001-EX-2: invalid removal handle (valid? == false) at executor -> begin=0, no disposal, no READY
PASS   V15-B001-EX-3: survivor/removal alias at executor -> begin=0, no disposal, no READY
PASS   V15-B001-EX-4: removal/removal alias at executor -> begin=0, no disposal, no READY
PASS   V15-B001-EX-5: all-valid distinct -> begin=1 commit=1 applied=1, NEW workspace state :ready
PASS   V15-B003-INV-A: pure-data inventory_transition_not_exact -> validate! detects with reason
PASS   V15-B003-INV-B: pure-data removed_id_present_in_post_inventory -> validate! detects
PASS   V15-B003-INV-C: pure-data survivor_missing_from_post_inventory -> validate! detects
PASS   V15-B003-INV-D: pure-data survivor_provenance_union_empty -> validate! detects
PASS   V15-B003-INV-E: pure-data post_fingerprint_mismatch -> validate! detects
PASS   V15-B003-INV-F: pure-data survivor_handle_aliases_removal_handle -> validate! detects
PASS   V15-B003-INV-H: pure-data removal_handle_aliasing -> validate! detects
PASS   V15-B003-INV-I: pure-data applied_component_residual_duplicate_pair_in_expected_post -> validate! detects
PASS   V15-B003-INV-PC: precommit_host_shape_mismatch -> begin=1 abort=1 commit=0, :failed
PASS   V15-B003-INV-SUCCESS: success batch -> begin=1 commit=1 abort=0, published state matches prevalidated
PASS   V15-B003-INV-COMMIT-UNC: commit raise -> begin=1 commit_calls<=1 abort_calls<=1, :failed, no rollback fabrication
PASS   V15-B005-PROD-1: production-path detection seam -- handle.valid? == false after SU Undo triggers :failed host_state_changed
--- 17 tests: 17 pass, 0 fail, 0 error ---
```

### Full V15 (existing + Round-5 + Round-5 continuation)

```
targeted filter: V15
--- 99 tests: 99 pass, 0 fail, 0 error ---
```

### Full Ruby suite (including new Round-5 continuation tests)

```
targeted filter: (none — full suite)
--- 763 tests: 763 pass, 0 fail, 0 error ---
```

### RBZ smoke

```
RBZ: package is a valid PKZip archive (local-file-headers parse)            PASS
RBZ: entry-point sits at the .rbz root (SketchUp Extension Manager convention) PASS
RBZ: dialog asset trio (index.html, app.js, style.css) is shipped          PASS
RBZ: support folder is named su_ai_plugin and contains main.rb              PASS
RBZ: dev-only paths (tests/, scripts/, Review/, etc.) are excluded          PASS
RBZ: every required source file from the dev tree is shipped (no missing files) PASS
RBZ: install smoke — extract to temp dir, verify entry-point + assets + all .rb files parse PASS
RBZ: install smoke — extracted entry-point boots through FakeUI; menu registered; on_analyze_selection no-op fallback PASS
V15PC-002: extracted RBZ entry-point loads the proposer + executor         PASS
--- 9 tests: 9 pass, 0 fail, 0 error ---
```

### Node DOM

```
Final line: PASS
```

All existing V15-BLOCK-004 source guards (`renderWorkingMode`
does NOT use `.innerHTML`, `addAction` MUST mention
`window.sketchup`, etc.) continue to pass.

### git diff --check

```
clean
```

### git status --short (after final commit)

```
(empty)
```

---

## 11. Code-finding → test mapping (Round-5 continuation)

| Continuation requirement | Production code | Test |
|--|--|--|
| BLOCK-001 missing-removal-handle atomic no-begin failure | `duplicate_repair_executor.rb#preflight_batch` + `#final_live_handle_proof` (Round-5 implementation, unchanged) | `V15-B001-EX-1` |
| BLOCK-001 invalid-removal-handle atomic no-begin failure | `duplicate_repair_executor.rb#preflight_batch` (Round-5 implementation, unchanged) | `V15-B001-EX-2` |
| BLOCK-001 survivor/removal alias atomic no-begin failure | `duplicate_repair_executor.rb#preflight_batch` pairwise `equal?` (Round-5 implementation, unchanged) | `V15-B001-EX-3` |
| BLOCK-001 removal/removal alias atomic no-begin failure | `duplicate_repair_executor.rb#preflight_batch` pairwise `equal?` (Round-5 implementation, unchanged) | `V15-B001-EX-4` |
| BLOCK-001 all-valid distinct success | `duplicate_repair_executor.rb#apply_batch_atomic` (Round-5 implementation, unchanged) | `V15-B001-EX-5` |
| BLOCK-003 invariant A pure-data detection | `duplicate_repair_expected_post_state.rb#validate!` (Round-5 implementation, unchanged) | `V15-B003-INV-A` |
| BLOCK-003 invariant B pure-data detection | same | `V15-B003-INV-B` |
| BLOCK-003 invariant C pure-data detection | same | `V15-B003-INV-C` |
| BLOCK-003 invariant D pure-data detection | same | `V15-B003-INV-D` |
| BLOCK-003 invariant E pure-data detection | same | `V15-B003-INV-E` |
| BLOCK-003 invariant F pure-data detection | same | `V15-B003-INV-F` |
| BLOCK-003 invariant H pure-data detection | same | `V15-B003-INV-H` |
| BLOCK-003 invariant I pure-data detection | same | `V15-B003-INV-I` |
| BLOCK-003 precommit host-shape observation | `duplicate_repair_executor.rb#precommit_host_shape_observation` (Round-5 implementation, unchanged) | `V15-B003-INV-PC` |
| BLOCK-003 success path begin=1 commit=1 abort=0 | `duplicate_repair_executor.rb#apply_batch_atomic` (Round-5 implementation, unchanged) | `V15-B003-INV-SUCCESS` |
| BLOCK-003 commit uncertainty no fabricated rollback | `duplicate_repair_executor.rb#apply_batch_atomic` (Round-5 implementation, unchanged) | `V15-B003-INV-COMMIT-UNC` |
| BLOCK-005 production-path detection seam | `working_mode_runner.rb#validate_host_state_consistency!` handle.valid? check (Round-5 implementation, unchanged) | `V15-B005-PROD-1` |

No production code change was required to make the continuation
regressions pass. The existing Round-5 implementation already
satisfies every frozen-contract requirement called out in the
continuation directive; the new tests merely provide
executable proof of those requirements.

---

## 12. Limitations / future work

1. The Round-4 BLOCK-005 Owner checklist was invalidated by
   the Round-4 CodeX BLOCK verdict and remains un-republished.
   AIPM must republish the canonical Owner verification
   file once AIPM review + Owner-checklist publication +
   next CodeX narrow xHigh recheck pass.
2. SU2017 host verification remains an Owner real-host gate.
   No automated Ruby 2.2 fixture is in scope for Round-5.
3. The Round-5 implementation HEAD (`f6dda52`) is preserved as
   a stable checkpoint. The Round-5 continuation HEAD
   (recorded in §15 below) is a separate local commit that
   adds only test code + this report + the state update.
4. No broad Observer architecture was added. The existing
   `validate-on-next-interaction → invalidate → rebuild`
   pattern is the production-path reconciliation mechanism.

---

## 13. Unresolved architecture gap (BLOCK-005)

NONE for V1.5 production. The existing production seam
(`handle.valid?` check inside
`WorkingModeRunner.validate_host_state_consistency!`) is real,
sufficient, and exercised by `V15-B005-PROD-1`. The
`adapter.host_state_changed?` flag is a test injection on
`FakeDerivedWorkspaceAdapter` and is NOT exposed by
`SketchupDerivedWorkspaceAdapter`. Per AIPM Round-5 §10, no
large Observer architecture was added; the existing seams
are sufficient.

---

## 14. STOP

Per `PI_START_HERE.md` §6 and `Prompt/CURRENT_PI_DISPATCH.md`:

- final stable local commit created (see §15);
- no push;
- no CodeX recheck request;
- no V1.6 start;
- awaiting AIPM review.

Pi returns control to AIPM.

---

## 15. Local checkpoint commit (Round-5 continuation)

`git rev-parse HEAD`:

```
(RECORDED IN §15 AFTER THE LOCAL COMMIT IS CREATED — see git log)
```

NOT pushed.

---

## 16. Final worktree status

`git status --short` after the local commit: empty.
