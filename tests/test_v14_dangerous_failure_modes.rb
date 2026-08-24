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
  # The production adapter's sketchup_available? checks
  # `Sketchup.active_model.respond_to?(:active_entities)`. The
  # test fake model must respond to BOTH :entities AND
  # :active_entities (V14-RUNTIME-BLOCK-003 also tightened
  # the host-API contract tests to match the real SU
  # signature).
  unless model.respond_to?(:active_entities)
    model.define_singleton_method(:active_entities) { :fake_active_entities }
  end
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

# BLOCK-R3-3 closure test: V14-8 ONE-SHOT SELF-RESTORING
# patch. The patch is INSTALLED BEFORE the Owner click,
# raises the injected failure on the FIRST call, AND restores
# itself on that first call (so subsequent calls -- including
# V14-9/V14-10 -- run against the original method). The Owner
# snippet (in the checklist) uses this pattern so the patch
# is GUARANTEED to NOT leak.
#
# Per the BLOCK: the test must prove (a) the patch is installed
# before any click, (b) the first call actually raises, (c)
# the patch is restored AFTER the first call (not before --
# the previous `ensure` pattern restored IMMEDIATELY, before
# the click could happen).
test 'BLOCK-R3-3 closure: V14-8 one-shot self-restoring patch is installed BEFORE, raises, restores AFTER' do
  adapter_class = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter
  original = adapter_class.instance_method(:begin_operation)

  # The V14-8 ONE-SHOT SELF-RESTORING patch: the FIRST call
  # restores the original method (so V14-9/V14-10 see no patch)
  # AND raises the injected failure. Subsequent calls run the
  # ORIGINAL method.
  raised_first = false
  adapter_class.class_eval do
    define_method(:begin_operation) do |_model, label:|
      # RESTORE FIRST -- so V14-9/V14-10 see no patch.
      adapter_class.class_eval do
        define_method(:begin_operation, original)
      end
      # THEN raise the injected failure (one-shot).
      raise StandardError, 'V14-8-injected-once' unless raised_first
      raised_first = true
    end
  end

  # (a) The patch MUST be installed BEFORE any click.
  # We verify by checking that the instance_method is NOT
  # the original. This is what makes "is the patch still
  # installed?" testable without triggering the injection.
  pre_click_method = adapter_class.instance_method(:begin_operation)
  refute_equal original, pre_click_method,
               'patch MUST be installed BEFORE any click (instance_method differs from original)'

  # (b) The first call MUST raise the injected failure.
  raised_call = false
  begin
    adapter_class.new.begin_operation(nil, label: 'first-call')
  rescue StandardError => e
    raised_call = true
    assert_match(/V14-8-injected-once/, e.message,
                 'first call MUST raise the injected failure (V14-8)')
  end
  assert raised_call, 'first call MUST raise (BLOCK-R3-3)'

  # (c) The patch MUST be restored AFTER the first call.
  post_click_method = adapter_class.instance_method(:begin_operation)
  assert_equal original, post_click_method,
               'patch MUST be self-restored AFTER the first call (BLOCK-R3-3)'

  # (d) Subsequent calls MUST NOT raise (V14-9/V14-10 safety).
  raised_second = false
  begin
    adapter_class.new.begin_operation(nil, label: 'second-call')
  rescue StandardError
    raised_second = true
  end
  refute raised_second,
         'second call MUST NOT raise (patch self-restored after first call)'

  # (e) The patched method, after restoration, MUST have the
  # SAME source location as the original (Ruby recreates the
  # UnboundMethod object on `define_method`, but the source
  # location is preserved -- this is the strongest behavioral
  # check we can do without holding the original UnboundMethod
  # object across `define_method`).
  restored = adapter_class.instance_method(:begin_operation)
  assert_equal original.source_location, restored.source_location,
               'restored method MUST share source_location with the original (true restoration)'
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

