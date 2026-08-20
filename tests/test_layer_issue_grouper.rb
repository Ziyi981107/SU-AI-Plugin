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

# --- V1.2 (per directive 026): role-bucket order via Hash-shaped input ---

# 8. V1.2 wiring: grouper accepts Hash-shaped LayerSummary input
# (the shape produced by LayerSemanticMapper.build) and preserves
# the input order so buckets line up with the Layers display order.
test 'LayerIssueGrouper.group: Hash-shaped input preserves input order (V1.2 wiring)' do
  # AnalyzersRunner passes the role-sorted LayerSummary hashes; the
  # bucket order must mirror that input order.
  layer_summaries = [
    { name: 'Layer0',      role: :construction }, # Construction row first
    { name: 'GUIDE-XLINE', role: :guide },         # Guide row second
    { name: 'DIM-XX',      role: :dimension },     # Dimension row third
    { name: 'TXT-XX',      role: :annotation },    # Annotation row fourth
    { name: 'XYZ-9999',    role: :unknown }        # Unknown row last
  ]
  issues = [
    { source: { layer_name: 'Layer0'      }, severity: :low,  issue_id: 'open_endpoint|1|1' },
    { source: { layer_name: 'GUIDE-XLINE' }, severity: :low,  issue_id: 'open_endpoint|2|1' },
    { source: { layer_name: 'DIM-XX'      }, severity: :high, issue_id: 'duplicate|3|1' },
    { source: { layer_name: 'TXT-XX'      }, severity: :low,  issue_id: 'short_edge|4|1' },
    { source: { layer_name: 'XYZ-9999'    }, severity: :low,  issue_id: 'short_edge|5|1' }
  ]
  result = SUAnalysis::Core::LayerIssueGrouper.group(issues, layer_summaries)
  names = result.map { |b| b[:name] }
  assert_equal ['Layer0', 'GUIDE-XLINE', 'DIM-XX', 'TXT-XX', 'XYZ-9999'], names,
               'bucket order must mirror the input order (Hash-shaped)'
end

# 9. V1.2: bucket survives issue data integrity (locatable flag and
# severity survive, the issues array is the registry's issue list).
test 'LayerIssueGrouper.group: issue data + locatable flag survive (V1.2)' do
  issues = [
    { source: { layer_name: 'DIM-XX' }, severity: :high, issue_id: 'duplicate|1|1',
      locatable: true, message: 'dup edge' },
    { source: { layer_name: 'DIM-XX' }, severity: :low, issue_id: 'open_endpoint|1|1',
      locatable: false, message: 'open ep' }
  ]
  result = SUAnalysis::Core::LayerIssueGrouper.group(issues, [make_layer_record('DIM-XX')])
  bucket = result.first
  issues_in_bucket = bucket[:issues]
  assert_equal 2, issues_in_bucket.length
  # locatable flag must be preserved on each issue.
  locatable_flags = issues_in_bucket.map { |i| i[:locatable] }
  assert_equal [true, false], locatable_flags
  # severity must be preserved.
  assert_equal :high, issues_in_bucket[0][:severity]
  assert_equal :low,  issues_in_bucket[1][:severity]
  # message must be preserved.
  assert_equal 'dup edge', issues_in_bucket[0][:message]
  assert_equal 'open ep',  issues_in_bucket[1][:message]
end

# 10. V1.2: input data not mutated.
test 'LayerIssueGrouper.group: input issues + layer_records not mutated (V1.2)' do
  issues = [
    { source: { layer_name: 'DIM-XX' }, severity: :low, issue_id: 'open_endpoint|1|1' }
  ]
  layer_summaries = [
    { name: 'Layer0', role: :construction },
    { name: 'DIM-XX', role: :dimension }
  ]
  issues_before = Marshal.load(Marshal.dump(issues))
  layers_before = Marshal.load(Marshal.dump(layer_summaries))
  SUAnalysis::Core::LayerIssueGrouper.group(issues, layer_summaries)
  assert_equal issues_before, issues, 'issues array must not be mutated'
  assert_equal layers_before, layer_summaries, 'layer_records array must not be mutated'
end

# 11. V1.2: deterministic bucket order when input order is role-sorted.
test 'LayerIssueGrouper.group: deterministic order for role-sorted Hash input (V1.2)' do
  # Two identical calls produce identical bucket orders.
  layer_summaries = [
    { name: 'DIM-XX',   role: :dimension },
    { name: 'TXT-XX',   role: :annotation },
    { name: 'Layer0',   role: :construction },
    { name: 'XYZ-9999', role: :unknown }
  ]
  issues = [
    { source: { layer_name: 'Layer0'   }, severity: :low, issue_id: 'open_endpoint|1|1' },
    { source: { layer_name: 'DIM-XX'   }, severity: :low, issue_id: 'open_endpoint|2|1' },
    { source: { layer_name: 'TXT-XX'   }, severity: :low, issue_id: 'short_edge|3|1' },
    { source: { layer_name: 'XYZ-9999' }, severity: :low, issue_id: 'short_edge|4|1' }
  ]
  a = SUAnalysis::Core::LayerIssueGrouper.group(issues, layer_summaries)
  b = SUAnalysis::Core::LayerIssueGrouper.group(issues, layer_summaries)
  assert_equal a.map { |x| x[:name] }, b.map { |x| x[:name] }
  assert_equal ['DIM-XX', 'TXT-XX', 'Layer0', 'XYZ-9999'], a.map { |x| x[:name] }
end
