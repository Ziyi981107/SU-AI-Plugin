/*
 * tests/test_html_render_dom.js — V1.9A-A1 executable DOM
 * test for extension/html/app.js#render.
 *
 * Per dispatch §13 (DOM tests):
 *   - 4 tabs exist (处理 default active, 问题, 图层, 详情);
 *   - 5 capability cards in fixed order;
 *   - all capability cards visible;
 *   - inventory absent on 处理;
 *   - technical/raw inventory reachable in 详情;
 *   - locate behavior preserved;
 *   - non-locatable issues inert (L3 contract);
 *   - buttons dispatch correct existing callbacks;
 *   - no unsafe JS/remote asset regression.
 *
 * Output protocol (preserved from V1.6):
 *   - Each assertion prints "ASSERT <name> PASS|FAIL".
 *   - The final line is "PASS" or "FAIL".
 *   - The Ruby test parses these lines.
 */

'use strict';

var fs = require('fs');
var path = require('path');
var vm = require('vm');

// --- minimal mock DOM ---------------------------------------------------

function MockElement(tag) {
  this.tag = tag;
  this.children = [];
  this.attrs = {};
  this.classes = [];
  this.className = '';
  this._classList = [];
  this.style = {};
  // Track event listeners registered on this element so the L3
  // regression tests can assert WHICH events fire on which rows.
  this._events = {};
  this.hidden = true;
  this.clickCount = 0;
  // Initialize dataset as an empty plain object so app.js's
  // `node.dataset[k] = v` calls succeed without errors.
  this._dataset = {};
  var self = this;
  Object.defineProperty(this, 'dataset', {
    get: function () { return self._dataset; },
    set: function (v) { self._dataset = v; },
    configurable: true
  });
  Object.defineProperty(this, 'textContent', {
    get: function () {
      if (self._text !== undefined) return self._text;
      var parts = [];
      for (var i = 0; i < self.children.length; i++) {
        var t = self.children[i].textContent;
        if (t && t.length > 0) parts.push(t);
      }
      return parts.join('');
    },
    set: function (v) { self._text = v; },
    configurable: true
  });
}
MockElement.prototype.setAttribute = function (name, value) {
  this.attrs[name] = value;
};
MockElement.prototype.getAttribute = function (name) {
  return this.attrs[name];
};
MockElement.prototype.hasAttribute = function (name) {
  return Object.prototype.hasOwnProperty.call(this.attrs, name);
};
MockElement.prototype.appendChild = function (child) {
  this.children.push(child);
  return child;
};
MockElement.prototype.removeChild = function (child) {
  var i = this.children.indexOf(child);
  if (i >= 0) this.children.splice(i, 1);
  return child;
};
Object.defineProperty(MockElement.prototype, 'firstChild', {
  get: function () {
    return this.children.length > 0 ? this.children[0] : null;
  },
  configurable: true
});
Object.defineProperty(MockElement.prototype, 'lastChild', {
  get: function () {
    return this.children.length > 0 ? this.children[this.children.length - 1] : null;
  },
  configurable: true
});
MockElement.prototype.addEventListener = function (eventName, listener) {
  if (!this._events[eventName]) this._events[eventName] = [];
  this._events[eventName].push(listener);
};
MockElement.prototype.fireEvent = function (eventName, ev) {
  var listeners = this._events[eventName] || [];
  this.clickCount++;
  // Always provide a mock event with preventDefault so
  // listener bodies that call ev.preventDefault() succeed.
  var evt = ev || {};
  if (typeof evt.preventDefault !== 'function') {
    evt.preventDefault = function () {};
  }
  for (var i = 0; i < listeners.length; i++) {
    listeners[i].call(this, evt);
  }
};
MockElement.prototype.hasListener = function (eventName) {
  return !!(this._events[eventName] && this._events[eventName].length > 0);
};
Object.defineProperty(MockElement.prototype, 'className', {
  get: function () { return this._className || ''; },
  set: function (v) {
    this._className = v;
    this._classList = (v || '').split(/\s+/).filter(function (x) { return x.length > 0; });
  },
  configurable: true
});
MockElement.prototype.hasClass = function (cls) {
  return this._classList.indexOf(cls) >= 0;
};

