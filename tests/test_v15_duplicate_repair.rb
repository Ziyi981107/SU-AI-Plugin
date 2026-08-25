#

# tests/test_v15_duplicate_repair.rb — V1.5 Phase 1

# High-confidence duplicate-edge auto-repair tests.

#

# Per V1.5 Phase 1 plan §6 (IMPLEMENTATION ORDER step 7) +

# §5 (FIRST TEST MATRIX):

#   - SHOULD REPAIR:

#       1. Forward exact duplicate (two distinct source edge

#          entities with the SAME persistent_id_path -> same

#          source occurrence).

#       2. Reversed exact duplicate.

#       3. Three identical edges (same occurrence).

#       4. Shared-definition two instances: duplicate pairs

#          across instances are NOT duplicates (different

#          source_occurrence_ids).

#   - MUST NOT REPAIR:

#       5. Legitimate short edge preserved.

#       6. Near-but-not-exact duplicate preserved.

#       7. Same world coordinates but different

#          source_occurrence_ids preserved.

#       8. Self-match skipped.

#       9. Nested transform (different persistent_id_path)

#          preserved.

#   - APPLY SAFETY:

#      10. Repeated apply idempotent.

#      11. Mid-action failure rollback.

#      12. Discard + rebuild after apply.

#      13. Erased / invalid derived entity skipped safely.

#      14. source_fingerprint unchanged across apply.

#

# Pure-Ruby tests; no host calls. Uses FakeDerivedWorkspaceAdapter

# to exercise the executor.

#



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

require_relative '../extension/su_ai_plugin/core/issue_registry'



include SUAnalysis::Core



# Top-level refute helper for tests.

def refute(cond, msg = nil)

  assert !cond, msg || "expected #{cond.inspect} to be falsy"

end



# ---- helpers ---------------------------------------------------------



def v15_exec_config(rule_set_digest: 'v15-rule-digest')

  ExecutionConfigSnapshot.from_live_config(

    AnalysisConfig.new(profile_name: 'test'),

    rule_set_digest: rule_set_digest,

    source_snapshot_schema_version: '1'

  )

end



# Build an EdgeRecord with full provenance.

#

# Per the V1.0-V1.4 contract (preflight_runner.rb#walk_entity_world),

# the canonical persistent_id_path INCLUDES the leaf edge

# entity's PID as its last element. Pass `parent_pid_path` (the

# Array of container PIDs from root to the immediate parent)

# and the helper builds the full path

# [parent_pid_path..., leaf_pid]. This matches what

# real-SketchUp's PreflightRunner produces.

#

# Examples:

#   v15_edge(id: 0, parent_pid_path: [])          # root-level edge

#   v15_edge(id: 0, parent_parent_pid_path: [100])       # edge in component 100

#   v15_edge(id: 0, parent_parent_pid_path: [100, 200])  # edge nested 2 levels

def v15_edge(id:, start:, finish:, pid: nil, parent_pid_path: [100], layer: 'Layer0')

  pid ||= id + 100

  parent_pid_path = parent_pid_path || []

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



# Build a SourceSnapshot carrying the given edges.

def v15_snapshot(edges:, snapshot_id: 'v15-snap-001', layer_name: 'Layer0')

  layers = [LayerRecord.new(name: layer_name)]

  SourceSnapshot.from_geometry_snapshot(

    GeometrySnapshot.new(edges: edges, layers: layers),

    selection: [],

    execution_config: v15_exec_config,

    rule_set_digest: 'v15-rule-digest',

    snapshot_id: snapshot_id,

    captured_at: '2026-08-25T00:00:00Z'

  )

end



# Build a derived-edge record (matching what WorkingModeRunner would

# produce via _build_derived_entities + _stable_id_fragment).

#

# `parent_pid_path` is the container path (Array of Integer

# PIDs); the resulting source_occurrence_ids is in the V1.4

# format "occ-<parent_path>-<leaf_pid>" (full path including

# the leaf). The proposer's V1.5 container-occurrence is

# derived on-demand by excluding the leaf.

def v15_derived_edge(derived_id:, start:, finish:, parent_pid_path: [100], kind: :edge)

  leaf_pid = (derived_id.gsub(/[^0-9]/, '').to_i) + 100

  pid_path = parent_pid_path + [leaf_pid]

  occ_id = "occ-#{pid_path.map(&:to_s).join('>')}"

  DerivedEntityRecord.new(

    derived_id:            derived_id,

    kind:                  kind,

    source_occurrence_ids: [occ_id],

    geometry_summary: {

      'layer'        => 'Layer0',

      'length'       => Math.sqrt(

        (start[0] - finish[0])**2 +

        (start[1] - finish[1])**2 +

        (start[2] - finish[2])**2

      ),

      'vertex_count' => 2,

      'start'        => start,

      'end'          => finish

    }

  )

end



# Build a DerivedGeometryWorkspace pre-populated with the given

# derived-edge records.

