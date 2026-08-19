
require_relative 'edge_record'
require_relative 'vertex_record'
require_relative 'layer_record'
require_relative 'source_reference'
require_relative 'analysis_config'
require_relative 'vertex_index'

module SUAnalysis
  module Core
    #
    # GeometrySnapshot — aggregates edges, layers, preflight data, and a
    # VertexIndex. Built once per analysis, then handed read-only to all
    # analyzers. Stage 1 builds it by hand from SyntheticFactory; Stage 5
    # will build it from a SU selection via a Snapshot Builder.
    #
    # All read-only mutators below either:
    #   - return plain values (immutable), or
    #   - construct new arrays without mutating inputs.
    #
    # PI_TASK_001 §8 允许内部分析建立 raw / normalized 坐标两套; 当前阶段不
    # 实现 Normalize 引擎,这里只保留 raw。Preflight / Issue 信息保留 Z 信息,
    # 留 Normalize 阶段处理 (PI_TASK_001 §8).
    #
    class GeometrySnapshot
      attr_reader :edges, :config, :preflight

      def initialize(edges:, layers: [], preflight: {}, config: AnalysisConfig.new, vertex_index: nil)
        @edges    = edges.freeze
        @layers   = layers.freeze
        @preflight = preflight.dup
        @config   = config
        @vertex_index = vertex_index || build_vertex_index(config)
        edges.each { |e| @vertex_index.add_edge(e) }
      end

      def vertex_records
        @vertex_index.vertices
      end

      def open_vertices
        @vertex_index.open_vertices
      end

      def edge_count
        @edges.size
      end

      def vertex_count
        @vertex_index.vertex_count
      end

      def layer_distribution
        @edges.each_with_object(Hash.new(0)) { |e, h| h[e.layer] += 1 }
      end

      def z_range
        zs = @edges.flat_map { |e| [e.start_point[2], e.end_point[2]] }
        return [0.0, 0.0] if zs.empty?
        [zs.min, zs.max]
      end

      def non_zero_z_count
        tol = @config.tolerance.coordinate_epsilon
        @edges.flat_map { |e| [e.start_point[2], e.end_point[2]] }
              .count { |z| z.abs > tol }
      end

      def bounding_box
        points = @edges.flat_map(&:vertices)
        return nil if points.empty?
        xs = points.map { |p| p[0] }
        ys = points.map { |p| p[1] }
        zs = points.map { |p| p[2] }
        { min: [xs.min, ys.min, zs.min], max: [xs.max, ys.max, zs.max] }
      end

      private

      def build_vertex_index(config)
        VertexIndex.new(tolerance: config.tolerance.coordinate_epsilon)
      end
    end
  end
end
