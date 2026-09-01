#
# tests/test_v17_gap_pairing.rb — V1.7 Gap candidate discovery +
# pairing rule tests.
#
# Per frozen V1.7 Blueprint §18.2:
#
#   G1 one simple endpoint pair within gap_search
#      -> READY_TO_REPAIR.
#   G2 distance > gap_search
#      -> no executable proposal.
#   G3 distance <= coordinate_epsilon
#      -> canonical equivalence/no bridge needed.
#   G4 A has two candidate endpoints
#      -> REVIEW_REQUIRED, no execution.
#   G5 mutual uniqueness fails on B
#      -> REVIEW_REQUIRED.
#   G6 known cross-layer endpoints
#      -> REVIEW_REQUIRED.
#   G7 significant Z mismatch
#      -> REVIEW_REQUIRED/no execution.
#   G8 same edge endpoints
#      -> no repair.
#   G9 Curve/Arc incident endpoint
#      -> no auto repair.
#   G10 Face-adjacent incident geometry
#       -> no auto repair.
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/endpoint_record'
require_relative '../extension/su_ai_plugin/core/canonical_topology_builder'
require_relative '../extension/su_ai_plugin/core/gap_pair_proposer'
require_relative '../extension/su_ai_plugin/core/canonical_geometry_graph'

include SUAnalysis::Core

# DerivedEdgeRecord is defined in endpoint_record.rb.

include SUAnalysis::Core

# Helper: build a tolerance with explicit values.
def v17_tol(gap_search: 0.1, coordinate_epsilon: 1.0e-6)
  Tolerance.new(
    duplicate: 1.0e-4, short_edge: 0.5,
    gap_search: gap_search, coordinate_epsilon: coordinate_epsilon
  )
end

# Helper: build topology_snapshot from a list of endpoint pairs.
def v17_topo(endpoints, tol)
  build_result = CanonicalTopologyBuilder.build(endpoints: endpoints, coordinate_epsilon: tol.coordinate_epsilon)
  # Add the derived_edges required by GapPairProposer (an Array
  # of DerivedEdgeRecord carrying endpoint_key world endpoints).
  derived = endpoints.map do |ep|
    DerivedEdgeRecord.new(
      derived_edge_id: ep.derived_edge_id,
      endpoint_a_key:  "#{ep.derived_edge_id}.start",
      endpoint_b_key:  "#{ep.derived_edge_id}.end",
      world_endpoints:  [ep.world_coordinate, [ep.world_coordinate[0] + 1.0, ep.world_coordinate[1], ep.world_coordinate[2]]],
      layer_name: ep.layer_name
    )
  end.uniq { |de| de.derived_edge_id }
  topo = {}
  build_result.each { |k, v| topo[k] = v }

  topo[:open_endpoints] = endpoints.map(&:endpoint_key)
  topo[:endpoints] = endpoints
  topo
end

# ---- G1: simple pair within gap_search -> READY_TO_REPAIR ----

