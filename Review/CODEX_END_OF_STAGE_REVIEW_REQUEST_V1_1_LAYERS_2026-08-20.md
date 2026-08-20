# CodeX End-of-Stage Review Request — V1.1 Layer Semantic Mapping

**Branch**: `v1.1-layer-semantic-mapping`
**Base (V1.0 freeze)**: `56ea611` (tag `v1.0-candidate-2026-08-19`)
**Implementation base** (last commit BEFORE the 5 V1.1 commits): `4206e78` (V1.1 plan v3 FINAL)
**Implementation head**: `823feab` (commit 5 of 5)
**Post-NIT-fix head**: `HEAD` of the branch (the 5 implementation commits + the docs checkpoint + the 2 NIT-fix commits + this handoff commit)
**Plan**: `Review/V1_1_LAYER_SEMANTIC_MAPPING_PLAN_2026-08-19.md` (864 lines)
**Owner Gate 2 V1.1 evidence**: `Prompt/OWNER_REPORT_V1_1_LAYERS_2026-08-20.txt`

When CodeX runs the review, the current `HEAD` of `v1.1-layer-semantic-mapping` is the post-NIT-fix head. The branch was cut from `4206e78`; the diff to review is `4206e78..HEAD` (the 5 V1.1 implementation commits + the docs checkpoint + the 2 NIT-fix commits + this handoff commit). For pure implementation review, use `4206e78..823feab`. For post-NIT-fix verification, use `823feab..HEAD`.

| Order | Commit | Subject |
|---|---|---|
| (V1.0 freeze) | `56ea611` | docs(state): 2026-08-19 agent handoff + active baseline block |
| (plan drafts) | `7d08b82`, `e8e14e0`, `cd94e1e`, `4206e78` | V1.1 plan DRAFT v1/v2/v3 FINAL + R006 routing rule |
| Implementation 1 | `460037c` | feat(v1.1): pure Ruby layer data layer + V1.1 extension to existing records |
| Implementation 2 | `a2b05df` | feat(v1.1): LayerSemanticMapper + LayerIssueGrouper (pure Ruby) |
| Implementation 3 | `4e626d3` | feat(v1.1): SUCapability.layer_visibility + preflight layer population (R007/R010/R011) |
| Implementation 4 | `ef9ae04` | feat(v1.1): AnalyzersRunner.layer_groups + UIBridge.layerGroups (commit 4) |
| Implementation 5 | `823feab` | feat(v1.1): UI render for Layers section + locked L4 DOM/CSS/JS contract (commit 5) |
| (docs checkpoint) | `788e462` | docs(checkpoint): V1.1 IMPLEMENTATION COMPLETE — wait for Owner Gate 2 V1.1 |
| NIT-1 | (commit A) | fix(v1.1): layer-row separator + plural form (per Gate 2 V1.1 NIT 1) |
| NIT-2 | (commit B) | docs(checkpoint): OWNER_VERIFICATION V1.1 fixture NITs 2a/2b/2c |
| (handoff) | (commit C — this commit) | docs(handoff): Owner Gate 2 V1.1 PASS-WITH-NIT report + CodeX end-of-stage packet |

---

## 1. Scope of this packet

This is **ONE consolidated end-of-stage review** per V1.1 plan §13 + the
Cicada 2026-08-19 reviewer-routing rule. CodeX is engaged ONCE for the
whole V1.1 Layer Semantic Mapping stage — implementation + NIT-fix
follow-ups + Owner Gate 2 V1.1 evidence — and is **not** asked to revisit
any V1.0 / Stage 6 / earlier CodeX round.

The packet EXPLICITLY does **not** request a re-review of:
- V1.0 Stage 6 (CodeX 009 / CodeX 020 closed)
- V1.0 RBZ package + root loader (CodeX 022 / CodeX 024 closed)
- Any V1.0 fence (286-test baseline, capability probe, IssueRegistry)
- Any V1.0 Owner verification (already PASS on SU2020, see
  `Review/OWNER_VERIFICATION_STAGE_6.txt` and
  `Review/OWNER_VERIFICATION_RBZ_INSTALL_2026-08-19.txt`)

If the CodeX reviewer wants to inspect those files for context, they
are linked in the references section, but no verdict is requested on
them.

---

## 2. Diff manifest

### 2.1 Implementation (commits 1..5, base → `823feab`)

`git diff --stat 4206e78..823feab` covers the implementation surface
(27 files, + 2,297 / - 33 net, before the docs checkpoint). The new V1.1
files (production + tests):

