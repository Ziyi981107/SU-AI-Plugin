#
# core/working_mode_runner.rb — V1.4 WorkingModeRunner.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 4: minimal working-mode plumbing.
#
# The runner is the in-process state holder for the dialog's
# "Working Mode" surface. It owns the current
# DerivedGeometryWorkspace (one per dialog session) and exposes
# prepare / discard / rebuild operations as JSON-safe Hashes
# for the JS layer.
#
# Locked contract (per directive 030 Stage 4):
#   - Enter working mode by clicking "Prepare" on the dialog.
#     The runner snapshots the current analysis source into a
#     DerivedGeometryWorkspace via the injected adapter.
#   - The runner NEVER touches the source -- it only sees the
#     frozen SourceSnapshot the AnalysisResult already carries.
#   - Discard / rebuild operate ONLY on the runner-owned
#     workspace.
#   - The runner returns a JSON-safe Hash; it never holds a
#     live SketchUp::Entity across the bridge.
#   - V1.5 repair actions stay out of scope. V1.4 plumbing
#     only.
#
# Adapter selection (per directive):
#   - Real SU: use SketchupDerivedWorkspaceAdapter (in
#     compatibility/) which creates real SketchUp::Group
#     entities under a recognizable name prefix.
#   - Test env: use FakeDerivedWorkspaceAdapter (in core/).
#   - The runner is adapter-agnostic; the factory decides.
#

require_relative 'derived_geometry_workspace'

module SUAnalysis
  module Core
    module WorkingModeRunner
      module_function

      # Internal state. Per-process (no per-dialog tracking yet;
      # one dialog instance per process is the common case).
      # All state is frozen when stored so callers cannot mutate
      # the runner's view of the current workspace.
      @current_workspace     = nil   # DerivedGeometryWorkspace or nil
      @current_source        = nil   # SourceSnapshot (frozen) or nil
      @current_adapter       = nil   # DerivedWorkspaceAdapter instance or nil
      @current_adapter_kind  = nil   # Symbol :real_su | :fake | nil

      STATES = [:none, :building, :ready, :discarded, :failed].freeze

      # Build (or rebuild) the current workspace from a frozen
      # SourceSnapshot. Returns the JSON-safe Hash for the UI.
      # When no existing workspace exists, this is "prepare".
      # When a workspace already exists, this is "rebuild".
      #
      # adapter: a DerivedWorkspaceAdapter subclass instance.
      # source:  a frozen SourceSnapshot.
      #
      # The adapter is captured for rebuild(); the runner does
      # NOT trust callers to re-supply it on every operation.
      def prepare(source:, adapter:)
        # Per directive: "Source CAD is immutable". The
        # runner only ever sees a frozen SourceSnapshot and
        # builds a brand new workspace. Any prior workspace
        # is discarded (best-effort) first.
        _discard_if_present
        ws = DerivedGeometryWorkspace.new(
          workspace_id:    "ws-#{rand(2**32)}",
          source_snapshot: source,
          adapter:         adapter
        )
        # Empty workspace state from the user's perspective
        # (nothing built yet). Real entities are added by the
        # upstream SU adapter layer in V1.4+ Stage 4b (out of
        # scope for the V1.4 foundation plumbing).
        @current_source        = source
        @current_adapter       = adapter
        @current_adapter_kind  = _adapter_kind_of(adapter)
        @current_workspace     = ws
        snapshot
      end

      # Discard the current workspace if any. Idempotent.
      # Returns the post-discard snapshot Hash (state == :discarded).
      #
      # The discarded workspace is KEPT in @current_workspace
      # (in :discarded state) so the next snapshot() reports
      # 'discarded' to the UI. The next prepare() proceeds
      # with a fresh workspace regardless; the prior discarded
      # workspace is no longer the active one (snapshot will
      # report the new state on the next render).
      def discard
        _discard_if_present
        # NOTE: do NOT clear @current_workspace here. The
        # discarded workspace carries the :discarded state
        # that the UI needs to render. The next prepare()
        # overwrites @current_workspace with a fresh
        # :building workspace.
        snapshot
      end

      # Rebuild from the SAME captured source + the SAME captured
      # adapter. The runner remembers the adapter that was
      # supplied at prepare() time; rebuild reuses it so the
      # caller does NOT have to re-supply it.
      #
      # For the V1.4 plumbing, rebuild = prepare (the workspace
      # is empty in :building state); V1.4+ will rebuild real
      # entities from the captured RepairPlan.
      def rebuild
        return _empty_snapshot if @current_source.nil?
        # If the captured adapter is missing (e.g. tests that
        # bypass prepare()), rebuild stays idle.
        return _empty_snapshot if @current_adapter.nil?
        prepare(source: @current_source, adapter: @current_adapter)
      end

      # Snapshot of the runner state for the UI. JSON-safe.
      # Returns a String-keyed Hash with: state, source_snapshot_id,
      # source_fingerprint_digest, execution_config_digest,
      # workspace_id, last_error.
      # When the runner is idle (no workspace), returns the
      # "none" snapshot.
      def snapshot
        if @current_workspace.nil?
          {
            'state'                    => 'none',
            'source_snapshot_id'       => nil,
            'source_fingerprint_digest' => nil,
            'execution_config_digest'  => nil,
            'workspace_id'             => nil,
            'last_error'               => nil
          }
        else
          ws = @current_workspace
          src = @current_source || ws.source_snapshot
          fp = src.fingerprint
          {
            'state'                    => ws.state.to_s,
            'source_snapshot_id'       => src.snapshot_id.to_s,
            'source_fingerprint_digest' => (fp.respond_to?(:digest) ? fp.digest : nil),
            'execution_config_digest'  => (src.execution_config.respond_to?(:digest) ? src.execution_config.digest : ''),
            'workspace_id'             => ws.workspace_id.to_s,
            'last_error'               => (ws.respond_to?(:last_error) ? ws.last_error : nil)
          }
        end
      end

      # ---- internals ----

      def _discard_if_present
        return if @current_workspace.nil?
        begin
          @current_workspace = @current_workspace.discard
        rescue StandardError
          # If the discard itself fails, leave the state alone;
          # the next prepare() will retry from scratch.
          @current_workspace = nil
        end
      end

      def _adapter_kind_of(adapter)
        if adapter.is_a?(DerivedWorkspaceAdapter)
          # The FakeAdapter is the only adapter in core/; the
          # production adapter lives in compatibility/.
          klass_path = adapter.class.name.to_s
          if klass_path.include?('Fake')
            :fake
          else
            :real_su
          end
        else
          :unknown
        end
      end

      def _adapter_for(_kind)
        # Deprecated: the runner remembers the adapter via
        # @current_adapter and rebuild() reuses it. This
        # private helper is retained for any external code
        # that may have been calling it; it returns the
        # currently captured adapter (or nil).
        @current_adapter
      end

      def _empty_snapshot
        snapshot
      end

      # Test hook: force-clear the runner state. Not used in
      # production; here for testing in isolation.
      def reset_for_tests
        @current_workspace    = nil
        @current_source       = nil
        @current_adapter      = nil
        @current_adapter_kind = nil
      end
    end
  end
end
