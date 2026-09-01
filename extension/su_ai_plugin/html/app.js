/*
 * extension/html/app.js — UI render + click handler.
 *
 * Per CodeX Round 010..014:
 *   - No eval, no new Function, no document.write, no innerHTML for
 *     user-supplied strings.
 *   - All text rendered via textContent / setAttribute.
 *   - Click -> window.sketchup.locate(issue_id).
 *   - DOMContentLoaded -> window.sketchup.ready() (ready handshake).
 *
 * Per CodeX Round 019 BLOCK-006-R2: the locked Stage 6 plan section
 * 6.7 summary MUST render per-issue-type counts as individual
 * human-readable counters (e.g. "Short edges: 1", "Duplicate
 * candidates: 0") in the canonical order, NOT as
 * "Issues: [object Object]". The scalar header rows (Selection,
 * Edges, Vertices, non-zero-Z vertices, Warnings) are emitted FIRST
 * and the per-issue-type rows are emitted AFTER, one per canonical
 * issue_type, all in a single linear summary block. The order of
 * canonical issue types is locked and matches
 * `SUAnalysis::Core::IssueRegistry::CANONICAL_ISSUE_TYPES`.
 *
 * V1.1 (per plan §4.10):
 *   - renderLayers(payload.layerGroups) renders the dialog Layers
 *     section. Each layer row exposes both a `role` badge AND a
 *     SEPARATE `visibility` badge (R007); they are independent.
 *   - The `<summary id="layers-summary">` text is populated at
 *     render time to "Layers — N total (M with issues)" BEFORE the
 *     user opens the details (so the user sees the count even when
 *     collapsed). Per ChatGPT §11.5.
 *   - Layer rows have `cursor: default` and NO click handler (mirrors
 *     V1.0 L3 non-locatable warning pattern from Round 020).
 *   - NO role color hints (R008); the CSS applies a single neutral
 *     `.layer-row` style and only `data-visible="false"` carries
 *     the muted `opacity: 0.6` style.
 *   - Hidden rows are placed at the BOTTOM of their role bucket by
 *     the Ruby-side mapper (per ChatGPT §11.2 / R009); the JS layer
 *     preserves the locked canonical order it receives and does NOT
 *     re-sort.
 */
