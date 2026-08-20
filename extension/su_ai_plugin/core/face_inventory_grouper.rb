#
# core/face_inventory_grouper.rb — V1.3 Face Inventory aggregator.
#
# Per V1.3 directive 027 (Prompt/CODEX_GUIDANCE_027_...):
#   - Aggregate face inventory by source layer in pure Ruby.
#     Do NOT implement topology grouping independently in JS.
#   - Reuse the existing LayerRecord visibility / role semantics
#     produced by the V1.1 LayerSemanticMapper path. The grouper
#     reads each layer's role / role_label / visible /
#     visibility_unknown / visibility_label from the locked
#     LayerRecord shape; it does NOT re-classify.
#   - Buckets are ordered by the same canonical role order as
#     the V1.1 Layers section (Dimension -> Annotation -> Guide
#     -> Construction -> Unknown; visible before hidden within a
#     role; then deterministic name order).
#   - Only layers with at least one face OCCURRENCE are emitted
#     (no empty buckets). Per directive item 4: "aggregate rows
#     by source face layer, not one UI row per individual face".
#   - No phantom layers: layers not present in the supplied
#     LayerRecord list are not created.
#

module SUAnalysis
  module Core
    module FaceInventoryGrouper
      module_function

      # Build per-layer buckets.
      #   layer_records: Array<LayerRecord> (from the snapshot)
      # Returns: Array<Hash> with the locked field set per bucket.
      def group(layer_records)
        buckets = []
        layer_records.each do |rec|
          next unless rec.respond_to?(:face_count) && rec.face_count.to_i > 0
          buckets << {
            name:               rec.name,
            face_count:         rec.face_count.to_i,
            faces_with_holes_count: rec.respond_to?(:faces_with_holes_count) ? rec.faces_with_holes_count.to_i : 0,
            role:               rec.respond_to?(:role) ? rec.role : :unknown,
            role_label:         rec.respond_to?(:role) ? humanize_role(rec.role) : 'Unknown',
            role_rule:          rec.respond_to?(:role_rule) ? rec.role_rule : nil,
            visible:            rec.respond_to?(:visible) ? rec.visible : true,
            visibility_unknown: rec.respond_to?(:visibility_unknown) ? rec.visibility_unknown : false,
            visibility_label:   build_visibility_label(rec)
          }
        end
        sort_like_layers(buckets)
      end

      # Sort buckets by the V1.1 canonical layer order so the
      # Face Inventory row order matches the existing Layers row
      # order (Dimension -> Annotation -> Guide -> Construction ->
      # Unknown; visible before hidden within a role; then name ASC).
      def sort_like_layers(buckets)
        role_rank = {
          dimension:    0,
          annotation:   1,
          guide:        2,
          construction: 3,
          unknown:      4
        }
        buckets.sort_by do |b|
          [
            role_rank.fetch(b[:role], role_rank.size),
            b[:visible] ? 0 : 1,
            b[:name].to_s
          ]
        end
      end

      # Human-readable role label. Mirrors LayerRole::HUMAN's
      # canonical map when available; falls back to capitalized
      # symbol form. Kept in the grouper so FaceInventoryGrouper
      # does not depend on LayerRole being loaded.
      def humanize_role(role)
        return 'Unknown' if role.nil?
        case role
        when :dimension    then 'Dimension'
        when :annotation   then 'Annotation'
        when :guide        then 'Guide'
        when :construction then 'Construction'
        when :unknown      then 'Unknown'
        else role.to_s.split('_').map(&:capitalize).join(' ')
        end
      end

      # Visibility label per V1.1 R007 / R011 contract.
      def build_visibility_label(rec)
        if rec.respond_to?(:visibility_unknown) && rec.visibility_unknown
          'Visibility: unknown'
        elsif rec.respond_to?(:visible) && !rec.visible
          'Off-screen'
        else
          'Visible'
        end
      end
    end
  end
end