#
# tests/test_preflight.rb — synthetic tests for PreflightAnalyzer.
#
# Covers PI_TASK_001 §6 (Preflight) + §8 (Z handling) for the pure-Ruby
# subset that is testable without SketchUp, plus adapter-level coverage
# using FakeEntity / FakeModel for the SU-side walk + transform path.
#
# Updated for Stage 2 BLOCK rework (Codex Review 004, 2026-08-17):
#   - non_zero_z_count split into non_zero_z_vertex_count + non_zero_z_edge_count
#   - large_coordinate_count renamed to large_coordinate_extrema_count
#   - canonical severity :low/:medium/:high (not :info/:warning)
#   - big_z is a SEPARATE significant-Z threshold, not part of non-zero counts
#   - root container = level 1; warning at deepest >= threshold
#

require_relative 'runner'
require_relative '../core/tolerance'
require_relative '../core/source_reference'
require_relative '../core/edge_record'
require_relative '../core/geometry_snapshot'
require_relative '../core/preflight'
require_relative '../compatibility/su_capability'

include SUAnalysis::Core

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def make_edge(id, a, b, layer: 'Layer0', instance_path: nil)
  src = SourceReference.new(entity_id: id, kind: 'edge', label: "tc-#{id}",
                            instance_path: instance_path)
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

test 'preflight.TC-12: pure 2D rectangle -> no significant-Z warning, bbox covers all edges' do
  edges = rectangle_at([0, 0], 10, 5)
  snap  = GeometrySnapshot.new(edges: edges)
  report = PreflightAnalyzer.run(snap)

  assert_equal 4, report.edge_count
  assert_equal 4, report.vertex_count
  assert_equal 0, report.non_zero_z_vertex_count
  assert_equal 0, report.non_zero_z_edge_count
  assert_equal 0, report.significant_z_extrema_count

  bbox = report.bounding_box
  refute_nil bbox
  assert_equal [0.0, 0.0, 0.0], bbox[:min]
  assert_equal [10.0, 5.0, 0.0], bbox[:max]

  sig_z_warnings = report.warnings.select { |w| w[:code] == :significant_non_zero_z }
  assert_empty sig_z_warnings
end

# --------------------------------------------------------------------------
# TC-13: Z between coordinate_epsilon and big_z (small but > epsilon)
#         -> appears in non-zero counts but does NOT fire significant
#         warning (S2-BLOCK-004 evidence).
# --------------------------------------------------------------------------

test 'preflight.TC-13a: Z above coordinate_epsilon but below big_z -> counts populated, no significant warning' do
  # coordinate_epsilon default = 1e-6 in. big_z default = 0.01 in.
  # Use Z = 0.005 in (above epsilon, below big_z).
  z_small = 0.005
  edges = rectangle_at([0, 0], 2, 2, z: z_small)
  snap  = GeometrySnapshot.new(edges: edges)
  report = PreflightAnalyzer.run(snap)

  # 4 edges, all endpoints at z_small. Distinct vertices = 4.
  assert_equal 4, report.non_zero_z_vertex_count
  assert_equal 4, report.non_zero_z_edge_count
  # None above big_z -> no significant warning.
  assert_equal 0, report.significant_z_extrema_count

  sig_z_warnings = report.warnings.select { |w| w[:code] == :significant_non_zero_z }
  assert_empty sig_z_warnings
end

# --------------------------------------------------------------------------
# TC-13 (was) — Z above big_z threshold -> significant warning fires.
# --------------------------------------------------------------------------

test 'preflight.TC-13b: Z above big_z threshold -> significant-Z warning, severity :medium' do
  # big_z threshold default = 0.01 inch. Use Z=5.0 to make this unambiguous.
  edges = rectangle_at([0, 0], 2, 2, z: 5.0)
  snap  = GeometrySnapshot.new(edges: edges)
  report = PreflightAnalyzer.run(snap)

  # 4 edges × 2 vertices = 8 vertices all at Z=5.0. Distinct = 4 (since
  # corners coincide).
  assert_operator report.non_zero_z_vertex_count, :>=, 4
  assert_equal 4, report.non_zero_z_edge_count
  assert_operator report.significant_z_extrema_count, :>=, 1

  w = report.warnings.select { |x| x[:code] == :significant_non_zero_z }
  assert_equal 1, w.size
  assert_equal :medium, w.first[:severity]
end

# --------------------------------------------------------------------------
# TC-14: abnormal large coordinates -> warning fires (severity :high).
# --------------------------------------------------------------------------

test 'preflight.TC-14: abnormal large coord (> 1e6 inch) -> abnormal_large_coord warning, severity :high' do
  edges = rectangle_at([0, 0], 1.5e6, 1.0, z: 0.0)
  snap  = GeometrySnapshot.new(edges: edges)
  report = PreflightAnalyzer.run(snap)

  assert_operator report.large_coordinate_extrema_count, :>, 0

  w = report.warnings.select { |x| x[:code] == :abnormal_large_coord }
  assert_equal 1, w.size
  assert_equal :high, w.first[:severity]
