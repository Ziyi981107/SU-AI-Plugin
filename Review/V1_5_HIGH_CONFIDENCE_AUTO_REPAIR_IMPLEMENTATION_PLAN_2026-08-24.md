# V1.5 High-Confidence Auto Repair — Implementation Plan
Date: 2026-08-24
For: CodeX V1.5 planning + future Pi implementation (after V1.4 Stage Review PASS)
Per: V1.X master plan §5.5, §6, §8, §16, §17, §19, §20, §21
Status: PLAN-READY (does NOT include production executor code; that lands only after CodeX V1.4 Stage Review PASS + Pi Task dispatch)

======================================================================
0. PURPOSE
======================================================================

This plan turns the V1.4 derived workspace foundation into the first
HIGH-CONFIDENCE auto-repair vertical slice. The first slice is intentionally
narrow:

  "Auto-apply ONLY exact-duplicate and reversed-exact-duplicate edge
   occurrences in the DerivedGeometryWorkspace, with full provenance,
   audit, and rollback. Do nothing else in V1.5 Phase 1."

This is the minimal "trustworthy auto-cleanup" milestone. It MUST be
shippable as a small, reviewable change on top of the V1.4 derived
workspace. Wider repair actions (weld, flatten, gap-close, loop, face,
site) remain parked for later V1.5.x slices and V1.6+.

======================================================================
1. INPUT CONTRACT (READ-ONLY)
======================================================================

Inputs are read-only. The V1.5 Phase 1 executor MUST NOT mutate any
input.

  a) Current SourceSnapshot (frozen).
     - Provides source edges + faces + layers + execution_config
       + transform_context + source_fingerprint.
     - Source edges carry a SourceReference with full persistent_id_path
       (snapshot-local occurrence identity is derived from this path).

  b) Current DerivedGeometryWorkspace.
     - Contains the derived entities built from the SourceSnapshot at
       Prepare time.
     - The workspace is the ONLY place the V1.5 executor is allowed
       to write.
     - Discard and Rebuild of the workspace are still the user's
       primary discard mechanism; Undo is an extra safety layer.

  c) Captured ExecutionConfigSnapshot.
     - Rule set digest + profile + tolerance values.
     - The executor reads the rule_set_digest to know which rule
       produced the candidate RepairAction; the values to apply
       come from the captured config (NOT from live constants).

  d) Analyzer / Issue Registry evidence.
     - The DuplicateDetector already emits
       type='duplicate_edge_candidate' with kind=:edge,
       source_entity_ids, edge_ids, location, severity, etc.
     - The V1.5 Phase 1 executor ONLY consumes the existing
       duplicate_edge_candidate evidence. It does NOT invent a new
       heuristic for "approximate duplicate" / "near duplicate" /
       "geometry-touching" / "collinear overlap".
     - The executor MUST verify that the candidate evidence is
       well-formed before acting (both endpoints coincide within
       `tolerance.duplicate`, both edges are EdgeRecords with
       resolvable source_occurrence_ids).

======================================================================
2. REPAIRACTION CONTRACT (already exists; executor uses it as-is)
======================================================================

Per master plan §5.5 and the existing
`extension/su_ai_plugin/core/repair_plan.rb` (RepairAction / RepairPlan
lifecycle):

  - action_id
  - action_type  (in V1.5 Phase 1: :remove_duplicate_edge ONLY)
  - rule_id      (e.g. "duplicate_edge.exact_remove")
  - confidence   (V1.5 Phase 1: 1.0 for exact / reversed exact,
                  0.95 for two-edges-collapsed-to-same-vertex with
                  identical world coordinates; lower for ANY fuzzy
                  match -- fuzzy matches are NOT auto-applied in
                  V1.5 Phase 1)
  - confidence_basis  (non-empty String naming the observation;
                  e.g. "exact_endpoint_match_within_tolerance.duplicate"
                  or "reversed_endpoint_match_within_tolerance.duplicate")
  - reason             (human-readable)
  - source_record_ids   (snapshot-local occurrence IDs)
  - affected_derived_ids (the derived record IDs to remove + the
                          survivor derived record ID to keep)
  - before_summary      (e.g. {removed_edge_count: 1, kept_edge_count: 1})
  - proposed_after_summary (e.g. {removed_edge_count: 0, kept_edge_count: 1})
  - topology_impact     ("removes_duplicate_edge")
  - auto_applicable     (Boolean -- TRUE in V1.5 Phase 1; the rule is
                          strictly deterministic, no human gate needed)
  - status              (lifecycle: :proposed -> :validated -> :applied /
                          :skipped / :rejected / :failed)
  - validation_result   (ValidationResult.ok or .fail(errors))

