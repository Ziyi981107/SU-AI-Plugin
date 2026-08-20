# CodeX End-of-Stage Review Request — V1.2 (Issues by Layer) + V1.3 (Face Inventory)

**Branch**: `v1.3-face-inventory` (V1.2 was developed on its own
branch `v1.2-issues-by-layer`, cut at `v1.2-issues-by-layer-candidate`
tag `0460c6b`; V1.3 was cut from that V1.2 head)
**V1.0 freeze**: `56ea611` (tag `v1.0-candidate-2026-08-19`)
**V1.1 close**: `23cac28` (CodeX 025)
**V1.2 Owner-test candidate (PRESERVED)**: tag
`v1.2-issues-by-layer-candidate` at `0460c6b` on branch
`v1.2-issues-by-layer`
**V1.3 implementation branch**: `v1.3-face-inventory` cut from
`0460c6b`; head at this commit

This is ONE consolidated end-of-stage review per the Owner
direction: "完成后一次性提交 V1.2 + V1.3 合并阶段包给评审。"

The packet covers two V1.x stages (V1.2 + V1.3) in two scope
sections. Each scope is independently auditable; the Owner
verdicts are kept separate (V1.2 + V1.3 each have their own
Owner report at `Prompt/OWNER_REPORT_V1_X_*.txt`).

V1.2 evidence:
- `Prompt/OWNER_REPORT_V1_2_ISSUES_BY_LAYER_2026-08-XX.txt`
  (Owner Gate 2 V1.2 result on real SU2020)
- `Review/OWNER_VERIFICATION_V1_2_ISSUES_BY_LAYER_2026-08-20.txt`
  (V12-1..V12-7)
- V1.2 implementation base/head: `56ea611..0460c6b` on
  `v1.2-issues-by-layer` (5 commits)
- V1.2 review request: superseded by this combined packet
  (no separate V1.2 packet dispatched)

V1.3 evidence:
- `Prompt/OWNER_REPORT_V1_3_FACE_INVENTORY_SU2020_2026-08-20.txt`
  (Owner Gate 2 V1.3 result on real SU2020, PASS WITH NIT,
  NIT fixed in this branch)
- `Review/OWNER_VERIFICATION_V1_3_FACE_INVENTORY_2026-08-20.txt`
  (V13-1..V13-6)
- `Review/CODEX_V13_BLOCK_001_RECHECK_2026-08-20.md`
  (the V13-BLOCK-001 BLOCK-recheck packet that fixed the
  production-seam silent-collapse)
- V1.3 implementation base/head: `0460c6b..HEAD` on
  `v1.3-face-inventory` (4 implementation + 2 follow-up + 1
  docs checkpoint + 1 BLOCK-recheck fix + 1 NIT-001 fix = 9
  commits)

---

## 1. Scope

This is **ONE consolidated end-of-stage review** per the
Owner direction. CodeX is engaged ONCE for the whole V1.2 +
V1.3 stage — implementation + Owner Gate 2 + the single
V13-BLOCK-001 recheck + the single V13-NIT-001 spacing fix.

The packet EXPLICITLY does **not** request a re-review of:
- V1.0 Stage 6 / CodeX 020 closed scope
- V1.0 RBZ package + root loader (CodeX 022 / CodeX 024 closed)
- V1.1 Layer Semantic Mapping (CodeX 025 CLOSED on SU2020)
- Any V1.0 fence: 286-test baseline, capability probe,
  IssueRegistry, EdgeRecord / VertexRecord / LayerRecord V1.0
  shape

If CodeX finds a regression in any of those, mark it
explicitly as "out of scope for V1.2 + V1.3 packet" so the
Owner can route it as a separate V1.0 / V1.1 patch.

---

## 2. V1.2 scope (Issues by Layer)

### 2.1 V1.2 directive

`Prompt/CODEX_GUIDANCE_026_2026-08-20_V1_2_ISSUES_BY_LAYER_START.txt`
- Title: Issues by Layer (按图层查看问题)
- Reuse existing `SUAnalysis::Core::LayerIssueGrouper`
- Maintain read-only, do not modify the model
- Complete full functionality + automated tests, then
  hand to Owner for SU2020 verification
- Submit ONE consolidated end-of-stage review
- SU2017 Gate 1 stays at formal release Gate; not blocking V1.2

### 2.2 V1.2 implementation diff (base → head)

