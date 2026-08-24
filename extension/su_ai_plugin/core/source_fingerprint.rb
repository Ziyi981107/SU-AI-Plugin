#
# core/source_fingerprint.rb — V1.4 deterministic source fingerprint.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL PREVIEW),
# answer to question 3 + risk test 1 + risk test 8:
#
#   "Define a deterministic fingerprint comparison suitable for
#    proving zero source mutation. It must cover material
#    source state, not only edge count."
#
# This class is a small, pure-Ruby, dependency-free component
# that captures the SU material source state into a stable
# Hash fingerprint. Two SourceFingerprints are == iff the
# underlying snapshot facts match.
#
# A second build from identical source + captured config must
# produce the same canonical fingerprint (risk test 8).
# A successful create / discard / rebuild / injected-failure /
# host-abort path must leave the source fingerprint identical
# to PRE (risk test 1).
#
# What the fingerprint covers (per directive "not only edge
# count"):
#   - total edge count + per-edge length sum + bounding box
#   - total face count + face vertex count sum
#   - group / component instance / definition counts
#   - layer count + per-layer visibility + per-layer edge count
#   - material set (hashed)
#   - selection scope (edge / face / group / instance IDs)
#
# What the fingerprint does NOT cover (out of scope for V1.4):
#   - per-entity attributes that the V1.0-V1.3 code did not
#     read. The fingerprint is the minimal sufficient
#     summary for proving zero source mutation, NOT a
#     complete round-trip serialization.
#   - live SketchUp entity object identity (entityID). We
#     never use entityID as canonical identity; per
#     SourceReference's fail-closed contract.
#

require 'digest'
require 'json'

