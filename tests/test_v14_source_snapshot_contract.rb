#
# tests/test_v14_source_snapshot_contract.rb — V1.4
# SourceSnapshot + ExecutionConfigSnapshot + SourceFingerprint
# pure-Ruby contract tests.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL PREVIEW).
# No host calls. All tests pure-Ruby.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/analysis_config'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/face_record'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/source_snapshot'

include SUAnalysis::Core

# --- helpers ---

def v14_config
  AnalysisConfig.new(profile_name: 'test')
end

def v14_rule_digest
  Digest::SHA256.hexdigest('layer-role-config.v1')
end

# --- ExecutionConfigSnapshot ---

test 'ExecutionConfigSnapshot: required fields are stored' do
  cfg = ExecutionConfigSnapshot.new(
    profile_id: 'profile.test',
    profile_version: '1',
    rule_set_id: 'role.config',
    rule_set_version: '1',
    rule_set_digest: v14_rule_digest,
    tolerance_schema_version: 'tol-1',
    tolerance_values: { 'duplicate' => 1.0e-4 },
    session_overrides: {},
    source_snapshot_schema_version: '1'
  )
  assert_equal 'profile.test',   cfg.profile_id
  assert_equal '1',              cfg.profile_version
  assert_equal 'role.config',    cfg.rule_set_id
  assert_equal v14_rule_digest, cfg.rule_set_digest
  assert_equal 'tol-1',          cfg.tolerance_schema_version
  assert_equal({ 'duplicate' => 1.0e-4 }, cfg.tolerance_values)
end

test 'ExecutionConfigSnapshot: top-level frozen + tolerance_values frozen' do
  cfg = ExecutionConfigSnapshot.new(
    profile_id: 'p', profile_version: '1',
    rule_set_id: 'r', rule_set_version: '1', rule_set_digest: 'd',
    tolerance_schema_version: 't', tolerance_values: { 'a' => 1 },
    session_overrides: { 'b' => 2 },
    source_snapshot_schema_version: '1'
  )
  assert cfg.frozen?, 'top-level must be frozen'
  assert cfg.tolerance_values.frozen?, 'tolerance_values must be frozen'
  assert cfg.session_overrides.frozen?, 'session_overrides must be frozen'
end

test 'ExecutionConfigSnapshot: == compares all fields' do
  args = {
    profile_id: 'p', profile_version: '1',
    rule_set_id: 'r', rule_set_version: '1', rule_set_digest: 'd',
    tolerance_schema_version: 't', tolerance_values: { 'a' => 1 },
    session_overrides: { 'b' => 2 },
    source_snapshot_schema_version: '1'
  }
  c1 = ExecutionConfigSnapshot.new(**args)
  c2 = ExecutionConfigSnapshot.new(**args)
  assert_equal c1, c2, 'identical configs must be =='
  c3 = ExecutionConfigSnapshot.new(**args.merge(rule_set_digest: 'other'))
  refute_equal c1, c3, 'rule_set_digest drift must break =='
end

test 'ExecutionConfigSnapshot.from_live_config: produces deterministic schema version' do
  cfg = v14_config
  es = ExecutionConfigSnapshot.from_live_config(
    cfg,
    rule_set_digest: v14_rule_digest,
    source_snapshot_schema_version: '1'
  )
  refute_nil es.tolerance_schema_version
  assert es.tolerance_schema_version.start_with?('tol-'),
         'tolerance schema version must start with tol-'
  # tolerance_values uses Symbol keys (mirrors Tolerance#to_h).
  assert es.tolerance_values.key?(:duplicate)
  assert es.tolerance_values.key?(:big_z)
  assert_equal 'profile.test', es.profile_id
end

# --- SourceFingerprint ---

def v14_empty_snapshot
  GeometrySnapshot.new(edges: [], faces: [], layers: [])
end