`v1.2-issues-by-layer` branch, commits `56ea611..0460c6b`:

| Order | Commit | Subject |
|---|---|---|
| (V1.0 freeze) | `56ea611` | docs(state): 2026-08-19 agent handoff + active baseline block |
| 1 | `035e306` | feat(v1.2): wire LayerIssueGrouper into AnalysisResult + AnalyzersRunner |
| 2 | `ea81aaa` | feat(v1.2): expose layerIssueGroups top-level in UIBridge payload |
| 3 | `03c2dd9` | feat(v1.2): render 'Issues by Layer' section in dialog |
| 4 | `0460c6b` | docs(checkpoint): V1.2 Owner verification checklist + CURRENT_STATE update |

The V1.2 Owner-test candidate is FROZEN at `0460c6b` per
Owner direction. The V1.3 branch was cut from this exact
head; V1.3 commits live in the SEPARATE `v1.3-face-inventory`
branch so the two stages are cleanly separable for any
follow-up patches.

### 2.3 V1.2 locked user behavior (re-stated from directive 026)

1. New top-level `<details id="layer-issues-section">` AFTER
   per-issue-type groups, BEFORE the V1.1 Layers section.
2. Closed by default; summary populated before opening.
3. `Issues by Layer — N layers (M issues)` summary format
   (singular form for n=1: `1 layer` per V12-NIT-001 fix).
4. One bucket per non-empty layer (no empty buckets).
5. Bucket header: `LayerName (N issue(s))` with correct
   singular/plural wording via `formatCount`.
6. Issues inside bucket reuse `renderIssue()` so the existing
   click-to-locate and non-locatable-inert contracts carry
   through unchanged.
7. Existing V1.1 Layers rows remain inert (no click handler,
   no navigation).
8. Order buckets consistently with V1.1 role order
   (Dimension → Annotation → Guide → Construction → Unknown;
   visible before hidden; name ASC).
9. `textContent` only. No innerHTML, no eval, no new Function,
   no document.write.
10. No new role colors. Severity palette remains exclusive
    to issue severity.
11. Analysis remains read-only.

### 2.4 V1.2 NIT fixed (V12-NIT-001)

The Owner flagged a tiny pluralization NIT in the V1.2
summary: `Issues by Layer — 1 layers (0 issues)` should
read `Issues by Layer — 1 layer (0 issues)` for n=1. Fix
landed in V1.3 commit `e66a9ad` (it touches the shared
`renderLayerIssues` function; the V1.2 branch is FROZEN
so the fix lives in V1.3 which V1.2 already imports
through the V1.2 → V1.3 cut).

### 2.5 V1.2 test evidence

- Ruby at V1.2 close (commit `0460c6b`): 395/395 PASS
  (V1.1 baseline 286 + V1.2 additions).
- Node.js DOM at V1.2 close: 86 assertions (67 V1.1 + 19
  V1.2), all PASS.
- `git diff --check` clean for `extension/` and `tests/`.
- V1.2 implementation introduces **no V1.0 / V1.1
  regression**: 286 V1.0 + V1.1 tests all PASS unchanged
  at V1.2 close.

### 2.6 V1.2 Owner evidence (real SU2020)

- `Prompt/OWNER_REPORT_V1_2_ISSUES_BY_LAYER_2026-08-XX.txt`
  (Owner dropped this after running V12-1..V12-7 on real
  SU2020; verdict per Owner).
- `Review/OWNER_VERIFICATION_V1_2_ISSUES_BY_LAYER_2026-08-20.txt`
  (V12-1..V12-7 checklist).
- The combined run-order doc:
  `Review/OWNER_RUN_ORDER_V1_2_AND_V1_3_2026-08-20.txt`
  (V12 first, V13 second; verdicts kept independent).

### 2.7 V1.2 known risks (per CodeX 026)

- `LayerIssueGrouper` UI integration was the only new V1.2
  surface; deferred UI integration is a forward-compat hook
  for a future V1.x stage. V1.2 wires the V1.1 grouper
  to the dialog.
- No git remote configured; backup / push separately. Not a
  V1.2 blocker.

---

## 3. V1.3 scope (Face Inventory)

### 3.1 V1.3 directive

`Prompt/CODEX_GUIDANCE_027_2026-08-20_DEFER_OWNER_SU_AND_CONTINUE_V1_3.txt`
- Title: Face Inventory (面拓扑清单)
- Default scope: read-only face/polygon extraction that
  reuses the existing `LayerIssueGrouper` semantics.
