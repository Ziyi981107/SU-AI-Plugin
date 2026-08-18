/*
 * extension/html/app.js — UI render + click handler.
 *
 * Per CodeX Round 010..014:
 *   - No eval, no new Function, no document.write, no innerHTML for
 *     user-supplied strings.
 *   - All text rendered via textContent / setAttribute.
 *   - Click -> window.sketchup.locate(issue_id).
 *   - DOMContentLoaded -> window.sketchup.ready() (ready handshake).
 */
(function () {
  'use strict';

  var ROOT = window.SUAI || (window.SUAI = {});

  function render(payload) {
    var sel = document.getElementById('selection-info');
    sel.textContent = payload.selectionLabel + ' (' + payload.selectionType + ')';

    var summary = document.getElementById('summary');
    summary.textContent = '';
    Object.keys(payload.summary || {}).forEach(function (k) {
      var stat = document.createElement('div');
      stat.className = 'stat';
      stat.textContent = k + ': ' + payload.summary[k];
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

  function renderIssue(issue) {
    var div = document.createElement('div');
    div.className = 'issue';
    div.setAttribute('data-issue-id', issue.issue_id || '');

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

    div.addEventListener('click', function () {
      var id = issue.issue_id || '';
      if (window.sketchup && window.sketchup.locate) {
        window.sketchup.locate(id);
      }
    });

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

  document.addEventListener('DOMContentLoaded', function () {
    if (window.sketchup && window.sketchup.ready) {
      window.sketchup.ready();
    }
  });
})();
