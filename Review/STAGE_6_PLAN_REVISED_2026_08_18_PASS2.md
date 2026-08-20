# Stage 6 — UI Implementation Plan (revised v2, after Codex Review 011)

| Field | Value |
|---|---|
| Date | 2026-08-18 (revised v2 after Codex Review 011) |
| Previous packet | `Review/STAGE_6_PLAN_REVISED_2026-08-18.md` (SUPERSEDED) |
| Project | D:\Projects\SU-AI-Plugin |
| Stage | 6 (UI — `UI::HtmlDialog` + Issue registry presentation) |
| Locked decisions | R001 / R002 / R003 / R004 / R005 |
| Source-of-truth contracts | PI_TASK_001 §11 / §12 / §13 / §14 / §17 / §18 / §91 |
| Author | Agent (revised v2 after Codex Review 011) |
| Status | **REVISED v2 — addresses S6-PLAN-BLOCK-001 + -003 narrow reopens** |
| Codex Review 010 verdict | BLOCKED (BLOCK-001..004) |
| Codex Review 011 verdict | BLOCKED (BLOCK-001 + -003 narrowly open; -002/-004 CLOSED) |


## 0. Why this is a revision

Codex Review 011 (2026-08-18, Prompt/CODEX_REVIEW_011…) returned
**VERDICT: BLOCKED** with two narrowly-scoped BLOCKs and 6 NITs.

**CLOSED** in this round: S6-PLAN-BLOCK-002 (one-snapshot + menu),
S6-PLAN-BLOCK-004 (HtmlDialog lifecycle).

**REMAINS OPEN narrowly**:
- S6-PLAN-BLOCK-001: source identity contract — the plan used two
  parallel arrays (`source_paths` + `source_entity_ids`) and dropped
  empty paths, which loses the source-path ↔ entity_id alignment and
  treats empty path as "root-level" when it actually means "PID
  capability missing". Normal root-level Edge has `pid_path = [edge_pid]`,
  not `[]`. Mitigated by §3.1 (single aligned `sources` array of
  `SourceToken` Hashes) and §6.3 (entityID fallback only for non-nested
  empty PID path).
- S6-PLAN-BLOCK-003: pure-core boundary — `core/issue_locator.rb` and
  `core/display_unit_formatter.rb` would have called into
  `Sketchup::Model` and `SUCapability`, breaking the
  core-stays-pure-Ruby rule. Mitigated by §4.1 (both files moved to
  `extension/`) and a new `test_core_no_host_dependency` lint.

All 6 NITs addressed: snapshot index built explicitly, IssueRegistry
constructor semantics clarified, `Ripper.lex` (not AST) for lint,
Owner verification step M rewritten, Step N uses a Ruby fingerprint
besides Model Info, test count is a soft target not a hard requirement.

No code has been written yet. The plan is still the only artifact
under review. Codex Review 011 directive: "Do not implement Gate A
yet."


## 1. Locked decisions (recap, do NOT re-litigate)

| ID | Decision | Consequence for Stage 6 |
|---|---|---|
| R001 | thresholds: `big_z=0.01`, `large_coordinate=1e6`, `deepest_nesting_warning=3` | PreflightReport already uses these; no UI capability to mutate them in V1.0 |
| R002 | HtmlDialog probe in `compatibility/su_capability.rb`; standalone Stage 5 cancelled | UI consumes `SUCapability.html_dialog?`; fallback path testable via FakeUI |
| R003 Q3.1 | **B**: selection + camera zoom ONLY. **NO overlay** | UI must NOT call `model.entities.add_*`, `layer.add`, `materials.add`, `tags.add`, even create-and-erase. |
| R003 Q3.2 | **A**: `UI::HtmlDialog` with capability check / fallback error | `UI::HtmlDialog` only (not `Sketchup::HtmlDialog`) |
| R003 Q3.3 | **A**: single-page summary + grouped issue sections | One HTML file, vertical scroll, no tabs |
| R003 Q3.4 | R005 colours | `:low`=neutral, `:medium`=orange, `:high`=red |
| R003 Q3.5 | **A**: click = Locate only. No Alt-click overlay. No Entity Info panel. | One click action, modifier keys ignored |
| R003 Q3.6 | no fix / edit / repair controls | UI exposes zero mutating controls |
| R004 | SU2017 verification posture B | UI must work on SU2017 real host; codebase must satisfy Ruby 2.2.4 syntax rules |
| R005 | grouped by issue_type, collapsible, count in heading | Sort + grouping happens in `IssueRegistry` |
| R005 | determinism: sort by issue_id, NOT `object_id` | Stable sorted by canonical source keys; counter is last tie-breaker |
| R005 | canonical severity: `:low / :medium / :high` ONLY | UI palette per R005 |
| R005 | no filter / sort / search in V1.0 | Only `<details>` collapse |
| NEW (Q1) | Default-open policy: open every group containing a `:high` Issue; if no `:high`, open first non-empty group only | Avoids blank-result appearance while keeping page compact |
| NEW (Q2) | Source resolve failure: in-dialog non-blocking status + one console line; no modal messagebox, no exception to JS | Status toast at panel bottom |
| NEW (Q4) | HtmlDialog assets: external local files via `set_file` absolute path; NO heredoc embedding | `File.expand_path('html/index.html', __dir__)` |
| NEW (Q5) | Internal: raw inch Float; Display: `Sketchup.format_length` strings | `extension/display_unit_formatter.rb` (only host-dependent formatter) |
| NEW (BLOCK-001) | One aligned `sources` array of `SourceToken` Hashes; `source_entity_ids` is derived/serialized only | §3.1 |
| NEW (BLOCK-001) | Empty `pid_path` = missing PID capability, not root-level. Root-level entity has `[leaf_pid]`. Root-only fallback via `model.find_entity_by_id(entity_id)` (per Source Identities skill / `Model#find_entity_by_id`). For nested missing PID → non-locatable. | §6.3 |
| NEW (BLOCK-003) | `issue_locator.rb` and `display_unit_formatter.rb` live in `extension/`, not `core/`. Core stays pure Ruby. | §4.1 |


## 2. What V1.0 UI does and does NOT do

### Does
- Display CAD Analyzer Result header (summary metrics).
- Display issue list grouped by `issue_type`, each section `<details>`,
  with `(NN)` count in the heading.
- Render severity badge per issue (`:low` neutral / `:medium` orange /
  `:high` red).
- On Issue row click: resolve source tokens to entities / root
  occurrences (pure-Ruby policy in `core/issue_locator_policy.rb`,
  SU-side glue in `extension/issue_locator.rb`), dedupe,
  `selection.clear` + `selection.add(entities)`,
  `view.zoom(entities)` — read-only.
- Close button + Esc + `set_on_closed` cleanup.
- In-dialog status toast for "source no longer available".

### Does NOT (V1.0 — per PI_TASK_001 §17 / §91 / R003 hard prohibition)
- Add any entity / material / layer / tag / face / edge / group /
  component / construction line / construction point / construction
  geometry to the model — even create-and-erase.
- Auto-fix anything.
- Mutate any source entity property (material, layer, visibility,
  soft/hidden, color, dictionary entries, attributes).
