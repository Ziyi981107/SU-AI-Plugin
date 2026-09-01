# AIPM V1.6 CLOSURE RECORD

DATE: 2026-09-01
PROJECT: SU-AI-Plugin
VERSION: V1.6 — Planar Normalization / Z Policy
AUTHORITY: AIPM / Final Product Owner
STATUS: CLOSED

## 0. Owner Summary

V1.6 is CLOSED.

The Final Product Owner completed the real SketchUp 2020 verification of the
V1.6 Chinese production candidate, including:

- small unintended Z drift;
- non-zero translated plane;
- high-Z outlier preservation;
- ambiguous 50/50 multi-plane refusal;
- discard / rebuild lifecycle;
- source-CAD immutability;
- Simplified Chinese workflow;
- discarded-state fresh Prepare recovery;
- dialog-close auto-discard and clean reopen.

The last Owner UX change was:

dialog close
→ reuse existing WorkingModeRunner.discard
→ transient Derived Workspace removed
→ Source CAD unchanged
→ reopen directly exposes `准备处理`.

No additional V1.6 polish is authorized by this closure.

Next stage:

V1.7 — Endpoint / Gap Repair + Canonical Topology.

## 1. V1.6 Product Outcome

V1.6 delivered a conservative derived-only planar normalization workflow:

selection
→ Prepare derived workspace
→ 检查平面偏差
→ deterministic dominant Z-band proposal
→ explicit 应用平面校正
→ Z-only derived host mutation
→ XY preservation
→ post-validation
→ provenance/audit
→ source unchanged.

The production UX is Simplified Chinese and intentionally hides normal
engineering/debug identifiers under collapsed technical details.

V1.6 also preserves the V1.4/V1.5 lifecycle:

- Prepare;
- Discard;
- Rebuild;
- host-state consistency validation;
- fail-closed recovery;
- close-time auto-discard.

## 2. Owner Real-Host Validation Result

Owner-confirmed real SketchUp 2020 PASS:

A. Small Z noise
- safe proposal;
- apply succeeds;
- derived Z range collapses to the proposed plane;
- source unchanged.

B. Non-zero translated plane
- target plane remains near the actual non-zero plane;
- not incorrectly flattened to world Z=0;
- source unchanged.

C. Outlier
- dominant safe geometry normalizes;
- genuine high-Z outlier remains unchanged;
- source unchanged.

D. Ambiguous split
- plugin refuses to guess;
- no destructive Apply action is exposed;
- source unchanged.

E. Discard / Rebuild
- normalized derived workspace may be discarded;
- source remains intact;
- rebuild recreates source-derived geometry;
- normalization may be proposed again.

F. Close auto-discard
- a prepared derived workspace exists before dialog close;
- closing the plugin removes the derived workspace;
- source remains unchanged;
- reopening the plugin begins on the clean `准备处理` path.

No additional unprovided screenshots/log lines are invented by this closure
record.

## 3. Accepted V1.6 Candidate

Path:

D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz

Final close-autodiscard candidate reported by Pi:

- Size: 768,150 bytes
- Entries: 62
- SHA-256:
  7154C6C96759E847CA99A99E9B8B62F88BF230E0741CDFED884586425960BAE7

Automated evidence reported for this candidate:

- Full Ruby: 850 / 850 PASS
- V1.6 focused: 26 / 26 PASS
- V1.5 focused: 149 / 149 PASS
- Node DOM: 307 / 307 PASS
- RBZ smoke: 9 / 9 PASS
- git diff --check: clean

Automated evidence does not replace the Owner real-host evidence above.

## 4. Frozen V1.6 Lessons for V1.7

Carry forward unchanged:

1. Source CAD is immutable.
2. Repairs operate on derived/workspace-owned geometry only.
3. Host state is authoritative over cached handles.
4. The UI must stay Simplified Chinese and user-oriented.
5. Technical/audit evidence remains available but collapsed.
6. One clear primary action is preferred over button clutter.
7. Real SketchUp 2020 Owner verification remains required at meaningful
   mutation/lifecycle gates.
8. Do not add Observer architecture without concrete host evidence requiring it.
9. Closing the dialog discards transient derived workspace state.
10. Rebuild/Prepare must always produce fresh host-valid handles.

## 5. Status

V1.0–V1.5:
CLOSED.

V1.6:
CLOSED.

V1.6 Owner SU2020:
PASS.

V1.7:
AUTHORIZED TO START after the V1.7 Technical Blueprint is present and the
CURRENT_PI_DISPATCH explicitly activates it.

V1.7 mandatory review:
Codex xHigh integration review after Pi implementation and AIPM primary source
review, before V1.7 Owner closure.

V1.8:
NOT STARTED.

V2 / MCP:
OUT OF SCOPE.

END
