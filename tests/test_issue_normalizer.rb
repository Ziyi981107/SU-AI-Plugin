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

# --------------------------------------------------------------------------
# CodeX Round 020 REAL-HOST BLOCK (recheck): regression tests for the
# production-path call form (NO `include`). The previous fix used
# `private` after `module_function`, making helpers private instance
# methods ONLY (not module singleton methods). This was masked by the
# test file doing `include SUAnalysis::Core::IssueNormalizer`, which
# pulled the helpers into Object's ancestor chain and made them
# reachable from any Module's method dispatch (including
# SUAnalysis::Core::IssueNormalizer itself).
#
# On the real production path (extension/analyzers_runner.rb calls
# `SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)`
# with no prior `include`), the implicit-self call to
# `normalize_location(...)` raised
# `NoMethodError: undefined method 'normalize_location' for
# SUAnalysis::Core::IssueNormalizer:Module`. The K2 real-SU2020
# duplicate analysis crashed on the FIRST issue with a non-nil 3D
# location.
#
# The fix: helpers are now defined after `module_function` so they
# ARE module singleton methods (callable from production); they are
# marked `private_class_method` at the bottom of the module to keep
# the original "private" intent (not part of public API).
#
# These tests exercise the fully-qualified production call form to
# catch any regression of the module-singleton dispatch path.
# --------------------------------------------------------------------------

# Call the public API through the FULLY QUALIFIED production form
# (no `include` of IssueNormalizer in scope). This is the exact form
# used by extension/analyzers_runner.rb.
test 'issue_normalizer (production path): normalize_analyzer_issue with non-nil 3D location via M.xxx' do
  raw = {
    kind:              'duplicate_edge_candidate',
    severity:          'medium',
    confidence:        'high',
    source_entity_ids: [10, 20],
    edge_ids:          [1, 2],
    location:          [100.0, 200.0, 0.0],
    message:           'duplicate edges',
    metadata:          { 'foo' => 'bar', 'count' => 2 }
  }
  result = SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)
  refute_nil result
  assert_equal 'duplicate_edge_candidate', result[:issue_type]
  assert_equal 'medium',                  result[:severity]
  assert_equal [100.0, 200.0, 0.0],       result[:location],
               'non-nil 3D location must survive normalize_location dispatch (the bug)'
  assert_equal 'duplicate edges',         result[:message]
  assert_equal({ 'foo' => 'bar', 'count' => 2 }, result[:metadata],
               'metadata must survive normalize_metadata dispatch')
end

test 'issue_normalizer (production path): normalize_analyzer_issue with non-Hash location components' do
  # Integer location components (not Float) must be coerced via Float().
  raw = {
    kind: 'open_endpoint', severity: 'medium', confidence: 'high',
    source_entity_ids: [1], edge_ids: [1],
    location: [1, 2, 3],   # Integer components, not Float
    message: 'open', metadata: {}
  }
  result = SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)
  refute_nil result
  assert_equal [1.0, 2.0, 3.0], result[:location]
end

test 'issue_normalizer (production path): normalize_analyzer_issue with non-nil metadata Hash' do
  # metadata must reach normalize_metadata (the bug was masked when
  # metadata was {}).
  raw = {
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [], edge_ids: [],
    location: nil,
    message: 'short edge',
    metadata: { 'k1' => 'v1', 'k2' => 42, 'k3' => true }
  }
  result = SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)
  refute_nil result
  assert_equal({ 'k1' => 'v1', 'k2' => 42, 'k3' => true }, result[:metadata],
               'metadata Hash must round-trip via normalize_metadata dispatch')
end

test 'issue_normalizer (production path): normalize_analyzer_issue with control-character message' do
  # message must reach sanitize_message (the bug was masked when
  # message had no control characters).
  raw = {
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [], edge_ids: [],
    location: nil,
    message: "short\x00\x07edge\x1Ftest",
    metadata: {}
  }
  result = SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)
  refute_nil result
  assert_equal 'shortedgetest', result[:message],
               'sanitize_message must be reachable via production dispatch'
