
#
# core/layer_role_config.rb — V1.1 Layer Semantic Mapping rules.
#
# Per V1.1 plan §4.2:
#   - classify(name) returns (role, rule_id).
#   - Rules are NAME-ONLY (visibility is captured separately by
#     SUCapability.layer_visibility, see R007).
#   - Rules are evaluated in DECLARED order; first match wins
#     (R010 top-down-by-priority, NOT by-specificity).
#   - Specificity MAY be a future tie-break / lint hint, but is
#     NOT the main sort rule.
#
# Rationale (R010): explicit priority is more predictable, more
# debuggable, and avoids hidden "more specific = more important"
# behavior. A future engineer who adds a more-specific rule must
# think about whether it should win over an earlier one — the
# RULES order IS the policy.
#
# Patterns are case-insensitive (anchored at both ends, but allow
# interior dots and underscores in real-world layer names).
#

module SUAnalysis
  module Core
    module LayerRoleConfig
      module_function

      # Canonical rule list. Order IS the priority (R010).
      # Each rule: a Regexp, the role Symbol it maps to, and a
      # stable rule_id for testability / debug.
      RULES = [
        {
          match:   /dim(ension)?/i,
          role:    LayerRole::DIMENSION,
          rule_id: 'name_dimension'
        }.freeze,
        {
          match:   /(anno|t?ext|label)/i,
          role:    LayerRole::ANNOTATION,
          rule_id: 'name_annotation'
        }.freeze,
        {
          match:   /(guide|constr(uction)?|xline)/i,
          role:    LayerRole::GUIDE,
          rule_id: 'name_guide'
        }.freeze,
        {
          # Exact match (case-insensitive) for SketchUp defaults.
          # Per the plan, "Layer0" / "Default" / "Untagged" are
          # the three canonical default layer names. Anything
          # else that wants :construction must match a future
          # rule; this rule does NOT promote arbitrary names.
          match:   /\A(layer0|default|untagged)\z/i,
          role:    LayerRole::CONSTRUCTION,
          rule_id: 'name_default_layer'
        }.freeze
      ].freeze

      DEFAULT_ROLE     = LayerRole::UNKNOWN
      DEFAULT_RULE_ID  = 'name_no_match'.freeze

      # Classify a layer NAME into (role, rule_id).
      # `name` MUST be a String (defensive: nil raises ArgumentError,
      # empty string falls through to DEFAULT_ROLE / DEFAULT_RULE_ID).
      def classify(name)
        raise ArgumentError, 'name must be a String (got nil)' if name.nil?
        s = name.to_s
        RULES.each do |rule|
          if s.match(rule[:match])
            return [rule[:role], rule[:rule_id]]
          end
        end
        [DEFAULT_ROLE, DEFAULT_RULE_ID]
      end
    end
  end
end