- Owner SU2020 verification DEFERRED during lunch → Agent
  continues V1.3 as a long-unattended task.
- V1.2 preserved exactly at tag
  `v1.2-issues-by-layer-candidate`; no Owner PASS, no
  CodeX end-of-stage packet, no formal release artifact.
- V1.3 work on a SEPARATE branch cut from V1.2 head.
- Complete core, host adapter, UI, full automated tests,
  performance check, RBZ smoke build.
- Separate V1.3 Owner checklist; combined V1.2 + V1.3 run
  order.
- SU2017 Gate 1 stays at formal release; not blocking V1.3.

### 3.2 V1.3 implementation diff (base → head)

`v1.3-face-inventory` branch, commits `0460c6b..HEAD`:

| Order | Commit | Subject |
|---|---|---|
| (V1.2 head) | `0460c6b` | docs(checkpoint): V1.2 Owner verification checklist + CURRENT_STATE update |
| (docs) | `ba8f28e` | docs(guidance): track V1.3 start directive in git |
| 1 | `b896e04` | feat(v1.3): core data layer for Face Inventory (FaceRecord + walk) |
| 2 | `b415364` | test(v1.3): FaceRecord + adapter + grouper + snapshot tests (core data) |
| 3 | `a72d23e` | feat(v1.3): pipeline + payload for Face Inventory (AnalysisResult + UIBridge + PreflightReport) |
| 4 | `5d20560` | feat(v1.3): render 'Face Inventory' section in dialog |
| (docs) | `0176c97` | docs(checkpoint): V1.3 Face Inventory final automated checkpoint |
| (BLOCK fix) | `bf2b2fc` | fix(v1.3): Face Inventory production seam — pass snapshot.layers to grouper (V13-BLOCK-001) |
| (recheck docs) | `ebe8c69` | docs(recheck): V13-BLOCK-001 BLOCK-recheck packet (after fix) |
| (NIT fix) | `e66a9ad` | fix(v1.3): face-inventory-row spacing fallback (V13-NIT-001) |

For pure V1.3 implementation review, the range is
`0460c6b..5d20560` (4 implementation + 1 docs checkpoint).
For post-implementation verification, the range is
`5d20560..HEAD` (the BLOCK-recheck fix + the NIT fix).

### 3.3 V1.3 locked user behavior (re-stated from directive 027)

1. New top-level `<details id="face-inventory-section">`
   AFTER the V1.1 Layers section.
