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

require_relative '../core/edge_record'
require_relative '../core/geometry_snapshot'
require_relative '../core/preflight'
require_relative '../core/source_reference'
require_relative '../compatibility/su_capability'

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
      # S2-BLOCK-001 fix: each source Edge yields exactly ONE EdgeRecord.
      # The two endpoints are read once via edge.start.position and
      # edge.end.position. Orientation-insensitive duplicate detection
      # lives in DuplicateDetector (already correct).
      #
      # S2-BLOCK-002 fix: each yielded edge carries the accumulated
      # transformation (in world coords) so the EdgeRecord is created
      # in world space. instance_path is set on the SourceReference so
      # the same definition Edge used by two ComponentInstances stays
      # two distinct analysis occurrences.
      def build_snapshot(selection)
        edges     = []
        preflight = collect_preflight_facts(selection)

        walk_selection_world(selection) do |entity, world_points, instance_path|
          next unless SUAnalysis::Compatibility::SUCapability.edge?(entity)
          next if world_points.size < 2
          begin
            src = SUAnalysis::Compatibility::SUCapability.build_source_reference(
              entity, kind: 'edge', instance_path: instance_path
            )
            layer = SUAnalysis::Compatibility::SUCapability.layer_name(entity)
            layer = 'Layer0' if layer.nil? || layer.empty?
            edges << SUAnalysis::Core::EdgeRecord.new(
              id:          edges.size,
              source:      src,
              start_point: world_points[0],
              end_point:   world_points[1],
              layer:       layer
            )
          rescue StandardError => e
            # PI_TASK_001 §18: skip safely, continue. We do NOT raise.
            warn "[SU-AI-Plugin] skipped invalid edge: #{e.class}: #{e.message}"
          end
        end

        SUAnalysis::Core::GeometrySnapshot.new(
          edges:     edges,
          layers:    [],
          preflight: preflight
        )
      end

      # -----------------------------------------------------------------
      # S2-BLOCK-002 — Traversal with accumulated transforms
      # -----------------------------------------------------------------

      # Walk every entity reachable from `selection` and yield each Edge
      # along with its 2 endpoints in WORLD coordinates and an
      # instance_path describing its container chain.
      #
      # Transform multiplication order: SU applies parent -> child.
      # Going deeper multiplies on the right: world = parent * child.
      # We track `accum_transform` as a chain; each entry is applied to
      # the next depth via `*` (Geom::Transformation overloads * for
      # matrix concatenation). For tests we use the duck-type matrix
      # multiply via apply_to_point (if defined) or treat as identity.
      #
      # Mock-friendly: every step uses respond_to? checks so test
      # fakes don't need the real Geom::Transformation class.
      def walk_selection_world(selection, &block)
        return unless selection
        return unless selection.respond_to?(:each)
        selection.each do |root|
          walk_entity_world(root, identity_transform, [], nil, &block)
        end
      end

      def walk_entity_world(entity, parent_t, parent_path, parent_kind, &block)
        return if entity.nil?
        # Apply this entity's own transformation (relative to parent).
        own_t = read_transformation(entity, parent_kind)
        world_t = combine_transforms(parent_t, own_t)

        if SUAnalysis::Compatibility::SUCapability.container?(entity)
          path = parent_path + [container_label(entity)]
          children = container_children(entity)
          if children.nil?
            # Empty / locked / deleted definition — skip silently.
            return
          end
          children.each do |child|
            child_kind = container_kind(entity)
            walk_entity_world(child, world_t, path, child_kind, &block)
          end
        elsif SUAnalysis::Compatibility::SUCapability.edge?(entity)
          yield entity, edge_world_endpoints(entity, world_t), parent_path
        end
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

      def safe_each(coll)
        return nil if coll.nil?
        coll
      rescue StandardError
        nil
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
        if vertex.nil?
          return [0.0, 0.0, 0.0]
        end
        pos = vertex.respond_to?(:position) ? vertex.position : nil
        if pos.nil?
          return [0.0, 0.0, 0.0]
        end
        apply_transform(world_t, [pos.x.to_f, pos.y.to_f, pos.z.to_f])
      rescue StandardError
        [0.0, 0.0, 0.0]
      end

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