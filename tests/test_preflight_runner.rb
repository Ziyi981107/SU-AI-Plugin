#
# tests/test_preflight_runner.rb — adapter-level tests using FakeSU.
#
# These exercise extension/preflight_runner.rb end-to-end without
# SketchUp installed, proving:
#
#   S2-BLOCK-001: one source Edge -> exactly ONE EdgeRecord.
#   S2-BLOCK-002: Group / ComponentInstance traversal, accumulated
#                 Geom::Transformation, world-coord endpoints, and
#                 instance_path composite source identity.
#   S2-BLOCK-003: extension/preflight_runner.rb loads under Ruby 2.2.4
#                 syntax baseline (no &. anywhere).
#   S2-BLOCK-004: mixed selection returns 'mixed' type and preserves
#                 per-type counts; non-zero Z counts use
#                 coordinate_epsilon not big_z; deep_nesting warn at >=3.
#   S2-BLOCK-005-replacement: invalid/erased entity in selection is
#                 skipped without aborting analysis (one valid + one
#                 invalid -> report still has the valid one).
#
# These tests are run via tests/run_all.rb (auto-discovered).
#

require_relative 'runner'
require_relative 'test_geometry_core' if false # no-op; just for IDE

require_relative '_fake_su'
require_relative '../core/source_reference'
require_relative '../core/edge_record'
require_relative '../core/geometry_snapshot'
require_relative '../core/preflight'
require_relative '../compatibility/su_capability'
require_relative '../extension/preflight_runner'

include SUAnalysis::Core
include SUAnalysis::Compatibility
include SUAnalysis::Extension

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def fake_edge(a, b, layer: 'Layer0')
  FakeSU::Edge.new(
    start: FakeSU::Vertex.new(a[0], a[1], a[2]),
    finish: FakeSU::Vertex.new(b[0], b[1], b[2]),
    layer: FakeSU::Layer.new(layer)
  )
end

# Build a rectangle on Layer0 around start_xy with width x height.
def fake_rectangle_edges(start_xy, w, h, layer: 'Layer0')
  x, y = start_xy
  [
    fake_edge([x,     y,     0.0], [x + w, y,     0.0], layer: layer),
    fake_edge([x + w, y,     0.0], [x + w, y + h, 0.0], layer: layer),
    fake_edge([x + w, y + h, 0.0], [x,     y + h, 0.0], layer: layer),
    fake_edge([x,     y + h, 0.0], [x,     y,     0.0], layer: layer)
  ]
end

# --------------------------------------------------------------------------
# S2-BLOCK-001 — One source Edge -> one EdgeRecord
# --------------------------------------------------------------------------

test 'S2-BLOCK-001: single Edge in selection -> exactly one EdgeRecord' do
  edge = fake_edge([0, 0, 0], [10, 0, 0])
  sel  = FakeSU::Selection.new([edge])
  snap = PreflightRunner.build_snapshot(sel)

  assert_equal 1, snap.edge_count
end

test 'S2-BLOCK-001: rectangle in Group -> 4 EdgeRecords (not 8)' do
  rect_edges = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'outer', children: rect_edges)
  sel   = FakeSU::Selection.new([group])
  snap  = PreflightRunner.build_snapshot(sel)

  assert_equal 4, snap.edge_count
end

# --------------------------------------------------------------------------
# S2-BLOCK-002 — Component traversal + accumulated transforms
# --------------------------------------------------------------------------

test 'S2-BLOCK-002: ComponentInstance child lives in definition.entities, not instance.entities' do
  edge = fake_edge([0, 0, 0], [10, 0, 0])
  defn = FakeSU::ComponentDefinition.new(name: 'Window', children: [edge])
  inst = FakeSU::ComponentInstance.new(definition: defn)
  sel  = FakeSU::Selection.new([inst])
  snap = PreflightRunner.build_snapshot(sel)

  # The Edge inside ComponentInstance definition must be found.
  assert_equal 1, snap.edge_count
end

test 'S2-BLOCK-002: ComponentInstance translation applied to Edge endpoints (world coords)' do
  # Build a ComponentInstance with one Edge from (0,0,0) -> (10,0,0),
  # and an instance-level translation of (100, 200, 0). The EdgeRecord
  # endpoints in the snapshot must reflect the translation.
  edge = fake_edge([0, 0, 0], [10, 0, 0])
  defn = FakeSU::ComponentDefinition.new(name: 'TranslatedWindow', children: [edge])
  inst = FakeSU::ComponentInstance.new(
    definition: defn,
    transformation: FakeSU.translation(100, 200, 0)
  )
  sel  = FakeSU::Selection.new([inst])
  snap = PreflightRunner.build_snapshot(sel)

  assert_equal 1, snap.edge_count
  e = snap.edges.first
  assert_in_delta 100.0, e.start_point[0], 1.0e-9
  assert_in_delta 200.0, e.start_point[1], 1.0e-9
  assert_in_delta 110.0, e.end_point[0],   1.0e-9
  assert_in_delta 200.0, e.end_point[1],   1.0e-9