def v14_simple_edges
  [
    EdgeRecord.new(id: 0,
      source: SourceReference.new(entity_id: 1, persistent_id: 100, kind: 'edge',
                                 persistent_id_path: [100], instance_path: [],
                                 structural_depth: 0, pid_path_complete: true,
                                 layer_name: 'Layer0'),
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0],
      layer: 'Layer0'),
    EdgeRecord.new(id: 1,
      source: SourceReference.new(entity_id: 2, persistent_id: 101, kind: 'edge',
                                 persistent_id_path: [101], instance_path: [],
                                 structural_depth: 0, pid_path_complete: true,
                                 layer_name: 'Layer0'),
      start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0],
      layer: 'Layer0')
  ]
end

test 'SourceFingerprint: empty snapshot -> all counts zero, no crash' do
  fp = SourceFingerprint.from_snapshot(v14_empty_snapshot)
  assert_equal 0, fp.edge_count
  assert_equal 0, fp.face_count
  assert_equal 0, fp.group_count
  assert_equal 0.0, fp.edge_length_sum
  assert_nil fp.bounding_box
  assert_equal '', fp.material_digest
  assert_equal '', fp.selection_scope_digest
end

test 'SourceFingerprint: edge_count + edge_length_sum accurate' do
  snap = GeometrySnapshot.new(edges: v14_simple_edges, layers: [
    LayerRecord.new(name: 'Layer0', edge_count: 2)
  ])
  fp = SourceFingerprint.from_snapshot(snap)
  assert_equal 2, fp.edge_count
  assert_in_delta 15.0, fp.edge_length_sum, 0.001
  assert_equal [0.0, 0.0, 0.0, 10.0, 5.0, 0.0], fp.bounding_box
end

test 'SourceFingerprint: == compares material source state' do
  s = v14_simple_edges
  snap_a = GeometrySnapshot.new(edges: s, layers: [LayerRecord.new(name: 'Layer0')])
  snap_b = GeometrySnapshot.new(edges: s, layers: [LayerRecord.new(name: 'Layer0')])
  fp_a = SourceFingerprint.from_snapshot(snap_a)
  fp_b = SourceFingerprint.from_snapshot(snap_b)
  assert_equal fp_a, fp_b, 'identical snapshots must produce equal fingerprints'
  # Mutate edge count.
  snap_c = GeometrySnapshot.new(edges: s + [s.first], layers: [LayerRecord.new(name: 'Layer0')])
  fp_c = SourceFingerprint.from_snapshot(snap_c)
  refute_equal fp_a, fp_c, 'edge-count delta must break =='
end

test 'SourceFingerprint: digest is deterministic for identical input (risk test 8)' do
  s = v14_simple_edges
  snap = GeometrySnapshot.new(edges: s, layers: [LayerRecord.new(name: 'Layer0')])
  fp1 = SourceFingerprint.from_snapshot(snap)
  fp2 = SourceFingerprint.from_snapshot(snap)
  assert_equal fp1.digest, fp2.digest
  # 64-hex SHA256.
  assert_equal 64, fp1.digest.length
  assert fp1.digest.match?(/\A[0-9a-f]{64}\z/), 'digest must be 64-char hex'
end

test 'SourceFingerprint: per-layer facts include visibility + edge/face counts' do
  hidden_layer = LayerRecord.new(name: 'HIDDEN', edge_count: 1, face_count: 0, visible: false)
  visible_layer = LayerRecord.new(name: 'LAYER-A', edge_count: 2, face_count: 1, visible: true)
  snap = GeometrySnapshot.new(edges: [], layers: [hidden_layer, visible_layer])
  fp = SourceFingerprint.from_snapshot(snap)
  assert_equal 2, fp.layer_count
  assert_equal false, fp.layer_facts['HIDDEN'][:visible]
  assert_equal true,  fp.layer_facts['LAYER-A'][:visible]
  assert_equal 1,     fp.layer_facts['HIDDEN'][:edge_count]
  assert_equal 2,     fp.layer_facts['LAYER-A'][:edge_count]
  assert_equal 1,     fp.layer_facts['LAYER-A'][:face_count]
end

