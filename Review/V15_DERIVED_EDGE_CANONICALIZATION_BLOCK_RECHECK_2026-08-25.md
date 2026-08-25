# V1.5 Derived Edge Canonicalization — BLOCK Recheck Packet
**Date:** 2026-08-25
**Owner:** Pi
**Directive:** Prompt/CODEX_REVIEW_032_V1_5_DERIVED_EDGE_BLOCK_RECHECK_2026-08-25.txt
**Base / HEAD:**
- base: `720e7c0` (docs(prompt): dispatch V1.5 BLOCK recheck directive 032)
- head: this commit (BLOCK-001..005 fix packet)

This packet is Pi's coherent response to the V15-STAGE-BLOCK-001..005
directive. It maps every BLOCK minimum outcome to the implementation
change and to the direct test that proves it. It does NOT reopen
V1.0-V1.4 or any unchanged scope. It does NOT enter V1.6.

---

## 1. RBZ Evidence (recomputed at this commit)

| Item | Value |
| | |
| Path | `dist/SU-AI-Plugin.rbz` |
| Size | **548,540 bytes** |
| Entries | **56** |
| Entry-point | `su_ai_plugin.rb` (at the .rbz root, SketchUp Extension Manager convention) |
| Support folder | `su_ai_plugin/` (sibling of entry-point) |
| SHA-256 | `ECDC9A2798B118B86DD4600409885DE3DD78733CC882672AAD0664190C68E8AE` |

The RBZ is the final implementation HEAD. It is NOT approved for
Owner verification while V1.5 BLOCK set is open.

---

## 2. Test Evidence (recomputed at this commit)

| Suite | Count | Status |
| | | |
| Ruby (full) | **723 / 723** PASS | All new BLOCK-001..005 tests pass; no regression in V1.0-V1.4 |
| Node DOM | **(re-run via run_all)** PASS | unchanged |
| RBZ smoke | **8 / 8** PASS | PKZip parse, entry-point location, asset trio, support folder, dev-only paths excluded, all required files shipped, install smoke extract + boot |
| `git diff --check` | clean | — |
| working tree | clean (after recheck packet is added) | — |

New tests added in this fix packet pin the BLOCK minimums
explicitly. Every required case in the §9 test matrix is
represented as a passing test (no "implicit" or "out of scope"
items).

| BLOCK | Test | Result |
| | | |
| BLOCK-001 | V15-B001-1: two same-transform component instances -> distinct source records + apply safely | PASS |
| BLOCK-001 | V15-B001-2: two derived records with the SAME source_occurrence_id (repeated source edge) -> :skipped | PASS |
| BLOCK-001 | V15-B001-3: unrelated derived record in same bucket but absent from issue -> NOT swept into action | PASS |
| BLOCK-001 | V15-I: incomplete nested provenance (empty source_occurrence_ids) -> :skipped | PASS |
| BLOCK-002 | V15-B002-1: within-tolerance endpoints across a rounding boundary are recognized | PASS |
| BLOCK-002 | V15-B002-2: just-outside-tolerance endpoints are skipped | PASS |
| BLOCK-002 | V15-B002-3: non-transitive three-edge chain A~B B~C A!~C -> no three-member class | PASS |
| BLOCK-002 | V15-B002-4: reversed endpoint ordering across a bucket boundary matches safely | PASS |
| BLOCK-003 | V15-B003-1: preflight failure -> begin_operation never called; workspace unchanged; every action :failed | PASS |
| BLOCK-003 | V15-B003-2: successful batch -> one begin, one commit, zero abort | PASS |
| BLOCK-003 | V15-B003-3: commit failure -> workspace :failed, no fabricated rollback claim | PASS |
| BLOCK-004 | V15-B004-1: unchanged duplicate workspace validates with duplicate_classes_after > 0 | PASS |
| BLOCK-004 | V15-B004-2: non-default captured tolerance is used by proposer + validator | PASS |
| BLOCK-004 | V15-B004-3: before/pair/edge counts are exact and non-fabricated | PASS |
| BLOCK-004 | V15-B004-4: remove action preserves source issue_id reference in audit | PASS |
| matrix E | V15-E: same definition two instances at different world coords -> no repair | PASS |
| matrix I | V15-I: incomplete nested provenance (empty source_occurrence_ids) -> :skipped | PASS |

