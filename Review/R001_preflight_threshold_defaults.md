============================================================
R001 — PREFLIGHT THRESHOLD DEFAULTS
============================================================
Date:    2026-08-17
Status:  DEFAULT CHOSEN, awaiting Owner/Codex confirmation
Stage:   2 (locked in commit 6eb33e8)
For:     Owner + Codex


SUMMARY
=======

Per PI_TASK_001 §10, all thresholds must be centralized in Tolerance.
Stage 2 introduces two new Preflight warning thresholds. Agent picked
defaults; Owner / Codex should confirm or override before Stage 6 ships.

Defaults chosen (in core/tolerance.rb):

  big_z              = 0.01  inches
  large_coordinate   = 1.0e6 inches
  deepest_nesting_warning = 3  levels   (already existed in
                                         AnalysisConfig, carried over)


RATIONALE
=========

big_z = 0.01 in
  - 0.01 in = 0.254 mm, about the thickness of 3 sheets of paper.
  - Real architectural CAD in plan view sits at Z=0 with sub-mm noise
    from import / dwg conversion. Anything bigger than 0.01 in is
    almost certainly real off-plane geometry, not noise.
  - coordinate_epsilon (1e-6 in) is too tight for "is Z meaningful";
    that one stays for "are two points the same point".
  - Conservative default. Owner can tighten later if false positives
    appear, or loosen if real CAD has more noise.

large_coordinate = 1.0e6 in
  - 1e6 in = 15.78 miles. No real building has a corner at 15 miles.
  - This catches: import with wrong unit (mm treated as in -> a 30 m
    building becomes 30 *million* inches), corrupted / malformed
    geometry, hand-imported garbage.
  - Conservative default — anything larger almost certainly indicates
    a unit / import bug, not a legitimate large site.

deepest_nesting_warning = 3
  - Carried over from AnalysisConfig initial value.
  - 3 levels (group → component → group) is a plausible upper bound
    for a clean CAD import; deeper nesting usually means somebody
    wrapped things in wrappers without reason.


WHAT OWNER GETS
===============

For Stage 2 verification checklist step C/D/E/F:

  C (pure 2D): no warnings expected.
  D (Z=5 in):  big_z warning fires, severity :info.
               Severity :info means "noted, not blocking" — Owner should
               confirm this is the right posture (info vs warning).
  E (1.5e6 in): large_coord warning fires, severity :warning.
               Severity :warning means "user-visible alert".
  F (3+ nesting): deep_nesting warning fires, severity :warning.


QUESTIONS FOR OWNER
====================

Q1.1  big_z default OK, or change?  (current 0.01 in)
      Alternatives:
        (a) keep 0.01 in (current)
        (b) tighten to 0.001 in (~0.025 mm, paper-thin) — fewer
            false negatives on intentional 3D CAD
        (c) loosen to 0.1 in (~2.5 mm) — fewer false positives on
            noisy DWGs

Q1.2  large_coordinate default OK?  (current 1e6 in = 15.78 mi)
      Alternatives:
        (a) keep 1e6 in
        (b) tighten to 1e5 in (= 1.58 mi) — also catches city-block-
            scale geometry that probably means a unit bug
        (c) loosen to 1e7 in (= 157 mi) — only flags truly absurd

Q1.3  deepest_nesting_warning = 3 OK?
      Alternatives:
        (a) keep 3
        (b) drop to 2 (stricter — clean CAD rarely nests > 1)
        (c) bump to 5 (more permissive)

Q1.4  Severity mapping OK?
        non_zero_z_geometry -> :info   (informational)
        abnormal_large_coord -> :warning (visible alert)
        deep_nesting        -> :warning (visible alert)
      Or should non_zero_z also be :warning so it's harder to miss?

No reply = Agent keeps current defaults.


IMPACT IF CHANGED LATER
========================

Tolerance is single source of truth (PI_TASK_001 §10). Changing a
default is one-line. All PreflightAnalyzer tests reference config
(which inherits Tolerance.default). Profile objects (Stage 4) will
override per Company Profile, so defaults only matter for "no
profile loaded" case.

============================================================
END
============================================================
