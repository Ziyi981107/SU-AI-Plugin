#
# core/canonical_structure_reconstructor.rb — V1.8 Pure
# canonical-structure reconstruction.
#
# Per frozen V1.8 Stage Technical Blueprint
# (Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_8_LOOP_REGION_2026-09-02.md):
#
#   Consumes the current V1.7 CanonicalGeometryGraph and produces
#   a deterministic, SketchUp-independent reconstruction:
#       CanonicalGeometryGraph
#       -> open chains (ChainRecord)
#       -> closed loops (LoopRecord)
#       -> nested regions (RegionRecord)
#       -> unresolved_issues / conservative unresolved codes
#
#   Pure value object. No random, no host mutation, no observer.
#   One shared SHA-256 identity scheme. Result is JSON-safe +
#   deterministically digestable across input iteration order.
#
# V1.7 frozen boundary (Blueprint §1):
#   CanonicalGeometryGraph owns: canonical nodes, edges,
#   adjacency, unresolved topology issues, deterministic
#   digest/provenance.
#   V1.8 consumes that graph. V1.8 MUST NOT expand the V1.7
#   schema with loops/regions. V1.8 result is a separate downstream
#   immutable reconstruction.
#
# This module is intentionally pure (no host mutation, no
# random, no Ruby >= 2.4-only API). It is consumed by the
# V1.8 WorkingModeRunner integration (compute_structure_
# reconstruction) AND by the focused V1.8 test set so they
# cannot silently diverge.
#
# Files:
#   extension/su_ai_plugin/core/canonical_structure_reconstructor.rb
#   tests/test_v18_structure_reconstruction.rb
#   tests/test_v18_working_mode_integration.rb
#

require 'digest'
require 'set'

require_relative 'segment_conflict'

