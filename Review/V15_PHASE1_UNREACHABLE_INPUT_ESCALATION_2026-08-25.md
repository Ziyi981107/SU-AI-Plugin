# V1.5 Phase 1 — Unreachable-Input Escalation to Product Owner (2026-08-25)

> STATUS: BLOCKED
> BLOCKS: V1.5 Phase 1 BLOCK-003 (input reachability) + BLOCK-004 (Owner checklist executability)
> Decision owner: Product Owner
> Decision deadline: BLOCK-003 cannot be closed without real-SU2020 evidence

Date: 2026-08-25
Branch: v1.5-high-confidence-auto-repair
Last committed HEAD: a8b7792 (CodeX BLOCK RECHECK #2)
Working tree at recovery: contained a recheck #3 attempt (production
adapter change, test rewrite, rewritten Owner checklist, and a
new "Real SU2020 Reachability Probe" file). That attempt is held
in escrow and is marked DO NOT RUN; see the on-hold banner at
the top of:
  - Review/OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-25.txt
  - Review/V15_REAL_SU2020_REACHABILITY_PROBE_2026-08-25.md
  - Review/V15_OWNER_GATE_BLOCK_RECHECK_PACKET_2026-08-25.md
See also CURRENT_STATE.md and
Prompt/CODEX_DECISION_REQUEST_V15_BLOCK003_UNREACHABLE_INPUT_2026-08-25.txt.

## 1. Current product contract

V1.5 Phase 1 is locked, per the V1.5 Implementation Plan §6, to:

- Repair only inside `DerivedGeometryWorkspace` (the plugin's
  scratch copy of selection geometry; never source).
- NEVER mutate source entities. Source fingerprint is the
  ground truth.
- NEVER merge duplicates across different container/source
  occurrences. The proposer uses a V1.5 container-occurrence
  identity derived from the source `persistent_id_path` with
  the leaf PID stripped.
- Repair ONLY exact duplicates and reversed-exact duplicates
  (same endpoints, byte-identical, within
  `tolerance.duplicate`). No approximate duplicates, no
  short edges, no face/gap/weld/flatten, no AI/MCP/V2.
- Cross-instance duplicates are PRESERVED even when their
  world coordinates coincide (different container paths).

## 2. Input that the V1.5 implementation requires to be applicable

The proposer's `:remove_duplicate_edge` RepairAction requires:

- Same container occurrence (one V1.5 occurrence = one
  `persistent_id_path` with the leaf PID stripped).
- Inside that occurrence, TWO OR MORE derived
  `EdgeRecord`s whose source `EdgeRecord` leaf PIDs differ
  AND whose endpoints are byte-identical within tolerance.
- The two source edges are reachable as two distinct SU
  edges on real SketchUp — i.e., SketchUp must allow them to
  coexist as two `Sketchup::Edge` entities.

In other words: the production path needs the walk to see
**two distinct `Sketchup::Edge` entities with byte-identical
endpoints inside the same parent container**, where the two
edges have different persistent_ids.

## 3. Why FakeSU can construct this, but real SU2020 may not

SketchUp's official Ruby API documentation for
`Sketchup::Entities#add_line` / `add_edges` states (see
`https://ruby.sketchup.com/file.generating_geometry.html`,
"SketchUp's Geometry Builder behavior"):

- `Entities#add_line(*points)` behaves like the native Line
  tool: when the new edge's endpoints coincide with an
  existing edge's endpoints, **the new edge is NOT created
  as a separate entity** — SketchUp either (a) returns the
  existing edge instead of a new one, or (b) splits/merges
  topology so that no two coincident edges remain in the
  same `Entities` collection.

If real SketchUp 2020 follows that behavior strictly,
the "two `add_line` calls with the same endpoints in the
same Entities collection" pattern cannot produce two
distinct `Sketchup::Edge` entities. The V1.5 Phase 1 SHOULD-
REPAIR input becomes unreachable.

