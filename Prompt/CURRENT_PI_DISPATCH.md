# CURRENT PI DISPATCH — V1.9B0 PERSISTENCE FEASIBILITY PROBE

Project: SU-AI-Plugin
Stage: V1.9B0 — PreparedCadDataset Persistence
Feasibility Probe
Date: 2026-09-10
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
TARGET_BRANCH: `dev/v1.9`
STATUS: ACTIVE
V1_9A = CLOSED_FROZEN
V1_9B0_IMPLEMENTATION = NOT_STARTED
V1_9B1 = NOT_STARTED

V1.9A Owner Accepted Closure evidence:

`Prompt/AIPM_V1_9A_OWNER_ACCEPTED_CLOSURE_2026-09-10.md`

EXPECTED_START_HEAD (current `dev/v1.9` HEAD
before Pi touches the working tree):
`36b8f5b48c8ec2f5a4894db894ca62397344d2fa`

---

## 0. PURPOSE

This packet is:

**V1.9B0 — PreparedCadDataset Persistence
Feasibility Probe**

This is **NOT** PreparedCadDataset
implementation.

The only question this packet answers is:

> Can SketchUp Model AttributeDictionary reliably
> persist a representative future
> PreparedCadDataset payload at realistic size?

Leading candidate persistence route:

```text
SketchUp Model AttributeDictionary

dictionary:
SU-AI-Plugin.PreparedCadDataset
```

The persistence route is NOT frozen by this
packet. AIPM will decide whether the SketchUp
Model AttributeDictionary route is acceptable
based on Owner real-host evidence after Pi
returns the probe.

---

## 1. CRITICAL SCOPE BOUNDARY

DO NOT implement:

- PreparedCadDataset production class
- PreparedCadDatasetBuilder
- PreparedCadDatasetValidator
- acceptance workflow
- accepted dataset state
- production load/store integration
- final validation UI
- new dialog callbacks
- V2
- MCP
- LLM
- Agent
- road recognition
- building recognition
- architectural / site semantics

DO NOT modify anything under:

```text
extension/
```

for this packet.

No production RBZ rebuild is required.

V1.9A is frozen at HEAD
`36b8f5b48c8ec2f5a4894db894ca62397344d2fa`.

---

## 2. PROBE IMPLEMENTATION

Create a standalone real-host probe:

```text
Probe/V1_9B0/prepared_dataset_persistence_probe.rb
```

Optional companion documentation:

```text
Probe/V1_9B0/README.md
```

The probe must be loadable directly from
SketchUp 2020 Ruby Console.

Example future Owner usage:

```text
load 'D:/Projects/SU-AI-Plugin/Probe/V1_9B0/prepared_dataset_persistence_probe.rb'
```

Do NOT require installing a new RBZ.

---

## 3. PROBE STORAGE CONTRACT

Use model-level AttributeDictionary APIs only.

Target dictionary:

```text
SU-AI-Plugin.PreparedCadDataset
```

Use explicitly probe-namespaced keys so this
cannot be confused with a future production
accepted dataset. Recommended keys:

```text
__v19b0_probe_payload__
__v19b0_probe_digest__
__v19b0_probe_schema__
__v19b0_probe_seed__
__v19b0_probe_requested_bytes__
__v19b0_probe_actual_bytes__
```

Provide an explicit cleanup operation that
removes all probe data.

Never modify CAD geometry.

---

## 4. DETERMINISTIC TEST PAYLOAD

Generate deterministic JSON-safe synthetic
payloads. The generated content should resemble
the likely PreparedCadDataset shape enough to
exercise strings / arrays / nested hashes, but
MUST NOT freeze the actual future B1 schema.

Include generic sections such as:

- metadata
- source-like data
- nodes-like arrays
- edges-like arrays
- structures-like arrays
- warnings-like arrays

This is only a persistence payload. Same
requested size / seed must produce byte-identical
JSON.

Use `JSON.generate`.

Use SHA-256 for external verification.

Do not put wall-clock timestamps into the
deterministic payload.

---

## 5. SIZE LADDER

Provide a convenient size-ladder probe.

Recommended default targets:

```text
256 KiB
1 MiB
4 MiB
8 MiB
```

The implementation should also allow Owner to
request an arbitrary payload size later.

Run progressively.

Do not hide slow/failing levels.

For each level report:

- requested approximate bytes
- actual JSON bytes
- write time
- read time
- exact string equality
- JSON parse success
- SHA-256 before write
- SHA-256 after read
- digest equality

Use monotonic timing where supported.

No arbitrary PASS performance threshold is
frozen in code.

Report raw measurements. AIPM will decide
whether performance is acceptable.

---

## 6. IMMEDIATE READBACK TEST

For every payload:

```text
write
-> read back
-> compare exact bytes
-> JSON.parse
-> recompute SHA-256
-> compare digest
```

Any mismatch must be surfaced explicitly.

Do not rescue corruption into a false PASS.

---

## 7. REPLACEMENT TEST

Provide a test for one-active-dataset replacement
semantics:

```text
write payload A
-> verify A
-> replace same probe slot with payload B
-> verify B
-> prove old A is no longer active
```

Do not build historical version management.

V1.9 scope is one active accepted dataset per
model.

---

## 8. CORRUPT / MISSING TEST

Provide probe helpers to exercise:

- payload missing
- digest missing
- invalid JSON
- digest mismatch
- unsupported probe schema marker

Read/verify must return a clear fail-closed
status.

No exception should escape for expected
corrupt-storage conditions.

Unexpected programming errors must not be
silently swallowed.

---

## 9. UNDO / REDO PROBE

Write operations must be wrapped in a normal
SketchUp model operation where appropriate.

Because host Undo/Redo semantics are part of
what B0 is measuring, DO NOT fake the result
in host-free code.

Provide:

- a method that writes a recognizable probe
  payload in one operation
- a status/read method Owner can call before/
  after Undo/Redo

Owner will perform real SketchUp Undo/Redo
manually if that is safer than automating
host UI actions.

Report observed behavior rather than assuming
it.

---

## 10. SAVE / CLOSE / REOPEN PROBE

Provide a method that writes a persistent
reopen-test payload and prints:

- payload bytes
- expected digest
- probe schema
- model path if available

Provide a separate method callable AFTER
SketchUp/model reopen that:

- reads the stored payload
- parses JSON
- recomputes digest
- compares stored digest
- prints PASS / BLOCK style evidence

Do NOT programmatically force-close SketchUp.

The Owner will:

```text
save SKP
-> close
-> reopen
-> run verification
```

---

## 11. COMPANY-SCALE EVIDENCE

Do not treat a tiny fixture as persistence
evidence.

The probe must support running the same size
ladder while a representative company
SKP / CAD model is open.

No source geometry mutation is allowed.

This lets Owner measure:

- attribute write / read latency
- SKP save behavior
- reopen behavior
- practical model-size impact where measurable

Do not invent company results.

Owner evidence will be supplied after Pi
returns the probe.

---

## 12. SAFETY

Probe must:

- never delete geometry
- never alter source CAD entities
- never create Faces
- never move vertices
- never touch WorkingModeRunner state
- never touch existing V1.9A derived workspace
- namespace all model attributes
- provide cleanup
- fail closed on malformed stored data

---

## 13. VALIDATION BEFORE RETURN

Because `extension/` production source MUST
remain untouched:

Required automated validation is narrow. At
minimum:

- `ruby -c` on probe script
- deterministic payload generation checked
  twice (same requested size + seed must
  produce byte-identical JSON)
- JSON round-trip in host-free Ruby where
  possible
- `git diff` confirms NO `extension/` change
- `git status` recorded

Do NOT spend time re-running the entire V1.x
suite unless an unexpected production/shared
dependency was changed.

If anything under `extension/` changes:
STOP and report before proceeding.

---

## 14. RETURN REPORT

Return:

- A. starting HEAD
- B. final HEAD
- C. exact changed files
- D. confirmation V1.9A closure docs recorded
- E. confirmation `extension/` unchanged
- F. probe Ruby Console command
- G. supported probe commands / methods
- H. deterministic payload evidence
- I. syntax / test evidence
- J. exact Owner real-SU2020 test sequence
- K. any limitation or unknown

Return state:

```text
V1_9A                        = CLOSED_FROZEN
V1_9B0_IMPLEMENTATION        = COMPLETE
OWNER_SU2020_PERSISTENCE_PROBE = REQUIRED
PERSISTENCE_ROUTE             = NOT_YET_FROZEN
V1_9B1                       = NOT_STARTED
```

STOP.

Do not begin B1.

Do not implement production PreparedCadDataset.

Do not choose a persistence route on Owner's
behalf.

END