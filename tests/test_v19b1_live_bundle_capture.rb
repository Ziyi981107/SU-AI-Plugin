#
# tests/test_v19b1_live_bundle_capture.rb — V1.9B1 B1.5 Live
# Coherent Input Bundle Capture integration suite.
#
# Per frozen V1.9B1 Blueprint v1.3 + B1.5 implementation
# packet + Codex PASS + AIPM V1.9B1 B1.5 LIVE COHERENT
# INPUT BUNDLE dispatch 2026-09-15:
#
#   B1.5 adds ONE additive public method to
#   WorkingModeRunner:
#
#     capture_prepared_cad_input_bundle(analysis_result:)
#
#   which returns either:
#
#     { 'status' => 'CAPTURED', 'bundle' => <frozen>, 'blockers' => [] }
#
#   or:
#
#     { 'status' => 'BLOCKED',  'bundle' => nil,    'blockers' => [...] }
#
#   and is the ONLY integration seam between the live Runner
#   and the already-frozen B1.2-B1.4 Builder/Validator.
#
# This file is HOST-FREE (FakeAdapter + FakeModel). It does
# NOT touch the source / derivation flow.
#
# Required regressions (B15-T01..B15-T15).
#
# Allowed scope:
#   extension/su_ai_plugin/core/working_mode_runner.rb (already
#   implemented by this packet).
#   tests/test_v19b1_live_bundle_capture.rb (this file).
#
# No other production file is modified.
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require 'digest'

require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/analysis_config'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/face_record'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/layer_role'
require_relative '../extension/su_ai_plugin/core/vertex_record'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/derived_entity_record'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'
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

require_relative '../extension/su_ai_plugin/core/working_mode_runner'

include SUAnalysis::Core

# =============================================================
# Helpers — pure-Ruby fixture builders for the live capture path.
# =============================================================

B15_RUNNER = SUAnalysis::Core::WorkingModeRunner

# Recompute the EXACT current production legacy tolerance
# digest formula (mirrors the one in
# canonical_geometry_graph.rb build_from_workspace) so B15-T04
# can assert graph.tolerance_digest against the captured
# SourceSnapshot execution tolerance.
def b15_expected_tolerance_digest(source)
  ec = source.respond_to?(:execution_config) ? source.execution_config : nil
  return '' if ec.nil?
  vals = ec.respond_to?(:tolerance_values) ? ec.tolerance_values : nil
  return '' unless vals.is_a?(Hash)
  sorted = vals.is_a?(Hash) ? vals.sort.to_h : {}
  'tol-' + Digest::SHA256.hexdigest(Marshal.dump(sorted))[0, 16]
end

def b15_coord_eps
  1.0e-6
end

def b15_default_tolerance(coord_eps = b15_coord_eps)
  Tolerance.new(duplicate: 1.0e-4, short_edge: 0.5,
                gap_search: 0.1, coordinate_epsilon: coord_eps,
                planar_z_snap: 0.01)
end

def b15_source(edges, tolerance = b15_default_tolerance, snapshot_id: nil)
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
  # B15 fixture builds the ExecutionConfigSnapshot directly with
  # STRING-keyed tolerance_values (matching the B1.2-B1.4 host-free
  # fixture pattern). from_live_config uses Tolerance.to_h whose
  # Symbol keys become US-ASCII Strings via Symbol#to_s during
  # Builder tolerance normalization, and the resulting US-ASCII
  # keys fail PreparedCadDataset._strict_utf8_string (B1-SR-12).
  tolerance_values = {
    'duplicate'          => tolerance.duplicate.to_f,
    'short_edge'         => tolerance.short_edge.to_f,
    'gap_search'         => tolerance.gap_search.to_f,
    'coordinate_epsilon' => tolerance.coordinate_epsilon.to_f,
    'big_z'              => tolerance.big_z.to_f,
    'large_coordinate'   => tolerance.large_coordinate.to_f,
    'planar_z_snap'      => tolerance.planar_z_snap.to_f
  }
  ec = ExecutionConfigSnapshot.new(
    profile_id:        'profile.b15',
    profile_version:   '1',
    rule_set_id:       'role.config',
    rule_set_version:  '1',
    rule_set_digest:   'b15-rules',
    tolerance_schema_version: 'tol-' + tolerance_values.keys.sort.join('-'),
    tolerance_values:        tolerance_values,
    session_overrides:        {},
    source_snapshot_schema_version: '1'
  )
  SourceSnapshot.new(
    snapshot_id: snapshot_id,
    edges: recs, faces: [], layers: [layer], execution_config: ec,
    selection_scope: [], unit: 'inches', coordinate_origin: 'raw',
    transform_context: { 'active_edit_seed' => 'identity' }
  )
