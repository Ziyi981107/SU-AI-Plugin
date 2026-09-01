#
# tests/test_v17_production_gap_path.rb — V1.7 ACTUAL-PRODUCTION-PATH
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
# i.e. exactly what the Simplified-Chinese `检查间隙` / `修复间隙`
# dialog callbacks (`compute_gap_repair` / `apply_gap_repair` in
# dialog_runner.rb) invoke. No crossing / third-node / canonical
# identity / adjacency logic is re-implemented here. The production
# `_crossing_checker_proc` is the ONLY crossing authority exercised.
#
# Blueprint coverage delivered by this file:
#   §18.3 X1  proposed bridge intersects unrelated edge interior
#             -> REVIEW_REQUIRED (production path).
#   §18.3 X2  third canonical node lies on bridge
#             -> REVIEW_REQUIRED (production path).
#   §18.3 X4  real almost-closed triangle missing one short closing
#             segment -> READY_TO_REPAIR (production path).
#   §18.4 H3  multiple independent safe bridges -> ONE native
#             operation, exact bridge count (production path).
#   §18.5 T3  repaired endpoints gain expected adjacency
#             (production path, exact degrees).
#   §18.5 T4  almost-closed triangle becomes a canonical CYCLE
#             (production path, exact cycle invariant — NOT mere
#             BFS connectivity).
#
# Plus explicit regressions for the four production defects this
# dispatch uncovered by actually executing the production path
# (see Review/CURRENT_PI_REPORT.md §B).
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
# Helpers (uniquely prefixed `v17p_` — tests/run_all.rb loads every
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
# derived_id (used to prove Blueprint §14 "existing source-derived
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
# (Blueprint §7.2). Node IDENTITY count is therefore the uniq set.
def v17p_node_ids(graph)
  graph.nodes.map { |n| n['canonical_node_id'].to_s }.uniq
end

def v17p_degrees(graph)
  v17p_node_ids(graph).map { |cid| Array(graph.adjacency[cid]).length }
end

# Map representative world coordinate -> canonical degree.
#
# Canonical node IDs are MEMBERSHIP-derived (Blueprint §7.3: sorted
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

# Deterministic cycle traversal (Blueprint §18.5 T4 exact invariant,
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
# R5 — X1 / X2 through the ACTUAL production crossing logic.
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
# R6 — X4 must be a REAL almost-closed triangle.
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
  # have merged the coincident corners A and B (Blueprint §7.2 /
  # §8) — a per-endpoint (host-vertex-style) degree would wrongly
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
# R7 — Blueprint §18.4 H3: multiple independent safe bridges ->
#      ONE native SketchUp operation + exact generated bridge count.
# ===============================================================

test 'V17-H3: [PRODUCTION PATH, Blueprint §18.4 H3] two independent safe bridges -> ONE begin_operation, ONE commit, zero abort, exactly TWO generated bridges' do
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

  # ONE native SketchUp operation for the whole batch (§12.3).
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
  assert_equal 2, adapter.repair_group_bridges.length,
               "H3: exactly TWO host bridge edges in the workspace-owned repair group; got #{adapter.repair_group_bridges.length}"
  assert_equal pre_coords.length + 2, ws_post.entity_count,
               'H3: the batch must add exactly two derived entities'

  # Both expected proposal IDs / provenance recorded.
  assert_equal expected_ids, Array(audit['applied_proposals']).map(&:to_s).sort,
               "H3: the audit must record BOTH applied proposal IDs; got #{Array(audit['applied_proposals']).inspect}"
  recorded = bridges.map { |b| b.geometry_summary['repair_action_id'].to_s }.sort
  assert_equal expected_ids, recorded,
               "H3: each generated bridge must carry its repair_action_id provenance; got #{recorded.inspect}"

  # Source fingerprint unchanged (§14).
  post_fingerprint = SourceFingerprint.from_snapshot(ws_post.source_snapshot).digest.to_s
  assert_equal pre_fingerprint, post_fingerprint,
               'H3: source fingerprint MUST be unchanged by gap repair'
  # Existing source-derived coordinates unchanged (§14 / §4).
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
# R8 — Blueprint §18.5 T3 / T4 exact adjacency + CYCLE proof.
# ===============================================================

test 'V17-T3: [PRODUCTION PATH, Blueprint §18.5 T3] repaired endpoints gain exactly +1 canonical adjacency each; unrelated nodes unchanged' do
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
  # mutually adjacent (§15.2 rebuilt adjacency).
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

test 'V17-T4: [PRODUCTION PATH, Blueprint §18.5 T4] real almost-closed triangle becomes an ACTUAL canonical cycle (exact degree + deterministic cycle traversal, NOT BFS connectivity)' do
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

  # 2. EXACT cycle invariant (Blueprint §18.5 T4, first accepted
  #    form): n canonical nodes + n canonical edges + EVERY node
  #    degree == 2. For this §2 fixture n == 4 (A, B, C, D) because
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

  # 4. V1.7 stops at nodes + edges + adjacency (Blueprint §15.3):
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

test 'V17-T4-EXACT3: [PRODUCTION PATH, Blueprint §18.5 T4] 3 canonical nodes + 3 canonical edges + every node degree == 2 after the closing bridge' do
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
# by actually executing the production path (report §B).
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
  # production path canonical_node_clusters was {} — coincident
  # corner endpoints were never merged into one canonical node
  # (Blueprint §7.2) and were mis-reported as open (Blueprint §8).
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
  # Blueprint §7.2: "if every pair directly matches within
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
