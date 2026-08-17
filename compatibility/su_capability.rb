
#
# compatibility/su_capability.rb — minimal capability detection shim for
# SU-AI-Plugin.
#
# Lives outside core/ so that:
#   - core/ stays 100% pure Ruby and importable by anyone (tests, fuzz,
#     future build tools, CI), and
#   - capability probes can be loaded on demand inside SketchUp without
#     dragging the rest of the extension.
#
# Per PI_TASK_001 §18 (Error Handling) and §14 (模块边界):
#   - The SketchUp API Layer is the only place allowed to talk to
#     Sketchup::* namespaces.
#   - Capability detection uses `respond_to?` first, version second;
#     we never hardcode SU 20xx checks in analyzers.
#
# No tests here: this module only runs inside SketchUp. Owner verification
# (per Q002=A) covers the real-SU paths; the design is locked to SU2017+
# capability flags so behavior is identical from 2017 onward for the
# features this extension actually uses.
#

require_relative '../core/source_reference'

module SUAnalysis
  module Compatibility
    module SUCapability
      module_function

      # ---- SketchUp version ------------------------------------------------

      # Returns the SU version as a comparable Integer (e.g. 2017, 2024).
      # Returns nil if called outside SketchUp (e.g. in unit tests).
      def sketchup_version
        return nil unless defined?(Sketchup)
        return nil unless Sketchup.respond_to?(:version)
        v = Sketchup.version
        return nil if v.nil?
        v.to_i
      end

      # ---- persistent_id (SU2017+) ----------------------------------------

      # PI_TASK_001 §11 + Q003: persistent_id is available on
      # Sketchup::Entity from SU2017 onward, but NOT on every entity type
      # and may be invalid. We probe per-instance instead of per-version.
      def supports_persistent_id?(entity)
        return false unless entity.respond_to?(:persistent_id)
        begin
          # persistent_id returns Integer or nil (or raises on invalid).
          # We do NOT consume the value here — caller still has to handle
          # nil / exception results.
          entity.persistent_id
          true
        rescue StandardError
          false
        end
      end

      # Safe read: returns Integer or nil, never raises.
      def safe_persistent_id(entity)
        return nil unless entity.respond_to?(:persistent_id)
        begin
          entity.persistent_id
        rescue StandardError
          nil
        end
      end

      # ---- Bounds / type probes -------------------------------------------

      def edge?(obj)
        return false unless obj
        # Sketchup::Edge is the canonical type. We avoid `is_a?(Sketchup::Edge)`
        # so this file can be required by tests outside SU.
        obj.respond_to?(:start) && obj.respond_to?(:end) && obj.respond_to?(:vertices)
      end

      def group?(obj)
        return false unless obj
        defined?(Sketchup::Group) && obj.is_a?(Sketchup::Group)
      end

      def component_instance?(obj)
        return false unless obj
        defined?(Sketchup::ComponentInstance) && obj.is_a?(Sketchup::ComponentInstance)
      end

      def container?(obj)
        group?(obj) || component_instance?(obj)
      end

      # ---- Layer name -----------------------------------------------------

      def layer_name(entity)
        return nil unless entity.respond_to?(:layer) && entity.layer
        # layer may be a String (old SU) or a Sketchup::Layer (new SU).
        if entity.layer.respond_to?(:name)
          entity.layer.name.to_s
        else
          entity.layer.to_s
        end
      rescue StandardError
        nil
      end

      # ---- Build a SourceReference from a SU entity -----------------------

      # entity_id: SU's internal Entity object_id is the only globally-unique
      # handle guaranteed across versions. We DO NOT use it for cross-session
      # stability — that's what persistent_id is for. We pass both and let
      # the SourceReference mark itself stable?() iff persistent_id is present.
      def build_source_reference(entity, kind: 'edge')
        pid = safe_persistent_id(entity)
        label = nil
        if entity.respond_to?(:definition) && entity.definition && entity.definition.respond_to?(:name)
          label = entity.definition.name.to_s
        end
        label ||= entity.respond_to?(:typename) ? entity.typename.to_s : 'entity'
        SUAnalysis::Core::SourceReference.new(
          entity_id:    entity.object_id,
          persistent_id: pid,
          kind:         kind.to_s,
          label:        label
        )
      end
    end
  end
end
