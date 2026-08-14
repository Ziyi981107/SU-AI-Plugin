# frozen_string_literal: true

require_relative 'vertex_record'
require_relative 'quantize_key'

module SUAnalysis
  module Core
    #
    # VertexIndex — groups edges that share an endpoint.
    #
    # Input:  `tolerance` controls how close two endpoints must be to be
    #         treated as "the same vertex" (typically coordinate_epsilon).
    # Output: a flat list of merged VertexRecords; each carries the list
    #         of edge ids that touch it.
    #
    # Complexity:
    #   - Each `add_edge` performs ~constant work (search 27 neighbour
    #     cells around the new point).
    #   - Total cost is O(E) amortized for the whole snapshot.
    #
    # Open-endpoint rule (PI_TASK_001 §9 ISSUE 003a):
    #   open_vertices = those with edge_ids.size == 1.
    #
    class VertexIndex
      attr_reader :tolerance, :cell_size

      def initialize(tolerance:, cell_size: nil)
        raise ArgumentError, 'tolerance must be > 0' unless tolerance > 0
        @tolerance = tolerance.to_f
        @cell_size = (cell_size || [tolerance, 1.0].max).to_f
        @buckets  = Hash.new { |h, k| h[k] = [] }
        @vertices = []
      end

      def add_edge(edge)
        add_endpoint(edge.id, edge.start_point)
        add_endpoint(edge.id, edge.end_point)
      end

      def vertices
        @vertices.dup
      end

      def open_vertices
        @vertices.select { |v| v.degree == 1 }
      end

      def vertex_count
        @vertices.size
      end

      private

      def add_endpoint(edge_id, point)
        vertex = find_or_create(point)
        vertex.add_edge(edge_id)
      end

      def find_or_create(point)
        candidate = search_nearby(point).find { |v| same_point?(v.coordinate, point) }
        return candidate if candidate

        new_id = @vertices.size
        v = VertexRecord.new(coordinate: point, id: new_id)
        @vertices << v
        key = QuantizeKey.bucket_for(point, @cell_size)
        @buckets[key] << v
        v
      end

      def search_nearby(point)
        reach = ((@tolerance / @cell_size).ceil + 1).to_i
        cx, cy, cz = QuantizeKey.bucket_for(point, @cell_size)
        result = []
        (-reach..reach).each do |dx|
          (-reach..reach).each do |dy|
            (-reach..reach).each do |dz|
              key = [cx + dx, cy + dy, cz + dz]
              @buckets[key].each { |v| result << v unless result.include?(v) }
            end
          end
        end
        result
      end

      def same_point?(a, b)
        (a[0] - b[0]).abs < @tolerance &&
          (a[1] - b[1]).abs < @tolerance &&
          (a[2] - b[2]).abs < @tolerance
      end
    end
  end
end
