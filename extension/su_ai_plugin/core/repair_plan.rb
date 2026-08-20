#
# core/repair_plan.rb — V1.4 RepairAction + RepairPlan pure-data
# foundation.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL PREVIEW),
# Stage 2: "RepairPlan pure-data foundation. Implement
# explicit RepairAction/RepairPlan lifecycle and validation
# WITHOUT applying substantive repairs."
#
# Locked semantics:
#   - action_id / type / rule_id: stable identity
#   - confidence + confidence_basis: evidence-driven, NEVER
#     a fake AI score. The confidence_basis field names the
#     observation(s) the confidence was derived from.
#   - explanation: human-readable reason for the action.
#   - source_occurrence_ids: snapshot-local occurrence IDs
#     (from the SourceSnapshot's selection_scope) that this
#     action targets.
#   - affected_derived_ids: snapshot-local derived IDs the
#     action proposes to create / modify / delete.
#   - before_summary / proposed_after_summary: structural
#     previews (Hash, primitive values only).
#   - topology_impact: a string describing the structural
#     shape change (e.g. "welds_two_edges", "removes_duplicate").
#   - auto_applicable: Boolean. TRUE means the action can be
#     applied WITHOUT a confirmation gate (per the captured
#     config's safety rules). FALSE means it requires an
#     explicit user / codex decision.
#
# Lifecycle statuses (RepairPlan.status):
#   :proposed  - initial; not yet validated
#   :validated - ValidationResult is set; status stays :proposed
#                until apply / skip / reject / fail
#   :applied   - the action ran (V1.5+ behavior; V1.4 keeps
#                this slot for forward compat; in V1.4 no
#                action is actually applied, so a V1.4 plan
#                with status :applied is reserved for future
#                use AND must also pass the lifecycle gate)
#   :skipped   - user / codex chose to skip
#   :rejected  - user / codex chose to reject
#   :failed    - validation OR apply failed; :failed is
#                NEVER :ready
#
# :ready means "the plan's actions have been applied to the
# derived workspace and the workspace is consistent". A plan
# is :ready ONLY if its status is :applied AND its
# validation_result.is_ok? is true AND its actions are all
# :applied status. Per directive: "failed plans/results are
# never READY".
#
# No fake AI confidence: confidence is a Float in [0.0, 1.0]
# derived from the captured config's deterministic rule. The
# confidence_basis field MUST name the specific
# observations / rules that produced the value. The two
# fields together are auditable.
#

require 'securerandom'

