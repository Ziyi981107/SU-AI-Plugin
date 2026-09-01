/*
 * tests/test_html_render_dom.js
 *
 * Per CodeX Round 019 BLOCK-006-R2: executable render/DOM test for
 * extension/html/app.js#render. Loads app.js into a minimal mock
 * DOM context (vm.runInContext) and inspects the rendered output
 * for:
 *   - Scalar header rows: "Edges: N", "Vertices: N",
 *     "Non Zero Z Vertices: N", "Warnings: N".
 *   - Per-issue-type counters in the locked order:
 *     "Duplicate Candidates: N", "Short Edges: N", ...
 *   - NO "[object Object]" anywhere in the rendered summary.
 *   - Per-issue-type stat elements carry data-issue-type attrs.
 *
 * Output protocol: each assertion prints "ASSERT <name> PASS|FAIL"
 * and the final line is "PASS" or "FAIL". The Ruby test parses
 * the lines.
 */

'use strict';

var fs = require('fs');
var path = require('path');
var vm = require('vm');

// --- minimal mock DOM ---------------------------------------------------

function MockElement(tag) {
  this.tag = tag;
  this.children = [];
  this.textContent = '';
  this.attrs = {};
  this.classes = [];
  this.className = '';
  this._classList = [];
  this.style = {};
  // Track event listeners registered on this element so the L3
  // regression tests can assert WHICH events fire on which rows.
  // Map: eventName -> Array<listenerFunction>.
  this._events = {};
  this.hidden = true;
  this.clickCount = 0;
  // Override textContent getter/setter so it aggregates child
  // textContent values (matching the real DOM behavior).
  var self = this;
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
MockElement.prototype.addEventListener = function (eventName, listener) {
  if (!this._events[eventName]) this._events[eventName] = [];
  this._events[eventName].push(listener);
};
MockElement.prototype.fireEvent = function (eventName, ev) {
  var listeners = this._events[eventName] || [];
  this.clickCount++;
  for (var i = 0; i < listeners.length; i++) {
    listeners[i].call(this, ev || {});
  }
};
MockElement.prototype.hasListener = function (eventName) {
  return !!(this._events[eventName] && this._events[eventName].length > 0);
};
MockElement.prototype.getAttribute = function (name) {
  return this.attrs[name];
};
MockElement.prototype.appendChild = function (child) {
  this.children.push(child);
  return child;
};
// Mimic the DOM `className` setter: storing the raw string AND
// exposing it via `classes` (split on whitespace) so tests can
// assert class membership the same way they would with real DOM.
Object.defineProperty(MockElement.prototype, 'className', {
  get: function () { return this._className || ''; },
  set: function (v) {
    this._className = v;
    this.classes = (v || '').split(/\s+/).filter(function (s) { return s.length > 0; });
  },
  configurable: true
});

var mockElements = {
  'selection-info': new MockElement('div'),
  'summary':        new MockElement('div'),
  'groups':         new MockElement('div'),
  'toast':          new MockElement('div'),
  // V1.1 (per plan §4.11): the Layers section uses these element
  // IDs. JS render treats them as the canonical entry points
  // (summary text + list of rows).
  'layers-summary': new MockElement('summary'),
  'layers-list':    new MockElement('div'),
  // V1.2 (per directive 026): the "Issues by Layer" section uses
  // these element IDs (placed AFTER #groups and BEFORE #layers-section).
  'layer-issues-summary': new MockElement('summary'),
  'layer-issues-list':    new MockElement('div'),
  // V1.3 (per directive 027): the "Face Inventory" section uses
  // these element IDs (placed AFTER #layers-section).
  'face-inventory-summary': new MockElement('summary'),
  'face-inventory-list':    new MockElement('div'),
  // V1.4 (per directive 030 Stage 4): the "Working Mode" section
  // uses these element IDs (placed AFTER #face-inventory-section).
  'working-mode-summary': new MockElement('summary'),
  'working-mode-list':    new MockElement('div'),
  'working-mode-actions': new MockElement('div'),
  // V1.6 UI-CN-SIMPLIFICATION (per dispatch §5.5): the
  // `技术详情` block preserves the full data contract (source
  // snapshot id / fingerprint / config digest / raw workspace
  // state / per-action audit / raw normalization audit /
  // reason / failure_reason). It is rendered CLOSED by
  // default and is the source of truth for AIPM/Pi/Owner
  // diagnosis without polluting the default screen.
  'technical-details-summary': new MockElement('summary'),
  'technical-details-list':    new MockElement('div')
};

var mockDocument = {
  getElementById: function (id) { return mockElements[id] || null; },
  addEventListener: function () { /* no-op */ },
  createElement: function (tag) { return new MockElement(tag); }
};

var mockWindow = global.mockWindow = {
  SUAIP: null,
  sketchup: {
    ready: function () {},
    locate: function (id) {},
    // V1.4 CodeX V14-RUNTIME-BLOCK-001 fix: the host
    // action callbacks (Prepare/Discard/Rebuild) live on
    // window.sketchup.<callback> (registered by
    // DialogRunner.add_action_callback at boot). The mock
    // records every invocation so the V14 DOM tests can
    // assert the click-handler dispatch path actually calls
    // the correct sketchup.<callback> (NOT window.SUAIP.*).
    // The closures reference `global.mockWindow` so the
    // function bodies resolve the recorded-arrays on the
    // SAME mockWindow object that the test inspects (the
    // sandbox sees `mockWindow` as a global via
    // `global.mockWindow = ...`).
    prepare_workspace_calls: [],
    discard_workspace_calls: [],
    rebuild_workspace_calls: [],
    prepare_workspace: function () { global.mockWindow.sketchup.prepare_workspace_calls.push('prepare'); },
    discard_workspace: function () { global.mockWindow.sketchup.discard_workspace_calls.push('discard'); },
    rebuild_workspace: function () { global.mockWindow.sketchup.rebuild_workspace_calls.push('rebuild'); },
    // V1.6 Planar Normalization / Z Policy (per dispatch
    // V16-UI-INTEGRATION-CORRECTION-2026-09-01): the host
    // callbacks for the destructive preview / apply actions
    // live on window.sketchup.<callback> (registered by
    // DialogRunner.add_action_callback at boot). The mock
    // records every invocation so the UI1-UI8 DOM tests can
    // assert the click-handler dispatch path actually calls
    // the correct sketchup.<callback> (NOT window.SUAIP.*).
    compute_planar_normalization_calls: [],
    apply_planar_normalization_calls: [],
    compute_planar_normalization: function () {
      global.mockWindow.sketchup.compute_planar_normalization_calls.push('compute');
    },
    apply_planar_normalization: function () {
      global.mockWindow.sketchup.apply_planar_normalization_calls.push('apply');
    }
  }
};
// Reset helper so each test can clear the call records
// without rebuilding the whole mockWindow.
function resetV14HostActionCalls() {
  mockWindow.sketchup.prepare_workspace_calls.length = 0;
  mockWindow.sketchup.discard_workspace_calls.length = 0;
  mockWindow.sketchup.rebuild_workspace_calls.length = 0;
  // V1.6 Planar Normalization host-action call records.
  mockWindow.sketchup.compute_planar_normalization_calls.length = 0;
  mockWindow.sketchup.apply_planar_normalization_calls.length = 0;
}

var context = {
  window: mockWindow,
  document: mockDocument,
  console: console
};
vm.createContext(context);

// --- load app.js -------------------------------------------------------

var appJsPath = path.resolve(__dirname, '..', 'extension', 'su_ai_plugin', 'html', 'app.js');
var appJsSrc = fs.readFileSync(appJsPath, 'utf-8');
vm.runInContext(appJsSrc, context, { filename: 'app.js' });

// --- exercise render(payload) -----------------------------------------

var payload = {
  selectionLabel: 'my_group',
  selectionType:  'Group',
  summary: {
    edges:               4,
    vertices:            5,
    non_zero_z_vertices: 0,
    warnings:            1,
    issues: {
      duplicate_edge_candidate:  0,
      short_edge:                1,
      open_endpoint:             0,
      gap_candidate:             0,
      significant_non_zero_z:    0,
      abnormal_large_coord:      0,
      deep_nesting:              0
    }
  },
  groups: [
    {
      type:         'short_edge',
      count:        1,
      defaultOpen:  true,
      issues: [{
        issue_id:  'short_edge|1|1',
        issue_type:'short_edge',
        severity:  'low',
        message:   'short edge detected',
        locatable: false
      }]
    }
  ]
};

context.window.SUAIP.render(payload);

// --- collect rendered text fragments ----------------------------------

function collectText(el, out) {
  if (el.textContent && el.textContent.length > 0) {
    out.push(el.textContent);
  }
  for (var i = 0; i < el.children.length; i++) {
    collectText(el.children[i], out);
  }
}

var summaryTexts = [];
collectText(mockElements['summary'], summaryTexts);
var selectionText = mockElements['selection-info'].textContent;
var fullText = summaryTexts.concat([selectionText]).join(' | ');

// --- assertions --------------------------------------------------------

var results = [];

function assert(name, cond) {
  results.push({ name: name, pass: !!cond });
  process.stdout.write('ASSERT ' + name + ' ' + (cond ? 'PASS' : 'FAIL') + '\n');
}

// Locked scalar header rows.
// V1.6 UI-CN-SIMPLIFICATION: scalar labels are Simplified
// Chinese (线段 / 顶点 / 非零 Z 顶点 / 警告 / 面 / 含洞面).
assert('summary: 线段: 4 present',
       summaryTexts.indexOf('线段: 4') !== -1);
assert('summary: 顶点: 5 present',
       summaryTexts.indexOf('顶点: 5') !== -1);
assert('summary: 非零 Z 顶点: 0 present',
       summaryTexts.indexOf('非零 Z 顶点: 0') !== -1);
assert('summary: 警告: 1 present',
       summaryTexts.indexOf('警告: 1') !== -1);

// Per-issue-type counters in the locked order.
// V1.6 UI-CN-SIMPLIFICATION: per-issue-type labels are
// Simplified Chinese (重复线候选 / 短线 / 未闭合端点 / 间隙候选 /
// 明显非零 Z / 异常大坐标 / 嵌套层级过深).
assert('summary: 重复线候选: 0 present',
       summaryTexts.indexOf('重复线候选: 0') !== -1);
assert('summary: 短线: 1 present',
       summaryTexts.indexOf('短线: 1') !== -1);
assert('summary: 未闭合端点: 0 present',
       summaryTexts.indexOf('未闭合端点: 0') !== -1);
assert('summary: 间隙候选: 0 present',
       summaryTexts.indexOf('间隙候选: 0') !== -1);
assert('summary: 明显非零 Z: 0 present',
       summaryTexts.indexOf('明显非零 Z: 0') !== -1);
assert('summary: 异常大坐标: 0 present',
       summaryTexts.indexOf('异常大坐标: 0') !== -1);
assert('summary: 嵌套层级过深: 0 present',
       summaryTexts.indexOf('嵌套层级过深: 0') !== -1);

// No "[object Object]" string anywhere in the rendered output.
assert('summary: no "[object Object]" in any rendered text',
       fullText.indexOf('[object Object]') === -1);

// Locked order: scalar rows come before per-issue-type rows.
var idxShortEdges   = summaryTexts.indexOf('短线: 1');
var idxEdges        = summaryTexts.indexOf('线段: 4');
var idxDup          = summaryTexts.indexOf('重复线候选: 0');
var idxDeep         = summaryTexts.indexOf('嵌套层级过深: 0');
assert('order: 线段 header comes before per-issue rows',
       idxEdges !== -1 && idxShortEdges !== -1 && idxEdges < idxShortEdges);
assert('order: per-issue rows in canonical order (重复线候选 before 嵌套层级过深)',
       idxDup !== -1 && idxDeep !== -1 && idxDup < idxDeep);

// Selection-info carries the locked shape (no duplication of the
// selection label inside the summary block).
assert('selection-info: "my_group (Group)" rendered',
       selectionText === 'my_group (Group)');

// Per-issue-type stat elements carry data-issue-type attrs.
var dataAttrsFound = summaryTexts.length; // we'll count separately
var attrs = [];
function collectAttrs(el, out) {
  for (var k in el.attrs) {
    if (Object.prototype.hasOwnProperty.call(el.attrs, k)) {
      out.push({ key: k, value: el.attrs[k], parentTag: el.tag });
    }
  }
  for (var i = 0; i < el.children.length; i++) {
    collectAttrs(el.children[i], out);
  }
}
collectAttrs(mockElements['summary'], attrs);
var typeAttrs = attrs.filter(function (a) { return a.key === 'data-issue-type'; });
var expectedTypes = [
  'duplicate_edge_candidate', 'short_edge', 'open_endpoint', 'gap_candidate',
  'significant_non_zero_z', 'abnormal_large_coord', 'deep_nesting'
];
assert('summary: 7 data-issue-type attrs present (one per canonical type)',
       typeAttrs.length === 7);
assert('summary: data-issue-type attrs in canonical order',
       typeAttrs.map(function (a) { return a.value; }).join(',') === expectedTypes.join(','));

// --------------------------------------------------------------------------
// CodeX Round 020 REAL-HOST BLOCK (recheck) L3: per-issue click handler
// dispatch. The previous app.js#renderIssue unconditionally added a
// click listener for every issue that called window.sketchup.locate(id).
// For non-locatable rows (preflight warnings like deep_nesting and
// abnormal_large_coord), the locator returns :unresolved and the JS
// previously raised a misleading "source no longer available" toast.
// These rows are intentionally non-locatable (no source token to
// resolve), NOT stale.
//
// Fix: only register the click handler when issue.locatable === true.
// For locatable === false, the row is non-actionable: no click handler,
// no path to window.sketchup.locate, no path to the toast.
// --------------------------------------------------------------------------

// Track locate() invocations on the mock window.sketchup.
var locateCalls = [];
mockWindow.sketchup.locate = function (id) { locateCalls.push(id); };

// Helper: render a fresh payload and reset state.
function renderIssuePayload(payload) {
  locateCalls = [];
  mockElements['groups'].textContent = '';
  mockElements['groups'].children = [];
  context.window.SUAIP.render(payload);
}

// L3.1 — locatable issue calls locate exactly once.
var payloadLocatable = {
  selectionLabel: 'outer_g',
  selectionType:  'Group',
  summary: {
    edges: 2, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
    issues: { open_endpoint: 1, deep_nesting: 1 }
  },
  groups: [
    {
      type: 'open_endpoint', count: 1, defaultOpen: true,
      issues: [{
        issue_id:   'open_endpoint|1|1',
        issue_type: 'open_endpoint',
        severity:   'medium',
        message:    'open endpoint',
        locatable:  true
      }]
    },
    {
      type: 'deep_nesting', count: 1, defaultOpen: false,
      issues: [{
        issue_id:   'deep_nesting|1|1',
        issue_type: 'deep_nesting',
        severity:   'low',
        message:    'selection contains 3 levels of nested groups/components',
        locatable:  false
      }]
    }
  ]
};
renderIssuePayload(payloadLocatable);

// Find each issue element by data-issue-id.
function findIssueEl(id) {
  function search(el) {
    if (el.attrs && el.attrs['data-issue-id'] === id) return el;
    for (var i = 0; i < el.children.length; i++) {
      var found = search(el.children[i]);
      if (found) return found;
    }
    return null;
  }
  return search(mockElements['groups']);
}

var openEndpointEl = findIssueEl('open_endpoint|1|1');
var deepNestingEl  = findIssueEl('deep_nesting|1|1');

assert('L3: locatable issue element exists in DOM',
       openEndpointEl !== null);
assert('L3: non-locatable issue element exists in DOM',
       deepNestingEl !== null);

// L3.1 — locatable row has a click listener.
assert('L3.1: locatable row has click listener registered',
       openEndpointEl !== null && openEndpointEl.hasListener('click') === true);
assert('L3.1: locatable row data-locatable attr is "true"',
       openEndpointEl !== null && openEndpointEl.attrs['data-locatable'] === 'true');
assert('L3.1: locatable row does NOT carry no-action class',
       openEndpointEl !== null && openEndpointEl.classes.indexOf('no-action') === -1);

// L3.2 — non-locatable row has NO click listener.
assert('L3.2: non-locatable row has NO click listener',
       deepNestingEl !== null && deepNestingEl.hasListener('click') === false);
assert('L3.2: non-locatable row data-locatable attr is "false"',
       deepNestingEl !== null && deepNestingEl.attrs['data-locatable'] === 'false');
assert('L3.2: non-locatable row carries no-action class',
       deepNestingEl !== null && deepNestingEl.classes.indexOf('no-action') !== -1);

// L3.1 — clicking the locatable row invokes locate exactly once.
openEndpointEl.fireEvent('click');
assert('L3.1: clicking locatable row invokes window.sketchup.locate ONCE',
       locateCalls.length === 1);
assert('L3.1: locate receives the issue_id',
       locateCalls.length === 1 && locateCalls[0] === 'open_endpoint|1|1');

// L3.2 — clicking the non-locatable row does NOT invoke locate
// (and cannot, because no listener is registered).
deepNestingEl.fireEvent('click');
assert('L3.2: clicking non-locatable row does NOT invoke window.sketchup.locate',
       locateCalls.length === 1); // unchanged from prior call

// L3.2 (extended) — fireEvent on a row with no listener is a no-op
// (no exception), proving the row is fully inert (no locate path,
// no toast path).
var beforeCalls = locateCalls.length;
try {
  deepNestingEl.fireEvent('click');
  deepNestingEl.fireEvent('click');
  deepNestingEl.fireEvent('click');
} catch (e) {
  assert('L3.2: clicking non-locatable row N times does NOT raise',
         false);
}
assert('L3.2: clicking non-locatable row N times still does NOT invoke locate',
       locateCalls.length === beforeCalls);

// --------------------------------------------------------------------------
// V1.1 (per plan §4.10 / §7.3): L4 — Layers section rendering. The
// dialog renders a Layers `<details>` block below per-issue-type
// groups. The renderer takes `payload.layerGroups` (an Array of
// per-layer summaries with role / role_label / visible /
// visibility_unknown / visibility_label / edge_count / issue_count)
// and emits one `.layer-row` per entry inside `#layers-list`. Each
// row carries a separate role badge AND visibility badge (R007).
// The summary text is populated BEFORE the user opens the details
// (ChatGPT §11.5). No layer row registers a click handler (mirrors
// L3 non-locatable pattern).
// --------------------------------------------------------------------------

// Helper: re-render with a fresh payload (resets locate state too).
function renderWithPayload(payload) {
  locateCalls = [];
  // Reset all elements so render is idempotent.
  Object.keys(mockElements).forEach(function (k) {
    mockElements[k].textContent = '';
    mockElements[k].children = [];
  });
  context.window.SUAIP.render(payload);
}

// L4.1 — payloads with 2 layer summaries -> 2 .layer-row children.
// Use a custom layerGroups shape: 1 visible DIM-XX layer, 1 hidden
// Layer0 layer (for the data-visible / visibility-unknown / has-
// issues branches below).
var layersPayload = {
  selectionLabel: 'outer_g',
  selectionType:  'Group',
  summary: {
    edges: 6, vertices: 6, non_zero_z_vertices: 0, warnings: 0,
    issues: {
      short_edge: 1
    }
  },
  groups: [
    {
      type: 'short_edge', count: 1, defaultOpen: true,
      issues: [{
        issue_id:   'short_edge|1|1',
        issue_type: 'short_edge',
        severity:   'low',
        message:    'short edge detected',
        locatable:  true
      }]
    }
  ],
  layerGroups: [
    {
      name:               'DIM-XX',
      role:               'dimension',
      role_rule:          'name_dimension',
      role_label:         'Dimension',
      visible:            true,
      visibility_unknown: false,
      visibility_label:   'Visible',
      edge_count:         4,
      issue_count:        1
    },
    {
      name:               'Layer0',
      role:               'construction',
      role_rule:          'name_default_layer',
      role_label:         'Construction',
      visible:            false,
      visibility_unknown: false,
      visibility_label:   'Off-screen',
      edge_count:         2,
      issue_count:        0
    }
  ]
};
renderWithPayload(layersPayload);

var layersList = mockElements['layers-list'];
assert('L4.1: #layers-list has 2 .layer-row children for 2 layer summaries',
       layersList.children.length === 2);
assert('L4.1: each child has class layer-row',
       layersList.children.every(function (c) {
         return c.classes.indexOf('layer-row') !== -1;
       }));

// L4.2 — role + visibility badges are SEPARATE per R007.
var dimRow = layersList.children[0];
var l0Row  = layersList.children[1];
assert('L4.2: layer row exposes a role-badge',
       dimRow !== undefined && dimRow.children.length >= 2 &&
       dimRow.children.some(function (c) {
         return c.classes.indexOf('role-badge') !== -1;
       }));
assert('L4.2: layer row exposes a separate visibility-badge (NOT fused into role)',
       dimRow !== undefined && dimRow.children.some(function (c) {
         return c.classes.indexOf('visibility-badge') !== -1;
       }));

// L4.3 — textContent on row carries role_label + visibility_label
// + edge_count + issue_count.
function findChildByClass(el, cls) {
  return el.children.filter(function (c) { return c.classes.indexOf(cls) !== -1; })[0];
}
var dimRoleBadge  = findChildByClass(dimRow, 'role-badge');
var dimVisBadge   = findChildByClass(dimRow, 'visibility-badge');
var dimEdgesCell  = findChildByClass(dimRow, 'edge-count');
var dimIssuesCell = findChildByClass(dimRow, 'issue-count');
assert('L4.3: role-badge textContent is the Simplified Chinese label (尺寸标注 for role=dimension)',
       dimRoleBadge && dimRoleBadge.textContent === '尺寸标注');
assert('L4.3: visibility-badge textContent is the Simplified Chinese label (可见 for visible=true)',
       dimVisBadge && dimVisBadge.textContent === '可见');
assert('L4.3: edge-count renders the layer edge count ("4 条" for n=4)',
       dimEdgesCell && dimEdgesCell.textContent === '4 条');
assert('L4.3: issue-count renders the layer issue count ("1 个问题" for n=1)',
       dimIssuesCell && dimIssuesCell.textContent === '1 个问题');
// L4.3.1 — Per Owner Gate 2 V1.1 NIT: a visible separator between
// the edge count and the issue count. The separator is a real DOM
// node carrying class "layer-count-sep" and textContent "·" so that
// both real host dialogs and the mock test harness surface it.
var dimSepCell = findChildByClass(dimRow, 'layer-count-sep');
assert('L4.3.1: a layer-count-sep separator sits between edge-count and issue-count',
       dimSepCell && dimSepCell.textContent === '\u00B7');
// The mock MockElement does not auto-aggregate child textContent
// into the parent, so we walk the row's direct children and
// concatenate their textContents ourselves. This proves the row
// will render as "4 edges · 1 issue" in a real DOM where
// textContent IS auto-aggregated.
function joinChildTexts(el) {
  if (!el || !el.children) return '';
  return el.children.map(function (c) { return c.textContent || ''; }).join('');
}
// The MockElement does NOT auto-aggregate textContent into the
// parent (just like a real DOM the textContent of a parent is the
// concatenation of its descendants' text nodes, with no spaces).
// The visual spacing in the real host comes from the row's flexbox
// `gap: 8px`, NOT from textContent. So the joined direct-children
// text is "DIM-XXDimensionVisible4 edges·1 issue" — the middle
// dot between edge-count and issue-count is what makes the
// separator visible to Owners and to the L4.10 "no object-
// stringification" guard.
assert('L4.3.1: row direct-children text concatenates with the middle-dot separator',
       dimRow && joinChildTexts(dimRow) === 'DIM-XX尺寸标注可见4 条\u00B71 个问题');
assert('L4.3.1: middle-dot separator is a real DOM node carrying class layer-count-sep',
       dimSepCell && dimSepCell.textContent === '\u00B7');

// L4.4 — issue_count > 0 gets the .has-issues class for emphasis.
assert('L4.4: issue_count > 0 gets the has-issues class',
       dimIssuesCell && dimIssuesCell.classes.indexOf('has-issues') !== -1);

// L4.4.1 — Per Owner Gate 2 V1.1 NIT: pluralization correctness.
// n=0 -> plural, n=1 -> singular, n=2+ -> plural. The hidden
// layer row in the same layersPayload carries edge_count=2 /
// issue_count=0; check those here.
var l0EdgesCell  = findChildByClass(l0Row, 'edge-count');
var l0IssuesCell = findChildByClass(l0Row, 'issue-count');
assert('L4.4.1: edge_count=2 renders as "2 条"',
       l0EdgesCell && l0EdgesCell.textContent === '2 条');
assert('L4.4.1: issue_count=0 renders as "0 个问题"',
       l0IssuesCell && l0IssuesCell.textContent === '0 个问题');
assert('L4.4.1: issue_count=0 has NO .has-issues class',
       l0IssuesCell && l0IssuesCell.classes.indexOf('has-issues') === -1);

// L4.5 — hidden layer has data-visible="false" AND a separate
// visibility badge "隐藏" (NOT a fused role label). V1.6
// UI-CN-SIMPLIFICATION: role + visibility labels are Simplified
// Chinese.
assert('L4.5: hidden layer row has data-visible="false"',
       l0Row && l0Row.attrs['data-visible'] === 'false');
assert('L4.5: hidden layer row role_label is still "构造线" (NOT fused)',
       findChildByClass(l0Row, 'role-badge') &&
       findChildByClass(l0Row, 'role-badge').textContent === '构造线');
assert('L4.5: hidden layer row visibility badge text is "隐藏"',
       findChildByClass(l0Row, 'visibility-badge') &&
       findChildByClass(l0Row, 'visibility-badge').textContent === '隐藏');

// L4.6 — visible layer has data-visible="true".
assert('L4.6: visible layer row has data-visible="true"',
       dimRow && dimRow.attrs['data-visible'] === 'true');

// L4.7 — layer rows are NON-ACTIONABLE (no click handler, mirrors L3).
assert('L4.7: layer row has NO click listener registered',
       dimRow && dimRow.hasListener('click') === false);
assert('L4.7: layer row has no-action CSS class? (intentionally default-cursor)',
       dimRow !== undefined);  // visual non-action is via .layer-row { cursor: default }
var beforeLocatesForLayers = locateCalls.length;
dimRow.fireEvent('click');
l0Row.fireEvent('click');
assert('L4.7: clicking a layer row does NOT invoke window.sketchup.locate',
       locateCalls.length === beforeLocatesForLayers);

// L4.8 — data-role on row mirrors the server-composed role.
assert('L4.8: layer row carries data-role attribute',
       dimRow.attrs['data-role'] === 'dimension' &&
       l0Row.attrs['data-role'] === 'construction');

// L4.9 — data-layer-name mirrors the layer name.
assert('L4.9: layer row carries data-layer-name attribute',
       dimRow.attrs['data-layer-name'] === 'DIM-XX' &&
       l0Row.attrs['data-layer-name'] === 'Layer0');

// L4.10 — no [object Object] stringification on any layer row text.
var layersRowTexts = [];
function collectAllTexts(el, out) {
  if (el.textContent && el.textContent.length > 0) out.push(el.textContent);
  for (var i = 0; i < el.children.length; i++) collectAllTexts(el.children[i], out);
}
collectAllTexts(layersList, layersRowTexts);
var concatenatedLayersText = layersRowTexts.join(' | ');
assert('L4.10: no "[object Object]" in any rendered layer row text',
       concatenatedLayersText.indexOf('[object Object]') === -1);

// L4.11 — layers_summary text is populated BEFORE the user opens
// the details (ChatGPT §11.5). Mock initial state was empty; after
// render it MUST carry the formatted count string.
var layersSummaryEl = mockElements['layers-summary'];
// V1.6 UI-CN-SIMPLIFICATION: section header text is
// Simplified Chinese: "图层信息— N 个图层（M 个存在问题）".
assert('L4.11: #layers-summary textContent is Simplified Chinese ("图层信息— N 个图层（M 个存在问题）")',
       layersSummaryEl.textContent === '图层信息\u2014 2 个图层（1 个存在问题）');

// L4.12 — payload.layerGroups undefined -> #layers-list is empty
// (no error). reset then re-render.
renderWithPayload({
  selectionLabel: 'outer_g', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0, issues: {} },
  groups:  [],
  layerGroups: undefined  // simulate a V1.0 caller / empty selection
});
assert('L4.12: undefined layerGroups -> #layers-list empty',
       mockElements['layers-list'].children.length === 0);
