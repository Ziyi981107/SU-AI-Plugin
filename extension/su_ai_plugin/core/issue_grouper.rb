#
# core/issue_grouper.rb — pure-Ruby pass-through wrapper for IssueRegistry
# grouping with a separate entry point so tests can exercise group
# ordering without instantiating an IssueRegistry.
#
# Per CodeX Review 011..014 (2026-08-18), Stage 6 R005 + CodeX Q1:
#   - Top-to-bottom order on the page (issue_type canonical order).
#   - Within each group, sort by issue_id ASC (lexicographic).
#   - Default-open: true iff the group contains a :high issue.
#   - If NO :high anywhere and the IssueRegistry has no :high issue,
#     open the first non-empty group (CodeX Q1 answer).
#
# Lives in core/ so the policy is testable without any registry state.
#

module SUAnalysis
  module Core
    module IssueGrouper
      module_function

      # Pure helper: a flat Array of UIIssue Hashes -> Array<group Hash>.
      # group_order: optional override Array<String>; default is
      #   IssueRegistry::DEFAULT_GROUP_ORDER.
      #
      # Default-open policy (CodeX Q1):
      #   - If any Issue has severity == 'high': open groups with :high.
      #   - Else: open the first non-empty group only.
      def group(issues, group_order: nil)
        order = group_order || IssueRegistry::DEFAULT_GROUP_ORDER
        by_type = Hash.new { |h, k| h[k] = [] }
        issues.each { |iss| by_type[iss[:issue_type]] << iss }
        ordered_types = (order + IssueRegistry::CANONICAL_ISSUE_TYPES).uniq
        any_high = issues.any? { |iss| iss[:severity] == 'high' }
        result = []
        first_emitted = false
        ordered_types.each do |type|
          bucket = by_type[type]
          next if bucket.empty?
          default_open = if any_high
                          bucket.any? { |iss| iss[:severity] == 'high' }
                        else
                          !first_emitted
                        end
          first_emitted = true if default_open
          result << {
            type:         type,
            count:        bucket.length,
            default_open: default_open,
            issues:       bucket.sort_by { |iss| iss[:issue_id].to_s }
          }
        end
        result
      end

      # Convenience: derive `any_high` from a registry.
      def open?(registry)
        return false if registry.nil?
        registry.respond_to?(:open?) ? registry.open? : false
      end
    end
  end
end