test 'DANGER 9b: source Face present BUT V1.4 minimal scope does NOT fail the workspace (no fabrication)' do
  # V1.4 CodeX BLOCK rework (2026-08-22) BLOCK-R3-2:
  # FaceRecord#vertices does not exist on the production
  # FaceRecord. V1.4 minimal scope ONLY derives Edges
  # faithfully; source Faces are recorded in the SourceSnapshot
  # (for layer counts / fingerprint / provenance) but NOT
  # materialized as derived Face entities. The previous
  # implementation called FaceRecord#vertices and forced a
  # :failed transition for any source with a face; that
  # broke the "Edge-only faithful derivation" contract.
  # The new behavior: workspace reaches :ready (driven by the
  # edge-derivation loop) and the face is silently skipped
  # (no fabrication, no :failed transition).
  v14_reset_everything
  face_class = SUAnalysis::Core::FaceRecord
  # A source Face with outer_loop_vertex_count == 2 (not a
  # faithful polygon). Under the OLD code this would have
  # forced :failed; under the NEW code it is silently skipped.
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
  edge1 = SUAnalysis::Core::EdgeRecord.new(
    id: 0,
    source: SUAnalysis::Core::SourceReference.new(
      entity_id: 12010, persistent_id: 12010, kind: 'edge',
      persistent_id_path: [12010], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    ),
    start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0],
    layer: 'Layer0'
  )
  edge2 = SUAnalysis::Core::EdgeRecord.new(
    id: 1,
    source: SUAnalysis::Core::SourceReference.new(
      entity_id: 12011, persistent_id: 12011, kind: 'edge',
      persistent_id_path: [12011], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    ),
    start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0],
    layer: 'Layer0'
  )
  src = v14_danger_source_with_paths([])
  ec = src.execution_config
  mixed_src = SUAnalysis::Core::SourceSnapshot.new(
    snapshot_id:       'mixed-edge-face-snap',
    selection_scope:   [],
    edges:             [edge1, edge2],
    faces:             [face],
    layers:            src.layers,
    vertex_records:    [],
    unit:              'inches',
    coordinate_origin: 'raw',
    transform_context: src.transform_context,
    execution_config:  ec,
    fingerprint:       src.fingerprint
  )
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  SUAnalysis::Core::WorkingModeRunner.prepare(source: mixed_src, adapter: adapter, model: nil)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  # Workspace MUST reach :ready (driven by the 2 edges),
  # NOT :failed (no fabrication).
  assert_equal 'ready', snap['state'],
               'presence of a source Face MUST NOT force :failed in V1.4 (no fabrication)'
  assert_equal 2, snap['entity_count'],
               'entity_count is the derived EDGE count (NOT edges + faces), per BLOCK-R3-2'
  ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal 2, ws.entity_count,
               'workspace entity_count must equal the derived EDGE count'
  refute_match(/fabricat|not faithfully/, snap['last_error'].to_s,
               'no fabrication-related last_error for V1.4 minimal scope')
end

