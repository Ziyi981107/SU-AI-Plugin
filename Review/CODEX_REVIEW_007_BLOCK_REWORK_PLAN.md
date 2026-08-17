# CODEX REVIEW 007 — BLOCK REWORK PLAN (pass 3)

Created: 2026-08-17
Status:  EXECUTION
Sources:
  Prompt/CODEX_REVIEW_007_2026-08-17_BLOCK_RECHECK_PASS2.txt
  Prompt/CODEX_GUIDANCE_006_2026-08-17_REWORK_PLAN_CORRECTIONS.txt
Fix commit (next): TBD

Closed (must NOT reopen):
  S2-BLOCK-001  one Edge -> one EdgeRecord
  S2-BLOCK-003  no &. in production entry path (Ruby 2.2.4)
  S2-BLOCK-006 HtmlDialog subpart (UI::HtmlDialog namespace)

Open (4 subparts to fix):
  S2-BLOCK-002  real API contract issues
  S2-BLOCK-004  boundary-bucket dedup
  S2-BLOCK-005  checklist + invalid geometry
  S2-BLOCK-006  version subpart (version_number not calendar year)


## Goal

Resolve the 4 remaining subparts as ONE focused Stage 2 correction pass 3,
incorporating the 3 mandatory corrections from CODEX_GUIDANCE_006:
1. Version API fix (sketchup_version returns String, baseline uses
   version.to_i >= 17, no calendar-year inference from version_number).
2. Active edit context fix (use model.edit_transform; model.active_path
   is Array; resolver accepts dot-delimited String).
3. Vertex dedup fix (search current + adjacent buckets; preserve perf).


## Block-by-block plan

### S2-BLOCK-006 (version subpart)

Location: compatibility/su_capability.rb, tests/test_preflight.rb

Fix:
- `sketchup_version` returns the String form (for diagnostics):
  `Sketchup.version.to_s` when defined.
- New `sketchup_major_version` returns Integer >= 17 on SU2017+.
  Uses `Sketchup.version.to_i` (leading major of dotted String).
- Drop `product_year` / `su_release_to_year` table (was based on
  wrong assumption that version_number is 17..26).
- baseline check: `sketchup_major_version >= 17` for SU2017+ lock.
- Tests use realistic dotted version strings: "17.2.0", "24.0.0".
  Verify `sketchup_version` returns the dotted String verbatim and
  `sketchup_major_version` extracts the leading integer.

Recheck evidence:
- [ ] sketchup_version returns "17.2.0" for fake version "17.2.0"
- [ ] sketchup_version returns "24.0.0" for fake version "24.0.0"
- [ ] sketchup_major_version returns 17 for "17.2.0"
- [ ] sketchup_major_version returns 24 for "24.0.0"
- [ ] No reference to version_number -> calendar year remains
- [ ] Owner checklist updated: uses major_version >= 17

------------------------------------------------------------

### S2-BLOCK-002 (real API contract)

Location: compatibility/su_capability.rb, extension/preflight_runner.rb,
tests/_fake_su.rb, tests/test_preflight_runner.rb

Fix:
- `active_edit_context(model)` returns:
  - `[model.edit_transform, [pid1, pid2, ...]]` where pids come from
    `safe_persistent_id(ent)` for each entity in `model.active_path`
    (Array, per real SU).
  - Outside edit context: `[identity_transform, []]`.
- Snapshot builder accepts `seed_pid_prefix: Array<Integer>` (already
  supported but currently fed by active_edit_context which we are
  correcting).
- `build_source_reference` uses `entity.entityID` (real SU API) when
  available, falling back to `entity.object_id` only outside SU / tests.
- `resolve_pid_path(model, pid_path)`:
  - Serializes Array<Integer> PID path to dot-delimited String before
    calling `model.instance_path_from_pid_path`.
  - Returns the resolved InstancePath or nil.

FakeSU updates:
- `Model.active_path` is Array (not InstancePath); per-entity PIDs
  populated.
- `Model.edit_transform` belongs to Model (not InstancePath).
- `Model.instance_path_from_pid_path` accepts ONLY dot-delimited String
  (rejects arrays).
- `InstancePath` keeps persistent_id_path as String (dot-delimited).

Recheck evidence:
- [ ] Active nested edit-context test uses real-API shape: active_path
      Array + edit_transform on Model; expected world coords exact
