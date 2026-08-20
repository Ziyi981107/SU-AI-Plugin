# Stage 6 — UI Implementation Plan (revised v4, after Codex Review 013)

| Field | Value |
|---|---|
| Date | 2026-08-18 (revised v4 after Codex Review 013) |
| Previous packet | `Review/STAGE_6_PLAN_REVISED_2026_08_18_PASS3.md` (SUPERSEDED) |
| Project | D:\Projects\SU-AI-Plugin |
| Stage | 6 (UI — `UI::HtmlDialog` + Issue registry presentation) |
| Locked decisions | R001 / R002 / R003 / R004 / R005 |
| Source-of-truth contracts | PI_TASK_001 §11 / §12 / §13 / §14 / §17 / §18 / §91 |
| Author | Agent (revised v4 after Codex Review 013) |
| Status | **REVISED v4 — addresses S6-PLAN-BLOCK-001 v4 + S6-VERIFY-BLOCK-001 v2** |
| Codex Review 010 | BLOCKED (BLOCK-001..004) |
| Codex Review 011 | BLOCKED (BLOCK-001 + -003 narrow; -002/-004 CLOSED) |
| Codex Review 012 | BLOCKED (BLOCK-001 v3 + VERIFY-001; -002/-003/-004 CLOSED) |
| Codex Review 013 | BLOCKED (BLOCK-001 v4 + VERIFY-001 v2; -002/-003/-004 CLOSED) |


## 0. Why this is a revision

Codex Review 013 returned **VERDICT: BLOCKED** with two narrow
contract defects:

**CLOSED** (must not reopen): S6-PLAN-BLOCK-002, S6-PLAN-BLOCK-003,
S6-PLAN-BLOCK-004.

**BLOCK-001 v4**: `pid_path_complete` was defined as "every container
PID was captured" — but the **leaf Entity PID** itself can be nil.
A root-level Edge has no container, so the previous definition
yielded `pid_path_complete == true` even when the leaf PID was nil
and the path was `[]`. The locator would attempt empty-path
resolution and never reach the entityID fallback. The fix: cover
the full path including the leaf PID.

**VERIFY-001 v2**: three remaining concrete checklist contradictions:
(A) `dangling` is a Group containing an Edge, so its open-endpoint
Issues are structurally nested, not root-level; (B) `outer_g` has
two connected edges in an L shape, so it ALSO emits two open-endpoint
Issues alongside the deep-nesting warning; (C) erasing the only
Edge in `dangling` leaves no analyzable geometry for the M step.

The 3 NITs are addressed: recursive fingerprint is a geometry/count
fingerprint (not the sole ground truth for property-only mutation),
`structural_depth_facts` is moved out of SUCapability into pure-Ruby
`core/structural_facts.rb`, and SourceReference defaults are not
explicit-construction-incompatible.

Codex's 4 questions are answered below: Q1 yes, Q2 yes, Q3 yes
(leaf PID included), Q4 yes (and the inverse missing-leaf case is
added).

No code has been written yet. The plan is still the only artifact
under review. Codex Review 013 directive: "After these two narrow
blocks close: PASS TO IMPLEMENT Gate A."


## 1. Locked decisions (recap, do NOT re-litigate)

Same as v3. The new contract clarifications are folded in:

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
| NEW (BLOCK-001 v4) | `pid_path_complete` covers the full path — every structural ancestor PID AND the leaf Entity PID. Invariant: `expected_pid_count = structural_depth + 1`. | §3.2, §3.10, §6.3, §7 |
| NEW (BLOCK-003) | `issue_locator.rb` and `display_unit_formatter.rb` live in `extension/`, not `core/`. Core stays pure Ruby. | §4.1 |
| NEW (NIT) | `structural_facts.rb` (pure-Ruby) holds `structural_depth_facts`; SUCapability stays focused on host probes (`html_dialog?`, `find_entity_by_id`, `resolve_pid_path`, etc.) | §4.1, §4.2 |
| NEW (NIT) | SourceReference is constructed EXPLICITLY at snapshot build time; `structural_depth: 0` / `pid_path_complete: true` are NOT default for production code paths | §3.10, §4.2 |
| NEW (NIT) | The recursive fingerprint is a geometry/count fingerprint; it does NOT prove absence of property-only mutations (material/layer/hidden/soft). The `test_no_overlay_lint` and real-host behavior evidence remain necessary alongside it. | §6.1, §11 |


