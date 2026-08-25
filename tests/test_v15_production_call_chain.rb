#

# tests/test_v15_production_call_chain.rb — V1.5 Phase 1

# Production call chain tests (CodeX V1.5 BLOCK-001, BLOCK-002,

# BLOCK-005 recheck, 2026-08-25).

#

# These tests exercise the production boot chain + dialog

# Prepare callback, NOT the test-side requires. They prove:

#   1. main.rb loads DuplicateRepairProposer and

#      DuplicateRepairExecutor when the plugin boots (BLOCK-001).

#   2. The extracted RBZ's entry-point also loads them

#      (BLOCK-001 production evidence).

#   3. The dialog's on_prepare_workspace automatically runs

#      the proposer + executor batch against the registry

#      (BLOCK-002 production evidence).

#   4. The dialog's on_rebuild_workspace re-runs the batch

#      with the SAME captured registry (deterministic

#      rebuild).

#   5. Batch atomicity: mid-batch failure rolls back ALL

#      prior dispose() calls; source_fingerprint unchanged

#      (BLOCK-005).

#   6. Discard + Rebuild after batch = source unchanged.

#   7. Shared-definition two instances produce NO action

#      (BLOCK-003 production evidence: real construct).

#   8. Same-world-coords-different-provenance produce NO

#      action (BLOCK-003 production evidence: real construct).

#   9. Real SketchUp sequential-operation semantics: FakeModel

#      exposes only ONE operation at a time (already true

#      per V1.4 V14-STAGE-BLOCK-002); the batch applies

#      commits OR aborts, never half-commits.

#



require_relative 'runner'

require_relative '_fake_ui'

require_relative '../extension/su_ai_plugin/core/tolerance'

require_relative '../extension/su_ai_plugin/core/analysis_config'

require_relative '../extension/su_ai_plugin/core/source_reference'

require_relative '../extension/su_ai_plugin/core/edge_record'

require_relative '../extension/su_ai_plugin/core/face_record'

require_relative '../extension/su_ai_plugin/core/layer_record'

require_relative '../extension/su_ai_plugin/core/geometry_snapshot'

require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'

require_relative '../extension/su_ai_plugin/core/source_fingerprint'

require_relative '../extension/su_ai_plugin/core/source_snapshot'

require_relative '../extension/su_ai_plugin/core/derived_entity_record'

require_relative '../extension/su_ai_plugin/core/derived_workspace_fingerprint'

require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'

require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'

require_relative '../extension/su_ai_plugin/core/repair_plan'

require_relative '../extension/su_ai_plugin/core/duplicate_repair_proposer'

require_relative '../extension/su_ai_plugin/core/duplicate_repair_executor'

require_relative '../extension/su_ai_plugin/core/working_mode_runner'

require_relative '../extension/su_ai_plugin/core/issue_registry'

require_relative '../extension/su_ai_plugin/core/issue_normalizer'

require_relative '../extension/su_ai_plugin/core/issue_enricher'

require_relative '../extension/su_ai_plugin/core/preflight'

require_relative '../extension/su_ai_plugin/compatibility/su_derived_workspace_adapter'



include SUAnalysis::Core



# ---- helpers ----



def v15pc_exec_config

  ExecutionConfigSnapshot.from_live_config(

    AnalysisConfig.new(profile_name: 'test'),

    rule_set_digest: 'v15pc-rule-digest',

    source_snapshot_schema_version: '1'

  )

end



def v15pc_edge(id:, start:, finish:, parent_container_pid_path: [100])

  leaf_pid = id + 100

  parent_container_pid_path = parent_container_pid_path || []

  pid_path = parent_container_pid_path + [leaf_pid]

  EdgeRecord.new(

    id:           id,

    source:       SourceReference.new(

      entity_id:            id,

      persistent_id:        leaf_pid,

      kind:                 'edge',

      persistent_id_path:   pid_path,

      instance_path:        [],

      structural_depth:     parent_container_pid_path.length,

      pid_path_complete:    true,

      layer_name:           'Layer0'

    ),

    start_point:  start,

    end_point:    finish,

    layer:        'Layer0'

  )

end



