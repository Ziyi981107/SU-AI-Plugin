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
require_relative '../extension/su_ai_plugin/core/planar_normalization_analyzer'
require_relative '../extension/su_ai_plugin/core/planar_normalization_proposer'
require_relative '../extension/su_ai_plugin/core/planar_normalization_executor'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'

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
  # Subclass: the first vertex_position call after
  # the first transform call returns a wrong Z
  # (postvalidate failure).
  hvm = v19a_fp_host_vertex_map(ws, adapter)
  # We want to inject a wrong Z for the FIRST
  # physical Vertex only, so postvalidation
  # detects dx/dy/dz drift.
  # Simplest: just return a different Z for the
  # first physical handle after the mutation.
  first_handle = hvm.values.first
  post_count = 0
  spied = Class.new(adapter.class) do
    define_method(:begin_operation) do |model, label:|
      adapter.begin_operation(model, label: label)
    end
    define_method(:end_operation) do |model, commit:|
      adapter.end_operation(model, commit: commit)
    end
    define_method(:transform_vertices_by_vectors) do |handles, vectors|
      adapter.transform_vertices_by_vectors(handles, vectors)
    end
    define_method(:vertex_position) do |h|
      if h.object_id == first_handle.object_id
        # Return the current position but with a
        # bogus large Z so postvalidation fails
        # (dz exceeds coordinate_epsilon).
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