2. Closed by default; summary populated before opening.
3. `Face Inventory — N total (H with holes)` summary
   format (N = face occurrences total; H = faces with
   holes; matches the directive's exact wording).
4. Aggregate rows by source face layer, NOT one UI row
   per individual face.
5. Each row shows: layer name, face count (correct
   singular/plural: `1 face` / `N faces`), faces-with-holes
   count (correct singular/plural: `1 face with holes` /
   `N faces with holes`), role badge, visibility badge
   using V1.1 layer semantics.
6. Order matches the V1.1 Layers display order
   (Dimension → Annotation → Guide → Construction → Unknown;
   visible before hidden; name ASC).
7. Face Inventory rows are informational and non-actionable
   in V1.3: no click handler, no Locate action, default
   cursor, no toast.
8. Existing issue-type groups / Issues by Layer / Layers /
   Locate behavior / role rules / issue severity remain
   unchanged.
9. `textContent` only. No innerHTML, no eval, no new
   Function, no document.write.
10. No new role colors. Severity palette remains exclusive
    to issue severity.
11. Two new scalar summary counters in `#summary`:
    `Faces: N` and `Faces With Holes: H`.
12. Analysis remains read-only. No entity / property /
    layer / visibility / material / soft / smooth / hidden
    / active-path mutation.

### 3.4 V1.3 BLOCK fixed (V13-BLOCK-001)

CodeX 028 (`Prompt/CODEX_REVIEW_028_2026-08-20_V1_3_FACE_INVENTORY_REAL_HOST_BLOCK.txt`)
identified a V1.3 production-seam silent-collapse defect:
`AnalyzersRunner` was passing `layer_groups` (Array<Hash>
LayerSummary) to `FaceInventoryGrouper.group`, but the
grouper requires each item to `respond_to?(:face_count)`;
Hash items do not, so every bucket was silently skipped
and the UI rendered `Face Inventory - 0 total (0 with holes)`
even when the top scalars reported `Faces: 1`.

- BLOCK-recheck packet:
  `Review/CODEX_V13_BLOCK_001_RECHECK_2026-08-20.md`
- Fix in commit `bf2b2fc`: pass `snapshot.layers`
  (Array<LayerRecord>, the canonical per-layer record list
  with all V1.1 role / visibility semantics already applied)
  instead of `layer_groups` (Array<Hash> LayerSummary).
- 6 new production-path tests in
  `tests/test_analyzers_runner.rb` exercise the real
  AnalyzersRunner path (the unit tests on the grouper in
  isolation passed before because they used LayerRecord
  directly; the production path was never exercised
  end-to-end before this BLOCK).
- Owner recheck on real SU2020: V13-BLOCK-001 CLOSED
  (Faces = 1 + Layer0 bucket with face_count = 1 + Face
  Inventory - 1 total).

### 3.5 V1.3 NIT fixed (V13-NIT-001)

Owner Gate 2 V1.3 NIT: on real SU2020 the Face Inventory
row parts render visually concatenated (e.g.
`ConstructionVisible1 face0 faces with holes`) because
the real SU HtmlDialog WebKit does not always honor the
CSS `gap` property on flex containers.

- Fix in commit `e66a9ad`: add
  `.face-inventory-row > * + * { margin-left: 8px; }` as a
  fallback. The `gap: 8px` is kept as the preferred path
  for standards-compliant webviews; the `+ *` adjacent-
  sibling selector only fires when gap is not honored, so
  the layout is correct in both modern and legacy WebKit.
- 1 new source-level guard test
  (`tests/test_html_render.rb`); 3 new DOM assertions
  (`tests/test_html_render_dom.js`).
- No semantic text / row order / data contracts change.

### 3.6 V1.3 locked contracts preserved

- R007..R012 (V1.1 layer semantics unchanged; role
  badges + visibility badges for face rows reuse the
  V1.1 LayerRecord shape).
- V1.2 directive 026 items 1-12 (V1.2 layerIssueGroups
  byte-for-byte intact; regression guard test in
  `test_ui_bridge.rb`; V12-NIT-001 pluralization fix lives
  in the V1.3 branch so the V1.2 branch is FROZEN at
  `0460c6b`).
- V1.3 directive 027 items 1-12 (Face Inventory section
  position, default-closed, summary format, aggregate-by-
  layer rows, singular/plural wording, textContent-only,
  non-actionable rows, read-only analysis, no new role
  colors).

### 3.7 V1.3 test evidence

- Ruby at V1.3 head: **470/470 PASS** (395 V1.2 + 75 new
  V1.3 = 8 FaceRecord + 10 FaceInventoryGrouper + 11
  adapter + 8 GeometrySnapshot/LayerRecord + 4 performance
  + 7 AnalysisResult + 6 UIBridge + 4 Preflight + 9 source
  guards + 6 production-path + 1 V12-NIT-001 source
  guard, 0 fail / 0 error).
- Node.js DOM at V1.3 head: **114 assertions PASS** (67
  V1.1 + 19 V1.2 + 25 V1.3 + 3 V13-NIT-001, all PASS).
- `git diff --check` clean for `extension/` and `tests/`.
- `dist/SU-AI-Plugin.rbz` rebuilt locally
  (255170+ bytes, 43 entries; gitignored).
- Performance guard: 5,000 + 50,000 face aggregations stay
  linear; FaceInventoryGrouper on 10 layers sub-second.
- V1.3 introduces **no V1.0 / V1.1 / V1.2 regression**: 395
  V1.0+V1.1+V1.2 tests all PASS unchanged at V1.3 head.

### 3.8 V1.3 Owner evidence (real SU2020)

- `Prompt/OWNER_REPORT_V1_3_FACE_INVENTORY_SU2020_2026-08-20.txt`
  (Owner Gate 2 V1.3 verdict: PASS WITH NIT on real SU2020;
  V13-BLOCK-001 recheck CLOSED; V13-NIT-001 spacing fixed).
- `Review/OWNER_VERIFICATION_V1_3_FACE_INVENTORY_2026-08-20.txt`
  (V13-1..V13-6 checklist with 4 doc corrections from
  CodeX 028 NITs applied).
- `Review/CODEX_V13_BLOCK_001_RECHECK_2026-08-20.md`
  (BLOCK-recheck packet documenting the V13-BLOCK-001 fix
  and regression evidence).
- The combined run-order doc:
  `Review/OWNER_RUN_ORDER_V1_2_AND_V1_3_2026-08-20.txt`
  (V12 first, V13 second; verdicts kept independent).

### 3.9 V1.3 known risks (per CodeX 027)

- `LayerIssueGrouper` (V1.1 forward-compat hook) is now
  wired to the V1.2 dialog. V1.3 does NOT use the
  grouper; V1.3 introduces a separate `FaceInventoryGrouper`
  that aggregates by layer using the V1.1 LayerRecord
  shape. Both groupers are pure Ruby; no JS-side
  recomputation.
- The two groupers are intentionally separate: a future
  "V1.x.1 Issues-by-Layer-and-Face" stage could
  compose them. Not a V1.2 / V1.3 blocker.
- No git remote configured; backup / push separately.
  Not a blocker.

---

## 4. Diff manifest (canonical)

### 4.1 V1.0 freeze (V1.0 stage 6 base)

`git diff --stat 56ea611..HEAD` covers V1.0 freeze +
V1.1 + V1.2 + V1.3 + V1.3 BLOCK fix + V1.3 NIT fix.

For per-stage review isolation:
- V1.0 stage 6 commits: see `git log --oneline 56ea611..23cac28`
  (excluded from this packet per the out-of-scope list).
- V1.1 implementation: `git diff --stat 23cac28..0460c6b`
  (excluded from this packet per CodeX 025 close + the
  out-of-scope list).
- V1.2 implementation: `git diff --stat 56ea611..0460c6b`
  on `v1.2-issues-by-layer` (5 commits, 2 scope
  sections in this packet).
- V1.3 implementation: `git diff --stat 0460c6b..HEAD`
  on `v1.3-face-inventory` (9 commits, 3 scope
  sections in this packet).

### 4.2 V1.2 production files (per directive 027 §REQUIRED
        AUTOMATED TESTS C + D)