V1.5 Phase 1 does NOT change the RepairAction schema. The executor
populates the existing fields.

======================================================================
3. SAFETY BOUNDARIES (HARD RULES, NOT NEGOTIABLE)
======================================================================

  - NEVER touch source entities. The executor operates on the
    DerivedGeometryWorkspace ONLY.
  - NEVER auto-delete a short edge merely because its length is below
    a threshold. "Short Edge" is NOT sufficient evidence for deletion.
  - NEVER handle approximate / fuzzy duplicates. V1.5 Phase 1 handles
    ONLY exact and reversed-exact duplicates within
    `tolerance.duplicate`.
  - NEVER combine different shared-component occurrences by mistake.
    Two ComponentInstances sharing one ComponentDefinition have
    DIFFERENT snapshot-local occurrence IDs; the duplicate detector
    MUST compare occurrences, not definitions.
  - NEVER collapse two derived edges whose world coordinates coincide
    but whose source_occurrence_ids differ. They MAY be different
    occurrences; if the evidence does not prove they are duplicates,
    do nothing.
  - NEVER write to the model root from this slice. The V1.5 Phase 1
    executor writes to the DerivedGeometryWorkspace's
    handle_registry + entity_pairs ONLY. Source groups remain
    untouched.
  - NEVER leave a partial state on failure. If the executor fails
    mid-action, the workspace transitions to :failed and the
    post-state is exactly the pre-state (the workspace's per-entity
    rollback contract -- V1.4 already implemented this).

======================================================================
4. BEHAVIOR CONTRACT
======================================================================

  - Exact duplicate: two derived edges whose source edges have the
    SAME source_occurrence_ids (or whose source occurrences collapse
    to the same pair of world-coordinate endpoints within
    `tolerance.duplicate`) are EQUIVALENT.
    - If the source edges are in the SAME source EdgeRecord (e.g.
      the analyzer emitted duplicate evidence for the SAME edge
      twice), this is an analyzer false-positive -- emit a
      :skipped RepairAction with reason "duplicate_evidence_self_match"
      and do nothing.
    - If the two source edges are DIFFERENT source EdgeRecords
      AND they form an exact endpoint match (forward or reversed),
      keep ONE deterministic survivor and remove the other.
      The survivor is the derived record with the LEXICOGRAPHICALLY
      SMALLER derived_id (deterministic, testable).

  - Reversed exact duplicate: same as exact duplicate, but with
    endpoints in opposite order. Both fall under the same
    equivalence relation; the survivor rule is identical.

  - Survivor selection:
    1. Keep the derived record whose derived_id is
       lexicographically smaller (deterministic).
    2. Ties broken by entity_count tiebreak:
       entity_count (smaller is kept) -> fingerprint bytes (smaller
       digest hex is kept) -> insertion order (first inserted wins).
    3. The decision is recorded in before_summary /
       proposed_after_summary and in the rule_id. Subsequent
       rebuilds MUST produce the same survivor (deterministic
       rebuild).

  - Repeated apply: running the same repair twice on the same
    workspace MUST be a no-op (idempotent). The second run finds no
    duplicate pairs and emits zero actions.

  - Action audit: every action MUST carry status, action_id,
    source_occurrence_ids, affected_derived_ids, before_summary,
    proposed_after_summary, validation_result. The user / CodeX can
    re-derive the action list from the workspace state.

  - Re-analysis: after a successful V1.5 Phase 1 apply, re-running
    the duplicate detector against the post-state SourceSnapshot
    SHOULD show fewer duplicate issues. The workspace must not introduce
    new issues.

  - Failure safety: a failed action leaves the workspace in
    :failed state with no partial pollution. source_fingerprint
    before and after a failed apply MUST be identical.

