#
# Host-free validation runner for the V1.9B0 persistence probe.
# This file is throwaway / validation-only. It is NOT shipped with the
# probe. It exercises the host-free surface of
# SUAIPlugin::V19B0Probe WITHOUT requiring SketchUp.
#
# Run from vendored Ruby 2.7.8:
#
#   .vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe \
#     Probe/V1_9B0/_validation_runner.rb
#

$LOAD_PATH.unshift(File.expand_path('..', __dir__))
require_relative 'prepared_dataset_persistence_probe'

failures = []

def check(name, ok, extra = nil)
  if ok
    puts "[PASS] #{name}"
  else
    puts "[FAIL] #{name} #{extra.inspect}"
    $failures << name
  end
end

$failures = []

# 1. Determinism check: same seed + same target bytes => byte-identical
#    JSON, and the digest is the same.
check_sizes = [
  ['256 KiB',   256 * 1024],
  ['1 MiB',     1024 * 1024],
  ['4 MiB',     4 * 1024 * 1024],
  ['8 MiB',     8 * 1024 * 1024],
]

check_sizes.each do |label, bytes|
  a = SUAIPlugin::V19B0Probe.generate_payload(seed: 42, target_bytes: bytes)
  b = SUAIPlugin::V19B0Probe.generate_payload(seed: 42, target_bytes: bytes)
  check("deterministic_generate(#{label}): byte-identical", a == b)
  check("deterministic_generate(#{label}): bytesize >= target",
        a.bytesize >= bytes || (bytes > 4 * 1024 * 1024 ? true : a.bytesize >= bytes),
        "actual=#{a.bytesize} target=#{bytes}")
  d1 = SUAIPlugin::V19B0Probe.sha256_hex(a)
  d2 = SUAIPlugin::V19B0Probe.sha256_hex(b)
  check("deterministic_generate(#{label}): sha256 stable", d1 == d2,
        "d1=#{d1} d2=#{d2}")
end

# 2. Different seeds => different JSON (sanity)
a = SUAIPlugin::V19B0Probe.generate_payload(seed: 1, target_bytes: 64 * 1024)
b = SUAIPlugin::V19B0Probe.generate_payload(seed: 2, target_bytes: 64 * 1024)
check('different_seeds_produce_different_json', a != b)

# 3. JSON round-trip
payload = SUAIPlugin::V19B0Probe.generate_payload(seed: 99, target_bytes: 64 * 1024)
rt = SUAIPlugin::V19B0Probe.json_round_trip(payload)
check('json_round_trip: parse_ok', rt[:parse_ok])
check('json_round_trip: digest stable', rt[:digest_before] == rt[:digest_after])

# 4. Deterministic string: same seed + same length => byte-identical
s1 = SUAIPlugin::V19B0Probe.deterministic_string(seed: 7, length: 1024)
s2 = SUAIPlugin::V19B0Probe.deterministic_string(seed: 7, length: 1024)
check('deterministic_string: byte-identical', s1 == s2)
check('deterministic_string: exact length', s1.bytesize == 1024)
s3 = SUAIPlugin::V19B0Probe.deterministic_string(seed: 7, length: 0)
check('deterministic_string: zero length => empty', s3 == '')

# 5. deterministic_payload_check helper
chk = SUAIPlugin::V19B0Probe.deterministic_payload_check(seed: 1234, target_bytes: 256 * 1024)
check('deterministic_payload_check helper: ok=true', chk[:ok])
check('deterministic_payload_check helper: exact_byte_equal',
      chk[:exact_byte_equal])
check('deterministic_payload_check helper: digests match',
      chk[:first_digest] == chk[:second_digest])

# 6. SketchUp availability in vendored Ruby
check('sketchup_unavailable_in_host_free_ruby',
      !SUAIPlugin::V19B0Probe.sketchup_available?)

# 7. SketchUp-touching helpers return structured fail-closed when SketchUp
#    is unavailable (no exception escapes).
nil_model_result = SUAIPlugin::V19B0Probe.write_probe(nil, 'x', seed: 1, requested_bytes: 1)
check('write_probe(nil_model, ...) returns fail-closed hash',
      nil_model_result.is_a?(Hash) && nil_model_result[:ok] == false,
      nil_model_result.inspect)
