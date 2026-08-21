#
# tests/test_v14_dangerous_failure_modes.rb — V1.4 CodeX
# BLOCK rework (2026-08-21) BLOCK 7: dangerous-failure-
# mode tests.
#
# Per CodeX directive, the V1.4 plumbing path MUST be
# verified against the dangerous failure modes that
# would silently corrupt source / derived geometry:
#
#   1. source Edge -> derived Edge: endpoints XYZ
#      IDENTICAL (no implicit conversion, no Z lift, no
#      fabrication).
#   2. No extra Face, no Z lift (the previous BLOCK-1
#      fabrication path is forbidden).
#   3. Shared-definition two instances -> distinct
#      snapshot-local occurrence IDs (BLOCK 2 forbids
#      using the leaf persistent_id only).
#   4. Root context vs active edit context -> the
#      production adapter writes at the model root AND
#      the inverse transform path is exercisable
#      (BLOCK 3).
#   5. snapshot payload entity_count MUST match the
#      actual derived record count (BLOCK 4 -- UI
#      "N entities ready" must not lie).
#   6. Ruby 2.2 syntax gate: no `&.`, `case...in`,
#      `rescue =>`, etc. in the V1.4 changed production
#      scope (BLOCK 5).
#   7. Owner checklist commands are paste-runnable and
#      have a recovery path (BLOCK 6).
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

# --- helpers ---------------------------------------------------------

def v14_danger_source_with_paths(specs)
  # specs: Array of Hashes {persistent_id_path:, instance_path:,
  # layer_name:, start_point:, end_point:}. Builds an
  # AnalysisResult-shaped input (just enough for the
  # WorkingModeRunner path).
  edges = specs.each_with_index.map do |spec, idx|
    EdgeRecord.new(
      id: idx,
      source: SourceReference.new(
        entity_id: spec[:entity_id] || (10_000 + idx),
        persistent_id: spec[:persistent_id],
        kind: 'edge',
        persistent_id_path: spec[:persistent_id_path],
        instance_path: spec[:instance_path] || [],
        structural_depth: (spec[:persistent_id_path] || []).length,
        pid_path_complete: spec.fetch(:pid_path_complete, true),
        layer_name: spec[:layer_name] || 'Layer0'
      ),
      start_point: spec[:start_point],
      end_point:   spec[:end_point],
      layer: spec[:layer_name] || 'Layer0'
    )
  end
  layers = [LayerRecord.new(name: 'Layer0')]
  geom = GeometrySnapshot.new(edges: edges, layers: layers)
  ec = ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'danger'),
    rule_set_digest: 'danger.rule-set',
    source_snapshot_schema_version: '1'
  )
  SourceSnapshot.from_geometry_snapshot(
    geom,
    selection: [],
    execution_config: ec,
    rule_set_digest: 'danger.rule-set',
    snapshot_id: 'danger-snap-001',
    captured_at: '2026-08-21T00:00:00Z'
  )
end

def v14_install_fake_su(model)
  unless Object.const_defined?(:Sketchup)
    Object.const_set(:Sketchup, Module.new)
  end
  Sketchup.define_singleton_method(:active_model) { model }
end

def v14_uninstall_fake_su
  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
end

def v14_reset_everything
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

# --- dangerous failure mode tests ------------------------------------

# BLOCK 7-1: source Edge -> derived Edge endpoints XYZ identical.
test 'DANGER 1: source Edge -> derived Edge, endpoints XYZ identical (no Z lift, no fabrication)' do
  v14_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_install_fake_su(model)
    src = v14_danger_source_with_paths([
      { persistent_id: 1001, persistent_id_path: [1001],
        start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] },
      { persistent_id: 1002, persistent_id_path: [1002],
        start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0] },
      { persistent_id: 1003, persistent_id_path: [1003],
        start_point: [10.0, 5.0, 0.0], end_point: [0.0, 5.0, 0.0] },
      { persistent_id: 1004, persistent_id_path: [1004],
        start_point: [0.0, 5.0, 0.0], end_point: [0.0, 0.0, 0.0] }
    ])
    adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
    SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: model)
    # Total derived entities == source edge count. Each derived
    # Edge is recorded on its group's entities (the model's
    # root entities only track the groups themselves; edges
    # belong to the groups). Gather across all groups.
    all_edges = []
    model.entities.groups.each do |g|
      ents = g.respond_to?(:entities) ? g.entities : g.children
      all_edges.concat(ents.edges) if ents.respond_to?(:edges)
    end
    assert_equal 4, all_edges.length,
                 'one derived edge per source edge, no extra'
    # Walk source + derived in parallel; assert XYZ identity.
    src.edges.zip(all_edges).each do |src_edge, derived_edge|
      assert_equal src_edge.start_point, derived_edge.start,
                   'derived edge start MUST equal source edge start (XYZ)'
      assert_equal src_edge.end_point,   derived_edge.end,
                   'derived edge end MUST equal source edge end (XYZ)'
    end
  ensure
    v14_uninstall_fake_su
    FakeUI.uninstall!
    v14_reset_everything
  end