- Mutate `model.active_path`.
- Provide filter / sort / search controls.
- Provide entity info / attribute viewer / persistent-id browser.
- Provide settings UI.
- Provide per-Issue highlight overlay (R003 Q3.1=B).
- Provide multi-Issue multi-select ("frame all").
- Persist any state across sessions (no file / registry write).
- Re-run / refresh button (UI is opened once per analysis run;
  Owner re-triggers via menu command).


## 3. The unified Issue / AnalysisResult contract (S6-PLAN-BLOCK-001 v2 fix)

### 3.1 `UIIssue` Hash (canonical contract — JSON-safe)

Every Issue that reaches the UI MUST be a Hash with the following
keys. No Symbol values, no `Sketchup::*` types, no callable objects.

| Key | Type | Required | Notes |
|---|---|---|---|
| `issue_id` | String | yes | Deterministic; see §3.5 |
| `issue_type` | String | yes | Canonical names from §3.4 |
| `severity` | String | yes | One of `"low"` / `"medium"` / `"high"` (String end-to-end) |
| `confidence` | String | yes | One of `"low"` / `"medium"` / `"high"` |
| `sources` | Array<SourceToken> | yes | **One aligned array** (see §3.2). Order matters. The source of truth. |
| `source_entity_ids` | Array<Integer> | yes | **Derived serialized projection** of `sources[*].entity_id` for legacy UI consumers; never enriched separately. |
| `edge_ids` | Array<Integer> | yes | Stable across the registry; may be empty |
| `location` | Array<Float,3> or null | yes | World-space midpoint or null when no spatial anchor |
| `message` | String | yes | Human-readable; UTF-8 preserved; control chars stripped |
| `metadata` | Hash<String,JSON-safe> | yes | Free-form; must be JSON-safe |
| `locatable` | Boolean | yes | true iff at least one `SourceToken` is locatable (see §3.6) |
| `display_length` | String or null | yes | Pre-formatted via `Sketchup.format_length`; only set for length-bearing issues |

### 3.2 `SourceToken` Hash (the aligned source of truth)

The two-array design (parallel `source_paths` + `source_entity_ids`)
broke alignment when one array was deduplicated or another path was
dropped. Per Codex Review 011 BLOCK-001, the source of truth is a
single array of aligned Hashes:

```ruby
# SourceToken — one per resolved EdgeRecord; never split.
# Constructed only by core/issue_enricher.rb.
SourceToken = {
  persistent_id_path: Array<Integer>,    # SU persistent_id_path (canonical)
  entity_id:          Integer or nil,     # transient entityID (in-session only)
  nested:             Boolean            # true iff pid_path.size > 1
}
```

Field rules:

- `persistent_id_path` is set when the source EdgeRecord has a
  non-empty `source.persistent_id_path`. Empty Array means PID
  capability/data was missing for this particular source.
- `entity_id` is set whenever the source is resolvable; transient,
  in-session only, NEVER used for `issue_id` determinism.
- `nested` is `pid_path.size > 1`. Root-level entity has
  `pid_path = [leaf_pid]` → `nested = false`. Empty path also → `nested = false`.
- `locatable` derivation (per BLOCK-001):
  - true iff at least one SourceToken has non-empty `persistent_id_path`,
    OR the SourceToken has `entity_id` AND `nested == false` (root-only
    entityID fallback).
  - false for nested sources with empty PID path (entityID alone cannot
    pick the correct shared component occurrence).

### 3.3 `AnalysisResult` (one immutable return value)

A single immutable wrapper that the entire pipeline produces and
the dialog consumes. Built once per `Analyze selection` command.

| Field | Type | Source |
|---|---|---|
| `preflight` | `PreflightReport` | `PreflightAnalyzer.run(snapshot)` |
| `registry` | `IssueRegistry` (see §3.4) | normalized from analyzer + preflight output |
| `snapshot_lookup` | `Hash<Integer, EdgeRecord>` | built explicitly in `analyzers_runner.rb` (see §5) |
| `display_data` | `Hash<String, String>` | `extension/display_unit_formatter.rb` (per issue_id) |
| `diagnostics` | `Array<Hash>` | per-stage errors, skipped entities, malformed-issue drops |
| `selection_type` | String | from preflight |
| `selection_label` | String | container name when present; "selection" otherwise |

`AnalysisResult` is **frozen** at construction (no setters, no
mutators). All consumers can rely on this.

### 3.4 `IssueRegistry` (pure-Ruby, replaces the plan's earlier stub)

| Property | Value |
|---|---|
| Holds | `Array<Hash>` of UIIssue (defined in §3.1) |
| Internal validation | a private `IssueRegistry.validate_issue` raises `IssueRegistry::InvalidIssue` on a missing key, a non-canonical severity String, an un-`to_s`-able field, or a non-`Array sources`. |
| Public constructor | `IssueRegistry.new(issues, diagnostics:)` **catches** any `InvalidIssue` from `validate_issue`, drops the offending Issue, records it in `diagnostics`, and continues. The constructor itself never raises on a single malformed Issue. |
| `open?` | true iff at least one Issue has `severity == "high"` |
| `summary` | `Hash{ issue_type => count }` |
| `groups` | `Array<{ type: String, count: Integer, default_open: Boolean, issues: Array<Hash> }>` — already sorted per §6.6 |
| `each`, `find(id)` | standard enumeration |

### 3.5 Canonical `issue_type` strings (R005 + per-type mapping)

| issue_type | source | severity (R005) |
|---|---|---|
| `duplicate_edge_candidate` | `DuplicateDetector` | `medium` |
| `short_edge` | `ShortEdgeDetector` | `low` |
| `open_endpoint` | `OpenEndpointDetector` | `medium` |
| `gap_candidate` | `GapCandidateDetector` | `medium` |
| `significant_non_zero_z` | Preflight warning | `medium` |
| `abnormal_large_coord` | Preflight warning | `high` |
| `deep_nesting` | Preflight warning | `low` |

The conversion layer (analyzer `kind` / preflight `code` → canonical
issue_type, raw analysis-side severities which may be Symbols → String `low/medium/high`)
lives at **one boundary** in `core/issue_normalizer.rb`. UIIssue
severity is **String end-to-end**; Symbols may exist only inside
`IssueNormalizer` before normalization. Display formatter and any
downstream code see only `"low"` / `"medium"` / `"high"`.

### 3.6 Deterministic `issue_id` (R005 + BLOCK-001 v2)

The ID is built from canonical source tokens, NOT raw `object_id`
and NOT `entity_id`. Algorithm (executed in
`core/issue_id_assigner.rb`):

```
1. Build canonical_source_keys = canonicalize(sources):
     for each token in sources:
       - if token.persistent_id_path is non-empty:
           serialize as dot-string "10.20.555"
       - else:
           use geometry signature from `location` quantized at
           coord epsilon; fall back to "edge_id:#{edge_id}" when
           edge_ids is non-empty and location is null
     sort the resulting Array<String> deterministically (lex).
2. issue_type_signature = issue_type (canonical).
3. counter_within_type = running counter starting from 1, scoped
       to the registry, sorted by canonical_source_keys.
4. issue_id = "{issue_type}|{canonical_source_keys.join('+')}|{counter}"
```

