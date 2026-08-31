#
# core/planar_normalization_proposer.rb — V1.6 Planar Normalization
# proposal builder.
#
# Per frozen V1.6 Blueprint §3 / §6 / §8:
#
#   Bridges the pure PlanarNormalizationAnalyzer (host-free math)
#   to the live DerivedGeometryWorkspace. Responsible for:
#     - gathering unique eligible derived edge vertices;
#     - filtering out unsafe scope (curve, face adjacency,
#       shared-vertex with ineligible geometry);
#     - computing the analyzer result;
#     - building a host mutation plan (per-vertex handle +
#       matching Z-only translation vector);
#     - tracking which source occurrence IDs are affected (for
#       the audit / provenance row).
#
# This module is the SOLE place where derived host handles are
# resolved against the workspace. The pure analyzer never sees
# a host handle; the host executor (PlanarNormalizationExecutor)
# never sees a derivation step.
#
# Locked semantics:
#   - input: a DerivedGeometryWorkspace (state == :ready), a
#     DerivedWorkspaceAdapter, and the captured Tolerance;
#   - output: a frozen Hash
#       {
#         state            : Symbol (same enum as the analyzer),
#         analyzer_result  : the frozen analyzer Hash,
#         proposal         : a frozen Hash describing the host
#                           mutation plan, OR nil iff state !=
#                           READY_TO_NORMALIZE. Shape:
#                           {
#                             target_z,
#                             unique_vertex_handles : [host vertex, ...]
#                             unique_vertex_records : [DerivedEntityRecord-backed
#                                                      vertex info Hash, ...]
#                             vectors                : [[0, 0, dz], ...]
#                             affected_derived_ids   : Array of String
#                             affected_source_occurrence_ids : Array of String
#                             shared_vertex_scope_skipped : Integer
#                             outlier_derived_ids    : Array of String
#                             max_movement           : Float
#                             tolerance_used         : Float
#                           }
#         reason           : String (stable, inspectable)
#         captured_tolerance:
#                           { planar_z_snap, coordinate_epsilon }
#         captured_at      : String (frozen timestamp)
#         rule_id          : 'planar_z_snap.v1'
#         rule_version     : '1'
#       }
#
# The output is JSON-safe (frozen, primitive types only). The
# host handles are NOT included in the JSON-safe proposal; they
# live in the proposal builder's private workspace mapping
# keyed by the proposal's plan_id (so the executor can resolve
# them back without re-deriving).
#
# Reuse of existing concepts:
#   - Tolerance.coordinate_epsilon + Tolerance.planar_z_snap
#   - SourceSnapshot.execution_config for rule/version tagging
#   - DerivedEntityRecord's geometry_summary['start'] / ['end']
#     for source occurrence IDs
#

require_relative 'planar_normalization_analyzer'
require_relative 'tolerance'

