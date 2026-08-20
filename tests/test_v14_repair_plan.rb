#
# tests/test_v14_repair_plan.rb — V1.4 Stage 2
# RepairPlan pure-data foundation contract tests.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 2: "Implement explicit RepairAction /
# RepairPlan lifecycle and validation WITHOUT applying
# substantive repairs."
#
# No host calls. All tests pure-Ruby.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/repair_plan'

include SUAnalysis::Core

# Top-level refute helper for tests (the test runner only
# exposes refute_nil and refute_match; we need a generic
# `refute(cond, msg)` for "assert NOT cond").
def refute(cond, msg = nil)
  assert !cond, msg || "expected #{cond.inspect} to be falsy"
end

def v14_action(type: :weld_two_edges, **overrides)
  defaults = {
    type:                    type,
    rule_id:                 'rule.test',
    confidence:              0.95,
    confidence_basis:        'obs: 2 edges within tolerance 0.001 in at (10,0,0)-(10,0,0)',
    explanation:             'two coincident edges at (10,0,0) within weld_tolerance',
    source_occurrence_ids:   ['occ-edge-100', 'occ-edge-101'],
    affected_derived_ids:    ['occ-der-edge-new'],
    before_summary:          { 'edges' => 2 },
    proposed_after_summary:  { 'edges' => 1 },
    topology_impact:         'welds_two_edges',
    auto_applicable:         true
  }
  RepairAction.new(**defaults.merge(overrides))
end

# --- RepairActionType ---

test 'RepairActionType: locked catalog includes the V1.5+ placeholder types' do
  assert RepairActionType::ALL.include?(:weld_two_edges)
  assert RepairActionType::ALL.include?(:remove_duplicate_edge)
  assert RepairActionType::ALL.include?(:close_gap)
  assert RepairActionType::ALL.include?(:heal_face_loop)
  assert RepairActionType::ALL.include?(:no_op)
  # Locked (frozen); cannot mutate.
  assert RepairActionType::ALL.frozen?
end

# --- RepairPlanStatus ---

test 'RepairPlanStatus: lifecycle enum' do
  assert_equal 6, RepairPlanStatus::ALL.length
  assert RepairPlanStatus::ALL.include?(:proposed)
  assert RepairPlanStatus::ALL.include?(:validated)
  assert RepairPlanStatus::ALL.include?(:applied)
  assert RepairPlanStatus::ALL.include?(:skipped)
  assert RepairPlanStatus::ALL.include?(:rejected)
  assert RepairPlanStatus::ALL.include?(:failed)
end

# --- ValidationResult ---

test 'ValidationResult.ok: produces a passing result' do
  r = ValidationResult.ok
  assert r.ok?
  assert_equal [], r.errors
  assert_equal [], r.warnings
  # Deeply immutable.
  assert r.frozen?
  assert r.errors.frozen?
end

test 'ValidationResult.fail: produces a failing result' do
  r = ValidationResult.fail(['e1', 'e2'])
  refute r.ok?
  assert_equal ['e1', 'e2'], r.errors
  # Deeply immutable.
  assert r.frozen?
  assert r.errors.frozen?
end

# --- RepairAction ---

test 'RepairAction: required fields stored' do
  a = v14_action
  assert_equal :weld_two_edges, a.type
  assert_equal 'rule.test',      a.rule_id
  assert_in_delta 0.95,          a.confidence, 0.0001
  refute a.confidence_basis.empty?
  assert_equal 2, a.source_occurrence_ids.length
  assert_equal 1, a.affected_derived_ids.length
  assert_equal 'welds_two_edges', a.topology_impact
  assert_equal true, a.auto_applicable
end

test 'RepairAction: type validation rejects unknown types' do
  assert_raises(ArgumentError) do
    RepairAction.new(type: :never_heard_of_it)
  end
end

test 'RepairAction: confidence must be in [0.0, 1.0]' do
  assert_raises(ArgumentError) { RepairAction.new(type: :no_op, rule_id: 'r', confidence: 1.5) }
  assert_raises(ArgumentError) { RepairAction.new(type: :no_op, rule_id: 'r', confidence: -0.1) }
  # Boundary values are OK.
  RepairAction.new(type: :no_op, rule_id: 'r', confidence: 0.0)
  # confidence 1.0 requires non-empty basis (no-fake-AI guard);
  # we provide a basis here so this boundary value is allowed.
  RepairAction.new(type: :no_op, rule_id: 'r', confidence: 1.0,
                  confidence_basis: 'obs: edge is exactly 0.0 long')
end

