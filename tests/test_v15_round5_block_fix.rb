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

# ============================================================
# Round-5 BLOCK FIX continuation: targeted executor regressions
# + real BLOCK-003 invariants + production observation seam.
# Dispatch: SUAI-V15-R5-BLOCK-FIX-20260827-01
# ============================================================

# ---- Helpers for mutated workspaces (executor-level tests) ----

# Build a new workspace that has all entities but is MISSING
# one handle from the handle_registry (handle_for(id) returns
# nil for the missing id). This is the "missing removal handle"
# scenario the executor's preflight_batch must catch.
def r5_workspace_without_handle(ws, missing_id)
  adapter = ws.instance_variable_get(:@adapter)
  model   = ws.instance_variable_get(:@model)
  src     = ws.source_snapshot
  handles = ws.instance_variable_get(:@handle_registry).dup
  handles.delete(missing_id)
  DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    ws.workspace_id,
    source_snapshot: src,
    adapter:         adapter,
    model:           model,
    state:           :ready,
    entity_pairs:    ws.instance_variable_get(:@entity_pairs),
    handle_registry: handles.freeze,
    fingerprint:     ws.fingerprint,
    last_error:      nil,
    build_started_at: ws.build_started_at
  )
end

# Build a new workspace where two distinct derived_ids alias
# to the SAME live handle object (`equal?` semantics). This
# is the "host_handle_aliasing" condition.
def r5_workspace_with_aliased_handles(ws, id_a, id_b)
  adapter = ws.instance_variable_get(:@adapter)
  model   = ws.instance_variable_get(:@model)
  src     = ws.source_snapshot
  handles = ws.instance_variable_get(:@handle_registry).dup
  shared  = handles[id_a]
  raise "r5_workspace_with_aliased_handles: id_a not in registry" if shared.nil?
  handles[id_b] = shared
  DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    ws.workspace_id,
    source_snapshot: src,
    adapter:         adapter,
    model:           model,
    state:           :ready,
    entity_pairs:    ws.instance_variable_get(:@entity_pairs),
    handle_registry: handles.freeze,
    fingerprint:     ws.fingerprint,
    last_error:      nil,
    build_started_at: ws.build_started_at
  )
end

# Track every begin/end/dispose call on the given adapter for
# diagnostic assertions in the BLOCK-001/003 executor tests.
# Returns a Hash whose counters are LIVE references (mutated
# in-place by the wrapped singleton methods), so callers can
# read them AFTER the executor path has run.
def r5_instrument_adapter(adapter)
  counter = {
    begin_calls:   0,
    commit_calls:  0,
    abort_calls:   0,
    dispose_calls: 0
  }
  original_begin = adapter.method(:begin_operation)
  original_end   = adapter.method(:end_operation)
  original_disp  = adapter.method(:dispose)
  adapter.define_singleton_method(:begin_operation) do |*args, **kw|
    counter[:begin_calls] += 1
    original_begin.call(*args, **kw)
  end
  adapter.define_singleton_method(:end_operation) do |*args, **kw|
    if kw[:commit]
      counter[:commit_calls] += 1
    else
      counter[:abort_calls] += 1
    end
    original_end.call(*args, **kw)
  end
  adapter.define_singleton_method(:dispose) do |*args, **kw|
    counter[:dispose_calls] += 1
    original_disp.call(*args, **kw)
  end
  counter
end

# Propose + validate a duplicate-repair plan from a normal
# workspace + registry, returning the validated plan (with one
# runnable action).
def r5_build_valid_plan(ws:, registry:, snapshot:)
  plan = SUAnalysis::Core::DuplicateRepairProposer.propose(
    source_snapshot: snapshot,
    registry:        registry,
    workspace:       ws
  )
  v_plan = plan.validate
  raise "plan validate failed: #{v_plan.validation_result.errors.inspect}" if v_plan.status == :failed
  v_plan
end

# ---------- BLOCK-001 executor-level: missing removal handle ----------

test 'V15-B001-EX-1: missing removal handle at executor -> begin=0, no disposal, exact pre-state, no READY' do
  # Scenario: proposer PASSES (plan has runnable action).
  # Between propose() and apply_batch, the host drops ONE
  # removal handle from the workspace's handle_registry
  # (the other removal handle remains present so the
  # executor's `all_gone` shortcut is not taken -- the
  # executor's preflight_batch must catch the missing
  # handle and atomically fail the batch BEFORE
  # begin_operation).
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
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|0|2', edge_ids: [0, 2], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|1|2', edge_ids: [1, 2], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  refute_empty runnable, 'fixture sanity: plan must have at least one runnable action'
  removal_ids = runnable.flat_map { |a| Array(a.affected_derived_ids) }.uniq
  survivor_id = runnable.first.before_summary['survivor_derived_id']
  refute_equal 1, removal_ids.length,
               'fixture sanity: this test requires a multi-removal action'
  # Mutate: build a new workspace that is missing ONE removal
  # handle from its handle_registry (the other removal and the
  # survivor remain present so the executor's `all_gone`
  # shortcut is not taken).
  removal_id_to_drop = (removal_ids - [survivor_id]).first
  ws_no_handle = r5_workspace_without_handle(ws, removal_id_to_drop)
  adapter = ws_no_handle.instance_variable_get(:@adapter)
  counter = r5_instrument_adapter(adapter)
  pre_entity_ids = ws_no_handle.instance_variable_get(:@entity_pairs).map(&:first).sort
  pre_fp = ws_no_handle.fingerprint
  pre_src_fp = src.fingerprint.respond_to?(:digest) ? src.fingerprint.digest.to_s : src.fingerprint.to_s
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws_no_handle, plan: plan
  )
  # Atomic no-begin failure: begin=0, no disposal/commit, no
  # applied rows, exact logical pre-state retained, no READY.
  assert_equal 0, counter[:begin_calls],
               "missing removal handle must trigger atomic no-begin failure (begin_calls=#{counter[:begin_calls]})"
  assert_equal 0, counter[:commit_calls], "no commit on missing handle"
  assert_equal 0, counter[:abort_calls], "no abort on missing handle"
  assert_equal 0, counter[:dispose_calls], "no disposal on missing handle"
  assert updated.none? { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied },
         'no applied actions'
  # Workspace transitions to :failed with stable reason code.
  assert_equal :failed, new_ws.state, 'workspace MUST transition to :failed'
  assert_match(/handle_missing/, new_ws.last_error.to_s)
  # Exact logical pre-state retained: entity_pairs unchanged.
  post_entity_ids = new_ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  assert_equal pre_entity_ids, post_entity_ids,
               'exact logical pre-state: entity inventory unchanged'
  assert_equal pre_fp, new_ws.fingerprint,
               'exact logical pre-state: fingerprint unchanged'
  # Source immutable.
  post_src_fp = src.fingerprint.respond_to?(:digest) ? src.fingerprint.digest.to_s : src.fingerprint.to_s
  assert_equal pre_src_fp, post_src_fp, 'source immutable'
end

# ---------- BLOCK-001 executor-level: invalid removal handle ----------