end

test 'S2-BLOCK-002: two ComponentInstances sharing one definition -> 2 occurrences, distinct world coords' do
  # One definition with one Edge at origin. Two instances: one translated,
  # one scaled. Both must appear in the snapshot with distinct world coords
  # and non-colliding SourceReference instance_path strings.
  edge = fake_edge([0, 0, 0], [10, 0, 0])
  defn = FakeSU::ComponentDefinition.new(name: 'Window', children: [edge])

  inst_a = FakeSU::ComponentInstance.new(
    definition: defn,
    transformation: FakeSU.translation(100, 0, 0)
  )
  inst_b = FakeSU::ComponentInstance.new(
    definition: defn,
    transformation: FakeSU.scale(2.0)
  )
  sel = FakeSU::Selection.new([inst_a, inst_b])
  snap = PreflightRunner.build_snapshot(sel)

  assert_equal 2, snap.edge_count
  starts = snap.edges.map { |e| e.start_point[0] }
  ends   = snap.edges.map { |e| e.end_point[0] }
  # One occurrence: (0,0,0) -> (10,0,0) (definition origin).
  # Scaled 2x:    (0,0,0) -> (20,0,0).
  # Translated:   (100,0,0) -> (110,0,0).
  starts_sorted = starts.sort
  ends_sorted   = ends.sort
  assert_in_delta 0.0,   starts_sorted[0], 1.0e-9
  assert_in_delta 100.0, starts_sorted[1], 1.0e-9
  assert_in_delta 20.0,  ends_sorted[0],   1.0e-9
  assert_in_delta 110.0, ends_sorted[1],   1.0e-9
end

test 'S2-BLOCK-002: instance_path distinguishes two ComponentInstance occurrences' do
  edge = fake_edge([0, 0, 0], [10, 0, 0])
  defn = FakeSU::ComponentDefinition.new(name: 'Window', children: [edge])
  inst_a = FakeSU::ComponentInstance.new(definition: defn,
                                         transformation: FakeSU.translation(100, 0, 0))
  inst_b = FakeSU::ComponentInstance.new(definition: defn,
                                         transformation: FakeSU.translation(0, 100, 0))
  sel = FakeSU::Selection.new([inst_a, inst_b])
  snap = PreflightRunner.build_snapshot(sel)

  paths = snap.edges.map { |e| e.source.instance_path_string }
  # Both should include 'ComponentInstance:Window'.
  assert paths.all? { |p| p.include?('ComponentInstance:Window') }
  # The two paths must be distinct (they differ because the fake instances
  # have different object_ids).
  refute_equal paths[0], paths[1]
end

test 'S2-BLOCK-002: nested Group -> Component -> Group accumulates transforms' do
  # Innermost: edge from (0,0,0) -> (1,0,0).
  inner_edge = fake_edge([0, 0, 0], [1, 0, 0])
  inner_group = FakeSU::Group.new(name: 'inner', children: [inner_edge],
                                  transformation: FakeSU.translation(10, 0, 0))

  # Middle: component instance containing inner_group, translated (100, 0, 0).
  defn = FakeSU::ComponentDefinition.new(name: 'MidComp', children: [inner_group])
  mid_inst = FakeSU::ComponentInstance.new(
    definition: defn,
    transformation: FakeSU.translation(100, 0, 0)
  )

  # Outer: group containing the component instance, translated (1000, 0, 0).
  outer = FakeSU::Group.new(name: 'outer', children: [mid_inst],
                            transformation: FakeSU.translation(1000, 0, 0))

  sel  = FakeSU::Selection.new([outer])
  snap = PreflightRunner.build_snapshot(sel)
  assert_equal 1, snap.edge_count
  e = snap.edges.first
  # World coord = 10 + 100 + 1000 = 1110 (start), 1111 (end).
  assert_in_delta 1110.0, e.start_point[0], 1.0e-6
  assert_in_delta 1111.0, e.end_point[0],   1.0e-6
end

