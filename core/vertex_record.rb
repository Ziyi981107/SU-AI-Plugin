# frozen_string_literal: true

module SUAnalysis
  module Core
    #
    # VertexRecord — pure-Ruby representation of a vertex in the snapshot
    # graph. Note this is NOT a one-to-one copy of a SketchUp vertex; it is
    # the merged endpoint graph (PI_TASK_001 §7 "VertexRecord 至少拥有:
    # coordinate, connected edge ids").
    #
    # Edge ids are added incrementally by VertexIndex as edges arrive.
    #
    class VertexRecord
      attr_reader :coordinate, :id

      def initialize(coordinate:, edge_ids: [], id: nil)
        raise ArgumentError, 'coordinate must be 3-element array' unless coordinate.is_a?(Array) && coordinate.size == 3
        @coordinate = coordinate.map(&:to_f).freeze
        @edge_ids   = []
        edge_ids.each { |eid| add_edge(eid) }
        @id         = id
      end

      def edge_ids
        @edge_ids.dup
      end

      def add_edge(edge_id)
        return if @edge_ids.include?(edge_id)
        @edge_ids << edge_id
      end

      def degree
        @edge_ids.size
      end

      def to_h
        {
          id:        @id,
          coordinate: @coordinate,
          edge_ids:  edge_ids
        }
      end
    end
  end
end