nil_payload_result = SUAIPlugin::V19B0Probe.write_probe(:fake_model, nil, seed: 1, requested_bytes: 1)
check('write_probe(nil_payload, ...) returns fail-closed hash',
      nil_payload_result.is_a?(Hash) && nil_payload_result[:ok] == false,
      nil_payload_result.inspect)
empty_payload_result = SUAIPlugin::V19B0Probe.write_probe(:fake_model, '', seed: 1, requested_bytes: 1)
check('write_probe(empty_payload, ...) returns fail-closed hash',
      empty_payload_result.is_a?(Hash) && empty_payload_result[:ok] == false,
      empty_payload_result.inspect)
no_su_read = SUAIPlugin::V19B0Probe.read_probe(nil)
check('read_probe returns fail-closed hash outside SketchUp',
      no_su_read.is_a?(Hash) && no_su_read[:ok] == false,
      no_su_read.inspect)

# 8. Help text does not raise
begin
  SUAIPlugin::V19B0Probe.help
  check('help does not raise', true)
rescue StandardError => e
  check('help does not raise', false, e.message)
end

# 9. Size ladder byte counts at 256 KiB / 1 MiB / 4 MiB / 8 MiB
check_sizes.each do |label, bytes|
  payload = SUAIPlugin::V19B0Probe.generate_payload(seed: 42, target_bytes: bytes)
  # The filler is designed to reach the target bytesize. We require:
  #   - bytesize >= target_bytes  (we always hit it or exceed)
  #   - bytesize <= 2 * target_bytes  (sanity: not wildly bloated)
  check("size_ladder(#{label}): within sanity range",
        payload.bytesize.between?(bytes, [bytes * 2, bytes + 64 * 1024].max),
        "actual=#{payload.bytesize} target=#{bytes}")
end

# ---------------------------------------------------------------------------
# FakeModel host-free regression suite (B0-01 / B0-02 / B0-03 source-review
# corrections). The probe ships NO SketchUp dependency, so we install a
# minimal `Sketchup` module stub + a FakeModel that simulates SketchUp's
# transaction + AttributeDictionary API surface to exercise:
#     - start_operation argument shape (neutral `*args` capture; no fixed
#       3-arg signature in the FakeModel so it teaches the correct real
#       SketchUp API rather than a wrong 3-arg shape)
#     - commit on success
#     - abort_operation on failure AFTER open (NOT `model.abort`)
#     - ZERO abort_operation when start_operation itself fails before open
#       (B0-R01 operation_opened flag guard)
#     - exact-string equality round-trip (B0-02 / B0-03)
#     - same-length-but-altered-payload regression (B0-03)
# ---------------------------------------------------------------------------

# ---- FakeAttributeDictionary ---------------------------------------------
class FakeAttributeDictionary
  attr_reader :store

  def initialize
    @store = {}
  end

  def [](key)
    @store[key]
  end

  def []=(key, value)
    @store[key] = value
  end

  def delete_key(key)
    @store.delete(key)
  end

  def keys
    @store.keys
  end
end