(function () {
  'use strict';

  // window.SUAIP is the page-function namespace (render/toast).
  // It does NOT carry host actions (Prepare/Discard/Rebuild);
  // those live on window.sketchup.<callback> (registered by
  // DialogRunner.add_action_callback at boot).
  // See addAction() below for the host-action dispatch path.
  var ROOT = window.SUAIP || (window.SUAIP = {});

  // Locked issue-type labels (matches Stage 6 plan section 6.7).
  // Order matters — the renderer emits them in this order.
  var ISSUE_TYPE_LABELS = [
    ['duplicate_edge_candidate',  'Duplicate Candidates'],
    ['short_edge',                'Short Edges'],
    ['open_endpoint',             'Open Endpoints'],
    ['gap_candidate',             'Gap Candidates'],
    ['significant_non_zero_z',    'Significant Non-zero Z'],
    ['abnormal_large_coord',      'Abnormal Large Coordinate'],
    ['deep_nesting',              'Deep Nesting']
  ];

  // V1.1 (per plan §4.10): locked layer-role labels. 5 canonical roles
  // ONLY (R007 — the OFFSCREEN role Symbol is REMOVED). Order mirrors
  // `SUAnalysis::Core::LayerRole::ALL` and is INDEPENDENT from the
  // issue-type order above (R012). The Ruby mapper already enforces
  // role bucket order when sorting layerGroups; JS preserves the
  // received order without re-sorting.
  var LAYER_ROLE_LABELS = [
    ['dimension',    'Dimension'],
    ['annotation',   'Annotation'],
    ['guide',        'Guide'],
    ['construction', 'Construction'],
    ['unknown',      'Unknown']
  ];

  // V1.1 (per plan §4.10): locked layer visibility labels. Mirrors
  // `SUAnalysis::Core::LayerRole::VISIBILITY_HUMAN` +
  // `LayerRole::VISIBILITY_UNKNOWN_HUMAN`. Per the plan, the
  // visibility_label on each row is pre-computed server-side
  // (LayerRole.visibility_label) and JS uses the per-row string
  // verbatim; this table is exposed for harness introspection only.
  var LAYER_VISIBILITY_LABELS = {
    visible: 'Visible',
    hidden:  'Off-screen',
    unknown: 'Visibility: unknown'
  };

  function render(payload) {
    var sel = document.getElementById('selection-info');
    sel.textContent = payload.selectionLabel + ' (' + payload.selectionType + ')';

    var summary = document.getElementById('summary');
    summary.textContent = '';
    // Phase 1 — locked scalar header rows (Stage 6 plan section 6.7).
    // The selection line is rendered separately as #selection-info,
    // so the summary block is reserved for the snapshot+issue
    // counts. We do NOT include the selection label here to avoid
    // duplicating it.
    // V1.3 (per directive 027 items 1 + 2): the scalar rows include
    // 'Faces' and 'Faces With Holes' as additive counters derived
    // from payload.summary (which UIBridge populates from
    // preflight.face_count + preflight.faces_with_holes_count).
    var scalarKeys = ['edges', 'vertices', 'non_zero_z_vertices', 'warnings',
                     'faces', 'faces_with_holes'];
    scalarKeys.forEach(function (k) {
      var stat = document.createElement('div');
      stat.className = 'stat';
      stat.setAttribute('data-stat', k);
      stat.textContent = humanizeKey(k) + ': ' + (payload.summary ? (payload.summary[k] || 0) : 0);
      summary.appendChild(stat);
    });

    // Phase 2 — locked per-issue-type counters in canonical order.
    // The renderer NEVER falls back to stringifying a nested Hash,
    // so the output is always human-readable. Missing issue types
    // default to 0 (per the locked count-zero-required-categories
    // contract).
    var issues = (payload.summary && payload.summary.issues) || {};
    ISSUE_TYPE_LABELS.forEach(function (pair) {
      var type = pair[0];
      var label = pair[1];
      var stat = document.createElement('div');
      stat.className = 'stat issue-stat issue-type-' + type;
      stat.setAttribute('data-issue-type', type);
      var count = (typeof issues[type] === 'number') ? issues[type] : 0;
      stat.textContent = label + ': ' + count;
      summary.appendChild(stat);
    });

    var groupsEl = document.getElementById('groups');
    groupsEl.textContent = '';
    (payload.groups || []).forEach(function (g) {
      var det = document.createElement('details');
      det.open = !!g.defaultOpen;
      var sum = document.createElement('summary');
      sum.textContent = humanizeType(g.type) + ' (' + g.count + ')';
      det.appendChild(sum);
      (g.issues || []).forEach(function (issue) {
        det.appendChild(renderIssue(issue));
      });
      groupsEl.appendChild(det);
    });

    // V1.1 (per plan §4.10): render the Layers section BELOW the
    // per-issue-type groups block (per ChatGPT §11.1). The function
    // is resilient to undefined / null / non-Array layerGroups — an
    // empty selection or a V1.0 caller that does not supply
    // layerGroups results in an empty list with summary text
    // "Layers — 0 total (0 with issues)".
    renderLayers(payload.layerGroups);

    // V1.2 (per directive 026): render the "Issues by Layer" section
    // AFTER the per-issue-type groups block AND BEFORE the V1.1
    // Layers section. Resilient to undefined / null / non-Array
    // payload.layerIssueGroups — defaults to "Issues by Layer — 0
    // layers (0 issues)" with zero buckets. Issues inside each
    // bucket reuse renderIssue() so the click-to-locate and
    // non-locatable-inert contracts carry through unchanged.
    renderLayerIssues(payload.layerIssueGroups);

    // V1.3 (per directive 027): render the "Face Inventory" section
    // AFTER the V1.1 Layers section. Resilient to undefined / null /
    // non-Array payload.faceInventoryGroups — defaults to "Face
    // Inventory — 0 total (0 with holes)" with zero rows. Rows are
    // aggregate-by-layer (NOT per-face), non-actionable, neutral
    // styling; reuse the V1.1 role + visibility badge semantics.
    renderFaceInventory(payload.faceInventoryGroups);

    // V1.4 (per directive 030, Stage 4): render the "Working Mode"
    // section AFTER V1.3. Resilient to a missing payload.derivedWorkspace
    // (defaults to state='none'). All text via textContent (per the
    // locked textContent-only contract for user-facing text). The
    // action buttons (Prepare / Discard / Rebuild) wire to
    // window.sketchup.<callback> -- the callbacks are
    // registered by DialogRunner.add_action_callback (Ruby
    // side) and exposed by SketchUp's HtmlDialog at
    // window.sketchup.<callback>. window.SUAIP only carries
    // the page functions render/toast (NOT the host actions).
    renderWorkingMode(payload.derivedWorkspace);
  }

  function humanizeKey(k) {
    if (!k) return '';
    return k.split('_').map(function (w) {
      return w.charAt(0).toUpperCase() + w.slice(1);
    }).join(' ');
  }

  // Per Owner Gate 2 V1.1 NIT (1-2): edge / issue counters must
  // (a) pluralize correctly (1 edge vs 4 edges, 1 issue vs 2 issues)
  // and (b) be visually separated so the row does not collapse to
  // "1 edge3 issues" when the flexbox gap is 0 in the host
  // dialog. We centralize the formatter here so both the layer
  // row and any future caller use the same rule.
  function formatCount(n, noun) {
    var count = (typeof n === 'number' && isFinite(n) && n >= 0) ? n : 0;
    return count + ' ' + noun + (count === 1 ? '' : 's');
  }

  function renderIssue(issue) {
    var div = document.createElement('div');
    div.setAttribute('data-issue-id', issue.issue_id || '');
    // Per CodeX Round 020 REAL-HOST BLOCK (recheck) L3: ONLY register
    // the locate click handler when the issue is locatable. For
    // non-locatable rows (preflight warnings like deep_nesting and
    // abnormal_large_coord), the locator returns :unresolved and the
    // JS previously raised a misleading "source no longer available"
    // toast — these rows are intentionally non-locatable (no source
    // token to resolve), NOT stale. Registering no click handler
    // means there is no path to window.sketchup.locate and therefore
    // no path to the toast.
    //
    // Visual non-action state: a `no-action` class so CSS can apply
    // default cursor + remove the hover affordance. This keeps the
    // locked contract that all user text is rendered via textContent
    // (no innerHTML for user-supplied strings).
    var locatable = (issue.locatable === true);
    div.className = 'issue' + (locatable ? '' : ' no-action');
    div.setAttribute('data-locatable', locatable ? 'true' : 'false');

    var sev = (issue.severity || 'low').toLowerCase();
    var badge = document.createElement('span');
    badge.className = 'badge sev-' + sev;
    badge.textContent = sev;

    var meta = document.createElement('span');
    meta.className = 'id';
    meta.textContent = issue.issue_id || '';

    var msg = document.createElement('div');
    msg.className = 'msg';
    msg.textContent = issue.message || '';

    var top = document.createElement('div');
    top.appendChild(meta);
    top.appendChild(badge);

    div.appendChild(top);
    div.appendChild(msg);

    // ONLY register the click handler when the issue is locatable.
    // For locatable === false, the row is intentionally non-actionable;
    // there is no click handler and therefore no path to the stale-
    // source toast (Round 020 REAL-HOST BLOCK L3 fix).
    if (locatable) {
      div.addEventListener('click', function () {
        var id = issue.issue_id || '';
        if (window.sketchup && window.sketchup.locate) {
          window.sketchup.locate(id);
        }
      });
    }

    return div;
  }

  function humanizeType(t) {
    if (!t) return '';
    return t.split('_').map(function (w) {
      return w.charAt(0).toUpperCase() + w.slice(1);
    }).join(' ');
  }

  function toast(msg) {
    var el = document.getElementById('toast');
    if (!el) return;
    el.textContent = msg;
    el.hidden = false;
    setTimeout(function () { el.hidden = true; }, 4000);
  }

  // V1.1 (per plan §4.10): render the dialog Layers section.
  // Populates #layers-list with one .layer-row per group and the
  // #layers-summary text with "Layers — N total (M with issues)"
  // BEFORE the user opens the details. The locked render contract
  // (textContent only, no innerHTML for user strings, no eval,
  // no new Function) is preserved.
  function renderLayers(layerGroups) {
    var layersList = document.getElementById('layers-list');
    var layersSummary = document.getElementById('layers-summary');
    // Defensive: clear the previous render so a re-render does not
    // accumulate. textContent = '' is the spec-clean equivalent of
    // element.innerHTML = '' without touching the locked contract.
    if (layersList) layersList.textContent = '';
    // Coerce undefined / null / non-Array to []. This keeps the
    // no-payload path testable (a V1.0 caller that does not supply
    // layerGroups, or an empty selection, both end up here).
    var groups = Array.isArray(layerGroups) ? layerGroups : [];
    var total = groups.length;
    var withIssues = 0;
    groups.forEach(function (g) {
      if (g && g.issue_count && g.issue_count > 0) withIssues++;
      if (layersList) layersList.appendChild(renderLayerRow(g));
    });
    if (layersSummary) {
      layersSummary.textContent = 'Layers \u2014 ' + total + ' total (' +
                                  withIssues + ' with issues)';
    }
  }

  // V1.2 (per directive 026): render the dialog "Issues by Layer"
  // section. Populates #layer-issues-list with one .layer-issue-bucket
  // per non-empty bucket and the #layer-issues-summary text with
  // "Issues by Layer — N layers (M issues)" BEFORE the user opens
  // the details. Each bucket is a `<details>` with its own summary;
  // issues inside reuse renderIssue() so the existing click-to-
  // locate and non-locatable-inert contracts carry through unchanged.
  // Locked render contract preserved: no innerHTML, no eval, no new
  // Function, no document.write.
  function renderLayerIssues(layerIssueGroups) {
    var listEl = document.getElementById('layer-issues-list');
    var summaryEl = document.getElementById('layer-issues-summary');
    // Defensive: clear the previous render.
    if (listEl) listEl.textContent = '';
    var buckets = Array.isArray(layerIssueGroups) ? layerIssueGroups : [];
    var totalBuckets = buckets.length;
    var totalIssues = 0;
    buckets.forEach(function (b) {
      if (!b || !Array.isArray(b.issues)) return;
      totalIssues += b.issues.length;
      if (listEl) listEl.appendChild(renderLayerIssueBucket(b));
    });
    if (summaryEl) {
      // Per CodeX review 028 V12-NIT-001 (deferred NIT, not blocking
      // V1.2): use the central formatCount helper for the 'layer(s)'
      // noun so the singular form '1 layer' reads correctly when
      // the selection only contributes one layer. The V1.1 Layers
      // section's 'Layers -- N total (M with issues)' wording is
      // already word-independent (always 'total'); the V1.2
      // wording uses 'layer(s)' which the formatCount helper
      // pluralizes correctly.
      summaryEl.textContent = 'Issues by Layer \u2014 ' + formatCount(totalBuckets, 'layer') +
                              ' (' + totalIssues + ' issues)';
    }
  }

  // V1.3 (per directive 027): render the dialog "Face Inventory"
  // section. Populates #face-inventory-list with one .face-inventory-row
  // per layer that has at least one face, and the #face-inventory-summary
  // text with "Face Inventory — N total (H with holes)" BEFORE the user
  // opens the details. Aggregate rows by source face layer (per directive
  // item 4: NOT one UI row per individual face). Rows reuse the
  // V1.1 layer semantics: role badge + visibility badge are SEPARATE
  // (R007), neutral styling, no role color selectors.
  // Locked render contract preserved: no innerHTML, no eval, no new
  // Function, no document.write.
  function renderFaceInventory(faceInventoryGroups) {
    var listEl = document.getElementById('face-inventory-list');
    var summaryEl = document.getElementById('face-inventory-summary');
    if (listEl) listEl.textContent = '';
    var buckets = Array.isArray(faceInventoryGroups) ? faceInventoryGroups : [];
    var totalFaces = 0;
    var totalHoles = 0;
    buckets.forEach(function (b) {
      if (!b) return;
      var fc = (typeof b.face_count === 'number') ? b.face_count : 0;
      var hc = (typeof b.faces_with_holes_count === 'number') ? b.faces_with_holes_count : 0;
      totalFaces += fc;
      totalHoles += hc;
      if (listEl) listEl.appendChild(renderFaceInventoryRow(b));
    });
    if (summaryEl) {
      summaryEl.textContent = 'Face Inventory \u2014 ' + totalFaces +
                              ' total (' + totalHoles + ' with holes)';
    }
  }

  // V1.3: render one Face Inventory row. Per directive 027 item 5:
  //   - layer name;
  //   - face count with correct singular/plural wording;
  //   - count of faces with holes;
  //   - role badge and visibility badge using the V1.1 layer
  //     semantics when available.
  // Per directive item 7: rows are informational and non-actionable.
  // No click handler. No Locate action. Default cursor. No toast.
  // Per directive item 11: no new role colors; reuse neutral
  // styling; severity colors remain exclusive to issue severity.
  function renderFaceInventoryRow(b) {
    var div = document.createElement('div');
    div.className = 'face-inventory-row';
    var role = (b && b.role) ? String(b.role) : 'unknown';
    var visibility_unknown = !!(b && b.visibility_unknown);
    var visible = !!(b && b.visible);
    div.setAttribute('data-role', role);
    div.setAttribute('data-visible', visible ? 'true' : 'false');
    div.setAttribute('data-visibility-unknown', visibility_unknown ? 'true' : 'false');
    div.setAttribute('data-layer-name', (b && b.name) ? String(b.name) : '');

    var name = document.createElement('span');
    name.className = 'layer-name';
    name.textContent = (b && b.name) ? String(b.name) : '';

    var roleBadge = document.createElement('span');
    roleBadge.className = 'role-badge';
    roleBadge.textContent = (b && b.role_label) ? String(b.role_label)
                                                : humanizeKey(role);

    var visBadge = document.createElement('span');
    visBadge.className = 'visibility-badge';
    visBadge.textContent = (b && b.visibility_label) ? String(b.visibility_label)
                                                      : '';

    var facesCell = document.createElement('span');
    facesCell.className = 'face-count';
    var fc = (b && typeof b.face_count === 'number') ? b.face_count : 0;
    facesCell.textContent = formatCount(fc, 'face');

    var facesSep = document.createElement('span');
    facesSep.className = 'face-count-sep';
    facesSep.setAttribute('aria-hidden', 'true');
    facesSep.textContent = '\u00B7'; // middle dot "·"

    var holesCell = document.createElement('span');
    holesCell.className = 'holes-count';
    var hc = (b && typeof b.faces_with_holes_count === 'number') ? b.faces_with_holes_count : 0;
    holesCell.textContent = formatCount(hc, 'face with holes');

    div.appendChild(name);
    div.appendChild(roleBadge);
    div.appendChild(visBadge);
    div.appendChild(facesCell);
    div.appendChild(facesSep);
    div.appendChild(holesCell);
    // No click handler -- Face Inventory rows are non-actionable.
    return div;
  }

  // V1.4 (per directive 030, Stage 4): render the dialog's
  // "Working Mode" section. The source is a snapshot of the
  // WorkingModeRunner (pure-data layer in core/), key
  // payload.derivedWorkspace.
  //
  // Locked contract:
  //   - All user-facing text rendered via textContent (no
  //     innerHTML for user-supplied strings).
  //   - Source-vs-derived ownership is shown by NEVER
  //     recoloring / re-layering / hiding source; the section
  //     is INFO ONLY -- it tells the user where the captured
  //     source snapshot came from and what workspace state
  //     is current.
  //   - Action buttons (Prepare / Discard / Rebuild) wire to
  //     window.SUAIP callbacks exposed by DialogRunner. The
  //     buttons are inert when the action is not available
  //     in the current state (disabled attribute).
  //   - No new role / state color selectors.
  //
  // States:
  //   - 'none'     -> No working copy yet. Show "No working
  //                   copy yet." + Prepare button enabled.
  //   - 'building' -> Workspace is being built. Show
  //                   "Building..." + no action buttons.
  //   - 'ready'    -> Workspace exists. Show entity count +
  //                   config digest + Discard + Rebuild
  //                   buttons.
  //   - 'discarded'-> Workspace was discarded. Show
  //                   "Discarded" + Rebuild button enabled.
  //   - 'failed'   -> A build / discard step raised. Show
  //                   last_error + Rebuild button enabled.
  //
  // V1.6 (per directive V16-UI-INTEGRATION-CORRECTION-2026-09-01):
  // when payload.derivedWorkspace.planar_normalization is an
  // object, render a compact "Planar normalization" block
  // from that sub-snapshot. Exposes the locked Blueprint §11
  // rows (State / Target Z / Eligible / Movable / Outliers /
  // Skipped / Max movement) plus a truthful post-apply
  // audit (when present). Action wiring:
  //   - state == 'NOT_COMPUTED' AND workspace.state == 'ready'
  //     -> "Analyze Planarity" button (callback:
  //     compute_planar_normalization).
  //   - state == 'READY_TO_NORMALIZE'
  //     -> "Apply Safe Normalization" button (callback:
  //     apply_planar_normalization). This destructive
  //     button MUST NOT appear enabled in any other state.
  //   - All other states (REVIEW_REQUIRED / NO_CANDIDATE /
  //     APPLIED / FAILED / invalid_tolerance / invalid_input)
  //     -> NO action button (info only). Existing
  //     Prepare / Discard / Rebuild behavior is unchanged.
  // The Ruby snapshot is authoritative; the JS layer NEVER
  // builds a parallel client-side source of truth. textContent
  // only.
  function renderWorkingMode(derivedWorkspace) {
    var listEl = document.getElementById('working-mode-list');
    var actionsEl = document.getElementById('working-mode-actions');
    var summaryEl = document.getElementById('working-mode-summary');
    if (!listEl || !actionsEl) return;

    // Defensive: missing or wrong-shape payload => 'none'.
    var ws = (derivedWorkspace && typeof derivedWorkspace === 'object')
              ? derivedWorkspace : { 'state': 'none' };
    var state = (typeof ws.state === 'string') ? ws.state : 'none';

    // Clear previous render.
    while (listEl.firstChild) listEl.removeChild(listEl.firstChild);
    while (actionsEl.firstChild) actionsEl.removeChild(actionsEl.firstChild);

    // Summary text (rendered BEFORE user opens the details block,
    // mirroring the V1.1/V1.2/V1.3 sections' convention).
    if (summaryEl) {
      var totalEntities = (typeof ws.entity_count === 'number') ? ws.entity_count : 0;
      if (state === 'none') {
        summaryEl.textContent = 'Working Mode — no working copy';
      } else if (state === 'ready') {
        summaryEl.textContent = 'Working Mode — ' + totalEntities +
                                (totalEntities === 1 ? ' entity' : ' entities') +
                                ' ready';
      } else {
        summaryEl.textContent = 'Working Mode — ' + state;
      }
    }

    // Per-state rows.
    if (state === 'none') {
      addRow(listEl, 'none', null, null, 'No working copy yet. Click Prepare to create one from the current selection snapshot.');
      // V1.5 Phase 1: when a duplicate_repair summary has been
      // recorded (even on a discarded workspace), surface it as
      // a single 'Duplicate repairs' row so the user can see
      // the audit trail after Discard.
      // V1.5 BLOCK-004 (2026-08-25 recheck): the audit row
      // exposes actions_applied/skipped/failed, duplicate
      // classes before/after, duplicate pairs before/after,
      // and derived edge counts before/after. Per-action
      // audit rows are also rendered when present.
      if (ws.duplicate_repair && typeof ws.duplicate_repair === 'object') {
        renderDuplicateRepairAudit(listEl, 'none', ws.duplicate_repair);
      }
      // Prepare button enabled.
      addAction(actionsEl, 'Prepare', 'prepare_workspace', true);
    } else {
      // state in {building, ready, discarded, failed}.
      if (ws.source_snapshot_id) {
        addRow(listEl, state, 'Source Snapshot', ws.source_snapshot_id, null);
      }
      if (ws.source_fingerprint_digest) {
        addRow(listEl, state, 'Source Fingerprint',
               ws.source_fingerprint_digest.substring(0, 12) + '\u2026',
               ws.source_fingerprint_digest);
      }
      if (ws.execution_config_digest) {
        addRow(listEl, state, 'Execution Config',
               ws.execution_config_digest.substring(0, 12) + '\u2026',
               ws.execution_config_digest);
      }
      // V1.5 BLOCK-004: per-state audit row with full counts.
      if (ws.duplicate_repair && typeof ws.duplicate_repair === 'object') {
        renderDuplicateRepairAudit(listEl, state, ws.duplicate_repair);
      }
      if (state === 'failed' && ws.last_error) {
        addRow(listEl, 'failed', 'Last Error', ws.last_error, ws.last_error);
      }
      // V1.6 Planar Normalization / Z Policy (per directive
      // V16-UI-INTEGRATION-CORRECTION-2026-09-01): when
      // payload.derivedWorkspace.planar_normalization is
      // present, render the locked Blueprint §11 rows and
      // (when the state warrants it) the locked action
      // button. All text via textContent (no innerHTML for
      // user-supplied strings). Missing fields degrade
      // safely (text rendering only; no exception path).
      if (ws.planar_normalization && typeof ws.planar_normalization === 'object') {
        renderPlanarNormalization(listEl, state, ws.planar_normalization);
      }
      // Action buttons (locked enable / disable per state).
      addAction(actionsEl, 'Prepare', 'prepare_workspace', state === 'none' || state === 'discarded' || state === 'failed');
      addAction(actionsEl, 'Discard', 'discard_workspace', state === 'ready');
      addAction(actionsEl, 'Rebuild', 'rebuild_workspace',  state === 'ready' || state === 'discarded' || state === 'failed');
      // V1.6 Planar Normalization action button (per
      // dispatch §2.2 + Blueprint §11). The destructive
      // Apply Safe Normalization action is rendered only
      // when the snapshot is explicitly READY_TO_NORMALIZE
      // AND the workspace is ready. The Analyze Planarity
      // preview action is rendered when the normalization
      // state is NOT_COMPUTED AND the workspace is ready
      // (so a fresh Prepare / Discard / Rebuild cycle
      // surfaces the preview action again).
      renderPlanarNormalizationAction(actionsEl, state, ws.planar_normalization);
    }
  }

  // V1.6 Planar Normalization: render the compact "Planar
  // normalization" block. Always renders a "Planar
  // Normalization" State row. When the snapshot carries
  // additional fields (target_z, eligible/movable/outlier
  // counts, max_movement, etc.) AND/OR an audit row, those
  // are rendered too. Defensive: missing / malformed
  // payload degrades to the State row only.
  function renderPlanarNormalization(listEl, workspaceState, pn) {
    if (!pn || typeof pn !== 'object') return;
    var pnState = (typeof pn.state === 'string') ? pn.state : 'NOT_COMPUTED';
    addRow(listEl, workspaceState, 'Planar Normalization',
           'state ' + pnState, 'state ' + pnState);
    // Defensive field accessor: returns fallback when the
    // field is missing / NaN / undefined / not-a-number.
    function n(val, fallback) {
      if (typeof val === 'number' && isFinite(val)) return val;
      if (typeof fallback === 'number') return fallback;
      return null;
    }
    // Render Target Z / Eligible / Movable / Outliers /
    // Skipped / Max movement ONLY when the snapshot
    // carries a non-empty proposal sub-Hash (i.e. the
    // Ruby side has actually computed it). The proposal
    // is omitted by WorkingModeRunner when computed=false
    // (NOT_COMPUTED).
    var proposal = (pn.proposal && typeof pn.proposal === 'object') ? pn.proposal : null;
    if (proposal) {
      var targetZ = n(proposal.target_z, null);
      if (targetZ !== null) {
        // 4 decimals is enough for an inch-scale planarity
        // check (Blueprint §4.1 default = 0.01 inch). We
        // render the raw Float (NOT toFixed) so the Owner
        // sees truthful values regardless of magnitude.
        var targetStr = String(targetZ);
        addRow(listEl, workspaceState, 'Target Z', targetStr, targetStr);
      }
      var eligible = n(proposal.eligible_count, null);
      if (eligible !== null) {
        var s1 = eligible + ' eligible vertices' + (eligible === 1 ? '' : 's');
        addRow(listEl, workspaceState, 'Eligible Vertices', s1, s1);
      }
      var movable = n(proposal.movable_count, null);
      if (movable !== null) {
        var s2 = movable + ' movable ' + (movable === 1 ? 'vertex' : 'vertices');
        addRow(listEl, workspaceState, 'Proposed Movable', s2, s2);
      }
      var outliers = n(proposal.outlier_count, null);
      if (outliers !== null) {
        var s3 = outliers + ' outlier ' + (outliers === 1 ? 'vertex' : 'vertices');
        addRow(listEl, workspaceState, 'Outliers', s3, s3);
      }
      // Affected derived edges = unique derived_ids that
      // participate in the proposal (an Integer count, not
      // the Array itself -- the Array may be very large).
      if (Array.isArray(proposal.affected_derived_ids)) {
        var adCount = proposal.affected_derived_ids.length;
        var s4 = adCount + ' affected derived edge' + (adCount === 1 ? '' : 's');
        addRow(listEl, workspaceState, 'Affected Derived Edges', s4, s4);
      }
      var skipped = n(proposal.shared_vertex_scope_skipped, null);
      if (skipped !== null && skipped > 0) {
        var s5 = skipped + ' shared-vertex scope skipped';
        addRow(listEl, workspaceState, 'Skipped / Ambiguous Scope', s5, s5);
      }
      var maxMv = n(proposal.max_movement, null);
      if (maxMv !== null) {
        var s6 = 'max proposed movement ' + String(maxMv);
        addRow(listEl, workspaceState, 'Max Proposed Movement', s6, s6);
      }
      // Reason row (only when the analyzer / proposer
      // populated a non-empty string).
      if (typeof proposal.reason === 'string' && proposal.reason.length > 0 &&
          pnState === 'REVIEW_REQUIRED') {
        addRow(listEl, workspaceState, 'Review Reason', proposal.reason, proposal.reason);
      }
    }
    // Audit row (only when the executor returned one). The
    // audit is a Hash with status, applied_count, failed_count,
    // max_movement, reason, before_z_summary, after_z_summary,
    // target_z, rule_id, rule_version, etc. (see
    // PlanarNormalizationExecutor._audit_row). We render
    // a compact truthful summary: status, target_z (if
    // present), moved/applied count, max_movement,
    // outlier count, failure reason (if FAILED).
    var audit = (pn.audit && typeof pn.audit === 'object') ? pn.audit : null;
    if (audit) {
      var auditStatus = (typeof audit.status === 'string') ? audit.status : 'unknown';
      var aTarget = n(audit.target_z, null);
      var appliedCount = n(audit.applied_count, null);
      var failedCount  = n(audit.failed_count, null);
      var aMaxMv       = n(audit.max_movement, null);
      var reasonStr    = (typeof audit.reason === 'string' && audit.reason.length > 0)
                         ? audit.reason : '';
      var outlierAuditIds = Array.isArray(audit.outlier_derived_ids)
                            ? audit.outlier_derived_ids.length : null;
      if (aTarget !== null) {
        var ts = 'target Z ' + String(aTarget);
        addRow(listEl, workspaceState, 'Applied Target Z', ts, ts);
      }
      if (appliedCount !== null) {
        var as = appliedCount + ' ' + (appliedCount === 1 ? 'vertex' : 'vertices') + ' applied';
        addRow(listEl, workspaceState, 'Moved / Applied', as, as);
      }
      if (aMaxMv !== null) {
        var ms = 'max movement ' + String(aMaxMv);
        addRow(listEl, workspaceState, 'Max Movement', ms, ms);
      }
      if (outlierAuditIds !== null && outlierAuditIds > 0) {
        var os = outlierAuditIds + ' outlier edge' + (outlierAuditIds === 1 ? '' : 's') + ' unchanged';
        addRow(listEl, workspaceState, 'Outliers Unchanged', os, os);
      }
      if (auditStatus === 'failed' && reasonStr.length > 0) {
        addRow(listEl, workspaceState, 'Failure Reason', reasonStr, reasonStr);
      }
    }
  }

  // V1.6 Planar Normalization action button wiring (per
  // dispatch §2.2 + Blueprint §11):
  //   - state == 'NOT_COMPUTED' AND workspace == 'ready'
  //     -> render ONE "Analyze Planarity" button wired to
  //     compute_planar_normalization.
  //   - state == 'READY_TO_NORMALIZE' AND workspace == 'ready'
  //     -> render ONE "Apply Safe Normalization" button
  //     wired to apply_planar_normalization. This is the
  //     DESTRUCTIVE action; it MUST NOT appear enabled in
  //     any other state (per dispatch §2.2 bullet 2).
  //   - All other states (REVIEW_REQUIRED / NO_CANDIDATE /
  //     APPLIED / FAILED / invalid_tolerance /
  //     invalid_input / undefined pn / non-ready
  //     workspace) -> NO action button.
  // The button is appended AFTER the existing Prepare /
  // Discard / Rebuild buttons so the action row layout is
  // stable.
  function renderPlanarNormalizationAction(actionsEl, workspaceState, pn) {
    if (!pn || typeof pn !== 'object') return;
    var pnState = (typeof pn.state === 'string') ? pn.state : 'NOT_COMPUTED';
    if (workspaceState !== 'ready') return;
    if (pnState === 'NOT_COMPUTED') {
      addAction(actionsEl, 'Analyze Planarity',
                'compute_planar_normalization', true);
    } else if (pnState === 'READY_TO_NORMALIZE') {
      addAction(actionsEl, 'Apply Safe Normalization',
                'apply_planar_normalization', true);
    }
    // All other states: no action button.
  }

  // Helper: append a labelled, factual row to the working-mode list.
  // `state` is the data-state attribute ('none' / 'building' / 'ready'
  // / 'discarded' / 'failed'). `label` is the small heading; `value`
  // is the short text; `title` is the long text (used as a tooltip
  // via the `title` attribute, so no user-text innerHTML).
  function addRow(listEl, state, label, value, title) {
    var row = document.createElement('div');
    row.className = 'working-mode-row';
    row.setAttribute('data-state', state);
    if (label) {
      var labelEl = document.createElement('span');
      labelEl.className = 'label';
      labelEl.textContent = label + ':';
      row.appendChild(labelEl);
    }
    if (value) {
      var valEl = document.createElement('span');
      valEl.className = 'value';
      valEl.textContent = value;
      if (title && title !== value) {
        valEl.setAttribute('title', title);
      }
      row.appendChild(valEl);
    } else if (title) {
      // No short value (state=='none' message); put the message
      // in the row directly.
      var msgEl = document.createElement('span');
      msgEl.className = 'value';
      msgEl.textContent = title;
      row.appendChild(msgEl);
    }
    listEl.appendChild(row);
  }

  // V1.5 BLOCK-004 audit row renderer. Exposes every required
  // technical audit field (applied/skipped/failed, classes
  // before/after, pairs before/after, derived edge counts
  // before/after) plus the per-action audit rows when the
  // Ruby side populates them in `duplicate_repair.actions`.
  function renderDuplicateRepairAudit(listEl, state, dr) {
    var applied = (typeof dr.actions_applied === 'number') ? dr.actions_applied : 0;
    var skipped = (typeof dr.actions_skipped === 'number') ? dr.actions_skipped : 0;
    var failed  = (typeof dr.actions_failed === 'number')  ? dr.actions_failed  : 0;
    // Summary label: applied/skipped/failed + classes + edges.
    var label = 'Duplicate repairs: applied ' + applied +
                ', skipped ' + skipped +
                ', failed '  + failed;
    if (typeof dr.duplicate_classes_before === 'number' &&
        typeof dr.duplicate_classes_after === 'number') {
      label += '; duplicate classes ' +
               dr.duplicate_classes_before + ' \u2192 ' +
               dr.duplicate_classes_after;
    }
    if (typeof dr.duplicate_pairs_before === 'number' &&
        typeof dr.duplicate_pairs_after === 'number') {
      label += '; duplicate pairs ' +
               dr.duplicate_pairs_before + ' \u2192 ' +
               dr.duplicate_pairs_after;
    }
    if (typeof dr.derived_edge_count_before === 'number' &&
        typeof dr.derived_edge_count_after === 'number') {
      label += '; derived edges ' +
               dr.derived_edge_count_before + ' \u2192 ' +
               dr.derived_edge_count_after;
    }
    addRow(listEl, state, 'Duplicate repairs', label, label);
    // Per-action audit rows when present (BLOCK-004
    // CodeX 032 recheck 2026-08-25 minimum): every action
    // row must include status, removed count, survivor ID,
    // and source-occurrence count as visible fields. The
    // UI MUST render these from the summary, not from a
    // hand-built label. textContent only (no innerHTML).
    if (Array.isArray(dr.actions) && dr.actions.length > 0) {
      dr.actions.forEach(function (act) {
        if (!act || typeof act !== 'object') return;
        var status = act.status || 'unknown';
        var actionId = act.action_id || '?';
        var removedCount = (typeof act.removed_count === 'number') ? act.removed_count : 0;
        var survivorId = act.survivor_derived_id || '';
        var sourceCount = (typeof act.source_occurrence_count === 'number') ?
                          act.source_occurrence_count : 0;
        var ruleId = act.rule_id || '';
        var basis = act.confidence_basis || act.explanation || 'no detail';
        // Use a small table-style row so each audit field is
        // independently inspectable from the DOM (DOM tests
        // can assert each cell by its data-action-id +
        // data-field attribute). textContent everywhere.
        var row = document.createElement('div');
        row.setAttribute('data-action-id', actionId);
        row.setAttribute('data-action-status', status);
        if (survivorId) row.setAttribute('data-survivor-id', survivorId);
        row.setAttribute('class', 'action-audit-row');
        var c1 = document.createElement('span');
        c1.setAttribute('data-field', 'status');
        c1.textContent = status;
        row.appendChild(c1);
        var c2 = document.createElement('span');
        c2.setAttribute('data-field', 'action_id');
        c2.textContent = actionId;
        row.appendChild(c2);
        var c3 = document.createElement('span');
        c3.setAttribute('data-field', 'survivor_id');
        c3.textContent = survivorId;
        row.appendChild(c3);
        var c4 = document.createElement('span');
        c4.setAttribute('data-field', 'removed_count');
        c4.textContent = String(removedCount);
        row.appendChild(c4);
        var c5 = document.createElement('span');
        c5.setAttribute('data-field', 'source_count');
        c5.textContent = String(sourceCount);
        row.appendChild(c5);
        var c6 = document.createElement('span');
        c6.setAttribute('data-field', 'rule_id');
        c6.textContent = ruleId;
        row.appendChild(c6);
        var c7 = document.createElement('span');
        c7.setAttribute('data-field', 'basis');
        c7.textContent = basis;
        row.appendChild(c7);
        listEl.appendChild(row);
        // Also surface a compact human-readable summary for
        // quick visual scan (kept for backward-compat with
        // older Node DOM assertions).
        var actLabel = 'action ' + actionId + ' (' + status +
                      '): removed=' + removedCount +
                      ', survivor=' + survivorId +
                      ', sources=' + sourceCount +
                      ', rule=' + ruleId +
                      '; ' + basis;
        addRow(listEl, state, 'Action audit', actLabel, actLabel);
      });
    }
  }

  // Helper: append an action button. `callback` is a SketchUp
  // add_action_callback name (Prepare / Discard / Rebuild).
  // V14-RUNTIME-BLOCK-001 (2026-08-22, real-SU2020 Owner
  // repro): the host action callbacks registered by
  // DialogRunner.add_action_callback live on
  // `window.sketchup.<name>` (NOT `window.SUAIP.<name>` --
  // window.SUAIP only carries the page functions render/toast).
  // The previous addAction resolved via
  // `window.SUAIP[callback]` -- which never matched the real
  // SU callback path -- so the click handler was a no-op on a
  // real SU host (Prepare/Discard/Rebuild buttons did nothing).
  // The fix below resolves via `window.sketchup[callback]`
  // (BRACKET LOOKUP, no eval). When the callback is absent
  // (test env / partial install), the click is a safe no-op
  // (the dialog stays usable).
  function addAction(actionsEl, label, callback, enabled) {
    var btn = document.createElement('button');
    btn.textContent = label;
    btn.setAttribute('data-action', callback);
    if (!enabled) btn.setAttribute('disabled', 'disabled');
    btn.addEventListener('click', function () {
      if (btn.hasAttribute('disabled')) return;
      // No eval; locate the callback on window.sketchup and
      // call it. The callback is registered by
      // DialogRunner.add_action_callback at boot.
      var sk = window.sketchup || {};
      var fn = sk[callback];
      if (typeof fn === 'function') fn();
    });
    actionsEl.appendChild(btn);
  }

  // V1.2: render one layer-issue bucket. Returns a `<details>`
  // element whose summary is "LayerName (N issue(s))" and whose
  // body contains the existing renderIssue() rows for each issue
  // in the bucket. The bucket honors `default_open` (set by
  // LayerIssueGrouper).
  function renderLayerIssueBucket(b) {
    var det = document.createElement('details');
    det.open = !!(b && b.default_open);
    var sum = document.createElement('summary');
    var layerName = (b && b.name) ? String(b.name) : '';
    var count = (b && typeof b.count === 'number') ? b.count : 0;
    // Locked per directive 026 item 6: "Each bucket header must
    // show the layer name and issue count with correct singular/
    // plural wording."
    sum.textContent = layerName + ' (' + formatCount(count, 'issue') + ')';
    det.appendChild(sum);
    var issues = (b && Array.isArray(b.issues)) ? b.issues : [];
    issues.forEach(function (issue) {
      det.appendChild(renderIssue(issue));
    });
    return det;
  }

  // V1.1 (per plan §4.10): render one layer row. The row carries:
  //   - data-role (locked canonical role symbol)
  //   - data-visible (true | false)        — operational layer
  //                                          visibility (R007).
  //   - data-visibility-unknown (true | false) — whether the host
  //                                          capability was missing
  //                                          (R011).
  //   - data-layer-name                    — verbatim layer name.
  // The row exposes BOTH a role badge (e.g. "Dimension") AND a
  // SEPARATE visibility badge ("Visible" / "Off-screen" /
  // "Visibility: unknown"); the two are independent (R007). The row
  // has cursor: default and NO click handler; it is intentionally
  // non-actionable (mirrors V1.0 L3 non-locatable warning pattern).
  function renderLayerRow(g) {
    var div = document.createElement('div');
    div.className = 'layer-row';
    var role = (g && g.role) ? String(g.role) : 'unknown';
    var visibility_unknown = !!(g && g.visibility_unknown);
    var visible = !!(g && g.visible);
    // The Ruby mapper already coerces these to the right shape.
    // We re-check on the JS side for defensive rendering of any
    // future payload shape (e.g. a malformed layerGroups array).
    div.setAttribute('data-role', role);
    div.setAttribute('data-visible', visible ? 'true' : 'false');
    div.setAttribute('data-visibility-unknown', visibility_unknown ? 'true' : 'false');
    div.setAttribute('data-layer-name', (g && g.name) ? String(g.name) : '');

    var name = document.createElement('span');
    name.className = 'layer-name';
    name.textContent = (g && g.name) ? String(g.name) : '';

    var roleBadge = document.createElement('span');
    roleBadge.className = 'role-badge';
    // g.role_label is the source-of-truth server-composed label
    // (LayerRole::HUMAN[role]). We fall back to a humanized
    // version of the role symbol only if role_label is missing.
    roleBadge.textContent = (g && g.role_label) ? String(g.role_label)
                                                : humanizeKey(role);

    var visBadge = document.createElement('span');
    visBadge.className = 'visibility-badge';
    visBadge.textContent = (g && g.visibility_label) ? String(g.visibility_label)
                                                     : '';

    var edgesCell = document.createElement('span');
    edgesCell.className = 'edge-count';
    var edgeCount = (g && g.edge_count != null) ? g.edge_count : 0;
    edgesCell.textContent = formatCount(edgeCount, 'edge');

    // Visible separator between the edge and issue counts. The
    // separator is a real DOM node (not just whitespace) so the
    // mock test harness and any future SR / a11y reader both pick
    // it up reliably. Per Owner Gate 2 V1.1 NIT: prior rendering
    // produced visually-joined text like "1 edge3 issues" when the
    // flexbox gap was 0; this separator makes the join explicit
    // in BOTH the CSS and the textContent.
    var countSep = document.createElement('span');
    countSep.className = 'layer-count-sep';
    countSep.setAttribute('aria-hidden', 'true');
    countSep.textContent = '\u00B7'; // middle dot "·"

    var issuesCell = document.createElement('span');
    var issueCount = (g && g.issue_count != null) ? g.issue_count : 0;
    issuesCell.className = 'issue-count' + (issueCount > 0 ? ' has-issues' : '');
    issuesCell.textContent = formatCount(issueCount, 'issue');

    div.appendChild(name);
    div.appendChild(roleBadge);
    div.appendChild(visBadge);
    div.appendChild(edgesCell);
    div.appendChild(countSep);
    div.appendChild(issuesCell);
    // No click handler — layers are intentionally non-actionable.
    // There is no path to window.sketchup.locate from this row.
    return div;
  }

  ROOT.render = render;
  ROOT.toast   = toast;
  ROOT.ISSUE_TYPE_LABELS       = ISSUE_TYPE_LABELS;
  ROOT.LAYER_ROLE_LABELS       = LAYER_ROLE_LABELS;
  ROOT.LAYER_VISIBILITY_LABELS = LAYER_VISIBILITY_LABELS;
  ROOT.renderLayers            = renderLayers;
  ROOT.renderLayerRow          = renderLayerRow;
  ROOT.renderLayerIssues       = renderLayerIssues;
  ROOT.renderLayerIssueBucket  = renderLayerIssueBucket;
  ROOT.renderFaceInventory     = renderFaceInventory;
  ROOT.renderFaceInventoryRow  = renderFaceInventoryRow;
  ROOT.renderWorkingMode       = renderWorkingMode;
  // V1.6 Planar Normalization / Z Policy: expose the two
  // sub-renderers so the DOM tests (UI1-UI8 per
  // V16-UI-INTEGRATION-CORRECTION-2026-09-01) can call them
  // directly. These are pure functions of (listEl /
  // actionsEl, state, payload) and have no other side effect.
  ROOT.renderPlanarNormalization       = renderPlanarNormalization;
  ROOT.renderPlanarNormalizationAction = renderPlanarNormalizationAction;

  document.addEventListener('DOMContentLoaded', function () {
    if (window.sketchup && window.sketchup.ready) {
      window.sketchup.ready();
    }
  });
})();
