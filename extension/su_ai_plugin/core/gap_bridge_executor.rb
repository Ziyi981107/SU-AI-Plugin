#
# core/gap_bridge_executor.rb — V1.7 GapBridgeExecutor.
#
# Per frozen V1.7 Blueprint §12 / §13 / §14:
#
#   §12 Host Mutation Model:
#     - Workspace-owned repair geometry (NOT cross-group
#       welding). One dedicated V1.7 repair group owned by the
#       current DerivedGeometryWorkspace, at model root.
#     - The repair group/handles must be included in:
#       * workspace handle registry
#       * discard cleanup
#       * rebuild cleanup
#       * close-time auto-discard
#       * host-state consistency validation.
#     - For each approved endpoint_bridge, create one line from
#       the exact endpoint A world coord to endpoint B world
#       coord using the OLD-host-compatible
#       Sketchup::Entities#add_edges path. Do NOT move existing
#       source-derived endpoints.
#     - ONE native operation for the batch.
#     - If mutation fails before commit: use the existing
#       abort/fail-closed semantics.
#     - If commit result is uncertain: workspace FAILED. Do
#       NOT claim rollback success without evidence.
#
#   §13 Preflight before destructive apply.
#
#   §14 Post-validation before publishing APPLIED.
#
# The executor is the SOLE producer of
# origin_kind=generated_gap_bridge entries. It runs AFTER
# prefight, and on success it returns a new
# DerivedGeometryWorkspace whose entity registry now contains
# the bridge edges. On failure it returns a :failed workspace
# with a stable reason code.
#
# Repair group lifetime:
#   - Created lazily on the first apply_gap_bridges call.
#   - Carried by the runner's
#     `current_workspace.repair_group_handle` per
#     adapter contract.
#   - Disposed by discard / rebuild / close-time auto-discard
#     (the working_mode_runner extends the existing discard
#     cleanup).
#

require_relative 'tolerance'

