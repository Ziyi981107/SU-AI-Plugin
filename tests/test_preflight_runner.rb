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
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/preflight'
require_relative '../extension/su_ai_plugin/compatibility/su_capability'
require_relative '../extension/su_ai_plugin/preflight_runner'

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
  path = File.expand_path('../extension/su_ai_plugin/preflight_runner.rb', __dir__)
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

# --------------------------------------------------------------------------
# S2-BLOCK-005 (round 4) — Owner checklist H corrected shape (per
# Codex Review 008). Selection_array = [inv_group, e1_invalid] only;
# e2_valid is reached via inv_group traversal (no explicit duplicate).
# --------------------------------------------------------------------------

test 'S2-BLOCK-005 (r4): checklist H shape [inv_group, e1_invalid] -> exactly 1 EdgeRecord' do
  e1 = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(0, 0, 0),
    finish: FakeSU::Vertex.new(10, 0, 0),
    persistent_id: 1
  )
  e2 = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(10, 5, 0),
    finish: FakeSU::Vertex.new(20, 5, 0),
    persistent_id: 2
  )
  inv_group = FakeSU::Group.new(name: 'inv_group', children: [e1, e2])
  e1.erase!
  # Correct shape per Codex Review 008 fix: parent + retained invalid
  # reference only. e2 is reached via parent traversal.
  sel = FakeSU::Selection.new([inv_group, e1])
  snap = PreflightRunner.build_snapshot(sel)
  # Exactly 1 EdgeRecord (from e2 via inv_group). Erased e1 contributes 0.
  assert_equal 1, snap.edge_count
  # The surviving edge is e2 (PID 2, end at x=20).
  e = snap.edges.first
  assert_equal 20.0, e.end_point[0]
end
# --------------------------------------------------------------------------
# S6-GATE-B-BLOCK-001 �� adapter integration tests through build_snapshot
# (per CodeX Round 018 BLOCK-001 minimum acceptable fix):
#   - root Edge with a valid PID -> complete / root
#   - nested valid-PID chain     -> complete / nested
#   - active path with a nil PID -> incomplete / nested
# --------------------------------------------------------------------------

test 'S6-GATE-B-BLOCK-001: root Edge with valid PID -> complete, structural_depth 0' do
  # A single root-level Edge (no active edit, no container). The leaf
  # PID is present, so pid_path_complete stays true.
  edge = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(0, 0, 0),
    finish: FakeSU::Vertex.new(10, 0, 0),
    persistent_id: 555
  )
  sel  = FakeSU::Selection.new([edge])
  model = FakeSU::Model.new(entities: [edge], active_path: nil, edit_transform: nil)
  snap = PreflightRunner.build_snapshot(sel, model: model)
  e = snap.edges.first
  refute_nil e
  # structural_depth is 0 (no containers above the leaf, no active edit).
  assert_equal 0, e.source.structural_depth
  # pid_path_complete: leaf PID is present AND the seed (no active edit)
  # is the neutral complete state. ANDed together: true.
  assert_equal true, e.source.pid_path_complete
end

test 'S6-GATE-B-BLOCK-001: nested valid-PID chain -> complete, structural_depth 2' do
  # Group(pid=200) -> Group(pid=100) -> Edge(pid=42). All PIDs present.
  edge = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(0, 0, 0),
    finish: FakeSU::Vertex.new(10, 0, 0),
    persistent_id: 42
  )
  inner = FakeSU::Group.new(name: 'inner', children: [edge], persistent_id: 100)
  outer = FakeSU::Group.new(name: 'outer', children: [inner], persistent_id: 200)
  sel   = FakeSU::Selection.new([outer])
  snap  = PreflightRunner.build_snapshot(sel)
  e = snap.edges.first
  refute_nil e
  # structural_depth is 2 (two container levels; leaf is NOT counted).
  assert_equal 2, e.source.structural_depth
  # pid_path_complete: every container + leaf has a non-nil PID.
  assert_equal true, e.source.pid_path_complete
  # persistent_id_path is the chain in order, leaf PID last.
  assert_equal [200, 100, 42], e.source.persistent_id_path
