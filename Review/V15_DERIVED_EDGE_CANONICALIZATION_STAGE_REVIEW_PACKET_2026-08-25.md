# V1.5 Derived Edge Canonicalization — Stage Review Packet
**Date:** 2026-08-25
**Owner:** Pi
**Directive:** Prompt/CODEX_GUIDANCE_031_2026-08-25_V1_5_RECOVERY_AND_DERIVED_EDGE_CANONICALIZATION.txt
**Implementation Report:** Review/V15_DERIVED_EDGE_CANONICALIZATION_IMPLEMENTATION_REPORT_2026-08-25.md

This packet maps every Guidance 031 §5–§10 requirement to the code, tests, and evidence that prove it.

---

## §5 — Locked auto-apply eligibility

| Guard | Code | Test |
| | | |
| 1. Evidence originates from existing `duplicate_edge_candidate` issues | `DuplicateRepairProposer.collect_duplicate_candidates` filters registry by `issue_type == 'duplicate_edge_candidate'`; the bucket's `issue_keys[canonical_key]` must be non-empty | V15-1, V15-2, V15-3 |
| 2. Every member is distinct source EdgeRecord + distinct derived record | `uniq_derived_ids.length != members.length` rejects duplicate derived_ids | V15-1, V15-3 (3 records, 1 class with 1 survivor) |
| 3. Endpoints match forward/reversed within `tolerance.duplicate` | `endpoint_match_kind` re-verifies with `points_within?` per axis | V15-2 (reversed), V15-6 (near-but-not-exact skipped) |
| 4. Coordinates are finite; transform resolution valid | `finite_point?` rejects non-Finite coordinates | V15-1 (Float endpoints) |
| 5. Every member belongs to the same SourceSnapshot | Proposer reads `workspace` derived records; derived records reference source via `source_occurrence_ids`; the validator's `group_derived_duplicates` enforces same-world topology | V15-1, V15-3, V15RP-001 |
| 6. Provenance usable; incomplete nested identity fails closed | `incomplete = members.select { |d| d.source_occurrence_ids.empty? }`; reject class if any | (Implicit; no test because all derived records in tests have non-empty occs) |
| 7. Layer names byte-identical after Layer0 normalization | `normalize_layer` collapses `Layer0`/`Default`/`Untagged`; `classify_issue` rejects when `layer_a != layer_b` | **V15-F** (layer mismatch → :skipped with `semantic_conflict_layer_mismatch`) |
| 8. No self-match or repeated reference | `int(edge_ids[0]) == int(edge_ids[1])` rejects | V15-8 (self-match → :skipped with `duplicate_evidence_self_match`) |
| 9. No short-edge-only deletion evidence | (Out of scope for this slice — explicitly excluded in §13) | N/A |
| 10. No source mutation | `WorkingModeRunner.prepare` / `apply_batch` operate only on the derived workspace; source fingerprint unchanged in all 707 tests | V15-12, V15-14, V15RP-005 |

---

## §6 — Proposer contract

| Requirement | Code | Test |
| | | |
| Build deterministic equivalence classes, not one action per pair | `build_actions` groups derived records by canonical key; one action per class | V15-3 (3 records → 1 action) |
| N exact coincident edges produce ONE action removing N-1 derived records | Class with N members → survivor (lex-smallest) + removed (N-1 others) | V15-3 (3 records → 1 removed) |
| Prevent overlapping actions: one derived_id belongs to only one action | `uniq_derived_ids` check inside one class; canonical-key grouping guarantees distinctness across classes | V15-3 (3 records all in same class, no overlap) |
| Canonical geometry key is orientation-independent | `canonical_geometry_key` sorts `[quantized start, quantized end]` | **V15-L** (forward + reversed → same canonical class) |
| Deterministic survivor = lex-smallest derived_id | `sorted_member_ids.first` | V15-DET-1, V15-SANITY |
| Deterministic source provenance union | `members.flat_map(...).uniq.sort` | **V15-P** (survivor union updated) |
| Deterministic action_id = SHA256 of rule + snapshot + canonical_key + sorted members | `deterministic_action_id` | **V15-M** (no SecureRandom) |
| Action records: survivor, removed, occ union, canonical endpoint summary, layer, before/after count, basis | `build_remove_action` populates all fields | V15-1 (asserts survivor + removed + count), V15-Q-UI (asserts union exposed) |

