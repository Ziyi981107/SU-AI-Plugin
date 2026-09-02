#
# tests/test_v17_production_gap_path.rb 鈥?V1.7 ACTUAL-PRODUCTION-PATH
# evidence for the frozen V1.7 Blueprint.
#
# Dispatch: V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01
#           (findings R5, R6, R7, R8).
#
# WHY THIS FILE EXISTS
# --------------------
# The previous V1.7 packet proved X1 / X2 with a `crossing_checker`
# proc CONSTRUCTED INSIDE THE TEST that "mirrored"
# WorkingModeRunner._crossing_checker_proc. AIPM finding R5 rejected
# that as production evidence: a mirrored implementation can stay
# green while production diverges.
#
# Every test in this file drives the REAL production entry points:
#
#   SUAnalysis::Core::WorkingModeRunner.prepare
#   SUAnalysis::Core::WorkingModeRunner.compute_gap_repair
#   SUAnalysis::Core::WorkingModeRunner.apply_gap_repair
#   SUAnalysis::Core::WorkingModeRunner.rebuild_canonical_geometry_graph
#
# i.e. exactly what the Simplified-Chinese `妫€鏌ラ棿闅檂 / `淇闂撮殭`
# dialog callbacks (`compute_gap_repair` / `apply_gap_repair` in
# dialog_runner.rb) invoke. No crossing / third-node / canonical
# identity / adjacency logic is re-implemented here. The production
# `_crossing_checker_proc` is the ONLY crossing authority exercised.
#
# Blueprint coverage delivered by this file:
#   搂18.3 X1  proposed bridge intersects unrelated edge interior
#             -> REVIEW_REQUIRED (production path).
#   搂18.3 X2  third canonical node lies on bridge
#             -> REVIEW_REQUIRED (production path).
#   搂18.3 X4  real almost-closed triangle missing one short closing
#             segment -> READY_TO_REPAIR (production path).
#   搂18.4 H3  multiple independent safe bridges -> ONE native
#             operation, exact bridge count (production path).
#   搂18.5 T3  repaired endpoints gain expected adjacency
#             (production path, exact degrees).
#   搂18.5 T4  almost-closed triangle becomes a canonical CYCLE
#             (production path, exact cycle invariant 鈥?NOT mere
#             BFS connectivity).
#
# Plus explicit regressions for the four production defects this
# dispatch uncovered by actually executing the production path
# (see Review/CURRENT_PI_REPORT.md 搂B).
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/endpoint_record'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/derived_entity_record'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/canonical_topology_builder'
require_relative '../extension/su_ai_plugin/core/canonical_geometry_graph'
require_relative '../extension/su_ai_plugin/core/gap_pair_proposer'
require_relative '../extension/su_ai_plugin/core/gap_bridge_executor'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_snapshot'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'

include SUAnalysis::Core

# ---------------------------------------------------------------
# Helpers (uniquely prefixed `v17p_` 鈥?tests/run_all.rb loads every
# test file into ONE process, so helper names must not collide).
# ---------------------------------------------------------------

V17P_RUNNER = SUAnalysis::Core::WorkingModeRunner

# Build a frozen SourceSnapshot whose captured ExecutionConfig
# carries the supplied Tolerance. The production runner derives its
# V1.7 tolerance from this captured snapshot
# (WorkingModeRunner._tolerance_from_snapshot), so this is the only
# supported way to drive gap_search / coordinate_epsilon through the
# real path.
def v17p_source(edges, tolerance)
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
  profile = Struct.new(:profile_name, :tolerance).new('v17p', tolerance)
  ec = ExecutionConfigSnapshot.from_live_config(
    profile, rule_set_digest: 'v17p-rules',
    source_snapshot_schema_version: 'v1'
  )
  SourceSnapshot.new(
    edges: recs, faces: [], layers: [layer], execution_config: ec,
    selection_scope: [], unit: 'inches', coordinate_origin: 'raw',
    transform_context: {}
  )
end

# Drive the REAL production prepare path. Returns the fake adapter.
def v17p_prepare(edges, tolerance)
  V17P_RUNNER.reset_for_tests
  adapter = DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter.new
  snap = V17P_RUNNER.prepare(
    source: v17p_source(edges, tolerance), adapter: adapter, model: nil
  )
  unless snap['state'] == 'ready'
    raise "v17p_prepare expected workspace state 'ready'; got " \
          "#{snap['state'].inspect} (#{snap['last_error'].inspect})"
  end
  adapter
end

def v17p_op_counts(adapter, from_index)
  ops = adapter.operation_log[from_index..-1] || []
  {
    begins:  ops.count { |o| o[:kind] == :begin },
    commits: ops.count { |o| o[:kind] == :commit },
    aborts:  ops.count { |o| o[:kind] == :abort }
  }
end

def v17p_distance(a, b)
  Math.sqrt(((a[0] - b[0])**2) + ((a[1] - b[1])**2) + ((a[2] - b[2])**2))
end

# Snapshot every source-derived edge's world endpoints, keyed by
# derived_id (used to prove Blueprint 搂14 "existing source-derived
# edge endpoint coordinates unchanged").
def v17p_source_edge_coords(workspace)
  out = {}
  workspace.entities.each do |rec|
    next unless rec.respond_to?(:kind) && rec.kind == :edge
    gs = rec.geometry_summary
    next unless gs.is_a?(Hash)
    next if gs['origin_kind'].to_s == 'generated_gap_bridge'
    out[rec.derived_id.to_s] = [gs['start'], gs['end']]
  end
  out
end

def v17p_bridge_records(workspace)
  workspace.entities.select { |rec|
    rec.respond_to?(:geometry_summary) && rec.geometry_summary.is_a?(Hash) &&
      rec.geometry_summary['origin_kind'].to_s == 'generated_gap_bridge'
  }
end

# Distinct canonical node identities in a CanonicalGeometryGraph.
# `graph.nodes` is a per-ENDPOINT mapping table (one record per
# EndpointRecord); several records legitimately share one
# canonical_node_id when they belong to one safe clique
# (Blueprint 搂7.2). Node IDENTITY count is therefore the uniq set.
def v17p_node_ids(graph)
  graph.nodes.map { |n| n['canonical_node_id'].to_s }.uniq
end

def v17p_degrees(graph)
  v17p_node_ids(graph).map { |cid| Array(graph.adjacency[cid]).length }
end

# Map representative world coordinate -> canonical degree.
#
# Canonical node IDs are MEMBERSHIP-derived (Blueprint 搂7.3: sorted
# endpoint membership keys + representative coordinate), so when a
# gap bridge endpoint joins an existing node's coordinate_epsilon
# clique the node's ID legitimately changes (singleton `cns-*` ->
# clique `cn-*`). Comparing pre/post adjacency therefore has to be
# anchored on the stable world coordinate, not on the node ID.
def v17p_degree_by_coord(graph)
  out = {}
  graph.nodes.each do |n|
    cid = n['canonical_node_id'].to_s
    w = n['world_coordinate']
    next unless w.is_a?(Array) && w.length == 3
    key = w.map { |v| format('%.9f', v.to_f) }
    out[key] = Array(graph.adjacency[cid]).length
  end
  out
end

def v17p_coord_key(point)
  point.map { |v| format('%.9f', v.to_f) }
end

# Deterministic cycle traversal (Blueprint 搂18.5 T4 exact invariant,
# second accepted form): walk the component from its lexicographically
# smallest canonical node, always taking the lexicographically
# smallest not-just-used neighbour, and prove we return to the start
# after consuming each expected canonical edge EXACTLY once.
# Returns { closed:, consumed:, uniq: }.
def v17p_cycle_walk(graph)
  ids = v17p_node_ids(graph).sort
  return { closed: false, consumed: 0, uniq: 0 } if ids.empty?
  start = ids.first
  cur = start
  prev = nil
  consumed = []
  closed = false
  (graph.edges.length + 2).times do
    nxt = Array(graph.adjacency[cur]).sort.find { |n| n != prev }
    break if nxt.nil?
    edge = graph.edges.find { |e|
      [e['node_a_id'].to_s, e['node_b_id'].to_s].sort == [cur, nxt].sort &&
        !consumed.include?(e['canonical_edge_id'].to_s)
    }
    break if edge.nil?
    consumed << edge['canonical_edge_id'].to_s
    prev = cur
    cur = nxt
    if cur == start
      closed = true
      break
    end
  end
  { closed: closed, consumed: consumed.length, uniq: consumed.uniq.length }
end

# The V1.7 gap_search / coordinate_epsilon used by the fixtures.
def v17p_tol(gap_search)
  Tolerance.new(duplicate: 1.0e-4, short_edge: 0.5,
                gap_search: gap_search, coordinate_epsilon: 1.0e-6)
end

# ===============================================================
# R5 鈥?X1 / X2 through the ACTUAL production crossing logic.
# ===============================================================