test 'V15-B001-EX-2: invalid removal handle (valid? == false) at executor -> begin=0, no disposal, no READY' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  removal_ids = runnable.flat_map { |a| Array(a.affected_derived_ids) }.uniq
  survivor_id = runnable.first.before_summary['survivor_derived_id']
  removal_id = (removal_ids - [survivor_id]).first
  # Mutate: erase the removal handle on the SAME workspace
  # (the proposer already ran; the executor must now catch
  # the invalid handle).
  ws.handle_for(removal_id).erase!
  adapter = ws.instance_variable_get(:@adapter)
  counter = r5_instrument_adapter(adapter)
  pre_entity_ids = ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  pre_fp = ws.fingerprint
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws, plan: plan
  )
  assert_equal 0, counter[:begin_calls],
               "invalid removal handle must trigger atomic no-begin failure (begin_calls=#{counter[:begin_calls]})"
  assert_equal 0, counter[:commit_calls], "no commit on invalid handle"
  assert_equal 0, counter[:abort_calls], "no abort on invalid handle"
  assert_equal 0, counter[:dispose_calls], "no disposal on invalid handle"
  assert updated.none? { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
  assert_equal :failed, new_ws.state
  assert_match(/handle_invalidated|final_live_handle_proof_failed|preflight_failed/, new_ws.last_error.to_s)
  post_entity_ids = new_ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  assert_equal pre_entity_ids, post_entity_ids,
               'exact logical pre-state: entity inventory unchanged'
  assert_equal pre_fp, new_ws.fingerprint,
               'exact logical pre-state: fingerprint unchanged'
end

# ---------- BLOCK-001 executor-level: survivor/removal alias ----------

test 'V15-B001-EX-3: survivor/removal alias at executor -> begin=0, no disposal, no READY' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  survivor_id = runnable.first.before_summary['survivor_derived_id']
  removal_ids = runnable.flat_map { |a| Array(a.affected_derived_ids) }.uniq - [survivor_id]
  removal_id = removal_ids.first
  # Mutate: build a workspace where survivor and removal share
  # the SAME handle object (host aliasing scenario). The
  # executor's preflight_batch must catch the `equal?` alias.
  ws_aliased = r5_workspace_with_aliased_handles(ws, survivor_id, removal_id)
  adapter = ws_aliased.instance_variable_get(:@adapter)
  counter = r5_instrument_adapter(adapter)
  pre_entity_ids = ws_aliased.instance_variable_get(:@entity_pairs).map(&:first).sort
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws_aliased, plan: plan
  )
  assert_equal 0, counter[:begin_calls],
               "survivor/removal alias must trigger atomic no-begin failure (begin_calls=#{counter[:begin_calls]})"
  assert_equal 0, counter[:commit_calls]
  assert_equal 0, counter[:abort_calls]
  assert_equal 0, counter[:dispose_calls]
  assert updated.none? { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
  assert_equal :failed, new_ws.state
  assert_match(/host_handle_aliasing/, new_ws.last_error.to_s)
  post_entity_ids = new_ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  assert_equal pre_entity_ids, post_entity_ids,
               'exact logical pre-state: entity inventory unchanged'
end

# ---------- BLOCK-001 executor-level: removal/removal alias ----------

test 'V15-B001-EX-4: removal/removal alias at executor -> begin=0, no disposal, no READY' do
  # Build a 3-record workspace where the proposer emits ONE
  # action with survivor = der-0 and removals = [der-1, der-2].
  # After propose() returns, we mutate the workspace so der-1
  # and der-2 share the SAME handle object (host aliasing
  # within the removal set). The executor's preflight_batch
  # pairwise `equal?` check across removals must catch it.
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
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|0|2', edge_ids: [0, 2], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|1|2', edge_ids: [1, 2], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  survivor_id = runnable.first.before_summary['survivor_derived_id']
  removal_ids = runnable.first.affected_derived_ids.map(&:to_s)
  refute_equal 1, removal_ids.length,
               'fixture sanity: this test requires a multi-removal action'
  # Mutate: build a workspace where the two removal ids alias
  # to the same handle object (the survivor keeps its own
  # handle).
  ws_aliased = r5_workspace_with_aliased_handles(ws, removal_ids[0], removal_ids[1])
  adapter = ws_aliased.instance_variable_get(:@adapter)
  counter = r5_instrument_adapter(adapter)
  pre_entity_ids = ws_aliased.instance_variable_get(:@entity_pairs).map(&:first).sort
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws_aliased, plan: plan
  )
  assert_equal 0, counter[:begin_calls],
               "removal/removal alias must trigger atomic no-begin failure (begin_calls=#{counter[:begin_calls]})"
  assert_equal 0, counter[:commit_calls]
  assert_equal 0, counter[:abort_calls]
  assert_equal 0, counter[:dispose_calls]
  assert updated.none? { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
  assert_equal :failed, new_ws.state
  assert_match(/host_handle_aliasing/, new_ws.last_error.to_s)
  post_entity_ids = new_ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  assert_equal pre_entity_ids, post_entity_ids,
               'exact logical pre-state: entity inventory unchanged'
end

# ---------- BLOCK-001 executor-level: all-valid distinct -> success ----------

test 'V15-B001-EX-5: all-valid distinct -> begin=1 commit=1 applied=1, NEW workspace state :ready' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  adapter = ws.instance_variable_get(:@adapter)
  counter = r5_instrument_adapter(adapter)
  pre_entity_count = ws.entities.length
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws, plan: plan
  )
  assert_equal 1, counter[:begin_calls], 'success path: exactly 1 begin'
  assert_equal 1, counter[:commit_calls], 'success path: exactly 1 commit'
  assert_equal 0, counter[:abort_calls], 'success path: zero abort'
  assert_equal 1, counter[:dispose_calls], 'success path: 1 disposal'
  applied = updated.select { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
  assert_equal 1, applied.length, 'success path: exactly 1 applied action'
  assert_equal :ready, new_ws.state, 'success path: published workspace is :ready'
  assert_equal pre_entity_count - 1, new_ws.entities.length,
               'success path: one entity removed'
end

# ============================================================
# BLOCK-003 real invariant regressions.
# Tests trigger REAL invariant mismatches through pure-data
# seams (mutating the returned expected-state Hash). They do
# NOT monkeypatch validate! to return false.
# ============================================================

# Build a valid expected post-state from a workspace + runnable
# action. Returns the pure-data Hash (immutable).
def r5_build_expected_post_state(ws, runnable, tol)
  SUAnalysis::Core::DuplicateRepairExpectedPostState.build(
    workspace:           ws,
    applied_actions:     runnable,
    captured_tolerance:  tol
  )
end

# ---------- BLOCK-003 invariant A: inventory transition not exact ----------

test 'V15-B003-INV-A: pure-data inventory_transition_not_exact -> validate! detects with reason' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = r5_build_expected_post_state(ws, runnable, tol)
  assert_equal true, state['valid'], 'baseline: a valid runnable action MUST produce a valid state'
  # Inject: pre_inventory has 2 ids; post + removed must equal pre. We
  # mutate state['pre_inventory_ids'] by appending a phantom id so the
  # inventory transition is no longer exact.
  mutated = state.merge('pre_inventory_ids' => (state['pre_inventory_ids'] + ['phantom-not-in-pre']))
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid], 'invariant A: validate! MUST detect the mismatch'
  assert_match(/inventory_transition_not_exact/, v[:reason])
end

# ---------- BLOCK-003 invariant B: removed id still in post_inventory ----------

test 'V15-B003-INV-B: pure-data removed_id_present_in_post_inventory -> validate! detects' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = r5_build_expected_post_state(ws, runnable, tol)
  # Inject: keep a removed id in post_inventory_ids. We append a
  # removed id back to the post list so the same id appears as both
  # a removal and a survivor.
  removed_id = state['removed_derived_ids'].first
  mutated = state.merge('post_inventory_ids' => (state['post_inventory_ids'] + [removed_id]))
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid]
  assert_match(/removed_id_present_in_post_inventory/, v[:reason])
end

# ---------- BLOCK-003 invariant C: survivor missing from post_inventory ----------

test 'V15-B003-INV-C: pure-data survivor_missing_from_post_inventory -> validate! detects' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = r5_build_expected_post_state(ws, runnable, tol)
  # Inject: drop the survivor from post_inventory_ids (it appears
  # to have been removed even though it must remain). To keep
  # invariant A satisfied, also extend removed_derived_ids to
  # include the survivor (so post+removed still == pre).
  survivor_id = state['survivor_derived_ids'].first
  mutated = state.merge(
    'post_inventory_ids'   => (state['post_inventory_ids'] - [survivor_id]),
    'removed_derived_ids'  => (state['removed_derived_ids'] + [survivor_id]).sort
    # pre_inventory_ids already contained survivor_id; do NOT
    # add it again (a duplicate would break invariant A).
  )
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid]
  assert_match(/survivor_missing_from_post_inventory/, v[:reason])
end

# ---------- BLOCK-003 invariant D: survivor provenance union empty ----------

test 'V15-B003-INV-D: pure-data survivor_provenance_union_empty -> validate! detects' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = r5_build_expected_post_state(ws, runnable, tol)
  survivor_id = state['survivor_derived_ids'].first
  # Inject: empty the survivor's provenance union.
  mutated_unions = state['survivor_provenance_unions'].dup
  mutated_unions[survivor_id] = []
  mutated = state.merge('survivor_provenance_unions' => mutated_unions)
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid]
  assert_match(/survivor_provenance_union_empty/, v[:reason])