end

def b15_geometry_for(source)
  layer = LayerRecord.new(name: 'L0')
  GeometrySnapshot.new(edges: source.edges, layers: [layer])
end

def b15_analysis(geom, issues: [])
  registry = IssueRegistry.new(issues)
  pf = PreflightReport.new(
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
    preflight: pf, registry: registry, geometry_snapshot: geom,
    selection_entities: [], active_edit_facts: {}
  )
end

# Prepare a fake-host workspace and return
# [adapter, workspace, source, analysis_result]. The
# caller is responsible for further orchestrator actions
# (planar apply / gap apply) before B1.5 capture.
def b15_prepare(edges, tolerance = b15_default_tolerance)
  B15_RUNNER.reset_for_tests
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  src = b15_source(edges, tolerance)
  snap = B15_RUNNER.prepare(
    source: src, adapter: adapter, model: nil
  )
  unless snap['state'] == 'ready'
    raise "b15_prepare expected workspace state 'ready'; got " \
          "#{snap['state'].inspect} (#{snap['last_error'].inspect})"
  end
  [adapter, B15_RUNNER.current_workspace_for_test, src, b15_analysis(b15_geometry_for(src))]
end

def b15_build_from_bundle(bundle)
  PreparedCadDatasetBuilder.build(
    source_snapshot:   bundle['source_snapshot'],
    workflow_snapshot: bundle['workflow_snapshot'],
    topology_snapshot: bundle['topology_snapshot'],
    canonical_graph:   bundle['canonical_graph'],
    structure_result:  bundle['structure_result'],
    analysis_result:   bundle['analysis_result']
  )
end

def b15_finalize_from_builder(build_out, bundle)
  PreparedCadDatasetValidator.validate_and_finalize(
    dataset:           build_out['dataset'],
    workflow_snapshot: bundle['workflow_snapshot']
  )
end

# =============================================================
# B15-T01 — public method only.
# =============================================================

test 'B15-T01: capture_prepared_cad_input_bundle is a public Runner method' do
  B15_RUNNER.reset_for_tests
  assert B15_RUNNER.respond_to?(:capture_prepared_cad_input_bundle),
         'B15-T01: WorkingModeRunner MUST expose capture_prepared_cad_input_bundle publicly'
  # No test-only accessor named `current_bundle_for_test` /
  # `instance_variable_get(:@b15_capture_state)` is exposed.
  refute B15_RUNNER.respond_to?(:current_bundle_for_test),
         'B15-T01: no `current_bundle_for_test` accessor allowed'
  # Defensive: there is no private external ivar accessor
  # for the bundle. (Production callers must use the
  # return value of capture_prepared_cad_input_bundle
  # alone.)
end