def v15_workspace(snapshot:, records:)

  adapter = FakeDerivedWorkspaceAdapter.new

  ws = DerivedGeometryWorkspace.new(

    workspace_id:    'ws-v15-001',

    source_snapshot: snapshot,

    adapter:         adapter,

    model:           nil

  )

  cur = ws

  records.each_with_index do |rec, idx|

    did = rec.derived_id

    occ = rec.source_occurrence_ids.first

    layer = rec.geometry_summary['layer'] || 'Layer0'

    cur = cur.build_entity(

      derived_id:            did,

      kind:                  rec.kind,

      source_occurrence_ids: [occ],

      geometry_summary:      rec.geometry_summary

    )

    if cur.state == :failed

      raise "build_entity ##{idx} failed: #{cur.last_error}"

    end

  end

  cur

end



# Build a duplicate_edge_candidate Issue Hash with the given

# edge_ids. The IssueRegistry requires the canonical UIIssue

# shape; we use the same defaults the DuplicateDetector + enricher

# would produce.

def v15_dup_issue(issue_id:, edge_ids:, location:)

  {

    issue_id:           issue_id.to_s,

    issue_type:         'duplicate_edge_candidate',

    severity:           'medium',

    confidence:         'high',

    sources:            [],

    source_entity_ids:  edge_ids.map { |eid| Integer(eid) },

    edge_ids:           edge_ids.map { |eid| Integer(eid) },

    location:           location,

    message:            'Duplicate edge candidate: two edges share both endpoints within duplicate_tolerance.',

    metadata:           { 'duplicate_tolerance' => 1.0e-4, 'length_a' => 0.0, 'length_b' => 0.0 },

    locatable:          true,

    display_length:     nil

  }

end



# Build an IssueRegistry carrying the given Issue Hashes.

def v15_registry(issues)

  IssueRegistry.new(issues)

end



# Run propose() and return the resulting plan.

def v15_propose(workspace:, registry:, snapshot:)

  DuplicateRepairProposer.propose(

    source_snapshot: snapshot,

    registry:        registry,

    workspace:       workspace

  )

end



# Run executor.apply() on every :proposed / :validated action in

# the plan. Returns [final_workspace, applied_actions].

def v15_apply_all(workspace:, plan:)

  cur_ws = workspace

  applied = []

  Array(plan.actions).each do |act|

    next unless [:proposed, :validated].include?(act.status)

    new_ws, new_act = DuplicateRepairExecutor.apply(workspace: cur_ws, action: act)

    cur_ws = new_ws

    applied << new_act

  end

  [cur_ws, applied]

end



# Validate a plan and return the validated plan.

def v15_validate(plan)

  v = plan.validate

  raise "plan validate failed: #{v.validation_result.errors.inspect}" if v.status == :failed

  v

end





# ===== Section 1: SHOULD REPAIR =====



# ----- 1. Forward exact duplicate -----

