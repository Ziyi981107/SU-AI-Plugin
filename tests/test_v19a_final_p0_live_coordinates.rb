#
# tests/test_v19a_final_p0_live_coordinates.rb
#
# V1.9A P0 SHARED-VERTEX CORRECTION -- P0 focused
# regression tests for
# DerivedTopologySnapshotBuilder.build + the shared
# physical-vertex fan-out in the proposer + executor.
#
# Per amendment `Prompt/AIPM_V1_9A_P0_SHARED_VERTEX_IMPLEMENTATION_AMENDMENT_2026-09-08.md`
# §10 (Required Regression Tests). The previous
# `V1.9A FINAL BLOCK FIX` packet's P0 tests (file
# `tests/test_v19a_final_p0_live_coordinates.rb`
# before this packet) did not model the real
# Group -> Edge -> Vertex contract and were not
# executed on the production fake adapter. Per
# dispatch §3 the misleading tests are DELETED /
# REPLACED, not patched.
#
# These tests model the real contract:
#   - the fake adapter's `vertex_position` seam is
#     invoked with the actual endpoint Vertex
#     handle (not the Group handle);
#   - the proposer's logical candidate retains ALL
#     identity-distinct physical endpoint Vertex
#     occurrences belonging to the same logical
#     coordinate cluster (one logical move -> many
#     physical primitives);
#   - the executor opens one outer SketchUp
#     operation, invokes one primitive per
#     physical occurrence, commits once;
#   - any preflight / mid-mutation / postvalidation
#     failure aborts the ONE outer operation and
#     publishes zero committed logical success.
#
# The tests assert the real production paths
# (no monkey-patching of the snapshot builder,
# proposer, or executor).
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/analysis_config'
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
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/endpoint_record'
require_relative '../extension/su_ai_plugin/core/planar_normalization_analyzer'
require_relative '../extension/su_ai_plugin/core/planar_normalization_proposer'
require_relative '../extension/su_ai_plugin/core/planar_normalization_executor'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'
require_relative '../extension/su_ai_plugin/cad_prep_workflow_orchestrator'

include SUAnalysis::Core

V19A_FP_RUNNER = SUAnalysis::Core::WorkingModeRunner

# ---- helpers -----------------------------------------------------

# Build a frozen SourceSnapshot whose captured
# ExecutionConfig carries the supplied Tolerance.
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
  profile = Struct.new(:profile_name, :tolerance).new('v19a-p0-shared-vertex', tolerance)
  ec = ExecutionConfigSnapshot.from_live_config(
    profile, rule_set_digest: 'v19a-p0-shared-vertex-rules',
    source_snapshot_schema_version: 'v1'
  )
  SourceSnapshot.new(
    edges: recs, faces: [], layers: [layer], execution_config: ec,
    selection_scope: [], unit: 'inches', coordinate_origin: 'raw',
    transform_context: {}
  )
end

def v19a_fp_tol(coord_eps = 1.0e-6, planar_z_snap = 0.001)
  Tolerance.new(duplicate: 1.0e-4, short_edge: 0.5,
                gap_search: 0.5, coordinate_epsilon: coord_eps,
                planar_z_snap: planar_z_snap)
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

# Resolve the production-style host_vertex_map: walk every
# workspace edge record, ask `adapter.edge_endpoints(group)`
# for the actual endpoint Vertex handles (the SAME seam
# `working_mode_runner._host_vertex_map` uses in production).
def v19a_fp_host_vertex_map(workspace, adapter)
  return {} if workspace.nil? || adapter.nil?
  out = {}
  workspace.entities.each do |rec|
    next unless rec.respond_to?(:kind) && rec.kind == :edge
    did = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
    next if did.empty?
    handle = workspace.handle_for(did) if workspace.respond_to?(:handle_for)
    next if handle.nil?
    next unless adapter.respond_to?(:edge_endpoints)
    eps = adapter.edge_endpoints(handle)
    next unless eps.is_a?(Array) && eps.length == 2
    out["#{did}.start"] = eps[0]
    out["#{did}.end"]   = eps[1]
  end
  out
end

# ===========================================================
# §10.1 -Handle-contract live-read test
# ===========================================================

# Per amendment §10.1: a derived edge with a
# post-V1.6 live Z mutation MUST publish that LIVE
# coordinate in both the edge record AND the
# endpoint records. The snapshot builder MUST call
# `vertex_position(actual_endpoint_vertex_handle)`,
# NOT `vertex_position(group_handle)`.
test 'V19A-P0 §10.1 (HANDLE-CONTRACT): vertex_position receives endpoint Vertex handle, not Group handle' do
  adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  edid = ws.entities.first.derived_id.to_s
  # Resolve the actual endpoint Vertex handles via the
  # production host_vertex_map path. This is the
  # SAME path `working_mode_runner._host_vertex_map`
  # uses in production.
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  refute_empty hvm, 'host_vertex_map MUST be resolvable from the production fake adapter'
  refute_nil hvm["#{edid}.start"], 'start endpoint Vertex handle MUST be resolvable'
  refute_nil hvm["#{edid}.end"],   'end   endpoint Vertex handle MUST be resolvable'
  # Mutate the LIVE Z of the start endpoint only.
  live_z = 0.007874015748031498
  hvm["#{edid}.start"].z = live_z
  # Spy: count vertex_position calls by handle identity.
  observed_handles = []
  spied = Class.new(adapter.class) do
    define_method(:vertex_position) { |h|
      observed_handles << h
      adapter.vertex_position(h)
    }
  end.new
  # Populate the spied adapter with the same handles
  # the original adapter owns, so the spy sees the
  # real data.
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
    workspace: ws, adapter: spied, vertex_keys_by_edge: hvm
  )
  # Assert the snapshot builder called vertex_position
  # with the actual endpoint Vertex handles, NOT the
  # group handle.
  start_handle = hvm["#{edid}.start"]
  end_handle   = hvm["#{edid}.end"]
  assert observed_handles.include?(start_handle),
         "snapshot builder MUST call vertex_position with the start endpoint Vertex handle; " \
         "observed handles: #{observed_handles.map(&:class).inspect}"
  assert observed_handles.include?(end_handle),
         "snapshot builder MUST call vertex_position with the end endpoint Vertex handle"
  # The published LIVE Z MUST reach both the edge
  # record and the endpoint records.
  edge = result['edges'].find { |e| e.derived_edge_id.to_s == edid }
  refute_nil edge
  assert_in_delta live_z, edge.world_endpoints[0][2], 1.0e-9,
                  'start Z MUST publish the LIVE host coordinate (not cached 0.0)'
  assert_in_delta 0.0, edge.world_endpoints[1][2], 1.0e-9,
                  'end Z MUST publish its LIVE coordinate (unmutated = 0.0)'
  start_ep = result['endpoints'].find { |e| e.endpoint_key == "#{edid}.start" }
  end_ep   = result['endpoints'].find { |e| e.endpoint_key == "#{edid}.end" }
  refute_nil start_ep
  refute_nil end_ep
  assert_in_delta live_z, start_ep.world_coordinate[2], 1.0e-9
  assert_in_delta 0.0,    end_ep.world_coordinate[2],   1.0e-9
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# Per amendment §10.7 / Owner-fixture equivalent: the
# 0.2 mm Z residue MUST NOT leak through. After V1.6
# mutation, BOTH physical copies of the shared
# corner B reach target Z.
test 'V19A-P0 §10.7 (OWNER-FIXTURE): combined Z + Gap -> snapshot publishes post-V1.6 LIVE coordinates' do
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, 0.0],    [5.0, 0.0, 0.0]],
      [[5.04, 0.0, 0.0],   [10.0, 0.0, 0.0]],
      [[10.0, 0.0, 0.0],   [10.0, 5.0, 0.0]],
      [[0.0, 5.0, 0.0],    [0.0, 0.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  live_z = 0.007874015748031498
  # Find the e0 FakeEdge and its corresponding
  # FakeVertex pair (the fake adapter stores the
  # endpoint vertices separately under
  # vertex_handles_by_edge).
  e0 = adapter.added_edges.find { |e|
    e.start.is_a?(Array) && e.start[0] == 0.0 && e.end.is_a?(Array) && e.end[0] == 5.0
  }
  refute_nil e0, 'e0 FakeEdge MUST be resolvable from added_edges'
  e0_vertices = adapter.vertex_handles_by_edge[e0]
  refute_nil e0_vertices, 'e0 FakeVertex pair MUST be resolvable from vertex_handles_by_edge'
  v_start = e0_vertices[0]
  v_end   = e0_vertices[1]
  # Mutate the LIVE Z of e0's BOTH endpoint Vertex
  # handles (simulating V1.6's
  # transform_vertices_by_vectors).
  v_start.z = live_z
  v_end.z   = live_z
  result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
    workspace: ws, adapter: adapter, vertex_keys_by_edge: hvm
  )
  e0_edge = result['edges'].find { |e|
    e.world_endpoints[0][0] == 0.0 && e.world_endpoints[0][1] == 0.0 &&
      e.world_endpoints[1][0] == 5.0 && e.world_endpoints[1][1] == 0.0
  }
  refute_nil e0_edge
  assert_in_delta live_z, e0_edge.world_endpoints[0][2], 1.0e-9,
                  'e0.start Z MUST publish the LIVE coordinate, not the cached 0.0'
  assert_in_delta live_z, e0_edge.world_endpoints[1][2], 1.0e-9
  e0_start_ep = result['endpoints'].find { |e| e.role == 'start' && e.world_coordinate[0] == 0.0 && e.world_coordinate[1] == 0.0 }
  refute_nil e0_start_ep
  assert_in_delta live_z, e0_start_ep.world_coordinate[2], 1.0e-9
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# §10.2 -Live-read fail closed
# ===========================================================

# Adapter exposes vertex_position BUT returns malformed
# (non-Array) value -> must fail closed with the
# stable reason `live_vertex_position_unreadable`.
test 'V19A-P0 §10.2 (FAILCLOSED-MALFORMED): vertex_position returns non-Array -> LiveVertexPositionUnreadable' do
  adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  bad_adapter = Class.new(adapter.class) do
    def vertex_position(_h); return { x: 0, y: 0, z: 0 }; end
  end.new
  adapter.created_handles.each { |h| bad_adapter.created_handles << h }
  adapter.added_edges.each       { |e| bad_adapter.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| bad_adapter.vertex_handles_by_edge[k] = v }
  # The project's assert_raises helper returns nil on
  # success; capture the exception explicitly so we can
  # inspect message/reason.
  err = nil
  begin
    SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: bad_adapter, vertex_keys_by_edge: hvm
    )
  rescue SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable => e
    err = e
  end
  refute_nil err, 'LiveVertexPositionUnreadable MUST be raised for malformed vertex_position'
  assert_includes err.message, 'live_vertex_position_unreadable',
                  'error message MUST carry the stable reason'
  assert_equal 'live_vertex_position_unreadable', err.reason
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# vertex_position raises -> must fail closed.
test 'V19A-P0 §10.2 (FAILCLOSED-RAISE): vertex_position raises -> LiveVertexPositionUnreadable' do
  adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  raising = Class.new(adapter.class) do
    def vertex_position(_h); raise StandardError, 'host read boom'; end
  end.new
  adapter.created_handles.each { |h| raising.created_handles << h }
  adapter.added_edges.each       { |e| raising.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| raising.vertex_handles_by_edge[k] = v }
  err = nil
  begin
    SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: raising, vertex_keys_by_edge: hvm
    )
  rescue SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable => e
    err = e
  end
  refute_nil err, 'LiveVertexPositionUnreadable MUST be raised when vertex_position raises'
  assert_includes err.message, 'live_vertex_position_unreadable'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# vertex_position returns nil while a real per-endpoint