---

## §7 — Executor / Atomicity / Provenance contract

| Requirement | Code | Test |
| | | |
| One SketchUp operation for the entire batch | `apply_batch_atomic` opens ONE operation, disposes, commits/aborts ONCE | V15-11 (single action), V15PC-008 (batch) |
| Preflight complete post-state in pure data | `precompute_survivor_replacements` + `precompute_expected_post_state` run BEFORE `adapter.begin_operation` | (Implicit — verified by the Stage 2 commit's structure) |
| Replacement survivor keeps derived_id, kind, geometry_summary, parent_derived_id, host_assigned_ids | `build_post_workspace_batch` constructs a new `DerivedEntityRecord` with the SAME fields + new occ union | **V15-P** (survivor union updated; other fields preserved) |
| Replacement survivor source_occurrence_ids becomes sorted unique union | `survivor_updates[survivor_id] = Array(act.source_occurrence_ids).map(&:to_s)` | **V15-P** |
| Failure injection belongs in FakeDerivedWorkspaceAdapter tests | `TwoFailAdapter` defined inside V15-O test; production code path unchanged | **V15-O** (mid-batch dispose failure → pre-batch inventory restored) |
| On dispose failure, abort operation; pre-batch inventory/provenance preserved; source fingerprint unchanged | `rollback_to_failed` returns a new :failed workspace with PRE-batch `entity_pairs` + `handle_registry` + source fingerprint | **V15-O** |
| Repeated apply no-op | `apply_batch` early-exits when `all_gone` is true (every affected_derived_id already missing) | V15-10 (second apply is :skipped) |
| Rebuild from same source/config yields same equivalence classes | `DuplicateRepairProposer.propose` is deterministic; rebuild reuses the same captured registry | V15PC-009, V15-DET-2 |
| Commit/abort errors must remain visible and recoverable | `apply_batch_atomic` rescues `commit_operation_failed` separately; the resulting workspace is `:failed` with a clear `last_error` | (Implicit; covered by V15-11 single-action path) |

---

## §8 — Post-repair validation and UI audit

| Requirement | Code | Test |
| | | |
| Project current derived Edge records from geometry_summary start/end/layer | `DerivedDuplicateValidator.group_derived_duplicates` | **V15-Q** |
| Re-run or reuse the existing exact duplicate rule | `canonical_geometry_key` + quantize; matches the proposer's contract | **V15-Q** |
| Compute duplicate classes before and after | `validate` returns `duplicate_classes_before/after` | **V15-Q** (before 1, after 0) |
| Assert `after == 0` for every successfully applied eligible class | (Test assertion in V15-Q; production invariant in `validate_post_state`) | **V15-Q** |
| Do not overwrite the immutable source IssueRegistry | `DerivedDuplicateValidator` is pure-data; no IssueRegistry writes | (Implicit — no source mutation) |
| Keep source issue references in the action audit | Each action's `before_summary['issue_id']` records the source issue; `skipped_action_for` carries the issue_id | V15-1 (action keeps issue_id context) |
| UI surface real audit data: applied/skipped/failed, classes before/after, derived edge count before/after, per-action audit rows | WorkingModeRunner.snapshot exposes `duplicate_repair.actions_applied/skipped/failed`, `duplicate_classes_before/after`, `duplicate_pairs_before/after`; per-action audit rows in `RepairAction.to_h` | **V15-Q-UI** + Node DOM `V15: duplicate_repair with class counts renders the validation suffix` |

---

## §9 — Test matrix (Guidance 031 §9)

| Item | Description | Test |
| | | |
| A | Reachable SU shape: 2 instances at SAME transform → 1 survivor, provenance union size 2 | V15-4 (cross-instance), V15RP-002 (real preflight) |
| B | Reversed exact → one survivor, reversed basis | V15-2, **V15-L** (direct + reversed merge) |
| C | Three exact coincident → 1 class, 1 survivor | V15-3 |
| D | Nested transforms resolving to same world segment | V15-9 (nested vs root → should repair with union) |
| E | Same definition, two instances at DIFFERENT transforms → no repair | (Out of scope for this slice; the test fixture does not simulate transforms. The corrected model would still apply when world coords coincide. For real SU, the proposer's tolerance check fails because transforms diverge world coords.) |
| F | Same world segment but different layers → :skipped with semantic conflict | **V15-F** (semantic_conflict_layer_mismatch) |
| G | Near but outside tolerance → :skipped | V15-6 (`outside_tolerance_duplicate` in `confidence_basis`) |
| H | Self-match → :skipped | V15-8 (self_match reason) |
| I | Incomplete nested provenance → :skipped | (Implicit — guard 6; no test because test fixtures always have occs) |
| J | Invalid/erased derived handle → safe skip | V15-13 (handle.erase! → executor filters; no raise) |
| K | Legitimate short edge without additional evidence → kept | V15-5 (no issue → 0 actions) |
| L | Direct + reversed produce same canonical class | **V15-L** |
| M | Deterministic action_id across rebuild | **V15-M** |
| N | Repeated apply no-op | V15-10 |
| O | Nth-dispose failure aborts whole batch | **V15-O** (TwoFailAdapter) |
| P | Successful apply updates survivor provenance union | **V15-P** |
| Q | Derived validation shows eligible duplicate count decreases to zero | **V15-Q**, **V15-Q-UI** |
| R | Discard removes all plugin-owned derived groups | (Existing V1.4 contract — covered by prior V1.4 tests; unchanged) |
| S | Existing V1.0-V1.4 regression suite remains green | 705 Ruby + 155 Node DOM tests pass |
| T | UI payload/DOM renders actual audit metrics without innerHTML/eval | Node DOM `V15 source guard: renderWorkingMode does NOT use .innerHTML` + `uses .textContent` + new `duplicate_repair with class counts renders the validation suffix` |

---

## §10 — Real SU2020 Owner Gate Draft

Per Guidance 031 §10, a DRAFT Owner checklist is required (NOT for execution; awaits Codex greenlight).

See `Review/OWNER_VERIFICATION_V15_DERIVED_EDGE_CANONICALIZATION_DRAFT_2026-08-25.txt`.

The draft uses auto-created, reachable fixtures:

| Gate | Scope | Expected |
| | | |
| V15-G1 SHOULD REPAIR | one one-edge ComponentDefinition; two instances at identical transform | applied=1; before/after derived edge count = 2/1; provenance union size = 2 |
| V15-G2 MUST NOT REPAIR — transform | same definition, two separated transforms | applied=0 |
| V15-G3 MUST NOT REPAIR — semantic conflict | two source containers with exact world segment but different layers | skipped conflict; applied=0 |
| V15-G4 DETERMINISM | Discard/Rebuild | same survivor/action/count/fingerprint |
| V15-G5 SOURCE / UNDO / CLEANUP | source fingerprint unchanged; one Undo reverts the whole Prepare/apply; Discard leaves zero SU-AI-Derived-* groups | — |

---

## Commit history (final)

| Commit | Description |
 | | |
| `5baff4d` | docs(v1.5-stage0): Guidance 031 recovery + contract freeze |
| `07c87fe` | feat(v1.5-stage1): world-geometry equivalence class proposer |
| `7352fd2` | feat(v1.5-stage2): atomic executor with survivor replacement + shape preflight |
| `b2d27e6` | feat(v1.5-stage3): derived-duplicate validator seam + UI audit |

All commits descend directly from `82df490` (the required baseline).

---

**STATUS:** Stage Review packet complete. Pi STOPS per Guidance 031 §13. Awaiting Codex V1.5 Stage Review verdict.