- [ ] PID path emitted as String "10.20.555" resolves through
      model.instance_path_from_pid_path
- [ ] build_source_reference uses entity.entityID when available
- [ ] Shared-definition multi-occurrence tests still pass (round-1 + r2)

------------------------------------------------------------

### S2-BLOCK-004 (boundary-bucket dedup)

Location: core/preflight.rb

Fix:
- `collect_distinct_vertices` searches current bucket AND all 26
  adjacent buckets (3D grid; offsets in [-1, 0, 1] for each axis).
- For each candidate point in adjacent buckets, confirm actual
  distance within coord_eps using `points_equal?` before merging.
- Keep the per-bucket Array structure; search all 27 buckets per
  insert.

Recheck evidence:
- [ ] Boundary regression: two points 0.02 apart on opposite sides
      of a bucket boundary (e.g. [0.99, 0, 0] and [1.01, 0, 0] with
      coord_eps=1.0) merge into ONE distinct vertex
- [ ] Custom-epsilon test still passes
- [ ] One-endpoint-off-plane test still passes
- [ ] Perf test: 5000-edge Preflight still < 2 seconds

------------------------------------------------------------

### S2-BLOCK-005 (checklist + invalid geometry)

Location: Review/OWNER_VERIFICATION_STAGE_2.txt, tests/_fake_su.rb,
extension/preflight_runner.rb

Fix:
- Owner checklist: `Entities#add_line(...)` returns one Edge directly
  (NOT an array); remove the spurious `[0]` indexing.
- Owner checklist: erasing edge then analyzing parent collection
  doesn't retain reference. Replace with explicit test that builds
  two Edges (one valid, one deliberately invalidated via stub) and
  passes BOTH as a selection that retains the invalid reference.
  Owner documents real-host behavior if shape differs.
- Owner fingerprint helper: use `entity.respond_to?(:persistent_id)
  && entity.persistent_id` capability-safe (NOT `definition.persistent_id`
  directly). Fingerprint also recurses into component-definition
  contents + occurrence transforms.
- FakeSU: support retaining invalid reference after erase!
  (e.g. `invalid_edge_holding_array` pattern).

Recheck evidence:
- [ ] Checklist add_line code is paste-runnable on SU2017+
- [ ] Invalid-entity test that holds invalid reference + valid Edge
      in same selection; valid Edge analyzed, invalid contributes 0
- [ ] Fingerprint helper uses capability-safe PID access
- [ ] Fingerprint recurses component-definition contents + transforms


## Test count delta

Currently 65 tests. Expected after pass 3: ~75-80 tests
(+10-15 for new recheck evidence).


## Commit & recheck

After fix:
1. Run full isolated Ruby suite. Expect all PASS (65 + new tests).
2. Run post-2.2 syntax sweep on all production .rb files.
3. Commit as `fix(stage-2): resolve Codex BLOCK rework pass 3`.
4. Drop new BLOCK RECHECK request packet to Owner for Codex:
   `Review/BLOCK_RECHECK_REQUEST_2026-08-17_pass3.md` (cover
   S2-BLOCK-002 / 004 / 005 / 006-version subparts only; do not
   reopen S2-BLOCK-001 / 003 / S2-BLOCK-006 HtmlDialog).
5. Codex BLOCK RECHECK 3 PASS -> enable Owner SU verification.
6. Codex BLOCK RECHECK 3 FAIL -> iterate (no new commits until PASS).


## What is NOT in this rework

- Stage 6 UI (separate stage, after BLOCK recheck 3 PASS + Owner SU verify)
- Stage 7 final report
- Any Repair feature (per PI_TASK_001 §17 / §91)


## References

- Source 1: `Prompt/CODEX_REVIEW_007_2026-08-17_BLOCK_RECHECK_PASS2.txt`
- Source 2: `Prompt/CODEX_GUIDANCE_006_2026-08-17_REWORK_PLAN_CORRECTIONS.txt`
- R001-R005 decisions: `Review/R00[1-5]_*.md` (all Status: ANSWERED)
- WORKFLOW_PROTOCOL: `Review/WORKFLOW_PROTOCOL.txt`
- AGENT.md §1b OWNER HANDOFF PROTOCOL
- PI_TASK_001: `Prompt/PI_TASK_001_V1_READONLY_CAD_ANALYZER.txt`