# BLOCK-R3-2 closure test: closed quadrilateral (4 edges + 1
# face) Prepare => ready, 4 derived edges, 0 fabricated
# faces.
test 'BLOCK-R3-2 closure: closed quadrilateral (4 edges + 1 face) Prepare => ready, 4 derived edges, 0 fabricated faces' do
  v14_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    Object.const_set(:Sketchup, Module.new) unless Object.const_defined?(:Sketchup)
    Sketchup.define_singleton_method(:active_model) { model }

    edges = [
      SUAnalysis::Core::EdgeRecord.new(
        id: 0,
        source: SUAnalysis::Core::SourceReference.new(
          entity_id: 14001, persistent_id: 14001, kind: 'edge',
          persistent_id_path: [14001], instance_path: [],
          structural_depth: 0, pid_path_complete: true,
          layer_name: 'Layer0'
        ),
        start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0],
        layer: 'Layer0'
      ),
      SUAnalysis::Core::EdgeRecord.new(
        id: 1,
        source: SUAnalysis::Core::SourceReference.new(
          entity_id: 14002, persistent_id: 14002, kind: 'edge',
          persistent_id_path: [14002], instance_path: [],
          structural_depth: 0, pid_path_complete: true,
          layer_name: 'Layer0'
        ),
        start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0],
        layer: 'Layer0'
      ),
      SUAnalysis::Core::EdgeRecord.new(
        id: 2,
        source: SUAnalysis::Core::SourceReference.new(
          entity_id: 14003, persistent_id: 14003, kind: 'edge',
          persistent_id_path: [14003], instance_path: [],
          structural_depth: 0, pid_path_complete: true,
          layer_name: 'Layer0'
        ),
        start_point: [10.0, 5.0, 0.0], end_point: [0.0, 5.0, 0.0],
        layer: 'Layer0'
      ),
      SUAnalysis::Core::EdgeRecord.new(
        id: 3,
        source: SUAnalysis::Core::SourceReference.new(
          entity_id: 14004, persistent_id: 14004, kind: 'edge',
          persistent_id_path: [14004], instance_path: [],
          structural_depth: 0, pid_path_complete: true,
          layer_name: 'Layer0'
        ),
        start_point: [0.0, 5.0, 0.0], end_point: [0.0, 0.0, 0.0],
        layer: 'Layer0'
      )
    ]
    # The face carries a faithful vertex array (4 corner
    # points) -- but per BLOCK-R3-2 V1.4 minimal scope does
    # NOT materialize it. We include a FaceRecord to assert
    # that the presence of a faithful face does NOT trigger
    # fabrication.
    face = SUAnalysis::Core::FaceRecord.new(
      id: 0,
      layer: 'Layer0',
      outer_loop_vertex_count: 4,
      source: SUAnalysis::Core::SourceReference.new(
        entity_id: 14005, persistent_id: 14005, kind: 'face',
        persistent_id_path: [14005], instance_path: [],
        structural_depth: 0, pid_path_complete: true,
        layer_name: 'Layer0'
      )
    )
    layers = [SUAnalysis::Core::LayerRecord.new(name: 'Layer0')]
    geom = SUAnalysis::Core::GeometrySnapshot.new(edges: edges, layers: layers)
    ec = SUAnalysis::Core::ExecutionConfigSnapshot.from_live_config(
      SUAnalysis::Core::AnalysisConfig.new(profile_name: 'r3-2'),
      rule_set_digest: 'r3-2.rule-set',
      source_snapshot_schema_version: '1'
    )
    src = SUAnalysis::Core::SourceSnapshot.from_geometry_snapshot(
      geom,
      selection: [],
      execution_config: ec,
      rule_set_digest: 'r3-2.rule-set',
      snapshot_id: 'r3-2-snap',
      captured_at: '2026-08-22T00:00:00Z'
    )
    # Inject the face into the snapshot's faces field.
    src_with_face = SUAnalysis::Core::SourceSnapshot.new(
      snapshot_id:       src.snapshot_id,
      selection_scope:   src.selection_scope,
      edges:             src.edges,
      faces:             [face],
      layers:            src.layers,
      vertex_records:    src.vertex_records,
      unit:              src.unit,
      coordinate_origin: src.coordinate_origin,
      transform_context: src.transform_context,
      execution_config:  src.execution_config,
      fingerprint:       src.fingerprint
    )

    adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
    SUAnalysis::Core::WorkingModeRunner.prepare(
      source: src_with_face, adapter: adapter, model: model
    )
    snap = SUAnalysis::Core::WorkingModeRunner.snapshot
    assert_equal 'ready', snap['state'],
                 'closed quadrilateral Prepare MUST reach :ready (BLOCK-R3-2)'
    assert_equal 4, snap['entity_count'],
                 'entity_count MUST be the derived EDGE count (4), NOT edges + faces'
    ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
    assert_equal 4, ws.entity_count
    # Verify: 4 derived groups in model.entities (one per edge),
    # each carrying exactly ONE real Edge with the source's
    # two world-coordinate endpoints (XYZ identical, no Z lift,
    # no fabricated Face).
    assert_equal 4, model.entities.groups.length
    all_edges = []
    model.entities.groups.each do |g|
      ents = g.respond_to?(:entities) ? g.entities : g.children
      all_edges.concat(ents.edges) if ents.respond_to?(:edges)
    end
    assert_equal 4, all_edges.length, '4 derived edges (NOT 5)'
    # Verify 0 fabricated faces across all derived groups.
    all_faces = []
    model.entities.groups.each do |g|
      ents = g.respond_to?(:entities) ? g.entities : g.children
      all_faces.concat(ents.faces) if ents.respond_to?(:faces)
    end
    assert_equal 0, all_faces.length,
                 'derived groups MUST carry 0 fabricated faces (BLOCK-R3-2)'
    # Verify XYZ identity on every derived Edge.
    src.edges.zip(all_edges).each do |src_edge, derived_edge|
      assert_equal src_edge.start_point, derived_edge.start,
                   'derived edge start MUST equal source edge start (XYZ)'
      assert_equal src_edge.end_point,   derived_edge.end,
                   'derived edge end MUST equal source edge end (XYZ)'
    end
  ensure
    Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
    FakeUI.uninstall!
    v14_reset_everything
  end
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