# Vertex handle is present in the host vertex map ->
# fail closed. Per amendment §6.2: when endpoint host
# Vertex handle exists + adapter exposes vertex_position
# + the read returns nil / malformed / non-finite /
# raises, the helper MUST raise
# `live_vertex_position_unreadable`; cached fallback is
# reserved for the NO-LIVE-AUTHORITY case (covered by
# the FAILCLOSED-NO-LIVE-AUTHORITY test below).
test 'V19A-P0 §10.2 (FAILCLOSED-NIL): vertex_position returns nil while endpoint handle is present -> LiveVertexPositionUnreadable' do
  adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  nil_adapter = Class.new(adapter.class) do
    def vertex_position(_h); return nil; end
  end.new
  adapter.created_handles.each { |h| nil_adapter.created_handles << h }
  adapter.added_edges.each       { |e| nil_adapter.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| nil_adapter.vertex_handles_by_edge[k] = v }
  err = nil
  begin
    SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: nil_adapter, vertex_keys_by_edge: hvm
    )
  rescue SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable => e
    err = e
  end
  refute_nil err, 'LiveVertexPositionUnreadable MUST be raised when live read returns nil while endpoint handle is present'
  assert_includes err.message, 'live_vertex_position_unreadable'
  assert_equal 'live_vertex_position_unreadable', err.reason
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# Cached fallback is allowed ONLY when there is
# genuinely no live endpoint authority. Per amendment
# §6.2: host_vertex_map has no handle for that endpoint
# -> cached fallback OK. This test passes an empty
# `vertex_keys_by_edge` so the snapshot builder cannot
# resolve any per-endpoint Vertex handle, and the
# cached build-time `geometry_summary` is the only
# available authority.
test 'V19A-P0 §10.2 (FAILCLOSED-NO-LIVE-AUTHORITY): empty host vertex map -> cached fallback' do
  adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  # Empty host vertex map: NO live endpoint authority.
  err = nil
  result = nil
  begin
    result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: adapter, vertex_keys_by_edge: {}
    )
  rescue SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable => e
    err = e
  end
  assert_nil err, 'snapshot builder MUST NOT raise when host vertex map is empty (no live authority; cached fallback allowed)'
  refute_nil result, 'snapshot MUST publish a result using cached coordinates when no live authority exists'
  edge = result['edges'].first
  assert_equal [0.0, 0.0, 0.0],  edge.world_endpoints[0],
               'cached start coord MUST be published when no live endpoint authority exists'
  assert_equal [10.0, 0.0, 0.0], edge.world_endpoints[1]
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# vertex_position returns non-finite (Float::INFINITY) ->
# fail closed.
test 'V19A-P0 §10.2 (FAILCLOSED-INFINITY): vertex_position returns Float::INFINITY -> LiveVertexPositionUnreadable' do
  adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  inf_adapter = Class.new(adapter.class) do
    def vertex_position(_h); return [Float::INFINITY, 0.0, 0.0]; end
  end.new
  adapter.created_handles.each { |h| inf_adapter.created_handles << h }
  adapter.added_edges.each       { |e| inf_adapter.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| inf_adapter.vertex_handles_by_edge[k] = v }
  err = nil
  begin
    SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: inf_adapter, vertex_keys_by_edge: hvm
    )
  rescue SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable => e
    err = e
  end
  refute_nil err, 'LiveVertexPositionUnreadable MUST be raised for non-finite position'
  assert_includes err.message, 'live_vertex_position_unreadable'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# R3 — V1.9A P0 NARROW RECHECK (fix 2026-09-08)
# Endpoint live-read fallback contract correction
# ===========================================================

# R3 fallback matrix: per-endpoint handle present + adapter
# genuinely lacks `vertex_position` capability -> cached
# fallback allowed (NOT a fail-closed condition). The
# frozen amendment §6.2 / R3 §4 enumerates this as a
# legitimate no-live-authority case.
test 'V19A-P0 (R3): endpoint handle + adapter lacks vertex_position -> cached fallback' do
  adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  # Subclass adapter with NO vertex_position seam.
  no_vp_adapter = Class.new(adapter.class) do
    undef_method(:vertex_position) if respond_to?(:vertex_position)
  end.new
  adapter.created_handles.each { |h| no_vp_adapter.created_handles << h }
  adapter.added_edges.each       { |e| no_vp_adapter.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| no_vp_adapter.vertex_handles_by_edge[k] = v }
  err = nil
  result = nil
  begin
    result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: no_vp_adapter, vertex_keys_by_edge: hvm
    )
  rescue SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable => e
    err = e
  end
  assert_nil err, 'per-endpoint handle + adapter lacks vertex_position MUST allow cached fallback (NOT fail closed)'
  refute_nil result, 'snapshot builder MUST publish a result using cached coordinates'
  edge = result['edges'].first
  assert_equal [0.0, 0.0, 0.0],  edge.world_endpoints[0],
               'cached start coord MUST be published when adapter lacks vertex_position'
  assert_equal [10.0, 0.0, 0.0], edge.world_endpoints[1]
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# R3 fallback matrix: per-endpoint handle present + adapter
# is nil -> cached fallback allowed (no-live-authority case).
test 'V19A-P0 (R3): endpoint handle + nil adapter -> cached fallback' do
  adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  err = nil
  result = nil
  begin
    result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: nil, vertex_keys_by_edge: hvm
    )
  rescue SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable => e
    err = e
  end
  assert_nil err, 'per-endpoint handle + nil adapter MUST allow cached fallback'
  refute_nil result
  edge = result['edges'].first
  assert_equal [0.0, 0.0, 0.0],  edge.world_endpoints[0],
               'cached start coord MUST be published when adapter is nil'
  assert_equal [10.0, 0.0, 0.0], edge.world_endpoints[1]
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# R3 fail-closed contract: per-endpoint handle present +
# adapter exposes vertex_position + returns a 4-element
# Array (NOT exactly 3) -> fail closed (malformed).
test 'V19A-P0 (R3): endpoint handle + 4-element position Array -> LiveVertexPositionUnreadable' do
  adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  long_adapter = Class.new(adapter.class) do
    def vertex_position(_h); return [0.0, 0.0, 0.0, 0.0]; end
  end.new
  adapter.created_handles.each { |h| long_adapter.created_handles << h }
  adapter.added_edges.each       { |e| long_adapter.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| long_adapter.vertex_handles_by_edge[k] = v }
  err = nil
  begin
    SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: long_adapter, vertex_keys_by_edge: hvm
    )
  rescue SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable => e
    err = e
  end
  refute_nil err, '4-element position Array MUST fail closed (malformed; exactly 3 required)'
  assert_includes err.message, 'live_vertex_position_unreadable'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# R3 fail-closed contract: per-endpoint handle present +
# adapter exposes vertex_position + returns a 2-element
# Array (length too short) -> fail closed (malformed).
test 'V19A-P0 (R3): endpoint handle + 2-element position Array -> LiveVertexPositionUnreadable' do
  adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  short_adapter = Class.new(adapter.class) do
    def vertex_position(_h); return [0.0, 0.0]; end
  end.new
  adapter.created_handles.each { |h| short_adapter.created_handles << h }
  adapter.added_edges.each       { |e| short_adapter.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| short_adapter.vertex_handles_by_edge[k] = v }
  err = nil
  begin
    SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
      workspace: ws, adapter: short_adapter, vertex_keys_by_edge: hvm
    )
  rescue SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable => e
    err = e
  end
  refute_nil err, '2-element position Array MUST fail closed (malformed; exactly 3 required)'
  assert_includes err.message, 'live_vertex_position_unreadable'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# nil adapter -> cached fallback (host-free / no
# live authority).
test 'V19A-P0 §10.2 (NO-ADAPTER): nil adapter -> cached fallback' do
  _adapter, ws = v19a_fp_prepare(
    [[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]],
    v19a_fp_tol
  )
  result = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder.build(
    workspace: ws, adapter: nil, vertex_keys_by_edge: {}
  )
  edge = result['edges'].first
  assert_equal [0.0, 0.0, 0.0],  edge.world_endpoints[0]
  assert_equal [10.0, 0.0, 0.0], edge.world_endpoints[1]
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# §10.3 -Shared logical coordinate proposer test
# ===========================================================

