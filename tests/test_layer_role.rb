#
# tests/test_layer_role.rb — pin V1.1 LayerRole enum + visibility_label helper.
#
# Per plan §4.1: 5 name-based roles, no OFFSCREEN, visibility is
# a separate field. visibility_label is the SOURCE OF TRUTH for
# the dialog badge text; JS does not recompute it.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/layer_role'

# 1. Enum surface (5 roles, no OFFSCREEN).
test 'LayerRole: 5 role constants, no OFFSCREEN' do
  defined = %i[CONSTRUCTION DIMENSION ANNOTATION GUIDE UNKNOWN]
  defined.each do |c|
    assert SUAnalysis::Core::LayerRole.const_defined?(c), "missing #{c}"
  end
  assert !SUAnalysis::Core::LayerRole.const_defined?(:OFFSCREEN),
         'OFFSCREEN must NOT be defined (R007 — role/visibility separated)'
end

test 'LayerRole::ALL is locked order: dim, anno, guide, construction, unknown' do
  expected = [:dimension, :annotation, :guide, :construction, :unknown]
  assert_equal expected, SUAnalysis::Core::LayerRole::ALL
end

test 'LayerRole::HUMAN has exactly 5 keys, all 5 role Symbols present' do
  human = SUAnalysis::Core::LayerRole::HUMAN
  assert_equal 5, human.size
  expected = [:dimension, :annotation, :guide, :construction, :unknown]
  expected.each do |r|
    assert human.key?(r), "HUMAN missing #{r}"
  end
end

test 'LayerRole::HUMAN labels are the locked UI strings' do
  human = SUAnalysis::Core::LayerRole::HUMAN
  assert_equal 'Dimension',    human[:dimension]
  assert_equal 'Annotation',   human[:annotation]
  assert_equal 'Guide',        human[:guide]
  assert_equal 'Construction', human[:construction]
  assert_equal 'Unknown',      human[:unknown]
end

# 2. Visibility helpers (R007 / R011).
test 'LayerRole::VISIBILITY_HUMAN has exactly 2 keys' do
  v = SUAnalysis::Core::LayerRole::VISIBILITY_HUMAN
  assert_equal 2, v.size
  assert_equal 'Visible',    v[true]
  assert_equal 'Off-screen', v[false]
end

test 'LayerRole::VISIBILITY_UNKNOWN_HUMAN is the locked "Visibility: unknown" string' do
  assert_equal 'Visibility: unknown',
               SUAnalysis::Core::LayerRole::VISIBILITY_UNKNOWN_HUMAN
end

# 3. visibility_label composition (R011: uncertainty wins over operational value).
test 'LayerRole.visibility_label: (true, false) -> "Visible"' do
  assert_equal 'Visible',
               SUAnalysis::Core::LayerRole.visibility_label(true, false)
end

test 'LayerRole.visibility_label: (false, false) -> "Off-screen"' do
  assert_equal 'Off-screen',
               SUAnalysis::Core::LayerRole.visibility_label(false, false)
end

test 'LayerRole.visibility_label: (true, true) -> "Visibility: unknown" (R011)' do
  # R011: uncertainty wins over operational value.
  assert_equal 'Visibility: unknown',
               SUAnalysis::Core::LayerRole.visibility_label(true, true)
end

test 'LayerRole.visibility_label: (false, true) -> "Visibility: unknown" (R011)' do
  # R011: uncertainty wins over operational value, even if operational is hidden.
  assert_equal 'Visibility: unknown',
               SUAnalysis::Core::LayerRole.visibility_label(false, true)
end