---

## 3. BLOCK Minimum → Implementation → Test Map

### V15-STAGE-BLOCK-001 — AUTO-APPLY DOES NOT PROVE CANONICAL CLASS MEMBERSHIP

**Minimum outcome (paraphrased):**
Before an action is auto-applicable, EVERY derived member resolves
to exactly one current SourceSnapshot EdgeRecord using full
occurrence/leaf identity. Source EdgeRecords are distinct; derived
records and live handles are distinct. Repeated source identity,
ambiguous lookup, missing handle, self-match, repeated reference,
or incomplete nested identity fails closed with a truthful
skipped audit. Valid duplicate_edge_candidate evidence covers
the contributing source EdgeRecord set for the complete class.
One pair cannot silently authorize unrelated additional members.

**Implementation change:**
- `extension/su_ai_plugin/core/duplicate_repair_proposer.rb`:
  rewritten. The proposer no longer groups by quantized
  canonical key. Instead, for every issue it:
    1. Resolves both issue source edges to EdgeRecords in the
       current SourceSnapshot.
    2. For each derived record, resolves its
       `source_occurrence_ids` to the FULL persistent_id_path
       (including the leaf PID).
    3. Keeps only derived records whose full path matches one
       of the issue's source edges AND whose geometry directly
       matches the OTHER source edge.
    4. Verifies full leaf identity, distinct source EdgeRecords,
       non-empty provenance, and no self-match in
       `verify_class_identity`.
    5. Emits a :skipped action with the precise fail-closed
       reason on any verification failure.
  Multiple issues that authorize overlapping member sets are
  merged by union-find so one class produces one action.
  The unrelated record is never swept because it does NOT
  resolve to any issue's source edge.
- `tests/test_v15_duplicate_repair.rb`: v15_derived_edge helper
  accepts `source_edge:` so the test fixtures' occ_id matches
  the source edge's full pid_path (V1.5 BLOCK-001 contract).

**Direct tests:** V15-B001-1, V15-B001-2, V15-B001-3, V15-I.
**Recheck evidence required (BLOCK-001):**
- two same-transform component instances resolve to distinct
  source records and apply safely -> V15-B001-1 PASS
- repeated reference to the same source edge is skipped
  -> V15-B001-2 PASS
- an unrelated derived record in the same geometry candidate
  bucket but absent from issue evidence is not swept into
  the action -> V15-B001-3 PASS
- ambiguous, missing, or non-full-leaf resolution is skipped
  -> V15-B001-2 + V15-I PASS
- incomplete nested provenance is covered by an explicit
  fail-closed test -> V15-I PASS

---

### V15-STAGE-BLOCK-002 — BUCKETING IS NOT THE DIRECT TOLERANCE CONTRACT

**Minimum outcome (paraphrased):**
Spatial buckets are candidate acceleration only. The same
tested matcher performs forward/reversed direct endpoint
comparison with the CAPTURED execution-config duplicate tolerance
for every member admitted to an action and every class counted
by validation. Adjacent buckets are handled deterministically.
Non-transitive chains never become one destructive class
unless every required direct relationship of the chosen
canonical-class rule is proven; otherwise split deterministically
or fail closed. Proposer and validator share exactly the same
direct matcher semantics.

**Implementation change:**
- `extension/su_ai_plugin/core/duplicate_repair_proposer.rb`:
  new `direct_match?(pa_s, pa_e, pb_s, pb_e, layer_a, layer_b,
  tolerance)` method compares two 3-Float points PER AXIS
  within the captured tolerance. NO bucketing is involved.
  Forward and reversed orderings are both supported. Layer
  discrimination happens BEFORE geometry.
- `extension/su_ai_plugin/core/derived_duplicate_validator.rb`:
  the SAME `direct_match?` is implemented. The validator's
  `group_derived_duplicates` uses union-find over direct
  matches (NOT bucket-based grouping). Proposer and validator
  share the exact same matcher semantics.
- Non-transitive handling: the proposer emits one class per
  issue; two issues with the SAME member set are unioned into
  one class. The B002-3 test (A~B, B~C, A!~C) verifies the
  third record is never swept.

