# CODEX REVIEW 004 — BLOCK REWORK PLAN

Created: 2026-08-17
Status:  DRAFT (execution scheduled next session / on Owner signal)
Source:  CODEX_REVIEW_004_2026-08-17_STAGE2_AND_R001_R005 (Prompt/, mtime 2026-08-17 15:47)


## Goal

Resolve all 5 S2-BLOCK-### items per Codex's "minimum acceptable fix" +
"recheck evidence needed" specifications, as ONE focused Stage 2 correction.
Pure-Ruby tests must still pass (33/33). Add adapter-level stub tests
covering traversal, transforms, shared definitions, counts, source identity.


## Block-by-block plan

### S2-BLOCK-001 — Every SketchUp Edge becomes 2 EdgeRecords

Location: `extension/preflight_runner.rb:55`

Current (wrong) pattern:
```ruby
entity.vertices.each_with_index do |v, i|
  next_vertex = entity.vertices[(i + 1) % entity.vertices.size]
  edges << EdgeRecord.new(start_point: p1, end_point: p2, ...)
end
```

Fix:
- Emit EXACTLY ONE EdgeRecord per source Edge.
- Read the two endpoints ONCE: `start_point, end_point = edge.start.position, edge.end.position`.
- Do NOT create directed half-records.
- Orientation-insensitive duplicate detection stays inside DuplicateDetector
  (already correct).

Recheck evidence:
- [ ] Stub test: one mock Edge → one EdgeRecord
- [ ] Rectangle in a Group → 4 EdgeRecords (not 8)
- [ ] Normal rectangle through adapter → 0 duplicate candidates, 0 open endpoints


### S2-BLOCK-002 — Component traversal, transforms, instance identity

Location: `extension/preflight_runner.rb` (multiple),
`core/source_reference.rb:27-45`

Fix (in order):
1. Group children: walk `group.entities` (not group itself).
2. ComponentInstance children: walk `instance.definition.entities`.
3. Accumulate `Geom::Transformation` through recursion; transform every
   endpoint into one documented analysis coordinate space (model/world).
4. Correct transform multiplication order; nested transforms handled.
5. SourceReference gains an `instance_path` field (list of component
   instance handles / names) so the same definition Edge used in two
   instances stays two distinct occurrences.
6. NEVER mutate definitions or source entities.

Recheck evidence:
- [ ] Stub test: translated, rotated, scaled Group → world coords correct
- [ ] Stub test: nested Group→Component→Group transforms
- [ ] Stub test: 2 ComponentInstances sharing one definition, different
      transforms → 2 occurrences, world coords differ, source identities
      don't collide
- [ ] Direct selected Edges still work (single Group → 1 occurrence per Edge)


### S2-BLOCK-003 — &. safe-navigation violates Ruby 2.2.4 baseline

Location: `extension/preflight_runner.rb:153`

Fix:
- Replace `obj&.foo` with explicit nil guard:
  `obj.nil? ? nil : obj.foo`
- grep all production/test Ruby files for post-2.2 syntax after the fix:
  ```
  grep -rn -E '(\&\.|frozen_string_literal: *true|<<~|\?\.|\bthen\b *$)' --include='*.rb' \
       core/ compatibility/ extension/ tests/
  ```

Recheck evidence:
- [ ] No `&.` (or other post-2.2 syntax) remains
- [ ] Production entry path loads under actual SU2017/Ruby 2.2.4 (R004 posture B)


### S2-BLOCK-004 — Preflight metrics don't match task contract

Location: `core/preflight.rb:118-127, 189`,
`extension/preflight_runner.rb:128-184`,
`Review/R001_preflight_threshold_defaults.md`

Fix:
1. Report separate `non_zero_z_vertex_count` and `non_zero_z_edge_count`
   (both use `coordinate_epsilon`, NOT `big_z`).
2. Deduplicate vertices in analysis/world coordinates using
   `coordinate_epsilon`; share endpoint counted ONCE as a Vertex.
3. Keep `big_z` as a SEPARATE significant off-plane warning threshold;
   do NOT redefine "non-zero Z" with it.
4. Mixed selection → selection_type="mixed" + retain per-type counts.
5. Root selected container = nesting level 1; warning at
   `deepest_nesting >= 3` (NOT `> 3`).
6. Update field names, messages, tests.
7. Canonical severity values: `:low / :medium / :high` ONLY (per R005).
   Drop current `:info / :warning` emissions from PreflightAnalyzer.
8. `large_coordinate_count` rename → it counts bbox axis extrema today;
   rename to `large_coordinate_extrema_count` OR return offending
   locations.

