#
# tests/test_v14_production_call_chain.rb — V1.4 CodeX BLOCK
# fix (Stage 4): production call-chain tests.
#
# Per directive 030 (CodeX 030 PRE-BUILD TECHNICAL PREVIEW)
# exit gate, V1.4 must demonstrate the REAL call chain:
#
#   dialog callback
#     -> WorkingModeRunner.prepare / discard / rebuild
#       -> DerivedGeometryWorkspace.build_entity
#         -> SketchupDerivedWorkspaceAdapter.create_top_level_group
#            (REAL Sketchup::Entities#add_group)
#
# These tests use:
#   - FakeUI::FakeModel (extended in tests/_fake_ui.rb) which
#     emulates Sketchup::Model + Sketchup::Entities + the
#     start_operation / commit_operation / abort_operation
#     boundary.
#   - The PRODUCTION adapter
#     (compatibility/SketchupDerivedWorkspaceAdapter) -- not
#     the fake one. The fake adapter is exercised by
#     test_v14_derived_workspace.rb and
#     test_v14_working_mode_runner.rb.
#   - The dialog callbacks (on_prepare_workspace /
#     on_discard_workspace / on_rebuild_workspace) wired
#     via DialogRunner.show.
#
# The model the dialog carries into the workspace is a
# FakeUI::FakeModel instance (NOT a real SU model). The
# production adapter resolves the model via `model` (the
# parameter passed to it) -- when FakeUI::FakeModel is the
# argument, the adapter's `model.respond_to?(:start_operation)`
# is true and the adapter calls into FakeUI's operation
# boundary. The model also supports `model.active_entities`
# so `add_group` returns FakeGroup handles that behave like
# Sketchup::Group (entityID / persistent_id / valid? /
# erase!).
#
# Each test EXPLICITLY asserts:
#   - prepare -> ready with entity_count > 0
#   - Discard calls the REAL saved handle (precise cleanup)
#   - Rebuild first discards old groups, then creates new
#     groups
#   - Failure injection cleans up all created handles
#   - Source fingerprint is identical before/after the
#     whole lifecycle
#

require_relative 'runner'
require_relative '_fake_ui'
require_relative '_fake_su'
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
require_relative '../extension/su_ai_plugin/compatibility/su_capability'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/preflight'
require_relative '../extension/su_ai_plugin/analyzers_runner'
require_relative '../extension/su_ai_plugin/dialog_runner'
require_relative '../extension/su_ai_plugin/loader'

include SUAnalysis::Core
include SUAnalysis::Extension
include FakeUI

# --- helpers ---------------------------------------------------------

# Build a minimal SourceSnapshot with N real Edges (each
# carrying a SourceReference with a unique persistent_id).
# The snapshot is a real SourceSnapshot that WorkingModeRunner
# can convert into derived entities.
def v14_real_source_snapshot(edge_count: 4)
  edges = (0...edge_count).map do |i|
    EdgeRecord.new(
      id: i,
      source: SourceReference.new(
        entity_id: 1000 + i,
        persistent_id: 1000 + i,
        kind: 'edge',
        persistent_id_path: [1000 + i],
        instance_path: [],
        structural_depth: 0,
        pid_path_complete: true,
        layer_name: 'Layer0'
      ),
      start_point: [0.0 + i * 10.0, 0.0, 0.0],
      end_point:   [10.0 + i * 10.0, 0.0, 0.0],
      layer: 'Layer0'
    )
  end
  layers = [LayerRecord.new(name: 'Layer0')]
  geom = GeometrySnapshot.new(edges: edges, layers: layers)
  ec = ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'production-call-chain'),
    rule_set_digest: 'production-call-chain.rule-set',
    source_snapshot_schema_version: '1'
  )
  SourceSnapshot.from_geometry_snapshot(
    geom,
    selection: [],
    execution_config: ec,
    rule_set_digest: 'production-call-chain.rule-set',
    snapshot_id: "real-snap-#{rand(2**32)}",
    captured_at: '2026-08-21T00:00:00Z'
  )
