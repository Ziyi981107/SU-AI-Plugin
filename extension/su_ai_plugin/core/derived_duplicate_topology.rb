#
# core/derived_duplicate_topology.rb — V1.5 Round 3 shared helper
#
# Provides the SHARED direct-match graph construction and
# maximal-clique enumeration used by BOTH DuplicateRepairProposer
# and DerivedDuplicateValidator (BLOCK-002 CodeX Review 033:
# proposer and validator must share both direct predicate and
# class semantics).
#
# Single source of truth for:
#   - The direct endpoint predicate (forward / reversed / nil)
#     with the SAME per-axis tolerance check the rest of V1.5
#     uses.
#   - Layer0 normalization (must match before geometry).
#   - Bron-Kerbosch-with-pivot enumeration of maximal direct-
#     match cliques on the induced direct-match graph.
#   - Layer/finite-point/tolerance helpers.
#
# Both the proposer (which operates on issue-derived member
# subsets of the workspace) and the validator (which operates on
# the full workspace entity list) call into this module. They
# each pass in their own record set; the methodology is
# identical and the class semantics match.
#

require_relative 'tolerance'
require_relative 'derived_entity_record'

module SUAnalysis
  module Core
    module DerivedDuplicateTopology
      module_function

      DEFAULT_TOLERANCE = 1.0e-4

      # ===========================================================
      # Direct endpoint matcher (the V1.5 BLOCK-002 contract).
      # Mirrors DuplicateRepairProposer.direct_match?.
      # ===========================================================

      def direct_match?(pa_s, pa_e, pb_s, pb_e, layer_a, layer_b, tolerance)
        return nil unless finite_point?(pa_s) && finite_point?(pa_e)
        return nil unless finite_point?(pb_s) && finite_point?(pb_e)
        tol = tolerance.to_f
        return nil unless tol.finite? && tol > 0
        # Layer names must match after Layer0 normalization.
        if normalize_layer(layer_a) != normalize_layer(layer_b)
          return nil
        end
        if points_within?(pa_s, pb_s, tol) && points_within?(pa_e, pb_e, tol)
          :forward
        elsif points_within?(pa_s, pb_e, tol) && points_within?(pa_e, pb_s, tol)
          :reversed
        else
          nil
        end
      end

      # ===========================================================
      # Build a direct-match adjacency matrix for a list of
      # records. Each record is a Hash {record:, start:, finish:,
      # layer:}. Returns:
      #   { adj: Array<Array<Boolean>>, records: Array<Hash> }
      # where adj[i][j] is true iff records[i] directly matches
      # records[j] under the captured tolerance.
      # ===========================================================

      def build_direct_match_graph(records, tolerance)
        adj = Array.new(records.length) { Array.new(records.length, false) }
        records.each_with_index do |a, i|
          sa_pts = [a[:start], a[:finish]]
          ((i + 1)...records.length).each do |j|
            b = records[j]
            sb_pts = [b[:start], b[:finish]]
            kind = direct_match?(sa_pts[0], sa_pts[1], sb_pts[0], sb_pts[1],
                                  a[:layer], b[:layer], tolerance)
            if kind == :forward || kind == :reversed
              adj[i][j] = true
              adj[j][i] = true
            end
          end
        end
        { adj: adj, records: records }
      end

      # ===========================================================
      # Enumerate MAXIMAL CLIQUES of the direct-match graph.
      # Same Bron-Kerbosch-with-pivot implementation as the
      # proposer uses (BLOCK-002 shared class semantics).
      # Returns an Array<Array<Integer>> where each inner Array
      # is a sorted list of node indices forming a maximal clique.
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

      # ===========================================================
      # Convenience: compute the duplicate-class topology for the
      # given records using clique partition (the V1.5 round-3
      # BLOCK-002 contract). Returns an Array<Array<Hash>> where
      # each inner Array contains ≥ 2 record Hashes forming a
      # maximal direct-match clique.
      #
      # Use `select{|c| c.length >= 2}` to keep only proper
      # cliques (the raw Bron-Kerbosch can also report
      # singletons, but maximal cliques of size 1 mean no
      # duplicate, so we drop them).
      # ===========================================================

      def clique_classes(records, tolerance)
        return [] if records.nil? || records.empty?
        graph = build_direct_match_graph(records, tolerance)
        cliques = maximal_cliques(graph[:adj])
        cliques.map { |c| c.map { |i| graph[:records][i] } }.select { |c| c.length >= 2 }
      end

      # ===========================================================
      # Resolve the captured tolerance from the workspace's
      # source_snapshot.execution_config (BLOCK-004: the
      # validator must use the captured tolerance, not the
      # default).
      # ===========================================================

      def resolve_tolerance(workspace, tolerance)
        return tolerance.to_f if tolerance && tolerance.to_f.finite? && tolerance.to_f > 0
        return DEFAULT_TOLERANCE if workspace.nil?
        src = workspace.respond_to?(:source_snapshot) ? workspace.source_snapshot : nil
        return DEFAULT_TOLERANCE if src.nil?
        ec = src.respond_to?(:execution_config) ? src.execution_config : nil
        return DEFAULT_TOLERANCE if ec.nil?
        vals = ec.respond_to?(:tolerance_values) ? ec.tolerance_values : nil
        return DEFAULT_TOLERANCE unless vals.is_a?(Hash)
        v = vals[:duplicate] || vals['duplicate']
        v ? v.to_f : DEFAULT_TOLERANCE
      end

      # ===========================================================
      # Layer0 normalization
      # ===========================================================

      def normalize_layer(name)
        return 'Layer0' if name.nil?
        s = name.to_s
        return 'Layer0' if s.empty?
        case s.downcase
        when 'layer0', 'default', 'untagged'
          'Layer0'
        else
          s
        end
      end

      # ===========================================================
      # Numeric helpers
      # ===========================================================

      def finite_point?(p)
        return false unless p.is_a?(Array) && p.length == 3
        p.all? do |v|
          v.respond_to?(:finite?) && v.finite?
        end
      end

      def points_within?(p, q, tol)
        return false unless p.is_a?(Array) && q.is_a?(Array) && p.length == 3 && q.length == 3
        (0..2).all? { |i| (p[i].to_f - q[i].to_f).abs <= tol.to_f }
      end

      # Extract a {record:, start:, finish:, layer:} Hash from a
      # DerivedEntityRecord. Used by the validator + proposer to
      # feed records into the shared graph builder.
      def extract_record_tuple(d)
        return nil unless d.is_a?(DerivedEntityRecord)
        return nil unless d.kind == :edge
        geom = d.respond_to?(:geometry_summary) ? d.geometry_summary : nil
        return nil unless geom.is_a?(Hash)
        s = geom['start'] || geom[:start]
        f = geom['end']   || geom[:end]
        l = geom['layer'] || geom[:layer]
        return nil unless finite_point?(s) && finite_point?(f)
        { record: d, start: s, finish: f, layer: l }
      end
    end
  end
end
