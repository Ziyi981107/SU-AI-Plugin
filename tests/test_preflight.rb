
#
# tests/test_preflight.rb — synthetic tests for PreflightAnalyzer.
#
# Covers PI_TASK_001 §6 (Preflight) + §8 (Z handling) for the pure-Ruby
# subset that is testable without SketchUp:
#
#   TC-11  empty snapshot    -> edge_count=0, no warnings, bbox=nil
#   TC-12  pure 2D rectangle -> non_zero_z_count=0, no Z warning
#   TC-13  geometry with Z>big_z -> non_zero_z warning fires, z_range covers it
#   TC-14  abnormal large coord -> abnormal_large_coord warning fires
#   TC-15  bbox accuracy on a non-trivial L-shape, layer_distribution accurate
#

require_relative 'runner'
require_relative '../core/tolerance'
require_relative '../core/source_reference'
require_relative '../core/edge_record'
require_relative '../core/geometry_snapshot'
require_relative '../core/preflight'

include SUAnalysis::Core

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def make_edge(id, a, b, layer: 'Layer0')
  src = SourceReference.new(entity_id: id, kind: 'edge', label: "tc-#{id}")
  EdgeRecord.new(
    id: id, source: src,
    start_point: a, end_point: b, layer: layer
  )
end

def rectangle_at(start_xy, w, h, layer: 'Layer0', z: 0.0)
  x, y = start_xy
  [
    make_edge(0, [x,     y,     z], [x + w, y,     z], layer: layer),
    make_edge(1, [x + w, y,     z], [x + w, y + h, z], layer: layer),
    make_edge(2, [x + w, y + h, z], [x,     y + h, z], layer: layer),
    make_edge(3, [x,     y + h, z], [x,     y,     z], layer: layer)
  ]
end

# --------------------------------------------------------------------------
# TC-11: empty snapshot
# --------------------------------------------------------------------------

test 'preflight.TC-11: empty snapshot -> edge_count=0, bbox=nil, no warnings' do
  snap = GeometrySnapshot.new(edges: [])
  report = PreflightAnalyzer.run(snap)

  assert_equal 0, report.edge_count
  assert_equal 0, report.vertex_count
  assert_nil   report.bounding_box
  assert_empty report.warnings
  assert       report.empty?
  assert_equal 0, report.warning_count
end

# --------------------------------------------------------------------------
# TC-12: pure 2D rectangle — no Z warning, bbox accurate
# --------------------------------------------------------------------------

test 'preflight.TC-12: pure 2D rectangle -> no non-zero-Z warning, bbox covers all edges' do
  edges = rectangle_at([0, 0], 10, 5)
  snap  = GeometrySnapshot.new(edges: edges)
  report = PreflightAnalyzer.run(snap)

  assert_equal 4, report.edge_count
  assert_equal 4, report.vertex_count
  assert_equal 0, report.non_zero_z_count

  bbox = report.bounding_box
  refute_nil bbox
  assert_equal [0.0, 0.0, 0.0], bbox[:min]
  assert_equal [10.0, 5.0, 0.0], bbox[:max]

  z_warnings = report.warnings.select { |w| w[:code] == :non_zero_z_geometry }
  assert_empty z_warnings
end

# --------------------------------------------------------------------------
# TC-13: geometry with off-plane Z — warning fires, z_range covers it
# --------------------------------------------------------------------------

test 'preflight.TC-13: Z above big_z threshold -> non_zero_z warning, z_range reflects it' do
  # Big Z threshold default = 0.01 inch. Use Z=5.0 to make this unambiguous.
  edges = rectangle_at([0, 0], 2, 2, z: 5.0)
  snap  = GeometrySnapshot.new(edges: edges)
  report = PreflightAnalyzer.run(snap)

  # 4 edges × 2 vertices = 8 vertices all at Z=5.0
  assert_equal 8, report.non_zero_z_count
  assert_in_delta 5.0, report.z_range[0], 1.0e-9
  assert_in_delta 5.0, report.z_range[1], 1.0e-9

  z_warnings = report.warnings.select { |w| w[:code] == :non_zero_z_geometry }
  assert_equal 1, z_warnings.size
  assert_equal :info, z_warnings.first[:severity]
