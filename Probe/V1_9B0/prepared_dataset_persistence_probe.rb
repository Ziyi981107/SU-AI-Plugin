#
# Probe/V1_9B0/prepared_dataset_persistence_probe.rb
# -----------------------------------------------------------------------------
# V1.9B0 — PreparedCadDataset Persistence Feasibility Probe
#
# This file is a STANDALONE REAL-HOST PROBE.
#
# It is NOT production code. It is NOT loaded into a new RBZ. It is NOT a
# replacement for V1.9A WorkingModeRunner / PreparedCadDataset production
# implementation. It is a loadable SketchUp 2020 Ruby Console probe whose
# only purpose is to answer:
#
#     "Can SketchUp Model AttributeDictionary reliably persist a
#      representative future PreparedCadDataset payload at realistic size?"
#
# Loaded from SketchUp 2020 Ruby Console (no RBZ install required):
#
#     load 'D:/Projects/SU-AI-Plugin/Probe/V1_9B0/prepared_dataset_persistence_probe.rb'
#
# The probe deliberately lives OUTSIDE `extension/`. It MUST NOT mutate any
# source CAD entity, MUST NOT create Faces, MUST NOT move vertices, MUST NOT
# touch WorkingModeRunner state, MUST NOT touch the existing V1.9A derived
# workspace. It uses Model AttributeDictionary APIs only, with explicit
# probe-namespaced keys so it can never be confused with a future production
# accepted dataset.
#
# Host-free (non-SketchUp) execution:
#
#   - All payload generation + JSON serialization + SHA-256 + deterministic
#     generation runs without SketchUp (validated in vendored Ruby 2.7.8).
#   - All SketchUp-touching helpers check `defined?(Sketchup)` and return a
#     structured fail-closed result `{ ok: false, reason: 'sketchup_unavailable',
#     ... }` instead of raising. This is intentional: probe-only code MUST
#     not silently fake host-free evidence.
#
# Layering:
#
#   1. Pure host-free layer (always available):
#      - SUAIPlugin::V19B0Probe::PROBE_DICTIONARY
#      - SUAIPlugin::V19B0Probe::KEY_PAYLOAD / KEY_DIGEST / KEY_SCHEMA / KEY_SEED
#        / KEY_REQUESTED_BYTES / KEY_ACTUAL_BYTES
#      - SUAIPlugin::V19B0Probe::SIZE_LADDER_BYTES
#      - SUAIPlugin::V19B0Probe.sha256_hex(string)
#      - SUAIPlugin::V19B0Probe.generate_payload(seed:, target_bytes:)
#      - SUAIPlugin::V19B0Probe.deterministic_string(seed:, length:)
#      - SUAIPlugin::V19B0Probe.json_round_trip(payload_string)
#      - SUAIPlugin::V19B0Probe.deterministic_payload_check(seed:, target_bytes:)
#        (re-generates twice and asserts byte-identical output)
#
#   2. SketchUp-touching layer (only when loaded inside SketchUp):
#      - SUAIPlugin::V19B0Probe.probe_dictionary(model)
#      - SUAIPlugin::V19B0Probe.write_probe(model, payload_string, seed:, requested_bytes:)
#      - SUAIPlugin::V19B0Probe.read_probe(model)
#      - SUAIPlugin::V19B0Probe.verify_probe(model)
#      - SUAIPlugin::V19B0Probe.cleanup_probe(model)
#      - SUAIPlugin::V19B0Probe.run_size_ladder(model, custom_bytes: nil)
#      - SUAIPlugin::V19B0Probe.run_immediate_readback_test(model, target_bytes:)
#      - SUAIPlugin::V19B0Probe.run_replacement_test(model, target_bytes:)
#      - SUAIPlugin::V19B0Probe.run_corrupt_missing_tests(model)
#      - SUAIPlugin::V19B0Probe.write_undo_redo_probe(model, payload_string, seed:)
#      - SUAIPlugin::V19B0Probe.write_reopen_test_payload(model, payload_string, seed:)
#      - SUAIPlugin::V19B0Probe.verify_reopen_test_payload(model)
#      - SUAIPlugin::V19B0Probe.help
#
# The SketchUp-touching layer wraps every write operation in
# `model.start_operation(...)/commit_operation` so that the host Undo/Redo
# stack observes the probe write as a single undoable SketchUp operation.
# Owner can then exercise real SketchUp Undo/Redo manually (or call the
# host-touching helpers before / after manual Undo/Redo).
#
# Safety contract (enforced inside every SketchUp-touching helper):
#
#   - Never delete geometry.
#   - Never alter source CAD entities.
#   - Never create Faces.
#   - Never move vertices.
#   - Never touch WorkingModeRunner state.
#   - Never touch the existing V1.9A derived workspace.
#   - All model attributes are namespaced under SU-AI-Plugin.PreparedCadDataset
#     with `__v19b0_probe_*__` keys.
#   - Cleanup is provided (cleanup_probe removes every probe-namespaced key).
#   - Fail-closed status is returned (no exception escapes) for expected
#     corrupt-storage conditions (missing key, invalid JSON, digest mismatch,
#     unsupported probe schema marker).
#   - Unexpected programming errors are NOT silently swallowed; they
#     propagate. Use `ensure` in the caller as appropriate.
#
# Persistence route is NOT frozen by this probe. AIPM will decide whether
# SketchUp Model AttributeDictionary is acceptable based on Owner real-host
# evidence after Pi returns this probe.
#
# V1.9A is frozen. This probe does NOT modify anything under `extension/`.
# -----------------------------------------------------------------------------

