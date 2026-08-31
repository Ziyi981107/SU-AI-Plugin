
#
# Tolerance — single source of truth for all geometric tolerances.
#
# SketchUp internal unit is INCH. Every tolerance field is in inches unless
# the field name suggests otherwise (it never does).
#
# Two tolerance systems coexist by design:
#   - tiny epsilon values (duplicate_tolerance, coordinate_epsilon)
#   - engineering values (short_edge_threshold, gap_search_tolerance)
#   - preflight warning thresholds (big_z, large_coordinate)
#
# These are deliberately separated per PI_TASK_001 §10 "Tolerance System".
# Preflight thresholds are kept here too: they are still "thresholds the
# analyzers need" (just for *flagging* rather than *equality*), and central
# placement avoids magic numbers leaking into Stage 2 Preflight code.
#
# No magic numbers live outside this class.
#

module SUAnalysis
  module Core
    class Tolerance
      # V1.6 Planar Normalization / Z Policy (per frozen V1.6
      # Blueprint §4.1): planar_z_snap is a Stage-specific
      # tolerance governing the dominant Z-band window during
      # planar normalization analysis. It is NOT a preflight
      # warning threshold (big_z remains that role) and it is
      # NOT a near-zero equality epsilon (coordinate_epsilon
      # remains that role). See PLANAR_Z_SNAP_DEFAULT below.
      attr_reader :duplicate, :short_edge, :gap_search, :coordinate_epsilon,
                  :big_z, :large_coordinate,
                  :planar_z_snap

      def initialize(duplicate:, short_edge:, gap_search:, coordinate_epsilon:,
                     big_z: 0.01, large_coordinate: 1.0e6,
                     planar_z_snap: PLANAR_Z_SNAP_DEFAULT)
        @duplicate         = duplicate.to_f
        @short_edge        = short_edge.to_f
        @gap_search        = gap_search.to_f
        @coordinate_epsilon = coordinate_epsilon.to_f
        # Preflight warning thresholds (PI_TASK_001 §6 + §8):
        #   big_z: any vertex with |z| > big_z is recorded as off-plane info
        #   large_coordinate: any |x|, |y|, |z| > large_coordinate is flagged
        @big_z             = big_z.to_f
        @large_coordinate  = large_coordinate.to_f
        # V1.6 Planar Normalization / Z Policy tolerance.
        # Default 0.01 inch (frozen Blueprint §4.1: "matches
        # the current order of magnitude already used by
        # `big_z`... remains explicit rather than reusing a
        # warning threshold as repair authority").
        @planar_z_snap     = planar_z_snap.to_f
        validate!
      end

      # Conservative defaults (PI_TASK_001 §10: "具体默认值可先选择保守值").
      # All in inches.
      def self.default
        new(
          duplicate:          1.0e-4,
          short_edge:         0.5,
          gap_search:         0.1,
          coordinate_epsilon: 1.0e-6,
          big_z:              0.01,
          large_coordinate:   1.0e6,
          planar_z_snap:      PLANAR_Z_SNAP_DEFAULT
        )
      end

      # V1.6 Blueprint §4.1 frozen default.
      # Single source of truth for the default Planar Normalization
      # Z-snap tolerance; matches `big_z`'s order of magnitude but
      # is a SEPARATE semantic role (repair authority, not warning).
      PLANAR_Z_SNAP_DEFAULT = 0.01

      # Per-field default constants. Exposed so the
      # WorkingModeRunner can rebuild a Tolerance from a
      # captured snapshot's tolerance_values Hash WITHOUT
      # silently dropping fields (and so external callers can
      # inspect the canonical default of any field).
      DEFAULT_DUPLICATE          = 1.0e-4
      DEFAULT_SHORT_EDGE         = 0.5
      DEFAULT_GAP_SEARCH         = 0.1
      DEFAULT_COORDINATE_EPSILON = 1.0e-6
      DEFAULT_BIG_Z              = 0.01
      DEFAULT_LARGE_COORDINATE   = 1.0e6

      def to_h
        {
          duplicate:          duplicate,
          short_edge:         short_edge,
          gap_search:         gap_search,
          coordinate_epsilon: coordinate_epsilon,
          big_z:              big_z,
          large_coordinate:   large_coordinate,
          planar_z_snap:      planar_z_snap
        }
      end

      private

      def validate!
        { duplicate: @duplicate, short_edge: @short_edge,
          gap_search: @gap_search, coordinate_epsilon: @coordinate_epsilon,
          big_z: @big_z, large_coordinate: @large_coordinate,
          planar_z_snap: @planar_z_snap }.each do |k, v|
          raise ArgumentError, "Tolerance[#{k}] must be > 0, got #{v}" unless v > 0
        end
      end
    end
  end
end