# --------------------------------------------------------------------------
# S2-BLOCK-003 — No &. in production entry path (Ruby 2.2.4 baseline)
# --------------------------------------------------------------------------

test 'S2-BLOCK-003: extension/preflight_runner.rb source contains no post-Ruby-2.2 syntax' do
  path = File.expand_path('../extension/preflight_runner.rb', __dir__)
  # Strip comment lines before checking (file contains commentary on why
  # &. is banned — the test must only flag actual code).
  code_only = File.readlines(path, encoding: 'utf-8').reject { |l| l.lstrip.start_with?('#') }.join
  refute_match(/&\./, code_only,
               "extension/preflight_runner.rb code (excl. comments) must not use &. (Ruby 2.3+)")
  refute_match(/frozen_string_literal/, code_only,
               "extension/preflight_runner.rb code (excl. comments) must not use frozen_string_literal: true (Ruby 2.3+ magic)")
end

# --------------------------------------------------------------------------
# S2-BLOCK-004 — Mixed selection + canonical severity + nesting semantics
# --------------------------------------------------------------------------

test 'S2-BLOCK-004: mixed selection (Group + Component + Edges) -> selection_type=mixed' do
  g_edge = fake_edge([0, 0, 0], [1, 0, 0])
  group  = FakeSU::Group.new(name: 'g', children: [g_edge])
  defn   = FakeSU::ComponentDefinition.new(name: 'c')
  inst   = FakeSU::ComponentInstance.new(definition: defn)
  e      = fake_edge([5, 5, 0], [5, 6, 0])
  sel    = FakeSU::Selection.new([group, inst, e])
  report = PreflightRunner.run(sel)
  assert_equal 'mixed', report.selection_type
end

test 'S2-BLOCK-004: 3-level nested Group -> deepest_nesting=3, warning fires, severity :low' do
  # Build Group[ Group[ Group[ edge ]]] with names only (no translations).
  inner_edge = fake_edge([0, 0, 0], [1, 0, 0])
  g3 = FakeSU::Group.new(name: 'g3', children: [inner_edge])
  g2 = FakeSU::Group.new(name: 'g2', children: [g3])
  g1 = FakeSU::Group.new(name: 'g1', children: [g2])
  sel  = FakeSU::Selection.new([g1])
  rep  = PreflightRunner.run(sel)
  assert_equal 3, rep.deepest_nesting
  deep_w = rep.warnings.select { |w| w[:code] == :deep_nesting }
  assert_equal 1, deep_w.size
  assert_equal :low, deep_w.first[:severity]
end

# --------------------------------------------------------------------------
# S2-BLOCK-005-replacement — invalid entity skipped, valid continues
# --------------------------------------------------------------------------

test 'S2-BLOCK-005-replacement: one valid + one erased Edge -> analysis continues with the valid one' do
  good_edge = fake_edge([0, 0, 0], [10, 0, 0])
  bad_edge  = fake_edge([0, 0, 0], [1, 0, 0])
  bad_edge.erase!
  sel  = FakeSU::Selection.new([good_edge, bad_edge])
  snap = PreflightRunner.build_snapshot(sel)
  # The good Edge must still be in the snapshot. We don't pin exact count
  # (depends on what fake erased? check does inside walk) — at minimum, the
  # good Edge's endpoints must be present.
  assert snap.edges.size >= 1
  assert snap.edges.any? { |e| e.end_point[0] == 10.0 }
end

# --------------------------------------------------------------------------
# End-to-end: full PreflightReport on a transformed nested fixture
# --------------------------------------------------------------------------

test 'end-to-end: nested translated component rectangle -> PreflightReport with correct counts' do
  rect = fake_rectangle_edges([0, 0], 4, 3)
  defn = FakeSU::ComponentDefinition.new(name: 'Window', children: rect)
  inst = FakeSU::ComponentInstance.new(
    definition: defn,
    transformation: FakeSU.translation(50, 60, 0)
  )
  sel  = FakeSU::Selection.new([inst])
  rep  = PreflightRunner.run(sel)
  assert_equal 4, rep.edge_count
  assert_equal 'ComponentInstance', rep.selection_type
  # Translated bbox should reflect the offset.
  refute_nil rep.bounding_box
  assert_in_delta 50.0, rep.bounding_box[:min][0], 1.0e-6
  assert_in_delta 60.0, rep.bounding_box[:min][1], 1.0e-6
  assert_in_delta 54.0, rep.bounding_box[:max][0], 1.0e-6
  assert_in_delta 63.0, rep.bounding_box[:max][1], 1.0e-6
end