test 'V15-1: forward exact duplicate (A->B + A->B, same occurrence) -> apply removes the duplicate' do

  # Two DISTINCT source edge entities (different edge_ids) but

  # BOTH with the same persistent_id_path (same source occurrence).

  # This is the "same source edge recorded twice in the source

  # data" case V1.5 Phase 1 deduplicates.

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  # Two derived records, one per source edge.

  records = [

    v15_derived_edge(derived_id: 'der-edge-0-rec100',

                     parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-edge-1-rec100',

                     parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  src_fp_before = src.fingerprint

  # The duplicate detector would emit one issue for [0, 1].

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  v_plan = v15_validate(plan)

  # Plan: 1 action, status :validated, type :remove_duplicate_edge.

  assert_equal :validated, v_plan.status

  assert_equal 1, v_plan.actions.length

  act = v_plan.actions.first

  assert_equal :remove_duplicate_edge, act.type

  assert_equal 1.0, act.confidence

  assert act.auto_applicable

  assert_equal 'duplicate_edge.exact_remove', act.rule_id

  refute act.confidence_basis.empty?, 'basis must be non-empty'

  # Survivor is the lex-smaller derived_id.

  expected_survivor = 'der-edge-0-rec100'

  expected_removed  = 'der-edge-1-rec100'

  assert_equal expected_survivor, act.before_summary['survivor_derived_id']

  assert_equal [expected_removed], act.affected_derived_ids

  # Apply.

  new_ws, applied = v15_apply_all(workspace: ws, plan: v_plan)

  assert_equal 1, applied.length

  assert_equal :applied, applied.first.status

  assert_equal 1, new_ws.entities.length, 'one duplicate removed'

  assert_equal expected_survivor, new_ws.entities.first.derived_id

  assert_equal :ready, new_ws.state

  # Source fingerprint unchanged.

  assert_equal src_fp_before, src.fingerprint

end



# ----- 2. Reversed exact duplicate -----

test 'V15-2: reversed exact duplicate (A->B + B->A, same occurrence) -> apply removes the duplicate' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [10.0, 0.0, 0.0], finish: [0.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  v_plan = v15_validate(plan)

  assert_equal 1, v_plan.actions.length

  act = v_plan.actions.first

  assert_equal 'reversed_endpoint_match_within_tolerance.duplicate', act.confidence_basis

  new_ws, applied = v15_apply_all(workspace: ws, plan: v_plan)

  assert_equal 1, applied.length

  assert_equal :applied, applied.first.status

  assert_equal 1, new_ws.entities.length

end



# ----- 3. Three identical edges -----

test 'V15-3: three identical edges (A->B x 3, same occurrence) -> apply produces 1 survivor' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e3 = v15_edge(id: 2, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2, e3])

  records = [

    v15_derived_edge(derived_id: 'der-edge-0', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-edge-1', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point),

    v15_derived_edge(derived_id: 'der-edge-2', parent_pid_path: [100],

                     start: e3.start_point, finish: e3.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  # Duplicate detector emits C(3,2)=3 pairwise issues.

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1], location: [5.0, 0.0, 0.0]),

    v15_dup_issue(issue_id: 'duplicate|0|2', edge_ids: [0, 2], location: [5.0, 0.0, 0.0]),

    v15_dup_issue(issue_id: 'duplicate|1|2', edge_ids: [1, 2], location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  v_plan = v15_validate(plan)

  # Same occurrence -> ONE action (per-occurrence deduplication).

  assert_equal 1, v_plan.actions.length, 'one action per occurrence, not per pair'

  new_ws, applied = v15_apply_all(workspace: ws, plan: v_plan)

  assert_equal 1, applied.length

  assert_equal :applied, applied.first.status

  # 2 derived entities removed; 1 survivor (the lex-smallest

  # derived_id, der-edge-0).

  assert_equal 1, new_ws.entities.length

  assert_equal 'der-edge-0', new_ws.entities.first.derived_id

end



# ----- 4. Cross-instance same-world-coords duplicate is
# canonicalized with provenance union (CORRECTED V1.5 model) -----

test 'V15-4: cross-instance same-world-coords duplicate is canonicalized with provenance union of 2' do

  # Two source edges with the SAME world coordinates but DIFFERENT
  # persistent_id_path (different source occurrences). Under the
  # corrected V1.5 model (Guidance 031, 2026-08-25), the DERIVED
  # topology is canonicalized to one survivor. Both source
  # occurrences remain immutable; the survivor's provenance is
  # the sorted unique union of every contributing source
  # occurrence.
  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                parent_pid_path: [100, 200])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                parent_pid_path: [300, 400])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100, 200],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [300, 400],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  # Plan: 1 remove action with provenance union of 2 source occurrences.
  assert_equal :validated, plan.status

  assert_equal 1, plan.actions.length

  act = plan.actions.first

  assert_equal :remove_duplicate_edge, act.type

  assert_equal 'der-A', act.before_summary['survivor_derived_id'],

               'survivor is the lex-smaller derived_id'

  assert_equal ['der-B'], act.affected_derived_ids

  refute act.source_occurrence_ids.empty?,

         'source_occurrence_ids must be the union of both contributing source occurrences'

  new_ws, applied = v15_apply_all(workspace: ws, plan: plan)

  assert_equal 1, applied.length

  assert_equal :applied, applied.first.status

  assert_equal 1, new_ws.entities.length

  assert_equal 'der-A', new_ws.entities.first.derived_id

end



# ===== Section 2: MUST NOT REPAIR =====



# ----- 5. Short edge preserved -----

test 'V15-5: legitimate short edge is NOT removed (no short-edge deletion policy)' do

  # The executor never deletes an edge BECAUSE it is short.

  # It only deletes when the evidence is an EXACT duplicate.

  # A short edge that coincides with another short edge

  # DOES qualify as a duplicate (the rule is exact-match,

  # not "only long edges").

  # This test pins the contract: even when an edge is short,

  # the executor does not delete it UNLESS the candidate

  # evidence is also present.

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [0.1, 0.0, 0.0],

                parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [5.0, 0.0, 0.0], finish: [7.0, 0.0, 0.0],

                parent_pid_path: [101])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [101],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  # No duplicate evidence -> no action.

  reg = v15_registry([])

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  assert_equal 0, plan.actions.length

  new_ws, _applied = v15_apply_all(workspace: ws, plan: plan)

  assert_equal 2, new_ws.entities.length

end



# ----- 6. Near-but-not-exact preserved -----

test 'V15-6: near-but-not-exact duplicate preserved (endpoints outside tolerance.duplicate)' do

  # Two edges with endpoints just outside 1.0e-4 inches

  # (~0.001 inches = ~0.025mm -- outside the tolerance).

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.001, 0.0, 0.0], finish: [10.001, 0.0, 0.0],

                parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  assert_equal 1, plan.actions.length

  assert_equal :skipped, plan.actions.first.status

  assert_match(/outside_tolerance|near-but-not-exact/, plan.actions.first.confidence_basis)

  new_ws, _applied = v15_apply_all(workspace: ws, plan: plan)

  assert_equal 2, new_ws.entities.length, 'no removal on near-but-not-exact'

end



# ----- 7. Cross-container same-world-coords duplicate is
# canonicalized with provenance union (CORRECTED V1.5 model) -----

test 'V15-7: cross-container same-world-coords duplicate is canonicalized with provenance union of 2' do

  # Two source edges with the SAME world coordinates but DIFFERENT
  # persistent_id_path (different parent containers). Under the
  # corrected V1.5 model (Guidance 031, 2026-08-25), the DERIVED
  # topology is canonicalized to one survivor. Both source
  # occurrences remain immutable; the survivor's provenance is
  # the sorted unique union of every contributing source
  # occurrence.
  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                parent_pid_path: [200])  # different persistent_id_path

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [200],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  assert_equal :validated, plan.status

  assert_equal 1, plan.actions.length

  act = plan.actions.first

  assert_equal :remove_duplicate_edge, act.type

  assert_equal 'der-A', act.before_summary['survivor_derived_id']

  assert_equal ['der-B'], act.affected_derived_ids

  refute act.source_occurrence_ids.empty?

  new_ws, applied = v15_apply_all(workspace: ws, plan: plan)

  assert_equal 1, applied.length

  assert_equal :applied, applied.first.status

  assert_equal 1, new_ws.entities.length