end

test 'issue_normalizer (production path): normalize_preflight_warnings with all 3 codes' do
  # Full production-path test for the preflight normalization
  # branch (the OTHER public API besides normalize_analyzer_issue).
  warnings = [
    { code: :significant_non_zero_z, message: 'z off', severity: :medium },
    { code: :abnormal_large_coord,   message: 'big',   severity: :high },
    { code: :deep_nesting,           message: 'deep',  severity: :low }
  ]
  result = SUAnalysis::Core::IssueNormalizer.normalize_preflight_warnings(warnings)
  assert_equal 3, result.length
  assert_equal 'significant_non_zero_z', result[0][:issue_type]
  assert_equal 'medium',                  result[0][:severity]
  assert_equal 'abnormal_large_coord',   result[1][:issue_type]
  assert_equal 'high',                    result[1][:severity]
  assert_equal 'deep_nesting',           result[2][:issue_type]
  assert_equal 'low',                     result[2][:severity]
  # All preflight hazards carry the code in their metadata so the
  # UI bridge / downstream can distinguish them from analyzer-side
  # issues. This dispatches through sanitize_message too (the bug
  # would have masked this when messages were empty / nil).
  assert_equal 'z off', result[0][:message]
  assert_equal 'big',   result[1][:message]
  assert_equal 'deep',  result[2][:message]
end

test 'issue_normalizer (production path): normalize_preflight_warnings with unknown code returns []' do
  # Branch: canonical_preflight_code returns nil -> filtered out.
  warnings = [
    { code: :unknown_thing, message: 'm', severity: :medium }
  ]
  result = SUAnalysis::Core::IssueNormalizer.normalize_preflight_warnings(warnings)
  assert_equal 0, result.length
end

test 'issue_normalizer (production path): helpers are private module methods' do
  # The fix uses `private_class_method` to keep the original `private`
  # intent: helpers must NOT be callable from outside the module
  # (they are internal). This test pins that contract.
  #
  # Per CodeX Round 020 REAL-HOST BLOCK recheck: the bug was that
  # helpers were NOT module singleton methods at all (the `private`
  # keyword suppressed `module_function`). After the fix, helpers
  # ARE module singleton methods but PRIVATE.
  #
  # We probe via `methods(false)` (public methods only) and
  # `private_methods` (private methods), which are independent of
  # any include chain (so this test is not affected by the include
  # at the top of this test file).
  helpers = [:normalize_location, :sanitize_message, :normalize_metadata,
             :canonical_preflight_code, :severity_for_preflight]

  # Helpers are NOT in the public methods list (which `M.xxx` uses
  # without explicit receiver in production code).
  public_methods = SUAnalysis::Core::IssueNormalizer.methods(false)
  helpers.each do |helper_name|
    assert !public_methods.include?(helper_name),
           "helper #{helper_name} must NOT be in M.methods(false) (i.e., must not be public)"
  end

  # Helpers ARE in private_methods (private_class_method'd methods
  # appear here; they are reachable via respond_to?(:name, true)
  # and via send, but raise NoMethodError on direct call from outside).
  private_methods_list = SUAnalysis::Core::IssueNormalizer.private_methods
  helpers.each do |helper_name|
    assert private_methods_list.include?(helper_name),
           "helper #{helper_name} must be in M.private_methods after private_class_method"
    assert SUAnalysis::Core::IssueNormalizer.respond_to?(helper_name, true),
           "helper #{helper_name} must be reachable via respond_to?(name, true)"
  end
end

test 'issue_normalizer (production path): public API remains public module methods' do
  # After the fix, the public API methods are still PUBLIC module
  # methods (callable via fully-qualified form from production).
  public_methods = %i[normalize_analyzer_issue normalize_preflight_warning
                      normalize_preflight_warnings canonical_severity
                      severity_for_type]
  public_methods.each do |m|
    assert SUAnalysis::Core::IssueNormalizer.respond_to?(m),
           "public API #{m} should remain callable as a public module method"
  end
