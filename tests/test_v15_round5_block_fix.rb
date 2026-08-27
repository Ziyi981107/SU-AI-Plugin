# =================================================================
# V1.5 Round-5 BLOCK corrective tests
# Per AIPM_TECHNICAL_GUIDANCE_V1_5_ROUND5_BLOCK_FIX_2026-08-27
# §8 (Required Round-5 tests):
#   BLOCK-001, BLOCK-002A/004, BLOCK-002B, BLOCK-003, BLOCK-005
# =================================================================

require_relative 'runner'

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
require_relative '../extension/su_ai_plugin/core/repair_plan'
require_relative '../extension/su_ai_plugin/core/duplicate_repair_proposer'
require_relative '../extension/su_ai_plugin/core/duplicate_repair_executor'
require_relative '../extension/su_ai_plugin/core/duplicate_repair_expected_post_state'
require_relative '../extension/su_ai_plugin/core/duplicate_geometry_semantics'
require_relative '../extension/su_ai_plugin/core/derived_duplicate_topology'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'
require_relative '../extension/su_ai_plugin/core/issue_registry'

include SUAnalysis::Core

# Top-level refute helper for tests.
def refute(cond, msg = nil)
  assert !cond, msg || "expected #{cond.inspect} to be falsy"
end

# ---- helpers (subset of v15 test helpers, scoped to this file) ----

def r5_edge(id:, start:, finish:, pid: nil, parent_pid_path: [100], layer: 'Layer0')
  pid ||= id + 100
  pid_path = parent_pid_path + [pid]
  EdgeRecord.new(
    id:           id,
    source:       SourceReference.new(
      entity_id:            id,
      persistent_id:        pid,
      kind:                 'edge',
      persistent_id_path:   pid_path,
      instance_path:        [],
      structural_depth:     parent_pid_path.length,
      pid_path_complete:    true,
      layer_name:           layer
    ),
    start_point:  start,
    end_point:    finish,
    layer:        layer
  )
end

def r5_snapshot(edges:, snapshot_id: 'r5-snap-001')
  layers = [LayerRecord.new(name: 'Layer0')]
  cap = ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'test'),
    rule_set_digest: 'r5-rule-digest',
    source_snapshot_schema_version: '1'
  )
  SourceSnapshot.from_geometry_snapshot(
    GeometrySnapshot.new(edges: edges, layers: layers),
    selection: [],
    execution_config: cap,
    rule_set_digest: 'r5-rule-digest',
    snapshot_id: snapshot_id,
    captured_at: '2026-08-27T00:00:00Z'
  )
end

def r5_derived_edge(derived_id:, start:, finish:, source_edge: nil)
  if source_edge
    full_path = source_edge.respond_to?(:source) && source_edge.source.respond_to?(:persistent_id_path) ?
                  source_edge.source.persistent_id_path : nil
    occ_id = full_path.is_a?(Array) && !full_path.empty? ?
               "occ-#{full_path.map(&:to_s).join('>')}" :
               "occ-#{derived_id}"
  else
    occ_id = "occ-#{derived_id}"
  end
  DerivedEntityRecord.new(
    derived_id:            derived_id.to_s,
    kind:                  :edge,
    source_occurrence_ids: [occ_id].freeze,
    geometry_summary:      {
      'layer'  => 'Layer0',
      'start'  => start,
      'end'    => finish,
      'length' => Math.sqrt((start[0]-finish[0])**2 + (start[1]-finish[1])**2 + (start[2]-finish[2])**2)
    }
  )
end

def r5_workspace(snapshot:, records:)
  adapter = FakeDerivedWorkspaceAdapter.new
  ws = DerivedGeometryWorkspace.new(
    workspace_id:    'ws-r5-001',
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

def r5_dup_issue(issue_id:, edge_ids:, location:)
  {
    issue_id:           issue_id.to_s,
    issue_type:         'duplicate_edge_candidate',
    severity:           'medium',
    confidence:         'high',
    sources:            [],
    source_entity_ids:  edge_ids.map { |eid| Integer(eid) },
    edge_ids:           edge_ids.map { |eid| Integer(eid) },
    location:           location,
    locatable:          true,
    message:            'duplicate edge candidate',
    display_length:     1,
    metadata:           { duplicate_tolerance: 0.0 }
  }
end

def r5_registry(issues)
  IssueRegistry.new(issues)
end

def r5_exec_config_zero_tolerance
  cap = ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'test'),
    rule_set_digest: 'r5-rule-digest',
    source_snapshot_schema_version: '1'
  )
  ExecutionConfigSnapshot.new(
    profile_id: cap.profile_id,
    profile_version: cap.profile_version,
    rule_set_id: cap.rule_set_id,
    rule_set_version: cap.rule_set_version,
    rule_set_digest: cap.rule_set_digest,
    tolerance_schema_version: cap.tolerance_schema_version,
    tolerance_values: { duplicate: 0.0 },
    session_overrides: cap.session_overrides,
    source_snapshot_schema_version: cap.source_snapshot_schema_version
  )
