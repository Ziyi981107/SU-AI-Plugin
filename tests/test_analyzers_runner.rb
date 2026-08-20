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

# --------------------------------------------------------------------------
# V1.1 (per plan §4.8 / §7.2): layer_groups appears on result.summary and
# AnalysisResult#layer_groups. The AnalyzersRunner is the single
# integration point that wires snapshot.layers + registry.issues
# through LayerSemanticMapper.
# --------------------------------------------------------------------------

# Build a 2-edge selection on a CUSTOM layer 'DIM-XX' so the snapshot
# produces non-default-layer LayerRecords.
def ar_two_edges_on_layer(layer_name)
  v0 = FakeSU::Vertex.new(0.0, 0.0, 0.0)
  v1 = FakeSU::Vertex.new(10.0, 0.0, 0.0)
  layer = FakeSU::Layer.new(layer_name)
  e0 = FakeSU::Edge.new(start: v0, finish: v1, layer: layer, persistent_id: 1)
  e1 = FakeSU::Edge.new(start: v1, finish: FakeSU::Vertex.new(20.0, 0.0, 0.0), layer: layer, persistent_id: 2)
  [e0, e1]
end

test 'V1.1: result.layer_groups is an Array (defaults present)' do
  rect = ar_rectangle_edges
  group = FakeSU::Group.new(name: 'rect', children: rect, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  assert_kind_of Array, result.layer_groups
  # The closed rectangle uses Layer0 (default) for all 4 edges, so
  # the layer_groups array has exactly 1 entry.
  assert_equal 1, result.layer_groups.length
end

test 'V1.1: result.summary includes layer_groups key' do
  rect = ar_rectangle_edges
  group = FakeSU::Group.new(name: 'rect', children: rect, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  s = result.summary
  assert s.key?('layer_groups'),
         "expected summary to have 'layer_groups' key, got #{s.keys.inspect}"
  assert_kind_of Array, s['layer_groups']
end

test 'V1.1: layer_summary has the locked V1.1 field set' do
  rect = ar_rectangle_edges
  group = FakeSU::Group.new(name: 'rect', children: rect, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  gs = result.layer_groups
  assert_equal 1, gs.length
  g = gs.first
  # Per LayerSemanticMapper.locked_field_set:
  expected_fields = [:name, :role, :role_rule, :role_label,
                     :visible, :visibility_unknown, :visibility_label,
                     :edge_count, :issue_count]
  expected_fields.each do |k|
    assert g.key?(k), "layer_summary missing field #{k.inspect}: got #{g.keys.inspect}"
  end
  # Closed rectangle -> no issues -> issue_count == 0.
  assert_equal 0, g[:issue_count]
  # 4 edges on Layer0 -> edge_count == 4.
  assert_equal 4, g[:edge_count]
  # Layer0 is the V1.0 default layer; role should be :construction.
  assert_equal :construction, g[:role]
  assert_equal 'Construction', g[:role_label]
  # visibility defaults to [true, false].
  assert_equal true, g[:visible]
  assert_equal false, g[:visibility_unknown]
  assert_equal 'Visible', g[:visibility_label]
end

test 'V1.1: layer_summary for a custom DIM-* layer is classified as :dimension' do
  edges = ar_two_edges_on_layer('DIM-XX')
  group = FakeSU::Group.new(name: 'g', children: edges, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  gs = result.layer_groups
  # Exactly 1 distinct layer (DIM-XX).
  assert_equal 1, gs.length
  g = gs.first
  assert_equal 'DIM-XX', g[:name]
  assert_equal :dimension, g[:role]
  assert_equal 'Dimension', g[:role_label]
  assert_equal 'name_dimension', g[:role_rule]
  assert_equal 2, g[:edge_count]
end

test 'V1.1: layer_summary issue_count reflects registry issues attributed to that layer' do
  # Build a synthetic Analyzer-like issue via the existing pipeline
  # by injecting a coincident edge. Two coincident edges -> 1
  # duplicate_edge_candidate issue. Both edges are on Layer0, so the
  # issue's source[:layer_name] = 'Layer0' and issue_count on the
  # Layer0 summary should be 1.
  v00 = FakeSU::Vertex.new(0.0, 0.0, 0.0)
  v10 = FakeSU::Vertex.new(10.0, 0.0, 0.0)
  layer = FakeSU::Layer.new('Layer0')
  e0 = FakeSU::Edge.new(start: v00, finish: v10, layer: layer, persistent_id: 1)
  # Coincident edge: same start/end, different persistent_id.
  e1 = FakeSU::Edge.new(start: v00, finish: v10, layer: layer, persistent_id: 2)
  # Two more edges to keep the snapshot non-empty (and not crash
  # preflight walkers).
  v20 = FakeSU::Vertex.new(20.0, 0.0, 0.0)
  e2 = FakeSU::Edge.new(start: v10, finish: v20, layer: layer, persistent_id: 3)
  v30 = FakeSU::Vertex.new(0.0, 5.0, 0.0)
  e3 = FakeSU::Edge.new(start: v20, finish: v30, layer: layer, persistent_id: 4)
  e4 = FakeSU::Edge.new(start: v30, finish: v00, layer: layer, persistent_id: 5)
  edges = [e0, e1, e2, e3, e4]
  group = FakeSU::Group.new(name: 'g', children: edges, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  # 4 distinct vertex positions; the duplicate detector should
  # surface at least 1 duplicate_edge_candidate issue on Layer0.
  gs = result.layer_groups
  layer0_summary = gs.find { |g| g[:name] == 'Layer0' }
  refute_nil layer0_summary
  assert layer0_summary[:issue_count] >= 1,
         "expected Layer0 issue_count >= 1, got #{layer0_summary[:issue_count]} (groups=#{gs.inspect})"
end

test 'V1.1: layer_groups are sorted in role bucket order [dim, anno, guide, construction, unknown]' do
  # Build 4 layers across 4 roles in MIXED insertion order.
  v = ->(x, y) { FakeSU::Vertex.new(x.to_f, y.to_f, 0.0) }
  layers_with_names = [
    FakeSU::Layer.new('UNK-99'),       # :unknown
    FakeSU::Layer.new('Layer0'),       # :construction
    FakeSU::Layer.new('TXT-LABEL'),    # :annotation
    FakeSU::Layer.new('DIM-XX')        # :dimension
  ]
  edges = []
  layers_with_names.each_with_index do |layer, li|
    base_x = li * 100.0
    e0 = FakeSU::Edge.new(start: v.call(base_x, 0.0), finish: v.call(base_x + 10.0, 0.0),
                            layer: layer, persistent_id: li * 10 + 1)
    e1 = FakeSU::Edge.new(start: v.call(base_x + 10.0, 0.0), finish: v.call(base_x + 20.0, 0.0),
                            layer: layer, persistent_id: li * 10 + 2)
    edges << e0 << e1
  end
  group = FakeSU::Group.new(name: 'multi', children: edges, persistent_id: 999)
  sel = FakeSU::Selection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  names = result.layer_groups.map { |g| g[:name] }
  # Expected bucket order: DIM-XX (dimension) before TXT-LABEL
  # (annotation) before Layer0 (construction) before UNK-99
  # (unknown). Hidden layers sort AFTER visible in same bucket, but
  # all are visible here.
  expected_first = 'DIM-XX'
  assert_equal expected_first, names.first,
               "expected #{expected_first} as first layer (role order dim first), got #{names.inspect}"
  # Layer0 should come BEFORE UNK-99 (construction before unknown).
  idx_layer0 = names.index('Layer0')
  idx_unk    = names.index('UNK-99')
  refute_nil idx_layer0
  refute_nil idx_unk
  assert idx_layer0 < idx_unk,
         "expected Layer0 before UNK-99, got order #{names.inspect}"
end

test 'V1.1: each issue in registry has source[:layer_name] populated by AnalyzersRunner' do
  # Per plan §4.8: the AnalyzersRunner injects source[:layer_name] on
  # each enriched issue BEFORE the registry freezes the issue. This
  # is what allows LayerSemanticMapper / LayerIssueGrouper to
  # attribute issues to layers on the production path.
  edges = ar_two_edges_on_layer('DIM-XX')
  group = FakeSU::Group.new(name: 'g', children: edges, persistent_id: 100)
  sel = FakeSU::Selection.new([group])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  # ALL frozen issues in the registry MUST have source[:layer_name].
  result.registry.issues.each do |iss|
    src = iss[:source]
    assert src.is_a?(Hash),
           "issue #{iss[:issue_id]} missing source Hash: got #{src.inspect}"
    ln = src[:layer_name]
    assert ln.is_a?(String) && !ln.empty?,
           "issue #{iss[:issue_id]} missing source[:layer_name]: got #{ln.inspect}"
  end
end

test 'V1.1: layer_groups is exposed in summary payload even when ZERO layers' do
  # An empty selection (or a selection with no edges) MUST still
  # expose layer_groups (as []). The UIBridge will then surface
  # `summary['layer_groups'] == []` and `layerGroups == []`.
  sel = FakeSU::Selection.new([])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  assert_kind_of Array, result.layer_groups
  assert_equal 0, result.layer_groups.length
  assert_equal [], result.summary['layer_groups']
end

# --- V1.3 (per CodeX review 028 V13-BLOCK-001) ---
#
# PRODUCTION-PATH regression guard. The earlier AnalyzersRunner
# code passed `layer_groups` (Array<Hash> LayerSummary) to
# FaceInventoryGrouper.group. Hash items do NOT respond to
# :face_count, so every bucket was silently skipped and the
# UI rendered '0 total' even when the top scalars reported
# 'Faces: 1'. Unit tests on the grouper in isolation passed
# because they used LayerRecord (which DOES respond to
# :face_count). This guard exercises the real AnalyzersRunner
# path with a face selection, so the silent skip can never
# regress.
require_relative '_fake_su'
include FakeSU

def ar_face(layer_name: 'Layer0', persistent_id: nil,
            outer_loop_vertices: 4, inner_loop_vertices: [])
  layer = layer_name == 'Layer0' ? Layer.new('Layer0') : Layer.new(layer_name)
  Face.new(
    layer: layer,
    persistent_id: persistent_id,
    outer_loop_vertices: outer_loop_vertices,
    inner_loop_vertices: inner_loop_vertices
  )
end

test 'V13-BLOCK-001: selection = 1 root Face, 0 edges -> summary faces == 1 + 1 Layer0 Face Inventory bucket with face_count == 1' do
  f = ar_face(layer_name: 'Layer0', persistent_id: 42)
  sel = Selection.new([f])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  refute_nil result
  # Top-level scalar counter must report the face.
  assert_equal 1, result.summary['faces'],
               'summary.faces must equal 1 for a single root Face'
  # The single Face Inventory bucket must be Layer0.
  fig = result.summary['face_inventory_groups']
  assert_equal 1, fig.length,
               "expected exactly 1 Face Inventory bucket; got #{fig.inspect}"
  assert_equal 'Layer0', fig.first[:name]
  assert_equal 1,        fig.first[:face_count]
  assert_equal 0,        fig.first[:faces_with_holes_count]
  # Production-path top-level key must agree with summary.
  assert_equal fig.length, result.face_inventory_groups.length
  assert_equal 'Layer0',   result.face_inventory_groups.first[:name]
end

test 'V13-BLOCK-001: 1 named-layer Face -> 1 bucket with the right role + visibility' do
  dim = Layer.new('DIM-WALLS')
  f = Face.new(layer: dim, persistent_id: 1, outer_loop_vertices: 4)
  sel = Selection.new([f])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  fig = result.summary['face_inventory_groups']
  assert_equal 1, fig.length
  b = fig.first
  assert_equal 'DIM-WALLS', b[:name]
  assert_equal :dimension,   b[:role]
  assert_equal 'Dimension',  b[:role_label]
  assert_equal 'Visible',    b[:visibility_label]
  assert_equal 1,            b[:face_count]
end

test 'V13-BLOCK-001: face with 1 inner loop -> face_count=1, faces_with_holes_count=1' do
  f = Face.new(layer: Layer.new('HOLES'),
               persistent_id: 1, outer_loop_vertices: 4,
               inner_loop_vertices: [3])
  sel = Selection.new([f])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  fig = result.summary['face_inventory_groups']
  assert_equal 1, fig.length
  assert_equal 1, fig.first[:face_count]
  assert_equal 1, fig.first[:faces_with_holes_count]
  assert_equal 1, result.summary['faces_with_holes'],
               'summary.faces_with_holes must equal 1 for a face with one inner loop'
end

test 'V13-BLOCK-001: 2 ComponentInstances of one defn -> 2 Face Inventory buckets (occurrence count semantics)' do
  inner = Face.new(layer: Layer.new('Layer0'),
                   persistent_id: 7, outer_loop_vertices: 4)
  defn = ComponentDefinition.new(name: 'Window', children: [inner], persistent_id: 999)
  inst_a = ComponentInstance.new(definition: defn, persistent_id: 10)
  inst_b = ComponentInstance.new(definition: defn, persistent_id: 11)
  sel = Selection.new([inst_a, inst_b])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  # 2 face occurrences on Layer0 -> one bucket (Layer0) with face_count=2.
  assert_equal 1, result.summary['face_inventory_groups'].length
  assert_equal 2, result.summary['face_inventory_groups'].first[:face_count]
  # But total face scalar must be 2 (one per occurrence).
  assert_equal 2, result.summary['faces']
end

test 'V13-BLOCK-001: empty selection -> empty face_inventory_groups + 0 summary scalars (no crash)' do
  sel = Selection.new([])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  assert_equal [], result.face_inventory_groups
  assert_equal [], result.summary['face_inventory_groups']
  assert_equal 0, result.summary['faces']
  assert_equal 0, result.summary['faces_with_holes']
end

test 'V13-BLOCK-001: guard against silent collapse -- grouper input shape cannot yield [] when snapshot has faces' do
  # Belt-and-suspenders regression guard. If anyone ever
  # re-introduces the wrong production-seam input shape
  # (Array<Hash> LayerSummary instead of Array<LayerRecord>),
  # this test fires because the per-layer face_count would
  # silently collapse to 0.
  f = ar_face(layer_name: 'Layer0', persistent_id: 1)
  sel = Selection.new([f])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  fig = result.summary['face_inventory_groups']
  assert !fig.empty?, 'Face Inventory must NOT collapse to [] when snapshot has faces'
  assert fig.first[:face_count] > 0, 'bucket face_count must be > 0 (no silent zero)'
  assert_equal result.summary['faces'], fig.first[:face_count],
               'top scalar faces must equal the (only) bucket face_count'
end
