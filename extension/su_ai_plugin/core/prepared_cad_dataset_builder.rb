#
# core/prepared_cad_dataset_builder.rb �?V1.9B1 B1.3 Pure Builder.
#
# Per frozen V1.9B1 Blueprint v1.3 (authoritative over v1.2)
# AND AIPM V1.9B1 B1.2-B1.4 Source Review Correction 2026-09-14:
#
#   PreparedCadDatasetBuilder is a PURE builder. It accepts
#   only EXPLICIT INPUTS:
#
#     source_snapshot    : SourceSnapshot (V1.4 immutable wrapper)
#     workflow_snapshot  : Hash<String, ...> (the B1-owned
#                          normalized view of the working-mode
#                          runner snapshot)
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
#   Source Review Correction contracts implemented here:
#     B1-SR-02: full source_content_digest + execution_context_digest
#     B1-SR-03: graph schema, structure schema, source schema
#               binding, exact topology endpoint equality,
#               topology canonical-node membership equality,
#               membership_count + resolved_clique agreement,
#               epsilon equality, tolerance_digest recompute,
#               execution_config_digest check, workflow digest
#               binding.
#     B1-SR-04: incomplete PID coherence includes kind,
#               structural_depth, persistent_id_path,
#               instance_path, entity_id, persistent_id,
#               layer_name. Nested structural_depth > 0 requires
#               non-empty valid UTF-8 instance_path.
#     B1-SR-05: stable source occurrence resolver is an
#               instance-bound helper (no module-global
#               memoization across builds).
#     B1-SR-06: endpoint_keys and legacy/transient addressing
#               IDs stay OUT of semantic content; semantic
#               repair IDs use only stable repair facts;
#               legacy repair/action/proposal IDs are build
#               evidence only.
#     B1-SR-07: full SHA-256 node labels throughout; iterate
#               until stable OR node_count rounds; pcn- +
#               first20(final full label), no extra rehash.
#     B1-SR-08: chain aligned forward/reverse; loop exactly
#               2*N node-starting representations (N forward
#               rotations + N reverse orientations); semantic
#               ID ambiguity BLOCKED; truncated prefix
#               collision maps for pch/pcl/pcr/pcrp;
#               injectable digest seam to force prefix
#               collisions in tests.
#     B1-SR-09: dataset_id_truncation_collision via a build
#               context map (dataset_id -> full digest).
#
#   Return:
#     Success:
#       { status: 'BUILT', dataset: <candidate PreparedCadDataset> }
#     Coherence / design failure:
#       { status: 'BLOCKED', dataset: nil, blockers: [String, ...] }
#
#   The Builder does NOT use 'NOT_READY' �?that readiness
#   verdict belongs to the Validator.
#

