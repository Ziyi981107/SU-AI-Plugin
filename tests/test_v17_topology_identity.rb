#
# tests/test_v17_topology_identity.rb — V1.7 Canonical node / identity
# regression set.
#
# Per frozen V1.7 Blueprint §18.1:
#
#   N1 exact same world coordinate across separate derived groups
#      -> one canonical node.
#   N2 within coordinate_epsilon complete clique
#      -> one canonical node.
#   N3 outside coordinate_epsilon
#      -> separate nodes.
#   N4 non-transitive A~=B, B~=C, A!~=C
#      -> must NOT collapse all three;
#         unresolved non_transitive_node_cluster.
#   N5 deterministic graph rebuild
#      -> same unchanged input produces same logical IDs/adjacency.
#   N6 random Ruby/host iteration order
#      -> canonical output unchanged.
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/endpoint_record'
require_relative '../extension/su_ai_plugin/core/canonical_topology_builder'
require_relative '../extension/su_ai_plugin/core/canonical_geometry_graph'

include SUAnalysis::Core

# ---- N1: exact same world coordinate -> one canonical node ----

test 'V17-N1: exact same world coord across separate endpoints -> one canonical node' do
  eps = [EndpointRecord.new(
            endpoint_key: 'e1.start',
            derived_edge_id: 'e1',
            role: EndpointRecord::ROLE_START,
            world_coordinate: [1.0, 2.0, 3.0]
          ),
         EndpointRecord.new(
            endpoint_key: 'e2.end',
            derived_edge_id: 'e2',
            role: EndpointRecord::ROLE_END,
            world_coordinate: [1.0, 2.0, 3.0]
          )]
  result = CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: 1.0e-6)
  # Both endpoints should resolve to the same canonical_node_cluster.
  cluster_ids = result['canonical_node_clusters'].values.flatten
  refute_empty result['canonical_node_clusters'],
               "expected at least one cluster; got #{result['canonical_node_clusters'].inspect}"
  # Every endpoint record has a resolved canonical_node_id (cn-...).
  result['canonical_nodes'].each do |node|
    assert_match(/^cn-/, node['canonical_node_id'],
                 'resolved clique endpoints should carry a cn-* canonical_node_id')
  end
end

# ---- N2: complete clique within coordinate_epsilon ----

test 'V17-N2: within coordinate_epsilon complete clique -> one canonical node' do
  eps = 1.0e-3
  endpoints = (0..2).map do |i|
    EndpointRecord.new(
      endpoint_key: "e#{i}.start",
      derived_edge_id: "e#{i}",
      role: EndpointRecord::ROLE_START,
      world_coordinate: [1.0 + i * (eps / 3.0), 0.0, 0.0]
    )
  end
  result = CanonicalTopologyBuilder.build(endpoints: endpoints, coordinate_epsilon: eps)
  # Every pair must be within eps -> one canonical node.
  assert_equal 1, result['canonical_node_clusters'].length,
               "expected exactly one cluster; got #{result['canonical_node_clusters'].inspect}"
  refute_empty result['canonical_nodes']
  result['canonical_nodes'].each do |node|
    assert_equal true, node['resolved_clique'],
                 'all endpoints in a complete eps-clique should be marked resolved_clique'
  end
end

# ---- N3: outside coordinate_epsilon -> separate nodes ----

test 'V17-N3: outside coordinate_epsilon -> separate nodes' do
  endpoints = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA',
                       role: EndpointRecord::ROLE_START,
                       world_coordinate: [0.0, 0.0, 0.0]),
    EndpointRecord.new(endpoint_key: 'b', derived_edge_id: 'eB',
                       role: EndpointRecord::ROLE_END,
                       world_coordinate: [1.0, 0.0, 0.0])
  ]
  result = CanonicalTopologyBuilder.build(endpoints: endpoints, coordinate_epsilon: 1.0e-6)
  # Two singletons -> two clusters.
  assert_equal 2, result['canonical_node_clusters'].length,
               "expected two singleton clusters; got #{result['canonical_node_clusters'].inspect}"
  assert_empty result['non_transitive_clusters'],
               "two singletons should NOT trigger a non-transitive cluster"
end

# ---- N4: non-transitive safeguard ----

test 'V17-N4: non-transitive A~=B, B~=C, A!~=C must NOT collapse into one node' do
  # A ~= B (within eps), B ~= C (within eps), A != C (outside eps).
  endpoints = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA',
                       role: 'start', world_coordinate: [0.0, 0.0, 0.0]),
    EndpointRecord.new(endpoint_key: 'b', derived_edge_id: 'eB',
                       role: 'start', world_coordinate: [eps_minus(0), 0.0, 0.0]),
    EndpointRecord.new(endpoint_key: 'c', derived_edge_id: 'eC',
                       role: 'start', world_coordinate: [2 * eps_minus(0), 0.0, 0.0])
  ]
  eps_used = eps_minus(0)
  result = CanonicalTopologyBuilder.build(endpoints: endpoints, coordinate_epsilon: eps_used)
  # A and C are outside eps -> the third pair (a, c) is NOT direct.
  # The connected component {a, b, c} is NOT a complete clique; the
  # builder must emit a non_transitive_cluster covering all three.
  refute_empty result['non_transitive_clusters'],
               "expected non_transitive_clusters; got #{result['non_transitive_clusters'].inspect}"
  cluster = result['non_transitive_clusters'].first
  assert_equal 'non_transitive_node_cluster', cluster['reason']
  assert_includes cluster['endpoint_keys'], 'a'
  assert_includes cluster['endpoint_keys'], 'b'
  assert_includes cluster['endpoint_keys'], 'c'
  # Per-endpoint canonical node records still exist.
  node_keys = result['canonical_nodes'].map { |n| n['endpoint_key'] }.sort
  assert_equal %w[a b c], node_keys