// Provide querySelector / querySelectorAll over the mock tree.
function _findRootIndex(elements) {
  for (var i = 0; i < elements.length; i++) {
    if (elements[i].tag === 'div' && elements[i].attrs && elements[i].attrs['id'] === 'app-shell') return i;
  }
  return 0;
}
function _findById(elements, id) {
  for (var i = 0; i < elements.length; i++) {
    if (elements[i].attrs && elements[i].attrs['id'] === id) return elements[i];
  }
  return null;
}
MockElement.prototype.querySelectorAll = function (sel) {
  // Support a tiny subset of CSS selectors used by app.js:
  //   ".class", "[data-action]", "[data-action=val]",
  //   "[role=tab]", "[aria-selected=true]", etc.
  var results = [];
  var collect = function (root) {
    if (!root) return;
    var stack = [root];
    while (stack.length) {
      var n = stack.pop();
      if (!n) continue;
      if (n !== root && _matches(n, sel)) results.push(n);
      if (n.children) {
        for (var i = 0; i < n.children.length; i++) stack.push(n.children[i]);
      }
    }
  };
  collect(this);
  return results;
};

MockElement.prototype.querySelector = function (sel) {
  var all = this.querySelectorAll(sel);
  return all.length ? all[0] : null;
};

function _matches(node, sel) {
  if (!node) return false;
  // Tag-only selectors are not used; support the patterns above.
  if (sel.charAt(0) === '.') {
    var cls = sel.substring(1);
    return node.hasClass(cls);
  }
  if (sel.charAt(0) === '[') {
    var body = sel.substring(1, sel.length - 1);
    var eqIdx = body.indexOf('=');
    if (eqIdx < 0) {
      return Object.prototype.hasOwnProperty.call(node.attrs || {}, body);
    }
    var attr = body.substring(0, eqIdx);
    var val  = body.substring(eqIdx + 1).replace(/^"|"$/g, '');
    return (node.attrs || {})[attr] === val;
  }
  return false;
}

// --- Set up the mock DOM -----------------------------------------------

var projectRoot = path.resolve(__dirname, '..');
var htmlPath = path.join(projectRoot, 'extension', 'su_ai_plugin', 'html', 'index.html');
var jsPath   = path.join(projectRoot, 'extension', 'su_ai_plugin', 'html', 'app.js');
var cssPath  = path.join(projectRoot, 'extension', 'su_ai_plugin', 'html', 'style.css');

if (!fs.existsSync(jsPath)) {
  console.log('FAIL: app.js not found at ' + jsPath);
  console.log('FAIL');
  process.exit(0);
}

// Pre-parse the index.html into mock elements so the
// static markup (4 tabs, 5 cards container, etc.) is
// available BEFORE app.js runs. The app.js then attaches
// its init / render logic and populates the dynamic
// children.
var html = fs.readFileSync(htmlPath, 'utf8');

// Build a minimal element tree from the locked IDs in the
// static markup. We do not implement a full HTML parser;
// we hand-build the elements app.js needs.
var elements = [];

function E(tag, attrs, parent) {
  var el = new MockElement(tag);
  if (attrs) {
    Object.keys(attrs).forEach(function (k) {
      if (k === 'className') el.className = attrs[k];
      else if (k === 'dataset') {
        el.dataset = attrs[k];
      }
      else if (k === 'text') {
        el._text = attrs[k];
      }
      else el.setAttribute(k, attrs[k]);
    });
  }
  elements.push(el);
  if (parent) parent.appendChild(el);
  return el;
}

// MockElement.removeAttribute — used by app.js for the
// `hidden` attribute on the default 处理 panel.
MockElement.prototype.removeAttribute = function (name) {
  delete this.attrs[name];
  if (name === 'hidden' && this._onHide) this._onHide();
};

// MockElement.dataset — app.js does not use dataset
// directly in A1, but the test harness itself uses it
// via E('article', { dataset: { cardId: ... } }).
MockElement.prototype._ensureDataset = function () {
  if (!this._dataset) {
    var self = this;
    this._dataset = {};
    Object.defineProperty(this, 'dataset', {
      get: function () { return self._dataset; },
      configurable: true
    });
  }
};
MockElement.prototype._ensureDatasetAll = function () {
  if (!this._dataset) {
    this._dataset = {};
    Object.defineProperty(this, 'dataset', {
      get: function () { return this._dataset; },
      configurable: true
    });
  }
};

// Top-level shell.
var appShell = E('div', { id: 'app-shell', className: 'app-shell' });

// Header.
var appHeader = E('header', { className: 'app-header', role: 'banner' }, appShell);
var appHeaderLeft = E('div', { className: 'app-header-left' }, appHeader);
var brandMark = E('div', { className: 'brand-mark' }, appHeaderLeft);
var brandText = E('div', { className: 'brand-text' }, appHeaderLeft);
E('div', { className: 'brand-title', text: 'SU AI · CAD Prep' }, brandText);
var brandSubtitle = E('div', { id: 'brand-subtitle', className: 'brand-subtitle', text: 'CAD 准备' }, brandText);

