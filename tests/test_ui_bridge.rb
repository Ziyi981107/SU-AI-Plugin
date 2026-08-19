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
