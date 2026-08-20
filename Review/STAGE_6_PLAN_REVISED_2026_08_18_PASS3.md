# Stage 6 — UI Implementation Plan (revised v3, after Codex Review 012)

| Field | Value |
|---|---|
| Date | 2026-08-18 (revised v3 after Codex Review 012) |
| Previous packet | `Review/STAGE_6_PLAN_REVISED_2026_08_18_PASS2.md` (SUPERSEDED) |
| Project | D:\Projects\SU-AI-Plugin |
| Stage | 6 (UI — `UI::HtmlDialog` + Issue registry presentation) |
| Locked decisions | R001 / R002 / R003 / R004 / R005 |
| Source-of-truth contracts | PI_TASK_001 §11 / §12 / §13 / §14 / §17 / §18 / §91 |
| Author | Agent (revised v3 after Codex Review 012) |
| Status | **REVISED v3 — addresses S6-PLAN-BLOCK-001 v3 + S6-VERIFY-BLOCK-001** |
| Codex Review 010 | BLOCKED (BLOCK-001..004) |
| Codex Review 011 | BLOCKED (BLOCK-001 + -003 narrow; -002/-004 CLOSED) |
| Codex Review 012 | BLOCKED (BLOCK-001 v3 + VERIFY-001; -002/-003/-004 CLOSED) |


## 0. Why this is a revision

Codex Review 012 returned **VERDICT: BLOCKED**:

**CLOSED**: S6-PLAN-BLOCK-002 (one-snapshot + menu), S6-PLAN-BLOCK-003
(pure-core/host boundary), S6-PLAN-BLOCK-004 (HtmlDialog lifecycle).

**STILL OPEN narrowly**:
- **S6-PLAN-BLOCK-001 v3**: the SourceToken's `nested` flag is derived
  from `pid_path.size > 1`, but this is wrong because the existing
  traversal skips nil PIDs while building the path; a nested source
  whose container PID is unavailable can have a partial path like
  `[leaf_pid]` (mis-classified as root-leaf) or `[]` (mis-classified
  as empty-root). Structural identity must be carried independently
  of PID availability, defined at snapshot construction.

**NEW**: **S6-VERIFY-BLOCK-001**: the Owner Verification Stage 6
checklist has several procedural bugs that would make it
unreliable as release evidence (fixture offsets, expected counts,
nil-handling, fingerprint scope, and unsupported menu introspection).

The 6 NITs are also addressed: Ruby-side keys (Symbol vs String)
single-boundary contract, AnalysisResult.freeze semantics,
fixture description (outer_g has 2 edges, not 1), lint claim
scope, toast JSON-encoding consistency.

No code has been written yet. The plan is still the only artifact
under review. Codex Review 012 directive: "After both blocks close:
PASS TO IMPLEMENT Gate A. Do not implement Gate A before that recheck."


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
| NEW (BLOCK-001 v2) | Aligned `sources` array of `SourceToken` Hashes; `source_entity_ids` is derived/serialized only | §3.1 |
| NEW (BLOCK-001 v3) | Structural identity (`nested`, `pid_path_complete`) carried on SourceReference at snapshot construction; locator policy tests cover all 5 cases | §3.2, §6.3, §7 |
| NEW (BLOCK-001 v3) | `SUCapability.find_entity_by_id` is a safe capability wrapper (added in §4.2); fails closed on missing capability | §6.3 |
| NEW (BLOCK-003) | `issue_locator.rb` and `display_unit_formatter.rb` live in `extension/`, not `core/`. Core stays pure Ruby. | §4.1 |
| NEW (NIT) | UIIssue/SourceToken Ruby-side keys are Symbols internally; converted to JSON Strings at the UIBridge boundary only | §3.1, §3.2 |
| NEW (NIT) | `AnalysisResult` is "no public setters + frozen top-level"; nested fields record a "no public mutators" contract | §3.3 |
| NEW (NIT) | `test_no_overlay_lint` proves absence of a finite forbidden-token set; it does NOT prove absence of mutation. Real-host fingerprint is the ground truth. | §6.1, §11 |


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


## 3. The unified Issue / AnalysisResult contract (S6-PLAN-BLOCK-001 v3)

### 3.1 `UIIssue` Hash (canonical contract — JSON-safe to UI)

By **NIT** discipline: Ruby-side keys are **Symbols** internally
inside `core/`; the conversion to **JSON String** keys happens at
exactly **one** boundary — `extension/ui_bridge.rb#as_html_data`.
Downstream of the UI bridge, only Strings exist. The original Symbol
hash is preserved in the registry for in-process consumers.