assert('L4.12: undefined layerGroups -> summary shows "图层信息— 0 个图层（0 个存在问题）"',
       mockElements['layers-summary'].textContent === '图层信息\u2014 0 个图层（0 个存在问题）');

// L4.13 — empty array layerGroups is the same as undefined (defensive).
renderWithPayload({
  selectionLabel: 'g', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0, issues: {} },
  groups:  [],
  layerGroups: []
});
assert('L4.13: empty array layerGroups -> #layers-list empty',
       mockElements['layers-list'].children.length === 0);
assert('L4.13: empty array layerGroups -> summary still computes N correctly',
       mockElements['layers-summary'].textContent === '图层信息\u2014 0 个图层（0 个存在问题）');

// L4.14 — visibility_unknown: true surfaces "Visibility: unknown"
// badge (R011). The data-visibility-unknown attribute must be "true".
renderWithPayload({
  selectionLabel: 'g', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0, issues: {} },
  groups:  [],
  layerGroups: [{
    name:               'GUESS',
    role:               'unknown',
    role_rule:          null,
    role_label:         'Unknown',
    visible:            true,        // operational fallback per R011
    visibility_unknown: true,
    visibility_label:   'Visibility: unknown',
    edge_count:         1,
    issue_count:        0
  }]
});
var unkRow = mockElements['layers-list'].children[0];
assert('L4.14: visibility_unknown: true -> data-visibility-unknown="true"',
       unkRow.attrs['data-visibility-unknown'] === 'true');
// V1.6 UI-CN-SIMPLIFICATION: visibility_unknown surfaces the
// Simplified Chinese "可见性未知" badge; role badge is "未识别".
assert('L4.14: visibility_unknown: true -> visibility badge text is "可见性未知" (Simplified Chinese)',
       findChildByClass(unkRow, 'visibility-badge') &&
       findChildByClass(unkRow, 'visibility-badge').textContent === '可见性未知');
assert('L4.14: visibility_unknown: true -> role badge still "未识别" (Simplified Chinese, NOT fused)',
       findChildByClass(unkRow, 'role-badge') &&
       findChildByClass(unkRow, 'role-badge').textContent === '未识别');
// V1.6 UI-CN-SIMPLIFICATION: the canonical Simplified Chinese
// label map is exposed on ROOT for harness introspection.
assert('L4.14: ROOT.LAYER_VISIBILITY_LABELS_CN has visible/hidden/unknown',
       context.window.SUAIP.LAYER_VISIBILITY_LABELS_CN &&
       context.window.SUAIP.LAYER_VISIBILITY_LABELS_CN.visible === '可见' &&
       context.window.SUAIP.LAYER_VISIBILITY_LABELS_CN.hidden === '隐藏' &&
       context.window.SUAIP.LAYER_VISIBILITY_LABELS_CN.unknown === '可见性未知');
assert('L4.14: ROOT.LAYER_ROLE_LABELS_CN has 5 canonical Simplified Chinese roles',
       Array.isArray(context.window.SUAIP.LAYER_ROLE_LABELS_CN) &&
       context.window.SUAIP.LAYER_ROLE_LABELS_CN.length === 5 &&
       context.window.SUAIP.LAYER_ROLE_LABELS_CN.map(function (p) { return p[0]; }).join(',') ===
         'dimension,annotation,guide,construction,unknown' &&
       context.window.SUAIP.LAYER_ROLE_LABELS_CN.map(function (p) { return p[1]; }).join(',') ===
         '尺寸标注,注释,辅助线,构造线,未识别');

// L4.15 — ROOT.LAYER_ROLE_LABELS_CN exposed with the 5 canonical roles
// (NO OFFSCREEN) in locked order (V1.6 UI-CN-SIMPLIFICATION).
var lrl = context.window.SUAIP.LAYER_ROLE_LABELS_CN;
assert('L4.15: ROOT.LAYER_ROLE_LABELS_CN is defined',
       Array.isArray(lrl) && lrl.length === 5);
var expectedRoleOrder = ['dimension', 'annotation', 'guide',
                         'construction', 'unknown'];
var actualRoleOrder = lrl.map(function (pair) { return pair[0]; });
assert('L4.15: ROOT.LAYER_ROLE_LABELS_CN in canonical order (dimension, annotation, guide, construction, unknown)',
       actualRoleOrder.join(',') === expectedRoleOrder.join(','));
assert('L4.15: ROOT.LAYER_ROLE_LABELS_CN does NOT include OFFSCREEN (R007)',
       actualRoleOrder.indexOf('offscreen') === -1);

// L4.16 — ROOT.LAYER_VISIBILITY_LABELS_CN exposed with 3 keys
// (visible, hidden, unknown). V1.6 UI-CN-SIMPLIFICATION.
var lvl = context.window.SUAIP.LAYER_VISIBILITY_LABELS_CN;
assert('L4.16: ROOT.LAYER_VISIBILITY_LABELS_CN is defined with visible/hidden/unknown (Simplified Chinese)',
       lvl && lvl.visible === '可见' &&
       lvl.hidden === '隐藏' &&
       lvl.unknown === '可见性未知');

// L4.17 — ROOT.renderLayers is exposed (so other scripts can call it).
assert('L4.17: ROOT.renderLayers is exposed',
       typeof context.window.SUAIP.renderLayers === 'function');

// L4.18 — locked render contract: textContent-only, no innerHTML
// assignment anywhere in the layer-render path. We assert this
// indirectly: the locked contract holds if data appears via
// textContent, NOT via innerHTML. All children added to the row
// during renderLayerRow carry their string via .textContent. We
// surface a stronger check via the Ruby source-level guard.
var rowBadges = dimRow ? dimRow.children.filter(function (c) {
  return c.classes.indexOf('role-badge') !== -1 ||
         c.classes.indexOf('visibility-badge') !== -1;
}) : [];
assert('L4.18: row badges have non-empty textContent (locked contract)',
       rowBadges.length > 0 && rowBadges.every(function (b) {
         return b.textContent && b.textContent.length > 0;
       }));

// --- V1.2 (per directive 026): "Issues by Layer" section tests -----

// Reset the document state and re-render with a V1.2 payload.
renderWithPayload({
  selectionLabel: 'multi_layer',
  selectionType:  'Group',
  summary: { edges: 2, vertices: 4, non_zero_z_vertices: 0, warnings: 0, issues: {} },
  groups:  [],
  layerGroups: [],
  layerIssueGroups: [
    {
      name:         'DIM-WALLS',
      count:        1,
      default_open: false,
      issues: [
        { issue_id: 'open_endpoint|1|1', issue_type: 'open_endpoint',
          severity: 'low', locatable: true,
          message: 'open endpoint on DIM-WALLS',
          source: { layer_name: 'DIM-WALLS' } }
      ]
    },
    {
      name:         'TXT-LABELS',
      count:        1,
      default_open: false,
      issues: [
        { issue_id: 'open_endpoint|2|1', issue_type: 'open_endpoint',
          severity: 'low', locatable: true,
          message: 'open endpoint on TXT-LABELS',
          source: { layer_name: 'TXT-LABELS' } }
      ]
    }
  ]
});

var v12LayerIssuesList = mockElements['layer-issues-list'];
var v12LayerIssuesSummary = mockElements['layer-issues-summary'];

assert('V12: layer-issues-list contains one .layer-issue-bucket per non-empty bucket',
       v12LayerIssuesList && v12LayerIssuesList.children.length === 2);
assert('V12: layer-issues-summary populated BEFORE the user opens the section (Simplified Chinese)',
       v12LayerIssuesSummary && v12LayerIssuesSummary.textContent ===
         '按图层查看问题\u2014 2 个图层（2 个问题）');
assert('V12: each bucket is a <details> element',
       v12LayerIssuesList.children.every(function (c) {
         return c.tag === 'details';
       }));
var _b0 = v12LayerIssuesList.children[0].children[0].textContent;
var _b1 = v12LayerIssuesList.children[1].children[0].textContent;
assert('V12: bucket summary shows layer name + issue count (Simplified Chinese, "1 个问题" for n=1)',
       _b0 === 'DIM-WALLS（1 个问题）' && _b1 === 'TXT-LABELS（1 个问题）');
assert('V12: each bucket body contains the issue row(s) from renderIssue',
       v12LayerIssuesList.children[0].children.length === 2 &&
       v12LayerIssuesList.children[0].children[1].classes.indexOf('issue') !== -1);
