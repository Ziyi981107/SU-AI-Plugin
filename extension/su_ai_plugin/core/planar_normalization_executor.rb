#
# core/planar_normalization_executor.rb — V1.6 Planar Normalization
# host mutation executor.
#
# Per frozen V1.6 Blueprint §8 + §9:
#
#   Apply a PlanarNormalizationProposer proposal to the live
#   DerivedGeometryWorkspace through the production adapter.
#
# Locked semantics:
#
#   Input:
#     workspace     : DerivedGeometryWorkspace (state == :ready)
#     adapter       : DerivedWorkspaceAdapter
#     proposal_hash : the frozen Hash returned by
#                     PlanarNormalizationProposer.propose (state ==
#                     READY_TO_NORMALIZE; proposal != nil)
#     tolerance     : Tolerance (for coordinate_epsilon in post-
#                     validation)
#
#   Preflight (Blueprint §8.1):
#     - workspace.state == :ready
#     - every unique vertex handle exists & is valid? on the
#       adapter
#     - target_z is finite
#     - every vector is exactly [0, 0, dz]
#     - expected post-state computed BEFORE mutation
#
#   Host mutation (Blueprint §8.2):
#     - one SketchUp native operation wraps the entire batch
#     - adapter.transform_vertices_by_vectors(handles, vectors)
#       (legacy-compatible since SketchUp 6.0)
#
#   Post-validation (Blueprint §9):
#     - |after.x - before.x| <= coordinate_epsilon
#     - |after.y - before.y| <= coordinate_epsilon
#     - |after.z - target_z| <= coordinate_epsilon
#     - moved vertex count matches the expected unique vertex set
#     - source fingerprint unchanged (workspace owns source
#       fingerprint via SourceSnapshot; we re-derive it)
#
#   Commit / failure:
#     - success: commit_operation, mark applied
#     - pre-commit failure: abort, return :failed
#     - commit uncertainty: FAILED, no false READY claim
#
#   Returns a Hash:
#     {
#       status              : :applied | :failed,
#       post_workspace      : the (possibly updated) workspace,
#       moved_vertex_count  : Integer,
#       max_movement        : Float,
#       audit               : {
#         rule_id, rule_version,
#         target_z,
#         captured_tolerance,
#         affected_derived_ids,
#         affected_source_occurrence_ids,
#         before_z_summary, after_z_summary,
#         max_movement,
#         applied_count, skipped_count, failed_count
#       }
#     }
#
# Source CAD is NEVER touched. Only derived host vertices move.
#

require_relative 'planar_normalization_proposer'
require_relative 'source_fingerprint'
require_relative 'derived_geometry_workspace'

