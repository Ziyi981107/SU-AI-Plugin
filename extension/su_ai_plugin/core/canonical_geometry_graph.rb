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
        # Sort nodes + edges by deterministic IDs so the
        # digest is stable.
        @nodes                       = _sort_nodes(nodes)
        @edges                       = _sort_edges(edges)
        @adjacency                   = _freeze_adjacency(adjacency)
        @unresolved_topology_issues  = Array(unresolved_topology_issues).map(&:to_s).freeze
        @metrics                     = (metrics || {}).each_with_object({}) { |(k, v), h| h[k.to_s] = v }.freeze
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
        nodes       = Array(topology_snapshot[:canonical_nodes])
        clusters    = topology_snapshot[:canonical_node_clusters] || {}
        non_trans   = topology_snapshot[:non_transitive_clusters] || []
        unresolved  = Array(topology_snapshot[:unresolved_topology_issues])
        eps         = topology_snapshot[:coordinate_epsilon].to_f
        edges       = _build_canonical_edges(workspace, clusters, eps)
        adjacency   = _build_adjacency(edges)
        open_list   = Array(topology_snapshot[:open_endpoints])
        if open_degree_count.is_a?(Hash)
          open_list = open_degree_count.keys.select { |k| open_degree_count[k].to_i == 1 }
                                       .map(&:to_s).sort
        end
        metric = topology_snapshot[:metrics] || {}
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

      def self._build_canonical_edges(workspace, clusters, eps)
        # Per Blueprint §15.1: each source-derived edge maps
        # to one CanonicalEdge (origin_kind = source_derived /
        # duplicate_repair_survivor). gap_bridge edges added by
        # the executor are appended separately at apply time.
        out = []
        return out unless workspace.respond_to?(:entities)
        cluster_id_for = {}
        clusters.each do |cid, keys|
          Array(keys).each { |k| cluster_id_for[k.to_s] = cid.to_s }
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
          aid = cluster_id_for[ak] || "#{ak}.singleton"
          bid = cluster_id_for[bk] || "#{bk}.singleton"
          origin_kind = if rec.respond_to?(:respond_to?) && rec.respond_to?(:origin_kind)
                          rec.origin_kind.to_s
                        else
                          ORIGIN_SOURCE_DERIVED
                        end
          repair_action_id = rec.respond_to?(:repair_action_id) ? rec.repair_action_id.to_s : nil
          out << {
            'canonical_edge_id'  => "ce-#{did}",
            'node_a_id'          => aid,
            'node_b_id'          => bid,
            'origin_kind'        => origin_kind,
            'derived_edge_id'    => did,
            'source_occurrence_id' => (rec.respond_to?(:source_occurrence_ids) ?
                                          Array(rec.source_occurrence_ids).first : nil),
            'repair_action_id'   => repair_action_id,
            'world_endpoints'    => [[s[0], s[1], s[2]], [e[0], e[1], e[2]]],
            'layer_name'         => (gs['layer'] if gs.is_a?(Hash)) || nil,
            'unresolved_flags'   => []
          }
        end
        out
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

      def _sort_nodes(nodes)
        Array(nodes).map { |n|
          n.is_a?(Hash) ? n : (n.respond_to?(:to_h) ? n.to_h : {})
        }.sort_by { |n| n['canonical_node_id'].to_s }
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
        # canonical derivation.
        canonical_lines = []
        nodes.each { |n| canonical_lines << "N|#{n['canonical_node_id']}|#{n['resolved_clique'] ? 1 : 0}|#{n['endpoint_key']}|" +
                                          sprintf('%.10f|%.10f|%.10f', n['world_coordinate'][0], n['world_coordinate'][1], n['world_coordinate'][2]) }
        edges.each { |e| canonical_lines << "E|#{e['canonical_edge_id']}|#{e['origin_kind']}|#{e['node_a_id']}|#{e['node_b_id']}|#{e['derived_edge_id']}|#{e['repair_action_id']}" }
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