## 2. What V1.0 UI does and does NOT do

Same as v3.

## 3. The unified Issue / AnalysisResult contract (S6-PLAN-BLOCK-001 v4)

### 3.1 `UIIssue` Hash (canonical contract — JSON-safe to UI)

Same as v3. Symbol keys internally, JSON String keys at the
UIBridge boundary only.

### 3.2 `SourceToken` Hash (aligned source of truth — Symbols internally)

The source of truth is a single array of aligned Hashes:

```ruby
# SourceToken — one per resolved EdgeRecord; never split.
# Constructed only by core/issue_enricher.rb.
# Internal Symbol keys; JSON-stringified at extension/ui_bridge.rb.
{
  persistent_id_path: Array<Integer>,    # canonical SU persistent_id_path
  entity_id:          Integer or nil,    # transient entityID (in-session only)
  nested:             Boolean,           # structural nesting (NOT pid_path.size)
  pid_path_complete:  Boolean            # FULL path complete (ancestry + leaf)
}
```

**`pid_path_complete` revised definition (BLOCK-001 v4)**:

`pid_path_complete` is true iff:

1. every structural ancestor PID along the ancestry was captured
   (no container PID is nil), AND
2. the leaf Entity PID itself was captured (non-nil).

Equivalently (with active edit context included in structural depth):

```
expected_pid_count = structural_depth + 1   # depth=0 root -> 1
                                            # depth=2 nested -> 3
actual_pid_count   = pid_path.length
ancestry_complete  = (no nil entry in pid_path)
pid_path_complete  = ancestry_complete &&
                     !leaf_pid.nil? &&
                     actual_pid_count == expected_pid_count
```

The leaf PID check is the new piece. Without it, a root-level Edge
whose own PID is nil would have `pid_path = []` AND `pid_path_complete
== true` (the previous definition), causing the locator to attempt
empty-path resolution and silently skip the entityID fallback.

Combined with `nested`, the locator profiles become:

| profile | nested | pid_path_complete | pid_path | entity_id | target |
|---|---|---|---|---|---|
| complete-root | false | true | `[leaf_pid]` (size 1) | any | `InstPath#leaf` |
| complete-nested | true | true | `[c, ..., leaf_pid]` (size>1) | any | `InstPath#root` |
| incomplete-root | false | false | `[]` | non-nil | `model.find_entity_by_id(entity_id)` |
| incomplete-nested-partial-leaf | true | false | `[leaf_pid]` only | any | **non-locatable** |
| incomplete-nested-partial-ancestry | true | false | `[]` | any | **non-locatable** |
| fully-missing | n/a | n/a | `[]` | nil | non-locatable |

Note `incomplete-nested-partial-leaf` is now an explicit case
distinguished from `incomplete-nested-partial-ancestry` (the previous
`incomplete-nested-partial`). Both are non-locatable; the table
documents both shapes for completeness.

### 3.3 `AnalysisResult` (one immutable return value)

Same as v3. No setters, frozen top-level, nested immutability
verified by tests.

### 3.4 `IssueRegistry` (pure-Ruby)

Same as v3.

### 3.5 Canonical `issue_type` strings (R005)

Same as v3.

### 3.6 Deterministic `issue_id` (R005)

Same as v3. `entity_id` is NEVER used.

### 3.7 `locatable` derivation (BLOCK-001 v3/v4)

In `core/issue_enricher.rb`:

```
locatable = sources.any? { |t|
  (t[:nested] == false && t[:pid_path_complete] == true) ||
  (t[:nested] == true  && t[:pid_path_complete] == true) ||
  (t[:nested] == false && t[:pid_path_complete] == false &&
   !t[:entity_id].nil?)
}
```

