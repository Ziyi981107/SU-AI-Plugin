# V1.1 — Layer Semantic Mapping (Plan)

| Field | Value |
|---|---|
| Date | 2026-08-19 |
| Project | D:\Projects\SU-AI-Plugin |
| Stage | V1.1 (Layer Semantic Mapping) — first V1.1 stage after V1.0 candidate freeze |
| Branch | `v1.1-layer-semantic-mapping` (cut from `v1.0-candidate-2026-08-19` at commit `56ea611`) |
| V1.0 baseline tag | `v1.0-candidate-2026-08-19` (Stage 6 PASS / Gate 2 PASS / CodeX 024 PASS / 286 tests PASS / Gate 1 SU2017 deferred to formal release per Cicada 2026-08-19) |
| Locked decisions (do NOT re-litigate) | R001..R005 from V1.0 + R006 (Gate 1 SU2017 deferred) + R007 (role/visibility separate) + R008 (no role colors) + R009 (display order) + R010 (top-down-by-priority) + R011 (fail-open + visibility_unknown flag) + R012 (role order independent from IssueRegistry) |
| Source-of-truth contracts | PI_TASK_001 §6 (preflight layer distribution), §11 (read-only), §14 (module boundary), §17 (no-fix), §18 (error handling) |
| Reviewer routing | **ChatGPT** (scope/UX/policy, §11) → **Agent self** (contained code architecture, §12, with documented defaults) → implement → **CodeX** end-of-stage review of full V1.1 diff (§13) — per Cicada 2026-08-19 routing rule |
| Author | Coding Agent (Mavis) |
| Status | **DRAFT — all 10 ChatGPT scope/policy questions answered (Q1..Q10); awaiting implementation** |


## 0. Purpose

V1.1 first stage. Adds **layer semantic role classification** on top of
the existing per-edge layer capture that V1.0 already does.

V1.0 already records each Edge's `layer` (the SU tag name string), and
the `PreflightReport#layer_distribution` field is reserved for per-layer
counts — but `build_snapshot` currently passes `layers: []` (empty), and
the dialog has no "Layers" section. V1.1 fills this in.

This is the smallest user-visible V1.1 increment: read-only analysis,
no new SU API beyond `Layer#visible?` (already gated through
`SUCapability`), no model mutation, no new feature scope beyond
"name + visibility pattern" classification, no settings UI.

**Out of V1.1 scope (explicit)**:
- Auto-renaming / re-tagging / re-layering
- Color / material based classification
- DB / settings persistence
- Multi-occurrence layer instances (layer is a SU-side singleton; we
  analyze the layer itself, not references to it)
- Layer-based auto-fix (e.g. "merge annotation layers")
- Layer-based issue severity mutation
- Cross-model layer mapping (e.g. import from template file)


## 1. Locked decisions (do NOT re-litigate)

| ID | Decision (V1.0) | Consequence for V1.1 |
|---|---|---|
| R001 | thresholds: `big_z=0.01`, `large_coordinate=1e6`, `deepest_nesting_warning=3` | V1.1 does not introduce new thresholds. Pattern matching is name-only + visibility, deterministic, not threshold-based. |
| R002 | HtmlDialog probe in `compatibility/su_capability.rb` | V1.1 extends `SUCapability` with `layer_visible?(entity)` (read-only `entity.layer.visible?` with capability-safe rescue). The same `html_dialog?` gate is reused for the new "Layers" UI section. |
| R003 | NO overlay, NO mutation, NO construction geometry | V1.1 inherits this. Layer role classification is read-only analysis, no `layers.add` / `tags.add` / `entities.add_*`. |
| R004 | SU2017+ baseline, Ruby 2.2.4 | V1.1 keeps the same baseline. No new Ruby 2.3+ syntax. |
| R005 | severity `:low / :medium / :high`, presentation via IssueRegistry groups | V1.1 adds layer grouping ALONGSIDE issue-type grouping. Layer is a new axis, not a replacement. Severity palette unchanged. |
| R006 (NEW) | Gate 1 SU2017 deferred to formal release (Cicada 2026-08-19) | V1.1 Gate 2 (real-SU2020) is sufficient for the V1.1 candidate. Gate 1 stays PENDING for the actual formal release, not per-stage. |
| R007 (NEW) | **Role and visibility are SEPARATE fields** (ChatGPT §11.3, 2026-08-19) | A hidden layer that matches `*dim*` shows `role="Dimension"` + `visibility="Off-screen"`, NOT a fused "Construction (off-screen)" role. 5 name-based roles only: `:construction / :dimension / :annotation / :guide / :unknown`. Visibility is a separate Boolean field on `LayerRecord` / `LayerSummary`. The `OFFSCREEN` role Symbol is REMOVED. |
| R008 (NEW) | **No role color hints in V1.1** (ChatGPT §11.7, 2026-08-19) | Roles use text + neutral badge. The V1.0 issue severity palette (R005) is NOT reused for roles — it stays scoped to issues. CSS adds a single `.layer-row` neutral style, NO `data-role="..."` color selectors in V1.1. |
| R009 (NEW) | **Layer display order = role order, hidden last within each role bucket** (ChatGPT §11.2, 2026-08-19) | Role buckets order: `:dimension, :annotation, :guide, :construction, :unknown`. Within a role bucket, hidden layers sort last and are visually muted (lower opacity / `aria-hidden` hint). |
| R010 (NEW) | **Rule ordering is top-down-by-priority, NOT by-specificity** (ChatGPT §11.8, 2026-08-19) | `LayerRoleConfig.classify` evaluates rules in DECLARED order; first match wins. Rationale: more predictable, more debuggable, no implicit "more specific = more important" behavior. Specificity MAY be a future tie-break or lint hint, but NOT the main sort rule. Test pin: a layer matching two rules gets the FIRST rule's role. |
| R011 (NEW) | **`layer_visible?` nil → `true` operationally, with separate `visibility_unknown` flag** (ChatGPT §11.9, 2026-08-19) | When host capability is missing, the operational fallback is `visible: true` so the layer is NOT silently demoted / sorted-last / dropped. Additionally, a separate `visibility_unknown: true` flag is set so the data model preserves the uncertainty. The UI surfaces this as a third badge "Visibility: unknown". The plan does NOT fake `false` ("confirmed hidden") when the answer is actually "I don't know". |
| R012 (NEW) | **Layer role order is INDEPENDENT from `IssueRegistry::DEFAULT_GROUP_ORDER`** (ChatGPT §11.10, 2026-08-19) | Locked role order: `[dimension, annotation, guide, construction, unknown]`. Unknown FIXED last. No future change to match `IssueRegistry` order — issue type and semantic role are two different information systems, each with its own sort rule. |


## 2. V1.1 user-visible behavior

### Does (V1.1)

