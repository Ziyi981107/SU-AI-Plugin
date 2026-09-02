# CURRENT PI REPORT — V17-CODEX-XHIGH-BLOCK-FIX

Project: `SU-AI-Plugin`
Version: V1.7
Stage: V1.7 CODEX xHIGH INTEGRATION BLOCK FIX COMPLETE /
AWAITING AIPM NARROW SOURCE REVIEW (NOT yet V1.7 CLOSED;
mandatory Codex xHigh NARROW recheck of INT-001..INT-005
+ final Owner SU2020 real-host verification gate remain.)
Dispatch: `V17-CODEX-XHIGH-BLOCK-FIX-2026-09-02`
Prior Dispatch: `V17-AIPM-FINAL-PRE-CODEX-FIX-2026-09-02`
Dispatcher / Technical Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Frozen Stage Technical Blueprint:
`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V1_7_GAP_TOPOLOGY_2026-09-01.md`
Codex xHigh integration BLOCK adjudication (the corrections
this dispatch addresses):
`Review/CURRENT_AIPM_REVIEW.md` (REVIEW_ID
`V17-CODEX-XHIGH-BLOCK-ADJUDICATION-2026-09-02`)
Frozen V1.6 Closure Anchor:
`Prompt/AIPM_V1_6_CLOSURE_2026-09-01.md`
Branch: `dev/v1.7`
Source of Truth: `extension/su_ai_plugin/` + canonical contracts in
`PROJECT_HANDOFF` + `PROJECT_MASTER_PLAN_V1X`.

---

## 0. Scope (per dispatch §0)

Correct ALL FIVE accepted Codex xHigh integration BLOCK
findings (INT-001..INT-005) in ONE bounded packet. This is
NOT a redesign.

DO NOT:
- invoke Codex yourself;
- run Owner SU2020 gate;
- start V1.8;
- add new repair types;
- add Observer architecture;
- mutate Source CAD;
- broaden into V1.8 loop/region work.

The frozen V1.7 Stage Technical Blueprint and the frozen
V1.6 closure anchor are PRESERVED UNCHANGED.

---

## A. INT-001..INT-005 disposition

### INT-001 — REMOVE DISCOVERY ORDER FROM NON-TRANSITIVE IDENTITY

ACCEPTED + CORRECTED in `extension/su_ai_plugin/core/canonical_topology_builder.rb`.

The non-transitive cluster id was:
`"ntc-#{comp_idx}-#{_digest_component(...)}"` where
`comp_idx` was the ORIGINAL pre-sort discovery index of
the component. With a DFS-based connected-components
algorithm, the same endpoint membership could produce a
different `comp_idx` when the input was shuffled /
reversed / fed in a different host iteration order, so
the cluster id (and the per-member canonical_node_id
`#{cluster_id}.n#{position}`) was not stable across
rebuilds.

The fix:
- Drop `comp_idx` from the cluster id; the id is now
  `"ntc-#{_digest_component(sorted_indices, epss)}"`,
  derived ONLY from the stable sorted endpoint_keys
  digest.
- The per-member canonical_node_id
  `"#{cluster_id}.n#{position}"` derives its `position`
  from `sorted_indices` (sorted by endpoint_key), which
  is stable across rebuilds.
- Membership is unchanged: non-transitive cluster
  members still get distinct per-member ids
  (Blueprint §7.2).

### INT-002 — CONSERVATIVE SEGMENT OVERLAP / T-JUNCTION SAFETY

ACCEPTED + CORRECTED via a NEW SHARED PURE predicate
`extension/su_ai_plugin/core/segment_conflict.rb` and
refactored callers in `gap_pair_proposer.rb` and
`working_mode_runner.rb`.

