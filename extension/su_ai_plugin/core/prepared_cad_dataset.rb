#
# core/prepared_cad_dataset.rb — V1.9B1 B1.2 PreparedCadDataset.
#
# Per frozen V1.9B1 Blueprint v1.3 (authoritative over v1.2):
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
#   Validation never defines semantic identity.
#   Candidate / final share the same five content-identity
#   fields. Validation is attached separately and binds BOTH
#   validated_content_digest + validated_build_evidence_digest.
#
#   Truncated-ID collision hardening: full digests are retained
#   internally; same truncated prefix mapped to a different
#   full digest => BLOCKED.
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
      # Truncation widths. 20 lowercase hex chars = 80 bits.
      DATASET_ID_TRUNCATED_LEN = 20
      NODE_ID_PREFIX = 'pcn-'.freeze
      EDGE_ID_PREFIX = 'pce-'.freeze
      CHAIN_ID_PREFIX = 'pch-'.freeze
      LOOP_ID_PREFIX = 'pcl-'.freeze
      REGION_ID_PREFIX = 'pcr-'.freeze
      REPAIR_ID_PREFIX = 'pcrp-'.freeze

      attr_reader :schema_version, :dataset_id, :content_digest,
                  :content, :build_evidence_digest, :build_evidence,
                  :validation, :full_content_digest,
                  :full_build_evidence_digest

      # ----- Construction ---------------------------------------------------

      # Build a candidate PreparedCadDataset.
      #
      # Required:
      #   content         : Hash<String, ...>  (semantic content; JSON-safe)
      #   content_digest  : String  (32 lowercase hex chars)
      #   build_evidence  : Hash<String, ...>  (build evidence; JSON-safe)
      #   build_evidence_digest : String  (32 lowercase hex chars)
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
        unless content_digest.is_a?(String) && !content_digest.empty?
          raise ArgumentError, 'content_digest must be a non-empty String'
        end
        unless build_evidence.is_a?(Hash)
          raise ArgumentError, 'build_evidence must be a Hash'
        end
        unless build_evidence_digest.is_a?(String) && !build_evidence_digest.empty?
          raise ArgumentError, 'build_evidence_digest must be a non-empty String'
        end
        dataset_id = compute_dataset_id(content_digest)
        # Defensive deep-freeze + key normalization. We never
        # publish Symbol keys.
        frozen_content = _stringify_deep_freeze(content)
        frozen_evidence = _stringify_deep_freeze(build_evidence)
        new(
          schema_version: schema_version,
          dataset_id: dataset_id,
          full_content_digest: content_digest,
          content: frozen_content,
          full_build_evidence_digest: build_evidence_digest,
          build_evidence: frozen_evidence,
          validation: nil,
          full_dataset_digest: nil
        )
      end

      # Internal: the constructor stores both the published
      # truncated dataset_id and the full content_digest (for
      # truncated-ID collision hardening). `validation` may be
      # nil (candidate) or a frozen Hash (final). `dataset_digest`
      # is an optional secondary cache filled when finalization
      # freezes the full payload.
      def initialize(schema_version:, dataset_id:,
                     full_content_digest:, content:,
                     full_build_evidence_digest:, build_evidence:,
                     validation:, full_dataset_digest:)
        @schema_version             = schema_version.to_s.freeze
        @dataset_id                 = dataset_id.to_s.freeze
        @full_content_digest        = full_content_digest.to_s.freeze
        @content                    = content  # already deeply frozen
        @full_build_evidence_digest = full_build_evidence_digest.to_s.freeze
        @build_evidence             = build_evidence  # already deeply frozen
        @validation                 = validation  # nil or deeply frozen Hash
        @full_dataset_digest        = full_dataset_digest
        @content_digest             = @full_content_digest[0, DATASET_ID_TRUNCATED_LEN]
        @build_evidence_digest      = @full_build_evidence_digest[0, DATASET_ID_TRUNCATED_LEN]
        freeze
      end

      # ----- Finalization ---------------------------------------------------

      # Return a NEW PreparedCadDataset with the validation Hash
      # attached. The candidate's five content-identity fields
      # (content, content_digest, dataset_id, build_evidence,
      # build_evidence_digest) MUST NOT change.
      #
      # The validation Hash MUST bind BOTH:
      #   validated_content_digest        : == candidate.full_content_digest
      #   validated_build_evidence_digest : == candidate.full_build_evidence_digest
      # otherwise this raises ArgumentError.
      def with_validation(validation)
        unless validation.is_a?(Hash)
          raise ArgumentError, "validation must be a Hash; got #{validation.class}"
        end
        vcd = validation['validated_content_digest']
        vbed = validation['validated_build_evidence_digest']
        unless vcd.is_a?(String) && vcd == full_content_digest
          raise ArgumentError, 'validated_content_digest mismatch'
        end
        unless vbed.is_a?(String) && vbed == full_build_evidence_digest
          raise ArgumentError, 'validated_build_evidence_digest mismatch'
        end
        frozen_validation = self.class._stringify_deep_freeze(validation)
        self.class.new(
          schema_version: schema_version,
          dataset_id: dataset_id,
          full_content_digest: full_content_digest,
          content: content,
          full_build_evidence_digest: full_build_evidence_digest,
          build_evidence: build_evidence,
          validation: frozen_validation,
          full_dataset_digest: frozen_validation['dataset_digest']
        )
      end

      # ----- Digest derivation ---------------------------------------------

      # Compute the truncated dataset_id from a full content
      # digest. Truncated-id prefix is the first 20 lowercase
      # hex chars.
      def self.compute_dataset_id(full_content_digest)
        full_content_digest.to_s[0, DATASET_ID_TRUNCATED_LEN]
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
          'content'                 => content
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
          'content_digest'          => full_content_digest.to_s,
          'build_evidence'          => build_evidence
        }
        Digest::SHA256.hexdigest(IdentityBytes.encode(domain))
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
          full_content_digest == other.full_content_digest &&
          full_build_evidence_digest == other.full_build_evidence_digest &&
          content == other.content &&
          build_evidence == other.build_evidence
      end
      alias eql? ==

      def hash
        [schema_version, dataset_id, full_content_digest,
         full_build_evidence_digest, content, build_evidence].hash
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

      # Stringify + deep-freeze a Hash / Array / scalar value.
      # Symbols become Strings. Strings are validated UTF-8.
      # Nested Arrays / Hashes recurse.
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
            _validate_utf8!(ks)
            out[ks] = _deep_freeze_stringify(val)
          end
          out.freeze
        when Array
          v.map { |x| _deep_freeze_stringify(x) }.freeze
        when String
          _validate_or_ascii!(v)
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

      def self._validate_utf8!(str)
        return if str.nil?
        unless str.respond_to?(:encode) && str.encoding.name == 'UTF-8' &&
               str.valid_encoding?
          raise ArgumentError, "invalid UTF-8 string: #{str.inspect[0, 80]}"
        end
      end

      def self._validate_or_ascii!(str)
        return if str.nil?
        return if !str.respond_to?(:encoding)
        return if str.valid_encoding?
        raise ArgumentError, "invalid byte string: #{str.inspect[0, 80]}"
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
          normalized = (v == 0.0 ? 0.0 : v)  # -0.0 -> +0.0
          hex = [normalized].pack('G').unpack('H*').first
          unless hex.is_a?(String) && hex.length == 16
            raise ArgumentError, "Float identity pack failed: #{v.inspect} -> #{hex.inspect}"
          end
          "F#{hex};".dup
        when String
          _validate_or_ascii!(v)
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
            _validate_utf8!(k)
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

      def _validate_utf8!(str)
        return if str.nil?
        unless str.respond_to?(:encoding) && str.encoding.name == 'UTF-8' &&
               str.valid_encoding?
          raise ArgumentError, "invalid UTF-8 string: #{str.inspect[0, 80]}"
        end
      end

      # Identity bytes must accept BINARY / US-ASCII strings
      # (e.g. SHA-256 hex digests returned by Digest::SHA256.
      # hexdigest). The constraint is that the byte sequence be
      # a valid bit-pattern for hashing; bytes are bytes.
      def _validate_or_ascii!(str)
        return if str.nil?
        return if !str.respond_to?(:encoding)
        # ASCII-only / binary is acceptable because identity
        # bytes encode the byte length + raw bytes. The byte
        # pattern itself is the source of truth.
        return if str.valid_encoding?
        raise ArgumentError, "invalid byte string: #{str.inspect[0, 80]}"
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
