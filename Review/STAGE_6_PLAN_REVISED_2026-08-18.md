# Stage 6 — UI Implementation Plan (revised per Codex Review 010)

| Field | Value |
|---|---|
| Date | 2026-08-18 (revised after Codex Review 010, BLOCKED) |
| Previous packet | `Review/STAGE_6_PLAN_2026-08-18.md` (SUPERSEDED) |
| Project | D:\Projects\SU-AI-Plugin |
| Stage | 6 (UI — `UI::HtmlDialog` + Issue registry presentation) |
| Locked decisions | R001 / R002 / R003 / R004 / R005 |
| Source-of-truth contracts | PI_TASK_001 §11 / §12 / §13 / §14 / §17 / §18 / §91 |
| Author | Agent (revised after Codex Review 010) |
| Status | **REVISED — addresses S6-PLAN-BLOCK-001..004** |
| Codex Review 010 verdict | BLOCKED (4 BLOCKs + 6 NITs + 6 answers) |


## 0. Why this is a revision

Codex Review 010 (2026-08-18, Prompt/CODEX_REVIEW_010…) returned
**VERDICT: BLOCKED** with 4 BLOCKs and 6 NITs. The BLOCKs surfaced
three underlying gaps in the original packet:

1. The Issue contract written in the plan did not match the actual
   analyzer output (`kind` vs `issue_type`, `severity` String vs
   Symbol, no SourceReference, multi-source duplicates, gap with
   empty `source_entity_ids`, Preflight warnings not joined).
2. The runtime flow threw away the GeometrySnapshot via
   `PreflightRunner.run` (returns only `PreflightReport`) and the
   plan claimed a menu item existed when none does.
3. The HtmlDialog handshake was incomplete (`set_html` vs
   `set_file`, callback signature shape, no ready handshake,
   production `SUCapability` polluted with test fakes).

The four BLOCKs are addressed in §3 (contract), §5 (runtime flow),
§6.3 (locate policy), and §6.4 (HtmlDialog lifecycle). All 6 NITs
are addressed in §6.1 (lint), §8 (consolidate to 2 gates), §3.6
(remove false claim), §13 (CURRENT_STATE timing). All 6 Codex
decisions on Q1-Q6 are reflected in §6.6, §6.3, §6.4, §11, §10.5,
§11.2.

No code has been written yet. The plan is the only artifact under
review. Codex Review 010 directive: "Correct the plan only. Do not
begin Stage 6 implementation until the four BLOCKs below are
incorporated."


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
| NEW (Q5) | Internal: raw inch Float; Display: `Sketchup.format_length` strings | API in core/ stays unit-agnostic; UI consumes display strings |


## 2. What V1.0 UI does and does NOT do

### Does
- Display CAD Analyzer Result header (summary metrics).
- Display issue list grouped by `issue_type`, each section `<details>`,
  with `(NN)` count in the heading.
- Render severity badge per issue (`:low` neutral / `:medium` orange /
  `:high` red).
- On Issue row click: resolve source paths to InstancePath(s),
  dedupe, `selection.clear` + `selection.add(entities)` (or root
  occurrence for nested), `view.zoom(entities)` — read-only.
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


## 3. The unified Issue / AnalysisResult contract (S6-PLAN-BLOCK-001 fix)

This is the seam that the whole UI depends on. It is defined here in
the plan, **before** any class names. Classes in §4 must conform.

### 3.1 `UIIssue` Hash (the canonical contract — JSON-safe)

Every Issue that reaches the UI MUST be a Hash with the following
keys. No Symbol values, no `Sketchup::*` types, no callable objects.

| Key | Type | Required | Notes |
|---|---|---|---|
| `issue_id` | String | yes | Deterministic; see §3.5 |
| `issue_type` | String | yes | Canonical names from §3.4 |
| `severity` | String | yes | One of `"low"` / `"medium"` / `"high"` |
| `confidence` | String | yes | One of `"low"` / `"medium"` / `"high"` |
| `source_paths` | Array<Array<Integer>> | yes | Each = `persistent_id_path` from a SourceReference; root-level is `[]` |
| `source_entity_ids` | Array<Integer> | yes | Transient in-memory keys; may be empty |
| `edge_ids` | Array<Integer> | yes | Stable across the registry; may be empty |
| `location` | Array<Float,3> or null | yes | World-space midpoint or null when no spatial anchor |
| `message` | String | yes | Human-readable, free of control chars |
| `metadata` | Hash<String,JSON-safe> | yes | Free-form; must be JSON-safe |
| `locatable` | Boolean | yes | true iff at least one `source_path` is non-empty |
| `display_length` | String or null | new | Pre-formatted via `Sketchup.format_length`; only set for length-bearing issues |

