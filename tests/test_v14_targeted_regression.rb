#
# tests/test_v14_targeted_regression.rb — V1.4 targeted regression tests
# added after the V14 Gate 2 real-SU2020 Owner run (2026-08-24).
#
# Scope: the Owner observed the following test-flow risks that should be
# automated so future runs do not silently regress:
#
#   - V14-8 failure injection: the generic one-shot begin_operation patch
#     can be CONSUMED by the prior Discard begin_operation. The Owner
#     run used a label-targeted patch that only injects when the operation
#     label includes the workspace Prepare path. This file pins that
#     contract with executable regressions.
#
#   - V14-10 shared-definition wording: the V14 Gate 2 Owner evidence
#     captured 8 independent derived edge occurrences (2 instances x 4
#     edges per definition). DANGER 3 in test_v14_dangerous_failure_modes.rb
#     already covers the 2-edge case at the pure-Ruby adapter level;
#     this file adds a 4-edge x 2-instance production-adapter test.
#
#   - V14-10 new-selection-must-re-Analyze: if a test helper reuses an
#     AnalysisResult across selections, the helper must construct a NEW
#     AnalysisResult for the new selection. The Owner observed
#     WORLD_COORDINATES_MATCH=false due to a stale SourceSnapshot in a
#     helper. This file pins the "fresh AnalysisResult per selection"
#     contract for the production call chain.
#
# These tests are additive to the existing V1.4 risk tests. They do NOT
# change production behavior, V1.0-V1.3 scope, or V1.5 plans.
#

require_relative 'runner'
require_relative '_fake_ui'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/analysis_config'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/face_record'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/vertex_record'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/source_snapshot'
require_relative '../extension/su_ai_plugin/core/derived_entity_record'
require_relative '../extension/su_ai_plugin/core/derived_workspace_fingerprint'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'
require_relative '../extension/su_ai_plugin/compatibility/su_derived_workspace_adapter'

include SUAnalysis::Core
include FakeUI

# ---- V14-8 label-targeted one-shot regression ----

# The Owner V14-8 patch targets ONLY the workspace Prepare begin_operation
# label ("SU-AI-Plugin: V1.4 Working Copy Prepare"). Discard / Discard-
# cleanup operations also call begin_operation, but with labels that do
# NOT match. This contract MUST hold:

test 'V14-TARGETED-1: label-targeted one-shot patch is installed BEFORE any click (probe check)' do
  adapter_class = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter
  original = adapter_class.instance_method(:begin_operation)
  target_label = 'SU-AI-Plugin: V1.4 Working Copy Prepare'

  adapter_class.class_eval do
    define_method(:begin_operation) do |model, label:|
      if label.to_s.include?(target_label)
        adapter_class.class_eval do
          define_method(:begin_operation, original)
        end
        raise StandardError, 'v14-gate-2-injected-failure'
      else
        original.bind(self).call(model, label: label)
      end
    end
  end

  pre = adapter_class.instance_method(:begin_operation)
  refute_equal original, pre,
               'patch MUST be installed BEFORE any click (instance_method differs from original)'
ensure
  # Restore (always -- even if assertions fail -- so subsequent tests
  # see the original method).
  if defined?(adapter_class) && defined?(original)
    adapter_class.class_eval do
      define_method(:begin_operation, original)
    end
  end
end

test 'V14-TARGETED-2: label-targeted one-shot patch passes through Discard label (does NOT inject)' do
  adapter_class = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter
  original = adapter_class.instance_method(:begin_operation)
  target_label = 'SU-AI-Plugin: V1.4 Working Copy Prepare'

  adapter_class.class_eval do
    define_method(:begin_operation) do |model, label:|
      if label.to_s.include?(target_label)
        adapter_class.class_eval do
          define_method(:begin_operation, original)
        end
        raise StandardError, 'v14-gate-2-injected-failure'
      else
        original.bind(self).call(model, label: label)
      end
    end
  end

  # A Discard begin_operation MUST pass through to the original --
  # this is the regression we want to pin (the generic patch would
  # have injected here and the Discard would have failed instead of
  # Prepare).
  # The production adapter's begin_operation calls model.start_operation
  # when a model is provided. We call with a FakeUI FakeModel; we
  # assert no exception is raised and that the operation_log shows
  # the begin entry.
  m = FakeUI::FakeModel.new
  adapter_class.new.begin_operation(m, label: 'SU-AI-Plugin: V1.4 Derived Workspace -- Discard ws-1')
  assert_equal 1, m.operation_log.length,
               'Discard begin_operation MUST pass through to original (one entry in operation_log)'
  assert_equal :start, m.operation_log.first[:kind]
  assert_match(/Discard ws-1/, m.operation_log.first[:label],
               'Discard label MUST be preserved on the operation_log entry')
