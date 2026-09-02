#
# core/canonical_geometry_graph.rb — V1.7 CanonicalGeometryGraph.
#
# Per frozen V1.7 Blueprint §15:
#
#   "V1.7 introduces the first durable `CanonicalGeometryGraph`.
#    This is a logical immutable snapshot derived from CURRENT
#    derived geometry. It must not be a live mirror that relies
#    on SketchUp observer replay."
#
# Conceptually:
#
#   CanonicalGeometryGraph
#     - schema_version
#     - source_snapshot_id
#     - execution_config_digest
#     - nodes
#     - edges
#     - adjacency
#     - unresolved_topology_issues
#     - metrics
#     - provenance_digest / reproducibility metadata as
#       appropriate
#
# §15.1 CanonicalEdge:
#   - canonical_edge_id
#   - node_a_id, node_b_id
#   - origin_kind
#   - current derived ID / generated repair ID
#   - source occurrence provenance
#   - repair_action_id if generated
#   - current world endpoint coordinates
#   - layer provenance
#   - unresolved flags
#
# Per §15.2 adjacency:
#   Adjacency is rebuilt deterministically from canonical
#   edges after Prepare / Rebuild / V1.5 duplicate repair /
#   V1.6 normalization apply / V1.7 gap repair apply. Do NOT
#   incrementally patch adjacency from assumed host events as
#   the only truth. Recompute from current workspace state.
#
# The graph is a PURE value object. It carries a
# `digest` (SHA-256) of its canonical content so rebuilds can
# detect drift. The graph does NOT carry host handles.
#

require 'digest'
require_relative 'canonical_topology_builder'

