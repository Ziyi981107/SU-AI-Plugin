
module SUAnalysis
  module Core
    module Analyzers
      #
      # ShortEdgeDetector — ISSUE 002 (PI_TASK_001 §9).
      #
      # Reports edges whose euclidean length < `tolerance.short_edge`.
      # The threshold itself lives in Tolerance (PI_TASK_001 §10 "不要散落
      # magic numbers"). Linear O(E) — no geometry transformation, so
      # length is cached in EdgeRecord.
      #
      class ShortEdgeDetector
        TYPE = 'short_edge'

        def detect(snapshot)
          threshold = snapshot.config.tolerance.short_edge
          snapshot.edges.each_with_object([]) do |edge, issues|
            next if edge.length >= threshold
            issues << {
              kind:              TYPE,
              severity:          'low',
              confidence:        'high',
              source_entity_ids: [edge.source.entity_id],
              edge_ids:          [edge.id],
              location:          midpoint(edge.start_point, edge.end_point),
              message:           "Short edge detected (length=#{format_length(edge.length)} < threshold=#{threshold}).",
              metadata:          {
                length:     edge.length,
                threshold:  threshold
              }
            }
          end
        end

        private

        def midpoint(p, q)
          [
            (p[0] + q[0]) / 2.0,
            (p[1] + q[1]) / 2.0,
            (p[2] + q[2]) / 2.0
          ]
        end

        def format_length(v)
          format('%.6f', v)
        end
      end
    end
  end
end
