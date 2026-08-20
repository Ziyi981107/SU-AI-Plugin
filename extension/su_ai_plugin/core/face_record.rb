#
# core/face_record.rb — V1.3 Face Inventory: pure-Ruby read-only
# representation of a SketchUp face occurrence.
#
# Per V1.3 directive 027 (Prompt/CODEX_GUIDANCE_027_2026-08-20_...):
#   - A FaceRecord represents ONE face OCCURRENCE in the selection
#     tree (not one definition-face). Two ComponentInstances using
#     the same definition count as two distinct FaceRecords, matching
#     the existing Edge occurrence semantics.
#   - Fields (locked):
#     * deterministic analysis-local id
#     * SourceReference (occurrence identity compatible with
#       existing snapshot rules)
#     * layer name with the established Layer0 fallback
#     * outer-loop vertex count (Integer, non-negative)
#     * inner-loop count (Integer, non-negative)
#     * has_holes (Boolean, derived from inner_loop_count > 0)
#   - Immutable by design (no setters, freeze top-level).
#   - Mirrors EdgeRecord's contract shape so analyzers + UI can
#     treat the two symmetrically.
#
# NOT included (out of scope per directive 027):
#   - face area (correct area under nested non-uniform transforms
#     is deferred)
#   - normal vectors, UVs, materials, smoothing
#   - per-face Locate actions
#

require_relative 'source_reference'

module SUAnalysis
  module Core
    class FaceRecord
      attr_reader :id, :source, :layer,
                  :outer_loop_vertex_count, :inner_loop_count, :has_holes,
                  :metadata

      def initialize(id:, source:, layer:,
                     outer_loop_vertex_count:,
                     inner_loop_count: 0,
                     metadata: {})
        # Validation: source must be a SourceReference (mirrors
        # EdgeRecord's contract).
        raise ArgumentError, 'source must be a SourceReference' unless source.is_a?(SourceReference)
        raise ArgumentError, 'outer_loop_vertex_count must be a non-negative Integer' \
              unless outer_loop_vertex_count.is_a?(Integer) && outer_loop_vertex_count >= 0
        raise ArgumentError, 'inner_loop_count must be a non-negative Integer' \
              unless inner_loop_count.is_a?(Integer) && inner_loop_count >= 0
        @id                    = id
        @source                = source
        @layer                 = layer.to_s
        @outer_loop_vertex_count = outer_loop_vertex_count
        @inner_loop_count      = inner_loop_count
        # Derived field per directive: has_holes == (inner_loop_count > 0).
        # Always computed from inner_loop_count to keep the data model
        # canonical; callers MUST NOT pass has_holes directly.
        @has_holes             = inner_loop_count > 0
        @metadata              = metadata || {}
      end

      def to_h
        {
          id:                       @id,
          source:                   @source.to_h,
          layer:                    @layer,
          outer_loop_vertex_count:  @outer_loop_vertex_count,
          inner_loop_count:         @inner_loop_count,
          has_holes:                @has_holes
        }
      end

      # V1.4 (per directive 030): value-based equality. The
      # rebuild contract requires two FaceRecord instances with
      # the same data to be ==, so the SourceSnapshot can be
      # compared across rebuilds (rebuilds produce new instances).
      def ==(other)
        return false unless other.is_a?(FaceRecord)
        id == other.id &&
          source == other.source &&
          layer == other.layer &&
          outer_loop_vertex_count == other.outer_loop_vertex_count &&
          inner_loop_count == other.inner_loop_count
        # has_holes is derived from inner_loop_count, so we
        # don't include it separately (== on inner_loop_count
        # is sufficient).
      end

      def eql?(other)
        self == other
      end

      def hash
        [id, source, layer, outer_loop_vertex_count, inner_loop_count].hash
      end
    end
  end
end