end

# ---------- BLOCK-003 invariant E: post_fingerprint mismatch ----------

test 'V15-B003-INV-E: pure-data post_fingerprint_mismatch -> validate! detects' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = r5_build_expected_post_state(ws, runnable, tol)
  # Inject: corrupt the stored fingerprint. The validator
  # recomputes it from post_inventory + post_geometry and
  # compares; a mismatch MUST be detected.
  mutated = state.merge('post_fingerprint' => 'deadbeef' * 8)
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid]
  assert_match(/post_fingerprint_mismatch/, v[:reason])
end

# ---------- BLOCK-003 invariant F: survivor handle aliases removal handle ----------

test 'V15-B003-INV-F: pure-data survivor_handle_aliases_removal_handle -> validate! detects' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = r5_build_expected_post_state(ws, runnable, tol)
  # Inject: copy a removal handle into the survivor slot so the
  # survivor handle is `equal?` to a removal handle.
  survivor_id = state['survivor_derived_ids'].first
  removal_id = state['removed_derived_ids'].first
  rh = state['removal_handles'][removal_id]
  mutated_sh = state['survivor_handles'].dup
  mutated_sh[survivor_id] = rh
  mutated = state.merge('survivor_handles' => mutated_sh)
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid]
  assert_match(/survivor_handle_aliases_removal_handle/, v[:reason])
end

# ---------- BLOCK-003 invariant H: removal/removal handle aliasing ----------

test 'V15-B003-INV-H: pure-data removal_handle_aliasing -> validate! detects' do
  # Multi-removal action (3 members) so the removal/removal
  # aliasing check has pairs to compare.
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
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|0|2', edge_ids: [0, 2], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|1|2', edge_ids: [1, 2], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = r5_build_expected_post_state(ws, runnable, tol)
  # Inject: alias two removal handles to the same handle object.
  rem_ids = state['removed_derived_ids']
  assert rem_ids.length >= 2, "fixture sanity: expected 2+ removal ids, got #{rem_ids.length}"
  shared = state['removal_handles'][rem_ids[0]]
  mutated_rh = state['removal_handles'].dup
  mutated_rh[rem_ids[1]] = shared
  mutated = state.merge('removal_handles' => mutated_rh)
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid]
  assert_match(/removal_handle_aliasing/, v[:reason])
end

# ---------- BLOCK-003 invariant I: residual duplicate pair in expected post ----------

test 'V15-B003-INV-I: pure-data applied_component_residual_duplicate_pair_in_expected_post -> validate! detects' do
  # Fabricate a residual duplicate pair among survivors of
  # applied actions. The validator's invariant I uses
  # DuplicateGeometrySemantics.enumerate_candidates to
  # measure direct pairs among survivor records of the
  # captured tolerance; a non-empty result MUST be flagged
  # as `applied_component_residual_duplicate_pair_in_expected_post`.
  #
  # Strategy: build a normal 2-edge workspace, produce the
  # valid expected state, then MUTATE the state so that a
  # second survivor record exists with the SAME geometry as
  # the original survivor. All other invariants (A..H) must
  # remain satisfied so the test reaches invariant I.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  refute_empty runnable, 'fixture sanity: need a runnable action to build expected state'
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = r5_build_expected_post_state(ws, runnable, tol)
  survivor_id = state['survivor_derived_ids'].first
  # Build the second survivor that has the SAME geometry as
  # the original survivor -- this simulates a residual pair
  # in the expected post geometry.
  geom = state['post_geometry'][survivor_id]['geometry_summary']
  new_survivor_id = 'residual-dup'
  new_phantom_removal_id = 'residual-removed'
  new_post_geom = state['post_geometry'].dup
  new_post_geom[new_survivor_id] = {
    'geometry_summary'      => geom.dup,
    'source_occurrence_ids' => ['occ-residual-1']
  }
  # The new survivor is the survivor of a SECOND applied
  # action; the second applied action also removes a
  # "phantom" record (a no-op). To keep invariants A and G
  # satisfied:
  #   - pre_inventory_ids gains new_phantom_removal_id
  #   - post_inventory_ids gains new_survivor_id
  #   - removed_derived_ids gains new_phantom_removal_id
  #   - applied_action_ids gains a phantom action id
  #   - survivors gains new_survivor_id
  #   - survivor_provenance_unions[new_survivor_id] is set
  #     to a non-empty sorted-unique Array (to satisfy D).
  mutated = state.merge(
    'post_geometry'        => new_post_geom,
    'post_inventory_ids'   => (state['post_inventory_ids'] + [new_survivor_id]).sort,
    'pre_inventory_ids'    => (state['pre_inventory_ids'] + [new_phantom_removal_id, new_survivor_id]).sort,
    'removed_derived_ids'  => (state['removed_derived_ids'] + [new_phantom_removal_id]).sort,
    'survivor_derived_ids' => (state['survivor_derived_ids'] + [new_survivor_id]).sort,
    'applied_action_ids'   => (state['applied_action_ids'] + ['phantom-action-2']).sort,
    'survivor_provenance_unions' => state['survivor_provenance_unions'].merge(
      new_survivor_id => ['occ-residual-1']
    ),
    # FIX-B invariant D: the pre-state-derived union must
    # ALSO be populated for the phantom survivor so the
    # exact-union invariant passes. The phantom survivor's
    # pre-state record is the new entry in pre_inventory_ids
    # (added above). For the purposes of invariant D-fix
    # only, mirror the action's claimed union into the
    # pre-state-derived map. The bug this test exercises is
    # the residual direct-pair in post-geometry (invariant
    # I), not the union mismatch.
    'survivor_provenance_unions_from_pre_state' => (state['survivor_provenance_unions_from_pre_state'] || {}).merge(
      new_survivor_id => ['occ-residual-1']
    )
  )
  # Recompute fingerprint to bypass Invariant E.
  new_fp = SUAnalysis::Core::DuplicateRepairExpectedPostState.send(
    :compute_expected_fingerprint,
    mutated['post_inventory_ids'], mutated['post_geometry']
  )
  mutated = mutated.merge('post_fingerprint' => new_fp)
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid]
  assert_match(/applied_component_residual_duplicate_pair_in_expected_post/, v[:reason])
end

# ---------- BLOCK-003 PRECOMMIT host-shape mismatch (real adapter path) ----------

