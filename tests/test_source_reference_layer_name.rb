#
# tests/test_source_reference_layer_name.rb — V1.1 SourceReference.layer_name kwarg.
#
# Per plan §12 default (Agent self): the layer name is captured on
# the SourceReference at snapshot time. V1.0 callers do not supply
# this kwarg; default is nil, which the LayerIssueGrouper maps to
# "Layer0" via the V1.0 fallback.
#
# V1.0 contract: the existing initializer (without layer_name)
# still works and the field is nil by default.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/source_reference'

# 1. V1.0 contract preserved.
test 'SourceReference: V1.0 constructor (no layer_name) still works' do
  ref = SUAnalysis::Core::SourceReference.new(
    entity_id: 1,
    persistent_id: 100,
    kind: 'edge',
    label: 'edge'
  )
  assert_nil ref.layer_name
  assert_nil ref.to_h[:layer_name]
end

# 2. V1.1: layer_name kwarg populates the field.
test 'SourceReference: V1.1 layer_name="DIM-XX" stored verbatim' do
  ref = SUAnalysis::Core::SourceReference.new(
    entity_id: 1,
    persistent_id: 100,
    kind: 'edge',
    label: 'edge',
    layer_name: 'DIM-XX'
  )
  assert_equal 'DIM-XX', ref.layer_name
  assert_equal 'DIM-XX', ref.to_h[:layer_name]
end

# 3. Coercion: layer_name: nil -> nil (not "nil" string).
test 'SourceReference: layer_name: nil -> nil (NOT "nil")' do
  ref = SUAnalysis::Core::SourceReference.new(layer_name: nil)
  assert_nil ref.layer_name
end

# 4. Coercion: layer_name: non-String -> String via to_s.
test 'SourceReference: layer_name coerces non-String via to_s' do
  sym = :dim_xx
  ref = SUAnalysis::Core::SourceReference.new(layer_name: sym)
  assert_equal 'dim_xx', ref.layer_name
end
