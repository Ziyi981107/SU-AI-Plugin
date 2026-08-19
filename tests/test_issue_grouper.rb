#
# tests/test_issue_grouper.rb
#
# Pure-Ruby tests for IssueGrouper. Verifies the CodeX Q1 default-open
# policy: open iff any :high in the group; if no :high anywhere,
# open the first non-empty group.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/issue_grouper'

include SUAnalysis::Core

def group_issue(overrides = {})
  base = {
    issue_id:          'duplicate_edge_candidate|default|1',
    issue_type:        'duplicate_edge_candidate',
    severity:          'medium',
    confidence:        'high',
    sources:           [],
    source_entity_ids: [],
    edge_ids:          [],
    location:          nil,
    message:           'm',
    metadata:          {},
    locatable:         true,
    display_length:    nil
  }
  base.merge(overrides)
end

# --- ordering ---

test 'issue_grouper.group: respects canonical order' do
  issues = [
    group_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge'),
    group_issue(issue_id: 'duplicate_edge_candidate|1|1', issue_type: 'duplicate_edge_candidate'),
    group_issue(issue_id: 'open_endpoint|1|1', issue_type: 'open_endpoint')
  ]
  groups = IssueGrouper.group(issues)
  types = groups.map { |g| g[:type] }
  assert_equal ['duplicate_edge_candidate', 'short_edge', 'open_endpoint'], types
end

test 'issue_grouper.group: within-group sort by issue_id ASC' do
  issues = [
    group_issue(issue_id: 'duplicate_edge_candidate|zzz|1', issue_type: 'duplicate_edge_candidate'),
    group_issue(issue_id: 'duplicate_edge_candidate|aaa|1', issue_type: 'duplicate_edge_candidate'),
    group_issue(issue_id: 'duplicate_edge_candidate|mmm|1', issue_type: 'duplicate_edge_candidate')
  ]
  groups = IssueGrouper.group(issues)
  ids = groups[0][:issues].map { |i| i[:issue_id] }
  assert_equal ['duplicate_edge_candidate|aaa|1',
                'duplicate_edge_candidate|mmm|1',
                'duplicate_edge_candidate|zzz|1'], ids
end

# --- default-open policy ---

test 'issue_grouper.group: opens group with any :high' do
  issues = [
    group_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge', severity: 'low'),
    group_issue(issue_id: 'duplicate_edge_candidate|1|1',
               issue_type: 'duplicate_edge_candidate', severity: 'high')
  ]
  groups = IssueGrouper.group(issues)
  dup_g  = groups.find { |g| g[:type] == 'duplicate_edge_candidate' }
  short_g = groups.find { |g| g[:type] == 'short_edge' }
  assert_equal true,  dup_g[:default_open]
  assert_equal false, short_g[:default_open]
end

test 'issue_grouper.group: no :high anywhere -> first non-empty opens' do
  issues = [
    group_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge', severity: 'low'),
    group_issue(issue_id: 'duplicate_edge_candidate|1|1',
               issue_type: 'duplicate_edge_candidate', severity: 'medium')
  ]
  groups = IssueGrouper.group(issues)
  dup_g  = groups.find { |g| g[:type] == 'duplicate_edge_candidate' }
  short_g = groups.find { |g| g[:type] == 'short_edge' }
  assert_equal true,  dup_g[:default_open]   # first non-empty
  assert_equal false, short_g[:default_open]
end

test 'issue_grouper.group: empty input returns empty array' do
  assert_equal [], IssueGrouper.group([])
end

test 'issue_grouper.group: custom group_order honored' do
  issues = [
    group_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge'),
    group_issue(issue_id: 'duplicate_edge_candidate|1|1', issue_type: 'duplicate_edge_candidate')
  ]
  groups = IssueGrouper.group(issues, group_order: ['short_edge', 'duplicate_edge_candidate'])
  types = groups.map { |g| g[:type] }
  assert_equal ['short_edge', 'duplicate_edge_candidate'], types
end

# --- IssueRegistry.groups integration ---

test 'issue_grouper + IssueRegistry: identical policies' do
  issues = [
    group_issue(issue_id: 'short_edge|1|1', issue_type: 'short_edge', severity: 'low'),
    group_issue(issue_id: 'duplicate_edge_candidate|1|1',
               issue_type: 'duplicate_edge_candidate', severity: 'medium')
  ]
  reg = IssueRegistry.new(issues)
  groups_grouper = IssueGrouper.group(issues)
  groups_registry = reg.groups
  assert_equal groups_grouper.map { |g| g[:type] },
               groups_registry.map { |g| g[:type] }
  assert_equal groups_grouper.map { |g| g[:default_open] },
               groups_registry.map { |g| g[:default_open] }
end