| Area | New files |
|---|---|
| Pure Ruby data layer | `core/layer_role.rb`, `core/layer_role_config.rb` |
| Mapper + grouper | `core/layer_semantic_mapper.rb`, `core/layer_issue_grouper.rb` |
| Capability + preflight | `extension/su_ai_plugin/compatibility/su_capability.rb` (`layer_visibility`), `extension/su_ai_plugin/preflight_runner.rb` (`build_layer_records`, per-edge `layer_name`) |
| Runner + bridge | `extension/su_ai_plugin/analysis_result.rb` (`layer_groups` kwarg), `extension/su_ai_plugin/analyzers_runner.rb` (`inject_source_layer_name` + `LayerSemanticMapper.build`), `extension/su_ai_plugin/ui_bridge.rb` (`layerGroups` top-level) |
| UI render | `extension/su_ai_plugin/html/index.html` (`<details id="layers-section">`), `extension/su_ai_plugin/html/app.js` (`renderLayers` + `renderLayerRow` + `formatCount` + `LAYER_ROLE_LABELS` (5 canonical, no OFFSCREEN, R007) + `LAYER_VISIBILITY_LABELS`), `extension/su_ai_plugin/html/style.css` (`.layer-row` neutral + `[data-visible="false"]` muted, NO role color hints, R008) |
| Tests | `tests/test_layer_role.rb`, `tests/test_layer_role_config.rb`, `tests/test_layer_record_extend.rb`, `tests/test_source_reference_layer_name.rb`, `tests/test_layer_semantic_mapper.rb`, `tests/test_layer_issue_grouper.rb`, `tests/test_su_capability_layer_visibility.rb`, `tests/test_analyzers_runner.rb` (8 new), `tests/test_ui_bridge.rb` (5 new), `tests/test_html_render.rb` (8 new + L4 separator guard), `tests/test_html_render_dom.js` (18 new + plural + separator), `tests/_fake_su.rb` (`FakeSU::Layer#visible?`) |
| Extends | `core/layer_record.rb`, `core/source_reference.rb` (`layer_name:` kwarg), `core/geometry_snapshot.rb` (`:layers` reader) |

### 2.2 NIT-fix follow-ups (after Owner Gate 2 V1.1)

Two follow-up commits land on top of `823feab`:

- `fix(v1.1): layer-row separator + plural form (per Gate 2 V1.1 NIT 1)`
  - Adds `formatCount(n, noun)` helper in `app.js` (singular vs plural).
  - Adds a real `.layer-count-sep` DOM node carrying middle-dot "·"
    between the edge and issue counts. Rendered row text now reads
    `4 edges · 0 issues` visually (with the existing `gap: 8px` flex
    layout separating the spans).
  - Adds `.layer-row .layer-count-sep` CSS rule (muted, font-size 11px).
  - Test updates:
    - `tests/test_html_render_dom.js`: L4.3 exact-match on `4 edges`
      and `1 issue`; L4.3.1 separator DOM check + joined-child-text
      check; L4.4.1 plural correctness for n=0/1/2.
    - `tests/test_html_render.rb`: L4 source-level guard for
      `.layer-row .layer-count-sep` CSS rule presence.

- `docs(checkpoint): OWNER_VERIFICATION V1.1 fixture NITs 2a/2b/2c`
  - `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt` setup
    helper rewritten with a `make_rect(entities, layer, x, y)` helper
    that builds a 4-edge closed rectangle and explicitly assigns the
    named layer to each of the four edges (NIT 2a: per-edge
    assignment, no group-only inheritance).
  - Hidden layer renamed from `TXT-HIDDEN` to `TXT-LABEL-HIDDEN` so it
    matches the Annotation regex `/(anno|t?ext|label)/i)` via the
    `label` alternation (NIT 2b: it was mis-classifying as `:unknown`
    and breaking L4).
  - Each V1.1 fixture switched from a single edge (which produces
    2 Open Endpoint issues) to a closed rectangle (NIT 2c: the
    "0 issues" assertion is now meaningful).
  - L3 / L4 / L5 step descriptions updated to reference the new
    fixture names and the closed-rectangle shape; "1 edge" → "4 edges";
    "0 issues" cell now described with the new "4 edges · 0 issues"
    expected text including the middle-dot separator.

### 2.3 Locked contract references

- R007 (ChatGPT §11.3): role vs visibility are SEPARATE fields; the
  `OFFSCREEN` role Symbol is REMOVED; 5 name-based roles only.
- R008 (ChatGPT §11.7): no role color hints in V1.1; roles use text +
  neutral badge; severity palette NOT reused for roles.
- R009 (ChatGPT §11.2): layer display order = role bucket order;
  hidden layers LAST within each role bucket (with `opacity: 0.6`).
