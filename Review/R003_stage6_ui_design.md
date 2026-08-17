============================================================
R003 — STAGE 6 UI DESIGN
============================================================
Date:    2026-08-17
Status:  ANSWERED (received 2026-08-17 via CODEX_REVIEW_004)
Stage:   6 (planning — not yet started)
For:     Owner (primary) + Codex (review)


WHY THIS MATTERS
================

PI_TASK_001 §12 ("能用，不追求漂亮") + §13 ("Issue → SketchUp Entity 定位")
+ §17 (no full settings UI in V1.0).

Stage 6 UI is what Owner actually uses daily. Most decisions in this
file are Owner-pickable (no engineering risk), but the *visualizer*
sub-question has hard constraints tied to PI_TASK_001 §91 ("原始 CAD:
NEVER MODIFY").

Each sub-question below has Options A/B/C with default recommendation
and tradeoffs. No reply = Agent picks the default.


================================================================
Q3.1 — SELECTION VISUALIZER APPROACH
================================================================

PI_TASK_001 §13: "Issue 定位 / 高亮 ... 优先考虑 Selection 高亮,
Zoom / camera 定位, 或稳定的临时视觉提示. 不要永久修改原几何样式."

Three concrete approaches:

(A) TEMPORARY EDGE OVERLAY [Agent default]
    - On Issue click: draw a short, colored construction line / box at
      the Issue's geometry (a *new* entity, not modifying the
      source edge).
    - Visual cleanup: stash overlay entity IDs in a session list;
      on "Clear Highlights" or next analysis run, erase them.
    - Pros: visually unambiguous, camera-independent.
    - Cons: introduces overlay entities that LOOK like geometry but
      aren't. Owner must understand "highlight = not real".

(B) CAMERA ZOOM-TO-ENTITY + transient Selection.set
    - On Issue click: `Sketchup.active_model.selection.add(issue_entity)`
      + `Sketchup.active_model.active_view.zoom(entities)` or
      `.camera.look_at(...)`.
    - Pros: zero new geometry; uses stock SU UI (selection is yellow).
    - Cons: relies on Owner visually tracking the selection among
      possibly many source entities. For 5000-edge CAD this is
      weak.

(C) HYBRID — selection.add() + camera zoom + optional overlay
    - Default: (B). Owner can toggle overlay on per Issue.
    - Pros: works for both small and large CAD.
    - Cons: more code paths, more test surface.

Agent default: (C). UI shows two buttons: "Locate" (B) and
"Highlight" (A overlay). Default action on Issue click = (B).

Owner pick: A / B / C  → default C.


================================================================
Q3.2 — DIALOG CONTAINER
================================================================

PI_TASK_001 §12: "可以使用适合 SU2017+ 的稳定 UI 方式".

(A) HtmlDialog  [Agent default, per PI_TASK_001 §12 hint]
    - Sketchup::HtmlDialog (SU 2017+ stable API).
    - HTML / CSS / JS for layout.
    - Pros: rich layout, modern, easy to iterate.
    - Cons: requires shipping HTML/CSS/JS in the extension; needs
      a callback bridge Ruby → JS for Issue click → locate.

(B) WebDialog (legacy)
    - SU 2017+ still ships it, but deprecated for newer SU.
    - Don't use.

(C) Custom Tool Window (Sketchup::Tool + View.draw)
    - Heavy; requires a Tool class with mouse handlers.
    - Overkill for a read-only result list.

Agent default: (A) HtmlDialog.

Owner pick: A only (B and C are not recommended). No reply = A.


================================================================
Q3.3 — LAYOUT
================================================================

PI_TASK_001 §12 example output:
  Edges: XXXX
  Vertices: XXXX
  Duplicate candidates: XX
  Short edges: XX
  Open endpoints: XX
  Gap candidates: XX
  Non-zero-Z geometry: XX

So a 2-section layout is implied: a header summary, then an issue
list.