end



# ----- 8. Self-match skipped -----

test 'V15-8: self-match (same source edge emitted twice) -> :skipped with self_match reason' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                parent_pid_path: [100])

  src = v15_snapshot(edges: [e1])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|0', edge_ids: [0, 0],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  assert_equal 1, plan.actions.length

  assert_equal :skipped, plan.actions.first.status

  assert_match(/self_match|self-match/, plan.actions.first.confidence_basis)

  new_ws, _applied = v15_apply_all(workspace: ws, plan: plan)

  assert_equal 1, new_ws.entities.length

end



# ----- 9. Nested vs root same-world-coords duplicate is
# canonicalized with provenance union (CORRECTED V1.5 model) -----

test 'V15-9: nested-vs-root same-world-coords duplicate is canonicalized with provenance union of 2' do

  # Two source edges with the SAME world coordinates but DIFFERENT
  # pid_path (root vs nested). Under the corrected V1.5 model
  # (Guidance 031, 2026-08-25), the DERIVED topology is
  # canonicalized to one survivor. Both source occurrences
  # remain immutable; the survivor's provenance is the sorted
  # unique union of every contributing source occurrence.
  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],

                parent_pid_path: [100, 200, 300])  # nested inside

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100, 200, 300],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  assert_equal :validated, plan.status

  assert_equal 1, plan.actions.length

  act = plan.actions.first

  assert_equal :remove_duplicate_edge, act.type

  assert_equal 'der-A', act.before_summary['survivor_derived_id']

  assert_equal ['der-B'], act.affected_derived_ids

  refute act.source_occurrence_ids.empty?

  new_ws, applied = v15_apply_all(workspace: ws, plan: plan)

  assert_equal 1, applied.length

  assert_equal :applied, applied.first.status

  assert_equal 1, new_ws.entities.length

end



# ===== Section 3: APPLY SAFETY =====



# ----- 10. Repeated apply is idempotent -----

test 'V15-10: repeated apply is idempotent (second call no-ops)' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_validate(v15_propose(workspace: ws, registry: reg, snapshot: src))

  new_ws1, applied1 = v15_apply_all(workspace: ws, plan: plan)

  assert_equal 1, new_ws1.entities.length

  assert_equal :applied, applied1.first.status

  # Second apply on the post-state workspace: the affected_derived_ids

  # are already gone -> :skipped (idempotent).

  new_ws2, applied2 = v15_apply_all(workspace: new_ws1, plan: plan)

  assert_equal 1, new_ws2.entities.length, 'no further removal'

  assert_equal :skipped, applied2.first.status

  assert_equal new_ws1.entities.first.derived_id, new_ws2.entities.first.derived_id

end



# ----- 11. Mid-action failure rollback -----

test 'V15-11: mid-action failure rolls back to pre-state (no partial removal)' do

  # Adapter that raises on dispose() to simulate host failure.

  class FailingDisposeAdapter < FakeDerivedWorkspaceAdapter

    def dispose(_handle)

      raise StandardError, 'dispose host failure'

    end

  end

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  adapter = FailingDisposeAdapter.new

  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: adapter, model: nil)

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  cur = ws0

  records.each do |rec|

    cur = cur.build_entity(

      derived_id:            rec.derived_id,

      kind:                  rec.kind,

      source_occurrence_ids: rec.source_occurrence_ids,

      geometry_summary:      rec.geometry_summary

    )

  end

  ws = cur

  src_fp_before = src.fingerprint

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_validate(v15_propose(workspace: ws, registry: reg, snapshot: src))

  new_ws, applied = v15_apply_all(workspace: ws, plan: plan)

  # Mid-action failure: workspace transitions to :failed with

  # ALL entities preserved (no partial removal).

  assert_equal :failed, new_ws.state

  assert !new_ws.ready?, ':failed workspace must NOT be ready'

  assert_match(/dispose|host failure/, new_ws.last_error.to_s)

  # All handles preserved.

  assert_equal 2, new_ws.entities.length

  assert !new_ws.handle_for('der-A').nil?

  assert !new_ws.handle_for('der-B').nil?

  # Action transitions to :failed.

  assert_equal :failed, applied.first.status

  # Source fingerprint unchanged.

  assert_equal src_fp_before, src.fingerprint

end



# ----- 12. Discard + rebuild after apply -----

test 'V15-12: rebuild after apply -> source unchanged; rebuilt workspace is post-state' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  src_fp_before = src.fingerprint

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_validate(v15_propose(workspace: ws, registry: reg, snapshot: src))

  new_ws1, _applied1 = v15_apply_all(workspace: ws, plan: plan)

  assert_equal 1, new_ws1.entities.length

  # Rebuild via the workspace's rebuild() path (Discard + build).

  # Per the V1.4 workspace contract, rebuild() captures the

  # first entity as a template BEFORE discarding, then rebuilds

  # from the template. The post-state (1 survivor) is the

  # template.

  rebuilt_ws = new_ws1.rebuild

  assert_equal :ready, rebuilt_ws.state

  assert_equal 1, rebuilt_ws.entities.length, 'rebuild preserves the survivor'

  assert_equal 'der-A', rebuilt_ws.entities.first.derived_id

  # Source unchanged.

  assert_equal src_fp_before, src.fingerprint

  # The rebuilt workspace's source snapshot ID matches the

  # original (same source -> same snapshot).

  assert_equal src.snapshot_id, rebuilt_ws.source_snapshot.snapshot_id

