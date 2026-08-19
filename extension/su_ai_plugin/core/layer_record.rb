
module SUAnalysis
  module Core
    #
    # LayerRecord — captures a SketchUp layer / tag and how many edges
    # reference it in the snapshot. Used by Preflight to produce
    # "Layer / Tag 分布" (PI_TASK_001 §6).
    #
    class LayerRecord
      attr_reader :name, :id, :edge_count

      def initialize(name:, id: nil, edge_count: 0)
        @name       = name.to_s
        @id         = id
        @edge_count = edge_count.to_i
      end

      def increment_edge_count!
        @edge_count += 1
      end

      def to_h
        { name: @name, id: @id, edge_count: @edge_count }
      end
    end
  end
end
