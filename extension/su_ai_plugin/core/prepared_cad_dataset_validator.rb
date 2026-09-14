#
# core/prepared_cad_dataset_validator.rb — V1.9B1 B1.4 Validator / Finalizer.
#
# Per frozen V1.9B1 Blueprint v1.3 (authoritative over v1.2)
# AND AIPM V1.9B1 B1.2-B1.4 Source Review Correction 2026-09-14:
#
#   PreparedCadDatasetValidator is the pure finalizer. It:
#
#     - Re-runs ALL non-size structural checks against the
#       candidate dataset.
#     - Re-computes content_digest, build_evidence_digest,
#       source_content_digest, execution_context_digest, and
#       dataset_id derivation to ensure they match the stored
#       values.
#     - Validates the workflow readiness state matrix
#       (workspace / planar / gap / structure) in FAIL-CLOSED
#       mode (B1-SR-10).
#     - Validates the final persisted JSON payload is
#       <= 8_388_608 bytes (B1-SR-11). If not, attaches the
#       `persistence_envelope_unverified` blocker and finalizes
#       NOT_READY.
#     - Attaches a validation Hash that binds BOTH digests
#       (validated_content_digest, validated_build_evidence_digest)
#       using the SAME full 64-hex values published on the
#       candidate (B1-SR-01).
#
#   Source Review Correction contracts implemented here:
#     B1-SR-01: validated_content_digest / validated_build_evidence_digest
#               are the SAME full 64-hex values the candidate
#               publishes.
#     B1-SR-02: recompute + verify source_content_digest /
#               execution_context_digest.
#     B1-SR-10: workspace / planar / gap / structure subhashes
#               are each REQUIRED; computed is an explicit
#               Boolean coherent with state; missing /
#               malformed / computed=false / unknown /
#               contradiction => NOT_READY. Production
#               lowercase invalid_tolerance / invalid_input
#               treated as fail-closed. Duplicate actions
#               array is required and must be Array; each row
#               Hash with required allowlisted status; counts
#               must be non-negative Integers (no .to_i coercion
#               from malformed values); last_action_status exact
#               allowlist / consistency.
#     B1-SR-11: 8 MiB gate. PASS path: the FINAL persisted
#               JSON (the one actually attached to the dataset)
#               is BYTE-IDENTICAL to the measured payload; no
#               `measured_bytes` is persisted inside the
#               measured payload. measured_bytes is exposed
#               OUT-OF-BAND in the outcome / report. Boundary
#               tests at 8_388_608 PASS and 8_388_609 FAIL.
#     B1-SR-12: valid UTF-8 required for identity / public
#               semantic Strings.
#
#   The Validator returns:
#     outcome = {
#       'status'      => 'NOT_READY' | 'READY_WITH_WARNINGS' | 'READY',
#       'dataset'     => <final PreparedCadDataset>  (or candidate
#                         when status is NOT_READY),
#       'validation'  => <validation Hash (may include blockers)>,
#       'blockers'    => [String, ...],
#       'warnings'    => [String, ...],
#       'checks'      => [String, ...],
#       'persisted_bytes' => <Integer> (out-of-band measurement)
#     }
#
#   Rules:
#     - Any blocker  => NOT_READY
#     - No blocker + warning => READY_WITH_WARNINGS
#     - No blocker + no warning => READY
#
#   Unknown / missing / malformed state must fail closed.
#
#   Validation never defines semantic identity; it only binds
#   the existing two full digests.
#
#   B1.4 does NOT modify WorkingModeRunner, persistence, UI,
#   or RBZ packaging.
#

require 'digest'
require 'json'

require_relative 'prepared_cad_dataset'
require_relative 'prepared_cad_dataset_builder'

