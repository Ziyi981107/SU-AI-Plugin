#
# tests/test_v19a_final_p0_live_coordinates.rb
#
# V1.9A FINAL BLOCK FIX — P0 live-coordinate authority
# focused regression tests for
# DerivedTopologySnapshotBuilder.build.
#
# Per dispatch Prompt/AIPM_V1_9A_FINAL_BLOCK_FIX_2026-09-07.md
# §1 (P0 BLOCK) + §9.1 (P0 current-coordinate
# unit/regression):
#
#   1. A derived record's cached geometry_summary carries
#      an OLD Z; the host vertex handle resolves to a
#      different CURRENT Z via adapter.vertex_position;
#      DerivedTopologySnapshotBuilder MUST publish the
#      LIVE Z in BOTH edge and endpoint records; cached
#      old Z MUST NOT leak into canonical coordinates.
#
#   2. Failure coverage: live handle exists + adapter
#      exposes vertex_position + unreadable/non-finite
#      current position -> fail closed; no stale-cache
#      substitution.
#
# These tests exercise the real
# DerivedTopologySnapshotBuilder.build path against the
# production FakeDerivedWorkspaceAdapter. They DO NOT
# patch / monkey-patch / re-implement the snapshot
# builder. The fake adapter's vertex_position seam is
# the same one production uses to verify V1.6 mutations.
#
# Per dispatch §1.3 the fix is in the
# DerivedTopologySnapshotBuilder / equivalent local helper.
# The tests assert the actual snapshot output, not
# implementation details.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/face_record'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/vertex_record'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/derived_entity_record'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'
require_relative '../extension/su_ai_plugin/core/source_snapshot'
require_relative '../extension/su_ai_plugin/core/endpoint_record'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'

include SUAnalysis::Core

V19A_FP_RUNNER = SUAnalysis::Core::WorkingModeRunner

# ---- helpers -----------------------------------------------------

# Build a frozen SourceSnapshot whose captured
# ExecutionConfig carries the supplied Tolerance. Real
# production path drives the runner's tolerance from
# this captured snapshot (see WorkingModeRunner
# _tolerance_from_snapshot).
def v19a_fp_source(edges, tolerance)
  layer = LayerRecord.new(name: 'L0')
  recs = edges.map.with_index do |(s, e), i|
    EdgeRecord.new(
      id: i,
      source: SourceReference.new(
        entity_id: 1 + i, persistent_id: 100 + i, kind: 'edge',
        persistent_id_path: [100 + i], instance_path: [],
        structural_depth: 0, pid_path_complete: true, layer_name: 'L0'
      ),
      start_point: s, end_point: e, layer: 'L0'
    )
  end
  profile = Struct.new(:profile_name, :tolerance).new('v19a-final-p0', tolerance)
  ec = ExecutionConfigSnapshot.from_live_config(
    profile, rule_set_digest: 'v19a-final-p0-rules',
    source_snapshot_schema_version: 'v1'
  )
  SourceSnapshot.new(
    edges: recs, faces: [], layers: [layer], execution_config: ec,
    selection_scope: [], unit: 'inches', coordinate_origin: 'raw',
    transform_context: {}
  )
end

def v19a_fp_tol(coord_eps = 1.0e-6)
  Tolerance.new(duplicate: 1.0e-4, short_edge: 0.5,
                gap_search: 0.5, coordinate_epsilon: coord_eps)
end

def v19a_fp_prepare(edges, tolerance)
  V19A_FP_RUNNER.reset_for_tests
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  snap = V19A_FP_RUNNER.prepare(
    source: v19a_fp_source(edges, tolerance), adapter: adapter, model: nil
  )
  unless snap['state'] == 'ready'
    raise "v19a_fp_prepare expected workspace state 'ready'; got " \
          "#{snap['state'].inspect} (#{snap['last_error'].inspect})"
  end
  [adapter, V19A_FP_RUNNER.current_workspace_for_test]
end

# ===========================================================
# P0 — LIVE coordinates over CACHED coordinates
# ===========================================================