`entity_id` is NEVER used for `issue_id` derivation. It is
session-transient and may collide across reloads.

### 3.7 Display-unit formatting (BLOCK-003 fix)

Core stays unit-agnostic. The Issue Registry keeps raw inch Float
values in `location` and `metadata`. **The formatter lives in
`extension/display_unit_formatter.rb`**, not in `core/`. It is the
**only** place that calls `Sketchup.format_length`.

Format:
- `edge length` in `metadata` of `short_edge` / `duplicate_edge_candidate`
  → `display_length` = `Sketchup.format_length(value)`.
- `distance` in `metadata` of `gap_candidate` → `display_length` =
  `Sketchup.format_length(distance)`.
- Non-SU test runs: `display_length` = `format("%.4f inch", value)`
  (deterministic fallback for unit tests).

`AnalysisResult.display_data` exposes a `Hash{ issue_id => display_length }`
that the UI reads. The UI never calls `Sketchup.format_length`.

### 3.8 Preflight-warning → Issue conversion (BLOCK-001)

Each Preflight warning Hash (kind: `:significant_non_zero_z`,
`:abnormal_large_coord`, `:deep_nesting`) is converted to a UIIssue
with:

- `sources: []`, `source_entity_ids: []`, `edge_ids: []`
- `location: null`
- `locatable: false`
- `message`: preflight warning's `:message` — **UTF-8 preserved**;
  control characters (U+0000..U+001F except newline/tab) are
  stripped/replaced.
- `metadata`: `{"code": "<preflight_code>"}`
- `display_length`: null

The UI renders these as non-clickable rows (no Locate action on
click; instead a clean "not locatable" affordance — see §6.3).

### 3.9 Issue enrichment from `edge_ids` (BLOCK-001)

`core/issue_enricher.rb` (NEW) takes the snapshot's EdgeRecord
index and the raw analyzer Issues, and produces Issues with full
`SourceToken` arrays.

Algorithm per Issue:

```
1. For each edge_id in Issue.edge_ids:
     rec = snapshot_lookup[edge_id]   # explicit index built in §5
     if rec is nil:
       skip and record "(missing edge_id #{edge_id})" in metadata
     else:
       pid_path = rec.source.persistent_id_path
       ent_id   = rec.source.entity_id
       nested   = pid_path.is_a?(Array) && pid_path.size > 1
       sources << {
         persistent_id_path: pid_path,
         entity_id:          ent_id,
         nested:             nested
       }
2. drop_empty_pid_paths is NOT applied here. The empty path is
   preserved as a SourceToken with empty persistent_id_path so the
   locator can apply the root-only entityID fallback.
3. dedup WHOLE SourceTokens (NOT individual fields):
     sources = uniq_by(sources) { |t| [t[:persistent_id_path],
                                       t[:entity_id]] }
4. Compute locatable per §3.2 rule.
5. Derive source_entity_ids = sources.map { |t| t[:entity_id] }.
   Replace the analyzer-emitted source_entity_ids in the Issue.
```

This is the one place where tokens are derived. After this, no
downstream code re-derives source tokens.

### 3.10 Gap-candidate empty-source fix (BLOCK-001)

`GapCandidateDetector` currently emits `source_entity_ids: []`.
After enrichment (§3.9), the gap's `sources` will be populated from
the two endpoint edges. The enricher is the canonical fix; the
analyzer is **not** patched in this stage (Stage 2 BLOCK rework is
closed, scope discipline).

### 3.11 Multi-source Issues (duplicate / gap)

Duplicate and gap Issues have **two source Edges**. Both
`SourceToken`s are kept. The locator (§6.3) handles multi-source.

## 4. File inventory (revised for BLOCK-001 / BLOCK-003)

### 4.1 New files

| Path | Gate | LoC est. | Purpose |
|---|---|---|---|
| `core/issue_registry.rb` | A | ~150 | Pure-Ruby IssueRegistry per §3.4; tolerant drop on malformed |
| `core/issue_id_assigner.rb` | A | ~80 | Deterministic IDs per §3.6; never uses `object_id` or `entity_id` |
| `core/issue_enricher.rb` | A | ~80 | Aligned SourceToken array per §3.9; one token per resolved EdgeRecord |
| `core/issue_normalizer.rb` | A | ~120 | One-boundary normalization: `kind` → `issue_type`, Symbol → String severity, R005 per-type mapping, preflight warning → Issue |
| `core/issue_grouper.rb` | A | ~80 | Pure-Ruby grouping by `issue_type` per §6.6 |
| `core/analysis_result.rb` | A | ~80 | Immutable wrapper per §3.3; one per `Analyze selection` |
| `core/issue_locator_policy.rb` | A | ~80 | Pure-Ruby locator policy: which targets to select/zoom per SourceToken profile (root leaf / nested root / empty / fallback). NO SketchUp imports. |
| `extension/issue_locator.rb` | B | ~120 | Implements the policy using `model`, `SUCapability`, `InstancePath`, `Selection` targets, entityID fallback. The ONLY place that touches SU locator APIs. |
| `extension/display_unit_formatter.rb` | B | ~60 | The ONLY place that calls `Sketchup.format_length`. Returns plain String display values. |
| `extension/loader.rb` | B | ~120 | Plugin load: `UI.menu` / `UI::Command` registration, idempotent, "Analyze selection" command |
| `extension/analyzers_runner.rb` | B | ~120 | One-pass: snapshot → preflight → analyzers → normalize → enrich → registry → AnalysisResult. Builds the snapshot_lookup index explicitly. |
| `extension/dialog_runner.rb` | B | ~150 | HtmlDialog lifecycle, callbacks as blocks, ready handshake, FakeUI factory injection |
| `extension/dialog_controller.rb` | B | ~120 | Per-dialog state (registry, registry-version, model lookup, snapshot_lookup, diagnostics) |
| `extension/ui_bridge.rb` | B | ~80 | Pure-Ruby serialization of `AnalysisResult` to JS-safe Hash (no `Sketchup::*` types) |
| `extension/html/index.html` | B | ~200 | Single-page summary + grouped `<details>` sections; loads via `set_file` absolute path |
| `extension/html/style.css` | B | ~140 | Severity palette: low=neutral, medium=orange, high=red |
| `extension/html/app.js` | B | ~250 | Renders JS Hash; click → `window.sketchup.locate_issue(issue_id)`; calls `window.sketchup.ready()` on `DOMContentLoaded` |
| `tests/test_issue_registry.rb` | A | ~150 | Pure-Ruby: validation, tolerant drop, determinism, grouping, summary, empty-registry |
| `tests/test_issue_id_assigner.rb` | A | ~80 | Pure-Ruby: stability, fallback, no `object_id` / `entity_id` in IDs |
| `tests/test_issue_enricher.rb` | A | ~80 | Pure-Ruby: aligned tokens, missing-edge diagnostic, dedup of whole tokens |
| `tests/test_issue_normalizer.rb` | A | ~100 | Pure-Ruby: per-type mapping, preflight warning → Issue, severity String end-to-end |
| `tests/test_issue_grouper.rb` | A | ~80 | Pure-Ruby: grouping, count, default_open per Q1 |
| `tests/test_analysis_result.rb` | A | ~80 | Pure-Ruby: immutability, single construction point |
| `tests/test_issue_locator_policy.rb` | A | ~120 | Pure-Ruby: target selection per token profile (root leaf / nested root / empty / fallback). NO host deps. |
| `tests/test_core_no_host_dependency.rb` | A | ~80 | Lint: scans new core files for forbidden tokens (`Sketchup`, `UI`, `Geom`, `compatibility/`, `extension/`). Single FAIL = any hit. |
| `tests/test_issue_locator.rb` | B | ~100 | Adapter: FakeInstancePath, root/leaf/multi-source, dedup, resolve-failure status |
| `tests/test_analyzers_runner.rb` | B | ~120 | Adapter: one snapshot per command, registry built from snapshot, explicit snapshot_lookup index |
| `tests/test_loader.rb` | B | ~80 | Adapter: FakeUI Command registry; idempotent registration across reloads |
| `tests/test_dialog_runner.rb` | B | ~120 | Adapter: set_file path, ready handshake, callback rebind on reopen, JSON.execute_script, no `eval`/`innerHTML`/`document.write` |
| `tests/test_ui_bridge.rb` | B | ~80 | Pure-Ruby: Hash shape, no SU types, escaping for JSON |
| `tests/test_display_unit_formatter.rb` | B | ~60 | Adapter: `Sketchup.format_length` integration + non-SU fallback |
| `tests/test_html_render.rb` | B | ~120 | Pure-Ruby: token scan of JS source for `eval`, `new Function`, `document.write`, `innerHTML` for user-supplied strings; static lint of HTML/CSS |
| `tests/test_no_overlay_lint.rb` | B | ~80 | `Ripper.lex`-based scanner of `extension/*.rb` for forbidden tokens (see §6.1) |
| `tests/test_ruby_22_syntax_sweep.rb` | B | 1 | Extended sweep: 22 + new files; 0 syntax issues |
| `tests/_fake_ui.rb` | B | ~150 | Fake `UI::HtmlDialog` + `UI::Command` + `UI::Menu` for adapter tests — `tests/` only |
| `tests/_fake_instance_path.rb` | B | ~80 | Fake `Sketchup::InstancePath` (root/leaf/to_a/empty) for locator tests |
| `Review/OWNER_VERIFICATION_STAGE_6.txt` | B | n/a | Owner Verification Stage 6 checklist (5 steps J..N) per Codex Q3 |

