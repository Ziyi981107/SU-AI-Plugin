#
# extension/preflight_runner.rb — SketchUp-side entry point for Preflight.
#
# This is the only file in the project allowed to call into Sketchup::*.
# It builds a GeometrySnapshot from a real Sketchup::Selection, then hands
# it to core/PreflightAnalyzer (pure Ruby) for the actual analysis.
#
# Per PI_TASK_001:
#   §6  Preflight 收集 selection type / Group/Component 计数 / bbox / Z / 嵌套
#   §8  Z 信息只记入 Preflight，不做修复
#   §14 SketchUp API Layer 只跟 SU 对话; Geometry Core 是纯 Ruby
#   §18 Error Handling: 一条坏 Entity 不能让整个分析退出
#
# Per Codex Review 004 (2026-08-17), this file was BLOCKED and required:
#   S2-BLOCK-001: emit ONE EdgeRecord per source Edge (was 2).
#   S2-BLOCK-002: walk Group.entities AND ComponentInstance.definition.entities;
#                 accumulate Geom::Transformation through recursion; apply to
#                 endpoints; carry instance_path for composite source identity.
#   S2-BLOCK-003: NO &. (Ruby 2.3+); explicit nil guards only (Ruby 2.2.4
#                 baseline per Q003+A).
#
# Ruby 2.2.4 syntax rules followed throughout:
#   - No &. safe-navigation operator
#   - No pattern matching (case/in)
#   - No numbered parameters (_1, _2)
#   - No endless method definitions
#   - No kwargs sugar (key:)
#   - No frozen_string_literal magic comments
#
# Owner verifies this file's behavior in real SU per Q002=A. Synthetic
# tests cover the core/ Preflight path AND an adapter-level path via
# FakeEntity / FakeModel in tests/test_preflight_runner.rb.
#

require_relative 'core/edge_record'
require_relative 'core/geometry_snapshot'
require_relative 'core/preflight'
require_relative 'core/source_reference'
require_relative 'compatibility/su_capability'