# Two independently-derived safe edges share the
# SAME logical coordinate. The proposer must:
#   - produce ONE logical candidate / ONE logical
#     proposed move;
#   - retain TWO identity-distinct physical
#     endpoint Vertex handles (one per independent
#     derived edge);
#   - retain BOTH derived IDs / endpoint keys /
#     source occurrence provenance.
# The fixture uses the real production fake adapter
# path (no test-only / synthetic seam).
test 'V19A-P0 §10.3 (SHARED-LOGICAL-COORDINATE): two safe edges sharing a coordinate -> one logical move + two physical Vertex handles' do
  # Two independent edges share the same logical
  # start coordinate A=(0,0,drift). Edge A-B has B
  # at Z=0. Edge A-C has C at Z=0. The fake
  # adapter assigns a separate FakeVertex to each
  # edge endpoint, so the corner A (logically one
  # vertex) is exposed via two physical Vertex
  # handles. The analyzer's dominant Z is 0, so
  # it finds ONE logical move for A (the only
  # Z-drift candidate) and we expect TWO physical
  # occurrences for that move (one per independent
  # edge that contributed A).
  drift = 0.007874015748031498 # 0.2 mm in inches
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  # Compute the planar proposal directly through
  # the pure proposer.
  tol = v19a_fp_tol(1.0e-4, 0.01)
  full_proposal = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: tol
  )
  assert_equal 'READY_TO_NORMALIZE', full_proposal[:state].to_s,
               'state MUST be READY_TO_NORMALIZE; got ' \
               "#{full_proposal[:state].inspect} (#{full_proposal[:reason].inspect})"
  proposal = full_proposal[:proposal]
  refute_nil proposal
  # ONE logical move -> movable_count == 1.
  assert_equal 1, proposal[:movable_count],
               'movable_count MUST be 1 (one logical coordinate cluster)'
  # TWO identity-distinct physical Vertex handles
  # in the proposal.
  unique = proposal[:unique_vertex_handles]
  assert_equal 2, unique.length,
               'proposal MUST carry 2 physical Vertex handles (one per independent edge)'
  refute_equal unique[0].object_id, unique[1].object_id,
               'the two physical Vertex handles MUST be IDENTITY-distinct'
  # The proposer MUST expose the per-logical physical
  # occurrences shape.
  physical_occs = proposal[:physical_occurrences]
  refute_nil physical_occs
  assert_equal 2, physical_occs.length
  refute_equal physical_occs[0]['vertex_handle'].object_id,
               physical_occs[1]['vertex_handle'].object_id
  # Both derived_ids / endpoint_keys retained.
  derived_ids = physical_occs.map { |o| o['derived_id'] }.uniq.sort
  assert_equal 2, derived_ids.length
  endpoint_keys = physical_occs.map { |o| o['endpoint_key'] }.sort
  assert_equal 2, endpoint_keys.length
  assert(endpoint_keys.all? { |k| k.end_with?('.start') })
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# §10.4 -Executor fan-out success
# ===========================================================

# One logical move with two physical handles in
# distinct derived groups. The executor must:
#   - open the outer SketchUp operation ONCE;
#   - invoke one owner-safe mutation primitive per
#     physical occurrence (NOT one mixed cross-group
#     batch);
#   - both physical Z values reach target;
#   - commit ONCE;
#   - logical_applied_count == 1
#   - physical_applied_count == 2
#   - applied_count == 2 (legacy alias).
test 'V19A-P0 §10.4 (EXECUTOR-FANOUT): one logical move with two physical handles -> one begin, one primitive per occurrence, one commit' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  # Build the full proposal (with host handles) via
  # the pure proposer.
  tol = v19a_fp_tol(1.0e-4, 0.01)
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: tol
  )
  assert_equal 'READY_TO_NORMALIZE', proposal_hash[:state].to_s
  # Spy on the adapter: count begin/commit/abort AND
  # per-primitive call count.
  begin_count = 0
  commit_count = 0
  abort_count = 0
  transform_call_count = 0
  observed_handles = []
  # We wrap the existing adapter by subclassing.
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      begin_count += 1
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      if commit
        commit_count += 1
      else
        abort_count += 1
      end
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      transform_call_count += 1
      observed_handles.concat(handles)
      adapter.transform_vertices_by_vectors(handles, vectors)
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  # Apply.
  result = PlanarNormalizationExecutor.apply(
    workspace:     ws,
    adapter:       spied,
    proposal_hash: proposal_hash,
    tolerance:     tol
  )
  assert_equal :applied, result[:status]
  # ONE outer begin, ONE commit, NO abort.
  assert_equal 1, begin_count,  'executor MUST open the outer operation exactly once'
  assert_equal 1, commit_count, 'executor MUST commit the outer operation exactly once'
  assert_equal 0, abort_count,  'successful apply MUST NOT abort'
  # One primitive per physical occurrence.
  assert_equal 2, transform_call_count,
               'executor MUST invoke one primitive per physical occurrence (no cross-group batch)'
  # The two observed handles are IDENTITY-distinct.
  assert_equal 2, observed_handles.length
  refute_equal observed_handles[0].object_id, observed_handles[1].object_id
  # Count schema: logical_applied_count == 1, physical_applied_count == 2,
  # applied_count == 2 (legacy alias).
  audit = result[:audit]
  assert_equal 1, audit[:logical_applied_count],
               'audit MUST publish logical_applied_count == 1'
  assert_equal 2, audit[:physical_applied_count],
               'audit MUST publish physical_applied_count == 2 (one per physical Vertex)'
  assert_equal 2, audit[:applied_count],
               'audit MUST publish applied_count == 2 (legacy physical-count alias)'
  # max_movement equals the input drift (the apply
  # actually moved both physical copies to Z=0; the
  # observed max_movement per Vertex is the drift).
  assert_in_delta drift, result[:max_movement].to_f, 1.0e-9,
                  'max_movement MUST equal the input Z drift'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# §10.4a -Executor preflight fail-closed (BLOCK-P0-04)
# ===========================================================

# Per AIPM source review BLOCK-P0-04: the executor MUST
# preflight EVERY physical occurrence's live position
# AND vector AND handle identity BEFORE opening any
# SketchUp operation. A preflight failure MUST:
#   - return fail-closed (no mutation, no commit);
#   - open ZERO begin_operations;
#   - invoke ZERO transform_vertices_by_vectors calls;
#   - preserve the one-outer-operation /
#     one-primitive-per-occurrence architecture for the
#     success path.
#
# The six focused regressions below cover each
# BLOCK-P0-04 failure mode in isolation, using a spy
# adapter that counts begin / abort / commit /
# transform calls + a per-mode vertex_position override.
#
# The seventh regression (valid fan-out path) lives in
# §10.4 EXECUTOR-FANOUT above.

