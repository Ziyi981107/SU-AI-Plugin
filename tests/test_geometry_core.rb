
#
# tests/test_geometry_core.rb
#
# Pure data-model tests: SourceReference, EdgeRecord, VertexRecord,
# LayerRecord, Tolerance, AnalysisConfig, GeometrySnapshot aggregate
# stats, issue-hash field completeness (PI_TASK_001 §11).
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/vertex_record'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/analysis_config'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/synthetic_factory'
require_relative '../extension/su_ai_plugin/core/analyzers/short_edge_detector'

include SUAnalysis::Core
include SUAnalysis::Core::Analyzers

# --- SourceReference ----------------------------------------------------

test 'core.SourceReference: stable? is false when persistent_id is nil' do
  ref = SourceReference.new(entity_id: 42, kind: 'edge')
  assert_equal false, ref.stable?
end

test 'core.SourceReference: stable? is true when persistent_id given' do
  ref = SourceReference.new(entity_id: 42, persistent_id: 100, kind: 'edge')
  assert_equal true, ref.stable?
end

test 'core.SourceReference: to_h carries all four fields' do
  ref = SourceReference.new(entity_id: 1, persistent_id: 99, kind: 'group', label: 'g0')
  h = ref.to_h
  assert_equal 1,    h[:entity_id]
  assert_equal 99,   h[:persistent_id]
  assert_equal 'group', h[:kind]
  assert_equal 'g0', h[:label]
end

# --- EdgeRecord ---------------------------------------------------------

test 'core.EdgeRecord: length is euclidean (3-4-5 right triangle)' do
  ref = SourceReference.new(entity_id: 1, kind: 'edge')
  e = EdgeRecord.new(
    id: 1, source: ref,
    start_point: [0, 0, 0], end_point: [3, 4, 0],
    layer: 'L'
  )
  assert_in_delta 5.0, e.length, 1.0e-9
end

test 'core.EdgeRecord: length caches and is idempotent' do
  ref = SourceReference.new(entity_id: 1, kind: 'edge')
  e = EdgeRecord.new(
    id: 1, source: ref,
    start_point: [0, 0, 0], end_point: [10, 0, 0],
    layer: 'L'
  )
  l1 = e.length
  l2 = e.length
  assert_equal l1, l2
end

test 'core.EdgeRecord: rejects malformed coords' do
  ref = SourceReference.new(entity_id: 1, kind: 'edge')
  assert_raises(ArgumentError) do
    EdgeRecord.new(id: 1, source: ref, start_point: [0, 0], end_point: [1, 1, 0], layer: 'L')
  end
end

# --- VertexRecord -------------------------------------------------------

test 'core.VertexRecord: degree grows by add_edge and de-dupes' do
  v = VertexRecord.new(coordinate: [0, 0, 0])
  v.add_edge(1)
  v.add_edge(2)
  v.add_edge(1)  # duplicate
  assert_equal 2, v.degree
  assert_equal [1, 2], v.edge_ids
end

# --- LayerRecord --------------------------------------------------------

test 'core.LayerRecord: increment_edge_count! adds 1 each call' do
  lr = LayerRecord.new(name: 'Layer0')
  lr.increment_edge_count!
  lr.increment_edge_count!
  assert_equal 2, lr.edge_count
end

# --- Tolerance ----------------------------------------------------------

test 'core.Tolerance: default values > 0' do
  t = Tolerance.default
  assert t.duplicate > 0
  assert t.short_edge > 0
  assert t.gap_search > 0
  assert t.coordinate_epsilon > 0
end

test 'core.Tolerance: rejects zero' do
  assert_raises(ArgumentError) do
    Tolerance.new(duplicate: 0, short_edge: 1, gap_search: 1, coordinate_epsilon: 1)
  end
end

test 'core.Tolerance: rejects negative' do
  assert_raises(ArgumentError) do
    Tolerance.new(duplicate: 1, short_edge: -1, gap_search: 1, coordinate_epsilon: 1)
  end
end

# --- AnalysisConfig -----------------------------------------------------

test 'core.AnalysisConfig: defaults wired to Tolerance.default' do
  cfg = AnalysisConfig.new
  assert_equal 'default', cfg.profile_name
  assert cfg.tolerance.duplicate > 0
end

# --- GeometrySnapshot aggregate stats ----------------------------------

test 'core.GeometrySnapshot: vertex_count after building a rectangle = 4' do
  edges = SyntheticFactory.rectangle([0, 0], 10, 5)
  snap  = SyntheticFactory.snapshot(edges)
  assert_equal 4, snap.vertex_count
end

test 'core.GeometrySnapshot: layer_distribution counts per layer name' do
  e1 = SyntheticFactory.horizontal_edge(0, 0, 1, 0, layer: 'A')
  e2 = SyntheticFactory.horizontal_edge(1, 0, 2, 0, layer: 'A')
  e3 = SyntheticFactory.horizontal_edge(2, 0, 3, 0, layer: 'B')
  snap = SyntheticFactory.snapshot([e1, e2, e3])
  dist = snap.layer_distribution
  assert_equal 2, dist['A']
  assert_equal 1, dist['B']
end

test 'core.GeometrySnapshot: bounding_box covers all edges' do
  edges = [
    SyntheticFactory.edge(0, [0, 0, 0], [10, 0, 0]),
    SyntheticFactory.edge(1, [10, 0, 0], [10, 5, 0])
  ]
  snap = SyntheticFactory.snapshot(edges)
  bb = snap.bounding_box
  assert_equal [0, 0, 0], bb[:min]
  assert_equal [10, 5, 0], bb[:max]
end

# --- Issue Registry field completeness (PI_TASK_001 §11) ---------------

test 'issue hash includes all §11 fields for short edge' do
  e = SyntheticFactory.horizontal_edge(0, 0.0, 0.1, 0.0)
  snap = SyntheticFactory.snapshot([e])
  issues = ShortEdgeDetector.new.detect(snap)
  assert_equal 1, issues.size
  i = issues.first
  [:kind, :severity, :confidence, :source_entity_ids,
   :edge_ids, :location, :message, :metadata].each do |k|
    assert i.key?(k), "issue missing :#{k}"
  end
  assert_equal 'short_edge', i[:kind]
  assert i[:confidence].is_a?(String)
end