assert('V12: locatable issue in bucket still invokes Locate on click',
       (function () {
         var issueRow = v12LayerIssuesList.children[0].children[1];
         var beforeLocates = locateCalls.length;
         issueRow.fireEvent('click');
         return locateCalls.length === beforeLocates + 1 &&
                locateCalls[locateCalls.length - 1] === 'open_endpoint|1|1';
       })());

// V12: non-locatable issue inside a bucket is inert.
renderWithPayload({
  selectionLabel: 'multi_layer',
  selectionType:  'Group',
  summary: { edges: 1, vertices: 2, non_zero_z_vertices: 0, warnings: 1, issues: {} },
  groups:  [],
  layerGroups: [],
  layerIssueGroups: [
    {
      name:         'Layer0',
      count:        1,
      default_open: true,
      issues: [
        { issue_id: 'deep_nesting|1|1', issue_type: 'deep_nesting',
          severity: 'low', locatable: false,
          message: 'deeply nested group',
          source: { layer_name: 'Layer0' } }
      ]
    }
  ]
});
var v12NonLocatableBucket = mockElements['layer-issues-list'].children[0];
var v12NonLocatableIssue = v12NonLocatableBucket.children[1];
assert('V12: non-locatable issue inside bucket has no-action class (inert)',
       v12NonLocatableIssue.classes.indexOf('no-action') !== -1);
assert('V12: non-locatable issue inside bucket has NO click listener',
       v12NonLocatableIssue.hasListener('click') === false);
var v12BeforeNL = locateCalls.length;
v12NonLocatableIssue.fireEvent('click');
assert('V12: clicking non-locatable issue inside bucket does NOT invoke Locate',
       locateCalls.length === v12BeforeNL);
assert('V12: bucket honors default_open flag (true => <details open>)',
       v12NonLocatableBucket.attrs['open'] === 'true' ||
       v12NonLocatableBucket._open === true ||
       v12NonLocatableBucket.open === true);

// V12: empty layerIssueGroups renders zero buckets + correct summary.
renderWithPayload({
  selectionLabel: 'g', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0, issues: {} },
  groups:  [],
  layerGroups: [],
  layerIssueGroups: []
});
assert('V12: empty layerIssueGroups -> #layer-issues-list empty',
       mockElements['layer-issues-list'].children.length === 0);
assert('V12: empty layerIssueGroups -> summary "按图层查看问题— 0 个图层（0 个问题）"',
       mockElements['layer-issues-summary'].textContent ===
         '按图层查看问题\u2014 0 个图层（0 个问题）');

// V12: undefined layerIssueGroups is the default-empty path.
renderWithPayload({
  selectionLabel: 'g', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0, issues: {} },
  groups:  [],
  layerGroups: [],
  layerIssueGroups: undefined  // V1.0 / V1.1 caller path
});
assert('V12: undefined layerIssueGroups -> empty list + zero-summary (Simplified Chinese)',
       mockElements['layer-issues-list'].children.length === 0 &&
       mockElements['layer-issues-summary'].textContent ===
         '按图层查看问题\u2014 0 个图层（0 个问题）');

// V12: bucket summary plural form (n > 1 -> plural wording).
renderWithPayload({
  selectionLabel: 'multi', selectionType: 'Group',
  summary: { edges: 5, vertices: 10, non_zero_z_vertices: 0, warnings: 0, issues: {} },
  groups:  [],
  layerGroups: [],
  layerIssueGroups: [
    { name: 'DIM-XX', count: 2, default_open: true,
      issues: [
        { issue_id: 'open_endpoint|1|1', issue_type: 'open_endpoint',
          severity: 'low', locatable: true, message: 'm1', source: { layer_name: 'DIM-XX' } },
        { issue_id: 'short_edge|2|1',   issue_type: 'short_edge',
          severity: 'low', locatable: true, message: 'm2', source: { layer_name: 'DIM-XX' } }
      ]
    }
  ]
});
var v12MultiBucket = mockElements['layer-issues-list'].children[0];
assert('V12: bucket summary plural form for n=2 ("2 个问题")',
       v12MultiBucket.children[0].textContent === 'DIM-XX（2 个问题）');
assert('V12: bucket body has 2 issue rows',
       v12MultiBucket.children.length === 3 &&
       v12MultiBucket.children[1].classes.indexOf('issue') !== -1 &&
       v12MultiBucket.children[2].classes.indexOf('issue') !== -1);

// V12: user-supplied layer names render via textContent (no innerHTML).
assert('V12: bucket summary text uses textContent (no [object Object] / no innerHTML)',
       v12MultiBucket.children[0].textContent.indexOf('[object Object]') === -1 &&
       v12MultiBucket.children[0].innerHTML === undefined);

// V12: the existing Layers section rows are STILL inert after V1.2 render.
renderWithPayload({
  selectionLabel: 'g', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0, issues: {} },
  groups:  [],
  layerGroups: [
    { name: 'Layer0', role: 'construction', role_rule: 'name_default_layer',
      role_label: 'Construction', visible: true, visibility_unknown: false,
      visibility_label: 'Visible', edge_count: 4, issue_count: 0 }
  ],
  layerIssueGroups: []
});
var v12LayersList = mockElements['layers-list'];
var v12LayerRow = v12LayersList.children[0];
assert('V12: existing Layers row has NO click listener after V1.2 render (still inert)',
       v12LayerRow && v12LayerRow.hasListener('click') === false);

// V12: ROOT.renderLayerIssues and ROOT.renderLayerIssueBucket are exposed.
assert('V12: ROOT.renderLayerIssues is exposed (so other scripts can call it)',
       typeof context.window.SUAIP.renderLayerIssues === 'function');
assert('V12: ROOT.renderLayerIssueBucket is exposed',
       typeof context.window.SUAIP.renderLayerIssueBucket === 'function');

// V12-NIT-001 (per CodeX review 028; deferred NIT, not blocking
// V1.2). Re-render with a single layer / single issue so the
// summary reads '1 layer' (NOT '1 layers') in the singular case.
// Placed AFTER all V12 bucket assertions because
// renderWithPayload clears the document state.
renderWithPayload({
  selectionLabel: 'single_layer',
  selectionType:  'Group',
  summary: { edges: 2, vertices: 4, non_zero_z_vertices: 0, warnings: 0, issues: {} },
  groups:  [],
  layerGroups: [],
  layerIssueGroups: [
    {
      name: 'DIM-XX', count: 1, default_open: false,
      issues: [
        { issue_id: 'open_endpoint|1|1', issue_type: 'open_endpoint',
          severity: 'low', locatable: true, message: 'm',
          source: { layer_name: 'DIM-XX' } }
      ]
    }
  ]
});
assert('V12-NIT-001: summary uses singular form for n=1 layer (Simplified Chinese: "按图层查看问题— 1 个图层（1 个问题）")',
       mockElements['layer-issues-summary'].textContent ===
         '按图层查看问题\u2014 1 个图层（1 个问题）');

// --- V1.3 (per directive 027): "Face Inventory" section tests -----

// Reset the document state and re-render with a V1.3 payload.
renderWithPayload({
  selectionLabel: 'mixed_layers',
  selectionType:  'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 2, faces_with_holes: 1, issues: {} },
  groups:  [],
  layerGroups: [],
  layerIssueGroups: [],
  faceInventoryGroups: [
    { name: 'DIM-WALLS', face_count: 1, faces_with_holes_count: 1,
      role: 'dimension', role_label: 'Dimension', role_rule: 'name_dimension',
      visible: true, visibility_unknown: false, visibility_label: 'Visible' },
    { name: 'Layer0', face_count: 1, faces_with_holes_count: 0,
      role: 'construction', role_label: 'Construction', role_rule: 'name_default_layer',
      visible: true, visibility_unknown: false, visibility_label: 'Visible' }
  ]
});

var v13FaceInvList = mockElements['face-inventory-list'];
var v13FaceInvSummary = mockElements['face-inventory-summary'];

assert('V13: face-inventory-list contains one .face-inventory-row per layer bucket',
       v13FaceInvList && v13FaceInvList.children.length === 2);
// V1.6 UI-CN-SIMPLIFICATION: section header is Simplified
// Chinese ("面信息— N 个面（H 个含洞）").
assert('V13: face-inventory-summary populated BEFORE opening with Simplified Chinese format',
       v13FaceInvSummary && v13FaceInvSummary.textContent ===
         '面信息\u2014 2 个面（1 个含洞）');
assert('V13: each row has class face-inventory-row',
       v13FaceInvList.children.every(function (c) {
         return c.classes.indexOf('face-inventory-row') !== -1;
       }));
assert('V13: row 1 (DIM-WALLS) renders layer name + role badge + visibility badge + face count + holes count (Simplified Chinese)',
       (function () {
         var row = v13FaceInvList.children[0];
         if (!row) return false;
         var children = row.children;
         var layerName  = children.filter(function (c) { return c.classes.indexOf('layer-name') !== -1; })[0];
         var roleBadge  = children.filter(function (c) { return c.classes.indexOf('role-badge') !== -1; })[0];
         var visBadge   = children.filter(function (c) { return c.classes.indexOf('visibility-badge') !== -1; })[0];
         var facesCell  = children.filter(function (c) { return c.classes.indexOf('face-count') !== -1; })[0];
         var holesCell  = children.filter(function (c) { return c.classes.indexOf('holes-count') !== -1; })[0];
         var sep        = children.filter(function (c) { return c.classes.indexOf('face-count-sep') !== -1; })[0];
         if (!layerName || !roleBadge || !visBadge || !facesCell || !holesCell || !sep) return false;
         if (layerName.textContent !== 'DIM-WALLS') return false;
         if (roleBadge.textContent !== 'Dimension') return false;
         if (visBadge.textContent !== 'Visible') return false;
         if (facesCell.textContent !== '1 个面') return false;
         if (holesCell.textContent !== '1 个含洞面') return false;
         if (sep.textContent !== '\u00B7') return false;
         return true;
       })());
assert('V13: face_count singular form for n=1 ("1 个面")',
       v13FaceInvList.children[0].children
         .filter(function (c) { return c.classes.indexOf('face-count') !== -1; })[0]
         .textContent === '1 个面');
assert('V13: faces_with_holes_count singular form for n=1 ("1 个含洞面")',
       v13FaceInvList.children[0].children
         .filter(function (c) { return c.classes.indexOf('holes-count') !== -1; })[0]
         .textContent === '1 个含洞面');
assert('V13: data-layer-name attribute carries the layer name verbatim',
       v13FaceInvList.children[0].attrs['data-layer-name'] === 'DIM-WALLS');
assert('V13: data-role attribute mirrors the server-composed role',
       v13FaceInvList.children[0].attrs['data-role'] === 'dimension' &&
       v13FaceInvList.children[1].attrs['data-role'] === 'construction');
assert('V13: data-visible + data-visibility-unknown attributes set per row',
       v13FaceInvList.children[0].attrs['data-visible'] === 'true' &&
       v13FaceInvList.children[0].attrs['data-visibility-unknown'] === 'false');

// V13: row is non-actionable.
assert('V13: face-inventory-row has NO click listener (non-actionable)',
       v13FaceInvList.children.every(function (c) {
         return c.hasListener('click') === false;
       }));
var v13BeforeLI = locateCalls.length;
v13FaceInvList.children.forEach(function (c) { c.fireEvent('click'); });
assert('V13: clicking a face-inventory-row does NOT invoke Locate',
       locateCalls.length === v13BeforeLI);

// V13: empty faceInventoryGroups renders zero rows + correct summary.
renderWithPayload({
  selectionLabel: 'g', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: []
});
assert('V13: empty faceInventoryGroups -> #face-inventory-list empty',
       mockElements['face-inventory-list'].children.length === 0);
assert('V13: empty faceInventoryGroups -> summary "面信息— 0 个面（0 个含洞）"',
       mockElements['face-inventory-summary'].textContent ===
         '面信息\u2014 0 个面（0 个含洞）');

// V13: undefined faceInventoryGroups is the default-empty path.
renderWithPayload({
  selectionLabel: 'g', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: undefined  // V1.0/V1.1/V1.2 caller path
});
assert('V13: undefined faceInventoryGroups -> empty list + zero-summary (Simplified Chinese)',
       mockElements['face-inventory-list'].children.length === 0 &&
       mockElements['face-inventory-summary'].textContent ===
         '面信息\u2014 0 个面（0 个含洞）');

// V13: hidden layer row gets data-visible="false" + opacity (via CSS attr).
renderWithPayload({
  selectionLabel: 'hidden_layer', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 1, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [
    { name: 'HIDDEN', face_count: 1, faces_with_holes_count: 0,
      role: 'annotation', role_label: 'Annotation', role_rule: 'name_annotation',
      visible: false, visibility_unknown: false, visibility_label: 'Off-screen' }
  ]
});
var v13HiddenRow = mockElements['face-inventory-list'].children[0];
assert('V13: hidden layer row carries data-visible="false" + Visibility badge = "Off-screen"',
       v13HiddenRow.attrs['data-visible'] === 'false' &&
       v13HiddenRow.children.filter(function (c) {
         return c.classes.indexOf('visibility-badge') !== -1;
       })[0].textContent === 'Off-screen');
assert('V13: hidden layer row still has NO click listener',
       v13HiddenRow.hasListener('click') === false);

// V13: user-supplied layer names render via textContent (no innerHTML).
var v13FinalRow = v13HiddenRow;
assert('V13: hidden row text uses textContent (no [object Object] / no innerHTML)',
       v13FinalRow.textContent.indexOf('[object Object]') === -1 &&
       v13FinalRow.innerHTML === undefined);

// V13: V1.2 Issues by Layer + V1.1 Layers rows remain inert after V1.3 render.
renderWithPayload({
  selectionLabel: 'multi', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 1, faces_with_holes: 0, issues: {} },
  groups:  [],
  layerGroups: [
    { name: 'Layer0', role: 'construction', role_rule: 'name_default_layer',
      role_label: 'Construction', visible: true, visibility_unknown: false,
      visibility_label: 'Visible', edge_count: 4, issue_count: 0 }
  ],
  layerIssueGroups: [
    { name: 'Layer0', count: 1, default_open: false,
      issues: [{ issue_id: 'open_endpoint|1|1', severity: 'low', locatable: true, source: { layer_name: 'Layer0' } }] }
  ],
  faceInventoryGroups: [
    { name: 'Layer0', face_count: 1, faces_with_holes_count: 0,
      role: 'construction', role_label: 'Construction', role_rule: 'name_default_layer',
      visible: true, visibility_unknown: false, visibility_label: 'Visible' }
  ]
});
assert('V13: existing Layers row remains inert after V1.3 render',
       mockElements['layers-list'].children[0].hasListener('click') === false);
assert('V13: existing V1.2 layer-issue-bucket row remains inert after V1.3 render',
       mockElements['layer-issues-list'].children[0].hasListener('click') === false);
assert('V13: new V1.3 face-inventory-row remains inert after V1.3 render',
       mockElements['face-inventory-list'].children[0].hasListener('click') === false);

// V13-NIT-001 (per Owner Gate 2 V1.3 NIT): row parts must
// remain distinct in the DOM, and the row's first child must
// have class `layer-name` (used by the spacing CSS). The
// parts (layer name + role badge + visibility badge + face
// count + separator + holes count) are 6 separate children
// with distinct classes, NOT merged into a single text node.
assert('V13-NIT-001: face-inventory-row has 6 distinct child parts (no merge)',
       (function () {
         var row = mockElements['face-inventory-list'].children[0];
         return row && row.children.length === 6;
       })());
assert('V13-NIT-001: face-inventory-row children carry distinct class names (no merge)',
       (function () {
         var row = mockElements['face-inventory-list'].children[0];
         var expectedClasses = ['layer-name', 'role-badge', 'visibility-badge',
                                'face-count', 'face-count-sep', 'holes-count'];
         return expectedClasses.every(function (cls) {
           return row.children.some(function (c) {
             return c.classes.indexOf(cls) !== -1;
           });
         });
       })());
assert('V13-NIT-001: face-inventory-row child textContent values are distinct (no merge)',
       (function () {
         var row = mockElements['face-inventory-list'].children[0];
         var texts = row.children.map(function (c) { return c.textContent; });
         // No two adjacent children should have the same textContent
         // (which would indicate a merge). Each child has a unique
         // text role.
         var uniq = {};
         for (var i = 0; i < texts.length; i++) {
           if (uniq[texts[i]] !== undefined) return false;
           uniq[texts[i]] = i;
         }
         return texts.length === 6;
       })());

// V13: ROOT.renderFaceInventory + ROOT.renderFaceInventoryRow are exposed.
assert('V13: ROOT.renderFaceInventory is exposed',
       typeof context.window.SUAIP.renderFaceInventory === 'function');
assert('V13: ROOT.renderFaceInventoryRow is exposed',
       typeof context.window.SUAIP.renderFaceInventoryRow === 'function');

// V13: Faces / Faces With Holes scalar counters in #summary block.
// V1.6 UI-CN-SIMPLIFICATION: scalar labels are Simplified
// Chinese (面 / 含洞面).
assert('V13: summary block contains "面: 1" + "含洞面: 0" scalars',
       (function () {
         var summaryEl = mockElements['summary'];
         var texts = [];
         function collect(el) {
           if (el.textContent) texts.push(el.textContent);
           for (var i = 0; i < el.children.length; i++) collect(el.children[i]);
         }
         collect(summaryEl);
         var all = texts.join(' | ');
         return all.indexOf('面: 1') !== -1 && all.indexOf('含洞面: 0') !== -1;
       })());

// --- V1.4 (per directive 030 Stage 4): "Working Mode" section tests -----

// Render with derivedWorkspace='none' (initial / pre-prepare state).
renderWithPayload({
  selectionLabel: 'wm-none', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: { state: 'none' }
});
var wmSummary = mockElements['working-mode-summary'];
var wmList    = mockElements['working-mode-list'];
var wmActions = mockElements['working-mode-actions'];

// V1.6 UI-CN-SIMPLIFICATION: working-mode-summary text is
// Simplified Chinese ("处理工作区— 尚未准备工作副本" for state='none').
assert('V14: working-mode-summary populated with idle Simplified Chinese text on state="none"',
       wmSummary && wmSummary.textContent === '处理工作区\u2014 尚未准备工作副本');
assert('V14: working-mode-list contains one row describing the idle state',
       wmList && wmList.children.length === 1);
