#
# core/derived_workspace_fingerprint.rb — V1.4 derived
# workspace fingerprint.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 3 + risk test 8:
#
#   "A second build from identical source + captured
#    config must produce the same canonical derived
#    fingerprint, excluding documented host-assigned IDs."
#
# Two DerivedWorkspaceFingerprints are == iff their canonical
# content matches. The fingerprint EXCLUDES host-assigned_ids
# (transient) but INCLUDES the derived inventory shape, the
# geometry_summary values, the source_occurrence_ids, the
# source_snapshot_id, and the execution_config digest.
#
# If the source changes between rebuilds, the fingerprint MUST
# drift (proves the rebuild is reading the captured source,
# not stale state).
#

require 'digest'

module SUAnalysis
  module Core
    class DerivedWorkspaceFingerprint
      attr_reader :source_snapshot_id, :execution_config_digest,
                  :derived_entity_count, :derived_entity_digests,
                  :kinds_breakdown, :parent_relationships

      def initialize(source_snapshot_id:,
                     execution_config_digest:,
                     derived_entity_count: 0,
                     derived_entity_digests: [],
                     kinds_breakdown: {},
                     parent_relationships: [])
        @source_snapshot_id       = source_snapshot_id.to_s.freeze
        @execution_config_digest  = execution_config_digest.to_s.freeze
        @derived_entity_count     = derived_entity_count.to_i
        @derived_entity_digests   = (derived_entity_digests || []).dup.freeze
        @kinds_breakdown          = (kinds_breakdown || {}).dup.freeze
        @parent_relationships    = (parent_relationships || []).dup.freeze
        freeze
      end

      def ==(other)
        return false unless other.is_a?(DerivedWorkspaceFingerprint)
        source_snapshot_id == other.source_snapshot_id &&
          execution_config_digest == other.execution_config_digest &&
          derived_entity_count == other.derived_entity_count &&
          derived_entity_digests == other.derived_entity_digests &&
          kinds_breakdown == other.kinds_breakdown &&
          parent_relationships == other.parent_relationships
      end
      alias eql? ==

      def hash
        [source_snapshot_id, execution_config_digest, derived_entity_count,
         derived_entity_digests, kinds_breakdown, parent_relationships].hash
      end

      def digest
        # Canonical SHA256 of the fingerprint's own canonical
        # content (excluding host-assigned_ids -- those are
        # transient and must not affect the digest).
        canonical = to_canonical
        Digest::SHA256.hexdigest(canonical)
      end

      def to_h
        {
          source_snapshot_id:      source_snapshot_id,
          execution_config_digest: execution_config_digest,
          derived_entity_count:    derived_entity_count,
          derived_entity_digests:  derived_entity_digests,
          kinds_breakdown:         kinds_breakdown,
          parent_relationships:   parent_relationships
        }
      end

      # Build a fingerprint from a list of DerivedEntityRecords.
      # The derived_entity_digests array is sorted so the
      # fingerprint is order-independent.
      def self.from_workspace(source_snapshot_id:, execution_config_digest:, entities: [])
        entity_digests = entities.map { |e| e.digest rescue nil }.compact.sort
        kinds = Hash.new(0)
        entities.each { |e| kinds[e.kind] += 1 }
        parents = entities.map { |e| [e.derived_id, e.parent_derived_id] }.sort
        new(
          source_snapshot_id:       source_snapshot_id,
          execution_config_digest:  execution_config_digest,
          derived_entity_count:     entities.length,
          derived_entity_digests:   entity_digests,
          kinds_breakdown:          kinds,
          parent_relationships:    parents
        )
      end

      private

      def to_canonical
        # Stable JSON so the digest is order-independent.
        JSON.generate(to_h.sort_by { |k, _| k.to_s }, sort_keys: false)
      end
    end
  end
end

require 'json'