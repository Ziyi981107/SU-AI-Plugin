#
# tests/test_html_render.rb — V1.9A-A1 HTML / JS contract test.
#
# Per dispatch §13 (DOM tests) + AGENTS.md / Blueprint §5.7
# (production frontend may be substantially rewritten):
#   - The rendered bridge payload is valid JSON.
#   - The JS namespaces match what Ruby calls.
#   - The JS uses no forbidden patterns (no eval, no innerHTML,
#     no document.write, no new Function).
#   - The HTML output references the locked header elements.
#   - All file paths resolve to real files (no `__dir__` typos).
#
# V1.9A-A1 DOM contract:
#   - 4 tabs (处理 default, 问题, 图层, 详情).
#   - 5 capability cards in fixed order.
#   - Default = 处理.
#   - Inventory absent on default 处理 tab.
#   - Technical / raw inventory reachable in 详情.
#   - Buttons dispatch the existing callbacks
#     (prepare_workspace, discard_workspace, rebuild_workspace,
#     compute_planar_normalization, apply_planar_normalization,
#     compute_gap_repair, apply_gap_repair,
#     compute_structure_reconstruction, locate, close).
#   - No remote runtime asset / no CDN.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/ui_bridge'

include SUAnalysis::Core
include SUAnalysis::Extension

# --- helpers ---------------------------------------------------------

def hr_make_issue(id, type: 'short_edge', severity: 'low', confidence: 'medium', locatable: false)
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
    locatable:         locatable,
    display_length:    nil
  }
end

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

HR_HTML_INDEX = File.expand_path('../extension/su_ai_plugin/html/index.html', __dir__).freeze
HR_HTML_APPJS = File.expand_path('../extension/su_ai_plugin/html/app.js', __dir__).freeze
HR_HTML_CSS   = File.expand_path('../extension/su_ai_plugin/html/style.css', __dir__).freeze
HR_RUNNER_RB  = File.expand_path('../extension/su_ai_plugin/dialog_runner.rb', __dir__).freeze
HR_PRESENTER  = File.expand_path('../extension/su_ai_plugin/cad_prep_workflow_presenter.rb', __dir__).freeze

# --- tests ----------------------------------------------------------

test 'html_render: analyze selection result is valid JSON' do
  result = hr_make_result
  json = UIBridge.to_json(result)
  require 'json'
  parsed = JSON.parse(json)
  assert_equal 'Group', parsed['selectionType']
  assert_equal 'my_group', parsed['selectionLabel']
  assert_equal 1, parsed['summary']['issues']['short_edge']
end

test 'html_render: summary includes Edges and Vertices (V1.4 contract preserved)' do
  result = hr_make_result
  payload = UIBridge.as_html_data(result)
  assert_equal 4, payload['summary']['edges']
  assert_equal 5, payload['summary']['vertices']
  assert_equal 0, payload['summary']['non_zero_z_vertices']
  assert_equal 1, payload['summary']['warnings']
end

# ---------------------------------------------------------------------------
# V1.9A-A1: index.html references the locked 4-tab IA
# ---------------------------------------------------------------------------

test 'html_render (V1.9A-A1): index.html has the 4-tab navigation with 处理 default active' do
  src = File.read(HR_HTML_INDEX)
  # 4 tabs.
  assert_match(/id="tab-process"/, src)
  assert_match(/id="tab-issues"/, src)
  assert_match(/id="tab-layers"/, src)
  assert_match(/id="tab-details"/, src)
  # 处理 default.
  assert_match(/id="tab-process"[^>]*aria-selected="true"/, src)
  # Tab list ARIA + role.
  assert_match(/<nav[^>]*role="tablist"/, src)
  assert_match(/role="tab"/, src)
end

test 'html_render (V1.9A-A1): index.html has the 4 panels with the locked ids' do
  src = File.read(HR_HTML_INDEX)
  assert_match(/id="panel-process"/, src)
  assert_match(/id="panel-issues"/, src)
  assert_match(/id="panel-layers"/, src)
  assert_match(/id="panel-details"/, src)
  assert_match(/role="tabpanel"/, src)
  # 处理 panel is visible by default (no hidden attribute).
  assert_match(/<section[^>]*id="panel-process"[^>]*role="tabpanel"/, src)
