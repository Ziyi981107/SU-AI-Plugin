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

      # V1.6 Planar Normalization / Z Policy: report whether a
      # derived Edge belongs to a Curve / Arc. Returning a truthy
      # value marks the edge as INELIGIBLE for auto-normalization
      # (the analyzer will skip its vertices). Per Blueprint §6.1,
      # Curve / Arc members must not be auto-normalized.
      # Default for the abstract base: raises NotImplementedError;
      # production + fake adapters override.
      def edge_curve(_handle)
        raise NotImplementedError, 'subclass must implement edge_curve'
      end

      # V1.6 Planar Normalization / Z Policy: count the
      # adjacent Faces for a derived Edge. Returning >0 marks
      # the edge as INELIGIBLE for auto-normalization. Per
      # Blueprint §6.1, Face-adjacent edges must not be
      # auto-normalized. Default for the abstract base: raises
      # NotImplementedError; production + fake adapters
      # override.
      def edge_faces_count(_handle)
        raise NotImplementedError, 'subclass must implement edge_faces_count'
      end

      # V1.6 Planar Normalization / Z Policy: inspect a derived
      # edge for safety under the host's `transform_by_vectors`
      # mutation. The base contract is: returns a Hash
      # `{safe: true | false, reasons: [...]}`. Subclasses MAY
      # override to add host-specific safety checks; the default
      # covers curve/face safety via edge_curve + edge_faces_count
      # (subclasses are responsible for implementing those).
      # This method is intentionally NOT an abstract raise: the
      # base class can compose a default answer from the two
      # subclass-provided primitives.
      def edge_safety(edge_handle)
        reasons = []
        curve = edge_curve(edge_handle)
        unless curve.nil? || (curve.respond_to?(:empty?) && curve.empty?)
          reasons << 'curve_membership'
        end
        fc = edge_faces_count(edge_handle)
        if fc.is_a?(Integer) && fc > 0
          reasons << 'face_adjacency'
        end
        {
          'safe'    => reasons.empty?,
          'reasons' => reasons.freeze
        }.freeze
      end

      # V1.6 Planar Normalization / Z Policy: mutate multiple
      # host vertices with one Z-only translation vector. Used by
      # the production path. The base contract: returns the
      # number of vertices actually mutated, OR raises on
      # failure. The vectors must be `[0, 0, dz]`; the adapter
      # MUST reject vectors with non-zero X or Y per Blueprint
      # §8.2 (Z-only movement).
      def transform_vertices_by_vectors(_vertex_handles, _vectors)
        raise NotImplementedError, 'subclass must implement transform_vertices_by_vectors'
      end

      # V1.6 Planar Normalization / Z Policy: read the current
      # world-coord position of a host vertex (returned as a
      # 3-Float Array). Used by the post-validation path. Default
      # for the abstract base: raises NotImplementedError.
      def vertex_position(_vertex_handle)
        raise NotImplementedError, 'subclass must implement vertex_position'
      end

      # V1.6 Planar Normalization / Z Policy: enumerate every
      # unique host vertex belonging to the supplied derived
      # edge handle. Returns an Array of host vertex handles
      # (length 2 for a faithful edge). The base contract:
      # subclasses override. Used by the proposal builder to
      # resolve analyzer-proposed vertex indices to live host
      # handles.
      #
      # IMPORTANT: the V1.4 handle_registry stores the GROUP
      # handle per derived_id (one SU-AI-Derived-* group per
      # source Edge, with the edge inside the group). The
      # proposer therefore calls edge_endpoints with the
      # GROUP handle, not the EDGE handle. Implementations
      # MUST accept BOTH (resolve the inner edge when given a
      # group handle).
      def edge_endpoints(_handle)
        raise NotImplementedError, 'subclass must implement edge_endpoints'
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

      # ---- V1.7 Endpoint / Gap Repair + Canonical Topology ----

      # Ensure (or recreate) the workspace-owned REPAIR group
      # for V1.7 gap bridges. Per Blueprint §12.1, the repair
      # group is a dedicated transient derived group at model
      # root. The executor calls this exactly once per apply
      # batch.
      #
      # Default contract:
      #   - if a repair group already exists for the supplied
      #     workspace_id, return the existing one (idempotent).
      #   - else create a fresh group and record it.
      #
      # Returns the group handle, or nil if creation fails.
      def ensure_repair_group(workspace_id:, label:, model: nil)
        raise NotImplementedError, 'subclass must implement ensure_repair_group'
      end

      # Add ONE explicit repair line to the supplied repair
      # group. Per Blueprint §12.2 the primitive uses
      # `entities.add_edges([start_point, end_point])` (or
      # the legacy `add_line` equivalent). Returns the
      # bridge host handle, OR nil on failure.
      def add_line_to_repair_group(repair_group, p1, p2)
        raise NotImplementedError, 'subclass must implement add_line_to_repair_group'
      end

      # List the bridge host handles currently belonging to
      # the workspace-owned repair group (for discard /
      # cleanup / rebuild). Returns an Array of host
      # handles. Empty when no repair group exists.
      def repair_group_handles(_model)
        raise NotImplementedError, 'subclass must implement repair_group_handles'
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
      # V1.6 Planar Normalization / Z Policy: a fake host
      # vertex stand-in. Stores a 3-Float position; supports
      # position read + transform by a single `[0, 0, dz]`
      # vector (the fake's transform model is a plain Z
      # assignment so the test can assert Z movement while
      # proving XY is preserved).
      FakeVertex = Struct.new(:x, :y, :z, :valid) do
        def valid?
          self[:valid] != false
        end
        def position
          [self[:x], self[:y], self[:z]]
        end
        # Apply a single translation vector. For V1.6 (Z-only
        # normalization), the fake ignores X/Y and updates Z.
        # Returns the new position.
        def apply_vector(vec)
          return position unless vec.is_a?(Array) && vec.length >= 3
          self[:z] = (self[:z].to_f + vec[2].to_f)
          position
        end
      end
      FakeFace = Struct.new(:derived_id, :layer, :vertex_count, :valid, :vertices) do
        def valid?
          self[:valid] != false
        end
      end

      attr_reader :created_handles, :disposed_handles,
                  :operation_log, :operation_open,
                  :added_edges, :added_faces,
                  :vertex_handles_by_edge,
                  :repair_groups, :repair_group_bridges

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
        # V1.6 Planar Normalization / Z Policy: track every
        # fake host vertex handle created by add_edge_to_group
        # so the proposal builder can resolve analyzer-proposed
        # vertex indices to live host handles. Keyed by
        # FakeEdge (Struct-equality by identity).
        @vertex_handles_by_edge = {}
        # V1.4 CodeX BLOCK fix (Stage 4): operation-wrapping
        # observability.
        @operation_open = false
        @operation_log  = []
        # Optional failure-injection hook (used by tests).
        @next_operation_should_raise = nil
        # Round-5 BLOCK-005 §7: host-state-change simulation
        # hook. When set true, the next
        # WorkingModeRunner.validate_host_state_consistency!
        # call sees the adapter as inconsistent (simulates a
        # SketchUp Undo or external host change). Default
        # false. Tests can flip this via
        # `simulate_host_state_change!`.
        @host_state_changed = false
        # V1.7 Gap Repair: per-workspace repair group
        # registry. Keyed by workspace_id -> FakeGroup handle.
        @repair_groups = {}
        # V1.7 Gap Repair: bridge edges created via
        # add_line_to_repair_group. Each entry is
        # { 'workspace_id' => ..., 'handle' => FakeEdge }.
        @repair_group_bridges = []
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

      # Round-5 BLOCK-005 §7: host-state-change simulation
      # hook. When set true via `simulate_host_state_change!`,
      # the next `validate_host_state_consistency!` call sees
      # the adapter as inconsistent and transitions the
      # current workspace to :failed with reason
      # `host_state_changed`. Production code MUST NOT call
      # this; tests use it to simulate a SketchUp Undo or
      # external host change.
      def simulate_host_state_change!
        @host_state_changed = true
      end

      def clear_host_state_change!
        @host_state_changed = false
      end

      def host_state_changed?
        @host_state_changed ? true : false
      end

      # Create a brand-new top-level group under the supplied
      # (or active) model. Mirrors the production adapter's
      # contract (1 positional + 1 keyword arg).
      def create_top_level_group(name, model: nil)
        derived_id = next_id
        g = FakeGroup.new(derived_id, name, FakeEntities.new, true)
        @created_handles << g
        g
      end

      # ---- V1.7 Gap Repair / Canonical Topology helpers ----

      # ensure_repair_group: per-workspace repair group.
      # Idempotent: if a repair group already exists for the
      # given workspace_id (per @repair_groups) AND its
      # handle is still valid, return it. Otherwise create a
      # new one and record it. The handle is what the executor
      # passes to add_line_to_repair_group.
      def ensure_repair_group(workspace_id:, label:, model: nil)
        existing = @repair_groups[workspace_id.to_s]
        if existing && existing.respond_to?(:valid?) && existing.valid?
          return existing
        end
        g = create_top_level_group(label.to_s, model: model)
        @repair_groups[workspace_id.to_s] = g
        g
      end

      # add_line_to_repair_group: append one bridge edge to
      # the supplied repair group. Per Blueprint §12.2 this
      # uses add_edges([p1, p2]) under the hood; in the fake
      # model we emit a FakeEdge with the faithful world-coord
      # endpoints and remember it in @repair_group_bridges for
      # cleanup / rebuild.
      def add_line_to_repair_group(repair_group, p1, p2)
        return nil unless repair_group && repair_group.respond_to?(:add_child)
        return nil unless _is_finite_point?(p1) && _is_finite_point?(p2)
        edge = FakeEdge.new(
          next_entity_id,
          _copy_point(p1),
          _copy_point(p2),
          (repair_group.respond_to?(:name) ? repair_group.name.to_s : nil),
          true
        )
        wid = @repair_groups.key(repair_group)
        @repair_group_bridges << {
          'workspace_id' => wid || '',
          'handle'       => edge
        }
        repair_group.add_child(edge)
        edge
      end

      # repair_group_handles: list every bridge edge currently
      # belonging to workspace-owned repair groups. Returns an
      # Array of FakeEdge handles.
      def repair_group_handles(_model = nil)
        @repair_group_bridges.map { |e| e['handle'] }
      end

      # dispose_repair_group_bridges: discard every bridge
      # edge currently in workspace-owned repair groups
      # (used by discard / rebuild / close).
      def dispose_repair_group_bridges
        handles = @repair_group_bridges.map { |e| e['handle'] }
        handles.each do |h|
          begin
            dispose(h)
          rescue StandardError
            # never propagate adapter disposal failures from
            # cleanup paths
          end
        end
        @repair_group_bridges.clear
        @repair_groups.each_value do |g|
          begin
            if g.respond_to?(:valid?) && g.valid?
              g.erase! if g.respond_to?(:erase!)
            end
          rescue StandardError
            # ignore
          end
        end
        @repair_groups.clear
        handles.length
      end

      # V1.4 CodeX BLOCK rework (2026-08-21): add_edge_to_group
      # preserves the source edge's two world-coordinate
      # endpoints EXACTLY. No Z lift, no extra Face. The
      # FakeEdge handle is returned so tests can assert the
      # endpoint identity via edge.start / edge.end.
      #
      # V1.6 Planar Normalization / Z Policy: the fake adapter
      # ALSO creates a pair of FakeVertex handles for the
      # edge's endpoints and stores them in
      # @vertex_handles_by_edge[edge] = [v_start, v_end]. The
      # proposal builder reads this map to resolve analyzer-
      # proposed vertex indices back to host vertex handles
      # for `transform_vertices_by_vectors`.
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
        # V1.6 Planar Normalization / Z Policy: create the
        # two fake host vertex handles for this edge and
        # record them. The fake model does NOT dedupe
        # vertices across edges (each edge owns its own pair);
        # the proposal builder applies the analyzer's
        # unique-vertex dedupe at the world-coord level.
        v_start = FakeVertex.new(
          start_point[0].to_f, start_point[1].to_f, start_point[2].to_f, true
        )
        v_end = FakeVertex.new(
          end_point[0].to_f,   end_point[1].to_f,   end_point[2].to_f,   true
        )
        @vertex_handles_by_edge[edge] = [v_start, v_end].freeze
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

      # ---- V1.6 Planar Normalization / Z Policy adapter methods ----

      # V1.6 Blueprint §6.1 / §8.2: the fake model has no
      # Curve membership or Face adjacency for its
      # faithfully-derived Edges; safe by default.
      def edge_curve(_handle)
        nil
      end

      def edge_faces_count(_handle)
        0
      end

      # V1.6 Blueprint §6.1: enumerate the edge's two host
      # vertex handles (start, end). Accepts BOTH an EDGE
      # handle (recorded in @vertex_handles_by_edge by
      # add_edge_to_group) AND a GROUP handle (the V1.4
      # handle_registry stores the GROUP handle per
      # derived_id). For GROUP handles we traverse to the
      # first edge child of the group.
      def edge_endpoints(handle)
        return nil unless handle
        if @vertex_handles_by_edge.key?(handle)
          return @vertex_handles_by_edge[handle]
        end
        if handle.respond_to?(:children) && handle.children.respond_to?(:edges)
          first_edge = handle.children.edges.first
          return @vertex_handles_by_edge[first_edge] if first_edge
        end
        nil
      end

      # V1.6 Blueprint §8.2: apply a batch of Z-only translation
      # vectors to the supplied host vertex handles. The fake
      # model updates each vertex's stored Z by the vector's
      # Z component; X/Y are NOT mutated. Returns the number of
      # vertices actually mutated (length of the input when
      # all vectors are valid `[0, 0, dz]`).
      #
      # Defensive contract (Blueprint §8.1 preflight): any
      # vector with non-zero X or Y, OR any non-finite
      # component, raises ArgumentError BEFORE any mutation.
      # The caller is expected to have already verified the
      # inputs; this is the last-line defense.
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
        # Pre-validate every vector BEFORE any mutation.
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
        vertex_handles.each_with_index do |v, i|
          next if v.nil?
          if v.respond_to?(:apply_vector)
            v.apply_vector(vectors[i])
          elsif v.respond_to?(:position=) || v.respond_to?(:[]=)
            # Generic fallback: treat as a position struct.
            v[2] = v[2].to_f + vectors[i][2].to_f
          end
        end
        vertex_handles.length
      end

      # V1.6 Blueprint §9 post-validation: read the current
      # world-coord position of a host vertex. For the fake
      # model we delegate to the FakeVertex#position accessor
      # (3-Float Array).
      def vertex_position(vertex_handle)
        if vertex_handle.respond_to?(:position)
          vertex_handle.position
        elsif vertex_handle.is_a?(Array) && vertex_handle.length >= 3
          [vertex_handle[0], vertex_handle[1], vertex_handle[2]]
        else
          nil
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