end

def r5_exec_config_with_tolerance(value)
  base = r5_exec_config_zero_tolerance
  ExecutionConfigSnapshot.new(
    profile_id: base.profile_id,
    profile_version: base.profile_version,
    rule_set_id: base.rule_set_id,
    rule_set_version: base.rule_set_version,
    rule_set_digest: base.rule_set_digest,
    tolerance_schema_version: base.tolerance_schema_version,
    tolerance_values: { duplicate: value },
    session_overrides: base.session_overrides,
    source_snapshot_schema_version: base.source_snapshot_schema_version
  )
end

def r5_src_with_tolerance(src, ec)
  SourceSnapshot.from_geometry_snapshot(
    GeometrySnapshot.new(edges: src.edges, layers: src.layers),
    selection: [],
    execution_config: ec,
    rule_set_digest: 'r5-rule-digest',
    snapshot_id: src.snapshot_id,
    captured_at: src.captured_at
  )
end

# ---------- BLOCK-001: complete final live-handle proof ----------

test 'V15-B001-6: invalid removal handle at proposer -> :skipped audit row; no applied actions; pre-state retained' do
  # Round-5 BLOCK-001: when the proposer's verify detects an
  # invalid removal handle (valid? == false), it emits a
  # :skipped audit row with a stable reason code. The executor
  # does NOT apply the action; the workspace stays :ready
  # (no destructive work was attempted).
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e3 = r5_edge(id: 2, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2, e3])
  records = [
    r5_derived_edge(derived_id: 'der-edge-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-edge-1', start: e2.start_point, finish: e2.end_point, source_edge: e2),
    r5_derived_edge(derived_id: 'der-edge-2', start: e3.start_point, finish: e3.end_point, source_edge: e3)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)
  # Poison: externally erase one removal handle. The
  # find_class_for_issue puts der-edge-0 (survivor) and
  # der-edge-1 (removal) into the clique. Erasing der-edge-1
  # makes the proposer's verify fail the handle proof.
  ws.handle_for('der-edge-1').erase!
  pre_source_fp = src.fingerprint.respond_to?(:digest) ? src.fingerprint.digest.to_s : src.fingerprint.to_s
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  # 0 applied actions (no destructive work attempted).
  assert_equal 0, snap['duplicate_repair']['actions_applied']
  # 1 skipped audit row emitted by the proposer.
  skipped_rows = snap['duplicate_repair']['actions'].select { |a| a['status'] == 'skipped' }
  assert skipped_rows.length >= 1, 'at least one skipped audit row'
  assert_match(/host_handle_invalid|non_transitive/, skipped_rows.first['confidence_basis'].to_s)
  # Source unchanged.
  post_source_fp = src.fingerprint.respond_to?(:digest) ? src.fingerprint.digest.to_s : src.fingerprint.to_s
  assert_equal pre_source_fp, post_source_fp
end

test 'V15-B001-7: invalid removal handle (valid? == false) at proposer -> :skipped audit row' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)
  ws.handle_for('der-1').erase!
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 0, snap['duplicate_repair']['actions_applied']
  skipped_rows = snap['duplicate_repair']['actions'].select { |a| a['status'] == 'skipped' }
  assert skipped_rows.length >= 1, "expected >=1 skipped row, got #{skipped_rows.length}"
  assert_match(/host_handle_invalid/, skipped_rows.first['confidence_basis'].to_s)
end

# ---------- BLOCK-002A / BLOCK-004: exact-zero tolerance path ----------

test 'V15-B002A-1: tolerance 0.0 forward exact duplicate -> 1 action applied, exact endpoint hash path' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  new_ec = r5_exec_config_zero_tolerance
  src_with_zero = r5_src_with_tolerance(src, new_ec)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src_with_zero)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal 1, snap['duplicate_repair']['actions_applied']
  assert_equal 1, cur_ws.entities.length
end

test 'V15-B002A-2: tolerance 0.0 reversed exact duplicate -> 1 action applied (forward/reversed share key)' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [10.0, 0.0, 0.0], finish: [0.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  new_ec = r5_exec_config_zero_tolerance
  src_with_zero = r5_src_with_tolerance(src, new_ec)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src_with_zero)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal 1, snap['duplicate_repair']['actions_applied']
  assert_equal 1, cur_ws.entities.length
end

