/*
 * extension/html/app.js — V1.9A-A1 production UI render + click
 * handler.
 *
 * Locked contracts (per dispatch §5 / §11 / §12):
 *   - All user-supplied text rendered via textContent /
 *     safe attribute APIs. No innerHTML / no eval / no
 *     new Function / no document.write.
 *   - No remote runtime dependency.
 *   - 4 tabs (处理 default, 问题, 图层, 详情).
 *   - 5 capability cards in fixed order, always visible.
 *   - Inventory absent from default 处理 view; raw counts
 *     reachable in 详情 only.
 *   - DOMContentLoaded -> window.sketchup.ready() handshake
 *     (preserved from V1.4 production contract).
 *   - Render contract:
 *       window.SUAIP.render(json) — main render entry
 *         (preserved from V1.4 production contract).
 *       window.SUAIP.toast(message) — user-facing toast
 *         (preserved from V1.4 production contract).
 *
 * Callbacks dispatched to host (per dispatch §12):
 *   prepare_workspace, discard_workspace, rebuild_workspace,
 *   compute_planar_normalization, apply_planar_normalization,
 *   compute_gap_repair, apply_gap_repair,
 *   compute_structure_reconstruction, locate, close.
 *
 * Render path:
 *   AnalysisResult + WorkingModeRunner.snapshot
 *   -> UIBridge -> { cadPrepWorkflow: { ... }, derivedWorkspace,
 *                    layerGroups, layerIssueGroups,
 *                    faceInventoryGroups, summary, groups, ... }
 *   -> window.SUAIP.render(json) -> this module
 *   -> DOM (4 tabs, 5 cards, error-only summary).
 *
 * Authority:
 *   Prompt/AIPM_STAGE_PRODUCT_TECHNICAL_BLUEPRINT_V1_9A_V1_9B_2026-09-04.md
 *   + dispatch Prompt/CURRENT_PI_DISPATCH.md (V1.9A-A1).
 *
 * Frozen V1.4 / V1.5 / V1.6 / V1.7 / V1.8 contracts UNCHANGED.
 * No algorithm change. No source CAD mutation.
 */

