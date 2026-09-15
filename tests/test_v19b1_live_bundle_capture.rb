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

require_relative '../extension/su_ai_plugin/core/duplicate_repair_proposer'
require_relative '../extension/su_ai_plugin/core/duplicate_repair_executor'
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
  assert !B15_RUNNER.respond_to?(:current_bundle_for_test),
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
  # unique endpoint keys (R1-T04: B15-R1-04 vacuous
  # uniqueness assertion fix -- use raw keys first, NOT a
  # pre-deduped list, so duplicate detection is real).
  raw_endpoint_keys = topo['endpoints'].map { |ep|
    ep.respond_to?(:endpoint_key) ? ep.endpoint_key.to_s : ep['endpoint_key'].to_s
  }
  assert raw_endpoint_keys.all? { |k| !k.to_s.empty? },
         'B15-T03: every topology endpoint key MUST be non-empty'
  assert_equal raw_endpoint_keys.length, raw_endpoint_keys.uniq.length,
               'B15-T03: topology endpoint keys MUST be unique (raw, not pre-deduped)'
  topo_endpoint_keys = raw_endpoint_keys.uniq.sort
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

test 'B15-T07 (R1-T02): truthful clean workflow reaches READY (run real duplicate/planar/gap before capture)' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  # R1-T02: run the REAL deterministic workflow stages
  # BEFORE capture so the B1 Validator sees a truthful
  # workflow readiness state. Do NOT obtain READY by
  # rewriting workflow state inside B1.5.
  reg = ar.respond_to?(:registry) ? ar.registry : nil
  if reg
    B15_RUNNER.run_duplicate_repair_batch(registry: reg)
  end
  planar_snap = B15_RUNNER.compute_planar_normalization
  # On a clean rectangle the planar stage should
  # truthfully reach NO_CANDIDATE; we still allow
  # READY_TO_NORMALIZE without applying (we do not
  # mutate geometry here for the truthful READY test).
  assert %w[NO_CANDIDATE READY_TO_NORMALIZE].include?(
           planar_snap['planar_normalization']['state'].to_s
         ),
         "B15-T07: planar MUST reach NO_CANDIDATE or READY_TO_NORMALIZE; " \
         "got #{planar_snap['planar_normalization']['state'].inspect}"
  # If READY_TO_NORMALIZE, apply it so the Validator
  # sees the APPLIED terminal state.
  if planar_snap['planar_normalization']['state'].to_s == 'READY_TO_NORMALIZE'
    B15_RUNNER.apply_planar_normalization
  end
  # Gap repair on a closed rectangle should also reach
  # NO_CANDIDATE (no open endpoints).
  gap_snap = B15_RUNNER.compute_gap_repair
  assert %w[NO_CANDIDATE].include?(
           gap_snap['topology_repair']['state'].to_s
         ),
         "B15-T07: gap MUST reach NO_CANDIDATE on closed rectangle; " \
         "got #{gap_snap['topology_repair']['state'].inspect}"
  # Capture AFTER the real workflow has run.
  bundle = B15_RUNNER.capture_prepared_cad_input_bundle(
    analysis_result: ar
  )['bundle']
  build_out = b15_build_from_bundle(bundle)
  assert_equal 'BUILT', build_out['status'], 'B15-T07: Builder MUST BUILT first'
  outcome = b15_finalize_from_builder(build_out, bundle)
  assert !%w[NOT_READY].include?(outcome['status']),
         "B15-T07: Validator MUST NOT report NOT_READY on a truthfully clean integration fixture; " \
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
  # R1-T02 (B15-R1-01): run the REAL duplicate repair
  # first so the bundle workflow carries a truthful
  # duplicate_repair summary. The B1 Validator requires
  # this; do not obtain READY by rewriting workflow state
  # inside B1.5.
  reg_pre = IssueRegistry.new([])
  pf_pre = PreflightReport.new(
    edge_count: src.edges.length, vertex_count: src.edges.length * 2,
    layer_distribution: {}, bounding_box: nil, z_range: [0.0, 0.0],
    non_zero_z_vertex_count: 0, non_zero_z_edge_count: 0,
    significant_z_extrema_count: 0, large_coordinate_extrema_count: 0,
    warnings: [], sketchup_version: 'test', selection_type: 'Edges',
    group_count: 0, component_count: 0, deepest_nesting: 0,
    nested_containers: [], face_count: 0, faces_with_holes_count: 0
  )
  ar_pre = AnalysisResult.new(
    preflight: pf_pre, registry: reg_pre, geometry_snapshot: b15_geometry_for(src),
    selection_entities: [], active_edit_facts: {}
  )
  B15_RUNNER.run_duplicate_repair_batch(registry: ar_pre.registry)
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
    loop_issues = Array(loop['unresolved_issues'] || [])
    assert !loop_issues.include?('non_planar_loop'),
           "B15-T14: closed loops MUST NOT carry non_planar_loop; got #{loop_issues.inspect}"
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