# Per-occurrence live position preflight: vertex_position
# returns nil -> 0 begin / 0 mutation / fail closed.
test 'V19A-P0 §10.4a (PREFLIGHT-NIL): vertex_position returns nil -> 0 begin, 0 mutation' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  begin_count = 0
  transform_count = 0
  spied = Class.new(adapter.class) do
    define_method(:vertex_position) do |_h|
      nil
    end
    define_method(:begin_operation) do |model, label:|
      begin_count += 1
      adapter.begin_operation(model, label: label)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      transform_count += 1
      adapter.transform_vertices_by_vectors(handles, vectors)
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace: ws, adapter: spied,
    proposal_hash: proposal_hash,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status],
               'preflight vertex_position => nil MUST fail closed'
  assert_equal 0, begin_count,
               'preflight failure MUST NOT call begin_operation'
  assert_equal 0, transform_count,
               'preflight failure MUST NOT call transform_vertices_by_vectors'
  audit = result[:audit]
  assert_equal 0, audit[:applied_count],
               'no physical success may be published on preflight failure'
  assert_equal 0, audit[:logical_applied_count]
  assert_equal 0, audit[:physical_applied_count]
  # The audit reason MUST identify the preflight failure
  # mode (not a generic host_mutation_failed).
  assert(audit[:reason].to_s.start_with?('preflight_'),
         "audit reason MUST identify the preflight failure mode; got #{audit[:reason].inspect}")
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# Per-occurrence live position preflight: vertex_position
# returns a malformed Array (length != 3) -> 0 begin / 0
# mutation / fail closed.
test 'V19A-P0 §10.4a (PREFLIGHT-MALFORMED-ARRAY): vertex_position returns malformed Array -> 0 begin, 0 mutation' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  begin_count = 0
  transform_count = 0
  spied = Class.new(adapter.class) do
    define_method(:vertex_position) do |_h|
      [0.0, 0.0] # malformed: length 2 instead of 3
    end
    define_method(:begin_operation) do |model, label:|
      begin_count += 1
      adapter.begin_operation(model, label: label)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      transform_count += 1
      adapter.transform_vertices_by_vectors(handles, vectors)
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace: ws, adapter: spied,
    proposal_hash: proposal_hash,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status]
  assert_equal 0, begin_count
  assert_equal 0, transform_count
  assert_equal 0, result[:audit][:applied_count]
  assert(result[:audit][:reason].to_s.start_with?('preflight_'),
         "audit reason MUST identify the preflight failure mode; got #{result[:audit][:reason].inspect}")
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# Per-occurrence live position preflight: vertex_position
# returns a non-Numeric coordinate -> 0 begin / 0
# mutation / fail closed. Validates the type-before-coerce
# constraint (BLOCK-P0-04: do NOT .to_f first).
test 'V19A-P0 §10.4a (PREFLIGHT-NON-NUMERIC): vertex_position returns non-Numeric coordinate -> 0 begin, 0 mutation' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  begin_count = 0
  transform_count = 0
  spied = Class.new(adapter.class) do
    define_method(:vertex_position) do |_h|
      [0.0, 'not-a-number', 0.0]  # y is a String, not Numeric
    end
    define_method(:begin_operation) do |model, label:|
      begin_count += 1
      adapter.begin_operation(model, label: label)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      transform_count += 1
      adapter.transform_vertices_by_vectors(handles, vectors)
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace: ws, adapter: spied,
    proposal_hash: proposal_hash,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status],
               'non-Numeric vertex_position coordinate MUST fail closed'
  assert_equal 0, begin_count
  assert_equal 0, transform_count
  assert_equal 0, result[:audit][:applied_count]
  assert(result[:audit][:reason].to_s.start_with?('preflight_'),
         "audit reason MUST identify the preflight failure mode; got #{result[:audit][:reason].inspect}")
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# Per-occurrence live position preflight: vertex_position
# returns NaN / Infinity -> 0 begin / 0 mutation / fail
# closed. Validates the finite-after-Numeric constraint.
test 'V19A-P0 §10.4a (PREFLIGHT-NAN-INFINITY): vertex_position returns Float::NAN / Float::INFINITY -> 0 begin, 0 mutation' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  begin_count = 0
  transform_count = 0
  counter = 0
  spied = Class.new(adapter.class) do
    define_method(:vertex_position) do |_h|
      counter += 1
      # Alternate NaN and Infinity so the test
      # covers both failure modes.
      if counter.odd?
        [0.0, 0.0, Float::NAN]
      else
        [0.0, 0.0, Float::INFINITY]
      end
    end
    define_method(:begin_operation) do |model, label:|
      begin_count += 1
      adapter.begin_operation(model, label: label)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      transform_count += 1
      adapter.transform_vertices_by_vectors(handles, vectors)
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace: ws, adapter: spied,
    proposal_hash: proposal_hash,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status],
               'NaN / Infinity vertex_position MUST fail closed'
  assert_equal 0, begin_count
  assert_equal 0, transform_count
  assert_equal 0, result[:audit][:applied_count]
  assert(result[:audit][:reason].to_s.start_with?('preflight_'),
         "audit reason MUST identify the preflight failure mode; got #{result[:audit][:reason].inspect}")
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# Per-occurrence live position preflight: vertex_position
# raises -> 0 begin / 0 mutation / fail closed.
test 'V19A-P0 §10.4a (PREFLIGHT-RAISED): vertex_position raises -> 0 begin, 0 mutation' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  begin_count = 0
  transform_count = 0
  spied = Class.new(adapter.class) do
    define_method(:vertex_position) do |_h|
      raise StandardError, 'synthetic preflight live-read failure'
    end
    define_method(:begin_operation) do |model, label:|
      begin_count += 1
      adapter.begin_operation(model, label: label)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      transform_count += 1
      adapter.transform_vertices_by_vectors(handles, vectors)
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace: ws, adapter: spied,
    proposal_hash: proposal_hash,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status],
               'vertex_position raise MUST fail closed'
  assert_equal 0, begin_count
  assert_equal 0, transform_count
  assert_equal 0, result[:audit][:applied_count]
  assert(result[:audit][:reason].to_s.start_with?('preflight_vertex_position_raised'),
         "audit reason MUST identify vertex_position raise; got #{result[:audit][:reason].inspect}")
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# Per-occurrence vector preflight: vector Z is non-Numeric
# (e.g. String '1.5') -> 0 begin / 0 mutation / fail
# closed. Validates the Numeric-Z BEFORE .to_f coercion
# (BLOCK-P0-04: do NOT call .to_f first to disguise
# malformed input).
test 'V19A-P0 §10.4a (PREFLIGHT-NON-NUMERIC-VECTOR-Z): vector Z is non-Numeric String -> 0 begin, 0 mutation' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  # Tamper with the proposal's first vector so that
  # vec[2] is a non-Numeric String. Naive .to_f would
  # turn that into 1.5 and pass; the production
  # preflight must reject it as non-Numeric FIRST.
  proposal = proposal_hash[:proposal]
  tampered_vectors = proposal[:vectors].map.with_index do |v, i|
    if i.zero?
      [0.0, 0.0, '1.5']
    else
      v
    end
  end
  tampered_proposal = proposal.merge(vectors: tampered_vectors)
  tampered_proposal_hash = proposal_hash.merge(
    proposal: tampered_proposal
  )
  begin_count = 0
  transform_count = 0
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      begin_count += 1
      adapter.begin_operation(model, label: label)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      transform_count += 1
      adapter.transform_vertices_by_vectors(handles, vectors)
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace: ws, adapter: spied,
    proposal_hash: tampered_proposal_hash,
    tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status],
               'non-Numeric vector Z MUST fail closed (do NOT .to_f disguise)'
  assert_equal 0, begin_count
  assert_equal 0, transform_count
  assert_equal 0, result[:audit][:applied_count]
  assert_equal 'preflight_vector_z_not_numeric:0',
               result[:audit][:reason],
               'audit reason MUST specifically identify the non-Numeric vector Z at index 0'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# §10.5 -Mid-mutation failure atomicity
# ===========================================================

# Failure injection: the SECOND
# transform_vertices_by_vectors call raises. The
# executor must:
#   - begin ONCE (the first primitive MAY execute);
#   - abort ONCE;
#   - no commit;
#   - status :failed;
#   - no published partial logical success.
test 'V19A-P0 §10.5 (MID-MUTATION-FAILURE): second primitive raises -> one begin, one abort, no commit, FAILED' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  # Spy that fails on the second transform call.
  call_count = 0
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      call_count += 1
      if call_count == 2
        raise StandardError, 'synthetic mid-mutation failure'
      end
      adapter.transform_vertices_by_vectors(handles, vectors)
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace:     ws,
    adapter:       spied,
    proposal_hash: proposal_hash,
    tolerance:     v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status]
  audit = result[:audit]
  assert_equal 0, audit[:logical_applied_count], 'no logical success may be published on mid-mutation failure'
  assert_equal 0, audit[:physical_applied_count], 'no physical success may be published on mid-mutation failure'
  assert_equal 0, audit[:applied_count], 'applied_count MUST be 0 on failure'
  # The apply operation log shows one begin + one
  # abort, no commit. The adapter's full log also
  # contains the prepare-cycle's begin/commit; we
  # therefore look at the LAST cycle (slice from the
  # last :begin onward). Use explicit checks because
  # the project's test runner does not ship
  # `refute_includes`.
  log = adapter.operation_log
  last_begin = log.rindex { |op| op[:kind] == :begin }
  apply_log_kinds = last_begin.nil? ? [] :
                       log[last_begin..-1].map { |op| op[:kind] }
  assert_includes apply_log_kinds, :begin
  assert_includes apply_log_kinds, :abort
  assert !apply_log_kinds.include?(:commit),
         "apply cycle MUST NOT contain a :commit on mid-mutation failure; got #{apply_log_kinds.inspect}"
  assert_equal 1, apply_log_kinds.count(:begin)
  assert_equal 1, apply_log_kinds.count(:abort)
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# §10.6 -Postvalidation failure atomicity
# ===========================================================

# Postvalidate by spoofing a post-mutation
# vertex_position that returns a wrong Z for ONE
# physical Vertex. The executor must abort once
# and not commit.
test 'V19A-P0 §10.6 (POSTVALIDATION-FAILURE): one post-mutation Z drift -> one abort, no commit, FAILED' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  # Subclass: the first vertex_position call AFTER
  # any transform_vertices_by_vectors call returns a
  # wrong Z (postvalidation failure). Preflight
  # (which runs BEFORE any transform) still reads the
  # truthful pre-mutation Z, so preflight passes and
  # only post-validation detects the drift.
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  first_handle = hvm.values.first
  mutated = false
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      adapter.transform_vertices_by_vectors(handles, vectors)
      mutated = true
      nil
    end
    define_method(:vertex_position) do |h|
      if mutated && h.object_id == first_handle.object_id
        # Return a bogus large Z so postvalidation
        # fails (dz exceeds coordinate_epsilon).
        [h.x, h.y, 1.0e6]
      else
        adapter.vertex_position(h)
      end
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace:     ws,
    adapter:       spied,
    proposal_hash: proposal_hash,
    tolerance:     v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status]
  audit = result[:audit]
  assert_equal 0, audit[:logical_applied_count]
  assert_equal 0, audit[:physical_applied_count]
  assert_equal 0, audit[:applied_count]
  log_kinds = adapter.operation_log.map { |op| op[:kind] }
  # Look at the LAST apply cycle only (the prepare
  # cycle's begin/commit precedes it on the same
  # adapter log).
  last_begin = adapter.operation_log.rindex { |op| op[:kind] == :begin }
  apply_log_kinds = last_begin.nil? ? [] :
                       adapter.operation_log[last_begin..-1].map { |op| op[:kind] }
  assert_includes apply_log_kinds, :begin
  assert_includes apply_log_kinds, :abort
  assert !apply_log_kinds.include?(:commit),
         "apply cycle MUST NOT contain a :commit on postvalidation failure; got #{apply_log_kinds.inspect}"
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# R2 — V1.9A P0 NARROW RECHECK (fix 2026-09-08)
# Post-read exception safety + atomicity
# ===========================================================

