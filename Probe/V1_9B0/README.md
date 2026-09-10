# V1.9B0 — PreparedCadDataset Persistence Feasibility Probe

> **Project**: `D:\Projects\SU-AI-Plugin`
> **Stage**: V1.9B0 (probe only — NOT production)
> **Date**: 2026-09-10
> **Authority**: ChatGPT / AIPM
> **Final Product Owner**: Owner
> **Implementation Agent**: Pi

---

## 0. What this probe answers

> Can SketchUp Model AttributeDictionary reliably persist a
> representative future PreparedCadDataset payload at realistic size?

The probe does NOT implement production PreparedCadDataset,
PreparedCadDatasetBuilder, PreparedCadDatasetValidator, acceptance
workflow, or any `extension/` change. V1.9A is frozen at HEAD
`36b8f5b48c8ec2f5a4894db894ca62397344d2fa` on `dev/v1.9`.

---

## 1. Files

- `prepared_dataset_persistence_probe.rb` — the probe itself (single
  file, no external dependencies beyond `json` + `digest` + `time`).
  Loadable directly from SketchUp 2020 Ruby Console. No RBZ install
  required.
- `_validation_runner.rb` — host-free (non-SketchUp) validation
  runner. Executes the deterministic-payload + JSON-round-trip +
  SketchUp-fail-closed checks in vendored Ruby. Throwaway; not
  shipped for Owner use.

---

## 2. Persistence route under test

SketchUp Model AttributeDictionary:

```text
dictionary: SU-AI-Plugin.PreparedCadDataset
```

with probe-namespaced keys (so it can never be confused with a future
production accepted dataset):

```text
__v19b0_probe_payload__
__v19b0_probe_digest__
__v19b0_probe_schema__
__v19b0_probe_seed__
__v19b0_probe_requested_bytes__
__v19b0_probe_actual_bytes__
```

---

## 3. Owner real-SU2020 test sequence (recommended)

Open SketchUp 2020 (version 20.0.363 or compatible).

Step 1 — load the probe from Ruby Console:

```ruby
load 'D:/Projects/SU-AI-Plugin/Probe/V1_9B0/prepared_dataset_persistence_probe.rb'
```

You should see the load banner:

```text
[SUAIPlugin::V19B0Probe] loaded; probe dictionary = 'SU-AI-Plugin.PreparedCadDataset'; schema = 'v19b0_probe_v1'; size ladder = [262144, 1048576, 4194304, 8388608]
```

