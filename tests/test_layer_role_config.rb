#
# tests/test_layer_role_config.rb — pin V1.1 LayerRoleConfig rules (R010 priority).
#
# Per plan §4.2 / R010:
#   - classify(name) returns (role, rule_id).
#   - RULES is in declared order; first match wins.
#   - Top-down-by-priority, NOT by-specificity.
#   - Test pin: a layer matching two rules gets the FIRST rule's role
#     (e.g. "DIM-ANNO" -> :dimension, not :annotation).
#   - 5 name-based rules + default :unknown.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/layer_role'
require_relative '../extension/su_ai_plugin/core/layer_role_config'

# 1. Name-based classification (positive cases).
test 'LayerRoleConfig.classify: "DIM-XX" -> dimension' do
  assert_equal [:dimension, 'name_dimension'],
               SUAnalysis::Core::LayerRoleConfig.classify('DIM-XX')
end

test 'LayerRoleConfig.classify: case-insensitive (dim-xx)' do
  assert_equal [:dimension, 'name_dimension'],
               SUAnalysis::Core::LayerRoleConfig.classify('dim-xx')
end

test 'LayerRoleConfig.classify: "TEXT-NOTES" -> annotation' do
  assert_equal [:annotation, 'name_annotation'],
               SUAnalysis::Core::LayerRoleConfig.classify('TEXT-NOTES')
end

test 'LayerRoleConfig.classify: "LABEL" -> annotation' do
  assert_equal [:annotation, 'name_annotation'],
               SUAnalysis::Core::LayerRoleConfig.classify('LABEL')
end

test 'LayerRoleConfig.classify: "GUIDE-LINES" -> guide' do
  assert_equal [:guide, 'name_guide'],
               SUAnalysis::Core::LayerRoleConfig.classify('GUIDE-LINES')
end

test 'LayerRoleConfig.classify: "XLINE" -> guide' do
  assert_equal [:guide, 'name_guide'],
               SUAnalysis::Core::LayerRoleConfig.classify('XLINE')
end

# 2. Default layer exact match.
test 'LayerRoleConfig.classify: "Layer0" -> construction (default)' do
  assert_equal [:construction, 'name_default_layer'],
               SUAnalysis::Core::LayerRoleConfig.classify('Layer0')
end

test 'LayerRoleConfig.classify: "default" -> construction (case-insensitive)' do
  assert_equal [:construction, 'name_default_layer'],
               SUAnalysis::Core::LayerRoleConfig.classify('default')
end

test 'LayerRoleConfig.classify: "Untagged" -> construction' do
  assert_equal [:construction, 'name_default_layer'],
               SUAnalysis::Core::LayerRoleConfig.classify('Untagged')
end

# 3. Negative / no-match.
test 'LayerRoleConfig.classify: "WEIRD-LAYER" -> unknown' do
  assert_equal [:unknown, 'name_no_match'],
               SUAnalysis::Core::LayerRoleConfig.classify('WEIRD-LAYER')
end

test 'LayerRoleConfig.classify: "" -> unknown' do
  assert_equal [:unknown, 'name_no_match'],
               SUAnalysis::Core::LayerRoleConfig.classify('')
end

test 'LayerRoleConfig.classify: nil -> ArgumentError (defensive)' do
  assert_raises(ArgumentError) do
    SUAnalysis::Core::LayerRoleConfig.classify(nil)
  end
end

# 4. R010 priority test — top-down-by-priority, NOT by-specificity.
test 'LayerRoleConfig.classify R010: "DIM-ANNO" -> dimension (NOT annotation)' do
  # This name matches BOTH the dim glob and the anno glob.
  # R010: the dim rule comes FIRST in RULES, so it wins.
  # If this test fails, someone re-ordered RULES without
  # thinking about R010.
  assert_equal [:dimension, 'name_dimension'],
               SUAnalysis::Core::LayerRoleConfig.classify('DIM-ANNO')
end

test 'LayerRoleConfig.classify R010: "TEXT-DIM-XX" -> dimension (NOT annotation)' do
  # This name matches BOTH the anno glob (TEXT) and the dim glob (DIM).
  # R010: the dim rule comes FIRST in RULES, so it wins. Rule order
  # is the priority, not the substring position in the name. This is
  # the whole point of "top-down-by-priority, not by-specificity".
  assert_equal [:dimension, 'name_dimension'],
               SUAnalysis::Core::LayerRoleConfig.classify('TEXT-DIM-XX')
end

# 5. RULES is frozen / order is canonical.
test 'LayerRoleConfig::RULES is in declared order (R010 canonical priority)' do
  rule_ids = SUAnalysis::Core::LayerRoleConfig::RULES.map { |r| r[:rule_id] }
  expected = ['name_dimension', 'name_annotation', 'name_guide', 'name_default_layer']
  assert_equal expected, rule_ids
end

test 'LayerRoleConfig: DEFAULT_ROLE and DEFAULT_RULE_ID are locked' do
  assert_equal SUAnalysis::Core::LayerRole::UNKNOWN,
               SUAnalysis::Core::LayerRoleConfig::DEFAULT_ROLE
  assert_equal 'name_no_match', SUAnalysis::Core::LayerRoleConfig::DEFAULT_RULE_ID
end
