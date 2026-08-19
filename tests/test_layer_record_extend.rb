#
# tests/test_layer_record_extend.rb — V1.1 LayerRecord extension (role/role_rule/visible/visibility_unknown).
#
# Per plan §4.3:
#   - V1.0 LayerRecord is preserved (name/id/edge_count).
#   - 4 new kwargs: role, role_rule, visible, visibility_unknown.
#   - Defaults are safe (UNKNOWN role, visible=true, visibility_unknown=false).
#   - V1.0 callers that do not supply new kwargs get the defaults
#     (V1.0 tests continue to pass unchanged).
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/layer_record'

# 1. V1.0 contract is preserved.
test 'LayerRecord: V1.0 constructor (name, id, edge_count) still works' do
  rec = SUAnalysis::Core::LayerRecord.new(name: 'Layer0', id: 1, edge_count: 5)
  assert_equal 'Layer0', rec.name
  assert_equal 1, rec.id
  assert_equal 5, rec.edge_count
end

# 2. New V1.1 fields with defaults.
test 'LayerRecord: V1.1 defaults — role=unknown, role_rule=nil, visible=true, visibility_unknown=false' do
  rec = SUAnalysis::Core::LayerRecord.new(name: 'Layer0')
  assert_equal :unknown, rec.role
  assert_nil rec.role_rule
  assert_equal true, rec.visible
  assert_equal false, rec.visibility_unknown
end

# 3. New V1.1 fields with explicit values.
test 'LayerRecord: V1.1 full constructor with all new fields' do
  rec = SUAnalysis::Core::LayerRecord.new(
    name: 'DIM-XX',
    id: 7,
    edge_count: 3,
    role: :dimension,
    role_rule: 'name_dimension',
    visible: false,
    visibility_unknown: false
  )
  assert_equal :dimension, rec.role
  assert_equal 'name_dimension', rec.role_rule
  assert_equal false, rec.visible
  assert_equal false, rec.visibility_unknown
end

test 'LayerRecord: visibility_unknown can be true (R011)' do
  rec = SUAnalysis::Core::LayerRecord.new(
    name: 'ANY-XX',
    role: :construction,
    role_rule: 'name_default_layer',
    visible: true,
    visibility_unknown: true
  )
  assert_equal true, rec.visibility_unknown
  assert_equal true, rec.visible   # operational fallback
end

# 4. Coercion to canonical Boolean.
test 'LayerRecord: visible: nil -> false (no silent truthy)' do
  rec = SUAnalysis::Core::LayerRecord.new(name: 'X', visible: nil)
  assert_equal false, rec.visible
end

test 'LayerRecord: visibility_unknown: nil -> false' do
  rec = SUAnalysis::Core::LayerRecord.new(name: 'X', visibility_unknown: nil)
  assert_equal false, rec.visibility_unknown
end

# 5. increment_edge_count! (V1.0 path).
test 'LayerRecord: increment_edge_count! still works' do
  rec = SUAnalysis::Core::LayerRecord.new(name: 'Layer0', edge_count: 0)
  rec.increment_edge_count!
  rec.increment_edge_count!
  rec.increment_edge_count!
  assert_equal 3, rec.edge_count
end

# 6. to_h includes all V1.1 fields.
test 'LayerRecord: to_h exposes all V1.1 fields' do
  rec = SUAnalysis::Core::LayerRecord.new(
    name: 'DIM-XX',
    id: 5,
    edge_count: 12,
    role: :dimension,
    role_rule: 'name_dimension',
    visible: false,
    visibility_unknown: false
  )
  h = rec.to_h
  assert_equal 'DIM-XX', h[:name]
  assert_equal 5, h[:id]
  assert_equal 12, h[:edge_count]
  assert_equal :dimension, h[:role]
  assert_equal 'name_dimension', h[:role_rule]
  assert_equal false, h[:visible]
  assert_equal false, h[:visibility_unknown]
end