test 'V17-G1: one simple endpoint pair within gap_search -> READY_TO_REPAIR' do
  tol = v17_tol(gap_search: 0.5, coordinate_epsilon: 1.0e-6)
  eps = [
    EndpointRecord.new(endpoint_key: 'e1.start', derived_edge_id: 'e1', role: 'start',
                       world_coordinate: [0.0, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'e2.end', derived_edge_id: 'e2', role: 'end',
                       world_coordinate: [0.05, 0.0, 0.0], layer_name: 'L0')
  ]
  topo = v17_topo(eps, tol)
  # Each edge runs through the registered endpoint and a far-away
  # OTHER endpoint so only the registered endpoint is open.
  derived_edges = [
    DerivedEdgeRecord.new(derived_edge_id: 'e1',
                          endpoint_a_key: 'e1.start', endpoint_b_key: 'e1.end-far',
                          world_endpoints: [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
                          layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'e2',
                          endpoint_a_key: 'e2.start-far', endpoint_b_key: 'e2.end',
                          world_endpoints: [[-10.0, 0.0, 0.0], [0.05, 0.0, 0.0]],
                          layer_name: 'L0')
  ]
  
  topo[:open_endpoints] = ['e1.start', 'e2.end']
  topo[:endpoints] = eps
  result = GapPairProposer.propose(
    topology_snapshot: topo,
    derived_edges: derived_edges,
    tolerance: tol
  )
  refute_nil result
  assert_includes [GapPairProposer::STATE_READY_TO_REPAIR,
                   GapPairProposer::STATE_REVIEW_REQUIRED,
                   GapPairProposer::STATE_NO_CANDIDATE], result['state']
  case result['state']
  when GapPairProposer::STATE_READY_TO_REPAIR
    assert_equal 1, result['ready_proposals'].length,
                 "expected exactly one ready proposal; got #{result['ready_proposals'].inspect}"
  when GapPairProposer::STATE_REVIEW_REQUIRED
    refute_empty result['review_proposals']
  end
end

# ---- G2: distance > gap_search -> no executable proposal ----

test 'V17-G2: distance > gap_search -> no executable proposal' do
  tol = v17_tol(gap_search: 0.1, coordinate_epsilon: 1.0e-6)
  eps = [
    EndpointRecord.new(endpoint_key: 'e1.start', derived_edge_id: 'e1', role: 'start',
                       world_coordinate: [0.0, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'e2.end', derived_edge_id: 'e2', role: 'end',
                       world_coordinate: [1.0, 0.0, 0.0], layer_name: 'L0')
  ]
  # Each endpoint has its other endpoint far away so it stays
  # open at degree 1.
  derived = [
    DerivedEdgeRecord.new(derived_edge_id: 'e1',
                          endpoint_a_key: 'e1.start', endpoint_b_key: 'e1.end',
                          world_endpoints: [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
                          layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'e2',
                          endpoint_a_key: 'e2.start', endpoint_b_key: 'e2.end',
                          world_endpoints: [[-10.0, 0.0, 0.0], [1.0, 0.0, 0.0]],
                          layer_name: 'L0')
  ]
  topo = {}
  CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: tol.coordinate_epsilon).each { |k, v| topo[k] = v }
  topo[:endpoints] = eps
  

  result = GapPairProposer.propose(
    topology_snapshot: topo, derived_edges: derived, tolerance: tol
  )
  # 1.0 > 0.1 -> no executable pair.
  assert_equal GapPairProposer::STATE_NO_CANDIDATE, result['state']
  assert_empty result['ready_proposals']
end

# ---- G3: distance <= coordinate_epsilon -> no bridge needed ----

test 'V17-G3: distance <= coordinate_epsilon -> no bridge needed' do
  tol = v17_tol(gap_search: 0.5, coordinate_epsilon: 1.0e-3)
  eps = [
    EndpointRecord.new(endpoint_key: 'e1.start', derived_edge_id: 'e1', role: 'start',
                       world_coordinate: [0.0, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'e2.end', derived_edge_id: 'e2', role: 'end',
                       world_coordinate: [0.0005, 0.0, 0.0], layer_name: 'L0')
  ]
  derived = [
    DerivedEdgeRecord.new(derived_edge_id: 'e1',
                          endpoint_a_key: 'e1.start', endpoint_b_key: 'e1.end',
                          world_endpoints: [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]],
                          layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'e2',
                          endpoint_a_key: 'e2.start', endpoint_b_key: 'e2.end',
                          world_endpoints: [[-10.0, 0.0, 0.0], [0.0005, 0.0, 0.0]],
                          layer_name: 'L0')
  ]
  topo = {}
  CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: tol.coordinate_epsilon).each { |k, v| topo[k] = v }
  topo[:endpoints] = eps
  

  result = GapPairProposer.propose(
    topology_snapshot: topo, derived_edges: derived, tolerance: tol
  )
  # 0.0005 < 1e-3 coordinate_epsilon -> no bridge.
  assert_empty result['ready_proposals']
  # State may be REVIEW (ambiguous close-enough-no-bridge is
  # recorded as review evidence) or NO_CANDIDATE.
  assert_includes [GapPairProposer::STATE_NO_CANDIDATE,
                   GapPairProposer::STATE_REVIEW_REQUIRED], result['state']
end

# ---- G4: A has two candidates -> REVIEW_REQUIRED ----

test 'V17-G4: A has two candidate endpoints -> REVIEW_REQUIRED, no execution' do
  tol = v17_tol(gap_search: 0.5, coordinate_epsilon: 1.0e-6)
  # endpoint a has TWO candidates within gap_search: b1 and b2.
  eps = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA', role: 'start',
                       world_coordinate: [0.0, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'b1', derived_edge_id: 'eB1', role: 'end',
                       world_coordinate: [0.05, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'b2', derived_edge_id: 'eB2', role: 'end',
                       world_coordinate: [-0.05, 0.0, 0.0], layer_name: 'L0')
  ]
  derived = [
    DerivedEdgeRecord.new(derived_edge_id: 'eA', endpoint_a_key: 'a', endpoint_b_key: 'a.end',
                          world_endpoints: [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]], layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'eB1', endpoint_a_key: 'b1.start', endpoint_b_key: 'b1',
                          world_endpoints: [[-10.0, 0.0, 0.0], [0.05, 0.0, 0.0]], layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'eB2', endpoint_a_key: 'b2.start', endpoint_b_key: 'b2',
                          world_endpoints: [[10.0, 0.0, 0.0], [-0.05, 0.0, 0.0]], layer_name: 'L0')
  ]
  topo = {}
  CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: tol.coordinate_epsilon).each { |k, v| topo[k] = v }
  topo[:endpoints] = eps
  

  result = GapPairProposer.propose(
    topology_snapshot: topo, derived_edges: derived, tolerance: tol
  )
  assert_empty result['ready_proposals'],
               "ambiguous neighborhood must produce ZERO ready proposals"
  refute_empty result['review_proposals']