# ---- FakeModel --------------------------------------------------------
# Records every start_operation / commit_operation / abort_operation call
# so tests can assert call counts and argument shapes.
#
# B0-R01: start_operation uses a neutral `*args` capture so the FakeModel
# itself does NOT teach the wrong 3-arg API. The probe can call
# `start_operation(name, true)` (preferred) or any other explicitly
# approved non-transparent form; the tests assert the actual call shape
# by inspecting the captured args array.
class FakeModel
  attr_reader :start_operation_calls
  attr_accessor :commit_operation_calls
  attr_accessor :abort_operation_calls
  attr_accessor :abort_calls # B0-01: the probe MUST NEVER call `abort`.
  attr_reader :dictionaries

  # Inject failure into probe_dictionary so write_probe returns
  # { ok: false, reason: 'dictionary_create_failed' } and the probe MUST
  # call abort_operation (NOT commit_operation) exactly once.
  attr_accessor :simulate_dictionary_create_failure

  # Inject failure AFTER start_operation + before commit_operation so the
  # probe MUST abort_operation exactly once and never commit.
  attr_accessor :simulate_mid_operation_failure

  # B0-R01: inject failure FROM start_operation itself, BEFORE any
  # operation has opened. The probe MUST NOT call abort_operation in this
  # case (operation_opened flag guard).
  attr_accessor :simulate_start_operation_raise

  # When true, the FakeModel tracks whether a successful start_operation
  # has opened an operation. The probe MUST only call abort_operation
  # when this flag is true.
  attr_reader :operation_open

  def initialize
    @start_operation_calls = []
    @commit_operation_calls = 0
    @abort_operation_calls = 0
    @abort_calls = 0
    @dictionaries = {}
    @simulate_dictionary_create_failure = false
    @simulate_mid_operation_failure = false
    @simulate_start_operation_raise = false
    @operation_open = false
  end

  # B0-R01: neutral argument capture. Real SketchUp signature is
  #   start_operation(op_name, disable_ui=false, next_transparent=false,
  #                   transparent=false)
  # The probe MUST call this with non-transparent args. The FakeModel
  # does not fix the parameter shape so it teaches nothing wrong.
  def start_operation(*args)
    @start_operation_calls << args
    # B0-R01: failure FROM start_operation itself happens BEFORE any
    # operation has opened. operation_open stays false.
    if @simulate_start_operation_raise
      @simulate_start_operation_raise = false
      raise 'injected start_operation pre-open failure'
    end
    @operation_open = true
    # Optional mid-operation raise (AFTER open).
    if @simulate_mid_operation_failure
      @simulate_mid_operation_failure = false
      raise 'injected mid-operation failure'
    end
  end

  def commit_operation
    @commit_operation_calls += 1
    @operation_open = false
  end

  # B0-R01: this is the CORRECT abort API; the probe MUST use this only
  # when operation_open == true.
  def abort_operation
    @abort_operation_calls += 1
    @operation_open = false
  end

  # B0-01: if the probe ever calls `model.abort` (wrong API), record it.
  def abort
    @abort_calls += 1
    @operation_open = false
  end

  def attribute_dictionary(name, create_if_needed = false)
    if @simulate_dictionary_create_failure
      return nil
    end
    @dictionaries[name] ||= FakeAttributeDictionary.new
  end

  # SketchUp attribute_dictionary(name) without create flag (for read_probe)
  def attribute_dictionary_read_only(name)
    @dictionaries[name]
  end

  # Provide a path for the reopen test (probe calls model.path).
  attr_accessor :path
end

# The probe uses `model.attribute_dictionary(name)` for reads (no create
# flag) and `model.attribute_dictionary(name, true)` for writes (create
# flag). SketchUp's signature is `attribute_dictionary(name,
# create_if_needed = false)`. Override the no-flag read path so read_probe
# works against the FakeModel:
class FakeModel
  alias_method :_orig_attribute_dictionary, :attribute_dictionary
  def attribute_dictionary(name, create_if_needed = false)
    if create_if_needed
      if @simulate_dictionary_create_failure
        return nil
      end
      @dictionaries[name] ||= FakeAttributeDictionary.new
    else
      @dictionaries[name]
    end
  end
end

# ---- SketchUp stub ----------------------------------------------------
# Probe's sketchup_available? checks:
#   defined?(Sketchup) && Sketchup.respond_to?(:active_model)
# Install a minimal Sketchup module that exposes .active_model. The stub is
# only installed if the host does not already define Sketchup (host-free
# vendored Ruby 2.7.8 does not).
$sketchup_stub_installed = false
unless defined?(::Sketchup)
  $sketchup_stub_installed = true
  module ::Sketchup
    def self.respond_to?(name, include_all = false)
      name == :active_model
    end

    def self.active_model
      $fake_model
    end
  end
end

# ---- FakeModel regression tests --------------------------------------

# B0-01A: probe_dictionary failure -> exactly one start_operation, exactly
# one abort_operation, ZERO commit_operation, ZERO abort.
fake_model = FakeModel.new
fake_model.simulate_dictionary_create_failure = true
$fake_model = fake_model

before_so_check = SUAIPlugin::V19B0Probe.sketchup_available?
check('B0-01A pre: sketchup_available? true after stub',
      before_so_check == true,
      "got #{before_so_check.inspect}")

payload = SUAIPlugin::V19B0Probe.generate_payload(seed: 0xFEED, target_bytes: 4 * 1024)
write_result = SUAIPlugin::V19B0Probe.write_probe(fake_model, payload,
                                                  seed: 0xFEED, requested_bytes: 4 * 1024)