This formula now correctly handles the case where a root-level source
has no leaf PID:

- `nested=false`, `pid_path_complete=false` (because leaf PID is nil),
  `entity_id` non-nil → entityID fallback. ✓
- `nested=false`, `pid_path_complete=true` (leaf PID was captured) →
  InstPath#leaf. ✓
- `nested=true`, `pid_path_complete=false` (any missing PID) → non-locatable. ✓

### 3.8 Display-unit formatting (BLOCK-003)

Same as v3. `extension/display_unit_formatter.rb` is the only host
formatter.

### 3.9 Preflight-warning → Issue conversion

Same as v3.

### 3.10 Structural identity capture at snapshot construction (BLOCK-001 v4)

The traversal in `extension/preflight_runner.rb` is enhanced to
carry structural facts alongside PID paths. The invariants ARE
the BLOCK-001 v4 fix:

```ruby
# pseudo-code added to walk_entity_world (BLOCK-001 v4)
# Active edit context contributes its own depth and incomplete
# path fact. Each entity in model.active_path adds 1 to depth
# and toggles pid_path_complete (false if any yields nil).

# Inside walk_entity_world, when we yield a leaf Edge:
expected_pid_count = struct_depth + 1      # struct_depth already
                                            #   includes containers
                                            #   and active edit path
actual_pid_count   = new_pid_path.length   # before yield
cont_pid           = safe_persistent_id(entity)
ancestry_complete  = parent_path_complete && !cont_pid.nil?
leaf_pid_present   = !cont_pid.nil?
pid_path_complete  = ancestry_complete && leaf_pid_present &&
                     actual_pid_count == expected_pid_count
yield (
  entity,
  endpoints,
  new_pid_path,           # full path including leaf PID
  label_path,
  structural_depth: struct_depth,
  pid_path_complete: pid_path_complete
)
```

The active edit context is included in `struct_depth` and
`parent_path_complete` via the seed pre-loop:

```ruby
# Seed from active edit context (pre-loop)
active_t, active_pids =
  SUAnalysis::Compatibility::SUCapability.active_edit_context(model)
seed_struct_depth = active_pids.length          # each active entity
                                                #   contributes 1
seed_path_complete = active_pids.all? { |p| !p.nil? }
```

This guarantees that the `expected_pid_count == structural_depth + 1`
invariant holds for every leaf, regardless of whether the leaf
itself is root-level or nested inside an active edit path.

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

Same as v3.

### 3.13 Gap-candidate empty-source fix

Same as v3.

## 4. File inventory (revised for BLOCK-001 v4 + VERIFY-001 v2 + NIT)

### 4.1 New files

