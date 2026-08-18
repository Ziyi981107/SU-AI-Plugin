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