def v15pc_derived_edge(derived_id, parent_container_pid_path: [100], start:, finish:)

  # Build the V1.4-format source_occurrence_id from the

  # derived record's derived_id + the container path. The V1.5

  # proposer's parse_v14_occurrence_to_container_path extracts

  # the container path by excluding the leaf PID.

  parent_container_pid_path = parent_container_pid_path || []

  leaf_pid = (derived_id.gsub(/[^0-9]/, '').to_i) + 100

  pid_path = parent_container_pid_path + [leaf_pid]

  occ_id = "occ-#{pid_path.map(&:to_s).join('>')}"

  DerivedEntityRecord.new(

    derived_id:            derived_id,

    kind:                  :edge,

    source_occurrence_ids: [occ_id],

    geometry_summary: {

      'layer'        => 'Layer0',

      'length'       => 10.0,

      'vertex_count' => 2,

      'start'        => start,

      'end'          => finish

    }

  )

end



def v15pc_snapshot(edges:, snapshot_id: 'v15pc-snap-001')

  SourceSnapshot.from_geometry_snapshot(

    GeometrySnapshot.new(edges: edges, layers: [LayerRecord.new(name: 'Layer0')]),

    selection: [],

    execution_config: v15pc_exec_config,

    rule_set_digest: 'v15pc-rule-digest',

    snapshot_id: snapshot_id,

    captured_at: '2026-08-25T00:00:00Z'

  )

end



def v15pc_workspace(snapshot:, records:)

  adapter = FakeDerivedWorkspaceAdapter.new

  ws = DerivedGeometryWorkspace.new(

    workspace_id:    'ws-v15pc-001',

    source_snapshot: snapshot,

    adapter:         adapter,

    model:           nil

  )

  cur = ws

  records.each do |rec|

    cur = cur.build_entity(

      derived_id:            rec.derived_id,

      kind:                  rec.kind,

      source_occurrence_ids: rec.source_occurrence_ids,

      geometry_summary:      rec.geometry_summary

    )

    raise "build_entity failed: #{cur.last_error}" if cur.state == :failed

  end

  cur

end



def v15pc_dup_issue(issue_id:, edge_ids:, location:)

  {

    issue_id:           issue_id.to_s,

    issue_type:         'duplicate_edge_candidate',

    severity:           'medium',

    confidence:         'high',

    sources:            [],

    source_entity_ids:  edge_ids.map { |eid| Integer(eid) },

    edge_ids:           edge_ids.map { |eid| Integer(eid) },

    location:           location,

    message:            'Duplicate edge candidate.',

    metadata:           {},

    locatable:          true,

    display_length:     nil

  }

end



def v15pc_registry(issues)

  IssueRegistry.new(issues)

end





# ================================================================

# BLOCK-001: production load wiring

# ================================================================



test 'V15PC-001: main.rb boot! loads DuplicateRepairProposer + DuplicateRepairExecutor' do

  # Re-execute main.rb's boot! method in isolation. We do NOT

  # rely on tests' own requires -- we go through the production

  # boot chain to verify the modules are wired in.

  #

  # The production boot chain is:

  #   extension/su_ai_plugin/main.rb -> SUAnalysis::Boot.boot!

  main_rb = File.expand_path('../extension/su_ai_plugin/main.rb', __dir__)

  load main_rb

  # After loading main.rb, the modules MUST be defined.

  refute_nil SUAnalysis::Core::DuplicateRepairProposer,

             'main.rb boot must load DuplicateRepairProposer'

  refute_nil SUAnalysis::Core::DuplicateRepairExecutor,

             'main.rb boot must load DuplicateRepairExecutor'

  # Sanity: the modules respond to the API surface we depend on.

  assert SUAnalysis::Core::DuplicateRepairProposer.respond_to?(:propose)

  assert SUAnalysis::Core::DuplicateRepairExecutor.respond_to?(:apply_batch)

end