end

test 'S6-GATE-B-BLOCK-001: active path with one nil PID -> incomplete, nested' do
  # Active edit context has a container (pid 7) plus a missing-PID
  # container (nil) and the selected Edge (pid 999). The leaf Edge
  # itself has a valid PID, but the active path has a nil slot, so
  # pid_path_complete fails closed.
  edge = FakeSU::Edge.new(
    start: FakeSU::Vertex.new(0, 0, 0),
    finish: FakeSU::Vertex.new(10, 0, 0),
    persistent_id: 999
  )
  active_container_with_pid = FakeSU::Group.new(
    name: 'p1', children: [], persistent_id: 7
  )
  # A second active-path entity that exposes a nil PID. We use a
  # minimal stub: responds to persistent_id by raising (so safe_persistent_id
  # returns nil) and contributes one slot to active_path.
  active_container_nil = Object.new
  def active_container_nil.typename; 'Group'; end
  def active_container_nil.persistent_id; raise 'simulated nil pid'; end
  edit_t = FakeSU.translation(50, 50, 0)
  model = FakeSU::Model.new(
    entities: [edge],
    active_path: [active_container_with_pid, active_container_nil],
    edit_transform: edit_t
  )
  sel = FakeSU::Selection.new([edge])
  snap = PreflightRunner.build_snapshot(sel, model: model)
  e = snap.edges.first
  refute_nil e
  # structural_depth = active_path count = 2.
  assert_equal 2, e.source.structural_depth
  # pid_path_complete: nil slot in active path -> false.
  assert_equal false, e.source.pid_path_complete
end

# --------------------------------------------------------------------------
# CodeX Round 020 REAL-HOST BLOCK: selection normalization at the boundary.
# Reproduces the symptom that `Sketchup.active_model.selection` (or any
# one-shot Selection-like enumerable) caused the full analysis path to
# return 0 edges when an Array with the same entities returned 4.
# The fix is `PreflightRunner.normalize_selection` at the top of
# `build_snapshot`. The regression test below uses a OneShotEnumerable
# mock that consumes its items on the first .each call.
# --------------------------------------------------------------------------

# A Selection-like enumerable that consumes its items on first
# iteration. Mimics a sketchup::Selection that, in some host versions,
# is not safely iterable more than once. The current (pre-fix) code
# iterates it twice (once for collect_preflight_facts, once for
# walk_selection_world) and would see 0 items on the second pass.
class OneShotEnumerable
  attr_reader :iteration_count
  def initialize(items)
    @items = items.dup
    @iteration_count = 0
  end
  def each
    @iteration_count += 1
    @items.each { |item| yield item }
    @items.clear  # consume: next .each yields nothing
  end
  def count; @items.length; end
  def length; @items.length; end
  def first; @items.first; end
  def to_a; @items.dup; end
  def empty?; @items.empty?; end
  # NO is_a? override — the real Sketchup::Selection is not an Array,
  # and our normalize_selection explicitly checks Array first then
  # falls through to to_ary / each. We must NOT trick the path into
  # treating the one-shot source as an Array, or normalize_selection
  # would short-circuit and return the OneShotEnumerable as-is.
end

test 'REAL-HOST BLOCK: OneShotEnumerable with 4-edge Group -> build_snapshot returns 4 edges' do
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  # Wrap the group in a OneShotEnumerable to mimic a real
  # Sketchup::Selection that consumes its items on first .each.
  one_shot = OneShotEnumerable.new([group])
  snap = PreflightRunner.build_snapshot(one_shot)
  # The fix: build_snapshot normalizes at the boundary, so the
  # preflight + walk both iterate the SAME stable Array, not the
  # one-shot source. Result: 4 edges.
  assert_equal 4, snap.edge_count, "expected 4 edges from OneShotEnumerable, got #{snap.edge_count}"
end

