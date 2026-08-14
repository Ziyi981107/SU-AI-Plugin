
require_relative 'source_reference'

module SUAnalysis
  module Core
    #
    # EdgeRecord — pure-Ruby read-only representation of a SketchUp edge.
    #
    # Coordinates are arrays [x, y, z] in SU internal inches.
    # Length is computed once at construction; never recomputed.
    #
    class EdgeRecord
      attr_reader :id, :source, :start_point, :end_point, :layer, :length, :metadata

      def initialize(id:, source:, start_point:, end_point:, layer:, length: nil, metadata: {})
        raise ArgumentError, 'source must be a SourceReference' unless source.is_a?(SourceReference)
        raise ArgumentError, 'start_point must be 3-element array' unless start_point.is_a?(Array) && start_point.size == 3
        raise ArgumentError, 'end_point must be 3-element array'   unless end_point.is_a?(Array)   && end_point.size == 3
        @id           = id
        @source       = source
        @start_point  = start_point.map(&:to_f)
        @end_point    = end_point.map(&:to_f)
        @layer        = layer
        @length       = (length || euclidean_length(@start_point, @end_point)).to_f
        @metadata     = metadata || {}
      end

      def vertices
        [@start_point, @end_point]
      end

      def to_h
        {
          id:           @id,
          source:       @source.to_h,
          start_point:  @start_point,
          end_point:    @end_point,
          length:       @length,
          layer:        @layer,
          metadata:     @metadata
        }
      end

      private

      def euclidean_length(a, b)
        dx = a[0] - b[0]
        dy = a[1] - b[1]
        dz = a[2] - b[2]
        Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
      end
    end
  end
end