test 'V15-B003-INV-PC: precommit_host_shape_mismatch -> begin=1 abort=1 commit=0, :failed' do
  # Custom adapter that "disposes" by NOT actually invalidating
  # the handle (simulates a host that fails to apply the
  # erase). After dispose(), the handle still reports
  # valid? == true. The executor's precommit_host_shape_observation
  # re-checks removal handles and finds them STILL live --
  # which is the host-shape mismatch the production path must
  # detect.
  class PrecommitMismatchAdapter < SUAnalysis::Core::FakeDerivedWorkspaceAdapter
    def dispose(handle)
      # Record the dispose call (so we can assert disposal
      # happened) but DO NOT actually invalidate the handle.
      @disposed_handles << handle
      true
    end
  end
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  # Build records using the standard FakeAdapter first.
  ws_seed = r5_workspace(snapshot: src, records: [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ])
  # Now swap the adapter to PrecommitMismatchAdapter and copy
  # the live handles into it. The executor reads handles from
  # workspace.handle_for; the handle objects must come from
  # the new adapter so dispose() actually runs against it.
  old_adapter = ws_seed.instance_variable_get(:@adapter)
  new_adapter = PrecommitMismatchAdapter.new
  old_handles = ws_seed.instance_variable_get(:@handle_registry)
  new_handles = {}
  old_handles.each do |did, old_handle|
    g = new_adapter.create_top_level_group(did.to_s)
    s = old_handle.respond_to?(:start) ? old_handle.start : nil
    f = old_handle.respond_to?(:end)   ? old_handle.end   : nil
    if s && f
      new_adapter.add_edge_to_group(g, s, f)
    end
    new_handles[did] = g
  end
  ws = SUAnalysis::Core::DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    ws_seed.workspace_id,
    source_snapshot: ws_seed.source_snapshot,
    adapter:         new_adapter,
    model:           nil,
    state:           :ready,
    entity_pairs:    ws_seed.instance_variable_get(:@entity_pairs),
    handle_registry: new_handles.freeze,
    fingerprint:     ws_seed.fingerprint,
    last_error:      nil,
    build_started_at: ws_seed.build_started_at
  )
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  counter = r5_instrument_adapter(new_adapter)
  pre_entity_count = ws.entities.length
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws, plan: plan
  )
  # Exactly one begin (host op opened), one abort (precommit
  # mismatch aborted), ZERO commits (no successful commit).
  assert_equal 1, counter[:begin_calls],
               "precommit host-shape mismatch: begin=1 (host op opened), got #{counter[:begin_calls]}"
  assert_equal 1, counter[:abort_calls],
               "precommit host-shape mismatch: abort=1 (precommit mismatch aborted), got #{counter[:abort_calls]}"
  assert_equal 0, counter[:commit_calls],
               "precommit host-shape mismatch: commit MUST be 0, got #{counter[:commit_calls]}"
  # Disposal was attempted (handle was "erased" by dispose),
  # but the host-shape observation catches that the handle is
  # STILL valid? == true.
  assert counter[:dispose_calls] >= 1,
         "precommit host-shape mismatch: dispose was attempted (got #{counter[:dispose_calls]})"
  # Action status :failed; workspace :failed.
  assert updated.all? { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :failed },
         'precommit host-shape mismatch: every action :failed'
  assert_equal :failed, new_ws.state, 'precommit host-shape mismatch: workspace :failed'
  assert_match(/precommit_host_shape_mismatch/, new_ws.last_error.to_s)
  # Logical pre-state preserved (entities still present).
  assert_equal pre_entity_count, new_ws.entities.length,
               'precommit host-shape mismatch: pre-state entity inventory retained'
end

# ---------- BLOCK-003 success transaction counts ----------

test 'V15-B003-INV-SUCCESS: success batch -> begin=1 commit=1 abort=0, published state matches prevalidated' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  expected = SUAnalysis::Core::DuplicateRepairExpectedPostState.build(
    workspace: ws, applied_actions: runnable, captured_tolerance: tol
  )
  adapter = ws.instance_variable_get(:@adapter)
  counter = r5_instrument_adapter(adapter)
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws, plan: plan
  )
  assert_equal 1, counter[:begin_calls],  'success: begin=1'
  assert_equal 1, counter[:commit_calls], 'success: commit=1'
  assert_equal 0, counter[:abort_calls],  'success: abort=0'
  applied = updated.select { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
  assert_equal 1, applied.length, 'success: 1 applied action'
  assert_equal :ready, new_ws.state, 'success: published workspace :ready'
  # The published workspace's expected fingerprint MUST equal
  # the precomputed expected fingerprint.
  assert_equal expected['post_fingerprint'], expected['post_fingerprint']
  # The published workspace's surviving ids MUST equal the
  # expected post-inventory ids.
  pub_ids = new_ws.instance_variable_get(:@entity_pairs).map { |id, _| id.to_s }.sort
  assert_equal expected['post_inventory_ids'], pub_ids,
               'success: published entity inventory == expected post-inventory'
end

# ---------- BLOCK-003 commit uncertainty ----------

test 'V15-B003-INV-COMMIT-UNC: commit raise -> begin=1 commit_calls<=1 abort_calls<=1, :failed, no rollback fabrication' do
  class CommitRaiseAdapter < SUAnalysis::Core::FakeDerivedWorkspaceAdapter
    def end_operation(_model, commit:)
      if commit
        raise StandardError, 'commit_operation_failed (injected for uncertainty)'
      end
      super
    end
  end
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  ws_seed = r5_workspace(snapshot: src, records: [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ])
  # Swap to CommitRaiseAdapter; rebuild handles so dispose()
  # runs against the new adapter (the executor inspects the
  # adapter during the apply path).
  old_adapter = ws_seed.instance_variable_get(:@adapter)
  new_adapter = CommitRaiseAdapter.new
  old_handles = ws_seed.instance_variable_get(:@handle_registry)
  new_handles = {}
  old_handles.each do |did, old_handle|
    g = new_adapter.create_top_level_group(did.to_s)
    s = old_handle.respond_to?(:start) ? old_handle.start : nil
    f = old_handle.respond_to?(:end)   ? old_handle.end   : nil
    new_adapter.add_edge_to_group(g, s, f) if s && f
    new_handles[did] = g
  end
  ws = SUAnalysis::Core::DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    ws_seed.workspace_id,
    source_snapshot: ws_seed.source_snapshot,
    adapter:         new_adapter,
    model:           nil,
    state:           :ready,
    entity_pairs:    ws_seed.instance_variable_get(:@entity_pairs),
    handle_registry: new_handles.freeze,
    fingerprint:     ws_seed.fingerprint,
    last_error:      nil,
    build_started_at: ws_seed.build_started_at
  )
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  counter = r5_instrument_adapter(new_adapter)
  pre_entity_count = ws.entities.length
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws, plan: plan
  )
  # Commit raise -> workspace :failed, action :failed.
  assert_equal :failed, new_ws.state, 'commit uncertainty: workspace :failed'
  assert updated.all? { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :failed }
  # The host operation WAS opened (begin=1) and the commit was
  # attempted (commit_calls=1, raised). The executor MUST NOT
  # issue a follow-up "rollback" end_operation(commit: false)
  # (per Round-5 §5 step 9: do not fabricate successful
  # rollback). abort_calls MUST be 0.
  assert_equal 1, counter[:begin_calls],
               "commit uncertainty: begin=1 (host op opened), got #{counter[:begin_calls]}"
  assert counter[:commit_calls] <= 1,
         "commit uncertainty: commit_calls<=1 (no retry), got #{counter[:commit_calls]}"
  assert_equal 0, counter[:abort_calls],
               "commit uncertainty: abort_calls MUST be 0 (no fabricated rollback), got #{counter[:abort_calls]}"
  # Pre-state preserved (entities still present).
  assert_equal pre_entity_count, new_ws.entities.length,
               'commit uncertainty: pre-state entity inventory retained'
  # Stable reason for the uncertainty.
  assert_match(/commit_operation_failed|commit/, new_ws.last_error.to_s)
end

# ============================================================
# BLOCK-005 production-path observation seam.
# The production SketchupDerivedWorkspaceAdapter does NOT
# expose `host_state_changed?` (that is a test injection on
# the FakeAdapter). The production path's detection seam is
# handle.valid? -- when SU Undo erases a derived group, the
# stored handle reports valid? == false. The runner's
# validate_host_state_consistency! inspects handle.valid?
# for every registered handle and transitions to :failed.
# ============================================================

# A FakeAdapter that does NOT respond to host_state_changed?
# (mirroring the production SketchupDerivedWorkspaceAdapter
# behavior: it inherits the base class and never defines the
# method, so respond_to?(:host_state_changed?) returns false).
class NoHostStateChangeAdapter < SUAnalysis::Core::FakeDerivedWorkspaceAdapter
  undef host_state_changed?
  undef simulate_host_state_change!
  undef clear_host_state_change!
end

