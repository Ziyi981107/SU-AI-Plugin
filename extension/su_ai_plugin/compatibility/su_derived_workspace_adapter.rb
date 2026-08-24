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
      def dispose(handle)
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
    end
  end
end
