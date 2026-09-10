# AIPM — V1.9B0 PERSISTENCE PROBE FINAL NARROW RESIDUAL CORRECTION

Project: `SU-AI-Plugin`  
Date: 2026-09-10  
Reviewed HEAD: `ab6362ce36454a0eb7e78d87ba11c8893a0e2e18`  
Status: **FIX REQUIRED — ONE NARROW PROBE RESIDUAL**  
V1.9A: **CLOSED_FROZEN**  
V1.9B1: **NOT STARTED**

## Owner summary

Pi materially fixed B0-01 / B0-02 / B0-03. Exact-string readback and size-ladder logic now follow the intended contract.

One transaction-safety residual remains before Owner real-SU2020 testing: the probe/tests document the SketchUp `start_operation` signature incorrectly and the rescue path can call `abort_operation` even when `start_operation` itself failed before an operation opened.

This is probe-only. Do not touch `extension/`, production tests, RBZ, V1.9A, or V1.9B1.

---

## BLOCK B0-R01 — Correct SketchUp operation signature + abort only if opened

### Official API contract

SketchUp Model API:

```text
start_operation(op_name,
                disable_ui = false,
                next_transparent = false,
                transparent = false)
```

The third argument is deprecated `next_transparent`.  
The fourth argument is `transparent`.

Therefore the prior four-argument call with a String in argument 4 was NOT ignored. The String was truthy and was being supplied as `transparent`.

The current implementation's three-argument call:

```ruby
model.start_operation(name, true, false)
```

happens to remain non-transparent because argument 3 is `false` and argument 4 defaults to `false`, but the source comments and FakeModel contract incorrectly describe the real API as a three-argument `(name, disable_ui, transparent)` API.

### Required call form

Prefer the simplest unambiguous normal operation:

```ruby
model.start_operation(name, true)
```

This leaves both `next_transparent` and `transparent` at their default `false`.

Do not use transparent operations for this probe.

### Required open-state guard

Current `write_probe` rescue unconditionally calls:

```ruby
model.abort_operation
```

even if `model.start_operation(...)` itself raised before an operation opened.

The previous AIPM correction explicitly requires: **do not abort an operation that was never opened**.

Use a local flag, for example:

```ruby
operation_opened = false

begin
  model.start_operation(name, true)
  operation_opened = true

  # work...

  model.commit_operation
  operation_opened = false
rescue StandardError => e
  if operation_opened
    begin
      model.abort_operation
    rescue StandardError
      # secondary abort failure is reported/contained as appropriate
    end
    operation_opened = false
  end

  # return existing structured runtime failure
end
```

For an explicit failure after opening but before commit (e.g. dictionary creation fails), abort once and clear the flag.

Apply the same principle to probe-owned transaction helpers where rescue can be reached from `start_operation` itself.

Do NOT introduce a new transaction architecture/helper unless necessary. Smallest local correction wins.

---

## FakeModel regression correction

The current FakeModel wrongly defines:

```ruby
start_operation(name, disable_ui, transparent)
```

and therefore teaches the wrong SketchUp API.

Replace it with a neutral argument-capturing seam, e.g.:

```ruby
def start_operation(*args)
  @start_operation_calls << args
  ...
end
```

Required tests:

1. Normal successful write:
   - actual call is `start_operation(name, true)` (preferred), or another explicitly approved non-transparent form;
   - one start;
   - one commit;
   - zero abort.

2. Failure AFTER a successful start:
   - one start;
   - zero commit;
   - one `abort_operation`.

3. Failure FROM `start_operation` itself, before open:
   - one attempted start;
   - zero commit;
   - **zero `abort_operation`**.

4. No probe source call to `model.abort`.

5. Comments/README must state the real four-parameter SketchUp API accurately.

---

## PASS / preserve from previous correction

Do not reopen:

- B0-02 raw `read_probe` exact-string comparison;
- B0-03 `exact_string_equal`;
- separate `exact_byte_count_equal` diagnostic;
- SHA-256 verification;
- 256 KiB / 1 MiB / 4 MiB / 8 MiB ladder;
- largest-passing-payload reopen plan;
- replacement test;
- corrupt/missing semantics;
- deterministic payload generator;
- probe namespace.

---

## Optional Owner-evidence improvement while README is touched

After reopen, add a direct deterministic exact-string check against a regenerated expected payload, e.g. for the 8 MiB / seed 7 case:

```ruby
expected = SUAIPlugin::V19B0Probe.generate_payload(
  seed: 7,
  target_bytes: 8 * 1024 * 1024
)
raw = SUAIPlugin::V19B0Probe.read_probe(Sketchup.active_model)
raw[:ok] && raw[:payload] == expected
```

This gives independent exact-content evidence in addition to stored-digest-vs-recomputed-digest verification.

This README addition is recommended, but no production schema is frozen by it.

---

## Allowed scope

Only:

- `Probe/V1_9B0/prepared_dataset_persistence_probe.rb`
- `Probe/V1_9B0/_validation_runner.rb`
- `Probe/V1_9B0/README.md`
- `CURRENT_STATE.md` / `Review/CURRENT_PI_REPORT.md` if needed

Forbidden:

- `extension/`
- production `tests/`
- `dist/SU-AI-Plugin.rbz`
- V1.9A closure
- V1.9B1 production implementation
- V2 / MCP / LLM / Agent

---

## Return

Run syntax + host-free validation, report exact counts, `git diff --check`, confirm `extension/`, `tests/`, `dist/` unchanged, commit/push `dev/v1.9`, then STOP.

Expected return state:

```text
V1_9A                           = CLOSED_FROZEN
V1_9B0_IMPLEMENTATION           = COMPLETE_PENDING_FINAL_AIPM_RECHECK
OWNER_SU2020_PERSISTENCE_PROBE  = BLOCKED_BY_FINAL_NARROW_FIX
PERSISTENCE_ROUTE               = NOT_YET_FROZEN
V1_9B1                          = NOT_STARTED
```
