#
# core/analysis_result.rb — pure-Ruby immutable wrapper returned by the
# analysis pipeline. Built once per "Analyze selection" command.
#
# Per CodeX Review 011..014 (2026-08-18), Stage 6 contract:
#   - No public setters, top-level frozen, nested fields immutable by
#     design (IssueRegistry + Hash#freeze in display_data).
#   - Hash<frozen> with: preflight, registry, snapshot_lookup,
#     display_data, diagnostics, selection_type, selection_label.
#
# This module is pure Ruby. It does NOT call SketchUp or access
# compatibility/.
#

module SUAnalysis
  module Core
    class AnalysisResult
      attr_reader :preflight, :registry, :snapshot_lookup,
                  :display_data, :diagnostics,
                  :selection_type, :selection_label,
                  :layer_groups

      def initialize(preflight:, registry:, snapshot_lookup: nil,
                     display_data: nil, diagnostics: nil,
                     selection_type: nil, selection_label: nil,
                     layer_groups: nil)
        raise ArgumentError, 'preflight is required' if preflight.nil?
        raise ArgumentError, 'registry is required'  if registry.nil?
        @preflight         = preflight
        @registry          = registry
        @snapshot_lookup   = (snapshot_lookup || {}).dup.freeze
        @display_data      = (display_data || {}).dup.freeze
        @diagnostics       = (diagnostics || []).dup.freeze
        @selection_type    = selection_type.to_s
        @selection_label   = selection_label.to_s
        # V1.1 (per plan §4.8): layer_groups is the locked Array of
        # LayerSummary hashes produced by LayerSemanticMapper. Default
        # to an empty Array for V1.0 callers. The frozen Array is the
        # immutable contract — UI bridge stringifies it once on the
        # way out. V1.0 callers that don't supply this get [] which
        # UIBridge will surface as `summary['layer_groups'] == []`
        # and `layerGroups == []`.
        @layer_groups = (layer_groups || []).dup.freeze
        # No public setters; freeze top-level.
        freeze
      end

      # Convenience: registry.find(id) — pass-through.
      def find_issue(issue_id)
        @registry.find(issue_id)
      end

      # Build the LOCKED-COMPLETE summary required by the Stage 6
      # plan section 6.7 and Owner checklist K.2. Includes:
      #   - Selection kind + label
      #   - Edges / Vertices from preflight
      #   - Non-zero-Z vertices
      #   - Warnings count
      #   - Issue counts per issue_type (from Registry)
      #   - V1.1 (plan §4.8): layer_groups — per-layer Array<Hash>
      #     with role / role_label / visibility / visibility_label /
      #     edge_count / issue_count for the dialog's Layers section.
      # Returns String-keyed Hash so the UI bridge String-keys it once.
      # NOTE: @layer_groups is Array<Hash-with-Symbol-keys>. The UI
      # bridge (UIBridge.stringify_value) recursively converts Symbol
      # keys to String keys on the JSON boundary; we do NOT deep-dup
      # here because summary is called many times in tests.
      def summary
        pf = @preflight
        result = {
          'selection' => @selection_label.to_s,
          'edges'     => safe_attr(pf, :edge_count, 0),
          'vertices'  => safe_attr(pf, :vertex_count, 0),
          'non_zero_z_vertices' => safe_attr(pf, :non_zero_z_vertex_count, 0),
          'warnings'  => safe_attr(pf, :warning_count, 0),
          'issues'    => @registry.summary,
          'layer_groups' => layer_groups_payload
        }
        result
      end

      # Returns a JSON-safe Array of layer-group hashes (deep-dup so
      # callers can mutate without affecting the frozen @layer_groups).
      # The Hash contents use Symbol keys mirroring the
      # LayerSemanticMapper shape; UIBridge.stringify_hash will rewrite
      # Symbol keys to String keys on the JSON boundary.
      def layer_groups_payload
        return [] if @layer_groups.nil? || @layer_groups.empty?
        @layer_groups.map do |g|
          # Per LayerSemanticMapper.locked_field_set: name, role,
          # role_rule, role_label, visible, visibility_unknown,
          # visibility_label, edge_count, issue_count.
          {
            name:               g[:name],
            role:               g[:role],
            role_rule:          g[:role_rule],
            role_label:         g[:role_label],
            visible:            g[:visible],
            visibility_unknown: g[:visibility_unknown],
            visibility_label:   g[:visibility_label],
            edge_count:         g[:edge_count],
            issue_count:        g[:issue_count]
          }
        end
      end

      # Test helper: assert top-level is frozen, frozen Array for
      # Diagnostics, frozen Hash for the others.
      def invariants_ok?
        return false unless frozen?
        return false unless @diagnostics.frozen?
        return false unless @snapshot_lookup.frozen?
        return false unless @display_data.frozen?
        true
      end

      private

      # Read an attribute from a (possibly missing) PreflightReport.
      # PreflightReport may respond_to?(:foo) without having defined
      # :foo; this returns the default cleanly.
      def safe_attr(obj, name, default)
        return default unless obj.respond_to?(name)
        v = obj.send(name)
        v.nil? ? default : v
      end
    end
  end
end