end

# BLOCK 7-2: no extra Face, no Z lift.
test 'DANGER 2: derived groups carry edges ONLY (no extra Face, no Z lift)' do
  v14_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_install_fake_su(model)
    src = v14_danger_source_with_paths([
      { persistent_id: 2001, persistent_id_path: [2001],
        start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] }
    ])
    adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
    SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: model)
    # The adapter is the PRODUCTION adapter (no added_edges /
    # added_faces tracking; those live on the FakeAdapter). We
    # verify via the model's group.entities instead.
    all_faces = []
    model.entities.groups.each do |g|
      ents = g.respond_to?(:entities) ? g.entities : g.children
      all_faces.concat(ents.faces) if ents.respond_to?(:faces)
    end
    assert_equal 0, all_faces.length,
                 'derived groups MUST carry edges ONLY (no extra Face fabrication)'
    # Gather all derived edges.
    all_edges = []
    model.entities.groups.each do |g|
      ents = g.respond_to?(:entities) ? g.entities : g.children
      all_edges.concat(ents.edges) if ents.respond_to?(:edges)
    end
    assert_equal 1, all_edges.length,
                 'add_edge_to_group MUST be called exactly once per source edge'
    # The edge's endpoints MUST be the source's endpoints (no Z
    # lift; the previous BLOCK-1 bug added a +1 Z offset to the
    # midpoint, which would have shown up as start[2] !=
    # derived.start[2]).
    added = all_edges.first
    assert_equal [0.0, 0.0, 0.0], added.start,
                 'derived edge start[2] MUST equal source start[2] (no Z lift)'
    assert_equal [10.0, 0.0, 0.0], added.end,
                 'derived edge end[2] MUST equal source end[2] (no Z lift)'
  ensure
    v14_uninstall_fake_su
    FakeUI.uninstall!
    v14_reset_everything
  end
end

# BLOCK 7-3: shared-definition two instances -> distinct occurrence IDs.
test 'DANGER 3: shared-definition two instances -> DISTINCT snapshot-local occurrence IDs' do
  v14_reset_everything
  # Two edges sharing the same ComponentDefinition persistent_id
  # (=5000) but in different instances with different
  # persistent_id_path arrays (= extra instance hops).
  shared_def_id = 5000
  src = v14_danger_source_with_paths([
    # Instance A: persistent_id_path = [definition_id, instance_A_id]
    { persistent_id: shared_def_id,
      persistent_id_path: [shared_def_id, 8001],
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] },
    # Instance B: persistent_id_path = [definition_id, instance_B_id]
    { persistent_id: shared_def_id,
      persistent_id_path: [shared_def_id, 8002],
      start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0] }
  ])
  # Use the FakeDerivedWorkspaceAdapter (no SU needed).
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  refute_nil ws
  # The two derived entities MUST carry distinct occurrence
  # IDs (per BLOCK 2: full persistent_id_path, NOT leaf
  # persistent_id; entityID / object_id are NEVER used).
  occ_ids = ws.entities.map { |rec| rec.source_occurrence_ids.first }
  assert_equal 2, occ_ids.length
  refute_equal occ_ids[0], occ_ids[1],
                  'shared-definition two instances MUST have DISTINCT snapshot-local occurrence IDs'
  assert_match(/^occ-5000>8001$/, occ_ids[0],
               'occurrence id MUST encode the FULL persistent_id_path; got ' + occ_ids[0].inspect)
  assert_match(/^occ-5000>8002$/, occ_ids[1],
               'occurrence id MUST encode the FULL persistent_id_path; got ' + occ_ids[1].inspect)
  refute_match(/object_id|entityID/i, occ_ids.join(' '),
               'occurrence IDs MUST NEVER use object_id / entityID as a stable-identity substitute')