Recheck evidence:
- [ ] Shared endpoint counted once as Vertex; Edges counted correctly
- [ ] Z above coordinate_epsilon but below big_z → in non-zero counts,
      no significant-Z warning
- [ ] Z above big_z → in counts AND warning fires (severity :medium)
- [ ] Mixed selection test passes (assertion on "mixed" type + per-type
      counts preserved)
- [ ] Exactly-three-level nesting fires warning (deepest=3, threshold=3)
- [ ] Tests updated to new field names; pure-Ruby 33/33 PASS


### S2-BLOCK-005 — Owner verification checklist unreliable

Location: `Review/OWNER_VERIFICATION_STAGE_2.txt:86, 96, 117`

Fix:
1. Rewrite setup steps to create DISPOSABLE test geometry:
   `Entities#add_line` inside a dedicated test Group / ComponentInstance.
   Never ask Owner to edit production/source CAD for test setup.
2. Source integrity check: capture DETERMINISTIC FINGERPRINT before vs
   after — entity counts, PIDs, endpoint coordinates, container
   transformations, layer/tag assignments.
3. Cleanup = explicit disposal of disposable test fixture only
   (not part of Analyzer behavior).
4. Reproducible invalid/erased entity test: 1 valid + 1 deliberately
   invalid/erased → analysis continues, only the invalid is skipped.

Recheck evidence:
- [ ] Updated checklist reviewed against official API calls
- [ ] Owner verification BLOCKED from starting until S2-BLOCK-001..005 closed
- [ ] Codex agrees (BLOCK RECHECK PASS)


## Adapter-level stub tests to add

New file: `tests/test_preflight_adapter.rb`

Stub design: a minimal `FakeEntity` + `FakeModel` set in `tests/_fake_su.rb`
that exposes:
- `entity.start` / `entity.end` (returns FakeVertex with .position)
- `entity.vertices` (returns 2-element array, used by S2-BLOCK-001 fix)
- `group.entities` / `instance.definition.entities` (recurse target)
- `entity.transformation` (returns a 4x4 matrix for transforms)
- `entity.layer` (returns a FakeLayer with .name)
- `entity.persistent_id` (returns Integer or nil; raise option for invalid)

Tests:
- one Edge → one EdgeRecord
- Group with 4-edge rectangle → 4 EdgeRecords, 0 duplicates, 0 open
- 2 ComponentInstances sharing definition at different transforms →
  2 distinct occurrences with correct world coords
- Mixed selection (Group + Component + Edge) → selection_type="mixed"
- 3-level nested Group → deepest_nesting=3, warning fires
- Erased/invalid Edge in selection → analyzer continues, warns, returns
  report with valid edges counted

Run command:
```
./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb
```
Expected: 33 (existing) + N (new adapter stubs) = 33+N, all PASS.


## Stage 5 implication (per R002)

The originally-planned standalone Stage 5 (`compatibility/su_version_probe.rb`)
is CANCELLED. Minimum HtmlDialog capability probe (used by Stage 6) is
folded into the BLOCK rework:
- Add `SUCapability.html_dialog?` returning false outside SU, true inside
  SU 2017+.
- Add outside-SU stub test for `html_dialog?`.


## Commit & recheck

After fix:
1. Run full isolated Ruby suite: `tests/run_all.rb`. Expect all PASS
   (33 existing + new adapter tests).
2. Run post-2.2 syntax sweep (BLOCK-003 evidence).
3. Commit as `fix(stage-2): resolve Codex BLOCK rework S2-BLOCK-001..005`.
4. Drop recheck request to Owner for them to forward to Codex:
   `Review/BLOCK_RECHECK_REQUEST_2026-08-17.md`
   (cover S2-BLOCK-001..005 recheck evidence only, per Codex).
5. Codex BLOCK RECHECK PASS → enable Owner SU verification.
6. Codex BLOCK RECHECK FAIL → iterate (no new commits until PASS).


## What is NOT in this rework

- Stage 6 UI (separate stage, after BLOCK recheck PASS + Owner SU verify)
- Stage 7 final report
- Any Repair feature (per PI_TASK_001 §17 / §91)


## References

- Source: `Prompt/CODEX_REVIEW_004_2026-08-17_STAGE2_AND_R001_R005.txt`
- R001-R005 decisions: `Review/R00[1-5]_*.md` (all Status: ANSWERED)
- WORKFLOW_PROTOCOL: `Review/WORKFLOW_PROTOCOL.txt`
- AGENT.md §1b OWNER HANDOFF PROTOCOL (Review/ vs Prompt/ contract)
- PI_TASK_001: `Prompt/PI_TASK_001_V1_READONLY_CAD_ANALYZER.txt`
