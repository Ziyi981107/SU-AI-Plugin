#
# tests/test_ui_bridge.rb
#
# Symbol -> JSON String boundary at the JS payload level.
# Per CodeX Round 011..014: ONLY this module converts Hash keys to
# Strings for the JS layer.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/issue_normalizer'
require_relative '../extension/su_ai_plugin/core/issue_enricher'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/ui_bridge'

include SUAnalysis::Core
include SUAnalysis::Extension

# --- helpers --------------------------------------------------------

def make_issue_overrides(overrides = {})
  base = {
    issue_id:          'duplicate_edge_candidate|10.20|1',
    issue_type:        'duplicate_edge_candidate',
    severity:          'medium',
    confidence:        'high',
    sources:           [],
    source_entity_ids: [],
    edge_ids:          [],
    location:          nil,
    message:           'm',
    metadata:          {},
    locatable:         true,
    display_length:    nil
  }
  base.merge(overrides)
end

# --- as_html_data --------------------------------------------------

test 'ui_bridge.as_html_data: nil -> empty hash' do
  assert_equal({}, UIBridge.as_html_data(nil))
end

test 'ui_bridge.as_html_data: top-level keys are Strings' do
  reg = IssueRegistry.new([make_issue_overrides])
  preflight = Object.new
  result = AnalysisResult.new(
    preflight: preflight, registry: reg,
    selection_type: 'Group', selection_label: 'g'
  )
  payload = UIBridge.as_html_data(result)
  assert payload.keys.all? { |k| k.is_a?(String) }
  assert payload['selectionType'] == 'Group'
  assert payload['selectionLabel'] == 'g'
end

test 'ui_bridge.as_html_data: summary keys are Strings' do
  reg = IssueRegistry.new([
    make_issue_overrides(issue_id: 'duplicate_edge_candidate|1|1'),
    make_issue_overrides(issue_id: 'short_edge|1|1', issue_type: 'short_edge')
  ])
  result = AnalysisResult.new(preflight: Object.new, registry: reg)
  payload = UIBridge.as_html_data(result)
  # Per CodeX Round 018 BLOCK-006: per-issue-type counts live under
  # summary['issues'], NOT at the top level of summary.
  assert payload['summary'].keys.all? { |k| k.is_a?(String) }
  assert payload['summary']['issues'].keys.all? { |k| k.is_a?(String) }
  assert_equal 1, payload['summary']['issues']['duplicate_edge_candidate']
  assert_equal 1, payload['summary']['issues']['short_edge']
end

test 'ui_bridge.as_html_data: groups shape is JS-safe' do
  reg = IssueRegistry.new([
    make_issue_overrides(severity: 'high', issue_id: 'abnormal_large_coord|1|1',
                          issue_type: 'abnormal_large_coord')
  ])
  result = AnalysisResult.new(preflight: Object.new, registry: reg)
  payload = UIBridge.as_html_data(result)
  assert_equal 1, payload['groups'].length
  g = payload['groups'][0]
  assert_equal 'abnormal_large_coord', g['type']
  assert_equal 1, g['count']
  assert g['defaultOpen'] == true
  assert g['issues'].length == 1
  iss = g['issues'][0]
  assert iss.keys.all? { |k| k.is_a?(String) }
  assert_equal 'high', iss['severity']
end

# --- to_json -------------------------------------------------------

test 'ui_bridge.to_json: produces valid JSON' do
  require 'json'
  reg = IssueRegistry.new([make_issue_overrides])
  result = AnalysisResult.new(preflight: Object.new, registry: reg)
  json = UIBridge.to_json(result)
  parsed = JSON.parse(json)
  assert_equal 'duplicate_edge_candidate', parsed['groups'][0]['issues'][0]['issue_type']
end

test 'ui_bridge.to_json: empty result is valid JSON' do
  require 'json'
  result = AnalysisResult.new(
    preflight: Object.new,
    registry:  IssueRegistry.new([]),
    selection_type:  'selection',
    selection_label: 'selection'
  )
  json = UIBridge.to_json(result)
  parsed = JSON.parse(json)
  assert_equal 'selection', parsed['selectionLabel']
  assert_equal 'selection', parsed['selectionType']
  assert_equal [], parsed['groups']
end

# --- value coercion -------------------------------------------------

test 'ui_bridge: numeric value coerced to String key' do
  reg = IssueRegistry.new([make_issue_overrides])
  result = AnalysisResult.new(preflight: Object.new, registry: reg)
  payload = UIBridge.as_html_data(result)
  issue = payload['groups'][0]['issues'][0]
  # Symbol keys became String keys.
  assert issue.key?('issue_id')
  assert issue.key?('severity')
  assert issue.key?('locatable')
end

test 'ui_bridge: deep nested Hash has String keys too' do
  reg = IssueRegistry.new([make_issue_overrides(
    metadata: { 'foo' => { 'bar' => 1, :baz => 'x' } })])
  result = AnalysisResult.new(preflight: Object.new, registry: reg)
  payload = UIBridge.as_html_data(result)
  issue = payload['groups'][0]['issues'][0]
  assert issue['metadata']['foo'].keys.all? { |k| k.is_a?(String) }
end

# --------------------------------------------------------------------------
# V1.1 (per plan §4.9): UIBridge exposes a `layerGroups` top-level key,
# String-keyed, derived from the frozen AnalysisResult#layer_groups
# Array. The summary's `layer_groups` (snake_case keys under summary)
# is the canonical Ruby access point; `layerGroups` is the convenience
# top-level key the JS render function reads.
# --------------------------------------------------------------------------

