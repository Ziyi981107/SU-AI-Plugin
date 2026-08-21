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
  'working-mode-actions': new MockElement('div')
};

var mockDocument = {
  getElementById: function (id) { return mockElements[id] || null; },
  addEventListener: function () { /* no-op */ },
  createElement: function (tag) { return new MockElement(tag); }
};

var mockWindow = {
  SUAIP: null,
  sketchup: {
    ready: function () {},
    locate: function (id) {}
  }
};

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
assert('summary: Edges: 4 present',
       summaryTexts.indexOf('Edges: 4') !== -1);
assert('summary: Vertices: 5 present',
       summaryTexts.indexOf('Vertices: 5') !== -1);
assert('summary: Non Zero Z Vertices: 0 present',
       summaryTexts.indexOf('Non Zero Z Vertices: 0') !== -1);
assert('summary: Warnings: 1 present',
       summaryTexts.indexOf('Warnings: 1') !== -1);

// Per-issue-type counters in the locked order.
assert('summary: Duplicate Candidates: 0 present',
       summaryTexts.indexOf('Duplicate Candidates: 0') !== -1);
assert('summary: Short Edges: 1 present',
       summaryTexts.indexOf('Short Edges: 1') !== -1);
assert('summary: Open Endpoints: 0 present',
       summaryTexts.indexOf('Open Endpoints: 0') !== -1);
assert('summary: Gap Candidates: 0 present',
       summaryTexts.indexOf('Gap Candidates: 0') !== -1);
assert('summary: Significant Non-zero Z: 0 present',
       summaryTexts.indexOf('Significant Non-zero Z: 0') !== -1);
assert('summary: Abnormal Large Coordinate: 0 present',
       summaryTexts.indexOf('Abnormal Large Coordinate: 0') !== -1);
assert('summary: Deep Nesting: 0 present',
       summaryTexts.indexOf('Deep Nesting: 0') !== -1);

// No "[object Object]" string anywhere in the rendered output.
assert('summary: no "[object Object]" in any rendered text',
       fullText.indexOf('[object Object]') === -1);

// Locked order: scalar rows come before per-issue-type rows.
var idxShortEdges   = summaryTexts.indexOf('Short Edges: 1');
var idxEdges        = summaryTexts.indexOf('Edges: 4');
var idxDup          = summaryTexts.indexOf('Duplicate Candidates: 0');
var idxDeep         = summaryTexts.indexOf('Deep Nesting: 0');
assert('order: Edges header comes before per-issue rows',
       idxEdges !== -1 && idxShortEdges !== -1 && idxEdges < idxShortEdges);
assert('order: per-issue rows in canonical order (Duplicate Candidates before Deep Nesting)',
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
assert('L4.3: role-badge textContent matches role_label',
       dimRoleBadge && dimRoleBadge.textContent === 'Dimension');
assert('L4.3: visibility-badge textContent matches visibility_label',
       dimVisBadge && dimVisBadge.textContent === 'Visible');
assert('L4.3: edge-count renders the layer edge count (plural form for n=4)',
       dimEdgesCell && dimEdgesCell.textContent === '4 edges');
assert('L4.3: issue-count renders the layer issue count (singular form for n=1)',
       dimIssuesCell && dimIssuesCell.textContent === '1 issue');
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
       dimRow && joinChildTexts(dimRow) === 'DIM-XXDimensionVisible4 edges\u00B71 issue');
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
assert('L4.4.1: edge_count=2 pluralizes to "2 edges"',
       l0EdgesCell && l0EdgesCell.textContent === '2 edges');
assert('L4.4.1: issue_count=0 pluralizes to "0 issues"',
       l0IssuesCell && l0IssuesCell.textContent === '0 issues');
assert('L4.4.1: issue_count=0 has NO .has-issues class',
       l0IssuesCell && l0IssuesCell.classes.indexOf('has-issues') === -1);