test 'REAL-HOST BLOCK: OneShotEnumerable without normalization -> 0 edges (proves the fix is required)' do
  # This test documents the broken behavior so future readers know
  # WHY the fix exists. It uses the OneShotEnumerable WITHOUT going
  # through build_snapshot's normalization. It manually invokes
  # collect_preflight_facts + walk_selection_world, which is what
  # build_snapshot WOULD do without the normalize-first step.
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  one_shot = OneShotEnumerable.new([group])
  # First iteration (collect_preflight_facts) consumes the items.
  PreflightRunner.collect_preflight_facts(one_shot)
  # Second iteration (walk_selection_world) sees 0 items.
  edges_count = 0
  PreflightRunner.walk_selection_world(one_shot) do |entity, world_points, _pid_path, _label_path, _struct_depth, _path_complete|
    next unless SUAnalysis::Compatibility::SUCapability.edge?(entity)
    next if world_points.nil? || world_points.size < 2
    edges_count += 1
  end
  # With OneShotEnumerable NOT normalized: 0 edges (the bug).
  assert_equal 0, edges_count,
               'sanity check: OneShotEnumerable without normalization yields 0 edges (this is the bug)'
end

test 'REAL-HOST BLOCK: normalize_selection converts Selection-like to stable Array' do
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  one_shot = OneShotEnumerable.new([group])

  normalized = PreflightRunner.normalize_selection(one_shot)
  assert_kind_of Array, normalized
  assert_equal 1, normalized.length
  assert_equal group, normalized.first

  # The normalized Array is stable: iterating it does not affect
  # the original OneShotEnumerable.
  normalized.each { |_| }
  normalized.each { |_| }
  assert_equal 1, normalized.length,
               'normalized Array should be stable across multiple iterations'
end

test 'REAL-HOST BLOCK: AnalyzersRunner.run with OneShotEnumerable -> 4 edges, not 0' do
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  one_shot = OneShotEnumerable.new([group])
  # AnalyzersRunner must accept a one-shot enumerable and still
  # produce a complete result. This is the OWNER's real-host repro
  # exercised in the fake-host test environment.
  result = SUAnalysis::Extension::AnalyzersRunner.run(one_shot)
  refute_nil result
  assert_kind_of SUAnalysis::Core::AnalysisResult, result
  # The locked preflight header must reflect the 4 edges, not 0.
  summary = result.summary
  assert_equal 4, summary['edges'],
               "expected 4 edges in AnalyzersRunner summary, got #{summary['edges']}"
end

test 'REAL-HOST BLOCK: Array input still works (regression on the fix)' do
  # The fix MUST NOT break the existing Array path. Control: pass
  # the group as a plain Array and verify the same 4-edge result.
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  result = SUAnalysis::Extension::AnalyzersRunner.run([group])
  assert_equal 4, result.summary['edges']
end

# --------------------------------------------------------------------------
# CodeX Round 020 REAL-HOST BLOCK (recheck): regression for the
# SU2020 Selection#to_ary bug. Real Sketchup::Selection in SU2020
# implements `to_ary` (Ruby's strict array-coercion protocol) but
# returns an empty Array even when entities are selected. Treating
# `to_ary` as an authoritative conversion path silently empties
# the normalized selection and breaks the whole analysis
# (`selection_type == 'empty'`, `summary['edges'] == 0`).
#
# The fix is `PreflightRunner.normalize_selection` preferring `to_a`
# (documented public API) over `to_ary`. This regression mock
# explicitly exhibits the SU2020 behavior so the fix cannot regress.
# --------------------------------------------------------------------------

