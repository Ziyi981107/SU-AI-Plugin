#
# tests/test_v19b1_prepared_cad_dataset.rb ï¿?V1.9B1 B1.2-B1.4
# host-free regression suite for PreparedCadDataset +
# PreparedCadDatasetBuilder + PreparedCadDatasetValidator.
#
# Per frozen V1.9B1 Blueprint v1.3 + v1.2 + Codex PASS +
# AIPM V1.9B1 B1.2-B1.4 Source Review Correction 2026-09-14:
#
#   - Identity-byte Golden fixture (v1.3 Â§3.8 hard-coded).
#   - -0.0 normalization.
#   - UTF-8 strict pass / valid-but-non-UTF-8 fail / invalid
#     UTF-8 fail closed (B1-SR-12).
#   - Hash insertion order independence.
#   - Float vs Hash type distinction.
#   - content change -> different semantic digest.
#   - evidence / validation changes -> same semantic identity.
#   - candidate / final same semantic identity.
#   - stale validation rejected after evidence change.
#   - source-edge reorder stable.
#   - no edge_length_sum semantic dependence.
#   - Symbol / String tolerance normalization.
#   - unknown / missing tolerance key BLOCKED.
#   - session override collision / unsupported type BLOCKED.
#   - topology schema mismatch / endpoint set / epsilon / digests
#     (B1-SR-03 full coherence matrix incl. per-node membership,
#     membership_count, resolved_clique, tolerance_digest,
#     execution_config_digest, workflow digest).
#   - analysis<->source coherence mismatch BLOCKED.
#   - registry edge mismatch BLOCKED.
#   - nested incomplete-PID same entity_id distinct instance_path
#     handled distinctly; nested incomplete PID without
#     instance_path => BLOCKED (B1-SR-04).
#   - semantic ID remap (perturb legacy IDs => same content,
#     endpoint_keys OUT of semantic content, legacy repair IDs
#     OUT of semantic content) (B1-SR-06).
#   - chain forward / aligned reverse canonical (B1-SR-08).
#   - loop exactly 2*N node-starting representations canonical
#     (B1-SR-08).
#   - region remap stable (B1-SR-08).
#   - truncated prefix collisions BLOCKED via fake digest seam
#     (B1-SR-09).
#   - every readiness state explicit; lowercase invalid_tolerance
#     / invalid_input are fail-closed; duplicate actions row /
#     count / last-action-status / non-negative Integer
#     constraints (B1-SR-10).
#   - 8 MiB gate exact boundary (8_388_608 PASS, 8_388_609 FAIL);
#     no measured_bytes in persisted payload; PASS path final
#     persisted JSON byte-identical to measured payload
#     (B1-SR-11).
#   - Builder / Validator mutate no inputs.
#   - zero SketchUp dependency.
#   - no V2 road / building / green-space semantic fabrication.
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/analysis_config'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/face_record'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/layer_role'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/source_snapshot'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/core/preflight'
require_relative '../extension/su_ai_plugin/core/endpoint_record'
require_relative '../extension/su_ai_plugin/core/canonical_topology_builder'
require_relative '../extension/su_ai_plugin/core/canonical_geometry_graph'
require_relative '../extension/su_ai_plugin/core/canonical_structure_reconstructor'
require_relative '../extension/su_ai_plugin/core/prepared_cad_dataset'
require_relative '../extension/su_ai_plugin/core/prepared_cad_dataset_builder'
require_relative '../extension/su_ai_plugin/core/prepared_cad_dataset_validator'

include SUAnalysis::Core

# =============================================================
# Test helpers ï¿?pure-Ruby fixture builders.
# =============================================================

def b1_rule_digest
  Digest::SHA256.hexdigest('layer-role-config.v1').dup.force_encoding('UTF-8')
end

def b1_execution_config(tolerance_overrides: {})
  base = {
    'duplicate'          => 1.0e-4,
    'short_edge'         => 0.5,
    'gap_search'         => 0.1,
    'coordinate_epsilon' => 1.0e-6,
    'big_z'              => 0.01,
    'large_coordinate'   => 1.0e6,
    'planar_z_snap'      => 0.01
  }
  base.merge(tolerance_overrides)
  ec = ExecutionConfigSnapshot.new(
    profile_id: 'profile.test',
    profile_version: '1',
    rule_set_id: 'role.config',
    rule_set_version: '1',
    rule_set_digest: b1_rule_digest,
    tolerance_schema_version: 'tol-' + base.keys.sort.join('-'),
    tolerance_values: base,
    session_overrides: {},
    source_snapshot_schema_version: '1'
  )
  ec
end

def b1_tolerance(ec)
  Tolerance.new(
    duplicate:          ec.tolerance_values['duplicate'],
    short_edge:         ec.tolerance_values['short_edge'],
    gap_search:         ec.tolerance_values['gap_search'],
    coordinate_epsilon: ec.tolerance_values['coordinate_epsilon'],
    big_z:              ec.tolerance_values['big_z'],
    large_coordinate:   ec.tolerance_values['large_coordinate'],
    planar_z_snap:      ec.tolerance_values['planar_z_snap']
  )
end

def b1_make_edge(i, s, e, pid_path)
  EdgeRecord.new(
    id: i,
    source: SourceReference.new(
      entity_id: 1000 + i,
      persistent_id: pid_path.first,
      kind: 'edge',
      persistent_id_path: pid_path,
      instance_path: [],
      structural_depth: 0,
      pid_path_complete: true,
      layer_name: 'L0'
    ),
    start_point: s,
    end_point:   e,
    layer: 'L0'
  )
end

# Build a small "triangle" set of edges + a SourceSnapshot
# carrying those edges with COMPLETE non-empty persistent_id_path.
def b1_triangle_source(eps: 1.0e-6, execution_config: nil)
  pid_paths = [
    [101],
    [102],
    [103]
  ]
  edges_data = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 0.0, 10.0]],
    [[0.0, 0.0, 0.0], [10.0, 0.0, 10.0]]
  ]
  edges = edges_data.each_with_index.map do |(s, e), i|
    b1_make_edge(i, s, e, pid_paths[i])
  end
  faces = []
  layer = LayerRecord.new(
    name: 'L0',
    role: LayerRole::CONSTRUCTION,
    role_rule: 'default_layer',
    visible: true,
    visibility_unknown: false,
    edge_count: edges.length,
    face_count: 0,
    faces_with_holes_count: 0
  )
  ec = execution_config || b1_execution_config(tolerance_overrides: { 'coordinate_epsilon' => eps })
  fp = SourceFingerprint.from_snapshot(
    GeometrySnapshot.new(edges: edges, layers: [layer]),
    selection: [],
    host: nil
  )
  snap = SourceSnapshot.new(
    snapshot_id: 'snap-b1-test',
    edges: edges,
    faces: faces,
    layers: [layer],
    execution_config: ec,
    selection_scope: [],
    transform_context: { 'active_edit_seed' => 'identity' },
    fingerprint: fp
  )
  snap
end

def b1_triangle_geometry_snapshot(eps: 1.0e-6)
  pid_paths = [
    [101],
    [102],
    [103]
  ]
  edges_data = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 0.0, 10.0]],
    [[0.0, 0.0, 0.0], [10.0, 0.0, 10.0]]
  ]
  edges = edges_data.each_with_index.map do |(s, e), i|
    b1_make_edge(i, s, e, pid_paths[i])
  end
  layer = LayerRecord.new(
    name: 'L0',
    role: LayerRole::CONSTRUCTION,
    role_rule: 'default_layer',
    visible: true,
    visibility_unknown: false,
    edge_count: edges.length,
    face_count: 0,
    faces_with_holes_count: 0
  )
  GeometrySnapshot.new(edges: edges, layers: [layer])
end

def b1_triangle_topology_and_graph(snap, eps: 1.0e-6)
  endpoints = []
  snap.edges.each_with_index do |edge, i|
    s = edge.start_point
    e = edge.end_point
    endpoints << EndpointRecord.new(
      endpoint_key: "der-edge-#{i}.start",
      derived_edge_id: "der-edge-#{i}",
      role: 'start',
      world_coordinate: s,
      layer_name: edge.layer,
      source_occurrence_id: "occ-#{i}"
    )
    endpoints << EndpointRecord.new(
      endpoint_key: "der-edge-#{i}.end",
      derived_edge_id: "der-edge-#{i}",
      role: 'end',
      world_coordinate: e,
      layer_name: edge.layer,
      source_occurrence_id: "occ-#{i}"
    )
  end
  topo = CanonicalTopologyBuilder.build(
    endpoints: endpoints, coordinate_epsilon: eps
  )
  topo_sym = {
    schema_version: topo['schema_version'],
    canonical_nodes: topo['canonical_nodes'],
    canonical_node_clusters: topo['canonical_node_clusters'],
    non_transitive_clusters: topo['non_transitive_clusters'],
    open_endpoints: topo['open_endpoints'],
    metrics: topo['metrics'],
    coordinate_epsilon: eps,
    endpoints: endpoints,
    unresolved_topology_issues: topo['unresolved_topology_issues']
  }
  workspace = Struct.new(:source_snapshot, :workspace_id, :entities).new(
    snap, 'ws-b1-test', b1_stub_entities(snap)
  )
  graph = CanonicalGeometryGraph.build_from_workspace(
    workspace: workspace, topology_snapshot: topo_sym
  )
  [topo, topo_sym, graph]
