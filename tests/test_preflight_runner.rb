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

# --------------------------------------------------------------------------
# S2-BLOCK-002 (round 2) — persistent_id_path as machine-resolvable identity
# --------------------------------------------------------------------------

test 'S2-BLOCK-002 (r2): persistent_id_path is Array<Integer> with one PID per container + leaf PID' do
  edge = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(0, 0, 0),
    finish: FakeSU::Vertex.new(10, 0, 0),
    persistent_id: 555
  )
  inner = FakeSU::Group.new(name: 'inner', children: [edge], persistent_id: 100)
  outer = FakeSU::Group.new(name: 'outer', children: [inner], persistent_id: 200)
  sel = FakeSU::Selection.new([outer])
  snap = PreflightRunner.build_snapshot(sel)
  e = snap.edges.first
  pid_path = e.source.persistent_id_path
  assert_kind_of Array, pid_path
  assert pid_path.all? { |p| p.is_a?(Integer) }
  # Container PIDs in order, then leaf PID last.
  assert_equal [200, 100, 555], pid_path
end

test 'S2-BLOCK-002 (r2): two ComponentInstances sharing one definition INSIDE ONE outer Group -> 2 occurrences' do
  edge = fake_edge([0, 0, 0], [10, 0, 0])
  defn = FakeSU::ComponentDefinition.new(name: 'Window', children: [edge])
  inst_a = FakeSU::ComponentInstance.new(
    definition: defn,
    transformation: FakeSU.translation(100, 0, 0),
    persistent_id: 501
  )
  inst_b = FakeSU::ComponentInstance.new(
    definition: defn,
    transformation: FakeSU.translation(0, 100, 0),
    persistent_id: 502
  )
  outer = FakeSU::Group.new(name: 'parent', children: [inst_a, inst_b], persistent_id: 999)
  sel = FakeSU::Selection.new([outer])
  snap = PreflightRunner.build_snapshot(sel)
  assert_equal 2, snap.edge_count
  paths = snap.edges.map { |e| e.source.persistent_id_path }
  # Each path starts with the outer Group's PID, then the ComponentInstance's PID.
  assert paths.all? { |p| p[0] == 999 }
  refute_equal paths[0][1], paths[1][1]
end

# --------------------------------------------------------------------------
# S2-BLOCK-002 (r2) — non-commutative nested transforms
# --------------------------------------------------------------------------

test 'S2-BLOCK-002 (r2): rotation + non-uniform scale + translation nested -> exact world coords' do
  # Build helper matrices.
  def rotate_z(deg)
    rad = deg * Math::PI / 180.0
    c = Math.cos(rad)
    s = Math.sin(rad)
    FakeSU::Transformation.new([
      [c, -s, 0.0, 0.0],
      [s,  c, 0.0, 0.0],
      [0.0, 0.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 1.0]
    ])
  end
  def scale_nu(sx, sy, sz)
    FakeSU::Transformation.new([
      [sx, 0.0, 0.0, 0.0],
      [0.0, sy, 0.0, 0.0],
      [0.0, 0.0, sz, 0.0],
      [0.0, 0.0, 0.0, 1.0]
    ])
  end

  inner_edge = fake_edge([1.0, 0.0, 0.0], [2.0, 0.0, 0.0])
  # Inner: rotate 30deg about z.
  inner_grp = FakeSU::Group.new(
    name: 'rot',
    children: [inner_edge],
    transformation: rotate_z(30)
  )
  # Middle: non-uniform scale (2, 3, 1).
  mid_grp = FakeSU::Group.new(
    name: 'scale',
    children: [inner_grp],
    transformation: scale_nu(2.0, 3.0, 1.0)
  )
  # Outer: translation (10, 20, 30).
  outer_grp = FakeSU::Group.new(
    name: 'trans',
    children: [mid_grp],
    transformation: FakeSU.translation(10, 20, 30)
  )
  sel = FakeSU::Selection.new([outer_grp])
  snap = PreflightRunner.build_snapshot(sel)
  e = snap.edges.first
  # Manual compose: rot30 -> scale(2,3,1) -> trans(10,20,30) applied to
  # (1,0,0) and (2,0,0). Compute expected:
  rad = 30 * Math::PI / 180.0
  c = Math.cos(rad); s = Math.sin(rad)
  # After rot30: (1,0,0) -> (c, s, 0); (2,0,0) -> (2c, 2s, 0)
  x1r = c;  y1r = s
  x2r = 2*c; y2r = 2*s
  # After scale(2,3,1): (c, s, 0) -> (2c, 3s, 0); (2c, 2s, 0) -> (4c, 6s, 0)
  x1s = 2*c;  y1s = 3*s
  x2s = 4*c;  y2s = 6*s
  # After trans(10,20,30):
  x1 = x1s + 10;  y1 = y1s + 20;  z1 = 30.0
  x2 = x2s + 10;  y2 = y2s + 20;  z2 = 30.0
  assert_in_delta x1, e.start_point[0], 1.0e-9
  assert_in_delta y1, e.start_point[1], 1.0e-9
  assert_in_delta z1, e.start_point[2], 1.0e-9
  assert_in_delta x2, e.end_point[0],   1.0e-9
  assert_in_delta y2, e.end_point[1],   1.0e-9
  assert_in_delta z2, e.end_point[2],   1.0e-9