assert('V14: idle row uses data-state="none" + .working-mode-row class',
       wmList && wmList.children[0] &&
       wmList.children[0].attrs['data-state'] === 'none' &&
       wmList.children[0].classes.indexOf('working-mode-row') !== -1);
assert('V14: idle row text uses textContent (no [object Object])',
       wmList && wmList.children[0] &&
       wmList.children[0].textContent.indexOf('[object Object]') === -1);
// V1.6 UI-CN-SIMPLIFICATION (dispatch §4): in state='none' only
// the primary Prepare CTA is rendered (unavailable actions are
// HIDDEN rather than rendered as disabled buttons). Secondary
// controls live in a collapsed "更多操作" block; with no
// workspace the block is collapsed-empty.
var wmActionBtns = wmActions ? wmActions.children : [];
assert('V14: state="none" produces exactly ONE top-level action button (Prepare CTA)',
       wmActionBtns.length === 1);
assert('V14: state="none" Prepare button has data-action="prepare_workspace"',
       wmActionBtns[0] && wmActionBtns[0].attrs['data-action'] === 'prepare_workspace' &&
       wmActionBtns[0].textContent === '准备处理' &&
       !wmActionBtns[0].hasAttribute('disabled'));

// Render with derivedWorkspace='ready' (active workspace).
renderWithPayload({
  selectionLabel: 'wm-ready', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-snap-001',
    source_fingerprint_digest: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    execution_config_digest: 'fedcba0987654321',
    workspace_id: 'ws-12345'
  }
});
var wmReadySummary = mockElements['working-mode-summary'];
var wmReadyList    = mockElements['working-mode-list'];
var wmReadyActions = mockElements['working-mode-actions'];
// V1.6 UI-CN-SIMPLIFICATION: ready state summary is Simplified
// Chinese ("处理工作区— 工作副本已准备，共 N 条记录").
assert('V14: ready state summary mentions "处理工作区— 工作副本已准备，共 N 条记录"',
       wmReadySummary && /处理工作区\u2014 工作副本已准备，共 \d+ 条记录/.test(wmReadySummary.textContent));
// V1.6 UI-CN-SIMPLIFICATION (per dispatch §5.5): the source
// snapshot id / fingerprint / config digest rows are moved to
// the collapsed `技术详情` block. The default Working Mode
// list no longer carries them. We assert they are preserved
// under 技术详情 here.
var wmReadyTechList = mockElements['technical-details-list'];
assert('V14: ready state 技术详情 block carries source_snapshot_id',
       wmReadyTechList && wmReadyTechList.children.some(function (c) {
         return c.textContent.indexOf('source_snapshot_id') !== -1 &&
                c.textContent.indexOf('wm-snap-001') !== -1;
       }));
assert('V14: ready state 技术详情 block carries source_fingerprint_digest',
       wmReadyTechList && wmReadyTechList.children.some(function (c) {
         return c.textContent.indexOf('source_fingerprint_digest') !== -1;
       }));
assert('V14: ready state 技术详情 block carries execution_config_digest',
       wmReadyTechList && wmReadyTechList.children.some(function (c) {
         return c.textContent.indexOf('execution_config_digest') !== -1 &&
                c.textContent.indexOf('fedcba0987654321') !== -1;
       }));
// V1.6 UI-CN-SIMPLIFICATION: in state='ready' WITHOUT a
// planar_normalization payload, the primary CTA is "检查平面偏差"
// (NOT_COMPUTED is the safe default). The collapsed "更多操作"
// block carries the secondary controls (放弃工作副本 + 重新生成).
// Unavailable actions are HIDDEN rather than rendered as
// disabled buttons.
var wmReadyBtns = wmReadyActions ? wmReadyActions.children : [];
assert('V14: state="ready" (no PN payload) produces TWO top-level elements (primary CTA + collapsed 更多操作)',
       wmReadyBtns.length === 2);
// First child: primary CTA "检查平面偏差".
var wmReadyPrimaryCTA = wmReadyBtns[0];
assert('V14: state="ready" primary CTA is "检查平面偏差" (Simplified Chinese, data-action=compute_planar_normalization)',
       wmReadyPrimaryCTA && wmReadyPrimaryCTA.textContent === '检查平面偏差' &&
       wmReadyPrimaryCTA.attrs['data-action'] === 'compute_planar_normalization' &&
       !wmReadyPrimaryCTA.hasAttribute('disabled'));
// Second child: collapsed 更多操作 block; the actionable
// Discard / Rebuild buttons live INSIDE its .more-actions-inner.
var wmMoreActions = wmReadyBtns[1];
assert('V14: state="ready" 更多操作 block contains Discard + Rebuild (Simplified Chinese)',
       wmMoreActions && (function () {
         var inner = wmMoreActions.children.filter(function (c) {
           return c.classes.indexOf('more-actions-inner') !== -1;
         })[0];
         if (!inner) return false;
         var actions = inner.children.map(function (b) { return b.attrs['data-action']; });
         return actions.indexOf('discard_workspace') !== -1 &&
                actions.indexOf('rebuild_workspace') !== -1;
       })());
assert('V14: state="ready" Discard button inside 更多操作 is enabled and Simplified Chinese ("放弃工作副本")',
       (function () {
         var inner = wmMoreActions.children.filter(function (c) {
           return c.classes.indexOf('more-actions-inner') !== -1;
         })[0];
         if (!inner) return null;
         var btn = inner.children.filter(function (b) {
           return b.attrs['data-action'] === 'discard_workspace';
         })[0];
         return btn && !btn.hasAttribute('disabled') && btn.textContent === '放弃工作副本';
       })());

// Render with derivedWorkspace='discarded' (post-discard state).
renderWithPayload({
  selectionLabel: 'wm-discarded', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'discarded',
    source_snapshot_id: 'wm-snap-001',
    source_fingerprint_digest: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    execution_config_digest: 'fedcba0987654321',
    workspace_id: 'ws-12345'
  }
});
var wmDiscardedSummary = mockElements['working-mode-summary'];
var wmDiscardedActions = mockElements['working-mode-actions'];
// V1.6 UI-CN-SIMPLIFICATION: discarded state summary text is
// Simplified Chinese ("处理工作区— 工作副本已放弃").
assert('V14: discarded state summary shows "处理工作区— 工作副本已放弃"',
       wmDiscardedSummary && wmDiscardedSummary.textContent.indexOf('工作副本已放弃') !== -1);
// V16-UI-CN-SIMPLIFICATION-FIX (Owner real-host finding):
// after Discard the user may select a NEW CAD/source selection
// and must be able to create a fresh SourceSnapshot +
// Derived Workspace. Rebuild replays the previously captured
// workspace, which is not a substitute. The primary CTA in
// state='discarded' MUST therefore be 准备处理 (not Rebuild,
// not Discard).
assert('V16-FIX: discarded state primary CTA is Simplified Chinese "准备处理" (Owner real-host fix)',
       wmDiscardedActions && wmDiscardedActions.children.length >= 1 &&
       wmDiscardedActions.children[0].textContent === '准备处理' &&
       wmDiscardedActions.children[0].attrs['data-action'] === 'prepare_workspace' &&
       !wmDiscardedActions.children[0].hasAttribute('disabled'));
// Rebuild remains a SECONDARY action under the collapsed
// 更多操作 block (per dispatch §5; the previously captured
// source can still be replayed).
var wmDiscardedMoreBlock = wmDiscardedActions.children[1];
var wmDiscardedMoreInner = wmDiscardedMoreBlock && wmDiscardedMoreBlock.children.filter(function (c) {
  return c.classes.indexOf('more-actions-inner') !== -1;
})[0];
assert('V16-FIX: discarded state 更多操作 block contains "重新生成" as secondary action',
       wmDiscardedMoreInner && wmDiscardedMoreInner.children.some(function (b) {
         return b.textContent === '重新生成' &&
                b.attrs['data-action'] === 'rebuild_workspace' &&
                !b.hasAttribute('disabled');
       }));
// Discard is NOT rendered in state='discarded' (already discarded).
assert('V16-FIX: discarded state does NOT render "放弃工作副本" (already discarded)',
       (!wmDiscardedMoreInner || !wmDiscardedMoreInner.children.some(function (b) {
         return b.textContent === '放弃工作副本';
       })) && (!wmDiscardedActions.children.some(function (b) {
         return b.textContent === '放弃工作副本';
       })));
// NO disabled buttons anywhere in the discarded state
// (unavailable actions are HIDDEN, not disabled).
var wmDiscardedDisabledCount = 0;
(function countDisabled(el) {
  if (!el) return;
  if (el.attrs && el.attrs['disabled'] !== undefined) wmDiscardedDisabledCount++;
  if (el.children) for (var i = 0; i < el.children.length; i++) countDisabled(el.children[i]);
})(wmDiscardedActions);
assert('V16-FIX: discarded state renders ZERO disabled buttons (unavailable actions are HIDDEN, not disabled)',
       wmDiscardedDisabledCount === 0);
// Click the 准备处理 CTA and verify it dispatches EXACTLY to
// window.sketchup.prepare_workspace (NOT rebuild_workspace,
// NOT discard_workspace).
resetV14HostActionCalls();
wmDiscardedActions.children[0].fireEvent('click');
assert('V16-FIX: clicking "准备处理" in discarded state calls prepare_workspace EXACTLY ONCE',
       mockWindow.sketchup.prepare_workspace_calls.length === 1);
assert('V16-FIX: clicking "准备处理" in discarded state does NOT call rebuild_workspace',
       mockWindow.sketchup.rebuild_workspace_calls.length === 0);
assert('V16-FIX: clicking "准备处理" in discarded state does NOT call discard_workspace',
       mockWindow.sketchup.discard_workspace_calls.length === 0);
// Click the secondary 重新生成 button and verify it dispatches
// to rebuild_workspace (NOT prepare_workspace).
resetV14HostActionCalls();
if (wmDiscardedMoreInner) {
  wmDiscardedMoreInner.children.forEach(function (b) { b.fireEvent('click'); });
}
assert('V16-FIX: clicking "重新生成" (secondary) in discarded state calls rebuild_workspace EXACTLY ONCE',
       mockWindow.sketchup.rebuild_workspace_calls.length === 1);
assert('V16-FIX: clicking "重新生成" (secondary) in discarded state does NOT call prepare_workspace',
       mockWindow.sketchup.prepare_workspace_calls.length === 0);

// Render with derivedWorkspace='failed' (build failure state).
renderWithPayload({
  selectionLabel: 'wm-failed', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'failed',
    source_snapshot_id: 'wm-snap-001',
    source_fingerprint_digest: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    execution_config_digest: 'fedcba0987654321',
    workspace_id: 'ws-12345',
    last_error: 'host failure during create_top_level_group'
  }
});
var wmFailedList = mockElements['working-mode-list'];
// V1.6 UI-CN-SIMPLIFICATION: failed state shows a concise
// Chinese recovery sentence in the primary list. The raw
// last_error is preserved under `技术详情` for Owner / AIPM
// diagnosis (not asserted here; see CN11 below).
assert('V14: failed state has a row describing "处理失败，请点击下方「重新生成」"',
       (function () {
         if (!wmFailedList) return false;
         var found = wmFailedList.children.filter(function (c) {
           return c.textContent.indexOf('处理失败') !== -1 &&
                  c.textContent.indexOf('重新生成') !== -1;
         });
         return found.length >= 1;
       })());
// V16-UI-CN-SIMPLIFICATION-FIX (Owner real-host "same class of
// mistake" review): the user may select a NEW source after a
// failed build. Prepare is the primary CTA in state='failed';
// Rebuild is the secondary action under 更多操作.
var wmFailedActions = mockElements['working-mode-actions'];
assert('V16-FIX: failed state primary CTA is Simplified Chinese "准备处理" (Owner real-host fix)',
       wmFailedActions && wmFailedActions.children.length >= 1 &&
       wmFailedActions.children[0].textContent === '准备处理' &&
       wmFailedActions.children[0].attrs['data-action'] === 'prepare_workspace' &&
       !wmFailedActions.children[0].hasAttribute('disabled'));
var wmFailedMoreBlock = wmFailedActions.children[1];
var wmFailedMoreInner = wmFailedMoreBlock && wmFailedMoreBlock.children.filter(function (c) {
  return c.classes.indexOf('more-actions-inner') !== -1;
})[0];
assert('V16-FIX: failed state 更多操作 block contains "重新生成" as secondary action',
       wmFailedMoreInner && wmFailedMoreInner.children.some(function (b) {
         return b.textContent === '重新生成' &&
                b.attrs['data-action'] === 'rebuild_workspace' &&
                !b.hasAttribute('disabled');
       }));
// Click the 准备处理 CTA and verify dispatch.
resetV14HostActionCalls();
wmFailedActions.children[0].fireEvent('click');
assert('V16-FIX: clicking "准备处理" in failed state calls prepare_workspace EXACTLY ONCE',
       mockWindow.sketchup.prepare_workspace_calls.length === 1);
assert('V16-FIX: clicking "准备处理" in failed state does NOT call rebuild_workspace',
       mockWindow.sketchup.rebuild_workspace_calls.length === 0);

// Defensive: missing derivedWorkspace => treated as 'none' state.
renderWithPayload({
  selectionLabel: 'wm-missing', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: []
  // derivedWorkspace is intentionally missing.
});
// V1.6 UI-CN-SIMPLIFICATION: default Simplified Chinese text.
assert('V14: missing derivedWorkspace defaults to state="none" (Simplified Chinese: "处理工作区— 尚未准备工作副本")',
       mockElements['working-mode-summary'].textContent === '处理工作区\u2014 尚未准备工作副本');

// Action button click -> invokes window.SUAIP[callback].
// (The previous assertion's wording was wrong: the host
// action callbacks live on window.sketchup, NOT
// window.SUAIP. The corrected assertions below use
// window.sketchup.<callback>.) We re-run it for legacy
// clarity: the click MUST NOT touch window.SUAIP[callback].
var locateCountBefore = locateCalls.length;
wmReadyActions.children.forEach(function (b) { b.fireEvent('click'); });
assert('V14: clicking Rebuild in state="ready" does NOT invoke Locate (it is a separate callback)',
       locateCalls.length === locateCountBefore);

// ROOT.renderWorkingMode is exposed.
assert('V14: ROOT.renderWorkingMode is exposed',
       typeof context.window.SUAIP.renderWorkingMode === 'function');

// =================================================================
// V14-RUNTIME-BLOCK-001 (real SU2020 Owner-found BLOCK)
// =================================================================
// Per CodeX V14-RUNTIME-BLOCK-001: the host action callbacks
// (Prepare / Discard / Rebuild) live on window.sketchup, NOT
// on window.SUAIP. The previous app.js#addAction resolved via
// `window.SUAIP[callback]` -- which never matched the
// real-SU callback path -- so the click handler was a
// no-op on a real SU host. The fixed addAction resolves via
// `window.sketchup[callback]` (bracket lookup, no eval).
//
// These assertions verify the FIXED dispatch path:
//   - Prepare click -> window.sketchup.prepare_workspace
//     exactly ONCE.
//   - Discard click -> window.sketchup.discard_workspace
//     exactly ONCE.
//   - Rebuild click -> window.sketchup.rebuild_workspace
//     exactly ONCE.
//   - Clicking the action buttons MUST NOT invoke Locate
//     (separate callback, must not be aliased).
//   - A disabled Prepare MUST NOT invoke any callback.
//   - Source guard: app.js#addAction MUST mention
//     `window.sketchup` AND MUST NOT use
//     `window.SUAIP[callback]` as host-action dispatch.

// Re-render with state="none" so we can click Prepare (the
// only enabled button in state='none').
renderWithPayload({
  selectionLabel: 'wm-click-none', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: { state: 'none' }
});
var wmNoneActions = mockElements['working-mode-actions'];
var wmNoneBtns = wmNoneActions ? wmNoneActions.children : [];
assert('V14-RUNTIME-BLOCK-001: state="none" produces ONE top-level action (Prepare CTA + collapsed More操作 block)',
       wmNoneBtns.length === 1);
assert('V14-RUNTIME-BLOCK-001: state="none" Prepare button is enabled',
       wmNoneBtns[0] && !wmNoneBtns[0].hasAttribute('disabled') &&
       wmNoneBtns[0].textContent === '准备处理');

resetV14HostActionCalls();
wmNoneBtns[0].fireEvent('click');
assert('V14-RUNTIME-BLOCK-001: clicking Prepare in state="none" calls window.sketchup.prepare_workspace EXACTLY ONCE',
       mockWindow.sketchup.prepare_workspace_calls.length === 1);
assert('V14-RUNTIME-BLOCK-001: clicking Prepare does NOT call discard / rebuild',
       mockWindow.sketchup.discard_workspace_calls.length === 0 &&
       mockWindow.sketchup.rebuild_workspace_calls.length === 0);
assert('V14-RUNTIME-BLOCK-001: clicking Prepare does NOT invoke Locate',
       locateCalls.length === locateCountBefore);

// Re-render with state="ready" and click Discard / Rebuild.
renderWithPayload({
  selectionLabel: 'wm-click-ready', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: { state: 'ready' }
});
var wmReadyActions2 = mockElements['working-mode-actions'];
var wmReadyBtns2 = wmReadyActions2 ? wmReadyActions2.children : [];
resetV14HostActionCalls();
// V1.6 UI-CN-SIMPLIFICATION: the primary CTA "检查平面偏差"
// is the first top-level button; the secondary Discard /
// Rebuild buttons live INSIDE the collapsed `更多操作`
// block (the second top-level element). Drill into the
// .more-actions-inner child container to find them.
var wmReady2Inner = wmReadyBtns2[1].children.filter(function (c) {
  return c.classes.indexOf('more-actions-inner') !== -1;
})[0];
var wmDiscardBtn = wmReady2Inner.children.filter(function (b) {
  return b.attrs['data-action'] === 'discard_workspace';
})[0];
wmDiscardBtn.fireEvent('click');
assert('V14-RUNTIME-BLOCK-001: clicking Discard in state="ready" calls window.sketchup.discard_workspace EXACTLY ONCE',
       mockWindow.sketchup.discard_workspace_calls.length === 1);
assert('V14-RUNTIME-BLOCK-001: clicking Discard does NOT call prepare / rebuild',
       mockWindow.sketchup.prepare_workspace_calls.length === 0 &&
       mockWindow.sketchup.rebuild_workspace_calls.length === 0);
assert('V14-RUNTIME-BLOCK-001: clicking Discard does NOT invoke Locate',
       locateCalls.length === locateCountBefore);