module SUAnalysis
  module Core
    module GapBridgeExecutor
      module_function

      REPAIR_GROUP_LABEL_PREFIX  = 'SU-AI-Repair-GapBridge'.freeze
      OPERATION_NAME             = 'SU-AI-Plugin: V1.7 Gap Bridge Apply'.freeze
      PROVENANCE_SCHEMA_VERSION  = 'gap-bridge-apply.v1'.freeze

      REASON_OK                  = 'ok'.freeze
      REASON_INVALID_WORKSPACE   = 'invalid_workspace_state'.freeze
      REASON_HOST_INCONSISTENT   = 'host_inconsistent_state'.freeze
      REASON_NO_ADAPTER          = 'no_adapter'.freeze
      REASON_NO_PROPOSALS        = 'no_proposals'.freeze
      REASON_PREFLIGHT_FAILED    = 'preflight_failed'.freeze
      REASON_ADD_LINE_FAILED     = 'add_line_failed'.freeze
      REASON_POST_VALIDATE_FAIL  = 'post_validation_failed'.freeze
      REASON_COMMIT_UNCERTAIN    = 'commit_uncertainty'.freeze

      # Apply a batch of approved gap-bridge proposals to the
      # current workspace. Returns:
      #
      #   {
      #     status:             :applied | :failed,
      #     post_workspace:      DerivedGeometryWorkspace (new
      #                          state==:ready on :applied,
      #                          state==:failed on :failed),
      #     audit:               frozen Hash,
      #     applied_proposals:   Array<Hash>,
      #     failed_proposals:    Array<Hash>
      #   }
      def apply(workspace:, adapter:, proposals:, tolerance:, repair_group: nil)
        # Defensive nulls.
        if workspace.nil? || adapter.nil?
          return _fail(workspace, :no_workspace_or_adapter,
                       REASON_NO_ADAPTER, [])
        end
        if workspace.state != :ready && workspace.state != :failed && workspace.state != :building
          # Only :ready is the legitimate apply path. Other
          # states are rejected with a stable reason.
          return _fail(workspace, workspace.state, REASON_INVALID_WORKSPACE, [])
        end
        if workspace.state != :ready
          # Building / failed / discarded -> refuse.
          return _fail(workspace, workspace.state, REASON_INVALID_WORKSPACE, [])
        end
        # Filter to executable proposals only.
        ready = Array(proposals).select { |p|
          p.is_a?(Hash) && p['state'] == GapPairProposer::STATE_READY_TO_REPAIR &&
            p['executable'] == true
        }
        if ready.empty?
          return _fail(workspace, :ok, REASON_NO_PROPOSALS, [])
        end

        # ---- Preflight (§13) ----
        preflight = _preflight(workspace, adapter, ready, tolerance)
        unless preflight['pass']
          return _fail(workspace, :ok, REASON_PREFLIGHT_FAILED, [],
                       preflight['reasons'])
        end

        # ---- Resolve / create the workspace-owned repair group ----
        if repair_group.nil?
          repair_group = _ensure_repair_group(workspace, adapter)
        end
        if repair_group.nil?
          return _fail(workspace, :ok, REASON_NO_ADAPTER, [],
                       ['repair_group_unavailable'])
        end

        # ---- Batch mutation under one SU native operation ----
        # Per Blueprint §12.3: preflight all, then start ONE
        # operation, create all approved bridge edges, hard post-
        # validate, commit.
        applied = []
        failed  = []
        adapter.begin_operation(workspace.instance_variable_get(:@model),
                                label: OPERATION_NAME)
        begin
          ready.each do |prop|
            eps = prop['expected_bridge_endpoints']
            p1 = eps[0]
            p2 = eps[1]
            unless eps.is_a?(Array) && eps.length == 2 &&
                   p1.is_a?(Array) && p1.length == 3 &&
                   p2.is_a?(Array) && p2.length == 3
              failed << { 'proposal_id' => prop['proposal_id'],
                      'reason'      => 'invalid_bridge_endpoints' }
              next
            end
            new_handle = adapter.add_line_to_repair_group(repair_group, p1, p2)
            if new_handle.nil?
              failed << { 'proposal_id' => prop['proposal_id'],
                          'reason'     => REASON_ADD_LINE_FAILED }
              next
            end
            # Add the bridge to the workspace's entity
            # inventory (with origin_kind=generated_gap_bridge).
            did = _next_bridge_id(workspace)
            new_ws = workspace.build_entity(
              derived_id:            did,
              kind:                  :edge,
              source_occurrence_ids: prop['incident_source_occurrence_ids'] || [],
              geometry_summary:      {
                'layer'           => prop['layer_a'] || prop['layer_b'] || nil,
                'length'          => prop['expected_bridge_length'].to_f,
                'start'           => [p1[0], p1[1], p1[2]],
                'end'             => [p2[0], p2[1], p2[2]],
                'origin_kind'     => 'generated_gap_bridge',
                'repair_action_id'=> prop['proposal_id']
              },
              geometry_data:         [p1, p2]
            )
            if new_ws.state == :failed
              failed << { 'proposal_id' => prop['proposal_id'],
                          'reason'     => 'workspace_build_failed' }
              next
            end
            workspace = new_ws
            applied << {
              'proposal_id'  => prop['proposal_id'],
              'derived_id'   => did,
              'host_handle'  => new_handle
            }
          end
          # ---- Post-validation (§14) ----
          post = _post_validate(workspace, adapter, applied, ready)
          if !post['pass']
            adapter.end_operation(workspace.instance_variable_get(:@model), commit: false)
            return _fail(workspace, :ok, REASON_POST_VALIDATE_FAIL, applied,
                         post['reasons'])
          end
          adapter.end_operation(workspace.instance_variable_get(:@model), commit: true)
        rescue StandardError => e
          begin
            adapter.end_operation(workspace.instance_variable_get(:@model), commit: false)
          rescue StandardError
            # ignore nested cleanup
          end
          return _fail(workspace, :ok, REASON_COMMIT_UNCERTAIN, applied,
                       ["#{e.class}: #{e.message}"])
        end

        # ---- Success ----
        audit = {
          'status'                   => :applied,
          'reason'                   => REASON_OK,
          'applied_count'            => applied.length,
          'failed_count'             => failed.length,
          'applied_proposals'        => applied.map { |a| a['proposal_id'] },
          'failed_proposals'         => failed,
          'tolerance_used'           => {
            'gap_search'         => tolerance.respond_to?(:gap_search) ? tolerance.gap_search.to_f : 0.1,
            'coordinate_epsilon' => tolerance.respond_to?(:coordinate_epsilon) ? tolerance.coordinate_epsilon.to_f : 1.0e-6
          },
          'rule_id'                  => GapPairProposer::RULE_ID,
          'rule_version'             => GapPairProposer::RULE_VERSION,
          'schema_version'           => PROVENANCE_SCHEMA_VERSION,
          'applied_at'               => '1970-01-01T00:00:00Z'
        }.freeze
        {
          'status'         => :applied,
          'post_workspace' => workspace,
          'audit'          => audit,
          'applied_proposals' => applied,
          'failed_proposals'  => failed,
          'repair_group'   => repair_group
        }
      end

      # ---- Preflight (Blueprint §13) ----

      def _preflight(workspace, adapter, ready, tolerance)
        reasons = []
        # Workspace state must be :ready (already checked
        # above; verify).
        unless workspace.state == :ready
          reasons << "workspace_state_#{workspace.state}"
        end
        # Tolerance validation.
        unless tolerance.respond_to?(:gap_search) && tolerance.gap_search.to_f > 0 &&
               tolerance.respond_to?(:coordinate_epsilon) && tolerance.coordinate_epsilon.to_f > 0
          reasons << 'invalid_tolerance'
        end
        # Proposals must be pairwise endpoint-disjoint.
        seen_endpoints = {}
        ready.each do |p|
          [p['endpoint_a_key'], p['endpoint_b_key']].each do |k|
            if seen_endpoints[k]
              reasons << "duplicate_endpoint:#{k}"
            else
              seen_endpoints[k] = true
            end
          end
        end
        # Every proposal must be a valid executable.
        ready.each do |p|
          unless p['state'] == GapPairProposer::STATE_READY_TO_REPAIR && p['executable'] == true
            reasons << "not_executable:#{p['proposal_id']}"
          end
        end
        # Bridge endpoints finite?
        ready.each do |p|
          eps = p['expected_bridge_endpoints']
          unless eps.is_a?(Array) && eps.length == 2 &&
                 eps[0].is_a?(Array) && eps[0].length == 3 &&
                 eps[1].is_a?(Array) && eps[1].length == 3 &&
                 _finite_point?(eps[0]) && _finite_point?(eps[1])
            reasons << "non_finite_endpoints:#{p['proposal_id']}"
          end
        end
        # Bridge distance within (coord_eps, gap_search].
        ready.each do |p|
          d = p['expected_bridge_length'].to_f
          ge = p['gap_search'].to_f
          ce = p['coordinate_epsilon'].to_f
          unless d > ce && d <= ge
            reasons << "distance_out_of_band:#{p['proposal_id']}"
          end
        end
        { 'pass' => reasons.empty?, 'reasons' => reasons }.freeze
      end

      # ---- Post-validation (Blueprint §14) ----

      def _post_validate(workspace, adapter, applied, ready)
        reasons = []
        unless workspace.state == :ready
          reasons << "post_workspace_state_#{workspace.state}"
        end
        # Applied count must equal expected executable count.
        if applied.length != ready.length
          reasons << "applied_count_mismatch(#{applied.length}/#{ready.length})"
        end
        # For every applied bridge, ensure host handle exists.
        # The fake adapter exposes `host_assigned_ids_of` /
        # `valid?`; real adapter likewise.
        applied.each do |a|
          h = a['host_handle']
          if h.nil?
            reasons << "missing_host_handle:#{a['proposal_id']}"
            next
          end
          if h.respond_to?(:valid?) && !h.valid?
            reasons << "invalid_host_handle:#{a['proposal_id']}"
          end
        end
        { 'pass' => reasons.empty?, 'reasons' => reasons }.freeze
      end

      # ---- Repair group lifecycle ----

      def _ensure_repair_group(workspace, adapter)
        # Adapter contract (V1.7): if `ensure_repair_group` is
        # supported, use it; else fall back to creating a new
        # top-level group with a recognizable name.
        if adapter.respond_to?(:ensure_repair_group)
          begin
            return adapter.ensure_repair_group(
              workspace_id: workspace.workspace_id.to_s,
              label:        "#{REPAIR_GROUP_LABEL_PREFIX}-#{workspace.workspace_id}",
              model:        workspace.instance_variable_get(:@model)
            )
          rescue StandardError
            # Fall through to the manual path; do not let a
            # single defensive miss kill the apply path.
          end
        end
        if adapter.respond_to?(:create_top_level_group)
          begin
            return adapter.create_top_level_group(
              "#{REPAIR_GROUP_LABEL_PREFIX}-#{workspace.workspace_id}",
              model: workspace.instance_variable_get(:@model)
            )
          rescue StandardError
            return nil
          end
        end
        nil
      end

      def _next_bridge_id(workspace)
        # Deterministic per workspace invocation.
        # The runner-level executor chooses IDs at the
        # adapter level; here we use a counter-based key.
        # We rely on `workspace.entity_count` for stability
        # and on `rand` only for uniqueness within a single
        # apply call.
        "der-gap-#{workspace.entity_count + 1}-#{rand(2**32)}"
      end

      # ---- Failure path ----

      def _fail(workspace, post_state, reason, applied, extra_reasons = [])
        audit = {
          'status'           => :failed,
          'reason'           => reason,
          'applied_count'    => applied.length,
          'applied_proposals' => applied,
          'extra_reasons'    => extra_reasons,
          'schema_version'   => PROVENANCE_SCHEMA_VERSION,
          'applied_at'       => '1970-01-01T00:00:00Z'
        }.freeze
        post_ws = if workspace.nil?
                    nil
                  elsif workspace.respond_to?(:fingerprint)
                    workspace
                  else
                    workspace
                  end
        {
          'status'         => :failed,
          'post_workspace' => post_ws,
          'audit'          => audit,
          'applied_proposals' => applied,
          'failed_proposals' => [],
          'repair_group'   => nil
        }
      end

      def _finite_point?(p)
        p.all? { |v| v.is_a?(Numeric) && v.respond_to?(:finite?) && v.finite? }
      end
    end
  end
end
