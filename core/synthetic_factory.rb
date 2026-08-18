
require_relative 'source_reference'
require_relative 'edge_record'
require_relative 'analysis_config'
require_relative 'geometry_snapshot'

module SUAnalysis
  module Core
    #
    # SyntheticFactory — build GeometrySnapshot fixtures with zero
    # SketchUp dependency. Used by the Synthetic Test Set (PI_TASK_001 §16
    # Test 01..10). Lives in `core/` (not `tests/`) so that any future
    # fuzz / golden-case harness can reuse it.
    #
    module SyntheticFactory
      module_function

      def edge(id, start_point, end_point, layer: 'Layer0', source: nil)
        # Synthetic edges have no PID path. Mark them as
        # pid_path_complete=false so the IssueEnricher treats them
        # as incomplete (matches the fail-closed default in
        # SourceReference). Tests that need a complete-path token
        # can pass an explicit `source` with pid_path_complete=true.
        src = source || SourceReference.new(
          entity_id: id,
          kind: 'edge',
          label: "synthetic-edge-#{id}",
          structural_depth: 0,
          pid_path_complete: false
        )
        EdgeRecord.new(
          id:          id,
          source:      src,
          start_point: start_point,
          end_point:   end_point,
          layer:       layer
        )
      end

      def horizontal_edge(id, x1, x2, y, z: 0.0, layer: 'Layer0')
        edge(id, [x1.to_f, y.to_f, z.to_f], [x2.to_f, y.to_f, z.to_f], layer: layer)
      end

      # Builds a closed XY-axis-aligned rectangle (Z=0 by default).
      def rectangle(start_xy, width, height, layer: 'Layer0', z: 0.0)
        x, y = start_xy
        [
          edge(0, [x,           y,           z], [x + width, y,           z], layer: layer),
          edge(1, [x + width,   y,           z], [x + width, y + height,  z], layer: layer),
          edge(2, [x + width,   y + height,  z], [x,         y + height,  z], layer: layer),
          edge(3, [x,           y + height,  z], [x,         y,           z], layer: layer)
        ]
      end

      def snapshot(edges, config: AnalysisConfig.new)
        GeometrySnapshot.new(edges: edges, config: config)
      end
    end
  end
end
