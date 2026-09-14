#
# core/prepared_cad_dataset.rb — V1.9B1 B1.2 PreparedCadDataset.
#
# Per frozen V1.9B1 Blueprint v1.3 (authoritative over v1.2)
# AND AIPM V1.9B1 B1.2-B1.4 Source Review Correction 2026-09-14:
#
#   PreparedCadDataset is the durable deterministic V1 -> V2
#   handoff contract. The B1.2 module provides:
#
#     - The immutable candidate/final value object (top-level
#       shape: schema_version, dataset_id, content_digest,
#       content, build_evidence_digest, build_evidence,
#       validation).
#     - The B1 canonical identity BYTE encoder (type-disjoint
#       grammar: nil/Boolean/Integer/Float/String/Array/Hash).
#     - The deterministic persisted JSON serializer (separate
#       from identity bytes; used by B2 for the exact
#       <= 8 MiB payload gate).
#
#   Source Review Correction contracts (B1-SR-01, B1-SR-12):
#
#     - content_digest (public/persisted) = FULL 64-hex SHA-256.
#     - build_evidence_digest (public/persisted) = FULL 64-hex
#       SHA-256.
#     - dataset_id = "pcd-" + content_digest[0, 20].
#     - candidate/final preserve those exact public fields.
#     - validation binds the SAME FULL public digests.
#
#   UTF-8 contract (B1-SR-12): identity / public semantic
#   Strings MUST be valid UTF-8. The encoder rejects valid
#   non-UTF-8 String encodings as well as invalid UTF-8.
#
#   Truncated-ID collision hardening: full digests are retained
#   internally; same truncated prefix mapped to a different
#   full digest => BLOCKED (handled in the Builder / Validator
#   truncation-context map).
#
#   No host objects. No Symbol keys/values in the final
#   published dataset. All input collections are deep-frozen
#   and the final dataset is deeply immutable.
#
# B1.2 owns these sub-responsibilities; B1.3 builds the
# candidate, B1.4 attaches validation.
#
# Ruby 2.2-compatible primitives (see Blueprint v1.3 §17):
#   - identity Float packing via [v].pack('G').unpack('H*').first
#   - no Hash#compact, Array#sum, transform_keys, filter_map,
#     Numeric#positive?, safe navigation, pattern matching, then
#     / yield_self
#

require 'digest'
require 'json'