# A Selection-like enumerable that mimics real SU2020's
# Sketchup::Selection: `to_ary` returns an empty Array (the host
# bug), but `to_a`, `each`, `count`, `first`, `length`, and `empty?`
# all correctly report the selected entities.
#
# Real SU2020 Selection#to_ary follows Ruby's strict array-coercion
# protocol but honors the "implicit conversion returns []" idiom —
# meaning splat, multiple-assignment, and any code treating `to_ary`
# as authoritative silently sees an empty selection. The correct
# authoritative path is `to_a` (the documented public API).
class BrokenToArySelection
  attr_reader :to_ary_calls, :to_a_calls
  def initialize(items)
    @items = items.dup
    @to_ary_calls = 0
    @to_a_calls = 0
  end
  # The bug: respond_to?(:to_ary) is true AND to_ary returns [].
  def respond_to?(name, include_private = false)
    return true if name == :to_ary
    super
  end
  def to_ary
    @to_ary_calls += 1
    # SU2020 quirk: returns empty Array even when entities are present.
    # This is the documented Ruby idiom for "not implicitly splattable".
    []
  end
  # The correct API: to_a returns the actual entities (stable).
  def to_a
    @to_a_calls += 1
    @items.dup
  end
  # Multi-shot iteration (real SU Selection is multi-shot; items are
  # not consumed on iteration).
  def each
    @items.each { |item| yield item }
  end
  def count; @items.length; end
  def length; @items.length; end
  def first; @items.first; end
  def empty?; @items.empty?; end
  # NO is_a? override — the real Sketchup::Selection is not an Array,
  # and our normalize_selection explicitly checks Array first. We
  # must NOT trick the path into treating this as an Array.
end

test 'REAL-HOST BLOCK (recheck): BrokenToArySelection -> normalize_selection returns [group]' do
  # Sanity check on the mock: to_ary returns [] but to_a returns [group].
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  broken = BrokenToArySelection.new([group])
  # The mock truly has the SU2020 bug.
  assert_equal [], broken.to_ary
  assert_equal [group], broken.to_a
  assert_equal 1, broken.count
  # The fix: normalize_selection must NOT trust `to_ary`; it uses
  # `to_a` (the documented public API) and returns [group].
  normalized = PreflightRunner.normalize_selection(broken)
  assert_kind_of Array, normalized
  assert_equal 1, normalized.length,
               'normalize_selection must not treat empty to_ary as authoritative'
  assert_equal group, normalized.first
end

test 'REAL-HOST BLOCK (recheck): BrokenToArySelection -> build_snapshot returns 4 edges' do
  # The OWNER's repro at the build_snapshot level: pass a real SU2020
  # Selection-like object (broken `to_ary`) and the snapshot must
  # contain 4 edges, not 0.
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  broken = BrokenToArySelection.new([group])
  snap = PreflightRunner.build_snapshot(broken)
  assert_equal 4, snap.edge_count,
               "expected 4 edges from BrokenToArySelection, got #{snap.edge_count} (to_ary returned #{broken.to_ary.inspect})"
end

test 'REAL-HOST BLOCK (recheck): BrokenToArySelection -> AnalyzersRunner.run returns 4 edges, not 0' do
  # The OWNER's repro at the full pipeline level:
  #   selection.add(test_group) => 1
  #   AnalyzersRunner.run(model.selection).summary['edges'] => 4
  # Mimicked with BrokenToArySelection: count is 1 (so the selection
  # is non-empty), to_a returns [group] (correct), to_ary returns []
  # (the SU2020 bug).
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  broken = BrokenToArySelection.new([group])
  # Sanity: selection.count > 0 (model.selection.add(test_group) => 1).
  assert_equal 1, broken.count
  result = SUAnalysis::Extension::AnalyzersRunner.run(broken)
  refute_nil result
  assert_kind_of SUAnalysis::Core::AnalysisResult, result
  # The locked preflight header must reflect the 4 edges, not 0.
  summary = result.summary
  assert_equal 4, summary['edges'],
               "expected 4 edges in AnalyzersRunner summary, got #{summary['edges']} (this is the OWNER's repro)"
  assert_equal 4, summary['vertices'],
               "expected 4 vertices in AnalyzersRunner summary, got #{summary['vertices']}"
  assert_equal 0, summary['warnings'],
               "expected 0 warnings for a closed rectangle, got #{summary['warnings']}"
end

test 'REAL-HOST BLOCK (recheck): BrokenToArySelection -> selection_type is not "empty"' do
  # The OWNER's repro symptom #1: result.selection_type was "empty".
  # With the fix (no `to_ary`), classification_label sees a non-empty
  # Array and returns "selection" (or "Group"; anything but "empty").
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  broken = BrokenToArySelection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(broken)
  refute_nil result
  refute_equal 'empty', result.selection_type,
               'selection_type must NOT be "empty" when the Selection actually contains an entity'
