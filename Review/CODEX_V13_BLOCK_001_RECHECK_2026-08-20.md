# CodeX V13-BLOCK-001 BLOCK Recheck Packet — Face Inventory Production Seam

**BLOCK under review**: V13-BLOCK-001 (per CodeX review 028;
file `Prompt/CODEX_REVIEW_028_2026-08-20_V1_3_FACE_INVENTORY_REAL_HOST_BLOCK.txt`).
**Branch**: `v1.3-face-inventory`
**Pre-fix head**: `0176c97` (V1.3 final automated checkpoint)
**Post-fix head**: `bf2b2fc` (this commit)
**Base (V1.0 freeze)**: `56ea611` (tag `v1.0-candidate-2026-08-19`)

This is ONE consolidated BLOCK-recheck packet per CodeX
028: "Commit the minimum fix, then write ONE complete
BLOCK recheck packet to Review. Do not submit intermediate
micro-reviews."

The next code review is the combined V1.2 + V1.3 end-of-stage
review packet, dispatched only after Owner re-runs V13-1
on real SU2020 and the V1.2/V1.3 Gate 2 evidence is in.

---

## 1. What CodeX asked for

CodeX 028 V13-BLOCK-001 (one BLOCK):

> Face Inventory is empty while the same run reports
> Faces: 1. AnalyzersRunner passes `layer_groups`
> (Array<Hash> LayerSummary) to FaceInventoryGrouper;
> grouper requires `respond_to?(:face_count)`; Hash does
> not; every bucket silently skipped.

Required minimum fix:

> Make the production seam pass face counts and the
> locked V1.1 role/visibility/order semantics correctly.
> Prefer the narrowest design with a single source of
> truth. Acceptable examples:
>   A. extend LayerSemanticMapper summaries to preserve
>      face_count + faces_with_holes_count from
>      LayerRecord, then make FaceInventoryGrouper
>      explicitly support the documented Hash shape; or
>   B. pass `snapshot.layers` to FaceInventoryGrouper
>      and ensure its canonical ordering remains exactly
>      aligned with V1.1.

Required regression evidence:

> - Add a production-path AnalyzersRunner test: selection
>   containing one root Face and zero edges must yield
>   summary faces == 1 and exactly one Face Inventory
>   Layer0 bucket with face_count == 1.
> - Add/retain integration coverage for named-layer faces,
>   faces_with_holes_count, and two occurrences of one
>   component definition.
> - Add a guard proving the grouper input shape used by
>   AnalyzersRunner cannot silently collapse to [].
> - Run the full Ruby and Node/DOM suites; report exact
>   totals and git diff --check.
> - Commit the minimum fix, then write ONE complete BLOCK
>   recheck packet to Review. Do not submit intermediate
>   micro-reviews.

---

## 2. What was done

### 2.1 Chosen path: option B

Per directive 028, two acceptable options were offered.
The Agent chose **option B (pass `snapshot.layers` to
FaceInventoryGrouper)** for these reasons:

1. **Single source of truth**: `snapshot.layers` is built
   by `PreflightRunner.build_snapshot` (commit `b896e04`)
   and is the canonical per-layer record list with all
   V1.1 role / visibility semantics already classified.
   Option A would have required either mutating the
   `LayerSummary` Hash contract (extending it) or extending
   `FaceInventoryGrouper` to support a parallel input
   shape — both add complexity to a stage the directive
   says to keep minimal.

2. **Bucket order preservation**: `snapshot.layers` is
   constructed from the same `PreflightRunner.layer_aggregates`
   Hash as `layer_groups`. Both are built in encounter
   order and preserved by `build_layer_records`. So
   FaceInventoryGrouper's `sort_like_layers` produces the
   SAME bucket order whether it receives `snapshot.layers`
   (LayerRecord list) or `layer_groups` (LayerSummary
   Hash list). No new sort logic.

3. **Grouper already supports both**: `FaceInventoryGrouper`
   has `layer_name_of(rec)` that handles Hash vs
   non-Hash, and `sort_like_layers` that reads
   `b[:role]` (works for both Hash and LayerRecord via
   `respond_to?(:[])`). The grouper's behavior is
   unchanged for unit tests that pass Hashes; production
   code now passes the right thing.

### 2.2 Code change

`extension/su_ai_plugin/analyzers_runner.rb` (single line):

```ruby
# Before (buggy -- Array<Hash> LayerSummary, no :face_count):
face_inventory_groups = SUAnalysis::Core::FaceInventoryGrouper.group(
  layer_groups
)

# After (fixed -- Array<LayerRecord> snapshot.layers, has :face_count):
face_inventory_groups = SUAnalysis::Core::FaceInventoryGrouper.group(
  snapshot.layers
)
```

