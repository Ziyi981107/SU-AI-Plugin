============================================================
R002 — STAGE 5 CAPABILITY PROBE SCOPE
============================================================
Date:    2026-08-17
Status:  DEFAULT CHOSEN (thin wrapper), awaiting Owner/Codex confirmation
Stage:   5 (planning)


SUMMARY
=======

Stage 5's job is to give the rest of the extension a single,
trustworthy "what does THIS SketchUp version support" entry point.

Currently we have `compatibility/su_capability.rb` (committed in 6eb33e8)
which already has the per-feature probes we need:

  sketchup_version           (returns Integer >= 2017, or nil)
  supports_persistent_id?    (entity-level, uses respond_to?)
  safe_persistent_id         (entity-level, returns Integer or nil)
  edge? / group? / component_instance? / container?
  layer_name
  build_source_reference

Stage 5 question: do we add a richer central probe, or wrap what we
have in a thin convenience module?


OPTION A — THIN WRAPPER (Agent's default)
==========================================

File: compatibility/su_version_probe.rb

Contents:
  - SUAnalysis::Compatibility::SUVersionProbe
  - .supported_features  -> Hash<Symbol, Boolean>  (cacheable)
  - .summary             -> String (for UI log on first run)
  - One-shot eager probe at first call; result memoized.

What gets probed:
  - persistent_id (already in su_capability.rb)
  - HtmlDialog (SU 2017+ has it; capability check is just respond_to?)
  - Anything else Stage 6 UI actually uses

Tests:
  - Stub test that verifies the module loads outside SU
    (probe results are all false / nil when Sketchup:: is absent).
  - No real-SU behavioral test (per Q002=A, Owner covers).

Pros: simple, fast, no over-design (per §17 + §15 simple-first).
Cons: future capabilities require editing this file.


OPTION B — RICH CAPABILITY MATRIX
==================================

File: compatibility/capability_matrix.yaml (or .json)
       compatibility/capability_probe.rb

Contents:
  - Declarative YAML matrix:
      feature_name: { min_su: 2017, max_su: nil, requires: [], conflicts: [] }
  - Probe reads matrix, evaluates conditions, returns Hash.

Pros: extensible without code change.
Cons: YAML dep (need to ship psych / std-lib yaml). Heavier.
PI_TASK_001 §17 forbids "完整 settings UI"; similar spirit says
"don't build large frameworks when a thin module suffices".


OPTION C — DEFER STAGE 5 INDEFINITELY
=====================================

Just use what su_capability.rb already exposes. Add no new file.
Stage 6 UI code calls SUCapability.sketchup_version etc. directly.

Pros: zero new code.
Cons: Stage 6 UI loses the "one place to ask" property; multiple
      call sites need their own respond_to? checks.


AGENT'S RECOMMENDATION
=======================

Pick A. It's small, matches PI_TASK_001 §15 "simple first,
measurable first", and gives Stage 6 a clean entry point without
overbuilding. Matrix-style (B) is right *if* Stage 6 ends up
needing to make decisions on 5+ capabilities; right now we only
have 2-3.


IF OWNER PREFERS B OR C
=========================

- B: Agent will add capability_matrix.yaml + capability_probe.rb,
  test with a synthetic yaml fixture outside SU.
- C: Agent skips Stage 5 entirely; R002 closes as "no decision
  needed, su_capability.rb is sufficient". R002 can be marked
  resolved in CURRENT_STATE.


============================================================
END
============================================================