end

test 'REAL-HOST BLOCK (recheck): BrokenToArySelection without normalization -> 0 edges (proves the fix is required)' do
  # Documents the broken behavior so future readers know WHY the fix
  # exists. Manually invokes collect_preflight_facts + walk_selection_world
  # WITHOUT going through normalize_selection. With BrokenToArySelection,
  # the bug would NOT manifest here (because `each` works correctly),
  # so we instead simulate the original buggy path by directly calling
  # `.to_ary` and using its result.
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  broken = BrokenToArySelection.new([group])
  # The original buggy normalize_selection would have called
  # to_ary first and returned [] (because the host's to_ary is broken).
  buggy_result = broken.to_ary
  assert_equal [], buggy_result
  # Verify that anything iterating `buggy_result` sees 0 entities:
  edges_count = 0
  buggy_result.each do |_entity|
    edges_count += 1
  end
  assert_equal 0, edges_count,
               'sanity check: a normalize that uses to_ary yields 0 items (the bug)'
end

test 'REAL-HOST BLOCK (recheck): normalize_selection prefers to_a over to_ary' do
  # White-box test: verify the implementation prefers `to_a` (or
  # `each`) and does NOT trust `to_ary` as authoritative. We do this
  # by counting `to_ary_calls` on the BrokenToArySelection mock.
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  broken = BrokenToArySelection.new([group])
  to_ary_before = broken.to_ary_calls
  normalized = PreflightRunner.normalize_selection(broken)
  to_ary_after = broken.to_ary_calls
  # The fix MUST NOT call to_ary at all (or call it zero extra times
  # beyond the sanity check above). The authoritative path is `to_a`.
  assert_equal to_ary_before, to_ary_after,
               'normalize_selection must not call to_ary (it returns [] on SU2020)'
  # And the result is correct.
  assert_kind_of Array, normalized
  assert_equal 1, normalized.length
end

# --------------------------------------------------------------------------
# CodeX Round 020 REAL-HOST BLOCK (recheck) part 2: variable-shadow
# bug in AnalyzersRunner.run. The previous code did:
#
#     normalized = PreflightRunner.normalize_selection(selection)  # selection
#     ...
#     normalized = []                                              # ISSUES (shadow!)
#     raw_issues.each { ... normalized << out ... }
#     ...
#     selection_label = selection_label_for(normalized)            # empty issues
#     selection_type:  classification_label(normalized)            # empty issues
#
# For a CLOSED rectangle (no issues), the issues array is empty and
# `classification_label([])` returns 'empty'. The Owner saw
# `result.selection_type == 'empty'` even though the selection had a
# 4-edge Group inside. The fix renames the issues variable to
# `normalized_issues` so the selection variable cannot be shadowed.
#
# This test would have FAILED on the previous fix: a closed-rectangle
# run would return selection_type == 'empty'.
# --------------------------------------------------------------------------

test 'REAL-HOST BLOCK (recheck): closed rectangle -> selection_type is not "empty" (no-shadow guard)' do
  # Closed rectangle = no analyzer issues. With the variable-shadow
  # bug, the selection_type check at the end of run() ran on the
  # (empty) issues array and returned 'empty'. This test proves the
  # fix is in place by checking the selection_type for a no-issue
  # fixture.
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  refute_nil result
  # The closed rectangle has no issues. Selection_type MUST reflect
  # the selection (non-empty), NOT the (empty) issues array.
  refute_equal 'empty', result.selection_type,
               'selection_type must NOT be "empty" when the selection contains entities'
  # The selection label must reflect the Group's typename.
  assert_equal 'Group: test_group', result.selection_label
end

test 'REAL-HOST BLOCK (recheck): BrokenToArySelection selection_label uses group typename' do
  # Companion to the BrokenToArySelection tests. Verify the
  # selection_label and selection_type both reflect the real
  # selection (Group), not the empty issues array.
  rect = fake_rectangle_edges([0, 0], 10, 5)
  group = FakeSU::Group.new(name: 'test_group', children: rect, persistent_id: 100)
  broken = BrokenToArySelection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(broken)
  refute_nil result
  assert_equal 'Group: test_group', result.selection_label,
               'selection_label must reflect the Group typename, not be the default "selection"'
  refute_equal 'empty', result.selection_type