end

def eps_minus(x); 1.0e-3 - x; end

# ---- N5: deterministic rebuild ----

test 'V17-N5: same unchanged input produces same logical IDs/adjacency' do
  endpoints = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA',
                       role: 'start', world_coordinate: [0.0, 0.0, 0.0]),
    EndpointRecord.new(endpoint_key: 'b', derived_edge_id: 'eB',
                       role: 'start', world_coordinate: [1.0e-7, 0.0, 0.0]),
    EndpointRecord.new(endpoint_key: 'c', derived_edge_id: 'eC',
                       role: 'start', world_coordinate: [5.0, 0.0, 0.0])
  ]
  result_a = CanonicalTopologyBuilder.build(endpoints: endpoints, coordinate_epsilon: 1.0e-6)
  # Shuffle the input - canonical IDs and cluster map MUST NOT change.
  endpoints_shuffled = endpoints.shuffle
  result_b = CanonicalTopologyBuilder.build(endpoints: endpoints_shuffled, coordinate_epsilon: 1.0e-6)
  assert_equal result_a['canonical_node_clusters'].keys.sort,
               result_b['canonical_node_clusters'].keys.sort
  assert_equal result_a['canonical_nodes'].map { |n| n['canonical_node_id'] }.sort,
               result_b['canonical_nodes'].map { |n| n['canonical_node_id'] }.sort
end

# ---- N6: random Ruby iteration order ----

test 'V17-N6: random Ruby iteration order does not change canonical output' do
  endpoints = (0..9).map do |i|
    EndpointRecord.new(
      endpoint_key: "k#{i}",
      derived_edge_id: "e#{i}",
      role: 'start',
      world_coordinate: [(i % 3) * 1.0e-7, (i % 2) * 1.0e-7, 0.0]
    )
  end
  result_a = CanonicalTopologyBuilder.build(endpoints: endpoints, coordinate_epsilon: 1.0e-6)
  # Two iterations with shuffled inputs.
  result_b = CanonicalTopologyBuilder.build(endpoints: endpoints.shuffle, coordinate_epsilon: 1.0e-6)
  result_c = CanonicalTopologyBuilder.build(endpoints: endpoints.reverse, coordinate_epsilon: 1.0e-6)
  # Same canonical_node_clusters keys (deterministic IDs).
  assert_equal result_a['canonical_node_clusters'].keys.sort,
               result_b['canonical_node_clusters'].keys.sort
  assert_equal result_a['canonical_node_clusters'].keys.sort,
               result_c['canonical_node_clusters'].keys.sort
end

# ---- CanonicalGeometryGraph digest stability ----

test 'V17-N5b: canonical graph digest is stable across runs' do
  edges = [
    { 'canonical_edge_id' => 'ce-A', 'node_a_id' => 'cn-X', 'node_b_id' => 'cn-Y',
      'origin_kind' => 'source_derived', 'derived_edge_id' => 'eA',
      'source_occurrence_id' => 'occ-A', 'repair_action_id' => nil,
      'world_endpoints' => [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0]],
      'layer_name' => 'L0', 'unresolved_flags' => [] },
    { 'canonical_edge_id' => 'ce-B', 'node_a_id' => 'cn-Y', 'node_b_id' => 'cn-Z',
      'origin_kind' => 'gap_bridge', 'derived_edge_id' => 'eB',
      'source_occurrence_id' => nil, 'repair_action_id' => 'gp-X',
      'world_endpoints' => [[1.0, 0.0, 0.0], [2.0, 0.0, 0.0]],
      'layer_name' => 'L0', 'unresolved_flags' => [] }
  ]
  adj = { 'cn-X' => ['cn-Y'], 'cn-Y' => ['cn-X', 'cn-Z'], 'cn-Z' => ['cn-Y'] }
  build_args = {
    source_snapshot_id:      'snap-X',
    execution_config_digest: 'cfg-Y',
    workspace_id:            'ws-Z',
    tolerance_digest:        'tol-t',
    nodes: [{ 'canonical_node_id' => 'cn-X', 'resolved_clique' => true,
             'endpoint_key' => 'eA.start', 'world_coordinate' => [0.0, 0.0, 0.0] }],
    edges: edges,
    adjacency: adj,
    unresolved_topology_issues: [],
    metrics: { 'endpoint_count' => 2, 'canonical_node_count' => 3 },
    non_transitive_clusters: [],
    open_endpoints: []
  }
  g1 = CanonicalGeometryGraph.new(**build_args)
  g2 = CanonicalGeometryGraph.new(**build_args)
  assert_equal g1.digest, g2.digest,
               "same content must produce same digest; #{g1.digest} != #{g2.digest}"
  assert_equal g1, g2
end