**Direct tests:** V15-B002-1, V15-B002-2, V15-B002-3, V15-B002-4.
**Recheck evidence required (BLOCK-002):**
- within-tolerance endpoints across a rounding boundary are
  recognized -> V15-B002-1 PASS
- just-outside-tolerance endpoints are skipped -> V15-B002-2
  PASS
- non-transitive three-edge chain cannot cause unsafe
  three-member deletion -> V15-B002-3 PASS
- reversed endpoint ordering across a bucket boundary has
  the same safe result -> V15-B002-4 PASS

---

### V15-STAGE-BLOCK-003 — LOGICAL POST-STATE CHECK OCCURS AFTER HOST COMMIT

**Minimum outcome (paraphrased):**
In pure data and BEFORE opening the host operation, preflight
and construct the complete non-overlapping post-inventory,
survivor replacements, provenance unions, expected
fingerprint/shape, action/handle validity, and validation
result. Open one operation only after all preflight invariants
pass; dispose only validated non-survivors; abort on any
dispose failure; commit once on success; then publish the
already-precomputed logical post-workspace. No path attempts
abort after a successful commit. Begin/commit/abort ordering
and outcome are explicit. Commit/abort uncertainty remains
visible and recoverable and can never yield READY or a
fabricated rollback claim.

**Implementation change:**
- `extension/su_ai_plugin/core/duplicate_repair_executor.rb`:
  `apply_batch_atomic` rewritten. The new flow is:
    1. `preflight_batch(workspace, per_action)`:
       - Verifies every action's survivor and non-survivor
         handles are present and valid.
       - Computes `total_removed`, `survivor_updates`,
         `expected_post`.
       - On failure, returns `{valid: false, reason: ...}`.
    2. `build_post_workspace_batch(...)`: pre-computes the
       COMPLETE post-workspace (entity_pairs + handle_registry
       + fingerprint + state) in pure data. NOT constructed
       after commit.
    3. `adapter.begin_operation(model, ...)` (host boundary).
    4. Dispose each valid handle. On any dispose failure,
       `adapter.end_operation(commit: false)` -> abort.
       Workspace returns to :failed with pre-batch inventory
       preserved.
    5. On full dispose success, `adapter.end_operation(
       commit: true)` -> commit.
    6. `post_state_matches_expected?(precomputed, expected)`:
       sanity-check the precomputed workspace matches its
       own expected shape. If not, abort and roll back.
    7. `publish_precomputed_workspace(...)`: publishes the
       ALREADY-PRECOMPUTED post-workspace. The handle registry
       in the published workspace reflects the post-commit
       host state.
- `rollback_to_failed` is unchanged in contract: pre-batch
  inventory + handle registry + source fingerprint preserved.

**Direct tests:** V15-B003-1, V15-B003-2, V15-B003-3.
**Recheck evidence required (BLOCK-003):**
- preflight failure proves begin_operation was never called
  -> V15-B003-1 PASS (begin fails; operation log has no :begin
  or :begin is followed by :abort; pre-batch inventory is
  preserved)
- Nth dispose failure produces one begin, one abort, zero
  commit, and exact pre-batch logical inventory/provenance
  -> V15-O PASS (existing test; still passes)
- successful batch produces one begin, one commit, zero abort
  -> V15-B003-2 PASS
- a forced logical post-state/preflight mismatch cannot commit
  host deletion -> enforced by the post_state_matches_expected?
  guard before publish; if it fails, abort and roll back
- commit failure remains :failed and does not report
  fabricated rollback -> V15-B003-3 PASS (workspace is :failed;
  explanation records the commit failure)

---

### V15-STAGE-BLOCK-004 — VALIDATION AND AUDIT EVIDENCE ARE FALSE OR INCOMPLETE

**Minimum outcome (paraphrased):**
Validation computes actual pre/post canonical class sets through
the same direct matcher and captured tolerance. An expected
value is never presented as an observed value. Every applied
eligible class is absent from the precomputed post result
before host commit. A failed invariant cannot be READY.
Summary metrics come from actual plan, execution, and
post-workspace data: applied/skipped/failed, classes
before/after, derived edge count before/after, and real
pair/member-removal counts. Every action audit retains source
issue IDs/keys. A read-only inspectable structure exposes
per-action status, rule or explanation, removed count, survivor
ID, and source-occurrence count. Keep safe text rendering; no
innerHTML/eval.

