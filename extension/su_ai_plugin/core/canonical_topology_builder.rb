#
# core/canonical_topology_builder.rb — V1.7 CanonicalTopology
# builder with NON-TRANSITIVE coordinate_epsilon clustering.
#
# Per frozen V1.7 Blueprint §7:
#
#   "Two endpoint records may share one CanonicalNode only when
#    their actual current world coordinates directly match
#    within `coordinate_epsilon`. Do not use transitive union
#    blindly.
#    Example: A ~= B, B ~= C, A !~= C must NOT silently become
#    one canonical node."
#
# Algorithm:
#   1. Bucket endpoints by spatial cell (cell_size = max of
#      coordinate_epsilon and a small floor) so the pairwise
#      check is O(K) per cell, not O(V^2).
#   2. For each cell + each endpoint in it, check the
#      endpoint's direct distance to every other endpoint in
#      the same / adjacent cell using coordinate_epsilon.
#   3. Build a direct pairwise `~=` relation. Build the
#      connected components of that relation.
#   4. For each component, check whether every pair directly
#      matches within coordinate_epsilon:
#       - if YES  -> one canonical node (deterministic ID).
#       - if NO   -> mark non_transitive_node_cluster; emit
#                    separate per-endpoint canonical node
#                    records (deterministic IDs); do not
#                    collapse identity.
#
# V1.7 Blueprint §7.2 explicit: "if every pair directly
# matches within `coordinate_epsilon`, create one canonical
# node; otherwise mark `non_transitive_node_cluster`, do not
# collapse the component into one identity, keep deterministic
# separate node records / unresolved topology evidence."
#
# The output `canonical_nodes` carries per-endpoint records
# (one record per EndpointRecord). The
# `canonical_node_clusters` Hash groups endpoint_keys that
# belong to the same Safe-Clique canonical node.
#

require 'digest'