| Key (Symbol internal) | Type | Required | JSON-safe (String) | Notes |
|---|---|---|---|---|
| `issue_id` | String | yes | yes | Deterministic; see §3.6 |
| `issue_type` | String | yes | yes | Canonical names from §3.5 |
| `severity` | String | yes | yes | One of `"low"` / `"medium"` / `"high"` (String end-to-end) |
| `confidence` | String | yes | yes | One of `"low"` / `"medium"` / `"high"` |
| `sources` | Array<SourceToken> | yes | yes | One aligned array; see §3.2 |
| `source_entity_ids` | Array<Integer> | yes | yes | Derived serialized projection of `sources[*].entity_id` |
| `edge_ids` | Array<Integer> | yes | yes | Stable across the registry; may be empty |
| `location` | Array<Float,3> or nil | yes | yes | World-space midpoint or nil when no spatial anchor |
| `message` | String | yes | yes | Human-readable; UTF-8 preserved; control chars stripped |
| `metadata` | Hash<String,JSON-safe> | yes | yes | Free-form; must be JSON-safe |
| `locatable` | Boolean | yes | yes | true iff at least one SourceToken is locatable (see §3.7) |
| `display_length` | String or nil | yes | yes | Pre-formatted via `Sketchup.format_length`; only set for length-bearing issues |

### 3.2 `SourceToken` Hash (aligned source of truth — Symbols internally)

The two-array design (parallel `source_paths` + `source_entity_ids`)
broke alignment when one array was deduplicated or another path was
dropped. The source of truth is a single array of aligned Hashes:

```ruby
# SourceToken — one per resolved EdgeRecord; never split.
# Constructed only by core/issue_enricher.rb.
# Internal Symbol keys; JSON-stringified at extension/ui_bridge.rb.
{
  persistent_id_path: Array<Integer>,    # canonical SU persistent_id_path
  entity_id:          Integer or nil,    # transient entityID (in-session only)
  nested:             Boolean,           # structural nesting (NOT pid_path.size)
  pid_path_complete:  Boolean            # true iff every container PID was captured
}
```

Difference from v2 — the KEY new fields are `nested` and
`pid_path_complete`:

- `nested` is **structural**: true iff the source Edge is reachable
  only via one or more Group / ComponentInstance containers. It is
  derived from the actual traversal ancestry at snapshot time, NOT
  from `pid_path.size`.
- `pid_path_complete` is true iff every container along the
  ancestry yielded a non-nil `persistent_id`. False means at least
  one container's PID was missing (the path may be shorter than
  the structural depth).

Together they drive the locator policy:

| profile | nested | pid_path_complete | pid_path | entity_id | target |
|---|---|---|---|---|---|
| complete-root | false | true | `[leaf_pid]` | any | `InstPath#leaf` |
| complete-nested | true | true | `[c, ..., leaf_pid]` | any | `InstPath#root` |
| incomplete-root | false | false | `[]` | non-nil | `model.find_entity_by_id(entity_id)` |
| incomplete-nested | true | false | `[]` or partial | any | **non-locatable** |
| incomplete-nested-partial | true | false | `[leaf_pid]` only | any | **non-locatable** |
| fully-missing | n/a | n/a | `[]` | nil | non-locatable; analyzer would not have produced |

The new addition is **incomplete-nested-partial**: a nested source
that has only the leaf PID (every container PID was unavailable)
must NOT be downgraded to `complete-root`. This is the v2 bug that
v3 fixes.

`entity_id` is NEVER used for `issue_id` derivation. It is
session-transient and may collide across reloads.

### 3.3 `AnalysisResult` (one immutable return value)

By **NIT** discipline: `AnalysisResult.freeze` is shallow. The
contract is **"no public setters + frozen top-level"**. Nested
fields (registry, snapshot_lookup, display_data, diagnostics) are
themselves immutable by design (IssueRegistry contract +
Hash#freeze in `display_data`). A test in `test_analysis_result.rb`
asserts:
- No `attr_writer` exists on `AnalysisResult`.
- Top-level `result.frozen?` is true.
- `result.registry.find('nonexistent')` returns nil and does not
  mutate the registry.
- `result.diagnostics << { foo: 1 }` raises `RuntimeError`
  (frozen Array).

| Field | Type | Source |
|---|---|---|
| `preflight` | `PreflightReport` | `PreflightAnalyzer.run(snapshot)` |
| `registry` | `IssueRegistry` (see §3.4) | normalized from analyzer + preflight output |
| `snapshot_lookup` | `Hash{Integer => EdgeRecord}` | built explicitly in `analyzers_runner.rb` (see §5) |
| `display_data` | `Hash{String => String}` | `extension/display_unit_formatter.rb` (per issue_id) |
| `diagnostics` | `Array<Hash>` | per-stage errors, skipped entities, malformed-issue drops |
| `selection_type` | String | from preflight |
| `selection_label` | String | container name when present; "selection" otherwise |

### 3.4 `IssueRegistry` (pure-Ruby)

| Property | Value |
|---|---|
| Holds | `Array<Hash>` of UIIssue (Symbol keys) |
| Internal validation | a private `IssueRegistry.validate_issue` raises `IssueRegistry::InvalidIssue` on a missing key, a non-canonical severity String, an un-`to_s`-able field, or a non-`Array sources`. |
| Public constructor | `IssueRegistry.new(issues, diagnostics:)` **catches** any `InvalidIssue`, drops the offending Issue, records a diagnostic, and continues. The constructor itself never raises on a single malformed Issue. |
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
issue_type, raw analysis-side severities which may be Symbols → String
`low/medium/high`) lives at **one boundary** in
`core/issue_normalizer.rb`. UIIssue severity is **String end-to-end**;
Symbols may exist only inside `IssueNormalizer` before normalization.