module SUAnalysis
  module Core
    class PreparedCadDataset
      # Locked top-level schema_version. Bump on any field-set
      # change.
      SCHEMA_VERSION         = 'pcd.v1'.freeze
      # Identity schemas (separate from the dataset schema).
      SEMANTIC_IDENTITY_SCHEMA    = 'pcd-semantic-identity.v1'.freeze
      BUILD_EVIDENCE_IDENTITY_SCHEMA = 'pcd-build-evidence-identity.v1'.freeze
      SOURCE_PROJECTION_SCHEMA  = 'pcd-source-projection.v1'.freeze
      EXECUTION_SCHEMA          = 'pcd-execution.v1'.freeze
      # Truncation widths. 20 lowercase hex chars = 80 bits.
      DATASET_ID_TRUNCATED_LEN = 20
      # dataset_id prefix per B1-SR-01.
      DATASET_ID_PREFIX = 'pcd-'.freeze
      NODE_ID_PREFIX = 'pcn-'.freeze
      EDGE_ID_PREFIX = 'pce-'.freeze
      CHAIN_ID_PREFIX = 'pch-'.freeze
      LOOP_ID_PREFIX = 'pcl-'.freeze
      REGION_ID_PREFIX = 'pcr-'.freeze
      REPAIR_ID_PREFIX = 'pcrp-'.freeze
      # SHA-256 hex length.
      SHA256_HEX_LEN = 64

      attr_reader :schema_version, :dataset_id, :content_digest,
                  :content, :build_evidence_digest, :build_evidence,
                  :validation

      # ----- Construction ---------------------------------------------------

      # Build a candidate PreparedCadDataset.
      #
      # Required:
      #   content         : Hash<String, ...>  (semantic content; JSON-safe)
      #   content_digest  : String  (FULL 64 lowercase hex chars)
      #   build_evidence  : Hash<String, ...>  (build evidence; JSON-safe)
      #   build_evidence_digest : String  (FULL 64 lowercase hex chars)
      #
      # Optional:
      #   schema_version  : defaults to SCHEMA_VERSION
      #
      # The candidate has validation=nil. Finalization is the
      # job of PreparedCadDatasetValidator.
      def self.build_candidate(content:, content_digest:,
                               build_evidence:, build_evidence_digest:,
                               schema_version: SCHEMA_VERSION)
        unless content.is_a?(Hash)
          raise ArgumentError, "content must be a Hash; got #{content.class}"
        end
        unless content_digest.is_a?(String) && _full_hex64?(content_digest)
          raise ArgumentError,
                'content_digest must be a 64 lowercase hex String (B1-SR-01)'
        end
        unless build_evidence.is_a?(Hash)
          raise ArgumentError, 'build_evidence must be a Hash'
        end
        unless build_evidence_digest.is_a?(String) && _full_hex64?(build_evidence_digest)
          raise ArgumentError,
                'build_evidence_digest must be a 64 lowercase hex String (B1-SR-01)'
        end
        dataset_id = compute_dataset_id(content_digest)
        # Defensive deep-freeze + key normalization. We never
        # publish Symbol keys.
        frozen_content = _stringify_deep_freeze(content)
        frozen_evidence = _stringify_deep_freeze(build_evidence)
        new(
          schema_version: schema_version,
          dataset_id: dataset_id,
          content_digest: content_digest,
          content: frozen_content,
          build_evidence_digest: build_evidence_digest,
          build_evidence: frozen_evidence,
          validation: nil
        )
      end

      # Internal: the constructor stores the full content_digest
      # and full build_evidence_digest as the PUBLIC persisted
      # fields. `validation` may be nil (candidate) or a frozen
      # Hash (final).
      def initialize(schema_version:, dataset_id:,
                     content_digest:, content:,
                     build_evidence_digest:, build_evidence:,
                     validation:)
        @schema_version             = schema_version.to_s.freeze
        @dataset_id                 = dataset_id.to_s.freeze
        @content_digest             = content_digest.to_s.freeze
        @content                    = content  # already deeply frozen
        @build_evidence_digest      = build_evidence_digest.to_s.freeze
        @build_evidence             = build_evidence  # already deeply frozen
        @validation                 = validation  # nil or deeply frozen Hash
        freeze
      end

      # ----- Finalization ---------------------------------------------------

      # Return a NEW PreparedCadDataset with the validation Hash
      # attached. The candidate's five content-identity fields
      # (content, content_digest, dataset_id, build_evidence,
      # build_evidence_digest) MUST NOT change.
      #
      # The validation Hash MUST bind BOTH:
      #   validated_content_digest        : == candidate.content_digest
      #                                       (FULL 64-hex)
      #   validated_build_evidence_digest : == candidate.build_evidence_digest
      #                                       (FULL 64-hex)
      # otherwise this raises ArgumentError.
      def with_validation(validation)
        unless validation.is_a?(Hash)
          raise ArgumentError, "validation must be a Hash; got #{validation.class}"
        end
        vcd = validation['validated_content_digest']
        vbed = validation['validated_build_evidence_digest']
        unless vcd.is_a?(String) && vcd == content_digest
          raise ArgumentError, 'validated_content_digest mismatch'
        end
        unless vbed.is_a?(String) && vbed == build_evidence_digest
          raise ArgumentError, 'validated_build_evidence_digest mismatch'
        end
        frozen_validation = self.class._stringify_deep_freeze(validation)
        self.class.new(
          schema_version: schema_version,
          dataset_id: dataset_id,
          content_digest: content_digest,
          content: content,
          build_evidence_digest: build_evidence_digest,
          build_evidence: build_evidence,
          validation: frozen_validation
        )
      end

      # ----- Digest derivation ---------------------------------------------

      # Compute the dataset_id from a full content digest
      # (B1-SR-01): "pcd-" + first 20 lowercase hex chars.
      def self.compute_dataset_id(full_content_digest)
        "#{DATASET_ID_PREFIX}#{full_content_digest.to_s[0, DATASET_ID_TRUNCATED_LEN]}"
      end

      # Compute the SHA-256 content_digest from a content Hash
      # using the B1 identity-byte encoder over the SEMANTIC
      # HASH DOMAIN.
      #
      # The ONLY semantic hash object is:
      #   {
      #     "identity_schema_version" => SEMANTIC_IDENTITY_SCHEMA,
      #     "dataset_schema_version"  => SCHEMA_VERSION,
      #     "content"                 => normalized_semantic_content
      #   }
      def self.compute_content_digest(content)
        domain = {
          'identity_schema_version' => SEMANTIC_IDENTITY_SCHEMA,
          'dataset_schema_version'  => SCHEMA_VERSION,
          'content'                 => _normalize_strings_utf8(content)
        }
        Digest::SHA256.hexdigest(IdentityBytes.encode(domain))
      end

      # Compute the SHA-256 build_evidence_digest from the
      # final content_digest + build_evidence Hash using the B1
      # identity-byte encoder over:
      #   {
      #     "identity_schema_version" => BUILD_EVIDENCE_IDENTITY_SCHEMA,
      #     "content_digest"          => full_content_digest,
      #     "build_evidence"          => build_evidence
      #   }
      def self.compute_build_evidence_digest(full_content_digest, build_evidence)
        domain = {
          'identity_schema_version' => BUILD_EVIDENCE_IDENTITY_SCHEMA,
          'content_digest'          => _utf8_string(full_content_digest),
          'build_evidence'          => _normalize_strings_utf8(build_evidence)
        }
        Digest::SHA256.hexdigest(IdentityBytes.encode(domain))
      end

      # Convert a hex digest String (e.g. from Digest::SHA256.
      # hexdigest) which Ruby returns as US-ASCII into a UTF-8
      # String so the strict B1-SR-12 identity encoder accepts
      # it. Hex characters are all 7-bit ASCII, which is a
      # strict subset of UTF-8, so the conversion is safe and
      # preserves the exact byte sequence.
      def self._utf8_string(s)
        return s if s.nil?
        return s unless s.respond_to?(:encoding)
        return s if s.encoding.name == 'UTF-8' && s.valid_encoding?
        out = s.dup.force_encoding('UTF-8')
        unless out.valid_encoding?
          raise ArgumentError,
                "cannot convert hex digest to UTF-8: #{out.inspect[0, 80]}"
        end
        out
      end

      # Recursively walk a Hash / Array / scalar value and
      # convert all String values (and Hash keys) to UTF-8.
      # This is the B1-SR-12 entry-point used by the digest
      # computation so that US-ASCII digests embedded in
      # semantic content / build evidence do not blow up the
      # strict identity encoder.
      def self._normalize_strings_utf8(v)
        case v
        when Hash
          out = {}
          v.each do |k, val|
            ks = k.is_a?(String) ? _utf8_string(k) : k
            unless ks.is_a?(String) && !ks.is_a?(Symbol)
              raise ArgumentError, "non-String hash key: #{k.inspect}"
            end
            out[ks] = _normalize_strings_utf8(val)
          end
          out
        when Array
          v.map { |x| _normalize_strings_utf8(x) }
        when String
          _utf8_string(v)
        when Symbol
          # Symbols are not allowed in the encoded domain.
          raise ArgumentError, "Symbol value not allowed: #{v.inspect}"
        when Numeric, TrueClass, FalseClass, NilClass
          v
        else
          raise ArgumentError,
                "unsupported value type in encoded domain: #{v.class}"
        end
      end

      # Convert a hex digest String (e.g. from Digest::SHA256.
      # hexdigest) which Ruby returns as US-ASCII into a UTF-8
      # String so the strict B1-SR-12 identity encoder accepts
      # it. Hex characters are all 7-bit ASCII, which is a
      # strict subset of UTF-8, so the conversion is safe and
      # preserves the exact byte sequence.
      def self._utf8_string(s)
        return s if s.nil?
        return s unless s.respond_to?(:encoding)
        return s if s.encoding.name == 'UTF-8' && s.valid_encoding?
        out = s.dup.force_encoding('UTF-8')
        unless out.valid_encoding?
          raise ArgumentError,
                "cannot convert hex digest to UTF-8: #{out.inspect[0, 80]}"
        end
        out
      end

      # ----- Equality / introspection --------------------------------------

      # Two PreparedCadDataset instances are == iff their
      # content + digests + dataset_id match (validation is
      # intentionally excluded so the same candidate is equal
      # to its final form).
      def ==(other)
        return false unless other.is_a?(PreparedCadDataset)
        schema_version == other.schema_version &&
          dataset_id == other.dataset_id &&
          content_digest == other.content_digest &&
          build_evidence_digest == other.build_evidence_digest &&
          content == other.content &&
          build_evidence == other.build_evidence
      end
      alias eql? ==

      def hash
        [schema_version, dataset_id, content_digest,
         build_evidence_digest, content, build_evidence].hash
      end

      def candidate?
        validation.nil?
      end

      def final?
        !validation.nil?
      end

      # ----- Persistence (deterministic JSON) -------------------------------

      # The persisted JSON serializer is a separate contract
      # from identity bytes. It deterministically serializes the
      # COMPLETE final top-level dataset for the <= 8 MiB gate.
      #
      # Hashes are recursively sorted by their UTF-8 String key
      # bytes; Arrays preserve semantic order; Numbers use
      # ordinary JSON number rendering (NOT identity-hex bytes).
      def to_persisted_json
        PreparedCadDatasetSerializer.encode(self)
      end

      # Out-of-band measurement: exact UTF-8 bytesize of the
      # final persisted JSON. This byte count is NEVER
      # persisted in the payload itself.
      def persisted_bytesize
        to_persisted_json.bytesize
      end

      # ----- Internals ------------------------------------------------------

      # Strict 64-hex full-digest format check.
      def self._full_hex64?(s)
        s.is_a?(String) && s.length == SHA256_HEX_LEN && s.match?(/\A[0-9a-f]{64}\z/)
      end

      # Stringify + deep-freeze a Hash / Array / scalar value.
      # Symbols become Strings. Strings are validated STRICT UTF-8
      # (B1-SR-12). Nested Arrays / Hashes recurse.
      def self._stringify_deep_freeze(value)
        _deep_freeze_stringify(value)
      end

      def self._deep_freeze_stringify(v)
        case v
        when Hash
          out = {}
          v.each do |k, val|
            ks = k.is_a?(Symbol) ? k.to_s : k
            unless ks.is_a?(String)
              raise ArgumentError, "hash key must be String or Symbol; got #{k.inspect}"
            end
            ks = _utf8_string(ks)
            _validate_strict_utf8!(ks)
            out[ks] = _deep_freeze_stringify(val)
          end
          out.freeze
        when Array
          v.map { |x| _deep_freeze_stringify(x) }.freeze
        when String
          v = _utf8_string(v)
          _validate_strict_utf8!(v)
          v.freeze
        when Symbol
          raise ArgumentError, "Symbol value not allowed in published dataset: #{v.inspect}"
        when Numeric, TrueClass, FalseClass, NilClass
          v
        else
          raise ArgumentError,
                "unsupported value type in published dataset: #{v.class} #{v.inspect[0, 80]}"
        end
      end

      # B1-SR-12 strict UTF-8 validation. Strings in the
      # identity encoder / public published dataset must be
      # valid UTF-8. Valid-but-non-UTF-8 encodings (e.g.
      # ASCII-8BIT, US-ASCII) are REJECTED.
      def self._validate_strict_utf8!(str)
        return if str.nil?
        unless str.respond_to?(:encoding)
          raise ArgumentError, "non-encoding-aware value: #{str.inspect[0, 80]}"
        end
        unless str.encoding.name == 'UTF-8' && str.valid_encoding?
          raise ArgumentError,
                "invalid / non-UTF-8 String: encoding=#{str.encoding.name.inspect} " \
                "valid_encoding?=#{str.respond_to?(:valid_encoding?) && str.valid_encoding?} " \
                "value=#{str.inspect[0, 80]}"
        end
      end
    end

    # ----------------------------------------------------------------------
    # IdentityBytes — B1 canonical byte encoder.
    #
    # Implements the type-disjoint grammar from Blueprint v1.3
    # §3.1. The encoder is HOST-AGNOSTIC: nil, Boolean, Integer,
    # finite Float, valid UTF-8 String, Array, Hash with String
    # keys. Symbol keys/values are rejected.
    #
    # Float encoding is Ruby's IEEE-754 binary64 big-endian hex
    # using [v].pack('G').unpack('H*').first — Ruby 2.2+
    # compatible. -0.0 normalizes to +0.0 before encoding so
    # -0.0 and +0.0 share the same identity bytes.
    #
    # The encoder produces UTF-8 byte strings only (no binary
    # escapes). The output bytes are valid for SHA-256.
    #
    # B1-SR-12: the encoder accepts only UTF-8 Strings.
    # Valid-but-non-UTF-8 encodings are rejected; invalid UTF-8
    # is rejected.
    # ----------------------------------------------------------------------
    module IdentityBytes
      module_function

      def encode(value)
        _encode(value)
      end

      def _encode(v)
        case v
        when nil
          'N;'.dup
        when false
          'B0;'.dup
        when true
          'B1;'.dup
        when Integer
          # Base-10 decimal, no '+', no leading zeros except '0'.
          s = v.to_s
          raise ArgumentError, "non-canonical Integer: #{v.inspect}" unless _canonical_int_str?(s)
          "I#{s.bytesize}:#{s};".dup
        when Float
          unless v.finite?
            raise ArgumentError, "non-finite Float not allowed: #{v.inspect}"
          end
          # -0.0 -> +0.0 (NOTE: -0.0 == 0.0 in Ruby Float,
          # so this branch collapses both to the +0.0 IEEE-754
          # representation).
          normalized = v.zero? ? 0.0 : v
          hex = [normalized].pack('G').unpack('H*').first
          unless hex.is_a?(String) && hex.length == 16
            raise ArgumentError, "Float identity pack failed: #{v.inspect} -> #{hex.inspect}"
          end
          "F#{hex};".dup
        when String
          _validate_strict_utf8!(v)
          "S#{v.bytesize}:#{v};".dup
        when Symbol
          raise ArgumentError, "Symbol not allowed in identity encoding: #{v.inspect}"
        when Array
          parts = ['A', v.length.to_s, ':[']
          v.each { |item| parts << _encode(item) }
          parts << '];'
          parts.join
        when Hash
          keys = v.keys
          keys.each do |k|
            unless k.is_a?(String)
              raise ArgumentError,
                    "hash key must be String (got #{k.class}: #{k.inspect})"
            end
            _validate_strict_utf8!(k)
          end
          sorted_keys = keys.sort_by { |k| k.bytes }
          parts = ['H', sorted_keys.length.to_s, ':{']
          sorted_keys.each do |k|
            parts << _encode(k)
            parts << _encode(v[k])
          end
          parts << '};'
          parts.join
        else
          raise ArgumentError,
                "identity encoder does not accept #{v.class}: #{v.inspect[0, 80]}"
        end
      end

      def _canonical_int_str?(s)
        return false if s.nil? || s.empty?
        return false unless s.match?(/\A-?\d+\z/)
        # No leading zeros except the literal "0" or "-0".
        if s.length > 1
          if s.start_with?('-')
            return false if s[1] == '0'
            return false if s[1].nil?
          else
            return false if s[0] == '0'
          end
        end
        true
      end

      # B1-SR-12 strict UTF-8. Per the Blueprint v1.3 + the AIPM
      # Source Review Correction 2026-09-14, identity / public
      # semantic Strings MUST be valid UTF-8. Valid-but-non-UTF-8
      # encodings (e.g. ASCII-8BIT, US-ASCII) are REJECTED.
      def _validate_strict_utf8!(str)
        return if str.nil?
        unless str.respond_to?(:encoding)
          raise ArgumentError, "non-encoding-aware value: #{str.inspect[0, 80]}"
        end
        unless str.encoding.name == 'UTF-8' && str.valid_encoding?
          raise ArgumentError,
                "invalid / non-UTF-8 String: encoding=#{str.encoding.name.inspect} " \
                "valid_encoding?=#{str.respond_to?(:valid_encoding?) && str.valid_encoding?} " \
                "value=#{str.inspect[0, 80]}"
        end
      end
    end

    # ----------------------------------------------------------------------
    # PreparedCadDatasetSerializer — deterministic persisted JSON.
    #
    # Separate from identity bytes. The serializer emits the
    # COMPLETE final top-level dataset with deterministic Hash
    # key order (sorted by raw UTF-8 bytes) so the persisted
    # payload is byte-stable for identical inputs.
    #
    # Used by:
    #   - PreparedCadDataset#to_persisted_json
    #   - PreparedCadDatasetValidator <= 8 MiB gate
    #   - (later) V1.9B2 B2 persistence
    # ----------------------------------------------------------------------
    module PreparedCadDatasetSerializer
      module_function

      # Top-level field order — locked. This is the EXACT shape
      # of the published payload that B2 will persist.
      TOP_LEVEL_FIELDS = [
        'schema_version',
        'dataset_id',
        'content_digest',
        'content',
        'build_evidence_digest',
        'build_evidence',
        'validation'
      ].freeze

      def encode(dataset)
        unless dataset.is_a?(PreparedCadDataset)
          raise ArgumentError, "encoder requires PreparedCadDataset; got #{dataset.class}"
        end
        payload = {
          'schema_version'         => dataset.schema_version,
          'dataset_id'             => dataset.dataset_id,
          'content_digest'         => dataset.content_digest,
          'content'                => dataset.content,
          'build_evidence_digest'  => dataset.build_evidence_digest,
          'build_evidence'         => dataset.build_evidence,
          'validation'             => dataset.validation
        }
        JSON.generate(_sort_keys_deep(payload))
      end

      # Recursively walk a Hash and rebuild it with sorted
      # String keys. Arrays preserve semantic order. This is
      # the same logic used by B2; kept here so the persisted
      # payload is byte-stable for identical inputs.
      def _sort_keys_deep(v)
        case v
        when Hash
          out = {}
          v.keys.map(&:to_s).sort_by { |k| k.bytes }.each do |k|
            out[k] = _sort_keys_deep(v[k])
          end
          out
        when Array
          v.map { |x| _sort_keys_deep(x) }
        else
          v
        end
      end
    end
  end
end
