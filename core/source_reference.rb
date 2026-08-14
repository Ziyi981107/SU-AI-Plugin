
#
# SourceReference — lightweight token that ties an analysis record back to
# its SketchUp entity without holding a hard Ruby reference.
#
# Why not just hold the entity object?
#   - SU entities can be erased at any time; holding a reference can crash
#     when garbage collection touches them.
#   - We need to ship values over JSON / to the UI / to the registry; an
#     entity object can't be marshalled.
#
# Stability (PI_TASK_001 + Codex Q003 answer, 2026-08-14):
#   - `persistent_id` is available in SketchUp 2017+ for Edge, Vertex,
#     Group, ComponentInstance, and most entity types (NOT a SU2018+
#     feature, contrary to an earlier hypothesis).
#   - Some entities / modes return nil even on supported SketchUp versions,
#     so consumers MUST use capability detection (`respond_to?(:persistent_id)
#     && entity.persistent_id`) rather than version number branches.
#   - `stable?` returns true only when a non-nil persistent_id was obtained.
#   - `entity_id` is Ruby `object_id`, NOT stable across reload or session;
#     it is useful only as a transient in-memory key.
#

module SUAnalysis
  module Core
    class SourceReference
      attr_reader :entity_id, :persistent_id, :kind, :label

      def initialize(entity_id:, persistent_id: nil, kind: 'edge', label: nil)
        @entity_id     = entity_id
        @persistent_id = persistent_id
        @kind          = kind
        @label         = label
      end

      def stable?
        !@persistent_id.nil?
      end

      def to_h
        {
          entity_id:     @entity_id,
          persistent_id: @persistent_id,
          kind:          @kind,
          label:         @label
        }
      end
    end
  end
end
