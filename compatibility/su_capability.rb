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
      # Per Codex Review 005 S2-BLOCK-006: Sketchup.version returns a
      # dotted String in modern SU ('24.0.318'). Calling .to_i on that
      # yields the leading numeric component (e.g. 24), NOT the calendar
      # year. Outside SU returns nil. Prefer product_year for Q003-style
      # year-based assertions; this method is for diagnostic display.
      def sketchup_version
        return nil unless defined?(Sketchup)
        return nil unless Sketchup.respond_to?(:version)
        v = Sketchup.version
        return nil if v.nil?
        v.is_a?(Integer) ? v : nil
      end

      # Normalized calendar-year integer of the SketchUp product.
      # Returns nil outside SU. In real SU, derives from
      # Sketchup.version_number when available (returns the product
      # release year on modern SU). Falls back to a manual parse of
      # Sketchup.version only if version_number is missing.
      def product_year
        return nil unless defined?(Sketchup)
        # Modern SU exposes a numeric release identifier. Map known
        # identifiers back to their calendar year.
        if Sketchup.respond_to?(:version_number)
          vn = Sketchup.version_number
          return su_release_to_year(vn) if vn.is_a?(Integer)
        end
        # Fallback: legacy Sketchup.version Integer (SU <= 2017).
        v = sketchup_version
        return v if v.is_a?(Integer)
        nil
      end

      # Map SketchUp release version_number to its calendar year.
      # Source: SketchUp release notes (major release only). 2017 is
      # the locked baseline (per Q003+A); we expose the full table so
      # any later version is recognized correctly.
      def su_release_to_year(version_number)
        table = {
          17 => 2017, 18 => 2018, 19 => 2019, 20 => 2020,
          21 => 2021, 22 => 2022, 23 => 2023, 24 => 2024,
          25 => 2025, 26 => 2026
        }
        table[version_number]
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

      # entity_id: SU's internal Entity object_id is the only globally-unique
      # handle guaranteed across versions. We DO NOT use it for cross-session
      # stability — that's what persistent_id is for. We pass both and let
      # the SourceReference mark itself stable?() iff persistent_id is present.
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
        SUAnalysis::Core::SourceReference.new(
          entity_id:          entity.object_id,
          persistent_id:      pid,
          kind:               kind.to_s,
          label:              label,
          instance_path:      instance_path,
          persistent_id_path: persistent_id_path
        )
      end

      # ---- Active edit-context -----------------------------------------

      # Per S2-BLOCK-002 round 2: when the user selects an entity while
      # editing inside a Group / Component, the Entity's coordinates are
      # local to the active edit context. The Snapshot builder needs to
      # seed its world transform with the active path's transformation.
      #
      # Returns a 2-tuple [active_path_transform, active_pid_path]:
      #   - active_path_transform: an SU Transform-like or test Fake
      #     representing the cumulative edit-context transform (identity
      #     if no active edit context).
      #   - active_pid_path: Array<Integer> of the PIDs of containers in
      #     the active edit path, from model root down to the deepest
      #     active container (empty if no active edit).
      # Returns [identity_transform, []] outside SU.
      def active_edit_context(model = nil)
        model ||= (defined?(Sketchup) ? Sketchup.active_model : nil)
        return [identity_transform_outside_su, [].freeze] if model.nil?
        # Real SU path. model.active_path is nil when not in edit mode.
        if model.respond_to?(:active_path) && !model.active_path.nil?
          path = model.active_path
          pid_path = path_persistent_ids(path)
          transform = path.respond_to?(:transformation) ? path.transformation : identity_transform_outside_su
          [transform, pid_path]
        else
          [identity_transform_outside_su, [].freeze]
        end
      rescue StandardError
        [identity_transform_outside_su, [].freeze]
      end

      def path_persistent_ids(path)
        return [].freeze unless path.respond_to?(:persistent_id_path)
        # SketchUp returns Array<Integer> directly.
        Array(path.persistent_id_path).map { |x| Integer(x) }.freeze
      rescue StandardError
        [].freeze
      end

      def identity_transform_outside_su
        # SU has Geom::Transformation; tests don't. Use SU when available.
        if defined?(Geom::Transformation)
          Geom::Transformation.new
        else
          nil
        end
      end

      # ---- Resolution back from PID path (used by Owner checklist) -----

      # Given a PID path, resolve it through a model. Returns the leaf
      # Sketchup::InstancePath or nil if unresolvable. Outside SU returns
      # nil unless `model` is a test fake that responds to
      # :instance_path_from_pid_path.
      def resolve_pid_path(model, pid_path)
        return nil if model.nil? || pid_path.nil? || pid_path.empty?
        return nil unless model.respond_to?(:instance_path_from_pid_path)
        model.instance_path_from_pid_path(pid_path)
      rescue StandardError
        nil
      end
    end
  end
end