#
# tests/test_v18_structure_reconstruction.rb — V1.8 base structure
# reconstruction focused tests.
#
# Dispatch: V18-BASE-STRUCTURE-RECONSTRUCTION-2026-09-02.
# Frozen Blueprint:
# Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_8_LOOP_REGION_2026-09-02.md.
#
# This file drives the REAL production entry point:
#   SUAnalysis::Core::CanonicalStructureReconstructor.reconstruct
# so test and production cannot silently diverge. Per Blueprint
# §19 the test matrix is V18-T01..T15. Each test uses a
# deterministic synthetic canonical graph Hash (the JSON-safe
# shape CanonicalGeometryGraph publishes via to_h).
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/canonical_structure_reconstructor'

include SUAnalysis::Core

# ---------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------

# Build a synthetic canonical graph Hash with named nodes
# placed on a Z=0 plane. `topology` is an Array<Array<Float>>
# where each entry is one closed loop (vertices in CCW or CW
# order). The helper synthesizes:
#   - canonical_node_ids: cn-1, cn-2, ...
#   - canonical_edge_ids: ce-1, ce-2, ... (one per consecutive
#     pair, including final->first to close the loop).
#   - canonical adjacency from the edge inventory.
# Returns: { 'nodes' => [...], 'edges' => [...], 'adjacency' =>
# {cid => [nbr_cids sorted]}, 'digest' => 'dummy' }.
def v18_build_graph(loops, edge_layer: 'L0', edge_origin_kind: 'source_derived',
                     coord_eps: 1.0e-6)
  nodes = []
  edges = []
  adjacency = {}
  node_index = {}  # (i,j) -> cid
  next_nid = 1
  next_eid = 1
  loops.each_with_index do |loop, li|
    loop.each_with_index do |(x, y), vi|
      cid = "cn-#{next_nid}"
      node_index[[li, vi]] = cid
      nodes << {
        'canonical_node_id' => cid,
        'endpoint_keys'     => [],
        'derived_edge_ids'  => [],
        'source_occurrence_ids' => [],
        'layer_names'       => [edge_layer],
        'world_coordinate'  => [x, y, 0.0],
        'resolved_clique'   => true,
        'coordinate_epsilon' => coord_eps,
        'membership_count'  => 1
      }
      adjacency[cid] = []
      next_nid += 1
    end
  end
  loops.each_with_index do |loop, li|
    n = loop.length
    next if n < 2
    (0...n).each do |i|
      from = node_index[[li, i]]
      to   = node_index[[li, (i + 1) % n]]
      eid  = "ce-#{next_eid}"
      next_eid += 1
      sx, sy = loop[i]
      ex, ey = loop[(i + 1) % n]
      edges << {
        'canonical_edge_id' => eid,
        'node_a_id' => from,
        'node_b_id' => to,
        'origin_kind' => edge_origin_kind,
        'derived_edge_id' => "der-#{eid}",
        'source_occurrence_id' => "occ-#{li}-#{i}",
        'source_occurrence_ids' => ["occ-#{li}-#{i}"],
        'repair_action_id' => '',
        'world_endpoints' => [[sx, sy, 0.0], [ex, ey, 0.0]],
        'layer_name' => edge_layer,
        'unresolved_flags' => []
      }
      (adjacency[from] ||= []) << to
      (adjacency[to]   ||= []) << from
    end
  end
  {
    'schema_version' => 'cgg.v1',
    'source_snapshot_id' => 'snap-v18-test',
    'execution_config_digest' => 'ec-v18-test',
    'workspace_id' => 'ws-v18-test',
    'nodes' => nodes,
    'edges' => edges,
    'adjacency' => adjacency,
    'unresolved_topology_issues' => [],
    'metrics' => {},
    'non_transitive_clusters' => [],
    'open_endpoints' => [],
    'tolerance_digest' => 'tol-v18-test',
    'digest' => 'graph-digest-v18-test'
  }
end

def v18_reconstruct(loops, **kw)
  CanonicalStructureReconstructor.reconstruct(
    v18_build_graph(loops, **kw),
    source_snapshot_id: 'snap-v18-test',
    workspace_id: 'ws-v18-test'
  )
end

# ================================================================= = #
# V18-T01 — single open polyline.
# ================================================================= = #