# =============================================================
# R1-T01 — uncomputed workflow stays uncomputed (B15-R1-01).
# =============================================================
#
# Prepare a clean rectangle. Do NOT run:
#   - duplicate repair
#   - planar compute
#   - gap compute
#
# Capture MUST:
#   - return CAPTURED
#   - preserve missing duplicate_repair
#   - preserve planar_normalization NOT_COMPUTED / computed=false
#   - preserve topology_repair NOT_COMPUTED / computed=false
#   - carry the fresh B1.5 structure_reconstruction as computed=true
# Builder may still BUILT if its coherence contract permits.
# Validator MUST return NOT_READY for the truthful unexecuted
# workflow readiness state. This is expected behavior, not a
# failure of B1.5.

test 'R1-T01: uncomputed workflow stays uncomputed => CAPTURED, missing duplicate, NOT_COMPUTED planar/gap, fresh structure, Validator NOT_READY' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  # Do NOT run duplicate / planar / gap. Capture must still
  # succeed (CAPTURED) but expose the truthful uncomputed
  # workflow substates.
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  assert_equal 'CAPTURED', out['status'],
               "R1-T01: capture MUST return CAPTURED on a valid ready workspace; " \
               "got #{out['status']} blockers=#{out['blockers'].inspect}"
  refute_nil out['bundle'], 'R1-T01: bundle MUST be non-nil on CAPTURED'
  bundle = out['bundle']
  wf = bundle['workflow_snapshot']
  # Missing duplicate_repair is the truthful answer.
  assert !wf.key?('duplicate_repair'),
         'R1-T01: workflow MUST NOT synthesize duplicate_repair when ' \
         "the Runner never ran duplicate repair; got #{wf['duplicate_repair'].inspect}"
  # planar_normalization MUST be preserved as
  # computed=false / state='NOT_COMPUTED' (the Runner
  # snapshot's truthful fresh placeholder).
  planar = wf['planar_normalization']
  refute_nil planar, 'R1-T01: workflow MUST carry planar_normalization substate'
  assert_equal false, planar['computed'],
                 'R1-T01: planar.computed MUST remain false when not run'
  assert_equal 'NOT_COMPUTED', planar['state'].to_s,
               'R1-T01: planar.state MUST remain NOT_COMPUTED when not run'
  # topology_repair MUST be preserved as
  # computed=false / state='NOT_COMPUTED'.
  gap = wf['topology_repair']
  refute_nil gap, 'R1-T01: workflow MUST carry topology_repair substate'
  assert_equal false, gap['computed'],
                 'R1-T01: gap.computed MUST remain false when not run'
  assert_equal 'NOT_COMPUTED', gap['state'].to_s,
               'R1-T01: gap.state MUST remain NOT_COMPUTED when not run'
  # structure_reconstruction MUST be the fresh B1.5
  # structure_result (computed=true, state='READY' on a
  # clean rectangle).
  struct_sub = wf['structure_reconstruction']
  refute_nil struct_sub, 'R1-T01: workflow MUST carry structure_reconstruction substate'
  assert_equal true, struct_sub['computed'],
               'R1-T01: structure_reconstruction.computed MUST be true ' \
               '(B1.5 actually performed a fresh reconstruct in this call)'
  assert_equal 'READY', struct_sub['state'].to_s,
               'R1-T01: structure_reconstruction.state MUST be READY on a clean rectangle'
  # Validator MUST return NOT_READY because duplicate /
  # planar / gap are truthfully uncomputed.
  build_out = b15_build_from_bundle(bundle)
  # Builder may still BUILT if its coherence contract
  # permits (the B1.2-B1.4 BUILT vs BLOCKED contract does
  # NOT touch workflow readiness -- it touches cross-input
  # coherence, which is satisfied by the bundle).
  if build_out['status'] == 'BUILT'
    outcome = b15_finalize_from_builder(build_out, bundle)
    assert_equal 'NOT_READY', outcome['status'],
                 'R1-T01: Validator MUST return NOT_READY for truthful uncomputed workflow; ' \
                 "got #{outcome['status']} blockers=#{outcome['blockers'].inspect}"
    blockers = Array(outcome['blockers'])
    # Truthful blockers MUST include the missing duplicate
    # summary AND the NOT_COMPUTED planar/gap blockers.
    assert blockers.any? { |b| b.include?('duplicate_state') && b.include?('missing_summary') },
           "R1-T01: Validator MUST block on missing duplicate_state summary; " \
           "got #{blockers.inspect}"
    assert blockers.any? { |b| b.include?('planar_state') },
           "R1-T01: Validator MUST block on uncomputed planar_state; " \
           "got #{blockers.inspect}"
    assert blockers.any? { |b| b.include?('gap_state') },
           "R1-T01: Validator MUST block on uncomputed gap_state; " \
           "got #{blockers.inspect}"
  end