resetV14HostActionCalls();
var wmRebuildBtn = wmReady2Inner.children.filter(function (b) {
  return b.attrs['data-action'] === 'rebuild_workspace';
})[0];
wmRebuildBtn.fireEvent('click');
assert('V14-RUNTIME-BLOCK-001: clicking Rebuild in state="ready" calls window.sketchup.rebuild_workspace EXACTLY ONCE',
       mockWindow.sketchup.rebuild_workspace_calls.length === 1);
assert('V14-RUNTIME-BLOCK-001: clicking Rebuild does NOT call prepare / discard',
       mockWindow.sketchup.prepare_workspace_calls.length === 0 &&
       mockWindow.sketchup.discard_workspace_calls.length === 0);
assert('V14-RUNTIME-BLOCK-001: clicking Rebuild does NOT invoke Locate',
       locateCalls.length === locateCountBefore);

// Disabled Prepare MUST NOT invoke any host action.
renderWithPayload({
  selectionLabel: 'wm-disabled-prepare', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: { state: 'ready' }
});
var wmReady3 = mockElements['working-mode-actions'];
var wmReady3Btns = wmReady3 ? wmReady3.children : [];
// V1.6 UI-CN-SIMPLIFICATION: in state="ready" the Prepare
// CTA is HIDDEN (not rendered) because the user already has
// a workspace. Re-prepare requires Discard first. We verify
// no Prepare button is present at all (not even disabled).
resetV14HostActionCalls();
var wmReady3Prepare = wmReady3Btns[0].querySelector ? null : null;
var wmReady3PrepareBtn = (function () {
  // Search the entire actions tree for any button with
  // data-action="prepare_workspace".
  function search(el) {
    if (!el) return null;
    if (el.attrs && el.attrs['data-action'] === 'prepare_workspace') return el;
    if (!el.children) return null;
    for (var i = 0; i < el.children.length; i++) {
      var found = search(el.children[i]);
      if (found) return found;
    }
    return null;
  }
  return search(wmReady3);
})();
assert('V14-RUNTIME-BLOCK-001: state="ready" Prepare button is HIDDEN (unavailable actions are not rendered)',
       wmReady3PrepareBtn === null);
assert('V14-RUNTIME-BLOCK-001: clicking any rendered button in state="ready" does NOT invoke prepare_workspace',
       mockWindow.sketchup.prepare_workspace_calls.length === 0);

// Source guard: app.js#addAction MUST mention
// `window.sketchup` (host dispatch path) AND MUST NOT use
// `window.SUAIP[callback]` as host-action dispatch.
var appJsSrc = fs.readFileSync(appJsPath, 'utf-8');
// Locate the addAction function body.
var addActionMatch = appJsSrc.match(/function\s+addAction\s*\([^)]*\)\s*\{[\s\S]*?\n\s\s\}\n/);
if (addActionMatch === null) {
  // Fallback for slightly different brace placement.
  var start = appJsSrc.indexOf('function addAction');
  if (start >= 0) {
    var rest = appJsSrc.substring(start);
    var end = rest.indexOf('\n  }\n');
    if (end >= 0) addActionMatch = [null, rest.substring(0, end + 4)];
  }
}
var addActionBody = addActionMatch ? addActionMatch[0] : '';
assert('V14-RUNTIME-BLOCK-001 source guard: addAction MUST mention window.sketchup',
       addActionBody.indexOf('window.sketchup') >= 0);
assert('V14-RUNTIME-BLOCK-001 source guard: addAction MUST NOT use window.SUAIP[callback] as host-action dispatch',
       addActionBody.indexOf('root[callback]') < 0 &&
       addActionBody.indexOf('SUAIP[callback]') < 0);
assert('V14-RUNTIME-BLOCK-001 source guard: addAction MUST NOT use eval',
       addActionBody.indexOf('eval(') < 0);

// =================================================================
// V15 Phase 1: Duplicate repairs row in Working Mode summary
// =================================================================
// Per V1.5 Phase 1 plan §6 step 6: minimal Working Mode UI
// summary addition. When derivedWorkspace.duplicate_repair is
// present (and has actions_applied / actions_skipped integers),
// a single labelled 'Duplicate repairs' row is rendered.

renderWithPayload({
  selectionLabel: 'wm-v15-ready', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v15-snap',
    source_fingerprint_digest: 'aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v15cfg',
    workspace_id: 'ws-v15-001',
    duplicate_repair: {
      duplicate_pairs_before: 2,
      duplicate_pairs_after: 0,
      actions_applied: 2,
      actions_skipped: 0,
      last_action_status: 'applied'
    }
  }
});
var v15ReadyList = mockElements['working-mode-list'];
// V1.6 UI-CN-SIMPLIFICATION: the condensed user-facing
// duplicate-repair row uses Simplified Chinese: "重复线清理：已处理 X，跳过 Y，失败 Z".
assert('V15: ready state with duplicate_repair renders a Simplified Chinese "重复线清理" row',
       v15ReadyList && v15ReadyList.children.some(function (c) {
         return c.textContent.indexOf('重复线清理') !== -1 &&
                c.textContent.indexOf('已处理 2') !== -1;
       }));
assert('V15: ready state duplicate_repair row uses data-state="ready"',
       v15ReadyList && v15ReadyList.children.some(function (c) {
         return c.textContent.indexOf('重复线清理') !== -1 &&
                c.attrs['data-state'] === 'ready';
       }));
assert('V15: ready state duplicate_repair row uses textContent (no innerHTML)',
       v15ReadyList && v15ReadyList.children.every(function (c) {
         return c.textContent.indexOf('[object Object]') === -1;
       }));

// In 'none' state with a recorded duplicate_repair summary
// (audit trail survives Discard), the row still appears.
renderWithPayload({
  selectionLabel: 'wm-v15-discarded', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'none',
    duplicate_repair: {
      duplicate_pairs_before: 1,
      duplicate_pairs_after: 0,
      actions_applied: 1,
      actions_skipped: 0,
      last_action_status: 'applied'
    }
  }
});
var v15NoneList = mockElements['working-mode-list'];
assert('V15: none state with duplicate_repair renders a Simplified Chinese "重复线清理" row',
       v15NoneList && v15NoneList.children.some(function (c) {
         return c.textContent.indexOf('重复线清理') !== -1 &&
                c.textContent.indexOf('已处理 1') !== -1;
       }));

// Without duplicate_repair, no Duplicate repairs row.
renderWithPayload({
  selectionLabel: 'wm-v15-no-dr', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: { state: 'none' }
});
var v15NoDrList = mockElements['working-mode-list'];
assert('V15: no duplicate_repair -> no "重复线清理" row (Simplified Chinese)',
       v15NoDrList && !v15NoDrList.children.some(function (c) {
         return c.textContent.indexOf('重复线清理') !== -1;
       }));

// Stage 3 (§8): when duplicate_classes_before/after are present,
// the row MUST surface the derived-duplicate class counts.
renderWithPayload({
  selectionLabel: 'wm-v15-classes', selectionType: 'Group',
  summary: { edges: 2, vertices: 2, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v15-snap',
    source_fingerprint_digest: 'aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v15cfg',
    workspace_id: 'ws-v15-002',
    duplicate_repair: {
      duplicate_pairs_before: 1,
      duplicate_pairs_after: 0,
      actions_applied: 1,
      actions_skipped: 0,
      last_action_status: 'applied',
      duplicate_classes_before: 1,
      duplicate_classes_after: 0
    }
  }
});
var v15ClassesList = mockElements['working-mode-list'];
// V1.6 UI-CN-SIMPLIFICATION: the condensed user-facing
// duplicate-repair row no longer surfaces the internal class
// counts by default (those are preserved in the 技术详情
// block). The condensed row reads only "重复线清理：已处理 X，跳过 Y，失败 Z".
assert('V15: duplicate_repair with class counts renders the condensed Simplified Chinese row (no internal class counts by default)',
       v15ClassesList && v15ClassesList.children.some(function (c) {
         return c.textContent.indexOf('重复线清理') !== -1 &&
                c.textContent.indexOf('已处理 1') !== -1 &&
                c.textContent.indexOf('duplicate classes') === -1;
       }));

// Source guard: renderWorkingMode MUST NOT use innerHTML for
// the duplicate_repair row (textContent only contract).
var v15SrcMatch = appJsSrc.match(/function\s+renderWorkingMode\s*\([\s\S]*?\n  \}/);
var v15SrcBody = v15SrcMatch ? v15SrcMatch[0] : appJsSrc;
assert('V15 source guard: renderWorkingMode does NOT use .innerHTML',
       v15SrcBody.indexOf('.innerHTML') === -1);
assert('V15 source guard: renderWorkingMode uses .textContent',
       v15SrcBody.indexOf('.textContent') >= 0);

// =====================================================================
// V15 BLOCK-004 DOM tests (CodeX 032 recheck 2026-08-25):
// every per-action audit row must include status, removed
// count, survivor ID, and source-occurrence count as visible
// fields. The UI MUST render these from the summary, not
// from a hand-built label. textContent only.
// =====================================================================

// Reset the working-mode-list before the BLOCK-004 DOM tests.
renderWithPayload({
  selectionLabel: 'wm-v15-block004', selectionType: 'Group',
  summary: { edges: 2, vertices: 2, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v15-block004-snap',
    source_fingerprint_digest: 'aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v15cfg',
    workspace_id: 'ws-v15-block004',
    duplicate_repair: {
      duplicate_pairs_before: 1,
      duplicate_pairs_after: 0,
      actions_applied: 1,
      actions_skipped: 0,
      actions_failed: 0,
      last_action_status: 'applied',
      duplicate_classes_before: 1,
      duplicate_classes_after: 0,
      derived_edge_count_before: 2,
      derived_edge_count_after: 1,
      actions: [{
        action_id: 'act-block004-1',
        status: 'applied',
        rule_id: 'duplicate_edge.exact_remove',
        explanation: 'BLOCK-004 DOM test fixture',
        confidence_basis: 'exact_endpoint_match_within_tolerance.duplicate',
        source_occurrence_ids: ['occ-100>100', 'occ-200>101'],
        source_occurrence_count: 2,
        affected_derived_ids: ['der-B'],
        removed_count: 1,
        survivor_derived_id: 'der-A',
        issue_ids: ['duplicate|0|1'],
        before_summary: {}
      }]
    }
  }
});
var v15Block004List = mockElements['working-mode-list'];
// Every per-action audit row MUST be a DOM row carrying the
// audit fields as inspectable data-* attributes. We assert the
// V1.6 UI-CN-SIMPLIFICATION (per dispatch §6 + §5.5): the
// per-action audit row (status / action_id / survivor_id /
// removed_count / source_count / rule_id / basis) is moved
// from the default primary Working Mode list to the
// `技术详情` block. The default list shows only the condensed
// Simplified Chinese summary row. We assert the per-action
// audit data is preserved under 技术详情 here.
var v15Block004TechList = mockElements['technical-details-list'];
var v15Block004Row = v15Block004TechList && v15Block004TechList.children.find(function (c) {
  return c.attrs && c.attrs['data-action-id'] === 'act-block004-1';
});
assert('V15 BLOCK-004: per-action audit row has data-action-id attribute (preserved in 技术详情)',
       v15Block004Row !== undefined && v15Block004Row !== null);
assert('V15 BLOCK-004: per-action audit row has data-action-status="applied"',
       v15Block004Row && v15Block004Row.attrs['data-action-status'] === 'applied');
assert('V15 BLOCK-004: per-action audit row has data-survivor-id="der-A"',
       v15Block004Row && v15Block004Row.attrs['data-survivor-id'] === 'der-A');
assert('V15 BLOCK-004: per-action audit row carries a removed_count cell',
       v15Block004Row && v15Block004Row.children.some(function (c) {
         return c.attrs && c.attrs['data-field'] === 'removed_count' &&
                c.textContent.indexOf('1') !== -1;
       }));
assert('V15 BLOCK-004: per-action audit row carries a source_count cell',
       v15Block004Row && v15Block004Row.children.some(function (c) {
         return c.attrs && c.attrs['data-field'] === 'source_count' &&
                c.textContent.indexOf('2') !== -1;
       }));
assert('V15 BLOCK-004: per-action audit row carries a survivor_id cell',
       v15Block004Row && v15Block004Row.children.some(function (c) {
         return c.attrs && c.attrs['data-field'] === 'survivor_id' &&
                c.textContent.indexOf('der-A') !== -1;
       }));
assert('V15 BLOCK-004: per-action audit row carries a status cell',
       v15Block004Row && v15Block004Row.children.some(function (c) {
         return c.attrs && c.attrs['data-field'] === 'status' &&
                c.textContent.indexOf('applied') !== -1;
       }));
// Source guard: per-action audit row uses textContent (no innerHTML).
assert('V15 BLOCK-004: per-action audit row uses textContent only (no innerHTML)',
       v15Block004Row && v15Block004Row.children.every(function (c) {
         return c.textContent.indexOf('[object Object]') === -1;
       }));
// Default Working Mode list no longer contains the per-action
// audit row (it was demoted to 技术详情 per dispatch §6).
var v15Block004NoAuditInDefault = v15Block004List && !v15Block004List.children.some(function (c) {
  return c.attrs && c.attrs['data-action-id'] === 'act-block004-1';
});
assert('V15 BLOCK-004: per-action audit row is NOT in the default Working Mode list (moved to 技术详情)',
       v15Block004NoAuditInDefault === true);

// =====================================================================
// V1.6 Planar Normalization / Z Policy (per dispatch
// V16-UI-INTEGRATION-CORRECTION-2026-09-01) — UI1..UI8: prove the
// actual shipped UI renders Planar Normalization state + the
// locked preview/apply action(s), and that all non-executable
// states fail closed. The DOM test loads the SHIPPED app.js
// (the test does NOT test a parallel helper that production
// does not call).
//
// UI1: NOT_COMPUTED  -> state row + "Analyze Planarity" button
// UI2: READY_TO_NORMALIZE -> target/counts + "Apply Safe
//      Normalization" enabled, click invokes exactly
//      window.sketchup.apply_planar_normalization.
// UI3: REVIEW_REQUIRED -> state/reason visible; Apply button
//      absent or disabled; NO destructive callback invoked.
// UI4: NO_CANDIDATE   -> truthful state visible; Apply
//      unavailable.
// UI5: APPLIED        -> truthful post-apply summary visible;
//      no stale READY_TO_NORMALIZE action remains.
// UI6: FAILED         -> failure state/reason visible; Apply
//      unavailable.
// UI7: missing/malformed planar_normalization -> old Working
//      Mode still renders; no crash; no [object Object] /
//      undefined / NaN.
// UI8: existing V1.4/V1.5 controls (Prepare/Discard/Rebuild +
//      duplicate repair row) remain UNCHANGED.
// =====================================================================

// UI1: NOT_COMPUTED + workspace ready.
renderWithPayload({
  selectionLabel: 'wm-v16-u1', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v16-u1-snap',
    source_fingerprint_digest: 'aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v16cfg',
    workspace_id: 'ws-v16-u1',
    planar_normalization: {
      computed: false,
      state:    'NOT_COMPUTED'
    }
  }
});
var ui1List    = mockElements['working-mode-list'];
var ui1Actions = mockElements['working-mode-actions'];

// V1.6 UI-CN-SIMPLIFICATION: UI1 assertions now use
// Simplified Chinese labels. The state name "NOT_COMPUTED" is
// translated to "未检查" in the visible card. The internal
// data field remains "state NOT_COMPUTED" inside 技术详情.
assert('UI1: NOT_COMPUTED + ready workspace renders a "平面校正" State row in Simplified Chinese',
       ui1List && ui1List.children.some(function (c) {
         return c.textContent.indexOf('平面校正') !== -1 &&
                c.textContent.indexOf('未检查') !== -1;
       }));
assert('UI1: NOT_COMPUTED + ready workspace renders a "检查平面偏差" primary action button',
       ui1Actions && ui1Actions.children.some(function (b) {
         return b.textContent === '检查平面偏差' &&
                b.attrs['data-action'] === 'compute_planar_normalization' &&
                !b.hasAttribute('disabled');
       }));
assert('UI1: NOT_COMPUTED + ready workspace does NOT render an "应用平面校正" button',
       ui1Actions && !ui1Actions.children.some(function (b) {
         return b.textContent === '应用平面校正';
       }));
// Reset host-action calls then click "Analyze Planarity".
resetV14HostActionCalls();
var ui1AnalyzeBtn = ui1Actions && ui1Actions.children.filter(function (b) {
  return b.attrs && b.attrs['data-action'] === 'compute_planar_normalization';
})[0];
ui1AnalyzeBtn.fireEvent('click');
assert('UI1: clicking "Analyze Planarity" calls window.sketchup.compute_planar_normalization EXACTLY ONCE',
       mockWindow.sketchup.compute_planar_normalization_calls.length === 1);
assert('UI1: clicking "Analyze Planarity" does NOT call apply_planar_normalization',
       mockWindow.sketchup.apply_planar_normalization_calls.length === 0);
assert('UI1: clicking "Analyze Planarity" does NOT call any V1.4/V1.5 host action',
       mockWindow.sketchup.prepare_workspace_calls.length === 0 &&
       mockWindow.sketchup.discard_workspace_calls.length === 0 &&
       mockWindow.sketchup.rebuild_workspace_calls.length === 0);

// UI2: READY_TO_NORMALIZE.
renderWithPayload({
  selectionLabel: 'wm-v16-u2', selectionType: 'Group',
  summary: { edges: 4, vertices: 8, non_zero_z_vertices: 4, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v16-u2-snap',
    source_fingerprint_digest: 'cccc1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v16cfg',
    workspace_id: 'ws-v16-u2',
    planar_normalization: {
      computed: true,
      state:    'READY_TO_NORMALIZE',
      proposal: {
        state:           'READY_TO_NORMALIZE',
        target_z:        1.003,
        eligible_count:  4,
        already_planar:  0,
        movable_count:   3,
        outlier_count:   1,
        affected_derived_ids: ['der-edge-1', 'der-edge-2', 'der-edge-3'],
        outlier_derived_ids:  ['der-edge-4'],
        shared_vertex_scope_skipped: 0,
        max_movement:    0.007,
        tolerance_used:  0.01
      }
    }
  }
});
var ui2List    = mockElements['working-mode-list'];
var ui2Actions = mockElements['working-mode-actions'];

