
require_relative 'analysis_config'
require_relative 'geometry_snapshot'
require_relative 'tolerance'

module SUAnalysis
  module Core
    #
    # PreflightReport — structured result of a Preflight run.
    #
    # PI_TASK_001 §6: "建立 Preflight 层 ... 输出结构化结果供后续模块使用".
    # §6 also forbids "Preflight 不做修复", and §17 forbids auto-fix; this
    # class only collects facts and warnings, never modifies anything.
    #
    # Field semantics (per Codex Review 004, 2026-08-17):
    #   - non_zero_z_vertex_count: distinct vertex count with |Z| above
    #       Tolerance#coordinate_epsilon (NOT big_z).
    #   - non_zero_z_edge_count: edge count where BOTH endpoints have
    #       |Z| above coordinate_epsilon.
    #   - large_coordinate_extrema_count: number of bbox axis extrema
    #       (not edges / vertices) above Tolerance#large_coordinate.
    #       Renamed from large_coordinate_count to be explicit.
    #   - significant_z_extrema_count: distinct vertex count with |Z|
    #       above Tolerance#big_z. Drives the :significant_non_zero_z
    #       warning (severity :medium).
    #   - selection_type: one of 'empty' / 'Group' / 'ComponentInstance'
    #       / 'Edges' / 'mixed'. 'mixed' means the selection contains
    #       more than one kind of root entity.
    #   - deepest_nesting: container depth where the root selected
    #       container is level 1. Pure-Eddge selection = 0.
    #   - group_count / component_count: counts of Group / ComponentInstance
    #       occurrences reachable from the selection (recursive, including
    #       within-component entities).
    #
    # Severity values (per R005, 2026-08-17): :low / :medium / :high ONLY.
    # No :info / :warning in the canonical Issue model. UI maps:
    #   :low    = neutral
    #   :medium = orange
    #   :high   = red
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
      attr_reader :non_zero_z_vertex_count, :non_zero_z_edge_count
      attr_reader :significant_z_extrema_count
      attr_reader :large_coordinate_extrema_count
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
        non_zero_z_vertex_count:,
        non_zero_z_edge_count:,
        significant_z_extrema_count:,
        large_coordinate_extrema_count:,
        warnings:,
        sketchup_version:,
        selection_type:,
        group_count:,
        component_count:,
        deepest_nesting:,
        nested_containers:
      )
        @edge_count                       = edge_count
        @vertex_count                     = vertex_count
        @layer_distribution               = layer_distribution
        @bounding_box                     = bounding_box
        @z_range                          = z_range
        @non_zero_z_vertex_count          = non_zero_z_vertex_count
        @non_zero_z_edge_count            = non_zero_z_edge_count
        @significant_z_extrema_count      = significant_z_extrema_count
        @large_coordinate_extrema_count   = large_coordinate_extrema_count
        @warnings                         = warnings.dup.freeze
        @sketchup_version                 = sketchup_version
        @selection_type                   = selection_type
        @group_count                      = group_count
        @component_count                  = component_count
        @deepest_nesting                  = deepest_nesting
        @nested_containers                = nested_containers
      end

      def empty?
        @edge_count == 0
      end

      def warning_count
        @warnings.size
      end

      def to_h
        {
          edge_count:                       @edge_count,
          vertex_count:                     @vertex_count,
          layer_distribution:               @layer_distribution,
          bounding_box:                     @bounding_box,
          z_range:                          @z_range,
          non_zero_z_vertex_count:          @non_zero_z_vertex_count,
          non_zero_z_edge_count:            @non_zero_z_edge_count,
          significant_z_extrema_count:      @significant_z_extrema_count,
          large_coordinate_extrema_count:   @large_coordinate_extrema_count,
          warning_count:                    @warnings.size,
          warnings:                         @warnings,
          sketchup_version:                 @sketchup_version,
          selection_type:                   @selection_type,
          group_count:                      @group_count,
          component_count:                  @component_count,
          deepest_nesting:                  @deepest_nesting,
          nested_containers:                @nested_containers
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
    # Warning categories emitted (PI_TASK_001 §6 + §8 + R001 + R005):
    #   - :significant_non_zero_z   (severity :medium)
    #       distinct vertex |Z| > config.tolerance.big_z
    #   - :abnormal_large_coord     (severity :high)
    #       bbox axis extrema > config.tolerance.large_coordinate
    #   - :deep_nesting             (severity :low)
    #       deepest_nesting >= config.deepest_nesting_warning
    #       (root selected container = level 1; warn at >= threshold)
    #
    module PreflightAnalyzer
      module_function

      def run(snapshot, config: nil)
        config ||= snapshot.config || AnalysisConfig.new
        edges   = snapshot.edges

        layer_dist = snapshot.layer_distribution
        bbox       = snapshot.bounding_box
        z_range    = snapshot.z_range

        # Non-zero-Z awareness (PI_TASK_001 §6 + R001 + S2-BLOCK-004 round 2):
        #   - non_zero_z_* counts use coordinate_epsilon (tight, point-
        #     equality tolerance), NOT big_z. Big_z is a separate
        #     "significant off-plane" warning threshold.
        #   - Vertex dedup REQUIRED: shared endpoint counted ONCE as a
        #     vertex. Dedup uses O(V) spatial hash (no result.any? scan).
        #   - Edge count uses OR semantics: an Edge with one off-plane
        #     endpoint and one on-plane endpoint IS a non-zero-Z Edge.
        coord_eps = config.tolerance.coordinate_epsilon
        big_z_thr = config.big_z

        distinct_z_vertices = collect_distinct_vertices(edges, coord_eps: coord_eps)
        non_zero_z_vertex_count = distinct_z_vertices.count do |v|
          v[2].abs > coord_eps
        end
        non_zero_z_edge_count = edges.count do |e|
          e.start_point[2].abs > coord_eps || e.end_point[2].abs > coord_eps
        end
        significant_z_extrema_count = distinct_z_vertices.count do |v|
          v[2].abs > big_z_thr
        end

        # Bbox axis extrema count (was 'large_coordinate_count'). Renamed
        # per Codex NIT to be explicit about what is counted.
        large_thr = config.large_coordinate
        large_coord_extrema_count = 0
        if bbox
          [:min, :max].each do |k|
            bbox[k].each { |c| large_coord_extrema_count += 1 if c.abs > large_thr }
          end
        end

        warnings = build_warnings(
          non_zero_z_vertex_count:    non_zero_z_vertex_count,
          significant_z_extrema_count: significant_z_extrema_count,
          large_coord_extrema_count:  large_coord_extrema_count,
          z_range:                    z_range,
          bbox:                       bbox,
          preflight_hash:             snapshot.preflight || {},
          config:                     config
        )

        pre = snapshot.preflight || {}

        PreflightReport.new(
          edge_count:                       edges.size,
          vertex_count:                     snapshot.vertex_count,
          layer_distribution:               layer_dist,
          bounding_box:                     bbox,
          z_range:                          z_range,
          non_zero_z_vertex_count:          non_zero_z_vertex_count,
          non_zero_z_edge_count:            non_zero_z_edge_count,
          significant_z_extrema_count:      significant_z_extrema_count,
          large_coordinate_extrema_count:   large_coord_extrema_count,
          warnings:                         warnings,
          sketchup_version:                 pre[:sketchup_version],
          selection_type:                   pre[:selection_type],
          group_count:                      pre[:group_count],
          component_count:                  pre[:component_count],
          deepest_nesting:                  pre[:deepest_nesting],
          nested_containers:                pre[:nested_containers] || []
        )
      end

      # Collect distinct vertices from edges, deduped in coord-epsilon
      # neighborhood. Uses an O(V) spatial hash (per S2-BLOCK-004 round
      # 2 — replaces previous O(V^2) `result.any?` scan).
      #
      # Per S2-BLOCK-004 round 3 (Codex Review 007): searches current
      # bucket AND all 26 adjacent buckets. Two points within coord_eps
      # but on opposite sides of a bucket boundary are still merged.
      # Returns Array<[x, y, z]>.
      def collect_distinct_vertices(edges, coord_eps: 1.0e-6)
        bucket_size = coord_eps
        buckets = {}
        result  = []

        edges.each do |e|
          [e.start_point, e.end_point].each do |v|
            key = bucket_key(v, bucket_size)
            merged = false
            # Search the 27 buckets in a 3x3x3 neighborhood (current + 26 adjacent).
            (-1..1).each do |dx|
              (-1..1).each do |dy|
                (-1..1).each do |dz|
                  neighbor_key = [key[0] + dx, key[1] + dy, key[2] + dz]
                  seen = buckets[neighbor_key]
                  next if seen.nil?
                  seen.each do |existing|
                    if points_equal?(existing, v, coord_eps)
                      merged = true
                      break
                    end
                  end
                  break if merged
                end
                break if merged
              end
              break if merged
            end
            unless merged
              buckets[key] = (buckets[key] || []) << v
              result << v
            end
          end
        end
        result
      end

      def bucket_key(point, size)
        [
          (point[0] / size).floor,
          (point[1] / size).floor,
          (point[2] / size).floor
        ]
      end

      def points_equal?(a, b, eps)
        (a[0] - b[0]).abs <= eps &&
          (a[1] - b[1]).abs <= eps &&
          (a[2] - b[2]).abs <= eps
      end

      def build_warnings(non_zero_z_vertex_count:, significant_z_extrema_count:,
                         large_coord_extrema_count:, z_range:, bbox:,
                         preflight_hash:, config:)
        warnings = []

        # Significant off-plane (R001: big_z ONLY here, NOT for non-zero
        # counts; severity :medium per R005).
        if significant_z_extrema_count > 0
          warnings << {
            code:     :significant_non_zero_z,
            message:  "#{significant_z_extrema_count} distinct vertex(es) have |Z| > " \
                      "#{config.big_z} inches; geometry is significantly off-plane.",
            severity: :medium
          }
        end

        # Abnormal large coordinate (R005: severity :high).
        if large_coord_extrema_count > 0
          warnings << {
            code:     :abnormal_large_coord,
            message:  "#{large_coord_extrema_count} bbox corner(s) exceed |coord| > " \
                      "#{config.large_coordinate} inches; check import scale.",
            severity: :high
          }
        end

        # Deep nesting (R001: root container = level 1; warn at >= threshold;
        # R005: severity :low).
        deepest = preflight_hash[:deepest_nesting]
        limit   = config.deepest_nesting_warning
        if deepest && deepest.is_a?(Integer) && deepest >= limit
          warnings << {
            code:     :deep_nesting,
            message:  "Selection contains #{deepest} levels of nested groups/components " \
                      "(warning threshold: #{limit}).",
            severity: :low
          }
        end

        warnings
      end
    end
  end
end