module SUAnalysis
  module Core
    module CanonicalTopologyBuilder
      module_function

      BUCKET_MIN_CELL = 1.0e-4  # floor for the bucketing cell
      PROVENANCE_SCHEMA_VERSION = 'cano-node.v1'.freeze

      # Build canonical nodes from the current endpoint list.
      #
      # Inputs:
      #   endpoints:         Array<EndpointRecord>
      #   coordinate_epsilon:Float (>0)
      #
      # Returns a frozen Hash with:
      #   canonical_nodes:   Array<Hash>  (per-endpoint record)
      #   canonical_node_clusters: Hash<String, Array<String>>  (cluster_id -> endpoint_keys)
      #   non_transitive_clusters:  Array<Hash>  (one per detected cluster)
      #   open_endpoints:    Array<String> (endpoint_keys with degree 1)
      #   unresolved_topology_issues: Array<String> (stable reason codes)
      #   metrics:           Hash
      def build(endpoints:, coordinate_epsilon:)
        eps = coordinate_epsilon.to_f
        if eps <= 0
          raise ArgumentError, "coordinate_epsilon must be > 0; got #{eps}"
        end
        result = _empty_result
        epss = endpoints.is_a?(Array) ? endpoints : []
        return result if epss.empty?

        # ---- Step 1: bucket ----
        cell_size = [eps, BUCKET_MIN_CELL].max
        bucket = Hash.new { |h, k| h[k] = [] }
        epss.each_with_index do |ep, idx|
          next unless ep.is_a?(EndpointRecord)
          key = _bucket_key(ep.world_coordinate, cell_size)
          bucket[key] << [ep, idx]
        end

        # ---- Step 2: direct pairwise ~= -- adjacency list ----
        # For each endpoint, find every endpoint in the same
        # cell + adjacent cells whose coordinate is within
        # coordinate_epsilon. Two endpoints "directly match"
        # iff coordinate distance within eps.
        n = epss.length
        adj = Array.new(n) { [] }
        visited_cell_keys = []
        bucket.each_key do |cell_key|
          # Expand to cells within 1 step from the cell.
          cx, cy, cz = cell_key
          range = (-1..1)
          cell_range = [range, range, range]
          # Pull all endpoints in the 3x3x3 neighborhood.
          neighbors = []
          cell_range[0].each do |dx|
            cell_range[1].each do |dy|
              cell_range[2].each do |dz|
                nk = [cx + dx, cy + dy, cz + dz]
                next unless bucket.key?(nk)
                neighbors.concat(bucket[nk])
              end
            end
          end
          bucket[cell_key].each do |pair_a|
            ep_a, idx_a = pair_a
            neighbors.each do |pair_b|
              ep_b, idx_b = pair_b
              next if idx_a == idx_b
              next if idx_b <= idx_a  # only process each pair once
              d = _distance(ep_a.world_coordinate, ep_b.world_coordinate)
              next unless d <= eps
              adj[idx_a] << idx_b
              adj[idx_b] << idx_a
            end
          end
        end

        # ---- Step 3: connected components ----
        comp_id = Array.new(n, -1)
        components = []
        n.times do |i|
          next if comp_id[i] >= 0
          comp = []
          stack = [i]
          comp_id[i] = components.length
          until stack.empty?
            cur = stack.pop
            comp << cur
            adj[cur].each do |j|
              next if comp_id[j] >= 0
              comp_id[j] = components.length
              stack << j
            end
          end
          components << comp
        end

        # ---- Step 4: per-component decision ----
        canonical_nodes = []
        canonical_node_clusters = {}
        non_transitive_clusters = []
        open_endpoints = []
        unresolved_topology_issues = []

        # Deterministic component iteration. The previous
        # form used `comp.first` (the DFS-discovery first
        # member), which is NOT necessarily the lex-
        # smallest endpoint_key in the component. Two
        # interleaved components could therefore swap
        # output order when the input enumeration changed.
        #
        # V17-CODEX-BLOCK-FINAL-RESIDUAL-FIX-2026-09-02
        # INT-001: derive a stable component key from the
        # SORTED endpoint_keys of EVERY member of the
        # component. This is independent of DFS / input
        # order: forward / reversed / shuffled input all
        # yield identical sorted component keys and
        # therefore identical component order.
        components_sorted = components.each_with_index.sort_by do |comp, _idx|
          if comp.empty?
            ''
          else
            comp.map { |i| epss[i].endpoint_key.to_s }.sort.join('|')
          end
        end

        components_sorted.each do |comp, comp_idx|
          next if comp.empty?
          # Check direct pairwise ~= for every pair IN this
          # component.
          all_pairwise_match = true
          ci = comp.length - 1
          ci.times do |i|
            (i + 1..ci).each do |j|
              a = epss[comp[i]]
              b = epss[comp[j]]
              d = _distance(a.world_coordinate, b.world_coordinate)
              if d > eps
                all_pairwise_match = false
                break
              end
            end
            break unless all_pairwise_match
          end

          # Deterministic sort of endpoints in this component
          # by endpoint_key (stable across rebuilds).
          sorted_indices = comp.sort_by { |i| epss[i].endpoint_key.to_s }

          if comp.length == 1
            # Singleton component -> per-endpoint canonical
            # node AND per-endpoint cluster entry (already
            # handled by the singleton block below; skip).
            next
          end

          if all_pairwise_match && comp.length >= 2
            # Safe clique: one canonical node.
            cluster_id = _canonical_node_id(sorted_indices, epss, eps)
            endpoint_keys = sorted_indices.map { |i| epss[i].endpoint_key.to_s }
            canonical_node_clusters[cluster_id] = endpoint_keys
            sorted_indices.each_with_index do |ep_idx, pos|
              ep = epss[ep_idx]
              canonical_nodes << _build_canonical_node_record(
                cluster_id: cluster_id,
                endpoint:   ep,
                position:   pos,
                eps:        eps,
                resolved:   true
              )
            end
          else
            # Non-transitive cluster: emit one canonical node
            # record per endpoint (no identity collapse).
            #
            # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-001:
            # the cluster id MUST NOT depend on DFS discovery
            # order. The previous form
            #   "ntc-#{comp_idx}-#{_digest_component(...)}"
            # included `comp_idx` (the ORIGINAL pre-sort
            # discovery index of the component), which meant
            # the SAME endpoint membership produced DIFFERENT
            # cluster_ids when the input was shuffled /
            # reversed / fed in a different host iteration
            # order. The fix drops `comp_idx` entirely: the
            # cluster id now derives ONLY from a stable digest
            # of the SORTED endpoint_keys (i.e. the cluster
            # membership, not the discovery order). The
            # per-member canonical_node_id
            # `#{cluster_id}.n#{position}` likewise derives
            # its position from the sorted-by-endpoint_key
            # iteration of `sorted_indices`, which is also
            # stable across rebuilds.
            cluster_id = "ntc-#{_digest_component(sorted_indices, epss)}"
            endpoint_keys = sorted_indices.map { |i| epss[i].endpoint_key.to_s }
            non_transitive_clusters << {
              'cluster_id'    => cluster_id,
              'endpoint_keys' => endpoint_keys,
              'reason'        => 'non_transitive_node_cluster',
              'size'          => endpoint_keys.length
            }.freeze
            unresolved_topology_issues << 'non_transitive_node_cluster'
            sorted_indices.each_with_index do |ep_idx, pos|
              ep = epss[ep_idx]
              canonical_nodes << _build_canonical_node_record(
                cluster_id: cluster_id,
                endpoint:   ep,
                position:   pos,
                eps:        eps,
                resolved:   false
              )
            end
          end
        end

        # Singleton endpoints (any component of size 1) ->
        # per-endpoint canonical node AND per-endpoint cluster
        # entry.
        singleton_indices = (0...n).to_a.reject { |i| comp_id[i] < 0 }
                          .select { |i| components[comp_id[i]] && components[comp_id[i]].length == 1 }
        singleton_indices.sort_by { |i| epss[i].endpoint_key.to_s }.each_with_index do |idx, pos|
          ep = epss[idx]
          next unless ep.is_a?(EndpointRecord)
          cluster_id = _singleton_node_id(ep, eps)
          canonical_node_clusters[cluster_id] = [ep.endpoint_key.to_s]
          canonical_nodes << _build_canonical_node_record(
            cluster_id: cluster_id,
            endpoint:   ep,
            position:   pos,
            eps:        eps,
            resolved:   true
          )
        end

        # ---- Open endpoints: degree 1 in the canonical edge
        # adjacency (recomputed below). This pass is a STUB;
        # the runner rebuilds the full adjacency from the
        # canonical edges after gap-pair matching.
        # ---- Provenance digest ----
        #
        # V17-CODEX-BLOCK-FINAL-RESIDUAL-FIX-2026-09-02
        # INT-001: defensively re-sort the published
        # canonical_nodes + non_transitive_clusters +
        # canonical_node_clusters by stable keys BEFORE
        # freezing, so the published array order is
        # independent of which component the DFS finished
        # first (even within a single component class) and
        # independent of which cluster the iteration chose
        # to publish first. canonical_nodes sorts by
        # (canonical_node_id, endpoint_key); non_transitive
        # clusters sort by cluster_id; canonical_node_clusters
        # is a Hash (already keyed by cluster_id) so its
        # iteration order is Hash insertion order — we
        # explicitly rebuild it in cluster_id-sorted order
        # so external consumers that serialize it get a
        # stable representation. Forward / reversed /
        # shuffled input enumerations must produce
        # byte-identical published payloads.
        sorted_canonical_nodes = canonical_nodes.sort_by { |n|
          [n['canonical_node_id'].to_s, n['endpoint_key'].to_s]
        }
        sorted_non_transitive_clusters = non_transitive_clusters.sort_by { |c|
          c['cluster_id'].to_s
        }
        sorted_canonical_node_clusters = {}
        canonical_node_clusters.keys.map(&:to_s).sort.each do |cid|
          sorted_canonical_node_clusters[cid] = canonical_node_clusters[cid]
        end
        {
          'canonical_nodes'              => sorted_canonical_nodes.freeze,
          'canonical_node_clusters'      => sorted_canonical_node_clusters.freeze,
          'non_transitive_clusters'      => sorted_non_transitive_clusters.freeze,
          'open_endpoints'               => open_endpoints.freeze,
          'unresolved_topology_issues'   => unresolved_topology_issues.freeze,
          'metrics'                      => _metrics(endpoints, sorted_canonical_nodes, sorted_non_transitive_clusters).freeze,
          'coordinate_epsilon'           => eps,
          'schema_version'               => PROVENANCE_SCHEMA_VERSION
        }.freeze
      end

      def _empty_result
        {
          'canonical_nodes'              => [].freeze,
          'canonical_node_clusters'      => {}.freeze,
          'non_transitive_clusters'      => [].freeze,
          'open_endpoints'               => [].freeze,
          'unresolved_topology_issues'   => [].freeze,
          'metrics'                      => { 'endpoint_count' => 0, 'canonical_node_count' => 0, 'non_transitive_cluster_count' => 0 }.freeze,
          'coordinate_epsilon'           => 1.0e-6,
          'schema_version'               => PROVENANCE_SCHEMA_VERSION
        }.freeze
      end

      def _bucket_key(coord, cell_size)
        # Round to integer cells. Use floor() so negative
        # coords bucket predictably.
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

      def _build_canonical_node_record(cluster_id:, endpoint:, position:, eps:, resolved:)
        # V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01 R6/R8 fix
        # (Blueprint §7.2 / §7.3):
        #
        # A SAFE CLIQUE is ONE canonical node. Every endpoint
        # member of a resolved clique must therefore share the
        # SAME deterministic `canonical_node_id`. The previous
        # `"#{cluster_id}.n#{position}"` form minted a DIFFERENT
        # id per clique member, so an exactly-coincident corner
        # (two derived edges meeting at one point) produced two
        # distinct canonical nodes. Downstream that split the
        # CanonicalGeometryGraph of a real almost-closed
        # triangle into disjoint degree-1 fragments: the
        # rebuilt graph could never be connected and could
        # never contain a cycle, which is exactly what
        # Blueprint §15.2 adjacency + §18.5 T3/T4 require.
        #
        # A NON-TRANSITIVE cluster must NOT collapse identity
        # (§7.2), so its members keep distinct per-member ids.
        canonical_node_id = resolved ? cluster_id.to_s :
                              "#{cluster_id}.n#{position}"
        {
          'canonical_node_id' => canonical_node_id,
          'endpoint_key'      => endpoint.endpoint_key.to_s,
          'derived_edge_id'   => endpoint.derived_edge_id.to_s,
          'role'              => endpoint.role.to_s,
          'world_coordinate'  => endpoint.world_coordinate.dup,
          'layer_name'        => endpoint.layer_name,
          'source_occurrence_id' => endpoint.source_occurrence_id,
          'resolved_clique'   => resolved ? true : false,
          'coordinate_epsilon' => eps
        }.freeze
      end

      # Deterministic ID for a safe-clique canonical node.
      # Inputs are the sorted endpoint_keys + their sorted
      # world coordinates + tolerance. Stable across rebuilds.
      def _canonical_node_id(sorted_indices, epss, eps)
        keys = sorted_indices.map { |i| epss[i].endpoint_key.to_s }.join('|')
        coords = sorted_indices.map { |i|
          ax = epss[i].world_coordinate
          sprintf('%.10f|%.10f|%.10f', ax[0], ax[1], ax[2])
        }.join('|')
        digest_input = "cano-node.v1|#{eps.to_f}|#{keys}|#{coords}"
        'cn-' + Digest::SHA256.hexdigest(digest_input)[0, 16]
      end

      # Deterministic ID for a singleton canonical node.
      def _singleton_node_id(ep, eps)
        ax = ep.world_coordinate
        coord = sprintf('%.10f|%.10f|%.10f', ax[0], ax[1], ax[2])
        digest_input = "cano-singleton.v1|#{eps.to_f}|#{ep.endpoint_key}|#{coord}"
        'cns-' + Digest::SHA256.hexdigest(digest_input)[0, 16]
      end

      def _digest_component(sorted_indices, epss)
        keys = sorted_indices.map { |i| epss[i].endpoint_key.to_s }.join('|')
        'ntc-' + Digest::SHA256.hexdigest("ntc.v1|#{keys}")[0, 12]
      end

      def _metrics(endpoints, canonical_nodes, non_transitive_clusters)
        {
          'endpoint_count'              => endpoints.length,
          'canonical_node_count'        => canonical_nodes.length,
          'non_transitive_cluster_count' => non_transitive_clusters.length
        }
      end
    end
  end
end
