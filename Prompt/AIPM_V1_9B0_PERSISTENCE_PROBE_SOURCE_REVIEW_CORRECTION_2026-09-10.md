# AIPM — V1.9B0 Persistence Probe Source Review Correction

Project: SU-AI-Plugin
Date: 2026-09-10
Reviewed HEAD: 4d1eeb93a9deacf422ad4aeea5bd0a274cf44c5e
Status: FIX REQUIRED — probe-only correction
V1.9A: CLOSED_FROZEN
V1.9B1: NOT STARTED

## BLOCK B0-01 — SketchUp operation API contract
In `Probe/V1_9B0/prepared_dataset_persistence_probe.rb`, calls such as:
`model.start_operation(name, true, false, DEFAULT_OP_DESC)` are wrong because SketchUp's fourth argument is the Boolean `transparent` flag, not a description string. Ruby strings are truthy, so these calls create transparent operations. Use `model.start_operation(name, true)` or explicit `..., false, false`.

All rescue paths must use `model.abort_operation`, not `model.abort`. If failure occurs after start_operation and before commit, abort the operation before returning. Add FakeModel tests proving one start/one commit on success, one start/one abort_operation on injected failure, and no `abort` call.

## BLOCK B0-02 — immediate readback false negative
`run_immediate_readback_test` compares the original payload against `read_result[:payload]`, but `verify_probe` success does not return `:payload`. Therefore exact equality is always false.

Fix by using `raw_read = read_probe(model)` for raw string comparison and `verify_probe(model)` separately for JSON/digest verification. Require `exact_string_equal == true` for success.

## BLOCK B0-03 — size ladder does not prove exact string equality
Current `exact_byte_equal` checks only equal byte count, not equal payload content. The probe contract requires direct exact string equality in addition to JSON parse and SHA-256 verification.

For each ladder level, use `read_probe` to compare `raw_read[:payload] == payload`; keep byte count, parse status, digest equality, write/read timings as separate fields. Add a same-length-but-altered-payload regression proving equality fails.

## Owner test plan correction
The save/close/reopen example should not stop at 64 KiB. Run the 256 KiB / 1 MiB / 4 MiB / 8 MiB ladder, then perform save-close-reopen using the largest passing payload (preferably 8 MiB), record reopen verification and latency, then cleanup.

## Allowed scope
Only:
- Probe/V1_9B0/prepared_dataset_persistence_probe.rb
- Probe/V1_9B0/README.md
- Probe/V1_9B0/_validation_runner.rb
- docs status files if needed

Do NOT modify extension/, production tests, dist RBZ, V1.9A closure, or begin V1.9B1.

After fix: ruby -c, updated host-free validation, git diff --check, confirm extension/ and tests/ unchanged, commit/push dev/v1.9, STOP.

Return:
V1_9A = CLOSED_FROZEN
V1_9B0_IMPLEMENTATION = COMPLETE_PENDING_AIPM_RECHECK
OWNER_SU2020_PERSISTENCE_PROBE = BLOCKED_BY_PROBE_FIX
PERSISTENCE_ROUTE = NOT_YET_FROZEN
V1_9B1 = NOT_STARTED
