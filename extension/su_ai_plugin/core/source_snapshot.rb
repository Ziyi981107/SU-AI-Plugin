#
# core/source_snapshot.rb — V1.4 SourceSnapshot contract.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL PREVIEW):
#
#   "The current GeometrySnapshot is not yet a complete V1.4
#    SourceSnapshot. It does not capture snapshot identity /
#    fingerprint, explicit unit/coordinate context, workspace
#    /profile/rule versions, or sufficient transform context
#    for all future reconstruction decisions. Its immutability
#    is also shallow: arrays are frozen at the aggregate level,
#    while nested point arrays, metadata and preflight values
#    can still be mutable. It may be evolved compatibly or
#    wrapped, but it must not be treated as a safe rebuild
#    contract unchanged."
#
# SourceSnapshot is the rebuild contract:
#   - Deeply immutable: every nested Array / Hash is .dup.freeze'd
#     at construction. Defensive copies prevent caller mutation.
#   - Schema-versioned: source_snapshot_schema_version field
#     allows forward-compat drift detection.
#   - Fingerprintable: SHA256 digest via the embedded
#     SourceFingerprint; identical source -> identical digest
#     (risk test 8).
#   - Host-agnostic: holds primitives + SourceRecord / SourceReference
#     values. NEVER holds a live Sketchup::Entity object.
#   - Selection-scope explicit: `selection_scope` records what
#     the user selected, with snapshot-local occurrence IDs that
#     are unique within THIS snapshot (separate from host-
#     resolvable PID identity).
#   - Coordinate policy explicit: `unit` (inches) +
#     `coordinate_origin` (raw vs canonical).
#   - Identity quality preserved per occurrence: resolvable
#     complete PID path / transient root fallback / unresolved
#     nested. NEVER upgrades an incomplete PID path to stable
#     identity via entityID (risk test 5).
#
# Two SourceSnapshots are == iff their schema_version,
# snapshot_id, fingerprint, and execution_config match.
#

require 'digest'
require_relative 'edge_record'
require_relative 'face_record'
require_relative 'layer_record'
require_relative 'source_reference'
require_relative 'source_fingerprint'
require_relative 'execution_config_snapshot'

