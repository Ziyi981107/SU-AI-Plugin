# CODEX REVIEW 005 — BLOCK REWORK PLAN (2nd pass)

Created: 2026-08-17
Status:  EXECUTION
Source:  Prompt/CODEX_REVIEW_005_2026-08-17_BLOCK_RECHECK.txt
Closed:  S2-BLOCK-001, S2-BLOCK-003
Open:    S2-BLOCK-002, S2-BLOCK-004, S2-BLOCK-005, S2-BLOCK-006 (NEW)


## Goal

Resolve the 4 remaining BLOCKS as ONE focused Stage 2 correction pass 2.
Pure-Ruby tests must remain green (currently 50/50). Add adapter-level
recheck evidence for each remaining BLOCK.


## Block-by-block plan

### S2-BLOCK-006 — Capability/version probes use wrong real-SU API

Location: `compatibility/su_capability.rb`, `Review/OWNER_VERIFICATION_STAGE_2.txt`

Fix:
- `html_dialog?` probes `defined?(UI::HtmlDialog)` (NOT `Sketchup::HtmlDialog`).
  `UI::HtmlDialog` lives in the `UI` module.
- `sketchup_version` returns Integer calendar year via
  `Sketchup.version.to_i` only if `Sketchup.version` is already an
  Integer (older SU). For the modern String form (e.g. "24.0.318"),
  extract the major version differently — UI consumers in real SU
  read `Sketchup.version` and `.to_i` of the leading numeric component
  is NOT a calendar year. Per Q003+A we lock to capability detection,
  not version string parsing. Keep `sketchup_version` for diagnostics,
  but add `product_year` that explicitly derives the calendar year from
  `Sketchup.version_number` (which is SU's stable numeric year in
  newer versions) or returns nil. Owner checklist will use the explicit
  `product_year`.
- Update Owner checklist (step B) to assert `product_year >= 2017`.

Recheck evidence:
- [ ] `html_dialog?` returns true when `UI::HtmlDialog` is defined (fake stub)
- [ ] `html_dialog?` returns false when `UI` namespace absent
- [ ] `product_year` returns nil outside SU, Integer >= 2017 inside
      (fake stub providing `Sketchup.version_number = 2017`)

------------------------------------------------------------

### S2-BLOCK-004 — Preflight metrics + performance

Location: `core/preflight.rb`

Fix:
1. `non_zero_z_edge_count` uses OR semantics:
   `edges.count { |e| e.start_point[2].abs > coord_eps || e.end_point[2].abs > coord_eps }`
2. `collect_distinct_vertices(edges, coord_eps:)` takes eps explicitly;
   default pulls from `config.tolerance.coordinate_epsilon`. NOT hardcoded 1e-6.
3. Performance: use a spatial hash keyed by quantized bucket (3D integer
   bucket of size eps) instead of `result.any?` O(V²) scan. Reuse
   `QuantizeKey` (already in core/) for the bucket calc.
4. `build_warnings` and `run` use the SAME coord_eps / big_z_thr / etc.

Recheck evidence:
- [ ] Test: one endpoint Z=0, other endpoint Z>eps -> non_zero_z_edge_count == 1
- [ ] Test: custom config.tolerance.coordinate_epsilon changes vertex merge
      behavior (smaller epsilon -> more distinct vertices)
- [ ] Test: Preflight alone on 5000 disconnected Edges finishes < 2 seconds
- [ ] All existing Preflight tests still pass

------------------------------------------------------------

### S2-BLOCK-002 — Source identity, edit-context, non-commutative coverage

Location: `core/source_reference.rb`, `extension/preflight_runner.rb`,
`compatibility/su_capability.rb`

Fix:
1. `SourceReference` carries `persistent_id_path` (Array<Integer>) — the
   PIDs of every container from model root to the leaf Edge, plus the
   leaf's own PID at the end. This is a machine-resolvable path.
   - `instance_path_string` is kept as a human-readable display label,
     derived from names (NOT used as the canonical identity).
2. Walk builds the PID path during recursion:
   - At each container, look up its PID via `safe_persistent_id(container)`.
   - Append to a growing path Array.
   - Yield to the snapshot builder with `(entity, world_points, pid_path)`.
3. Active edit-context: the snapshot builder accepts an `active_path`
   argument (a Sketchup::InstancePath or nil). When non-nil:
   - `model.instance_path_from_pid_path(active_path)` resolves the chain.
   - `active_path.transformation` gives the active edit-context transform.
   - We seed the world_t with that transform instead of identity.
   - Without an active edit-context, we still default to identity.
