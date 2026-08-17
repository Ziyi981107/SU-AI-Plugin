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

      # Returns Sketchup.version as a String for diagnostic display.
      # Real SU returns a dotted String like '17.2.0' or '24.0.318'.
      # Outside SU returns nil.
      #
      # Per Codex Review 007 + CODEX_GUIDANCE_006 (mandatory): this method
      # preserves the dotted String verbatim. We DO NOT call .to_i on it
      # (that yields the leading major 24, NOT the calendar year).
      def sketchup_version
        return nil unless defined?(Sketchup)
        return nil unless Sketchup.respond_to?(:version)
        v = Sketchup.version
        return nil if v.nil?
        v.to_s
      end

      # Returns the leading major version as Integer (17, 18, 24, ...).
      # Use this for the SU2017+ baseline assertion
      # (`sketchup_major_version >= 17`).
      #
      # Per CODEX_GUIDANCE_006: derive the major via .to_i on the dotted
      # version String. Do NOT infer a calendar year from version_number
      # (version_number is an encoded comparison integer, e.g. ~1.7e9 for
      # the SU2017 family — NOT 17).
      def sketchup_major_version
        v = sketchup_version
        return nil if v.nil?
        s = v.to_s
        return nil unless s.is_a?(String)
        # Take leading integer (e.g. "24.0.318" -> 24, "17" -> 17).
        m = s.match(/\A\s*(\d+)/)
        m.nil? ? nil : m[1].to_i
      end

      # ---- HtmlDialog (SU 2017+, per R002) ---------------------------------

      # True when UI::HtmlDialog is available. Per Codex Review 005
      # S2-BLOCK-006: HtmlDialog lives in the UI module
      # (UI::HtmlDialog), NOT Sketchup::HtmlDialog. Always false outside
      # SU (including in unit tests).
      def html_dialog?
        return false unless defined?(UI)
        defined?(UI::HtmlDialog) ? true : false
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

      # entity_id: prefer entity.entityID (real SU API, integer per session);
      # fall back to entity.object_id (Ruby transient) only outside SU or
      # when entityID is unavailable (per Codex Review 007 S2-BLOCK-002).
      # entityID is per-session but integer-stable within a session; object_id
      # is Ruby transient. For cross-session stability use persistent_id.
      #
      # persistent_id_path: optional Array<Integer> of container PIDs from
      # model root to this entity, with the entity's own PID last (added per
      # S2-BLOCK-002 round 2 for machine-resolvable source identity).
      #
      # instance_path: optional Array<String> describing the container chain
      # (display label only; NOT used as canonical identity).
      def build_source_reference(entity, kind: 'edge',
                                  persistent_id_path: nil,
                                  instance_path: nil)
        pid = safe_persistent_id(entity)
        label = nil
        if entity.respond_to?(:definition) && entity.definition && entity.definition.respond_to?(:name)
          label = entity.definition.name.to_s
        end
        label = entity.respond_to?(:typename) ? entity.typename.to_s : 'entity' if label.nil? || label.empty?
        eid = if entity.respond_to?(:entityID) && !entity.entityID.nil?
                entity.entityID
              else
                entity.object_id
              end
        SUAnalysis::Core::SourceReference.new(
          entity_id:          eid,
          persistent_id:      pid,
          kind:               kind.to_s,
          label:              label,
          instance_path:      instance_path,
          persistent_id_path: persistent_id_path
        )
      end

      # ---- Active edit-context -----------------------------------------

      # Per S2-BLOCK-002 round 3 (Codex Review 007 + GUIDANCE 006):
      # real Model#active_path returns an Array of drawing elements
      # (Group / ComponentInstance), NOT an InstancePath-like object.
      # The edit transform is model.edit_transform. Active container
      # PIDs come from iterating model.active_path and calling
      # safe_persistent_id on each entity.
      #
      # Returns a 2-tuple [edit_transform, active_pid_path]:
      #   - edit_transform: an SU Transform (or nil outside SU / tests)
      #   - active_pid_path: Array<Integer> of PIDs of entities in
      #     model.active_path (empty if no active edit context).
      def active_edit_context(model = nil)
        model ||= (defined?(Sketchup) ? Sketchup.active_model : nil)
        return [nil, [].freeze] if model.nil?
        transform = model_edit_transform(model)
        pid_path = active_path_pids(model)
        [transform, pid_path]
      rescue StandardError
        [nil, [].freeze]
      end

      def model_edit_transform(model)
        if model.respond_to?(:edit_transform)
          v = model.edit_transform
          return nil if v.nil?
          v
        else
          nil
        end
      rescue StandardError
        nil
      end

      def active_path_pids(model)
        return [].freeze unless model.respond_to?(:active_path)
        path = model.active_path
        return [].freeze if path.nil?
        return [].freeze unless path.respond_to?(:each)
        pids = []
        path.each do |entity|
          pid = safe_persistent_id(entity)
          pids << pid unless pid.nil?
        end
        pids.freeze
      rescue StandardError
        [].freeze
      end

      # ---- Resolution back from PID path -------------------------------

      # Resolve a PID path through a model. Per CODEX_GUIDANCE_006: real
      # Sketchup::Model#instance_path_from_pid_path expects a dot-delimited
      # String. We serialize Array<Integer> -> "10.20.555" before calling.
      # Returns the resolved Sketchup::InstancePath (or test fake) or nil.
      def resolve_pid_path(model, pid_path)
        return nil if model.nil? || pid_path.nil? || pid_path.empty?
        return nil unless model.respond_to?(:instance_path_from_pid_path)
        serialized = serialize_pid_path(pid_path)
        model.instance_path_from_pid_path(serialized)
      rescue StandardError
        nil
      end

      # Serialize Array<Integer> PID path to dot-delimited String.
      # Empty array returns "" (caller's responsibility to handle).
      def serialize_pid_path(pid_path)
        return '' if pid_path.nil? || pid_path.empty?
        Array(pid_path).map { |x| Integer(x).to_s }.join('.')
      end
    end
  end
end