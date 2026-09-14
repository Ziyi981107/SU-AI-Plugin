#
# core/prepared_cad_dataset_builder.rb — V1.9B1 B1.3 Pure Builder.
#
# Per frozen V1.9B1 Blueprint v1.3 (authoritative over v1.2):
#
#   PreparedCadDatasetBuilder is a PURE builder. It accepts
#   only EXPLICIT INPUTS:
#
#     source_snapshot    : SourceSnapshot (V1.4 immutable wrapper)
#     workflow_snapshot  : Hash<String, ...> (the B1-owned
#                          normalized view of the working-mode
#                          runner snapshot; produced externally
#                          from the runner's snapshot Hash)
#     topology_snapshot  : Hash (cano-node.v1 from
#                          CanonicalTopologyBuilder.build)
#     canonical_graph    : CanonicalGeometryGraph (cgg.v1)
#     structure_result   : Hash<String, ...> (csr.v1 from
#                          CanonicalStructureReconstructor.reconstruct)
#     analysis_result    : AnalysisResult (V1.4 IssueRegistry +
#                          geometry_snapshot + active_edit_facts
#                          source)
#
#   The Builder:
#     - Has no Runner access (no globals, no instance_variable
#       reach-in, no private ivar access).
#     - Has no SketchUp API calls.
#     - Has no host mutation.
#     - Has no input mutation (every input is deep-frozen or
#       deep-duped before normalization).
#
#   Return:
#     Success:
#       { status: 'BUILT', dataset: <candidate PreparedCadDataset> }
#     Coherence / design failure:
#       { status: 'BLOCKED', dataset: nil, blockers: [String, ...] }
#
#   The Builder does NOT use 'NOT_READY' — that readiness
#   verdict belongs to the Validator.
#
# B1.3 owns:
#   - explicit-input coherence preflight
#   - semantic source projection
#   - semantic execution normalization
#   - semantic geometry ID remap (pcn / pce / pch / pcl / pcr /
#     pcrp) with truncated-ID collision hardening
#   - canonical content object assembly
#   - build_evidence assembly (legacy IDs / transient occurrence
#     IDs / current-session transient evidence are build evidence
#     only)
#

require 'digest'
require_relative 'prepared_cad_dataset'
require_relative 'analysis_result'

