
#
# core/layer_role.rb — V1.1 Layer Semantic Mapping role enum + helpers.
#
# Per V1.1 plan §4.1:
#   - 5 name-based roles ONLY (no OFFSCREEN).
#   - Visibility is a SEPARATE field (per R007), not a role.
#   - Role and visibility are independent; a hidden "DIM-XX" layer
#     shows role="Dimension" + visibility="Off-screen", NOT a
#     fused "Construction (off-screen)" role.
#
# The HUMAN table is the JS-locked label set (mirrors
# ROOT.ISSUE_TYPE_LABELS / ROOT.LAYER_ROLE_LABELS in app.js).
# Changing the human label is a UI-visible change; the plan
# pins every label.
#

module SUAnalysis
  module Core
    module LayerRole
      CONSTRUCTION = :construction       # Layer0 / Default / Untagged
      DIMENSION    = :dimension          # *dim* / *dimension*
      ANNOTATION   = :annotation         # *anno* / *text* / *label*
      GUIDE        = :guide              # *guide* / *constr* / *xline*
      UNKNOWN      = :unknown            # no rule matched (KEEP, per ChatGPT §11.6)

      # Display order for the dialog table. Most informative role first;
      # default layer in the middle; unknown FIXED last (R012).
      ALL = [DIMENSION, ANNOTATION, GUIDE, CONSTRUCTION, UNKNOWN].freeze

      # Human label per role. JS renders verbatim.
      HUMAN = {
        DIMENSION    => 'Dimension'.freeze,
        ANNOTATION   => 'Annotation'.freeze,
        GUIDE        => 'Guide'.freeze,
        CONSTRUCTION => 'Construction'.freeze,
        UNKNOWN      => 'Unknown'.freeze
      }.freeze

      # Visibility label table (R007). Two-state boolean.
      VISIBILITY_HUMAN = {
        true  => 'Visible'.freeze,
        false => 'Off-screen'.freeze
      }.freeze

      # When host capability is missing (R011), the data model
      # preserves the uncertainty via `visibility_unknown: true`.
      # The dialog renders this as its own badge.
      VISIBILITY_UNKNOWN_HUMAN = 'Visibility: unknown'.freeze

      # Compose the final visibility label from (visible,
      # visibility_unknown). This is the SOURCE OF TRUTH for the
      # dialog badge text; the JS layer does NOT recompute it.
      # uncertainty wins over operational value (R011).
      def self.visibility_label(visible, unknown)
        return VISIBILITY_UNKNOWN_HUMAN if unknown
        VISIBILITY_HUMAN[visible ? true : false]
      end
    end
  end
end