| Path | Gate | LoC est. | Purpose |
|---|---|---|---|
| `core/issue_registry.rb` | A | ~150 | Pure-Ruby IssueRegistry per §3.4; tolerant drop on malformed |
| `core/issue_id_assigner.rb` | A | ~80 | Deterministic IDs per §3.6; never uses `object_id` or `entity_id` |
| `core/issue_enricher.rb` | A | ~100 | Aligned SourceToken array per §3.11; structural identity preserved |
| `core/issue_normalizer.rb` | A | ~120 | One-boundary normalization: `kind` → `issue_type`, Symbol → String severity, R005 per-type mapping, preflight warning → Issue |
| `core/issue_grouper.rb` | A | ~80 | Pure-Ruby grouping by `issue_type` per §6.6 |
| `core/analysis_result.rb` | A | ~80 | Immutable wrapper per §3.3; one per `Analyze selection` |
| `core/issue_locator_policy.rb` | A | ~100 | Pure-Ruby locator policy: 6 profile → target descriptor. NO SketchUp imports. |
| `core/structural_facts.rb` | A | ~40 | Pure-Ruby helper: `pid_path_complete?(depth, ancestry, leaf_pid)` + `expected_pid_count(depth)` (NIT: not in SUCapability) |
| `extension/issue_locator.rb` | B | ~140 | Implements the policy using `model`, `SUCapability`, `InstancePath`, `entityID fallback`. Concrete ownership of `model.find_entity_by_id` calls. |
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
| `tests/test_issue_enricher.rb` | A | ~100 | Pure-Ruby: aligned tokens, missing-edge diagnostic, whole-token dedup, structural identity preserved across traversal variations |
| `tests/test_issue_normalizer.rb` | A | ~100 | Pure-Ruby: per-type mapping, preflight warning → Issue, severity String end-to-end |
| `tests/test_issue_grouper.rb` | A | ~80 | Pure-Ruby: grouping, count, default_open per Q1 |
| `tests/test_analysis_result.rb` | A | ~100 | Pure-Ruby: no public setters, frozen top-level, frozen-diagnostics assertion |
| `tests/test_issue_locator_policy.rb` | A | ~120 | Pure-Ruby: 6 profile targets, no host deps |
| `tests/test_structural_facts.rb` | A | ~40 | Pure-Ruby: pid_path_complete() and expected_pid_count() — NIT support |
| `tests/test_core_no_host_dependency.rb` | A | ~80 | Lint: scans new core files for forbidden tokens (`Sketchup`, `UI`, `Geom`, `compatibility/`, `extension/`). Single FAIL = any hit. |
| `tests/test_issue_locator.rb` | B | ~120 | Adapter: 6 profile cases, FakeInstancePath, including missing-leaf-PID root + nested-partial-leaf cases |
| `tests/test_analyzers_runner.rb` | B | ~120 | Adapter: one snapshot per command, registry built from snapshot, explicit snapshot_lookup index |
| `tests/test_loader.rb` | B | ~80 | Adapter: FakeUI Command registry; idempotent registration across reloads |
| `tests/test_dialog_runner.rb` | B | ~120 | Adapter: set_file path, ready handshake, callback rebind on reopen, JSON.execute_script, no `eval`/`innerHTML`/`document.write` |
| `tests/test_ui_bridge.rb` | B | ~80 | Pure-Ruby: Symbol → JSON String conversion, no SU types, escaping for JSON |
| `tests/test_display_unit_formatter.rb` | B | ~60 | Adapter: `Sketchup.format_length` integration + non-SU fallback |
| `tests/test_html_render.rb` | B | ~120 | Pure-Ruby: token scan of JS source for `eval`, `new Function`, `document.write`, `innerHTML` for user-supplied strings; static lint of HTML/CSS |
| `tests/test_no_overlay_lint.rb` | B | ~80 | `Ripper.lex`-based scanner of `extension/*.rb` for forbidden tokens. Per NIT: this proves absence of a finite forbidden-token set; real-host fingerprint is the geometry/count ground truth; property-only mutations require the lint + real-host behavior evidence. |
| `tests/test_ruby_22_syntax_sweep.rb` | B | 1 | Extended sweep: 22 + new files; 0 syntax issues |
| `tests/_fake_ui.rb` | B | ~150 | Fake `UI::HtmlDialog` + `UI::Command` + `UI::Menu` for adapter tests — `tests/` only |
| `tests/_fake_instance_path.rb` | B | ~80 | Fake `Sketchup::InstancePath` (root/leaf/to_a/empty) for locator tests |
| `Review/OWNER_VERIFICATION_STAGE_6.txt` | B | n/a | Owner Verification Stage 6 checklist (5 steps J..N) per Codex Q3 AND revised per VERIFY-001 v2 |

### 4.2 Modified files