module SUAnalysis
  module Core
    module PlanarNormalizationExecutor
      module_function

      OPERATION_LABEL = 'SU-AI-Plugin: V1.6 Planar Normalization Apply'.freeze

      # Apply the proposal. See module docstring for full
      # contract. Returns the result Hash.
      def apply(workspace:, adapter:, proposal_hash:, tolerance:)
        if workspace.nil? || adapter.nil? || proposal_hash.nil? || tolerance.nil?
          return _fail_result(workspace: workspace,
                              reason: 'missing_input',
                              proposal_hash: proposal_hash)
        end
        unless workspace.state == :ready
          return _fail_result(workspace: workspace,
                              reason: "workspace_not_ready:#{workspace.state}",
                              proposal_hash: proposal_hash)
        end
        unless proposal_hash.is_a?(Hash) && proposal_hash[:state] == PlanarNormalizationAnalyzer::STATE_READY_TO_NORMALIZE
          return _fail_result(workspace: workspace,
                              reason: "proposal_not_ready:#{proposal_hash[:state]}",
                              proposal_hash: proposal_hash)
        end
        proposal = proposal_hash[:proposal]
        unless proposal.is_a?(Hash) && proposal[:unique_vertex_handles].is_a?(Array) &&
               proposal[:unique_vertex_handles].length > 0
          return _fail_result(workspace: workspace,
                              reason: 'proposal_missing_handles',
                              proposal_hash: proposal_hash)
        end
        target_z = proposal[:target_z].to_f
        unless target_z.respond_to?(:finite?) ? target_z.finite? : (target_z.is_a?(Numeric) && !target_z.nan? && !target_z.infinite?)
          return _fail_result(workspace: workspace,
                              reason: 'non_finite_target_z',
                              proposal_hash: proposal_hash)
        end
        # ---- Preflight: handle liveness ----
        handles = proposal[:unique_vertex_handles]
        vectors = proposal[:vectors]
        unless vectors.is_a?(Array) && vectors.length == handles.length
          return _fail_result(workspace: workspace,
                              reason: 'vector_length_mismatch',
                              proposal_hash: proposal_hash)
        end
        # Capture pre-mutation positions for post-validation.
        pre_positions = handles.map do |h|
          adapter.respond_to?(:vertex_position) ? adapter.vertex_position(h) : nil
        end
        # Pre-validate every vector.
        vectors.each_with_index do |vec, i|
          unless vec.is_a?(Array) && vec.length == 3
            return _fail_result(workspace: workspace,
                                reason: "vector_malformed:#{i}",
                                proposal_hash: proposal_hash)
          end
          if vec[0] != 0.0 || vec[1] != 0.0
            return _fail_result(workspace: workspace,
                                reason: "vector_not_z_only:#{i}",
                                proposal_hash: proposal_hash)
          end
          dz = vec[2].to_f
          unless dz.respond_to?(:finite?) ? dz.finite? : true
            return _fail_result(workspace: workspace,
                                reason: "vector_nonfinite:#{i}",
                                proposal_hash: proposal_hash)
          end
        end
        # ---- Expected post-state ----
        expected_post = handles.each_with_index.map do |h, i|
          pre = pre_positions[i]
          next [0.0, 0.0, target_z] if pre.nil?
          [pre[0], pre[1], target_z]
        end
        # ---- Open operation + mutate ----
        moved = 0
        new_workspace = workspace
        begin
          adapter.begin_operation(workspace_model_for(workspace), label: OPERATION_LABEL)
          moved = adapter.transform_vertices_by_vectors(handles, vectors)
        rescue StandardError => e
          # Abort + record failure. Workspace transitions to :failed
          # via the helper.
          begin
            adapter.end_operation(workspace_model_for(workspace), commit: false)
          rescue StandardError
            # ignore secondary cleanup failure
          end
          new_workspace = _mark_workspace_failed(workspace, "host_mutation_failed:#{e.class}:#{e.message}")
          return {
            status: :failed,
            post_workspace: new_workspace,
            moved_vertex_count: 0,
            max_movement: 0.0,
            audit: _audit_row(
              proposal_hash: proposal_hash,
              workspace: new_workspace,
              applied_count: 0,
              failed_count: 1,
              reason: "host_mutation_failed:#{e.class}"
            )
          }.freeze
        end
        # ---- Post-validation ----
        eps = tolerance.coordinate_epsilon.to_f
        post_positions = handles.map { |h|
          adapter.respond_to?(:vertex_position) ? adapter.vertex_position(h) : nil
        }
        validation_errors = []
        moved_count = 0
        max_movement = 0.0
        before_zs = []
        after_zs = []
        handles.each_with_index do |h, i|
          pre = pre_positions[i]
          post = post_positions[i]
          before_zs << pre[2].to_f if pre.is_a?(Array)
          after_zs << post[2].to_f if post.is_a?(Array)
          if pre.is_a?(Array) && post.is_a?(Array)
            dx = (post[0] - pre[0]).abs
            dy = (post[1] - pre[1]).abs
            dz = (post[2] - target_z).abs
            if dx > eps
              validation_errors << "vertex_#{i}_dx_#{dx}_exceeds_eps"
            end
            if dy > eps
              validation_errors << "vertex_#{i}_dy_#{dy}_exceeds_eps"
            end
            if dz > eps
              validation_errors << "vertex_#{i}_dz_#{dz}_exceeds_eps"
            end
            m_abs = (post[2] - pre[2]).abs
            max_movement = m_abs if m_abs > max_movement
            moved_count += 1
          else
            validation_errors << "vertex_#{i}_position_unreadable"
          end
        end
        if !validation_errors.empty?
          begin
            adapter.end_operation(workspace_model_for(workspace), commit: false)
          rescue StandardError
            # ignore
          end
          new_workspace = _mark_workspace_failed(workspace, "post_validation_failed:#{validation_errors.first}")
          return {
            status: :failed,
            post_workspace: new_workspace,
            moved_vertex_count: 0,
            max_movement: 0.0,
            audit: _audit_row(
              proposal_hash: proposal_hash,
              workspace: new_workspace,
              applied_count: 0,
              failed_count: 1,
              reason: 'post_validation_failed'
            )
          }.freeze
        end
        # Commit.
        begin
          adapter.end_operation(workspace_model_for(workspace), commit: true)
        rescue StandardError => e
          # Commit failed: workspace stays usable (no mutation
          # applied) but the operation did not commit. Per
          # Blueprint §8.3: commit uncertainty => FAILED.
          new_workspace = _mark_workspace_failed(workspace, "commit_failed:#{e.class}")
          return {
            status: :failed,
            post_workspace: new_workspace,
            moved_vertex_count: 0,
            max_movement: 0.0,
            audit: _audit_row(
              proposal_hash: proposal_hash,
              workspace: new_workspace,
              applied_count: 0,
              failed_count: 1,
              reason: 'commit_failed'
            )
          }.freeze
        end
        # ---- Build the audit row + return ----
        audit = _audit_row(
          proposal_hash:   proposal_hash,
          workspace:       workspace,
          applied_count:   moved_count,
          failed_count:    0,
          before_zs:       before_zs,
          after_zs:        after_zs,
          max_movement:    max_movement.to_f,
          status:          :applied
        )
        {
          status: :applied,
          post_workspace: workspace,
          moved_vertex_count: moved_count,
          max_movement: max_movement.to_f,
          audit: audit
        }.freeze
      end

      # ---- internals ----

      def workspace_model_for(workspace)
        workspace.instance_variable_get(:@model)
      end

      def _mark_workspace_failed(workspace, reason)
        return workspace if workspace.nil?
        adapter = workspace.instance_variable_get(:@adapter)
        model   = workspace.instance_variable_get(:@model)
        DerivedGeometryWorkspace.new_with_inventory(
          workspace_id:    workspace.workspace_id,
          source_snapshot: workspace.source_snapshot,
          adapter:         adapter,
          model:           model,
          state:           :failed,
          entity_pairs:    workspace.instance_variable_get(:@entity_pairs),
          handle_registry: workspace.instance_variable_get(:@handle_registry),
          fingerprint:     workspace.respond_to?(:fingerprint) ? workspace.fingerprint : nil,
          last_error:      reason,
          build_started_at: workspace.build_started_at
        )
      end

      def _fail_result(workspace:, reason:, proposal_hash:)
        {
          status: :failed,
          post_workspace: workspace,
          moved_vertex_count: 0,
          max_movement: 0.0,
          audit: _audit_row(
            proposal_hash: proposal_hash,
            workspace: workspace,
            applied_count: 0,
            failed_count: 1,
            reason: reason
          )
        }.freeze
      end

      def _audit_row(proposal_hash:, workspace:, applied_count:, failed_count:,
                     before_zs: [], after_zs: [], max_movement: 0.0,
                     status: nil, reason: nil)
        proposal = proposal_hash.is_a?(Hash) ? proposal_hash[:proposal] : nil
        {
          rule_id:         proposal_hash.is_a?(Hash) ? proposal_hash[:rule_id] : nil,
          rule_version:    proposal_hash.is_a?(Hash) ? proposal_hash[:rule_version] : nil,
          target_z:        proposal.is_a?(Hash) ? proposal[:target_z] : nil,
          captured_tolerance: proposal_hash.is_a?(Hash) ? proposal_hash[:captured_tolerance] : nil,
          affected_derived_ids:          proposal.is_a?(Hash) ? Array(proposal[:affected_derived_ids]) : [],
          affected_source_occurrence_ids: proposal.is_a?(Hash) ? Array(proposal[:affected_source_occurrence_ids]) : [],
          outlier_derived_ids:           proposal.is_a?(Hash) ? Array(proposal[:outlier_derived_ids]) : [],
          before_z_summary: _z_summary(before_zs),
          after_z_summary:  _z_summary(after_zs),
          max_movement:     max_movement.to_f,
          applied_count:    applied_count,
          failed_count:     failed_count,
          status:           status,
          reason:           reason
        }.freeze
      end

      def _z_summary(zs)
        return { 'count' => 0, 'min' => nil, 'max' => nil, 'mean' => nil } if zs.empty?
        floats = zs.map(&:to_f)
        {
          'count' => floats.length,
          'min'   => floats.min.to_f,
          'max'   => floats.max.to_f,
          'mean'  => (floats.sum.to_f / floats.length.to_f)
        }.freeze
      end
    end
  end
end