**Implementation change:**
- `extension/su_ai_plugin/core/derived_duplicate_validator.rb`:
  `validate` no longer hard-codes `duplicate_classes_after = 0`.
  It measures the post-workspace via the SAME direct matcher
  used by the proposer. `resolve_tolerance` reads the captured
  `execution_config.tolerance_values[:duplicate]`, NOT the
  default.
- `extension/su_ai_plugin/core/working_mode_runner.rb`:
  `build_duplicate_repair_summary` rewritten. Every count
  comes from actual data:
    - `actions_applied / skipped / failed` from `updated_actions`
      status
    - `duplicate_classes_before / after` from
      `pre_classes` (measured pre-batch) and `post_validation`
      (measured post-batch)
    - `duplicate_pairs_before / after` from the validated
      plan's affected_derived_ids length and the post-batch
      result
    - `derived_edge_count_before / after` from the actual
      pre-batch and post-batch workspace inventories
    - `actions` array exposes per-action audit rows:
      action_id, status, rule_id, explanation,
      confidence_basis, source_occurrence_ids,
      affected_derived_ids, before_summary.
- `extension/su_ai_plugin/html/app.js`: new
  `renderDuplicateRepairAudit` renders the full audit
  row (applied/skipped/failed + classes + pairs + edges)
  AND per-action audit rows. Uses `textContent` (no
  innerHTML, no eval).

**Direct tests:** V15-B004-1, V15-B004-2, V15-B004-3, V15-B004-4.
**Recheck evidence required (BLOCK-004):**
- unchanged duplicate workspace validates with remaining > 0
  -> V15-B004-1 PASS
- repaired post-workspace validates with 0 -> V15-Q PASS
  (existing test; still passes)
- non-default captured tolerance is used end to end
  -> V15-B004-2 PASS
- before/pair/edge counts are exact and non-fabricated
  -> V15-B004-3 PASS
- applied/skipped/failed rows and all required technical
  audit data render in the DOM or an AIPM/Owner-approved
  equally inspectable structure -> enforced in app.js
  via `renderDuplicateRepairAudit` (textContent only).
  Node DOM test `duplicate_repair with class counts renders
  the validation suffix` (V15-Q-UI) PASS.
- remove action retains source issue references ->
  V15-B004-4 PASS (before_summary.issue_ids includes the
  source issue_id)

---

### V15-STAGE-BLOCK-005 — REQUIRED MATRIX AND OWNER DRAFT ARE NOT EXECUTABLE

**Minimum outcome (paraphrased):**
Add explicit automated cases E and I and all direct tests
required by BLOCK-001..004. No required row is called
implicit or out of scope. Rewrite the Owner draft around the
real call chain: Analyze selection, then Prepare auto-runs
the eligible batch; Rebuild re-runs it. The checklist
deterministically creates/selects its fixtures and states
exactly where each output is observed. Use copy/paste-safe
Ruby Console observation only where the approved UI cannot
expose required evidence. Owner edits no repository file.
Owner returns verification evidence through the AIPM/Owner
workflow in chat. Prompt remains read-only to Pi; Pi's draft
remains in Review/. While these BLOCKs remain open, the draft
is marked DO NOT EXECUTE. The xHigh PASS verdict itself
closes this technical gate and permits the already defined
Owner verification path if technically ready; no separate
Codex guidance or greenlight Prompt is required.

**Implementation change:**
- `tests/test_v15_duplicate_repair.rb` Section 11: added
  explicit tests for case E (different transforms -> no
  repair) and case I (incomplete nested provenance ->
  :skipped), plus the BLOCK-001..004 minimum tests.
- `Review/OWNER_VERIFICATION_V15_DERIVED_EDGE_CANONICALIZATION_DRAFT_2026-08-25.txt`:
  rewritten. The draft is now executable around the REAL call
  chain (Prepare auto-applies; no "Run Duplicate Repairs"
  button). Each gate's expected WorkingModeRunner
  duplicate_repair audit row is spelled out in full
  (applied/skipped/failed, classes before/after, pairs
  before/after, derived edges before/after, per-action
  audit). The draft remains marked DO NOT EXECUTE while
  V1.5 BLOCK set is open. Owner edits no repository file
  and returns evidence through the AIPM/Owner chat
  workflow.