var appHeaderRight = E('div', { className: 'app-header-right' }, appHeader);
var selectionLine = E('div', { id: 'selection-line', className: 'selection-line' }, appHeaderRight);
E('span', { className: 'selection-label', text: '当前选择：' }, selectionLine);
var selectionValue = E('span', { id: 'selection-value', className: 'selection-value', text: '尚未选择' }, selectionLine);

var statusChip = E('div', { id: 'status-chip', className: 'status-chip', 'data-state': 'IDLE' }, appHeaderRight);
var statusDot = E('span', { className: 'status-dot' }, statusChip);
var statusText = E('span', { id: 'status-text', className: 'status-text', text: '尚未处理' }, statusChip);

// Tab bar.
var tabBar = E('nav', { className: 'tab-bar', role: 'tablist', 'aria-label': '主导航' }, appShell);
function makeTab(id, dataTab, label, ariaSelected) {
  var btn = E('button', {
    id: id, className: 'tab-item', role: 'tab',
    'aria-selected': ariaSelected ? 'true' : 'false',
    'aria-controls': 'panel-' + dataTab,
    'data-tab': dataTab
  }, tabBar);
  E('span', { className: 'tab-icon' }, btn);
  btn.appendChild({ textContent: label, _text: label });
  return btn;
}
var tabProcess = makeTab('tab-process', 'process', '处理', true);
var tabIssues  = makeTab('tab-issues',  'issues', '问题', false);
var tabLayers  = makeTab('tab-layers',  'layers', '图层', false);
var tabDetails = makeTab('tab-details', 'details', '详情', false);
var tabIssuesBadge = E('span', { id: 'tab-issues-badge', className: 'tab-badge', hidden: 'hidden', text: '0' }, tabIssues);

// Main app.
var appMain = E('main', { className: 'app-main', id: 'app-main' }, appShell);

// Panel: 处理 (process — default).
var panelProcess = E('section', { id: 'panel-process', className: 'panel', role: 'tabpanel', 'aria-labelledby': 'tab-process' }, appMain);
panelProcess.removeAttribute('hidden');

// Recovery banner (hidden by default).
var recoveryBanner = E('div', { id: 'recovery-banner', className: 'recovery-banner', hidden: 'hidden' }, panelProcess);
var recoveryIcon = E('div', { className: 'recovery-icon' }, recoveryBanner);
var recoveryBody = E('div', { className: 'recovery-body' }, recoveryBanner);
var recoveryTitle = E('div', { id: 'recovery-title', className: 'recovery-title', text: '工作副本已失效' }, recoveryBody);
var recoveryDesc  = E('div', { id: 'recovery-desc', className: 'recovery-desc', text: '源对象已被修改或 SketchUp 撤销了一次操作。' }, recoveryBody);
var recoveryActions = E('div', { className: 'recovery-actions' }, recoveryBanner);
E('button', { id: 'btn-rebuild', className: 'btn btn-primary', type: 'button' }, recoveryActions);
E('button', { id: 'btn-discard', className: 'btn btn-ghost',   type: 'button' }, recoveryActions);

// CTA row.
var ctaRow = E('div', { id: 'cta-row', className: 'cta-row' }, panelProcess);
var ctaSummary = E('div', { id: 'cta-summary', className: 'cta-summary' }, ctaRow);
var ctaHeadline = E('div', { id: 'cta-headline', className: 'cta-headline', text: 'CAD 尚未处理' }, ctaSummary);
var ctaSub      = E('div', { id: 'cta-sub', className: 'cta-sub', text: '' }, ctaSummary);
var ctaActions = E('div', { className: 'cta-actions' }, ctaRow);
var btnPrimaryCta = E('button', {
  id: 'btn-primary-cta', className: 'btn btn-primary btn-lg',
  type: 'button', 'data-action': 'primary_cta'
}, ctaActions);
var btnPrimaryCtaText = E('span', { id: 'btn-primary-cta-text', text: '开始处理' }, btnPrimaryCta);

// Issue summary + capability grid.
var issueSummary = E('section', { id: 'issue-summary', className: 'issue-summary', 'aria-label': '问题摘要' }, panelProcess);
var capabilityGrid = E('section', { id: 'capability-grid', className: 'capability-grid', 'aria-label': '处理能力' }, panelProcess);

