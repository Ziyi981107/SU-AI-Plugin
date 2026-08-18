#
# tests/test_issue_registry.rb
#
# Pure-Ruby tests for IssueRegistry construction, validation,
# tolerant drop, summary, and groups.
#

require_relative 'runner'
require_relative '../core/issue_registry'

include SUAnalysis::Core

# --- helpers ----------------------------------------------------------

def reg_issue(overrides = {})
  base = {
    issue_id:          'duplicate_edge_candidate|10.20.555|1',
    issue_type:        'duplicate_edge_candidate',
    severity:          'medium',
    confidence:        'high',
    sources:           [
      { persistent_id_path: [10, 20, 555], entity_id: 1,
        nested: true, pid_path_complete: true }
    ],
    source_entity_ids: [1],
    edge_ids:          [1, 2],
    location:          [10.0, 0.0, 0.0],
    message:           'test',
    metadata:          {},
    locatable:         true,
    display_length:    nil
  }
  base.merge(overrides)
end

# --- validation accepts ---

test 'issue_registry: accepts a well-formed issue' do
  reg = IssueRegistry.new([reg_issue])
  assert_equal 1, reg.size
  assert_equal 0, reg.diagnostics.length
end

test 'issue_registry: accepts mixed types in one batch' do
  issues = [
    reg_issue(issue_id: 'duplicate_edge_candidate|10.20|1', issue_type: 'duplicate_edge_candidate'),
    reg_issue(issue_id: 'short_edge|10.20|1', issue_type: 'short_edge', severity: 'low'),
    reg_issue(issue_id: 'open_endpoint|10.20|1', issue_type: 'open_endpoint', severity: 'medium')
  ]
  reg = IssueRegistry.new(issues)
  assert_equal 3, reg.size
  assert_equal 0, reg.diagnostics.length
end

# --- validation rejects + tolerant drop ---

test 'issue_registry: drops issue with missing key, others kept' do
  bad = reg_issue(severity: nil)  # missing ... wait, severity is required
  bad.delete(:severity)
  good = reg_issue(issue_id: 'short_edge|10.20|1', issue_type: 'short_edge', severity: 'low')
  reg = IssueRegistry.new([bad, good])
  assert_equal 1, reg.size
  assert_equal 1, reg.diagnostics.length
  assert_match(/missing key :severity/, reg.diagnostics[0][:message])
end

test 'issue_registry: drops issue with non-canonical severity' do
  bad = reg_issue(severity: 'warning')
  reg = IssueRegistry.new([bad])
  assert_equal 0, reg.size
  assert_equal 1, reg.diagnostics.length
  assert_match(/non-canonical severity/, reg.diagnostics[0][:message])
end

test 'issue_registry: drops issue with non-Array sources' do
  bad = reg_issue
  bad[:sources] = 'not-an-array'
  reg = IssueRegistry.new([bad])
  assert_equal 0, reg.size
  assert_equal 1, reg.diagnostics.length
end

test 'issue_registry: drops issue with non-Boolean locatable' do
  bad = reg_issue(locatable: 'yes')
  reg = IssueRegistry.new([bad])
  assert_equal 0, reg.size
  assert_equal 1, reg.diagnostics.length
end

test 'issue_registry: drops issue with wrong location shape' do
  bad = reg_issue(location: [10.0, 0.0])
  reg = IssueRegistry.new([bad])
  assert_equal 0, reg.size
  assert_equal 1, reg.diagnostics.length
end

test 'issue_registry: drops non-Hash input' do
  reg = IssueRegistry.new(['not a hash'])
  assert_equal 0, reg.size
  assert_equal 1, reg.diagnostics.length
end

# --- summary ---

test 'issue_registry.summary: counts per issue_type' do
  issues = [
    reg_issue(issue_id: 'duplicate_edge_candidate|1|1', issue_type: 'duplicate_edge_candidate'),
    reg_issue(issue_id: 'duplicate_edge_candidate|2|1', issue_type: 'duplicate_edge_candidate'),
    reg_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge', severity: 'low')
  ]
  reg = IssueRegistry.new(issues)
  assert_equal 2, reg.summary['duplicate_edge_candidate']
  assert_equal 1, reg.summary['short_edge']
  assert_equal 0, reg.summary['open_endpoint']