end

test 'html_render (V1.9A-A1): index.html has the recovery banner + CTA row + issue summary + capability grid' do
  src = File.read(HR_HTML_INDEX)
  assert_match(/id="recovery-banner"/, src)
  assert_match(/id="cta-row"/, src)
  assert_match(/id="cta-headline"/, src)
  assert_match(/id="cta-sub"/, src)
  assert_match(/id="btn-primary-cta"/, src)
  assert_match(/id="issue-summary"/, src)
  assert_match(/id="capability-grid"/, src)
end

test 'html_render (V1.9A-A1): index.html has the brand mark + selection line + status chip' do
  src = File.read(HR_HTML_INDEX)
  assert_match(/class="brand-mark"/, src)
  assert_match(/class="brand-title"/, src)
  assert_match(/id="selection-line"/, src)
  assert_match(/id="selection-value"/, src)
  assert_match(/id="status-chip"/, src)
  assert_match(/id="status-text"/, src)
end

test 'html_render (V1.9A-A1): index.html preserves the toast element for legacy SUAIP.toast' do
  src = File.read(HR_HTML_INDEX)
  assert_match(/id="toast"/, src)
end

test 'html_render (V1.9A-A1): index.html references app.js + style.css' do
  src = File.read(HR_HTML_INDEX)
  assert_match(/app\.js/, src)
  assert_match(/style\.css/, src)
end

# ---------------------------------------------------------------------------
# V1.9A-A1: app.js uses no forbidden patterns
# ---------------------------------------------------------------------------

