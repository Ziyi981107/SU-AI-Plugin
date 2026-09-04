# SU-AI-Plugin — V1.8 OWNER ACCEPTED CLOSURE

DATE: 2026-09-03
STAGE: V1.8 — Polyline / Closed Loop / Region Reconstruction
STATUS: CLOSED — OWNER ACCEPTED FOR DEMO MILESTONE

## 0. Owner Summary

V1.8 is formally closed for the current demo / presentation milestone.

The stage now provides the deterministic downstream structure layer:

CanonicalGeometryGraph
→ Open Chains
→ Closed Loops
→ Nested Loops / Holes
→ Regions

No further V1.8 development or broad verification is authorized before the presentation.

---

## 1. Final Build

Branch:
`dev/v1.8`

Final implementation / UI-wiring commit:
`bbe423cc83f4136ddd4d0673fbce02527e36de15`

RBZ:
`D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`

Size:
`1,078,875 bytes`

Entries:
`69`

SHA-256:
`8fdadd5a9258bd2c2ceaf1cf83edf0427ed6f5d8123270877c3f90bb7387739d`

This RBZ is the frozen presentation/demo candidate.

---

## 2. AIPM Review Status

V1.8 base:
AIPM direct source review initially BLOCKED bounded contract gaps.

Correction rounds closed:
- Ruby 2.2 compatibility
- coordinate_epsilon authority
- conservative segment-conflict handling
- indexed traversal / performance
- cache invalidation
- truthful READY_WITH_WARNINGS state
- deep immutability
- adjacency validation
- real SU2020 old-Ruby boot syntax compatibility
- real SU2020 HtmlDialog UI callback wiring

Final AIPM status:
`PASS_WITH_NONBLOCKING_NOTES`

Codex:
`NOT REQUIRED`

Reason:
No V1.7 canonical identity/schema/digest redesign, no host Face generation,
no new Observer/Undo architecture, no tolerance-authority redesign, and no
workspace-ownership change were introduced by V1.8.

---

## 3. Automated Evidence

Latest UI-wiring packet reported:

- 1053 total Ruby tests
- 1050 PASS
- 1 fail / 2 error confirmed pre-existing on the prior commit and unrelated to
  the V1.8 UI-wiring change
- 5 / 5 new V1.8 UI-wiring focused tests PASS
- Node DOM: 327 assertions PASS
- git diff --check: clean
- RBZ rebuilt successfully

The three pre-existing test failures are accepted as non-blocking for this
presentation milestone and are not relabeled as PASS.

---

## 4. Real SketchUp 2020 Evidence

### Boot / host compatibility

Latest RBZ:
PASS

The extension appears and loads normally in real SketchUp 2020 after the
old-Ruby parser compatibility fix.

### UI wiring

`检查结构`:
PASS

The HtmlDialog callback is connected through:

app.js
→ window.sketchup.compute_structure_reconstruction
→ DialogRunner
→ WorkingModeRunner.compute_structure_reconstruction
→ payload re-push
→ UI render

### Owner Scenario A — Simple Rectangle

Observed real-host result:

- Open Chains: 0
- Closed Loops: 1
- Regions: 1
- Holes: 0
- Exceptions: 0
- State: structure usable / READY

Result:
`PASS`

### Owner Scenario C — Outer Loop + Inner Loop

Observed real-host result:

- Open Chains: 0
- Closed Loops: 2
- Regions: 1
- Holes: 1
- Exceptions: 0

Result:
`PASS`

These scenarios prove the two highest-value presentation paths:
- simple closed region reconstruction;
- nested-loop / hole reconstruction.

---

## 5. Owner Verification Waiver

For the presentation milestone, remaining representative Owner scenarios are
not required.

Skipped / waived examples:
- dedicated open-polyline real-host Owner scenario;
- repaired V1.7 triangle → V1.8 reconstruction scenario;
- exhaustive malformed-geometry host scenarios.

These are not recorded as PASS.

They are:
`WAIVED_BY_OWNER_FOR_CURRENT_DEMO_MILESTONE`

Rationale:
- deterministic core automated coverage exists;
- AIPM source review passed;
- real SU2020 boot and UI production path passed;
- real SU2020 region and hole reconstruction passed;
- further verification would consume presentation-preparation time without
  proportionate demo-milestone value.

---

## 6. Frozen Product Boundary

V1.8 includes:

- deterministic open-chain reconstruction;
- deterministic closed-loop reconstruction;
- conservative malformed-structure handling;
- nested-loop containment;
- holes;
- RegionRecord reconstruction;
- plural provenance preservation;
- Chinese `轮廓与区域 / 检查结构` UI;
- read-only V1.8 structure computation from current workspace.

V1.8 does NOT include:

- SketchUp Face generation;
- site semantics;
- building / road / red-line classification;
- MCP;
- AI;
- V2 site modeling;
- PreparedCadDataset packaging.

---

## 7. Next Stage Boundary

V1.9 / PreparedCadDataset:
`NOT STARTED`

V2 / MCP:
`NOT STARTED`

No next implementation stage is active during presentation preparation.

---

## 8. Freeze Decision

Effective immediately:

- V1.8 CLOSED
- Owner Gate ACCEPTED
- Demo Build FROZEN
- Pi STOP
- Codex STOP
- no more V1.8 code changes before the presentation
- only reopen V1.8 if a material demo-blocking real-host defect is discovered

NEXT PRODUCT ACTION:
`PPT / DEMO PREPARATION`

END
