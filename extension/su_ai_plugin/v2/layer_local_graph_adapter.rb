#
# v2/layer_local_graph_adapter.rb — V2-0A Pure-Data
# Layer-Local Graph Adapter.
#
# Per frozen V2-0A Stage Technical Blueprint
# (Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0A_SEMANTIC_FOOTPRINT_2026-09-16.md)
# §3.1 + §10:
#
#   Consume ONLY the published PreparedCadDataset semantic_graph.
#   Filter by EXACT mapped `layer_name` match (no implicit /
#   empty / unknown matching).
#   Retain only nodes referenced by the FILTERED EDGES.
#   Rebuild layer-local adjacency from the filtered edges
#   themselves -- never trust the published global adjacency
#   after filtering.
#   Preserve edge multiplicity (no parallel-edge dedup).
#   Adapt PCD semantic IDs into the field names expected by
#   `CanonicalStructureReconstructor` without inventing new
#   geometry.
#   Preserve source edge provenance needed downstream.
#
# Pure value object. No host mutation, no observer, no SketchUp
# API calls, no shared-kernel modification. V1.8
# CanonicalStructureReconstructor is the downstream geometry
# authority (Blueprint §8).
#
# Files:
#   extension/su_ai_plugin/v2/layer_local_graph_adapter.rb
#   extension/su_ai_plugin/v2/semantic_footprint.rb
#   extension/su_ai_plugin/v2/semantic_footprint_projector.rb
#   tests/test_v2_stage0a_semantic_footprint.rb
#

require 'digest'
require 'set'