test 'html_render: app.js uses no forbidden patterns (V1.9A-A1)' do
  assert File.exist?(HR_HTML_APPJS), "missing: #{HR_HTML_APPJS}"
  # Strip comment lines so the commentary on the forbidden
  # patterns does not false-positive the regex check.
  code_only = File.readlines(HR_HTML_APPJS, encoding: 'utf-8')
    .reject { |l| l.lstrip.start_with?('//', '*') }
    .join
  refute_match(/\beval\(/, code_only,
               'app.js must not call eval(...)')
  refute_match(/\bnew\s+Function\(/, code_only,
               'app.js must not construct a Function(...)')
  refute_match(/\bdocument\.write\(/, code_only)
  refute_match(/\.innerHTML\s*=/, code_only)
end

test 'html_render: app.js exports render and toast on window.SUAIP (V1.4 contract preserved)' do
  assert File.exist?(HR_HTML_APPJS), "missing: #{HR_HTML_APPJS}"
  src = File.read(HR_HTML_APPJS)
  assert_match(/window\.SUAIP/, src)
  assert_match(/\.render\s*=\s*render/, src,
               'app.js must bind ROOT.render = render (or equivalent)')
  # The toast binding may rename the internal function
  # (e.g. ROOT.toast = _toast). We accept either form as
  # long as the resulting window.SUAIP.toast is a callable.
  assert_match(/\.toast\s*=\s*[A-Za-z_][A-Za-z_0-9]*/, src,
               'app.js must bind window.SUAIP.toast to a callable function')
end

test 'html_render: dialog_runner calls window.SUAIP.render not window.SUAIP (V1.4 contract)' do
  assert File.exist?(HR_RUNNER_RB), "missing: #{HR_RUNNER_RB}"
  src = File.read(HR_RUNNER_RB)
  assert_match(/window\.SUAIP\.render\(/, src)
  assert_match(/window\.SUAIP\.toast\(/, src)
end

# ---------------------------------------------------------------------------
# V1.9A-A1: style.css honors the frozen visual language + legacy-aware rules
# ---------------------------------------------------------------------------

test 'html_render (V1.9A-A1): style.css defines the locked visual tokens' do
  assert File.exist?(HR_HTML_CSS), "missing: #{HR_HTML_CSS}"
  src = File.read(HR_HTML_CSS)
  # Tokens used by the approved visual language.
  assert_match(/--bg-app/, src)
  assert_match(/--accent-1/, src)
  assert_match(/--accent-2/, src)
  assert_match(/--ok-1/, src)
  assert_match(/--warn-1/, src)
  assert_match(/--err-1/, src)
  assert_match(/--r-card/, src)
  # No CSS Grid (legacy-aware).
  refute_match(/\bdisplay\s*:\s*grid\b/, src,
               'style.css MUST NOT use CSS Grid (legacy-aware frontend)')
  # No flex `gap` (legacy-aware).
  refute_match(/\bgap\s*:\s*\d/, src,
               'style.css MUST NOT use flex `gap` (legacy-aware frontend)')
  # No `backdrop-filter`. Permit mentions in comments.
  code_only = src.lines.reject { |l| l.lstrip.start_with?('/*', '*', '//') }.join
  refute_match(/backdrop-filter/, code_only,
               'style.css MUST NOT use backdrop-filter (legacy-aware frontend)')
  # No `@import`.
  refute_match(/@import/, code_only)
  # No remote url(...) — only inline data URLs are allowed.
  # We permit `url(#brand-grad)` (SVG fragment) and similar.
  remote_url_lines = src.lines.select { |l| l =~ /url\s*\(\s*['"]?https?:|url\s*\(\s*['"]?\/\// }
  assert_equal [], remote_url_lines,
               "style.css MUST NOT reference remote assets: #{remote_url_lines.inspect}"
end

test 'html_render (V1.9A-A1): style.css defines the capability card + status chip + tab styles' do
  src = File.read(HR_HTML_CSS)
  assert_match(/\.cap-card/, src)
  assert_match(/\.cap-icon/, src)
  assert_match(/\.cap-state/, src)
  assert_match(/\.status-chip/, src)
  assert_match(/\.status-chip\[data-state="IDLE"\]/, src)
  assert_match(/\.status-chip\[data-state="NEEDS_ATTENTION"\]/, src)
  assert_match(/\.status-chip\[data-state="READY_FOR_VALIDATION"\]/, src)
  assert_match(/\.status-chip\[data-state="STALE"\]/, src)
  assert_match(/\.status-chip\[data-state="FAILED"\]/, src)
  assert_match(/\.tab-bar/, src)
  assert_match(/\.tab-item/, src)
  assert_match(/\.tab-item\[aria-selected="true"\]/, src)
  assert_match(/\.issue-summary/, src)
  assert_match(/\.issue-summary\.is-clean/, src)
  assert_match(/\.recovery-banner/, src)
end

# ---------------------------------------------------------------------------
# V1.9A-A1: app.js preserves the V1.4 callback contract
# ---------------------------------------------------------------------------

test 'html_render (V1.9A-A1): app.js preserves window.sketchup.ready handshake' do
  src = File.read(HR_HTML_APPJS)
  assert_match(/window\.sketchup\.ready\(\)/, src,
               'app.js must call window.sketchup.ready() on DOMContentLoaded')
end

test 'html_render (V1.9A-A1): app.js preserves window.sketchup.locate contract (L3)' do
  src = File.read(HR_HTML_APPJS)
  assert_match(/window\.sketchup\.locate\(/, src)
end

test 'html_render (V1.9A-A1): app.js preserves all existing callback names (dispatch §12)' do
  src = File.read(HR_HTML_APPJS)
  expected_callbacks = %w[
    prepare_workspace
    discard_workspace
    rebuild_workspace
    compute_planar_normalization
    apply_planar_normalization
    compute_gap_repair
    apply_gap_repair
    compute_structure_reconstruction
    locate
    close
  ]
  expected_callbacks.each do |cb|
    assert src.include?(cb),
           "app.js MUST reference the existing callback #{cb.inspect} (dispatch §12)"
  end
end

# ---------------------------------------------------------------------------
# V1.9A-A1: dialog_runner preserves all existing callbacks (dispatch §12)
# ---------------------------------------------------------------------------

test 'html_render (V1.9A-A1): dialog_runner registers all 11 required callbacks' do
  src = File.read(HR_RUNNER_RB)
  expected = %w[
    ready
    locate
    close
    prepare_workspace
    discard_workspace
    rebuild_workspace
    compute_planar_normalization
    apply_planar_normalization
    compute_gap_repair
    apply_gap_repair
    compute_structure_reconstruction
  ]
  expected.each do |cb|
    assert src =~ /add_action_callback\(["']#{cb}["']/,
           "dialog_runner MUST register the callback #{cb.inspect} (dispatch §12)"
  end
end

test 'html_render: dialog_runner uses BLOCK callbacks, not method(:name) (V1.4 contract)' do
  src = File.read(HR_RUNNER_RB)
  assert_match(/add_action_callback\(['"]ready['"][^)]*\)\s*\{/, src)
  refute_match(/add_action_callback\([^)]*method\(:/, src,
               'dialog_runner must use BLOCK callbacks, NOT method(:name)')
end

test 'html_render: set_file path uses absolute path (V1.4 contract Round 018 BLOCK-006)' do
  src = File.read(HR_RUNNER_RB)
  assert_match(/File\.expand_path\(['"]html\/index\.html['"],\s*__dir__\)/, src)
  assert_match(/dialog\.set_file\(index_path\)/, src)
end

# ---------------------------------------------------------------------------
# V1.9A-A1: presenter exists + is loaded by UIBridge
# ---------------------------------------------------------------------------

test 'html_render (V1.9A-A1): presenter module file exists' do
  assert File.exist?(HR_PRESENTER), "missing: #{HR_PRESENTER}"
end

test 'html_render (V1.9A-A1): ui_bridge.rb requires the presenter and exposes cadPrepWorkflow' do
  src = File.read(File.expand_path('../extension/su_ai_plugin/ui_bridge.rb', __dir__))
  assert_match(/require_relative\s+['"]cad_prep_workflow_presenter['"]/, src,
               'ui_bridge.rb must require the presenter')
  assert_match(/['"]cadPrepWorkflow['"]/, src,
               'ui_bridge.rb must expose the additive cadPrepWorkflow key')
end

# ---------------------------------------------------------------------------
# V1.9A-A1: executable Node DOM test (the heavy DOM contract)
# ---------------------------------------------------------------------------

DOM_TEST_PATH = File.expand_path('test_html_render_dom.js', __dir__).freeze

test 'html_render (V1.9A-A1): executable Node DOM test passes (4 tabs / 5 cards / callbacks / locate)' do
  require 'open3'
  out, err, status = Open3.capture3('node', DOM_TEST_PATH)
  assert status.success?, "node DOM test exited #{status.inspect}\nstdout: #{out}\nstderr: #{err}"
  # The Node DOM test prints one line per ASSERT + a final
  # "PASS" line. Count the PASS lines.
  pass_count = out.lines.count { |l| l.start_with?('ASSERT ') && l.include?(' PASS') }
  fail_count = out.lines.count { |l| l.start_with?('ASSERT ') && l.include?(' FAIL') }
  assert fail_count.zero?, "node DOM test had #{fail_count} FAIL line(s):\n#{out}"
  assert pass_count >= 30,
         "expected at least 30 PASS lines from node DOM test, got #{pass_count}\n#{out}"
  assert out.lines.last.strip == 'PASS',
         "node DOM test must end with PASS line, got: #{out.lines.last.inspect}"
end

# ---------------------------------------------------------------------------
# V1.9A-A1: legacy raw payload fields remain available
# ---------------------------------------------------------------------------

test 'html_render (V1.9A-A1): ui_bridge preserves legacy raw payload fields (V1.0-V1.8 backward compat)' do
  result = hr_make_result
  payload = UIBridge.as_html_data(result)
  %w[selectionType selectionLabel summary diagnostics groups layerGroups
     layerIssueGroups faceInventoryGroups derivedWorkspace cadPrepWorkflow].each do |k|
    assert payload.key?(k), "ui_bridge payload missing legacy key #{k.inspect}"
  end
end

test 'html_render (V1.9A-A1): cadPrepWorkflow carries the locked 5-card order' do
  result = hr_make_result
  payload = UIBridge.as_html_data(result)
  wf = payload['cadPrepWorkflow']
  assert_equal %w[duplicate_cleanup planar_normalization gap_endpoint structure_region other],
               wf['cards'].map { |c| c['id'] }
end
