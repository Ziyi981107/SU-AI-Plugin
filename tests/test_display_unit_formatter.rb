#
# tests/test_display_unit_formatter.rb
#
# Per CodeX Q5: internal raw inch Float; display via Sketchup.format_length
# outside SU; deterministic fallback in tests.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/display_unit_formatter'

include SUAnalysis::Extension

test 'format_length: nil -> 0.0 inch' do
  assert_equal '0.0 inch', DisplayUnitFormatter.format_length(nil)
end

test 'format_length: float uses fallback format outside SU' do
  out = DisplayUnitFormatter.format_length(12.5)
  assert_match(/inch/, out)
  # 4 decimal places.
  assert_equal '12.5000 inch', out
end

test 'format_length: integer coerces to float' do
  out = DisplayUnitFormatter.format_length(10)
  assert_equal '10.0000 inch', out
end

test 'format_length: zero -> 0.0 inch' do
  assert_equal '0.0000 inch', DisplayUnitFormatter.format_length(0)
end

test 'format_length: negative -> negative inches' do
  out = DisplayUnitFormatter.format_length(-5.5)
  assert_equal '-5.5000 inch', out
end

# --- format_all ---------------------------------------------------

test 'format_all: nil -> empty hash' do
  assert_equal({}, DisplayUnitFormatter.format_all(nil))
  assert_equal({}, DisplayUnitFormatter.format_all([]))
end

test 'format_all: extracts length from metadata' do
  issues = [
    { issue_id: 'short_edge|1|1', metadata: { 'length' => 12.5 } },
    { issue_id: 'short_edge|2|1', metadata: { 'length' => 0.01 } },
    { issue_id: 'short_edge|3|1', metadata: {} }
  ]
  out = DisplayUnitFormatter.format_all(issues)
  assert_equal 2, out.length
  assert_match(/inch/, out['short_edge|1|1'])
  assert_match(/inch/, out['short_edge|2|1'])
  assert !out.key?('short_edge|3|1')
end

test 'format_all: supports Symbol and String keys' do
  issues = [
    { issue_id: 'a|1', metadata: { length: 1.5 } },
    { issue_id: 'b|1', metadata: { 'length' => 2.5 } }
  ]
  out = DisplayUnitFormatter.format_all(issues)
  assert out.key?('a|1')
  assert out.key?('b|1')
end