### 3.2 `AnalysisResult` (one immutable return value)

A single immutable wrapper that the entire pipeline produces and
the dialog consumes. Built once per `Analyze selection` command.

| Field | Type | Source |
|---|---|---|
| `preflight` | `PreflightReport` | `PreflightAnalyzer.run(snapshot)` |
| `registry` | `IssueRegistry` (see §3.3) | normalized from analyzer + preflight output |
| `snapshot_lookup` | `Hash<Integer, EdgeRecord>` | `snapshot.edges_by_id` (or build a one-shot index) |
| `display_units` | `Hash` per §3.6 | `Sketchup.format_length` pre-formatting |
| `diagnostics` | `Array<Hash>` | per-stage errors, skipped entities, malformed-issue drops |
| `selection_type` | String | from preflight |
| `selection_label` | String | container name when present; "selection" otherwise |

`AnalysisResult` is **frozen** at construction (no setters, no
mutators). All consumers can rely on this.

### 3.3 `IssueRegistry` (pure-Ruby, replaces the plan's earlier stub)

| Property | Value |
|---|---|
| Holds | `Array<Hash>` of UIIssue (defined in §3.1) |
| Validation | raises `IssueRegistry::InvalidIssue` on construction if any Issue is missing a required key, has a non-canonical severity, has un-`to_s`-able field, or has a non-`Array` `source_paths` |
| On validation failure | per Codex decision: **continue with valid Issues and record the dropped one in `diagnostics`**. Do NOT abort the entire analysis because one Issue is malformed. |
| `open?` | true iff at least one Issue has `severity == "high"` |
| `summary` | `Hash{ issue_type => count }` |
| `groups` | `Array<{ type: String, count: Integer, default_open: Boolean, issues: Array<Hash> }>` — already sorted per §6.6 |
| `each`, `find(id)` | standard enumeration |

### 3.4 Canonical `issue_type` strings (R005 + per-type mapping)

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
issue_type) lives at **one boundary** in
`core/issue_normalizer.rb`. No other file runs the mapping.

### 3.5 Deterministic `issue_id` (R005 + Codex S6-PLAN-BLOCK-001 fix)

The ID is built from canonical source keys, NOT raw `object_id`.
Algorithm (executed in `core/issue_id_assigner.rb`):

```
1. Build canonical_source_keys = canonicalize(source_paths):
     for each source_path:
       - if non-empty:  serialize as dot-string "10.20.555"
       - if empty:       use geometry signature from `location`
                         quantized at coord epsilon
                       (or fall back to "edge_id:#{edge_id}" when
                        edge_ids are present and location is null)
     sort the resulting Array<String> deterministically (lex order).
2. Compute issue_type_signature = issue_type (canonical).
3. counter_within_type = running counter starting from 1, scoped
       to the registry, sorted by canonical_source_keys.
4. issue_id = "{issue_type}|{canonical_source_keys.join('+')}|{counter}"
```

The counter is the **last** tie-breaker, applied only after the
canonical keys are sorted. Two calls with the same inputs produce
the same `issue_id`.

The Issue ID MUST be a String (not a Symbol, not an Integer) for
JSON serialization safety and to avoid `respond_to?` freeze-edge
issues.

### 3.6 Display-unit formatting (Codex Q5 answer)

Core stays unit-agnostic. The Issue Registry keeps raw inch Float
values in `location` and `metadata`. A separate `display_length`
String is attached only when the analysis is run inside SketchUp,
using `Sketchup.format_length`. Format:

- `edge length` in `metadata` of `short_edge` / `duplicate_edge_candidate` →
  `display_length` = `Sketchup.format_length(value)`.
- `distance` in `metadata` of `gap_candidate` → `display_length` =
  `Sketchup.format_length(distance)`.