ensure
  if defined?(adapter_class) && defined?(original)
    adapter_class.class_eval do
      define_method(:begin_operation, original)
    end
  end
end

test 'V14-TARGETED-3: label-targeted one-shot patch fires on Prepare label and restores itself' do
  adapter_class = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter
  original = adapter_class.instance_method(:begin_operation)
  target_label = 'SU-AI-Plugin: V1.4 Working Copy Prepare'

  adapter_class.class_eval do
    define_method(:begin_operation) do |model, label:|
      if label.to_s.include?(target_label)
        adapter_class.class_eval do
          define_method(:begin_operation, original)
        end
        raise StandardError, 'v14-gate-2-injected-failure'
      else
        original.bind(self).call(model, label: label)
      end
    end
  end

  # (a) The patch is installed BEFORE the Prepare click -- probe check.
  refute_equal original, adapter_class.instance_method(:begin_operation),
               'patch MUST be installed BEFORE the Prepare click'

  # (b) The Prepare begin_operation call MUST raise the injected failure.
  raised = false
  begin
    adapter_class.new.begin_operation(FakeUI::FakeModel.new,
                                    label: 'SU-AI-Plugin: V1.4 Working Copy Prepare')
  rescue StandardError => e
    raised = true
    assert_match(/v14-gate-2-injected-failure/, e.message,
                 'Prepare begin_operation MUST raise the injected failure')
  end
  assert raised, 'Prepare begin_operation MUST raise (V14-TARGETED-3)'

  # (c) The patch is self-restored AFTER the Prepare call.
  assert_equal original, adapter_class.instance_method(:begin_operation),
               'patch MUST be self-restored AFTER the Prepare begin_operation call'

  # (d) A subsequent Discard begin_operation MUST work normally
  # (no leftover patch).
  m = FakeUI::FakeModel.new
  adapter_class.new.begin_operation(m,
                                    label: 'SU-AI-Plugin: V1.4 Derived Workspace -- Discard ws-2')
  assert_equal 1, m.operation_log.length,
               'subsequent Discard begin_operation MUST NOT raise (patch self-restored)'

  # (e) The restored method MUST have the SAME source_location as
  # the original (Ruby recreates the UnboundMethod object on
  # define_method, but the source location is preserved -- this is
  # the strongest behavioral check we can do without holding the
  # original UnboundMethod object across define_method).
  restored = adapter_class.instance_method(:begin_operation)
  assert_equal original.source_location, restored.source_location,
               'restored method MUST share source_location with the original'
end