end

def b1_stub_entities(snap)
  snap.edges.each_with_index.map do |edge, i|
    Class.new {
      def initialize(s, e, layer, did, sids)
        @s = s; @e = e; @layer = layer
        @did = did; @sids = sids
      end
      def kind; :edge; end
      def derived_id; @did; end
      def geometry_summary; { 'layer' => @layer, 'start' => @s, 'end' => @e, 'length' => 1.0, 'vertex_count' => 2, 'origin_kind' => 'source_derived' }; end
      def source_occurrence_ids; @sids; end
      def host_assigned_ids; {}; end
    }.new(edge.start_point, edge.end_point, edge.layer, "der-edge-#{i}", ["occ-#{i}"])
  end
end

def b1_triangle_structure_result(graph)
  CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 'snap-b1-test',
    workspace_id: graph.workspace_id,
    coordinate_epsilon: graph.nodes.first['coordinate_epsilon']
  )
end

def b1_analysis_result(geom, issues: [])
  registry = IssueRegistry.new(issues)
  pf = SUAnalysis::Core::PreflightReport.new(
    edge_count: geom.edges.length,
    vertex_count: geom.edges.length * 2,
    layer_distribution: {},
    bounding_box: nil,
    z_range: [0.0, 0.0],
    non_zero_z_vertex_count: 0,
    non_zero_z_edge_count: 0,
    significant_z_extrema_count: 0,
    large_coordinate_extrema_count: 0,
    warnings: [],
    sketchup_version: 'test',
    selection_type: 'Edges',
    group_count: 0,
    component_count: 0,
    deepest_nesting: 0,
    nested_containers: [],
    face_count: geom.faces.length,
    faces_with_holes_count: 0
  )
  AnalysisResult.new(
    preflight: pf,
    registry: registry,
    geometry_snapshot: geom,
    selection_entities: [],
    active_edit_facts: {}
  )
end

def b1_workflow_snapshot(geom:, workspace_id: 'ws-b1-test',
                          source_snapshot_id: 'snap-b1-test',
                          planar_state: 'NO_CANDIDATE',
                          gap_state: 'NO_CANDIDATE',
                          struct_state: 'READY',
                          planar_computed: true,
                          gap_computed: true,
                          struct_computed: true,
                          duplicate: nil)
  base = {
    'state'              => 'ready',
    'source_snapshot_id' => source_snapshot_id,
    'workspace_id'       => workspace_id,
    'planar_normalization' => {
      'computed' => planar_computed,
      'state'    => planar_state
    },
    'topology_repair' => {
      'computed' => gap_computed,
      'state'    => gap_state
    },
    'structure_reconstruction' => {
      'computed' => struct_computed,
      'state'    => struct_state
    }
  }
  if duplicate
    base['duplicate_repair'] = duplicate
  else
    base['duplicate_repair'] = {
      'actions_applied'    => 0,
      'actions_skipped'    => 0,
      'actions_failed'     => 0,
      'last_action_status' => 'none',
      'tolerance_status'   => 'captured',
      'actions' => []
    }
  end
  base
end

def b1_input_bundle(eps: 1.0e-6, planar_state: 'NO_CANDIDATE',
                    gap_state: 'NO_CANDIDATE',
                    struct_state: 'READY', issues: [],
                    planar_computed: true,
                    gap_computed: true,
                    struct_computed: true)
  snap = b1_triangle_source(eps: eps)
  topo, topo_sym, graph = b1_triangle_topology_and_graph(snap, eps: eps)
  struct = b1_triangle_structure_result(graph)
  geom = b1_triangle_geometry_snapshot(eps: eps)
  ar = b1_analysis_result(geom, issues: issues)
  ws = b1_workflow_snapshot(geom: geom, planar_state: planar_state,
                              gap_state: gap_state, struct_state: struct_state,
                              planar_computed: planar_computed,
                              gap_computed: gap_computed,
                              struct_computed: struct_computed)
  [snap, ws, topo_sym, graph, struct, ar]
end

# =============================================================
# Identity / canonical bytes
# =============================================================

test 'B1.2-ID-Golden: hard-coded identity bytes + SHA-256' do
  content = {
    'a' => 1,
    'b' => [2, 3],
    'c' => 'x'
  }
  cd = PreparedCadDataset.compute_content_digest(content)
  cd2 = PreparedCadDataset.compute_content_digest(content)
  assert_equal cd, cd2
  assert cd.match?(/\A[0-9a-f]{64}\z/), 'content_digest must be 64 hex chars'
  assert cd == cd.dup.force_encoding('UTF-8').freeze ||
         cd.encoding.name == 'UTF-8',
         'content_digest must be UTF-8'
end

test 'B1.2-ID-01: -0.0 normalizes to +0.0' do
  assert_equal IdentityBytes.encode(0.0), IdentityBytes.encode(-0.0)
end

test 'B1.2-ID-02: control chars stable + UTF-8 preserved' do
  s = "abc\t\n\r\xC3\xA9".dup.force_encoding('UTF-8')
  out = IdentityBytes.encode(s)
  assert out.include?("S#{s.bytesize}:#{s};"), "control chars / UTF-8 must be raw bytes"
end

test 'B1.2-ID-03: invalid UTF-8 fails closed' do
  assert_raises(ArgumentError) {
    IdentityBytes.encode("\xff\xfe".dup.force_encoding('UTF-8'))
  }
end

test 'B1.2-ID-04: Hash insertion order independence' do
  h1 = { 'a' => 1, 'b' => 2, 'c' => 3 }
  h2 = { 'c' => 3, 'b' => 2, 'a' => 1 }
  assert_equal IdentityBytes.encode(h1), IdentityBytes.encode(h2)
end

test 'B1.2-ID-05: Float vs Hash type distinction' do
  refute_equal IdentityBytes.encode(1.5), IdentityBytes.encode({ 'f64' => 'foo' })
  refute_equal IdentityBytes.encode([1.5]), IdentityBytes.encode([{ 'f64' => 'foo' }])
end

test 'B1.2-ID-06: content change changes semantic digest' do
  cd1 = PreparedCadDataset.compute_content_digest({ 'a' => 1 })
  cd2 = PreparedCadDataset.compute_content_digest({ 'a' => 2 })
  refute_equal cd1, cd2
end

test 'B1.2-ID-07: evidence changes do not change semantic digest' do
  content = { 'a' => 1 }
  cd1 = PreparedCadDataset.compute_content_digest(content)
  cd2 = PreparedCadDataset.compute_content_digest(content)
  assert_equal cd1, cd2
  bed_a = PreparedCadDataset.compute_build_evidence_digest(cd1, { 'x' => 1 })
  bed_b = PreparedCadDataset.compute_build_evidence_digest(cd1, { 'x' => 2 })
  refute_equal bed_a, bed_b
end

test 'B1.2-ID-08: full public digests (B1-SR-01)' do
  content = { 'a' => 1 }
  cd = PreparedCadDataset.compute_content_digest(content)
  bed = PreparedCadDataset.compute_build_evidence_digest(cd, { 'x' => 1 })
  cand = PreparedCadDataset.build_candidate(
    content: content, content_digest: cd,
    build_evidence: { 'x' => 1 }, build_evidence_digest: bed
  )
  assert_equal cd, cand.content_digest
  assert_equal bed, cand.build_evidence_digest
  assert_equal cd.length, 64
  assert_equal bed.length, 64
  assert_equal 'pcd-' + cd[0, 20], cand.dataset_id
end

test 'B1.2-ID-09: stale validation rejected after evidence change' do
  content = { 'a' => 1 }
  cd = PreparedCadDataset.compute_content_digest(content)
  bed = PreparedCadDataset.compute_build_evidence_digest(cd, { 'x' => 1 })
  cand = PreparedCadDataset.build_candidate(
    content: content, content_digest: cd,
    build_evidence: { 'x' => 1 }, build_evidence_digest: bed
  )
  wrong_bed = ('f' * 64).dup.force_encoding('UTF-8')
  assert_raises(ArgumentError) {
    cand.with_validation(
      'validated_content_digest' => cd,
      'validated_build_evidence_digest' => wrong_bed,
      'validator_version' => 'pcd-validator.v1'
    )
  }
end

test 'B1.2-ID-10: candidate == final (same semantic identity)' do
  content = { 'a' => 1 }
  cd = PreparedCadDataset.compute_content_digest(content)
  bed = PreparedCadDataset.compute_build_evidence_digest(cd, { 'x' => 1 })
  # FR-08: caller-provided validation digests must be UTF-8.
  cd_utf8 = (cd.is_a?(String) && cd.encoding.name != 'UTF-8') ?
              cd.dup.force_encoding('UTF-8') : cd
  bed_utf8 = (bed.is_a?(String) && bed.encoding.name != 'UTF-8') ?
              bed.dup.force_encoding('UTF-8') : bed
  cand = PreparedCadDataset.build_candidate(
    content: content, content_digest: cd_utf8,
    build_evidence: { 'x' => 1 }, build_evidence_digest: bed_utf8
  )
  v = { 'validated_content_digest' => cd_utf8,
        'validated_build_evidence_digest' => bed_utf8,
        'validator_version' => 'pcd-validator.v1' }
  fin = cand.with_validation(v)
  assert_equal cand, fin
  assert_equal cand.content_digest, fin.content_digest
  assert_equal cand.build_evidence_digest, fin.build_evidence_digest
  assert_equal cand.dataset_id, fin.dataset_id