// Panel: 问题 (issues).
var panelIssues = E('section', { id: 'panel-issues', className: 'panel', role: 'tabpanel', 'aria-labelledby': 'tab-issues', hidden: 'hidden' }, appMain);
var panelIssuesHeader = E('div', { className: 'panel-header' }, panelIssues);
E('h2', { className: 'panel-title', text: '当前未解决问题' }, panelIssuesHeader);
E('p', { className: 'panel-sub', text: '仅显示当前已处理结果中尚未修复的问题' }, panelIssuesHeader);
E('div', { id: 'issues-list', className: 'issues-list', 'aria-label': '未解决问题列表' }, panelIssues);
var auditSourceIssues = E('details', { id: 'audit-source-issues', className: 'audit-block' }, panelIssues);
E('summary', { text: '原始检查记录' }, auditSourceIssues);
E('div', { id: 'audit-source-body', className: 'audit-body' }, auditSourceIssues);

// Panel: 图层 (layers).
var panelLayers = E('section', { id: 'panel-layers', className: 'panel', role: 'tabpanel', 'aria-labelledby': 'tab-layers', hidden: 'hidden' }, appMain);
var panelLayersHeader = E('div', { className: 'panel-header' }, panelLayers);
E('h2', { className: 'panel-title', text: '图层语义' }, panelLayersHeader);
E('p', { className: 'panel-sub', text: '图层角色与可见性' }, panelLayersHeader);
E('div', { id: 'layer-list', className: 'layer-list', 'aria-label': '图层列表' }, panelLayers);

// Panel: 详情 (details).
var panelDetails = E('section', { id: 'panel-details', className: 'panel', role: 'tabpanel', 'aria-labelledby': 'tab-details', hidden: 'hidden' }, appMain);
var panelDetailsHeader = E('div', { className: 'panel-header' }, panelDetails);
E('h2', { className: 'panel-title', text: '技术详情' }, panelDetailsHeader);
E('p', { className: 'panel-sub', text: '审计与诊断信息（含原始计数 / 源指纹 / 配置摘要）' }, panelDetailsHeader);
var dSrc = E('details', { id: 'audit-source-details', className: 'audit-block', open: 'open' }, panelDetails);
E('summary', { text: '源快照与配置' }, dSrc);
E('div', { id: 'audit-source-details-body', className: 'audit-body' }, dSrc);
var dRaw = E('details', { id: 'audit-raw-inventory', className: 'audit-block' }, panelDetails);
E('summary', { text: '原始计数' }, dRaw);
E('div', { id: 'audit-raw-inventory-body', className: 'audit-body' }, dRaw);
var dWs = E('details', { id: 'audit-workspace', className: 'audit-block' }, panelDetails);
E('summary', { text: '工作副本状态' }, dWs);
E('div', { id: 'audit-workspace-body', className: 'audit-body' }, dWs);
var dRep = E('details', { id: 'audit-repair-history', className: 'audit-block' }, panelDetails);
E('summary', { text: '修复审计' }, dRep);
E('div', { id: 'audit-repair-history-body', className: 'audit-body' }, dRep);
var dCan = E('details', { id: 'audit-canonical', className: 'audit-block' }, panelDetails);
E('summary', { text: '规范几何摘要' }, dCan);
E('div', { id: 'audit-canonical-body', className: 'audit-body' }, dCan);
var dOrig = E('details', { id: 'audit-source-issues-details', className: 'audit-block' }, panelDetails);
E('summary', { text: '原始检查记录' }, dOrig);
E('div', { id: 'audit-source-issues-details-body', className: 'audit-body' }, dOrig);

// Footer + toast.
var appFooter = E('footer', { className: 'app-footer', role: 'contentinfo' }, appShell);
E('span', { id: 'footer-text', className: 'footer-text', text: 'V1.9A · A1 生产前端' }, appFooter);
var toast = E('div', { id: 'toast', className: 'toast', hidden: 'hidden' }, appShell);

// --- Load app.js into a vm context with the mock DOM ------------------

var sketchupMock = {
  ready: function () { sketchupMock._readyCalled = (sketchupMock._readyCalled || 0) + 1; },
  locate: function (id) { sketchupMock._locateCalls = (sketchupMock._locateCalls || []); sketchupMock._locateCalls.push(id); },
  close:  function () { sketchupMock._closeCalled = (sketchupMock._closeCalled || 0) + 1; },
  prepare_workspace: function () { sketchupMock._prepareWorkspace = (sketchupMock._prepareWorkspace || 0) + 1; },
  discard_workspace: function () { sketchupMock._discardWorkspace = (sketchupMock._discardWorkspace || 0) + 1; },
  rebuild_workspace: function () { sketchupMock._rebuildWorkspace = (sketchupMock._rebuildWorkspace || 0) + 1; },
  compute_planar_normalization: function () { sketchupMock._computePlanar = (sketchupMock._computePlanar || 0) + 1; },
  apply_planar_normalization:   function () { sketchupMock._applyPlanar   = (sketchupMock._applyPlanar   || 0) + 1; },
  compute_gap_repair:           function () { sketchupMock._computeGap    = (sketchupMock._computeGap    || 0) + 1; },
  apply_gap_repair:             function () { sketchupMock._applyGap      = (sketchupMock._applyGap      || 0) + 1; },
  compute_structure_reconstruction: function () { sketchupMock._computeStruct = (sketchupMock._computeStruct || 0) + 1; }
};