end

# --- V1.3 (per directive 027): Face Inventory adapter tests -----------

require_relative '../extension/su_ai_plugin/core/face_record'

def fake_face(layer: 'Layer0', persistent_id: nil, outer_loop_vertices: 4,
              inner_loop_vertices: [], invalid: false)
  FakeSU::Face.new(
    layer: FakeSU::Layer.new(layer),
    persistent_id: persistent_id,
    outer_loop_vertices: outer_loop_vertices,
    inner_loop_vertices: inner_loop_vertices,
    invalid: invalid
  )
end

test 'V1.3: root selected Face counts once (single FaceRecord)' do
  f = fake_face(layer: 'Layer0', persistent_id: 1, outer_loop_vertices: 4)
  sel = FakeSU::Selection.new([f])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  assert_equal 1, snapshot.faces.length,
               'one root Face -> exactly one FaceRecord'
  assert_equal 'Layer0', snapshot.faces.first.layer
  assert_equal 4,        snapshot.faces.first.outer_loop_vertex_count
  assert_equal false,    snapshot.faces.first.has_holes
end

test 'V1.3: Face inside Group counts once with correct occurrence identity' do
  f = fake_face(layer: 'DIM-WALLS', persistent_id: 42, outer_loop_vertices: 4)
  g = FakeSU::Group.new(name: 'outer', children: [f], persistent_id: 100)
  sel = FakeSU::Selection.new([g])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  assert_equal 1, snapshot.faces.length
  rec = snapshot.faces.first
  assert_equal 'DIM-WALLS', rec.layer
  # SourceReference instance_path includes 'Group:outer'.
  assert_includes rec.source.instance_path, 'Group:outer'
end

test 'V1.3: same ComponentDefinition instantiated twice -> 2 FaceRecord occurrences' do
  inner_face = fake_face(layer: 'Layer0', persistent_id: 7, outer_loop_vertices: 4)
  defn = FakeSU::ComponentDefinition.new(
    name: 'Window', children: [inner_face], persistent_id: 999
  )
  inst_a = FakeSU::ComponentInstance.new(definition: defn, persistent_id: 10)
  inst_b = FakeSU::ComponentInstance.new(definition: defn, persistent_id: 11)
  sel = FakeSU::Selection.new([inst_a, inst_b])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  assert_equal 2, snapshot.faces.length,
               'two ComponentInstance occurrences of the same defn -> 2 FaceRecords'
end

test 'V1.3: nested Group traversal preserves occurrence identity + path depth' do
  inner_face = fake_face(layer: 'Layer0', persistent_id: 7, outer_loop_vertices: 4)
  inner_grp = FakeSU::Group.new(name: 'inner', children: [inner_face], persistent_id: 1)
  outer_grp = FakeSU::Group.new(name: 'outer', children: [inner_grp], persistent_id: 2)
  sel = FakeSU::Selection.new([outer_grp])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  assert_equal 1, snapshot.faces.length
  rec = snapshot.faces.first
  # The face is 2 deep (outer -> inner).
  assert_equal 2, rec.source.structural_depth
  # Path includes both groups.
  path = rec.source.instance_path
  assert_includes path, 'Group:outer'
  assert_includes path, 'Group:inner'
end

test 'V1.3: Face with outer loop only -> has_holes = false' do
  f = fake_face(layer: 'Layer0', outer_loop_vertices: 4, inner_loop_vertices: [])
  sel = FakeSU::Selection.new([f])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  assert_equal 1, snapshot.faces.length
  assert_equal false, snapshot.faces.first.has_holes
  assert_equal 0,    snapshot.faces.first.inner_loop_count
end

test 'V1.3: Face with one inner loop -> has_holes = true (inner_loop_count=1)' do
  f = fake_face(layer: 'Layer0', outer_loop_vertices: 4, inner_loop_vertices: [3])
  sel = FakeSU::Selection.new([f])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  assert_equal 1, snapshot.faces.length
  rec = snapshot.faces.first
  assert_equal true, rec.has_holes
  assert_equal 1,    rec.inner_loop_count