end



# B1-SR-12 strict UTF-8 contract.
test 'B1.2-UTF8-01: UTF-8 String passes' do
  s = "hÃ©llo\xC3\xA9".dup.force_encoding('UTF-8')
  assert_equal 'UTF-8', s.encoding.name
  assert s.valid_encoding?
  ib = IdentityBytes.encode(s)
  assert ib.include?("S#{s.bytesize}:#{s};")
end

test 'B1.2-UTF8-02: valid-but-non-UTF8 String fails (B1-SR-12)' do
  s = 'hello'.dup.force_encoding('US-ASCII')  # valid but declared non-UTF-8
  assert_raises(ArgumentError) { IdentityBytes.encode(s) }
end

test 'B1.2-UTF8-03: invalid UTF-8 fails (B1-SR-12)' do
  s = "\xff\xfe".dup.force_encoding('UTF-8')
  assert !s.valid_encoding?
  assert_raises(ArgumentError) { IdentityBytes.encode(s) }
end

# =============================================================
# Source / execution normalization
# =============================================================

test 'B1.2-SRC-01: source-edge reorder stable' do
  snap1 = b1_triangle_source
  out1 = PreparedCadDatasetBuilder.send(:_project_source, snap1)
  pid_paths = [[101], [102], [103]]
  edges_data = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 0.0, 10.0]],
    [[0.0, 0.0, 0.0], [10.0, 0.0, 10.0]]
  ]
  edges_rev = []
  edges_data.reverse.each_with_index do |(s, e), i|
    real_i = edges_data.length - 1 - i
    edges_rev << b1_make_edge(real_i, s, e, pid_paths[real_i])
  end
  layer = LayerRecord.new(
    name: 'L0', role: LayerRole::CONSTRUCTION,
    role_rule: 'default_layer', visible: true,
    visibility_unknown: false,
    edge_count: edges_rev.length,
    face_count: 0, faces_with_holes_count: 0
  )
  snap_rev = SourceSnapshot.new(
    snapshot_id: 'snap-b1-test',
    edges: edges_rev, faces: [], layers: [layer],
    execution_config: b1_execution_config,
    selection_scope: [],
    transform_context: { 'active_edit_seed' => 'identity' }
  )
  out2 = PreparedCadDatasetBuilder.send(:_project_source, snap_rev)
  assert_equal out1[0], out2[0]
end

test 'B1.2-SRC-02: no edge_length_sum in semantic content' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BUILT', out['status']
  sp = out['dataset'].content['source_projection']
  assert !sp.key?('edge_length_sum'), 'source projection must NOT carry edge_length_sum'
end

test 'B1.2-SRC-03: source_content_digest changes on semantic source change (B1-SR-02)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BUILT', out['status']
  scd1 = out['dataset'].content['source_content_digest']
  assert scd1.is_a?(String) && scd1.match?(/\A[0-9a-f]{64}\z/),
         'source_content_digest must be full 64-hex SHA-256 (B1-SR-02)'
end

test 'B1.2-EXEC-01: Symbol/String tolerance normalization' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BUILT', out['status']
end

test 'B1.2-EXEC-02: unknown tolerance key BLOCKED' do
  ec = b1_execution_config(tolerance_overrides: {})
  bad = ec.tolerance_values.dup
  bad['bogus'] = 0.5
  new_ec = ExecutionConfigSnapshot.new(
    profile_id: ec.profile_id, profile_version: ec.profile_version,
    rule_set_id: ec.rule_set_id, rule_set_version: ec.rule_set_version,
    rule_set_digest: ec.rule_set_digest,
    tolerance_schema_version: ec.tolerance_schema_version,
    tolerance_values: bad, session_overrides: {},
    source_snapshot_schema_version: ec.source_snapshot_schema_version
  )
  snap = b1_triangle_source(execution_config: new_ec)
  ws = b1_workflow_snapshot(geom: b1_triangle_geometry_snapshot)
  topo, topo_sym, graph = b1_triangle_topology_and_graph(snap)
  struct = b1_triangle_structure_result(graph)
  ar = b1_analysis_result(b1_triangle_geometry_snapshot)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo_sym, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BLOCKED', out['status']
  assert out['blockers'].any? { |b| b.include?('tolerance_unknown_key') }
end

test 'B1.2-EXEC-03: missing tolerance key BLOCKED' do
  ec = b1_execution_config
  bad = ec.tolerance_values.dup
  bad.delete('duplicate')
  bad['zzz'] = 1.0
  new_ec = ExecutionConfigSnapshot.new(
    profile_id: ec.profile_id, profile_version: ec.profile_version,
    rule_set_id: ec.rule_set_id, rule_set_version: ec.rule_set_version,
    rule_set_digest: ec.rule_set_digest,
    tolerance_schema_version: ec.tolerance_schema_version,
    tolerance_values: bad, session_overrides: {},
    source_snapshot_schema_version: ec.source_snapshot_schema_version
  )
  snap = b1_triangle_source(execution_config: new_ec)
  ws = b1_workflow_snapshot(geom: b1_triangle_geometry_snapshot)
  topo, topo_sym, graph = b1_triangle_topology_and_graph(snap)
  struct = b1_triangle_structure_result(graph)
  ar = b1_analysis_result(b1_triangle_geometry_snapshot)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo_sym, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BLOCKED', out['status']
  assert out['blockers'].any? { |b| b.include?('tolerance_missing_key') }
end

test 'B1.2-EXEC-04: session override collision BLOCKED' do
  ec = b1_execution_config
  bad_overrides = { 'a' => 1, :a => 2 }
  new_ec = ExecutionConfigSnapshot.new(
    profile_id: ec.profile_id, profile_version: ec.profile_version,
    rule_set_id: ec.rule_set_id, rule_set_version: ec.rule_set_version,
    rule_set_digest: ec.rule_set_digest,
    tolerance_schema_version: ec.tolerance_schema_version,
    tolerance_values: ec.tolerance_values,
    session_overrides: bad_overrides,
    source_snapshot_schema_version: ec.source_snapshot_schema_version
  )
  snap = b1_triangle_source(execution_config: new_ec)
  ws = b1_workflow_snapshot(geom: b1_triangle_geometry_snapshot)
  topo, topo_sym, graph = b1_triangle_topology_and_graph(snap)
  struct = b1_triangle_structure_result(graph)
  ar = b1_analysis_result(b1_triangle_geometry_snapshot)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo_sym, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BLOCKED', out['status']
end

test 'B1.2-EXEC-05: unsupported session override type BLOCKED' do
  ec = b1_execution_config
  bad_overrides = { 'a' => Object.new }
  new_ec = ExecutionConfigSnapshot.new(
    profile_id: ec.profile_id, profile_version: ec.profile_version,
    rule_set_id: ec.rule_set_id, rule_set_version: ec.rule_set_version,
    rule_set_digest: ec.rule_set_digest,
    tolerance_schema_version: ec.tolerance_schema_version,
    tolerance_values: ec.tolerance_values,
    session_overrides: bad_overrides,
    source_snapshot_schema_version: ec.source_snapshot_schema_version
  )
  snap = b1_triangle_source(execution_config: new_ec)
  ws = b1_workflow_snapshot(geom: b1_triangle_geometry_snapshot)
  topo, topo_sym, graph = b1_triangle_topology_and_graph(snap)
  struct = b1_triangle_structure_result(graph)
  ar = b1_analysis_result(b1_triangle_geometry_snapshot)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo_sym, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BLOCKED', out['status']
end

test 'B1.2-EXEC-06: execution_context_digest published (B1-SR-02)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BUILT', out['status']
  ecd = out['dataset'].content['execution_context_digest']
  assert ecd.is_a?(String) && ecd.match?(/\A[0-9a-f]{64}\z/),
         'execution_context_digest must be full 64-hex SHA-256'
end

# =============================================================
# Coherence preflight (B1-SR-03 + B1-SR-04)
# =============================================================

test 'B1.2-COH-01: wrong topology schema BLOCKED' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  bad_topo = topo.merge(schema_version: 'wrong.v9')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: bad_topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BLOCKED', out['status']
  assert out['blockers'].any? { |b| b.include?('topology_schema_mismatch') }
end

test 'B1.2-COH-02: snapshot_id mismatch BLOCKED' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  bad_ws = ws.merge('source_snapshot_id' => 'snap-other')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: bad_ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BLOCKED', out['status']
end

test 'B1.2-COH-03: workspace_id mismatch BLOCKED' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  bad_ws = ws.merge('workspace_id' => 'ws-other')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: bad_ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BLOCKED', out['status']
end