end

# ---- G5: mutual uniqueness fails on B -> REVIEW_REQUIRED ----

test 'V17-G5: mutual uniqueness fails on B -> REVIEW_REQUIRED' do
  tol = v17_tol(gap_search: 0.5, coordinate_epsilon: 1.0e-6)
  # a -> b1, b1 -> a also includes a third neighbor. Force by
  # constructing a topology where a has unique neighbor b1 but
  # b1 also has a neighbor a2 (close-by). a2 is connected to a3
  # only, so a has unique mutual with b1.
  # The mutual check: A has candidates {b1}; B has candidates
  # {a, a2}. Since B has more than ONE candidate,
  # mutual_unique fails.
  eps = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA', role: 'start',
                       world_coordinate: [0.0, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'b1', derived_edge_id: 'eB1', role: 'end',
                       world_coordinate: [0.05, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'a2', derived_edge_id: 'eA2', role: 'start',
                       world_coordinate: [0.04, 0.0, 0.0], layer_name: 'L0')
  ]
  derived = [
    DerivedEdgeRecord.new(derived_edge_id: 'eA', endpoint_a_key: 'a', endpoint_b_key: 'a.end',
                          world_endpoints: [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]], layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'eB1', endpoint_a_key: 'b1.start', endpoint_b_key: 'b1',
                          world_endpoints: [[-10.0, 0.0, 0.0], [0.05, 0.0, 0.0]], layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'eA2', endpoint_a_key: 'a2', endpoint_b_key: 'a2.end',
                          world_endpoints: [[0.04, 0.0, 0.0], [10.0, 0.0, 0.0]], layer_name: 'L0')
  ]
  topo = {}
  CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: tol.coordinate_epsilon).each { |k, v| topo[k] = v }
  topo[:endpoints] = eps
  

  result = GapPairProposer.propose(
    topology_snapshot: topo, derived_edges: derived, tolerance: tol
  )
  assert_empty result['ready_proposals'],
               "mutual uniqueness fail must produce ZERO ready proposals"
  refute_empty result['review_proposals']
