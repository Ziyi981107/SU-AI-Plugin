
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
# Instance identity (per Codex S2-BLOCK-002, 2026-08-17):
#   - Two ComponentInstances sharing one definition are two distinct
#     occurrences. Each Edge inside those instances therefore needs a
#     composite source identity that includes the instance path.
#   - `instance_path` is a list of String entries describing the container
#     chain from the model root to this entity, e.g.
#       ["Group:outer", "ComponentInstance:Window#1", "Group:inner_frame"]
#     - Each entry is "Kind:Name"; Name is the definition's name (or the
#       object_id hex for anonymous / unnamed containers).
#     - The list is empty for entities directly selected in the model
#       root (i.e. no enclosing group / component).
#   - This is stored alongside persistent_id and entity_id; SourceReference
#     is purely data, so all three fields survive serialization.
#

module SUAnalysis
  module Core
    class SourceReference
      attr_reader :entity_id, :persistent_id, :kind, :label,
                  :persistent_id_path, :instance_path

      def initialize(entity_id:, persistent_id: nil, kind: 'edge', label: nil,
                     instance_path: nil, persistent_id_path: nil)
        @entity_id     = entity_id
        @persistent_id = persistent_id
        @kind          = kind
        @label         = label
        # Per Codex Review 005 S2-BLOCK-002: persistent_id_path is the
        # canonical machine-resolvable identity. It is an Array<Integer>
        # of container PIDs from model root to the leaf, with the leaf
        # PID last. Empty array for root-level entities.
        # instance_path remains as a display label (legacy / human-readable).
        @persistent_id_path = if persistent_id_path.nil?
                                 [].freeze
                               else
                                 persistent_id_path.dup.freeze
                               end
        # instance_path is now derived from labels (not PIDs). Default empty.
        @instance_path = if instance_path.nil?
                           [].freeze
                         else
                           instance_path.dup.freeze
                         end
      end

      def stable?
        !@persistent_id.nil?
      end

      # Returns the PID path joined by '/' for display / debugging.
      # Empty string for root-level entities.
      def persistent_id_path_string
        @persistent_id_path.map(&:to_s).join('/')
      end

      # Returns the instance_path joined by ' > ' for display purposes only.
      # Empty string for root-level entities. NOT used as canonical identity.
      def instance_path_string
        @instance_path.join(' > ')
      end

      def to_h
        {
          entity_id:          @entity_id,
          persistent_id:      @persistent_id,
          kind:               @kind,
          label:              @label,
          instance_path:      @instance_path,
          persistent_id_path: @persistent_id_path
        }
      end
    end
  end
end