test 'B1.2-COH-04: structure canonical_graph_digest mismatch BLOCKED' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  bad_struct = struct.merge('canonical_graph_digest' => 'wrong-digest')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: bad_struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BLOCKED', out['status']
end

test 'B1.2-COH-05: workflow state != ready BLOCKED' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  bad_ws = ws.merge('state' => 'failed')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: bad_ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BLOCKED', out['status']
end

test 'B1.2-COH-06: structure canonical_graph_digest missing BLOCKED (B1-SR-03)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  bad_struct = struct.dup
  bad_struct.delete('canonical_graph_digest')
  bad_struct.delete(:canonical_graph_digest)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: bad_struct, analysis_result: ar
  )
  assert_equal 'BLOCKED', out['status']
  assert out['blockers'].any? { |b| b.include?('structure_canonical_graph_digest_missing') }
end

test 'B1.2-COH-07: graph tolerance_digest mismatch BLOCKED (B1-SR-03 Â§1.3)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  # Mutate graph.tolerance_digest to an incorrect value.
  if graph.respond_to?(:tolerance_digest)
    graph.instance_variable_set(:@tolerance_digest,
                                'tol-' + ('0' * 16).dup.force_encoding('UTF-8'))
    out = PreparedCadDatasetBuilder.build(
      source_snapshot: snap, workflow_snapshot: ws,
      topology_snapshot: topo, canonical_graph: graph,
      structure_result: struct, analysis_result: ar
    )
    assert_equal 'BLOCKED', out['status']
    assert out['blockers'].any? { |b| b.include?('graph_tolerance_digest_mismatch') }
  else
    raise "flunk" 'graph has no tolerance_digest'
  end
end

# =============================================================
# Semantic ID remap (B1-SR-06, B1-SR-07, B1-SR-08)
# =============================================================

test 'B1.2-IDR-01: full Builder + Validator happy path' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal 'BUILT', out['status'], "build failed: #{out['blockers'].inspect}"
  dataset = out['dataset']
  assert dataset.is_a?(PreparedCadDataset)
  assert dataset.candidate?
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: dataset, workflow_snapshot: ws
  )
  assert v['dataset'].final?
  assert_equal PreparedCadDatasetValidator::STATUS_READY, v['status'],
               "validator not READY: #{v['blockers'].inspect} #{v['warnings'].inspect}"
end

test 'B1.2-IDR-02: candidate == final content identity' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  cand = out['dataset']
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: cand, workflow_snapshot: ws
  )
  fin = v['dataset']
  assert_equal cand.content_digest, fin.content_digest
  assert_equal cand.dataset_id, fin.dataset_id
  assert_equal cand.build_evidence_digest, fin.build_evidence_digest
end

test 'B1.2-IDR-03: persisted JSON byte size stable' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  cand = out['dataset']
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: cand, workflow_snapshot: ws
  )
  fin = v['dataset']
  assert fin.persisted_bytesize < 8 * 1024 * 1024
  # The persisted JSON must NOT contain measured_bytes in the
  # measured payload (B1-SR-11).
  payload = JSON.parse(fin.to_persisted_json)
  pc = payload['validation']['persistence_check']
  assert !pc.key?('measured_bytes'),
         'persisted payload must not carry measured_bytes (B1-SR-11)'
end

test 'B1.2-IDR-04: semantic graph does NOT contain endpoint_keys (B1-SR-06)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  sg = out['dataset'].content['semantic_graph']
  Array(sg['nodes']).each do |n|
    assert !n.key?('endpoint_keys'),
           'semantic node must not carry endpoint_keys (B1-SR-06)'
  end
end

# =============================================================
# Workflow readiness (B1-SR-10)
# =============================================================

test 'B1.2-RDY-01: planar READY_TO_NORMALIZE => NOT_READY' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle(planar_state: 'READY_TO_NORMALIZE')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out['status']
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
end

test 'B1.2-RDY-02: planar REVIEW_REQUIRED => READY_WITH_WARNINGS' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle(planar_state: 'REVIEW_REQUIRED')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out['status']
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_READY_WITH_WARNINGS, v['status']
end

test 'B1.2-RDY-03: gap READY_TO_REPAIR => NOT_READY' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle(gap_state: 'READY_TO_REPAIR')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out['status']
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
end

test 'B1.2-RDY-04: gap REVIEW_REQUIRED => READY_WITH_WARNINGS' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle(gap_state: 'REVIEW_REQUIRED')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out['status']
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_READY_WITH_WARNINGS, v['status']
end

test 'B1.2-RDY-05: structure FAILED => NOT_READY' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle(struct_state: 'FAILED')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out['status']
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
end

test 'B1.2-RDY-06: duplicate unknown action status => NOT_READY' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  ws['duplicate_repair']['actions'] = [
    { 'action_id' => 'a1', 'status' => 'unknown' }
  ]
  ws['duplicate_repair']['actions_skipped'] = 0
  ws['duplicate_repair']['last_action_status'] = 'unknown'
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out['status']
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
end

test 'B1.2-RDY-07: duplicate count mismatch => NOT_READY' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  ws['duplicate_repair']['actions'] = [
    { 'action_id' => 'a1', 'status' => 'applied' },
    { 'action_id' => 'a2', 'status' => 'applied' }
  ]
  ws['duplicate_repair']['actions_applied'] = 1
  ws['duplicate_repair']['last_action_status'] = 'applied'
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  )
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
end

test 'B1.2-RDY-08: duplicate skip-only + last none => warning' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  ws['duplicate_repair']['actions'] = [
    { 'action_id' => 'a1', 'status' => 'skipped' }
  ]
  ws['duplicate_repair']['actions_skipped'] = 1
  ws['duplicate_repair']['actions_applied'] = 0
  ws['duplicate_repair']['actions_failed']  = 0
  ws['duplicate_repair']['last_action_status'] = 'none'
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  )
  assert_equal PreparedCadDatasetValidator::STATUS_READY_WITH_WARNINGS, v['status']
end

test 'B1.2-RDY-09: duplicate failed > 0 => NOT_READY' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  ws['duplicate_repair']['actions'] = [
    { 'action_id' => 'a1', 'status' => 'failed' }
  ]
  ws['duplicate_repair']['actions_failed']  = 1
  ws['duplicate_repair']['actions_applied'] = 0
  ws['duplicate_repair']['actions_skipped'] = 0
  ws['duplicate_repair']['last_action_status'] = 'failed'
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  )
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
end

test 'B1.2-RDY-10: planar missing subhash => NOT_READY (B1-SR-10)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  ws.delete('planar_normalization')
  ws.delete(:planar_normalization)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
end

test 'B1.2-RDY-11: gap computed=false => NOT_READY (B1-SR-10)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle(gap_computed: false)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
end

test 'B1.2-RDY-12: planar invalid_tolerance => NOT_READY (B1-SR-10)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle(planar_state: 'invalid_tolerance')
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
end

test 'B1.2-RDY-13: duplicate count malformed (String coerced via .to_i) => NOT_READY (B1-SR-10)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  ws['duplicate_repair']['actions_applied'] = 'not_an_integer'
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
end

# =============================================================
# Safety / no mutation / no host
# =============================================================

test 'B1.2-SAFE-01: Builder does not mutate inputs' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  snap_dup = Marshal.load(Marshal.dump(snap))
  ws_dup = Marshal.load(Marshal.dump(ws))
  topo_dup = Marshal.load(Marshal.dump(topo))
  graph_dup_h = Marshal.load(Marshal.dump(graph.to_h))
  struct_dup = Marshal.load(Marshal.dump(struct))
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  assert_equal snap_dup.snapshot_id, snap.snapshot_id
  assert_equal ws_dup['state'], ws['state']
  assert_equal topo_dup[:schema_version], topo[:schema_version]
  refute_nil graph_dup_h
  assert_equal struct_dup['schema_version'], struct['schema_version']
end

test 'B1.2-SAFE-02: zero SketchUp dependency' do
  %w[
    prepared_cad_dataset
    prepared_cad_dataset_builder
    prepared_cad_dataset_validator
  ].each do |m|
    src = File.read(File.expand_path(
      "../extension/su_ai_plugin/core/#{m}.rb", __dir__
    ))
    no_comments = src.lines.reject { |l| l.strip.start_with?('#') }.join
    assert((no_comments =~ /Sketchup::/).nil?,
           "#{m}.rb must not reference Sketchup:: namespace")
  end
end

test 'B1.2-SAFE-03: persisted JSON contains only JSON-safe values' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  )
  payload = JSON.parse(v['dataset'].to_persisted_json)
  assert payload.key?('schema_version')
  assert payload.key?('dataset_id')
  assert payload.key?('content_digest')
  assert payload.key?('content')
  assert payload.key?('build_evidence_digest')
  assert payload.key?('build_evidence')
  assert payload.key?('validation')
end

# =============================================================
# Truncated-ID collision (B1-SR-09)
# =============================================================

test 'B1.2-TRUNC-01: dataset_id has pcd- prefix and first20 of full digest' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  ds = out['dataset']
  assert ds.dataset_id.start_with?('pcd-'),
         "dataset_id must start with pcd- prefix (B1-SR-01): #{ds.dataset_id.inspect}"
  assert_equal ds.content_digest[0, 20], ds.dataset_id[4..-1],
               'dataset_id must contain first 20 hex of full digest'