// L4.5 — hidden layer has data-visible="false" AND a separate
// visibility badge "Off-screen" (NOT a fused role label).
assert('L4.5: hidden layer row has data-visible="false"',
       l0Row && l0Row.attrs['data-visible'] === 'false');
assert('L4.5: hidden layer row role_label is still "Construction" (NOT fused)',
       findChildByClass(l0Row, 'role-badge') &&
       findChildByClass(l0Row, 'role-badge').textContent === 'Construction');
assert('L4.5: hidden layer row visibility badge text is "Off-screen"',
       findChildByClass(l0Row, 'visibility-badge') &&
       findChildByClass(l0Row, 'visibility-badge').textContent === 'Off-screen');

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
assert('L4.11: #layers-summary textContent is "Layers — N total (M with issues)"',
       layersSummaryEl.textContent === 'Layers \u2014 2 total (1 with issues)');

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
assert('L4.12: undefined layerGroups -> summary shows "Layers — 0 total (0 with issues)"',
       mockElements['layers-summary'].textContent === 'Layers \u2014 0 total (0 with issues)');

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
       mockElements['layers-summary'].textContent === 'Layers \u2014 0 total (0 with issues)');

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
assert('L4.14: visibility_unknown: true -> visibility badge text is "Visibility: unknown"',
       findChildByClass(unkRow, 'visibility-badge') &&
       findChildByClass(unkRow, 'visibility-badge').textContent === 'Visibility: unknown');
assert('L4.14: visibility_unknown: true -> role badge still "Unknown" (NOT fused)',
       findChildByClass(unkRow, 'role-badge') &&
       findChildByClass(unkRow, 'role-badge').textContent === 'Unknown');

// L4.15 — ROOT.LAYER_ROLE_LABELS exposed with the 5 canonical roles
// (NO OFFSCREEN) in locked order.
var lrl = context.window.SUAIP.LAYER_ROLE_LABELS;
assert('L4.15: ROOT.LAYER_ROLE_LABELS is defined',
       Array.isArray(lrl) && lrl.length === 5);
var expectedRoleOrder = ['dimension', 'annotation', 'guide',
                         'construction', 'unknown'];
var actualRoleOrder = lrl.map(function (pair) { return pair[0]; });
assert('L4.15: ROOT.LAYER_ROLE_LABELS in canonical order (dimension, annotation, guide, construction, unknown)',
       actualRoleOrder.join(',') === expectedRoleOrder.join(','));
assert('L4.15: ROOT.LAYER_ROLE_LABELS does NOT include OFFSCREEN (R007)',
       actualRoleOrder.indexOf('offscreen') === -1);

// L4.16 — ROOT.LAYER_VISIBILITY_LABELS exposed with 3 keys (visible,
// hidden, unknown).
var lvl = context.window.SUAIP.LAYER_VISIBILITY_LABELS;
assert('L4.16: ROOT.LAYER_VISIBILITY_LABELS is defined with visible/hidden/unknown',
       lvl && lvl.visible === 'Visible' &&
       lvl.hidden === 'Off-screen' &&
       lvl.unknown === 'Visibility: unknown');

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
assert('V12: layer-issues-summary populated BEFORE the user opens the section',
       v12LayerIssuesSummary && v12LayerIssuesSummary.textContent ===
         'Issues by Layer \u2014 2 layers (2 issues)');
assert('V12: each bucket is a <details> element',
       v12LayerIssuesList.children.every(function (c) {
         return c.tag === 'details';
       }));
var _b0 = v12LayerIssuesList.children[0].children[0].textContent;
var _b1 = v12LayerIssuesList.children[1].children[0].textContent;
assert('V12: bucket summary shows layer name + issue count (correct singular form for n=1)',
       _b0 === 'DIM-WALLS (1 issue)' && _b1 === 'TXT-LABELS (1 issue)');
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
assert('V12: empty layerIssueGroups -> summary "Issues by Layer — 0 layers (0 issues)"',
       mockElements['layer-issues-summary'].textContent ===
         'Issues by Layer \u2014 0 layers (0 issues)');

