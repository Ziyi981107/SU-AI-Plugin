# AIPM V1.5 CLOSURE RECORD

DATE: 2026-08-31
PROJECT: SU-AI-Plugin
VERSION: V1.5 — High-confidence Auto Repair
AUTHORITY: AIPM / Final Product Owner
STATUS: CLOSED

## 0. Owner Summary

V1.5 is closed.

The final unresolved item was BLOCK-005: real SketchUp host-state reconciliation
around native Undo / recovery.

The Final Product Owner has now reported that the SketchUp-side verification is
complete and PASS for the current V1.5 candidate.

This record closes the stage. It does not fabricate screenshots, per-scenario
logs, or host evidence that the Owner did not explicitly provide.

Next product stage:

V1.6 — Planar Normalization / Z Policy

V1.6 implementation MUST NOT start until the V1.6 Stage Technical Blueprint is
present and a new CURRENT_PI_DISPATCH explicitly activates it.

---

## 1. V1.5 Product Outcome

V1.5 delivered the first high-confidence deterministic repair capability on top
of the V1.4 DerivedGeometryWorkspace foundation:

- exact / reversed duplicate-edge cleanup on DERIVED geometry;
- conservative fail-closed behavior for ambiguous duplicate components;
- deterministic survivor semantics;
- provenance preservation;
- before/after repair audit;
- idempotent repeated execution;
- source CAD immutability;
- transactional host mutation;
- discard / rebuild;
- host-state consistency validation before later destructive interaction.

V1.5 does NOT include:
- planar normalization;
- gap repair;
- endpoint snapping;
- topology reconstruction;
- loop/region reconstruction;
- MCP / AI / site modeling.

---

## 2. BLOCK-005 Closure

BLOCK-005 investigated the risk:

SketchUp native Undo / Redo changes host geometry
while the plugin still holds derived Ruby Entity handles/state.

Frozen V1.5 architecture:

validate-on-next-interaction
→ detect host mismatch
→ fail closed / invalidate
→ host-authoritative discard + prepare/rebuild

SketchUp Model remains the geometry Source of Truth.

V1.5 did NOT add:
- global ModelObserver architecture;
- EntitiesObserver replay;
- plugin-owned Undo history;
- persistent_id as the correctness Source of Truth.

The approved fallback (small ModelObserver dirty/stale invalidation) was reserved
only if real SketchUp testing proved the existing seam insufficient.

Owner real-host verification has now been reported complete and PASS.
Therefore the fallback is NOT activated for V1.5.

BLOCK-005: CLOSED.

---

## 3. Compatibility Evidence

The V1.5 legacy-compatibility packet established:

- the confirmed SketchUp 2020 parser failure from Ruby endless-range syntax was
  fixed using a legacy-compatible equivalent;
- later false compatibility claims were corrected rather than preserved as
  fake evidence;
- current automated compatibility evidence remains bounded by the available
  project toolchain and does NOT prove real SU2017 host support;
- real-host evidence is kept distinct from automated parser / FakeSU evidence.

Current accepted V1.5 RBZ candidate:

Path:
D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz

Size:
642,037 bytes

Entries:
59

SHA-256:
61784D79AB90BC96E448AC8F8693CCC77F007510654ED7FB70AAEAFFAE9A3292

Formal SU2017 real-host support remains unverified unless a separate real SU2017
verification is later performed.

---

## 4. Closure State

V1.0–V1.4:
CLOSED / unchanged for this closure.

V1.5:
CLOSED.

BLOCK-005:
CLOSED.

Owner SketchUp 2020 V1.5 verification:
PASS — based on Final Product Owner confirmation in the active project
conversation. No unprovided sub-scenario evidence is invented.

Codex:
NOT REQUIRED for this closure step.

V1.6:
NOT STARTED.

V1.6 Stage Technical Blueprint:
may now be frozen and prepared for dispatch.

V1.7:
NOT STARTED.

V2 / MCP:
OUT OF SCOPE.

---

## 5. Durable Lessons Carried Forward

1. Source CAD remains immutable.
2. Derived workspace remains the only normal mutation target.
3. Host state is authoritative over cached plugin state.
4. Real SketchUp evidence is required for host/runtime claims.
5. SketchUp 2017+ remains the intended compatibility baseline, but only tested
   real hosts may be claimed as verified.
6. Do not add Observer architecture unless a concrete host behavior requires it.
7. Do not let compatibility lint rules encode unsupported version-history claims.
8. Simple-first remains mandatory: future stages should maximize visible product
   value and avoid repeated micro-review loops unless material risk warrants them.

---

## 6. Next Permitted Action

AIPM may now:

1. publish/freeze the V1.6 Stage Technical Blueprint;
2. close V1.5 in CURRENT_STATE;
3. create a new V1.6 implementation dispatch.

Pi must not infer V1.6 work from this closure file alone.

END
