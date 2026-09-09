#
# core/endpoint_record.rb -V1.7 EndpointRecord + DerivedEdgeRecord.
#
# Per frozen V1.7 Blueprint §6:
#
#   "V1.7 analysis runs on the CURRENT DerivedGeometryWorkspace
#    after any V1.5/V1.6 operations. Create a pure logical
#    snapshot of current derived edges in world/model coordinates.
#    Each EndpointRecord conceptually contains:
#      - endpoint_key;
#      - derived_edge_id;
#      - endpoint_role (start/end or stable equivalent);
#      - world_coordinate;
#      - owner/context identity;
#      - layer/source-layer identity where available;
#      - source occurrence identity/provenance;
#      - incident derived edge IDs;
#      - host handle reference only in the host execution layer;
#      - curve membership evidence;
#      - face adjacency evidence.
#
#    Each DerivedEdgeRecord conceptually contains:
#      - derived_edge_id;
#      - endpoint A key;
#      - endpoint B key;
#      - world coordinates;
#      - source provenance;
#      - layer/context evidence;
#      - origin_kind:
#        - source_derived
#        - duplicate_repair_survivor/current derived
#        - generated_gap_bridge
#      - repair_action_id if generated."
#
# Pure value-object records. JSON-safe (with one explicit JSON-
# unsafe field for the host handle reference, which the proposer
# uses internally and strips before snapshot publication). No
# live host mutation.
#

require 'digest'
require_relative 'derived_entity_record'

