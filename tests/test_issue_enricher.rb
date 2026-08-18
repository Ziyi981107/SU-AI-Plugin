#
# tests/test_issue_enricher.rb
#
# Pure-Ruby tests for IssueEnricher:
#   - aligned SourceToken array from edge_ids -> snapshot_lookup
#   - whole-token dedup
#   - locatable derivation per CodeX BLOCK-001 v4
#   - missing edge_id diagnostic
#   - structural identity preserved (nested, pid_path_complete)
#

require_relative 'runner'
require_relative '../core/source_reference'
require_relative '../core/edge_record'
require_relative '../core/synthetic_factory'
require_relative '../core/issue_normalizer'
require_relative '../core/issue_enricher'
require_relative '../core/issue_id_assigner'

include SUAnalysis::Core
include SUAnalysis::Core::IssueNormalizer

# --- helpers ---

def edge_with(extras = {})
  pid_path = extras[:persistent_id_path] || []
  # pid_path_complete default: true iff pid_path is non-empty AND
  # every entry is non-nil. This matches the inherited-invariance
  # interpretation: the leaf is the LAST entry of pid_path.
  pid_path_complete = if extras[:pid_path_complete].nil?
                       pid_path.is_a?(Array) && !pid_path.empty? && pid_path.all? { |p| !p.nil? }
                     else
                       extras[:pid_path_complete]
                     end
  src = SUAnalysis::Core::SourceReference.new(
    entity_id:          extras[:entity_id].nil? ? 1 : extras[:entity_id],
    persistent_id:      extras[:persistent_id],
    kind:               'edge',
    label:              'e',
    persistent_id_path: pid_path,
    structural_depth:   extras[:structural_depth] || 0,
    pid_path_complete:  pid_path_complete
  )
  EdgeRecord.new(
    id: 100, source: src,
    start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0],
    layer: 'Layer0'
  )
end

def snap(*edges)
  lookup = {}
  edges.each_with_index { |e, i| lookup[e.id] = e }
  lookup
end

# --- aligned source tokens ---

test 'issue_enricher: one SourceToken per resolved EdgeRecord' do
  edges = [edge_with(persistent_id_path: [10, 20, 555], structural_depth: 2)]
  edges.first.instance_variable_set(:@id, 100)
  lkp = snap(edges.first)
  raw = IssueNormalizer.normalize_analyzer_issue(
    kind: 'duplicate_edge_candidate', severity: 'medium',
    confidence: 'high', source_entity_ids: [1],
    edge_ids: [100], location: nil, message: 'd', metadata: {}
  )
  out = IssueEnricher.enrich_one(raw, snapshot_lookup: lkp, counter_within_type: 1)
  assert_equal 1, out[:sources].length
  tok = out[:sources][0]
  assert_equal [10, 20, 555], tok[:persistent_id_path]
  assert_equal 1, tok[:entity_id]
  assert_equal true, tok[:nested]
  assert_equal true, tok[:pid_path_complete]
end

test 'issue_enricher: dedup whole tokens (positional alignment preserved)' do
  edges = []
  2.times { |i|
    e = edge_with(persistent_id_path: [10, 20, 555], structural_depth: 2)
    e.instance_variable_set(:@id, 100 + i)
    edges << e
  }
  lkp = snap(*edges)
  raw = IssueNormalizer.normalize_analyzer_issue(
    kind: 'duplicate_edge_candidate', severity: 'medium',
    confidence: 'high', source_entity_ids: [1, 2],
    edge_ids: [100, 101], location: nil, message: 'd', metadata: {}
  )
  out = IssueEnricher.enrich_one(raw, snapshot_lookup: lkp, counter_within_type: 1)
  assert_equal 1, out[:sources].length
end

# --- locatable derivation ---

test 'issue_enricher: locatable=true for complete-root (single leaf pid)' do
  e = edge_with(persistent_id: 100, persistent_id_path: [100], structural_depth: 0)
  e.instance_variable_set(:@id, 1)
  lkp = snap(e)
  raw = IssueNormalizer.normalize_analyzer_issue(
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [1], edge_ids: [1], location: nil,
    message: 'short', metadata: {}
  )
  out = IssueEnricher.enrich_one(raw, snapshot_lookup: lkp, counter_within_type: 1)
  assert_equal true, out[:locatable]
