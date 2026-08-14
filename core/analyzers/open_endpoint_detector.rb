# frozen_string_literal: true

module SUAnalysis
  module Core
    module Analyzers
      #
      # OpenEndpointDetector — ISSUE 003a (PI_TASK_001 §9).
      #
      # Identifies vertices in the merged VertexIndex that are touched by
      # exactly one edge (a "dangling" or open endpoint). The
      # actual "closed loop" rule lives in GeometrySnapshot#open_vertices.
      #
      # Used by GapCandidateDetector downstream as the candidate pool.
      #
      class OpenEndpointDetector
        TYPE = 'open_endpoint'

        def detect(snapshot)
          edges_by_id = {}
          snapshot.edges.each { |e| edges_by_id[e.id] = e }

          issues = []
          snapshot.vertex_records.each do |vertex|
            next unless vertex.degree == 1
            edge = edges_by_id[vertex.edge_ids.first]
            next unless edge
            issues << {
              kind:              TYPE,
              severity:          'low',
              confidence:        'high',
              source_entity_ids: [edge.source.entity_id],
              edge_ids:          [edge.id],
              location:          vertex.coordinate,
              message:           'Open endpoint: vertex is shared by exactly one edge.',
              metadata:          { vertex_id: vertex.id }
            }
          end
          issues
        end
      end
    end
  end
end
