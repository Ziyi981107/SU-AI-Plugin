#
# extension/analyzers_runner.rb — one-pass pipeline that orchestrates:
#   1. PreflightRunner.build_snapshot   (snapshot + preflight)
#   2. four analyzers                       (snapshot-driven)
#   3. IssueNormalizer                       (raw -> canonical)
#   4. IssueEnricher                         (SourceToken + issue_id)
#   5. IssueRegistry.new                    (validate + hold)
#   6. DisplayUnitFormatter                 (length display strings)
#   7. AnalysisResult.new                    (immutable wrapper)
#
# Per CodeX Round 013 BLOCK-002: ONE snapshot is built per command.
# Per CodeX Round 011: display_data is produced before the
# AnalysisResult is frozen.
#
# This module is the user-facing entry point of the analyzer pipeline.
# It is the only place those 7 pieces are stitched together.
#

require_relative 'preflight_runner'
require_relative 'display_unit_formatter'
require_relative 'core/preflight'
require_relative 'core/analyzers/duplicate_detector'
require_relative 'core/analyzers/short_edge_detector'
require_relative 'core/analyzers/open_endpoint_detector'
require_relative 'core/analyzers/gap_candidate_detector'
require_relative 'core/issue_registry'
require_relative 'core/issue_normalizer'
require_relative 'core/issue_enricher'
require_relative 'core/analysis_result'
require_relative 'core/layer_semantic_mapper'

