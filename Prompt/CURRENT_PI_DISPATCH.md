# CURRENT PI DISPATCH — V2-0B HOST GEOMETRY PROBE

Date: 2026-09-16
Project: SU-AI-Plugin
TARGET_BRANCH: dev/v2
STATUS: ACTIVE

## Authority

V2-0A = CLOSED / PASS.

AIPM closure review:

`Review/CURRENT_AIPM_REVIEW.md`

Frozen V2-0B technical authority:

`Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md`

Pi must implement exactly that Blueprint. Do not redesign the host transaction, stale gate, geometry ownership, or Stage boundary.

## Before work

```bash
git fetch origin
git switch dev/v2
git pull --ff-only origin dev/v2
```

Then verify:

- branch is `dev/v2`;
- local `dev/v2 == origin/dev/v2` before editing;
- V2-0A R2 closure commit `b476da98f135deeb0da40e01512f0807ca3a4823` is an ancestor of HEAD;
- `Review/CURRENT_AIPM_REVIEW.md` says `V2-0A CLOSED`;
- the V2-0B Blueprint exists;
- this dispatch is ACTIVE.

If any check fails, STOP and report to AIPM.

## Current stage

V1 = CLOSED / frozen input authority.
V2-0A SemanticFootprint = CLOSED / PASS.
V2-0B Host Geometry Probe = ACTIVE.
V2 Residential Stage 1 = NOT STARTED.

## Mandatory read order

1. `PI_START_HERE.md`
2. `AGENTS.md`
3. `PROJECT_HANDOFF.md`
4. `PROJECT_MASTER_PLAN_V1X.md`
5. `CURRENT_STATE.md`
6. `Review/CURRENT_AIPM_REVIEW.md`
7. `Prompt/CURRENT_PI_DISPATCH.md`
8. `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0A_SEMANTIC_FOOTPRINT_2026-09-16.md`
9. `Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md`

## Implement V2-0B only

Expected production files:

- `extension/su_ai_plugin/v2/host_operation_guard.rb`
- `extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb`
- `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

Expected focused test:

- `tests/test_v2_stage0b_host_mass_probe.rb`

Expected developer/Owner probe:

- `Probe/v2_stage0b_owner_probe.rb`

Follow the Blueprint contracts exactly.

## Non-negotiable contracts

### 1. Pre-mutation stale/context gate

Before ANY SketchUp mutation:

- session not HOST_STATE_UNCERTAIN;
- model exists;
- `model.active_path == nil`;
- fresh V1 public capture -> Builder -> Validator;
- Validator READY / READY_WITH_WARNINGS;
- full current 64-hex `content_digest` equals source footprint digest;
- re-project same semantic role + layer;
- exact `footprint_id_full` re-resolves;
- root context checked again immediately before start_operation.

Any failure above => zero host mutation and zero operation start.

### 2. One normal operation

Use one normal, non-transparent operation.

Inspect literal Boolean results from start / commit / abort.

Do NOT reuse the V1 adapter's operation wrapper because it discards those Boolean results.

### 3. Geometry

- destination = `model.entities` root;
- empty `add_group` with no arguments;
- group name assigned after creation;
- minimal V2 ownership attributes written inside the same operation;
- face uses exact current footprint XY / z=0 coordinates;
- nil face fails;
- verify +Z normal, reverse if needed, verify again;
- positive explicit probe height;
- `pushpull` nil return is not success evidence;
- post-validate real generated geometry before commit.

### 4. Failure

After operation start, any construction/post-validation failure:

- abort exactly once;
- abort true => confirmed rolled back;
- abort false/raise => HOST_STATE_UNCERTAIN;
- uncertain => lock all later V2 host writes until explicit developer recovery reset.

Commit false/raise follows the same confirmed-abort/uncertain rule.

### 5. Ownership

Never mutate:

- Source CAD;
- V1 Derived Workspace;
- existing V1 production objects;
- existing V2-0A data.

The generated mass is a new independent V2-owned root Group.

## Allowed production scope

New files only unless the Blueprint explicitly says otherwise:

- `extension/su_ai_plugin/v2/host_operation_guard.rb`
- `extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb`
- `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`

Do NOT modify existing V1 production files.
Do NOT modify the three existing V2-0A production files.
Do NOT modify Loader/UI.

If another production file is required, STOP with:

`V2_0B_SCOPE_EXPANSION_REQUIRED`

## Required validation

Run at minimum:

1. syntax checks for all new Ruby files;
2. complete V2-0B focused suite;
3. V2-0A focused 43/43 regression;
4. V1.7 relevant regression;
5. V1.8 structure regression;
6. V1.9 B1 PreparedCadDataset regression;
7. V1.9 B1.5 live bundle regression;
8. project full runner vs established 5 fail / 4 error baseline;
9. Ruby-2.2-era source compatibility guard for new production files;
10. `git diff --check`;
11. RBZ rebuild + smoke if required by the repository packaging contract for new production files.

No new fail/error acceptable.

The focused suite MUST include the full failure matrix from the Blueprint, including start/commit/abort false/raise, stale digest, context change, post-validation failure, uncertainty lock, successful root-group geometry, and real V1 freshness integration with fake host.

## Real-host gate is NOT Pi self-approval

Pi may add the Owner probe script but does NOT claim Stage 0B closed from automated tests.

After Pi implementation:

1. update `CURRENT_STATE.md`;
2. update `Review/CURRENT_PI_REPORT.md`;
3. commit + push only `dev/v2`;
4. STOP.

Then:

- AIPM direct source review;
- Owner real SU2020 success probe;
- one native Undo removes complete successful probe mass;
- Owner real SU2020 injected-failure probe leaves zero visible residue on confirmed abort;
- only AIPM closes Stage 0B.

## Frozen / forbidden

Do NOT:

- implement selection Tool / pickray / highlight;
- implement HtmlDialog / toolbar / menu;
- implement ResidentialObject / floors / balconies / parapets;
- implement update/regenerate;
- implement site / raised community / roads / landscape;
- implement materials;
- implement MCP / LLM / Agent;
- start Residential Stage 1;
- modify V1;
- modify pcd.v1;
- modify CanonicalStructureReconstructor;
- invoke Codex yourself.

END