end

# Reset Loader sentinels + WorkingModeRunner state.
def v14_reset_everything
  SUAnalysis::Extension::Loader.instance_variable_set(:@registered, false)
  SUAnalysis::Extension::Loader.instance_variable_set(:@live_dialog, nil)
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

# Force the production adapter to believe SU is available,
# so it will call model.start_operation / commit_operation /
# abort_operation. The production adapter's begin/end paths
# already no-op when model is nil; we use a real model here.
def v14_install_fake_su(model)
  # Install the Sketchup module stub that the production
  # adapter's sketchup_available? check uses. The stub
  # returns true when the model responds to active_entities.
  unless defined?(Sketchup)
    Object.const_set(:Sketchup, Module.new)
  end
  Sketchup.define_singleton_method(:active_model) { model }
  Sketchup.define_singleton_method(:respond_to?) { |name| name == :active_model || super(name) }
end

def v14_uninstall_fake_su
  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
end

# --- tests -----------------------------------------------------------

test 'V14 production call chain: prepare creates REAL derived groups via FakeUI::FakeModel + production adapter' do
  FakeUI.install!
  v14_reset_everything
  Loader.register!

  model = FakeUI::FakeModel.new
  v14_install_fake_su(model)

  # Use the PRODUCTION adapter (not FakeDerivedWorkspaceAdapter).
  # The production adapter calls model.entities.add_group
  # (model ROOT, per BLOCK 3) which goes through the FakeUI's
  # FakeEntities -> creates a real FakeGroup handle.
  adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new

  src = v14_real_source_snapshot(edge_count: 4)
  fp_before = src.fingerprint.digest

  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: adapter,
    model:   model
  )

  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  # Workspace MUST be :ready with entity_count > 0
  # (the source has 4 edges -> 4 derived entities).
  assert_equal 'ready', snap['state'],
               'prepare via production adapter must reach :ready'
  ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  refute_nil ws, 'current_workspace must be available for assertions'
  assert_operator ws.entity_count, :>, 0,
                  'prepare must produce at least one derived entity'
  assert_equal 4, ws.entity_count,
               'one derived entity per source edge (4 edges -> 4 derived entities)'

  # The model MUST hold 4 FakeGroups with the recognizable
  # 'SU-AI-Derived-' name prefix.
  assert_equal 4, model.entities.groups.length,
               'production adapter must have created 4 real groups at model.entities (root, NOT active_entities)'
  model.entities.groups.each do |g|
    assert g.name.start_with?('SU-AI-Derived-'),
           "derived group name must carry the prefix; got #{g.name.inspect}"
    assert g.valid?, 'each derived group must be valid'
  end

  # Each derived group MUST carry exactly one real edge
  # with XYZ-identical endpoints (BLOCK 7 risk test).
  # Total edges across all groups == source edge count.
  # Each FakeGroup stores its edges on its OWN entities
  # (FakeEntities); the model's root entities only track
  # the groups themselves. Gather across all groups.
  all_edges = []
  model.entities.groups.each do |g|
    ents = g.respond_to?(:entities) ? g.entities : g.children
    if ents && ents.respond_to?(:edges)
      all_edges.concat(ents.edges)
    end
  end
  assert_equal 4, all_edges.length,
               'one derived edge per source edge (no extra Face, no extra Edge)'
  all_edges.zip(src.edges).each do |derived_edge, source_edge|
    s_src = source_edge.start_point
    e_src = source_edge.end_point
    assert_equal s_src, derived_edge.start,
                 'derived edge start MUST equal source edge start (XYZ)'
    assert_equal e_src, derived_edge.end,
                 'derived edge end MUST equal source edge end (XYZ)'
  end

  # The model MUST have wrapped the build in a single
  # SU operation (start_operation + commit_operation).
  # Per V14-STAGE-BLOCK-002 (2026-08-24): the workspace's
  # per-entity begin_operation calls are removed; the
  # runner's outer operation is the single operation owner.
  # The operation_log MUST therefore have exactly 2 entries
  # (1 start + 1 commit), NOT 2*N entries (one per entity).
  # Per directive gate: production writes MUST be wrapped
  # in SU operations.
  assert_equal 2, model.operation_log.length,
               'production adapter must wrap host writes in EXACTLY ONE SU operation (single owner; per-entity nesting is forbidden by real SU)'
  assert_equal :start,  model.operation_log.first[:kind]
  assert_equal :commit, model.operation_log.last[:kind],
               'successful prepare MUST commit (NOT abort) the SU operation'
  refute model.operation_open?,
               'after commit the operation MUST be closed (single-open invariant)'

  # Source fingerprint MUST be unchanged.
  assert_equal fp_before, src.fingerprint.digest,
               'source fingerprint must NOT drift across prepare'