module SUAnalysis
  module Core
    class SourceSnapshot
      # Locked attribute set. Any future addition is a schema
      # bump (source_snapshot_schema_version) so rebuilds detect
      # drift.
      attr_reader :snapshot_id, :schema_version,
                  :captured_at,
                  :selection_scope, :selection_scope_digest,
                  :edges, :faces, :layers, :vertex_records,
                  :unit, :coordinate_origin,
                  :transform_context,
                  :fingerprint, :execution_config

      SCHEMA_VERSION = '1'.freeze

      def initialize(snapshot_id: nil, captured_at: nil,
                     selection_scope: [], edges: [], faces: [],
                     layers: [], vertex_records: [],
                     unit: 'inches', coordinate_origin: 'raw',
                     transform_context: {},
                     execution_config:,
                     fingerprint: nil)
        # Defensive deep-freeze on every collection. The
        # rebuild contract requires: identical input -> identical
        # snapshot; therefore nothing in the snapshot may mutate
        # post-construction.
        @snapshot_id          = (snapshot_id || self.class.default_snapshot_id).freeze
        @schema_version      = SCHEMA_VERSION
        @captured_at          = (captured_at || self.class.default_timestamp).freeze
        @selection_scope      = deep_freeze_array(selection_scope)
        # selection_scope_digest is derived from selection_scope for
        # the rebuild check; callers can override via the
        # fingerprint: kwarg if they have a precomputed digest.
        @selection_scope_digest = if fingerprint && fingerprint.selection_scope_digest && !fingerprint.selection_scope_digest.empty?
                                    fingerprint.selection_scope_digest
                                  else
                                    digest_selection_scope(selection_scope)
                                  end
        @edges                = deep_freeze_array(edges)
        @faces                = deep_freeze_array(faces)
        @layers               = deep_freeze_array(layers)
        @vertex_records       = deep_freeze_array(vertex_records)
        @unit                 = unit.to_s.freeze
        @coordinate_origin    = coordinate_origin.to_s.freeze
        @transform_context    = (transform_context || {}).dup.freeze
        @execution_config     = execution_config  # must already be frozen
        @fingerprint          = fingerprint  # must already be frozen
        # Top-level freeze: prevents any field re-assignment.
        freeze
      end

      def ==(other)
        return false unless other.is_a?(SourceSnapshot)
        schema_version == other.schema_version &&
          snapshot_id == other.snapshot_id &&
          execution_config == other.execution_config &&
          fingerprint == other.fingerprint &&
          selection_scope == other.selection_scope &&
          edges == other.edges &&
          faces == other.faces &&
          layers == other.layers &&
          transform_context == other.transform_context &&
          unit == other.unit &&
          coordinate_origin == other.coordinate_origin
      end

      def eql?(other)
        self == other
      end

      def hash
        [snapshot_id, schema_version, execution_config.hash,
         fingerprint.hash, selection_scope.hash, edges.hash,
         faces.hash, layers.hash].hash
      end

      def to_h
        {
          snapshot_id:          snapshot_id,
          schema_version:      schema_version,
          captured_at:          captured_at,
          selection_scope:      selection_scope,
          selection_scope_digest: selection_scope_digest,
          edges:                edges,
          faces:                faces,
          layers:               layers,
          vertex_records:       vertex_records,
          unit:                 unit,
          coordinate_origin:    coordinate_origin,
          transform_context:    transform_context,
          execution_config:     execution_config.to_h,
          fingerprint:          fingerprint ? fingerprint.to_h : nil
        }
      end

      def to_digest
        # SHA256 of the canonical (snapshot_id, schema_version,
        # fingerprint.digest, execution_config digest) tuple.
        # The fingerprint already covers the bulk; the
        # schema_version + snapshot_id allow drift detection.
        cfg_digest = execution_config.respond_to?(:digest) ?
                       execution_config.digest : ''
        input = [
          snapshot_id, schema_version,
          fingerprint ? fingerprint.digest : '',
          cfg_digest
        ].join('|')
        Digest::SHA256.hexdigest(input)
      end

      # Build a SourceSnapshot from the existing GeometrySnapshot
      # + selection. Pure-Ruby. This is the V1.4 wiring point:
      # the V1.0-V1.3 GeometrySnapshot is the input; the new
      # SourceSnapshot wraps it with the V1.4 contract.
      def self.from_geometry_snapshot(geometry_snapshot,
                                      selection: nil,
                                      host: nil,
                                      execution_config:,
                                      rule_set_digest:,
                                      snapshot_id: nil,
                                      captured_at: nil)
        # The geometry_snapshot IS the body of the SourceSnapshot
        # in V1.4 (the rebuild contract is a superset of the
        # V1.0 GeometrySnapshot data, not a replacement). We do
        # NOT copy the GeometrySnapshot object identity; we
        # rebuild its array contents from the live fields so we
        # can deep-freeze them.
        edges   = (geometry_snapshot.respond_to?(:edges)   ? geometry_snapshot.edges   : []) || []
        faces   = (geometry_snapshot.respond_to?(:faces)   ? geometry_snapshot.faces   : []) || []
        layers  = (geometry_snapshot.respond_to?(:layers)  ? geometry_snapshot.layers  : []) || []
        vertex_records = (geometry_snapshot.respond_to?(:vertex_records) ? geometry_snapshot.vertex_records : []) || []

        # Build the SourceFingerprint BEFORE we freeze the arrays
        # so it can read the live fields.
        fingerprint = SourceFingerprint.from_snapshot(
          geometry_snapshot,
          selection: selection,
          host: host
        )

        # Selection scope: each entry is a small Hash with
        # {kind:, persistent_id_path:, instance_path:, layer:}.
        # We deep-freeze these below.
        sel_scope = selection ? Array(selection).map do |entry|
          if entry.is_a?(Hash)
            {
              kind:               entry[:kind] || entry['kind'],
              persistent_id_path: (entry[:persistent_id_path] || entry['persistent_id_path'] || []).dup,
              instance_path:      (entry[:instance_path] || entry['instance_path'] || []).dup,
              layer:              entry[:layer] || entry['layer']
            }
          else
            { kind: 'unknown', persistent_id_path: [], instance_path: [], layer: nil }
          end
        end : []

        new(
          snapshot_id:          snapshot_id,
          captured_at:          captured_at,
          selection_scope:      sel_scope,
          edges:                edges,
          faces:                faces,
          layers:               layers,
          vertex_records:       vertex_records,
          unit:                 'inches',
          coordinate_origin:    'raw',
          transform_context:    { 'active_edit_seed' => 'identity' },
          execution_config:     execution_config,
          fingerprint:          fingerprint
        )
      end

      def self.default_snapshot_id
        'snap-' + Time.now.to_i.to_s + '-' + SecureRandom.hex(4) rescue
        'snap-' + Time.now.to_i.to_s
      end

      def self.default_timestamp
        '1970-01-01T00:00:00Z'
      end

      private

      def deep_freeze_array(arr)
        return [].freeze if arr.nil?
        arr.map do |item|
          case item
          when Hash
            item.each_with_object({}) { |(k, v), h| h[k] = deep_freeze_value(v) }.freeze
          when Array
            deep_freeze_array(item)
          else
            deep_freeze_value(item)
          end
        end.freeze
      end

      def deep_freeze_value(v)
        case v
        when Hash
          v.each_with_object({}) { |(k, val), h| h[k] = deep_freeze_value(val) }.freeze
        when Array
          deep_freeze_array(v)
        else
          v.frozen? ? v : v.dup.freeze
        end
      end

      def digest_selection_scope(scope)
        canonical = scope.map do |entry|
          "#{entry[:kind]}|#{entry[:persistent_id_path].to_a.join('/')}|" \
            "#{entry[:instance_path].to_a.join('>')}|#{entry[:layer]}"
        end.sort.join("\n")
        Digest::SHA256.hexdigest(canonical)
      end
    end
  end
end

# SecureRandom fallback for Ruby 2.2.4 (no SecureRandom in stdlib
# before 2.5; on platforms without it we fall back to a
# timestamp-only id which is still unique within one process).
begin
  require 'securerandom'
rescue LoadError
  module SecureRandom
    def self.hex(n)
      # Deterministic 8-hex-char pseudo-id from the current
      # time + process id. NOT cryptographically secure; only
      # used for snapshot_id uniqueness within a single Agent
      # process.
      (Time.now.to_f * 1_000_000).to_i.to_s(16)[-2 * n, 2 * n] || '0' * 2 * n
    end
  end
end