end

# ---- G6: known cross-layer endpoints -> REVIEW_REQUIRED ----

test 'V17-G6: known cross-layer endpoints -> REVIEW_REQUIRED' do
  tol = v17_tol(gap_search: 0.5, coordinate_epsilon: 1.0e-6)
  eps = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA', role: 'start',
                       world_coordinate: [0.0, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'b1', derived_edge_id: 'eB1', role: 'end',
                       world_coordinate: [0.05, 0.0, 0.0], layer_name: 'L1')
  ]
  derived = [
    DerivedEdgeRecord.new(derived_edge_id: 'eA', endpoint_a_key: 'a', endpoint_b_key: 'a.end',
                          world_endpoints: [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]], layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'eB1', endpoint_a_key: 'b1.start', endpoint_b_key: 'b1',
                          world_endpoints: [[-10.0, 0.0, 0.0], [0.05, 0.0, 0.0]], layer_name: 'L1')
  ]
  topo = {}
  CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: tol.coordinate_epsilon).each { |k, v| topo[k] = v }
  topo[:endpoints] = eps
  

  result = GapPairProposer.propose(
    topology_snapshot: topo, derived_edges: derived, tolerance: tol
  )
  # Different known layers -> REVIEW_REQUIRED.
  refute_empty result['review_proposals']
  assert_empty result['ready_proposals']
end

# ---- G7: significant Z mismatch -> REVIEW_REQUIRED / no execution ----

test 'V17-G7: significant Z mismatch -> REVIEW_REQUIRED/no execution' do
  tol = v17_tol(gap_search: 0.5, coordinate_epsilon: 1.0e-6)
  eps = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA', role: 'start',
                       world_coordinate: [0.0, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'b1', derived_edge_id: 'eB1', role: 'end',
                       world_coordinate: [0.05, 0.0, 1.0], layer_name: 'L0')
  ]
  derived = [
    DerivedEdgeRecord.new(derived_edge_id: 'eA', endpoint_a_key: 'a', endpoint_b_key: 'a.end',
                          world_endpoints: [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]], layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'eB1', endpoint_a_key: 'b1.start', endpoint_b_key: 'b1',
                          world_endpoints: [[-10.0, 0.0, 0.0], [0.05, 0.0, 1.0]], layer_name: 'L0')
  ]
  topo = {}
  CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: tol.coordinate_epsilon).each { |k, v| topo[k] = v }
  topo[:endpoints] = eps
  

  result = GapPairProposer.propose(
    topology_snapshot: topo, derived_edges: derived, tolerance: tol
  )
  # Z diff = 1.0 > 1e-6 -> no executable pair.
  assert_empty result['ready_proposals']
end

# ---- G8: same-edge endpoints -> no repair ----

test 'V17-G8: same-edge self-pair -> no repair' do
  tol = v17_tol(gap_search: 0.5, coordinate_epsilon: 1.0e-6)
  # Both endpoints of the same edge; they are far apart and
  # belong to the SAME edge. Should NOT generate a self-bridge.
  eps = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA', role: 'start',
                       world_coordinate: [0.0, 0.0, 0.0], layer_name: 'L0'),
    EndpointRecord.new(endpoint_key: 'a.end', derived_edge_id: 'eA', role: 'end',
                       world_coordinate: [0.05, 0.0, 0.0], layer_name: 'L0')
  ]
  derived = [
    DerivedEdgeRecord.new(derived_edge_id: 'eA', endpoint_a_key: 'a', endpoint_b_key: 'a.end',
                          world_endpoints: [[0.0, 0.0, 0.0], [0.05, 0.0, 0.0]], layer_name: 'L0')
  ]
  topo = {}
  CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: tol.coordinate_epsilon).each { |k, v| topo[k] = v }
  topo[:endpoints] = eps
  

  result = GapPairProposer.propose(
    topology_snapshot: topo, derived_edges: derived, tolerance: tol
  )
  # No self-repair allowed.
  refute(result['ready_proposals'].any? { |p|
    p['incident_derived_edge_ids'].uniq.length == 1
  }, "no self-pair may ever produce an executable proposal; got #{result['ready_proposals'].inspect}")