### 3.6 Deterministic `issue_id` (R005)

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

### 3.7 `locatable` derivation (BLOCK-001 v3)

In `core/issue_enricher.rb`:

```
locatable = sources.any? { |t|
  (t[:nested] == false && t[:pid_path_complete] == true) ||
  (t[:nested] == true  && t[:pid_path_complete] == true) ||
  (t[:nested] == false && t[:pid_path_complete] == false &&
   !t[:entity_id].nil?)
}
```

Equivalently: locatable iff at least one token is `complete-root`,
`complete-nested`, or `incomplete-root` (the entityID fallback
profile). All other profiles are non-locatable.

### 3.8 Display-unit formatting (BLOCK-003)

Core stays unit-agnostic. The Issue Registry keeps raw inch Float
values in `location` and `metadata`. The formatter lives in
`extension/display_unit_formatter.rb`, not in `core/`. It is the
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

### 3.9 Preflight-warning → Issue conversion

Each Preflight warning Hash (kind: `:significant_non_zero_z`,
`:abnormal_large_coord`, `:deep_nesting`) is converted to a UIIssue
with:

- `sources: []`, `source_entity_ids: []`, `edge_ids: []`
- `location: nil`
- `locatable: false`
- `message`: preflight warning's `:message` — UTF-8 preserved;
  control characters (U+0000..U+001F except newline/tab) are
  stripped/replaced.
- `metadata`: `{"code": "<preflight_code>"}`
- `display_length`: nil

### 3.10 Structural identity capture at snapshot construction (BLOCK-001 v3)

The traversal in `extension/preflight_runner.rb` is enhanced to
carry structural facts alongside PID paths. Per Codex Review 012
BLOCK-001 v3, the snapshot-side `SourceReference` gains two
explicit fields:

- `structural_depth`: Integer ≥ 0. The root container is level 1;
  every nested container adds 1. Root-level entity has depth 0.
  Active edit context contributes its depth too.
- `pid_path_complete`: Boolean. True iff every container along the
  ancestry yielded a non-nil `persistent_id`.

The `SourceReference` constructor accepts these. The `walk_entity_world`
code in `extension/preflight_runner.rb` already tracks the existing
`parent_label_path` and `parent_pid_path`; the new fields are
populated in the same loop:

```ruby
# pseudo-code added to walk_entity_world
struct_depth = parent_struct_depth + (container?(entity) ? 1 : 0)
cont_pid = SUAnalysis::Compatibility::SUCapability.safe_persistent_id(entity)
new_pid_path_complete = parent_pid_path_complete && !cont_pid.nil?
# `entity` itself is the leaf when container?(entity) is false:
# depth = parent_struct_depth (parent is the leaf-depth container)
all_complete = yield_pid_complete && new_pid_path_complete
```

The active edit context contributes its own depth and incomplete
path fact. When `model.active_path` is non-empty, its traversal
is recursive: each entity in the active path adds 1 to depth and
toggles `pid_path_complete`.

`EdgeRecord` carries the inherited SourceReference verbatim. The
snapshot lookup is unchanged.

### 3.11 Issue enrichment from `edge_ids`

`core/issue_enricher.rb` takes the snapshot's EdgeRecord index
and the raw analyzer Issues, and produces Issues with full
`SourceToken` arrays.

Algorithm per Issue:

```
1. For each edge_id in Issue.edge_ids:
     rec = snapshot_lookup[edge_id]
     if rec is nil:
       skip and record "(missing edge_id #{edge_id})" in metadata
     else:
       src = rec.source
       sources << {
         persistent_id_path: src.persistent_id_path.dup,
         entity_id:          src.entity_id,
         nested:             src.structural_depth > 0,
         pid_path_complete:  src.pid_path_complete
       }
2. dedup WHOLE SourceTokens (NOT individual fields):
     sources = uniq_by(sources) { |t|
       [t[:persistent_id_path], t[:entity_id], t[:nested],
        t[:pid_path_complete]]
     }
3. Compute locatable per §3.7 rule.
4. Derive source_entity_ids = sources.map { |t| t[:entity_id] }.
```

