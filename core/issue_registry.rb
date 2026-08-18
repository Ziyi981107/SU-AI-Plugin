#
# core/issue_registry.rb — pure-Ruby container of normalized UIIssue Hashes.
#
# Per CodeX Review 011..014 (2026-08-18), Stage 6 contract:
#   - Holds Array<Hash> of UIIssue Hashes (Symbol keys, JSON-safe values).
#   - Validation: a private `validate_issue` raises
#     `IssueRegistry::InvalidIssue` on a missing key, a non-canonical
#     severity String, an un-`to_s`-able field, or a non-Array sources.
#   - Public constructor `new` CATCHES any `InvalidIssue`, drops the
#     offending Issue, records a diagnostic, and continues. The
#     constructor itself never raises on a single malformed Issue.
#   - Summary: Hash{ issue_type => count }
#   - Groups: Array<{type, count, default_open, issues}> sorted per
#     §6.6 of the Stage 6 plan
#   - Tunable group ordering (passed to #groups)
#
# The IssueRegistry is a frozen Hash-keyed read-only store; mutators
# are explicitly absent. To extend, replace the registry instance.
#

module SUAnalysis
  module Core
    class IssueRegistry
      class InvalidIssue < StandardError; end

      # Canonical severity values (R005, per CodeX Review 004..007).
      CANONICAL_SEVERITIES = ['low', 'medium', 'high'].freeze
      # Canonical issue types (Stage 6 contract).
      CANONICAL_ISSUE_TYPES = [
        'duplicate_edge_candidate',
        'short_edge',
        'open_endpoint',
        'gap_candidate',
        'significant_non_zero_z',
        'abnormal_large_coord',
        'deep_nesting'
      ].freeze
      # Per CodeX Q1 default-open policy (per IssueGrouper).
      DEFAULT_GROUP_ORDER = [
        'duplicate_edge_candidate',
        'short_edge',
        'open_endpoint',
        'gap_candidate',
        'significant_non_zero_z',
        'abnormal_large_coord',
        'deep_nesting'
      ].freeze
      # Required keys (Symbol) on every UIIssue Hash.
      REQUIRED_KEYS = [
        :issue_id, :issue_type, :severity, :confidence,
        :sources, :source_entity_ids, :edge_ids,
        :location, :message, :metadata,
        :locatable, :display_length
      ].freeze

      attr_reader :issues, :diagnostics, :summary, :groups

      # Build an IssueRegistry from `issues` (raw UIIssue Hashes).
      # `diagnostics` is an optional Array<Hash> that gets diagnostics
      # appended when an issue is dropped.
      def initialize(issues, diagnostics: nil)
        @diagnostics = (diagnostics || []).dup
        @issues = []
        Array(issues).each do |iss|
          begin
            self.class.validate_issue!(iss)
            @issues << iss.freeze
          rescue InvalidIssue => e
            @diagnostics << {
              stage: 'issue_registry.validate',
              error: e.class.name,
              message: e.message,
              dropped_issue: iss
            }
          end
        end
        @issues.freeze
        @diagnostics.freeze
        @summary = build_summary
      end

      # Open iff at least one Issue has severity == 'high'.
      def open?
        @issues.any? { |iss| iss[:severity] == 'high' }
      end

      # Total Issue count.
      def size
        @issues.length
      end

      # Find an Issue by issue_id. Returns the Hash or nil.
      def find(issue_id)
        return nil if issue_id.nil? || !issue_id.is_a?(String)
        @issues.find { |iss| iss[:issue_id] == issue_id }
      end

      # All Issues grouped by issue_type, ordered per group_order.
      # Each group is a Hash:
      #   :type          String
      #   :count         Integer
      #   :default_open  Boolean
      #   :issues        Array<Hash>
      #
      # Default-open policy (CodeX Q1):
      #   - If any Issue has severity == 'high': open groups with :high.
      #   - Else: open the first non-empty group only.
      #
      # Per CodeX NIT Round 015: unknown issue_types are appended AFTER
      # the canonical list, in lex order of the type itself, so they
      # are deterministically visible.
      def groups(group_order: DEFAULT_GROUP_ORDER)
        by_type = Hash.new { |h, k| h[k] = [] }
        @issues.each { |iss| by_type[iss[:issue_type]] << iss }
        canonical_types_in_order = (group_order + CANONICAL_ISSUE_TYPES).uniq
        unknown_types = by_type.keys.reject { |t| canonical_types_in_order.include?(t) }.sort
        ordered_types = canonical_types_in_order + unknown_types
        any_high = @issues.any? { |iss| iss[:severity] == 'high' }
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

      # Public class method: validate one Issue Hash. Raises
      # InvalidIssue on the first failure found.
      def self.validate_issue!(iss)
        unless iss.is_a?(Hash)
          raise InvalidIssue, "issue must be a Hash, got #{iss.class}"
        end
        REQUIRED_KEYS.each do |k|
          unless iss.key?(k)
            raise InvalidIssue, "missing key :#{k}"
          end
        end
        unless CANONICAL_SEVERITIES.include?(iss[:severity])
          raise InvalidIssue, "non-canonical severity: #{iss[:severity].inspect}"
        end
        unless CANONICAL_SEVERITIES.include?(iss[:confidence])
          raise InvalidIssue, "non-canonical confidence: #{iss[:confidence].inspect}"
        end
        unless iss[:issue_type].is_a?(String) && !iss[:issue_type].empty?
          raise InvalidIssue, "issue_type must be a non-empty String"
        end
        unless iss[:issue_id].is_a?(String) && !iss[:issue_id].empty?
          raise InvalidIssue, "issue_id must be a non-empty String"
        end
        unless iss[:sources].is_a?(Array)
          raise InvalidIssue, "sources must be an Array"
        end
        unless iss[:source_entity_ids].is_a?(Array)
          raise InvalidIssue, "source_entity_ids must be an Array"
        end
        unless iss[:edge_ids].is_a?(Array)
          raise InvalidIssue, "edge_ids must be an Array"
        end
        unless iss[:message].is_a?(String)
          raise InvalidIssue, "message must be a String"
        end
        unless iss[:location].nil? || (iss[:location].is_a?(Array) && iss[:location].size == 3)
          raise InvalidIssue, "location must be nil or [x, y, z]"
        end
        unless iss[:locatable] == true || iss[:locatable] == false
          raise InvalidIssue, "locatable must be a Boolean"
        end
        true
      end

      private

      def build_summary
        s = Hash.new(0)
        @issues.each { |iss| s[iss[:issue_type]] += 1 }
        s.freeze
      end
    end
  end
end
