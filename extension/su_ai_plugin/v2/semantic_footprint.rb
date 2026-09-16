#
# v2/semantic_footprint.rb — V2-0A Pure-Data SemanticFootprint.
#
# Per frozen V2-0A Stage Technical Blueprint
# (Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0A_SEMANTIC_FOOTPRINT_2026-09-16.md)
# §3.2 + §4 + §5:
#
#   The immutable V2 Stage-0A footprint value record. Pure
#   value object (no host mutation, no random, no SketchUp API
#   calls). All scalar fields are JSON-safe UTF-8 Strings /
#   finite Floats / Arrays. The record MUST be deeply
#   immutable and deterministic.
#
#   Identity is dataset-relative: `v2fp-` is NOT a durable
#   building / object identity across changed PreparedCadDatasets.
#   identity = SHA-256 over a versioned, unambiguous domain:
#       - footprint identity schema/version
#       - semantic_role
#       - exact source_layer_name
#       - canonical outer-loop source semantic node/edge
#         sequence (deterministic layer-local reconstruction)
#   truncated display ID = "v2fp-" + first 20 hex chars; the
#   full SHA-256 hex digest is retained internally and may be
#   published under a separate field if a downstream consumer
#   needs the full identity.
#
#   The record's construction plane is exactly z=0.0; the
#   projector copies the source outer-loop world coordinates
#   onto z=0.0 before publishing (Blueprint §4).
#
# Files:
#   extension/su_ai_plugin/v2/layer_local_graph_adapter.rb
#   extension/su_ai_plugin/v2/semantic_footprint.rb
#   extension/su_ai_plugin/v2/semantic_footprint_projector.rb
#   tests/test_v2_stage0a_semantic_footprint.rb
#

require 'digest'