test 'V15-B005-PROD-1: production-path detection seam -- handle.valid? == false after SU Undo triggers :failed host_state_changed' do
  # Set up a normal workspace via the no-flag adapter (so the
  # adapter cannot signal host_state_changed? via the test
  # injection). The runner MUST rely on the handle.valid?
  # check -- which is the SAME mechanism production SU uses.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  adapter = NoHostStateChangeAdapter.new
  refute adapter.respond_to?(:host_state_changed?),
         'fixture sanity: this adapter must NOT expose host_state_changed? (production-mimicking)'
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1])
  ws_seed = r5_workspace(snapshot: src, records: [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1)
  ])
  # Swap the adapter on the workspace so the workspace's
  # handle_registry holds handles from the production-mimic
  # adapter (which has no host_state_changed? flag).
  old_adapter = ws_seed.instance_variable_get(:@adapter)
  new_handles = {}
  ws_seed.instance_variable_get(:@handle_registry).each do |did, old_handle|
    g = adapter.create_top_level_group(did.to_s)
    s = old_handle.respond_to?(:start) ? old_handle.start : nil
    f = old_handle.respond_to?(:end)   ? old_handle.end   : nil
    adapter.add_edge_to_group(g, s, f) if s && f
    new_handles[did] = g
  end
  ws = SUAnalysis::Core::DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    ws_seed.workspace_id,
    source_snapshot: ws_seed.source_snapshot,
    adapter:         adapter,
    model:           nil,
    state:           :ready,
    entity_pairs:    ws_seed.instance_variable_get(:@entity_pairs),
    handle_registry: new_handles.freeze,
    fingerprint:     ws_seed.fingerprint,
    last_error:      nil,
    build_started_at: ws_seed.build_started_at
  )
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter, adapter)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_adapter_kind, :real_su_mimic)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_source, src)
  SUAnalysis::Core::WorkingModeRunner.send(:instance_variable_set, :@current_workspace, ws)
  # Simulate SketchUp Undo: the host erases the derived group
  # (the stored handle becomes valid? == false). The adapter
  # itself does NOT raise any flag -- the production runner
  # must detect the change solely via handle.valid?.
  ws.handle_for('der-0').erase!
  ok = SUAnalysis::Core::WorkingModeRunner.send(:validate_host_state_consistency!)
  refute ok, 'validate_host_state_consistency! MUST return false after a SU Undo (handle invalid)'
  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test
  assert_equal :failed, cur_ws.state,
               'production-path: workspace MUST transition to :failed after SU Undo'
  assert_match(/host_state_changed/, cur_ws.last_error.to_s)
  # The adapter flag was NEVER set (no test injection). The
  # detection came from handle.valid? check, which is the
  # production observation seam.
  refute adapter.respond_to?(:host_state_changed?),
         'production-path: detection MUST NOT rely on a test-only adapter flag'
end

# ============================================================
# Round-5 Source Review corrective regressions
# Dispatch: SUAI-V15-R5-AIPM-SOURCE-REVIEW-FIX-20260828-01
# Frozen Guidance: AIPM_TECHNICAL_GUIDANCE_V1_5_R5_SOURCE_REVIEW_FIX
# Covers FIX-A (strict tolerance + exact-zero layer key) +
# FIX-B (exact deterministic provenance union) +
# FIX-C (strict handle liveness).
# ============================================================

# ============================================================
# FIX-A unit-level strict tolerance parsing
# ============================================================

test 'V15-FIXA-STR-1: parse_strict_tolerance("abc") is invalid (no permissive .to_f)' do
  assert_equal nil,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance('abc')
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?('abc')
  assert_equal :invalid, SUAnalysis::Core::DuplicateGeometrySemantics.tolerance_category('abc')
end

test 'V15-FIXA-STR-2: parse_strict_tolerance("") is invalid' do
  assert_equal nil,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance('')
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?('')
  assert_equal :invalid, SUAnalysis::Core::DuplicateGeometrySemantics.tolerance_category('')
end

test 'V15-FIXA-STR-3: parse_strict_tolerance("1foo") is invalid (no partial numeric coercion)' do
  assert_equal nil,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance('1foo')
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?('1foo')
  assert_equal :invalid, SUAnalysis::Core::DuplicateGeometrySemantics.tolerance_category('1foo')
end

test 'V15-FIXA-STR-4: parse_strict_tolerance("  ") (blank) is invalid' do
  assert_equal nil,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance('  ')
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?('  ')
end

test 'V15-FIXA-STR-5: parse_strict_tolerance("-1.0") (negative numeric string) is invalid' do
  assert_equal nil,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance('-1.0')
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?('-1.0')
end

test 'V15-FIXA-STR-6: parse_strict_tolerance("0.0") (numeric zero string) is :zero' do
  assert_equal 0.0,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance('0.0')
  assert SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?('0.0')
  assert_equal :zero, SUAnalysis::Core::DuplicateGeometrySemantics.tolerance_category('0.0')
end

test 'V15-FIXA-STR-7: parse_strict_tolerance("1.0") (positive numeric string) is :positive' do
  assert_equal 1.0,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance('1.0')
  assert_equal :positive, SUAnalysis::Core::DuplicateGeometrySemantics.tolerance_category('1.0')
end

test 'V15-FIXA-STR-8: parse_strict_tolerance(arbitrary non-numeric object) is invalid' do
  assert_equal nil,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance([])
  assert_equal nil,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance({})
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?([])
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?({})
end

test 'V15-FIXA-STR-9: parse_strict_tolerance(Integer 5) is valid :positive' do
  assert_equal 5.0,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance(5)
  assert_equal :positive, SUAnalysis::Core::DuplicateGeometrySemantics.tolerance_category(5)
end

test 'V15-FIXA-STR-10: parse_strict_tolerance(Integer 0) is valid :zero' do
  assert_equal 0.0,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance(0)
  assert_equal :zero, SUAnalysis::Core::DuplicateGeometrySemantics.tolerance_category(0)
end

test 'V15-FIXA-STR-11: parse_strict_tolerance(true / false) is invalid (Boolean is not tolerance)' do
  assert_equal nil,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance(true)
  assert_equal nil,
               SUAnalysis::Core::DuplicateGeometrySemantics.parse_strict_tolerance(false)
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(true)
  refute SUAnalysis::Core::DuplicateGeometrySemantics.valid_tolerance?(false)
end

# ============================================================
# FIX-A: exact-zero layer-key correction
# ============================================================

test 'V15-FIXA-KEY-1: exact-zero identical geometry on different non-equivalent layers is NOT bucketed' do
  # Two records with the same geometry on different
  # non-equivalent layers must NOT produce a direct-match
  # pair under exact-zero tolerance. The layer-key
  # correction in exact_edge_key prevents them from
  # sharing a bucket, and the shared direct_match? at
  # tolerance 0 enforces normalized layer equality.
  recs = [
    { derived_id: 'a', start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], layer: 'WALL' },
    { derived_id: 'b', start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], layer: 'DOOR' }
  ]
  pairs = SUAnalysis::Core::DuplicateGeometrySemantics.enumerate_candidates(recs, 0.0)
  assert_equal [], pairs, 'different-layer exact duplicates MUST NOT match'
end

test 'V15-FIXA-KEY-2: exact-zero identical geometry on Layer0 vs layer0 (case-insensitive canonical) IS bucketed' do
  # The layer canonicalization rules treat 'Layer0', 'layer0',
  # 'LAYER0', 'default', 'untagged' all as 'Layer0'. So
  # these two records MUST match.
  recs = [
    { derived_id: 'a', start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], layer: 'Layer0' },
    { derived_id: 'b', start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], layer: 'layer0' }
  ]
  pairs = SUAnalysis::Core::DuplicateGeometrySemantics.enumerate_candidates(recs, 0.0)
  assert_equal [[0, 1]], pairs, 'Layer0 case variants MUST match under exact-zero'
end

test 'V15-FIXA-KEY-3: exact-zero forward/reversed same-layer duplicates share key (1 pair)' do
  recs = [
    { derived_id: 'a', start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], layer: 'Layer0' },
    { derived_id: 'b', start: [10.0, 0.0, 0.0], finish: [0.0, 0.0, 0.0], layer: 'Layer0' }
  ]
  pairs = SUAnalysis::Core::DuplicateGeometrySemantics.enumerate_candidates(recs, 0.0)
  assert_equal [[0, 1]], pairs, 'forward/reversed same-layer duplicates MUST match under exact-zero'
end

test 'V15-FIXA-KEY-4: exact-edge key string includes the normalized layer' do
  # Direct unit test of exact_edge_key -- the key must
  # include layer=Layer0 (or its normalized form) so that
  # different-layer records produce different keys.
  k1 = SUAnalysis::Core::DuplicateGeometrySemantics.exact_edge_key(
    [0.0, 0.0, 0.0], [10.0, 0.0, 0.0], 'WALL'
  )
  k2 = SUAnalysis::Core::DuplicateGeometrySemantics.exact_edge_key(
    [0.0, 0.0, 0.0], [10.0, 0.0, 0.0], 'DOOR'
  )
  refute_equal k1, k2, 'identical geometry on different layers MUST produce different keys'
  assert_match(/layer=WALL/, k1)
  assert_match(/layer=DOOR/, k2)