test 'V15PC-002: extracted RBZ entry-point loads the proposer + executor' do

  # Per CodeX V1.5 BLOCK-001: the production boot test MUST

  # start from the EXTRACTED RBZ entry-point (not the in-tree

  # main.rb). This proves the production package wires the

  # modules, not just the dev tree.

  rbz_path = File.expand_path('../dist/SU-AI-Plugin.rbz', __dir__)

  unless File.exist?(rbz_path)

    skip "RBZ not built at #{rbz_path}"

  end

  require 'fileutils'

  require 'tmpdir'

  # Establish a fresh Sketchup / SketchupExtension stub surface.

  # test_loader.rb's earlier stubs may have been un-stubbed; we

  # must RE-DEFINE before loading the extracted entry-point. We use

  # `load` (NOT `require`) so the stub file is re-executed even

  # if it was previously loaded -- `require` is idempotent and

  # would skip the file when the constant was unstubbed.

  stubs_dir = File.expand_path('stubs', __dir__)

  $LOAD_PATH.unshift(stubs_dir) unless $LOAD_PATH.include?(stubs_dir)

  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)

  Object.send(:remove_const, :SketchupExtension) if Object.const_defined?(:SketchupExtension)

  load File.join(stubs_dir, 'sketchup.rb')

  load File.join(stubs_dir, 'extensions.rb')

  # Sanity: confirm both constants are defined now.

  assert defined?(Sketchup), 'Sketchup must be defined for the entry-point'

  assert defined?(SketchupExtension), 'SketchupExtension must be defined for the entry-point'

  FakeUI.install!

  tmp = Dir.mktmpdir('v15pc-rbz-')

  begin

    # Use the same PKZip parser as test_rbz_smoke.rb.

    unless respond_to?(:rbz_extract_all)

      load File.expand_path('test_rbz_smoke.rb', __dir__)

    end

    install_root, pkg_root = rbz_extract_all(rbz_path, tmp)

    ep_path = File.join(install_root, "#{pkg_root}.rb")

    assert File.exist?(ep_path),

           "extracted entry-point not found at #{ep_path}"

    # Load the entry-point. This is exactly what SketchUp

    # does at plugin install time.

    load ep_path

    # The entry-point loaded main.rb; the modules MUST be defined.

    refute_nil SUAnalysis::Core::DuplicateRepairProposer,

               'RBZ entry-point must load DuplicateRepairProposer'

    refute_nil SUAnalysis::Core::DuplicateRepairExecutor,

               'RBZ entry-point must load DuplicateRepairExecutor'

  ensure

    FakeUI.uninstall!

    FileUtils.rm_rf(tmp)

  end

end





# ================================================================

# BLOCK-002: production call chain

# ================================================================



test 'V15PC-003: WorkingModeRunner.run_duplicate_repair_batch runs proposer + executor from current registry' do

  # Pure-Ruby production call chain test (no FakeUI): simulate

  # the dialog_runner's call sequence -- Prepare + run_duplicate_repair_batch.

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  # Same parent component instance: two edges with same pid_path

  # [100]. Real-SketchUp constructible scenario.

  e1 = v15pc_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  e2 = v15pc_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  src = v15pc_snapshot(edges: [e1, e2])

  records = [

    v15pc_derived_edge('der-edge-0-rec100', parent_container_pid_path: [100],

                      start: e1.start_point, finish: e1.end_point),

    v15pc_derived_edge('der-edge-1-rec100', parent_container_pid_path: [100],

                      start: e2.start_point, finish: e2.end_point)

  ]

  # Use the real production adapter so the test exercises the

  # same path as a real SketchUp host.

  model = FakeUI::FakeModel.new

  production_adapter = SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new

  # Manually build a workspace via the production adapter

  # (FakeAdapter would skip the operation-wrapping path; the

  # production adapter writes to the model.entities and

  # wraps operations correctly).

  ws = DerivedGeometryWorkspace.new(

    source_snapshot: src, adapter: production_adapter, model: model

  )

  records.each do |rec|

    ws = ws.build_entity(

      derived_id:            rec.derived_id,

      kind:                  rec.kind,

      source_occurrence_ids: rec.source_occurrence_ids,

      geometry_summary:      rec.geometry_summary

    )

  end

  # Inject the workspace + source + adapter into the runner

  # (simulating the dialog_runner's prepare() call).

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_adapter, production_adapter)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_model, model)

  src_fp_before = src.fingerprint

  # Build a real IssueRegistry carrying the candidate pair.

  issues = [

    v15pc_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                     location: [5.0, 0.0, 0.0])

  ]

  registry = v15pc_registry(issues)

  # Run the production chain.

  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)

  snap = SUAnalysis::Core::WorkingModeRunner.snapshot

  # Verify the post-state.

  refute_nil snap['duplicate_repair'],

             'duplicate_repair summary must come from REAL execution, not manual injection'

  assert_equal 1, snap['duplicate_repair']['actions_applied']

  assert_equal 0, snap['duplicate_repair']['actions_skipped']

  # Workspace has 1 entity.

  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

  assert_equal 1, cur_ws.entities.length

  # Source fingerprint unchanged.

  assert_equal src_fp_before, src.fingerprint

  # Cleanup.

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