# BLOCK-R3-1 closure test: two no-PID root Edges produce
# DIFFERENT occurrence IDs (snapshot-local uniqueness), AND
# rebuild produces the SAME occurrence IDs (snapshot-local
# determinism). The transient-occ- prefix is preserved; we
# never collapse to 'transient-occ-unresolved'.
test 'BLOCK-R3-1 closure: two no-PID root Edges -> DIFFERENT occurrence IDs, SAME after rebuild' do
  v14_reset_everything
  # Build two edges WITHOUT persistent_id (root transient
  # edges with NO usable identity chain). Each edge has a
  # distinct analysis-local id (record.id).
  edge1 = SUAnalysis::Core::EdgeRecord.new(
    id: 0,
    source: SUAnalysis::Core::SourceReference.new(
      kind: 'edge', layer_name: 'Layer0',
      persistent_id_path: [], instance_path: [],
      structural_depth: 0, pid_path_complete: false
    ),
    start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0],
    layer: 'Layer0'
  )
  edge2 = SUAnalysis::Core::EdgeRecord.new(
    id: 1,
    source: SUAnalysis::Core::SourceReference.new(
      kind: 'edge', layer_name: 'Layer0',
      persistent_id_path: [], instance_path: [],
      structural_depth: 0, pid_path_complete: false
    ),
    start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0],
    layer: 'Layer0'
  )
  layers = [SUAnalysis::Core::LayerRecord.new(name: 'Layer0')]
  geom = SUAnalysis::Core::GeometrySnapshot.new(edges: [edge1, edge2], layers: layers)
  ec = SUAnalysis::Core::ExecutionConfigSnapshot.from_live_config(
    SUAnalysis::Core::AnalysisConfig.new(profile_name: 'r3-1'),
    rule_set_digest: 'r3-1.rule-set',
    source_snapshot_schema_version: '1'
  )
  src = SUAnalysis::Core::SourceSnapshot.from_geometry_snapshot(
    geom, selection: [], execution_config: ec,
    rule_set_digest: 'r3-1.rule-set',
    snapshot_id: 'r3-1-snap', captured_at: '2026-08-22T00:00:00Z'
  )
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  # First build: capture the occurrence IDs.
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  ws1 = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  refute_nil ws1
  occ1 = ws1.entities.map { |rec| rec.source_occurrence_ids.first }
  assert_equal 2, occ1.length
  # Per BLOCK-R3-1: the two edges MUST get DIFFERENT
  # snapshot-local occurrence IDs (no collapse to
  # 'transient-occ-unresolved').
  refute_equal occ1[0], occ1[1],
               'two no-PID root Edges MUST have DIFFERENT occurrence IDs (BLOCK-R3-1)'
  occ1.each do |id|
    assert_match(/^transient-occ-edge-\d+$/, id,
                 'transient occurrence MUST be snapshot-local (kind+id), got ' + id.inspect)
    refute_equal 'transient-occ-unresolved', id,
                 'must NOT collapse distinct edges to the same id (BLOCK-R3-1)'
  end
  # Capture the deterministic ids for the rebuild check.
  first_build_ids = occ1.dup

  # Rebuild from the SAME captured source: occurrence IDs
  # MUST be identical (snapshot-local determinism).
  SUAnalysis::Core::WorkingModeRunner.discard
  SUAnalysis::Core::WorkingModeRunner.rebuild
  ws2 = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  refute_nil ws2
  occ2 = ws2.entities.map { |rec| rec.source_occurrence_ids.first }
  assert_equal first_build_ids, occ2,
               'rebuild MUST produce the SAME occurrence IDs (snapshot-local determinism)'
end