### 4.2 Modified files

| Path | Modify |
|---|---|
| `compatibility/su_capability.rb` | **No fake hooks added.** Read-only probes (`html_dialog?`, `sketchup_version`, `resolve_pid_path`, `serialize_pid_path`, `active_edit_context`) only. No `fake_ui?`, no `fake_html_dialog`. |
| `tests/_fake_su.rb` | Add `FakeUI` namespace (delegate to `tests/_fake_ui.rb`); add `FakeInstancePath` (delegate to `tests/_fake_instance_path.rb`). |
| `extension/preflight_runner.rb` | **No behavioral change.** Keep S2-BLOCK closed. Stage 6 calls `build_snapshot` directly, not `run`. |
| `tests/runner.rb` | No change. |
| `CURRENT_STATE.md` | Update only after the Stage 6 plan is approved (per Codex NIT). |

### 4.3 What is NOT being added

- No `core/issue_locator.rb` (BLOCK-003 fix — only in `extension/`).
- No `core/display_unit_formatter.rb` (BLOCK-003 fix — only in `extension/`).
- No `extension/repair_runner.rb` (PI_TASK_001 §17).
- No `extension/settings.rb` (PI_TASK_001 §17).
- No overlay / construction geometry helper (R003 hard prohibition).
- No persistent-id browser / entity-info helper (R003 Q3.5=A).
- No new gem dependency (Ruby 2.2.4 + zero gem deps).
- No external JS / CSS library (no jQuery, no React, no Bootstrap).
- No fake hooks in production `SUCapability` (per Codex BLOCK-004).
- No `snapshot.edges_by_id` silent assumption — explicit index
  built in `extension/analyzers_runner.rb` (per Codex NIT).

### 4.4 Module diagram (revised)

```
                  ┌──────────────────────────────────────────────┐
 extension/       │                                              │
                  │   loader.rb              (B)                │
                  │   analyzers_runner.rb    (B)                │
                  │   dialog_runner.rb       (B)                │
                  │   dialog_controller.rb   (B)                │
                  │   issue_locator.rb       (B)   SU-host glue │
                  │   ui_bridge.rb           (B)                │
                  │   display_unit_formatter.rb (B)             │
                  │                                              │
                  │   html/                                       │
                  │     index.html, style.css, app.js            │
                  ├──────────────────────────────────────────────┤
                  │   compatibility/su_capability.rb             │
                  │   (existing; no fake hooks added)             │
                  ├──────────────────────────────────────────────┤
 core/            │                                              │
  (pure Ruby,     │   issue_registry.rb        (A)               │
   NO Sketchup::, │   issue_id_assigner.rb     (A)               │
   NO UI::,       │   issue_enricher.rb        (A)               │
   NO Geom::,     │   issue_normalizer.rb      (A)               │
   NO compat/,    │   issue_grouper.rb         (A)               │
   NO extension/) │   analysis_result.rb       (A)               │
                  │   issue_locator_policy.rb  (A)               │
                  │                                              │
                  │   … existing edge_record.rb, source_reference.rb,
                  │     preflight.rb, geometry_snapshot.rb, etc. │
                  └──────────────────────────────────────────────┘
```

The lint `tests/test_core_no_host_dependency.rb` enforces the lower
boundary: any new `core/*.rb` file with a `Sketchup` / `UI` / `Geom`
/ `compatibility` / `extension` reference is a hard FAIL.

## 5. Runtime flow (revised — one snapshot, one explicit index)