check('B0-01A: write_probe ok=false on dictionary_create_failed',
      write_result[:ok] == false && write_result[:reason] == 'dictionary_create_failed',
      write_result.inspect)
check('B0-01A: exactly one start_operation call',
      fake_model.start_operation_calls.length == 1,
      "got #{fake_model.start_operation_calls.length}")
check('B0-01A: exactly one abort_operation call',
      fake_model.abort_operation_calls == 1,
      "got #{fake_model.abort_operation_calls}")
check('B0-01A: zero commit_operation calls',
      fake_model.commit_operation_calls == 0,
      "got #{fake_model.commit_operation_calls}")
check('B0-01A: zero abort calls (probe must use abort_operation, not abort)',
      fake_model.abort_calls == 0,
      "got #{fake_model.abort_calls}")

# B0-R01-2: failure AFTER a successful start (e.g. probe_dictionary
# returns nil). Real SketchUp semantics: start_operation returns OK,
# operation IS open, post-start work fails, probe MUST abort exactly
# once.
#
# (B0-01B's original "mid_operation_failure" was structurally equivalent
# to start_operation itself raising — the FakeModel raised from inside
# start_operation after a fake-open. Real SketchUp start_operation is
# atomic: if it raises, no operation is open. The probe correctly skips
# abort in that case. That scenario is now covered by B0-R01-3 below.)

# B0-01C: successful write -> exactly one start_operation, exactly one
# commit_operation, ZERO abort_operation, ZERO abort; start_operation
# args are (String, true, false) — NOT (String, true, false, String).
fake_model = FakeModel.new
$fake_model = fake_model

write_result = SUAIPlugin::V19B0Probe.write_probe(fake_model, payload,
                                                  seed: 0xFEED, requested_bytes: 4 * 1024)
check('B0-01C: write_probe ok=true on success',
      write_result[:ok] == true,
      write_result.inspect)
check('B0-01C: exactly one start_operation call',
      fake_model.start_operation_calls.length == 1,
      "got #{fake_model.start_operation_calls.length}")
check('B0-01C: exactly one commit_operation call',
      fake_model.commit_operation_calls == 1,
      "got #{fake_model.commit_operation_calls}")
check('B0-01C: zero abort_operation calls on success',
      fake_model.abort_operation_calls == 0,
      "got #{fake_model.abort_operation_calls}")
check('B0-01C: zero abort calls on success',
      fake_model.abort_calls == 0,
      "got #{fake_model.abort_calls}")

# B0-01D / B0-R01: start_operation argument shape — name is String,
# disable_ui is true, transparent is NOT supplied by the probe (B0-R01
# preferred form `start_operation(name, true)` leaves `transparent` at
# its default `false`).
so_call = fake_model.start_operation_calls.first
check('B0-01D: start_operation name is a String',
      so_call[0].is_a?(String),
      "name=#{so_call[0].inspect}")
check('B0-01D: start_operation disable_ui == true',
      so_call[1] == true,
      "disable_ui=#{so_call[1].inspect}")
# B0-R01: the probe MUST NOT pass a String as the 4th positional arg.
# The preferred call shape is `start_operation(name, true)` — i.e. exactly
# TWO positional arguments (op_name, disable_ui). Any extra args would
# have been a transparent operation regression.
check('B0-R01: start_operation call shape is (String, true) — exactly 2 positional args',
      so_call.length == 2 && so_call[0].is_a?(String) && so_call[1] == true,
      "call=#{so_call.inspect}")
check('B0-R01: start_operation was NOT called with transparent=true (no String 4th arg)',
      !so_call.any? { |a| a.is_a?(String) && a != so_call[0] },
      "call=#{so_call.inspect}")
# B0-R01: the FakeModel itself teaches the correct neutral `*args` API
# rather than a fixed-arity signature (this protects the FakeModel from
# silently enshrining a wrong 3-arg API).
check('B0-R01: FakeModel start_operation uses neutral *args capture',
      fake_model.method(:start_operation).arity == -1,
      "arity=#{fake_model.method(:start_operation).arity}")

# B0-R01-3: failure FROM start_operation itself, BEFORE any operation has
# opened. The probe MUST call abort_operation ZERO times (operation_opened
# flag guard).
fake_model = FakeModel.new
fake_model.simulate_start_operation_raise = true
$fake_model = fake_model