### 3.12 Multi-source Issues (duplicate / gap)

Duplicate and gap Issues have **two source Edges**. Both
`SourceToken`s are kept. The locator (§6.3) handles multi-source.

Helper: `gap_candidate` Issue's `edge_ids` is `[edge_id_1, edge_id_2]`.
Both tokens are emitted. The duplicate Issue's `edge_ids` likewise
has two entries.

### 3.13 Gap-candidate empty-source fix

`GapCandidateDetector` currently emits `source_entity_ids: []`.
After enrichment (§3.11), the gap's `sources` will be populated
from the two endpoint edges. The enricher is the canonical fix;
the analyzer is **not** patched in this stage (Stage 2 BLOCK rework
is closed, scope discipline).


## 4. File inventory (revised for BLOCK-001 v3 + VERIFY-001)

### 4.1 New files

| Path | Gate | LoC est. | Purpose |
|---|---|---|---|
| `core/issue_registry.rb` | A | ~150 | Pure-Ruby IssueRegistry per §3.4; tolerant drop on malformed |
| `core/issue_id_assigner.rb` | A | ~80 | Deterministic IDs per §3.6; never uses `object_id` or `entity_id` |
| `core/issue_enricher.rb` | A | ~100 | Aligned SourceToken array per §3.11; structural identity preserved |
| `core/issue_normalizer.rb` | A | ~120 | One-boundary normalization: `kind` → `issue_type`, Symbol → String severity, R005 per-type mapping, preflight warning → Issue |
| `core/issue_grouper.rb` | A | ~80 | Pure-Ruby grouping by `issue_type` per §6.6 |
| `core/analysis_result.rb` | A | ~80 | Immutable wrapper per §3.3; one per `Analyze selection` |
| `core/issue_locator_policy.rb` | A | ~100 | Pure-Ruby locator policy: 5 profile → target descriptor. NO SketchUp imports. |
| `extension/issue_locator.rb` | B | ~140 | Implements the policy using `model`, `SUCapability`, `InstancePath`, `entityID fallback`. Concrete ownership of `find_entity_by_id`. |
| `extension/display_unit_formatter.rb` | B | ~60 | The ONLY place that calls `Sketchup.format_length`. Returns plain String display values. |
| `extension/loader.rb` | B | ~120 | Plugin load: `UI.menu` / `UI::Command` registration, idempotent, "Analyze selection" command |
| `extension/analyzers_runner.rb` | B | ~120 | One-pass: snapshot → preflight → analyzers → normalize → enrich → registry → AnalysisResult. Builds the snapshot_lookup index explicitly. |
| `extension/dialog_runner.rb` | B | ~150 | HtmlDialog lifecycle, callbacks as blocks, ready handshake, FakeUI factory injection |
| `extension/dialog_controller.rb` | B | ~120 | Per-dialog state (registry, registry-version, model lookup, snapshot_lookup, diagnostics) |
| `extension/ui_bridge.rb` | B | ~100 | Pure-Ruby Symbol → JSON String conversion at the boundary; emits JS-safe Hash only |
| `extension/html/index.html` | B | ~200 | Single-page summary + grouped `<details>` sections; loads via `set_file` absolute path |
| `extension/html/style.css` | B | ~140 | Severity palette: low=neutral, medium=orange, high=red |
| `extension/html/app.js` | B | ~250 | Renders JS Hash; click → `window.sketchup.locate_issue(issue_id)`; calls `window.sketchup.ready()` on `DOMContentLoaded` |
| `tests/test_issue_registry.rb` | A | ~150 | Pure-Ruby: validation, tolerant drop, determinism, grouping, summary, empty-registry |
| `tests/test_issue_id_assigner.rb` | A | ~80 | Pure-Ruby: stability, fallback, no `object_id` / no `entity_id` in IDs |
| `tests/test_issue_enricher.rb` | A | ~100 | Pure-Ruby: aligned tokens, missing-edge diagnostic, whole-token dedup, structural identity preserved |
| `tests/test_issue_normalizer.rb` | A | ~100 | Pure-Ruby: per-type mapping, preflight warning → Issue, severity String end-to-end |
| `tests/test_issue_grouper.rb` | A | ~80 | Pure-Ruby: grouping, count, default_open per Q1 |
| `tests/test_analysis_result.rb` | A | ~100 | Pure-Ruby: no public setters, frozen top-level, frozen-diagnostics assertion |
| `tests/test_issue_locator_policy.rb` | A | ~120 | Pure-Ruby: 5 profile targets, no host deps |
| `tests/test_core_no_host_dependency.rb` | A | ~80 | Lint: scans new core files for forbidden tokens (`Sketchup`, `UI`, `Geom`, `compatibility/`, `extension/`). Single FAIL = any hit. |
| `tests/test_issue_locator.rb` | B | ~120 | Adapter: 5 profile cases, FakeInstancePath, root-leaf, nested root, empty-root, empty-nested, nested-partial, two-source, erased |
| `tests/test_analyzers_runner.rb` | B | ~120 | Adapter: one snapshot per command, registry built from snapshot, explicit snapshot_lookup index |
| `tests/test_loader.rb` | B | ~80 | Adapter: FakeUI Command registry; idempotent registration across reloads |
| `tests/test_dialog_runner.rb` | B | ~120 | Adapter: set_file path, ready handshake, callback rebind on reopen, JSON.execute_script, no `eval`/`innerHTML`/`document.write` |
| `tests/test_ui_bridge.rb` | B | ~80 | Pure-Ruby: Symbol → JSON String conversion, no SU types, escaping for JSON |
| `tests/test_display_unit_formatter.rb` | B | ~60 | Adapter: `Sketchup.format_length` integration + non-SU fallback |
| `tests/test_html_render.rb` | B | ~120 | Pure-Ruby: token scan of JS source for `eval`, `new Function`, `document.write`, `innerHTML` for user-supplied strings; static lint of HTML/CSS |
| `tests/test_no_overlay_lint.rb` | B | ~80 | `Ripper.lex`-based scanner of `extension/*.rb` for forbidden tokens. Per NIT: this proves absence of a finite token set; real-host fingerprint is the ground truth for no mutation. |
| `tests/test_ruby_22_syntax_sweep.rb` | B | 1 | Extended sweep: 22 + new files; 0 syntax issues |
| `tests/_fake_ui.rb` | B | ~150 | Fake `UI::HtmlDialog` + `UI::Command` + `UI::Menu` for adapter tests — `tests/` only |
| `tests/_fake_instance_path.rb` | B | ~80 | Fake `Sketchup::InstancePath` (root/leaf/to_a/empty) for locator tests |
| `Review/OWNER_VERIFICATION_STAGE_6.txt` | B | n/a | Owner Verification Stage 6 checklist (5 steps J..N) per Codex Q3 AND revised per VERIFY-001 |