module SUAnalysis
  module Core
    class CanonicalGeometryGraph
      # Locked schema version (frozen Blueprint §15). Bump on
      # any field-set change.
      SCHEMA_VERSION = 'cgg.v1'.freeze

      # Origin kinds carried by CanonicalEdge (per §15.1).
      ORIGIN_SOURCE_DERIVED               = 'source_derived'.freeze
      ORIGIN_DUPLICATE_REPAIR_SURVIVOR    = 'duplicate_repair_survivor'.freeze
      ORIGIN_GENERATED_GAP_BRIDGE         = 'gap_bridge'.freeze

      attr_reader :schema_version, :source_snapshot_id, :execution_config_digest,
                  :workspace_id, :nodes, :edges, :adjacency,
                  :unresolved_topology_issues, :metrics,
                  :non_transitive_clusters, :open_endpoints, :digest,
                  :built_at, :tolerance_digest

      def initialize(schema_version: SCHEMA_VERSION,
                     source_snapshot_id:, execution_config_digest:,
                     workspace_id:,
                     nodes:, edges:, adjacency:,
                     unresolved_topology_issues:,
                     metrics:, non_transitive_clusters:,
                     open_endpoints:,
                     tolerance_digest:,
                     built_at: nil)
        @schema_version              = schema_version.to_s.freeze
        @source_snapshot_id          = source_snapshot_id.to_s
        @execution_config_digest     = execution_config_digest.to_s
        @workspace_id                = workspace_id.to_s
        # V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-07:
        # collapse per-endpoint canonical_node records into
        # ONE LOGICAL NODE per canonical_node_id before
        # publication. The internal endpoint-membership data
        # is preserved on each logical node as sorted
        # endpoint_keys + sorted derived_edge_ids + sorted
        # source_occurrence_ids.
        collapsed_nodes              = _collapse_nodes_by_id(Array(nodes))
        # Sort nodes + edges by deterministic IDs so the
        # digest is stable.
        @nodes                       = _sort_nodes(collapsed_nodes)
        @edges                       = _sort_edges(edges)
        @adjacency                   = _freeze_adjacency(adjacency)
        @unresolved_topology_issues  = Array(unresolved_topology_issues).map(&:to_s).freeze
        # V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-07:
        # canonical_node_count in the published metrics now
        # reflects the UNIQUE LOGICAL NODE count (not the
        # per-endpoint record count from the builder). This
        # is the metric downstream consumers (V1.8) will
        # read.
        @metrics                     = _finalize_metrics(metrics, collapsed_nodes, edges).freeze
        @non_transitive_clusters     = Array(non_transitive_clusters).freeze
        @open_endpoints              = Array(open_endpoints).map(&:to_s).sort.freeze
        @tolerance_digest            = tolerance_digest.to_s.freeze
        @built_at                    = (built_at || self.class.default_timestamp).to_s.freeze
        @digest                      = _compute_digest
      end

      def ==(other)
        return false unless other.is_a?(CanonicalGeometryGraph)
        digest == other.digest
      end
      alias eql? ==

      def hash
        digest.hash
      end

      # JSON-safe Hash. Recursively stringifies keys.
      def to_h
        {
          'schema_version'              => schema_version,
          'source_snapshot_id'          => source_snapshot_id,
          'execution_config_digest'     => execution_config_digest,
          'workspace_id'                => workspace_id,
          'nodes'                       => nodes.map { |n| _stringify_node(n) },
          'edges'                       => edges.map { |e| _stringify_edge(e) },
          'adjacency'                   => adjacency.each_with_object({}) { |(k, v), h|
                                              h[k.to_s] = Array(v).map(&:to_s).sort
                                            },
          'unresolved_topology_issues'  => unresolved_topology_issues.dup,
          'metrics'                     => metrics.dup,
          'non_transitive_clusters'     => non_transitive_clusters.map { |c| c.to_h },
          'open_endpoints'              => open_endpoints.dup,
          'built_at'                    => built_at,
          'digest'                      => digest,
          'tolerance_digest'            => tolerance_digest
        }.freeze
      end

      def self.default_timestamp
        '1970-01-01T00:00:00Z'
      end

      # Build the canonical graph from the current workspace
      # state. Pure derivation; no host mutation.
      def self.build_from_workspace(workspace:, topology_snapshot:, open_degree_count: nil)
        if workspace.nil?
          return nil
        end
        source_snapshot_id = workspace.source_snapshot.respond_to?(:snapshot_id) ?
                                workspace.source_snapshot.snapshot_id.to_s : ''
        ec = workspace.source_snapshot.respond_to?(:execution_config) ?
                workspace.source_snapshot.execution_config : nil
        exec_digest = ec.respond_to?(:digest) ? ec.digest.to_s : ''
        tolerance_digest = if ec.respond_to?(:tolerance_values)
                             vals = ec.tolerance_values
                             'tol-' + Digest::SHA256.hexdigest(
                               Marshal.dump(vals.is_a?(Hash) ? vals.sort.to_h : {})
                             )[0, 16]
                           else
                             ''
                           end
        # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R3 fix:
        # CanonicalTopologyBuilder.build returns STRING-keyed
        # Hashes (canonical_nodes, canonical_node_clusters,
        # etc.). Read both string + symbol keys defensively so
        # the graph builder works with either input shape
        # (legacy callers passed symbol-keyed Hashes).
        nodes       = Array(topology_snapshot[:canonical_nodes] ||
                             topology_snapshot['canonical_nodes'])
        clusters    = topology_snapshot[:canonical_node_clusters] ||
                       topology_snapshot['canonical_node_clusters'] || {}
        non_trans   = topology_snapshot[:non_transitive_clusters] ||
                      topology_snapshot['non_transitive_clusters'] || []
        unresolved  = Array(topology_snapshot[:unresolved_topology_issues] ||
                             topology_snapshot['unresolved_topology_issues'])
        eps         = (topology_snapshot[:coordinate_epsilon] ||
                       topology_snapshot['coordinate_epsilon'] || 1.0e-6).to_f
        edges       = _build_canonical_edges(workspace, clusters, nodes, eps)
        adjacency   = _build_adjacency(edges)
        open_list   = Array(topology_snapshot[:open_endpoints] ||
                             topology_snapshot['open_endpoints'])
        if open_degree_count.is_a?(Hash)
          open_list = open_degree_count.keys.select { |k| open_degree_count[k].to_i == 1 }
                                       .map(&:to_s).sort
        end
        metric = topology_snapshot[:metrics] ||
                  topology_snapshot['metrics'] || {}
        new(
          source_snapshot_id:        source_snapshot_id,
          execution_config_digest:   exec_digest,
          workspace_id:              workspace.workspace_id.to_s,
          nodes:                     nodes,
          edges:                     edges,
          adjacency:                 adjacency,
          unresolved_topology_issues:unresolved,
          metrics:                   metric,
          non_transitive_clusters:   non_trans,
          open_endpoints:            open_list,
          tolerance_digest:          tolerance_digest
        )
      end

      # ---- internal builders ----

      def self._build_canonical_edges(workspace, clusters, canonical_nodes, eps)
        # Per Blueprint §15.1: each source-derived edge maps
        # to one CanonicalEdge (origin_kind = source_derived /
        # duplicate_repair_survivor). gap_bridge edges added by
        # the executor are appended separately at apply time.
        #
        # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R3:
        # the workspace's DerivedEntityRecord carries the
        # workspace-implementation enum value
        # 'generated_gap_bridge' in `origin_kind`. The
        # canonical graph must NOT leak the workspace enum;
        # CanonicalEdge.origin_kind is the canonical contract
        # enum. We translate at this boundary:
        #   'source_derived'              -> 'source_derived'
        #   'duplicate_repair_survivor'   -> 'duplicate_repair_survivor'
        #   'generated_gap_bridge'        -> 'gap_bridge'   (R3 fix)
        # V1.8 downstream must consume 'gap_bridge' without
        # ever learning the workspace enum.
        #
        # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R3
        # secondary fix: for bridge edges (gap_bridge origin),
        # the bridge's endpoint keys (der-gap-X.start /
        # der-gap-X.end) are NOT in cluster_id_for (the
        # cluster map is keyed by the topology snapshot's
        # endpoint_keys, not by the bridge's derived_edge_id).
        # We resolve bridge-endpoint canonical_node_ids via
        # world-coordinate proximity against the topology
        # snapshot's canonical_nodes (within `eps`). This
        # connects the bridge into the existing canonical
        # graph instead of inventing fresh singleton nodes.
        out = []
        return out unless workspace.respond_to?(:entities)
        cluster_id_for = {}
        # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R3
        # secondary fix: map endpoint_key -> canonical_node_id
        # (NOT cluster id) so source_derived edges + bridge
        # edges resolve to the SAME identifier format. The
        # cluster_id (without .nN suffix) is a group
        # identifier; the canonical_node_id (with .nN suffix)
        # is the unique node identifier. For singleton
        # clusters, the canonical_node_id == cluster_id +
        # '.n0'.
        Array(canonical_nodes).each do |n|
          next unless n.is_a?(Hash)
          ek = n['endpoint_key']
          cnid = n['canonical_node_id']
          next unless ek && cnid
          cluster_id_for[ek.to_s] = cnid.to_s
        end
        # Build a coordinate-indexed lookup of canonical
        # nodes for bridge-endpoint resolution.
        canonical_nodes_by_world = {}
        # Defensive: the bucket eps must be a positive finite
        # number; fall back to 1e-6 if not.
        buck_eps = eps.to_f
        buck_eps = 1.0e-6 unless buck_eps.finite? && buck_eps > 0
        Array(canonical_nodes).each do |n|
          next unless n.is_a?(Hash)
          cid = n['canonical_node_id']
          w   = n['world_coordinate']
          next unless cid && w.is_a?(Array) && w.length == 3
          # Bucket by integer cell of coord_epsilon so the
          # bridge-endpoint lookup stays O(1) expected.
          cell = [
            (w[0] / buck_eps).floor,
            (w[1] / buck_eps).floor,
            (w[2] / buck_eps).floor
          ]
          canonical_nodes_by_world[cell] ||= []
          canonical_nodes_by_world[cell] << [cid, w]
        end
        workspace.entities.each do |rec|
          next unless rec.respond_to?(:kind) && rec.kind == :edge
          did = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
          next if did.empty?
          gs = rec.respond_to?(:geometry_summary) ? rec.geometry_summary : {}
          s = gs.is_a?(Hash) ? gs['start'] : nil
          e = gs.is_a?(Hash) ? gs['end']   : nil
          next unless s.is_a?(Array) && s.length == 3 && e.is_a?(Array) && e.length == 3
          ak = "#{did}.start"
          bk = "#{did}.end"
          aid = cluster_id_for[ak]
          bid = cluster_id_for[bk]
          # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R3
          # secondary fix: source_derived edges use the
          # convention "#{did}.start" / "#{did}.end" for
          # their endpoint keys; the topology snapshot may
          # carry the canonical endpoint_keys with different
          # names (e.g. 'der-edge-1.end'). When the
          # convention-derived key isn't in cluster_id_for,
          # resolve by world-coordinate proximity against
          # the topology snapshot's canonical_nodes (same
          # logic as bridge-endpoint resolution above). This
          # connects source_derived edges into the same
          # canonical graph as the bridge edge so cycle /
          # BFS assertions work end-to-end.
          aid ||= _resolve_bridge_node(
            cluster_id_for, canonical_nodes_by_world,
            ak, s, eps
          )
          bid ||= _resolve_bridge_node(
            cluster_id_for, canonical_nodes_by_world,
            bk, e, eps
          )
          aid ||= "#{ak}.singleton"
          bid ||= "#{bk}.singleton"
          # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R3
          # secondary fix: DerivedEntityRecord carries
          # origin_kind inside geometry_summary (it does NOT
          # expose a `rec.origin_kind` accessor). Read from
          # geometry_summary so the canonical translation
          # actually sees the workspace enum.
          workspace_origin = if gs.is_a?(Hash) && gs['origin_kind']
                               gs['origin_kind'].to_s
                             else
                               ORIGIN_SOURCE_DERIVED
                             end
          origin_kind = _canonicalize_origin_kind(workspace_origin)
          # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R3
          # secondary fix (companion to the origin_kind fix):
          # repair_action_id is also carried inside
          # geometry_summary (no DerivedEntityRecord accessor);
          # read it from there so the canonical graph carries
          # the bridge provenance correctly.
          repair_action_id = if gs.is_a?(Hash) && gs['repair_action_id']
                               gs['repair_action_id'].to_s
                             elsif rec.respond_to?(:repair_action_id)
                               rec.repair_action_id.to_s
                             else
                               nil
                             end
          # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R3
          # bridge-endpoint resolution: if this edge is a
          # gap_bridge and its endpoint keys weren't found
          # in cluster_id_for, look them up by world
          # coordinate proximity against the topology snapshot's
          # canonical_nodes (so the bridge connects into the
          # existing canonical graph, not into fresh singleton
          # nodes).
          if origin_kind == ORIGIN_GENERATED_GAP_BRIDGE
            resolved_a = _resolve_bridge_node(
              cluster_id_for, canonical_nodes_by_world,
              ak, s, eps
            )
            resolved_b = _resolve_bridge_node(
              cluster_id_for, canonical_nodes_by_world,
              bk, e, eps
            )
            aid = resolved_a if resolved_a
            bid = resolved_b if resolved_b
          end
          out << {
            'canonical_edge_id'  => "ce-#{did}",
            'node_a_id'          => aid,
            'node_b_id'          => bid,
            'origin_kind'        => origin_kind,
            'derived_edge_id'    => did,
            'source_occurrence_id' => (rec.respond_to?(:source_occurrence_ids) ?
                                          Array(rec.source_occurrence_ids).first : nil),
            # V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-06:
            # PLURAL source_occurrence_ids provenance. For a
            # gap_bridge, this contains the COMPLETE support
            # union from both incident sides (the workspace
            # record already carries both incident source
            # occurrence IDs in `source_occurrence_ids`). The
            # singular `source_occurrence_id` is kept for
            # backwards compatibility with existing consumers;
            # V1.8 authority is the plural field.
            'source_occurrence_ids' => _normalize_occurrence_ids(
              rec.respond_to?(:source_occurrence_ids) ? rec.source_occurrence_ids : nil
            ),
            'repair_action_id'   => repair_action_id,
            'world_endpoints'    => [[s[0], s[1], s[2]], [e[0], e[1], e[2]]],
            'layer_name'         => (gs['layer'] if gs.is_a?(Hash)) || nil,
            'unresolved_flags'   => []
          }
        end
        out
      end

      # Translate a workspace-implementation `origin_kind` to
      # the canonical contract enum (Blueprint §15.1).
      # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R3:
      # canonical downstream (V1.8, etc.) MUST consume only
      # the canonical enum; the workspace enum
      # 'generated_gap_bridge' must not leak through
      # CanonicalGeometryGraph. Unknown workspace values are
      # preserved verbatim so the downstream layer can still
      # surface the truth without silently aliasing an
      # unknown value.
      def self._canonicalize_origin_kind(workspace_origin)
        case workspace_origin.to_s
        when ORIGIN_SOURCE_DERIVED            then ORIGIN_SOURCE_DERIVED
        when ORIGIN_DUPLICATE_REPAIR_SURVIVOR then ORIGIN_DUPLICATE_REPAIR_SURVIVOR
        when 'generated_gap_bridge'           then ORIGIN_GENERATED_GAP_BRIDGE
        else
          workspace_origin.to_s
        end
      end

      # V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-06:
      # normalize source occurrence IDs to a deterministic
      # sorted/uniq String Array for the plural
      # `source_occurrence_ids` field. Nil / empty inputs
      # yield an empty Array (no nil entries leak downstream).
      def self._normalize_occurrence_ids(values)
        Array(values).map { |v| v.nil? ? '' : v.to_s }.reject { |s| s.empty? }.uniq.sort.freeze
      end

      # Resolve a bridge-edge endpoint to its canonical node id.
      # Returns the existing cluster_id_for entry if found;
      # otherwise scans canonical_nodes_by_world for a node
      # within `eps` of the bridge endpoint's world
      # coordinate. Returns nil if no match (the bridge then
      # keeps its singleton node fallback).
      def self._resolve_bridge_node(cluster_id_for, canonical_nodes_by_world,
                                   endpoint_key, world_coord, eps)
        existing = cluster_id_for[endpoint_key]
        return existing if existing
        return nil unless world_coord.is_a?(Array) && world_coord.length == 3
        # Defensive: eps must be a positive finite number.
        lookup_eps = eps.to_f
        lookup_eps = 1.0e-6 unless lookup_eps.finite? && lookup_eps > 0
        # V17-AIPM-PRIMARY-REVIEW-CORRECTION-2026-09-01 R3
        # bridge-endpoint resolution: do a linear scan through
        # ALL canonical_nodes_by_world entries (typical
        # canonical-node counts are small — the bucket-grid
        # ±1 range fails for sparse / long-thin topologies).
        # For each candidate, accept iff within `lookup_eps`
        # (canonical-equivalence rule).
        best = nil
        best_d = nil
        canonical_nodes_by_world.each do |_cell, candidates|
          candidates.each do |cid, w|
            d = _coord_distance(world_coord, w)
            if (best_d.nil? || d < best_d) && d <= lookup_eps
              best_d = d
              best = cid
            end
          end
        end
        return best if best
        nil
      end

      def self._coord_distance(a, b)
        dx = a[0] - b[0]
        dy = a[1] - b[1]
        dz = a[2] - b[2]
        Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
      end

      def self._build_adjacency(edges)
        adj = Hash.new { |h, k| h[k] = [] }
        edges.each do |e|
          adj[e['node_a_id']] << e['node_b_id']
          adj[e['node_b_id']] << e['node_a_id']
        end
        adj.each_value { |v| v.uniq!; v.sort! }
        adj
      end

      # ---- instance helpers ----

      # V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-07 +
      # V17-AIPM-DIRECT-SOURCE-REREVIEW-2026-09-01 RR-05:
      # collapse per-endpoint canonical_node records into ONE
      # LOGICAL NODE per canonical_node_id. The internal
      # endpoint-membership data is preserved on the logical
      # node as sorted endpoint_keys + sorted derived_edge_ids
      # + sorted source_occurrence_ids.
      #
      # RR-05 ORDER-INDEPENDENCE: members are stored as LINKED
      # MEMBER RECORDS (NOT separate parallel arrays). We sort
      # the linked members by endpoint_key, then pick the
      # ACTUAL world_coordinate of the lex-smallest member.
      # Forward / reversed / shuffled input order all yield
      # the same node payload, representative coordinate, and
      # graph digest.
      def _collapse_nodes_by_id(nodes)
        grouped = {}
        Array(nodes).each do |n|
          h = n.is_a?(Hash) ? n : (n.respond_to?(:to_h) ? n.to_h : {})
          cid = h['canonical_node_id'].to_s
          next if cid.empty?
          grouped[cid] ||= {
            'canonical_node_id'    => cid,
            'members'              => [],   # linked records
            'resolved_clique'      => h['resolved_clique'],
            'coordinate_epsilon'   => h['coordinate_epsilon']
          }
          wc = h['world_coordinate']
          # Store a LINKED member record (one Hash per input
          # member) keyed by endpoint_key. The representative
          # world_coordinate is the ACTUAL member coord of
          # the lex-smallest endpoint_key; we never zip
          # separately-tracked arrays.
          member = {
            'endpoint_key'         => h['endpoint_key'].to_s,
            'derived_edge_id'      => h['derived_edge_id'].to_s,
            'source_occurrence_id' => (
              sid = h['source_occurrence_id']
              sid && !sid.to_s.empty? ? sid.to_s : nil
            ),
            'layer_name'           => (
              ln = h['layer_name']
              ln && !ln.to_s.empty? ? ln.to_s : nil
            ),
            'world_coordinate'     => wc.is_a?(Array) ? wc.dup : nil
          }
          grouped[cid]['members'] << member
        end
        # Build the final logical node records.
        logical = grouped.values.map do |g|
          # RR-05: sort the LINKED members by endpoint_key;
          # every aggregate field is derived from these
          # same linked records. Forward / reversed /
          # shuffled input orders all yield the same
          # sorted members sequence because the comparator
          # is stable on the canonical key.
          sorted_members = g['members'].sort_by { |m| m['endpoint_key'].to_s }
          sorted_eks     = sorted_members.map { |m| m['endpoint_key'] }.uniq
          sorted_dids    = sorted_members.map { |m| m['derived_edge_id'] }.uniq.sort
          sorted_sids    = sorted_members.map { |m| m['source_occurrence_id'] }.compact.uniq.sort
          sorted_layers  = sorted_members.map { |m| m['layer_name'] }.compact.uniq.sort
          # RR-05 representative world_coordinate: ACTUAL
          # coordinate of the lex-smallest endpoint_key
          # member. NEVER averaged or zip-mixed.
          rep_wc = sorted_members.first ? sorted_members.first['world_coordinate'] : nil
          {
            'canonical_node_id'      => g['canonical_node_id'],
            'endpoint_keys'          => sorted_eks,
            'derived_edge_ids'       => sorted_dids,
            'source_occurrence_ids'  => sorted_sids,
            'layer_names'            => sorted_layers,
            'world_coordinate'       => (rep_wc.is_a?(Array) ? rep_wc.dup : nil),
            'resolved_clique'        => g['resolved_clique'],
            'coordinate_epsilon'     => g['coordinate_epsilon'],
            'membership_count'       => sorted_eks.length
          }.freeze
        end
        logical
      end

      def _sort_nodes(nodes)
        Array(nodes).map { |n|
          n.is_a?(Hash) ? n : (n.respond_to?(:to_h) ? n.to_h : {})
        }.sort_by { |n| n['canonical_node_id'].to_s }
      end

      # V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-07:
      # finalize the published metrics. Preserve caller-supplied
      # values, but overwrite `canonical_node_count` with the
      # UNIQUE LOGICAL NODE count from the collapsed nodes
      # (NOT the per-endpoint record count from the builder).
      # Also add `canonical_edge_count` for downstream
      # convenience (consumers should not need to count
      # edges.length themselves).
      def _finalize_metrics(supplied_metrics, collapsed_nodes, edges)
        merged = {}
        (supplied_metrics || {}).each { |k, v| merged[k.to_s] = v }
        merged['canonical_node_count'] = collapsed_nodes.length
        merged['canonical_edge_count'] = Array(edges).length
        merged
      end

      def _sort_edges(edges)
        Array(edges).sort_by { |e| e['canonical_edge_id'].to_s }
      end

      def _freeze_adjacency(adj)
        h = {}
        Array(adj).each do |k, v|
          h[k.to_s] = Array(v).map(&:to_s).sort.freeze
        end
        h.freeze
      end

      def _stringify_node(n)
        n.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
      end

      def _stringify_edge(e)
        e.each_with_object({}) { |(k, v), h|
          h[k.to_s] = v.is_a?(Hash) ? v.each_with_object({}) { |(kk, vv), hh| hh[kk.to_s] = vv } : v
        }
      end

      def _compute_digest
        # Deterministic content hash. Stable for an unchanged
        # canonical derivation. After SR-07 the `nodes`
        # collection is a per-canonical_node_id logical
        # representation (each entry carries endpoint_keys +
        # membership_count + a representative world_coordinate).
        canonical_lines = []
        nodes.each do |n|
          wc = n['world_coordinate']
          coord_str = if wc.is_a?(Array) && wc.length == 3
                        sprintf('%.10f|%.10f|%.10f', wc[0], wc[1], wc[2])
                      else
                        'none'
                      end
          canonical_lines << "N|#{n['canonical_node_id']}|#{n['resolved_clique'] ? 1 : 0}|#{Array(n['endpoint_keys']).join(',')}|#{n['membership_count']}|#{coord_str}"
        end
        edges.each { |e| canonical_lines << "E|#{e['canonical_edge_id']}|#{e['origin_kind']}|#{e['node_a_id']}|#{e['node_b_id']}|#{e['derived_edge_id']}|#{e['repair_action_id']}|#{Array(e['source_occurrence_ids']).join(',')}" }
        adj_lines = adjacency.sort.map { |k, vs| "A|#{k}|#{vs.join(',')}" }
        unresolved_lines = unresolved_topology_issues.sort.map { |x| "U|#{x}" }
        cl_lines = Array(non_transitive_clusters).map { |c| "C|#{c['cluster_id']}|#{Array(c['endpoint_keys']).join('|')}" }
        metric_lines = (metrics || {}).sort.map { |k, v| "M|#{k}|#{v}" }
        adj_section = adj_lines.empty? ? '' : (adj_lines.join("\n") + "\n")
        n_section = canonical_lines.empty? ? '' : (canonical_lines.join("\n") + "\n")
        u_section = unresolved_lines.empty? ? '' : (unresolved_lines.join("\n") + "\n")
        c_section = cl_lines.empty? ? '' : (cl_lines.join("\n") + "\n")
        m_section = metric_lines.join("\n")
        body = ([
          schema_version,
          source_snapshot_id,
          execution_config_digest,
          workspace_id,
          tolerance_digest,
          built_at
        ].join("\n") + "\n" + n_section + adj_section + u_section + c_section + m_section)
        Digest::SHA256.hexdigest(body)
      end
    end
  end
end