end

test 'issue_enricher: locatable=true for complete-nested' do
  e = edge_with(persistent_id: 555, persistent_id_path: [10, 20, 555], structural_depth: 2)
  e.instance_variable_set(:@id, 1)
  lkp = snap(e)
  raw = IssueNormalizer.normalize_analyzer_issue(
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [1], edge_ids: [1], location: nil,
    message: 'short', metadata: {}
  )
  out = IssueEnricher.enrich_one(raw, snapshot_lookup: lkp, counter_within_type: 1)
  assert_equal true, out[:locatable]
end

test 'issue_enricher: locatable=true for incomplete-root (entity_id fallback)' do
  # leaf pid missing, but entity_id is non-nil and nested=false
  e = edge_with(persistent_id: nil, persistent_id_path: [], structural_depth: 0,
                pid_path_complete: false)
  e.instance_variable_set(:@id, 1)
  lkp = snap(e)
  raw = IssueNormalizer.normalize_analyzer_issue(
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [1], edge_ids: [1], location: nil,
    message: 'short', metadata: {}
  )
  out = IssueEnricher.enrich_one(raw, snapshot_lookup: lkp, counter_within_type: 1)
  assert_equal true, out[:locatable]
end

test 'issue_enricher: locatable=false for incomplete-nested-partial-leaf' do
  # nested=true, pid_path=[leaf_pid] only, complete=false
  e = edge_with(persistent_id: 555, persistent_id_path: [555], structural_depth: 2,
                pid_path_complete: false)
  e.instance_variable_set(:@id, 1)
  lkp = snap(e)
  raw = IssueNormalizer.normalize_analyzer_issue(
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [1], edge_ids: [1], location: nil,
    message: 'short', metadata: {}
  )
  out = IssueEnricher.enrich_one(raw, snapshot_lookup: lkp, counter_within_type: 1)
  assert_equal false, out[:locatable]
end

test 'issue_enricher: locatable=false for incomplete-nested-partial-ancestry' do
  # nested=true, pid_path=[], complete=false
  e = edge_with(persistent_id: nil, persistent_id_path: [], structural_depth: 2,
                pid_path_complete: false)
  e.instance_variable_set(:@id, 1)
  lkp = snap(e)
  raw = IssueNormalizer.normalize_analyzer_issue(
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [1], edge_ids: [1], location: nil,
    message: 'short', metadata: {}
  )
  out = IssueEnricher.enrich_one(raw, snapshot_lookup: lkp, counter_within_type: 1)
  assert_equal false, out[:locatable]
end

test 'issue_enricher: locatable=false for fully-missing' do
  # entity_id: nil + pid_path_complete: false + nested: false
  # -> fully-missing -> non-locatable
  src = SourceReference.new(entity_id: nil, kind: 'edge', label: 'e',
                            persistent_id_path: [], structural_depth: 0,
                            pid_path_complete: false)
  e = EdgeRecord.new(id: 2, source: src, start_point: [0,0,0],
                     end_point: [1,0,0], layer: 'Layer0')
  lkp = snap(e)
  raw = IssueNormalizer.normalize_analyzer_issue(
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [], edge_ids: [2], location: nil,
    message: 'short', metadata: {}
  )
  out = IssueEnricher.enrich_one(raw, snapshot_lookup: lkp, counter_within_type: 1)
  assert_equal false, out[:locatable]
  assert_equal [nil], out[:sources].map { |t| t[:entity_id] }
end

# --- missing edge_id ---

test 'issue_enricher: missing edge_id -> empty-source token + still locatable=false' do
  raw = IssueNormalizer.normalize_analyzer_issue(
    kind: 'short_edge', severity: 'low', confidence: 'medium',
    source_entity_ids: [], edge_ids: [999], location: nil,
    message: 'short', metadata: {}
  )
  out = IssueEnricher.enrich_one(raw, snapshot_lookup: {}, counter_within_type: 1)
  assert_equal 1, out[:sources].length
  assert_equal [], out[:sources][0][:persistent_id_path]
  assert_equal false, out[:locatable]
