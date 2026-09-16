# AIPM STAGE TECHNICAL BLUEPRINT — V2-0B HOST GEOMETRY PROBE

Date: 2026-09-16
Project: SU-AI-Plugin
Target branch: `dev/v2`
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Status: FROZEN FOR IMPLEMENTATION

## 0. Owner intent

V2-0A is CLOSED / PASS.

V2-0B proves one thing only:

> one valid, current V2 `SemanticFootprint` can be written into real SketchUp as one independent V2-owned mass, inside one normal undoable operation, with fail-closed stale/context checks and confirmed rollback semantics.

This is NOT residential modeling and NOT product UI.

No V2-0B code may guess geometry, modify V1 source/derived geometry, or bypass the current PreparedCadDataset freshness authority.

## 1. Frozen scope

IN SCOPE:

- consume an already-valid V2-0A `SemanticFootprint`;
- re-resolve fresh V1 PreparedCadDataset immediately before host mutation;
- compare full `content_digest`;
- re-project and re-resolve the exact footprint identity;
- require root edit context;
- create one new V2-owned top-level SketchUp Group at model root;
- create one Face from the footprint's projected z=0 coordinates;
- orient the Face to +Z;
- extrude it upward by one explicit positive probe height;
- validate the created mass;
- commit as one normal SketchUp operation;
- confirmed rollback on construction/validation/commit failure;
- session lock when rollback cannot be confirmed;
- host-free automated contract tests;
- one developer/Owner real-SketchUp probe script for native Undo / rollback verification.

OUT OF SCOPE:

- selection Tool / pickray / highlighting;
- HtmlDialog / toolbar / menu;
- ResidentialObject;
- floors / seams / balconies / parapets;
- update/regenerate;
- site / raised community / roads / landscape;
- materials;
- MCP / LLM / Agent;
- V3;
- V1 changes;
- pcd.v1 changes;
- CanonicalStructureReconstructor changes.

## 2. Official host-contract references reviewed

The implementation must remain compatible with SketchUp 2017+ / Ruby 2.2-era syntax.

Authoritative host facts used by this Blueprint:

1. `Sketchup::Model#start_operation`, `#commit_operation`, `#abort_operation` return Boolean. Operations are sequential and cannot be nested. A normal operation is the unit presented to native Undo.
   - https://ruby.sketchup.com/Sketchup/Model.html#start_operation-instance_method
   - https://ruby.sketchup.com/Sketchup/Model.html#commit_operation-instance_method
   - https://ruby.sketchup.com/Sketchup/Model.html#abort_operation-instance_method

2. Never abort a transparent operation. V2-0B therefore uses a normal, non-transparent operation only.

3. `Sketchup::Entities#add_group` should create an empty group first, then geometry should be added to `group.entities`. This also avoids old-SketchUp issues with `add_group(entities)`.
   - https://ruby.sketchup.com/Sketchup/Entities.html#add_group-instance_method

4. `Sketchup::Entities#add_face` may return `nil`. A face created on the ground plane has a special orientation behavior and can face downward regardless of vertex order.
   - https://ruby.sketchup.com/Sketchup/Entities.html#add_face-instance_method

5. `Sketchup::Face#pushpull(distance, false)` extrudes in the direction of the face normal and returns `nil`; success must therefore be validated from resulting geometry rather than a truthy return value.
   - https://ruby.sketchup.com/Sketchup/Face.html#pushpull-instance_method

Mature patterns also reviewed:

- Trimble official `sketchup-ruby-api-tutorials` Hello Cube example: operation -> empty group -> face -> pushpull -> commit.
- Trimble `sketchup-extension-ux-guidelines`: one user action should be one undo step; orient face before pushpull.
- Existing project V1 production `SketchupDerivedWorkspaceAdapter`: root-owned independent groups and operation/abort architecture are already proven in real SU2020, but V2 MUST NOT reuse its transaction wrapper because it discards Boolean operation results.

## 3. Minimal module architecture

Implement only the following production modules unless AIPM explicitly approves otherwise:

### 3.1 `extension/su_ai_plugin/v2/host_operation_guard.rb`

Responsibilities:

- own V2 in-memory host-write session state;
- start/commit/abort ONE normal operation;
- inspect exact Boolean operation results;
- perform at most one abort attempt for a failed open operation;
- publish deterministic transaction result states;
- lock further V2 writes when rollback cannot be confirmed.

It MUST NOT create geometry and MUST NOT know PreparedCadDataset semantics.

### 3.2 `extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb`

Responsibilities:

- real SketchUp host calls only;
- resolve model and root `model.entities`;
- verify root edit context (`model.active_path == nil`);
- create empty top-level Group with `model.entities.add_group` and assign name afterward;
- create face inside `group.entities`;
- orient the face to +Z;
- pushpull positive distance;
- set minimal V2 ownership attributes INSIDE the same operation;
- validate real generated geometry after pushpull.

It MUST return real Boolean operation results unchanged to the guard.

It MUST NOT read V1 Runner private state.

### 3.3 `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

Responsibilities:

- validate V2-0A footprint + explicit positive finite probe height;
- perform the complete pre-mutation freshness/context gate;
- call V1 public capture/build/validate seams only;
- re-run `SemanticFootprintProjector` against current PCD;
- re-resolve the exact target footprint;
- call the operation guard + host adapter;
- return one deterministic result object/status.

No UI.

## 4. Input contract

Production entry conceptually accepts:

- `footprint:` a valid V2-0A SemanticFootprint record;
- `analysis_result:` current AnalysisResult needed by the frozen V1 public capture path;
- `probe_height:` explicit Numeric, finite, > 0, in SketchUp model units;
- optional explicit model/adapter dependencies only where needed for testability.

There is NO implicit production default height.

The Owner probe may use a fixed explicit test height, e.g. `120.0` model units, but product code must receive height explicitly.

## 5. Pre-mutation stale/context gate — mandatory order

Before ANY SketchUp mutation:

1. reject if V2 host session is `HOST_STATE_UNCERTAIN`;
2. require current model exists;
3. require `model.active_path == nil`;
4. call the frozen V1 public seam:

   `WorkingModeRunner.capture_prepared_cad_input_bundle(analysis_result: ...)`
   -> `PreparedCadDatasetBuilder.build(...)`
   -> `PreparedCadDatasetValidator.validate_and_finalize(...)`

5. require Validator result is `READY` or `READY_WITH_WARNINGS` and a final usable PCD exists;
6. compare FULL 64-hex current `content_digest` with `footprint['source_content_digest']`;
7. re-run `SemanticFootprintProjector.project` with the footprint's exact `semantic_role` + `source_layer_name`;
8. require exact `footprint_id_full` match in the current projected result;
9. require current matching footprint still has the same `source_content_digest`;
10. re-check `model.active_path == nil` immediately before operation start;
11. only then may host mutation begin.

Any failure above returns BLOCKED/STALE/CONTEXT_CHANGED with zero SketchUp mutation and zero start_operation call.

`dataset_id` is never freshness authority.

## 6. Host operation contract

Use one normal, non-transparent operation:

`model.start_operation('SU-AI-Plugin: V2 Stage 0B Mass Probe', true, false, false)`

Use exact Boolean success semantics (`equal?(true)` acceptable and Ruby-2.2-compatible).

### 6.1 Start

- `true` -> operation is open;
- `false` or raise -> `START_FAILED`;
- no abort attempt when start was not confirmed;
- zero geometry mutation expected.

### 6.2 Construction / post-validation failure after start

Attempt `abort_operation` exactly once.

- abort `true` -> `FAILED_ROLLED_BACK`;
- abort `false` or raise -> `HOST_STATE_UNCERTAIN` and lock further V2 writes for the current plugin session.

Do not report cleanup success unless abort returned literal true.

### 6.3 Commit

Commit only after geometry post-validation has passed.

- commit `true` -> `SUCCESS`;
- commit `false` or raise -> attempt abort exactly once;
- abort `true` -> `COMMIT_FAILED_ROLLED_BACK`;
- abort `false` or raise -> `HOST_STATE_UNCERTAIN` + session lock.