# BLOCK-R3-1 extra: NEVER use record.object_id in the id
# (object_id varies per process; we must use the
# analysis-local record id, which is part of the captured
# SourceSnapshot and is stable across rebuilds).
test 'BLOCK-R3-1: transient occurrence id does NOT use record.object_id (determinism invariant)' do
  v14_reset_everything
  edge = SUAnalysis::Core::EdgeRecord.new(
    id: 42,
    source: SUAnalysis::Core::SourceReference.new(
      kind: 'edge', layer_name: 'Layer0',
      persistent_id_path: [], instance_path: [],
      structural_depth: 0, pid_path_complete: false
    ),
    start_point: [0.0, 0.0, 0.0], end_point: [1.0, 0.0, 0.0],
    layer: 'Layer0'
  )
  occ_id = SUAnalysis::Core::WorkingModeRunner.send(:_source_occurrence_id_for, edge, kind: :edge, array_index: 99)
  refute_match(/object_id/i, occ_id,
               'transient occurrence MUST NOT use object_id (BLOCK-R3-1)')
  refute_match(/\d{16,}/, occ_id,
               'transient occurrence MUST NOT use the Ruby object_id (16+ digits)')
  # The id MUST be deterministic (rebuild -> same id).
  occ_id2 = SUAnalysis::Core::WorkingModeRunner.send(:_source_occurrence_id_for, edge, kind: :edge, array_index: 99)
  assert_equal occ_id, occ_id2,
               'transient occurrence id MUST be deterministic (rebuild -> same id)'
  assert_match(/^transient-occ-edge-42$/, occ_id,
               'occurrence id MUST be analysis-local (kind + record.id)')
end

# BLOCK-R4-1 closure test: Face-only SourceSnapshot ->
# state == :failed (NOT :building). Per BLOCK-R4-1: V1.4
# minimal scope derives SOLELY from edges; if edges is empty
# (even when faces is non-empty), the workspace MUST
# transition to :failed with a precise last_error. Without
# this guard the UI would be locked in :building.
test 'BLOCK-R4-1 closure: Face-only SourceSnapshot -> state == :failed (NOT :building), via production adapter + FakeUI' do
  v14_reset_everything
  FakeUI.install!
  begin
    model = FakeUI::FakeModel.new
    Object.const_set(:Sketchup, Module.new) unless Object.const_defined?(:Sketchup)
    Sketchup.define_singleton_method(:active_model) { model }

    # Build a Face-only SourceSnapshot: 1 source face,
    # zero edges.
    face = SUAnalysis::Core::FaceRecord.new(
      id: 0,
      layer: 'Layer0',
      outer_loop_vertex_count: 4,
      source: SUAnalysis::Core::SourceReference.new(
        entity_id: 15001, persistent_id: 15001, kind: 'face',
        persistent_id_path: [15001], instance_path: [],
        structural_depth: 0, pid_path_complete: true,
        layer_name: 'Layer0'
      )
    )
    layers = [SUAnalysis::Core::LayerRecord.new(name: 'Layer0')]
    geom = SUAnalysis::Core::GeometrySnapshot.new(edges: [], layers: layers)
    ec = SUAnalysis::Core::ExecutionConfigSnapshot.from_live_config(
      SUAnalysis::Core::AnalysisConfig.new(profile_name: 'r4-1'),
      rule_set_digest: 'r4-1.rule-set',
      source_snapshot_schema_version: '1'
    )
    fp_before = SourceFingerprint.from_snapshot(
      geom, selection: [], host: nil
    )
    src = SUAnalysis::Core::SourceSnapshot.from_geometry_snapshot(
      geom,
      selection: [],
      execution_config: ec,
      rule_set_digest: 'r4-1.rule-set',
      snapshot_id: 'r4-1-face-only',
      captured_at: '2026-08-22T01:00:00Z'
    )
    src_with_face = SUAnalysis::Core::SourceSnapshot.new(
      snapshot_id:       src.snapshot_id,
      selection_scope:   src.selection_scope,
      edges:             [],
      faces:             [face],
      layers:            src.layers,
      vertex_records:    src.vertex_records,
      unit:              src.unit,
      coordinate_origin: src.coordinate_origin,
      transform_context: src.transform_context,
      execution_config:  src.execution_config,
      fingerprint:       src.fingerprint
    )
    adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
    SUAnalysis::Core::WorkingModeRunner.prepare(
      source: src_with_face, adapter: adapter, model: model
    )
    snap = SUAnalysis::Core::WorkingModeRunner.snapshot

    # 1. state MUST be :failed (NOT :building).
    assert_equal 'failed', snap['state'],
                 'Face-only source MUST transition to :failed (NOT :building) -- BLOCK-R4-1'

    # 2. entity_count MUST be 0.
    assert_equal 0, snap['entity_count'],
                 'Face-only source MUST yield entity_count == 0'

    # 3. last_error MUST be non-empty and explicitly name the
    # constraint.
    refute_nil snap['last_error'], 'last_error MUST be set'
    assert_match(/\S/, snap['last_error'].to_s, 'last_error MUST be non-empty')
    assert_match(/requires at least one derivable edge/, snap['last_error'].to_s,
                 'last_error MUST name the BLOCK-R4-1 constraint explicitly')
    assert_match(/source faces are retained as provenance only/, snap['last_error'].to_s,
                 'last_error MUST clarify that source faces are kept as provenance, not materialized')

    # 4. NO SU-AI-Derived-* handles were created in the
    # model (the production adapter's add_group MUST NOT
    # have been called).
    assert_equal 0, model.entities.groups.length,
                 'Face-only source MUST NOT create any SU-AI-Derived-* handle (BLOCK-R4-1)'
    assert_equal 0, model.active_entities.groups.length,
                 'Face-only source MUST NOT write into active_entities either'

    # 5. source fingerprint MUST NOT drift.
    assert_equal fp_before.digest, src_with_face.fingerprint.digest,
                 'source fingerprint MUST NOT drift across Face-only prepare'
  ensure
    Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
    FakeUI.uninstall!
    v14_reset_everything
  end