end

# --- enrich_all: counter per type ---

test 'issue_enricher.enrich_all: assigns sequential counter within type' do
  e1 = edge_with(persistent_id_path: [10], structural_depth: 0, pid_path_complete: true)
  e1.instance_variable_set(:@id, 1)
  e2 = edge_with(persistent_id_path: [20], structural_depth: 0, pid_path_complete: true)
  e2.instance_variable_set(:@id, 2)
  lkp = snap(e1, e2)
  raws = [
    IssueNormalizer.normalize_analyzer_issue(
      kind: 'short_edge', severity: 'low', confidence: 'medium',
      source_entity_ids: [], edge_ids: [1], location: nil,
      message: 'a', metadata: {}),
    IssueNormalizer.normalize_analyzer_issue(
      kind: 'short_edge', severity: 'low', confidence: 'medium',
      source_entity_ids: [], edge_ids: [2], location: nil,
      message: 'b', metadata: {})
  ]
  out = IssueEnricher.enrich_all(raws, snapshot_lookup: lkp)
  assert_equal 2, out.length
  counters = out.map { |x| x[:issue_id].match(/\|(\d+)$/)[1].to_i }
  assert_equal [1, 2], counters
end

# --- BLOCK-002 counter stability: input order must NOT change counters ---

test 'issue_enricher.enrich_all: counter is order-independent (reversed input)' do
  e1 = edge_with(persistent_id_path: [10], structural_depth: 0, pid_path_complete: true)
  e1.instance_variable_set(:@id, 1)
  e2 = edge_with(persistent_id_path: [20], structural_depth: 0, pid_path_complete: true)
  e2.instance_variable_set(:@id, 2)
  e3 = edge_with(persistent_id_path: [30], structural_depth: 0, pid_path_complete: true)
  e3.instance_variable_set(:@id, 3)
  lkp = snap(e1, e2, e3)
  mk = ->(id) {
    IssueNormalizer.normalize_analyzer_issue(
      kind: 'short_edge', severity: 'low', confidence: 'medium',
      source_entity_ids: [], edge_ids: [id], location: nil,
      message: "m#{id}", metadata: {})
  }
  forward = [mk.call(1), mk.call(2), mk.call(3)]
  reversed = [mk.call(3), mk.call(2), mk.call(1)]
  out_f = IssueEnricher.enrich_all(forward,  snapshot_lookup: lkp)
  out_r = IssueEnricher.enrich_all(reversed, snapshot_lookup: lkp)
  # Same logical Issue -> same issue_id (counter and all).
  ids_f = out_f.map { |x| x[:issue_id] }.sort
  ids_r = out_r.map { |x| x[:issue_id] }.sort
  assert_equal ids_f, ids_r
end

test 'issue_enricher.enrich_all: counter is order-independent (shuffled input)' do
  e1 = edge_with(persistent_id_path: [10], structural_depth: 0, pid_path_complete: true)
  e1.instance_variable_set(:@id, 1)
  e2 = edge_with(persistent_id_path: [20], structural_depth: 0, pid_path_complete: true)
  e2.instance_variable_set(:@id, 2)
  e3 = edge_with(persistent_id_path: [30], structural_depth: 0, pid_path_complete: true)
  e3.instance_variable_set(:@id, 3)
  lkp = snap(e1, e2, e3)
  mk = ->(id) {
    IssueNormalizer.normalize_analyzer_issue(
      kind: 'short_edge', severity: 'low', confidence: 'medium',
      source_entity_ids: [], edge_ids: [id], location: nil,
      message: "m#{id}", metadata: {})
  }
  a = [mk.call(1), mk.call(2), mk.call(3)]
  b = [mk.call(2), mk.call(3), mk.call(1)]
  c = [mk.call(3), mk.call(1), mk.call(2)]
  out_a = IssueEnricher.enrich_all(a, snapshot_lookup: lkp).map { |x| x[:issue_id] }.sort
  out_b = IssueEnricher.enrich_all(b, snapshot_lookup: lkp).map { |x| x[:issue_id] }.sort
  out_c = IssueEnricher.enrich_all(c, snapshot_lookup: lkp).map { |x| x[:issue_id] }.sort
  assert_equal out_a, out_b
  assert_equal out_a, out_c
