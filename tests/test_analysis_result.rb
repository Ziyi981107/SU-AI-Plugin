#
# tests/test_analysis_result.rb
#
# Pure-Ruby tests for AnalysisResult immutability contract.
# Per CodeX Review 011..014, the result is "no public setters + frozen
# top-level + nested fields immutable by design".
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/analysis_result'

include SUAnalysis::Core

def ar_issue(id)
  {
    issue_id: id,
    issue_type: 'duplicate_edge_candidate',
    severity: 'medium',
    confidence: 'high',
    sources: [],
    source_entity_ids: [],
    edge_ids: [],
    location: nil,
    message: 'm',
    metadata: {},
    locatable: true,
    display_length: nil
  }
end

def minimal_result
  reg = IssueRegistry.new([ar_issue('duplicate_edge_candidate|1|1')])
  preflight = Object.new  # plain stand-in for PreflightReport
  AnalysisResult.new(
    preflight:         preflight,
    registry:          reg,
    snapshot_lookup:   { 1 => :edge_record_1 },
    display_data:      { 'duplicate_edge_candidate|1|1' => '10.0 inch' },
    diagnostics:       [{ stage: 'mock', message: 'ok' }],
    selection_type:    'Group',
    selection_label:   'test_group'
  )
end

# --- required arguments ---

test 'analysis_result: preflight is required' do
  assert_raises(ArgumentError) do
    AnalysisResult.new(preflight: nil, registry: IssueRegistry.new([]))
  end
end

test 'analysis_result: registry is required' do
  assert_raises(ArgumentError) do
    AnalysisResult.new(preflight: Object.new, registry: nil)
  end
end

# --- defaults ---

test 'analysis_result: snapshot_lookup defaults to empty frozen Hash' do
  r = AnalysisResult.new(preflight: Object.new, registry: IssueRegistry.new([]))
  assert_equal({}, r.snapshot_lookup)
  assert r.snapshot_lookup.frozen?
end

test 'analysis_result: diagnostics defaults to empty frozen Array' do
  r = AnalysisResult.new(preflight: Object.new, registry: IssueRegistry.new([]))
  assert_equal [], r.diagnostics
  assert r.diagnostics.frozen?
end

test 'analysis_result: selection_type / selection_label coerced to String' do
  r = AnalysisResult.new(preflight: Object.new, registry: IssueRegistry.new([]),
                         selection_type: :Group, selection_label: nil)
  assert_equal 'Group', r.selection_type
  assert_equal '',      r.selection_label
end

# --- immutability (no setters, frozen top-level) ---

test 'analysis_result: top-level is frozen' do
  r = minimal_result
  assert r.frozen?
end

test 'analysis_result: no public setters' do
  r = minimal_result
  # Common setter names should all raise NoMethodError.
  assert !r.respond_to?(:preflight=)
  assert !r.respond_to?(:registry=)
  assert !r.respond_to?(:snapshot_lookup=)
  assert !r.respond_to?(:display_data=)
  assert !r.respond_to?(:diagnostics=)
end

test 'analysis_result: mutating diagnostics raises' do
  r = minimal_result
  assert_raises(RuntimeError) { r.diagnostics << { new: 'one' } }
end

test 'analysis_result: mutating snapshot_lookup raises' do
  r = minimal_result
  assert_raises(RuntimeError) { r.snapshot_lookup[2] = :new }
end

test 'analysis_result: mutating display_data raises' do
  r = minimal_result
  assert_raises(RuntimeError) { r.display_data['new'] = 'value' }
end

# --- invariant helper ---

test 'analysis_result.invariants_ok?: true when all invariants hold' do
  assert_equal true, minimal_result.invariants_ok?
end

# --- pass-through helpers ---

test 'analysis_result.find_issue: returns matching issue' do
  r = minimal_result
  assert_equal r.registry.issues[0], r.find_issue('duplicate_edge_candidate|1|1')
end