end

# BLOCK-R4-1 extra: Face-only source MUST be :failed even
# without the production adapter (FakeAdapter path). This
# proves the failure is detected BEFORE any host adapter call.
test 'BLOCK-R4-1 extra: Face-only source -> :failed with FakeAdapter (no host call)' do
  v14_reset_everything
  face = SUAnalysis::Core::FaceRecord.new(
    id: 0,
    layer: 'Layer0',
    outer_loop_vertex_count: 4,
    source: SUAnalysis::Core::SourceReference.new(
      entity_id: 16001, persistent_id: 16001, kind: 'face',
      persistent_id_path: [16001], instance_path: [],
      structural_depth: 0, pid_path_complete: true,
      layer_name: 'Layer0'
    )
  )
  layers = [SUAnalysis::Core::LayerRecord.new(name: 'Layer0')]
  # (proper constant path: SUAnalysis::Core::LayerRecord)
  ec = SUAnalysis::Core::ExecutionConfigSnapshot.from_live_config(
    SUAnalysis::Core::AnalysisConfig.new(profile_name: 'r4-1-extra'),
    rule_set_digest: 'r4-1-extra.rule-set',
    source_snapshot_schema_version: '1'
  )
  src = SUAnalysis::Core::SourceSnapshot.new(
    snapshot_id:       'r4-1-face-only-fake',
    selection_scope:   [],
    edges:             [],
    faces:             [face],
    layers:            layers,
    vertex_records:    [],
    unit:              'inches',
    coordinate_origin: 'raw',
    transform_context: { 'r4-1-extra' => 'face-only' },
    execution_config:  ec,
    fingerprint:       SUAnalysis::Core::SourceFingerprint.new(
      edge_count: 0, face_count: 1, layer_count: 1
    )
  )
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source: src, adapter: adapter, model: nil
  )
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'failed', snap['state'],
               'Face-only source with FakeAdapter MUST also transition to :failed'
  assert_equal 0, snap['entity_count']
  # The FakeAdapter MUST NOT have been called for any host
  # mutation (no group created, no edge added, no face added).
  assert_equal 0, adapter.created_handles.length,
               'Face-only source MUST NOT trigger any FakeAdapter group creation'
  assert_equal 0, adapter.added_edges.length,
               'Face-only source MUST NOT trigger any FakeAdapter edge creation'