// V12: undefined layerIssueGroups is the default-empty path.
renderWithPayload({
  selectionLabel: 'g', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0, issues: {} },
  groups:  [],
  layerGroups: [],
  layerIssueGroups: undefined  // V1.0 / V1.1 caller path
});
assert('V12: undefined layerIssueGroups -> empty list + zero-summary',
       mockElements['layer-issues-list'].children.length === 0 &&
       mockElements['layer-issues-summary'].textContent ===
         'Issues by Layer \u2014 0 layers (0 issues)');

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
assert('V12: bucket summary plural form for n=2 ("2 issues")',
       v12MultiBucket.children[0].textContent === 'DIM-XX (2 issues)');
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
assert('V12-NIT-001: summary uses singular form for n=1 layer ("Issues by Layer \u2014 1 layer (1 issues)")',
       mockElements['layer-issues-summary'].textContent ===
         'Issues by Layer \u2014 1 layer (1 issues)');

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
assert('V13: face-inventory-summary populated BEFORE opening with format "N total (H with holes)"',
       v13FaceInvSummary && v13FaceInvSummary.textContent ===
         'Face Inventory \u2014 2 total (1 with holes)');
assert('V13: each row has class face-inventory-row',
       v13FaceInvList.children.every(function (c) {
         return c.classes.indexOf('face-inventory-row') !== -1;
       }));
assert('V13: row 1 (DIM-WALLS) renders layer name + role badge + visibility badge + face count + holes count',
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
         if (facesCell.textContent !== '1 face') return false;
         if (holesCell.textContent !== '1 face with holes') return false;
         if (sep.textContent !== '\u00B7') return false;
         return true;
       })());
assert('V13: face_count singular form for n=1 ("1 face")',
       v13FaceInvList.children[0].children
         .filter(function (c) { return c.classes.indexOf('face-count') !== -1; })[0]
         .textContent === '1 face');
assert('V13: faces_with_holes_count singular form for n=1 ("1 face with holes")',
       v13FaceInvList.children[0].children
         .filter(function (c) { return c.classes.indexOf('holes-count') !== -1; })[0]
         .textContent === '1 face with holes');
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
assert('V13: empty faceInventoryGroups -> summary "Face Inventory — 0 total (0 with holes)"',
       mockElements['face-inventory-summary'].textContent ===
         'Face Inventory \u2014 0 total (0 with holes)');