1. **Per-layer summary in the dialog** (NEW section, positioned
   BELOW the existing per-issue-type groups per R007 / ChatGPT §11.1):
   - One row per layer that has at least one Edge in the current
     snapshot.
   - Row fields: `name`, `role` (5 name-based options), `edge_count`,
     `issue_count`, `visibility` ('Visible' or 'Off-screen' as a
     separate status badge).
   - Both `edge_count` and `issue_count` are shown (per
     ChatGPT §11.4). When `issue_count > 0`, the count is visually
     emphasized (bold weight or larger size — see §4.10).
   - Hidden layers sort LAST within their role bucket, with a
     muted visual treatment (reduced opacity or muted font; the
     visibility badge says "Off-screen" per R007 / ChatGPT §11.3).
   - Layer row click: no-op (mirrors V1.0 L3 non-locatable
     warning). Cursor `default`, no hover. Reason: the layer
     row is informational; the per-edge Locate stays the only
     interactive action.
2. **Layer role classification** (5 name-based roles only — per
   R007):
   - `:dimension` — name matches `*dim*` / `*dimension*`
     (case-insensitive, glob-like).
   - `:annotation` — name matches `*anno*` / `*text*` / `*label*`.
   - `:guide` — name matches `*guide*` / `*constr*` / `*xline*`.
   - `:construction` — name is `"Layer0"` / `"Default"` / `"Untagged"`
     (SketchUp defaults).
   - `:unknown` — no rule matched. Per ChatGPT §11.6, this role
     is RETAINED and surfaces as "Unknown / ?" — never silently
     mapped to `:construction`.
   - **Role and visibility are separate fields** (R007). A hidden
     layer still gets its name-based role; visibility is a
     separate Boolean. No fused `OFFSCREEN` role.
3. **"Layers" `<details>` default-closed with summary**
   (per ChatGPT §11.5):
   - The `<details>` element is closed by default.
   - When closed, the `<summary>` shows: `"Layers — N total (M
     with issues)"` so the user sees the headline numbers without
     expanding. N and M are computed across all layers in the
     snapshot.
   - When open, the full per-layer list is shown.
4. **Layer-aware issue grouping** (additive, does not change V1.0
   grouping):
   - Each existing issue already has `source.kind == 'edge'` and the
     edge has a `layer` name. We can attach the layer name to the
     issue as a derived field `issue[:layer_name]` without changing
     the issue model contract.
   - Dialog shows the `layer_name` next to each Issue row, after
     the existing `label` (e.g. "Edge: …  [Layer: DIM-01]"). The
     layer badge is text-only, no click, no Locate (it would just
     re-zoom to the same edge).
5. **No new SU API** beyond `Layer#visible?` (already in SU 2017+,
   capability-gated). All other inputs are layer names (already
   captured on each Edge in V1.0).
6. **No new "what to fix" controls** — V1.0 dialog has no
   fix/refresh/filter controls and V1.1 keeps that contract.
7. **No role color hints** (R008 / ChatGPT §11.7). Role badges
   use the V1.0 neutral badge style; only text distinguishes
   roles. The V1.0 issue severity palette is NOT reused.

### Does NOT (V1.1)

- Mutate the model. Ever. (Inherited from R003.)
- Add / remove / rename any layer / tag.
- Classify a layer as "fix this" (the role is informational, not
  prescriptive).
- Add filter / search / sort controls (R005).
- Persist the role classification across sessions (no DB, no
  settings file).
- Per-layer Locate / zoom (clicks on layer rows do nothing — the
  edge-level Locate is still the only interactive action).
- Layer color / material / line weight analysis (deferred to V1.1.x
  if requested later; would require a `Layer#material` and
  `Layer#color` capability probe, which is out of V1.1 scope).
- Per-occurrence layer overrides (e.g. SU allows per-face
  `material=` overrides; V1.1 ignores those, the role classification
  is on the layer, not on a specific face / edge).


## 3. Hard-line module boundary (inherited from R003 + R005)

```
                  ┌──────────────────────────────────────────────────┐
                  │   extension/  (the only place Sketchup::* is    │
                  │                allowed)                           │
                  │                                                  │
                  │   preflight_runner.rb   (V1.0)  ← layer capture │
                  │     .build_snapshot   populates layers: Array   │
                  │                                                  │
                  │   analyzers_runner.rb   (V1.0)                   │
                  │     .run              produces AnalysisResult    │
                  │     .summary          includes layer_distribution│
                  │                                                  │
                  │   ui_bridge.rb          (V1.0)                   │
                  │     .as_html_data      + layer_groups field      │
                  │                                                  │
                  │   dialog_runner.rb     (V1.0)                    │
                  │   dialog_controller.rb (V1.0)                    │
                  │   html/                                         │
                  │     index.html         (V1.0) + Layers section   │
                  │     app.js             (V1.0) + renderLayers     │
                  │     style.css          (V1.0) + .layer-row       │
                  │                                                  │
                  ├──────────────────────────────────────────────────┤
                  │   compatibility/su_capability.rb                 │
                  │     (V1.0) + layer_visible?(entity)              │
                  ├──────────────────────────────────────────────────┤
                  │   core/  (pure Ruby; NO `Sketchup::`)            │
                  │     PreflightReport, EdgeRecord …    (V1.0)      │
                  │     IssueRegistry / IssueGrouper     (V1.0)      │
                  │     IssueIdAssigner / Normalizer     (V1.0)      │
                  │     LayerRecord                      (V1.0)      │
                  │     LayerRole enum (NEW V1.1)                    │
                  │     LayerSemanticMapper (NEW V1.1, pure Ruby)    │
                  │     LayerIssueGrouper  (NEW V1.1, pure Ruby)     │
                  │     LayerRoleConfig   (NEW V1.1, frozen config)  │
                  └──────────────────────────────────────────────────┘
```

**Rules inherited from V1.0**:
1. `core/` MUST NOT `require` `Sketchup::*` or anything in `extension/`.
2. `compatibility/` only does `respond_to?` / `defined?` probes.
3. `extension/` is the only place that talks to `Sketchup::*`; it
   also is the only place that constructs a `UI::HtmlDialog`.
4. UI render is textContent-only for user strings (no innerHTML for
   layer names, role names, edge counts). No eval. No new Function.
5. UI never receives a callable that mutates the model. The only
   Ruby callback exposed to JS stays `locate_issue(issue_id)`.

**Rules new in V1.1**:
6. `LayerSemanticMapper` (pure Ruby) is the SINGLE place that turns
   a layer name String + a `visible?` Boolean into a `LayerRole`
   Symbol. Test cases pin every rule. (See §7.)
7. `LayerRoleConfig` is a frozen module-singleton whose
   `RULES`, `DEFAULT_ROLE`, and the canonical role-name list are
   constants, not method state. No dynamic reconfiguration in V1.1.
8. The dialog adds ONE new section ("Layers"). It MUST NOT change
   the existing "Issues" section structure, default-open policy,
   or per-issue click handler. V1.0 Stage 6 / CodeX 020 contracts
   are intact.


## 4. API surface (V1.1 additions only)

### 4.1 `core/layer_role.rb` (NEW)