end



test 'V15PC-004: no eligible actions -> ready + applied=0 (idempotent batch)' do

  # When the registry has NO duplicate_edge_candidate issues,

  # the production chain is a no-op: workspace unchanged,

  # duplicate_repair summary records 0 applied / 0 skipped.

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  e1 = v15pc_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  src = v15pc_snapshot(edges: [e1])

  records = [

    v15pc_derived_edge('der-A', parent_container_pid_path: [100],

                      start: e1.start_point, finish: e1.end_point)

  ]

  ws = v15pc_workspace(snapshot: src, records: records)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_adapter, ws.instance_variable_get(:@adapter))

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_model, nil)

  registry = v15pc_registry([])  # empty registry

  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)

  snap = SUAnalysis::Core::WorkingModeRunner.snapshot

  refute_nil snap['duplicate_repair']

  assert_equal 0, snap['duplicate_repair']['actions_applied']

  assert_equal 0, snap['duplicate_repair']['actions_skipped']

  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

  assert_equal 1, cur_ws.entities.length

  assert_equal :ready, cur_ws.state

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

end



test 'V15PC-005: real-SketchUp constructible should-repair (same container path = CAD artifact)' do

  # The realistic SU2020 construct: a ComponentDefinition whose

  # body contains two SU Edges with the same world endpoints

  # (a CAD import artifact). Selecting the ComponentInstance

  # yields two EdgeRecords with the same container pid_path

  # (the instance's pid). V1.5 Phase 1 detects this and removes

  # one duplicate.

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  # Two edges in component instance pid=100 (CAD import duplicate).

  e1 = v15pc_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  e2 = v15pc_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  src = v15pc_snapshot(edges: [e1, e2])

  records = [

    v15pc_derived_edge('der-edge-0', parent_container_pid_path: [100],

                      start: e1.start_point, finish: e1.end_point),

    v15pc_derived_edge('der-edge-1', parent_container_pid_path: [100],

                      start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15pc_workspace(snapshot: src, records: records)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)

  registry = v15pc_registry([

    v15pc_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1],

                    location: [5.0, 0.0, 0.0])

  ])

  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)

  snap = SUAnalysis::Core::WorkingModeRunner.snapshot

  assert_equal 1, snap['duplicate_repair']['actions_applied']

  assert_equal 'applied', snap['duplicate_repair']['last_action_status']

  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

  assert_equal 1, cur_ws.entities.length

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

end



test 'V15PC-006: cross-instance same-world-coords duplicate is canonicalized with provenance union' do

  # CORRECTED V1.5 model (Guidance 031, 2026-08-25): two
  # component INSTANCES of the same definition with the SAME
  # world coordinates are canonicalized to one derived survivor.
  # Both source instances remain immutable; the survivor's
  # provenance is the sorted unique union of every contributing
  # source occurrence.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  e1 = v15pc_edge(id: 0, start: [0.0, 0.0, 0], finish: [10.0, 0.0, 0],

                  parent_container_pid_path: [100])  # instance A

  e2 = v15pc_edge(id: 1, start: [0.0, 0.0, 0], finish: [10.0, 0.0, 0],

                  parent_container_pid_path: [200])  # instance B (same definition, different instance)

  src = v15pc_snapshot(edges: [e1, e2])

  records = [

    v15pc_derived_edge('der-A', parent_container_pid_path: [100],

                      start: e1.start_point, finish: e1.end_point),

    v15pc_derived_edge('der-B', parent_container_pid_path: [200],

                      start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15pc_workspace(snapshot: src, records: records)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)

  registry = v15pc_registry([

    v15pc_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1],

                    location: [5.0, 0.0, 0.0])

  ])

  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)

  snap = SUAnalysis::Core::WorkingModeRunner.snapshot

  # Production call chain applies the canonicalization:
  assert_equal 1, snap['duplicate_repair']['actions_applied']

  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

  assert_equal 1, cur_ws.entities.length

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

