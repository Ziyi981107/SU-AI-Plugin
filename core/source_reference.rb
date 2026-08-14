# frozen_string_literal: true

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
# Stability:
#   - `persistent_id` is SketchUp 2018+. Older SketchUp returns nil here;
#     `stable?` flags it, and consumer code can fall back to entity_id.
#   - `entity_id` is Ruby `object_id`, NOT stable across reload. It is
#     useful only within a single SketchUp session.
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