# Primary Owner-fixture equivalent: one edge starts at
# (0,0,0.0) (cached Z = 0.0) and the host handle's
# CURRENT position has been mutated to Z = 0.2 mm
# (= 0.2 / 25.4 inches ≈ 0.007874015748031498).
# The snapshot builder MUST publish the LIVE coordinate,
# not the cached coordinate.
test 'v19a_final_p0 (P0-LIVE): cached Z=0.0 + live Z=0.007874... -> snapshot publishes live Z' do
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]
    ],
    v19a_fp_tol
  )
  # Simulate V1.6 mutation: the fake vertex handle for the
  # first edge's start has been moved from Z=0 to
  # Z=0.007874015748031498 (= 0.2 mm). The fixture's
  # geometry_summary CACHE remains at the build-time Z=0
  # (this is the exact bug P0 closes).
  edid = ws.entities.first.derived_id.to_s
  host_edge = adapter.created_handles.find { |h|
    h.respond_to?(:entityID) && h.entityID.to_s.include?('fake-') &&
      h.start.is_a?(DerivedWorkspaceAdapter::FakeVertex) &&
      h.start.x == 0.0 && h.start.y == 0.0 && h.start.z == 0.0
  }
  refute_nil host_edge, 'host edge handle MUST be resolvable from the fake adapter'
  # Apply the LIVE Z mutation directly on the FakeVertex.
  host_edge.start.z = 0.007874015748031498
  # Run the snapshot builder through the production path.
  result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
    workspace: ws, adapter: adapter, vertex_keys_by_edge: {}
  )
  # The published LIVE Z MUST reach the edge record.
  edge = result['edges'].find { |e| e.derived_edge_id.to_s == edid }
  refute_nil edge, "edge record for derived_id=#{edid} MUST be present"
  start_coord = edge.world_endpoints[0]
  end_coord   = edge.world_endpoints[1]
  assert_in_delta 0.007874015748031498, start_coord[2], 1.0e-9,
                  'P0-LIVE: published START Z MUST equal the LIVE host coordinate ' \
                  "(0.2 mm / 25.4 inches), not the cached Z=0.0; got #{start_coord.inspect}"
  # End coordinate: untouched in this fixture. Use cached
  # fallback (no live mutation). Must remain 0.0.
  assert_in_delta 0.0, end_coord[2], 1.0e-9,
                  'P0-LIVE: published END Z MUST equal the cached fallback (no live mutation)'
  # The matching EndpointRecord MUST carry the LIVE Z too.
  start_ep = result['endpoints'].find { |e| e.endpoint_key == "#{edid}.start" }
  refute_nil start_ep, 'P0-LIVE: START endpoint record MUST be present'
  assert_in_delta 0.007874015748031498, start_ep.world_coordinate[2], 1.0e-9,
                  'P0-LIVE: EndpointRecord.world_coordinate Z MUST equal the LIVE host Z'
end

# Owner-fixture equivalent (real SU2020 evidence): one
# safe Z drift (0.2 mm) + one safe endpoint gap (1.0 mm).
# After V1.6 host mutation the V1.7 topology snapshot MUST
# publish the LIVE coordinates (no 0.2 mm residue).
test 'v19a_final_p0 (P0-OWNER-FIXTURE): combined Z+Gap -> V1.7 snapshot publishes post-V1.6 live coordinates (no 0.2 mm residue)' do
  # Two edges forming a near-closed rectangle:
  #   e0: (0,0,0)        -> (5,0,0)
  #   e1: (5.04,0,0)     -> (10,0,0)   endpoint gap 0.04 in
  #   e2: (10,0,0)       -> (10,5,0)
  #   e3: (0,5,0)        -> (0,0,0)
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
      [[5.04, 0.0, 0.0], [10.0, 0.0, 0.0]],
      [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
      [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
    ],
    v19a_fp_tol(0.05)
  )
  # Simulate V1.6 mutation: mutate the LIVE host Z of
  # every vertex on the FIRST edge (e0) to 0.2 mm
  # (= 0.2 / 25.4 in). The cached geometry_summary Z
  # remains at 0.0.
  fake_edges = adapter.created_handles.select { |h| h.respond_to?(:start) && h.start.is_a?(DerivedWorkspaceAdapter::FakeVertex) }
  e0 = fake_edges.find { |e| e.start.x == 0.0 && e.start.y == 0.0 && e.start.z == 0.0 && e.end.x == 5.0 }
  refute_nil e0, 'host edge e0 MUST be resolvable'
  live_z = 0.007874015748031498 # 0.2 mm
  e0.start.z = live_z
  e0.end.z   = live_z
  # Run the snapshot builder through the production path.
  result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
    workspace: ws, adapter: adapter, vertex_keys_by_edge: {}
  )
  # The published edges MUST carry the LIVE Z (0.007874...).
  # No 0.2 mm residue is permitted; if the cached Z=0.0
  # leaked through, the V1.8 reconstruction would flag the
  # loop as non_planar (which is the bug P0 closes).
  e0_edge = result['edges'].find { |e|
    e.world_endpoints[0][0] == 0.0 && e.world_endpoints[0][1] == 0.0 &&
      e.world_endpoints[1][0] == 5.0 && e.world_endpoints[1][1] == 0.0
  }
  refute_nil e0_edge, 'P0-OWNER-FIXTURE: e0 edge record MUST be present'
  assert_in_delta live_z, e0_edge.world_endpoints[0][2], 1.0e-9,
                  'P0-OWNER-FIXTURE: e0.start Z MUST be the LIVE coordinate, not the cached 0.0'
  assert_in_delta live_z, e0_edge.world_endpoints[1][2], 1.0e-9,
                  'P0-OWNER-FIXTURE: e0.end Z MUST be the LIVE coordinate'
  # The matching endpoints must agree.
  e0_start_ep = result['endpoints'].find { |e| e.role == 'start' && e.world_coordinate[0] == 0.0 }
  refute_nil e0_start_ep
  assert_in_delta live_z, e0_start_ep.world_coordinate[2], 1.0e-9,
                  'P0-OWNER-FIXTURE: e0.start EndpointRecord Z MUST be the LIVE coordinate'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# P0 — FAIL CLOSED when live coordinate is unreadable