test 'V14-TARGETED-4: full Prepare -> Discard -> Prepare cycle with label-targeted patch installed' do
  # The end-to-end Owner-flow scenario: install the label-targeted
  # patch, then run Discard (must pass through), then Prepare (must
  # fire the injection). After the cycle, the patch must be gone.
  adapter_class = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter
  original = adapter_class.instance_method(:begin_operation)
  target_label = 'SU-AI-Plugin: V1.4 Working Copy Prepare'

  adapter_class.class_eval do
    define_method(:begin_operation) do |model, label:|
      if label.to_s.include?(target_label)
        adapter_class.class_eval do
          define_method(:begin_operation, original)
        end
        raise StandardError, 'v14-gate-2-injected-failure'
      else
        original.bind(self).call(model, label: label)
      end
    end
  end

  m = FakeUI::FakeModel.new
  # (1) Patch is installed -- probe check.
  refute_equal original, adapter_class.instance_method(:begin_operation),
               'patch MUST be installed at cycle start'

  # (2) Discard begin_operation passes through (label does NOT match).
  adapter_class.new.begin_operation(m,
                                    label: 'SU-AI-Plugin: V1.4 Derived Workspace -- Discard ws-3')
  assert_equal 1, m.operation_log.length,
               'Discard begin_operation MUST pass through (no patch consumption)'

  # (3) Prepare begin_operation fires the injection.
  raised_prepare = false
  begin
    adapter_class.new.begin_operation(m,
                                      label: 'SU-AI-Plugin: V1.4 Working Copy Prepare')
  rescue StandardError
    raised_prepare = true
  end
  assert raised_prepare, 'Prepare begin_operation MUST fire the injection'

  # (4) Patch is self-restored.
  assert_equal original, adapter_class.instance_method(:begin_operation),
               'patch MUST be self-restored after Prepare begin_operation'

  # (5) A subsequent Discard begin_operation works normally.
  adapter_class.new.begin_operation(m,
                                    label: 'SU-AI-Plugin: V1.4 Derived Workspace -- Discard ws-3')
  assert_equal 2, m.operation_log.length,
               'subsequent Discard begin_operation MUST work normally'
ensure
  if defined?(adapter_class) && defined?(original)
    adapter_class.class_eval do
      define_method(:begin_operation, original)
    end
  end
end

# ---- V14-10 shared-definition production-adapter regression ----

def v14_shared_def_install_fake_su(model)
  unless Object.const_defined?(:Sketchup)
    Object.const_set(:Sketchup, Module.new)
  end
  Sketchup.define_singleton_method(:active_model) { model }
  unless model.respond_to?(:active_entities)
    model.define_singleton_method(:active_entities) { :fake_active_entities }
  end
end

def v14_shared_def_uninstall_fake_su
  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
end

def v14_shared_def_source_with_two_instances(definition_persistent_id, edges_per_instance)
  # edges_per_instance: Array of Hashes {instance_id, edges: [{pid, start, end}]}
  # Builds a SourceSnapshot whose edges are world-space occurrences:
  # one occurrence per (definition-edge x instance) pair.
  edges = []
  edges_per_instance.each do |instance_spec|
    instance_id = instance_spec[:instance_id]
    instance_spec[:edges].each_with_index do |edge_spec, idx|
      edges << EdgeRecord.new(
        id: edges.length,
        source: SourceReference.new(
          entity_id: (definition_persistent_id * 1000) + (instance_id * 100) + idx,
          persistent_id: edge_spec[:pid],
          kind: 'edge',
          persistent_id_path: [definition_persistent_id, instance_id],
          instance_path: [],
          structural_depth: 1,
          pid_path_complete: true,
          layer_name: 'Layer0'
        ),
        start_point: edge_spec[:start],
        end_point:   edge_spec[:end],
        layer: 'Layer0'
      )
    end
  end
  layers = [LayerRecord.new(name: 'Layer0')]
  geom = GeometrySnapshot.new(edges: edges, layers: layers)
  ec = ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'shared-def-4x2'),
    rule_set_digest: 'shared-def-4x2.rule-set',
    source_snapshot_schema_version: '1'
  )
  SourceSnapshot.from_geometry_snapshot(
    geom, selection: [], execution_config: ec,
    rule_set_digest: 'shared-def-4x2.rule-set',
    snapshot_id: 'shared-def-4x2-snap',
    captured_at: '2026-08-24T00:00:00Z'
  )
end

