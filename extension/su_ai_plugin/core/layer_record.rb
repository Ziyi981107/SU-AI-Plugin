
#
# core/layer_record.rb — V1.0+V1.1: per-layer aggregate in a snapshot.
#
# V1.0 (pre-V1.1): name + id + edge_count.
#
# V1.1 additions (per plan §4.3):
#   - role (LayerRole Symbol) — name-based, 5 options.
#   - role_rule (String) — the rule_id that classified it; nil for UNKNOWN.
#   - visible (Boolean) — operational layer visibility, separate from
#     role (R007).
#   - visibility_unknown (Boolean) — true iff host capability was
#     missing (R011). Operational fallback is `visible: true`, but
#     the uncertainty is preserved in the data model.
#
# Backward compat: V1.0 callers may construct LayerRecord without
# the new kwargs; defaults fill in. The new fields are all
# deterministic (role=UNKNOWN, visible=true, visibility_unknown=
# false) so V1.0 tests continue to pass unchanged.
#

require_relative 'layer_role'

module SUAnalysis
  module Core
    class LayerRecord
      attr_reader :name, :id, :edge_count,
                  :role, :role_rule, :visible, :visibility_unknown

      def initialize(name:, id: nil, edge_count: 0,
                     role: LayerRole::UNKNOWN, role_rule: nil,
                     visible: true, visibility_unknown: false)
        @name              = name.to_s
        @id                = id
        @edge_count        = edge_count.to_i
        @role              = role
        @role_rule         = role_rule
        @visible           = visible ? true : false
        @visibility_unknown = visibility_unknown ? true : false
      end

      def increment_edge_count!
        @edge_count += 1
      end

      def to_h
        {
          name:               @name,
          id:                 @id,
          edge_count:         @edge_count,
          role:               @role,
          role_rule:          @role_rule,
          visible:            @visible,
          visibility_unknown: @visibility_unknown
        }
      end
    end
  end
end