require 'digest'
require 'json'

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
      SEMANTIC_STRUCTURE_SCHEMA      = 'pcd-semantic-structure.v1'.freeze
      COHERENCE_PROJECTION_SCHEMA    = 'pcd-coherence.v1'.freeze
      CURRENT_ISSUES_SCHEMA          = 'pcd-current-issues.v1'.freeze
      ACTIVE_EDIT_SCHEMA             = 'pcd-active-edit.v1'.freeze

      # The fixed execution tolerance key set (v1.2 + v1.3).
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

      # ----- Stable blocker codes ----------------------------------------
      REASON_NOT_A_HASH                 = 'input_not_a_hash'.freeze
      REASON_MISSING_INPUT              = 'missing_input'.freeze
      REASON_WORKFLOW_STATE_NOT_READY   = 'workflow_state_not_ready'.freeze
      REASON_TOPOLOGY_SCHEMA_MISMATCH   = 'topology_schema_mismatch'.freeze
      REASON_TOPOLOGY_MISSING_ENDPOINTS = 'topology_endpoints_missing'.freeze
      REASON_TOPOLOGY_DUPLICATE_KEY     = 'topology_duplicate_endpoint_key'.freeze
      REASON_TOPOLOGY_BAD_COORDINATE    = 'topology_bad_endpoint_coordinate'.freeze
      REASON_TOPOLOGY_BAD_CANONICAL     = 'topology_bad_canonical_node'.freeze
      REASON_TOPOLOGY_CANONICAL_GROUP_MISMATCH =
        'topology_canonical_node_membership_mismatch'.freeze
      REASON_GRAPH_SCHEMA_MISMATCH      = 'graph_schema_mismatch'.freeze
      REASON_GRAPH_ENDPOINT_MISMATCH    = 'graph_topology_endpoint_set_mismatch'.freeze
      REASON_GRAPH_NODE_MEMBERSHIP_MISMATCH = 'graph_node_topology_membership_mismatch'.freeze
      REASON_GRAPH_NODE_MEMBERSHIP_COUNT_MISMATCH = 'graph_node_membership_count_mismatch'.freeze
      REASON_GRAPH_NODE_CLIQUE_FLAG_MISMATCH    = 'graph_node_resolved_clique_mismatch'.freeze
      REASON_STRUCTURE_SCHEMA_MISMATCH  = 'structure_schema_mismatch'.freeze
      REASON_STRUCTURE_DIGEST_MISSING   = 'structure_canonical_graph_digest_missing'.freeze
      REASON_STRUCTURE_GRAPH_DIGEST_MISMATCH =
        'structure_canonical_graph_digest_mismatch'.freeze
      REASON_SNAPSHOT_ID_MISMATCH       = 'snapshot_id_mismatch'.freeze
      REASON_WORKSPACE_ID_MISMATCH      = 'workspace_id_mismatch'.freeze
      REASON_SOURCE_SCHEMA_MISMATCH     = 'source_snapshot_schema_version_mismatch'.freeze
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
      REASON_SEMANTIC_REPAIR_AMBIGUITY  = 'semantic_repair_ambiguity'.freeze
      REASON_DATASET_ID_TRUNCATION_COLLISION =
        'dataset_id_truncation_collision'.freeze
      REASON_SEMANTIC_ID_TRUNCATION_COLLISION =
        'semantic_id_truncation_collision'.freeze
      REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS =
        'ambiguous_incomplete_occurrence'.freeze
      REASON_ANALYSIS_RESULT_INVALID    = 'analysis_result_invalid'.freeze
      REASON_INPUT_SHAPE                = 'input_shape_invalid'.freeze
      REASON_GRAPH_TOLERANCE_DIGEST_MISMATCH = 'graph_tolerance_digest_mismatch'.freeze
      REASON_GRAPH_EXECUTION_CONFIG_DIGEST_MISMATCH =
        'graph_execution_config_digest_mismatch'.freeze
      REASON_GRAPH_TOLERANCE_UNREADABLE = 'graph_tolerance_digest_unreadable'.freeze

      # ----- Public API --------------------------------------------------

      def build(source_snapshot:, workflow_snapshot:,
                topology_snapshot:, canonical_graph:,
                structure_result:, analysis_result:,
                truncation_context: nil)
        # FR-01: every public build gets a fresh per-build
        # truncation collision context. Production correctness
        # NEVER depends on Thread.current / module-global /
        # process-global state. The optional `truncation_context`
        # keyword arg is a TEST-ONLY seam; when supplied, it
        # is used (and possibly mutated) as the per-build
        # collision registry for that single call only.
        truncation_context = truncation_context.nil? ? {} : truncation_context

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
        return _blocked(blockers, truncation_context) unless blockers.empty?

        # ----- workflow state gate -----------------------------------------
        blockers.concat(_check_workflow_state(workflow_snapshot))

        # ----- cross-input ID / digest gates (B1-SR-03) ------------------
        blockers.concat(_check_cross_ids(
          source_snapshot: source_snapshot,
          workflow_snapshot: workflow_snapshot,
          topology_snapshot: topology_snapshot,
          canonical_graph: canonical_graph,
          structure_result: structure_result
        ))

        # ----- source schema binding (B1-SR-03) --------------------------
        blockers.concat(_check_source_schema(
          source_snapshot: source_snapshot,
          workflow_snapshot: workflow_snapshot
        ))

        # ----- graph tolerance_digest binding (B1-SR-03 §1.3) ------------
        blockers.concat(_check_graph_tolerance_digest(canonical_graph, source_snapshot: source_snapshot))

        # ----- graph execution_config_digest binding (B1-SR-03 §1.4) -----
        blockers.concat(_check_graph_execution_config_digest(canonical_graph))

        # ----- workflow digest binding (B1-SR-03 §1.5) -------------------
        blockers.concat(_check_workflow_digests(
          source_snapshot: source_snapshot,
          workflow_snapshot: workflow_snapshot,
          canonical_graph: canonical_graph,
          structure_result: structure_result
        ))

        # ----- tolerance / execution normalization ------------------------
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

        return _blocked(blockers, truncation_context) unless blockers.empty?

        # ----- semantic source projection --------------------------------
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

        # ----- B1-SR-02: source_content_digest + execution_context_digest
        # Hex digests are returned by _sha256_hex
        # as US-ASCII. Coerce to UTF-8 at the producer
        # (FR-08 digest-only normalization) so the strict
        # encoder in compute_content_digest accepts them.
        source_content_digest = PreparedCadDataset.send(
          :_digest_only_utf8_normalize,
          _sha256_hex(_encode_normalized(source_projection))
        )
        execution_context_digest = PreparedCadDataset.send(
          :_digest_only_utf8_normalize,
          _sha256_hex(_encode_normalized(execution_projection))
        )

        # ----- semantic geometry remap -------------------------------------
        # R2-01: the per-build truncation_context MUST be
        # threaded through `_remap_graph` so `_semantic_repair_id`
        # can register / detect pcrp truncated-prefix collisions.
        graph_projection, graph_blockers, legacy_maps = _remap_graph(
          topology_snapshot: topology_snapshot,
          canonical_graph: canonical_graph,
          normalized_tolerance: normalized_tolerance,
          source_projection: source_projection,
          truncation_context: truncation_context
        )
        blockers.concat(graph_blockers)

        return _blocked(blockers, truncation_context) if graph_projection.nil?

        # ----- semantic structure remap ------------------------------------
        structure_projection, struct_blockers = _remap_structure(
          structure_result: structure_result,
          graph_projection: graph_projection,
          legacy_node_to_pcn: legacy_maps[:node],
          legacy_edge_to_pce: legacy_maps[:edge],
          source_projection: source_projection,
          truncation_context: truncation_context
        )
        blockers.concat(struct_blockers)

        # ----- current issue / readiness projection ------------------------
        issue_projection, issue_blockers = _project_issues(
          analysis_result: analysis_result,
          graph_projection: graph_projection
        )
        blockers.concat(issue_blockers)

        return _blocked(blockers, truncation_context) unless blockers.empty?

        # ----- coherence evidence ------------------------------------------
        coherence_digest, coh_blockers = _compute_coherence_digest(
          source_snapshot: source_snapshot,
          analysis_result: analysis_result,
          source_projection: source_projection
        )
        blockers.concat(coh_blockers)
        return _blocked(blockers, truncation_context) if coherence_digest.nil?

        # ----- assemble semantic content ------------------------------------
        content = {
          'schema_version'             => PCD_SCHEMA_VERSION,
          'source_content_digest'      => source_content_digest,
          'execution_context_digest'   => execution_context_digest,
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

        # ----- compute final digests (B1-SR-01) ----------------------------
        cd = PreparedCadDataset.compute_content_digest(content)
        ds_id = PreparedCadDataset.compute_dataset_id(cd)

        # ----- B1-SR-09 truncated-ID collision check -----------------------
        if truncation_context.key?(ds_id)
          existing_full = truncation_context[ds_id][:full_content_digest]
          if existing_full != cd
            blockers << REASON_DATASET_ID_TRUNCATION_COLLISION +
                            ":same_id_distinct_full_digest"
            return _blocked(blockers, truncation_context)
          end
        end
        truncation_context[ds_id] = {
          :full_content_digest => cd,
          :semantic_record     => content
        }

        bed = PreparedCadDataset.compute_build_evidence_digest(cd, build_evidence)

        candidate = PreparedCadDataset.build_candidate(
          content: content,
          content_digest: cd,
          build_evidence: build_evidence,
          build_evidence_digest: bed
        )
        { 'status' => STATUS_BUILT, 'dataset' => candidate,
          'truncation_context' => truncation_context }
      end

      # ----- Truncation context (B1-SR-05 / B1-SR-09) --------------------
      #
      # Per-build, instance-bound context mapping every
      # computed truncated semantic ID (dataset_id, pcn-, pce-,
      # pch-, pcl-, pcr-, pcrp-) to its full digest +
      # semantic record. Used to enforce "same truncated prefix
      # + different full digest => BLOCKED".
      #
      # This is exposed so test code can inspect / pre-seed the
      # context for forced-collision scenarios, but it lives as
      # a local Thread-keyed map to avoid leaking across builds.

      def _truncation_context
        Thread.current[:_pcd_truncation_ctx] ||=
          Hash.new { |h, k| h[k] = nil }
      end

      def _reset_truncation_context!
        Thread.current[:_pcd_truncation_ctx] = nil
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

      # ----- cross-input ID / digest gates (B1-SR-03) --------------------

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
        # B1-SR-03: structure canonical_graph_digest is REQUIRED.
        if struct_graph_dgst.nil? || struct_graph_dgst.empty?
          blockers << REASON_STRUCTURE_DIGEST_MISSING
        elsif struct_graph_dgst != graph_dgst
          blockers << REASON_STRUCTURE_GRAPH_DIGEST_MISMATCH
        end

        # ----- graph schema check (B1-SR-03) ---------------------------
        graph_schema = canonical_graph.respond_to?(:schema_version) ?
                         canonical_graph.schema_version.to_s : ''
        if graph_schema != 'cgg.v1'
          blockers << REASON_GRAPH_SCHEMA_MISMATCH + ":got=#{graph_schema}"
        end

        # ----- structure schema check (B1-SR-03) ------------------------
        struct_schema = (structure_result[:schema_version] ||
                         structure_result['schema_version']).to_s
        if struct_schema != 'csr.v1'
          blockers << REASON_STRUCTURE_SCHEMA_MISMATCH + ":got=#{struct_schema}"
        end

        # ----- topology schema check (B1-SR-03 §1.1) --------------------
        topo_schema = (topology_snapshot[:schema_version] ||
                       topology_snapshot['schema_version']).to_s
        if topo_schema != 'cano-node.v1'
          blockers << REASON_TOPOLOGY_SCHEMA_MISMATCH + ":got=#{topo_schema}"
        end
        blockers
      end

      # ----- source schema binding (B1-SR-03) -----------------------------

      def _check_source_schema(source_snapshot:, workflow_snapshot:)
        blockers = []
        ss_schema = source_snapshot.respond_to?(:schema_version) ?
                      source_snapshot.schema_version.to_s : ''
        # The execution.source_snapshot_schema_version is the
        # authoritative source schema reference for the builder.
        # We look it up in the workflow_snapshot (it may be
        # present directly, or we ask the source snapshot's
        # execution_config).
        ref_schema = nil
        ec = source_snapshot.respond_to?(:execution_config) ?
                source_snapshot.execution_config : nil
        if ec && ec.respond_to?(:source_snapshot_schema_version)
          ref_schema = ec.source_snapshot_schema_version.to_s
        end
        if ref_schema.nil? || ref_schema.empty?
          ref_schema = (workflow_snapshot['source_snapshot_schema_version'] ||
                        workflow_snapshot[:source_snapshot_schema_version]).to_s
        end
        if ref_schema.nil? || ref_schema.empty?
          # No reference schema available: cannot prove
          # coherence; fail closed.
          blockers << REASON_SOURCE_SCHEMA_MISMATCH + ':no_reference'
        elsif ss_schema != ref_schema
          blockers << REASON_SOURCE_SCHEMA_MISMATCH +
                          ":got=#{ss_schema}:want=#{ref_schema}"
        end
        blockers
      end

      # ----- graph tolerance_digest (B1-SR-03 §1.3) -----------------------

      def _check_graph_tolerance_digest(canonical_graph, source_snapshot: nil)
        blockers = []
        # FR-02: missing tolerance_digest seam is BLOCKED, not
        # silently bypassed.
        unless canonical_graph.respond_to?(:tolerance_digest)
          blockers << REASON_GRAPH_TOLERANCE_UNREADABLE +
                          ':graph_missing_tolerance_digest_seam'
          return blockers
        end
        published_digest = canonical_graph.tolerance_digest.to_s
        if published_digest.empty?
          blockers << REASON_GRAPH_TOLERANCE_UNREADABLE +
                          ':graph_tolerance_digest_empty'
          return blockers
        end
        ec = nil
        if source_snapshot && source_snapshot.respond_to?(:execution_config)
          ec = source_snapshot.execution_config
        end
        if ec.nil? && canonical_graph.respond_to?(:execution_config)
          ec = canonical_graph.execution_config
        end
        raw = ec && ec.respond_to?(:tolerance_values) ?
                ec.tolerance_values : nil
        if raw.nil?
          blockers << REASON_GRAPH_TOLERANCE_UNREADABLE +
                          ':raw_tolerance_unreadable'
          return blockers
        end
        # Recompute from raw tolerance_values per Blueprint v1.3
        # §1.3 (matches the actual canonical_geometry_graph.rb
        # computation: Marshal.dump of Hash#sort.to_h).
        begin
          expected = 'tol-' + _sha256_hex(
            Marshal.dump(raw.is_a?(Hash) ? raw.sort.to_h : {})
          )[0, 16]
        rescue StandardError
          blockers << REASON_GRAPH_TOLERANCE_UNREADABLE + ':recompute_failed'
          return blockers
        end
        if expected != published_digest
          blockers << REASON_GRAPH_TOLERANCE_DIGEST_MISMATCH +
                          ":got=#{published_digest}:want=#{expected}"
        end
        blockers
      end

      # ----- graph execution_config_digest (B1-SR-03 §1.4) ---------------

      def _check_graph_execution_config_digest(canonical_graph)
        blockers = []
        # FR-02: missing execution_config_digest seam is BLOCKED.
        unless canonical_graph.respond_to?(:execution_config_digest)
          blockers << REASON_GRAPH_EXECUTION_CONFIG_DIGEST_MISMATCH +
                          ':graph_missing_execution_config_digest_seam'
          return blockers
        end
        published = canonical_graph.execution_config_digest.to_s
        # Current ExecutionConfigSnapshot has no public digest.
        # Per Blueprint v1.3 §1.4, the normal current production
        # value is "".
        expected = ''
        if expected != published
          blockers << REASON_GRAPH_EXECUTION_CONFIG_DIGEST_MISMATCH +
                          ":got=#{published}:want=#{expected}"
        end
        blockers
      end

      # ----- workflow digest binding (B1-SR-03 §1.5) ---------------------

      def _check_workflow_digests(source_snapshot:, workflow_snapshot:,
                                  canonical_graph:, structure_result:)
        blockers = []
        graph_dgst = canonical_graph.respond_to?(:digest) ?
                       canonical_graph.digest.to_s : ''
        struct_dgst = (structure_result[:digest] ||
                       structure_result['digest']).to_s

        # workflow may publish graph_digest / structure_digest as
        # evidence (optional fields). When present they MUST
        # match. When absent, that part of the evidence is
        # missing �?we treat as fail-closed per Blueprint v1.3
        # §1.5.
        wf_graph_dgst = (workflow_snapshot['graph_digest'] ||
                         workflow_snapshot[:graph_digest])
        if wf_graph_dgst && !wf_graph_dgst.to_s.empty?
          if wf_graph_dgst.to_s != graph_dgst
            blockers << REASON_STRUCTURE_GRAPH_DIGEST_MISMATCH +
                            ':workflow_graph_digest'
          end
        end
        wf_struct_dgst = (workflow_snapshot['structure_digest'] ||
                          workflow_snapshot[:structure_digest])
        if wf_struct_dgst && !wf_struct_dgst.to_s.empty?
          if wf_struct_dgst.to_s != struct_dgst
            blockers << REASON_STRUCTURE_GRAPH_DIGEST_MISMATCH +
                            ':workflow_structure_digest'
          end
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
        return [nil, [REASON_TOLERANCE_MISSING_KEY + ':raw_unreadable']] if raw.nil?
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
        topo_eps_raw = topology_snapshot[:coordinate_epsilon] ||
                         topology_snapshot['coordinate_epsilon']
        topo_eps = topo_eps_raw.respond_to?(:to_f) ? topo_eps_raw.to_f : nil
        # FR-02: malformed topology epsilon must BLOCK, never
        # raise on nil.finite?.
        unless topo_eps.is_a?(Numeric) && topo_eps.finite? && topo_eps > 0 && topo_eps == tol_eps
          blockers << REASON_EPSILON_MISMATCH + ':topology_vs_tolerance'
        end
        # Every graph-node coordinate_epsilon must agree when present.
        graph_nodes = canonical_graph.respond_to?(:nodes) ? Array(canonical_graph.nodes) : []
        graph_nodes.each do |n|
          nh = n.is_a?(Hash) ? n : (n.respond_to?(:to_h) ? n.to_h : {})
          ge = nh['coordinate_epsilon']
          if !ge.nil?
            ge_f = ge.respond_to?(:to_f) ? ge.to_f : nil
            unless ge_f.is_a?(Numeric) && ge_f.finite? && ge_f == tol_eps
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
          # B1-SR-12 strict UTF-8.
          unless value.respond_to?(:encoding) && value.encoding.name == 'UTF-8' &&
                 value.valid_encoding?
            raise ArgumentError, "invalid / non-UTF-8 session_override String"
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
          layer_name = _to_utf8(e.respond_to?(:layer) ? e.layer : '')
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
        edge_descs.sort_by! { |d| _encode_normalized(d) } if blockers.empty?

        face_descs = faces_in.map do |f|
          unless f.respond_to?(:source) && f.source.is_a?(SourceReference)
            blockers << REASON_INPUT_SHAPE + ':face_source'
            break
          end
          ref = _stable_source_ref(f.source)
          {
            'kind'                    => 'face',
            'layer_name'              => _to_utf8(f.respond_to?(:layer) ? f.layer : ''),
            'outer_loop_vertex_count' => f.respond_to?(:outer_loop_vertex_count) ?
                                           f.outer_loop_vertex_count.to_i : 0,
            'inner_loop_count'        => f.respond_to?(:inner_loop_count) ?
                                           f.inner_loop_count.to_i : 0,
            'stable_source_ref'       => ref
          }
        end
        face_descs.sort_by! { |d| _encode_normalized(d) } if blockers.empty?

        layer_descs = layers_in.map do |l|
          role_raw = l.respond_to?(:role) ? l.role : nil
          {
            'layer_name'           => _to_utf8(l.respond_to?(:name) ? l.name : ''),
            'role'                 => _to_utf8(role_raw.is_a?(Symbol) ? role_raw.to_s :
                                                  (role_raw || 'UNKNOWN')),
            'role_rule'            => (l.respond_to?(:role_rule) && l.role_rule) ?
                                        _to_utf8(l.role_rule) : nil,
            'visible'              => l.respond_to?(:visible) ? (l.visible ? true : false) : true,
            'visibility_unknown'   => l.respond_to?(:visibility_unknown) ?
                                        (l.visibility_unknown ? true : false) : false,
            'edge_count'           => l.respond_to?(:edge_count) ? l.edge_count.to_i : 0,
            'face_count'           => l.respond_to?(:face_count) ? l.face_count.to_i : 0,
            'faces_with_holes_count' => l.respond_to?(:faces_with_holes_count) ?
                                          l.faces_with_holes_count.to_i : 0
          }
        end
        layer_descs.sort_by! { |d| _encode_normalized(d) }

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

      # B1-SR-05: stable source occurrence resolver.
      #
      # This is an INSTANCE-bound helper, NOT a module-global.
      # It does NOT memoize across builds. For every call it
      # walks the supplied source_projection and resolves a
      # transient occurrence ID only when the SourceSnapshot
      # edge record at that occurrence has a complete
      # persistent_id_path AND the supplied occurrence ID
      # string matches the expected current SourceSnapshot
      # spelling: "occ-" + PID path joined by ">".
      #
      # Transient or unknown occurrence IDs return nil and
      # produce no semantic ref.
      def _stable_source_refs_from_occurrences(occurrence_ids, source_projection:)
        return [] unless occurrence_ids.is_a?(Array)
        return [] if source_projection.nil?
        # Build the lookup table from the current
        # source_projection: map the EXACT current
        # SourceSnapshot expected spelling to the ref.
        table = {}
        Array(source_projection['edges']).each do |edge|
          ref = edge['stable_source_ref']
          next unless ref.is_a?(Hash) && ref['kind'] == 'source_pid_path'
          pid_path = Array(ref['persistent_id_path']).map(&:to_i)
          expected_spelling = 'occ-' + pid_path.map(&:to_s).join('>')
          table[expected_spelling] = ref
        end
        # Now resolve each occurrence ID only if it matches the
        # current snapshot spelling exactly.
        out = []
        occurrence_ids.each do |oid|
          oid_str = oid.to_s
          next if oid_str.empty?
          ref = table[oid_str]
          next unless ref
          out << ref
        end
        out
      end

      def _endpoint_xyz(point)
        return nil unless point.is_a?(Array) && point.length == 3
        out = point.map { |c| c.respond_to?(:to_f) ? c.to_f : nil }
        return nil if out.any? { |v| v.nil? || !v.finite? }
        out
      end

      def _canonical_edge_endpoints(a, b)
        ab = [a, b]
        ba = [b, a]
        _encode_normalized(ab) <=
          _encode_normalized(ba) ? ab : ba
      end

      # Ensure a String value is stored as UTF-8. nil -> "".
      # Used to normalize layer names / roles / messages / etc.
      # that may originate in US-ASCII (e.g. Symbol#to_s in
      # Ruby). For already-UTF-8 strings, this is a no-op.
      def _to_utf8(v)
        return '' if v.nil?
        s = v.to_s
        if s.respond_to?(:encoding) && s.encoding.name != 'UTF-8'
          s = s.dup.force_encoding('UTF-8')
          unless s.valid_encoding?
            raise ArgumentError,
                  "cannot convert value to valid UTF-8: #{s.inspect[0, 80]}"
          end
        end
        s
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
        if source_snapshot.respond_to?(:transform_context) &&
           source_snapshot.transform_context.is_a?(Hash) &&
           !source_snapshot.transform_context.empty?
          tctx = source_snapshot.transform_context
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
        unit = source_snapshot.respond_to?(:unit) ?
                 source_snapshot.unit.to_s : 'inches'
        origin = source_snapshot.respond_to?(:coordinate_origin) ?
                   source_snapshot.coordinate_origin.to_s : 'raw'
        projection = {
          'schema_version'          => ACTIVE_EDIT_SCHEMA,
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
                       normalized_tolerance:, source_projection:,
                       truncation_context: nil)
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

        # Topology canonical_nodes (raw topology view).
        topo_canonicals = topology_snapshot[:canonical_nodes] ||
                            topology_snapshot['canonical_nodes'] || []
        topo_canonicals = Array(topo_canonicals)
        topo_groups = {}  # legacy_canonical_node_id -> [endpoint_keys]
        topo_group_meta = {}  # legacy_canonical_node_id -> membership_count + resolved_clique
        topo_canonicals.each do |n|
          unless n.is_a?(Hash)
            blockers << REASON_TOPOLOGY_BAD_CANONICAL + ':not_hash'
            break
          end
          cid = n['canonical_node_id'].to_s
          ek  = n['endpoint_key'].to_s
          if cid.empty? || ek.empty?
            blockers << REASON_TOPOLOGY_BAD_CANONICAL + ":node=#{cid}:ek=#{ek}"
            break
          end
          topo_groups[cid] ||= []
          topo_groups[cid] << ek
          topo_group_meta[cid] ||= {
            'resolved_clique'  => n['resolved_clique']
          }
        end

        graph_nodes = Array(canonical_graph.nodes)
        if blockers.empty?
          # ----- B1-SR-03 §1.1: exact topology endpoint set equality ---
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
            blockers << REASON_GRAPH_ENDPOINT_MISMATCH +
                            ":missing=#{missing.sort.join(',')}:extra=#{extra.sort.join(',')}"
          end
        end

        # ----- B1-SR-03 §1.1: topology-group vs graph-node membership
        # equality per graph node, plus membership_count +
        # resolved_clique agreement.
        if blockers.empty?
          graph_nodes.each do |gn|
            nh = gn.is_a?(Hash) ? gn : (gn.respond_to?(:to_h) ? gn.to_h : {})
            cid = nh['canonical_node_id'].to_s
            topo_group = Array(topo_groups[cid]).map(&:to_s).sort
            graph_group = Array(nh['endpoint_keys']).map(&:to_s).sort
            if topo_group != graph_group
              blockers << REASON_GRAPH_NODE_MEMBERSHIP_MISMATCH +
                              ":node=#{cid}"
              break
            end
            meta = topo_group_meta[cid] || {}
            # Topology doesn't always publish membership_count
            # directly; derive it from the topology group size.
            topo_mc = Array(topo_groups[cid]).length
            graph_mc = nh['membership_count']
            if topo_mc.to_i != graph_mc.to_i
              blockers << REASON_GRAPH_NODE_MEMBERSHIP_COUNT_MISMATCH +
                              ":node=#{cid}:got=#{graph_mc}:want=#{topo_mc}"
              break
            end
            topo_clique = meta['resolved_clique']
            graph_clique = nh['resolved_clique']
            if (topo_clique == true) != (graph_clique == true)
              blockers << REASON_GRAPH_NODE_CLIQUE_FLAG_MISMATCH +
                              ":node=#{cid}"
              break
            end
          end
        end

        if blockers.empty?
          # Stage A: per-graph-node resolve + clique check + rep coord.
          node_records = []
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
            sorted_coords = coords.sort_by { |c| _encode_normalized(c) }
            rep = sorted_coords.first
            # B1-SR-06: stable source refs are derived ONLY from
            # the EXACT current SourceSnapshot lookup.
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
            # B1-SR-07: full SHA-256 labels throughout. Initial
            # label0 = full SHA-256 hex.
            node_records.each do |nr|
              seed = {
                'xyz'              => nr['xyz'],
                'source_occurrence_ids' => nr['source_occurrence_ids'],
                'layer_names'      => nr['layer_names'],
                'resolved_clique'  => nr['resolved_clique'],
                'membership_count' => nr['membership_count']
              }
              nr['label_seed'] = seed
              nr['label_full'] = PreparedCadDataset.send(
                :_utf8_string,
                _sha256_hex(
                  _encode_normalized(
                    PreparedCadDataset.send(:_normalize_strings_utf8, seed)
                  )
                )
              )
            end

            # Sort by full label for stable iteration.
            node_records.sort_by! { |nr| nr['label_full'] }

            label_by_cid = {}
            node_records.each { |nr| label_by_cid[nr['legacy_canonical_node_id']] = nr['label_full'] }

            # ----- Build semantic edges (semantic node IDs are
            # resolved AFTER node label refinement; here we keep
            # record_without_id per edge using CURRENT endpoint
            # labels as we iterate). ---------------------------
            edge_records = Array(canonical_graph.edges)
            semantic_edges = []
            edge_records.each do |e|
              eh = e.is_a?(Hash) ? e : (e.respond_to?(:to_h) ? e.to_h : {})
              a = eh['node_a_id'].to_s
              b = eh['node_b_id'].to_s
              origin = _to_utf8(eh['origin_kind'] || 'source_derived')
              layer  = _to_utf8(eh['layer_name'])
              srefs  = _stable_source_refs_from_occurrences(
                Array(eh['source_occurrence_ids']),
                source_projection: source_projection
              )
              repair_id_legacy = eh['repair_action_id'] ?
                                   eh['repair_action_id'].to_s : nil
              unresolved = Array(eh['unresolved_flags']).map(&:to_s).sort.uniq
              # B1-SR-06: semantic_repair_id is derived from
              # STABLE repair facts only. Legacy repair_id is
              # intentionally NOT in the semantic hash.
              semantic_repair_id = nil
              if origin == 'gap_bridge' && repair_id_legacy && !repair_id_legacy.empty?
                semantic_repair_id = _semantic_repair_id(
                  origin_kind: origin,
                  layer_name: layer,
                  source_occurrence_ids: srefs,
                  unresolved_flags: unresolved,
                  truncation_context: truncation_context
                )
                # R2-01: nil return from _semantic_repair_id
                # signals a pcrp truncated-prefix collision.
                # Per dispatch R2-01: collision blocker MUST
                # use the normal semantic-ID truncation collision
                # family (`semantic_id_truncation_collision:repair`),
                # NOT `semantic_repair_ambiguity`.
                if semantic_repair_id.nil?
                  blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                                  ':repair'
                  # continue to surface as many collisions as
                  # possible, but BLOCK at the end
                end
              end
              semantic_edges << {
                'legacy_canonical_edge_id' => eh['canonical_edge_id'].to_s,
                'node_a_id'                => a,
                'node_b_id'                => b,
                'origin_kind'              => origin,
                'layer_name'               => layer,
                'source_occurrence_ids'    => srefs,
                'legacy_repair_action_id'  => repair_id_legacy,
                'unresolved_flags'         => unresolved,
                'semantic_repair_id'       => semantic_repair_id
              }
            end
            semantic_edges.sort_by! { |e| e['legacy_canonical_edge_id'] }

            # Incident edge index for node label refinement.
            incident = Hash.new { |h, k| h[k] = [] }
            semantic_edges.each do |e|
              incident[e['node_a_id']] << e
              incident[e['node_b_id']] << e
            end

            # ----- Node label refinement (B1-SR-07) ------------------
            # Iterate until labels stop changing OR node_count
            # rounds. Each round produces a FULL SHA-256 hex
            # label. The final pcn- id is "pcn-" + first20(final
            # full label). No extra rehash.
            current_labels = label_by_cid.dup
            max_rounds = [node_records.length, 1].max
            (0...max_rounds).each do |_round|
              next_labels = {}
              node_records.each do |nr|
                cid = nr['legacy_canonical_node_id']
                pair_list = incident[cid].map do |e|
                  other_cid = e['node_a_id'] == cid ? e['node_b_id'] : e['node_a_id']
                  other_prev = current_labels[other_cid] || other_cid
                  la = current_labels[e['node_a_id']] || e['node_a_id']
                  lb = current_labels[e['node_b_id']] || e['node_b_id']
                  lo_pair = la <= lb ? [la, lb] : [lb, la]
                  prov = {
                    'node_a_label0'      => lo_pair[0],
                    'node_b_label0'      => lo_pair[1],
                    'origin_kind'        => e['origin_kind'],
                    'layer_name'         => e['layer_name'],
                    'stable_source_refs' => e['source_occurrence_ids'],
                    'unresolved_flags'   => e['unresolved_flags'],
                    'semantic_repair_id' => e['semantic_repair_id']
                  }
                  prov_label = _sha256_hex(
                    _encode_normalized(prov)
                  )
                  [prov_label, other_prev].sort_by { |s| s.bytes }
                end
                pair_list.sort_by! { |p| _encode_normalized(p) }
                input = {
                  'node_local_seed' => nr['label_seed'],
                  'edges'           => pair_list
                }
                next_labels[cid] = _sha256_hex(
                  _encode_normalized(input)
                )
              end
              if next_labels == current_labels
                current_labels = next_labels
                break
              end
              current_labels = next_labels
            end

            # ----- Final pcn IDs + collision check -------------------
            full_digest_by_pid = {}
            node_id_by_cid = {}
            node_records.each do |nr|
              cid = nr['legacy_canonical_node_id']
              full = current_labels[cid]
              pid = PreparedCadDataset::NODE_ID_PREFIX + full[0, 20]
              # B1-SR-09 truncated-ID collision map.
              existing = full_digest_by_pid[pid]
              if !existing.nil? && existing != full
                blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION + ':node'
              end
              full_digest_by_pid[pid] = full
              node_id_by_cid[cid] = pid
              nr['node_id'] = pid
              nr['full_node_digest'] = full
            end

            # B1-SR-08: ambiguity BLOCKED if any two distinct
            # legacy nodes share one final full digest.
            seen_label = {}
            node_records.each do |nr|
              cid = nr['legacy_canonical_node_id']
              full = nr['full_node_digest']
              if seen_label.key?(full) && seen_label[full] != cid
                blockers << REASON_SEMANTIC_NODE_AMBIGUITY +
                                ":full=#{full[0, 12]}"
              end
              seen_label[full] = cid
            end

            # ----- Semantic edge IDs (final) -------------------------
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
                'semantic_repair_id'    => e['semantic_repair_id']
              }
              full = _sha256_hex(
                _encode_normalized(record)
              )
              pid = PreparedCadDataset::EDGE_ID_PREFIX + full[0, 20]
              existing = edge_full_by_pid[pid]
              if !existing.nil? && existing != full
                blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION + ':edge'
              end
              edge_full_by_pid[pid] = full
              edge_id_by_legacy[e['legacy_canonical_edge_id']] = pid
              e['semantic_edge_id'] = pid
              e['semantic_node_a_id'] = node_a_id
              e['semantic_node_b_id'] = node_b_id
            end

            # B1-SR-08: edge ambiguity BLOCKED.
            seen_efull = {}
            semantic_edges.each do |e|
              cid = e['legacy_canonical_edge_id']
              full = edge_full_by_pid[e['semantic_edge_id']]
              if seen_efull.key?(full) && seen_efull[full] != cid
                blockers << REASON_SEMANTIC_EDGE_AMBIGUITY +
                                ":full=#{full[0, 12]}"
              end
              seen_efull[full] = cid
            end

            # Adjacency rebuild from semantic edges.
            adj = Hash.new { |h, k| h[k] = [] }
            semantic_edges.each do |e|
              a = e['semantic_node_a_id']
              b = e['semantic_node_b_id']
              adj[a] << b
              adj[b] << a
            end
            adj.each_value { |v| v.uniq!; v.sort! }

            final_nodes = node_records.map do |nr|
              {
                'node_id'             => nr['node_id'],
                'xyz'                 => nr['xyz'],
                'membership_count'    => nr['membership_count'],
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
                'semantic_repair_id'  => e['semantic_repair_id']
              }
            end
            final_edges.sort_by! { |e| e['edge_id'] }

            final_adj = {}
            adj.each { |k, v| final_adj[k.to_s] = v.map(&:to_s).sort }

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

      # B1-SR-06 + FR-04: semantic repair ID is hashed from
      # STABLE repair facts only. Structured stable source
      # refs are normalized directly (NOT via Hash#to_s,
      # which is unstable and forbidden as semantic identity).
      # Legacy repair/action/proposal IDs are NOT in the
      # semantic record (they remain build evidence only).
      def _semantic_repair_id(origin_kind:, layer_name:,
                              source_occurrence_ids:, unresolved_flags:,
                              truncation_context: nil)
        # Normalize structured refs into a deterministic
        # canonical Hash form: sort by IdentityBytes of the
        # canonical-ref record (NOT by to_s of the Hash).
        canonical_refs = Array(source_occurrence_ids).map do |r|
          if r.is_a?(Hash)
            {
              'kind'               => r['kind'] || r[:kind],
              'persistent_id_path' => Array(r['persistent_id_path'] ||
                                            r[:persistent_id_path]).map(&:to_i)
            }
          end
        end.compact
        # Deterministic order: by IdentityBytes.
        canonical_refs.sort_by! do |r|
          PreparedCadDataset::IdentityBytes.encode(r)
        end
        canonical_refs.uniq!
        record = {
          'origin_kind'           => origin_kind.to_s,
          'layer_name'            => _to_utf8(layer_name),
          'stable_source_refs'    => canonical_refs,
          'unresolved_flags'      => Array(unresolved_flags).map(&:to_s).sort.uniq
        }
        full = _sha256_hex(
          _encode_normalized(record)
        )
        pid = PreparedCadDataset::REPAIR_ID_PREFIX + full[0, 20]
        # FR-04: enforce pcrp truncated-prefix collision map.
        if truncation_context
          key = "pcrp_collision:#{pid}"
          existing = truncation_context[key]
          if existing && existing != full
            return nil  # ambiguous: caller maps to BLOCKED
          end
          truncation_context[key] = full
        end
        pid
      end

      # ----- semantic structure remap -------------------------------------

      def _remap_structure(structure_result:, graph_projection:,
                           legacy_node_to_pcn:, legacy_edge_to_pce:,
                           source_projection:, truncation_context: nil)
        blockers = []
        schema = structure_result[:schema_version] ||
                   structure_result['schema_version']
        unless schema.to_s == 'csr.v1'
          blockers << REASON_STRUCTURE_SCHEMA_MISMATCH + ":got=#{schema}"
          return [nil, blockers]
        end

        node_lookup = {}
        Array(graph_projection['nodes']).each do |n|
          node_lookup[n['node_id'].to_s] = n['xyz']
        end

        # ----- Chains (B1-SR-08) ---------------------------------------
        # Chain forward = walk nodes/edges in given order:
        #   [n0, e0, n1, e1, ..., n_last]
        # Chain reverse (aligned) = walk backwards:
        #   [n_last, e_{n-2}, n_{n-1}, ..., n1, e0, n0]
        # i.e. for an L-edge chain (length 2L+1 token seq),
        # rev_seq = fwd_seq.reverse.
        chains_in = structure_result[:chains] || structure_result['chains'] || []
        chain_records = []
        Array(chains_in).each do |ch|
          nh = ch.is_a?(Hash) ? ch : (ch.respond_to?(:to_h) ? ch.to_h : {})
          legacy_node_ids = Array(nh['node_ids'] || nh[:node_ids]).map(&:to_s)
          legacy_edge_ids = Array(nh['edge_ids'] || nh[:edge_ids]).map(&:to_s)
          # R2-03: do NOT silently fall back to the raw legacy
          # id when lookup fails. Return [resolved, missing]
          # so the caller can BLOCK on unresolved legacy refs.
          remap_nodes, missing_nodes =
            _remap_chain_nodes(legacy_node_ids, legacy_node_to_pcn)
          remap_edges, missing_edges =
            _remap_chain_edges(legacy_edge_ids, legacy_edge_to_pce)
          unless missing_nodes.empty?
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                            ':chain_node_unresolved'
            break
          end
          unless missing_edges.empty?
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                            ':chain_edge_unresolved'
            break
          end
          # R2-03: structural cardinality. A chain of L edges
          # MUST have exactly L+1 nodes; an empty chain
          # (no nodes / no edges) is BLOCKED.
          if remap_nodes.empty? || remap_edges.empty?
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                            ':chain_empty'
            break
          end
          if remap_nodes.length != remap_edges.length + 1
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                            ':chain_node_edge_cardinality'
            break
          end
          fwd_seq = _chain_forward_sequence(remap_nodes, remap_edges)
          rev_seq = _chain_reverse_sequence(remap_nodes, remap_edges)
          chosen = (_encode_normalized(fwd_seq) <=
                    _encode_normalized(rev_seq)) ?
                     fwd_seq : rev_seq
          record_without_id = {
            'node_ids' => chosen.select { |t| t.start_with?(PreparedCadDataset::NODE_ID_PREFIX) },
            'edge_ids' => chosen.select { |t| t.start_with?(PreparedCadDataset::EDGE_ID_PREFIX) }
          }
          full = _sha256_hex(
            _encode_normalized(record_without_id)
          )
          legacy_id = (nh['chain_id'] || nh[:chain_id] || '').to_s
          chain_records << {
            'chain_id'    => PreparedCadDataset::CHAIN_ID_PREFIX + full[0, 20],
            'full_digest' => full,
            'legacy_id'   => legacy_id,
            'node_ids'    => record_without_id['node_ids'],
            'edge_ids'    => record_without_id['edge_ids']
          }
        end
        # FR-05: track distinct legacy chain inputs separately
        # from the semantic full_digest. Two DISTINCT legacy
        # chain IDs producing the SAME full semantic record
        # => semantic_chain_ambiguity BLOCKED.
        # Same legacy_id producing same full_digest is dedup,
        # NOT ambiguity.
        seen_by_full = {}
        seen_by_legacy = {}
        chain_records.each do |c|
          full = c['full_digest']
          leg  = c['legacy_id']
          if seen_by_full.key?(full)
            # Multiple distinct legacy chains collide to same
            # semantic record => ambiguity.
            if seen_by_full[full] != leg
              blockers << REASON_SEMANTIC_CHAIN_AMBIGUITY +
                              ":full=#{full[0, 12]}:legacy=#{seen_by_full[full]}:#{leg}"
              break
            end
          else
            seen_by_full[full] = leg
          end
          if !leg.empty? && seen_by_legacy.key?(leg) && seen_by_legacy[leg] != full
            # Same legacy id mapped to two different fulls =>
            # ambiguity too.
            blockers << REASON_SEMANTIC_CHAIN_AMBIGUITY +
                            ":legacy=#{leg}:full=#{full[0, 12]}:#{seen_by_legacy[leg][0, 12]}"
            break
          end
          seen_by_legacy[leg] = full
        end
        # B1-SR-09 truncated-ID collision check.
        chain_full_by_pid = {}
        chain_records.each do |c|
          pid = c['chain_id']
          existing = chain_full_by_pid[pid]
          if !existing.nil? && existing != c['full_digest']
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION + ':chain'
          end
          chain_full_by_pid[pid] = c['full_digest']
        end
        chain_records.each do |c|
          c.delete('full_digest')
          c.delete('legacy_id')
        end

        # ----- Loops (B1-SR-08) ----------------------------------------
        # Loop exactly 2*N valid node-starting representations,
        # N forward rotations + N reverse orientations,
        # preserving edge-to-consecutive-node alignment. N is
        # the number of loop NODES (i.e. seq.length / 2).
        loops_in = structure_result[:loops] || structure_result['loops'] || []
        loop_records = []
        Array(loops_in).each do |lp|
          lh = lp.is_a?(Hash) ? lp : (lp.respond_to?(:to_h) ? lp.to_h : {})
          legacy_node_ids = Array(lh['node_ids'] || lh[:node_ids]).map(&:to_s)
          legacy_edge_ids = Array(lh['edge_ids'] || lh[:edge_ids]).map(&:to_s)
          # R2-03: fail closed if any legacy node/edge ref
          # cannot resolve through the supplied maps.
          remap_nodes, missing_nodes =
            _remap_chain_nodes(legacy_node_ids, legacy_node_to_pcn)
          remap_edges, missing_edges =
            _remap_chain_edges(legacy_edge_ids, legacy_edge_to_pce)
          unless missing_nodes.empty?
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                            ':loop_node_unresolved'
            break
          end
          unless missing_edges.empty?
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                            ':loop_edge_unresolved'
            break
          end
          # R2-03: structural cardinality. A valid loop has
          # node_count == edge_count and non-empty.
          if remap_nodes.empty? || remap_edges.empty?
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                            ':loop_empty'
            break
          end
          if remap_nodes.length != remap_edges.length
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                            ':loop_node_edge_cardinality'
            break
          end
          rotations = _loop_canonical_representations(remap_nodes, remap_edges)
                    chosen = rotations.min_by do |s|
            _encode_normalized(s)
          end
          record_without_id = {
            'node_ids' => chosen.select { |t| t.start_with?(PreparedCadDataset::NODE_ID_PREFIX) },
            'edge_ids' => chosen.select { |t| t.start_with?(PreparedCadDataset::EDGE_ID_PREFIX) }
          }
          full = _sha256_hex(
            _encode_normalized(record_without_id)
          )
          legacy_id = (lh['loop_id'] || lh[:loop_id] || '').to_s
          loop_records << {
            'loop_id'    => PreparedCadDataset::LOOP_ID_PREFIX + full[0, 20],
            'full_digest' => full,
            'legacy_id'   => legacy_id,
            'node_ids'   => record_without_id['node_ids'],
            'edge_ids'   => record_without_id['edge_ids'],
            'layer_name' => _to_utf8(lh['layer_name'] || lh[:layer_name] || '')
          }
        end
        # FR-05: distinct legacy loop inputs producing same
        # semantic full_digest => ambiguity.
        seen_by_full = {}
        seen_by_legacy = {}
        loop_records.each do |lp|
          f = lp['full_digest']
          leg  = lp['legacy_id']
          if seen_by_full.key?(f) && seen_by_full[f] != leg
            blockers << REASON_SEMANTIC_LOOP_AMBIGUITY +
                            ':full=' + f[0, 12] + ':legacy=' + seen_by_full[f] + ':' + leg
            break
          end
          seen_by_full[f] = leg
          if !leg.empty? && seen_by_legacy.key?(leg) && seen_by_legacy[leg] != f
            blockers << REASON_SEMANTIC_LOOP_AMBIGUITY +
                            ':legacy=' + leg + ':full=' + f[0, 12]
            break
          end
          seen_by_legacy[leg] = f
        end
        seen = {}
        loop_records.each do |lp|
          if seen.key?(lp['full_digest']) && seen[lp['full_digest']] != lp['loop_id']
            blockers << REASON_SEMANTIC_LOOP_AMBIGUITY +
                            ":full=#{lp['full_digest'][0, 12]}"
            break
          end
          seen[lp['full_digest']] = lp['loop_id']
        end
        loop_full_by_pid = {}
        loop_records.each do |lp|
          pid = lp['loop_id']
          existing = loop_full_by_pid[pid]
          if !existing.nil? && existing != lp['full_digest']
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION + ':loop'
          end
          loop_full_by_pid[pid] = lp['full_digest']
        end
        loop_records.each do |lp|
          # R2-03: legacy_id is a transient addressing ID and
          # MUST be removed from the published semantic loop
          # record. The published semantic content must NOT
          # carry any chain_id / loop_id / region_id /
          # canonical_* legacy IDs.
          lp.delete('full_digest')
          lp.delete('legacy_id')
        end

        # ----- Regions (B1-SR-08) --------------------------------------
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
          # R2-03: outer loop ref MUST resolve; nil => BLOCKED.
          outer_semantic = _remap_loop_id(outer, legacy_node_to_pcn,
                                          legacy_edge_to_pce, loops_in, loop_records)
          if outer_semantic.nil? && !Array(regions_in).empty?
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                            ':region_outer_loop_unresolved'
            break
          end
          holes_semantic = holes.map { |h| _remap_loop_id(h, legacy_node_to_pcn,
                                                         legacy_edge_to_pce, loops_in, loop_records) }
          # R2-03: hole loop refs MUST resolve. nil => BLOCKED.
          if holes_semantic.any?(&:nil?)
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION +
                            ':region_hole_loop_unresolved'
            break
          end
          holes_semantic = holes_semantic.compact.uniq.sort
          record_without_id = {
            'outer_loop_id'   => outer_semantic,
            'hole_loop_ids'    => holes_semantic,
            'layer_name'       => _to_utf8(rh['layer_name'] || rh[:layer_name] || ''),
            'stable_source_refs' => _region_source_refs(rh),
            'unresolved_flags' => Array(rh['unresolved_flags'] || rh[:unresolved_flags]).map(&:to_s).sort.uniq
          }
          full = _sha256_hex(
            _encode_normalized(record_without_id)
          )
                    region_records << {
            'region_id' => PreparedCadDataset::REGION_ID_PREFIX + full[0, 20],
            'full_digest' => full,
            'legacy_id' => (rh['region_id'] || rh[:region_id] || '').to_s,
            'outer_loop_id' => outer_semantic,
            'hole_loop_ids' => holes_semantic,
            'layer_name' => record_without_id['layer_name'],
            'stable_source_refs' => record_without_id['stable_source_refs'],
            'unresolved_flags' => record_without_id['unresolved_flags']
          }
        end
        # FR-05: distinct legacy region inputs producing
        # same semantic full_digest => ambiguity.
        seen_by_full = {}
        seen_by_legacy = {}
        region_records.each do |r|
          f = r['full_digest']
          leg  = r['legacy_id']
          if seen_by_full.key?(f) && seen_by_full[f] != leg
            blockers << REASON_SEMANTIC_REGION_AMBIGUITY +
                            ':full=' + f[0, 12] + ':legacy=' + seen_by_full[f] + ':' + leg
            break
          end
          seen_by_full[f] = leg
          if !leg.empty? && seen_by_legacy.key?(leg) && seen_by_legacy[leg] != f
            blockers << REASON_SEMANTIC_REGION_AMBIGUITY +
                            ':legacy=' + leg + ':full=' + f[0, 12]
            break
          end
          seen_by_legacy[leg] = f
        end
        region_full_by_pid = {}
        region_records.each do |r|
          pid = r['region_id']
          existing = region_full_by_pid[pid]
          if !existing.nil? && existing != r['full_digest']
            blockers << REASON_SEMANTIC_ID_TRUNCATION_COLLISION + ':region'
          end
          region_full_by_pid[pid] = r['full_digest']
        end
        region_records.each do |r|
          r.delete('full_digest')
          r.delete('legacy_id')
        end
        region_records.each { |r| r.delete('full_digest') }

        chain_records.sort_by! { |c| c['chain_id'] }
        loop_records.sort_by!  { |lp| lp['loop_id'] }
        region_records.sort_by! { |r| r['region_id'] }

        state = structure_result[:state] || structure_result['state']
        metrics = structure_result[:metrics] || structure_result['metrics'] || {}

        projection = {
          'schema_version' => SEMANTIC_STRUCTURE_SCHEMA,
          'state'          => state.to_s,
          'chains'         => chain_records,
          'loops'          => loop_records,
          'regions'        => region_records,
          'metrics'        => metrics
        }
        [projection, blockers]
      end

      def _remap_chain_nodes(legacy_node_ids, legacy_node_to_pcn)
        # R2-03: return [resolved_ids, missing_ids]. The
        # caller must fail closed when missing_ids is
        # non-empty. DO NOT silently fall back to the raw
        # legacy id.
        resolved = []
        missing = []
        legacy_node_ids.each do |id|
          mapped = legacy_node_to_pcn[id]
          if mapped.nil?
            missing << id
            resolved << nil
          else
            resolved << mapped
          end
        end
        [resolved, missing]
      end

      def _remap_chain_edges(legacy_edge_ids, legacy_edge_to_pce)
        # R2-03: return [resolved_ids, missing_ids].
        resolved = []
        missing = []
        legacy_edge_ids.each do |id|
          mapped = legacy_edge_to_pce[id]
          if mapped.nil?
            missing << id
            resolved << nil
          else
            resolved << mapped
          end
        end
        [resolved, missing]
      end

      # Forward chain sequence:
      #   nodes[0], edges[0], nodes[1], edges[1], ..., nodes[L]
      # where L is chain length (number of edges).
      def _chain_forward_sequence(nodes, edges)
        out = []
        l = edges.length
        l.times do |i|
          out << nodes[i]
          out << edges[i]
        end
        out << nodes.last
        out
      end

      # Reverse chain sequence (aligned):
      #   nodes[L], edges[L-1], nodes[L-1], edges[L-2], ..., nodes[0]
      def _chain_reverse_sequence(nodes, edges)
        l = edges.length
        return nodes.dup if l.zero?
        out = []
        l.times do |i|
          out << nodes[l - i]
          out << edges[l - 1 - i]
        end
        out << nodes[0]
        out
      end

      # Loop canonical representations (B1-SR-08):
      # exactly 2*N valid node-starting representations:
      # N forward rotations + N reverse orientations,
      # preserving edge-to-consecutive-node alignment.
      # Here N is the number of loop nodes.
      def _loop_canonical_representations(remap_nodes, remap_edges)
        # Build the canonical token sequence starting at the
        # first node:
        # nodes[0], edges[0], nodes[1], edges[1], ..., nodes[N-1], edges[N-1]
        # (where N = number of loop nodes; loop length in edges is also N).
        n_nodes = remap_nodes.length
        n_edges = remap_edges.length
        if n_nodes == 0
          return [[]]
        end
        # If edge count doesn't match node count (degenerate
        # loop), fall back to a single representation.
        return [_loop_sequence_at(remap_nodes, remap_edges, 0, :forward)] if n_nodes != n_edges
        reps = []
        n_nodes.times do |i|
          reps << _loop_sequence_at(remap_nodes, remap_edges, i, :forward)
        end
        n_nodes.times do |i|
          reps << _loop_sequence_at(remap_nodes, remap_edges, i, :reverse)
        end
        reps
      end

      # Build the loop token sequence starting at node `start_i`
      # in orientation :forward or :reverse. The sequence is
      # length 2*N: alternating node/edge.
      def _loop_sequence_at(nodes, edges, start_i, orientation)
        n = nodes.length
        return [nodes[start_i]] if n == 1
        if orientation == :forward
          out = []
          n.times do |k|
            out << nodes[(start_i + k) % n]
            out << edges[(start_i + k) % n]
          end
          out
        else
          # Reverse orientation: walk around the loop in the
          # OPPOSITE direction. The reverse walk visits:
          #   nodes[start_i],
          #   edges[(start_i - 1) % n],
          #   nodes[(start_i - 1) % n],
          #   edges[(start_i - 2) % n],
          #   ...
          out = []
          n.times do |k|
            out << nodes[(start_i - k) % n]
            out << edges[(start_i - 1 - k) % n]
          end
          out
        end
      end

      def _remap_loop_id(legacy_loop_id, legacy_node_to_pcn, legacy_edge_to_pce,
                        legacy_loops, semantic_loops)
        return nil if legacy_loop_id.nil?
        legacy_loop_id = legacy_loop_id.to_s
        legacy_loop = Array(legacy_loops).find do |lp|
          lh = lp.is_a?(Hash) ? lp : (lp.respond_to?(:to_h) ? lp.to_h : {})
          (lh['loop_id'] || lh[:loop_id]).to_s == legacy_loop_id
        end
        return nil unless legacy_loop
        lh = legacy_loop.is_a?(Hash) ? legacy_loop :
                (legacy_loop.respond_to?(:to_h) ? legacy_loop.to_h : {})
        legacy_node_ids = Array(lh['node_ids'] || lh[:node_ids]).map(&:to_s)
        legacy_edge_ids = Array(lh['edge_ids'] || lh[:edge_ids]).map(&:to_s)
        # R2-03: fail closed if any legacy node/edge ref
        # cannot resolve. The returned resolved arrays may
        # contain nils; the caller checks for that.
        remap_nodes, _missing_nodes =
          _remap_chain_nodes(legacy_node_ids, legacy_node_to_pcn)
        remap_edges, _missing_edges =
          _remap_chain_edges(legacy_edge_ids, legacy_edge_to_pce)
        if remap_nodes.any?(&:nil?) || remap_edges.any?(&:nil?)
          return nil
        end
        rotations = _loop_canonical_representations(remap_nodes, remap_edges)
        chosen = rotations.min_by do |s|
          _encode_normalized(s)
        end
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
        pcn_by_xy_clique = {}
        Array(graph_projection['nodes']).each do |n|
          xyz = n['xyz']
          key = _encode_normalized(xyz)
          pcn_by_xy_clique[key] = n['node_id']
        end
        pce_by_sref = {}
        Array(graph_projection['edges']).each do |e|
          Array(e['source_occurrence_ids']).each do |s|
            # s is a Hash { 'kind' => ..., 'persistent_id_path' => [...] }.
            pce_by_sref[_encode_normalized(s)] = e['edge_id'] if s.is_a?(Hash)
          end
        end

        projected = []
        Array(issues).each do |iss|
          issue_type = (iss[:issue_type] || iss['issue_type']).to_s
          next unless SECONDARY_WARNING_TYPES.include?(issue_type)
          refs = []
          loc = iss[:location]
          if loc.is_a?(Array) && loc.length == 3
            key = _encode_normalized(loc.map(&:to_f))
            pid = pcn_by_xy_clique[key]
            refs << { 'kind' => 'pcd_node', 'id' => pid } if pid
          end
          # source_occurrence_ids from issue carry the
          # transient occurrence spellings (occ-...). We can
          # still resolve them only via the B1-SR-05 lookup if
          # the issue supplied complete persistent_id_paths.
          Array(iss[:sources]).each do |src|
            next unless src.is_a?(Hash)
            pp = Array(src[:persistent_id_path] || src['persistent_id_path'])
            if src[:pid_path_complete] && !pp.empty?
              refs << { 'kind' => 'source_pid_path',
                        'persistent_id_path' => pp.map(&:to_i) }
            end
          end
          refs = refs.reject { |r| r['id'].nil? }
          projected << {
            'issue_type' => issue_type,
            'severity'   => iss[:severity].to_s,
            'confidence' => iss[:confidence],
            'refs'       => refs,
            'message'    => iss[:message].to_s
          }
        end
        projected.sort_by! { |i| _encode_normalized(i) }

        counts = Hash.new(0)
        projected.each { |i| counts[i['issue_type']] += 1 }

        projection = {
          'schema_version' => CURRENT_ISSUES_SCHEMA,
          'issues'         => projected,
          'counts'         => counts
        }
        [projection, blockers]
      end

      # ----- Analysis <-> Source coherence projection ----------------------

      def _compute_coherence_digest(source_snapshot:, analysis_result:,
                                    source_projection:)
        blockers = []
        source_edges = source_snapshot.respond_to?(:edges) ?
                         Array(source_snapshot.edges) : []
        source_faces = source_snapshot.respond_to?(:faces) ?
                         Array(source_snapshot.faces) : []
        source_layers = source_snapshot.respond_to?(:layers) ?
                          Array(source_snapshot.layers) : []

        # R3-01: pre-pass validate every SourceReference
        # participating in Source<->Analysis coherence. The
        # Blueprint v1.3 §1.6 shape gate must apply to
        # ALL participants, not only to registry issue
        # sources. Done BEFORE coherence digest acceptance.
        geom = analysis_result.respond_to?(:geometry_snapshot) ?
                 analysis_result.geometry_snapshot : nil
        all_participants = []
        source_edges.each do |e|
          all_participants << (e.respond_to?(:source) ? e.source : nil)
        end
        source_faces.each do |f|
          all_participants << (f.respond_to?(:source) ? f.source : nil)
        end
        if geom && geom.respond_to?(:edges)
          Array(geom.edges).each do |e|
            all_participants << (e.respond_to?(:source) ? e.source : nil)
          end
        end
        if geom && geom.respond_to?(:faces)
          Array(geom.faces).each do |f|
            all_participants << (f.respond_to?(:source) ? f.source : nil)
          end
        end
        all_participants.each do |src|
          shape_blockers, _desc =
            _validate_coherence_source_reference(src)
          blockers.concat(shape_blockers)
          break unless blockers.empty?
        end
        return [nil, blockers] unless blockers.empty?

        source_edge_descs = source_edges.map do |e|
          s = _endpoint_xyz(e.start_point)
          t = _endpoint_xyz(e.end_point)
          ref = _coherence_source_ref(e.source)
          layer = _to_utf8(e.respond_to?(:layer) ? e.layer : '')
          {
            'kind' => 'edge',
            'canonical_endpoints' => (s && t) ? _canonical_edge_endpoints(s, t) : nil,
            'layer_name' => layer,
            'coherence_source_ref' => ref
          }
        end.compact
        source_edge_descs.sort_by! { |d| _encode_normalized(d) }

        source_face_descs = source_faces.map do |f|
          ref = _coherence_source_ref(f.source)
          {
            'kind' => 'face',
            'layer_name' => _to_utf8(f.respond_to?(:layer) ? f.layer : ''),
            'outer_loop_vertex_count' => f.respond_to?(:outer_loop_vertex_count) ?
                                           f.outer_loop_vertex_count.to_i : 0,
            'inner_loop_count' => f.respond_to?(:inner_loop_count) ?
                                    f.inner_loop_count.to_i : 0,
            'coherence_source_ref' => ref
          }
        end
        source_face_descs.sort_by! { |d| _encode_normalized(d) }

        source_layer_descs = source_layers.map do |l|
          {
            'name' => _to_utf8(l.respond_to?(:name) ? l.name : ''),
            'role' => _to_utf8(l.respond_to?(:role) ?
                        (l.role.is_a?(Symbol) ? l.role.to_s : l.role.to_s) : 'UNKNOWN'),
            'role_rule' => _to_utf8(l.respond_to?(:role_rule) ? (l.role_rule ? l.role_rule.to_s : nil) : nil),
            'visible' => l.respond_to?(:visible) ? (l.visible ? true : false) : true,
            'visibility_unknown' => l.respond_to?(:visibility_unknown) ?
                                      (l.visibility_unknown ? true : false) : false,
            'edge_count' => l.respond_to?(:edge_count) ? l.edge_count.to_i : 0,
            'face_count' => l.respond_to?(:face_count) ? l.face_count.to_i : 0,
            'faces_with_holes_count' => l.respond_to?(:faces_with_holes_count) ?
                                          l.faces_with_holes_count.to_i : 0
          }
        end
        source_layer_descs.sort_by! { |d| _encode_normalized(d) }

        analysis_edges = []
        analysis_faces = []
        analysis_layers = []
        if geom && geom.respond_to?(:edges)
          Array(geom.edges).each do |e|
            ref = _coherence_source_ref(e.respond_to?(:source) ? e.source : nil)
            s = _endpoint_xyz(e.start_point)
            t = _endpoint_xyz(e.end_point)
            analysis_edges << {
              'kind' => 'edge',
              'canonical_endpoints' => (s && t) ? _canonical_edge_endpoints(s, t) : nil,
              'layer_name' => _to_utf8(e.respond_to?(:layer) ? e.layer : ''),
              'coherence_source_ref' => ref
            }
          end
        end
        if geom && geom.respond_to?(:faces)
          Array(geom.faces).each do |f|
            ref = _coherence_source_ref(f.respond_to?(:source) ? f.source : nil)
            analysis_faces << {
              'kind' => 'face',
              'layer_name' => _to_utf8(f.respond_to?(:layer) ? f.layer : ''),
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
              'name' => _to_utf8(l.respond_to?(:name) ? l.name : ''),
              'role' => _to_utf8(l.respond_to?(:role) ?
                          (l.role.is_a?(Symbol) ? l.role.to_s : l.role.to_s) : 'UNKNOWN'),
              'role_rule' => _to_utf8(l.respond_to?(:role_rule) ? (l.role_rule ? l.role_rule.to_s : nil) : nil),
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
        analysis_edges.sort_by! { |d| _encode_normalized(d) }
        analysis_faces.sort_by!  { |d| _encode_normalized(d) }
        analysis_layers.sort_by! { |d| _encode_normalized(d) }

        source_digest = _sha256_hex(
          _encode_normalized({
            'edges' => source_edge_descs,
            'faces' => source_face_descs,
            'layers' => source_layer_descs
          })
        )
        analysis_digest = _sha256_hex(
          _encode_normalized({
            'edges' => analysis_edges,
            'faces' => analysis_faces,
            'layers' => analysis_layers
          })
        )

        unless source_digest == analysis_digest
          blockers << REASON_COHERENCE_DIGEST_MISMATCH
          return [nil, blockers]
        end

        # ----- B1-SR-04: incomplete PID occurrence coherence -----------
        # R3-01: the v1.3 §1.6 shape gate is now applied to
        # ALL SourceReference participants (SourceSnapshot +
        # Analysis geometry edges/faces) in the pre-pass at
        # the top of this method. The registry-issue-source
        # hash gate is ALSO retained (registry issue sources
        # are Hash literals describing incomplete occurrences
        # that may not be present as a SourceReference on any
        # edge/face in the SourceSnapshot / Analysis geometry
        # — they participate in the B1 issue projection,
        # not the coherence descriptor computation).
        registry = analysis_result.registry
        registry_issues = registry && registry.respond_to?(:issues) ?
                            Array(registry.issues) : []
        registry_issues.each do |iss|
          Array(iss[:sources]).each do |src|
            next unless src.is_a?(Hash)
            next if src[:pid_path_complete]
            struct_depth = src[:structural_depth]
            unless struct_depth.is_a?(Integer) && struct_depth >= 0
              blockers << REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                              ':bad_structural_depth'
              break
            end
            instance_path = Array(src[:instance_path] || src['instance_path'])
            entity_id = src[:entity_id]
            if struct_depth > 0
              if instance_path.empty?
                blockers << REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                                ':nested_instance_path_empty'
                break
              end
              instance_path.each do |el|
                unless el.is_a?(String) && !el.empty? &&
                       el.respond_to?(:encoding) &&
                       el.encoding.name == 'UTF-8' &&
                       el.valid_encoding?
                  blockers << REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                                  ':nested_instance_path_element_invalid'
                  break
                end
              end
              break if blockers.any?
            else
              unless entity_id.is_a?(Integer)
                blockers << REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                                ':rooted_incomplete_entity_id_required'
                break
              end
            end
          end
          break if blockers.any?
        end
        return [nil, blockers] unless blockers.empty?

        # ----- Registry edge ID resolution ----------------------------
        # FR-03: Analysis geometry EdgeRecord.id MUST be
        # non-nil and unique. Duplicates or nils BLOCK rather
        # than overwrite.
        analysis_edge_by_id = {}
        analysis_edge_ids_seen = {}
        if geom && geom.respond_to?(:edges)
          Array(geom.edges).each do |e|
            id_raw = e.respond_to?(:id) ? e.id : nil
            if id_raw.nil?
              blockers << REASON_REGISTRY_EDGE_MISSING +
                              ':analysis_edge_id_nil'
              break
            end
            id_str = id_raw.to_s
            if analysis_edge_ids_seen.key?(id_str)
              blockers << REASON_REGISTRY_EDGE_NOT_IN_SOURCE +
                              ":analysis_edge_id_duplicate:#{id_str}"
              break
            end
            analysis_edge_ids_seen[id_str] = true
            analysis_edge_by_id[id_str] = e
          end
        end
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

      # R3-01 + R4-02: validate every SourceReference
      # participating in Source↔Analysis coherence and return
      # the proper descriptor.
      #
      # Returns [blockers, descriptor].
      #
      # R4-02 ADDITIVE: branch selection is itself validated
      # via the SourceReference construction_facts seam. The
      # Builder MUST consult those facts BEFORE trusting any
      # normalized accessor value. This is the only seam
      # required to fail closed on malformed raw constructor
      # inputs that are otherwise irreversibly normalized
      # (entity_id: "123" -> 123, pid_path_complete: "false"
      # -> false, persistent_id_path: [1, nil, 2] -> [1, 2],
      # instance_path: "A" -> "A", etc.).
      #
      # Branch selection rules (per
      # Prompt/AIPM_V1_9B1_R4_SOURCE_REFERENCE_RAW_SHAPE_PROVENANCE_CLOSURE_2026-09-15.md):
      #
      #   Before choosing COMPLETE vs INCOMPLETE:
      #     - pid_path_complete constructor input MUST be exact
      #       Boolean (true OR false); a String "false" / "true"
      #       or nil is rejected and the ref BLOCKS with
      #       :pid_path_complete_not_boolean.
      #     - persistent_id_path constructor input MUST be an
      #       Array.
      #     - Every persistent_id_path member MUST be exact
      #       Integer; no nil / non-Integer member may be
      #       silently removed or coerced (the new
      #       SourceReference fallback keeps the .compact legacy
      #       semantics for VALID Integer arrays but the
      #       construction_facts record the original shape so
      #       B1 can BLOCK).
      #
      # Complete stable PID branch (pid_path_complete == true
      # AND persistent_id_path non-empty):
      #   - minimal descriptor: kind + persistent_id_path ONLY.
      #   - Stable path alone determines coherence provenance.
      #   - Does NOT depend on entity_id, instance_path,
      #     structural_depth, persistent_id leaf copy, or
      #     SourceReference.layer_name.
      #   - Edge/face `layer_name` is a separate field on the
      #     containing coherence descriptor (not on this
      #     source ref).
      #
      # Incomplete branch (pid_path_complete == false):
      #   - full descriptor per v1.3 §1.6:
      #     kind + structural_depth + persistent_id_path +
      #     instance_path + entity_id + persistent_id
      #     (when present) + layer_name.
      #   - All required fields validated as exact shapes (see
      #     construction_facts below). Any malformed field =>
      #     ambiguous_incomplete_occurrence:* BLOCKED, no raise.
      #
      # nil or non-SourceReference => unresolved descriptor,
      # no blockers (nil source is a legitimate test fixture).
      def _validate_coherence_source_reference(source_ref)
        unresolved = {
          'kind'                => 'unresolved',
          'structural_depth'    => 0,
          'persistent_id_path'  => [],
          'instance_path'       => [],
          'entity_id'           => nil,
          'persistent_id'       => nil,
          'layer_name'          => ''
        }
        if source_ref.nil? || !source_ref.is_a?(SourceReference)
          return [[], unresolved]
        end

        # R4-02: read the immutable construction-input facts
        # captured BEFORE any normalization. If the seam is
        # missing for any reason (e.g. an old fixture that
        # somehow pre-dates R4), treat as a fail-closed neutral
        # set so the rest of the validation still runs.
        cf = source_ref.construction_facts
        cf = {} unless cf.is_a?(Hash)
        cf_entity_id_exact_integer =
          cf['entity_id_exact_integer'] == true
        cf_persistent_id_integer_or_nil =
          cf['persistent_id_integer_or_nil'] == true
        cf_pid_path_is_array =
          cf['persistent_id_path_is_array'] == true
        cf_pid_path_all_integer =
          cf['persistent_id_path_all_integer'] == true
        cf_pid_path_had_invalid_member =
          cf['persistent_id_path_had_invalid_member'] == true
        cf_instance_path_is_array =
          cf['instance_path_is_array'] == true
        cf_instance_path_all_string =
          cf['instance_path_all_string'] == true
        cf_structural_depth_exact_integer =
          cf['structural_depth_exact_integer'] == true
        cf_pid_path_complete_exact_boolean =
          cf['pid_path_complete_exact_boolean'] == true
        cf_layer_name_is_string =
          cf['layer_name_is_string'] == true

        # Step 1: pid_path_complete MUST be an exact Boolean.
        # Without an exact Boolean we cannot trust branch
        # selection itself (a String "false" must NOT silently
        # become complete=false after truthiness coercion).
        unless cf_pid_path_complete_exact_boolean
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':pid_path_complete_not_boolean'],
                  unresolved]
        end

        # Step 2: persistent_id_path MUST be an Array of
        # exact Integer with no silently-removed / coerced
        # members. This is required BEFORE branch selection
        # because both branches need a trustworthy path.
        unless cf_pid_path_is_array &&
               cf_pid_path_all_integer &&
               !cf_pid_path_had_invalid_member
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':persistent_id_path_not_integer_array'],
                  unresolved]
        end

        pp = Array(source_ref.persistent_id_path).map(&:to_i)

        # Step 3: Complete stable PID branch.
        if source_ref.pid_path_complete
          if pp.empty?
            return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                       ':complete_pid_path_empty'],
                    unresolved]
          end
          # Minimal descriptor; transient fields are NOT part
          # of coherence identity for this branch.
          return [[], {
            'kind'                => 'stable_pid',
            'persistent_id_path'  => pp
          }]
        end

        # Step 4: Incomplete branch (pid_path_complete == false).
        # All v1.3 §1.6 shape requirements are re-validated as
        # exact shapes via construction_facts AND via the
        # final accessor values (defense in depth).
        unless cf_structural_depth_exact_integer
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':structural_depth_not_integer'],
                  unresolved]
        end
        sd = source_ref.structural_depth
        unless sd.is_a?(Integer) && sd >= 0
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':bad_structural_depth'],
                  unresolved]
        end

        unless cf_instance_path_is_array
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':instance_path_not_array'],
                  unresolved]
        end
        unless cf_instance_path_all_string
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':instance_path_element_invalid'],
                  unresolved]
        end
        ip = Array(source_ref.instance_path)

        unless cf_layer_name_is_string
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':layer_name_invalid'],
                  unresolved]
        end
        layer = source_ref.layer_name
        unless layer.is_a?(String) &&
               layer.respond_to?(:encoding) &&
               layer.encoding.name == 'UTF-8' &&
               layer.valid_encoding?
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':layer_name_invalid'],
                  unresolved]
        end

        unless cf_entity_id_exact_integer
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':entity_id_not_integer'],
                  unresolved]
        end
        eid = source_ref.entity_id
        unless eid.is_a?(Integer)
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':rooted_incomplete_entity_id_required'],
                  unresolved]
        end

        # R4: persistent_id must be Integer or nil as a
        # construction-input fact. The SourceReference
        # accessor may have already normalized a wrong-class
        # value to nil as a fail-closed fallback; therefore
        # the construction_facts check MUST run first
        # (before any accessor-value-based decision) so B1
        # BLOCKS even though the accessor returns nil.
        unless cf_persistent_id_integer_or_nil
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':persistent_id_not_integer'],
                  unresolved]
        end
        pid = source_ref.persistent_id
        if !pid.nil? && !pid.is_a?(Integer)
          return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                     ':persistent_id_not_integer'],
                  unresolved]
        end

        # Nested-depth > 0: instance_path must be non-empty
        # AND every item non-empty valid UTF-8 String.
        if sd > 0
          if ip.empty?
            return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                       ':nested_instance_path_empty'],
                    unresolved]
          end
          ip.each do |el|
            unless el.is_a?(String) && !el.empty? &&
                   el.respond_to?(:encoding) &&
                   el.encoding.name == 'UTF-8' &&
                   el.valid_encoding?
              return [[REASON_INCOMPLETE_OCCURRENCE_AMBIGUOUS +
                         ':nested_instance_path_element_invalid'],
                      unresolved]
            end
          end
        end

        [[], {
          'kind'                => 'transient_entity',
          'structural_depth'    => sd,
          'persistent_id_path'  => pp,
          'instance_path'       => ip,
          'entity_id'           => eid,
          'persistent_id'       => pid,
          'layer_name'          => layer
        }]
      end

      # Legacy wrapper: returns descriptor only. Kept for
      # source compatibility with callers that don't need the
      # blocker list. Internal _compute_coherence_digest uses
      # _validate_coherence_source_reference directly so it
      # can collect blockers for ALL participants.
      def _coherence_source_ref(source_ref)
        _blockers, desc = _validate_coherence_source_reference(source_ref)
        desc
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
        # FR-08: legacy / derived digests are produced by
        # upstream code (Digest::SHA256 etc.) and returned
        # as US-ASCII. They are NOT caller-provided semantic
        # strings; normalize via the digest-only helper.
        _utf8dig = ->(s) { PreparedCadDataset.send(:_digest_only_utf8_normalize, s) }
        fp_digest = (fp && fp.respond_to?(:digest)) ? _utf8dig.call(fp.digest.to_s) : ''
        graph_dgst = canonical_graph.respond_to?(:digest) ?
                       _utf8dig.call(canonical_graph.digest.to_s) : ''
        struct_dgst = (structure_result[:digest] ||
                       structure_result['digest']).to_s
        struct_dgst = _utf8dig.call(struct_dgst)
        cap = ''
        if source_snapshot.respond_to?(:captured_at)
          cap = source_snapshot.captured_at.to_s
        end
        sel = source_snapshot.respond_to?(:selection_scope) ?
                source_snapshot.selection_scope : []
        topo_legacy = {
          'schema_version' => (topology_snapshot[:schema_version] ||
                                topology_snapshot['schema_version']).to_s,
          'canonical_node_count' => Array(topology_snapshot[:canonical_nodes] ||
                                           topology_snapshot['canonical_nodes']).length,
          'endpoint_count' => Array(topology_snapshot[:endpoints] ||
                                     topology_snapshot['endpoints']).length,
          'endpoint_keys' => Array(topology_snapshot[:endpoints] ||
                                    topology_snapshot['endpoints']).map do |ep|
            ep.respond_to?(:endpoint_key) ? ep.endpoint_key.to_s : nil
          end.compact.sort
        }
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

      def _blocked(blockers, truncation_context = nil)
        out = { 'status' => STATUS_BLOCKED, 'dataset' => nil,
                'blockers' => Array(blockers).uniq.sort }
        unless truncation_context.nil?
          out['truncation_context'] = truncation_context
        end
        out
      end

      # Convenience: SHA-256 hex digest of `s` returned as a
      # UTF-8 String (B1-SR-12 + FR-08: digest-only
      # normalization).
      def _sha256_hex(str)
        PreparedCadDataset.send(
          :_digest_only_utf8_normalize,
          Digest::SHA256.hexdigest(str)
        )
      end

      # Wrapper that normalizes all Strings inside `v` to
      # UTF-8 (B1-SR-12 entry point) and then identity-encodes
      # it. Used in B1-SR-02 source_content_digest /
      # execution_context_digest + all sort_by IdentityBytes.
      def _encode_normalized(v)
        PreparedCadDataset::IdentityBytes.encode(
          PreparedCadDataset.send(:_normalize_strings_utf8, v)
        )
      end
    end
  end
end



