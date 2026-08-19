#
# tests/test_layer_semantic_mapper.rb — V1.1 LayerSemanticMapper aggregation.
#
# Per plan §4.4 / §6 / §8: aggregate per-layer records + issues into
# LayerSummary Array, with locked sort order and visibility_label
# composition (R011).
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/layer_role'
require_relative '../extension/su_ai_plugin/core/layer_role_config'
require_relative '../extension/su_ai_plugin/core/layer_semantic_mapper'

def make_record(name, edge_count: 1, role: :unknown, role_rule: nil,
                visible: true, visibility_unknown: false)
  SUAnalysis::Core::LayerRecord.new(
    name: name, edge_count: edge_count, role: role, role_rule: role_rule,
    visible: visible, visibility_unknown: visibility_unknown
  )
end

# 1. Empty input.
test 'LayerSemanticMapper.build: empty layer_records + empty issues -> []' do
  result = SUAnalysis::Core::LayerSemanticMapper.build([], [])
  assert_equal [], result
end

test 'LayerSemanticMapper.build: empty layer_records + issues -> [] (no phantom layers)' do
  issues = [{ source: { layer_name: 'DIM-XX' }, severity: :low, issue_id: 'x|1' }]
  result = SUAnalysis::Core::LayerSemanticMapper.build([], issues)
  assert_equal [], result
end

# 2. Single layer -> single summary.
test 'LayerSemanticMapper.build: one layer -> one summary with right role' do
  recs = [make_record('DIM-XX', role: :dimension, role_rule: 'name_dimension', edge_count: 5)]
  result = SUAnalysis::Core::LayerSemanticMapper.build(recs, [])
  assert_equal 1, result.length
  s = result.first
  assert_equal 'DIM-XX', s[:name]
  assert_equal :dimension, s[:role]
  assert_equal 'Dimension', s[:role_label]
  assert_equal 5, s[:edge_count]
  assert_equal 0, s[:issue_count]
  assert_equal 'Visible', s[:visibility_label]
end

# 3. Deduplication.
test 'LayerSemanticMapper.build: two records with same name -> one summary, summed edge_count' do
  recs = [
    make_record('DIM-XX', edge_count: 3),
    make_record('DIM-XX', edge_count: 7)
  ]
  result = SUAnalysis::Core::LayerSemanticMapper.build(recs, [])
  assert_equal 1, result.length
  assert_equal 10, result.first[:edge_count]
end

# 4. Sort order: role bucket, then visible, then issue_count DESC, then name.
test 'LayerSemanticMapper.build: role bucket order [dim, anno, guide, construction, unknown] (R009/R012)' do
  recs = [
    make_record('UNK',    role: :unknown,      role_rule: 'name_no_match'),
    make_record('CON',    role: :construction, role_rule: 'name_default_layer'),
    make_record('GUI',    role: :guide,        role_rule: 'name_guide'),
    make_record('ANN',    role: :annotation,   role_rule: 'name_annotation'),
    make_record('DIM',    role: :dimension,    role_rule: 'name_dimension')
  ]
  result = SUAnalysis::Core::LayerSemanticMapper.build(recs, [])
  names = result.map { |s| s[:name] }
  assert_equal %w[DIM ANN GUI CON UNK], names
end

# 5. Within role bucket: visible first, then hidden.
test 'LayerSemanticMapper.build: hidden rows sort AFTER visible rows in same role (R009)' do
  recs = [
    make_record('DIM-HIDDEN', role: :dimension, visible: false),
    make_record('DIM-VISIBLE', role: :dimension, visible: true)
  ]
  result = SUAnalysis::Core::LayerSemanticMapper.build(recs, [])
  names = result.map { |s| s[:name] }
  assert_equal %w[DIM-VISIBLE DIM-HIDDEN], names
end

# 6. issue_count attribution.
test 'LayerSemanticMapper.build: issue_count matches source[:layer_name]' do
  recs = [make_record('DIM-XX', role: :dimension, edge_count: 4)]
  issues = [
    { source: { layer_name: 'DIM-XX' }, severity: :low, issue_id: 'short_edge|1' },
    { source: { layer_name: 'DIM-XX' }, severity: :high, issue_id: 'duplicate|1' },
    { source: { layer_name: 'OTHER'  }, severity: :low, issue_id: 'short_edge|2' }
  ]
  result = SUAnalysis::Core::LayerSemanticMapper.build(recs, issues)
  dim_summary = result.find { |s| s[:name] == 'DIM-XX' }
  refute_nil dim_summary
  assert_equal 2, dim_summary[:issue_count]
end

test 'LayerSemanticMapper.build: issue with nil source[:layer_name] -> attributed to Layer0' do
  recs = [make_record('Layer0', role: :construction, edge_count: 1)]
  issues = [{ source: {}, severity: :low, issue_id: 'short_edge|1' }]
  result = SUAnalysis::Core::LayerSemanticMapper.build(recs, issues)
  l0 = result.find { |s| s[:name] == 'Layer0' }
  refute_nil l0
  assert_equal 1, l0[:issue_count]
end

# 7. R011 visibility_unknown.
test 'LayerSemanticMapper.build: visibility_unknown: true -> visibility_label "Visibility: unknown"' do
  recs = [make_record('ANY-XX', role: :construction, visible: true, visibility_unknown: true)]
  result = SUAnalysis::Core::LayerSemanticMapper.build(recs, [])
  s = result.first
  assert_equal 'Visibility: unknown', s[:visibility_label]
  assert_equal true, s[:visible]  # operational fallback
  assert_equal true, s[:visibility_unknown]
end

test 'LayerSemanticMapper.build: visibility_unknown true sorts alongside visible (operational true)' do
  recs = [
    make_record('NORMAL',   role: :construction, visible: true,  visibility_unknown: false),
    make_record('UNKNOWN',  role: :construction, visible: true,  visibility_unknown: true),
    make_record('HIDDEN',   role: :construction, visible: false, visibility_unknown: false)
  ]
  result = SUAnalysis::Core::LayerSemanticMapper.build(recs, [])
  names = result.map { |s| s[:name] }
  # visible (including visibility_unknown-true) first, then hidden.
  assert_equal %w[NORMAL UNKNOWN HIDDEN], names
end

# 8. R012 sort order is INDEPENDENT from IssueRegistry.
test 'LayerSemanticMapper.build: R012 role order is independent from IssueRegistry order' do
  layer_order = SUAnalysis::Core::LayerRole::ALL
  refute_equal layer_order, SUAnalysis::Core::IssueRegistry::DEFAULT_GROUP_ORDER
end