```ruby
module SUAnalysis
  module Core
    module LayerRole
      # 5 name-based roles ONLY. Visibility is a separate field
      # (LayerRecord#visible, LayerSummary#visible) — NOT a role.
      # Per R007 / ChatGPT §11.3 (2026-08-19): role and visibility
      # are independent.
      CONSTRUCTION = :construction       # Layer0 / Default / Untagged
      DIMENSION    = :dimension          # *dim* / *dimension*
      ANNOTATION   = :annotation         # *anno* / *text* / *label*
      GUIDE        = :guide              # *guide* / *constr* / *xline*
      UNKNOWN      = :unknown            # no rule matched (KEEP, per ChatGPT §11.6)
      ALL = [DIMENSION, ANNOTATION, GUIDE, CONSTRUCTION, UNKNOWN].freeze
      # ALL is the table display order (R009 / ChatGPT §11.2):
      # most informative role first, default layer in the middle,
      # unknown last.
      HUMAN = {
        DIMENSION    => 'Dimension',
        ANNOTATION   => 'Annotation',
        GUIDE        => 'Guide',
        CONSTRUCTION => 'Construction',
        UNKNOWN      => 'Unknown'
      }.freeze
      # Visibility label table (R007). The dialog renders one of
      # these as a separate status badge next to the role badge.
      VISIBILITY_HUMAN = {
        true  => 'Visible',
        false => 'Off-screen'
      }.freeze
      # When host capability is missing, we keep the data-model
      # flag `visibility_unknown: true` AND surface a third label
      # (R011). The dialog renders this as its own badge so the
      # user sees the uncertainty, not a fake "Off-screen".
      VISIBILITY_UNKNOWN_HUMAN = 'Visibility: unknown'.freeze
      # Compose the final visibility label from (visible,
      # visibility_unknown). This is the source of truth for the
      # dialog badge text; the JS layer does not recompute it.
      def self.visibility_label(visible, unknown)
        return VISIBILITY_UNKNOWN_HUMAN if unknown
        VISIBILITY_HUMAN[visible ? true : false]
      end
    end
  end
end
```

### 4.2 `core/layer_role_config.rb` (NEW)

Frozen module-singleton. Exposes:
- `RULES` — `Array<{match: Regexp, role: LayerRole::Symbol,
  rule_id: String}>`. Order is DECLARED order (R010).
- `DEFAULT_ROLE` — `LayerRole::UNKNOWN`.
- `classify(name)` — given a String name, return
  `(role_symbol, rule_id_string_or_nil)`. The `visible` argument
  is REMOVED in V1.1 (R007: role and visibility are independent).
  The rule_id is for testability / debug; production code uses
  the role symbol.

Pattern rules in evaluation order (top-down-by-priority, R010).
**First match wins**; the order below is the canonical priority
and is NOT auto-promoted by specificity:

1. Name matches `*dim*` or `*dimension*` → `DIMENSION` (rule_id
   `"name_dimension"`).
2. Name matches `*anno*` / `*text*` / `*label*` → `ANNOTATION`
   (rule_id `"name_annotation"`).
3. Name matches `*guide*` / `*constr*` / `*xline*` → `GUIDE`
   (rule_id `"name_guide"`).
4. Name is exactly `"Layer0"`, `"Default"`, `"Untagged"` (case
   insensitive) → `CONSTRUCTION` (rule_id `"name_default_layer"`).
5. Otherwise → `UNKNOWN` (rule_id `"name_no_match"`).

**Top-down-by-priority rationale (R010)**: explicit priority is
more predictable and debuggable. Auto-promotion by specificity
would create hidden behavior — a future more-specific rule
would silently win over an earlier less-specific one, even if
the author meant the earlier rule to be the canonical answer.
Specificity MAY be a future tie-break or lint hint, but is NOT
the main rule. The current order is fixed; changing it requires
a code change + test pin (see §7.1).

Note: rules are NAME-ONLY. Visibility is captured separately by
`SUCapability.layer_visibility` (see §4.7) and stored on
`LayerRecord#visible` + `LayerRecord#visibility_unknown`. There
is no `:construction_offscreen` role — ChatGPT §11.3 explicitly
rejected the fused label.

### 4.3 `core/layer_record.rb` (V1.0 — extends, not breaks)

Add fields:
- `role` (LayerRole Symbol, one of the 5 name-based roles)
- `role_rule` (String, the rule_id that classified it; nil for
  UNKNOWN)
- `visible` (Boolean, the operational layer visibility — separate
  from role, per R007)
- `visibility_unknown` (Boolean, true iff host capability was
  missing and we could not determine visibility; per R011 the
  operational fallback is `visible: true` so the layer is NOT
  silently demoted)

V1.0 call sites that construct `LayerRecord` (`preflight_runner.rb`)
gain FOUR new keyword args: `role:` (default `LayerRole::UNKNOWN`),
`role_rule:` (default nil), `visible:` (default `true`),
`visibility_unknown:` (default `false`).

### 4.4 `core/layer_semantic_mapper.rb` (NEW)

Pure Ruby. Input: `Array<LayerRecord>` (V1.0 + V1.1 fields mixed
allowed, defaults fill in). Output: `Array<LayerSummary>` where
`LayerSummary` is a plain Hash with keys:
- `name: String`
- `role: LayerRole::Symbol` (5 name-based only)
- `role_rule: String or nil`
- `role_label: String` (= `LayerRole::HUMAN[role]`)
- `visible: Boolean` (raw, per R011 — operationally true even
  when `visibility_unknown: true`)
- `visibility_unknown: Boolean` (per R011 — true iff host could
  not determine visibility)
- `visibility_label: String` (composed via
  `LayerRole.visibility_label(visible, unknown)`; one of
  "Visible" / "Off-screen" / "Visibility: unknown")
- `edge_count: Integer` (from LayerRecord)
- `issue_count: Integer` (passed in by the caller from
  AnalysisResult grouping; see 4.5)

The mapper:
- Deduplicates by layer name (V1.0 had `LayerRecord` per
  *unique* layer; V1.1 keeps that). When deduplicating two
  LayerRecord with same name but different `visible` /
  `visibility_unknown`, see §12 (first-seen-wins default).