- R010 (ChatGPT §11.8): rule ordering is top-down-by-priority; first
  match wins (test pin: a layer matching two rules gets the FIRST
  rule's role).
- R011 (ChatGPT §11.9): `layer_visibility` returns
  `:visible | :hidden | :unknown`; caller maps `:unknown` to
  `visible: true, visibility_unknown: true` (data-model preserves
  uncertainty, operational fallback is visible).
- R012 (ChatGPT §11.10): role order is INDEPENDENT from
  `IssueRegistry::DEFAULT_GROUP_ORDER`; locked role order
  `[dimension, annotation, guide, construction, unknown]`.

---

## 3. Test results

```
Ruby 2.7.8p225, tests/run_all.rb
  V1.0 baseline: 286 tests PASS (unchanged, no regressions)
  V1.1 additions: 86 tests PASS
  Total: 372 tests PASS, 0 fail, 0 error
```

The Node.js DOM test (`tests/test_html_render_dom.js`, 67 assertions)
runs `PASS` and is called from the Ruby suite
(`tests/test_html_render.rb`).

`git diff --check` clean on all V1.1 + NIT-fix commits.

`dist/SU-AI-Plugin.rbz` rebuilds locally (gitignored, not committed)
and ships:
- 41 entries / 214,776 bytes (pre-NIT-fix head `823feab`); the
  post-NIT-fix head rebuilds to the same shape (same file set;
  only `app.js` / `style.css` text changed, and the two test files
  are not shipped).

The `data/` directory is in
`scripts/build_rbz.rb EXCLUDED_TOP_LEVEL`, so WIP files in
`data/_check_tmp/` are not shipped.

---

## 4. Owner Gate 2 V1.1 evidence

`Prompt/OWNER_REPORT_V1_1_LAYERS_2026-08-20.txt` — Owner dropped the
real-SU2020 Gate 2 V1.1 evidence at this exact path. Headline:

> **Verdict: PASS WITH NIT** on real SketchUp 2020.
> V1.0 baseline (L1): unchanged.
> L2..L9 (V1.1-specific): PASS on the pre-NIT-fix head `823feab`.
> Three NITs observed; all three FIXED in this branch.
> Owner collected evidence on the pre-NIT-fix head; Agent requests
> a brief re-verification on top of the NIT-fix head (optional,
> covered by the automated L4 source-level guard tests).

The Owner checklist `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-
20.txt` was re-issued in the NIT-fix commit with the corrected
fixtures and updated step descriptions.

---

## 5. Agent self-defaults (V1.1 plan §12)

§12 of the V1.1 plan asked the Agent to decide two contained code-
architecture questions with documented defaults. The Agent's
decisions (and where they landed):

1. **`SourceReference` extension shape**:
   - Decision: add a `layer_name:` kwarg to `SourceReference.new`;
     do NOT add a new `SourceLayer` class.
   - Rationale: per-edge `layer_name` is a derived string from
     `entity.layer.name`; a separate class would have one field and
     one consumer, which is overkill. The kwarg is required
     (defaults to `nil`), forcing the producer to think about
     presence/absence.
   - Locked test: `tests/test_source_reference_layer_name.rb`.

2. **`LayerIssueGrouper` first-seen-wins dedup policy**:
   - Decision: when the same layer name shows up in multiple
     `Issue.source[:layer_name]` references, count it once for
     the `M with issues` summary count and once per occurrence
     for the per-layer `issue_count` (a layer with 3 issues is
     still 1 layer with issues, but with 3 issues on it).
   - Rationale: matches Owner intuition; matches `summary.issues`
     semantics. Tested by `tests/test_layer_issue_grouper.rb`.

These defaults were documented in the plan §12 + Locked Decisions
block; no deviation in the implementation.

---

## 6. Known risks (V1.1 plan §8)

1. **LayerIssueGrouper UI integration deferred**: the commit-2 pure-
   Ruby grouper is built but not yet consumed by any UI surface. It
   is a forward-compatibility hook for a future "V1.1.1" stage that
   wants an "Issues by Layer" `<details>` block. Per plan §4.5 the
   API is locked; UI integration is intentionally deferred. **NOT a
   V1.1 blocker.**

2. **No git remote configured**: `git ls-remote` returns "Connection
   was reset". The 5 V1.1 commits + 2 NIT-fix commits are local in
   `D:\Projects\SU-AI-Plugin\.git`. Owner will need to push from a
   connected machine, or provide a remote URL with credentials.
   **NOT a V1.1 blocker.**

3. **Gate 1 (SU2017) remains PENDING per R006** — Cicada 2026-08-19
   deferred Gate 1 to formal release. The V1.1 candidate ships with
   Gate 1 still PENDING. Formal release must re-run Gate 1 + Gate 2
   on the final RBZ artifact. **NOT a V1.1 blocker.**

4. **PRE/POST fingerprint test on real host is Owner-run, not
   automated**: the fingerprint helper is provided as a Ruby snippet
   in `OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt`. The Agent
   cannot run real-SU from this environment. The 372/372 PASS suite
   covers the data-layer contract; the Owner covers the host
   contract.

5. **Parked WIP file `** : the file
   `data/_check_tmp/_WIP__WIP_test_preflight_runner_layer.rb` is a
   gitignored stub from a commit-3 metaprogramming detour. The
   372/372 PASS result is achieved without it; the file is retained
   only as a future-work stub. RBZ shipping is confirmed WIP-free
   (`data/` is in `EXCLUDED_TOP_LEVEL`).

---

## 7. What CodeX is asked to do

ONE consolidated end-of-stage verdict on the V1.1 implementation
(`4206e78..823feab`) + the two NIT-fix follow-up commits + the
updated `OWNER_VERIFICATION` checklist + the Owner Gate 2 V1.1
report. The verdict must address:

1. **Implementation diff review** (the 5 V1.1 commits, base → `823feab`):
   - Code architecture follows the V1.1 plan §4 (Pure Ruby data
     layer → Capability → PreflightRunner → AnalyzersRunner → UIBridge
     → HTML render).
   - All 10 ChatGPT §11 questions answered; R007..R012 honored.
   - All 2 §12 self-defaults honored.
   - No re-opening of V1.0 fences.

2. **NIT-fix correctness review** (2 follow-up commits):
   - NIT 1 (separator + plural): the fix matches the Owner's stated
     expected output (`4 edges · 0 issues` with visible middle-dot
     separator; correct plural form).
   - NIT 2 (fixtures): the rewrite of the OWNER_VERIFICATION setup
     helper addresses all three Owner-flagged defects (per-edge
     layer assignment; rename to `TXT-LABEL-HIDDEN`; closed-rectangle
     shape).

3. **Locked contract review**:
   - R007 (5 canonical roles, no OFFSCREEN) — verify both
     `LAYER_ROLE_LABELS` in `app.js` and the test pinning.
   - R008 (no role color hints) — verify the CSS file's `.layer-row`
     blocks contain no `[data-role="..."]` color selectors.
   - R009 (role-bucket order + hidden-bottom) — verify the render
     path uses `LAYER_ROLE_LABELS` order and groups hidden layers
     last within each bucket.
   - R010 (first-match-wins) — verify the `LayerRoleConfig.classify`
     rules iteration.
   - R011 (visibility `:unknown` preserves uncertainty) — verify
     `LayerRecord(visible: true, visibility_unknown: true)` mapping.
   - R012 (role order independent of issue order) — verify the role
     array is hard-coded, not derived from `IssueRegistry::DEFAULT_GROUP_ORDER`.

4. **Test sufficiency**:
   - 372/372 PASS is the contract; nothing in the V1.1 diff should
     relax any V1.0 invariant.
   - The Node.js DOM test covers the visual layer-row render and the
     locked L4 source-level guards.
   - The L4.4.1 plural correctness test covers the NIT 1 fix.
   - The L4.3.1 separator test covers the NIT 1 fix.

5. **Out-of-scope guard**:
   - Do NOT raise BLOCKs against V1.0 fences (Stage 6 / CodeX 020 /
     RBZ / CodeX 024). If the reviewer finds a regression on those
     fences, mark it explicitly as "out of scope for V1.1 packet" so
     the Owner can route it as a separate V1.0 patch.

---

## 8. References

- V1.1 plan: `Review/V1_1_LAYER_SEMANTIC_MAPPING_PLAN_2026-08-19.md`
- V1.1 progress (pre-NIT-fix): `Review/V1_1_LAYER_SEMANTIC_MAPPING_PROGRESS_2026-08-19.md`
- Owner Gate 2 V1.1 evidence: `Prompt/OWNER_REPORT_V1_1_LAYERS_2026-08-20.txt`
- Owner Gate 2 V1.1 checklist (post-NIT-fix):
  `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt`
- V1.0 stage 6 owner evidence: `Review/OWNER_VERIFICATION_STAGE_6.txt`
- V1.0 RBZ install evidence:
  `Review/OWNER_VERIFICATION_RBZ_INSTALL_2026-08-19.txt`
- CURRENT_STATE.md (project memory):
  `CURRENT_STATE.md`
- AGENT.md (Agent playbook + Review/Prompt routing):
  `AGENT.md`

---

## 9. Sign-off

Once CodeX returns a verdict on this packet:
- **PASS** → Owner may run Re-Verification L4..L9 on top of the
  NIT-fix head (optional) and the V1.1 stage is closed on SU2020.
- **PASS WITH NIT** → Agent fixes the NITs in a follow-up commit;
  no new packet required unless the NIT is large.
- **BLOCK** → CodeX lists the BLOCK(s) explicitly; Agent addresses
  in a follow-up commit and dispatches a follow-up packet.

In all three cases, Gate 1 (SU2017) and the formal-release
combination of V1.0 + V1.1 RBZ remain Owner-run after the
end-of-stage review closes.

---

*End of CodeX end-of-stage review request for V1.1 Layer
Semantic Mapping.*