The current `tests/test_v15_real_preflight_path.rb`
(`FakeEntitiesWithEdges` + the uncommitted recheck #3
`FakeEntities#add_line` rewrite) accepts this topology
because FakeSU does not enforce the merge. The CodeX
recheck #2 verdict (a8b7792) flagged this as BLOCK-003:
FakeSU is not authoritative for production behavior.

## 4. Repository search — does the repo contain real-SU2020 evidence that this topology exists?

Per the constraint "只检查仓库和指定总体规划文件，不得扫描电脑"
this search was limited to:

- All files under `D:/Projects/SU-AI-Plugin` (the repo root).
- The single master-plan file
  `E:/dnowload/SU_AI_PLUGIN_V1X_PRODUCT_TECHNICAL_MASTER_PLAN_FOR_CODEX.txt`.

Findings:

- **`Review/` documents** contain zero host captures from
  real SU2020 that show two coincident `Sketchup::Edge`
  entities coexisting in one Entities collection. The
  V1.4-era Owner reports under `Prompt/OWNER_REPORT_*` cover
  real-SU behaviors (Undo / Rebuild / Discard / mid-build
  failure injection) but never document a coincident-edge
  topology.
- **`tests/`** contain only FakeUI / FakeModel / FakeSU
  fixtures; no real-SU captures.
- **`extension/`** production code never invokes
  `add_line` on a real model; the adapter
  (`su_derived_workspace_adapter.rb`) wraps SU's
  `Sketchup.active_model` for the production path but the
  selector-driven walk only READS entities — it does not
  insert them. So the production code itself is neutral
  on the question "can two coincident edges coexist?"
- **`Prompt/` and `Review/`** for the V1.5 Phase 1
  implementation contain NO owner-captured SU2020 output
  showing two coincident edges surviving `add_line`.
- **Master plan §6 / §17** do NOT cite a real-SU2020
  sample of the topology; the implementation plan derives
  the SHOULD-REPAIR path from a logical-deduction
  argument about CAD-import artifacts, not from a host
  capture.

**Conclusion of the repository audit: there is NO
in-repo real-SU2020 evidence that two distinct
`Sketchup::Edge` entities with byte-identical endpoints
can coexist in the same `Entities` collection. The
"two coincident edges inside one CAD-imported
ComponentDefinition" topology is HYPOTHESIZED, not
captured.**

## 5. Verdict

**V1.5 Phase 1 current SHOULD-REPAIR input is NOT proven
reachable on real SU2020.** CodeX BLOCK-003 cannot be
closed on the evidence in the repository.

The recheck #3 attempt in the working tree did not fix
this; it:

1. Added a `class_test_hook=` accessor on
   `SketchupDerivedWorkspaceAdapter` (production code,
   held in the working tree, UNCOMMITTED). This change
   enables the BLOCK-004 C ordering fix but does not
   resolve BLOCK-003.
2. Rewrote `tests/test_v15_real_preflight_path.rb` and
   `tests/_fake_ui.rb` so the FakeSU's `add_line`
   mirrors the **"no auto-merge"** behavior. This is
   precisely the contract CodeX rejected (FakeSU cannot
   prove real-SU behavior).
3. Wrote a new `Review/V15_REAL_SU2020_REACHABILITY_PROBE_2026-08-25.md`
   asking the Owner to install the V1.5 Phase 1 RBZ and
   paste probe commands into the SU2020 Ruby Console.
   This contradicts the policy "real SU verification is
   OWNER's responsibility; do NOT ask Owner to install
   before Product Owner decision" and "do NOT install the
   previous RBZ".
4. Rewrote `Review/OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-25.txt`
   to fix the BLOCK-004 defects A-E but the entire
   checklist is blocked behind the BLOCK-003 question.

The working tree as a whole is held in escrow (per the
on-hold banners); none of these changes are committed in
this checkpoint.

## 6. Options for Product Owner

Three product-level choices are presented. The Agent does
NOT pick. The Product Owner must decide.