Step 2 — small fixture sanity (the script's default ladder):

```ruby
m = Sketchup.active_model
SUAIPlugin::V19B0Probe.run_size_ladder(m)
```

This exercises 256 KiB → 1 MiB → 4 MiB → 8 MiB progressive write /
readback / digest-equality checks against `Sketchup.active_model`.
Each level prints a one-line summary and the function returns an
Array of result hashes.

Step 3 — immediate readback test:

```ruby
SUAIPlugin::V19B0Probe.run_immediate_readback_test(m, 256 * 1024)
```

Step 4 — replacement test (one-active-dataset semantics):

```ruby
SUAIPlugin::V19B0Probe.run_replacement_test(m, 256 * 1024)
```

Step 5 — corrupt / missing matrix:

```ruby
SUAIPlugin::V19B0Probe.run_corrupt_missing_tests(m)
```

Each corrupt case MUST return a fail-closed status
(`ok == false`, `reason == 'payload_missing'` / `'invalid_json'` /
`'digest_mismatch'` / `'unsupported_probe_schema'` / etc.). No
exception should escape for any of these expected corrupt-storage
conditions.

Step 6 — Undo / Redo probe:

```ruby
payload = SUAIPlugin::V19B0Probe.generate_payload(seed: 99, target_bytes: 64 * 1024)
SUAIPlugin::V19B0Probe.write_undo_redo_probe(m, payload, seed: 99)
SUAIPlugin::V19B0Probe.verify_probe(m)   # before Undo -> ok=true, digest matches
# Now click Edit > Undo manually in SketchUp.
SUAIPlugin::V19B0Probe.verify_probe(m)   # after Undo -> ok=false, reason='payload_missing' (or similar)
# Now click Edit > Redo manually in SketchUp.
SUAIPlugin::V19B0Probe.verify_probe(m)   # after Redo -> ok=true again
```

Step 7 — save / close / reopen probe:

```ruby
SUAIPlugin::V19B0Probe.write_reopen_test_payload(m, SUAIPlugin::V19B0Probe.generate_payload(seed: 7, target_bytes: 64 * 1024), seed: 7)
# In SketchUp: File > Save, then File > Close (do NOT quit SketchUp).
# File > Open the same .skp file again.
# In the new session's Ruby Console:
m2 = Sketchup.active_model
SUAIPlugin::V19B0Probe.verify_reopen_test_payload(m2)
```

The expected verdict is `PASS` with the stored digest matching the
recomputed digest and the JSON parse succeeding.

Step 8 — company-scale ladder (optional but recommended):

Open a representative company SKP / CAD model (with many entities /
groups / components) BEFORE running the ladder. Then:

```ruby
SUAIPlugin::V19B0Probe.run_size_ladder(Sketchup.active_model)
```

This exercises the same persistence path while a real-world model is
open, so the Owner can observe practical write / read latency,
SKP-save behavior, reopen behavior, and any practical model-size
impact. No source geometry mutation is performed.

Step 9 — cleanup before final close:

```ruby
SUAIPlugin::V19B0Probe.cleanup_probe(Sketchup.active_model)
```

This removes every `__v19b0_probe_*__` key from the probe
AttributeDictionary. After cleanup, the probe leaves no observable
trace in the model.

---

## 4. Probe commands / methods

Public SketchUp-touching API (each returns a structured hash; all
return `{ ok: false, reason: 'sketchup_unavailable' }` outside
SketchUp):

| Method | Purpose |
|---|---|
| `SUAIPlugin::V19B0Probe.help` | Print usage help to the console. |
| `SUAIPlugin::V19B0Probe.sketchup_available?` | SketchUp presence check. |
| `SUAIPlugin::V19B0Probe.probe_dictionary(model)` | Get / create the probe AttributeDictionary. |
| `SUAIPlugin::V19B0Probe.write_probe(model, payload_string, seed:, requested_bytes:)` | Write payload + digest + schema + seed + size in one SketchUp operation. |
| `SUAIPlugin::V19B0Probe.read_probe(model)` | Read probe payload + metadata. |
| `SUAIPlugin::V19B0Probe.verify_probe(model)` | Read + parse JSON + recompute digest + compare. |
| `SUAIPlugin::V19B0Probe.cleanup_probe(model)` | Remove every probe-namespaced key. |
| `SUAIPlugin::V19B0Probe.run_size_ladder(model, custom_bytes: nil)` | Run the default or custom size ladder; print + return results. |
| `SUAIPlugin::V19B0Probe.run_immediate_readback_test(model, target_bytes:)` | Single-level immediate readback test. |
| `SUAIPlugin::V19B0Probe.run_replacement_test(model, target_bytes:)` | One-active-dataset replacement semantics. |
| `SUAIPlugin::V19B0Probe.run_corrupt_missing_tests(model)` | Missing / invalid / mismatched / unsupported-schema matrix. |
| `SUAIPlugin::V19B0Probe.write_undo_redo_probe(model, payload_string, seed:)` | Write a recognizable payload for manual Undo/Redo. |
| `SUAIPlugin::V19B0Probe.write_reopen_test_payload(model, payload_string, seed:)` | Write + print the reopen-test payload. |
| `SUAIPlugin::V19B0Probe.verify_reopen_test_payload(model)` | Verify the reopen-test payload AFTER SketchUp / model reopen. |

Host-free API (always available; does not need SketchUp):

| Method | Purpose |
|---|---|
| `SUAIPlugin::V19B0Probe.sha256_hex(string)` | SHA-256 hex digest. |
| `SUAIPlugin::V19B0Probe.deterministic_string(seed:, length:)` | Deterministic ASCII string of exact length. |
| `SUAIPlugin::V19B0Probe.generate_payload(seed:, target_bytes:)` | Deterministic JSON payload of approximately target_bytes. |
| `SUAIPlugin::V19B0Probe.json_round_trip(payload_string)` | JSON parse + re-serialize + digest compare. |
| `SUAIPlugin::V19B0Probe.deterministic_payload_check(seed:, target_bytes:)` | Assert same (seed, target_bytes) yields byte-identical JSON. |

---

## 5. Failure semantics

- Read / verify of corrupt storage (missing key / invalid JSON /
  digest mismatch / unsupported probe schema) returns a structured
  fail-closed `{ ok: false, reason: '...' }` hash. No exception
  escapes for any of these expected corrupt-storage conditions.
- Unexpected programming errors propagate (not silently swallowed).
- The probe never mutates source CAD geometry, never creates Faces,
  never moves vertices, never touches `WorkingModeRunner` state,
  never touches the existing V1.9A derived workspace.
- Cleanup is always safe to call: it removes only the
  `__v19b0_probe_*__` keys under the
  `SU-AI-Plugin.PreparedCadDataset` dictionary.

---

## 6. Persistence route decision

This probe does NOT freeze a persistence route. AIPM will decide
whether the SketchUp Model AttributeDictionary route is acceptable
based on Owner real-host evidence after Pi returns the probe.
V1.9B1 (production implementation) remains NOT STARTED until that
decision is made.

---

## 7. Scope reminder

This probe is OUTSIDE `extension/`. Nothing under `extension/` was
modified by this packet. V1.9A production behavior is FROZEN at
HEAD `36b8f5b48c8ec2f5a4894db894ca62397344d2fa` on `dev/v1.9`.
No production RBZ was rebuilt.