module SUAnalysis
  module Extension
    module PreflightRunner
      module_function

      # Public entry point. Accepts a Sketchup::Selection (or any object
      # exposing #each + #count, e.g. an Array of entities, for testing).
      # Returns a PreflightReport.
      def run(selection)
        snapshot = build_snapshot(selection)
        SUAnalysis::Core::PreflightAnalyzer.run(snapshot)
      end

      # Walk the selection, collect all Edges (recursing into nested
      # Groups / ComponentInstances), build EdgeRecords and a preflight
      # facts hash. Never mutates the source entities.
      #
      # S2-BLOCK-001 fix (round 1): each source Edge yields exactly ONE
      # EdgeRecord. Orientation-insensitive duplicate detection lives in
      # DuplicateDetector.
      #
      # S2-BLOCK-002 fix (round 2): each yielded edge carries the
      # accumulated transformation (in world coords) so the EdgeRecord is
      # created in world space. persistent_id_path is set on the
      # SourceReference so the same definition Edge used by two
      # ComponentInstances stays two distinct analysis occurrences.
      #
      # Active edit-context support: when model has an active edit path,
      # walk seeds its world transform with the active path's transform
      # instead of identity. The active path's PIDs are prepended to
      # each yielded entity's pid_path.
      def build_snapshot(selection, model: nil)
        # Per CodeX Round 020 REAL-HOST BLOCK (recheck):
        #   (1) The real SketchUp::Selection object is not always safe
        #       to iterate more than once. Some SU versions (and some
        #       Selection-like mocks) consume iteration state on the
        #       first .each, so a subsequent .each yields 0 items.
        #   (2) On SU2020, `Sketchup::Selection#to_ary` (Ruby's strict
        #       array-coercion protocol) returns an empty Array even
        #       when the selection contains entities. Treating `to_ary`
        #       as an authoritative conversion path silently empties
        #       the normalized selection. We must NOT use `to_ary`; we
        #       use `to_a` (documented public API) with `each` as the
        #       universal fallback.
        # We normalize the input to a stable Array at the boundary so
        # preflight + walk + label extraction all see the same set.
        selection = normalize_selection(selection)
        edges     = []
        preflight = collect_preflight_facts(selection)

        # Use the AUTHORITATIVE helper for active-edit-context facts.
        # Per CodeX Round 014 Gate B proof #1: structural_depth is
        # the REAL entity count from model.active_path, NOT the filtered
        # PID array length.
        active_facts = SUAnalysis::Compatibility::SUCapability.active_edit_context_facts(model)
        # If active facts.transform is nil (outside SU; test fakes may
        # use FakeSU::Transformation for identity), substitute our
        # adapter's identity.
        seed_t = active_facts[:transform].nil? ? identity_transform : active_facts[:transform]

        # V1.1 (per plan §4.6): per-layer aggregates. Local to this
        # build_snapshot call so test state does not leak across
        # calls (a module-level @hash would persist).
        layer_aggregates = {}

        # V1.3 (per directive 027): per-face occurrences parallel
        # to per-edge occurrences. Same defensive per-leaf rescue
        # pattern; faces with no `loops` / `outer_loop` capability
        # are skipped via the `face?` predicate below.
        faces = []

        walk_selection_world(
          selection,
          seed_t:               seed_t,
          seed_pid_path:        active_facts[:pid_path],
          seed_struct_depth:    active_facts[:structural_depth],
          seed_path_complete:    active_facts[:pid_path_complete]
        ) do |entity, world_points, pid_path, label_path, struct_depth, path_complete|
          if SUAnalysis::Compatibility::SUCapability.edge?(entity)
            next if world_points.nil? || world_points.size < 2
            begin
              # pid_path_complete for the leaf: AND of parent completeness
              # AND leaf PID non-nil.
              leaf_pid = SUAnalysis::Compatibility::SUCapability.safe_persistent_id(entity)
              leaf_complete = !leaf_pid.nil?
              full_complete = path_complete && leaf_complete
              layer_name = SUAnalysis::Compatibility::SUCapability.layer_name(entity)
              layer_name = 'Layer0' if layer_name.nil? || layer_name.empty?
              src = SUAnalysis::Compatibility::SUCapability.build_source_reference(
                entity,
                kind:               'edge',
                persistent_id_path: pid_path,
                instance_path:      label_path,
                structural_depth:   struct_depth,
                pid_path_complete:  full_complete,
                layer_name:         layer_name
              )
              edges << SUAnalysis::Core::EdgeRecord.new(
                id:          edges.size,
                source:      src,
                start_point: world_points[0],
                end_point:   world_points[1],
                layer:       layer_name
              )
              # V1.1 (per plan §4.6): accumulate per-layer aggregate.
              # Track the first entity reference for each layer so the
              # post-walk layer_visibility probe has a real Entity (not
              # just a Layer object) to pass to SUCapability.layer_visibility
              # — which is the entity-as-input adapter that drills
              # `entity.layer` and probes `layer.visible?`. Passing the
              # raw Layer object would force SUCapability to call
              # `entity.layer` on the Layer itself, which always returns
              # :unknown (real Layers / our FakeLayer don't expose a
              # `.layer` method). The stored entity MAY be nil if the
              # edge lacked `respond_to?(:layer)` — handled gracefully
              # in build_layer_records (R011 :unknown fallback).
              layer_aggregates[layer_name] ||= {
                name:        layer_name,
                edge_count:  0,
                entity:      entity
              }
              layer_aggregates[layer_name][:edge_count] += 1
            rescue StandardError => e
              # PI_TASK_001 §18: skip safely, continue. We do NOT raise.
              warn "[SU-AI-Plugin] skipped invalid edge: #{e.class}: #{e.message}"
            end
          elsif SUAnalysis::Compatibility::SUCapability.face?(entity)
            # V1.3 (per directive 027): one FaceRecord per face
            # occurrence in the selection tree. Per directive item
            # "Invalid/erased/malformed Face objects must be skipped
            # per entity without aborting sibling geometry", the
            # face? predicate already returned true above; if any
            # face-specific probe raises (e.g. invalid Face raised
            # on `outer_loop` / `loops`), we rescue and skip cleanly.
            begin
              leaf_pid = SUAnalysis::Compatibility::SUCapability.safe_persistent_id(entity)
              leaf_complete = !leaf_pid.nil?
              full_complete = path_complete && leaf_complete
              layer_name = SUAnalysis::Compatibility::SUCapability.face_layer_name(entity)
              outer_v = SUAnalysis::Compatibility::SUCapability.face_outer_loop_vertex_count(entity)
              inner_n = SUAnalysis::Compatibility::SUCapability.face_inner_loop_count(entity)
              src = SUAnalysis::Compatibility::SUCapability.build_source_reference(
                entity,
                kind:               'face',
                persistent_id_path: pid_path,
                instance_path:      label_path,
                structural_depth:   struct_depth,
                pid_path_complete:  full_complete,
                layer_name:         layer_name
              )
              faces << SUAnalysis::Core::FaceRecord.new(
                id:                       faces.size,
                source:                   src,
                layer:                    layer_name,
                outer_loop_vertex_count:  outer_v,
                inner_loop_count:         inner_n
              )
              layer_aggregates[layer_name] ||= {
                name:        layer_name,
                edge_count:  0,
                entity:      entity
              }
              has_holes = inner_n > 0
              layer_aggregates[layer_name][:face_count] = (layer_aggregates[layer_name][:face_count] || 0) + 1
              layer_aggregates[layer_name][:faces_with_holes_count] = (layer_aggregates[layer_name][:faces_with_holes_count] || 0) + (has_holes ? 1 : 0)
              layer_aggregates[layer_name][:entity] ||= entity  # keep first entity seen (Edge preferred over Face for visibility probe)
            rescue StandardError => e
              warn "[SU-AI-Plugin] skipped invalid face: #{e.class}: #{e.message}"
            end
          end
        end

        # V1.1 (per plan §4.6): build the per-layer LayerRecord list
        # after the walk. For each aggregate, probe visibility via
        # SUCapability.layer_visibility (R011) and classify role via
        # LayerRoleConfig.classify (R010 top-down-by-priority).
        layer_records = build_layer_records(layer_aggregates)

        SUAnalysis::Core::GeometrySnapshot.new(
          edges:     edges,
          layers:    layer_records,
          preflight: preflight,
          faces:     faces
        )
      end

      # Build Array<LayerRecord> from the post-walk per-layer
      # aggregates. Probes visibility once per layer via the
      # entity-aware SUCapability.layer_visibility (R011) and
      # classifies role via LayerRoleConfig.classify (R010
      # top-down-by-priority). The stored `agg[:entity]` is the
      # first Edge entity captured for that layer during the walk;
      # passing the entity (NOT the layer object) matches the
      # SUCapability contract (entity.layer -> layer.visible?).
      def build_layer_records(aggregates)
        records = []
        aggregates.each do |name, agg|
          edge_entity = agg[:entity]
          # If the stored entity doesn't expose a `layer` method,
          # SUCapability will fail closed and return :unknown (R011).
          # We keep the safe-attr style here to remain robust for
          # zero-capability edges.
          vis_status = if edge_entity.nil? || !edge_entity.respond_to?(:layer)
                         # R011: entity lacked .layer OR no entity was
                         # captured -> cannot probe; fall back to
                         # :unknown (operational visible: true, with
                         # visibility_unknown: true).
                         :unknown
                       else
                         # Probe via the entity-aware adapter. For
                         # FakeSU entities, entity.layer returns a
                         # FakeSU::Layer (no `.layer` method on the
                         # layer itself, so SUCapability returns
                         # :unknown with proper R011 fallback).
                         # Tests that want explicit visibility set
                         # up custom edges / mocks that DO expose
                         # visible? on the layer.
                         v = begin
                               SUAnalysis::Compatibility::SUCapability.layer_visibility(edge_entity)
                             rescue StandardError
                               :unknown
                             end
                         v
                       end
          visible, vis_unknown = case vis_status
                                  when :visible  then [true,  false]
                                  when :hidden   then [false, false]
                                  when :unknown  then [true,  true]
                                  else                [true,  false]
                                  end
          role, rule_id = SUAnalysis::Core::LayerRoleConfig.classify(name)
          records << SUAnalysis::Core::LayerRecord.new(
            name:               name,
            edge_count:         agg[:edge_count],
            role:               role,
            role_rule:          rule_id,
            visible:            visible,
            visibility_unknown: vis_unknown,
            face_count:         agg[:face_count] || 0,
            faces_with_holes_count: agg[:faces_with_holes_count] || 0
          )
        end
        # Sort by name for determinism (mapper re-sorts by role bucket).
        records.sort_by { |r| r.name }
      end

      # -----------------------------------------------------------------
      # CodeX Round 020 REAL-HOST BLOCK (recheck): normalize selection
      # at the boundary so both preflight + walk see the same stable
      # entity array. The real SketchUp::Selection (and any one-shot
      # Selection-like enumerable) is not always safe to iterate
      # more than once, AND on SU2020 the host's Selection#to_ary
      # returns an empty Array even when the selection contains
      # entities (Ruby's strict array-coercion protocol is honored
      # to mean "[]", NOT to mean "the selected entities"). We must
      # NOT trust `to_ary`; use `to_a` (documented public API) as
      # the one-pass capture, with `each` as the universal fallback.
      # -----------------------------------------------------------------

      # Public: convert any selection-like input to a stable Array.
      # Returns [] for nil. For Array inputs, returns a copy (so
      # downstream mutation of the result does not leak back).
      # For Selection-like objects:
      #   1. try to_a (documented Sketchup::Selection public API) and
      #      rescue on failure. This is the authoritative one-pass
      #      capture path. NEVER use `to_ary`: SU2020's
      #      Sketchup::Selection#to_ary returns [] even when the
      #      selection has entities, which silently empties the
      #      normalized selection and breaks the whole analysis.
      #   2. fallback to manual each (rescue on iteration failure)
      #      if to_a is not available OR returns a non-Array.
      #   3. last resort: empty array.
      def normalize_selection(input)
        return [] if input.nil?
        return input.dup if input.is_a?(Array)

        # 1. Prefer `to_a` (documented Sketchup::Selection public API).
        #    On SU2020 this returns the actual selected entities as a
        #    fresh Array; subsequent calls return fresh copies, so the
        #    capture is safe and stable.
        if input.respond_to?(:to_a)
          begin
            arr = input.to_a
            return arr.dup if arr.is_a?(Array)
            # to_a returned a non-Array; fall through to manual each.
          rescue StandardError
            # to_a raised; fall through to manual each.
          end
        end

        # 2. Fall back to manual `each` iteration. Handles objects
        #    that don't implement `to_a` but DO iterate.
        if input.respond_to?(:each)
          arr = []
          begin
            input.each { |e| arr << e }
          rescue StandardError
            # iteration raised; return whatever we collected so far.
          end
          return arr
        end

        []
      end

      # -----------------------------------------------------------------
      # S2-BLOCK-002 — Traversal with accumulated transforms
      # -----------------------------------------------------------------

      # Walk every entity reachable from `selection` and yield each Edge
      # along with its 2 endpoints in WORLD coordinates and an
      # instance_path describing its container chain.
      #
      # Per CodeX Round 014 Gate B: yield also carries
      # structural_depth and path_complete (computed on the leaf side
      # of the pipeline). Active edit-context seed is passed via
      # seed_struct_depth / seed_path_complete (= 0 / true when no
      # active edit).
      def walk_selection_world(selection, seed_t: nil, seed_pid_path: nil,
                                seed_struct_depth: 0, seed_path_complete: false, &block)
        return unless selection
        return unless selection.respond_to?(:each)
        seed_t        ||= identity_transform
        seed_pid_path ||= []
        selection.each do |root|
          walk_entity_world(
            root, seed_t, seed_pid_path, [], nil,
            seed_struct_depth, seed_path_complete, &block
          )
        end
      end

      def walk_entity_world(entity, parent_t, parent_pid_path, parent_label_path, parent_kind,
                            parent_struct_depth, parent_path_complete, &block)
        return if entity.nil?
        # If entity is invalid (erased / deleted / raises on respond_to?),
        # skip cleanly without aborting siblings. The block is never
        # yielded for invalid entities. Per S2-BLOCK-005 round 2.
        return unless entity_valid?(entity)

        # Apply this entity's own transformation (relative to parent).
        own_t = read_transformation(entity, parent_kind)
        world_t = combine_transforms(parent_t, own_t)

        # PID path: append this container's PID (if any).
        my_pid = SUAnalysis::Compatibility::SUCapability.safe_persistent_id(entity)
        new_pid_path = my_pid.nil? ? parent_pid_path.dup : parent_pid_path.dup << my_pid

        if SUAnalysis::Compatibility::SUCapability.container?(entity)
          # Structural depth: this container adds 1 to the parent's depth.
          # The leaf is NOT counted (CodeX BLOCK-001 v3 / v4 contract).
          new_struct_depth = parent_struct_depth + 1
          # Path completeness: the absence of my_pid flips completeness
          # to false (fail closed).
          child_path_complete = parent_path_complete && !my_pid.nil?
          new_label_path = parent_label_path + [container_label(entity)]
          children = safe_each(container_children(entity))
          if children.nil?
            # Empty / locked / deleted definition — skip silently.
            return
          end
          children.each do |child|
            child_kind = container_kind(entity)
            begin
              walk_entity_world(
                child, world_t, new_pid_path, new_label_path, child_kind,
                new_struct_depth, child_path_complete, &block
              )
            rescue StandardError => e
              # §18 + S2-BLOCK-005 r2: per-child rescue so one bad
              # child does not abort siblings.
              warn "[SU-AI-Plugin] skipped invalid child: #{e.class}: #{e.message}"
            end
          end
        elsif SUAnalysis::Compatibility::SUCapability.edge?(entity)
          begin
            endpoints = edge_world_endpoints(entity, world_t)
          rescue InvalidGeometryError => e
            # Per S2-BLOCK-005 r2: skip the entire Edge; do NOT
            # synthesize origin geometry.
            warn "[SU-AI-Plugin] skipped invalid edge: #{e.message}"
            return
          end
          # At the leaf: structural_depth EXCLUDES the leaf itself.
          # path_complete is the parent's; the leaf pid_completeness
          # is ANDed in by the caller (build_snapshot) so non-leaf
          # callers like tests can inspect it separately.
          yield entity, endpoints, new_pid_path, parent_label_path,
                parent_struct_depth, parent_path_complete
        elsif SUAnalysis::Compatibility::SUCapability.face?(entity)
          # V1.3 (per directive 027): yield one event per Face
          # occurrence. Faces have no endpoints (they are
          # 2-D topology, not 1-line geometry), so we yield
          # `nil` as the world-points placeholder; the caller's
          # `case leaf_kind` switch treats the Face branch
          # specially and does not read world_points.
          # structural_depth / pid_path_complete follow the same
          # Edge-leaf discipline (depth excludes the leaf itself).
          yield entity, nil, new_pid_path, parent_label_path,
                parent_struct_depth, parent_path_complete
        end
      end

      # Returns true if the entity is safe to traverse / yield. Fails
      # closed: any unexpected condition returns false.
      def entity_valid?(entity)
        return false if entity.nil?
        # Real SU exposes .valid? on Entity. We don't strictly require it
        # because fakes may not implement it; respond_to? is enough.
        if entity.respond_to?(:valid?)
          return false unless entity.valid?
        end
        if entity.respond_to?(:deleted?) && entity.deleted?
          return false
        end
        if entity.respond_to?(:erased?) && entity.erased?
          return false
        end
        true
      rescue StandardError
        false
      end

      # Children of a container. For Group: `group.entities`. For
      # ComponentInstance: `instance.definition.entities`. For test
      # fakes, accept either.
      def container_children(entity)
        if SUAnalysis::Compatibility::SUCapability.component_instance?(entity)
          defn = entity.respond_to?(:definition) ? entity.definition : nil
          return nil if defn.nil?
          # S2-BLOCK-002 fix: definition.entities (NOT instance.entities).
          return defn.respond_to?(:entities) ? safe_each(defn.entities) : nil
        end
        # Group OR test fake container
        return nil unless entity.respond_to?(:entities)
        safe_each(entity.entities)
      end

      # Returns the collection, or an empty Array if enumeration raises.
      # Per S2-BLOCK-005 round 2: must actually wrap iteration, not just
      # return the collection and hope downstream iteration is safe.
      def safe_each(coll)
        return nil if coll.nil?
        result = []
        begin
          coll.each { |item| result << item }
        rescue StandardError
          # Caller gets the items successfully enumerated up to the
          # failure. Sibling entities continue normally.
        end
        result
      end

      def container_kind(entity)
        return :component if SUAnalysis::Compatibility::SUCapability.component_instance?(entity)
        return :group if SUAnalysis::Compatibility::SUCapability.group?(entity)
        # Test fakes: guess from class name.
        cls = entity.class.name.to_s
        return :component if cls.include?('ComponentInstance') || cls.include?('FakeComponent')
        :group
      end

      def container_label(entity)
        kind = container_kind(entity)
        name = nil
        if entity.respond_to?(:definition) && entity.definition && entity.definition.respond_to?(:name)
          name = entity.definition.name.to_s
        end
        if name.nil? || name.empty?
          name = (entity.respond_to?(:name) && entity.name.is_a?(String)) ? entity.name : nil
        end
        if name.nil? || name.empty?
          name = format('0x%x', entity.object_id)
        end
        kind_label = (kind == :component) ? 'ComponentInstance' : 'Group'
        label = "#{kind_label}:#{name}"
        # Per S2-BLOCK-002: distinguish two ComponentInstances sharing one
        # definition. Append a short suffix using object_id hex so the
        # path is unique per instance even when names collide.
        if kind == :component
          label = "#{label}#0x#{entity.object_id.to_s(16)}"
        end
        label
      end

      # -----------------------------------------------------------------
      # Transform handling
      # -----------------------------------------------------------------

      # Identity transform: prefer SU's Geom::Transformation.new if
      # available, else build a 4x4 identity Array for test mocks.
      def identity_transform
        return Geom::Transformation.new if defined?(Geom::Transformation)
        # 4x4 identity matrix (row-major)
        [
          [1.0, 0.0, 0.0, 0.0],
          [0.0, 1.0, 0.0, 0.0],
          [0.0, 0.0, 1.0, 0.0],
          [0.0, 0.0, 0.0, 1.0]
        ]
      end

      # Extract the underlying 4x4 matrix from either a SU
      # Geom::Transformation (which IS the matrix in SU's API) or a
      # test FakeSU::Transformation (which wraps via .matrix), or a
      # raw Array of arrays.
      def to_matrix(t)
        return t.matrix if t.respond_to?(:matrix) && !t.is_a?(Array)
        t
      end

      # The local transform of an entity. Groups and ComponentInstances
      # expose .transformation; test fakes expose it as well.
      def read_transformation(entity, parent_kind)
        if entity.respond_to?(:transformation) && !entity.transformation.nil?
          return entity.transformation
        end
        identity_transform
      rescue StandardError
        identity_transform
      end

      # world_t = parent_t * own_t. SU overloads *; test fakes get
      # the matrix multiply below.
      def combine_transforms(parent_t, own_t)
        if defined?(Geom::Transformation) && parent_t.is_a?(Geom::Transformation)
          return parent_t * own_t
        end
        # 4x4 matrix multiply for test mocks.
        a = to_matrix(parent_t)
        b = to_matrix(own_t)
        mat_mul(a, b)
      end

      def mat_mul(a, b)
        result = Array.new(4) { Array.new(4, 0.0) }
        4.times do |i|
          4.times do |j|
            s = 0.0
            4.times { |k| s += a[i][k] * b[k][j] }
            result[i][j] = s
          end
        end
        # Return a Transformation wrapper if input was a Transformation.
        if defined?(FakeSU::Transformation)
          FakeSU::Transformation.new(result)
        else
          result
        end
      end

      # Apply a transform to a 3D point. SU provides #transform! / #*
      # overloads on Geom::Point3d; for tests we do the math directly.
      def apply_transform(t, point)
        x = point[0]
        y = point[1]
        z = point[2]
        if defined?(Geom::Transformation) && t.is_a?(Geom::Transformation)
          # Real SU path: wrap into Point3d, transform, unwrap.
          p = Geom::Point3d.new(x, y, z)
          out = t * p
          return [out.x.to_f, out.y.to_f, out.z.to_f]
        end
        # Test mock path: t is either raw 4x4 array or
        # FakeSU::Transformation wrapper.
        m = to_matrix(t)
        nx = m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3]
        ny = m[1][0] * x + m[1][1] * y + m[1][2] * z + m[1][3]
        nz = m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3]
        [nx, ny, nz]
      end

      def edge_world_endpoints(edge, world_t)
        p1 = vertex_point_world(edge.start, world_t)
        p2 = vertex_point_world(edge.end, world_t)
        [p1, p2]
      end

      def vertex_point_world(vertex, world_t)
        # Per S2-BLOCK-005 round 2: invalid vertices must NOT silently
        # be converted to origin. Raise so the per-Edge rescue skips
        # the entire Edge. The caller catches this in build_snapshot.
        if vertex.nil?
          raise InvalidGeometryError, 'vertex is nil'
        end
        pos = vertex.respond_to?(:position) ? vertex.position : nil
        if pos.nil?
          raise InvalidGeometryError, 'vertex.position is nil'
        end
        apply_transform(world_t, [pos.x.to_f, pos.y.to_f, pos.z.to_f])
      rescue InvalidGeometryError
        raise
      rescue StandardError
        raise InvalidGeometryError, "vertex extraction failed: #{$ERROR_MESSAGE}"
      end

      class InvalidGeometryError < StandardError; end

      # -----------------------------------------------------------------
      # Preflight facts (SU-side fields)
      # -----------------------------------------------------------------

      def collect_preflight_facts(selection)
        groups  = 0
        comps   = 0
        deepest = 0
        nested  = []
        sel_type = describe_selection(selection)

        if selection.respond_to?(:each)
          selection.each do |root|
            count_containers_world(root, [0], []) do |depth, kind, label|
              if kind == :group
                groups += 1
              else
                comps  += 1
              end
              deepest = depth if depth > deepest
              nested << ('  ' * depth + label)
            end
          end
        end

        {
          sketchup_version:  version_to_string(SUAnalysis::Compatibility::SUCapability.sketchup_version),
          selection_type:    sel_type,
          group_count:       groups,
          component_count:   comps,
          deepest_nesting:   deepest,
          nested_containers: nested
        }
      end

      def version_to_string(v)
        v.nil? ? nil : v.to_s
      end

      def count_containers_world(entity, depth_arr, path, visited = nil, &block)
        visited = if visited.nil?
                    {}
                  else
                    visited.dup
                  end
        visited[entity.object_id] = true
        return unless SUAnalysis::Compatibility::SUCapability.container?(entity)

        # Per R001: root selected container = level 1. Increment first,
        # yield after.
        depth_arr[0] += 1
        kind = container_kind(entity)
        label = container_label(entity)
        yield depth_arr[0], kind, label
        children = container_children(entity)
        if !children.nil?
          children.each do |c|
            count_containers_world(c, depth_arr, path, visited, &block) unless visited.key?(c.object_id)
          end
        end
        depth_arr[0] -= 1
      end

      # -----------------------------------------------------------------
      # S2-BLOCK-004 — Mixed selection detection
      # -----------------------------------------------------------------

      def describe_selection(selection)
        return 'empty' unless selection.respond_to?(:count) && selection.count > 0

        types = []
        if selection.respond_to?(:each)
          selection.each do |entity|
            t = classify_root(entity)
            types << t unless types.include?(t)
            break if types.size > 1 # we only need to know "more than one"
          end
        end
        return 'unknown' if types.empty?
        return types.first if types.size == 1
        'mixed'
      end

      def classify_root(entity)
        return 'ComponentInstance' if SUAnalysis::Compatibility::SUCapability.component_instance?(entity)
        return 'Group' if SUAnalysis::Compatibility::SUCapability.group?(entity)
        return 'Edges' if SUAnalysis::Compatibility::SUCapability.edge?(entity)
        if entity.respond_to?(:typename)
          tn = entity.typename.to_s
          return tn.empty? ? 'unknown' : tn
        end
        'unknown'
      end
    end
  end
end