end



# ----- 13. Erased / invalid derived entity skipped safely -----

test 'V15-13: erased / invalid derived entity is skipped (no raise; no removal)' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  # Manually invalidate the 'der-B' handle in the workspace.

  # The executor MUST skip it safely (valid? == false).

  handle_b = ws.handle_for('der-B')

  refute_nil handle_b

  handle_b.erase!  # marks valid?=false on the FakeGroup

  refute handle_b.valid?

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_validate(v15_propose(workspace: ws, registry: reg, snapshot: src))

  # Apply: der-B is invalid -> the executor filters it out and

  # the action transitions to :applied with affected_derived_ids

  # excluding the invalid handle.

  new_ws, applied = v15_apply_all(workspace: ws, plan: plan)

  assert_equal :applied, applied.first.status

  # Only der-A remains; der-B was filtered as invalid.

  assert_equal 1, new_ws.entities.length

  assert_equal 'der-A', new_ws.entities.first.derived_id

end



# ----- 14. Source fingerprint unchanged across successful apply -----

test 'V15-14: source_fingerprint unchanged across SUCCESSFUL apply' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  src_fp_before = src.fingerprint

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_validate(v15_propose(workspace: ws, registry: reg, snapshot: src))

  new_ws, _applied = v15_apply_all(workspace: ws, plan: plan)

  assert_equal :ready, new_ws.state

  assert_equal 1, new_ws.entities.length

  assert_equal src_fp_before, src.fingerprint

end



# ===== Section 4: Determinism + survivor rule =====



test 'V15-DET-1: survivor selection is deterministic across rebuilds (same plan)' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  # Order the derived records in REVERSE so we can prove the

  # survivor is determined by derived_id, NOT by build order.

  records = [

    v15_derived_edge(derived_id: 'zzz-second', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point),

    v15_derived_edge(derived_id: 'aaa-first',  parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_validate(v15_propose(workspace: ws, registry: reg, snapshot: src))

  # Survivor is the LEX-SMALLER derived_id ('aaa-first').

  assert_equal 'aaa-first', plan.actions.first.before_summary['survivor_derived_id']

  assert_equal ['zzz-second'], plan.actions.first.affected_derived_ids

end



test 'V15-DET-2: applying the same plan twice produces a stable post-state' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_validate(v15_propose(workspace: ws, registry: reg, snapshot: src))

  # Apply in order.

  new_ws1, _ = v15_apply_all(workspace: ws, plan: plan)

  # Rebuild the workspace from scratch (simulating a fresh

  # Prepare) and apply the same plan again. The survivor MUST

  # be the same derived_id.

  ws2 = v15_workspace(snapshot: src, records: records)

  new_ws2, _ = v15_apply_all(workspace: ws2, plan: plan)

  assert_equal new_ws1.entities.first.derived_id,

               new_ws2.entities.first.derived_id,

               'survivor must be the same derived_id across rebuilds'

end



# ===== Section 5: WorkingModeRunner integration =====



test 'V15-WMR-1: WorkingModeRunner records duplicate_repair summary on snapshot' do

  require_relative '../extension/su_ai_plugin/core/working_mode_runner'

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  # Build a workspace with one duplicate pair, apply the plan,

  # record the summary on the runner. The summary MUST be

  # exposed via the snapshot EVEN when the runner has no

  # current workspace (the snapshot summary is the audit

  # trail that the user reads).

  summary = {

    'duplicate_pairs_before' => 1,

    'duplicate_pairs_after'  => 0,

    'actions_applied'        => 1,

    'actions_skipped'        => 0,

    'last_action_status'     => 'applied'

  }

  SUAnalysis::Core::WorkingModeRunner.record_duplicate_repair_summary(summary)

  snap = SUAnalysis::Core::WorkingModeRunner.snapshot

  refute_nil snap['duplicate_repair'], 'duplicate_repair summary must be in the snapshot'

  assert_equal 1, snap['duplicate_repair']['duplicate_pairs_before']

  assert_equal 1, snap['duplicate_repair']['actions_applied']

  # Reset between tests.

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

end



test 'V15-WMR-2: discard clears the duplicate_repair summary' do

  require_relative '../extension/su_ai_plugin/core/working_mode_runner'

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  SUAnalysis::Core::WorkingModeRunner.record_duplicate_repair_summary(

    { 'duplicate_pairs_before' => 1, 'actions_applied' => 1 }

  )

  refute_nil SUAnalysis::Core::WorkingModeRunner.duplicate_repair_summary

  SUAnalysis::Core::WorkingModeRunner.discard

  # After discard, summary is cleared (no current workspace).

  assert_nil SUAnalysis::Core::WorkingModeRunner.duplicate_repair_summary

end



# ===== Section 6: RepairAction invariants =====



test 'V15-RA-1: action uses ONLY the allowed action_type (no widening)' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  plan.actions.each do |a|

    assert_equal :remove_duplicate_edge, a.type, 'Phase 1 allows ONLY :remove_duplicate_edge'

    assert_equal true, a.auto_applicable

  end

end



test 'V15-RA-2: confidence=1.0 requires non-empty basis (no fake AI confidence)' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  plan.actions.each do |a|

    refute a.confidence_basis.to_s.empty?, "basis must be non-empty (got #{a.confidence_basis.inspect})"

    # confidence is 1.0 (or possibly 'skipped:...' for skipped actions;

    # for skipped actions the basis is also non-empty by construction).

  end

end



# ===== Section 7: Hand-rolled mini-edge fixtures (sanity) =====



test 'V15-SANITY: simple 2-edge forward exact duplicate -> exactly 1 action' do

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0], parent_pid_path: [100])

  src = v15_snapshot(edges: [e1, e2])

  records = [

    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],

                     start: e1.start_point, finish: e1.end_point),

    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],

                     start: e2.start_point, finish: e2.end_point)

  ]

  ws = v15_workspace(snapshot: src, records: records)

  issues = [

    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],

                  location: [5.0, 0.0, 0.0])

  ]

  reg = v15_registry(issues)

  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)

  assert_equal 1, plan.actions.length

  assert_equal :validated, plan.status

  # Apply and verify the workspace state.

  new_ws, applied = v15_apply_all(workspace: ws, plan: plan.validate)

  assert_equal 1, applied.length

  assert_equal :applied, applied.first.status