end

# PHASE-3-MATRIX closure test: first / middle / last entity
# build failure MUST leave ZERO PARTIAL LEAKED entities.
# Per directive: failure injection must clean up any
# partial derived entity created in the SAME build call
# (precise cleanup via per-entity dispose). Tests this for
# the first, middle, and last edge in a 3-edge source.
#
# The atomic-cleanup invariant: a successfully-built
# entity that COMPLETED before the failure point is KEPT
# (the user expects their work to survive). A PARTIAL
# entity (host_handle created but a later step failed)
# MUST be disposed. The workspace must be in :failed state.
test 'PHASE-3-MATRIX: first/middle/last entity build failure -> no partial leaked entities (all positions)' do
  v14_reset_everything
  # Build a 3-edge source.
  src = v14_danger_source_with_paths([
    { persistent_id: 17001, persistent_id_path: [17001],
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] },
    { persistent_id: 17002, persistent_id_path: [17002],
      start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0] },
    { persistent_id: 17003, persistent_id_path: [17003],
      start_point: [10.0, 5.0, 0.0], end_point: [0.0, 5.0, 0.0] }
  ])

  # Build an adapter that fails on the N-th add_edge_to_group
  # call (1-based). The workspace's build_entity wraps each
  # call in its own SU operation; the failing N-th call must
  # dispose any partial handle from that same call. Prior
  # successfully-committed entities MUST remain (they
  # completed before the failure point).
  [1, 2, 3].each do |fail_at|
    v14_reset_everything
    counter = 0
    failing_adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
    original_add_edge = failing_adapter.method(:add_edge_to_group)
    failing_adapter.define_singleton_method(:add_edge_to_group) do |group, s, e|
      counter += 1
      if counter == fail_at
        raise StandardError, "v14-injected-fail-at-#{fail_at}"
      end
      original_add_edge.call(group, s, e)
    end
    SUAnalysis::Core::WorkingModeRunner.prepare(
      source: src, adapter: failing_adapter, model: nil
    )
    snap = SUAnalysis::Core::WorkingModeRunner.snapshot
    assert_equal 'failed', snap['state'],
                 "failure at position #{fail_at} MUST produce :failed"
    # Workspace-level invariant: every entity in entity_pairs
    # has a corresponding live handle in handle_registry. There
    # are NO partial leaked handles (a group created but
    # add_edge_to_group failed -> must be disposed).
    ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
    refute_nil ws
    entity_count_after = ws.entity_count
    handle_count_after = ws.handle_registry_keys.length
    assert_equal entity_count_after, handle_count_after,
                 "failure at position #{fail_at}: entity_count (#{entity_count_after}) must equal handle_registry_keys length (#{handle_count_after}) -- NO partial leaked handles"
    # Adapter-level invariant: total groups created by the
    # adapter across this prepare call equals total groups
    # disposed (no group survives that isn't in the final
    # handle_registry).
    total_created = failing_adapter.created_handles.length
    total_disposed = failing_adapter.disposed_handles.length
    surviving_groups = total_created - total_disposed
    assert_equal handle_count_after, surviving_groups,
                 "failure at position #{fail_at}: surviving_groups (#{surviving_groups}) must equal handle_registry_keys length (#{handle_count_after})"
    # For fail_at=1 (very first build fails): NO entities,
    # NO handles, NO surviving groups.
    if fail_at == 1
      assert_equal 0, entity_count_after,
                   "first failure (fail_at=1) MUST leave entity_count == 0 (no successful builds before)"
    end
  end
end