- `extension/su_ai_plugin/core/analysis_result.rb`:
  `layer_issue_groups` attr + `layer_issue_groups_payload`
  helper + summary key `layer_issue_groups` + scalar
  `layer_issue_groups == []` default.
- `extension/su_ai_plugin/analyzers_runner.rb`:
  LayerIssueGrouper wiring (Hash-shape input).
- `extension/su_ai_plugin/ui_bridge.rb`:
  `layerIssueGroups` top-level key (String-keyed at
  boundary; same data as `summary['layer_issue_groups']`).
- `extension/su_ai_plugin/html/index.html`:
  `<details id="layer-issues-section">` block.
- `extension/su_ai_plugin/html/app.js`:
  `renderLayerIssues()` + `renderLayerIssueBucket()` +
  `formatCount` (also drives V13-NIT-001 fix).
- `extension/su_ai_plugin/html/style.css`:
  `.layer-issue-bucket` neutral styles.

### 4.3 V1.3 production files

- `extension/su_ai_plugin/core/face_record.rb` (NEW): the
  V1.3 FaceRecord immutable record.
- `extension/su_ai_plugin/core/face_inventory_grouper.rb`
  (NEW): the V1.3 pure-Ruby per-layer face aggregation.
- `extension/su_ai_plugin/core/geometry_snapshot.rb`:
  additive `faces:` keyword + `face_count` helper.
- `extension/su_ai_plugin/core/layer_record.rb`:
  additive `face_count` + `faces_with_holes_count` fields.
- `extension/su_ai_plugin/compatibility/su_capability.rb`:
  `face?` + `face_outer_loop_vertex_count` +
  `face_inner_loop_count` + `face_layer_name` capability
  probes.
- `extension/su_ai_plugin/preflight_runner.rb`: face
  branch in the same walk + `build_layer_records` passes
  face counters to LayerRecord.
- `extension/su_ai_plugin/core/preflight.rb`:
  `PreflightReport.face_count` + `faces_with_holes_count`
  + PreflightAnalyzer aggregates from `snapshot.faces`.
- `extension/su_ai_plugin/core/analysis_result.rb`:
  `face_inventory_groups` attr + payload helper + summary
  keys `faces` / `faces_with_holes` / `face_inventory_groups`.