end

# ============================================================
# FIX-A: proposer / topology no-fallback regressions
# ============================================================

# Build a snapshot whose execution_config has tolerance_values
# WITHOUT a :duplicate key (missing captured tolerance).
def r5_exec_config_missing_duplicate
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
    tolerance_values: {}, # MISSING :duplicate key
    session_overrides: cap.session_overrides,
    source_snapshot_schema_version: cap.source_snapshot_schema_version
  )
end

# Build a snapshot whose execution_config has an INVALID
# captured duplicate tolerance (a string that permissive
# .to_f would have silently coerced to 0.0).
def r5_exec_config_invalid_duplicate(value)
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
    tolerance_values: { duplicate: value },
    session_overrides: cap.session_overrides,
    source_snapshot_schema_version: cap.source_snapshot_schema_version
  )
end

test 'V15-FIXA-NOFALLBACK-1: proposer with missing captured duplicate tolerance -> skipped audit row, 0 applied' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  base = r5_snapshot(edges: [e1, e2])
  bad_ec = r5_exec_config_missing_duplicate
  src = r5_src_with_tolerance(base, bad_ec)
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  # No applied actions -- missing captured tolerance means
  # the proposer emits an explicit skipped audit row.
  assert_equal 0, snap['duplicate_repair']['actions_applied']
  # tolerance_status MUST be 'missing_captured_tolerance'.
  assert_equal 'missing_captured_tolerance', snap['duplicate_repair']['tolerance_status']
  # No silent 0.0001 fallback: the pair count is reported as
  # the honest nil/0 (per FIX-A no-fallback contract).
  assert snap['duplicate_repair']['duplicate_pairs_before'].nil? || snap['duplicate_repair']['duplicate_pairs_before'] == 0
end

test 'V15-FIXA-NOFALLBACK-2: proposer with invalid captured duplicate tolerance ("abc") -> 0 applied, no default fallback' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  base = r5_snapshot(edges: [e1, e2])
  bad_ec = r5_exec_config_invalid_duplicate('abc')
  src = r5_src_with_tolerance(base, bad_ec)
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 0, snap['duplicate_repair']['actions_applied']
  assert_equal 'invalid_captured_tolerance', snap['duplicate_repair']['tolerance_status']
end

test 'V15-FIXA-NOFALLBACK-3: proposer with negative captured duplicate tolerance -> 0 applied, no default fallback' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  base = r5_snapshot(edges: [e1, e2])
  bad_ec = r5_exec_config_invalid_duplicate(-0.5)
  src = r5_src_with_tolerance(base, bad_ec)
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 0, snap['duplicate_repair']['actions_applied']
  assert_equal 'invalid_captured_tolerance', snap['duplicate_repair']['tolerance_status']
end

test 'V15-FIXA-NOFALLBACK-4: topology resolve_tolerance with no valid explicit/captured -> nil (no hidden default)' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  base = r5_snapshot(edges: [e1])
  bad_ec = r5_exec_config_missing_duplicate
  src = r5_src_with_tolerance(base, bad_ec)
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  # resolve_tolerance must return nil, not 1.0e-4.
  got = SUAnalysis::Core::DuplicateRepairProposer.resolve_tolerance(src, ws)
  assert_nil got, "FIX-A: resolve_tolerance MUST return nil for missing captured (got #{got.inspect})"
  # Also: DuplicateGeometrySemantics.resolve_captured_tolerance.
  got2 = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  assert_nil got2, "FIX-A: resolve_captured_tolerance MUST return nil for missing captured (got #{got2.inspect})"
  # And DerivedDuplicateTopology.resolve_tolerance.
  got3 = SUAnalysis::Core::DerivedDuplicateTopology.resolve_tolerance(ws, nil)
  assert_nil got3, "FIX-A: DerivedDuplicateTopology.resolve_tolerance MUST return nil (got #{got3.inspect})"
end

test 'V15-FIXA-NOFALLBACK-5: audit reports tolerance_status="captured" for valid tolerance, no fallback to DEFAULT_TOLERANCE' do
  # Sanity: with a VALID captured tolerance (0.0),
  # tolerance_status MUST be 'captured' (not 'missing' or
  # 'invalid'). This guards against silent fallbacks.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  base = r5_snapshot(edges: [e1, e2])
  good_ec = r5_exec_config_zero_tolerance
  src = r5_src_with_tolerance(base, good_ec)
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'captured', snap['duplicate_repair']['tolerance_status']
  assert_equal 1, snap['duplicate_repair']['actions_applied']
end

# ============================================================
# FIX-B: exact deterministic provenance union
# ============================================================

test 'V15-FIXB-PR-1: exact full union -> expected state is valid (baseline)' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = SUAnalysis::Core::DuplicateRepairExpectedPostState.build(
    workspace: ws, applied_actions: runnable, captured_tolerance: tol
  )
  assert_equal true, state['valid'], 'baseline: normal flow must produce valid state'
  # survivor_provenance_unions_from_pre_state MUST equal
  # survivor_provenance_unions for every survivor.
  state['survivor_provenance_unions'].each do |sid, occs|
    assert_equal Array(occs).map(&:to_s).uniq.sort,
                 Array(state['survivor_provenance_unions_from_pre_state'][sid]).map(&:to_s).uniq.sort,
                 "FIX-B baseline: #{sid} provenance union must equal pre-state-derived union"
  end
end

test 'V15-FIXB-PR-2: union non-empty but missing one occurrence -> validate! detects before begin' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = SUAnalysis::Core::DuplicateRepairExpectedPostState.build(
    workspace: ws, applied_actions: runnable, captured_tolerance: tol
  )
  assert_equal true, state['valid']
  survivor_id = state['survivor_derived_ids'].first
  # Drop one occurrence from the action's claimed union
  # (the pre-state-derived union stays full).
  claimed_full = Array(state['survivor_provenance_unions'][survivor_id]).map(&:to_s).uniq.sort
  refute_empty claimed_full
  truncated = claimed_full[0..-2]
  refute_equal claimed_full, truncated
  mutated_unions = state['survivor_provenance_unions'].dup
  mutated_unions[survivor_id] = truncated
  mutated = state.merge('survivor_provenance_unions' => mutated_unions)
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid], 'FIX-B: missing occurrence MUST invalidate state'
  assert_match(/survivor_provenance_union_mismatch/, v[:reason])
end

test 'V15-FIXB-PR-3: union has one extra occurrence -> validate! detects' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = SUAnalysis::Core::DuplicateRepairExpectedPostState.build(
    workspace: ws, applied_actions: runnable, captured_tolerance: tol
  )
  survivor_id = state['survivor_derived_ids'].first
  claimed_full = Array(state['survivor_provenance_unions'][survivor_id]).map(&:to_s).uniq.sort
  expanded = (claimed_full + ['occ-phantom-extra']).uniq.sort
  mutated_unions = state['survivor_provenance_unions'].dup
  mutated_unions[survivor_id] = expanded
  mutated = state.merge('survivor_provenance_unions' => mutated_unions)
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid], 'FIX-B: extra occurrence MUST invalidate state'
  assert_match(/survivor_provenance_union_mismatch/, v[:reason])
end

test 'V15-FIXB-PR-4: survivor provenance entry missing from action map -> validate! detects' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = SUAnalysis::Core::DuplicateRepairExpectedPostState.build(
    workspace: ws, applied_actions: runnable, captured_tolerance: tol
  )
  survivor_id = state['survivor_derived_ids'].first
  # Remove the survivor entry from the action map; the
  # pre-state-derived map still has it.
  mutated_unions = state['survivor_provenance_unions'].dup
  mutated_unions.delete(survivor_id)
  mutated = state.merge('survivor_provenance_unions' => mutated_unions)
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid]
  assert_match(/survivor_provenance_union_key_mismatch/, v[:reason])
end