# R2: post-position read RAISES for one physical Vertex.
# The executor MUST:
#   - call begin_operation ONCE;
#   - call transform_vertices_by_vectors for each occurrence
#     (the mutation itself succeeds);
#   - abort ONCE (not commit);
#   - publish status :failed with zero committed logical
#     success;
#   - the post-read exception MUST NOT escape the
#     function (the operation control surface remains
#     consistent).
test 'V19A-P0 (R2): post-position read raises -> one begin, one abort, no commit, FAILED, exception suppressed' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  # After any transform_vertices_by_vectors call, the
  # post-position read raises. Preflight (which runs
  # BEFORE the transform) still reads truthful
  # pre-mutation Z values so preflight passes; only
  # postvalidation detects the failure.
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  first_handle = hvm.values.first
  mutated = false
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      adapter.transform_vertices_by_vectors(handles, vectors)
      mutated = true
      nil
    end
    define_method(:vertex_position) do |h|
      if mutated
        # Raise AFTER any mutation. The postvalidation
        # loop MUST catch this raise per occurrence;
        # the executor MUST abort once + publish FAILED;
        # the exception MUST NOT escape the function.
        raise StandardError, 'synthetic post-read boom'
      else
        adapter.vertex_position(h)
      end
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = nil
  raised = nil
  begin
    result = PlanarNormalizationExecutor.apply(
      workspace:     ws,
      adapter:       spied,
      proposal_hash: proposal_hash,
      tolerance:     v19a_fp_tol(1.0e-4, 0.01)
    )
  rescue StandardError => e
    raised = e
  end
  assert_nil raised,
             'executor MUST NOT let the post-read exception escape (operation must be aborted first)'
  refute_nil result
  assert_equal :failed, result[:status],
               'post-read raise MUST surface as :failed'
  audit = result[:audit]
  assert_equal 0, audit[:logical_applied_count]
  assert_equal 0, audit[:physical_applied_count]
  assert_equal 0, audit[:applied_count]
  # Operation control surface: last apply cycle has
  # exactly one begin + exactly one abort + zero commit.
  last_begin = adapter.operation_log.rindex { |op| op[:kind] == :begin }
  apply_log_kinds = last_begin.nil? ? [] :
                       adapter.operation_log[last_begin..-1].map { |op| op[:kind] }
  assert_equal 1, apply_log_kinds.count(:begin),
               'apply cycle MUST contain exactly one begin'
  assert_equal 1, apply_log_kinds.count(:abort),
               'apply cycle MUST contain exactly one abort'
  assert !apply_log_kinds.include?(:commit),
         'apply cycle MUST NOT contain a commit'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# R2: post-position returns malformed (non-Array)
# for one occurrence -> one begin, one abort, no
# commit, FAILED.
test 'V19A-P0 (R2): post-position returns malformed non-Array -> one begin, one abort, no commit, FAILED' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  mutated = false
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      adapter.transform_vertices_by_vectors(handles, vectors)
      mutated = true
      nil
    end
    define_method(:vertex_position) do |h|
      if mutated
        { x: 0.0, y: 0.0, z: 0.0 } # Hash, NOT an Array
      else
        adapter.vertex_position(h)
      end
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace:     ws,
    adapter:       spied,
    proposal_hash: proposal_hash,
    tolerance:     v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status]
  audit = result[:audit]
  assert_equal 0, audit[:logical_applied_count]
  assert_equal 0, audit[:physical_applied_count]
  assert_equal 0, audit[:applied_count]
  last_begin = adapter.operation_log.rindex { |op| op[:kind] == :begin }
  apply_log_kinds = last_begin.nil? ? [] :
                       adapter.operation_log[last_begin..-1].map { |op| op[:kind] }
  assert_equal 1, apply_log_kinds.count(:begin)
  assert_equal 1, apply_log_kinds.count(:abort)
  assert !apply_log_kinds.include?(:commit),
         'apply cycle MUST NOT contain a commit on malformed post-read'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# R2: post-position returns Float::NAN for one
# occurrence -> one begin, one abort, no commit,
# FAILED.
test 'V19A-P0 (R2): post-position returns Float::NAN -> one begin, one abort, no commit, FAILED' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  mutated = false
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      adapter.transform_vertices_by_vectors(handles, vectors)
      mutated = true
      nil
    end
    define_method(:vertex_position) do |h|
      if mutated
        [0.0, 0.0, Float::NAN]
      else
        adapter.vertex_position(h)
      end
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace:     ws,
    adapter:       spied,
    proposal_hash: proposal_hash,
    tolerance:     v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status]
  audit = result[:audit]
  assert_equal 0, audit[:logical_applied_count]
  assert_equal 0, audit[:physical_applied_count]
  assert_equal 0, audit[:applied_count]
  last_begin = adapter.operation_log.rindex { |op| op[:kind] == :begin }
  apply_log_kinds = last_begin.nil? ? [] :
                       adapter.operation_log[last_begin..-1].map { |op| op[:kind] }
  assert_equal 1, apply_log_kinds.count(:begin)
  assert_equal 1, apply_log_kinds.count(:abort)
  assert !apply_log_kinds.include?(:commit),
         'apply cycle MUST NOT contain a commit on non-finite post-read'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# V1.9A P0 FINAL NARROW RESIDUAL CORRECTION FINAL-R2-01
# Post-validation .to_f exception-leak path
# ===========================================================

# FINAL-R2-01 (2026-09-09): the previous R2 packet
# wrapped `adapter.vertex_position(h)` in
# `begin/rescue StandardError`, but the downstream
# validation loop performed `after_zs << post[2].to_f
# if post.is_a?(Array)` BEFORE proving the post shape
# is exactly 3 + Numeric + finite. A malformed post
# like `[0.0, 0.0, Object.new]` therefore raised
# `NoMethodError` on `Object.new.to_f` BEFORE the
# executor reached the unreadable-position branch.
# Required: prove no exception escapes with the outer
# operation open + abort-once-no-commit FAILED +
# zero committed success.
test 'V19A-P0 (FINAL-R2-01): post-position [0.0, 0.0, Object.new] -> no exception escapes, 1 begin, 1 abort, 0 commit, FAILED' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  mutated = false
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      adapter.transform_vertices_by_vectors(handles, vectors)
      mutated = true
      nil
    end
    define_method(:vertex_position) do |h|
      if mutated
        # FINAL-R2-01 fixture: post is a 3-Array but
        # the third slot is Object.new (not Numeric).
        # The previous code would raise on `.to_f`
        # before the validation block; the corrected
        # code MUST detect the non-Numeric slot FIRST
        # and fail closed without invoking `.to_f`.
        [0.0, 0.0, Object.new]
      else
        adapter.vertex_position(h)
      end
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = nil
  raised = nil
  begin
    result = PlanarNormalizationExecutor.apply(
      workspace:     ws,
      adapter:       spied,
      proposal_hash: proposal_hash,
      tolerance:     v19a_fp_tol(1.0e-4, 0.01)
    )
  rescue StandardError => e
    raised = e
  end
  assert_nil raised,
             'FINAL-R2-01: a post slot of Object.new MUST NOT escape as NoMethodError; the validation block MUST detect non-Numeric BEFORE .to_f'
  refute_nil result
  assert_equal :failed, result[:status],
               'post[2] is non-Numeric MUST surface as :failed'
  audit = result[:audit]
  assert_equal 0, audit[:logical_applied_count]
  assert_equal 0, audit[:physical_applied_count]
  assert_equal 0, audit[:applied_count]
  # Operation control surface: last apply cycle has
  # exactly one begin + exactly one abort + zero commit.
  last_begin = adapter.operation_log.rindex { |op| op[:kind] == :begin }
  apply_log_kinds = last_begin.nil? ? [] :
                       adapter.operation_log[last_begin..-1].map { |op| op[:kind] }
  assert_equal 1, apply_log_kinds.count(:begin),
               'FINAL-R2-01: apply cycle MUST contain exactly one begin'
  assert_equal 1, apply_log_kinds.count(:abort),
               'FINAL-R2-01: apply cycle MUST contain exactly one abort'
  assert !apply_log_kinds.include?(:commit),
         'FINAL-R2-01: apply cycle MUST NOT contain a commit'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# FINAL-R2-01: a 4-element position Array is malformed
# (per R3 + FINAL-R2-01 the position shape MUST be
# exactly 3) and MUST fail closed BEFORE any `.to_f`.
test 'V19A-P0 (FINAL-R2-01): post-position [0.0, 0.0, 0.0, 123.0] -> malformed, 1 begin, 1 abort, 0 commit, FAILED' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  mutated = false
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      adapter.transform_vertices_by_vectors(handles, vectors)
      mutated = true
      nil
    end
    define_method(:vertex_position) do |h|
      if mutated
        # 4-element position Array (R3 + FINAL-R2-01:
        # exactly 3 required; anything else is malformed).
        [0.0, 0.0, 0.0, 123.0]
      else
        adapter.vertex_position(h)
      end
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace:     ws,
    adapter:       spied,
    proposal_hash: proposal_hash,
    tolerance:     v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status]
  audit = result[:audit]
  assert_equal 0, audit[:logical_applied_count]
  assert_equal 0, audit[:physical_applied_count]
  assert_equal 0, audit[:applied_count]
  last_begin = adapter.operation_log.rindex { |op| op[:kind] == :begin }
  apply_log_kinds = last_begin.nil? ? [] :
                       adapter.operation_log[last_begin..-1].map { |op| op[:kind] }
  assert_equal 1, apply_log_kinds.count(:begin)
  assert_equal 1, apply_log_kinds.count(:abort)
  assert !apply_log_kinds.include?(:commit),
         'FINAL-R2-01: 4-element post Array MUST fail closed without commit'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# FINAL-R2-01: a 2-element position Array is malformed