require 'json'
require 'digest'
require 'time'

module SUAIPlugin
  module V19B0Probe
    # ----- Probe namespacing (DO NOT change without AIPM) ----------------
    PROBE_DICTIONARY      = 'SU-AI-Plugin.PreparedCadDataset'
    PROBE_SCHEMA_MARKER   = 'v19b0_probe_v1'
    KEY_PAYLOAD           = '__v19b0_probe_payload__'
    KEY_DIGEST            = '__v19b0_probe_digest__'
    KEY_SCHEMA            = '__v19b0_probe_schema__'
    KEY_SEED              = '__v19b0_probe_seed__'
    KEY_REQUESTED_BYTES   = '__v19b0_probe_requested_bytes__'
    KEY_ACTUAL_BYTES      = '__v19b0_probe_actual_bytes__'

    ALL_PROBE_KEYS = [
      KEY_PAYLOAD,
      KEY_DIGEST,
      KEY_SCHEMA,
      KEY_SEED,
      KEY_REQUESTED_BYTES,
      KEY_ACTUAL_BYTES,
    ].freeze

    # Default size ladder. Owner may pass a custom_bytes array to override.
    SIZE_LADDER_BYTES = [
      256 * 1024,          # 256 KiB
      1024 * 1024,         # 1 MiB
      4 * 1024 * 1024,     # 4 MiB
      8 * 1024 * 1024,     # 8 MiB
    ].freeze

    DEFAULT_OP_NAME     = 'SU-AI-Plugin V1.9B0 Persistence Probe Write'
    # NOTE: SketchUp's start_operation(name, disable_ui, transparent) takes
    # at most 3 arguments; the 3rd is the Boolean `transparent` flag, NOT a
    # description string. A Ruby String would be truthy and silently create
    # a transparent operation (with no Undo entry + no Undo/Redo probe
    # visibility). B0-01 fix: always call `start_operation(name, true, false)`
    # so the operation is non-transparent and observable in the host Undo
    # stack. See FakeModel transaction-arguments regression in
    # `_validation_runner.rb`.

    # ----- Host-free helpers (always available) --------------------------

    # Deterministic SHA-256 of a String (UTF-8 bytes).
    # Returns the lowercase hex digest.
    def self.sha256_hex(string)
      Digest::SHA256.hexdigest(string)
    end

    # Deterministic byte-safe pseudo-random string of exactly `length`
    # characters, derived from `seed`. Pure function: same seed + length
    # always produces the same output.
    def self.deterministic_string(seed:, length:)
      raise ArgumentError, 'length must be >= 0' if length.negative?
      return '' if length.zero?
      chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + [' ', '.', '-', '_']
      # SeededRandom: linear-congruential style for cross-host determinism.
      rng = SeededRandom.new((seed.to_i & 0xFFFFFFFF) ^ length)
      out = String.new(capacity: length)
      length.times { out << chars[rng.rand(chars.length)] }
      out
    end

    # Generate a deterministic JSON-safe payload of approximately
    # `target_bytes` bytes. The structural skeleton resembles the likely
    # future PreparedCadDataset shape (metadata / source-like / nodes-like /
    # edges-like / structures-like / warnings-like sections) but does NOT
    # freeze the actual future B1 schema.
    #
    # Same seed + same target_bytes => byte-identical JSON.
    def self.generate_payload(seed:, target_bytes:)
      raise ArgumentError, 'target_bytes must be > 0' if target_bytes.to_i <= 0
      seed_int = seed.to_i

      skeleton = {
        'metadata' => {
          'schema'      => PROBE_SCHEMA_MARKER,
          'seed'        => seed_int,
          'generator'   => 'SUAIPlugin::V19B0Probe.generate_payload',
          'target_bytes'=> target_bytes,
          'note'        => 'synthetic deterministic probe payload (NOT a real B1 schema)',
        },
        'source_like' => {
          'cad_kind'                => 'synthetic_test',
          'format'                  => 'rbz_v19a_fixture_like',
          'layer_count'             => 7,
          'layer_names'             => [
            'L01_PRIMARY_ROADS',
            'L02_SECONDARY_ROADS',
            'L03_LOTS',
            'L04_BUILDINGS',
            'L05_GREEN_SPACE',
            'L06_ANNOTATIONS',
            'L07_UNKNOWN',
          ],
          'selection_count'         => 42,
          'fixture_geometry_summary'=> {
            'edge_count'             => 96,
            'vertex_count'           => 64,
            'group_count'            => 5,
            'component_count'        => 3,
            'nested_max_depth'       => 4,
            'units_hint'             => 'mm',
          },
        },
        'nodes_like'    => build_nodes_like(seed_int, 64),
        'edges_like'    => build_edges_like(seed_int, 96),
        'structures_like' => build_structures_like(seed_int, 5),
        'warnings_like' => build_warnings_like(seed_int, 12),
        'data_filler'   => '',
      }

      json = JSON.generate(skeleton)
      if json.bytesize < target_bytes
        # Each byte of filler adds exactly 1 byte to the JSON output
        # because the deterministic_string alphabet consists only of
        # JSON-safe chars (no escape encoding). The `"data_filler":""`
        # wrapper overhead is already accounted for in `json.bytesize`,
        # so the delta equals the new filler length exactly. If the
        # skeleton already exceeds the target, we emit it as-is (probe
        # is not a strict size contract; deterministic-payload + digest
        # equality is the real evidence).
        filler_len = target_bytes - json.bytesize
        if filler_len.positive?
          skeleton['data_filler'] = deterministic_string(seed: seed_int + 7, length: filler_len)
          json = JSON.generate(skeleton)
        end
      end
      json
    end

    # JSON round-trip in pure Ruby: parse then re-serialize. Returns a
    # structured hash describing the outcome. Does NOT touch SketchUp.
    def self.json_round_trip(payload_string)
      parsed = JSON.parse(payload_string)
      re_emitted = JSON.generate(parsed)
      {
        ok:               true,
        parse_ok:         true,
        parse_class:      parsed.class.name,
        original_bytes:   payload_string.bytesize,
        reparsed_bytes:   re_emitted.bytesize,
        exact_byte_equal: payload_string == re_emitted,
        digest_before:    sha256_hex(payload_string),
        digest_after:     sha256_hex(re_emitted),
      }
    end

    # Deterministic payload generation check: generate the same
    # (seed, target_bytes) twice and assert byte-identical output.
    # Returns a structured hash describing the outcome. Does NOT touch
    # SketchUp.
    def self.deterministic_payload_check(seed:, target_bytes:)
      a = generate_payload(seed: seed, target_bytes: target_bytes)
      b = generate_payload(seed: seed, target_bytes: target_bytes)
      {
        ok:                a == b,
        first_bytes:       a.bytesize,
        second_bytes:      b.bytesize,
        first_digest:      sha256_hex(a),
        second_digest:     sha256_hex(b),
        exact_byte_equal:  a == b,
      }
    end

    # ----- SketchUp-touching helpers ------------------------------------
    # Each helper returns a structured result hash; failures are
    # fail-closed (no exception escapes for expected corrupt-storage
    # conditions; unexpected programming errors propagate).

    def self.sketchup_available?
      defined?(Sketchup) && Sketchup.respond_to?(:active_model)
    end

    # Returns the probe AttributeDictionary for the given model, creating it
    # if necessary. Returns nil if SketchUp is unavailable.
    def self.probe_dictionary(model)
      return nil if !sketchup_available? || model.nil?
      model.attribute_dictionary(PROBE_DICTIONARY, true)
    end

    # Write the probe payload + digest + schema + seed + size to the
    # probe AttributeDictionary, wrapped in a single SketchUp operation so
    # that host Undo/Redo observes one undoable step.
    def self.write_probe(model, payload_string, seed:, requested_bytes:)
      return { ok: false, reason: 'sketchup_unavailable' } unless sketchup_available?
      return { ok: false, reason: 'nil_model' } if model.nil?
      return { ok: false, reason: 'nil_payload' } if payload_string.nil?
      return { ok: false, reason: 'empty_payload' } if payload_string.empty?

      actual_bytes = payload_string.bytesize
      digest       = sha256_hex(payload_string)
      result       = { ok: false }

      # B0-01: SketchUp start_operation signature is
      #   start_operation(name, disable_ui, transparent)
      # - name       : String (required, becomes the host Undo entry)
      # - disable_ui : Boolean (true => no UI during operation)
      # - transparent: Boolean (true => excluded from Undo stack — DO NOT use)
      # The previous call passed a String as the 4th positional argument;
      # Ruby silently ignored it AND the 3rd arg `false` left the operation
      # non-transparent. The fix is to call with exactly three positional
      # arguments and NEVER pass a description string. Failure paths use
      # `model.abort_operation`, never `model.abort` (which does not exist
      # on SketchUp::Model — it raises NoMethodError).
      begin
        model.start_operation(DEFAULT_OP_NAME, true, false)
        dict = probe_dictionary(model)
        if dict.nil?
          # B0-01 extension: probe_dictionary failed AFTER start_operation,
          # so the operation is still open. We MUST abort it before
          # returning; otherwise the host transaction leaks.
          begin
            model.abort_operation
          rescue StandardError
            # ignore secondary abort_operation errors
          end
          result = { ok: false, reason: 'dictionary_create_failed' }
        else
          dict[KEY_PAYLOAD]         = payload_string
          dict[KEY_DIGEST]          = digest
          dict[KEY_SCHEMA]          = PROBE_SCHEMA_MARKER
          dict[KEY_SEED]            = seed.to_s
          dict[KEY_REQUESTED_BYTES] = requested_bytes.to_i
          dict[KEY_ACTUAL_BYTES]    = actual_bytes
          model.commit_operation
          result = {
            ok:               true,
            requested_bytes:  requested_bytes.to_i,
            actual_bytes:     actual_bytes,
            digest:           digest,
            seed:             seed.to_i,
            schema:           PROBE_SCHEMA_MARKER,
            dictionary:       PROBE_DICTIONARY,
          }
        end
      rescue StandardError => e
        # Defensive: if we got far enough to open an operation, abort it.
        # B0-01 fix: use `abort_operation`, not `abort` (which doesn't exist
        # on SketchUp::Model and would itself raise).
        begin
          model.abort_operation
        rescue StandardError
          # ignore secondary abort_operation errors
        end
        result = {
          ok:     false,
          reason: 'unexpected_runtime_error',
          class:  e.class.name,
          message: e.message,
        }
      end
      result
    end

    # Read the probe payload back from the model AttributeDictionary.
    # Returns a fail-closed hash on any expected corrupt-storage condition.
    def self.read_probe(model)
      return { ok: false, reason: 'sketchup_unavailable' } unless sketchup_available?
      return { ok: false, reason: 'nil_model' } if model.nil?

      dict = model.attribute_dictionary(PROBE_DICTIONARY)
      return { ok: false, reason: 'dictionary_missing' } if dict.nil?

      payload         = dict[KEY_PAYLOAD]
      stored_digest   = dict[KEY_DIGEST]
      stored_schema   = dict[KEY_SCHEMA]
      stored_seed     = dict[KEY_SEED]
      req_bytes       = dict[KEY_REQUESTED_BYTES]
      act_bytes       = dict[KEY_ACTUAL_BYTES]

      if payload.nil?
        return { ok: false, reason: 'payload_missing' }
      end
      if stored_digest.nil? || stored_digest.to_s.empty?
        return { ok: false, reason: 'digest_missing' }
      end
      if stored_schema.nil?
        return { ok: false, reason: 'schema_missing' }
      end
      if stored_schema.to_s != PROBE_SCHEMA_MARKER
        return {
          ok: false,
          reason: 'unsupported_probe_schema',
          stored_schema: stored_schema.to_s,
          expected_schema: PROBE_SCHEMA_MARKER,
        }
      end

      {
        ok:                true,
        payload:           payload,
        digest:            stored_digest.to_s,
        schema:            stored_schema.to_s,
        seed:              stored_seed.to_i,
        requested_bytes:   req_bytes.to_i,
        actual_bytes:      act_bytes.to_i,
        actual_string_bytes: payload.to_s.bytesize,
      }
    end

    # Read + verify the probe: round-trip digest equality + JSON parse +
    # structural echo. Returns a fail-closed hash.
    def self.verify_probe(model)
      read = read_probe(model)
      return read unless read[:ok]

      payload = read[:payload]
      stored_digest = read[:digest]

      json_parse_ok = begin
        JSON.parse(payload)
        true
      rescue JSON::ParserError
        false
      end

      if !json_parse_ok
        return {
          ok: false,
          reason: 'invalid_json',
          digest: stored_digest,
        }
      end

      recomputed = sha256_hex(payload)
      digest_match = (recomputed == stored_digest)
      unless digest_match
        return {
          ok: false,
          reason: 'digest_mismatch',
          stored_digest: stored_digest,
          recomputed_digest: recomputed,
          actual_bytes: read[:actual_string_bytes],
        }
      end

      {
        ok:                  true,
        reason:              'verified',
        schema:              read[:schema],
        seed:                read[:seed],
        requested_bytes:     read[:requested_bytes],
        actual_bytes:        read[:actual_string_bytes],
        digest:              stored_digest,
        recomputed_digest:   recomputed,
        json_parse_ok:       true,
      }
    end

    # Remove every probe-namespaced key from the probe AttributeDictionary.
    # If the dictionary becomes empty after removal, the dictionary itself
    # is left in place (SketchUp does not expose a "remove empty dictionary"
    # API in all versions; an empty dictionary is harmless and uses no
    # observable SKP bytes beyond the dictionary header).
    def self.cleanup_probe(model)
      return { ok: false, reason: 'sketchup_unavailable' } unless sketchup_available?
      return { ok: false, reason: 'nil_model' } if model.nil?

      result = { ok: false }
      # B0-01: start_operation(name, disable_ui, transparent) — exactly 3 args.
      begin
        model.start_operation('SU-AI-Plugin V1.9B0 Probe Cleanup', true, false)
        dict = model.attribute_dictionary(PROBE_DICTIONARY)
        removed = []
        if dict.nil?
          result = { ok: true, removed: removed, note: 'no_dictionary' }
        else
          ALL_PROBE_KEYS.each do |k|
            if dict.keys.include?(k)
              dict.delete_key(k)
              removed << k
            end
          end
          result = { ok: true, removed: removed }
        end
        model.commit_operation
      rescue StandardError => e
        # B0-01 fix: use abort_operation (NOT abort — which does not exist).
        begin
          model.abort_operation
        rescue StandardError
          # ignore secondary abort_operation errors
        end
        result = {
          ok: false,
          reason: 'unexpected_runtime_error',
          class: e.class.name,
          message: e.message,
        }
      end
      result
    end

    # Run the default size ladder (or a custom array of bytes). For each
    # level: write -> immediate readback -> verify -> digest check -> print.
    # Returns an Array of result hashes (one per level).
    def self.run_size_ladder(model, custom_bytes: nil)
      return [{ ok: false, reason: 'sketchup_unavailable' }] unless sketchup_available?
      return [{ ok: false, reason: 'nil_model' }] if model.nil?
      ladder = custom_bytes.nil? ? SIZE_LADDER_BYTES.dup : Array(custom_bytes).map(&:to_i)
      seed_base = 0x1_9B0_0000
      results = []
      ladder.each_with_index do |bytes, idx|
        seed = seed_base + idx
        level_start = monotonic_now
        payload = generate_payload(seed: seed, target_bytes: bytes)
        gen_elapsed = monotonic_now - level_start

        write_start = monotonic_now
        write_result = write_probe(model, payload,
                                   seed: seed, requested_bytes: bytes)
        write_elapsed = monotonic_now - write_start

        read_start = monotonic_now
        # B0-03 fix: use read_probe (returns the raw payload string) for
        # the exact string equality check; use verify_probe separately for
        # JSON parse + digest verification. The previous `exact_byte_equal`
        # only compared byte counts (silently passing even when the payload
        # was corrupted to a different same-length string).
        raw_read = read_probe(model)
        read_elapsed = monotonic_now - read_start

        # If read_probe failed, we still want a verify pass for the report.
        verify_elapsed_start = monotonic_now
        verify_result = verify_probe(model)
        verify_elapsed = monotonic_now - verify_elapsed_start

        # B0-03: exact STRING equality (not just byte count equality).
        exact_string_equal = raw_read[:ok] && (raw_read[:payload] == payload)
        # Kept as a separate field for backwards-compatible display.
        exact_byte_count_equal = raw_read[:ok] &&
                                 raw_read[:actual_string_bytes].to_i == payload.bytesize

        row = {
          level_index:             idx,
          requested_bytes:         bytes,
          actual_json_bytes:       payload.bytesize,
          generation_time_s:       gen_elapsed,
          write_time_s:            write_elapsed,
          read_time_s:             read_elapsed,
          verify_time_s:           verify_elapsed,
          write_ok:                write_result[:ok],
          read_ok:                 raw_read[:ok],
          verify_ok:               verify_result[:ok],
          # B0-03: primary success predicate for the size ladder.
          exact_string_equal:      exact_string_equal,
          # B0-03: kept as a diagnostic field only; NOT a success predicate.
          exact_byte_count_equal:  exact_byte_count_equal,
          json_parse_ok:           verify_result[:ok] ? verify_result[:json_parse_ok] : false,
          digest_before_write:     sha256_hex(payload),
          digest_after_read:       verify_result[:ok] ? verify_result[:recomputed_digest] : nil,
          digest_equality:         verify_result[:ok] ? (verify_result[:digest] == verify_result[:recomputed_digest]) : false,
          schema:                  verify_result[:ok] ? verify_result[:schema] : nil,
          seed:                    seed,
        }
        results << row
        print_size_ladder_row(row)
      end
      results
    end

    # Run the immediate readback test on a single target size.
    #
    # B0-02 fix: the previous implementation compared `payload` against
    # `read_result[:payload]` where `read_result` came from `verify_probe`.
    # `verify_probe` does NOT return `:payload` (only digest + parse
    # evidence), so the comparison was always against `nil` and
    # `exact_byte_equal` was always false. The fix uses `read_probe`
    # directly for the raw payload string equality and `verify_probe`
    # separately for JSON / digest verification. Success requires
    # `exact_string_equal == true`.
    def self.run_immediate_readback_test(model, target_bytes:)
      return { ok: false, reason: 'sketchup_unavailable' } unless sketchup_available?
      return { ok: false, reason: 'nil_model' } if model.nil?
      seed = 0x1_9B0_1000
      payload = generate_payload(seed: seed, target_bytes: target_bytes)
      write_result = write_probe(model, payload,
                                 seed: seed, requested_bytes: target_bytes)
      # Raw read for exact-string equality (B0-02).
      raw_read    = read_probe(model)
      # Verify read for JSON / digest evidence.
      verify_read = verify_probe(model)

      # B0-02: exact STRING equality is the primary success predicate.
      exact_string_equal = raw_read[:ok] && (raw_read[:payload] == payload)
      # Kept as a separate diagnostic field (NOT a success predicate).
      exact_byte_count_equal = raw_read[:ok] &&
                               raw_read[:actual_string_bytes].to_i == payload.bytesize

      row = {
        ok:                     write_result[:ok] && raw_read[:ok] && verify_read[:ok] && exact_string_equal,
        requested_bytes:        target_bytes,
        actual_json_bytes:      payload.bytesize,
        write_ok:               write_result[:ok],
        read_ok:                raw_read[:ok],
        verify_ok:              verify_read[:ok],
        # B0-02: primary success field.
        exact_string_equal:     exact_string_equal,
        # Diagnostic only.
        exact_byte_count_equal: exact_byte_count_equal,
        json_parse_ok:          verify_read[:ok] ? verify_read[:json_parse_ok] : false,
        digest_before:          sha256_hex(payload),
        digest_after:           verify_read[:ok] ? verify_read[:recomputed_digest] : nil,
        digest_equality:        verify_read[:ok] ? (verify_read[:digest] == verify_read[:recomputed_digest]) : false,
      }
      puts "[immediate_readback] #{row.inspect}"
      row
    end

    # Replacement test: write payload A, verify A; replace the same probe
    # slot with payload B (different seed); verify B; prove old A is no
    # longer active (old A's digest MUST NOT match the stored digest).
    def self.run_replacement_test(model, target_bytes:)
      return { ok: false, reason: 'sketchup_unavailable' } unless sketchup_available?
      return { ok: false, reason: 'nil_model' } if model.nil?

      seed_a = 0x1_9B0_2001
      seed_b = 0x1_9B0_2002
      payload_a = generate_payload(seed: seed_a, target_bytes: target_bytes)
      payload_b = generate_payload(seed: seed_b, target_bytes: target_bytes)
      digest_a  = sha256_hex(payload_a)
      digest_b  = sha256_hex(payload_b)

      write_a = write_probe(model, payload_a, seed: seed_a, requested_bytes: target_bytes)
      verify_a = verify_probe(model)

      write_b = write_probe(model, payload_b, seed: seed_b, requested_bytes: target_bytes)
      verify_b = verify_probe(model)

      old_a_still_active =
        verify_b[:ok] && verify_b[:digest] == digest_a

      row = {
        ok:                     write_a[:ok] && verify_a[:ok] && write_b[:ok] && verify_b[:ok] && !old_a_still_active,
        payload_a_digest:       digest_a,
        payload_b_digest:       digest_b,
        verify_a_ok:            verify_a[:ok],
        verify_b_ok:            verify_b[:ok],
        verify_b_digest:        verify_b[:ok] ? verify_b[:digest] : nil,
        verify_b_recomputed:    verify_b[:ok] ? verify_b[:recomputed_digest] : nil,
        old_a_still_active:     old_a_still_active,
        active_payload_is_b:    verify_b[:ok] && verify_b[:digest] == digest_b,
      }
      puts "[replacement] #{row.inspect}"
      row
    end

    # Corrupt / missing test matrix. Exercises:
    #   - payload missing (delete_key)
    #   - digest missing (delete_key)
    #   - invalid JSON (set payload to "{not json")
    #   - digest mismatch (set payload to a different value while keeping the old digest)
    #   - unsupported probe schema marker (set KEY_SCHEMA to "v19b0_probe_v9")
    # All cases must return a fail-closed status, no exception escapes for
    # any of these expected corrupt-storage conditions.
    def self.run_corrupt_missing_tests(model)
      return [{ ok: false, reason: 'sketchup_unavailable' }] unless sketchup_available?
      return [{ ok: false, reason: 'nil_model' }] if model.nil?

      results = []

      # Start each case from a known-good probe write so the model state is
      # consistent across cases. Then apply the targeted corruption.
      baseline_payload = generate_payload(seed: 0x1_9B0_3000, target_bytes: 16 * 1024)
      write_probe(model, baseline_payload, seed: 0x1_9B0_3000, requested_bytes: 16 * 1024)

      dict = model.attribute_dictionary(PROBE_DICTIONARY, true)

      # Case 1: payload missing
      begin
        # B0-01: start_operation(name, disable_ui, transparent) — 3 args max.
        model.start_operation('V1.9B0 probe — corrupt: payload missing', true, false)
        dict.delete_key(KEY_PAYLOAD)
        model.commit_operation
      rescue StandardError
        # B0-01 fix: abort_operation (NOT abort).
        begin; model.abort_operation; rescue StandardError; end
      end
      v = verify_probe(model)
      results << { case: 'payload_missing', ok: !v[:ok] && v[:reason] == 'payload_missing', observed: v }
      puts "[corrupt:payload_missing] ok=#{results.last[:ok]} observed=#{v.inspect}"

      # Restore payload for next case
      write_probe(model, baseline_payload, seed: 0x1_9B0_3000, requested_bytes: 16 * 1024)
      dict = model.attribute_dictionary(PROBE_DICTIONARY, true)

      # Case 2: digest missing
      begin
        model.start_operation('V1.9B0 probe — corrupt: digest missing', true, false)
        dict.delete_key(KEY_DIGEST)
        model.commit_operation
      rescue StandardError
        begin; model.abort_operation; rescue StandardError; end
      end
      v = verify_probe(model)
      results << { case: 'digest_missing', ok: !v[:ok] && v[:reason] == 'digest_missing', observed: v }
      puts "[corrupt:digest_missing] ok=#{results.last[:ok]} observed=#{v.inspect}"

      write_probe(model, baseline_payload, seed: 0x1_9B0_3000, requested_bytes: 16 * 1024)
      dict = model.attribute_dictionary(PROBE_DICTIONARY, true)

      # Case 3: invalid JSON
      begin
        model.start_operation('V1.9B0 probe — corrupt: invalid JSON', true, false)
        dict[KEY_PAYLOAD] = '{this is not valid JSON'
        # Keep digest intentionally stale to also exercise the digest
        # mismatch path that would otherwise be triggered first.
        dict[KEY_DIGEST]  = 'deadbeef' * 8
        model.commit_operation
      rescue StandardError
        begin; model.abort_operation; rescue StandardError; end
      end
      v = verify_probe(model)
      results << { case: 'invalid_json', ok: !v[:ok] && v[:reason] == 'invalid_json', observed: v }
      puts "[corrupt:invalid_json] ok=#{results.last[:ok]} observed=#{v.inspect}"

      write_probe(model, baseline_payload, seed: 0x1_9B0_3000, requested_bytes: 16 * 1024)
      dict = model.attribute_dictionary(PROBE_DICTIONARY, true)

      # Case 4: digest mismatch (payload fresh, digest intentionally stale)
      begin
        model.start_operation('V1.9B0 probe — corrupt: digest mismatch', true, false)
        dict[KEY_PAYLOAD] = JSON.generate({ 'ok' => true, 'note' => 'different payload after restore' })
        dict[KEY_DIGEST]  = 'feedface' * 8
        model.commit_operation
      rescue StandardError
        begin; model.abort_operation; rescue StandardError; end
      end
      v = verify_probe(model)
      results << { case: 'digest_mismatch', ok: !v[:ok] && v[:reason] == 'digest_mismatch', observed: v }
      puts "[corrupt:digest_mismatch] ok=#{results.last[:ok]} observed=#{v.inspect}"

      write_probe(model, baseline_payload, seed: 0x1_9B0_3000, requested_bytes: 16 * 1024)
      dict = model.attribute_dictionary(PROBE_DICTIONARY, true)

      # Case 5: unsupported probe schema marker
      begin
        model.start_operation('V1.9B0 probe — corrupt: unsupported schema', true, false)
        dict[KEY_SCHEMA] = 'v19b0_probe_v9_unsupported'
        model.commit_operation
      rescue StandardError
        begin; model.abort_operation; rescue StandardError; end
      end
      v = verify_probe(model)
      results << { case: 'unsupported_probe_schema', ok: !v[:ok] && v[:reason] == 'unsupported_probe_schema', observed: v }
      puts "[corrupt:unsupported_probe_schema] ok=#{results.last[:ok]} observed=#{v.inspect}"

      # Restore baseline after matrix.
      write_probe(model, baseline_payload, seed: 0x1_9B0_3000, requested_bytes: 16 * 1024)

      results
    end

    # Write a recognizable probe payload in a single SketchUp operation so
    # Owner can call verify_probe before/after manual SketchUp Undo/Redo.
    def self.write_undo_redo_probe(model, payload_string, seed:)
      write_probe(model, payload_string, seed: seed, requested_bytes: payload_string.bytesize)
    end

    # Write a persistent reopen-test payload. Returns the write result and
    # prints PASS / BLOCK style evidence + model path if available.
    def self.write_reopen_test_payload(model, payload_string, seed:)
      r = write_probe(model, payload_string,
                      seed: seed, requested_bytes: payload_string.bytesize)
      path_info =
        begin
          if sketchup_available? && model.respond_to?(:path) && !model.path.nil? && !model.path.to_s.empty?
            { model_path: model.path.to_s }
          else
            { model_path: '(unsaved / no path)' }
          end
        rescue StandardError
          { model_path: '(unavailable)' }
        end
      payload_bytes = payload_string.bytesize
      expected_digest = sha256_hex(payload_string)
      puts "[reopen_test:write] #{({
        write_ok: r[:ok],
        payload_bytes: payload_bytes,
        expected_digest: expected_digest,
        probe_schema: PROBE_SCHEMA_MARKER,
        dictionary: PROBE_DICTIONARY,
        keys: ALL_PROBE_KEYS,
        path_info: path_info,
      }.inspect)}"
      r
    end

    # Verify the persistent reopen-test payload AFTER SketchUp / model
    # reopen. Prints PASS / BLOCK style evidence.
    def self.verify_reopen_test_payload(model)
      v = verify_probe(model)
      path_info =
        begin
          if sketchup_available? && model.respond_to?(:path) && !model.path.nil? && !model.path.to_s.empty?
            { model_path: model.path.to_s }
          else
            { model_path: '(unsaved / no path)' }
          end
        rescue StandardError
          { model_path: '(unavailable)' }
        end
      verdict = v[:ok] ? 'PASS' : 'BLOCK'
      puts "[reopen_test:verify] verdict=#{verdict} observed=#{v.inspect} path_info=#{path_info.inspect}"
      v
    end

    # Print short usage help for the Ruby Console.
    def self.help
      out = []
      out << 'SUAIPlugin::V19B0Probe — V1.9B0 Persistence Feasibility Probe'
      out << "PROBE_DICTIONARY = #{PROBE_DICTIONARY}"
      out << "PROBE_SCHEMA_MARKER = #{PROBE_SCHEMA_MARKER}"
      out << "SIZE_LADDER_BYTES = #{SIZE_LADDER_BYTES.inspect}"
      out << ''
      out << 'Host-free (no SketchUp needed):'
      out << '  SUAIPlugin::V19B0Probe.deterministic_payload_check(seed: 42, target_bytes: 256*1024)'
      out << '  SUAIPlugin::V19B0Probe.json_round_trip(SUAIPlugin::V19B0Probe.generate_payload(seed: 42, target_bytes: 256*1024))'
      out << '  SUAIPlugin::V19B0Probe.sha256_hex("abc")'
      out << ''
      out << 'Inside SketchUp 2020 Ruby Console (after load ...):'
      out << '  m = Sketchup.active_model'
      out << '  SUAIPlugin::V19B0Probe.help'
      out << '  SUAIPlugin::V19B0Probe.run_size_ladder(m)'
      out << '  SUAIPlugin::V19B0Probe.run_size_ladder(m, custom_bytes: [64*1024, 512*1024, 2*1024*1024])'
      out << '  SUAIPlugin::V19B0Probe.run_immediate_readback_test(m, 256*1024)'
      out << '  SUAIPlugin::V19B0Probe.run_replacement_test(m, 256*1024)'
      out << '  SUAIPlugin::V19B0Probe.run_corrupt_missing_tests(m)'
      out << '  SUAIPlugin::V19B0Probe.write_undo_redo_probe(m, SUAIPlugin::V19B0Probe.generate_payload(seed: 99, target_bytes: 256*1024), seed: 99)'
      out << '  # then Undo / Redo manually via SketchUp UI'
      out << '  SUAIPlugin::V19B0Probe.verify_probe(m)'
      out << '  # B0-03 correction: use the largest passing ladder payload'
      out << '  # (default 8 MiB; fall back to 4 MiB / 1 MiB if 8 MiB fails).'
      out << '  SUAIPlugin::V19B0Probe.write_reopen_test_payload(m, SUAIPlugin::V19B0Probe.generate_payload(seed: 7, target_bytes: 8*1024*1024), seed: 7)'
      out << '  # save SKP, close, reopen, then:'
      out << '  SUAIPlugin::V19B0Probe.verify_reopen_test_payload(Sketchup.active_model)'
      out << '  SUAIPlugin::V19B0Probe.cleanup_probe(m)  # always run before final close'
      puts out.join("\n")
    end

    # ----- Internal helpers ---------------------------------------------

    def self.build_nodes_like(seed, count)
      rng = SeededRandom.new(seed ^ 0xA1)
      Array.new(count) do |i|
        {
          'node_id'    => "N#{i.to_s.rjust(6, '0')}",
          'logical_id' => rng.rand(1_000_000),
          'x'          => (rng.rand(200_000) - 100_000) / 1000.0,
          'y'          => (rng.rand(200_000) - 100_000) / 1000.0,
          'z'          => rng.rand(200) / 1000.0,
          'layer_index' => rng.rand(7),
          'flags'      => [],
        }
      end
    end

    def self.build_edges_like(seed, count)
      rng = SeededRandom.new(seed ^ 0xB2)
      Array.new(count) do |i|
        {
          'edge_id'    => "E#{i.to_s.rjust(6, '0')}",
          'start_node' => "N#{rng.rand(64).to_s.rjust(6, '0')}",
          'end_node'   => "N#{rng.rand(64).to_s.rjust(6, '0')}",
          'kind'       => %w[road lot building annotation boundary][rng.rand(5)],
          'length_mm'  => rng.rand(50_000) / 1000.0,
        }
      end
    end

    def self.build_structures_like(seed, count)
      rng = SeededRandom.new(seed ^ 0xC3)
      Array.new(count) do |i|
        {
          'structure_id'   => "S#{i.to_s.rjust(4, '0')}",
          'kind'           => %w[loop region chain][rng.rand(3)],
          'edge_count'     => rng.rand(40) + 4,
          'closed'         => rng.rand(2) == 1,
          'unresolved_flags'=> [],
        }
      end
    end

    def self.build_warnings_like(seed, count)
      rng = SeededRandom.new(seed ^ 0xD4)
      kinds = %w[
        short_edge non_planar_loop open_chain unresolved_layer
        nested_too_deep unknown_cad_kind missing_attribute
        duplicate_candidate ambiguous_repair gap_oversize
        z_drift tolerance_violation
      ]
      Array.new(count) do |i|
        {
          'warning_id' => "W#{i.to_s.rjust(5, '0')}",
          'kind'       => kinds[rng.rand(kinds.length)],
          'severity'   => %w[info warn block][rng.rand(3)],
          'message'    => "synthetic probe warning #{i} for seed #{seed}",
        }
      end
    end

    # Monotonic time in fractional seconds. Uses Process.clock_gettime when
    # available (Ruby 2.1+); falls back to Time.now.
    def self.monotonic_now
      if Process.respond_to?(:clock_gettime)
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      else
        Time.now.to_f
      end
    end

    def self.print_size_ladder_row(row)
      puts "[size_ladder:level_#{row[:level_index]}] " \
           "requested=#{row[:requested_bytes]}B " \
           "actual=#{row[:actual_json_bytes]}B " \
           "write=#{format('%.4f', row[:write_time_s])}s " \
           "read=#{format('%.4f', row[:read_time_s])}s " \
           "verify=#{format('%.4f', row[:verify_time_s])}s " \
           "write_ok=#{row[:write_ok]} read_ok=#{row[:read_ok]} verify_ok=#{row[:verify_ok]} " \
           "exact_string_equal=#{row[:exact_string_equal]} " \
           "exact_byte_count_equal=#{row[:exact_byte_count_equal]} " \
           "json_parse_ok=#{row[:json_parse_ok]} " \
           "digest_equality=#{row[:digest_equality]} " \
           "digest_before=#{row[:digest_before_write]} " \
           "digest_after=#{row[:digest_after_read]}"
    end

    # ----- SeededRandom (pure-ruby, host-independent, deterministic) -----
    # Park-Miller LCG: x_{n+1} = a*x_n mod m. Cross-host deterministic so
    # the probe can be regenerated identically on any Ruby host.
    class SeededRandom
      A = 48_271
      Q = 44_488
      R = 33_966
      M = 2_147_483_647

      def initialize(seed)
        s = seed.to_i.abs
        @state = (s == 0 ? 1 : s) % M
      end

      def rand(limit = nil)
        if limit.nil?
          hi  = @state / Q
          lo  = @state % Q
          test = (A * lo) - (R * hi)
          @state = test.positive? ? test : test + M
          @state.to_f / M
        elsif limit.is_a?(Integer)
          hi  = @state / Q
          lo  = @state % Q
          test = (A * lo) - (R * hi)
          @state = test.positive? ? test : test + M
          @state % limit
        elsif limit.is_a?(Float)
          hi  = @state / Q
          lo  = @state % Q
          test = (A * lo) - (R * hi)
          @state = test.positive? ? test : test + M
          (@state.to_f / M) * limit
        else
          raise ArgumentError, 'SeededRandom only supports Integer/Float/nil limits'
        end
      end
    end
  end
end

# ----- Probe load banner (host-free + SketchUp) -----------------------------
# Print a short banner so Owner can confirm the probe loaded inside Ruby
# Console (no SketchUp side effect on load). Banner is host-free.
puts "[SUAIPlugin::V19B0Probe] loaded; probe dictionary = " \
     "'#{SUAIPlugin::V19B0Probe::PROBE_DICTIONARY}'; " \
     "schema = '#{SUAIPlugin::V19B0Probe::PROBE_SCHEMA_MARKER}'; " \
     "size ladder = #{SUAIPlugin::V19B0Probe::SIZE_LADDER_BYTES.inspect}"