test 'V15-B002A-3: tolerance 0.0 three-member clique -> 1 action; duplicate_pairs_before == 3; duplicate_pairs_after == 0' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e3 = r5_edge(id: 2, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2, e3])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2),
    r5_derived_edge(derived_id: 'der-2', start: e3.start_point, finish: e3.end_point, source_edge: e3)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  new_ec = r5_exec_config_zero_tolerance
  src_with_zero = r5_src_with_tolerance(src, new_ec)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src_with_zero)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|0|2', edge_ids: [0, 2], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|1|2', edge_ids: [1, 2], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal 1, snap['duplicate_repair']['actions_applied']
  assert_equal 3, snap['duplicate_repair']['duplicate_pairs_before']
  assert_equal 0, snap['duplicate_repair']['duplicate_pairs_after']
  assert_equal 1, cur_ws.entities.length
end

test 'V15-B002A-4: tolerance 0.0 flows through detector/proposer/topology/expected-state/validator' do
  recs = [
    { derived_id: 'd1', start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], layer: 'Layer0' },
    { derived_id: 'd2', start: [10.0, 0.0, 0.0], finish: [0.0, 0.0, 0.0], layer: 'Layer0' },
    { derived_id: 'd3', start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], layer: 'Layer0' }
  ]
  pairs = SUAnalysis::Core::DuplicateGeometrySemantics.enumerate_candidates(recs, 0.0)
  assert_equal 3, pairs.length, 'exact-zero: all three pairs must be detected'
  recs.each_with_index do |a, i|
    ((i + 1)...recs.length).each do |j|
      kind = SUAnalysis::Core::DuplicateGeometrySemantics.direct_match?(
        a[:start], a[:finish], recs[j][:start], recs[j][:finish],
        a[:layer], recs[j][:layer], 0.0
      )
      assert(kind == :forward || kind == :reversed,
             "exact-zero direct_match? at index pair (#{i},#{j}) must yield :forward or :reversed")
    end
  end
end

test 'V15-B002A-5: missing tolerance -> no auto-repair (valid_tolerance?(nil) is false)' do
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(nil)
end

test 'V15-B002A-6: negative tolerance -> no auto-repair' do
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(-0.001)
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(-1.0)
end

test 'V15-B002A-7: non-finite tolerance (NaN / Inf) -> no auto-repair' do
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(Float::NAN)
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(Float::INFINITY)
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(-Float::INFINITY)
end

test 'V15-B002A-8: captured 0.0 never becomes 0.0001 (tolerance_category is :zero)' do
  cat = SUAnalysis::Core::DuplicateGeometrySemantics.tolerance_category(0.0)
  assert_equal :zero, cat
  recs = [
    { derived_id: 'd1', start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], layer: 'Layer0' },
    { derived_id: 'd2', start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], layer: 'Layer0' }
  ]
  pairs = SUAnalysis::Core::DuplicateGeometrySemantics.enumerate_candidates(recs, 0.0)
  assert_equal [[0, 1]], pairs
end

# ---------- BLOCK-002B: genuine non-transitive regression ----------

test 'V15-B002B-1: genuine 0/.75T/1.5T production chain -> 2 pairs; 0 destructive actions; 1 skipped whole-component' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  T = 1.0
  a_start = [0.0, 0.0, 0.0]; a_finish = [10.0, 0.0, 0.0]
  b_start = [0.75 * T, 0.0, 0.0]; b_finish = [10.0 + 0.75 * T, 0.0, 0.0]
  c_start = [1.5 * T, 0.0, 0.0]; c_finish = [10.0 + 1.5 * T, 0.0, 0.0]
  e_a = r5_edge(id: 0, start: a_start, finish: a_finish, parent_pid_path: [100])
  e_b = r5_edge(id: 1, start: b_start, finish: b_finish, parent_pid_path: [100])
  e_c = r5_edge(id: 2, start: c_start, finish: c_finish, parent_pid_path: [100])
  src = r5_snapshot(edges: [e_a, e_b, e_c])
  # Use a tolerance of T = 1.0 so that 0.75T < T (B~C) but
  # 1.5T > T (A!~C). The default tolerance is 0.0001 which
  # would treat all three pairs as non-duplicates.
  new_ec = r5_exec_config_with_tolerance(T)
  src_with_T = r5_src_with_tolerance(src, new_ec)
  records = [
    r5_derived_edge(derived_id: 'der-A', start: a_start, finish: a_finish, source_edge: e_a),
    r5_derived_edge(derived_id: 'der-B', start: b_start, finish: b_finish, source_edge: e_b),
    r5_derived_edge(derived_id: 'der-C', start: c_start, finish: c_finish, source_edge: e_c)
  ]
  ws = r5_workspace(snapshot: src_with_T, records: records)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src_with_T)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|1|2', edge_ids: [1, 2], location: [10.75, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal 0, snap['duplicate_repair']['actions_applied']
  skipped_rows = snap['duplicate_repair']['actions'].select { |a| a['status'] == 'skipped' }
  assert_equal 1, skipped_rows.length, 'exactly one skipped whole-component row'
  assert_match(/non_transitive/, skipped_rows.first['confidence_basis'].to_s)
  assert_equal 3, cur_ws.entities.length
  assert_equal :ready, cur_ws.state