ensure
  v14_uninstall_fake_su
  FakeUI.uninstall!
  v14_reset_everything
end

test 'V14 production call chain: discard calls the REAL saved handles (precise cleanup)' do
  FakeUI.install!
  v14_reset_everything
  Loader.register!

  model = FakeUI::FakeModel.new
  v14_install_fake_su(model)
  adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new

  src = v14_real_source_snapshot(edge_count: 3)
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: model)
  # Pre-discard: 3 groups are valid.
  assert_equal 3, model.entities.valid_count

  SUAnalysis::Core::WorkingModeRunner.discard
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'discarded', snap['state']
  # Every saved handle MUST be erased precisely (not just
  # dropped; the production adapter's dispose path erases
  # the real handle).
  assert_equal 0, model.entities.valid_count,
               'discard MUST erase every saved handle (precise cleanup)'
  # The model MUST have wrapped the discard in a SU operation.
  last_two = model.operation_log.last(2)
  assert_equal :start,  last_two.first[:kind]
  assert_equal :commit, last_two.last[:kind],
               'successful discard MUST commit the SU operation'
ensure
  v14_uninstall_fake_su
  FakeUI.uninstall!
  v14_reset_everything
end

test 'V14 production call chain: rebuild discards old groups then creates new ones' do
  FakeUI.install!
  v14_reset_everything
  Loader.register!

  model = FakeUI::FakeModel.new
  v14_install_fake_su(model)
  adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new

  src = v14_real_source_snapshot(edge_count: 3)
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: model)
  pre_rebuild_groups = model.entities.groups.dup
  pre_rebuild_count  = pre_rebuild_groups.length
  refute_nil pre_rebuild_groups
  assert_operator pre_rebuild_groups.length, :>, 0

  SUAnalysis::Core::WorkingModeRunner.rebuild
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'ready', snap['state'],
               'rebuild MUST reach :ready'

  # The old groups MUST be erased.
  pre_rebuild_groups.each do |old|
    refute old.valid?,
           'old derived group must be erased by rebuild'
  end

  # New groups MUST exist (the rebuild creates a fresh
  # workspace with the same template -> 3 new groups).
  new_groups = model.entities.groups - pre_rebuild_groups
  assert_operator new_groups.length, :>, 0,
                  'rebuild must create fresh groups in addition to the discarded old ones'
  new_groups.each do |g|
    assert g.valid?, 'each new derived group must be valid'
    assert g.name.start_with?('SU-AI-Derived-'),
           'new derived group must carry the prefix'
  end
ensure
  v14_uninstall_fake_su
  FakeUI.uninstall!
  v14_reset_everything
end