end

# --- open? ---

test 'issue_registry.open?: true iff any :high' do
  reg = IssueRegistry.new([
    reg_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge', severity: 'low'),
    reg_issue(issue_id: 'abnormal_large_coord|1|1', issue_type: 'abnormal_large_coord', severity: 'high')
  ])
  assert_equal true, reg.open?
end

test 'issue_registry.open?: false when no :high' do
  reg = IssueRegistry.new([
    reg_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge', severity: 'low')
  ])
  assert_equal false, reg.open?
end

# --- find ---

test 'issue_registry.find: returns matching issue' do
  iss = reg_issue(issue_id: 'duplicate_edge_candidate|10.20|1')
  reg = IssueRegistry.new([iss])
  assert_equal iss, reg.find('duplicate_edge_candidate|10.20|1')
  assert_nil reg.find('does-not-exist')
  assert_nil reg.find(nil)
end

# --- groups ---

test 'issue_registry.groups: ordered by canonical order, count per group' do
  issues = [
    reg_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge', severity: 'low'),
    reg_issue(issue_id: 'duplicate_edge_candidate|1|1', issue_type: 'duplicate_edge_candidate'),
    reg_issue(issue_id: 'duplicate_edge_candidate|2|1', issue_type: 'duplicate_edge_candidate')
  ]
  reg = IssueRegistry.new(issues)
  groups = reg.groups
  assert_equal 'duplicate_edge_candidate', groups[0][:type]
  assert_equal 2, groups[0][:count]
  assert_equal 'short_edge', groups[1][:type]
  assert_equal 1, groups[1][:count]
end

test 'issue_registry.groups: default_open iff any :high' do
  issues = [
    reg_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge', severity: 'low'),
    reg_issue(issue_id: 'duplicate_edge_candidate|1|1',
               issue_type: 'duplicate_edge_candidate', severity: 'high')
  ]
  reg = IssueRegistry.new(issues)
  groups = reg.groups
  dup_g = groups.find { |g| g[:type] == 'duplicate_edge_candidate' }
  short_g = groups.find { |g| g[:type] == 'short_edge' }
  assert_equal true, dup_g[:default_open]
  assert_equal false, short_g[:default_open]
end

test 'issue_registry.groups: when no :high, first non-empty group opens' do
  issues = [
    reg_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge', severity: 'low'),
    reg_issue(issue_id: 'duplicate_edge_candidate|1|1',
               issue_type: 'duplicate_edge_candidate', severity: 'medium')
  ]
  reg = IssueRegistry.new(issues)
  groups = reg.groups
  dup_g = groups.find { |g| g[:type] == 'duplicate_edge_candidate' }
  short_g = groups.find { |g| g[:type] == 'short_edge' }
  # First non-empty group opens.
  assert_equal true, dup_g[:default_open]
  assert_equal false, short_g[:default_open]
end

test 'issue_registry.groups: within-group sort by issue_id ASC' do
  issues = [
    reg_issue(issue_id: 'duplicate_edge_candidate|zzz|1', issue_type: 'duplicate_edge_candidate'),
    reg_issue(issue_id: 'duplicate_edge_candidate|aaa|1', issue_type: 'duplicate_edge_candidate'),
    reg_issue(issue_id: 'duplicate_edge_candidate|mmm|1', issue_type: 'duplicate_edge_candidate')
  ]
  reg = IssueRegistry.new(issues)
  groups = reg.groups
  issue_ids = groups[0][:issues].map { |i| i[:issue_id] }
  assert_equal ['duplicate_edge_candidate|aaa|1',
                'duplicate_edge_candidate|mmm|1',
                'duplicate_edge_candidate|zzz|1'], issue_ids
end