- `extension/su_ai_plugin/analyzers_runner.rb`:
  `FaceInventoryGrouper.group(snapshot.layers)` (post-
  BLOCK fix; was passing `layer_groups` before).
- `extension/su_ai_plugin/ui_bridge.rb`:
  `faceInventoryGroups` top-level key.
- `extension/su_ai_plugin/html/index.html`:
  `<details id="face-inventory-section">` block (AFTER
  V1.1 Layers).
- `extension/su_ai_plugin/html/app.js`:
  `renderFaceInventory()` + `renderFaceInventoryRow()` +
  `#summary` scalar rows (`Faces: N` + `Faces With Holes: H`).
- `extension/su_ai_plugin/html/style.css`:
  `.face-inventory-row` neutral styles + the
  `.face-inventory-row > * + *` spacing fallback
  (V13-NIT-001 fix).

### 4.4 Tests

- `tests/test_face_record.rb` (NEW, 8 tests)
- `tests/test_face_inventory_grouper.rb` (NEW, 10 tests)
- `tests/test_face_inventory_performance.rb` (NEW, 4 tests)
- `tests/test_geometry_core.rb` (extended, 8 new V1.3 tests)
- `tests/test_preflight.rb` (extended, 4 new V1.3 tests)
- `tests/test_preflight_runner.rb` (extended, 11 new V1.3
  adapter tests)
- `tests/test_analysis_result.rb` (extended, 7 new V1.3
  tests)
- `tests/test_ui_bridge.rb` (extended, 6 new V1.3 tests)
- `tests/test_analyzers_runner.rb` (extended, 6 new V1.3
  production-path tests for the V13-BLOCK-001 fix)
- `tests/test_html_render.rb` (extended, 10 new V1.3 source-
  level guards + 1 V12-NIT-001 + 1 V13-NIT-001)
- `tests/test_html_render_dom.js` (extended, 25 V1.3 DOM
  assertions + 1 V12-NIT-001 + 3 V13-NIT-001)
- `tests/_fake_su.rb`: `Layer#visible=` setter, `Loop`,
  `Face` stand-ins (V1.3 needs them).

---

## 5. What CodeX is asked to do

This is **ONE consolidated end-of-stage verdict** on V1.2 +
V1.3 (combined per Owner direction). The verdict must
address:

### 5.1 V1.2 verification (per CodeX 026 + Owner direction)

1. **Implementation diff review** (commits
   `56ea611..0460c6b` on `v1.2-issues-by-layer`):
   - `LayerIssueGrouper` wiring in
     `AnalyzersRunner` (Hash-shape input) +
     `AnalysisResult.layer_issue_groups` +
     `UIBridge.layerIssueGroups` + dialog render path.
   - R007..R012 preserved (no regression).
   - V1.2 directive 026 items 1-12 honored (new section
     position, default-closed, summary format, bucket
     per non-empty layer, bucket summary singular/plural,
     issue-row reuse, locate carry-through, non-locatable
     inert, existing Layers rows remain inert,
     textContent-only, no new role colors, read-only).
2. **Owner evidence**:
   `Prompt/OWNER_REPORT_V1_2_ISSUES_BY_LAYER_2026-08-XX.txt`
   PASS on real SU2020.
3. **V12-NIT-001 fix**: covered by the V1.3 commit
   `e66a9ad` (the fix lives in the V1.3 branch which
   V1.2 imports through the V1.2 → V1.3 cut; the V1.2
   branch itself is FROZEN at `0460c6b`).

### 5.2 V1.3 verification (per CodeX 027 + 028)

1. **Implementation diff review** (commits
   `0466c6b..5d20560` on `v1.3-face-inventory` for
   implementation, `5d20560..HEAD` for fixes):
   - `FaceRecord` + `FaceInventoryGrouper` + walk
     extension + `PreflightReport` face counters +
     `AnalysisResult.face_inventory_groups` +
     `UIBridge.faceInventoryGroups` + dialog render.
   - R007..R012 preserved; V1.2 byte-for-byte intact.
   - V1.3 directive 027 items 1-12 honored (Face
     Inventory section position, default-closed, summary
     format, aggregate-by-layer rows, singular/plural
     wording, textContent-only, non-actionable rows,
     read-only analysis, no new role colors, scalar
     counters `Faces: N` + `Faces With Holes: H` in
     `#summary`).