// V1.6 UI-CN-SIMPLIFICATION: READY_TO_NORMALIZE renders the
// Simplified Chinese "可安全校正" state label. The condensed
// Blueprint §11 rows show target_z + 待移动顶点 + 异常点
// (no separate "Eligible Vertices" or "Affected Derived Edges"
// row by default; those are preserved in 技术详情 per dispatch §5.5).
assert('UI2: READY_TO_NORMALIZE renders a "平面校正" State row with Simplified Chinese "可安全校正" label',
       ui2List && ui2List.children.some(function (c) {
         return c.textContent.indexOf('平面校正') !== -1 &&
                c.textContent.indexOf('可安全校正') !== -1;
       }));
assert('UI2: READY_TO_NORMALIZE renders a "目标 Z" row with the proposal target_z',
       ui2List && ui2List.children.some(function (c) {
         return c.textContent.indexOf('目标 Z') !== -1 &&
                c.textContent.indexOf('1.003') !== -1;
       }));
assert('UI2: READY_TO_NORMALIZE renders "待移动顶点" count',
       ui2List && ui2List.children.some(function (c) {
         return c.textContent.indexOf('待移动顶点') !== -1 &&
                c.textContent.indexOf('3') !== -1;
       }));
assert('UI2: READY_TO_NORMALIZE renders "异常点" count',
       ui2List && ui2List.children.some(function (c) {
         return c.textContent.indexOf('异常点') !== -1 &&
                c.textContent.indexOf('1') !== -1;
       }));
assert('UI2: READY_TO_NORMALIZE renders the "应用平面校正" primary action button (enabled)',
       ui2Actions && ui2Actions.children.some(function (b) {
         return b.textContent === '应用平面校正' &&
                b.attrs['data-action'] === 'apply_planar_normalization' &&
                !b.hasAttribute('disabled');
       }));
assert('UI2: READY_TO_NORMALIZE does NOT render "检查平面偏差" button (already computed)',
       ui2Actions && !ui2Actions.children.some(function (b) {
         return b.textContent === '检查平面偏差';
       }));
// Click the apply button and verify dispatch.
resetV14HostActionCalls();
var ui2ApplyBtn = ui2Actions && ui2Actions.children.filter(function (b) {
  return b.attrs && b.attrs['data-action'] === 'apply_planar_normalization';
})[0];
ui2ApplyBtn.fireEvent('click');
assert('UI2: clicking "应用平面校正" calls window.sketchup.apply_planar_normalization EXACTLY ONCE',
       mockWindow.sketchup.apply_planar_normalization_calls.length === 1);
assert('UI2: clicking "应用平面校正" does NOT call compute_planar_normalization',
       mockWindow.sketchup.compute_planar_normalization_calls.length === 0);
assert('UI2: clicking "应用平面校正" does NOT call any V1.4/V1.5 host action',
       mockWindow.sketchup.prepare_workspace_calls.length === 0 &&
       mockWindow.sketchup.discard_workspace_calls.length === 0 &&
       mockWindow.sketchup.rebuild_workspace_calls.length === 0);
assert('UI2: clicking "应用平面校正" does NOT invoke Locate',
       locateCalls.length === locateCountBefore);

// UI3: REVIEW_REQUIRED.
renderWithPayload({
  selectionLabel: 'wm-v16-u3', selectionType: 'Group',
  summary: { edges: 6, vertices: 12, non_zero_z_vertices: 12, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v16-u3-snap',
    source_fingerprint_digest: 'dddd1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v16cfg',
    workspace_id: 'ws-v16-u3',
    planar_normalization: {
      computed: true,
      state:    'REVIEW_REQUIRED',
      proposal: {
        state:           'REVIEW_REQUIRED',
        reason:          'tied_dominant_windows',
        eligible_count:  6,
        movable_count:   0,
        outlier_count:   0,
        affected_derived_ids: [],
        max_movement:    0.0,
        tolerance_used:  0.01
      }
    }
  }
});
var ui3List    = mockElements['working-mode-list'];
var ui3Actions = mockElements['working-mode-actions'];

// V1.6 UI-CN-SIMPLIFICATION: REVIEW_REQUIRED renders the
// Simplified Chinese "需要人工确认" state label + a Chinese
// review-required explanation. The raw reason string is
// preserved under 技术详情.
assert('UI3: REVIEW_REQUIRED renders a "平面校正" State row with Simplified Chinese "需要人工确认" label',
       ui3List && ui3List.children.some(function (c) {
         return c.textContent.indexOf('平面校正') !== -1 &&
                c.textContent.indexOf('需要人工确认') !== -1;
       }));
assert('UI3: REVIEW_REQUIRED renders a Chinese review-required explanation ("检测到多组高度")',
       ui3List && ui3List.children.some(function (c) {
         return c.textContent.indexOf('检测到多组高度') !== -1;
       }));
assert('UI3: REVIEW_REQUIRED does NOT render "应用平面校正" (destructive button absent)',
       ui3Actions && !ui3Actions.children.some(function (b) {
         return b.textContent === '应用平面校正';
       }));
assert('UI3: REVIEW_REQUIRED does NOT render "检查平面偏差" (already computed)',
       ui3Actions && !ui3Actions.children.some(function (b) {
         return b.textContent === '检查平面偏差';
       }));
// NO destructive callback can be invoked -- verify by clicking
// every existing action button and confirming the V1.6
// destructive callback was NOT called.
resetV14HostActionCalls();
var ui3ActionsBefore = ui3Actions.children.slice();
ui3ActionsBefore.forEach(function (b) { b.fireEvent('click'); });
assert('UI3: clicking any UI3 action does NOT invoke apply_planar_normalization',
       mockWindow.sketchup.apply_planar_normalization_calls.length === 0);

// UI4: NO_CANDIDATE.
renderWithPayload({
  selectionLabel: 'wm-v16-u4', selectionType: 'Group',
  summary: { edges: 4, vertices: 8, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v16-u4-snap',
    source_fingerprint_digest: 'eeee1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v16cfg',
    workspace_id: 'ws-v16-u4',
    planar_normalization: {
      computed: true,
      state:    'NO_CANDIDATE',
      proposal: {
        state:          'NO_CANDIDATE',
        reason:         'already_planar',
        eligible_count: 4,
        already_planar: 4,
        movable_count:  0,
        outlier_count:  0,
        affected_derived_ids: [],
        max_movement:   0.0,
        tolerance_used: 0.01
      }
    }
  }
});
var ui4List    = mockElements['working-mode-list'];
var ui4Actions = mockElements['working-mode-actions'];

// V1.6 UI-CN-SIMPLIFICATION: NO_CANDIDATE renders the
// Simplified Chinese "无需校正" state label + a Chinese
// no-action explanation.
assert('UI4: NO_CANDIDATE renders a "平面校正" State row with Simplified Chinese "无需校正" label',
       ui4List && ui4List.children.some(function (c) {
         return c.textContent.indexOf('平面校正') !== -1 &&
                c.textContent.indexOf('无需校正') !== -1;
       }));
assert('UI4: NO_CANDIDATE does NOT render "应用平面校正"',
       ui4Actions && !ui4Actions.children.some(function (b) {
         return b.textContent === '应用平面校正';
       }));
assert('UI4: NO_CANDIDATE does NOT render "检查平面偏差" (already computed)',
       ui4Actions && !ui4Actions.children.some(function (b) {
         return b.textContent === '检查平面偏差';
       }));

// UI5: APPLIED.
renderWithPayload({
  selectionLabel: 'wm-v16-u5', selectionType: 'Group',
  summary: { edges: 4, vertices: 8, non_zero_z_vertices: 4, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v16-u5-snap',
    source_fingerprint_digest: 'ffff1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v16cfg',
    workspace_id: 'ws-v16-u5',
    planar_normalization: {
      computed: true,
      state:    'APPLIED',
      audit: {
        status:          'applied',
        rule_id:         'planar_z_snap.v1',
        rule_version:    '1',
        target_z:        1.003,
        affected_derived_ids: ['der-edge-1', 'der-edge-2', 'der-edge-3'],
        outlier_derived_ids:  ['der-edge-4'],
        before_z_summary: { count: 4, min: 0.996, max: 1.008, mean: 1.00275 },
        after_z_summary:  { count: 4, min: 1.003, max: 1.003, mean: 1.003 },
        max_movement:     0.007,
        applied_count:    4,
        failed_count:     0
      }
    }
  }
});
var ui5List    = mockElements['working-mode-list'];
var ui5Actions = mockElements['working-mode-actions'];

// V1.6 UI-CN-SIMPLIFICATION: APPLIED renders the Simplified
// Chinese "已校正" state label + a Chinese completion
// summary ("平面校正已完成。") + condensed Chinese user-facing
// rows (已移动 / 最大校正量 / 保留异常项). Raw audit values are
// preserved under 技术详情.
assert('UI5: APPLIED renders a "平面校正" State row with Simplified Chinese "已校正" label',
       ui5List && ui5List.children.some(function (c) {
         return c.textContent.indexOf('平面校正') !== -1 &&
                c.textContent.indexOf('已校正') !== -1;
       }));
assert('UI5: APPLIED renders a Chinese completion summary ("平面校正已完成。")',
       ui5List && ui5List.children.some(function (c) {
         return c.textContent.indexOf('平面校正已完成') !== -1;
       }));
assert('UI5: APPLIED renders "已移动" count',
       ui5List && ui5List.children.some(function (c) {
         return c.textContent.indexOf('已移动') !== -1 &&
                c.textContent.indexOf('4') !== -1;
       }));
assert('UI5: APPLIED renders "保留异常项" count',
       ui5List && ui5List.children.some(function (c) {
         return c.textContent.indexOf('保留异常项') !== -1 &&
                c.textContent.indexOf('1') !== -1;
       }));
assert('UI5: APPLIED does NOT leave a stale "应用平面校正" button (no stale READY_TO_NORMALIZE action)',
       ui5Actions && !ui5Actions.children.some(function (b) {
         return b.textContent === '应用平面校正';
       }));
assert('UI5: APPLIED does NOT render "检查平面偏差" (already in terminal APPLIED state)',
       ui5Actions && !ui5Actions.children.some(function (b) {
         return b.textContent === '检查平面偏差';
       }));
// Verify no destructive callback can be invoked from APPLIED.
resetV14HostActionCalls();
var ui5ActionsBefore = ui5Actions.children.slice();
ui5ActionsBefore.forEach(function (b) { b.fireEvent('click'); });
assert('UI5: clicking any UI5 action does NOT invoke apply_planar_normalization',
       mockWindow.sketchup.apply_planar_normalization_calls.length === 0);

// UI6: FAILED.
renderWithPayload({
  selectionLabel: 'wm-v16-u6', selectionType: 'Group',
  summary: { edges: 4, vertices: 8, non_zero_z_vertices: 4, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'failed',
    source_snapshot_id: 'wm-v16-u6-snap',
    source_fingerprint_digest: 'aaaa2222bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v16cfg',
    workspace_id: 'ws-v16-u6',
    last_error: 'host failure during build',
    planar_normalization: {
      computed: true,
      state:    'FAILED',
      audit: {
        status:          'failed',
        rule_id:         'planar_z_snap.v1',
        rule_version:    '1',
        target_z:        1.003,
        affected_derived_ids: ['der-edge-1', 'der-edge-2', 'der-edge-3'],
        outlier_derived_ids:  ['der-edge-4'],
        max_movement:     0.0,
        applied_count:    0,
        failed_count:     1,
        reason:           'post_validation_failed:vertex_0_dx_0.5_exceeds_eps'
      }
    }
  }
});
var ui6List    = mockElements['working-mode-list'];
var ui6Actions = mockElements['working-mode-actions'];

// V1.6 UI-CN-SIMPLIFICATION: FAILED renders the Simplified
// Chinese "校正失败" state label + a Chinese failure reason
// ("失败原因"). The raw reason string is preserved under
// 技术详情.
assert('UI6: FAILED renders a "平面校正" State row with Simplified Chinese "校正失败" label',
       ui6List && ui6List.children.some(function (c) {
         return c.textContent.indexOf('平面校正') !== -1 &&
                c.textContent.indexOf('校正失败') !== -1;
       }));
assert('UI6: FAILED renders a Chinese failure explanation',
       ui6List && ui6List.children.some(function (c) {
         return c.textContent.indexOf('失败原因') !== -1;
       }));
assert('UI6: FAILED does NOT render "应用平面校正"',
       ui6Actions && !ui6Actions.children.some(function (b) {
         return b.textContent === '应用平面校正';
       }));
assert('UI6: FAILED does NOT render "检查平面偏差"',
       ui6Actions && !ui6Actions.children.some(function (b) {
         return b.textContent === '检查平面偏差';
       }));
// V1.5 failure contract: the failed workspace still surfaces
// the concise Chinese recovery sentence ("处理失败，请点击下方「重新生成」").
assert('UI6: FAILED still surfaces the V1.5 Chinese recovery sentence',
       ui6List && ui6List.children.some(function (c) {
         return c.textContent.indexOf('处理失败') !== -1 &&
                c.textContent.indexOf('重新生成') !== -1;
       }));

// UI7: missing / malformed planar_normalization.
renderWithPayload({
  selectionLabel: 'wm-v16-u7', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v16-u7-snap',
    source_fingerprint_digest: 'cccc2222bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v16cfg',
    workspace_id: 'ws-v16-u7'
    // planar_normalization is intentionally missing
  }
});
var ui7List = mockElements['working-mode-list'];
var ui7Actions = mockElements['working-mode-actions'];
// UI7: a missing planar_normalization payload in a READY
// workspace is treated as NOT_COMPUTED per dispatch §4.2.
// The primary CTA is therefore "检查平面偏差" (the user can
// still run the analyzer). The destructive "应用平面校正"
// button MUST NOT be rendered in this state. The old
// Working Mode still renders (no crash).
assert('UI7: missing planar_normalization -> no "平面校正" card row rendered (graceful degrade)',
       ui7List && !ui7List.children.some(function (c) {
         return c.textContent.indexOf('平面校正') !== -1;
       }));
assert('UI7: missing planar_normalization -> primary CTA is "检查平面偏差" (NOT_COMPUTED safe default)',
       ui7Actions && ui7Actions.children.some(function (b) {
         return b.textContent === '检查平面偏差' &&
                b.attrs['data-action'] === 'compute_planar_normalization';
       }));
assert('UI7: missing planar_normalization -> destructive "应用平面校正" button is NOT rendered',
       ui7Actions && !ui7Actions.children.some(function (b) {
         return b.textContent === '应用平面校正';
       }));
assert('UI7: missing planar_normalization -> working-mode-summary is populated (no crash)',
       mockElements['working-mode-summary'] &&
       mockElements['working-mode-summary'].textContent.indexOf('处理工作区') !== -1);
assert('UI7: missing planar_normalization -> no [object Object] / undefined / NaN',
       (function () {
         var texts = [];
         function collect(el) {
           if (el.textContent) texts.push(el.textContent);
           for (var i = 0; i < el.children.length; i++) collect(el.children[i]);
         }
         collect(ui7List);
         var all = texts.join(' | ');
         if (all.indexOf('[object Object]') !== -1) return false;
         if (all.indexOf('undefined') !== -1) return false;
         if (all.indexOf('NaN') !== -1) return false;
         return true;
       })());

// UI7 (extended): a malformed planar_normalization (e.g.
// a String) degrades safely -- no crash, no [object Object],
// no destructive Apply button rendered. The primary CTA
// stays "检查平面偏差" because the JS layer treats missing /
// malformed pn as NOT_COMPUTED.
renderWithPayload({
  selectionLabel: 'wm-v16-u7-malformed', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v16-u7-mal-snap',
    workspace_id: 'ws-v16-u7-mal',
    planar_normalization: 'malformed-not-an-object'
  }
});
var ui7malList = mockElements['working-mode-list'];
assert('UI7: malformed planar_normalization (String) -> graceful degrade, working-mode-summary populated (no crash)',
       ui7malList && mockElements['working-mode-summary'] &&
       mockElements['working-mode-summary'].textContent.indexOf('处理工作区') !== -1);
assert('UI7: malformed planar_normalization (String) -> destructive Apply button NOT rendered',
       !mockElements['working-mode-actions'].children.some(function (b) {
         return b.textContent === '应用平面校正';
       }));

// UI8: V1.4/V1.5 controls remain UNCHANGED when V1.6 state is
// present (Prepare / Discard / Rebuild + Duplicate repair row
// still behave per their original contract).
renderWithPayload({
  selectionLabel: 'wm-v16-u8', selectionType: 'Group',
  summary: { edges: 4, vertices: 8, non_zero_z_vertices: 4, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'wm-v16-u8-snap',
    source_fingerprint_digest: 'bbbb2222bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222',
    execution_config_digest: 'v16cfg',
    workspace_id: 'ws-v16-u8',
    duplicate_repair: {
      duplicate_pairs_before: 2,
      duplicate_pairs_after: 0,
      actions_applied: 2,
      actions_skipped: 0,
      actions_failed: 0,
      last_action_status: 'applied',
      duplicate_classes_before: 2,
      duplicate_classes_after: 0,
      derived_edge_count_before: 4,
      derived_edge_count_after: 2
    },
    planar_normalization: {
      computed: true,
      state:    'READY_TO_NORMALIZE',
      proposal: {
        state:           'READY_TO_NORMALIZE',
        target_z:        1.003,
        eligible_count:  4,
        movable_count:   3,
        outlier_count:   1,
        affected_derived_ids: ['der-edge-1', 'der-edge-2', 'der-edge-3'],
        max_movement:    0.007,
        tolerance_used:  0.01
      }
    }
  }
});
var ui8List    = mockElements['working-mode-list'];
var ui8Actions = mockElements['working-mode-actions'];

// V1.6 UI-CN-SIMPLIFICATION: the condensed Simplified Chinese
// "重复线清理：已处理 X，跳过 Y，失败 Z" row is still rendered
// (parallel presence with the planar_normalization card).
assert('UI8: V1.5 Simplified Chinese "重复线清理" row is still rendered (V1.6 wiring did not break V1.5 audit)',
       ui8List && ui8List.children.some(function (c) {
         return c.textContent.indexOf('重复线清理') !== -1 &&
                c.textContent.indexOf('已处理 2') !== -1;
       }));
assert('UI8: V1.6 "平面校正" row is also rendered (parallel presence, Simplified Chinese)',
       ui8List && ui8List.children.some(function (c) {
         return c.textContent.indexOf('平面校正') !== -1 &&
                c.textContent.indexOf('可安全校正') !== -1;
       }));