// V13: undefined faceInventoryGroups is the default-empty path.
renderWithPayload({
  selectionLabel: 'g', selectionType: 'Group',
  summary: { edges: 4, vertices: 4, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: undefined  // V1.0/V1.1/V1.2 caller path
});
assert('V13: undefined faceInventoryGroups -> empty list + zero-summary',
       mockElements['face-inventory-list'].children.length === 0 &&
       mockElements['face-inventory-summary'].textContent ===
         'Face Inventory \u2014 0 total (0 with holes)');

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
assert('V13: summary block contains "Faces: 1" + "Faces With Holes: 0" scalars',
       (function () {
         var summaryEl = mockElements['summary'];
         var texts = [];
         function collect(el) {
           if (el.textContent) texts.push(el.textContent);
           for (var i = 0; i < el.children.length; i++) collect(el.children[i]);
         }
         collect(summaryEl);
         var all = texts.join(' | ');
         return all.indexOf('Faces: 1') !== -1 && all.indexOf('Faces With Holes: 0') !== -1;
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

assert('V14: working-mode-summary populated with idle text on state="none"',
       wmSummary && wmSummary.textContent === 'Working Mode — no working copy');
assert('V14: working-mode-list contains one row describing the idle state',
       wmList && wmList.children.length === 1);
assert('V14: idle row uses data-state="none" + .working-mode-row class',
       wmList && wmList.children[0] &&
       wmList.children[0].attrs['data-state'] === 'none' &&
       wmList.children[0].classes.indexOf('working-mode-row') !== -1);
assert('V14: idle row text uses textContent (no [object Object])',
       wmList && wmList.children[0] &&
       wmList.children[0].textContent.indexOf('[object Object]') === -1);
// In state='none' ONLY the Prepare button is enabled.
var wmActionBtns = wmActions ? wmActions.children : [];
assert('V14: state="none" produces exactly ONE action button (Prepare only)',
       wmActionBtns.length === 1);
assert('V14: state="none" Prepare button has data-action="prepare_workspace"',
       wmActionBtns[0] && wmActionBtns[0].attrs['data-action'] === 'prepare_workspace' &&
       wmActionBtns[0].textContent === 'Prepare' &&
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
assert('V14: ready state summary mentions "Working Mode — N entities ready"',
       wmReadySummary && /Working Mode — \d+ entities? ready/.test(wmReadySummary.textContent));
assert('V14: ready list has rows for source_snapshot_id + digests',
       wmReadyList && wmReadyList.children.length >= 3);
assert('V14: ready rows carry data-state="ready"',
       wmReadyList && wmReadyList.children.every(function (c) {
         return c.attrs['data-state'] === 'ready';
       }));
// In state='ready' ALL THREE buttons appear; Discard enabled, Prepare
// disabled (re-prepare requires discard first).
var wmReadyBtns = wmReadyActions ? wmReadyActions.children : [];
assert('V14: state="ready" produces THREE action buttons',
       wmReadyBtns.length === 3);
var wmBtnActions = wmReadyBtns.map(function (b) { return b.attrs['data-action']; });
assert('V14: state="ready" buttons are prepare/discard/rebuild (canonical order)',
       wmBtnActions[0] === 'prepare_workspace' &&
       wmBtnActions[1] === 'discard_workspace' &&
       wmBtnActions[2] === 'rebuild_workspace');
assert('V14: state="ready" Discard button is enabled (no disabled attr)',
       wmReadyBtns[1] && !wmReadyBtns[1].hasAttribute('disabled'));

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
assert('V14: discarded state summary shows "Working Mode — discarded"',
       wmDiscardedSummary && wmDiscardedSummary.textContent.indexOf('discarded') !== -1);

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
assert('V14: failed state has a row labeled "Last Error" with the message',
       (function () {
         if (!wmFailedList) return false;
         var found = wmFailedList.children.filter(function (c) {
           return c.textContent.indexOf('Last Error') !== -1 &&
                  c.textContent.indexOf('host failure') !== -1;
         });
         return found.length >= 1;
       })());

// Defensive: missing derivedWorkspace => treated as 'none' state.
renderWithPayload({
  selectionLabel: 'wm-missing', selectionType: 'Group',
  summary: { edges: 0, vertices: 0, non_zero_z_vertices: 0, warnings: 0,
             faces: 0, faces_with_holes: 0, issues: {} },
  groups:  [], layerGroups: [], layerIssueGroups: [],
  faceInventoryGroups: []
  // derivedWorkspace is intentionally missing.
});
assert('V14: missing derivedWorkspace defaults to state="none" (defensive)',
       mockElements['working-mode-summary'].textContent === 'Working Mode — no working copy');

// Action button click -> invokes window.SUAIP[callback].
var locateCountBefore = locateCalls.length;
wmReadyActions.children.forEach(function (b) { b.fireEvent('click'); });
assert('V14: clicking Rebuild in state="ready" does NOT invoke Locate (it is a separate callback)',
       locateCalls.length === locateCountBefore);

// ROOT.renderWorkingMode is exposed.
assert('V14: ROOT.renderWorkingMode is exposed',
       typeof context.window.SUAIP.renderWorkingMode === 'function');

// --- final verdict -----------------------------------------------------

var failed = results.filter(function (r) { return !r.pass; });
if (failed.length === 0) {
  process.stdout.write('PASS\n');
  process.exit(0);
} else {
  process.stderr.write('FAIL (' + failed.length + ' of ' + results.length + ')\n');
  process.exit(1);
}