# ===========================================================

# Adapter exposes vertex_position BUT returns malformed
# (non-Array) value -> must fail closed with the
# stable reason `live_vertex_position_unreadable`.
test 'v19a_final_p0 (P0-FAILCLOSED-MALFORMED): vertex_position returns non-Array -> LiveVertexPositionUnreadable' do
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]
    ],
    v19a_fp_tol
  )
  # Define a FakeVertex-shim adapter subclass that
  # overrides vertex_position to return a malformed
  # value (e.g. a Hash instead of an Array).
  bad_adapter_class = Class.new(adapter.class) do
    def vertex_position(_h); return { x: 0, y: 0, z: 0 }; end
  end
  bad_adapter = bad_adapter_class.new
  # Need to populate the bad adapter with the workspace's
  # vertex handles so handle_for resolves.
  ws.entities.each do |rec|
    bad_adapter.created_handles << adapter.handle_for(rec.derived_id.to_s)
  end
  # Snapshot build MUST raise the narrowest existing
  # error path: LiveVertexPositionUnreadable with the
  # stable reason substring.
  err = assert_raises(SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable) do
    SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: bad_adapter, vertex_keys_by_edge: {}
    )
  end
  assert_includes err.message, 'live_vertex_position_unreadable',
                  'P0-FAILCLOSED-MALFORMED: error message MUST contain the stable reason'
  assert_equal 'live_vertex_position_unreadable', err.reason
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# Adapter exposes vertex_position AND returns a finite
# Float -> snapshot MUST publish the live coordinate.
test 'v19a_final_p0 (P0-LIVE-VALID): vertex_position returns finite [x,y,z] -> snapshot uses live coordinate' do
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]
    ],
    v19a_fp_tol
  )
  # Override vertex_position to return a deterministic
  # live coordinate different from the cached value.
  live = [7.0, 8.0, 9.0]
  live_adapter_class = Class.new(adapter.class) do
    define_method(:vertex_position) { |_h| live }
  end
  live_adapter = live_adapter_class.new
  ws.entities.each do |rec|
    live_adapter.created_handles << adapter.handle_for(rec.derived_id.to_s)
  end
  result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
    workspace: ws, adapter: live_adapter, vertex_keys_by_edge: {}
  )
  edge = result['edges'].first
  assert_equal [7.0, 8.0, 9.0], edge.world_endpoints[0],
               'P0-LIVE-VALID: edge.start MUST publish the live [x,y,z]'
  assert_equal [7.0, 8.0, 9.0], edge.world_endpoints[1],
               'P0-LIVE-VALID: edge.end MUST publish the live [x,y,z]'
  # Endpoint records MUST match.
  start_ep = result['endpoints'].find { |e| e.role == 'start' }
  assert_equal [7.0, 8.0, 9.0], start_ep.world_coordinate
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# Adapter exposes vertex_position but returns nil -> must
# fall back to the cached coordinate (host-free path).
test 'v19a_final_p0 (P0-LIVE-NIL): vertex_position returns nil -> falls back to cached coordinate' do
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]
    ],
    v19a_fp_tol
  )
  nil_adapter_class = Class.new(adapter.class) do
    def vertex_position(_h); return nil; end
  end
  nil_adapter = nil_adapter_class.new
  ws.entities.each do |rec|
    nil_adapter.created_handles << adapter.handle_for(rec.derived_id.to_s)
  end
  result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
    workspace: ws, adapter: nil_adapter, vertex_keys_by_edge: {}
  )
  edge = result['edges'].first
  # Cached fallback: 0.0 Z.
  assert_equal [0.0, 0.0, 0.0], edge.world_endpoints[0],
               'P0-LIVE-NIL: cached fallback MUST be used when live coordinate is nil'
  assert_equal [10.0, 0.0, 0.0], edge.world_endpoints[1]
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# Adapter exposes vertex_position and returns a non-finite
# (Float::INFINITY) -> must fail closed.
test 'v19a_final_p0 (P0-FAILCLOSED-INFINITY): vertex_position returns Float::INFINITY -> LiveVertexPositionUnreadable' do
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]
    ],
    v19a_fp_tol
  )
  inf_adapter_class = Class.new(adapter.class) do
    def vertex_position(_h); return [Float::INFINITY, 0.0, 0.0]; end
  end
  inf_adapter = inf_adapter_class.new
  ws.entities.each do |rec|
    inf_adapter.created_handles << adapter.handle_for(rec.derived_id.to_s)
  end
  err = assert_raises(SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable) do
    SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: inf_adapter, vertex_keys_by_edge: {}
    )
  end
  assert_includes err.message, 'live_vertex_position_unreadable'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# P0 — HOST-FREE FALLBACK (no live handle)