4. Non-commutative nested transforms: add a test with rotation + non-uniform
   scale + translation combined at multiple depths. Verify world coords
   are exact.
5. Two instances sharing one definition **inside the same selected
   parent**: add a test where both are children of one outer Group.

Recheck evidence:
- [ ] `persistent_id_path` is Array<Integer> with one PID per container level
      plus leaf PID
- [ ] `persistent_id_path` distinct for two shared-definition instances
- [ ] Test: rotation 30deg around z + scale (2,3,1) + translation (10,20,30)
      applied at 3 levels produces exact world coords
- [ ] Test: active edit-context (fake) seeds transform correctly; selected
      Edges inside active context are in active-context-local coords mapped
      to model-space world
- [ ] Test: two ComponentInstances inside one outer Group -> 2 occurrences
- [ ] Test: PID path resolution back via `model.instance_path_from_pid_path`
      (fake) returns the original InstancePath

------------------------------------------------------------

### S2-BLOCK-005 — Owner checklist + invalid handling

Location: `Review/OWNER_VERIFICATION_STAGE_2.txt`, `extension/preflight_runner.rb`,
`tests/_fake_su.rb`

Fix:
1. Owner checklist: replace `v.position = Geom::Point3d.new(...)` with
   `entities.add_line([x1,y1,z1], [x2,y2,z2])` to build disposable
   geometry at desired coordinates (no setter).
2. Add a recursive fingerprint helper snippet Owner can paste into
   Ruby Console (model-level + selection-level: counts, PIDs, endpoints,
   transforms, layer names).
3. `vertex_point_world`: on invalid vertex/position (nil, raises, or
   `valid? == false`), do NOT return `[0,0,0]`. Instead, raise a custom
   `InvalidEntityError` so the per-Edge rescue in `build_snapshot` skips
   the Edge and emits `[SU-AI-Plugin] skipped invalid edge: ...`.
4. `safe_each` actually wraps iteration in begin/rescue, returning an
   Array of items successfully enumerated up to the failure point
   (so traversal can continue with the rest).
5. `walk_entity_world`: wrap each container's children enumeration in
   per-child rescue so a single bad child doesn't abort siblings.
6. `tests/_fake_su.rb`:
   - `Edge#erase!` flips state; subsequent `start`/`end`/`vertices`
     return nil (or raise). Add `valid?` method.
   - `Edge#valid?` returns `!@erased` by default.

Recheck evidence:
- [ ] Test: invalid Edge (erased) -> ZERO EdgeRecords from that Edge
      (assertion: count == 1 for valid one, not >= 1)
- [ ] Test: invalid vertex (start = nil) -> entire Edge skipped, no origin EdgeRecord
- [ ] Test: invalid container (raises on .entities) -> siblings still walked
- [ ] Test: fingerprint helper snippet exists in checklist (manual check)
- [ ] Test: setup commands in checklist use only Entities#add_line (no setters)


## Test count delta

Expected after rework: ~60-70 tests (current 50, +10-15 for new BLOCK evidence).


## Commit & recheck

After fix:
1. Run full isolated Ruby suite. Expect all PASS (50 + new tests).
2. Run post-2.2 syntax sweep on all production .rb files.
3. Commit as `fix(stage-2): resolve Codex BLOCK rework 2nd pass`.
4. Drop new BLOCK RECHECK request to Owner for Codex:
   `Review/BLOCK_RECHECK_REQUEST_2026-08-17_pass2.md`
   (cover S2-BLOCK-002 / 004 / 005 / 006 recheck evidence only).


## What is NOT in this rework

- Stage 6 UI (separate stage, after BLOCK recheck PASS + Owner SU verify)
- Stage 7 final report
- Any Repair feature (per PI_TASK_001 §17 / §91)
- S2-BLOCK-001 / S2-BLOCK-003 (already CLOSED, must not reopen)

## References

- Source: `Prompt/CODEX_REVIEW_005_2026-08-17_BLOCK_RECHECK.txt`
- R001-R005 decisions: `Review/R00[1-5]_*.md` (all Status: ANSWERED)
- WORKFLOW_PROTOCOL: `Review/WORKFLOW_PROTOCOL.txt`
- AGENT.md §1b OWNER HANDOFF PROTOCOL
- PI_TASK_001: `Prompt/PI_TASK_001_V1_READONLY_CAD_ANALYZER.txt`