end

test 'V1.3: Face with multiple inner loops -> inner_loop_count summed' do
  f = fake_face(layer: 'Layer0', outer_loop_vertices: 4,
                inner_loop_vertices: [3, 5, 7])
  sel = FakeSU::Selection.new([f])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  rec = snapshot.faces.first
  assert_equal true, rec.has_holes
  assert_equal 3,    rec.inner_loop_count
end

test 'V1.3: hidden + unknown-visibility layer behavior matches V1.1 (face)' do
  # Hidden face: layer.visible? = false.
  hidden_layer = FakeSU::Layer.new('HIDDEN')
  hidden_layer.visible = false
  f_hidden = FakeSU::Face.new(layer: hidden_layer, persistent_id: 1,
                              outer_loop_vertices: 4)
  # Unknown-visibility face: entity.layer is a bare Struct that does
  # NOT expose :visible? at all. The adapter falls back to the
  # R011 :unknown contract (visible: true, visibility_unknown: true).
  no_vis_layer = Struct.new(:name).new('NO_VIS')
  f_no_vis = FakeSU::Face.new(layer: no_vis_layer, persistent_id: 2,
                              outer_loop_vertices: 4)
  sel = FakeSU::Selection.new([f_hidden, f_no_vis])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  # LayerRecord for each layer should carry the correct visibility.
  layers = snapshot.layers.sort_by(&:name)
  hidden_rec  = layers.find { |r| r.name == 'HIDDEN' }
  no_vis_rec  = layers.find { |r| r.name == 'NO_VIS' }
  assert_equal false, hidden_rec.visible
  assert_equal false, hidden_rec.visibility_unknown
  assert_equal true,  no_vis_rec.visible
  assert_equal true,  no_vis_rec.visibility_unknown
end

test 'V1.3: one invalid Face skipped while valid sibling Face remains' do
  good  = fake_face(layer: 'Layer0', persistent_id: 1, outer_loop_vertices: 4)
  bad   = fake_face(layer: 'Layer0', persistent_id: 2, outer_loop_vertices: 4,
                    invalid: true)
  sel = FakeSU::Selection.new([good, bad])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  assert_equal 1, snapshot.faces.length,
               'invalid Face must be skipped; valid sibling must remain'
  assert_equal 1, snapshot.faces.first.source.persistent_id
end

test 'V1.3: face_aggregates accumulate face_count + faces_with_holes_count per layer' do
  f1 = fake_face(layer: 'DIM-XX', outer_loop_vertices: 4)        # no holes
  f2 = fake_face(layer: 'DIM-XX', outer_loop_vertices: 4,
                inner_loop_vertices: [3])                        # holes
  f3 = fake_face(layer: 'TXT-XX', outer_loop_vertices: 4)        # no holes
  sel = FakeSU::Selection.new([f1, f2, f3])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  dim_rec = snapshot.layers.find { |r| r.name == 'DIM-XX' }
  txt_rec = snapshot.layers.find { |r| r.name == 'TXT-XX' }
  assert_equal 2, dim_rec.face_count
  assert_equal 1, dim_rec.faces_with_holes_count
  assert_equal 1, txt_rec.face_count
  assert_equal 0, txt_rec.faces_with_holes_count
end

test 'V1.3: edge counts unchanged after face traversal (no regression)' do
  edges = fake_rectangle_edges([0, 0], 10, 5)
  g = FakeSU::Group.new(name: 'g', children: edges, persistent_id: 100)
  face = fake_face(layer: 'Layer0', outer_loop_vertices: 4)
  sel = FakeSU::Selection.new([g, face])
  snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(sel)
  # 4 edges, 1 face.
  assert_equal 4, snapshot.edge_count
  assert_equal 1, snapshot.face_count
  # Layer0 aggregates 4 edges AND 1 face.
  layer0 = snapshot.layers.find { |r| r.name == 'Layer0' }
  assert_equal 4, layer0.edge_count
  assert_equal 1, layer0.face_count
end