# ===========================================================

# Adapter = nil -> builder MUST fall back to cached
# coordinates (pure-test path).
test 'v19a_final_p0 (P0-NO-ADAPTER): nil adapter -> cached coordinates are published verbatim' do
  _adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]
    ],
    v19a_fp_tol
  )
  result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
    workspace: ws, adapter: nil, vertex_keys_by_edge: {}
  )
  edge = result['edges'].first
  assert_equal [0.0, 0.0, 0.0],  edge.world_endpoints[0],
               'P0-NO-ADAPTER: cached start coord MUST be published'
  assert_equal [10.0, 0.0, 0.0], edge.world_endpoints[1],
               'P0-NO-ADAPTER: cached end coord MUST be published'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# P0 — ERROR CLASS / SOURCE-LEVEL GUARDS
# ===========================================================

test 'v19a_final_p0 (P0-ERROR-CLASS): LiveVertexPositionUnreadable carries stable reason + endpoint_key' do
  err = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable.new(
    endpoint_key: 'fake-edge.start'
  )
  assert_equal 'live_vertex_position_unreadable', err.reason
  assert_equal 'fake-edge.start', err.endpoint_key
  assert_includes err.message, 'live_vertex_position_unreadable'
  assert_includes err.message, 'fake-edge.start'
end

test 'v19a_final_p0 (P0-SOURCE-LEVEL): endpoint_record.rb does NOT mutate cached geometry_summary' do
  # Defense-in-depth: the fix MUST NOT rewrite
  # geometry_summary. The cached summary remains the
  # build-time snapshot; live coordinates are applied to
  # the OUTGOING EdgeRecord / EndpointRecord only.
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/endpoint_record.rb',
      __dir__
    )
  )
  refute_match(/@geometry_summary\s*=/, src,
               'endpoint_record.rb MUST NOT reassign @geometry_summary (live coords go to outgoing records only)')
  refute_match(/rec\.geometry_summary\s*=/, src,
               'endpoint_record.rb MUST NOT mutate rec.geometry_summary in place')
  # The snapshot builder MUST still publish via
  # DerivedEdgeRecord / EndpointRecord constructors with
  # the LIVE coordinates.
  assert_match(/DerivedEdgeRecord\.new\(/, src,
               'endpoint_record.rb MUST still publish via DerivedEdgeRecord.new')
  assert_match(/EndpointRecord\.new\(/, src,
               'endpoint_record.rb MUST still publish via EndpointRecord.new')
end