======================================================================
5. FIRST TEST MATRIX (V1.5 Phase 1)
======================================================================

The test matrix MUST cover both "should repair" and "must not repair"
cases per master plan §19.2:

  SHOULD REPAIR:
    1. Forward exact duplicate: two distinct source edges A->B and
       A->B (same endpoints, same direction). Apply once -> 1 edge.
    2. Reversed exact duplicate: A->B and B->A. Apply once -> 1 edge.
    3. Three identical edges: A->B, A->B, A->B. Apply once -> 1 edge.
    4. Shared-definition two instances of a 4-edge definition: each
       definition edge is itself NOT a duplicate within its
       instance; duplicate pairs across instances are NOT duplicates
       because their source_occurrence_ids differ (snapshot-local
       identity preserved).

  MUST NOT REPAIR:
    5. Legitimate short edge (length below short_edge threshold)
       that happens to coincide with another edge: do NOT remove.
       Reason: short edge is not sufficient evidence for deletion.
    6. Near-but-not-exact duplicate: endpoints within 1.5x
       `tolerance.duplicate` but outside the tolerance: do NOT remove.
       Reason: not an exact duplicate.
    7. Same world coordinates but different source_occurrence_ids:
       do NOT remove. Reason: provenance differs; the duplicate
       detector MUST compare occurrences, not just coordinates.
    8. Self-match (same source_edge emitted twice by the analyzer):
       do NOT remove (emit :skipped with duplicate_evidence_self_match).
    9. Nested transform: same world coordinates but different
       persistent_id_path -> do NOT remove.

  APPLY SAFETY:
    10. Repeated apply idempotency: apply twice -> second call no-ops.
    11. Mid-action failure rollback: simulate host failure during
        dispose; workspace returns to pre-state; status :failed;
        source fingerprint unchanged.
    12. Discard + rebuild after apply: source unchanged; rebuilt
        workspace is the post-state workspace.
    13. Erased / invalid derived entity: skip without raising.
    14. source fingerprint unchanged across apply (successful or failed).

======================================================================
6. IMPLEMENTATION ORDER (post CodeX V1.4 Stage Review PASS)
======================================================================

  1. Pure-data RepairAction / RepairPlan contracts -- ALREADY EXIST
     (extension/su_ai_plugin/core/repair_plan.rb). Verify the existing
     remove_duplicate_edge action type fits the V1.5 Phase 1 schema
     (it does).

  2. Duplicate candidate -> RepairAction proposal:
     - New pure-Ruby helper `core/duplicate_repair_proposer.rb`
       that reads the existing duplicate_edge_candidate evidence
       from the IssueRegistry + SourceSnapshot, verifies exactness
       (endpoint equality within tolerance.duplicate), and emits a
       RepairAction per pair with confidence=1.0,
       confidence_basis naming the rule, status=:proposed.

  3. Derived-only executor:
     - New pure-Ruby helper `core/duplicate_repair_executor.rb`
       that takes a validated RepairAction (status=:validated),
       executes it against the DerivedGeometryWorkspace ONLY,
       and transitions the action to :applied or :failed. Source
       entities are NEVER touched.
     - The executor MUST use the workspace's atomic dispose path
       (per V1.4 derived_geometry_workspace.rb).

  4. Failure rollback / invalid-state:
     - The executor's apply MUST be transactional: on failure,
       roll back the just-removed derived records. The workspace's
       discard path provides the rollback primitive (V1.4 already
       implemented atomic cleanup; the executor calls it on
       failure).

  5. Re-analysis / metrics:
     - Add a V1.5 Phase 1 metric: workspace.duplicate_count_before
       and workspace.duplicate_count_after, exposed via the
       workspace.to_h JSON-safe payload for the dialog summary.

  6. Minimal UI summary:
     - Add a "Duplicate repairs" line in the Working Mode summary
       text (the dialog row count is small; only status / counts,
       no full action list).

  7. Tests:
     - New `tests/test_v15_duplicate_repair.rb` covering the full
     matrix in §5 above (should repair + must not repair + apply
     safety).

  8. Real-host Owner Gate:
     - Add a V15-1..V15-N Owner checklist mirroring V14-1..V14-10
     for the new feature. Owner runs on the rebuilt rbz.