### Option A — Pause current Phase 1 SHOULD-REPAIR and pick a different vertical slice

- **User value:** a different repair type that is
  reachable on real SU2020 (for example: zero-length
  edge pruning INSIDE a derived copy; or duplicate
  face-removal inside one container that has been
  independently verified on real SU). The vertical
  slice becomes runnable end-to-end.
- **Source / data risk:** low — a new slice will be
  scoped inside the same DerivedGeometryWorkspace
  contract and will reuse the proposer / executor
  patterns. No new source-occurrence rules are
  introduced.
- **Conflict with master plan:** MAY conflict with the
  current §6 vertical-slice choice. The master plan
  lists SHOULD-REPAIR (exact / reversed-exact duplicate
  edges) as the Phase 1 vertical slice. A replacement
  slice would need a new plan addendum (CodeX Pre-build
  Review required).
- **Estimated scope of change:** new implementation
  plan section + new CodeX Pre-build Review + new
  vertical-slice commit. BLOCK-003 closes by being
  scoped away; BLOCK-004 closes by being rewritten
  from scratch against the new slice.
- **Requires new CodeX Pre-build Review:** YES.

### Option B — Relax the provenance contract (allow some cross-occurrence duplicates)

- **User value:** widens the SHOULD-REPAIR input to
  include cases where two coincident edges live in
  different parent containers (different instance PIDs
  but coincident world coords, or different source
  occurrences). The repair scope grows.
