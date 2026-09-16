# AIPM V2-0A SOURCE REVIEW R2 — TEST-PROOF MICRO-CORRECTION

Date: 2026-09-16
Project: SU-AI-Plugin
Target branch: `dev/v2`
Status: **FROZEN MICRO-CORRECTION**
Final Product Owner: Owner
Technical authority: ChatGPT / AIPM

## 0. Verdict

AIPM direct source/diff review of the V2-0A R1 implementation commit
`e722638c9863ec2f1a8d562a34a3ec92491d2354` finds the five R1 production corrections directionally correct and preserved.

R1 is **NOT YET PASS** because one required acceptance proof is vacuous:

`V2-S0A-R1-07` claims to prove isolated/load-order-safe `Set` availability, but the child process only requires the adapter and checks `respond_to?(:project)` / `SCHEMA_VERSION`. It never calls `LayerLocalGraphAdapter.project`, so it never executes the adjacency-rebuild path containing `Set.new`.

This is a **test-evidence residual only**. No production-code correction is authorized.

## 1. R2-01 — make the isolated Set proof non-vacuous

Correct `V2-S0A-R1-07` (or replace it with an equivalently named R2 regression) so the fresh child Ruby process actually executes the adapter path that uses `Set.new`.

Required behavior:

1. Start a fresh Ruby child process.
2. Do NOT explicitly `require 'set'` in the child/test shim.
3. Require only the minimum production dependencies needed for `PreparedCadDataset` + `LayerLocalGraphAdapter`.
4. Construct a minimal contract-usable FINAL `PreparedCadDataset` using the actual schemas:
   - content schema `pcd.v1`;
   - semantic graph schema `pcd-semantic-graph.v1`;
   - validation blockers = empty Array;
   - `persistence_check.status == 'PASS'`.
5. The semantic graph MUST contain at least one mapped edge so `LayerLocalGraphAdapter.project(dataset:, layer_name:)` proceeds through filtered-edge adjacency rebuild and executes `Set.new`.
6. Call the REAL production method:

   `SUAnalysis::V2::LayerLocalGraphAdapter.project(dataset: dataset, layer_name: 'L0')`

7. Assert at minimum:
   - process exits successfully;
   - adapter status is `PROJECTED`;
   - graph is non-empty;
   - expected adjacency for the mapped edge exists.

The proof must be constructed such that removing production `require 'set'` from `layer_local_graph_adapter.rb` would make this isolated test fail with the missing `Set` dependency. A source-text check alone is not sufficient.

Synthetic PCD construction is acceptable for THIS dependency-isolation test because the separate R1-01 authoritative integration test already proves the real public V1 handoff → Builder → Validator → V2 path. Do not replace or weaken R1-01.

## 2. Allowed files

Production files: **NONE**.

Primary test file only:

- `tests/test_v2_stage0a_semantic_footprint.rb`

One temporary/generated child-process shim at test runtime is allowed and should be deleted in `ensure`, as in the existing pattern. Do not add a permanent production helper.

Completion documentation may update:

- `CURRENT_STATE.md`
- `Review/CURRENT_PI_REPORT.md`

If any production change appears necessary, STOP and report:

`V2_0A_R2_PRODUCTION_SCOPE_EXPANSION_REQUIRED`

Do not modify V1 or any of the three V2-0A production modules.

## 3. Preserve all R1 PASS surfaces

Do not rewrite or weaken:

- R1-01 real public V1 handoff integration proof;
- real `pcd.v1` / `pcd-semantic-graph.v1` schema checks;
- finalized READY usability gate;
- `require 'set'` production fix;
- Ruby 2.2-era production compatibility fix;
- known-zero-edge => EMPTY behavior;
- unknown-layer => BLOCKED behavior;
- original 35 Stage-0A geometry tests;
- host-free / no-SketchUp contract;
- V1 production freeze.

## 4. Required validation

Run at minimum:

1. `ruby -c tests/test_v2_stage0a_semantic_footprint.rb`;
2. full V2-0A focused suite — all prior 43 tests plus the corrected/non-vacuous isolation proof must pass;
3. explicitly show the child process actually called `LayerLocalGraphAdapter.project` and returned `PROJECTED` with expected adjacency;
4. V1.7 reconstruction/topology regression (`V17-`);
5. V1.8 structure reconstruction (`V18-`);
6. V1.9B1 B1.2 regression (`B1.2-`);
7. V1.9B1 B1.5 regression (`B15-`);
8. project full runner and compare against the established pre-existing `5 fail / 4 error` baseline;
9. `git diff --check`;
10. prove the substantive R2 diff contains **test-only** changes (plus allowed state/report docs), with zero production-file changes.

No new fail/error is acceptable.

RBZ rebuild is NOT required for this test-only correction.

## 5. Forbidden

Do NOT:

- modify any production file;
- reopen R1-01..R1-05 production design;
- modify V1;
- modify `CanonicalStructureReconstructor`;
- start V2-0B;
- start Residential Stage 1;
- add host mutation / Group / Face / extrusion;
- add UI / Tool / HtmlDialog work;
- add MCP / LLM / Agent;
- invoke Codex.

## 6. Completion

After R2-01 is complete:

1. update `CURRENT_STATE.md` with `V2-0A R2 TEST-PROOF COMPLETE / PENDING AIPM FINAL SOURCE REVIEW`;
2. prepend/replace `Review/CURRENT_PI_REPORT.md` with exact R2 evidence;
3. create the final stable commit;
4. push only `dev/v2`;
5. report implementation SHA + final remote HEAD;
6. STOP and return control to AIPM.

AIPM will perform one narrow final source recheck. If this test-only residual is closed with no production drift, V2-0A may close and the next V2 stage can be considered.

END
