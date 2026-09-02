# CURRENT AIPM REVIEW

REVIEW_ID: V17-AIPM-FINAL-SOURCE-REREVIEW-2026-09-02
PROJECT: SU-AI-Plugin
STAGE: V1.7 — Endpoint / Gap Repair + Canonical Topology
REVIEWER: AIPM
FINAL PRODUCT OWNER: Owner

REMOTE_HEAD_REVIEWED:
43a3ac080d02d4aa809df7429d0589760a2594b3

VERDICT:
FIX REQUIRED — FINAL TWO NARROW CONTRACT CORRECTIONS

CODEX_GATE: HOLD
OWNER_GATE: HOLD
V1.8: NOT ACTIVE

# 0. OWNER SUMMARY

RR-01..RR-05 are materially corrected and the restored 939-test suite is meaningful.

AIPM final direct source rereview found exactly TWO remaining source-contract defects.

No new architecture is authorized.
No additional review scope should be invented after these two items unless the fixes themselves introduce a new concrete defect.

# 1. PASS / PRESERVE

Preserve unchanged:

- truthful native abort/commit/uncertainty handling;
- one logical bridge = one workspace-owned host bridge;
- restored H1..H7 host mutation suite;
- fail-closed host endpoint capability reads;
- exact canonical pre/post non-transitive comparison;
- deterministic bridge IDs;
- plural provenance;
- unique logical CanonicalGeometryGraph nodes;
- point-on-segment-interior predicate;
- Source CAD immutability;
- endpoint_bridge as the only V1.7 executable repair;
- no Observer architecture;
- V1.8 remains blocked.

# 2. FINAL BLOCK F-01 — PRE-BATCH CANONICAL BASELINE REBUILDS WITH DEFAULT TOLERANCE WHEN CAPTURED KEYS ARE SYMBOLS

## Source finding

`WorkingModeRunner#v17_tolerance` rebuilds tolerance values using string keys only:

- `vals['duplicate']`
- `vals['short_edge']`
- `vals['gap_search']`
- `vals['coordinate_epsilon']`

But `Tolerance#to_h` publishes SYMBOL keys:

- `:duplicate`
- `:short_edge`
- `:gap_search`
- `:coordinate_epsilon`
- etc.

`ExecutionConfigSnapshot.from_live_config` preserves that Hash shape.

Therefore a normal captured SourceSnapshot can carry symbol-keyed tolerance values while `v17_tolerance` silently falls back to defaults.

RR-04's "exact pre-batch canonical baseline" can therefore be rebuilt with a DIFFERENT coordinate_epsilon / gap_search from the proposal/apply path when a non-default profile or override is used.

This violates captured-config authority.

## Required correction

Do not maintain a second tolerance parser.

Preferred:

`v17_tolerance` should delegate directly to the already-correct:

`_tolerance_from_snapshot(@current_source)`

That existing helper already accepts both symbol and string keys and preserves the complete tolerance field set.

Equivalent implementation is acceptable only if it uses the exact same captured-config semantics.

## Required regression

Create a SourceSnapshot whose captured tolerance is deliberately non-default, e.g.:

- gap_search = 0.25
- coordinate_epsilon = 5e-6

Prove:

- compute_gap_repair uses those captured values;
- pre-batch canonical baseline uses the SAME values;
- no silent fallback to 0.1 / 1e-6 occurs.

# 3. FINAL BLOCK F-02 — HARD POST-VALIDATION DOES NOT INDEPENDENTLY COMPARE RECORD/HOST GEOMETRY TO THE READY PROPOSAL

## Source finding

`GapBridgeExecutor._post_validate` correctly looks up the READY proposal to obtain `coordinate_epsilon`.

But the expected endpoints used for host comparison are currently:

- `gs['start']`
- `gs['end']`

where `gs` is the newly-created DerivedEntityRecord's own `geometry_summary`.

The code comment says the host is compared against the READY proposal's expected endpoints, but the implementation compares host output against the derived record that was created from the same mutation path.

The current method also does not independently prove:

- record start/end == proposal expected_bridge_endpoints;
- record length == proposal expected_bridge_length.

This weakens the hard post-validation contract because a wrong record/mutation input can self-consistently agree with the host while disagreeing with the authoritative proposal.

## Required correction

For each applied bridge:

1. resolve the matching READY proposal by proposal_id;
2. fail if no matching proposal exists;
3. read:
   - proposal `expected_bridge_endpoints`
   - proposal `expected_bridge_length`
   - proposal `coordinate_epsilon`
4. independently verify DerivedEntityRecord:
   - geometry_summary start/end match proposal endpoints;
   - geometry_summary length matches proposal expected length;
   - origin_kind and repair_action_id remain correct;
5. independently verify actual host edge endpoints against the PROPOSAL endpoints, not against geometry_summary;
6. use proposal coordinate_epsilon;
7. host segment comparison remains undirected.

Stable reason examples:

- `proposal_not_found:<pid>`
- `record_endpoint_mismatch:<pid>`
- `record_length_mismatch:<pid>`
- existing `host_endpoint_segment_mismatch:<pid>`

## Required regression

Add a test that intentionally creates this contradictory evidence:

- READY proposal expects segment A-B;
- DerivedEntityRecord geometry_summary says A-C;
- fake host edge also reports A-C.

Old code would self-consistently pass host-vs-record.

Correct code MUST fail because both record and host disagree with READY proposal A-B.

Also preserve:
- reversed host endpoint order PASS;
- proposal coordinate_epsilon ownership.

# 4. FINAL GATE

Run fresh:

- focused F-01/F-02 tests;
- full V1.7;
- full Ruby;
- restored H1..H7;
- V1.6 close-autodiscard;
- V1.5 BLOCK-005;
- LEGACY-COMPAT;
- Node DOM;
- RBZ smoke;
- git diff --check.

Rebuild RBZ after production changes.

# 5. REVIEW POLICY

This is the FINAL AIPM pre-Codex correction packet.

After F-01 and F-02 are corrected and pushed:

Pi STOP
→ AIPM verifies only these two deltas
→ if both PASS, AIPM PRIMARY SOURCE REVIEW = PASS
→ mandatory Codex xHigh integration review

Do not open another AIPM correction round for speculative polish.

END