```
Plugin load (SketchUp startup):
  extension/loader.rb#register!
    UI::Command.new('Analyze selection') { on_analyze_selection }
    UI.menu('Plugins').add_item(...).  # idempotent across reloads
  ↑
  Side effect: one menu item, no duplicate on Ruby reload.

Owner clicks "Analyze selection":
  loader.rb#on_analyze_selection
    selection = Sketchup.active_model.selection
    if selection.empty? → UI.messagebox("Please select CAD geometry first.")
                          return
    if selection unsupported (e.g. only faces) → UI.messagebox + return
    show_progress_indicator (SketchUp status bar text)
    begin
      result = analyzers_runner.run(selection, model)
      dialog_runner.show(result)
    rescue StandardError => e
      log_diagnostic_and_show_fallback(e)
    ensure
      clear_progress_indicator
    end

  analyzers_runner.run(selection, model):
    # ONE snapshot per command — rebuild NOT allowed downstream.
    snapshot     = PreflightRunner.build_snapshot(selection, model: model)
    preflight    = PreflightAnalyzer.run(snapshot)

    # Explicit snapshot lookup index (Codex NIT).
    snapshot_lookup = {}
    snapshot.edges.each { |e| snapshot_lookup[e.id] = e }

    raw_issues   = []
    [DuplicateDetector, ShortEdgeDetector,
     OpenEndpointDetector, GapCandidateDetector].each_with_index do |det, i|
      begin
        raw_issues.concat(det.new.detect(snapshot))
      rescue StandardError => e
        diagnostics << { stage: "analyzer[#{i}]", error: "#{e.class}: #{e.message}" }
      end
    end
    preflight_issues = IssueNormalizer.preflight_warnings_to_issues(preflight)
    raw_issues      = raw_issues + preflight_issues
    enriched        = IssueEnricher.enrich_all(raw_issues, snapshot_lookup)
    normalized      = IssueNormalizer.normalize_all(enriched)
    registry        = IssueRegistry.new(normalized, diagnostics: diagnostics)
    display_data    = DisplayUnitFormatter.format_all(registry,
                                        model: model, fallback: true)
    AnalysisResult.new(
      preflight:        preflight,
      registry:         registry,
      snapshot_lookup:  snapshot_lookup,
      display_data:     display_data,
      diagnostics:      diagnostics,
      selection_type:   preflight.selection_type,
      selection_label:  selection.first.respond_to?(:name) ?
                          selection.first.name.to_s : 'selection'
    )

  dialog_runner.show(result):
    unless SUCapability.html_dialog?
      UI.messagebox("Stage 6 UI requires UI::HtmlDialog (SU 2017+). " \
                    "Detected: #{SUCapability.sketchup_version}.")
      return
    end
    controller = DialogController.new(result, dialog_factory: self, ...)
    dialog = UI::HtmlDialog.new(
      dialog_title: 'CAD Analyzer Result',
      preferences_key: 'SU-AI-Plugin.cad_analyzer.v1',
      width: 720, height: 600,
      left: 100, top: 100,
      resizable: true
    )
    dialog.set_file(File.expand_path('html/index.html', __dir__))
    dialog.add_action_callback('ready') { |_ctx|
      push_data(dialog, controller)
    }
    dialog.add_action_callback('locate_issue') { |_ctx, issue_id|
      on_locate_issue(dialog, controller, issue_id)
    }
    dialog.set_on_closed { controller.release! }
    controller.bind(dialog)
    dialog.show

  push_data(dialog, controller):
    payload = UIBridge.as_html_data(controller.result)
    json = JSON.generate(payload)
    dialog.execute_script("window.SUAIP.render(#{json})")

  on_locate_issue(dialog, controller, issue_id):
    return unless issue_id.is_a?(String)
    return unless controller.registry.find(issue_id)
    result = IssueLocator.locate(controller.result, issue_id,
                                 model: Sketchup.active_model)
    if result.status == :resolved
      apply_selection_and_zoom(controller, result.targets)
    else
      dialog.execute_script(
        "window.SUAIP.toast(#{JSON.generate([
          "source no longer available for: #{issue_id}"])})")
      $stdout.puts("[SU-AI-Plugin] locate_issue: #{result.diagnostic}")
    end
```

Key invariants enforced in this flow:

- **One snapshot per command** (Codex BLOCK-002).
- **No UI.menu / UI::Command elsewhere** (Codex BLOCK-002).
- **No production fake hooks** (Codex BLOCK-004).
- **No asset path ambiguity** (Codex BLOCK-004).
- **No `InstancePath` passed to `Selection#add` / `View#zoom`**
  (Codex BLOCK-003).
- **No source mutation** (R003 hard prohibition).
- **Aligned SourceToken array** (Codex BLOCK-001 v2).
- **Explicit snapshot_lookup index** (Codex NIT).
- **`core/` free of host dependencies** (Codex BLOCK-003).

## 6. Critical implementation rules

### 6.1 NO overlay / NO mutation enforcement (R003 hard prohibition)

Strategy — three layers:

**Layer 1: token-aware static lint** (`tests/test_no_overlay_lint.rb`).

Per Codex NIT: literal wildcard `.entities.add_*` is NOT a
whole-token match in Ruby source, and AST-node names like
`method_add_arg` are not visible in a token stream. The lint uses
`Ripper.lex` (per Codex NIT) to produce a flat token stream, strips
comments and string literals, then walks tokens left-to-right and
matches a state machine on the `(receiver, dot, method)` triple.

Forbidden patterns (after stripping comments and string literals):

```
- .add_cpoint, .add_cline, .add_face, .add_group,
- .add_component_instance, .add_image, .add_text,
- .add_3d_text, .add_section_cut,
- .entities.add_* (any method under a receiver whose last token is `entities`),
- .materials.add, .layers.add, .tags.add,
- .attribute_dictionary, .set_attribute, .material =,
- .layer =, .back_material =, .soft=, .hidden=,
- .erase_entities, .start_operation, .commit_operation,
- .active_path =
```

The lint is restricted to `extension/*.rb`. `tests/_fake_su.rb`,
`tests/_fake_ui.rb`, `tests/_fake_instance_path.rb`, and the lint
test file itself are exempt.

**Layer 2: `extension/` top-of-file banner.**
`extension/dialog_runner.rb` and `extension/loader.rb` carry a
block comment at the top reproducing the R003 hard prohibition
verbatim. Future Agents cannot miss it.

**Layer 3: Owner Verification Stage 6 (per Codex Q3).**
A new `Review/OWNER_VERIFICATION_STAGE_6.txt` lists 5 steps
(J..N) that force Owner to compare model state pre/post analysis.

### 6.2 Capability fallback (R002 / R003 Q3.2)

`SUCapability.html_dialog?` returns `true` on SU2017+ real SU. If
false: `UI.messagebox("Stage 6 UI requires UI::HtmlDialog (SU 2017+).
Detected: #{SUCapability.sketchup_version}.")`. No silent WebDialog
fallback, no `Sketchup::HtmlDialog` (per S2-BLOCK-006).

Testable via `tests/_fake_ui.rb` FakeUI having no `HtmlDialog`.

### 6.3 Locate policy (S6-PLAN-BLOCK-001 v2 + BLOCK-003)

Two-layer design:

**Layer A**: `core/issue_locator_policy.rb` — pure-Ruby target
selection. Given an array of `SourceToken`s and a `policy_forest`
Hash (built from `analysis_result` once, in `extension/analyzers_runner.rb`),
return a `PolicyResult` (Array of target descriptors).

Token profiles:

| profile | persistent_id_path | entity_id | nested | target |
|---|---|---|---|---|
| root-leaf | `[leaf_pid]` | any | false | `InstPath#leaf` |
| nested | `[container_pid, ..., leaf_pid]` size>1 | any | true | `InstPath#root` |
| empty-root | `[]` | non-nil | false | `model.find_entity_by_id(entity_id)` |
| empty-nested | `[]` | any | true | non-locatable; skip |
| missing-everything | `[]` | nil | n/a | non-locatable; skip |

