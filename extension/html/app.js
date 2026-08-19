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
  }

  function humanizeKey(k) {
    if (!k) return '';
    return k.split('_').map(function (w) {
      return w.charAt(0).toUpperCase() + w.slice(1);
    }).join(' ');
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

  ROOT.render = render;
  ROOT.toast   = toast;
  ROOT.ISSUE_TYPE_LABELS = ISSUE_TYPE_LABELS;

  document.addEventListener('DOMContentLoaded', function () {
    if (window.sketchup && window.sketchup.ready) {
      window.sketchup.ready();
    }
  });
})();