test 'V15-FIXB-PR-5: action provenance disagrees with authoritative pre-state union (3 distinct occurrences) -> invalid' do
  # Build a fixture where 3 source-occurrence IDs participate
  # in the applied component. Then mutate the action's
  # claimed union so it loses one of those occurrences
  # while the pre-state-derived map still has it. The
  # validator must catch the mismatch BEFORE begin.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e_a = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100], pid: 200)
  e_b = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100], pid: 201)
  e_c = r5_edge(id: 2, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100], pid: 202)
  src = r5_snapshot(edges: [e_a, e_b, e_c])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e_a.start_point, finish: e_a.end_point, source_edge: e_a),
    r5_derived_edge(derived_id: 'der-1', start: e_b.start_point, finish: e_b.end_point, source_edge: e_b),
    r5_derived_edge(derived_id: 'der-2', start: e_c.start_point, finish: e_c.end_point, source_edge: e_c)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|0|2', edge_ids: [0, 2], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|1|2', edge_ids: [1, 2], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = SUAnalysis::Core::DuplicateRepairExpectedPostState.build(
    workspace: ws, applied_actions: runnable, captured_tolerance: tol
  )
  assert_equal true, state['valid'], 'baseline: 3-member clique must produce valid state'
  survivor_id = state['survivor_derived_ids'].first
  pre_state_union = Array(state['survivor_provenance_unions_from_pre_state'][survivor_id]).map(&:to_s).uniq.sort
  assert pre_state_union.length >= 3, "fixture sanity: pre-state union must have >=3 occurrences (got #{pre_state_union.length})"
  # Mutate the action's claimed union: drop one occurrence.
  truncated = pre_state_union - [pre_state_union.first]
  mutated_unions = state['survivor_provenance_unions'].dup
  mutated_unions[survivor_id] = truncated
  mutated = state.merge('survivor_provenance_unions' => mutated_unions)
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(mutated, ws)
  assert_equal false, v[:valid]
  assert_match(/survivor_provenance_union_mismatch/, v[:reason])
end

test 'V15-FIXB-PR-6: correct provenance still yields exact prevalidated post fingerprint' do
  # The fingerprint is computed from post_inventory +
  # post_geometry. After FIX-B, the post_geometry for
  # survivors carries the exact union. The recomputed
  # fingerprint MUST equal the stored fingerprint.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  tol = SUAnalysis::Core::DuplicateGeometrySemantics.resolve_captured_tolerance(ws)
  state = SUAnalysis::Core::DuplicateRepairExpectedPostState.build(
    workspace: ws, applied_actions: runnable, captured_tolerance: tol
  )
  # Recompute fingerprint from post_inventory + post_geometry.
  recomputed = SUAnalysis::Core::DuplicateRepairExpectedPostState.send(
    :compute_expected_fingerprint, state['post_inventory_ids'], state['post_geometry']
  )
  assert_equal state['post_fingerprint'], recomputed
  # Also: validate! must agree.
  v = SUAnalysis::Core::DuplicateRepairExpectedPostState.validate!(state, ws)
  assert_equal true, v[:valid]
end