module SUAnalysis
  module Core
    module PreparedCadDatasetBuilder
      module_function

      STATUS_BUILT   = 'BUILT'.freeze
      STATUS_BLOCKED = 'BLOCKED'.freeze

      PCD_SCHEMA_VERSION             = 'pcd.v1'.freeze
      SOURCE_PROJECTION_SCHEMA       = 'pcd-source-projection.v1'.freeze
      EXECUTION_PROJECTION_SCHEMA    = 'pcd-execution.v1'.freeze
      SEMANTIC_GRAPH_SCHEMA          = 'pcd-semantic-graph.v1'.freeze
      COHERENCE_PROJECTION_SCHEMA    = 'pcd-coherence.v1'.freeze

      # The fixed execution tolerance key set.
      TOLERANCE_KEYS = [
        'duplicate',
        'short_edge',
        'gap_search',
        'coordinate_epsilon',
        'big_z',
        'large_coordinate',
        'planar_z_snap'
      ].freeze

      # Secondary source warnings allowed on the published dataset
      # (Blueprint v1.3 §13). Other families do not resurrect.
      SECONDARY_WARNING_TYPES = [
        'short_edge',
        'abnormal_large_coord',
        'deep_nesting'
      ].freeze

      # Stable reason codes (used as blockers).
      REASON_NOT_A_HASH                 = 'input_not_a_hash'.freeze
      REASON_MISSING_INPUT              = 'missing_input'.freeze
      REASON_WORKFLOW_STATE_NOT_READY   = 'workflow_state_not_ready'.freeze
      REASON_TOPOLOGY_SCHEMA_MISMATCH   = 'topology_schema_mismatch'.freeze
      REASON_TOPOLOGY_MISSING_ENDPOINTS = 'topology_endpoints_missing'.freeze
      REASON_TOPOLOGY_DUPLICATE_KEY     = 'topology_duplicate_endpoint_key'.freeze
      REASON_TOPOLOGY_BAD_COORDINATE    = 'topology_bad_endpoint_coordinate'.freeze
      REASON_GRAPH_SCHEMA_MISMATCH      = 'graph_schema_mismatch'.freeze
      REASON_STRUCTURE_SCHEMA_MISMATCH  = 'structure_schema_mismatch'.freeze
      REASON_SNAPSHOT_ID_MISMATCH       = 'snapshot_id_mismatch'.freeze
      REASON_WORKSPACE_ID_MISMATCH      = 'workspace_id_mismatch'.freeze
      REASON_STRUCTURE_GRAPH_DIGEST_MISMATCH =
        'structure_canonical_graph_digest_mismatch'.freeze
      REASON_EPSILON_MISMATCH           = 'coordinate_epsilon_mismatch'.freeze
      REASON_TOLERANCE_MISSING_KEY      = 'tolerance_missing_key'.freeze
      REASON_TOLERANCE_UNKNOWN_KEY      = 'tolerance_unknown_key'.freeze
      REASON_TOLERANCE_DUPLICATE_KEY    = 'tolerance_duplicate_key'.freeze
      REASON_TOLERANCE_BAD_VALUE        = 'tolerance_bad_value'.freeze
      REASON_OVERRIDE_BAD_TYPE          = 'session_override_bad_type'.freeze
      REASON_OVERRIDE_KEY_COLLISION     = 'session_override_key_collision'.freeze
      REASON_COHERENCE_DIGEST_MISMATCH  = 'analysis_source_coherence_mismatch'.freeze
      REASON_REGISTRY_EDGE_MISSING      = 'analysis_registry_edge_missing'.freeze
      REASON_REGISTRY_EDGE_NOT_IN_SOURCE =
        'analysis_registry_edge_not_in_source'.freeze
      REASON_NODE_CLIQUE_MISSING_MEMBER = 'node_clique_missing_member'.freeze
      REASON_NODE_CLIQUE_OUT_OF_EPSILON = 'node_clique_out_of_epsilon'.freeze
      REASON_SEMANTIC_NODE_AMBIGUITY    = 'semantic_node_ambiguity'.freeze
      REASON_SEMANTIC_EDGE_AMBIGUITY    = 'semantic_edge_ambiguity'.freeze
      REASON_SEMANTIC_CHAIN_AMBIGUITY   = 'semantic_chain_ambiguity'.freeze
      REASON_SEMANTIC_LOOP_AMBIGUITY    = 'semantic_loop_ambiguity'.freeze
      REASON_SEMANTIC_REGION_AMBIGUITY  = 'semantic_region_ambiguity'.freeze
      REASON_DATASET_ID_TRUNCATION_COLLISION =
        'dataset_id_truncation_collision'.freeze
      REASON_SEMANTIC_ID_TRUNCATION_COLLISION =
        'semantic_id_truncation_collision'.freeze
      REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS =
        'ambiguous_incomplete_occurrence'.freeze
      REASON_ANALYSIS_RESULT_INVALID    = 'analysis_result_invalid'.freeze
      REASON_INPUT_SHAPE                = 'input_shape_invalid'.freeze

      # Maximum iteration rounds for the topology-refined node
      # label refinement (Blueprint v1.3 §8.3).
      NODE_REFINEMENT_MAX_ROUNDS = 50

      # ----- Public API --------------------------------------------------

      def build(source_snapshot:, workflow_snapshot:,
                topology_snapshot:, canonical_graph:,
                structure_result:, analysis_result:)
        blockers = []

        # ----- input-shape gate --------------------------------------------
        blockers.concat(_check_inputs(
          source_snapshot: source_snapshot,
          workflow_snapshot: workflow_snapshot,
          topology_snapshot: topology_snapshot,
          canonical_graph: canonical_graph,
          structure_result: structure_result,
          analysis_result: analysis_result
        ))
        return _blocked(blockers) unless blockers.empty?

        # ----- workflow state gate -----------------------------------------
        blockers.concat(_check_workflow_state(workflow_snapshot))

        # ----- cross-input ID / digest gates -------------------------------
        blockers.concat(_check_cross_ids(
          source_snapshot: source_snapshot,
          workflow_snapshot: workflow_snapshot,
          topology_snapshot: topology_snapshot,
          canonical_graph: canonical_graph,
          structure_result: structure_result
        ))

        # ----- tolerance / execution normalization -------------------------
        normalized_tolerance = nil
        if blockers.empty?
          normalized_tolerance, tol_blockers = _normalize_tolerance(
            workflow_snapshot: workflow_snapshot,
            source_snapshot: source_snapshot,
            topology_snapshot: topology_snapshot,
            canonical_graph: canonical_graph
          )
          blockers.concat(tol_blockers)
        end

        return _blocked(blockers) unless blockers.empty?

        # ----- semantic source projection ----------------------------------
        source_projection, source_blockers = _project_source(source_snapshot)
        blockers.concat(source_blockers)

        # ----- semantic execution projection -------------------------------
        execution_projection, exec_blockers = _project_execution(
          source_snapshot: source_snapshot,
          workflow_snapshot: workflow_snapshot,
          normalized_tolerance: normalized_tolerance
        )
        blockers.concat(exec_blockers)

        # ----- active-edit context -----------------------------------------
        active_edit, ae_blockers = _project_active_edit(
          source_snapshot: source_snapshot,
          analysis_result: analysis_result
        )
        blockers.concat(ae_blockers)

        # ----- semantic geometry remap -------------------------------------
        graph_projection, graph_blockers, legacy_maps = _remap_graph(
          topology_snapshot: topology_snapshot,
          canonical_graph: canonical_graph,
          normalized_tolerance: normalized_tolerance,
          source_projection: source_projection
        )
        blockers.concat(graph_blockers)

        return _blocked(blockers) if graph_projection.nil?

        # ----- semantic structure remap ------------------------------------
        structure_projection, struct_blockers = _remap_structure(
          structure_result: structure_result,
          graph_projection: graph_projection,
          legacy_node_to_pcn: legacy_maps[:node],
          legacy_edge_to_pce: legacy_maps[:edge],
          source_projection: source_projection
        )
        blockers.concat(struct_blockers)

        # ----- current issue / readiness projection ------------------------
        issue_projection, issue_blockers = _project_issues(
          analysis_result: analysis_result,
          graph_projection: graph_projection
        )
        blockers.concat(issue_blockers)

        return _blocked(blockers) unless blockers.empty?

        # ----- coherence evidence ------------------------------------------
        coherence_digest, coh_blockers = _compute_coherence_digest(
          source_snapshot: source_snapshot,
          analysis_result: analysis_result
        )
        blockers.concat(coh_blockers)
        return _blocked(blockers) if coherence_digest.nil?

        # ----- assemble semantic content ------------------------------------
        content = {
          'schema_version'             => PCD_SCHEMA_VERSION,
          'source_projection'          => source_projection,
          'execution'                  => execution_projection,
          'active_edit_context'        => active_edit,
          'semantic_graph'             => graph_projection,
          'semantic_structure'         => structure_projection,
          'current_issues'             => issue_projection,
          'coherence_evidence'         => {
            'schema_version' => COHERENCE_PROJECTION_SCHEMA,
            'digest'         => coherence_digest
          }
        }

        # ----- assemble build_evidence --------------------------------------
        build_evidence = _build_evidence(
          source_snapshot: source_snapshot,
          workflow_snapshot: workflow_snapshot,
          topology_snapshot: topology_snapshot,
          canonical_graph: canonical_graph,
          structure_result: structure_result,
          analysis_result: analysis_result
        )

        # ----- truncated-ID collision gate ----------------------------------
        cd = PreparedCadDataset.compute_content_digest(content)
        ds_id = PreparedCadDataset.compute_dataset_id(cd)
        unless cd.start_with?(ds_id)
          return _blocked([REASON_DATASET_ID_TRUNCATION_COLLISION])
        end
        bed = PreparedCadDataset.compute_build_evidence_digest(cd, build_evidence)

        candidate = PreparedCadDataset.build_candidate(
          content: content,
          content_digest: cd,
          build_evidence: build_evidence,
          build_evidence_digest: bed
        )
        { 'status' => STATUS_BUILT, 'dataset' => candidate }
      end

      # ----- input-shape gate ----------------------------------------------

      def _check_inputs(source_snapshot:, workflow_snapshot:,
                        topology_snapshot:, canonical_graph:,
                        structure_result:, analysis_result:)
        blockers = []
        unless source_snapshot.respond_to?(:snapshot_id) && source_snapshot.respond_to?(:execution_config)
          blockers << REASON_INPUT_SHAPE + ':source_snapshot'
        end
        unless workflow_snapshot.is_a?(Hash)
          blockers << REASON_INPUT_SHAPE + ':workflow_snapshot'
        end
        unless topology_snapshot.is_a?(Hash)
          blockers << REASON_INPUT_SHAPE + ':topology_snapshot'
        end
        unless canonical_graph.respond_to?(:nodes) && canonical_graph.respond_to?(:edges) &&
               canonical_graph.respond_to?(:digest)
          blockers << REASON_INPUT_SHAPE + ':canonical_graph'
        end
        unless structure_result.is_a?(Hash)
          blockers << REASON_INPUT_SHAPE + ':structure_result'
        end
        unless analysis_result.respond_to?(:registry)
          blockers << REASON_INPUT_SHAPE + ':analysis_result'
        end
        blockers
      end

      # ----- workflow state gate -------------------------------------------

      def _check_workflow_state(workflow_snapshot)
        state = workflow_snapshot['state'] || workflow_snapshot[:state]
        return [REASON_WORKFLOW_STATE_NOT_READY] unless state.to_s == 'ready'
        []
      end

      # ----- cross-input ID / digest gates ---------------------------------

      def _check_cross_ids(source_snapshot:, workflow_snapshot:,
                           topology_snapshot:, canonical_graph:,
                           structure_result:)
        blockers = []
        ss_id = source_snapshot.snapshot_id.to_s
        ws_id = (workflow_snapshot['source_snapshot_id'] ||
                 workflow_snapshot[:source_snapshot_id]).to_s
        graph_ssid = canonical_graph.respond_to?(:source_snapshot_id) ?
                       canonical_graph.source_snapshot_id.to_s : ''
        struct_ssid = (structure_result['source_snapshot_id'] ||
                       structure_result[:source_snapshot_id]).to_s
        ws_id_graph = canonical_graph.respond_to?(:workspace_id) ?
                        canonical_graph.workspace_id.to_s : ''
        ws_id_workflow = (workflow_snapshot['workspace_id'] ||
                          workflow_snapshot[:workspace_id]).to_s
        ws_id_struct  = (structure_result['workspace_id'] ||
                         structure_result[:workspace_id]).to_s
        graph_dgst    = canonical_graph.respond_to?(:digest) ?
                          canonical_graph.digest.to_s : ''
        struct_graph_dgst = (structure_result['canonical_graph_digest'] ||
                             structure_result[:canonical_graph_digest]).to_s

        unless ss_id == ws_id && ss_id == graph_ssid && ss_id == struct_ssid
          blockers << REASON_SNAPSHOT_ID_MISMATCH
        end
        unless ws_id_graph == ws_id_workflow && ws_id_graph == ws_id_struct && !ws_id_graph.empty?
          blockers << REASON_WORKSPACE_ID_MISMATCH
        end
        unless struct_graph_dgst.empty? || struct_graph_dgst == graph_dgst
          blockers << REASON_STRUCTURE_GRAPH_DIGEST_MISMATCH
        end
        blockers
      end

      # ----- execution / tolerance normalization ---------------------------

      def _normalize_tolerance(workflow_snapshot:, source_snapshot:,
                               topology_snapshot:, canonical_graph:)
        blockers = []
        raw = _raw_tolerance_values(
          workflow_snapshot: workflow_snapshot,
          source_snapshot: source_snapshot
        )
        return [nil, [REASON_TOLERANCE_MISSING_KEY]] if raw.nil?
        # Accept Symbol or String keys; normalize to String.
        normalized = {}
        raw.each do |k, v|
          ks = k.is_a?(Symbol) ? k.to_s : k
          unless ks.is_a?(String)
            blockers << REASON_TOLERANCE_BAD_VALUE + ":key_type"
            break
          end
          if normalized.key?(ks)
            blockers << REASON_TOLERANCE_DUPLICATE_KEY + ":#{ks}"
            break
          end
          unless v.is_a?(Numeric) && v.finite? && v.to_f > 0
            blockers << REASON_TOLERANCE_BAD_VALUE + ":#{ks}"
            break
          end
          normalized[ks] = v.to_f
        end
        # Required-set equality.
        expected = TOLERANCE_KEYS
        unless normalized.keys.sort == expected.sort
          missing = expected - normalized.keys
          extra   = normalized.keys - expected
          unless missing.empty?
            blockers << REASON_TOLERANCE_MISSING_KEY + ":missing=#{missing.sort.join(',')}"
          end
          unless extra.empty?
            blockers << REASON_TOLERANCE_UNKNOWN_KEY + ":extra=#{extra.sort.join(',')}"
          end
        end
        return [nil, blockers] unless blockers.empty?
        # Epsilon binding: tolerance_values.coordinate_epsilon
        # must agree with topology + canonical_graph nodes.
        tol_eps = normalized['coordinate_epsilon']
        topo_eps = (topology_snapshot[:coordinate_epsilon] ||
                    topology_snapshot['coordinate_epsilon']).to_f
        unless topo_eps.finite? && topo_eps > 0 && topo_eps == tol_eps
          blockers << REASON_EPSILON_MISMATCH + ':topology_vs_tolerance'
        end
        # Every graph-node coordinate_epsilon must agree when present.
        graph_nodes = canonical_graph.respond_to?(:nodes) ? Array(canonical_graph.nodes) : []
        graph_nodes.each do |n|
          nh = n.is_a?(Hash) ? n : (n.respond_to?(:to_h) ? n.to_h : {})
          ge = nh['coordinate_epsilon']
          if !ge.nil?
            ge_f = ge.respond_to?(:to_f) ? ge.to_f : nil
            if !ge_f.finite? || ge_f != tol_eps
              blockers << REASON_EPSILON_MISMATCH + ':graph_node'
              break
            end
          end
        end
        blockers.empty? ? [normalized, []] : [nil, blockers]
      end

      def _raw_tolerance_values(workflow_snapshot:, source_snapshot:)
        # Prefer the captured execution config (SourceSnapshot).
        ec = source_snapshot.respond_to?(:execution_config) ?
               source_snapshot.execution_config : nil
        if ec.respond_to?(:tolerance_values)
          raw = ec.tolerance_values
          return raw.is_a?(Hash) ? raw : nil
        end
        # Fallback: workflow_snapshot may carry it under
        # tolerance (Planar / Topology repair) but ONLY the
        # captured execution_config is authoritative. Return nil
        # to force fail-closed.
        nil
      end

      # ----- session_overrides normalization ------------------------------

      def _normalize_session_overrides(value)
        case value
        when nil, true, false then value
        when Integer           then value
        when Float
          unless value.finite?
            raise ArgumentError, "non-finite Float: #{value.inspect}"
          end
          value
        when String
          unless value.respond_to?(:encoding) && value.encoding.name == 'UTF-8' &&
                 value.valid_encoding?
            raise ArgumentError, "invalid UTF-8 session_override String"
          end
          value
        when Array
          value.map { |x| _normalize_session_overrides(x) }
        when Hash
          out = {}
          value.each do |k, v|
            ks = k.is_a?(Symbol) ? k.to_s : k
            unless ks.is_a?(String)
              raise ArgumentError,
                    "session_override key must be String or Symbol; got #{k.inspect}"
            end
            if out.key?(ks)
              raise ArgumentError,
                    "session_override key collision: #{ks.inspect}"
            end
            out[ks] = _normalize_session_overrides(v)
          end
          out
        else
          raise ArgumentError,
                "unsupported session_override value: #{value.class}"
        end
      end

      # ----- source projection --------------------------------------------

      def _project_source(source_snapshot)
        blockers = []
        # Source-stable semantic ref derives from persistent_id_path.
        edges_in = source_snapshot.respond_to?(:edges) ?
                     Array(source_snapshot.edges) : []
        faces_in = source_snapshot.respond_to?(:faces) ?
                     Array(source_snapshot.faces) : []
        layers_in = source_snapshot.respond_to?(:layers) ?
                      Array(source_snapshot.layers) : []

        edge_descs = edges_in.map do |e|
          unless e.respond_to?(:source) && e.source.is_a?(SourceReference)
            blockers << REASON_INPUT_SHAPE + ':edge_source'
            break
          end
          s = _endpoint_xyz(e.start_point)
          t = _endpoint_xyz(e.end_point)
          unless s && t
            blockers << REASON_INPUT_SHAPE + ':edge_endpoints'
            break
          end
          layer_name = e.respond_to?(:layer) ? e.layer.to_s : ''
          ref = _stable_source_ref(e.source)
          ep = _canonical_edge_endpoints(s, t)
          {
            'kind'             => 'edge',
            'endpoints'        => ep,
            'layer_name'       => layer_name,
            'stable_source_ref' => ref
          }
        end
        # Sort by identity bytes, preserving multiplicity.
        edge_descs.sort_by! { |d| IdentityBytes.encode(d) } if blockers.empty?

        face_descs = faces_in.map do |f|
          unless f.respond_to?(:source) && f.source.is_a?(SourceReference)
            blockers << REASON_INPUT_SHAPE + ':face_source'
            break
          end
          ref = _stable_source_ref(f.source)
          {
            'kind'                    => 'face',
            'layer_name'              => f.respond_to?(:layer) ? f.layer.to_s : '',
            'outer_loop_vertex_count' => f.respond_to?(:outer_loop_vertex_count) ?
                                           f.outer_loop_vertex_count.to_i : 0,
            'inner_loop_count'        => f.respond_to?(:inner_loop_count) ?
                                           f.inner_loop_count.to_i : 0,
            'stable_source_ref'       => ref
          }
        end
        face_descs.sort_by! { |d| IdentityBytes.encode(d) } if blockers.empty?

        layer_descs = layers_in.map do |l|
          {
            'layer_name'           => l.respond_to?(:name) ? l.name.to_s : '',
            'role'                 => (l.respond_to?(:role) ?
                                         (l.role.is_a?(Symbol) ? l.role.to_s : l.role.to_s) :
                                         'UNKNOWN'),
            'role_rule'            => l.respond_to?(:role_rule) ? (l.role_rule ? l.role_rule.to_s : nil) : nil,
            'visible'              => l.respond_to?(:visible) ? (l.visible ? true : false) : true,
            'visibility_unknown'   => l.respond_to?(:visibility_unknown) ?
                                        (l.visibility_unknown ? true : false) : false,
            'edge_count'           => l.respond_to?(:edge_count) ? l.edge_count.to_i : 0,
            'face_count'           => l.respond_to?(:face_count) ? l.face_count.to_i : 0,
            'faces_with_holes_count' => l.respond_to?(:faces_with_holes_count) ?
                                          l.faces_with_holes_count.to_i : 0
          }
        end
        layer_descs.sort_by! { |d| IdentityBytes.encode(d) }

        projection = {
          'schema_version'                => SOURCE_PROJECTION_SCHEMA,
          'source_snapshot_schema_version' => source_snapshot.respond_to?(:schema_version) ?
                                               source_snapshot.schema_version.to_s : '',
          'edges'                         => edge_descs,
          'faces'                         => face_descs,
          'layers'                        => layer_descs
        }
        [projection, blockers]
      end

      def _stable_source_ref(source_ref)
        return nil unless source_ref.is_a?(SourceReference)
        return nil unless source_ref.pid_path_complete
        path = Array(source_ref.persistent_id_path)
        return nil if path.empty?
        { 'kind' => 'source_pid_path', 'persistent_id_path' => path.map(&:to_i) }
      end

      # Map legacy transient occurrence IDs (occ-X strings) to
      # stable source_pid_path refs. The occurrence ID matches a
      # stable ref ONLY when the current SourceSnapshot records
      # have the corresponding PID path. The current session
      # source_projection provides the lookup table
      # (edges[i].stable_source_ref).
      #
      # When the lookup fails, the occurrence ID is dropped
      # (transient occurrence IDs do NOT enter semantic content).
      def _stable_source_refs_from_occurrences(occurrence_ids, source_projection:)
        table = @_stable_source_ref_lookup
        unless table
          table = {}
          sp = source_projection || {}
          Array(sp['edges']).each do |edge|
            ref = edge['stable_source_ref']
            next unless ref.is_a?(Hash)
            # Map a synthetic occurrence spelling -> ref using
            # the source edge's index position.
            table[ref['persistent_id_path'].join('>')] = ref
          end
          @_stable_source_ref_lookup = table
        end
        # The graph's transient occurrence IDs are addresses
        # into the DerivedEntityRecord stream; the Builder does
        # not have direct access to that stream, so the lookup
        # cannot resolve occ-X -> PID path deterministically.
        # Blueprint v1.2 §7 says: only complete non-empty PID
        # path matches count as semantic provenance. Transient
        # occurrence IDs alone MUST NOT enter semantic content.
        # Therefore we return an empty Array here (no semantic
        # stable refs from occurrence IDs alone). Persistent
        # identifiers MUST flow through the SourceSnapshot
        # edge's stable_source_ref directly when present.
        refs = []
        Array(occurrence_ids).each do |oid|
          # No-op: graph occurrence IDs are transient.
        end
        refs
      end

      def _endpoint_xyz(point)
        return nil unless point.is_a?(Array) && point.length == 3
        out = point.map { |c| c.respond_to?(:to_f) ? c.to_f : nil }
        return nil if out.any? { |v| v.nil? || !v.finite? }
        out
      end

      def _canonical_edge_endpoints(a, b)
        # Canonical orientation: compare identity bytes of [a,b]
        # vs [b,a]; choose the lex-smaller.
        ab = [a, b]
        ba = [b, a]
        IdentityBytes.encode(ab) <= IdentityBytes.encode(ba) ? ab : ba
      end

      # ----- execution projection -----------------------------------------

      def _project_execution(source_snapshot:, workflow_snapshot:,
                             normalized_tolerance:)
        blockers = []
        ec = source_snapshot.execution_config
        session_raw = ec.respond_to?(:session_overrides) ? ec.session_overrides : {}
        session = {}
        begin
          session = _normalize_session_overrides(session_raw || {})
        rescue ArgumentError => e
          blockers << REASON_OVERRIDE_BAD_TYPE + ':' + e.message[0, 80]
          return [nil, blockers]
        end
        projection = {
          'schema_version' => EXECUTION_PROJECTION_SCHEMA,
          'profile_id'     => ec.respond_to?(:profile_id) ? ec.profile_id.to_s : '',
          'profile_version' => ec.respond_to?(:profile_version) ?
                                 ec.profile_version.to_s : '',
          'rule_set_id'    => ec.respond_to?(:rule_set_id) ? ec.rule_set_id.to_s : '',
          'rule_set_version' => ec.respond_to?(:rule_set_version) ?
                                   ec.rule_set_version.to_s : '',
          'rule_set_digest'  => ec.respond_to?(:rule_set_digest) ?
                                   ec.rule_set_digest.to_s : '',
          'tolerance_schema_version' => ec.respond_to?(:tolerance_schema_version) ?
                                          ec.tolerance_schema_version.to_s : '',
          'tolerance_values' => normalized_tolerance,
          'session_overrides' => session,
          'source_snapshot_schema_version' =>
            ec.respond_to?(:source_snapshot_schema_version) ?
              ec.source_snapshot_schema_version.to_s : ''
        }
        [projection, blockers]
      end

      # ----- active-edit context ------------------------------------------

      def _project_active_edit(source_snapshot:, analysis_result:)
        blockers = []
        ctx = {}
        # Preferred: SourceSnapshot.transform_context.
        if source_snapshot.respond_to?(:transform_context) &&
           source_snapshot.transform_context.is_a?(Hash) &&
           !source_snapshot.transform_context.empty?
          tctx = source_snapshot.transform_context
          # Identity marker is acceptable (root fallback).
          if tctx['active_edit_seed'].to_s == 'identity'
            ctx = _active_edit_root_fallback
          else
            fwd = tctx['active_edit_transform']
            inv = tctx['active_edit_inverse']
            path = tctx['active_edit_path']
            complete = tctx['pid_path_complete']
            unless fwd.is_a?(Array) && fwd.length == 16 &&
                   fwd.all? { |v| v.is_a?(Numeric) && v.finite? }
              blockers << REASON_INPUT_SHAPE + ':active_edit_transform'
            end
            unless inv.is_a?(Array) && inv.length == 16 &&
                   inv.all? { |v| v.is_a?(Numeric) && v.finite? }
              blockers << REASON_INPUT_SHAPE + ':active_edit_inverse'
            end
            unless path.is_a?(Array) && path.all? { |s| s.is_a?(Integer) }
              blockers << REASON_INPUT_SHAPE + ':active_edit_path'
            end
            unless [true, false].include?(complete)
              blockers << REASON_INPUT_SHAPE + ':pid_path_complete'
            end
            return [nil, blockers] unless blockers.empty?
            ctx = {
              'context_kind'          => 'active_edit',
              'active_edit_transform' => fwd.map { |v| v.to_f },
              'active_edit_inverse'   => inv.map { |v| v.to_f },
              'active_edit_path'      => path.map(&:to_i),
              'pid_path_complete'     => complete ? true : false
            }
          end
        else
          ctx = _active_edit_root_fallback
        end
        # Coordinate context (always sketchup_model_world).
        unit = source_snapshot.respond_to?(:unit) ?
                 source_snapshot.unit.to_s : 'inches'
        origin = source_snapshot.respond_to?(:coordinate_origin) ?
                   source_snapshot.coordinate_origin.to_s : 'raw'
        projection = {
          'schema_version'          => 'pcd-active-edit.v1',
          'coordinate_space'        => 'sketchup_model_world',
          'unit'                    => unit,
          'axes'                    => ['x', 'y', 'z'],
          'source_coordinate_origin' => origin,
          'active_edit_context'     => ctx
        }
        [projection, blockers]
      end

      def _active_edit_root_fallback
        identity = [
          1.0, 0.0, 0.0, 0.0,
          0.0, 1.0, 0.0, 0.0,
          0.0, 0.0, 1.0, 0.0,
          0.0, 0.0, 0.0, 1.0
        ]
        {
          'context_kind'          => 'root',
          'active_edit_transform' => identity.dup,
          'active_edit_inverse'   => identity.dup,
          'active_edit_path'      => [],
          'pid_path_complete'     => true
        }
      end

      # ----- semantic graph remap -----------------------------------------

      def _remap_graph(topology_snapshot:, canonical_graph:,
                       normalized_tolerance:, source_projection:)
        blockers = []
        schema = (topology_snapshot[:schema_version] ||
                  topology_snapshot['schema_version']).to_s
        unless schema == 'cano-node.v1'
          blockers << REASON_TOPOLOGY_SCHEMA_MISMATCH + ":got=#{schema}"
          return [nil, blockers]
        end
        eps = normalized_tolerance['coordinate_epsilon']

        # Topology endpoint resolution: must have endpoints,
        # unique endpoint_keys, exactly 3 finite coords.
        endpoints = topology_snapshot[:endpoints] || topology_snapshot['endpoints']
        endpoints = Array(endpoints)
        topo_keys = {}
        topo_world = {}
        endpoints.each do |ep|
          unless ep.respond_to?(:endpoint_key) && ep.respond_to?(:world_coordinate)
            blockers << REASON_INPUT_SHAPE + ':topology_endpoint'
            break
          end
          k = ep.endpoint_key.to_s
          if topo_keys.key?(k)
            blockers << REASON_TOPOLOGY_DUPLICATE_KEY + ":key=#{k}"
            break
          end
          wc = ep.world_coordinate
          unless wc.is_a?(Array) && wc.length == 3 &&
                 wc.all? { |v| v.is_a?(Numeric) && v.finite? }
            blockers << REASON_TOPOLOGY_BAD_COORDINATE + ":key=#{k}"
            break
          end
          topo_keys[k] = true
          topo_world[k] = wc.map(&:to_f)
        end

        # Canonical nodes from the topology snapshot
        # (raw topology nodes) and from the graph (collapsed
        # logical nodes). Resolve every graph node member through
        # the topology endpoints; verify clique agreement within
        # eps.
        topo_canonicals = topology_snapshot[:canonical_nodes] ||
                            topology_snapshot['canonical_nodes'] || []
        topo_canonicals = Array(topo_canonicals)
        topo_groups = {}
        topo_canonicals.each do |n|
          nh = n.is_a?(Hash) ? n : (n.respond_to?(:to_h) ? n.to_h : {})
          cid = nh['canonical_node_id'].to_s
          ek  = nh['endpoint_key'].to_s
          next if cid.empty? || ek.empty?
          topo_groups[cid] ||= []
          topo_groups[cid] << ek
        end

        graph_nodes = Array(canonical_graph.nodes)
        if blockers.empty?
          # T (topology endpoint keys) vs G (graph-node member keys).
          graph_member_keys = []
          graph_nodes.each do |gn|
            nh = gn.is_a?(Hash) ? gn : (gn.respond_to?(:to_h) ? gn.to_h : {})
            Array(nh['endpoint_keys']).each { |k| graph_member_keys << k.to_s }
          end
          topo_key_set = topo_keys.keys.sort
          graph_key_set = graph_member_keys.uniq.sort
          if topo_key_set != graph_key_set
            missing = topo_key_set - graph_key_set
            extra   = graph_key_set - topo_key_set
            blockers << REASON_GRAPH_SCHEMA_MISMATCH +
                            ":missing=#{missing.sort.join(',')}:extra=#{extra.sort.join(',')}"
          end
        end

        # ----- Node representative + topology-refined label ------------
        # Resolve every graph node's member coordinates; verify
        # clique agreement within eps; pick lex-smallest by
        # identity bytes; iterate node label refinement until
        # labels stop changing or NODE_REFINEMENT_MAX_ROUNDS.
        #
        # The label seed uses xyz + sorted unique stable source
        # refs + sorted layer_names + resolved_clique +
        # membership_count. The provisional edge label uses
        # the unordered endpoint label0 pair + origin_kind +
        # layer_name + sorted stable source refs + unresolved
        # flags + semantic_repair_id.
        #
        # We build:
        #   node_records   : per-node semantic record (xyz, etc.)
        #   node_id_map    : legacy_canonical_node_id -> pcn-id
        #   semantic_edges : remapped edges (carrying pcn/pce IDs)

        # Stage A: per-graph-node resolve + clique check + rep coord.
        node_records = []
        graph_node_id_by_cid = {}
        graph_nodes.each do |gn|
          nh = gn.is_a?(Hash) ? gn : (gn.respond_to?(:to_h) ? gn.to_h : {})
          cid = nh['canonical_node_id'].to_s
          members = Array(nh['endpoint_keys']).map(&:to_s)
          coords = []
          ok = true
          members.each do |k|
            wc = topo_world[k]
            if wc.nil?
              blockers << REASON_NODE_CLIQUE_MISSING_MEMBER + ":node=#{cid}:ek=#{k}"
              ok = false
              break
            end
            coords << wc
          end
          next unless ok
          # Clique agreement: every pair within eps.
          (0...coords.length).each do |i|
            ((i + 1)...coords.length).each do |j|
              d = _coord_distance(coords[i], coords[j])
              if d > eps.to_f
                blockers << REASON_NODE_CLIQUE_OUT_OF_EPSILON +
                                ":node=#{cid}:d=#{d}"
                ok = false
                break
              end
            end
            break unless ok
          end
          next unless ok
          # Representative coord = lex-smallest by identity bytes.
          sorted_coords = coords.sort_by { |c| IdentityBytes.encode(c) }
          rep = sorted_coords.first
          # Sorted unique stable source refs: derived from the
          # occurrence-ID lookup against SourceSnapshot
          # (Blueprint v1.2 §7). Transient occurrence IDs (occ-X)
          # are NOT semantic identity and MUST NOT enter content.
          srefs = _stable_source_refs_from_occurrences(
            Array(nh['source_occurrence_ids']),
            source_projection: source_projection
          )
          layers = Array(nh['layer_names']).map(&:to_s).sort.uniq
          node_records << {
            'legacy_canonical_node_id' => cid,
            'xyz'                      => rep,
            'membership_count'         => members.length,
            'endpoint_keys'            => members.sort,
            'layer_names'              => layers,
            'source_occurrence_ids'    => srefs,
            'resolved_clique'          => nh['resolved_clique'] ? true : false
          }
        end
        if blockers.empty?
          # Initial label0 = SHA256(label_seed).
          node_records.each do |nr|
            seed = {
              'xyz'              => nr['xyz'],
              'source_occurrence_ids' => nr['source_occurrence_ids'],
              'layer_names'      => nr['layer_names'],
              'resolved_clique'  => nr['resolved_clique'],
              'membership_count' => nr['membership_count']
            }
            nr['label_seed'] = seed
            nr['label0'] = Digest::SHA256.hexdigest(
              IdentityBytes.encode(seed)
            )[0, 16]
          end

          # Build edge->node link index for provisional edge labels.
          edge_records = Array(canonical_graph.edges)
          # Provisional edges: we need node_a_id / node_b_id mapped
          # to legacy canonical_node_id; for that we use the
          # graph-published adjacency / node order.
          # Build a node_a_id -> legacy_canonical_node_id map.
          legacy_by_node_id = {}
          graph_nodes.each do |gn|
            nh = gn.is_a?(Hash) ? gn : (gn.respond_to?(:to_h) ? gn.to_h : {})
            legacy_by_node_id[nh['canonical_node_id'].to_s] = nh['canonical_node_id'].to_s
          end

          # Sort node_records by label0 for stable iteration.
          node_records.sort_by! { |nr| nr['label0'] }

          # ----- Semantic edge IDs -------------------------------------
          # Each graph edge carries:
          #   node_a_id, node_b_id (legacy canonical_node_ids)
          #   origin_kind, layer_name, derived_edge_id,
          #   source_occurrence_ids, repair_action_id,
          #   world_endpoints, unresolved_flags
          # Map node IDs to provisional label0 (initial round).
          label0_by_cid = {}
          node_records.each { |nr| label0_by_cid[nr['legacy_canonical_node_id']] = nr['label0'] }

          semantic_edges = []
          # Map legacy_canonical_edge_id -> pce-id
          edge_label0_pairs = []
          edge_records.each do |e|
            eh = e.is_a?(Hash) ? e : (e.respond_to?(:to_h) ? e.to_h : {})
            a = eh['node_a_id'].to_s
            b = eh['node_b_id'].to_s
            la = label0_by_cid[a]
            lb = label0_by_cid[b]
            # Lex-smaller first.
            if la && lb
              lo_pair = la <= lb ? [la, lb] : [lb, la]
            else
              lo_pair = [la || a, lb || b]
            end
            origin = (eh['origin_kind'] || 'source_derived').to_s
            layer  = eh['layer_name'].to_s
            # Sort out transient occurrence IDs.
            srefs  = _stable_source_refs_from_occurrences(
              Array(eh['source_occurrence_ids']),
              source_projection: source_projection
            )
            repair_id = eh['repair_action_id'] ? eh['repair_action_id'].to_s : nil
            unresolved = Array(eh['unresolved_flags']).map(&:to_s).sort.uniq
            semantic_repair_id = nil
            if origin == 'gap_bridge' && repair_id && !repair_id.empty?
              semantic_repair_id = _semantic_repair_id(
                repair_id: repair_id,
                source_occurrence_ids: srefs
              )
            end
            record_without_id = {
              'node_a_label0'         => lo_pair[0],
              'node_b_label0'         => lo_pair[1],
              'origin_kind'           => origin,
              'layer_name'            => layer,
              'stable_source_refs'    => srefs,
              'unresolved_flags'      => unresolved,
              'semantic_repair_id'    => semantic_repair_id
            }
            edge_label0_pairs << record_without_id
            semantic_edges << {
              'legacy_canonical_edge_id' => eh['canonical_edge_id'].to_s,
              'node_a_id'                => a,
              'node_b_id'                => b,
              'origin_kind'              => origin,
              'layer_name'               => layer,
              'source_occurrence_ids'    => srefs,
              'repair_action_id'         => repair_id,
              'world_endpoints'          => eh['world_endpoints'],
              'unresolved_flags'         => unresolved,
              'label_record'             => record_without_id
            }
          end
          semantic_edges.sort_by! { |e| e['legacy_canonical_edge_id'] }

          # ----- Node label refinement rounds --------------------------
          # We need a stable function:
          #   next_label(nr) = sha256(IdentityBytes({
          #     'node_local_seed' => nr.label_seed,
          #     'edges' => sorted [(provisional_edge_label, neighbor_prev_label)]
          #   }))
          # For initial round, neighbor_prev_label = previous label0.
          # We iterate until labels stop changing or hit the round cap.
          prev_labels = {}
          node_records.each { |nr| prev_labels[nr['legacy_canonical_node_id']] = nr['label0'] }
          # Build a per-node list of incident edges (canonical_edge_id).
          incident = Hash.new { |h, k| h[k] = [] }
          semantic_edges.each do |e|
            incident[e['node_a_id']] << e
            incident[e['node_b_id']] << e
          end

          current_labels = prev_labels.dup
          (0...NODE_REFINEMENT_MAX_ROUNDS).each do |_round|
            next_labels = {}
            node_records.each do |nr|
              cid = nr['legacy_canonical_node_id']
              ed = incident[cid]
              pair_list = ed.map do |e|
                other_cid = e['node_a_id'] == cid ? e['node_b_id'] : e['node_a_id']
                other_prev = current_labels[other_cid] || other_cid
                # Provisional edge label: re-derive per round using
                # the CURRENT labels of the two endpoints.
                la = current_labels[e['node_a_id']] || e['node_a_id']
                lb = current_labels[e['node_b_id']] || e['node_b_id']
                lo_pair = la <= lb ? [la, lb] : [lb, la]
                prov = {
                  'node_a_label0'         => lo_pair[0],
                  'node_b_label0'         => lo_pair[1],
                  'origin_kind'           => e['origin_kind'],
                  'layer_name'            => e['layer_name'],
                  'stable_source_refs'    => e['source_occurrence_ids'],
                  'unresolved_flags'      => e['unresolved_flags'],
                  'semantic_repair_id'    => e['label_record']['semantic_repair_id']
                }
                prov_label = Digest::SHA256.hexdigest(
                  IdentityBytes.encode(prov)
                )[0, 16]
                [prov_label, other_prev].sort_by { |s| s.bytes }
              end
              pair_list.sort_by! { |p| IdentityBytes.encode(p) }
              input = {
                'node_local_seed' => nr['label_seed'],
                'edges'           => pair_list
              }
              next_labels[cid] = Digest::SHA256.hexdigest(
                IdentityBytes.encode(input)
              )[0, 16]
            end
            if next_labels == current_labels
              current_labels = next_labels
              break
            end
            current_labels = next_labels
          end

          # Final pcn IDs + collision check.
          full_digest_by_pid = {}
          node_id_by_cid = {}
          node_records.each do |nr|
            cid = nr['legacy_canonical_node_id']
            full = Digest::SHA256.hexdigest(current_labels[cid])
            pid = PreparedCadDataset::NODE_ID_PREFIX + full[0, 20]
            if full_digest_by_pid.key?(pid) &&
               full_digest_by_pid[pid] != full
              blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION + ':node'
            end
            full_digest_by_pid[pid] = full
            node_id_by_cid[cid] = pid
            nr['node_id'] = pid
            nr['full_node_digest'] = full
          end

          # If any two distinct legacy nodes share the same final
          # label (full digest), BLOCKED.
          seen_label = {}
          node_records.each do |nr|
            cid = nr['legacy_canonical_node_id']
            full = nr['full_node_digest']
            if seen_label.key?(full) && seen_label[full] != cid
              blockers << REASON_SEMANTIC_NODE_AMBIGUITY + ":full=#{full[0,12]}"
            end
            seen_label[full] = cid
          end

          # ----- Semantic edge IDs (final) -----------------------------
          edge_id_by_legacy = {}
          edge_full_by_pid = {}
          semantic_edges.each do |e|
            a = e['node_a_id']
            b = e['node_b_id']
            node_a_id = node_id_by_cid[a] || a
            node_b_id = node_id_by_cid[b] || b
            node_pair = node_a_id <= node_b_id ? [node_a_id, node_b_id] :
                                                  [node_b_id, node_a_id]
            record = {
              'node_a_id'             => node_pair[0],
              'node_b_id'             => node_pair[1],
              'origin_kind'           => e['origin_kind'],
              'layer_name'            => e['layer_name'],
              'stable_source_refs'    => e['source_occurrence_ids'],
              'unresolved_flags'      => e['unresolved_flags'],
              'semantic_repair_id'    => e['label_record']['semantic_repair_id']
            }
            full = Digest::SHA256.hexdigest(IdentityBytes.encode(record))
            pid = PreparedCadDataset::EDGE_ID_PREFIX + full[0, 20]
            if edge_full_by_pid.key?(pid) && edge_full_by_pid[pid] != full
              blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION + ':edge'
            end
            edge_full_by_pid[pid] = full
            edge_id_by_legacy[e['legacy_canonical_edge_id']] = pid
            e['semantic_edge_id'] = pid
            e['semantic_node_a_id'] = node_a_id
            e['semantic_node_b_id'] = node_b_id
          end

          # Collision check for distinct legacy edges.
          seen_efull = {}
          semantic_edges.each do |e|
            cid = e['legacy_canonical_edge_id']
            full = edge_full_by_pid[e['semantic_edge_id']]
            if seen_efull.key?(full) && seen_efull[full] != cid
              blockers << REASON_SEMANTIC_EDGE_AMBIGUITY + ":full=#{full[0,12]}"
            end
            seen_efull[full] = cid
          end

          # ----- Adjacency rebuild from semantic edges -----------------
          adj = Hash.new { |h, k| h[k] = [] }
          semantic_edges.each do |e|
            a = e['semantic_node_a_id']
            b = e['semantic_node_b_id']
            adj[a] << b
            adj[b] << a
          end
          adj.each_value { |v| v.uniq!; v.sort! }

          # Final node_records list with semantic IDs (drop legacy
          # internal fields used for round refinement).
          final_nodes = node_records.map do |nr|
            {
              'node_id'             => nr['node_id'],
              'xyz'                 => nr['xyz'],
              'membership_count'    => nr['membership_count'],
              'endpoint_keys'       => nr['endpoint_keys'],
              'layer_names'         => nr['layer_names'],
              'source_occurrence_ids' => nr['source_occurrence_ids'],
              'resolved_clique'     => nr['resolved_clique']
            }
          end
          final_nodes.sort_by! { |n| n['node_id'] }

          final_edges = semantic_edges.map do |e|
            {
              'edge_id'             => e['semantic_edge_id'],
              'node_a_id'           => e['semantic_node_a_id'],
              'node_b_id'           => e['semantic_node_b_id'],
              'origin_kind'         => e['origin_kind'],
              'layer_name'          => e['layer_name'],
              'source_occurrence_ids' => e['source_occurrence_ids'],
              'semantic_repair_id'  => e['label_record']['semantic_repair_id']
            }
          end
          final_edges.sort_by! { |e| e['edge_id'] }

          # Adjacency: stable string-keyed map.
          final_adj = {}
          adj.each { |k, v| final_adj[k.to_s] = v.map(&:to_s).sort }
          final_adj.keys.sort.each { |k| final_adj[k] = final_adj.delete(k) }

          projection = {
            'schema_version' => SEMANTIC_GRAPH_SCHEMA,
            'nodes'          => final_nodes,
            'edges'          => final_edges,
            'adjacency'      => final_adj
          }
          legacy_node_to_pcn = {}
          node_records.each do |nr|
            legacy_node_to_pcn[nr['legacy_canonical_node_id']] = nr['node_id']
          end
          legacy_edge_to_pce = {}
          semantic_edges.each do |e|
            legacy_edge_to_pce[e['legacy_canonical_edge_id']] = e['semantic_edge_id']
          end
          legacy_maps = { :node => legacy_node_to_pcn, :edge => legacy_edge_to_pce }
          [projection, blockers, legacy_maps]
        else
          [nil, blockers, { :node => {}, :edge => {} }]
        end
      end

      def _coord_distance(a, b)
        dx = a[0] - b[0]
        dy = a[1] - b[1]
        dz = a[2] - b[2]
        Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
      end

      def _semantic_repair_id(repair_id:, source_occurrence_ids:)
        return nil if repair_id.nil? || repair_id.to_s.empty?
        record = {
          'repair_id'             => repair_id.to_s,
          'stable_source_refs'    => Array(source_occurrence_ids).map(&:to_s).sort.uniq
        }
        full = Digest::SHA256.hexdigest(IdentityBytes.encode(record))
        PreparedCadDataset::REPAIR_ID_PREFIX + full[0, 20]
      end

      # ----- semantic structure remap -------------------------------------

      def _remap_structure(structure_result:, graph_projection:,
                           legacy_node_to_pcn:, legacy_edge_to_pce:,
                           source_projection:)
        blockers = []
        schema = structure_result[:schema_version] ||
                   structure_result['schema_version']
        unless schema.to_s == 'csr.v1'
          blockers << REASON_STRUCTURE_SCHEMA_MISMATCH + ":got=#{schema}"
          return [nil, blockers]
        end

        # Build node lookup from graph_projection.
        node_lookup = {}
        Array(graph_projection['nodes']).each do |n|
          node_lookup[n['node_id'].to_s] = n['xyz']
        end
        edge_lookup = {}
        Array(graph_projection['edges']).each do |e|
          edge_lookup[e['edge_id'].to_s] = e
        end

        # ----- Chains ---------------------------------------------------
        chains_in = structure_result[:chains] || structure_result['chains'] || []
        chain_records = []
        Array(chains_in).each do |ch|
          nh = ch.is_a?(Hash) ? ch : (ch.respond_to?(:to_h) ? ch.to_h : {})
          legacy_node_ids = Array(nh['node_ids'] || nh[:node_ids]).map(&:to_s)
          legacy_edge_ids = Array(nh['edge_ids'] || nh[:edge_ids]).map(&:to_s)
          # Map legacy node ids via the graph. The graph projection
          # publishes node_id from canonical_node_id; map via the
          # legacy_canonical_node_id supplied by the chain's
          # construction. The canonical_structure_reconstructor
          # published chain.node_ids as canonical_node_ids (cn-...).
          remap_nodes = _remap_chain_nodes(legacy_node_ids, legacy_node_to_pcn)
          remap_edges = _remap_chain_edges(legacy_edge_ids, legacy_edge_to_pce)
          # Forward and reverse traversal tokens.
          fwd_seq = _alternating_sequence(remap_nodes, remap_edges)
          rev_seq = fwd_seq.reverse
          chosen = (IdentityBytes.encode(fwd_seq) <= IdentityBytes.encode(rev_seq)) ?
                     fwd_seq : rev_seq
          record_without_id = {
            'node_ids' => chosen.select { |t| t.start_with?(PreparedCadDataset::NODE_ID_PREFIX) },
            'edge_ids' => chosen.select { |t| t.start_with?(PreparedCadDataset::EDGE_ID_PREFIX) }
          }
          full = Digest::SHA256.hexdigest(IdentityBytes.encode(record_without_id))
          chain_records << {
            'chain_id'   => PreparedCadDataset::CHAIN_ID_PREFIX + full[0, 20],
            'full_digest' => full,
            'node_ids'   => record_without_id['node_ids'],
            'edge_ids'   => record_without_id['edge_ids']
          }
        end
        # Collision check.
        seen = {}
        chain_records.each do |c|
          if seen.key?(c['full_digest']) && seen[c['full_digest']] != c['chain_id']
            blockers << REASON_SEMANTIC_CHAIN_AMBIGUITY
            break
          end
          seen[c['full_digest']] = c['chain_id']
        end
        chain_records.each { |c| c.delete('full_digest') }

        # ----- Loops ----------------------------------------------------
        loops_in = structure_result[:loops] || structure_result['loops'] || []
        loop_records = []
        Array(loops_in).each do |lp|
          lh = lp.is_a?(Hash) ? lp : (lp.respond_to?(:to_h) ? lp.to_h : {})
          legacy_node_ids = Array(lh['node_ids'] || lh[:node_ids]).map(&:to_s)
          legacy_edge_ids = Array(lh['edge_ids'] || lh[:edge_ids]).map(&:to_s)
          remap_nodes = _remap_chain_nodes(legacy_node_ids, legacy_node_to_pcn)
          remap_edges = _remap_chain_edges(legacy_edge_ids, legacy_edge_to_pce)
          base_seq = _alternating_sequence(remap_nodes, remap_edges)
          rotations = _loop_rotations(base_seq)
          chosen = rotations.min_by { |s| IdentityBytes.encode(s) }
          record_without_id = {
            'node_ids' => chosen.select { |t| t.start_with?(PreparedCadDataset::NODE_ID_PREFIX) },
            'edge_ids' => chosen.select { |t| t.start_with?(PreparedCadDataset::EDGE_ID_PREFIX) }
          }
          full = Digest::SHA256.hexdigest(IdentityBytes.encode(record_without_id))
          loop_records << {
            'loop_id'    => PreparedCadDataset::LOOP_ID_PREFIX + full[0, 20],
            'full_digest' => full,
            'node_ids'   => record_without_id['node_ids'],
            'edge_ids'   => record_without_id['edge_ids'],
            'layer_name' => lh['layer_name'] || lh[:layer_name] || ''
          }
        end
        seen = {}
        loop_records.each do |lp|
          if seen.key?(lp['full_digest']) && seen[lp['full_digest']] != lp['loop_id']
            blockers << REASON_SEMANTIC_LOOP_AMBIGUITY
            break
          end
          seen[lp['full_digest']] = lp['loop_id']
        end
        loop_records.each { |lp| lp.delete('full_digest') }

        # ----- Regions --------------------------------------------------
        regions_in = structure_result[:regions] || structure_result['regions'] || []
        loop_id_lookup = {}
        loop_records.each do |lp|
          loop_id_lookup[lp['loop_id']] = lp
        end
        region_records = []
        Array(regions_in).each do |r|
          rh = r.is_a?(Hash) ? r : (r.respond_to?(:to_h) ? r.to_h : {})
          outer = rh['outer_loop_id'] || rh[:outer_loop_id]
          holes = Array(rh['hole_loop_ids'] || rh[:hole_loop_ids]).map(&:to_s)
          # Resolve the legacy loop IDs to semantic loop IDs.
          outer_semantic = _remap_loop_id(outer, legacy_node_to_pcn, legacy_edge_to_pce, loops_in, loop_records)
          holes_semantic = holes.map { |h| _remap_loop_id(h, legacy_node_to_pcn, legacy_edge_to_pce, loops_in, loop_records) }
          holes_semantic = holes_semantic.compact.uniq.sort
          record_without_id = {
            'outer_loop_id'   => outer_semantic,
            'hole_loop_ids'    => holes_semantic,
            'layer_name'       => rh['layer_name'] || rh[:layer_name] || '',
            'stable_source_refs' => _region_source_refs(rh),
            'unresolved_flags' => Array(rh['unresolved_flags'] || rh[:unresolved_flags]).map(&:to_s).sort.uniq
          }
          full = Digest::SHA256.hexdigest(IdentityBytes.encode(record_without_id))
          region_records << {
            'region_id' => PreparedCadDataset::REGION_ID_PREFIX + full[0, 20],
            'full_digest' => full,
            'outer_loop_id' => outer_semantic,
            'hole_loop_ids' => holes_semantic,
            'layer_name' => record_without_id['layer_name'],
            'stable_source_refs' => record_without_id['stable_source_refs'],
            'unresolved_flags' => record_without_id['unresolved_flags']
          }
        end
        seen = {}
        region_records.each do |r|
          if seen.key?(r['full_digest']) && seen[r['full_digest']] != r['region_id']
            blockers << REASON_SEMANTIC_REGION_AMBIGUITY
            break
          end
          seen[r['full_digest']] = r['region_id']
        end
        region_records.each { |r| r.delete('full_digest') }

        # Chain/loop/region IDs sorted by their respective IDs.
        chain_records.sort_by! { |c| c['chain_id'] }
        loop_records.sort_by!  { |lp| lp['loop_id'] }
        region_records.sort_by! { |r| r['region_id'] }

        # State pass-through.
        state = structure_result[:state] || structure_result['state']
        metrics = structure_result[:metrics] || structure_result['metrics'] || {}

        projection = {
          'schema_version' => 'pcd-semantic-structure.v1',
          'state'          => state.to_s,
          'chains'         => chain_records,
          'loops'          => loop_records,
          'regions'        => region_records,
          'metrics'        => metrics
        }
        [projection, blockers]
      end

      def _remap_chain_nodes(legacy_node_ids, legacy_node_to_pcn)
        legacy_node_ids.map { |id| legacy_node_to_pcn[id] || id }
      end

      def _remap_chain_edges(legacy_edge_ids, legacy_edge_to_pce)
        legacy_edge_ids.map { |id| legacy_edge_to_pce[id] || id }
      end

      def _alternating_sequence(node_ids, edge_ids)
        # Build [n0, e0, n1, e1, n2, ...].
        out = []
        m = [node_ids.length, edge_ids.length].min
        m.times do |i|
          out << node_ids[i]
          out << edge_ids[i]
        end
        # If there are more nodes than edges, append the tail.
        if node_ids.length > edge_ids.length
          out << node_ids.last
        end
        out
      end

      def _loop_rotations(seq)
        # 2N representations: N forward rotations + N reverse
        # orientations. Each must preserve edge-to-consecutive-
        # node alignment.
        n = seq.length
        return [seq] if n <= 2
        fwd = (0...n).map { |i| seq[i % n] }
        rev = fwd.reverse
        rotations = []
        n.times do |i|
          rotations << fwd[i..-1] + fwd[0...i]
        end
        n.times do |i|
          rotations << rev[i..-1] + rev[0...i]
        end
        rotations
      end

      def _remap_loop_id(legacy_loop_id, legacy_node_to_pcn, legacy_edge_to_pce,
                        legacy_loops, semantic_loops)
        return nil if legacy_loop_id.nil?
        legacy_loop_id = legacy_loop_id.to_s
        # Index: legacy loop record (loop.v1 form) carries
        # node_ids (cn-ids). Match by canonical identity bytes.
        legacy_loop = Array(legacy_loops).find do |lp|
          lh = lp.is_a?(Hash) ? lp : (lp.respond_to?(:to_h) ? lp.to_h : {})
          (lh['loop_id'] || lh[:loop_id]).to_s == legacy_loop_id
        end
        return nil unless legacy_loop
        lh = legacy_loop.is_a?(Hash) ? legacy_loop :
                (legacy_loop.respond_to?(:to_h) ? legacy_loop.to_h : {})
        legacy_node_ids = Array(lh['node_ids'] || lh[:node_ids]).map(&:to_s)
        legacy_edge_ids = Array(lh['edge_ids'] || lh[:edge_ids]).map(&:to_s)
        remap_nodes = _remap_chain_nodes(legacy_node_ids, legacy_node_to_pcn)
        remap_edges = _remap_chain_edges(legacy_edge_ids, legacy_edge_to_pce)
        base_seq = _alternating_sequence(remap_nodes, remap_edges)
        rotations = _loop_rotations(base_seq)
        chosen = rotations.min_by { |s| IdentityBytes.encode(s) }
        # Find the matching semantic loop record by node/edge ids.
        wanted = {
          'node_ids' => chosen.select { |t| t.start_with?(PreparedCadDataset::NODE_ID_PREFIX) },
          'edge_ids' => chosen.select { |t| t.start_with?(PreparedCadDataset::EDGE_ID_PREFIX) }
        }
        match = Array(semantic_loops).find do |sl|
          sl['node_ids'] == wanted['node_ids'] && sl['edge_ids'] == wanted['edge_ids']
        end
        match ? match['loop_id'] : nil
      end

      def _region_source_refs(region_hash)
        Array(region_hash['stable_source_refs'] ||
                region_hash[:stable_source_refs])
          .map { |s|
            if s.is_a?(Hash)
              { 'kind' => s['kind'] || s[:kind],
                'persistent_id_path' =>
                  Array(s['persistent_id_path'] || s[:persistent_id_path]).map(&:to_i) }
            else
              s.to_s
            end
          }
      end

      # ----- current issue projection -------------------------------------

      def _project_issues(analysis_result:, graph_projection:)
        blockers = []
        registry = analysis_result.respond_to?(:registry) ?
                     analysis_result.registry : nil
        issues = registry && registry.respond_to?(:issues) ?
                   Array(registry.issues) : []
        # Build pcn lookup for resolution.
        pcn_by_xy_clique = {}
        Array(graph_projection['nodes']).each do |n|
          xyz = n['xyz']
          key = IdentityBytes.encode(xyz)
          pcn_by_xy_clique[key] = n['node_id']
        end
        # Build analysis edge id -> pce via source_occurrence_ids.
        # The graph exposes source_occurrence_ids per edge.
        pce_by_sref = {}
        Array(graph_projection['edges']).each do |e|
          Array(e['source_occurrence_ids']).each do |s|
            pce_by_sref[s.to_s] = e['edge_id']
          end
        end

        projected = []
        Array(issues).each do |iss|
          issue_type = (iss[:issue_type] || iss['issue_type']).to_s
          next unless SECONDARY_WARNING_TYPES.include?(issue_type)
          refs = []
          # Resolve pcd_node refs from location.
          loc = iss[:location]
          if loc.is_a?(Array) && loc.length == 3
            key = IdentityBytes.encode(loc.map(&:to_f))
            pid = pcn_by_xy_clique[key]
            refs << { 'kind' => 'pcd_node', 'id' => pid } if pid
          end
          # Resolve pcd_edge refs from source_occurrence_ids.
          Array(iss[:source_entity_ids]).each do |sid|
            pid = pce_by_sref[sid.to_s]
            refs << { 'kind' => 'pcd_edge', 'id' => pid } if pid
          end
          # Resolve complete source_pid_path refs.
          Array(iss[:sources]).each do |src|
            next unless src.is_a?(Hash)
            pp = Array(src[:persistent_id_path] || src['persistent_id_path'])
            if src[:pid_path_complete] && !pp.empty?
              refs << { 'kind' => 'source_pid_path',
                        'persistent_id_path' => pp.map(&:to_i) }
            end
          end
          # Drop refs with nil id.
          refs = refs.reject { |r| r['id'].nil? }
          projected << {
            'issue_type' => issue_type,
            'severity'   => iss[:severity].to_s,
            'confidence' => iss[:confidence],
            'refs'       => refs,
            'message'    => iss[:message].to_s
          }
        end
        # Sort by identity bytes.
        projected.sort_by! { |i| IdentityBytes.encode(i) }

        # Also surface counts.
        counts = Hash.new(0)
        projected.each { |i| counts[i['issue_type']] += 1 }

        projection = {
          'schema_version' => 'pcd-current-issues.v1',
          'issues'         => projected,
          'counts'         => counts
        }
        [projection, blockers]
      end

      # ----- Analysis <-> Source coherence projection ----------------------

      def _compute_coherence_digest(source_snapshot:, analysis_result:)
        blockers = []
        # Build source-side coherence multiset from SourceSnapshot
        # edges / faces / layers.
        source_edges = source_snapshot.respond_to?(:edges) ?
                         Array(source_snapshot.edges) : []
        source_faces = source_snapshot.respond_to?(:faces) ?
                         Array(source_snapshot.faces) : []
        source_layers = source_snapshot.respond_to?(:layers) ?
                          Array(source_snapshot.layers) : []

        source_edge_descs = source_edges.map do |e|
          s = _endpoint_xyz(e.start_point)
          t = _endpoint_xyz(e.end_point)
          ref = _coherence_source_ref(e.source)
          layer = e.respond_to?(:layer) ? e.layer.to_s : ''
          {
            'kind' => 'edge',
            'canonical_endpoints' => (s && t) ? _canonical_edge_endpoints(s, t) : nil,
            'layer_name' => layer,
            'coherence_source_ref' => ref
          }
        end.compact
        source_edge_descs.sort_by! { |d| IdentityBytes.encode(d) }

        source_face_descs = source_faces.map do |f|
          ref = _coherence_source_ref(f.source)
          {
            'kind' => 'face',
            'layer_name' => f.respond_to?(:layer) ? f.layer.to_s : '',
            'outer_loop_vertex_count' => f.respond_to?(:outer_loop_vertex_count) ?
                                           f.outer_loop_vertex_count.to_i : 0,
            'inner_loop_count' => f.respond_to?(:inner_loop_count) ?
                                    f.inner_loop_count.to_i : 0,
            'coherence_source_ref' => ref
          }
        end
        source_face_descs.sort_by! { |d| IdentityBytes.encode(d) }

        source_layer_descs = source_layers.map do |l|
          {
            'name' => l.respond_to?(:name) ? l.name.to_s : '',
            'role' => (l.respond_to?(:role) ?
                        (l.role.is_a?(Symbol) ? l.role.to_s : l.role.to_s) : 'UNKNOWN'),
            'role_rule' => l.respond_to?(:role_rule) ? (l.role_rule ? l.role_rule.to_s : nil) : nil,
            'visible' => l.respond_to?(:visible) ? (l.visible ? true : false) : true,
            'visibility_unknown' => l.respond_to?(:visibility_unknown) ?
                                      (l.visibility_unknown ? true : false) : false,
            'edge_count' => l.respond_to?(:edge_count) ? l.edge_count.to_i : 0,
            'face_count' => l.respond_to?(:face_count) ? l.face_count.to_i : 0,
            'faces_with_holes_count' => l.respond_to?(:faces_with_holes_count) ?
                                          l.faces_with_holes_count.to_i : 0
          }
        end
        source_layer_descs.sort_by! { |d| IdentityBytes.encode(d) }

        # Analysis side: read geometry_snapshot from
        # AnalysisResult (V1.4 directive 030).
        analysis_edges = []
        analysis_faces = []
        analysis_layers = []
        geom = analysis_result.respond_to?(:geometry_snapshot) ?
                 analysis_result.geometry_snapshot : nil
        if geom && geom.respond_to?(:edges)
          Array(geom.edges).each do |e|
            ref = _coherence_source_ref(e.respond_to?(:source) ? e.source : nil)
            s = _endpoint_xyz(e.start_point)
            t = _endpoint_xyz(e.end_point)
            analysis_edges << {
              'kind' => 'edge',
              'canonical_endpoints' => (s && t) ? _canonical_edge_endpoints(s, t) : nil,
              'layer_name' => e.respond_to?(:layer) ? e.layer.to_s : '',
              'coherence_source_ref' => ref
            }
          end
        end
        if geom && geom.respond_to?(:faces)
          Array(geom.faces).each do |f|
            ref = _coherence_source_ref(f.respond_to?(:source) ? f.source : nil)
            analysis_faces << {
              'kind' => 'face',
              'layer_name' => f.respond_to?(:layer) ? f.layer.to_s : '',
              'outer_loop_vertex_count' => f.respond_to?(:outer_loop_vertex_count) ?
                                             f.outer_loop_vertex_count.to_i : 0,
              'inner_loop_count' => f.respond_to?(:inner_loop_count) ?
                                      f.inner_loop_count.to_i : 0,
              'coherence_source_ref' => ref
            }
          end
        end
        if geom && geom.respond_to?(:layers)
          Array(geom.layers).each do |l|
            analysis_layers << {
              'name' => l.respond_to?(:name) ? l.name.to_s : '',
              'role' => (l.respond_to?(:role) ?
                          (l.role.is_a?(Symbol) ? l.role.to_s : l.role.to_s) : 'UNKNOWN'),
              'role_rule' => l.respond_to?(:role_rule) ? (l.role_rule ? l.role_rule.to_s : nil) : nil,
              'visible' => l.respond_to?(:visible) ? (l.visible ? true : false) : true,
              'visibility_unknown' => l.respond_to?(:visibility_unknown) ?
                                        (l.visibility_unknown ? true : false) : false,
              'edge_count' => l.respond_to?(:edge_count) ? l.edge_count.to_i : 0,
              'face_count' => l.respond_to?(:face_count) ? l.face_count.to_i : 0,
              'faces_with_holes_count' => l.respond_to?(:faces_with_holes_count) ?
                                            l.faces_with_holes_count.to_i : 0
            }
          end
        end
        analysis_edges.sort_by! { |d| IdentityBytes.encode(d) }
        analysis_faces.sort_by!  { |d| IdentityBytes.encode(d) }
        analysis_layers.sort_by! { |d| IdentityBytes.encode(d) }

        # Source digest (use ALL records).
        source_digest = Digest::SHA256.hexdigest(
          IdentityBytes.encode({
            'edges' => source_edge_descs,
            'faces' => source_face_descs,
            'layers' => source_layer_descs
          })
        )
        analysis_digest = Digest::SHA256.hexdigest(
          IdentityBytes.encode({
            'edges' => analysis_edges,
            'faces' => analysis_faces,
            'layers' => analysis_layers
          })
        )

        unless source_digest == analysis_digest
          blockers << REASON_COHERENCE_DIGEST_MISMATCH
          return [nil, blockers]
        end

        # ----- Registry edge ID resolution (v1.3 §10.5) -----------------
        analysis_edge_by_id = {}
        if geom && geom.respond_to?(:edges)
          Array(geom.edges).each do |e|
            id = e.respond_to?(:id) ? e.id : nil
            analysis_edge_by_id[id.to_s] = e if id
          end
        end
        registry = analysis_result.registry
        registry_issues = registry && registry.respond_to?(:issues) ?
                            Array(registry.issues) : []
        registry_issues.each do |iss|
          edge_ids = Array(iss[:edge_ids]).map(&:to_s)
          next if edge_ids.empty?
          edge_ids.each do |eid|
            unless analysis_edge_by_id.key?(eid)
              blockers << REASON_REGISTRY_EDGE_MISSING + ":edge_id=#{eid}"
              break
            end
          end
          break unless blockers.empty?
          # Each referenced analysis edge's coherence descriptor
          # must exist in the source edge multiset.
          edge_ids.each do |eid|
            ae = analysis_edge_by_id[eid]
            desc = {
              'kind' => 'edge',
              'canonical_endpoints' => (ae.start_point && ae.end_point) ?
                                          _canonical_edge_endpoints(
                                            _endpoint_xyz(ae.start_point),
                                            _endpoint_xyz(ae.end_point)) : nil,
              'layer_name' => ae.respond_to?(:layer) ? ae.layer.to_s : '',
              'coherence_source_ref' => _coherence_source_ref(ae.respond_to?(:source) ? ae.source : nil)
            }
            unless source_edge_descs.include?(desc)
              blockers << REASON_REGISTRY_EDGE_NOT_IN_SOURCE + ":edge_id=#{eid}"
              break
            end
          end
          break unless blockers.empty?
        end

        return [nil, blockers] unless blockers.empty?
        [source_digest, blockers]
      end

      def _coherence_source_ref(source_ref)
        return { 'kind' => 'unresolved' } if source_ref.nil?
        return { 'kind' => 'unresolved' } unless source_ref.is_a?(SourceReference)
        if source_ref.pid_path_complete
          pp = Array(source_ref.persistent_id_path)
          unless pp.empty?
            return {
              'kind' => 'stable_pid',
              'persistent_id_path' => pp.map(&:to_i)
            }
          end
        end
        if source_ref.respond_to?(:entity_id) && source_ref.entity_id
          return {
            'kind' => 'transient_entity',
            'entity_id' => source_ref.entity_id.to_i
          }
        end
        { 'kind' => 'unresolved' }
      end

      # ----- build_evidence assembly --------------------------------------

      def _build_evidence(source_snapshot:, workflow_snapshot:,
                          topology_snapshot:, canonical_graph:,
                          structure_result:, analysis_result:)
        ec = source_snapshot.respond_to?(:execution_config) ?
               source_snapshot.execution_config : nil
        fp = source_snapshot.respond_to?(:fingerprint) ?
               source_snapshot.fingerprint : nil
        ws_id = canonical_graph.respond_to?(:workspace_id) ?
                  canonical_graph.workspace_id.to_s : ''
        # Legacy source fingerprint digest.
        fp_digest = (fp && fp.respond_to?(:digest)) ? fp.digest.to_s : ''
        # Legacy graph digest (cgg.v1).
        graph_dgst = canonical_graph.respond_to?(:digest) ?
                       canonical_graph.digest.to_s : ''
        # Legacy structure digest (csr.v1 digest).
        struct_dgst = (structure_result[:digest] ||
                       structure_result['digest']).to_s
        # Captured_at.
        cap = ''
        if source_snapshot.respond_to?(:captured_at)
          cap = source_snapshot.captured_at.to_s
        end
        # selection_scope (raw).
        sel = source_snapshot.respond_to?(:selection_scope) ?
                source_snapshot.selection_scope : []
        # topology legacy mapping.
        topo_legacy = {
          'schema_version' => (topology_snapshot[:schema_version] ||
                                topology_snapshot['schema_version']).to_s,
          'canonical_node_count' => Array(topology_snapshot[:canonical_nodes] ||
                                           topology_snapshot['canonical_nodes']).length,
          'endpoint_count' => Array(topology_snapshot[:endpoints] ||
                                     topology_snapshot['endpoints']).length
        }
        # Workflow readiness (snapshot only; readiness itself is
        # validated separately in §11 of the dispatch).
        workflow_state = (workflow_snapshot[:state] ||
                          workflow_snapshot['state']).to_s
        planar_sub = workflow_snapshot[:planar_normalization] ||
                       workflow_snapshot['planar_normalization'] || {}
        gap_sub = workflow_snapshot[:topology_repair] ||
                    workflow_snapshot['topology_repair'] || {}
        struct_sub = workflow_snapshot[:structure_reconstruction] ||
                       workflow_snapshot['structure_reconstruction'] || {}
        evidence = {
          'schema_version'              => 'pcd-build-evidence.v1',
          'source_snapshot_id'          => source_snapshot.snapshot_id.to_s,
          'workspace_id'                => ws_id,
          'captured_at'                 => cap,
          'legacy_source_fingerprint_digest' => fp_digest,
          'legacy_canonical_graph_digest' => graph_dgst,
          'legacy_structure_digest'     => struct_dgst,
          'workflow_state'              => workflow_state,
          'workflow_planar'             => _stringify_workflow_sub(planar_sub),
          'workflow_gap'                => _stringify_workflow_sub(gap_sub),
          'workflow_structure'          => _stringify_workflow_sub(struct_sub),
          'selection_scope'             => sel,
          'topology_legacy'             => topo_legacy
        }
        evidence
      end

      def _stringify_workflow_sub(value)
        return {} unless value.is_a?(Hash)
        out = {}
        value.each do |k, v|
          ks = k.is_a?(Symbol) ? k.to_s : k
          out[ks] = v.is_a?(Hash) ? v.each_with_object({}) { |(kk, vv), h|
                                  h[kk.to_s] = vv
                                } : v
        end
        out
      end

      def _blocked(blockers)
        { 'status' => STATUS_BLOCKED, 'dataset' => nil,
          'blockers' => Array(blockers).uniq.sort }
      end
    end
  end
end
