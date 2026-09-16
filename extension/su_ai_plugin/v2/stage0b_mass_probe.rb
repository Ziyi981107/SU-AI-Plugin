#
# v2/stage0b_mass_probe.rb — V2-0B Stage 0B Mass Probe.
#
# Per frozen V2-0B Stage Technical Blueprint
# (Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md)
# §3.3 + §4 + §5 + §10:
#
#   Validate the V2-0A SemanticFootprint + explicit positive
#   finite probe height. Perform the complete pre-mutation
#   freshness/context gate. Call the V1 public capture /
#   Builder / Validator seams only. Re-run
#   `SemanticFootprintProjector.project` against the current
#   PCD. Re-resolve the exact target footprint by full 64-hex
#   footprint_id_full. Call the operation guard + host
#   adapter. Return one deterministic result object/status.
#
#   No UI. No selection Tool. No V1 source mutation.
#
# Files:
#   extension/su_ai_plugin/v2/host_operation_guard.rb
#   extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb
#   extension/su_ai_plugin/v2/stage0b_mass_probe.rb
#

require_relative 'host_operation_guard'
require_relative 'semantic_footprint_projector'
require_relative '../compatibility/v2_sketchup_mass_adapter'

module SUAnalysis
  module V2
    # Stage0BMassProbe is the deterministic orchestrator for the
    # V2-0B first real SketchUp write probe. It owns the
    # pre-mutation gate (Blueprint §5), the operation lifecycle
    # (delegated to HostOperationGuard), and the geometry
    # construction (delegated to V2SketchupMassAdapter).
    #
    # Public entry point: `Stage0BMassProbe.run(...)`.
    class Stage0BMassProbe
      # Status constants (Blueprint §10).
      STATUS_SUCCESS                     = 'SUCCESS'
      STATUS_BLOCKED                     = 'BLOCKED'
      STATUS_STALE_PREPARED_DATASET      = 'STALE_PREPARED_DATASET'
      STATUS_CONTEXT_CHANGED             = 'CONTEXT_CHANGED'
      STATUS_START_FAILED                = 'START_FAILED'
      STATUS_FAILED_ROLLED_BACK          = 'FAILED_ROLLED_BACK'
      STATUS_COMMIT_FAILED_ROLLED_BACK   = 'COMMIT_FAILED_ROLLED_BACK'
      STATUS_HOST_STATE_UNCERTAIN        = 'HOST_STATE_UNCERTAIN'

      attr_reader :guard, :adapter, :projector, :capture_seam, :build_seam,
                  :validate_seam

      # Constructor. All collaborators are injectable so the
      # focused test suite can supply fakes; production code
      # uses defaults that call the frozen V1 seams.
      #
      # Required kwargs:
      #   guard       : HostOperationGuard instance
      #   adapter     : V2SketchupMassAdapter instance
      #   projector   : callable accepting (dataset:, semantic_role:,
      #                 layer_name:) and returning the projector
      #                 result Hash (default: SemanticFootprintProjector)
      #   capture_seam: callable accepting (analysis_result:) and
      #                 returning either a Hash bundle or a
      #                 BLOCKED-shaped status Hash (default:
      #                 WorkingModeRunner.capture_prepared_cad_input_bundle)
      #   build_seam  : callable accepting (the bundle Hash) and
      #                 returning the Builder result Hash (default:
      #                 PreparedCadDatasetBuilder.build)
      #   validate_seam: callable accepting (dataset:,
      #                  workflow_snapshot:) and returning the
      #                  Validator result Hash (default:
      #                  PreparedCadDatasetValidator.validate_and_finalize)
      def initialize(guard:,
                     adapter:,
                     projector: nil,
                     capture_seam: nil,
                     build_seam: nil,
                     validate_seam: nil)
        @guard        = guard
        @adapter      = adapter
        @projector    = projector    || method(:_default_projector)
        @capture_seam = capture_seam || method(:_default_capture_seam)
        @build_seam   = build_seam   || method(:_default_build_seam)
        @validate_seam = validate_seam || method(:_default_validate_seam)
      end

      # Run the Stage-0B probe end-to-end. Returns a
      # deterministic result Hash with a top-level `status`
      # String from the Blueprint §10 list.
      #
      # Required kwargs:
      #   footprint      : valid V2-0A SemanticFootprint record
      #                    (must carry projected_world_coordinates,
      #                     footprint_id_full, source_content_digest,
      #                     semantic_role, source_layer_name,
      #                     coordinate_epsilon)
      #   analysis_result: the AnalysisResult the frozen V1 public
      #                    capture path requires
      #   probe_height   : explicit Numeric, finite, > 0
      #
      # Optional kwargs:
      #   workflow_snapshot: explicit Hash passed to
      #                      validate_and_finalize; default
      #                      derives one from the capture bundle
      #                      when available.
      def run(footprint:, analysis_result:, probe_height:, workflow_snapshot: nil)
        # ---- Input validation (Blueprint §4 + R1-03 hidden-epsilon ban) ----
        return _blocked('invalid_footprint') unless _valid_footprint?(footprint)
        return _blocked('invalid_probe_height') unless _valid_probe_height?(probe_height)
        # R1-03: footprint['coordinate_epsilon'] is the only
        # post-validation geometry tolerance. Missing/invalid
        # epsilon must fail BEFORE start_operation.
        eps_check = _validate_coordinate_epsilon(footprint['coordinate_epsilon'])
        return _blocked(eps_check) if eps_check

        # ---- Pre-mutation gate (Blueprint §5) ----
        return _blocked('host_session_uncertain') if @guard.uncertain?

        m = begin
          @adapter.model
        rescue StandardError
          nil
        end
        return _blocked('no_model') unless m
        return _context_changed unless _root_context?(m)

        # 4-9. Frozen V1 public capture/build/validate +
        #      digest compare + re-project + footprint re-resolve.
        freshness = _freshness_check(footprint, analysis_result, workflow_snapshot)
        unless freshness.is_a?(Hash) && freshness['status'] == 'FRESH'
          return freshness
        end
        # R1-05: the freshness check must yield the matched
        # CURRENT SemanticFootprint; geometry construction
        # consumes that re-resolved record rather than the
        # caller's original footprint.
        current_footprint = freshness['current_footprint']
        unless current_footprint.is_a?(Hash)
          return { 'status' => STATUS_STALE_PREPARED_DATASET,
                   'error'  => 'current_footprint_missing' }
        end

        # 10. Re-check root context immediately before operation
        #     start (Blueprint §5 step 10).
        return _context_changed unless _root_context?(m)

        # ---- Operation lifecycle ----
        start_status = @guard.start(m, V2SketchupMassAdapter::OPERATION_LABEL)
        unless start_status == HostOperationGuard::STATUS_STARTED
          # Per Blueprint §6.1: no abort attempt when start was
          # not confirmed. Zero geometry mutation expected.
          return _host_status_to_result(start_status)
        end

        # ---- Geometry construction ----
        # R1-02: wrap construction in an outer rescue so any
        # unexpected adapter/SketchUp exception after confirmed
        # start is converted to a construction failure and
        # goes through exactly one abort attempt. Never let
        # an open operation be left to the caller.
        build = begin
          @adapter.build_mass(
            footprint:   current_footprint,
            probe_height: probe_height.to_f
          )
        rescue StandardError => e
          { status: V2SketchupMassAdapter::STATUS_CONSTRUCTION_FAILED,
            error:  'adapter_exception:' + e.class.name + ':' + e.message }
        end

        if build[:status] == V2SketchupMassAdapter::STATUS_SUCCESS
          # Commit the operation.
          commit_status = @guard.commit(m)
          return _host_status_to_result(commit_status, build, current_footprint)
        end

        # Construction or post-validation failure (or wrapped
        # adapter exception). Per Blueprint §6.2: abort exactly
        # once, never claim cleanup success unless abort
        # returned literal true.
        abort_status = @guard.abort(m)
        case abort_status
        when HostOperationGuard::STATUS_FAILED_ROLLED_BACK
          build_status = build[:status]
          reason       = build[:error].to_s
          if build_status == V2SketchupMassAdapter::STATUS_POST_VALIDATION_FAILED
            { 'status' => STATUS_FAILED_ROLLED_BACK,
              'error'  => 'post_validation_failed:' + reason }
          else
            { 'status' => STATUS_FAILED_ROLLED_BACK,
              'error'  => 'construction_failed:' + reason }
          end
        when HostOperationGuard::STATUS_HOST_STATE_UNCERTAIN
          { 'status' => STATUS_HOST_STATE_UNCERTAIN,
            'error'  => 'abort_failed_or_uncertain' }
        else
          { 'status' => STATUS_HOST_STATE_UNCERTAIN,
            'error'  => 'unexpected_abort_status:' + abort_status.to_s }
        end
      end

      private

      def _valid_footprint?(fp)
        return false unless fp.is_a?(Hash)
        return false unless fp['footprint_id_full'].is_a?(String) && !fp['footprint_id_full'].empty?
        return false unless fp['source_content_digest'].is_a?(String) && fp['source_content_digest'].length == 64
        return false unless fp['semantic_role'].is_a?(String) && !fp['semantic_role'].empty?
        return false unless fp['source_layer_name'].is_a?(String) && !fp['source_layer_name'].empty?
        coords = fp['projected_world_coordinates']
        return false unless coords.is_a?(Array) && coords.size >= 3
        true
      end

      def _valid_probe_height?(h)
        return false unless h.is_a?(Numeric)
        return false unless h.finite?
        h.to_f > 0.0
      end

      def _root_context?(m)
        if @adapter.respond_to?(:root_context?)
          @adapter.root_context?
        else
          m.respond_to?(:active_path) && m.active_path.nil?
        end
      end

      # Perform the freshness check (Blueprint §5 steps 4-9):
      # V1 public capture -> Builder -> Validator; compare
      # full content_digest; re-run projector; require exact
      # footprint_id_full re-resolution.
      #
      # R1-01: the REAL B1.5 capture bundle keys
      # (source_snapshot / workflow_snapshot /
      # topology_snapshot / canonical_graph /
      # structure_result / analysis_result) are the only
      # Builder inputs accepted by the production default.
      # Validator workflow authority defaults from
      # bundle['workflow_snapshot'].
      #
      # R1-05: the matched CURRENT SemanticFootprint is
      # returned to the caller (via 'current_footprint')
      # so geometry construction consumes the re-resolved
      # current record.
      def _freshness_check(footprint, analysis_result, workflow_snapshot)
        # 4. Capture.
        capture_out = begin
          @capture_seam.call(analysis_result: analysis_result)
        rescue StandardError
          { 'status' => 'BLOCKED', 'bundle' => nil }
        end
        unless _capture_ok?(capture_out)
          return { 'status' => STATUS_STALE_PREPARED_DATASET,
                   'error'  => 'capture_failed' }
        end
        bundle = capture_out['bundle']
        return { 'status' => STATUS_STALE_PREPARED_DATASET,
                 'error'  => 'capture_bundle_nil' } unless bundle.is_a?(Hash)

        # 5. Build.
        build_out = begin
          @build_seam.call(bundle)
        rescue StandardError
          { 'status' => 'BLOCKED', 'dataset' => nil }
        end
        unless _build_ok?(build_out)
          return { 'status' => STATUS_STALE_PREPARED_DATASET,
                   'error'  => 'build_failed' }
        end
        candidate = build_out['dataset']

        # 6. Validate. R1-01: workflow_snapshot authority
        # MUST default from bundle['workflow_snapshot'].
        ws = workflow_snapshot ||
             (bundle['workflow_snapshot'] || {}).dup ||
             {}
        validate_out = begin
          @validate_seam.call(dataset: candidate, workflow_snapshot: ws)
        rescue StandardError
          { 'status' => 'NOT_READY', 'dataset' => candidate }
        end
        unless _validate_ok?(validate_out)
          return { 'status' => STATUS_STALE_PREPARED_DATASET,
                   'error'  => 'validate_failed' }
        end
        dataset = validate_out['dataset']
        return { 'status' => STATUS_STALE_PREPARED_DATASET,
                 'error'  => 'dataset_not_final' } unless dataset.respond_to?(:final?) && dataset.final?

        # 7. Full content_digest compare.
        current_digest = dataset.respond_to?(:content_digest) ? dataset.content_digest.to_s : ''
        target_digest  = footprint['source_content_digest'].to_s
        unless current_digest == target_digest && current_digest.length == 64
          return { 'status' => STATUS_STALE_PREPARED_DATASET,
                   'error'  => 'content_digest_mismatch' }
        end

        # 8. Re-run projector against current PCD.
        proj = begin
          @projector.call(
            dataset:      dataset,
            semantic_role: footprint['semantic_role'],
            layer_name:   footprint['source_layer_name']
          )
        rescue StandardError
          { 'status' => 'BLOCKED' }
        end
        unless proj.is_a?(Hash)
          return { 'status' => STATUS_STALE_PREPARED_DATASET,
                   'error'  => 'projector_invalid_return' }
        end
        proj_status = proj['status']
        unless proj_status == 'PROJECTED' || proj_status == 'PROJECTED_WITH_REJECTIONS'
          return { 'status' => STATUS_STALE_PREPARED_DATASET,
                   'error'  => 'projector_status:' + proj_status.to_s }
        end
        footprints = proj['footprints']
        unless footprints.is_a?(Array)
          return { 'status' => STATUS_STALE_PREPARED_DATASET,
                   'error'  => 'projector_no_footprints' }
        end

        # 9. Re-resolve exact footprint_id_full.
        target_fpid = footprint['footprint_id_full'].to_s
        matched = nil
        footprints.each do |fp|
          if fp.is_a?(Hash) && fp['footprint_id_full'].to_s == target_fpid &&
             fp['source_content_digest'].to_s == target_digest
            matched = fp
            break
          end
        end
        unless matched
          return { 'status' => STATUS_STALE_PREPARED_DATASET,
                   'error'  => 'footprint_not_re_resolved' }
        end

        # R1-05: surface the matched current footprint so the
        # caller can build geometry from it.
        { 'status' => 'FRESH', 'current_footprint' => matched }
      end

      def _capture_ok?(out)
        out.is_a?(Hash) && out['status'] == 'CAPTURED' && out['bundle'].is_a?(Hash)
      end

      def _build_ok?(out)
        out.is_a?(Hash) && out['status'] == 'BUILT' && out['dataset'].respond_to?(:final?)
      end

      def _validate_ok?(out)
        return false unless out.is_a?(Hash)
        status = out['status']
        return false unless status == 'READY' || status == 'READY_WITH_WARNINGS'
        out['dataset'].respond_to?(:final?) && out['dataset'].final?
      end

      # R1-03: footprint['coordinate_epsilon'] is the ONLY
      # post-validation geometry tolerance. It MUST be a
      # Numeric, finite, > 0 before any host mutation.
      # Missing/invalid values fail closed BEFORE start.
      # Returns nil on success or a non-empty reason String
      # on failure.
      def _validate_coordinate_epsilon(value)
        unless value.is_a?(Numeric)
          return 'missing_or_non_numeric_coordinate_epsilon'
        end
        unless value.respond_to?(:finite?) ? value.finite? :
               (value.respond_to?(:infinite?) ? !value.infinite? : true)
          return 'non_finite_coordinate_epsilon'
        end
        return 'non_positive_coordinate_epsilon' if value.to_f <= 0.0
        nil
      end

      def _blocked(reason)
        { 'status' => STATUS_BLOCKED, 'error' => reason.to_s }
      end

      def _context_changed
        { 'status' => STATUS_CONTEXT_CHANGED,
          'error'  => 'model_active_path_non_nil' }
      end

      def _host_status_to_result(guard_status, build = nil, footprint = nil)
        case guard_status
        when HostOperationGuard::STATUS_STARTED
          # Should not happen; we only call this after start.
          { 'status' => STATUS_START_FAILED,
            'error'  => 'unexpected_started_state' }
        when HostOperationGuard::STATUS_START_FAILED
          { 'status' => STATUS_START_FAILED,
            'error'  => 'start_failed' }
        when HostOperationGuard::STATUS_SUCCESS
          # R1-05: success result carries the generated host
          # Group handle as the explicitly host-only 'group'
          # field. Do not serialize/persist the handle into
          # PCD or model metadata.
          { 'status'           => STATUS_SUCCESS,
            'footprint_id_full' => footprint ? footprint['footprint_id_full'].to_s : nil,
            'group'            => build && build.is_a?(Hash) ? build[:group] : nil }
        when HostOperationGuard::STATUS_FAILED_ROLLED_BACK
          { 'status' => STATUS_FAILED_ROLLED_BACK,
            'error'  => 'construction_or_post_validation_failed' }
        when HostOperationGuard::STATUS_COMMIT_FAILED_ROLLED_BACK
          { 'status' => STATUS_COMMIT_FAILED_ROLLED_BACK,
            'error'  => 'commit_failed_rolled_back' }
        when HostOperationGuard::STATUS_HOST_STATE_UNCERTAIN
          { 'status' => STATUS_HOST_STATE_UNCERTAIN,
            'error'  => 'host_state_uncertain' }
        else
          { 'status' => STATUS_HOST_STATE_UNCERTAIN,
            'error'  => 'unknown_guard_status:' + guard_status.to_s }
        end
      end

      # ---- Default seams (real V1 / V2-0A production paths) ----

      def _default_projector(dataset:, semantic_role:, layer_name:)
        SUAnalysis::V2::SemanticFootprintProjector.project(
          dataset: dataset,
          semantic_role: semantic_role,
          layer_name: layer_name
        )
      end

      def _default_capture_seam(analysis_result:)
        SUAnalysis::Core::WorkingModeRunner.capture_prepared_cad_input_bundle(
          analysis_result: analysis_result
        )
      end

      # R1-01: the default build seam wires the REAL B1.5
      # bundle keys to the REAL PreparedCadDatasetBuilder
      # keyword contract:
      #   source_snapshot / workflow_snapshot /
      #   topology_snapshot / canonical_graph /
      #   structure_result / analysis_result
      # No synthetic projection-shape adaptation may become
      # the production default seam.
      def _default_build_seam(bundle)
        SUAnalysis::Core::PreparedCadDatasetBuilder.build(
          source_snapshot:    bundle['source_snapshot'],
          workflow_snapshot:  bundle['workflow_snapshot'],
          topology_snapshot:  bundle['topology_snapshot'],
          canonical_graph:    bundle['canonical_graph'],
          structure_result:   bundle['structure_result'],
          analysis_result:    bundle['analysis_result']
        )
      end

      def _default_validate_seam(dataset:, workflow_snapshot:)
        SUAnalysis::Core::PreparedCadDatasetValidator.validate_and_finalize(
          dataset: dataset,
          workflow_snapshot: workflow_snapshot
        )
      end
    end
  end
end