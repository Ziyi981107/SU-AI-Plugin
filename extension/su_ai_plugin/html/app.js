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

  // Namespace MUST match extension/dialog_runner.rb ('window.SUAIP').
  var ROOT = window.SUAIP || (window.SUAIP = {});

  // Locked issue-type labels (matches Stage 6 plan section 6.7).
  // Order matters — the renderer emits them in this order.
  var ISSUE_TYPE_LABELS = [
    ['duplicate_edge_candidate',  'Duplicate Candidates'],
    ['short_edge',                'Short Edges'],
    ['open_endpoint',             'Open Endpoints'],
    ['gap_candidate',             'Gap Candidates'],
    ['significant_non_zero_z',    'Significant Non-zero Z'],
    ['abnormal_large_coord',      'Abnormal Large Coordinate'],
    ['deep_nesting',              'Deep Nesting']
  ];

  // V1.1 (per plan §4.10): locked layer-role labels. 5 canonical roles
  // ONLY (R007 — the OFFSCREEN role Symbol is REMOVED). Order mirrors
  // `SUAnalysis::Core::LayerRole::ALL` and is INDEPENDENT from the
  // issue-type order above (R012). The Ruby mapper already enforces
  // role bucket order when sorting layerGroups; JS preserves the
  // received order without re-sorting.
  var LAYER_ROLE_LABELS = [
    ['dimension',    'Dimension'],
    ['annotation',   'Annotation'],
    ['guide',        'Guide'],
    ['construction', 'Construction'],
    ['unknown',      'Unknown']
  ];

  // V1.1 (per plan §4.10): locked layer visibility labels. Mirrors
  // `SUAnalysis::Core::LayerRole::VISIBILITY_HUMAN` +
  // `LayerRole::VISIBILITY_UNKNOWN_HUMAN`. Per the plan, the
  // visibility_label on each row is pre-computed server-side
  // (LayerRole.visibility_label) and JS uses the per-row string
  // verbatim; this table is exposed for harness introspection only.
  var LAYER_VISIBILITY_LABELS = {
    visible: 'Visible',
    hidden:  'Off-screen',
    unknown: 'Visibility: unknown'
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
    var scalarKeys = ['edges', 'vertices', 'non_zero_z_vertices', 'warnings'];
    scalarKeys.forEach(function (k) {
      var stat = document.createElement('div');
      stat.className = 'stat';
      stat.textContent = humanizeKey(k) + ': ' + (payload.summary ? payload.summary[k] : 0);
      summary.appendChild(stat);
    });

    // Phase 2 — locked per-issue-type counters in canonical order.
    // The renderer NEVER falls back to stringifying a nested Hash,
    // so the output is always human-readable. Missing issue types
    // default to 0 (per the locked count-zero-required-categories
    // contract).
    var issues = (payload.summary && payload.summary.issues) || {};
    ISSUE_TYPE_LABELS.forEach(function (pair) {
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
      sum.textContent = humanizeType(g.type) + ' (' + g.count + ')';
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
  }

  function humanizeKey(k) {
    if (!k) return '';
    return k.split('_').map(function (w) {
      return w.charAt(0).toUpperCase() + w.slice(1);
    }).join(' ');
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
    badge.textContent = sev;

    var meta = document.createElement('span');
    meta.className = 'id';
    meta.textContent = issue.issue_id || '';

    var msg = document.createElement('div');
    msg.className = 'msg';
    msg.textContent = issue.message || '';

    var top = document.createElement('div');
    top.appendChild(meta);
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

  function humanizeType(t) {
    if (!t) return '';
    return t.split('_').map(function (w) {
      return w.charAt(0).toUpperCase() + w.slice(1);
    }).join(' ');
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
      layersSummary.textContent = 'Layers \u2014 ' + total + ' total (' +
                                  withIssues + ' with issues)';
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
      summaryEl.textContent = 'Issues by Layer \u2014 ' + totalBuckets +
                              ' layers (' + totalIssues + ' issues)';
    }
  }

  // V1.2: render one layer-issue bucket. Returns a `<details>`
  // element whose summary is "LayerName (N issue(s))" and whose
  // body contains the existing renderIssue() rows for each issue
  // in the bucket. The bucket honors `default_open` (set by
  // LayerIssueGrouper).
  function renderLayerIssueBucket(b) {
    var det = document.createElement('details');
    det.open = !!(b && b.default_open);
    var sum = document.createElement('summary');
    var layerName = (b && b.name) ? String(b.name) : '';
    var count = (b && typeof b.count === 'number') ? b.count : 0;
    // Locked per directive 026 item 6: "Each bucket header must
    // show the layer name and issue count with correct singular/
    // plural wording."
    sum.textContent = layerName + ' (' + formatCount(count, 'issue') + ')';
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
    // g.role_label is the source-of-truth server-composed label
    // (LayerRole::HUMAN[role]). We fall back to a humanized
    // version of the role symbol only if role_label is missing.
    roleBadge.textContent = (g && g.role_label) ? String(g.role_label)
                                                : humanizeKey(role);

    var visBadge = document.createElement('span');
    visBadge.className = 'visibility-badge';
    visBadge.textContent = (g && g.visibility_label) ? String(g.visibility_label)
                                                     : '';

    var edgesCell = document.createElement('span');
    edgesCell.className = 'edge-count';
    var edgeCount = (g && g.edge_count != null) ? g.edge_count : 0;
    edgesCell.textContent = formatCount(edgeCount, 'edge');

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
    issuesCell.textContent = formatCount(issueCount, 'issue');

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
  ROOT.ISSUE_TYPE_LABELS       = ISSUE_TYPE_LABELS;
  ROOT.LAYER_ROLE_LABELS       = LAYER_ROLE_LABELS;
  ROOT.LAYER_VISIBILITY_LABELS = LAYER_VISIBILITY_LABELS;
  ROOT.renderLayers            = renderLayers;
  ROOT.renderLayerRow          = renderLayerRow;
  ROOT.renderLayerIssues       = renderLayerIssues;
  ROOT.renderLayerIssueBucket  = renderLayerIssueBucket;

  document.addEventListener('DOMContentLoaded', function () {
    if (window.sketchup && window.sketchup.ready) {
      window.sketchup.ready();
    }
  });
})();
