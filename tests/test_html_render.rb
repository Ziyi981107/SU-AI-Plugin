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
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/ui_bridge'

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
HR_HTML_INDEX = File.expand_path('../extension/su_ai_plugin/html/index.html', __dir__).freeze
HR_HTML_APPJS = File.expand_path('../extension/su_ai_plugin/html/app.js', __dir__).freeze
HR_HTML_CSS   = File.expand_path('../extension/su_ai_plugin/html/style.css', __dir__).freeze
HR_RUNNER_RB  = File.expand_path('../extension/su_ai_plugin/dialog_runner.rb', __dir__).freeze

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
  # that if-block (not before it). The most precise check:
  # scope the count to renderIssue only (V1.4 working-mode
  # buttons ALSO have addEventListener('click', ...), so the
  # whole-file count is no longer exactly 1; the per-function
  # count inside renderIssue is the L3 invariant).
  render_issue_block = src[/function\s+renderIssue[\s\S]+?\n\s\s}\n/, 0] || src[/function\s+renderIssue[\s\S]+?\n  \}/m, 0]
  if render_issue_block.nil?
    # Fallback for the case where the closing brace shape differs:
    # find the renderIssue function and capture up to the next
    # `function ` or end-of-script.
    start = src.index('function renderIssue')
    raise 'renderIssue not found' if start.nil?
    rest = src[start..-1]
    next_fn = rest.index("\n  function ")
    render_issue_block = next_fn ? rest[0..next_fn] : rest
  end
  ri_click_listeners = render_issue_block.scan(/addEventListener\(['"]click['"]/).length
  assert_equal 1, ri_click_listeners,
               'renderIssue must contain exactly ONE addEventListener("click", ...) call (the locatable one)'

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

# --------------------------------------------------------------------------
# V1.1 (per plan §7.3 / §4.10..§4.12): L4 source-level guards for the
# Layers section. The Ruby-level tests below validate:
#   - index.html has the locked Layers DOM structure.
#   - app.js exports the locked LAYER_ROLE_LABELS (5 canonical) and
#     LAYER_VISIBILITY_LABELS.
#   - app.js exposes ROOT.renderLayers.
#   - app.js uses textContent only for layer row data (no innerHTML).
#   - app.js NEVER adds an addEventListener('click', ...) inside the
#     renderLayerRow / renderLayers path (per L3-mirroring non-actionable
#     pattern, R008).
#   - style.css defines .layer-row + .role-badge + .visibility-badge
#     + .issue-count.has-issues + .layer-row[data-visible="false"].
#   - style.css does NOT define .layer-row[data-role="..."] color
#     selectors (R008 / ChatGPT §11.7).
# --------------------------------------------------------------------------

HR_HTML_INDEX_L4 = HR_HTML_INDEX
HR_HTML_APPJS_L4 = HR_HTML_APPJS
HR_HTML_CSS_L4   = HR_HTML_CSS

test 'html_render (L4): index.html has <details id="layers-section"> with <summary id="layers-summary"> first child' do
  src = File.read(HR_HTML_INDEX_L4)
  assert_match(/<details\s+id="layers-section">/, src,
               'index.html must include <details id="layers-section"> (V1.1 plan §4.11)')
  # The summary must be the FIRST child of the details block.
  # Use a non-greedy lookahead: <details id="layers-section"> followed
  # by whitespace then <summary id="layers-summary">.
  assert_match(/<details\s+id="layers-section">\s*<summary\s+id="layers-summary">/, src,
               'the <summary id="layers-summary"> must be the first child of <details id="layers-section">')
  # The block must contain a <div id="layers-list">.
  assert_match(/<div\s+id="layers-list">/, src,
               '<details id="layers-section"> must contain <div id="layers-list">')
end

test 'html_render (L4): index.html layers-section is rendered closed by default (no open attribute)' do
  src = File.read(HR_HTML_INDEX_L4)
  # The rendered HTML MUST NOT have the `open` attribute on the
  # layers details — the section starts collapsed per ChatGPT §11.5.
  # We assert NO `open` attribute within the layers-section block by
  # extracting the block and scanning it.
  m = src.match(/<details\s+id="layers-section">[^<]*<summary[^>]*>[^<]*<\/summary>[\s\S]*?<\/details>/m)
  refute_nil m, 'failed to extract <details id="layers-section"> block'
  block = m[0]
  refute_match(/\bopen\b/, block,
               '<details id="layers-section"> must NOT carry the `open` attribute (closed by default per ChatGPT §11.5)')
end

test 'html_render (L4): app.js exports LAYER_ROLE_LABELS in canonical order (no OFFSCREEN, R007)' do
  src = File.read(HR_HTML_APPJS_L4)
  assert_match(/ROOT\.LAYER_ROLE_LABELS\s*=\s*LAYER_ROLE_LABELS/, src,
               'app.js must expose ROOT.LAYER_ROLE_LABELS for harness introspection')
  expected_roles = %w[dimension annotation guide construction unknown]
  expected_roles.each do |r|
    assert_match(/['"]#{r}['"]/, src,
                 "LAYER_ROLE_LABELS must include '#{r}' (canonical role label, per R007)")
  end
  # No OFFSCREEN role (R007 removed the symbol).
  refute_match(/['"]offscreen['"]/, src,
               "LAYER_ROLE_LABELS must NOT include 'offscreen' (R007 removed the OFFSCREEN role)")
end

test 'html_render (L4): app.js exports LAYER_VISIBILITY_LABELS with visible/hidden/unknown keys' do
  src = File.read(HR_HTML_APPJS_L4)
  assert_match(/ROOT\.LAYER_VISIBILITY_LABELS\s*=\s*LAYER_VISIBILITY_LABELS/, src,
               'app.js must expose ROOT.LAYER_VISIBILITY_LABELS')
  assert_match(/LAYER_VISIBILITY_LABELS\s*=\s*\{/, src,
               'LAYER_VISIBILITY_LABELS is an object literal')
  assert_match(/visible:\s*['"]Visible['"]/, src,
               'LAYER_VISIBILITY_LABELS.visible is "Visible"')
  assert_match(/hidden:\s*['"]Off-screen['"]/, src,
               'LAYER_VISIBILITY_LABELS.hidden is "Off-screen"')
  assert_match(/unknown:\s*['"]Visibility: unknown['"]/, src,
               'LAYER_VISIBILITY_LABELS.unknown is "Visibility: unknown"')
end

test 'html_render (L4): app.js exposes ROOT.renderLayers (callable surface)' do
  src = File.read(HR_HTML_APPJS_L4)
  assert_match(/ROOT\.renderLayers\s*=\s*renderLayers/, src,
               'app.js must expose ROOT.renderLayers so harness + future callers can invoke the render path')
end

test 'html_render (L4): renderLayers uses textContent only for layer row data (no innerHTML)' do
  src = File.read(HR_HTML_APPJS_L4)
  # Extract the renderLayerRow function body and assert it never
  # assigns to innerHTML for user-supplied strings. The locked
  # contract from Stage 6 extends to V1.1.
  m = src.match(/function\s+renderLayerRow\s*\([^)]*\)\s*\{[\s\S]*?\n\s*\}/m)
  refute_nil m, 'failed to extract renderLayerRow function body'
  body = m[0]
  # No innerHTML = ... assignment in the function body.
  refute_match(/\.innerHTML\s*=/, body,
               'renderLayerRow must not assign .innerHTML for user strings (locked contract)')
  # textContent IS the only DOM-mutation API used for user strings.
  assert_match(/\.textContent\s*=/, body,
               'renderLayerRow must use .textContent for user strings (locked contract)')
end

test 'html_render (L4): renderLayers / renderLayerRow do NOT register a click handler (mirrors L3)' do
  # Per plan §4.10: "The row has `cursor: default` and NO click
  # handler (mirrors V1.0 L3 non-locatable warning pattern)."
  # We assert there is NO addEventListener('click', ...) inside
  # the renderLayerRow body (the rest of app.js has ONE addEventListener
  # for locatable issue rows; that one is in renderIssue).
  src = File.read(HR_HTML_APPJS_L4)
  m = src.match(/function\s+renderLayerRow\s*\([^)]*\)\s*\{[\s\S]*?\n\s*\}/m)
  refute_nil m, 'failed to extract renderLayerRow function body'
  body = m[0]
  refute_match(/addEventListener\s*\(\s*['"]click['"]/, body,
               'renderLayerRow must NOT register a click listener (layer rows are intentionally non-actionable)')
end

test 'html_render (L4): style.css defines .layer-row + role-badge + visibility-badge + has-issues emphasis' do
  src = File.read(HR_HTML_CSS_L4)
  assert_match(/\.layer-row\s*\{/, src,
               'style.css must define .layer-row (V1.1 plan §4.12)')
  assert_match(/\.layer-row\s+\.role-badge/, src,
               'style.css must define .layer-row .role-badge for the locked neutral role badge')
  assert_match(/\.layer-row\s+\.visibility-badge/, src,
               'style.css must define .layer-row .visibility-badge for the separate visibility badge')
  assert_match(/\.layer-row\s+\.issue-count\.has-issues/, src,
               'style.css must define .layer-row .issue-count.has-issues for the locked issue-count emphasis')
  # Per Owner Gate 2 V1.1 NIT: explicit visible separator between
  # the edge count and the issue count. Must be a real CSS rule.
  assert_match(/\.layer-row\s+\.layer-count-sep/, src,
               'style.css must define .layer-row .layer-count-sep for the visible separator')
  # The muted style for hidden layers (data-visible="false"). This
  # is the ONLY data-attribute-driven style on layer rows.
  assert_match(/\.layer-row\[data-visible="false"\]/, src,
               'style.css must define the muted style for hidden layers via [data-visible="false"]')
  assert_match(/opacity:\s*0\.6/, src,
               'the muted style uses opacity: 0.6 (per ChatGPT §11.2)')
  # The row has cursor: default (no click affordance).
  assert_match(/\.layer-row\s*\{[^}]*cursor:\s*default/m, src,
               '.layer-row must set cursor: default (mirrors V1.0 L3 non-actionable pattern)')
end

test 'html_render (L4): style.css does NOT use data-role="..." color selectors (R008)' do
  # Per ChatGPT §11.7 / R008: the locked neutral style MUST NOT
  # color rows by data-role. The only data-attribute-driven style
  # allowed is [data-visible="false"] (for muted hidden layers).
  # We scan ONLY the .layer-row CSS rule bodies (NOT any
  # preceding block comments) and assert NO `data-role="..."`
  # selector appears inside any of them.
  src = File.read(HR_HTML_CSS_L4)
  # Strip block comments first so the regex scan below does not
  # pick up comments like "...NO data-role=..." that quote the
  # forbidden pattern intentionally.
  stripped = src.gsub(/\/\*[\s\S]*?\*\//m, '')
  blocks = stripped.scan(/[^{}]*\.layer-row[^{}]*\{[^}]*\}/m)
  assert blocks.length > 0, 'failed to extract any .layer-row CSS block'
  blocks.each do |b|
    refute_match(/data-role\s*=/, b,
                 ".layer-row CSS block must NOT use a [data-role=\"...\"] selector (R008): #{b.inspect}")
  end
end

# --- V1.2 (per directive 026): "Issues by Layer" source-level guards ---

HR_HTML_INDEX_V12 = HR_HTML_INDEX
HR_HTML_APPJS_V12 = HR_HTML_APPJS

test 'html_render (V1.2): index.html has <details id="layer-issues-section"> with <summary id="layer-issues-summary"> first child' do
  src = File.read(HR_HTML_INDEX_V12)
  assert_match(/<details\s+id="layer-issues-section">/, src,
               'index.html must include <details id="layer-issues-section"> (V1.2 directive 026)')
  # Summary must be the FIRST child of the details block.
  assert_match(/<details\s+id="layer-issues-section">\s*<summary\s+id="layer-issues-summary">/, src,
               'the <summary id="layer-issues-summary"> must be the first child of <details id="layer-issues-section">')
  # Must contain <div id="layer-issues-list">.
  assert_match(/<div\s+id="layer-issues-list">/, src,
               '<details id="layer-issues-section"> must contain <div id="layer-issues-list">')
end

test 'html_render (V1.2): layer-issues-section is rendered closed by default (no open attribute)' do
  src = File.read(HR_HTML_INDEX_V12)
  m = src.match(/<details\s+id="layer-issues-section">[^<]*<summary[^>]*>[^<]*<\/summary>[\s\S]*?<\/details>/m)
  refute_nil m, 'failed to extract <details id="layer-issues-section"> block'
  block = m[0]
  refute_match(/\bopen\b/, block,
               '<details id="layer-issues-section"> must NOT carry the `open` attribute (closed by default per directive 026)')
end

test 'html_render (V1.2): layer-issues-section is positioned AFTER groups and BEFORE layers-section' do
  src = File.read(HR_HTML_INDEX_V12)
  pos_groups = src.index('id="groups"')
  pos_li     = src.index('id="layer-issues-section"')
  pos_layers = src.index('id="layers-section"')
  refute_nil pos_groups, '#groups element must exist'
  refute_nil pos_li,     '#layer-issues-section element must exist'
  refute_nil pos_layers, '#layers-section element must exist'
  assert pos_groups < pos_li,
         '#layer-issues-section must come AFTER #groups'
  assert pos_li < pos_layers,
         '#layer-issues-section must come BEFORE #layers-section (per directive 026 placement)'
end

test 'html_render (V1.2): app.js exposes renderLayerIssues + renderLayerIssueBucket on ROOT' do
  src = File.read(HR_HTML_APPJS_V12)
  assert_match(/function\s+renderLayerIssues\s*\(/, src,
               'app.js must define renderLayerIssues function')
  assert_match(/function\s+renderLayerIssueBucket\s*\(/, src,
               'app.js must define renderLayerIssueBucket function')
  assert_match(/ROOT\.renderLayerIssues\s*=\s*renderLayerIssues/, src,
               'app.js must expose ROOT.renderLayerIssues for harness + future callers')
  assert_match(/ROOT\.renderLayerIssueBucket\s*=\s*renderLayerIssueBucket/, src,
               'app.js must expose ROOT.renderLayerIssueBucket')
end

test 'html_render (V1.2): renderLayerIssueBucket uses textContent only (no innerHTML)' do
  src = File.read(HR_HTML_APPJS_V12)
  m = src.match(/function\s+renderLayerIssueBucket\s*\([^)]*\)\s*\{[\s\S]*?\n\s*\}/m)
  refute_nil m, 'failed to extract renderLayerIssueBucket function body'
  body = m[0]
  refute_match(/\.innerHTML\s*=/, body,
               'renderLayerIssueBucket must not assign .innerHTML for user strings (locked contract)')
  assert_match(/\.textContent\s*=/, body,
               'renderLayerIssueBucket must use .textContent for user strings (locked contract)')
end

test 'html_render (V1.2): renderLayerIssueBucket does NOT register a click handler (per-bucket is a navigation aid, not an action)' do
  src = File.read(HR_HTML_APPJS_V12)
  m = src.match(/function\s+renderLayerIssueBucket\s*\([^)]*\)\s*\{[\s\S]*?\n\s*\}/m)
  refute_nil m, 'failed to extract renderLayerIssueBucket function body'
  body = m[0]
  refute_match(/addEventListener\s*\(\s*['"]click['"]/, body,
               'renderLayerIssueBucket must NOT register a click listener on the bucket container (issues inside carry the locate click handler)')
end

test 'html_render (V1.2): style.css defines .layer-issue-bucket style (neutral, no new role colors)' do
  src = File.read(HR_HTML_CSS_L4)
  assert_match(/\.layer-issue-bucket/, src,
               'style.css must define .layer-issue-bucket (V1.2 directive 026)')
  # Per locked contract item 11: no new role colors. We assert no
  # role-color selectors were introduced under .layer-issue-bucket.
  stripped = src.gsub(/\/\*[\s\S]*?\*\//m, '')
  blocks = stripped.scan(/[^{}]*\.layer-issue-bucket[^{}]*\{[^}]*\}/m)
  assert blocks.length > 0, 'failed to extract any .layer-issue-bucket CSS block'
  blocks.each do |b|
    refute_match(/data-role\s*=/, b,
                 ".layer-issue-bucket CSS block must NOT use a [data-role=\"...\"] color selector (R008 / directive 026 item 11): #{b.inspect}")
  end
end

test 'html_render (V1.2): app.js render() invokes renderLayerIssues AFTER groups but BEFORE renderLayers' do
  src = File.read(HR_HTML_APPJS_V12)
  pos_groups      = src.index('renderLayers(payload.layerGroups)')
  pos_layerissues = src.index('renderLayerIssues(payload.layerIssueGroups)')
  refute_nil pos_groups, 'render() must invoke renderLayers(payload.layerGroups)'
  refute_nil pos_layerissues, 'render() must invoke renderLayerIssues(payload.layerIssueGroups)'
  assert pos_groups < pos_layerissues,
         'renderLayerIssues must come AFTER renderLayers (the per-issue-type groups render); directive 026 says "after groups, before layers" — but the layers-section is rendered separately, so position is between renderLayers-call and end of render()'
end

# --- V1.3 (per directive 027): "Face Inventory" source-level guards ---

HR_HTML_INDEX_V13 = HR_HTML_INDEX
HR_HTML_APPJS_V13 = HR_HTML_APPJS
HR_HTML_CSS_V13   = HR_HTML_CSS

test 'html_render (V1.3): index.html has <details id="face-inventory-section"> with <summary id="face-inventory-summary"> first child' do
  src = File.read(HR_HTML_INDEX_V13)
  assert_match(/<details\s+id="face-inventory-section">/, src,
               'index.html must include <details id="face-inventory-section"> (V1.3 directive 027)')
  assert_match(/<details\s+id="face-inventory-section">\s*<summary\s+id="face-inventory-summary">/, src,
               'the <summary id="face-inventory-summary"> must be the first child of <details id="face-inventory-section">')
  assert_match(/<div\s+id="face-inventory-list">/, src,
               '<details id="face-inventory-section"> must contain <div id="face-inventory-list">')
end

test 'html_render (V1.3): face-inventory-section is rendered closed by default (no open attribute)' do
  src = File.read(HR_HTML_INDEX_V13)
  m = src.match(/<details\s+id="face-inventory-section">[^<]*<summary[^>]*>[^<]*<\/summary>[\s\S]*?<\/details>/m)
  refute_nil m, 'failed to extract <details id="face-inventory-section"> block'
  block = m[0]
  refute_match(/\bopen\b/, block,
               '<details id="face-inventory-section"> must NOT carry the `open` attribute (closed by default per directive 027)')
end

test 'html_render (V1.3): face-inventory-section is positioned AFTER layers-section' do
  src = File.read(HR_HTML_INDEX_V13)
  pos_layers = src.index('id="layers-section"')
  pos_fi     = src.index('id="face-inventory-section"')
  refute_nil pos_layers, '#layers-section element must exist'
  refute_nil pos_fi,     '#face-inventory-section element must exist'
  assert pos_layers < pos_fi,
         '#face-inventory-section must come AFTER #layers-section (per directive 027 item 2)'
end

test 'html_render (V1.3): app.js exposes renderFaceInventory + renderFaceInventoryRow on ROOT' do
  src = File.read(HR_HTML_APPJS_V13)
  assert_match(/function\s+renderFaceInventory\s*\(/, src,
               'app.js must define renderFaceInventory function')
  assert_match(/function\s+renderFaceInventoryRow\s*\(/, src,
               'app.js must define renderFaceInventoryRow function')
  assert_match(/ROOT\.renderFaceInventory\s*=\s*renderFaceInventory/, src,
               'app.js must expose ROOT.renderFaceInventory for harness + future callers')
  assert_match(/ROOT\.renderFaceInventoryRow\s*=\s*renderFaceInventoryRow/, src,
               'app.js must expose ROOT.renderFaceInventoryRow')
end

test 'html_render (V1.3): renderFaceInventoryRow uses textContent only (no innerHTML)' do
  src = File.read(HR_HTML_APPJS_V13)
  m = src.match(/function\s+renderFaceInventoryRow\s*\([^)]*\)\s*\{[\s\S]*?\n\s*\}/m)
  refute_nil m, 'failed to extract renderFaceInventoryRow function body'
  body = m[0]
  refute_match(/\.innerHTML\s*=/, body,
               'renderFaceInventoryRow must not assign .innerHTML for user strings (locked contract)')
  assert_match(/\.textContent\s*=/, body,
               'renderFaceInventoryRow must use .textContent for user strings (locked contract)')
end

test 'html_render (V1.3): renderFaceInventoryRow does NOT register a click handler (rows are non-actionable)' do
  src = File.read(HR_HTML_APPJS_V13)
  m = src.match(/function\s+renderFaceInventoryRow\s*\([^)]*\)\s*\{[\s\S]*?\n\s*\}/m)
  refute_nil m, 'failed to extract renderFaceInventoryRow function body'
  body = m[0]
  refute_match(/addEventListener\s*\(\s*['"]click['"]/, body,
               'renderFaceInventoryRow must NOT register a click listener (rows are non-actionable per directive 027 item 7)')
end

test 'html_render (V1.3): style.css defines .face-inventory-row style (neutral, no new role colors)' do
  src = File.read(HR_HTML_CSS_V13)
  assert_match(/\.face-inventory-row/, src,
               'style.css must define .face-inventory-row (V1.3 directive 027)')
  stripped = src.gsub(/\/\*[\s\S]*?\*\//m, '')
  blocks = stripped.scan(/[^{}]*\.face-inventory-row[^{}]*\{[^}]*\}/m)
  assert blocks.length > 0, 'failed to extract any .face-inventory-row CSS block'
  blocks.each do |b|
    refute_match(/data-role\s*=/, b,
                 ".face-inventory-row CSS block must NOT use a [data-role=\"...\"] color selector (R008 / directive 027 item 11): #{b.inspect}")
  end
end

test 'html_render (V1.3 NIT-001): style.css adds margin-left fallback for face-inventory-row children (no flex-gap reliance)' do
  # Per Owner Gate 2 V1.3 NIT (V13-NIT-001): the real SU2020
  # HtmlDialog WebKit does not always honor the CSS `gap`
  # property on flex containers, so the row parts render
  # visually concatenated ("ConstructionVisible1 face...").
  # The minimum CSS fix: a `.face-inventory-row > * + *`
  # selector that adds margin-left to every child except the
  # first, mirroring the gap behavior in any webview.
  src = File.read(HR_HTML_CSS_V13)
  assert_match(/\.face-inventory-row\s*>\s*\*\s*\+\s*\*/, src,
               'style.css must define .face-inventory-row > * + * spacing fallback (V13-NIT-001)')
end

test 'html_render (V1.3): app.js render() invokes renderFaceInventory AFTER renderLayers' do
  src = File.read(HR_HTML_APPJS_V13)
  pos_layers = src.index('renderLayers(payload.layerGroups)')
  pos_fi     = src.index('renderFaceInventory(payload.faceInventoryGroups)')
  refute_nil pos_layers, 'render() must invoke renderLayers(payload.layerGroups)'
  refute_nil pos_fi,     'render() must invoke renderFaceInventory(payload.faceInventoryGroups)'
  assert pos_layers < pos_fi,
         'renderFaceInventory must come AFTER renderLayers (per directive 027 item 2)'
end

test 'html_render (V1.3): app.js render() summary block includes faces + faces_with_holes scalars' do
  src = File.read(HR_HTML_APPJS_V13)
  scalar_match = src.match(/scalarKeys\s*=\s*\[([^\]]+)\]/)
  refute_nil scalar_match, 'render() must define scalarKeys Array'
  list = scalar_match[1]
  assert list.include?("'faces'"),            "scalarKeys must include 'faces'"
  assert list.include?("'faces_with_holes'"), "scalarKeys must include 'faces_with_holes'"
end

# --------------------------------------------------------------------------
# CodeX 030 PRE-BUILD TECHNICAL PREVIEW V1.4 Stage 4: the dialog's
# "Working Mode" section. Per directive 030:
#   - Enter working mode by clicking "Prepare".
#   - Discard / Rebuild operate only on the runner-owned workspace.
#   - Source CAD is NEVER touched.
#   - Action buttons wire to window.SUAIP callbacks (no eval).
#   - User-facing text via textContent only (no innerHTML).
# --------------------------------------------------------------------------

HR_HTML_INDEX_V14 = HR_HTML_INDEX
HR_HTML_APPJS_V14 = HR_HTML_APPJS
HR_HTML_CSS_V14   = HR_HTML_CSS
HR_RUNNER_RB_V14  = HR_RUNNER_RB
HR_UIBRIDGE_RB_V14 = File.expand_path('../extension/su_ai_plugin/ui_bridge.rb', __dir__).freeze

test 'html_render (V1.4): index.html has <details id="working-mode-section"> with <summary id="working-mode-summary"> first child' do
  src = File.read(HR_HTML_INDEX_V14)
  m = src.match(/<details\s+id="working-mode-section">[^<]*<summary[^>]*id="working-mode-summary"[^>]*>[^<]*<\/summary>/m)
  refute_nil m,
           'index.html must define <details id="working-mode-section"> with <summary id="working-mode-summary"> as first child (per directive 030 Stage 4)'
end

test 'html_render (V1.4): working-mode-section is rendered closed by default (no open attribute)' do
  src = File.read(HR_HTML_INDEX_V14)
  m = src.match(/<details\s+id="working-mode-section">[^<]*<summary[^>]*>[^<]*<\/summary>[\s\S]*?<\/details>/m)
  refute_nil m, 'failed to extract <details id="working-mode-section"> block'
  block = m[0]
  refute_match(/\bopen\b/, block,
               '<details id="working-mode-section"> must NOT carry the `open` attribute (closed by default per directive 030 Stage 4)')
end

test 'html_render (V1.4): working-mode-section is positioned AFTER face-inventory-section' do
  src = File.read(HR_HTML_INDEX_V14)
  pos_fi  = src.index('id="face-inventory-section"')
  pos_wm  = src.index('id="working-mode-section"')
  refute_nil pos_fi, '#face-inventory-section element must exist'
  refute_nil pos_wm, '#working-mode-section element must exist'
  assert pos_fi < pos_wm,
         '#working-mode-section must come AFTER #face-inventory-section (per directive 030 Stage 4)'
end

test 'html_render (V1.4): app.js exposes renderWorkingMode on ROOT' do
  src = File.read(HR_HTML_APPJS_V14)
  assert_match(/function\s+renderWorkingMode\s*\(/, src,
               'app.js must define renderWorkingMode function')
  assert_match(/ROOT\.renderWorkingMode\s*=\s*renderWorkingMode/, src,
               'app.js must expose ROOT.renderWorkingMode for harness + future callers')
end

test 'html_render (V1.4): renderWorkingMode uses textContent only (no innerHTML for user strings)' do
  src = File.read(HR_HTML_APPJS_V14)
  m = src.match(/function\s+renderWorkingMode\s*\([^)]*\)\s*\{[\s\S]*?\n\s\s}\n/m)
  if m.nil?
    # Fallback: find the function and capture up to the next `function ` or end-of-script.
    start = src.index('function renderWorkingMode')
    refute_nil start, 'renderWorkingMode function not found'
    rest = src[start..-1]
    next_fn = rest.index("\n  function ")
    body = next_fn ? rest[0..next_fn] : rest
  else
    body = m[0]
  end
  refute_match(/\.innerHTML\s*=/, body,
               'renderWorkingMode must NOT assign .innerHTML for user strings (locked contract)')
  assert_match(/\.textContent\s*=/, body,
               'renderWorkingMode must use .textContent for user strings (locked contract)')
end

test 'html_render (V1.4): renderWorkingMode helper (addAction) locates callback via brackets, NOT eval' do
  src = File.read(HR_HTML_APPJS_V14)
  # Per the locked no-eval contract, the click handler must look up
  # the callback on window.SUAIP via bracket notation (root[callback]),
  # NOT via eval(...).
  assert_match(/var\s+fn\s*=\s*root\[callback\]/, src,
               'renderWorkingMode action click handler must use root[callback] lookup (no eval)')
  refute_match(/eval\s*\(\s*['"`]?\s*(?:root|window)/, src,
               'renderWorkingMode must NOT eval the callback string')
end

test 'html_render (V1.4): style.css defines .working-mode-row + .working-mode-actions neutral styles' do
  src = File.read(HR_HTML_CSS_V14)
  assert_match(/\.working-mode-row/, src,
               'style.css must define .working-mode-row (V1.4 directive 030 Stage 4)')
  assert_match(/\.working-mode-actions/, src,
               'style.css must define .working-mode-actions (V1.4 directive 030 Stage 4)')
  # Strip comments to find the actual blocks.
  stripped = src.gsub(/\/\*[\s\S]*?\*\//m, '')
  blocks = stripped.scan(/[^{}]*\.working-mode-row[^{}]*\{[^}]*\}/m)
  assert blocks.length > 0, 'failed to extract any .working-mode-row CSS block'
  blocks.each do |b|
    refute_match(/data-role\s*=/, b,
                 ".working-mode-row CSS block must NOT use a [data-role=\"...\"] color selector (R008): #{b.inspect}")
    # No new color selectors for data-state (per directive 030 Stage 4
    # 'no new role / state color selectors'). The neutral var(--*)
    # variables (--text, --muted, --border) are EXISTING palette
    # tokens, not new colors. NEW colors are hex/rgb/named values
    # OR new --* variables introduced in this rule block.
    if b =~ /\[data-state=/
      # Reject any hard-coded color literal in a [data-state=...] block.
      %w[# rgb rgba hsl hsla].each do |prefix|
        if b =~ /(?:color|background|background-color|border-color)\s*:\s*#{Regexp.escape(prefix)}/i
          flunk(".working-mode-row [data-state=...] block must NOT use a literal #{prefix} color (no new state colors): #{b.inspect}")
        end
      end
    end
  end
end

test 'html_render (V1.4): dialog_runner wires the 3 working-mode callbacks as BLOCKs (not method(:name))' do
  src = File.read(HR_RUNNER_RB_V14)
  %w[prepare_workspace discard_workspace rebuild_workspace].each do |cb|
    assert_match(/add_action_callback\s*\(\s*['"]#{cb}['"]\s*\)\s+do/, src,
                 "dialog_runner.rb must register '#{cb}' as a BLOCK callback (do/end), per the locked contract")
    # No method(:...) form for these.
    refute_match(/add_action_callback\s*\(\s*['"]#{cb}['"]\s*,\s*method/, src,
                 "dialog_runner.rb must NOT register '#{cb}' as a method(:...) callback")
  end
end

test 'html_render (V1.4): ui_bridge exposes derivedWorkspace top-level key (String-typed)' do
  require_relative '../extension/su_ai_plugin/core/working_mode_runner'
  # The UIBridge payload must include 'derivedWorkspace' (String key)
  # sourced from WorkingModeRunner.snapshot.
  result = hr_make_result
  payload = UIBridge.as_html_data(result)
  assert payload.key?('derivedWorkspace'),
         "UIBridge.as_html_data payload must include 'derivedWorkspace' top-level key (V1.4 directive 030 Stage 4)"
  assert_kind_of Hash, payload['derivedWorkspace']
  assert payload['derivedWorkspace'].key?('state'),
         "payload['derivedWorkspace'] must be a Hash with a 'state' key (per WorkingModeRunner.snapshot shape)"
  assert_kind_of String, payload['derivedWorkspace']['state']
end

test 'html_render (V1.4): UIBridge.to_json round-trips derivedWorkspace (JSON-safe)' do
  require_relative '../extension/su_ai_plugin/core/working_mode_runner'
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  result = hr_make_result
  payload = UIBridge.as_html_data(result)
  require 'json'
  json = JSON.generate(payload)
  parsed = JSON.parse(json)
  assert parsed.key?('derivedWorkspace'), 'derivedWorkspace must survive JSON round-trip'
  assert parsed['derivedWorkspace']['state'] == 'none',
         "derivedWorkspace.state must be 'none' on a fresh runner (round-trip)"
end