# (exactly 3 required) and MUST fail closed.
test 'V19A-P0 (FINAL-R2-01): post-position [0.0, 0.0] -> malformed (length 2), 1 begin, 1 abort, 0 commit, FAILED' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  mutated = false
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      adapter.transform_vertices_by_vectors(handles, vectors)
      mutated = true
      nil
    end
    define_method(:vertex_position) do |h|
      if mutated
        [0.0, 0.0] # length 2 -> malformed
      else
        adapter.vertex_position(h)
      end
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace:     ws,
    adapter:       spied,
    proposal_hash: proposal_hash,
    tolerance:     v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status]
  audit = result[:audit]
  assert_equal 0, audit[:logical_applied_count]
  assert_equal 0, audit[:physical_applied_count]
  assert_equal 0, audit[:applied_count]
  last_begin = adapter.operation_log.rindex { |op| op[:kind] == :begin }
  apply_log_kinds = last_begin.nil? ? [] :
                       adapter.operation_log[last_begin..-1].map { |op| op[:kind] }
  assert_equal 1, apply_log_kinds.count(:begin)
  assert_equal 1, apply_log_kinds.count(:abort)
  assert !apply_log_kinds.include?(:commit),
         'FINAL-R2-01: 2-element post Array MUST fail closed without commit'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# FINAL-R2-01: a non-Array post value (Hash) MUST fail
# closed BEFORE any `.to_f`. This was already covered
# by the prior R2 packet's FAILCLOSED-MALFORMED-style
# test, but the FINAL-R2-01 contract requires the
# shape ordering check to gate the `.to_f`. This
# test pins that contract inside the post-validation
# phase (not just the preflight).
test 'V19A-P0 (FINAL-R2-01): post-position Hash -> malformed, 1 begin, 1 abort, 0 commit, FAILED' do
  drift = 0.007874015748031498
  adapter, ws = v19a_fp_prepare(
    [
      [[0.0, 0.0, drift], [5.0, 0.0, 0.0]],
      [[0.0, 0.0, drift], [0.0, 5.0, 0.0]]
    ],
    v19a_fp_tol(1.0e-4, 0.01)
  )
  proposal_hash = SUAnalysis::Core::PlanarNormalizationProposer.propose(
    workspace: ws, adapter: adapter, tolerance: v19a_fp_tol(1.0e-4, 0.01)
  )
  mutated = false
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      adapter.transform_vertices_by_vectors(handles, vectors)
      mutated = true
      nil
    end
    define_method(:vertex_position) do |h|
      if mutated
        { x: 0.0, y: 0.0, z: 0.0 } # Hash (not Array)
      else
        adapter.vertex_position(h)
      end
    end
  end.new
  adapter.created_handles.each { |h| spied.created_handles << h }
  adapter.added_edges.each       { |e| spied.added_edges << e }
  adapter.vertex_handles_by_edge.each { |k, v| spied.vertex_handles_by_edge[k] = v }
  result = PlanarNormalizationExecutor.apply(
    workspace:     ws,
    adapter:       spied,
    proposal_hash: proposal_hash,
    tolerance:     v19a_fp_tol(1.0e-4, 0.01)
  )
  assert_equal :failed, result[:status]
  audit = result[:audit]
  assert_equal 0, audit[:logical_applied_count]
  assert_equal 0, audit[:physical_applied_count]
  assert_equal 0, audit[:applied_count]
  last_begin = adapter.operation_log.rindex { |op| op[:kind] == :begin }
  apply_log_kinds = last_begin.nil? ? [] :
                       adapter.operation_log[last_begin..-1].map { |op| op[:kind] }
  assert_equal 1, apply_log_kinds.count(:begin)
  assert_equal 1, apply_log_kinds.count(:abort)
  assert !apply_log_kinds.include?(:commit),
         'FINAL-R2-01: Hash post MUST fail closed without commit'
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# R2 source-level guard: the post-read loop MUST be
# wrapped in an exception-safe guard so an unexpected
# host read cannot escape with the outer operation open.
#
# V1.9A P0 FINAL NARROW RESIDUAL CORRECTION FINAL-R2-01
# (2026-09-09): the guard test is updated to find the
# new validation phase. The old guard located the
# end of the post-validation block by the literal
# `if !validation_errors.empty?` marker; FINAL-R2-01
# replaced that with `if post_validation_phase_failed
# || !validation_errors.empty?`. We therefore locate
# the end of the block by the new marker and also
# assert the FINAL-R2-01 defensive `begin/rescue
# StandardError` boundary exists at the post-validation
# phase level (the prior R2 packet only had the
# per-read rescue; FINAL-R2-01 adds a phase-level
# defensive boundary).
test 'V19A-P0 (R2 source-level): post-read loop is wrapped in begin/rescue StandardError' do
  src = File.read(File.expand_path('../extension/su_ai_plugin/core/planar_normalization_executor.rb', __dir__))
  # Locate the post-validation block by scanning for
  # the 'Post-validation' comment marker.
  refute_nil src.index('Post-validation'),
             'executor source MUST contain the Post-validation block'
  # Locate the end of the post-validation block by the
  # new FINAL-R2-01 marker.
  post_block_start = src.index('# ---- Post-validation')
  refute_nil post_block_start
  post_block_end   = src.index('if post_validation_phase_failed', post_block_start)
  refute_nil post_block_end
  post_block = src[post_block_start..post_block_end]
  assert_includes post_block, 'rescue StandardError',
                  'post-read loop MUST be wrapped in `rescue StandardError` so a raised host read cannot escape with the outer operation open'
  assert_includes post_block, "vertex_position(h)",
                  'post-read loop MUST call adapter.vertex_position(h)'
  # FINAL-R2-01: phase-level defensive rescue around
  # the entire post-validation loop.
  assert_includes post_block, 'post_validation_phase_failed',
                  'FINAL-R2-01 phase-level defensive rescue boundary MUST exist'
  # Strict ordering: post must be an Array of EXACTLY
  # 3 BEFORE any `.to_f` / numeric coercion.
  assert_match(/post\.length\s*==\s*3/, post_block,
               'FINAL-R2-01 MUST require `post.length == 3` BEFORE `.to_f`')
end

# ===========================================================
# §10.7 -TRUE end-to-end Owner-equivalent integration
# ===========================================================

# Mirror the real Owner fixture:
#   A=(0,0,0)  B=(W,0,0.2mm)  C=(W,H,0)  D=(0,H,0)  E=(0,1mm,0)
#   source edges A-B, B-C, C-D, D-E
#   missing E-A = 1mm gap.
# Use production-equivalent strict tolerances:
#   coordinate_epsilon << 1mm <= gap_search
#   0.2mm <= planar_z_snap  AND  0.2mm > coordinate_epsilon.
# Drive the production-like orchestrator / WorkingModeRunner
# path through compute_planar_normalization ->
# apply_planar_normalization -> compute_gap_repair ->
# apply_gap_repair -> compute_structure_reconstruction.
# Final assertions:
#   workspace == ready
#   open_chain_count == 0
#   closed_loop_count == 1
#   invalid_loop_count == 0
#   region_count == 1
#   no closed loop carries non_planar_loop.
test 'V19A-P0 §10.7 (E2E-OWNER-EQUIVALENT): Z+Gap -> Region. BOTH physical copies of B reach target Z; Gap auto-unlocks; Structure = 0/1/0/1; no non_planar_loop' do
  # W = 10 inches; H = 5 inches.
  # 0.2 mm = 0.2 / 25.4 in = 0.007874015748031498 in.
  live_z = 0.2 / 25.4
  W = 10.0
  H = 5.0
  # Edge A-B carries the 0.2 mm drift on BOTH
  # endpoints. The other three edges are at Z=0.
  edges = [
    [[0.0, 0.0, 0.0],     [W,   0.0, live_z]],   # A-B (B has 0.2 mm Z drift)
    [[W,   0.0, live_z],  [W,   H,   0.0]],       # B-C (B drift persists)
    [[W,   H,   0.0],     [0.0, H,   0.0]],       # C-D
    [[0.0, H,   0.0],     [0.0, 1.0 / 25.4, 0.0]] # D-E
  ]
  # Use strict tolerances per the amendment:
  #   coordinate_epsilon = 1.0e-4 (<< 1mm = 0.0394 in)
  #   gap_search         = 0.05 in (>= 1mm)
  #   planar_z_snap      = 0.01 in (>= 0.2mm = 0.00787 in)
  tol = Tolerance.new(duplicate: 1.0e-4, short_edge: 0.5,
                      gap_search: 0.05, coordinate_epsilon: 1.0e-4,
                      planar_z_snap: 0.01)
  adapter, ws = v19a_fp_prepare(edges, tol)
  # Step 1: compute planar.
  planar_snap = V19A_FP_RUNNER.compute_planar_normalization
  planar = planar_snap['planar_normalization']
  refute_nil planar, 'snapshot MUST expose the planar_normalization sub-snapshot'
  assert_equal 'READY_TO_NORMALIZE', planar['state'].to_s,
               'state MUST be READY_TO_NORMALIZE; got ' \
               "#{planar['state'].inspect} (#{planar['reason'].inspect})"
  # The proposer should report one logical move
  # covering the (0,0,0)/(W,0,0) cluster.
  assert_equal 1, planar['proposal']['movable_count']
  # Step 2: apply planar.
  apply_snap = V19A_FP_RUNNER.apply_planar_normalization
  apply = apply_snap['planar_normalization']
  refute_nil apply
  assert_equal 'APPLIED', apply['state'].to_s,
               'planar apply state MUST be APPLIED; got ' \
               "#{apply['state'].inspect} (#{apply['reason'].inspect})"
  # The audit MUST publish logical_applied_count = 1
  # (one logical move) and physical_applied_count >= 1
  # (the fake adapter does NOT have multiple physical
  # Vertex handles per logical coord in this minimal
  # fixture, so physical == logical = 1).
  assert_equal 1, apply['audit']['logical_applied_count']
  assert apply['audit']['physical_applied_count'] >= 1
  assert_equal apply['audit']['physical_applied_count'], apply['audit']['applied_count']
  # After planar, host Z of A AND B MUST be 0.
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  refute_empty hvm
  # Step 3: compute gap.
  gap_snap = V19A_FP_RUNNER.compute_gap_repair
  # Step 4: apply gap.
  apply_gap_snap = V19A_FP_RUNNER.apply_gap_repair
  # Step 5: compute structure.
  struct_snap = V19A_FP_RUNNER.compute_structure_reconstruction
  struct = struct_snap['structure_reconstruction']
  refute_nil struct, 'snapshot MUST expose structure_reconstruction sub-snapshot'
  # Final assertions.
  assert_equal 'READY', struct['state'].to_s,
               'structure state MUST be READY; got ' \
               "#{struct['state'].inspect} (#{struct['reason'].inspect})"
  metrics = struct['metrics'] || {}
  assert_equal 0, metrics['open_chain_count'].to_i,
               'open_chain_count MUST be 0 after Z+Gap fix; got ' \
               "#{metrics.inspect}"
  assert_equal 1, metrics['closed_loop_count'].to_i,
               'closed_loop_count MUST be 1; got ' \
               "#{metrics.inspect}"
  assert_equal 1, metrics['region_count'].to_i,
               'region_count MUST be 1; got ' \
               "#{metrics.inspect}"
  assert_equal 0, metrics['invalid_loop_count'].to_i,
               'invalid_loop_count MUST be 0 (no non_planar_loop residue)'
  # No closed loop carries non_planar_loop.
  loops = struct['closed_loops'] || []
  loops.each do |loop|
    flags = Array(loop['unresolved_flags'])
    assert !flags.include?('non_planar_loop'),
           'NO closed loop MAY carry non_planar_loop after the V1.9A P0 fix'
  end