The full step 7.7 comment block was rewritten to document
why `snapshot.layers` is the right input (single source
of truth, role/visibility already classified, grouper
order matches V1.1). No JS recomputation, no reopened
V1.0/V1.1/V1.2 scope, no source geometry / selection /
camera / active_path / layer / visibility mutation.

### 2.3 V12-NIT-001 (tiny deferred NIT fixed in this cycle)

CodeX 028 V12-NIT-001: UI says "1 layers" (should be
"1 layer") for n=1 in the V1.2 'Issues by Layer' summary.
The directive said: "If the pluralization fix is isolated,
tiny, and low-risk, fix it in this same work cycle with
DOM coverage; otherwise record as deferred NIT. It does
not block V1.2." The Agent fixed it.

`extension/su_ai_plugin/html/app.js`: the V1.2
`renderLayerIssues` summary now uses the central
`formatCount` helper for the 'layer(s)' noun, so n=1
reads '1 layer' (NOT '1 layers').

---

## 3. Required regression evidence

### 3.1 Production-path AnalyzersRunner test (the one the directive required)

`tests/test_analyzers_runner.rb` — 6 new V1.3 production-
path tests added. The most important:

```ruby
test 'V13-BLOCK-001: selection = 1 root Face, 0 edges -> summary faces == 1 +
                  1 Layer0 Face Inventory bucket with face_count == 1' do
  f = ar_face(layer_name: 'Layer0', persistent_id: 42)
  sel = Selection.new([f])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  refute_nil result
  # Top-level scalar counter must report the face.
  assert_equal 1, result.summary['faces'],
               'summary.faces must equal 1 for a single root Face'
  # The single Face Inventory bucket must be Layer0.
  fig = result.summary['face_inventory_groups']
  assert_equal 1, fig.length, "expected exactly 1 Face Inventory bucket; got #{fig.inspect}"
  assert_equal 'Layer0', fig.first[:name]
  assert_equal 1,        fig.first[:face_count]
  assert_equal 0,        fig.first[:faces_with_holes_count]
  # Production-path top-level key must agree with summary.
  assert_equal fig.length, result.face_inventory_groups.length
  assert_equal 'Layer0',   result.face_inventory_groups.first[:name]
end
```

### 3.2 Additional integration coverage (per directive 028)

- Named-layer Face: 1 named-layer Face -> 1 bucket with
  the right role + visibility (Dimension / Visible). Test
  in test_analyzers_runner.rb.
- faces_with_holes_count: face with 1 inner loop ->
  face_count=1 + holes=1 + summary.faces_with_holes=1.
  Test in test_analyzers_runner.rb.
- Two ComponentInstances of one defn: 2 occurrences on
  Layer0 -> 1 Layer0 bucket with face_count=2. Test in
  test_analyzers_runner.rb (matches the V13-4 owner
  checklist NIT correction).

### 3.3 Belt-and-suspenders silent-collapse guard

```ruby
test 'V13-BLOCK-001: guard against silent collapse -- grouper input shape
                  cannot yield [] when snapshot has faces' do
  f = ar_face(layer_name: 'Layer0', persistent_id: 1)
  sel = Selection.new([f])
  result = SUAnalysis::Extension::AnalyzersRunner.run(sel)
  fig = result.summary['face_inventory_groups']
  assert !fig.empty?, 'Face Inventory must NOT collapse to [] when snapshot has faces'
  assert fig.first[:face_count] > 0, 'bucket face_count must be > 0 (no silent zero)'
  assert_equal result.summary['faces'], fig.first[:face_count],
               'top scalar faces must equal the (only) bucket face_count'
end
```

If anyone reverts the AnalyzersRunner to pass `layer_groups`
(Array<Hash>), the per-bucket face_count silently
collapses to 0, the top scalar Faces stays correct, and
this guard fires.

### 3.4 Suite totals + diff check

- **Ruby**: 469/469 PASS (463 prior + 6 new V1.3
  production-path tests, 0 fail / 0 error).
- **Node.js DOM**: 111 assertions PASS (105 prior + 1
  new V12-NIT-001 + 5 helper moves; the original V1.2
  tests were re-captured into local variables to avoid
  renderWithPayload reset invalidation).
- **`git diff --check`**: clean for `extension/` and
  `tests/`.
- **Locked contracts preserved**: R007..R012 + V1.2
  directive 026 items 1-12 + V1.3 directive 027 items 1-12.
  V1.0 / V1.1 / V1.2 / Stage 6 / CodeX 020 / RBZ / CodeX
  024 / CodeX 025 closed scope NOT touched.