end



test 'V15PC-007: cross-container same-world-coords duplicate is canonicalized with provenance union' do

  # CORRECTED V1.5 model (Guidance 031, 2026-08-25): same world
  # coordinates but DIFFERENT pid_path are canonicalized to one
  # derived survivor with provenance union of both source
  # occurrences.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  e1 = v15pc_edge(id: 0, start: [0.0, 0.0, 0], finish: [10.0, 0.0, 0],

                  parent_container_pid_path: [100, 200])

  e2 = v15pc_edge(id: 1, start: [0.0, 0.0, 0], finish: [10.0, 0.0, 0],

                  parent_container_pid_path: [300, 400])

  src = v15pc_snapshot(edges: [e1, e2])

  records = [

    v15pc_derived_edge('der-A', parent_container_pid_path: [100, 200],

                      start: e1.start_point, finish: e1.end_point),

    v15pc_derived_edge('der-B', parent_container_pid_path: [300, 400],

                      start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15pc_workspace(snapshot: src, records: records)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)

  registry = v15pc_registry([

    v15pc_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1],

                    location: [5.0, 0.0, 0.0])

  ])

  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)

  snap = SUAnalysis::Core::WorkingModeRunner.snapshot

  assert_equal 1, snap['duplicate_repair']['actions_applied']

  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

  assert_equal 1, cur_ws.entities.length

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

end





# ================================================================

# BLOCK-005: batch atomicity

# ================================================================



test 'V15PC-008: batch atomicity -- N-th action failure rolls back all prior actions' do

  # Adapter that succeeds on the first dispose() but fails on the

  # second. The executor's apply_batch MUST roll back the first

  # dispose (via end_operation(commit: false)) and leave the

  # workspace in :failed state with ALL entities preserved.

  class PartiallyFailingAdapter < FakeDerivedWorkspaceAdapter

    attr_reader :dispose_call_count

    def initialize(fail_at_call:)

      super()

      @fail_at_call = fail_at_call

      @dispose_call_count = 0

    end

    def dispose(_handle)

      @dispose_call_count += 1

      if @dispose_call_count >= @fail_at_call

        raise StandardError, "host failure on dispose call #{@dispose_call_count}"

      end

      super

    end

  end

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  # Build a workspace with TWO duplicate pairs (each is its own

  # action). The executor's apply_batch processes them sequentially;

  # the second action's first dispose() call fails.

  e1 = v15pc_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  e2 = v15pc_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  e3 = v15pc_edge(id: 2, start: [20.0, 0.0, 0.0], finish: [30.0, 0.0, 0.0],

                  parent_container_pid_path: [200])

  e4 = v15pc_edge(id: 3, start: [20.0, 0.0, 0.0], finish: [30.0, 0.0, 0.0],

                  parent_container_pid_path: [200])

  src = v15pc_snapshot(edges: [e1, e2, e3, e4])

  records = [

    v15pc_derived_edge('der-A1', parent_container_pid_path: [100],

                      start: e1.start_point, finish: e1.end_point),

    v15pc_derived_edge('der-A2', parent_container_pid_path: [100],

                      start: e2.start_point, finish: e2.end_point),

    v15pc_derived_edge('der-B1', parent_container_pid_path: [200],

                      start: e3.start_point, finish: e3.end_point),

    v15pc_derived_edge('der-B2', parent_container_pid_path: [200],

                      start: e4.start_point, finish: e4.end_point)

  ]

  adapter = PartiallyFailingAdapter.new(fail_at_call: 2)

  ws = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: adapter)

  cur = ws

  records.each do |rec|

    cur = cur.build_entity(

      derived_id:            rec.derived_id,

      kind:                  rec.kind,

      source_occurrence_ids: rec.source_occurrence_ids,

      geometry_summary:      rec.geometry_summary

    )

  end

  src_fp_before = src.fingerprint

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, cur)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_adapter, adapter)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_model, nil)

  # Two duplicate pairs from DuplicateDetector: (0,1) and (2,3).

  # Per-occurrence deduplication -> TWO actions, each removing

  # 1 derived record. The batch processes them in deterministic

  # order (survivor_id ascending); the second action's first

  # dispose call fails.

  registry = v15pc_registry([

    v15pc_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1],

                    location: [5.0, 0.0, 0.0]),

    v15pc_dup_issue(issue_id: 'dup|2|3', edge_ids: [2, 3],

                    location: [25.0, 0.0, 0.0])

  ])

  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)

  snap = SUAnalysis::Core::WorkingModeRunner.snapshot

  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

  # Workspace MUST be :failed (mid-batch failure).

  assert_equal :failed, cur_ws.state

  assert !cur_ws.ready?

  # All 4 entities preserved (no partial removal).

  assert_equal 4, cur_ws.entities.length

  # Source fingerprint unchanged.

  assert_equal src_fp_before, src.fingerprint

  # Adapter operation log shows begin + abort (NOT commit).

  log_kinds = adapter.operation_log.map { |op| op[:kind] }

  refute_includes log_kinds, :commit,

                  'batch with mid-action failure MUST NOT commit'

  assert_includes log_kinds, :abort,

                  'batch with mid-action failure MUST abort the SU operation'

  # The summary records the failure.

  refute_nil snap['duplicate_repair']

  assert snap['duplicate_repair']['actions_failed'] >= 1

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