======================================================================
7. STOP CONDITIONS
======================================================================

The following MUST STOP and escalate to CodeX V1.5 planning if hit
during V1.5 Phase 1 implementation:

  - Any path that mutates a source entity, source definition,
    source transform, source layer, source material, source
    visibility, source lock, source scale, source coordinate, or
    source attribute.
  - Any path that merges two distinct source_occurrence_ids into
    one snapshot-local occurrence when the evidence is not exact
    (within `tolerance.duplicate`).
  - Any path that drops the survivor rule (must always be
    deterministic; must always produce the same survivor across
    rebuilds).
  - Any path that introduces a "near duplicate" or "collinear
    overlap" or "approximate duplicate" action type. These are
    V1.6/V1.7 territory.
  - Any path that touches the active-edit context transform in
    a way that changes world coordinates silently.
  - Any path that depends on a host API the existing V1.4 derived
    adapter does not already use (no new SU API surface).
  - Any path that requires an Owner manual one-by-one approval
    for hundreds of safe exact duplicate removals. V1.5 Phase 1 is
    BATCH auto-apply; Owner reviews the SUMMARY, not each action.
  - Any path that requires a real SketchUp install to validate
    (the V1.5 Phase 1 slice is pure-Ruby; the rbz install is only
    needed for the Owner Gate at the end, not for the test suite).

  This Pi Task plan is the IMPLEMENTATION-READY CONTRACT for V1.5
  Phase 1. Pi will NOT start production implementation until:

    1. CodeX V1.4 Stage Review has PASSED.
    2. The V1.4 Owner Gate 2 evidence (V14-1..V14-10) has been
       formally accepted.
    3. A new Pi Task file has been dispatched from Prompt/.

  Until those three conditions are met, this plan is documentation
  only. Do NOT pre-build V1.5 production code under this plan; doing
  so would violate the master plan §21 PI AUTONOMY boundary
  ("reopen frozen unchanged V1.0-V1.3 scope" / "cross into V2 scope
  ahead of review").

======================================================================
8. NON-GOALS (V1.5 Phase 1 explicitly does NOT include)
======================================================================

  - Short edge removal (V1.5 Phase 2 or later, requires additional
    deterministic evidence beyond length).
  - Reversed-exact-duplicate deletion for FaceRecord (V1.5 Phase 2
    or later; Phase 1 is Edges ONLY).
  - Gap closure, weld, flatten, planar normalization, topology
    reconstruction (V1.6+ territory).
  - Loop / region reconstruction (V1.8 territory).
  - Site / road / AI / MCP / V2 (forbidden).

======================================================================
10. STOP
======================================================================

This is the V1.5 Phase 1 implementation-ready plan. Pi does NOT
start production code until CodeX V1.4 Stage Review PASSES and the
formal V1.5 Pi Task is dispatched from Prompt/. See
Prompt/PI_TASK_V1_5_HIGH_CONFIDENCE_AUTO_REPAIR_PHASE1_2026-08-24.txt
for the formal dispatch file (still pending dispatch; this is the
plan side).