test 'V14-TARGETED-5: shared-definition 4-edge x 2-instance -> 8 INDEPENDENT derived edge occurrences' do
  # Per the V14 Gate 2 Owner evidence (2026-08-24):
  # SHARED_EDGE_COUNT=8 (2 instances x 4 edges per definition),
  # WORLD_COORDINATES_MATCH=true, UNIQUE_PID_PATHS=8, INSTANCE_OCCURRENCES=2.
  # DANGER 3 covers the 2-edge case at the pure-Ruby adapter level.
  # This test pins the 4-edge x 2-instance case via the PRODUCTION
  # adapter + FakeUI::FakeModel.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_shared_def_install_fake_su(model)
    src = v14_shared_def_source_with_two_instances(
      5000, [
        { instance_id: 8001, edges: [
          { pid: 5001, start: [0.0, 0.0, 0.0], end: [10.0, 0.0, 0.0] },
          { pid: 5002, start: [10.0, 0.0, 0.0], end: [10.0, 5.0, 0.0] },
          { pid: 5003, start: [10.0, 5.0, 0.0], end: [0.0, 5.0, 0.0] },
          { pid: 5004, start: [0.0, 5.0, 0.0], end: [0.0, 0.0, 0.0] }
        ] },
        { instance_id: 8002, edges: [
          { pid: 5001, start: [100.0, 100.0, 0.0], end: [110.0, 100.0, 0.0] },
          { pid: 5002, start: [110.0, 100.0, 0.0], end: [110.0, 105.0, 0.0] },
          { pid: 5003, start: [110.0, 105.0, 0.0], end: [100.0, 105.0, 0.0] },
          { pid: 5004, start: [100.0, 105.0, 0.0], end: [100.0, 100.0, 0.0] }
        ] }
      ]
    )
    adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
    SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: model)
    snap = SUAnalysis::Core::WorkingModeRunner.snapshot
    assert_equal 'ready', snap['state'],
                 'shared-definition 4-edge x 2-instance Prepare MUST reach :ready'
    # 8 derived groups total (one per source edge occurrence).
    assert_equal 8, model.entities.groups.length,
                 'shared-definition 4-edge x 2-instance MUST produce 8 derived groups'
    # Each group carries exactly one Edge (no Face fabrication).
    all_edges = []
    model.entities.groups.each do |g|
      ents = g.respond_to?(:entities) ? g.entities : g.children
      all_edges.concat(ents.edges) if ents.respond_to?(:edges)
    end
    assert_equal 8, all_edges.length,
                 'each derived group MUST carry exactly one Edge (8 total)'
    # The 8 derived edges MUST map 1:1 with the 8 source edge
    # occurrences (NOT collapsed by shared definition).
    assert_equal 8, src.edges.length,
                 'source snapshot MUST have 8 edge occurrences'
    # Verify each derived Edge carries the SAME world-coordinate
    # XYZ as its source occurrence (snapshot-local identity
    # distinct from host identity, per directive gate A).
    src.edges.zip(all_edges).each_with_index do |(src_edge, derived_edge), idx|
      assert_equal src_edge.start_point, derived_edge.start,
                   "derived edge #{idx} start MUST equal source edge start (XYZ)"
      assert_equal src_edge.end_point,   derived_edge.end,
                   "derived edge #{idx} end MUST equal source edge end (XYZ)"
    end
    # Verify two source edges with the SAME leaf persistent_id
    # (definition edge pid) but different instance_id get
    # DIFFERENT snapshot-local occurrence IDs.
    leaf_pids = src.edges.map { |e| e.source.persistent_id }
    pair_indices = leaf_pids.each_with_index.select { |p, _| p == 5001 }.map { |_, i| i }
    assert_equal 2, pair_indices.length,
                 'two occurrences with the same leaf pid (definition edge) MUST be present'
    src_a, src_b = src.edges[pair_indices[0]], src.edges[pair_indices[1]]
    occ_a = src_a.source.persistent_id_path.join('>')
    occ_b = src_b.source.persistent_id_path.join('>')
    refute_equal occ_a, occ_b,
                 'shared-definition occurrences MUST have DISTINCT full PID paths'
  ensure
    v14_shared_def_uninstall_fake_su
    FakeUI.uninstall!
    SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  end
end

# ---- V14-10 new-selection-must-re-Analyze regression ----

# This test pins the contract: when a fresh selection is made, the
# controller must build a NEW AnalysisResult for that selection. Reusing
# an old AnalysisResult (and its old SourceSnapshot) for a different
# selection is an OWNER TEST-FLOW ERROR -- it can produce stale-derived
# world coordinates even though the production code is correct.