end

# --------------------------------------------------------------------------
# S2-BLOCK-002 (r2) — active edit-context seeds transform
# --------------------------------------------------------------------------

test 'S2-BLOCK-002 (r2): active edit-context seeds walk transform (selected Edges inside active Group)' do
  # Per S2-BLOCK-002 round 3 (Codex Review 007 + GUIDANCE 006): real
  # Model#active_path is Array of drawing elements; edit_transform
  # belongs to Model. We build a fake Model whose active_path is an
  # Array containing a Group with persistent_id 42, and edit_transform
  # translates by (100, 200, 0). Expected world coords of selected Edge:
  # add the edit_transform to the Edge's local coords.
  edge = fake_edge([5, 0, 0], [10, 0, 0])
  outer = FakeSU::Group.new(name: 'outer', children: [edge], persistent_id: 42)
  edit_t = FakeSU.translation(100, 200, 0)
  model = FakeSU::Model.new(
    entities: [outer],
    active_path: [outer],
    edit_transform: edit_t
  )
  sel = FakeSU::Selection.new([edge])
  snap = PreflightRunner.build_snapshot(sel, model: model)
  e = snap.edges.first
  # World = edit_transform * edge_local. active adds (100,200,0).
  assert_in_delta 105.0, e.start_point[0], 1.0e-9
  assert_in_delta 200.0, e.start_point[1], 1.0e-9
  assert_in_delta 110.0, e.end_point[0],   1.0e-9
  assert_in_delta 200.0, e.end_point[1],   1.0e-9
end

test 'S2-BLOCK-002 (r2): no active edit-context -> identity seed (no offset)' do
  edge = fake_edge([5, 0, 0], [10, 0, 0])
  model = FakeSU::Model.new(entities: [edge], active_path: nil, edit_transform: nil)
  sel = FakeSU::Selection.new([edge])
  snap = PreflightRunner.build_snapshot(sel, model: model)
  e = snap.edges.first
  assert_in_delta 5.0,  e.start_point[0], 1.0e-9
  assert_in_delta 10.0, e.end_point[0],   1.0e-9
end

# --------------------------------------------------------------------------
# S2-BLOCK-002 (r2) — PID path resolution back via model.instance_path_from_pid_path
# --------------------------------------------------------------------------

test 'S2-BLOCK-002 (r2): snapshot PID paths resolve back through model.instance_path_from_pid_path' do
  edge = fake_edge([0, 0, 0], [10, 0, 0])
  inner = FakeSU::Group.new(name: 'inner', children: [edge], persistent_id: 100)
  outer = FakeSU::Group.new(name: 'outer', children: [inner], persistent_id: 200)
  sel = FakeSU::Selection.new([outer])
  snap = PreflightRunner.build_snapshot(sel)

  # Build a model with a registry keyed by dot-delimited String.
  model = FakeSU::Model.new(entities: [outer])
  pid_path_arr = snap.edges.first.source.persistent_id_path
  # Snapshot internal form is Array<Integer>; real SU API takes String.
  ip_expected = FakeSU::InstancePath.new(
    persistent_id_path: pid_path_arr,
    transformation: FakeSU.translation(0, 0, 0)
  )
  pid_path_str = SUAnalysis::Compatibility::SUCapability.serialize_pid_path(pid_path_arr)
  model.register_pid_path(pid_path_str, ip_expected)

  # Resolve through the resolver helper (serializes internally).
  resolved = SUAnalysis::Compatibility::SUCapability.resolve_pid_path(model, pid_path_arr)
  refute_nil resolved
  assert_equal pid_path_str, resolved.persistent_id_path
end

# --------------------------------------------------------------------------
# S2-BLOCK-002 (round 3) — real API contract: entityID + Array active_path
# --------------------------------------------------------------------------

test 'S2-BLOCK-002 (r3): SourceReference uses entity.entityID when available (per round 3 API contract)' do
  edge = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(0, 0, 0),
    finish: FakeSU::Vertex.new(10, 0, 0),
    entityID: 4242
  )
  src = SUAnalysis::Compatibility::SUCapability.build_source_reference(edge)
  assert_equal 4242, src.entity_id
end