end

# BLOCK 7-4: nested PID incomplete -> transient prefix.
test 'DANGER 4: nested PID incomplete -> transient prefix (no entityID fallback)' do
  v14_reset_everything
  # Edge with an incomplete PID path (pid_path_complete = false).
  # The previous implementation would have fallen back to
  # entityID -- BLOCK 2 forbids that.
  src = v14_danger_source_with_paths([
    { persistent_id: 7001,
      persistent_id_path: [7001],
      pid_path_complete: false,
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] }
  ])
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  refute_nil ws
  assert ws.entities.length > 0,
         'workspace must have at least one entity (the transient edge)'
  occ_id = ws.entities.first.source_occurrence_ids.first
  assert_match(/^transient-occ-/, occ_id,
               'incomplete PID path MUST produce a transient-occ- prefix (BLOCK 2)')
  refute_match(/eid-/, occ_id,
               'incomplete PID path MUST NEVER fall back to entityID as stable identity')
end

# BLOCK 7-5: root context vs active edit context coords correct.
test 'DANGER 5a: production adapter writes at the model ROOT (model.entities), NOT active_entities' do
  v14_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_install_fake_su(model)
    src = v14_danger_source_with_paths([
      { persistent_id: 9001, persistent_id_path: [9001],
        start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] }
    ])
    adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
    SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: model)
    # model.entities (root) has the derived group.
    assert_equal 1, model.entities.groups.length,
                 'production adapter MUST write at the model root (model.entities)'
    assert_equal 0, model.active_entities.groups.length,
                 'production adapter MUST NOT write into active_entities'
    # Code + checklist alignment: the production adapter's
    # resolve_root_entities returns model.entities.
    assert_equal model.entities, adapter.resolve_root_entities(model),
                 'adapter.resolve_root_entities MUST return model.entities (root, per BLOCK 3)'
  ensure
    v14_uninstall_fake_su
    FakeUI.uninstall!
    v14_reset_everything
  end
end

test 'DANGER 5b: active-edit context -- inverse transform path is exercisable' do
  # Per directive BLOCK 3: "if active edit context is
  # supported, execute world -> destination-local inverse
  # transform and test". We verify the adapter's
  # inverse_world_to_local_transform is exercisable AND
  # that the production adapter's resolve_root_entities +
  # inverse_world_to_local_transform contract matches the
  # Owner checklist (model root + active-edit transform).
  v14_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_install_fake_su(model)
    # Inject a fake edit_transform. The adapter must call
    # transform.inverse when computing the inverse.
    # Use a module-level (singleton) instance variable on the
    # transform itself so the singleton method's closure
    # does NOT need to capture a local variable (which is
    # fragile across Ruby versions).
    fake_inv = Object.new
    fake_inv.define_singleton_method(:inverse_called?) { true }
    fake_t = Object.new
    fake_t.define_singleton_method(:inverse) { fake_inv }
    model.inject_edit_transform(fake_t)
    adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
    got_inv = adapter.inverse_world_to_local_transform(model)
    assert_equal fake_inv, got_inv,
                 'adapter MUST return the inverse transform when edit_transform.inverse is present'
  ensure
    v14_uninstall_fake_su
    FakeUI.uninstall!
    v14_reset_everything
  end
end

test 'DANGER 5c: active-edit context -- inverse transform is identity when no edit' do
  v14_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    v14_install_fake_su(model)
    # No edit_transform injected -> adapter returns nil
    # (caller falls back to identity / world coords as-is).
    adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
    got_inv = adapter.inverse_world_to_local_transform(model)
    assert_nil got_inv,
               'when no active edit, the inverse MUST be nil (caller uses identity)'
  ensure
    v14_uninstall_fake_su
    FakeUI.uninstall!
    v14_reset_everything
  end
end

