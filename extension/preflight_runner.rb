
#
# extension/preflight_runner.rb — SketchUp-side entry point for Preflight.
#
# This is the only file in the project allowed to call into Sketchup::*.
# It builds a GeometrySnapshot from a real SketchUp::Selection, then hands
# it to core/PreflightAnalyzer (pure Ruby) for the actual analysis.
#
# Per PI_TASK_001:
#   §6  Preflight 收集 selection type / Group/Component 计数 / bbox / Z / 嵌套
#   §8  Z 信息只记入 Preflight，不做修复
#   §14 SketchUp API Layer 只跟 SU 对话; Geometry Core 是纯 Ruby
#   §18 Error Handling: 一条坏 Entity 不能让整个分析退出
#
# Owner verifies this file's behavior in real SU per Q002=A. Synthetic
# tests cover the core/ Preflight path; this file is exercised only when
# the .rbz is loaded into SketchUp 2017+.
#

require_relative '../core/edge_record'
require_relative '../core/geometry_snapshot'
require_relative '../core/preflight'
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
      def build_snapshot(selection)
        edges       = []
        preflight   = collect_preflight_facts(selection)
        layer_names = {}

        walk_selection(selection) do |entity|
          next unless SUAnalysis::Compatibility::SUCapability.edge?(entity)

          begin
            src = SUAnalysis::Compatibility::SUCapability.build_source_reference(
              entity, kind: 'edge'
            )
            layer = SUAnalysis::Compatibility::SUCapability.layer_name(entity) || 'Layer0'

            entity.vertices.each_with_index do |v, i|
              # entity.vertices is a small (usually 2-element) Array of
              # Sketchup::Vertex; we make two directed half-records so
              # geometry_snapshot.rb's flat edges pipeline is unchanged.
              next_vertex = entity.vertices[(i + 1) % entity.vertices.size]
              p1 = vertex_point(v)
              p2 = vertex_point(next_vertex)
              edges << SUAnalysis::Core::EdgeRecord.new(
                id:          edges.size,
                source:      src,
                start_point: p1,
                end_point:   p2,
                layer:       layer
              )
            end

            layer_names[layer] = true
          rescue StandardError => e
            # PI_TASK_001 §18: skip safely, continue. We do NOT raise.
            warn "[SU-AI-Plugin] skipped invalid edge: #{e.class}: #{e.message}"
          end
        end

        # LayerRecord is a thin counter; snapshot can build layer dist
        # from edges alone. We pass an empty array here to keep the
        # snapshot constructor stable.
        SUAnalysis::Core::GeometrySnapshot.new(
          edges:     edges,
          layers:    [],
          preflight: preflight
        )
      end

      # -----------------------------------------------------------------
      # Private helpers
      # -----------------------------------------------------------------

      def walk_selection(selection, &block)
        return unless selection
        if selection.respond_to?(:each)
          selection.each { |e| walk_entity(e, &block) }
        end
      end

      def walk_entity(entity, visited = nil, depth = 0, &block)
        visited ||= {}.compare_by_identity

        return if visited.key?(entity)
        visited[entity] = true

        if SUAnalysis::Compatibility::SUCapability.container?(entity)
          # Recurse into nested entities.
          if entity.respond_to?(:entities)
            begin
              entity.entities.each { |c| walk_entity(c, visited, depth + 1, &block) }
            rescue StandardError
              # §18: empty group / deleted definition / locked entity — skip.
            end
          end
        elsif SUAnalysis::Compatibility::SUCapability.edge?(entity)
          yield entity
        end
      end

      def vertex_point(vertex)
        pos = vertex.position
        [pos.x.to_f, pos.y.to_f, pos.z.to_f]
      end

      # Collects selection-shape facts that core/ cannot compute itself.
      def collect_preflight_facts(selection)
        groups = 0
        comps  = 0
        deepest = 0
        nested  = []
        sel_type = describe_selection(selection)

        walk_selection(selection) do |entity|
          # block is invoked for every Edge; we don't increment container
          # counts here — do a separate pass to avoid double-walking.
        end

        # Separate pass for container stats.
        if selection.respond_to?(:each)
          selection.each do |root|
            count_containers(root, [0]) do |depth, kind, label|
              if kind == :group
                groups += 1
              else
                comps  += 1
              end
              deepest = depth if depth > deepest
              nested << ("  " * depth + label)
            end
          end
        end

        {
          sketchup_version:  SUAnalysis::Compatibility::SUCapability.sketchup_version&.to_s,
          selection_type:    sel_type,
          group_count:       groups,
          component_count:   comps,
          deepest_nesting:   deepest,
          nested_containers: nested
        }
      end

      def count_containers(entity, depth_arr, visited = nil, &block)
        visited ||= {}.compare_by_identity
        return if visited.key?(entity)
        visited[entity] = true

        if SUAnalysis::Compatibility::SUCapability.container?(entity)
          kind = SUAnalysis::Compatibility::SUCapability.group?(entity) ? :group : :component
          label = entity.respond_to?(:definition) && entity.definition &&
                    entity.definition.respond_to?(:name) ?
                    entity.definition.name.to_s : kind.to_s
          yield depth_arr.first, kind, label
          depth_arr[0] += 1
          if entity.respond_to?(:entities)
            begin
              entity.entities.each { |c| count_containers(c, depth_arr, visited, &block) }
            rescue StandardError
              # skip
            end
          end
          depth_arr[0] -= 1
        end
      end

      def describe_selection(selection)
        return 'empty' unless selection.respond_to?(:count) && selection.count > 0
        # Coarse-grained: first entity's type drives the label.
        first = nil
        if selection.respond_to?(:first)
          first = selection.first
        elsif selection.respond_to?(:to_a)
          first = selection.to_a.first
        end
        return 'unknown' unless first
        if SUAnalysis::Compatibility::SUCapability.component_instance?(first)
          'ComponentInstance'
        elsif SUAnalysis::Compatibility::SUCapability.group?(first)
          'Group'
        elsif SUAnalysis::Compatibility::SUCapability.edge?(first)
          'Edges'
        else
          first.respond_to?(:typename) ? first.typename.to_s : 'unknown'
        end
      end
    end
  end
end
