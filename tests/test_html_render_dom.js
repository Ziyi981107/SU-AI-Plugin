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
  this.style = {};
  this._events = {};
  this.hidden = true;
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
MockElement.prototype.addEventListener = function () { /* no-op */ };

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

// --- final verdict -----------------------------------------------------

var failed = results.filter(function (r) { return !r.pass; });
if (failed.length === 0) {
  process.stdout.write('PASS\n');
  process.exit(0);
} else {
  process.stderr.write('FAIL (' + failed.length + ' of ' + results.length + ')\n');
  process.exit(1);
}