### 4.2 Modified files

| Path | Modify |
|---|---|
| `core/source_reference.rb` | Add `structural_depth` and `pid_path_complete` Sym-key fields (default 0 / true); include in `to_h`. **Per BLOCK-001 v3**: the structural facts are captured at construction time. |
| `extension/preflight_runner.rb` | Walk loop tracks `parent_struct_depth` and `parent_pid_path_complete`; passes them to `build_source_reference`; yields the structural slice to the `EdgeRecord` builder. **No change to the existing traversal semantics** — only adds two parallel fields. |
| `compatibility/su_capability.rb` | Add safe `find_entity_by_id(model, entity_id)` wrapper: returns nil for nil input, returns nil if model lacks `find_entity_by_id`, returns nil on any error, otherwise returns the Entity. Fails closed. Also add `structural_depth_facts(parent_struct_depth, parent_complete)` helper that the walker can call. |
| `tests/_fake_su.rb` | Add `FakeUI` namespace (delegate to `tests/_fake_ui.rb`); add `FakeInstancePath` (delegate to `tests/_fake_instance_path.rb`). |
| `extension/preflight_runner.rb` (other) | **No behavioral change** to the existing preflight logic. |
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
- No call to a nonexistent `SUCapability.find_entity_by_id` —
  added explicitly in `SUCapability` (per BLOCK-001 v3).

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
                  │   (existing; no fake hooks; +find_entity_by_id)│
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
                  │   … edge_record.rb, source_reference.rb      │
                  │     (+structural_depth, +pid_path_complete),  │
                  │     preflight.rb, geometry_snapshot.rb, etc.  │
                  └──────────────────────────────────────────────┘