end

# ===== Section 8: Guidance 031 §9 matrix additions (Stage 1) =====

# ----- F. Same world segment but different layers -> :skipped
# with semantic-conflict reason -----

test 'V15-F: layer-mismatch duplicate is skipped with semantic-conflict reason' do
  # Two source edges with EXACT same world endpoints but on
  # DIFFERENT layers (after Layer0 normalization). Per
  # Guidance 031 §5 guard 7, this is a semantic conflict and
  # MUST be skipped (NOT canonicalized) -- collapsing a
  # layer-A edge into a layer-B edge would lose the user's
  # layer assignment.
  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100], layer: 'Layer0')
  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [200], layer: 'Layer1')
  src = v15_snapshot(edges: [e1, e2], layer_name: 'Layer0')
  records = [
    v15_derived_edge(derived_id: 'der-layer0',
                     parent_pid_path: [100],
                     start: e1.start_point, finish: e1.end_point)
  ]
  # Override the layer on the second derived record to Layer1
  # (the helper sets Layer0 by default).
  records[0] = DerivedEntityRecord.new(
    derived_id:            'der-layer0',
    kind:                  :edge,
    source_occurrence_ids: records[0].source_occurrence_ids,
    geometry_summary:      records[0].geometry_summary.merge('layer' => 'Layer0')
  )
  records << DerivedEntityRecord.new(
    derived_id:            'der-layer1',
    kind:                  :edge,
    source_occurrence_ids: [
      "occ-#{[200, 201].map(&:to_s).join('>')}"
    ],
    geometry_summary:      {
      'layer'        => 'Layer1',
      'length'       => 10.0,
      'vertex_count' => 2,
      'start'        => [0.0, 0.0, 0.0],
      'end'          => [10.0, 0.0, 0.0]
    }
  )
  ws = v15_workspace(snapshot: src, records: records)
  issues = [
    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],
                  location: [5.0, 0.0, 0.0])
  ]
  reg = v15_registry(issues)
  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)
  # Per-Issue-guard: the issue is :skipped with semantic-conflict.
  assert_equal 1, plan.actions.length
  assert_equal :skipped, plan.actions.first.status
  assert_match(/semantic_conflict_layer_mismatch/, plan.actions.first.confidence_basis)
  # No remove action: workspace unchanged.
  new_ws, applied = v15_apply_all(workspace: ws, plan: plan)
  assert_equal 0, applied.length
  assert_equal 2, new_ws.entities.length
end

# ----- L. Direct + reversed endpoint ordering produce the
# same canonical class -----