end

# --- BLOCK-002 v2: same-PID + different-location -> distinct stable counters ---

test 'issue_enricher.enrich_all: same-PID + different-location get stable counters (CodeX Round 016)' do
  # Two open endpoints of one Edge: same PID path, same edge_id, different locations.
  e1 = edge_with(persistent_id_path: [10, 20, 555], structural_depth: 2,
                  persistent_id: 555, pid_path_complete: true)
  e1.instance_variable_set(:@id, 100)
  lkp = snap(e1)
  mk = ->(loc_idx) {
    IssueNormalizer.normalize_analyzer_issue(
      kind: 'open_endpoint', severity: 'medium', confidence: 'high',
      source_entity_ids: [1], edge_ids: [100],
      location: [loc_idx.to_f, 0.0, 0.0],
      message: 'open', metadata: {}
    )
  }
  forward  = [mk.call(0),   mk.call(10)]
  reversed = [mk.call(10),  mk.call(0)]
  shuffled = [mk.call(10),  mk.call(0),   mk.call(5),  mk.call(5)]  # duplicates with same loc

  out_f = IssueEnricher.enrich_all(forward,  snapshot_lookup: lkp)
  out_r = IssueEnricher.enrich_all(reversed, snapshot_lookup: lkp)
  out_s = IssueEnricher.enrich_all(shuffled, snapshot_lookup: lkp)

  # Map issue_id -> location_x for each run.
  map_f = out_f.map { |x| [x[:issue_id], x[:location][0]] }.sort_by { |id, loc| loc }
  map_r = out_r.map { |x| [x[:issue_id], x[:location][0]] }.sort_by { |id, loc| loc }
  map_s = out_s.map { |x| [x[:issue_id], x[:location][0]] }.sort_by { |id, loc| loc }

  # The same logical location (x=0) gets the same issue_id across runs.
  # The same logical location (x=10) gets the same issue_id across runs.
  ids_0_f = map_f.find { |_, loc| loc == 0 }.first
  ids_0_r = map_r.find { |_, loc| loc == 0 }.first
  ids_0_s = map_s.find { |_, loc| loc == 0 }.first
  ids_10_f = map_f.find { |_, loc| loc == 10 }.first
  ids_10_r = map_r.find { |_, loc| loc == 10 }.first

  assert_equal ids_0_f, ids_0_r
  assert_equal ids_0_f, ids_0_s
  assert_equal ids_10_f, ids_10_r
  refute_equal ids_0_f, ids_10_f   # distinct counters for distinct locations
end

test 'issue_enricher.enrich_all: 3 distinct locations -> 3 distinct counters' do
  e1 = edge_with(persistent_id_path: [10], structural_depth: 0, pid_path_complete: true)
  e1.instance_variable_set(:@id, 1)
  lkp = snap(e1)
  mk = ->(loc_idx) {
    IssueNormalizer.normalize_analyzer_issue(
      kind: 'open_endpoint', severity: 'medium', confidence: 'high',
      source_entity_ids: [1], edge_ids: [1],
      location: [loc_idx.to_f, 0.0, 0.0],
      message: 'open', metadata: {}
    )
  }
  forward = [mk.call(0), mk.call(10), mk.call(5)]
  reversed = [mk.call(5), mk.call(0), mk.call(10)]
  out_f = IssueEnricher.enrich_all(forward,  snapshot_lookup: lkp)
  out_r = IssueEnricher.enrich_all(reversed, snapshot_lookup: lkp)
  # Sort each by location; the issue_id sequence should match.
  ids_f = out_f.sort_by { |x| x[:location][0] }.map { |x| x[:issue_id] }
  ids_r = out_r.sort_by { |x| x[:location][0] }.map { |x| x[:issue_id] }
  assert_equal ids_f, ids_r
  # And they are distinct.
  assert_equal 3, ids_f.uniq.length
end