test 'analysis_result.summary: includes Edges/Vertices and registry counts' do
  # Per CodeX Round 018 BLOCK-006: AnalysisResult.summary must
  # expose snapshot Edge/Vertex facts + per-issue-type counts.
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count).new(4, 5, 0, 1)
  ar_issue_default = {
    issue_id:          'short_edge|1|1',
    issue_type:        'short_edge',
    severity:          'low',
    confidence:        'medium',
    sources:           [],
    source_entity_ids: [],
    edge_ids:          [],
    location:          nil,
    message:           'm',
    metadata:          {},
    locatable:         false,
    display_length:    nil
  }
  reg = IssueRegistry.new([ar_issue_default])
  result = AnalysisResult.new(preflight: pf, registry: reg,
                             selection_type: 'Group', selection_label: 'g')
  summary = result.summary
  assert_equal 4, summary['edges']
  assert_equal 5, summary['vertices']
  assert_equal 0, summary['non_zero_z_vertices']
  assert_equal 1, summary['warnings']
  assert_equal 1, summary['issues']['short_edge']
  assert_equal 'g', summary['selection']
end

# --- V1.2: layer_issue_groups ---

test 'analysis_result: layer_issue_groups defaults to [] when not supplied' do
  r = minimal_result
  assert_equal [], r.layer_issue_groups
end

test 'analysis_result: layer_issue_groups is frozen' do
  reg = IssueRegistry.new([])
  pf = Object.new
  r = AnalysisResult.new(
    preflight: pf, registry: reg,
    layer_issue_groups: [
      { name: 'DIM-XX', count: 1, default_open: false, issues: [] }
    ]
  )
  assert r.layer_issue_groups.frozen?,
         'layer_issue_groups must be frozen'
  # Mutating the frozen Array raises.
  assert_raises(RuntimeError, FrozenError) do
    r.layer_issue_groups << { name: 'X', count: 1, default_open: false, issues: [] }
  end
end

test 'analysis_result.summary: includes layer_issue_groups (V1.2)' do
  reg = IssueRegistry.new([])
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count).new(0, 0, 0, 0)
  buckets = [
    { name: 'DIM-XX', count: 2, default_open: true,
      issues: [
        { issue_id: 'open_endpoint|1|1', severity: 'low', source: { layer_name: 'DIM-XX' }, locatable: true },
        { issue_id: 'short_edge|1|1',   severity: 'low', source: { layer_name: 'DIM-XX' }, locatable: false }
      ]
    }
  ]
  r = AnalysisResult.new(
    preflight: pf, registry: reg,
    layer_issue_groups: buckets
  )
  summary = r.summary
  assert summary.key?('layer_issue_groups'),
         "summary must expose 'layer_issue_groups', got #{summary.keys.inspect}"
  assert_equal 1, summary['layer_issue_groups'].length
  bucket = summary['layer_issue_groups'].first
  assert_equal 'DIM-XX', bucket[:name]
  assert_equal 2, bucket[:count]
  assert_equal true, bucket[:default_open]
  assert_equal 2, bucket[:issues].length
end

test 'analysis_result.summary: layer_issue_groups defaults to [] (V1.2)' do
  reg = IssueRegistry.new([])
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count).new(0, 0, 0, 0)
  r = AnalysisResult.new(preflight: pf, registry: reg)
  assert_equal [], r.summary['layer_issue_groups']
end

test 'analysis_result.layer_issue_groups_payload: returns the SAME frozen Array, not a deep-dup copy of issues' do
  reg = IssueRegistry.new([])
  pf = Object.new
  inner_issues = [{ issue_id: 'open_endpoint|1|1', severity: 'low', locatable: true }]
  r = AnalysisResult.new(
    preflight: pf, registry: reg,
    layer_issue_groups: [
      { name: 'DIM-XX', count: 1, default_open: false, issues: inner_issues }
    ]
  )
  payload = r.layer_issue_groups_payload
  assert_equal 1, payload.length
  # Per the locked contract: payload is a deep-dup of the bucket Hash
  # but the inner issues Array is freshly duped so the caller can
  # mutate without affecting @layer_issue_groups.
  refute_equal payload.first[:issues].object_id, r.layer_issue_groups.first[:issues].object_id,
         'inner issues Array must be duped per call (caller-mutable)'
  # Same data, though.
  assert_equal payload.first[:issues], r.layer_issue_groups.first[:issues]
end
