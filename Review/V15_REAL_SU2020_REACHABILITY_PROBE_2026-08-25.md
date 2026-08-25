# V1.5 Phase 1 — Real SU2020 Reachability Probe (BLOCK-003)

> !!!  ON HOLD — DO NOT RUN  !!!
>
> STATUS: BLOCKED — see
> Review/V15_PHASE1_UNREACHABLE_INPUT_ESCALATION_2026-08-25.md.
>
> DO NOT install the V1.5 Phase 1 RBZ on SketchUp 2020.
> DO NOT paste any commands in this file into the Ruby Console.
> DO NOT generate
>   Prompt/OWNER_REPORT_V15_REAL_SU2020_REACHABILITY_PROBE_2026-08-25.txt.
>
> This file is preserved as-is for review only. The CodeX
> V1.5 BLOCK RECHECK #2 verdict (a8b7792) and the CodeX BLOCK
> RECHECK #3 attempt in the working tree are both held in
> escrow. CodeX has NOT closed BLOCK-003 (real production
> provenance unreachable on real SU2020). Until Product Owner
> decides between options A, B, and C in
> Review/V15_PHASE1_UNREACHABLE_INPUT_ESCALATION_2026-08-25.md,
> no reachability probe is runnable.
>
> The pre-existing content below is the recheck #3 reachability
> probe draft. It is preserved unchanged (per the "do not
> overwrite existing modifications" rule). Do not execute it as
> written.

Date: 2026-08-25
Branch: v1.5-high-confidence-auto-repair
For: CodeX V1.5 BLOCK-003 recheck #3 (2026-08-25)

## Why this probe exists

Per CodeX V1.5 BLOCK-003 recheck #3 (2026-08-25):

> 当前 Owner fixture 在同一个 ComponentDefinition 中连续两次调用
> entities.add_line，添加端点完全相同的边。SketchUp 的
> Entities#add_line/add_edges 会像原生 Line 工具一样合并、切割
> 重叠几何，不能假定真实 SU2020 会保留两条独立 Edge。
>
> 必须先完成"可达性调查"，再决定实现方向：
>
> 1. 设计一个真实 SU2020 可执行的 Ruby Console 探针，验证同一
>    Entities/container 中是否能同时存在：
>    - 两个不同 Sketchup::Edge 对象
>    - 不同 entityID / persistent_id
>    - byte-identical endpoints

This document is the Owner-runnable probe that answers the
question. Every command below is single-line, copy-paste-safe,
runs in a real SketchUp 2020 Ruby Console, and reports the
host facts the proposer relies on.

## Prerequisites

1. The V1.5 Phase 1 BLOCK-003/004 recheck #3 RBZ
   (`dist/SU-AI-Plugin.rbz`) is installed in the SketchUp 2020
   Plugins folder.
2. A fresh, empty SketchUp 2020 model is open (File > New).
3. Window > Ruby Console is open and pinned.
4. (Optional but recommended) UNCHECK "Show Ruby Console at
   startup" before pasting so the probe output stays clean.

## Helper used by every probe

The probe uses one helper for "grab the currently-active model
+ definitions collection" so the commands are short:

```ruby
mod = Sketchup.active_model
```

All probe commands assume `mod = Sketchup.active_model` is in
scope (paste the helper first).

## PROBE 1 — Can two distinct Sketchup::Edge entities with
              byte-identical endpoints coexist in the same
              Entities collection?

### Step 1a — Clean any prior probe state

```ruby
mod.entities.grep(Sketchup::Group).each { |g| g.erase! if g.name.to_s.start_with?('V15_PROBE_') }; nil
```

EXPECTED: `nil` (no output; the cleanup is silent).

### Step 1b — Create a fresh Group to host the probe edges

```ruby
mod.entities.add_group.tap { |g| g.name = 'V15_PROBE_DUP' }; nil
```

EXPECTED: `nil` (the group handle is discarded by `tap`; we
don't need it). A new Group named "V15_PROBE_DUP" now exists
in the model root.

### Step 1c — Add two coincident edges via the SU `add_line` API

```ruby
mod.definitions['V15_PROBE_DUP'] || mod.entities.grep(Sketchup::Group).find { |g| g.name == 'V15_PROBE_DUP' }
host = mod.entities.grep(Sketchup::Group).find { |g| g.name == 'V15_PROBE_DUP' }
e1 = host.entities.add_line([0, 0, 0], [10, 0, 0])
e2 = host.entities.add_line([0, 0, 0], [10, 0, 0])
[e1.class.to_s, e1.entityID, e1.persistent_id, e2.class.to_s, e2.entityID, e2.persistent_id]
```

EXPECTED:
```
["Sketchup::Edge", <some Integer>, <some Integer>, "Sketchup::Edge", <different Integer>, <different Integer>]
```

CRITICAL ASSERTIONS:
- `e1.class.to_s == "Sketchup::Edge"` (it IS a real SU Edge, not nil)
- `e1.entityID != e2.entityID` (distinct entityIDs)
- `e1.persistent_id != e2.persistent_id` (distinct persistent_ids)

If SU auto-merges the two add_line calls, `e2` would be `nil`
or refer to the same object as `e1`. If that happens, the
topology IS NOT achievable on real SU2020 → BLOCK-003 stays
OPEN; we MUST escalate to CodeX with the captured output.

### Step 1d — Verify the endpoints are byte-identical

```ruby
[e1.start.position.to_a, e1.end.position.to_a, e2.start.position.to_a, e2.end.position.to_a]
```

EXPECTED:
```
[[0.0, 0.0, 0.0], [10.0, 0.0, 0.0], [0.0, 0.0, 0.0], [10.0, 0.0, 0.0]]
```

All four endpoints are byte-identical (SketchUp rounds to
the same Float representation).

### Step 1e — Both edges are present in the container's collection

```ruby
all_edges = host.entities.grep(Sketchup::Edge)
[all_edges.length, all_edges.include?(e1), all_edges.include?(e2), (e1.object_id != e2.object_id)]
```

EXPECTED:
```
[2, true, true, true]
```

CRITICAL:
- `all_edges.length == 2`: two edges exist.
- `all_edges.include?(e1) && all_edges.include?(e2)`: both
  are discoverable via the collection.
- `e1.object_id != e2.object_id`: they are distinct Ruby
  objects.

### Step 1f — The DuplicateDetector path emits a candidate pair

Run the plugin's analysis on the host Group and inspect the
registry for `duplicate_edge_candidate`:

```ruby
load File.join(File.expand_path('~'), 'AppData', 'Roaming', 'SketchUp', 'Sketchup 2020', 'SketchUp', 'Plugins', 'su_ai_plugin.rb')
res = SUAnalysis::Extension::AnalyzersRunner.run(mod.entities.grep(Sketchup::Group).select { |g| g.name == 'V15_PROBE_DUP' })
res.registry.issues.select { |i| i[:issue_type] == 'duplicate_edge_candidate' }.map { |i| { id: i[:issue_id], edge_ids: i[:edge_ids], loc: i[:location], tol: i[:metadata][:duplicate_tolerance] } }
```

EXPECTED:
```
[{ id: "duplicate|0|1", edge_ids: [0, 1], loc: [5.0, 0.0, 0.0], tol: 0.0001 }]
```

CRITICAL: the registry emitted ONE duplicate pair (issue_id
`duplicate|0|1`), with both edge_ids (0 and 1), at the midpoint
(5, 0, 0), with tolerance 0.0001 (the V1.5 Phase 1
duplicate_tolerance default).

### Step 1g — Cleanup the probe fixture

```ruby
mod.entities.grep(Sketchup::Group).each { |g| g.erase! if g.name.to_s.start_with?('V15_PROBE_') }; nil
```

EXPECTED: `nil`. The probe fixture is gone.

## PROBE 2 — Inside one ComponentInstance of a definition that
              has two coincident edges (the actual production
              shape: child entities inside an instance)

### Step 2a — Clean any prior probe state

```ruby
mod.entities.grep(Sketchup::Group).each { |g| g.erase! if g.name.to_s.start_with?('V15_PROBE_') }
mod.definitions.to_a.each { |d| d.instances.each(&:erase!) rescue nil; d.erase! rescue nil }; nil
```

### Step 2b — Create a ComponentDefinition with 2 coincident edges

```ruby
d = mod.definitions.add('V15_PROBE_DEF')
d.entities.add_line([0, 0, 0], [10, 0, 0])
d.entities.add_line([0, 0, 0], [10, 0, 0])
[d.entities.grep(Sketchup::Edge).length, d.entities.grep(Sketchup::Edge).map(&:entityID), d.entities.grep(Sketchup::Edge).map(&:persistent_id)]
```

EXPECTED:
```
[2, [<int>, <int>], [<int>, <int>]]
```

Two edges exist inside the ComponentDefinition, with distinct
entityIDs and persistent_ids.

### Step 2c — Instantiate the definition

```ruby
inst = mod.active_entities.add_instance(d, Geom::Transformation.new)
inst.name = 'V15_PROBE_INST#1'
inst.persistent_id
```

EXPECTED:
```
<some Integer>
```

A new instance PID is assigned.

### Step 2d — Run the analysis and inspect the registry

```ruby
res = SUAnalysis::Extension::AnalyzersRunner.run([inst])
res.registry.issues.select { |i| i[:issue_type] == 'duplicate_edge_candidate' }.map { |i| { id: i[:issue_id], edge_ids: i[:edge_ids], loc: i[:location] } }
```

EXPECTED:
```
[{ id: "duplicate|0|1", edge_ids: [0, 1], loc: [5.0, 0.0, 0.0] }]
```

The registry emitted the duplicate pair inside the
ComponentInstance.

### Step 2e — Cleanup

```ruby
mod.definitions.to_a.each { |d| d.instances.each(&:erase!) rescue nil; d.erase! rescue nil }; nil
```

## PROBE 3 — Two ComponentInstances of the SAME definition
              (the cross-instance shared-definition isolation case)

### Step 3a — Clean any prior probe state

```ruby
mod.entities.grep(Sketchup::Group).each { |g| g.erase! if g.name.to_s.start_with?('V15_PROBE_') }
mod.definitions.to_a.each { |d| d.instances.each(&:erase!) rescue nil; d.erase! rescue nil }; nil
```

### Step 3b — Create the shared definition + 2 instances

```ruby
d = mod.definitions.add('V15_PROBE_SHARED')
d.entities.add_line([0, 0, 0], [10, 0, 0])
d.entities.add_line([20, 0, 0], [30, 0, 0])
i1 = mod.active_entities.add_instance(d, Geom::Transformation.new([100,0,0]))
i2 = mod.active_entities.add_instance(d, Geom::Transformation.new([100,0,0]))
[i1.persistent_id, i2.persistent_id, i1.persistent_id != i2.persistent_id]
```

EXPECTED:
```
[<int>, <int>, true]
```

Two instances with distinct PIDs, placed at the SAME transform
(so their world coords coincide).

### Step 3c — Run the analysis

```ruby
res = SUAnalysis::Extension::AnalyzersRunner.run([i1, i2])
res.registry.issues.select { |i| i[:issue_type] == 'duplicate_edge_candidate' }.map { |i| { id: i[:issue_id], edge_ids: i[:edge_ids], loc: i[:location] } }
```

EXPECTED:
```
[{ id: "duplicate|0|1", edge_ids: [0, 1], loc: [105.0, 0.0, 0.0] }]
```

The DuplicateDetector emits a candidate pair (the two edges
coincide in world space because the instances have the same
transform).

### Step 3d — Verify the proposer preserves the pair
              (different container paths -> applied = 0)

```ruby
SUAnalysis::Core::WorkingModeRunner.reset_for_tests
SUAnalysis::Core::WorkingModeRunner.prepare(
  source:  SUAnalysis::Core::SourceSnapshot.from_geometry_snapshot(
             SUAnalysis::Extension::PreflightRunner.build_snapshot([i1, i2]),
             selection: [],
             execution_config: SUAnalysis::Core::ExecutionConfigSnapshot.from_live_config(SUAnalysis::Core::AnalysisConfig.new(profile_name: 'test')),
             rule_set_digest: 'probe-shared-isolation',
             snapshot_id: 'probe-snap-' + SecureRandom.hex(4),
             captured_at: '2026-08-25T00:00:00Z'
           ),
  adapter: SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new,
  model:   mod
)
SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: res.registry)['duplicate_repair']
```

EXPECTED:
```
{ "duplicate_pairs_before" => 0, "duplicate_pairs_after" => 0,
  "actions_applied" => 0, "actions_skipped" => 1,
  "actions_failed" => 0, "last_action_status" => "skipped" }
```

CRITICAL:
- `actions_applied == 0`: the cross-instance duplicate pair is
  PRESERVED (different container paths).
- `actions_skipped == 1`: the proposer emitted one :skipped
  action with reason `source_occurrence_ids_differ`.

### Step 3e — Cleanup

```ruby
mod.definitions.to_a.each { |d| d.instances.each(&:erase!) rescue nil; d.erase! rescue nil }; nil
```

## Recording the result

The Owner records the captured output from each probe in
`Prompt/OWNER_REPORT_V15_REAL_SU2020_REACHABILITY_PROBE_2026-08-25.txt`:

```
PROBE 1: PASS or FAIL
  Step 1a output: ...
  Step 1b output: ...
  ...
  Step 1g output: ...
  Verdict: 2 distinct Sketchup::Edge entities with byte-identical
  endpoints coexist in the same Entities collection.
  (Or: FAIL. e2 was nil / e1 == e2. Topology NOT achievable.)

PROBE 2: PASS or FAIL
  ...

PROBE 3: PASS or FAIL
  ...
```

If PROBE 1 returns FAIL (SU auto-merges the two add_line calls),
the Owner STOPS and reports BLOCK-003 unreachable — the
Product Owner must decide whether to drop V1.5 Phase 1 SHOULD-
REPAIR entirely or to relax the contract to "approximate
duplicate" (which is explicitly forbidden by master plan §6).

If PROBE 1 returns PASS, the Owner runs PROBE 2 + PROBE 3 to
confirm the production-shape input is reachable. With all 3
probes PASS, BLOCK-003 is closed; V1.5 Phase 1 SHOULD-REPAIR
proceeds as planned.

## STOP

The Owner runs the probes on real SketchUp 2020 and drops the
report. Agent does NOT modify the production code or the
fixtures based on probe output alone; the Owner report is the
authoritative evidence.

Until the Owner report is captured, BLOCK-003 stays OPEN.

## Hard limits (inherited)

- DO NOT modify V1.0–V1.4 closed scope.
- DO NOT enter V1.5 Phase 2 / V1.6+ / V1.7+ / V1.8 / V1.9.
- DO NOT handle short edge / face / gap / weld / flatten /
  AI / MCP / V2.
- DO NOT install the previous RBZ — wait for the recheck #3
  commit.
- DO NOT push, publish, install, or release.

## END OF PROBE PACKET