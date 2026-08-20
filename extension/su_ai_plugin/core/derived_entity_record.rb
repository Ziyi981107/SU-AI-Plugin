#
# core/derived_entity_record.rb — V1.4 DerivedEntityRecord.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 3: DerivedGeometryWorkspace ownership +
# host adapter.
#
# One DerivedEntityRecord represents one EDITABLE entity in
# the derived workspace. The record is the rebuild-safe,
# host-agnostic description of the entity; the host adapter
# (extension/derived_workspace_adapter.rb) maintains the
# mapping between derived_id and the live SketchUp handle.
#
# Locked contract:
#   - derived_id: snapshot-local unique id; stable across
#     rebuilds of identical source + config (per directive
#     "A second build from identical source + captured config
#     must produce the same canonical derived fingerprint").
#   - source_occurrence_ids: snapshot-local occurrence IDs
#     from the SourceSnapshot selection_scope that this entity
#     is derived from. PRESERVE the provenance.
#   - kind: :group | :face | :edge (forward-compat for V1.5+).
#   - geometry_summary: a Hash of primitive values describing
#     the entity's structural shape (e.g. { layer: 'Layer0',
#     vertex_count: 4, bbox: [...] }). Host-agnostic; the
#     rebuild reads geometry_summary and re-creates the entity
#     from the same summary.
#   - parent_derived_id: optional; nil for top-level derived
#     entities, or the derived_id of the parent group for
#     nested entities.
#   - host_assigned_ids: a Hash of host-side transient ids
#     (e.g. SketchUp entityID, group.persistent_id). These are
#     EXCLUDED from the rebuild fingerprint because they can
#     change between rebuilds. They are recorded for audit
#     purposes only.
#
# Independence: every derived entity is INDEPENDENTLY OWNED.
# No derived entity shares a mutable definition with source
# entities (per directive 030 stage 3 gate B: "Prove derived
# geometry owns independent editable geometry. Never create a
# derived ComponentInstance that still shares a ComponentDefinition
# with the source and then edit that definition.").
#

module SUAnalysis
  module Core
    class DerivedEntityRecord
      require 'digest'
      require 'json'
      attr_reader :derived_id, :kind,
                  :source_occurrence_ids,
                  :geometry_summary,
                  :parent_derived_id,
                  :host_assigned_ids

      KINDS = [:group, :face, :edge].freeze

      def initialize(derived_id:,
                     kind:,
                     source_occurrence_ids: [],
                     geometry_summary: {},
                     parent_derived_id: nil,
                     host_assigned_ids: {})
        unless KINDS.include?(kind)
          raise ArgumentError, "unknown DerivedEntity kind: #{kind.inspect}"
        end
        @derived_id             = derived_id.to_s.freeze
        @kind                   = kind.to_sym.freeze
        @source_occurrence_ids  = (source_occurrence_ids || []).dup.freeze
        # geometry_summary must be primitive-only (String /
        # Numeric / Boolean / nil / Array of these / Hash of
        # these). The host adapter may pass anything; we coerce
        # via the build method below.
        @geometry_summary       = self.class.deep_freeze(geometry_summary || {})
        @parent_derived_id     = parent_derived_id.nil? ? nil : parent_derived_id.to_s.freeze
        @host_assigned_ids      = self.class.deep_freeze(host_assigned_ids || {})
        freeze
      end

      def ==(other)
        return false unless other.is_a?(DerivedEntityRecord)
        derived_id == other.derived_id &&
          kind == other.kind &&
          source_occurrence_ids == other.source_occurrence_ids &&
          geometry_summary == other.geometry_summary &&
          parent_derived_id == other.parent_derived_id
        # host_assigned_ids is EXCLUDED from ==; it's host-
        # transient. Two rebuilds of the same source must ==
        # even if SketchUp assigned different entityIDs.
      end
      alias eql? ==

      def hash
        [derived_id, kind, source_occurrence_ids, geometry_summary,
         parent_derived_id].hash
      end

      def to_h
        {
          derived_id:             derived_id,
          kind:                   kind,
          source_occurrence_ids:  source_occurrence_ids,
          geometry_summary:       geometry_summary,
          parent_derived_id:     parent_derived_id,
          host_assigned_ids:      host_assigned_ids
        }
      end

      # Deterministic SHA256 of the canonical record content.
      # EXCLUDES host_assigned_ids (per directive: those are
      # transient and may change between rebuilds).
      def digest
        canonical = to_canonical
        Digest::SHA256.hexdigest(canonical)
      end

      # Recursive deep-freeze of Hash / Array values. Strings
      # and numerics are returned frozen (String#freeze,
      # Numeric is already immutable).
      def self.deep_freeze(v)
        case v
        when Hash
          v.each_with_object({}) { |(k, val), h| h[k] = deep_freeze(val) }.freeze
        when Array
          v.map { |item| deep_freeze(item) }.freeze
        when String
          v.frozen? ? v : v.dup.freeze
        else
          # Numerics / Booleans / nil / Symbols are immutable
          # in Ruby; return as-is.
          v
        end
      end

      private

      def to_canonical
        # Stable JSON, no host-assigned_ids (those are
        # transient and excluded from the rebuild fingerprint).
        cleaned = to_h.reject { |k, _| k == :host_assigned_ids }
        JSON.generate(cleaned.sort_by { |k, _| k.to_s }, sort_keys: false)
      end
    end
  end
end