end



test 'V15PC-009: Rebuild replay -> same post-state as first run' do

  # Per CodeX BLOCK-002: Rebuild MUST deterministically replay

  # the same post-repair state. The registry is the same

  # captured registry; the workspace is rebuilt from source;

  # the batch runs again with the same plan.

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  e1 = v15pc_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  e2 = v15pc_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  src = v15pc_snapshot(edges: [e1, e2])

  records = [

    v15pc_derived_edge('der-A', parent_container_pid_path: [100],

                      start: e1.start_point, finish: e1.end_point),

    v15pc_derived_edge('der-B', parent_container_pid_path: [100],

                      start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15pc_workspace(snapshot: src, records: records)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)

  registry = v15pc_registry([

    v15pc_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1],

                    location: [5.0, 0.0, 0.0])

  ])

  # First run.

  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)

  first_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

  first_state = {

    'entity_count'    => first_ws.entities.length,

    'survivor_id'     => first_ws.entities.first&.derived_id,

    'state'           => first_ws.state.to_s

  }

  # Rebuild: build a fresh workspace from source + adapter.

  ws2 = v15pc_workspace(snapshot: src, records: records)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws2)

  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)

  second_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

  second_state = {

    'entity_count'    => second_ws.entities.length,

    'survivor_id'     => second_ws.entities.first&.derived_id,

    'state'           => second_ws.state.to_s

  }

  assert_equal first_state, second_state,

               'rebuild must deterministically replay the same post-repair state'

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

end



test 'V15PC-010: Discard after batch -> source unchanged, workspace :discarded' do

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  e1 = v15pc_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  e2 = v15pc_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                  parent_container_pid_path: [100])

  src = v15pc_snapshot(edges: [e1, e2])

  records = [

    v15pc_derived_edge('der-A', parent_container_pid_path: [100],

                      start: e1.start_point, finish: e1.end_point),

    v15pc_derived_edge('der-B', parent_container_pid_path: [100],

                      start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15pc_workspace(snapshot: src, records: records)

  src_fp_before = src.fingerprint

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)

  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)

  registry = v15pc_registry([

    v15pc_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1],

                    location: [5.0, 0.0, 0.0])

  ])

  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)

  SUAnalysis::Core::WorkingModeRunner.discard

  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

  assert_equal :discarded, cur_ws.state

  # Source unchanged.

  assert_equal src_fp_before, src.fingerprint

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

end



# ---- helpers for refutes ----

def refute(cond, msg = nil)

  assert !cond, msg || "expected #{cond.inspect} to be falsy"

end



def refute_includes(coll, item, msg = nil)

  return unless coll.respond_to?(:include?) && coll.include?(item)

  raise msg || "expected #{coll.inspect} NOT to include #{item.inspect}"

end



def assert_includes(coll, item, msg = nil)

  return if coll.respond_to?(:include?) && coll.include?(item)

  raise msg || "expected #{coll.inspect} to include #{item.inspect}"

end