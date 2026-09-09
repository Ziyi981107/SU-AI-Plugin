#
# core/planar_normalization_executor.rb -V1.6 Planar Normalization
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
        # BLOCK-P0-04 (AIPM source review):
        # Validate target_z as Numeric + finite FIRST. Do NOT
        # call .to_f first to disguise malformed input (e.g.
        # nil, "1.5", Float::NAN would all become 0.0 under
        # .to_f and pass the naive finite? check).
        raw_target_z = proposal[:target_z]
        unless raw_target_z.is_a?(Numeric) &&
               (raw_target_z.respond_to?(:finite?) ? raw_target_z.finite? :
                (!raw_target_z.nan? && !raw_target_z.infinite?))
          return _fail_result(workspace: workspace,
                              reason: 'preflight_target_z_not_numeric_or_nonfinite',
                              proposal_hash: proposal_hash)
        end
        target_z = raw_target_z
        # ---- Preflight: every physical live position + vector ----
        #
        # V1.9A P0 SHARED-VERTEX CORRECTION (amendment §4.1 +
        # BLOCK-P0-04 AIPM source review): preflight EVERY
        # physical occurrence's LIVE position AND vector AND
        # handle identity BEFORE opening any SketchUp
        # operation. A failure here aborts BEFORE
        # begin_operation; we never publish a partial logical
        # success, and the host sees ZERO begin_operation
        # calls + ZERO transform_vertices_by_vectors calls.
        handles = proposal[:unique_vertex_handles]
        vectors = proposal[:vectors]
        unless vectors.is_a?(Array) && vectors.length == handles.length
          return _fail_result(workspace: workspace,
                              reason: 'preflight_vector_length_mismatch',
                              proposal_hash: proposal_hash)
        end
        # The adapter MUST expose the vertex_position seam.
        # Without it we cannot read the live current Z; any
        # mutation here would be a guess against the cached
        # pre-V1.6 coordinate, which the amendment forbids.
        unless adapter.respond_to?(:vertex_position)
          return _fail_result(workspace: workspace,
                              reason: 'preflight_no_vertex_position_seam',
                              proposal_hash: proposal_hash)
        end
        # Per-occurrence preflight: handle presence +
        # identity-uniqueness + vector shape + Z-only +
        # Numeric-Z + finite-Z + live vertex_position success
        # + Array-of-3-Numeric + finite-XYZ + consistency
        # with the logical move target within
        # coordinate_epsilon.
        eps = tolerance.coordinate_epsilon
        unless eps.is_a?(Numeric) &&
               (eps.respond_to?(:finite?) ? eps.finite? : (!eps.nan? && !eps.infinite?))
          return _fail_result(workspace: workspace,
                              reason: 'preflight_epsilon_invalid',
                              proposal_hash: proposal_hash)
        end
        seen_handle_ids = {}
        pre_positions = []
        handles.each_with_index do |h, i|
          # 1. Handle presence.
          if h.nil?
            return _fail_result(workspace: workspace,
                                reason: "preflight_nil_handle:#{i}",
                                proposal_hash: proposal_hash)
          end
          # 2. Handle identity uniqueness.
          id = h.object_id
          if seen_handle_ids.key?(id)
            return _fail_result(workspace: workspace,
                                reason: "preflight_duplicate_handle:#{i}",
                                proposal_hash: proposal_hash)
          end
          seen_handle_ids[id] = true
          # 3. Vector shape (Array length 3).
          vec = vectors[i]
          unless vec.is_a?(Array) && vec.length == 3
            return _fail_result(workspace: workspace,
                                reason: "preflight_vector_malformed:#{i}",
                                proposal_hash: proposal_hash)
          end
          # 4. Vector X / Y must be Numeric + numeric zero
          #    (NOT vec[0].to_f == 0 — that would let nil /
          #    "1.5" / Float::NAN sneak through).
          unless vec[0].is_a?(Numeric) && vec[0] == 0
            return _fail_result(workspace: workspace,
                                reason: "preflight_vector_x_not_numeric_zero:#{i}",
                                proposal_hash: proposal_hash)
          end
          unless vec[1].is_a?(Numeric) && vec[1] == 0
            return _fail_result(workspace: workspace,
                                reason: "preflight_vector_y_not_numeric_zero:#{i}",
                                proposal_hash: proposal_hash)
          end
          # 5. Vector Z must be Numeric + finite. Validate
          #    type FIRST, then convert only if Numeric.
          dz_raw = vec[2]
          unless dz_raw.is_a?(Numeric)
            return _fail_result(workspace: workspace,
                                reason: "preflight_vector_z_not_numeric:#{i}",
                                proposal_hash: proposal_hash)
          end
          unless dz_raw.respond_to?(:finite?) ? dz_raw.finite? :
                   (!dz_raw.nan? && !dz_raw.infinite?)
            return _fail_result(workspace: workspace,
                                reason: "preflight_vector_z_nonfinite:#{i}",
                                proposal_hash: proposal_hash)
          end
          dz = dz_raw.to_f
          # 6. Live vertex_position read MUST succeed.
          begin
            pos = adapter.vertex_position(h)
          rescue StandardError => e
            return _fail_result(workspace: workspace,
                                reason: "preflight_vertex_position_raised:#{i}:#{e.class}",
                                proposal_hash: proposal_hash)
          end
          # 7. Live position must be Array of exactly 3.
          unless pos.is_a?(Array) && pos.length == 3
            return _fail_result(workspace: workspace,
                                reason: "preflight_position_not_array3:#{i}",
                                proposal_hash: proposal_hash)
          end
          # 8. Live position must be 3 Numeric values.
          unless pos[0].is_a?(Numeric) && pos[1].is_a?(Numeric) && pos[2].is_a?(Numeric)
            return _fail_result(workspace: workspace,
                                reason: "preflight_position_not_numeric:#{i}",
                                proposal_hash: proposal_hash)
          end
          # 9. Live position XYZ must all be finite. Use
          #    `.to_f` only after Numeric + finite is
          #    confirmed (so nil / non-Numeric are rejected
          #    by the Numeric gate above).
          unless pos[0].respond_to?(:finite?) ? pos[0].finite? :
                   (!pos[0].nan? && !pos[0].infinite?)
            return _fail_result(workspace: workspace,
                                reason: "preflight_position_x_nonfinite:#{i}",
                                proposal_hash: proposal_hash)
          end
          unless pos[1].respond_to?(:finite?) ? pos[1].finite? :
                   (!pos[1].nan? && !pos[1].infinite?)
            return _fail_result(workspace: workspace,
                                reason: "preflight_position_y_nonfinite:#{i}",
                                proposal_hash: proposal_hash)
          end
          unless pos[2].respond_to?(:finite?) ? pos[2].finite? :
                   (!pos[2].nan? && !pos[2].infinite?)
            return _fail_result(workspace: workspace,
                                reason: "preflight_position_z_nonfinite:#{i}",
                                proposal_hash: proposal_hash)
          end
          # 10. Consistency: current physical Z must agree
          #    with the logical-move target within
          #    coordinate_epsilon. The proposal carries
          #    target_z + per-physical dz; the expected
          #    from_z is reconstructed as
          #    target_z - dz (the proposer's
          #    cluster-level from_z maps 1:1 onto every
          #    physical occurrence of the same logical
          #    cluster, so this is exact arithmetic on
          #    proposal-derived Numeric values).
          expected_from_z = target_z - dz
          unless (pos[2] - expected_from_z).abs <= eps
            return _fail_result(workspace: workspace,
                                reason: "preflight_position_inconsistent:#{i}",
                                proposal_hash: proposal_hash)
          end
          # All preflight checks pass. Capture the validated
          # Numeric position for post-validation reuse.
          pre_positions << [pos[0].to_f, pos[1].to_f, pos[2].to_f]
        end
        # ---- Open operation + mutate (V1.9A P0) ----
        #
        # Per amendment §4.2: open the existing single
        # outer operation ONCE. For each physical
        # occurrence, call the existing adapter primitive
        # with one handle / one vector. Do not pass a
        # cross-group mixed Vertex array to one primitive
        # call. Do not open nested SketchUp operations.
        moved_count_physical = 0
        new_workspace = workspace
        begin
          adapter.begin_operation(workspace_model_for(workspace), label: OPERATION_LABEL)
          handles.each_with_index do |h, i|
            adapter.transform_vertices_by_vectors([h], [vectors[i]])
            moved_count_physical += 1
          end
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
        # V1.9A P0 FINAL NARROW RESIDUAL CORRECTION
        # FINAL-R2-01 (fix 2026-09-09): the host call
        # `adapter.vertex_position(h)` is wrapped in
        # `begin/rescue StandardError` (the prior R2
        # packet). However, the downstream validation
        # loop previously performed `after_zs <<
        # post[2].to_f if post.is_a?(Array)` BEFORE
        # proving:
        #   1. entry must not be raised / missing
        #   2. `post` MUST be an Array of EXACTLY 3
        #   3. all 3 values MUST be Numeric
        #   4. all 3 values MUST be finite
        # Therefore malformed-but-Array post data
        # (e.g. `[0.0, 0.0, Object.new]`) raised
        # `NoMethodError` on `.to_f` BEFORE the executor
        # reached the unreadable-position branch.
        #
        # Required correction:
        #   - The post-validation phase is now wrapped in
        #     a final defensive `begin/rescue StandardError`
        #     boundary so any unexpected exception during
        #     post-validation aborts the outer operation
        #     ONCE, never commits, returns :failed, and
        #     publishes zero logical / physical / legacy
        #     applied success.
        #   - The per-occurrence validation order is
        #     tightened: kind != raised -> post is Array
        #     of EXACTLY 3 -> all 3 Numeric -> all 3 finite
        #     -> THEN perform any `.to_f` / subtraction /
        #     `audit append`.
        #   - The `after_zs` audit append is moved INSIDE
        #     the validation block so it only runs after
        #     the four checks pass.
        #
        # Pre-flight, fan-out, operation ownership,
        # tolerances, and proposer logic are FROZEN
        # unchanged per dispatch.
        eps = tolerance.coordinate_epsilon.to_f
        post_results = handles.map do |h|
          if !adapter.respond_to?(:vertex_position)
            # No live-read capability — treat as missing.
            { 'kind' => 'missing' }
          else
            begin
              pos = adapter.vertex_position(h)
              { 'kind' => 'ok', 'value' => pos }
            rescue StandardError => e
              # Raised host read becomes a per-occurrence
              # tagged sentinel so the downstream
              # validation logic can record the original
              # exception class verbatim. The exception
              # itself is suppressed here so the function
              # NEVER returns while the outer operation is
              # still open (the abort-once path below runs
              # cleanly to completion).
              { 'kind' => 'raised', 'class' => e.class.name }
            end
          end
        end
        validation_errors = []
        moved_count = 0
        max_movement = 0.0
        before_zs = []
        after_zs = []
        post_validation_phase_failed = false
        begin
          # FINAL-R2-01: validate the post shape BEFORE
          # any `.to_f` / numeric coercion / subtraction.
          # Order is strict: raised -> missing -> Array
          # length == 3 -> Numeric -> finite -> safe to
          # use the value.
          handles.each_with_index do |h, i|
            pre = pre_positions[i]
            entry = post_results[i]
            post = entry.is_a?(Hash) ? entry['value'] : nil
            # `pre` was already validated as a 3-Numeric-
            # finite point during preflight; the
            # numeric coercion below is therefore safe.
            # Defensive guard: still wrap pre[2] so a
            # malformed pre cannot raise here either.
            before_zs << pre[2].to_f if pre.is_a?(Array) && pre.length == 3 &&
                                        pre[0].is_a?(Numeric) && pre[1].is_a?(Numeric) &&
                                        pre[2].is_a?(Numeric)
            # FINAL-R2-01: a raised read is treated as a
            # postvalidation failure for that occurrence
            # AND we MUST NOT call `.to_f` on the value
            # (which is `nil` for a raised read; calling
            # `nil.to_f` raises NoMethodError).
            if entry.is_a?(Hash) && entry['kind'] == 'raised'
              validation_errors << "vertex_#{i}_post_read_raised:#{entry['class']}"
              next
            end
            # FINAL-R2-01: strict exactly-3 shape check
            # BEFORE any `.to_f`. A 4-element / 2-element
            # Array (or Hash / nil / etc.) is malformed
            # and fails closed WITHOUT touching `.to_f`.
            post_ok = post.is_a?(Array) &&
                      post.length == 3 &&
                      post[0].is_a?(Numeric) &&
                      post[1].is_a?(Numeric) &&
                      post[2].is_a?(Numeric)
            unless post_ok
              validation_errors << "vertex_#{i}_position_unreadable"
              next
            end
            finite =
              (!post[0].respond_to?(:finite?) || post[0].finite?) &&
              (!post[1].respond_to?(:finite?) || post[1].finite?) &&
              (!post[2].respond_to?(:finite?) || post[2].finite?)
            unless finite
              validation_errors << "vertex_#{i}_position_unreadable"
              next
            end
            # All four FINAL-R2-01 checks pass. NOW we can
            # safely call `.to_f` and perform the XY/Z
            # drift validation + audit append.
            after_zs << post[2].to_f
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
          end
        rescue StandardError => e
          # FINAL-R2-01: defensive final boundary. An
          # unexpected StandardError during the
          # post-validation phase MUST NOT escape the
          # function while the outer operation is still
          # open. Treat as a post-validation failure:
          # abort ONCE, never commit, :failed, zero
          # committed success.
          post_validation_phase_failed = true
          validation_errors << "vertex_phase_post_validation_raised:#{e.class}"
        end
        if post_validation_phase_failed || !validation_errors.empty?
          begin
            adapter.end_operation(workspace_model_for(workspace), commit: false)
          rescue StandardError
            # ignore
          end
          reason = if post_validation_phase_failed
                     "post_validation_phase_failed:#{validation_errors.first}"
                   else
                     "post_validation_failed:#{validation_errors.first}"
                   end
          new_workspace = _mark_workspace_failed(workspace, reason)
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
              reason: post_validation_phase_failed ? 'post_validation_phase_failed' : 'post_validation_failed'
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
        #
        # V1.9A P0 SHARED-VERTEX CORRECTION (amendment §5):
        # publish the frozen count schema:
        #   logical_applied_count   = logical moves fully applied
        #                             (always == 1 on a successful
        #                             overall apply, per the
        #                             atomic-transaction contract)
        #   physical_applied_count  = physical Vertex occurrences
        #                             mutated + postvalidated
        #   applied_count           = backward-compat alias of
        #                             physical_applied_count
        #   moved_vertex_count      = physical count (legacy
        #                             consumer surface)
        logical_applied = (proposal.is_a?(Hash) && proposal[:logical_moves].is_a?(Integer) ?
                              proposal[:logical_moves] :
                              1) # legacy fallback
        physical_applied = moved_count
        audit = _audit_row(
          proposal_hash:             proposal_hash,
          workspace:                 workspace,
          applied_count:             physical_applied,
          failed_count:              0,
          logical_applied_count:     logical_applied,
          physical_applied_count:    physical_applied,
          before_zs:                 before_zs,
          after_zs:                  after_zs,
          max_movement:              max_movement.to_f,
          status:                    :applied
        )
        {
          status: :applied,
          post_workspace: workspace,
          moved_vertex_count: physical_applied,
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
                     status: nil, reason: nil,
                     logical_applied_count: nil,
                     physical_applied_count: nil)
        proposal = proposal_hash.is_a?(Hash) ? proposal_hash[:proposal] : nil
        # V1.9A P0 SHARED-VERTEX CORRECTION (amendment §5):
        # freeze the count schema. The successful apply
        # path passes logical + physical counts explicitly.
        # The fail path does not need to (logical = 0,
        # physical = 0 on failure).
        logical_count   = logical_applied_count.nil? ? 0 : logical_applied_count
        physical_count  = physical_applied_count.nil? ? applied_count : physical_applied_count
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
          # FROZEN count schema (amendment §5):
          applied_count:    physical_count,             # legacy alias
          logical_applied_count:  logical_count,
          physical_applied_count: physical_count,
          failed_count:     failed_count,
          status:           status,
          reason:           reason
        }.freeze
      end

      def _z_summary(zs)
        return { 'count' => 0, 'min' => nil, 'max' => nil, 'mean' => nil } if zs.empty?
        floats = zs.map(&:to_f)
        # Ruby 2.2 compatibility: Array#sum was added in Ruby 2.4.
        # Use inject-based reduction so this runs on the legacy
        # baseline (SU2017 Ruby 2.2.4 / SU2020 Ruby 2.5.5).
        total = floats.inject(0.0) { |acc, z| acc + z }
        {
          'count' => floats.length,
          'min'   => floats.min.to_f,
          'max'   => floats.max.to_f,
          'mean'  => (total / floats.length.to_f)
        }.freeze
      end
    end
  end
end