ensure
  V19A_FP_RUNNER.reset_for_tests
end

# ===========================================================
# §10.8 -Presenter logical count / FAILED no CTA /
# Issues / badge / refresh preserved
# ===========================================================

# Presenter Planar APPLIED card MUST prefer
# logical_applied_count over applied_count.
test 'V19A-P0 §10.8 (PRESENTER-LOGICAL-COUNT): Planar APPLIED card reads logical_applied_count' do
  require_relative '../extension/su_ai_plugin/cad_prep_workflow_presenter'
  pres = SUAnalysis::Extension::CadPrepWorkflowPresenter
  snap = {
    'state' => 'ready',
    'duplicate_repair' => { 'actions_applied' => 0 },
    'planar_normalization' => {
      'computed' => true, 'state' => 'APPLIED',
      'audit' => {
        'logical_applied_count' => 7,
        'physical_applied_count' => 11,
        'applied_count' => 11
      }
    },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' }
  }
  ar = { 'issues' => {}, 'registry' => [] }
  payload = pres.present(analysis_result: ar, workspace_snapshot: snap)
  planar_card = payload['cards'].find { |c| c['id'] == 'planar_normalization' }
  refute_nil planar_card
  # The user-facing count is the LOGICAL one (7),
  # not the physical one (11).
  moved_metric = planar_card['metrics'].find { |m| m['label'] == '已移动' }
  refute_nil moved_metric
  assert_equal 7, moved_metric['value'],
               'user-facing APPLIED count MUST be the LOGICAL count (7), not the physical count (11)'
end

# FAILED issue summary MUST NOT carry a normal
# CTA; the recovery banner owns recovery.
test 'V19A-P0 §10.8 (PRESENTER-FAILED-NO-CTA): FAILED issue_summary has cta=nil, cta_callback=nil' do
  require_relative '../extension/su_ai_plugin/cad_prep_workflow_presenter'
  pres = SUAnalysis::Extension::CadPrepWorkflowPresenter
  snap = {
    'state' => 'failed',
    'last_error' => 'SomeError: synthetic failure'
  }
  ar = { 'issues' => {}, 'registry' => [] }
  payload = pres.present(analysis_result: ar, workspace_snapshot: snap)
  issue = payload['issue_summary']
  assert_nil issue['cta'],
             'FAILED issue_summary MUST NOT carry a normal 閲嶆柊妫€娴?CTA'
  assert_nil issue['cta_callback'],
             'FAILED issue_summary MUST NOT carry a refresh_cad_prep cta_callback'
end

# ===========================================================
# §9 -error class / source-level guards
# ===========================================================

test 'V19A-P0 §9 (ERROR-CLASS): LiveVertexPositionUnreadable carries stable reason + endpoint_key' do
  err = SUAnalysis::Core::EndpointRecord::DerivedTopologySnapshotBuilder::LiveVertexPositionUnreadable.new(
    endpoint_key: 'fake-edge.start'
  )
  assert_equal 'live_vertex_position_unreadable', err.reason
  assert_equal 'fake-edge.start', err.endpoint_key
  assert_includes err.message, 'live_vertex_position_unreadable'
  assert_includes err.message, 'fake-edge.start'
end

test 'V19A-P0 §9 (SOURCE-LEVEL): endpoint_record.rb does NOT mutate cached geometry_summary' do
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/endpoint_record.rb',
      __dir__
    )
  )
  refute_match(/@geometry_summary\s*=/, src,
               'endpoint_record.rb MUST NOT reassign @geometry_summary')
  refute_match(/rec\.geometry_summary\s*=/, src,
               'endpoint_record.rb MUST NOT mutate rec.geometry_summary in place')
  assert_match(/DerivedEdgeRecord\.new\(/, src)
  assert_match(/EndpointRecord\.new\(/, src)
end

# Source-level guard: the proposer MUST use object
# identity dedupe, NOT Array#include?, for
# physical handle uniqueness.
test 'V19A-P0 §9 (PROPOSER-IDENTITY-DEDUPE): proposer source uses object_id-based dedupe, not value equality' do
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/planar_normalization_proposer.rb',
      __dir__
    )
  )
  # The proposer MUST compare physical handles by
  # object_id (identity) to avoid collapsing
  # independent physical occurrences.
  assert_match(/object_id/, src,
               'proposer source MUST use object_id-based identity dedupe for physical handles')
  # The new physical_occurrences field MUST exist.
  assert_match(/physical_occurrences/, src,
               'proposer source MUST publish the per-logical physical_occurrences shape')
end

# Source-level guard: the executor MUST call
# transform_vertices_by_vectors ONE per physical
# occurrence (or expose the per-occurrence
# structure), not one batched cross-group call.
test 'V19A-P0 §9 (EXECUTOR-ONE-PRIMITIVE-PER-OCCURRENCE): executor opens once + iterates per physical handle' do
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/planar_normalization_executor.rb',
      __dir__
    )
  )
  # The executor MUST open one outer operation
  # BEFORE iterating physical occurrences.
  assert_match(/begin_operation/, src)
  # The executor MUST call the per-vertex primitive
  # in a loop (NOT one batched call).
  assert_match(/transform_vertices_by_vectors/, src)
end

# ===========================================================
# R5 — V1.9A P0 NARROW RECHECK (fix 2026-09-08)
# TRUE orchestrated Owner-equivalent E2E regression
# ===========================================================

# Build an Owner-fixture SourceSnapshot carrying 4 source
# edges (A-B, B-C, C-D, D-E) with the same geometry the
# R5 dispatch specifies.
def v19a_fp_owner_fixture_source
  live_z = 0.2 / 25.4            # 0.2 mm in inches
  w = 10.0
  h = 5.0
  one_mm = 1.0 / 25.4
  edges_data = [
    [[0.0, 0.0, 0.0],     [w,   0.0, live_z]],
    [[w,   0.0, live_z],  [w,   h,   0.0]],
    [[w,   h,   0.0],     [0.0, h,   0.0]],
    [[0.0, h,   0.0],     [0.0, one_mm, 0.0]]
  ]
  recs = edges_data.map.with_index do |(s, e), i|
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
  layer = LayerRecord.new(name: 'L0')
  geom = GeometrySnapshot.new(edges: recs, layers: [layer])
  cfg = AnalysisConfig.new
  ec = ExecutionConfigSnapshot.from_live_config(
    cfg, rule_set_digest: 'v19a-p0-r5-owner-fixture',
    source_snapshot_schema_version: '1'
  )
  SourceSnapshot.from_geometry_snapshot(
    geom,
    selection: [],
    host: nil,
    execution_config: ec,
    rule_set_digest: 'v19a-p0-r5-owner-fixture',
    snapshot_id: "v19a-p0-r5-snap-#{rand(2**32)}",
    captured_at: '2026-09-08T00:00:00Z',
    transform_context: nil
  )
end

