
#
# core/layer_record.rb — V1.0+V1.1+V1.3: per-layer aggregate in a snapshot.
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
# V1.3 additions (per directive 027):
#   - face_count (Integer, default 0) — total face occurrences on
#     this layer in the selection tree.
#   - faces_with_holes_count (Integer, default 0) — subset of
#     face_count whose FaceRecord.has_holes == true.
#
# Backward compat: V1.0/V1.1 callers may construct LayerRecord without
# the new kwargs; defaults fill in. The new fields are all
# deterministic (role=UNKNOWN, visible=true, visibility_unknown=
# false, face_count=0, faces_with_holes_count=0) so V1.0/V1.1 tests
# continue to pass unchanged.
#

require_relative 'layer_role'

module SUAnalysis
  module Core
    class LayerRecord
      attr_reader :name, :id, :edge_count, :face_count, :faces_with_holes_count,
                  :role, :role_rule, :visible, :visibility_unknown

      def initialize(name:, id: nil, edge_count: 0,
                     role: LayerRole::UNKNOWN, role_rule: nil,
                     visible: true, visibility_unknown: false,
                     face_count: 0, faces_with_holes_count: 0)
        @name              = name.to_s
        @id                = id
        @edge_count        = edge_count.to_i
        @face_count        = face_count.to_i
        @faces_with_holes_count = faces_with_holes_count.to_i
        @role              = role
        @role_rule         = role_rule
        @visible           = visible ? true : false
        @visibility_unknown = visibility_unknown ? true : false
      end

      def increment_edge_count!
        @edge_count += 1
      end

      def increment_face_count!(has_holes: false)
        @face_count += 1
        @faces_with_holes_count += 1 if has_holes
      end

      def to_h
        {
          name:               @name,
          id:                 @id,
          edge_count:         @edge_count,
          face_count:         @face_count,
          faces_with_holes_count: @faces_with_holes_count,
          role:               @role,
          role_rule:          @role_rule,
          visible:            @visible,
          visibility_unknown: @visibility_unknown
        }
      end

      # V1.4 (per directive 030): value-based equality. The
      # rebuild contract requires two LayerRecord instances with
      # the same data to be ==, so the SourceSnapshot can be
      # compared across rebuilds (rebuilds produce new instances).
      def ==(other)
        return false unless other.is_a?(LayerRecord)
        name == other.name &&
          id == other.id &&
          edge_count == other.edge_count &&
          face_count == other.face_count &&
          faces_with_holes_count == other.faces_with_holes_count &&
          role == other.role &&
          role_rule == other.role_rule &&
          visible == other.visible &&
          visibility_unknown == other.visibility_unknown
      end

      def eql?(other)
        self == other
      end

      def hash
        [name, id, edge_count, face_count, faces_with_holes_count,
         role, role_rule, visible, visibility_unknown].hash
      end
    end
  end
end
