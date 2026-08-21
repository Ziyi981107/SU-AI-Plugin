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
# V1.4 CodeX BLOCK fix (Stage 4): the adapter also exposes
# a SketchUp operation-wrapping boundary (begin_operation /
# end_operation). The workspace calls begin before any
# host mutation, then end(commit: true|false). On commit: false
# the adapter MUST abort the SU operation so partial derived
# entities are rolled back. This is what makes "failure
# injection cleanup all created handles" possible without
# leaking entities.
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

module SUAnalysis
  module Core
    # Abstract base class. Production code subclasses this
    # for the SketchUp adapter; tests subclass it for the
    # FakeAdapter.
    class DerivedWorkspaceAdapter
      # Create a new top-level group in the derived workspace.
      # Returns a host handle (e.g. a SketchUp::Group). The
      # caller is responsible for storing the handle in the
      # workspace's PRIVATE handle registry.
      # Raises StandardError on any failure. The workspace
      # wraps the call in a fail-safe cleanup.
      def create_top_level_group(name)
        raise NotImplementedError, 'subclass must implement create_top_level_group'
      end

      # Add an edge (a single line segment) to an existing
      # group, preserving the source edge's two world-
      # coordinate endpoints EXACTLY. No Z lift, no extra
      # Face, no fabrication. Returns a host handle for the
      # edge (per directive: "V1.4 derived edge must use
      # real add_edges/add_line capabilities, faithfully
      # preserving the two world-coordinate endpoints").
      # Raises StandardError on failure.
      def add_edge_to_group(group_handle, start_point, end_point)
        raise NotImplementedError, 'subclass must implement add_edge_to_group'
      end

      # Add a face (a polygon with >= 3 world-coordinate
      # vertices) to an existing group. The face is only
      # added if the caller supplies a faithful Array of
      # vertex coordinates (length >= 3, all Float). When
      # the source's face vertices are NOT faithfully
      # representable (e.g. only 2 endpoints from a derived
      # Edge, or non-Float values), the caller MUST NOT use
      # this method; per directive, fabricating a face from
      # non-faithful input is forbidden. The caller signals
      # "unsupported" via the workspace's :failed transition.
      # Raises StandardError on failure.
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

      # V1.4 CodeX BLOCK fix (Stage 4): begin a SketchUp
      # operation. Production adapter wraps this in
      # `model.start_operation(label, true)`. FakeAdapter
      # is a no-op (no model).
      # Returns nothing.
      def begin_operation(_model, label:)
        raise NotImplementedError, 'subclass must implement begin_operation'
      end

      # V1.4 CodeX BLOCK fix (Stage 4): end a SketchUp
      # operation. commit=true -> `model.commit_operation`;
      # commit=false -> `model.abort_operation`. The
      # adapter MUST honor the commit flag precisely so
      # partial derived entities are rolled back on
      # failure injection.
      def end_operation(_model, commit:)
        raise NotImplementedError, 'subclass must implement end_operation'
      end
    end

    # Test adapter: in-memory model that emulates the host
    # without touching SketchUp. The fake group is a
    # Struct + a child Array. The fake face is a Struct.
    #
    # V1.4 CodeX BLOCK fix (Stage 4): the FakeAdapter now
    # ALSO tracks real (fake) handles via a registry, and
    # supports operation wrapping (no-op for the fake
    # model, but observable via @operations_open and
    # @operation_log so the test can assert operation
    # boundaries are honored).
    class FakeDerivedWorkspaceAdapter < DerivedWorkspaceAdapter
      # Mimics Sketchup::Entities. Tracks each add_edge /
      # add_face call so the test can assert endpoint
      # identity, no extra Face, and no Z lift.
      FakeEntities = Struct.new(:items) do
        def initialize
          super([])
        end
        def add_item(item)
          items << item
          item
        end
        def edges
          items.select { |i| i.is_a?(FakeEdge) }
        end
        def faces
          items.select { |i| i.is_a?(FakeFace) }
        end
        def invalidate_all!
          items.each(&:erase!)
          items.clear
        end
      end
      FakeGroup = Struct.new(:derived_id, :name, :children, :valid) do
        # Mimic Sketchup::Entity#valid?. After dispose,
        # the fake handle reports valid? == false.
        def valid?
          self[:valid] != false
        end
        def erase!
          # Children may be a FakeEntities (post-2026-08-21) or
          # a plain Array (legacy callers in tests). Tolerate
          # both.
          ch = self[:children]
          if ch.respond_to?(:invalidate_all!)
            ch.invalidate_all!
          elsif ch.is_a?(Array)
            ch.clear
          end
          self[:valid] = false
          true
        end
        def add_child(item)
          ch = self[:children]
          if ch.respond_to?(:add_item)
            ch.add_item(item)
          elsif ch.is_a?(Array)
            ch << item
          end
          item
        end
      end
      # A sketchup::Edge stand-in: stores start / end / layer /
      # entityID. After erase, valid? returns false. Tests
      # assert endpoint XYZ identity via `edge.start` /
      # `edge.end` (per BLOCK 7 risk test: source Edge ->
      # derived Edge endpoints must be XYZ-identical).
      FakeEdge = Struct.new(:entityID, :start, :end, :layer, :valid) do
        def valid?
          self[:valid] != false
        end
        def erase?
          true
        end
        def erase!
          self[:valid] = false
          true
        end
      end
      FakeFace = Struct.new(:derived_id, :layer, :vertex_count, :valid, :vertices) do
        def valid?
          self[:valid] != false
        end
      end

      attr_reader :created_handles, :disposed_handles,
                  :operation_log, :operation_open,
                  :added_edges, :added_faces

      def initialize
        @created_handles = []
        @disposed_handles = []
        # V1.4 CodeX BLOCK rework (2026-08-21): track every
        # add_edge / add_face call so the test can assert
        # endpoint XYZ identity, no extra Face, and no Z lift.
        @added_edges = []
        @added_faces = []
        @id_counter = 0
        @next_entity_id = 0
        # V1.4 CodeX BLOCK fix (Stage 4): operation-wrapping
        # observability.
        @operation_open = false
        @operation_log  = []
        # Optional failure-injection hook (used by tests).
        @next_operation_should_raise = nil
      end

      def next_id
        @id_counter += 1
        "fake-#{@id_counter}"
      end

      def next_entity_id
        @next_entity_id += 1
      end

      # Test hook: inject a failure into the next operation
      # boundary. After this call, the NEXT begin_operation
      # OR end_operation call raises the given error.
      def inject_operation_failure!(error)
        @next_operation_should_raise = error
      end

      def create_top_level_group(name)
        derived_id = next_id
        g = FakeGroup.new(derived_id, name, FakeEntities.new, true)
        @created_handles << g
        g
      end

      # V1.4 CodeX BLOCK rework (2026-08-21): add_edge_to_group
      # preserves the source edge's two world-coordinate
      # endpoints EXACTLY. No Z lift, no extra Face. The
      # FakeEdge handle is returned so tests can assert the
      # endpoint identity via edge.start / edge.end.
      def add_edge_to_group(group_handle, start_point, end_point)
        unless group_handle && group_handle.respond_to?(:add_child)
          raise ArgumentError,
                "group_handle is not a derived group: #{group_handle.inspect}"
        end
        unless _is_finite_point?(start_point) && _is_finite_point?(end_point)
          raise ArgumentError,
                "add_edge_to_group requires two finite world-coordinate points; got #{start_point.inspect}, #{end_point.inspect}"
        end
        edge = FakeEdge.new(
          next_entity_id,
          _copy_point(start_point),
          _copy_point(end_point),
          (group_handle.respond_to?(:name) ? 'Layer0' : nil),
          true
        )
        @added_edges << edge
        group_handle.add_child(edge)
        edge
      end

      # V1.4 CodeX BLOCK rework (2026-08-21): add_face_to_group
      # requires a faithful Array of >= 3 vertex points (each a
      # 3-Float Array). The caller MUST verify faithfulness
      # before invoking; the adapter does NOT fabricate
      # faces from non-faithful input. Per directive:
      # "fabricating a face from non-faithful input is
      # forbidden."
      def add_face_to_group(group_handle, points)
        unless group_handle && group_handle.respond_to?(:add_child)
          raise ArgumentError,
                "group_handle is not a derived group: #{group_handle.inspect}"
        end
        unless points.is_a?(Array) && points.length >= 3
          raise ArgumentError,
                "add_face_to_group requires Array of >= 3 vertex points; got #{points.inspect}"
        end
        unless points.all? { |p| _is_finite_point?(p) }
          raise ArgumentError,
                "add_face_to_group requires every vertex to be a finite 3-Float point"
        end
        verts = points.map { |p| _copy_point(p) }
        face = FakeFace.new(
          next_id,
          (group_handle.respond_to?(:name) ? 'Layer0' : nil),
          verts.length,
          true,
          verts
        )
        @added_faces << face
        group_handle.add_child(face)
        face
      end

      def dispose(handle)
        @disposed_handles << handle
        # Mark the handle invalid so it cannot be disposed
        # twice without raising.
        if handle.respond_to?(:erase!)
          handle.erase!
        end
        true
      end

      private

      # Validate that a point is a finite 3-Float Array.
      # We require v.is_a?(Float) explicitly -- Integer
      # is_a?(Numeric) but is NOT a Float and would corrupt
      # the derived edge's world-coordinate endpoints if
      # passed through silently. Per BLOCK 1: derived Edge
      # must preserve the source's two world-coordinate
      # endpoints EXACTLY (no implicit conversion, no Z
      # lift, no fabrication).
      def _is_finite_point?(p)
        return false unless p.is_a?(Array)
        return false unless p.length == 3
        p.all? do |v|
          v.is_a?(Float) && v.respond_to?(:finite?) && v.finite?
        end
      end

      # Defensive copy of a 3-Float point (so callers cannot
      # mutate the derived edge's stored endpoints after the
      # fact).
      def _copy_point(p)
        [p[0], p[1], p[2]]
      end

      public

      def host_assigned_ids_of(handle)
        if handle.respond_to?(:derived_id)
          { 'fake_derived_id' => handle.derived_id }
        else
          {}
        end
      end

      # Operation-wrapping boundary. The fake model is a
      # no-op (no real SU to call into), but the boundary
      # IS observable so tests can assert (a) operations
      # are opened before any host mutation, (b) operations
      # are committed on success, (c) operations are aborted
      # on failure.
      def begin_operation(_model, label:)
        _consume_failure_injection!
        @operation_open = true
        @operation_log << { kind: :begin, label: label.to_s }
        nil
      end

      def end_operation(_model, commit:)
        _consume_failure_injection!
        @operation_log << { kind: commit ? :commit : :abort }
        @operation_open = false
        nil
      end

      private

      def _consume_failure_injection!
        err = @next_operation_should_raise
        return nil if err.nil?
        @next_operation_should_raise = nil
        raise err
      end
    end
  end
end
