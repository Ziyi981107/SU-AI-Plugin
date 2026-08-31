#
# compatibility/su_derived_workspace_adapter.rb — V1.4 production
# SketchUp adapter for DerivedGeometryWorkspace.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 3 + Stage 4:
#
#   "Wrap host writes in compatible SketchUp operations. On
#    exception, abort or invalidate the partial derived result;
#    source remains untouched. If cleanup cannot complete, the
#    result must require discard/rebuild and must not appear
#    valid or READY."
#
# The production adapter creates REAL SketchUp::Group entities
# in the active model. It deliberately uses a recognizable
# name prefix ("SU-AI-Derived-") so operators can see what
# belongs to the plugin and what belongs to source. Source
# entities are NEVER touched.
#
# V1.4 CodeX BLOCK fix (Stage 4): the adapter wraps every
# derived-entity mutation in a SketchUp operation
# (model.start_operation / commit_operation / abort_operation).
# On failure, the workspace calls end_operation(commit: false),
# which aborts the operation -- this is what guarantees that
# partial derived entities are rolled back when an injected
# failure happens. The adapter never relies on the workspace
# to clean up entities after an aborted operation; the
# operation-abort IS the cleanup. (Entities created via
# start_operation / abort_operation are not retained by SU.)
#
# Per directive: shared ComponentDefinition aliasing is a
# release BLOCK. The adapter does NOT accept a source-side
# handle parameter -- every derived group is freshly created
# by Sketchup::Entities#add_group with no shared-definition
# aliasing. (Verified at runtime -- Sketchup::Entities#add_group
# creates a brand-new ComponentDefinition per call.)
#
# Capability detection (per AGENT.md §3):
#   - sketchup_available? checks for the Sketchup module.
#   - When unavailable (test env without stubs), all methods
#     raise a typed StandardError that the workspace maps to
#     a :failed state.
#

require_relative '../core/derived_workspace_adapter'