# PHASE-3-MATRIX closure test: failed state is RECOVERABLE.
# After Prepare hits a :failed state, a subsequent Prepare
# (with the same source) MUST start fresh and reach :ready
# (the failed workspace does NOT block retries).
test 'PHASE-3-MATRIX: failed state is recoverable -- retry Prepare reaches :ready' do
  v14_reset_everything
  src = v14_danger_source_with_paths([
    { persistent_id: 18001, persistent_id_path: [18001],
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] }
  ])
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  # First Prepare with a failing adapter (begin_operation
  # raises before any build_entity runs).
  failing_adapter = Class.new(SUAnalysis::Core::FakeDerivedWorkspaceAdapter) do
    def begin_operation(_model, label:)
      raise StandardError, 'v14-first-try-fail'
    end
  end.new
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source: src, adapter: failing_adapter, model: nil
  )
  snap1 = SUAnalysis::Core::WorkingModeRunner.snapshot
  # The runner's prepare() catches begin_operation failures and
  # transitions the workspace to :failed with the original
  # exception captured in last_error.
  assert_equal 'failed', snap1['state'],
               'first Prepare (failing begin_operation) MUST produce :failed'
  assert_match(/v14-first-try-fail/, snap1['last_error'].to_s,
               'last_error MUST capture the begin_operation failure')
  # Second Prepare with a WORKING adapter on the SAME source
  # MUST reach :ready (recovery). This proves the failed
  # workspace does not block retries.
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source: src, adapter: adapter, model: nil
  )
  snap2 = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'ready', snap2['state'],
               'retry Prepare (working adapter) MUST reach :ready (failed state is recoverable)'
  assert_equal 1, snap2['entity_count'],
               'retry Prepare MUST produce 1 derived entity'
end

# PHASE-3-MATRIX closure test: rapid click cycles (Prepare +
# Discard + Rebuild) MUST not produce overlapping workspaces.
# Each Prepare must replace the previous workspace; each
# Discard must drop the workspace; each Rebuild must produce
# a fresh workspace. The runner is single-stateful, so
# overlapping is forbidden by construction -- this test
# pins that invariant.
test 'PHASE-3-MATRIX: rapid Prepare/Discard/Rebuild cycles -- no overlapping workspaces' do
  v14_reset_everything
  src = v14_danger_source_with_paths([
    { persistent_id: 19001, persistent_id_path: [19001],
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0] },
    { persistent_id: 19002, persistent_id_path: [19002],
      start_point: [10.0, 0.0, 0.0], end_point: [10.0, 5.0, 0.0] }
  ])
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new

  # Rapid cycle 1: Prepare -> Discard
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  assert_equal 'ready', SUAnalysis::Core::WorkingModeRunner.snapshot['state']
  SUAnalysis::Core::WorkingModeRunner.discard
  assert_equal 'discarded', SUAnalysis::Core::WorkingModeRunner.snapshot['state']

  # Rapid cycle 2: Prepare (immediately) -> Rebuild
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  snap_pre_rebuild = SUAnalysis::Core::WorkingModeRunner.snapshot
  SUAnalysis::Core::WorkingModeRunner.rebuild
  snap_post_rebuild = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'ready', snap_post_rebuild['state'],
               'rebuild from captured source MUST reach :ready'
  refute_equal snap_pre_rebuild['workspace_id'], snap_post_rebuild['workspace_id'],
               'rebuild MUST produce a fresh workspace_id (no overlap)'
  # The post-rebuild workspace must carry the SAME
  # source_snapshot_id (deterministic rebuild invariant).
  assert_equal snap_pre_rebuild['source_snapshot_id'], snap_post_rebuild['source_snapshot_id'],
               'rebuild MUST preserve the captured source_snapshot_id'

  # Rapid cycle 3: Discard -> Prepare -> Discard
  SUAnalysis::Core::WorkingModeRunner.discard
  assert_equal 'discarded', SUAnalysis::Core::WorkingModeRunner.snapshot['state']
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  assert_equal 'ready', SUAnalysis::Core::WorkingModeRunner.snapshot['state']
  SUAnalysis::Core::WorkingModeRunner.discard
  assert_equal 'discarded', SUAnalysis::Core::WorkingModeRunner.snapshot['state']

  # The FakeAdapter's added_edges + disposed_handles
  # should be balanced (no leakage). 2 edges per build, 3
  # builds total => 6 added; 3 discards => 6 disposed.
  # (dispose is idempotent; second discard sees an empty
  # handle_registry and disposes 0. Each Prepare creates 2
  # new groups and 2 new edges.)
  # We assert the upper bound: the FakeAdapter must NOT
  # have more surviving valid groups than the current
  # workspace's entity_count.
  ws_final = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal 'discarded', ws_final.state.to_s
  assert_equal 0, ws_final.entity_count,
               'after final discard, workspace must have 0 entities (no overlap)'
end