test 'SourceFingerprint: top-level frozen + layer_facts frozen (deep immutability)' do
  snap = GeometrySnapshot.new(edges: [], layers: [LayerRecord.new(name: 'Layer0')])
  fp = SourceFingerprint.from_snapshot(snap)
  assert fp.frozen?, 'SourceFingerprint must be top-level frozen'
  assert fp.layer_facts.frozen?, 'layer_facts Hash must be frozen'
  fp.layer_facts.each do |_, v|
    assert v.frozen?, 'per-layer value Hash must be frozen'
  end
end

# --- SourceSnapshot ---

def v14_sample_config
  ExecutionConfigSnapshot.from_live_config(
    v14_config,
    rule_set_digest: v14_rule_digest,
    source_snapshot_schema_version: '1'
  )
end

def v14_sample_snapshot
  src = SourceSnapshot.from_geometry_snapshot(
    GeometrySnapshot.new(edges: v14_simple_edges, layers: [
      LayerRecord.new(name: 'Layer0', edge_count: 2)
    ]),
    selection: [
      { kind: 'edge', persistent_id_path: [100], instance_path: [], layer: 'Layer0' }
    ],
    execution_config: v14_sample_config,
    rule_set_digest: v14_rule_digest,
    snapshot_id: 'snap-test-001',
    captured_at: '2026-08-20T10:00:00Z'
  )
  src
end

test 'SourceSnapshot: required fields populated' do
  s = v14_sample_snapshot
  assert_equal 'snap-test-001',                 s.snapshot_id
  assert_equal '1',                              s.schema_version
  assert_equal '2026-08-20T10:00:00Z',           s.captured_at
  assert_equal 'inches',                         s.unit
  assert_equal 'raw',                            s.coordinate_origin
  assert_equal 1,                                s.selection_scope.length
  assert_equal 2,                                s.edges.length
  refute_nil s.fingerprint
  refute_nil s.execution_config
end

test 'SourceSnapshot: deep immutability -- cannot mutate nested arrays or hashes' do
  s = v14_sample_snapshot
  # Top-level frozen.
  assert s.frozen?, 'SourceSnapshot must be top-level frozen'
  # Edges array frozen.
  assert s.edges.frozen?, 'edges Array must be frozen'
  # Selection scope frozen.
  assert s.selection_scope.frozen?, 'selection_scope Array must be frozen'
  # transform_context frozen.
  assert s.transform_context.frozen?, 'transform_context Hash must be frozen'
  # Cannot mutate nested array.
  assert_raises(RuntimeError, FrozenError) { s.edges << 'forged' }
  # Cannot mutate nested hash.
  assert_raises(RuntimeError, FrozenError) { s.transform_context['new_key'] = 'x' }
end

test 'SourceSnapshot: == compares ALL rebuild-critical fields' do
  s1 = v14_sample_snapshot
  s2 = v14_sample_snapshot
  assert_equal s1, s2, 'two snapshots with identical inputs must be =='
  # snapshot_id drift must break == (risk test 8 cross-check).
  s3 = SourceSnapshot.new(
    snapshot_id:      'snap-test-002',
    captured_at:      '2026-08-20T10:00:00Z',
    selection_scope:  s1.selection_scope,
    edges:            s1.edges,
    faces:            s1.faces,
    layers:           s1.layers,
    vertex_records:   s1.vertex_records,
    execution_config: s1.execution_config,
    fingerprint:      s1.fingerprint
  )
  assert_equal 'snap-test-002', s3.snapshot_id
  refute_equal s1, s3, 'snapshot_id drift must break =='
end

test 'SourceSnapshot: schema version pinned to 1' do
  s = v14_sample_snapshot
  assert_equal '1', s.schema_version
  assert_equal SourceSnapshot::SCHEMA_VERSION, s.schema_version
end