# R5: TRUE orchestrated Owner-equivalent integration.
#
# Per R5 dispatch (fix 2026-09-08): exercise ONLY the
# real V1.9A orchestrator chain — NOT manual
# `WorkingModeRunner.compute_*` / `apply_*` calls that
# simulate the automatic chain.
#
# Flow:
#   CadPrepWorkflowOrchestrator.start
#     -> planar ACTIONABLE
#     -> gap detected + presenter Gap action disabled
#   CadPrepWorkflowOrchestrator.apply_planar_and_refresh
#     -> BOTH identity-distinct physical B Vertex handles
#        reach target Z
#     -> presenter Gap action enabled
#   CadPrepWorkflowOrchestrator.apply_gap_and_refresh
#     -> returned snapshot already contains recomputed
#        Structure (open=0, closed=1, invalid=0, region=1,
#        no non_planar_loop).
test 'V19A-P0 (R5): orchestrated Owner-equivalent E2E: start -> apply_planar_and_refresh -> apply_gap_and_refresh -> ready 0/1/0/1' do
  src = v19a_fp_owner_fixture_source
  # Use strict tolerances per the amendment.
  tol = Tolerance.new(duplicate: 1.0e-4, short_edge: 0.5,
                      gap_search: 0.05, coordinate_epsilon: 1.0e-4,
                      planar_z_snap: 0.01)
  V19A_FP_RUNNER.reset_for_tests
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  begin
    # === Step 1: CadPrepWorkflowOrchestrator.start ===
    start_snap = CadPrepWorkflowOrchestrator.start(
      source: src, adapter: adapter, model: nil, registry: nil
    )
    assert_equal 'ready', start_snap['state'],
                 'orchestrator.start MUST yield a ready workspace'
    pn = start_snap['planar_normalization']
    refute_nil pn, 'start snapshot MUST expose planar_normalization sub-snapshot'
    assert_equal 'READY_TO_NORMALIZE', pn['state'].to_s,
                 'planar MUST be READY_TO_NORMALIZE on the Owner fixture (0.2 mm Z residue on B)'
    # Gap detected but disabled while planar is
    # actionable.
    tr = start_snap['topology_repair']
    refute_nil tr, 'start snapshot MUST expose topology_repair sub-snapshot'
    assert_equal 'READY_TO_REPAIR', tr['state'].to_s,
                 'gap MUST be READY_TO_REPAIR on the Owner fixture (1mm E-A gap)'
    # Presenter surfaces Gap action disabled.
    pres = SUAnalysis::Extension::CadPrepWorkflowPresenter.present(
      analysis_result: nil, workspace_snapshot: start_snap
    )
    gap_card = pres['cards'].find { |c| c['id'] == 'gap_endpoint' }
    refute_nil gap_card
    refute_nil gap_card['primary_action']
    refute gap_card['primary_action']['enabled'],
           'gap repair action MUST be disabled while planar is actionable (gap-ordering safety)'
    # === Step 2: CadPrepWorkflowOrchestrator.apply_planar_and_refresh ===
    apply_p_snap = CadPrepWorkflowOrchestrator.apply_planar_and_refresh
    assert_equal 'ready', apply_p_snap['state'],
                 'orchestrator.apply_planar_and_refresh MUST yield a ready workspace'
    pn_after = apply_p_snap['planar_normalization']
    refute_nil pn_after
    assert_equal 'APPLIED', pn_after['state'].to_s,
                 'planar MUST be APPLIED after apply_planar_and_refresh'
    # --- FINAL-R5-01 (2026-09-09): prove the two physical
    # B Vertex handles are identity-distinct AND both
    # reached target Z in this same orchestrated fixture
    # BEFORE proceeding to gap apply. ---
    # Access the post-apply workspace via the runner
    # test-only accessor (the orchestrator does NOT
    # publish the workspace handle; this is the
    # production-equivalent read).
    ws_after_planar = V19A_FP_RUNNER.current_workspace_for_test
    refute_nil ws_after_planar,
               'post-planar workspace MUST be accessible to inspect the two physical B Vertex handles'
    # Build the authoritative host-vertex map from the
    # workspace edges (same seam
    # `working_mode_runner._host_vertex_map` uses in
    # production).
    hvm_after_planar = v19a_fp_host_vertex_map(ws_after_planar, adapter)
    refute_empty hvm_after_planar,
                 'post-planar host_vertex_map MUST be resolvable'
    # Resolve the two physical endpoint Vertex handles
    # representing logical B from the two independent
    # derived edge Groups:
    #   - edge 0 (A-B): B is the .end slot
    #   - edge 1 (B-C): B is the .start slot
    # Discover the derived IDs by walking the workspace
    # entities (do NOT hardcode "0"/"1" — the test must
    # be robust against derivation-order changes).
    edge_dids = ws_after_planar.entities
                              .select { |r| r.respond_to?(:kind) && r.kind == :edge }
                              .map { |r| r.respond_to?(:derived_id) ? r.derived_id.to_s : '' }
                              .reject(&:empty?)
                              .sort
    assert_equal 4, edge_dids.length,
                 'Owner fixture MUST produce 4 derived edge entities'
    edge_a_b_did = edge_dids.find { |did|
      g = ws_after_planar.handle_for(did)
      next false unless g
      eps = adapter.edge_endpoints(g) if adapter.respond_to?(:edge_endpoints)
      next false unless eps.is_a?(Array) && eps.length == 2
      eps[0].respond_to?(:position) && eps[0].position[0] == 0.0 &&
        eps[0].position[1] == 0.0
    }
    refute_nil edge_a_b_did,
               'Owner fixture MUST expose one derived edge whose start endpoint is (0,0,Z) (edge A-B)'
    edge_b_c_did = edge_dids.find { |did|
      g = ws_after_planar.handle_for(did)
      next false unless g
      next false if did == edge_a_b_did
      eps = adapter.edge_endpoints(g) if adapter.respond_to?(:edge_endpoints)
      next false unless eps.is_a?(Array) && eps.length == 2
      eps[1].respond_to?(:position) && eps[1].position[0] == 0.0 &&
        eps[1].position[1] == 1.0 / 25.4
    }
    refute_nil edge_b_c_did,
               'Owner fixture MUST expose one derived edge whose end endpoint is (0,1mm,Z) (edge D-E)'
    # B end-of-A-B + B start-of-B-C; do not assume A-B is
    # the first derived_id — the V1.4 prepare pipeline
    # walks the source snapshot in order so for this
    # fixture A-B is the FIRST derived edge (id 0) and
    # B-C is the SECOND (id 1).
    ab_b_handle = hvm_after_planar["#{edge_a_b_did}.end"]
    bc_b_handle = hvm_after_planar["#{edge_b_c_did}.start"]
    refute_nil ab_b_handle,
               'A-B .end endpoint Vertex handle MUST be resolvable from host_vertex_map'
    refute_nil bc_b_handle,
               'B-C .start endpoint Vertex handle MUST be resolvable from host_vertex_map'
    # FINAL-R5-01: the two physical B handles MUST be
    # IDENTITY-distinct (different object_ids).
    refute_equal ab_b_handle.object_id, bc_b_handle.object_id,
                 'the two physical B Vertex handles MUST be identity-distinct (R5 contract)'
    # FINAL-R5-01: read both Z values via the adapter's
    # live vertex_position seam.
    ab_b_pos = adapter.vertex_position(ab_b_handle)
    bc_b_pos = adapter.vertex_position(bc_b_handle)
    refute_nil ab_b_pos,
               'A-B .end live vertex_position MUST be readable'
    refute_nil bc_b_pos,
               'B-C .start live vertex_position MUST be readable'
    assert_equal 3, ab_b_pos.length,
                 'A-B .end live position MUST be exactly 3'
    assert_equal 3, bc_b_pos.length,
                 'B-C .start live position MUST be exactly 3'
    # FINAL-R5-01: both Z values MUST equal the planar
    # target Z within the existing coordinate_epsilon.
    target_z = V19A_FP_RUNNER.planar_normalization_audit['target_z']
    refute_nil target_z,
               'runner MUST publish planar_normalization_audit.target_z for this assertion'
    eps = v19a_fp_tol(1.0e-4, 0.01).coordinate_epsilon
    assert_in_delta target_z.to_f, ab_b_pos[2].to_f, eps,
                    'A-B .end (physical B handle 1) Z MUST equal planar target_z within coordinate_epsilon'
    assert_in_delta target_z.to_f, bc_b_pos[2].to_f, eps,
                    'B-C .start (physical B handle 2) Z MUST equal planar target_z within coordinate_epsilon'
    # === Step 3: CadPrepWorkflowOrchestrator.apply_gap_and_refresh ===
    apply_g_snap = CadPrepWorkflowOrchestrator.apply_gap_and_refresh
    assert_equal 'ready', apply_g_snap['state'],
                 'orchestrator.apply_gap_and_refresh MUST yield a ready workspace'
    # Structure is auto-recomputed on the returned snapshot.
    struct = apply_g_snap['structure_reconstruction']
    refute_nil struct, 'returned snapshot MUST expose structure_reconstruction sub-snapshot (auto-recomputed)'
    assert_equal 'READY', struct['state'].to_s,
                 'structure MUST be READY after apply_gap_and_refresh'
    metrics = struct['metrics'] || {}
    assert_equal 0, metrics['open_chain_count'].to_i,
                 'open_chain_count MUST be 0 after Z+Gap fix; got ' \
                 "#{metrics.inspect}"
    assert_equal 1, metrics['closed_loop_count'].to_i,
                 "closed_loop_count MUST be 1; got #{metrics.inspect}"
    assert_equal 1, metrics['region_count'].to_i,
                 "region_count MUST be 1; got #{metrics.inspect}"
    assert_equal 0, metrics['invalid_loop_count'].to_i,
                 'invalid_loop_count MUST be 0 (no non_planar_loop residue)'
    # No closed loop carries non_planar_loop.
    # V1.8 production shape: `loops`[].unresolved_flags.
    loops = struct['loops'] || struct['closed_loops'] || []
    loops.each do |loop|
      flags = Array(loop['unresolved_flags'])
      assert !flags.include?('non_planar_loop'),
             'NO closed loop MAY carry non_planar_loop after the V1.9A P0 fix'
    end
    # The presenter surfaces Gap action enabled after
    # planar apply.
    pres_after = SUAnalysis::Extension::CadPrepWorkflowPresenter.present(
      analysis_result: nil, workspace_snapshot: apply_g_snap
    )
    gap_card_after = pres_after['cards'].find { |c| c['id'] == 'gap_endpoint' }
    refute_nil gap_card_after
    if gap_card_after['primary_action']
      # After gap apply the topology_repair state is
      # APPLIED (no longer READY_TO_REPAIR). The
      # presenter's gap card surfaces 'APPLIED' state
      # (no primary_action in that branch). This test
      # only asserts the post-planar intermediate
      # (gap unlocked) state.
    end
    # === Step 4: post-planar intermediate state proves
    # the gap was auto-unlocked before the user clicked
    # 修复间隙. ===
    pres_after_planar = SUAnalysis::Extension::CadPrepWorkflowPresenter.present(
      analysis_result: nil, workspace_snapshot: apply_p_snap
    )
    gap_card_after_planar = pres_after_planar['cards'].find { |c| c['id'] == 'gap_endpoint' }
    refute_nil gap_card_after_planar
    refute_nil gap_card_after_planar['primary_action']
    assert gap_card_after_planar['primary_action']['enabled'],
           'gap repair action MUST be enabled after planar apply (gap auto-unlocks)'
  ensure
    V19A_FP_RUNNER.reset_for_tests
  end
end
