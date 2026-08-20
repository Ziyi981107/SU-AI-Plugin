# V1.1 Layer Semantic Mapping — Progress Report (2026-08-20)

Stage status: **IMPLEMENTATION COMPLETE** (5 of 5 implementation
commits landed; Owner Gate 2 V1.1 checklist drafted; awaiting
Owner Gate 2 V1.1 evidence on real SU2020, then CodeX end-of-stage
review packet per plan §13).

Author: Coding Agent (Mavis)
Branch: `v1.1-layer-semantic-mapping` (cut from
`v1.0-candidate-2026-08-19` at commit `56ea611`)
Plan: `Review/V1_1_LAYER_SEMANTIC_MAPPING_PLAN_2026-08-19.md` (864 lines,
all 10 ChatGPT scope/policy questions answered, R007..R012 locked)

## What landed in this session (5 implementation commits)

| Commit | Scope | Files |
|---|---|---|
| `460037c` | Pure Ruby data layer | `core/layer_role.rb` (NEW), `core/layer_role_config.rb` (NEW), `core/layer_record.rb` (extend), `core/source_reference.rb` (extend), `tests/test_layer_role.rb` (NEW), `tests/test_layer_role_config.rb` (NEW), `tests/test_layer_record_extend.rb` (NEW), `tests/test_source_reference_layer_name.rb` (NEW) |
| `a2b05df` | Mapper + grouper | `core/layer_semantic_mapper.rb` (NEW), `core/layer_issue_grouper.rb` (NEW), `tests/test_layer_semantic_mapper.rb` (NEW), `tests/test_layer_issue_grouper.rb` (NEW) |
| `4e626d3` | SUCapability + preflight integration | `compatibility/su_capability.rb` (extend with `layer_visibility`), `core/geometry_snapshot.rb` (add `:layers` reader), `extension/preflight_runner.rb` (populate `layers:`, capture `layer_name` per edge), `tests/test_su_capability_layer_visibility.rb` (NEW) |
| `ef9ae04` | Analyzers runner + UI bridge | `core/analysis_result.rb` (extend with `layer_groups` kwarg + `layer_groups_payload`), `extension/analyzers_runner.rb` (extend with `inject_source_layer_name` + `LayerSemanticMapper.build`), `extension/preflight_runner.rb` (entity-aware visibility probe fix), `extension/ui_bridge.rb` (extend with `layerGroups` top-level key), `tests/_fake_su.rb` (extend with `FakeSU::Layer#visible?`), `tests/test_analyzers_runner.rb` (extend, 8 new V1.1 tests), `tests/test_ui_bridge.rb` (extend, 5 new V1.1 tests) |
| `823feab` | UI render for the Layers section | `extension/html/index.html` (extend with `<details id="layers-section">` + `<summary id="layers-summary">` + `<div id="layers-list">`), `extension/html/app.js` (extend with `renderLayers`, `renderLayerRow`, locked `LAYER_ROLE_LABELS` (5 canonical, NO OFFSCREEN) + `LAYER_VISIBILITY_LABELS`), `extension/html/style.css` (extend with `.layer-row` neutral styles + `[data-visible="false"]` muted opacity, NO `data-role="..."` color selectors per R008), `tests/test_html_render.rb` (extend, 8 new L4 source-level guards), `tests/test_html_render_dom.js` (extend, 18 new L4 DOM tests) |

## Test results

**372/372 PASS, 0 fail, 0 error.**
- V1.0 baseline: 286 tests (unchanged, no regressions).
- V1.1 additions: 86 tests (this report's session totals all 5
  commits; see previous progress report `2026-08-19` for commit-
  by-commit breakdowns).
- `git diff --check` clean on all 5 commits.
- `dist/SU-AI-Plugin.rbz` rebuilt locally (gitignored, not
  committed) at the end of commit 5 — 214,776 bytes, 41 entries.
  The .rbz now ships the locked `layer_groups` integration and
  the locked L4 DOM/CSS/JS contract from plan §4.10..§4.12.

## What is still pending (post-implementation)

| Step | Owner | Description |
|---|---|---|
| Gate 2 V1.1 | Owner (Cicada) | Run `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt` on real SU2020. The checklist re-runs V1.0 steps J,K + adds V1.1-specific L1..L9 steps (Layers section, role + visibility independence, hidden-layer muted style, role bucket order, no role color hints, default-closed summary, layer row non-actionable, fingerprint non-mutation). Owner drops report to `Prompt/OWNER_REPORT_V1_1_LAYERS_2026-08-XX.txt` per the standard handoff convention. |
| CodeX end-of-stage review | CodeX (per plan §13) | One consolidated review packet after the Agent's 5 commits + Gate 2 V1.1 evidence land. Packet contents: this plan + base/head (commit `56ea611`..`823feab`) + changed files manifest + 372/372 test results + Owner Gate 2 V1.1 report + §12 self-defaults + known risk + NO request to re-open V1.0 scope (CodeX 020 / RBZ / CodeX 024 / Stage 6 are explicitly out of scope). |
| Formal release | Owner (Cicada) | Combine V1.0 + V1.1 in the .rbz and rerun Gate 1 (SU2017) + Gate 2 (V1.1 owner report) on the final RBZ. Per R006, Gate 1 is deferred to formal release; V1.1 ships with Gate 1 PENDING. |

## Locked decisions (incorporated into the implementation)

- **R007** — Role and visibility are SEPARATE fields. The `OFFSCREEN`
  role Symbol is REMOVED. 5 name-based roles only
  (`:dimension`, `:annotation`, `:guide`, `:construction`, `:unknown`).
