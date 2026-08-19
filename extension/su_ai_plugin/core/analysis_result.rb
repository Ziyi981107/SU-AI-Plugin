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
                  :selection_type, :selection_label

      def initialize(preflight:, registry:, snapshot_lookup: nil,
                     display_data: nil, diagnostics: nil,
                     selection_type: nil, selection_label: nil)
        raise ArgumentError, 'preflight is required' if preflight.nil?
        raise ArgumentError, 'registry is required'  if registry.nil?
        @preflight         = preflight
        @registry          = registry
        @snapshot_lookup   = (snapshot_lookup || {}).dup.freeze
        @display_data      = (display_data || {}).dup.freeze
        @diagnostics       = (diagnostics || []).dup.freeze
        @selection_type    = selection_type.to_s
        @selection_label   = selection_label.to_s
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
      # Returns String-keyed Hash so the UI bridge String-keys it once.
      def summary
        pf = @preflight
        result = {
          'selection' => @selection_label.to_s,
          'edges'     => safe_attr(pf, :edge_count, 0),
          'vertices'  => safe_attr(pf, :vertex_count, 0),
          'non_zero_z_vertices' => safe_attr(pf, :non_zero_z_vertex_count, 0),
          'warnings'  => safe_attr(pf, :warning_count, 0),
          'issues'    => @registry.summary
        }
        result
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