(A) SINGLE PAGE — Summary header on top, issue list below [Agent default]
    - Pros: matches §12 example exactly. One screen, one scroll.
    - Cons: lots of issues makes the summary scroll out of view.

(B) TABBED — Summary / Duplicate / Short / Open Endpoints / Gap / Warnings
    - Pros: each issue type gets its own list view.
    - Cons: more clicks; user has to know which tab to look at.

(C) SUMMARY + DRAWER — Summary main, click "Issues (NN)" expands drawer
    - Pros: single page when collapsed, drawer when expanded.
    - Cons: slightly more JS.

Agent default: (A). Matches §12 example output 1:1.

Owner pick: A / B / C  → default A.


================================================================
Q3.4 — VISUAL LANGUAGE
================================================================

PI_TASK_001 §12 says nothing about color. Agent default proposal:

  Severity palette:
    :info     -> neutral grey text "i"
    :warning  -> orange text "!"
    :error    -> red text "✕"   (none emitted in V1.0, but reserved)

  Issue-type icons (text-only, no font deps):
    duplicate -> "="
    short     -> "·"
    open-end  -> "○"
    gap       -> "··"
    non-zero-Z -> "↑Z"
    large-coord -> "!"
    deep-nest -> "{}"

  Highlight color (when Q3.1=A overlay):
    Default: SU Material red (0xCC0000).
    Configurable later via Company Profile.

Owner pick: accept / override per field.


================================================================
Q3.5 — ISSUE CLICK ACTION
================================================================

When Owner clicks an Issue in the list, what happens?

(A) LOCATE only (Q3.1=B zoom + selection) [Agent default]
(B) LOCATE + HIGHLIGHT overlay (Q3.1=A)
(C) OPEN entity in Entity Info panel
(D) COPY entity's persistent_id to clipboard for downstream tooling

Agent default: (A). Owner can hold a modifier key (e.g. Alt) for (B).

Owner pick: A / B / C / D  → default A.


================================================================
Q3.6 — "MODIFY SOURCE CAD" CHECK
================================================================

PI_TASK_001 §91: "原始 CAD: NEVER MODIFY SOURCE CAD".

Stage 6 UI must NOT (even accidentally) provide any "fix" button.
Per §17 V1.0 forbids: auto-delete, gap-join, flatten, weld, polyline
reconstruction, face generation.

Confirm: V1.0 UI is read-only. No fix button, no edit, no
selection-toggle. Just: run, view, locate, close.

This is non-negotiable per PI_TASK_001 §91 / §17. No reply needed.


================================================================
WHAT AGENT WILL DO IF NO OWNER REPLY
======================================

Agent proceeds with defaults:
  Q3.1 = C (hybrid)
  Q3.2 = A (HtmlDialog)
  Q3.3 = A (single page)
  Q3.4 = accept Agent's palette / icons / red overlay
  Q3.5 = A (locate, Alt = highlight)
  Q3.6 = no UI controls that mutate CAD

If Owner wants different, just edit this file and drop answer in
Prompt/.

ANSWER (received 2026-08-17):
  Codex decisions:
    Q3.1 = B  selection + camera zoom ONLY for V1. NO overlay.
    Q3.2 = A  HtmlDialog with capability check / fallback error.
    Q3.3 = A  Single-page summary + grouped issue sections.
    Q3.4 = Use one consistent severity language defined under R005;
           simple text labels / badges, no icon font dep.
    Q3.5 = A  Click = Locate only.
    Q3.6 = confirmed — no fix / edit / repair controls.

  HARD PROHIBITION (overrides earlier Agent default of C hybrid):
    Do NOT add construction lines, boxes, materials, layers/tags or
    any other entities/properties to the model, EVEN TEMPORARILY.
    Creating-and-erasing overlay geometry still mutates the model and
    violates the 100% read-only constraint (PI_TASK_001 §91).
    Selection / camera state are OK because they don't change source
    entity geometry or properties. NO Alt-click overlay in V1.
============================================================
END
============================================================