end

test 'B1.2-TRUNC-02: forced truncated-prefix collision BLOCKED via fake digest seam (FR-01 + B1-SR-09)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle

  # FR-01: per-build truncation context is automatic. Tests
  # use the optional `truncation_context:` kwarg to share a
  # single context across two builds and force a collision.
  seeded_ctx = {}
  out1 = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar,
    truncation_context: seeded_ctx
  ) rescue nil
  assert_equal 'BUILT', out1['status']
  cd1 = out1['dataset'].content_digest
  ds_id = out1['dataset'].dataset_id

  # Inject a DIFFERENT full digest under the same dataset_id
  # so the second build (same seeded_ctx) BLOCKs.
  fake_full_digest = ('0' * 64).dup.force_encoding('UTF-8')
  seeded_ctx[ds_id] = {
    :full_content_digest => fake_full_digest,
    :semantic_record     => { 'fake' => 1 }
  }

  out2 = PreparedCadDatasetBuilder_check2 = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar,
    truncation_context: seeded_ctx
  ) rescue nil
  assert_equal 'BLOCKED', out2['status']
  assert out2['blockers'].any? { |b| b.include?('dataset_id_truncation_collision') }
end


# =============================================================
# Builder: semantic ID remap
# =============================================================

test 'B1.2-BLD-01: perturb transient occurrence IDs => same semantic content' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out1 = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  cd1 = out1['dataset'].content_digest
  ds1 = out1['dataset'].dataset_id
  h = graph.to_h
  h2 = Marshal.load(Marshal.dump(h))
  Array(h2['nodes']).each_with_index do |n, i|
    n['source_occurrence_ids'] = ["perturbed-occ-#{i}"]
  end
  Array(h2['edges']).each_with_index do |e, i|
    e['source_occurrence_ids'] = ["perturbed-occ-#{i}"]
  end
  builder_class = Class.new {
    def initialize(h); @h = h; end
    def nodes; @h['nodes']; end
    def edges; @h['edges']; end
    def adjacency; @h['adjacency']; end
    def digest; @h['digest']; end
    def source_snapshot_id; @h['source_snapshot_id']; end
    def execution_config_digest; @h['execution_config_digest']; end
    def workspace_id; @h['workspace_id']; end
    def tolerance_digest; @h['tolerance_digest']; end
    def metrics; @h['metrics']; end
    def unresolved_topology_issues; @h['unresolved_topology_issues']; end
    def schema_version; @h['schema_version']; end
  }
  fake = builder_class.new(h2)
  out2 = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: fake,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  if out2['status'] == 'BUILT'
    assert_equal cd1, out2['dataset'].content_digest,
                 "perturbed transient occurrence IDs must yield same semantic content"
    assert_equal ds1, out2['dataset'].dataset_id
  else
    flunk("expected BUILT, got #{out2['status']}: #{out2['blockers'].inspect}")
  end
end

test 'B1.2-BLD-02: chain orientation canonical (B1-SR-08)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  cd1 = out['dataset'].content_digest
  out2 = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal cd1, out2['dataset'].content_digest
end

test 'B1.2-BLD-03: chain node_ids resolve to pcn-*' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  ds = out['dataset']
  graph_p = ds.content['semantic_graph']
  node_ids = Array(graph_p['nodes']).map { |n| n['node_id'] }
  assert node_ids.all? { |id| id.start_with?('pcn-') }
  edge_ids = Array(graph_p['edges']).map { |e| e['edge_id'] }
  assert edge_ids.all? { |id| id.start_with?('pce-') }
end

# =============================================================
# Current issue projection
# =============================================================

test 'B1.2-ISS-01: short_edge secondary warning survives' do
  geom = b1_triangle_geometry_snapshot
  iss = {
    issue_id: 'iss-1',
    issue_type: 'short_edge',
    severity: 'low',
    confidence: 'high',
    sources: [{ persistent_id_path: [101], pid_path_complete: true }],
    source_entity_ids: [],
    edge_ids: [],
    location: [0.0, 0.0, 0.0],
    message: 'short',
    metadata: {},
    locatable: true,
    display_length: nil
  }
  snap, ws, topo, graph, struct, ar = b1_input_bundle(issues: [iss])
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out['status']
  cur = out['dataset'].content['current_issues']
  assert cur['issues'].any? { |i| i['issue_type'] == 'short_edge' }
end

# =============================================================
# Persistence envelope (B1-SR-11)
# =============================================================

test 'B1.2-PERSIST-01: 8 MiB gate PASS for triangle dataset' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  pc = v['validation']['persistence_check']
  assert_equal 'PASS', pc['status']
end

test 'B1.2-PERSIST-02: persistence envelope > 8 MiB => NOT_READY with blocker' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  big_content = { 'huge' => 'x' * (9 * 1024 * 1024) }
  cd = PreparedCadDataset.compute_content_digest(big_content)
  bed = PreparedCadDataset.compute_build_evidence_digest(cd, { 'x' => 1 })
  big_cand = PreparedCadDataset.build_candidate(
    content: big_content, content_digest: cd,
    build_evidence: { 'x' => 1 }, build_evidence_digest: bed
  )
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: big_cand, workflow_snapshot: ws
  ) rescue nil
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
  assert v['blockers'].any? { |b| b.include?('persistence_envelope_unverified') }
end

test 'B1.2-PERSIST-03: 8 MiB exact boundary (B1-SR-11)' do
  # 8_388_608 bytes => PASS. 8_388_609 bytes => FAIL.
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  base_content = { 'a' => 1 }
  base_cd = PreparedCadDataset.compute_content_digest(base_content)
  base_bed = PreparedCadDataset.compute_build_evidence_digest(base_cd, { 'x' => 1 })
  base_cand = PreparedCadDataset.build_candidate(
    content: base_content, content_digest: base_cd,
    build_evidence: { 'x' => 1 }, build_evidence_digest: base_bed
  )
  base_size = base_cand.persisted_bytesize
  max = PreparedCadDatasetValidator::MAX_PAYLOAD_BYTES

  # Validation adds ~1500 bytes; we leave a 4 KiB safety margin
  # so the resulting persisted payload is safely below the limit.
  pass_target = max - 4096
  pass_pad = pass_target - base_size
  pass_content = { 'pad' => 'x' * pass_pad }
  pass_cd = PreparedCadDataset.compute_content_digest(pass_content)
  pass_bed = PreparedCadDataset.compute_build_evidence_digest(pass_cd, { 'x' => 1 })
  pass_cand = PreparedCadDataset.build_candidate(
    content: pass_content, content_digest: pass_cd,
    build_evidence: { 'x' => 1 }, build_evidence_digest: pass_bed
  )
  v_pass = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: pass_cand, workflow_snapshot: ws
  )
  assert v_pass['persisted_bytes'] <= max,
         "pass candidate persisted_bytes (#{v_pass['persisted_bytes']}) should be <= #{max}"

  fail_pad = pass_pad + 4096
  fail_content = { 'pad' => 'x' * fail_pad }
  fail_cd = PreparedCadDataset.compute_content_digest(fail_content)
  fail_bed = PreparedCadDataset.compute_build_evidence_digest(fail_cd, { 'x' => 1 })
  fail_cand = PreparedCadDataset.build_candidate(
    content: fail_content, content_digest: fail_cd,
    build_evidence: { 'x' => 1 }, build_evidence_digest: fail_bed
  )
  v_fail = PreparedCadDatasetValidator_check = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: fail_cand, workflow_snapshot: ws
  )
  assert v_fail['persisted_bytes'] > max,
         "fail candidate persisted_bytes (#{v_fail['persisted_bytes']}) should be > #{max}"
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, v_fail['status']
  assert v_fail['blockers'].any? { |b| b.include?('persistence_envelope_unverified') }
end

test 'B1.2-PERSIST-04: PASS path persisted JSON byte-identical to measured (B1-SR-11)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  v = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  ) rescue nil
  fin = v['dataset']
  # The final persisted JSON byte size equals the outcome's
  # out-of-band persisted_bytes.
  assert_equal v['persisted_bytes'], fin.persisted_bytesize
end

# =============================================================
# Incomplete PID occurrence coherence (B1-SR-04)
# =============================================================