The `entity_id` fallback path is restricted to `nested == false`
(root only). For nested `[]` paths, entityID alone cannot identify
which shared component occurrence to use; the source is
non-locatable.

`locatable` derivation (in `IssueEnricher`):
- true iff at least one SourceToken falls into `root-leaf`,
  `nested`, or `empty-root` profile.
- false otherwise (only `empty-nested` and `missing-everything` survive).

**Layer B**: `extension/issue_locator.rb` — host glue. Takes the
`PolicyResult` and walks `model.instance_path_from_pid_path` for
each token, applies the entityID fallback, dedupes whole
`Entity` references, then returns a `LocateResult`.

Algorithm:

```
1. From controller.registry, find Issue by issue_id. If not found →
   return unresolved("issue_id not in current registry").
2. If !issue.locatable → return unresolved("issue is a non-locatable
   preflight warning").
3. For each SourceToken in issue.sources:
     policy = IssueLocatorPolicy.target_for(token)
     case policy
     when :root_leaf
       inst_path = SUCapability.resolve_pid_path(model, token.persistent_id_path)
       if inst_path.nil? → record source_no_longer_available
       else → targets << inst_path.leaf
     when :nested
       inst_path = SUCapability.resolve_pid_path(model, token.persistent_id_path)
       if inst_path.nil? → record source_no_longer_available
       else → targets << inst_path.root
     when :empty_root
       entity = SUCapability.find_entity_by_id(model, token.entity_id)
       if entity.nil? → record source_no_longer_available
       else → targets << entity
     when :empty_nested, :missing
       skip
     end
4. dedup(targets)  # Object#hash stable within session
5. If targets.empty? → return unresolved(diagnostic).
6. Return resolved(targets).
```

`extension/dialog_runner.rb#apply_selection_and_zoom`:

```
model = Sketchup.active_model
model.selection.clear                       # explicit, no accumulate
model.selection.add(targets)                # accepts Entities / Array
view = model.active_view
view.zoom(targets) if targets.size > 0
```

Testable via `tests/_fake_instance_path.rb` exposing `root` /
`leaf` / `to_a` / `empty?` — the locator test asserts:
- Root-level `[leaf_pid]` path → `target == inst_path.leaf`.
- Nested non-empty path → `target == inst_path.root`.
- Empty path with `nested == false` AND `entity_id` → `target == model.find_entity_by_id(entity_id)`.
- Empty path with `nested == true` → unresolved.
- Two-source duplicate/gap → both targets reached.
- Erased entity → resolved to nil → record source_no_longer_available.

**Hard rules**:
- `model.active_path` is NEVER mutated.
- `Selection#add` is preceded by `Selection#clear`.
- `View#zoom` is called only when targets is non-empty.
- `Sketchup::InstancePath` is NEVER passed to `Selection#add` or
  `View#zoom` (the test asserts this with `assert_raises`).
- `entity_id` is NEVER used for `issue_id` derivation; it is only
  a transient fallback for root-only empty PID paths.

### 6.4 HtmlDialog lifecycle (Codex BLOCK-004, closed)

Lifecycle order (registered BEFORE `show`):

```
1. UI::HtmlDialog.new(dialog_title:, preferences_key:, width:,
                       height:, left:, top:, resizable:)
2. dialog.set_file(File.expand_path('html/index.html', __dir__))
   # ABSOLUTE path; CSS/JS resolved relative to this file.
3. dialog.add_action_callback('ready') { |_ctx| push_data(dialog, controller) }
   dialog.add_action_callback('locate_issue') { |_ctx, issue_id| on_locate_issue(...) }
   dialog.set_on_closed { controller.release! }
4. controller.bind(dialog)   # circular ref managed via release
5. dialog.show
```

JS side:

```
// app.js
document.addEventListener('DOMContentLoaded', function () {
  window.SUAIP = {
    render: function (payload) { /* render JSON-safe Hash */ },
    toast:   function (msg)    { /* non-blocking status line */ }
  };
  window.sketchup.ready();
});
```

Ruby side:

```
push_data(dialog, controller):
  payload = UIBridge.as_html_data(controller.result)
  json = JSON.generate(payload)
  dialog.execute_script("window.SUAIP.render(#{json})")
```

Hard rules:

- **No `eval`, no `new Function`, no `document.write`, no `innerHTML`
  for user-supplied strings** — enforced by `test_html_render.rb`.
- The Ruby Hash → JS Hash passes only via `JSON.generate` +
  `execute_script` invoking the fixed `window.SUAIP.render` function.
  Never interpolate user text into JS.
- `add_action_callback` registers **blocks** (the real API), not
  `method(:name)`. The block yields `|action_context, *args|`. The
  block signature is `|_ctx| -> push_data` for `ready` and
  `|_ctx, issue_id| -> locate` for `locate_issue`.
- Callbacks are async and cleared on dialog close. `set_on_closed`
  releases `controller` references; the next `show` re-creates the
  controller and rebinds callbacks.
- `controller.bind(dialog)` stores the dialog reference for
  `execute_script` calls. `controller.release!` nils it.

### 6.5 Issue ID determinism (R005 + BLOCK-001 v2)

Already covered in §3.6. The canonical_source_keys array is
sorted before the counter is assigned; the counter is the last
tie-breaker. `entity_id` is NEVER used.

### 6.6 Group ordering (R005 + Codex Q1 answer)

Top-to-bottom order on the page:

1. Group by `issue_type` in this order: `duplicate_edge_candidate`,
   `short_edge`, `open_endpoint`, `gap_candidate`,
   `significant_non_zero_z`, `abnormal_large_coord`, `deep_nesting`.
2. Within each group, sort by `issue_id` ASC (lexicographic).
3. Each group is a `<details>` element. **Default-open**:
   - true iff the group contains at least one `:high` Issue, OR
   - true iff the IssueRegistry has no `:high` Issue AND this is
     the first non-empty group (per Codex Q1 answer).
4. `<summary>` shows: `Duplicate edge candidates (12)` etc.

Implementation lives in `core/issue_grouper.rb` (pure-Ruby, fully
unit-testable).

### 6.7 Summary header

A two-line header at the top of the page:

```
CAD Analyzer Result
Selection: <selection_label>   Edges: 1234   Vertices: 678
```

Lines:

- Title: "CAD Analyzer Result".
- `selection_label` from `AnalysisResult.selection_label`.
- Counts: `Edges: NN`, `Vertices: NN`,
  `Duplicate candidates: NN`, `Short edges: NN`,
  `Open endpoints: NN`, `Gap candidates: NN`,
  `Non-zero-Z vertices: NN`, `Warnings: NN`.

### 6.8 Ruby 2.2.4 syntax discipline

Same rules as Stage 2:

- No `&.` safe-navigation.
- No `case/in` pattern matching.
- No `(param =)` shorthand.
- No `def foo() = expr` endless defs.
- No `frozen_string_literal: true` magic comment.
- No `_1`, `_2` numbered params.
- No `$ERROR_INFO` (use `$ERROR_MESSAGE`).
- Strings use `to_s` explicitly on any object that could be a
  `Float` / `Integer` / `nil`.
- All `require` are `require_relative` (no gem deps).