# Helper: build a minimal AnalysisResult for a given set of source edges.
def v14_targeted_fresh_analysis_result(edges_specs)
  # edges_specs: Array of {pid, start, end, pid_path}
  # Returns [analysis_result, source_snapshot]. The AnalysisResult is
  # frozen (per its invariant); we do not attach a singleton method
  # to it (would raise FrozenError). Instead the caller keeps the
  # SourceSnapshot alongside.
  edges = edges_specs.each_with_index.map do |spec, idx|
    EdgeRecord.new(
      id: idx,
      source: SourceReference.new(
        entity_id: 1000 + idx,
        persistent_id: spec[:pid],
        kind: 'edge',
        persistent_id_path: spec[:pid_path],
        instance_path: [],
        structural_depth: (spec[:pid_path] || []).length,
        pid_path_complete: true,
        layer_name: 'Layer0'
      ),
      start_point: spec[:start],
      end_point:   spec[:end],
      layer: 'Layer0'
    )
  end
  layers = [LayerRecord.new(name: 'Layer0')]
  geom = GeometrySnapshot.new(edges: edges, layers: layers)
  ec = ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'fresh-ar'),
    rule_set_digest: 'fresh-ar.rule-set',
    source_snapshot_schema_version: '1'
  )
  src_snap = SourceSnapshot.from_geometry_snapshot(
    geom, selection: [], execution_config: ec,
    rule_set_digest: 'fresh-ar.rule-set',
    snapshot_id: "fresh-ar-snap-#{rand(2**32)}",
    captured_at: '2026-08-24T00:00:00Z'
  )
  pf = PreflightAnalyzer.run(geom)
  reg = IssueRegistry.new([])
  ar = AnalysisResult.new(
    preflight:       pf,
    registry:        reg,
    selection_type:  'Edges',
    selection_label: "#{edges.length} edges",
    geometry_snapshot: geom,
    selection_entities: [],
    active_edit_facts:  { 'active_edit_seed' => 'identity' }
  )
  [ar, src_snap]
end

test 'V14-TARGETED-6: a fresh AnalysisResult for a new selection produces a SourceSnapshot whose edges match the new selection' do
  # Selection 1: 4 edges around (0,0) -> (10,5)
  _ar1, snap1 = v14_targeted_fresh_analysis_result([
    { pid: 2001, pid_path: [2001], start: [0.0, 0.0, 0.0],  end: [10.0, 0.0, 0.0] },
    { pid: 2002, pid_path: [2002], start: [10.0, 0.0, 0.0], end: [10.0, 5.0, 0.0] },
    { pid: 2003, pid_path: [2003], start: [10.0, 5.0, 0.0], end: [0.0, 5.0, 0.0] },
    { pid: 2004, pid_path: [2004], start: [0.0, 5.0, 0.0],  end: [0.0, 0.0, 0.0] }
  ])
  refute_nil snap1
  assert_equal 4, snap1.edges.length
  assert_equal [0.0, 0.0, 0.0], snap1.edges.first.start_point

  # Selection 2: 4 edges around (100, 100) -> (110, 105). A FRESH
  # AnalysisResult is required; reusing the previous snapshot would
  # produce stale coordinates.
  _ar2, snap2 = v14_targeted_fresh_analysis_result([
    { pid: 2001, pid_path: [2001], start: [100.0, 100.0, 0.0], end: [110.0, 100.0, 0.0] },
    { pid: 2002, pid_path: [2002], start: [110.0, 100.0, 0.0], end: [110.0, 105.0, 0.0] },
    { pid: 2003, pid_path: [2003], start: [110.0, 105.0, 0.0], end: [100.0, 105.0, 0.0] },
    { pid: 2004, pid_path: [2004], start: [100.0, 105.0, 0.0], end: [100.0, 100.0, 0.0] }
  ])
  refute_nil snap2
  assert_equal 4, snap2.edges.length
  assert_equal [100.0, 100.0, 0.0], snap2.edges.first.start_point,
               'fresh AnalysisResult MUST produce a SourceSnapshot whose edges match the new selection'
  refute_equal snap1.snapshot_id, snap2.snapshot_id,
               'fresh AnalysisResult MUST produce a NEW snapshot_id (not reuse the old one)'
  refute_equal snap1.fingerprint.digest, snap2.fingerprint.digest,
               'fresh AnalysisResult MUST produce a DIFFERENT source fingerprint (different source)'
end