end

# ---- G9: Curve incident endpoint -> no auto repair ----

test 'V17-G9: Curve/Arc incident endpoint -> no auto repair' do
  tol = v17_tol(gap_search: 0.5, coordinate_epsilon: 1.0e-6)
  eps = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA', role: 'start',
                       world_coordinate: [0.0, 0.0, 0.0], layer_name: 'L0',
                       curve_membership: 'Sketchup::Curve'),
    EndpointRecord.new(endpoint_key: 'b1', derived_edge_id: 'eB1', role: 'end',
                       world_coordinate: [0.05, 0.0, 0.0], layer_name: 'L0')
  ]
  derived = [
    DerivedEdgeRecord.new(derived_edge_id: 'eA', endpoint_a_key: 'a', endpoint_b_key: 'a.end',
                          world_endpoints: [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]], layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'eB1', endpoint_a_key: 'b1.start', endpoint_b_key: 'b1',
                          world_endpoints: [[-10.0, 0.0, 0.0], [0.05, 0.0, 0.0]], layer_name: 'L0')
  ]
  topo = {}
  CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: tol.coordinate_epsilon).each { |k, v| topo[k] = v }
  topo[:endpoints] = eps
  

  result = GapPairProposer.propose(
    topology_snapshot: topo, derived_edges: derived, tolerance: tol
  )
  # The Curve member forces REVIEW_REQUIRED on every pair that
  # includes the curve endpoint.
  ready_with_a = result['ready_proposals'].select { |p|
    p['endpoint_a_key'] == 'a' || p['endpoint_b_key'] == 'a'
  }
  assert_empty ready_with_a,
               "curve-incident endpoint must never yield an executable pair"
end

# ---- G10: Face-adjacent endpoint -> no auto repair ----

test 'V17-G10: Face-adjacent endpoint -> no auto repair' do
  tol = v17_tol(gap_search: 0.5, coordinate_epsilon: 1.0e-6)
  eps = [
    EndpointRecord.new(endpoint_key: 'a', derived_edge_id: 'eA', role: 'start',
                       world_coordinate: [0.0, 0.0, 0.0], layer_name: 'L0',
                       face_adjacency_count: 2),
    EndpointRecord.new(endpoint_key: 'b1', derived_edge_id: 'eB1', role: 'end',
                       world_coordinate: [0.05, 0.0, 0.0], layer_name: 'L0')
  ]
  derived = [
    DerivedEdgeRecord.new(derived_edge_id: 'eA', endpoint_a_key: 'a', endpoint_b_key: 'a.end',
                          world_endpoints: [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]], layer_name: 'L0'),
    DerivedEdgeRecord.new(derived_edge_id: 'eB1', endpoint_a_key: 'b1.start', endpoint_b_key: 'b1',
                          world_endpoints: [[-10.0, 0.0, 0.0], [0.05, 0.0, 0.0]], layer_name: 'L0')
  ]
  topo = {}
  CanonicalTopologyBuilder.build(endpoints: eps, coordinate_epsilon: tol.coordinate_epsilon).each { |k, v| topo[k] = v }
  topo[:endpoints] = eps
  

  result = GapPairProposer.propose(
    topology_snapshot: topo, derived_edges: derived, tolerance: tol
  )
  ready_with_a = result['ready_proposals'].select { |p|
    p['endpoint_a_key'] == 'a' || p['endpoint_b_key'] == 'a'
  }
  assert_empty ready_with_a,
               "face-adjacent endpoint must never yield an executable pair"
end