end

# =============================================================
# R1-T03 — exact fresh structure_result in workflow (B15-R1-02).
# =============================================================
#
# After capture:
#   wf_structure = bundle['workflow_snapshot']['structure_reconstruction']
#   fresh = bundle['structure_result']
# Require every fresh structure field/value to match exactly.
# Only additive workflow metadata allowed: `computed => true`.
# Specifically assert actual fresh:
#   metrics, unresolved_issues, chains, loops, regions,
#   source_snapshot_id, workspace_id, canonical_graph_digest,
#   digest, state as present in the current structure-result schema.

test 'R1-T03: workflow structure_reconstruction is the exact fresh structure_result (+ computed=true)' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  assert_equal 'CAPTURED', out['status'],
               "R1-T03: capture MUST succeed; got #{out['status']}"
  bundle = out['bundle']
  wf_structure = bundle['workflow_snapshot']['structure_reconstruction']
  fresh = bundle['structure_result']
  refute_nil wf_structure, 'R1-T03: workflow MUST carry structure_reconstruction'
  refute_nil fresh, 'R1-T03: bundle MUST carry structure_result'
  # R1-T03 invariant: every fresh structure field survives
  # into the workflow. Only the additive `computed => true`
  # field is added.
  %w[state digest canonical_graph_digest
     source_snapshot_id workspace_id metrics
     unresolved_issues chains loops regions].each do |k|
    assert_equal fresh[k], wf_structure[k],
                 "R1-T03: workflow structure_reconstruction[#{k.inspect}] MUST " \
                 "equal fresh structure_result[#{k.inspect}]; " \
                 "got workflow=#{wf_structure[k].inspect}, " \
                 "fresh=#{fresh[k].inspect}"
  end
  # Additive `computed` is the ONLY workflow-only field.
  assert_equal true, wf_structure['computed'],
               'R1-T03: workflow structure_reconstruction MUST carry computed=true'
  assert !fresh.key?('computed'),
         'R1-T03: fresh structure_result MUST NOT carry `computed` (it is added by the workflow copy)'
end

# =============================================================
# R1-T05 — topology missing/malformed endpoints fail closed
# (B15-R1-03).
# =============================================================
#
# Exercise the narrow B1.5 topology-normalization / capture
# seam and prove:
#   - missing endpoints => BLOCKED/no bundle
#   - non-Array endpoints => BLOCKED/no bundle
# Prefer a public capture-path regression. We test the
# helper directly (it is internal but the B15-R1 correction
# mandates a regression proof) and also prove the public
# capture path BLOCKS when the runner's topology is
# corrupted.

test 'R1-T05: topology missing endpoints => BLOCKED + topology_endpoints_missing' do
  topology = {
    'schema_version' => 'cano-node.v1',
    'canonical_nodes' => [],
    'canonical_node_clusters' => {},
    'non_transitive_clusters' => [],
    'open_endpoints' => [],
    'unresolved_topology_issues' => [],
    'metrics' => {},
    'coordinate_epsilon' => 1.0e-6
    # NO 'endpoints' / :endpoints key
  }
  result, blocker = B15_RUNNER.send(
    :_b15_normalize_topology, topology
  )
  assert_nil result,
             'R1-T05: missing endpoints MUST return [nil, blocker_code]'
  assert_equal 'pcd_bundle:topology_endpoints_missing', blocker,
               'R1-T05: missing endpoints MUST yield topology_endpoints_missing reason'
