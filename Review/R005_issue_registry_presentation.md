============================================================
R005 — ISSUE REGISTRY PRESENTATION
============================================================
Date:    2026-08-17
Status:  ANSWERED (received 2026-08-17 via CODEX_REVIEW_004)
Stage:   6 (planning)
For:     Owner (primary) + Codex (review)


RECAP
=====

PI_TASK_001 §11:

  "建立统一 IssueRegistry
   每个 Issue 至少包含:
     issue_id
     issue_type
     severity   (high / medium / low)   ← per §11
     confidence (high / medium / low)
     source entity ids
     geometry / location
     message
     metadata"

Stage 1 + Stage 2 analyzers already emit issues with these fields.
What V1.0 does NOT yet have is a unified `IssueRegistry` data
structure (each analyzer currently returns its own array of issue
hashes). That's Stage 3 / 4 territory.

This file is purely about how the issues are *presented* to Owner
in the V1.0 UI. The IssueRegistry data class itself comes later.


PRESENTATION OPTIONS
====================

V1.0 has at most these issue types (PI_TASK_001 §9 + §6):

  ISSUE_001  duplicate_edge_candidate    (Analyzer: DuplicateDetector)
  ISSUE_002  short_edge                  (Analyzer: ShortEdgeDetector)
  ISSUE_003  open_endpoint               (Analyzer: OpenEndpointDetector)
  ISSUE_004  gap_candidate               (Analyzer: GapCandidateDetector)
  PREFLIGHT  non_zero_z_geometry         (Preflight)
  PREFLIGHT  abnormal_large_coord        (Preflight)
  PREFLIGHT  deep_nesting                (Preflight)

For V1.0, severity is fixed per issue type (not user-tunable yet,
that comes with IssueRegistry in Stage 3):

  duplicate_edge_candidate   -> :medium
  short_edge                 -> :low      (often a real artifact, low priority)
  open_endpoint              -> :medium
  gap_candidate              -> :medium
  non_zero_z_geometry        -> :info     (informational only, see R001)
  abnormal_large_coord       -> :warning  (user-visible alert)
  deep_nesting               -> :warning


UI PRESENTATION OPTIONS
========================

(1) FLAT LIST — single scrollable list, all issues mixed, sorted by
    issue_type then by source entity id [Agent default]

    Pros: simplest, matches §12 example "Issue 列表".
    Cons: at 1000 issues, hard to scan.

(2) GROUPED BY TYPE — Duplicate (NN) / Short (NN) / Open (NN) /
    Gap (NN) / Warnings (NN), each collapsible

    Pros: mirrors §12 example output exactly.
    Cons: more clicks for a quick "show me all duplicates" view.

(3) GROUPED BY LAYER — first-level grouping by source Layer, then by
    issue_type inside

    Pros: useful when Owner knows "Layer A is the suspicious layer".
    Cons: less useful when issues span many layers.

(4) FILTERABLE TABLE — flat list with column filters
    (type / severity / layer / entity)

    Pros: most flexible.
    Cons: more UI complexity, more JS.

Agent default: (2) GROUPED BY TYPE — matches §12 example, gives
quick "show me all duplicates" via collapse, and the section
headers double as a summary count.

Owner pick: 1 / 2 / 3 / 4  → default 2.


SORT ORDER WITHIN A GROUP
==========================

(a) by source entity id (stable, predictable)
(b) by location (bbox center distance from origin)
(c) by severity then entity id
(d) by length (short edges first) when type=short_edge

Agent default: (a) by source entity id.

Owner pick: a / b / c / d  → default a.


SEVERITY VISUAL TREATMENT
==========================

Per R003 Q3.4 (visual language):

  :info     -> grey "i" badge
  :warning  -> orange "!" badge
  :medium   -> blue dot (default; no special badge if too noisy)
  :low      -> no badge

Owner pick: accept / override per severity.


INTERACTION (RECAP FROM R003)
==============================

Click Issue → locate (Q3.1=B = selection.add + zoom).
Alt-click Issue → highlight overlay (Q3.1=A).
Double-click Issue → open Entity Info panel (Q3.5=C optional).


SUMMARY OF DEFAULTS IF NO OWNER REPLY
======================================

- Issue grouping: by issue_type, collapsible, section headers show
  count (option 2).
- Within-group sort: by source entity id (option a).
- Severity badge: :info = grey "i", :warning = orange "!",
  :medium = no badge (low visual noise), :low = no badge.
- Interaction: click = locate, Alt+click = highlight,
  Double-click = Entity Info (optional).

If Owner wants different, edit this file and drop answer in Prompt/.

ANSWER (received 2026-08-17):
  Codex decisions:
    - Presentation: option 2 (grouped by issue_type, collapsible,
      count in each heading).
    - Within-group order: deterministic issue_id, NOT raw Ruby object_id.
    - Canonical severity values: low / medium / high ONLY.
      (Do NOT mix :info / :warning with :low / :medium.)
    - Canonical confidence values: low / medium / high, KEPT SEPARATE
      from severity.
    - UI treatment: low = neutral, medium = orange, high = red.
    - Click = Locate (selection + zoom). No overlay. No Entity Info.
    - No filterable / sortable table in V1.

  Suggested initial severity mapping (centralized in Issue Registry,
  not UI):
    duplicate_edge_candidate   :medium
    short_edge                 :low
    open_endpoint              :medium
    gap_candidate              :medium
    significant non-zero-Z     :medium
    abnormal large coordinate  :high
    deep nesting               :low

  Preflight facts that do not cross a warning threshold remain
  summary metrics, NOT separate warning Issues.

  Implication for current code: PreflightAnalyzer currently emits
  :info / :warning severities. These MUST be migrated to the
  canonical :low / :medium / :high set during Stage 2 BLOCK rework
  (S2-BLOCK-004) before any UI consumes them.
============================================================
END
============================================================
