/*
 * extension/html/app.js — UI render + click handler.
 *
 * Per CodeX Round 010..014:
 *   - No eval, no new Function, no document.write, no innerHTML for
 *     user-supplied strings.
 *   - All text rendered via textContent / setAttribute.
 *   - Click -> window.sketchup.locate(issue_id).
 *   - DOMContentLoaded -> window.sketchup.ready() (ready handshake).
 *
 * Per CodeX Round 019 BLOCK-006-R2: the locked Stage 6 plan section
 * 6.7 summary MUST render per-issue-type counts as individual
 * human-readable counters (e.g. "Short edges: 1", "Duplicate
 * candidates: 0") in the canonical order, NOT as
 * "Issues: [object Object]". The scalar header rows (Selection,
 * Edges, Vertices, non-zero-Z vertices, Warnings) are emitted FIRST
 * and the per-issue-type rows are emitted AFTER, one per canonical
 * issue_type, all in a single linear summary block. The order of
 * canonical issue types is locked and matches
 * `SUAnalysis::Core::IssueRegistry::CANONICAL_ISSUE_TYPES`.
 *
 * V1.6 UI-CN-SIMPLIFICATION (per dispatch
 * V16-UI-CN-SIMPLIFICATION-2026-09-01):
 *   - All normal user-facing text is Simplified Chinese.
 *   - Internal data identifiers (issue_id, snapshot_id, fingerprint,
 *     config_digest, action_id, rule_id, survivor_id, source
 *     occurrence counts, raw audit rows, internal state enum names)
 *     are NO LONGER visible in the default primary Working Mode
 *     area; they are preserved under a collapsed `技术详情`
 *     section so the data contract is NOT deleted.
 *   - The default UI shows one clear primary next-action whenever
 *     possible (Prepare / Analyze Planarity / Apply Safe
 *     Normalization). Unavailable actions are HIDDEN rather than
 *     rendered as disabled buttons.
 *   - Per-state condensed Working Mode rows; technical detail
 *     block (`技术详情`) is collapsed by default and lists source
 *     snapshot id, source fingerprint, execution config digest,
 *     raw workspace state, duplicate repair technical audit rows,
 *     per-action action_id/rule_id/survivor_id/source occurrence
 *     count, raw normalization reason, raw normalization audit
 *     fields.
 *   - V1.6 Planar Normalization `Ready` UI shows a compact
 *     primary card; the locked Blueprint §11 fields (Target Z /
 *     Eligible / Movable / Outliers / Affected / Skipped /
 *     Max movement) and the post-apply audit are rendered as
 *     CONCISE Chinese rows under the card when applicable.
 *   - Callback action names (prepare_workspace, discard_workspace,
 *     rebuild_workspace, compute_planar_normalization,
 *     apply_planar_normalization) are preserved verbatim. The
 *     destructive Apply Safe Normalization action MUST NOT appear
 *     enabled in any state other than READY_TO_NORMALIZE (per
 *     dispatch §2.2 bullet 2 / §10 CN5).
 *   - V1.5 Duplicate Repair summary row is condensed to the
 *     user-facing line ("重复线清理：已处理 X，跳过 Y，失败 Z")
 *     while the full audit (action_id, rule_id, survivor_id,
 *     source occurrence count) is preserved in `技术详情`.
 *   - The textContent-only contract for user-supplied strings is
 *     preserved. No innerHTML / no eval / no new Function / no
 *     document.write.
 *
 * V1.1 (per plan §4.10):
 *   - renderLayers(payload.layerGroups) renders the dialog Layers
 *     section. Each layer row exposes both a `role` badge AND a
 *     SEPARATE `visibility` badge (R007); they are independent.
 *   - The `<summary id="layers-summary">` text is populated at
 *     render time to "Layers — N total (M with issues)" BEFORE the
 *     user opens the details (so the user sees the count even when
 *     collapsed). Per ChatGPT §11.5.
 *   - Layer rows have `cursor: default` and NO click handler (mirrors
 *     V1.0 L3 non-locatable warning pattern from Round 020).
 *   - NO role color hints (R008); the CSS applies a single neutral
 *     `.layer-row` style and only `data-visible="false"` carries
 *     the muted `opacity: 0.6` style.
 *   - Hidden rows are placed at the BOTTOM of their role bucket by
 *     the Ruby-side mapper (per ChatGPT §11.2 / R009); the JS layer
 *     preserves the locked canonical order it receives and does NOT
 *     re-sort.
 */