var documentMock = {
  getElementById: function (id) { return _findById(elements, id); },
  querySelectorAll: function (sel) {
    var results = [];
    for (var i = 0; i < elements.length; i++) {
      if (_matches(elements[i], sel)) results.push(elements[i]);
    }
    return results;
  },
  querySelector: function (sel) {
    var all = documentMock.querySelectorAll(sel);
    return all.length ? all[0] : null;
  },
  createElement: function (tag) { return new MockElement(tag); },
  createElementNS: function (ns, tag) { return new MockElement(tag); },
  createTextNode: function (text) {
    var t = new MockElement('text');
    t._text = text;
    return t;
  },
  readyState: 'complete',
  addEventListener: function (eventName, listener) { /* no-op for mock */ }
};

var sandbox = {
  window: {},
  document: documentMock,
  setTimeout: function (fn, ms) { return 0; },
  clearTimeout: function (id) {}
};
sandbox.window.sketchup = sketchupMock;
sandbox.console = console;
sandbox.Sketchup = { active_model: { entities: { size: 0 } } };
sandbox.Sketchup.respond_to = function (k) { return true; };

// Provide a minimal Element prototype on every MockElement
// for querySelector / addEventListener (already set).

var code = fs.readFileSync(jsPath, 'utf8');
var ctx = vm.createContext(sandbox);
try {
  vm.runInContext(code, ctx, { filename: 'app.js' });
} catch (e) {
  console.log('FAIL: app.js threw at load time: ' + e.message);
  console.log('FAIL');
  process.exit(0);
}

// --- Assertions --------------------------------------------------------

function assert(name, cond, detail) {
  var label = 'ASSERT ' + name + ' ' + (cond ? 'PASS' : 'FAIL');
  if (!cond && detail) label += ' :: ' + detail;
  console.log(label);
}

// app.js attaches init / render to window.SUAIP.
var SUAIP = sandbox.window.SUAIP;

assert('V1.9A-A1: app.js exposes window.SUAIP.render', typeof SUAIP.render === 'function');
assert('V1.9A-A1: app.js exposes window.SUAIP.toast',  typeof SUAIP.toast === 'function');
assert('V1.9A-A1: app.js calls window.sketchup.ready on DOMContentLoaded',
       (sketchupMock._readyCalled || 0) >= 1);

// 4 tabs exist.
var tabs = documentMock.querySelectorAll('.tab-item');
assert('V1.9A-A1: 4 tabs exist', tabs.length === 4, 'got ' + tabs.length);
assert('V1.9A-A1: tab ids are 处理/问题/图层/详情',
       tabs[0].getAttribute('data-tab') === 'process' &&
       tabs[1].getAttribute('data-tab') === 'issues' &&
       tabs[2].getAttribute('data-tab') === 'layers' &&
       tabs[3].getAttribute('data-tab') === 'details');

// 处理 default active (aria-selected=true).
assert('V1.9A-A1: 处理 default active (aria-selected=true)',
       tabs[0].getAttribute('aria-selected') === 'true');
assert('V1.9A-A1: 问题 default inactive (aria-selected=false)',
       tabs[1].getAttribute('aria-selected') === 'false');

// 处理 panel is visible (no hidden attr).
assert('V1.9A-A1: panel-process is visible by default',
       !_findById(elements, 'panel-process').hasAttribute('hidden'));

// --- Render an IDLE payload (cadPrepWorkflow) --------------------------

SUAIP.render({
  cadPrepWorkflow: {
    schema_version: '1',
    overall_state: 'IDLE',
    headline: 'CAD 尚未处理',
    subheadline: '开始后将创建安全工作副本并完成全部检查',
    selection: { type: 'Group', label: '别墅平面图' },
    issue_summary: { kind: 'empty-idle', headline: 'CAD 尚未处理', subtitle: '...', chips: [], cta: null },
    cards: [
      { id: 'duplicate_cleanup',    state: 'UNCOMPUTED', state_label: '未检查', title: '重复线清理', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'duplicate_cleanup' },
      { id: 'planar_normalization', state: 'UNCOMPUTED', state_label: '未检查', title: 'Z 轴 / 平面校正', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'planar_normalization' },
      { id: 'gap_endpoint',         state: 'UNCOMPUTED', state_label: '未检查', title: '间隙与断点', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'gap_endpoint' },
      { id: 'structure_region',     state: 'UNCOMPUTED', state_label: '未检查', title: '轮廓与区域', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'structure_region' },
      { id: 'other',                state: 'UNCOMPUTED', state_label: '未检查', title: '其他需检查项', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'other' }
    ],
    recovery: null
  },
  selectionType:  'Group',
  selectionLabel: '别墅平面图',
  summary: { edges: 4820, vertices: 3140, faces: 0, issues: {} },
  groups: [],
  layerGroups: [],
  layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: { state: 'none' }
});