A successful Stage 0B call must generate exactly one native Undo item for the user-level probe action.

## 7. Host session lock

`HostOperationGuard` owns a process-memory/session-level lock.

States needed at minimum:

- `READY`
- `HOST_STATE_UNCERTAIN`

When uncertain:

- all later Stage-0B/V2 writes fail before `start_operation`;
- no automatic reset;
- expose an explicit developer-only recovery reset method for tests / Owner recovery after the user manually restores the model state.

Do NOT store this lock in the SKP model and do NOT persist it.

## 8. Geometry construction contract

Given the re-resolved current footprint:

1. destination is `model.entities`, never `model.active_entities`;
2. create empty Group with `model.entities.add_group` (no arguments);
3. assign a recognizable name after creation:
   `SU-AI-V2-Probe-<short-footprint-id>`;
4. set minimal ownership attributes inside the same open operation, dictionary name `SU-AI-V2`:
   - `schema_version = 'v2.host-object.v1'`
   - `kind = 'stage0b_mass_probe'`
   - `footprint_id_full`
   - `source_content_digest`
5. create `Geom::Point3d` / host points from the footprint's published `projected_world_coordinates` exactly; do not change XY; Z must remain `0.0`;
6. call `group.entities.add_face(points)`;
7. `nil` face => construction failure;
8. because ground-plane face orientation is special, verify face normal. If not +Z, call `face.reverse!`; verify +Z afterward;
9. call `face.pushpull(probe_height, false)`;
10. do not use `pushpull` return value as success evidence;
11. run post-validation on the actual group geometry.

No materials.
No smoothing.
No extra faces invented before add_face.
No source/V1 group edits.

## 9. Post-validation contract

Before commit, require at minimum:

- group exists and is valid/not deleted where host API supports these checks;
- group is top-level under `model.entities`;
- group contains faces and edges after extrusion;
- at least one generated vertex is at/near z=0;
- at least one generated vertex is at/near z=`probe_height`;
- no generated vertex is below `-coordinate_epsilon`;
- generated max-z satisfies `abs(max_z - probe_height) <= coordinate_epsilon`;
- ownership attributes are readable and exactly match the target footprint/digest.

Use the footprint's existing `coordinate_epsilon` as the geometry tolerance. Do not invent another hidden epsilon.

Any failed post-validation is a construction failure and must go through the operation guard rollback contract.

## 10. Result contract

Return a JSON-safe / testable Hash-like result with stable top-level status.

Minimum statuses:

- `SUCCESS`
- `BLOCKED`
- `STALE_PREPARED_DATASET`
- `CONTEXT_CHANGED`
- `START_FAILED`
- `FAILED_ROLLED_BACK`
- `COMMIT_FAILED_ROLLED_BACK`
- `HOST_STATE_UNCERTAIN`

On `SUCCESS`, return only safe V2 metadata plus the generated Group handle as an explicitly host-only field if necessary for the Owner probe. Do not serialize SketchUp host handles into persistent data.

## 11. Automated acceptance matrix

Create `tests/test_v2_stage0b_host_mass_probe.rb` with host-free Fakes.

Required cases:

### Pre-mutation / stale gate

- active_path non-nil before capture -> blocked; no operation;
- V2 host session already uncertain -> blocked; no operation;
- capture/build/validator not READY -> blocked; no operation;
- full content_digest mismatch -> `STALE_PREPARED_DATASET`; no operation;
- current projector cannot re-resolve exact `footprint_id_full` -> stale/blocked; no operation;
- active_path becomes non-nil before start -> `CONTEXT_CHANGED`; no operation;
- warnings-only READY_WITH_WARNINGS remains allowed.

### Operation guard

- start false;
- start raise;
- add_group failure;
- add_face returns nil;
- add_face raise;
- face orientation correction failure;
- pushpull raise;
- post-validation failure;
- abort true;
- abort false;
- abort raise;
- commit true;
- commit false + abort true;
- commit false + abort false;
- commit raise + abort true;
- commit raise + abort raise;
- uncertain session blocks next write;
- explicit recovery reset unlocks test session.

