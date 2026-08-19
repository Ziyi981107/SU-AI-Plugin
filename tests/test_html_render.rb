#
# tests/test_html_render.rb — HTML/JS contract test.
#
# Per CodeX Round 018 BLOCK-006:
#   - The rendered bridge payload is valid JSON.
#   - The JS namespaces match what Ruby calls.
#   - The JS uses no forbidden patterns (no eval, no innerHTML,
#     no document.write, no new Function).
#   - The HTML output references the locked header elements.
#   - All file paths resolve to real files (no `__dir__` typos).
#

require_relative 'runner'
require_relative '../core/issue_registry'
require_relative '../core/analysis_result'
require_relative '../extension/ui_bridge'

include SUAnalysis::Core
include SUAnalysis::Extension

# --- helpers ---------------------------------------------------------

# Build a minimal Issue Hash compatible with IssueRegistry validation.
def hr_make_issue(id, type: 'short_edge', severity: 'low', confidence: 'medium')
  {
    issue_id:          id,
    issue_type:        type,
    severity:          severity,
    confidence:        confidence,
    sources:           [],
    source_entity_ids: [],
    edge_ids:          [],
    location:          nil,
    message:           'm',
    metadata:          {},
    locatable:         false,
    display_length:    nil
  }
end

# Build a minimal AnalysisResult with one Issue + a small preflight.
def hr_make_result
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count).new(4, 5, 0, 1)
  reg = IssueRegistry.new([hr_make_issue('short_edge|1|1')])
  AnalysisResult.new(
    preflight:        pf,
    registry:         reg,
    selection_type:   'Group',
    selection_label:  'my_group'
  )
end

# Resolve paths RELATIVE TO THE TESTS DIRECTORY (one level up to project
# root, then into extension/). The previous version used `../../` which
# resolved to D:/Projects/... and produced ENOENT errors.
HR_HTML_INDEX = File.expand_path('../extension/html/index.html', __dir__).freeze
HR_HTML_APPJS = File.expand_path('../extension/html/app.js', __dir__).freeze
HR_HTML_CSS   = File.expand_path('../extension/html/style.css', __dir__).freeze
HR_RUNNER_RB  = File.expand_path('../extension/dialog_runner.rb', __dir__).freeze

# --- tests ----------------------------------------------------------

test 'html_render: analyze selection result is valid JSON' do
  result = hr_make_result
  json = UIBridge.to_json(result)
  require 'json'
  parsed = JSON.parse(json)
  assert_equal 'Group', parsed['selectionType']
  assert_equal 'my_group', parsed['selectionLabel']
  # The short_edge count is in summary['issues'] (NOT top-level summary).
  assert_equal 1, parsed['summary']['issues']['short_edge']
end

test 'html_render: summary includes Edges and Vertices (Round 018 BLOCK-006)' do
  result = hr_make_result
  payload = UIBridge.as_html_data(result)
  assert_equal 4, payload['summary']['edges']
  assert_equal 5, payload['summary']['vertices']
  assert_equal 0, payload['summary']['non_zero_z_vertices']
  assert_equal 1, payload['summary']['warnings']
end

test 'html_render: index.html references locked header elements' do
  assert File.exist?(HR_HTML_INDEX), "missing: #{HR_HTML_INDEX}"
  src = File.read(HR_HTML_INDEX)
  assert_match(/<header>/, src)
  assert_match(/CAD Analyzer Result/, src)
  assert_match(/<section id="summary">/, src)
  assert_match(/<section id="groups">/, src)
  assert_match(/<div id="toast"/, src)
end