test 'ui_bridge.as_html_data: layerGroups top-level key is present (V1.1)' do
  reg = IssueRegistry.new([])
  result = AnalysisResult.new(preflight: Object.new, registry: reg)
  payload = UIBridge.as_html_data(result)
  assert payload.key?('layerGroups'),
         "expected top-level 'layerGroups' key, got #{payload.keys.inspect}"
  assert_kind_of Array, payload['layerGroups']
end

test 'ui_bridge.as_html_data: layerGroups is an empty Array when V1.0 caller passes nothing' do
  # V1.0 callers (no layer_groups kwarg) get layer_groups = [], which
  # UIBridge surfaces as layerGroups = [].
  reg = IssueRegistry.new([])
  result = AnalysisResult.new(preflight: Object.new, registry: reg)
  payload = UIBridge.as_html_data(result)
  assert_equal [], payload['layerGroups']
end

test 'ui_bridge.as_html_data: layerGroups contains Symbol-keyed layer summary hashes (stringified)' do
  # Simulate an AnalyzersRunner result that has been run. We pass
  # layer_groups as the same shape LayerSemanticMapper produces.
  reg = IssueRegistry.new([])
  layer_groups = [
    {
      name:               'DIM-XX',
      role:               :dimension,
      role_rule:          'name_dimension',
      role_label:         'Dimension',
      visible:            true,
      visibility_unknown: false,
      visibility_label:   'Visible',
      edge_count:         12,
      issue_count:        0
    },
    {
      name:               'Layer0',
      role:               :construction,
      role_rule:          'name_default_layer',
      role_label:         'Construction',
      visible:            false,
      visibility_unknown: false,
      visibility_label:   'Off-screen',
      edge_count:         4,
      issue_count:        1
    }
  ]
  result = AnalysisResult.new(
    preflight:      Object.new,
    registry:       reg,
    layer_groups:   layer_groups
  )
  payload = UIBridge.as_html_data(result)
  lg = payload['layerGroups']
  assert_equal 2, lg.length
  # V1.0 contract: ALL keys (top + nested) MUST be Strings.
  assert lg.all? { |g| g.keys.all? { |k| k.is_a?(String) } },
         "layerGroups entries have non-String keys: #{lg.map(&:keys).inspect}"
  # Field set preserved end-to-end.
  dim = lg.find { |g| g['name'] == 'DIM-XX' }
  refute_nil dim
  assert_equal 'Dimension',         dim['role_label']
  assert_equal 'name_dimension',    dim['role_rule']
  assert_equal 'Visible',           dim['visibility_label']
  assert_equal 12,                  dim['edge_count']
  assert_equal 0,                   dim['issue_count']
  assert_equal true,                dim['visible']
  assert_equal false,               dim['visibility_unknown']
  l0 = lg.find { |g| g['name'] == 'Layer0' }
  refute_nil l0
  assert_equal 'Construction',      l0['role_label']
  assert_equal 'Off-screen',        l0['visibility_label']
  assert_equal 4,                   l0['edge_count']
  assert_equal 1,                   l0['issue_count']
end

test 'ui_bridge.to_json: layerGroups survives JSON round-trip' do
  reg = IssueRegistry.new([])
  layer_groups = [
    {
      name:               'DIM-XX',
      role:               :dimension,
      role_rule:          'name_dimension',
      role_label:         'Dimension',
      visible:            true,
      visibility_unknown: false,
      visibility_label:   'Visible',
      edge_count:         5,
      issue_count:        2
    }
  ]
  result = AnalysisResult.new(
    preflight:      Object.new,
    registry:       reg,
    layer_groups:   layer_groups
  )
  require 'json'
  json = UIBridge.to_json(result)
  parsed = JSON.parse(json)
  refute_nil parsed['layerGroups']
  assert_equal 1, parsed['layerGroups'].length
  entry = parsed['layerGroups'].first
  assert_equal 'DIM-XX', entry['name']
  assert_equal 'Dimension', entry['role_label']
  assert_equal 5, entry['edge_count']
  assert_equal 2, entry['issue_count']
  # Symbol keys never leak to JSON.
  assert entry.keys.all? { |k| k.is_a?(String) },
         "JSON keys must be Strings, got #{entry.keys.inspect}"
end

test 'ui_bridge.as_html_data: layerGroups and summary.layer_groups carry the SAME data' do
  # Per plan §4.9: both are exposed, both must agree. The summary key
  # is the canonical Ruby access; the top-level key is the JS
  # convenience. They MUST NOT drift.
  reg = IssueRegistry.new([])
  layer_groups = [
    {
      name:               'DIM-XX',
      role:               :dimension,
      role_rule:          'name_dimension',
      role_label:         'Dimension',
      visible:            true,
      visibility_unknown: false,
      visibility_label:   'Visible',
      edge_count:         5,
      issue_count:        0
    }
  ]
  result = AnalysisResult.new(
    preflight:      Object.new,
    registry:       reg,
    layer_groups:   layer_groups
  )
  payload = UIBridge.as_html_data(result)
  # Same number of entries.
  assert_equal payload['layerGroups'].length, payload['summary']['layer_groups'].length
  # Same per-entry String keys (recursively).
  from_top  = payload['layerGroups'].first.keys.sort
  from_sum  = payload['summary']['layer_groups'].first.keys.sort
  assert_equal from_top, from_sum
end