(function () {
  'use strict';

  // window.SUAIP is the page-function namespace (render/toast).
  // It does NOT carry host actions (Prepare/Discard/Rebuild);
  // those live on window.sketchup.<callback> (registered by
  // DialogRunner.add_action_callback at boot).
  // See addAction() below for the host-action dispatch path.
  var ROOT = window.SUAIP || (window.SUAIP = {});

  // V1.6 UI-CN-SIMPLIFICATION: locked Simplified Chinese label
  // map for normal user-facing presentation. Internal data
  // identifiers (issue_id, snapshot_id, fingerprint, etc.) are
  // intentionally NOT translated; they remain as raw server
  // values inside `技术详情`. Order matters for ISSUE_TYPE_LABELS
  // (matches SUAnalysis::Core::IssueRegistry::CANONICAL_ISSUE_TYPES)
  // but is otherwise a presentation concern only.
  var ISSUE_TYPE_LABELS_CN = [
    ['duplicate_edge_candidate',  '重复线候选'],
    ['short_edge',                '短线'],
    ['open_endpoint',             '未闭合端点'],
    ['gap_candidate',             '间隙候选'],
    ['significant_non_zero_z',    '明显非零 Z'],
    ['abnormal_large_coord',      '异常大坐标'],
    ['deep_nesting',              '嵌套层级过深']
  ];

  // V1.1 (per plan §4.10): locked layer-role labels. 5 canonical roles
  // ONLY (R007 — the OFFSCREEN role Symbol is REMOVED). Order mirrors
  // `SUAnalysis::Core::LayerRole::ALL` and is INDEPENDENT from the
  // issue-type order above (R012). The Ruby mapper already enforces
  // role bucket order when sorting layerGroups; JS preserves the
  // received order without re-sorting.
  var LAYER_ROLE_LABELS_CN = [
    ['dimension',    '尺寸标注'],
    ['annotation',   '注释'],
    ['guide',        '辅助线'],
    ['construction', '构造线'],
    ['unknown',      '未识别']
  ];

  // V1.1 (per plan §4.10): locked layer visibility labels. Mirrors
  // `SUAnalysis::Core::LayerRole::VISIBILITY_HUMAN` +
  // `LayerRole::VISIBILITY_UNKNOWN_HUMAN`. Per the plan, the
  // visibility_label on each row is pre-computed server-side
  // (LayerRole.visibility_label) and JS uses the per-row string
  // verbatim; this table is exposed for harness introspection only.
  var LAYER_VISIBILITY_LABELS_CN = {
    visible: '可见',
    hidden:  '隐藏',
    unknown: '可见性未知'
  };

  // V1.6 UI-CN-SIMPLIFICATION: severity Simplified Chinese labels.
  // Server-side severity strings are the canonical Symbols
  // ('high' / 'medium' / 'low'); JS maps them to concise Chinese
  // presentation in the badge text only.
  var SEVERITY_LABELS_CN = {
    high:   '高',
    medium: '中',
    low:    '低'
  };

  // V1.6 UI-CN-SIMPLIFICATION: workspace state Simplified Chinese
  // labels for the Working Mode summary line.
  var WORKSPACE_STATE_LABELS_CN = {
    none:      '未准备',
    building:  '正在准备',
    ready:     '已准备',
    discarded: '已放弃',
    failed:    '处理失败'
  };

  // V1.6 UI-CN-SIMPLIFICATION: planar normalization state Simplified
  // Chinese labels (matches Blueprint §11).
  var PN_STATE_LABELS_CN = {
    NOT_COMPUTED:        '未检查',
    READY_TO_NORMALIZE:  '可安全校正',
    REVIEW_REQUIRED:     '需要人工确认',
    NO_CANDIDATE:        '无需校正',
    APPLIED:             '已校正',
    FAILED:              '校正失败',
    INVALID_TOLERANCE:   '配置无效',
    INVALID_INPUT:       '数据无效'
  };

  // V1.6 UI-CN-SIMPLIFICATION: short user-facing row labels for the
  // default-visible Working Mode card. Internal identifiers that
  // still need to be visible in `技术详情` (Source Snapshot /
  // Fingerprint / Config) keep their English keys for the DOM
  // `data-field` attribute, but the visible text is Chinese.
  var FIELD_LABEL_CN = {
    sourceSnapshot:           '源快照',
    sourceFingerprint:        '源指纹',
    executionConfig:          '执行配置',
    duplicateRepairs:         '重复线清理',
    planarNormalization:      '平面校正',
    targetZ:                  '目标 Z',
    eligibleVertices:         '可处理顶点',
    proposedMovable:          '待移动顶点',
    outliers:                 '异常点',
    affectedDerivedEdges:     '受影响线段',
    skippedScope:             '已跳过',
    maxProposedMovement:      '最大校正量',
    reviewReason:             '原因',
    appliedTargetZ:           '目标 Z',
    movedApplied:             '已移动',
    maxMovement:              '最大校正量',
    outliersUnchanged:        '保留异常项',
    failureReason:            '失败原因',
    lastError:                '上次错误'
  };

  // V1.6 UI-CN-SIMPLIFICATION: action button Simplified Chinese
  // labels. The internal data-action attribute (callback name) is
  // unchanged; only the visible button text is translated.
  var ACTION_LABEL_CN = {
    prepare_workspace:             '准备处理',
    discard_workspace:             '放弃工作副本',
    rebuild_workspace:             '重新生成',
    compute_planar_normalization:  '检查平面偏差',
    apply_planar_normalization:    '应用平面校正'
  };

  // V1.6 UI-CN-SIMPLIFICATION: section header Simplified Chinese
  // labels (rendered in the index.html <summary> static text AND
  // populated by JS at render time).
  var SECTION_LABEL_CN = {
    main:                    'CAD 检查结果',
    noSelection:             '未选择对象',
    issues:                  '问题概览',
    inspectionDetails:       '检查详情',
    layerIssues:             '按图层查看问题',
    layers:                  '图层信息',
    faceInventory:           '面信息',
    workingMode:             '处理工作区',
    planarNormalization:     '平面校正',
    technicalDetails:        '技术详情',
    moreActions:             '更多操作'
  };

  function render(payload) {
    var sel = document.getElementById('selection-info');
    sel.textContent = payload.selectionLabel + ' (' + payload.selectionType + ')';

    var summary = document.getElementById('summary');
    summary.textContent = '';
    // Phase 1 — locked scalar header rows (Stage 6 plan section 6.7).
    // The selection line is rendered separately as #selection-info,
    // so the summary block is reserved for the snapshot+issue
    // counts. We do NOT include the selection label here to avoid
    // duplicating it.
    // V1.3 (per directive 027 items 1 + 2): the scalar rows include
    // 'Faces' and 'Faces With Holes' as additive counters derived
    // from payload.summary (which UIBridge populates from
    // preflight.face_count + preflight.faces_with_holes_count).
    // V1.6 UI-CN-SIMPLIFICATION: scalar labels are Simplified
    // Chinese in normal user-facing presentation.
    var scalarKeys = ['edges', 'vertices', 'non_zero_z_vertices', 'warnings',
                     'faces', 'faces_with_holes'];
    var scalarLabelCN = {
      edges:               '线段',
      vertices:            '顶点',
      non_zero_z_vertices: '非零 Z 顶点',
      warnings:            '警告',
      faces:               '面',
      faces_with_holes:    '含洞面'
    };
    scalarKeys.forEach(function (k) {
      var stat = document.createElement('div');
      stat.className = 'stat';
      stat.setAttribute('data-stat', k);
      var label = scalarLabelCN[k] || humanizeKey(k);
      stat.textContent = label + ': ' + (payload.summary ? (payload.summary[k] || 0) : 0);
      summary.appendChild(stat);
    });

    // Phase 2 — locked per-issue-type counters in canonical order.
    // The renderer NEVER falls back to stringifying a nested Hash,
    // so the output is always human-readable. Missing issue types
    // default to 0 (per the locked count-zero-required-categories
    // contract).
    var issues = (payload.summary && payload.summary.issues) || {};
    ISSUE_TYPE_LABELS_CN.forEach(function (pair) {
      var type = pair[0];
      var label = pair[1];
      var stat = document.createElement('div');
      stat.className = 'stat issue-stat issue-type-' + type;
      stat.setAttribute('data-issue-type', type);
      var count = (typeof issues[type] === 'number') ? issues[type] : 0;
      stat.textContent = label + ': ' + count;
      summary.appendChild(stat);
    });

    var groupsEl = document.getElementById('groups');
    groupsEl.textContent = '';
    (payload.groups || []).forEach(function (g) {
      var det = document.createElement('details');
      det.open = !!g.defaultOpen;
      var sum = document.createElement('summary');
      // V1.6 UI-CN-SIMPLIFICATION: issue group summary label is
      // Simplified Chinese for the canonical issue types we know.
      // Unknown groups fall back to a humanized English label.
      sum.textContent = issueTypeLabelCN(g.type) + ' (' + g.count + ')';
      det.appendChild(sum);
      (g.issues || []).forEach(function (issue) {
        det.appendChild(renderIssue(issue));
      });
      groupsEl.appendChild(det);
    });

    // V1.1 (per plan §4.10): render the Layers section BELOW the
    // per-issue-type groups block (per ChatGPT §11.1). The function
    // is resilient to undefined / null / non-Array layerGroups — an
    // empty selection or a V1.0 caller that does not supply
    // layerGroups results in an empty list with summary text
    // "Layers — 0 total (0 with issues)".
    renderLayers(payload.layerGroups);

    // V1.2 (per directive 026): render the "Issues by Layer" section
    // AFTER the per-issue-type groups block AND BEFORE the V1.1
    // Layers section. Resilient to undefined / null / non-Array
    // payload.layerIssueGroups — defaults to "Issues by Layer — 0
    // layers (0 issues)" with zero buckets. Issues inside each
    // bucket reuse renderIssue() so the click-to-locate and
    // non-locatable-inert contracts carry through unchanged.
    renderLayerIssues(payload.layerIssueGroups);

    // V1.3 (per directive 027): render the "Face Inventory" section
    // AFTER the V1.1 Layers section. Resilient to undefined / null /
    // non-Array payload.faceInventoryGroups — defaults to "Face
    // Inventory — 0 total (0 with holes)" with zero rows. Rows are
    // aggregate-by-layer (NOT per-face), non-actionable, neutral
    // styling; reuse the V1.1 layer semantics.
    renderFaceInventory(payload.faceInventoryGroups);

    // V1.4 (per directive 030, Stage 4): render the "Working Mode"
    // section AFTER V1.3. Resilient to a missing payload.derivedWorkspace
    // (defaults to state='none'). All text via textContent (per the
    // locked textContent-only contract for user-facing text). The
    // action buttons (Prepare / Discard / Rebuild) wire to
    // window.sketchup.<callback> -- the callbacks are
    // registered by DialogRunner.add_action_callback (Ruby
    // side) and exposed by SketchUp's HtmlDialog at
    // window.sketchup.<callback>. window.SUAIP only carries
    // the page functions render/toast (NOT the host actions).
    //
    // V1.6 UI-CN-SIMPLIFICATION: the Working Mode card uses the
    // SIMPLIFIED presentation — one clear primary next action,
    // a concise user-facing status sentence, condensed V1.5 audit
    // row (no internal IDs by default), and a condensed V1.6
    // normalization card. Technical detail rows are emitted to a
    // SEPARATE `技术详情` collapsed block (renderTechnicalDetails)
    // so the data contract is preserved without polluting the
    // default screen.
    renderWorkingMode(payload.derivedWorkspace);
    renderTechnicalDetails(payload.derivedWorkspace);
  }

  function humanizeKey(k) {
    if (!k) return '';
    return k.split('_').map(function (w) {
      return w.charAt(0).toUpperCase() + w.slice(1);
    }).join(' ');
  }

  // V1.6 UI-CN-SIMPLIFICATION: map a canonical issue_type Symbol
  // to its Simplified Chinese label. Returns the humanized English
  // form for any unknown type (safe fallback).
  function issueTypeLabelCN(t) {
    if (!t) return '';
    for (var i = 0; i < ISSUE_TYPE_LABELS_CN.length; i++) {
      if (ISSUE_TYPE_LABELS_CN[i][0] === t) return ISSUE_TYPE_LABELS_CN[i][1];
    }
    return humanizeKey(t);
  }

  // Per Owner Gate 2 V1.1 NIT (1-2): edge / issue counters must
  // (a) pluralize correctly (1 edge vs 4 edges, 1 issue vs 2 issues)
  // and (b) be visually separated so the row does not collapse to
  // "1 edge3 issues" when the flexbox gap is 0 in the host
  // dialog. We centralize the formatter here so both the layer
  // row and any future caller use the same rule.
  function formatCount(n, noun) {
    var count = (typeof n === 'number' && isFinite(n) && n >= 0) ? n : 0;
    return count + ' ' + noun + (count === 1 ? '' : 's');
  }

  function renderIssue(issue) {
    var div = document.createElement('div');
    div.setAttribute('data-issue-id', issue.issue_id || '');
    // Per CodeX Round 020 REAL-HOST BLOCK (recheck) L3: ONLY register
    // the locate click handler when the issue is locatable. For
    // non-locatable rows (preflight warnings like deep_nesting and
    // abnormal_large_coord), the locator returns :unresolved and the
    // JS previously raised a misleading "source no longer available"
    // toast — these rows are intentionally non-locatable (no source
    // token to resolve), NOT stale. Registering no click handler
    // means there is no path to window.sketchup.locate and therefore
    // no path to the toast.
    //
    // Visual non-action state: a `no-action` class so CSS can apply
    // default cursor + remove the hover affordance. This keeps the
    // locked contract that all user text is rendered via textContent
    // (no innerHTML for user-supplied strings).
    var locatable = (issue.locatable === true);
    div.className = 'issue' + (locatable ? '' : ' no-action');
    div.setAttribute('data-locatable', locatable ? 'true' : 'false');

    var sev = (issue.severity || 'low').toLowerCase();
    var badge = document.createElement('span');
    badge.className = 'badge sev-' + sev;
    // V1.6 UI-CN-SIMPLIFICATION: severity badge text is the
    // mapped Simplified Chinese label.
    badge.textContent = SEVERITY_LABELS_CN[sev] || sev;

    // V1.6 UI-CN-SIMPLIFICATION (dispatch §7): issue ID is hidden
    // from the primary row. We keep it as a data attribute on the
    // row for harness introspection + Owner tooltip + the
    // `技术详情` block, but the primary visible text does NOT
    // include the raw issue_id.
    var msg = document.createElement('div');
    msg.className = 'msg';
    msg.textContent = issue.message || '';

    // Per dispatch §7 the issue row carries the Chinese severity
    // badge and one concise Chinese message. The Issue ID is
    // preserved as a data attribute and exposed under `技术详情`.
    var top = document.createElement('div');
    top.appendChild(badge);
    div.appendChild(top);
    div.appendChild(msg);

    // ONLY register the click handler when the issue is locatable.
    // For locatable === false, the row is intentionally non-actionable;
    // there is no click handler and therefore no path to the stale-
    // source toast (Round 020 REAL-HOST BLOCK L3 fix).
    if (locatable) {
      div.addEventListener('click', function () {
        var id = issue.issue_id || '';
        if (window.sketchup && window.sketchup.locate) {
          window.sketchup.locate(id);
        }
      });
    }

    return div;
  }

  function toast(msg) {
    var el = document.getElementById('toast');
    if (!el) return;
    el.textContent = msg;
    el.hidden = false;
    setTimeout(function () { el.hidden = true; }, 4000);
  }

  // V1.1 (per plan §4.10): render the dialog Layers section.
  // Populates #layers-list with one .layer-row per group and the
  // #layers-summary text with "Layers — N total (M with issues)"
  // BEFORE the user opens the details. The locked render contract
  // (textContent only, no innerHTML for user strings, no eval,
  // no new Function) is preserved.
  //
  // V1.6 UI-CN-SIMPLIFICATION: per-row role + visibility badge
  // labels are Simplified Chinese.
  function renderLayers(layerGroups) {
    var layersList = document.getElementById('layers-list');
    var layersSummary = document.getElementById('layers-summary');
    // Defensive: clear the previous render so a re-render does not
    // accumulate. textContent = '' is the spec-clean equivalent of
    // element.innerHTML = '' without touching the locked contract.
    if (layersList) layersList.textContent = '';
    // Coerce undefined / null / non-Array to []. This keeps the
    // no-payload path testable (a V1.0 caller that does not supply
    // layerGroups, or an empty selection, both end up here).
    var groups = Array.isArray(layerGroups) ? layerGroups : [];
    var total = groups.length;
    var withIssues = 0;
    groups.forEach(function (g) {
      if (g && g.issue_count && g.issue_count > 0) withIssues++;
      if (layersList) layersList.appendChild(renderLayerRow(g));
    });
    if (layersSummary) {
      // V1.6 UI-CN-SIMPLIFICATION: section header text is
      // Simplified Chinese.
      layersSummary.textContent = SECTION_LABEL_CN.layers +
                                  '\u2014 ' + total + ' 个图层（' +
                                  withIssues + ' 个存在问题）';
    }
  }

  // V1.2 (per directive 026): render the dialog "Issues by Layer"
  // section. Populates #layer-issues-list with one .layer-issue-bucket
  // per non-empty bucket and the #layer-issues-summary text with
  // "Issues by Layer — N layers (M issues)" BEFORE the user opens
  // the details. Each bucket is a `<details>` with its own summary;
  // issues inside reuse renderIssue() so the existing click-to-
  // locate and non-locatable-inert contracts carry through unchanged.
  // Locked render contract preserved: no innerHTML, no eval, no new
  // Function, no document.write.
  //
  // V1.6 UI-CN-SIMPLIFICATION: section header + bucket count noun
  // are Simplified Chinese.
  function renderLayerIssues(layerIssueGroups) {
    var listEl = document.getElementById('layer-issues-list');
    var summaryEl = document.getElementById('layer-issues-summary');
    // Defensive: clear the previous render.
    if (listEl) listEl.textContent = '';
    var buckets = Array.isArray(layerIssueGroups) ? layerIssueGroups : [];
    var totalBuckets = buckets.length;
    var totalIssues = 0;
    buckets.forEach(function (b) {
      if (!b || !Array.isArray(b.issues)) return;
      totalIssues += b.issues.length;
      if (listEl) listEl.appendChild(renderLayerIssueBucket(b));
    });
    if (summaryEl) {
      // V1.6 UI-CN-SIMPLIFICATION: section header is Simplified
      // Chinese ("按图层查看问题— N 个图层（M 个问题）"). The
      // noun "个图层" already encodes the counter so we do
      // NOT pass it through formatCount (which would append
      // a stray "s" for the English pluralization).
      summaryEl.textContent = SECTION_LABEL_CN.layerIssues +
                              '\u2014 ' + totalBuckets + ' 个图层' +
                              '（' + totalIssues + ' 个问题）';
    }
  }

  // V1.3 (per directive 027): render the dialog "Face Inventory"
  // section. Populates #face-inventory-list with one .face-inventory-row
  // per layer that has at least one face, and the #face-inventory-summary
  // text with "Face Inventory — N total (H with holes)" BEFORE the user
  // opens the details. Aggregate rows by source face layer (per directive
  // item 4: NOT one UI row per individual face). Rows reuse the
  // V1.1 layer semantics: role badge + visibility badge are SEPARATE
  // (R007), neutral styling, no role color selectors.
  // Locked render contract preserved: no innerHTML, no eval, no new
  // Function, no document.write.
  //
  // V1.6 UI-CN-SIMPLIFICATION: section header is Simplified
  // Chinese.
  function renderFaceInventory(faceInventoryGroups) {
    var listEl = document.getElementById('face-inventory-list');
    var summaryEl = document.getElementById('face-inventory-summary');
    if (listEl) listEl.textContent = '';
    var buckets = Array.isArray(faceInventoryGroups) ? faceInventoryGroups : [];
    var totalFaces = 0;
    var totalHoles = 0;
    buckets.forEach(function (b) {
      if (!b) return;
      var fc = (typeof b.face_count === 'number') ? b.face_count : 0;
      var hc = (typeof b.faces_with_holes_count === 'number') ? b.faces_with_holes_count : 0;
      totalFaces += fc;
      totalHoles += hc;
      if (listEl) listEl.appendChild(renderFaceInventoryRow(b));
    });
    if (summaryEl) {
      // V1.6 UI-CN-SIMPLIFICATION: section header is Simplified
      // Chinese.
      summaryEl.textContent = SECTION_LABEL_CN.faceInventory +
                              '\u2014 ' + totalFaces +
                              ' 个面（' + totalHoles + ' 个含洞）';
    }
  }

  // V1.3: render one Face Inventory row. Per directive 027 item 5:
  //   - layer name;
  //   - face count with correct singular/plural wording;
  //   - count of faces with holes;
  //   - role badge and visibility badge using the V1.1 layer
  //     semantics when available.
  // Per directive item 7: rows are informational and non-actionable.
  // No click handler. No Locate action. Default cursor. No toast.
  // Per directive item 11: no new role colors; reuse neutral
  // styling; severity colors remain exclusive to issue severity.
  function renderFaceInventoryRow(b) {
    var div = document.createElement('div');
    div.className = 'face-inventory-row';
    var role = (b && b.role) ? String(b.role) : 'unknown';
    var visibility_unknown = !!(b && b.visibility_unknown);
    var visible = !!(b && b.visible);
    div.setAttribute('data-role', role);
    div.setAttribute('data-visible', visible ? 'true' : 'false');
    div.setAttribute('data-visibility-unknown', visibility_unknown ? 'true' : 'false');
    div.setAttribute('data-layer-name', (b && b.name) ? String(b.name) : '');

    var name = document.createElement('span');
    name.className = 'layer-name';
    name.textContent = (b && b.name) ? String(b.name) : '';

    // V1.6 UI-CN-SIMPLIFICATION: role badge uses the Simplified
    // Chinese label map; visibility badge uses the Simplified
    // Chinese label map. The Ruby mapper still emits a
    // pre-computed visibility_label per row; if the row is from
    // a server-side payload that has already been translated we
    // honor it, otherwise we map from the canonical role /
    // visibility symbol.
    var roleBadge = document.createElement('span');
    roleBadge.className = 'role-badge';
    roleBadge.textContent = (b && b.role_label) ? String(b.role_label)
                                                : layerRoleLabelCN(role);

    var visBadge = document.createElement('span');
    visBadge.className = 'visibility-badge';
    visBadge.textContent = (b && b.visibility_label) ? String(b.visibility_label)
                                                      : '';

    var facesCell = document.createElement('span');
    facesCell.className = 'face-count';
    var fc = (b && typeof b.face_count === 'number') ? b.face_count : 0;
    facesCell.textContent = formatCount(fc, '个面');

    var facesSep = document.createElement('span');
    facesSep.className = 'face-count-sep';
    facesSep.setAttribute('aria-hidden', 'true');
    facesSep.textContent = '\u00B7'; // middle dot "·"

    var holesCell = document.createElement('span');
    holesCell.className = 'holes-count';
    var hc = (b && typeof b.faces_with_holes_count === 'number') ? b.faces_with_holes_count : 0;
    holesCell.textContent = formatCount(hc, '个含洞面');

    div.appendChild(name);
    div.appendChild(roleBadge);
    div.appendChild(visBadge);
    div.appendChild(facesCell);
    div.appendChild(facesSep);
    div.appendChild(holesCell);
    // No click handler -- Face Inventory rows are non-actionable.
    return div;
  }

  // V1.6 UI-CN-SIMPLIFICATION: map a canonical layer-role Symbol
  // to its Simplified Chinese label.
  function layerRoleLabelCN(r) {
    if (!r) return LAYER_ROLE_LABELS_CN[4][1]; // 'unknown'
    for (var i = 0; i < LAYER_ROLE_LABELS_CN.length; i++) {
      if (LAYER_ROLE_LABELS_CN[i][0] === r) return LAYER_ROLE_LABELS_CN[i][1];
    }
    return humanizeKey(r);
  }

  // V1.6 UI-CN-SIMPLIFICATION: short Chinese sentence describing
  // the current workspace state for the default Working Mode
  // summary line. The full technical state string is preserved in
  // `技术详情`.
  function workspaceStateSentenceCN(ws) {
    var state = (typeof ws.state === 'string') ? ws.state : 'none';
    var totalEntities = (typeof ws.entity_count === 'number') ? ws.entity_count : 0;
    switch (state) {
      case 'none':
        return '尚未准备工作副本';
      case 'building':
        return '正在准备工作副本…';
      case 'ready':
        return '工作副本已准备，共 ' + totalEntities + ' 条记录';
      case 'discarded':
        return '工作副本已放弃';
      case 'failed':
        return '处理失败，需要重新生成';
      default:
        return state;
    }
  }

  // V1.4 (per directive 030, Stage 4) + V1.6 UI-CN-SIMPLIFICATION:
  // render the dialog's simplified "Working Mode" section. The
  // default screen shows:
  //   - one short Chinese status sentence;
  //   - one condensed user-facing summary row for the V1.5
  //     duplicate-repair audit (when present);
  //   - one condensed user-facing summary row for the V1.6
  //     planar-normalization card (when present);
  //   - ONE primary action button (Prepare / Analyze Planarity /
  //     Apply Safe Normalization) chosen by current workspace +
  //     normalization state. Unavailable actions are HIDDEN rather
  //     than rendered as disabled buttons.
  // Secondary operational controls (Discard / Rebuild) are emitted
  // to a separate collapsed "更多操作" block when applicable.
  // Technical detail rows (source snapshot id / fingerprint /
  // config digest / raw workspace state / per-action audit /
  // raw normalization audit) are emitted to renderTechnicalDetails
  // (under `技术详情`) so the data contract is preserved without
  // polluting the default screen.
  //
  // Locked contract:
  //   - All user-facing text rendered via textContent (no
  //     innerHTML for user-supplied strings).
  //   - Source-vs-derived ownership is shown by NEVER
  //     recoloring / re-layering / hiding source; the section
  //     is INFO ONLY -- it tells the user where the captured
  //     source snapshot came from and what workspace state
  //     is current.
  //   - Action buttons wire to window.sketchup.<callback> (no
  //     eval). The buttons are HIDDEN when not available in the
  //     current state (NOT rendered as disabled).
  //   - No new role / state color selectors.
  //   - The destructive Apply Safe Normalization action MUST
  //     NOT appear enabled in any state other than
  //     READY_TO_NORMALIZE (per dispatch §2.2 bullet 2).
  function renderWorkingMode(derivedWorkspace) {
    var listEl = document.getElementById('working-mode-list');
    var actionsEl = document.getElementById('working-mode-actions');
    var summaryEl = document.getElementById('working-mode-summary');
    if (!listEl || !actionsEl) return;

    // Defensive: missing or wrong-shape payload => 'none'.
    var ws = (derivedWorkspace && typeof derivedWorkspace === 'object')
              ? derivedWorkspace : { 'state': 'none' };
    var state = (typeof ws.state === 'string') ? ws.state : 'none';

    // Clear previous render.
    while (listEl.firstChild) listEl.removeChild(listEl.firstChild);
    while (actionsEl.firstChild) actionsEl.removeChild(actionsEl.firstChild);

    // Summary text (rendered BEFORE user opens the details block,
    // mirroring the V1.1/V1.2/V1.3 sections' convention).
    // V1.6 UI-CN-SIMPLIFICATION: the summary text is the concise
    // Chinese sentence describing the current workspace state.
    if (summaryEl) {
      summaryEl.textContent = SECTION_LABEL_CN.workingMode +
                              '\u2014 ' + workspaceStateSentenceCN(ws);
    }

    // Per-state user-facing rows.
    if (state === 'none') {
      addRow(listEl, 'none', null, null, '尚未准备工作副本');
      // V1.5 Phase 1 + V1.6 UI-CN-SIMPLIFICATION: when a
      // duplicate_repair summary has been recorded (even on a
      // discarded workspace), surface it as a single condensed
      // Chinese row so the user can see the audit trail after
      // Discard. The full per-action audit (action_id, rule_id,
      // survivor_id, source occurrence count) is preserved in
      // `技术详情`.
      if (ws.duplicate_repair && typeof ws.duplicate_repair === 'object') {
        renderDuplicateRepairUserRow(listEl, 'none', ws.duplicate_repair);
      }
    } else {
      // state in {building, ready, discarded, failed}.
      // V1.6 UI-CN-SIMPLIFICATION: failed state exposes a
      // concise Chinese recovery sentence in the primary list.
      // The full raw last_error string is preserved in
      // `技术详情` for Owner / AIPM diagnosis.
      if (state === 'failed') {
        addRow(listEl, 'failed', null, null, '处理失败，请点击下方「重新生成」');
      }
      // V1.5 BLOCK-004: condensed duplicate-repair row in the
      // default Working Mode card. Full audit rows are in
      // `技术详情`.
      if (ws.duplicate_repair && typeof ws.duplicate_repair === 'object') {
        renderDuplicateRepairUserRow(listEl, state, ws.duplicate_repair);
      }
      // V1.6 Planar Normalization condensed card (per
      // dispatch §3 D + §10 CN4-CN10). The full Blueprint §11
      // rows and (when applicable) the locked action button
      // are rendered here; the raw audit rows are preserved in
      // `技术详情`.
      if (ws.planar_normalization && typeof ws.planar_normalization === 'object') {
        renderPlanarNormalization(listEl, state, ws.planar_normalization);
      }
    }

    // V1.6 UI-CN-SIMPLIFICATION (per dispatch §4): ONE primary
    // action button is shown when applicable. Unavailable
    // actions are HIDDEN (NOT rendered as disabled). The
    // primary action is chosen by current workspace + planar
    // normalization state.
    renderPrimaryAction(actionsEl, state, ws.planar_normalization);

    // Secondary operational controls live in a collapsed
    // `更多操作` block under the primary CTA (per dispatch
    // §4.5). They are emitted to a separate sub-element so
    // they do not clutter the primary action row.
    renderMoreActions(actionsEl, state);
  }

  // V1.6 UI-CN-SIMPLIFICATION: condensed Chinese user-facing
  // duplicate-repair row. The full audit is preserved in
  // `技术详情`. The summary line format is
  // "重复线清理：已处理 X，跳过 Y，失败 Z" per dispatch §6.
  function renderDuplicateRepairUserRow(listEl, state, dr) {
    var applied = (typeof dr.actions_applied === 'number') ? dr.actions_applied : 0;
    var skipped = (typeof dr.actions_skipped === 'number') ? dr.actions_skipped : 0;
    var failed  = (typeof dr.actions_failed === 'number')  ? dr.actions_failed  : 0;
    var line = FIELD_LABEL_CN.duplicateRepairs + '：已处理 ' + applied +
               '，跳过 ' + skipped + '，失败 ' + failed;
    addRow(listEl, state, null, line, line);
  }

  // V1.6 UI-CN-SIMPLIFICATION + V16-UI-CN-SIMPLIFICATION-FIX:
  // emit the ONE primary action button when applicable.
  // Unavailable actions are HIDDEN. Destructive Apply Safe
  // Normalization is rendered ONLY when workspaceState ===
  // 'ready' AND pnState === 'READY_TO_NORMALIZE'.
  //
  // Action-state matrix (per dispatch V16-UI-CN-SIMPLIFICATION-FIX
  // §5):
  //   - 'none'                         -> 准备处理
  //   - 'discarded'                    -> 准备处理 (primary)
  //   - 'failed'                       -> 准备处理 (primary; same
  //                                        class of mistake: the
  //                                        user may select a NEW
  //                                        source after a failed
  //                                        build)
  //   - 'ready' + NOT_COMPUTED         -> 检查平面偏差
  //   - 'ready' + READY_TO_NORMALIZE   -> 应用平面校正
  //   - 'ready' + (REVIEW_REQUIRED / NO_CANDIDATE / APPLIED /
  //                FAILED / INVALID_*) -> no destructive Apply
  //                                       CTA
  //   - 'building'                     -> no buttons (in-progress)
  //
  // `准备处理` is the primary CTA in BOTH 'none' and 'discarded'
  // (and 'failed') because in all three the user may select a
  // NEW CAD source and must be able to create a fresh
  // SourceSnapshot + Derived Workspace from the CURRENT
  // selection. Rebuild replays the previously captured workspace,
  // which is not the same thing.
  function renderPrimaryAction(actionsEl, workspaceState, pn) {
    if (workspaceState === 'none') {
      // No workspace yet -> Prepare.
      addAction(actionsEl, ACTION_LABEL_CN.prepare_workspace,
                'prepare_workspace', true);
      return;
    }
    if (workspaceState === 'discarded') {
      // Per V16-UI-CN-SIMPLIFICATION-FIX Owner real-host finding:
      // after Discard the user may select a NEW source and must
      // be able to create a fresh SourceSnapshot. Rebuild replays
      // the previously captured workspace, which is not a
      // substitute. Prepare is the primary CTA; Rebuild is
      // available as a secondary control under `更多操作` when
      // a previously captured source still exists.
      addAction(actionsEl, ACTION_LABEL_CN.prepare_workspace,
                'prepare_workspace', true);
      return;
    }
    if (workspaceState === 'failed') {
      // Per V16-UI-CN-SIMPLIFICATION-FIX "same class of mistake"
      // review: the user may select a NEW source after a failed
      // build. Prepare is the primary CTA; Rebuild replays the
      // captured workspace as a secondary control.
      addAction(actionsEl, ACTION_LABEL_CN.prepare_workspace,
                'prepare_workspace', true);
      return;
    }
    // Workspace exists (ready).
    if (workspaceState === 'ready') {
      // Determine the planar normalization state.
      var pnState = (pn && typeof pn === 'object' && typeof pn.state === 'string')
                    ? pn.state : 'NOT_COMPUTED';
      if (pnState === 'NOT_COMPUTED') {
        addAction(actionsEl, ACTION_LABEL_CN.compute_planar_normalization,
                  'compute_planar_normalization', true);
        return;
      }
      if (pnState === 'READY_TO_NORMALIZE') {
        addAction(actionsEl, ACTION_LABEL_CN.apply_planar_normalization,
                  'apply_planar_normalization', true);
        return;
      }
      // All other PN states (REVIEW_REQUIRED / NO_CANDIDATE /
      // APPLIED / FAILED / invalid_*): no destructive Apply
      // button. The user can rebuild / discard from the
      // `更多操作` block.
      return;
    }
    // 'building' (in-progress) -> no buttons.
  }

  // V1.6 UI-CN-SIMPLIFICATION + V16-UI-CN-SIMPLIFICATION-FIX:
// secondary operational controls. Per dispatch §4.5 these live
// in a collapsed `更多操作` block under the primary CTA.
// Unavailable controls are HIDDEN rather than rendered as
// disabled buttons. The collapsed block is itself HIDDEN when
// no secondary control is meaningful (e.g. state='none' before
// the first Prepare, OR state='building' in-progress), so the
// default screen shows ONLY the primary CTA.
//
// Per V16-UI-CN-SIMPLIFICATION-FIX §5 the action-state matrix:
//   - 'none'         -> primary=准备处理, secondary=(none, no block)
//   - 'discarded'    -> primary=准备处理, secondary=重新生成
//                        (only; the previously captured source
//                         can still be replayed)
//   - 'failed'       -> primary=准备处理, secondary=重新生成
//   - 'ready'        -> primary per PN state, secondary=放弃工作副本
//                        + 重新生成
//   - 'building'     -> no buttons at all (in-progress)
function renderMoreActions(actionsEl, workspaceState) {
    var hasDiscard = (workspaceState === 'ready');
    var hasRebuild = (workspaceState === 'ready' || workspaceState === 'discarded' ||
                      workspaceState === 'failed');
    if (!hasDiscard && !hasRebuild) return;
    // We emit a small `<details>` with `<summary>更多操作</summary>`
    // containing the available secondary buttons.
    var det = document.createElement('details');
    det.className = 'more-actions';
    var sum = document.createElement('summary');
    sum.textContent = SECTION_LABEL_CN.moreActions;
    det.appendChild(sum);
    var inner = document.createElement('div');
    inner.className = 'more-actions-inner';
    if (hasDiscard) {
      addAction(inner, ACTION_LABEL_CN.discard_workspace,
                'discard_workspace', true);
    }
    if (hasRebuild) {
      addAction(inner, ACTION_LABEL_CN.rebuild_workspace,
                'rebuild_workspace', true);
    }
    det.appendChild(inner);
    actionsEl.appendChild(det);
  }

  // V1.6 UI-CN-SIMPLIFICATION (per dispatch §5.5): render the
  // collapsed `技术详情` block. This preserves the full data
  // contract (source snapshot id / fingerprint / config digest /
  // raw workspace state / per-action audit / raw normalization
  // audit) so AIPM / Pi / Owner can still inspect the technical
  // truth, while keeping the default screen materially simpler.
  // The block is rendered CLOSED by default; users only see it
  // when they explicitly open the section.
  function renderTechnicalDetails(derivedWorkspace) {
    var listEl = document.getElementById('technical-details-list');
    if (!listEl) return;
    while (listEl.firstChild) listEl.removeChild(listEl.firstChild);
    var ws = (derivedWorkspace && typeof derivedWorkspace === 'object')
              ? derivedWorkspace : null;
    if (!ws) return;

    // Raw workspace state (always shown when ws is present).
    if (typeof ws.state === 'string') {
      addTechRow(listEl, 'workspace_state', ws.state);
    }
    if (ws.source_snapshot_id) {
      addTechRow(listEl, 'source_snapshot_id', ws.source_snapshot_id);
    }
    if (ws.source_fingerprint_digest) {
      addTechRow(listEl, 'source_fingerprint_digest', ws.source_fingerprint_digest);
    }
    if (ws.execution_config_digest) {
      addTechRow(listEl, 'execution_config_digest', ws.execution_config_digest);
    }
    if (ws.workspace_id) {
      addTechRow(listEl, 'workspace_id', ws.workspace_id);
    }
    if (ws.last_error) {
      addTechRow(listEl, 'last_error', ws.last_error);
    }

    // Duplicate repair technical audit: applied/skipped/failed,
    // duplicate classes before/after, duplicate pairs before/
    // after, derived edge counts before/after, and per-action
    // audit rows (action_id / rule_id / survivor_id / source
    // occurrence count).
    if (ws.duplicate_repair && typeof ws.duplicate_repair === 'object') {
      renderDuplicateRepairTechnicalRows(listEl, ws.duplicate_repair);
    }
    // V1.6 Planar Normalization raw audit rows (per dispatch
    // §5.5): raw normalization reason string, raw audit fields
    // (status, target_z, applied_count, max_movement,
    // outlier_count, failure_reason).
    if (ws.planar_normalization && typeof ws.planar_normalization === 'object') {
      renderPlanarNormalizationTechnicalRows(listEl, ws.planar_normalization);
    }
  }

  function addTechRow(listEl, key, value) {
    var row = document.createElement('div');
    row.className = 'tech-row';
    row.setAttribute('data-field', key);
    var labelEl = document.createElement('span');
    labelEl.className = 'label';
    labelEl.textContent = key + ':';
    var valEl = document.createElement('span');
    valEl.className = 'value';
    valEl.textContent = String(value);
    row.appendChild(labelEl);
    row.appendChild(valEl);
    listEl.appendChild(row);
  }

  // V1.6 UI-CN-SIMPLIFICATION (per dispatch §5.5): per-action
  // audit rows (BLOCK-004 / CodeX 032 recheck 2026-08-25
  // minimum). Every action row exposes status, removed count,
  // survivor ID, and source-occurrence count as visible fields.
  // textContent only (no innerHTML).
  function renderDuplicateRepairTechnicalRows(listEl, dr) {
    var applied = (typeof dr.actions_applied === 'number') ? dr.actions_applied : 0;
    var skipped = (typeof dr.actions_skipped === 'number') ? dr.actions_skipped : 0;
    var failed  = (typeof dr.actions_failed === 'number')  ? dr.actions_failed  : 0;
    var bits = [];
    bits.push('applied=' + applied);
    bits.push('skipped=' + skipped);
    bits.push('failed=' + failed);
    if (typeof dr.duplicate_classes_before === 'number' &&
        typeof dr.duplicate_classes_after === 'number') {
      bits.push('classes=' + dr.duplicate_classes_before + '->' + dr.duplicate_classes_after);
    }
    if (typeof dr.duplicate_pairs_before === 'number' &&
        typeof dr.duplicate_pairs_after === 'number') {
      bits.push('pairs=' + dr.duplicate_pairs_before + '->' + dr.duplicate_pairs_after);
    }
    if (typeof dr.derived_edge_count_before === 'number' &&
        typeof dr.derived_edge_count_after === 'number') {
      bits.push('derived_edges=' + dr.derived_edge_count_before + '->' + dr.derived_edge_count_after);
    }
    addTechRow(listEl, 'duplicate_repair_summary', bits.join('; '));

    if (Array.isArray(dr.actions) && dr.actions.length > 0) {
      dr.actions.forEach(function (act) {
        if (!act || typeof act !== 'object') return;
        var status = act.status || 'unknown';
        var actionId = act.action_id || '?';
        var removedCount = (typeof act.removed_count === 'number') ? act.removed_count : 0;
        var survivorId = act.survivor_derived_id || '';
        var sourceCount = (typeof act.source_occurrence_count === 'number') ?
                          act.source_occurrence_count : 0;
        var ruleId = act.rule_id || '';
        var basis = act.confidence_basis || act.explanation || 'no detail';
        var row = document.createElement('div');
        row.className = 'tech-row action-audit-row';
        row.setAttribute('data-action-id', actionId);
        row.setAttribute('data-action-status', status);
        if (survivorId) row.setAttribute('data-survivor-id', survivorId);
        var c1 = document.createElement('span');
        c1.setAttribute('data-field', 'status');
        c1.textContent = 'status=' + status;
        row.appendChild(c1);
        var c2 = document.createElement('span');
        c2.setAttribute('data-field', 'action_id');
        c2.textContent = 'action_id=' + actionId;
        row.appendChild(c2);
        var c3 = document.createElement('span');
        c3.setAttribute('data-field', 'survivor_id');
        c3.textContent = 'survivor_id=' + survivorId;
        row.appendChild(c3);
        var c4 = document.createElement('span');
        c4.setAttribute('data-field', 'removed_count');
        c4.textContent = 'removed_count=' + removedCount;
        row.appendChild(c4);
        var c5 = document.createElement('span');
        c5.setAttribute('data-field', 'source_count');
        c5.textContent = 'source_count=' + sourceCount;
        row.appendChild(c5);
        var c6 = document.createElement('span');
        c6.setAttribute('data-field', 'rule_id');
        c6.textContent = 'rule_id=' + ruleId;
        row.appendChild(c6);
        var c7 = document.createElement('span');
        c7.setAttribute('data-field', 'basis');
        c7.textContent = 'basis=' + basis;
        row.appendChild(c7);
        listEl.appendChild(row);
      });
    }
  }

  // V1.6 UI-CN-SIMPLIFICATION (per dispatch §5.5): raw
  // normalization audit / reason / target_z / max_movement /
  // outlier count are preserved under `技术详情` for AIPM/Pi/
  // Owner diagnosis. The default Working Mode card only shows
  // the condensed Chinese user-facing rows.
  function renderPlanarNormalizationTechnicalRows(listEl, pn) {
    if (!pn || typeof pn !== 'object') return;
    var pnState = (typeof pn.state === 'string') ? pn.state : 'NOT_COMPUTED';
    addTechRow(listEl, 'planar_normalization_state', pnState);
    var proposal = (pn.proposal && typeof pn.proposal === 'object') ? pn.proposal : null;
    if (proposal) {
      if (typeof proposal.reason === 'string' && proposal.reason.length > 0) {
        addTechRow(listEl, 'planar_normalization_reason', proposal.reason);
      }
      if (typeof proposal.target_z === 'number') {
        addTechRow(listEl, 'planar_normalization_target_z', proposal.target_z);
      }
      if (typeof proposal.tolerance_used === 'number') {
        addTechRow(listEl, 'planar_normalization_tolerance_used', proposal.tolerance_used);
      }
    }
    var audit = (pn.audit && typeof pn.audit === 'object') ? pn.audit : null;
    if (audit) {
      if (typeof audit.status === 'string') {
        addTechRow(listEl, 'planar_normalization_audit_status', audit.status);
      }
      if (typeof audit.rule_id === 'string') {
        addTechRow(listEl, 'planar_normalization_audit_rule_id', audit.rule_id);
      }
      if (typeof audit.rule_version === 'string') {
        addTechRow(listEl, 'planar_normalization_audit_rule_version', audit.rule_version);
      }
      if (typeof audit.target_z === 'number') {
        addTechRow(listEl, 'planar_normalization_audit_target_z', audit.target_z);
      }
      if (typeof audit.max_movement === 'number') {
        addTechRow(listEl, 'planar_normalization_audit_max_movement', audit.max_movement);
      }
      if (typeof audit.applied_count === 'number') {
        addTechRow(listEl, 'planar_normalization_audit_applied_count', audit.applied_count);
      }
      if (typeof audit.failed_count === 'number') {
        addTechRow(listEl, 'planar_normalization_audit_failed_count', audit.failed_count);
      }
      if (typeof audit.reason === 'string' && audit.reason.length > 0) {
        addTechRow(listEl, 'planar_normalization_audit_reason', audit.reason);
      }
    }
  }

  // V1.6 Planar Normalization: render the compact Chinese
  // "平面校正" card inside the default Working Mode list.
  // Always renders a "平面校正" State row in Chinese. When the
  // snapshot carries additional Blueprint §11 fields AND/OR an
  // audit row, those are rendered as concise Chinese rows under
  // the card. The destructive Apply action is rendered by
  // renderPrimaryAction (NOT here). The raw audit fields are
  // preserved under `技术详情` by renderTechnicalDetails.
  //
  // Per dispatch §3 D: NOT_COMPUTED shows "尚未检查平面偏差。",
  // READY_TO_NORMALIZE shows target_z + movable count + outlier
  // count + the primary CTA, REVIEW_REQUIRED shows a Chinese
  // explanation with no destructive action, NO_CANDIDATE shows
  // a Chinese no-action explanation, APPLIED shows moved count +
  // max movement + outlier count, FAILED shows a Chinese
  // failure reason + recovery action.
  function renderPlanarNormalization(listEl, workspaceState, pn) {
    if (!pn || typeof pn !== 'object') return;
    var pnState = (typeof pn.state === 'string') ? pn.state : 'NOT_COMPUTED';
    var pnLabel = PN_STATE_LABELS_CN[pnState] || pnState;
    // Card title row.
    addRow(listEl, workspaceState, FIELD_LABEL_CN.planarNormalization,
           pnLabel, pnLabel);

    // NOT_COMPUTED -> short message, no further rows.
    if (pnState === 'NOT_COMPUTED') {
      addRow(listEl, workspaceState, null, null, '尚未检查平面偏差。');
      return;
    }
    // REVIEW_REQUIRED -> reason row in Chinese.
    if (pnState === 'REVIEW_REQUIRED') {
      addRow(listEl, workspaceState, null, null,
             '检测到多组高度，无法安全自动判断。');
      var proposalRQ = (pn.proposal && typeof pn.proposal === 'object') ? pn.proposal : null;
      if (proposalRQ && typeof proposalRQ.reason === 'string' && proposalRQ.reason.length > 0) {
        addRow(listEl, workspaceState, FIELD_LABEL_CN.reviewReason,
               proposalRQ.reason, proposalRQ.reason);
      }
      return;
    }
    // NO_CANDIDATE -> short message.
    if (pnState === 'NO_CANDIDATE') {
      addRow(listEl, workspaceState, null, null, '当前几何无需平面校正。');
      return;
    }
    // READY_TO_NORMALIZE -> Blueprint §11 condensed rows.
    if (pnState === 'READY_TO_NORMALIZE') {
      addRow(listEl, workspaceState, null, null,
             '检测到可安全校正的轻微 Z 偏差。');
      var proposal = (pn.proposal && typeof pn.proposal === 'object') ? pn.proposal : null;
      if (proposal) {
        if (typeof proposal.target_z === 'number') {
          addRow(listEl, workspaceState, FIELD_LABEL_CN.targetZ,
                 String(proposal.target_z), String(proposal.target_z));
        }
        if (typeof proposal.movable_count === 'number') {
          addRow(listEl, workspaceState, FIELD_LABEL_CN.proposedMovable,
                 proposal.movable_count + ' 个',
                 proposal.movable_count + ' 个');
        }
        if (typeof proposal.outlier_count === 'number') {
          addRow(listEl, workspaceState, FIELD_LABEL_CN.outliers,
                 proposal.outlier_count + ' 个',
                 proposal.outlier_count + ' 个');
        }
      }
      return;
    }
    // APPLIED -> moved + max movement + outlier unchanged.
    if (pnState === 'APPLIED') {
      addRow(listEl, workspaceState, null, null, '平面校正已完成。');
      var auditA = (pn.audit && typeof pn.audit === 'object') ? pn.audit : null;
      if (auditA) {
        if (typeof auditA.applied_count === 'number') {
          addRow(listEl, workspaceState, FIELD_LABEL_CN.movedApplied,
                 auditA.applied_count + ' 个',
                 auditA.applied_count + ' 个');
        }
        if (typeof auditA.max_movement === 'number') {
          addRow(listEl, workspaceState, FIELD_LABEL_CN.maxMovement,
                 String(auditA.max_movement),
                 String(auditA.max_movement));
        }
        if (Array.isArray(auditA.outlier_derived_ids) && auditA.outlier_derived_ids.length > 0) {
          addRow(listEl, workspaceState, FIELD_LABEL_CN.outliersUnchanged,
                 auditA.outlier_derived_ids.length + ' 个',
                 auditA.outlier_derived_ids.length + ' 个');
        }
      }
      return;
    }
    // FAILED -> Chinese failure reason + recovery.
    if (pnState === 'FAILED') {
      addRow(listEl, workspaceState, null, null, '平面校正失败。');
      var auditF = (pn.audit && typeof pn.audit === 'object') ? pn.audit : null;
      if (auditF && typeof auditF.reason === 'string' && auditF.reason.length > 0) {
        addRow(listEl, workspaceState, FIELD_LABEL_CN.failureReason,
               auditF.reason, auditF.reason);
      }
      return;
    }
    // invalid_tolerance / invalid_input -> Chinese explanation.
    if (pnState === 'INVALID_TOLERANCE' || pnState === 'INVALID_INPUT') {
      addRow(listEl, workspaceState, null, null, '当前配置或数据无效，无法计算。');
    }
  }

  // Helper: append a labelled, factual row to the working-mode list.
  // `state` is the data-state attribute ('none' / 'building' / 'ready'
  // / 'discarded' / 'failed'). `label` is the small heading; `value`
  // is the short text; `title` is the long text (used as a tooltip
  // via the `title` attribute, so no user-text innerHTML).
  //
  // V1.6 UI-CN-SIMPLIFICATION: when `label` is null the row is a
  // single-line message (no label-value separator), which is the
  // dominant pattern in the simplified Working Mode card.
  function addRow(listEl, state, label, value, title) {
    var row = document.createElement('div');
    row.className = 'working-mode-row';
    row.setAttribute('data-state', state);
    if (label) {
      var labelEl = document.createElement('span');
      labelEl.className = 'label';
      labelEl.textContent = label + '：';
      row.appendChild(labelEl);
      if (value) {
        var valEl = document.createElement('span');
        valEl.className = 'value';
        valEl.textContent = value;
        if (title && title !== value) {
          valEl.setAttribute('title', title);
        }
        row.appendChild(valEl);
      }
    } else if (value) {
      var valEl2 = document.createElement('span');
      valEl2.className = 'value';
      valEl2.textContent = value;
      if (title && title !== value) {
        valEl2.setAttribute('title', title);
      }
      row.appendChild(valEl2);
    } else if (title) {
      // No short value; put the message in the row directly.
      var msgEl = document.createElement('span');
      msgEl.className = 'value';
      msgEl.textContent = title;
      row.appendChild(msgEl);
    }
    listEl.appendChild(row);
  }

  // Helper: append an action button. `callback` is a SketchUp
  // add_action_callback name (Prepare / Discard / Rebuild).
  // V14-RUNTIME-BLOCK-001 (2026-08-22, real-SU2020 Owner
  // repro): the host action callbacks registered by
  // DialogRunner.add_action_callback live on
  // `window.sketchup.<name>` (NOT `window.SUAIP.<name>` --
  // window.SUAIP only carries the page functions render/toast).
  // The previous addAction resolved via
  // `window.SUAIP[callback]` -- which never matched the real
  // SU callback path -- so the click handler was a no-op on a
  // real SU host (Prepare/Discard/Rebuild buttons did nothing).
  // The fix below resolves via `window.sketchup[callback]`
  // (BRACKET LOOKUP, no eval). When the callback is absent
  // (test env / partial install), the click is a safe no-op
  // (the dialog stays usable).
  //
  // V1.6 UI-CN-SIMPLIFICATION: button label is the Simplified
  // Chinese presentation. The internal `data-action` attribute
  // preserves the canonical English callback name so the Ruby
  // dispatch + DOM tests still resolve correctly.
  function addAction(actionsEl, label, callback, enabled) {
    var btn = document.createElement('button');
    btn.textContent = label;
    btn.setAttribute('data-action', callback);
    if (!enabled) btn.setAttribute('disabled', 'disabled');
    btn.addEventListener('click', function () {
      if (btn.hasAttribute('disabled')) return;
      // No eval; locate the callback on window.sketchup and
      // call it. The callback is registered by
      // DialogRunner.add_action_callback at boot.
      var sk = window.sketchup || {};
      var fn = sk[callback];
      if (typeof fn === 'function') fn();
    });
    actionsEl.appendChild(btn);
  }

  // V1.2: render one layer-issue bucket. Returns a `<details>`
  // element whose summary is "LayerName (N issue(s))" and whose
  // body contains the existing renderIssue() rows for each issue
  // in the bucket. The bucket honors `default_open` (set by
  // LayerIssueGrouper).
  //
  // V1.6 UI-CN-SIMPLIFICATION: bucket header uses the
  // formatCount helper so "1 issue" reads correctly in any
  // language; per dispatch §13 CN13 the wording is Simplified
  // Chinese.
  function renderLayerIssueBucket(b) {
    var det = document.createElement('details');
    det.open = !!(b && b.default_open);
    var sum = document.createElement('summary');
    var layerName = (b && b.name) ? String(b.name) : '';
    var count = (b && typeof b.count === 'number') ? b.count : 0;
    // V1.6 UI-CN-SIMPLIFICATION: bucket header reads
    // "LayerName（N 个问题）"; we do NOT pass it through
    // formatCount (the noun "个问题" already encodes the
    // counter and the English-pluralization 's' suffix
    // would corrupt the Simplified Chinese wording).
    sum.textContent = layerName + '（' + count + ' 个问题）';
    det.appendChild(sum);
    var issues = (b && Array.isArray(b.issues)) ? b.issues : [];
    issues.forEach(function (issue) {
      det.appendChild(renderIssue(issue));
    });
    return det;
  }

  // V1.1 (per plan §4.10): render one layer row. The row carries:
  //   - data-role (locked canonical role symbol)
  //   - data-visible (true | false)        — operational layer
  //                                          visibility (R007).
  //   - data-visibility-unknown (true | false) — whether the host
  //                                          capability was missing
  //                                          (R011).
  //   - data-layer-name                    — verbatim layer name.
  // The row exposes BOTH a role badge (e.g. "Dimension") AND a
  // SEPARATE visibility badge ("Visible" / "Off-screen" /
  // "Visibility: unknown"); the two are independent (R007). The row
  // has cursor: default and NO click handler; it is intentionally
  // non-actionable (mirrors V1.0 L3 non-locatable warning pattern).
  //
  // V1.6 UI-CN-SIMPLIFICATION: role + visibility badges use the
  // Simplified Chinese label maps.
  function renderLayerRow(g) {
    var div = document.createElement('div');
    div.className = 'layer-row';
    var role = (g && g.role) ? String(g.role) : 'unknown';
    var visibility_unknown = !!(g && g.visibility_unknown);
    var visible = !!(g && g.visible);
    // The Ruby mapper already coerces these to the right shape.
    // We re-check on the JS side for defensive rendering of any
    // future payload shape (e.g. a malformed layerGroups array).
    div.setAttribute('data-role', role);
    div.setAttribute('data-visible', visible ? 'true' : 'false');
    div.setAttribute('data-visibility-unknown', visibility_unknown ? 'true' : 'false');
    div.setAttribute('data-layer-name', (g && g.name) ? String(g.name) : '');

    var name = document.createElement('span');
    name.className = 'layer-name';
    name.textContent = (g && g.name) ? String(g.name) : '';

    var roleBadge = document.createElement('span');
    roleBadge.className = 'role-badge';
    // V1.6 UI-CN-SIMPLIFICATION: the visible role label is
    // always the JS Simplified Chinese translation (based on
    // the canonical role Symbol). The Ruby mapper's pre-
    // computed `role_label` is not used here because the
    // mapper currently emits English labels; we want the
    // visible presentation to ALWAYS be Simplified Chinese
    // regardless of payload version.
    roleBadge.textContent = layerRoleLabelCN(role);

    var visBadge = document.createElement('span');
    visBadge.className = 'visibility-badge';
    // V1.6 UI-CN-SIMPLIFICATION: prefer the JS Simplified
    // Chinese translation based on the canonical visibility
    // Symbol; fall back to the raw server-provided label only
    // when the visibility is `unknown` (where the server may
    // carry extra diagnostic context).
    var visKey = visibility_unknown ? 'unknown' : (visible ? 'visible' : 'hidden');
    visBadge.textContent = LAYER_VISIBILITY_LABELS_CN[visKey] || '';

    var edgesCell = document.createElement('span');
    edgesCell.className = 'edge-count';
    var edgeCount = (g && g.edge_count != null) ? g.edge_count : 0;
    edgesCell.textContent = edgeCount + ' 条';

    // Visible separator between the edge and issue counts. The
    // separator is a real DOM node (not just whitespace) so the
    // mock test harness and any future SR / a11y reader both pick
    // it up reliably. Per Owner Gate 2 V1.1 NIT: prior rendering
    // produced visually-joined text like "1 edge3 issues" when the
    // flexbox gap was 0; this separator makes the join explicit
    // in BOTH the CSS and the textContent.
    var countSep = document.createElement('span');
    countSep.className = 'layer-count-sep';
    countSep.setAttribute('aria-hidden', 'true');
    countSep.textContent = '\u00B7'; // middle dot "·"

    var issuesCell = document.createElement('span');
    var issueCount = (g && g.issue_count != null) ? g.issue_count : 0;
    issuesCell.className = 'issue-count' + (issueCount > 0 ? ' has-issues' : '');
    issuesCell.textContent = issueCount + ' 个问题';

    div.appendChild(name);
    div.appendChild(roleBadge);
    div.appendChild(visBadge);
    div.appendChild(edgesCell);
    div.appendChild(countSep);
    div.appendChild(issuesCell);
    // No click handler — layers are intentionally non-actionable.
    // There is no path to window.sketchup.locate from this row.
    return div;
  }

  ROOT.render = render;
  ROOT.toast   = toast;
  ROOT.ISSUE_TYPE_LABELS_CN    = ISSUE_TYPE_LABELS_CN;
  ROOT.LAYER_ROLE_LABELS_CN    = LAYER_ROLE_LABELS_CN;
  ROOT.LAYER_VISIBILITY_LABELS_CN = LAYER_VISIBILITY_LABELS_CN;
  ROOT.SEVERITY_LABELS_CN      = SEVERITY_LABELS_CN;
  ROOT.WORKSPACE_STATE_LABELS_CN = WORKSPACE_STATE_LABELS_CN;
  ROOT.PN_STATE_LABELS_CN      = PN_STATE_LABELS_CN;
  ROOT.FIELD_LABEL_CN          = FIELD_LABEL_CN;
  ROOT.ACTION_LABEL_CN         = ACTION_LABEL_CN;
  ROOT.SECTION_LABEL_CN        = SECTION_LABEL_CN;
  ROOT.renderLayers            = renderLayers;
  ROOT.renderLayerRow          = renderLayerRow;
  ROOT.renderLayerIssues       = renderLayerIssues;
  ROOT.renderLayerIssueBucket  = renderLayerIssueBucket;
  ROOT.renderFaceInventory     = renderFaceInventory;
  ROOT.renderFaceInventoryRow  = renderFaceInventoryRow;
  ROOT.renderWorkingMode       = renderWorkingMode;
  ROOT.renderTechnicalDetails  = renderTechnicalDetails;
  // V1.6 Planar Normalization / Z Policy: expose the
  // sub-renderer so the DOM tests (CN1-CN18 per dispatch
  // V16-UI-CN-SIMPLIFICATION-2026-09-01) can call it directly.
  // These are pure functions of (listEl, state, payload) and
  // have no other side effect.
  ROOT.renderPlanarNormalization       = renderPlanarNormalization;

  document.addEventListener('DOMContentLoaded', function () {
    if (window.sketchup && window.sketchup.ready) {
      window.sketchup.ready();
    }
  });
})();