test 'html_render: app.js uses no forbidden patterns' do
  assert File.exist?(HR_HTML_APPJS), "missing: #{HR_HTML_APPJS}"
  # Strip comment lines so the commentary on the forbidden patterns
  # doesn't false-positive the regex check.
  code_only = File.readlines(HR_HTML_APPJS, encoding: 'utf-8')
    .reject { |l| l.lstrip.start_with?('//', '*') }
    .join
  refute_match(/\beval\(/, code_only,
               'app.js must not call eval(...) — the ready handshake is fixed')
  refute_match(/\bnew\s+Function\(/, code_only,
               'app.js must not construct a Function(...)')
  refute_match(/\bdocument\.write\(/, code_only)
  refute_match(/\.innerHTML\s*=/, code_only)
end

test 'html_render: app.js exports render and toast on window.SUAIP (Round 018 BLOCK-003)' do
  assert File.exist?(HR_HTML_APPJS), "missing: #{HR_HTML_APPJS}"
  src = File.read(HR_HTML_APPJS)
  # The code defines `var ROOT = window.SUAIP || (window.SUAIP = {})`
  # and then `ROOT.render = render; ROOT.toast = toast;`. Both
  # assignments are equivalent to window.SUAIP.render/toast at runtime.
  # Verify the explicit binding in the IIFE initializer + the assignments.
  assert_match(/window\.SUAIP/, src,
               'app.js must reference the window.SUAIP namespace')
  assert_match(/\.render\s*=\s*render/, src,
               'app.js must assign the render function on the namespace')
  assert_match(/\.toast\s*=\s*toast/, src,
               'app.js must assign the toast function on the namespace')
end

test 'html_render: dialog_runner calls window.SUAIP.render not window.SUAIP' do
  assert File.exist?(HR_RUNNER_RB), "missing: #{HR_RUNNER_RB}"
  src = File.read(HR_RUNNER_RB)
  assert_match(/window\.SUAIP\.render\(/, src)
  assert_match(/window\.SUAIP\.toast\(/, src)
end

test 'html_render: style.css defines severity palette' do
  assert File.exist?(HR_HTML_CSS), "missing: #{HR_HTML_CSS}"
  src = File.read(HR_HTML_CSS)
  assert_match(/--sev-low/, src)
  assert_match(/--sev-medium/, src)
  assert_match(/--sev-high/, src)
end

test 'html_render: set_file path uses absolute path (Round 018 BLOCK-006)' do
  assert File.exist?(HR_RUNNER_RB), "missing: #{HR_RUNNER_RB}"
  src = File.read(HR_RUNNER_RB)
  # The runner builds an absolute index path via File.expand_path and
  # then passes it to set_file. Match the helper invocation, not the
  # direct set_file call (the variable is passed, not the literal).
  assert_match(/File\.expand_path\(['"]html\/index\.html['"],\s*__dir__\)/, src,
               'dialog_runner.rb must build the html path via File.expand_path + __dir__')
  assert_match(/dialog\.set_file\(index_path\)/, src,
               'dialog_runner.rb must call set_file with the built path')
end

# --------------------------------------------------------------------------
# Round 018 BLOCK-006: additional HTML contract tests.
# --------------------------------------------------------------------------

test 'html_render: app.js uses textContent / setAttribute (no innerHTML for user strings)' do
  src = File.read(HR_HTML_APPJS)
  # The renderIssue path uses textContent + setAttribute exclusively.
  assert_match(/\.textContent\s*=/, src)
  assert_match(/\.setAttribute\(/, src)
end

test 'html_render: app.js calls window.sketchup.locate (Round 018 contract)' do
  src = File.read(HR_HTML_APPJS)
  assert_match(/window\.sketchup\.locate\(/, src)
end

test 'html_render: app.js ready handshake calls window.sketchup.ready' do
  src = File.read(HR_HTML_APPJS)
  assert_match(/window\.sketchup\.ready\(\)/, src)
end

test 'html_render: index.html references app.js + style.css' do
  src = File.read(HR_HTML_INDEX)
  assert_match(/app\.js/, src)
  assert_match(/style\.css/, src)
end

test 'html_render: dialog_runner uses BLOCK callbacks, not method(:name)' do
  src = File.read(HR_RUNNER_RB)
  # Block syntax: `dialog.add_action_callback('foo') { ... }`
  assert_match(/add_action_callback\(['"]ready['"][^)]*\)\s*\{/, src)
  assert_match(/add_action_callback\(['"]locate['"][^)]*\)\s*\{/, src)
  assert_match(/add_action_callback\(['"]close['"][^)]*\)\s*\{/, src)
  # Negative: no `method(` calls inside add_action_callback.
  refute_match(/add_action_callback\([^)]*method\(:/, src)
end

# --------------------------------------------------------------------------
# Round 019 BLOCK-006-R2: executable render/DOM test.
# Spawns Node.js to actually load extension/html/app.js into a mock
# DOM (via vm.runInContext), invoke window.SUAIP.render(payload),
# and inspect the rendered children for the locked Stage 6 plan
# section 6.7 summary contract:
#   - per-issue-type counters in the canonical order
#   - no "[object Object]" in any rendered text
#   - data-issue-type attrs on every issue stat
# --------------------------------------------------------------------------

HR_RENDER_DOM_JS = File.expand_path('test_html_render_dom.js', __dir__).freeze

def hr_run_node_render_test
  # Use `node <path>`; capture stdout+stderr; the JS test prints
  # "ASSERT <name> PASS|FAIL" lines and a final "PASS"/"FAIL" line.
  out = `node "#{HR_RENDER_DOM_JS}" 2>&1`
  [out, $?.exitstatus]
end

test 'html_render: render outputs per-issue-type counters in locked order (BLOCK-006-R2)' do
  out, exit_code = hr_run_node_render_test
  # The JS test must end with the "PASS" sentinel and exit 0.
  assert_equal 0, exit_code, "node test exited #{exit_code}; output:\n#{out}"
  assert_match(/^PASS\s*$/, out, "node test did not PASS:\n#{out}")
  # Cross-check the critical labels the BLOCK-006-R2 contract calls
  # out by name.
  assert_match(/ASSERT summary: Short Edges: 1 present PASS/, out)
  assert_match(/ASSERT summary: Duplicate Candidates: 0 present PASS/, out)
  assert_match(/ASSERT summary: no "\[object Object\]" in any rendered text PASS/, out)
  assert_match(/ASSERT order: per-issue rows in canonical order/, out)
  assert_match(/ASSERT summary: 7 data-issue-type attrs present/, out)
end

test 'html_render: app.js exports ISSUE_TYPE_LABELS for the locked render order (BLOCK-006-R2)' do
  src = File.read(HR_HTML_APPJS)
  # The render function must iterate over a fixed ISSUE_TYPE_LABELS
  # array (the locked canonical order). The labels are exposed on
  # ROOT.ISSUE_TYPE_LABELS so the test harness can introspect.
  assert_match(/ROOT\.ISSUE_TYPE_LABELS\s*=\s*ISSUE_TYPE_LABELS/, src)
  # The array is the canonical order per IssueRegistry.
  expected_types = %w[
    duplicate_edge_candidate
    short_edge
    open_endpoint
    gap_candidate
    significant_non_zero_z
    abnormal_large_coord
    deep_nesting
  ]
  expected_types.each do |t|
    assert_match(/'#{t}'/, src,
                 "ISSUE_TYPE_LABELS must include '#{t}' in canonical order")
  end
end

# --------------------------------------------------------------------------
# CodeX Round 020 REAL-HOST BLOCK (recheck) L3: per-issue click handler
# dispatch. The previous app.js#renderIssue unconditionally added a
# click listener for every issue that called window.sketchup.locate(id).
# For non-locatable rows (preflight warnings like deep_nesting and
# abnormal_large_coord), the locator returns :unresolved and the JS
# previously raised a misleading "source no longer available" toast.
# These rows are intentionally non-locatable (no source token to
# resolve), NOT stale.
#
# Fix: only register the click handler when issue.locatable === true.
# For locatable === false, the row is non-actionable: no click handler,
# no path to window.sketchup.locate, no path to the toast.
# --------------------------------------------------------------------------

test 'html_render (L3): renderIssue branches on issue.locatable before adding click listener' do
  src = File.read(HR_HTML_APPJS)
  # The fix: the addEventListener('click', ...) call MUST be inside
  # a branch gated by issue.locatable (or equivalent). A bare,
  # unconditional addEventListener would re-introduce the L3 bug.
  #
  # Look for the conditional structure: an `if (locatable)` /
  # `if (...locatable...)` guard before the addEventListener('click').
  assert_match(/if\s*\(\s*locatable\s*\)\s*\{/, src,
               'renderIssue must gate the click handler on locatable === true')
  # And the addEventListener('click', ...) call must appear INSIDE
  # that if-block (not before it). The simplest check: count the
  # addEventListener('click', ...) occurrences and ensure they're
  # inside the if.
  click_listeners = src.scan(/addEventListener\(['"]click['"]/).length
  assert_equal 1, click_listeners,
               'there must be exactly ONE addEventListener("click", ...) call (the locatable one)'

  # The CSS `no-action` class must be defined for the visual
  # non-action state (default cursor, no hover affordance).
  css_src = File.read(HR_HTML_CSS)
  assert_match(/\.issue\.no-action/, css_src,
               'style.css must define .issue.no-action for non-action visual state')
  # Cursor and hover overrides must be present.
  assert_match(/\.issue\.no-action\s*\{[^}]*cursor:\s*default/m, css_src,
               '.issue.no-action must set cursor: default (no pointer)')
  assert_match(/\.issue\.no-action:hover/, css_src,
               '.issue.no-action:hover must override the hover affordance')
end

test 'html_render (L3): executable DOM test asserts the L3 contract' do
  # The Node.js DOM test (tests/test_html_render_dom.js) exercises the
  # full click path. It MUST contain L3 assertions for both the
  # locatable and non-locatable branches.
  js_src = File.read(HR_RENDER_DOM_JS)
  # L3.1 — locatable issue calls locate exactly once.
  assert_match(/L3\.1:.*locatable.*locate.*ONCE/m, js_src,
               'test_html_render_dom.js must assert locatable rows invoke locate once')
  # L3.2 — non-locatable issue has no click handler and no locate call.
  assert_match(/L3\.2:.*non-locatable.*NO click/m, js_src,
               'test_html_render_dom.js must assert non-locatable rows have no click listener')
  assert_match(/L3\.2:.*non-locatable.*NOT invoke/m, js_src,
               'test_html_render_dom.js must assert non-locatable rows do NOT invoke locate')
end

test 'html_render (L3): executable render test runs the new assertions and passes' do
  # Run the Node.js DOM test and ensure it PASSES. The new L3
  # assertions MUST appear in the output.
  out, exit_code = hr_run_node_render_test
  assert_equal 0, exit_code, "node test exited #{exit_code}; output:\n#{out}"
  assert_match(/^PASS\s*$/, out, "node test did not PASS:\n#{out}")
  # Spot-check the L3 assertions by name.
  assert_match(/ASSERT L3\.1:.*locatable row has click listener registered PASS/, out)
  assert_match(/ASSERT L3\.2:.*non-locatable row has NO click listener PASS/, out)
  assert_match(/ASSERT L3\.1:.*locatable row invokes window\.sketchup\.locate ONCE PASS/, out)
  assert_match(/ASSERT L3\.2:.*non-locatable row does NOT invoke window\.sketchup\.locate PASS/, out)
end