module SUAnalysis
  module V2
    # Adapter contract: read-only projection of one exact
    # mapped CAD layer from a validated PreparedCadDataset
    # into the canonical-graph shape required by
    # CanonicalStructureReconstructor.
    #
    # Returns:
    #   { 'status'  => 'PROJECTED' | 'BLOCKED',
    #     'graph'   => <frozen canonical-shape Hash> | nil,
    #     'reasons' => <frozen Array<String>> }
    #
    # Frozen module: no instance state.
    module LayerLocalGraphAdapter
      module_function

      # Stable schema for the projected canonical-shape graph
      # returned to the projector. Matches the V1.8
      # CanonicalStructureReconstructor input contract.
      SCHEMA_VERSION = 'cgg.v1'.freeze

      # Stable blocker reason codes (Blueprint §6).
      REASON_NOT_A_PCD              = 'v2_llga:not_a_prepared_cad_dataset'.freeze
      REASON_NOT_FINALIZED          = 'v2_llga:pcd_not_finalized'.freeze
      REASON_NOT_READY              = 'v2_llga:pcd_not_ready'.freeze
      REASON_PCD_SCHEMA_MISMATCH    = 'v2_llga:pcd_schema_mismatch'.freeze
      REASON_MISSING_SEMANTIC_GRAPH = 'v2_llga:missing_semantic_graph'.freeze
      REASON_MALFORMED_GRAPH        = 'v2_llga:malformed_semantic_graph'.freeze
      REASON_INVALID_LAYER_NAME     = 'v2_llga:invalid_layer_name'.freeze
      REASON_EMPTY_MAPPED_LAYER     = 'v2_llga:empty_mapped_layer'.freeze
      REASON_UNKNOWN_MAPPED_LAYER   = 'v2_llga:unknown_mapped_layer'.freeze
      REASON_MALFORMED_NODE         = 'v2_llga:malformed_node'.freeze
      REASON_MALFORMED_EDGE         = 'v2_llga:malformed_edge'.freeze
      REASON_UNRESOLVED_EDGE_REF    = 'v2_llga:unresolved_edge_reference'.freeze

      # PCD content schema_version expected by V2 Stage-0A.
      # MUST equal the real PreparedCadDatasetBuilder publisher
      # (V1.9B1 R1 SOURCE_REVIEW_R1_CORRECTION §1).
      EXPECTED_CONTENT_SCHEMA = 'pcd.v1'.freeze
      # The semantic_graph child schema MUST equal the real
      # PreparedCadDatasetBuilder publisher.
      EXPECTED_GRAPH_SCHEMA   = 'pcd-semantic-graph.v1'.freeze

      # Project one exact mapped layer from a validated PCD
      # into the canonical-shape graph expected by
      # CanonicalStructureReconstructor.
      #
      #   dataset:    a `PreparedCadDataset` (final only);
      #   layer_name: non-empty mapped CAD layer String.
      #
      # The returned Hash shape matches the V1.8
      # `CanonicalStructureReconstructor.reconstruct` JSON-safe
      # input shape:
      #
      #   {
      #     'schema_version'             => 'cgg.v1',
      #     'source_snapshot_id'         => dataset.source_snapshot_id,
      #     'workspace_id'               => dataset.dataset_id,
      #     'nodes'                      => <sorted Array<Hash>>,
      #     'edges'                      => <sorted Array<Hash>>,
      #     'adjacency'                  => {<node_id> => <sorted Array<...>>},
      #     'unresolved_topology_issues' => [],
      #     'metrics'                    => {},
      #     'non_transitive_clusters'    => [],
      #     'open_endpoints'             => [],
      #     'tolerance_digest'           => 'v2-llga-v1',
      #     'digest'                     => <sha256>
      #   }
      #
      # Edge multiplicity IS preserved: two distinct edges
      # between the same node pair produce two separate
      # canonical_edge_id entries (one per source semantic
      # edge_id). The V1.8 reconstructor detects parallel edges
      # via `pair_to_edges` and routes the component to
      # `:parallel_edges` -> REJECT. V2-0A therefore cannot
      # silently merge parallel same-layer edges.
      #
      # The source input dataset MUST NOT be mutated. We
      # consult the published `content['semantic_graph']` (the
      # canonical graph stored in the PCD) and emit a fresh
      # frozen graph Hash.
      def project(dataset:, layer_name:)
        reasons = []
        pcd_graph, pcd_blockers = _extract_pcd_graph(dataset)
        reasons.concat(pcd_blockers)
        if pcd_graph.nil?
          return _blocked(reasons.uniq)
        end
        # Validate layer_name (Blueprint §3.1: non-empty String).
        unless layer_name.is_a?(String)
          reasons << REASON_INVALID_LAYER_NAME
          return _blocked(reasons.uniq)
        end
        layer_str = layer_name.dup
        unless layer_str.encoding.name == 'UTF-8' && layer_str.valid_encoding?
          reasons << REASON_INVALID_LAYER_NAME
          return _blocked(reasons.uniq)
        end
        if layer_str.strip.empty?
          reasons << REASON_EMPTY_MAPPED_LAYER
          return _blocked(reasons.uniq)
        end
        # Mapped layer must appear in the PCD layer inventory
        # of the semantic_graph nodes' `layer_names` (Blueprint
        # §3.1 §5: exact mapped CAD layer matching).
        pcd_nodes = Array(pcd_graph['nodes'])
        pcd_edges = Array(pcd_graph['edges'])
        known_layers = _collect_known_layers(pcd_nodes, pcd_edges)
        if !known_layers.include?(layer_str)
          reasons << REASON_UNKNOWN_MAPPED_LAYER
          return _blocked(reasons.uniq)
        end
        # Filter EDGES by EXACT `layer_name == layer_str`
        # (Blueprint §3.1 §4). No implicit / empty /
        # unknown matching.
        filtered_edges = []
        malformed_edge = false
        pcd_edges.each do |e|
          unless e.is_a?(Hash)
            malformed_edge = true
            break
          end
          e_layer = e['layer_name']
          unless e_layer.is_a?(String) && e_layer.encoding.name == 'UTF-8' &&
                 e_layer.valid_encoding?
            malformed_edge = true
            break
          end
          next unless e_layer == layer_str
          filtered_edges << e
        end
        if malformed_edge
          reasons << REASON_MALFORMED_EDGE
          return _blocked(reasons.uniq)
        end
        if filtered_edges.empty?
          # R1-05 (V2-0A SOURCE_REVIEW_R1_CORRECTION §5):
          # a KNOWN mapped layer (already validated by
          # `known_layers.include?(layer_str)` above) that
          # contributes zero matching edges is a SUCCESSFUL
          # empty projection -- the projector maps this to
          # its EMPTY status. The adapter MUST NOT label this
          # case as UNKNOWN_MAPPED_LAYER (the layer was
          # explicitly known). Return a frozen empty graph so
          # the projector can distinguish this from BLOCKED.
          empty_graph = {
            'schema_version'             => SCHEMA_VERSION,
            'source_snapshot_id'         => (dataset.respond_to?(:content) ?
                                              _read_pcd_source_id(dataset) : ''),
            'workspace_id'               => (dataset.respond_to?(:dataset_id) ?
                                              dataset.dataset_id.to_s : ''),
            'source_dataset_id'          => (dataset.respond_to?(:dataset_id) ?
                                              dataset.dataset_id.to_s : ''),
            'source_content_digest'      => (dataset.respond_to?(:content_digest) ?
                                              dataset.content_digest.to_s : ''),
            'source_layer_name'          => layer_str.dup,
            'nodes'                      => [].freeze,
            'edges'                      => [].freeze,
            'adjacency'                  => {}.freeze,
            'unresolved_topology_issues' => [].freeze,
            'metrics'                    => {},
            'non_transitive_clusters'    => [].freeze,
            'open_endpoints'             => [].freeze,
            'tolerance_digest'           => 'v2-llga-v1'.freeze,
            'digest'                     => Digest::SHA256.hexdigest(
              "v2-llga-empty|#{layer_str}|#{dataset.respond_to?(:dataset_id) ? dataset.dataset_id.to_s : ''}"
            )
          }
          deep_freeze(empty_graph)
          return {
            'status'  => 'PROJECTED',
            'graph'   => empty_graph,
            'reasons' => [].freeze,
            'empty'   => true
          }
        end
        # Build the set of canonical-node IDs referenced by the
        # FILTERED edges. Other nodes are dropped.
        referenced_nodes = {}
        filtered_edges.each do |e|
          a = e['node_a_id']
          b = e['node_b_id']
          referenced_nodes[a.to_s] = true if a.is_a?(String) && !a.empty?
          referenced_nodes[b.to_s] = true if b.is_a?(String) && !b.empty?
        end
        # Build the filtered node inventory (preserving every
        # PCD node record by node_id) but only keep the ones
        # referenced by filtered edges.
        pcd_nodes_by_id = {}
        malformed_node = false
        pcd_nodes.each do |n|
          unless n.is_a?(Hash)
            malformed_node = true
            break
          end
          nid = n['node_id']
          unless nid.is_a?(String) && !nid.empty?
            malformed_node = true
            break
          end
          pcd_nodes_by_id[nid] = n
        end
        if malformed_node
          reasons << REASON_MALFORMED_NODE
          return _blocked(reasons.uniq)
        end
        filtered_nodes = []
        referenced_nodes.keys.sort.each do |nid|
          unless pcd_nodes_by_id.key?(nid)
            reasons << REASON_UNRESOLVED_EDGE_REF + ":node=#{nid}"
            return _blocked(reasons.uniq)
          end
          filtered_nodes << pcd_nodes_by_id[nid]
        end
        # Rebuild adjacency from the FILTERED edge records
        # themselves (Blueprint §3.1 §7, §3.1 §11). Published
        # PCD adjacency is NOT trusted after filtering -- the
        # global adjacency may carry edges whose other endpoint
        # is outside this layer.
        adj = Hash.new { |h, k| h[k] = Set.new }
        projected_edge_records = []
        malformed_proj = false
        sorted_filtered_edges = filtered_edges.sort_by { |e|
          e['edge_id'].to_s
        }
        sorted_filtered_edges.each_with_index do |e, idx|
          a = e['node_a_id'].to_s
          b = e['node_b_id'].to_s
          if a.empty? || b.empty?
            malformed_proj = true
            break
          end
          if !pcd_nodes_by_id.key?(a) || !pcd_nodes_by_id.key?(b)
            reasons << REASON_UNRESOLVED_EDGE_REF + ":edge=#{e['edge_id']}"
            return _blocked(reasons.uniq)
          end
          adj[a].add(b)
          adj[b].add(a)
          projected_edge_records << _project_edge(e, a, b, pcd_nodes_by_id, idx)
        end
        if malformed_proj
          reasons << REASON_MALFORMED_EDGE
          return _blocked(reasons.uniq)
        end
        # Convert adjacency into a sorted/uniq String Array per
        # key. Frozen Hash.
        projected_adjacency = {}
        adj.each { |k, nbrs| projected_adjacency[k.to_s] = nbrs.to_a.sort }
        # Adapt nodes into the canonical-shape Hash expected by
        # the V1.8 reconstructor.
        projected_nodes = filtered_nodes.sort_by { |n|
          n['node_id'].to_s
        }.map { |n| _project_node(n) }
        # Deterministic graph digest: the V1.8 reconstructor
        # uses `graph.digest` only as a stale-cache sentinel;
        # the layer-local graph MUST have a stable distinct
        # digest across reorders. SHA-256 over a canonical
        # text encoding of nodes + edges + adjacency.
        digest = _compute_layer_graph_digest(
          projected_nodes, projected_edge_records, projected_adjacency
        )
        # All checks succeeded -> PROJECTED.
        result = {
          'schema_version'             => SCHEMA_VERSION,
          'source_snapshot_id'         => (dataset.respond_to?(:content) ?
                                            _read_pcd_source_id(dataset) : ''),
          'workspace_id'               => (dataset.respond_to?(:dataset_id) ?
                                            dataset.dataset_id.to_s : ''),
          'source_dataset_id'          => (dataset.respond_to?(:dataset_id) ?
                                            dataset.dataset_id.to_s : ''),
          'source_content_digest'      => (dataset.respond_to?(:content_digest) ?
                                            dataset.content_digest.to_s : ''),
          'source_layer_name'          => layer_str.dup,
          'nodes'                      => projected_nodes.freeze,
          'edges'                      => projected_edge_records.freeze,
          'adjacency'                  => _stringify_adjacency(projected_adjacency),
          'unresolved_topology_issues' => [].freeze,
          'metrics'                    => {},
          'non_transitive_clusters'    => [].freeze,
          'open_endpoints'             => [].freeze,
          'tolerance_digest'           => 'v2-llga-v1'.freeze,
          'digest'                     => digest
        }
        # Deep-freeze: required so the reconstructor cannot
        # accidentally mutate the published PCD data via this
        # adapter seam.
        deep_freeze(result)
        { 'status' => 'PROJECTED', 'graph' => result, 'reasons' => [].freeze }
      end

      # ---- internals ----

      # Extract the published PCD semantic_graph Hash.
      # Returns [graph_hash_or_nil, blockers]. graph_hash is a
      # defensive deep-frozen read-only snapshot of the PCD
      # semantic_graph (the PCD itself is immutable per B1.2).
      def _extract_pcd_graph(dataset)
        blockers = []
        unless dataset.is_a?(SUAnalysis::Core::PreparedCadDataset)
          blockers << REASON_NOT_A_PCD
          return [nil, blockers]
        end
        # Blueprint §1: V2 may consume only the FINAL PCD
        # (`validated` is attached). Candidates are not yet
        # validated and cannot be trusted.
        unless dataset.final?
          blockers << REASON_NOT_FINALIZED
          return [nil, blockers]
        end
        # R1-02 (V2-0A SOURCE_REVIEW_R1_CORRECTION §2):
        # a finalized PCD is V2-usable only when the
        # attached validation Hash is itself READY: blockers
        # Array is empty AND persistence_check.status ==
        # 'PASS'. Warnings are allowed. The candidate's
        # `final?` (validation != nil) is NOT sufficient
        # because a NOT_READY Validator result can still
        # carry a final dataset.
        validation = dataset.respond_to?(:validation) ?
                       dataset.validation : nil
        unless validation.is_a?(Hash)
          blockers << REASON_NOT_READY + ':validation_missing'
          return [nil, blockers]
        end
        v_blockers = validation['blockers']
        unless v_blockers.is_a?(Array) && v_blockers.empty?
          blockers << REASON_NOT_READY + ':blockers_non_empty'
          return [nil, blockers]
        end
        persistence_check = validation['persistence_check']
        unless persistence_check.is_a?(Hash)
          blockers << REASON_NOT_READY + ':persistence_check_missing'
          return [nil, blockers]
        end
        p_status = persistence_check['status']
        unless p_status.is_a?(String) && p_status == 'PASS'
          blockers << REASON_NOT_READY + ":persistence_check=#{p_status.inspect}"
          return [nil, blockers]
        end
        content = dataset.content
        unless content.is_a?(Hash)
          blockers << REASON_MISSING_SEMANTIC_GRAPH
          return [nil, blockers]
        end
        content_schema = content['schema_version'].to_s
        unless content_schema == EXPECTED_CONTENT_SCHEMA
          blockers << REASON_PCD_SCHEMA_MISMATCH +
                          ":got=#{content_schema.inspect}"
          return [nil, blockers]
        end
        graph = content['semantic_graph']
        unless graph.is_a?(Hash)
          blockers << REASON_MISSING_SEMANTIC_GRAPH
          return [nil, blockers]
        end
        graph_schema = graph['schema_version'].to_s
        unless graph_schema == EXPECTED_GRAPH_SCHEMA
          blockers << REASON_MALFORMED_GRAPH +
                          ":schema=#{graph_schema.inspect}"
          return [nil, blockers]
        end
        [graph, blockers]
      end

      def _read_pcd_source_id(dataset)
        # PCD does not currently carry a source_snapshot_id
        # directly; carry it through build_evidence for future
        # use, but report '' here to keep the adapter pure to
        # the published content surface.
        if dataset.respond_to?(:build_evidence) &&
           dataset.build_evidence.is_a?(Hash)
          be = dataset.build_evidence
          v = be['source_snapshot_id']
          return v if v.is_a?(String) && !v.empty?
          v = be[:source_snapshot_id]
          return v if v.is_a?(String) && !v.empty?
        end
        ''
      end

      # Collect the EXACT mapped CAD layer inventory from the
      # PCD semantic_graph's nodes + edges. The node inventory
      # uses `layer_names` (Array); the edge inventory uses
      # `layer_name` (single String). Both are required for
      # Blueprint §3.1 §5 (the layer must be known to the
      # PCD).
      def _collect_known_layers(pcd_nodes, pcd_edges)
        layers = {}
        pcd_nodes.each do |n|
          next unless n.is_a?(Hash)
          Array(n['layer_names']).each do |ln|
            layers[ln.to_s] = true if ln.is_a?(String) && !ln.empty?
          end
        end
        pcd_edges.each do |e|
          next unless e.is_a?(Hash)
          ln = e['layer_name']
          layers[ln.to_s] = true if ln.is_a?(String) && !ln.empty?
        end
        layers.keys.sort
      end

      # Adapt one PCD node record into the canonical-shape
      # node record expected by `CanonicalStructureReconstructor`.
      # The `xyz` field becomes `world_coordinate`; the
      # other fields are passed through with no invented geometry.
      def _project_node(pcd_node)
        h = {}
        h['canonical_node_id']    = pcd_node['node_id'].to_s
        h['endpoint_keys']        = []
        h['derived_edge_ids']     = []
        h['source_occurrence_ids'] =
          Array(pcd_node['source_occurrence_ids']).map(&:to_s).sort.uniq
        h['layer_names']          =
          Array(pcd_node['layer_names']).map(&:to_s).sort.uniq
        wc = pcd_node['xyz']
        h['world_coordinate']     = wc.is_a?(Array) ? wc.dup : nil
        h['resolved_clique']      =
          pcd_node['resolved_clique'] == true ? true : false
        h['membership_count']     = pcd_node['membership_count'].to_i
        # Blueprint §3.1 §10: pass the downstream coordinate_eps
        # as a per-node placeholder. The reconstructor pulls
        # this from the *explicit* `coordinate_epsilon:` kwarg
        # (Blueprint §3.3 + V1.8 SR18-02 authority); this field
        # is informational only and must NOT be used to derive a
        # different epsilon silently.
        h['coordinate_epsilon']   = nil
        h
      end

      # Adapt one PCD edge record into the canonical-shape
      # edge record expected by `CanonicalStructureReconstructor`.
      # The V1.8 reconstructor uses `world_endpoints` for
      # perimeter/length aggregation; derive the endpoint
      # coordinates from the FILTERED node inventory (not from
      # the PCD node record, which is the original global
      # graph). Preserve multiplicity: each source edge gets a
      # distinct canonical_edge_id.
      def _project_edge(pcd_edge, a_id, b_id, pcd_nodes_by_id, idx)
        wc_a = _coord_of(pcd_nodes_by_id, a_id)
        wc_b = _coord_of(pcd_nodes_by_id, b_id)
        {
          'canonical_edge_id'  => "v2-#{pcd_edge['edge_id']}",
          'node_a_id'          => a_id,
          'node_b_id'          => b_id,
          'origin_kind'        => pcd_edge['origin_kind'].to_s,
          'derived_edge_id'    => pcd_edge['edge_id'].to_s,
          'source_occurrence_id' => (
            Array(pcd_edge['source_occurrence_ids']).first.to_s
          ),
          'source_occurrence_ids' =>
            Array(pcd_edge['source_occurrence_ids']).map(&:to_s).sort.uniq,
          'repair_action_id'   => (
            r = pcd_edge['semantic_repair_id']
            r.is_a?(String) ? r.to_s : nil
          ),
          'world_endpoints'    => [wc_a, wc_b],
          'layer_name'         => pcd_edge['layer_name'].to_s,
          'unresolved_flags'   => []
        }
      end

      def _coord_of(pcd_nodes_by_id, nid)
        n = pcd_nodes_by_id[nid]
        return nil unless n.is_a?(Hash)
        wc = n['xyz']
        return nil unless wc.is_a?(Array) && wc.length == 3
        wc.map { |v| v.to_f }
      end

      def _stringify_adjacency(adj)
        out = {}
        adj.keys.sort.each do |k|
          out[k.to_s] = Array(adj[k]).map(&:to_s).sort.freeze
        end
        out.freeze
      end

      # Compute a deterministic SHA-256 digest over the
      # projected layer-local graph. Used by the projector to
      # assert byte-stable reorder identity.
      def _compute_layer_graph_digest(nodes, edges, adjacency)
        lines = []
        lines << "V|#{SCHEMA_VERSION}"
        nodes.each do |n|
          wc = n['world_coordinate']
          coord = if wc.is_a?(Array) && wc.length == 3
                    sprintf('%.10f|%.10f|%.10f', wc[0], wc[1], wc[2])
                  else
                    'none'
                  end
          lines << "N|#{n['canonical_node_id']}|#{coord}|#{Array(n['layer_names']).join(',')}"
        end
        edges.each do |e|
          lines << "E|#{e['canonical_edge_id']}|#{e['node_a_id']}|#{e['node_b_id']}|#{e['layer_name']}|#{e['origin_kind']}"
        end
        adjacency.keys.sort.each do |k|
          lines << "A|#{k}|#{Array(adjacency[k]).join(',')}"
        end
        Digest::SHA256.hexdigest(lines.join("\n"))
      end

      def _blocked(reasons)
        {
          'status'  => 'BLOCKED',
          'graph'   => nil,
          'reasons' => reasons.uniq.sort.freeze
        }
      end

      # Deep-freeze a value in place. Mirrors the V1.8
      # CanonicalStructureReconstructor.deep_freeze contract.
      def deep_freeze(obj)
        case obj
        when Hash
          obj.each_key { |k| deep_freeze(k) }
          obj.each_value { |v| deep_freeze(v) }
          obj.freeze
        when Array
          obj.each { |v| deep_freeze(v) }
          obj.freeze
        when String
          obj.freeze
        else
          obj
        end
      end
    end
  end
end