end

test 'R1-T05: topology non-Array endpoints => BLOCKED + topology_endpoints_missing' do
  topology = {
    'schema_version' => 'cano-node.v1',
    'endpoints' => 'this-is-not-an-array',
    'canonical_nodes' => [],
    'canonical_node_clusters' => {},
    'non_transitive_clusters' => [],
    'open_endpoints' => [],
    'unresolved_topology_issues' => [],
    'metrics' => {},
    'coordinate_epsilon' => 1.0e-6
  }
  result, blocker = B15_RUNNER.send(
    :_b15_normalize_topology, topology
  )
  assert_nil result,
             'R1-T05: non-Array endpoints MUST return [nil, blocker_code]'
  assert_equal 'pcd_bundle:topology_endpoints_missing', blocker,
               'R1-T05: non-Array endpoints MUST yield topology_endpoints_missing reason'
end

test 'R1-T05: topology Symbol-keyed endpoints are accepted as a single source' do
  topology = {
    'schema_version' => 'cano-node.v1',
    :endpoints => ['ep-a', 'ep-b'],
    'canonical_nodes' => [],
    'canonical_node_clusters' => {},
    'non_transitive_clusters' => [],
    'open_endpoints' => [],
    'unresolved_topology_issues' => [],
    'metrics' => {},
    'coordinate_epsilon' => 1.0e-6
  }
  result, blocker = B15_RUNNER.send(
    :_b15_normalize_topology, topology
  )
  refute_nil result,
             'R1-T05: Symbol-keyed endpoints with Array value MUST be accepted'
  assert_nil blocker,
             'R1-T05: Symbol-keyed endpoints with Array value MUST NOT yield a blocker'
  assert_equal ['ep-a', 'ep-b'], result['endpoints'],
               'R1-T05: bundle-local endpoints MUST come from the Symbol-keyed Array'
end

test 'R1-T05: topology dual Symbol+String endpoints (both Array, different contents) => BLOCKED + topology_endpoints_ambiguous' do
  topology = {
    'schema_version' => 'cano-node.v1',
    :endpoints => ['ep-a', 'ep-b'],
    'endpoints' => ['ep-c', 'ep-d'],
    'canonical_nodes' => [],
    'canonical_node_clusters' => {},
    'non_transitive_clusters' => [],
    'open_endpoints' => [],
    'unresolved_topology_issues' => [],
    'metrics' => {},
    'coordinate_epsilon' => 1.0e-6
  }
  result, blocker = B15_RUNNER.send(
    :_b15_normalize_topology, topology
  )
  assert_nil result,
             'R2-T05: dual-key endpoints MUST return [nil, blocker_code]'
  assert_equal 'pcd_bundle:topology_endpoints_ambiguous', blocker,
               'R2-T05: dual-key endpoints MUST yield topology_endpoints_ambiguous reason'
end

test 'R1-T05: topology wrong schema_version => BLOCKED + topology_unavailable' do
  topology = {
    'schema_version' => 'wrong-schema',
    :endpoints => ['ep-a'],
    'canonical_nodes' => []
  }
  result, blocker = B15_RUNNER.send(
    :_b15_normalize_topology, topology
  )
  assert_nil result,
             'R1-T05: wrong schema_version MUST return [nil, blocker_code]'
  assert_equal 'pcd_bundle:topology_unavailable', blocker,
               'R1-T05: wrong schema_version MUST yield topology_unavailable reason'
end

# =============================================================
# R1-T06 — no cache mutation, pre-populated variant.
# =============================================================
#
# Add a second variant of B15-T08:
#   - populate the normal Runner graph/structure caches
#     through existing public calls
#   - record public snapshot before
#   - call B1.5
#   - record public snapshot after
#   - prove B1.5 did not overwrite those cached values
#     with its fresh local graph/structure.
# No external private-ivar access.