(function () {
  'use strict';

  // window.SUAIP is the page-function namespace (render/toast).
  // Host callbacks (Prepare/Discard/Rebuild/...) live on
  // window.sketchup.<callback> (registered by
  // DialogRunner.add_action_callback at boot).
  var ROOT = window.SUAIP || (window.SUAIP = {});

  // ================================================================
  // 1. Static Simplified Chinese labels (presentation-only)
  // ================================================================

  // Overall presentation state -> user-facing CN label.
  // Per Blueprint §4.4: raw enum strings MUST NOT be exposed
  // to the user.
  var OVERALL_STATE_LABELS_CN = {
    IDLE:                 '尚未处理',
    SCANNING:             '正在检查',
    NEEDS_ATTENTION:      '发现需要处理的问题',
    READY_FOR_VALIDATION: '已完成检查',
    STALE:                '工作副本已失效',
    FAILED:               '处理失败'
  };

  // Card presentation state -> CSS class (icon / pill).
  var CARD_STATE_TO_CLASS = {
    UNCOMPUTED:      'is-idle',
    CHECKING:        'is-accent',
    CLEAN:           'is-ok',
    ACTIONABLE:      'is-warn',
    REVIEW_REQUIRED: 'is-warn',
    APPLIED:         'is-ok',
    BLOCKED:         'is-warn',
    STALE:           'is-warn',
    FAILED:          'is-err'
  };

  // Layer role CN labels (mirrors V1.1 layerGroups).
  var LAYER_ROLE_LABELS_CN = {
    dimension:    '尺寸标注',
    annotation:   '注释',
    guide:        '辅助线',
    construction: '构造线',
    unknown:      '未识别'
  };

  // Inline SVG paths for the 5 capability cards.
  var CARD_ICON_PATHS = {
    duplicate_cleanup:    'M8 3h9a2 2 0 0 1 2 2v12M4 7h11a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z',
    planar_normalization: 'M4 18h16M5 16l4-8 4 6 3-3 3 4',
    gap_endpoint:         'M3 12h6m6 0h6M9 12a3 3 0 1 1 6 0 3 3 0 0 1-6 0z',
    structure_region:     'M4 6h6v6H4zM14 6h6v6h-6zM4 16h6v6H4zM14 16h6v6h-6z',
    other:                'M12 3l9 4.5v9L12 21 3 16.5v-9L12 3z M12 8v4 M12 16v.2'
  };

  // ================================================================
  // 2. DOM-safe render helpers
  // ================================================================

  function clearChildren(parent) {
    while (parent && parent.firstChild) {
      parent.removeChild(parent.firstChild);
    }
  }

  function el(tag, opts, children) {
    var node = document.createElement(tag);
    if (opts) {
      if (opts.className) node.className = opts.className;
      if (opts.dataset) {
        Object.keys(opts.dataset).forEach(function (k) {
          node.dataset[k] = opts.dataset[k];
        });
      }
      if (opts.attrs) {
        Object.keys(opts.attrs).forEach(function (k) {
          node.setAttribute(k, opts.attrs[k]);
        });
      }
      if (opts.text != null) node.textContent = String(opts.text);
    }
    if (children) {
      children.forEach(function (c) {
        if (c == null) return;
        if (typeof c === 'string') {
          node.appendChild(document.createTextNode(c));
        } else {
          node.appendChild(c);
        }
      });
    }
    return node;
  }

  function svgInline(pathD, sizePx, classes) {
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('width', String(sizePx));
    svg.setAttribute('height', String(sizePx));
    svg.setAttribute('viewBox', '0 0 24 24');
    if (classes) svg.setAttribute('class', classes);
    var p = document.createElementNS(ns, 'path');
    p.setAttribute('d', pathD);
    p.setAttribute('fill', 'none');
    p.setAttribute('stroke', 'currentColor');
    p.setAttribute('stroke-width', '1.6');
    p.setAttribute('stroke-linecap', 'round');
    p.setAttribute('stroke-linejoin', 'round');
    svg.appendChild(p);
    return svg;
  }

  function emptyNode(text) {
    var d = document.createElement('div');
    d.textContent = text;
    return d;
  }

  // ================================================================
  // 3. Capability card render
  // ================================================================

  function renderCard(card) {
    var iconCls = CARD_STATE_TO_CLASS[card.state] || '';
    var pillCls = CARD_STATE_TO_CLASS[card.state] || 'is-idle';

    var root = el('article', {
      className: 'cap-card',
      dataset: { cardId: card.id }
    });

    // Icon
    root.appendChild(el('div', {
      className: 'cap-icon ' + iconCls
    }, [ svgInline(CARD_ICON_PATHS[card.id] || CARD_ICON_PATHS.other, 20) ]));

    // Body
    var body = el('div', { className: 'cap-body' });
    var header = el('div', { className: 'cap-header' });
    header.appendChild(el('div', {
      className: 'cap-title',
      text: card.title || card.id
    }));
    header.appendChild(el('span', {
      className: 'cap-state ' + pillCls,
      text: card.state_label || card.state || ''
    }));
    body.appendChild(header);

    if (card.summary) {
      body.appendChild(el('div', { className: 'cap-summary', text: card.summary }));
    }

    if (card.metrics && card.metrics.length) {
      var m = el('div', { className: 'cap-metrics' });
      card.metrics.forEach(function (mm) {
        if (!mm) return;
        if (mm.value == null) return;
        var n = Number(mm.value);
        if (!isFinite(n)) return;
        var metric = el('span', { className: 'cap-metric' });
        metric.appendChild(el('span', {
          className: 'cap-metric-value',
          text: String(n)
        }));
        metric.appendChild(document.createTextNode(mm.label || ''));
        m.appendChild(metric);
      });
      body.appendChild(m);
    }
    root.appendChild(body);

    // Actions
    if (card.primary_action || card.secondary_action) {
      var actions = el('div', { className: 'cap-actions' });
      if (card.secondary_action) {
        var sa = renderActionButton(card.secondary_action, 'btn-ghost');
        actions.appendChild(sa);
      }
      if (card.primary_action) {
        var pa = renderActionButton(card.primary_action, 'btn-primary');
        actions.appendChild(pa);
      }
      root.appendChild(actions);
    }

    return root;
  }

  function renderActionButton(action, baseClass) {
    var cls = baseClass;
    if (action.kind === 'danger') cls = 'btn-danger';
    var btn = el('button', { className: 'btn ' + cls, attrs: { type: 'button' } });
    btn.appendChild(document.createTextNode(action.label || ''));
    if (action.callback) {
      btn.setAttribute('data-action', action.callback);
    }
    if (action.enabled === false) {
      btn.setAttribute('disabled', 'disabled');
    }
    return btn;
  }

  function renderCards(gridEl, cards) {
    clearChildren(gridEl);
    if (!cards || !cards.length) {
      // Truthful fallback: the presenter SHOULD always emit
      // exactly 5 cards in fixed order; if not, render an
      // empty placeholder so the user sees something.
      var empty = el('div', { className: 'cap-card' });
      empty.appendChild(el('div', { className: 'cap-icon is-idle' },
        [ svgInline(CARD_ICON_PATHS.other, 20) ]));
      var b = el('div', { className: 'cap-body' });
      b.appendChild(el('div', { className: 'cap-title', text: '处理能力' }));
      b.appendChild(el('div', { className: 'cap-summary', text: '尚未加载' }));
      empty.appendChild(b);
      gridEl.appendChild(empty);
      return;
    }
    cards.forEach(function (c) {
      gridEl.appendChild(renderCard(c));
    });
  }

  // ================================================================
  // 4. Top issue summary (error-only per dispatch §8)
  // ================================================================

  function renderIssueSummary(container, summary) {
    clearChildren(container);
    if (!summary) return;

    if (summary.kind === 'clean') {
      container.className = 'issue-summary is-clean';
      var t = el('div', { className: 'issue-summary-text' });
      t.appendChild(el('div', {
        className: 'issue-summary-headline',
        text: summary.headline || 'CAD 状态良好'
      }));
      t.appendChild(el('div', {
        className: 'cap-summary',
        text: summary.subtitle || '未发现需要处理的问题'
      }));
      container.appendChild(t);
      return;
    }

    if (summary.kind === 'empty-idle') {
      container.className = 'issue-summary is-empty';
      var tt = el('div', { className: 'issue-summary-text' });
      tt.appendChild(el('div', {
        className: 'issue-summary-headline',
        text: summary.headline || 'CAD 尚未处理'
      }));
      tt.appendChild(el('div', {
        className: 'cap-summary',
        text: summary.subtitle || ''
      }));
      container.appendChild(tt);
      return;
    }

    // kind === 'issues'
    container.className = 'issue-summary';
    var left = el('div', { className: 'issue-summary-text' });
    left.appendChild(el('div', {
      className: 'issue-summary-headline',
      text: summary.headline || '发现需要处理的问题'
    }));
    if (summary.chips && summary.chips.length) {
      var list = el('div', { className: 'issue-summary-list' });
      summary.chips.forEach(function (c) {
        if (!c) return;
        var n = Number(c.value);
        if (!isFinite(n) || n <= 0) return; // error-only
        var chip = el('span', { className: 'issue-summary-chip' });
        chip.appendChild(el('span', {
          className: 'issue-summary-chip-num',
          text: String(n)
        }));
        chip.appendChild(document.createTextNode(c.label || ''));
        list.appendChild(chip);
      });
      if (list.firstChild) left.appendChild(list);
    }
    container.appendChild(left);

    if (summary.cta) {
      var right = el('div', { className: 'cta-actions' });
      var b = el('button', {
        className: 'btn btn-secondary',
        attrs: { type: 'button', 'data-action': 'rebuild_workspace' }
      });
      b.appendChild(document.createTextNode(summary.cta));
      right.appendChild(b);
      container.appendChild(right);
    }
  }

  // ================================================================
  // 5. Issues / Layers / Details render
  // ================================================================

  function renderIssuesList(container, items) {
    clearChildren(container);
    if (!items || !items.length) {
      var empty = el('div', { className: 'issue-row is-empty' });
      empty.appendChild(document.createTextNode('当前没有未解决问题'));
      container.appendChild(empty);
      return;
    }
    items.forEach(function (it) {
      var row = el('div', {
        className: 'issue-row' + (it.locatable ? '' : ' no-action'),
        attrs: { 'data-locatable': it.locatable ? 'true' : 'false' }
      });
      if (it.issue_id) {
        row.setAttribute('data-issue-id', it.issue_id);
      }
      var iconClass = it.severity === 'err' ? 'is-err'
                    : it.severity === 'warn' ? 'is-warn'
                    : it.severity === 'ok' ? 'is-ok' : '';
      row.appendChild(el('div', {
        className: 'issue-row-icon ' + iconClass
      }, [ svgInline(it.icon || CARD_ICON_PATHS.other, 16) ]));
      var body = el('div', { className: 'issue-row-body' });
      body.appendChild(el('div', { className: 'issue-row-title', text: it.title || '' }));
      body.appendChild(el('div', { className: 'issue-row-desc',  text: it.desc  || '' }));
      row.appendChild(body);

      // Per CodeX Round 020 L3: only register a click handler
      // on LOCATABLE rows. Non-locatable rows are inert.
      if (it.locatable && it.issue_id && window.sketchup &&
          typeof window.sketchup.locate === 'function') {
        row.addEventListener('click', function () {
          try {
            window.sketchup.locate(it.issue_id);
          } catch (e) {
            // Defensive: never crash the UI on a callback
            // failure.
            _toast('定位失败: ' + (e && e.message ? e.message : e), 'err');
          }
        });
      }

      if (it.action) {
        var acts = el('div', { className: 'issue-row-actions' });
        var btn = el('button', {
          className: 'btn ' + (it.action.kind === 'danger' ? 'btn-danger' : 'btn-secondary'),
          attrs: { type: 'button' }
        });
        btn.appendChild(document.createTextNode(it.action.label || ''));
        if (it.action.callback) {
          btn.setAttribute('data-action', it.action.callback);
        }
        if (it.action.enabled === false) {
          btn.setAttribute('disabled', 'disabled');
        }
        acts.appendChild(btn);
        row.appendChild(acts);
      }
      container.appendChild(row);
    });
  }

  function renderLayerList(container, layers) {
    clearChildren(container);
    if (!layers || !layers.length) {
      var empty = el('div', { className: 'issue-row is-empty' });
      empty.appendChild(document.createTextNode('当前没有图层信息'));
      container.appendChild(empty);
      return;
    }
    layers.forEach(function (l) {
      var row = el('div', { className: 'layer-row' });
      row.appendChild(el('div', { className: 'layer-row-name', text: l.name || '' }));
      var roleLabel = LAYER_ROLE_LABELS_CN[l.role] || l.role_label || l.role || '未知';
      var roleKnown = (l.role_known !== false && l.role !== 'unknown');
      row.appendChild(el('span', {
        className: 'layer-row-role ' + (roleKnown ? 'is-known' : 'is-unknown'),
        text: roleLabel
      }));
      var vis = el('div', {
        className: 'layer-row-vis' + (l.visible ? '' : ' is-hidden')
      });
      vis.appendChild(document.createTextNode(l.visible ? '可见' : '隐藏'));
      row.appendChild(vis);
      if (l.edge_count != null) {
        row.appendChild(el('div', {
          className: 'layer-row-count',
          text: l.edge_count + ' 条边'
        }));
      } else if (l.count != null) {
        row.appendChild(el('div', {
          className: 'layer-row-count',
          text: l.count + ' 项'
        }));
      }
      container.appendChild(row);
    });
  }

  function renderKvList(container, rows) {
    clearChildren(container);
    if (!rows || !rows.length) {
      var empty = el('div', { className: 'audit-row' });
      empty.appendChild(el('span', { className: 'audit-row-key', text: '(empty)' }));
      empty.appendChild(el('span', { className: 'audit-row-value', text: '' }));
      container.appendChild(empty);
      return;
    }
    rows.forEach(function (r) {
      var row = el('div', { className: 'audit-row' });
      row.appendChild(el('span', { className: 'audit-row-key', text: r.k || '' }));
      row.appendChild(el('span', { className: 'audit-row-value', text: r.v == null ? '' : String(r.v) }));
      container.appendChild(row);
    });
  }

  // ================================================================
  // 6. Tab switching
  // ================================================================

  function switchTab(tabId) {
    var tabMap = {
      'process': { btn: 'tab-process',  panel: 'panel-process' },
      'issues':  { btn: 'tab-issues',   panel: 'panel-issues'  },
      'layers':  { btn: 'tab-layers',   panel: 'panel-layers'  },
      'details': { btn: 'tab-details',  panel: 'panel-details' }
    };
    Object.keys(tabMap).forEach(function (k) {
      var m = tabMap[k];
      var btn = document.getElementById(m.btn);
      var panel = document.getElementById(m.panel);
      if (!btn || !panel) return;
      if (k === tabId) {
        btn.setAttribute('aria-selected', 'true');
        panel.removeAttribute('hidden');
      } else {
        btn.setAttribute('aria-selected', 'false');
        panel.setAttribute('hidden', '');
      }
    });
  }

  // ================================================================
  // 7. Toast (preserved from V1.4 contract)
  // ================================================================

  function _toast(message, kind) {
    var t = document.getElementById('toast');
    if (!t) return;
    clearChildren(t);
    t.textContent = String(message == null ? '' : message);
    t.className = 'toast' + (kind === 'err' ? ' is-err' : (kind === 'warn' ? ' is-warn' : ''));
    t.removeAttribute('hidden');
    // Auto-hide after 4s.
    if (_toast._hider) {
      try { clearTimeout(_toast._hider); } catch (e) {}
    }
    _toast._hider = setTimeout(function () {
      try { t.setAttribute('hidden', ''); } catch (e) {}
    }, 4000);
  }

  // ================================================================
  // 8. Main render entry — window.SUAIP.render(payload)
  // ================================================================

  function _setText(id, text) {
    var n = document.getElementById(id);
    if (n) n.textContent = text == null ? '' : String(text);
  }

  function _setAttr(id, name, value) {
    var n = document.getElementById(id);
    if (!n) return;
    if (value == null) {
      n.removeAttribute(name);
    } else {
      n.setAttribute(name, String(value));
    }
  }

  function _show(el, yes) {
    if (!el) return;
    if (yes) el.removeAttribute('hidden');
    else el.setAttribute('hidden', '');
  }

  function _dispatchCallback(action) {
    if (!action) return;
    if (!window.sketchup || typeof window.sketchup[action] !== 'function') {
      _toast('当前 SketchUp 环境下不可用: ' + action, 'warn');
      return;
    }
    try {
      window.sketchup[action]();
    } catch (e) {
      _toast('调用失败: ' + (e && e.message ? e.message : e), 'err');
    }
  }

  function _bindActions(root) {
    // Generic delegated click handler for any descendant
    // element with a data-action attribute. The frontend
    // DOES NOT maintain a JS-side state machine — each
    // action just calls the matching existing
    // window.sketchup.<callback> and the host re-pushes
    // a fresh payload.
    var nodes = root.querySelectorAll('[data-action]');
    nodes.forEach(function (n) {
      // Avoid double-binding (some elements were bound
      // explicitly in renderCard / renderIssuesList etc.).
      if (n.__v19a_bound) return;
      n.__v19a_bound = true;
      n.addEventListener('click', function (ev) {
        var action = n.getAttribute('data-action');
        if (!action) return;
        // The view_issues pseudo-action is intercepted by
        // the frontend to switch to the 问题 tab.
        if (action === 'view_issues') {
          ev.preventDefault();
          switchTab('issues');
          return;
        }
        if (action === 'primary_cta') {
          // The CTA's actual callback is determined by the
          // cadPrepWorkflow primary_cta.callback; the data-action
          // attribute on btn-primary-cta is rewritten by render().
          var cta = n.getAttribute('data-action-callback') || '';
          if (!cta) return;
          ev.preventDefault();
          _dispatchCallback(cta);
          return;
        }
        ev.preventDefault();
        _dispatchCallback(action);
      });
    });
  }

  function _buildIssueRows(payload, cadPrep) {
    // Current unresolved / relevant issues first. Priority:
    //   1. Cards that are REVIEW_REQUIRED / FAILED (per
    //      cadPrepWorkflow.cards).
    //   2. ACTIONABLE items (without a separate issue row;
    //      the action lives on the card).
    //   3. Legacy groups (raw issue Registry) for the
    //      "原始检查记录" block.
    var rows = [];
    var cards = (cadPrep && cadPrep.cards) || [];
    cards.forEach(function (c) {
      if (!c) return;
      if (c.state === 'REVIEW_REQUIRED') {
        rows.push({
          severity: 'warn',
          title:    c.title + ' · 需要人工查看',
          desc:     c.summary,
          locatable: false,
          issue_id: null,
          icon: CARD_ICON_PATHS[c.id] || CARD_ICON_PATHS.other,
          action:   c.primary_action || c.secondary_action
        });
      } else if (c.state === 'FAILED') {
        rows.push({
          severity: 'err',
          title:    c.title + ' · 处理失败',
          desc:     c.summary,
          locatable: false,
          issue_id: null,
          icon: CARD_ICON_PATHS[c.id] || CARD_ICON_PATHS.other
        });
      }
    });

    // Legacy raw groups (preserve V1.0-V1.4 issue rows).
    var groups = payload.groups || [];
    groups.forEach(function (g) {
      if (!g || !g.issues) return;
      g.issues.forEach(function (iss) {
        if (!iss) return;
        if (iss.locatable) {
          rows.push({
            severity: iss.severity || 'info',
            title:    iss.message || iss.issue_type || iss.issue_id || '',
            desc:     iss.issue_type || '',
            locatable: true,
            issue_id: iss.issue_id,
            icon: CARD_ICON_PATHS.other
          });
        } else {
          rows.push({
            severity: iss.severity || 'info',
            title:    iss.message || iss.issue_type || iss.issue_id || '',
            desc:     iss.issue_type || '',
            locatable: false,
            issue_id: iss.issue_id,
            icon: CARD_ICON_PATHS.other
          });
        }
      });
    });
    return rows;
  }

  function _buildLegacySourceRows(payload) {
    // Compact per-issue-type counts (legacy V1.0-V1.4
    // "raw inventory"-style summary).
    var rows = [];
    var summary = payload.summary || {};
    var issues = summary.issues || {};
    Object.keys(issues).forEach(function (k) {
      rows.push({ k: k, v: String(issues[k]) });
    });
    if (typeof summary.edges === 'number') {
      rows.push({ k: 'edges', v: String(summary.edges) });
    }
    if (typeof summary.vertices === 'number') {
      rows.push({ k: 'vertices', v: String(summary.vertices) });
    }
    if (typeof summary.non_zero_z_vertices === 'number') {
      rows.push({ k: 'non_zero_z_vertices', v: String(summary.non_zero_z_vertices) });
    }
    if (typeof summary.warnings === 'number') {
      rows.push({ k: 'warnings', v: String(summary.warnings) });
    }
    return rows;
  }

  function _buildDetailsKv(payload, cadPrep) {
    var rows = [];
    var dw = payload.derivedWorkspace || {};
    if (dw.source_snapshot_id) {
      rows.push({ k: 'source_snapshot_id', v: dw.source_snapshot_id });
    }
    if (dw.source_fingerprint_digest) {
      rows.push({ k: 'source_fingerprint', v: dw.source_fingerprint_digest });
    }
    if (dw.execution_config_digest) {
      rows.push({ k: 'config_digest', v: dw.execution_config_digest });
    }
    if (dw.workspace_id) {
      rows.push({ k: 'workspace_id', v: dw.workspace_id });
    }
    if (dw.last_error) {
      rows.push({ k: 'last_error', v: dw.last_error });
    }
    if (typeof dw.entity_count === 'number') {
      rows.push({ k: 'entity_count', v: String(dw.entity_count) });
    }
    if (cadPrep && cadPrep.schema_version) {
      rows.push({ k: 'cadPrepWorkflow.schema_version', v: cadPrep.schema_version });
    }
    if (cadPrep && cadPrep.overall_state) {
      rows.push({ k: 'cadPrepWorkflow.overall_state', v: cadPrep.overall_state });
    }
    if (cadPrep && cadPrep.headline) {
      rows.push({ k: 'cadPrepWorkflow.headline', v: cadPrep.headline });
    }
    return rows;
  }

  function _buildRawInventoryKv(payload) {
    var rows = [];
    var summary = payload.summary || {};
    Object.keys(summary).forEach(function (k) {
      // Skip nested `issues` Hash (already shown elsewhere).
      if (k === 'issues') return;
      var v = summary[k];
      var s;
      if (v == null) {
        s = '';
      } else if (typeof v === 'object') {
        s = JSON.stringify(v);
      } else {
        s = String(v);
      }
      rows.push({ k: k, v: s });
    });
    return rows;
  }

  function _buildWorkspaceKv(payload) {
    var rows = [];
    var dw = payload.derivedWorkspace || {};
    Object.keys(dw).forEach(function (k) {
      if (k === 'duplicate_repair' || k === 'planar_normalization' ||
          k === 'topology_repair'   || k === 'structure_reconstruction') {
        // Rendered under their own audit blocks below.
        return;
      }
      var v = dw[k];
      var s;
      if (v == null) {
        s = '';
      } else if (typeof v === 'object') {
        s = JSON.stringify(v);
      } else {
        s = String(v);
      }
      rows.push({ k: k, v: s });
    });
    return rows;
  }

  function _buildRepairHistoryKv(payload) {
    var rows = [];
    var dw = payload.derivedWorkspace || {};
    // Duplicate repair summary.
    var dr = dw.duplicate_repair;
    if (dr && typeof dr === 'object') {
      rows.push({ k: 'duplicate_repair.actions_applied', v: String(dr.actions_applied || 0) });
      rows.push({ k: 'duplicate_repair.actions_skipped', v: String(dr.actions_skipped || 0) });
      rows.push({ k: 'duplicate_repair.actions_failed',  v: String(dr.actions_failed  || 0) });
      if (dr.duplicate_pairs_before != null) {
        rows.push({ k: 'duplicate_repair.pairs_before', v: String(dr.duplicate_pairs_before) });
      }
      if (dr.duplicate_pairs_after != null) {
        rows.push({ k: 'duplicate_repair.pairs_after', v: String(dr.duplicate_pairs_after) });
      }
      if (dr.tolerance_status) {
        rows.push({ k: 'duplicate_repair.tolerance_status', v: String(dr.tolerance_status) });
      }
    } else {
      rows.push({ k: 'duplicate_repair', v: '未执行' });
    }
    // Planar normalization.
    var pn = dw.planar_normalization;
    if (pn && typeof pn === 'object') {
      rows.push({ k: 'planar_normalization.state',    v: String(pn.state || 'NOT_COMPUTED') });
      rows.push({ k: 'planar_normalization.computed', v: String(!!pn.computed) });
    } else {
      rows.push({ k: 'planar_normalization', v: '未执行' });
    }
    // Topology repair.
    var tr = dw.topology_repair;
    if (tr && typeof tr === 'object') {
      rows.push({ k: 'topology_repair.state',    v: String(tr.state || 'NOT_COMPUTED') });
      rows.push({ k: 'topology_repair.computed', v: String(!!tr.computed) });
    } else {
      rows.push({ k: 'topology_repair', v: '未执行' });
    }
    return rows;
  }

  function _buildCanonicalKv(payload) {
    var rows = [];
    var dw = payload.derivedWorkspace || {};
    var sr = dw.structure_reconstruction;
    if (sr && typeof sr === 'object') {
      rows.push({ k: 'structure_reconstruction.state',    v: String(sr.state || 'NOT_COMPUTED') });
      rows.push({ k: 'structure_reconstruction.computed', v: String(!!sr.computed) });
      if (sr.digest) {
        rows.push({ k: 'structure_reconstruction.digest', v: String(sr.digest) });
      }
      if (sr.canonical_graph_digest) {
        rows.push({ k: 'canonical_graph_digest', v: String(sr.canonical_graph_digest) });
      }
      if (sr.metrics && typeof sr.metrics === 'object') {
        Object.keys(sr.metrics).forEach(function (k) {
          rows.push({
            k: 'structure_reconstruction.metrics.' + k,
            v: JSON.stringify(sr.metrics[k])
          });
        });
      }
    } else {
      rows.push({ k: 'structure_reconstruction', v: '未执行' });
    }
    // V1.7 canonical graph digest (when available).
    var tr = dw.topology_repair;
    if (tr && typeof tr === 'object' && tr.canonical_graph) {
      var cg = tr.canonical_graph;
      if (cg.digest)         rows.push({ k: 'canonical_graph.digest',         v: String(cg.digest) });
      if (cg.schema_version) rows.push({ k: 'canonical_graph.schema_version', v: String(cg.schema_version) });
    }
    return rows;
  }

  function _primaryCtaFor(overallState) {
    var map = {
      IDLE:                 { label: '开始处理', callback: 'prepare_workspace', enabled: true  },
      SCANNING:             { label: '正在准备...', callback: 'prepare_workspace', enabled: false },
      NEEDS_ATTENTION:      { label: '重新检测', callback: 'rebuild_workspace', enabled: true  },
      READY_FOR_VALIDATION: { label: '重新检测', callback: 'rebuild_workspace', enabled: true  },
      STALE:                { label: '重新检测', callback: 'rebuild_workspace', enabled: false },
      FAILED:               { label: '重新检测', callback: 'rebuild_workspace', enabled: true  }
    };
    return map[overallState] || map.IDLE;
  }

  function _buildIssuesBadgeCount(cadPrep, payload) {
    var n = 0;
    var cards = (cadPrep && cadPrep.cards) || [];
    cards.forEach(function (c) {
      if (!c) return;
      if (c.state === 'REVIEW_REQUIRED' || c.state === 'FAILED') n++;
    });
    var groups = payload.groups || [];
    groups.forEach(function (g) {
      if (g && g.count) n += Number(g.count) || 0;
    });
    return n;
  }

  function render(payload) {
    // Defensive: tolerate missing cadPrepWorkflow (older
    // dialog_runner / test payloads). Show IDLE.
    var cadPrep = (payload && payload.cadPrepWorkflow) || null;
    var overall = (cadPrep && cadPrep.overall_state) || 'IDLE';
    var overallLabel = OVERALL_STATE_LABELS_CN[overall] || overall;

    // --- Header ---
    var sel = (cadPrep && cadPrep.selection) || {};
    var selLabel = sel.label && sel.label.length ? sel.label : '尚未选择';
    _setText('selection-value', selLabel);
    var statusChip = document.getElementById('status-chip');
    var statusText = document.getElementById('status-text');
    if (statusChip) statusChip.setAttribute('data-state', overall);
    if (statusText) statusText.textContent = overallLabel;

    // --- CTA row ---
    _setText('cta-headline', (cadPrep && cadPrep.headline) || 'CAD 尚未处理');
    _setText('cta-sub',      (cadPrep && cadPrep.subheadline) || '');
    var primaryBtn = document.getElementById('btn-primary-cta');
    var primaryText = document.getElementById('btn-primary-cta-text');
    var cta = _primaryCtaFor(overall);
    if (primaryText) primaryText.textContent = cta.label;
    if (primaryBtn) {
      primaryBtn.setAttribute('data-action', 'primary_cta');
      primaryBtn.setAttribute('data-action-callback', cta.callback);
      if (cta.enabled) {
        primaryBtn.removeAttribute('disabled');
      } else {
        primaryBtn.setAttribute('disabled', 'disabled');
      }
    }

    // --- Recovery banner ---
    var banner = document.getElementById('recovery-banner');
    var recovery = cadPrep && cadPrep.recovery;
    if (recovery) {
      _show(banner, true);
      banner.className = 'recovery-banner' + (overall === 'FAILED' ? ' is-failed' : '');
      _setText('recovery-title', recovery.title || '');
      _setText('recovery-desc',  recovery.desc  || '');
      var rb = document.getElementById('btn-rebuild');
      if (rb) rb.setAttribute('data-action', recovery.primary_callback || 'rebuild_workspace');
      var rd = document.getElementById('btn-discard');
      if (rd) rd.setAttribute('data-action', recovery.secondary_callback || 'discard_workspace');
    } else {
      _show(banner, false);
    }

    // --- Issue summary ---
    renderIssueSummary(document.getElementById('issue-summary'),
                       cadPrep && cadPrep.issue_summary);

    // --- Capability cards ---
    renderCards(document.getElementById('capability-grid'),
                cadPrep && cadPrep.cards);

    // --- Issues tab ---
    renderIssuesList(document.getElementById('issues-list'),
                     _buildIssueRows(payload, cadPrep));
    renderKvList(document.getElementById('audit-source-body'),
                 _buildLegacySourceRows(payload));

    // --- Layers tab (legacy layerGroups payload). ---
    renderLayerList(document.getElementById('layer-list'),
                    payload.layerGroups || []);

    // --- Details tab (audit blocks). ---
    renderKvList(document.getElementById('audit-source-details-body'),
                 _buildDetailsKv(payload, cadPrep));
    renderKvList(document.getElementById('audit-raw-inventory-body'),
                 _buildRawInventoryKv(payload));
    renderKvList(document.getElementById('audit-workspace-body'),
                 _buildWorkspaceKv(payload));
    renderKvList(document.getElementById('audit-repair-history-body'),
                 _buildRepairHistoryKv(payload));
    renderKvList(document.getElementById('audit-canonical-body'),
                 _buildCanonicalKv(payload));
    renderKvList(document.getElementById('audit-source-issues-details-body'),
                 _buildLegacySourceRows(payload));

    // --- Tab badges ---
    var badge = document.getElementById('tab-issues-badge');
    var badgeCount = _buildIssuesBadgeCount(cadPrep, payload);
    if (badge) {
      if (badgeCount > 0) {
        badge.removeAttribute('hidden');
        badge.textContent = String(badgeCount);
      } else {
        badge.setAttribute('hidden', '');
        badge.textContent = '0';
      }
    }

    // --- Wire action buttons ---
    var appShell = document.getElementById('app-shell');
    if (appShell) _bindActions(appShell);
  }

  // ================================================================
  // 9. Wire up (tab clicks + ready handshake)
  // ================================================================

  function init() {
    // Tab clicks
    document.querySelectorAll('.tab-item').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var tab = btn.getAttribute('data-tab');
        if (tab) switchTab(tab);
      });
    });

    // V1.4 ready handshake: signal host that DOM is ready
    // and the host can begin pushing payloads via
    // window.SUAIP.render(json). We call ready() exactly
    // once, after DOMContentLoaded, via the existing
    // callback path.
    if (window.sketchup && typeof window.sketchup.ready === 'function') {
      try {
        window.sketchup.ready();
      } catch (e) {
        // Defensive: never crash the UI on handshake failure.
        _toast('ready 握手失败: ' + (e && e.message ? e.message : e), 'err');
      }
    }
  }

  // Expose on window.SUAIP (preserved from V1.4 contract).
  ROOT.render = render;
  ROOT.toast  = _toast;

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