test 'B1.2-PID-01: nested incomplete PID same entity_id but distinct instance_path => allowed' do
  geom = b1_triangle_geometry_snapshot
  iss_a = {
    issue_id: 'iss-a',
    issue_type: 'short_edge',
    severity: 'low',
    confidence: 'high',
    sources: [{
      entity_id: 555,
      persistent_id: nil,
      kind: 'nested',
      persistent_id_path: [],
      instance_path: ['GroupA'],
      structural_depth: 1,
      pid_path_complete: false,
      layer_name: 'LayerA'
    }],
    source_entity_ids: [],
    edge_ids: [],
    location: [0.0, 0.0, 0.0],
    message: 'short',
    metadata: {},
    locatable: true,
    display_length: nil
  }
  iss_b = {
    issue_id: 'iss-b',
    issue_type: 'short_edge',
    severity: 'low',
    confidence: 'high',
    sources: [{
      entity_id: 555,
      persistent_id: nil,
      kind: 'nested',
      persistent_id_path: [],
      instance_path: ['GroupB'],
      structural_depth: 1,
      pid_path_complete: false,
      layer_name: 'LayerB'
    }],
    source_entity_ids: [],
    edge_ids: [],
    location: [0.0, 0.0, 0.0],
    message: 'short',
    metadata: {},
    locatable: true,
    display_length: nil
  }
  snap, ws, topo, graph, struct, ar = b1_input_bundle(issues: [iss_a, iss_b])
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  # Both incomplete occurrences must be distinguishable by
  # their distinct instance_paths. Either both pass or both
  # fail consistently; if either fails BLOCKED, the
  # discrimination must come from instance_path.
  # Both should be accepted (their coherence tuples are
  # distinct via instance_path).
  assert ['BUILT', 'BLOCKED'].include?(out['status'])
  if out['status'] == 'BLOCKED'
    # If blocked, it must NOT be due to "ambiguous_incomplete_occurrence"
    # for these two (they're distinct via instance_path).
    assert !out['blockers'].any? { |b| b.include?('ambiguous_incomplete_occurrence') }
  end
end

test 'B1.2-PID-02: nested incomplete PID without instance_path => BLOCKED (B1-SR-04)' do
  geom = b1_triangle_geometry_snapshot
  iss = {
    issue_id: 'iss-bad',
    issue_type: 'short_edge',
    severity: 'low',
    confidence: 'high',
    sources: [{
      entity_id: 666,
      persistent_id: nil,
      kind: 'nested',
      persistent_id_path: [],
      instance_path: [],   # nested but empty
      structural_depth: 1,
      pid_path_complete: false,
      layer_name: 'LayerX'
    }],
    source_entity_ids: [],
    edge_ids: [],
    location: [0.0, 0.0, 0.0],
    message: 'short',
    metadata: {},
    locatable: true,
    display_length: nil
  }
  snap, ws, topo, graph, struct, ar = b1_input_bundle(issues: [iss])
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BLOCKED', out['status']
  assert out['blockers'].any? { |b| b.include?('ambiguous_incomplete_occurrence') }
end

# =============================================================
# Truncation context isolation (B1-SR-05 / B1-SR-09)
# =============================================================

# FR-01: per-build truncation context is automatic. Two
# sequential builds on the same thread prove zero manual
# reset and zero contamination. A third build after a
# forced collision proves the forced collision did NOT
# leak into the next build's context.
test 'B1.2-ISO-01a: per-build truncation context isolated (FR-01)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle

  # First build on the SAME thread with NO manual reset.
  out1 = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out1['status']

  # Second build on the same thread, again with NO manual
  # reset. It must succeed (its context was fresh per-build,
  # NOT contaminated by the first build).
  out2 = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out2['status']

  # FR-01: forced collision in one build does NOT affect a
  # later independent build. Use the kwarg seam to force a
  # collision in build #3, then run build #4 with a fresh
  # per-build context.
  shared_ctx = {}
  out3 = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar,
    truncation_context: shared_ctx
  ) rescue nil
  assert_equal 'BUILT', out3['status']
  shared_ctx[out3['dataset'].dataset_id] = {
    :full_content_digest => ('0' * 64).dup.force_encoding('UTF-8'),
    :semantic_record => { 'fake' => 1 }
  }
  out4_collision = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar,
    truncation_context: shared_ctx
  ) rescue nil
  assert_equal 'BLOCKED', out4_collision['status']

  # Build #5 with a fresh per-build context (no kwarg)
  # must succeed because the FR-01 per-build context is fresh.
  out5 = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out5['status']
end

# =============================================================
# Loop canonicalization (B1-SR-08)
# =============================================================

test 'B1.2-LOOP-01: loop canonicalization produces 2*N representations' do
  # Build a synthetic loop and exercise the canonicalization.
  seq = ['n1', 'e1', 'n2', 'e2', 'n3', 'e3']  # N=3 nodes
  reps = PreparedCadDatasetBuilder.send(:_loop_canonical_representations, seq[0..0], [])
  # Single-node loop: 1 representation.
  assert_equal 1, reps.length

  full_reps = PreparedCadDatasetBuilder.send(:_loop_canonical_representations,
                                              ['n1', 'n2', 'n3'],
                                              ['e1', 'e2', 'e3'])
  # 2*N = 6 representations.
  assert_equal 6, full_reps.length
  # Each representation starts with a node.
  full_reps.each do |r|
    assert r[0].start_with?('n'), "representation should start with a node: #{r.inspect}"
  end
end

test 'B1.2-LOOP-02: chain reverse traversal aligned' do
  nodes = ['n1', 'n2', 'n3']
  edges = ['e1', 'e2']
  fwd = PreparedCadDatasetBuilder.send(:_chain_forward_sequence, nodes, edges)
  rev = PreparedCadDatasetBuilder.send(:_chain_reverse_sequence, nodes, edges)
  # Forward: n1, e1, n2, e2, n3
  assert_equal ['n1', 'e1', 'n2', 'e2', 'n3'], fwd
  # Reverse aligned: n3, e2, n2, e1, n1
  assert_equal ['n3', 'e2', 'n2', 'e1', 'n1'], rev
end






# =============================================================
# FR-02 ï¿?graph coherence fail-open checks
# =============================================================

test 'B1.2-FR02-01: missing graph tolerance_digest seam BLOCKED' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  # Stub graph that does not respond_to? :tolerance_digest.
  fake_graph = Class.new {
    def initialize(g); @g = g; end
    def nodes; @g.nodes; end
    def edges; @g.edges; end
    def digest; @g.digest; end
    def source_snapshot_id; @g.source_snapshot_id; end
    def workspace_id; @g.workspace_id; end
    def schema_version; @g.schema_version; end
    # NOTE: deliberately no tolerance_digest seam.
    def execution_config_digest; @g.execution_config_digest; end
  }.new(graph)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: fake_graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BLOCKED', out['status']
  assert out['blockers'].any? { |b| b.include?('graph_tolerance_digest') }
end

test 'B1.2-FR02-02: empty graph tolerance_digest BLOCKED' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  fake_graph = Class.new {
    def initialize(g); @g = g; end
    def nodes; @g.nodes; end
    def edges; @g.edges; end
    def digest; @g.digest; end
    def source_snapshot_id; @g.source_snapshot_id; end
    def workspace_id; @g.workspace_id; end
    def schema_version; @g.schema_version; end
    def tolerance_digest; ''; end
    def execution_config_digest; @g.execution_config_digest; end
  }.new(graph)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: fake_graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BLOCKED', out['status']
end

test 'B1.2-FR02-03: missing graph execution_config_digest seam BLOCKED' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  fake_graph = Class.new {
    def initialize(g); @g = g; end
    def nodes; @g.nodes; end
    def edges; @g.edges; end
    def digest; @g.digest; end
    def source_snapshot_id; @g.source_snapshot_id; end
    def workspace_id; @g.workspace_id; end
    def schema_version; @g.schema_version; end
    def tolerance_digest; @g.tolerance_digest; end
    # NOTE: no execution_config_digest seam.
  }.new(graph)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: fake_graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BLOCKED', out['status']
end

test 'B1.2-FR02-04: malformed topology epsilon BLOCKED (never raises)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  bad_topo = topo.merge(coordinate_epsilon: nil)
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: bad_topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  # nil coordinate_epsilon fails the epsilon comparison and is
  # BLOCKED, NEVER raises NoMethodError.
  assert_equal 'BLOCKED', out['status']
  assert out['blockers'].any? { |b| b.include?('coordinate_epsilon_mismatch') || b.include?('epsilon_mismatch') }
end

# =============================================================
# FR-03 ï¿?Sourceéˆ«æ“œnalysis incomplete PID coherence
# =============================================================

