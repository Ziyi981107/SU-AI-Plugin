#
# core/derived_duplicate_topology.rb — V1.5 Round-4
#
# Compatibility shim + thin domain helper for the duplicate
# topology. All actual duplicate-geometry semantics (direct
# match predicate, finite/tolerance/layer normalization,
# candidate enumeration, pair enumeration) live in
# `DuplicateGeometrySemantics` and are re-exported from here
# so the historical `DerivedDuplicateTopology.*` call sites
# continue to resolve.
#
# Per AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND4_BLOCK_FIX_2026-08-27
# §3 (BLOCK-002A + BLOCK-002B):
#   "Introduce one shared pure duplicate-geometry semantics
#    responsibility used by: DuplicateDetector; duplicate
#    proposer eligibility/revalidation; duplicate validator.
#    For tolerance > 0: 3D grid cell size = captured tolerance;
#    mathematical floor per axis; index EVERY edge under BOTH
#    endpoint cells; 27-neighbor-cell query around each endpoint;
#    union/deduplicate candidate IDs; shared direct_match?
#    as final authority; stable unordered pair dedup."
#
# Round-4 does NOT use Bron-Kerbosch / maximal-clique
# enumeration as the destructive action unit. See
# DuplicateRepairProposer for the connected-component +
# complete-graph topology decision.
#

require_relative 'tolerance'
require_relative 'derived_entity_record'
require_relative 'duplicate_geometry_semantics'

