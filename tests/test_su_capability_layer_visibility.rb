#
# tests/test_su_capability_layer_visibility.rb — V1.1 SUCapability.layer_visibility
# (R011 fail-open contract).
#
# Per V1.1 plan §4.7 / R011:
#   - layer_visibility(entity) returns :visible | :hidden | :unknown.
#   - :unknown when host capability is missing (NO #visible?, no #layer,
#     visible? raises, or visible? returns nil).
#   - Caller maps :unknown -> { visible: true, visibility_unknown: true }.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/compatibility/su_capability'

# 1. Visible layer.
test 'SUCapability.layer_visibility: FakeLayer(visible?=true) -> :visible' do
  fake_layer = Class.new do
    def visible?; true; end
  end.new
  fake_entity = Class.new do
    def layer; @l; end
  end.new
  fake_entity.instance_variable_set(:@l, fake_layer)
  assert_equal :visible,
               SUAnalysis::Compatibility::SUCapability.layer_visibility(fake_entity)
end

# 2. Hidden layer.
test 'SUCapability.layer_visibility: FakeLayer(visible?=false) -> :hidden' do
  fake_layer = Class.new do
    def visible?; false; end
  end.new
  fake_entity = Class.new do
    def layer; @l; end
  end.new
  fake_entity.instance_variable_set(:@l, fake_layer)
  assert_equal :hidden,
               SUAnalysis::Compatibility::SUCapability.layer_visibility(fake_entity)
end

# 3. visible? returns nil (defensive).
test 'SUCapability.layer_visibility: FakeLayer(visible?=nil) -> :unknown' do
  fake_layer = Class.new do
    def visible?; nil; end
  end.new
  fake_entity = Class.new do
    def layer; @l; end
  end.new
  fake_entity.instance_variable_set(:@l, fake_layer)
  assert_equal :unknown,
               SUAnalysis::Compatibility::SUCapability.layer_visibility(fake_entity)
end

# 4. visible? raises.
test 'SUCapability.layer_visibility: FakeLayer(visible? raises) -> :unknown' do
  fake_layer = Class.new do
    def visible?; raise StandardError, 'host bug'; end
  end.new
  fake_entity = Class.new do
    def layer; @l; end
  end.new
  fake_entity.instance_variable_set(:@l, fake_layer)
  assert_equal :unknown,
               SUAnalysis::Compatibility::SUCapability.layer_visibility(fake_entity)
end

# 5. Entity lacks #layer.
test 'SUCapability.layer_visibility: entity without #layer -> :unknown' do
  fake_entity = Class.new do
    # No #layer method.
  end.new
  assert_equal :unknown,
               SUAnalysis::Compatibility::SUCapability.layer_visibility(fake_entity)
end

# 6. Entity returns nil for #layer.
test 'SUCapability.layer_visibility: entity.layer == nil -> :unknown' do
  fake_entity = Class.new do
    def layer; nil; end
  end.new
  assert_equal :unknown,
               SUAnalysis::Compatibility::SUCapability.layer_visibility(fake_entity)
end

# 7. Layer object lacks #visible?.
test 'SUCapability.layer_visibility: layer without #visible? -> :unknown' do
  fake_layer = Class.new do
    # No #visible? method.
  end.new
  fake_entity = Class.new do
    def layer; @l; end
  end.new
  fake_entity.instance_variable_set(:@l, fake_layer)
  assert_equal :unknown,
               SUAnalysis::Compatibility::SUCapability.layer_visibility(fake_entity)
end

# 8. nil entity.
test 'SUCapability.layer_visibility: nil entity -> :unknown' do
  assert_equal :unknown,
               SUAnalysis::Compatibility::SUCapability.layer_visibility(nil)
end
