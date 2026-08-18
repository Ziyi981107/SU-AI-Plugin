#
# core/structural_facts.rb — pure-Ruby helpers for calculating structural
# identity of an entity path in the SketchUp model.
#
# Per CodeX Review 013 (2026-08-18), Stage 6 BLOCK-001 v5 fix:
#   - structural_depth must come from the actual entity count
#     (model.active_path count + walking container ancestry),
#     NOT from the filtered PID array length.
#   - pid_path_complete must be calculated BEFORE nil PIDs are discarded.
#   - These two facts are independent: a source can have a non-empty
#     path AND still be incomplete (e.g. nested source with leaf_pid
#     captured but container_pid missing).
#
# This module is pure Ruby (no SketchUp, no compatibility/) and lives
# in core/ so the structural invariants can be unit-tested without
# any SU runtime.
#
# Usage:
#   facts = SUAnalysis::Core::StructuralFacts.compute(
#     ancestry_pids_with_nil: [12, nil, 555],   # include nil for missing
#     leaf_pid:               555,
#     active_path_count:      0
#   )
#   facts.structural_depth   # => 2 (one container + leaf, plus active)
#   facts.pid_path_complete   # => false (one nil in chain)
#

module SUAnalysis
  module Core
    module StructuralFacts
      module_function

      # Compute the three structural facts for a single source path.
      # Returns a Hash with three keys:
      #   :structural_depth    — total structural depth (active + containers + leaf)
      #   :pid_path_complete    — true iff every PID slot is non-nil AND leaf is non-nil
      #   :pid_path             — Array<Integer> with only non-nil integers
      #
      # Inputs:
      #   ancestry_pids_with_nil: Array<Integer|nil> — container PID slots
      #     (NOT pre-filtered). Empty array means no containers.
      #   leaf_pid: Integer|nil — the leaf entity's own PID.
      #   active_path_count: Integer — number of entities in the
      #     current active edit path. 0 when not editing.
      #
      # Formula (Stage 6 contract):
      #   structural_depth = active_path_count + ancestry_count + 1
      #     The +1 accounts for the leaf itself.
      #   pid_path_complete = every ancestry slot non-nil AND leaf_pid non-nil
      #   pid_path = ancestry.compact + [leaf_pid] if leaf_pid non-nil
      def compute(ancestry_pids_with_nil:, leaf_pid:, active_path_count: 0)
        ancestry_complete = ancestry_pids_with_nil.all? { |p| !p.nil? }
        leaf_complete     = !leaf_pid.nil?
        structural_depth = active_path_count.to_i + ancestry_pids_with_nil.length + 1
        pid_path = ancestry_pids_with_nil.compact
        pid_path = pid_path + [leaf_pid] if !leaf_pid.nil?
        {
          structural_depth: structural_depth,
          pid_path_complete: !!(ancestry_complete && leaf_complete),
          pid_path: pid_path.freeze
        }
      end

      # Convenience: derive facts from a CANONICAL pid_path that
      # INCLUDES the leaf at the end. Treats the last element as the
      # leaf; ancestry is pid_path[0..-2].
      def from_canonical_path(pid_path:, active_path_count: 0)
        pp = pid_path || []
        ancestry = pp[0..-2] || []
        leaf_pid = pp.last
        ancestry_complete = ancestry.is_a?(Array) && ancestry.all? { |p| !p.nil? }
        leaf_complete = !leaf_pid.nil?
        structural_depth = active_path_count.to_i + ancestry.length + 1
        {
          structural_depth: structural_depth,
          pid_path_complete: !!(ancestry_complete && leaf_complete),
          pid_path: pp.dup.freeze
        }
      end
    end
  end
end