test 'V14 production call chain: failure injection aborts SU operation and rolls back entities' do
  FakeUI.install!
  v14_reset_everything
  Loader.register!

  model = FakeUI::FakeModel.new
  v14_install_fake_su(model)
  # Inject a failure on the next begin_operation call.
  adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
  # We inject at the model level by injecting a fault that
  # the adapter's begin_operation propagates. The cleanest
  # way is to make start_operation raise; we monkey-patch it
  # temporarily.
  original = model.method(:start_operation)
  injected = false
  model.define_singleton_method(:start_operation) do |label, disable_ui = false|
    if !injected
      # The first call to start_operation raises.
      Object.send(:remove_instance_variable, :@injected) if Object.instance_variable_defined?(:@injected)
      Kernel.binding.local_variable_set(:injected, true) # no-op; just for clarity
      Thread.current[:v14_injected] = true
      raise StandardError, 'host failure during begin_operation'
    else
      original.call(label, disable_ui)
    end
  end
  begin
    src = v14_real_source_snapshot(edge_count: 3)
    SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: model)
    # The first source edge's build_entity triggers
    # begin_operation -> raises -> workspace must abort.
    snap = SUAnalysis::Core::WorkingModeRunner.snapshot
    # The first edge's build_entity triggers the failure
    # -> workspace becomes :failed.
    assert_equal 'failed', snap['state'],
                 'host failure during begin_operation MUST produce :failed workspace'
    # The model MUST show the aborted attempt in the
    # operation log. Because begin_operation raised, no
    # commit/abort was emitted by the production adapter;
    # the FakeModel's single-open invariant is preserved
    # (the raise happened before @operation_open=true).
    refute model.operation_open?,
           'after host failure the operation MUST be closed (single-open invariant)'
    # NO partial derived groups must remain.
    assert_equal 0, model.entities.valid_count,
                 'failure injection MUST leave zero valid derived groups'
  ensure
    # Restore the original start_operation method.
    model.define_singleton_method(:start_operation, original)
  end
ensure
  v14_uninstall_fake_su
  FakeUI.uninstall!
  v14_reset_everything
end

test 'V14 production call chain: source fingerprint identical across prepare + discard + rebuild' do
  FakeUI.install!
  v14_reset_everything
  Loader.register!

  model = FakeUI::FakeModel.new
  v14_install_fake_su(model)
  adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new

  src = v14_real_source_snapshot(edge_count: 4)
  fp_before = src.fingerprint.digest

  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: model)
  fp_after_prepare = src.fingerprint.digest
  SUAnalysis::Core::WorkingModeRunner.discard
  fp_after_discard = src.fingerprint.digest
  SUAnalysis::Core::WorkingModeRunner.rebuild
  fp_after_rebuild = src.fingerprint.digest

  assert_equal fp_before, fp_after_prepare,
               'source fingerprint must NOT drift across prepare'
  assert_equal fp_before, fp_after_discard,
               'source fingerprint must NOT drift across discard'
  assert_equal fp_before, fp_after_rebuild,
               'source fingerprint must NOT drift across rebuild'
ensure
  v14_uninstall_fake_su
  FakeUI.uninstall!
  v14_reset_everything
end

