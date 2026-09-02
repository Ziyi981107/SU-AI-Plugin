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