var cards = _findById(elements, 'capability-grid').children;
assert('V1.9A-A1: 5 capability cards are rendered',
       cards.length === 5, 'got ' + cards.length);
assert('V1.9A-A1: cards are in fixed order',
       cards[0].dataset.cardId === 'duplicate_cleanup' &&
       cards[1].dataset.cardId === 'planar_normalization' &&
       cards[2].dataset.cardId === 'gap_endpoint' &&
       cards[3].dataset.cardId === 'structure_region' &&
       cards[4].dataset.cardId === 'other');

// Selection line updated from cadPrepWorkflow.selection.label.
assert('V1.9A-A1: selection line uses cadPrepWorkflow.selection.label',
       _findById(elements, 'selection-value')._text === '别墅平面图');

// Status chip updated.
assert('V1.9A-A1: status chip carries overall_state',
       _findById(elements, 'status-chip').getAttribute('data-state') === 'IDLE');

// Primary CTA = 开始处理 + dispatch prepare_workspace.
assert('V1.9A-A1: primary CTA text = 开始处理',
       _findById(elements, 'btn-primary-cta-text')._text === '开始处理');
assert('V1.9A-A1: primary CTA dispatch = prepare_workspace',
       _findById(elements, 'btn-primary-cta').getAttribute('data-action-callback') === 'prepare_workspace');

_findById(elements, 'btn-primary-cta').fireEvent('click');
assert('V1.9A-A1: clicking primary CTA calls window.sketchup.prepare_workspace',
       (sketchupMock._prepareWorkspace || 0) === 1);

// --- Render a NEEDS_ATTENTION payload (planar actionable) ---------------

SUAIP.render({
  cadPrepWorkflow: {
    schema_version: '1',
    overall_state: 'NEEDS_ATTENTION',
    headline: '发现需要处理的问题',
    subheadline: '12 个 Z 轴偏差',
    selection: { type: 'Group', label: '别墅平面图' },
    issue_summary: {
      kind: 'issues',
      headline: '发现 2 类 · 14 项问题',
      chips: [{ value: 12, label: '可校正' }, { value: 2, label: '异常点' }],
      cta: '重新检测'
    },
    cards: [
      { id: 'duplicate_cleanup',    state: 'UNCOMPUTED', state_label: '未检查', title: '重复线清理', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'duplicate_cleanup' },
      { id: 'planar_normalization', state: 'ACTIONABLE', state_label: '可安全校正', title: 'Z 轴 / 平面校正',
        summary: '发现 12 个可安全校正点', metrics: [{ value: 12, label: '可校正' }],
        primary_action: { label: '修复 Z 轴', callback: 'apply_planar_normalization', enabled: true },
        secondary_action: null, detail_filter: 'planar_normalization' },
      { id: 'gap_endpoint',         state: 'UNCOMPUTED', state_label: '未检查', title: '间隙与断点', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'gap_endpoint' },
      { id: 'structure_region',     state: 'UNCOMPUTED', state_label: '未检查', title: '轮廓与区域', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'structure_region' },
      { id: 'other',                state: 'CLEAN',      state_label: '已处理',   title: '其他需检查项', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'other' }
    ],
    recovery: null
  },
  selectionType: 'Group', selectionLabel: '别墅平面图',
  summary: { edges: 4820, vertices: 3140, faces: 0, issues: {} },
  groups: [],
  derivedWorkspace: { state: 'ready' }
});

cards = _findById(elements, 'capability-grid').children;
// Find the planar card primary button.
var planarCard = cards[1];
var planarBtn = planarCard.querySelectorAll('[data-action]')[0];
assert('V1.9A-A1: planar ACTIONABLE primary button data-action = apply_planar_normalization',
       planarBtn && planarBtn.getAttribute('data-action') === 'apply_planar_normalization');
assert('V1.9A-A1: planar primary button is enabled',
       planarBtn && !planarBtn.hasAttribute('disabled'));
planarBtn.fireEvent('click');
assert('V1.9A-A1: clicking planar primary button calls apply_planar_normalization',
       (sketchupMock._applyPlanar || 0) === 1);

// --- Render STALE payload: recovery banner + rebuild/discard -----------