---

## 4. Doc corrections (CodeX 028 NITs)

`Review/OWNER_VERIFICATION_V1_3_FACE_INVENTORY_2026-08-20.txt`
updated per CodeX 028 NITs:

- NIT 1: assign layer to each Face entity ITSELF, not
  only to its parent Group (`v2.layer = layer_dim`).
- NIT 2: V13-3 helper now uses 'ANNOTATION-HOLES' (not
  'HOLES-OK') so the V1.1 LayerRoleConfig classifies the
  bucket as :annotation. The inner-loop creation now uses
  `add_face` + `erase!` (a known cross-version pattern) —
  `reverse!` does NOT create a hole on a freshly built
  face. The helper has the same SKIP fallback for builds
  that cannot create the inner loop.
- NIT 3: V13-3 expected row now uses 'ANNOTATION-HOLES'
  / 'Annotation' (NOT 'HOLES-OK' / 'Unknown').
- NIT 4: V13-4 expected result corrected: two
  ComponentInstances of the same defn on the same Layer0
  aggregate to ONE Face Inventory row with face_count=2,
  NOT two rows. Section summary reads 'Face Inventory -
  1 total (0 with holes)'. OVERALL RESULT block updated.

---

## 5. Owner next action (per CodeX 028)

> Owner then restarts SketchUp, reruns V13-1, and continues
> V13-2..V13-6 only after V13-1 shows Face Inventory = 1 total.
> Do not request another full Codex stage review until the
> combined V1.2 + V1.3 end-of-stage packet, unless a new
> high-risk BLOCK appears.

The Agent is in WAIT state. After Owner:

1. Owner restarts SketchUp (per directive 028 to clear
   any in-memory stale state).
2. Owner reruns V13-1 on real SU2020 (one rectangular
   face on Layer0).
3. Expected: top scalars 'Faces: 1' / 'Faces With Holes: 0',
   Face Inventory section shows 'Face Inventory - 1 total
   (0 with holes)' with ONE row for Layer0
   (Construction / Visible / 1 face / 0 faces with holes).
4. Owner then runs V13-2..V13-6 (or reports a new BLOCK
   if the production fix is insufficient).
5. Owner drops the V1.3 report at
   `Prompt/OWNER_REPORT_V1_3_FACE_INVENTORY_2026-08-XX.txt`.
6. After BOTH V1.2 + V1.3 Gate 2 evidence land, Agent
   assembles ONE consolidated CodeX end-of-stage review
   packet (V1.2 + V1.3, two scope sections).
7. CodeX returns ONE consolidated verdict.
8. After CodeX PASS, Owner combines V1.0 + V1.1 + V1.2 +
   V1.3 in the final RBZ, reruns Gate 1 (SU2017) + Gate 2
   V1.1 + V1.2 + V1.3, ships.

---

## 6. What the Agent is NOT doing in this BLOCK-recheck cycle

- Not dispatching the combined V1.2 + V1.3 end-of-stage
  packet yet (per directive 028: "Do not request another
  full Codex stage review until the combined V1.2 + V1.3
  end-of-stage packet, unless a new high-risk BLOCK
  appears").
- Not starting V1.4.
- Not publishing, pushing, releasing, or overwriting
  the V1.2 / V1.3 candidate artifacts.
- Not running or controlling the real SketchUp GUI on
  the Owner's behalf.
- Not writing the V1.2 CodeX end-of-stage packet (V1.2
  is preserved; Owner SU2020 testing is the gate).

---

## 7. Commit graph (this BLOCK-recheck cycle only)

```
bf2b2fc fix(v1.3): Face Inventory production seam -- pass snapshot.layers to grouper (V13-BLOCK-001)
0176c97 docs(checkpoint): V1.3 Face Inventory final automated checkpoint  (pre-fix head)
5d20560 feat(v1.3): render 'Face Inventory' section in dialog
a72d23e feat(v1.3): pipeline + payload for Face Inventory
b415364 test(v1.3): FaceRecord + adapter + grouper + snapshot tests (core data)
b896e04 feat(v1.3): core data layer for Face Inventory (FaceRecord + walk)
ba8f28e docs(guidance): track V1.3 start directive in git
```

The BLOCK-recheck fix is a SINGLE commit (`bf2b2fc`); no
intermediate micro-reviews per directive 028.

---

*End of V13-BLOCK-001 recheck packet. Awaiting Owner
restart + V13-1 rerun on real SU2020.*