### Successful geometry

- exact input XY preserved;
- z=0 base preserved;
- group created at model root, not active_entities;
- empty add_group call (no source entities passed);
- face oriented +Z before positive pushpull;
- ownership attributes written inside same operation;
- success = one start + one commit + zero abort;
- no V1/source mutation calls;
- no UI / Sketchup global calls from pure Stage0B orchestration module except through the compatibility adapter.

### Public V1 freshness integration

At least one test must use the real frozen public V1 capture -> Builder -> Validator path from a truthful clean fixture, then use a fake host adapter to prove Stage0B accepts a genuinely current SemanticFootprint.

Do not replace this integration proof with a synthetic FINAL PCD only.

## 12. Real SketchUp Owner probe

Add developer-only:

`Probe/v2_stage0b_owner_probe.rb`

It may build a small synthetic FINAL PCD + matching SemanticFootprint for host-only diagnostics, provided the automated suite separately proves the real public V1 freshness path.

The probe must invoke the SAME production Stage0B mass executor + SAME real SketchUp compatibility adapter.

Provide two callable developer commands:

1. success probe
   - create one simple rectangular V2 mass;
   - print status + created group name;
   - Owner presses native Undo once;
   - expected: the complete V2 probe group disappears in one Undo.

2. injected construction-failure probe
   - use a Probe-only adapter subclass/decorator that raises after mutation has begun (for example at extrusion);
   - production code itself must not gain a `failure_stage` test switch;
   - expected result is `FAILED_ROLLED_BACK` when abort succeeds;
   - expected visible residue = zero V2 probe group.

Do NOT put Owner-probe test switches into production modules.

## 13. Compatibility

New production code must use Ruby 2.2-era syntax.

Do not introduce:

- safe navigation;
- `match?`;
- `Array#sum`;
- `Hash#compact`;
- `filter_map`;
- `transform_keys`;
- pattern matching;
- `then` / `yield_self`;
- other newer helpers without explicit AIPM approval.

Host target remains SketchUp 2017+; Owner real-host gate uses SU2020.

## 14. Allowed production scope

Expected new production files only:

- `extension/su_ai_plugin/v2/host_operation_guard.rb`
- `extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb`
- `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

Expected tests/probe:

- `tests/test_v2_stage0b_host_mass_probe.rb`
- `Probe/v2_stage0b_owner_probe.rb`

Do NOT modify existing V1 production files.
Do NOT modify existing V2-0A production files unless a compile/load issue proves a narrow need; if so STOP and report before editing.
Do NOT modify Loader/UI for Stage 0B.

If another production file appears necessary, STOP with:

`V2_0B_SCOPE_EXPANSION_REQUIRED`

## 15. Validation / Gate

Pi must run at minimum:

1. syntax checks for all new Ruby files;
2. V2-0B focused test suite;
3. V2-0A 43/43 regression;
4. V1.7 relevant reconstruction/topology regression;
5. V1.8 structure reconstruction regression;
6. V1.9 B1 PreparedCadDataset regression;
7. V1.9 B1.5 live bundle regression;
8. full runner vs established 5 fail / 4 error baseline;
9. source compatibility guard for all new production files;
10. `git diff --check`;
11. RBZ rebuild + RBZ smoke if the repository packaging contract requires every production source file in `extension/` to ship.

No new fail/error is acceptable.

Automated tests cannot close Stage 0B alone.

Final Stage-0B Gate after Pi implementation:

1. AIPM direct source/diff review;
2. real SU2020 Owner success probe;
3. one native Undo removes the whole successful probe mass;
4. real SU2020 injected-failure probe leaves zero visible V2 residue when abort succeeds;
5. only then V2-0B = CLOSED.

Codex is NOT automatically required because PB-03/PB-04/PB-05 transaction/stale/root contracts already received prior xHigh review and this Blueprint does not alter them. AIPM may escalate only if implementation deviates from the frozen host boundary or real SU2020 reveals a new host-specific ambiguity.

END