- Non-SU test runs: `display_length` = `format("%.4f inch", value)`
  (a deterministic fallback for unit tests).

`AnalysisResult.display_units` exposes a `Hash{ issue_id => display_length }`
that the UI reads. The UI never calls `Sketchup.format_length`.

### 3.7 Preflight-warning → Issue conversion (S6-PLAN-BLOCK-001 fix)

Each Preflight warning Hash (kind: `:significant_non_zero_z`,
`:abnormal_large_coord`, `:deep_nesting`) is converted to a UIIssue
with:

- `source_paths: []`, `source_entity_ids: []`, `edge_ids: []`
- `location: null`
- `locatable: false`
- `message`: preflight warning's `:message` (sanitized to ASCII
  printable; no control chars)
- `metadata`: `{"code": "<preflight_code>"}`
- `display_length`: null

The UI renders these as non-clickable rows (no Locate action on
click; instead a clean "not locatable" affordance — see §6.3).

The conversion is **explicit** in `core/issue_normalizer.rb` and
covered by unit tests for each of the three preflight codes.

### 3.8 Issue enrichment from `edge_ids` (S6-PLAN-BLOCK-001 fix)

`core/issue_enricher.rb` (NEW) takes the snapshot's EdgeRecord
index and the raw analyzer Issues, and produces Issues with full
`source_paths` arrays.

Algorithm per Issue:

```
1. For each edge_id in Issue.edge_ids:
     rec = snapshot.edges_by_id[edge_id]
     if rec is nil:
       skip and record "(missing edge_id #{edge_id})" in metadata
     else:
       source_paths << rec.source.persistent_id_path
       source_entity_ids << rec.source.entity_id
2. Drop empty source_paths entries (root-level entities).
3. de-duplicate source_paths (preserve order).
4. If source_paths is empty AND edge_ids is empty AND this is not a
   preflight warning: log to diagnostics and drop the Issue.
5. Set locatable = source_paths.size > 0 OR
       (root-level edge case where source_path is [] and source
        was found — see §6.3 root/leaf policy).
```

This is the one place where `source_entity_ids` is enriched. After
this, no downstream code re-derives source paths.

### 3.9 Gap-candidate empty-source fix (S6-PLAN-BLOCK-001 fix)

`GapCandidateDetector` currently emits `source_entity_ids: []`.
After enrichment (§3.8), the gap's `source_paths` will be
populated from the two endpoint edges. The enricher is the
canonical fix; the analyzer is **not** patched in this stage
(Stage 2 BLOCK rework is closed, scope discipline).

### 3.10 Multi-source Issues (duplicate / gap)

Duplicate and gap Issues have **two source Edges**. Both
`source_paths` are kept. The locator (§6.3) handles multi-source.

## 4. File inventory (revised)

### 4.1 New files