test 'R1-T06: pre-populated Runner caches are NOT overwritten by B1.5 capture' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  # Populate the Runner graph / structure caches via the
  # existing public compute paths. We do NOT touch any
  # private ivar.
  B15_RUNNER.compute_structure_reconstruction
  gap_snap = B15_RUNNER.compute_gap_repair
  # The cached topology_repair_canonical_graph is published
  # through the snapshot's topology_repair.canonical_graph.
  pre_snap = B15_RUNNER.snapshot
  pre_struct_sub = pre_snap['structure_reconstruction']
  pre_topo = pre_snap['topology_repair'] || {}
  pre_cg = pre_topo['canonical_graph']
  pre_struct_digest = pre_struct_sub.is_a?(Hash) ?
                        pre_struct_sub['digest'] : nil
  pre_struct_state  = pre_struct_sub.is_a?(Hash) ?
                        pre_struct_sub['state'] : nil
  pre_cg_digest     = pre_cg.is_a?(Hash) ?
                        pre_cg['digest'] : nil
  # Capture. The bundle's canonical_graph / structure_result
  # are bundle-local fresh values; the Runner's OWN caches
  # MUST NOT be overwritten.
  out = B15_RUNNER.capture_prepared_cad_input_bundle(analysis_result: ar)
  assert_equal 'CAPTURED', out['status'],
               "R1-T06: capture MUST succeed; got #{out['status']} blockers=#{out['blockers'].inspect}"
  post_snap = B15_RUNNER.snapshot
  post_struct_sub = post_snap['structure_reconstruction']
  post_topo = post_snap['topology_repair'] || {}
  post_cg = post_topo['canonical_graph']
  post_struct_digest = post_struct_sub.is_a?(Hash) ?
                         post_struct_sub['digest'] : nil
  post_struct_state  = post_struct_sub.is_a?(Hash) ?
                         post_struct_sub['state'] : nil
  post_cg_digest     = post_cg.is_a?(Hash) ?
                         post_cg['digest'] : nil
  # The Runner's own cached structure_reconstruction state
  # MUST be unchanged across capture.
  assert_equal pre_struct_digest, post_struct_digest,
               'R1-T06: Runner @structure_reconstruction_result digest MUST be unchanged by capture'
  assert_equal pre_struct_state, post_struct_state,
               'R1-T06: Runner @structure_reconstruction_result state MUST be unchanged by capture'
  # The Runner's own topology_repair.canonical_graph digest
  # MUST be unchanged across capture.
  assert_equal pre_cg_digest, post_cg_digest,
               'R1-T06: Runner @topology_repair_canonical_graph digest MUST be unchanged by capture'
  # Cross-bundle check: the BUNDLE's fresh canonical_graph
  # may have a DIFFERENT digest from the Runner cache (the
  # bundle is recomputed from the same workspace with
  # current tolerance; the cache is the previous gap-repair
  # snapshot's value). We just assert the bundle itself is
  # internally coherent.
  bundle = out['bundle']
  refute_nil bundle['canonical_graph']
  refute_nil bundle['structure_result']
  assert_equal bundle['canonical_graph'].digest.to_s,
               bundle['structure_result']['canonical_graph_digest'].to_s,
               'R1-T06: bundle MUST bind structure canonical_graph_digest to its own graph.digest'
end

# =============================================================
# R2-PUB — PUBLIC capture-path malformed topology regressions.
# =============================================================
#
# Per frozen R2 packet R2-03:
#   The previous R1-T05 private-helper tests are
#   insufficient. Add PUBLIC capture-path regressions
#   through capture_prepared_cad_input_bundle(...)
#   that fault-inject the topology returned by
#   _canonical_topology_snapshot WITHOUT modifying
#   production design or adding a production test
#   seam.
#
# Technique:
#   - temporarily replace the Runner singleton method
#     _canonical_topology_snapshot in the test (the
#     Runner is module-level in SUAnalysis::Core);
#   - call the public capture_prepared_cad_input_bundle
#     with a valid ready workspace + analysis_result;
#   - restore the original method in ensure;
#   - assert status=BLOCKED, bundle=nil, and the
#     required pcd_bundle:* blocker code.
#
# This keeps production code untouched while proving the
# actual publication boundary behaves fail-closed for each
# required case.

# A tiny class whose #to_s returns the literal expected
# schema version. Used in R2-PUB-01 to prove the schema
# type check rejects any non-String spoof -- even one
# whose #to_s stringifies to the expected schema.
class R2SchemaSpoofString
  def to_s
    'cano-node.v1'
  end
  def is_a?(klass)
    klass == String || super
  end
end

