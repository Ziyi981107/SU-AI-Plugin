# frozen_string_literal: true

#
# Tolerance — single source of truth for all geometric tolerances.
#
# SketchUp internal unit is INCH. Every tolerance field is in inches unless
# the field name suggests otherwise (it never does).
#
# Two tolerance systems coexist by design:
#   - tiny epsilon values (duplicate_tolerance, coordinate_epsilon)
#   - engineering values (short_edge_threshold, gap_search_tolerance)
#
# These are deliberately separated per PI_TASK_001 §10 "Tolerance System".
#
# No magic numbers live outside this class.
#

module SUAnalysis
  module Core
    class Tolerance
      attr_reader :duplicate, :short_edge, :gap_search, :coordinate_epsilon

      def initialize(duplicate:, short_edge:, gap_search:, coordinate_epsilon:)
        @duplicate         = duplicate.to_f
        @short_edge        = short_edge.to_f
        @gap_search        = gap_search.to_f
        @coordinate_epsilon = coordinate_epsilon.to_f
        validate!
      end

      # Conservative defaults (PI_TASK_001 §10: "具体默认值可先选择保守值").
      # All in inches.
      def self.default
        new(
          duplicate:          1.0e-4,
          short_edge:         0.5,
          gap_search:         0.1,
          coordinate_epsilon: 1.0e-6
        )
      end

      def to_h
        {
          duplicate:          duplicate,
          short_edge:         short_edge,
          gap_search:         gap_search,
          coordinate_epsilon: coordinate_epsilon
        }
      end

      private

      def validate!
        { duplicate: @duplicate, short_edge: @short_edge,
          gap_search: @gap_search, coordinate_epsilon: @coordinate_epsilon }.each do |k, v|
          raise ArgumentError, "Tolerance[#{k}] must be > 0, got #{v}" unless v > 0
        end
      end
    end
  end
end