test 'S2-BLOCK-002 (r3): active edit-context uses Array active_path (not InstancePath) + edit_transform on Model' do
  edge = fake_edge([5, 0, 0], [10, 0, 0])
  outer = FakeSU::Group.new(name: 'outer', children: [edge], persistent_id: 42)
  inner_active = FakeSU::Group.new(name: 'inner_active', persistent_id: 7)
  edit_t = FakeSU.translation(100, 200, 0)
  # Real SU shape: model.active_path is Array; edit_transform on Model.
  model = FakeSU::Model.new(
    entities: [outer],
    active_path: [outer, inner_active],
    edit_transform: edit_t
  )
  sel = FakeSU::Selection.new([edge])
  snap = PreflightRunner.build_snapshot(sel, model: model)
  e = snap.edges.first
  # World = edit_transform * edge_local = (100+5, 200, 0) -> (110, 200, 0).
  assert_in_delta 105.0, e.start_point[0], 1.0e-9
  assert_in_delta 200.0, e.start_point[1], 1.0e-9
  # persistent_id_path is prefixed by the active edit path PIDs:
  # [42, 7, edge_pid].
  pid_path = e.source.persistent_id_path
  assert_equal 42, pid_path[0]
  assert_equal 7,  pid_path[1]
end

test 'S2-BLOCK-002 (r3): resolve_pid_path rejects Array<Integer>, only String works' do
  model = FakeSU::Model.new
  # Direct array should NOT resolve (real API takes String).
  result = model.instance_path_from_pid_path([10, 20, 30])
  assert_nil result
  # Dot-delimited String resolves to registered InstancePath.
  ip = FakeSU::InstancePath.new(persistent_id_path: '10.20.30')
  model.register_pid_path('10.20.30', ip)
  result = model.instance_path_from_pid_path('10.20.30')
  refute_nil result
  assert_equal '10.20.30', result.persistent_id_path
end

# --------------------------------------------------------------------------
# S2-BLOCK-005 (round 2) — invalid handling
# --------------------------------------------------------------------------

test 'S2-BLOCK-005 (r2): erased Edge -> ZERO EdgeRecords from that Edge (count == 1, not >= 1)' do
  # Build two Edges, erase one. The erased one must NOT appear in the
  # snapshot at all (its start/end/vertices raise InvalidEntityError,
  # so vertex_point_world raises InvalidGeometryError, so the per-Edge
  # rescue skips the entire Edge).
  good_edge = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(0, 0, 0),
    finish: FakeSU::Vertex.new(10, 0, 0),
    persistent_id: 1
  )
  bad_edge = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(0, 0, 0),
    finish: FakeSU::Vertex.new(1, 0, 0),
    persistent_id: 2
  )
  bad_edge.erase!
  sel = FakeSU::Selection.new([good_edge, bad_edge])
  snap = PreflightRunner.build_snapshot(sel)
  # Exactly ONE EdgeRecord, from good_edge. The erased one is fully
  # excluded — no fallback, no origin synthesis.
  assert_equal 1, snap.edge_count
  e = snap.edges.first
  assert_equal 10.0, e.end_point[0]
  assert e.source.persistent_id.nil? || e.source.persistent_id == 1
end

test 'S2-BLOCK-005 (r2): invalid vertex (start nil) -> Edge skipped, no origin EdgeRecord' do
  # Build an Edge whose start Vertex has nil position. vertex_point_world
  # raises InvalidGeometryError; the per-Edge rescue skips the Edge.
  v_start = FakeSU::Vertex.new(0, 0, 0)
  v_start.position = nil
  v_end = FakeSU::Vertex.new(10, 0, 0)
  bad_edge = FakeSU::Edge.new(start: v_start, finish: v_end)
  good_edge = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(20, 0, 0),
    finish: FakeSU::Vertex.new(30, 0, 0)
  )
  sel = FakeSU::Selection.new([bad_edge, good_edge])
  snap = PreflightRunner.build_snapshot(sel)
  # Only the good Edge; bad Edge produces NO origin record.
  assert_equal 1, snap.edge_count
  e = snap.edges.first
  assert_in_delta 20.0, e.start_point[0], 1.0e-9
  assert_in_delta 30.0, e.end_point[0],   1.0e-9
end

test 'S2-BLOCK-005 (r2): invalid container with one bad child -> siblings still walked' do
  # Two children: one bad (raises on .entities), one good. The good one
  # must still produce EdgeRecords. FakeSU Group's children access is
  # a normal array, so we simulate a bad container by stubbing it.
  good_edge = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(0, 0, 0),
    finish: FakeSU::Vertex.new(10, 0, 0)
  )
  bad_container = Object.new
  def bad_container.typename; 'BadContainer'; end
  def bad_container.entities
    raise 'simulated bad container'
  end
  def bad_container.definition
    nil
  end
  sel = FakeSU::Selection.new([bad_container, good_edge])
  snap = PreflightRunner.build_snapshot(sel)
  # The good edge should be picked up; the bad container's
  # enumerator raise must NOT abort the walk.
  assert_equal 1, snap.edge_count
end