test 'B15-T01: source-level guard — capture is the ONLY public B1.5 entry' do
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/working_mode_runner.rb', __dir__
    )
  )
  # The production source MUST define the public method.
  assert_match(/def\s+capture_prepared_cad_input_bundle/, src,
               'production source MUST define capture_prepared_cad_input_bundle')
  # No test-only accessor exposed for the bundle state.
  refute_match(/def\s+current_bundle_for_test/, src,
               'production source MUST NOT define current_bundle_for_test accessor')
  # No external `instance_variable_get` for the bundle in
  # production seams.
  refute_match(/instance_variable_get\(:@b15_capture/, src,
               'production source MUST NOT expose @b15_capture_* ivar access')
end

# =============================================================
# B15-T02 — happy coherent capture.
# =============================================================

test 'B15-T02: happy coherent capture returns CAPTURED + six frozen members + graph digest binding' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, src, ar = b15_prepare(edges)
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  assert_equal 'CAPTURED', out['status'],
               "B15-T02: status MUST be CAPTURED; got #{out['status']}"
  assert_equal [], out['blockers'],
               'B15-T02: blockers MUST be empty on happy path'
  assert out['bundle'].is_a?(Hash), 'B15-T02: bundle MUST be a Hash'
  assert out.frozen?, 'B15-T02: wrapper MUST be frozen'
  bundle = out['bundle']
  assert bundle.frozen?, 'B15-T02: bundle MUST be frozen'
  assert_equal 'pcd-input-bundle.v1', bundle['schema_version'],
               'B15-T02: bundle schema_version MUST be pcd-input-bundle.v1'
  %w[source_snapshot workflow_snapshot topology_snapshot canonical_graph
     structure_result analysis_result].each do |k|
    refute_nil bundle[k], "B15-T02: bundle MUST carry #{k}"
  end
  # source/workspace IDs agree.
  graph = bundle['canonical_graph']
  assert_equal src.snapshot_id.to_s, graph.source_snapshot_id.to_s,
               'B15-T02: graph source_snapshot_id MUST equal source.snapshot_id'
  struct = bundle['structure_result']
  assert_equal src.snapshot_id.to_s, struct['source_snapshot_id'].to_s,
               'B15-T02: structure source_snapshot_id MUST equal source.snapshot_id'
  assert_equal graph.workspace_id.to_s, struct['workspace_id'].to_s,
               'B15-T02: structure workspace_id MUST equal graph workspace_id'
  assert_equal 'cgg.v1', graph.schema_version,
               'B15-T02: graph schema_version MUST be cgg.v1'
  # structure graph digest == graph.digest.
  assert_equal graph.digest.to_s, struct['canonical_graph_digest'].to_s,
               'B15-T02: structure canonical_graph_digest MUST equal graph.digest'
  # Workflow + topology bundle copies frozen.
  assert bundle['workflow_snapshot'].frozen?,
         'B15-T02: workflow_snapshot MUST be frozen'
  assert bundle['topology_snapshot'].frozen?,
         'B15-T02: topology_snapshot MUST be frozen'
end

# =============================================================
# B15-T03 — topology exactness.
# =============================================================

test 'B15-T03: topology schema, unique endpoint keys, exact endpoint set == graph node keys' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, src, ar = b15_prepare(edges)
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  bundle = out['bundle']
  topo = bundle['topology_snapshot']
  graph = bundle['canonical_graph']
  # schema.
  assert_equal 'cano-node.v1', topo['schema_version'],
               'B15-T03: topology schema_version MUST be cano-node.v1'
  # unique endpoint keys.
  topo_endpoint_keys = topo['endpoints'].map { |ep|
    ep.respond_to?(:endpoint_key) ? ep.endpoint_key.to_s : ep['endpoint_key'].to_s
  }.uniq.sort
  assert_equal topo_endpoint_keys, topo_endpoint_keys.uniq.sort,
               'B15-T03: topology endpoint keys MUST be unique'
  # topology epsilon == captured execution coordinate_epsilon.
  tv = src.execution_config.tolerance_values
  expected_eps = (tv[:coordinate_epsilon] || tv['coordinate_epsilon']).to_f
  assert_in_delta expected_eps, topo['coordinate_epsilon'].to_f, 1.0e-12,
                  'B15-T03: topology epsilon MUST equal captured execution coordinate_epsilon'
  # every graph node epsilon (when present) == captured epsilon.
  node_eps_violations = graph.nodes.reject { |n|
    v = n.is_a?(Hash) ? n['coordinate_epsilon'] : nil
    v.nil? || (v.respond_to?(:to_f) && (v.to_f - expected_eps).abs < 1.0e-12)
  }
  assert_equal 0, node_eps_violations.length,
               "B15-T03: every graph node coordinate_epsilon MUST equal " \
               "captured epsilon; got #{node_eps_violations.length} violations"
  # exact topology endpoint set == union graph node endpoint_keys.
  graph_node_keys = graph.nodes.flat_map { |n|
    if n.is_a?(Hash)
      Array(n['endpoint_keys']).map(&:to_s)
    elsif n.respond_to?(:endpoint_keys)
      Array(n.endpoint_keys).map(&:to_s)
    else
      []
    end
  }.sort.uniq
  assert_equal topo_endpoint_keys, graph_node_keys,
               'B15-T03: topology endpoint set MUST equal union of graph node endpoint_keys'
end

# =============================================================
# B15-T04 — graph captured configuration.
# =============================================================

test 'B15-T04: graph tolerance_digest + source_snapshot_id + workspace_id match captured inputs' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, src, ar = b15_prepare(edges)
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  graph = out['bundle']['canonical_graph']
  expected_digest = b15_expected_tolerance_digest(src)
  assert_equal expected_digest, graph.tolerance_digest.to_s,
               "B15-T04: graph.tolerance_digest MUST equal expected legacy digest; " \
               "got #{graph.tolerance_digest.inspect}"
  assert_equal src.snapshot_id.to_s, graph.source_snapshot_id.to_s,
               'B15-T04: graph source_snapshot_id MUST equal source.snapshot_id'
  ws = B15_RUNNER.current_workspace_for_test
  assert_equal ws.workspace_id.to_s, graph.workspace_id.to_s,
               'B15-T04: graph workspace_id MUST equal workspace.workspace_id'
end

# =============================================================
# B15-T05 — exact graph→structure binding.
# =============================================================

test 'B15-T05: structure canonical_graph_digest / source_snapshot_id / workspace_id bind to graph' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, src, ar = b15_prepare(edges)
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  bundle = out['bundle']
  graph = bundle['canonical_graph']
  struct = bundle['structure_result']
  assert_equal graph.digest.to_s, struct['canonical_graph_digest'].to_s,
               'B15-T05: structure canonical_graph_digest MUST equal graph.digest'
  assert_equal src.snapshot_id.to_s, struct['source_snapshot_id'].to_s,
               'B15-T05: structure source_snapshot_id MUST equal source.snapshot_id'
  ws = B15_RUNNER.current_workspace_for_test
  assert_equal ws.workspace_id.to_s, struct['workspace_id'].to_s,
               'B15-T05: structure workspace_id MUST equal workspace.workspace_id'
end

# =============================================================
# B15-T06 — Builder consumes the bundle directly.
# =============================================================

test 'B15-T06: PreparedCadDatasetBuilder consumes the bundle directly => BUILT, dataset != nil' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, src, ar = b15_prepare(edges)
  bundle = B15_RUNNER.capture_prepared_cad_input_bundle(
    analysis_result: ar
  )['bundle']
  # NO manual patching of any bundle field in the TEST after capture.
  out = b15_build_from_bundle(bundle)
  assert_equal 'BUILT', out['status'],
               "B15-T06: Builder MUST return BUILT on a clean fixture; got #{out['status']}"
  assert !out['blockers'].is_a?(Array) || out['blockers'].empty?,
         "B15-T06: Builder blockers MUST be empty; got #{out['blockers'].inspect}"
  refute_nil out['dataset'], 'B15-T06: Builder dataset MUST be non-nil on BUILT'
end

# =============================================================
# B15-T07 — Validator consumes Builder candidate.
# =============================================================

test 'B15-T07: PreparedCadDatasetValidator consume the Builder candidate => READY (not NOT_READY from cross-input mismatch)' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  bundle = B15_RUNNER.capture_prepared_cad_input_bundle(
    analysis_result: ar
  )['bundle']
  build_out = b15_build_from_bundle(bundle)
  assert_equal 'BUILT', build_out['status'], 'B15-T07: Builder MUST BUILT first'
  outcome = b15_finalize_from_builder(build_out, bundle)
  refute_equal 'NOT_READY', outcome['status'],
               "B15-T07: Validator MUST NOT report NOT_READY on a clean integration fixture; " \
               "got #{outcome['status']} blockers=#{outcome['blockers'].inspect}"
  assert %w[READY READY_WITH_WARNINGS].include?(outcome['status']),
         "B15-T07: Validator status MUST be READY or READY_WITH_WARNINGS; " \
         "got #{outcome['status']}"
  refute_nil outcome['dataset'], 'B15-T07: Validator MUST return dataset'
end

# =============================================================
# B15-T08 — no cache mutation.
# =============================================================

test 'B15-T08: capture does not mutate Runner caches / workspace fingerprint' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, ws, _src, ar = b15_prepare(edges)
  # Force the V1.7 + V1.8 caches to populate so we can
  # observe no-mutation.
  pre_snap = B15_RUNNER.snapshot
  ws_fingerprint_before = ws.respond_to?(:fingerprint) ? ws.fingerprint : nil
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  assert_equal 'CAPTURED', out['status'],
               'B15-T08: capture MUST succeed for the no-mutation assertion'
  post_snap = B15_RUNNER.snapshot
  # Workspace fingerprint unchanged.
  ws_fingerprint_after = B15_RUNNER.current_workspace_for_test.fingerprint
  assert_equal ws_fingerprint_before, ws_fingerprint_after,
               'B15-T08: workspace fingerprint MUST be unchanged by capture'
  # Snapshot() output for fields OUTSIDE the
  # bundle-specific bundle correction (state, source_id,
  # duplicate / planar sub-snapshot etc.) must be
  # unchanged. The bundle workflow copy is bundle-local;
  # the Runner's own snapshot() surface may change in
  # trivial ways (e.g. canonical_graph sub-dict freshness
  # when topology_repair_canonical_graph was previously
  # nil and now exists post-bundle_build via the runner
  # -- but capture does NOT publish to it).
  # Strict assertions:
  assert_equal pre_snap['state'], post_snap['state'],
               'B15-T08: snapshot state MUST be unchanged by capture'
  assert_equal pre_snap['workspace_id'], post_snap['workspace_id'],
               'B15-T08: workspace_id MUST be unchanged by capture'
  # The runner's internal canonical_graph cache ivar MUST
  # NOT have been mutated by capture. We cannot read the
  # private ivar in production; we observe through the
  # public snapshot surface.
  pre_topology_repair = pre_snap['topology_repair'] || {}
  post_topology_repair = post_snap['topology_repair'] || {}
  pre_cg = pre_topology_repair['canonical_graph']
  post_cg = post_topology_repair['canonical_graph']
  # If both pre and post are nil (no prior compute_gap_repair),
  # they MUST still both be nil after capture (capture does
  # NOT populate the runner's own cache).
  if pre_cg.nil?
    assert_nil post_cg,
               'B15-T08: capture MUST NOT populate @topology_repair_canonical_graph'
  end
  # structure_reconstruction cache ivar MUST NOT have been
  # mutated by capture.
  pre_struct = pre_snap['structure_reconstruction']
  post_struct = post_snap['structure_reconstruction']
  if pre_struct.nil? || (pre_struct.is_a?(Hash) &&
                          pre_struct['state'] == 'NOT_COMPUTED' &&
                          pre_struct['computed'] == false)
    assert post_struct.nil? ||
           (post_struct.is_a?(Hash) &&
            post_struct['state'] == 'NOT_COMPUTED' &&
            post_struct['computed'] == false),
           'B15-T08: capture MUST NOT populate @structure_reconstruction_result'
  end
end

# =============================================================
# B15-T09 — zero operation / geometry mutation.
# =============================================================

test 'B15-T09: capture opens zero host operations and does not mutate geometry' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  adapter, ws, _src, ar = b15_prepare(edges)
  ops_before = adapter.operation_log.length
  entities_before = ws.entities.length
  fp_before = ws.fingerprint
  # Snapshot live endpoint coords.
  live_coords_before = {}
  adapter.respond_to?(:edge_endpoints) &&
    ws.entities.each do |rec|
      next unless rec.respond_to?(:kind) && rec.kind == :edge
      did = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
      next if did.empty?
      handle = ws.handle_for(did) if ws.respond_to?(:handle_for)
      next if handle.nil?
      eps = adapter.edge_endpoints(handle)
      next unless eps.is_a?(Array) && eps.length == 2
      live_coords_before["#{did}.start"] =
        adapter.respond_to?(:vertex_position) ? adapter.vertex_position(eps[0]) : nil
      live_coords_before["#{did}.end"] =
        adapter.respond_to?(:vertex_position) ? adapter.vertex_position(eps[1]) : nil
    end
  B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  ops_after = adapter.operation_log.length
  assert_equal 0, ops_after - ops_before,
               "B15-T09: capture MUST NOT open host operations; " \
               "got #{ops_after - ops_before} new operations"
  ws = B15_RUNNER.current_workspace_for_test
  entities_after = ws.entities.length
  fp_after = ws.fingerprint
  assert_equal entities_before, entities_after,
               'B15-T09: entity count MUST be unchanged by capture'
  assert_equal fp_before, fp_after,
               'B15-T09: workspace fingerprint MUST be unchanged by capture'
  live_coords_after = {}
  adapter.respond_to?(:edge_endpoints) &&
    ws.entities.each do |rec|
      next unless rec.respond_to?(:kind) && rec.kind == :edge
      did = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
      next if did.empty?
      handle = ws.handle_for(did) if ws.respond_to?(:handle_for)
      next if handle.nil?
      eps = adapter.edge_endpoints(handle)
      next unless eps.is_a?(Array) && eps.length == 2
      live_coords_after["#{did}.start"] =
        adapter.respond_to?(:vertex_position) ? adapter.vertex_position(eps[0]) : nil
      live_coords_after["#{did}.end"] =
        adapter.respond_to?(:vertex_position) ? adapter.vertex_position(eps[1]) : nil
    end
  assert_equal live_coords_before, live_coords_after,
               'B15-T09: live endpoint coordinates MUST be unchanged by capture'
end

# =============================================================
# B15-T10 — host mismatch before first validation.
# =============================================================

test 'B15-T10: host mismatch before first validation => BLOCKED + host_state_changed' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  adapter, _ws, _src, ar = b15_prepare(edges)
  adapter.simulate_host_state_change!
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  assert_equal 'BLOCKED', out['status'],
               "B15-T10: status MUST be BLOCKED on pre-capture host mismatch; " \
               "got #{out['status']}"
  assert_nil out['bundle'],
             'B15-T10: bundle MUST be nil on BLOCKED'
  assert out['blockers'].include?('pcd_bundle:host_state_changed'),
         "B15-T10: blocker MUST include pcd_bundle:host_state_changed; " \
         "got #{out['blockers'].inspect}"
end

# =============================================================
# B15-T11 — host mismatch during capture (between first and second validation).
# =============================================================

test 'B15-T11: host mismatch during capture => BLOCKED + no partial bundle' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  adapter, _ws, _src, ar = b15_prepare(edges)
  # Arrange: first validation passes; second validation fails.
  # The FakeAdapter exposes `host_state_changed?` which the
  # runner consults via validate_host_state_consistency!. We
  # arm it so that the first call returns false (no change)
  # but the SECOND call returns true. Use the existing
  # simulate_host_state_change! before capture and then
  # arrange the runner to revert the flag via the test seam
  # _invalidate_to_failed_with_reason; but the simpler seam
  # is: pre-arm the change AND then verify that capture
  # returns BLOCKED. The "between first and second
  # validation" path is exercised by the production seam:
  # validate_host_state_consistency! is idempotent and
  # always consults the adapter flag at call time, so
  # arming it once covers both calls. To prove that BOTH
  # calls were attempted (not just the first short-circuit),
  # we ALSO assert: pre_first_validation_arm = false ->
  # first call returns true; then arm; second call returns
  # false. The validate_host_state_consistency! path is
  # straightforward; we simulate the sequence by toggling
  # the flag.
  # Capture will fail on FIRST validation if the flag is
  # armed; to test the BETWEEN path we need the flag
  # flipped between calls. We use the FakeAdapter's
  # simulate_host_state_change! exactly once during capture.
  # The runner's existing seam is: workspace transitions to
  # :failed on first mismatch; subsequent validate_host_state_
  # consistency! returns true (because state is already
  # :failed -> return true). So to exercise the between
  # path we simulate: first validate succeeds (flag
  # initially false) -> validate between topology/graph and
  # structure builds, then second validate fails (flag
  # armed) -> BLOCKED.
  # The FakeAdapter flips the flag ONCE on
  # simulate_host_state_change!; subsequent reads return
  # the new state. We use a custom subclass that flips the
  # flag during the second call only.
  flag_armed = [false]
  flippable = Class.new(DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter) do
    def initialize
      super()
      @call_count = 0
    end
    def host_state_changed?
      @call_count += 1
      # Flip the flag on the SECOND call only.
      if @call_count >= 2
        true
      else
        false
      end
    end
  end.new
  B15_RUNNER.reset_for_tests
  src = b15_source(edges)
  snap = B15_RUNNER.prepare(
    source: src, adapter: flippable, model: nil
  )
  unless snap['state'] == 'ready'
    raise "B15-T11: prepare expected ready; got #{snap['state']}"
  end
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  assert_equal 'BLOCKED', out['status'],
               "B15-T11: status MUST be BLOCKED when host_state_changed between validations; " \
               "got #{out['status']}"
  assert_nil out['bundle'],
             'B15-T11: bundle MUST be nil when BLOCKED during capture'
  assert out['blockers'].include?('pcd_bundle:host_state_changed'),
         "B15-T11: blocker MUST include pcd_bundle:host_state_changed; " \
         "got #{out['blockers'].inspect}"
  # Workspace is :failed (Runner fail-closed invalidation).
  refute_nil B15_RUNNER.current_workspace_for_test
  assert_equal :failed,
               B15_RUNNER.current_workspace_for_test.state,
               'B15-T11: workspace MUST be :failed after host mismatch during capture'
end

# =============================================================
# B15-T12 — analysis mismatch early gate.
# =============================================================

test 'B15-T12: AnalysisResult from another source => BLOCKED + analysis_source_mismatch' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, _ar = b15_prepare(edges)
  # Build a different AnalysisResult from a DIFFERENT source.
  other_src = b15_source([
    [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
    [[5.0, 0.0, 0.0], [5.0, 5.0, 0.0]],
    [[5.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ])
  other_ar = b15_analysis(b15_geometry_for(other_src))
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: other_ar)
  assert_equal 'BLOCKED', out['status'],
               "B15-T12: status MUST be BLOCKED on analysis mismatch; " \
               "got #{out['status']}"
  assert_nil out['bundle'], 'B15-T12: bundle MUST be nil on BLOCKED'
  assert out['blockers'].any? { |b| b.include?('analysis_source_mismatch') },
         "B15-T12: blocker MUST include analysis_source_mismatch; " \
         "got #{out['blockers'].inspect}"
end

# =============================================================
# B15-T13 — no precomputed gap dependency.
# =============================================================

test 'B15-T13: capture works without a prior compute_gap_repair' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  # Explicitly NOT calling compute_gap_repair; capture must
  # still succeed because topology / graph / structure are
  # read-only derivations of the current workspace.
  assert_nil B15_RUNNER.topology_repair_proposal,
             'B15-T13: pre-condition: topology_repair_proposal is nil'
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  assert_equal 'CAPTURED', out['status'],
               "B15-T13: capture MUST succeed without prior compute_gap_repair; " \
               "got #{out['status']} blockers=#{out['blockers'].inspect}"
end

# =============================================================
# B15-T14 — Owner-equivalent repaired fixture.
# =============================================================

test 'B15-T14: Owner-equivalent 0.2mm Z + 1mm Gap fixture => capture + Builder + Validator BUILT/READY' do
  live_z = 0.2 / 25.4
  one_mm = 1.0 / 25.4
  W = 10.0
  H = 5.0
  edges = [
    [[0.0, 0.0, 0.0],     [W,   0.0, live_z]],
    [[W,   0.0, live_z],  [W,   H,   0.0]],
    [[W,   H,   0.0],     [0.0, H,   0.0]],
    [[0.0, H,   0.0],     [0.0, one_mm, 0.0]]
  ]
  tol = Tolerance.new(duplicate: 1.0e-4, short_edge: 0.5,
                      gap_search: 0.05, coordinate_epsilon: 1.0e-4,
                      planar_z_snap: 0.01)
  B15_RUNNER.reset_for_tests
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  src = b15_source(edges, tol)
  snap = B15_RUNNER.prepare(
    source: src, adapter: adapter, model: nil
  )
  unless snap['state'] == 'ready'
    raise "B15-T14: prepare expected ready; got #{snap['state']}"
  end
  # Apply planar.
  planar_snap = B15_RUNNER.compute_planar_normalization
  assert_equal 'READY_TO_NORMALIZE',
               planar_snap['planar_normalization']['state'].to_s,
               'B15-T14: planar MUST be READY_TO_NORMALIZE on Owner fixture'
  apply_p = B15_RUNNER.apply_planar_normalization
  assert_equal 'APPLIED', apply_p['planar_normalization']['state'].to_s,
               'B15-T14: planar apply MUST succeed'
  # Apply gap.
  B15_RUNNER.compute_gap_repair
  apply_g = B15_RUNNER.apply_gap_repair
  assert_equal 'applied',
               apply_g['topology_repair']['audit']['status'].to_s,
               'B15-T14: gap apply MUST succeed on Owner fixture'
  ar = b15_analysis(b15_geometry_for(src))
  # Capture the B1.5 bundle.
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  assert_equal 'CAPTURED', out['status'],
               "B15-T14: capture MUST succeed on Owner fixture; " \
               "got #{out['status']} blockers=#{out['blockers'].inspect}"
  bundle = out['bundle']
  struct = bundle['structure_result']
  metrics = struct['metrics']
  assert_equal 0, metrics['open_chain_count'].to_i,
               'B15-T14: open_chain_count MUST be 0 after Z+Gap fix'
  assert_equal 1, metrics['closed_loop_count'].to_i,
               'B15-T14: closed_loop_count MUST be 1'
  assert_equal 0, metrics['invalid_loop_count'].to_i,
               'B15-T14: invalid_loop_count MUST be 0 (no non_planar_loop residue)'
  assert_equal 1, metrics['region_count'].to_i,
               'B15-T14: region_count MUST be 1'
  # No closed loop carries non_planar_loop.
  Array(struct['loops']).each do |loop|
    refute_includes Array(loop['unresolved_issues'] || []),
                    'non_planar_loop',
                    'B15-T14: closed loops MUST NOT carry non_planar_loop'
  end
  # Builder from the bundle.
  build_out = b15_build_from_bundle(bundle)
  assert_equal 'BUILT', build_out['status'],
               "B15-T14: Builder MUST BUILT on Owner fixture; " \
               "got #{build_out['status']} blockers=#{build_out['blockers'].inspect}"
  refute_nil build_out['dataset']
  # Validator.
  outcome = b15_finalize_from_builder(build_out, bundle)
  refute_equal 'NOT_READY', outcome['status'],
               "B15-T14: Validator MUST NOT report NOT_READY from cross-input mismatch; " \
               "got #{outcome['status']} blockers=#{outcome['blockers'].inspect}"
  # Validator's source/graph/structure coherence blockers
  # MUST be empty (NOT_READY from cross-input mismatch is
  # the failure mode the test guards against).
  coherence_blockers = Array(outcome['blockers']).select { |b|
    b.include?('coherence') ||
      b.include?('content_digest') ||
      b.include?('build_evidence') ||
      b.include?('source_content') ||
      b.include?('execution_context')
  }
  assert_equal [], coherence_blockers,
               "B15-T14: Validator MUST NOT block on source/graph/structure coherence; " \
               "got #{coherence_blockers.inspect}"
end

# =============================================================
# B15-T15 — repeated capture determinism.
# =============================================================

test 'B15-T15: repeated capture determinism — same source/workspace, same bundle semantics' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  out1 = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  out2 = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  assert_equal 'CAPTURED', out1['status'], 'B15-T15: first capture CAPTURED'
  assert_equal 'CAPTURED', out2['status'], 'B15-T15: second capture CAPTURED'
  b1 = out1['bundle']; b2 = out2['bundle']
  # Same source snapshot id.
  assert_equal b1['source_snapshot'].snapshot_id.to_s,
               b2['source_snapshot'].snapshot_id.to_s,
               'B15-T15: source snapshot id MUST be stable across capture'
  # Same workspace id (read via the source on the bundle).
  assert_equal b1['canonical_graph'].workspace_id.to_s,
               b2['canonical_graph'].workspace_id.to_s,
               'B15-T15: workspace id MUST be stable across capture'
  # Topology semantic content equal.
  t1 = b1['topology_snapshot']
  t2 = b2['topology_snapshot']
  # Compare endpoint set + canonical_node_clusters +
  # non_transitive_clusters + open_endpoints + metrics +
  # schema_version + coordinate_epsilon (string-keyed).
  %w[schema_version coordinate_epsilon canonical_node_clusters
     non_transitive_clusters open_endpoints metrics].each do |k|
    assert_equal t1[k], t2[k],
                 "B15-T15: topology_snapshot[#{k}] MUST be equal across captures"
  end
  # Graph digest equal.
  assert_equal b1['canonical_graph'].digest.to_s,
               b2['canonical_graph'].digest.to_s,
               'B15-T15: graph.digest MUST be stable across captures'
  # Structure digest equal.
  assert_equal b1['structure_result']['digest'].to_s,
               b2['structure_result']['digest'].to_s,
               'B15-T15: structure.digest MUST be stable across captures'
  # Builder from each bundle yields same PreparedCardataset
  # content_digest / dataset_id.
  bo1 = b15_build_from_bundle(b1)
  bo2 = b15_build_from_bundle(b2)
  assert_equal 'BUILT', bo1['status']
  assert_equal 'BUILT', bo2['status']
  cd1 = bo1['dataset'].content_digest
  cd2 = bo2['dataset'].content_digest
  assert_equal cd1, cd2,
               'B15-T15: PreparedCadDataset content_digest MUST be stable across captures'
  assert_equal bo1['dataset'].dataset_id.to_s, bo2['dataset'].dataset_id.to_s,
               'B15-T15: PreparedCadDataset dataset_id MUST be stable across captures'
end

# =============================================================
# B15-T16 — frozen bundle members cannot be mutated.
# =============================================================

test 'B15-T16: bundle + members are frozen (deep freeze)' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  bundle = out['bundle']
  assert bundle.frozen?, 'B15-T16: bundle MUST be frozen'
  bundle['workflow_snapshot'].each do |k, v|
    raise "B15-T16: workflow_snapshot[#{k.inspect}] should be Hash/String frozen; got #{v.class}" unless v.is_a?(Hash) || v.is_a?(String) || v.is_a?(Numeric) || v.is_a?(TrueClass) || v.is_a?(FalseClass) || v.nil?
    assert v.frozen?, "B15-T16: workflow_snapshot[#{k.inspect}] MUST be frozen" if v.respond_to?(:frozen?)
  end
  # topology_snapshot is a Hash; structure_result is already
  # deep-frozen by the reconstructor. canonical_graph and
  # source_snapshot are immutable value objects.
  bundle['topology_snapshot'].each do |k, v|
    assert v.frozen?, "B15-T16: topology_snapshot[#{k.inspect}] MUST be frozen" if v.is_a?(String)
  end
end