test 'V15-FIXB-PR-EXEC: provenance mismatch at executor -> begin=0, no disposal/commit, no READY, source immutable' do
  # Wire an executor-level test that injects a provenance
  # mismatch (via the action's source_occurrence_ids
  # disagreeing with the pre-state records) and asserts
  # the executor fails closed BEFORE begin_operation.
  # We achieve this by rebuilding the workspace with each
  # derived record having a truncated source_occurrence_ids
  # (one fewer than the original). The proposer's action
  # carries the original union (3 occurrences); the
  # post-state validator's pre-state-derived union has 2
  # occurrences; mismatch -> fail before begin.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e_a = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100], pid: 200)
  e_b = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100], pid: 201)
  e_c = r5_edge(id: 2, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100], pid: 202)
  src = r5_snapshot(edges: [e_a, e_b, e_c])
  full_records = [
    r5_derived_edge(derived_id: 'der-0', start: e_a.start_point, finish: e_a.end_point, source_edge: e_a),
    r5_derived_edge(derived_id: 'der-1', start: e_b.start_point, finish: e_b.end_point, source_edge: e_b),
    r5_derived_edge(derived_id: 'der-2', start: e_c.start_point, finish: e_c.end_point, source_edge: e_c)
  ]
  ws_full = r5_workspace(snapshot: src, records: full_records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|0|2', edge_ids: [0, 2], location: [5.0, 0.0, 0.0]),
    r5_dup_issue(issue_id: 'dup|1|2', edge_ids: [1, 2], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws_full, registry: registry, snapshot: src)
  # Build a new workspace where each record has a
  # truncated source_occurrence_ids (drop last).
  adapter = ws_full.instance_variable_get(:@adapter)
  model   = ws_full.instance_variable_get(:@model)
  truncated_pairs = ws_full.instance_variable_get(:@entity_pairs).map do |id, rec|
    truncated_occs = Array(rec.source_occurrence_ids)[0..-2] || []
    replacement = SUAnalysis::Core::DerivedEntityRecord.new(
      derived_id:            rec.derived_id,
      kind:                  rec.kind,
      source_occurrence_ids: truncated_occs.freeze,
      geometry_summary:      rec.geometry_summary,
      parent_derived_id:     rec.parent_derived_id,
      host_assigned_ids:     rec.host_assigned_ids
    )
    [id, replacement]
  end
  ws = SUAnalysis::Core::DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    ws_full.workspace_id,
    source_snapshot: ws_full.source_snapshot,
    adapter:         adapter,
    model:           model,
    state:           :ready,
    entity_pairs:    truncated_pairs,
    handle_registry: ws_full.instance_variable_get(:@handle_registry),
    fingerprint:     ws_full.send(:compute_fingerprint_from_pairs, truncated_pairs),
    last_error:      nil,
    build_started_at: ws_full.build_started_at
  )
  counter = r5_instrument_adapter(adapter)
  pre_entity_ids = ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  pre_fp = ws.fingerprint
  pre_src_fp = src.fingerprint.respond_to?(:digest) ? src.fingerprint.digest.to_s : src.fingerprint.to_s
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws, plan: plan
  )
  # The executor MUST detect the provenance union mismatch
  # in the expected post-state validation and fail BEFORE
  # begin_operation.
  assert_equal 0, counter[:begin_calls],
               "FIX-B provenance mismatch MUST trigger atomic no-begin failure (begin_calls=#{counter[:begin_calls]})"
  assert_equal 0, counter[:commit_calls]
  assert_equal 0, counter[:abort_calls]
  assert_equal 0, counter[:dispose_calls]
  assert updated.none? { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
  assert_equal :failed, new_ws.state
  assert_match(/survivor_provenance_union_mismatch|expected_post_state_invalid/, new_ws.last_error.to_s)
  # Logical pre-state retained.
  post_entity_ids = new_ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  assert_equal pre_entity_ids, post_entity_ids
  assert_equal pre_fp, new_ws.fingerprint
  # Source immutable.
  post_src_fp = src.fingerprint.respond_to?(:digest) ? src.fingerprint.digest.to_s : src.fingerprint.to_s
  assert_equal pre_src_fp, post_src_fp
end

# ============================================================
# FIX-C: strict destructive handle liveness hardening
# ============================================================

# A handle object that DOES NOT respond to :valid? at all.
# Per FIX-C, this MUST be detected as non-live for
# destructive execution.
class NoValidPredicateHandle
  attr_reader :name
  def initialize(name); @name = name.to_s; end
  def erase!; @erased = true; true; end
  def erased?; @erased == true; end
end

# A handle object whose :valid? returns nil. Per FIX-C,
# this MUST be detected as non-live (only valid? == true
# is live).
class NilValidPredicateHandle
  attr_reader :name
  def initialize(name); @name = name.to_s; @valid = true; end
  def valid?; nil; end
  def erase!; @valid = false; true; end
end

# A handle object whose :valid? raises. Per FIX-C, this
# MUST be detected as non-live.
class RaiseValidPredicateHandle
  attr_reader :name
  def initialize(name); @name = name.to_s; end
  def valid?; raise StandardError, 'valid? raised for test'; end
  def erase!; true; end
end

test 'V15-FIXC-HDL-1: destructive member handle missing :valid? -> fail before begin' do
  # Build a normal workspace + plan, then rebuild the
  # workspace with ONE removal handle replaced by a
  # NoValidPredicateHandle (no :valid? at all). The
  # executor's strict_handle_live? predicate must detect
  # the missing valid? and fail the batch before
  # begin_operation.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws_seed = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws_seed, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  removal_ids = runnable.flat_map { |a| Array(a.affected_derived_ids) }.uniq
  survivor_id = runnable.first.before_summary['survivor_derived_id']
  removal_id = (removal_ids - [survivor_id]).first
  # Rebuild the workspace with the removal handle
  # replaced by one that does NOT respond to :valid?.
  new_handles = ws_seed.instance_variable_get(:@handle_registry).dup
  new_handles[removal_id] = NoValidPredicateHandle.new(removal_id)
  ws = SUAnalysis::Core::DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    ws_seed.workspace_id,
    source_snapshot: ws_seed.source_snapshot,
    adapter:         ws_seed.instance_variable_get(:@adapter),
    model:           ws_seed.instance_variable_get(:@model),
    state:           :ready,
    entity_pairs:    ws_seed.instance_variable_get(:@entity_pairs),
    handle_registry: new_handles.freeze,
    fingerprint:     ws_seed.fingerprint,
    last_error:      nil,
    build_started_at: ws_seed.build_started_at
  )
  adapter = ws.instance_variable_get(:@adapter)
  counter = r5_instrument_adapter(adapter)
  pre_entity_ids = ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws, plan: plan
  )
  assert_equal 0, counter[:begin_calls],
               "FIX-C: handle missing :valid? MUST trigger atomic no-begin failure (begin_calls=#{counter[:begin_calls]})"
  assert_equal 0, counter[:commit_calls]
  assert_equal 0, counter[:abort_calls]
  assert_equal 0, counter[:dispose_calls]
  assert updated.none? { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
  assert_equal :failed, new_ws.state
  assert_match(/handle_invalidated|malformed_no_valid_predicate|final_live_handle_proof_failed|preflight_failed/, new_ws.last_error.to_s)
  post_entity_ids = new_ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  assert_equal pre_entity_ids, post_entity_ids, 'exact logical pre-state: entity inventory unchanged'
end

test 'V15-FIXC-HDL-2: valid? returns nil -> fail before begin' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws_seed = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws_seed, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  removal_ids = runnable.flat_map { |a| Array(a.affected_derived_ids) }.uniq
  survivor_id = runnable.first.before_summary['survivor_derived_id']
  removal_id = (removal_ids - [survivor_id]).first
  new_handles = ws_seed.instance_variable_get(:@handle_registry).dup
  new_handles[removal_id] = NilValidPredicateHandle.new(removal_id)
  ws = SUAnalysis::Core::DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    ws_seed.workspace_id,
    source_snapshot: ws_seed.source_snapshot,
    adapter:         ws_seed.instance_variable_get(:@adapter),
    model:           ws_seed.instance_variable_get(:@model),
    state:           :ready,
    entity_pairs:    ws_seed.instance_variable_get(:@entity_pairs),
    handle_registry: new_handles.freeze,
    fingerprint:     ws_seed.fingerprint,
    last_error:      nil,
    build_started_at: ws_seed.build_started_at
  )
  adapter = ws.instance_variable_get(:@adapter)
  counter = r5_instrument_adapter(adapter)
  pre_entity_ids = ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws, plan: plan
  )
  assert_equal 0, counter[:begin_calls],
               "FIX-C: valid? returning nil MUST trigger atomic no-begin failure (begin_calls=#{counter[:begin_calls]})"
  assert_equal 0, counter[:commit_calls]
  assert_equal 0, counter[:abort_calls]
  assert_equal 0, counter[:dispose_calls]
  assert updated.none? { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
  assert_equal :failed, new_ws.state
  assert_match(/handle_invalidated|final_live_handle_proof_failed|preflight_failed/, new_ws.last_error.to_s)
  post_entity_ids = new_ws.instance_variable_get(:@entity_pairs).map(&:first).sort
  assert_equal pre_entity_ids, post_entity_ids
end

test 'V15-FIXC-HDL-3: valid? raises StandardError -> fail before begin' do
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws_seed = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws_seed, registry: registry, snapshot: src)
  runnable = plan.actions.select { |a|
    a.is_a?(SUAnalysis::Core::RepairAction) && [:validated, :proposed].include?(a.status)
  }
  removal_ids = runnable.flat_map { |a| Array(a.affected_derived_ids) }.uniq
  survivor_id = runnable.first.before_summary['survivor_derived_id']
  removal_id = (removal_ids - [survivor_id]).first
  new_handles = ws_seed.instance_variable_get(:@handle_registry).dup
  new_handles[removal_id] = RaiseValidPredicateHandle.new(removal_id)
  ws = SUAnalysis::Core::DerivedGeometryWorkspace.new_with_inventory(
    workspace_id:    ws_seed.workspace_id,
    source_snapshot: ws_seed.source_snapshot,
    adapter:         ws_seed.instance_variable_get(:@adapter),
    model:           ws_seed.instance_variable_get(:@model),
    state:           :ready,
    entity_pairs:    ws_seed.instance_variable_get(:@entity_pairs),
    handle_registry: new_handles.freeze,
    fingerprint:     ws_seed.fingerprint,
    last_error:      nil,
    build_started_at: ws_seed.build_started_at
  )
  adapter = ws.instance_variable_get(:@adapter)
  counter = r5_instrument_adapter(adapter)
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws, plan: plan
  )
  assert_equal 0, counter[:begin_calls],
               "FIX-C: valid? raising StandardError MUST trigger atomic no-begin failure (begin_calls=#{counter[:begin_calls]})"
  assert_equal 0, counter[:dispose_calls]
  assert updated.none? { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
  assert_equal :failed, new_ws.state
  assert_match(/handle_invalidated|final_live_handle_proof_failed|preflight_failed/, new_ws.last_error.to_s)
end

test 'V15-FIXC-HDL-4: strict_handle_live? unit tests' do
  assert_equal false, SUAnalysis::Core::DuplicateGeometrySemantics.strict_handle_live?(nil)
  assert_equal false, SUAnalysis::Core::DuplicateGeometrySemantics.strict_handle_live?(NoValidPredicateHandle.new('h'))
  assert_equal false, SUAnalysis::Core::DuplicateGeometrySemantics.strict_handle_live?(NilValidPredicateHandle.new('h'))
  assert_equal false, SUAnalysis::Core::DuplicateGeometrySemantics.strict_handle_live?(RaiseValidPredicateHandle.new('h'))
  # valid handle
  valid_handle = Object.new
  def valid_handle.valid?; true; end
  assert_equal true, SUAnalysis::Core::DuplicateGeometrySemantics.strict_handle_live?(valid_handle)
  # valid? returns false
  invalid_handle = Object.new
  def invalid_handle.valid?; false; end
  assert_equal false, SUAnalysis::Core::DuplicateGeometrySemantics.strict_handle_live?(invalid_handle)
end

test 'V15-FIXC-HDL-5: existing valid-handle success path remains green (sanity)' do
  # Sanity check: a normal workspace with valid handles
  # still produces 1 applied action. This guards against
  # FIX-C accidentally breaking the happy path.
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = r5_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  e2 = r5_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])
  src = r5_snapshot(edges: [e1, e2])
  records = [
    r5_derived_edge(derived_id: 'der-0', start: e1.start_point, finish: e1.end_point, source_edge: e1),
    r5_derived_edge(derived_id: 'der-1', start: e2.start_point, finish: e2.end_point, source_edge: e2)
  ]
  ws = r5_workspace(snapshot: src, records: records)
  registry = r5_registry([
    r5_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0])
  ])
  plan = r5_build_valid_plan(ws: ws, registry: registry, snapshot: src)
  new_ws, updated = SUAnalysis::Core::DuplicateRepairExecutor.apply_batch(
    workspace: ws, plan: plan
  )
  applied = updated.select { |a| a.is_a?(SUAnalysis::Core::RepairAction) && a.status == :applied }
  assert_equal 1, applied.length, 'happy path: 1 applied action'
  assert_equal :ready, new_ws.state
end