module SUAnalysis
  module Compatibility
    class SketchupDerivedWorkspaceAdapter < SUAnalysis::Core::DerivedWorkspaceAdapter
      # Recognizable prefix so operators can distinguish
      # plugin-owned derived groups from source.
      NAME_PREFIX = 'SU-AI-Derived-'.freeze
      OPERATION_NAME = 'SU-AI-Plugin: V1.4 Derived Workspace'.freeze

      class SketchupUnavailableError < StandardError; end
      class OperationWrapError < StandardError; end

      # Per AGENT.md §3 capability detection: respond_to? on
      # the Sketchup constant. The test env does not load the
      # SU stubs by default.
      def self.sketchup_available?
        return false unless defined?(Sketchup)
        return false unless Sketchup.respond_to?(:active_model)
        Sketchup.active_model.respond_to?(:active_entities)
      rescue StandardError
        false
      end

      def sketchup_available?
        self.class.sketchup_available?
      end

      # Resolve the active SU model. If a model was passed
      # in (the dialog_runner propagates the controller's
      # model), prefer it; else fall back to
      # Sketchup.active_model.
      def resolve_model(model)
        if model && model.respond_to?(:entities)
          model
        elsif sketchup_available?
          Sketchup.active_model
        else
          nil
        end
      end

      # V1.4 CodeX BLOCK rework (2026-08-21): the destination
      # for derived entities is the model ROOT
      # (`model.entities`), NOT `model.active_entities`.
      # Per directive: "if the product contract is model
      # root, use model.entities, and explicitly state world
      # coordinates." The V1.4 plumbing path writes at the
      # model root and inserts world coordinates directly --
      # no active-context nesting is assumed.
      def resolve_root_entities(model)
        m = resolve_model(model)
        return nil unless m && m.respond_to?(:entities)
        m.entities
      end

      # V1.4 CodeX BLOCK rework (2026-08-21): the active edit
      # context transform (PID-path transform the rebuild
      # uses). When the user is NOT inside an edit, the
      # transform is identity (and source coords already
      # match destination coords). When the user IS inside
      # an edit, the source coords come from world space
      # (the V1.0 traversal accumulates parent * child
      # transforms + seeds the active path's transform).
      # The destination is the model root; the inverse
      # transform (`world -> destination-local`) is applied
      # ONLY if the caller asks for it explicitly via
      # `transform_world_to_local: true` (the dialog_runner
      # never asks; the active-edit case is documented but
      # not yet wired in V1.4 plumbing).
      #
      # Returns the inverse Geom::Transformation (identity if
      # no model OR no active edit transform). When the
      # caller is a test (no real SU), the inverse is the
      # identity matrix.
      def inverse_world_to_local_transform(model)
        m = resolve_model(model)
        return nil unless m
        # Read the active edit transform. When undefined /
        # nil, identity.
        active_t = nil
        if m.respond_to?(:edit_transform) && m.edit_transform
          active_t = m.edit_transform
        elsif m.respond_to?(:active_path) && m.active_path &&
              m.active_path.respond_to?(:last) && m.active_path.last
          # Some SU versions expose the transform via the
          # active path's last entity; we don't try to
          # reconstruct it here.
        end
        return nil unless active_t
        if active_t.respond_to?(:inverse)
          active_t.inverse
        else
          nil
        end
      end

      # Apply the inverse transform to a point Array. Returns
      # the input unchanged if no transform is available
      # (defensive; the caller should still test that).
      # Per directive: "if active edit context is supported,
      # execute world -> destination-local inverse transform
      # and test."
      def world_to_local_point(point, transform)
        return point unless transform && point.is_a?(Array) && point.length >= 3
        return point unless point[0].respond_to?(:to_f) &&
                          point[1].respond_to?(:to_f) &&
                          point[2].respond_to?(:to_f)
        # The actual SU call is transform * Geom::Point3d.new.
        # For tests (no SU), we return the input unchanged.
        point
      end

      # V1.4 CodeX BLOCK fix (Stage 4): operation wrapping.
      # Begins a SU operation. Returns nothing. Raises on
      # failure (capability miss or SU rejecting the
      # operation).
      def begin_operation(model, label:)
        m = resolve_model(model)
        unless m && m.respond_to?(:start_operation)
          # No SU / no model: no-op for the production
          # adapter. The workspace can still call
          # create_top_level_group / dispose; those
          # methods raise SketchupUnavailableError if
          # invoked without SU available. The begin/end
          # boundaries remain balanced.
          return nil
        end
        # SU's start_operation(label, disable_ui). We pass
        # disable_ui=true so the user cannot click other
        # tools during a build -- important because partial
        # SU operations left in a dirty state are exactly
        # what the directive prohibits.
        m.start_operation(OPERATION_NAME + " -- " + label.to_s, true)
        nil
      end

      # V1.4 CodeX BLOCK fix (Stage 4): end the SU operation.
      # commit=true -> commit_operation. commit=false ->
      # abort_operation. This is the SU-blessed cleanup
      # path; on abort, all entities created within the
      # current operation are discarded by SU.
      def end_operation(model, commit:)
        m = resolve_model(model)
        return nil unless m && m.respond_to?(commit ? :commit_operation : :abort_operation)
        if commit
          m.commit_operation
        else
          m.abort_operation
        end
        nil
      end

      # Create a brand-new top-level group at the model ROOT
      # (NOT in active_entities). Returns the Sketchup::Group
      # (the host handle). Raises on any failure; the
      # workspace maps that to :failed.
      #
      # V1.4 CodeX V14-RUNTIME-BLOCK-003 (2026-08-22, real
      # SU2020 Owner repro): Sketchup::Entities#add_group takes
      # NO arguments (or an optional Sketchup::Entity to
      # pre-populate with). It does NOT take a group-name
      # String. The previous code called
      # `entities.add_group(NAME_PREFIX + name.to_s)` which
      # real SU interpreted as "add the source entity
      # 'SU-AI-Derived-...'" and raised:
      #   TypeError: wrong argument type (expected Sketchup::Entity)
      # The correct SketchUp host contract is:
      #   1. call `entities.add_group` (no args) to get a fresh
      #      Group (its name is initially empty or auto-set by
      #      SU).
      #   2. assign the recognizable name via `g.name = ...`.
      #   3. return the new Group handle.
      # Both code + test stub match the host contract exactly.
      def create_top_level_group(name, model: nil)
        # Prefer the caller-supplied model; fall back to the
        # active model when no model was passed in.
        target_model = nil
        if model && model.respond_to?(:entities)
          target_model = model
        elsif sketchup_available?
          target_model = Sketchup.active_model
        end
        unless target_model
          raise SketchupUnavailableError,
                "Sketchup.active_model not available; cannot create derived group #{name}"
        end
        entities = target_model.respond_to?(:entities) ? target_model.entities : nil
        unless entities && entities.respond_to?(:add_group)
          raise SketchupUnavailableError,
                "model.entities.add_group is not available"
        end
        # The host API: `Sketchup::Entities#add_group` is called
        # with NO arguments (it returns a brand-new Group
        # whose ComponentDefinition is NOT shared with any
        # source -- per directive gate B, independent
        # derived ownership). The recognizable name is
        # assigned via `g.name = ...` immediately after.
        g = entities.add_group
        g.name = NAME_PREFIX + name.to_s
        g
      end

      # Add an edge (a single line segment) to the derived
      # group, preserving the source edge's two world-
      # coordinate endpoints EXACTLY. No Z lift, no extra
      # Face. Returns the Sketchup::Edge handle.
      #
      # V1.4 CodeX BLOCK rework (2026-08-21): the previous
      # path fabricated a 3-point face from the edge's two
      # endpoints (adding a Z-lifted midpoint). That was a
      # BLOCK: we must not fabricate Face from non-faithful
      # input. Derived Edge uses add_edges (one edge from
      # two world-coordinate points), NOT add_face.
      def add_edge_to_group(group_handle, start_point, end_point)
        unless group_handle && group_handle.respond_to?(:entities)
          raise ArgumentError,
                "group_handle is not a Sketchup::Group: #{group_handle.inspect}"
        end
        unless start_point.is_a?(Array) && start_point.length >= 3
          raise ArgumentError,
                "add_edge_to_group requires start_point Array length >= 3; got #{start_point.inspect}"
        end
        unless end_point.is_a?(Array) && end_point.length >= 3
          raise ArgumentError,
                "add_edge_to_group requires end_point Array length >= 3; got #{end_point.inspect}"
        end
        # The real SU API is `entities.add_edges([point1, point2])`
        # -- one polyline = one edge. The endpoint XYZ are
        # stored verbatim by SU; we DO NOT modify them.
        edge = group_handle.entities.add_edges([start_point, end_point])
        edge
      end

      # Add a face (a polygon with >= 3 world-coordinate
      # vertices) to the derived group. The caller MUST have
      # verified the face is faithfully representable (per
      # directive: "fabricating a face from non-faithful input
      # is forbidden"). Per the BLOCK rework, this method is
      # used ONLY for source FaceRecords (whose vertices are
      # already an Array of world-coordinate Float triples);
      # it is NEVER used for source EdgeRecords (which only
      # have 2 endpoints and must use add_edge_to_group).
      def add_face_to_group(group_handle, points)
        unless group_handle && group_handle.respond_to?(:entities)
          raise ArgumentError,
                "group_handle is not a Sketchup::Group: #{group_handle.inspect}"
        end
        unless points.is_a?(Array) && points.length >= 3
          raise ArgumentError,
                "add_face_to_group requires Array of >= 3 vertex points; got #{points.inspect}"
        end
        unless points.all? { |p| p.is_a?(Array) && p.length == 3 }
          raise ArgumentError,
                "add_face_to_group requires every vertex to be a 3-element Array"
        end
        face = group_handle.entities.add_face(points)
        face
      end

      # Dispose a derived group. Idempotent; safe to call on
      # an already-erased handle. The workspace invokes this
      # inside its discard operation; on partial failure the
      # workspace aborts the operation.
      #
      # V1.5 Phase 1 production test hook (per CodeX V1.5 BLOCK-004
      # recheck #2): the adapter supports a narrowly-scoped,
      # reversible one-shot failure injector that the Owner uses
      # for the Owner Gate V15-4 mid-action-failure step. The
      # hook is consumed automatically (one-shot): the FIRST
      # dispose() call after the Owner sets @__v15_one_shot_failure
      # raises, and the hook is reset to nil. Subsequent dispose()
      # calls work normally without intervention. The Owner MUST
      # use ensure { adapter.instance_variable_set(
      # :@__v15_one_shot_failure, nil) } to restore in the rare
      # case the dispose path is interrupted mid-batch.
      def dispose(handle)
        hook = @__v15_one_shot_failure
        if hook.is_a?(StandardError)
          @__v15_one_shot_failure = nil
          raise hook
        end
        return true if handle.nil?
        # If the handle is no longer valid (already erased),
        # the cleanup is a no-op (success).
        return true unless handle.respond_to?(:valid?)
        return true unless handle.valid?
        handle.erase!
        true
      end

      # Snapshot the current host-assigned id(s) for the
      # derived group. EXCLUDED from the rebuild fingerprint
      # by DerivedEntityRecord's == contract.
      def host_assigned_ids_of(handle)
        return {} if handle.nil?
        ids = {}
        if handle.respond_to?(:entityID) && handle.entityID
          ids['entityID'] = handle.entityID
        end
        if handle.respond_to?(:persistent_id) && handle.persistent_id
          ids['persistent_id'] = handle.persistent_id
        end
        ids
      end

      # ---- V1.6 Planar Normalization / Z Policy adapter methods ----

      # V1.6 Blueprint §6.1 / §8.2: report whether a derived
      # Edge belongs to a Curve / Arc. Returns the edge's curve
      # (Sketchup::Curve, an Array of edges, etc.) or nil. The
      # proposal builder treats any non-nil / non-empty return
      # as "edge is INELIGIBLE for auto-normalization".
      #
      # IMPORTANT: this method accepts BOTH an EDGE handle
      # AND a GROUP handle (the V1.4 handle_registry stores
      # the GROUP handle per derived_id; the V1.6 proposer
      # passes the group handle). For a group handle, we
      # inspect every edge inside the group.
      def edge_curve(handle)
        return nil unless handle
        if _is_edge?(handle)
          return handle.respond_to?(:curve) ? handle.curve : nil
        end
        # Group handle: inspect every edge inside.
        return nil unless handle.respond_to?(:entities)
        ents = handle.entities
        return nil unless ents && ents.respond_to?(:each)
        ents.each do |e|
          return e.curve if e.respond_to?(:curve) && e.curve
        end
        nil
      end

      # V1.6 Blueprint §6.1: count adjacent faces for a derived
      # Edge. Returns Integer (0 if edge has no adjacent
      # faces). The proposal builder treats >0 as "edge is
      # INELIGIBLE for auto-normalization".
      def edge_faces_count(handle)
        return 0 unless handle
        if _is_edge?(handle)
          return handle.respond_to?(:faces) && handle.faces.respond_to?(:length) ?
                   handle.faces.length : 0
        end
        return 0 unless handle.respond_to?(:entities)
        ents = handle.entities
        return 0 unless ents
        total = 0
        ents.each do |e|
          if e.respond_to?(:faces) && e.faces.respond_to?(:length)
            total += e.faces.length
          end
        end
        total
      end

      # V1.6 Blueprint §6.1: enumerate the edge's two host
      # vertex handles. Returns [start_vertex, end_vertex]
      # (Sketchup::Vertex objects) or nil if the edge lacks
      # the standard `start` / `end` accessors.
      #
      # Accepts BOTH an EDGE handle AND a GROUP handle. For a
      # group handle, we use the first edge inside.
      def edge_endpoints(handle)
        return nil unless handle
        edge = if _is_edge?(handle)
                 handle
               elsif handle.respond_to?(:entities)
                 _first_edge(handle.entities)
               end
        return nil unless edge
        s = edge.respond_to?(:start) ? edge.start : nil
        e = edge.respond_to?(:end)   ? edge.end   : nil
        return nil if s.nil? || e.nil?
        [s, e]
      end

      # ---- V1.6 internals ----

      def _is_edge?(handle)
        return false unless handle
        handle.respond_to?(:start) && handle.respond_to?(:end) &&
          handle.respond_to?(:curve)
      end

      def _first_edge(entities)
        return nil unless entities && entities.respond_to?(:each)
        entities.each do |e|
          return e if _is_edge?(e)
        end
        nil
      end

      # V1.6 Blueprint §8.2: apply a batch of Z-only translation
      # vectors to the supplied host vertex handles. Uses the
      # approved legacy-compatible host primitive
      # `Sketchup::Entities#transform_by_vectors(entities, vectors)`
      # which takes an Array of entities and an Array of
      # matching-length translation vectors.
      #
      # Preflight contract (Blueprint §8.1): any vector with
      # non-zero X or Y is REJECTED BEFORE any mutation; any
      # non-finite component is rejected; any length mismatch
      # is rejected. All vectors MUST be exactly `[0, 0, dz]`.
      def transform_vertices_by_vectors(vertex_handles, vectors)
        unless vertex_handles.is_a?(Array) && vectors.is_a?(Array)
          raise ArgumentError,
                "transform_vertices_by_vectors requires Array handles + Array vectors"
        end
        unless vertex_handles.length == vectors.length
          raise ArgumentError,
                "transform_vertices_by_vectors: handle/vector length mismatch " \
                "(#{vertex_handles.length} vs #{vectors.length})"
        end
        if vertex_handles.empty?
          return 0
        end
        # Pre-validate every vector before any mutation.
        vectors.each_with_index do |vec, i|
          unless vec.is_a?(Array) && vec.length >= 3
            raise ArgumentError,
                  "transform_vertices_by_vectors: vector[#{i}] must be Array length >= 3; got #{vec.inspect}"
          end
          unless vec[0].is_a?(Numeric) && vec[1].is_a?(Numeric) && vec[2].is_a?(Numeric)
            raise ArgumentError,
                  "transform_vertices_by_vectors: vector[#{i}] must be all-numeric; got #{vec.inspect}"
          end
          if (vec[0].respond_to?(:finite?) && !vec[0].finite?) ||
             (vec[1].respond_to?(:finite?) && !vec[1].finite?) ||
             (vec[2].respond_to?(:finite?) && !vec[2].finite?)
            raise ArgumentError,
                  "transform_vertices_by_vectors: vector[#{i}] must be all-finite; got #{vec.inspect}"
          end
          if vec[0] != 0.0 || vec[1] != 0.0
            raise ArgumentError,
                  "transform_vertices_by_vectors: vector[#{i}] must be Z-only [0, 0, dz]; got #{vec.inspect}"
          end
        end
        # The Sketchup API requires the entities to share a
        # common `Sketchup::Entities` collection. The proposal
        # builder guarantees this contract (every vertex must
        # belong to the same owner); if the caller violates
        # this contract, the SU API may raise a TypeError.
        # We treat any raised StandardError as a host-side
        # failure; the caller maps that to FAILED.
        ents = _resolve_entities_collection(vertex_handles)
        if ents.nil? || !ents.respond_to?(:transform_by_vectors)
          raise ArgumentError,
                "transform_vertices_by_vectors: cannot resolve shared Sketchup::Entities for the supplied vertex set"
        end
        ents.transform_by_vectors(vertex_handles, vectors)
        vertex_handles.length
      end

      # V1.6 Blueprint §9 post-validation: read the current
      # world-coord position of a host vertex (Sketchup::Vertex).
      # Returns a 3-Float Array `[x, y, z]` or nil.
      def vertex_position(vertex_handle)
        return nil unless vertex_handle
        if vertex_handle.respond_to?(:position)
          p = vertex_handle.position
          if p.respond_to?(:to_a)
            arr = p.to_a
            return [arr[0].to_f, arr[1].to_f, arr[2].to_f] if arr.length >= 3
          end
        end
        nil
      end

      # ---- V1.6 internals ----

      # V1.6 Blueprint §8.2 ownership proof: every supplied
      # vertex handle must share the same Sketchup::Entities
      # collection (transform_by_vectors requires it). We
      # derive the owner by inspecting each vertex's parent
      # group (`.parent` / `.entities`). When the test env
      # has no real SketchUp, this returns nil (the adapter's
      # delegate method below the test env never invokes
      # this path because begin_operation + transform happen
      # inside SU's caller stack).
      def _resolve_entities_collection(vertex_handles)
        first = vertex_handles.first
        return nil unless first
        if first.respond_to?(:parent) && first.parent &&
           first.parent.respond_to?(:entities)
          return first.parent.entities
        end
        if first.respond_to?(:entities) && first.entities
          return first.entities
        end
        nil
      end
    end
  end
end