end

# --------------------------------------------------------------------------
# TC-15: non-trivial geometry, layer_distribution accuracy, multiple layers
# --------------------------------------------------------------------------

test 'preflight.TC-15: L-shape + multiple layers -> counts and layer distribution accurate' do
  edges = []
  edges.concat rectangle_at([0, 0], 10, 5, layer: 'A')
  edges.concat rectangle_at([10, 0], 5, 5, layer: 'B')

  snap = GeometrySnapshot.new(edges: edges)
  report = PreflightAnalyzer.run(snap)

  assert_equal 8, report.edge_count
  assert_equal 6, report.vertex_count
  assert_equal [0.0, 0.0, 0.0], report.bounding_box[:min]
  assert_equal [15.0, 5.0, 0.0], report.bounding_box[:max]
  assert_equal 4, report.layer_distribution['A']
  assert_equal 4, report.layer_distribution['B']

  z_w = report.warnings.select { |x| x[:code] == :significant_non_zero_z }
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

# --------------------------------------------------------------------------
# Extra: deep nesting warning semantics (root = level 1; warn at >= threshold)
# --------------------------------------------------------------------------

test 'preflight.EXTRA: deep_nesting warning fires at >= threshold (root=1), severity :low' do
  edges  = rectangle_at([0, 0], 2, 2)
  snap   = GeometrySnapshot.new(
    edges: edges,
    preflight: { deepest_nesting: 3 } # default warning threshold = 3
  )
  report = PreflightAnalyzer.run(snap)

  deep = report.warnings.select { |w| w[:code] == :deep_nesting }
  assert_equal 1, deep.size
  assert_equal :low, deep.first[:severity]
end

test 'preflight.EXTRA: deep_nesting does NOT fire below threshold (root=1)' do
  edges  = rectangle_at([0, 0], 2, 2)
  snap   = GeometrySnapshot.new(
    edges: edges,
    preflight: { deepest_nesting: 2 } # threshold = 3, so no warning
  )
  report = PreflightAnalyzer.run(snap)

  deep = report.warnings.select { |w| w[:code] == :deep_nesting }
  assert_empty deep
end

# --------------------------------------------------------------------------
# Extra: shared endpoint deduplication in vertex count (S2-BLOCK-004 evidence)
# --------------------------------------------------------------------------

test 'preflight.EXTRA: shared endpoint of two edges counted ONCE in vertex count' do
  # Two edges share one endpoint at (0,0,0). Distinct non-zero-Z vertex
  # count must be 1 (not 2).
  src = SourceReference.new(entity_id: 1, kind: 'edge')
  e1  = EdgeRecord.new(id: 0, source: src, start_point: [0, 0, 0.1],
                       end_point: [10, 0, 0.1], layer: 'L')
  e2  = EdgeRecord.new(id: 1, source: src, start_point: [0, 0, 0.1],
                       end_point: [0,  5, 0.1], layer: 'L')
  snap = GeometrySnapshot.new(edges: [e1, e2])
  report = PreflightAnalyzer.run(snap)

  assert_equal 3, report.vertex_count
  # Two edges x 2 endpoints = 4 raw. 3 distinct (shared (0,0,0.1)).
  # Non-zero vertex count = 3 (all above epsilon).
  assert_equal 3, report.non_zero_z_vertex_count
end

# --------------------------------------------------------------------------
# Extra: HtmlDialog capability probe (R002) — outside SU returns false.
# --------------------------------------------------------------------------

test 'capability.HtmlDialog: outside SU returns false (R002 evidence)' do
  # Outside SU the constant is undefined -> false.
  assert_equal false, SUAnalysis::Compatibility::SUCapability.html_dialog?
end

# --------------------------------------------------------------------------
# Extra: SourceReference carries instance_path (S2-BLOCK-002 evidence)
# --------------------------------------------------------------------------

test 'source_ref: instance_path default empty, override via constructor, serialized in to_h' do
  r1 = SourceReference.new(entity_id: 1, kind: 'edge')
  assert_equal [], r1.instance_path
  assert_equal '',  r1.instance_path_string

  r2 = SourceReference.new(
    entity_id: 2, kind: 'edge',
    instance_path: ['Group:outer', 'ComponentInstance:Window#1']
  )
  assert_equal ['Group:outer', 'ComponentInstance:Window#1'], r2.instance_path
  assert_equal 'Group:outer > ComponentInstance:Window#1', r2.instance_path_string
  assert_equal ['Group:outer', 'ComponentInstance:Window#1'], r2.to_h[:instance_path]
end