end

# --------------------------------------------------------------------------
# TC-14: abnormal large coordinates — warning fires
# --------------------------------------------------------------------------

test 'preflight.TC-14: abnormal large coord (> 1e6 inch) -> abnormal_large_coord warning' do
  # Default large_coordinate threshold = 1e6 inches. 1.5e6 should trip it.
  edges = rectangle_at([0, 0], 1.5e6, 1.0, z: 0.0)
  snap  = GeometrySnapshot.new(edges: edges)
  report = PreflightAnalyzer.run(snap)

  assert_operator report.large_coordinate_count, :>, 0

  w = report.warnings.select { |x| x[:code] == :abnormal_large_coord }
  assert_equal 1, w.size
  assert_equal :warning, w.first[:severity]
end

# --------------------------------------------------------------------------
# TC-15: non-trivial geometry, layer_distribution accuracy, multiple layers
# --------------------------------------------------------------------------

test 'preflight.TC-15: L-shape + multiple layers -> counts and layer distribution accurate' do
  # L-shape: two rectangles sharing an edge, on two different layers.
  edges = []
  edges.concat rectangle_at([0, 0], 10, 5, layer: 'A')  # bottom rectangle
  edges.concat rectangle_at([10, 0], 5, 5, layer: 'B') # top rectangle, sharing x=10 wall

  snap = GeometrySnapshot.new(edges: edges)
  report = PreflightAnalyzer.run(snap)

  assert_equal 8, report.edge_count
  # L-shape has 6 unique vertices: (0,0)(10,0)(15,0)(15,5)(10,5)(0,5)
  assert_equal 6, report.vertex_count

  # bbox: x in [0,15], y in [0,5], z in [0,0]
  assert_equal [0.0, 0.0, 0.0], report.bounding_box[:min]
  assert_equal [15.0, 5.0, 0.0], report.bounding_box[:max]

  # layer distribution: 4 edges on each layer
  assert_equal 4, report.layer_distribution['A']
  assert_equal 4, report.layer_distribution['B']

  # no Z warnings, no large coord warnings
  z_w = report.warnings.select { |x| x[:code] == :non_zero_z_geometry }
  lc_w = report.warnings.select { |x| x[:code] == :abnormal_large_coord }
  assert_empty z_w
  assert_empty lc_w
end

# --------------------------------------------------------------------------
# Extra: SU-side facts flow through snapshot.preflight hash verbatim
# --------------------------------------------------------------------------

test 'preflight.EXTRA: SU-side facts from snapshot.preflight are passed through to report' do
  edges = rectangle_at([0, 0], 2, 2)
  snap  = GeometrySnapshot.new(
    edges: edges,
    preflight: {
      sketchup_version: 'SU 2024',
      selection_type:   'Group',
      group_count:      1,
      component_count:  0,
      deepest_nesting:  2,
      nested_containers: ['outer_group/inner_group']
    }
  )
  report = PreflightAnalyzer.run(snap)

  assert_equal 'SU 2024', report.sketchup_version
  assert_equal 'Group',   report.selection_type
  assert_equal 1,         report.group_count
  assert_equal 0,         report.component_count
  assert_equal 2,         report.deepest_nesting
  assert_equal ['outer_group/inner_group'], report.nested_containers
end

test 'preflight.EXTRA: deep nesting above warning threshold emits :deep_nesting warning' do
  edges  = rectangle_at([0, 0], 2, 2)
  snap   = GeometrySnapshot.new(
    edges: edges,
    preflight: { deepest_nesting: 5 } # default warning threshold = 3
  )
  report = PreflightAnalyzer.run(snap)

  deep = report.warnings.select { |w| w[:code] == :deep_nesting }
  assert_equal 1, deep.size
  assert_equal :warning, deep.first[:severity]
end