Lint extension: `tests/test_ruby_22_syntax_sweep.rb` covers the
existing 17 files plus the new Stage 6 files.

### 6.9 JS contract discipline

- No `eval`, no `new Function`, no `document.write`, no `innerHTML`
  for user-supplied strings (enforced by `test_html_render.rb`).
- All interop data is JSON-shaped (String, Number, Boolean, Array,
  Object). No functions, no Symbols, no Dates.
- Click handler is the only outbound call. No push to SU.
- `locate_issue` callback receives ONLY an `issue_id` String.
- `ready` callback receives nothing.
- All issue data is rendered via `textContent` / `setAttribute`.

### 6.10 Error handling (PI_TASK_001 §18)

Every external boundary has a `rescue StandardError`:

- `extension/analyzers_runner.rb`: per-analyzer rescue; one bad
  analyzer does not stop the others. Recorded in `diagnostics`.
- `extension/dialog_runner.rb#on_locate_issue`: if resolve fails,
  write to SU console and show in-dialog toast. NEVER raise to JS.
- `core/issue_id_assigner.rb`: if PIDs are missing, fall back to
  geometry signature; never raise.
- `core/issue_enricher.rb`: if a snapshot edge lookup fails, drop
  the source_token from the issue and continue; record the missing
  edge_id in `metadata`.
- `extension/ui_bridge.rb`: serialization is lossy-tolerant; missing
  fields render as "—" not throw.
- `IssueRegistry.new`: drops malformed Issues with diagnostic,
  never aborts the analysis.

## 7. Test matrix (target ~140 new tests, ~210 total)

Per Codex NIT: the test count is a soft target, not a hard
requirement. We aim for the **smallest risk-based suite** that
proves the contracts; we do not write tests to hit a round number.

| Suite | Tests | What's covered |
|---|---|---|
| `test_issue_registry` | ~12 | validation, tolerant drop, determinism, grouping, summary, empty-registry |
| `test_issue_id_assigner` | ~6 | stability, fallback, no `object_id` / no `entity_id` |
| `test_issue_enricher` | ~8 | aligned tokens, missing-edge diagnostic, whole-token dedup, empty-root fallback |
| `test_issue_normalizer` | ~12 | per-type mapping, preflight warning → Issue, severity String end-to-end |
| `test_issue_grouper` | ~6 | group order, count, default_open per Q1 |
| `test_analysis_result` | ~5 | immutability, single construction point |
| `test_issue_locator_policy` | ~10 | profile targets, no host deps |
| `test_core_no_host_dependency` | ~6 | no `Sketchup` / `UI` / `Geom` / `compatibility` / `extension` tokens in new core files |
| `test_issue_locator` | ~10 | root-leaf, nested root, empty-root entityID, empty-nested, two-source, erased |
| `test_analyzers_runner` | ~8 | one snapshot per command, explicit snapshot_lookup, registry build |
| `test_loader` | ~6 | idempotent registration across reloads, empty/unsupported selection handling |
| `test_dialog_runner` | ~10 | set_file absolute path, ready handshake, callback rebind on reopen, JSON.execute_script, no model mutation |
| `test_ui_bridge` | ~6 | Hash shape, no SU types, JSON-safe escaping |
| `test_display_unit_formatter` | ~4 | `Sketchup.format_length` integration + non-SU fallback |
| `test_html_render` | ~8 | no `eval`, no `innerHTML` for user-supplied strings, JS source parses |
| `test_no_overlay_lint` | ~5 | `Ripper.lex` scan, comment/string stripping, zero forbidden tokens |
| `test_ruby_22_syntax_sweep` | 1 | 30+ files, 0 syntax issues |

## 8. Sub-stage breakdown + Codex review round plan (consolidated)

| Gate | Sub-steps | Codex review round | Verdict target |
|---|---|---|---|
| **Gate A — Core contract** | `core/issue_registry.rb`, `core/issue_id_assigner.rb`, `core/issue_enricher.rb`, `core/issue_normalizer.rb`, `core/issue_grouper.rb`, `core/analysis_result.rb`, `core/issue_locator_policy.rb` + 7 test files + `test_core_no_host_dependency` | Round 012 | All BLOCK-001 v2 sub-issues CLOSED |
| **Gate B — HtmlDialog integration** | `extension/issue_locator.rb`, `extension/display_unit_formatter.rb`, `extension/loader.rb`, `extension/analyzers_runner.rb`, `extension/dialog_runner.rb`, `extension/dialog_controller.rb`, `extension/ui_bridge.rb`, `extension/html/*`, `tests/_fake_ui.rb`, `tests/_fake_instance_path.rb`, `Review/OWNER_VERIFICATION_STAGE_6.txt` + 6 test files + lint extensions | Round 013 | All BLOCK-002 / 003 / 004 sub-issues CLOSED |

Between Gates A and B, only BLOCK fix passes run. After Gate B
passes, One Owner Verification Stage 6 run on SketchUp 2020 (per
Q002=A), then SU2017 (per R004, release Gate).

## 9. Risks (graded by Codex severity)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `UI::HtmlDialog` API drift in newer SU | Low | Medium | Capability probe is `defined?`-based; `test_no_overlay_lint` keeps the call surface narrow. |
| `model.active_path` returns a non-Array in some edge case | Low | Low | Already covered by S2-BLOCK-002 round 3 fix; `test_analyzers_runner` re-probes. |
| Selection callback race when Owner clicks 2 issues in rapid succession | Low | Low | UI is single-threaded by SU's design; click handler is idempotent (selection.clear + selection.add). |
| HtmlDialog shows but does not register `add_action_callback` due to a SU bug | Very Low | Medium | `test_dialog_runner` asserts the callback registration happens; Owner verifies on SU2020. |
| Owner closes the model while the dialog is open | Low | Low | `set_on_closed` handler releases controller; on `model.close` SU dismisses the dialog automatically. |
| CSS / layout regression on SU2017 | Medium | Low | No CSS feature newer than 2017; use `display: block` + `margin`. |
| JS bridge exposes a method that mutates | Low | High | `test_html_no_mutation` whitelists allowed types; `test_no_overlay_lint` covers the Ruby side. |
| Asset path is relative → CSS/JS unresolvable | Medium | High | Fixed by `set_file(absolute_path)` with `File.expand_path('html/index.html', __dir__)`. |
| `InstancePath` accidentally passed to `Selection#add` | Low | High | `test_issue_locator` asserts the locator never returns InstancePath; `test_dialog_runner` asserts only `Entity` / `Array<Entity>` reach `Selection#add`. |
| Snapshot double-build (run twice) | Low | Medium | `test_analyzers_runner` asserts one snapshot per command. |
| Menu item duplicates on Ruby reload | Low | Low | `loader.rb#register!` is idempotent; `test_loader` reloads and asserts count stays 1. |
| Source token alignment lost in enrichment | Low | High | `test_issue_enricher` asserts positional alignment; tokens are deduped whole, not field-by-field. |
| Empty-root entityID fallback picks wrong occurrence | Low | High | Restricted to `nested == false` only; nested empty-path → non-locatable. `test_issue_locator` covers both branches. |