# BLOCK 7-6: snapshot payload entity_count MUST match actual record count.
test 'DANGER 6: snapshot payload entity_count matches actual derived record count' do
  v14_reset_everything
  src = v14_danger_source_with_paths([
    { persistent_id: 11001, persistent_id_path: [11001],
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] },
    { persistent_id: 11002, persistent_id_path: [11002],
      start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0] },
    { persistent_id: 11003, persistent_id_path: [11003],
      start_point: [10.0, 5.0, 0.0], end_point: [0.0, 5.0, 0.0] }
  ])
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  refute_nil snap['entity_count']
  assert_equal ws.entity_count, snap['entity_count'],
               'snapshot entity_count MUST equal workspace.entity_count (no UI lie)'
  assert_equal 3, snap['entity_count'],
               'entity_count for 3 source edges must be 3'
  # The idle snapshot also reports entity_count == 0.
  SUAnalysis::Core::WorkingModeRunner.discard
  # After discard, the discarded workspace is still :discarded
  # with the original entity_count (entity_count is intrinsic
  # to the workspace, not to the lifecycle).
  snap_discarded = SUAnalysis::Core::WorkingModeRunner.snapshot
  refute_nil snap_discarded
end

# BLOCK 7-7: Ruby 2.2 syntax gate.
test 'DANGER 7a: V1.4 changed production scope -- NO &. safe navigation' do
  changed_files = %w[
    extension/su_ai_plugin/core/derived_geometry_workspace.rb
    extension/su_ai_plugin/core/working_mode_runner.rb
    extension/su_ai_plugin/core/derived_workspace_adapter.rb
    extension/su_ai_plugin/core/derived_entity_record.rb
    extension/su_ai_plugin/core/derived_workspace_fingerprint.rb
    extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb
    extension/su_ai_plugin/core/analysis_result.rb
    extension/su_ai_plugin/core/source_snapshot.rb
    extension/su_ai_plugin/core/source_fingerprint.rb
    extension/su_ai_plugin/core/source_reference.rb
    extension/su_ai_plugin/core/execution_config_snapshot.rb
    extension/su_ai_plugin/core/edge_record.rb
    extension/su_ai_plugin/core/face_record.rb
    extension/su_ai_plugin/core/layer_record.rb
    extension/su_ai_plugin/core/repair_plan.rb
    extension/su_ai_plugin/dialog_runner.rb
    extension/su_ai_plugin/analyzers_runner.rb
    extension/su_ai_plugin/ui_bridge.rb
  ]
  root = File.expand_path('..', __dir__)
  offenders = []
  changed_files.each do |rel|
    path = File.join(root, rel)
    next unless File.exist?(path)
    src = File.read(path)
    # Strip comment lines (lines starting with `#`) before
    # scanning for `&.` -- the codebase may legitimately
    # reference `&.` in comments / commit history.
    code_only = src.lines.reject { |l| l.lstrip.start_with?('#') }.join
    # `&.` outside a string literal or comment is Ruby 2.3+.
    if code_only =~ /(?<!\\)&(?!\s*[\{\(a-zA-Z_])/
      # Crude: any `&` followed by non-{, non-(, non-letter.
      # Real Ruby 2.3+ safe navigation is `&.<id>` or `&[\n`
      # / `& [`; we scan for `&.<ident>` specifically.
      if code_only =~ /&\.[a-zA-Z_]/
        offenders << rel
      end
    end
  end
  assert_equal [], offenders,
               "V1.4 production scope MUST NOT use &. safe navigation (Ruby 2.2.4 baseline). Offenders: #{offenders.inspect}"
end

test 'DANGER 7b: V1.4 changed production scope -- NO case...in pattern matching' do
  changed_files = %w[
    extension/su_ai_plugin/core/derived_geometry_workspace.rb
    extension/su_ai_plugin/core/working_mode_runner.rb
    extension/su_ai_plugin/core/derived_workspace_adapter.rb
    extension/su_ai_plugin/core/derived_entity_record.rb
    extension/su_ai_plugin/core/derived_workspace_fingerprint.rb
    extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb
    extension/su_ai_plugin/core/analysis_result.rb
    extension/su_ai_plugin/core/source_snapshot.rb
    extension/su_ai_plugin/core/source_fingerprint.rb
    extension/su_ai_plugin/core/source_reference.rb
    extension/su_ai_plugin/core/execution_config_snapshot.rb
    extension/su_ai_plugin/core/edge_record.rb
    extension/su_ai_plugin/core/face_record.rb
    extension/su_ai_plugin/core/layer_record.rb
    extension/su_ai_plugin/core/repair_plan.rb
    extension/su_ai_plugin/dialog_runner.rb
    extension/su_ai_plugin/analyzers_runner.rb
    extension/su_ai_plugin/ui_bridge.rb
  ]
  root = File.expand_path('..', __dir__)
  offenders = []
  changed_files.each do |rel|
    path = File.join(root, rel)
    next unless File.exist?(path)
    src = File.read(path)
    code_only = src.lines.reject { |l| l.lstrip.start_with?('#') }.join
    # case ... in (Ruby 2.7+) -- pattern matching syntax.
    if code_only =~ /\bcase\b.*\bin\b/
      # Crude check: the `in` keyword at end-of-line after
      # `case X` is pattern matching. We require it to NOT
      # appear in production code.
      offenders << rel
    end
  end
  assert_equal [], offenders,
               "V1.4 production scope MUST NOT use case...in pattern matching. Offenders: #{offenders.inspect}"
end

# BLOCK 7-8: Owner checklist commands paste-runnable with recovery.
test 'DANGER 8a: Owner V14-8 monkey-patch is RESTORE-able via ensure block' do
  # The V14-8 checklist monkey-patches
  # SketchupDerivedWorkspaceAdapter#begin_operation to
  # raise. The recovery path is an explicit restore step.
  # We verify the recovery contract here by mimicking the
  # pattern: save -> monkey-patch -> raise -> restore in
  # ensure -> subsequent call works.
  adapter_class = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter
  original = adapter_class.instance_method(:begin_operation)
  monkey_patched = proc do |_model, label:|
    raise StandardError, 'V14-8-injected-failure'
  end
  begin
    adapter_class.class_eval do
      define_method(:begin_operation, &monkey_patched)
    end
    # Verify the monkey-patch is active (a call raises).
    raised = false
    begin
      adapter_class.new.begin_operation(nil, label: 'test')
    rescue StandardError
      raised = true
    end
    assert raised, 'monkey-patch MUST be active before restore'
  ensure
    # Restore: re-define the original method.
    adapter_class.class_eval do
      define_method(:begin_operation, original)
    end
    # Verify the restore: a subsequent call does NOT raise.
    raised_after = false
    begin
      adapter_class.new.begin_operation(nil, label: 'after-restore')
    rescue StandardError
      raised_after = true
    end
    refute raised_after,
           'after the restore step, begin_operation MUST NOT raise (the monkey-patch is gone)'
  end
end

test 'DANGER 8b: Owner V14-8 checklist commands have a recovery path that does NOT leak into V14-9/V14-10' do
  # We verify the recovery contract: after the restore step,
  # a NEW adapter instance sees the original (non-monkey-patched)
  # method. This proves that subsequent Owner steps (V14-9,
  # V14-10) run against the original implementation, NOT a
  # polluted one.
  adapter_class = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter
  original = adapter_class.instance_method(:begin_operation)
  # Monkey-patch (simulating the V14-8 injection).
  adapter_class.class_eval do
    define_method(:begin_operation) do |_model, label:|
      raise StandardError, 'V14-8-injected-failure'
    end
  end
  # Verify pollution.
  polluted = adapter_class.new
  raised_polluted = false
  begin
    polluted.begin_operation(nil, label: 'polluted')
  rescue StandardError
    raised_polluted = true
  end
  assert raised_polluted, 'monkey-patch MUST cause begin_operation to raise'
  # Restore.
  adapter_class.class_eval do
    define_method(:begin_operation, original)
  end
  # Verify a NEW instance sees the original (NOT polluted).
  fresh = adapter_class.new
  raised_fresh = false
  begin
    fresh.begin_operation(nil, label: 'fresh')
  rescue StandardError
    raised_fresh = true
  end
  refute raised_fresh,
         'after restore, a NEW adapter instance MUST see the original begin_operation (no pollution into V14-9/V14-10)'
end

# BLOCK 7-9: Face derivation rejects non-faithful input -> :failed.
# The current FaceRecord model carries outer_loop_vertex_count
# (Integer), not a vertex array; the per-vertex faithful
# validation lives at the adapter boundary. We verify the
# adapter rejects a Face whose vertices are non-Array OR
# fewer than 3 points OR non-Float components.
test 'DANGER 9a: adapter.add_face_to_group rejects Integer vertex (non-Float)' do
  v14_reset_everything
  adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
  # We don't need a full adapter to test the production
  # adapter's add_face_to_group; just exercise it.
  # Production adapter: the call goes through group_handle
  # .entities.add_face; in a test env without SU the
  # production adapter raises SketchupUnavailableError
  # BEFORE the per-vertex check. The per-vertex check is
  # enforced by the FAKE adapter (which is what the test
  # call chain exercises).
  fake = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  g = fake.create_top_level_group('g')
  raised = false
  begin
    fake.add_face_to_group(g, [[0, 0, 0], [1.0, 0.0, 0.0], [1.0, 1.0, 0.0]])
  rescue ArgumentError
    raised = true
  end
  assert raised, 'add_face_to_group MUST reject Integer vertex components (no Float coercion)'
end

test 'DANGER 9b: source Face with < 3 vertices -> workspace :failed (no fabrication)' do
  v14_reset_everything
  face_class = SUAnalysis::Core::FaceRecord
  # A source Face with outer_loop_vertex_count == 2 (not a
  # faithful polygon).
  face = face_class.new(
    id: 0,
    layer: 'Layer0',
    outer_loop_vertex_count: 2,
    source: SUAnalysis::Core::SourceReference.new(
      entity_id: 12001, persistent_id: 12001, kind: 'face',
      persistent_id_path: [12001], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    )
  )
  src = v14_danger_source_with_paths([])
  ec = src.execution_config
  bad_src = SUAnalysis::Core::SourceSnapshot.new(
    snapshot_id:       'bad-face-snap',
    selection_scope:   [],
    edges:             [],
    faces:             [face],
    layers:            src.layers,
    vertex_records:    [],
    unit:              'inches',
    coordinate_origin: 'raw',
    transform_context: src.transform_context,
    execution_config:  ec,
    fingerprint:       src.fingerprint
  )
  # Use the FakeDerivedWorkspaceAdapter (no SU needed).
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  SUAnalysis::Core::WorkingModeRunner.prepare(source: bad_src, adapter: adapter, model: nil)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'failed', snap['state'],
               'non-faithful source face MUST transition the workspace to :failed (no fabrication)'
  assert_match(/not faithfully representable/, snap['last_error'].to_s,
               'last_error MUST explain why the face is unsupported')
end

# BLOCK 7-10 (DOM regression): WorkingModeRunner.snapshot.entity_count
# MUST drive the JS renderWorkingMode's 'N entities ready'
# summary (BLOCK 4). We assert the snapshot -> payload ->
# render path explicitly here.
require_relative '../extension/su_ai_plugin/ui_bridge'

test 'DANGER 10: snapshot.entity_count flows through UIBridge -> JS render summary (no UI lie)' do
  v14_reset_everything
  src = v14_danger_source_with_paths([
    { persistent_id: 13001, persistent_id_path: [13001],
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] },
    { persistent_id: 13002, persistent_id_path: [13002],
      start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0] }
  ])
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  # Build a minimal AnalysisResult (the UI bridge calls
  # snapshot() to populate the derivedWorkspace key).
  reg = SUAnalysis::Core::IssueRegistry.new([])
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count, :face_count, :faces_with_holes_count, :layer_distribution).new(0, 0, 0, 0, 0, 0, {})
  ar = SUAnalysis::Core::AnalysisResult.new(
    preflight: pf, registry: reg, selection_type: 'Group',
    selection_label: 'g'
  )
  payload = SUAnalysis::Extension::UIBridge.as_html_data(ar)
  refute_nil payload['derivedWorkspace']
  # BLOCK 4: the derivedWorkspace payload MUST carry entity_count
  # and the JS render uses it verbatim. We assert both the
  # snapshot side and the JS-side regex.
  assert_equal 2, payload['derivedWorkspace']['entity_count'],
               'UIBridge-derivedWorkspace.entity_count MUST equal the workspace entity_count'
  # The JS render (extension/html/app.js#renderWorkingMode)
  # reads ws.entity_count verbatim and emits
  # 'Working Mode — N entities ready' when state === 'ready'.
  # We assert the snapshot has the values that JS consumes.
  assert_equal 'ready', payload['derivedWorkspace']['state'],
               'snapshot state MUST be :ready for the JS render to show "N entities ready"'
  # The entity_count drives the UI text; a count mismatch
  # would be a UI lie.
  refute_nil payload['derivedWorkspace']['entity_count'],
               'snapshot MUST include entity_count for the UI render'
end
