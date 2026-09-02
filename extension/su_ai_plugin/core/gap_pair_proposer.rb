#
# core/gap_pair_proposer.rb — V1.7 EndpointGapPairProposer.
#
# Per frozen V1.7 Blueprint §6 / §9 / §10 / §11:

# Ensure Set is available (Ruby 2.7+ requires explicit require).
require 'set'

#
#   §9 Gap Candidate Discovery: spatial bucket/grid/hash;
#   target complexity O(V+K); no whole-drawing O(V^2) scan.
#   Per open canonical endpoint A, find endpoint B candidates
#   satisfying all basic filters.
#
#   §10 High-Confidence Pairing Rule: proximity is not enough.
#     - §10.1 mutual unique candidate (A has exactly one B in
#       gap_search, B has exactly one A in gap_search).
#     - §10.2 layer evidence: if both known and different ->
#       REVIEW_REQUIRED. If both unknown -> implementation may
#       still execute, but must be recorded.
#     - §10.3 crossing / branch safety: proposed bridge must
#       not intersect unrelated canonical edges in its
#       interior, must not pass through an unrelated
#       canonical node, must not create an implicit T-junction,
#       must not require splitting an edge, must not cross
#       another proposed bridge.
#     - §10.4 no same-edge self-repair.
#     - §10.5 determinism: stable sorted keys.
#
#   §11 Gap Proposal Data Contract:
#     GapRepairProposal:
#       - proposal_id
#       - action_type = 'endpoint_bridge'
#       - endpoint_a_key, endpoint_b_key
#       - canonical_node_a_id, canonical_node_b_id
#       - distance, gap_search, coordinate_epsilon
#       - layer evidence
#       - crossing-check result
#       - incident derived edge IDs
#       - incident source occurrence IDs
#       - expected bridge endpoints
#       - expected bridge length
#       - confidence/state
#       - reason
#       - executable boolean.
#
# States (per Blueprint §11):
#   READY_TO_REPAIR / REVIEW_REQUIRED / NO_CANDIDATE /
#   APPLIED / FAILED.
#

require 'digest'

