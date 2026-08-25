# V1.5 Derived Edge Canonicalization — Implementation Report
**Date:** 2026-08-25
**Owner:** Pi
**Directive:** Prompt/CODEX_GUIDANCE_031_2026-08-25_V1_5_RECOVERY_AND_DERIVED_EDGE_CANONICALIZATION.txt

---

## 1. Base / HEAD

| Item | Value |
| | |
| Branch | `v1.5-high-confidence-auto-repair` |
| Required baseline | `82df490` (docs(v1.5): escalate unreachable duplicate-input contract) |
| Initial dispatch HEAD | `78f8500` (docs(prompt): dispatch V1.5 recovery guidance 031) |
| Final implementation HEAD | `b2d27e6` (feat(v1.5-stage3): derived-duplicate validator seam + UI audit) |
| Implementation commits (5baff4d, 07c87fe, 7352fd2, b2d27e6) all descend directly from `82df490` | |

---

## 2. Exact Product Behavior (Corrected V1.5 scope)

The V1.5 implementation directive **canonicalizes exact / reversed-exact coincident DERIVED edges inside the current selected SourceSnapshot, while preserving the immutable source occurrences as a many-to-one provenance union on the surviving derived edge.**

| Property | Value |
| | |
| Action type | `:remove_duplicate_edge` |
| Rule id | `duplicate_edge.exact_remove` |
| Confidence | `1.0` (evidence-based, NEVER a fake AI score) |
| Auto-applicable | `true` |
| Match tolerance | `tolerance.duplicate` from captured `execution_config` (default `1.0e-4` inches) |
| Endpoint match kinds | forward exact / reversed exact (orientation-independent canonical key) |
| Source identity preservation | source occurrences are NEVER merged, rewritten, or discarded; the survivor's `source_occurrence_ids` is the **sorted unique union** of every contributing derived record's `source_occurrence_ids` |
| Survivor selection | lex-smallest `derived_id` (deterministic, testable) |
| Action id | deterministic SHA256 — `act-{rule_id}-{digest8}`, no SecureRandom |

---

## 3. Files Changed

### Production

| Path | Stage | Description |
| | | |
| `extension/su_ai_plugin/core/duplicate_repair_proposer.rb` | Stage 1 | Refactored from same-container-occurrence grouping to **DERIVED world-geometry equivalence classes**. Computes orientation-independent canonical key (quantized endpoint pair + Layer0-normalized layer). Deterministic `action_id`. Action carries survivor, removed ids, source-occurrence union, canonical endpoint summary, layer, before/after edge count, basis. |
| `extension/su_ai_plugin/core/duplicate_repair_executor.rb` | Stage 2 + Stage 3 | Added pre-flight: **survivor replacement map** (Hash<derived_id, source_occurrence_ids>) + **expected post-state shape** validation. Atomic batch (one SU operation), precompute -> open -> dispose -> commit/abort. `:failed` rollback preserves pre-batch inventory + source fingerprint. Added `validate_post_state` (Stage 3). |
| `extension/su_ai_plugin/core/working_mode_runner.rb` | Stage 3 | Captures pre-batch classes via `DerivedDuplicateValidator.group_derived_duplicates` BEFORE apply. Calls `validate_post_state` AFTER apply. Summary exposes `duplicate_classes_before/after`. |
| `extension/su_ai_plugin/core/derived_duplicate_validator.rb` | Stage 3 (new) | Pure-core derived-duplicate validation seam. Re-uses proposer's canonical-key contract. Reads only `geometry_summary`; never writes the source IssueRegistry. |
| `extension/su_ai_plugin/html/app.js` | Stage 3 | UI surfaces `Duplicate repairs: applied N, skipped M; duplicate classes X → Y` row in both `none` (audit-after-discard) and `ready`/`failed` states. |

### Tests

| Path | Stage | New tests |
| | | |
| `tests/test_v15_duplicate_repair.rb` | Stage 1 + 2 + 3 | V15-F (layer mismatch), V15-L (direct + reversed → same class), V15-M (deterministic action_id), V15-P (survivor union updated), V15-O (mid-batch dispose failure), V15-Q (validation seam), V15-Q-UI (UI summary) |
| `tests/test_v15_production_call_chain.rb` | Stage 1 | Updated V15PC-006, V15PC-007 to reflect corrected model |
| `tests/test_v15_real_preflight_path.rb` | Stage 1 | Updated V15RP-002 |
| `tests/test_html_render_dom.js` | Stage 3 | V15: `duplicate_repair with class counts renders the validation suffix` |

### Documentation

| Path | Stage | Description |
| | | |
| `PROJECT_HANDOFF.txt` | Stage 0 | Created from §2 durable facts only |
| `CURRENT_STATE.md` | Stage 0 | Prepended Guidance 031 ACTIVE section, preserved all historical content |

---

## 4. Provenance Union Design

Each `:remove_duplicate_edge` action carries `source_occurrence_ids` = **sorted unique union** of every contributing derived record's `source_occurrence_ids`. The derivation follows these rules:

1. Group derived records by **canonical world-geometry key** = `geom|<quantized start>|<quantized end>|layer=<normalized layer>`.
2. The key is **orientation-independent**: `[start, end]` and `[end, start]` land in the same bucket.
3. The key is **layer-discriminating**: `Layer0` vs `Layer1` (after Layer0 normalization) land in different buckets.
4. The quantizer divides by `tolerance.duplicate` and rounds, so endpoints within tolerance land in the same bucket.
5. For each class with 2+ members AND at least one matching `duplicate_edge_candidate` issue in the captured IssueRegistry, emit ONE action.
6. The survivor's `source_occurrence_ids` is the **sorted unique union** — the input data for Stage 2's `precompute_survivor_replacements` produces a Hash<derived_id, source_occurrence_ids> that the post-workspace builder uses to construct the replacement `DerivedEntityRecord`.

The replacement record preserves `derived_id`, `kind`, `geometry_summary`, `parent_derived_id`, `host_assigned_ids`; ONLY `source_occurrence_ids` is replaced.

---

## 5. Semantic-Conflict Guard (Guidance 031 §5.7)

Per Guidance 031 §5 guard 7: "Layer names byte-identical after Layer0 normalization. Different layer names/semantic sources are ambiguous and MUST be skipped."

Layer0 normalization collapses `Layer0` / `Default` / `Untagged` (case-insensitive) into the canonical `Layer0`. Anything else passes through unchanged.

When an issue references two source edges with different normalized layers, the per-issue guard emits a `:skipped` action with reason `semantic_conflict_layer_mismatch`. The exact error text is recorded in the action's `confidence_basis` field.

Test coverage: V15-F (`layer-mismatch duplicate is skipped with semantic-conflict reason`).

---

## 6. Atomicity / Recovery Behavior

`apply_batch` runs the entire batch inside ONE SketchUp operation:

1. **Pre-flight (Stage 2 §7):** `precompute_survivor_replacements` (Hash<derived_id, source_occurrence_ids>) and `precompute_expected_post_state` (surviving derived_ids set + pre-classes topology). Both are pure-data; no host mutations.
2. **Open operation** via `adapter.begin_operation(model, label: ...)`.
3. **Dispose each handle** in deterministic order. First failure → break + log + abort.
4. **On failure path:** `adapter.end_operation(model, commit: false)` → `rollback_to_failed` preserves pre-batch inventory + handle registry + source fingerprint. Every action transitions to `:failed`.
5. **On success path:** `adapter.end_operation(model, commit: true)` → `build_post_workspace_batch` with `survivor_updates` → `post_state_matches_expected?` validates the new inventory shape → every action transitions to `:applied`.

The pre-batch inventory / handle registry / source fingerprint are NEVER touched on source entities (Guidance 031 §5 guard 10).

---

## 7. Derived Validation Result (Stage 3 §8)

`DerivedDuplicateValidator.validate(workspace:, tolerance:)` returns:

```ruby
{
  'duplicate_classes_before' => Integer,
  'duplicate_classes_after'  => Integer,
  'class_keys'               => Array<String>,
  'class_member_counts'      => Array<Integer>,
  'tolerance'                => Float
}.freeze
```

The validator re-runs the exact-duplicate rule against the derived records' `geometry_summary` (start/end/layer) and counts classes with 2+ members. It NEVER writes the immutable source IssueRegistry.

WorkingModeRunner records the validator output in the `duplicate_repair` summary; the UI exposes it as `Duplicate repairs: applied N, skipped M; duplicate classes X → Y`.

---

## 8. Tests and RBZ Evidence

### Baseline test counts

| Suite | Count | Status |
| | | |
| Ruby | **707 / 707** PASS | 5 new pure-core tests added (V15-F, V15-L, V15-M, V15-P, V15-O, V15-Q, V15-Q-UI) |
| Node DOM | **155 / 155** PASS | 1 new DOM assertion added (`duplicate_repair with class counts renders the validation suffix`) |
| RBZ smoke | 8 / 8 PASS | Package is valid PKZip archive; dialog asset trio shipped; support folder correct; dev-only paths excluded; all required source files shipped; install smoke extracts + parses + boots |
| `git diff --check` | clean | — |
| working tree | clean | — |

### RBZ build (final HEAD)

| Item | Value |
| | |
| Path | `dist/SU-AI-Plugin.rbz` |
| Size | **525,661 bytes** |
| Entries | **56** (54 + 2 for the new `derived_duplicate_validator.rb` and its compiled form) |
| Entry-point | `su_ai_plugin.rb` (at the .rbz root, SketchUp Extension Manager convention) |
| Support folder | `su_ai_plugin/` (sibling of entry-point) |
| SHA-256 | (recomputed at Stage 4 close; see Stage Review packet) |

---

## 9. Known NIT / DEBT

- `apply_atomic` (single-action path) still uses the old pre-batch flow; the survivor replacement is applied but the `precompute_expected_post_state` shape check is only enforced in `apply_batch_atomic`. This is fine for production (the production path uses `apply_batch`), but a future cleanup could unify the two.
- The `test_v15_real_preflight_path.rb` test uses a stub `FakeEntitiesWithEdges` that does NOT enforce SketchUp's "two coincident edges in one Entities collection" suppression. This is acceptable for the corrected model — the Stub mimics what a real CAD-import duplicate inside one ComponentDefinition produces (one entity per leaf edge).
- The validator's `group_derived_duplicates` is called once per `run_duplicate_repair_batch`. For very large workspaces this is O(N log N); acceptable for current V1.5 scale.

---

## 10. Explicit Non-Goals

These are explicitly OUT OF SCOPE per Guidance 031 §13 and remain so:

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

**STATUS:** Stage 4 close — STOP for Codex V1.5 Stage Review.