module SUAnalysis
  module Extension
    module AnalyzersRunner
      module_function

      # Run the full pipeline. Returns an AnalysisResult.
      # selection: SketchUp Selection (or any each-able duck type)
      # model:     SU model (or nil in tests)
      def run(selection, model: nil)
        # Initialize diagnostics BEFORE any recoverable stage uses it.
        # Otherwise an analyzer raising would crash on `diagnostics << {...}`
        # (NoMethodError on nil) and abort the entire command.
        diagnostics = []

        # Normalize the selection at the boundary so all downstream
        # stages (preflight + walk + label + classification) see the
        # same stable entity array. Per CodeX Round 020 REAL-HOST
        # BLOCK: the real SketchUp::Selection is not always safe to
        # iterate more than once.
        # NOTE: keep this variable named `normalized_selection` (NOT
        # `normalized`); see step 4 below for why. The variable name
        # collision masked a critical bug where the issue-normalization
        # array shadowed the selection array, leaving selection_type
        # empty when the closed-rectangle case produced zero issues.
        normalized_selection = SUAnalysis::Extension::PreflightRunner.normalize_selection(selection)

        # 1. Build snapshot + preflight.
        snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(normalized_selection, model: model)
        # Run the pure-Ruby PreflightAnalyzer on the snapshot so the
        # preflight is a real PreflightReport (responds to :edge_count,
        # :vertex_count, etc.). Per CodeX Round 020 REAL-HOST BLOCK:
        # the OWNER's repro was ".summary" returning "edges: 0" because
        # the HASH returned by collect_preflight_facts does not respond
        # to :edge_count; AnalysisResult#summary uses safe_attr which
        # defaults to 0 for non-responsive objects.
        preflight = SUAnalysis::Core::PreflightAnalyzer.run(snapshot)

        # 2. Run analyzers. Per-analyzer rescue — one bad analyzer must
        # not abort the others. PI_TASK_001 §18.
        raw_issues = []
        analyzers.each do |det|
          begin
            raw_issues.concat(det.new.detect(snapshot))
          rescue StandardError => e
            diagnostics << {
              stage: "analyzer[#{det.name.split('::').last}]",
              error: "#{e.class}: #{e.message}"
            }
          end
        end

        # 3. Build the snapshot_lookup for enrichment.
        snapshot_lookup = build_snapshot_lookup(snapshot)

        # 4. Normalize raw issues + preflight warnings.
        # NOTE: the variable is named `normalized_issues` (NOT
        # `normalized`) to avoid shadowing `normalized_selection`
        # above. Round 020 REAL-HOST BLOCK recheck fix: the prior
        # name `normalized` caused `selection_label_for(normalized)`
        # and `classification_label(normalized)` at the bottom of
        # run() to be called on the issues array (often empty for
        # a closed rectangle), not on the selection array — which
        # surfaced to the Owner as `result.selection_type == 'empty'`.
        normalized_issues = []
        raw_issues.each do |raw|
          out = SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)
          normalized_issues << out if out
        end
        SUAnalysis::Core::IssueNormalizer.normalize_preflight_warnings(
          preflight.respond_to?(:warnings) ? preflight.warnings : []
        ).each do |pf|
          normalized_issues << pf
        end

        # 5. Enrich (deterministic ids + locatable).
        # diagnostics is the SAME array the analyzer rescue used above;
        # do NOT re-initialize it here. Per CodeX Round 018 BLOCK-005:
        # any `diagnostics = []` after the analyzer loop wipes the
        # captured per-analyzer failure entries. The registry below
        # appends to whatever array we pass in; the SAME array is
        # what AnalysisResult.diagnostics reads.
        enriched = SUAnalysis::Core::IssueEnricher.enrich_all(
          normalized_issues, snapshot_lookup: snapshot_lookup
        )

        # 5.5. V1.1 (per plan §4.8): populate `source[:layer_name]` on
        # each enriched issue so LayerSemanticMapper can attribute the
        # issue to the correct layer. The IssueRegistry freezes each
        # issue, so we MUST populate the field BEFORE constructing the
        # registry; we do this by creating shallow copies (dup the issue
        # Hash + dup the source sub-Hash if present). Issues whose first
        # edge has no resolvable layer_name are passed through as-is;
        # LayerSemanticMapper's Layer0 fallback will catch them.
        enriched_with_source = inject_source_layer_name(enriched, snapshot_lookup)

        # 6. Build IssueRegistry (drops malformed issues with diagnostics).
        registry = SUAnalysis::Core::IssueRegistry.new(enriched_with_source, diagnostics: diagnostics)

        # 7. Display unit formatting (lengths only).
        display_data = SUAnalysis::Extension::DisplayUnitFormatter.format_all(registry.issues)

        # 7.5. V1.1 (per plan §4.8 + §4.4): build the per-layer Array
        # of LayerSummary hashes from `snapshot.layers` + the
        # registry's issues. The mapper handles dedup by name,
        # edge_count summation, visibility_label composition (R011),
        # role bucket order (R009/R012), and the cross-role visibility
        # sort (visible first, then issue_count DESC, then name ASC).
        layer_groups = SUAnalysis::Core::LayerSemanticMapper.build(
          snapshot.layers,
          registry.issues
        )

        # 8. Selection label and classification. These MUST use
        # `normalized_selection` (the selection array), NOT
        # `normalized_issues`. Per Round 020 REAL-HOST BLOCK recheck:
        # when these were called on the (possibly empty) issues array,
        # the Owner saw `result.selection_type == 'empty'` even though
        # the selection contained a 4-edge Group.
        selection_label = selection_label_for(normalized_selection)

        # 9. Frozen immutable result. V1.1: pass layer_groups so the
        # dialog's Layers section has per-layer data to render.
        SUAnalysis::Core::AnalysisResult.new(
          preflight:        preflight,
          registry:         registry,
          snapshot_lookup:  snapshot_lookup,
          display_data:     display_data,
          diagnostics:      diagnostics,
          selection_type:   classification_label(normalized_selection),
          selection_label:  selection_label,
          layer_groups:     layer_groups
        )
      end

      # ---- internals ------------------------------------------------------

      def analyzers
        [
          SUAnalysis::Core::Analyzers::DuplicateDetector,
          SUAnalysis::Core::Analyzers::ShortEdgeDetector,
          SUAnalysis::Core::Analyzers::OpenEndpointDetector,
          SUAnalysis::Core::Analyzers::GapCandidateDetector
        ]
      end

      # Build the edge_id -> EdgeRecord index used by IssueEnricher.
      # Cache the index from the snapshot's edges array.
      def build_snapshot_lookup(snapshot)
        lookup = {}
        Array(snapshot.respond_to?(:edges) ? snapshot.edges : []).each do |edge|
          lookup[edge.id] = edge
        end
        lookup
      end

      def selection_label_for(selection)
        return 'selection' if selection.nil?
        if selection.respond_to?(:first) && selection.first
          e = selection.first
          if e.respond_to?(:name) && e.respond_to?(:typename)
            return "#{e.typename}: #{e.name}"
          end
        end
        'selection'
      end

      def classification_label(selection)
        return 'empty' if selection.nil?
        return 'empty' unless selection.respond_to?(:count)
        return 'empty' if selection.count.zero?
        # We don't try to distinguish Group/ComponentInstance/etc.
        # in the test environment; the real SU path classifies via
        # PreflightRunner's collect_preflight_facts. Tests can
        # override this by passing a custom model.
        'selection'
      end

      # V1.1 helper (per plan §4.8): for each enriched issue, derive
      # the layer_name from the first edge's layer (the only canonical
      # place a layer_name is recorded for an analyzer issue) and
      # populate `source[:layer_name]` on the issue. The mapper and
      # grouper (commit 1+2) read `iss[:source][:layer_name]`; this
      # helper makes that read succeed on the production path.
      #
      # Returns a NEW array of issues (does NOT mutate input). Each
      # issue with a resolvable layer_name is shallow-duped and gets
      # a `source: { layer_name: <String> }` Hash. Issues without a
      # resolvable layer_name (no edge_ids, no resolvable edge, edge
      # has nil/empty layer name) pass through unchanged so the
      # mapper's `Layer0` fallback still works.
      #
      # The dup is shallow: only the issue Hash itself and the
      # `source` sub-Hash (if present) are duplicated. The frozen
      # `sources` / `source_tokens` / `edge_ids` Arrays inside the
      # issue Hash are NOT mutated by this helper, so they keep their
      # frozen state across the registry's `iss.freeze` call below.
      def inject_source_layer_name(enriched, snapshot_lookup)
        return enriched if enriched.nil? || enriched.empty?
        enriched.map do |iss|
          next iss unless iss.is_a?(Hash)
          # Resolve the first edge_id -> edge record -> layer name.
          layer_name = nil
          eids = iss[:edge_ids]
          if eids.is_a?(Array) && !eids.empty?
            eid = eids.first
            begin
              edge = snapshot_lookup[Integer(eid)]
            rescue StandardError
              edge = nil
            end
            if edge && edge.respond_to?(:layer) && edge.layer && !edge.layer.to_s.empty?
              layer_name = edge.layer.to_s
            end
          end
          # No resolvable layer name -> leave the issue unchanged so
          # the mapper's Layer0 fallback handles it.
          next iss if layer_name.nil?
          # Shallow-copy the issue; copy the source sub-Hash too if
          # present (other Hash slots like sources / source_tokens /
          # edge_ids are NOT mutated, so they can stay aliased).
          new_iss = iss.dup
          src = if iss[:source].is_a?(Hash)
                  iss[:source].dup
                else
                  {}
                end
          src[:layer_name] = layer_name
          new_iss[:source] = src
          new_iss
        end
      end
    end
  end
end