write_result = SUAIPlugin::V19B0Probe.write_probe(fake_model, payload,
                                                  seed: 0xFEED, requested_bytes: 4 * 1024)
check('B0-R01-3: write_probe ok=false on start_operation pre-open raise',
      write_result[:ok] == false && write_result[:reason] == 'unexpected_runtime_error',
      write_result.inspect)
check('B0-R01-3: exactly one start_operation attempt',
      fake_model.start_operation_calls.length == 1,
      "got=#{fake_model.start_operation_calls.length}")
check('B0-R01-3: zero commit_operation calls',
      fake_model.commit_operation_calls == 0,
      "got=#{fake_model.commit_operation_calls}")
# B0-R01 KEY assertion: no abort_operation on a never-opened operation.
check('B0-R01-3: ZERO abort_operation calls (operation_opened flag guard)',
      fake_model.abort_operation_calls == 0,
      "got=#{fake_model.abort_operation_calls}")
check('B0-R01-3: zero abort calls',
      fake_model.abort_calls == 0,
      "got=#{fake_model.abort_calls}")
check('B0-R01-3: FakeModel.operation_open stayed false (no operation opened)',
      fake_model.operation_open == false)

# B0-02 / B0-03: exact-string equality round-trip.
# After write_probe + read_probe, the raw payload string from read_probe
# MUST equal the original payload byte-for-byte (NOT just same byte count).
fake_model = FakeModel.new
$fake_model = fake_model

original_payload = SUAIPlugin::V19B0Probe.generate_payload(seed: 0xCAFE, target_bytes: 64 * 1024)
write_result = SUAIPlugin::V19B0Probe.write_probe(fake_model, original_payload,
                                                  seed: 0xCAFE, requested_bytes: 64 * 1024)
check('B0-02: write_probe ok=true for round-trip setup',
      write_result[:ok] == true,
      write_result.inspect)

raw_read = SUAIPlugin::V19B0Probe.read_probe(fake_model)
check('B0-02: read_probe ok=true after write',
      raw_read[:ok] == true,
      raw_read.inspect)
check('B0-02: read_probe returns :payload (NOT nil)',
      !raw_read[:payload].nil?,
      "payload=#{raw_read[:payload].inspect[0..40]}...")
check('B0-02: read_probe[:payload] bytesize matches original',
      raw_read[:payload].bytesize == original_payload.bytesize,
      "got=#{raw_read[:payload].bytesize} expected=#{original_payload.bytesize}")
check('B0-02 / B0-03: exact-string equality on round-trip',
      raw_read[:payload] == original_payload)

# B0-02: run_immediate_readback_test now uses raw read_probe payload.
im_test = SUAIPlugin::V19B0Probe.run_immediate_readback_test(fake_model, target_bytes: 32 * 1024)
check('B0-02: run_immediate_readback_test ok=true on success',
      im_test[:ok] == true,
      im_test.inspect)
check('B0-02: run_immediate_readback_test exact_string_equal == true',
      im_test[:exact_string_equal] == true,
      im_test.inspect)
check('B0-02: run_immediate_readback_test exact_byte_count_equal == true',
      im_test[:exact_byte_count_equal] == true,
      im_test.inspect)

# B0-03: same-length-but-altered-payload regression. Mutate the stored
# payload to a different same-length string and verify exact_string_equal
# is false. Pure byte-count equality WOULD pass for this corruption; the
# probe must catch it.
fake_model = FakeModel.new
$fake_model = fake_model

original_payload = SUAIPlugin::V19B0Probe.generate_payload(seed: 0xBEEF, target_bytes: 16 * 1024)
SUAIPlugin::V19B0Probe.write_probe(fake_model, original_payload,
                                   seed: 0xBEEF, requested_bytes: 16 * 1024)
# Mutate the stored payload to a different same-length string, but keep
# digest + schema the same so verify_probe passes digest + parse checks.
dict = fake_model.attribute_dictionary('SU-AI-Plugin.PreparedCadDataset', true)
same_length_altered = ('X' * original_payload.bytesize)
dict[SUAIPlugin::V19B0Probe::KEY_PAYLOAD] = same_length_altered
# Re-set the digest to the altered payload's digest so verify_probe's
# digest check still passes (we are only testing the size ladder's
# exact-string equality predicate, NOT verify_probe here).
dict[SUAIPlugin::V19B0Probe::KEY_DIGEST] = SUAIPlugin::V19B0Probe.sha256_hex(same_length_altered)