| Path | LoC est. | Purpose | Codex gate |
|---|---|---|---|
| `core/issue_registry.rb` | ~150 | Pure-Ruby IssueRegistry per §3.3; validates UIIssue Hash; tolerant drop on malformed | A |
| `core/issue_id_assigner.rb` | ~80 | Deterministic IDs per §3.5; never uses `object_id` | A |
| `core/issue_enricher.rb` | ~80 | Enriches analyzer Issues with `source_paths` from `edge_ids` via snapshot lookup | A |
| `core/issue_normalizer.rb` | ~120 | One-boundary normalization: `kind` → `issue_type`, String → Symbol severity, R005 per-type mapping, preflight warning → Issue | A |
| `core/issue_grouper.rb` | ~80 | Pure-Ruby grouping by `issue_type` per §6.6 | A |
| `core/analysis_result.rb` | ~80 | Immutable wrapper per §3.2; one per `Analyze selection` | A |
| `core/issue_locator.rb` | ~120 | Pure-Ruby source-path resolution policy (root/leaf/multi-source, dedup, selection.clear + add, in-dialog status) | B |
| `extension/loader.rb` | ~120 | Plugin load: `UI.menu` / `UI::Command` registration, idempotent, "Analyze selection" command | B |
| `extension/analyzers_runner.rb` | ~120 | One-pass: snapshot → preflight → analyzers → normalize → enrich → registry → AnalysisResult | B |
| `extension/dialog_runner.rb` | ~150 | HtmlDialog lifecycle, callbacks as blocks, ready handshake, FakeUI factory injection | B |
| `extension/dialog_controller.rb` | ~120 | Per-dialog state (registry, registry-version, model lookup, registry-snapshot-list, diagnostics) | B |
| `extension/ui_bridge.rb` | ~80 | Pure-Ruby serialization of `AnalysisResult` to JS-safe Hash (no `Sketchup::*` types) | B |
| `extension/html/index.html` | ~200 | Single-page summary + grouped `<details>` sections; loads via `set_file` absolute path | B |
| `extension/html/style.css` | ~140 | Severity palette: low=neutral, medium=orange, high=red | B |
| `extension/html/app.js` | ~250 | Renders JS Hash; click → `window.sketchup.locate_issue(issue_id)`; calls `window.sketchup.ready()` on `DOMContentLoaded` | B |
| `tests/test_issue_registry.rb` | ~150 | Pure-Ruby: validation, determinism, grouping, summary, malformed tolerant drop | A |
| `tests/test_issue_id_assigner.rb` | ~80 | Pure-Ruby: stability, fallback, no `object_id` | A |
| `tests/test_issue_enricher.rb` | ~80 | Pure-Ruby: edge lookup, missing edge diagnostic, empty-source fallback | A |
| `tests/test_issue_normalizer.rb` | ~100 | Pure-Ruby: per-type mapping, preflight warning → Issue, severities canonical | A |
| `tests/test_issue_grouper.rb` | ~80 | Pure-Ruby: grouping, count, default_open per Q1 answer | A |
| `tests/test_analysis_result.rb` | ~80 | Pure-Ruby: immutability, single construction point | A |
| `tests/test_issue_locator.rb` | ~100 | Adapter: FakeInstancePath, root/leaf/multi-source, dedup, resolve-failure status | B |
| `tests/test_analyzers_runner.rb` | ~120 | Adapter: one snapshot per command, registry built from snapshot | B |
| `tests/test_loader.rb` | ~80 | Adapter: FakeUI Command registry; idempotent registration across reloads | B |
| `tests/test_dialog_runner.rb` | ~120 | Adapter: set_file path, ready handshake, callback rebind on reopen, JSON.execute_script, no `eval`/`innerHTML`/`document.write` | B |
| `tests/test_ui_bridge.rb` | ~80 | Pure-Ruby: Hash shape, no SU types, escaping for JSON | B |
| `tests/test_html_render.rb` | ~120 | Pure-Ruby: token scan of JS source for `eval`, `new Function`, `document.write`, `innerHTML` for user-supplied strings; static lint of HTML/CSS | B |
| `tests/test_no_overlay_lint.rb` | ~80 | AST-aware scan of `extension/*.rb` for forbidden tokens (see §6.1) | B |
| `tests/test_ruby_22_syntax_sweep.rb` | 1 | Extended sweep: 22 + new files; 0 syntax issues | B |
| `tests/_fake_ui.rb` | ~150 | Fake `UI::HtmlDialog` + `UI::Command` + `UI::Menu` for adapter tests — `tests/` only | B |
| `tests/_fake_instance_path.rb` | ~80 | Fake `Sketchup::InstancePath` (root/leaf/to_a/empty) for locator tests | B |
| `Review/OWNER_VERIFICATION_STAGE_6.txt` | n/a | Owner Verification Stage 6 checklist (5 steps J..N) per Codex Q3 answer | B |

### 4.2 Modified files

| Path | Modify |
|---|---|
| `compatibility/su_capability.rb` | **No fake hooks added.** Read-only probes (`html_dialog?`, `sketchup_version`, `resolve_pid_path`, `serialize_pid_path`, `active_edit_context`) only. No `fake_ui?`, no `fake_html_dialog`. |
| `tests/_fake_su.rb` | Add `FakeUI` namespace (delegate to `tests/_fake_ui.rb`); add `FakeInstancePath` (delegate to `tests/_fake_instance_path.rb`). |
| `extension/preflight_runner.rb` | **No behavioral change.** Keep S2-BLOCK closed. Stage 6 calls `build_snapshot` directly, not `run`. |
| `tests/runner.rb` | No change. |
| `CURRENT_STATE.md` | Update only after the Stage 6 plan is approved (per Codex NIT). |