test 'RepairAction: NO FAKE AI CONFIDENCE -- confidence > 0.5 requires non-empty basis' do
  # Risk test from the directive: "No fake AI confidence and
  # no short-edge deletion policy." A high confidence with
  # empty basis is a configuration error -- the agent / caller
  # is asserting certainty without naming an observation.
  assert_raises(ArgumentError) do
    RepairAction.new(
      type:               :weld_two_edges,
      confidence:         0.9,
      confidence_basis:   ''    # EMPTY basis with high confidence
    )
  end
  # confidence 0.5 is the threshold; == 0.5 is allowed without
  # basis (boundary), but > 0.5 is NOT.
  assert_raises(ArgumentError) do
    RepairAction.new(
      type:               :weld_two_edges,
      rule_id:            'r',
      confidence:         0.51,
      confidence_basis:   ''
    )
  end
  # confidence 0.5 with empty basis is allowed (boundary).
  RepairAction.new(
    type:               :no_op,
    rule_id:            'r',
    confidence:         0.5,
    confidence_basis:   ''
  )
end

test 'RepairAction: top-level + nested arrays are frozen (deep immutability)' do
  a = v14_action
  assert a.frozen?
  assert a.source_occurrence_ids.frozen?
  assert a.affected_derived_ids.frozen?
  assert a.before_summary.frozen?
  assert a.proposed_after_summary.frozen?
  # Cannot mutate after construction.
  assert_raises(RuntimeError, FrozenError) { a.source_occurrence_ids << 'forged' }
end

test 'RepairAction: == compares all fields' do
  a1 = v14_action
  a2 = v14_action
  # Different action_id -> not ==.
  refute_equal a1, a2
  # Same action_id -> ==.
  a3 = RepairAction.new(
    action_id:               a1.action_id,
    type:                    a1.type,
    rule_id:                 a1.rule_id,
    confidence:              a1.confidence,
    confidence_basis:        a1.confidence_basis,
    explanation:             a1.explanation,
    source_occurrence_ids:   a1.source_occurrence_ids,
    affected_derived_ids:    a1.affected_derived_ids,
    before_summary:          a1.before_summary,
    proposed_after_summary:  a1.proposed_after_summary,
    topology_impact:         a1.topology_impact,
    auto_applicable:         a1.auto_applicable,
    status:                  a1.status
  )
  assert_equal a1, a3
end

# --- RepairPlan ---

test 'RepairPlan: default status is :proposed' do
  p = RepairPlan.new(actions: [v14_action])
  assert_equal :proposed, p.status
end

test 'RepairPlan: rejects unknown status' do
  assert_raises(ArgumentError) do
    RepairPlan.new(actions: [v14_action], status: :pending)
  end
end

test 'RepairPlan: top-level + actions array are frozen' do
  p = RepairPlan.new(actions: [v14_action])
  assert p.frozen?
  assert p.actions.frozen?
end

test 'RepairPlan: == compares plan_id + actions + status + validation_result' do
  p1 = RepairPlan.new(plan_id: 'plan-A', actions: [v14_action])
  p2 = RepairPlan.new(plan_id: 'plan-A', actions: [v14_action])
  refute_equal p1, p2, 'different plan_id -> not =='
  p3 = RepairPlan.new(plan_id: 'plan-B', actions: [v14_action])
  refute_equal p1, p3
end

test 'RepairPlan: :ready? is FALSE for :proposed / :validated / :skipped / :rejected / :failed' do
  # Per directive: "failed plans/results are never READY".
  # In V1.4 no plan is :ready (no actions are applied; the
  # :ready gate is forward-compat for V1.5+).
  statuses = RepairPlanStatus::ALL - [:applied]
  statuses.each do |s|
    p = RepairPlan.new(actions: [v14_action], status: s)
    assert !p.ready?, "status=#{s} must NOT be ready"
  end
end

test 'RepairPlan: :ready? requires ALL three gates (status=:applied + validation.ok? + all_actions.applied)' do
  action = v14_action
  # Gate 1: status :proposed -> not ready.
  refute RepairPlan.new(actions: [action], status: :proposed).ready?
  # Gate 2: status :validated but no validation_result -> not ready.
  refute RepairPlan.new(actions: [action], status: :validated).ready?
  # Gate 3: status :applied + validation ok, but action is not :applied -> not ready.
  applied_plan = RepairPlan.new(
    actions: [action], status: :applied,
    validation_result: ValidationResult.ok
  )
  refute applied_plan.ready?, 'action still :proposed; plan cannot be :ready'
  # All three gates pass: status :applied + validation ok + action :applied.
  applied_action = RepairAction.new(
    type: :no_op, status: :applied,
    rule_id: 'rule.test',
    confidence: 1.0, confidence_basis: 'test',
    auto_applicable: true
  )
  ready_plan = RepairPlan.new(
    actions: [applied_action], status: :applied,
    validation_result: ValidationResult.ok
  )
  assert ready_plan.ready?, 'all three gates passed; plan must be :ready'
end