module SUAnalysis
  module Core
    module DerivedDuplicateTopology
      module_function

      DEFAULT_TOLERANCE = DuplicateGeometrySemantics::DEFAULT_TOLERANCE

      # Re-export the shared semantics so existing call sites
      # resolve through this module unchanged.
      def direct_match?(pa_s, pa_e, pb_s, pb_e, layer_a, layer_b, tolerance)
        DuplicateGeometrySemantics.direct_match?(pa_s, pa_e, pb_s, pb_e,
                                                  layer_a, layer_b, tolerance)
      end

      def finite_point?(p)
        DuplicateGeometrySemantics.finite_point?(p)
      end

      def finite_float_triple(p)
        DuplicateGeometrySemantics.finite_float_triple(p)
      end

      def points_within?(p, q, tol)
        DuplicateGeometrySemantics.points_within?(p, q, tol)
      end

      def normalize_layer(name)
        DuplicateGeometrySemantics.normalize_layer(name)
      end

      def valid_tolerance?(t)
        DuplicateGeometrySemantics.valid_tolerance?(t)
      end

      def resolve_tolerance(workspace, tolerance)
        # Prefer explicit value, then captured. Per FIX-A:
        # missing/invalid captured tolerance returns NIL
        # (NOT a runtime fallback to DEFAULT_TOLERANCE).
        # Production callers MUST treat nil as "no
        # auto-repair / no topology measurement".
        if DuplicateGeometrySemantics.valid_tolerance?(tolerance)
          return DuplicateGeometrySemantics.parse_strict_tolerance(tolerance)
        end
        DuplicateGeometrySemantics.resolve_captured_tolerance(workspace)
      end

      # Extract a tuple from a DerivedEntityRecord.
      def extract_record_tuple(d)
        DuplicateGeometrySemantics.extract_record_tuple(d)
      end

      # Candidate enumeration (BLOCK-002A).
      def enumerate_candidates(records, tolerance)
        DuplicateGeometrySemantics.enumerate_candidates(records, tolerance)
      end

      # Pair enumeration (BLOCK-004 pair metric).
      def enumerate_direct_pairs(records, tolerance)
        DuplicateGeometrySemantics.enumerate_direct_pairs(records, tolerance)
      end

      def count_direct_pairs(records, tolerance)
        DuplicateGeometrySemantics.count_direct_pairs(records, tolerance)
      end

      # ===========================================================
      # Round-4 topology decision (BLOCK-002B).
      # ===========================================================
      #
      # Builds the direct-match adjacency graph for the given
      # records under the captured tolerance, then partitions
      # the vertices into connected components. For each
      # component with N >= 2:
      #
      #   - if the component is a COMPLETE GRAPH (every pair of
      #     members is a direct match), the component is
      #     REPAIRABLE: ONE destructive action will be emitted,
      #     with deterministic survivor = lex-smallest
      #     derived_id and removal set = the other members.
      #
      #   - if the component is NOT a complete graph, it is
      #     NON-TRANSITIVE / INCOMPLETE: emit NO destructive
      #     action for any sub-clique; emit one inspectable
      #     :skipped audit row with reason
      #     `non_transitive_duplicate_component`; preserve
      #     member IDs, issue IDs, source/provenance evidence.
      #
      # This decision is the V1.5 Round-4 BLOCK-002B contract.
      # Bron-Kerbosch / maximal-clique enumeration is NOT used
      # to drive destructive action emission (AIPM Round-4 §4).
      def classify_components(records, tolerance)
        pairs = DuplicateGeometrySemantics.enumerate_candidates(records, tolerance)
        tuples = DuplicateGeometrySemantics.records_to_tuples(records)
        n = tuples.length
        # Build union-find over direct-match edges.
        parent = (0...n).to_a
        find = ->(i) {
          while parent[i] != i
            parent[i] = parent[parent[i]]
            i = parent[i]
          end
          i
        }
        pairs.each do |i, j|
          ri = find.call(i)
          rj = find.call(j)
          next if ri == rj
          parent[ri] = rj
        end
        # Group indices by root.
        groups = {}
        (0...n).each do |i|
          r = find.call(i)
          (groups[r] ||= []) << i
        end
        # Build the pair set for O(1) membership.
        pair_set = {}
        pairs.each { |i, j| pair_set[[i, j]] = true }
        # Classify each component.
        result = {
          repairable_components: [],
          non_transitive_components: [],
          singletons: []
        }
        groups.each do |_r, members|
          if members.length < 2
            result[:singletons] << members
            next
          end
          # For each component with N >= 2, count direct pairs.
          required_pairs = members.length * (members.length - 1) / 2
          actual_pairs = 0
          members.combination(2).each do |i, j|
            actual_pairs += 1 if pair_set[[i, j]]
          end
          if actual_pairs == required_pairs
            # COMPLETE GRAPH -> repairable.
            result[:repairable_components] << members.sort
          else
            # NON-TRANSITIVE / INCOMPLETE -> fail-closed as one
            # inspectable skipped audit row.
            result[:non_transitive_components] << {
              member_indices: members.sort,
              member_tuples:  members.sort.map { |i| tuples[i] },
              direct_pair_count: actual_pairs,
              required_pair_count: required_pairs,
              missing_pair_count: required_pairs - actual_pairs
            }
          end
        end
        result
      end

      # Round-4 pair-count metric (BLOCK-004).
      def duplicate_pair_count(records, tolerance)
        DuplicateGeometrySemantics.count_direct_pairs(records, tolerance)
      end

      # ===========================================================
      # Compatibility-only: maximal cliques of the direct-match
      # graph. This is retained ONLY as a diagnostic helper for
      # tests + audit; the proposer's destructive-action decision
      # does NOT use maximal cliques (Round-4 BLOCK-002B).
      # Production auto-repair paths MUST NOT call this.
      # ===========================================================

      def maximal_cliques(adj)
        cliques = []
        return cliques if adj.nil? || adj.empty?
        nodes = (0...adj.length).to_a
        neighbor_indices = lambda do |v|
          row = adj[v]
          return [] if row.nil?
          result = []
          row.each_with_index { |flag, idx| result << idx if flag }
          result
        end
        pivot = lambda do |candidates, excluded|
          pool = candidates + excluded
          return nil if pool.empty?
          best = pool.first
          best_count = neighbor_indices.call(best).count { |n| candidates.include?(n) }
          pool.each do |p|
            cnt = neighbor_indices.call(p).count { |n| candidates.include?(n) }
            if cnt > best_count
              best = p
              best_count = cnt
            end
          end
          best
        end
        work = []
        work << { r: [], P: nodes.dup, X: [], pivots: nil, idx: 0, done: false }
        until work.empty?
          f = work[-1]
          if !f[:done] && f[:P].empty? && f[:X].empty?
            cliques << f[:r].sort
            f[:done] = true
            work.pop
            next
          end
          if f[:pivots].nil?
            u = pivot.call(f[:P], f[:X])
            u_neighbors = neighbor_indices.call(u)
            f[:pivots] = f[:P] - u_neighbors
            f[:idx] = 0
            next
          end
          if f[:idx] >= f[:pivots].length
            work.pop
            next
          end
          v = f[:pivots][f[:idx]]
          f[:idx] += 1
          nbrs = neighbor_indices.call(v)
          child = {
            r: f[:r] + [v],
            P: f[:P] & nbrs,
            X: f[:X] & nbrs,
            pivots: nil,
            idx: 0,
            done: false
          }
          work << child
          f[:P] = f[:P] - [v]
          f[:X] = f[:X] + [v]
        end
        cliques.uniq
      end
    end
  end
end