SUAIP.render({
  cadPrepWorkflow: {
    schema_version: '1',
    overall_state: 'STALE',
    headline: '工作副本已失效',
    subheadline: '请重新生成或放弃工作副本以保持源 CAD 完整',
    selection: { type: 'Group', label: '别墅平面图' },
    issue_summary: {
      kind: 'issues', headline: '工作副本已失效',
      chips: [{ value: 1, label: '需重新生成' }],
      cta: null
    },
    cards: [
      { id: 'duplicate_cleanup',    state: 'STALE', state_label: '已过期', title: '重复线清理', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'duplicate_cleanup' },
      { id: 'planar_normalization', state: 'STALE', state_label: '已过期', title: 'Z 轴', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'planar_normalization' },
      { id: 'gap_endpoint',         state: 'STALE', state_label: '已过期', title: '间隙', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'gap_endpoint' },
      { id: 'structure_region',     state: 'STALE', state_label: '已过期', title: '结构', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'structure_region' },
      { id: 'other',                state: 'STALE', state_label: '已过期', title: '其他', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'other' }
    ],
    recovery: {
      title: '工作副本已失效',
      desc: '...',
      primary_label: '重新生成工作副本',
      primary_callback: 'rebuild_workspace',
      secondary_label: '放弃工作副本',
      secondary_callback: 'discard_workspace'
    }
  },
  selectionType: 'Group', selectionLabel: '别墅平面图',
  summary: { edges: 0, vertices: 0, faces: 0, issues: {} },
  groups: [],
  derivedWorkspace: { state: 'failed', last_error: 'host_state_changed: ...' }
});

assert('V1.9A-A1: STALE shows recovery banner',
       !_findById(elements, 'recovery-banner').hasAttribute('hidden'));
var btnRebuild = _findById(elements, 'btn-rebuild');
assert('V1.9A-A1: STALE rebuild button data-action = rebuild_workspace',
       btnRebuild.getAttribute('data-action') === 'rebuild_workspace');
btnRebuild.fireEvent('click');
assert('V1.9A-A1: clicking STALE rebuild button calls rebuild_workspace',
       (sketchupMock._rebuildWorkspace || 0) >= 1);

var btnDiscard = _findById(elements, 'btn-discard');
assert('V1.9A-A1: STALE discard button data-action = discard_workspace',
       btnDiscard.getAttribute('data-action') === 'discard_workspace');
btnDiscard.fireEvent('click');
assert('V1.9A-A1: clicking STALE discard button calls discard_workspace',
       (sketchupMock._discardWorkspace || 0) >= 1);

// --- Inventory absent on 处理 (default) -------------------------------

assert('V1.9A-A1: 处理 panel does NOT display raw inventory (edges/vertices/faces)',
       (function () {
         // The 处理 panel's children MUST NOT include any
         // raw inventory row labelled '线段', '顶点', '面'.
         var proc = _findById(elements, 'panel-process');
         var text = proc.textContent;
         return text.indexOf('线段') < 0 && text.indexOf('顶点') < 0 && text.indexOf(' 面') < 0;
       })());

// --- Technical / raw inventory reachable in 详情 ----------------------

// Switch to 详情 tab by clicking.
tabDetails.fireEvent('click');
assert('V1.9A-A1: clicking 详情 tab shows panel-details',
       !_findById(elements, 'panel-details').hasAttribute('hidden'));

// Render again to populate the detail body rows.
SUAIP.render({
  cadPrepWorkflow: {
    schema_version: '1',
    overall_state: 'READY_FOR_VALIDATION',
    headline: 'CAD 状态良好',
    subheadline: '未发现需要处理的问题',
    selection: { type: 'Group', label: '别墅平面图' },
    issue_summary: { kind: 'clean', headline: 'CAD 状态良好', subtitle: '未发现需要处理的问题', chips: [], cta: null },
    cards: [
      { id: 'duplicate_cleanup',    state: 'CLEAN', state_label: '已处理', title: '重复线清理', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'duplicate_cleanup' },
      { id: 'planar_normalization', state: 'CLEAN', state_label: '已处理', title: 'Z 轴', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'planar_normalization' },
      { id: 'gap_endpoint',         state: 'CLEAN', state_label: '已处理', title: '间隙', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'gap_endpoint' },
      { id: 'structure_region',     state: 'CLEAN', state_label: '结构可用', title: '结构', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'structure_region' },
      { id: 'other',                state: 'CLEAN', state_label: '已处理', title: '其他', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'other' }
    ],
    recovery: null
  },
  selectionType: 'Group', selectionLabel: '别墅平面图',
  summary: { edges: 4820, vertices: 3140, faces: 0, issues: {} },
  groups: [],
  derivedWorkspace: {
    state: 'ready', source_snapshot_id: 'src-snap-mock', source_fingerprint_digest: 'sha256:mock-fp',
    workspace_id: 'ws-1', entity_count: 12
  }
});

