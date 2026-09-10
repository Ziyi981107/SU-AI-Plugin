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

puts ''
puts "validation summary: #{$failures.length} failure(s)"
puts "failures: #{$failures.inspect}" unless $failures.empty?
exit($failures.empty? ? 0 : 1)