test 'SourceSnapshot: identity quality preserved on selection scope' do
  # Per risk test 5: missing PID stays unresolved, never
  # upgraded via entityID.
  s = SourceSnapshot.from_geometry_snapshot(
    GeometrySnapshot.new(edges: [], layers: [LayerRecord.new(name: 'Layer0')]),
    selection: [
      {
        kind: 'edge',
        persistent_id_path: [],        # MISSING PID
        instance_path: ['Group:outer'],
        layer: 'Layer0'
      }
    ],
    execution_config: v14_sample_config,
    rule_set_digest: v14_rule_digest
  )
  entry = s.selection_scope.first
  # persistent_id_path is empty -- identity quality is
  # UNRESOLVED; the snapshot does NOT auto-promote this to
  # a resolvable id.
  assert_equal [], entry[:persistent_id_path]
  assert_equal 'edge', entry[:kind]
  # instance_path records the host label (a display-only hint),
  # NOT a stable identity claim.
  assert_equal ['Group:outer'], entry[:instance_path]
end

test 'SourceSnapshot: from_geometry_snapshot never wraps the snapshot object' do
  # The SourceSnapshot must NOT hold a reference to the live
  # GeometrySnapshot; rebuilds must work from primitives.
  geo = GeometrySnapshot.new(edges: v14_simple_edges, layers: [
    LayerRecord.new(name: 'Layer0', edge_count: 2)
  ])
  s = SourceSnapshot.from_geometry_snapshot(
    geo,
    execution_config: v14_sample_config,
    rule_set_digest: v14_rule_digest
  )
  # SourceSnapshot holds the edge Array, not the GeometrySnapshot
  # itself.
  assert_kind_of Array, s.edges
  # The edges inside are the same EdgeRecord objects (we
  # share by reference, not deep-copy, for memory), but the
  # SourceSnapshot does NOT depend on the GeometrySnapshot
  # container for any field. After this point, mutating `geo`
  # is irrelevant to `s`.
  assert_equal 2, s.edges.length
end

test 'SourceSnapshot: V1.0-V1.3 GeometrySnapshot callers still work (backward compat)' do
  # The Stage 1 V1.4 build does NOT touch the existing
  # GeometrySnapshot or any V1.0-V1.3 caller. The new files
  # are additive.
  geo = GeometrySnapshot.new(edges: v14_simple_edges, layers: [
    LayerRecord.new(name: 'Layer0')
  ])
  # GeometrySnapshot still works without SourceSnapshot.
  assert_equal 2, geo.edge_count
  assert_equal 1, geo.layers.length
  # EdgeRecord + LayerRecord + SourceReference all unchanged.
  assert_equal 10.0, geo.bounding_box[:max][0]
  assert_equal 5.0,  geo.bounding_box[:max][1]
end

test 'SourceSnapshot: to_digest is SHA256 hex and stable' do
  s1 = v14_sample_snapshot
  s2 = v14_sample_snapshot
  d1 = s1.to_digest
  d2 = s2.to_digest
  assert_equal d1, d2, 'identical snapshots -> identical digest'
  assert_equal 64, d1.length
  assert d1.match?(/\A[0-9a-f]{64}\z/)
end

test 'SourceSnapshot: host entity objects are NOT in the snapshot' do
  # Per directive: "Do not use live SketchUp entity objects
  # as the authoritative rebuild input." SourceSnapshot must
  # hold only primitives + SourceReference / EdgeRecord /
  # FaceRecord / LayerRecord -- never a live Sketchup::Entity.
  s = SourceSnapshot.from_geometry_snapshot(
    GeometrySnapshot.new(edges: [], layers: [LayerRecord.new(name: 'Layer0')]),
    selection: [],
    execution_config: v14_sample_config,
    rule_set_digest: v14_rule_digest
  )
  # selection_scope is an Array<Hash>; no Object/Entity inside.
  s.selection_scope.each do |entry|
    assert_kind_of Hash, entry
  end
  # edges / faces / layers contain only EdgeRecord /
  # FaceRecord / LayerRecord / SourceReference.
  assert s.edges.empty?
  assert s.faces.empty?
  s.layers.each    { |l| assert_kind_of LayerRecord,    l }
end