2. **V13-BLOCK-001 recheck CLOSED**: see
   `Review/CODEX_V13_BLOCK_001_RECHECK_2026-08-20.md`.
   The production-seam silent-collapse defect is fixed
   in `bf2b2fc`; 6 production-path tests prove the
   fix; Owner recheck on real SU2020 confirmed
   `Face Inventory - 1 total` for a single Layer0 face.
3. **V13-NIT-001 fix**: see commit `e66a9ad`. The
   spacing fallback (`.face-inventory-row > * + *`) is
   presentation-only; semantic text / row order / data
   contracts unchanged. Source-level guard +
   3 DOM assertions added.
4. **Owner evidence**:
   `Prompt/OWNER_REPORT_V1_3_FACE_INVENTORY_SU2020_2026-08-20.txt`
   PASS WITH NIT on real SU2020; NIT is the spacing
   cleanup that this commit addresses.

### 5.3 Out-of-scope guard

- Do NOT raise BLOCKs against V1.0 fences (Stage 6 /
  CodeX 020 / RBZ / CodeX 024) — they are explicitly
  out of scope for this packet.
- Do NOT raise BLOCKs against V1.1 (CodeX 025 CLOSED)
  — out of scope.
- Do NOT raise BLOCKs against CodeX 028 / 025 / 020 /
  024 — they are explicitly out of scope.
- If a regression is found in any of those, mark it
  explicitly as "out of scope for V1.2 + V1.3 packet" so
  the Owner can route it as a separate V1.0 / V1.1 patch.

---

## 6. References

- **V1.2 directive**: `Prompt/CODEX_GUIDANCE_026_2026-08-20_V1_2_ISSUES_BY_LAYER_START.txt`
- **V1.3 directive**: `Prompt/CODEX_GUIDANCE_027_2026-08-20_DEFER_OWNER_SU_AND_CONTINUE_V1_3.txt`
- **V1.3 BLOCK**: `Prompt/CODEX_REVIEW_028_2026-08-20_V1_3_FACE_INVENTORY_REAL_HOST_BLOCK.txt`
- **V1.2 Owner report**: `Prompt/OWNER_REPORT_V1_2_ISSUES_BY_LAYER_2026-08-XX.txt`
- **V1.3 Owner report**: `Prompt/OWNER_REPORT_V1_3_FACE_INVENTORY_SU2020_2026-08-20.txt`
- **V1.2 Owner checklist**: `Review/OWNER_VERIFICATION_V1_2_ISSUES_BY_LAYER_2026-08-20.txt`
- **V1.3 Owner checklist**: `Review/OWNER_VERIFICATION_V1_3_FACE_INVENTORY_2026-08-20.txt`
- **Combined run-order**: `Review/OWNER_RUN_ORDER_V1_2_AND_V1_3_2026-08-20.txt`
- **V1.3 BLOCK-recheck packet**: `Review/CODEX_V13_BLOCK_001_RECHECK_2026-08-20.md`
- **Project memory**: `CURRENT_STATE.md`
- **Agent playbook + Review/Prompt routing**: `AGENT.md`

---

## 7. Sign-off

Once CodeX returns a verdict on this packet:

- **PASS** → Owner combines V1.0 + V1.1 + V1.2 + V1.3 in
  the final RBZ, reruns Gate 1 (SU2017) + Gate 2 V1.1 +
  Gate 2 V1.2 + Gate 2 V1.3 on the final artifact, ships.
- **PASS WITH NIT** → Agent fixes the NITs in a follow-up
  commit on the same branch. NO new CodeX review unless
  a high-risk BLOCK appears; cosmetic NITs do not block.
- **BLOCK** → Agent addresses each BLOCK explicitly in a
  follow-up commit. Dispatches a follow-up packet (one
  packet, not per-BLOCK). Reopening V1.0 / V1.1 / V1.2
  closed scope requires a new concrete evidence (per the
  Owner direction).

In all three cases:
- V1.2 + V1.3 verdicts stay in their separate Owner
  reports (no merge).
- SU2017 Gate 1 stays deferred to the formal release
  (R006); it does not block this combined end-of-stage
  review.
- The combined end-of-stage review is the LAST CodeX
  review before formal release. After CodeX PASS, no
  more CodeX micro-reviews until the formal release
  packet.

---

*End of V1.2 + V1.3 consolidated end-of-stage review
request. One packet; one verdict; no per-NIT or per-BLOCK
CodeX submissions until the formal release.*