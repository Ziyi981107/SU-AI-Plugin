#
# tests/test_issue_normalizer.rb
#
# Pure-Ruby tests for analyzer/preflight issue normalization.
# Verifies that the canonical severity string (low/medium/high) is
# produced and the R005 per-type mapping is applied.
#

require_relative 'runner'
require_relative '../core/issue_normalizer'

include SUAnalysis::Core::IssueNormalizer

# --- analyzer normalize ---

test 'issue_normalizer: normalizes analyzer Hash (kind -> issue_type)' do
  raw = {
    kind:              'duplicate_edge_candidate',
    severity:          'medium',
    confidence:        'high',
    source_entity_ids: [10, 20],
    edge_ids:          [1, 2],
    location:          [100.0, 0.0, 0.0],
    message:           'duplicate',
    metadata:          { 'foo' => 'bar' }
  }
  result = normalize_analyzer_issue(raw)
  assert_equal 'duplicate_edge_candidate', result[:issue_type]
  assert_equal 'medium',                  result[:severity]
  assert_equal 'high',                    result[:confidence]
  assert_equal [10, 20],                  result[:source_entity_ids]
  assert_equal [1, 2],                    result[:edge_ids]
  assert_equal [100.0, 0.0, 0.0],         result[:location]
  assert_equal 'duplicate',               result[:message]
end

test 'issue_normalizer: per-type severity mapping applied (R005)' do
  raw = {
    kind: 'short_edge', severity: 'high',  # analyzer says high, but R005 says short_edge -> low
    confidence: 'high',
    source_entity_ids: [],
    edge_ids: [],
    location: nil,
    message: 'short',
    metadata: {}
  }
  result = normalize_analyzer_issue(raw)
  assert_equal 'low', result[:severity]
end

test 'issue_normalizer: Symbol severity is normalized to String' do
  raw = {
    kind: 'duplicate_edge_candidate',
    severity: :medium,  # Symbol
    confidence: :high,
    source_entity_ids: [],
    edge_ids: [],
    location: nil,
    message: 'm',
    metadata: {}
  }
  result = normalize_analyzer_issue(raw)
  assert_equal 'medium', result[:severity]
  assert_equal 'high',   result[:confidence]
end

test 'issue_normalizer: missing kind returns nil' do
  raw = { severity: 'medium', source_entity_ids: [], edge_ids: [],
          location: nil, message: 'm', metadata: {} }
  assert_nil normalize_analyzer_issue(raw)
end

test 'issue_normalizer: non-Hash input returns nil' do
  assert_nil normalize_analyzer_issue('nope')
  assert_nil normalize_analyzer_issue(nil)
end

# --- preflight normalize ---

test 'issue_normalizer: preflight warnings -> issues (3 codes)' do
  warnings = [
    { code: :significant_non_zero_z, message: 'z off', severity: :medium },
    { code: :abnormal_large_coord,   message: 'big',   severity: :high },
    { code: :deep_nesting,           message: 'deep',  severity: :low }
  ]
  result = normalize_preflight_warnings(warnings)
  assert_equal 3, result.length
  assert_equal 'significant_non_zero_z', result[0][:issue_type]
  assert_equal 'medium',                  result[0][:severity]
  assert_equal 'abnormal_large_coord',   result[1][:issue_type]
  assert_equal 'high',                    result[1][:severity]
  assert_equal 'deep_nesting',           result[2][:issue_type]
  assert_equal 'low',                     result[2][:severity]
  # All preflight hazards are NON-locatable (no source path).
  # (locatable is filled in by IssueEnricher; this is just the
  # enrichment input from the normalizer.)
  assert_equal [], result[0][:source_entity_ids]
  assert_equal [], result[0][:edge_ids]
  assert_equal nil, result[0][:location]
end

test 'issue_normalizer: unknown preflight code is dropped' do
  warnings = [
    { code: :unknown_thing, message: 'm', severity: :medium }
  ]
  result = normalize_preflight_warnings(warnings)
  assert_equal 0, result.length
end

test 'issue_normalizer: control characters stripped from message' do
  raw = {
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [], edge_ids: [], location: nil,
    message: "short\x00\x07edge\x1Ftest", metadata: {}
  }
  result = normalize_analyzer_issue(raw)
  # \x00, \x07, \x1F are all stripped; "shortedge" + "test" remains.
  assert_equal 'shortedgetest', result[:message]
end

test 'issue_normalizer: UTF-8 preserved in message' do
  raw = {
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [], edge_ids: [], location: nil,
    message: '短边检测 (中文) — OK', metadata: {}
  }
  result = normalize_analyzer_issue(raw)
  assert_equal '短边检测 (中文) — OK', result[:message]
end
