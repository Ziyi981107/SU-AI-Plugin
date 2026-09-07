# SU-AI-Plugin — V1.9A3 Native Toolbar & Product Entry Blueprint

**Date:** 2026-09-07  
**Stage:** V1.9A3 — Native Toolbar & Product Entry  
**Baseline branch:** `dev/v1.9`  
**Baseline HEAD:** `1de098b5d3ab8872294ace3fdb504511512faf13`  
**A2 source review:** PASS  
**A2 Owner real-SU2020:** plugin load verified; workflow Owner gate still pending  
**Implementation Agent:** Pi  
**AIPM / Product & Technical Design:** ChatGPT  
**Codex:** not required unless scope crosses frozen host/ownership boundaries

---

# 0. Owner Summary

V1.9A3 adds the missing native SketchUp product entry:

```text
SketchUp toolbar
    ↓
SU AI button
    ↓
existing CAD Prep command
    ↓
existing Loader.on_analyze_selection
    ↓
existing analysis + HtmlDialog
```

This is a product-shell improvement only.

It must make SU-AI-Plugin behave like a mature SketchUp extension:

- visible native toolbar;
- branded icon;
- tooltip/status text;
- same command reused by menu + toolbar;
- no duplicate business logic;
- respect the user's toolbar visibility choice;
- no new geometry state;
- no A2/V1.9B algorithm change.

---

# 1. Official SketchUp API Basis

Use native:

- `UI::Command`
- `UI::Toolbar`

The same `UI::Command` must be reusable from both the menu and toolbar.

Toolbar state should use:

- `UI::Toolbar#get_last_state`
- `UI::Toolbar#restore`
- `UI::Toolbar#show`

Product rule:

- first-ever toolbar creation: show it;
- later launches: respect SketchUp's remembered hidden/visible state.

Do not forcibly reopen a toolbar the user deliberately hid.

---

# 2. Product Scope

## V1.9A3 ships ONE production toolbar button

Toolbar name:

```text
SU AI
```

Button:

```text
CAD Prep
```

Tooltip:

```text
SU AI · CAD Prep
```

Status bar text:

```text
检查并准备当前选择的 CAD 几何
```

Menu text:

```text
CAD Prep
```

Current and future product architecture may later add:

- Site Model
- Residential Model
- AI Render

but these are NOT shown as disabled placeholders in V1.9A3.

Only real production capability is visible.

---

# 3. Interaction Contract

## With a valid selection

Click toolbar:

```text
CAD Prep
→ existing on_analyze_selection
→ AnalyzersRunner.run
→ DialogRunner.show
→ current V1.9A UI
```

No duplicate controller / analysis path.

## With no selection

Do not silently no-op.

Show a concise SketchUp-native message:

```text
请先选择需要检查和处理的 CAD 几何。
```

Then stop.

This behavior should be shared by menu and toolbar because both invoke the same command.

---

# 4. Command Ownership

The existing Loader currently creates a menu-only `UI::Command`.

Refactor it to create exactly ONE command object and attach it to:

1. existing `SU-AI-Plugin` menu/submenu;
2. new `SU AI` toolbar.

Conceptually:

```text
@cad_prep_command
       ├─ menu
       └─ toolbar
```

Do not create one command for menu and a second command for toolbar.

The command block must call the existing:

```text
on_analyze_selection
```

---

# 5. Toolbar Lifetime / Idempotency

Loader already uses module-level registration state.

Extend that pattern with retained references:

```text
@cad_prep_command
@toolbar
```

Requirements:

- repeated `Loader.register!` must not duplicate menu items;
- must not create duplicate `SU AI` toolbars;
- must not add duplicate toolbar buttons;
- toolbar object should be retained for process lifetime;
- existing live HtmlDialog reference behavior remains unchanged.

Do not attempt unreliable SketchUp menu/toolbar introspection as the primary idempotency mechanism.

Use module-owned state.

---

# 6. Toolbar Visibility Policy

After creating and populating the toolbar:

```text
state = toolbar.get_last_state
```

Desired behavior:

### Never shown before

If the API state is `TB_NEVER_SHOWN`:

```text
toolbar.show
```

so the Owner/user can discover the plugin after installation.

### Previously visible

Use:

```text
toolbar.restore
```

### Previously hidden

Do NOT force-show.

Prefer `restore`, relying on SketchUp's last-state behavior, or an equivalent implementation that respects the remembered hidden state.

The user remains in control.

---

# 7. Icons

Add bundled local PNG icons:

```text
extension/su_ai_plugin/icons/cad_prep_24.png
extension/su_ai_plugin/icons/cad_prep_32.png
```

Assign:

```text
small_icon → 24x24
large_icon → 32x32
```

Visual direction:

- same blue-violet identity as V1.9A UI;
- very simple silhouette;
- recognizable at 24px;
- white CAD/polyline or node/loop symbol;
- transparent background around the icon artwork;
- no tiny text;
- no external image dependency.

The icon should visually read as:

> SU AI / CAD preparation

not as a generic chatbot sparkle.

If Pi cannot produce a polished bitmap safely in the repo, it may create a simple deterministic icon asset and report it for Owner visual review. It must not download icons from the internet.

---

# 8. Expected Code Direction

Preferred change remains inside existing Loader ownership.

Likely:

```text
extension/su_ai_plugin/loader.rb
extension/su_ai_plugin/icons/cad_prep_24.png
extension/su_ai_plugin/icons/cad_prep_32.png
```

Tests + RBZ build files as required.

Avoid creating a separate toolbar framework unless the current Loader becomes materially unclear.

V1.9A3 is one button; simpler is better.

---

# 9. Legacy Compatibility

The feature must remain compatible with the project's SU2017+ policy.

Do not use:

- `UI::Command#extension=`;
- subclassing `UI::Command`;
- modern Ruby syntax outside the existing legacy baseline.

Use stable `UI::Command` / `UI::Toolbar` APIs.

PNG is the preferred icon route for predictable legacy behavior.

---

# 10. No Changes to Product Core

Do NOT change:

- A2 orchestrator;
- presenter state logic;
- DialogRunner callbacks;
- V1.6/V1.7/V1.8 algorithms;
- tolerance authority;
- source/derived ownership;
- Undo/Redo;
- persistent-id reconciliation;
- Face generation;
- Observer architecture;
- V1.9B;
- PreparedCadDataset;
- MCP / LLM / Agent.

Toolbar is an entry point only.

---

# 11. Acceptance Criteria

A3-01. SketchUp shows a native toolbar named `SU AI`.

A3-02. Toolbar contains exactly one production button.

A3-03. Button uses bundled icon assets.

A3-04. Button tooltip is `SU AI · CAD Prep`.

A3-05. Button invokes the exact same `UI::Command` object used by the menu.

A3-06. Valid selection opens the existing production CAD Prep dialog.

A3-07. No selection produces a friendly message instead of silent no-op.

A3-08. `Loader.register!` repeated calls do not duplicate menu/toolbar/button.

A3-09. Toolbar visibility respects remembered SketchUp state.

A3-10. First discovery path shows the toolbar if it has never been shown.

A3-11. No geometry/product-core behavior changes.

A3-12. Icon files are packaged in RBZ.

A3-13. Existing A2 production frontend/orchestrator remains loadable.

A3-14. Full legacy/RBZ regressions remain green except explicitly known pre-existing test-environment failures.

---

# 12. Owner Real-SU2020 Gate

After AIPM source review:

1. install latest RBZ;
2. restart SketchUp 2020;
3. verify `SU AI` toolbar appears;
4. verify icon rendering;
5. hover → tooltip;
6. no selection → friendly message;
7. select CAD geometry → click icon;
8. current V1.9A CAD Prep dialog opens;
9. one-click A2 `开始处理` Owner workflow continues.

This gate can close both:

- A2 real-host workflow;
- A3 native toolbar entry.

END