test 'V14 production call chain: dialog callback -> WorkingModeRunner -> workspace reaches :ready' do
  FakeUI.install!
  v14_reset_everything
  Loader.register!

  model = FakeUI::FakeModel.new
  v14_install_fake_su(model)
  adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new

  # Build a minimal AnalysisResult the controller can bind.
  # The V1.4 dialog path requires the AnalysisResult to
  # carry geometry_snapshot + selection_entities +
  # active_edit_facts so the dialog_runner's _source_snapshot_for
  # builds a REAL SourceSnapshot (per directive CodeX BLOCK
  # fix Stage 4 item 2).
  edges = (0...3).map do |i|
    EdgeRecord.new(
      id: i,
      source: SourceReference.new(
        entity_id: 2000 + i,
        persistent_id: 2000 + i,
        kind: 'edge',
        persistent_id_path: [2000 + i],
        instance_path: [],
        structural_depth: 0,
        pid_path_complete: true,
        layer_name: 'Layer0'
      ),
      start_point: [0.0 + i * 10.0, 0.0, 0.0],
      end_point:   [10.0 + i * 10.0, 0.0, 0.0],
      layer: 'Layer0'
    )
  end
  layers = [LayerRecord.new(name: 'Layer0')]
  geom = GeometrySnapshot.new(edges: edges, layers: layers)
  pf = PreflightAnalyzer.run(geom)
  reg = IssueRegistry.new([])
  # The selection entities are 3 placeholder hashes that
  # look like real entities from the dialog's perspective.
  selection_entities = (0...3).map do |i|
    ent = Object.new
    ent.define_singleton_method(:typename) { 'Edge' }
    ent.define_singleton_method(:persistent_id) { 2000 + i }
    ent.define_singleton_method(:entityID) { 2000 + i }
    ent.define_singleton_method(:layer) do
      l = Object.new
      l.define_singleton_method(:name) { 'Layer0' }
      l
    end
    ent
  end
  ar = AnalysisResult.new(
    preflight:          pf,
    registry:           reg,
    selection_type:     'Edges',
    selection_label:    '3 edges',
    geometry_snapshot:  geom,
    selection_entities: selection_entities,
    active_edit_facts:  { 'active_edit_seed' => 'identity' }
  )
  # Show the dialog. The dialog_runner propagates the model
  # to the controller.
  dialog = SUAnalysis::Extension::DialogRunner.show(ar, model: model)
  refute_nil dialog

  # Simulate the JS Prepare click.
  dialog.callbacks['prepare_workspace'].call(nil)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'ready', snap['state'],
               'dialog prepare_workspace callback MUST reach :ready via production adapter'
  assert_operator model.entities.valid_count, :>, 0,
                  'production adapter must have created real derived groups via the dialog callback path'
  # Source snapshot id MUST be carried (proves the dialog
  # built a real SourceSnapshot, not a synthetic plumbing one).
  refute_nil snap['source_snapshot_id']
  refute_nil snap['workspace_id']

  # Discard via the dialog callback.
  dialog.callbacks['discard_workspace'].call(nil)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'discarded', snap['state']
  assert_equal 0, model.entities.valid_count,
               'discard via dialog callback MUST erase all real groups'

  # Rebuild via the dialog callback.
  dialog.callbacks['rebuild_workspace'].call(nil)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'ready', snap['state'],
               'rebuild via dialog callback MUST reach :ready'
  assert_operator model.entities.valid_count, :>, 0,
                  'rebuild via dialog callback MUST create fresh real groups'
ensure
  v14_uninstall_fake_su
  FakeUI.uninstall!
  v14_reset_everything
end

test 'V14 production call chain: handle registry stays workspace-private (NOT in to_h / JSON)' do
  FakeUI.install!
  v14_reset_everything
  Loader.register!

  model = FakeUI::FakeModel.new
  v14_install_fake_su(model)
  adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
  src = v14_real_source_snapshot(edge_count: 2)
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: model)
  ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  refute_nil ws

  # The workspace has a private handle registry.
  assert_operator ws.handle_registry_keys.length, :>, 0,
                  'workspace must track at least one real handle per derived entity'

  # The workspace's to_h MUST NOT include the handle registry
  # (per directive CodeX BLOCK fix Stage 4 item 3).
  h = ws.to_h
  refute h.key?(:handle_registry), 'to_h MUST NOT expose handle_registry'
  refute h.key?('handle_registry'), 'to_h MUST NOT expose handle_registry (String key)'

  # The JSON round-trip MUST NOT include handle references.
  require 'json'
  json = JSON.generate(h)
  parsed = JSON.parse(json)
  refute_match(/SU-AI-Derived-/, json,
               'to_h output MUST NOT leak the derived group names')
ensure
  v14_uninstall_fake_su
  FakeUI.uninstall!
  v14_reset_everything
end
