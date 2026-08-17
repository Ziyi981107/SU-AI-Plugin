
require_relative 'analysis_config'
require_relative 'geometry_snapshot'

module SUAnalysis
  module Core
    #
    # PreflightReport — structured result of a Preflight run.
    #
    # PI_TASK_001 §6: "建立 Preflight 层 ... 输出结构化结果供后续模块使用".
    # §6 also forbids "Preflight 不做修复", and §17 forbids auto-fix; this
    # class only collects facts and warnings, never modifies anything.
    #
    # Fields are split into:
    #   - pure-Ruby metrics: computed from GeometrySnapshot alone, fully
    #     unit-testable without SketchUp (this file).
    #   - SU-side facts: passed in via Snapshot#preflight hash by the
    #     SU adapter (extension/preflight_runner.rb). Stored verbatim so
    #     PreflightAnalyzer stays free of Sketchup:: API calls.
    #
    class PreflightReport
      # Pure-Ruby metrics (this file).
      attr_reader :edge_count, :vertex_count
      attr_reader :layer_distribution
      attr_reader :bounding_box, :z_range
      attr_reader :non_zero_z_count, :large_coordinate_count
      attr_reader :warnings

      # SU-side facts (stored verbatim from snapshot.preflight).
      attr_reader :sketchup_version, :selection_type
      attr_reader :group_count, :component_count
      attr_reader :deepest_nesting, :nested_containers

      def initialize(
        edge_count:,
        vertex_count:,
        layer_distribution:,
        bounding_box:,
        z_range:,
        non_zero_z_count:,
        large_coordinate_count:,
        warnings:,
        sketchup_version:,
        selection_type:,
        group_count:,
        component_count:,
        deepest_nesting:,
        nested_containers:
      )
        @edge_count              = edge_count
        @vertex_count            = vertex_count
        @layer_distribution      = layer_distribution
        @bounding_box            = bounding_box
        @z_range                 = z_range
        @non_zero_z_count        = non_zero_z_count
        @large_coordinate_count  = large_coordinate_count
        @warnings                = warnings.dup.freeze
        @sketchup_version        = sketchup_version
        @selection_type          = selection_type
        @group_count             = group_count
        @component_count         = component_count
        @deepest_nesting         = deepest_nesting
        @nested_containers       = nested_containers
      end

      def empty?
        @edge_count == 0
      end

      def warning_count
        @warnings.size
      end

      def to_h
        {
          edge_count:              @edge_count,
          vertex_count:            @vertex_count,
          layer_distribution:      @layer_distribution,
          bounding_box:            @bounding_box,
          z_range:                 @z_range,
          non_zero_z_count:        @non_zero_z_count,
          large_coordinate_count:  @large_coordinate_count,
          warning_count:           @warnings.size,
          warnings:                @warnings,
          sketchup_version:        @sketchup_version,
          selection_type:          @selection_type,
          group_count:             @group_count,
          component_count:         @component_count,
          deepest_nesting:         @deepest_nesting,
          nested_containers:       @nested_containers
        }
      end
    end

    #
    # PreflightAnalyzer — turns a GeometrySnapshot (+ an optional preflight
    # hash from the SU adapter) into a PreflightReport.
    #
    # Pure Ruby; no Sketchup:: references. SU-side facts are read out of
    # snapshot.preflight (a plain Hash) so this module stays testable and
    # SketchUp-importable code does not accidentally call into SU APIs.
    #
    # Warning categories emitted (PI_TASK_001 §6 + §8):
    #   - :non_zero_z_geometry    Z out of plane (above config.big_z)
    #   - :abnormal_large_coord   any axis magnitude > config.large_coordinate
    #   - :deep_nesting           deepest group/component depth above warning
    #
    module PreflightAnalyzer
      module_function

      def run(snapshot, config: nil)
        config ||= snapshot.config || AnalysisConfig.new
        edges   = snapshot.edges

        layer_dist = snapshot.layer_distribution
        bbox       = snapshot.bounding_box
        z_range    = snapshot.z_range

        # Preflight counter: any vertex Z strictly beyond config.big_z
        # is "off-plane". coordinate_epsilon is too tight for this purpose
        # (it's for point equality, not for "is Z meaningful here").
        big_z_thr = config.big_z
        non_zero_z = 0
        edges.each do |e|
          non_zero_z += 1 if e.start_point[2].abs > big_z_thr
          non_zero_z += 1 if e.end_point[2].abs   > big_z_thr
        end

        # Preflight counter: any axis component bigger than the warning
        # threshold is "abnormally large" (e.g. 1e6 inches ~= 15.7 miles).
        large_thr = config.large_coordinate
        large_coord_count = 0
        if bbox
          [:min, :max].each do |k|
            bbox[k].each { |c| large_coord_count += 1 if c.abs > large_thr }
          end
        end

        warnings = build_warnings(
          non_zero_z_count:   non_zero_z,
          large_coord_count:  large_coord_count,
          z_range:            z_range,
          bbox:               bbox,
          preflight_hash:     snapshot.preflight || {},
          config:             config
        )

        pre = snapshot.preflight || {}

        PreflightReport.new(
          edge_count:              edges.size,
          vertex_count:            snapshot.vertex_count,
          layer_distribution:      layer_dist,
          bounding_box:            bbox,
          z_range:                 z_range,
          non_zero_z_count:        non_zero_z,
          large_coordinate_count:  large_coord_count,
          warnings:                warnings,
          sketchup_version:        pre[:sketchup_version],
          selection_type:          pre[:selection_type],
          group_count:             pre[:group_count],
          component_count:         pre[:component_count],
          deepest_nesting:         pre[:deepest_nesting],
          nested_containers:       pre[:nested_containers] || []
        )
      end

      def build_warnings(non_zero_z_count:, large_coord_count:,
                         z_range:, bbox:, preflight_hash:, config:)
        warnings = []
        if non_zero_z_count > 0
          warnings << {
            code:    :non_zero_z_geometry,
            message: "#{non_zero_z_count} vertex(es) have |Z| > #{config.big_z} inches; " \
                     'geometry is not purely 2D.',
            severity: :info
          }
        end
        if large_coord_count > 0
          warnings << {
            code:    :abnormal_large_coord,
            message: "#{large_coord_count} bbox corner(s) exceed |coord| > " \
                     "#{config.large_coordinate} inches; check import scale.",
            severity: :warning
          }
        end
        deepest = preflight_hash[:deepest_nesting]
        limit   = config.deepest_nesting_warning
        if deepest && deepest.is_a?(Integer) && deepest > limit
          warnings << {
            code:    :deep_nesting,
            message: "Selection contains #{deepest} levels of nested groups/components " \
                     "(warning threshold: #{limit}).",
            severity: :warning
          }
        end
        warnings
      end
    end
  end
end
