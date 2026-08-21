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
      # model:   SU model (passed to workspace + adapter for
      #          operation wrapping). May be nil in tests.
      #
      # The adapter is captured for rebuild(); the runner does
      # NOT trust callers to re-supply it on every operation.
      #
      # V1.4 CodeX BLOCK fix (Stage 4): prepare MUST actually
      # build at least one derived entity via the adapter
      # (NOT just an empty workspace). The SourceSnapshot's
      # edges + faces are converted 1:1 to derived entities
      # (one SU-AI-Derived-* group per source Edge / Face).
      # If the source has NO edges AND NO faces, prepare
      # transitions the workspace to :failed with a clear
      # last_error (cannot derive from empty source).
      def prepare(source:, adapter:, model: nil)
        # Per directive: "Source CAD is immutable". The
        # runner only ever sees a frozen SourceSnapshot and
        # builds a brand new workspace. Any prior workspace
        # is discarded (best-effort) first.
        _discard_if_present

        # Build the empty workspace first. We will populate
        # it via build_entity calls below.
        ws = DerivedGeometryWorkspace.new(
          workspace_id:    "ws-#{rand(2**32)}",
          source_snapshot: source,
          adapter:         adapter,
          model:           model
        )
        @current_source        = source
        @current_adapter       = adapter
        @current_adapter_kind  = _adapter_kind_of(adapter)
        @current_workspace     = ws

        # V1.4 CodeX BLOCK fix (Stage 4): build at least one
        # derived entity from the captured source. The SourceSnapshot
        # carries the real edges + faces; we materialize one
        # derived entity per source EdgeRecord + one per source
        # FaceRecord. Each entity captures source_occurrence_ids
        # (the SourceReference's persistent_id_path as the
        # snapshot-local occurrence id) so rebuild determinism
        # is preserved.
        #
        # If the source has no edges AND no faces, prepare
        # cannot produce ANY derived entity. Per directive:
        # the workspace must NOT be marked READY in this
        # case; it transitions to :failed with a clear error.
        built_ws = _build_derived_entities(ws, source)
        @current_workspace = built_ws
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

      # V1.4 CodeX BLOCK fix (Stage 4): materialize one derived
      # entity per source EdgeRecord + one per source FaceRecord.
      # Returns a new DerivedGeometryWorkspace (the original is
      # deeply frozen; transitions produce new instances).
      # On failure (no source geometry OR adapter failure), returns
      # a :failed workspace with last_error set.
      def _build_derived_entities(ws, source)
        edges = source.respond_to?(:edges) ? source.edges : []
        faces = source.respond_to?(:faces) ? source.faces : []
        if (edges.nil? || edges.empty?) && (faces.nil? || faces.empty?)
          # No source geometry to derive from: workspace must
          # NOT be marked READY. Transition to :failed.
          return DerivedGeometryWorkspace.new_with_inventory(
            workspace_id:    ws.workspace_id,
            source_snapshot: source,
            adapter:         ws.instance_variable_get(:@adapter),
            model:           ws.instance_variable_get(:@model),
            state:           :failed,
            entity_pairs:    [].freeze,
            handle_registry: {}.freeze,
            fingerprint:     nil,
            last_error:      'cannot derive from empty source (no edges / faces in SourceSnapshot)',
            build_started_at: ws.build_started_at
          )
        end
        # Build one derived entity per source EdgeRecord.
        cur = ws
        edges.each_with_index do |edge, idx|
          did = "der-edge-#{idx}-#{_stable_id_fragment(edge)}"
          occ_ids = [ _source_occurrence_id_for(edge) ]
          geom = _geometry_summary_for_edge(edge)
          # Use the edge's endpoints as the geometry_data so the
          # adapter can add_face_to_group a representative face.
          # This is what gives the FakeAdapter a real `add_face_to_group`
          # call (verifying the operation-wrapping path).
          pts = _face_points_for_edge(edge)
          cur = cur.build_entity(
            derived_id:            did,
            kind:                  :edge,
            source_occurrence_ids: occ_ids,
            geometry_summary:      geom,
            geometry_data:         pts
          )
          # If build_entity returned :failed (per directive:
          # :failed workspaces are NOT :ready), stop the loop
          # and propagate the failure.
          break if cur.state == :failed
        end
        return cur if cur.state == :failed
        # Build one derived entity per source FaceRecord.
        faces.each_with_index do |face, idx|
          did = "der-face-#{idx}-#{_stable_id_fragment(face)}"
          occ_ids = [ _source_occurrence_id_for(face) ]
          geom = _geometry_summary_for_face(face)
          pts = _face_points_for_face(face)
          cur = cur.build_entity(
            derived_id:            did,
            kind:                  :face,
            source_occurrence_ids: occ_ids,
            geometry_summary:      geom,
            geometry_data:         pts
          )
          break if cur.state == :failed
        end
        cur
      end

      # Derive a stable occurrence id from a SourceRecord. The
      # occurrence id is unique within ONE snapshot; it is
      # NOT a host PID. We use the host persistent_id (or
      # entity_id as fallback) joined with the snapshot_id
      # so the same source across two snapshots has two
      # different snapshot-local occurrence ids (per
      # directive: "snapshot-local occurrence/record
      # identity that is always unique within one snapshot,
      # separate from host-resolvable identity").
      def _source_occurrence_id_for(record)
        return 'unknown' if record.nil?
        src = record.respond_to?(:source) ? record.source : nil
        if src && src.respond_to?(:persistent_id) && src.persistent_id
          "occ-pid-#{src.persistent_id}"
        elsif src && src.respond_to?(:entity_id) && src.entity_id
          "occ-eid-#{src.entity_id}"
        else
          "occ-idx-#{record.object_id}"
        end
      end

      # Build a small geometry_summary Hash for a source Edge.
      # Mirrors the V1.3 FaceInventory summary style.
      def _geometry_summary_for_edge(edge)
        return {} if edge.nil?
        layer_name = (edge.respond_to?(:layer) && edge.layer) ? edge.layer.to_s : nil
        {
          'layer'        => layer_name,
          'length'       => (edge.respond_to?(:length) ? edge.length : nil),
          'vertex_count' => 2
        }
      end

      # Build a small geometry_summary Hash for a source Face.
      def _geometry_summary_for_face(face)
        return {} if face.nil?
        layer_name = (face.respond_to?(:layer) && face.layer) ? face.layer.to_s : nil
        {
          'layer'        => layer_name,
          'vertex_count' => (face.respond_to?(:vertices) ? face.vertices.length : nil)
        }
      end

      # Build a deterministic id fragment from a source
      # record so derived_id is stable across rebuilds (per
      # directive: "rebuild is deterministic for identical
      # source + captured config").
      def _stable_id_fragment(record)
        return '0' if record.nil?
        src = record.respond_to?(:source) ? record.source : nil
        if src && src.respond_to?(:persistent_id) && src.persistent_id
          "pid#{src.persistent_id}"
        elsif src && src.respond_to?(:entity_id) && src.entity_id
          "eid#{src.entity_id}"
        else
          "x#{record.object_id}"
        end
      end

      # Build a representative face point array for an Edge
      # so the adapter's add_face_to_group has 3+ points to
      # consume. We construct a degenerate but valid 3-point
      # face at the edge's start / end / a small Z offset --
      # this is sufficient for the V1.4 plumbing path; the
      # actual repair geometry is V1.5+ scope.
      def _face_points_for_edge(edge)
        return nil if edge.nil?
        s = edge.respond_to?(:start_point) ? edge.start_point : nil
        e = edge.respond_to?(:end_point)   ? edge.end_point   : nil
        return nil unless s.is_a?(Array) && e.is_a?(Array) && s.length >= 3 && e.length >= 3
        # 3-point face: start, end, midpoint-with-Z-lift.
        mid = [
          (s[0] + e[0]) / 2.0,
          (s[1] + e[1]) / 2.0,
          [(s[2] + e[2]) / 2.0, 1.0].max  # ensure distinct from any collinear points
        ]
        [s, e, mid]
      end

      def _face_points_for_face(face)
        return nil if face.nil?
        vs = face.respond_to?(:vertices) ? face.vertices : nil
        if vs.is_a?(Array) && vs.length >= 3
          vs[0..2].map { |v| v.is_a?(Array) ? v : [0.0, 0.0, 0.0] }
        else
          nil
        end
      end

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

      # V1.4 CodeX BLOCK fix (Stage 4): test-only accessor
      # for the current DerivedGeometryWorkspace. Returns
      # the workspace instance (with its private handle
      # registry) so production-call-chain tests can assert
      # on entity_count / handle_registry_keys / state.
      # NOT exposed via the snapshot Hash (snapshot() still
      # returns JSON-safe primitives only).
      def current_workspace_for_test
        @current_workspace
      end
    end
  end
end