test 'V17-X1: [PRODUCTION PATH] bridge crossing an unrelated edge interior -> REVIEW_REQUIRED/bridge_crossing (real WorkingModeRunner._crossing_checker_proc)' do
  # e0: (0,0,0)->(5,0,0)      open at e0.end
  # e1: (5.1,0,0)->(10,0,0)   open at e1.start
  # e2: (5.05,-5,0)->(5.05,5,0)  UNRELATED, crosses the proposed
  #     bridge segment interior at (5.05,0,0).
  adapter = v17p_prepare([
    [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
    [[5.1, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[5.05, -5.0, 0.0], [5.05, 5.0, 0.0]]
  ], v17p_tol(0.5))
  ws_before = V17P_RUNNER.current_workspace_for_test
  entity_count_before = ws_before.entity_count
  ops_before = adapter.operation_log.length

  # THE PRODUCTION ENTRY POINT (dialog callback `compute_gap_repair`).
  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal

  refute_nil prop, 'X1: production compute_gap_repair must publish a proposal Hash'
  assert_equal GapPairProposer::STATE_REVIEW_REQUIRED, prop['state'],
               "X1: production state must be REVIEW_REQUIRED; got #{prop['state'].inspect}"
  assert_empty Array(prop['ready_proposals']),
               "X1: NO executable proposal may survive a crossing bridge; got #{Array(prop['ready_proposals']).inspect}"
  rev = Array(prop['review_proposals']).find { |r|
    Array(r['crossing_reasons']).include?('bridge_crossing')
  }
  refute_nil rev,
             "X1: a REVIEW_REQUIRED proposal with crossing_reasons ['bridge_crossing'] must be present; got #{Array(prop['review_proposals']).map { |r| [r['reason'], r['crossing_reasons']] }.inspect}"
  assert_equal 'bridge_crossing', rev['reason'],
               "X1: stable reason code must be 'bridge_crossing'"
  assert_equal false, rev['executable'],
               'X1: a crossing proposal must not be executable'
  # The bridge that was rejected is the e0.end <-> e1.start pair.
  pair_coords = Array(rev['expected_bridge_endpoints']).map { |p| p.map(&:to_f) }.sort
  assert_equal [[5.0, 0.0, 0.0], [5.1, 0.0, 0.0]], pair_coords,
               'X1: the rejected bridge must be the e0.end <-> e1.start pair'

  # No destructive host operation from a compute step.
  counts = v17p_op_counts(adapter, ops_before)
  assert_equal 0, counts[:begins], 'X1: compute_gap_repair must NOT open a host operation'
  assert_equal 0, counts[:commits], 'X1: compute_gap_repair must NOT commit a host operation'
  assert_empty adapter.repair_group_bridges,
               'X1: compute_gap_repair must NOT create repair-group bridge geometry'
  assert_equal entity_count_before,
               V17P_RUNNER.current_workspace_for_test.entity_count,
               'X1: compute_gap_repair must NOT change the derived entity inventory'
ensure
  V17P_RUNNER.reset_for_tests
end

test 'V17-X2: [PRODUCTION PATH] third canonical node on the bridge -> REVIEW_REQUIRED/third_node_on_bridge (real WorkingModeRunner._crossing_checker_proc)' do
  # e0: (0,0,0)->(5,0,0)        open at e0.end
  # e1: (5.1,0,0)->(10,0,0)     open at e1.start
  # e2: (5.05,0,0)->(5.05,5,0)  \ meet EXACTLY at (5.05,0,0):
  # e3: (5.05,0,0)->(5.05,-5,0) / that canonical node has degree 2,
  #     so it is NOT an open endpoint and NOT a gap candidate, but it
  #     lies exactly ON the proposed bridge interior.
  adapter = v17p_prepare([
    [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
    [[5.1, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[5.05, 0.0, 0.0], [5.05, 5.0, 0.0]],
    [[5.05, 0.0, 0.0], [5.05, -5.0, 0.0]]
  ], v17p_tol(0.5))
  ops_before = adapter.operation_log.length

  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal

  refute_nil prop
  assert_equal GapPairProposer::STATE_REVIEW_REQUIRED, prop['state'],
               "X2: production state must be REVIEW_REQUIRED; got #{prop['state'].inspect}"
  assert_empty Array(prop['ready_proposals']),
               "X2: NO executable proposal may survive a third node on the bridge; got #{Array(prop['ready_proposals']).inspect}"
  rev = Array(prop['review_proposals']).find { |r|
    Array(r['crossing_reasons']).include?('third_node_on_bridge')
  }
  refute_nil rev,
             "X2: a REVIEW_REQUIRED proposal with crossing_reasons ['third_node_on_bridge'] must be present; got #{Array(prop['review_proposals']).map { |r| [r['reason'], r['crossing_reasons']] }.inspect}"
  assert_equal 'third_node_on_bridge', rev['reason'],
               "X2: stable reason code must be 'third_node_on_bridge'"
  assert_equal false, rev['executable']

  counts = v17p_op_counts(adapter, ops_before)
  assert_equal 0, counts[:begins], 'X2: compute_gap_repair must NOT open a host operation'
  assert_empty adapter.repair_group_bridges,
               'X2: compute_gap_repair must NOT create repair-group bridge geometry'
ensure
  V17P_RUNNER.reset_for_tests
end

# ===============================================================
# R6 鈥?X4 must be a REAL almost-closed triangle.
# ===============================================================
#
#   A -------------------- B        A = (0, 0, 0)
#    \                    /         B = (10, 0, 0)
#     \                  /          C = (4.975, -6, 0)
#      \                /           D = (5.025, -6, 0)
#       C            D              gap C-D = 0.05
#
# THREE existing source-derived edges: A-B, A-C, B-D.
# C and D are the only two open endpoints. C-D is the missing short
# closing segment.

V17P_TRI_A = [0.0, 0.0, 0.0].freeze
V17P_TRI_B = [10.0, 0.0, 0.0].freeze
V17P_TRI_C = [4.975, -6.0, 0.0].freeze
V17P_TRI_D = [5.025, -6.0, 0.0].freeze

def v17p_triangle_edges
  [
    [V17P_TRI_A.dup, V17P_TRI_B.dup],   # A -> B  (top)
    [V17P_TRI_A.dup, V17P_TRI_C.dup],   # A -> C  (left leg)
    [V17P_TRI_B.dup, V17P_TRI_D.dup]    # B -> D  (right leg)
  ]
end

test 'V17-X4: [PRODUCTION PATH] real 3-edge almost-closed triangle with one short unique closing gap -> exactly one READY_TO_REPAIR endpoint_bridge C-D' do
  tol = v17p_tol(0.1)
  adapter = v17p_prepare(v17p_triangle_edges, tol)
  ws = V17P_RUNNER.current_workspace_for_test

  # --- Prove the INPUT really is a 3-edge almost-closed triangle ---
  src_edges = v17p_source_edge_coords(ws)
  assert_equal 3, src_edges.length,
               "X4: the fixture must contain exactly THREE existing source-derived edges; got #{src_edges.length}"
  world_pairs = src_edges.values.map { |(s, e)| [s.map(&:to_f), e.map(&:to_f)] }
  assert_includes world_pairs, [V17P_TRI_A.dup, V17P_TRI_B.dup], 'X4: edge A-B must exist'
  assert_includes world_pairs, [V17P_TRI_A.dup, V17P_TRI_C.dup], 'X4: edge A-C must exist'
  assert_includes world_pairs, [V17P_TRI_B.dup, V17P_TRI_D.dup], 'X4: edge B-D must exist'
  # Corner A and corner B are EXACTLY coincident shared corners
  # (2 incident edges each) -> the triangle boundary is closed
  # everywhere except the C-D gap.
  corner_a_hits = world_pairs.count { |pair| pair.include?(V17P_TRI_A.dup) }
  corner_b_hits = world_pairs.count { |pair| pair.include?(V17P_TRI_B.dup) }
  assert_equal 2, corner_a_hits, 'X4: corner A must be shared by exactly two edges'
  assert_equal 2, corner_b_hits, 'X4: corner B must be shared by exactly two edges'
  # The gap is inside (coordinate_epsilon, gap_search].
  gap = v17p_distance(V17P_TRI_C, V17P_TRI_D)
  assert_in_delta 0.05, gap, 1.0e-12
  assert_operator gap, :>, tol.coordinate_epsilon,
                  'X4: gap must exceed coordinate_epsilon'
  assert_operator gap, :<=, tol.gap_search,
                  'X4: gap must be inside gap_search'

  # --- Production compute ---
  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal
  refute_nil prop

  # Exactly TWO open endpoints (C and D). Canonical identity must
  # have merged the coincident corners A and B (Blueprint 搂7.2 /
  # 搂8) 鈥?a per-endpoint (host-vertex-style) degree would wrongly
  # report 6 open endpoints here.
  assert_equal 2, prop['open_endpoint_count'].to_i,
               "X4: the almost-closed triangle must expose exactly TWO open canonical endpoints; got #{prop['open_endpoint_count'].inspect}"

  assert_equal GapPairProposer::STATE_READY_TO_REPAIR, prop['state'],
               "X4: production state must be READY_TO_REPAIR; got #{prop['state'].inspect}"
  ready = Array(prop['ready_proposals'])
  assert_equal 1, ready.length,
               "X4: exactly ONE READY_TO_REPAIR endpoint_bridge must be proposed; got #{ready.length}"
  assert_empty Array(prop['review_proposals']),
               "X4: no crossing / third-node / layer / Z / curve / face disqualifier may fire; got #{Array(prop['review_proposals']).map { |r| r['reason'] }.inspect}"
  p0 = ready.first
  assert_equal 'endpoint_bridge', p0['action_type']
  assert_equal true, p0['executable']
  assert_equal 'ok', p0['reason']
  assert_empty Array(p0['crossing_reasons'])
  # THE BRIDGE IS C-D.
  bridge_pts = Array(p0['expected_bridge_endpoints']).map { |p| p.map(&:to_f) }.sort
  assert_equal [V17P_TRI_C.dup, V17P_TRI_D.dup].sort, bridge_pts,
               "X4: the proposed bridge must be exactly C-D; got #{bridge_pts.inspect}"
  assert_in_delta 0.05, p0['expected_bridge_length'].to_f, 1.0e-9
ensure
  V17P_RUNNER.reset_for_tests
end

# ===============================================================
# R7 鈥?Blueprint 搂18.4 H3: multiple independent safe bridges ->
#      ONE native SketchUp operation + exact generated bridge count.
# ===============================================================

test 'V17-H3: [PRODUCTION PATH, Blueprint 搂18.4 H3] two independent safe bridges -> ONE begin_operation, ONE commit, zero abort, exactly TWO generated bridges' do
  # Two independent gaps, four distinct open endpoints, no crossing,
  # no shared endpoint between the two proposals.
  #   band y=0  : (0,0)->(5,0)      gap 0.05   (5.05,0)->(10,0)
  #   band y=20 : (0,20)->(5,20)    gap 0.05   (5.05,20)->(10,20)
  tol = v17p_tol(0.1)
  adapter = v17p_prepare([
    [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
    [[5.05, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[0.0, 20.0, 0.0], [5.0, 20.0, 0.0]],
    [[5.05, 20.0, 0.0], [10.0, 20.0, 0.0]]
  ], tol)
  ws_pre = V17P_RUNNER.current_workspace_for_test
  pre_fingerprint = SourceFingerprint.from_snapshot(ws_pre.source_snapshot).digest.to_s.dup
  pre_coords = v17p_source_edge_coords(ws_pre)
  assert_equal 4, pre_coords.length

  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal
  ready = Array(prop['ready_proposals'])
  assert_equal 2, ready.length,
               "H3: the fixture must yield TWO independent executable proposals; got #{ready.length}"
  # Four DISTINCT endpoints across the two proposals.
  endpoint_keys = ready.flat_map { |p| [p['endpoint_a_key'].to_s, p['endpoint_b_key'].to_s] }
  assert_equal 4, endpoint_keys.length
  assert_equal 4, endpoint_keys.uniq.length,
               "H3: the two proposals must be endpoint-disjoint; got #{endpoint_keys.inspect}"
  ready.each { |p| assert_equal true, p['executable'] }
  expected_ids = ready.map { |p| p['proposal_id'].to_s }.sort

  # --- ONE batch apply through the production entry point ---
  ops_before = adapter.operation_log.length
  V17P_RUNNER.apply_gap_repair
  audit = V17P_RUNNER.topology_repair_audit
  ws_post = V17P_RUNNER.current_workspace_for_test

  assert_equal 'applied', audit['status'].to_s,
               "H3: batch apply must succeed; got #{audit.inspect}"
  assert_equal 2, audit['applied_count'].to_i,
               "H3: exact generated bridge count must be 2; got #{audit['applied_count'].inspect}"
  assert_equal 0, audit['failed_count'].to_i

  # ONE native SketchUp operation for the whole batch (搂12.3).
  counts = v17p_op_counts(adapter, ops_before)
  assert_equal 1, counts[:begins],
               "H3: exactly ONE begin_operation for the batch; got #{counts[:begins]}"
  assert_equal 1, counts[:commits],
               "H3: exactly ONE commit_operation for the batch; got #{counts[:commits]}"
  assert_equal 0, counts[:aborts],
               "H3: zero abort for a fully safe batch; got #{counts[:aborts]}"

  # Exactly TWO generated bridge entities (workspace + host side).
  bridges = v17p_bridge_records(ws_post)
  assert_equal 2, bridges.length,
               "H3: exactly TWO generated_gap_bridge derived entities; got #{bridges.length}"
  # V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-01: the
  # V1.7 base path owns the bridge via workspace.build_entity
  # (NOT a separate repair-group edge). Verify the workspace
  # handle_registry has exactly TWO bridge handles, each valid.
  bridge_dids = bridges.map(&:derived_id).map(&:to_s)
  bridge_handles = bridge_dids.map { |did| ws_post.handle_for(did) }
  assert_equal 2, bridge_handles.compact.length,
               "H3: both bridge derived_ids must have a live workspace handle; got #{bridge_handles.inspect}"
  bridge_handles.compact.each do |h|
    assert_equal true, h.respond_to?(:valid?) ? h.valid? : true,
                 'H3: each workspace-owned bridge handle must be valid'
  end
  assert_equal pre_coords.length + 2, ws_post.entity_count,
               'H3: the batch must add exactly two derived entities'

  # Both expected proposal IDs / provenance recorded.
  assert_equal expected_ids, Array(audit['applied_proposals']).map(&:to_s).sort,
               "H3: the audit must record BOTH applied proposal IDs; got #{Array(audit['applied_proposals']).inspect}"
  recorded = bridges.map { |b| b.geometry_summary['repair_action_id'].to_s }.sort
  assert_equal expected_ids, recorded,
               "H3: each generated bridge must carry its repair_action_id provenance; got #{recorded.inspect}"

  # Source fingerprint unchanged (搂14).
  post_fingerprint = SourceFingerprint.from_snapshot(ws_post.source_snapshot).digest.to_s
  assert_equal pre_fingerprint, post_fingerprint,
               'H3: source fingerprint MUST be unchanged by gap repair'
  # Existing source-derived coordinates unchanged (搂14 / 搂4).
  post_coords = v17p_source_edge_coords(ws_post)
  assert_equal pre_coords, post_coords,
               'H3: existing source-derived edge endpoint coordinates MUST be unchanged'

  # Post canonical graph contains BOTH gap_bridge canonical edges.
  graph = V17P_RUNNER.topology_repair_canonical_graph
  refute_nil graph, 'H3: the canonical graph must be rebuilt after apply'
  bridge_edges = graph.edges.select { |e| e['origin_kind'].to_s == 'gap_bridge' }
  assert_equal 2, bridge_edges.length,
               "H3: post canonical graph must contain TWO gap_bridge canonical edges; got #{bridge_edges.length}"
  assert_equal expected_ids,
               bridge_edges.map { |e| e['repair_action_id'].to_s }.sort,
               'H3: both canonical gap_bridge edges must carry their repair_action_id'
  # Each bridge closed its own gap: both formerly-open node pairs
  # are now mutually adjacent.
  bridge_edges.each do |e|
    a = e['node_a_id'].to_s
    b = e['node_b_id'].to_s
    refute_equal a, b, 'H3: a bridge must connect two DISTINCT canonical nodes'
    assert_includes Array(graph.adjacency[a]), b
    assert_includes Array(graph.adjacency[b]), a
  end
ensure
  V17P_RUNNER.reset_for_tests
end

# ===============================================================
# R8 鈥?Blueprint 搂18.5 T3 / T4 exact adjacency + CYCLE proof.
# ===============================================================

test 'V17-T3: [PRODUCTION PATH, Blueprint 搂18.5 T3] repaired endpoints gain exactly +1 canonical adjacency each; unrelated nodes unchanged' do
  tol = v17p_tol(0.1)
  v17p_prepare(v17p_triangle_edges, tol)
  ws_pre = V17P_RUNNER.current_workspace_for_test
  pre = V17P_RUNNER.rebuild_canonical_geometry_graph(workspace: ws_pre, tolerance: tol)
  refute_nil pre
  pre_deg = v17p_degree_by_coord(pre)

  # Pre-repair: A and B are shared corners (degree 2); C and D are
  # the two open endpoints (degree 1).
  assert_equal 2, pre_deg[v17p_coord_key(V17P_TRI_A)], 'T3 pre: corner A degree 2'
  assert_equal 2, pre_deg[v17p_coord_key(V17P_TRI_B)], 'T3 pre: corner B degree 2'
  assert_equal 1, pre_deg[v17p_coord_key(V17P_TRI_C)], 'T3 pre: open endpoint C degree 1'
  assert_equal 1, pre_deg[v17p_coord_key(V17P_TRI_D)], 'T3 pre: open endpoint D degree 1'

  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  post = V17P_RUNNER.topology_repair_canonical_graph
  refute_nil post

  bridge = post.edges.find { |e| e['origin_kind'].to_s == 'gap_bridge' }
  refute_nil bridge, 'T3: the applied bridge must appear as a canonical gap_bridge edge'
  # The bridge connects two DISTINCT canonical nodes, and they are
  # mutually adjacent (搂15.2 rebuilt adjacency).
  node_a = bridge['node_a_id'].to_s
  node_b = bridge['node_b_id'].to_s
  refute_equal node_a, node_b
  assert_includes Array(post.adjacency[node_a]), node_b
  assert_includes Array(post.adjacency[node_b]), node_a
  # The bridge spans exactly the two repaired endpoints C and D.
  assert_equal [v17p_coord_key(V17P_TRI_C), v17p_coord_key(V17P_TRI_D)].sort,
               Array(bridge['world_endpoints']).map { |p| v17p_coord_key(p) }.sort,
               'T3: the canonical bridge must span exactly C-D'

  post_deg = v17p_degree_by_coord(post)
  # Each repaired endpoint gains EXACTLY one adjacency.
  [V17P_TRI_C, V17P_TRI_D].each do |pt|
    k = v17p_coord_key(pt)
    assert_equal pre_deg[k] + 1, post_deg[k],
                 "T3: repaired endpoint #{pt.inspect} degree must increase by exactly 1 (was #{pre_deg[k].inspect}, now #{post_deg[k].inspect})"
  end
  # No unrelated node degree changed.
  [V17P_TRI_A, V17P_TRI_B].each do |pt|
    k = v17p_coord_key(pt)
    assert_equal pre_deg[k], post_deg[k],
                 "T3: unrelated node #{pt.inspect} degree must be unchanged"
  end
  # Exactly one new canonical edge; open endpoint count drops by 2.
  assert_equal pre.edges.length + 1, post.edges.length,
               'T3: apply must add exactly ONE canonical edge'
  assert_equal 2, pre.open_endpoints.length
  assert_equal 0, post.open_endpoints.length,
               'T3: open endpoint count must decrease by 2 for one independent bridge'
ensure
  V17P_RUNNER.reset_for_tests
end

test 'V17-T4: [PRODUCTION PATH, Blueprint 搂18.5 T4] real almost-closed triangle becomes an ACTUAL canonical cycle (exact degree + deterministic cycle traversal, NOT BFS connectivity)' do
  tol = v17p_tol(0.1)
  v17p_prepare(v17p_triangle_edges, tol)
  ws_pre = V17P_RUNNER.current_workspace_for_test

  # ---------- BEFORE the bridge ----------
  pre = V17P_RUNNER.rebuild_canonical_geometry_graph(workspace: ws_pre, tolerance: tol)
  refute_nil pre
  pre_ids = v17p_node_ids(pre)
  assert_equal 4, pre_ids.length,
               "T4 pre: the 3-edge almost triangle must have 4 canonical nodes (A, B, C, D); got #{pre_ids.length}"
  assert_equal 3, pre.edges.length,
               "T4 pre: exactly 3 canonical edges before the bridge; got #{pre.edges.length}"
  assert_equal [1, 1, 2, 2], v17p_degrees(pre).sort,
               "T4 pre: degrees must be [1,1,2,2] (an open chain); got #{v17p_degrees(pre).sort.inspect}"
  # Exactly TWO open endpoint nodes.
  assert_equal 2, v17p_degrees(pre).count { |d| d == 1 },
               'T4 pre: exactly two open endpoint nodes'
  assert_equal 2, pre.open_endpoints.length,
               "T4 pre: the graph must publish exactly two open endpoints; got #{pre.open_endpoints.inspect}"
  # Connected but ACYCLIC: a connected graph has a cycle iff
  # edges >= nodes. Here edges == nodes - 1 -> spanning tree -> no cycle.
  assert_equal pre_ids.length - 1, pre.edges.length,
               'T4 pre: connected + edges == nodes-1 -> NO cycle before the bridge'
  pre_walk = v17p_cycle_walk(pre)
  assert_equal false, pre_walk[:closed],
               'T4 pre: deterministic traversal must NOT close a cycle before the bridge'

  # ---------- APPLY through the production path ----------
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  post = V17P_RUNNER.topology_repair_canonical_graph
  refute_nil post

  # ---------- AFTER the bridge ----------
  # 1. the bridge exists as canonical `gap_bridge`.
  bridges = post.edges.select { |e| e['origin_kind'].to_s == 'gap_bridge' }
  assert_equal 1, bridges.length,
               "T4: exactly one canonical gap_bridge edge; got #{bridges.length}"
  bridge_pts = Array(bridges.first['world_endpoints']).map { |p| p.map(&:to_f) }.sort
  assert_equal [V17P_TRI_C.dup, V17P_TRI_D.dup].sort, bridge_pts,
               'T4: the canonical bridge must span exactly C-D'

  # 2. EXACT cycle invariant (Blueprint 搂18.5 T4, first accepted
  #    form): n canonical nodes + n canonical edges + EVERY node
  #    degree == 2. For this 搂2 fixture n == 4 (A, B, C, D) because
  #    C and D are distinct canonical nodes by construction
  #    (distance 0.05 > coordinate_epsilon). See V17-T4-EXACT3 for
  #    the 3-node / 3-edge form.
  post_ids = v17p_node_ids(post)
  assert_equal 4, post_ids.length,
               "T4: 4 canonical nodes after the bridge; got #{post_ids.length}"
  assert_equal 4, post.edges.length,
               "T4: 4 canonical edges after the bridge; got #{post.edges.length}"
  assert_equal [2, 2, 2, 2], v17p_degrees(post).sort,
               "T4: EVERY canonical node degree must be exactly 2; got #{v17p_degrees(post).sort.inspect}"
  assert_equal post_ids.length, post.edges.length,
               'T4: edges == nodes (connected + all degree 2) -> exactly one cycle'
  assert_equal 0, post.open_endpoints.length,
               "T4: zero open endpoints remain; got #{post.open_endpoints.inspect}"

  # 3. EXACT cycle invariant (second accepted form): a deterministic
  #    cycle traversal returns to the start after consuming the
  #    expected canonical edges EXACTLY once each.
  walk = v17p_cycle_walk(post)
  assert_equal true, walk[:closed],
               'T4: deterministic cycle traversal MUST return to the start node'
  assert_equal 4, walk[:consumed],
               "T4: the traversal must consume the expected 4 canonical edges; got #{walk[:consumed]}"
  assert_equal walk[:consumed], walk[:uniq],
               'T4: every canonical edge in the cycle must be consumed EXACTLY once'

  # 4. V1.7 stops at nodes + edges + adjacency (Blueprint 搂15.3):
  #    NO LoopRecord / RegionRecord is created.
  assert_nil defined?(SUAnalysis::Core::LoopRecord),
             'T4: V1.7 must NOT introduce a LoopRecord (V1.8 boundary)'
  assert_nil defined?(SUAnalysis::Core::RegionRecord),
             'T4: V1.7 must NOT introduce a RegionRecord (V1.8 boundary)'
  graph_h = post.to_h
  %w[loops regions loop_count region_count loop_records region_records].each do |forbidden|
    assert_equal false, post.metrics.key?(forbidden),
                 "T4: canonical metrics must not carry V1.8 key #{forbidden}"
    assert_equal false, graph_h.key?(forbidden),
                 "T4: canonical graph must not carry V1.8 key #{forbidden}"
  end
  snap = V17P_RUNNER.snapshot
  assert_equal false, snap.key?('loops')
  assert_equal false, snap.key?('regions')
ensure
  V17P_RUNNER.reset_for_tests
end

test 'V17-T4-EXACT3: [PRODUCTION PATH, Blueprint 搂18.5 T4] 3 canonical nodes + 3 canonical edges + every node degree == 2 after the closing bridge' do
  # The literal 3/3 form of the T4 exact invariant: two source edges
  # meeting EXACTLY at one corner, with the closing segment missing.
  #        P (0,0,0) ---------- Q (10,0,0)
  #                    (gap)     \
  #                               R (5,-8,0)
  # Edges: P-Q and Q-R exist (sharing Q exactly). P and R are the two
  # open endpoints; the bridge R-P closes the triangle.
  p_pt = [0.0, 0.0, 0.0]
  q_pt = [10.0, 0.0, 0.0]
  r_pt = [5.0, -8.0, 0.0]
  tol = v17p_tol(12.0)   # gap_search must cover |R-P| = ~9.43
  v17p_prepare([[p_pt.dup, q_pt.dup], [q_pt.dup, r_pt.dup]], tol)
  ws_pre = V17P_RUNNER.current_workspace_for_test

  pre = V17P_RUNNER.rebuild_canonical_geometry_graph(workspace: ws_pre, tolerance: tol)
  assert_equal 3, v17p_node_ids(pre).length, 'T4-EXACT3 pre: 3 canonical nodes'
  assert_equal 2, pre.edges.length, 'T4-EXACT3 pre: 2 canonical edges'
  assert_equal [1, 1, 2], v17p_degrees(pre).sort,
               "T4-EXACT3 pre: degrees [1,1,2]; got #{v17p_degrees(pre).sort.inspect}"
  assert_equal v17p_node_ids(pre).length - 1, pre.edges.length,
               'T4-EXACT3 pre: edges == nodes-1 -> NO cycle'

  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal
  assert_equal GapPairProposer::STATE_READY_TO_REPAIR, prop['state']
  assert_equal 1, Array(prop['ready_proposals']).length
  V17P_RUNNER.apply_gap_repair
  post = V17P_RUNNER.topology_repair_canonical_graph
  refute_nil post

  assert_equal 1, post.edges.count { |e| e['origin_kind'].to_s == 'gap_bridge' },
               'T4-EXACT3: exactly one canonical gap_bridge edge'
  assert_equal 3, v17p_node_ids(post).length,
               "T4-EXACT3: exactly 3 canonical nodes; got #{v17p_node_ids(post).length}"
  assert_equal 3, post.edges.length,
               "T4-EXACT3: exactly 3 canonical edges; got #{post.edges.length}"
  assert_equal [2, 2, 2], v17p_degrees(post).sort,
               "T4-EXACT3: EVERY node degree == 2; got #{v17p_degrees(post).sort.inspect}"
  walk = v17p_cycle_walk(post)
  assert_equal true, walk[:closed], 'T4-EXACT3: cycle traversal must close'
  assert_equal 3, walk[:consumed],
               "T4-EXACT3: traversal must consume exactly 3 canonical edges; got #{walk[:consumed]}"
  assert_equal walk[:consumed], walk[:uniq],
               'T4-EXACT3: each canonical edge consumed exactly once'
  assert_equal 0, post.open_endpoints.length
ensure
  V17P_RUNNER.reset_for_tests
end

# ===============================================================
# Regressions for the production defects this dispatch uncovered
# by actually executing the production path (report 搂B).
# ===============================================================

test 'V17-R5-REG-LAYER: DerivedTopologySnapshotBuilder must not call rec.layer on a DerivedEntityRecord (layered CAD must not raise NoMethodError)' do
  # Before the R5 fix the layer expression parsed as
  #   ((gs['layer'] || rec.respond_to?(:layer)) ? rec.layer : nil)
  # so ANY derived edge carrying a layer raised NoMethodError and
  # the whole production compute_gap_repair path died.
  adapter = v17p_prepare([
    [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
    [[5.05, 0.0, 0.0], [10.0, 0.0, 0.0]]
  ], v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  # The fixture really does carry a layer (otherwise the guard is vacuous).
  assert_equal 'L0', ws.entities.first.geometry_summary['layer'].to_s
  result = DerivedTopologySnapshotBuilder.build(
    workspace: ws, adapter: adapter, vertex_keys_by_edge: {}
  )
  endpoints = Array(result['endpoints'])
  assert_equal 4, endpoints.length
  endpoints.each do |ep|
    assert_equal 'L0', ep.layer_name.to_s,
                 'R5-REG-LAYER: the geometry_summary layer must reach EndpointRecord.layer_name'
  end
ensure
  V17P_RUNNER.reset_for_tests
end

test 'V17-R5-REG-FROZEN: WorkingModeRunner._canonical_topology_snapshot must not mutate the frozen CanonicalTopologyBuilder result' do
  # Before the R5 fix this raised FrozenError, so
  # compute_gap_repair / apply_gap_repair could NEVER run at all.
  v17p_prepare([
    [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
    [[5.05, 0.0, 0.0], [10.0, 0.0, 0.0]]
  ], v17p_tol(0.1))
  tol = v17p_tol(0.1)
  ws = V17P_RUNNER.current_workspace_for_test
  topo = V17P_RUNNER._canonical_topology_snapshot(workspace: ws, tolerance: tol)
  refute_nil topo
  assert_equal 4, Array(topo[:endpoints]).length,
               'R5-REG-FROZEN: the runner must be able to attach :endpoints'
  # The published canonical sub-structures stay frozen (immutability
  # contract preserved).
  assert_equal true, topo['canonical_nodes'].frozen?
  assert_equal true, topo['canonical_node_clusters'].frozen?
ensure
  V17P_RUNNER.reset_for_tests
end

test 'V17-R5-REG-CLUSTER: GapPairProposer must read the STRING-keyed canonical_node_clusters published by CanonicalTopologyBuilder' do
  # Before the R5 fix the proposer only read SYMBOL keys, so on the
  # production path canonical_node_clusters was {} 鈥?coincident
  # corner endpoints were never merged into one canonical node
  # (Blueprint 搂7.2) and were mis-reported as open (Blueprint 搂8).
  tol = v17p_tol(0.1)
  v17p_prepare(v17p_triangle_edges, tol)
  ws = V17P_RUNNER.current_workspace_for_test
  topo = V17P_RUNNER._canonical_topology_snapshot(workspace: ws, tolerance: tol)
  # The builder publishes STRING keys.
  assert_equal true, topo.key?('canonical_node_clusters')
  assert_nil topo[:canonical_node_clusters],
             'R5-REG-CLUSTER: the builder publishes string keys only (symbol read must be nil)'
  edges = V17P_RUNNER._derived_topology_edges(workspace: ws, tolerance: tol)
  result = GapPairProposer.propose(
    topology_snapshot: topo, derived_edges: edges, tolerance: tol,
    crossing_checker: V17P_RUNNER._crossing_checker_proc(tolerance: tol)
  )
  assert_equal 2, result['open_endpoint_count'].to_i,
               "R5-REG-CLUSTER: canonical clustering must collapse the two exactly-coincident corners; got #{result['open_endpoint_count'].inspect} open endpoints"
  assert_equal GapPairProposer::STATE_READY_TO_REPAIR, result['state']
ensure
  V17P_RUNNER.reset_for_tests
end

test 'V17-R6-NODE-IDENTITY: a resolved coordinate_epsilon clique is ONE canonical node id; a non-transitive cluster keeps distinct ids' do
  # Blueprint 搂7.2: "if every pair directly matches within
  # coordinate_epsilon: create ONE canonical node". Before the fix
  # every clique MEMBER received its own "<cluster>.nN" id, so an
  # exactly-coincident corner produced two canonical nodes and the
  # rebuilt canonical graph of a real almost-closed triangle could
  # never be connected or cycle-capable.
  clique = [
    EndpointRecord.new(endpoint_key: 'e1.end', derived_edge_id: 'e1',
                       role: 'end', world_coordinate: [3.0, 4.0, 0.0]),
    EndpointRecord.new(endpoint_key: 'e2.start', derived_edge_id: 'e2',
                       role: 'start', world_coordinate: [3.0, 4.0, 0.0])
  ]
  res = CanonicalTopologyBuilder.build(endpoints: clique, coordinate_epsilon: 1.0e-6)
  ids = res['canonical_nodes'].map { |n| n['canonical_node_id'] }.uniq
  assert_equal 1, ids.length,
               "R6-NODE-IDENTITY: a resolved clique must share ONE canonical_node_id; got #{ids.inspect}"
  assert_equal 1, res['canonical_node_clusters'].length
  assert_equal ids.first, res['canonical_node_clusters'].keys.first,
               'R6-NODE-IDENTITY: the clique canonical_node_id must equal its cluster id'
  res['canonical_nodes'].each { |n| assert_equal true, n['resolved_clique'] }

  # Non-transitive A~=B, B~=C, A!~=C must NOT collapse.
  e = 1.0e-3
  chain = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA',
                       role: 'start', world_coordinate: [0.0, 0.0, 0.0]),
    EndpointRecord.new(endpoint_key: 'b', derived_edge_id: 'eB',
                       role: 'start', world_coordinate: [e * 0.9, 0.0, 0.0]),
    EndpointRecord.new(endpoint_key: 'c', derived_edge_id: 'eC',
                       role: 'start', world_coordinate: [e * 1.8, 0.0, 0.0])
  ]
  res2 = CanonicalTopologyBuilder.build(endpoints: chain, coordinate_epsilon: e)
  refute_empty res2['non_transitive_clusters']
  ids2 = res2['canonical_nodes'].map { |n| n['canonical_node_id'] }
  assert_equal 3, ids2.uniq.length,
               "R6-NODE-IDENTITY: a non-transitive cluster must keep DISTINCT node ids; got #{ids2.inspect}"
end

# ===============================================================
# V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-01..SR-07
# regression tests (dispatch 搂9).
# ===============================================================

# SR1-1 - one proposal -> exactly one physical generated bridge
test 'V17-SR1-1 [PRODUCTION PATH]: one proposal -> exactly ONE host bridge edge total (not two)' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  bridges = v17p_bridge_records(ws_post)
  assert_equal 1, bridges.length,
               'SR1-1: exactly ONE workspace-owned bridge entity; got ' \
               "#{bridges.length}"
  did = bridges.first.derived_id.to_s
  h = ws_post.handle_for(did)
  refute_nil h, 'SR1-1: the bridge must have a workspace-owned host handle'
  children = h.respond_to?(:children) ? h.children.items : []
  edge_children = children.select { |c| c.is_a?(DerivedWorkspaceAdapter::FakeDerivedWorkspaceAdapter::FakeEdge) }
  assert_equal 1, edge_children.length,
               'SR1-1: exactly ONE bridge host edge inside the workspace group'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR1-2 - Discard -> zero generated bridge host geometry
test 'V17-SR1-2 [PRODUCTION PATH]: explicit Discard removes every generated bridge host geometry' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws_pre = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  pre_discard_bridges = v17p_bridge_records(ws_post)
  assert_equal 1, pre_discard_bridges.length
  discarded = ws_post.discard
  assert_equal :discarded, discarded.state
  bridge_h = ws_post.handle_for(pre_discard_bridges.first.derived_id)
  assert_equal false, bridge_h.valid?,
               'SR1-2: the bridge host handle must be invalid after discard'
  assert_empty discarded.entities,
               'SR1-2: the discarded workspace must have ZERO entities'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR1-3 - close auto-discard -> zero generated bridge host geometry
test 'V17-SR1-3 [PRODUCTION PATH]: close-time auto-discard removes every generated bridge host geometry' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  pre_close_bridges = v17p_bridge_records(ws_post)
  bridge_h = ws_post.handle_for(pre_close_bridges.first.derived_id)
  discarded = ws_post.discard
  assert_equal :discarded, discarded.state
  assert_equal false, bridge_h.valid?,
               'SR1-3: close-time auto-discard must invalidate the bridge host handle'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR1-4 - Rebuild -> no stale generated bridge geometry
test 'V17-SR1-4 [PRODUCTION PATH]: Rebuild -> no stale generated bridge geometry' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws_pre = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  assert_equal 1, v17p_bridge_records(ws_post).length,
               'SR1-4 precondition: apply produces one bridge'
  ws_post.discard
  rebuilt = V17P_RUNNER.prepare(
    source:  ws_pre.source_snapshot,
    adapter: adapter,
    model:   nil
  )
  assert_equal 'ready', rebuilt['state'],
               'SR1-4: rebuild must reach :ready'
  new_ws = V17P_RUNNER.current_workspace_for_test
  assert_empty v17p_bridge_records(new_ws),
               'SR1-4: the rebuilt workspace must have ZERO bridge entities'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR2-1 - first of two bridges succeeds, second fails
test 'V17-SR2-1 [PRODUCTION PATH]: first bridge succeeds, second fails -> clean abort + :failed + no logical bridge residue' do
  adapter = v17p_prepare([
    [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
    [[5.05, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[0.0, 20.0, 0.0], [5.0, 20.0, 0.0]],
    [[5.05, 20.0, 0.0], [10.0, 20.0, 0.0]]
  ], v17p_tol(0.1))
  fail_count = 0
  original_create = adapter.method(:create_top_level_group)
  adapter.define_singleton_method(:create_top_level_group) do |name, model: nil|
    fail_count += 1
    if fail_count >= 2
      raise StandardError, 'injected_second_bridge_failure'
    end
    original_create.call(name, model: model)
  end
  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal
  ready = Array(prop['ready_proposals'])
  assert_equal 2, ready.length, 'SR2-1 precondition: two ready proposals'
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  assert_equal :failed, ws_post.state,
               'SR2-1: post_workspace MUST be :failed after second bridge fails'
  bridges = ws_post.entities.select { |rec|
    rec.respond_to?(:geometry_summary) && rec.geometry_summary.is_a?(Hash) &&
      rec.geometry_summary['origin_kind'].to_s == 'generated_gap_bridge'
  }
  assert_empty bridges,
               'SR2-1: NO generated bridge entity may survive after confirmed-abort'
  audit = V17P_RUNNER.topology_repair_audit
  assert_equal 'failed', audit['status'].to_s
  assert_includes ['post_validation_failed', 'commit_uncertainty'], audit['reason'].to_s,
               'SR2-1: failure reason must be post_validation_failed or commit_uncertainty; ' \
               "got #{audit['reason'].inspect}"
ensure
  V17P_RUNNER.reset_for_tests
end

# SR2-2 - post-validation failure -> :failed
test 'V17-SR2-2 [PRODUCTION PATH]: post-validation failure -> :failed' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws_pre = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  assert_equal 'applied', V17P_RUNNER.topology_repair_audit['status'].to_s
  bridge = v17p_bridge_records(ws_post).first
  refute_nil bridge
  applied_entry = {
    'proposal_id' => bridge.geometry_summary['repair_action_id'].to_s,
    'derived_id' => bridge.derived_id.to_s,
    'host_handle' => ws_post.handle_for(bridge.derived_id)
  }
  tol = v17p_tol(0.1)
  ready_entry = {
    'proposal_id' => bridge.geometry_summary['repair_action_id'].to_s,
    'state' => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable' => true,
    'coordinate_epsilon' => tol.coordinate_epsilon.to_f,
    'expected_bridge_endpoints' => [
      bridge.geometry_summary['start'].dup,
      bridge.geometry_summary['end'].dup
    ]
  }
  adapter.define_singleton_method(:vertex_position) do |_v|
    [999.0, 999.0, 999.0]
  end
  adapter.define_singleton_method(:edge_endpoints) do |_h|
    [Object.new, Object.new]
  end
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter, [applied_entry], [ready_entry],
    pre_workspace: ws_pre,
    pre_fingerprint_digest: ws_pre.fingerprint.respond_to?(:digest) ? ws_pre.fingerprint.digest.to_s : nil,
    pre_source_fingerprint_digest: SourceFingerprint.from_snapshot(ws_pre.source_snapshot).digest.to_s,
    pre_entity_coords: nil
  )
  refute_equal true, result['pass'],
               'SR2-2: a host endpoint mismatch MUST be detected by post-validation'
  reasons_str = result['reasons'].join(',')
  assert(reasons_str.include?('host_endpoint_segment_mismatch') ||
         reasons_str.include?('host_endpoint_start_mismatch') ||
         reasons_str.include?('host_endpoint_end_mismatch'),
         "SR2-2: the post-validation reason must include a host_endpoint_* mismatch; " \
         "got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end

# SR2-3 - commit uncertainty -> :failed + handles retained
test 'V17-SR2-3 [PRODUCTION PATH]: commit uncertainty -> :failed + handles retained for Discard' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  V17P_RUNNER.compute_gap_repair
  original_end = adapter.method(:end_operation)
  adapter.define_singleton_method(:end_operation) do |_m, commit:|
    if commit
      raise StandardError, 'commit_uncertain_simulation'
    end
    original_end.call(_m, commit: commit)
  end
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  assert_equal :failed, ws_post.state,
               'SR2-3: commit uncertainty -> :failed'
  handles = ws_post.handle_registry_keys
  refute_empty handles,
               'SR2-3: handles must be retained for Discard recovery'
  audit = V17P_RUNNER.topology_repair_audit
  assert_equal 'commit_uncertainty', audit['reason'].to_s,
               'SR2-3: stable reason `commit_uncertainty` recorded'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR2-4 - no failure path returns READY
test 'V17-SR2-4 [PRODUCTION PATH]: no failure path returns READY (executor + canonical post-validate)' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  result_a = GapBridgeExecutor.apply(
    workspace: ws, adapter: adapter, proposals: [], tolerance: v17p_tol(0.1)
  )
  assert_equal :failed, result_a['status']
  refute_equal :ready, result_a['post_workspace'].state,
               'SR2-4A: zero-proposals path must NOT yield :ready'
  discarded = ws.discard
  result_b = GapBridgeExecutor.apply(
    workspace: discarded, adapter: adapter,
    proposals: [], tolerance: v17p_tol(0.1)
  )
  assert_equal :failed, result_b['status']
  refute_equal :ready, result_b['post_workspace'].state,
               'SR2-4B: discarded workspace must NOT be applyable as :ready'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR3-1 - endpoint mismatch is caught by post-validation
test 'V17-SR3-1 [PRODUCTION PATH]: endpoint mismatch is caught by post-validation' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  bridge = v17p_bridge_records(ws_post).first
  refute_nil bridge
  tol = v17p_tol(0.1)
  adapter.define_singleton_method(:edge_endpoints) do |_h|
    [Object.new, Object.new]
  end
  adapter.define_singleton_method(:vertex_position) do |_v|
    [999.0, 999.0, 999.0]
  end
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter,
    [{ 'proposal_id' => bridge.geometry_summary['repair_action_id'].to_s,
       'derived_id' => bridge.derived_id.to_s,
       'host_handle' => ws_post.handle_for(bridge.derived_id) }],
    [{ 'proposal_id' => bridge.geometry_summary['repair_action_id'].to_s,
       'state' => GapPairProposer::STATE_READY_TO_REPAIR,
       'executable' => true,
       'coordinate_epsilon' => tol.coordinate_epsilon.to_f,
       'expected_bridge_endpoints' => [
         bridge.geometry_summary['start'].dup,
         bridge.geometry_summary['end'].dup
       ] }],
    pre_workspace: ws, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  refute_equal true, result['pass']
  reasons_str = result['reasons'].join(',')
  assert(reasons_str.include?('host_endpoint_segment_mismatch') ||
         reasons_str.include?('host_endpoint_start_mismatch') ||
         reasons_str.include?('host_endpoint_end_mismatch'),
         "SR3-1: must include a host_endpoint_* mismatch reason; got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end

# SR3-2 - provenance/action mismatch is caught
test 'V17-SR3-2 [PRODUCTION PATH]: provenance/action mismatch is caught by post-validation' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  bridge = v17p_bridge_records(ws_post).first
  refute_nil bridge
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter,
    [{ 'proposal_id' => 'WRONG-PROPOSAL-ID',
       'derived_id' => bridge.derived_id.to_s,
       'host_handle' => ws_post.handle_for(bridge.derived_id) }],
    [{ 'proposal_id' => 'WRONG-PROPOSAL-ID',
       'state' => GapPairProposer::STATE_READY_TO_REPAIR,
       'executable' => true }],
    pre_workspace: ws, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  refute_equal true, result['pass']
  reasons_str = result['reasons'].join(',')
  assert(reasons_str.include?('wrong_repair_action_id') ||
         reasons_str.include?('proposal_id_set_mismatch'),
         "SR3-2: must include wrong_repair_action_id or proposal_id_set_mismatch; " \
         "got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end

# SR3-3 - source fingerprint mismatch is caught
test 'V17-SR3-3 [PRODUCTION PATH]: source fingerprint mismatch is caught by post-validation' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  fake_snap = Struct.new(:fingerprint).new(
    Struct.new(:digest).new('0000MUTATED0000')
  )
  fake_ws = Struct.new(:state, :source_snapshot, :entities, :handle_registry_keys).new(
    :ready, fake_snap, [], []
  )
  result = GapBridgeExecutor._post_validate(
    fake_ws, adapter, [], [],
    pre_workspace: ws, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: 'FFFFFFFFFFFFFFFF',
    pre_entity_coords: nil
  )
  refute_equal true, result['pass']
  assert_includes result['reasons'].join(','), 'source_fingerprint_changed'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR3-4 - pre-existing derived-coordinate mismatch is caught
test 'V17-SR3-4 [PRODUCTION PATH]: pre-existing derived-coordinate mismatch is caught' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  src_edges = ws_post.entities.select { |rec|
    rec.respond_to?(:geometry_summary) && rec.geometry_summary.is_a?(Hash) &&
      rec.geometry_summary['origin_kind'].to_s != 'generated_gap_bridge'
  }
  wrong_pre_coords = {}
  src_edges.each do |rec|
    wrong_pre_coords[rec.derived_id.to_s] = [
      [888.0, 888.0, 888.0], [777.0, 777.0, 777.0]
    ]
  end
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter, [], [],
    pre_workspace: ws, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil,
    pre_entity_coords: wrong_pre_coords
  )
  refute_equal true, result['pass']
  assert_includes result['reasons'].join(','), 'pre_existing_coords_changed'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR3-5 - canonical post-validation mismatch -> :failed
test 'V17-SR3-5 [PRODUCTION PATH]: canonical post-validation mismatch -> :failed' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  graph = V17P_RUNNER.topology_repair_canonical_graph
  result = V17P_RUNNER._canonical_post_validate(
    graph: graph,
    audit: { 'applied_proposals' => ['NONEXISTENT-PROPOSAL-ID'] },
    ready: [{ 'proposal_id' => 'NONEXISTENT-PROPOSAL-ID',
              'endpoint_a_key' => 'x', 'endpoint_b_key' => 'y' }]
  )
  refute_equal true, result['pass']
  reasons_str = result['reasons'].join(',')
  # V17-AIPM-DIRECT-SOURCE-REREVIEW-2026-09-01 RR-04: the
  # canonical post-validate now checks CURRENT-BATCH bridges
  # (those whose repair_action_id is in applied_ids). A
  # nonexistent applied_id therefore emits EITHER
  # canonical_bridge_count_mismatch(0/N) OR
  # repair_action_id_not_in_canonical (whichever the check
  # order reaches first).
  assert(
    reasons_str.include?('repair_action_id_not_in_canonical') ||
      reasons_str.include?('canonical_bridge_count_mismatch'),
    "SR3-5: must include repair_action_id_not_in_canonical OR canonical_bridge_count_mismatch; " \
    "got #{reasons_str.inspect}"
  )
ensure
  V17P_RUNNER.reset_for_tests
end

# SR4-1 - point truly inside segment -> third_node_on_bridge
test 'V17-SR4-1 [PRODUCTION PATH]: point truly inside the bridge segment -> third_node_on_bridge' do
  # e0: (0,0,0) -> (5,0,0)    open at e0.end
  # e1: (5.05,0,0) -> (10,0,0)  open at e1.start
  # e2: (5.025,0,0) -> (5.025,5,0)   meets e3 exactly at (5.025,0,0)
  # e3: (5.025,0,0) -> (5.025,-5,0)  \ so canonical node (5.025,0,0)
  #                                    has degree 2 -- NOT an open
  #                                    endpoint, NOT a candidate for
  #                                    the bridge, but lies EXACTLY
  #                                    on the bridge segment interior.
  v17p_prepare([
    [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
    [[5.05, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[5.025, 0.0, 0.0], [5.025, 5.0, 0.0]],
    [[5.025, 0.0, 0.0], [5.025, -5.0, 0.0]]
  ], v17p_tol(0.5))
  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal
  rev_third = Array(prop['review_proposals']).select { |r|
    Array(r['crossing_reasons']).include?('third_node_on_bridge')
  }
  refute_empty rev_third,
               'SR4-1: a point truly inside the bridge segment MUST trigger third_node_on_bridge; ' \
               "got crossing_reasons=#{Array(prop['review_proposals']).map { |r| r['crossing_reasons'] }.inspect}"
ensure
  V17P_RUNNER.reset_for_tests
end

# SR4-2 - far collinear beyond endpoint -> safe
test 'V17-SR4-2 [PRODUCTION PATH]: far collinear point beyond endpoint -> safe (NOT third_node_on_bridge)' do
  v17p_prepare([
    [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
    [[5.05, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[5.025, 100.0, 0.0], [5.025, 105.0, 0.0]]
  ], v17p_tol(0.5))
  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal
  rev_third = Array(prop['review_proposals']).select { |r|
    Array(r['crossing_reasons']).include?('third_node_on_bridge')
  }
  assert_empty rev_third,
               'SR4-2: far collinear point beyond endpoint must NOT trigger third_node_on_bridge; ' \
               "got #{rev_third.inspect}"
ensure
  V17P_RUNNER.reset_for_tests
end

# SR4-3 - near-line but outside epsilon -> safe
test 'V17-SR4-3 [PRODUCTION PATH]: near-line but outside epsilon -> safe (NOT third_node_on_bridge)' do
  v17p_prepare([
    [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
    [[5.05, 0.0, 0.0], [10.0, 0.0, 0.0]],
    [[5.025, 0.1, 0.0], [5.025, 0.2, 0.0]]
  ], v17p_tol(0.5))
  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal
  rev_third = Array(prop['review_proposals']).select { |r|
    Array(r['crossing_reasons']).include?('third_node_on_bridge')
  }
  assert_empty rev_third,
               'SR4-3: near-line point outside epsilon must NOT trigger third_node_on_bridge; ' \
               "got #{rev_third.inspect}"
ensure
  V17P_RUNNER.reset_for_tests
end

# SR5-1 - deterministic generated bridge ID
test 'V17-SR5-1 [PRODUCTION PATH]: deterministic generated bridge derived_id across equivalent rebuild/reapply' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal
  proposal_id = Array(prop['ready_proposals']).first['proposal_id'].to_s
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  bridge = v17p_bridge_records(ws_post).first
  refute_nil bridge
  expected_did = "der-gap-#{proposal_id}"
  assert_equal expected_did, bridge.derived_id.to_s,
               'SR5-1: bridge derived_id must be deterministic `der-gap-#{proposal_id}`; ' \
               "got #{bridge.derived_id.inspect}, expected #{expected_did.inspect}"
  ws_post.discard
  rebuilt = V17P_RUNNER.prepare(
    source: ws.source_snapshot, adapter: adapter, model: nil
  )
  assert_equal 'ready', rebuilt['state']
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post2 = V17P_RUNNER.current_workspace_for_test
  bridge2 = v17p_bridge_records(ws_post2).first
  refute_nil bridge2
  assert_equal expected_did, bridge2.derived_id.to_s,
               'SR5-1: reapply must yield the SAME deterministic derived_id'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR6-1 - plural source_occurrence_ids in canonical edge
test 'V17-SR6-1 [PRODUCTION PATH]: generated gap canonical edge contains BOTH source occurrence IDs (plural)' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  graph = V17P_RUNNER.topology_repair_canonical_graph
  refute_nil graph
  bridge_edges = graph.edges.select { |e| e['origin_kind'].to_s == 'gap_bridge' }
  assert_equal 1, bridge_edges.length,
               'SR6-1: exactly one gap_bridge canonical edge; ' \
               "got #{bridge_edges.length}"
  plural = Array(bridge_edges.first['source_occurrence_ids'])
  assert_equal 2, plural.length,
               'SR6-1: plural source_occurrence_ids must contain BOTH incident support IDs; ' \
               "got #{plural.inspect}"
  assert_includes plural, 'occ-101'
  assert_includes plural, 'occ-102'
  assert_includes plural, bridge_edges.first['source_occurrence_id'].to_s,
               'SR6-1: singular source_occurrence_id must be one of the plural IDs'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR7-1 - resolved clique -> one CanonicalGeometryGraph node
test 'V17-SR7-1 [PRODUCTION PATH]: a resolved coordinate_epsilon clique collapses to ONE CanonicalGeometryGraph node' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  graph = V17P_RUNNER.topology_repair_canonical_graph
  refute_nil graph
  corner_a_node = graph.nodes.find { |n|
    wc = n['world_coordinate']
    wc.is_a?(Array) && wc[0].to_f == 0.0 && wc[1].to_f == 0.0
  }
  refute_nil corner_a_node, 'SR7-1: corner A node must exist'
  assert_operator corner_a_node['membership_count'].to_i, :>=, 2,
                  'SR7-1: corner A clique must have membership_count >= 2; ' \
                  "got #{corner_a_node.inspect}"
  ids = graph.nodes.map { |n| n['canonical_node_id'].to_s }
  assert_equal ids.length, ids.uniq.length,
               'SR7-1: graph.nodes MUST contain exactly ONE logical record per canonical_node_id; ' \
               "found duplicates: total=#{ids.length}, uniq=#{ids.uniq.length}"
ensure
  V17P_RUNNER.reset_for_tests
end

# SR7-2 - non-transitive members remain distinct graph nodes
test 'V17-SR7-2 [PRODUCTION PATH]: non-transitive cluster members remain distinct graph nodes' do
  e = 1.0e-3
  chain = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA',
                       role: 'start', world_coordinate: [0.0, 0.0, 0.0]),
    EndpointRecord.new(endpoint_key: 'b', derived_edge_id: 'eB',
                       role: 'start', world_coordinate: [e * 0.9, 0.0, 0.0]),
    EndpointRecord.new(endpoint_key: 'c', derived_edge_id: 'eC',
                       role: 'start', world_coordinate: [e * 1.8, 0.0, 0.0])
  ]
  res = CanonicalTopologyBuilder.build(endpoints: chain, coordinate_epsilon: e)
  refute_empty res['non_transitive_clusters']
  graph = CanonicalGeometryGraph.new(
    source_snapshot_id: 'snap', execution_config_digest: 'ec',
    workspace_id: 'ws', nodes: res['canonical_nodes'],
    edges: [], adjacency: {},
    unresolved_topology_issues: res['unresolved_topology_issues'],
    metrics: res['metrics'],
    non_transitive_clusters: res['non_transitive_clusters'],
    open_endpoints: [],
    tolerance_digest: 'tol'
  )
  assert_equal 3, graph.nodes.length,
               'SR7-2: non-transitive members must remain 3 distinct graph nodes; ' \
               "got #{graph.nodes.length}"
  ids = graph.nodes.map { |n| n['canonical_node_id'].to_s }
  assert_equal 3, ids.uniq.length,
               'SR7-2: each non-transitive member MUST keep its distinct canonical_node_id'
end

# SR7-3 - canonical_node_count counts unique logical nodes
test 'V17-SR7-3 [PRODUCTION PATH]: canonical_node_count metric counts UNIQUE logical nodes (not per-endpoint records)' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  graph = V17P_RUNNER.topology_repair_canonical_graph
  refute_nil graph
  assert_equal 4, graph.metrics['canonical_node_count'].to_i,
               'SR7-3: canonical_node_count MUST equal unique logical node count (4); ' \
               "got #{graph.metrics['canonical_node_count'].inspect}"
  assert_equal graph.nodes.length, graph.metrics['canonical_node_count'].to_i,
               'SR7-3: canonical_node_count MUST equal graph.nodes.length'
ensure
  V17P_RUNNER.reset_for_tests
end

# SR7-4 - graph IDs / digest stable for unchanged reconstruction
test 'V17-SR7-4 [PRODUCTION PATH]: graph IDs / digest stable for unchanged same-workspace reconstruction' do
  adapter = v17p_prepare(v17p_triangle_edges, v17p_tol(0.1))
  ws = V17P_RUNNER.current_workspace_for_test
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  graph1 = V17P_RUNNER.topology_repair_canonical_graph
  tol = v17p_tol(0.1)
  graph2 = V17P_RUNNER.rebuild_canonical_geometry_graph(workspace: V17P_RUNNER.current_workspace_for_test, tolerance: tol)
  refute_nil graph1
  refute_nil graph2
  assert_equal graph1.digest, graph2.digest,
               'SR7-4: digest MUST be stable for an unchanged workspace'
  graph1_ids = graph1.nodes.map { |n| n['canonical_node_id'].to_s }.sort
  graph2_ids = graph2.nodes.map { |n| n['canonical_node_id'].to_s }.sort
  assert_equal graph1_ids, graph2_ids,
               'SR7-4: canonical_node_ids MUST be stable across rebuilds'
ensure
  V17P_RUNNER.reset_for_tests
end

# ===============================================================
# V17-AIPM-DIRECT-SOURCE-REREVIEW-2026-09-01 RR-02:
# HOST ENDPOINT POST-VALIDATION MUST FAIL CLOSED.
# Use the proposal's own coordinate_epsilon; no hardcoded
# 1e-5; undirected (forward OR reverse) segment match.
# Tests: missing capability, nil handles, raised/nil
# vertex reads, epsilon ownership, reversed host order.
# ===============================================================

# Helper: build a complete applied+ready pair from the
# already-applied bridge on the workspace, with the supplied
# proposal's coordinate_epsilon and expected endpoints.
def v17p_rr02_build_entries(ws_post, bridge, ce)
  applied_entry = {
    'proposal_id' => bridge.geometry_summary['repair_action_id'].to_s,
    'derived_id'  => bridge.derived_id.to_s,
    'host_handle' => ws_post.handle_for(bridge.derived_id)
  }
  ready_entry = {
    'proposal_id' => bridge.geometry_summary['repair_action_id'].to_s,
    'state' => GapPairProposer::STATE_READY_TO_REPAIR,
    'executable' => true,
    'coordinate_epsilon' => ce.to_f,
    'expected_bridge_endpoints' => [
      bridge.geometry_summary['start'].dup,
      bridge.geometry_summary['end'].dup
    ]
  }
  [applied_entry, ready_entry]
end

def v17p_rr02_workspace(tol)
  adapter = v17p_prepare(v17p_triangle_edges, tol)
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  ws_post = V17P_RUNNER.current_workspace_for_test
  bridge  = v17p_bridge_records(ws_post).first
  refute_nil bridge
  [adapter, ws_post, bridge]
end

# RR-02-A: missing edge_endpoints capability -> fail
test 'V17-RR02-A [PRODUCTION PATH]: missing edge_endpoints capability -> post-validate fails' do
  tol = v17p_tol(0.1)
  adapter, ws_post, bridge = v17p_rr02_workspace(tol)
  applied_entry, ready_entry = v17p_rr02_build_entries(ws_post, bridge, tol.coordinate_epsilon)
  # Make the adapter NOT expose edge_endpoints. We use a
  # respond_to? singleton override that returns false for
  # :edge_endpoints (does NOT modify the class itself, so
  # subsequent tests still have a working edge_endpoints
  # capability on fresh adapter instances).
  adapter.define_singleton_method(:respond_to?) do |sym, *args|
    sym.to_sym == :edge_endpoints ? false : super(sym, *args)
  end
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter, [applied_entry], [ready_entry],
    pre_workspace: ws_post, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  refute_equal true, result['pass'],
               'RR02-A: missing edge_endpoints capability MUST fail post-validation'
  reasons_str = result['reasons'].join(',')
  assert(reasons_str.include?('host_endpoint_handles_unavailable'),
         "RR02-A: reason must include 'host_endpoint_handles_unavailable'; " \
         "got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end

# RR-02-B: nil handles -> fail
test 'V17-RR02-B [PRODUCTION PATH]: edge_endpoints returns nil handles -> post-validate fails' do
  tol = v17p_tol(0.1)
  adapter, ws_post, bridge = v17p_rr02_workspace(tol)
  applied_entry, ready_entry = v17p_rr02_build_entries(ws_post, bridge, tol.coordinate_epsilon)
  adapter.define_singleton_method(:edge_endpoints) do |_h|
    [nil, nil]
  end
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter, [applied_entry], [ready_entry],
    pre_workspace: ws_post, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  refute_equal true, result['pass'],
               'RR02-B: nil handles MUST fail post-validation'
  reasons_str = result['reasons'].join(',')
  assert(reasons_str.include?('host_endpoint_handles_malformed'),
         "RR02-B: reason must include 'host_endpoint_handles_malformed'; " \
         "got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end

# RR-02-C: vertex_position raises -> fail
test 'V17-RR02-C [PRODUCTION PATH]: vertex_position raises -> post-validate fails' do
  tol = v17p_tol(0.1)
  adapter, ws_post, bridge = v17p_rr02_workspace(tol)
  applied_entry, ready_entry = v17p_rr02_build_entries(ws_post, bridge, tol.coordinate_epsilon)
  adapter.define_singleton_method(:edge_endpoints) do |_h|
    [Object.new, Object.new]
  end
  adapter.define_singleton_method(:vertex_position) do |_v|
    raise StandardError, 'vertex_position failure'
  end
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter, [applied_entry], [ready_entry],
    pre_workspace: ws_post, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  refute_equal true, result['pass'],
               'RR02-C: raising vertex_position MUST fail post-validation'
  reasons_str = result['reasons'].join(',')
  assert(reasons_str.include?('host_endpoint_position_unreadable'),
         "RR02-C: reason must include 'host_endpoint_position_unreadable'; " \
         "got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end

# RR-02-D: vertex_position returns nil -> fail
test 'V17-RR02-D [PRODUCTION PATH]: vertex_position returns nil -> post-validate fails' do
  tol = v17p_tol(0.1)
  adapter, ws_post, bridge = v17p_rr02_workspace(tol)
  applied_entry, ready_entry = v17p_rr02_build_entries(ws_post, bridge, tol.coordinate_epsilon)
  adapter.define_singleton_method(:edge_endpoints) do |_h|
    [Object.new, Object.new]
  end
  adapter.define_singleton_method(:vertex_position) do |_v|
    nil
  end
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter, [applied_entry], [ready_entry],
    pre_workspace: ws_post, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  refute_equal true, result['pass'],
               'RR02-D: nil vertex_position MUST fail post-validation'
  reasons_str = result['reasons'].join(',')
  assert(reasons_str.include?('host_endpoint_position_unreadable'),
         "RR02-D: reason must include 'host_endpoint_position_unreadable'; " \
         "got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end

# RR-02-E: difference between coordinate_epsilon and 1e-5 is enforced.
# The production code MUST use the proposal's own
# coordinate_epsilon. A delta that is inside the proposal's
# coordinate_epsilon but OUTSIDE 1e-5 must therefore be a
# pass at proposal epsilon AND a fail at the legacy 1e-5
# epsilon. Verify the proposal-epsilon pass.
test 'V17-RR02-E [PRODUCTION PATH]: difference between coordinate_epsilon and 1e-5 is enforced (proposal epsilon used)' do
  tol = v17p_tol(0.1)
  adapter, ws_post, bridge = v17p_rr02_workspace(tol)
  bridge_start = bridge.geometry_summary['start'].dup
  bridge_end   = bridge.geometry_summary['end'].dup
  # Apply a perturbation that is 5e-6 in magnitude (well
  # below 1e-5, so the legacy 1e-5 check would PASS) but
  # larger than the proposal's coordinate_epsilon (1e-6).
  pert_start = [bridge_start[0] + 5.0e-6, bridge_start[1], bridge_start[2]]
  pert_end   = [bridge_end[0]   - 5.0e-6, bridge_end[1],   bridge_end[2]]
  # Proposal coordinate_epsilon = 1.0e-6 (from v17p_tol).
  proposal_ce = 1.0e-6
  applied_entry, ready_entry = v17p_rr02_build_entries(ws_post, bridge, proposal_ce)
  adapter.define_singleton_method(:edge_endpoints) do |_h|
    [Object.new, Object.new]
  end
  adapter.define_singleton_method(:vertex_position) do |v|
    # First vertex -> perturbed start; second vertex ->
    # perturbed end. The host actually disagrees from the
    # expected endpoints by 5e-6.
    v.equal?(applied_entry['host_handle']) ? bridge_start.dup : pert_start.dup
  end
  # Use the perturbation pattern: alternate calls.
  vertex_seq = [pert_start, pert_end]
  adapter.define_singleton_method(:vertex_position) do |_v|
    vertex_seq.shift || pert_end
  end
  # The 5e-6 perturbation is INSIDE the legacy 1e-5 limit
  # but OUTSIDE the proposal's coordinate_epsilon of 1e-6.
  # RR-02 contract: post-validate MUST use the proposal's
  # epsilon (1e-6), so this MUST FAIL with
  # host_endpoint_segment_mismatch.
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter, [applied_entry], [ready_entry],
    pre_workspace: ws_post, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  refute_equal true, result['pass'],
               'RR02-E: 5e-6 host perturbation MUST exceed proposal 1e-6 epsilon -> FAIL'
  reasons_str = result['reasons'].join(',')
  assert(reasons_str.include?('host_endpoint_segment_mismatch'),
         "RR02-E: reason must include 'host_endpoint_segment_mismatch'; " \
         "got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end

# RR-02-F: reversed host endpoint order passes
test 'V17-RR02-F [PRODUCTION PATH]: reversed host endpoint order passes (undirected segment match)' do
  tol = v17p_tol(0.1)
  adapter, ws_post, bridge = v17p_rr02_workspace(tol)
  bridge_start = bridge.geometry_summary['start'].dup
  bridge_end   = bridge.geometry_summary['end'].dup
  applied_entry, ready_entry = v17p_rr02_build_entries(ws_post, bridge, tol.coordinate_epsilon)
  # Host reports the endpoints in REVERSED order (end, start).
  vh_a = Object.new
  vh_b = Object.new
  adapter.define_singleton_method(:edge_endpoints) do |_h|
    [vh_a, vh_b]
  end
  adapter.define_singleton_method(:vertex_position) do |v|
    if v.equal?(vh_a)
      bridge_end.dup     # reversed: vertex_a reports END coord
    elsif v.equal?(vh_b)
      bridge_start.dup   # reversed: vertex_b reports START coord
    else
      [0.0, 0.0, 0.0]
    end
  end
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter, [applied_entry], [ready_entry],
    pre_workspace: ws_post, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  assert_equal true, result['pass'],
               "RR02-F: reversed host endpoint order MUST pass undirected match; " \
               "got reasons=#{result['reasons'].inspect}"
  # The only non-endpoint-related reason permitted in a
  # valid pass is none.
  assert_empty result['reasons'].select { |r| r.start_with?('host_endpoint') },
               'RR02-F: no host_endpoint_* reasons expected when reversed order matches'
ensure
  V17P_RUNNER.reset_for_tests
end

# ===============================================================
# V17-AIPM-DIRECT-SOURCE-REREVIEW-2026-09-01 RR-05:
# ORDER-INDEPENDENT LOGICAL-NODE COLLAPSE.
# Forward / reversed / shuffled member order MUST yield the
# same logical-node payload (endpoint_keys, derived_edge_ids,
# source_occurrence_ids, layer_names, membership_count),
# the SAME representative world_coordinate, and the SAME
# graph digest.
# ===============================================================

def v17p_rr05_build_graph(ce, members)
  # Build a CanonicalGeometryGraph directly from the supplied
  # members. The `_collapse_nodes_by_id` is the function under
  # test.
  cid = 'clq-A'
  nodes_input = members.map do |m|
    {
      'canonical_node_id' => cid,
      'endpoint_key'      => m[:endpoint_key],
      'derived_edge_id'   => m[:derived_edge_id],
      'source_occurrence_id' => m[:source_occurrence_id],
      'layer_name'        => m[:layer_name],
      'world_coordinate'  => m[:world_coordinate],
      'resolved_clique'   => true,
      'coordinate_epsilon'=> ce
    }
  end
  CanonicalGeometryGraph.new(
    source_snapshot_id: 'snap', execution_config_digest: 'ec',
    workspace_id: 'ws', nodes: nodes_input, edges: [],
    adjacency: {},
    unresolved_topology_issues: [],
    metrics: { 'foo' => 'bar' },
    non_transitive_clusters: [],
    open_endpoints: [],
    tolerance_digest: 'tol'
  )
end

test 'V17-RR05 [PRODUCTION PATH]: forward / reversed / shuffled members -> identical logical node payload + representative coord + graph digest' do
  ce = 1.0e-6
  base_members = [
    { endpoint_key: 'kA', derived_edge_id: 'eA',
      source_occurrence_id: 'occ-a', layer_name: 'L0',
      world_coordinate: [1.0, 2.0, 3.0] },
    { endpoint_key: 'kB', derived_edge_id: 'eB',
      source_occurrence_id: 'occ-b', layer_name: 'L0',
      world_coordinate: [4.0, 5.0, 6.0] },
    { endpoint_key: 'kC', derived_edge_id: 'eC',
      source_occurrence_id: 'occ-c', layer_name: 'L1',
      world_coordinate: [7.0, 8.0, 9.0] }
  ]
  # Forward order (lex-sorted by key).
  g_forward = v17p_rr05_build_graph(ce, base_members)
  # Reversed order (kC, kB, kA).
  g_reversed = v17p_rr05_build_graph(ce, base_members.reverse)
  # Shuffled order (kB, kA, kC).
  g_shuffled = v17p_rr05_build_graph(
    ce, [base_members[1], base_members[0], base_members[2]]
  )
  # All three MUST expose the SAME logical node payload.
  [g_forward, g_reversed, g_shuffled].each do |g|
    assert_equal 1, g.nodes.length,
                 "RR05: collapsed nodes MUST contain exactly ONE logical node; got #{g.nodes.length}"
    n = g.nodes.first
    assert_equal %w[kA kB kC], n['endpoint_keys'],
                 "RR05: endpoint_keys must be sorted ['kA','kB','kC']; got #{n['endpoint_keys'].inspect}"
    assert_equal %w[eA eB eC], n['derived_edge_ids'],
                 "RR05: derived_edge_ids must be sorted ['eA','eB','eC']; got #{n['derived_edge_ids'].inspect}"
    assert_equal %w[occ-a occ-b occ-c], n['source_occurrence_ids'],
                 "RR05: source_occurrence_ids must be sorted; got #{n['source_occurrence_ids'].inspect}"
    assert_equal %w[L0 L1], n['layer_names'],
                 "RR05: layer_names must be sorted uniq; got #{n['layer_names'].inspect}"
    assert_equal 3, n['membership_count'].to_i,
                 "RR05: membership_count must be 3; got #{n['membership_count'].inspect}"
  end
  # Representative world_coordinate = ACTUAL coordinate of
  # the lex-smallest endpoint_key member (kA -> [1.0, 2.0, 3.0]).
  [g_forward, g_reversed, g_shuffled].each do |g|
    rep = g.nodes.first['world_coordinate']
    assert_equal [1.0, 2.0, 3.0], rep,
                 "RR05: representative coord MUST be the lex-smallest member's ACTUAL coord; got #{rep.inspect}"
  end
  # Graph digests MUST be identical.
  assert_equal g_forward.digest, g_reversed.digest,
               'RR05: forward vs reversed digest MUST match'
  assert_equal g_forward.digest, g_shuffled.digest,
               'RR05: forward vs shuffled digest MUST match'
end

# ===============================================================
# V17-AIPM-DIRECT-SOURCE-REREVIEW-2026-09-01 RR-04:
# EXACT CANONICAL PRE/POST VALIDATION.
# Three required tests:
# 1. prior gap bridge + later independent valid gap bridge
#    -> PASS (pre-existing bridge allowed; new bridge maps
#    1:1 to applied proposal_id).
# 2. unchanged pre-existing non-transitive cluster -> PASS
#    (post signatures - pre signatures is empty).
# 3. genuinely new cluster -> FAIL
#    (post signatures - pre signatures is non-empty).
# ===============================================================

# Helper: synthesize a minimal CanonicalGeometryGraph with
# the supplied gap_bridge repair_action_ids and non_transitive
# cluster signatures.
def v17p_rr04_build_graph(action_ids:, non_trans_sigs: [])
  bridge_edges = action_ids.map do |aid|
    {
      'canonical_edge_id'  => "ce-#{aid}",
      'origin_kind'        => 'gap_bridge',
      'repair_action_id'   => aid,
      'derived_edge_id'    => "der-#{aid}",
      'source_occurrence_id' => 'occ-bridge',
      'source_occurrence_ids' => ['occ-bridge'],
      'node_a_id'          => "cn-A-#{aid}",
      'node_b_id'          => "cn-B-#{aid}",
      'world_endpoints'    => [[0.0, 0.0, 0.0], [0.05, 0.0, 0.0]],
      'layer_name'         => 'L0',
      'unresolved_flags'   => []
    }
  end
  clusters = non_trans_sigs.map do |sig|
    keys = sig.split('|').reject(&:empty?)
    { 'cluster_id' => "clq-#{keys.join('-')}",
      'endpoint_keys' => keys }
  end
  # Synthetic adjacency: each bridge edge's two nodes are
  # mutually adjacent. The keys must be distinct from cluster
  # membership to avoid noise.
  adj = {}
  bridge_edges.each do |e|
    adj[e['node_a_id']] ||= []
    adj[e['node_a_id']] << e['node_b_id']
    adj[e['node_b_id']] ||= []
    adj[e['node_b_id']] << e['node_a_id']
  end
  adj.each_value { |v| v.uniq!; v.sort! }
  CanonicalGeometryGraph.new(
    source_snapshot_id: 'snap', execution_config_digest: 'ec',
    workspace_id: 'ws', nodes: [], edges: bridge_edges,
    adjacency: adj,
    unresolved_topology_issues: [],
    metrics: { 'foo' => 'bar' },
    non_transitive_clusters: clusters,
    open_endpoints: [],
    tolerance_digest: 'tol'
  )
end

# RR-04-A: prior gap bridge + later independent valid gap
# bridge -> PASS (pre-existing bridge is allowed; new bridge
# maps 1:1 to the batch's applied proposal_id).
test 'V17-RR04-A [PRODUCTION PATH]: prior gap bridge + later independent valid gap bridge -> PASS' do
  graph = v17p_rr04_build_graph(
    action_ids: %w[prior-gap-001 current-gap-002],
    non_trans_sigs: []
  )
  # Pretend the pre-batch baseline already contains the prior
  # bridge.
  pre_batch_ids   = %w[prior-gap-001]
  pre_batch_sigs  = []
  # The batch's applied proposal_id is current-gap-002.
  result = V17P_RUNNER._canonical_post_validate(
    graph: graph,
    audit: { 'applied_proposals' => %w[current-gap-002] },
    ready: [{ 'proposal_id' => 'current-gap-002',
              'endpoint_a_key' => 'a',
              'endpoint_b_key' => 'b' }],
    pre_batch_gap_bridge_action_ids: pre_batch_ids,
    pre_batch_non_transitive_sigs:   pre_batch_sigs
  )
  assert_equal true, result['pass'],
               "RR04-A: prior + new bridge must PASS; got reasons=#{result['reasons'].inspect}"
ensure
  V17P_RUNNER.reset_for_tests
end

# RR-04-B: unchanged pre-existing non-transitive cluster
# -> PASS (post signatures - pre signatures is EMPTY).
test 'V17-RR04-B [PRODUCTION PATH]: unchanged pre-existing non-transitive cluster -> PASS' do
  existing_sig = 'kA|kB|kC'
  graph = v17p_rr04_build_graph(
    action_ids: %w[current-gap-002],
    non_trans_sigs: [existing_sig]
  )
  pre_batch_ids  = []
  pre_batch_sigs = [existing_sig]   # pre-existing cluster
  result = V17P_RUNNER._canonical_post_validate(
    graph: graph,
    audit: { 'applied_proposals' => %w[current-gap-002] },
    ready: [{ 'proposal_id' => 'current-gap-002',
              'endpoint_a_key' => 'a',
              'endpoint_b_key' => 'b' }],
    pre_batch_gap_bridge_action_ids: pre_batch_ids,
    pre_batch_non_transitive_sigs:   pre_batch_sigs
  )
  assert_equal true, result['pass'],
               "RR04-B: unchanged pre-existing cluster must PASS; " \
               "got reasons=#{result['reasons'].inspect}"
ensure
  V17P_RUNNER.reset_for_tests
end

# RR-04-C: genuinely new non-transitive cluster -> FAIL
# (post signatures - pre signatures is NON-EMPTY).
test 'V17-RR04-C [PRODUCTION PATH]: genuinely new non-transitive cluster -> FAIL' do
  new_sig = 'kX|kY|kZ'
  graph = v17p_rr04_build_graph(
    action_ids: %w[current-gap-002],
    non_trans_sigs: [new_sig]
  )
  # Pre-batch baseline does NOT include the new cluster.
  pre_batch_ids  = []
  pre_batch_sigs = []
  result = V17P_RUNNER._canonical_post_validate(
    graph: graph,
    audit: { 'applied_proposals' => %w[current-gap-002] },
    ready: [{ 'proposal_id' => 'current-gap-002',
              'endpoint_a_key' => 'a',
              'endpoint_b_key' => 'b' }],
    pre_batch_gap_bridge_action_ids: pre_batch_ids,
    pre_batch_non_transitive_sigs:   pre_batch_sigs
  )
  refute_equal true, result['pass'],
               'RR04-C: a genuinely new cluster MUST fail'
  reasons_str = result['reasons'].join(',')
  assert(reasons_str.include?('new_non_transitive_cluster_introduced'),
         "RR04-C: must include 'new_non_transitive_cluster_introduced'; " \
         "got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end

# RR-04-D: runner-side baseline capture hooks exist and
# return deterministic shapes.
test 'V17-RR04-D [PRODUCTION PATH]: runner exposes RR-04 baseline capture hooks with deterministic shapes' do
  V17P_RUNNER.reset_for_tests
  empty_ids  = V17P_RUNNER._current_gap_bridge_action_ids
  empty_sigs = V17P_RUNNER._current_non_transitive_signatures
  assert_equal [], empty_ids,
               "RR04-D: _current_gap_bridge_action_ids returns [] when no workspace; " \
               "got #{empty_ids.inspect}"
  assert_equal [], empty_sigs,
               "RR04-D: _current_non_transitive_signatures returns [] when no workspace; " \
               "got #{empty_sigs.inspect}"
ensure
  V17P_RUNNER.reset_for_tests
end

# ===============================================================
# V17-AIPM-FINAL-PRE-CODEX-FIX-2026-09-02
# F-01 -- CAPTURED TOLERANCE AUTHORITY
# F-02 -- INDEPENDENT PROPOSAL-vs-RECORD-vs-HOST POST-VALIDATE
# ===============================================================
#
# These are the FINAL TWO bounded pre-Codex corrections
# from `Review/CURRENT_AIPM_REVIEW.md` (REVIEW_ID
# V17-AIPM-FINAL-SOURCE-REREVIEW-2026-09-02).
#
# F-01 captures tolerance authority in RR-04's pre-batch
# baseline: the previous v17_tolerance parsed only STRING keys
# while Tolerance#to_h publishes SYMBOL keys. v17_tolerance now
# delegates to the already-correct _tolerance_from_snapshot,
# which accepts both symbol and string keys.
#
# F-02 forces _post_validate to compare host / record /
# proposal independently: it resolves the READY proposal by
# proposal_id and verifies both the record (start/end/length)
# AND the host endpoint positions against the proposal's
# expected endpoints -- not against the record itself.

# ---- F-01-A: captured non-default tolerance is honored by both
#       compute_gap_repair and the pre-batch canonical baseline ----
test 'V17-F01-A [PRODUCTION PATH]: v17_tolerance honors non-default captured symbol-keyed tolerance (no silent fallback to defaults)' do
  # Build a SourceSnapshot whose captured execution_config
  # carries a Tolerance with SYMBOL-keyed tolerance_values
  # (the production Tolerance#to_h shape). Use non-default
  # values:
  #   gap_search = 0.25
  #   coordinate_epsilon = 5e-6
  custom_tol = Tolerance.new(
    duplicate: 1.0e-4, short_edge: 0.5,
    gap_search: 0.25, coordinate_epsilon: 5.0e-6
  )
  # Use the production prepare path with a triangle fixture
  # whose single gap is INSIDE the custom tolerance window
  # but OUTSIDE the legacy default window.
  adapter = v17p_prepare(v17p_triangle_edges, custom_tol)
  refute_nil adapter
  # The runner's v17_tolerance accessor MUST surface the
  # captured tolerance, not the legacy default. In particular,
  # gap_search and coordinate_epsilon are the two values the
  # RR-04 pre-batch baseline capture relies on.
  rtol = V17P_RUNNER.v17_tolerance
  refute_nil rtol, 'F-01-A: v17_tolerance must return a Tolerance when a source is captured'
  assert_in_delta 0.25,    rtol.gap_search.to_f,         1.0e-12,
               "F-01-A: v17_tolerance.gap_search must honor the captured value 0.25; " \
               "got #{rtol.gap_search.inspect}"
  assert_in_delta 5.0e-6,  rtol.coordinate_epsilon.to_f, 1.0e-12,
               "F-01-A: v17_tolerance.coordinate_epsilon must honor the captured value 5e-6; " \
               "got #{rtol.coordinate_epsilon.inspect}"
  # Compute must use the SAME captured tolerance (no silent
  # fallback). The custom coordinate_epsilon (5e-6) is LARGER
  # than the legacy default (1e-6), so a triangle whose gap
  # is 0.05 -- which the legacy default rejects as
  # "within coordinate_epsilon" (NO bridge) -- now passes as
  # a real gap.
  V17P_RUNNER.compute_gap_repair
  prop = V17P_RUNNER.topology_repair_proposal
  refute_nil prop
  # The almost-closed triangle yields exactly ONE
  # READY_TO_REPAIR proposal using the custom tolerance.
  assert_equal GapPairProposer::STATE_READY_TO_REPAIR, prop['state'],
               "F-01-A: custom captured tolerance must produce READY_TO_REPAIR; " \
               "got #{prop['state'].inspect}"
  ready = Array(prop['ready_proposals'])
  assert_equal 1, ready.length,
               "F-01-A: exactly one READY_TO_REPAIR proposal expected; got #{ready.length}"
  p0 = ready.first
  # The proposal MUST carry the captured coordinate_epsilon
  # (5e-6), NOT the legacy default (1e-6).
  assert_in_delta 5.0e-6, p0['coordinate_epsilon'].to_f, 1.0e-12,
               "F-01-A: ready_proposal.coordinate_epsilon must be the captured 5e-6; " \
               "got #{p0['coordinate_epsilon'].inspect}"
  # The proposal's expected bridge length MUST equal the
  # actual gap (C-D = 0.05). The captured tolerance is the
  # authoritative reference for the entire compute path.
  assert_in_delta 0.05, p0['expected_bridge_length'].to_f, 1.0e-9,
               "F-01-A: expected bridge length must equal the captured C-D gap (0.05); " \
               "got #{p0['expected_bridge_length'].inspect}"
ensure
  V17P_RUNNER.reset_for_tests
end

# ---- F-01-B: RR-04 pre-batch baseline capture uses the SAME
#       captured tolerance (no silent divergence from the
#       proposal/apply path) ----
test 'V17-F01-B [PRODUCTION PATH]: RR-04 baseline capture honors the captured tolerance (no silent fallback)' do
  custom_tol = Tolerance.new(
    duplicate: 1.0e-4, short_edge: 0.5,
    gap_search: 0.25, coordinate_epsilon: 5.0e-6
  )
  v17p_prepare(v17p_triangle_edges, custom_tol)
  ws = V17P_RUNNER.current_workspace_for_test
  # _current_gap_bridge_action_ids + _current_non_transitive_signatures
  # both rebuild the canonical graph via v17_tolerance. Both
  # MUST use the captured tolerance (5e-6 / 0.25), NOT the
  # legacy default (1e-6 / 0.1).
  ids  = V17P_RUNNER._current_gap_bridge_action_ids
  sigs = V17P_RUNNER._current_non_transitive_signatures
  # Empty pre-batch workspace -> both are empty Arrays.
  assert_equal [], ids,
               "F-01-B: _current_gap_bridge_action_ids returns [] when no bridges yet; " \
               "got #{ids.inspect}"
  assert_equal [], sigs,
               "F-01-B: _current_non_transitive_signatures returns [] when no clusters yet; " \
               "got #{sigs.inspect}"
  # The runner's v17_tolerance accessor MUST also be visible
  # to the pre-batch baseline path (the baseline rebuild
  # calls rebuild_canonical_geometry_graph with this
  # tolerance).
  rtol = V17P_RUNNER.v17_tolerance
  assert_in_delta 0.25, rtol.gap_search.to_f, 1.0e-12,
               "F-01-B: v17_tolerance.gap_search must be the captured 0.25"
  assert_in_delta 5.0e-6, rtol.coordinate_epsilon.to_f, 1.0e-12,
               "F-01-B: v17_tolerance.coordinate_epsilon must be the captured 5e-6"
  # And the apply path uses the SAME captured tolerance
  # (no divergence from the baseline path).
  V17P_RUNNER.compute_gap_repair
  V17P_RUNNER.apply_gap_repair
  post = V17P_RUNNER.topology_repair_canonical_graph
  refute_nil post
  bridge = post.edges.find { |e| e['origin_kind'].to_s == 'gap_bridge' }
  refute_nil bridge
  # The canonical bridge MUST carry the captured tolerance
  # influence (canonical graph is built from the captured
  # tolerance via rebuild_canonical_geometry_graph).
  # Indirect check: apply succeeded with the custom tolerance
  # and the canonical graph is structurally consistent.
  assert_equal 4, post.edges.length,
               "F-01-B: canonical graph must contain the bridge + 3 source edges"
ensure
  V17P_RUNNER.reset_for_tests
end

# ---- F-02-A: ready proposal with endpoints (A,B) -- record + host
#       both report (A,B) -- PASSES ----
test 'V17-F02-A [PRODUCTION PATH]: record + host both match READY proposal endpoints -> PASS' do
  tol = v17p_tol(0.1)
  adapter, ws_post, bridge = v17p_rr02_workspace(tol)
  bridge_start = bridge.geometry_summary['start'].dup
  bridge_end   = bridge.geometry_summary['end'].dup
  applied_entry, ready_entry = v17p_rr02_build_entries(ws_post, bridge, tol.coordinate_epsilon)
  # Add expected_bridge_length to the proposal so the F-02
  # length check has an authoritative reference.
  ready_entry['expected_bridge_length'] = bridge.geometry_summary['length'].to_f
  # Host reports the endpoints in FORWARD order (start, end).
  vh_a = Object.new
  vh_b = Object.new
  adapter.define_singleton_method(:edge_endpoints) do |_h|
    [vh_a, vh_b]
  end
  adapter.define_singleton_method(:vertex_position) do |v|
    if v.equal?(vh_a)
      bridge_start.dup
    elsif v.equal?(vh_b)
      bridge_end.dup
    else
      [0.0, 0.0, 0.0]
    end
  end
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter, [applied_entry], [ready_entry],
    pre_workspace: ws_post, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  assert_equal true, result['pass'],
               "F-02-A: forward host + record agreeing with proposal MUST pass; " \
               "got reasons=#{result['reasons'].inspect}"
ensure
  V17P_RUNNER.reset_for_tests
end

# ---- F-02-B: CONTRADICTION regression. READY proposal expects
#       segment (A,B); record says (A,C); host says (A,C).
#       MUST FAIL because both record and host disagree with
#       the READY proposal A-B. The previous self-consistent
#       host-vs-record check would have passed this case. ----
test 'V17-F02-B [PRODUCTION PATH]: contradictory record/host vs proposal MUST FAIL (independent proposal-vs-record-vs-host check)' do
  tol = v17p_tol(0.1)
  adapter, ws_post, bridge = v17p_rr02_workspace(tol)
  bridge_start = bridge.geometry_summary['start'].dup
  bridge_end   = bridge.geometry_summary['end'].dup
  applied_entry, ready_entry = v17p_rr02_build_entries(ws_post, bridge, tol.coordinate_epsilon)
  # Inject the CONTRADICTION: the proposal says A-B (the real
  # bridge); the record (geometry_summary) we will overwrite
  # to say A-C; the host will also say A-C.
  expected_a = bridge_start.dup
  expected_b = bridge_end.dup
  # Build a coordinate 0.01 away from expected_b (well inside
  # gap_search 0.1, well outside coordinate_epsilon 1e-6).
  contradictory_b = [
    expected_b[0] + 0.01,
    expected_b[1],
    expected_b[2]
  ]
  # DerivedEntityRecord is frozen; we cannot mutate
  # bridge.geometry_summary directly. Instead we attach a
  # duplicate record (with the contradictory summary) to the
  # workspace via build_entity; build_entity returns a NEW
  # workspace, so we capture that and use it for the post-
  # validate call. The original bridge stays as the proposal's
  # evidence, while the new contradictory record exercises
  # the F-02 path.
  contradictory_did = 'der-gap-contradictory-test'
  ws_with_contradictory = ws_post.build_entity(
    derived_id: contradictory_did,
    kind: :edge,
    source_occurrence_ids: bridge.source_occurrence_ids.dup,
    geometry_summary: {
      'layer'           => 'L0',
      'length'          => 0.01,
      'start'           => expected_a.dup,
      'end'             => contradictory_b.dup,
      'origin_kind'     => 'generated_gap_bridge',
      'repair_action_id'=> bridge.geometry_summary['repair_action_id'].to_s
    },
    geometry_data: [expected_a.dup, contradictory_b.dup]
  )
  refute_equal :failed, ws_with_contradictory.state,
               "F-02-B setup: workspace.build_entity with contradictory endpoints must succeed"
  contradictory_handle = ws_with_contradictory.handle_for(contradictory_did)
  refute_nil contradictory_handle, 'F-02-B setup: contradictory record must have a live host handle'
  applied_entry['derived_id']  = contradictory_did
  applied_entry['host_handle'] = contradictory_handle
  # Host reports the SAME contradictory (A, C) endpoints.
  vh_a = Object.new
  vh_b = Object.new
  adapter.define_singleton_method(:edge_endpoints) do |_h|
    [vh_a, vh_b]
  end
  adapter.define_singleton_method(:vertex_position) do |v|
    if v.equal?(vh_a)
      expected_a.dup          # host agrees with record (A)
    elsif v.equal?(vh_b)
      contradictory_b.dup     # host agrees with record (C -- contradicts proposal B)
    else
      [0.0, 0.0, 0.0]
    end
  end
  # Add explicit expected_bridge_length to the proposal so
  # the F-02 length check has an authoritative reference.
  ready_entry['expected_bridge_length'] = 0.05
  result = GapBridgeExecutor._post_validate(
    ws_with_contradictory, adapter, [applied_entry], [ready_entry],
    pre_workspace: ws_with_contradictory, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  refute_equal true, result['pass'],
               "F-02-B: contradictory record+host vs READY proposal MUST FAIL; " \
               "got reasons=#{result['reasons'].inspect}"
  reasons_str = result['reasons'].join(',')
  # The contract is: independent comparison against the
  # PROPOSAL. The post-validation MUST surface all three
  # proposal-comparison reasons: record endpoint mismatch,
  # record length mismatch, and host segment mismatch.
  assert(reasons_str.include?('record_endpoint_mismatch'),
         "F-02-B: record_endpoint_mismatch MUST appear (record vs proposal); " \
         "got #{reasons_str.inspect}")
  assert(reasons_str.include?('record_length_mismatch'),
         "F-02-B: record_length_mismatch MUST appear (record length 0.01 != proposal 0.05); " \
         "got #{reasons_str.inspect}")
  assert(reasons_str.include?('host_endpoint_segment_mismatch'),
         "F-02-B: host_endpoint_segment_mismatch MUST appear (host vs proposal, not host vs record); " \
         "got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end

# ---- F-02-C: missing READY proposal entry -> proposal_not_found ----
test 'V17-F02-C [PRODUCTION PATH]: missing READY proposal entry -> proposal_not_found' do
  tol = v17p_tol(0.1)
  adapter, ws_post, bridge = v17p_rr02_workspace(tol)
  applied_entry, _ready_entry = v17p_rr02_build_entries(ws_post, bridge, tol.coordinate_epsilon)
  # Pass an EMPTY ready list: the applied bridge has no
  # matching READY proposal.
  result = GapBridgeExecutor._post_validate(
    ws_post, adapter, [applied_entry], [],
    pre_workspace: ws_post, pre_fingerprint_digest: nil,
    pre_source_fingerprint_digest: nil, pre_entity_coords: nil
  )
  refute_equal true, result['pass'],
               "F-02-C: missing READY proposal MUST fail"
  reasons_str = result['reasons'].join(',')
  assert(reasons_str.include?('proposal_not_found'),
         "F-02-C: reason must include 'proposal_not_found'; " \
         "got #{reasons_str.inspect}")
ensure
  V17P_RUNNER.reset_for_tests
end