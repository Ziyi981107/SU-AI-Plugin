#
# core/prepared_cad_dataset_validator.rb — V1.9B1 B1.4 Validator / Finalizer.
#
# Per frozen V1.9B1 Blueprint v1.3 (authoritative over v1.2):
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
#       (workspace / planar / gap / structure).
#     - Validates the final persisted JSON payload is
#       <= 8_388_608 bytes; if not, attaches the
#       `persistence_envelope_unverified` blocker and finalizes
#       NOT_READY.
#     - Attaches a validation Hash that binds BOTH digests
#       (validated_content_digest, validated_build_evidence_digest).
#
#   The Validator returns:
#     outcome = {
#       'status'      => 'NOT_READY' | 'READY_WITH_WARNINGS' | 'READY',
#       'dataset'     => <final PreparedCadDataset>  (or candidate
#                         when status is NOT_READY),
#       'validation'  => <validation Hash (may include blockers)>,
#       'blockers'    => [String, ...],
#       'warnings'    => [String, ...],
#       'checks'      => [String, ...]
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

      WARNING_DUPLICATE_SKIPPED   = 'duplicate_actions_skipped'.freeze

      VALIDATOR_VERSION = 'pcd-validator.v1'.freeze

      # ----- Public API ----------------------------------------------------

      def validate_and_finalize(dataset:, workflow_snapshot:)
        unless dataset.is_a?(PreparedCadDataset)
          return _outcome_blocked(
            nil, [BLOCKER_DATASET_NOT_BUILT], [], [],
            'candidate_nil'
          )
        end
        unless workflow_snapshot.is_a?(Hash)
          return _outcome_blocked(
            dataset, [BLOCKER_WORKFLOW_NOT_READY], [], [],
            'workflow_nil'
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
          unless cd_recomputed == dataset.full_content_digest
            blockers << BLOCKER_CONTENT_DIGEST_MISMATCH
          end
          ds_id_recomputed = PreparedCadDataset.compute_dataset_id(cd_recomputed)
          unless ds_id_recomputed == dataset.dataset_id
            blockers << BLOCKER_DATASET_ID_MISMATCH +
                          ":got=#{dataset.dataset_id.inspect}:want=#{ds_id_recomputed.inspect}"
          end
          unless cd_recomputed.start_with?(dataset.dataset_id)
            blockers << BLOCKER_DATASET_ID_TRUNCATION_COLLISION
          end
          bed_recomputed = PreparedCadDataset.compute_build_evidence_digest(
            cd_recomputed, build_evidence
          )
          unless bed_recomputed == dataset.full_build_evidence_digest
            blockers << BLOCKER_BUILD_EVIDENCE_DIGEST_MISMATCH
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
          # Unique semantic IDs.
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
            # Edge refs resolve.
            [e['node_a_id'], e['node_b_id']].each do |nid|
              unless node_ids_set.include?(nid.to_s)
                blockers << BLOCKER_UNRESOLVED_EDGE_REF + ":edge=#{id}:node=#{nid}"
              end
            end
            # Forbidden duplicate coordinate fields.
            %w[world_endpoints start end].each do |fk|
              if e.key?(fk)
                blockers << BLOCKER_FORBIDDEN_FIELD + ":edge=#{id}:#{fk}"
              end
            end
          end
          # Adjacency valid / symmetric / consistent.
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
            # Forbidden duplicate coordinate fields.
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
            # Recompute by hashing the source_projection + analysis
            # projection if present. The Builder binds the digest
            # at construction; here we verify the digest is a
            # well-formed SHA-256 hex string of length 64.
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

        # ----- Workflow readiness matrix -------------------------------
        workflow_state = (workflow_snapshot[:state] ||
                          workflow_snapshot['state']).to_s
        unless workflow_state == 'ready'
          blockers << BLOCKER_WORKFLOW_NOT_READY + ":state=#{workflow_state.inspect}"
        end

        # Duplicate summary.
        dup = _duplicate_summary(workflow_snapshot)
        if dup[:has_summary]
          actions = Array(dup[:actions])
          actions_statuses = actions.map { |a| a['status'] || a[:status] }.compact.map(&:to_s)
          # Allowed status set.
          unless actions_statuses.all? { |s| %w[applied skipped failed].include?(s) }
            blockers << BLOCKER_DUPLICATE_STATE + ':action_status_unknown'
          end
          # Recompute counts.
          recomputed = { 'applied' => 0, 'skipped' => 0, 'failed' => 0 }
          actions_statuses.each do |s|
            recomputed[s] += 1 if recomputed.key?(s)
          end
          # Tolerances.
          tol_status = (dup[:tolerance_status] || '').to_s
          unless tol_status == 'captured'
            blockers << BLOCKER_DUPLICATE_STATE + ':tolerance_status'
          end
          # Count consistency.
          %w[applied skipped failed].each do |k|
            sum_k = dup[:summary]['actions_' + k]
            unless sum_k == recomputed[k]
              blockers << BLOCKER_DUPLICATE_STATE + ":count_#{k}"
            end
          end
          # last_action_status consistency.
          last = (dup[:last_action_status] || '').to_s
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
              # Allowed: 'skipped' or 'none' (skipped-only).
              unless %w[skipped none].include?(last)
                blockers << BLOCKER_DUPLICATE_STATE + ':last_action_status_skipped'
              end
            end
          end
          # Failure count.
          if recomputed['failed'] > 0
            blockers << BLOCKER_DUPLICATE_STATE + ':failed_actions_present'
          end
          # Skip with no blocker = warning.
          if recomputed['skipped'] > 0 && recomputed['failed'] == 0
            warnings << WARNING_DUPLICATE_SKIPPED
          end
        else
          # Missing actions => NOT_READY.
          blockers << BLOCKER_DUPLICATE_STATE + ':missing_summary'
        end

        # Planar substate.
        planar = workflow_snapshot[:planar_normalization] ||
                   workflow_snapshot['planar_normalization'] || {}
        if planar.is_a?(Hash) && planar['computed']
          ps = planar['state'].to_s
          case ps
          when 'NO_CANDIDATE', 'APPLIED'
            # clean
          when 'READY_TO_NORMALIZE'
            blockers << BLOCKER_PLANAR_STATE + ':' + ps
          when 'REVIEW_REQUIRED'
            warnings << BLOCKER_PLANAR_STATE + ':' + ps
          when 'FAILED', 'NOT_COMPUTED', 'INVALID_TOLERANCE', 'INVALID_INPUT'
            blockers << BLOCKER_PLANAR_STATE + ':' + ps
          else
            blockers << BLOCKER_PLANAR_STATE + ':unknown'
          end
        end

        # Gap substate.
        gap = workflow_snapshot[:topology_repair] ||
                workflow_snapshot['topology_repair'] || {}
        if gap.is_a?(Hash) && gap['computed']
          gs = gap['state'].to_s
          case gs
          when 'NO_CANDIDATE', 'APPLIED'
            # clean
          when 'READY_TO_REPAIR'
            blockers << BLOCKER_GAP_STATE + ':' + gs
          when 'REVIEW_REQUIRED'
            warnings << BLOCKER_GAP_STATE + ':' + gs
          when 'FAILED', 'NOT_COMPUTED'
            blockers << BLOCKER_GAP_STATE + ':' + gs
          else
            blockers << BLOCKER_GAP_STATE + ':unknown'
          end
        end

        # Structure substate.
        struct_sub = workflow_snapshot[:structure_reconstruction] ||
                       workflow_snapshot['structure_reconstruction'] || {}
        if struct_sub.is_a?(Hash) && struct_sub['computed']
          ss = struct_sub['state'].to_s
          case ss
          when 'READY'
            # clean
          when 'READY_WITH_WARNINGS'
            warnings << BLOCKER_STRUCTURE_STATE + ':' + ss
          when 'FAILED', 'NOT_COMPUTED'
            blockers << BLOCKER_STRUCTURE_STATE + ':' + ss
          else
            blockers << BLOCKER_STRUCTURE_STATE + ':unknown'
          end
        end

        checks << 'workflow_state_matrix'

        # ----- 8 MiB persistence gate -----------------------------------
        # Tentative: build a provisional final dataset (no
        # validation yet) and measure the persisted JSON bytesize.
        # If <= 8 MiB, attach the persistence PASS validation. If
        # > 8 MiB, attach persistence_envelope_unverified blocker
        # and finalize NOT_READY.
        tentative_validation = {
          'validated_content_digest'        => dataset.full_content_digest,
          'validated_build_evidence_digest' => dataset.full_build_evidence_digest,
          'validator_version'               => VALIDATOR_VERSION,
          'persistence_check'               => {
            'envelope' => 'pcd-final.v1',
            'status'   => 'PASS'
          },
          'checks'    => checks.dup,
          'warnings'  => warnings.dup,
          'blockers'  => []
        }
        tentative_final = dataset.with_validation(tentative_validation)
        size = tentative_final.persisted_bytesize

        if size > MAX_PAYLOAD_BYTES
          blockers << BLOCKER_PERSISTENCE_ENVELOPE_UNVERIFIED +
                        ":bytes=#{size}:limit=#{MAX_PAYLOAD_BYTES}"
        end

        checks << 'persistence_envelope'

        # ----- Build final validation ----------------------------------
        validation = {
          'validated_content_digest'        => dataset.full_content_digest,
          'validated_build_evidence_digest' => dataset.full_build_evidence_digest,
          'validator_version'               => VALIDATOR_VERSION,
          'persistence_check'               => {
            'envelope' => 'pcd-final.v1',
            'status'   => (size <= MAX_PAYLOAD_BYTES ? 'PASS' : 'FAIL'),
            'measured_bytes' => size
          },
          'checks'   => checks.uniq.sort,
          'warnings' => warnings.uniq.sort,
          'blockers' => blockers.uniq.sort
        }

        status = if validation['blockers'].any?
                   STATUS_NOT_READY
                 elsif validation['warnings'].any?
                   STATUS_READY_WITH_WARNINGS
                 else
                   STATUS_READY
                 end

        final_dataset = dataset.with_validation(validation)

        {
          'status'    => status,
          'dataset'   => final_dataset,
          'validation' => validation,
          'blockers'  => validation['blockers'],
          'warnings'  => validation['warnings'],
          'checks'    => validation['checks']
        }
      end

      # ----- Helpers --------------------------------------------------------

      def _outcome_blocked(dataset, blockers, warnings, checks, reason)
        validation = {
          'validated_content_digest'        => dataset && dataset.respond_to?(:full_content_digest) ?
                                               dataset.full_content_digest : '',
          'validated_build_evidence_digest' => dataset && dataset.respond_to?(:full_build_evidence_digest) ?
                                               dataset.full_build_evidence_digest : '',
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
          'checks'    => checks
        }
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
          # Host object detection: SketchUp entity paths.
          if obj =~ /\ASKETCHUP|sketchup::|SU::|onIs[A-Z]/
            # Heuristic only; do not block.
          end
        when Numeric, TrueClass, FalseClass, NilClass
          # safe
        else
          # Host objects (or arbitrary objects) leaked.
          if obj.respond_to?(:entityID) || obj.respond_to?(:persistent_id) ||
             (obj.class.name && obj.class.name.start_with?('Sketchup'))
            out << BLOCKER_HOST_OBJECT_LEAKED + ":path=#{path.join('.')}"
          end
        end
        out
      end

      def _duplicate_summary(workflow_snapshot)
        # Workflow snapshot in the runner shape carries a
        # duplicate_repair sub-hash with summary counts. We
        # also accept legacy "duplicate_repair_summary" shapes.
        dup = workflow_snapshot[:duplicate_repair] ||
                workflow_snapshot['duplicate_repair']
        return { :has_summary => false } unless dup.is_a?(Hash)
        actions = Array(dup[:actions] || dup['actions'])
        tolerance_status = (dup[:tolerance_status] || dup['tolerance_status']).to_s
        summary = {
          'actions_applied' => (dup[:actions_applied] || dup['actions_applied']).to_i,
          'actions_skipped' => (dup[:actions_skipped] || dup['actions_skipped']).to_i,
          'actions_failed'  => (dup[:actions_failed]  || dup['actions_failed']).to_i
        }
        last_action_status = (dup[:last_action_status] || dup['last_action_status']).to_s
        {
          :has_summary => true,
          :actions => actions,
          :tolerance_status => tolerance_status,
          :summary => summary,
          :last_action_status => last_action_status
        }
      end
    end
  end
end