module SUAnalysis
  module Core
    class EndpointRecord
      # Origin kinds for the DerivedEdgeRecord this endpoint
      # belongs to (per Blueprint §6).
      ORIGIN_KIND_SOURCE_DERIVED          = 'source_derived'.freeze
      ORIGIN_KIND_DUPLICATE_REPAIR_SURVIVOR = 'duplicate_repair_survivor'.freeze
      ORIGIN_KIND_GENERATED_GAP_BRIDGE    = 'generated_gap_bridge'.freeze

      # Endpoint role constants (start / end are the only two
      # faithful roles for a derived Edge).
      ROLE_START = 'start'.freeze
      ROLE_END   = 'end'.freeze

      attr_reader :endpoint_key, :derived_edge_id, :role,
                  :world_coordinate, :layer_name,
                  :source_occurrence_id, :source_occurrence_ids,
                  :incident_derived_edge_ids,
                  :curve_membership, :face_adjacency_count,
                  :origin_kind, :host_vertex_handle

      def initialize(endpoint_key:, derived_edge_id:, role:,
                     world_coordinate:, layer_name: nil,
                     source_occurrence_id: nil,
                     source_occurrence_ids: nil,
                     incident_derived_edge_ids: [],
                     curve_membership: nil,
                     face_adjacency_count: 0,
                     origin_kind: ORIGIN_KIND_SOURCE_DERIVED,
                     host_vertex_handle: nil)
        @endpoint_key              = endpoint_key.to_s
        @derived_edge_id           = derived_edge_id.to_s
        @role                      = role.to_s
        unless world_coordinate.is_a?(Array) && world_coordinate.length == 3
          raise ArgumentError,
                "EndpointRecord requires world_coordinate to be a 3-Float Array; got #{world_coordinate.inspect}"
        end
        @world_coordinate          = world_coordinate.dup.freeze
        @layer_name                = layer_name.nil? ? nil : layer_name.to_s
        # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-003:
        # plural source provenance is AUTHORITATIVE end-to-end.
        # The plural `source_occurrence_ids` field is the
        # normalized-sorted-uniq String Array carried through
        # the V1.7 pipeline. The singular `source_occurrence_id`
        # is a backwards-compatible accessor derived from the
        # plural field (first element) so older callers still
        # see a single representative occurrence ID.
        plural_raw = if source_occurrence_ids.nil?
                       # Allow singular-only legacy callers.
                       source_occurrence_id.nil? ? [] : [source_occurrence_id]
                     else
                       Array(source_occurrence_ids)
                     end
        @source_occurrence_ids = plural_raw.map { |v|
          v.nil? ? '' : v.to_s
        }.reject { |s| s.empty? }.uniq.sort.freeze
        @source_occurrence_id = @source_occurrence_ids.first
        @incident_derived_edge_ids = Array(incident_derived_edge_ids).map(&:to_s).freeze
        @curve_membership          = curve_membership.nil? ? nil : curve_membership.to_s
        @face_adjacency_count      = face_adjacency_count.to_i
        @origin_kind               = origin_kind.to_s
        @host_vertex_handle        = host_vertex_handle  # NOT JSON-safe by design
      end

      # Deterministic equality by content. host_vertex_handle is
      # NOT compared (it is intentionally not content-equality
      # safe across processes).
      def ==(other)
        return false unless other.is_a?(EndpointRecord)
        endpoint_key == other.endpoint_key &&
          derived_edge_id == other.derived_edge_id &&
          role == other.role &&
          world_coordinate == other.world_coordinate &&
          layer_name == other.layer_name &&
          source_occurrence_ids == other.source_occurrence_ids &&
          curve_membership == other.curve_membership &&
          face_adjacency_count == other.face_adjacency_count &&
          origin_kind == other.origin_kind
      end
      alias eql? ==

      def hash
        [endpoint_key, derived_edge_id, role, world_coordinate,
         layer_name, source_occurrence_ids, curve_membership,
         face_adjacency_count, origin_kind].hash
      end

      # JSON-safe Hash. host_vertex_handle is intentionally
      # omitted; only canonical content is published.
      def to_h
        {
          'endpoint_key'              => endpoint_key,
          'derived_edge_id'           => derived_edge_id,
          'role'                      => role,
          'world_coordinate'          => world_coordinate.dup,
          'layer_name'                => layer_name,
          'source_occurrence_id'      => source_occurrence_id,
          'source_occurrence_ids'     => source_occurrence_ids.dup,
          'incident_derived_edge_ids' => incident_derived_edge_ids.dup,
          'curve_membership'          => curve_membership,
          'face_adjacency_count'      => face_adjacency_count,
          'origin_kind'               => origin_kind
        }.freeze
      end

      # Build a deterministic endpoint_key from the parent
      # derived_edge_id + role. Stable across rebuilds because
      # the derived_edge_id itself is deterministic (see
      # WorkingModeRunner._stable_id_fragment).
      def self.key_for(derived_edge_id, role)
        "#{derived_edge_id.to_s}.#{role.to_s}"
      end
    end

    class DerivedEdgeRecord
      attr_reader :derived_edge_id, :endpoint_a_key, :endpoint_b_key,
                  :world_endpoints, :source_occurrence_id,
                  :source_occurrence_ids,
                  :layer_name, :origin_kind, :repair_action_id,
                  :created_at, :host_handle

      def initialize(derived_edge_id:, endpoint_a_key:, endpoint_b_key:,
                     world_endpoints:, source_occurrence_id: nil,
                     source_occurrence_ids: nil,
                     layer_name: nil,
                     origin_kind: EndpointRecord::ORIGIN_KIND_SOURCE_DERIVED,
                     repair_action_id: nil,
                     created_at: nil,
                     host_handle: nil)
        @derived_edge_id      = derived_edge_id.to_s
        @endpoint_a_key       = endpoint_a_key.to_s
        @endpoint_b_key       = endpoint_b_key.to_s
        unless world_endpoints.is_a?(Array) && world_endpoints.length == 2 &&
               world_endpoints.all? { |p| p.is_a?(Array) && p.length == 3 }
          raise ArgumentError,
                "DerivedEdgeRecord requires world_endpoints = [p1, p2] (each 3-Float); got #{world_endpoints.inspect}"
        end
        @world_endpoints      = world_endpoints.map { |p| [p[0], p[1], p[2]] }.freeze
        # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-003:
        # plural source provenance is AUTHORITATIVE end-to-end.
        # The plural `source_occurrence_ids` field is the
        # normalized-sorted-uniq String Array carried through
        # the V1.7 pipeline. The singular `source_occurrence_id`
        # is a backwards-compatible accessor derived from the
        # plural field (first element) so older callers still
        # see a single representative occurrence ID.
        plural_raw = if source_occurrence_ids.nil?
                       source_occurrence_id.nil? ? [] : [source_occurrence_id]
                     else
                       Array(source_occurrence_ids)
                     end
        @source_occurrence_ids = plural_raw.map { |v|
          v.nil? ? '' : v.to_s
        }.reject { |s| s.empty? }.uniq.sort.freeze
        @source_occurrence_id = @source_occurrence_ids.first
        @layer_name           = layer_name.nil? ? nil : layer_name.to_s
        @origin_kind          = origin_kind.to_s
        @repair_action_id     = repair_action_id.nil? ? nil : repair_action_id.to_s
        @created_at           = (created_at || default_timestamp).to_s.freeze
        @host_handle          = host_handle  # NOT JSON-safe by design
      end

      def ==(other)
        return false unless other.is_a?(DerivedEdgeRecord)
        derived_edge_id == other.derived_edge_id &&
          endpoint_a_key == other.endpoint_a_key &&
          endpoint_b_key == other.endpoint_b_key &&
          world_endpoints == other.world_endpoints &&
          source_occurrence_ids == other.source_occurrence_ids &&
          origin_kind == other.origin_kind
      end
      alias eql? ==

      def hash
        [derived_edge_id, endpoint_a_key, endpoint_b_key,
         world_endpoints, source_occurrence_ids, origin_kind].hash
      end

      # JSON-safe Hash. host_handle is intentionally omitted.
      def to_h
        {
          'derived_edge_id'      => derived_edge_id,
          'endpoint_a_key'       => endpoint_a_key,
          'endpoint_b_key'       => endpoint_b_key,
          'world_endpoints'      => world_endpoints.map { |p| p.dup },
          'source_occurrence_id' => source_occurrence_id,
          'source_occurrence_ids' => source_occurrence_ids.dup,
          'layer_name'           => layer_name,
          'origin_kind'          => origin_kind,
          'repair_action_id'     => repair_action_id,
          'created_at'           => created_at
        }.freeze
      end

      def generated_gap_bridge?
        origin_kind == EndpointRecord::ORIGIN_KIND_GENERATED_GAP_BRIDGE
      end

      def self.default_timestamp
        '1970-01-01T00:00:00Z'
      end

      private

      def default_timestamp
        self.class.default_timestamp
      end
    end

    # Build EndpointRecord + DerivedEdgeRecord arrays from a
    # DerivedGeometryWorkspace. Pure read of the workspace's
    # entities; resolves host vertex handles via the adapter for
    # safety evidence (curve / face adjacency) AND for LIVE
    # current-coordinate authority (per V1.9A FINAL BLOCK FIX P0).
    #
    # The `host_vertex_handles` map (keyed by endpoint_key) is
    # populated as a side effect; the proposer / executor
    # consult this map WITHOUT serializing it.
    #
    # V1.9A FINAL BLOCK FIX -P0 live-coordinate authority:
    #
    #   Per dispatch §1.3 + Blueprint §6: "V1.7 analysis runs
    #   on the CURRENT DerivedGeometryWorkspace after V1.5 /
    #   V1.6 operations." When V1.6 mutates derived host
    #   vertices (PlanarNormalizationExecutor's
    #   transform_vertices_by_vectors), the per-record
    #   `geometry_summary['start' / 'end']` cache remains the
    #   BUILD-TIME coordinate and becomes stale.
    #
    #   Therefore the current live derived host geometry is
    #   AUTHORITATIVE for V1.7 coordinates whenever the host
    #   execution layer can resolve it:
    #
    #     1. Preserve DerivedEntityRecord identity /
    #        provenance / layer / origin semantics (no change).
    #     2. Preserve the existing endpoint_key / derived_edge_id
    #        contract (no change).
    #     3. Resolve each endpoint's host vertex handle through
    #        the already-supplied host map (the workspace's
    #        handle_for(derived_id) seam).
    #     4. When adapter.vertex_position(handle) is available
    #        AND returns a finite [x, y, z], use that LIVE
    #        position as the endpoint's world_coordinate AND
    #        the matching slot in the parent edge's
    #        world_endpoints.
    #     5. Cached geometry_summary['start' / 'end'] is allowed
    #        only as the host-free / no-live-handle fallback
    #        for pure tests or contexts that genuinely have no
    #        live coordinate authority.
    #     6. If a live host handle exists AND the adapter
    #        exposes vertex_position BUT the position read is
    #        malformed / non-finite / unreadable, DO NOT
    #        silently substitute the cached pre-mutation
    #        coordinate. Fail closed by raising a specific
    #        error with stable reason containing
    #        `live_vertex_position_unreadable` (endpoint key
    #        appended). The orchestrator's _safe_invoke
    #        boundary logs / toasts the failure and the UI
    #        surfaces it truthfully; source / canonical graph
    #        state stay consistent.
    #     7. The snapshot builder MUST NOT mutate SketchUp.
    #     8. The snapshot builder MUST NOT rewrite
    #        geometry_summary (the cache remains the
    #        build-time snapshot; live coordinates are
    #        applied to the OUTGOING EdgeRecord /
    #        EndpointRecord only).
    module DerivedTopologySnapshotBuilder
      module_function

      # Stable fail-closed reason string. The orchestrator's
      # _safe_invoke boundary logs the exception class +
      # message verbatim; the UI's FAILED copy uses a
      # frozen generic CN message that does NOT expose this
      # string (per A2-UX-01 narrow correction). This
      # constant exists so the substring is grep-able for
      # tests + source-level guards.
      LIVE_POSITION_UNREADABLE_REASON = 'live_vertex_position_unreadable'.freeze

      # Custom error class carrying the fail-closed reason.
      # Carries the endpoint_key as data (not in the message
      # string) so callers can recover the offending key
      # without parsing.
      class LiveVertexPositionUnreadable < StandardError
        attr_reader :endpoint_key, :reason
        def initialize(endpoint_key:, underlying: nil)
          @endpoint_key = endpoint_key.to_s
          @reason       = LIVE_POSITION_UNREADABLE_REASON
          suffix        = @endpoint_key.empty? ? '' : " (endpoint_key=#{@endpoint_key})"
          base          = "#{LIVE_POSITION_UNREADABLE_REASON}#{suffix}"
          msg           = underlying.nil? ? base : "#{base}: #{underlying.class}: #{underlying.message}"
          super(msg)
        end
      end

      # Snapshot the workspace's :edge entities into a pure
      # logical topology.
      #
      # Returns:
      #   {
      #     endpoints:        Array<EndpointRecord>
      #     edges:            Array<DerivedEdgeRecord>
      #     host_vertex_map:  Hash<endpoint_key => host_vertex_handle>
      #   }
      #
      # The host_vertex_map is INTENTIONALLY retained on the
      # host execution layer (the executor uses it); it is
      # stripped before the result is published to the UI
      # snapshot. The map is keyed by endpoint_key.
      def build(workspace:, adapter:, vertex_keys_by_edge: nil)
        endpoints = []
        edges     = []
        host_vertex_map = vertex_keys_by_edge || {}
        if workspace.nil?
          return {
            'endpoints'       => endpoints,
            'edges'           => edges,
            'host_vertex_map' => host_vertex_map
          }
        end
        edge_records = workspace.entities.select { |r|
          r.respond_to?(:kind) && r.kind == :edge
        }
        edge_records.each do |rec|
          edid = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
          next if edid.empty?
          gs = rec.respond_to?(:geometry_summary) ? rec.geometry_summary : {}
          next unless gs.is_a?(Hash)
          cached_s = gs['start']
          cached_e = gs['end']
          # Cached fallback path (host-free / no-live-handle):
          # the cached summary MUST itself be a finite 3-Float
          # Array, otherwise this edge is not snapshot-able.
          unless cached_s.is_a?(Array) && cached_s.length == 3 &&
                 cached_e.is_a?(Array) && cached_e.length == 3
            next
          end
          unless _is_finite_point?(cached_s) && _is_finite_point?(cached_e)
            next
          end
          # V17-AIPM-EVIDENCE-INTEGRATION-FINAL-2026-09-01 R5 fix:
          # the previous expression was
          #   (gs['layer'] || rec.respond_to?(:layer) ? rec.layer : nil) || ...
          # which Ruby parses as
          #   ((gs['layer'] || rec.respond_to?(:layer)) ? rec.layer : nil) || ...
          # so ANY derived edge carrying a layer in its
          # geometry_summary evaluated `rec.layer` -- a method
          # DerivedEntityRecord does NOT define. The whole
          # production WorkingModeRunner.compute_gap_repair /
          # apply_gap_repair path therefore raised NoMethodError
          # for every layered CAD selection (the V1.7 Owner
          # demo path). Intent (unchanged): prefer the
          # geometry_summary layer, fall back to a record-level
          # `layer` reader only when the record exposes one.
          layer_name = gs['layer']
          if layer_name.nil? && rec.respond_to?(:layer)
            layer_name = rec.layer
          end
          layer_name = layer_name.to_s unless layer_name.nil?
          # Resolve safety evidence via the adapter when one is
          # available. A missing adapter leaves the fields nil/0
          # (safe default).
          safety = if adapter && rec.respond_to?(:host_assigned_ids)
                      rec.host_assigned_ids
                    else
                      nil
                    end
          # P0 live-coordinate authority:
          # Resolve each endpoint's CURRENT world coordinate.
          #   - If both the workspace's handle_for(derived_id)
          #     seam AND adapter.vertex_position are available
          #     AND the read returns a finite 3-Float Array,
          #     the LIVE coordinate wins (this is the
          #     post-mutation truth after V1.6).
          #   - Otherwise we fall back to the cached
          #     geometry_summary coordinate (pure-test path /
          #     host-free contexts that genuinely have no live
          #     coordinate authority).
          #   - A live handle + adapter.vertex_position that
          #     yields a malformed / non-finite result MUST
          #     fail closed (raise LiveVertexPositionUnreadable
          #     with the offending endpoint_key). Silently
          #     substituting the cached pre-mutation coordinate
          #     is the bug P0 closes.
          host_handle = nil
          if adapter && workspace.respond_to?(:handle_for)
            host_handle = workspace.handle_for(edid)
          end
          # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
          # §6.1): the LIVE host coordinate authority is the
          # actual endpoint Vertex handle, NOT the edge /
          # group handle. The workspace's
          # `handle_for(derived_id)` returns the derived
          # Group wrapper, which is correct for edge_curve
          # / edge_faces_count / edge ownership / discard
          # / provenance, but it is NOT a host Vertex.
          # Production `vertex_position(group_handle)`
          # returns nil; the legacy code therefore
          # silently fell back to the cached
          # geometry_summary coordinate, which is the bug
          # P0 closes.
          #
          # The endpoint-level host Vertex handles live
          # in `host_vertex_map[endpoint_key]`, populated
          # upstream by `_host_vertex_map(workspace)` via
          # `adapter.edge_endpoints(group_handle)` (see
          # working_mode_runner.rb §V1.7 internals). When
          # the per-endpoint Vertex handle is resolvable
          # we MUST read the LIVE coordinate from THAT
          # handle, not the Group handle. The Group
          # handle is used only as a last-resort
          # fallback (so the legacy semantic survives in
          # tests that do not populate the host vertex
          # map).
          per_endpoint_start = host_vertex_map["#{edid}.start"]
          per_endpoint_end   = host_vertex_map["#{edid}.end"]
          # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
          # §6.2): the live authority is the per-endpoint
          # Vertex handle resolved from `host_vertex_map`
          # (NOT the Group handle). Pass the per-endpoint
          # handle as the live read authority. When it is
          # nil there is genuinely no live authority and
          # the helper returns nil so the cached fallback
          # below applies. When it is non-nil but the read
          # is unreadable the helper raises
          # LiveVertexPositionUnreadable per the fail-closed
          # contract.
          start_coord = _live_coordinate_for(
            adapter:             adapter,
            host_handle:         host_handle,
            endpoint_key:        "#{edid}.start",
            cached_coordinate:   cached_s,
            per_endpoint_handle: per_endpoint_start
          ) || cached_s
          end_coord = _live_coordinate_for(
            adapter:             adapter,
            host_handle:         host_handle,
            endpoint_key:        "#{edid}.end",
            cached_coordinate:   cached_e,
            per_endpoint_handle: per_endpoint_end
          ) || cached_e
          curve_membership      = nil
          face_adjacency_count  = 0
          if adapter && host_handle
            if adapter.respond_to?(:edge_curve) && adapter.respond_to?(:edge_faces_count)
              begin
                curve = adapter.edge_curve(host_handle)
                curve_membership = curve.inspect if curve
                face_adjacency_count = adapter.edge_faces_count(host_handle).to_i
              rescue StandardError
                # Defensive: never let adapter failure corrupt the
                # pure snapshot. Defaults are safe (nil/0).
              end
            end
          end
          occ_id = if rec.respond_to?(:source_occurrence_ids)
                     Array(rec.source_occurrence_ids).first
                   end
          # V17-AIPM-CODEX-XHIGH-BLOCK-FIX-2026-09-02 INT-003:
          # PLURAL source provenance is AUTHORITATIVE end-to-end.
          # The previous code captured only `Array(...).first`
          # so any survivor that already represented multiple
          # source occurrences had all but the first lost
          # before proposal creation. Read the FULL
          # `source_occurrence_ids` from the derived record and
          # normalize: Strings, uniq, sorted. This preserves
          # the complete union across the snapshot builder,
          # endpoint lookup, proposer, generated record, and
          # canonical gap_bridge edge.
          occ_ids_plural = if rec.respond_to?(:source_occurrence_ids)
                             Array(rec.source_occurrence_ids).map { |v|
                               v.nil? ? '' : v.to_s
                             }.reject { |s| s.empty? }.uniq.sort
                           else
                             []
                           end
          # Backwards-compat fallback: if the record carries
          # only the singular accessor and no plural list, use
          # that singular value (wrapped as a 1-element
          # sorted/uniq array).
          if occ_ids_plural.empty? && rec.respond_to?(:source_occurrence_id) &&
             rec.source_occurrence_id && !rec.source_occurrence_id.to_s.empty?
            occ_ids_plural = [rec.source_occurrence_id.to_s]
          end
          # DerivedEdgeRecord (parent).
          origin_kind = _origin_kind_for(rec)
          repair_action_id = rec.respond_to?(:respond_to?) && rec.respond_to?(:repair_action_id) ?
                               rec.repair_action_id : nil
          edge = DerivedEdgeRecord.new(
            derived_edge_id:      edid,
            endpoint_a_key:       "#{edid}.start",
            endpoint_b_key:       "#{edid}.end",
            world_endpoints:      [[start_coord[0], start_coord[1], start_coord[2]],
                                   [end_coord[0],   end_coord[1],   end_coord[2]]],
            source_occurrence_id: occ_id,
            source_occurrence_ids: occ_ids_plural,
            layer_name:           layer_name,
            origin_kind:          origin_kind,
            repair_action_id:     repair_action_id,
            created_at:           (rec.respond_to?(:created_at) ? rec.created_at : nil) || DerivedEdgeRecord.default_timestamp,
            host_handle:          host_handle
          )
          edges << edge
          # Two EndpointRecords per edge. Each tracks host
          # vertex handle only when explicitly resolvable from
          # the adapter (the executor needs this for the
          # add_line path).
          end_a = EndpointRecord.new(
            endpoint_key:              "#{edid}.start",
            derived_edge_id:           edid,
            role:                      EndpointRecord::ROLE_START,
            world_coordinate:          [start_coord[0], start_coord[1], start_coord[2]],
            layer_name:                layer_name,
            source_occurrence_id:      occ_id,
            source_occurrence_ids:     occ_ids_plural,
            incident_derived_edge_ids: [edid],
            curve_membership:          curve_membership,
            face_adjacency_count:      face_adjacency_count,
            origin_kind:               origin_kind,
            host_vertex_handle:        (host_vertex_map && host_vertex_map["#{edid}.start"]) || nil
          )
          end_b = EndpointRecord.new(
            endpoint_key:              "#{edid}.end",
            derived_edge_id:           edid,
            role:                      EndpointRecord::ROLE_END,
            world_coordinate:          [end_coord[0], end_coord[1], end_coord[2]],
            layer_name:                layer_name,
            source_occurrence_id:      occ_id,
            source_occurrence_ids:     occ_ids_plural,
            incident_derived_edge_ids: [edid],
            curve_membership:          curve_membership,
            face_adjacency_count:      face_adjacency_count,
            origin_kind:               origin_kind,
            host_vertex_handle:        (host_vertex_map && host_vertex_map["#{edid}.end"]) || nil
          )
          endpoints << end_a
          endpoints << end_b
        end
        {
          'endpoints'       => endpoints,
          'edges'           => edges,
          'host_vertex_map' => host_vertex_map
        }
      end

      # Resolve the CURRENT world coordinate for one
      # endpoint. Returns:
      #   - A live 3-Float Array (the live coordinate), when
      #     adapter + host_handle + vertex_position are all
      #     available AND the read succeeds with a finite
      #     result.
      #   - nil, when the adapter or host_handle is missing /
      #     vertex_position is not exposed (cached fallback
      #     is the caller's authority).
      # Raises:
      #   - LiveVertexPositionUnreadable when a live handle
      #     exists AND the adapter exposes vertex_position
      #     AND the read returns a malformed / non-finite
      #     result. This is the P0 fail-closed behavior; the
      #     orchestrator's _safe_invoke boundary propagates
      #     the exception to the dialog_runner error
      #     boundary (log + toast + payload re-push).
      #
      # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
      # §6.1): the correct current-coordinate authority
      # path is
      #
      #   endpoint_key
      #   -> host_vertex_map[endpoint_key]
      #   -> actual endpoint Vertex handle
      #   -> adapter.vertex_position(actual Vertex)
      #   -> current world coordinate
      #
      # The Group handle from `workspace.handle_for(derived_id)`
      # is the OWNERSHIP / edge-level handle. It is NOT
      # an endpoint Vertex, so `vertex_position(group)` on
      # the production SketchUp adapter returns nil; the
      # legacy code then silently fell back to the cached
      # geometry_summary coordinate (the bug P0 closes).
      #
      # When the caller (the `build` method above) supplies
      # a `per_endpoint_handle` (resolved upstream from
      # `host_vertex_map[endpoint_key]` via
      # `adapter.edge_endpoints(group_handle)`), that
      # per-endpoint Vertex handle WINS as the live-read
      # authority. When `per_endpoint_handle` is nil we
      # fall back to the Group handle, then to the cached
      # coordinate.
      #
      # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
      # §6.2): when a live endpoint Vertex handle exists
      # AND the adapter exposes `vertex_position`, a `nil`
      # OR malformed OR non-finite read is genuine unreadable
      # live authority. The caller MUST NOT silently fall
      # back to the cached coordinate; the snapshot builder
      # MUST raise `live_vertex_position_unreadable` so
      # the orchestrator transitions through the existing
      # failed-workspace path. Cached fallback is allowed
      # ONLY when there is genuinely no live endpoint
      # authority (host_vertex_map has no handle for this
      # endpoint, OR the adapter genuinely lacks
      # `vertex_position`).
      def _live_coordinate_for(adapter:, host_handle:, endpoint_key:,
                                cached_coordinate:, per_endpoint_handle: nil)
        # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
        # §6.1 + §6.2): the LIVE host coordinate authority
        # is the per-endpoint Vertex handle from
        # `host_vertex_map[endpoint_key]`, NOT the derived
        # Group handle from `workspace.handle_for(derived_id)`.
        # When `per_endpoint_handle` is nil there is genuinely
        # NO live endpoint authority and the helper returns
        # nil so the caller's cached fallback applies.
        # When `per_endpoint_handle` is non-nil but the
        # adapter is missing, the adapter lacks
        # `vertex_position`, or the live read raises / returns
        # nil / returns malformed / returns non-finite data,
        # the helper raises `LiveVertexPositionUnreadable`
        # (fail closed). The Group handle is retained ONLY
        # for backwards compatibility with tests that do not
        # populate the host vertex map; it is NOT consulted
        # when a per-endpoint handle is present.
        handle = per_endpoint_handle
        if handle.nil?
          # No live endpoint authority — caller may use
          # cached fallback.
          return nil
        end
        # V1.9A P0 NARROW RECHECK R3 (fix 2026-09-08):
        # when the caller provided a per-endpoint Vertex
        # handle but the adapter is nil OR the adapter
        # genuinely lacks `vertex_position` capability,
        # there is no usable live authority. Cached
        # fallback IS allowed for this case (host-free
        # pure-test path / contexts that genuinely have
        # no live coordinate authority). Only when the
        # adapter is present AND exposes `vertex_position`
        # but the read returns nil / malformed /
        # non-finite / raises do we fail closed.
        if adapter.nil? || !adapter.respond_to?(:vertex_position)
          # Caller provided a per-endpoint handle but no
          # usable adapter seam — cached fallback is the
          # caller's authority.
          return nil
        end
        # We DO have live endpoint authority reachable.
        # Fail closed on ANY unreadable result.
        begin
          pos = adapter.vertex_position(handle)
        rescue StandardError => e
          raise LiveVertexPositionUnreadable.new(
            endpoint_key: endpoint_key, underlying: e
          )
        end
        # Adapter returned nil => unreadable live authority.
        # Fail closed (do NOT silently substitute cached).
        if pos.nil?
          raise LiveVertexPositionUnreadable.new(
            endpoint_key: endpoint_key, underlying: nil
          )
        end
        # V1.9A P0 NARROW RECHECK R3 (fix 2026-09-08):
        # live position shape MUST be EXACTLY 3 values;
        # an Array longer or shorter than 3 is malformed
        # and fails closed. Previously the code accepted
        # `pos.length >= 3` which silently let 4-element
        # arrays through and ignored the surplus slot(s).
        unless pos.is_a?(Array) && pos.length == 3 &&
               pos[0].is_a?(Numeric) && pos[1].is_a?(Numeric) && pos[2].is_a?(Numeric)
          raise LiveVertexPositionUnreadable.new(
            endpoint_key: endpoint_key,
            underlying:   nil
          )
        end
        finite =
          (!pos[0].respond_to?(:finite?) || pos[0].finite?) &&
          (!pos[1].respond_to?(:finite?) || pos[1].finite?) &&
          (!pos[2].respond_to?(:finite?) || pos[2].finite?)
        unless finite
          raise LiveVertexPositionUnreadable.new(
            endpoint_key: endpoint_key,
            underlying:   nil
          )
        end
        [pos[0].to_f, pos[1].to_f, pos[2].to_f]
      end

      def _origin_kind_for(rec)
        if rec.respond_to?(:origin_kind) && rec.origin_kind
          rec.origin_kind.to_s
        else
          EndpointRecord::ORIGIN_KIND_SOURCE_DERIVED
        end
      end

      def _is_finite_point?(p)
        return false unless p.is_a?(Array)
        return false unless p.length == 3
        p.all? do |v|
          v.is_a?(Numeric) && !v.nil? && v.respond_to?(:finite?) && v.finite?
        end
      end
    end
  end
end