- **Source / data risk:** HIGH. The current contract
  forbids merging across container/source occurrences
  precisely because two coincident CAD lines that look
  identical may NOT be redundant — they may be
  intentional cross-instance geometry (mirrored
  instances, mirrored stories, mirrored floors).
  Auto-merge would silently destroy intentional
  duplication. The CodeX V1.5 §17.2 contract
  ("cross-instance duplicates PRESERVED") is built on
  this concern. Relaxing it requires a documented
  product justification and an opt-in scope
  (probably a user-toggled "allow cross-instance
  merge" flag, NOT a default behavior).
- **Conflict with master plan:** YES. Master plan §17.2
  explicitly requires PRESERVATION of cross-instance
  duplicates. Relaxing the contract requires either
  a plan amendment or a guardrail flag. A CodeX
  Pre-build Technical Preview is required BEFORE any
  implementation; do NOT implement directly.
- **Estimated scope of change:** plan addendum +
  Pre-build Technical Preview + new flag in
  `ExecutionConfigSnapshot` + proposer contract
  change + new BLOCK-004 Owner checklist + new tests.
  This is a substantial body of work and re-opens
  the contract.
- **Requires new CodeX Pre-build Review:** YES (a
  Pre-build Technical Preview specifically, not just
  a recheck).

### Option C — Keep Phase 1 as audit/proposal-only; defer auto-repair

- **User value:** users still get a SHOULD-REPAIR
  REPORT (which occurrences have a duplicate pair,
  and how many derived records would be removed). No
  data is touched. Users can review the report and
  decide manually.
- **Source / data risk:** NONE — the workspace is
  never mutated. The audit-only path is safe even if
  the topology is uncertain.
- **Conflict with master plan:** MAY conflict with
  §6's "high-confidence auto-repair vertical slice"
  intent. Auto-repair is the headline feature.
  Audit-only is a graceful downgrade but reduces
  Phase 1 to a reporting feature; the user value is
  limited. If master plan can be amended to allow
  audit-only as Phase 1, this is the safest path.
- **Estimated scope of change:** small. Strip the
  executor's apply path from the V1.5 Phase 1
  scope; keep the proposer as a "report-only" mode
  that records `actions_proposed` instead of
  `actions_applied`. The dialog shows "would-apply"
  numbers. No new tests beyond confirming the report
  numbers match the existing SHOULD-REPAIR detection.
- **Requires new CodeX Pre-build Review:** YES (a
  narrow re-scoping addendum). BLOCK-003 closes by
  becoming moot (no apply → no need to prove
  reachability of the apply input). BLOCK-004 closes
  with a new audit-only checklist.

## 7. Recommendation framework (not a decision)

Each option above is presented neutrally. The Agent does
NOT recommend a specific option. The Product Owner should
weigh:

- Time-to-value vs safety
- Whether the master plan §6 vertical slice is the right
  starting point given the FakeSU-vs-real-SU gap surfaced
  by BLOCK-003
- Whether audit-only Phase 1 (Option C) buys time to
  collect real-SU2020 samples and resume Phase 1 apply
  later
- Whether Option B's user value justifies opening the
  cross-instance contract (which the master plan currently
  forbids)

## 8. Status of uncommitted work (held in escrow)

The following files in the working tree are NOT committed
in this checkpoint; they are preserved (per the "do not
overwrite existing modifications" rule) and marked DO NOT
RUN where Owner-runnable:

- `extension/su_ai_plugin/compatibility/su_derived_workspace_adapter.rb`
  — production code change adding `class_test_hook=`
  accessor + class-level hook consumption in `dispose`.
  Status: held in escrow, UNCOMMITTED. **NOT approved for
  production** until BLOCK-003 is resolved and BLOCK-004
  is rewritten against a confirmed vertical slice.

- `tests/_fake_ui.rb` — adds `add_line(*points)` method on
  FakeEntities with "no auto-merge" semantics. Status:
  held in escrow, UNCOMMITTED. **NOT a substitute for
  real-SU evidence**.

- `tests/test_v15_real_preflight_path.rb` — rewritten to
  use the FakeSU `add_line` API and a Group-based fixture.
  Status: held in escrow, UNCOMMITTED. Tests fail (see
  CURRENT_STATE.md and the test report) because the
  Group-based fixture does not exercise the walk's
  ComponentInstance path.

- `Review/OWNER_VERIFICATION_V1_5_DUPLICATE_REPAIR_2026-08-25.txt`
  — recheck #3 rewrite. Status: marked DO NOT RUN at the
  top of the file. Held in escrow.

- `Review/V15_REAL_SU2020_REACHABILITY_PROBE_2026-08-25.md`
  — recheck #3 new file. Status: marked DO NOT RUN at the
  top of the file. Held in escrow.

- `Review/V15_OWNER_GATE_BLOCK_RECHECK_PACKET_2026-08-25.md`
  — recheck #3 packet. Status: marked DO NOT RUN at the
  top of the file. Held in escrow.

- `CURRENT_STATE.md` — updated with the recheck #3 attempt
  in the working tree. THIS ESCALATION checkpoint updates
  it again to reflect actual current status (held in
  escrow, awaiting Product Owner decision).

The committed state at `a8b7792` is the LAST VERIFIED
GREEN state on the BLOCK-001/002/005 closed subset. Its
700/700 Ruby / 154/154 Node / clean diff-check / clean
working tree baseline is the only state that has CodeX
verification for those three closed BLOCKs. The
uncommitted recheck #3 changes do NOT extend that green
state; they only attempt to address BLOCK-003 / BLOCK-004,
which remain open.

## 9. RBZ status

The last-built RBZ is the `a8b7792` candidate
(SHA256 8C1162031C76B3E984906D821FBDB523D7241EC20D8400CF3C931061FBABD2D4,
504298 bytes, 55 entries). This RBZ is an UNAPPROVED
candidate and is NOT to be installed. No new RBZ is built
in this checkpoint (no production code change is
committed; the production change is held in the working
tree).

## 10. STOP. Awaiting Product Owner decision.

Until Product Owner selects A / B / C and CodeX is
re-engaged, this escalation is the canonical state. The
Agent will not commit the production change, will not
install the RBZ, will not push, will not publish, and
will not enter V1.5 Phase 2 / V1.6+ / V1.7+ / V1.8 /
V1.9 / V1.5-Phase-2.