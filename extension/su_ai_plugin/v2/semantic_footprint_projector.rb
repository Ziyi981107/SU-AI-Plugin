#
# v2/semantic_footprint_projector.rb — V2-0A Pure-Data
# SemanticFootprintProjector.
#
# Per frozen V2-0A Stage Technical Blueprint
# (Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0A_SEMANTIC_FOOTPRINT_2026-09-16.md)
# §3.3 + §4 + §6 + §8:
#
#   Consume only the published PreparedCadDataset data.
#   Resolve the single geometry tolerance authority from
#     dataset.content['execution']['tolerance_values']['coordinate_epsilon'].
#   Require coordinate_epsilon to be Numeric, finite, strictly > 0.
#   Call LayerLocalGraphAdapter for the exact mapped layer.
#   Call existing CanonicalStructureReconstructor.reconstruct with
#     the SAME explicit coordinate_epsilon.
#   Project only valid reconstructed REGIONS, never raw loops.
#   Apply the Stage-0A acceptance contract below.
#   Publish accepted immutable SemanticFootprint records plus
#     deterministic rejection evidence for non-buildable results.
#   Never mutate PCD or reconstructor output.
#
#   Stage-0A acceptance contract (Blueprint §4):
#       - reconstructed region has exactly one outer loop
#       - hole_loop_ids is empty
#       - region has no unresolved flags
#       - referenced outer loop exists
#       - outer loop valid_for_region == true
#       - outer loop has at least 3 distinct nodes
#       - source coordinates are finite
#       - every source vertex satisfies inclusive ground-plane:
#           abs(z) <= coordinate_epsilon
#
#   Stage-0A rejection (fail-closed, Blueprint §4):
#       - holes / nested inner loops
#       - self-intersection
#       - endpoint-on-segment ambiguity
#       - collinear overlap
#       - zero / degenerate area
#       - same-layer parallel edges
#       - branching components
#       - malformed / missing references
#       - non-finite coordinates
#       - any vertex with abs(z) > coordinate_epsilon
#       - missing / invalid coordinate_epsilon
#       - empty / unknown mapped layer
#
#   Status contract (Blueprint §6):
#       PROJECTED                 - one or more valid footprints
#       PROJECTED_WITH_REJECTIONS - valid footprints + rejections
#       EMPTY                     - mapped layer exists but yields
#                                   no buildable footprint
#       BLOCKED                   - invalid dataset / invalid eps /
#                                   missing mapped layer / other
#                                   contract failure
#
# Pure value object. No SketchUp API calls, no observer, no
# shared-kernel modification. V1.8 CanonicalStructureReconstructor
# is the geometry authority (Blueprint §8).
#
# Files:
#   extension/su_ai_plugin/v2/layer_local_graph_adapter.rb
#   extension/su_ai_plugin/v2/semantic_footprint.rb
#   extension/su_ai_plugin/v2/semantic_footprint_projector.rb
#   tests/test_v2_stage0a_semantic_footprint.rb
#

require_relative 'layer_local_graph_adapter'
require_relative 'semantic_footprint'
require_relative '../../su_ai_plugin/core/prepared_cad_dataset'
require_relative '../../su_ai_plugin/core/canonical_structure_reconstructor'