end

# --------------------------------------------------------------------------
# CodeX Round 020 REAL-HOST BLOCK (recheck) K2: full K2 real-SU2020
# duplicate repro at the IssueNormalizer layer. The K2 Owner repro
# is: select two coincident component instances in fresh SU2020;
# Analyze selection crashes with NoMethodError because the first
# duplicate issue has a non-nil 3D location that dispatches to
# normalize_location, which is unreachable on the production call
# path. This test reproduces the K2 scenario end-to-end through
# the fully-qualified production form (no include).
# --------------------------------------------------------------------------

test 'issue_normalizer (K2 real-SU2020 repro): full production-path duplicate analysis' do
  # Mimic the duplicate analyzer's raw Hash. This is the exact shape
  # produced by extension/analyzers/core/analyzers/duplicate_detector.rb
  # on a real coincident-edges case (e.g., shared ComponentDefinition
  # with two world-coincident occurrences).
  raw_duplicate_issue = {
    kind:              'duplicate_edge_candidate',
    severity:          'medium',
    confidence:        'high',
    source_entity_ids: [501, 502],
    edge_ids:          [100, 101],
    # K2: non-nil 3D location — the bug crashes here.
    location:          [200.0, 0.0, 0.0],
    message:           'duplicate edge candidate (occ_a + occ_b)',
    metadata:          { 'tolerance' => 0.001, 'count' => 2 }
  }

  # Production call form (no include in scope).
  result = SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw_duplicate_issue)
  refute_nil result, 'production call must NOT crash on a duplicate with non-nil location'
  assert_equal 'duplicate_edge_candidate', result[:issue_type]
  assert_equal 'medium',                  result[:severity]
  assert_equal 'high',                    result[:confidence]
  assert_equal [501, 502],                result[:source_entity_ids]
  assert_equal [100, 101],                result[:edge_ids]
  assert_equal [200.0, 0.0, 0.0],         result[:location]
  assert_equal 'duplicate edge candidate (occ_a + occ_b)', result[:message]
  assert_equal({ 'tolerance' => 0.001, 'count' => 2 }, result[:metadata])
end

test 'issue_normalizer (K2 real-SU2020 repro): production path survives batch normalization' do
  # Mimic the full pre-normalization batch: a list of mixed analyzer
  # issues (some with locations, some without; some with metadata,
  # some without). This is what extension/analyzers_runner.rb
  # actually feeds into the normalizer after the analyzer stage.
  raw_issues = [
    # K2 issue #1: duplicate with non-nil 3D location
    {
      kind: 'duplicate_edge_candidate', severity: 'medium', confidence: 'high',
      source_entity_ids: [501, 502], edge_ids: [100, 101],
      location: [200.0, 0.0, 0.0],
      message: 'dup', metadata: { 'k' => 'v' }
    },
    # No-location issue (was the only kind that worked before)
    {
      kind: 'short_edge', severity: 'low', confidence: 'medium',
      source_entity_ids: [1], edge_ids: [1], location: nil,
      message: 'short', metadata: {}
    },
    # Another non-nil location issue
    {
      kind: 'open_endpoint', severity: 'medium', confidence: 'high',
      source_entity_ids: [2], edge_ids: [2], location: [10.0, 5.0, 0.0],
      message: 'open', metadata: {}
    }
  ]

  # Production call form: simulate analyzers_runner.rb iterating
  # through raw_issues and normalizing each.
  normalized = []
  raw_issues.each do |raw|
    out = SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)
    normalized << out if out
  end

  assert_equal 3, normalized.length,
  'every raw issue must survive normalization on the production call form'
  assert_equal [200.0, 0.0, 0.0],  normalized[0][:location],
  'K2: duplicate with non-nil location must survive'
  assert_equal nil,                 normalized[1][:location],
  'short_edge (no location) must remain nil'
  assert_equal [10.0, 5.0, 0.0],   normalized[2][:location],
  'open_endpoint with non-nil location must survive'
end