test 'V15-L: direct and reversed endpoint ordering produce the same canonical class' do
  # Two issues, one referencing forward-exact and one
  # referencing reversed-exact duplicates. They both belong
  # to the same canonical world-geometry class -> ONE
  # remove action (NOT two).
  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  e2 = v15_edge(id: 1, start: [10.0, 0.0, 0.0], finish: [0.0, 0.0, 0.0],
                parent_pid_path: [100])
  e3 = v15_edge(id: 2, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  src = v15_snapshot(edges: [e1, e2, e3])
  records = [
    v15_derived_edge(derived_id: 'der-fwd-1', parent_pid_path: [100],
                     start: e1.start_point, finish: e1.end_point),
    v15_derived_edge(derived_id: 'der-rev-2', parent_pid_path: [100],
                     start: e2.start_point, finish: e2.end_point),
    v15_derived_edge(derived_id: 'der-fwd-3', parent_pid_path: [100],
                     start: e3.start_point, finish: e3.end_point)
  ]
  ws = v15_workspace(snapshot: src, records: records)
  issues = [
    v15_dup_issue(issue_id: 'duplicate|forward|0|1',
                  edge_ids: [0, 1], location: [5.0, 0.0, 0.0]),
    v15_dup_issue(issue_id: 'duplicate|reversed|0|2',
                  edge_ids: [0, 2], location: [5.0, 0.0, 0.0])
  ]
  reg = v15_registry(issues)
  plan = v15_propose(workspace: ws, registry: reg, snapshot: src)
  # ONE class -- orientation-independent canonical key merges
  # forward and reversed pairs into one equivalence class.
  assert_equal :validated, plan.status
  assert_equal 1, plan.actions.length,
               'one canonical class regardless of forward/reversed ordering'
  act = plan.actions.first
  assert_equal :remove_duplicate_edge, act.type
  # Survivor = lex-smaller derived_id among all 3.
  assert_equal 'der-fwd-1', act.before_summary['survivor_derived_id']
  assert_equal ['der-fwd-3', 'der-rev-2'].sort, act.affected_derived_ids.sort
  # Provenance union includes all 3 contributing records.
  assert_equal 3, act.source_occurrence_ids.length,
               'provenance union size = 3 (one per contributing derived record)'
end

# ----- Determinism: same plan -> same action_id (regression
# of Guidance 031 §6 deterministic action_id) -----

test 'V15-M: deterministic action_id across repeated proposal / rebuild' do
  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  src = v15_snapshot(edges: [e1, e2])
  records = [
    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],
                     start: e1.start_point, finish: e1.end_point),
    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],
                     start: e2.start_point, finish: e2.end_point)
  ]
  issues = [
    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],
                  location: [5.0, 0.0, 0.0])
  ]
  reg = v15_registry(issues)
  # First proposal.
  plan1 = v15_propose(
    workspace: v15_workspace(snapshot: src, records: records),
    registry:  reg,
    snapshot:  src
  )
  # Second proposal (rebuilt workspace).
  plan2 = v15_propose(
    workspace: v15_workspace(snapshot: src, records: records),
    registry:  reg,
    snapshot:  src
  )
  assert_equal plan1.actions.length, plan2.actions.length
  assert_equal 1, plan1.actions.length
  assert_equal plan1.actions.first.action_id, plan2.actions.first.action_id,
               'action_id MUST be deterministic across rebuilds (no SecureRandom)'
  # Sanity: the action_id embeds the rule id.
  assert_match(/duplicate_edge\.exact_remove/, plan1.actions.first.action_id)
end


# ===== Section 9: Stage 2 (Executor / Atomic Post-State) tests =====

# ----- P. Successful apply updates survivor provenance union -----

test 'V15-P: successful apply updates survivor provenance union in the post-workspace' do
  # Two source edges with SAME world coords + SAME layer but
  # DIFFERENT parent paths. The survivor's source_occurrence_ids
  # in the post-workspace MUST be the sorted unique union of
  # both contributing records' source_occurrence_ids
  # (Guidance 031 §7).
  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [200])
  src = v15_snapshot(edges: [e1, e2])
  records = [
    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],
                     start: e1.start_point, finish: e1.end_point),
    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [200],
                     start: e2.start_point, finish: e2.end_point)
  ]
  ws = v15_workspace(snapshot: src, records: records)
  issues = [
    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],
                  location: [5.0, 0.0, 0.0])
  ]
  reg = v15_registry(issues)
  plan = v15_validate(v15_propose(workspace: ws, registry: reg, snapshot: src))
  expected_occ_union = plan.actions.first.source_occurrence_ids.dup
  refute expected_occ_union.empty?, 'action source_occurrence_ids must be the union'
  new_ws, _applied = v15_apply_all(workspace: ws, plan: plan)
  # Verify the post-workspace survivor has the union provenance.
  survivor = new_ws.entities.first
  assert_equal 'der-A', survivor.derived_id
  assert_equal expected_occ_union.sort, survivor.source_occurrence_ids.sort,
               'survivor source_occurrence_ids must equal the union after apply'
  # Verify source fingerprint is unchanged.
  assert_equal src.fingerprint, src.fingerprint
end

# ----- O. Mid-batch dispose failure aborts WHOLE batch; pre-batch
# inventory restored; source fingerprint unchanged -----