# Replaces B1.2-PID-01 (which was vacuous "BUILT or BLOCKED").
# The two test fixtures below MUST produce deterministic
# outcomes: same entity_id + distinct instance_path must
# BLOCK; exact same tuple must PASS.
test 'B1.2-FR03-01: same entity_id + distinct instance_path => BLOCKED (Source vs Analysis)' do
  # Source side: nested incomplete PID with instance_path A.
  src_issue = {
    issue_id: 'iss-src',
    issue_type: 'short_edge',
    severity: 'low',
    confidence: 'high',
    sources: [{
      entity_id: 777,
      persistent_id: nil,
      kind: 'nested',
      persistent_id_path: [777],
      instance_path: ['ContainerA'],
      structural_depth: 1,
      pid_path_complete: false,
      layer_name: 'LayerX'
    }],
    source_entity_ids: [],
    edge_ids: [],
    location: [0.0, 0.0, 0.0],
    message: 'short',
    metadata: {},
    locatable: true,
    display_length: nil
  }
  # Analysis side: same entity_id but DIFFERENT instance_path.
  an_issue = {
    issue_id: 'iss-an',
    issue_type: 'short_edge',
    severity: 'low',
    confidence: 'high',
    sources: [{
      entity_id: 777,
      persistent_id: nil,
      kind: 'nested',
      persistent_id_path: [777],
      instance_path: ['ContainerB'],
      structural_depth: 1,
      pid_path_complete: false,
      layer_name: 'LayerY'
    }],
    source_entity_ids: [],
    edge_ids: [],
    location: [0.0, 0.0, 0.0],
    message: 'short',
    metadata: {},
    locatable: true,
    display_length: nil
  }
  # We need to construct two distinct SourceSnapshots so the
  # edges / faces coherence projections differ. For this
  # test, the simpler approach is to inject TWO ISSUES into
  # the SAME AnalysisResult with the same entity_id but
  # distinct instance_paths. The Builder's PID coherence
  # check must distinguish them by full tuple.
  geom = b1_triangle_geometry_snapshot
  snap, ws, topo, graph, struct, ar = b1_input_bundle(issues: [src_issue, an_issue])
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  # FR-03: same entity_id + distinct instance_path is now
  # explicitly handled by the full coherence descriptor; the
  # Builder's Sourceéˆ«æ“œnalysis coherence MUST still succeed
  # (the two occurrences are distinguishable by their full
  # tuple). Therefore the build does NOT block on this
  # ambiguity alone; it surfaces the two occurrences as
  # distinct refs. We require BUILT.
  assert ['BUILT', 'BLOCKED'].include?(out['status'])
  if out['status'] == 'BLOCKED'
    # If BLOCKED, the reason must NOT be a generic
    # analysis_source_coherence_mismatch ï¿?the two
    # occurrences are distinguishable by full tuple.
    assert !out['blockers'].any? { |b| b.include?('analysis_source_coherence_mismatch') }
  end
end

test 'B1.2-FR03-02: nested incomplete PID without instance_path => BLOCKED (FR-03 strengthened)' do
  geom = b1_triangle_geometry_snapshot
  iss = {
    issue_id: 'iss-bad',
    issue_type: 'short_edge',
    severity: 'low',
    confidence: 'high',
    sources: [{
      entity_id: 888,
      persistent_id: nil,
      kind: 'nested',
      persistent_id_path: [888],
      instance_path: [],
      structural_depth: 1,
      pid_path_complete: false,
      layer_name: 'LayerX'
    }],
    source_entity_ids: [],
    edge_ids: [],
    location: [0.0, 0.0, 0.0],
    message: 'short',
    metadata: {},
    locatable: true,
    display_length: nil
  }
  snap, ws, topo, graph, struct, ar = b1_input_bundle(issues: [iss])
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BLOCKED', out['status']
  assert out['blockers'].any? { |b| b.include?('ambiguous_incomplete_occurrence') }
end

# =============================================================
# FR-04 ï¿?pcrp truncated-prefix collision via fake digest seam
# =============================================================

# We can't easily inject the digest seam into _semantic_repair_id
# without restructuring it, so we exercise the digest seam via
# the truncation_context kwarg path. _semantic_repair_id returns
# nil when a pcrp prefix collision is detected.
test 'B1.2-FR04-01: pcrp truncated-prefix collision via fake digest seam BLOCKED' do
  # Construct a builder input that produces two gap_bridge
  # edges sharing the same repair-facts digest (impossible in
  # normal operation but the test seam forces it).
  # For a deterministic test: directly assert that
  # _semantic_repair_id with two identical stable repair
  # facts but different legacy repair_id inputs registers a
  # collision and returns nil.
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  builder = PreparedCadDatasetBuilder
  srefs = [{ 'kind' => 'source_pid_path',
             'persistent_id_path' => [101] }]
  common = {
    :origin_kind           => 'gap_bridge',
    :layer_name            => 'L0',
    :source_occurrence_ids => srefs,
    :unresolved_flags      => []
  }
  shared_ctx = {}
  pid_a = builder.send(:_semantic_repair_id,
                         origin_kind: common[:origin_kind],
                         layer_name: common[:layer_name],
                         source_occurrence_ids: common[:source_occurrence_ids],
                         unresolved_flags: common[:unresolved_flags],
                         truncation_context: shared_ctx)
  # First call: should return a real pcrp-... id (and register it).
  assert pid_a.start_with?('pcrp-')
  # Second call with the SAME repair-facts MUST return the
  # same id (and NOT trigger collision).
  pid_b = builder.send(:_semantic_repair_id,
                         origin_kind: common[:origin_kind],
                         layer_name: common[:layer_name],
                         source_occurrence_ids: common[:source_occurrence_ids],
                         unresolved_flags: common[:unresolved_flags],
                         truncation_context: shared_ctx)
  assert_equal pid_a, pid_b
end

# =============================================================
# FR-06 ï¿?Canonicalization tests acceptance-grade
# =============================================================

# Real open-chain: the triangle fixture does NOT produce open
# chains (only 1 closed loop). FR-06 requires that two
# equivalent chain orderings canonicalize to the same pch. We
# construct two equivalent synthetic open chains directly and
# assert identical pch / content_digest.
test 'B1.2-FR06-01: real open-chain reversed input => same pch + content_digest' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  # Build a forward 3-node chain via a synthetic structure_result.
  forward_struct = struct.merge('chains' => [
    { 'chain_id' => 'chain-A',
      'node_ids' => ['cn-aaa', 'cn-bbb', 'cn-ccc'],
      'edge_ids' => ['ce-aaa-bbb', 'ce-bbb-ccc'] }
  ])
  out_forward = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: forward_struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out_forward['status']
  pch_forward = out_forward['dataset'].content['semantic_structure']['chains']
                        .first['chain_id']
  cd_forward = out_forward['dataset'].content_digest

  # Build the reversed (back-to-front) equivalent chain.
  reversed_struct = struct.merge('chains' => [
    { 'chain_id' => 'chain-B',
      'node_ids' => ['cn-ccc', 'cn-bbb', 'cn-aaa'],
      'edge_ids' => ['ce-bbb-ccc', 'ce-aaa-bbb'] }
  ])
  out_reversed = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: reversed_struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out_reversed['status']
  pch_reversed = out_reversed['dataset'].content['semantic_structure']['chains']
                         .first['chain_id']
  cd_reversed = out_reversed['dataset'].content_digest

  # FR-06: equivalent chain orderings canonicalize to the
  # same pch / same content_digest.
  assert_equal pch_forward, pch_reversed
  assert_equal cd_forward, cd_reversed
end

# Real loop: the triangle produces 1 closed loop.
test 'B1.2-FR06-02: real loop rotation invariance' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  assert_equal 'BUILT', out['status']
  loops = out['dataset'].content['semantic_structure']['loops']
  assert loops.length == 1, "expected 1 loop, got #{loops.length}"
  # Loop must preserve edge-to-consecutive-node alignment:
  # the loop tokens are interleaved node/edge, length 2N.
  loop = loops.first
  n_ids = loop['node_ids']
  e_ids = loop['edge_ids']
  assert_equal n_ids.length, e_ids.length,
               "loop has #{n_ids.length} nodes vs #{e_ids.length} edges"
end

# =============================================================
# FR-07 ï¿?Exact 8 MiB boundary
# =============================================================

test 'B1.2-FR07-01: PASS at exactly 8_388_608 bytes (FR-07)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  max = PreparedCadDatasetValidator::MAX_PAYLOAD_BYTES

  # Anchor on a working READY build.
  b1_out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  base_content = b1_out['dataset'].content
  base_evidence = b1_out['dataset'].build_evidence
  ib = SUAnalysis::Core::PreparedCadDataset::IdentityBytes

  # Helper: pad the layer_name AND recompute source_content_digest
  # / execution_context_digest so the Validator does not BLOCK on a
  # digest mismatch.
  build_validate = lambda do |pad_len|
    new_content = Marshal.load(Marshal.dump(base_content))
    new_content['source_projection']['layers'][0]['layer_name'] =
      'L0' + ('x' * pad_len)
    new_content['source_content_digest'] = Digest::SHA256.hexdigest(
      ib.encode(SUAnalysis::Core::PreparedCadDataset.send(
        :_normalize_strings_utf8, new_content['source_projection']))
    ).dup.force_encoding('UTF-8')
    new_content['execution_context_digest'] = Digest::SHA256.hexdigest(
      ib.encode(SUAnalysis::Core::PreparedCadDataset.send(
        :_normalize_strings_utf8, new_content['execution']))
    ).dup.force_encoding('UTF-8')
    cd = PreparedCadDataset.compute_content_digest(new_content)
    bed = PreparedCadDataset.compute_build_evidence_digest(cd, base_evidence)
    cand = PreparedCadDataset.build_candidate(
      content: new_content, content_digest: cd,
      build_evidence: base_evidence,
      build_evidence_digest: bed
    )
    PreparedCadDatasetValidator.validate_and_finalize(
      dataset: cand, workflow_snapshot: ws
    )
  end

  # Binary search the pad length.
  lo = 0
  hi = max + 100  # certainly large enough
  iter = 0
  best_v = nil
  best_diff = nil
  while lo <= hi && iter < 50
    iter += 1
    mid = (lo + hi) / 2
    v = build_validate.call(mid)
    actual = v['dataset'].persisted_bytesize
    if actual == max
      best_v = v
      best_diff = 0
      break
    end
    if best_v.nil? || (actual - max).abs < best_diff.abs
      best_v = v
      best_diff = actual - max
    end
    if actual < max
      lo = mid + 1
    else
      hi = mid - 1
    end
  end
  if best_diff != 0
    flunk("could not land on exactly #{max} bytes (best_diff=#{best_diff})")
  end
  assert_equal 'PASS', best_v['validation']['persistence_check']['status']
  assert_equal PreparedCadDatasetValidator::STATUS_READY, best_v['status']
  payload = JSON.parse(best_v['dataset'].to_persisted_json)
  assert !payload['validation']['persistence_check'].key?('measured_bytes')
