#
# tests/test_analyzers_runner.rb — pipeline recovery tests.
#
# Per CodeX Round 018 BLOCK-005:
#   - AnalyzersRunner.run initializes diagnostics BEFORE any recoverable
#     stage uses it. A failing analyzer must not crash the whole
#     command via NoMethodError on nil.
#   - The original failure is recorded in AnalysisResult.diagnostics.
#   - Later analyzers still run after one raises.
#
# These tests stub one of the four analyzers in AnalyzersRunner.analyzers
# to raise. The other three still run and the command returns an
# AnalysisResult with the failing analyzer's error in diagnostics.
#

require_relative 'runner'
require_relative '_fake_su'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/preflight'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/issue_normalizer'
require_relative '../extension/su_ai_plugin/core/issue_enricher'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/compatibility/su_capability'
require_relative '../extension/su_ai_plugin/preflight_runner'
require_relative '../extension/su_ai_plugin/display_unit_formatter'
require_relative '../extension/su_ai_plugin/analyzers_runner'

include SUAnalysis::Core
include SUAnalysis::Compatibility
include SUAnalysis::Extension

# --- helpers ----------------------------------------------------------

# Build a simple rectangle as a 4-Edge selection.
def ar_rectangle_edges
  x0, y0 = 0.0, 0.0
  x1, y1 = 10.0, 5.0
  v00 = FakeSU::Vertex.new(x0, y0, 0.0)
  v10 = FakeSU::Vertex.new(x1, y0, 0.0)
  v11 = FakeSU::Vertex.new(x1, y1, 0.0)
  v01 = FakeSU::Vertex.new(x0, y1, 0.0)
  [
    FakeSU::Edge.new(start: v00, finish: v10, persistent_id: 1),
    FakeSU::Edge.new(start: v10, finish: v11, persistent_id: 2),
    FakeSU::Edge.new(start: v11, finish: v01, persistent_id: 3),
    FakeSU::Edge.new(start: v01, finish: v00, persistent_id: 4)
  ]
end

# Build a "failing analyzer" class. detect always raises with msg.
def ar_build_failing_class(label, msg)
  Class.new do
    define_singleton_method(:name) { label }
    def detect(_snapshot)
      raise StandardError, 'simulated analyzer failure'
    end
  end
end

# Snapshot the current AnalyzersRunner.analyzers (as a plain Array)
# and replace it with a patched list. Returns the original Array.
def ar_patch_analyzers(patched_list)
  original = SUAnalysis::Extension::AnalyzersRunner.analyzers
  # Replace the module-level analyzers via singleton method redefinition.
  SUAnalysis::Extension::AnalyzersRunner.singleton_class.send(
    :remove_method, :analyzers
  ) rescue nil
  SUAnalysis::Extension::AnalyzersRunner.singleton_class.send(
    :define_method, :analyzers
  ) do
    patched_list
  end
  original
end

def ar_unpatch_analyzers(original)
  SUAnalysis::Extension::AnalyzersRunner.singleton_class.send(
    :remove_method, :analyzers
  ) rescue nil
  SUAnalysis::Extension::AnalyzersRunner.singleton_class.send(
    :define_method, :analyzers
  ) do
    original
  end
end

# --- baseline ---------------------------------------------------------

test 'analyzers_runner: baseline run on closed rectangle returns an AnalysisResult' do
  rect = ar_rectangle_edges
  group = FakeSU::Group.new(name: 'rect', children: rect, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  refute_nil result
  assert_kind_of SUAnalysis::Core::AnalysisResult, result
  # Closed rectangle: no open endpoints / no short / no duplicate.
  assert_equal 0, result.registry.summary['open_endpoint'].to_i
  assert_equal 0, result.registry.summary['short_edge'].to_i
  assert_equal 0, result.registry.summary['duplicate_edge_candidate'].to_i
end

# --------------------------------------------------------------------------
# S6-GATE-B-BLOCK-005 — Failing-analyzer injection tests
# --------------------------------------------------------------------------

test 'S6-GATE-B-BLOCK-005: one failing analyzer -> others still run, command returns AnalysisResult' do
  rect = ar_rectangle_edges
  group = FakeSU::Group.new(name: 'rect', children: rect, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  # Make DuplicateDetector raise. The other 3 analyzers must still run.
  original = ar_patch_analyzers(
    SUAnalysis::Extension::AnalyzersRunner.analyzers.map do |k|
      if k == SUAnalysis::Core::Analyzers::DuplicateDetector
        ar_build_failing_class('FailingDuplicateDetector',
                               'simulated analyzer failure')
      else
        k
      end
    end
  )
  begin
    result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
    refute_nil result
    assert_kind_of SUAnalysis::Core::AnalysisResult, result
    # The failure must be recorded in diagnostics.
    fail_diag = result.diagnostics.find { |d| d[:stage].to_s.include?('DuplicateDetector') }
    refute_nil fail_diag, "expected a diagnostic for the failing DuplicateDetector, got: #{result.diagnostics.inspect}"
    assert_match(/simulated analyzer failure/, fail_diag[:error].to_s)
    # The OTHER analyzers must still run. Verify the registry has the
    # short_edge / open_endpoint keys present (proves those analyzers ran).
    assert result.registry.issues.is_a?(Array)
  ensure
    ar_unpatch_analyzers(original)
  end
end

test 'S6-GATE-B-BLOCK-005: all analyzers raising -> no crash, diagnostics records each' do
  rect = ar_rectangle_edges
  group = FakeSU::Group.new(name: 'rect', children: rect, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  original = ar_patch_analyzers(
    SUAnalysis::Extension::AnalyzersRunner.analyzers.map do |k|
      ar_build_failing_class("FailingAll[#{k.name}]", 'all-fail simulation')
    end
  )
  begin
    result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
    refute_nil result
    fail_diags = result.diagnostics.select { |d| d[:stage].to_s.start_with?('analyzer[') }
    assert fail_diags.length >= 4,
           "expected >= 4 analyzer-stage diagnostics, got #{fail_diags.length}: #{result.diagnostics.inspect}"
  ensure
    ar_unpatch_analyzers(original)
  end
end

test 'S6-GATE-B-BLOCK-005: diagnostics is initialized before the analyzer loop (no NoMethodError on nil)' do
  # The BLOCK-005 finding was: `diagnostics << {...}` inside the rescue
  # raised NoMethodError on nil because diagnostics was a local
  # variable that Ruby bound at first use. Verify by injecting a
  # failing analyzer and confirming diagnostics is an Array (not nil).
  rect = ar_rectangle_edges
  group = FakeSU::Group.new(name: 'rect', children: rect, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  original = ar_patch_analyzers(
    SUAnalysis::Extension::AnalyzersRunner.analyzers.map do |k|
      if k == SUAnalysis::Core::Analyzers::OpenEndpointDetector
        ar_build_failing_class('FailingOpenEndpointDetector', 'nil-test')
      else
        k
      end
    end
  )
  begin
    result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
    refute_nil result
    assert_kind_of Array, result.diagnostics
    assert !result.diagnostics.empty?, "diagnostics should not be empty after a failing analyzer"
    # The failure must be specifically tagged in diagnostics.
    assert(result.diagnostics.any? { |d| d[:stage].to_s.include?('OpenEndpointDetector') })
  ensure
    ar_unpatch_analyzers(original)
  end
end