| Path | Modify |
|---|---|
| `core/source_reference.rb` | Add `structural_depth` and `pid_path_complete` Sym-key fields. Per **NIT**: do NOT provide default values that allow an empty-path production source to appear complete. The constructor accepts `structural_depth:` (required) and `pid_path_complete:` (required). All production callers must supply both explicitly. |
| `extension/preflight_runner.rb` | Walk loop tracks `parent_struct_depth` and `parent_pid_path_complete` AND `leaf_pid`; passes them to `build_source_reference`; yields the structural slice to the `EdgeRecord` builder. Active edit context is folded into the seed struct depth and path completeness. **No change to the existing traversal semantics** — only adds the new fields. |
| `compatibility/su_capability.rb` | Add safe `find_entity_by_id(model, entity_id)` wrapper: returns nil for nil input, returns nil if model lacks `find_entity_by_id`, returns nil on any error, otherwise returns the Entity. Fails closed. Per NIT: `structural_depth_facts` is NOT added here; it lives in `core/structural_facts.rb` (pure arithmetic). |
| `tests/_fake_su.rb` | Add `FakeUI` namespace (delegate to `tests/_fake_ui.rb`); add `FakeInstancePath` (delegate to `tests/_fake_instance_path.rb`). |
| `extension/preflight_runner.rb` (other) | **No behavioral change** to the existing preflight logic. |
| `tests/runner.rb` | No change. |
| `CURRENT_STATE.md` | Update only after the Stage 6 plan is approved (per Codex NIT). |

### 4.3 What is NOT being added

Same as v3. Plus:

- No `core/structural_depth_facts` (or equivalent) inside
  `compatibility/su_capability.rb` (per NIT).

### 4.4 Module diagram (revised — NIT)

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
                  │   (host probes only; +find_entity_by_id)     │
                  ├──────────────────────────────────────────────┤
 core/            │                                              │
  (pure Ruby,     │   structural_facts.rb       (A)  NIT helper  │
   NO Sketchup::, │   issue_registry.rb         (A)              │
   NO UI::,       │   issue_id_assigner.rb      (A)              │
   NO Geom::,     │   issue_enricher.rb         (A)              │
   NO compat/,    │   issue_normalizer.rb       (A)              │
   NO extension/) │   issue_grouper.rb          (A)              │
                  │   analysis_result.rb        (A)              │
                  │   issue_locator_policy.rb   (A)              │
                  │                                              │
                  │   … edge_record.rb, source_reference.rb      │
                  │     (+structural_depth, +pid_path_complete,  │
                  │      explicit construction required — NIT),   │
                  │     preflight.rb, geometry_snapshot.rb, etc. │
                  └──────────────────────────────────────────────┘