The pre-fix code (both the proposer's X3 pairwise check
and the runner's crossing-checker proc) used STRICT
ORIENTATION crossing, which returns false for collinear
cases. So V1.7 could create collinear-overlap bridges
or implicit T-junctions despite the conservative repair
contract.

The fix creates ONE small PURE predicate
`SUAnalysis::Core::SegmentConflict.conflict?(segment_a,
segment_b, eps:)` that detects:
1. proper interior crossing;
2. full collinear containment;
3. partial collinear interior overlap;
4. bridge endpoint strictly inside an unrelated edge
   (T-junction by bridge);
5. unrelated endpoint strictly inside the bridge
   (T-junction by unrelated);
6. simultaneous proposed-bridge overlap/conflict.

Shared endpoints remain SAFE (Blueprint §10.3). Disjoint
collinear segments remain SAFE (dispatch INT-002). The
predicate also exposes
`SegmentConflict.point_in_segment_interior?` for the
canonical-node third-node check.

The predicate is the SINGLE source of truth used by:
- `WorkingModeRunner._crossing_checker_proc` (existing-
  edge crossing safety) — reason code mapped to
  `bridge_crossing` (existing-edge conflict) or
  `third_node_on_bridge` (actual third canonical node on
  bridge interior).
- `GapPairProposer.propose` X3 pairwise check (simultaneous-
  proposal conflict) — reason code mapped to
  `bridge_conflict`.

### INT-003 — PRESERVE PLURAL SOURCE PROVENANCE END-TO-END

ACCEPTED + CORRECTED in `extension/su_ai_plugin/core/endpoint_record.rb`
and `extension/su_ai_plugin/core/gap_pair_proposer.rb`.

The pre-fix code in
`DerivedTopologySnapshotBuilder.build` executed
`Array(rec.source_occurrence_ids).first` and stored only
the singular `source_occurrence_id` in
`DerivedEdgeRecord` and `EndpointRecord`. When a derived
survivor already represented multiple source occurrences,
all but the first were lost before proposal creation.

The fix:
- `EndpointRecord` and `DerivedEdgeRecord` now carry
  `source_occurrence_ids` (PLURAL, frozen, sorted, uniq,
  no nil/empty). The singular `source_occurrence_id`
  accessor is derived from the plural field (first
  element) so older callers still see a single
  representative ID.
- `DerivedTopologySnapshotBuilder.build` now reads
  the FULL `source_occurrence_ids` and normalizes:
  `Array(...).map(&:to_s).reject(&:empty?).uniq.sort`.
- `GapPairProposer.propose` builds
  `incident_source_occurrence_ids` as the FULL
  sorted/uniq union across both incident sides (a + b)
  via the shared `_plurals_union` helper.
- `GapBridgeExecutor.apply` already passes
  `prop['incident_source_occurrence_ids']` (plural) into
  the generated `DerivedEntityRecord`, so the plural
  union survives end-to-end into the
  `CanonicalGeometryGraph` edge's `source_occurrence_ids`.

### INT-004 — VALIDATE HOST STATE BEFORE EVERY V1.7 INTERACTION

ACCEPTED + CORRECTED in `extension/su_ai_plugin/core/working_mode_runner.rb`.

The pre-fix `compute_gap_repair` and `apply_gap_repair` did
not call `validate_host_state_consistency!` BEFORE reading
the current workspace topology/proposal. After a native
SketchUp Undo that erased generated bridge handles, the
next V1.7 interaction could reuse stale logical state and
return early with `NO_CANDIDATE` or `ready.empty?` instead
of failing closed with `host_state_changed`.

The fix:
- `compute_gap_repair`: validate-on-next-V1.7-interaction
  fires AFTER the nil/state guard but BEFORE any
  topology snapshot / proposal recomputation. On
  mismatch: workspace already :failed with reason
  `host_state_changed`; stale V1.7 proposal/canonical
  graph state cleared; truthful failed audit published;
  zero begin_operation.
- `apply_gap_repair`: validation fires BEFORE the
  proposal recomputation AND BEFORE the
  `ready.empty?` early return. A second defense-in-depth
  validation immediately before the executor apply
  catches any race.
- No new Observer architecture. The existing
  `validate_host_state_consistency!` seam (Round-5
  BLOCK-005 §7) is the authoritative source of truth.

### INT-005 — RUBY 2.2 / SU2017 COMPATIBILITY

ACCEPTED + CORRECTED in `extension/su_ai_plugin/core/working_mode_runner.rb`.

The pre-fix
`_attach_topology_repair_to_snapshot` used
`{ ... }.compact.freeze` to build the `canonical_graph`
sub-Hash. `Hash#compact` is Ruby 2.4+; SketchUp 2017
embeds Ruby 2.2.4. So the V1.7 production snapshot
rendering path was incompatible with the frozen
SU2017+ baseline.

The fix:
- Build the digest Hash + `delete_if { |_k, v| v.nil? }`
  + freeze. Same semantics as `Hash#compact` (remove
  pairs whose value is nil) but Ruby 2.2-compatible.
- Audit confirms no other V1.7 production use of
  `Hash#compact` was introduced by this packet.
- Targeted compatibility regression (V17-INT-005-B):
  `Hash#compact` is removed from the test process via
  `Hash.send(:undef_method, :compact)`; the successful
  V1.7 apply + snapshot rendering path continues to
  PASS, and the `canonical_graph` sub-Hash is published
  with digest + schema_version.
- Runtime compatibility evidence (V17-INT-005-C):
  no Ruby 2.2.4 / SketchUp 2017-compatible runtime is
  available on this machine, so the report carries
  `SU2017_RUNTIME_EVIDENCE_PENDING` truthfully; no
  global Ruby tooling was changed. The narrow Codex
  recheck decides whether the static/API-removal
  evidence is sufficient or whether a separate
  Owner/host compatibility probe remains required
  before release.

---

## B. Exact changed production files

This packet created or modified the following production
files:

NEW:
- `extension/su_ai_plugin/core/segment_conflict.rb`
  (the shared PURE V1.7 segment-conflict predicate used
  by the runner's crossing checker and the proposer's
  X3 pairwise check).

MODIFIED:
- `extension/su_ai_plugin/core/canonical_topology_builder.rb`
  (INT-001: drop `comp_idx` from non-transitive
  cluster_id).
- `extension/su_ai_plugin/core/endpoint_record.rb`
  (INT-003: plural `source_occurrence_ids` in
  `EndpointRecord` + `DerivedEdgeRecord`; snapshot
  builder reads the full plural union).
- `extension/su_ai_plugin/core/gap_pair_proposer.rb`
  (INT-002: use shared `SegmentConflict` for X3; INT-003:
  plural `incident_source_occurrence_ids` from
  `_plurals_union` helper).
- `extension/su_ai_plugin/core/working_mode_runner.rb`
  (INT-002: crossing checker delegates to
  `SegmentConflict`; INT-004: validate-on-next-V1.7-
  interaction BEFORE topology/proposal read; INT-005:
  `delete_if { |_k, v| v.nil? }` in place of
  `Hash#compact`).

Tests:
- `tests/test_v17_int_block_fix.rb` (NEW; 23 explicit
  regressions for INT-001..INT-005; full regression
  also covers restored H1-H7, V1.5 BLOCK-005, V1.6 close
  auto-discard, LEGACY-COMPAT, Node DOM, RBZ smoke/load,
  `git diff --check`).

---

## C. Deterministic identity evidence (INT-001)

`tests/test_v17_int_block_fix.rb`:

- V17-INT-001-A: two non-transitive components (size 3
  and size 4) with `eps = 1e-2`. Forward / reverse /
  shuffled endpoint enumeration produce IDENTICAL
  cluster_id sets; each cluster_id has the
  `ntc-{digest}` schema (no discovery ordinal).
- V17-INT-001-B: per-member canonical_node_id set is
  identical across forward / reverse / shuffled input.
- V17-INT-001-C: CanonicalGeometryGraph digest is
  stable across forward vs reversed topology snapshot
  (one unique digest).
- Plus the prior `V17-N1..N6 + N5b` regressions
  continue to pass.

---

## D. Collinear overlap / T-junction safety evidence (INT-002)

`tests/test_v17_int_block_fix.rb`:

- V17-INT-002-A: full collinear containment -> conflict
  (`collinear_overlap`).
- V17-INT-002-B: partial collinear interior overlap ->
  conflict (`collinear_overlap`).
- V17-INT-002-C: bridge endpoint strictly inside
  unrelated edge -> conflict
  (`bridge_endpoint_on_unrelated`).
- V17-INT-002-D: unrelated endpoint strictly inside
  bridge -> conflict (`unrelated_endpoint_on_bridge`).
- V17-INT-002-E: disjoint collinear segments -> SAFE.
- V17-INT-002-F: shared endpoint -> SAFE
  (`shared_endpoint`).
- V17-INT-002-G: [PRODUCTION PATH] collinear
  containment in a real runner topology -> zero
  READY_TO_REPAIR proposals.
- V17-INT-002-H: [PRODUCTION PATH] real almost-closed
  triangle remains READY_TO_REPAIR (no false
  conflict).
- V17-INT-002-I: [PRODUCTION PATH] proposal-vs-proposal
  collinear overlap -> shared predicate reports
  collinear overlap.
- Plus the prior `V17-X1 / X2 / X3 / X4` production
  path tests + `V17-OK-MAP-1 / V17-OK-MAP-2` canonical
  origin_kind mapping tests continue to pass.

---

## E. Plural provenance end-to-end evidence (INT-003)

`tests/test_v17_int_block_fix.rb`:

- V17-INT-003-A: GapPairProposer.propose with
  EndpointRecord / DerivedEdgeRecord carrying plural
  `source_occurrence_ids` (occ-a1 + occ-a2 on side A,
  occ-b1 + occ-b2 on side B, with a deliberate occ-a1
  duplicate that must be deduplicated) ->
  `incident_source_occurrence_ids` = the FULL sorted /
  uniq union `['occ-a1', 'occ-a2', 'occ-b1', 'occ-b2']`.
- V17-INT-003-A-PROD: [PRODUCTION PATH] end-to-end through
  the REAL WorkingModeRunner. A workspace whose
  `DerivedEntityRecord`s carry plural
  `source_occurrence_ids` produces a READY_TO_REPAIR
  proposal whose `incident_source_occurrence_ids`
  contains the full union; the canonical `gap_bridge`
  edge after apply also carries the full union.
- V17-INT-003-B / C / D: plural/singular accessor
  compatibility (backwards-compatible singular
  accessor is derived from the plural list; nil /
  empty / duplicates collapse deterministically).
- Plus the prior `V17-SR6-1` test (plural canonical
  edge contains BOTH source occurrence IDs) continues
  to pass.

---

## F. Undo Check / Apply invalidation evidence (INT-004)

`tests/test_v17_int_block_fix.rb`:

- V17-INT-004-A: [PRODUCTION PATH]
  `compute_gap_repair` after
  `adapter.simulate_host_state_change!` -> workspace
  is `:failed` with `last_error == 'host_state_changed'`;
  zero `begin_operation` from the invalid interaction;
  topology_repair.audit.reason ==
  `'host_state_changed'`; stale V1.7 proposal +
  canonical graph are cleared.
- V17-INT-004-B: [PRODUCTION PATH] `apply_gap_repair`
  after the bridge group handle is `erase!`d (simulating
  native Undo) -> workspace is `:failed` with
  `last_error == 'host_state_changed'`; the audit
  reason is `'host_state_changed'` (NOT a stale
  `no_ready_proposals` skipped); zero `begin_operation`.
- V17-INT-004-C: [PRODUCTION PATH] Discard -> Rebuild
  recovery: after the Undo-invalidated workspace
  reaches `:failed`, `WorkingModeRunner.discard`
  transitions to `:discarded`; the next
  `WorkingModeRunner.rebuild` recovers the workspace
  to `:ready` from the SAME captured source + adapter.
- Plus the prior `V15-B005-3 / B005-4 / B005-5 /
  B005-PROD-1` Round-5 BLOCK-005 tests continue to
  pass (V1.5 BLOCK-005 stays closed).

---

## G. SU2017 / Ruby 2.2 compatibility evidence status (INT-005)

`tests/test_v17_int_block_fix.rb`:

- V17-INT-005-A: static audit. The production V1.7
  path (`working_mode_runner.rb`) has ZERO
  `}.compact` patterns (Hash#compact patterns) after
  the INT-005 fix. The `delete_if { |_k, v| v.nil? }`
  form is used instead.
- V17-INT-005-B: runtime audit. `Hash#compact` is
  removed from the test process via
  `Hash.send(:undef_method, :compact)`. The
  successful V1.7 apply + snapshot rendering path
  continues to PASS, and the `canonical_graph`
  sub-Hash is published with digest + schema_version.
- V17-INT-005-C: this machine runs Ruby 2.7.8
  (`RUBY_VERSION = 2.7.8`); no Ruby 2.2.4 / SketchUp
  2017-compatible runtime is available. The narrow
  Codex recheck decides whether the static / API-
  removal evidence is sufficient or whether a
  separate Owner/host compatibility probe remains
  required before release. No global Ruby tooling
  was changed. Status: `SU2017_RUNTIME_EVIDENCE_PENDING`.

---

## H. Fresh test counts (this dispatch)

- **967 / 967 PASS** / 0 fail / 0 error.
  - Pre-dispatch (HEAD `e1e6275`): 944 / 944 PASS
    (V1.0–V1.7).
  - This dispatch adds 23 explicit INT-001..INT-005
    regressions (`V17-INT-001-A..C`, `V17-INT-002-A..I`,
    `V17-INT-003-A..D + V17-INT-003-A-PROD`,
    `V17-INT-004-A..C`, `V17-INT-005-A..C`).
- `git diff --check`: clean.
- Node DOM (`tests/test_html_render_dom.js`): all
  assertions PASS; final line `PASS`.
- V1.5 BLOCK-005 substring: 149 / 149 PASS.
- V16 substring: 26 / 26 PASS.
- V17 substring: 162 / 162 PASS.
- V14 substring: full suite PASS.
- LEGACY-COMPAT substring: 4 / 4 PASS.
- RBZ substring: 9 / 9 PASS (post-rebuild).

---

## I. Prior regressions (preserved)

- H1-H7 (`tests/test_v17_host_mutation.rb`): PASS
  (RR-03 fix preserved).
- RR-04 pre-batch canonical baseline
  (`tests/test_v17_production_gap_path.rb`,
  `V17-RR04-A..D`): PASS.
- F-01 captured tolerance authority
  (`V17-F01-A`, `V17-F01-B`): PASS.
- F-02 independent proposal-vs-record-vs-host post-
  validate (`V17-F02-A`, `V17-F02-B`, `V17-F02-C`):
  PASS.
- V1.5 BLOCK-005: PASS (149 / 149).
- V1.6 close auto-discard: PASS (7 / 7).
- LEGACY-COMPAT: PASS (4 / 4).
- Node DOM: PASS.
- RBZ smoke + install smoke: PASS.

---

## J. RBZ identity

- Path: `D:\Projects\SU-AI-Plugin\dist\SU-AI-Plugin.rbz`
- Size: **980425 bytes**
- Entries: **68**
- SHA-256: **`058609B141D6AFA6D50E8E87C8D19BA183216E03B3123EC541F842CFDCF828DF`**
- Packaged `html/app.js`, `html/index.html`,
  `html/style.css` SHAs unchanged (no UI changes in
  this dispatch; UI is untouched per the dispatch
  `do NOT add Observer architecture` constraint).
- New `core/segment_conflict.rb` is shipped (1 new
  entry vs prior RBZ).
- Install smoke: extracted entry-point boots through
  FakeUI; menu registered; on_analyze_selection
  no-op fallback.

---

## K. Final implementation commit SHA

Recorded after `git commit` (one production commit
on `dev/v1.7`) — see `git log -1` for the SHA.

---

## L. Remote `dev/v1.7` HEAD

Recorded after `git push origin dev/v1.7` (one
fast-forward push, no force, no rebase). See
`git rev-parse origin/dev/v1.7` post-push.

---

## M. Remaining REAL unknowns only

1. **No actual Ruby 2.2.4 / SketchUp 2017 host
   execution evidence for the V1.7 production path.**
   Static + API-removal evidence is provided. The
   narrow Codex recheck + the final Owner SU2020
   real-host verification gate are the appropriate
   venues to acquire (or explicitly waive) runtime
   compatibility evidence. Status:
   `SU2017_RUNTIME_EVIDENCE_PENDING`.
2. **No new `EdgeRecord` /
   `DerivedEntityRecord` plural-source construction
   at the `SourceReference` level.** The
   `WorkingModeRunner._source_occurrence_id_for` path
   still produces a singular `pid_path` -> `"occ-..."`
   mapping. Plural source occurrence IDs are
   constructible at the `DerivedEntityRecord` level
   (and preserved end-to-end via INT-003), but a
   `SourceReference` that natively carries multiple
   `persistent_id_path` siblings is out of this
   packet's scope (it would broaden the V1.4
   source-snapshot contract; per dispatch
   `do not redesign V1.7`).
3. **`tests/_debug_int_001.rb`,
   `tests/_debug_int_001b.rb`,
   `tests/_debug_int_003.rb`** were used during
   this dispatch to localize the INT-001 test
   geometry (floating-point boundary case) and the
   INT-003 test seam (entity_pairs must be
   `[id, record]`, not just `record`). These debug
   scripts were REMOVED from the working tree
   before commit; they are not in the dispatch's
   final `git status` and are not in the RBZ.

No other remaining unknowns.

---

## Gate lines (per dispatch §7)

```
AIPM_REVIEW: PENDING NARROW DELTA REVIEW
CODEX_RECHECK: REQUIRED — DO NOT SELF-INVOKE
OWNER_GATE: NOT YET RUN
V1.8: NOT STARTED
```

Pi does NOT claim PASS for AIPM / Codex / Owner.

---

## Implementation summary

V1.7 production code is CORRECTED for all five
accepted Codex xHigh integration BLOCK findings
(INT-001..INT-005) in ONE bounded packet on the
assigned `dev/v1.7`, with the frozen V1.7 Stage
Technical Blueprint and the frozen V1.6 closure
anchor preserved unchanged.

Source CAD remains immutable. Derived-first
architecture is preserved. No Observer
architecture was added. No new repair types
were added. V1.8 is NOT started. V2 / MCP remain
out of scope.

Next action: AIPM narrow source review of the
INT-001..INT-005 delta. On AIPM PASS: mandatory
Codex xHigh NARROW recheck of these five
findings only. On Codex PASS: final Owner
SU2020 A-G real-host verification gate.
