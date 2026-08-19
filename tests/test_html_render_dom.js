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
}
MockElement.prototype.setAttribute = function (name, value) {
  this.attrs[name] = value;
};
MockElement.prototype.getAttribute = function (name) {
  return this.attrs[name];
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
MockElement.prototype.setAttribute = function (name, value) {
  this.attrs[name] = value;
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
  'toast':          new MockElement('div')
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

var appJsPath = path.resolve(__dirname, '..', 'extension', 'html', 'app.js');
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

// --- final verdict -----------------------------------------------------

var failed = results.filter(function (r) { return !r.pass; });
if (failed.length === 0) {
  process.stdout.write('PASS\n');
  process.exit(0);
} else {
  process.stderr.write('FAIL (' + failed.length + ' of ' + results.length + ')\n');
  process.exit(1);
}
