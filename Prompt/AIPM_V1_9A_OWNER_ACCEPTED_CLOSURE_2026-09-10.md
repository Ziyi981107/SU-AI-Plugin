# AIPM V1.9A OWNER ACCEPTED CLOSURE — 2026-09-10

> Project: `D:\Projects\SU-AI-Plugin`
>
> Stage: **V1.9A — Owner Accepted Closure**
>
> Date: 2026-09-10
>
> Authority: ChatGPT / AIPM
>
> Final Product Owner: **Owner**
>
> Implementation Agent: Pi (closure docs only — no
> production change)
>
> Status: **V1.9A = COMPLETE / FROZEN**
>
> Next authorized stage: **V1.9B0 ONLY**
> (PreparedCadDataset Persistence Feasibility Probe —
> probe only, NO production PreparedCadDataset
> implementation)

---

## 1. Purpose

This durable closure artifact records the Final
V1.9A state observed and accepted by Owner real
SketchUp 2020 on 2026-09-10, and freezes the
V1.9A surface so that future Stage work (V1.9B0
and beyond) does NOT silently reopen already-PASS
production behavior.

This file is documentation-only. It does NOT
reopen, modify, or contradict any V1.9A
production RBZ, production source, or test
baseline.

---

## 2. Final V1.9A Production HEAD

- Branch: `dev/v1.9`
- Final HEAD SHA on `dev/v1.9`:
  `36b8f5b48c8ec2f5a4894db894ca62397344d2fa`
- Commit subject:
  `fix(v1.9a-rfr-codex-narrow-recheck): CXR-01
  first-pass live-capability vs cached-fallback
  split + CXR-02 proposer wrong-length Array
  regressions`

---

## 3. Final V1.9A RBZ (Owner-installed candidate)

- File: `dist/SU-AI-Plugin.rbz`
- **size**: 1,205,785 bytes
- **entries**: 73
- **SHA-256**:
  `FA9E9D7C4A146813183793BE4F3887A42907EAAE036D7706C2727912321AF6A5`

This is the candidate RBZ installed and exercised
by Owner on real SketchUp 2020 (version 20.0.363)
on 2026-09-10. Do NOT present any prior RBZ
SHA-256 as the V1.9A Owner-candidate.

---

## 4. Review Chain (all PASS)

| Gate | Verdict | Evidence |
|---|---|---|
| AIPM direct source / diff review | **PASS** | `Review/CURRENT_AIPM_REVIEW.md` (V1.9A CXR packet verdict) |
| Codex xHigh narrow recheck | **PASS** | Codex narrow recheck on CXR-01 + CXR-02 seams |
| Owner real SketchUp 2020 (20.0.363) verification | **PASS** | §5 below |

V1.9A is therefore:

```text
AIPM_REVIEW          = PASS
CODEX_NARROW_RECHECK = PASS
OWNER_SU2020         = PASS
V1.9A                = COMPLETE / FROZEN
```

---

## 5. Owner Real SketchUp 2020 Regression Evidence

Owner real-host environment:

- SketchUp 2020
- version 20.0.363

Owner real-host regression fixture:

- 0.2 mm Z drift (Planar)
- 1.0 mm endpoint gap (Gap)

Observed owner-driven flow:

```text
initial scan
-> planar safe correction detected
-> gap detected but correctly gated behind Z

apply Z
-> successful

refresh / recheck
-> corrected 0.2 mm planar deviation DID NOT resurrect

apply gap
-> successful

final structure:
component_count            = 1
open_chain_count           = 0
closed_loop_count          = 1
region_count               = 1
hole_count                 = 0
invalid_component_count    = 0
invalid_loop_count         = 0
unresolved_issue_count     = 0
computed                   = true
```

All authoritative Owner-acceptance assertions are
met. Refresh / recheck after Apply Z did NOT
resurrect the corrected planar drift (the
behavior the prior refresh-stale-planar BLOCK
was specifically tracking).

---

## 6. Frozen V1.9A Surface (do NOT silently reopen)

The following areas are now frozen unless a
future real-host blocker forces an explicit
AIPM reopening. A future Stage must NOT
silently rewrite, replace, or revert any of
the following:

- Planar normalization proposer / executor
  (`extension/su_ai_plugin/core/planar_normalization_proposer.rb`,
  `extension/su_ai_plugin/core/planar_normalization_executor.rb`)
- Gap proposer / executor
- Canonical topology
- Structure reconstruction
- `extension/su_ai_plugin/core/working_mode_runner.rb`
  (V1.9A behavior)
- `extension/su_ai_plugin/cad_prep_workflow_orchestrator.rb`
- `extension/su_ai_plugin/cad_prep_workflow_presenter.rb`
- `html/app.js`, `html/style.css`, V1.9A UI
- Native toolbar
- Tolerance policy (`coordinate_epsilon`,
  `planar_z_snap`, `gap_search` defaults)
- Shared-vertex rules
- Source / provenance ownership
- Source CAD immutability contract

V1.9A is closed at HEAD
`36b8f5b48c8ec2f5a4894db894ca62397344d2fa`.

---

## 7. Next Authorized Stage

The next authorized stage is **V1.9B0 ONLY**:

> V1.9B0 — PreparedCadDataset Persistence
> Feasibility Probe

This is a probe-only stage. It MUST NOT:

- Implement production `PreparedCadDataset`.
- Implement `PreparedCadDatasetBuilder`.
- Implement `PreparedCadDatasetValidator`.
- Implement acceptance workflow or accepted-dataset
  state.
- Implement production load / store integration.
- Implement final validation UI.
- Add new dialog callbacks.
- Touch V2 / MCP / LLM / Agent.
- Implement road / building recognition.
- Implement architectural / site semantics.
- Modify anything under `extension/`.
- Rebuild a production RBZ.

The probe lives under `Probe/V1_9B0/` and is
loaded directly from SketchUp 2020 Ruby
Console. The probe uses SketchUp Model
AttributeDictionary APIs only, with explicit
probe-namespaced keys
(`__v19b0_probe_payload__` etc.) so it can
never be confused with a future production
accepted dataset.

V1.9B0 does NOT freeze a persistence route.
AIPM will decide whether the SketchUp Model
AttributeDictionary route is acceptable based
on Owner real-host evidence after Pi returns
the probe. V1.9B1 (the implementation stage)
remains NOT STARTED.

---

## 8. Sign-Off

V1.9A is **COMPLETE / FROZEN** on `dev/v1.9`
at HEAD
`36b8f5b48c8ec2f5a4894db894ca62397344d2fa`.

The next normal formal Pi dispatch is the
V1.9B0 persistence feasibility probe
dispatch, which has already been issued as
the new `Prompt/CURRENT_PI_DISPATCH.md`.

END