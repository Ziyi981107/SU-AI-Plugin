
module SUAnalysis
  module Core
    #
    # QuantizeKey — turns a 3D point into discrete (i, j, k) bucket
    # coordinates for fast spatial lookup. Used by analyzers and
    # VertexIndex to avoid O(n^2) comparisons on real CAD (PI_TASK_001 §15
    # 性能原则).
    #
    # cell_size policy:
    #   - We pick cell_size >= the relevant tolerance so any point within
    #     `radius` of an anchor is at most one bucket away.
    #   - VertexIndex auto-selects cell_size = max(tolerance, 1.0 inch).
    #
    module QuantizeKey
      module_function

      def bucket_for(point, cell_size)
        x, y, z = point
        [
          (x / cell_size).floor,
          (y / cell_size).floor,
          (z / cell_size).floor
        ]
      end

      def cells_within_radius(point, radius, cell_size)
        cx, cy, cz = bucket_for(point, cell_size)
        reach = ((radius / cell_size).ceil + 1).to_i
        ((-reach)..reach).each_with_object([]) do |dx, acc|
          ((-reach)..reach).each do |dy|
            ((-reach)..reach).each do |dz|
              acc << [cx + dx, cy + dy, cz + dz]
            end
          end
        end
      end
    end
  end
end
