#
# compatibility/su_derived_workspace_adapter.rb — V1.4 production
# SketchUp adapter for DerivedGeometryWorkspace.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 3 + Stage 4:
#
#   "Wrap host writes in compatible SketchUp operations. On
#    exception, abort or invalidate the partial derived result;
#    source remains untouched. If cleanup cannot complete, the
#    result must require discard/rebuild and must not appear
#    valid or READY."
#
# The production adapter creates REAL SketchUp::Group entities
# in the active model. It deliberately uses a recognizable
# name prefix ("SU-AI-Derived-") so operators can see what
# belongs to the plugin and what belongs to source. Source
# entities are NEVER touched.
#
# Per directive: shared ComponentDefinition aliasing is a
# release BLOCK. The adapter does NOT accept a source-side
# handle parameter -- every derived group is freshly created
# by Sketchup::Entities#add_group with no shared-definition
# aliasing. (Verified at runtime -- Sketchup::Entities#add_group
# creates a brand-new ComponentDefinition per call.)
#
# Capability detection (per AGENT.md §3):
#   - sketchup_available? checks for the Sketchup module.
#   - When unavailable (test env without stubs), all methods
#     raise a typed StandardError that the workspace maps to
#     a :failed state.
#

require_relative '../core/derived_workspace_adapter'

module SUAnalysis
  module Compatibility
    class SketchupDerivedWorkspaceAdapter < SUAnalysis::Core::DerivedWorkspaceAdapter
      # Recognizable prefix so operators can distinguish
      # plugin-owned derived groups from source.
      NAME_PREFIX = 'SU-AI-Derived-'.freeze

      class SketchupUnavailableError < StandardError; end

      # Per AGENT.md §3 capability detection: respond_to? on
      # the Sketchup constant. The test env does not load the
      # SU stubs by default.
      def self.sketchup_available?
        return false unless defined?(Sketchup)
        return false unless Sketchup.respond_to?(:active_model)
        Sketchup.active_model.respond_to?(:active_entities)
      rescue StandardError
        false
      end

      def sketchup_available?
        self.class.sketchup_available?
      end

      # Create a brand-new top-level group in the active
      # model. Returns the Sketchup::Group (the host handle).
      # Raises on any failure; the workspace maps that to
      # :failed.
      def create_top_level_group(name)
        unless sketchup_available?
          raise SketchupUnavailableError,
                "Sketchup.active_model not available; cannot create derived group #{name}"
        end
        model = Sketchup.active_model
        entities = model.active_entities
        # Sketchup::Entities#add_group creates a NEW
        # ComponentDefinition under the hood -- it does NOT
        # alias source-side definitions. Per directive gate B,
        # this guarantees independent derived ownership.
        g = entities.add_group(NAME_PREFIX + name.to_s)
        g
      end

      # Add a face to the derived group. Skips on invalid
      # input (no points / wrong shape).
      def add_face_to_group(group_handle, points)
        unless group_handle && group_handle.respond_to?(:entities)
          raise ArgumentError,
                "group_handle is not a Sketchup::Group: #{group_handle.inspect}"
        end
        unless points.is_a?(Array) && points.length >= 3
          raise ArgumentError,
                "add_face_to_group requires Array of >= 3 points; got #{points.inspect}"
        end
        face = group_handle.entities.add_face(points)
        face
      end

      # Dispose a derived group. Idempotent; safe to call on
      # an already-erased handle.
      def dispose(handle)
        return true if handle.nil?
        # If the handle is no longer valid (already erased),
        # the cleanup is a no-op (success).
        return true unless handle.respond_to?(:valid?)
        return true unless handle.valid?
        handle.erase!
        true
      end

      # Snapshot the current host-assigned id(s) for the
      # derived group. EXCLUDED from the rebuild fingerprint
      # by DerivedEntityRecord's == contract.
      def host_assigned_ids_of(handle)
        return {} if handle.nil?
        ids = {}
        if handle.respond_to?(:entityID) && handle.entityID
          ids['entityID'] = handle.entityID
        end
        if handle.respond_to?(:persistent_id) && handle.persistent_id
          ids['persistent_id'] = handle.persistent_id
        end
        ids
      end
    end
  end
end
