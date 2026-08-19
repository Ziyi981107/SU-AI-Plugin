#
# tests/test_layer_issue_grouper.rb — V1.1 LayerIssueGrouper buckets by source layer.
#
# Per plan §4.5: bucket issues by their source[:layer_name], with
# V1.0 fallback "Layer0" for issues with no source layer. Default-open
# policy mirrors IssueGrouper (open iff :high in bucket, else first
# non-empty bucket). No phantom layers.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/layer_issue_grouper'

def make_layer_record(name)
  SUAnalysis::Core::LayerRecord.new(name: name, edge_count: 1)
end

# 1. Empty inputs.
test 'LayerIssueGrouper.group: empty issues + empty layers -> []' do
  result = SUAnalysis::Core::LayerIssueGrouper.group([], [])
  assert_equal [], result
end

# 2. One issue, one known layer -> one bucket.
test 'LayerIssueGrouper.group: one issue with layer_name -> one bucket' do
  issues = [{ source: { layer_name: 'DIM-XX' }, severity: :low, issue_id: 'short_edge|1' }]
  result = SUAnalysis::Core::LayerIssueGrouper.group(issues, [make_layer_record('DIM-XX')])
  assert_equal 1, result.length
  b = result.first
  assert_equal 'DIM-XX', b[:name]
  assert_equal 1, b[:count]
end

# 3. Default-open policy: high -> open.
test 'LayerIssueGrouper.group: bucket with :high issue -> default_open = true' do
  issues = [
    { source: { layer_name: 'DIM-XX' }, severity: :low,  issue_id: 'short_edge|1' },
    { source: { layer_name: 'DIM-XX' }, severity: :high, issue_id: 'duplicate|1' },
    { source: { layer_name: 'DIM-XX' }, severity: :low,  issue_id: 'short_edge|2' }
  ]
  result = SUAnalysis::Core::LayerIssueGrouper.group(issues, [make_layer_record('DIM-XX')])
  assert_equal true, result.first[:default_open]
end

# 4. Default-open policy: no high -> first non-empty bucket open.
test 'LayerIssueGrouper.group: all :low -> first non-empty bucket default_open = true' do
  issues = [
    { source: { layer_name: 'DIM-XX' }, severity: :low, issue_id: 'short_edge|1' },
    { source: { layer_name: 'TXT-XX' }, severity: :low, issue_id: 'short_edge|2' }
  ]
  recs = [make_layer_record('DIM-XX'), make_layer_record('TXT-XX')]
  result = SUAnalysis::Core::LayerIssueGrouper.group(issues, recs)
  # First non-empty bucket (in `known_names` order: DIM-XX, TXT-XX) is open.
  assert_equal true,  result[0][:default_open]
  assert_equal false, result[1][:default_open]
end

# 5. V1.0 fallback: issue with no layer_name -> "Layer0".
test 'LayerIssueGrouper.group: issue with no source[:layer_name] -> Layer0 bucket' do
  issues = [{ source: {}, severity: :low, issue_id: 'short_edge|1' }]
  result = SUAnalysis::Core::LayerIssueGrouper.group(issues, [])
  assert_equal 1, result.length
  assert_equal 'Layer0', result.first[:name]
end

# 6. No phantom layers: issue with unknown layer_name is dropped.
test 'LayerIssueGrouper.group: issue with unknown layer_name -> dropped (no phantom)' do
  issues = [{ source: { layer_name: 'NOT-IN-LIST' }, severity: :low, issue_id: 'short_edge|1' }]
  result = SUAnalysis::Core::LayerIssueGrouper.group(issues, [make_layer_record('DIM-XX')])
  assert_equal [], result
end

# 7. Sort within bucket: by issue_id ASC.
test 'LayerIssueGrouper.group: issues within bucket sorted by issue_id ASC' do
  issues = [
    { source: { layer_name: 'DIM-XX' }, severity: :low, issue_id: 'short_edge|2' },
    { source: { layer_name: 'DIM-XX' }, severity: :low, issue_id: 'short_edge|1' }
  ]
  result = SUAnalysis::Core::LayerIssueGrouper.group(issues, [make_layer_record('DIM-XX')])
  ids = result.first[:issues].map { |i| i[:issue_id] }
  assert_equal ['short_edge|1', 'short_edge|2'], ids
end