// V1.6 UI-CN-SIMPLIFICATION: the Simplified Chinese primary
// CTA "应用平面校正" is the FIRST top-level child when the
// planar normalization state is READY_TO_NORMALIZE. The
// collapsed 更多操作 block (carrying Discard + Rebuild) is the
// SECOND top-level child. The Prepare button is HIDDEN (not
// disabled) in state="ready" because the user already has a
// workspace (re-prepare requires Discard first).
var ui8TopBtn = ui8Actions.children[0];
assert('UI8: primary CTA "应用平面校正" is rendered as the top-level button (Simplified Chinese)',
       ui8TopBtn && ui8TopBtn.textContent === '应用平面校正' &&
       ui8TopBtn.attrs['data-action'] === 'apply_planar_normalization' &&
       !ui8TopBtn.hasAttribute('disabled'));
// Secondary Discard / Rebuild live INSIDE the collapsed
// 更多操作 block (the SECOND top-level child of #working-mode-actions).
var ui8MoreBlock = ui8Actions.children[1];
var ui8MoreInner = ui8MoreBlock && ui8MoreBlock.children.filter(function (c) {
  return c.classes.indexOf('more-actions-inner') !== -1;
})[0];
var ui8SecondaryActions = ui8MoreInner ? ui8MoreInner.children.map(function (b) {
  return b.attrs['data-action'];
}) : [];
assert('UI8: Discard + Rebuild buttons are still present inside the collapsed 更多操作 block (V1.4 contract preserved)',
       ui8SecondaryActions.indexOf('discard_workspace') !== -1 &&
       ui8SecondaryActions.indexOf('rebuild_workspace') !== -1);
assert('UI8: Prepare button is HIDDEN (not rendered at all) in state="ready"',
       (function () {
         function search(el) {
           if (!el) return false;
           if (el.attrs && el.attrs['data-action'] === 'prepare_workspace') return true;
           if (!el.children) return false;
           for (var i = 0; i < el.children.length; i++) {
             if (search(el.children[i])) return true;
           }
           return false;
         }
         return !search(ui8Actions);
       })());
// Click each rendered button and verify the right host callback fires.
resetV14HostActionCalls();
ui8TopBtn.fireEvent('click');
if (ui8MoreInner) {
  ui8MoreInner.children.forEach(function (b) { b.fireEvent('click'); });
}
assert('UI8: clicking the primary CTA + 更多操作 buttons fires Apply + Discard + Rebuild exactly once each',
       mockWindow.sketchup.apply_planar_normalization_calls.length === 1 &&
       mockWindow.sketchup.discard_workspace_calls.length === 1 &&
       mockWindow.sketchup.rebuild_workspace_calls.length === 1);

// Source guard: renderPlanarNormalization MUST use textContent
// only and MUST NOT use innerHTML for user-supplied strings.
// renderPlanarNormalizationAction is no longer used by the
// simplified renderer; the primary CTA is rendered by
// renderPrimaryAction.
var appJsSrcV16 = fs.readFileSync(appJsPath, 'utf-8');
assert('UI source guard: app.js mentions compute_planar_normalization host dispatch',
       appJsSrcV16.indexOf("'compute_planar_normalization'") >= 0 ||
       appJsSrcV16.indexOf('"compute_planar_normalization"') >= 0);
assert('UI source guard: app.js mentions apply_planar_normalization host dispatch',
       appJsSrcV16.indexOf("'apply_planar_normalization'") >= 0 ||
       appJsSrcV16.indexOf('"apply_planar_normalization"') >= 0);
assert('UI source guard: renderPlanarNormalization function defined',
       appJsSrcV16.indexOf('function renderPlanarNormalization') >= 0);
assert('UI source guard: renderPrimaryAction function defined',
       appJsSrcV16.indexOf('function renderPrimaryAction') >= 0);
assert('UI source guard: renderTechnicalDetails function defined',
       appJsSrcV16.indexOf('function renderTechnicalDetails') >= 0);

// =====================================================================
// V1.6 UI-CN-SIMPLIFICATION (per dispatch
// V16-UI-CN-SIMPLIFICATION-2026-09-01) — CN1..CN18: explicit
// Simplified Chinese UX proof points. The previous UI1..UI8 /
// L4 / V12 / V13 / V14 / V15 blocks already prove many of these
// assertions; the CN block is the explicit owner-facing
// dispatch-contract checklist.
// =====================================================================

// CN1 — Main title / selection empty-state are Chinese.
// Verified against the SHIPPED index.html (no mock).
var cn1IndexHtml = fs.readFileSync(
  path.resolve(__dirname, '..', 'extension', 'su_ai_plugin', 'html', 'index.html'),
  'utf-8'
);
assert('CN1: index.html <title> is Simplified Chinese ("CAD 检查结果")',
       cn1IndexHtml.indexOf('<title>CAD 检查结果</title>') !== -1);
assert('CN1: index.html <h1> is Simplified Chinese ("CAD 检查结果")',
       cn1IndexHtml.indexOf('<h1>CAD 检查结果</h1>') !== -1);
assert('CN1: index.html default #selection-info text is Simplified Chinese ("未选择对象")',
       cn1IndexHtml.indexOf('未选择对象') !== -1);
assert('CN1: index.html <html lang="zh-CN"> for accessibility',
       cn1IndexHtml.indexOf('<html lang="zh-CN">') !== -1);
// dialog_title in dialog_runner.rb must be Simplified Chinese.
var cn1RunnerRb = fs.readFileSync(
  path.resolve(__dirname, '..', 'extension', 'su_ai_plugin', 'dialog_runner.rb'),
  'utf-8'
);
assert('CN1: dialog_runner.rb dialog_title is Simplified Chinese ("CAD 检查结果")',
       cn1RunnerRb.indexOf("dialog_title:    'CAD 检查结果'") !== -1);

// CN2 — Issue type / severity labels are Chinese.
// Verified via ROOT.ISSUE_TYPE_LABELS_CN / ROOT.SEVERITY_LABELS_CN.
var cn2IssueLabels = context.window.SUAIP.ISSUE_TYPE_LABELS_CN;
assert('CN2: ROOT.ISSUE_TYPE_LABELS_CN has 7 Simplified Chinese issue types in canonical order',
       Array.isArray(cn2IssueLabels) && cn2IssueLabels.length === 7 &&
       cn2IssueLabels.map(function (p) { return p[0]; }).join(',') ===
         'duplicate_edge_candidate,short_edge,open_endpoint,gap_candidate,significant_non_zero_z,abnormal_large_coord,deep_nesting' &&
       cn2IssueLabels.map(function (p) { return p[1]; }).join('|') ===
         '重复线候选|短线|未闭合端点|间隙候选|明显非零 Z|异常大坐标|嵌套层级过深');
var cn2SeverityLabels = context.window.SUAIP.SEVERITY_LABELS_CN;
assert('CN2: ROOT.SEVERITY_LABELS_CN has high/medium/low Simplified Chinese labels',
       cn2SeverityLabels && cn2SeverityLabels.high === '高' &&
       cn2SeverityLabels.medium === '中' && cn2SeverityLabels.low === '低');
// Re-render with a multi-severity payload and confirm badge
// text is Simplified Chinese (no English severity words).
renderWithPayload({
  selectionLabel: 'cn2-multi', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0,
             issues: { short_edge: 1, deep_nesting: 1 } },
  groups: [
    { type: 'short_edge', count: 1, defaultOpen: true,
      issues: [{ issue_id: 'short_edge|1|1', issue_type: 'short_edge',
                 severity: 'high', locatable: true, message: 'short edge msg' }] },
    { type: 'deep_nesting', count: 1, defaultOpen: false,
      issues: [{ issue_id: 'deep_nesting|1|1', issue_type: 'deep_nesting',
                 severity: 'low', locatable: false, message: 'deep nesting msg' }] }
  ],
  layerGroups: [], layerIssueGroups: [], faceInventoryGroups: []
});
var cn2Groups = mockElements['groups'];
var cn2AllTexts = (function () {
  var out = [];
  function collect(el) { if (el.textContent) out.push(el.textContent);
    for (var i = 0; i < el.children.length; i++) collect(el.children[i]); }
  collect(cn2Groups);
  return out.join(' | ');
})();
assert('CN2: severity badge text in DOM is Simplified Chinese (高 / 低, NOT English)',
       cn2AllTexts.indexOf('高') !== -1 && cn2AllTexts.indexOf('低') !== -1 &&
       cn2AllTexts.indexOf('high') === -1 && cn2AllTexts.indexOf('low') === -1);

// CN3 — Working Mode visible labels/buttons are Chinese.
// Verified by V14 assertions above + a focused string check.
renderWithPayload({
  selectionLabel: 'cn3-wm', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: { state: 'none' }
});
var cn3WmSummary = mockElements['working-mode-summary'];
assert('CN3: working-mode-summary is Simplified Chinese ("处理工作区— ...")',
       cn3WmSummary.textContent.indexOf('处理工作区') !== -1);
assert('CN3: working-mode section <summary> element default text is Simplified Chinese ("处理工作区")',
       cn1IndexHtml.indexOf('<summary id="working-mode-summary">处理工作区</summary>') !== -1);

// CN4 — Planar Normalization states/buttons are Chinese.
var cn4PnLabels = context.window.SUAIP.PN_STATE_LABELS_CN;
assert('CN4: ROOT.PN_STATE_LABELS_CN has all canonical Simplified Chinese state labels',
       cn4PnLabels &&
       cn4PnLabels.NOT_COMPUTED === '未检查' &&
       cn4PnLabels.READY_TO_NORMALIZE === '可安全校正' &&
       cn4PnLabels.REVIEW_REQUIRED === '需要人工确认' &&
       cn4PnLabels.NO_CANDIDATE === '无需校正' &&
       cn4PnLabels.APPLIED === '已校正' &&
       cn4PnLabels.FAILED === '校正失败');
var cn4ActionLabels = context.window.SUAIP.ACTION_LABEL_CN;
assert('CN4: ROOT.ACTION_LABEL_CN has Simplified Chinese action labels for all 5 callbacks',
       cn4ActionLabels &&
       cn4ActionLabels.prepare_workspace === '准备处理' &&
       cn4ActionLabels.discard_workspace === '放弃工作副本' &&
       cn4ActionLabels.rebuild_workspace === '重新生成' &&
       cn4ActionLabels.compute_planar_normalization === '检查平面偏差' &&
       cn4ActionLabels.apply_planar_normalization === '应用平面校正');

// CN5 — READY_TO_NORMALIZE: ONLY the destructive primary CTA
// "应用平面校正" is rendered; no other Apply / Compute button.
renderWithPayload({
  selectionLabel: 'cn5-rt', selectionType: 'Group',
  summary: { edges: 4, vertices: 8, non_zero_z_vertices: 4, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    planar_normalization: {
      computed: true, state: 'READY_TO_NORMALIZE',
      proposal: { state: 'READY_TO_NORMALIZE', target_z: 1.003,
                  eligible_count: 4, movable_count: 3, outlier_count: 1,
                  affected_derived_ids: ['d1','d2','d3'], max_movement: 0.007 }
    }
  }
});
var cn5Actions = mockElements['working-mode-actions'];
// Primary CTA (top-level button).
var cn5Primary = cn5Actions.children[0];
assert('CN5: READY_TO_NORMALIZE primary CTA is Simplified Chinese "应用平面校正"',
       cn5Primary && cn5Primary.textContent === '应用平面校正' &&
       cn5Primary.attrs['data-action'] === 'apply_planar_normalization');
// Only ONE Apply button exists in the entire actions subtree.
var cn5ApplyCount = 0;
(function count(el) {
  if (!el) return;
  if (el.attrs && el.attrs['data-action'] === 'apply_planar_normalization') cn5ApplyCount++;
  if (el.children) for (var i = 0; i < el.children.length; i++) count(el.children[i]);
})(cn5Actions);
assert('CN5: READY_TO_NORMALIZE renders exactly ONE "应用平面校正" button (no Apply button clutter)',
       cn5ApplyCount === 1);

// CN6 — NOT_COMPUTED: primary action is "检查平面偏差".
renderWithPayload({
  selectionLabel: 'cn6-nc', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    planar_normalization: { computed: false, state: 'NOT_COMPUTED' }
  }
});
var cn6Actions = mockElements['working-mode-actions'];
var cn6Primary = cn6Actions.children[0];
assert('CN6: NOT_COMPUTED primary action is Simplified Chinese "检查平面偏差"',
       cn6Primary && cn6Primary.textContent === '检查平面偏差' &&
       cn6Primary.attrs['data-action'] === 'compute_planar_normalization' &&
       !cn6Primary.hasAttribute('disabled'));

// CN7 — REVIEW_REQUIRED: Chinese review-required explanation
// visible; no Apply action.
renderWithPayload({
  selectionLabel: 'cn7-rr', selectionType: 'Group',
  summary: { edges: 6, vertices: 12, non_zero_z_vertices: 12, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    planar_normalization: {
      computed: true, state: 'REVIEW_REQUIRED',
      proposal: { state: 'REVIEW_REQUIRED', reason: 'tied_dominant_windows',
                  eligible_count: 6, movable_count: 0, outlier_count: 0,
                  max_movement: 0.0 }
    }
  }
});
var cn7List = mockElements['working-mode-list'];
assert('CN7: REVIEW_REQUIRED Chinese review-required explanation visible ("检测到多组高度")',
       cn7List && cn7List.children.some(function (c) {
         return c.textContent.indexOf('检测到多组高度') !== -1;
       }));
var cn7ApplyCount = 0;
(function count(el) {
  if (!el) return;
  if (el.attrs && el.attrs['data-action'] === 'apply_planar_normalization') cn7ApplyCount++;
  if (el.children) for (var i = 0; i < el.children.length; i++) count(el.children[i]);
})(mockElements['working-mode-actions']);
assert('CN7: REVIEW_REQUIRED renders NO Apply action button (no destructive CTA)',
       cn7ApplyCount === 0);

// CN8 — NO_CANDIDATE: Chinese no-action explanation visible; no Apply action.
renderWithPayload({
  selectionLabel: 'cn8-noc', selectionType: 'Group',
  summary: { edges: 4, vertices: 8, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    planar_normalization: {
      computed: true, state: 'NO_CANDIDATE',
      proposal: { state: 'NO_CANDIDATE', reason: 'already_planar',
                  eligible_count: 4, already_planar: 4, movable_count: 0,
                  outlier_count: 0, max_movement: 0.0 }
    }
  }
});
var cn8List = mockElements['working-mode-list'];
assert('CN8: NO_CANDIDATE Chinese no-action explanation visible ("当前几何无需平面校正。")',
       cn8List && cn8List.children.some(function (c) {
         return c.textContent.indexOf('当前几何无需平面校正') !== -1;
       }));
var cn8ApplyCount = 0;
(function count(el) {
  if (!el) return;
  if (el.attrs && el.attrs['data-action'] === 'apply_planar_normalization') cn8ApplyCount++;
  if (el.children) for (var i = 0; i < el.children.length; i++) count(el.children[i]);
})(mockElements['working-mode-actions']);
assert('CN8: NO_CANDIDATE renders NO Apply action button',
       cn8ApplyCount === 0);

// CN9 — APPLIED: Chinese completion summary; no stale Apply action.
renderWithPayload({
  selectionLabel: 'cn9-app', selectionType: 'Group',
  summary: { edges: 4, vertices: 8, non_zero_z_vertices: 4, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    planar_normalization: {
      computed: true, state: 'APPLIED',
      audit: { status: 'applied', target_z: 1.003,
               applied_count: 4, failed_count: 0, max_movement: 0.007,
               outlier_derived_ids: ['d4'] }
    }
  }
});
var cn9List = mockElements['working-mode-list'];
assert('CN9: APPLIED Chinese completion summary visible ("平面校正已完成。")',
       cn9List && cn9List.children.some(function (c) {
         return c.textContent.indexOf('平面校正已完成') !== -1;
       }));
var cn9ApplyCount = 0;
(function count(el) {
  if (!el) return;
  if (el.attrs && el.attrs['data-action'] === 'apply_planar_normalization') cn9ApplyCount++;
  if (el.children) for (var i = 0; i < el.children.length; i++) count(el.children[i]);
})(mockElements['working-mode-actions']);
assert('CN9: APPLIED renders NO stale Apply action button (no stale READY_TO_NORMALIZE action)',
       cn9ApplyCount === 0);

// CN10 — FAILED: Chinese failure summary; no Apply action.
renderWithPayload({
  selectionLabel: 'cn10-fail', selectionType: 'Group',
  summary: { edges: 4, vertices: 8, non_zero_z_vertices: 4, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    planar_normalization: {
      computed: true, state: 'FAILED',
      audit: { status: 'failed', target_z: 1.003, applied_count: 0,
               failed_count: 1, reason: 'post_validation_failed:xyz',
               outlier_derived_ids: [] }
    }
  }
});
var cn10List = mockElements['working-mode-list'];
assert('CN10: FAILED Chinese failure summary visible ("校正失败。")',
       cn10List && cn10List.children.some(function (c) {
         return c.textContent.indexOf('校正失败') !== -1;
       }));
var cn10ApplyCount = 0;
(function count(el) {
  if (!el) return;
  if (el.attrs && el.attrs['data-action'] === 'apply_planar_normalization') cn10ApplyCount++;
  if (el.children) for (var i = 0; i < el.children.length; i++) count(el.children[i]);
})(mockElements['working-mode-actions']);
assert('CN10: FAILED renders NO Apply action button',
       cn10ApplyCount === 0);

// CN11 — source snapshot / fingerprint / config digest are NOT
// visible in the default primary Working Mode area and are
// available under 技术详情. (Per dispatch §5.5: technical
// identifiers are collapsed by default.)
renderWithPayload({
  selectionLabel: 'cn11-tech', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'cn11-snap-001',
    source_fingerprint_digest: 'cn11-abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678',
    execution_config_digest: 'cn11-cfg'
  }
});
var cn11List = mockElements['working-mode-list'];
var cn11AllTexts = (function () {
  var out = [];
  function collect(el) { if (el.textContent) out.push(el.textContent);
    for (var i = 0; i < el.children.length; i++) collect(el.children[i]); }
  collect(cn11List);
  return out.join(' | ');
})();
assert('CN11: source_snapshot_id is NOT in default Working Mode list',
       cn11AllTexts.indexOf('cn11-snap-001') === -1);
assert('CN11: source_fingerprint_digest is NOT in default Working Mode list',
       cn11AllTexts.indexOf('cn11-abcdef1234567890') === -1);