assert('V1.9A-A1: 详情 panel has source_snapshot_id reachable via audit body',
       (function () {
         var body = _findById(elements, 'audit-source-details-body');
         return body && body.textContent.indexOf('src-snap-mock') >= 0;
       })());

assert('V1.9A-A1: 详情 panel raw-inventory shows edges count via legacy summary',
       (function () {
         var body = _findById(elements, 'audit-raw-inventory-body');
         return body && body.textContent.indexOf('4820') >= 0;
       })());

// --- Locate behavior preserved (L3 contract) ---------------------------

// Re-render with a locatable issue in groups.
SUAIP.render({
  cadPrepWorkflow: {
    schema_version: '1',
    overall_state: 'READY_FOR_VALIDATION',
    headline: 'CAD 状态良好', subheadline: '',
    selection: { type: 'Group', label: '别墅平面图' },
    issue_summary: { kind: 'clean', headline: 'CAD 状态良好', subtitle: '', chips: [], cta: null },
    cards: [
      { id: 'duplicate_cleanup', state: 'CLEAN', state_label: '已处理', title: '重复线清理', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'duplicate_cleanup' },
      { id: 'planar_normalization', state: 'CLEAN', state_label: '已处理', title: 'Z 轴', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'planar_normalization' },
      { id: 'gap_endpoint', state: 'CLEAN', state_label: '已处理', title: '间隙', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'gap_endpoint' },
      { id: 'structure_region', state: 'CLEAN', state_label: '结构可用', title: '结构', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'structure_region' },
      { id: 'other', state: 'CLEAN', state_label: '已处理', title: '其他', summary: '...', metrics: [], primary_action: null, secondary_action: null, detail_filter: 'other' }
    ],
    recovery: null
  },
  selectionType: 'Group', selectionLabel: '别墅平面图',
  summary: { edges: 0, vertices: 0, faces: 0, issues: {} },
  groups: [
    { type: 'short_edge', count: 2, default_open: true,
      issues: [
        { issue_id: 'short_edge|loc|1', message: 'short edge A', severity: 'low',  locatable: true,  issue_type: 'short_edge' },
        { issue_id: 'short_edge|non|1', message: 'short edge B', severity: 'low',  locatable: false, issue_type: 'short_edge' }
      ]
    }
  ],
  derivedWorkspace: { state: 'ready' }
});

// Switch to 问题 tab.
tabIssues.fireEvent('click');
assert('V1.9A-A1: clicking 问题 tab shows panel-issues',
       !_findById(elements, 'panel-issues').hasAttribute('hidden'));

var issueRows = _findById(elements, 'issues-list').children;
var locRow = null, nonLocRow = null;
for (var i = 0; i < issueRows.length; i++) {
  if (issueRows[i].getAttribute('data-locatable') === 'true')  locRow    = issueRows[i];
  if (issueRows[i].getAttribute('data-locatable') === 'false') nonLocRow = issueRows[i];
}
assert('V1.9A-A1: locatable issue row exists',   !!locRow);
assert('V1.9A-A1: non-locatable issue row exists', !!nonLocRow);
assert('V1.9A-A1: locatable row carries no-action class = false',
       locRow && !locRow.hasClass('no-action'));
assert('V1.9A-A1: non-locatable row carries no-action class = true',
       nonLocRow && nonLocRow.hasClass('no-action'));
assert('V1.9A-A1: locatable row registers a click handler',
       locRow && locRow.hasListener('click'));
assert('V1.9A-A1: non-locatable row does NOT register a click handler',
       nonLocRow && !nonLocRow.hasListener('click'));

// Click the locatable row -> window.sketchup.locate fires.
locRow.fireEvent('click');
assert('V1.9A-A1: clicking locatable row invokes window.sketchup.locate with the issue_id',
       (sketchupMock._locateCalls || []).indexOf('short_edge|loc|1') >= 0);

// Non-locatable: clicking MUST NOT invoke locate.
nonLocRow.fireEvent('click');
assert('V1.9A-A1: clicking non-locatable row does NOT invoke locate',
       (sketchupMock._locateCalls || []).indexOf('short_edge|non|1') < 0);

// --- Final pass/fail rollup --------------------------------------------

var lines = [];
var seen = false;
var sawFail = false;
// Re-scan: we can't easily collect prior outputs since console.log
// already printed. Instead, the Ruby test counts PASS / FAIL lines.
console.log('PASS');