module SUAnalysis
  module Core
    class SourceFingerprint
      # Locked field set.
      attr_reader :edge_count, :edge_length_sum, :bounding_box,
                  :face_count, :face_vertex_count_sum,
                  :group_count, :component_instance_count,
                  :component_definition_count,
                  :layer_count, :layer_facts,
                  :material_digest,
                  :selection_scope_digest

      def initialize(edge_count: 0, edge_length_sum: 0.0, bounding_box: nil,
                     face_count: 0, face_vertex_count_sum: 0,
                     group_count: 0, component_instance_count: 0,
                     component_definition_count: 0,
                     layer_count: 0, layer_facts: {},
                     material_digest: '',
                     selection_scope_digest: '')
        # Defensive copy + deep-freeze so the captured facts
        # cannot drift after construction.
        @edge_count                 = edge_count.to_i
        @edge_length_sum            = edge_length_sum.to_f
        @bounding_box               = bounding_box ? bounding_box.dup.freeze : nil
        @face_count                 = face_count.to_i
        @face_vertex_count_sum     = face_vertex_count_sum.to_i
        @group_count                = group_count.to_i
        @component_instance_count  = component_instance_count.to_i
        @component_definition_count = component_definition_count.to_i
        @layer_count                = layer_count.to_i
        @layer_facts                = (layer_facts || {}).each_with_object({}) do |(k, v), h|
                                          h[k.to_s] = v.dup.freeze
                                        end.freeze
        @material_digest            = material_digest.to_s
        @selection_scope_digest     = selection_scope_digest.to_s
        freeze
      end

      def ==(other)
        return false unless other.is_a?(SourceFingerprint)
        edge_count == other.edge_count &&
          edge_length_sum == other.edge_length_sum &&
          bounding_box == other.bounding_box &&
          face_count == other.face_count &&
          face_vertex_count_sum == other.face_vertex_count_sum &&
          group_count == other.group_count &&
          component_instance_count == other.component_instance_count &&
          component_definition_count == other.component_definition_count &&
          layer_count == other.layer_count &&
          layer_facts == other.layer_facts &&
          material_digest == other.material_digest &&
          selection_scope_digest == other.selection_scope_digest
      end

      def eql?(other)
        self == other
      end

      def hash
        [
          edge_count, edge_length_sum, bounding_box,
          face_count, face_vertex_count_sum,
          group_count, component_instance_count,
          component_definition_count,
          layer_count, layer_facts,
          material_digest, selection_scope_digest
        ].hash
      end

      def to_h
        {
          edge_count:                  edge_count,
          edge_length_sum:             edge_length_sum,
          bounding_box:                bounding_box,
          face_count:                  face_count,
          face_vertex_count_sum:      face_vertex_count_sum,
          group_count:                 group_count,
          component_instance_count:   component_instance_count,
          component_definition_count:  component_definition_count,
          layer_count:                 layer_count,
          layer_facts:                 layer_facts,
          material_digest:             material_digest,
          selection_scope_digest:      selection_scope_digest
        }
      end

      # Deterministic hex digest of the canonical JSON
      # representation. Same input -> same digest (risk test 8).
      def digest
        canonical = canonical_json
        Digest::SHA256.hexdigest(canonical)
      end

      # Build a SourceFingerprint from a live snapshot + selection.
      # Pure-Ruby; no host calls. The snapshot is the V1.0+
      # GeometrySnapshot (additive fields; older callers can
      # still build a SourceFingerprint from a minimal snapshot
      # via the keyword defaults).
      def self.from_snapshot(snapshot, selection: nil, host: nil)
        edges = snapshot.respond_to?(:edges) ? (snapshot.edges || []) : []
        faces = snapshot.respond_to?(:faces) ? (snapshot.faces || []) : []
        layers = snapshot.respond_to?(:layers) ? (snapshot.layers || []) : []

        # bbox: [min_x, min_y, min_z, max_x, max_y, max_z] or nil
        bbox = snapshot.respond_to?(:bounding_box) ? snapshot.bounding_box : nil
        bbox_flat = bbox ? [bbox[:min][0], bbox[:min][1], bbox[:min][2],
                              bbox[:max][0], bbox[:max][1], bbox[:max][2]] : nil

        # layer_facts: name -> { visible:, edge_count:, face_count: }
        layer_facts = layers.each_with_object({}) do |rec, h|
          h[rec.name.to_s] = {
            visible:     rec.respond_to?(:visible) ? rec.visible : true,
            edge_count:  rec.respond_to?(:edge_count) ? rec.edge_count : 0,
            face_count:  rec.respond_to?(:face_count) ? rec.face_count : 0
          }.freeze
        end

        # material_digest: SHA256 of sorted material names. We
        # cannot enumerate host materials here (pure-Ruby), so
        # we accept a precomputed list. For test hosts that don't
        # supply a list, we use the empty string so callers can
        # distinguish 'no materials' from a populated set without
        # comparing against an arbitrary SHA256 of nothing.
        material_source = host && host.respond_to?(:materials) ? host.materials : []
        # SketchUp::Materials (SU2020) is enumerable but does not
        # implement Array's #empty? / #map surface. Normalize the
        # host collection before using ordinary Array operations;
        # this keeps the core free of host-specific constants.
        material_list = if material_source.respond_to?(:to_a)
                          material_source.to_a
                        elsif material_source.respond_to?(:each)
                          list = []
                          material_source.each { |m| list << m }
                          list
                        else
                          Array(material_source)
                        end
        material_list = Array(material_list)
        local_material_digest = if material_list.empty?
                                   ''
                                 else
                                   Digest::SHA256.hexdigest(
                                     material_list.map { |m| m.to_s }.sort.join("\n")
                                   )
                                 end

        # selection_scope_digest: SHA256 of the canonical
        # (entity_type, persistent_id_path, instance_path, layer)
        # tuple set. Falls back to '' for an empty selection.
        sel_entries = selection ? Array(selection) : []
        local_selection_digest = if sel_entries.empty?
                                  # An empty selection is a distinct,
                                  # recognizable state (the "user
                                  # selected nothing" case). We use the
                                  # empty string so callers can
                                  # distinguish it from a populated
                                  # selection without comparing against
                                  # an arbitrary SHA256 of nothing.
                                  ''
                                else
                                  canonical_sel = sel_entries.map do |entry|
                                    if entry.is_a?(Hash)
                                      "#{entry[:kind]}|#{entry[:persistent_id_path].to_a.join('/')}|" \
                                        "#{entry[:instance_path].to_a.join('>')}|#{entry[:layer]}"
                                    else
                                      entry.to_s
                                    end
                                  end.sort.join("\n")
                                  Digest::SHA256.hexdigest(canonical_sel)
                                end

        # Component counts: optional host counts (passed via
        # the host: kwarg) so we don't depend on the live
        # SketchUp model just to compute the fingerprint.
        component_instance_count  = (host && host.respond_to?(:component_instance_count)) ? host.component_instance_count : 0
        component_definition_count = (host && host.respond_to?(:component_definition_count)) ? host.component_definition_count : 0
        group_count                = (host && host.respond_to?(:group_count)) ? host.group_count : 0

        new(
          edge_count:                  edges.length,
          edge_length_sum:             edges.map { |e| e.respond_to?(:length) ? e.length : 0.0 }.sum,
          bounding_box:                bbox_flat,
          face_count:                  faces.length,
          face_vertex_count_sum:      faces.map { |f| f.respond_to?(:outer_loop_vertex_count) ? f.outer_loop_vertex_count : 0 }.sum,
          group_count:                 group_count,
          component_instance_count:   component_instance_count,
          component_definition_count:  component_definition_count,
          layer_count:                 layers.length,
          layer_facts:                 layer_facts,
          material_digest:             local_material_digest,
          selection_scope_digest:      local_selection_digest
        )
      end

      private

      def canonical_json
        # Stable key order so the JSON string is identical for
        # identical inputs. JSON.generate does NOT sort keys by
        # default; we sort here to make the digest deterministic.
        sorted = to_h.sort_by { |k, _| k.to_s }
        JSON.generate(sorted, sort_keys: false)
      end
    end
  end
end