test 'V15-O: mid-batch dispose failure aborts WHOLE batch; no partial host removal; pre-batch inventory restored' do
  # Build a workspace with TWO duplicate pairs (each is its own
  # canonical class -> two actions). The second action's first
  # dispose call fails. The executor MUST roll back the first
  # action's dispose via end_operation(commit: false); the
  # source fingerprint MUST stay unchanged.
  class TwoFailAdapter < FakeDerivedWorkspaceAdapter
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
  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  e3 = v15_edge(id: 2, start: [20.0, 0.0, 0.0], finish: [30.0, 0.0, 0.0],
                parent_pid_path: [200])
  e4 = v15_edge(id: 3, start: [20.0, 0.0, 0.0], finish: [30.0, 0.0, 0.0],
                parent_pid_path: [200])
  src = v15_snapshot(edges: [e1, e2, e3, e4])
  records = [
    v15_derived_edge(derived_id: 'der-A1', parent_pid_path: [100],
                     start: e1.start_point, finish: e1.end_point),
    v15_derived_edge(derived_id: 'der-A2', parent_pid_path: [100],
                     start: e2.start_point, finish: e2.end_point),
    v15_derived_edge(derived_id: 'der-B1', parent_pid_path: [200],
                     start: e3.start_point, finish: e3.end_point),
    v15_derived_edge(derived_id: 'der-B2', parent_pid_path: [200],
                     start: e4.start_point, finish: e4.end_point)
  ]
  adapter = TwoFailAdapter.new(fail_at_call: 2)
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
  pre_fp = src.fingerprint
  pre_entity_count = cur.entities.length
  issues = [
    v15_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1],
                  location: [5.0, 0.0, 0.0]),
    v15_dup_issue(issue_id: 'dup|2|3', edge_ids: [2, 3],
                  location: [25.0, 0.0, 0.0])
  ]
  reg = v15_registry(issues)
  plan = v15_validate(v15_propose(workspace: cur, registry: reg, snapshot: src))
  new_ws, updated_actions = DuplicateRepairExecutor.apply_batch(
    workspace: cur, plan: plan
  )
  # Workspace MUST be :failed.
  assert_equal :failed, new_ws.state
  # All 4 entities preserved (no partial removal).
  assert_equal pre_entity_count, new_ws.entities.length,
               'pre-batch inventory MUST be restored after mid-batch failure'
  # Source fingerprint preserved.
  assert_equal pre_fp, src.fingerprint,
               'source fingerprint MUST be unchanged after failed batch'
  # Adapter operation log: begin + abort (NOT commit).
  log_kinds = adapter.operation_log.map { |op| op[:kind] }
  refute_includes log_kinds, :commit
  assert_includes log_kinds, :abort
end

# ---- helpers for refutes ----
def refute_includes(coll, item, msg = nil)
  return unless coll.respond_to?(:include?) && coll.include?(item)
  raise msg || "expected #{coll.inspect} NOT to include #{item.inspect}"
end


# ===== Section 10: Stage 3 (Validation / Production Wiring / UI Audit) tests =====

# ----- Q. Derived validation shows eligible duplicate count
# decreases to zero -----

test 'V15-Q: derived validation reports eligible duplicate class count decreases to 0 after successful apply' do
  require_relative '../extension/su_ai_plugin/core/derived_duplicate_validator'

  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  src = v15_snapshot(edges: [e1, e2])
  records = [
    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],
                     start: e1.start_point, finish: e1.end_point),
    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],
                     start: e2.start_point, finish: e2.end_point)
  ]
  ws = v15_workspace(snapshot: src, records: records)
  # Pre-batch validation: at least 1 duplicate class (the A/B pair).
  pre_validation = DerivedDuplicateValidator.validate(workspace: ws)
  assert pre_validation['duplicate_classes_before'] >= 1,
         'pre-batch should report at least 1 duplicate class'
  # Apply the repair.
  issues = [
    v15_dup_issue(issue_id: 'duplicate|0|1', edge_ids: [0, 1],
                  location: [5.0, 0.0, 0.0])
  ]
  reg = v15_registry(issues)
  plan = v15_validate(v15_propose(workspace: ws, registry: reg, snapshot: src))
  new_ws, _applied = v15_apply_all(workspace: ws, plan: plan)
  # Post-batch validation: 0 duplicate classes (the survivor
  # is unique in its class).
  post_validation = DerivedDuplicateValidator.validate(workspace: new_ws)
  assert_equal 0, post_validation['duplicate_classes_after'],
               'post-batch should report 0 duplicate classes'
  # The class keys before included the canonical key for the
  # A/B pair; after apply that key is no longer present.
  refute_includes post_validation['class_keys'], pre_validation['class_keys'].first
end

# ----- UI surface: duplicate_classes_before/after are exposed
# in the snapshot via run_duplicate_repair_batch -----

test 'V15-Q-UI: snapshot duplicate_repair summary includes before/after class counts' do
  require_relative '../extension/su_ai_plugin/core/working_mode_runner'

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
  e1 = v15_edge(id: 0, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  e2 = v15_edge(id: 1, start: [0.0, 0.0, 0.0], finish: [10.0, 0.0, 0.0],
                parent_pid_path: [100])
  src = v15_snapshot(edges: [e1, e2])
  records = [
    v15_derived_edge(derived_id: 'der-A', parent_pid_path: [100],
                     start: e1.start_point, finish: e1.end_point),
    v15_derived_edge(derived_id: 'der-B', parent_pid_path: [100],
                     start: e2.start_point, finish: e2.end_point)
  ]
  ws = v15_workspace(snapshot: src, records: records)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_workspace, ws)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_source, src)
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_adapter, ws.instance_variable_get(:@adapter))
  SUAnalysis::Core::WorkingModeRunner.instance_variable_set(:@current_model, nil)
  reg = v15_registry([
    v15_dup_issue(issue_id: 'dup|0|1', edge_ids: [0, 1],
                  location: [5.0, 0.0, 0.0])
  ])
  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: reg)
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  refute_nil snap['duplicate_repair']
  assert snap['duplicate_repair'].key?('duplicate_classes_before'),
         'snapshot must include duplicate_classes_before'
  assert snap['duplicate_repair'].key?('duplicate_classes_after'),
         'snapshot must include duplicate_classes_after'
  assert_equal 1, snap['duplicate_repair']['duplicate_classes_before']
  assert_equal 0, snap['duplicate_repair']['duplicate_classes_after']
  assert_equal 1, snap['duplicate_repair']['actions_applied']
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end