- **R008** — No role color hints. Roles use text + neutral badge.
  The V1.0 issue severity palette is NOT reused for roles.
- **R009** — Layer display order = role bucket order
  `[dim, anno, guide, construction, unknown]`. Hidden layers sort
  LAST within each role bucket (with `opacity: 0.6` muted style in
  the UI, per ChatGPT §11.2).
- **R010** — `LayerRoleConfig.classify` evaluates rules in DECLARED
  order; first match wins (top-down-by-priority, NOT by-specificity).
  Test pin: a layer matching two rules gets the FIRST rule's role.
- **R011** — `SUCapability.layer_visibility` returns
  `:visible | :hidden | :unknown`. The caller maps `:unknown` to
  `LayerRecord(visible: true, visibility_unknown: true)` —
  operational fallback is visible, but the data model preserves
  the uncertainty. We do NOT fake `:hidden` when the answer is
  "I don't know".
- **R012** — Role order is INDEPENDENT from
  `IssueRegistry::DEFAULT_GROUP_ORDER`. Locked role order:
  `[dimension, annotation, guide, construction, unknown]`.

## Reviewer routing (per Cicada 2026-08-19)

- **ChatGPT** — already answered all 10 plan-level questions (Q1..Q10).
- **Agent self** — implemented all 5 commits (commits 1+2 by the
  prior 2026-08-19 session; commits 3, 4, 5 by this session).
- **CodeX end-of-stage** — engages ONLY when all 5 commits +
  Gate 2 V1.1 Owner evidence land. Packet contents per plan §13.

## Risks and known issues

1. **Parked WIP file** (cleaned up in this session): the
   previously-parked
   `data/_check_tmp/_WIP_test_preflight_runner_layer.rb` was a
   stub that ran into Ruby metaprogramming gotchas during
   commit 3; not needed for the 372/372 PASS result because
   `tests/test_su_capability_layer_visibility.rb` + the V1.1
   FakeSU::Layer#visible? extension already cover the
   visibility contract. The file remains in `data/_check_tmp/`
   (gitignored) as a future-work stub if Owner wants layer-
   level tests later.

2. **Preflight_runner layer visibility probe fix** (commit 4
   NIT fix): the original commit-3 implementation stored
   `layer_obj = entity.layer` in `layer_aggregates[name][:layer_obj]`
   and passed it to `SUCapability.layer_visibility(layer_obj)`.
   That was a contract mismatch — `layer_visibility` is the
   entity-as-input adapter, so the stored value needs to be
   the entity (NOT the layer). Commit 4 stores `entity` instead
   and probes via the entity-aware path. Without this fix,
   FakeSU::Layer (no `.layer` method) was falling back to
   `:unknown` for ALL layers, surfacing `visibility_unknown: true`
   on the closed-square L0 layer (the test that initially
   failed). The fix is in
   `extension/preflight_runner.rb#build_layer_records`; the
   commit message documents it as a NIT-driven contract
   correction, NOT a behavior change on real SU (real SU
   layers respond to `.layer` correctly).

3. **RBZ is gitignored** (`*.rbz` in `.gitignore`). The local
   `dist/SU-AI-Plugin.rbz` (214,776 bytes, 41 entries) is
   rebuilt at the end of commit 5. CodeX end-of-stage will
   validate the package structure on the .rbz assembled from
   the V1.1 branch head.

4. **No git remote configured** on this machine. Network
   `git ls-remote https://github.com/...` returns
   "Connection was reset". The 5 V1.1 commits are local in
   `D:\Projects\SU-AI-Plugin\.git`. Owner (Cicada) will need to
   push manually from a connected machine, or provide a remote
   URL with credentials for the next Agent session to push.

5. **Gate 1 (SU2017) remains PENDING per R006** — Cicada
   (2026-08-19) deferred this to formal release. Not a V1.1
   blocker; the V1.1 candidate will be released with Gate 1
   still PENDING, and the formal release re-runs Gate 1 +
   Gate 2 against the final RBZ.

6. **`LayerIssueGrouper` integration deferred**: the commit
   1+2 implementation built
   `SUAnalysis::Core::LayerIssueGrouper` (groups issues by
   source[:layer_name]) but the V1.1 UI does not yet render
   "issues grouped by layer" buckets. The per-layer `issue_count`
   surfaced in the layer row is the only V1.1 consumer. The
   grouper is a forward-compatibility hook for a future
   "V1.1.1" stage that wants a "Issues by Layer" <details>
   block. Per plan §4.5 it is a NEW pure-Ruby module with no
   UI consumption contract yet.

## Owner action required right now

- **Gate 2 V1.1 Owner verification** —
  `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt`. Steps
  L1..L9 cover (1) V1.0 baseline unchanged, (2) Layers section
  visible, (3) multi-layer role bucket order, (4) hidden layer
  muted + bucket-interior sort, (5) `issue_count > 0` gets
  `.has-issues` emphasis, (6) NO role color hints, (7) summary
  pre-populated + default-closed, (8) layer row non-actionable,
  (9) PRE/POST fingerprint byte-identical.

## CodeX review required right now

- **Yes — end-of-stage** (per plan §13 + Cicada 2026-08-19
  routing). After Owner reports Gate 2 V1.1 PASS, the Agent
  dispatches ONE consolidated CodeX end-of-stage packet with
  this branch's full diff (commits `56ea611`..`823feab`),
  372/372 test results, Gate 2 V1.1 Owner report, plan §12
  defaults with any deviations documented, plus §8 known risks.
  Reopening already-passed V1.0 scope (Stage 6, CodeX 020,
  RBZ structure, CodeX 024) is EXPLICITLY out of scope per the
  packet contract; the packet does NOT request a re-review.