- Sorts results by **role bucket** (`LayerRole::ALL` order:
  dimension, annotation, guide, construction, unknown), then
  **within each role bucket** by `visible == true` first
  (visible rows before hidden rows per R009 / ChatGPT §11.2),
  then by `issue_count DESC`, then by `name ASC`
  (deterministic, mirroring IssueGrouper's tiebreak policy).
  Rows where `visibility_unknown: true` sort alongside visible
  rows (since `visible: true` is their operational value) but
  the UI surfaces the uncertainty via the visibility label
  ("Visibility: unknown"), so the user is not misled.

### 4.5 `core/layer_issue_grouper.rb` (NEW)

Pure Ruby. Input: `Array<UIIssue>` (V1.0 issue Hash shape) +
`Array<LayerRecord>`. Output: `Array<LayerIssueBucket>` where:
- `name: String`
- `issues: Array<UIIssue>` (filtered to that layer)
- `count: Integer`
- `default_open: Boolean` (true iff bucket contains a `:high`
  issue, same policy as IssueGrouper)

Each UIIssue gains a derived `layer_name` field, populated by
matching the issue's `source` chain to the layer name captured
on the Edge. Implementation: `EdgeRecord#layer` is set during
`build_snapshot`; the UIIssue that wraps a duplicate / short /
gap issue carries the originating edge's layer in
`issue[:source][:layer_name]` (new field, default nil; non-nil
when the analyzer can attach a layer). The LayerIssueGrouper
folds this in: per issue, the layer is
`issue[:source][:layer_name] || 'Layer0'` (matching V1.0's
`layer = 'Layer0' if layer.nil? || layer.empty?` fallback).

### 4.6 `extension/preflight_runner.rb` (V1.0 — extends, not breaks)

The line currently setting `layers: []` becomes a populated
`Array<LayerRecord>` derived from the walked edges. Each edge
contributes 1 to the per-layer `edge_count`, then the per-layer
record is enriched with `role`, `role_rule`, `visible` from
`SUCapability` (see 4.7).

V1.0's `EdgeRecord#layer` (String) is unchanged. V1.1 just
adds the per-layer aggregate.

### 4.7 `compatibility/su_capability.rb` (V1.0 — extends, not breaks)

Add ONE method:
```ruby
# Returns one of:
#   :visible  — host confirms the layer is visible
#   :hidden   — host confirms the layer is hidden (visible? == false)
#   :unknown  — host capability missing OR entity lacks #layer
#                OR the probe raised; caller should map
#                :unknown -> { visible: true, visibility_unknown: true }
#                per R011 fail-open direction.
def layer_visibility(entity)
  return :unknown unless entity.respond_to?(:layer) && entity.layer
  layer = entity.layer
  return :unknown unless layer.respond_to?(:visible?)
  v = layer.visible?
  return :unknown if v.nil?     # defensive: some hosts return nil
  v ? :visible : :hidden
rescue StandardError
  :unknown
end
```

R011 contract: the method returns `:unknown` (not `false`) when
host capability is missing. The caller in `preflight_runner.rb`
maps `:unknown` to `LayerRecord(visible: true, visibility_unknown:
true)` — operational fallback is visible, but the uncertainty is
preserved in the data model. We do NOT fake `:hidden` ("confirmed
hidden") when the answer is actually "I don't know".

Note: this method replaces the V1.0 design of
`layer_visible?` returning `Boolean | nil`. The previous nil
return is now `:unknown`, which is more explicit and self-
documenting.

### 4.8 `extension/analyzers_runner.rb` (V1.0 — extends, not breaks)

`run(selection, model: nil)` after producing the V1.0
`AnalysisResult`, also calls
`SUAnalysis::Core::LayerSemanticMapper.build(edges, issues)`
and merges the result into `result.summary['layer_groups']`
(Array<LayerSummary>). V1.0's existing summary keys stay
unchanged; V1.1 only ADDS the new key.

### 4.9 `extension/ui_bridge.rb` (V1.0 — extends, not breaks)

`as_html_data` adds ONE key to the top-level payload:
`'layerGroups'` = Array<Hash> (String-keyed). Each Hash has
the same shape as `LayerSummary` from 4.4, with String keys
and String role labels. The existing `summary`,
`displayData`, `diagnostics`, `groups` keys are unchanged.

### 4.10 `extension/html/app.js` (V1.0 — extends, not breaks)

- `render(payload)` now also calls `renderLayers(payload.layerGroups)`.
- New function `renderLayers(layerGroups)`: walks the array,
  for each summary creates a `<div class="layer-row" data-role="..."
  data-visible="true|false" data-visibility-unknown="true|false">`,
  populates with `textContent` only (layer name, role label,
  edge count, issue count, visibility label), NO innerHTML for
  user strings, no `eval`, no `new Function`.
- New locked label `ROOT.LAYER_ROLE_LABELS = LayerRole::HUMAN`
  in JS (mirroring `ROOT.ISSUE_TYPE_LABELS` from V1.0 Round 019
  Block-006 recheck). Also `ROOT.LAYER_VISIBILITY_LABELS` for
  the visible / off-screen / unknown mapping (server-side
  pre-composed via `LayerRole.visibility_label`; JS uses the
  per-row `visibility_label` field verbatim).
- Locked role order: `[dimension, annotation, guide, construction,
  unknown]` (matches `LayerRole::ALL`, 5 entries — OFFSCREEN
  removed per R007). The order is INDEPENDENT from
  `IssueRegistry::DEFAULT_GROUP_ORDER` (R012) — issue type and
  semantic role are two different information systems.
- Role badge: text only, neutral color (per R008 / ChatGPT §11.7).
  Each row carries BOTH a role badge (e.g. "Dimension") and a
  separate visibility badge (one of "Visible" / "Off-screen" /
  "Visibility: unknown"). The two are independent — a hidden
  "DIM-XX" layer shows `Dimension | Off-screen`, NOT
  "Construction (off-screen)".
- Rows where `visibility_unknown: true` show the
  "Visibility: unknown" badge (R011). The user is NOT misled
  into thinking the layer is "confirmed visible" — the data
  model preserves the uncertainty AND the UI surfaces it.
- Hidden rows have `data-visible="false"` and CSS applies a
  muted style (lower opacity). They are NOT moved to the top;
  they sit at the bottom of their role bucket (per R009 / ChatGPT
  §11.2). Rows with `visibility_unknown: true` are sorted
  alongside visible rows (per §4.4 mapper note) but their
  badge text distinguishes them.
- Edge count + issue count are both shown. When
  `issue_count > 0`, the issue count is visually emphasized
  (bold weight or larger size — TBD with CSS, see §4.12).
- The row has `cursor: default` and NO click handler (mirrors
  V1.0 L3 non-locatable warning pattern).
- "Layers" `<details>` is **closed by default** (per ChatGPT §11.5).
  When closed, the `<summary>` shows: `"Layers — N total (M with
  issues)"`. N = total layers, M = layers with `issue_count > 0`.
  JS populates the summary text BEFORE the open/close toggle fires
  (so the user sees the count even when collapsed).
- Layers section sits BELOW the per-issue-type groups (per
  ChatGPT §11.1).

### 4.11 `extension/html/index.html` (V1.0 — extends, not breaks)

Add ONE `<details id="layers-section">` block with an explicit
`<summary id="layers-summary">` child. The summary text is
populated by JS at render time. The block contains an empty
`<div id="layers-list"></div>` that JS populates when the
details is opened. No other DOM structure changes. The existing
`<details>` blocks (summary, issues) are unchanged.

```html
<details id="layers-section">
  <summary id="layers-summary">Layers</summary>
  <div id="layers-list"></div>
</details>
```

The `details` element is rendered closed by default (no
`open` attribute on the HTML). JS does NOT call `details.open
= true` automatically.

### 4.12 `extension/html/style.css` (V1.0 — extends, not breaks)

Add a SINGLE neutral style `.layer-row`. Per R008 / ChatGPT §11.7,
NO `data-role="..."` color selectors. The CSS adds:
- `.layer-row` — neutral text color, standard padding, border
  for row separation.
- `.layer-row .role-badge` — neutral badge style (e.g. light
  gray background, dark text). Same style for every role.
- `.layer-row .visibility-badge` — neutral badge style. When
  `data-visible="false"`, applies `opacity: 0.6` to the WHOLE
  row to make hidden layers visually muted.
- `.layer-row .issue-count.has-issues` — when
  `issue_count > 0`, the issue count is bold or larger.
- `.layer-row` `cursor: default` (no click target).

The V1.0 issue severity palette (R005) is NOT touched. The
locked CSS palette tokens for issues stay scoped to issues;
layers get a separate neutral badge style with no role color
distinction.


## 5. Out-of-scope but worth noting (deferred)

If ChatGPT + CodeX + Cicada later want these:
- Layer color / material analysis (would require
  `Layer#material` / `Layer#color` capability probes).
- Per-occurrence layer overrides (face material overrides;
  per-edge color).
- Layer relationship graph (parent/child layers — does not
  exist as a SU concept, but layer foldering might in future
  SU versions).
- Layer-based issue severity mutation (e.g. "issues on
  dimension layers are warning, not error"). This would
  re-open R005; NOT V1.1.
- Cross-model layer mapping (e.g. "DIM" → "Dimensions"
  across files). Out of scope; not a V1.1 ask.
- User-editable rule sets (would require a settings UI —
  R003 + R005 explicitly defer this).


## 6. Layer row display order

The dialog sorts layers in this order (deterministic, mirrors
the `LayerRole::ALL` order with tiebreakers; per R009 / ChatGPT
§11.2):

1. `:dimension`
2. `:annotation`
3. `:guide`
4. `:construction`
5. `:unknown`

`OFFSCREEN` is NOT a role — it is a visibility state. There is
no `:construction_offscreen` Symbol.

Within each role bucket, sort by `visible == true` FIRST (so
visible rows are at the top of each role), then by
`issue_count DESC` (most-issues-first), then by `name ASC`
(deterministic tiebreak).

Hidden layers (those with `data-visible="false"`) end up at
the bottom of their role bucket, visually muted via
`opacity: 0.6` (per §4.12). Layers with `visibility_unknown:
true` are sorted alongside visible rows (per §4.4 mapper note)
and the UI surfaces the uncertainty via the
"Visibility: unknown" badge (R011).

**This order is INDEPENDENT from `IssueRegistry::DEFAULT_GROUP_ORDER`
(R012)** — issue type and semantic role are two different
information systems, each with its own sort rule. `unknown`
is FIXED last in the role order.

This mirrors V1.0's `IssueGrouper` policy: severity-first
within bucket, then a stable secondary sort. Same principle,
applied to layers.


## 7. Test plan

### 7.1 Pure Ruby (no SketchUp required)

`tests/test_layer_role_config.rb` — NEW. Pin every rule
(name-only classify, per R007 — `visible:` is NOT a kwarg
in V1.1):
- `classify(name: "DIM-XX") == [:dimension, "name_dimension"]`
- `classify(name: "dim-xx") == [:dimension, "name_dimension"]` (case-insensitive)
- `classify(name: "TEXT-NOTES") == [:annotation, "name_annotation"]`
- `classify(name: "GUIDE-LINES") == [:guide, "name_guide"]`
- `classify(name: "Layer0") == [:construction, "name_default_layer"]`
- `classify(name: "default") == [:construction, "name_default_layer"]`
- `classify(name: "Untagged") == [:construction, "name_default_layer"]`
- `classify(name: "WEIRD-LAYER") == [:unknown, "name_no_match"]`
- `classify(name: "") == [:unknown, "name_no_match"]`
- `classify(name: nil)` raises `ArgumentError` (defensive; not silently passing nil through)
- `HUMAN` table has exactly 5 keys, all 5 role Symbols present
- `ALL` order is `[DIMENSION, ANNOTATION, GUIDE, CONSTRUCTION, UNKNOWN]`
- `VISIBILITY_HUMAN` table has exactly 2 keys: `true => 'Visible'`, `false => 'Off-screen'`
- `VISIBILITY_UNKNOWN_HUMAN` is the string `"Visibility: unknown"` (R011)
- `visibility_label(visible: true,  unknown: false) == "Visible"`
- `visibility_label(visible: false, unknown: false) == "Off-screen"`
- `visibility_label(visible: true,  unknown: true)  == "Visibility: unknown"`
- `visibility_label(visible: false, unknown: true)  == "Visibility: unknown"`
  (uncertainty wins over operational value; R011)
- `OFFSCREEN` constant is NOT defined (R007 — removed)

**R010 priority test (top-down-by-priority, not by-specificity)**:
- `classify(name: "DIM-ANNO")` returns `[:dimension, "name_dimension"]`,
  NOT `[:annotation, "name_annotation"]`. The layer name matches
  BOTH the dim and anno glob rules, but the dim rule comes FIRST
  in `RULES`, so it wins. Pins the intentional priority order.
- `RULES` is in declared order. Reordering `RULES` is an explicit
  code change, not auto-promoted by specificity.

`tests/test_layer_semantic_mapper.rb` — NEW. Test aggregate
behavior:
- Empty input → empty output
- One LayerRecord → one LayerSummary with the right role,
  `role_label`, `visible`, `visibility_label`
- Deduplication (two LayerRecord with same name → one
  LayerSummary, summed edge_count)
- Sort order: role bucket order from `ALL`, then within
  each bucket `visible == true` first, then `issue_count
  DESC`, then `name ASC`
- Hidden layer with name "DIM-XX" → role: `:dimension`,
  visible: `false`, `role_label: "Dimension"`,
  `visibility_label: "Off-screen"` (the two are independent)
- `visibility_unknown: true` layer with name "ANY-XX" →
  `visibility_label: "Visibility: unknown"`, `visible: true`
  (operational fallback), role classified by name only
  (R011)
- Issue count attribution: `LayerSummary#issue_count` equals
  the number of UIIssues whose `source[:layer_name]` matches
  the layer's name
- Default `visible: true` for an existing V1.0 LayerRecord
  that does not have the new field
- A layer with `issue_count == 0` does NOT block the
  visibility-first sort: hidden layers with no issues
  still sort to the bottom of their role bucket
- `visibility_unknown: true` layers sort alongside visible
  rows (operational `visible: true`) but the badge text
  distinguishes them in the dialog

`tests/test_su_capability_layer_visibility.rb` — NEW.
Pin R011 fail-open contract:
- `layer_visibility(FakeLayer(visible? => true))` → `:visible`
- `layer_visibility(FakeLayer(visible? => false))` → `:hidden`
- `layer_visibility(FakeLayer(visible? => nil))` → `:unknown`
  (defensive)
- `layer_visibility(FakeLayer(visible? raises StandardError))`
  → `:unknown`
- `layer_visibility(FakeEntityWithoutLayer)` → `:unknown`
- `layer_visibility(nil)` → `:unknown`
- `layer_visibility(FakeLayer(no_visible_method))` → `:unknown`
- Caller-side mapping in `preflight_runner`:
  `:visible → { visible: true,  visibility_unknown: false }`
  `:hidden  → { visible: false, visibility_unknown: false }`
  `:unknown → { visible: true,  visibility_unknown: true }`
  (operational fallback is visible; uncertainty preserved)

**R012 sort order test (independent of IssueRegistry)**:
- `LayerRole::ALL` equals
  `[:dimension, :annotation, :guide, :construction, :unknown]`.
- `LayerRole::ALL` does NOT equal
  `IssueRegistry::DEFAULT_GROUP_ORDER` (intentionally
  independent).
- Sort helper that uses `ALL` produces the expected order
  for a mixed input.

`tests/test_layer_issue_grouper.rb` — NEW. Test bucket
behavior:
- Empty input → empty buckets
- One issue with `source[:layer_name] = "DIM-XX"` → one
  bucket, count 1
- Three issues on layer "DIM-XX" (one `:high`, two `:low`)
  → bucket count 3, default_open = true
- Three issues on layer "DIM-XX" (all `:low`) → bucket
  default_open = false (no `:high`)
- Issue with no `source[:layer_name]` → attributed to
  `Layer0` (V1.0 fallback)
- Two layers with same issue count, sort by name ASC
- Bucket does NOT include issues whose layer name is not
  present in the supplied LayerRecord list (no auto-creation
  of phantom layers)

### 7.2 Adapter / fake-host

`tests/test_preflight_runner.rb` — extend (no rewrite).
- FakeLayer with `.visible?` returning `true` / `false` /
  raising StandardError
- `build_snapshot` populates `layers:` with one record per
  unique layer, each with the right `role`, `role_rule`,
  `visible`
- A FakeLayer whose `.visible?` raises → recorded as
  `visible: true` (fail-closed, do NOT classify as
  OFFSCREEN due to missing capability)
- A FakeEntity with no `.layer` (V1.0 already handles via
  `SUCapability.layer_name` returning nil) → still produces
  a `LayerRecord` for `Layer0` (V1.0 fallback), with
  `role: :construction` (Layer0 default), `visible: true`
- An EdgeRecord that has `layer: ""` → `Layer0` (V1.0
  fallback path), role `:construction`

`tests/test_analyzers_runner.rb` — extend. After V1.0 tests
still pass, add:
- `result.summary['layer_groups']` is an Array
- For a snapshot with 1 layer and 1 issue, the layer_groups
  has 1 entry with `issue_count == 1`
- For a snapshot with 0 layers, `layer_groups == []`
- The `layer_groups` Array order matches §6

### 7.3 UI render (Node.js, no SketchUp)

`tests/test_html_render_dom.js` — extend. Add L4 tests:
- `renderLayers` exists on `window.SUAIP` (or equivalent root
  exposure)
- For a payload with 2 layer summaries, the DOM has 2
  `.layer-row` children inside `#layers-list`
- For a payload with 1 layer summary whose `visible: false`,
  the row has `data-visible="false"` AND a separate
  visibility badge text "Off-screen" (NOT a fused role label)
- The row's textContent contains `edge_count` and
  `issue_count` (as Strings)
- When `issue_count > 0`, the issue count has
  `class="has-issues"` (or equivalent emphasis class)
- No `[object Object]` anywhere (stringification guard)
- `payload.layerGroups` undefined → `#layers-list` is empty
  (no error)
- `ROOT.LAYER_ROLE_LABELS` is defined with the 5 canonical
  roles (NO OFFSCREEN)
- `ROOT.LAYER_VISIBILITY_LABELS` is defined with the 2
  visibility labels
- The new `<details id="layers-section">` is in `index.html`
- The `<details id="layers-section">` is rendered CLOSED
  (no `open` attribute on initial DOM)
- The `<summary id="layers-summary">` text is populated
  with `"Layers — N total (M with issues)"` BEFORE the user
  opens the details
- A row with `data-visible="false"` has CSS class for muted
  display (asserted via computed style if available in mock)
- Layer row click does NOT invoke `window.sketchup.locate`
  (mirrors V1.0 L3 non-locatable pattern)

`tests/test_html_render.rb` — extend. Source-level guards:
- `renderLayers` appears exactly once in `app.js`
- `textContent` is the only DOM-mutation API used inside
  `renderLayers` (no `innerHTML = ...` for user strings)
- `eval(` / `new Function(` / `document.write(` count is
  unchanged (V1.0's count + 0)
- `index.html` has exactly one `<details id="layers-section">`
  AND the `<summary id="layers-summary">` is its first child
- `index.html` does NOT have `open` attribute on the layers
  details (closed by default)
- `style.css` has `.layer-row` defined
- `style.css` has a muted style for `.layer-row[data-visible="false"]`
  (e.g. `opacity: 0.6`)
- `style.css` has `.issue-count.has-issues` emphasis
- `style.css` does NOT have `.layer-row[data-role="..."]`
  color selectors (per R008 / ChatGPT §11.7)

### 7.4 Regression

- V1.0 test suite (286 tests) MUST still pass. No V1.0
  behavior changes (only additive).
- The `dist/SU-AI-Plugin.rbz` produced by the V1.1 build is
  re-verified on real SU2020 by Owner (Gate 2 V1.1). The
  V1.0 Owner verification checklist (Review/OWNER_VERIFICATION_RBZ_INSTALL_2026-08-19.txt)
  is re-run as the Gate 2 V1.1 base; V1.1-specific checks
  (Layers section visible, layer row data correct) are
  added on top.

### 7.5 Forbidden regressions

This rework MUST NOT re-open:
- R001 (thresholds — none added)
- R002 (HtmlDialog namespace — unchanged)
- R003 (no overlay / no mutation — V1.1 inherits; no
  `model.entities.add_*` introduced anywhere)
- R004 (SU2017+ / Ruby 2.2.4 — V1.1 uses no new syntax)
- R005 (severity palette + group ordering — unchanged)
- Any V1.0 CodeX 015..024 BLOCK / recheck scope


## 8. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Name pattern not matching user's actual layer naming convention | High | Low | Role is informational, not prescriptive. `:unknown` is a valid role (R007 / ChatGPT §11.6). V1.1 documents the rules in `LayerRoleConfig`; user can mentally map their naming to the closest role. |
| Hidden layer shown next to its name-based role (R007) confuses user who expected a "hidden = something different" indicator | Medium | Low | The separate "Off-screen" visibility badge makes the state explicit. The row is also visually muted (`opacity: 0.6`). User who disagrees can mentally swap role and visibility in their head; V1.1 documents the independence. |
| `Layer#visible?` capability missing on SU2017 | Low | Low | R011 fail-open: `layer_visibility` returns `:unknown`; caller maps to `visible: true, visibility_unknown: true` (operational fallback is visible, but the data model preserves the uncertainty). Test pin covers all capability-missing paths. |
| `EdgeRecord#layer` empty string on a malformed entity | Low | Low | V1.0 already normalizes to `'Layer0'`. V1.1 inherits. |
| Performance with 100+ layers | Low | Low | `LayerSemanticMapper.build` is O(N + M log M) where N = edges, M = unique layers. Snapshot for 5000 edges (V1.0 TC-10) is well under 1s. |
| `role` / `visible` fields are Booleans/Symbols — JSON-safe in ui_bridge but not as HTML attribute values | Low | Low | ui_bridge.rb stringifies via `to_s` per `LayerRole::HUMAN` / `VISIBILITY_HUMAN` lookups. Test pin: the JS payload `role` and `visibility_label` are Strings, not Symbols. |
| Layer changes within a session (user toggles a layer off mid-analysis) | Very low | Very low | Analysis is one-shot per click; layer visibility captured at start of `build_snapshot`. No incremental updates. |
| L4 render test mocks the wrong DOM node | Medium | Medium | Mock DOM assertion against `#layers-list` + `#layers-summary` (the locked IDs from `index.html` change). If `index.html` IDs change, both ends change together. |
| User expects click on layer row to filter / locate | High | Low | V1.0 has no filter controls. V1.1 keeps that contract. Layer rows have `cursor: default`, no click handler, no `data-locatable` (same as V1.0 L3 non-locatable warning). |
| User expects role color hints (e.g. "Dimension in orange") but R008 says no role colors | Medium | Low | R008 is a deliberate ChatGPT decision (avoid palette collision with V1.0 issue severity). The role TEXT distinguishes roles; if the user later wants color, V1.2 can add a `data-role` color selector without changing the data model. |
| Default-closed details makes user miss the layer info entirely | Low | Medium | The `<summary>` is populated with `"Layers — N total (M with issues)"` so the headline is visible even when closed. Test pin: summary text is set before user interaction. |
| R010 priority order — future engineer reorders `RULES` thinking "more specific should win" | Medium | Medium | R010 rationale is documented inline (§4.2). R012 test pin demonstrates the priority is intentional (e.g. "DIM-ANNO" → dimension, not annotation). Code review / CodeX end-of-stage verifies the rule order is the canonical one. |
| R011 fail-open — user sees "Visibility: unknown" badge and thinks the layer is "confirmed visible" | Low | Low | The badge text is explicit: "Visibility: unknown" (not "Visible"). Data model preserves the flag. R011 test pin verifies the badge text. |
| R012 role order — future change to match `IssueRegistry::DEFAULT_GROUP_ORDER` | Low | Low | R012 is documented in §6 and §1. Locked role order is independent of issue-type order by design. R012 test pin verifies the two orders are NOT equal. |


## 9. Acceptance criteria (V1.1 done = all of these)

- [ ] `tests/test_layer_role_config.rb` exists, all rule pins pass.
- [ ] `tests/test_layer_semantic_mapper.rb` exists, all aggregate
      tests pass.
- [ ] `tests/test_layer_issue_grouper.rb` exists, all bucket tests
      pass.
- [ ] `tests/test_preflight_runner.rb` extended, all V1.1-specific
      adapter tests pass.
- [ ] `tests/test_analyzers_runner.rb` extended, `summary['layer_groups']`
      shape verified.
- [ ] `tests/test_html_render_dom.js` extended, all L4 DOM tests
      pass via Node.
- [ ] `tests/test_html_render.rb` extended, all source-level guards
      pass.
- [ ] V1.0 test suite (286 tests) still passes unchanged.
- [ ] `dist/SU-AI-Plugin.rbz` builds cleanly via `scripts/build_rbz.rb`.
- [ ] Gate 2 V1.1: Owner re-runs the V1.0 checklist PLUS the
      V1.1-specific checks on real SU2020. Report at
      `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-XX.txt`.
- [ ] `tests/test_rbz_smoke.rb` (V1.0) still passes for the V1.1
      artifact (the entry-point + dialog asset paths are unchanged
      in shape).
- [ ] `git diff --check` clean on the V1.1 commit.
- [ ] No `Prompt/` write (Agent → Review/ only).
- [ ] No new CodeX review round mid-implementation (CodeX review
      happens on the COMPLETE V1.1 stage, per the Pi handoff
      "CodeX is invoked only at the end-of-stage boundary" rule).
- [ ] V1.0 candidate tag `v1.0-candidate-2026-08-19` is NOT
      modified; V1.1 work lives on `v1.1-layer-semantic-mapping`
      only.
- [ ] Gate 1 (SU2017) remains PENDING per R006 — NOT a V1.1
      blocker.


## 11. Open questions for ChatGPT (scope / UX / policy)

Per Cicada 2026-08-19 routing principle ("理论上只要chatgpt能做的
就不给codex做"), these questions are routed to **ChatGPT** by
default. None of them require direct source / Git / diff
inspection; they are all policy / scope / UX choices that
ChatGPT can reason about from the plan doc + generic design
tradeoffs. CodeX is NOT asked to re-litigate any of these.

**UI placement** (4 questions — Q1..Q4 answered 2026-08-19):
1. **Q1 (ANSWERED)**: "Layers" section sits BELOW the existing
   per-issue-type groups. Locked into §2 / §4.10 / §4.11.
2. **Q2 (ANSWERED)**: Hidden layers sort LAST within their role
   bucket, with a slightly muted display. The `:offscreen` role
   is REMOVED entirely (see R007). The role bucket order
   becomes `[dimension, annotation, guide, construction,
   unknown]` per §6. Within each bucket, visible rows come
   first, then hidden rows (muted via `opacity: 0.6`).
3. **Q3 (ANSWERED)**: Role and visibility are SEPARATE fields.
   The role badge shows the name-based role (e.g. "Dimension",
   "Construction"). The visibility badge is a SEPARATE status
   indicator showing "Off-screen" or "Visible". The fused
   "Construction (off-screen)" label is REJECTED. See R007 +
   §4.1 + §4.10.
4. **Q4 (ANSWERED)**: Per-layer `edge_count` and `issue_count`
   are BOTH shown. When `issue_count > 0`, the issue count is
   visually emphasized (bold weight, larger size — see
   §4.10 / §4.12). Locked into §4.4 LayerSummary fields +
   §4.10 render contract.

**Default-open + unknown policy** (2 questions — Q5..Q6 answered
2026-08-19):
5. **Q5 (ANSWERED)**: Layers `<details>` is **default-closed**.
   When closed, the `<summary>` text is populated by JS with
   `"Layers — N total (M with issues)"` so the user sees the
   headline numbers without expanding. N = total layers, M =
   layers with `issue_count > 0`. See §4.10 / §4.11.
6. **Q6 (ANSWERED)**: `:unknown` role is RETAINED, surfaced as
   `"Unknown / ?"` label. NOT silently fallback to
   `:construction`. See §4.1 HUMAN table.

**Color hints** (1 question — Q7 answered 2026-08-19):
7. **Q7 (ANSWERED)**: V1.1 does NOT use role colors. Roles
   use text + neutral badge. The V1.0 issue severity palette
   (R005) is NOT reused for roles — it stays scoped to issues.
   See R008 + §4.10 / §4.12. CSS adds a single neutral
   `.layer-row` style; NO `data-role="..."` color selectors
   in V1.1.

**Rule ordering + fail-closed direction** (2 questions —
ANSWERED 2026-08-19, originally §12.1 / §12.2):
8. **Q8 (ANSWERED → R010)**: Rule ordering is **top-down-by-priority**
   (declared order, first match wins). NOT auto-promoted by
   specificity. Rationale: explicit priority is more
   predictable, more debuggable, no implicit "more specific =
   more important" hidden behavior. Specificity MAY be a
   future tie-break or lint hint, but NOT the main rule. Test
   pin: a layer matching two rules gets the FIRST rule's role.
9. **Q9 (ANSWERED → R011)**: `layer_visibility` returns `:unknown`
   when host capability is missing. The caller maps `:unknown`
   to `{ visible: true, visibility_unknown: true }` —
   operational fallback is visible (so the layer is NOT
   silently demoted / sorted-last / dropped), BUT the data
   model preserves the uncertainty via the
   `visibility_unknown` flag. The UI surfaces this as a
   third badge "Visibility: unknown". We do NOT fake
   `false` ("confirmed hidden") when the answer is actually
   "I don't know". `SUCapability.layer_visibility` method
   signature: returns `:visible | :hidden | :unknown` (Symbol,
   not Boolean | nil).

**Sort / canonical order** (1 question — ANSWERED 2026-08-19,
originally §12.4):
10. **Q10 (ANSWERED → R012)**: The locked role order is
    `[dimension, annotation, guide, construction, unknown]`
    and is INDEPENDENT from `IssueRegistry::DEFAULT_GROUP_ORDER`.
    Issue type and semantic role are two different information
    systems, each with its own sort rule. `unknown` is FIXED
    last. No future change to match `IssueRegistry` order.
    R012 test pin verifies the two orders are NOT equal.


## 12. Agent self decisions (defaulted; can be overridden during implementation)

These are contained code-architecture choices that do NOT
require an external reviewer. Agent decides during
implementation, with the default documented below. If
implementation reveals a real reason to deviate, the change
is captured in `CURRENT_STATE.md` as a documented local
decision, not a review escalation.

**Q3 (was §12.3). Edge → layer attribution** — DEFAULT:
**captured on `SourceReference` at snapshot time**.

Rationale: `SourceReference` is already the read-only identity
record built during `build_snapshot`. The layer name is a
property of the entity that is already known at snapshot time.
Adding a `layer_name:` keyword to `SourceReference.new` is a
purely additive change (V1.0 call sites do not supply it, so
V1.0 behavior is unchanged). Storing the layer on the
SourceReference means the LayerIssueGrouper does not need to
re-look-up the layer from the entity during issue-build; the
issue's `source[:layer_name]` is read directly from the
`SourceReference` it already wraps.

Risk: V1.0 `SourceReference` is locked. The change is purely
additive (new optional kwarg, default `nil`), so the V1.0
contract is preserved. Test pins: V1.0 test_loader / test_ui_bridge
must continue to pass with a `SourceReference` that has
`layer_name: nil`.

**Q5 (was §12.5). Same-name layer dedup** — DEFAULT:
**first-seen-wins, ordered by EdgeRecord.id ASC**.

Rationale: V1.0 `LayerRecord` is built per unique layer name;
V1.1 keeps that. If a future change introduces per-face
material overrides that flip one edge on layer "DIM-XX" to
hidden, V1.1 still sees two LayerRecord entries with
`name == "DIM-XX"` and different `visible` values. The
dedup in `LayerSemanticMapper.build` keeps the first
LayerRecord (EdgeRecord.id ASC) and reports its `visible` and
`role`. The second entry is silently absorbed.

Risk: a per-edge visibility flip is very rare in real SU
models. If it ever surfaces in a real-host Owner report, the
fix is local to `LayerSemanticMapper.build` (e.g. "if any
edge on this layer is visible, treat as visible; otherwise
mark off-screen"). Document as `[nit]` if seen, do not block
V1.1.

**CodeX does NOT see §11 or §12.** CodeX is reserved for the
end-of-stage review packet (§13), which is the full V1.1
implementation diff + tests + Gate 2 Owner evidence.


## 13. End-of-stage CodeX review packet (after implementation)

When the V1.1 implementation lands, this section becomes the
CodeX review packet contents:

- This plan doc
  (`Review/V1_1_LAYER_SEMANTIC_MAPPING_PLAN_2026-08-19.md`),
  with §11 (ChatGPT answers filled in) + §12 (any Agent self
  deviations documented).
- Base/head: `v1.0-candidate-2026-08-19` (base) → current
  `v1.1-layer-semantic-mapping` head (after implementation
  commits).
- Changed files (once implementation lands):
  `core/layer_role.rb` (NEW), `core/layer_role_config.rb` (NEW),
  `core/layer_record.rb` (extend), `core/layer_semantic_mapper.rb` (NEW),
  `core/layer_issue_grouper.rb` (NEW),
  `extension/preflight_runner.rb` (extend, populate `layers:`),
  `extension/analyzers_runner.rb` (extend, merge layer_groups),
  `extension/ui_bridge.rb` (extend, layerGroups key),
  `extension/html/index.html` (extend, layers-section),
  `extension/html/app.js` (extend, renderLayers),
  `extension/html/style.css` (extend, .layer-row),
  `compatibility/su_capability.rb` (extend, layer_visible?),
  `tests/test_layer_role_config.rb` (NEW),
  `tests/test_layer_semantic_mapper.rb` (NEW),
  `tests/test_layer_issue_grouper.rb` (NEW),
  `tests/test_preflight_runner.rb` (extend),
  `tests/test_analyzers_runner.rb` (extend),
  `tests/test_html_render.rb` (extend),
  `tests/test_html_render_dom.js` (extend).
- Test results: all NEW + extended tests pass; V1.0 286 tests
  still pass; full suite 286+N / 286+N PASS.
- Real-host evidence: Gate 2 V1.1 Owner report
  (`Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-XX.txt`).
- Remaining known risk: §8.
- §11 ChatGPT answers + §12 Agent self defaults (with any
  deviations from the defaults noted).
- NO request to re-open V1.0 Stage 6 / CodeX 020 / RBZ / CodeX 024
  scope.

The trigger for the end-of-stage CodeX packet is the
"meaningful coherent stage" boundary in the Pi handoff:
"Codex is the default technical reviewer when direct source/Git/diff
review is genuinely needed, especially for a meaningful coherent
stage ... or final release review". The full V1.1 implementation
diff is the meaningful coherent stage; that is where CodeX
engages.

END