module SUAnalysis
  module V2
    # SemanticFootprint contract: an immutable, dataset-relative,
    # pure-data record describing one accepted V2 footprint
    # projected from a validated PreparedCadDataset.
    #
    # Field shape (Blueprint §3.2):
    #
    #   schema_version           => 'v2.semantic-footprint.v1'
    #   footprint_id             => 'v2fp-' + first 20 hex chars
    #   footprint_id_full        => <full 64-hex SHA-256>
    #   semantic_role            => <String>
    #   source_layer_name        => <String>
    #   source_dataset_id        => <String>
    #   source_content_digest    => <String> (full 64-hex SHA-256)
    #   coordinate_epsilon       => <Float>
    #   source_node_ids          => <Array<String>> sorted/uniq
    #   source_edge_ids          => <Array<String>> sorted/uniq
    #   projected_world_coordinates => <Array<Array<Float>>>
    #                                   (each = [x, y, 0.0])
    #   area_xy                  => <Float>
    #   perimeter                => <Float>
    #
    # `semantic_role` is supplied by the projector (it names
    # the V2 Stage-0A semantic intent that owns the footprint;
    # Stage-0A itself does NOT classify roles -- it consumes a
    # caller-supplied role string from a future Layer Mapping
    # surface).
    #
    # The factory `build` performs the field-shape validation
    # required by Blueprint §3.2 (JSON-safe / deterministic /
    # deeply immutable). All published fields are deep-frozen.
    module SemanticFootprint
      module_function

      SCHEMA_VERSION      = 'v2.semantic-footprint.v1'.freeze
      FOOTPRINT_ID_PREFIX = 'v2fp-'.freeze

      # Identity schema used by the deterministic identity
      # digest. Bumped on any field-set change.
      IDENTITY_SCHEMA = 'v2.semantic-footprint-identity.v1'.freeze

      # Domain separator appended before truncation.
      # Keeps the `v2fp-` namespace separated from any future
      # V2 object / face / group identity namespaces.
      FULL_DIGEST_DOMAIN = 'v2fp-full-identity.v1'.freeze

      # Truncated display ID width. 20 lowercase hex chars =
      # 80 bits of entropy. Matches PCD dataset_id truncation
      # width (Blueprint §5).
      TRUNCATED_LEN = 20

      # Build a SemanticFootprint value record from already
      # computed projector-side facts.
      #
      # Required:
      #   semantic_role           : String
      #   source_layer_name       : String (UTF-8, non-empty)
      #   source_dataset_id       : String (UTF-8)
      #   source_content_digest   : String (UTF-8, 64 lowercase hex)
      #   coordinate_epsilon      : Numeric, finite, > 0
      #   source_node_ids         : Array<String>
      #   source_edge_ids         : Array<String>
      #   projected_world_coordinates : Array<Array<Numeric>>
      #                                  (each = [x, y, 0.0])
      #   area_xy                 : Numeric (>= 0)
      #   perimeter               : Numeric (>= 0)
      #
      # Returns a deeply-frozen Hash that satisfies the
      # Stage-0A contract. Raises ArgumentError on invalid
      # inputs; the projector must catch and convert to its
      # own BLOCKED status.
      def build(semantic_role:,
                source_layer_name:,
                source_dataset_id:,
                source_content_digest:,
                coordinate_epsilon:,
                source_node_ids:,
                source_edge_ids:,
                projected_world_coordinates:,
                area_xy:,
                perimeter:)
        role_str     = _strict_utf8_string('semantic_role', semantic_role)
        layer_str    = _strict_utf8_string('source_layer_name',
                                            source_layer_name)
        dsid_str     = _strict_utf8_string('source_dataset_id',
                                            source_dataset_id)
        digest_str   = _strict_utf8_string('source_content_digest',
                                            source_content_digest)
        eps          = _strict_finite_positive_float('coordinate_epsilon',
                                                     coordinate_epsilon)
        node_ids     = _sorted_uniq_strings('source_node_ids', source_node_ids)
        edge_ids     = _sorted_uniq_strings('source_edge_ids', source_edge_ids)
        coords       = _projected_world_coordinates(
                         'projected_world_coordinates',
                         projected_world_coordinates
                       )
        area_f       = _strict_non_negative_float('area_xy', area_xy)
        perim_f      = _strict_non_negative_float('perimeter', perimeter)
        # Validate the source content_digest format (must be a
        # full 64-hex SHA-256 of the source PreparedCadDataset).
        unless digest_str =~ /\A[0-9a-f]{64}\z/
          raise ArgumentError,
                "source_content_digest must be a full 64-hex SHA-256; got #{digest_str.inspect[0, 80]}"
        end
        # Deterministic identity digest. The domain is
        # unambiguous + versioned + dataset-relative, so two
        # distinct PreparedCadDatasets carrying identical
        # geometry / layer / role naturally produce distinct
        # identities (Blueprint §5).
        identity_full = _compute_identity_digest(
          semantic_role: role_str,
          source_layer_name: layer_str,
          source_content_digest: digest_str,
          source_node_ids: node_ids,
          source_edge_ids: edge_ids,
          projected_world_coordinates: coords
        )
        truncated = "#{FOOTPRINT_ID_PREFIX}#{identity_full[0, TRUNCATED_LEN]}"
        record = {
          'schema_version'               => SCHEMA_VERSION,
          'footprint_id'                 => truncated,
          'footprint_id_full'            => identity_full,
          'semantic_role'                => role_str,
          'source_layer_name'            => layer_str,
          'source_dataset_id'            => dsid_str,
          'source_content_digest'        => digest_str,
          'coordinate_epsilon'           => eps,
          'source_node_ids'              => node_ids,
          'source_edge_ids'              => edge_ids,
          'projected_world_coordinates'  => coords,
          'area_xy'                      => area_f,
          'perimeter'                    => perim_f
        }
        deep_freeze(record)
      end

      # Recompute the canonical identity digest over the
      # public field set, ignoring the existing
      # `footprint_id` / `footprint_id_full` fields. Used by
      # tests / downstream consumers that need to verify the
      # identity of a published footprint against its domain.
      def identity_digest_of(footprint)
        unless footprint.is_a?(Hash)
          raise ArgumentError,
                "identity_digest_of requires a Hash; got #{footprint.class}"
        end
        _compute_identity_digest(
          semantic_role: footprint['semantic_role'],
          source_layer_name: footprint['source_layer_name'],
          source_content_digest: footprint['source_content_digest'],
          source_node_ids: footprint['source_node_ids'],
          source_edge_ids: footprint['source_edge_ids'],
          projected_world_coordinates: footprint['projected_world_coordinates']
        )
      end

      # ---- internals ----

      def _compute_identity_digest(semantic_role:,
                                   source_layer_name:,
                                   source_content_digest:,
                                   source_node_ids:,
                                   source_edge_ids:,
                                   projected_world_coordinates:)
        # Stable SHA-256 over a canonical text encoding. Avoids
        # Marshal / JSON so the digest is platform-stable.
        lines = []
        lines << "schema|#{IDENTITY_SCHEMA}"
        lines << "role|#{semantic_role}"
        lines << "layer|#{source_layer_name}"
        lines << "dataset_digest|#{source_content_digest}"
        Array(source_node_ids).each do |nid|
          lines << "n|#{nid}"
        end
        Array(source_edge_ids).each do |eid|
          lines << "e|#{eid}"
        end
        Array(projected_world_coordinates).each do |c|
          if c.is_a?(Array) && c.length == 3
            lines << sprintf('c|%.10f|%.10f|%.10f', c[0].to_f, c[1].to_f, c[2].to_f)
          else
            lines << 'c|invalid'
          end
        end
        Digest::SHA256.hexdigest(FULL_DIGEST_DOMAIN + "\n" + lines.join("\n"))
      end

      def _strict_utf8_string(field, value)
        unless value.is_a?(String)
          raise ArgumentError, "#{field} must be a String; got #{value.class}"
        end
        unless value.encoding.name == 'UTF-8' && value.valid_encoding?
          raise ArgumentError,
                "#{field} must be valid UTF-8 (got encoding=#{value.encoding.name.inspect})"
        end
        if value.empty?
          raise ArgumentError, "#{field} must be a non-empty String"
        end
        value.dup.force_encoding('UTF-8').freeze
      end

      def _strict_finite_positive_float(field, value)
        unless value.is_a?(Numeric)
          raise ArgumentError, "#{field} must be Numeric; got #{value.class}"
        end
        f = value.to_f
        unless f.finite? && f > 0
          raise ArgumentError,
                "#{field} must be finite and strictly > 0; got #{value.inspect}"
        end
        f
      end

      def _strict_non_negative_float(field, value)
        unless value.is_a?(Numeric)
          raise ArgumentError, "#{field} must be Numeric; got #{value.class}"
        end
        f = value.to_f
        unless f.finite? && f >= 0
          raise ArgumentError,
                "#{field} must be finite and >= 0; got #{value.inspect}"
        end
        f
      end

      def _sorted_uniq_strings(field, arr)
        unless arr.is_a?(Array)
          raise ArgumentError, "#{field} must be an Array<String>; got #{arr.class}"
        end
        out = []
        arr.each do |x|
          unless x.is_a?(String)
            raise ArgumentError, "#{field} entries must be Strings; got #{x.inspect}"
          end
          unless x.encoding.name == 'UTF-8' && x.valid_encoding?
            raise ArgumentError,
                  "#{field} entry has non-UTF-8 / invalid encoding: #{x.inspect[0, 80]}"
          end
          out << x
        end
        out.uniq.sort
      end

      def _projected_world_coordinates(field, arr)
        unless arr.is_a?(Array)
          raise ArgumentError, "#{field} must be an Array<Array<Numeric>>; got #{arr.class}"
        end
        out = []
        arr.each_with_index do |c, i|
          unless c.is_a?(Array) && c.length == 3
            raise ArgumentError,
                  "#{field}[#{i}] must be a 3-element Array<Numeric>; got #{c.inspect}"
          end
          xs = []
          c.each_with_index do |v, j|
            unless v.is_a?(Numeric) && v.respond_to?(:finite?) && v.finite?
              raise ArgumentError,
                    "#{field}[#{i}][#{j}] must be a finite Numeric; got #{v.inspect}"
            end
            xs << v.to_f
          end
          out << xs
        end
        out
      end

      # Mirror the V1.8 deep-freeze contract.
      def deep_freeze(obj)
        case obj
        when Hash
          obj.each_key { |k| deep_freeze(k) }
          obj.each_value { |v| deep_freeze(v) }
          obj.freeze
        when Array
          obj.each { |v| deep_freeze(v) }
          obj.freeze
        when String
          obj.freeze
        else
          obj
        end
      end
    end
  end
end