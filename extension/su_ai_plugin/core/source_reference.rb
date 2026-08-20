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
#   - `persistent_id_path` is the canonical machine-resolvable identity.
#     It is an Array<Integer> of container PIDs from model root to the leaf,
#     with the leaf PID last. Empty array for root-level entities.
#
# Structural identity (per CodeX Review 013, 2026-08-18):
#   - `structural_depth` is the structural depth of this entity (root
#     container = 0; +1 per nested container; +1 per active edit context
#     entity). Populated in `extension/preflight_runner.rb` alongside
#     `pid_path_complete`. The two are independent facts: structural
#     depth is the entity count; pid_path_complete is whether every
#     container pid was captured.
#   - `pid_path_complete` is true iff every structural ancestor AND the
#     leaf entity itself supplied a non-nil persistent_id.
#   - Defaults are FAIL-CLOSED: `structural_depth: 0` and
#     `pid_path_complete: false`. Production callers MUST pass both
#     explicitly. Legacy test callers that omit these fields get an
#     explicit "incomplete" marker, which is the correct behavior for
#     synthetic edges with no PID path.
#

module SUAnalysis
  module Core
    class SourceReference
      attr_reader :entity_id, :persistent_id, :kind, :label,
                  :persistent_id_path, :instance_path,
                  :structural_depth, :pid_path_complete,
                  :layer_name

      def initialize(entity_id: nil, persistent_id: nil, kind: 'edge', label: nil,
                     instance_path: nil, persistent_id_path: nil,
                     structural_depth: 0, pid_path_complete: false,
                     layer_name: nil)
        # entity_id is optional (nil allowed for fully-missing SourceReferences
        # in test fixtures). In production, callers should always supply it.
        @entity_id     = entity_id.nil? ? nil : Integer(entity_id)
        @persistent_id = persistent_id
        @kind          = kind
        @label         = label
        @persistent_id_path = if persistent_id_path.nil?
                                 [].freeze
                               else
                                 persistent_id_path.map { |p| p.nil? ? nil : Integer(p) }.compact.freeze
                               end
        @instance_path = if instance_path.nil?
                           [].freeze
                         else
                           instance_path.dup.freeze
                         end
        @structural_depth    = structural_depth.to_i
        @pid_path_complete   = pid_path_complete ? true : false
        # V1.1 (per plan §12 default + R007): layer_name is captured
        # at snapshot time. The LayerIssueGrouper reads this directly
        # from the SourceReference it wraps, without re-looking-up
        # the layer from the entity. V1.0 callers do not supply
        # this; default is nil, which the grouper maps to "Layer0"
        # via the V1.0 fallback.
        @layer_name = layer_name.nil? ? nil : layer_name.to_s
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
          persistent_id_path: @persistent_id_path,
          structural_depth:    @structural_depth,
          pid_path_complete:   @pid_path_complete,
          layer_name:         @layer_name
        }
      end

      # V1.4 (per directive 030): value-based equality. The
      # rebuild contract requires two SourceReference instances
      # with the same data to be ==, so the SourceSnapshot can
      # be compared across rebuilds (rebuilds produce new
      # instances). All fields participate; layer_name is
      # included even when nil so two refs from the same source
      # entity on the same layer compare equal.
      def ==(other)
        return false unless other.is_a?(SourceReference)
        entity_id == other.entity_id &&
          persistent_id == other.persistent_id &&
          kind == other.kind &&
          label == other.label &&
          instance_path == other.instance_path &&
          persistent_id_path == other.persistent_id_path &&
          structural_depth == other.structural_depth &&
          pid_path_complete == other.pid_path_complete &&
          layer_name == other.layer_name
      end

      def eql?(other)
        self == other
      end

      def hash
        [entity_id, persistent_id, kind, label, instance_path,
         persistent_id_path, structural_depth, pid_path_complete,
         layer_name].hash
      end
    end
  end
end