### 4.3 What is NOT being added

- No `extension/repair_runner.rb` (PI_TASK_001 §17).
- No `extension/settings.rb` (PI_TASK_001 §17).
- No overlay / construction geometry helper (R003 hard prohibition).
- No persistent-id browser / entity-info helper (R003 Q3.5=A).
- No new gem dependency (Ruby 2.2.4 + zero gem deps).
- No external JS / CSS library (no jQuery, no React, no Bootstrap).
- No fake hooks in production `SUCapability` (per Codex BLOCK-004).
- No menu item reaches into a non-existent registry (per Codex
  BLOCK-002 — the menu command is registered in `extension/loader.rb`).

## 5. Runtime flow (revised — one snapshot, one AnalysisResult)

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
      dialog_runner.show(result)   # may defer if HtmlDialog not ready
    rescue StandardError => e
      log_diagnostic_and_show_fallback(e)
    ensure
      clear_progress_indicator
    end

  analyzers_runner.run(selection, model):
    # ONE snapshot per command — rebuild NOT allowed downstream.
    snapshot     = PreflightRunner.build_snapshot(selection, model: model)
    preflight    = PreflightAnalyzer.run(snapshot)
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
    enriched        = IssueEnricher.enrich_all(raw_issues, snapshot)
    normalized      = IssueNormalizer.normalize_all(enriched)
    registry        = IssueRegistry.new(normalized, diagnostics: diagnostics)
    AnalysisResult.new(
      preflight:        preflight,
      registry:         registry,
      snapshot_lookup:  snapshot.edges_by_id,
      display_units:    DisplayUnitFormatter.format_all(registry,
                                       model: model),
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
    dialog.set_on_closed {
      controller.release!  # break reference cycle
    }
    controller.bind(dialog)
    dialog.show

  push_data(dialog, controller):
    payload = UIBridge.as_html_data(controller.result)
    # payload is JSON-safe; no Sketchup:: types, no Symbol, no callable.
    json = JSON.generate(payload)
    # Use execute_script to call one fixed render function. Never interpolate
    # user-supplied text into JS.
    dialog.execute_script("window.SUAIP.render(#{json})")

  on_locate_issue(dialog, controller, issue_id):
    return unless issue_id.is_a?(String)
    return unless controller.registry.find(issue_id)
    result = IssueLocator.locate(controller.result, issue_id,
                                 model: Sketchup.active_model)
    if result.status == :resolved
      apply_selection_and_zoom(controller, result.targets)
    else
      # Non-blocking toast (no messagebox, no exception to JS)
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

## 6. Critical implementation rules

### 6.1 NO overlay / NO mutation enforcement (R003 hard prohibition)

Strategy — three layers:

**Layer 1: AST-aware static lint** (`tests/test_no_overlay_lint.rb`).

Per Codex NIT: literal wildcard `.entities.add_*` is NOT a whole-token
match in Ruby source. The lint is an AST-aware scanner that:

1. Reads each `.rb` file under `extension/`.
2. Strips comments (`#` to EOL) and string literals
   (single-quoted, double-quoted, percent-strings, heredocs).
3. Tokenizes via a Ruby parser (MRI `RubyVM::AbstractSyntaxTree` —
   available in Ruby 2.2+ only as `Ripper`; the lint uses `Ripper`
   for tokenization, which is in the standard library and works on
   Ruby 2.2.4).
4. Walks the token stream; on a `method_add_arg` or `method_add_block`
   node whose receiver or method name matches one of the forbidden
   patterns, FAIL with the file:line.

Forbidden tokens (case-sensitive, after stripping comments/strings):

```
- .add_cpoint, .add_cline, .add_face, .add_group,
- .add_component_instance, .add_image, .add_text,
- .add_3d_text, .add_section_cut,
- .entities.add_* (any descendant of .entities),
- .materials.add, .layers.add, .tags.add,
- .attribute_dictionary, .set_attribute, .material =,
- .layer =, .back_material =, .soft=, .hidden=,
- .erase_entities, .start_operation, .commit_operation,
- .active_path =
```

**Layer 2: `extension/` top-of-file banner.**
`extension/dialog_runner.rb` and `extension/loader.rb` carry a
block comment at the top reproducing the R003 hard prohibition
verbatim. Future Agents cannot miss it.

**Layer 3: `tests/_fake_su.rb` exemption.**
The lint is restricted to `extension/*.rb`. `tests/_fake_su.rb` is
exempt (as today). The lint test file itself is exempt.

**Layer 4: Owner Verification Stage 6 (per Codex Q3).**
A new `Review/OWNER_VERIFICATION_STAGE_6.txt` lists 5 steps
(J..N) that force Owner to compare model state pre/post analysis
via Model Info → Statistics and via a layer/material count delta.

### 6.2 Capability fallback (R002 / R003 Q3.2)

`SUCapability.html_dialog?` returns `true` on SU2017+ real SU. If
false: `UI.messagebox("Stage 6 UI requires UI::HtmlDialog (SU 2017+).
Detected: #{SUCapability.sketchup_version}.")`. No silent WebDialog
fallback, no `Sketchup::HtmlDialog` (per S2-BLOCK-006).

Testable via `tests/_fake_ui.rb` FakeUI having no `HtmlDialog`.

### 6.3 Locate policy (S6-PLAN-BLOCK-003 fix)

`core/issue_locator.rb` (pure-Ruby, no `Sketchup::*` resolution at
the layer boundary — the SU API calls happen in
`extension/dialog_runner.rb` at the bottom of the chain).

Inputs: `AnalysisResult`, `issue_id`, `model`.
Output: `LocateResult` with `:resolved` or `:unresolved` + optional
`:targets` (Array of EDGE / GROUP / COMPONENT_INSTANCE entities;
azero-element Array when unresolved).

Algorithm:

```
1. From controller.registry, find Issue by issue_id. If not found →
   return unresolved("issue_id not in current registry").
2. If !issue.locatable → return unresolved("issue is a non-locatable
   preflight warning").
3. For each source_path in issue.source_paths:
     inst_path = SUCapability.resolve_pid_path(model, source_path)
     if inst_path is nil → record source_path_no_longer_available
     else:
       if source_path.empty? (root-level entity):
         # Use the leaf entity directly.
         target = inst_path.leaf
       else:
         # Nested: select/zoom the root occurrence (Group / ComponentInstance)
         # NOT the leaf definition geometry. Read-only.
         target = inst_path.root
       targets << target
4. dedupe(targets)            # Object#hash stable within session
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
- Root-level path → `target == inst_path.leaf`.
- Nested path → `target == inst_path.root`.
- Empty path → unresolved.
- Duplicate paths → deduped.
- No path → unresolved + toast + console line.

**Hard rules**:
- `model.active_path` is NEVER mutated.
- `Selection#add` is preceded by `Selection#clear`.
- `View#zoom` is called only when targets is non-empty.
- `Sketchup::InstancePath` is NEVER passed to `Selection#add` or
  `View#zoom` (the test asserts this with `assert_raises`).

### 6.4 HtmlDialog lifecycle (S6-PLAN-BLOCK-004 fix)

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
  window.sketchup.ready();   // ASK Ruby to push data
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

### 6.5 Issue ID determinism (R005 + Codex BLOCK-001)

Already covered in §3.5. The canonical_keys array is sorted before
the counter is assigned; the counter is the last tie-breaker.

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

Every new file follows Stage 2 rules:

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
existing 17 files plus the new Stage 6 files (target 30+/30+).

### 6.9 JS contract discipline

- No `eval`, no `new Function`, no `document.write`, no `innerHTML`
  for user-supplied strings (enforced by `test_html_render.rb`).
- All interop data is JSON-shaped (String, Number, Boolean, Array,
  Object). No functions, no Symbols, no Dates.
- Click handler is the only outbound call. No push to SU.
- `locate_issue` callback receives ONLY an `issue_id` String.
- `ready` callback receives nothing.
- All issue data is rendered via `textContent` / `setAttribute`;

### 6.10 Error handling (PI_TASK_001 §18)

Every external boundary has a `rescue StandardError`:

- `extension/analyzers_runner.rb`: per-analyzer rescue; one bad
  analyzer does not stop the others. Recorded in `diagnostics`.
- `extension/dialog_runner.rb#on_locate_issue`: if resolve fails,
  write to SU console and show in-dialog toast. NEVER raise to JS.
- `core/issue_id_assigner.rb`: if PIDs are missing, fall back to
  geometry signature; never raise.
- `core/issue_enricher.rb`: if a snapshot edge lookup fails, drop
  the source_path from the issue and continue; record the missing
  edge_id in `metadata`.
- `extension/ui_bridge.rb`: serialization is lossy-tolerant; missing
  fields render as "—" not throw.
- `IssueRegistry.new`: drops malformed Issues with diagnostic,
  never aborts the analysis.

## 7. Test matrix (target ~125 new tests, ~200 total)

| Suite | Tests | What's covered |
|---|---|---|
| `test_issue_registry` | ~12 | validation, tolerant drop, determinism, grouping, summary, empty-registry |
| `test_issue_id_assigner` | ~6 | stability, fallback, no `object_id` |
| `test_issue_enricher` | ~8 | edge lookup, missing-edge diagnostic, empty-source fallback, duplicate/gap multi-source preserved |
| `test_issue_normalizer` | ~12 | per-type mapping, preflight warning → Issue, severity canonicalization |
| `test_issue_grouper` | ~6 | group order, count, default_open per Q1 |
| `test_analysis_result` | ~5 | immutability, single construction |
| `test_issue_locator` | ~10 | root/leaf, nested-multi-source, dedup, resolve-failure status |
| `test_analyzers_runner` | ~8 | one snapshot per command, registry build, per-analyzer rescue |
| `test_loader` | ~6 | idempotent registration across reloads, empty/unsupported selection handling |
| `test_dialog_runner` | ~10 | set_file absolute path, ready handshake, callback rebind on reopen, JSON.execute_script, no model mutation |
| `test_ui_bridge` | ~6 | Hash shape, no SU types, JSON-safe escaping |
| `test_html_render` | ~8 | no `eval`, no `innerHTML` for user-supplied strings, JS source parses |
| `test_no_overlay_lint` | ~5 | AST-aware scan, comment/string stripping, zero forbidden tokens |
| `test_ruby_22_syntax_sweep` | 1 | 30+ files, 0 syntax issues |

Target: 200+/200+ (was 72/72; new: ~130; total: ~200). Commit
messages will quote the exact count.

## 8. Sub-stage breakdown + Codex review round plan (consolidated per Codex NIT)

Per Codex NIT, consolidate 4 rounds into **2 meaningful gates**:

| Gate | Sub-steps | Codex review round | Verdict target |
|---|---|---|---|
| **Gate A — Core contract** | 6.1: `core/issue_registry.rb`, `core/issue_id_assigner.rb`, `core/issue_enricher.rb`, `core/issue_normalizer.rb`, `core/issue_grouper.rb`, `core/analysis_result.rb` + 6 test files | Round 011 | All BLOCK-001 sub-issues CLOSED |
| **Gate B — HtmlDialog integration** | 6.2: `core/issue_locator.rb`, `extension/loader.rb`, `extension/analyzers_runner.rb`, `extension/dialog_runner.rb`, `extension/dialog_controller.rb`, `extension/ui_bridge.rb`, `extension/html/*`, `tests/_fake_ui.rb`, `tests/_fake_instance_path.rb`, `Review/OWNER_VERIFICATION_STAGE_6.txt` + 6 test files + lint extensions | Round 012 | All BLOCK-002 / 003 / 004 sub-issues CLOSED |

Between Gates A and B, only BLOCK fix passes run. After Gate B
passes, One Owner Verification Stage 6 run on SketchUp 2020 (per
Q002=A), then SU2017 (per R004, release Gate).

This consolidated model halves the rework-loop overhead and gives
Codex a more meaningful review surface per round.

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

## 10. Open questions answered by Codex (Q1-Q6)

| # | Codex answer | Implementer consequence |
|---|---|---|
| Q1 | Default-open: every group with `:high` Issue; if no `:high`, open first non-empty group | `IssueGrouper` carries the policy; one test case per branch |
| Q2 | In-dialog non-blocking status + one console line; no modal messagebox; no exception to JS | `dialog.execute_script("window.SUAIP.toast(...)")` + `$stdout.puts` |
| Q3 | New focused Stage 6 checklist (5 steps J..N); do NOT append to Stage 2 | `Review/OWNER_VERIFICATION_STAGE_6.txt` |
| Q4 | External local files via `set_file` absolute path; NO heredoc embedding | `set_file(File.expand_path('html/index.html', __dir__))` |
| Q5 | Internal: raw inch Float; Display: `Sketchup.format_length` strings | `core/display_unit_formatter.rb` (NEW) is the only place that calls `Sketchup.format_length`; UI consumes `display_length` strings |
| Q6 | New `Review/OWNER_VERIFICATION_STAGE_6.txt`; do not extend Stage 2 | Listed in §4.1 |

## 11. Owner Verification Stage 6 (per Codex Q3)

New file: `Review/OWNER_VERIFICATION_STAGE_6.txt`. Five steps J..N:

- J. Plugin load smoke — load sketchup → confirm menu item "Analyze
  selection" appears under Plugins menu.
- K. Complete analysis on a disposable Group — click menu → confirm
  HtmlDialog opens, summary header shows correct counts, grouped
  issue sections render.
- L. Root/nested/multi-source Locate — click a duplicate Issue,
  click a nested Issue, click a gap Issue. Confirm selection +
  camera zoom fires; no overlay; no active_path mutation.
- M. Stale source behavior — analyze, then ERASE the source entity
  in another SU window, then click the Issue. Confirm in-dialog
  toast + one console line; no exception popup.
- N. Before/after model fingerprint — run Model Info → Statistics
  pre and post; confirm `Edges`, `Faces`, `Groups`, `Components`,
  `Layers`, `Materials`, `Styles`, `Tags` all unchanged. Confirm
  no new entity in the model.

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

## 15. Summary for Codex (revised)

Stage 6 is split into **2 gates** (down from 4 rounds per Codex NIT):
- **Gate A** — Core contract: `IssueRegistry`, `IssueIdAssigner`,
  `IssueEnricher`, `IssueNormalizer`, `IssueGrouper`, `AnalysisResult`
  + 6 test files. Codex Round 011.
- **Gate B** — HtmlDialog integration: `core/issue_locator.rb`,
  `extension/loader.rb`, `extension/analyzers_runner.rb`,
  `extension/dialog_runner.rb`, `extension/dialog_controller.rb`,
  `extension/ui_bridge.rb`, `extension/html/{index.html, style.css,
  app.js}`, `Review/OWNER_VERIFICATION_STAGE_6.txt`, plus
  `tests/_fake_ui.rb`, `tests/_fake_instance_path.rb`, lint
  extensions, and ~6 test files. Codex Round 012.

The 4 BLOCKs are addressed:
- **BLOCK-001**: §3 defines the unified `UIIssue` Hash contract,
  `AnalysisResult` immutable wrapper, `IssueRegistry` tolerant
  validation, explicit preflight-warning → Issue conversion, edge-id
  enrichment from `snapshot.edges_by_id`, and canonical-key
  deterministic IDs.
- **BLOCK-002**: §5 builds the snapshot exactly once
  (`PreflightRunner.build_snapshot`); `analyzers_runner.rb` returns
  the immutable `AnalysisResult`; `extension/loader.rb` registers the
  menu command idempotently.
- **BLOCK-003**: §6.3 defines the root/leaf/multi-source locator
  policy: dedupe, `selection.clear` + `add(entities)`, `view.zoom`,
  no `InstancePath` ever reaches `Selection#add`/`View#zoom`, no
  `active_path` mutation, in-dialog toast + console line on resolve
  failure.
- **BLOCK-004**: §6.4 uses `set_file(absolute_path)`, registers
  callbacks as blocks before `show` (real API), defines a ready
  handshake (`window.sketchup.ready()` → push data via
  `JSON.generate` + `execute_script`), per-dialog controller with
  release on `set_on_closed`, FakeUI kept in `tests/`, no fake
  hooks in production `SUCapability`.

6 NITs addressed: AST-aware lint (§6.1); 2 gates (§8); remove false
"menu exists" claim (§3.6 + §4.2); CURRENT_STATE timing (§13).

Awaiting Codex verdict on Gate A start authorization.