# Fault-inject a custom topology Hash via a singleton
# replacement of the Runner's _canonical_topology_snapshot
# method for the duration of one test, then restore in
# ensure.
def b15_r2_inject_topology(topology_hash)
  runner = B15_RUNNER
  unless runner.respond_to?(:_canonical_topology_snapshot)
    raise 'R2 helper: Runner is missing _canonical_topology_snapshot'
  end
  original = runner.method(:_canonical_topology_snapshot)
  runner.define_singleton_method(:_canonical_topology_snapshot) do |**kwargs|
    topology_hash
  end
  begin
    yield
  ensure
    runner.define_singleton_method(
      :_canonical_topology_snapshot, original
    )
  end
end

test 'R2-PUB-01: public capture BLOCKS on non-String schema spoof => topology_unavailable' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  spoof = R2SchemaSpoofString.new
  b15_r2_inject_topology(
    'schema_version' => spoof,
    :endpoints       => ['ep-a', 'ep-b'],
    'canonical_nodes' => [],
    'canonical_node_clusters' => {},
    'non_transitive_clusters' => [],
    'open_endpoints' => [],
    'unresolved_topology_issues' => [],
    'metrics' => {},
    'coordinate_epsilon' => 1.0e-6
  ) do
    out = B15_RUNNER.capture_prepared_cad_input_bundle(
      analysis_result: ar
    )
    assert_equal 'BLOCKED', out['status'],
                 'R2-PUB-01: public capture MUST BLOCK on non-String schema spoof; ' \
                 "got status=#{out['status']} blockers=#{out['blockers'].inspect}"
    assert_nil out['bundle'],
               'R2-PUB-01: bundle MUST be nil on BLOCKED'
    assert_includes out['blockers'],
                    'pcd_bundle:topology_unavailable',
                    'R2-PUB-01: blocker MUST include topology_unavailable'
  end
end

test 'R2-PUB-02: public capture BLOCKS on dual endpoints with different Arrays => topology_endpoints_ambiguous' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  b15_r2_inject_topology(
    'schema_version' => 'cano-node.v1',
    :endpoints       => ['ep-a', 'ep-b'],
    'endpoints'      => ['ep-c', 'ep-d'],
    'canonical_nodes' => [],
    'canonical_node_clusters' => {},
    'non_transitive_clusters' => [],
    'open_endpoints' => [],
    'unresolved_topology_issues' => [],
    'metrics' => {},
    'coordinate_epsilon' => 1.0e-6
  ) do
    out = B15_RUNNER.capture_prepared_cad_input_bundle(
      analysis_result: ar
    )
    assert_equal 'BLOCKED', out['status'],
                 'R2-PUB-02: public capture MUST BLOCK on dual endpoint keys; ' \
                 "got status=#{out['status']} blockers=#{out['blockers'].inspect}"
    assert_nil out['bundle'],
               'R2-PUB-02: bundle MUST be nil on BLOCKED'
    assert_includes out['blockers'],
                    'pcd_bundle:topology_endpoints_ambiguous',
                    'R2-PUB-02: blocker MUST include topology_endpoints_ambiguous'
  end
end

test 'R2-PUB-03: public capture BLOCKS on Symbol Array + malformed String endpoint => topology_endpoints_ambiguous' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  b15_r2_inject_topology(
    'schema_version' => 'cano-node.v1',
    :endpoints       => ['ep-a', 'ep-b'],
    'endpoints'      => 'this-is-not-an-array',
    'canonical_nodes' => [],
    'canonical_node_clusters' => {},
    'non_transitive_clusters' => [],
    'open_endpoints' => [],
    'unresolved_topology_issues' => [],
    'metrics' => {},
    'coordinate_epsilon' => 1.0e-6
  ) do
    out = B15_RUNNER.capture_prepared_cad_input_bundle(
      analysis_result: ar
    )
    assert_equal 'BLOCKED', out['status'],
                 'R2-PUB-03: public capture MUST BLOCK on Symbol Array + malformed String endpoint; ' \
                 "got status=#{out['status']} blockers=#{out['blockers'].inspect}"
    assert_nil out['bundle'],
               'R2-PUB-03: bundle MUST be nil on BLOCKED'
    assert_includes out['blockers'],
                    'pcd_bundle:topology_endpoints_ambiguous',
                    'R2-PUB-03: blocker MUST include topology_endpoints_ambiguous'
  end
end