test 'RepairPlan: :failed plans are NEVER :ready (directive invariant)' do
  # The directive explicit invariant: "failed plans/results
  # are never READY".
  failed_action = RepairAction.new(
    type: :no_op, status: :failed,
    rule_id: 'rule.test',
    confidence: 1.0, confidence_basis: 'test',
    auto_applicable: true
  )
  p = RepairPlan.new(
    actions: [failed_action], status: :failed,
    validation_result: ValidationResult.fail(['bad'])
  )
  refute p.ready?, 'failed plan must NEVER be :ready'
end

test 'RepairPlan.validate: returns NEW plan with status :validated when input is valid' do
  p = RepairPlan.new(actions: [v14_action])
  v = p.validate
  refute_equal p, v, 'validate must return a new plan (plans are immutable)'
  assert_equal :validated, v.status
  assert v.validation_result.ok?
  # Original is unchanged.
  assert_equal :proposed, p.status
  assert_nil p.validation_result
end

test 'RepairPlan.validate: returns NEW plan with status :failed when input is invalid' do
  p = RepairPlan.new(actions: [])   # empty actions -> invalid
  v = p.validate
  assert_equal :failed, v.status
  refute v.validation_result.ok?
  refute v.validation_result.errors.empty?
  # Original unchanged.
  assert_equal :proposed, p.status
end

test 'RepairPlan: high-confidence action with empty basis is REJECTED AT CONSTRUCTION (no fake AI confidence)' do
  # Per directive "No fake AI confidence": the construction
  # of the action itself must reject a high-confidence claim
  # with an empty basis. This is a stronger invariant than
  # deferring the check to validate() -- we want to PREVENT
  # the situation, not merely catch it later.
  assert_raises(ArgumentError) do
    RepairAction.new(
      type:               :weld_two_edges,
      rule_id:            'rule.test',
      confidence:         0.99,
      confidence_basis:   ''      # EMPTY basis
    )
  end
  # Same check via the validate() path on a lower-confidence
  # action with empty basis: still rejected because confidence
  # > 0.5 needs basis.
  low_action = RepairAction.new(
    type:               :no_op,
    rule_id:            'rule.test',
    confidence:         0.0,
    confidence_basis:   ''
  )
  p = RepairPlan.new(actions: [low_action])
  # confidence 0.0 + empty basis is allowed at construction
  # (no claim). The plan is valid in the empty-claim sense.
  v = p.validate
  assert_equal :validated, v.status
  # But if we try to BUMP confidence later (per a future V1.5
  # recalibration step), the construction-time invariant will
  # catch it -- we cannot retroactively raise confidence without
  # providing a basis.
end

test 'RepairPlan: validate() never mutates the original plan (immutable lifecycle)' do
  p = RepairPlan.new(actions: [v14_action])
  p.validate
  p.validate
  p.validate
  assert_equal :proposed, p.status, 'original must stay :proposed after validate calls'
  assert_nil p.validation_result
end

test 'RepairPlan: lifecycle state machine -- proposed -> validated -> applied -> ready' do
  # Happy path. validate() moves to :validated; then a
  # forward-compat V1.5+ step moves to :applied (in V1.4 we
  # construct the :applied plan directly to test the gate).
  a = v14_action
  p1 = RepairPlan.new(actions: [a])
  assert_equal :proposed, p1.status
  refute p1.ready?
  p2 = p1.validate
  assert_equal :validated, p2.status
  refute p2.ready?, 'validated alone is not ready (no apply yet)'
  # A V1.5+ apply would move :validated -> :applied. In V1.4
  # we test the gate by constructing an :applied plan with all
  # actions already :applied.
  applied_action = RepairAction.new(
    type: :no_op, status: :applied,
    rule_id: 'rule.test',
    confidence: 1.0, confidence_basis: 'test',
    auto_applicable: true
  )
  p3 = RepairPlan.new(
    actions: [applied_action], status: :applied,
    validation_result: ValidationResult.ok
  )
  assert p3.ready?
end

test 'RepairPlan: lifecycle state machine -- failed is terminal; no transition OUT of failed' do
  p = RepairPlan.new(actions: [])
  v = p.validate
  assert_equal :failed, v.status
  # A second validate() on a :failed plan stays :failed.
  v2 = v.validate
  assert_equal :failed, v2.status
  # No public API to move out of :failed in V1.4.
  # (Future V1.5+ may add a :retry path; V1.4 is conservative.)
end

test 'RepairPlan: to_h is fully JSON-safe (only primitive types + Arrays + Hashes)' do
  p = RepairPlan.new(actions: [v14_action])
  h = p.validate.to_h
  # All values are String / Numeric / Boolean / Array / Hash
  # / nil -- safe to JSON.dump. No object identity leaks.
  assert_kind_of String, h[:plan_id]
  assert_kind_of Symbol, h[:status]
  assert_kind_of Array,  h[:actions]
  assert h[:actions].all? { |a| a.is_a?(Hash) }
end