module SUAnalysis
  module Core
    module PreparedCadDatasetValidator
      module_function

      STATUS_NOT_READY          = 'NOT_READY'.freeze
      STATUS_READY_WITH_WARNINGS = 'READY_WITH_WARNINGS'.freeze
      STATUS_READY              = 'READY'.freeze

      MAX_PAYLOAD_BYTES = 8 * 1024 * 1024  # 8_388_608

      # Stable blocker / warning codes.
      BLOCKER_DATASET_NOT_BUILT    = 'dataset_not_built'.freeze
      BLOCKER_CONTENT_DIGEST_MISMATCH = 'content_digest_mismatch'.freeze
      BLOCKER_BUILD_EVIDENCE_DIGEST_MISMATCH =
        'build_evidence_digest_mismatch'.freeze
      BLOCKER_DATASET_ID_MISMATCH  = 'dataset_id_mismatch'.freeze
      BLOCKER_DATASET_ID_TRUNCATION_COLLISION =
        'dataset_id_truncation_collision'.freeze
      BLOCKER_SCHEMA_VERSION      = 'schema_version_invalid'.freeze
      BLOCKER_TOP_LEVEL_SHAPE      = 'top_level_shape_invalid'.freeze
      BLOCKER_DUPLICATE_SEMANTIC_ID = 'duplicate_semantic_id'.freeze
      BLOCKER_INVALID_NODE_XYZ     = 'invalid_node_xyz'.freeze
      BLOCKER_UNRESOLVED_EDGE_REF  = 'unresolved_edge_ref'.freeze
      BLOCKER_INVALID_ADJACENCY    = 'invalid_adjacency'.freeze
      BLOCKER_UNRESOLVED_CHAIN_REF = 'unresolved_chain_ref'.freeze
      BLOCKER_UNRESOLVED_LOOP_REF  = 'unresolved_loop_ref'.freeze
      BLOCKER_UNRESOLVED_REGION_REF = 'unresolved_region_ref'.freeze
      BLOCKER_INVALID_ISSUE_REF    = 'invalid_issue_ref'.freeze
      BLOCKER_PERSISTENCE_ENVELOPE_UNVERIFIED =
        'persistence_envelope_unverified'.freeze
      BLOCKER_WORKFLOW_NOT_READY   = 'workflow_not_ready'.freeze
      BLOCKER_WORKSPACE_STATE      = 'workspace_state_invalid'.freeze
      BLOCKER_DUPLICATE_STATE      = 'duplicate_state_invalid'.freeze
      BLOCKER_PLANAR_STATE         = 'planar_state_invalid'.freeze
      BLOCKER_GAP_STATE            = 'gap_state_invalid'.freeze
      BLOCKER_STRUCTURE_STATE      = 'structure_state_invalid'.freeze
      BLOCKER_HOST_OBJECT_LEAKED   = 'host_object_leaked'.freeze
      BLOCKER_SYMBOL_LEAKED        = 'symbol_leaked'.freeze
      BLOCKER_INVALID_UTF8         = 'invalid_utf8'.freeze
      BLOCKER_TRANSIENT_ID_LEAKED  = 'transient_id_leaked'.freeze
      BLOCKER_FORBIDDEN_FIELD      = 'forbidden_duplicate_coordinate_field'.freeze
      BLOCKER_COHERENCE_DIGEST_MISMATCH = 'coherence_digest_mismatch'.freeze
      BLOCKER_NODE_REF_INVALID     = 'node_ref_invalid'.freeze
      BLOCKER_SOURCE_CONTENT_DIGEST_MISMATCH = 'source_content_digest_mismatch'.freeze
      BLOCKER_EXECUTION_CONTEXT_DIGEST_MISMATCH = 'execution_context_digest_mismatch'.freeze
      BLOCKER_WORKFLOW_SUBHASH_MISSING = 'workflow_subhash_missing'.freeze
      BLOCKER_WORKFLOW_SUBHASH_BAD_TYPE = 'workflow_subhash_bad_type'.freeze

      WARNING_DUPLICATE_SKIPPED   = 'duplicate_actions_skipped'.freeze

      VALIDATOR_VERSION = 'pcd-validator.v1'.freeze

      # ----- Public API ----------------------------------------------------

      def validate_and_finalize(dataset:, workflow_snapshot:)
        unless dataset.is_a?(PreparedCadDataset)
          return _outcome_blocked(
            nil, [BLOCKER_DATASET_NOT_BUILT], [], [],
            'candidate_nil', nil
          )
        end
        unless workflow_snapshot.is_a?(Hash)
          return _outcome_blocked(
            dataset, [BLOCKER_WORKFLOW_NOT_READY], [], [],
            'workflow_nil', nil
          )
        end

        checks = []
        blockers = []
        warnings = []

        # ----- Top-level shape + schema_version ------------------------
        unless dataset.schema_version.to_s == PreparedCadDataset::SCHEMA_VERSION
          blockers << BLOCKER_SCHEMA_VERSION +
                        ":got=#{dataset.schema_version.inspect}"
        end

        # ----- Re-compute digests --------------------------------------
        content = dataset.content
        build_evidence = dataset.build_evidence
        unless content.is_a?(Hash)
          blockers << BLOCKER_TOP_LEVEL_SHAPE + ':content'
        end
        unless build_evidence.is_a?(Hash)
          blockers << BLOCKER_TOP_LEVEL_SHAPE + ':build_evidence'
        end

        if content.is_a?(Hash) && build_evidence.is_a?(Hash)
          cd_recomputed = PreparedCadDataset.compute_content_digest(content)
          unless cd_recomputed == dataset.content_digest
            blockers << BLOCKER_CONTENT_DIGEST_MISMATCH
          end
          ds_id_recomputed = PreparedCadDataset.compute_dataset_id(cd_recomputed)
          unless ds_id_recomputed == dataset.dataset_id
            blockers << BLOCKER_DATASET_ID_MISMATCH +
                          ":got=#{dataset.dataset_id.inspect}:want=#{ds_id_recomputed.inspect}"
          end
          # B1-SR-09: dataset_id MUST start with the first 20
          # chars of the full content_digest (after the "pcd-"
          # prefix). Detect truncation collision: same prefix
          # but different full digest.
          # The dataset_id is "pcd-" + content_digest[0,20].
          unless dataset.dataset_id.start_with?(PreparedCadDataset::DATASET_ID_PREFIX) &&
                 dataset.dataset_id[4..-1] == cd_recomputed[0, PreparedCadDataset::DATASET_ID_TRUNCATED_LEN]
            blockers << BLOCKER_DATASET_ID_TRUNCATION_COLLISION
          end
          bed_recomputed = PreparedCadDataset.compute_build_evidence_digest(
            cd_recomputed, build_evidence
          )
          unless bed_recomputed == dataset.build_evidence_digest
            blockers << BLOCKER_BUILD_EVIDENCE_DIGEST_MISMATCH
          end
          # B1-SR-02: source_content_digest + execution_context_digest
          # recompute + verify.
          cd_norm = PreparedCadDataset.send(:_normalize_strings_utf8, content)
          sp = cd_norm['source_projection']
          ep = cd_norm['execution']
          if sp.is_a?(Hash)
            expected_sc = Digest::SHA256.hexdigest(
              PreparedCadDataset::IdentityBytes.encode(sp)
            ).dup.force_encoding('UTF-8')
            if cd_norm['source_content_digest'] != expected_sc
              blockers << BLOCKER_SOURCE_CONTENT_DIGEST_MISMATCH
            end
          else
            blockers << BLOCKER_SOURCE_CONTENT_DIGEST_MISMATCH + ':missing'
          end
          if ep.is_a?(Hash)
            expected_ec = Digest::SHA256.hexdigest(
              PreparedCadDataset::IdentityBytes.encode(ep)
            ).dup.force_encoding('UTF-8')
            if cd_norm['execution_context_digest'] != expected_ec
              blockers << BLOCKER_EXECUTION_CONTEXT_DIGEST_MISMATCH
            end
          else
            blockers << BLOCKER_EXECUTION_CONTEXT_DIGEST_MISMATCH + ':missing'
          end
        end

        checks << 'digest_recompute'

        # ----- JSON-safe + UTF-8 + Symbol/host object leakage ----------
        if content.is_a?(Hash)
          leakage = _scan_for_leakage(content)
          blockers.concat(leakage)
        end
        if build_evidence.is_a?(Hash)
          leakage = _scan_for_leakage(build_evidence)
          blockers.concat(leakage)
        end

        # ----- Semantic graph structural checks ------------------------
        graph = content.is_a?(Hash) ? content['semantic_graph'] : nil
        if graph.is_a?(Hash)
          seen_ids = {}
          Array(graph['nodes']).each do |n|
            id = n['node_id']
            if id.nil? || id.to_s.empty?
              blockers << BLOCKER_INVALID_NODE_XYZ + ':missing_id'
              next
            end
            if seen_ids.key?(id) && seen_ids[id] != :node
              blockers << BLOCKER_DUPLICATE_SEMANTIC_ID + ":id=#{id}"
            end
            seen_ids[id] = :node
            xyz = n['xyz']
            unless xyz.is_a?(Array) && xyz.length == 3 &&
                   xyz.all? { |v| v.is_a?(Numeric) && v.finite? }
              blockers << BLOCKER_INVALID_NODE_XYZ + ":id=#{id}"
            end
          end
          node_ids_set = Array(graph['nodes']).map { |n| n['node_id'].to_s }
          edge_ids_set = []
          Array(graph['edges']).each do |e|
            id = e['edge_id']
            if id.nil? || id.to_s.empty?
              blockers << BLOCKER_UNRESOLVED_EDGE_REF + ':missing_id'
              next
            end
            if seen_ids.key?(id) && seen_ids[id] != :edge
              blockers << BLOCKER_DUPLICATE_SEMANTIC_ID + ":id=#{id}"
            end
            seen_ids[id] = :edge
            edge_ids_set << id.to_s
            [e['node_a_id'], e['node_b_id']].each do |nid|
              unless node_ids_set.include?(nid.to_s)
                blockers << BLOCKER_UNRESOLVED_EDGE_REF + ":edge=#{id}:node=#{nid}"
              end
            end
            %w[world_endpoints start end endpoint_keys].each do |fk|
              if e.key?(fk)
                blockers << BLOCKER_FORBIDDEN_FIELD + ":edge=#{id}:#{fk}"
              end
            end
          end
          adj = graph['adjacency']
          if adj.is_a?(Hash)
            adj.each do |nid, neighbors|
              unless node_ids_set.include?(nid.to_s)
                blockers << BLOCKER_INVALID_ADJACENCY + ":orphan=#{nid}"
              end
              Array(neighbors).each do |nn|
                unless node_ids_set.include?(nn.to_s)
                  blockers << BLOCKER_INVALID_ADJACENCY + ":bad=#{nn}"
                end
                rev = adj[nn]
                unless rev.is_a?(Array) && rev.include?(nid)
                  blockers << BLOCKER_INVALID_ADJACENCY + ":asym=#{nid}-#{nn}"
                end
              end
            end
          end
        end

        # ----- Structure projection checks -----------------------------
        struct = content.is_a?(Hash) ? content['semantic_structure'] : nil
        loop_id_set = []
        if struct.is_a?(Hash)
          Array(struct['chains']).each do |c|
            cid = c['chain_id']
            if cid.nil? || cid.to_s.empty?
              blockers << BLOCKER_UNRESOLVED_CHAIN_REF + ':missing_id'
            elsif seen_ids.key?(cid) && seen_ids[cid] != :chain
              blockers << BLOCKER_DUPLICATE_SEMANTIC_ID + ":id=#{cid}"
            end
            seen_ids[cid] = :chain if cid
            Array(c['node_ids']).each do |nid|
              unless node_ids_set.include?(nid.to_s)
                blockers << BLOCKER_UNRESOLVED_CHAIN_REF + ":chain=#{cid}:node=#{nid}"
              end
            end
            Array(c['edge_ids']).each do |eid|
              unless edge_ids_set.include?(eid.to_s)
                blockers << BLOCKER_UNRESOLVED_CHAIN_REF + ":chain=#{cid}:edge=#{eid}"
              end
            end
          end
          Array(struct['loops']).each do |lp|
            lid = lp['loop_id']
            if lid.nil? || lid.to_s.empty?
              blockers << BLOCKER_UNRESOLVED_LOOP_REF + ':missing_id'
            elsif seen_ids.key?(lid) && seen_ids[lid] != :loop
              blockers << BLOCKER_DUPLICATE_SEMANTIC_ID + ":id=#{lid}"
            end
            seen_ids[lid] = :loop if lid
            loop_id_set << lid.to_s
            Array(lp['node_ids']).each do |nid|
              unless node_ids_set.include?(nid.to_s)
                blockers << BLOCKER_UNRESOLVED_LOOP_REF + ":loop=#{lid}:node=#{nid}"
              end
            end
            Array(lp['edge_ids']).each do |eid|
              unless edge_ids_set.include?(eid.to_s)
                blockers << BLOCKER_UNRESOLVED_LOOP_REF + ":loop=#{lid}:edge=#{eid}"
              end
            end
            %w[world_coordinates].each do |fk|
              if lp.key?(fk)
                blockers << BLOCKER_FORBIDDEN_FIELD + ":loop=#{lid}:#{fk}"
              end
            end
          end
          Array(struct['regions']).each do |r|
            rid = r['region_id']
            if rid.nil? || rid.to_s.empty?
              blockers << BLOCKER_UNRESOLVED_REGION_REF + ':missing_id'
            elsif seen_ids.key?(rid) && seen_ids[rid] != :region
              blockers << BLOCKER_DUPLICATE_SEMANTIC_ID + ":id=#{rid}"
            end
            seen_ids[rid] = :region if rid
            outer = r['outer_loop_id']
            unless loop_id_set.include?(outer.to_s)
              blockers << BLOCKER_UNRESOLVED_REGION_REF + ":region=#{rid}:outer_loop=#{outer}"
            end
            Array(r['hole_loop_ids']).each do |hl|
              unless loop_id_set.include?(hl.to_s)
                blockers << BLOCKER_UNRESOLVED_REGION_REF + ":region=#{rid}:hole=#{hl}"
              end
            end
          end
        end

        # ----- Issue refs typed + resolve ------------------------------
        issues = content.is_a?(Hash) ? content['current_issues'] : nil
        if issues.is_a?(Hash)
          Array(issues['issues']).each do |i|
            Array(i['refs']).each do |r|
              kind = r['kind']
              id   = r['id']
              case kind
              when 'pcd_node'
                unless node_ids_set.include?(id.to_s)
                  blockers << BLOCKER_INVALID_ISSUE_REF + ":node=#{id}"
                end
              when 'pcd_edge'
                unless edge_ids_set.include?(id.to_s)
                  blockers << BLOCKER_INVALID_ISSUE_REF + ":edge=#{id}"
                end
              when 'source_pid_path'
                pp = Array(r['persistent_id_path']).map(&:to_i)
                if pp.empty?
                  blockers << BLOCKER_INVALID_ISSUE_REF + ':empty_pid_path'
                end
              else
                blockers << BLOCKER_INVALID_ISSUE_REF + ":kind=#{kind}"
              end
            end
          end
        end

        # ----- Coherence evidence recompute (digest must match) --------
        if content.is_a?(Hash)
          coh = content['coherence_evidence']
          if coh.is_a?(Hash) && coh['digest'].is_a?(String)
            unless coh['digest'].match?(/\A[0-9a-f]{64}\z/)
              blockers << BLOCKER_COHERENCE_DIGEST_MISMATCH + ':format'
            end
          end
        end

        # ----- Forbidden fields in source projection -------------------
        if content.is_a?(Hash) && content['source_projection'].is_a?(Hash)
          sp = content['source_projection']
          %w[edge_length_sum bounding_box aggregate].each do |fk|
            if sp.key?(fk)
              blockers << BLOCKER_FORBIDDEN_FIELD + ":source:#{fk}"
            end
          end
        end

        # ----- Workflow readiness matrix (B1-SR-10) -------------------
        workflow_state = (workflow_snapshot[:state] ||
                          workflow_snapshot['state']).to_s
        unless workflow_state == 'ready'
          blockers << BLOCKER_WORKFLOW_NOT_READY + ":state=#{workflow_state.inspect}"
        end

        # Duplicate summary.
        dup = _duplicate_summary(workflow_snapshot)
        if dup[:has_summary]
          actions = Array(dup[:actions])
          actions_statuses = actions.map do |a|
            status = a['status'] || a[:status]
            raise ArgumentError, "action row not Hash: #{a.inspect}" unless a.is_a?(Hash)
            status.to_s
          end
          unless actions_statuses.all? { |s| %w[applied skipped failed].include?(s) }
            blockers << BLOCKER_DUPLICATE_STATE + ':action_status_unknown'
          end
          recomputed = { 'applied' => 0, 'skipped' => 0, 'failed' => 0 }
          actions_statuses.each do |s|
            recomputed[s] += 1 if recomputed.key?(s)
          end
          tol_status = (dup[:tolerance_status] || '').to_s
          unless tol_status == 'captured'
            blockers << BLOCKER_DUPLICATE_STATE + ':tolerance_status'
          end
          # Counts must match summary (no .to_i coercion from
          # malformed values).
          %w[applied skipped failed].each do |k|
            sum_k = dup[:summary]['actions_' + k]
            unless sum_k.is_a?(Integer) && sum_k >= 0
              blockers << BLOCKER_DUPLICATE_STATE + ":count_#{k}_malformed"
              next
            end
            unless sum_k == recomputed[k]
              blockers << BLOCKER_DUPLICATE_STATE + ":count_#{k}"
            end
          end
          last = (dup[:last_action_status] || '').to_s
          unless %w[none applied skipped failed].include?(last)
            blockers << BLOCKER_DUPLICATE_STATE + ':last_action_status_invalid'
          end
          if actions.empty?
            unless last == 'none'
              blockers << BLOCKER_DUPLICATE_STATE + ':last_action_status_nonempty'
            end
          else
            if recomputed['applied'] > 0
              unless last == 'applied'
                blockers << BLOCKER_DUPLICATE_STATE + ':last_action_status_applied'
              end
            elsif recomputed['failed'] > 0
              unless last == 'failed'
                blockers << BLOCKER_DUPLICATE_STATE + ':last_action_status_failed'
              end
            elsif recomputed['skipped'] > 0
              unless %w[skipped none].include?(last)
                blockers << BLOCKER_DUPLICATE_STATE + ':last_action_status_skipped'
              end
            end
          end
          if recomputed['failed'] > 0
            blockers << BLOCKER_DUPLICATE_STATE + ':failed_actions_present'
          end
          if recomputed['skipped'] > 0 && recomputed['failed'] == 0
            warnings << WARNING_DUPLICATE_SKIPPED
          end
        else
          blockers << BLOCKER_DUPLICATE_STATE + ':missing_summary'
        end

        # ----- Planar substate (B1-SR-10 fail-closed) ----------------
        planar = workflow_snapshot[:planar_normalization] ||
                   workflow_snapshot['planar_normalization']
        planar_state_res, planar_blockers, planar_warnings =
          _check_substate(planar, 'planar_normalization',
                          BLOCKER_PLANAR_STATE, {
                            'clean' => %w[NO_CANDIDATE APPLIED],
                            'block' => %w[READY_TO_NORMALIZE FAILED
                                           NOT_COMPUTED
                                           INVALID_TOLERANCE INVALID_INPUT],
                            'warn' => %w[REVIEW_REQUIRED]
                          })
        blockers.concat(planar_blockers)
        warnings.concat(planar_warnings)

        # ----- Gap substate (B1-SR-10 fail-closed) -------------------
        gap = workflow_snapshot[:topology_repair] ||
                workflow_snapshot['topology_repair']
        gap_state_res, gap_blockers, gap_warnings =
          _check_substate(gap, 'topology_repair',
                          BLOCKER_GAP_STATE, {
                            'clean' => %w[NO_CANDIDATE APPLIED],
                            'block' => %w[READY_TO_REPAIR FAILED
                                           NOT_COMPUTED],
                            'warn' => %w[REVIEW_REQUIRED]
                          })
        blockers.concat(gap_blockers)
        warnings.concat(gap_warnings)

        # ----- Structure substate (B1-SR-10 fail-closed) ------------
        struct_sub = workflow_snapshot[:structure_reconstruction] ||
                       workflow_snapshot['structure_reconstruction']
        struct_state_res, struct_blockers, struct_warnings =
          _check_substate(struct_sub, 'structure_reconstruction',
                          BLOCKER_STRUCTURE_STATE, {
                            'clean' => %w[READY],
                            'block' => %w[FAILED NOT_COMPUTED],
                            'warn' => %w[READY_WITH_WARNINGS]
                          })
        blockers.concat(struct_blockers)
        warnings.concat(struct_warnings)

        checks << 'workflow_state_matrix'

        # ----- 8 MiB persistence gate (B1-SR-11) ---------------------
        # Add 'persistence_envelope' BEFORE the size measurement
        # so the measurement uses the SAME checks array as the
        # final payload (B1-SR-11 byte-identical invariant).
        checks << 'persistence_envelope'
        checks = checks.uniq.sort
        blockers = blockers.uniq.sort
        warnings = warnings.uniq.sort

        # Build the EXACT final validation FIRST with the
        # current checks / warnings / blockers arrays, then
        # measure its bytesize. The measured size is the size
        # of the EXACT final payload that will be published.
        # measured_bytes is OUT-OF-BAND and is NOT persisted in
        # the measured payload.
        tentative_validation = {
          'validated_content_digest'        => dataset.content_digest,
          'validated_build_evidence_digest' => dataset.build_evidence_digest,
          'validator_version'               => VALIDATOR_VERSION,
          'persistence_check'               => {
            'envelope' => 'pcd-final.v1',
            'status'   => 'PASS'  # tentative; replaced below if too big
          },
          'checks'   => checks,
          'warnings' => warnings,
          'blockers' => blockers
        }
        size = dataset.with_validation(tentative_validation).persisted_bytesize

        if size > MAX_PAYLOAD_BYTES
          blockers << BLOCKER_PERSISTENCE_ENVELOPE_UNVERIFIED +
                        ":bytes=#{size}:limit=#{MAX_PAYLOAD_BYTES}"
          # Re-sort after mutation.
          blockers = blockers.uniq.sort
        end

        # ----- Build final validation (B1-SR-11) ----------------------
        # The final persisted JSON is BYTE-IDENTICAL to the
        # payload measured above (same validation shape).
        # The only difference: persistence_check.status reflects
        # the actual size verdict. The validator ensures that
        # the byte size does not change between the tentative
        # measurement and the final persisted payload.
        final_validation = {
          'validated_content_digest'        => dataset.content_digest,
          'validated_build_evidence_digest' => dataset.build_evidence_digest,
          'validator_version'               => VALIDATOR_VERSION,
          'persistence_check'               => {
            'envelope' => 'pcd-final.v1',
            'status'   => (size <= MAX_PAYLOAD_BYTES ? 'PASS' : 'FAIL')
          },
          'checks'   => checks,
          'warnings' => warnings,
          'blockers' => blockers
        }
        final_dataset = dataset.with_validation(final_validation)

        # ----- Byte-identical measured / persisted assertion ---------
        # The final persisted JSON MUST equal the size that we
        # measured above. Because the validation shapes are
        # identical except for persistence_check.status (which
        # is a fixed-width string 'PASS' / 'FAIL'), the bytesize
        # should be the same.
        final_size = final_dataset.persisted_bytesize
        unless final_size == size
          blockers << BLOCKER_PERSISTENCE_ENVELOPE_UNVERIFIED +
                        ':final_payload_size_mismatch_with_measurement'
          blockers = blockers.uniq.sort
        end

        status = if final_validation['blockers'].any?
                   STATUS_NOT_READY
                 elsif final_validation['warnings'].any?
                   STATUS_READY_WITH_WARNINGS
                 else
                   STATUS_READY
                 end

        # Re-attach final_dataset with the up-to-date blockers/
        # warnings arrays (since with_validation froze the
        # earlier copy).
        if final_validation['blockers'] != blockers.uniq.sort ||
           final_validation['warnings'] != warnings.uniq.sort
          final_dataset = final_dataset.with_validation(final_validation)
        end

        {
          'status'    => status,
          'dataset'   => final_dataset,
          'validation' => final_validation,
          'blockers'  => final_validation['blockers'],
          'warnings'  => final_validation['warnings'],
          'checks'    => final_validation['checks'],
          'persisted_bytes' => size
        }
      end

      # ----- Helpers --------------------------------------------------------

      def _outcome_blocked(dataset, blockers, warnings, checks, reason, persisted_bytes)
        validation = {
          'validated_content_digest'        => dataset && dataset.respond_to?(:content_digest) ?
                                               dataset.content_digest : '',
          'validated_build_evidence_digest' => dataset && dataset.respond_to?(:build_evidence_digest) ?
                                               dataset.build_evidence_digest : '',
          'validator_version'               => VALIDATOR_VERSION,
          'persistence_check'               => { 'envelope' => 'pcd-final.v1', 'status' => 'FAIL' },
          'checks'    => checks,
          'warnings'  => warnings,
          'blockers'  => blockers,
          'reason'    => reason
        }
        {
          'status'    => STATUS_NOT_READY,
          'dataset'   => dataset,
          'validation' => validation,
          'blockers'  => blockers,
          'warnings'  => warnings,
          'checks'    => checks,
          'persisted_bytes' => persisted_bytes
        }
      end

      # B1-SR-10 fail-closed substate check.
      def _check_substate(sub, name, blocker_code, classification)
        return [:missing, [BLOCKER_WORKFLOW_SUBHASH_MISSING + ':' + name], []] if sub.nil?
        return [:bad_type, [BLOCKER_WORKFLOW_SUBHASH_BAD_TYPE + ':' + name], []] unless sub.is_a?(Hash)
        computed = sub['computed']
        unless computed == true || computed == false
          return [:bad_computed,
                  [blocker_code + ':computed_not_boolean'], []]
        end
        # computed=false => not-computed-state => blocker if
        # there's any state published, otherwise fail closed.
        state = sub['state'].to_s
        if computed == false
          # If a state IS published but computed is false, that
          # is a contradiction.
          if state.empty?
            return [:not_computed, [blocker_code + ':NOT_COMPUTED'], []]
          else
            return [:contradiction,
                    [blocker_code + ':computed_false_with_state'], []]
          end
        end
        # computed=true: classify state.
        if classification['clean'].include?(state)
          [:clean, [], []]
        elsif classification['block'].include?(state)
          [state, [blocker_code + ':' + state], []]
        elsif classification['warn'].include?(state)
          [state, [], [blocker_code + ':' + state]]
        else
          [state, [blocker_code + ':unknown'], []]
        end
      end

      def _scan_for_leakage(obj, path = [])
        out = []
        case obj
        when Hash
          obj.each do |k, v|
            unless k.is_a?(String)
              out << BLOCKER_SYMBOL_LEAKED + ":path=#{(path + [k.inspect]).join('.')}"
            end
            out.concat(_scan_for_leakage(v, path + [k.to_s]))
          end
        when Array
          obj.each_with_index do |v, i|
            out.concat(_scan_for_leakage(v, path + ["[#{i}]"]))
          end
        when Symbol
          out << BLOCKER_SYMBOL_LEAKED + ":path=#{(path + [obj.inspect]).join('.')}"
        when String
          unless obj.respond_to?(:encoding) && obj.valid_encoding?
            out << BLOCKER_INVALID_UTF8 + ":path=#{path.join('.')}"
          end
        when Numeric, TrueClass, FalseClass, NilClass
          # safe
        else
          if obj.respond_to?(:entityID) || obj.respond_to?(:persistent_id) ||
             (obj.class.name && obj.class.name.start_with?('Sketchup'))
            out << BLOCKER_HOST_OBJECT_LEAKED + ":path=#{path.join('.')}"
          end
        end
        out
      end

      def _duplicate_summary(workflow_snapshot)
        dup = workflow_snapshot[:duplicate_repair] ||
                workflow_snapshot['duplicate_repair']
        return { :has_summary => false } unless dup.is_a?(Hash)
        actions_raw = dup[:actions] || dup['actions']
        return { :has_summary => false } unless actions_raw.is_a?(Array)
        tolerance_status = (dup[:tolerance_status] || dup['tolerance_status']).to_s
        summary = {
          'actions_applied' => (dup[:actions_applied] || dup['actions_applied']),
          'actions_skipped' => (dup[:actions_skipped] || dup['actions_skipped']),
          'actions_failed'  => (dup[:actions_failed]  || dup['actions_failed'])
        }
        last_action_status = (dup[:last_action_status] || dup['last_action_status']).to_s
        {
          :has_summary => true,
          :actions => actions_raw,
          :tolerance_status => tolerance_status,
          :summary => summary,
          :last_action_status => last_action_status
        }
      end
    end
  end
end