module SUAnalysis
  module V2
    # SemanticFootprintProjector contract: derive immutable
    # V2 semantic-footprint records for one (dataset,
    # semantic_role, layer_name) tuple using the existing V1.8
    # geometry authority.
    #
    # Returns:
    #   { 'status'     => 'PROJECTED' | 'PROJECTED_WITH_REJECTIONS'
    #                    | 'EMPTY' | 'BLOCKED',
    #     'footprints' => <Array<Hash>> (empty on EMPTY/BLOCKED),
    #     'rejections' => <Array<Hash>> (deterministic),
    #     'reasons'    => <Array<String>> (deterministic) }
    module SemanticFootprintProjector
      module_function

      # Stage-0A output status values (Blueprint §6).
      STATUS_PROJECTED                  = 'PROJECTED'.freeze
      STATUS_PROJECTED_WITH_REJECTIONS = 'PROJECTED_WITH_REJECTIONS'.freeze
      STATUS_EMPTY                      = 'EMPTY'.freeze
      STATUS_BLOCKED                    = 'BLOCKED'.freeze

      # Stable rejection reason codes for the conservative
      # rejection list (Blueprint §4).
      REJECT_REASON_HOLES                 = 'v2_sfp_reject:hole_bearing_region'.freeze
      REJECT_REASON_UNRESOLVED_FLAGS      = 'v2_sfp_reject:region_unresolved_flags'.freeze
      REJECT_REASON_OUTER_LOOP_INVALID    = 'v2_sfp_reject:outer_loop_invalid_for_region'.freeze
      REJECT_REASON_OUTER_LOOP_MISSING    = 'v2_sfp_reject:outer_loop_missing'.freeze
      REJECT_REASON_DISTINCT_NODES_LT_3   = 'v2_sfp_reject:outer_loop_lt_3_distinct_nodes'.freeze
      REJECT_REASON_NON_FINITE_COORD      = 'v2_sfp_reject:non_finite_vertex_coordinate'.freeze
      REJECT_REASON_Z_OUT_OF_EPSILON      = 'v2_sfp_reject:z_out_of_epsilon'.freeze
      REJECT_REASON_ZERO_AREA            = 'v2_sfp_reject:zero_or_negative_area'.freeze

      # Stable input-contract blocker reason codes.
      BLOCKER_NOT_A_PCD              = LayerLocalGraphAdapter::REASON_NOT_A_PCD
      BLOCKER_NOT_FINALIZED          = LayerLocalGraphAdapter::REASON_NOT_FINALIZED
      BLOCKER_NOT_READY              = LayerLocalGraphAdapter::REASON_NOT_READY
      BLOCKER_PCD_SCHEMA_MISMATCH    = LayerLocalGraphAdapter::REASON_PCD_SCHEMA_MISMATCH
      BLOCKER_MISSING_SEMANTIC_GRAPH = LayerLocalGraphAdapter::REASON_MISSING_SEMANTIC_GRAPH
      BLOCKER_INVALID_LAYER_NAME     = LayerLocalGraphAdapter::REASON_INVALID_LAYER_NAME
      BLOCKER_EMPTY_MAPPED_LAYER     = LayerLocalGraphAdapter::REASON_EMPTY_MAPPED_LAYER
      BLOCKER_UNKNOWN_MAPPED_LAYER   = LayerLocalGraphAdapter::REASON_UNKNOWN_MAPPED_LAYER
      BLOCKER_MISSING_EPSILON        = 'v2_sfp_block:missing_coordinate_epsilon'.freeze
      BLOCKER_INVALID_EPSILON        = 'v2_sfp_block:invalid_coordinate_epsilon'.freeze
      BLOCKER_INVALID_ROLE           = 'v2_sfp_block:invalid_semantic_role'.freeze
      BLOCKER_RECONSTRUCTOR_FAILED   = 'v2_sfp_block:reconstructor_failed'.freeze
      BLOCKER_NO_REGIONS             = 'v2_sfp_block:no_regions_produced'.freeze
      BLOCKER_ZERO_AREA_REGION       = 'v2_sfp_block:all_regions_zero_area'.freeze

      # Project one mapped layer.
      #
      # Required:
      #   dataset       : a finalized `PreparedCadDataset`
      #   semantic_role : non-empty UTF-8 String
      #   layer_name    : non-empty UTF-8 String
      def project(dataset:, semantic_role:, layer_name:)
        reasons = []
        role_str = _require_role(semantic_role, reasons)
        return _blocked(reasons.uniq) if role_str.nil?
        # Step 1: resolve the single geometry tolerance authority.
        eps, eps_blockers = _resolve_coordinate_epsilon(dataset)
        reasons.concat(eps_blockers)
        if eps.nil?
          return _blocked(reasons.uniq)
        end
        # Step 2: layer-local graph adapter (exact layer match).
        adapter_out = LayerLocalGraphAdapter.project(
          dataset: dataset, layer_name: layer_name
        )
        if adapter_out['status'] != 'PROJECTED'
          reasons.concat(Array(adapter_out['reasons']))
          return _blocked(reasons.uniq)
        end
        # R1-05: known mapped layer with zero matching edges =>
        # adapter returns PROJECTED with `empty: true`. The
        # projector maps this to its EMPTY status (no
        # footprint, no rejection, no blocker) without
        # invoking the reconstructor.
        if adapter_out['empty'] == true
          return _empty(reasons.uniq)
        end
        local_graph = adapter_out['graph']
        # Step 3: call the existing V1.8 reconstructor with
        # the SAME explicit coordinate_epsilon. We pass the
        # JSON-safe Hash form so the reconstructor is forced
        # into its Hash-input branch and does not need a
        # live CanonicalGeometryGraph object.
        result = SUAnalysis::Core::CanonicalStructureReconstructor.reconstruct(
          local_graph,
          source_snapshot_id: local_graph['source_snapshot_id'],
          workspace_id: local_graph['workspace_id'],
          coordinate_epsilon: eps
        )
        # Step 4: classify each region against the Stage-0A
        # acceptance contract. Publish accepted footprints +
        # deterministic rejection evidence for the rest.
        dsid     = local_graph['source_dataset_id'].to_s
        cdigest  = dataset.content_digest.to_s
        layer    = local_graph['source_layer_name'].to_s
        accepted = []
        rejections = []
        loops_by_id = _index_loops(result['loops'])
        Array(result['regions']).each do |region|
          rid = region['region_id']
          outer_lid = region['outer_loop_id'].to_s
          outer = loops_by_id[outer_lid]
          if outer.nil?
            rejections << _build_rejection(
              rid, REJECT_REASON_OUTER_LOOP_MISSING,
              region: region
            )
            next
          end
          unless outer['valid_for_region'] == true
            rejections << _build_rejection(
              rid, REJECT_REASON_OUTER_LOOP_INVALID,
              region: region, loop: outer
            )
            next
          end
          if Array(outer['unresolved_flags']).any?
            rejections << _build_rejection(
              rid, REJECT_REASON_UNRESOLVED_FLAGS,
              region: region, loop: outer
            )
            next
          end
          if Array(region['hole_loop_ids']).any?
            rejections << _build_rejection(
              rid, REJECT_REASON_HOLES,
              region: region
            )
            next
          end
          if Array(region['unresolved_flags']).any?
            rejections << _build_rejection(
              rid, REJECT_REASON_UNRESOLVED_FLAGS,
              region: region
            )
            next
          end
          # Source provenance + coordinate contract.
          source_node_ids = _collect_source_node_ids(
            Array(outer['node_ids']),
            local_graph
          )
          source_edge_ids = _collect_source_edge_ids(
            Array(outer['edge_ids']),
            local_graph
          )
          source_coords = _loop_source_world_coords(
            Array(outer['world_coordinates'])
          )
          non_finite = source_coords.any? { |c|
            !(c.is_a?(Array) && c.length == 3 &&
              c.all? { |v| v.is_a?(Numeric) &&
                          v.respond_to?(:finite?) && v.finite? })
          }
          if non_finite
            rejections << _build_rejection(
              rid, REJECT_REASON_NON_FINITE_COORD,
              region: region, loop: outer
            )
            next
          end
          out_of_eps = source_coords.any? { |c|
            c[2].abs > eps
          }
          if out_of_eps
            rejections << _build_rejection(
              rid, REJECT_REASON_Z_OUT_OF_EPSILON,
              region: region, loop: outer
            )
            next
          end
          distinct_nodes = Array(outer['node_ids']).uniq.length
          if distinct_nodes < 3
            rejections << _build_rejection(
              rid, REJECT_REASON_DISTINCT_NODES_LT_3,
              region: region, loop: outer
            )
            next
          end
          region_area = region['area_xy'].to_f
          if !(region_area.is_a?(Numeric)) || !region_area.finite? ||
             region_area <= 0.0
            rejections << _build_rejection(
              rid, REJECT_REASON_ZERO_AREA,
              region: region, loop: outer
            )
            next
          end
          # Accepted: build the immutable SemanticFootprint
          # record. Project all source outer-loop world
          # coordinates onto z=0.0 (Blueprint §4). Preserve
          # the projected order (open polyline sequence
          # returned by the reconstructor).
          projected = source_coords.map { |c| [c[0], c[1], 0.0] }
          perimeter = outer['perimeter'].to_f
          if !(perimeter.is_a?(Numeric)) || !perimeter.finite? ||
             perimeter < 0.0
            perimeter = 0.0
          end
          fp = SemanticFootprint.build(
            semantic_role: role_str,
            source_layer_name: layer,
            source_dataset_id: dsid,
            source_content_digest: cdigest,
            coordinate_epsilon: eps,
            source_node_ids: source_node_ids,
            source_edge_ids: source_edge_ids,
            projected_world_coordinates: projected,
            area_xy: region_area,
            perimeter: perimeter
          )
          accepted << fp
        end
        # Stable order: by footprint_id.
        accepted.sort_by! { |f| f['footprint_id'].to_s }
        # Step 5: classify the overall status.
        if accepted.empty?
          # Blueprint §6: if the mapped layer is in the PCD but
          # yields no buildable footprint, status = EMPTY (NOT
          # BLOCKED). EMPTY implies the input was readable but
          # no footprints survived.
          if rejections.empty?
            return _empty(reasons.uniq)
          else
            # No accepted footprints but at least one rejection:
            # return EMPTY (the layer produced only conservative
            # rejections, no block).
            return _empty(reasons.uniq, rejections.sort_by { |r|
              r['region_id'].to_s
            })
          end
        end
        if rejections.empty?
          { 'status'     => STATUS_PROJECTED,
            'footprints' => accepted.freeze,
            'rejections' => [].freeze,
            'reasons'    => reasons.uniq.sort.freeze }
        else
          { 'status'     => STATUS_PROJECTED_WITH_REJECTIONS,
            'footprints' => accepted.freeze,
            'rejections' => rejections.sort_by { |r|
              r['region_id'].to_s
            }.freeze,
            'reasons'    => reasons.uniq.sort.freeze }
        end
      end

      # ---- internals ----

      def _resolve_coordinate_epsilon(dataset)
        unless dataset.is_a?(SUAnalysis::Core::PreparedCadDataset)
          return [nil, [BLOCKER_NOT_A_PCD]]
        end
        unless dataset.final?
          return [nil, [BLOCKER_NOT_FINALIZED]]
        end
        content = dataset.content
        unless content.is_a?(Hash)
          return [nil, [BLOCKER_MISSING_SEMANTIC_GRAPH]]
        end
        exec = content['execution']
        unless exec.is_a?(Hash)
          return [nil, [BLOCKER_MISSING_EPSILON]]
        end
        tv = exec['tolerance_values']
        unless tv.is_a?(Hash)
          return [nil, [BLOCKER_MISSING_EPSILON]]
        end
        eps = tv['coordinate_epsilon']
        if eps.nil?
          return [nil, [BLOCKER_MISSING_EPSILON]]
        end
        unless eps.is_a?(Numeric)
          return [nil, [BLOCKER_INVALID_EPSILON]]
        end
        f = eps.to_f
        unless f.finite? && f > 0
          return [nil, [BLOCKER_INVALID_EPSILON]]
        end
        [f, []]
      end

      def _require_role(semantic_role, reasons)
        unless semantic_role.is_a?(String)
          reasons << BLOCKER_INVALID_ROLE
          return nil
        end
        unless semantic_role.encoding.name == 'UTF-8' &&
               semantic_role.valid_encoding?
          reasons << BLOCKER_INVALID_ROLE
          return nil
        end
        if semantic_role.strip.empty?
          reasons << BLOCKER_INVALID_ROLE
          return nil
        end
        semantic_role.dup.force_encoding('UTF-8').freeze
      end

      def _index_loops(loops)
        idx = {}
        Array(loops).each do |l|
          next unless l.is_a?(Hash)
          idx[l['loop_id'].to_s] = l
        end
        idx
      end

      def _collect_source_node_ids(layer_node_ids, local_graph)
        # Map V1.8 canonical_node_id back to PCD node_id. The
        # LayerLocalGraphAdapter preserves the PCD node_id in
        # `canonical_node_id` (via _project_node).
        local_nodes = Array(local_graph['nodes'])
        by_canon = {}
        local_nodes.each do |n|
          by_canon[n['canonical_node_id'].to_s] = n['canonical_node_id'].to_s
        end
        layer_node_ids.map { |nid|
          by_canon[nid.to_s] || nid.to_s
        }.uniq.sort
      end

      def _collect_source_edge_ids(layer_edge_ids, local_graph)
        local_edges = Array(local_graph['edges'])
        by_canon = {}
        local_edges.each do |e|
          cid = e['canonical_edge_id'].to_s
          did = e['derived_edge_id'].to_s
          by_canon[cid] = did if !did.empty?
        end
        layer_edge_ids.map { |eid|
          did = by_canon[eid.to_s]
          did && !did.empty? ? did : eid.to_s
        }.uniq.sort
      end

      def _loop_source_world_coords(world_coords)
        out = []
        Array(world_coords).each do |c|
          next unless c.is_a?(Array) && c.length == 3
          out << c.map { |v| v.to_f }
        end
        out
      end

      def _build_rejection(region_id, reason_code, region: nil, loop: nil)
        {
          'region_id'       => (region_id || '').to_s,
          'reason'          => reason_code,
          'outer_loop_id'   => (region && region['outer_loop_id']) ?
                                  region['outer_loop_id'].to_s : '',
          'unresolved_flags' => (loop && Array(loop['unresolved_flags'])) ||
                                  (region && Array(region['unresolved_flags'])) ||
                                  [],
          'hole_loop_ids'   => region ? Array(region['hole_loop_ids']) : [],
          'area_xy'         => region ? region['area_xy'].to_f : 0.0
        }
      end

      def _blocked(reasons)
        {
          'status'     => STATUS_BLOCKED,
          'footprints' => [].freeze,
          'rejections' => [].freeze,
          'reasons'    => reasons.uniq.sort.freeze
        }
      end

      def _empty(reasons, rejections = [])
        {
          'status'     => STATUS_EMPTY,
          'footprints' => [].freeze,
          'rejections' => rejections.freeze,
          'reasons'    => reasons.uniq.sort.freeze
        }
      end
    end
  end
end