## 10. Open questions answered by Codex (Q1-Q6)

| # | Codex answer | Implementer consequence |
|---|---|---|
| Q1 | Default-open: every group with `:high` Issue; if no `:high`, open first non-empty group | `IssueGrouper` carries the policy; one test case per branch |
| Q2 | In-dialog non-blocking status + one console line; no modal messagebox; no exception to JS | `dialog.execute_script("window.SUAIP.toast(...)")` + `$stdout.puts` |
| Q3 | New focused Stage 6 checklist (5 steps J..N); do NOT append to Stage 2 | `Review/OWNER_VERIFICATION_STAGE_6.txt` |
| Q4 | External local files via `set_file` absolute path; NO heredoc embedding | `set_file(File.expand_path('html/index.html', __dir__))` |
| Q5 | Internal: raw inch Float; Display: `Sketchup.format_length` strings | `extension/display_unit_formatter.rb` (only host-dependent formatter) |
| Q6 | New `Review/OWNER_VERIFICATION_STAGE_6.txt`; do not extend Stage 2 | Listed in §4.1 |

## 11. Owner Verification Stage 6 (per Codex Q3 + NIT)

New file: `Review/OWNER_VERIFICATION_STAGE_6.txt`. Five steps J..N:

- J. Plugin load smoke — load SketchUp → confirm menu item "Analyze
  selection" appears under Plugins menu. Run the loader twice (Ruby
  reload simulation: re-`require`) and confirm the menu item count
  stays at 1.
- K. Complete analysis on a disposable Group — click menu → confirm
  HtmlDialog opens, summary header shows correct counts, grouped
  issue sections render with each section's count in its heading.
- L. Root/nested/multi-source Locate — click a duplicate Issue,
  click a nested Issue, click a gap Issue. Confirm selection +
  camera zoom fires; no overlay; no `active_path` mutation.
- M. Stale source behavior — analyze, then ERASE the source entity
  in the **same test model** (not another SU window), then click
  the Issue. Confirm in-dialog toast + one console line; no
  exception popup.
- N. Source integrity fingerprint — run the following Ruby snippet
  pre and post the entire Stage 6 flow:
  ```ruby
  m = Sketchup.active_model
  fp = {
    edges:           m.edges.length,
    faces:           m.faces.length,
    groups:          m.entities.count { |e| e.is_a?(Sketchup::Group) },
    components:      m.entities.count { |e| e.is_a?(Sketchup::ComponentInstance) },
    layers:          m.layers.length,
    materials:       m.materials.length,
    styles:          m.styles.length,
    tags:            (m.respond_to?(:tags) ? m.tags.length : 0)
  }
  ```
  Confirm `fp` is byte-identical before and after. `Model Info →
  Statistics` is unreliable for layer/material/style counts; the
  Ruby fingerprint is the canonical check.

## 12. Self-imposed constraints (mirroring Stage 2)

- No new gem dependency.
- No commit auto-push.
- No model mutation (proven by `test_no_overlay_lint` + Owner
  verification N).
- Working tree clean between gates.
- Owner is gatekeeper of `Prompt/`.
- `Review/` is the Agent's output channel; `Prompt/` is the
  Codex/Owner input channel (per AGENTS.md §1b).

## 13. CURRENT_STATE.md update timing (per Codex NIT)

CURRENT_STATE.md is updated **after** Codex's Gate B APPROVED
verdict — not earlier. Stage 2 history is closed and not
rewritten. The Stage 6 entry is appended under the existing
"决策落地" table and the "CODEX REVIEW" section.

## 14. Out of scope (V1.0 / V1.1+)

- Auto-fix (PI_TASK_001 §17).
- Settings UI (PI_TASK_001 §17).
- Stage 7 TASK 001 IMPLEMENTATION REPORT (PI_TASK_001 §22) —
  only after Stage 6 Owner verification.
- Rich leaf-level visual highlighting inside a closed nested
  component (per Codex DEBT: V1 may select/zoom the root
  occurrence).
- IssueRegistry richer data model (Stage 3+).
- Profile / company-branded palette override (R003 Q3.4 noted
  "configurable later via Company Profile").
- Filter / search / column sort (R005).
- Per-Issue high-detail inspector (R003 Q3.5 = A single action).
- HTML opens in external browser vs HtmlDialog (R003 Q3.2 = A).

## 15. Summary for Codex (revised v2)

Stage 6 is split into **2 gates**:
- **Gate A** — Core contract: `IssueRegistry`, `IssueIdAssigner`,
  `IssueEnricher`, `IssueNormalizer`, `IssueGrouper`, `AnalysisResult`,
  `IssueLocatorPolicy` (pure-Ruby) + 7 test files +
  `test_core_no_host_dependency`. Codex Round 012.
- **Gate B** — Host-side integration: `extension/issue_locator.rb`,
  `extension/display_unit_formatter.rb`, `extension/loader.rb`,
  `extension/analyzers_runner.rb`, `extension/dialog_runner.rb`,
  `extension/dialog_controller.rb`, `extension/ui_bridge.rb`,
  `extension/html/{index.html, style.css, app.js}`,
  `Review/OWNER_VERIFICATION_STAGE_6.txt`, plus
  `tests/_fake_ui.rb`, `tests/_fake_instance_path.rb`, lint
  extensions, and ~6 test files. Codex Round 013.

The 2 reopens are addressed:

- **BLOCK-001 v2**: §3.1–§3.2 replace the parallel arrays with an
  aligned `sources: Array<SourceToken>` array of Hashes. §3.6
  explicitly forbids `entity_id` for `issue_id` derivation. §3.9
  dedupes whole tokens. §6.3 separates the policy (pure-Ruby token
  profile → target descriptor) from the host glue (resolves to
  Entity). Root-leaf path `[leaf_pid]` is the normal root case;
  empty path means missing PID capability, with a root-only
  `entity_id` fallback (`model.find_entity_by_id`).
  Nested empty-path → non-locatable (no entityID fallback).
- **BLOCK-003**: §4.1 moves `issue_locator.rb` and
  `display_unit_formatter.rb` to `extension/`. The new
  `test_core_no_host_dependency` lint enforces that no
  new `core/*.rb` file references `Sketchup`, `UI`, `Geom`,
  `compatibility`, or `extension`. `core/issue_locator_policy.rb` is
  the only pure-Ruby piece (depends on token shapes, not on SU).

6 NITs addressed:
- `snapshot.edges_by_id` → explicit index built in §5
  (`snapshot_lookup`).
- `IssueRegistry` constructor: per-Issue validation may raise
  internally; the public constructor catches `InvalidIssue`, drops
  the malformed Issue, records a diagnostic, and returns a valid
  registry. The constructor itself never both raises and continues
  for the same error.
- `Ripper.lex` for the no-overlay lint (not AST nodes).
- Owner verification step M rewritten: erase in the **same test
  model**, not another SU window.
- Owner verification step N uses a Ruby fingerprint for
  layer/material/style counts in addition to Model Info Statistics.
- Test count is a soft target, not a hard requirement.

Awaiting Codex verdict on Gate A start authorization.
