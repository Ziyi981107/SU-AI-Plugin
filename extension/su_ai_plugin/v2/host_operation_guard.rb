#
# v2/host_operation_guard.rb — V2-0B Host Operation Guard.
#
# Per frozen V2-0B Stage Technical Blueprint
# (Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md)
# §3.1 + §6 + §7:
#
#   Own V2 in-memory host-write session state. Start / commit /
#   abort ONE normal SketchUp operation. Inspect exact Boolean
#   results. At most one abort attempt per failed open
#   operation. Lock further V2 writes when rollback cannot be
#   confirmed.
#
#   MUST NOT create geometry and MUST NOT know PreparedCadDataset
#   semantics. MUST NOT read V1 Runner private state. MUST NOT
#   reuse the V1 SketchupDerivedWorkspaceAdapter wrapper because
#   it discards Boolean operation results (Blueprint §2 + §6).
#
# Files:
#   extension/su_ai_plugin/v2/host_operation_guard.rb
#   extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb
#   extension/su_ai_plugin/v2/stage0b_mass_probe.rb
#

module SUAnalysis
  module V2
    # HostOperationGuard owns V2 in-memory host-write session state.
    # The session-level lock is process-memory only; it is NOT
    # stored in the SKP model and NOT persisted (Blueprint §7).
    class HostOperationGuard
      STATE_READY                 = 'READY'
      STATE_HOST_STATE_UNCERTAIN  = 'HOST_STATE_UNCERTAIN'

      STATUS_STARTED                       = 'STARTED'
      STATUS_START_FAILED                  = 'START_FAILED'
      STATUS_SUCCESS                       = 'SUCCESS'
      STATUS_FAILED_ROLLED_BACK            = 'FAILED_ROLLED_BACK'
      STATUS_COMMIT_FAILED_ROLLED_BACK     = 'COMMIT_FAILED_ROLLED_BACK'
      STATUS_HOST_STATE_UNCERTAIN          = 'HOST_STATE_UNCERTAIN'

      attr_reader :state

      def initialize
        @state = STATE_READY
        @open   = false
      end

      # True when the session is locked. All V2 host writes MUST
      # be rejected while uncertain (Blueprint §7).
      def uncertain?
        @state == STATE_HOST_STATE_UNCERTAIN
      end

      # True when an operation is currently open. The Blueprint
      # #6 requires at-most-one open operation per session.
      def operation_open?
        @open == true
      end

      # Transition the session into the locked state. No
      # automatic reset (Blueprint §7).
      def lock!
        @state = STATE_HOST_STATE_UNCERTAIN
        @open   = false
      end

      # Explicit developer-only recovery reset. Used by tests
      # and by Owner recovery after the user manually restores
      # model state. NOT a normal path.
      def reset_for_test!
        @state = STATE_READY
        @open   = false
      end

      # Start one normal, non-transparent SketchUp operation.
      # Returns STATUS_STARTED on confirmed start, STATUS_START_FAILED
      # on false/raise. NO abort attempt when start was not
      # confirmed (Blueprint §6.1).
      def start(model, label)
        return STATUS_START_FAILED if uncertain?
        unless model.respond_to?(:start_operation)
          lock!
          return STATUS_HOST_STATE_UNCERTAIN
        end
        result = begin
          model.start_operation(label, true, false, false)
        rescue StandardError
          nil
        end
        if result == true
          @open = true
          STATUS_STARTED
        else
          @open = false
          STATUS_START_FAILED
        end
      end

      # Commit the currently open operation. Per Blueprint §6.3:
      # commit true -> SUCCESS;
      # commit false or raise -> attempt abort exactly once;
      #   abort true  -> COMMIT_FAILED_ROLLED_BACK;
      #   abort false or raise -> HOST_STATE_UNCERTAIN + lock.
      def commit(model)
        return STATUS_HOST_STATE_UNCERTAIN unless @open
        return STATUS_HOST_STATE_UNCERTAIN unless model.respond_to?(:commit_operation)
        result = begin
          model.commit_operation
        rescue StandardError
          :raised
        end
        if result == true
          @open = false
          STATUS_SUCCESS
        else
          # Commit false or raise. Attempt abort exactly once.
          abort_result = _safe_abort(model)
          @open = false
          if abort_result == true
            lock!
            STATUS_COMMIT_FAILED_ROLLED_BACK
          else
            lock!
            STATUS_HOST_STATE_UNCERTAIN
          end
        end
      end

      # Abort the currently open operation. Per Blueprint §6.2:
      # abort true -> FAILED_ROLLED_BACK;
      # abort false or raise -> HOST_STATE_UNCERTAIN + lock.
      def abort(model)
        return STATUS_HOST_STATE_UNCERTAIN unless @open
        return STATUS_HOST_STATE_UNCERTAIN unless model.respond_to?(:abort_operation)
        result = begin
          model.abort_operation
        rescue StandardError
          :raised
        end
        @open = false
        if result == true
          STATUS_FAILED_ROLLED_BACK
        else
          lock!
          STATUS_HOST_STATE_UNCERTAIN
        end
      end

      private

      # At most one abort attempt per failed open operation.
      # The caller MUST treat any non-true return as uncertain.
      def _safe_abort(model)
        model.abort_operation
      rescue StandardError
        :raised
      end
    end
  end
end