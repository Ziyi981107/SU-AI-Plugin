#
# core/derived_workspace_adapter.rb — V1.4 DerivedWorkspaceAdapter.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 3: DerivedGeometryWorkspace ownership +
# host adapter.
#
# "Wrap host writes in compatible SketchUp operations. On
#  exception, abort or invalidate the partial derived result;
#  source remains untouched. If cleanup cannot complete, the
#  result must require discard/rebuild and must not appear
#  valid or READY."
#
# The adapter defines the host-write boundary. V1.4 tests
# exercise the adapter via FakeDerivedWorkspaceAdapter; the
# production SketchUp adapter is wired in V1.4+ and never
# applied to source entities.
#
# Per the directive:
#   - "Every editable derived entity must be independently
#     owned; no shared mutable definition or attribute container
#     may alias source."
#   - "Choose and document the destination coordinate context,
#     then perform explicit world/local conversion at the
#     adapter boundary."
#   - "Apply/discard/rebuild must operate only on the
#     plugin-owned workspace."
#
# The adapter is a thin host-call wrapper. The workspace
# (DerivedGeometryWorkspace) is responsible for inventory,
# lifecycle, and the rebuild contract; the adapter is
# responsible for translating host-side operations into the
# V1.4 data records.
#

module SUAnalysis
  module Core
    # Abstract base class. Production code subclasses this
    # for the SketchUp adapter; tests subclass it for the
    # FakeAdapter.
    class DerivedWorkspaceAdapter
      # Create a new top-level group in the derived workspace.
      # Returns a host handle (e.g. a SketchUp::Group). The
      # caller is responsible for storing the handle in the
      # workspace inventory.
      # Raises StandardError on any failure. The workspace
      # wraps the call in a fail-safe cleanup.
      def create_top_level_group(name)
        raise NotImplementedError, 'subclass must implement create_top_level_group'
      end

      # Add a face to an existing group. Returns a host
      # handle for the face. Raises StandardError on failure.
      def add_face_to_group(group_handle, points)
        raise NotImplementedError, 'subclass must implement add_face_to_group'
      end

      # Dispose a single derived entity. Idempotent -- safe
      # to call multiple times on the same handle. Raises
      # StandardError if the host refuses; the workspace
      # marks itself :failed when disposal fails (per
      # directive: "the result must require discard/rebuild
      # and must not appear valid or READY").
      def dispose(handle)
        raise NotImplementedError, 'subclass must implement dispose'
      end

      # Snapshot the current host-assigned id(s) for a
      # handle. Used to populate DerivedEntityRecord's
      # host_assigned_ids field (which is EXCLUDED from the
      # rebuild fingerprint but recorded for audit).
      def host_assigned_ids_of(handle)
        raise NotImplementedError, 'subclass must implement host_assigned_ids_of'
      end
    end

    # Test adapter: in-memory model that emulates the host
    # without touching SketchUp. The fake group is a
    # Struct + a child Array. The fake face is a Struct.
    class FakeDerivedWorkspaceAdapter < DerivedWorkspaceAdapter
      FakeGroup = Struct.new(:derived_id, :name, :children) do
        def add_child(face)
          children << face
        end
      end
      FakeFace = Struct.new(:derived_id, :layer, :vertex_count)

      attr_reader :created_handles, :disposed_handles

      def initialize
        @created_handles = []
        @disposed_handles = []
        @id_counter = 0
        @next_entity_id = 0
      end

      def next_id
        @id_counter += 1
        "fake-#{@id_counter}"
      end

      def next_entity_id
        @next_entity_id += 1
      end

      def create_top_level_group(name)
        derived_id = next_id
        g = FakeGroup.new(derived_id, name, [])
        @created_handles << g
        g
      end

      def add_face_to_group(group_handle, points)
        face = FakeFace.new(
          next_id,
          (group_handle.respond_to?(:name) ? 'Layer0' : nil),
          points.respond_to?(:length) ? points.length : (points.is_a?(Array) ? points.length : 0)
        )
        group_handle.add_child(face)
        face
      end

      def dispose(handle)
        @disposed_handles << handle
        # No-op for the fake host.
        true
      end

      def host_assigned_ids_of(handle)
        # The fake host returns the derived_id as the only
        # 'host' id (so we can trace it). The real SketchUp
        # adapter would return entityID, persistent_id, etc.
        if handle.respond_to?(:derived_id)
          { 'fake_derived_id' => handle.derived_id }
        else
          {}
        end
      end
    end
  end
end