test 'V18-T01: single open polyline -> 1 open chain, 0 loops, 0 regions' do
  # Three collinear points on X axis -> 2 edges -> 2 degree-1
  # terminals + 1 degree-2 internal.
  # Use the helper with explicit edge construction (no closure).
  nodes = [
    {'canonical_node_id' => 'cn-A', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-B', 'world_coordinate' => [5.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-C', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-A', 'node_b_id' => 'cn-B',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'der-1',
     'source_occurrence_id' => 'occ-1', 'source_occurrence_ids' => ['occ-1'],
     'repair_action_id' => '', 'world_endpoints' => [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-B', 'node_b_id' => 'cn-C',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'der-2',
     'source_occurrence_id' => 'occ-2', 'source_occurrence_ids' => ['occ-2'],
     'repair_action_id' => '', 'world_endpoints' => [[5.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  adjacency = {
    'cn-A' => ['cn-B'], 'cn-B' => ['cn-A', 'cn-C'], 'cn-C' => ['cn-B']
  }
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adjacency,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-1'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal 1, result['metrics']['open_chain_count'],
               "V18-T01: expected 1 open_chain_count; got #{result['metrics']}"
  assert_equal 0, result['metrics']['closed_loop_count'],
               "V18-T01: expected 0 closed_loop_count"
  assert_equal 0, result['metrics']['region_count'],
               "V18-T01: expected 0 region_count"
  assert_equal 1, result['chains'].length
  chain = result['chains'].first
  # Lex-smaller terminal first.
  assert_equal 'cn-A', chain['start_node_id'],
               "V18-T01: chain start_node_id should be lex-smaller of 'cn-A'/'cn-C'; got #{chain['start_node_id']}"
  assert_equal 'cn-C', chain['end_node_id'],
               "V18-T01: chain end_node_id should be 'cn-C'"
  assert_equal false, chain['closed']
  assert_equal 10.0, chain['length'],
               "V18-T01: chain length should be 10.0; got #{chain['length']}"
end
# ================================================================= = #
# V18-T02 — simple rectangle -> 1 loop, 1 region, 0 holes.
# ================================================================= = #

test 'V18-T02: simple rectangle -> 0 chains, 1 valid loop, 1 region, 0 holes' do
  result = v18_reconstruct([[[0.0, 0.0], [10.0, 0.0], [10.0, 5.0], [0.0, 5.0]]])
  assert_equal 0, result['metrics']['open_chain_count'],
               "V18-T02: 0 open chains; got #{result['metrics']}"
  assert_equal 1, result['metrics']['closed_loop_count'],
               "V18-T02: 1 closed loop; got #{result['metrics']}"
  assert_equal 1, result['metrics']['region_count'],
               "V18-T02: 1 region; got #{result['metrics']}"
  assert_equal 0, result['metrics']['hole_count'],
               "V18-T02: 0 holes; got #{result['metrics']}"
  assert_equal 0, result['metrics']['invalid_loop_count'],
               "V18-T02: 0 invalid loops; got #{result['metrics']}"
  loop = result['loops'].first
  refute_nil loop
  assert_equal true, loop['valid_for_region']
  assert_equal 4, loop['node_ids'].length
  assert_equal 'CCW', loop['winding'],
               "V18-T02: rectangle (CCW) winding should be CCW; got #{loop['winding']}"
  assert_in_delta 50.0, loop['area_xy'], 1.0e-3,
                  "V18-T02: 10x5 = 50.0 area_xy; got #{loop['area_xy']}"
end

# ================================================================= = #
# V18-T03 — triangle containing a canonical gap_bridge.
# ================================================================= = #

test 'V18-T03: triangle containing gap_bridge retains plural provenance union' do
  nodes = (1..3).map { |i|
    coords = [[0.0, 0.0], [10.0, 0.0], [5.0, 8.0]][i - 1]
    {
      'canonical_node_id' => "cn-#{i}", 'world_coordinate' => coords + [0.0],
      'endpoint_keys' => [], 'derived_edge_ids' => [],
      'source_occurrence_ids' => [], 'layer_names' => ['L0'],
      'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
      'membership_count' => 1
    }
  }
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'der-1',
     'source_occurrence_id' => 'occ-src-1', 'source_occurrence_ids' => ['occ-src-1'],
     'repair_action_id' => '', 'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'gap_bridge', 'derived_edge_id' => 'der-gap-2',
     'source_occurrence_id' => 'occ-bridge-a',
     'source_occurrence_ids' => ['occ-bridge-a', 'occ-bridge-b'],
     'repair_action_id' => 'rep-2',
     'world_endpoints' => [[10.0, 0.0, 0.0], [5.0, 8.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-3', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'der-3',
     'source_occurrence_id' => 'occ-src-3', 'source_occurrence_ids' => ['occ-src-3'],
     'repair_action_id' => '', 'world_endpoints' => [[5.0, 8.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  adjacency = {
    'cn-1' => ['cn-2', 'cn-3'], 'cn-2' => ['cn-1', 'cn-3'], 'cn-3' => ['cn-2', 'cn-1']
  }
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adjacency,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol', 'digest' => 'g-3'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal 1, result['metrics']['closed_loop_count'],
               "V18-T03: triangle has 1 closed loop; got #{result['metrics']}"
  assert_equal 1, result['metrics']['region_count'],
               "V18-T03: triangle with gap_bridge -> 1 region; got #{result['metrics']}"
  occ = result['loops'].first['source_occurrence_ids']
  expected = %w[occ-bridge-a occ-bridge-b occ-src-1 occ-src-3]
  assert_equal expected, occ,
               "V18-T03: plural provenance union (sorted/uniq); got #{occ.inspect}"
end

# ================================================================= = #
# V18-T04 — outer + inner rectangle -> 2 loops, 1 region, 1 hole.
# ================================================================= = #

test 'V18-T04: outer + inner rectangle -> 2 loops, 1 region, 1 hole' do
  result = v18_reconstruct([
    [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0]],
    [[3.0, 3.0], [7.0, 3.0], [7.0, 7.0], [3.0, 7.0]]
  ])
  assert_equal 2, result['metrics']['closed_loop_count'],
               "V18-T04: 2 closed loops; got #{result['metrics']}"
  assert_equal 1, result['metrics']['region_count'],
               "V18-T04: 1 outer region; got #{result['metrics']}"
  assert_equal 1, result['metrics']['hole_count'],
               "V18-T04: 1 hole; got #{result['metrics']}"
  region = result['regions'].first
  refute_nil region
  assert_equal 1, region['hole_loop_ids'].length,
               "V18-T04: region should have 1 hole_loop_id"
  assert_in_delta 84.0, region['area_xy'], 1.0e-3,
                  "V18-T04: region area = 100 - 16 = 84; got #{region['area_xy']}"
end

# ================================================================= = #
# V18-T05 — three nested rectangles -> 3 loops, 2 regions.
# ================================================================= = #

test 'V18-T05: three nested rectangles -> 3 loops, 2 regions' do
  result = v18_reconstruct([
    [[0.0, 0.0], [30.0, 0.0], [30.0, 30.0], [0.0, 30.0]],
    [[5.0, 5.0], [25.0, 5.0], [25.0, 25.0], [5.0, 25.0]],
    [[10.0, 10.0], [20.0, 10.0], [20.0, 20.0], [10.0, 20.0]]
  ])
  assert_equal 3, result['metrics']['closed_loop_count'],
               "V18-T05: 3 closed loops; got #{result['metrics']}"
  assert_equal 2, result['metrics']['region_count'],
               "V18-T05: 2 regions (depth 0 outer + depth 2 island); got #{result['metrics']}"
  assert_equal 1, result['metrics']['hole_count'],
               "V18-T05: 1 hole (depth 1); got #{result['metrics']}"
end

# ================================================================= = #
# V18-T06 — bow-tie / self-crossing topology.
# ================================================================= = #

test 'V18-T06: bow-tie closed topology -> self_intersection, no valid region' do
  nodes = (1..4).map { |i|
    coords = [[0.0, 0.0], [10.0, 10.0], [10.0, 0.0], [0.0, 10.0]][i - 1]
    {
      'canonical_node_id' => "cn-#{i}", 'world_coordinate' => coords + [0.0],
      'endpoint_keys' => [], 'derived_edge_ids' => [],
      'source_occurrence_ids' => [], 'layer_names' => ['L0'],
      'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
      'membership_count' => 1
    }
  }
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 10.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 10.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-3', 'node_b_id' => 'cn-4',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 0.0, 0.0], [0.0, 10.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-4', 'node_a_id' => 'cn-4', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-4',
     'source_occurrence_id' => 'o-4', 'source_occurrence_ids' => ['o-4'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 10.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  adjacency = {
    'cn-1' => ['cn-2', 'cn-4'], 'cn-2' => ['cn-1', 'cn-3'],
    'cn-3' => ['cn-2', 'cn-4'], 'cn-4' => ['cn-3', 'cn-1']
  }
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adjacency,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol', 'digest' => 'g-6'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal 1, result['metrics']['closed_loop_count'],
               "V18-T06: bow-tie has 1 closed topology; got #{result['metrics']}"
  assert_equal 0, result['metrics']['region_count'],
               "V18-T06: bow-tie must NOT produce a region; got #{result['metrics']}"
  loop = result['loops'].first
  refute_nil loop
  assert_equal false, loop['valid_for_region'],
               "V18-T06: bow-tie loop must NOT be valid_for_region"
  assert_includes loop['unresolved_flags'],
                  CanonicalStructureReconstructor::REASON_SELF_INTERSECTION,
                  "V18-T06: bow-tie must carry self_intersection flag"
end

# ================================================================= = #
# V18-T07 — self-loop edge.
# ================================================================= = #

test 'V18-T07: self-loop edge -> invalid_graph reason, no false region' do
  nodes = (1..3).map { |i|
    coords = [[0.0, 0.0], [5.0, 0.0], [2.5, 4.0]][i - 1]
    {
      'canonical_node_id' => "cn-#{i}", 'world_coordinate' => coords + [0.0],
      'endpoint_keys' => [], 'derived_edge_ids' => [],
      'source_occurrence_ids' => [], 'layer_names' => ['L0'],
      'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
      'membership_count' => 1
    }
  }
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[5.0, 0.0, 0.0], [2.5, 4.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  adjacency = {
    'cn-1' => ['cn-1', 'cn-2'], 'cn-2' => ['cn-1', 'cn-3'], 'cn-3' => ['cn-2']
  }
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adjacency,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol', 'digest' => 'g-7'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal 0, result['metrics']['region_count'],
               "V18-T07: malformed self-loop must NOT yield a region; got #{result['metrics']}"
  assert(result['reasons'].any? { |r|
    r.to_s.include?(CanonicalStructureReconstructor::REASON_SELF_LOOP_EDGE)
  }, "V18-T07: must emit self_loop_edge reason; got #{result['reasons'].inspect}")
end

# ================================================================= = #
# V18-T08 — T/Y branching component.
# ================================================================= = #

test 'V18-T08: T/Y branching component -> branching_component' do
  nodes = (1..4).map { |i|
    coords = [[0.0, 0.0], [5.0, 0.0], [0.0, 5.0], [-5.0, 0.0]][i - 1]
    {
      'canonical_node_id' => "cn-#{i}", 'world_coordinate' => coords + [0.0],
      'endpoint_keys' => [], 'derived_edge_ids' => [],
      'source_occurrence_ids' => [], 'layer_names' => ['L0'],
      'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
      'membership_count' => 1
    }
  }
  edges = (1..3).map { |i|
    other = i + 1
    {'canonical_edge_id' => "ce-#{i}",
     'node_a_id' => 'cn-1', 'node_b_id' => "cn-#{other}",
     'origin_kind' => 'source_derived', 'derived_edge_id' => "d-#{i}",
     'source_occurrence_id' => "o-#{i}", 'source_occurrence_ids' => ["o-#{i}"],
     'repair_action_id' => '',
     'world_endpoints' => [nodes[0]['world_coordinate'],
                           nodes[other - 1]['world_coordinate']],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  }
  adjacency = {
    'cn-1' => ['cn-2', 'cn-3', 'cn-4'],
    'cn-2' => ['cn-1'], 'cn-3' => ['cn-1'], 'cn-4' => ['cn-1']
  }
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adjacency,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol', 'digest' => 'g-8'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal 0, result['metrics']['open_chain_count'],
               "V18-T08: branching -> 0 chains"
  assert_equal 0, result['metrics']['closed_loop_count'],
               "V18-T08: branching -> 0 loops"
  assert_equal 0, result['metrics']['region_count'],
               "V18-T08: branching -> 0 regions"
  assert_includes result['unresolved_issues'],
                  CanonicalStructureReconstructor::REASON_BRANCHING_COMPONENT,
                  "V18-T08: must emit branching_component"
end

# ================================================================= = #
# V18-T09 — non-planar loop.
# ================================================================= = #

test 'V18-T09: non-planar loop (Z range > eps) -> non_planar_loop, NOT region-valid' do
  nodes = [
    {'canonical_node_id' => 'cn-1', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-2', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-3', 'world_coordinate' => [10.0, 5.0, 1.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-4', 'world_coordinate' => [0.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 0.0, 0.0], [10.0, 5.0, 1.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-3', 'node_b_id' => 'cn-4',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 5.0, 1.0], [0.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-4', 'node_a_id' => 'cn-4', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-4',
     'source_occurrence_id' => 'o-4', 'source_occurrence_ids' => ['o-4'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  adjacency = {
    'cn-1' => ['cn-2', 'cn-4'], 'cn-2' => ['cn-1', 'cn-3'],
    'cn-3' => ['cn-2', 'cn-4'], 'cn-4' => ['cn-3', 'cn-1']
  }
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adjacency,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol', 'digest' => 'g-9'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal 1, result['metrics']['closed_loop_count'],
               "V18-T09: 1 closed loop topology"
  assert_equal 0, result['metrics']['region_count'],
               "V18-T09: non-planar -> 0 regions"
  loop = result['loops'].first
  assert_equal false, loop['valid_for_region'],
               "V18-T09: non-planar loop must NOT be valid_for_region"
  assert_includes loop['unresolved_flags'],
                  CanonicalStructureReconstructor::REASON_NON_PLANAR_LOOP,
                  "V18-T09: must carry non_planar_loop"
end

# ================================================================= = #
# V18-T10 — touching / intersecting loop boundaries -> ambiguous.
# ================================================================= = #

test 'V18-T10: touching loop boundaries -> no false hole' do
  nodes = []
  (1..6).each do |i|
    coords = [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0],
              [20.0, 0.0], [20.0, 10.0]][i - 1]
    nodes << {
      'canonical_node_id' => "cn-#{i}", 'world_coordinate' => coords + [0.0],
      'endpoint_keys' => [], 'derived_edge_ids' => [],
      'source_occurrence_ids' => [], 'layer_names' => ['L0'],
      'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
      'membership_count' => 1
    }
  end
  edges = []
  eid = 0
  [
    ['cn-1', 'cn-2'], ['cn-2', 'cn-3'], ['cn-3', 'cn-4'], ['cn-4', 'cn-1'],
    ['cn-2', 'cn-5'], ['cn-5', 'cn-6'], ['cn-6', 'cn-3'], ['cn-3', 'cn-2']
  ].each do |from, to|
    eid += 1
    fc = nodes.find { |n| n['canonical_node_id'] == from }['world_coordinate']
    tc = nodes.find { |n| n['canonical_node_id'] == to }['world_coordinate']
    edges << {
      'canonical_edge_id' => "ce-#{eid}",
      'node_a_id' => from, 'node_b_id' => to,
      'origin_kind' => 'source_derived', 'derived_edge_id' => "d-#{eid}",
      'source_occurrence_id' => "o-#{eid}", 'source_occurrence_ids' => ["o-#{eid}"],
      'repair_action_id' => '',
      'world_endpoints' => [fc, tc],
      'layer_name' => 'L0', 'unresolved_flags' => []
    }
  end
  adjacency = {
    'cn-1' => ['cn-2', 'cn-4'],
    'cn-2' => ['cn-1', 'cn-3', 'cn-5'],
    'cn-3' => ['cn-2', 'cn-4', 'cn-6'],
    'cn-4' => ['cn-3', 'cn-1'],
    'cn-5' => ['cn-2', 'cn-6'],
    'cn-6' => ['cn-5', 'cn-3']
  }
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adjacency,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol', 'digest' => 'g-10'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal 0, result['metrics']['hole_count'],
               "V18-T10: touching boundaries -> 0 holes; got #{result['metrics']}"
end

# ================================================================= = #
# V18-T11 — forward/reverse/shuffle determinism.
# ================================================================= = #

test 'V18-T11: forward / reverse / shuffled node+edge input -> exact-equal payload + identical digest' do
  ids = %w[cn-A cn-B cn-C cn-D]
  coord_by_id = {
    'cn-A' => [0.0, 0.0],
    'cn-B' => [10.0, 0.0],
    'cn-C' => [10.0, 5.0],
    'cn-D' => [0.0, 5.0]
  }
  # Build the canonical edges in a fixed order, with
  # fixed canonical_edge_ids, then reorder the resulting
  # edge Hashes in the input array. The graph CONTENT
  # (node id -> world coord + edge id -> endpoints) is
  # invariant under reordering; only the input array
  # order changes. This is the true shuffle test.
  canonical_edge_specs = [
    { 'ce-1' => ['cn-A', 'cn-B', [0.0, 0.0], [10.0, 0.0]] },
    { 'ce-2' => ['cn-B', 'cn-C', [10.0, 0.0], [10.0, 5.0]] },
    { 'ce-3' => ['cn-C', 'cn-D', [10.0, 5.0], [0.0, 5.0]] },
    { 'ce-4' => ['cn-D', 'cn-A', [0.0, 5.0], [0.0, 0.0]] }
  ]
  make_node = ->(id, x, y) {
    {'canonical_node_id' => id, 'world_coordinate' => [x, y, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  }
  make_edge = ->(spec) {
    eid, rest = spec.first
    a, b, pa, pb = rest
    {'canonical_edge_id' => eid,
     'node_a_id' => a, 'node_b_id' => b,
     'origin_kind' => 'source_derived', 'derived_edge_id' => "d-#{eid}",
     'source_occurrence_id' => "o-#{eid}", 'source_occurrence_ids' => ["o-#{eid}"],
     'repair_action_id' => '',
     'world_endpoints' => [pa + [0.0], pb + [0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  }
  build_graph = lambda do |nodes_in, specs_in|
    edges_in = specs_in.map { |s| make_edge.call(s) }
    adj = Hash.new { |h, k| h[k] = [] }
    edges_in.each do |e|
      adj[e['node_a_id']] << e['node_b_id']
      adj[e['node_b_id']] << e['node_a_id']
    end
    adj.each_value { |v| v.sort! }
    {
      'schema_version' => 'cgg.v1',
      'nodes' => nodes_in, 'edges' => edges_in, 'adjacency' => adj,
      'unresolved_topology_issues' => [],
      'metrics' => {}, 'non_transitive_clusters' => [],
      'open_endpoints' => [], 'tolerance_digest' => 'tol', 'digest' => 'g-11'
    }
  end
  node_orders = [
    ids.sort,
    ids.sort.reverse,
    [ids[2], ids[0], ids[3], ids[1]]
  ]
  # Reorder the SAME canonical_edge_specs (same
  # canonical_edge_id -> pair) in different orders.
  edge_orders = [
    canonical_edge_specs,
    canonical_edge_specs.reverse,
    [canonical_edge_specs[2], canonical_edge_specs[0],
     canonical_edge_specs[3], canonical_edge_specs[1]]
  ]
  results = node_orders.zip(edge_orders).map do |node_ids, specs|
    nlist = node_ids.map { |id| make_node.call(id, *coord_by_id.fetch(id)) }
    graph = build_graph.call(nlist, specs)
    r = CanonicalStructureReconstructor.reconstruct(
      graph, source_snapshot_id: 's', workspace_id: 'w'
    )
    r
  end
  base = results.first
  results.drop(1).each_with_index do |r, i|
    assert_equal base['chains'], r['chains'],
                 "V18-T11[#{i}]: chains must be EXACTLY equal"
    assert_equal base['loops'], r['loops'],
                 "V18-T11[#{i}]: loops must be EXACTLY equal"
    assert_equal base['regions'], r['regions'],
                 "V18-T11[#{i}]: regions must be EXACTLY equal"
    assert_equal base['digest'], r['digest'],
                 "V18-T11[#{i}]: digest must be IDENTICAL"
  end
end

# ================================================================= = #
# V18-T12 — source_occurrence_ids plural union sorted/uniq.
# ================================================================= = #

test 'V18-T12: source_occurrence_ids plural union deterministic sorted/uniq' do
  result = v18_reconstruct([[[0.0, 0.0], [10.0, 0.0], [10.0, 5.0], [0.0, 5.0]]])
  loop = result['loops'].first
  refute_nil loop
  occ = loop['source_occurrence_ids']
  assert_equal occ.sort, occ,
               "V18-T12: loop source_occurrence_ids must be sorted"
  assert_equal occ.uniq, occ,
               "V18-T12: loop source_occurrence_ids must be uniq"
  region = result['regions'].first
  refute_nil region
  r_occ = region['source_occurrence_ids']
  assert_equal r_occ.sort, r_occ,
               "V18-T12: region source_occurrence_ids must be sorted"
end

# ================================================================= = #
# V18-T13 — invalid graph missing node ref.
# ================================================================= = #

test 'V18-T13: invalid graph (missing node ref) -> FAILED, stable reason' do
  nodes = [
    {'canonical_node_id' => 'cn-1', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-MISSING',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  adjacency = { 'cn-1' => [] }
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adjacency,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol', 'digest' => 'g-13'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal 'FAILED', result['state'],
               "V18-T13: state must be FAILED; got #{result['state']}"
  assert(result['reasons'].any? { |r|
    r.to_s.include?(CanonicalStructureReconstructor::REASON_MISSING_NODE_REFERENCE) ||
    r.to_s.include?(CanonicalStructureReconstructor::REASON_INVALID_GRAPH)
  }, "V18-T13: must emit missing_node_reference / invalid_graph; got #{result['reasons'].inspect}")
end

# ================================================================= = #
# V18-T14 — upstream unresolved topology issue propagation.
# ================================================================= = #

test 'V18-T14: upstream unresolved topology issue propagation' do
  graph = v18_build_graph([[[0.0, 0.0], [10.0, 0.0], [10.0, 5.0], [0.0, 5.0]]])
  graph['unresolved_topology_issues'] = ['non_transitive_node_cluster', 'host_state_changed']
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  propagated = result['unresolved_issues'].select { |u|
    u.to_s.start_with?(CanonicalStructureReconstructor::REASON_UPSTREAM_TOPOLOGY_ISSUE)
  }
  assert_equal 2, propagated.length,
               "V18-T14: both upstream issues must be propagated; got #{propagated.inspect}"
end

# ================================================================= = #
# V18-T15 — long chain + many loops performance smoke.
# ================================================================= = #

test 'V18-T15: long chain + many loops performance smoke' do
  long_nodes = (1..100).map { |i|
    {'canonical_node_id' => "cn-#{i}",
     'world_coordinate' => [i.to_f, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  }
  long_edges = (1...100).map { |i|
    {'canonical_edge_id' => "ce-#{i}",
     'node_a_id' => "cn-#{i}", 'node_b_id' => "cn-#{i + 1}",
     'origin_kind' => 'source_derived', 'derived_edge_id' => "d-#{i}",
     'source_occurrence_id' => "o-#{i}", 'source_occurrence_ids' => ["o-#{i}"],
     'repair_action_id' => '',
     'world_endpoints' => [[i.to_f, 0.0, 0.0], [(i + 1).to_f, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  }
  long_adj = {}
  long_nodes.each { |n| long_adj[n['canonical_node_id']] = [] }
  long_edges.each do |e|
    (long_adj[e['node_a_id']] ||= []) << e['node_b_id']
    (long_adj[e['node_b_id']] ||= []) << e['node_a_id']
  end
  rect_nodes = []
  50.times do |idx|
    bx = (idx % 10) * 200.0
    by = (idx / 10) * 200.0
    base = 101 + idx * 4
    coords = [[100.0, 100.0], [150.0, 100.0], [150.0, 150.0], [100.0, 150.0]]
    4.times do |j|
      rect_nodes << {
        'canonical_node_id' => "cn-rect-#{base + j}",
        'world_coordinate' => [
          bx + coords[j][0], by + coords[j][1], 0.0
        ],
        'endpoint_keys' => [], 'derived_edge_ids' => [],
        'source_occurrence_ids' => [], 'layer_names' => ['L0'],
        'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
        'membership_count' => 1
      }
    end
  end
  rect_edges = []
  rect_adj = {}
  rect_nodes.each { |n| rect_adj[n['canonical_node_id']] = [] }
  50.times do |idx|
    base = 101 + idx * 4
    coords = [[100.0, 100.0], [150.0, 100.0], [150.0, 150.0], [100.0, 150.0]]
    4.times do |j|
      k = (j + 1) % 4
      a = "cn-rect-#{base + j}"
      b = "cn-rect-#{base + k}"
      rect_edges << {
        'canonical_edge_id' => "ce-rect-#{idx}-#{j}",
        'node_a_id' => a, 'node_b_id' => b,
        'origin_kind' => 'source_derived', 'derived_edge_id' => "d-rect-#{idx}-#{j}",
        'source_occurrence_id' => "o-rect-#{idx}-#{j}",
        'source_occurrence_ids' => ["o-rect-#{idx}-#{j}"],
        'repair_action_id' => '',
        'world_endpoints' => [
          [coords[j][0] + (idx % 10) * 200.0,
           coords[j][1] + (idx / 10) * 200.0, 0.0],
          [coords[k][0] + (idx % 10) * 200.0,
           coords[k][1] + (idx / 10) * 200.0, 0.0]
        ],
        'layer_name' => 'L0', 'unresolved_flags' => []
      }
      (rect_adj[a] ||= []) << b
      (rect_adj[b] ||= []) << a
    end
  end
  combined_nodes = long_nodes + rect_nodes
  combined_edges = long_edges + rect_edges
  combined_adj = long_adj.merge(rect_adj) { |_k, a, b| (a + b).uniq.sort }
  combined_graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => combined_nodes, 'edges' => combined_edges, 'adjacency' => combined_adj,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol', 'digest' => 'g-15-big'
  }
  started_at = Time.now
  result = CanonicalStructureReconstructor.reconstruct(
    combined_graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  elapsed = Time.now - started_at
  assert_equal 1, result['metrics']['open_chain_count'],
               "V18-T15: 1 long chain; got #{result['metrics']}"
  assert_equal 50, result['metrics']['closed_loop_count'],
               "V18-T15: 50 closed loops; got #{result['metrics']}"
  assert_equal 50, result['metrics']['region_count'],
               "V18-T15: 50 regions; got #{result['metrics']}"
  assert elapsed < 10.0,
         "V18-T15: performance smoke budget 10s; got #{elapsed}s"
end


# ================================================================= = #
# V18-SR01 — Ruby 2.2 source guard: Array#sum / Enumerable#sum
# is Ruby 2.4+. SketchUp 2017 embeds Ruby 2.2.4. The V1.8
# production code MUST NOT use Array#sum / Enumerable#sum.
# Source-level static guard: scan the V1.8 production file
# and assert NO call to `.sum` (with optional whitespace +
# block/brace) is present in PRODUCTION paths.
# ================================================================= = #

test 'V18-SR01: V1.8 production has NO Array#sum / Enumerable#sum call' do
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/canonical_structure_reconstructor.rb',
      __dir__
    )
  )
  offenders = []
  src.each_line do |line|
    stripped = line.sub(/#.*$/, '')
    cleaned = stripped.gsub(/"[^"]*"/, '').gsub(/'[^']*'/, '')
    if cleaned =~ /\.sum\b/
      offenders << line.strip
    end
  end
  assert_equal [], offenders,
               "V18-SR01: V1.8 production MUST NOT use .sum (Ruby 2.2 SU2017 compat); " \
               "offenders: #{offenders.inspect}"
end

test 'V18-SR01: Array#sum undef still produces hole_count + region_area correctly' do
  Array.send(:remove_method, :sum) if Array.method_defined?(:sum)
  begin
    result = v18_reconstruct([
      [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0]],
      [[3.0, 3.0], [7.0, 3.0], [7.0, 7.0], [3.0, 7.0]]
    ])
    assert_equal 1, result['metrics']['hole_count'],
                 "V18-SR01: hole_count must be 1 even with Array#sum removed"
    assert_equal 1, result['metrics']['region_count'],
                 "V18-SR01: region_count must be 1"
    region = result['regions'].first
    refute_nil region
    expected_area = 100.0 - 16.0
    assert (region['area_xy'] - expected_area).abs < 1.0e-6,
           "V18-SR01: region_area must be outer - sum(holes)"
  ensure
    unless Array.method_defined?(:sum)
      Array.send(:define_method, :sum) do |*args, &block|
        acc = args[0] || 0
        if block
          each { |x| acc += block.call(x) }
        else
          each { |x| acc += x }
        end
        acc
      end
    end
  end
end

# ================================================================= = #
# V18-SR02 — coordinate_epsilon authority.
# Per-loop flags live on loop['unresolved_flags'] (consistent
# with V18-T09).
# ================================================================= = #

test 'V18-SR02: explicit coordinate_epsilon (1e-3) is used verbatim (no silent 1e-6)' do
  graph = v18_build_graph(
    [[[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]],
    coord_eps: 1.0e-6
  )
  graph['nodes'].first['world_coordinate'] = [0.0, 0.0, 5.0e-4]
  result_default = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  loop_default = result_default['loops'].first
  refute_nil loop_default
  assert_includes Array(loop_default['unresolved_flags']),
                  'non_planar_loop',
                  "V18-SR02: default eps (1e-6) must flag z=5e-4 as non-planar"
  assert_equal false, loop_default['valid_for_region'],
               "V18-SR02: non_planar loop must NOT be valid_for_region"
  graph2 = Marshal.load(Marshal.dump(graph))
  graph2['nodes'].first['world_coordinate'] = [0.0, 0.0, 5.0e-4]
  result_eps3 = CanonicalStructureReconstructor.reconstruct(
    graph2, source_snapshot_id: 's', workspace_id: 'w',
    coordinate_epsilon: 1.0e-3
  )
  loop_eps3 = result_eps3['loops'].first
  refute_nil loop_eps3
  refute_includes Array(loop_eps3['unresolved_flags']),
                  'non_planar_loop',
                  "V18-SR02: 1e-3 eps MUST honor captured non-default tolerance"
  assert_equal true, loop_eps3['valid_for_region'],
               "V18-SR02: planar loop under 1e-3 must be valid_for_region"
  assert_equal 1.0e-3, loop_eps3['coordinate_epsilon'],
               "V18-SR02: loop.coordinate_epsilon must equal the explicit 1e-3"
  assert_equal 1.0e-6, loop_default['coordinate_epsilon'],
               "V18-SR02: default loop.coordinate_epsilon must equal the per-node 1e-6"
end

test 'V18-SR02: explicit coordinate_epsilon (1e-5) tightens degenerate-loop detection' do
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => [
      {'canonical_node_id' => 'cn-a', 'world_coordinate' => [0.0, 0.0, 0.0],
       'endpoint_keys' => [], 'derived_edge_ids' => [],
       'source_occurrence_ids' => [], 'layer_names' => ['L0'],
       'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
       'membership_count' => 1},
      {'canonical_node_id' => 'cn-b', 'world_coordinate' => [1.0e-5, 0.0, 0.0],
       'endpoint_keys' => [], 'derived_edge_ids' => [],
       'source_occurrence_ids' => [], 'layer_names' => ['L0'],
       'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
       'membership_count' => 1},
      {'canonical_node_id' => 'cn-c', 'world_coordinate' => [0.0, 2.0e-6, 0.0],
       'endpoint_keys' => [], 'derived_edge_ids' => [],
       'source_occurrence_ids' => [], 'layer_names' => ['L0'],
       'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
       'membership_count' => 1}
    ],
    'edges' => [
      {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-a', 'node_b_id' => 'cn-b',
       'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
       'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
       'repair_action_id' => '',
       'world_endpoints' => [[0.0, 0.0, 0.0], [1.0e-5, 0.0, 0.0]],
       'layer_name' => 'L0', 'unresolved_flags' => []},
      {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-b', 'node_b_id' => 'cn-c',
       'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
       'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
       'repair_action_id' => '',
       'world_endpoints' => [[1.0e-5, 0.0, 0.0], [0.0, 2.0e-6, 0.0]],
       'layer_name' => 'L0', 'unresolved_flags' => []},
      {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-c', 'node_b_id' => 'cn-a',
       'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
       'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
       'repair_action_id' => '',
       'world_endpoints' => [[0.0, 2.0e-6, 0.0], [0.0, 0.0, 0.0]],
       'layer_name' => 'L0', 'unresolved_flags' => []}
    ],
    'adjacency' => {'cn-a' => ['cn-b', 'cn-c'], 'cn-b' => ['cn-a', 'cn-c'],
                    'cn-c' => ['cn-b', 'cn-a']},
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr02-tiny'
  }
  result_default = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  loop_default = result_default['loops'].first
  refute_nil loop_default
  refute_includes Array(loop_default['unresolved_flags']),
                  'degenerate_loop',
                  "V18-SR02: under default 1e-6 the tiny area 1e-11 must NOT be flagged"
  result_eps5 = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w',
    coordinate_epsilon: 1.0e-5
  )
  loop_eps5 = result_eps5['loops'].first
  refute_nil loop_eps5
  assert_includes Array(loop_eps5['unresolved_flags']),
                  'degenerate_loop',
                  "V18-SR02: under 1e-5 the tiny area 1e-11 must be flagged degenerate"
  assert_equal 1.0e-5, loop_eps5['coordinate_epsilon'],
               "V18-SR02: loop.coordinate_epsilon must equal the explicit 1e-5"
  assert_equal 1.0e-6, loop_default['coordinate_epsilon'],
               "V18-SR02: default loop.coordinate_epsilon must equal the per-node 1e-6"
end

test 'V18-SR02: silent 1e-6 fallback ONLY when no captured non-default eps is available' do
  graph = v18_build_graph(
    [[[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]]
  )
  graph['nodes'].each { |n| n['coordinate_epsilon'] = nil }
  graph['nodes'].first['world_coordinate'] = [0.0, 0.0, 5.0e-7]
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  loop = result['loops'].first
  refute_nil loop
  refute_includes Array(loop['unresolved_flags']),
                  'non_planar_loop',
                  "V18-SR02: fallback 1e-6 must permit Z range 5e-7"
  assert_equal 1.0e-6, loop['coordinate_epsilon'],
               "V18-SR02: fallback path MUST emit 1e-6 when no eps authority is available"
end


# ================================================================= = #
# V18-SR04 — O(V + E) traversal via deterministic edge indexes.
# ================================================================= = #

test 'V18-SR04: no comp.combination(2) in V1.8 production traversal' do
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/canonical_structure_reconstructor.rb',
      __dir__
    )
  )
  offenders = []
  src.each_line.with_index(1) do |line, lineno|
    stripped = line.sub(/#.*$/, '')
    cleaned = stripped.gsub(/"[^"]*"/, '').gsub(/'[^']*'/, '')
    if cleaned =~ /comp\.combination\(2\)/
      offenders << "#{lineno}: #{line.strip}"
    end
  end
  assert_equal [], offenders,
               "V18-SR04: V1.8 production MUST NOT use comp.combination(2); " \
               "offenders: #{offenders.inspect}"
end

test 'V18-SR04: parallel edges between the same node pair -> conservative invalid' do
  nodes = [
    {'canonical_node_id' => 'cn-1', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-2', 'world_coordinate' => [1.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-3', 'world_coordinate' => [0.5, 1.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-1b', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1b',
     'source_occurrence_id' => 'o-1b', 'source_occurrence_ids' => ['o-1b'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[1.0, 0.0, 0.0], [0.5, 1.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-3', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.5, 1.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges,
    'adjacency' => {'cn-1' => ['cn-2', 'cn-3'], 'cn-2' => ['cn-1', 'cn-3'],
                    'cn-3' => ['cn-2', 'cn-1']},
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr04-parallel'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal 0, result['metrics']['closed_loop_count'],
               "V18-SR04: parallel edges MUST NOT mint a loop"
  assert_equal 0, result['metrics']['open_chain_count'],
               "V18-SR04: parallel edges MUST NOT mint a chain"
  parallel_present = result['unresolved_issues'].any? { |r|
    r.to_s.start_with?('parallel_edges_unsupported:')
  }
  assert parallel_present,
         "V18-SR04: must report parallel_edges_unsupported; " \
         "got #{result['unresolved_issues'].inspect}"
end

test 'V18-SR04: indexed traversal correctness -- 100 isolated rectangles' do
  loops = (0...100).map do |i|
    bx = (i % 10) * 200.0
    by = (i / 10) * 200.0
    [
      [bx + 0.0, by + 0.0],
      [bx + 10.0, by + 0.0],
      [bx + 10.0, by + 10.0],
      [bx + 0.0, by + 10.0]
    ]
  end
  graph = v18_build_graph(loops, coord_eps: 1.0e-6)
  started_at = Time.now
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  elapsed = Time.now - started_at
  assert_equal 100, result['metrics']['component_count']
  assert_equal 100, result['metrics']['closed_loop_count']
  assert_equal 100, result['metrics']['region_count']
  refute result['unresolved_issues'].any? { |r|
    r.to_s.start_with?('parallel_edges_unsupported:')
  }, "V18-SR04: isolated rectangles must NOT report parallel_edges"
  assert elapsed < 5.0,
         "V18-SR04: 100-rectangle traversal must finish in <5s; " \
         "got #{elapsed}s"
end

test 'V18-SR04: chain walk uses incident index (200-node chain)' do
  nodes = (1..200).map do |i|
    {'canonical_node_id' => "cn-#{i}",
     'world_coordinate' => [i.to_f, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  end
  edges = (1...200).map do |i|
    {'canonical_edge_id' => "ce-#{i}",
     'node_a_id' => "cn-#{i}", 'node_b_id' => "cn-#{i + 1}",
     'origin_kind' => 'source_derived', 'derived_edge_id' => "d-#{i}",
     'source_occurrence_id' => "o-#{i}",
     'source_occurrence_ids' => ["o-#{i}"],
     'repair_action_id' => '',
     'world_endpoints' => [[i.to_f, 0.0, 0.0], [(i + 1).to_f, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  end
  adj = {}
  nodes.each { |n| adj[n['canonical_node_id']] = [] }
  edges.each do |e|
    (adj[e['node_a_id']] ||= []) << e['node_b_id']
    (adj[e['node_b_id']] ||= []) << e['node_a_id']
  end
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adj,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr04-long-chain'
  }
  started_at = Time.now
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  elapsed = Time.now - started_at
  assert_equal 1, result['metrics']['component_count']
  assert_equal 1, result['metrics']['open_chain_count']
  assert_equal 200, result['chains'].first['node_ids'].length
  assert_equal 199, result['chains'].first['edge_ids'].length
  assert elapsed < 5.0,
         "V18-SR04: 200-node chain walk must finish in <5s; " \
         "got #{elapsed}s"
end


# ================================================================= = #
# V18-SR03 — loop conflict detection for NON-ADJACENT loop
# segments. Four kinds:
#   1. proper interior crossing  -> self_intersection
#   2. endpoint on unrelated segment interior (T-junction-like)
#      -> loop_endpoint_on_segment
#   3. collinear interior overlap -> loop_collinear_overlap
# Adjacent pairs (including closure adjacency) MUST be skipped.
# ================================================================= = #

test 'V18-SR03: bow-tie proper crossing -> self_intersection' do
  # X-shaped bow-tie: (0,0)->(10,10)->(10,0)->(0,10)->(0,0).
  # Non-adjacent segments (s0=AB diagonal, s2=CD opposite
  # diagonal) cross at (5,5).
  nodes = [
    {'canonical_node_id' => 'cn-1', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-2', 'world_coordinate' => [10.0, 10.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-3', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-4', 'world_coordinate' => [0.0, 10.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 10.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 10.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-3', 'node_b_id' => 'cn-4',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 0.0, 0.0], [0.0, 10.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-4', 'node_a_id' => 'cn-4', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-4',
     'source_occurrence_id' => 'o-4', 'source_occurrence_ids' => ['o-4'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 10.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges,
    'adjacency' => {'cn-1' => ['cn-2', 'cn-4'], 'cn-2' => ['cn-1', 'cn-3'],
                    'cn-3' => ['cn-2', 'cn-4'], 'cn-4' => ['cn-3', 'cn-1']},
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr03-bowtie'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  loop = result['loops'].first
  refute_nil loop
  assert_includes Array(loop['unresolved_flags']),
                  'self_intersection',
                  "V18-SR03: bow-tie must flag self_intersection; " \
                  "got #{loop['unresolved_flags']}"
  assert_equal false, loop['valid_for_region'],
               "V18-SR03: self-intersecting loop must NOT be valid_for_region"
end

test 'V18-SR03: endpoint on segment interior (T-junction-like) -> loop_endpoint_on_segment' do
  # 6-vertex polygon A=(0,0) B=(10,0) X=(5,0) Y=(5,5)
  # C=(10,10) D=(0,10). Loop: A-B-X-Y-C-D-A.
  # Segment XY has endpoint X=(5,0) which lies on AB's
  # interior (a T-junction-like touch).
  nodes = [
    {'canonical_node_id' => 'cn-a', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-b', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-x', 'world_coordinate' => [5.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-y', 'world_coordinate' => [5.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-c', 'world_coordinate' => [10.0, 10.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-d', 'world_coordinate' => [0.0, 10.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-a', 'node_b_id' => 'cn-b',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-b', 'node_b_id' => 'cn-x',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 0.0, 0.0], [5.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-x', 'node_b_id' => 'cn-y',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[5.0, 0.0, 0.0], [5.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-4', 'node_a_id' => 'cn-y', 'node_b_id' => 'cn-c',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-4',
     'source_occurrence_id' => 'o-4', 'source_occurrence_ids' => ['o-4'],
     'repair_action_id' => '',
     'world_endpoints' => [[5.0, 5.0, 0.0], [10.0, 10.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-5', 'node_a_id' => 'cn-c', 'node_b_id' => 'cn-d',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-5',
     'source_occurrence_id' => 'o-5', 'source_occurrence_ids' => ['o-5'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 10.0, 0.0], [0.0, 10.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-6', 'node_a_id' => 'cn-d', 'node_b_id' => 'cn-a',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-6',
     'source_occurrence_id' => 'o-6', 'source_occurrence_ids' => ['o-6'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 10.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges,
    'adjacency' => {
      'cn-a' => ['cn-b', 'cn-d'], 'cn-b' => ['cn-a', 'cn-x'],
      'cn-x' => ['cn-b', 'cn-y'], 'cn-y' => ['cn-x', 'cn-c'],
      'cn-c' => ['cn-y', 'cn-d'], 'cn-d' => ['cn-c', 'cn-a']
    },
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr03-tjunction'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  loop = result['loops'].first
  refute_nil loop
  assert_includes Array(loop['unresolved_flags']),
                  'loop_endpoint_on_segment',
                  "V18-SR03: T-junction-like must flag loop_endpoint_on_segment; " \
                  "got #{loop['unresolved_flags']}"
end

test 'V18-SR03: collinear interior overlap -> loop_collinear_overlap' do
  # 6-vertex polygon where two NON-ADJACENT edges are collinear
  # and overlap on their interiors.
  # A=(0,0) B=(10,0) C=(10,5) D=(3,5) E=(3,0) F=(-1,0).
  # Loop: A-B-C-D-E-F-A.
  # AB=(0,0)-(10,0) y=0 x=[0,10]. EF=(3,0)-(-1,0) y=0 x=[-1,3].
  # Both collinear (y=0); overlap on x=[0,3] = interior of
  # both. FA-AB is closure-adjacent (share A). Skipped.
  nodes = [
    {'canonical_node_id' => 'cn-a', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-b', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-c', 'world_coordinate' => [10.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-d', 'world_coordinate' => [3.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-e', 'world_coordinate' => [3.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-f', 'world_coordinate' => [-1.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-a', 'node_b_id' => 'cn-b',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-b', 'node_b_id' => 'cn-c',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-c', 'node_b_id' => 'cn-d',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 5.0, 0.0], [3.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-4', 'node_a_id' => 'cn-d', 'node_b_id' => 'cn-e',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-4',
     'source_occurrence_id' => 'o-4', 'source_occurrence_ids' => ['o-4'],
     'repair_action_id' => '',
     'world_endpoints' => [[3.0, 5.0, 0.0], [3.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-5', 'node_a_id' => 'cn-e', 'node_b_id' => 'cn-f',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-5',
     'source_occurrence_id' => 'o-5', 'source_occurrence_ids' => ['o-5'],
     'repair_action_id' => '',
     'world_endpoints' => [[3.0, 0.0, 0.0], [-1.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-6', 'node_a_id' => 'cn-f', 'node_b_id' => 'cn-a',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-6',
     'source_occurrence_id' => 'o-6', 'source_occurrence_ids' => ['o-6'],
     'repair_action_id' => '',
     'world_endpoints' => [[-1.0, 0.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges,
    'adjacency' => {
      'cn-a' => ['cn-b', 'cn-f'], 'cn-b' => ['cn-a', 'cn-c'],
      'cn-c' => ['cn-b', 'cn-d'], 'cn-d' => ['cn-c', 'cn-e'],
      'cn-e' => ['cn-d', 'cn-f'], 'cn-f' => ['cn-e', 'cn-a']
    },
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr03-collinear'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  loop = result['loops'].first
  refute_nil loop
  assert_includes Array(loop['unresolved_flags']),
                  'loop_collinear_overlap',
                  "V18-SR03: collinear interior overlap must flag loop_collinear_overlap; " \
                  "got #{loop['unresolved_flags']}"
end

test 'V18-SR03: normal rectangle -> no false positives' do
  graph = v18_build_graph([[[0.0, 0.0], [10.0, 0.0], [10.0, 5.0], [0.0, 5.0]]])
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  loop = result['loops'].first
  refute_nil loop
  refute_includes Array(loop['unresolved_flags']), 'self_intersection',
                  "V18-SR03: normal rectangle MUST NOT flag self_intersection"
  refute_includes Array(loop['unresolved_flags']), 'loop_endpoint_on_segment',
                  "V18-SR03: normal rectangle MUST NOT flag loop_endpoint_on_segment"
  refute_includes Array(loop['unresolved_flags']), 'loop_collinear_overlap',
                  "V18-SR03: normal rectangle MUST NOT flag loop_collinear_overlap"
  refute_includes Array(loop['unresolved_flags']), 'loop_geometric_touch',
                  "V18-SR03: normal rectangle MUST NOT flag loop_geometric_touch"
  assert_equal true, loop['valid_for_region'],
               "V18-SR03: normal rectangle MUST be valid_for_region"
end


# ================================================================= = #
# V18-SR08 — adjacency validation.
# ================================================================= = #

def v18_sr08_graph_with_adj(adjacency_override)
  nodes = [
    {'canonical_node_id' => 'cn-1', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-2', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-3', 'world_coordinate' => [10.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-4', 'world_coordinate' => [0.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-3', 'node_b_id' => 'cn-4',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-4', 'node_a_id' => 'cn-4', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-4',
     'source_occurrence_id' => 'o-4', 'source_occurrence_ids' => ['o-4'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges,
    'adjacency' => adjacency_override,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr08'
  }
end

test 'V18-SR08: unknown adjacency key -> adjacency_mismatch:unknown_key' do
  adj = {
    'cn-1' => ['cn-2', 'cn-4'],
    'cn-2' => ['cn-1', 'cn-3'],
    'cn-3' => ['cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1'],
    'cn-ghost' => ['cn-1']
  }
  graph = v18_sr08_graph_with_adj(adj)
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-SR08: unknown adjacency key MUST yield FAILED state"
  assert result['reasons'].any? { |r|
    r.to_s.start_with?('invalid_graph:adjacency_mismatch:unknown_key:cn-ghost')
  }, "V18-SR08: must report invalid_graph:adjacency_mismatch:unknown_key:cn-ghost"
end

test 'V18-SR08: unknown neighbor -> adjacency_mismatch:unknown_neighbor' do
  adj = {
    'cn-1' => ['cn-2', 'cn-4', 'cn-phantom'],
    'cn-2' => ['cn-1', 'cn-3'],
    'cn-3' => ['cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1']
  }
  graph = v18_sr08_graph_with_adj(adj)
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_FAILED, result['state']
  assert result['reasons'].any? { |r|
    r.to_s.start_with?('invalid_graph:adjacency_mismatch:unknown_neighbor:cn-1->cn-phantom')
  }, "V18-SR08: must report unknown_neighbor"
end

test 'V18-SR08: missing edge-backed neighbor -> adjacency_mismatch:missing_neighbor' do
  adj = {
    'cn-1' => ['cn-2', 'cn-4'],
    'cn-2' => ['cn-1'],
    'cn-3' => ['cn-4'],
    'cn-4' => ['cn-3', 'cn-1']
  }
  graph = v18_sr08_graph_with_adj(adj)
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_FAILED, result['state']
  assert result['reasons'].any? { |r|
    r.to_s.start_with?('invalid_graph:adjacency_mismatch:missing_neighbor:')
  }, "V18-SR08: must report missing_neighbor"
end

test 'V18-SR08: extra neighbor not backed by edge -> adjacency_mismatch:extra_neighbor' do
  adj = {
    'cn-1' => ['cn-2', 'cn-3', 'cn-4'],
    'cn-2' => ['cn-1', 'cn-3'],
    'cn-3' => ['cn-1', 'cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1']
  }
  graph = v18_sr08_graph_with_adj(adj)
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_FAILED, result['state']
  assert result['reasons'].any? { |r|
    r.to_s.start_with?('invalid_graph:adjacency_mismatch:extra_neighbor:')
  }, "V18-SR08: must report extra_neighbor"
end

test 'V18-SR08: consistent adjacency -> no mismatch reason' do
  adj = {
    'cn-1' => ['cn-2', 'cn-4'],
    'cn-2' => ['cn-1', 'cn-3'],
    'cn-3' => ['cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1']
  }
  graph = v18_sr08_graph_with_adj(adj)
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  refute_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-SR08: consistent adjacency MUST NOT be FAILED"
  refute result['reasons'].any? { |r|
    r.to_s.start_with?('invalid_graph:adjacency_mismatch')
  }, "V18-SR08: consistent adjacency MUST NOT report mismatch"
  assert_equal 1, result['metrics']['closed_loop_count']
end


# ================================================================= = #
# V18-SR07 — deep immutability of published normal
# StructureReconstructionResult.
# ================================================================= = #

test 'V18-SR07: published normal result is fully deep-frozen (outer + nested)' do
  graph = v18_build_graph([
    [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0]],
    [[3.0, 3.0], [7.0, 3.0], [7.0, 7.0], [3.0, 7.0]]
  ])
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  # Outer hash is frozen.
  assert result.frozen?, "V18-SR07: outer result hash MUST be frozen"
  # Top-level collection fields are frozen Arrays.
  assert result['chains'].frozen?, "V18-SR07: result['chains'] MUST be frozen"
  assert result['loops'].frozen?, "V18-SR07: result['loops'] MUST be frozen"
  assert result['regions'].frozen?, "V18-SR07: result['regions'] MUST be frozen"
  assert result['unresolved_issues'].frozen?,
         "V18-SR07: result['unresolved_issues'] MUST be frozen"
  assert result['reasons'].frozen?, "V18-SR07: result['reasons'] MUST be frozen"
  assert result['metrics'].frozen?, "V18-SR07: result['metrics'] MUST be frozen"
  # Each chain / loop / region hash is itself frozen.
  result['chains'].each do |c|
    assert c.frozen?, "V18-SR07: each chain hash MUST be frozen"
    assert c['node_ids'].frozen?, "V18-SR07: chain['node_ids'] MUST be frozen"
    assert c['edge_ids'].frozen?, "V18-SR07: chain['edge_ids'] MUST be frozen"
    assert Array(c['source_occurrence_ids']).frozen?,
           "V18-SR07: chain['source_occurrence_ids'] MUST be frozen"
    assert Array(c['layer_names']).frozen?,
           "V18-SR07: chain['layer_names'] MUST be frozen"
    assert Array(c['unresolved_flags']).frozen?,
           "V18-SR07: chain['unresolved_flags'] MUST be frozen"
  end
  result['loops'].each do |l|
    assert l.frozen?, "V18-SR07: each loop hash MUST be frozen"
    assert l['node_ids'].frozen?, "V18-SR07: loop['node_ids'] MUST be frozen"
    assert l['edge_ids'].frozen?, "V18-SR07: loop['edge_ids'] MUST be frozen"
    assert l['world_coordinates'].frozen?,
           "V18-SR07: loop['world_coordinates'] MUST be frozen"
    # Each coordinate tuple itself is a frozen Array.
    Array(l['world_coordinates']).each do |coord|
      assert coord.frozen?,
             "V18-SR07: each loop world_coordinate tuple MUST be frozen"
    end
    assert l['source_occurrence_ids'].frozen?,
           "V18-SR07: loop['source_occurrence_ids'] MUST be frozen"
    assert l['layer_names'].frozen?,
           "V18-SR07: loop['layer_names'] MUST be frozen"
    assert l['unresolved_flags'].frozen?,
           "V18-SR07: loop['unresolved_flags'] MUST be frozen"
  end
  result['regions'].each do |r|
    assert r.frozen?, "V18-SR07: each region hash MUST be frozen"
    assert r['hole_loop_ids'].frozen?,
           "V18-SR07: region['hole_loop_ids'] MUST be frozen"
  end
end

test 'V18-SR07: nested mutation attempts raise FrozenError and do not change digest' do
  graph = v18_build_graph([
    [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0]]
  ])
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  digest_before = result['digest'].to_s
  # Try mutating outer hash.
  raised = false
  begin
    result['state'] = 'HACKED'
  rescue RuntimeError, FrozenError
    raised = true
  end
  assert raised, "V18-SR07: outer hash mutation MUST raise"
  # Try mutating inner loop['node_ids'].
  loop = result['loops'].first
  refute_nil loop
  raised = false
  begin
    loop['node_ids'] << 'hacked'
  rescue RuntimeError, FrozenError
    raised = true
  end
  assert raised, "V18-SR07: loop['node_ids'] mutation MUST raise"
  # Try mutating loop['world_coordinates'][0].
  raised = false
  begin
    loop['world_coordinates'][0][0] = 999.0
  rescue RuntimeError, FrozenError
    raised = true
  end
  assert raised, "V18-SR07: world_coordinates[0] mutation MUST raise"
  # Try mutating result['unresolved_issues'].
  raised = false
  begin
    result['unresolved_issues'] << 'hacked_reason'
  rescue RuntimeError, FrozenError
    raised = true
  end
  assert raised, "V18-SR07: result['unresolved_issues'] mutation MUST raise"
  # Digest must NOT have changed.
  assert_equal digest_before, result['digest'],
               "V18-SR07: digest MUST NOT change after failed mutations"
end

test 'V18-SR07: empty / failed result is also fully deep-frozen' do
  # Invalid graph (missing node ref) -> _empty_result.
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => [
      {'canonical_node_id' => 'cn-a', 'world_coordinate' => [0.0, 0.0, 0.0],
       'endpoint_keys' => [], 'derived_edge_ids' => [],
       'source_occurrence_ids' => [], 'layer_names' => ['L0'],
       'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
       'membership_count' => 1}
    ],
    'edges' => [
      {'canonical_edge_id' => 'ce-bad', 'node_a_id' => 'cn-a',
       'node_b_id' => 'cn-missing',
       'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-bad',
       'source_occurrence_id' => 'o-bad',
       'source_occurrence_ids' => ['o-bad'],
       'repair_action_id' => '',
       'world_endpoints' => [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0]],
       'layer_name' => 'L0', 'unresolved_flags' => []}
    ],
    'adjacency' => {'cn-a' => ['cn-missing']},
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr07-failed'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert result.frozen?, "V18-SR07: failed result outer hash MUST be frozen"
  assert result['chains'].frozen?, "V18-SR07: failed result chains MUST be frozen"
  assert result['loops'].frozen?, "V18-SR07: failed result loops MUST be frozen"
  assert result['regions'].frozen?, "V18-SR07: failed result regions MUST be frozen"
  assert result['metrics'].frozen?,
         "V18-SR07: failed result metrics MUST be frozen"
  assert result['unresolved_issues'].frozen?,
         "V18-SR07: failed result unresolved_issues MUST be frozen"
end


# ================================================================= = #
# V18-SR06 — truthful state.
#   - invalid graph => FAILED
#   - any unresolved/upstream warning => READY_WITH_WARNINGS
#   - warning-free + content => READY
#   - branch-only => READY_WITH_WARNINGS (NOT READY)
# ================================================================= = #

test 'V18-SR06: branch-only component -> READY_WITH_WARNINGS (NOT READY)' do
  # A Y-shape: 3 edges meeting at one center vertex. This
  # is a branching component (no simple chain / no simple
  # loop). The component must NOT be classified as a chain
  # or loop.
  nodes = [
    {'canonical_node_id' => 'cn-c', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-a', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-b', 'world_coordinate' => [-10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-d', 'world_coordinate' => [0.0, 10.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-ca', 'node_a_id' => 'cn-c', 'node_b_id' => 'cn-a',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-ca',
     'source_occurrence_id' => 'o-ca', 'source_occurrence_ids' => ['o-ca'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-cb', 'node_a_id' => 'cn-c', 'node_b_id' => 'cn-b',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-cb',
     'source_occurrence_id' => 'o-cb', 'source_occurrence_ids' => ['o-cb'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [-10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-cd', 'node_a_id' => 'cn-c', 'node_b_id' => 'cn-d',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-cd',
     'source_occurrence_id' => 'o-cd', 'source_occurrence_ids' => ['o-cd'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [0.0, 10.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges,
    'adjacency' => {
      'cn-c' => ['cn-a', 'cn-b', 'cn-d'],
      'cn-a' => ['cn-c'], 'cn-b' => ['cn-c'], 'cn-d' => ['cn-c']
    },
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr06-branch-only'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  refute_equal CanonicalStructureReconstructor::STATE_READY, result['state'],
               "V18-SR06: branch-only component MUST NOT be READY; got #{result['state']}"
  assert_equal CanonicalStructureReconstructor::STATE_READY_WITH_WARNINGS, result['state'],
               "V18-SR06: branch-only MUST be READY_WITH_WARNINGS; got #{result['state']}"
  assert result['unresolved_issues'].include?('branching_component'),
         "V18-SR06: branch-only MUST carry branching_component reason; " \
         "got #{result['unresolved_issues'].inspect}"
end

test 'V18-SR06: upstream-warning-only -> READY_WITH_WARNINGS (NOT READY)' do
  # A clean simple rectangle PLUS an upstream topology issue
  # propagated from V1.7. The result must surface the
  # upstream warning even though the geometry is clean.
  graph = v18_build_graph([[[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0]]])
  graph['unresolved_topology_issues'] = ['v17_synthetic_propagated_issue']
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  refute_equal CanonicalStructureReconstructor::STATE_READY, result['state'],
               "V18-SR06: upstream-warning-only MUST NOT be READY; got #{result['state']}"
  assert_equal CanonicalStructureReconstructor::STATE_READY_WITH_WARNINGS, result['state'],
               "V18-SR06: upstream-warning-only MUST be READY_WITH_WARNINGS; got #{result['state']}"
  upstream_present = result['unresolved_issues'].any? { |u|
    u.to_s.start_with?('upstream_topology_issue:')
  }
  assert upstream_present,
         "V18-SR06: upstream warning MUST be propagated; got #{result['unresolved_issues'].inspect}"
end

test 'V18-SR06: clean rectangle (no warnings) -> READY' do
  graph = v18_build_graph([[[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0]]])
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_READY, result['state'],
               "V18-SR06: clean rectangle MUST be READY; got #{result['state']}"
  assert_empty result['unresolved_issues'],
               "V18-SR06: clean rectangle MUST have empty unresolved_issues; " \
               "got #{result['unresolved_issues'].inspect}"
end

test 'V18-SR06: invalid graph -> FAILED' do
  # Missing node reference -> validation fail.
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => [
      {'canonical_node_id' => 'cn-a', 'world_coordinate' => [0.0, 0.0, 0.0],
       'endpoint_keys' => [], 'derived_edge_ids' => [],
       'source_occurrence_ids' => [], 'layer_names' => ['L0'],
       'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
       'membership_count' => 1}
    ],
    'edges' => [
      {'canonical_edge_id' => 'ce-bad', 'node_a_id' => 'cn-a',
       'node_b_id' => 'cn-missing',
       'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-bad',
       'source_occurrence_id' => 'o-bad',
       'source_occurrence_ids' => ['o-bad'],
       'repair_action_id' => '',
       'world_endpoints' => [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0]],
       'layer_name' => 'L0', 'unresolved_flags' => []}
    ],
    'adjacency' => {'cn-a' => ['cn-missing']},
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr06-invalid'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-SR06: invalid graph MUST be FAILED; got #{result['state']}"
end

test 'V18-SR06: invalid adjacency (adjacency_mismatch) -> FAILED' do
  # SR18-08 produces STATE_FAILED when adjacency mismatches
  # edge inventory. SR18-06 truthful state must reflect
  # this as FAILED, not READY_WITH_WARNINGS.
  adj = {
    'cn-1' => ['cn-2', 'cn-4'],
    'cn-2' => ['cn-1', 'cn-3'],
    'cn-3' => ['cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1'],
    'cn-ghost' => ['cn-1']
  }
  nodes = [
    {'canonical_node_id' => 'cn-1', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-2', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-3', 'world_coordinate' => [10.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-4', 'world_coordinate' => [0.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-3', 'node_b_id' => 'cn-4',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-4', 'node_a_id' => 'cn-4', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-4',
     'source_occurrence_id' => 'o-4', 'source_occurrence_ids' => ['o-4'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adj,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-sr06-failed'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-SR06: adjacency_mismatch MUST be FAILED; got #{result['state']}"
end


# ================================================================= = #
# V18-FR01 — FR18-01 (epsilon authority) focused regressions.
#
# Per dispatch V18-FINAL-FOUR-RESIDUALS-2026-09-03:
#   - any explicit finite positive `coordinate_epsilon:` wins
#     verbatim, including exactly 1e-6;
#   - with no explicit value, node epsilon is usable only if
#     finite/positive/consistent;
#   - conflicting per-node eps -> FAILED stable reason
#     `invalid_graph:coordinate_epsilon_mismatch`,
#     no median/min/max/first selection.
# ================================================================= = #

# Helper: minimal canonical graph with explicit per-node
# `coordinate_epsilon` overrides. Returns a clean rectangle
# graph Hash (4 nodes + 4 edges, adjacency is the canonical
# rectangle).
def v18_fr01_graph_with_node_eps(node_eps_by_id)
  nodes = [
    {'canonical_node_id' => 'cn-1', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true,
     'coordinate_epsilon' => node_eps_by_id['cn-1'],
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-2', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true,
     'coordinate_epsilon' => node_eps_by_id['cn-2'],
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-3', 'world_coordinate' => [10.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true,
     'coordinate_epsilon' => node_eps_by_id['cn-3'],
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-4', 'world_coordinate' => [0.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true,
     'coordinate_epsilon' => node_eps_by_id['cn-4'],
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-3', 'node_b_id' => 'cn-4',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-4', 'node_a_id' => 'cn-4', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-4',
     'source_occurrence_id' => 'o-4', 'source_occurrence_ids' => ['o-4'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  adjacency = {
    'cn-1' => ['cn-2', 'cn-4'],
    'cn-2' => ['cn-1', 'cn-3'],
    'cn-3' => ['cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1']
  }
  {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adjacency,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-fr01'
  }
end

test 'V18-FR01: explicit 1e-6 wins verbatim over conflicting per-node eps' do
  # Per-node eps disagree: 1e-3 vs 1e-5 vs 1e-4 vs 1e-6.
  graph = v18_fr01_graph_with_node_eps(
    'cn-1' => 1.0e-3, 'cn-2' => 1.0e-5,
    'cn-3' => 1.0e-4, 'cn-4' => 1.0e-6
  )
  # The previous bug rejected kw == 1e-6 and then silently
  # picked a median of conflicting per-node eps. The frozen
  # FR18-01 contract says ANY explicit finite positive kw
  # wins verbatim -- including exactly 1e-6 -- even when the
  # per-node eps disagree.
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w',
    coordinate_epsilon: 1.0e-6
  )
  refute_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-FR01: explicit 1e-6 MUST NOT be rejected when conflicting nodes disagree; " \
               "got #{result['state']}"
  loop = result['loops'].first
  refute_nil loop
  assert_equal 1.0e-6, loop['coordinate_epsilon'],
               "V18-FR01: explicit kw=1e-6 MUST be used verbatim (not median of node eps)"
end

test 'V18-FR01: conflicting per-node eps without kw -> FAILED mismatch reason' do
  # Per-node eps disagree: 1e-3 vs 1e-5. No explicit kw.
  # The frozen FR18-01 contract says: fail closed with a
  # stable `invalid_graph:coordinate_epsilon_mismatch`
  # reason -- NO silent median/min/max/first selection.
  graph = v18_fr01_graph_with_node_eps(
    'cn-1' => 1.0e-3, 'cn-2' => 1.0e-5,
    'cn-3' => 1.0e-4, 'cn-4' => 1.0e-6
  )
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-FR01: conflicting per-node eps without kw MUST be FAILED; " \
               "got #{result['state']}"
  expected_reason =
    CanonicalStructureReconstructor::REASON_COORDINATE_EPSILON_MISMATCH
  assert_includes result['reasons'], expected_reason,
                  "V18-FR01: must emit #{expected_reason}; " \
                  "got #{result['reasons'].inspect}"
  assert_includes result['unresolved_issues'], expected_reason,
                  "V18-FR01: reason must also appear in unresolved_issues; " \
                  "got #{result['unresolved_issues'].inspect}"
end

test 'V18-FR01: consistent per-node eps without kw -> uses that exact value' do
  # All nodes carry the SAME finite positive epsilon (1e-4),
  # which is the frozen "captured tolerance" pattern used by
  # the V1.8 WorkingModeRunner integration. With no explicit
  # kw, the reconstructor MUST adopt that exact consistent
  # per-node value (not the 1e-6 fallback).
  graph = v18_fr01_graph_with_node_eps(
    'cn-1' => 1.0e-4, 'cn-2' => 1.0e-4,
    'cn-3' => 1.0e-4, 'cn-4' => 1.0e-4
  )
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  refute_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-FR01: consistent per-node eps MUST NOT be FAILED; got #{result['state']}"
  loop = result['loops'].first
  refute_nil loop
  assert_equal 1.0e-4, loop['coordinate_epsilon'],
               "V18-FR01: consistent per-node eps MUST be used verbatim"
end

test 'V18-FR01: no per-node eps + no kw -> defensive 1e-6 fallback' do
  # No per-node eps at all (all nil), no kw. The defensive
  # 1e-6 fallback MUST still apply so the reconstructor
  # remains operational when neither authority is available.
  graph = v18_fr01_graph_with_node_eps(
    'cn-1' => nil, 'cn-2' => nil, 'cn-3' => nil, 'cn-4' => nil
  )
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  refute_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-FR01: no eps authority must fall back to 1e-6; got #{result['state']}"
  loop = result['loops'].first
  refute_nil loop
  assert_equal 1.0e-6, loop['coordinate_epsilon'],
               "V18-FR01: fallback path MUST use 1e-6 when no authority is available"
end


# ================================================================= = #
# V18-FR02 — FR18-02 (true indexed O(V+E) membership) focused
# regressions.
#
# Source guards + behavioural guards.
# ================================================================= = #

test 'V18-FR02: production traversal has NO comp.include? in hot path' do
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/canonical_structure_reconstructor.rb',
      __dir__
    )
  )
  offenders = []
  src.each_line.with_index(1) do |line, lineno|
    stripped = line.sub(/#.*$/, '')
    cleaned = stripped.gsub(/"[^"]*"/, '').gsub(/'[^']*'/, '')
    if cleaned =~ /comp\.include\?/
      offenders << "#{lineno}: #{line.strip}"
    end
  end
  assert_equal [], offenders,
               "V18-FR02: production traversal MUST NOT use comp.include?; " \
               "offenders: #{offenders.inspect}"
end

test 'V18-FR02: production source has NO @_comp_set_cache / object_id cache' do
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/canonical_structure_reconstructor.rb',
      __dir__
    )
  )
  refute_match(/@_comp_set_cache/, src,
               'V18-FR02: production source MUST NOT define @_comp_set_cache')
  refute_match(/def\s+comp_set\b/, src,
               'V18-FR02: production source MUST NOT define a comp_set global helper')
  # The historical object_id-keyed membership cache pattern is gone.
  refute_match(/object_id.*Set\.new/, src,
               'V18-FR02: production source MUST NOT use object_id-keyed membership cache')
end

test 'V18-FR02: production adjacency rebuild accumulates via Set (no Array#include? insert scan)' do
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/canonical_structure_reconstructor.rb',
      __dir__
    )
  )
  # The previous build path was:
  #   adjacency[a] << b unless adjacency[a].include?(b)
  # The FR18-02 contract requires Set/hash accumulation
  # without Array#include? insertion scans.
  refute_match(/adjacency\[.*?\]\.include\?/, src,
               'V18-FR02: production source MUST NOT use adjacency[key].include? insert scan')
  # The new path must include Set/hash accumulation.
  assert_match(/adj_set\[.*?\]\.add\(b\)/, src,
               'V18-FR02: production source MUST accumulate per-node adjacency via Set#add')
end

test 'V18-FR02: 500-node chain walk finishes comfortably bounded (no V^2)' do
  n = 500
  nodes = (1..n).map do |i|
    {'canonical_node_id' => "cn-#{i}",
     'world_coordinate' => [i.to_f, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  end
  edges = (1...n).map do |i|
    {'canonical_edge_id' => "ce-#{i}",
     'node_a_id' => "cn-#{i}", 'node_b_id' => "cn-#{i + 1}",
     'origin_kind' => 'source_derived', 'derived_edge_id' => "d-#{i}",
     'source_occurrence_id' => "o-#{i}",
     'source_occurrence_ids' => ["o-#{i}"],
     'repair_action_id' => '',
     'world_endpoints' => [[i.to_f, 0.0, 0.0], [(i + 1).to_f, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  end
  adj = {}
  nodes.each { |nd| adj[nd['canonical_node_id']] = [] }
  edges.each do |e|
    (adj[e['node_a_id']] ||= []) << e['node_b_id']
    (adj[e['node_b_id']] ||= []) << e['node_a_id']
  end
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adj,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-fr02-500-chain'
  }
  started_at = Time.now
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  elapsed = Time.now - started_at
  assert_equal 1, result['metrics']['component_count']
  assert_equal 1, result['metrics']['open_chain_count']
  assert_equal n, result['chains'].first['node_ids'].length
  assert_equal n - 1, result['chains'].first['edge_ids'].length
  assert elapsed < 5.0,
         "V18-FR02: 500-node chain walk MUST finish in <5s; got #{elapsed}s"
end

test 'V18-FR02: 300-node cycle walk finishes comfortably bounded (no V^2)' do
  n = 300
  nodes = (1..n).map do |i|
    angle = (2.0 * Math::PI * (i - 1)) / n
    {
      'canonical_node_id' => "cn-#{i}",
      'world_coordinate' => [10.0 * Math.cos(angle),
                             10.0 * Math.sin(angle), 0.0],
      'endpoint_keys' => [], 'derived_edge_ids' => [],
      'source_occurrence_ids' => [], 'layer_names' => ['L0'],
      'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
      'membership_count' => 1
    }
  end
  edges = (1..n).map do |i|
    a_id = "cn-#{i}"
    b_id = (i < n) ? "cn-#{i + 1}" : 'cn-1'
    a = nodes[i - 1]['world_coordinate']
    b = if i < n
          nodes[i]['world_coordinate']
        else
          nodes[0]['world_coordinate']
        end
    {'canonical_edge_id' => "ce-#{i}",
     'node_a_id' => a_id, 'node_b_id' => b_id,
     'origin_kind' => 'source_derived', 'derived_edge_id' => "d-#{i}",
     'source_occurrence_id' => "o-#{i}",
     'source_occurrence_ids' => ["o-#{i}"],
     'repair_action_id' => '',
     'world_endpoints' => [a, b],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  end
  adj = {}
  nodes.each { |nd| adj[nd['canonical_node_id']] = [] }
  edges.each do |e|
    (adj[e['node_a_id']] ||= []) << e['node_b_id']
    (adj[e['node_b_id']] ||= []) << e['node_a_id']
  end
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adj,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-fr02-300-cycle'
  }
  started_at = Time.now
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  elapsed = Time.now - started_at
  assert_equal 1, result['metrics']['component_count'],
               "V18-FR02: single cycle component"
  assert_equal 1, result['metrics']['closed_loop_count'],
               "V18-FR02: 1 closed loop; got #{result['metrics']}"
  assert_equal n, result['loops'].first['node_ids'].length,
               "V18-FR02: cycle visits all #{n} nodes"
  assert elapsed < 5.0,
         "V18-FR02: 300-node cycle walk MUST finish in <5s; got #{elapsed}s"
end


# ================================================================= = #
# V18-FR03 — FR18-03 (true deep freeze) focused regressions.
#
# Per dispatch V18-FINAL-FOUR-RESIDUALS-2026-09-03:
#   - deep-freeze Hash keys + values;
#   - deep-freeze Arrays;
#   - freeze String scalar values;
#   - mutation of digest / loop_id / source_occurrence_id
#     strings must fail;
#   - digest/payload cannot change after publication.
# ================================================================= = #

test 'V18-FR03: digest / loop_id / source_occurrence_id strings are frozen' do
  graph = v18_build_graph([
    [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0]]
  ])
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert result['digest'].frozen?,
         'V18-FR03: result[\'digest\'] string MUST be frozen'
  loop = result['loops'].first
  refute_nil loop
  assert loop['loop_id'].frozen?,
         'V18-FR03: loop[\'loop_id\'] string MUST be frozen'
  loop['source_occurrence_ids'].each_with_index do |s, i|
    assert s.frozen?,
           "V18-FR03: loop source_occurrence_ids[#{i}] string MUST be frozen"
  end
  region = result['regions'].first
  refute_nil region
  assert region['region_id'].frozen?,
         'V18-FR03: region[\'region_id\'] string MUST be frozen'
  result['reasons'].each do |r|
    assert r.frozen?,
           "V18-FR03: reason string MUST be frozen; got #{r.inspect}"
  end
end

test 'V18-FR03: in-place string mutation of digest / loop_id / source_occurrence_id raises' do
  graph = v18_build_graph([
    [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0]],
    [[3.0, 3.0], [7.0, 3.0], [7.0, 7.0], [3.0, 7.0]]
  ])
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  digest_before = result['digest'].to_s
  loop = result['loops'].first
  loop_id_before = loop['loop_id'].to_s
  occ_id_before = loop['source_occurrence_ids'].first.to_s
  # 1. digest string in-place mutation must fail.
  raised = false
  begin
    result['digest'] << 'x'
  rescue RuntimeError, FrozenError
    raised = true
  end
  assert raised,
         'V18-FR03: result[\'digest\'] << \'x\' MUST raise'
  # 2. loop_id string in-place mutation must fail.
  raised = false
  begin
    loop['loop_id'] << 'x'
  rescue RuntimeError, FrozenError
    raised = true
  end
  assert raised,
         'V18-FR03: loop[\'loop_id\'] << \'x\' MUST raise'
  # 3. source_occurrence_id string in-place mutation must fail.
  raised = false
  begin
    loop['source_occurrence_ids'].first << 'x'
  rescue RuntimeError, FrozenError
    raised = true
  end
  assert raised,
         'V18-FR03: source_occurrence_ids[0] << \'x\' MUST raise'
  # 4. digest / loop_id / source_occurrence_id are unchanged.
  assert_equal digest_before, result['digest'],
               'V18-FR03: digest MUST remain unchanged'
  assert_equal loop_id_before, loop['loop_id'],
               'V18-FR03: loop_id MUST remain unchanged'
  assert_equal occ_id_before, loop['source_occurrence_ids'].first,
               'V18-FR03: source_occurrence_id MUST remain unchanged'
end

test 'V18-FR03: Hash keys inside published payload are frozen' do
  graph = v18_build_graph([
    [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0]]
  ])
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  # Every top-level key of the published Hash must be a
  # frozen String (the published keys are the String
  # schema_field names).
  result.each_key do |k|
    assert k.frozen?,
           "V18-FR03: top-level result key #{k.inspect} MUST be frozen"
  end
  loop = result['loops'].first
  loop.each_key do |k|
    assert k.frozen?,
           "V18-FR03: loop key #{k.inspect} MUST be frozen"
  end
end


# ================================================================= = #
# V18-FR04 — FR18-04 (complete adjacency validation) focused
# regressions.
#
# Per dispatch V18-FINAL-FOUR-RESIDUALS-2026-09-03:
#   A. remove an entire edge-backed adjacency key => FAILED.
#   B. scalar / non-Array adjacency value => FAILED.
#   C. isolated known node with explicit empty adjacency
#      remains valid if the graph otherwise supports
#      isolated-node policy.
# Plus the existing four mismatch families continue to fail.
# ================================================================= = #

# Helper: minimal 4-node rectangular graph (cn-1..cn-4)
# matching the canonical rectangle adjacency. Caller supplies
# an adjacency_override Hash; node_set is derived from the
# canonical nodes cn-1..cn-4 so isolated-node cases can
# exercise the per-canonical-node iteration.
def v18_fr04_graph_with_adj(adjacency_override)
  nodes = [
    {'canonical_node_id' => 'cn-1', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-2', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-3', 'world_coordinate' => [10.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-4', 'world_coordinate' => [0.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-iso', 'world_coordinate' => [50.0, 50.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-3', 'node_b_id' => 'cn-4',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-4', 'node_a_id' => 'cn-4', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-4',
     'source_occurrence_id' => 'o-4', 'source_occurrence_ids' => ['o-4'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges,
    'adjacency' => adjacency_override,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-fr04'
  }
end

test 'V18-FR04: omitted entire edge-backed adjacency key -> FAILED missing_neighbor' do
  # Adjacency is missing the entire key for cn-2, which is
  # edge-backed (cn-1 <-> cn-2 <-> cn-3). Previously the
  # omission passed because validation only iterated
  # supplied keys. FR18-04 requires that we iterate EVERY
  # canonical node and compare expected vs supplied.
  adj = {
    'cn-1' => ['cn-2', 'cn-4'],
    # 'cn-2' => <omitted entirely>,
    'cn-3' => ['cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1'],
    'cn-iso' => []
  }
  graph = v18_fr04_graph_with_adj(adj)
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-FR04: omitted edge-backed key MUST be FAILED; got #{result['state']}"
  missing_present = result['reasons'].any? { |r|
    r.to_s.start_with?(
      'invalid_graph:adjacency_mismatch:missing_neighbor:cn-2->'
    )
  }
  assert missing_present,
         "V18-FR04: must report missing_neighbor for cn-2; " \
         "got #{result['reasons'].inspect}"
end

test 'V18-FR04: scalar non-Array adjacency value -> FAILED non_array_value' do
  # cn-2 carries a scalar String instead of an Array. Per
  # FR18-04, the reconstructor must NOT silently coerce a
  # scalar into a valid adjacency list.
  adj = {
    'cn-1' => ['cn-2', 'cn-4'],
    'cn-2' => 'cn-1',
    'cn-3' => ['cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1'],
    'cn-iso' => []
  }
  graph = v18_fr04_graph_with_adj(adj)
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-FR04: scalar adjacency value MUST be FAILED; got #{result['state']}"
  scalar_present = result['reasons'].any? { |r|
    r.to_s.start_with?(
      'invalid_graph:adjacency_mismatch:non_array_value:cn-2'
    )
  }
  assert scalar_present,
         "V18-FR04: must report non_array_value for cn-2; " \
         "got #{result['reasons'].inspect}"
end

test 'V18-FR04: isolated known node empty adjacency remains valid (clean negative case)' do
  # cn-iso is an isolated canonical node (no incident
  # edges). Its adjacency is explicitly an empty Array,
  # which is the canonical "isolated node" representation.
  # Per FR18-04, an isolated known node with empty adjacency
  # remains valid; the validation must NOT report
  # missing_neighbor for an isolated node.
  adj = {
    'cn-1' => ['cn-2', 'cn-4'],
    'cn-2' => ['cn-1', 'cn-3'],
    'cn-3' => ['cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1'],
    'cn-iso' => []
  }
  graph = v18_fr04_graph_with_adj(adj)
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  refute_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-FR04: isolated known node with empty adjacency MUST NOT be FAILED; " \
               "got #{result['state']}"
  refute result['reasons'].any? { |r|
    r.to_s.start_with?('invalid_graph:adjacency_mismatch')
  }, "V18-FR04: isolated node with empty adjacency MUST NOT report any mismatch; " \
     "got #{result['reasons'].inspect}"
  assert_equal 1, result['metrics']['closed_loop_count'],
               "V18-FR04: 1 closed loop; got #{result['metrics']}"
end

test 'V18-FR04: omitted isolated node key remains valid' do
  # Same as above, but the isolated canonical node does not
  # even appear as a key in the adjacency hash at all.
  # FR18-04 says: missing supplied-key for an isolated node
  # normalizes to an empty list and remains valid.
  adj = {
    'cn-1' => ['cn-2', 'cn-4'],
    'cn-2' => ['cn-1', 'cn-3'],
    'cn-3' => ['cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1']
    # cn-iso is omitted entirely
  }
  graph = v18_fr04_graph_with_adj(adj)
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  refute_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-FR04: omitted isolated node key MUST NOT be FAILED; " \
               "got #{result['state']}"
  refute result['reasons'].any? { |r|
    r.to_s.include?('cn-iso')
  }, "V18-FR04: omitted isolated node MUST NOT generate any cn-iso reason; " \
     "got #{result['reasons'].inspect}"
end


# ================================================================= = #
# V18-BOOT — OWNER SU2020 BOOT BLOCK regression.
#
# Real SketchUp 2020 Owner Gate produced:
#   SyntaxError: canonical_structure_reconstructor.rb:680:
#   void value expression
#
# The previous FR18-04 implementation used `next` as the
# value of an `else` branch of an `if` expression assigned to
# `supplied`:
#
#   supplied =
#     if supplied_value.nil?
#       []
#     elsif supplied_value.is_a?(Array)
#       supplied_value.map(&:to_s).reject(&:empty?).sort.uniq
#     else
#       mismatches << "...:non_array_value:#{nid}"
#       next           # <-- embedded as a value
#     end
#
# The local development Ruby (2.7.x) accepts that form (the
# value of `next` is `nil`). The SketchUp 2020 embedded Ruby
# parser rejects it with a `void value expression`
# SyntaxError, which prevents the extension from even loading.
#
# Per the BOOT BLOCK dispatch, the narrow structural fix is
# already applied: `next` is now a standalone block control
# statement and `supplied` is assigned only from `nil` /
# `Array` cases. This guard is the source-level regression
# that prevents the same anti-pattern from regressing into
# the production code in any future refactor.
#
# The guard scans the production source for two anti-patterns:
#
#   (1) `next` / `break` / `return` used as an expression
#       value inside an assignment RHS — e.g. `x = if ... else
#       next end` — which the old SU2020 parser rejects with
#       `void value expression`. This is detected by looking
#       for any line whose assignment RHS contains `next`,
#       `break`, or `return` as a top-level keyword on its
#       own line within an `if`/`case` expression.
#
#   (2) Specifically, the exact offending pattern from the
#       BOOT BLOCK report: `else\n  ...\n  next\nend` (or
#       similar) appearing as the value of an assignment.
#
# Both are forbidden. Standalone block control statements
# (i.e. `next` at the start of a line inside a block body,
# not embedded as the value of an assignment RHS) remain
# allowed and are NOT flagged.
# ================================================================= = #

# Scan the V1.8 production file for any control-flow keyword
# used as an expression value inside an assignment RHS, with
# a particular focus on the old-Ruby-parser-incompatible
# pattern of `next` / `break` / `return` inside an `if`/
# `case` expression.
#
# The targeted pattern is the exact one that broke the
# SketchUp 2020 Owner Gate:
#
#   supplied =
#     if supplied_value.nil?
#       []
#     elsif supplied_value.is_a?(Array)
#       ...
#     else
#       mismatches << "..."
#       next           # <-- embedded as a value
#     end
#
# Heuristic: track the bracket depth contributed by `if` /
# `case` / `do` / `begin` / `{` and `end` / `}` so that when
# we hit a standalone `next` / `break` / `return` line we
# can tell whether we are still inside the RHS of an
# assignment. This is intentionally conservative: standalone
# block control statements at the START of a line inside a
# block body are NOT flagged (they are legal in all Ruby
# versions).
def v18_boot_violations(src)
  src_lines = src.each_line.to_a
  # Strip comments + string literals (single + double quoted).
  cleaned_lines = src_lines.map do |raw|
    s = raw.sub(/#.*$/, '')
    s = s.gsub(/"[^"]*"/, '""')
    s = s.gsub(/'[^']*'/, "''")
    s
  end

  offenders = []
  # `pending_assign` is true when the previous non-empty
  # line ended with `=` (an assignment whose RHS opener is
  # on a continuation line). `open_rhs` is a stack of line
  # indices for in-progress `if` / `case` / `do` RHS blocks.
  pending_assign = false
  open_rhs = []

  cleaned_lines.each_with_index do |raw_clean, idx|
    raw_orig = src_lines[idx]
    stripped = raw_clean.rstrip
    next if stripped.empty?

    # A top-level `end` or `}` closes the innermost open RHS
    # block (and clears any pending_assign state).
    if stripped =~ /^\s*end\s*(?:#|$)/
      open_rhs.pop if !open_rhs.empty?
      pending_assign = false
      next
    end
    if stripped =~ /^\s*\}\s*(?:#|$)/
      open_rhs.pop if !open_rhs.empty?
      pending_assign = false
      next
    end

    # Detect the START of a multi-line assignment whose RHS
    # is an `if` / `case` / `do` expression. Two forms are
    # supported:
    #   (a) `x = if cond1 ...` (opener on the same line)
    #   (b) `x =` on one line followed by `if cond1 ...`
    #       on the next non-empty line (continuation).
    if !pending_assign &&
       stripped =~ /^\s*\w[\w.\[\]\:]*\s*=(?!=)[^=]*\b(if|case|do)\b/
      open_rhs << idx
    elsif pending_assign && stripped =~ /^\s*(if|case|do)\b/
      open_rhs << idx
      pending_assign = false
    end

    # A non-comparison line ending with `=` sets the
    # pending_assign flag (the next non-empty line should
    # open the RHS).
    if stripped =~ /=(?!=)\s*(?:#|$)/ &&
       stripped !~ /\b==/ && stripped !~ /\b!=/ &&
       stripped !~ /\b<=/ && stripped !~ /\b>=/ &&
       stripped !~ /:=/ && stripped !~ /=>/ &&
       stripped !~ /<<=/ && stripped !~ /\+=/
      pending_assign = true
    elsif !open_rhs.empty?
      # We are inside an open RHS but did NOT close it on
      # this line; keep pending_assign sticky until the
      # opener / closer / value keyword lands.
      pending_assign = false
    else
      pending_assign = false
    end

    # Detect a standalone control-flow keyword as a value
    # ONLY if we are currently inside an open RHS block.
    if !open_rhs.empty? && stripped =~ /^\s*(next|break|return)\s*(?:#|$)/
      keyword = Regexp.last_match(1)
      offenders << "#{idx + 1}: #{raw_orig.rstrip}  " \
                     "[#{keyword} used as value inside assignment RHS]"
    end
  end
  offenders
end

test 'V18-BOOT: production source has NO `next`/`break`/`return` used as assignment RHS value' do
  src = File.read(
    File.expand_path(
      '../extension/su_ai_plugin/core/canonical_structure_reconstructor.rb',
      __dir__
    )
  )
  offenders = v18_boot_violations(src)
  assert_equal [], offenders,
               'V18-BOOT: production source MUST NOT use control-flow keywords ' \
               '(next / break / return) as expression values inside assignment ' \
               'RHS expressions; the SketchUp 2020 embedded Ruby parser rejects ' \
               "this with `void value expression` SyntaxError. Offenders:\n" \
               "#{offenders.join("\n")}"
end

test 'V18-BOOT: V1.8 production file parses under the local vendored Ruby (sanity check)' do
  # Load the production file in isolation and confirm it
  # parses cleanly. This is a host-side sanity check
  # against the local vendored Ruby 2.7.8; the BOOT BLOCK
  # fix must keep this green.
  load_path = File.expand_path(
    '../extension/su_ai_plugin/core/canonical_structure_reconstructor.rb',
    __dir__
  )
  # Clear any previously-loaded copy of the module so we
  # get a clean parse-and-load cycle.
  if defined?(SUAnalysis::Core::CanonicalStructureReconstructor)
    SUAnalysis::Core.send(:remove_const, :CanonicalStructureReconstructor)
  end
  begin
    load load_path
    refute_nil SUAnalysis::Core::CanonicalStructureReconstructor
    assert_equal 'csr.v1',
                 SUAnalysis::Core::CanonicalStructureReconstructor::SCHEMA_VERSION,
                 'V18-BOOT: production module must load and expose SCHEMA_VERSION'
  ensure
    # The test framework already required this module via
    # the file's top-level require_relative; reload the
    # module so subsequent tests in this file see the same
    # constants + method definitions.
    if defined?(SUAnalysis::Core::CanonicalStructureReconstructor)
      SUAnalysis::Core.send(:remove_const, :CanonicalStructureReconstructor)
    end
    load load_path
  end
end

test 'V18-BOOT: _validate_adjacency_against_edges still produces correct results after restructure' do
  # The BOOT BLOCK restructure moved the non-array branch
  # out of the if-expression and into a standalone guard.
  # All four mismatch families must continue to fire.
  nodes = [
    {'canonical_node_id' => 'cn-1', 'world_coordinate' => [0.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-2', 'world_coordinate' => [10.0, 0.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-3', 'world_coordinate' => [10.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1},
    {'canonical_node_id' => 'cn-4', 'world_coordinate' => [0.0, 5.0, 0.0],
     'endpoint_keys' => [], 'derived_edge_ids' => [],
     'source_occurrence_ids' => [], 'layer_names' => ['L0'],
     'resolved_clique' => true, 'coordinate_epsilon' => 1.0e-6,
     'membership_count' => 1}
  ]
  edges = [
    {'canonical_edge_id' => 'ce-1', 'node_a_id' => 'cn-1', 'node_b_id' => 'cn-2',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-1',
     'source_occurrence_id' => 'o-1', 'source_occurrence_ids' => ['o-1'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-2', 'node_a_id' => 'cn-2', 'node_b_id' => 'cn-3',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-2',
     'source_occurrence_id' => 'o-2', 'source_occurrence_ids' => ['o-2'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 0.0, 0.0], [10.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-3', 'node_a_id' => 'cn-3', 'node_b_id' => 'cn-4',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-3',
     'source_occurrence_id' => 'o-3', 'source_occurrence_ids' => ['o-3'],
     'repair_action_id' => '',
     'world_endpoints' => [[10.0, 5.0, 0.0], [0.0, 5.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []},
    {'canonical_edge_id' => 'ce-4', 'node_a_id' => 'cn-4', 'node_b_id' => 'cn-1',
     'origin_kind' => 'source_derived', 'derived_edge_id' => 'd-4',
     'source_occurrence_id' => 'o-4', 'source_occurrence_ids' => ['o-4'],
     'repair_action_id' => '',
     'world_endpoints' => [[0.0, 5.0, 0.0], [0.0, 0.0, 0.0]],
     'layer_name' => 'L0', 'unresolved_flags' => []}
  ]
  adj = {
    'cn-1' => ['cn-2', 'cn-4'],
    'cn-2' => 'cn-1',                  # <-- scalar value
    'cn-3' => ['cn-2', 'cn-4'],
    'cn-4' => ['cn-3', 'cn-1']
  }
  graph = {
    'schema_version' => 'cgg.v1',
    'nodes' => nodes, 'edges' => edges, 'adjacency' => adj,
    'unresolved_topology_issues' => [],
    'metrics' => {}, 'non_transitive_clusters' => [],
    'open_endpoints' => [], 'tolerance_digest' => 'tol',
    'digest' => 'g-v18-boot'
  }
  result = CanonicalStructureReconstructor.reconstruct(
    graph, source_snapshot_id: 's', workspace_id: 'w'
  )
  assert_equal CanonicalStructureReconstructor::STATE_FAILED, result['state'],
               "V18-BOOT: scalar adjacency value MUST still be FAILED; " \
               "got #{result['state']}"
  non_array = result['reasons'].any? { |r|
    r.to_s.start_with?(
      'invalid_graph:adjacency_mismatch:non_array_value:cn-2'
    )
  }
  assert non_array,
         "V18-BOOT: must still emit non_array_value for cn-2 after restructure; " \
         "got #{result['reasons'].inspect}"
end