```

The lint `tests/test_core_no_host_dependency.rb` enforces the lower
boundary: any new `core/*.rb` file with a `Sketchup` / `UI` / `Geom`
/ `compatibility` / `extension` reference is a hard FAIL.

## 5. Runtime flow (revised — one snapshot, one explicit index)

Same as v3. The snapshot_lookup is built explicitly in
`analyzers_runner.rb`. The structural fields are appended to
`SourceReference` during the walk loop in `preflight_runner.rb`.

## 6. Critical implementation rules

### 6.1 NO overlay / NO mutation enforcement (R003 hard prohibition)

Strategy — three layers, same as v3.

**Per NIT clarification**: the recursive fingerprint (step N in
Owner Verification) is a **geometry/count fingerprint**. It does
NOT prove absence of property-only mutations (material / layer /
hidden / soft / dictionary). The `test_no_overlay_lint` is the
additional guard against forbidden mutation tokens; real-host
behavior evidence is the final check. The Owner Verification
step N renames its claim accordingly.

### 6.2 Capability fallback (R002 / R003 Q3.2)

Same as v3.

### 6.3 Locate policy (S6-PLAN-BLOCK-001 v4 + BLOCK-003)

Six profiles (revised):

| profile | nested | pid_path_complete | pid_path | entity_id | target descriptor |
|---|---|---|---|---|---|
| complete-root | false | true | `[leaf_pid]` (size 1) | any | `{kind: :inst_path_leaf, pid_path: token.pid_path}` |
| complete-nested | true | true | `[c, ..., leaf_pid]` (size>1) | any | `{kind: :inst_path_root, pid_path: token.pid_path}` |
| incomplete-root | false | false | `[]` | non-nil | `{kind: :entity_id, entity_id: token.entity_id}` |
| incomplete-nested-partial-leaf | true | false | `[leaf_pid]` only | any | `skip — non-locatable` |
| incomplete-nested-partial-ancestry | true | false | `[]` | any | `skip — non-locatable` |
| fully-missing | n/a | n/a | `[]` | nil | `skip — non-locatable` |

The `entity_id` fallback path is restricted to `nested == false`
AND `pid_path_complete == false` AND `entity_id != nil`. For any
nested source, regardless of pid_path shape, the source is
non-locatable (entityID alone cannot pick the correct shared
component occurrence; partial `[leaf_pid]` can resolve to the
wrong definition edge).

**Six required test cases** (per §7 + Codex Review 013 Q4):

1. `complete-root [leaf_pid]` (size 1) → `target == inst_path.leaf`
2. `complete-nested [container, leaf_pid]` (size>1) → `target == inst_path.root`
3. `incomplete-root [] + entity_id` → `target == model.find_entity_by_id(entity_id)`
4. `incomplete-nested-partial-leaf [leaf_pid]` (nested=true, complete=false) → unresolved, NEVER entityID fallback
5. `incomplete-nested-partial-ancestry []` (nested=true, complete=false) → unresolved, NEVER entityID fallback
6. `fully-missing [] entity_id=nil` → unresolved

Cases 4 and 5 must never use entityID fallback and must never be
treated as root.

Algorithm in `extension/issue_locator.rb`:

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

### 6.4 HtmlDialog lifecycle (Codex BLOCK-004, closed)

Same as v3.

### 6.5 Issue ID determinism (R005)

Same as v3. `entity_id` is NEVER used.

### 6.6 Group ordering (R005 + Codex Q1 answer)

Same as v3.

### 6.7 Summary header

Same as v3.

### 6.8 Ruby 2.2.4 syntax discipline

Same as v3.

### 6.9 JS contract discipline

Same as v3.

### 6.10 Error handling (PI_TASK_001 §18)

Same as v3.

## 7. Test matrix (target ~140+ new tests, ~210+ total)

The 6 mandated locator policy tests are listed in §6.3 explicitly.
The test count is a soft target, not a hard requirement.

| Suite | Tests | What's covered |
|---|---|---|
| `test_issue_registry` | ~12 | validation, tolerant drop, determinism, grouping, summary, empty-registry |
| `test_issue_id_assigner` | ~6 | stability, fallback, no `object_id` / no `entity_id` |
| `test_issue_enricher` | ~10 | aligned tokens, missing-edge diagnostic, whole-token dedup, structural identity preserved across traversal variations |
| `test_issue_normalizer` | ~12 | per-type mapping, preflight warning → Issue, severity String end-to-end |
| `test_issue_grouper` | ~6 | group order, count, default_open per Q1 |
| `test_analysis_result` | ~6 | no public setters, frozen top-level, frozen-diagnostics assertion |
| `test_issue_locator_policy` | ~12 | 6 profile targets, no host deps |
| `test_structural_facts` | ~6 | expected_pid_count + pid_path_complete helper (NIT support) |
| `test_core_no_host_dependency` | ~6 | no `Sketchup` / `UI` / `Geom` / `compatibility` / `extension` tokens in new core files |
| `test_issue_locator` | **6 mandated by BLOCK-001 v4 / Q4** | (1) complete root, (2) complete nested, (3) incomplete-root + entityID, (4) nested-partial-leaf, (5) nested-partial-ancestry, (6) fully-missing; plus two-source, erased |
| `test_analyzers_runner` | ~8 | one snapshot per command, explicit snapshot_lookup, registry build |
| `test_loader` | ~6 | idempotent registration across reloads, empty/unsupported selection handling |
| `test_dialog_runner` | ~10 | set_file absolute path, ready handshake, callback rebind on reopen, JSON.execute_script, no model mutation |
| `test_ui_bridge` | ~6 | Symbol → JSON String conversion at boundary, no SU types, escaping for JSON |
| `test_display_unit_formatter` | ~4 | `Sketchup.format_length` integration + non-SU fallback |
| `test_html_render` | ~8 | no `eval`, no `innerHTML` for user-supplied strings, JS source parses |
| `test_no_overlay_lint` | ~5 | `Ripper.lex` scan, comment/string stripping, zero forbidden tokens |
| `test_ruby_22_syntax_sweep` | 1 | 30+ files, 0 syntax issues |

## 8. Sub-stage breakdown + Codex review round plan (consolidated)

| Gate | Sub-steps | Codex review round | Verdict target |
|---|---|---|---|
| **Gate A — Core contract** | `core/structural_facts.rb`, `core/issue_registry.rb`, `core/issue_id_assigner.rb`, `core/issue_enricher.rb`, `core/issue_normalizer.rb`, `core/issue_grouper.rb`, `core/analysis_result.rb`, `core/issue_locator_policy.rb` + 8 test files + `test_core_no_host_dependency` + modifications to `core/source_reference.rb` (explicit construction) | Round 014 | All BLOCK-001 v4 sub-issues CLOSED |
| **Gate B — Host-side integration** | `extension/issue_locator.rb`, `extension/display_unit_formatter.rb`, `extension/loader.rb`, `extension/analyzers_runner.rb`, `extension/dialog_runner.rb`, `extension/dialog_controller.rb`, `extension/ui_bridge.rb`, `extension/html/*`, `tests/_fake_ui.rb`, `tests/_fake_instance_path.rb`, `Review/OWNER_VERIFICATION_STAGE_6.txt` (revised v2) + 6 test files + lint extensions + modifications to `extension/preflight_runner.rb` (structural-depth + pid_path_complete tracking) + `compatibility/su_capability.rb` (find_entity_by_id wrapper) | Round 015 | All BLOCK-002 / 003 / 004 + VERIFY-001 v2 sub-issues CLOSED |

After Gate B passes, Owner Verification Stage 6 runs on
SketchUp 2020 (per Q002=A), then SU2017 (per R004, release Gate).

## 9. Risks (graded by Codex severity)

Same as v3 plus the v4-locator risks:

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `UI::HtmlDialog` API drift in newer SU | Low | Medium | Capability probe is `defined?`-based; `test_no_overlay_lint` keeps the call surface narrow. |
| `model.active_path` returns a non-Array in some edge case | Low | Low | Already covered by S2-BLOCK-002 round 3 fix; `test_analyzers_runner` re-probes. |
| Selection callback race when Owner clicks 2 issues in rapid succession | Low | Low | UI is single-threaded by SU's design; click handler is idempotent. |
| HtmlDialog shows but does not register `add_action_callback` due to a SU bug | Very Low | Medium | `test_dialog_runner` asserts the callback registration happens. |
| Owner closes the model while the dialog is open | Low | Low | `set_on_closed` handler releases controller. |
| CSS / layout regression on SU2017 | Medium | Low | No CSS feature newer than 2017. |
| JS bridge exposes a method that mutates | Low | High | `test_html_no_mutation` whitelists allowed types. |
| Asset path is relative → CSS/JS unresolvable | Medium | High | `set_file(absolute_path)` with `File.expand_path`. |
| `InstancePath` accidentally passed to `Selection#add` | Low | High | `test_issue_locator` asserts only Entities. |
| Snapshot double-build (run twice) | Low | Medium | `test_analyzers_runner` asserts one snapshot per command. |
| Menu item duplicates on Ruby reload | Low | Low | `loader.rb#register!` idempotent. |
| Source token alignment lost in enrichment | Low | High | `test_issue_enricher` asserts positional alignment. |
| Empty-root entityID fallback picks wrong occurrence | Low | High | Restricted to `nested == false` + `pid_path_complete == false` + `entity_id != nil`. |
| Nested source with `[leaf_pid]` only mis-treated as root-leaf | Low | High | `pid_path_complete` covers leaf PID per v4. |
| Root-leaf PID missing, path `[]`, entityID present | Low | High | Covered by case 4 (incomplete-root) of the v4 locator profile. |
| Container PIDs present, leaf PID missing | Low | High | Covered by case 5 (incomplete-nested-partial-leaf). |
| Property-only mutation (material/layer/hidden) | Low | Medium | `test_no_overlay_lint` + real-host behavior evidence complement the geometry/count fingerprint. |

## 10. Open questions answered by Codex (Q1-Q6)

Same as v3.

## 11. Owner Verification Stage 6 (per VERIFY-001 v2)

The revised checklist is in `Review/OWNER_VERIFICATION_STAGE_6.txt`
(supersedes v1 draft). 5 steps J..N corrected to:

- **Corrected K.7 (dangling fixture)**: `dangling` is a Group containing
  an Edge. Its Edge is structurally nested (`structural_depth > 0`),
  not root-level. Both endpoint Issues share one source Edge and
  Locate selects the root Group occurrence.
- **Corrected outer_g (Nest fixture K.6)**: the L-shape has two
  end vertices of degree 1, so OpenEndpointDetector emits 2
  open-endpoint Issues alongside the deep-nesting warning. The
  expected counts in K.6 are updated to include 2 open endpoints.
- **Corrected M.8 (post-erase behavior)**: erasing the only Edge
  in `dangling` leaves the Group empty (no edges); the next
  analysis accepts the defined "no analyzable geometry" fallback
  (or shows zero Issues, depending on the analyzer contract).
  Expected: `Open endpoints: 0` after re-open.
- **Corrected L.1 (duplicate tokens)**: both tokens are nested
  definition-edge occurrences; remove "root + nested leaf" wording.

## 12. Self-imposed constraints (mirroring Stage 2)

Same as v3.

## 13. CURRENT_STATE.md update timing (per Codex NIT)

Same as v3.

## 14. Out of scope (V1.0 / V1.1+)

Same as v3.

## 15. Summary for Codex (revised v4)

Stage 6 is split into **2 gates**:

- **Gate A** — Core contract: 8 core files + 8 test files +
  `test_core_no_host_dependency` + modifications to
  `core/source_reference.rb` (explicit construction — NIT). Codex
  Round 014.
- **Gate B** — Host-side integration: ~7 extension .rb + 3 html/css/js
  + 6 test files + `Review/OWNER_VERIFICATION_STAGE_6.txt` (v2) +
  lint extensions + modifications to `extension/preflight_runner.rb`
  + `compatibility/su_capability.rb` (find_entity_by_id). Codex
  Round 015.

The two narrow opens are addressed:

- **S6-PLAN-BLOCK-001 v4**: §3.2 / §3.10 / §6.3 redefine
  `pid_path_complete` to cover the **full path** including the leaf
  Entity PID. The invariant `expected_pid_count = structural_depth + 1`
  is enforced at the leaf yield. The locator profile table now has
  6 explicit cases including `incomplete-nested-partial-leaf` (the
  case the previous definition missed). `locatable` derivation
  handles all root-leaf scenarios. 6 mandated test cases listed
  in §7 / §6.3.
- **S6-VERIFY-BLOCK-001 v2**: §11 points to the revised
  `Review/OWNER_VERIFICATION_STAGE_6.txt` with all 4 corrections
  (K.7, outer_g, M.8, L.1) applied.

3 NITs addressed:
- The recursive fingerprint is renamed to a geometry/count
  fingerprint; it does NOT prove absence of property-only
  mutations (§6.1, §11).
- `structural_facts.rb` is the new home for pid_path_complete
  arithmetic; `SUCapability` stays focused on host probes (§4.1,
  §4.2).
- SourceReference defaults are NOT used in production; all
  construction is explicit at snapshot build time (§3.10, §4.2).
  Construction arg shape is tested by `test_source_reference.py`
  (NIT contract).

4 Questions answered:
- Q1: Yes, both incomplete nested profiles non-locatable, no
  entityID fallback.
- Q2: SUCapability acceptable for find_entity_by_id.
- Q3: Yes, active edit-path contributes to structural depth AND
  path completeness; leaf PID included.
- Q4: Yes, FakeSU can simulate missing intermediate/container PID;
  the inverse missing-leaf case is also added (case 4) per
  Codex Review 013 Q4.

Awaiting Codex verdict on Round 014 (Gate A start authorization).