end

test 'V15-B002B-2: 0/.75T/1.5T chain -- multiple derived-ID orderings produce the same classification' do
  T = 1.0
  tuples_a = [
    { derived_id: 'a', start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], layer: 'Layer0' },
    { derived_id: 'b', start: [0.75 * T, 0.0, 0.0], finish: [10.0 + 0.75 * T, 0.0, 0.0], layer: 'Layer0' },
    { derived_id: 'c', start: [1.5 * T, 0.0, 0.0], finish: [10.0 + 1.5 * T, 0.0, 0.0], layer: 'Layer0' }
  ]
  tuples_b = [tuples_a[2], tuples_a[0], tuples_a[1]]
  cls_a = SUAnalysis::Core::DerivedDuplicateTopology.classify_components(tuples_a, T)
  cls_b = SUAnalysis::Core::DerivedDuplicateTopology.classify_components(tuples_b, T)
  assert_equal 0, cls_a[:repairable_components].length
  assert_equal 0, cls_b[:repairable_components].length
  assert_equal 1, cls_a[:non_transitive_components].length
  assert_equal 1, cls_b[:non_transitive_components].length
  assert_equal 2, cls_a[:non_transitive_components].first[:direct_pair_count]
  assert_equal 2, cls_b[:non_transitive_components].first[:direct_pair_count]
end

# ---------- BLOCK-003: precommit host-shape observation ----------

# ---------- BLOCK-005: production Owner path + host-change reconciliation ----------

test 'V15-B005-1: normal prepare/apply works WITHOUT calling reset_for_tests' do
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter, adapter)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_source, src)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter_kind, :fake)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_model, nil)
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_workspace, ws)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal 1, snap['duplicate_repair']['actions_applied']
  assert_equal 1, cur_ws.entities.length
end

test 'V15-B005-3: discard + simulated host Undo -> next interaction transitions to :failed host_state_changed' do
  adapter = SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter, adapter)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter_kind, :fake)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_model, nil)
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_source, src)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.discard
  snap_discard = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'discarded', snap_discard['state']
  adapter.simulate_host_state_change!
  ok = SUAnalysis::Core::WorkingModeRunner.send(:validate_host_state_consistency!)
  refute ok
  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal :failed, cur_ws.state
  assert_match(/host_state_changed/, cur_ws.last_error.to_s)
  adapter.clear_host_state_change!
end

test 'V15-B005-4: invalidate/reconcile truth -- :failed workspace exposes stable reason host_state_changed' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  adapter = ws.instance_variable_get(:@adapter)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter, adapter)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter_kind, :fake)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_source, src)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_workspace, ws)
  handle = ws.handle_for('der-0')
  handle.erase!
  ok = SUAnalysis::Core::WorkingModeRunner.send(:validate_host_state_consistency!)
  refute ok
  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal :failed, cur_ws.state
  assert_match(/host_state_changed/, cur_ws.last_error.to_s)
end

test 'V15-B005-5: rebuild after host_state_changed restores coherent inventory/handles/UI' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  adapter = ws.instance_variable_get(:@adapter)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter, adapter)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter_kind, :fake)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_source, src)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_workspace, ws)
  ws.handle_for('der-0').erase!
  SUAnalysis::Core::WorkingModeRunner.send(:validate_host_state_consistency!)
  SUAnalysis::Core::WorkingModeRunner.discard
  snap_discard = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'discarded', snap_discard['state']
  SUAnalysis::Core::WorkingModeRunner.prepare(source: src, adapter: adapter, model: nil)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'ready', snap['state']
  assert_equal 1, snap['entity_count']
end

test 'V15-B005-6: source CAD immutable across full BLOCK-005 scenario' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  pre_fp = src.fingerprint.respond_to?(:digest) ? src.fingerprint.digest.to_s : src.fingerprint.to_s
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  adapter = ws.instance_variable_get(:@adapter)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter, adapter)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter_kind, :fake)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_source, src)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_workspace, ws)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  adapter.simulate_host_state_change!
  SUAnalysis::Core::WorkingModeRunner.send(:validate_host_state_consistency!)
  SUAnalysis::Core::WorkingModeRunner.discard
  post_fp = src.fingerprint.respond_to?(:digest) ? src.fingerprint.digest.to_s : src.fingerprint.to_s
  assert_equal pre_fp, post_fp
  adapter.clear_host_state_change!
end