module SUAnalysis
  module Core
    module PlanarNormalizationProposer
      module_function

      RULE_ID = 'planar_z_snap.v1'.freeze
      RULE_VERSION = '1'.freeze

      # Build a proposal from the current workspace.
      #
      # Returns the frozen Hash described above. When the
      # workspace is missing / not :ready / empty, returns
      # a NO_CANDIDATE result with the appropriate reason.
      def propose(workspace:, adapter:, tolerance:)
        if workspace.nil?
          return _fail(state: PlanarNormalizationAnalyzer::STATE_NO_CANDIDATE,
                       reason: 'no_workspace',
                       analyzer_result: nil,
                       tolerance: tolerance)
        end
        if workspace.state != :ready
          return _fail(state: PlanarNormalizationAnalyzer::STATE_NO_CANDIDATE,
                       reason: "workspace_not_ready:#{workspace.state}",
                       analyzer_result: nil,
                       tolerance: tolerance)
        end
        if adapter.nil?
          return _fail(state: PlanarNormalizationAnalyzer::STATE_NO_CANDIDATE,
                       reason: 'no_adapter',
                       analyzer_result: nil,
                       tolerance: tolerance)
        end
        tolerance = tolerance || Tolerance.default
        unless PlanarNormalizationAnalyzer.valid_tolerance?(tolerance.planar_z_snap)
          return _fail(state: PlanarNormalizationAnalyzer::STATE_INVALID_TOLERANCE,
                       reason: 'invalid_planar_z_snap',
                       analyzer_result: nil,
                       tolerance: tolerance)
        end
        unless PlanarNormalizationAnalyzer.valid_coordinate_epsilon?(tolerance.coordinate_epsilon)
          return _fail(state: PlanarNormalizationAnalyzer::STATE_INVALID_TOLERANCE,
                       reason: 'invalid_coordinate_epsilon',
                       analyzer_result: nil,
                       tolerance: tolerance)
        end
        # ---- Gather eligible vertices from derived edges ----
        edges_records = workspace.entities.select { |r|
          r.respond_to?(:kind) && r.kind == :edge
        }
        if edges_records.empty?
          return _fail(state: PlanarNormalizationAnalyzer::STATE_NO_CANDIDATE,
                       reason: 'no_derived_edges',
                       analyzer_result: nil,
                       tolerance: tolerance)
        end
        # Step A: per-edge safety + endpoint resolution.
        # We collect (record, edge_handle, [v0, v1], [s, e])
        # for each edge, OR note the safety reason. Edges
        # without resolvable endpoints OR with unsafe scope
        # are flagged.
        edge_data = []
        unsafe_edge_count = 0
        unresolved_endpoint_count = 0
        # First pass: build unsafe_lookup for every edge
        # (covers curve, face, missing handle, unresolved
        # endpoints, malformed geometry_summary). The same
        # checks below ALSO push to edge_data when the edge
        # is safe; we do the unsafe marking first so the
        # shared-vertex scope pass below can include unsafe
        # edges in its cluster map (Blueprint §6.4).
        unsafe_lookup = {}
        edges_records.each do |rec|
          did = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
          next if did.empty?
          edge_handle = workspace.handle_for(did)
          if edge_handle.nil?
            unsafe_lookup[did] = true
            next
          end
          safety = adapter.respond_to?(:edge_safety) ?
                     adapter.edge_safety(edge_handle) :
                     { 'safe' => true, 'reasons' => [].freeze }
          unless safety.is_a?(Hash) && safety['safe']
            unsafe_lookup[did] = true
            next
          end
          endpoints = adapter.respond_to?(:edge_endpoints) ?
                        adapter.edge_endpoints(edge_handle) :
                        nil
          unless endpoints.is_a?(Array) && endpoints.length == 2 &&
                 endpoints.all? { |v| !v.nil? }
            unsafe_lookup[did] = true
            next
          end
          gs = rec.respond_to?(:geometry_summary) ? rec.geometry_summary : {}
          s = gs['start']
          e = gs['end']
          unless s.is_a?(Array) && s.length == 3 && e.is_a?(Array) && e.length == 3
            unsafe_lookup[did] = true
            next
          end
        end
        # Second pass: build edge_data (only safe edges).
        edges_records.each do |rec|
          derived_id = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
          next if unsafe_lookup[derived_id]
          edge_handle = workspace.handle_for(derived_id)
          endpoints = adapter.respond_to?(:edge_endpoints) ?
                        adapter.edge_endpoints(edge_handle) :
                        nil
          gs = rec.respond_to?(:geometry_summary) ? rec.geometry_summary : {}
          s = gs['start']
          e = gs['end']
          unsafe_edge_count += 1 if unsafe_lookup[derived_id]
          unresolved_endpoint_count += 1 if endpoints.nil? ||
                                             !endpoints.is_a?(Array) ||
                                             endpoints.length != 2
          edge_data << {
            derived_id:    derived_id,
            edge_handle:   edge_handle,
            vertex_handles: [endpoints[0], endpoints[1]].freeze,
            positions:     [
              [s[0].to_f, s[1].to_f, s[2].to_f],
              [e[0].to_f, e[1].to_f, e[2].to_f]
            ].freeze,
            record:        rec
          }
        end
        # Update final counts from the first pass (covers
        # ALL unsafe edges, not just those we encountered
        # while iterating edges_records for edge_data).
        unsafe_edge_count = edges_records.count { |r|
          did = r.respond_to?(:derived_id) ? r.derived_id.to_s : ''
          unsafe_lookup[did]
        }
        unresolved_endpoint_count = unsafe_edge_count # we count all unsafe the same way for the audit
        # Step B: shared-vertex scope check.
        # A vertex is "shared" between two derived edges iff
        # both edges reference the SAME world-coord position.
        # We dedupe vertices by (x, y, z) tuple (rounded to
        # coordinate_epsilon-equivalent classes).
        #
        # IMPORTANT: we build vertex_to_edge_indices from
        # BOTH safe and unsafe edges so that a safe edge's
        # vertex can be flagged shared_with_unsafe because a
        # neighbor edge in the same vertex cluster is unsafe
        # (Blueprint §6.4). Edge 2 (curve membership) must
        # still participate in vertex clustering even though
        # it cannot contribute to the candidate set itself.
        eps = tolerance.coordinate_epsilon.to_f
        pos_key = ->(p) {
          # Round to a stable integer key for dedupe.
          [
            (p[0].to_f / eps).round,
            (p[1].to_f / eps).round,
            (p[2].to_f / eps).round
          ]
        }
        # Build (position_key) -> list of {edge_data_idx | nil}
        # where `nil` marks unsafe edges (kept as identity-only
        # markers for clustering, never used as candidates).
        all_edge_positions = []  # parallel to edges_records
        edges_records.each do |rec|
          did = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
          gs = rec.respond_to?(:geometry_summary) ? rec.geometry_summary : {}
          s = gs['start']
          e = gs['end']
          positions = if s.is_a?(Array) && s.length == 3 && e.is_a?(Array) && e.length == 3
                        [[s[0], s[1], s[2]], [e[0], e[1], e[2]]]
                      else
                        nil
                      end
          if unsafe_lookup[did]
            all_edge_positions << positions  # may be nil
          elsif positions
            all_edge_positions << positions
          else
            # Safe edge with malformed geometry; treat as unsafe
            # for clustering purposes (it cannot contribute to
            # candidates anyway since edge_data building
            # already filtered it).
            all_edge_positions << nil
          end
        end
        # Map edge_data_idx (compact, only safe edges) ->
        # corresponding all_edge_positions index.
        edge_data_idx_to_all_idx = {}
        all_idx = 0
        safe_idx = 0
        edges_records.each do |rec|
          did = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
          if unsafe_lookup[did]
            # unsafe edge: increment all_idx but not safe_idx
            all_idx += 1
          else
            # safe edge: both all_idx and safe_idx advance
            edge_data_idx_to_all_idx[safe_idx] = all_idx
            safe_idx += 1
            all_idx += 1
          end
        end
        # Build (position_key) -> list of safe edge_data indices
        # that share this vertex (BOTH safe and unsafe edges
        # contribute keys; we only mark safe edges as
        # shared_with_unsafe).
        vertex_to_edge_indices = {}
        all_edge_positions.each_with_index do |positions, all_i|
          next if positions.nil?
          positions.each do |pos|
            k = pos_key.call(pos)
            vertex_to_edge_indices[k] ||= []
            # Find the safe edge_data_idx (if any) for this all_i.
            safe_idx_for_this = edge_data_idx_to_all_idx.key(all_i)
            if safe_idx_for_this
              vertex_to_edge_indices[k] << safe_idx_for_this
            end
          end
        end
        # For each edge, count how many of its vertices are
        # "shared" (used by another edge). If any of its two
        # vertices is shared with an UNSAFE edge, the edge is
        # unsafe via shared-vertex scope (Blueprint §6.4).
        # Track per-edge: 'shared_with_unsafe' boolean.
        edge_data.each do |ed|
          ed[:shared_with_unsafe] = false
        end
        # First, mark unsafe edges by their derived_id list.
        unsafe_derived_ids = edges_records.map { |r|
          r.respond_to?(:derived_id) ? r.derived_id.to_s : nil
        }.compact.to_set rescue nil
        # Now flag shared-with-unsafe.
        # A cluster is unsafe iff ANY edge contributing a
        # vertex to it (safe OR unsafe) appears in
        # unsafe_lookup. We track this via a parallel
        # all-edges cluster map built from all_edge_positions.
        all_vertex_to_all_edge_indices = {}
        all_edge_positions.each_with_index do |positions, all_i|
          next if positions.nil?
          positions.each do |pos|
            k = pos_key.call(pos)
            all_vertex_to_all_edge_indices[k] ||= []
            all_vertex_to_all_edge_indices[k] << all_i
          end
        end
        vertex_to_edge_indices.each do |k, edge_indices|
          all_indices = all_vertex_to_all_edge_indices[k] || []
          # unsafe_present: any ALL-edges-index in the cluster
          # corresponds to an unsafe edge.
          unsafe_in_cluster = all_indices.any? { |ai| unsafe_lookup[edges_records[ai].respond_to?(:derived_id) ? edges_records[ai].derived_id.to_s : ''] }
          next unless unsafe_in_cluster
          edge_indices.each do |idx|
            ed = edge_data[idx]
            unless unsafe_lookup[ed[:derived_id]]
              ed[:shared_with_unsafe] = true
            end
          end
        end
        # Step C: build the candidate vertex list.
        # A vertex is "candidate" iff:
        #   (a) it belongs to a SAFE edge (not in unsafe_lookup);
        #   (b) its cluster has NO unsafe edge in it (otherwise
        #       shared-vertex scope is ambiguous).
        # We process each edge's two vertices; we dedupe by
        # position_key.
        candidate_positions = []
        candidate_records = []   # parallel: per-position, the list of edge derived_ids
        seen_keys = {}
        edge_data.each do |ed|
          next if unsafe_lookup[ed[:derived_id]]
          next if ed[:shared_with_unsafe]
          ed[:positions].each_with_index do |pos, vi|
            k = pos_key.call(pos)
            if seen_keys.key?(k)
              # Already a candidate; record the second edge's
              # derived_id for audit (mutable list, dedup).
              existing_ids = candidate_records[seen_keys[k]][:derived_ids]
              unless existing_ids.include?(ed[:derived_id])
                existing_ids << ed[:derived_id]
              end
              next
            end
            seen_keys[k] = candidate_positions.length
            candidate_positions << pos
            candidate_records << {
              vertex_handle:  ed[:vertex_handles][vi],
              derived_ids:    [ed[:derived_id]],
              source_occurrence_ids: (ed[:record].respond_to?(:source_occurrence_ids) ?
                                        Array(ed[:record].source_occurrence_ids) :
                                        []).map(&:to_s)
            }
          end
        end
        if candidate_positions.empty?
          return _fail(state: PlanarNormalizationAnalyzer::STATE_REVIEW_REQUIRED,
                       reason: 'no_safe_eligible_vertices',
                       analyzer_result: nil,
                       tolerance: tolerance,
                       shared_vertex_skipped: edge_data.count { |ed| ed[:shared_with_unsafe] },
                       unsafe_edge_count: unsafe_edge_count,
                       unresolved_endpoint_count: unresolved_endpoint_count
                      )
        end
        # ---- Run the pure analyzer ----
        analyzer_result = PlanarNormalizationAnalyzer.analyze(
          eligible_vertices:   candidate_positions,
          planar_z_snap:       tolerance.planar_z_snap.to_f,
          coordinate_epsilon:  tolerance.coordinate_epsilon.to_f
        )
        case analyzer_result[:state]
        when PlanarNormalizationAnalyzer::STATE_NO_CANDIDATE
          return _wrap_no_candidate(analyzer_result, tolerance)
        when PlanarNormalizationAnalyzer::STATE_REVIEW_REQUIRED
          return _wrap_review_required(analyzer_result, tolerance,
                                      shared_vertex_skipped: edge_data.count { |ed| ed[:shared_with_unsafe] },
                                      unsafe_edge_count: unsafe_edge_count)
        when PlanarNormalizationAnalyzer::STATE_INVALID_TOLERANCE,
             PlanarNormalizationAnalyzer::STATE_INVALID_INPUT
          return _wrap_invalid(analyzer_result, tolerance)
        end
        # READY_TO_NORMALIZE: build the host mutation plan.
        target_z = analyzer_result[:target_z].to_f
        proposed_moves = analyzer_result[:proposed_moves]
        # Each proposed_move carries `vertex_index` (index into
        # candidate_positions). Resolve to vertex_handle +
        # affected derived ids.
        unique_vertex_handles = []
        unique_vertex_records = []
        vectors = []
        affected_derived_ids = []
        affected_source_occurrence_ids = []
        proposed_moves.each do |m|
          idx = m[:vertex_index]
          vrec = candidate_records[idx]
          vh = vrec[:vertex_handle]
          next if vh.nil?
          # Dedup the vertex handles by identity (the analyzer
          # already deduped positions; we mirror).
          if unique_vertex_handles.include?(vh)
            # Still record the additional derived ids for the
            # audit row.
            vrec[:derived_ids].each do |did|
              affected_derived_ids << did unless affected_derived_ids.include?(did)
            end
            vrec[:source_occurrence_ids].each do |soid|
              affected_source_occurrence_ids << soid unless affected_source_occurrence_ids.include?(soid)
            end
            next
          end
          unique_vertex_handles << vh
          unique_vertex_records << vrec
          vectors << [0.0, 0.0, (target_z - m[:from_z].to_f).to_f]
          vrec[:derived_ids].each do |did|
            affected_derived_ids << did unless affected_derived_ids.include?(did)
          end
          vrec[:source_occurrence_ids].each do |soid|
            affected_source_occurrence_ids << soid unless affected_source_occurrence_ids.include?(soid)
          end
        end
        # Outlier audit: list the derived_ids of edges that
        # belong to the outlier positions.
        outlier_indices = analyzer_result[:outliers].map { |o| o[:vertex_index] }
        outlier_derived_ids = []
        outlier_indices.each do |idx|
          next if idx >= candidate_records.length
          candidate_records[idx][:derived_ids].each do |did|
            outlier_derived_ids << did unless outlier_derived_ids.include?(did)
          end
        end
        proposal = {
          target_z:                       target_z.to_f,
          unique_vertex_handles:         unique_vertex_handles.freeze,
          unique_vertex_records:         unique_vertex_records.freeze,
          vectors:                        vectors.freeze,
          affected_derived_ids:          affected_derived_ids.uniq.freeze,
          affected_source_occurrence_ids: affected_source_occurrence_ids.uniq.freeze,
          shared_vertex_scope_skipped:   edge_data.count { |ed| ed[:shared_with_unsafe] },
          outlier_derived_ids:           outlier_derived_ids.uniq.freeze,
          outlier_count:                 analyzer_result[:outlier_count],
          eligible_count:                analyzer_result[:eligible_count],
          already_planar:                analyzer_result[:already_planar],
          movable_count:                 analyzer_result[:movable_count],
          max_movement:                   analyzer_result[:max_movement].to_f,
          tolerance_used:                analyzer_result[:tolerance_used].to_f
        }.freeze
        {
          state:           analyzer_result[:state],
          analyzer_result: analyzer_result,
          proposal:        proposal,
          reason:          nil,
          captured_tolerance: {
            planar_z_snap:      tolerance.planar_z_snap.to_f,
            coordinate_epsilon: tolerance.coordinate_epsilon.to_f
          }.freeze,
          captured_at:      DEFAULT_TIMESTAMP,
          rule_id:          RULE_ID,
          rule_version:     RULE_VERSION
        }.freeze
      end

      # ---- internal result builders ----

      def _fail(state:, reason:, analyzer_result:, tolerance:, **extra)
        out = {
          state:           state,
          analyzer_result: analyzer_result,
          proposal:        nil,
          reason:          reason,
          captured_tolerance: {
            planar_z_snap:      tolerance.respond_to?(:planar_z_snap) ? tolerance.planar_z_snap.to_f : nil,
            coordinate_epsilon: tolerance.respond_to?(:coordinate_epsilon) ? tolerance.coordinate_epsilon.to_f : nil
          }.freeze,
          captured_at:      DEFAULT_TIMESTAMP,
          rule_id:          RULE_ID,
          rule_version:     RULE_VERSION
        }
        out[:shared_vertex_skipped]   = extra[:shared_vertex_skipped]   if extra.key?(:shared_vertex_skipped)
        out[:unsafe_edge_count]       = extra[:unsafe_edge_count]       if extra.key?(:unsafe_edge_count)
        out[:unresolved_endpoint_count] = extra[:unresolved_endpoint_count] if extra.key?(:unresolved_endpoint_count)
        out.freeze
      end

      def _wrap_no_candidate(analyzer_result, tolerance)
        {
          state:           analyzer_result[:state],
          analyzer_result: analyzer_result,
          proposal:        nil,
          reason:          analyzer_result[:reason],
          captured_tolerance: {
            planar_z_snap:      tolerance.planar_z_snap.to_f,
            coordinate_epsilon: tolerance.coordinate_epsilon.to_f
          }.freeze,
          captured_at:      DEFAULT_TIMESTAMP,
          rule_id:          RULE_ID,
          rule_version:     RULE_VERSION
        }.freeze
      end

      def _wrap_review_required(analyzer_result, tolerance, shared_vertex_skipped:, unsafe_edge_count:)
        {
          state:           analyzer_result[:state],
          analyzer_result: analyzer_result,
          proposal:        nil,
          reason:          analyzer_result[:reason],
          shared_vertex_skipped: shared_vertex_skipped,
          unsafe_edge_count:     unsafe_edge_count,
          captured_tolerance: {
            planar_z_snap:      tolerance.planar_z_snap.to_f,
            coordinate_epsilon: tolerance.coordinate_epsilon.to_f
          }.freeze,
          captured_at:      DEFAULT_TIMESTAMP,
          rule_id:          RULE_ID,
          rule_version:     RULE_VERSION
        }.freeze
      end

      def _wrap_invalid(analyzer_result, tolerance)
        {
          state:           analyzer_result[:state],
          analyzer_result: analyzer_result,
          proposal:        nil,
          reason:          analyzer_result[:reason],
          captured_tolerance: {
            planar_z_snap:      tolerance.planar_z_snap.to_f,
            coordinate_epsilon: tolerance.coordinate_epsilon.to_f
          }.freeze,
          captured_at:      DEFAULT_TIMESTAMP,
          rule_id:          RULE_ID,
          rule_version:     RULE_VERSION
        }.freeze
      end

      def self.default_timestamp
        DEFAULT_TIMESTAMP
      end
      DEFAULT_TIMESTAMP = '1970-01-01T00:00:00Z'.freeze
    end
  end
end