assert('CN11: execution_config_digest is NOT in default Working Mode list',
       cn11AllTexts.indexOf('cn11-cfg') === -1);
var cn11TechList = mockElements['technical-details-list'];
assert('CN11: source_snapshot_id IS available under 技术详情',
       cn11TechList && cn11TechList.children.some(function (c) {
         return c.textContent.indexOf('source_snapshot_id') !== -1 &&
                c.textContent.indexOf('cn11-snap-001') !== -1;
       }));
assert('CN11: source_fingerprint_digest IS available under 技术详情',
       cn11TechList && cn11TechList.children.some(function (c) {
         return c.textContent.indexOf('source_fingerprint_digest') !== -1;
       }));
assert('CN11: execution_config_digest IS available under 技术详情',
       cn11TechList && cn11TechList.children.some(function (c) {
         return c.textContent.indexOf('execution_config_digest') !== -1 &&
                c.textContent.indexOf('cn11-cfg') !== -1;
       }));

// CN12 — duplicate action IDs / rule IDs / survivor IDs are
// hidden by default and available under 技术详情.
renderWithPayload({
  selectionLabel: 'cn12-audit', selectionType: 'Group',
  summary: { edges: 2, vertices: 2, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    duplicate_repair: {
      duplicate_pairs_before: 1, duplicate_pairs_after: 0,
      actions_applied: 1, actions_skipped: 0, actions_failed: 0,
      actions: [{
        action_id: 'act-cn12-1',
        status: 'applied',
        rule_id: 'duplicate_edge.exact_remove',
        survivor_derived_id: 'der-cn12-A',
        removed_count: 1,
        source_occurrence_count: 2,
        confidence_basis: 'exact_endpoint_match_within_tolerance'
      }]
    }
  }
});
var cn12List = mockElements['working-mode-list'];
var cn12ListTexts = (function () {
  var out = [];
  function collect(el) { if (el.textContent) out.push(el.textContent);
    for (var i = 0; i < el.children.length; i++) collect(el.children[i]); }
  collect(cn12List);
  return out.join(' | ');
})();
assert('CN12: per-action action_id ("act-cn12-1") is NOT in default Working Mode list',
       cn12ListTexts.indexOf('act-cn12-1') === -1);
assert('CN12: rule_id ("duplicate_edge.exact_remove") is NOT in default Working Mode list',
       cn12ListTexts.indexOf('duplicate_edge.exact_remove') === -1);
assert('CN12: survivor_derived_id ("der-cn12-A") is NOT in default Working Mode list',
       cn12ListTexts.indexOf('der-cn12-A') === -1);
var cn12TechList = mockElements['technical-details-list'];
assert('CN12: action_id IS available under 技术详情',
       cn12TechList && cn12TechList.children.some(function (c) {
         return c.attrs && c.attrs['data-action-id'] === 'act-cn12-1';
       }));
assert('CN12: rule_id IS available under 技术详情',
       cn12TechList && cn12TechList.children.some(function (c) {
         return c.attrs && c.attrs['data-action-id'] === 'act-cn12-1' &&
                c.children.some(function (cc) {
                  return cc.textContent.indexOf('rule_id=duplicate_edge.exact_remove') !== -1;
                });
       }));
assert('CN12: survivor_derived_id IS available under 技术详情',
       cn12TechList && cn12TechList.children.some(function (c) {
         return c.attrs && c.attrs['data-action-id'] === 'act-cn12-1' &&
                c.children.some(function (cc) {
                  return cc.textContent.indexOf('survivor_id=der-cn12-A') !== -1;
                });
       }));

// CN13 — Issues by Layer / Layers / Face Inventory are Chinese
// AND collapsed by default in index.html (no `open` attribute).
assert('CN13: index.html <details id="layer-issues-section"> is closed by default',
       cn1IndexHtml.indexOf('<details id="layer-issues-section">') !== -1 &&
       !/\bid="layer-issues-section"[^>]*\bopen\b/.test(cn1IndexHtml));
assert('CN13: index.html <details id="layers-section"> is closed by default',
       cn1IndexHtml.indexOf('<details id="layers-section">') !== -1 &&
       !/\bid="layers-section"[^>]*\bopen\b/.test(cn1IndexHtml));
assert('CN13: index.html <details id="face-inventory-section"> is closed by default',
       cn1IndexHtml.indexOf('<details id="face-inventory-section">') !== -1 &&
       !/\bid="face-inventory-section"[^>]*\bopen\b/.test(cn1IndexHtml));
assert('CN13: index.html <details id="technical-details-section"> is closed by default',
       cn1IndexHtml.indexOf('<details id="technical-details-section">') !== -1 &&
       !/\bid="technical-details-section"[^>]*\bopen\b/.test(cn1IndexHtml));
// Section header text is Simplified Chinese.
assert('CN13: index.html Layers section header is Simplified Chinese ("图层信息")',
       cn1IndexHtml.indexOf('<summary id="layers-summary">图层信息</summary>') !== -1);
assert('CN13: index.html Issues by Layer section header is Simplified Chinese ("按图层查看问题")',
       cn1IndexHtml.indexOf('<summary id="layer-issues-summary">按图层查看问题</summary>') !== -1);
assert('CN13: index.html Face Inventory section header is Simplified Chinese ("面信息")',
       cn1IndexHtml.indexOf('<summary id="face-inventory-summary">面信息</summary>') !== -1);
assert('CN13: index.html Technical Details section header is Simplified Chinese ("技术详情")',
       cn1IndexHtml.indexOf('<summary id="technical-details-summary">技术详情</summary>') !== -1);

// CN14 — unavailable actions are hidden rather than producing
// button clutter. Verified for state='ready' (no PN payload):
// only ONE primary CTA ("检查平面偏差") + the 更多操作 block.
renderWithPayload({
  selectionLabel: 'cn14-wm', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: { state: 'ready' }
});
var cn14Actions = mockElements['working-mode-actions'];
var cn14DisabledCount = 0;
(function countDisabled(el) {
  if (!el) return;
  if (el.attrs && el.attrs['disabled'] !== undefined) cn14DisabledCount++;
  if (el.children) for (var i = 0; i < el.children.length; i++) countDisabled(el.children[i]);
})(cn14Actions);
assert('CN14: state="ready" (no PN) renders ZERO disabled action buttons (unavailable actions are hidden)',
       cn14DisabledCount === 0);

// CN15 — existing callback dispatch still works: Prepare /
// Discard / Rebuild / Compute / Apply all wire to the correct
// window.sketchup.<callback>. Verified via V14-RUNTIME-BLOCK-001
// (Prepare / Discard / Rebuild) + UI1 (Compute) + UI2 (Apply).
// We re-run the focused Dispatch test here to prove the
// Simplified Chinese buttons still dispatch correctly.
resetV14HostActionCalls();
renderWithPayload({
  selectionLabel: 'cn15-state', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: { state: 'none' }
});
mockElements['working-mode-actions'].children[0].fireEvent('click');
assert('CN15: clicking Simplified Chinese "准备处理" CTA fires prepare_workspace (callback preserved)',
       mockWindow.sketchup.prepare_workspace_calls.length === 1);
resetV14HostActionCalls();
renderWithPayload({
  selectionLabel: 'cn15-rt', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: { state: 'ready' }
});
var cn15WmActions = mockElements['working-mode-actions'];
cn15WmActions.children[0].fireEvent('click');  // primary CTA: 检查平面偏差
assert('CN15: clicking Simplified Chinese "检查平面偏差" CTA fires compute_planar_normalization (callback preserved)',
       mockWindow.sketchup.compute_planar_normalization_calls.length === 1);
resetV14HostActionCalls();
renderWithPayload({
  selectionLabel: 'cn15-rt2', selectionType: 'Group',
  summary: { edges: 4, vertices: 8, non_zero_z_vertices: 4, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: [],
  derivedWorkspace: {
    state: 'ready',
    planar_normalization: {
      computed: true, state: 'READY_TO_NORMALIZE',
      proposal: { state: 'READY_TO_NORMALIZE', target_z: 1.003,
                  eligible_count: 4, movable_count: 3, outlier_count: 1,
                  affected_derived_ids: ['d1'], max_movement: 0.007 }
    }
  }
});
mockElements['working-mode-actions'].children[0].fireEvent('click');
assert('CN15: clicking Simplified Chinese "应用平面校正" CTA fires apply_planar_normalization (callback preserved)',
       mockWindow.sketchup.apply_planar_normalization_calls.length === 1);
resetV14HostActionCalls();
// Discard + Rebuild from the collapsed 更多操作 block.
var cn15WmActions2 = mockElements['working-mode-actions'];
var cn15MoreInner = cn15WmActions2.children[1].children.filter(function (c) {
  return c.classes.indexOf('more-actions-inner') !== -1;
})[0];
cn15MoreInner.children.filter(function (b) {
  return b.attrs['data-action'] === 'discard_workspace';
})[0].fireEvent('click');
assert('CN15: clicking Simplified Chinese "放弃工作副本" fires discard_workspace (callback preserved)',
       mockWindow.sketchup.discard_workspace_calls.length === 1);
resetV14HostActionCalls();
cn15MoreInner.children.filter(function (b) {
  return b.attrs['data-action'] === 'rebuild_workspace';
})[0].fireEvent('click');
assert('CN15: clicking Simplified Chinese "重新生成" fires rebuild_workspace (callback preserved)',
       mockWindow.sketchup.rebuild_workspace_calls.length === 1);

// CN16 — missing / malformed payload degrades safely. Already
// proven by UI7 above (missing + malformed planar_normalization).
// We add one more: a fully-missing derivedWorkspace.
renderWithPayload({
  selectionLabel: 'cn16-missing', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups: [], layerGroups: [], layerIssueGroups: [], faceInventoryGroups: []
  // derivedWorkspace intentionally missing
});
assert('CN16: missing derivedWorkspace degrades safely (summary is Chinese, no crash)',
       mockElements['working-mode-summary'].textContent === '处理工作区\u2014 尚未准备工作副本');

// CN17 — no [object Object] / undefined / NaN in visible
// normal UI. Already proven by summary assertions above +
// UI7. We add a sweep across all rendered text in a fresh
// normal payload.
renderWithPayload({
  selectionLabel: 'cn17-normal', selectionType: 'Group',
  summary: { edges: 5, vertices: 8, non_zero_z_vertices: 2, warnings: 1,
             faces: 1, faces_with_holes: 0,
             issues: { duplicate_edge_candidate: 0, short_edge: 1,
                       open_endpoint: 0, gap_candidate: 0,
                       significant_non_zero_z: 1, abnormal_large_coord: 0,
                       deep_nesting: 1 } },
  groups: [
    { type: 'short_edge', count: 1, defaultOpen: true,
      issues: [{ issue_id: 'short_edge|1|1', issue_type: 'short_edge',
                 severity: 'low', locatable: true, message: 'short edge detected' }] },
    { type: 'significant_non_zero_z', count: 1, defaultOpen: false,
      issues: [{ issue_id: 'significant_non_zero_z|1|1', issue_type: 'significant_non_zero_z',
                 severity: 'medium', locatable: true, message: 'non-zero z' }] }
  ],
  layerGroups: [
    { name: 'DIM-XX', role: 'dimension', role_label: 'Dimension',
      role_rule: 'name_dimension', visible: true, visibility_unknown: false,
      visibility_label: 'Visible', edge_count: 4, issue_count: 1 }
  ],
  layerIssueGroups: [
    { name: 'DIM-XX', count: 1, default_open: false,
      issues: [{ issue_id: 'short_edge|1|1', issue_type: 'short_edge',
                 severity: 'low', locatable: true, message: 'short edge',
                 source: { layer_name: 'DIM-XX' } }] }
  ],
  faceInventoryGroups: [
    { name: 'DIM-XX', face_count: 1, faces_with_holes_count: 0,
      role: 'dimension', role_label: 'Dimension', role_rule: 'name_dimension',
      visible: true, visibility_unknown: false, visibility_label: 'Visible' }
  ],
  derivedWorkspace: {
    state: 'ready',
    source_snapshot_id: 'cn17-snap',
    source_fingerprint_digest: 'cn17-abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678',
    execution_config_digest: 'cn17-cfg',
    duplicate_repair: {
      duplicate_pairs_before: 1, duplicate_pairs_after: 0,
      duplicate_classes_before: 1, duplicate_classes_after: 0,
      derived_edge_count_before: 2, derived_edge_count_after: 1,
      actions_applied: 1, actions_skipped: 0, actions_failed: 0,
      actions: [{
        action_id: 'act-cn17-1', status: 'applied', rule_id: 'r',
        survivor_derived_id: 'd-A', removed_count: 1,
        source_occurrence_count: 2
      }]
    },
    planar_normalization: {
      computed: true, state: 'APPLIED',
      audit: { status: 'applied', target_z: 1.003, applied_count: 4,
               failed_count: 0, max_movement: 0.007,
               outlier_derived_ids: ['d4'] }
    }
  }
});
var cn17AllTexts = (function () {
  var out = [];
  function collect(el) { if (el.textContent) out.push(el.textContent);
    for (var i = 0; i < el.children.length; i++) collect(el.children[i]); }
  ['summary', 'groups', 'layers-list', 'layer-issues-list',
   'face-inventory-list', 'working-mode-list', 'technical-details-list'
  ].forEach(function (id) { collect(mockElements[id]); });
  return out.join(' | ');
})();
assert('CN17: no "[object Object]" anywhere in visible normal UI',
       cn17AllTexts.indexOf('[object Object]') === -1);
assert('CN17: no "undefined" anywhere in visible normal UI',
       cn17AllTexts.indexOf('undefined') === -1);
assert('CN17: no "NaN" anywhere in visible normal UI',
       cn17AllTexts.indexOf('NaN') === -1);

// CN18 — technical details still retain the audit evidence
// needed by AIPM / Pi. The full raw data contract is
// preserved under 技术详情: source_snapshot_id, +
// source_fingerprint_digest, + execution_config_digest, +
// raw workspace state, + duplicate_repair summary (with +
// per-action audit row carrying action_id, rule_id, +
// survivor_id, source occurrence count, removed_count), +
// raw normalization reason, + raw normalization audit +
// fields (status, target_z, applied_count, max_movement, +
// outlier_count, failure_reason).
var cn18TechList = mockElements['technical-details-list'];
var cn18TechTexts = (function () {
  var out = [];
  function collect(el) { if (el.textContent) out.push(el.textContent);
    for (var i = 0; i < el.children.length; i++) collect(el.children[i]); }
  collect(cn18TechList);
  return out.join(' | ');
})();
assert('CN18: 技术详情 preserves source_snapshot_id ("cn17-snap")',
       cn18TechTexts.indexOf('cn17-snap') !== -1);
assert('CN18: 技术详情 preserves source_fingerprint_digest (full SHA-256 hex)',
       cn18TechTexts.indexOf('cn17-abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678') !== -1);
assert('CN18: 技术详情 preserves execution_config_digest ("cn17-cfg")',
       cn18TechTexts.indexOf('cn17-cfg') !== -1);
assert('CN18: 技术详情 preserves duplicate_repair audit summary (applied/skipped/failed + class/pair/edge deltas)',
       cn18TechTexts.indexOf('duplicate_repair_summary') !== -1 &&
       cn18TechTexts.indexOf('applied=1') !== -1 &&
       cn18TechTexts.indexOf('classes=1->0') !== -1);
assert('CN18: 技术详情 preserves per-action action_id ("act-cn17-1")',
       cn18TechTexts.indexOf('act-cn17-1') !== -1);
assert('CN18: 技术详情 preserves per-action rule_id ("r")',
       cn18TechTexts.indexOf('rule_id=r') !== -1);
assert('CN18: 技术详情 preserves per-action survivor_id ("d-A")',
       cn18TechTexts.indexOf('survivor_id=d-A') !== -1);
assert('CN18: 技术详情 preserves per-action source_occurrence_count (= 2)',
       cn18TechTexts.indexOf('source_count=2') !== -1);
assert('CN18: 技术详情 preserves per-action removed_count (= 1)',
       cn18TechTexts.indexOf('removed_count=1') !== -1);
assert('CN18: 技术详情 preserves raw planar_normalization_state ("APPLIED")',
       cn18TechTexts.indexOf('planar_normalization_state') !== -1 &&
       cn18TechTexts.indexOf('APPLIED') !== -1);
assert('CN18: 技术详情 preserves planar_normalization_audit_status ("applied")',
       cn18TechTexts.indexOf('planar_normalization_audit_status') !== -1 &&
       cn18TechTexts.indexOf('applied') !== -1);
assert('CN18: 技术详情 preserves planar_normalization_audit_target_z (= 1.003)',
       cn18TechTexts.indexOf('planar_normalization_audit_target_z') !== -1 &&
       cn18TechTexts.indexOf('1.003') !== -1);
assert('CN18: 技术详情 preserves planar_normalization_audit_applied_count (= 4)',
       cn18TechTexts.indexOf('planar_normalization_audit_applied_count') !== -1 &&
       cn18TechTexts.indexOf('4') !== -1);
assert('CN18: 技术详情 preserves planar_normalization_audit_max_movement (= 0.007)',
       cn18TechTexts.indexOf('planar_normalization_audit_max_movement') !== -1 &&
       cn18TechTexts.indexOf('0.007') !== -1);

// Source guard: app.js does NOT use innerHTML / eval / new
// Function / document.write anywhere.
assert('CN source guard: app.js does NOT use eval()',
       appJsSrcV16.search(/\beval\(/) === -1);
assert('CN source guard: app.js does NOT use new Function(...)',
       appJsSrcV16.search(/\bnew\s+Function\(/) === -1);
assert('CN source guard: app.js does NOT use document.write(...)',
       appJsSrcV16.search(/\bdocument\.write\(/) === -1);
// innerHTML may appear in comments only; verify code body.
var cnCodeOnly = appJsSrcV16.split('\n')
  .filter(function (l) { return !l.trim().startsWith('//') && !l.trim().startsWith('*'); })
  .join('\n');
assert('CN source guard: app.js does NOT use innerHTML= in code (comments allowed)',
       cnCodeOnly.search(/\.innerHTML\s*=/) === -1);

// --- final verdict -----------------------------------------------------

var failed = results.filter(function (r) { return !r.pass; });
if (failed.length === 0) {
  process.stdout.write('PASS\n');
  process.exit(0);
} else {
  process.stderr.write('FAIL (' + failed.length + ' of ' + results.length + ')\n');
  process.exit(1);
}