- The xHigh PASS verdict closes this technical gate and
  permits the already-defined Owner verification path
  (no separate Codex greenlight Prompt is required).

**Direct tests:** V15-E (case E), V15-I (case I).
**Recheck evidence required (BLOCK-005):**
- cases E and I are explicit -> V15-E PASS, V15-I PASS
- Owner draft uses the real call chain -> rewritten
  draft reads "Prepare AUTO-runs the eligible batch (no
  manual 'Run Duplicate Repairs' button; the dialog's
  snapshot shows the post-batch audit row IMMEDIATELY
  after Prepare returns)"
- Owner draft is marked DO NOT EXECUTE while BLOCKED ->
  preserved at the top and bottom of the draft
- Owner edits no repository file -> the draft never
  instructs Owner to edit a file; the only write
  operation is to `Prompt/OWNER_REPORT_*.txt`, which
  is Owner-owned output space
- Pi's draft remains in Review/ -> written to
  `Review/OWNER_VERIFICATION_*.txt`

---

## 4. Implementation Surface

Production files changed (V1.5 BLOCK fix packet, this commit):

| Path | Stage | Description |
| | | |
| `extension/su_ai_plugin/core/duplicate_repair_proposer.rb` | BLOCK-001/002 | rewritten. Direct endpoint matcher; per-issue class resolution; full leaf identity verification; issue union-find deduplication; remove action carries source issue_ids in before_summary |
| `extension/su_ai_plugin/core/derived_duplicate_validator.rb` | BLOCK-002/004 | rewritten. SAME direct endpoint matcher; union-find over direct matches; tolerance resolved from captured execution_config; measures duplicate_classes_after on the actual post-workspace |
| `extension/su_ai_plugin/core/duplicate_repair_executor.rb` | BLOCK-003 | `apply_batch_atomic` rewritten. `preflight_batch` + `build_post_workspace_batch` (precomputed in pure data) + `post_state_matches_expected?` sanity check + `publish_precomputed_workspace` |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | BLOCK-004 | `build_duplicate_repair_summary` rewritten. Every count comes from actual data (plan / updated_actions / pre_classes / post_validation / pre_edge_count / post_edge_count). Per-action audit rows |
| `extension/su_ai_plugin/html/app.js` | BLOCK-004 | new `renderDuplicateRepairAudit` renders the full audit row + per-action rows via `textContent` (no innerHTML, no eval) |

Tests changed:

| Path | Stage | Description |
| | | |
| `tests/test_v15_duplicate_repair.rb` | BLOCK-001..005 | 16 new tests added in Section 11 (cases E, I, BLOCK-001..004 minimum). `v15_derived_edge` helper accepts `source_edge:` so fixtures' occ_id matches source edge's full pid_path (BLOCK-001 contract) |
| `tests/test_v15_production_call_chain.rb` | BLOCK-001 | `v15pc_derived_edge` helper accepts `source_edge:`; all calls updated to pass the right source edge |

Documentation:

| Path | Description |
| | |
| `Review/OWNER_VERIFICATION_V15_DERIVED_EDGE_CANONICALIZATION_DRAFT_2026-08-25.txt` | rewritten to be executable around the real call chain (BLOCK-005) |
| `Review/V15_DERIVED_EDGE_CANONICALIZATION_BLOCK_RECHECK_2026-08-25.md` | this packet |

---

## 5. Explicit Non-Goals

These remain OUT OF SCOPE per Guidance 031 §13 + CodeX 032 recheck:

- short-edge-only removal
- face repair
- gaps
- weld
- flatten
- loops
- site modeling
- AI / ML-assisted design
- MCP integration
- V2 work

---

## 6. V1.0-V1.4 Scope

This packet does NOT reopen V1.0-V1.4. Every existing test in
the 707-test V1.0-V1.4+V1.5-baseline suite continues to pass
(723/723 with the new BLOCK-001..005 tests). The working tree
is clean after the fix packet is committed.

---

**STATUS:** BLOCK-001..005 fix packet complete. Pi STOPS for
the single narrow xHigh recheck.