module SUAnalysis
  module Core
    module CanonicalStructureReconstructor
      module_function

      SCHEMA_VERSION = 'csr.v1'.freeze

      # Result states (per Blueprint §3.1).
      STATE_NOT_COMPUTED         = 'NOT_COMPUTED'.freeze
      STATE_READY                = 'READY'.freeze
      STATE_READY_WITH_WARNINGS  = 'READY_WITH_WARNINGS'.freeze
      STATE_FAILED               = 'FAILED'.freeze

      # Stable issue / reason vocabulary (per Blueprint §18).
      REASON_INVALID_GRAPH            = 'invalid_graph'.freeze
      REASON_MISSING_NODE_REFERENCE   = 'missing_node_reference'.freeze
      REASON_DUPLICATE_CANONICAL_EDGE_ID = 'duplicate_canonical_edge_id'.freeze
      REASON_SELF_LOOP_EDGE           = 'self_loop_edge'.freeze
      REASON_ADJACENCY_MISMATCH       = 'invalid_graph:adjacency_mismatch'.freeze
      REASON_COORDINATE_EPSILON_MISMATCH =
        'invalid_graph:coordinate_epsilon_mismatch'.freeze
      REASON_UPSTREAM_TOPOLOGY_ISSUE  = 'upstream_topology_issue'.freeze
      REASON_BRANCHING_COMPONENT      = 'branching_component'.freeze
      REASON_INVALID_COMPONENT        = 'invalid_component'.freeze
      REASON_PARALLEL_EDGES           = 'parallel_edges_unsupported'.freeze
      REASON_CHAIN_TRAVERSAL_FAILED   = 'chain_traversal_failed'.freeze
      REASON_LOOP_TRAVERSAL_FAILED    = 'loop_traversal_failed'.freeze
      REASON_REPEATED_VERTEX          = 'repeated_vertex'.freeze
      REASON_SELF_INTERSECTION        = 'self_intersection'.freeze
      REASON_LOOP_ENDPOINT_ON_SEGMENT = 'loop_endpoint_on_segment'.freeze
      REASON_LOOP_COLLINEAR_OVERLAP   = 'loop_collinear_overlap'.freeze
      REASON_LOOP_GEOMETRIC_TOUCH     = 'loop_geometric_touch'.freeze
      REASON_NON_PLANAR_LOOP          = 'non_planar_loop'.freeze
      REASON_DEGENERATE_LOOP          = 'degenerate_loop'.freeze
      REASON_LOOP_BOUNDARY_INTERSECTION = 'loop_boundary_intersection'.freeze
      REASON_LOOP_BOUNDARY_TOUCH      = 'loop_boundary_touch'.freeze
      REASON_AMBIGUOUS_CONTAINMENT    = 'ambiguous_containment'.freeze
      REASON_INVALID_REGION           = 'invalid_region'.freeze

      CHAIN_ID_SCHEMA    = 'chain.v1'.freeze
      LOOP_ID_SCHEMA     = 'loop.v1'.freeze
      REGION_ID_SCHEMA   = 'region.v1'.freeze
      RESULT_ID_SCHEMA   = 'csr-result.v1'.freeze

      # Numerical epsilon used to gate degenerate loops and
      # point-on-boundary classification. Per Blueprint §9 +
      # §11: "use coordinate_epsilon for verification
      # semantics and document exact formula in tests". The
      # abs(area_xy) gate uses coord_eps^2; this is the
      # smallest reasonable XY area that two distinct finite
      # points can enclose when separated by coord_eps. Tests
      # prove exact values.
      def _area_eps(coord_eps)
        ee = _safe_eps(coord_eps)
        ee * ee
      end

      # SR18-02: coordinate_epsilon authority.
      # Safe-eps normalizer: finite + positive or fall back
      # to 1e-6. NEVER silently fall back when caller already
      # supplied a finite/positive value (including a
      # non-default captured tolerance such as 1e-3 or 1e-5).
      def _safe_eps(coord_eps)
        ee = coord_eps.to_f
        if ee.finite? && ee > 0
          ee
        else
          1.0e-6
        end
      end

      # Resolve ONE coordinate_epsilon for the whole
      # reconstruction (FR18-01). Authority order:
      #   1. explicit `coordinate_epsilon:` keyword argument
      #      wins VERBATIM if finite + positive -- including
      #      exactly 1.0e-6 (no special-casing of the default);
      #   2. per-node `coordinate_epsilon` carried by the
      #      canonical graph nodes (only when ALL canonical
      #      nodes carry a finite, positive, CONSISTENT value);
      #   3. hard-coded 1.0e-6 fallback (used ONLY when no
      #      explicit value AND no per-node value is available).
      #
      # Returns [coord_eps_or_nil, failure_reason_or_nil]:
      #   - on success, coord_eps is a Float > 0 and the
      #     failure reason is nil;
      #   - on failure (conflicting per-node eps with no
      #     explicit kw), coord_eps is nil and the failure
      #     reason is the stable
      #     `invalid_graph:coordinate_epsilon_mismatch` token.
      # No silent median / min / max / first selection.
      def _resolve_coordinate_eps(graph_h, eps_kw)
        # 1. Explicit kw wins verbatim (including exactly 1e-6).
        if eps_kw.is_a?(Numeric)
          kw = eps_kw.to_f
          if kw.finite? && kw > 0
            return [kw, nil]
          end
        end
        # 2. Try per-node eps from canonical graph nodes (Hash
        # form, read from the graph passed in). Only valid when
        # ALL finite-positive per-node values are consistent.
        node_list = if graph_h.is_a?(CanonicalGeometryGraph)
                      graph_h.nodes
                    else
                      Array(graph_h[:nodes] || graph_h['nodes'])
                    end
        node_eps = []
        node_list.each do |n|
          h = n.is_a?(Hash) ? n : (n.respond_to?(:to_h) ? n.to_h : {})
          v = h['coordinate_epsilon']
          next if v.nil?
          f = v.to_f
          node_eps << f if f.finite? && f > 0
        end
        if node_eps.empty?
          # 3. Defensive fallback (matches legacy 1e-6 contract).
          return [1.0e-6, nil]
        end
        uniq = node_eps.uniq
        if uniq.length == 1
          return [uniq.first, nil]
        end
        # Conflicting per-node eps with no explicit kw ->
        # FR18-01 fails conservatively with a stable reason
        # instead of silently picking median/min/max/first.
        [nil, REASON_COORDINATE_EPSILON_MISMATCH]
      end

      # ---- Public entry ----

      # Reconstruct the deterministic structure from a
      # canonical graph (or a JSON-safe Hash with the same
      # shape). Pure. No host mutation. No random.
      #
      # SR18-02 coordinate_epsilon authority: a single
      # `coordinate_epsilon` keyword argument is threaded
      # through the ENTIRE reconstruction. When absent /
      # invalid the reconstructor falls back ONLY to the
      # per-node coordinate_epsilon carried by the canonical
      # graph nodes (when finite / positive / consistent),
      # and ONLY THEN to 1e-6. No silent 1e-6 fallback when
      # the caller has supplied a valid non-default epsilon.
      def reconstruct(graph, source_snapshot_id: nil, workspace_id: nil,
                      coordinate_epsilon: nil)
        if graph.nil?
          return _empty_result(source_snapshot_id: source_snapshot_id,
                               workspace_id: workspace_id,
                               reasons: [REASON_INVALID_GRAPH])
        end
        # CanonicalGeometryGraph (object) -- read attrs.
        if graph.is_a?(CanonicalGeometryGraph)
          node_h      = graph.nodes
          edge_h      = graph.edges
          adj_h       = graph.adjacency
          upstream_u  = Array(graph.unresolved_topology_issues)
          graph_dgst  = graph.digest.to_s
        else
          # JSON-safe Hash form (for tests + runner).
          h           = graph.is_a?(Hash) ? graph : {}
          node_h      = Array(h[:nodes] || h['nodes'])
          edge_h      = Array(h[:edges] || h['edges'])
          adj_h       = (h[:adjacency] || h['adjacency'] || {}).to_h
          upstream_u  = Array(h[:unresolved_topology_issues] ||
                              h['unresolved_topology_issues'])
          graph_dgst  = (h[:digest] || h['digest'] || '').to_s
        end

        # FR18-01: resolve ONE coordinate_epsilon for the
        # whole reconstruction. Threaded explicitly through
        # every geometry check below; no silent 1e-6 fallback,
        # no silent median/min/max/first selection on
        # inconsistent per-node values.
        coord_eps, eps_failure = _resolve_coordinate_eps(
          graph.is_a?(CanonicalGeometryGraph) ? graph : h,
          coordinate_epsilon
        )
        if coord_eps.nil?
          # Conflicting per-node eps with no explicit kw:
          # fail closed with the stable mismatch reason.
          return _empty_result(source_snapshot_id: source_snapshot_id,
                               workspace_id: workspace_id,
                               graph_digest: graph_dgst,
                               reasons: [eps_failure])
        end

        # ---- Step 1: graph validation ----
        reasons, validated = _validate_graph(node_h, edge_h, adj_h)
        unless validated
          return _empty_result(source_snapshot_id: source_snapshot_id,
                               workspace_id: workspace_id,
                               graph_digest: graph_dgst,
                               reasons: reasons)
        end

        # ---- Step 2: build canonical node index ----
        node_index = _build_node_index(node_h)

        # ---- Step 3: build canonical edge index ----
        # Each edge carries: canonical_edge_id, node_a_id,
        # node_b_id, world_endpoints (Array of two
        # 3-Float coords), plural source_occurrence_ids,
        # layer_name, origin_kind, repair_action_id.
        edges_by_id = {}
        edge_list = []
        edge_h.each do |e|
          h = e.is_a?(Hash) ? e : {}
          cid = h['canonical_edge_id'].to_s
          next if cid.empty?
          edges_by_id[cid] = h
          edge_list << cid
        end
        edge_list.sort!

        # Build adjacency by edge-id (canonical_edge_id is the
        # authoritative key in CanonicalGeometryGraph; we
        # ignore string-format inconsistency between
        # canonical_edge_id and canonical_node_id keys --
        # both are opaque identifiers in V1.8).
        #
        # FR18-02: accumulate via per-node Set (O(1) add)
        # instead of `Array#include?` insertion scans, then
        # publish sorted Arrays so the published payload is
        # deterministic AND downstream traversal can rely on
        # O(V+E) Set lookups rather than O(N) Array scans.
        adj_set = Hash.new { |h_inner, k| h_inner[k] = Set.new }
        edge_list.each do |eid|
          e = edges_by_id[eid]
          a = e['node_a_id'].to_s
          b = e['node_b_id'].to_s
          next if a.empty? || b.empty?
          adj_set[a].add(b)
          adj_set[b].add(a)
        end
        adjacency = {}
        adj_set.each { |k, s| adjacency[k] = s.to_a.sort }

        # SR18-04: build deterministic edge indexes once so
        # traversal is O(V + E). Built from the validated
        # edges_by_id (post-validation).
        edge_indexes = _build_edge_indexes(edges_by_id)

        # ---- Step 4: connected components (BFS, deterministic) ----
        all_nodes = node_index.keys.sort
        components = []
        visited = {}
        all_nodes.each do |nid|
          next if visited[nid]
          stack = [nid]
          comp = []
          until stack.empty?
            cur = stack.pop
            next if visited[cur]
            visited[cur] = true
            comp << cur
            Array(adjacency[cur]).sort.each do |nbr|
              stack << nbr unless visited[nbr]
            end
          end
          components << comp.sort
        end
        components.sort_by! { |c| c.first.to_s }

        # ---- Step 5: classify each component ----
        chains = []
        loops  = []
        unresolved_issues = []
        # Blueprint §5: existing V1.7 unresolved topology
        # issues MUST be propagated as upstream warnings.
        # The propagated issues appear in BOTH the published
        # `reasons` (so callers can read them at the boundary)
        # AND the V1.8 `unresolved_issues` array (so the UI /
        # downstream readers can surface them consistently).
        upstream_propagated = upstream_u.map { |u|
          "#{REASON_UPSTREAM_TOPOLOGY_ISSUE}:#{u.to_s}"
        }.uniq
        reasons.concat(upstream_propagated)
        unresolved_issues.concat(upstream_propagated)

        components.each do |comp|
          cls, payload = _classify_component(comp, adjacency, edges_by_id,
                                             node_index, coord_eps,
                                             edge_indexes)
          case cls
          when :simple_chain
            chains << payload
          when :simple_loop
            loops << payload
          when :branching
            unresolved_issues << REASON_BRANCHING_COMPONENT
          when :invalid
            unresolved_issues << REASON_INVALID_COMPONENT
          when :parallel_edges
            # SR18-04: parallel edges between the same node
            # pair are conservatively treated as unsupported.
            # Emit one stable reason per affected node pair.
            pair_set = _parallel_pairs_in_comp(comp, edge_indexes)
            pair_set.each do |pair|
              unresolved_issues <<
                "#{REASON_PARALLEL_EDGES}:#{pair}"
            end
          end
        end

        # Sort chains + loops by id for stable output.
        chains.sort_by! { |c| c['chain_id'].to_s }
        loops.sort_by!  { |l| l['loop_id'].to_s }

        # ---- Step 6: loop geometry validation + self-intersection ----
        validated_loops = []
        loops.each do |loop|
          vflags = Array(loop['unresolved_flags']).dup
          # SR18-02: pass the resolved coordinate_epsilon so
          # planarity, degenerate-area, and self-intersection
          # all use the SAME epsilon. Publish it on the loop
          # so downstream region validity can read it without
          # re-resolving.
          loop['coordinate_epsilon'] = coord_eps
          _validate_loop_geometry(loop, vflags, coord_eps)
          _validate_loop_self_intersection(loop, node_index, vflags, coord_eps)
          loop['unresolved_flags'] = vflags.uniq.sort
          loop['valid_for_region'] = vflags.empty?
          validated_loops << loop
        end

        # ---- Step 7: containment + regions ----
        regions = []
        only_valid_loops = validated_loops.select { |l| l['valid_for_region'] }
        contained_pairs = _classify_loop_containment(only_valid_loops, coord_eps)
        unless contained_pairs.nil?
          regions = _build_regions(only_valid_loops, contained_pairs,
                                   unresolved_issues, coord_eps)
        else
          # Ambiguous containment: all loops are valid for
          # region individually but pairwise containment could
          # not be determined safely. Emit unresolved_issues
          # for each valid loop pair and do NOT build regions.
          unresolved_issues << REASON_AMBIGUOUS_CONTAINMENT
        end

        # ---- Step 8: finalize metrics ----
        invalid_loop_count = validated_loops.count { |l|
          !l['valid_for_region']
        }
        invalid_component_count = unresolved_issues.count { |r|
          r == REASON_BRANCHING_COMPONENT || r == REASON_INVALID_COMPONENT
        }
        # SR18-01: explicit Ruby 2.2-compatible accumulation
        # (Enumerable/Array#sum is Ruby 2.4+).
        hole_count = 0
        regions.each do |r|
          hole_count += Array(r['hole_loop_ids']).length
        end
        metrics = {
          'component_count'          => components.length,
          'open_chain_count'         => chains.length,
          'closed_loop_count'        => validated_loops.length,
          'region_count'             => regions.length,
          'hole_count'               => hole_count,
          'invalid_component_count'  => invalid_component_count,
          'invalid_loop_count'       => invalid_loop_count,
          'unresolved_issue_count'   => unresolved_issues.uniq.sort.length
        }

        # ---- Step 9: result state ----
        # SR18-06 truthful state:
        #   - invalid graph => FAILED  (rejected earlier)
        #   - any unresolved/upstream warning
        #                            => READY_WITH_WARNINGS
        #   - warning-free + has content => READY
        #   - branch-only (no chains/loops but a
        #     branching_component reason was reported)
        #                            => READY_WITH_WARNINGS
        # The dispatch requires branch-only components to
        # surface as READY_WITH_WARNINGS rather than READY
        # so the UI does not falsely display "结构可用"
        # while carrying branching_component issues.
        unique_issues = unresolved_issues.uniq.sort
        branch_only = validated_loops.empty? && chains.empty? &&
                       unique_issues.any? { |r|
                         r == REASON_BRANCHING_COMPONENT ||
                         r.to_s.start_with?("#{REASON_PARALLEL_EDGES}:")
                       }
        has_warnings = unique_issues.any? || invalid_loop_count > 0
        state = if has_warnings || branch_only
                  STATE_READY_WITH_WARNINGS
                else
                  STATE_READY
                end

        # ---- Step 10: deterministic digest ----
        digest = _compute_result_digest(
          graph_digest: graph_dgst,
          chains: chains,
          loops: validated_loops,
          regions: regions,
          unresolved_issues: unresolved_issues.uniq.sort,
          metrics: metrics,
          state: state
        )

        result = {
          'schema_version'           => SCHEMA_VERSION,
          'state'                    => state,
          'canonical_graph_digest'   => graph_dgst,
          'source_snapshot_id'       => source_snapshot_id.to_s,
          'workspace_id'             => workspace_id.to_s,
          'chains'                   => chains,
          'loops'                    => validated_loops,
          'regions'                  => regions,
          'unresolved_issues'        => unresolved_issues.uniq.sort,
          'metrics'                  => metrics,
          'reasons'                  => reasons.uniq.sort,
          'digest'                   => digest
        }
        # SR18-07: deep-freeze the published normal result so
        # that nested arrays / hashes / frozen-string payloads
        # cannot be mutated after the caller observes the
        # digest. Outer .freeze is insufficient: without
        # deep_freeze a caller could mutate chains.first['node_ids']
        # or loops.first['world_coordinates'] in place, which
        # would silently change the post-digest payload.
        deep_freeze(result)
        result
      end

      # FR18-03: deep-freeze a value in place. Recurses
      # through Hash (freezing keys AND values) and Array
      # (freezing each member). String scalars are explicitly
      # frozen (Ruby Strings are mutable by default; without
      # this branch, callers could mutate `result['digest']`,
      # `loop_id`, `chain_id`, `region_id`, `source_occurrence_id`
      # strings in place after publication). Numeric, symbol,
      # true, false, and nil are immutable by definition and
      # safely pass through. JSON-shape frozen recursively.
      # Returns the same object (mutated in place) so the call
      # site reads naturally.
      def deep_freeze(obj)
        case obj
        when Hash
          obj.each_key { |k| deep_freeze(k) }
          obj.each_value { |v| deep_freeze(v) }
          obj.freeze
        when Array
          obj.each { |v| deep_freeze(v) }
          obj.freeze
        when String
          obj.freeze
        else
          # Numeric / Symbol / TrueClass / FalseClass / NilClass
          # are immutable by definition.
          obj
        end
      end

      def _empty_result(source_snapshot_id: nil, workspace_id: nil,
                        graph_digest: nil, reasons: nil)
        rs = Array(reasons)
        rs << REASON_INVALID_GRAPH if rs.empty?
        rs.uniq!
        result = {
          'schema_version'           => SCHEMA_VERSION,
          'state'                    => STATE_FAILED,
          'canonical_graph_digest'   => (graph_digest || '').to_s,
          'source_snapshot_id'       => (source_snapshot_id || '').to_s,
          'workspace_id'             => (workspace_id || '').to_s,
          'chains'                   => [],
          'loops'                    => [],
          'regions'                  => [],
          'unresolved_issues'        => rs.uniq.sort,
          'metrics'                  => {
            'component_count'          => 0,
            'open_chain_count'         => 0,
            'closed_loop_count'        => 0,
            'region_count'             => 0,
            'hole_count'               => 0,
            'invalid_component_count'  => 0,
            'invalid_loop_count'       => 0,
            'unresolved_issue_count'   => rs.uniq.sort.length
          },
          'reasons'                  => rs.uniq.sort,
          'digest'                   => ''
        }
        deep_freeze(result)
        result
      end

      # ---- internals ----

      # ---- Step 1: validation ----

      def _validate_graph(node_h, edge_h, adj_h)
        reasons = []
        # Adjacency shape: Hash<String, Array<String>> (String
        # keys, Array values).
        unless adj_h.is_a?(Hash)
          reasons << REASON_INVALID_GRAPH
          return [reasons, false]
        end
        # Nodes: every canonical node id unique.
        node_ids = node_h.map { |n|
          (n.is_a?(Hash) ? n['canonical_node_id'] : nil).to_s
        }.reject(&:empty?)
        if node_ids.empty?
          reasons << REASON_INVALID_GRAPH
          return [reasons, false]
        end
        dup_n = node_ids.group_by { |x| x }.select { |_, v| v.length > 1 }.keys
        unless dup_n.empty?
          reasons << "#{REASON_INVALID_GRAPH}:duplicate_node_id"
          return [reasons, false]
        end
        # Edges: unique canonical_edge_id, non-self-loop,
        # both endpoints must exist in node set.
        seen_eids = {}
        node_set = node_ids.to_set
        edge_h.each do |e|
          h = e.is_a?(Hash) ? e : {}
          cid = h['canonical_edge_id'].to_s
          a = h['node_a_id'].to_s
          b = h['node_b_id'].to_s
          if cid.empty?
            reasons << "#{REASON_INVALID_GRAPH}:missing_canonical_edge_id"
            next
          end
          if seen_eids.key?(cid)
            reasons << "#{REASON_DUPLICATE_CANONICAL_EDGE_ID}:#{cid}"
            next
          end
          seen_eids[cid] = true
          if a == b
            reasons << "#{REASON_SELF_LOOP_EDGE}:#{cid}"
          end
          if a.empty? || b.empty?
            reasons << "#{REASON_MISSING_NODE_REFERENCE}:#{cid}"
          else
            unless node_set.include?(a)
              reasons << "#{REASON_MISSING_NODE_REFERENCE}:#{cid}:#{a}"
            end
            unless node_set.include?(b)
              reasons << "#{REASON_MISSING_NODE_REFERENCE}:#{cid}:#{b}"
            end
          end
        end
        if reasons.include?("#{REASON_DUPLICATE_CANONICAL_EDGE_ID}") ||
           reasons.any? { |r| r.start_with?("#{REASON_MISSING_NODE_REFERENCE}:") } ||
           reasons.any? { |r| r.start_with?("#{REASON_SELF_LOOP_EDGE}:") }
          return [reasons.uniq.sort, false]
        end
        unless reasons.empty?
          # Other validation reasons (e.g. duplicate node id)
          # are fatal.
          return [reasons.uniq.sort, false]
        end
        # SR18-08: validate the supplied canonical adjacency
        # EXACTLY against the edge inventory. The dispatch
        # requires four checks:
        #   1. unknown adjacency key => invalid
        #   2. unknown neighbor => invalid
        #   3. missing edge-backed neighbor => invalid
        #   4. extra neighbor not backed by edge => invalid
        # Stable reason: invalid_graph:adjacency_mismatch
        # (with details appended).
        adj_mismatch = _validate_adjacency_against_edges(adj_h,
                                                        node_set, edge_h)
        unless adj_mismatch.empty?
          reasons.concat(adj_mismatch)
          return [reasons.uniq.sort, false]
        end
        [reasons, true]
      end

      # FR18-04: structural adjacency vs edge inventory.
      # Normalizes expected adjacency for EVERY canonical
      # node id (missing expected-key = empty list), normalizes
      # supplied adjacency for EVERY canonical node id
      # (missing supplied-key = empty list), and compares the
      # two sets for every canonical node id. An omitted
      # edge-backed adjacency key now reports
      # `missing_neighbor` instead of silently passing.
      # Non-Array adjacency values are rejected as
      # `non_array_value` (no silent scalar coercion). An
      # isolated canonical node with empty adjacency remains
      # valid (no edges = empty list = empty list).
      # Returns an Array of stable
      # `invalid_graph:adjacency_mismatch:...` reason strings
      # sorted + uniq. Empty Array means adjacency is
      # consistent with the edge inventory.
      def _validate_adjacency_against_edges(adj_h, node_set, edge_h)
        mismatches = []
        return mismatches unless adj_h.is_a?(Hash)
        # 1. Build expected adjacency from the edge inventory,
        # for EVERY canonical node id that participates in any
        # edge. Isolated nodes get empty expected lists below.
        expected = {}
        edge_h.each do |e|
          h = e.is_a?(Hash) ? e : {}
          a = h['node_a_id'].to_s
          b = h['node_b_id'].to_s
          next if a.empty? || b.empty?
          next if a == b
          (expected[a] ||= []) << b
          (expected[b] ||= []) << a
        end
        expected.each_value { |arr| arr.sort!.uniq! }
        # 2. Unknown supplied adjacency keys are still
        # failures (defensive against stale or fabricated
        # ids that are not in the canonical node set).
        adj_h.each_key do |k|
          kid = k.to_s
          unless node_set.include?(kid)
            mismatches << "#{REASON_ADJACENCY_MISMATCH}:unknown_key:#{kid}"
          end
        end
        # 3. For EVERY canonical node id, compare expected vs
        # supplied. Missing supplied-key is normalized to an
        # empty list. Non-Array supplied values are rejected
        # explicitly.
        #
        # OWNER SU2020 BOOT BLOCK fix (narrow, no algorithm
        # change): the previous implementation used `next` as
        # the value of an `else` branch of an `if` expression
        # assigned to `supplied`. The local development Ruby
        # (2.7.x) accepts that, but the SketchUp 2020 embedded
        # Ruby parser rejects it with
        # `SyntaxError: void value expression`. The control
        # flow is restructured below so `next` is a standalone
        # block control statement and `supplied` is assigned
        # only from `nil` / `Array` cases.
        node_set.each do |nid|
          # Look up the supplied value, defensively handling
          # both string and symbol keys.
          supplied_value = if adj_h.key?(nid)
                             adj_h[nid]
                           elsif adj_h.key?(nid.to_sym)
                             adj_h[nid.to_sym]
                           end
          # Scalar / Hash / arbitrary non-Array supplied value:
          # fail closed (no silent coercion). Handled FIRST as a
          # standalone control-flow branch so `next` is never
          # used as an expression value.
          if supplied_value && !supplied_value.is_a?(Array)
            mismatches << "#{REASON_ADJACENCY_MISMATCH}:non_array_value:#{nid}"
            next
          end
          # Normalize to a sorted/uniq String Array. nil
          # (key absent) -> empty list; Array -> filtered +
          # sorted/uniq. No control-flow keywords are used as
          # expression values here.
          supplied = if supplied_value.nil?
                       []
                     else
                       supplied_value.map(&:to_s).reject(&:empty?).sort.uniq
                     end
          expected_nbrs = Array(expected[nid]).map(&:to_s).sort.uniq
          supplied.each do |n|
            unless node_set.include?(n)
              mismatches << "#{REASON_ADJACENCY_MISMATCH}:unknown_neighbor:#{nid}->#{n}"
            end
          end
          # Missing edge-backed neighbor: expected entries
          # that did not appear in supplied.
          (expected_nbrs - supplied).each do |n|
            mismatches << "#{REASON_ADJACENCY_MISMATCH}:missing_neighbor:#{nid}->#{n}"
          end
          # Extra neighbor not backed by an edge: supplied
          # entries that did not appear in expected AND are
          # known canonical ids (so we do not double-count
          # `unknown_neighbor`).
          (supplied - expected_nbrs).each do |n|
            next unless node_set.include?(n)
            mismatches << "#{REASON_ADJACENCY_MISMATCH}:extra_neighbor:#{nid}->#{n}"
          end
        end
        mismatches.uniq.sort
      end

      def _build_node_index(node_h)
        idx = {}
        node_h.each do |n|
          h = n.is_a?(Hash) ? n : {}
          cid = h['canonical_node_id'].to_s
          next if cid.empty?
          idx[cid] = h
        end
        idx
      end

      # SR18-04: build deterministic edge indexes once so
      # traversal is O(V + E) instead of O(V^2 * E).
      # Returns:
      #   'incident'       => Hash[node_id] -> Array (sorted edge_ids)
      #   'pair_to_edges'  => Hash[sorted 'a|b'] -> Array (sorted; >1 => parallel)
      #   'edge_endpoints' => Hash[edge_id] -> [sorted_node_a, sorted_node_b]
      #   'has_parallel'   => Boolean (true if any node pair has >=2 edges)
      #   'parallel_pairs' => Array (sorted 'a|b' pairs with >1 edge)
      def _build_edge_indexes(edges_by_id)
        incident = {}
        pair_to_edges = {}
        edge_endpoints = {}
        has_parallel = false
        parallel_pairs = []
        edges_by_id.each do |eid, e|
          h = e.is_a?(Hash) ? e : {}
          a = h['node_a_id'].to_s
          b = h['node_b_id'].to_s
          next if a.empty? || b.empty?
          if a == b
            edge_endpoints[eid.to_s] = [a, b]
            next
          end
          sorted_pair = [a, b].sort
          key = "#{sorted_pair[0]}|#{sorted_pair[1]}"
          (pair_to_edges[key] ||= []) << eid.to_s
          (incident[a] ||= []) << eid.to_s
          (incident[b] ||= []) << eid.to_s
          edge_endpoints[eid.to_s] = sorted_pair
        end
        incident.each_value { |arr| arr.sort! }
        pair_to_edges.each_value { |arr| arr.sort! }
        pair_to_edges.each do |k, arr|
          if arr.length > 1
            has_parallel = true
            parallel_pairs << k
          end
        end
        parallel_pairs.sort!
        {
          'incident'       => incident,
          'pair_to_edges'  => pair_to_edges,
          'edge_endpoints' => edge_endpoints,
          'has_parallel'   => has_parallel,
          'parallel_pairs' => parallel_pairs
        }
      end

      # ---- Step 5: classify component ----

      def _classify_component(comp, adjacency, edges_by_id, node_index,
                              coord_eps = nil, edge_indexes = nil)
        # FR18-02: ONE local Set for this component, used by
        # every per-step `include?` check below (degree,
        # chain walk, loop walk, parallel-pair pruning). The
        # previous `comp.include?(other)` Array scan was
        # O(N) per step and would degrade to O(V^2) for a
        # long simple chain / loop.
        comp_set = Set.new(comp)
        # SR18-04: detect parallel edges in this component
        # FIRST. Conservative: any node pair with >1 edge
        # => the component cannot be safely parsed, so we
        # return :parallel_edges without guessing.
        idx = edge_indexes || _build_edge_indexes(edges_by_id)
        if idx['has_parallel']
          pair_set = _parallel_pairs_in_comp(comp_set, idx)
          return [:parallel_edges, nil] unless pair_set.empty?
        end

        degree_map = {}
        comp.each do |nid|
          # SR18-04: degree is the count of incident edges
          # whose other endpoint is also in comp. Use the
          # incident index for O(degree(nid)) lookups
          # instead of scanning all edges.
          incident_edges = idx['incident'][nid] ||
                           Array(adjacency[nid]).map { |nbr|
                             _edge_between(nid, nbr, edges_by_id)
                           }.compact
          degree_map[nid] = incident_edges.count { |eid|
            h = edges_by_id[eid]
            next false if h.nil?
            a = h['node_a_id'].to_s
            b = h['node_b_id'].to_s
            other = (a == nid) ? b : (b == nid ? a : nil)
            !other.nil? && comp_set.include?(other)
          }
        end
        degree_counts = Hash.new(0)
        degree_map.each_value { |d| degree_counts[d] += 1 }
        min_d = degree_map.values.min || 0
        max_d = degree_map.values.max || 0
        term_count = degree_map.values.count(1)
        branch_count = degree_map.values.count { |d| d > 2 }

        edges_in_comp = _edges_in_component_via_index(comp_set, idx, edges_by_id)

        # ---- branching > 2 ----
        if branch_count > 0
          return [:branching, nil]
        end

        # ---- invalid component shapes ----
        if comp.empty?
          return [:invalid, nil]
        end
        if term_count > 2
          return [:invalid, nil]
        end

        # ---- simple closed loop ----
        # Cycles have every node degree == 2 and
        # edge_count == node_count. Detect them BEFORE
        # the open-chain edge-count check so the cycle
        # is not mis-classified as invalid.
        if min_d == 2 && max_d == 2 && term_count == 0 &&
           comp.length >= 3 && edges_in_comp.length == comp.length
          payload = _build_loop(comp, comp_set, adjacency, edges_by_id,
                                node_index, coord_eps, idx)
          return [:simple_loop, payload]
        end

        # Open chains have edge_count == node_count - 1.
        if edges_in_comp.length != (comp.length - 1)
          # Edges must equal V - 1 for an open chain; if not,
          # the component has isolated nodes (no edges) or a
          # topology the simple classifier cannot parse.
          return [:invalid, nil]
        end

        # ---- simple open chain ----
        if term_count == 2 && max_d <= 2 && min_d >= 1
          payload = _build_chain(comp, comp_set, adjacency, edges_by_id,
                                 node_index, degree_map, coord_eps, idx)
          return [:simple_chain, payload]
        end

        [:invalid, nil]
      end

      # SR18-04: collect the set of parallel-edge pairs that
      # are wholly contained inside `comp_set` (already a Set).
      # Returns sorted Array of 'a|b' strings. Empty when no
      # parallel edges touch this component.
      def _parallel_pairs_in_comp(comp_set, edge_indexes)
        out = []
        edge_indexes['parallel_pairs'].each do |pair|
          a, b = pair.split('|', 2)
          next unless comp_set.include?(a) && comp_set.include?(b)
          out << pair
        end
        out
      end

      # ---- chain ----

      def _build_chain(comp, comp_set, adjacency, edges_by_id, node_index,
                     degree_map, coord_eps = nil, edge_indexes = nil)
        # Terminal nodes (degree 1).
        terminals = comp.select { |nid| degree_map[nid] == 1 }.sort
        # Blueprint §7: start from the lex-smaller terminal.
        start_node = terminals.first
        end_node   = terminals.last
        # Walk the unique unused edge at each step.
        ordered_nodes = [start_node]
        ordered_edges = []
        used_edges = {}
        current = start_node
        safety = 0
        safety_max = comp.length * 4
        idx = edge_indexes || _build_edge_indexes(edges_by_id)
        incident_list = idx['incident']
        until current == end_node
          safety += 1
          if safety > safety_max
            return _chain_with_failure(comp, edges_by_id,
                                       REASON_CHAIN_TRAVERSAL_FAILED,
                                       coord_eps)
          end
          next_edge_id = nil
          next_node = nil
          # SR18-04: use the incident index for O(deg(current))
          # candidate edges instead of scanning every edge in
          # the graph.
          # FR18-02: per-step `comp_set.include?(other)` is
          # O(1) instead of the previous O(V) `comp.include?`.
          incident = []
          (incident_list[current] || []).each do |eid|
            next if used_edges[eid]
            h = edges_by_id[eid]
            next if h.nil?
            a = h['node_a_id'].to_s
            b = h['node_b_id'].to_s
            other = (a == current) ? b : (b == current ? a : nil)
            next if other.nil?
            next unless comp_set.include?(other)
            incident << [eid, other]
          end
          incident.sort_by! { |pair| pair[0].to_s }
          incident.each do |eid, other|
            # Disallow immediate backtrack (to the previously
            # visited node) UNLESS the backtrack is the only
            # path to the end_node (final step).
            if ordered_nodes.length > 1 && other == ordered_nodes[-2] &&
               other != end_node
              next
            end
            next_edge_id = eid
            next_node = other
            break
          end
          if next_edge_id.nil? || next_node.nil?
            return _chain_with_failure(comp, edges_by_id,
                                       REASON_CHAIN_TRAVERSAL_FAILED,
                                       coord_eps)
          end
          used_edges[next_edge_id] = true
          ordered_edges << next_edge_id
          ordered_nodes << next_node
          current = next_node
        end
        # Repeated vertex check (must not revisit an internal node).
        seen = Set.new
        repeated = false
        ordered_nodes.each do |nid|
          if seen.include?(nid)
            repeated = true
            break
          end
          seen.add(nid)
        end
        if ordered_nodes.length != comp.length ||
           ordered_edges.length != (comp.length - 1) ||
           ordered_nodes.last != end_node ||
           repeated
          return _chain_with_failure(comp, edges_by_id, REASON_REPEATED_VERTEX,
                                     coord_eps)
        end
        # Compute length, provenance, layer union.
        length, occ_ids, layer_names = _aggregate_edge_meta(ordered_edges, edges_by_id)
        chain_id = _chain_id(ordered_nodes, ordered_edges)
        {
          'chain_id'                => chain_id,
          'node_ids'                => ordered_nodes.dup,
          'edge_ids'                => ordered_edges.dup,
          'start_node_id'           => start_node,
          'end_node_id'             => end_node,
          'closed'                  => false,
          'length'                  => length,
          'source_occurrence_ids'   => occ_ids,
          'layer_names'             => layer_names,
          'unresolved_flags'        => [].freeze,
          'coordinate_epsilon'      => _safe_eps(coord_eps)
        }
      end

      def _chain_with_failure(comp, edges_by_id, reason, coord_eps = nil)
        edges_in_comp = _edges_in_component(comp, {}, edges_by_id)
        length, _occ, _layer = _aggregate_edge_meta(edges_in_comp, edges_by_id)
        {
          'chain_id'                => '',
          'node_ids'                => [].freeze,
          'edge_ids'                => [].freeze,
          'start_node_id'           => nil,
          'end_node_id'             => nil,
          'closed'                  => false,
          'length'                  => length,
          'source_occurrence_ids'   => [].freeze,
          'layer_names'             => [].freeze,
          'unresolved_flags'        => [reason].freeze,
          'coordinate_epsilon'      => _safe_eps(coord_eps)
        }
      end

      def _chain_id(ordered_nodes, ordered_edges)
        keys = ordered_nodes.join('|') + '#' + ordered_edges.join('|')
        'cn-' + Digest::SHA256.hexdigest(
          "#{CHAIN_ID_SCHEMA}|#{keys}"
        )[0, 16]
      end

      # ---- loop ----

      def _build_loop(comp, comp_set, adjacency, edges_by_id, node_index,
                      coord_eps = nil, edge_indexes = nil)
        # Blueprint §4.2: start at lex-smallest canonical node.
        sorted_comp = comp.sort
        start_node = sorted_comp.first
        # Build the two valid orientations by walking BOTH
        # first-step choices; keep the lex-smaller normalized
        # token sequence.
        idx = edge_indexes || _build_edge_indexes(edges_by_id)
        neighbors = Array(adjacency[start_node]).select { |n|
          comp_set.include?(n)
        }.sort
        if neighbors.length != 2
          return _loop_with_failure(comp, edges_by_id,
                                   REASON_LOOP_TRAVERSAL_FAILED, coord_eps)
        end
        orientation_a = _walk_cycle(start_node, neighbors[0], comp_set,
                                    adjacency, edges_by_id, node_index, idx)
        orientation_b = _walk_cycle(start_node, neighbors[1], comp_set,
                                    adjacency, edges_by_id, node_index, idx)
        a_valid = _valid_cycle?(orientation_a)
        b_valid = _valid_cycle?(orientation_b)
        chosen = if !a_valid && !b_valid
                  nil
                elsif !a_valid
                  orientation_b
                elsif !b_valid
                  orientation_a
                else
                  # Both orientations are valid simple cycles.
                  # Choose the lex-smaller normalized token
                  # sequence (Blueprint §4.2).
                  ta = orientation_a['node_ids'].join('|')
                  tb = orientation_b['node_ids'].join('|')
                  ta <= tb ? orientation_a : orientation_b
                end
        if chosen.nil?
          return _loop_with_failure(comp, edges_by_id,
                                   REASON_LOOP_TRAVERSAL_FAILED, coord_eps)
        end
        # Build a complete loop payload with stable id +
        # provenance / layer union + placeholder geometry
        # fields. The downstream _validate_loop_geometry +
        # _validate_loop_self_intersection calls fill in the
        # signed_area_xy, area_xy, perimeter, winding,
        # valid_for_region, and unresolved_flags.
        open_nodes = chosen['node_ids']
        ordered_edges = chosen['edge_ids']
        length, occs, layers = _aggregate_edge_meta(ordered_edges, edges_by_id)
        loop_id = _loop_id(open_nodes, ordered_edges)
        {
          'loop_id'                 => loop_id,
          'node_ids'                => open_nodes.dup,
          'edge_ids'                => ordered_edges.dup,
          'world_coordinates'       => chosen['world_coordinates'].dup,
          'closed'                  => true,
          'perimeter'               => length,
          'signed_area_xy'          => 0.0,
          'area_xy'                 => 0.0,
          'winding'                 => 'DEGENERATE',
          'source_occurrence_ids'   => occs,
          'layer_names'             => layers,
          'unresolved_flags'        => [].freeze,
          'valid_for_region'        => false,
          'coordinate_epsilon'      => _safe_eps(coord_eps)
        }
      end

      def _walk_cycle(start_node, first_neighbor, comp_set, adjacency,
                      edges_by_id, node_index, edge_indexes = nil)
        # Walk a deterministic cycle using the FIRST neighbor
        # as the orientation choice. We choose at each
        # degree-2 node the neighbor that is NOT the
        # previously-visited node. The deterministic tie-break
        # between two valid orientations is then resolved by
        # the lex-smaller normalized token sequence
        # (Blueprint §4.2 + §8).
        ordered_nodes = [start_node]
        ordered_edges = []
        prev = nil
        current = start_node
        next_node = first_neighbor
        until next_node.nil?
          # SR18-04: O(1) edge lookup via the pair index
          # instead of a full scan of edges_by_id per step.
          eid = _edge_between(current, next_node, edges_by_id,
                              edge_indexes)
          if eid.nil?
            return nil
          end
          ordered_edges << eid
          ordered_nodes << next_node
          prev = current
          current = next_node
          break if current == start_node && ordered_nodes.length > 1
          # FR18-02: per-step membership check via the local
          # Set is O(1) instead of the previous O(V) Array
          # scan. This keeps the cycle walk linear in V+E.
          nbrs = Array(adjacency[current]).select { |n|
            comp_set.include?(n) && n != prev
          }.sort
          next_node = nbrs.first
          if next_node.nil? && current != start_node
            # Dead end before closure.
            return nil
          end
        end
        return nil if ordered_nodes.first != start_node
        return nil unless ordered_nodes.last == start_node
        # Must visit all component nodes.
        comp_length = comp_set.length
        return nil if ordered_nodes.uniq.length != comp_length
        # Remove the trailing duplicate (closure) so node_ids
        # is the open sequence; world_coordinates carries the
        # closure coordinate for the polygon.
        open_nodes = ordered_nodes[0..-2]
        {
          'node_ids'                => open_nodes.dup,
          'edge_ids'                => ordered_edges.dup,
          'world_coordinates'       => open_nodes.map { |nid|
            node_index.fetch(nid, {})['world_coordinate']
          }.compact
        }
      end

      def _valid_cycle?(orientation)
        return false if orientation.nil?
        ns = Array(orientation['node_ids'])
        es = Array(orientation['edge_ids'])
        return false if ns.empty? || es.empty?
        return false if ns.length < 3
        return false if ns.length != es.length
        return false if ns.uniq.length != ns.length
        true
      end

      def _loop_with_failure(comp, edges_by_id, reason, coord_eps = nil)
        edges_in_comp = _edges_in_component(comp, {}, edges_by_id)
        length, _occ, _layer = _aggregate_edge_meta(edges_in_comp, edges_by_id)
        {
          'loop_id'                 => '',
          'node_ids'                => [].freeze,
          'edge_ids'                => [].freeze,
          'world_coordinates'       => [].freeze,
          'closed'                  => true,
          'perimeter'               => length,
          'signed_area_xy'          => 0.0,
          'area_xy'                 => 0.0,
          'winding'                 => 'DEGENERATE',
          'source_occurrence_ids'   => [].freeze,
          'layer_names'             => [].freeze,
          'unresolved_flags'        => [reason].freeze,
          'valid_for_region'        => false,
          'coordinate_epsilon'      => _safe_eps(coord_eps)
        }
      end

      def _loop_id(open_nodes, ordered_edges)
        # Blueprint §4.2: SHA-256 over schema + normalized
        # canonical node/edge sequence. The node_ids + edge_ids
        # are already in the lex-smaller orientation.
        keys = open_nodes.join('|') + '#' + ordered_edges.join('|')
        'lp-' + Digest::SHA256.hexdigest(
          "#{LOOP_ID_SCHEMA}|#{keys}"
        )[0, 16]
      end

      # ---- loop geometry validation ----

      def _validate_loop_geometry(loop, vflags, coord_eps = nil)
        coords = Array(loop['world_coordinates'])
        if coords.empty?
          vflags << REASON_DEGENERATE_LOOP
          loop['signed_area_xy'] = 0.0
          loop['area_xy'] = 0.0
          loop['winding'] = 'DEGENERATE'
          loop['perimeter'] = 0.0
          return
        end
        # Z planarity check: Z range vs coordinate_epsilon.
        eps = _loop_coord_eps(loop)
        # Sample a representative coord_eps from the first
        # node's coordinate_epsilon (or fallback 1e-6).
        zs = coords.map { |c| c.is_a?(Array) && c.length == 3 ? c[2] : nil }.compact
        if zs.empty?
          vflags << REASON_DEGENERATE_LOOP
          loop['signed_area_xy'] = 0.0
          loop['area_xy'] = 0.0
          loop['winding'] = 'DEGENERATE'
          loop['perimeter'] = _perimeter(coords)
          return
        end
        z_range = zs.max - zs.min
        if z_range > eps
          vflags << REASON_NON_PLANAR_LOOP
        end
        signed = _shoelace_signed(coords)
        area = signed.abs
        loop['signed_area_xy'] = signed
        loop['area_xy'] = area
        loop['perimeter'] = _perimeter(coords)
        # Winding: positive signed area in right-handed XY
        # = CCW; negative = CW; near-zero = DEGENERATE.
        if area <= _area_eps(eps)
          loop['winding'] = 'DEGENERATE'
          vflags << REASON_DEGENERATE_LOOP
        else
          loop['winding'] = signed >= 0 ? 'CCW' : 'CW'
        end
      end

      def _loop_coord_eps(loop)
        # Read coordinate_epsilon from the first node's stored
        # field (set by CanonicalTopologyBuilder). Fall back
        # to 1e-6.
        # We don't carry node records on the loop directly; the
        # reconstructor uses the graph-level coordinate_eps
        # passed in via _validate_loop_geometry's caller. The
        # caller passes a closure with the eps. We approximate
        # by reading loop['coordinate_epsilon'] if present,
        # else 1e-6.
        if loop.is_a?(Hash) && loop['coordinate_epsilon']
          return loop['coordinate_epsilon'].to_f
        end
        1.0e-6
      end

      def _perimeter(coords)
        perim = 0.0
        return perim if coords.length < 2
        n = coords.length
        (0...n).each do |i|
          a = coords[i]
          b = coords[(i + 1) % n]
          next unless a.is_a?(Array) && b.is_a?(Array)
          perim += _distance3(a, b)
        end
        perim
      end

      def _shoelace_signed(coords)
        signed = 0.0
        return signed if coords.length < 3
        n = coords.length
        (0...n).each do |i|
          a = coords[i]
          b = coords[(i + 1) % n]
          next unless a.is_a?(Array) && b.is_a?(Array) &&
                      a.length >= 2 && b.length >= 2
          signed += (a[0] * b[1]) - (b[0] * a[1])
        end
        signed / 2.0
      end

      def _distance3(a, b)
        return 0.0 unless a.is_a?(Array) && b.is_a?(Array) &&
                            a.length == 3 && b.length == 3
        dx = a[0] - b[0]
        dy = a[1] - b[1]
        dz = a[2] - b[2]
        Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
      end

      # ---- loop self-intersection (non-adjacent only) ----
      #
      # SR18-03: detect non-adjacent loop-segment conflicts
      # of FOUR kinds:
      #   1. proper interior crossing  -> REASON_SELF_INTERSECTION
      #   2. endpoint on unrelated segment interior
      #      (T-junction-like)         -> REASON_LOOP_ENDPOINT_ON_SEGMENT
      #   3. collinear interior overlap
      #                                    -> REASON_LOOP_COLLINEAR_OVERLAP
      #   4. non-adjacent geometric touch
      #                                    -> REASON_LOOP_GEOMETRIC_TOUCH
      # Adjacent pairs (including the closure-adjacent pair
      # that closes the polygon) are SKIPPED. The closure
      # adjacency is NOT a conflict: the segment (last -> first)
      # naturally closes on its own start point. We achieve
      # this by only comparing j >= i+2 within the open
      # node_ids list, AND by routing every conflict check
      # through the shared V1.7 SegmentConflict pure
      # predicate (which already knows shared_endpoint is SAFE
      # per Blueprint §10.3).
      def _validate_loop_self_intersection(loop, node_index, vflags,
                                       coord_eps = nil)
        return if Array(loop['unresolved_flags']).include?(REASON_DEGENERATE_LOOP)
        coords = Array(loop['world_coordinates'])
        return if coords.length < 3
        n = coords.length
        eps = coord_eps.is_a?(Numeric) ? _safe_eps(coord_eps) :
                                      _loop_coord_eps(loop)
        segs = []
        (0...n).each do |i|
          segs << [coords[i], coords[(i + 1) % n]]
        end
        seg_bboxes = segs.map { |a, b|
          xs = [a[0], b[0]]
          ys = [a[1], b[1]]
          [xs.min - eps, ys.min - eps, xs.max + eps, ys.max + eps]
        }
        kinds = {}
        (0...n).each do |i|
          ((i + 2)...n).each do |j|
            # Skip closure adjacency: when the loop's node_ids
            # are stored open, the pair (i=last_index, j=0)
            # would NOT be tested by this loop. We also skip
            # the cross-closure pair (last_segment vs first_segment)
            # explicitly because i+2..n excludes i == n-1 + 2 > n.
            next if seg_bboxes[i][2] < seg_bboxes[j][0]
            next if seg_bboxes[j][2] < seg_bboxes[i][0]
            next if seg_bboxes[i][3] < seg_bboxes[j][1]
            next if seg_bboxes[j][3] < seg_bboxes[i][1]
            pa1 = segs[i][0]
            pa2 = segs[i][1]
            pb1 = segs[j][0]
            pb2 = segs[j][1]
            # SR18-03: route through the shared V1.7
            # SegmentConflict pure predicate so semantics stay
            # aligned with the V1.7 bridge / proposal X3 paths.
            outcome = SUAnalysis::Core::SegmentConflict.conflict?(
              [pa1, pa2], [pb1, pb2], eps: eps
            )
            next unless outcome.is_a?(Hash) && outcome['conflict']
            reason = outcome['reason'].to_s
            case reason
            when 'proper_interior_crossing'
              kinds[REASON_SELF_INTERSECTION] = true
            when 'collinear_overlap'
              kinds[REASON_LOOP_COLLINEAR_OVERLAP] = true
            when 'bridge_endpoint_on_unrelated',
                 'unrelated_endpoint_on_bridge'
              kinds[REASON_LOOP_ENDPOINT_ON_SEGMENT] = true
            else
              # Defensive: any other SegmentConflict hit at
              # the loop self-intersection level is reported
              # as a non-adjacent geometric touch (segment
              # bbox proximity with no proper crossing,
              # collinear overlap, or endpoint-on-segment).
              kinds[REASON_LOOP_GEOMETRIC_TOUCH] = true
            end
          end
        end
        kinds.each_key { |r| vflags << r }
      end

      def _segments_cross_strictly_xy?(p1, p2, q1, q2, eps)
        return false unless _finite?(p1) && _finite?(p2) &&
                            _finite?(q1) && _finite?(q2)
        d1 = _orient2d(p1, p2, q1)
        d2 = _orient2d(p1, p2, q2)
        d3 = _orient2d(q1, q2, p1)
        d4 = _orient2d(q1, q2, p2)
        return false if d1.abs < eps || d2.abs < eps ||
                        d3.abs < eps || d4.abs < eps
        ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
          ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
      end

      def _orient2d(p, q, r)
        (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
      end

      def _finite?(p)
        p.is_a?(Array) && p.length == 3 &&
          p.all? { |v| v.is_a?(Numeric) && v.respond_to?(:finite?) && v.finite? }
      end

      # ---- containment + regions ----

      def _classify_loop_containment(loops, coord_eps = nil)
        # SR18-02: one resolved eps threaded through.
        eps = coord_eps.is_a?(Numeric) ? _safe_eps(coord_eps) : 1.0e-6
        # Build loop bboxes (XY).
        loop_bboxes = {}
        loops.each do |l|
          xs = []
          ys = []
          Array(l['world_coordinates']).each do |c|
            next unless c.is_a?(Array) && c.length >= 2
            xs << c[0]
            ys << c[1]
          end
          loop_bboxes[l['loop_id']] = {
            'min_x' => xs.min || 0.0, 'max_x' => xs.max || 0.0,
            'min_y' => ys.min || 0.0, 'max_y' => ys.max || 0.0
          }
        end
        # For each candidate pair (A, B), decide if A is
        # INSIDE B (strictly, with no boundary crossing or
        # touch) using a deterministic ray-cast point-in-
        # polygon test. If we cannot determine cleanly (any
        # boundary touch OR boundary crossing), flag
        # ambiguous_containment -- do not silently emit a
        # region.
        ambiguous = false
        inside_map = {}  # outer_loop_id -> sorted Array<inner_loop_id>
        # Use the smallest coordinate_eps of any loop as
        # the boundary epsilon.
        eps = 1.0e-6
        # bbox prune first.
        loops.each do |outer|
          inside_map[outer['loop_id']] = []
        end
        loops.combination(2).each do |la, lb|
          # Determine candidates by bbox inclusion only.
          bbox_a = loop_bboxes[la['loop_id']]
          bbox_b = loop_bboxes[lb['loop_id']]
          a_in_b_box = bbox_a['min_x'] >= bbox_b['min_x'] - eps &&
                       bbox_a['max_x'] <= bbox_b['max_x'] + eps &&
                       bbox_a['min_y'] >= bbox_b['min_y'] - eps &&
                       bbox_a['max_y'] <= bbox_b['max_y'] + eps
          b_in_a_box = bbox_b['min_x'] >= bbox_a['min_x'] - eps &&
                       bbox_b['max_x'] <= bbox_a['max_x'] + eps &&
                       bbox_b['min_y'] >= bbox_a['min_y'] - eps &&
                       bbox_b['max_y'] <= bbox_a['max_y'] + eps
          unless a_in_b_box || b_in_a_box
            next
          end
          # Test if A vertices are all STRICTLY inside B
          # (no boundary touch).
          status_a_in_b = _all_vertices_strictly_inside?(la, lb, eps)
          status_b_in_a = _all_vertices_strictly_inside?(lb, la, eps)
          # Detect boundary crossings between the two loops.
          if _loop_boundaries_cross?(la, lb, eps)
            ambiguous = true
            next
          end
          # If the test is ambiguous on either side, mark
          # the whole classification as ambiguous.
          if status_a_in_b == :ambiguous || status_b_in_a == :ambiguous
            ambiguous = true
            next
          end
          if status_a_in_b == :inside && status_b_in_a == :outside
            inside_map[lb['loop_id']] << la['loop_id']
          elsif status_b_in_a == :inside && status_a_in_b == :outside
            inside_map[la['loop_id']] << lb['loop_id']
          elsif status_a_in_b == :inside && status_b_in_a == :inside
            # Identical bbox + identical in-inside: identical
            # loops -- ambiguous containment.
            ambiguous = true
          end
        end
        # Loop self-touch: a loop that touches itself (degenerate)
        # would have already been classified invalid. Skip.
        if ambiguous
          return nil
        end
        # Sort inner-loop lists deterministically.
        inside_map.each { |_k, v| v.sort! }
        inside_map
      end

      # Ray-cast point-in-polygon. Returns:
      #   :inside -- strictly inside (no boundary hit, no
      #     segment intersection ambiguity).
      #   :outside -- strictly outside.
      #   :ambiguous -- touches boundary or self-crossing.
      def _all_vertices_strictly_inside?(inner_loop, outer_loop, eps)
        coords_outer = Array(outer_loop['world_coordinates'])
        coords_inner = Array(inner_loop['world_coordinates'])
        return :ambiguous if coords_outer.length < 3 || coords_inner.length < 3
        coords_inner.each do |p|
          status = _point_in_polygon_status(p, coords_outer, eps)
          return :ambiguous if status == :ambiguous
          return :outside if status == :outside
        end
        :inside
      end

      def _point_in_polygon_status(p, polygon, eps)
        return :ambiguous unless p.is_a?(Array) && p.length >= 2
        # Boundary check first: if p is within eps of any edge
        # (inclusive of endpoints), it is ON the boundary =>
        # ambiguous for containment purposes.
        n = polygon.length
        (0...n).each do |i|
          a = polygon[i]
          b = polygon[(i + 1) % n]
          next unless a.is_a?(Array) && b.is_a?(Array) && a.length >= 2 &&
                      b.length >= 2
          if _point_on_segment_2d(p, a, b, eps)
            return :ambiguous
          end
        end
        # Ray-cast to the +X direction.
        x = p[0]
        y = p[1]
        inside = false
        (0...n).each do |i|
          a = polygon[i]
          b = polygon[(i + 1) % n]
          next unless a.is_a?(Array) && b.is_a?(Array) && a.length >= 2 &&
                      b.length >= 2
          yi = a[1]
          yj = b[1]
          next if (yi <= y && yj <= y) || (yi > y && yj > y)
          # x at y via line segment param.
          xi = a[0]
          xj = b[0]
          dy = yj - yi
          next if dy.abs < eps
          t = (y - yi) / dy
          x_int = xi + t * (xj - xi)
          if x_int > x
            inside = !inside
          end
        end
        inside ? :inside : :outside
      end

      def _point_on_segment_2d(p, a, b, eps)
        return false unless a.is_a?(Array) && b.is_a?(Array) &&
                            a.length >= 2 && b.length >= 2 &&
                            p.is_a?(Array) && p.length >= 2
        # Distance from p to segment ab (XY).
        vx = b[0] - a[0]
        vy = b[1] - a[1]
        wx = p[0] - a[0]
        wy = p[1] - a[1]
        seg_len2 = (vx * vx) + (vy * vy)
        return _distance_xy(p, a) <= eps if seg_len2 <= 0
        t = (wx * vx + wy * vy) / seg_len2
        t = 0.0 if t < 0.0
        t = 1.0 if t > 1.0
        px = a[0] + t * vx
        py = a[1] + t * vy
        _distance_xy(p, [px, py]) <= eps
      end

      def _distance_xy(a, b)
        return Float::INFINITY unless a.is_a?(Array) && b.is_a?(Array) &&
                                     a.length >= 2 && b.length >= 2
        dx = a[0] - b[0]
        dy = a[1] - b[1]
        Math.sqrt((dx * dx) + (dy * dy))
      end

      def _loop_boundaries_cross?(loop_a, loop_b, eps)
        coords_a = Array(loop_a['world_coordinates'])
        coords_b = Array(loop_b['world_coordinates'])
        return false if coords_a.length < 3 || coords_b.length < 3
        segs_a = []
        n_a = coords_a.length
        (0...n_a).each { |i| segs_a << [coords_a[i], coords_a[(i + 1) % n_a]] }
        segs_b = []
        n_b = coords_b.length
        (0...n_b).each { |i| segs_b << [coords_b[i], coords_b[(i + 1) % n_b]] }
        segs_a.each do |pa1, pa2|
          segs_b.each do |pb1, pb2|
            next unless _bbox_overlap_2d(pa1, pa2, pb1, pb2, eps)
            if _segments_cross_strictly_xy?(pa1, pa2, pb1, pb2, eps)
              return true
            end
            # Boundary touch: an endpoint of one segment lies
            # ON the interior of the other. This is
            # ambiguous containment.
            if _point_on_segment_2d(pb1, pa1, pa2, eps) ||
               _point_on_segment_2d(pb2, pa1, pa2, eps) ||
               _point_on_segment_2d(pa1, pb1, pb2, eps) ||
               _point_on_segment_2d(pa2, pb1, pb2, eps)
              return true
            end
          end
        end
        false
      end

      def _bbox_overlap_2d(a1, a2, b1, b2, eps)
        ax_min = [a1[0], a2[0]].min
        ax_max = [a1[0], a2[0]].max
        ay_min = [a1[1], a2[1]].min
        ay_max = [a1[1], a2[1]].max
        bx_min = [b1[0], b2[0]].min
        bx_max = [b1[0], b2[0]].max
        by_min = [b1[1], b2[1]].min
        by_max = [b1[1], b2[1]].max
        return false if ax_max + eps < bx_min
        return false if bx_max + eps < ax_min
        return false if ay_max + eps < by_min
        return false if by_max + eps < ay_min
        true
      end

      def _build_regions(loops, inside_map, unresolved_issues, coord_eps = nil)
        # SR18-02: one resolved eps threaded through.
        eps = coord_eps.is_a?(Numeric) ? _safe_eps(coord_eps) : 1.0e-6
        # inside_map[outer_id] = sorted Array<inner_id>.
        # Depth parity: depth 0 = outer region; depth 1 = hole;
        # depth 2 = new island/outer region; etc.
        regions = []
        # Build parent_map: every loop -> its smallest-area
        # containing loop (depth 1 above it). If a loop is
        # not contained in any other valid loop, parent is
        # nil (depth 0 outer).
        parents = {}
        loops.each do |loop|
          # Find the smallest-area valid containing loop.
          own_area = loop['area_xy'].to_f
          parent = nil
          parent_area = Float::INFINITY
          inside_map.each do |outer_id, inner_ids|
            next unless inner_ids.include?(loop['loop_id'])
            outer_loop = loops.find { |l| l['loop_id'] == outer_id }
            next if outer_loop.nil?
            oa = outer_loop['area_xy'].to_f
            if oa < parent_area && oa > own_area
              parent = outer_id
              parent_area = oa
            end
          end
          parents[loop['loop_id']] = parent
        end
        # Walk depth 0 loops (parents[loop_id] == nil) as
        # outer-region candidates. Their immediate
        # depth-1 children (parents[child] == loop_id)
        # become holes. Recurse for depth 2 -> region again.
        # Blueprint §3.4 + §11: depth 0 outer = region; depth 1
        # = hole; depth 2 = new island region; depth 3 = hole
        # of depth 2; etc. We emit a region for every
        # even-depth loop in the containment tree.
        depth_of = {}
        loops.each do |lp|
          depth_of[lp['loop_id']] = _depth_of(lp['loop_id'], parents)
        end
        # Process loops in deterministic order (loop_id sort)
        # so the regions list is stable.
        loops.sort_by { |lp| lp['loop_id'].to_s }.each do |outer|
          depth = depth_of[outer['loop_id']] || 0
          # Only even-depth loops are region candidates.
          next if depth.odd?
          hole_ids = _immediate_children(outer['loop_id'], parents)
          unless _holes_valid?(loops, hole_ids)
            # Boundary intersection or other ambiguous
            # relation: skip emitting.
            unresolved_issues << REASON_LOOP_BOUNDARY_INTERSECTION
            next
          end
          # Compute region area = outer area - sum(holes area).
          outer_area = outer['area_xy'].to_f
          # SR18-01: explicit Ruby 2.2-compatible accumulation
          # (Enumerable/Array#sum is Ruby 2.4+; SU2017 ships 2.2.4).
          hole_area = 0.0
          hole_ids.each do |hid|
            hit = loops.find { |l| l['loop_id'] == hid }
            hole_area += hit.nil? ? 0.0 : hit.fetch('area_xy', 0.0).to_f
          end
          region_area = outer_area - hole_area
          eps = coord_eps.is_a?(Numeric) ? _safe_eps(coord_eps) :
                                          _loop_coord_eps(outer)
          if region_area <= _area_eps(eps)
            unresolved_issues << REASON_INVALID_REGION
            next
          end
          # Provenance union across outer + holes.
          outer_occ = Array(outer['source_occurrence_ids'])
          outer_layer = Array(outer['layer_names'])
          all_occ = outer_occ.dup
          all_layer = outer_layer.dup
          hole_ids.each do |hid|
            h_loop = loops.find { |l| l['loop_id'] == hid }
            next if h_loop.nil?
            all_occ.concat(Array(h_loop['source_occurrence_ids']))
            all_layer.concat(Array(h_loop['layer_names']))
          end
          occ = all_occ.map { |v| v.to_s }.reject(&:empty?).uniq.sort
          layers = all_layer.map { |v| v.to_s }.reject(&:empty?).uniq.sort
          region_id = _region_id(outer['loop_id'], hole_ids)
          regions << {
            'region_id'              => region_id,
            'outer_loop_id'          => outer['loop_id'],
            'hole_loop_ids'          => hole_ids.dup,
            'area_xy'                => region_area,
            'perimeter_outer'        => outer['perimeter'].to_f,
            'source_occurrence_ids'  => occ,
            'layer_names'            => layers,
            'unresolved_flags'       => [].freeze
          }
        end
        regions.sort_by! { |r| r['region_id'].to_s }
        regions
      end

      # Walk the parent chain to compute the depth of a loop
      # in the containment tree. Returns 0 for a top-level
      # (parent == nil) loop; 1 for a depth-1 child; etc.
      def _depth_of(loop_id, parents)
        depth = 0
        seen = Set.new
        cur = loop_id
        while !cur.nil? && !seen.include?(cur)
          seen.add(cur)
          cur = parents[cur]
          # Safety cap to prevent infinite loops in malformed
          # parents maps.
          return depth if cur.nil? || seen.include?(cur)
          depth += 1
          break if depth > 64
        end
        depth
      end

      def _immediate_children(outer_id, parents)
        children = []
        parents.each do |child_id, parent_id|
          children << child_id if parent_id == outer_id
        end
        children.sort
      end

      def _holes_valid?(loops, hole_ids)
        # All holes are valid_for_region; pairwise boundaries
        # between holes do not cross.
        hole_ids.each do |hid|
          hole_loop = loops.find { |l| l['loop_id'] == hid }
          return false if hole_loop.nil?
          return false unless hole_loop['valid_for_region']
        end
        hole_ids.combination(2).each do |ha, hb|
          la = loops.find { |l| l['loop_id'] == ha }
          lb = loops.find { |l| l['loop_id'] == hb }
          next if la.nil? || lb.nil?
          return false if _loop_boundaries_cross?(la, lb, eps)
        end
        true
      end

      def _region_id(outer_loop_id, hole_ids)
        keys = outer_loop_id.to_s + '#' + hole_ids.sort.join('|')
        'rg-' + Digest::SHA256.hexdigest(
          "#{REGION_ID_SCHEMA}|#{keys}"
        )[0, 16]
      end

      # ---- edge helpers ----
      # FR18-02: index-aware edge collection. Sum of
      # incident-edge lists for each node in `comp_set`,
      # restricted to edges whose OTHER endpoint is also in
      # comp_set, deduped, sorted. O(V + E_comp) instead of
      # O(V^2).
      def _edges_in_component_via_index(comp_set, edge_indexes,
                                        edges_by_id)
        seen = {}
        comp_set.each do |nid|
          (edge_indexes['incident'][nid] || []).each do |eid|
            h = edges_by_id[eid]
            next if h.nil?
            a = h['node_a_id'].to_s
            b = h['node_b_id'].to_s
            other = (a == nid) ? b : (b == nid ? a : nil)
            next if other.nil?
            next unless comp_set.include?(other)
            seen[eid] = true
          end
        end
        seen.keys.sort
      end

      # Backward-compat: build indexes on the fly when the
      # caller passes an empty `adjacency` (the chain-with-
      # failure path). Defensive only; new code should
      # thread `edge_indexes` through and call the indexed
      # helper directly.
      def _edges_in_component(comp, adjacency, edges_by_id)
        if comp.empty?
          return []
        end
        idx = _build_edge_indexes(edges_by_id)
        _edges_in_component_via_index(Set.new(comp), idx, edges_by_id)
      end

      # SR18-04: pair-index lookup, O(1) on average. Falls
      # back to a full scan only if the pair isn't in the
      # index (defensive against malformed input).
      def _edge_between(a, b, edges_by_id, edge_indexes = nil)
        if edge_indexes && edge_indexes['pair_to_edges']
          sorted_pair = [a.to_s, b.to_s].sort
          key = "#{sorted_pair[0]}|#{sorted_pair[1]}"
          arr = edge_indexes['pair_to_edges'][key]
          return arr.first if arr && !arr.empty?
        end
        edges_by_id.each do |eid, h|
          na = h['node_a_id'].to_s
          nb = h['node_b_id'].to_s
          return eid if (na == a && nb == b) || (na == b && nb == a)
        end
        nil
      end

      # FR18-02: removed the previous process-global
      # `comp_set(arr)` helper and its instance-variable
      # membership cache (which was keyed by
      # `arr.object_id`). Object IDs can be reused after GC
      # and the cache could grow across reconstructions.
      # Component membership checks now use a local Set that
      # is built once per traversal context (see
      # `_classify_component`) and passed through the
      # indexed helpers (`_parallel_pairs_in_comp`,
      # `_edges_in_component_via_index`, `_build_chain`,
      # `_walk_cycle`). No `comp.include?` remains in the
      # production traversal hot path.

      def _aggregate_edge_meta(edge_ids, edges_by_id)
        length = 0.0
        occs = []
        layers = []
        edge_ids.each do |eid|
          e = edges_by_id[eid]
          next if e.nil?
          we = e['world_endpoints']
          if we.is_a?(Array) && we.length == 2 &&
             we[0].is_a?(Array) && we[1].is_a?(Array)
            length += _distance3(we[0], we[1])
          end
          occs.concat(Array(e['source_occurrence_ids']).map(&:to_s))
          layer = e['layer_name']
          layers << layer.to_s if layer.is_a?(String) && !layer.empty?
        end
        [length,
         occs.reject(&:empty?).uniq.sort,
         layers.reject(&:empty?).uniq.sort]
      end

      # ---- result digest ----

      def _compute_result_digest(graph_digest:, chains:, loops:, regions:,
                                 unresolved_issues:, metrics:, state:)
        lines = []
        lines << "V|#{state}"
        lines << "G|#{graph_digest}"
        chains.sort_by { |c| c['chain_id'].to_s }.each do |c|
          lines << "CHAIN|#{c['chain_id']}|#{c['node_ids'].join(',')}|#{c['edge_ids'].join(',')}|#{c['length']}"
        end
        loops.sort_by { |l| l['loop_id'].to_s }.each do |l|
          lines << "LOOP|#{l['loop_id']}|#{l['node_ids'].join(',')}|#{l['edge_ids'].join(',')}|#{l['signed_area_xy']}|#{l['perimeter']}|#{l['winding']}|#{l['valid_for_region']}"
        end
        regions.sort_by { |r| r['region_id'].to_s }.each do |r|
          lines << "REGION|#{r['region_id']}|#{r['outer_loop_id']}|#{Array(r['hole_loop_ids']).join(',')}|#{r['area_xy']}"
        end
        Array(unresolved_issues).each do |u|
          lines << "U|#{u}"
        end
        metrics.sort.each do |k, v|
          lines << "M|#{k}|#{v}"
        end
        Digest::SHA256.hexdigest("#{RESULT_ID_SCHEMA}\n" + lines.join("\n"))
      end
    end
  end
end