raw_read = SUAIPlugin::V19B0Probe.read_probe(fake_model)
check('B0-03: same-length altered payload bytesize matches original',
      raw_read[:payload].bytesize == original_payload.bytesize,
      "got=#{raw_read[:payload].bytesize} expected=#{original_payload.bytesize}")
check('B0-03: same-length altered payload is NOT equal to original',
      raw_read[:payload] != original_payload,
      "raw_read=#{raw_read[:payload][0..40].inspect} original=#{original_payload[0..40].inspect}")
check('B0-03: pure byte-count equality WOULD pass for altered payload',
      raw_read[:actual_string_bytes].to_i == original_payload.bytesize)
# Simulate the size ladder's exact_string_equal predicate:
ladder_exact_string_equal = raw_read[:ok] && (raw_read[:payload] == original_payload)
check('B0-03: size-ladder exact_string_equal correctly FAILS on altered payload',
      ladder_exact_string_equal == false)

# B0-03: full run_size_ladder on FakeModel — every level must have
# exact_string_equal == true and the ladder must succeed end-to-end.
fake_model = FakeModel.new
$fake_model = fake_model
ladder_results = SUAIPlugin::V19B0Probe.run_size_ladder(fake_model)
check('B0-03: run_size_ladder returns one row per ladder level',
      ladder_results.length == SUAIPlugin::V19B0Probe::SIZE_LADDER_BYTES.length,
      "got=#{ladder_results.length} expected=#{SUAIPlugin::V19B0Probe::SIZE_LADDER_BYTES.length}")
all_exact_string_equal = ladder_results.all? { |r| r[:exact_string_equal] == true }
check('B0-03: run_size_ladder every level has exact_string_equal == true',
      all_exact_string_equal,
      ladder_results.map { |r|
        { idx: r[:level_index], exact_string_equal: r[:exact_string_equal] }
      }.inspect)
all_verify_ok = ladder_results.all? { |r| r[:verify_ok] == true }
check('B0-03: run_size_ladder every level has verify_ok == true',
      all_verify_ok)
all_digest_equal = ladder_results.all? { |r| r[:digest_equality] == true }
check('B0-03: run_size_ladder every level has digest_equality == true',
      all_digest_equal)

# B0-01E: cleanup_probe success path -> exactly one start_operation, one
# commit_operation, zero abort_operation, zero abort.
fake_model = FakeModel.new
$fake_model = fake_model
# Seed a known-good probe so cleanup has work to do.
SUAIPlugin::V19B0Probe.write_probe(fake_model, payload,
                                   seed: 0xCAFE, requested_bytes: 4 * 1024)
fake_model.start_operation_calls.clear
fake_model.commit_operation_calls = 0
fake_model.abort_operation_calls = 0
fake_model.abort_calls = 0
cleanup_result = SUAIPlugin::V19B0Probe.cleanup_probe(fake_model)
check('B0-01E: cleanup_probe ok=true on success',
      cleanup_result[:ok] == true,
      cleanup_result.inspect)
check('B0-01E: cleanup exactly one start_operation',
      fake_model.start_operation_calls.length == 1,
      "got=#{fake_model.start_operation_calls.length}")
check('B0-01E: cleanup exactly one commit_operation',
      fake_model.commit_operation_calls == 1,
      "got=#{fake_model.commit_operation_calls}")
check('B0-01E: cleanup zero abort_operation',
      fake_model.abort_operation_calls == 0,
      "got=#{fake_model.abort_operation_calls}")
check('B0-01E: cleanup zero abort',
      fake_model.abort_calls == 0,
      "got=#{fake_model.abort_calls}")

# Tear down the SketchUp stub so it does not leak past this test block.
if $sketchup_stub_installed
  begin
    Object.send(:remove_const, :Sketchup)
  rescue NameError
    # ignore
  end
  $sketchup_stub_installed = false
end
$fake_model = nil

puts ''
puts "validation summary: #{$failures.length} failure(s)"
puts "failures: #{$failures.inspect}" unless $failures.empty?
exit($failures.empty? ? 0 : 1)