```

The lint `tests/test_core_no_host_dependency.rb` enforces the
lower boundary: any new `core/*.rb` file with a `Sketchup` / `UI` /
`Geom` / `compatibility` / `extension` reference is a hard FAIL.

## 5. Runtime flow (revised — one snapshot, one explicit index)

Same as v2; the snapshot_lookup is built explicitly in
`analyzers_runner.rb`. No change.

## 6. Critical implementation rules

### 6.1 NO overlay / NO mutation enforcement (R003 hard prohibition)

Same as v2. **Per NIT, the lint proves absence of a finite
forbidden-token set only; real-host fingerprint is the ground
truth for no model mutation.** Owner verification step N is the
authoritative assertion.

### 6.2 Capability fallback (R002 / R003 Q3.2)

Same as v2.

### 6.3 Locate policy (S6-PLAN-BLOCK-001 v3 + BLOCK-003)

Two-layer design:

**Layer A**: `core/issue_locator_policy.rb` — pure-Ruby target
selection. Given an array of `SourceToken`s, return a `PolicyResult`
(Array of target descriptors).

Profile→Target mapping (the FIVE cases plus the partial case):

| profile | nested | pid_path_complete | pid_path | entity_id | target descriptor |
|---|---|---|---|---|---|
| complete-root | false | true | `[leaf_pid]` | any | `{kind: :inst_path_leaf, pid_path: token.pid_path}` |
| complete-nested | true | true | `[c, ..., leaf_pid]` | any | `{kind: :inst_path_root, pid_path: token.pid_path}` |
| incomplete-root | false | false | `[]` | non-nil | `{kind: :entity_id, entity_id: token.entity_id}` |
| incomplete-nested | true | false | `[]` | any | `skip — non-locatable` |
| incomplete-nested-partial | true | false | `[leaf_pid]` only | any | `skip — non-locatable` |
| fully-missing | n/a | n/a | `[]` | nil | `skip — non-locatable` |

The `entity_id` fallback path is restricted to `nested == false`
AND `pid_path_complete == false` AND `entity_id != nil`. For any
nested source, regardless of pid_path shape, the source is
non-locatable (entityID alone cannot pick the correct shared
component occurrence; partial `[leaf_pid]` can resolve to the
wrong definition edge).

**Layer B**: `extension/issue_locator.rb` — host glue. Takes the
`PolicyResult` and walks `model.instance_path_from_pid_path` for
each token, applies the entityID fallback via the new
`SUCapability.find_entity_by_id` (see §4.2), dedupes whole
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
     when :inst_path_leaf
       inst_path = SUCapability.resolve_pid_path(model, token.persistent_id_path)
       if inst_path.nil? → record source_no_longer_available
       else → targets << inst_path.leaf
     when :inst_path_root
       inst_path = SUCapability.resolve_pid_path(model, token.persistent_id_path)
       if inst_path.nil? → record source_no_longer_available
       else → targets << inst_path.root
     when :entity_id
       entity = SUCapability.find_entity_by_id(model, token.entity_id)
       if entity.nil? → record source_no_longer_available
       else → targets << entity
     when :skip
       next
     end
4. dedup(targets)            # Object#hash stable within session
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

**Five required test cases** (per §7):

1. `complete-root [leaf_pid]` → `target == inst_path.leaf`
2. `complete-nested [container, leaf]` → `target == inst_path.root`
3. `incomplete-root [] + entity_id` → `target == model.find_entity_by_id(entity_id)`
4. `incomplete-nested []` → unresolved, no entityID fallback
5. `incomplete-nested-partial [leaf]` → unresolved, no entityID fallback

Cases 4 and 5 must never use entityID fallback and must never be
treated as root.

**Hard rules**:
- `model.active_path` is NEVER mutated.
- `Selection#add` is preceded by `Selection#clear`.
- `View#zoom` is called only when targets is non-empty.
- `Sketchup::InstancePath` is NEVER passed to `Selection#add` or
  `View#zoom` (the test asserts this with `assert_raises`).
- `entity_id` is NEVER used for `issue_id` derivation; it is only
  a transient fallback for `nested == false` +
  `pid_path_complete == false` empty PID paths.

### 6.4 HtmlDialog lifecycle (Codex BLOCK-004, closed)

Same as v2.

### 6.5 Issue ID determinism (R005)

Already covered in §3.6. `entity_id` is NEVER used.

### 6.6 Group ordering (R005 + Codex Q1 answer)

Same as v2.

### 6.7 Summary header

Same as v2.

### 6.8 Ruby 2.2.4 syntax discipline

Same as v2.

### 6.9 JS contract discipline

By **NIT** discipline: the toast interpolation must pass a JSON
String argument consistently. The unresolved-path pseudocode
sends `JSON.generate([...])` (a JSON Array). The `unresolved-path`
toast invocation must always pass a JSON String. Revised:

```ruby
# dialog.execute_script passes a JSON String (the array contents
# are pre-converted to a single user-facing message string).
msg = "source no longer available for: #{issue_id}"
dialog.execute_script("window.SUAIP.toast(#{JSON.generate(msg)})")
```

### 6.10 Error handling (PI_TASK_001 §18)

Same as v2.

## 7. Test matrix (target ~140 new tests, ~210 total)

Per Codex NIT: the test count is a soft target, not a hard
requirement. We aim for the **smallest risk-based suite** that
proves the contracts; we do not write tests to hit a round number.

| Suite | Tests | What's covered |
|---|---|---|
| `test_issue_registry` | ~12 | validation, tolerant drop, determinism, grouping, summary, empty-registry |
| `test_issue_id_assigner` | ~6 | stability, fallback, no `object_id` / no `entity_id` |
| `test_issue_enricher` | ~10 | aligned tokens, missing-edge diagnostic, whole-token dedup, structural identity preserved across traversal variations |
| `test_issue_normalizer` | ~12 | per-type mapping, preflight warning → Issue, severity String end-to-end |
| `test_issue_grouper` | ~6 | group order, count, default_open per Q1 |
| `test_analysis_result` | ~6 | no public setters, frozen top-level, frozen-diagnostics assertion |
| `test_issue_locator_policy` | ~10 | profile targets, no host deps |
| `test_core_no_host_dependency` | ~6 | no `Sketchup` / `UI` / `Geom` / `compatibility` / `extension` tokens in new core files |
| `test_issue_locator` | **5 mandated by BLOCK-001 v3** | (1) complete root, (2) complete nested, (3) incomplete-root + entityID, (4) incomplete-nested, (5) incomplete-nested-partial; plus two-source, erased |
| `test_analyzers_runner` | ~8 | one snapshot per command, explicit snapshot_lookup, registry build |
| `test_loader` | ~6 | idempotent registration across reloads, empty/unsupported selection handling |
| `test_dialog_runner` | ~10 | set_file absolute path, ready handshake, callback rebind on reopen, JSON.execute_script, no model mutation |
| `test_ui_bridge` | ~6 | Symbol → JSON String conversion at boundary, no SU types, escaping for JSON |
| `test_display_unit_formatter` | ~4 | `Sketchup.format_length` integration + non-SU fallback |
| `test_html_render` | ~8 | no `eval`, no `innerHTML` for user-supplied strings, JS source parses |
| `test_no_overlay_lint` | ~5 | `Ripper.lex` scan, comment/string stripping, zero forbidden tokens |
| `test_ruby_22_syntax_sweep` | 1 | 30+ files, 0 syntax issues |

The 5 mandated locator policy tests are listed in §6.3 explicitly.

## 8. Sub-stage breakdown + Codex review round plan (consolidated)

| Gate | Sub-steps | Codex review round | Verdict target |
|---|---|---|---|
| **Gate A — Core contract** | `core/issue_registry.rb`, `core/issue_id_assigner.rb`, `core/issue_enricher.rb`, `core/issue_normalizer.rb`, `core/issue_grouper.rb`, `core/analysis_result.rb`, `core/issue_locator_policy.rb` + 7 test files + `test_core_no_host_dependency` + modifications to `core/source_reference.rb` | Round 013 | All BLOCK-001 v3 sub-issues CLOSED |
| **Gate B — Host-side integration** | `extension/issue_locator.rb`, `extension/display_unit_formatter.rb`, `extension/loader.rb`, `extension/analyzers_runner.rb`, `extension/dialog_runner.rb`, `extension/dialog_controller.rb`, `extension/ui_bridge.rb`, `extension/html/*`, `tests/_fake_ui.rb`, `tests/_fake_instance_path.rb`, `Review/OWNER_VERIFICATION_STAGE_6.txt` (revised) + 6 test files + lint extensions + modifications to `extension/preflight_runner.rb` (structural-depth tracking) + `compatibility/su_capability.rb` (find_entity_by_id wrapper) | Round 014 | All BLOCK-002 / 003 / 004 + VERIFY-001 sub-issues CLOSED |

After Gate B passes, Owner Verification Stage 6 runs on
SketchUp 2020 (per Q002=A), then SU2017 (per R004, release Gate).

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
| Empty-root entityID fallback picks wrong occurrence | Low | High | Restricted to `nested == false` + `pid_path_complete == false` + `entity_id != nil` only. Nested empty-path → non-locatable. `test_issue_locator` covers all 5 cases. |
| Nested source with `[leaf_pid]` only mis-treated as root-leaf | Low | High | `pid_path_complete` carries the truth; `nested` carries structural depth. `test_issue_locator` cases 4 and 5 cover this. |

## 10. Open questions answered by Codex (Q1-Q6)

| # | Codex answer | Implementer consequence |
|---|---|---|
| Q1 | Default-open: every group with `:high` Issue; if no `:high`, open first non-empty group | `IssueGrouper` carries the policy; one test case per branch |
| Q2 | In-dialog non-blocking status + one console line; no modal messagebox; no exception to JS | `dialog.execute_script("window.SUAIP.toast(...)")` + `$stdout.puts` |
| Q3 | New focused Stage 6 checklist (5 steps J..N); do NOT append to Stage 2 | `Review/OWNER_VERIFICATION_STAGE_6.txt` (revised) |
| Q4 | External local files via `set_file` absolute path; NO heredoc embedding | `set_file(File.expand_path('html/index.html', __dir__))` |
| Q5 | Internal: raw inch Float; Display: `Sketchup.format_length` strings | `extension/display_unit_formatter.rb` (only host-dependent formatter) |
| Q6 | New `Review/OWNER_VERIFICATION_STAGE_6.txt`; do not extend Stage 2 | Listed in §4.1 |

## 11. Owner Verification Stage 6 (per VERIFY-001)

The revised checklist is in `Review/OWNER_VERIFICATION_STAGE_6.txt`
(supersedes the v1 draft). Five steps J..N are corrected to:

- Use a **reliable duplicate fixture** (two distinct container
  occurrences whose edges are world-coincident, NOT a 0.001 offset).
- Expect **one Issue row with two SourceTokens** for a duplicate
  pair (not two rows).
- Expect **two open-endpoint issues** for one isolated edge (not
  one).
- Use a **nil-safe active-path helper** everywhere (root has
  `active_path == nil`).
- Make stale-source **mandatory**; keep the dialog open; capture
  the reference to the nested source Edge, erase in Ruby Console,
  click the stale row. Compare fingerprints immediately before
  and after the Locate click.
- **Remove unsupported UI::Menu introspection** from J.3. The
  script relies on `submenus / name / items` which is not part of
  the normal public menu workflow. Replace with a FakeUI adapter
  test proof + a real-host visual confirmation that only one
  command appears after reload.
- **Separate N (non-mutating end-to-end) from M (intentional
  erase)**. N captures the fingerprint BEFORE the M-style
  destructive fixture; M's fingerprint comparison is
  immediately-before-vs-after the Locate click, not before-and-after
  the deliberate erase.
- **Recursive geometry fingerprint** across reachable Groups /
  ComponentDefinitions (not just root `m.entities`). Otherwise
  nested mutations escape detection.

The existing fingerprint helper is updated accordingly.

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

## 15. Summary for Codex (revised v3)

Stage 6 is split into **2 gates**:

- **Gate A** — Core contract: `IssueRegistry`, `IssueIdAssigner`,
  `IssueEnricher`, `IssueNormalizer`, `IssueGrouper`, `AnalysisResult`,
  `IssueLocatorPolicy` (pure-Ruby) + 7 test files +
  `test_core_no_host_dependency` + modifications to
  `core/source_reference.rb` (add `structural_depth` and
  `pid_path_complete`). Codex Round 013.
- **Gate B** — Host-side integration: `extension/issue_locator.rb`,
  `extension/display_unit_formatter.rb`, `extension/loader.rb`,
  `extension/analyzers_runner.rb`, `extension/dialog_runner.rb`,
  `extension/dialog_controller.rb`, `extension/ui_bridge.rb`,
  `extension/html/{index.html, style.css, app.js}`,
  `Review/OWNER_VERIFICATION_STAGE_6.txt` (revised per VERIFY-001),
  plus `tests/_fake_ui.rb`, `tests/_fake_instance_path.rb`, lint
  extensions, and ~6 test files. Plus modifications to
  `extension/preflight_runner.rb` (structural-depth tracking) and
  `compatibility/su_capability.rb` (add `find_entity_by_id`).
  Codex Round 014.

The remaining opens are addressed:

- **S6-PLAN-BLOCK-001 v3**: §3.2 introduces `nested` and
  `pid_path_complete` carried on SourceReference at snapshot
  construction. The locator policy now distinguishes 5+1 profiles
  including `incomplete-nested-partial` (`[leaf_pid]` only —
  NON-locatable, never entityID fallback). §3.10 specifies that
  structural_depth and pid_path_complete are populated in the
  traversal walk loop. §4.2 adds `SUCapability.find_entity_by_id`
  as a safe capability wrapper (fails closed). §6.3 lists the 5
  mandated test cases (1-5) explicitly. Modifications to
  `core/source_reference.rb` and `extension/preflight_runner.rb`
  are listed in §4.2.
- **S6-VERIFY-BLOCK-001**: §11 points to the revised
  `Review/OWNER_VERIFICATION_STAGE_6.txt` with corrected fixtures
  (world-coincident duplicate, two open-endpoints per isolated
  edge, nil-safe active_path, mandatory open-dialog stale-source,
  no UI::Menu introspection, recursive geometry fingerprint across
  Groups/ComponentDefinitions, N vs M separation).

6 NITs addressed:
- UIIssue/SourceToken Ruby-side keys are Symbols internally;
  JSON-String conversion happens at `extension/ui_bridge.rb` only
  (§3.1, §3.2).
- `AnalysisResult` is "no public setters + frozen top-level" with
  explicit mutation test in §3.3.
- Fixture description corrected: outer_g in Owner Verification has
  2 edges, not 1.
- `test_no_overlay_lint` scope clarified: it proves absence of a
  finite forbidden-token set; real-host fingerprint is the ground
  truth for no mutation.
- Toast interpolation consistency: pass a JSON String argument,
  not a JSON Array (§6.9).

Awaiting Codex verdict on Gate A start authorization.