module SUAnalysis
  module Core
    # Canonical repair-action types (V1.5+ will define the
    # actual rules; V1.4 only enumerates the locked catalog).
    # Adding a new type here is a schema bump.
    module RepairActionType
      ALL = [
        :weld_two_edges,
        :remove_duplicate_edge,
        :close_gap,
        :remove_zero_length_edge,
        :heal_face_loop,
        :flatten_component,
        :no_op                      # explicitly no repair; for tests
      ].freeze
    end

    # Status set (the lifecycle enum).
    module RepairPlanStatus
      ALL = [
        :proposed,
        :validated,
        :applied,
        :skipped,
        :rejected,
        :failed
      ].freeze
    end

    # Validation result: OK or an error list.
    class ValidationResult
      attr_reader :ok, :errors, :warnings

      def initialize(ok:, errors: [], warnings: [])
        @ok = ok ? true : false
        @errors   = (errors   || []).dup.freeze
        @warnings = (warnings || []).dup.freeze
        freeze
      end

      def ok?
        @ok
      end

      def to_h
        { ok: ok, errors: errors, warnings: warnings }
      end

      def self.ok
        new(ok: true)
      end

      def self.fail(errors)
        new(ok: false, errors: errors)
      end
    end

    # One proposed repair step. Immutable.
    class RepairAction
      attr_reader :action_id, :type, :rule_id,
                  :confidence, :confidence_basis,
                  :explanation,
                  :source_occurrence_ids,
                  :affected_derived_ids,
                  :before_summary, :proposed_after_summary,
                  :topology_impact,
                  :auto_applicable,
                  :status

      def initialize(action_id: nil, type:, rule_id:,
                     confidence: 0.0, confidence_basis: '',
                     explanation: '',
                     source_occurrence_ids: [],
                     affected_derived_ids: [],
                     before_summary: {},
                     proposed_after_summary: {},
                     topology_impact: 'no_op',
                     auto_applicable: false,
                     status: :proposed)
        unless RepairActionType::ALL.include?(type)
          raise ArgumentError, "unknown RepairAction type: #{type.inspect}"
        end
        unless confidence.is_a?(Numeric) && confidence >= 0.0 && confidence <= 1.0
          raise ArgumentError, "confidence must be Float in [0.0, 1.0], got #{confidence.inspect}"
        end
        unless confidence_basis.is_a?(String)
          raise ArgumentError, "confidence_basis must be a String, got #{confidence_basis.inspect}"
        end
        # No fake AI confidence: if confidence is high but
        # confidence_basis is empty, that's a configuration
        # error. We allow confidence 0.0 with empty basis (no
        # observation -> no claim).
        if confidence > 0.5 && confidence_basis.empty?
          raise ArgumentError,
                "confidence > 0.5 requires non-empty confidence_basis " \
                "(no fake AI confidence); got confidence=#{confidence} basis=#{confidence_basis.inspect}"
        end
        @action_id               = (action_id || "act-#{SecureRandom.hex(4)}").freeze
        @type                    = type.to_sym.freeze
        @rule_id                 = rule_id.to_s.freeze
        @confidence              = confidence.to_f
        @confidence_basis        = confidence_basis.to_s.freeze
        @explanation             = explanation.to_s.freeze
        @source_occurrence_ids   = (source_occurrence_ids || []).dup.freeze
        @affected_derived_ids    = (affected_derived_ids || []).dup.freeze
        @before_summary          = (before_summary || {}).dup.freeze
        @proposed_after_summary  = (proposed_after_summary || {}).dup.freeze
        @topology_impact         = topology_impact.to_s.freeze
        @auto_applicable         = auto_applicable ? true : false
        @status                  = status.to_sym.freeze
        freeze
      end

      def ==(other)
        return false unless other.is_a?(RepairAction)
        action_id == other.action_id &&
          type == other.type &&
          rule_id == other.rule_id &&
          confidence == other.confidence &&
          confidence_basis == other.confidence_basis &&
          explanation == other.explanation &&
          source_occurrence_ids == other.source_occurrence_ids &&
          affected_derived_ids == other.affected_derived_ids &&
          before_summary == other.before_summary &&
          proposed_after_summary == other.proposed_after_summary &&
          topology_impact == other.topology_impact &&
          auto_applicable == other.auto_applicable &&
          status == other.status
      end
      alias eql? ==

      def hash
        [action_id, type, rule_id, confidence, confidence_basis,
         explanation, source_occurrence_ids, affected_derived_ids,
         before_summary, proposed_after_summary, topology_impact,
         auto_applicable, status].hash
      end

      def to_h
        {
          action_id:               action_id,
          type:                    type,
          rule_id:                 rule_id,
          confidence:              confidence,
          confidence_basis:        confidence_basis,
          explanation:             explanation,
          source_occurrence_ids:   source_occurrence_ids,
          affected_derived_ids:    affected_derived_ids,
          before_summary:          before_summary,
          proposed_after_summary:  proposed_after_summary,
          topology_impact:         topology_impact,
          auto_applicable:         auto_applicable,
          status:                  status
        }
      end
    end

    # A RepairPlan is the locked lifecycle container. Immutable.
    class RepairPlan
      attr_reader :plan_id, :actions, :status, :validation_result

      # All allowed status values. Per directive: "Use proposed
      # / applied / skipped / rejected / failed states; failed
      # plans/results are never READY."
      STATUSES = RepairPlanStatus::ALL

      def initialize(plan_id: nil, actions: [], status: :proposed, validation_result: nil)
        @plan_id  = (plan_id || "plan-#{SecureRandom.hex(4)}").freeze
        @actions  = (actions || []).dup.freeze
        unless STATUSES.include?(status)
          raise ArgumentError, "unknown RepairPlan status: #{status.inspect}"
        end
        @status  = status.to_sym.freeze
        @validation_result = validation_result  # may be nil
        freeze
      end

      # :ready means the plan's actions have been applied to
      # the derived workspace AND the workspace is consistent.
      # Per directive: "failed plans/results are never READY".
      # V1.4 does not apply actions; a V1.4 plan can be
      # :proposed / :validated / :skipped / :rejected /
      # :failed, but never :ready.
      def ready?
        status == :applied &&
          !validation_result.nil? &&
          validation_result.ok? &&
          actions.all? { |a| a.status == :applied }
      end

      def ==(other)
        return false unless other.is_a?(RepairPlan)
        plan_id == other.plan_id &&
          actions == other.actions &&
          status == other.status &&
          validation_result == other.validation_result
      end
      alias eql? ==

      def hash
        [plan_id, actions, status, validation_result].hash
      end

      def to_h
        {
          plan_id:            plan_id,
          actions:            actions.map(&:to_h),
          status:             status,
          validation_result:  validation_result ? validation_result.to_h : nil
        }
      end

      # Pure-Ruby validation pass. Returns a new RepairPlan
      # with status :validated (if validation passed) or
      # :failed (if validation failed). Does NOT mutate self
      # (plans are deeply frozen; lifecycle transitions
      # produce new instances). This is the only legal way
      # to move a plan to a terminal state in V1.4 -- apply
      # happens in V1.5+.
      def validate
        errors = []
        if actions.empty?
          errors << 'RepairPlan has no actions'
        end
        actions.each do |a|
          unless RepairActionType::ALL.include?(a.type)
            errors << "action #{a.action_id} has unknown type #{a.type.inspect}"
          end
          if a.confidence > 0.5 && a.confidence_basis.empty?
            errors << "action #{a.action_id} confidence=#{a.confidence} requires non-empty confidence_basis"
          end
        end
        if errors.empty?
          new_validation = ValidationResult.ok
          new_status = :validated
        else
          new_validation = ValidationResult.fail(errors)
          new_status = :failed
        end
        # Produce a new plan with the new status + validation.
        self.class.new(
          plan_id:            plan_id,
          actions:            actions,
          status:             new_status,
          validation_result:  new_validation
        )
      end
    end
  end
end