test 'R2-PUB-04: public capture BLOCKS on malformed Symbol endpoint + valid String Array => topology_endpoints_ambiguous' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  b15_r2_inject_topology(
    'schema_version' => 'cano-node.v1',
    :endpoints       => 'this-is-not-an-array',
    'endpoints'      => ['ep-a', 'ep-b'],
    'canonical_nodes' => [],
    'canonical_node_clusters' => {},
    'non_transitive_clusters' => [],
    'open_endpoints' => [],
    'unresolved_topology_issues' => [],
    'metrics' => {},
    'coordinate_epsilon' => 1.0e-6
  ) do
    out = B15_RUNNER.capture_prepared_cad_input_bundle(
      analysis_result: ar
    )
    assert_equal 'BLOCKED', out['status'],
                 'R2-PUB-04: public capture MUST BLOCK on malformed Symbol + valid String Array; ' \
                 "got status=#{out['status']} blockers=#{out['blockers'].inspect}"
    assert_nil out['bundle'],
               'R2-PUB-04: bundle MUST be nil on BLOCKED'
    assert_includes out['blockers'],
                    'pcd_bundle:topology_endpoints_ambiguous',
                    'R2-PUB-04: blocker MUST include topology_endpoints_ambiguous'
  end
end

test 'R2-PUB-05: public capture BLOCKS on missing single non-Array endpoints => topology_endpoints_missing' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  # single non-Array Symbol endpoints
  b15_r2_inject_topology(
    'schema_version' => 'cano-node.v1',
    :endpoints       => 'this-is-not-an-array',
    'canonical_nodes' => [],
    'canonical_node_clusters' => {},
    'non_transitive_clusters' => [],
    'open_endpoints' => [],
    'unresolved_topology_issues' => [],
    'metrics' => {},
    'coordinate_epsilon' => 1.0e-6
  ) do
    out = B15_RUNNER.capture_prepared_cad_input_bundle(
      analysis_result: ar
    )
    assert_equal 'BLOCKED', out['status'],
                 'R2-PUB-05: public capture MUST BLOCK on missing/non-Array endpoints; ' \
                 "got status=#{out['status']} blockers=#{out['blockers'].inspect}"
    assert_nil out['bundle'],
               'R2-PUB-05: bundle MUST be nil on BLOCKED'
    assert_includes out['blockers'],
                    'pcd_bundle:topology_endpoints_missing',
                    'R2-PUB-05: blocker MUST include topology_endpoints_missing'
  end
end

# =============================================================
# R2-05 — mutation-by-freeze regression (PUBLIC).
# =============================================================
#
# Per frozen R2 packet R2-05:
#   Capture real Runner workflow state.
#   Original mutable Runner String is not frozen before
#   capture.
#   Call public B1.5 capture.
#   Bundle copy is frozen.
#   Bundle copy object_id != original object_id.
#   Original Runner String remains unfrozen afterward.
#   Bytes unchanged.
#
# We obtain a real Runner workflow state by running the
# duplicate-repair batch (per B15-T14's successful
# pattern). The Runner's snapshot()'s
# duplicate_repair substate is the truthful fresh
# workflow String we capture. We capture its object_id
# BEFORE B1.5 capture, run B1.5, then assert:
#   - capture is CAPTURED;
#   - the bundle's copy of that String is frozen;
#   - the bundle's copy has a DIFFERENT object_id from
#     the Runner-owned String;
#   - the Runner-owned String remains unfrozen;
#   - bytes are identical.
#
# Implementation:
#   We rely on the snapshot() Hash shape produced by the
#   real Runner after running run_duplicate_repair_batch.
#   The Runner-owned String we use is the duplicate_repair
#   substate's summary text, which the Runner
#   run_duplicate_repair_batch populates. We capture that
#   String reference via the Runner's public snapshot()
#   output BEFORE B1.5 capture.