module SUAnalysis
  module Core
    module GapPairProposer
      module_function

      ACTION_TYPE = 'endpoint_bridge'.freeze
      RULE_ID = 'endpoint_bridge.v1'.freeze
      RULE_VERSION = '1'.freeze
      PROVENANCE_SCHEMA_VERSION = 'gap-proposal.v1'.freeze

      STATE_READY_TO_REPAIR   = 'READY_TO_REPAIR'.freeze
      STATE_REVIEW_REQUIRED   = 'REVIEW_REQUIRED'.freeze
      STATE_NO_CANDIDATE      = 'NO_CANDIDATE'.freeze
      STATE_APPLIED           = 'APPLIED'.freeze
      STATE_FAILED            = 'FAILED'.freeze

      # Reason codes carried in `reason`.
      REASON_OK                  = 'ok'.freeze
      REASON_DISTANCE_OUT        = 'distance_out_of_range'.freeze
      REASON_CLOSE_ENOUGH_NO_BRIDGE = 'coordinate_epsilon_match_no_bridge_needed'.freeze
      REASON_AMBIGUOUS_NEIGHBORS = 'ambiguous_neighborhood'.freeze
      REASON_MUTUAL_UNIQUE_FAIL  = 'mutual_unique_failed'.freeze
      REASON_CROSS_LAYER         = 'cross_layer_repair'.freeze
      REASON_Z_INCOMPATIBLE      = 'z_incompatible'.freeze
      REASON_SAME_EDGE           = 'same_edge_self_pair'.freeze
      REASON_CURVE_FACE          = 'unsafe_curve_or_face_context'.freeze
      REASON_BRIDGE_CROSSING     = 'bridge_crossing'.freeze
      REASON_THIRD_NODE_ON_BRIDGE = 'third_node_on_bridge'.freeze
      REASON_BRIDGE_CONFLICT     = 'bridge_conflict'.freeze
      REASON_NON_TRANSITIVE_CLUSTER = 'non_transitive_node_cluster_member'.freeze

      # Build proposals for the CURRENT canonical topology.
      #
      # Inputs:
      #   topology_snapshot: Hash returned by
      #     CanonicalTopologyBuilder.build (with
      #     :canonical_nodes, :canonical_node_clusters,
      #     :non_transitive_clusters, :coordinate_epsilon).
      #   derived_edges:     Array<DerivedEdgeRecord>.
      #   tolerance:         Tolerance instance (carries
      #     gap_search + coordinate_epsilon).
      #   crossing_checker:  optional callable for crossing /
      #     third-node / pair-conflict evaluation.
      #
      # Returns:
      #   {
      #     state:           Symbol or String from STATE_*
      #     ready_proposals: Array<Hash> (only SAFE ones)
      #     review_proposals:Array<Hash> (ambiguous / cross /
      #                     unsafe)
      #     open_endpoint_count: Integer
      #     metrics:         Hash
      #     rule_id:         'endpoint_bridge.v1'
      #     rule_version:    '1'
      #     tolerance:       { gap_search, coordinate_epsilon }
      #   }
      def propose(topology_snapshot:, derived_edges:, tolerance:, crossing_checker: nil)
        gap_search  = tolerance.respond_to?(:gap_search) ? tolerance.gap_search.to_f : 0.1
        coord_eps   = _ts_read(topology_snapshot, :coordinate_epsilon) ||
                       tolerance.coordinate_epsilon.to_f

        # ---- Open endpoint candidates ----
        # Open endpoint = canonical degree-1 endpoint computed
        # from the canonical edges. In this stage we determine
        # openness from the derived_edges + canonical_nodes
        # adjacency (consistent with Blueprint §8).
        adj_map   = _build_canonical_adjacency(derived_edges)
        cluster_lookup = _ts_read(topology_snapshot, :canonical_node_clusters) || {}
        non_trans_clusters = _ts_read(topology_snapshot, :non_transitive_clusters) || []
        non_trans_keys = non_trans_clusters.flat_map { |c| Array(c[:endpoint_keys] || c['endpoint_keys']).map(&:to_s) }.to_set rescue nil
        non_trans_keys ||= Set.new(non_trans_clusters.flat_map { |c| Array(c['endpoint_keys']).map(&:to_s) })

        # Build endpoint -> incident_edges + canonical_node_id
        endpoint_lookup = {}
        canonical_node_by_endpoint = {}
        cluster_lookup.each do |cid, keys|
          Array(keys).each { |k| canonical_node_by_endpoint[k.to_s] = cid.to_s }
        end

        # Resolve EndpointRecord by endpoint_key when
        # available (drives curve / face context annotations).
        endpoint_records_by_key = {}
        _ts_endpoint_records = _ts_read(topology_snapshot, :endpoint_records)
        _ts_endpoints        = _ts_read(topology_snapshot, :endpoints)
        if _ts_endpoint_records.is_a?(Hash)
          _ts_endpoint_records.each { |k, v| endpoint_records_by_key[k.to_s] = v }
        elsif _ts_endpoints.is_a?(Array)
          _ts_endpoints.each do |ep|
            next unless ep.respond_to?(:endpoint_key)
            endpoint_records_by_key[ep.endpoint_key.to_s] = ep
          end
        end
        derived_edges.each do |e|
          ek_a = e.endpoint_a_key.to_s
          ek_b = e.endpoint_b_key.to_s
          rec_a = endpoint_records_by_key[ek_a]
          rec_b = endpoint_records_by_key[ek_b]
          # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-003:
          # plural source provenance is authoritative. Read the
          # COMPLETE sorted/uniq union of source occurrence IDs
          # from the EndpointRecord when available (it carries
          # the snapshotted union from DerivedTopologySnapshot
          # Builder); fall back to the DerivedEdgeRecord's
          # `source_occurrence_ids` (also plural). The singular
          # `source_occurrence_id` accessor is preserved for
          # backwards compatibility and is derived from the
          # plural field (first element).
          sids_a = _plurals_from(rec_a, e)
          sids_b = _plurals_from(rec_b, e)
          endpoint_lookup[ek_a] = {
            'endpoint_key'  => ek_a,
            'derived_edge_id' => e.derived_edge_id.to_s,
            'world_coordinate' => e.world_endpoints[0].dup,
            'layer_name'    => e.layer_name,
            'source_occurrence_id' => (sids_a.first || e.source_occurrence_id),
            'source_occurrence_ids' => sids_a,
            'canonical_node_id' => canonical_node_by_endpoint[ek_a] || "cns-#{ek_a}",
            'host_vertex_handle'  => nil,
            'curve_membership'   => (rec_a.respond_to?(:curve_membership) ? rec_a.curve_membership : nil),
            'face_adjacency_count' => (rec_a.respond_to?(:face_adjacency_count) ? rec_a.face_adjacency_count.to_i : 0),
            'origin_kind'    => e.origin_kind
          }
          endpoint_lookup[ek_b] = {
            'endpoint_key'  => ek_b,
            'derived_edge_id' => e.derived_edge_id.to_s,
            'world_coordinate' => e.world_endpoints[1].dup,
            'layer_name'    => e.layer_name,
            'source_occurrence_id' => (sids_b.first || e.source_occurrence_id),
            'source_occurrence_ids' => sids_b,
            'canonical_node_id' => canonical_node_by_endpoint[ek_b] || "cns-#{ek_b}",
            'host_vertex_handle'  => nil,
            'curve_membership'   => (rec_b.respond_to?(:curve_membership) ? rec_b.curve_membership : nil),
            'face_adjacency_count' => (rec_b.respond_to?(:face_adjacency_count) ? rec_b.face_adjacency_count.to_i : 0),
            'origin_kind'    => e.origin_kind
          }
        end

        # Filter to OPEN endpoints (degree 1 in canonical
        # adjacency). Compute degree in endpoint_key space
        # (NOT canonical_node_id space) because endpoints that
        # share a canonical node (within coordinate_epsilon)
        # MUST be considered independently for gap repair —
        # only one endpoint of a clique is "open" relative to
        # its edge's other endpoint.
        endpoint_key_degree = Hash.new(0)
        adj_map.each do |k, vs|
          endpoint_key_degree[k] = vs.length
        end
        # A canonical_node is "open-degree-1" iff EXACTLY ONE of
        # its endpoint members has endpoint_key_degree == 1.
        # We collect endpoints whose endpoint_key_degree == 1 AND
        # are NOT in non-transitive clusters.
        open_endpoint_set = Set.new
        canonical_node_members = Hash.new { |h, k| h[k] = [] }
        endpoint_lookup.each do |ek, ep|
          cid = ep['canonical_node_id']
          canonical_node_members[cid] << ek if cid
        end
        endpoint_lookup.each do |ek, ep|
          next unless endpoint_key_degree[ek].to_i == 1
          next if non_trans_keys.include?(ek)
          cid = ep['canonical_node_id']
          members = canonical_node_members[cid] || []
          # Only endpoints whose canonical_node degree == 1 in
          # edge-adjacency space contribute (a clique with >1
          # member that all have endpoint_key_degree > 1 is a
          # closed loop, no open endpoints here).
          members_with_degree_one = members.count { |m| endpoint_key_degree[m].to_i == 1 }
          if members_with_degree_one == 1
            open_endpoint_set << ek
          end
        end
        open_endpoints = endpoint_lookup.values.select { |ep|
          open_endpoint_set.include?(ep['endpoint_key'].to_s)
        }
        # Filter out endpoints that belong to a non_transitive
        # canonical-node cluster (per Blueprint §8 final bullet).
        open_endpoints = open_endpoints.reject { |ep|
          non_trans_keys.include?(ep['endpoint_key'].to_s)
        }
        # Filter out endpoints belonging to Curve / Arc / Face
        # context. We rely on endpoint_record's curve_membership /
        # face_adjacency_count annotations; the topology
        # snapshot published by WorkingModeRunner carries these
        # as endpoint_lookup values.
        # ---- Spatial candidate retrieval ----
        cell_size = [gap_search, coord_eps, 1.0e-4].max
        bucket = Hash.new { |h, k| h[k] = [] }
        open_endpoints.each do |ep|
          key = _bucket_key(ep['world_coordinate'], cell_size)
          bucket[key] << ep
        end
        # For each open endpoint, find candidates in adjacent
        # cells within `gap_search` distance. Emit candidates
        # in BOTH directions so the mutual-uniqueness check
        # can pair a with b AND b with a (Blueprint §10.1).
        candidates_by_a = Hash.new { |h, k| h[k] = [] }
        open_endpoints.each do |ep_a|
          cx, cy, cz = _bucket_key(ep_a['world_coordinate'], cell_size)
          reach = ((gap_search / cell_size).ceil + 1).to_i
          (-reach..reach).each do |dx|
            (-reach..reach).each do |dy|
              (-reach..reach).each do |dz|
                nk = [cx + dx, cy + dy, cz + dz]
                next unless bucket.key?(nk)
                bucket[nk].each do |ep_b|
                  next if ep_b['endpoint_key'] == ep_a['endpoint_key']
                  if ep_b['derived_edge_id'] == ep_a['derived_edge_id']
                    # No same-edge self-pair (Blueprint §10.4).
                    next
                  end
                  d = _distance(ep_a['world_coordinate'], ep_b['world_coordinate'])
                  # ---- Basic filters ----
                  if d <= coord_eps
                    candidates_by_a[ep_a['endpoint_key']] << {
                      'endpoint' => ep_b,
                      'distance' => d,
                      'reason'   => REASON_CLOSE_ENOUGH_NO_BRIDGE
                    }
                    next
                  end
                  if d > gap_search
                    next
                  end
                  # Z compatibility (§9 step 5).
                  if (ep_a['world_coordinate'][2] - ep_b['world_coordinate'][2]).abs > coord_eps
                    next
                  end
                  candidates_by_a[ep_a['endpoint_key']] << {
                    'endpoint' => ep_b,
                    'distance' => d,
                    'reason'   => REASON_OK
                  }
                end
              end
            end
          end
        end

        # ---- Pair authority (mutual uniqueness, §10.1) ----
        # A is "ready" only if exactly one B candidate in
        # gap_search (i.e. exactly one OK reason that is not
        # REASON_CLOSE_ENOUGH_NO_BRIDGE). Symmetrically B must
        # also have exactly one.
        ready_a = {}
        review = {}
        candidates_by_a.each do |a_key, candidates|
          ok_candidates = candidates.select { |c| c['reason'] == REASON_OK }
          if ok_candidates.length == 1
            ready_a[a_key] = ok_candidates.first
          else
            review[a_key] = candidates
          end
        end

        # Mutual uniqueness: B must also have exactly one ready.
        mutual_ready = {}
        ready_a.each do |a_key, cand|
          b_key = cand['endpoint']['endpoint_key']
          b_ready = ready_a[b_key]
          next if b_ready.nil?
          # Ensure symmetry: B's OK candidate must be A.
          if b_ready['endpoint']['endpoint_key'] == a_key
            pair_key = [a_key, b_key].sort
            mutual_ready[pair_key] = [a_key, b_key]
          end
        end

        # ---- Layer evidence (§10.2) ----
        # If both endpoints have known source-layer identities
        # AND they differ: REVIEW_REQUIRED.
        # If one or both are unknown: implementation may still
        # execute, but we MUST record the evidence.
        layer_review = {}
        mutual_ready.keys.each do |pair_key|
          a_key, b_key = pair_key
          ep_a = endpoint_lookup[a_key]
          ep_b = endpoint_lookup[b_key]
          next unless ep_a && ep_b
          la = ep_a['layer_name']
          lb = ep_b['layer_name']
          if !la.nil? && !la.empty? && !lb.nil? && !lb.empty? && la.to_s != lb.to_s
            layer_review[pair_key] = REASON_CROSS_LAYER
          end
        end

        # ---- Curve/Face context ----
        # The endpoint_lookup entries may carry
        # curve_membership / face_adjacency_count annotations
        # populated by the proposer prep phase. If either
        # endpoint is curve/face-context ineligible, drop it.
        curve_review = {}
        mutual_ready.keys.each do |pair_key|
          a_key, b_key = pair_key
          ep_a = endpoint_lookup[a_key]
          ep_b = endpoint_lookup[b_key]
          next unless ep_a && ep_b
          ca = ep_a['curve_membership']
          cb = ep_b['curve_membership']
          fa = ep_a['face_adjacency_count'].to_i
          fb = ep_b['face_adjacency_count'].to_i
          if (!ca.nil? && !ca.to_s.empty?) || fa > 0 ||
             (!cb.nil? && !cb.to_s.empty?) || fb > 0
            curve_review[pair_key] = REASON_CURVE_FACE
          end
        end

        # ---- Build proposals ----
        ready_proposals  = []
        review_proposals = []
        # Build a quick map: pair_key -> reason if non-OK
        pair_reason = {}
        layer_review.each  { |k, v| pair_reason[k] = v }
        curve_review.each  { |k, v| pair_reason[k] = v }
        mutual_ready.each do |pair_key, (a_key, b_key)|
          ep_a = endpoint_lookup[a_key]
          ep_b = endpoint_lookup[b_key]
          d = _distance(ep_a['world_coordinate'], ep_b['world_coordinate'])
          proposal_id = _proposal_id(a_key, b_key, d, gap_search, coord_eps)
          base = {
            'proposal_id'         => proposal_id,
            'action_type'         => ACTION_TYPE,
            'endpoint_a_key'      => a_key,
            'endpoint_b_key'      => b_key,
            'canonical_node_a_id' => ep_a['canonical_node_id'],
            'canonical_node_b_id' => ep_b['canonical_node_id'],
            'distance'            => d,
            'gap_search'          => gap_search,
            'coordinate_epsilon'  => coord_eps,
            'layer_a'             => ep_a['layer_name'],
            'layer_b'             => ep_b['layer_name'],
            'incident_derived_edge_ids'   => [ep_a['derived_edge_id'], ep_b['derived_edge_id']],
            # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-003:
            # plural source provenance end-to-end. The
            # `incident_source_occurrence_ids` field carries
            # the FULL sorted/uniq union from BOTH incident
            # sides (a + b), including duplicates that reduce
            # to a single occurrence ID. Built by the shared
            # `_plurals_union` helper from the plural
            # endpoint_lookup entries.
            'incident_source_occurrence_ids' => _plurals_union(ep_a, ep_b),
            'expected_bridge_endpoints' => [ep_a['world_coordinate'].dup, ep_b['world_coordinate'].dup],
            'expected_bridge_length'    => d,
            'rule_id'             => RULE_ID,
            'rule_version'        => RULE_VERSION
          }
          if pair_reason[pair_key]
            base['state']    = STATE_REVIEW_REQUIRED
            base['reason']   = pair_reason[pair_key]
            base['executable'] = false
            review_proposals << base
          else
            # Crossing check is handled by an external
            # checker (Blueprint §10.3). If a checker was
            # supplied, defer to it; otherwise the
            # proposal is SAFE by default.
            crossing = if crossing_checker
                         crossing_checker.call(base, derived_edges, endpoint_lookup, topology_snapshot)
                       else
                         { 'safe' => true, 'reasons' => [] }
                       end
            if crossing.is_a?(Hash) && crossing['safe']
              base['state']      = STATE_READY_TO_REPAIR
              base['reason']     = REASON_OK
              base['executable'] = true
              base['crossing_reasons'] = []
              ready_proposals << base
            else
              base['state']    = STATE_REVIEW_REQUIRED
              base['reason']   = (crossing['reasons'] || []).first || REASON_BRIDGE_CROSSING
              base['executable'] = false
              base['crossing_reasons'] = Array(crossing['reasons']).map(&:to_s)
              review_proposals << base
            end
          end
        end

        # ---- X3 / Bridge conflict ----
        # Blueprint §10.3: two proposed bridges must not
        # cross OR overlap (collinear) OR T-junction each
        # other in the interior.
        # Walk every pair of ready_proposals; if their
        # bridge segments conflict in any V1.7-conservative
        # way, demote both to REVIEW_REQUIRED with reason
        # `bridge_conflict`. The executor's preflight
        # already rejects pairwise endpoint-disjoint
        # violations; X3 adds the segment-conflict check
        # (proper crossing / collinear overlap / T-junction)
        # that preflight does NOT do.
        # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R1.
        #
        # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-002:
        # uses the SHARED PURE V1.7 segment-conflict
        # predicate (core/segment_conflict.rb). The shared
        # predicate detects proper crossing, full collinear
        # containment, partial collinear interior overlap,
        # and T-junction intent. Two proposals sharing an
        # endpoint (legitimate vertex meeting, not interior
        # crossing) remain un-demoted.
        if ready_proposals.length >= 2
          require_relative 'segment_conflict'
          conflict_pairs = []
          (0...ready_proposals.length).each do |i|
            (i + 1...ready_proposals.length).each do |j|
              pi = ready_proposals[i]
              pj = ready_proposals[j]
              eps_i = pi['expected_bridge_endpoints']
              eps_j = pj['expected_bridge_endpoints']
              next unless eps_i.is_a?(Array) && eps_i.length == 2 &&
                          eps_j.is_a?(Array) && eps_j.length == 2
              # Two proposals sharing an endpoint are allowed
              # (they meet at a vertex, not an interior
              # crossing).
              shared = [pi['endpoint_a_key'], pi['endpoint_b_key']].any? { |k|
                [pj['endpoint_a_key'], pj['endpoint_b_key']].include?(k)
              }
              next if shared
              seg = SUAnalysis::Core::SegmentConflict.conflict?(
                [eps_i[0], eps_i[1]], [eps_j[0], eps_j[1]], eps: coord_eps
              )
              if seg['conflict']
                conflict_pairs << [i, j]
              end
            end
          end
          unless conflict_pairs.empty?
            demote = conflict_pairs.flatten.uniq
            demote.each do |idx|
              p = ready_proposals[idx]
              p['state']    = STATE_REVIEW_REQUIRED
              p['reason']   = REASON_BRIDGE_CONFLICT
              p['executable'] = false
              p['crossing_reasons'] = Array(p['crossing_reasons']) + [REASON_BRIDGE_CONFLICT]
              review_proposals << p
            end
            ready_proposals = ready_proposals.reject.with_index { |_p, idx| demote.include?(idx) }
          end
        end

        # Ambiguous / cross-layer / curve-face / non-OK
        # candidates emitted as REVIEW_REQUIRED evidence per
        # endpoint.
        candidates_by_a.each do |a_key, candidates|
          ok_candidates = candidates.select { |c| c['reason'] == REASON_OK }
          next if ok_candidates.length == 1  # already handled as ready_a
          ep_a = endpoint_lookup[a_key]
          next unless ep_a
          ok_candidates.each_with_index do |cand, idx|
            ep_b = cand['endpoint']
            d = cand['distance']
            pair_key = [a_key, ep_b['endpoint_key']].sort
            next if mutual_ready.key?(pair_key)
            review_proposals << {
              'proposal_id'      => _proposal_id(a_key, ep_b['endpoint_key'], d, gap_search, coord_eps),
              'action_type'      => ACTION_TYPE,
              'endpoint_a_key'   => a_key,
              'endpoint_b_key'   => ep_b['endpoint_key'],
              'canonical_node_a_id' => ep_a['canonical_node_id'],
              'canonical_node_b_id' => ep_b['canonical_node_id'],
              'distance'         => d,
              'gap_search'       => gap_search,
              'coordinate_epsilon'  => coord_eps,
              'layer_a'          => ep_a['layer_name'],
              'layer_b'          => ep_b['layer_name'],
              'incident_derived_edge_ids'  => [ep_a['derived_edge_id'], ep_b['derived_edge_id']],
              'incident_source_occurrence_ids' => _plurals_union(ep_a, ep_b),
              'expected_bridge_endpoints' => [ep_a['world_coordinate'].dup, ep_b['world_coordinate'].dup],
              'expected_bridge_length'    => d,
              'state'       => STATE_REVIEW_REQUIRED,
              'reason'      => ok_candidates.length > 1 ? REASON_AMBIGUOUS_NEIGHBORS : REASON_MUTUAL_UNIQUE_FAIL,
              'executable'  => false,
              'rule_id'     => RULE_ID,
              'rule_version' => RULE_VERSION
            }
          end
        end

        # ---- Summaries ----
        state = if ready_proposals.any?
                  STATE_READY_TO_REPAIR
                elsif review_proposals.any?
                  STATE_REVIEW_REQUIRED
                elsif open_endpoints.any?
                  STATE_NO_CANDIDATE
                else
                  STATE_NO_CANDIDATE
                end
        {
          'state'            => state,
          'ready_proposals'  => ready_proposals,
          'review_proposals' => review_proposals,
          'open_endpoint_count' => open_endpoints.length,
          'metrics'          => {
            'open_endpoint_count' => open_endpoints.length,
            'ready_proposal_count'  => ready_proposals.length,
            'review_proposal_count' => review_proposals.length
          },
          'rule_id'         => RULE_ID,
          'rule_version'    => RULE_VERSION,
          'tolerance'       => { 'gap_search' => gap_search, 'coordinate_epsilon' => coord_eps }.freeze,
          'schema_version'  => PROVENANCE_SCHEMA_VERSION
        }.freeze
      end

      # ---- helpers ----

      # V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01 R5 fix:
      # CanonicalTopologyBuilder.build publishes STRING-keyed
      # results, while the historical in-test callers passed
      # SYMBOL-keyed Hashes. The previous symbol-only reads
      # silently resolved to nil on the ACTUAL production
      # WorkingModeRunner.compute_gap_repair path, so
      # `canonical_node_clusters` was empty there: coincident
      # corner endpoints were never merged into one canonical
      # node (Blueprint §7) and were mis-reported as open
      # endpoints (Blueprint §8). Read symbol first, then
      # string. Same defensive pattern already used by
      # CanonicalGeometryGraph.build_from_workspace.
      def _ts_read(topology_snapshot, key)
        return nil unless topology_snapshot.respond_to?(:[])
        v = topology_snapshot[key]
        return v unless v.nil?
        topology_snapshot[key.to_s]
      end

      def _bucket_key(coord, cell_size)
        x = (coord[0].to_f / cell_size).floor
        y = (coord[1].to_f / cell_size).floor
        z = (coord[2].to_f / cell_size).floor
        [x, y, z]
      end

      def _distance(a, b)
        dx = a[0] - b[0]
        dy = a[1] - b[1]
        dz = a[2] - b[2]
        Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
      end

      # Strict 2D interior intersection test for two segments,
      # used by the X3 bridge-conflict check.
      # Returns true iff the segments cross at a non-endpoint
      # point in the XY plane (the V1.7 base Z-compat test
      # already excludes non-coplanar bridges upstream).
      #
      # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-002:
      # delegates to the SHARED PURE V1.7 segment-conflict
      # predicate in core/segment_conflict.rb. The previous
      # implementation used strict orientation crossing only,
      # which returns false for collinear cases, so V1.7
      # could accept overlapping bridges despite the
      # conservative repair contract. The shared predicate
      # now detects collinear overlap AND proper crossing in
      # one place; the proposer's X3 check + the runner's
      # crossing checker + this helper all share one source
      # of truth. Backwards-compatible: returns true iff the
      # segment conflict is a PROPER crossing or a COLLINEAR
      # OVERLAP (so X3 demotes both bridge forms together).
      def _segments_intersect_interior?(p1, p2, q1, q2, eps)
        return false unless p1.is_a?(Array) && p2.is_a?(Array) &&
                            q1.is_a?(Array) && q2.is_a?(Array)
        require_relative 'segment_conflict'
        r = SUAnalysis::Core::SegmentConflict.conflict?([p1, p2], [q1, q2], eps: eps)
        return false unless r['conflict']
        r['reason'] == 'proper_interior_crossing' || r['reason'] == 'collinear_overlap'
      end

      # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-002:
      # legacy 2D orientation predicate retained for
      # backwards-compatible callers. The shared
      # SegmentConflict.conflict? predicate is the
      # authoritative source of truth.
      def _segment_orientation(p, q, r)
        (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
      end

      def _shared_endpoint?(a, b, eps)
        return false unless a.is_a?(Array) && b.is_a?(Array)
        dx = a[0] - b[0]
        dy = a[1] - b[1]
        dz = a[2] - b[2]
        Math.sqrt((dx * dx) + (dy * dy) + (dz * dz)) <= eps
      end

      def _build_canonical_adjacency(derived_edges)
        adj = Hash.new { |h, k| h[k] = [] }
        cluster_lookup = {}
        derived_edges.each_with_index do |e, _idx|
          ak = e.endpoint_a_key
          bk = e.endpoint_b_key
          adj[ak] << bk unless adj[ak].include?(bk)
          adj[bk] << ak unless adj[bk].include?(ak)
        end
        adj
      end

      def _proposal_id(a_key, b_key, distance, gap_search, coord_eps)
        # Deterministic ID. Stable for an unchanged pair +
        # tolerance values.
        keys = [a_key.to_s, b_key.to_s].sort.join('|')
        body = "gap.v1|#{keys}|#{sprintf('%.10f', distance.to_f)}|#{sprintf('%.10f', gap_search.to_f)}|#{sprintf('%.10f', coord_eps.to_f)}"
        'gp-' + Digest::SHA256.hexdigest(body)[0, 16]
      end

      # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-003:
      # plural source provenance is authoritative end-to-end.
      # Resolve the COMPLETE sorted/uniq union of source
      # occurrence IDs from the EndpointRecord (preferred) or
      # fall back to the DerivedEdgeRecord's plural field.
      # Returns a frozen sorted/uniq String Array (no nils,
      # no empties).
      def _plurals_from(endpoint_record, derived_edge)
        out = []
        if endpoint_record.is_a?(EndpointRecord)
          out.concat(endpoint_record.source_occurrence_ids)
        elsif endpoint_record.respond_to?(:source_occurrence_ids)
          out.concat(Array(endpoint_record.source_occurrence_ids))
        end
        if out.empty? && derived_edge.respond_to?(:source_occurrence_ids)
          out.concat(Array(derived_edge.source_occurrence_ids))
        end
        if out.empty? && derived_edge.respond_to?(:source_occurrence_id) &&
           derived_edge.source_occurrence_id
          out << derived_edge.source_occurrence_id.to_s
        end
        out.map { |v| v.nil? ? '' : v.to_s }
           .reject { |s| s.empty? }
           .uniq
           .sort
           .freeze
      end

      # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-003:
      # compute the COMPLETE sorted/uniq union of source
      # occurrence IDs across BOTH incident sides of a bridge.
      # Deliberate duplicates are deduplicated deterministically.
      def _plurals_union(ep_a, ep_b)
        a = ep_a.is_a?(Hash) ? Array(ep_a['source_occurrence_ids']) : []
        b = ep_b.is_a?(Hash) ? Array(ep_b['source_occurrence_ids']) : []
        (a + b).map { |v| v.nil? ? '' : v.to_s }
                .reject { |s| s.empty? }
                .uniq
                .sort
                .freeze
      end
    end

    # Backwards-compatible: if Set isn't loaded by some test
    # environment, define a thin fallback.
    unless defined?(Set)
      class Set
        def initialize(ary = [])
          @h = {}
          Array(ary).each { |x| @h[x] = true }
        end
        def include?(x); @h.key?(x); end
        def add(x); @h[x] = true; x; end
        def <<(x); @h[x] = true; self; end
        def to_a; @h.keys; end
        def flat_map(&blk); to_a.flat_map(&blk); end
      end
    end

  end
end
