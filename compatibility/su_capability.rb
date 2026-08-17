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
# Added in Stage 2 BLOCK rework (Codex R002):
#   - html_dialog? — capability probe for Sketchup::HtmlDialog, used by
#     Stage 6 UI. Tested outside SU with a stub test in test_preflight.rb.
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

      # ---- HtmlDialog (SU 2017+, per R002) ---------------------------------

      # True when Sketchup::HtmlDialog is available (SU 2017+). Always
      # false outside SU (including in unit tests).
      def html_dialog?
        return false unless defined?(Sketchup)
        defined?(Sketchup::HtmlDialog) ? true : false
      end

      # ---- persistent_id (SU2017+) ----------------------------------------

      # PI_TASK_001 §11 + Q003: persistent_id is available on
      # Sketchup::Entity from SU2017 onward, but NOT on every entity type
      # and may be invalid. We probe per-instance instead of per-version.
      def supports_persistent_id?(entity)
        return false unless entity.respond_to?(:persistent_id)
        begin
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
        obj.respond_to?(:start) && obj.respond_to?(:end) && obj.respond_to?(:vertices)
      end

      def group?(obj)
        return false unless obj
        if defined?(Sketchup::Group)
          return obj.is_a?(Sketchup::Group)
        end
        obj.class.name.to_s.include?('Group') || obj.class.name.to_s.include?('FakeGroup')
      end

      def component_instance?(obj)
        return false unless obj
        if defined?(Sketchup::ComponentInstance)
          return obj.is_a?(Sketchup::ComponentInstance)
        end
        obj.class.name.to_s.include?('ComponentInstance') ||
          obj.class.name.to_s.include?('FakeComponent')
      end

      def container?(obj)
        # container? is used at runtime inside SU. For unit tests we also
        # need a way to recognize fake groups / components; fall back to
        # class-name matching when class checks are unavailable.
        if defined?(Sketchup::Group) && defined?(Sketchup::ComponentInstance)
          return true if obj.is_a?(Sketchup::Group)
          return true if obj.is_a?(Sketchup::ComponentInstance)
          return false
        end
        # Outside SU (test env): match by class name on FakeSU stand-ins.
        cls = obj.class.name.to_s
        return false if cls.empty?
        # Exclude Edges / Vertices explicitly.
        return false if cls.include?('Edge') || cls.include?('Vertex')
        cls.include?('Group') ||
          cls.include?('ComponentInstance') ||
          cls.include?('Container') ||
          cls.include?('ComponentDefinition')
      end

      def component_definition?(obj)
        # ComponentDefinition is a SU-only class but tests can mock by
        # duck-typing: responds to .entities AND has .name.
        if defined?(Sketchup::ComponentDefinition)
          return obj.is_a?(Sketchup::ComponentDefinition)
        end
        obj.respond_to?(:entities) && obj.respond_to?(:name) && !obj.respond_to?(:definition)
      end

      # ---- Layer name -----------------------------------------------------

      def layer_name(entity)
        return nil unless entity.respond_to?(:layer) && entity.layer
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
      #
      # instance_path: optional Array<String> describing the container chain
      # from the model root to this entity (added per S2-BLOCK-002 to
      # distinguish two ComponentInstances sharing one definition).
      def build_source_reference(entity, kind: 'edge', instance_path: nil)
        pid = safe_persistent_id(entity)
        label = nil
        if entity.respond_to?(:definition) && entity.definition && entity.definition.respond_to?(:name)
          label = entity.definition.name.to_s
        end
        label = entity.respond_to?(:typename) ? entity.typename.to_s : 'entity' if label.nil? || label.empty?
        SUAnalysis::Core::SourceReference.new(
          entity_id:    entity.object_id,
          persistent_id: pid,
          kind:         kind.to_s,
          label:        label,
          instance_path: instance_path
        )
      end
    end
  end
end