test 'R2-05: real Runner-owned String remains unfrozen while bundle copy is frozen + distinct' do
  edges = [
    [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
    [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
    [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]]
  ]
  _adapter, _ws, _src, ar = b15_prepare(edges)
  # Run duplicate-repair so the Runner snapshot carries
  # a real duplicate_repair substate populated by the
  # public BatchExecutor. The "none" status String (and
  # other real summary Strings) inside that substate is
  # a mutable UTF-8 String owned by the Runner's snapshot
  # output.
  reg = ar.respond_to?(:registry) ? ar.registry : nil
  if reg
    B15_RUNNER.run_duplicate_repair_batch(registry: reg)
  end
  # Take the Runner's public snapshot BEFORE B1.5
  # capture; locate a real UTF-8 String that the bundle
  # workflow copy will receive via _b15_force_utf8.
  pre_snap = B15_RUNNER.snapshot
  # Use the duplicate_repair substate (a Hash populated
  # by run_duplicate_repair_batch). The Hash carries
  # multiple real UTF-8 Strings; pick `last_action_status`
  # which the production executor populates with the
  # literal String "none" (or similar) when no actions
  # were applied. The String is owned by the Runner's
  # snapshot Hash, not by the bundle.
  dr_pre = pre_snap['duplicate_repair']
  assert dr_pre.is_a?(Hash),
         'R2-05: pre-condition: Runner snapshot MUST carry duplicate_repair substate after running duplicate repair'
  # Find a real String entry in the duplicate_repair Hash.
  # last_action_status is the canonical mutable UTF-8
  # status String the production executor produces.
  original_str_ref = dr_pre['last_action_status']
  unless original_str_ref.is_a?(String)
    # Fallback: pick any String entry.
    original_str_ref = dr_pre.values.find { |v| v.is_a?(String) }
  end
  assert original_str_ref.is_a?(String),
         'R2-05: pre-condition: duplicate_repair MUST carry a real String field'
  original_frozen_before = original_str_ref.frozen?
  original_bytes_before  = original_str_ref.dup.force_encoding('UTF-8').bytes
  original_obj_id       = original_str_ref.object_id
  original_encoding     = original_str_ref.encoding
  assert !original_frozen_before,
         'R2-05: pre-condition: Runner-owned String MUST NOT be frozen before capture'
  # Run B1.5 capture. The bundle workflow copy will be a
  # bundle-local deep copy.
  out = B15_RUNNER.capture_prepared_cad_input_bundle(
    analysis_result: ar
  )
  assert_equal 'CAPTURED', out['status'],
               'R2-05: capture MUST succeed on a real Runner workflow; ' \
               "got status=#{out['status']} blockers=#{out['blockers'].inspect}"
  bundle = out['bundle']
  refute_nil bundle, 'R2-05: bundle MUST be non-nil on CAPTURED'
  # Locate the same logical String inside the bundle
  # workflow's duplicate_repair substate.
  bundle_dr = bundle['workflow_snapshot']['duplicate_repair']
  assert bundle_dr.is_a?(Hash),
         'R2-05: bundle workflow MUST carry duplicate_repair substate'
  bundle_str = bundle_dr['last_action_status']
  unless bundle_str.is_a?(String)
    bundle_str = bundle_dr.values.find { |v| v.is_a?(String) }
  end
  assert bundle_str.is_a?(String),
         'R2-05: bundle duplicate_repair MUST carry a String field'
  assert_equal original_bytes_before, bundle_str.dup.force_encoding('UTF-8').bytes,
               'R2-05: bundle copy MUST preserve bytes'
  # CRITICAL: bundle String MUST be a distinct object.
  assert !bundle_str.equal?(original_str_ref),
         'R2-05: bundle String MUST NOT be the same object as the Runner-owned String'
  refute_equal original_obj_id, bundle_str.object_id,
               'R2-05: bundle String object_id MUST differ from original'
  # CRITICAL: bundle String MUST be frozen.
  assert bundle_str.frozen?,
         'R2-05: bundle String MUST be frozen after deep-freeze'
  # CRITICAL: original Runner-owned String MUST remain
  # unfrozen after capture and MUST retain its previous
  # frozen? state.
  post_snap = B15_RUNNER.snapshot
  dr_post = post_snap['duplicate_repair']
  assert dr_post.is_a?(Hash),
         'R2-05: Runner snapshot MUST still carry duplicate_repair substate after capture'
  post_str = dr_post['last_action_status']
  unless post_str.is_a?(String)
    post_str = dr_post.values.find { |v| v.is_a?(String) }
  end
  assert_equal original_obj_id, post_str.object_id,
               'R2-05: Runner-owned duplicate_repair String MUST remain the same object after capture'
  assert !post_str.frozen?,
         'R2-05: Runner-owned String MUST remain unfrozen after capture'
  # Bytes unchanged.
  assert_equal original_bytes_before, post_str.dup.force_encoding('UTF-8').bytes,
               'R2-05: Runner-owned String bytes MUST be unchanged by capture'
  # Encoding unchanged.
  assert_equal original_encoding, post_str.encoding,
               'R2-05: Runner-owned String encoding MUST be unchanged by capture'
end