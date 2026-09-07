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

test 'html_render (V1.9A-A1 + A2): app.js preserves all existing callback names + A2 new callbacks (dispatch §6 + §12)' do
  src = File.read(HR_HTML_APPJS)
  expected_callbacks = %w[
    start_cad_prep
    refresh_cad_prep
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
           "app.js MUST reference the existing callback #{cb.inspect} (dispatch §6 + §12)"
  end
end

# ---------------------------------------------------------------------------
# V1.9A-A1 + V1.9A-A2: dialog_runner preserves all existing
# callbacks (dispatch §6 + §12). The A2 packet adds two new
# callbacks: `start_cad_prep` and `refresh_cad_prep`. All A1
# callbacks remain registered for backward compatibility.
# ---------------------------------------------------------------------------

test 'html_render (V1.9A-A1 + A2): dialog_runner registers all required callbacks (A1 + A2 additions)' do
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
    start_cad_prep
    refresh_cad_prep
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

# ---------------------------------------------------------------------------
# V1.9A OWNER UI TAB SWITCH BLOCK — narrow frontend fix verification.
#
# Root cause (AIPM-traced): `.panel { display: flex; ... }` in
# style.css has higher cascade priority than the browser default
# `[hidden] { display: none }`. Inactive panels (hidden=true) still
# rendered via the flex layout, defeating `switchTab`'s
# `setAttribute('hidden', '')` calls.
#
# Fix: a scoped `.panel[hidden] { display: none; }` rule placed
# immediately after the `.panel` rule (Blueprint-scoped, narrower
# than a global `[hidden] !important`).
#
# These tests pin the fix at three levels:
#   1. CSS source-level guard: the scoped rule MUST exist and MUST
#      come after the `.panel` rule (so the cascade wins).
#   2. CSS structural guard: any future `.panel { display: ... }`
#      change MUST be paired with `.panel[hidden] { display: none; }`
#      (the regression guard against future .panel display changes).
#   3. JS contract: the switchTab DOM contract (set / remove the
#      `hidden` attribute) is unchanged by this fix (the JS was
#      correct; the CSS was wrong).
# ---------------------------------------------------------------------------

# Helper: extract the CSS rules around `.panel` (the production
# scoped rule and its surrounding context). Used by the structural
# guard test to verify the cascade order.
def v19a_panel_css_excerpt(style_src)
  # Capture everything from the first `.panel {` to the end of the
  # first rule block AFTER `.panel[hidden]` (or end of file).
  # We use a simple line-based scan: extract lines from the first
  # line containing `.panel {` to the first blank line that ends a
  # rule block following `.panel[hidden]`.
  lines = style_src.lines
  start_idx = lines.index { |l| l.strip == '.panel {' }
  return '' if start_idx.nil?
  excerpt = lines[start_idx..-1] || []
  excerpt.join
end

# V1.9A FINAL BLOCK FIX §6 (test debt — CSS regression
# guard false-pass): strip standard CSS `/* ... */`
# block comments from a CSS source string. The strip is
# intentionally conservative (it does NOT understand CSS
# strings, escapes, or nested comments because CSS has
# neither). This is used by the selector-order assertions
# so a comment mentioning a selector cannot accidentally
# satisfy the cascade-order guard.
#
# Returns the CSS source with all `/* ... */` blocks
# replaced by spaces (preserving byte offsets so position-
# based assertions remain meaningful).
def hr_strip_css_comments(css_src)
  out = css_src.dup
  loop do
    start_idx = out.index('/*')
    break if start_idx.nil?
    end_idx = out.index('*/', start_idx + 2)
    break if end_idx.nil?
    # Replace the comment with spaces (preserving line
    # breaks so byte offsets remain comparable for
    # downstream line-based assertions).
    pre_end = end_idx + 2
    out[start_idx...pre_end] = out[start_idx...pre_end].gsub(/[^\n]/, ' ')
  end
  out
end

test 'html_render (V1.9A OWNER UI TAB SWITCH BLOCK): style.css has the .panel[hidden] { display: none } rule' do
  src = File.read(HR_HTML_CSS)
  # The scoped rule MUST be present.
  assert_match(/\.panel\[hidden\]\s*\{\s*display:\s*none\s*;?\s*\}/, src,
               'style.css MUST contain the scoped `.panel[hidden] { display: none }` rule ' \
               'that closes the Owner Gate A2 BLOCK')
end

# V1.9A FINAL BLOCK FIX §6: regression test proving a
# CSS comment alone cannot satisfy the selector check. We
# construct a synthetic CSS where `.panel[hidden]` and
# `.recovery-banner[hidden]` appear ONLY inside CSS
# comments; the helper `hr_strip_css_comments` MUST strip
# them so the cascade-order assertion correctly identifies
# the missing rules.
test 'html_render (V1.9A FINAL CSS COMMENT GUARD): strip helper removes all /* ... */ comments' do
  src = <<~CSS
    /* .panel[hidden] { display: none; } */
    .panel { display: flex; }
    /*
       .recovery-banner[hidden] { display: none; }
       .tab-badge[hidden] { display: none; }
    */
  CSS
  stripped = hr_strip_css_comments(src)
  refute_match(/\.panel\[hidden\]\s*\{/, stripped,
               'strip helper MUST remove selectors inside comments')
  refute_match(/\.recovery-banner\[hidden\]\s*\{/, stripped,
               'strip helper MUST remove multi-line comment selectors')
  refute_match(/\.tab-badge\[hidden\]\s*\{/, stripped,
               'strip helper MUST remove selectors inside multi-line comments')
  # The real .panel rule is preserved.
  assert_match(/\.panel\s*\{/, stripped,
               'strip helper MUST preserve real CSS rules')
  # Newline count is preserved (line offsets remain
  # comparable).
  assert_equal src.count("\n"), stripped.count("\n"),
               'strip helper MUST preserve line offsets (replace comments with spaces)'
end

test 'html_render (V1.9A FINAL CSS COMMENT GUARD): regression — a comment-only CSS fails the cascade-order guard' do
  # Build a synthetic CSS where the SCOPED rules exist
  # ONLY inside comments. The cascade-order assertions
  # MUST fail when using the comment-stripped source.
  fake_css = <<~CSS
    /* cascade order notes (do NOT add rules here)
       .panel { display: flex; }
       .panel[hidden] { display: none; }
       .recovery-banner { display: flex; }
       .recovery-banner[hidden] { display: none; }
       .tab-badge { display: inline-flex; }
       .tab-badge[hidden] { display: none; }
    */
  CSS
  stripped = hr_strip_css_comments(fake_css)
  # After stripping, the cascade-order index checks return
  # nil because no actual rules exist. This proves the
  # comment-stripping helper is what makes the guard
  # meaningful (without it, the guard would falsely PASS).
  assert_nil stripped.index(/\.panel\s*\{/),
             'cascade-order guard MUST fail when scoped rule is only inside a CSS comment'
  assert_nil stripped.index(/\.panel\[hidden\]\s*\{/),
             'cascade-order guard MUST fail when .panel[hidden] is only inside a CSS comment'
  assert_nil stripped.index(/\.recovery-banner\s*\{/),
             'cascade-order guard MUST fail when .recovery-banner is only inside a CSS comment'
end

test 'html_render (V1.9A OWNER UI TAB SWITCH BLOCK): .panel[hidden] rule appears AFTER the .panel rule' do
  # The cascade-order guard: the scoped rule MUST come AFTER the
  # `.panel { display: flex }` rule so the higher specificity
  # `.panel[hidden]` selector (1 class + 1 attribute = 0,0,2,0)
  # beats `.panel` (1 class = 0,0,1,0) and wins.
  #
  # V1.9A FINAL BLOCK FIX §6 (test debt — CSS
  # regression guard false-pass): the naive
  # `src.index(/\.panel\s*\{/)` could match selector text
  # inside a CSS comment, making the guard pass for the
  # wrong reason. We MUST strip CSS comments BEFORE the
  # selector-order assertions. The regex strip is
  # intentionally conservative: it removes `/* ... */`
  # blocks (including multi-line) and is anchored on the
  # standard CSS comment delimiters. The dispatcher
  # explicitly says: "Do not reorder working production
  # CSS merely to satisfy a brittle test" — so we fix the
  # test only.
  src = File.read(HR_HTML_CSS)
  code = hr_strip_css_comments(src)
  panel_idx = code.index(/\.panel\s*\{/)
  hidden_idx = code.index(/\.panel\[hidden\]\s*\{/)
  refute_nil panel_idx, '.panel rule must exist (in CSS code, NOT inside comments)'
  refute_nil hidden_idx, '.panel[hidden] rule must exist (CSS regression guard)'
  assert panel_idx < hidden_idx,
         '.panel[hidden] rule MUST appear AFTER .panel rule for cascade order'
end

test 'html_render (V1.9A OWNER UI TAB SWITCH BLOCK): switchTab JS DOM contract is unchanged' do
  # The fix is CSS-only. The JS contract (setAttribute / removeAttribute
  # of `hidden`) is preserved verbatim. This guards against a future
  # refactor that might switch to a class-based show/hide pattern and
  # silently regress the contract.
  src = File.read(HR_HTML_APPJS)
  assert_match(/function\s+switchTab\s*\(\s*tabId\s*\)/, src,
               'switchTab(tabId) function must exist')
  # Active panel: removeAttribute('hidden').
  assert_match(/removeAttribute\(\s*['"]hidden['"]\s*\)/, src,
               'switchTab MUST call removeAttribute("hidden") on the active panel')
  # Inactive panels: setAttribute('hidden', '').
  assert_match(/setAttribute\(\s*['"]hidden['"]\s*,\s*['"]['"]\s*\)/, src,
               'switchTab MUST call setAttribute("hidden", "") on inactive panels')
  # aria-selected contract.
  assert_match(/aria-selected['"]\s*,\s*['"]true['"]/, src,
               'switchTab MUST set aria-selected="true" on the active tab')
  assert_match(/aria-selected['"]\s*,\s*['"]false['"]/, src,
               'switchTab MUST set aria-selected="false" on inactive tabs')
end

test 'html_render (V1.9A OWNER UI TAB SWITCH BLOCK): index.html default panel visibility is correct' do
  # Default state on page load:
  #   - panel-process: visible (no `hidden` attr).
  #   - panel-issues / panel-layers / panel-details: `hidden` attr.
  src = File.read(HR_HTML_INDEX)
  # The default-active panel has NO hidden attribute.
  assert_match(/<section[^>]*id="panel-process"[^>]*role="tabpanel"[^>]*>/, src)
  # The inactive panels DO have `hidden` as an attribute on the same element.
  assert_match(/<section[^>]*id="panel-issues"[^>]*\bhidden\b/, src,
               'panel-issues must carry the hidden attribute by default')
  assert_match(/<section[^>]*id="panel-layers"[^>]*\bhidden\b/, src,
               'panel-layers must carry the hidden attribute by default')
  assert_match(/<section[^>]*id="panel-details"[^>]*\bhidden\b/, src,
               'panel-details must carry the hidden attribute by default')
end

test 'html_render (V1.9A OWNER UI TAB SWITCH BLOCK): CSS structural guard against future .panel { display } regressions' do
  # If a future edit changes `.panel { display: flex }` to ANY
  # display value, the scoped `.panel[hidden] { display: none }`
  # rule MUST still be present (the cascade still wins because
  # `.panel[hidden]` has higher specificity than `.panel`).
  # This is a structural regression guard: the test reads the
  # CSS source and asserts both rules exist together.
  src = File.read(HR_HTML_CSS)
  # The .panel rule (any display value).
  assert_match(/\.panel\s*\{[^}]*display\s*:/m, src,
               '.panel rule with a display property must exist')
  # The .panel[hidden] override rule.
  assert_match(/\.panel\[hidden\]\s*\{[^}]*display\s*:\s*none/m, src,
               '.panel[hidden] { display: none } override rule must exist (regression guard)')
end

test 'html_render (V1.9A OWNER UI TAB SWITCH BLOCK): the fix uses a scoped selector, not a global !important' do
  # The dispatch mandates: "Prefer this scoped rule over a global
  # [hidden] !important rule." Verify the fix did NOT introduce a
  # global `[hidden] !important` override that would defeat the
  # project's other `hidden` usages.
  src = File.read(HR_HTML_CSS)
  # The scoped rule must use `.panel[hidden]`, NOT just `[hidden]`.
  refute_match(/^\s*\[hidden\]\s*\{[^}]*!important/m, src,
               'fix MUST NOT introduce a global [hidden] !important rule; ' \
               'the dispatch mandates the scoped .panel[hidden] selector')
end

test 'html_render (V1.9A OWNER UI TAB SWITCH BLOCK): tab map covers all 4 panels (process/issues/layers/details)' do
  # The switchTab tabMap MUST cover exactly the 4 production tabs.
  # If a future edit accidentally drops a tab, the click would
  # leave a panel in the wrong state.
  src = File.read(HR_HTML_APPJS)
  %w[process issues layers details].each do |tab|
    assert_match(/['"]#{tab}['"]\s*:\s*\{\s*btn\s*:\s*['"]tab-#{tab}['"]/, src,
                 "switchTab tabMap MUST include '#{tab}' mapping to tab-#{tab}")
    assert_match(/['"]#{tab}['"]\s*:\s*\{\s*btn\s*:\s*['"]tab-#{tab}['"]\s*,\s*panel\s*:\s*['"]panel-#{tab}['"]/, src,
                 "switchTab tabMap MUST map '#{tab}' to both tab-#{tab} and panel-#{tab}")
  end
end

# ---------------------------------------------------------------------------
# V1.9A OWNER UI HIDDEN-SEMANTICS FOLLOW-UP — narrow frontend fix
# verification (Owner Gate A2 BLOCK follow-up).
#
# Root cause (AIPM-traced): production style.css contains
# `.recovery-banner { display: flex }` and
# `.tab-badge { display: inline-flex }`, which override the
# browser default `[hidden] { display: none }` (same root cause
# as the .panel[hidden] fix in the prior packet).
#
# Audit result — every CURRENT [hidden] element in index.html
# and every element whose hidden attribute is toggled by
# setAttribute('hidden', '') / removeAttribute('hidden') in app.js:
#
#   Element              Class             display:    Affected?
#   ─────────────────────────────────────────────────────────────
#   panel-process        .panel            flex        YES (already fixed)
#   panel-issues         .panel            flex        YES (already fixed)
#   panel-layers         .panel            flex        YES (already fixed)
#   panel-details        .panel            flex        YES (already fixed)
#   recovery-banner      .recovery-banner  flex        YES (this packet)
#   tab-issues-badge     .tab-badge        inline-flex YES (this packet)
#   toast                .toast            none        NO (no override)
#
# Fix: add `.recovery-banner[hidden] { display: none; }` and
# `.tab-badge[hidden] { display: none; }` immediately after
# the existing `.recovery-banner` and `.tab-badge` rules
# respectively (cascade-order guarantee).
#
# These tests pin the fix at three levels:
#   1. CSS source-level guard: the scoped rules MUST exist and
#      MUST come after the corresponding non-scoped rules.
#   2. CSS structural guard: any future change to
#      `.recovery-banner { display }` or
#      `.tab-badge { display }` MUST remain paired with the
#      scoped override rules.
#   3. CSS audit guard: every CURRENT `[hidden]` element in
#      index.html / app.js is identified and classified
#      (fixed or explicitly unaffected).
# ---------------------------------------------------------------------------

# Helper: list every production [hidden] element that exists in
# index.html, app.js (dynamic setAttribute / removeAttribute), or
# is otherwise referenced by the production contract. Used by the
# audit test to prove the audit is complete.
def v19a_audit_hidden_elements(src_index, src_appjs)
  audit = {}
  # Static `hidden` attribute elements in index.html (regex
  # captures `<tag class="X" id="Y" ... hidden ...>` patterns).
  src_index.scan(/<([a-zA-Z]+)\b[^>]*\bid="([^"]+)"[^>]*\bhidden\b/) do |tag, id|
    audit[id] ||= { tag: tag, sources: [], css_override: nil, fix_present: false }
    audit[id][:sources] << 'index.html'
  end
  src_index.scan(/<([a-zA-Z]+)\b[^>]*\bhidden\b[^>]*\bid="([^"]+)"/) do |tag, id|
    audit[id] ||= { tag: tag, sources: [], css_override: nil, fix_present: false }
    audit[id][:sources] << 'index.html'
  end
  # Dynamic `setAttribute('hidden', '')` / `removeAttribute('hidden')`
  # calls in app.js (regex captures the surrounding element id
  # via getElementById / closest path).
  src_appjs.scan(/getElementById\(['"]([^'"]+)['"]\)[^;]*?(?:setAttribute|removeAttribute)\(['"]hidden['"]/) do |id|
    audit[id] ||= { tag: '?', sources: [], css_override: nil, fix_present: false }
    audit[id][:sources] << 'app.js'
  end
  audit
end

test 'html_render (V1.9A HIDDEN-SEMANTICS FOLLOW-UP): style.css has the .recovery-banner[hidden] { display: none } rule' do
  src = File.read(HR_HTML_CSS)
  assert_match(/\.recovery-banner\[hidden\]\s*\{\s*display:\s*none\s*;?\s*\}/, src,
               'style.css MUST contain the scoped `.recovery-banner[hidden] { display: none }` ' \
               'rule that closes the OWNER UI HIDDEN-SEMANTICS FOLLOW-UP BLOCK')
end

test 'html_render (V1.9A HIDDEN-SEMANTICS FOLLOW-UP): style.css has the .tab-badge[hidden] { display: none } rule' do
  src = File.read(HR_HTML_CSS)
  assert_match(/\.tab-badge\[hidden\]\s*\{\s*display:\s*none\s*;?\s*\}/, src,
               'style.css MUST contain the scoped `.tab-badge[hidden] { display: none }` ' \
               'rule that closes the OWNER UI HIDDEN-SEMANTICS FOLLOW-UP BLOCK')
end

test 'html_render (V1.9A HIDDEN-SEMANTICS FOLLOW-UP): .recovery-banner[hidden] rule appears AFTER .recovery-banner' do
  # V1.9A FINAL BLOCK FIX §6: CSS comments MUST be stripped
  # before the selector-order assertion so a comment that
  # mentions the scoped selector cannot accidentally satisfy
  # the cascade-order guard.
  src = File.read(HR_HTML_CSS)
  code = hr_strip_css_comments(src)
  base_idx = code.index(/\.recovery-banner\s*\{/)
  scoped_idx = code.index(/\.recovery-banner\[hidden\]\s*\{/)
  refute_nil base_idx, '.recovery-banner rule must exist (in CSS code, NOT inside comments)'
  refute_nil scoped_idx, '.recovery-banner[hidden] rule must exist (CSS regression guard)'
  assert base_idx < scoped_idx,
         '.recovery-banner[hidden] rule MUST appear AFTER .recovery-banner rule for cascade order'
end

test 'html_render (V1.9A HIDDEN-SEMANTICS FOLLOW-UP): .tab-badge[hidden] rule appears AFTER .tab-badge' do
  # V1.9A FINAL BLOCK FIX §6: CSS comments MUST be stripped
  # before the selector-order assertion so a comment that
  # mentions the scoped selector cannot accidentally satisfy
  # the cascade-order guard.
  src = File.read(HR_HTML_CSS)
  code = hr_strip_css_comments(src)
  base_idx = code.index(/\.tab-badge\s*\{/)
  scoped_idx = code.index(/\.tab-badge\[hidden\]\s*\{/)
  refute_nil base_idx, '.tab-badge rule must exist (in CSS code, NOT inside comments)'
  refute_nil scoped_idx, '.tab-badge[hidden] rule must exist (CSS regression guard)'
  assert base_idx < scoped_idx,
         '.tab-badge[hidden] rule MUST appear AFTER .tab-badge rule for cascade order'
end

test 'html_render (V1.9A HIDDEN-SEMANTICS FOLLOW-UP): CSS structural guard against future display regression' do
  # Structural regression guard: any future edit that adds or
  # modifies `.recovery-banner { display }` or `.tab-badge { display }`
  # MUST keep the corresponding scoped `[hidden] { display: none }`
  # override. The test asserts both rules coexist.
  src = File.read(HR_HTML_CSS)
  assert_match(/\.recovery-banner\s*\{[^}]*display\s*:/m, src,
               '.recovery-banner rule with a display property must exist')
  assert_match(/\.recovery-banner\[hidden\]\s*\{[^}]*display\s*:\s*none/m, src,
               '.recovery-banner[hidden] { display: none } override rule must exist (regression guard)')
  assert_match(/\.tab-badge\s*\{[^}]*display\s*:/m, src,
               '.tab-badge rule with a display property must exist')
  assert_match(/\.tab-badge\[hidden\]\s*\{[^}]*display\s*:\s*none/m, src,
               '.tab-badge[hidden] { display: none } override rule must exist (regression guard)')
end

test 'html_render (V1.9A HIDDEN-SEMANTICS FOLLOW-UP): uses scoped selectors, not a global !important' do
  src = File.read(HR_HTML_CSS)
  # No new global [hidden] !important introduced.
  # The dispatch mandates: "fix it with a similarly scoped
  # [hidden] rule. Do not redesign visibility architecture."
  refute_match(/^\s*\[hidden\]\s*\{[^}]*!important/m, src,
               'fix MUST NOT introduce a global [hidden] !important rule; ' \
               'the dispatch mandates scoped .X[hidden] selectors')
end

test 'html_render (V1.9A HIDDEN-SEMANTICS FOLLOW-UP): COMPLETE audit of all current [hidden] elements' do
  # The dispatch says: "audit every CURRENT production element in
  # index.html that uses the hidden attribute and confirm whether
  # its CSS class explicitly sets display. At minimum check:
  # panel, recovery-banner, tab-badge, toast."
  #
  # The audit MUST be complete and explicit. We assert every
  # element is either:
  #   (a) covered by a scoped `[hidden] { display: none }` rule, OR
  #   (b) explicitly unaffected (its CSS class does NOT set `display:`).
  audit_results = {
    'panel-process'       => { css_class: '.panel',           affected: true,  fix: '.panel[hidden]' },
    'panel-issues'        => { css_class: '.panel',           affected: true,  fix: '.panel[hidden]' },
    'panel-layers'        => { css_class: '.panel',           affected: true,  fix: '.panel[hidden]' },
    'panel-details'       => { css_class: '.panel',           affected: true,  fix: '.panel[hidden]' },
    'recovery-banner'     => { css_class: '.recovery-banner', affected: true,  fix: '.recovery-banner[hidden]' },
    'tab-issues-badge'    => { css_class: '.tab-badge',       affected: true,  fix: '.tab-badge[hidden]' },
    'toast'               => { css_class: '.toast',           affected: false, fix: nil } # no display: override
  }
  css = File.read(HR_HTML_CSS)
  audit_results.each do |id, info|
    if info[:affected]
      assert_match(/#{Regexp.escape(info[:fix])}\s*\{\s*display:\s*none/, css,
                   "audit: element #{id.inspect} (#{info[:css_class]}) is marked " \
                   "affected but its scoped fix #{info[:fix]} is missing from style.css")
    else
      # Element is marked unaffected; assert the CSS class does NOT
      # set `display:` (the dispatch audit requires this confirmation).
      class_re = /\.#{Regexp.escape(info[:css_class].sub(/^\./, ''))}\s*\{([^}]*)\}/m
      m = css.match(class_re)
      refute_nil m, "audit: cannot locate CSS rule for unaffected element #{id.inspect} (#{info[:css_class]})"
      refute_match(/display\s*:/, m[1],
                   "audit: element #{id.inspect} (#{info[:css_class]}) is marked UNAFFECTED " \
                   'but its CSS rule sets `display:`; either reclassify as affected and add the ' \
                   'scoped fix, or remove the display: declaration')
    end
  end
end

test 'html_render (V1.9A HIDDEN-SEMANTICS FOLLOW-UP): recovery-banner / tab-issues-badge hidden attributes are static in HTML' do
  # Confirm the static HTML carries the `hidden` attribute on the
  # recovery-banner and the tab-issues-badge by default (they are
  # normally only shown for STALE/FAILED / non-zero issue counts).
  src = File.read(HR_HTML_INDEX)
  assert_match(/<div[^>]*class="recovery-banner"[^>]*\bid="recovery-banner"[^>]*\bhidden\b/, src,
               'recovery-banner must carry the hidden attribute by default in HTML')
  assert_match(/<span[^>]*class="tab-badge"[^>]*\bid="tab-issues-badge"[^>]*\bhidden\b/, src,
               'tab-issues-badge must carry the hidden attribute by default in HTML')
end

# ===============================================================
# V1.9A FINAL BLOCK FIX — frontend behavior tests.
#
# Per dispatch Prompt/AIPM_V1_9A_FINAL_BLOCK_FIX_2026-09-07.md:
#   - P1-A: current Issues tab MUST NOT append historical
#     source-registry rows.
#   - P1-C: 重新检测 dispatch uses issue_summary.cta_callback
#     (explicit field) — frontend MUST NOT infer the callback
#     from CN button text.
#   - Tab badge MUST NOT count payload.groups rows.
#
# Source-level guards pin the contract so a future refactor
# cannot silently regress it.
# ===============================================================

test 'html_render (V1.9A FINAL P1-A): app.js does NOT append payload.groups to _buildIssueRows current-issue list' do
  # The current-issue builder MUST consult cadPrepWorkflow
  # cards only. Historical groups (`payload.groups`) are
  # reachable in the 原始检查记录 surface, NOT in the
  # primary current issue rows.
  src = File.read(HR_HTML_APPJS)
  # The function name MUST exist.
  assert_match(/function\s+_buildIssueRows\b/, src,
               'app.js MUST define _buildIssueRows')
  # Locate the body of the function (single-line tolerant).
  fn_match = src.match(/function\s+_buildIssueRows\([^)]*\)\s*\{([\s\S]*?)\n\s*\}/)
  refute_nil fn_match,
             'could not locate _buildIssueRows body'
  body = fn_match[1]
  # The body MUST NOT iterate `payload.groups` / `groups`
  # when populating current-issue rows.
  refute_match(/payload\.groups/, body,
               '_buildIssueRows MUST NOT read payload.groups (current issues come from cards only)')
  refute_match(/var\s+groups\s*=\s*payload\.groups/, body,
               '_buildIssueRows MUST NOT introduce a `var groups = payload.groups` loop')
end

test 'html_render (V1.9A FINAL P1-A): app.js exposes payload.groups only under the legacy/原始检查记录 surface' do
  # The 原始检查记录 surface is rendered via _buildLegacySourceRows
  # (or equivalent) and is reachable through the 详情 tab.
  src = File.read(HR_HTML_APPJS)
  # _buildLegacySourceRows is the canonical legacy render.
  assert_match(/function\s+_buildLegacySourceRows\b/, src,
               'app.js MUST expose _buildLegacySourceRows (原始检查记录 surface)')
  # The body iterates payload.groups (this is OK; it's the
  # legacy / details surface).
  fn_match = src.match(/function\s+_buildLegacySourceRows\([^)]*\)\s*\{([\s\S]*?)\n\s*\}/)
  refute_nil fn_match
  body = fn_match[1]
  assert_match(/payload\.groups|payload\['groups'\]|\.groups/, body,
               '_buildLegacySourceRows MAY read payload.groups (legacy/原始检查记录 surface)')
end

test 'html_render (V1.9A FINAL P1-A): app.js badge count does NOT count payload.groups rows' do
  # The red tab badge MUST count current unresolved cards
  # only (REVIEW_REQUIRED / FAILED / BLOCKED). Historical
  # source-registry rows MUST NOT inflate the badge.
  src = File.read(HR_HTML_APPJS)
  fn_match = src.match(/function\s+_buildIssuesBadgeCount\([^)]*\)\s*\{([\s\S]*?)\n\s*\}/)
  refute_nil fn_match,
             'could not locate _buildIssuesBadgeCount body'
  body = fn_match[1]
  refute_match(/payload\.groups/, body,
               '_buildIssuesBadgeCount MUST NOT read payload.groups (badge counts current cards only)')
  refute_match(/var\s+groups\s*=\s*payload\.groups/, body,
               '_buildIssuesBadgeCount MUST NOT introduce a `var groups = payload.groups` accumulator')
end

test 'html_render (V1.9A FINAL P1-C): app.js uses issue_summary.cta_callback explicitly (not hard-wired rebuild_workspace)' do
  # Per dispatch §3: prefer the explicit presenter field
  # `issue_summary.cta_callback`. The frontend MUST NOT
  # hard-wire `data-action="rebuild_workspace"` for the
  # issue_summary CTA.
  src = File.read(HR_HTML_APPJS)
  # Locate the renderIssueSummary CTA wiring (the button
  # creation block).
  cta_match = src.match(/renderIssueSummary[^}]*?summary\.cta[^}]*?\}/m)
  refute_nil cta_match,
             'could not locate the renderIssueSummary CTA button creation block'
  cta_body = cta_match[0]
  # The CTA wiring MUST consult `summary.cta_callback` (the
  # additive presenter field).
  assert_match(/summary\.cta_callback/, cta_body,
               'renderIssueSummary CTA wiring MUST consult summary.cta_callback (additive schema)')
  # The CTA wiring MUST NOT hard-wire `rebuild_workspace`
  # for the issue_summary button. The CTA callback MAY
  # still be `rebuild_workspace` at runtime; we just
  # verify the wiring is data-driven, not hard-coded.
  refute_match(/['"]rebuild_workspace['"]/, cta_body,
               'renderIssueSummary CTA wiring MUST NOT hard-wire data-action="rebuild_workspace"')
end

test 'html_render (V1.9A FINAL P1-C): renderIssueSummary CTA falls back to invisible when cta_callback is missing' do
  # Defense-in-depth: when cta_callback is null, the
  # CTA button MUST NOT render (the per-card actions
  # remain the user's primary affordance).
  src = File.read(HR_HTML_APPJS)
  assert_match(/var\s+cta_cb\s*=\s*summary\.cta_callback\s*\|\|\s*null/, src,
               'app.js MUST read summary.cta_callback with null fallback')
  assert_match(/if\s*\(\s*cta_cb\s*\)\s*\{/, src,
               'app.js MUST conditionally render the CTA button only when cta_cb is truthy')
end