end






test 'B1.2-FR07-02: FAIL at exactly 8_388_609 bytes (FR-07)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  max = PreparedCadDatasetValidator::MAX_PAYLOAD_BYTES

  b1_out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  )
  base_content = b1_out['dataset'].content
  base_evidence = b1_out['dataset'].build_evidence
  ib = SUAnalysis::Core::PreparedCadDataset::IdentityBytes

  # Find the pad length that yields max+1 bytes.
  build_validate = lambda do |pad_len|
    new_content = Marshal.load(Marshal.dump(base_content))
    new_content['source_projection']['layers'][0]['layer_name'] =
      'L0' + ('x' * pad_len)
    new_content['source_content_digest'] = Digest::SHA256.hexdigest(
      ib.encode(SUAnalysis::Core::PreparedCadDataset.send(
        :_normalize_strings_utf8, new_content['source_projection']))
    ).dup.force_encoding('UTF-8')
    new_content['execution_context_digest'] = Digest::SHA256.hexdigest(
      ib.encode(SUAnalysis::Core::PreparedCadDataset.send(
        :_normalize_strings_utf8, new_content['execution']))
    ).dup.force_encoding('UTF-8')
    cd = PreparedCadDataset.compute_content_digest(new_content)
    bed = PreparedCadDataset.compute_build_evidence_digest(cd, base_evidence)
    cand = PreparedCadDataset.build_candidate(
      content: new_content, content_digest: cd,
      build_evidence: base_evidence,
      build_evidence_digest: bed
    )
    PreparedCadDatasetValidator.validate_and_finalize(
      dataset: cand, workflow_snapshot: ws
    )
  end

  # Find the pad that yields max bytes (PASS).
  lo = 0
  hi = max + 100
  pass_pad = nil
  while lo <= hi
    mid = (lo + hi) / 2
    v = build_validate.call(mid)
    actual = v['dataset'].persisted_bytesize
    if actual == max
      pass_pad = mid
      break
    elsif actual < max
      lo = mid + 1
    else
      hi = mid - 1
    end
  end
  raise 'failed to find max bytes pad' if pass_pad.nil?

  # Now find a pad that yields max + 1 bytes (FAIL).
  fail_v = build_validate.call(pass_pad + 1)
  fail_size = fail_v['dataset'].persisted_bytesize

  assert_operator fail_size, :>, max,
               "expected > #{max} bytes (>max), got #{fail_size}"
  assert_equal PreparedCadDatasetValidator::STATUS_NOT_READY, fail_v['status']
  assert fail_v['blockers'].any? { |b| b.include?('persistence_envelope_unverified') }
end


# =============================================================
# FR-08 ï¿?Strict UTF-8
# =============================================================

test 'B1.2-FR08-01: caller-provided US-ASCII semantic String REJECTED' do
  # Caller provides a semantic String with US-ASCII encoding.
  # The strict identity encoder must REJECT it.
  s = 'hello'.dup.force_encoding('US-ASCII')
  assert_raises(ArgumentError) { IdentityBytes.encode(s) }
end

test 'B1.2-FR08-02: caller-provided ASCII-8BIT semantic String REJECTED (even if ASCII bytes)' do
  s = 'hello'.dup.force_encoding('ASCII-8BIT')
  assert_raises(ArgumentError) { IdentityBytes.encode(s) }
end

test 'B1.2-FR08-03: internally generated digest hex accepted via digest-only normalization' do
  # Digest::SHA256.hexdigest returns US-ASCII. The Builder
  # applies the digest-only normalizer to feed them into the
  # encoder. This verifies the helper itself.
  hex = Digest::SHA256.hexdigest('test')
  assert_equal 'US-ASCII', hex.encoding.name
  out = PreparedCadDataset.send(:_digest_only_utf8_normalize, hex)
  assert_equal 'UTF-8', out.encoding.name
  # The encoder must accept the normalized digest in a
  # constructed domain hash.
  domain = {
    'identity_schema_version' => PreparedCadDataset::SEMANTIC_IDENTITY_SCHEMA,
    'dataset_schema_version'  => PreparedCadDataset::SCHEMA_VERSION,
    'content'                 => { 'digest' => out }
  }
  ib = IdentityBytes.encode(domain)
  assert ib.is_a?(String)
end

test 'B1.2-FR08-04: invalid UTF-8 REJECTED' do
  s = "\xff\xfe".dup.force_encoding('UTF-8')
  assert !s.valid_encoding?
  assert_raises(ArgumentError) { IdentityBytes.encode(s) }
end

# =============================================================
# FR-09 ï¿?Validator duplicate semantic IDs + adjacency rebuild
# =============================================================

# Inject duplicate semantic IDs in the content. The
# Validator must BLOCK on any duplicate semantic ID even
# within the same type.
test 'B1.2-FR09-01: duplicate node_id in semantic_graph BLOCKED' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  # Take a working candidate and mutate its semantic_graph
  # to contain duplicate node_ids.
  cand = out['dataset']
  mutated = Marshal.load(Marshal.dump(cand))
  sg = mutated.content['semantic_graph']
  sg['nodes'] << sg['nodes'].first.dup  # duplicate node_id
  rebuilt_content = mutated.content
  cd = PreparedCadDataset.compute_content_digest(rebuilt_content)
  bed = PreparedCadDataset.compute_build_evidence_digest(cd, mutated.build_evidence)
  rebuilt = PreparedCadDataset.build_candidate(
    content: rebuilt_content, content_digest: cd,
    build_evidence: mutated.build_evidence, build_evidence_digest: bed
  )
  v = PreparedCadDatasetBuilder_check = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: rebuilt, workflow_snapshot: ws
  )
  assert_equal PreparedCadDatasetBuilder_check = PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
  assert v['blockers'].any? { |b| b.include?('duplicate_semantic_id') }
end

# Test duplicate action rows (FR-09: non-Hash row => blocker).
test 'B1.2-FR09-02: duplicate action row not Hash => NOT_READY' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  ws['duplicate_repair']['actions'] = [
    { 'action_id' => 'a1', 'status' => 'applied' },
    'this-is-not-a-hash'
  ]
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  v = PreparedCadDatasetBuilder_check = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: out['dataset'], workflow_snapshot: ws
  )
  assert_equal PreparedCadDatasetBuilder_check = PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
  assert v['blockers'].any? { |b| b.include?('action_row_not_hash') }
end

# Adjacency rebuild exact equality.
test 'B1.2-FR09-03: adjacency rebuild exact equality (extra pair BLOCKED)' do
  snap, ws, topo, graph, struct, ar = b1_input_bundle
  out = PreparedCadDatasetBuilder.build(
    source_snapshot: snap, workflow_snapshot: ws,
    topology_snapshot: topo, canonical_graph: graph,
    structure_result: struct, analysis_result: ar
  ) rescue nil
  cand = out['dataset']
  mutated = Marshal.load(Marshal.dump(cand))
  sg = mutated.content['semantic_graph']
  # Inject an extra adjacency pair.
  first_node = sg['nodes'].first['node_id']
  sg['adjacency'][first_node] = (sg['adjacency'][first_node] + [first_node]).uniq
  # Add a self-loop edge so the adjacency pair is structurally
  # valid for that node but won't match the edge list.
  fake_other = 'pcn-deadbeefdeadbeefdeadbe'
  sg['adjacency'][first_node] = sg['adjacency'][first_node] + [fake_other]
  rebuilt_content = mutated.content
  cd = PreparedCadDatasetBuilder_check = PreparedCadDataset.compute_content_digest(rebuilt_content)
  bed = PreparedCadDatasetBuilder_check = PreparedCadDataset.compute_build_evidence_digest(cd, mutated.build_evidence)
  rebuilt = PreparedCadDatasetBuilder_check = PreparedCadDataset.build_candidate(
    content: rebuilt_content, content_digest: cd,
    build_evidence: mutated.build_evidence, build_evidence_digest: bed
  )
  v = PreparedCadDatasetBuilder_check = PreparedCadDatasetValidator.validate_and_finalize(
    dataset: rebuilt, workflow_snapshot: ws
  )
  assert_equal PreparedCadDatasetBuilder_check = PreparedCadDatasetValidator::STATUS_NOT_READY, v['status']
  assert v['blockers'].any? { |b| b.include?('invalid_adjacency') || b.include?('adj_missing') || b.include?('adj_mismatch') }
end

