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
require_relative '../core/preflight'
require_relative '../core/analyzers/duplicate_detector'
require_relative '../core/analyzers/short_edge_detector'
require_relative '../core/analyzers/open_endpoint_detector'
require_relative '../core/analyzers/gap_candidate_detector'
require_relative '../core/issue_registry'
require_relative '../core/issue_normalizer'
require_relative '../core/issue_enricher'
require_relative '../core/analysis_result'

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
        normalized = SUAnalysis::Extension::PreflightRunner.normalize_selection(selection)

        # 1. Build snapshot + preflight.
        snapshot = SUAnalysis::Extension::PreflightRunner.build_snapshot(normalized, model: model)
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
        normalized = []
        raw_issues.each do |raw|
          out = SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)
          normalized << out if out
        end
        SUAnalysis::Core::IssueNormalizer.normalize_preflight_warnings(
          preflight.respond_to?(:warnings) ? preflight.warnings : []
        ).each do |pf|
          normalized << pf
        end

        # 5. Enrich (deterministic ids + locatable).
        # diagnostics is the SAME array the analyzer rescue used above;
        # do NOT re-initialize it here. Per CodeX Round 018 BLOCK-005:
        # any `diagnostics = []` after the analyzer loop wipes the
        # captured per-analyzer failure entries. The registry below
        # appends to whatever array we pass in; the SAME array is
        # what AnalysisResult.diagnostics reads.
        enriched = SUAnalysis::Core::IssueEnricher.enrich_all(
          normalized, snapshot_lookup: snapshot_lookup
        )

        # 6. Build IssueRegistry (drops malformed issues with diagnostics).
        registry = SUAnalysis::Core::IssueRegistry.new(enriched, diagnostics: diagnostics)

        # 7. Display unit formatting (lengths only).
        display_data = SUAnalysis::Extension::DisplayUnitFormatter.format_all(registry.issues)

        # 8. Selection label.
        selection_label = selection_label_for(normalized)

        # 9. Frozen immutable result.
        SUAnalysis::Core::AnalysisResult.new(
          preflight:        preflight,
          registry:         registry,
          snapshot_lookup:  snapshot_lookup,
          display_data:     display_data,
          diagnostics:      diagnostics,
          selection_type:   classification_label(normalized),
          selection_label:  selection_label
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
    end
  end
end
